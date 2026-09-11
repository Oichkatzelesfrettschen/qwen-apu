"""The artifact mount, the control-socket client, and the image tool routes.

Every artifact case states its refusal in the listener's own order, because the
order is the property: a Host outside the set answers before a credential is
read, a credential answers before an existence lookup, the meter charges an
authenticated reader alone, the digest pattern refuses a name no normalization
pass touched, and the publication marker decides last. A case that asserts a
status therefore also asserts which check produced it, by presenting a request
that would answer differently under any other ordering.

The artifact directory is built the way `remote/image-service.py` builds one:
two content-addressed files and one atomic `.publication-<job>.json` marker
naming both. The uncommitted pair writes the same two files and no marker,
which is `test_uncommitted_artifact_pair_is_not_reachable` from the shell
suite. The gateway reads that directory and writes nothing in it, so the
worker's legacy recovery and its retention sweep stay the worker's.

The control socket is a thread holding one AF_UNIX listener that answers one
line per connection, the worker's own ControlHandler shape. Its responder
returns raw bytes so a reply outside the closed schema and a reply past the
65536-byte line bound are both expressible.
"""

from __future__ import annotations

import hashlib
import json
import os
import socket
import sys
import threading
import time
from collections.abc import Callable, Iterator, Mapping
from pathlib import Path

import pytest

from qwen_apu.config import models as config_models
from qwen_apu.engines.image import (
    ImageControlClient,
    ProtocolRefused,
    ServiceUnreachable,
    protocol,
    short_socket_address,
)
from qwen_apu.tools import images as image_tools
from qwen_apu.tools.images import ImageToolSettings, ToolRefused
from qwen_apu.web.artifacts import (
    ArtifactDirectory,
    ArtifactSettings,
    FixedWindowLimiter,
    read_artifact,
    read_index,
    routes,
)
from qwen_apu.web.assemble import GatewayRequest, review_model_for
from qwen_apu.web.http import Request, Response, match

API_KEY = "test-artifact-key"
CLIENT = "127.0.0.1"
REVIEW_MODEL = "lfm25-vl-16b"
PROMPT = "a chart of four bars"
PROMPT_SHA256 = hashlib.sha256(PROMPT.encode("utf-8")).hexdigest()

# A one-pixel PNG stands in for a generated artifact: the gateway serves bytes
# by digest and validates none of them, which is the worker's own step.
PNG_BYTES = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108020000009077"
    "3dda0000000c4944415408d763f8cfc00000030101007a5b8c4a0000000049454e44ae426082"
)


