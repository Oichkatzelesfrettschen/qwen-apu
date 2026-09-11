"""The image artifact listener, mounted on the gateway's one origin.

`remote/image-service.py` serves completed immutable artifacts from a second
loopback socket under `GET /artifacts/<sha256>.<png|json>`. This module serves
the same bytes under `/api/artifacts/...` behind the gateway, so a page reads
an artifact over the origin it already holds a credential for and the worker
keeps its socket to the operator's own tools.

Four rules run in the listener's order and the order is the security property.
The Host set closes DNS rebinding before anything else answers. The session or
bearer check runs ahead of the existence lookup, so a present digest and an
absent one answer 401 alike and the route is no existence oracle. The
per-client bucket charges an authenticated reader alone, which keeps an
unauthenticated flood on the constant-cost 401 rather than on a 429 that would
report whether this client is already metered. The digest pattern refuses
traversal, percent-encoded separators, and every other spelling of a path by
matching `<64 hex>.<png|json>` and nothing else, so no normalization pass
decides what a name means. The publication marker decides last: a PNG and a
provenance record become readable through one atomic marker naming both.

The route pattern is the catch-all `(?P<name>.*)` because `web.http.match`
answers a pattern miss with the application's own 404, which would put a name
refusal ahead of the Host, credential, and bucket checks this module orders.
The handler owns every refusal instead, and the name arrives through
`path_params` the server layer already split from the query.
"""

from __future__ import annotations

import datetime as dt
import hmac
import json
import re
import threading
import time
from collections.abc import Callable, Iterator, Sequence
from dataclasses import dataclass, field
from pathlib import Path

from qwen_apu.web.http import Request, Response, Route

# The name a published artifact carries, from `image-service.py`'s own
# ARTIFACT_NAME_PATTERN: the content digest and one of two suffixes.
ARTIFACT_NAME_PATTERN = re.compile(r"^([0-9a-f]{64})\.(png|json)$")
ARTIFACT_BYTE_CAP = 64 * 1024 * 1024
ARTIFACT_PER_CLIENT_PER_MINUTE_DEFAULT = 30
RATE_WINDOW_SECONDS = 60
LOOPBACK_HOSTS: tuple[str, ...] = ("127.0.0.1", "::1")
PUBLICATION_PREFIX = ".publication-"
PUBLICATION_SUFFIX = ".json"
ARTIFACT_ROUTE_PREFIX = "/api/artifacts"
BEARER_REALM = 'Bearer realm="qwen-image"'

CONTENT_TYPES = {"png": "image/png", "json": "application/json"}
IMMUTABLE_CACHE_CONTROL = "private, max-age=31536000, immutable"


def host_header_names(header: str, admitted: Sequence[str]) -> str:
    """Return the admitted name a Host header presents, or an empty string.

    A browser that resolves an attacker-controlled name to a bound address
    reaches this origin with that name in the Host header, so the bind alone
    leaves DNS rebinding open and the closed set closes it. The bracketed form
    carries an IPv6 literal and the plain form drops its port. The comparison
    falls back to the casefolded name because DNS is case-insensitive while the
    literals hold digits, dots, and colons alone.
    """
    if not header:
        return ""
    value = header.strip()
    if value.startswith("["):
        closing = value.find("]")
        if closing < 0:
            return ""
        named = value[1:closing]
    else:
        named = value.split(":", 1)[0]
    if named in admitted:
        return named
    lowered = named.lower()
    return lowered if lowered in admitted else ""


class FixedWindowLimiter:
    """An in-process fixed-window counter, one bucket per client address.

    The arithmetic is `image-service.py`'s FixedWindowLimiter and through it
    `authorize-broker.py`'s `Ledger._consume_bucket`, so a 429 from the
    gateway and a 429 from the worker's own listener both mean the next
    admitted attempt lies within the current window's close. Artifact reads
    carry nothing worth auditing durably, so the counter lives in memory and
    resets with the process.
    """

    def __init__(
        self,
        limit: int = ARTIFACT_PER_CLIENT_PER_MINUTE_DEFAULT,
        window_seconds: int = RATE_WINDOW_SECONDS,
    ) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self._lock = threading.Lock()
        self._buckets: dict[str, tuple[int, int]] = {}

    def consume(self, key: str, now: float) -> tuple[bool, int]:
        """Return (admitted, retry_after_seconds) and charge one unit if admitted."""
        window_start = int(now) - int(now) % self.window_seconds
        with self._lock:
            stored_start, used = self._buckets.get(key, (window_start, 0))
            if stored_start != window_start:
                stored_start, used = window_start, 0
            if used + 1 > self.limit:
                return False, self.window_seconds - int(now) % self.window_seconds
            self._buckets[key] = (stored_start, used + 1)
            return True, 0


