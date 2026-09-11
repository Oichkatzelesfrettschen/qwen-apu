"""Document extraction as an owned subprocess, a content-addressed store, and three routes.

`DocumentService.extract` hands one job to `qwen_apu.tools.document_worker`
and owns everything the worker does not: the argv list with `shell=False`, a
new session so the whole process group answers one kill, a temporary working
directory under `<tmp>/documents/<job>`, a monotonic deadline that kills that
group on expiry, and an environment holding PATH, PYTHONPATH, TMPDIR, and
PYTHONDONTWRITEBYTECODE alone. PYTHONPATH names the directory the running
`qwen_apu` package sits in plus whatever `DocumentSettings.python_path` adds,
so the worker imports the package this service was imported from and resolves
pypdf from the wheel `wheelhouse/requirements.lock` pins; the child's working
directory and any ambient PYTHONPATH decide nothing.

Network isolation is probed once at service start: a child that reaches
`os.unshare(os.CLONE_NEWUSER | os.CLONE_NEWNET)` proves the kernel admits an
unprivileged user namespace here, and every later extraction installs that
same call as its `preexec_fn`, which runs between fork and exec in the
single-threaded child. Where the kernel refuses -- `kernel.unprivileged_userns_clone`
off, a seccomp filter, or a sandbox that is already a namespace -- the service
records `network_isolation: unavailable` in every record it writes and keeps
extracting, because the worker opens no socket of its own and the isolation is
defense in depth rather than the boundary itself.

The store is content-addressed by the source digest: `<artifacts>/documents/
<sha256>/` holds `<sha256>.json` and `chunks/<n>.txt`. A second extraction of
the same bytes finds that directory and answers from it, so a collision is the
ordinary case rather than an error, and publication is one `os.rename` of the
staging directory that loses a race by dropping its own copy.

`POST /api/documents`, `GET /api/documents/<sha256>`, and
`POST /api/documents/<sha256>/search` sit behind the injectable session check
that defaults to refused, the rule `tools/files.py` and `web/artifacts.py`
both carry: a caller that wires no session authority serves nothing.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import cast

from qwen_apu.tools.document_worker import (
    Boundary,
    Chunk,
    DocumentRecord,
    Limits,
    read_record,
)
from qwen_apu.web.http import Request, Response, Route

DOCUMENTS_ROUTE = "/api/documents"
DOCUMENT_ROUTE = r"/api/documents/(?P<digest>[0-9a-f]{64})"
DOCUMENT_SEARCH_ROUTE = r"/api/documents/(?P<digest>[0-9a-f]{64})/search"

WORKER_MODULE = "qwen_apu.tools.document_worker"
STORE_DIRECTORY = "documents"
JOB_TOKEN_BYTES = 8
DEFAULT_DEADLINE_SECONDS = 120.0
DEFAULT_MAX_UPLOAD_BYTES = 32 * 1024 * 1024
DEFAULT_MAX_SEARCH_HITS = 200
PROBE_TIMEOUT_SECONDS = 10.0
KILL_GRACE_SECONDS = 5.0
EXCERPT_MAX_CHARS = 400
FILENAME_PATTERN = re.compile(r"^[\w][\w .()+-]{0,127}$")
DIGEST_PATTERN = re.compile(r"^[0-9a-f]{64}$")
MULTIPART_BOUNDARY_PATTERN = re.compile(r'boundary="?([^";]+)"?', re.IGNORECASE)
DISPOSITION_FILENAME_PATTERN = re.compile(r'filename="([^"]*)"', re.IGNORECASE)

NETWORK_ISOLATION_NAMESPACED = "namespaced"
NETWORK_ISOLATION_UNAVAILABLE = "unavailable"

# The probe runs the same two flags the extraction installs, so what it proves
# is what the extraction performs rather than a weaker approximation of it.
ISOLATION_PROBE_SOURCE = "import os\nos.unshare(os.CLONE_NEWUSER | os.CLONE_NEWNET)\n"


class DocumentRefused(Exception):
    """One refusal carrying the HTTP status the boundary answers with."""

    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


@dataclass(frozen=True, slots=True)
class SearchHit:
    """One match inside one chunk, named in the document's own coordinates."""

    chunk_index: int
    chunk_sha256: str
    char_start: int
    char_end: int
    text: str
    boundaries: tuple[str, ...]

    def to_json(self) -> dict[str, object]:
        return {
            "chunk_index": self.chunk_index,
            "chunk_sha256": self.chunk_sha256,
            "char_start": self.char_start,
            "char_end": self.char_end,
            "text": self.text,
            "boundaries": list(self.boundaries),
        }