def provenance_body(png_digest: str, prompt_sha256: str = PROMPT_SHA256) -> bytes:
    """The provenance record, serialized the way `finish_artifact` writes it."""
    record = {
        "schema": "qwen-image-provenance/1",
        "job_id": "0" * 16,
        "png_sha256": png_digest,
        "prompt_sha256": prompt_sha256,
        "negative_prompt_sha256": hashlib.sha256(b"").hexdigest(),
        "profile_id": "image-sdxs-512-a",
        "seed": 7,
        "width": 512,
        "height": 512,
        "steps": 4,
    }
    return json.dumps(record, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def publish(directory: Path, png: bytes, job_id: str, prompt_sha256: str = PROMPT_SHA256) -> str:
    """Write one PNG, its provenance, and the marker committing the pair."""
    png_digest = hashlib.sha256(png).hexdigest()
    body = provenance_body(png_digest, prompt_sha256)
    provenance_digest = hashlib.sha256(body).hexdigest()
    (directory / f"{png_digest}.png").write_bytes(png)
    (directory / f"{provenance_digest}.json").write_bytes(body)
    marker = {
        "schema": "qwen-image-publication/1",
        "job_id": job_id,
        "png_sha256": png_digest,
        "provenance_sha256": provenance_digest,
    }
    (directory / f".publication-{job_id}.json").write_bytes(
        json.dumps(marker, sort_keys=True, separators=(",", ":")).encode("utf-8") + b"\n"
    )
    return png_digest


def stage_uncommitted(directory: Path, png: bytes) -> str:
    """Write both files of a pair and no marker, which commits nothing."""
    png_digest = hashlib.sha256(png).hexdigest()
    (directory / f"{png_digest}.png").write_bytes(png)
    body = provenance_body(png_digest)
    (directory / f"{hashlib.sha256(body).hexdigest()}.json").write_bytes(body)
    return png_digest


@pytest.fixture
def artifacts(tmp_path: Path) -> Path:
    directory = tmp_path / "artifacts"
    directory.mkdir()
    return directory


@pytest.fixture
def published(artifacts: Path) -> str:
    return publish(artifacts, PNG_BYTES, "aabbccdd")


@pytest.fixture
def uncommitted(artifacts: Path) -> str:
    return stage_uncommitted(artifacts, PNG_BYTES + b"\x00")


def settings_for(directory: Path, **overrides: object) -> ArtifactSettings:
    fields: dict[str, object] = {
        "directory": directory,
        "api_key": API_KEY,
        "limiter": FixedWindowLimiter(),
    }
    fields.update(overrides)
    return ArtifactSettings(**fields)  # type: ignore[arg-type]


def get(
    name: str,
    *,
    host: str = "127.0.0.1",
    bearer: str | None = API_KEY,
    query: Mapping[str, str] | None = None,
    client: str = CLIENT,
) -> Request:
    headers = {"host": host}
    if bearer is not None:
        headers["authorization"] = f"Bearer {bearer}"
    return Request(
        method="GET",
        path=f"/api/artifacts/{name}",
        query=query or {},
        headers=headers,
        body=b"",
        client_address=client,
        path_params={"name": name},
    )


def index_request(*, host: str = "127.0.0.1", bearer: str | None = API_KEY) -> Request:
    headers = {"host": host}
    if bearer is not None:
        headers["authorization"] = f"Bearer {bearer}"
    return Request("GET", "/api/artifacts", {}, headers, b"", CLIENT)


def payload(response: Response) -> object:
    return json.loads(response.body.decode("utf-8"))


def test_the_committed_pair_serves_under_the_immutable_header_set(
    artifacts: Path, published: str
) -> None:
    settings = settings_for(artifacts)
    response = read_artifact(settings, get(f"{published}.png"))
    assert response.status == 200
    assert hashlib.sha256(response.body).hexdigest() == published
    assert response.headers["content-type"] == "image/png"
    assert response.headers["cache-control"] == "private, max-age=31536000, immutable"
    assert response.headers["etag"] == f'"{published}"'
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["content-disposition"] == f'inline; filename="{published}.png"'

    marker = json.loads((artifacts / ".publication-aabbccdd.json").read_text())
    record = read_artifact(settings, get(f"{marker['provenance_sha256']}.json"))
    assert record.status == 200
    assert record.headers["content-type"] == "application/json"
    assert json.loads(record.body)["png_sha256"] == published


def test_a_present_and_an_absent_digest_answer_401_alike(artifacts: Path, published: str) -> None:
    """The credential runs ahead of the lookup, so the route is no existence oracle."""
    settings = settings_for(artifacts)
    for name in (f"{published}.png", f"{'0' * 64}.png"):
        response = read_artifact(settings, get(name, bearer=None))
        assert response.status == 401, name
        assert response.body == b""
        assert response.headers["www-authenticate"] == 'Bearer realm="qwen-image"'
        assert response.headers["cache-control"] == "no-store"


def test_the_host_set_refuses_ahead_of_the_credential(artifacts: Path, published: str) -> None:
    """A Host outside the set answers 403 whether or not a bearer is present."""
    settings = settings_for(artifacts)
    for bearer in (API_KEY, None):
        response = read_artifact(
            settings, get(f"{published}.png", host="attacker.example", bearer=bearer)
        )
        assert response.status == 403
        assert "admitted literal" in str(payload(response))


def test_the_admitted_host_set_reads_a_port_and_an_ipv6_literal(
    artifacts: Path, published: str
) -> None:
    settings = settings_for(artifacts)
    assert read_artifact(settings, get(f"{published}.png", host="127.0.0.1:8080")).status == 200
    assert read_artifact(settings, get(f"{published}.png", host="[::1]:8080")).status == 200


def test_an_exposure_literal_joins_the_admitted_set_and_no_other(
    artifacts: Path, published: str
) -> None:
    """`--lan-exposure` adds exactly one literal; the set stays closed around it."""
    exposed = settings_for(artifacts, admitted_hosts=("127.0.0.1", "::1", "192.0.2.10"))
    assert read_artifact(exposed, get(f"{published}.png", host="192.0.2.10:8080")).status == 200
    assert read_artifact(exposed, get(f"{published}.png", host="192.0.2.11")).status == 403
    default = settings_for(artifacts)
    assert read_artifact(default, get(f"{published}.png", host="192.0.2.10")).status == 403


def test_a_query_parameter_carries_no_authority(artifacts: Path, published: str) -> None:
    settings = settings_for(artifacts)
    response = read_artifact(settings, get(f"{published}.png", bearer=None, query={"key": API_KEY}))
    assert response.status == 401


def test_an_unset_key_admits_nothing(artifacts: Path, published: str) -> None:
    """An empty expectation never becomes an open route."""
    settings = settings_for(artifacts, api_key="")
    assert read_artifact(settings, get(f"{published}.png", bearer="")).status == 401
    assert read_artifact(settings, get(f"{published}.png", bearer=None)).status == 401


def test_the_session_callable_admits_where_the_bearer_is_absent(
    artifacts: Path, published: str
) -> None:
    """The default refuses; an injected session admits without a bearer."""
    assert (
        read_artifact(settings_for(artifacts), get(f"{published}.png", bearer=None)).status == 401
    )
    admitting = settings_for(artifacts, session_admits=lambda request: True)
    assert read_artifact(admitting, get(f"{published}.png", bearer=None)).status == 200


def test_reads_are_bounded_per_client(artifacts: Path, published: str) -> None:
    settings = settings_for(artifacts, limiter=FixedWindowLimiter(limit=2))
    for _ in range(2):
        assert read_artifact(settings, get(f"{published}.png")).status == 200
    throttled = read_artifact(settings, get(f"{published}.png"))
    assert throttled.status == 429
    retry_after = int(throttled.headers["retry-after"])
    assert 0 < retry_after <= 60
    # A second client holds its own bucket.
    assert read_artifact(settings, get(f"{published}.png", client="127.0.0.2")).status == 200


def test_an_unauthenticated_reader_never_reaches_the_meter(artifacts: Path, published: str) -> None:
    """A flood answers the constant-cost 401 rather than a 429 that would leak metering."""
    settings = settings_for(artifacts, limiter=FixedWindowLimiter(limit=1))
    assert read_artifact(settings, get(f"{published}.png")).status == 200
    assert read_artifact(settings, get(f"{published}.png")).status == 429
    for _ in range(3):
        assert read_artifact(settings, get(f"{published}.png", bearer=None)).status == 401


def test_a_name_outside_the_digest_form_is_refused_after_the_credential(
    artifacts: Path,
) -> None:
    settings = settings_for(artifacts)
    outside = (
        "../../etc/passwd",
        "%2e%2e%2fetc%2fpasswd",
        "report.png",
        "0" * 63 + ".png",
        "0" * 64 + ".gif",
        "0" * 64,
        "",
    )
    for name in outside:
        response = read_artifact(settings, get(name))
        assert response.status == 404, name
        assert "<sha256>.png" in str(payload(response)), name
        # The same name unauthenticated answers 401, which places the pattern
        # refusal behind the credential rather than ahead of it.
        assert read_artifact(settings, get(name, bearer=None)).status == 401, name


def test_an_uncommitted_pair_is_unreachable(artifacts: Path, uncommitted: str) -> None:
    """Files become readable through one atomic marker and never by lying in the directory."""
    settings = settings_for(artifacts)
    response = read_artifact(settings, get(f"{uncommitted}.png"))
    assert response.status == 404
    assert payload(response) == {"error": "no such artifact"}
    body = provenance_body(uncommitted)
    orphan = hashlib.sha256(body).hexdigest()
    assert read_artifact(settings, get(f"{orphan}.json")).status == 404


def test_a_marker_whose_partner_left_commits_nothing(artifacts: Path, published: str) -> None:
    """Retention removes a digest's bytes; the marker alone reaches no artifact."""
    marker = json.loads((artifacts / ".publication-aabbccdd.json").read_text())
    (artifacts / f"{marker['provenance_sha256']}.json").unlink()
    settings = settings_for(artifacts)
    assert read_artifact(settings, get(f"{published}.png")).status == 404
    assert json.loads(read_index(settings, index_request()).body)["artifacts"] == []


def test_the_index_lists_the_committed_pair_alone(
    artifacts: Path, published: str, uncommitted: str
) -> None:
    settings = settings_for(artifacts)
    response = read_index(settings, index_request())
    assert response.status == 200
    assert response.headers["cache-control"] == "no-store"
    listed = json.loads(response.body)["artifacts"]
    assert [entry["png_sha256"] for entry in listed] == [published]
    assert listed[0]["png_url"] == f"/api/artifacts/{published}.png"
    assert listed[0]["provenance_url"].startswith("/api/artifacts/")
    assert listed[0]["job_id"] == "aabbccdd"
    assert uncommitted not in json.dumps(listed)


def test_the_index_runs_the_same_refusal_prefix(artifacts: Path, published: str) -> None:
    settings = settings_for(artifacts, limiter=FixedWindowLimiter(limit=1))
    assert read_index(settings, index_request(host="attacker.example")).status == 403
    assert read_index(settings, index_request(bearer=None)).status == 401
    assert read_index(settings, index_request()).status == 200
    assert read_index(settings, index_request()).status == 429


def test_the_index_orders_newest_first(artifacts: Path) -> None:
    first = publish(artifacts, PNG_BYTES, "job00001")
    second = publish(artifacts, PNG_BYTES + b"\x01", "job00002")
    marker = artifacts / ".publication-job00001.json"
    older = time.time() - 600
    os.utime(marker, (older, older))
    listed = json.loads(read_index(settings_for(artifacts), index_request()).body)["artifacts"]
    assert [entry["png_sha256"] for entry in listed] == [second, first]


def test_the_two_routes_are_disjoint_and_the_bare_slash_reaches_the_pattern(
    artifacts: Path, published: str
) -> None:
    """`routes()` mounts the index and the catch-all read, and matching never 404s a name."""
    mounted = routes(settings_for(artifacts))
    index = match(mounted, "GET", "/api/artifacts")
    assert index is not None and index[1] == {}
    for path, name in (
        (f"/api/artifacts/{published}.png", f"{published}.png"),
        ("/api/artifacts/", ""),
        ("/api/artifacts/../../etc/passwd", "../../etc/passwd"),
    ):
        found = match(mounted, "GET", path)
        assert found is not None, path
        assert found[1] == {"name": name}
    assert routes() != ()
    # The mount serves reads and nothing that changes state.
    for method in ("POST", "PUT", "DELETE"):
        assert match(mounted, method, f"/api/artifacts/{published}.png") is None, method
        assert match(mounted, method, "/api/artifacts") is None, method


def test_routes_resolve_without_settings() -> None:
    """Another module may call `routes()` zero-arg; the default mount answers rather
    than raising."""
    mounted = routes()
    found = match(mounted, "GET", "/api/artifacts/" + "0" * 64 + ".png")
    assert found is not None
    route, params = found
    response = route.handler(get("0" * 64 + ".png", bearer=None))
    assert isinstance(response, Response)
    assert response.status == 401


def test_the_directory_reader_skips_a_malformed_marker(artifacts: Path, published: str) -> None:
    (artifacts / ".publication-broken.json").write_text("{ not json")
    reader = ArtifactDirectory(artifacts)
    assert [entry.png_sha256 for entry in reader.publications()] == [published]


# The control socket.


class ControlFixture:
    """One AF_UNIX listener answering a single line per connection."""

    def __init__(self, directory: Path, responder: Callable[[Mapping[str, object]], bytes]) -> None:
        self.path = directory / "image-service.sock"
        self.received: list[Mapping[str, object]] = []
        self._responder = responder
        self._listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        address, descriptor = short_socket_address(self.path)
        try:
            self._listener.bind(address)
        finally:
            os.close(descriptor)
        self._listener.listen(4)
        self._listener.settimeout(0.2)
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._serve, name="fake-image-control", daemon=True)
        self._thread.start()

    def _serve(self) -> None:
        cap: int = protocol().MAX_LINE_BYTES
        while not self._stop.is_set():
            try:
                connection, _ = self._listener.accept()
            except TimeoutError:
                continue
            except OSError:
                return
            with connection, connection.makefile("rb") as stream:
                line = stream.readline(cap + 1)
                if not line:
                    continue
                request = json.loads(line.decode("utf-8"))
                self.received.append(request)
                connection.sendall(self._responder(request))

    def close(self) -> None:
        self._stop.set()
        self._listener.close()
        self._thread.join(timeout=5)