@dataclass(frozen=True, slots=True)
class Publication:
    """One atomic publication marker: the job, the two digests it commits, its file."""

    job_id: str
    png_sha256: str
    provenance_sha256: str
    published_at: float
    marker: str = ""


class ArtifactDirectory:
    """A reader over the worker's artifact directory.

    The worker owns every write here -- the `.part.png` staging file, the two
    hard links that name the content digests, the marker that commits them,
    and the retention sweep bounded by QWEN_IMAGE_ARTIFACT_MAX_COUNT and
    QWEN_IMAGE_ARTIFACT_MAX_AGE_S. This reader answers from whatever the
    directory holds at the moment of the read, which is what makes a retention
    expiry visible as a 404 rather than as stale bytes.
    """

    def __init__(self, directory: Path) -> None:
        self.directory = directory

    def publications(self) -> Iterator[Publication]:
        """Yield every complete marker, oldest first by its own write time.

        A marker is written once through a staging file and `os.replace`, which
        preserves the inode and its timestamp, so `st_mtime` states when the
        pair became readable.
        """
        try:
            names = sorted(path.name for path in self.directory.iterdir())
        except OSError:
            return
        found: list[Publication] = []
        for name in names:
            if not name.startswith(PUBLICATION_PREFIX) or not name.endswith(PUBLICATION_SUFFIX):
                continue
            path = self.directory / name
            try:
                record = json.loads(path.read_text(encoding="utf-8"))
                published_at = path.stat().st_mtime
            except (OSError, ValueError):
                continue
            if not isinstance(record, dict):
                continue
            png = record.get("png_sha256")
            provenance = record.get("provenance_sha256")
            job = record.get("job_id")
            if not (isinstance(png, str) and isinstance(provenance, str) and isinstance(job, str)):
                continue
            found.append(Publication(job, png, provenance, published_at, name))
        found.sort(key=lambda entry: (entry.published_at, entry.job_id))
        yield from found

    def committed(self, digest: str, suffix: str) -> Publication | None:
        """Return the marker committing one digest under one suffix.

        Both files of the pair are required on disk, the rule
        `ImageService.artifact_is_published` states: a marker whose partner
        file left under retention commits nothing.
        """
        key = "png_sha256" if suffix == "png" else "provenance_sha256"
        for publication in self.publications():
            if getattr(publication, key) != digest:
                continue
            png_path = self.directory / f"{publication.png_sha256}.png"
            provenance_path = self.directory / f"{publication.provenance_sha256}.json"
            if png_path.is_file() and provenance_path.is_file():
                return publication
        return None

    def read(self, digest: str, suffix: str) -> bytes | None:
        """Return the committed bytes of one artifact, or None where none commit it.

        A file past the byte cap reads as absent the way an unreadable one
        does: the worker refuses an oversized artifact before it names one, so
        a file above the cap here states a directory this reader did not write.
        """
        if self.committed(digest, suffix) is None:
            return None
        try:
            with (self.directory / f"{digest}.{suffix}").open("rb") as handle:
                body = handle.read(ARTIFACT_BYTE_CAP + 1)
        except OSError:
            return None
        return None if len(body) > ARTIFACT_BYTE_CAP else body

    def retract(self, png_digest: str) -> Publication | None:
        """Unlink the marker committing one PNG, leaving the payload to the worker.

        Publication is one atomic write of `.publication-<job_id>.json`, and
        `committed` requires that marker before either file of the pair reads,
        so unlinking it is the exact inverse: the PNG and the provenance record
        answer 404 through every route here from the next read onward.

        The payload bytes stay on disk and nothing here reclaims them. The
        worker owns every payload write under this directory, and its
        `enforce_artifact_retention` enumerates markers rather than files:
        `publication_markers` lists `.publication-*.json` and unlinks a
        digest's bytes only while expiring the marker that names it, so a pair
        whose marker this method removed is one the sweep never sees again
        whatever QWEN_IMAGE_ARTIFACT_MAX_COUNT and QWEN_IMAGE_ARTIFACT_MAX_AGE_S
        are set to. The bytes therefore remain until an operator removes them,
        which AGENTS.md routes through remote/check-deletion-plan.sh rather
        than through a request.

        Returns the retracted marker, or None where no marker commits the
        digest and where the unlink fails, so a caller reports "no such
        artifact" for both rather than claiming a removal it did not make.
        """
        publication = self.committed(png_digest, "png")
        if publication is None or not publication.marker:
            return None
        try:
            (self.directory / publication.marker).unlink()
        except OSError:
            return None
        return publication

    def provenance_for_png(self, png_digest: str) -> dict[str, object] | None:
        """Return the provenance record the marker binds to one PNG digest.

        The PNG and its provenance are independently content-addressed, so the
        record's own name comes from the marker rather than from the PNG's
        digest. `image-review.py` reaches the same record over the artifact
        route; the binding it then checks -- `png_sha256` equal to the reviewed
        digest -- holds through the marker here.
        """
        publication = self.committed(png_digest, "png")
        if publication is None:
            return None
        body = self.read(publication.provenance_sha256, "json")
        if body is None:
            return None
        try:
            record = json.loads(body.decode("utf-8"))
        except (UnicodeDecodeError, ValueError):
            return None
        return record if isinstance(record, dict) else None


