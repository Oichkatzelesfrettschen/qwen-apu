"""The second listener: llama.cpp's own page proxied to the router on loopback.

The fake upstream reproduces the three behaviors of `server-http.cpp` that
decide whether the proxied page works at all: `handle_gzip_header` answers 415
where `Accept-Encoding` omits gzip and returns the bytes with
`Content-Encoding: gzip` where it names it, `serve_asset_cached` answers 304 to
a matching `If-None-Match`, and the completion route streams SSE frame by
frame. Both listeners run in this process over one `SessionGate`, which is what
lets one pairing be shown to admit both origins.
"""

from __future__ import annotations

import gzip
import json
import os
import threading
import time
from collections.abc import Iterator
from http.client import HTTPConnection, HTTPResponse
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

from qwen_apu.engines.llama import LlamaClient, binding_from_runtime
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.process import read_start_time
from qwen_apu.runtime.state import RuntimeRecord, RuntimeState
from qwen_apu.web import assemble as assemble_module
from qwen_apu.web import llama_ui
from qwen_apu.web.app import Gateway, GatewayConfig
from qwen_apu.web.auth import SessionGate

EXCHANGE_DEADLINE_SECONDS = 10.0
STREAM_FRAME_INTERVAL_SECONDS = 0.05
SERVED_ALIAS = "qwen-apu"
BUILT_IN_PAGE = b"<!doctype html><title>llama.cpp</title><script>window.llama=1;</script>"
BUNDLE_ETAG = '"bundle-1"'
CUSTOM_PAGE_MARKER = b"the custom qwen-apu page"
BUILT_BUNDLE_PAGE = b"<!doctype html><title>built llama.cpp UI</title>\n"
BUILT_BUNDLE_SCRIPT = b"export const built = true;\n"