def completed_reply(request: Mapping[str, object]) -> bytes:
    digest = hashlib.sha256(PNG_BYTES).hexdigest()
    provenance = hashlib.sha256(provenance_body(digest)).hexdigest()
    return (
        json.dumps(
            {
                "protocol_version": 1,
                "request_id": request["request_id"],
                "status": "completed",
                "sha256": digest,
                "provenance_url": f"/artifacts/{provenance}.json",
                "artifact_url": f"/artifacts/{digest}.png",
                "job_id": "aabbccdd",
                "bytes": len(PNG_BYTES),
                "seconds": 11.3,
            }
        )
        + "\n"
    ).encode("utf-8")


@pytest.fixture
def control(tmp_path: Path) -> Iterator[ControlFixture]:
    fixture = ControlFixture(tmp_path, completed_reply)
    try:
        yield fixture
    finally:
        fixture.close()


def generation_frame(**overrides: object) -> dict[str, object]:
    frame: dict[str, object] = {
        "request_id": "req0001",
        "profile_id": "image-sdxs-512-a",
        "prompt": PROMPT,
        "negative_prompt": "",
        "seed": 7,
        "width": 512,
        "height": 512,
        "steps": 4,
        "aspect": "square",
        "authorization": "grant-token",
    }
    frame.update(overrides)
    return frame


def test_generate_names_the_frame_and_returns_the_completed_reply(
    control: ControlFixture,
) -> None:
    client = ImageControlClient(control.path, timeout=5.0)
    reply = client.generate(generation_frame())
    assert reply["status"] == "completed"
    assert reply["sha256"] == hashlib.sha256(PNG_BYTES).hexdigest()
    sent = control.received[0]
    assert sent["protocol_version"] == 1
    assert sent["action"] == "image_generate"
    assert sent["authorization"] == "grant-token"


def test_a_request_outside_the_closed_schema_never_reaches_the_socket(
    control: ControlFixture,
) -> None:
    client = ImageControlClient(control.path, timeout=5.0)
    with pytest.raises(ProtocolRefused) as refusal:
        client.generate(generation_frame(sampler="euler_a"))
    assert "sampler" in str(refusal.value)
    assert control.received == []


def test_an_aspect_disagreeing_with_the_geometry_is_refused(control: ControlFixture) -> None:
    client = ImageControlClient(control.path, timeout=5.0)
    with pytest.raises(ProtocolRefused):
        client.generate(generation_frame(aspect="portrait"))
    assert control.received == []