def session_refused(request: Request) -> bool:
    """The default session check: no session admits a call."""
    return False


@dataclass(frozen=True, slots=True)
class DocumentSettings:
    """Where the store and the scratch live, what bounds a job, and who is admitted."""

    artifacts: Path
    tmp: Path
    limits: Limits = field(default_factory=Limits)
    deadline_seconds: float = DEFAULT_DEADLINE_SECONDS
    max_upload_bytes: int = DEFAULT_MAX_UPLOAD_BYTES
    max_search_hits: int = DEFAULT_MAX_SEARCH_HITS
    worker_command: tuple[str, ...] = ()
    python_path: tuple[Path, ...] = ()
    session_admits: Callable[[Request], bool] = session_refused

    def command(self) -> tuple[str, ...]:
        """The worker argv: the settings' own, or this interpreter running the module."""
        return self.worker_command or (sys.executable, "-m", WORKER_MODULE)

    def store(self) -> Path:
        return self.artifacts / STORE_DIRECTORY

    def scratch(self) -> Path:
        return self.tmp / STORE_DIRECTORY


def probe_network_isolation(timeout: float = PROBE_TIMEOUT_SECONDS) -> str:
    """Report whether an unprivileged user and network namespace is reachable here.

    The probe is a child rather than a call in this process: unsharing a user
    namespace in the gateway would move every later syscall into it, and a
    multithreaded process cannot unshare one at all.
    """
    try:
        completed = subprocess.run(  # noqa: S603
            [sys.executable, "-c", ISOLATION_PROBE_SOURCE],
            check=False,
            capture_output=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return NETWORK_ISOLATION_UNAVAILABLE
    if completed.returncode == 0:
        return NETWORK_ISOLATION_NAMESPACED
    return NETWORK_ISOLATION_UNAVAILABLE


def _isolate_child() -> None:
    """Drop the child into its own user and network namespace before exec.

    One syscall runs between fork and exec, which is what keeps this callable
    safe in a process that holds locks elsewhere.
    """
    os.unshare(os.CLONE_NEWUSER | os.CLONE_NEWNET)


def _package_directory() -> Path:
    """The directory holding the `qwen_apu` package this module was imported from."""
    return Path(__file__).resolve().parents[2]


def safe_filename(name: str) -> str:
    """Return the base name a record carries, refusing a name that is not one.

    The name reaches the record and the extension decides the extractor, so a
    path separator, a leading dot, and a control character all refuse here
    rather than reaching a `Path` join or a log line.
    """
    stripped = name.strip()
    if "/" in stripped or "\\" in stripped or ".." in stripped:
        raise DocumentRefused(400, f"{name!r} names a path rather than a file")
    if not FILENAME_PATTERN.match(os.path.basename(stripped)):
        raise DocumentRefused(400, f"{name!r} is not a plain file name")
    return os.path.basename(stripped)


class DocumentService:
    """Extraction, storage, and retrieval for one settings object."""

    def __init__(self, settings: DocumentSettings) -> None:
        self.settings = settings
        self.network_isolation = probe_network_isolation()

    # --- extraction ----------------------------------------------------------

    def extract(self, path: Path, media_type: str, filename: str = "") -> DocumentRecord:
        """Extract one file through the worker and publish it into the store.

        The digest decides first: bytes already in the store answer from it and
        start no process, which is what makes a re-upload cost one read.
        """
        name = safe_filename(filename or path.name)
        try:
            size = path.stat().st_size
        except OSError as error:
            raise DocumentRefused(400, f"the input is unreadable: {error}") from None
        if size > self.settings.max_upload_bytes:
            raise DocumentRefused(
                413,
                f"the input is {size} bytes, past the "
                f"{self.settings.max_upload_bytes}-byte upload cap",
            )
        digest = _digest_file(path)
        stored = self.settings.store() / digest
        if (stored / f"{digest}.json").is_file():
            return read_record(stored, digest)
        job_directory = self.settings.scratch() / secrets.token_hex(JOB_TOKEN_BYTES)
        job_directory.mkdir(parents=True)
        try:
            self._run_worker(path, name, media_type, job_directory)
            record = read_record(job_directory, digest)
            _publish(job_directory, stored)
        finally:
            shutil.rmtree(job_directory, ignore_errors=True)
        return record

    def _run_worker(self, path: Path, filename: str, media_type: str, job_directory: Path) -> None:
        """Run one worker to completion, killing its group on the deadline."""
        job = json.dumps(
            {
                "input_path": str(path.resolve()),
                "filename": filename,
                "media_type": media_type,
                "output_directory": str(job_directory),
                "limits": self.settings.limits.to_json(),
                "network_isolation": self.network_isolation,
            }
        ).encode("utf-8")
        environment = {
            "PATH": os.environ.get("PATH", os.defpath),
            "PYTHONPATH": os.pathsep.join(
                [str(_package_directory()), *(str(entry) for entry in self.settings.python_path)]
            ),
            "PYTHONDONTWRITEBYTECODE": "1",
            "TMPDIR": str(job_directory),
        }
        isolate = _isolate_child if self.network_isolation == NETWORK_ISOLATION_NAMESPACED else None
        deadline = time.monotonic() + self.settings.deadline_seconds
        try:
            process = subprocess.Popen(  # noqa: S603
                list(self.settings.command()),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(job_directory),
                env=environment,
                start_new_session=True,
                preexec_fn=isolate,  # noqa: PLW1509
            )
        except OSError as error:
            raise DocumentRefused(500, f"the worker did not start: {error}") from None
        try:
            stdout, stderr = process.communicate(job, timeout=max(0.0, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            _kill_group(process)
            raise DocumentRefused(
                504,
                f"the extraction passed its {self.settings.deadline_seconds:g}-second deadline "
                "and its process group was killed",
            ) from None
        if process.returncode != 0:
            raise DocumentRefused(400, _worker_error(process.returncode, stdout, stderr))

    # --- retrieval -----------------------------------------------------------

    def record(self, digest: str) -> DocumentRecord:
        """Read one stored record, refusing an unstored digest."""
        if not DIGEST_PATTERN.match(digest):
            raise DocumentRefused(400, "the digest is not 64 lowercase hexadecimal characters")
        stored = self.settings.store() / digest
        if not (stored / f"{digest}.json").is_file():
            raise DocumentRefused(404, f"no document is stored under {digest}")
        return read_record(stored, digest)

    def search(self, digest: str, query: str, *, regex: bool = False) -> tuple[SearchHit, ...]:
        """Return every match over the stored chunks, in chunk order.

        A hit names the chunk that holds it, the chunk's digest, the match's
        own span in the document's character coordinates, and every boundary
        the match falls inside, so a caller cites a page, a paragraph, or a row
        rather than an offset alone.

        The pattern runs in this process against the stored chunks, where the
        worker's CPU cap reaches nothing, so a catastrophically backtracking
        expression costs the gateway its own time; the admitted session is what
        bounds who spends it.
        """
        if not query:
            raise DocumentRefused(400, "the query is empty")
        record = self.record(digest)
        matcher = _matcher(query, regex=regex)
        stored = self.settings.store() / digest
        hits: list[SearchHit] = []
        for chunk in record.chunks:
            if len(hits) >= self.settings.max_search_hits:
                break
            body = (stored / "chunks" / f"{chunk.index}.txt").read_text(encoding="utf-8")
            for found in matcher(body):
                if len(hits) >= self.settings.max_search_hits:
                    break
                start = chunk.char_start + found.start()
                end = chunk.char_start + found.end()
                hits.append(
                    SearchHit(
                        chunk_index=chunk.index,
                        chunk_sha256=chunk.sha256,
                        char_start=start,
                        char_end=end,
                        text=_excerpt(body, found.start(), found.end()),
                        boundaries=_covering(record.boundaries, start, end),
                    )
                )
        return tuple(hits)

    def chunk_text(self, digest: str, index: int) -> str:
        """Return one chunk's text, refusing an index the record does not carry."""
        record = self.record(digest)
        if not any(chunk.index == index for chunk in record.chunks):
            raise DocumentRefused(404, f"document {digest} carries no chunk {index}")
        return (self.settings.store() / digest / "chunks" / f"{index}.txt").read_text(
            encoding="utf-8"
        )


def _digest_file(path: Path, block: int = 1024 * 1024) -> str:
    """The source digest, read in blocks so a large upload never sits in memory twice."""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            data = handle.read(block)
            if not data:
                break
            digest.update(data)
    return digest.hexdigest()


def _publish(staging: Path, stored: Path) -> None:
    """Move the staging directory into the store, keeping the published copy.

    `os.rename` refuses a non-empty target, which is the ordinary case for a
    content-addressed store: a second extraction of the same bytes lost the
    race and drops its own copy. A target holding no `<digest>.json` published
    nothing -- a run killed between `mkdir` and the record write leaves exactly
    that -- so the partial directory goes and the rename runs again, which
    keeps a crash from making one digest permanently unreadable.
    """
    stored.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.rename(staging, stored)
        return
    except OSError:
        if (stored / f"{stored.name}.json").is_file():
            return
    shutil.rmtree(stored, ignore_errors=True)
    os.rename(staging, stored)


def _kill_group(process: subprocess.Popen[bytes]) -> None:
    """Kill the whole session the worker leads, then reap it."""
    try:
        os.killpg(os.getpgid(process.pid), 9)
    except (OSError, ProcessLookupError):
        pass
    try:
        process.communicate(timeout=KILL_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        process.kill()
        process.communicate()


def _worker_error(returncode: int, stdout: bytes, stderr: bytes) -> str:
    """The worker's own refusal text, or the signal that ended it."""
    try:
        payload: object = json.loads(stdout.decode("utf-8"))
    except ValueError:
        payload = None
    if isinstance(payload, dict):
        error = cast(Mapping[str, object], payload).get("error")
        if isinstance(error, str) and error:
            return error
    if returncode < 0:
        return f"the worker was ended by signal {-returncode}"
    tail = stderr.decode("utf-8", errors="replace").strip().splitlines()
    return tail[-1] if tail else f"the worker exited {returncode}"


def _matcher(query: str, *, regex: bool) -> Callable[[str], list[re.Match[str]]]:
    """Compile the query once; a literal query escapes into the same engine."""
    try:
        pattern = re.compile(query if regex else re.escape(query))
    except re.error as error:
        raise DocumentRefused(
            400, f"the query is not a valid regular expression: {error}"
        ) from None

    def find(body: str) -> list[re.Match[str]]:
        return [found for found in pattern.finditer(body) if found.end() > found.start()]

    return find


def _excerpt(body: str, start: int, end: int) -> str:
    """The line the match sits on, bounded to 400 characters."""
    line_start = body.rfind("\n", 0, start) + 1
    line_end = body.find("\n", end)
    line = body[line_start : line_end if line_end >= 0 else len(body)]
    return line[:EXCERPT_MAX_CHARS]


def _covering(boundaries: Sequence[Boundary], start: int, end: int) -> tuple[str, ...]:
    return tuple(
        f"{boundary.kind}:{boundary.index}"
        for boundary in boundaries
        if boundary.char_start < end and boundary.char_end > start
    )


# --- HTTP routes -------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Upload:
    """One uploaded file: what it is called, what it claims to be, and its bytes."""

    filename: str
    media_type: str
    data: bytes


def parse_upload(request: Request) -> Upload:
    """Read the uploaded file from a multipart body or from the raw body.

    The multipart form is split on the declared boundary rather than parsed by
    the email package, so the file part's bytes reach the store exactly as the
    browser sent them. The raw form takes the whole body and names the file
    through `X-Filename`, which is what a fetch of a File object sends.
    """
    content_type = request.header("content-type")
    if content_type.lower().startswith("multipart/form-data"):
        return _parse_multipart(content_type, request.body)
    name = request.header("x-filename")
    if not name:
        raise DocumentRefused(400, "the request names no file through X-Filename")
    if not request.body:
        raise DocumentRefused(400, "the request carries an empty body")
    return Upload(safe_filename(name), content_type.split(";")[0].strip(), request.body)


def _parse_multipart(content_type: str, body: bytes) -> Upload:
    found = MULTIPART_BOUNDARY_PATTERN.search(content_type)
    if not found:
        raise DocumentRefused(400, "the multipart content type declares no boundary")
    delimiter = b"--" + found.group(1).encode("utf-8")
    for section in body.split(delimiter):
        head, separator, payload = section.partition(b"\r\n\r\n")
        if not separator:
            continue
        headers = _part_headers(head)
        disposition = headers.get("content-disposition", "")
        name = DISPOSITION_FILENAME_PATTERN.search(disposition)
        if not name:
            continue
        data = payload[:-2] if payload.endswith(b"\r\n") else payload
        return Upload(
            safe_filename(name.group(1)),
            headers.get("content-type", "").split(";")[0].strip(),
            data,
        )
    raise DocumentRefused(400, "the multipart body carries no file part")


def _part_headers(head: bytes) -> dict[str, str]:
    headers: dict[str, str] = {}
    for line in head.decode("utf-8", errors="replace").splitlines():
        name, separator, value = line.partition(":")
        if separator:
            headers[name.strip().lower()] = value.strip()
    return headers


def _json(status: int, payload: object) -> Response:
    return Response(
        status,
        json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        {
            "content-type": "application/json",
            "cache-control": "no-store",
            "x-content-type-options": "nosniff",
        },
    )


def _body(request: Request) -> Mapping[str, object]:
    try:
        parsed: object = request.json()
    except ValueError:
        raise DocumentRefused(400, "the request body is not JSON") from None
    if not isinstance(parsed, dict):
        raise DocumentRefused(400, "the request body is not a JSON object")
    return cast(Mapping[str, object], parsed)


def handle_upload(service: DocumentService, request: Request) -> Response:
    """Store one uploaded document and answer with its record."""
    if not service.settings.session_admits(request):
        return _json(401, {"error": "the request carries no admitted session"})
    scratch = service.settings.scratch()
    staged: Path | None = None
    try:
        upload = parse_upload(request)
        if len(upload.data) > service.settings.max_upload_bytes:
            raise DocumentRefused(
                413,
                f"the upload is {len(upload.data)} bytes, past the "
                f"{service.settings.max_upload_bytes}-byte cap",
            )
        scratch.mkdir(parents=True, exist_ok=True)
        staged = scratch / f"upload-{secrets.token_hex(JOB_TOKEN_BYTES)}-{upload.filename}"
        staged.write_bytes(upload.data)
        record = service.extract(staged, upload.media_type, upload.filename)
    except DocumentRefused as refusal:
        return _json(refusal.status, {"error": refusal.message})
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)
    return _json(201, record.to_json())


def handle_record(service: DocumentService, request: Request) -> Response:
    """Answer one stored record, behind the injectable session check."""
    if not service.settings.session_admits(request):
        return _json(401, {"error": "the request carries no admitted session"})
    try:
        record = service.record(request.path_params.get("digest", ""))
    except DocumentRefused as refusal:
        return _json(refusal.status, {"error": refusal.message})
    return _json(200, record.to_json())


def handle_search(service: DocumentService, request: Request) -> Response:
    """Answer one search over one stored document's chunks."""
    if not service.settings.session_admits(request):
        return _json(401, {"error": "the request carries no admitted session"})
    try:
        body = _body(request)
        query = body.get("query")
        if not isinstance(query, str) or not query:
            raise DocumentRefused(400, "query is absent or is not a nonempty string")
        regex = body.get("regex", False)
        if not isinstance(regex, bool):
            raise DocumentRefused(400, "regex is not a boolean")
        digest = request.path_params.get("digest", "")
        hits = service.search(digest, query, regex=regex)
    except DocumentRefused as refusal:
        return _json(refusal.status, {"error": refusal.message})
    return _json(200, {"sha256": digest, "hits": [hit.to_json() for hit in hits]})


def routes(service: DocumentService) -> tuple[Route, ...]:
    """The upload, record, and search routes, each gated by the settings' session check."""
    return (
        Route.make("POST", DOCUMENTS_ROUTE, lambda request: handle_upload(service, request)),
        Route.make("POST", DOCUMENT_SEARCH_ROUTE, lambda request: handle_search(service, request)),
        Route.make("GET", DOCUMENT_ROUTE, lambda request: handle_record(service, request)),
    )


__all__ = [
    "Boundary",
    "Chunk",
    "DocumentRecord",
    "DocumentRefused",
    "DocumentService",
    "DocumentSettings",
    "Limits",
    "SearchHit",
    "Upload",
    "handle_record",
    "handle_search",
    "handle_upload",
    "parse_upload",
    "probe_network_isolation",
    "routes",
    "safe_filename",
]
