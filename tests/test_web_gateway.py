"""The gateway against a fake upstream, both bound to port zero in this process.

Every port comes from the bound server object. A bind-then-close reports a
number that was free at the instant of the read and reserves nothing
afterwards, so two gate cells receive the same number and the second listener
meets EADDRINUSE; reading `Gateway.port` and the fake upstream's own
`server_address` reads a port that is bound for the whole arm.

The fake upstream runs in this process, so the pid and start time
`state/runtime.json` names are this process's own and
`qwen_apu.runtime.health.probe_listener` resolves a real socket inode from
`/proc/<pid>/fd` rather than a stub. `_listening_inodes` reads `/proc/net/tcp`,
which carries IPv4 alone, so the fake upstream binds 127.0.0.1 explicitly.
"""

from __future__ import annotations

import json
import os
import secrets
import socket
import stat
import threading
import time
from collections.abc import Iterator
from http.client import HTTPConnection, HTTPResponse, IncompleteRead
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

from qwen_apu.config import models as registry
from qwen_apu.engines.llama import LlamaClient, UpstreamRefused, binding_from_runtime
from qwen_apu.runtime.process import read_start_time
from qwen_apu.runtime.state import RuntimeRecord, RuntimeState
from qwen_apu.web import auth as auth_module
from qwen_apu.web.app import (
    Gateway,
    GatewayConfig,
    content_security_policy,
    hash_source,
    host_header_names,
)
from qwen_apu.web.auth import (
    PAIRING_ATTEMPT_LIMIT,
    PAIRING_CODE_FILENAME,
    SESSION_COOKIE,
    FixedWindowBucket,
    SessionGate,
)
from qwen_apu.web.chat import PICKER_TIERS, ChatService, quantization
from qwen_apu.web.http import Route, StreamingResponse
from qwen_apu.web.roster import LOADING, READY, REFUSED, UNAVAILABLE
from qwen_apu.web.status import StatusService

EXCHANGE_DEADLINE_SECONDS = 20.0
STREAM_FRAME_INTERVAL_SECONDS = 0.05
SERVED_MODEL = "qwen38-2b-distill"
BEARER_MARKER = "appliance-bearer-8f2c1d4a-never-in-a-response"


def sse_frames(model: str = SERVED_MODEL) -> tuple[bytes, ...]:
    """One frame per token, each naming the model the answer came from."""
    return tuple(
        json.dumps(
            {
                "id": f"chatcmpl-{index}",
                "model": model,
                "choices": [{"index": 0, "delta": {"content": word}}],
            }
        ).encode("utf-8")
        for index, word in enumerate(("one", " two", " three"))
    )


SSE_FRAMES: tuple[bytes, ...] = sse_frames()

INDEX_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>qwen-apu</title>
<style>
body { background: #101014; color: #e8e8ef; }
</style>
</head>
<body>
<div id="log"></div>
<script>
const log = document.getElementById("log");
log.textContent = "gateway";
</script>
</body>
</html>
"""


class _FakeUpstream(BaseHTTPRequestHandler):
    """llama-server's three routes, with the completion streamed frame by frame."""

    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: object) -> None:
        """Keep the fixture's request lines out of the test output."""

    def do_GET(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        if self.path == "/health":
            self._json({"status": "ok"})
        elif self.path == "/v1/models":
            self._json({"object": "list", "data": [{"id": SERVED_MODEL}]})
        else:
            self._json({"error": "no such endpoint"}, status=404)

    def do_POST(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        if self.path == "/tokenize":
            content = json.loads(body).get("content", "")
            self._json({"tokens": list(range(len(content.split())))})
            return
        if self.path != "/v1/chat/completions":
            self._json({"error": "no such endpoint"}, status=404)
            return
        # `model_override` is the one knob a served-model mismatch needs: the
        # deployed server states the model it actually loaded, and a fixture
        # that always echoes the request could never disagree with it.
        served = str(json.loads(body or b"{}").get("model_override") or SERVED_MODEL)
        if json.loads(body or b"{}").get("stream") is False:
            self._json(
                {
                    "id": "chatcmpl-whole",
                    "model": served,
                    "choices": [{"index": 0, "message": {"content": "one two three"}}],
                }
            )
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        for frame in sse_frames(served):
            self.wfile.write(b"data: " + frame + b"\n\n")
            self.wfile.flush()
            time.sleep(STREAM_FRAME_INTERVAL_SECONDS)
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()

    def _json(self, payload: object, status: int = 200) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


@pytest.fixture(scope="module")
def upstream() -> Iterator[ThreadingHTTPServer]:
    server = ThreadingHTTPServer(("127.0.0.1", 0), _FakeUpstream)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05})
    thread.start()
    try:
        yield server
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=EXCHANGE_DEADLINE_SECONDS)