def test_a_reply_outside_the_closed_schema_is_refused(tmp_path: Path) -> None:
    def responder(request: Mapping[str, object]) -> bytes:
        return (
            json.dumps(
                {
                    "protocol_version": 1,
                    "request_id": request["request_id"],
                    "status": "accepted",
                    "queue_position": 3,
                }
            )
            + "\n"
        ).encode("utf-8")

    fixture = ControlFixture(tmp_path, responder)
    try:
        with pytest.raises(ProtocolRefused) as refusal:
            ImageControlClient(fixture.path, timeout=5.0).status("req0001")
        assert "queue_position" in str(refusal.value)
    finally:
        fixture.close()


def test_a_reply_past_the_line_bound_is_refused(tmp_path: Path) -> None:
    def responder(request: Mapping[str, object]) -> bytes:
        cap: int = protocol().MAX_LINE_BYTES
        return b"{" + b"x" * (cap + 16) + b"}\n"

    fixture = ControlFixture(tmp_path, responder)
    try:
        with pytest.raises(ProtocolRefused) as refusal:
            ImageControlClient(fixture.path, timeout=5.0).status("req0001")
        assert "bytes" in str(refusal.value)
    finally:
        fixture.close()


def test_a_reply_naming_another_request_is_refused(tmp_path: Path) -> None:
    def responder(request: Mapping[str, object]) -> bytes:
        return (
            json.dumps({"protocol_version": 1, "request_id": "other", "status": "accepted"}) + "\n"
        ).encode("utf-8")

    fixture = ControlFixture(tmp_path, responder)
    try:
        with pytest.raises(ProtocolRefused, match="another request"):
            ImageControlClient(fixture.path, timeout=5.0).status("req0001")
    finally:
        fixture.close()


def test_cancel_and_status_name_a_job_and_describe_none(control: ControlFixture) -> None:
    def responder(request: Mapping[str, object]) -> bytes:
        return (
            json.dumps(
                {
                    "protocol_version": 1,
                    "request_id": request["request_id"],
                    "status": "accepted",
                    "state": "idle",
                    "lease_held": False,
                }
            )
            + "\n"
        ).encode("utf-8")

    control._responder = responder  # noqa: SLF001 -- the fixture is this test's own
    client = ImageControlClient(control.path, timeout=5.0)
    assert client.status("req0001")["state"] == "idle"
    assert client.cancel("req0002")["status"] == "accepted"
    assert [sorted(frame) for frame in control.received] == [
        ["action", "protocol_version", "request_id"],
        ["action", "protocol_version", "request_id"],
    ]
    assert [frame["action"] for frame in control.received] == ["status", "cancel"]


def test_an_absent_socket_reports_the_service_unreachable(tmp_path: Path) -> None:
    client = ImageControlClient(tmp_path / "image-service.sock", timeout=1.0)
    with pytest.raises(ServiceUnreachable, match="unreachable"):
        client.status("req0001")


# The image tool routes.


def tool_request(path: str, body: Mapping[str, object]) -> Request:
    return Request(
        "POST",
        path,
        {},
        {"host": "127.0.0.1", "content-type": "application/json"},
        json.dumps(body).encode("utf-8"),
        CLIENT,
    )


def tool_settings(
    artifacts_directory: Path, control_path: Path, **overrides: object
) -> ImageToolSettings:
    fields: dict[str, object] = {
        "client": ImageControlClient(control_path, timeout=5.0),
        "artifacts": ArtifactDirectory(artifacts_directory),
        "review_model": REVIEW_MODEL,
        "verify_generation": lambda request: {"profile_id": request["profile_id"]},
        "verify_grant": lambda token: {
            "prompt_hash": PROMPT_SHA256,
            "grant_id": "g-" + token[:8],
            "expiry": 4102444800.0,
        },
        "spend_grant": SpendRecorder(),
    }
    fields.update(overrides)
    return ImageToolSettings(**fields)  # type: ignore[arg-type]


GENERATE_BODY: Mapping[str, object] = {
    "profile_id": "image-sdxs-512-a",
    "prompt": PROMPT,
    "negative_prompt": "",
    "seed": 7,
    "width": 512,
    "height": 256,
    "steps": 4,
    "authorization": "grant-token",
}


class SpendRecorder:
    """A ledger stand-in: the first spend of a grant succeeds, a replay refuses."""

    def __init__(self) -> None:
        self.spent: list[tuple[str, float]] = []

    def __call__(self, grant_id: str, expiry: float) -> None:
        if any(seen == grant_id for seen, _ in self.spent):
            raise RuntimeError(f"grant {grant_id} was already spent")
        self.spent.append((grant_id, expiry))


def test_generate_spends_the_grant_once_and_refuses_the_replay(
    artifacts: Path, control: ControlFixture
) -> None:
    recorder = SpendRecorder()
    settings = tool_settings(artifacts, control.path, spend_grant=recorder)
    body = GENERATE_BODY
    first = image_tools.generate(settings, tool_request("/api/tools/image/generate", body))
    second = image_tools.generate(settings, tool_request("/api/tools/image/generate", body))
    assert isinstance(first, Response) and first.status == 200, first.body
    assert isinstance(second, Response) and second.status == 403
    assert b"already spent" in second.body
    assert len(recorder.spent) == 1


def test_generate_refuses_without_a_ledger(artifacts: Path, control: ControlFixture) -> None:
    settings = tool_settings(artifacts, control.path)
    object.__setattr__(settings, "spend_grant", image_tools._ledger_absent)  # noqa: SLF001
    reply = image_tools.generate(settings, tool_request("/api/tools/image/generate", GENERATE_BODY))
    assert isinstance(reply, Response) and reply.status == 503
    assert b"binds no ledger" in reply.body


def test_generate_forwards_the_job_and_answers_on_the_gateway_mount(
    artifacts: Path, control: ControlFixture
) -> None:
    seen: list[Mapping[str, object]] = []

    def verifier(request: Mapping[str, object]) -> Mapping[str, object]:
        seen.append(request)
        return {"profile_id": request["profile_id"]}

    settings = tool_settings(artifacts, control.path, verify_generation=verifier)
    body = {
        "profile_id": "image-sdxs-512-a",
        "prompt": PROMPT,
        "negative_prompt": "",
        "seed": 7,
        "width": 512,
        "height": 256,
        "steps": 4,
        "authorization": "grant-token",
    }
    response = image_tools.generate(settings, tool_request("/api/tools/image/generate", body))
    assert response.status == 200
    answered = json.loads(response.body)
    digest = hashlib.sha256(PNG_BYTES).hexdigest()
    assert answered["sha256"] == digest
    assert answered["artifact_url"] == f"/api/artifacts/{digest}.png"
    assert answered["provenance_url"].startswith("/api/artifacts/")
    assert answered["provenance_url"].endswith(".json")
    # The verifier receives the job as the worker receives it, aspect included.
    assert seen[0]["aspect"] == "landscape"
    assert control.received[0]["aspect"] == "landscape"