def session_refused(request: Request) -> bool:
    """The default session check: no session admits a read.

    The gateway's session authority lives in `web/auth.py`, and a caller that
    names none leaves the bearer as the whole credential. Defaulting to refused
    rather than to admitted keeps this module's tests standing alone without
    widening what an unconfigured mount serves.
    """
    return False


@dataclass(frozen=True, slots=True)
class ArtifactSettings:
    """What the mount reads, whom it admits, and how fast it answers them."""

    directory: Path
    api_key: str = ""
    admitted_hosts: tuple[str, ...] = LOOPBACK_HOSTS
    session_admits: Callable[[Request], bool] = session_refused
    limiter: FixedWindowLimiter = field(default_factory=FixedWindowLimiter)
    clock: Callable[[], float] = time.time

    def artifacts(self) -> ArtifactDirectory:
        return ArtifactDirectory(self.directory)


def _json_response(status: int, payload: object, retry_after: int | None = None) -> Response:
    headers = {
        "content-type": "application/json",
        "cache-control": "no-store",
        "x-content-type-options": "nosniff",
    }
    if retry_after is not None:
        headers["retry-after"] = str(retry_after)
    return Response(status, json.dumps(payload, separators=(",", ":")).encode("utf-8"), headers)


def _unauthorized() -> Response:
    """The bare 401 the listener sends: a challenge, no body, and no cache."""
    return Response(
        401,
        b"",
        {"www-authenticate": BEARER_REALM, "cache-control": "no-store"},
    )


def _bearer_admits(settings: ArtifactSettings, request: Request) -> bool:
    """Compare the presented bearer against the configured key in constant time.

    An unset key admits nothing: the comparison would otherwise stand against
    an empty expectation and turn a missing configuration into an open route.
    A query parameter carries no authority, which is why this reads the header
    alone.
    """
    if not settings.api_key:
        return False
    presented = request.header("authorization")
    return bool(presented) and hmac.compare_digest(presented, f"Bearer {settings.api_key}")