def _upstream_port(server: ThreadingHTTPServer) -> int:
    return int(server.server_address[1])


def _write_runtime_record(state_directory: Path, port: int) -> Path:
    """A record naming this process as the server that owns the upstream socket."""
    state_directory.mkdir(parents=True, exist_ok=True)
    record_path = state_directory / "runtime.json"
    RuntimeRecord(record_path).write(
        RuntimeState(
            state="running",
            server_pid=os.getpid(),
            server_start_time=read_start_time(os.getpid()) or 0,
            port=port,
            model_id=SERVED_MODEL,
            deployment="fixture",
            profile="low-async",
        )
    )
    return record_path


class Fixture:
    """One running gateway, its state directory, and its pairing code."""

    def __init__(self, gateway: Gateway, state: Path, gate: SessionGate, code: str) -> None:
        self.gateway = gateway
        self.state = state
        self.gate = gate
        self.code = code
        self.thread = threading.Thread(target=gateway.serve_forever)
        self.thread.start()

    @property
    def port(self) -> int:
        return self.gateway.port

    def connection(self) -> HTTPConnection:
        return HTTPConnection("127.0.0.1", self.port, timeout=EXCHANGE_DEADLINE_SECONDS)

    def stop(self) -> None:
        self.gateway.shutdown()
        self.thread.join(timeout=EXCHANGE_DEADLINE_SECONDS)


@pytest.fixture
def gateway(tmp_path: Path, upstream: ThreadingHTTPServer) -> Iterator[Fixture]:
    static_root = tmp_path / "webui"
    static_root.mkdir()
    (static_root / "index.html").write_text(INDEX_PAGE, encoding="utf-8")
    (static_root / "app.js").write_text("export const name = 'gateway';\n", encoding="utf-8")
    (tmp_path / "outside.txt").write_text(BEARER_MARKER, encoding="utf-8")

    state = tmp_path / "state"
    record_path = _write_runtime_record(state, _upstream_port(upstream))
    # The appliance bearer and the launch plan that carries the profile
    # environment both sit in the state directory the status route reads from.
    (state / "web-token.key").write_text(f"{BEARER_MARKER}\n", encoding="utf-8")
    (state / "launch-plan.json").write_text(
        json.dumps({"env": {"QWEN_WEB_API_KEY": BEARER_MARKER}}), encoding="utf-8"
    )

    def client_factory() -> LlamaClient:
        binding = binding_from_runtime(record_path, fallback_port=_upstream_port(upstream))
        return LlamaClient(binding)

    gate = SessionGate(state)
    code = gate.start()
    chat = ChatService(client_factory, runtime_record=record_path)
    status = StatusService(client_factory, runtime_record=record_path, session_gate=gate)
    config = GatewayConfig(
        static_root=static_root,
        port=0,
        origins=("http://127.0.0.1:8090",),
    )
    running = Fixture(
        Gateway(config, (gate, chat, status), session_authority=gate), state, gate, code
    )
    try:
        yield running
    finally:
        running.stop()