def test_an_absent_generation_field_is_refused_before_the_verifier(
    artifacts: Path, control: ControlFixture
) -> None:
    """The verifier indexes its arguments directly, so the shape check runs first."""
    called: list[object] = []
    settings = tool_settings(
        artifacts,
        control.path,
        verify_generation=lambda request: called.append(request) or {},
    )
    body = {"profile_id": "image-sdxs-512-a", "prompt": PROMPT, "authorization": "grant-token"}
    response = image_tools.generate(settings, tool_request("/api/tools/image/generate", body))
    assert response.status == 400
    assert "negative_prompt" in str(json.loads(response.body))
    assert called == []
    assert control.received == []


def test_a_boolean_seed_is_refused(artifacts: Path, control: ControlFixture) -> None:
    settings = tool_settings(artifacts, control.path)
    body = {
        "profile_id": "image-sdxs-512-a",
        "prompt": PROMPT,
        "negative_prompt": "",
        "seed": True,
        "width": 512,
        "height": 512,
        "steps": 4,
        "authorization": "grant-token",
    }
    response = image_tools.generate(settings, tool_request("/api/tools/image/generate", body))
    assert response.status == 400
    assert "seed" in str(json.loads(response.body))


def test_a_refused_grant_answers_403(artifacts: Path, control: ControlFixture) -> None:
    def refusing(request: Mapping[str, object]) -> Mapping[str, object]:
        raise ValueError("the generation arguments leave the grant: seed differs")

    settings = tool_settings(artifacts, control.path, verify_generation=refusing)
    body = {
        "profile_id": "image-sdxs-512-a",
        "prompt": PROMPT,
        "negative_prompt": "",
        "seed": 7,
        "width": 512,
        "height": 512,
        "steps": 4,
        "authorization": "grant-token",
    }
    response = image_tools.generate(settings, tool_request("/api/tools/image/generate", body))
    assert response.status == 403
    assert "leave the grant" in str(json.loads(response.body))
    assert control.received == []


def test_a_service_refusal_reaches_the_caller_as_a_bad_gateway(
    artifacts: Path, tmp_path: Path
) -> None:
    def responder(request: Mapping[str, object]) -> bytes:
        return (
            json.dumps(
                {
                    "protocol_version": 1,
                    "request_id": request["request_id"],
                    "status": "refused",
                    "reason": "lease_unavailable",
                    "error": "the Vulkan workload lease is held",
                }
            )
            + "\n"
        ).encode("utf-8")

    fixture = ControlFixture(tmp_path, responder)
    try:
        settings = tool_settings(artifacts, fixture.path)
        body = {
            "profile_id": "image-sdxs-512-a",
            "prompt": PROMPT,
            "negative_prompt": "",
            "seed": 7,
            "width": 512,
            "height": 512,
            "steps": 4,
            "authorization": "grant-token",
        }
        response = image_tools.generate(settings, tool_request("/api/tools/image/generate", body))
        assert response.status == 502
        assert "lease" in str(json.loads(response.body))
    finally:
        fixture.close()


CONSTRAINTS = [{"name": "four_bars", "description": "the chart shows exactly four bars"}]


def verdict_document(content: str) -> dict[str, object]:
    return {"choices": [{"message": {"content": content}}]}


def review_body(digest: str, **overrides: object) -> dict[str, object]:
    body: dict[str, object] = {
        "authorization": "grant-token",
        "sha256": digest,
        "constraints": CONSTRAINTS,
    }
    body.update(overrides)
    return body