class _FakeUpstream(BaseHTTPRequestHandler):
    """The routes the built-in page loads, with the asset rules the server applies."""

    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: object) -> None:
        """Keep the fixture's request lines out of the test output."""

    def do_GET(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        if self.path in ("/", "/index.html", "/bundle.abc123.js"):
            self._asset()
            return
        if self.path == "/v1/models":
            self._json({"object": "list", "data": [{"id": SERVED_ALIAS}]})
            return
        if self.path == "/props":
            self._json({"model_path": "fixture.gguf"})
            return
        self._json({"error": "no such asset"}, status=404)

    def do_POST(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        if self.path != "/v1/chat/completions":
            self._json({"error": "no such endpoint"}, status=404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        for index in range(3):
            frame = json.dumps({"model": SERVED_ALIAS, "index": index}).encode("utf-8")
            self.wfile.write(b"data: " + frame + b"\n\n")
            self.wfile.flush()
            time.sleep(STREAM_FRAME_INTERVAL_SECONDS)
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()
        self._body = body

    def _asset(self) -> None:
        """`handle_gzip_header` and the ETag branch of `serve_asset_cached`."""
        if "gzip" not in self.headers.get("Accept-Encoding", ""):
            self._text(415, b"Error: gzip is not supported by this browser")
            return
        if self.headers.get("If-None-Match", "") == BUNDLE_ETAG:
            self.send_response(304)
            self.send_header("ETag", BUNDLE_ETAG)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        payload = gzip.compress(BUILT_IN_PAGE)
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Encoding", "gzip")
        self.send_header("ETag", BUNDLE_ETAG)
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _text(self, status: int, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

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


class _Listener:
    """One gateway running on a thread of this process."""

    def __init__(self, gateway: Gateway) -> None:
        self.gateway = gateway
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


class Fixture:
    """Both listeners over one session gate, with the pairing code unspent."""

    def __init__(self, page: _Listener, proxy: _Listener, gate: SessionGate, code: str) -> None:
        self.page = page
        self.proxy = proxy
        self.gate = gate
        self.code = code

    def stop(self) -> None:
        self.proxy.stop()
        self.page.stop()


def _write_runtime_record(state: Path, port: int) -> Path:
    state.mkdir(parents=True, exist_ok=True)
    record_path = state / "runtime.json"
    RuntimeRecord(record_path).write(
        RuntimeState(
            state="running",
            server_pid=os.getpid(),
            server_start_time=read_start_time(os.getpid()) or 0,
            port=port,
            model_id=SERVED_ALIAS,
            deployment="fixture",
            profile="low-async",
        )
    )
    return record_path


def _build(tmp_path: Path, upstream: ThreadingHTTPServer, assets: Path | None) -> Fixture:
    """Both listeners over one session gate, with the proxy holding `assets` or none."""
    static_root = tmp_path / "static"
    (static_root / llama_ui.PAIRING_PAGE_DIRECTORY).mkdir(parents=True)
    # The custom page's own files, which the proxy listener must never serve.
    (static_root / "index.html").write_bytes(CUSTOM_PAGE_MARKER)
    (static_root / "app.js").write_bytes(CUSTOM_PAGE_MARKER)
    card = static_root / llama_ui.PAIRING_PAGE_DIRECTORY / llama_ui.PAIRING_PAGE_NAME
    card.write_text("<p>pair on the chat page</p>\n", encoding="utf-8")

    state = tmp_path / "state"
    port = int(upstream.server_address[1])
    record_path = _write_runtime_record(state, port)

    def client_factory() -> LlamaClient:
        return LlamaClient(binding_from_runtime(record_path, fallback_port=port))

    gate = SessionGate(state)
    code = gate.start()
    page_gateway = Gateway(
        GatewayConfig(static_root=static_root, port=0, origins=()),
        (gate,),
        session_authority=gate,
    )
    proxy_gateway = Gateway(
        GatewayConfig(static_root=assets or card.parent, port=0, origins=()),
        (
            llama_ui.LlamaUiProxy(
                llama_ui.LlamaUiSettings(
                    client_factory=client_factory,
                    require_session=gate.require_session,
                    pairing_page=card,
                    assets=assets,
                )
            ),
        ),
    )
    return Fixture(_Listener(page_gateway), _Listener(proxy_gateway), gate, code)


@pytest.fixture
def listeners(tmp_path: Path, upstream: ThreadingHTTPServer) -> Iterator[Fixture]:
    running = _build(tmp_path, upstream, None)
    try:
        yield running
    finally:
        running.stop()


def _request(
    listener: _Listener,
    method: str,
    path: str,
    *,
    body: bytes | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[HTTPResponse, bytes]:
    connection = listener.connection()
    sent = {"Host": f"127.0.0.1:{listener.port}", **(headers or {})}
    if body is not None:
        sent.setdefault("Content-Type", "application/json")
    connection.request(method, path, body=body, headers=sent)
    response = connection.getresponse()
    return response, response.read()


def _pair(fixture: Fixture) -> str:
    """Pair on the page listener and return the cookie header a browser resends."""
    response, _ = _request(
        fixture.page,
        "POST",
        "/api/pair",
        body=json.dumps({"code": fixture.code}).encode("utf-8"),
    )
    assert response.status == 200
    jar = SimpleCookie()
    jar.load(response.getheader("set-cookie") or "")
    token = jar["qwen_apu_session"].value
    return f"qwen_apu_session={token}"


def test_an_unpaired_page_load_answers_the_pairing_card(listeners: Fixture) -> None:
    """GET / without a session states where a session is minted."""
    response, body = _request(listeners.proxy, "GET", "/")
    assert response.status == 401
    assert b"pair on the chat page" in body
    assert response.getheader("content-type", "").startswith("text/html")
    assert "worker-src 'self'" in (response.getheader("content-security-policy") or "")


def test_an_unpaired_api_request_is_refused_rather_than_carded(listeners: Fixture) -> None:
    """Every path but the page root meets the gate's own 401.

    `SessionGate.guards` names `/api/` alone, so the proxy rather than the
    gateway's authority is what refuses a router path here.
    """
    response, body = _request(listeners.proxy, "GET", "/v1/models")
    assert response.status == 401
    assert b"no live session" in body


def test_one_pairing_on_the_page_origin_admits_the_second_listener(
    listeners: Fixture,
) -> None:
    """One `SessionGate` backs both listeners, so the cookie crosses the port."""
    cookie = _pair(listeners)
    response, body = _request(
        listeners.proxy,
        "GET",
        "/",
        headers={"Cookie": cookie, "Accept-Encoding": "gzip"},
    )
    assert response.status == 200
    assert response.getheader("content-encoding") == "gzip"
    assert gzip.decompress(body) == BUILT_IN_PAGE


def test_the_page_bytes_pass_through_unrewritten(listeners: Fixture) -> None:
    """The served body is the upstream's own, and the asset name reaches it.

    `handle_gzip_header` answers 415 to a request whose `Accept-Encoding` omits
    gzip, so the forwarded header is what makes the page load at all.
    """
    cookie = _pair(listeners)
    response, body = _request(
        listeners.proxy,
        "GET",
        "/bundle.abc123.js",
        headers={"Cookie": cookie, "Accept-Encoding": "gzip"},
    )
    assert response.status == 200
    assert gzip.decompress(body) == BUILT_IN_PAGE
    assert response.getheader("etag") == BUNDLE_ETAG

    plain, refusal = _request(listeners.proxy, "GET", "/index.html", headers={"Cookie": cookie})
    assert plain.status == 415
    assert b"gzip is not supported" in refusal


def test_a_matching_validator_answers_304(listeners: Fixture) -> None:
    """`If-None-Match` travels up and the 304 travels back with its ETag."""
    cookie = _pair(listeners)
    response, body = _request(
        listeners.proxy,
        "GET",
        "/index.html",
        headers={"Cookie": cookie, "Accept-Encoding": "gzip", "If-None-Match": BUNDLE_ETAG},
    )
    assert response.status == 304
    assert body == b""
    assert response.getheader("etag") == BUNDLE_ETAG


def test_an_api_round_trip_reaches_the_router(listeners: Fixture) -> None:
    cookie = _pair(listeners)
    response, body = _request(listeners.proxy, "GET", "/v1/models", headers={"Cookie": cookie})
    assert response.status == 200
    assert json.loads(body)["data"][0]["id"] == SERVED_ALIAS

    props, payload = _request(listeners.proxy, "GET", "/props", headers={"Cookie": cookie})
    assert props.status == 200
    assert json.loads(payload)["model_path"] == "fixture.gguf"


def test_a_completion_streams_frame_by_frame(listeners: Fixture) -> None:
    """Each SSE frame reaches the client as the upstream flushed it.

    The read deadline is shorter than the whole stream, so a body that arrived
    buffered would leave the first read empty rather than carrying one frame.
    """
    cookie = _pair(listeners)
    connection = listeners.proxy.connection()
    connection.request(
        "POST",
        "/v1/chat/completions",
        body=json.dumps({"stream": True, "messages": []}).encode("utf-8"),
        headers={
            "Host": f"127.0.0.1:{listeners.proxy.port}",
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "Cookie": cookie,
        },
    )
    response = connection.getresponse()
    assert response.status == 200
    assert response.getheader("content-type") == "text/event-stream"
    assert response.getheader("transfer-encoding") == "chunked"
    arrivals: list[float] = []
    frames: list[bytes] = []
    start = time.monotonic()
    while len(frames) < 3:
        chunk = response.read1(4096)
        if not chunk:
            break
        arrivals.append(time.monotonic() - start)
        frames.extend(line for line in chunk.split(b"\n") if line.startswith(b"data: "))
    connection.close()
    assert len(frames) >= 3
    assert b'"index": 0' in frames[0]
    assert arrivals[-1] > arrivals[0]


def test_an_unadmitted_path_is_refused_before_the_upstream(listeners: Fixture) -> None:
    """The routes that change server state stay behind this listener."""
    cookie = _pair(listeners)
    for method, path in (
        ("POST", "/models/load"),
        ("POST", "/props"),
        ("POST", "/slots/0"),
        ("GET", "/one/two/three/four"),
    ):
        response, body = _request(
            listeners.proxy,
            method,
            path,
            body=b"{}" if method == "POST" else None,
            headers={"Cookie": cookie},
        )
        assert response.status == 404, f"{method} {path} was not refused"
        assert b"through this listener" in body


def test_the_custom_pages_own_files_stay_off_this_listener(listeners: Fixture) -> None:
    """A catch-all route keeps every path out of the gateway's static branch."""
    cookie = _pair(listeners)
    for path in ("/app.js", "/index.html"):
        response, body = _request(
            listeners.proxy,
            "GET",
            path,
            headers={"Cookie": cookie, "Accept-Encoding": "gzip"},
        )
        assert CUSTOM_PAGE_MARKER not in body
        assert response.status in (200, 404)


def test_the_admitted_set_names_the_servers_own_routes() -> None:
    """The table mirrors `tools/server/server.cpp` rather than an inferred shape."""
    assert llama_ui.path_is_admitted("GET", "/health")
    assert llama_ui.path_is_admitted("POST", "/v1/chat/completions")
    assert llama_ui.path_is_admitted("GET", "/_app/version.json")
    assert not llama_ui.path_is_admitted("POST", "/models/unload")
    assert not llama_ui.path_is_admitted("PUT", "/props")
    assert not llama_ui.path_is_admitted("GET", "/../etc/passwd")
    assert not llama_ui.path_is_admitted("GET", "/a/b/c/d")


# ---------------------------------------------------------------------------
# The built bundle, served from disk ahead of the proxy
# ---------------------------------------------------------------------------


@pytest.fixture
def bundle(tmp_path: Path) -> Path:
    """The `tools/ui` output `remote/build-llama-ui.sh` lays under the runtime root."""
    root = tmp_path / "opt" / "llama-ui" / "dist"
    (root / "assets").mkdir(parents=True)
    (root / "index.html").write_bytes(BUILT_BUNDLE_PAGE)
    (root / "assets" / "bundle.abc123.js").write_bytes(BUILT_BUNDLE_SCRIPT)
    (root / "sw.js").write_bytes(b"self.addEventListener('install', () => {});\n")
    (root / "manifest.webmanifest").write_bytes(b'{"name":"llama.cpp"}\n')
    (tmp_path / "outside.txt").write_bytes(b"outside the bundle\n")
    return root


@pytest.fixture
def served(tmp_path: Path, upstream: ThreadingHTTPServer, bundle: Path) -> Iterator[Fixture]:
    """The same two listeners, with the proxy holding the built bundle."""
    running = _build(tmp_path, upstream, bundle)
    try:
        yield running
    finally:
        running.stop()


def test_the_built_bundle_is_served_from_disk_ahead_of_the_proxy(
    served: Fixture, bundle: Path
) -> None:
    """The page and its hashed asset come off disk with the server's own headers.

    The upstream would answer `/` with its own gzipped fixture page, so the
    bytes name which side served the request.
    """
    cookie = _pair(served)
    page, body = _request(
        served.proxy, "GET", "/", headers={"Cookie": cookie, "Accept-Encoding": "gzip"}
    )
    assert page.status == 200
    assert body == BUILT_BUNDLE_PAGE
    assert page.getheader("content-type") == "text/html; charset=utf-8"
    assert page.getheader("cache-control") == llama_ui.REVALIDATE_CACHE_CONTROL
    assert page.getheader("cross-origin-embedder-policy") == "require-corp"
    assert page.getheader("cross-origin-opener-policy") == "same-origin"

    asset, script = _request(
        served.proxy, "GET", "/assets/bundle.abc123.js", headers={"Cookie": cookie}
    )
    assert script == BUILT_BUNDLE_SCRIPT
    assert asset.getheader("content-type") == "text/javascript; charset=utf-8"
    assert asset.getheader("cache-control") == llama_ui.IMMUTABLE_CACHE_CONTROL

    manifest, _ = _request(served.proxy, "GET", "/manifest.webmanifest", headers={"Cookie": cookie})
    assert manifest.getheader("content-type") == "application/manifest+json"
    assert manifest.getheader("cache-control") == llama_ui.REVALIDATE_CACHE_CONTROL


def test_a_bundle_asset_answers_304_to_its_own_validator(served: Fixture) -> None:
    cookie = _pair(served)
    first, body = _request(served.proxy, "GET", "/index.html", headers={"Cookie": cookie})
    tag = first.getheader("etag")
    assert tag == llama_ui.asset_entity_tag(body)
    again, empty = _request(
        served.proxy, "GET", "/index.html", headers={"Cookie": cookie, "If-None-Match": tag}
    )
    assert again.status == 304
    assert empty == b""


def test_a_traversal_out_of_the_bundle_is_refused(served: Fixture) -> None:
    """`StaticDirectory.resolve` unquotes before containment, so no escape resolves.

    A path that names nothing inside the bundle falls to the proxy, and the
    router answers for it, so the refusal is read as the absence of the file
    outside rather than as a served one.
    """
    cookie = _pair(served)
    for path in ("/../outside.txt", "/%2e%2e/outside.txt", "/assets/../../outside.txt"):
        response, body = _request(served.proxy, "GET", path, headers={"Cookie": cookie})
        assert b"outside the bundle" not in body
        assert response.status == 404


def test_a_path_the_bundle_lacks_still_reaches_the_router(served: Fixture) -> None:
    """The bundle takes precedence and the proxy keeps every path it does not hold."""
    cookie = _pair(served)
    response, body = _request(served.proxy, "GET", "/v1/models", headers={"Cookie": cookie})
    assert response.status == 200
    assert json.loads(body)["data"][0]["id"] == SERVED_ALIAS


def test_an_unpaired_load_answers_the_card_rather_than_the_bundle(served: Fixture) -> None:
    """The session gate stands ahead of every file the bundle holds."""
    response, body = _request(served.proxy, "GET", "/")
    assert response.status == 401
    assert b"pair on the chat page" in body

    asset, _ = _request(served.proxy, "GET", "/assets/bundle.abc123.js")
    assert asset.status == 401


def test_an_absent_bundle_leaves_every_path_to_the_router(listeners: Fixture) -> None:
    """A launch whose directory holds no page proxies the root as before."""
    cookie = _pair(listeners)
    response, body = _request(
        listeners.proxy, "GET", "/", headers={"Cookie": cookie, "Accept-Encoding": "gzip"}
    )
    assert response.status == 200
    assert gzip.decompress(body) == BUILT_IN_PAGE


def test_the_assembly_reads_the_runtime_roots_bundle_where_a_build_left_one(
    tmp_path: Path,
) -> None:
    """The default is `opt/llama-ui/dist`, and a named directory without a page refuses."""
    paths = RuntimePaths(tree=Path(__file__).resolve().parents[1], root=tmp_path / "runtime")
    paths.lay_out()
    request = assemble_module.GatewayRequest(port=8090, llama_ui_port=42072)
    assert assemble_module.llama_ui_assets(paths, request) is None

    derived = paths["qwen_home_opt"] / "llama-ui" / "dist"
    derived.mkdir(parents=True)
    (derived / "index.html").write_bytes(BUILT_BUNDLE_PAGE)
    assert assemble_module.llama_ui_assets(paths, request) == derived

    empty = tmp_path / "named"
    empty.mkdir()
    with pytest.raises(ValueError, match="carries no index.html"):
        assemble_module.llama_ui_assets(
            paths,
            assemble_module.GatewayRequest(port=8090, llama_ui_port=42072, llama_ui_static=empty),
        )