def guard(settings: ArtifactSettings, request: Request) -> Response | None:
    """Run the Host, credential, and bucket checks in that order.

    Returning None admits the request to the lookup that follows. Every route
    this module serves runs the same three, so an index read and an artifact
    read report the same refusal for the same cause.
    """
    if not host_header_names(request.header("host"), settings.admitted_hosts):
        return _json_response(
            403,
            {
                "error": "the request Host names no admitted literal: "
                + ", ".join(settings.admitted_hosts)
            },
        )
    if not (settings.session_admits(request) or _bearer_admits(settings, request)):
        return _unauthorized()
    admitted, retry_after = settings.limiter.consume(request.client_address, settings.clock())
    if not admitted:
        return _json_response(
            429,
            {"error": f"artifact reads from {request.client_address} exceed the per-client rate"},
            retry_after,
        )
    return None


def read_artifact(settings: ArtifactSettings, request: Request) -> Response:
    """Answer one `<sha256>.<png|json>` read, or refuse it in the listener's order."""
    refusal = guard(settings, request)
    if refusal is not None:
        return refusal
    name = request.path_params.get("name", "")
    found = ARTIFACT_NAME_PATTERN.match(name)
    if found is None:
        return _json_response(404, {"error": "an artifact is named <sha256>.png or <sha256>.json"})
    digest, suffix = found.group(1), found.group(2)
    body = settings.artifacts().read(digest, suffix)
    if body is None:
        return _json_response(404, {"error": "no such artifact"})
    return Response(
        200,
        body,
        {
            "content-type": CONTENT_TYPES[suffix],
            # The name is the SHA-256 of the bytes, so the content at one route
            # never changes and the response says so. `private` rather than
            # `public` because the response is credentialed.
            "cache-control": IMMUTABLE_CACHE_CONTROL,
            "etag": f'"{digest}"',
            "x-content-type-options": "nosniff",
            "content-disposition": f'inline; filename="{digest}.{suffix}"',
        },
    )


def read_index(settings: ArtifactSettings, request: Request) -> Response:
    """List the published pairs, newest first.

    The index is the one route here the worker's listener does not serve: it
    answers 404 to `/artifacts` under every setting. The gateway serves it
    because a page that reloads holds no record of what it generated, and it
    runs behind the identical Host, credential, and bucket prefix and charges
    the bucket the way a read does. The listing is mutable where an artifact is
    immutable, so it carries `no-store` rather than the immutable set.
    """
    refusal = guard(settings, request)
    if refusal is not None:
        return refusal
    reader = settings.artifacts()
    entries = []
    # The pair check is the two `is_file` calls `committed` makes after it finds
    # a marker, and the marker is already in hand. Calling `committed` per entry
    # would re-list the directory and re-parse every marker for each one, which
    # at the worker's own 200-publication retention bound is 40,000 parses on a
    # route metered at 30 reads a minute.
    for publication in reversed(list(reader.publications())):
        png_path = reader.directory / f"{publication.png_sha256}.png"
        provenance_path = reader.directory / f"{publication.provenance_sha256}.json"
        if not (png_path.is_file() and provenance_path.is_file()):
            continue
        entries.append(
            {
                "job_id": publication.job_id,
                "png_sha256": publication.png_sha256,
                "provenance_sha256": publication.provenance_sha256,
                "png_url": f"{ARTIFACT_ROUTE_PREFIX}/{publication.png_sha256}.png",
                "provenance_url": f"{ARTIFACT_ROUTE_PREFIX}/{publication.provenance_sha256}.json",
                "published_at": dt.datetime.fromtimestamp(
                    publication.published_at, tz=dt.UTC
                ).isoformat(timespec="seconds"),
            }
        )
    return _json_response(200, {"artifacts": entries})


def routes(settings: ArtifactSettings | None = None) -> tuple[Route, ...]:
    """The artifact routes, index first and the catch-all read second.

    The two patterns are disjoint: `/api/artifacts` matches the index alone and
    `/api/artifacts/` reaches the read with an empty name, which the digest
    pattern refuses the way the worker's listener refuses `/artifacts/`.
    """
    resolved = settings if settings is not None else ArtifactSettings(Path("artifacts"))
    return (
        Route.make("GET", ARTIFACT_ROUTE_PREFIX, lambda request: read_index(resolved, request)),
        Route.make(
            "GET",
            rf"{ARTIFACT_ROUTE_PREFIX}/(?P<name>.*)",
            lambda request: read_artifact(resolved, request),
        ),
    )