def test_a_review_reply_parses_into_completion_schema_and_judgment(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    sent: list[Mapping[str, object]] = []
    verdict = {
        "hard_constraints": [
            {"name": "four_bars", "passed": False, "observation": "the chart shows three bars"}
        ],
        "composition_change_required": False,
        "prompt_delta": "draw four bars",
        "regenerate": True,
    }

    def router(request: Mapping[str, object]) -> object:
        sent.append(request)
        return verdict_document(json.dumps(verdict))

    settings = tool_settings(artifacts, control.path, router=router)
    response = image_tools.review(
        settings, tool_request("/api/tools/image/review", review_body(published))
    )
    assert response.status == 200
    findings = json.loads(response.body)
    assert findings["completion"]["answered"] is True
    assert findings["completion"]["refusal_code"] is None
    assert findings["schema_validity"]["valid"] is True
    assert findings["schema_validity"]["verdict"]["regenerate"] is True
    assert findings["judgment"]["failed"] == ["four_bars"]
    assert findings["judgment"]["correction_admitted"] is True
    assert findings["model"] == REVIEW_MODEL
    assert findings["prompt_hash"] == PROMPT_SHA256
    # The request reaches the router in image-review.py's own shape.
    assert sent[0]["model"] == REVIEW_MODEL
    assert "tools" not in sent[0]
    assert sent[0]["max_tokens"] == 400
    assert sent[0]["response_format"]["json_schema"]["schema"]["required"] == [
        "hard_constraints",
        "composition_change_required",
        "prompt_delta",
        "regenerate",
    ]


def test_a_completed_reply_that_fails_the_schema_reports_the_three_fields_apart(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    """A grammar-bounded reply that still fails the parser is itself the finding."""
    settings = tool_settings(
        artifacts,
        control.path,
        router=lambda request: verdict_document("the image looks fine to me"),
    )
    response = image_tools.review(
        settings, tool_request("/api/tools/image/review", review_body(published))
    )
    assert response.status == 200
    findings = json.loads(response.body)
    assert findings["completion"]["answered"] is True
    assert findings["completion"]["raw_reply"] == "the image looks fine to me"
    assert findings["schema_validity"]["valid"] is False
    assert findings["schema_validity"]["refusal_code"] == "not_json"
    assert findings["judgment"] is None


def test_a_reply_carrying_no_message_reports_an_incomplete_completion(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    settings = tool_settings(artifacts, control.path, router=lambda request: {"choices": []})
    findings = json.loads(
        image_tools.review(
            settings, tool_request("/api/tools/image/review", review_body(published))
        ).body
    )
    assert findings["completion"]["answered"] is False
    assert findings["completion"]["refusal_code"] == "reply_choice_count"
    assert findings["schema_validity"]["valid"] is False
    assert findings["judgment"] is None


def test_a_grant_signed_over_another_prompt_is_refused(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    settings = tool_settings(
        artifacts,
        control.path,
        verify_grant=lambda token: {"prompt_hash": "1" * 64},
        router=lambda request: verdict_document("{}"),
    )
    response = image_tools.review(
        settings, tool_request("/api/tools/image/review", review_body(published))
    )
    assert response.status == 403
    assert "another generation prompt" in str(json.loads(response.body))


def test_a_review_of_an_uncommitted_artifact_is_refused(
    artifacts: Path, control: ControlFixture, uncommitted: str
) -> None:
    settings = tool_settings(artifacts, control.path, router=lambda request: verdict_document("{}"))
    response = image_tools.review(
        settings, tool_request("/api/tools/image/review", review_body(uncommitted))
    )
    assert response.status == 404


def test_a_review_naming_an_unregistered_reviewer_is_refused(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    settings = tool_settings(artifacts, control.path, router=lambda request: verdict_document("{}"))
    response = image_tools.review(
        settings,
        tool_request("/api/tools/image/review", review_body(published, model="qwen38-2b-distill")),
    )
    assert response.status == 400
    assert REVIEW_MODEL in str(json.loads(response.body))


def test_a_constraint_declaration_outside_the_reviewer_rules_is_refused(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    """The CLI's own parser exits the process on these, so the route states them itself."""
    settings = tool_settings(artifacts, control.path, router=lambda request: verdict_document("{}"))
    for constraints in (
        [],
        [{"name": "FourBars", "description": "x"}],
        [{"name": "four_bars", "description": ""}],
        [{"name": "four_bars", "description": "x"}, {"name": "four_bars", "description": "y"}],
        [{"name": "four_bars", "description": "x" * 201}],
        [{"name": f"c{index}", "description": "x"} for index in range(9)],
    ):
        response = image_tools.review(
            settings,
            tool_request(
                "/api/tools/image/review", review_body(published, constraints=constraints)
            ),
        )
        assert response.status == 400, constraints


def test_an_absent_router_refuses_rather_than_raising(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    settings = ImageToolSettings(
        client=ImageControlClient(control.path, timeout=5.0),
        artifacts=ArtifactDirectory(artifacts),
        review_model=REVIEW_MODEL,
        verify_generation=lambda request: {},
        verify_grant=lambda token: {"prompt_hash": PROMPT_SHA256},
    )
    response = image_tools.review(
        settings, tool_request("/api/tools/image/review", review_body(published))
    )
    assert response.status == 503


def test_a_malformed_tool_body_is_refused(artifacts: Path, control: ControlFixture) -> None:
    settings = tool_settings(artifacts, control.path)
    for body in (b"not json", b"[1,2,3]"):
        request = Request(
            "POST", "/api/tools/image/generate", {}, {"host": "127.0.0.1"}, body, CLIENT
        )
        assert image_tools.generate(settings, request).status == 400


def test_the_tool_routes_mount_under_the_api_prefix(
    artifacts: Path, control: ControlFixture
) -> None:
    mounted = image_tools.routes(tool_settings(artifacts, control.path))
    assert match(mounted, "POST", "/api/tools/image/generate") is not None
    assert match(mounted, "POST", "/api/tools/image/review") is not None
    assert match(mounted, "GET", "/api/tools/image/generate") is None


def test_tool_refused_carries_its_status() -> None:
    refusal = ToolRefused(409, "the provenance record names another PNG digest")
    assert refusal.status == 409
    assert refusal.message in str(refusal)


def test_the_frozen_frame_loads_once_under_its_own_name() -> None:
    """One module object serves every reader, so one `ProtocolError` class does too.

    `remote/web-mcp/image_grant.py` reaches `image_protocol` through a
    `sys.path` insert. Registering the by-path load under the same name is what
    makes that import bind this object rather than a second one, where an
    `except ProtocolError` raised by one would pass uncaught through the other.
    """
    frozen = protocol()
    assert sys.modules["image_protocol"] is frozen
    assert protocol() is frozen
    grant = image_tools.grant_module()
    assert grant.image_protocol is frozen
    assert grant.IMAGE_CLAIM_CONTEXT == "qwen-image-generate-v1"


def test_the_review_module_states_the_verdict_keys_this_route_reports() -> None:
    """The three fields split `image-review.py`'s own closed schema, not a copy of it."""
    module = image_tools.review_module()
    assert module.VERDICT_KEYS == (
        "hard_constraints",
        "composition_change_required",
        "prompt_delta",
        "regenerate",
    )
    assert module.MAX_CONSTRAINTS == 8
    assert module.CONSTRAINT_DESCRIPTION_MAX_CHARS == 200


# The image control routes: status, cancel, and remove.


def admitting(directory: Path, control_path: Path, **overrides: object) -> ImageToolSettings:
    """Tool settings whose session gate admits, the way the assembled gateway wires it."""
    fields: dict[str, object] = {"session_admits": lambda request: True}
    fields.update(overrides)
    return tool_settings(directory, control_path, **fields)


def observation_reply(**observation: object) -> Callable[[Mapping[str, object]], bytes]:
    """A control responder answering one observation for every control action."""

    def responder(request: Mapping[str, object]) -> bytes:
        frame: dict[str, object] = {
            "protocol_version": 1,
            "request_id": request["request_id"],
            "status": "accepted",
        }
        frame.update(observation)
        return (json.dumps(frame) + "\n").encode("utf-8")

    return responder


def test_a_control_route_without_a_session_is_refused(
    artifacts: Path, control: ControlFixture
) -> None:
    """The default gate refuses, so an unwired mount exposes no worker state."""
    settings = tool_settings(artifacts, control.path)
    for path, body in (
        (image_tools.STATUS_ROUTE, {"request_id": "req0001"}),
        (image_tools.CANCEL_ROUTE, {"request_id": "req0001"}),
        (image_tools.REMOVE_ROUTE, {"sha256": "0" * 64}),
    ):
        handler = {
            image_tools.STATUS_ROUTE: image_tools.status,
            image_tools.CANCEL_ROUTE: image_tools.cancel,
            image_tools.REMOVE_ROUTE: image_tools.remove,
        }[path]
        response = handler(settings, tool_request(path, body))
        assert response.status == 401, path
        assert b"gateway session" in response.body
    assert control.received == []


def test_status_reports_the_workers_observation(artifacts: Path, tmp_path: Path) -> None:
    fixture = ControlFixture(
        tmp_path,
        observation_reply(
            state="running",
            job_id="aabbccdd",
            job_request_id="req0001",
            lease_held=True,
            elapsed_seconds=3.5,
            pid=4242,
        ),
    )
    try:
        settings = admitting(artifacts, fixture.path)
        response = image_tools.status(
            settings, tool_request(image_tools.STATUS_ROUTE, {"request_id": "req0001"})
        )
        assert response.status == 200, response.body
        payload = json.loads(response.body.decode("utf-8"))
        assert payload["state"] == "running"
        assert payload["lease_held"] is True
        assert payload["pid"] == 4242
        assert [frame["action"] for frame in fixture.received] == ["status"]
        # The status frame names a job and describes none.
        assert sorted(fixture.received[0]) == ["action", "protocol_version", "request_id"]
    finally:
        fixture.close()


def test_status_drops_a_key_outside_the_protocols_observation_set(
    artifacts: Path, tmp_path: Path
) -> None:
    """The answer is built from the closed set, so an unknown key reaches no page."""
    fixture = ControlFixture(tmp_path, observation_reply(state="idle", lease_held=False))
    try:
        settings = admitting(artifacts, fixture.path)
        response = image_tools.status(
            settings, tool_request(image_tools.STATUS_ROUTE, {"request_id": "req0001"})
        )
        payload = json.loads(response.body.decode("utf-8"))
        assert set(payload) <= {"status", *image_tools.OBSERVATION_KEYS}
    finally:
        fixture.close()


@pytest.mark.parametrize("request_id", ["", "req 0001", "x" * 65, "req/0001"])
def test_a_malformed_request_id_is_refused_before_the_socket(
    artifacts: Path, control: ControlFixture, request_id: str
) -> None:
    settings = admitting(artifacts, control.path)
    response = image_tools.status(
        settings, tool_request(image_tools.STATUS_ROUTE, {"request_id": request_id})
    )
    assert response.status == 400
    assert control.received == []


def test_cancel_ends_the_job_and_reports_the_lease_the_worker_observes(
    artifacts: Path, tmp_path: Path
) -> None:
    replies: list[bytes] = []

    def responder(request: Mapping[str, object]) -> bytes:
        if request["action"] == "cancel":
            frame: dict[str, object] = {
                "protocol_version": 1,
                "request_id": request["request_id"],
                "status": "accepted",
                "job_id": "aabbccdd",
                "cancelled": True,
            }
        else:
            frame = {
                "protocol_version": 1,
                "request_id": request["request_id"],
                "status": "accepted",
                "state": "idle",
                "lease_held": False,
            }
        line = (json.dumps(frame) + "\n").encode("utf-8")
        replies.append(line)
        return line

    fixture = ControlFixture(tmp_path, responder)
    try:
        settings = admitting(artifacts, fixture.path)
        response = image_tools.cancel(
            settings, tool_request(image_tools.CANCEL_ROUTE, {"request_id": "req0001"})
        )
        assert response.status == 200, response.body
        payload = json.loads(response.body.decode("utf-8"))
        assert payload["cancelled"] is True
        assert payload["lease_held"] is False
        assert payload["state"] == "idle"
        assert [frame["action"] for frame in fixture.received] == ["cancel", "status"]
    finally:
        fixture.close()


def test_cancelling_a_job_that_is_not_running_answers_its_term(
    artifacts: Path, tmp_path: Path
) -> None:
    """`handle_cancel` refuses a stale identifier as `not_running`, which is an answer."""

    def responder(request: Mapping[str, object]) -> bytes:
        if request["action"] == "cancel":
            frame: dict[str, object] = {
                "protocol_version": 1,
                "request_id": request["request_id"],
                "status": "refused",
                "reason": "not_running",
                "error": "the cancel names a job that is not running",
            }
        else:
            frame = {
                "protocol_version": 1,
                "request_id": request["request_id"],
                "status": "accepted",
                "state": "idle",
                "lease_held": False,
            }
        return (json.dumps(frame) + "\n").encode("utf-8")

    fixture = ControlFixture(tmp_path, responder)
    try:
        settings = admitting(artifacts, fixture.path)
        response = image_tools.cancel(
            settings, tool_request(image_tools.CANCEL_ROUTE, {"request_id": "req0002"})
        )
        assert response.status == 200
        payload = json.loads(response.body.decode("utf-8"))
        assert payload["reason"] == "not_running"
        assert payload["cancelled"] is False
        assert payload["lease_held"] is False
    finally:
        fixture.close()


def test_a_control_call_against_an_absent_socket_reports_the_service_unreachable(
    artifacts: Path, tmp_path: Path
) -> None:
    settings = admitting(artifacts, tmp_path / "image-service.sock")
    response = image_tools.status(
        settings, tool_request(image_tools.STATUS_ROUTE, {"request_id": "req0001"})
    )
    assert response.status == 503
    assert b"unreachable" in response.body


def test_remove_retracts_the_marker_and_retains_the_payload(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    settings = admitting(artifacts, control.path)
    directory = ArtifactDirectory(artifacts)
    assert directory.read(published, "png") is not None
    provenance = directory.committed(published, "png")
    assert provenance is not None

    response = image_tools.remove(
        settings, tool_request(image_tools.REMOVE_ROUTE, {"sha256": published})
    )
    assert response.status == 200, response.body
    payload = json.loads(response.body.decode("utf-8"))
    assert payload["removed"] is True
    assert payload["png_sha256"] == published
    assert payload["payload_retained"] is True

    # Both files of the pair read 404 from the next read onward.
    assert directory.read(published, "png") is None
    assert directory.read(provenance.provenance_sha256, "json") is None
    # The worker owns the payload, so the bytes stay for its retention sweep.
    assert (artifacts / f"{published}.png").is_file()
    assert (artifacts / f"{provenance.provenance_sha256}.json").is_file()
    # The route reaches the worker at no point: version 1 admits three actions
    # and none of them deletes an artifact.
    assert control.received == []


def test_removing_an_uncommitted_or_absent_artifact_answers_no_such_artifact(
    artifacts: Path, control: ControlFixture, uncommitted: str
) -> None:
    settings = admitting(artifacts, control.path)
    for digest in (uncommitted, "b" * 64):
        response = image_tools.remove(
            settings, tool_request(image_tools.REMOVE_ROUTE, {"sha256": digest})
        )
        assert response.status == 404, digest
        assert b"no such artifact" in response.body


def test_removing_twice_answers_the_second_call_as_absent(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    settings = admitting(artifacts, control.path)
    body = {"sha256": published}
    assert image_tools.remove(settings, tool_request(image_tools.REMOVE_ROUTE, body)).status == 200
    assert image_tools.remove(settings, tool_request(image_tools.REMOVE_ROUTE, body)).status == 404


def test_remove_refuses_a_name_that_is_not_a_digest(
    artifacts: Path, control: ControlFixture
) -> None:
    """Traversal, uppercase hex, and a short name each answer 400 before any unlink."""
    settings = admitting(artifacts, control.path)
    for name in ("../secret", "AB" * 32, "0" * 63):
        response = image_tools.remove(
            settings, tool_request(image_tools.REMOVE_ROUTE, {"sha256": name})
        )
        assert response.status == 400, name
    assert sorted(path.name for path in artifacts.iterdir()) == []


# The lease the worker holds, released by a cancel this gateway sends.


def refusing_reply(request: Mapping[str, object]) -> bytes:
    return (
        json.dumps(
            {
                "protocol_version": 1,
                "request_id": request["request_id"],
                "status": "failed",
                "reason": "runtime_failed",
                "error": "the runtime left before it wrote an artifact",
            }
        )
        + "\n"
    ).encode("utf-8")


def test_a_failed_generation_sends_one_cancel_for_its_own_job(
    artifacts: Path, tmp_path: Path
) -> None:
    fixture = ControlFixture(tmp_path, refusing_reply)
    try:
        settings = admitting(artifacts, fixture.path)
        response = image_tools.generate(
            settings, tool_request("/api/tools/image/generate", GENERATE_BODY)
        )
        assert response.status == 502
        actions = [frame["action"] for frame in fixture.received]
        assert actions == ["image_generate", "cancel"]
        # The cancel names the job this gateway opened and no other.
        assert fixture.received[1]["request_id"] == fixture.received[0]["request_id"]
    finally:
        fixture.close()


def test_a_timed_out_generation_sends_one_cancel_for_its_own_job(
    artifacts: Path, tmp_path: Path
) -> None:
    """A worker that answers nothing leaves the lease held until a cancel reaches it."""
    seen: list[Mapping[str, object]] = []
    path = tmp_path / "image-service.sock"
    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    address, descriptor = short_socket_address(path)
    try:
        listener.bind(address)
    finally:
        os.close(descriptor)
    listener.listen(4)
    listener.settimeout(0.5)
    stop = threading.Event()

    def serve() -> None:
        cap: int = protocol().MAX_LINE_BYTES
        while not stop.is_set():
            try:
                connection, _ = listener.accept()
            except (TimeoutError, OSError):
                continue
            with connection, connection.makefile("rb") as stream:
                line = stream.readline(cap + 1)
                if not line:
                    continue
                request = json.loads(line.decode("utf-8"))
                seen.append(request)
                if request["action"] == "image_generate":
                    # The generation answers nothing, which is what a stalled
                    # runtime looks like from this side of the socket.
                    continue
                connection.sendall(
                    (
                        json.dumps(
                            {
                                "protocol_version": 1,
                                "request_id": request["request_id"],
                                "status": "accepted",
                                "cancelled": True,
                            }
                        )
                        + "\n"
                    ).encode("utf-8")
                )

    worker = threading.Thread(target=serve, name="stalled-image-control", daemon=True)
    worker.start()
    try:
        settings = admitting(artifacts, path, client=ImageControlClient(path, timeout=0.5))
        response = image_tools.generate(
            settings, tool_request("/api/tools/image/generate", GENERATE_BODY)
        )
        assert response.status == 503, response.body
        assert [frame["action"] for frame in seen] == ["image_generate", "cancel"]
        assert seen[1]["request_id"] == seen[0]["request_id"]
    finally:
        stop.set()
        listener.close()
        worker.join(timeout=5)


def test_a_reviewer_failure_leaves_the_grant_spent_and_takes_no_lease(
    artifacts: Path, control: ControlFixture, published: str
) -> None:
    """A review holds no lease and spends no grant, so a failure releases nothing.

    The grant the generation spent is gone whatever the reviewer answers, which
    is the property `_spend` establishes between admission and dispatch; the
    review route verifies the claim and spends nothing of its own.
    """
    recorder = SpendRecorder()

    def failing_router(payload: Mapping[str, object]) -> object:
        raise RuntimeError("the router refused the reviewer")

    settings = admitting(artifacts, control.path, router=failing_router, spend_grant=recorder)
    response = image_tools.review(
        settings, tool_request(image_tools.REVIEW_ROUTE, review_body(published))
    )
    assert response.status == 502
    assert recorder.spent == []
    assert control.received == []


def test_the_five_workflow_routes_mount_under_the_gateway(
    artifacts: Path, control: ControlFixture
) -> None:
    mounted = image_tools.routes(admitting(artifacts, control.path))
    for path in (
        image_tools.GENERATE_ROUTE,
        image_tools.REVIEW_ROUTE,
        image_tools.STATUS_ROUTE,
        image_tools.CANCEL_ROUTE,
        image_tools.REMOVE_ROUTE,
    ):
        assert match(mounted, "POST", path) is not None, path
        assert match(mounted, "GET", path) is None, path


# The reviewer the launch runs, resolved from the profile that produced the artifact.


def test_the_reviewer_comes_from_the_armed_image_profiles_ledger_row() -> None:
    served = next(
        row for row in config_models.load_image_profiles() if row.review_model is not None
    )
    resolved = review_model_for(GatewayRequest(port=1, image_profile=served.profile_id))
    assert resolved == served.review_model


def test_a_profile_naming_no_reviewer_leaves_the_review_route_without_one() -> None:
    """`-` offers no review, so the reviewer stays empty rather than falling back."""
    silent = next(row for row in config_models.load_image_profiles() if row.review_model is None)
    assert review_model_for(GatewayRequest(port=1, image_profile=silent.profile_id)) == ""


def test_an_unarmed_image_lane_names_no_reviewer() -> None:
    assert review_model_for(GatewayRequest(port=1)) == ""


def test_an_explicit_reviewer_overrides_the_ledger() -> None:
    served = next(
        row for row in config_models.load_image_profiles() if row.review_model is not None
    )
    named = review_model_for(
        GatewayRequest(port=1, image_profile=served.profile_id, review_model="qwen35-4b")
    )
    assert named == "qwen35-4b"


def test_an_unknown_image_profile_names_no_reviewer() -> None:
    assert review_model_for(GatewayRequest(port=1, image_profile="image-absent")) == ""