def _exchange(
    fixture: Fixture,
    method: str,
    path: str,
    *,
    body: bytes | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[HTTPResponse, bytes]:
    connection = fixture.connection()
    try:
        connection.request(method, path, body=body, headers=headers or {})
        response = connection.getresponse()
        return response, response.read()
    finally:
        connection.close()


def _pair(fixture: Fixture, code: str) -> tuple[HTTPResponse, bytes]:
    return _exchange(
        fixture,
        "POST",
        "/api/pair",
        body=json.dumps({"code": code}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )


def _session_cookie(response: HTTPResponse) -> str:
    raw = response.getheader("Set-Cookie") or ""
    return raw.split(";", 1)[0]


# ---------------------------------------------------------------------------
# The static page and its policy
# ---------------------------------------------------------------------------


def test_static_page_is_served_with_its_own_policy(gateway: Fixture) -> None:
    response, body = _exchange(gateway, "GET", "/")
    assert response.status == 200
    assert body == INDEX_PAGE.encode("utf-8")
    assert (response.getheader("Content-Type") or "").startswith("text/html")
    assert response.getheader("X-Content-Type-Options") == "nosniff"
    assert response.getheader("Referrer-Policy") == "no-referrer"
    policy = response.getheader("Content-Security-Policy") or ""
    # The page carries one inline script and one inline style, so the policy
    # names the SHA-256 of each block rather than admitting 'unsafe-inline'.
    inline_script = INDEX_PAGE.split("<script>", 1)[1].split("</script>", 1)[0]
    inline_style = INDEX_PAGE.split("<style>", 1)[1].split("</style>", 1)[0]
    assert hash_source(inline_script.encode("utf-8")) in policy
    assert hash_source(inline_style.encode("utf-8")) in policy
    assert "'unsafe-inline'" not in policy
    assert "frame-ancestors 'none'" in policy


def test_policy_over_a_page_with_no_inline_block_names_self_alone() -> None:
    policy = content_security_policy(b"<!doctype html><html><body>plain</body></html>")
    assert "script-src 'self';" in policy
    assert "sha256-" not in policy


def test_path_traversal_is_refused(gateway: Fixture) -> None:
    for path in ("/../outside.txt", "/%2e%2e/outside.txt", "/..%2foutside.txt"):
        response, body = _exchange(gateway, "GET", path)
        assert response.status == 404, path
        assert BEARER_MARKER.encode("utf-8") not in body, path


def test_a_directory_answers_no_listing(gateway: Fixture) -> None:
    """A directory that holds a file answers 404 under both spellings."""
    nested = gateway.gateway.static.root / "assets"
    nested.mkdir()
    (nested / "note.txt").write_text("nested\n", encoding="utf-8")
    response, _ = _exchange(gateway, "GET", "/assets/note.txt")
    assert response.status == 200
    for path in ("/assets", "/assets/", "/nonexistent/"):
        response, _ = _exchange(gateway, "GET", path)
        assert response.status == 404, path


# ---------------------------------------------------------------------------
# Host and Origin
# ---------------------------------------------------------------------------


def test_host_outside_the_set_is_refused_before_anything_else(gateway: Fixture) -> None:
    """A foreign Host refuses ahead of the pairing route, so no attempt is spent."""
    response, _ = _pair_with_host(gateway, gateway.code, "evil.example")
    assert response.status == 403
    assert gateway.gate.attempts == 0
    # The refusal precedes the body read, so the unread bytes make the
    # connection unusable for a second request and the answer says so.
    assert response.will_close is True
    # The code the foreign-Host request carried is still the live one.
    response, _ = _pair(gateway, gateway.code)
    assert response.status == 200


def _pair_with_host(fixture: Fixture, code: str, host: str) -> tuple[HTTPResponse, bytes]:
    return _exchange(
        fixture,
        "POST",
        "/api/pair",
        body=json.dumps({"code": code}).encode("utf-8"),
        headers={"Content-Type": "application/json", "Host": host},
    )


def test_host_header_strips_the_port_and_unwraps_a_literal() -> None:
    admitted = ("127.0.0.1", "::1", "qwen.local")
    assert host_header_names("127.0.0.1:45311", admitted) == "127.0.0.1"
    assert host_header_names("[::1]:8090", admitted) == "::1"
    assert host_header_names("QWEN.local", admitted) == "qwen.local"
    assert host_header_names("evil.example", admitted) == ""
    assert host_header_names("", admitted) == ""


def test_origin_outside_the_allowlist_gets_no_cors_headers(gateway: Fixture) -> None:
    response, _ = _exchange(
        gateway,
        "OPTIONS",
        "/api/chat",
        headers={"Origin": "http://127.0.0.1:8090", "Access-Control-Request-Method": "POST"},
    )
    assert response.status == 204
    assert response.getheader("Access-Control-Allow-Origin") == "http://127.0.0.1:8090"
    assert response.getheader("Vary") == "Origin"
    # The cookie is SameSite=Strict, so credentials stay unallowed.
    assert response.getheader("Access-Control-Allow-Credentials") is None

    response, _ = _exchange(
        gateway,
        "OPTIONS",
        "/api/chat",
        headers={"Origin": "http://evil.example", "Access-Control-Request-Method": "POST"},
    )
    assert response.status == 403
    assert response.getheader("Access-Control-Allow-Origin") is None


# ---------------------------------------------------------------------------
# Pairing and the session cookie
# ---------------------------------------------------------------------------


def test_unauthenticated_chat_is_refused(gateway: Fixture) -> None:
    response, body = _exchange(
        gateway,
        "POST",
        "/api/chat",
        body=json.dumps({"messages": []}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    assert response.status == 401
    assert b"session" in body


def test_pairing_succeeds_once_and_the_code_is_then_dead(gateway: Fixture) -> None:
    secret = gateway.state / PAIRING_CODE_FILENAME
    assert secret.read_text(encoding="utf-8").strip() == gateway.code
    assert stat.S_IMODE(secret.stat().st_mode) == 0o600

    response, body = _pair(gateway, gateway.code)
    assert response.status == 200
    assert json.loads(body)["paired"] is True
    assert not secret.exists()

    repeated, _ = _pair(gateway, gateway.code)
    assert repeated.status == 403


def test_the_cookie_is_the_only_browser_credential(gateway: Fixture) -> None:
    response, _ = _pair(gateway, gateway.code)
    raw = response.getheader("Set-Cookie") or ""
    assert raw.startswith(f"{SESSION_COOKIE}=")
    assert "HttpOnly" in raw
    assert "SameSite=Strict" in raw
    assert "Path=/" in raw
    # The bind is loopback, so no plaintext hop exists for Secure to close.
    assert "Secure" not in raw
    secure_gate = SessionGate(gateway.state / "secure", secure_cookie=True)
    minted = secrets.token_urlsafe(auth_module.TOKEN_BYTES)
    session = auth_module.Session(token=minted, expiry=0.0, client_address="192.0.2.7")
    assert "Secure" in secure_gate.cookie(session)


def test_the_cookie_admits_the_guarded_routes(gateway: Fixture) -> None:
    paired, _ = _pair(gateway, gateway.code)
    cookie = _session_cookie(paired)
    response, _ = _exchange(gateway, "GET", "/api/models", headers={"Cookie": cookie})
    assert response.status == 200
    response, _ = _exchange(
        gateway, "GET", "/api/models", headers={"Cookie": f"{SESSION_COOKIE}=x"}
    )
    assert response.status == 401


def test_health_passes_the_gate_unguarded(gateway: Fixture) -> None:
    response, body = _exchange(gateway, "GET", "/api/health")
    assert response.status == 200
    report = json.loads(body)
    assert report["gateway"]["pid"] == os.getpid()
    assert report["upstream"]["serving"] is True
    assert report["upstream"]["bound_to_process"] is True


def test_eight_failed_attempts_end_pairing_for_the_process(tmp_path: Path) -> None:
    """The attempt count bounds the guesses; the meter bounds their rate.

    The clock advances one window per attempt, so the fixed window admits
    every one of the eight and the lifetime limit is what refuses the ninth.
    A caller that does not wait meets the three-per-minute bucket first, which
    is the other half of the same gate.
    """
    minutes = iter(1_700_000_000.0 + 60.0 * step for step in range(64))
    gate = SessionGate(tmp_path / "state", clock=lambda: next(minutes))
    code = gate.start()
    request = _local_request(b'{"code": "wrong"}')
    for _ in range(PAIRING_ATTEMPT_LIMIT):
        with pytest.raises(auth_module.RequestRefused):
            gate.pair(request)
    assert gate.attempts == PAIRING_ATTEMPT_LIMIT
    with pytest.raises(auth_module.RequestRefused) as refused:
        gate.pair(_local_request(json.dumps({"code": code}).encode("utf-8")))
    assert "process lifetime" in str(refused.value)


def _local_request(body: bytes) -> auth_module.Request:
    return auth_module.Request(
        method="POST",
        path="/api/pair",
        query={},
        headers={"content-type": "application/json"},
        body=body,
        client_address="127.0.0.1",
    )


def test_the_pairing_meter_is_a_fixed_window(tmp_path: Path) -> None:
    """The bucket is the broker's fixed window, not a rolling refill."""
    bucket = FixedWindowBucket(60, 3)
    now = 1_700_000_000.0 + 12.0
    for _ in range(3):
        bucket.consume("pair-client-minute:127.0.0.1", now)
    with pytest.raises(auth_module.RateLimited) as refused:
        bucket.consume("pair-client-minute:127.0.0.1", now)
    assert refused.value.status == 429
    assert refused.value.retry_after == 60 - int(now) % 60
    # The next window opens at its own close rather than at a smoothed rate.
    bucket.consume("pair-client-minute:127.0.0.1", now + 60)


# ---------------------------------------------------------------------------
# Chat, the roster, and status
# ---------------------------------------------------------------------------


def test_streaming_reaches_the_client_chunk_by_chunk(gateway: Fixture) -> None:
    paired, _ = _pair(gateway, gateway.code)
    cookie = _session_cookie(paired)
    connection = gateway.connection()
    try:
        connection.request(
            "POST",
            "/api/chat",
            body=json.dumps({"model": SERVED_MODEL, "messages": [], "stream": True}).encode(
                "utf-8"
            ),
            headers={"Content-Type": "application/json", "Cookie": cookie},
        )
        response = connection.getresponse()
        assert response.status == 200
        assert (response.getheader("Content-Type") or "").startswith("text/event-stream")
        reads: list[bytes] = []
        deadline = time.monotonic() + EXCHANGE_DEADLINE_SECONDS
        while time.monotonic() < deadline:
            chunk = response.read1(65536)
            if not chunk:
                break
            reads.append(chunk)
    finally:
        connection.close()
    assert len(reads) >= 2, f"the body arrived in {len(reads)} read(s), so it was buffered"
    body = b"".join(reads)
    for frame in SSE_FRAMES:
        assert b"data: " + frame + b"\n\n" in body
    assert body.endswith(b"data: [DONE]\n\n")
    # The served model name is the upstream's own, carried through unrewritten.
    first = json.loads(body.split(b"data: ", 1)[1].split(b"\n\n", 1)[0])
    assert first["model"] == SERVED_MODEL


def test_tokenize_counts_through_the_served_tokenizer(gateway: Fixture) -> None:
    paired, _ = _pair(gateway, gateway.code)
    cookie = _session_cookie(paired)
    body = json.dumps({"model": SERVED_MODEL, "content": "three short words"}).encode("utf-8")
    response, answer = _exchange(
        gateway,
        "POST",
        "/api/models/tokenize",
        body=body,
        headers={"Content-Type": "application/json", "Cookie": cookie},
    )
    assert response.status == 200
    assert json.loads(answer)["tokens"] == [0, 1, 2]

    refused, _ = _exchange(
        gateway,
        "POST",
        "/api/models/tokenize",
        body=json.dumps({"model": SERVED_MODEL}).encode("utf-8"),
        headers={"Content-Type": "application/json", "Cookie": cookie},
    )
    assert refused.status == 400

    unpaired, _ = _exchange(
        gateway,
        "POST",
        "/api/models/tokenize",
        body=body,
        headers={"Content-Type": "application/json"},
    )
    assert unpaired.status == 401


def test_models_roster_is_the_intersection_rather_than_the_registry(gateway: Fixture) -> None:
    """The picker answers what this appliance serves, not what the registry admits.

    The shadow pass read thirteen models against one served checkpoint, because
    the roster came from `remote/models.tsv` alone. The answer here is the join:
    the record names the launched checkpoint, the upstream's `/v1/models` names
    the one it resident, and the registry supplies the row.
    """
    paired, _ = _pair(gateway, gateway.code)
    cookie = _session_cookie(paired)
    rows = registry.load_models()

    response, body = _exchange(gateway, "GET", "/api/models", headers={"Cookie": cookie})
    assert response.status == 200
    answer = json.loads(body)
    assert answer["mode"] == "standalone"
    assert answer["upstream_reachable"] is True
    served = answer["models"]
    assert [entry["id"] for entry in served] == [SERVED_MODEL]
    assert served[0]["state"] == READY
    assert served[0]["served_as"] == SERVED_MODEL
    assert len(served) < len(rows)

    response, body = _exchange(gateway, "GET", "/api/models?research=1", headers={"Cookie": cookie})
    research = json.loads(body)["models"]
    assert {entry["id"] for entry in research} == {row.id for row in rows} | {SERVED_MODEL}
    # Every registry row the launch did not serve states why it is absent from
    # the ordinary answer rather than being silently listed beside the served one.
    unserved = [entry for entry in research if entry["id"] != SERVED_MODEL]
    assert {entry["state"] for entry in unserved} <= {REFUSED, "quarantined"}
    assert {entry["tier"] for entry in served} <= set(PICKER_TIERS)


def test_an_unadmitted_model_is_refused_before_the_upstream(gateway: Fixture) -> None:
    """A model the live router does not admit meets 409 with the reason, not a completion."""
    paired, _ = _pair(gateway, gateway.code)
    cookie = _session_cookie(paired)
    body = json.dumps(
        {"model": "qwen38-9b-distill", "messages": [{"role": "user", "content": "x"}]}
    )
    response, payload = _exchange(
        gateway,
        "POST",
        "/api/chat",
        body=body.encode("utf-8"),
        headers={"Content-Type": "application/json", "Cookie": cookie},
    )
    assert response.status == 409
    assert "does not admit qwen38-9b-distill" in json.loads(payload)["error"]

    response, payload = _exchange(
        gateway,
        "POST",
        "/api/models/tokenize",
        body=json.dumps({"model": "qwen38-9b-distill", "content": "one two"}).encode("utf-8"),
        headers={"Content-Type": "application/json", "Cookie": cookie},
    )
    assert response.status == 409


def test_the_admitted_model_reaches_the_upstream(gateway: Fixture) -> None:
    paired, _ = _pair(gateway, gateway.code)
    cookie = _session_cookie(paired)
    response, payload = _exchange(
        gateway,
        "POST",
        "/api/chat",
        body=json.dumps(
            {"model": SERVED_MODEL, "stream": False, "messages": [{"role": "user", "content": "x"}]}
        ).encode("utf-8"),
        headers={"Content-Type": "application/json", "Cookie": cookie},
    )
    assert response.status == 200
    assert json.loads(payload)["model"] == SERVED_MODEL


def test_a_served_model_other_than_the_selected_one_is_an_error(gateway: Fixture) -> None:
    """A wrong served model is surfaced rather than routed silently.

    Both bodies are checked, because a streamed answer's model name arrives in
    the first frame and a buffered one in the whole object; the streamed case
    must refuse before any byte reaches the browser, since a started chunked
    body leaves truncation as the only remaining signal.
    """
    paired, _ = _pair(gateway, gateway.code)
    cookie = _session_cookie(paired)
    for extra in ({"stream": False}, {}):
        request = {
            "model": SERVED_MODEL,
            "model_override": "some-other-checkpoint",
            "messages": [{"role": "user", "content": "x"}],
            **extra,
        }
        response, payload = _exchange(
            gateway,
            "POST",
            "/api/chat",
            body=json.dumps(request).encode("utf-8"),
            headers={"Content-Type": "application/json", "Cookie": cookie},
        )
        assert response.status == 502, extra
        assert "served some-other-checkpoint" in json.loads(payload)["error"]


def test_an_unreachable_upstream_reports_unavailable_rather_than_ready(
    gateway: Fixture, tmp_path: Path
) -> None:
    """Residency is unknown where the upstream answers nothing, and the state says so."""
    # A directory the gateway fixture never wrote, so the record is absent
    # and the binding falls back to a port nothing serves.
    record = tmp_path / "unsupervised" / "runtime.json"
    dead = ChatService(
        lambda: LlamaClient(binding_from_runtime(record, fallback_port=1)),
        runtime_record=record,
    )
    request = auth_module.Request(
        method="GET",
        path="/api/models",
        query={},
        headers={},
        body=b"",
        client_address="127.0.0.1",
    )
    answer = json.loads(dead.models(request).body)
    assert answer["upstream_reachable"] is False
    assert {entry["state"] for entry in answer["models"]} <= {UNAVAILABLE, REFUSED, LOADING}


def test_quantization_reads_the_publishers_own_filenames() -> None:
    assert quantization("Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf") == "Q4_K_M"
    assert quantization("Qwen3.5-0.8B-GGUF/Qwen3.5-0.8B-F16.gguf") == "F16"
    assert quantization("Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-IQ3_XXS.gguf") == "UD-IQ3_XXS"
    assert quantization("Qwen3.8-4B-Distill-Q2_K-GGUF/Qwen3.8-4B-i1-Q2_K.gguf") == "Q2_K"
    assert quantization("Qwenseer-2B-GGUF/Qwenseer-2B.Q4_K_M.gguf") == "Q4_K_M"
    assert quantization("Some-Model/weights.gguf") == "-"


def test_status_carries_the_runtime_record_and_no_bearer(gateway: Fixture) -> None:
    paired, _ = _pair(gateway, gateway.code)
    cookie = _session_cookie(paired)
    response, body = _exchange(gateway, "GET", "/api/status", headers={"Cookie": cookie})
    assert response.status == 200
    report = json.loads(body)
    assert report["runtime"]["state"] == "running"
    assert report["runtime"]["model_id"] == SERVED_MODEL
    assert report["gateway"]["pairing"]["paired"] is True
    assert report["gateway"]["pairing"]["live_sessions"] == 1
    # The state directory holds the bearer and the launch plan's environment;
    # neither reaches the answer.
    assert BEARER_MARKER.encode("utf-8") not in body
    assert b"env" not in body


def test_health_from_a_routable_peer_presents_a_session(gateway: Fixture) -> None:
    """Every field here is a process identity, so a LAN peer pairs first."""
    service = StatusService(
        lambda: LlamaClient(binding_from_runtime(gateway.state / "runtime.json", fallback_port=1)),
        runtime_record=gateway.state / "runtime.json",
        session_gate=gateway.gate,
    )
    loopback = _probe_request("127.0.0.1")
    assert json.loads(service.health(loopback).body)["gateway"]["pid"] == os.getpid()
    with pytest.raises(auth_module.RequestRefused) as refused:
        service.health(_probe_request("192.0.2.7"))
    assert refused.value.status == 401


def _probe_request(client_address: str) -> auth_module.Request:
    return auth_module.Request(
        method="GET",
        path="/api/health",
        query={},
        headers={},
        body=b"",
        client_address=client_address,
    )


def test_a_session_binds_to_the_address_it_was_issued_for(gateway: Fixture) -> None:
    paired, _ = _pair(gateway, gateway.code)
    cookie = _session_cookie(paired)
    carried = auth_module.Request(
        method="GET",
        path="/api/models",
        query={},
        headers={"cookie": cookie},
        body=b"",
        client_address="127.0.0.1",
    )
    gateway.gate.require_session(carried)
    replayed = auth_module.Request(
        method="GET",
        path="/api/models",
        query={},
        headers={"cookie": cookie},
        body=b"",
        client_address="192.0.2.7",
    )
    with pytest.raises(auth_module.RequestRefused):
        gateway.gate.require_session(replayed)


def test_a_stream_that_fails_mid_body_reaches_the_client_truncated(gateway: Fixture) -> None:
    """A listener that changed identity mid-exchange ends the body unterminated.

    `LlamaClient._read` raises where the closing `probe_listener` names another
    inode, and the bytes already written cannot be recalled, so the gateway
    leaves the terminating zero-length chunk unwritten. `http.client` reads
    that as `IncompleteRead`, which is the signal a complete body would have
    hidden.
    """
    frames = [b"data: one\n\n", b"data: two\n\n"]

    def failing() -> Iterator[bytes]:
        yield from frames
        raise UpstreamRefused("listener inode changed across the exchange: 11 -> 12")

    gateway.gateway.routes = (
        *gateway.gateway.routes,
        Route.make(
            "GET",
            "/api/fixture-stream",
            lambda request: StreamingResponse(
                200, failing(), {"content-type": "text/event-stream"}
            ),
        ),
    )
    paired, _ = _pair(gateway, gateway.code)
    connection = gateway.connection()
    try:
        connection.request(
            "GET", "/api/fixture-stream", headers={"Cookie": _session_cookie(paired)}
        )
        response = connection.getresponse()
        assert response.status == 200
        with pytest.raises(IncompleteRead):
            response.read()
    finally:
        connection.close()


def test_shutdown_leaves_no_listener(gateway: Fixture) -> None:
    port = gateway.port
    response, _ = _exchange(gateway, "GET", "/api/health")
    assert response.status == 200
    gateway.stop()
    # allow_reuse_address is set on HTTPServer, so a successful re-bind proves
    # nothing; a refused connection is the falsifier.
    with pytest.raises(ConnectionRefusedError):
        socket.create_connection(("127.0.0.1", port), timeout=EXCHANGE_DEADLINE_SECONDS).close()
