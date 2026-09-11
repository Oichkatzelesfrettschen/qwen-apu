"""The one-origin gateway: one listener, one Host set, one Origin allowlist.

`remote/web-mcp/authorize-broker.py` holds the rules this server reproduces.
Its `host_header_names` compares the Host header against a closed set, because
a browser that resolves an attacker-controlled name to a bound address reaches
the socket with that name and the bind alone leaves DNS rebinding open; its
`do_POST` runs that check ahead of every meter, so a request naming no
admitted literal is a constant-cost refusal that spends no bucket unit, and
runs the credential check ahead of the meter, so an unauthenticated peer draws
no unit a legitimate caller also spends from. `_dispatch` applies both orders:
Host, then Origin, then the route, then the session, then the handler.

`REQUEST_BODY_BYTE_CAP` bounds the body every route reads whole. A route
declared `streams=True` reads the socket itself through `Request.stream`
under the bound it states, so an upload route admits a body the JSON routes
refuse while the cap keeps its position ahead of every other handler.

A handler returns a `Response` whole or a `StreamingResponse` whose chunks
this server writes as chunked transfer encoding with a flush per chunk, which
is how chat completions reach the browser token by token. The static WebUI
directory answers GET under a resolved path confined to the root, and its
Content-Security-Policy names the SHA-256 of every inline script and style
block the served page carries, so the page runs under `script-src 'self'`
plus exactly its own blocks rather than under `'unsafe-inline'`.
"""

from __future__ import annotations

import base64
import hashlib
import mimetypes
import socket
import threading
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Protocol, cast
from urllib.parse import parse_qsl, unquote, urlsplit

from qwen_apu.web.http import BodyStream, Request, Response, Route, StreamingResponse, match

# remote/web-mcp/authorize-broker.py's own literals: the loopback pair stands
# under every setting, because the session's probes reach a service over
# 127.0.0.1 whatever the listener binds.
LOOPBACK_HOSTS: tuple[str, ...] = ("127.0.0.1", "::1")
ASCII_LABEL_CHARACTERS = frozenset("abcdefghijklmnopqrstuvwxyz0123456789-")

DEFAULT_BIND_HOST = "127.0.0.1"
DEFAULT_PORT = 8090
DEFAULT_INDEX = "index.html"

# A chat body carries a conversation rather than the broker's single grant
# request, so the cap sits at one mebibyte where `REQUEST_BODY_BYTE_CAP` in
# authorize-broker.py sits at 16384 bytes.
REQUEST_BODY_BYTE_CAP = 1 << 20

# The deadline authorize-broker.py arms as `expire_request_read`, applied here
# as the connection's own timeout: `socketserver.StreamRequestHandler.setup`
# calls `settimeout` with it, so a request line that never arrives, a body
# shorter than its Content-Length, and a client that stops reading a stream all
# end at this bound rather than holding a thread for the process lifetime.
REQUEST_DEADLINE_SECONDS = 60.0

SECURITY_HEADERS: Mapping[str, str] = {
    "x-content-type-options": "nosniff",
    "referrer-policy": "no-referrer",
}
# An API answer carries JSON to script that the page already loaded, so every
# fetch directive closes and the response document itself loads nothing.
API_CONTENT_SECURITY_POLICY = "default-src 'none'; base-uri 'none'; frame-ancestors 'none'"

BODY_METHODS = frozenset({"POST", "PUT", "PATCH", "DELETE"})


class RequestRefused(Exception):
    """A refusal a handler or the session authority states as one HTTP status."""

    def __init__(self, status: int, message: str, retry_after: int | None = None) -> None:
        super().__init__(message)
        self.status = status
        self.message = message
        self.retry_after = retry_after


class RouteProvider(Protocol):
    """Any module component that contributes routes to the gateway."""

    def routes(self) -> tuple[Route, ...]: ...


class SessionAuthority(Protocol):
    """The gate `/api/*` passes, as web.auth implements it."""

    def guards(self, path: str) -> bool: ...

    def require_session(self, request: Request) -> None: ...


def label_is_admitted(label: str) -> bool:
    """Whether one hostname label meets the ASCII letter-digit-hyphen rule.

    The character set stays ASCII rather than reading `str.isalnum`, which
    admits every Unicode letter: a browser sends an internationalized name in
    its Punycode form, so a name outside ASCII is refused here rather than
    admitted into a set no request ever matches.
    """
    return (
        1 <= len(label) <= 63
        and not label.startswith("-")
        and not label.endswith("-")
        and all(character in ASCII_LABEL_CHARACTERS for character in label)
    )


def admitted_hosts(exposure: str = "", name: str = "") -> tuple[str, ...]:
    """The Host-header names a request may present.

    The exposure adds exactly one literal and the name adds exactly one
    lowercased mDNS hostname, so the set stays a closed list of two to four
    entries, the shape `admitted_hosts` builds in authorize-broker.py.
    """
    admitted = list(LOOPBACK_HOSTS)
    if exposure:
        admitted.append(exposure)
    if name:
        if not name.endswith(".local") or not label_is_admitted(name[: -len(".local")]):
            raise ValueError(
                "the LAN exposure name is exactly one lowercase mDNS label under "
                f".local; {name!r} is refused"
            )
        admitted.append(name)
    return tuple(admitted)


def host_header_names(header: str, admitted: Sequence[str]) -> str:
    """The admitted entry this request's Host names, or an empty string.

    The port comes off first, because a listener on an ephemeral port answers
    `Host: 127.0.0.1:45311` for exactly the request the loopback literal
    admits, and a bracketed literal unwraps because that is how a browser
    spells an IPv6 address. The comparison falls back to the casefolded form
    because DNS names are case-insensitive and the admitted name is stored
    lowercased; the literals hold digits, colons, and dots alone, so lowering
    leaves them as they stand.
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


class _InlineBlockReader(HTMLParser):
    """Collect the bytes of every inline script and style block of one page.

    `HTMLParser` switches to CDATA mode inside `script` and `style` and leaves
    character references unconverted there, so `handle_data` hands back the
    element's source text exactly as the file carries it, which is what a
    CSP hash source digests. A tokenizer rather than a regex reads the page,
    because a `</script>` inside a string literal ends the element for the
    browser and must end it here for the digests to agree.
    """

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.scripts: list[bytes] = []
        self.styles: list[bytes] = []
        self._collecting = ""

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in ("script", "style") and not any(name == "src" for name, _ in attrs):
            self._collecting = tag

    def handle_endtag(self, tag: str) -> None:
        if tag == self._collecting:
            self._collecting = ""

    def handle_data(self, data: str) -> None:
        if self._collecting == "script":
            self.scripts.append(data.encode("utf-8"))
        elif self._collecting == "style":
            self.styles.append(data.encode("utf-8"))


def hash_source(block: bytes) -> str:
    """One CSP `'sha256-...'` source, base64 over the raw element text."""
    digest = base64.b64encode(hashlib.sha256(block).digest()).decode("ascii")
    return f"'sha256-{digest}'"


def content_security_policy(page: bytes) -> str:
    """The page's own policy: `'self'` plus the hash of each inline block.

    `connect-src 'self'` names this gateway alone, which is the phase's whole
    claim -- one origin carries chat, approvals, artifacts, and images -- and
    refuses a page that still derives a broker origin on a sibling port.
    """
    reader = _InlineBlockReader()
    reader.feed(page.decode("utf-8", "replace"))
    reader.close()
    scripts = " ".join(hash_source(block) for block in reader.scripts)
    styles = " ".join(hash_source(block) for block in reader.styles)
    return "; ".join(
        (
            "default-src 'none'",
            f"script-src 'self'{' ' + scripts if scripts else ''}",
            f"style-src 'self'{' ' + styles if styles else ''}",
            "img-src 'self' data: blob:",
            "connect-src 'self'",
            "font-src 'self'",
            "form-action 'none'",
            "base-uri 'none'",
            "frame-ancestors 'none'",
        )
    )


@dataclass(frozen=True)
class StaticDirectory:
    """The WebUI directory, served by GET alone and confined to its own root."""

    root: Path

    def resolved_root(self) -> Path:
        return self.root.resolve()

    def resolve(self, url_path: str) -> Path | None:
        """The file one URL path names, or None where the root holds no such file.

        The path unquotes before resolution, so `%2e%2e%2f` becomes `../` and
        meets the containment check rather than passing it as an opaque
        segment. A directory resolves to None rather than to a listing, and
        `/` alone resolves to the index page.
        """
        relative = unquote(url_path).lstrip("/")
        if not relative or relative.endswith("/"):
            relative = f"{relative}{DEFAULT_INDEX}"
        root = self.resolved_root()
        candidate = (root / relative).resolve()
        if candidate != root and root not in candidate.parents:
            return None
        return candidate if candidate.is_file() else None

    def index(self) -> bytes:
        page = self.resolved_root() / DEFAULT_INDEX
        return page.read_bytes() if page.is_file() else b""


@dataclass(frozen=True)
class GatewayConfig:
    """One bind, one Host set, one Origin allowlist, one static root."""

    static_root: Path
    port: int = DEFAULT_PORT
    bind_host: str = DEFAULT_BIND_HOST
    exposure: str = ""
    exposure_name: str = ""
    origins: tuple[str, ...] = ()

    def admitted_hosts(self) -> tuple[str, ...]:
        return admitted_hosts(self.exposure, self.exposure_name)

    @property
    def binds_loopback(self) -> bool:
        return self.bind_host in LOOPBACK_HOSTS


class _GatewayServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self,
        server_address: tuple[str, int],
        handler: type[BaseHTTPRequestHandler],
        gateway: Gateway,
    ) -> None:
        self.gateway = gateway
        if ":" in server_address[0]:
            self.address_family = socket.AF_INET6
        super().__init__(server_address, handler)


class _Handler(BaseHTTPRequestHandler):
    # Chunked transfer encoding and keep-alive both require the 1.1 protocol
    # line; the streaming writer below depends on it.
    protocol_version = "HTTP/1.1"
    server_version = "qwen-apu-gateway/1"
    sys_version = ""
    timeout = REQUEST_DEADLINE_SECONDS

    # Set true by `_read_body`; a refusal ahead of it leaves the request body
    # in the socket and the connection unusable for a second request.
    body_consumed = False

    # The body a streaming route reads for itself, whose `remaining` reports
    # what the handler left in the socket.
    body_stream: BodyStream | None = None

    @property
    def gateway(self) -> Gateway:
        return cast(_GatewayServer, self.server).gateway

    def close_on_unread_body(self) -> None:
        """Close a connection whose request body stayed in the socket.

        A refusal that precedes the body -- the Host check, the byte cap, a
        preflight -- leaves those bytes unread, and the next read on a
        keep-alive connection would take them as a request line, which is the
        request-smuggling case. Closing is what keeps the unread bytes from
        being parsed as anything, and it is the cost of refusing before the
        read rather than draining a body a refused peer sent.

        A streaming route reads the body itself, so its stream reports what it
        consumed: an upload refused at its own bound leaves the rest of the
        body in the socket and takes the same close.
        """
        if self.body_stream is not None:
            self.body_consumed = self.body_stream.exhausted
        if self.body_consumed or self.command not in BODY_METHODS:
            return
        if self.headers.get("Content-Length", "0") not in ("0", ""):
            self.close_connection = True

    def announce_close(self) -> None:
        """State the close in the answer a client is already reading.

        `close_connection` alone ends the socket and tells the client nothing,
        so a client holding the connection for a second request discovers the
        end as a failed write. The header states it in the response itself.
        """
        if self.close_connection:
            self.send_header("Connection", "close")

    def log_message(self, format: str, *args: object) -> None:
        """Drop the default access log.

        A request line reaching stderr would carry the prompt and the pairing
        code a refusal deliberately keeps out of every record, so the gateway
        writes no access log of its own.
        """

    def do_GET(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        self._dispatch()

    def do_POST(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        self._dispatch()

    def do_PUT(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        self._dispatch()

    def do_DELETE(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        self._dispatch()

    def do_OPTIONS(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        """Answer the preflight a custom header and a JSON body force.

        A browser sends this ahead of every cross-origin API request and a
        Python client sends it ahead of none, so the arm lives here and in the
        test rather than being discovered by a front end that fails while
        every test passes. The Host check runs first here as everywhere.
        """
        self.body_consumed = False
        self.body_stream = None
        if not self._named_host():
            self._write(Response.json({"error": self._host_refusal()}, status=403), "")
            return
        origin = self._allowed_origin()
        headers = {"content-length": "0"}
        if origin:
            headers.update(
                {
                    "access-control-allow-origin": origin,
                    "access-control-allow-methods": "GET, POST, OPTIONS",
                    "access-control-allow-headers": "Content-Type",
                    "access-control-max-age": "60",
                    "vary": "Origin",
                }
            )
        self._write(Response(204 if origin else 403, b"", headers), "")

    def _named_host(self) -> str:
        return host_header_names(self.headers.get("Host", ""), self.gateway.admitted_hosts)

    def _host_refusal(self) -> str:
        return (
            f"the request Host names no admitted literal: {', '.join(self.gateway.admitted_hosts)}"
        )

    def _allowed_origin(self) -> str:
        origin = self.headers.get("Origin", "")
        return origin if origin and origin in self.gateway.config.origins else ""

    def _read_body(self) -> bytes:
        if self.command not in BODY_METHODS:
            return b""
        raw = self.headers.get("Content-Length", "0")
        try:
            length = int(raw)
        except ValueError:
            raise RequestRefused(400, "Content-Length is not an integer") from None
        if length < 0 or length > REQUEST_BODY_BYTE_CAP:
            raise RequestRefused(
                413, f"the request body exceeds the {REQUEST_BODY_BYTE_CAP} byte cap"
            )
        body = self.rfile.read(length)
        self.body_consumed = True
        if len(body) != length:
            raise RequestRefused(400, "the request body is shorter than Content-Length")
        return body

    def _open_body_stream(self) -> BodyStream:
        """The body as bytes still in the socket, for a route that bounds its own read.

        The gateway's byte cap stays off this path, which is what lets one
        upload route admit a body every JSON route refuses; the route's own
        bound is what the stream meets.

        Content-Length is what a stream reads: `BaseHTTPRequestHandler`
        decodes no chunked body, so a request that names a transfer encoding
        and no length is refused by name here rather than read as an empty
        body.
        """
        if self.headers.get("Transfer-Encoding", "") and "Content-Length" not in self.headers:
            raise RequestRefused(
                411,
                "this route reads a body of a declared length; "
                f"{self.headers.get('Transfer-Encoding', '')} declares none",
            )
        raw = self.headers.get("Content-Length", "0")
        try:
            length = int(raw)
        except ValueError:
            raise RequestRefused(400, "Content-Length is not an integer") from None
        if length < 0:
            raise RequestRefused(400, "Content-Length is negative")
        return BodyStream(self.rfile, length)

    def _dispatch(self) -> None:
        """Host, Origin, route, session, handler -- in that order.

        The Host comparison is first and constant-cost, so a peer outside the
        admitted set spends no meter unit and reaches no handler. The session
        gate precedes every guarded handler for the same reason the broker
        puts the bearer ahead of its buckets.

        The route match runs ahead of the body read and decides which read
        happens: a streaming route takes the socket under its own bound and
        every other route takes the capped read, in the position the cap has
        always occupied. Matching reads no bytes and holds no state, so the
        refusal order a non-streaming route meets is the order above.
        """
        self.body_consumed = False
        self.body_stream = None
        if not self._named_host():
            self._write(Response.json({"error": self._host_refusal()}, status=403), "")
            return
        origin = self._allowed_origin()
        parts = urlsplit(self.path)
        path = unquote(parts.path)
        found = match(self.gateway.routes, self.command, path)
        streams = found is not None and found[0].streams and self.command in BODY_METHODS
        try:
            if streams:
                self.body_stream = self._open_body_stream()
            request = Request(
                method=self.command,
                path=path,
                query=dict(parse_qsl(parts.query)),
                headers={name.lower(): value for name, value in self.headers.items()},
                body=b"" if streams else self._read_body(),
                client_address=str(self.client_address[0]),
                stream=self.body_stream,
            )
            if found is None:
                self._serve_static(path, origin)
                return
            route, params = found
            bound = Request(
                method=request.method,
                path=request.path,
                query=request.query,
                headers=request.headers,
                body=request.body,
                client_address=request.client_address,
                path_params=params,
                stream=request.stream,
            )
            authority = self.gateway.session_authority
            if authority is not None and authority.guards(path):
                authority.require_session(bound)
            answer = route.handler(bound)
        except RequestRefused as refusal:
            headers = {"retry-after": str(refusal.retry_after)} if refusal.retry_after else {}
            self._write(
                Response.json({"error": refusal.message}, status=refusal.status, **headers),
                origin,
            )
            return
        if isinstance(answer, StreamingResponse):
            self._write_stream(answer, origin)
        else:
            self._write(answer, origin)

    def _serve_static(self, path: str, origin: str) -> None:
        if self.command != "GET":
            self._write(Response.json({"error": "no such endpoint"}, status=404), origin)
            return
        target = self.gateway.static.resolve(path)
        if target is None:
            self._write(Response.json({"error": "no such endpoint"}, status=404), origin)
            return
        guessed, _ = mimetypes.guess_type(target.name)
        content_type = guessed or "application/octet-stream"
        if content_type.startswith("text/") or content_type == "application/javascript":
            content_type = f"{content_type}; charset=utf-8"
        self._write(
            Response(
                200,
                target.read_bytes(),
                {
                    "content-type": content_type,
                    "content-security-policy": self.gateway.content_security_policy,
                    "cache-control": "no-store",
                },
            ),
            origin,
        )

    def _common_headers(self, path_is_api: bool, origin: str) -> dict[str, str]:
        headers = dict(SECURITY_HEADERS)
        if path_is_api:
            headers["content-security-policy"] = API_CONTENT_SECURITY_POLICY
            headers["cache-control"] = "no-store"
        if origin:
            # The echoed value is one entry of the configured allowlist, so a
            # wildcard never reaches a response. Credentials stay unallowed
            # because the session cookie is SameSite=Strict and travels on
            # same-origin requests alone.
            headers["access-control-allow-origin"] = origin
            headers["vary"] = "Origin"
        return headers

    def _write(self, response: Response, origin: str) -> None:
        self.close_on_unread_body()
        headers = self._common_headers(self.path.startswith("/api/"), origin)
        headers.update({name.lower(): value for name, value in response.headers.items()})
        self.send_response(response.status)
        for name, value in headers.items():
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(response.body)))
        self.announce_close()
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(response.body)
            self.wfile.flush()

    def _write_stream(self, response: StreamingResponse, origin: str) -> None:
        """Write each chunk as it arrives, terminator last.

        A chunk reaches the socket with its own flush, so a token the upstream
        emitted is a token the browser reads rather than one a buffer holds
        until the body completes. An iterator that raises mid-stream leaves
        the terminating zero-length chunk unwritten and the connection closed,
        which is what tells the client the body is partial: the bytes already
        written cannot be recalled, and a truncated chunked body is the one
        signal that survives them.
        """
        self.close_on_unread_body()
        headers = self._common_headers(self.path.startswith("/api/"), origin)
        headers.update({name.lower(): value for name, value in response.headers.items()})
        self.send_response(response.status)
        for name, value in headers.items():
            self.send_header(name, value)
        self.send_header("Transfer-Encoding", "chunked")
        self.announce_close()
        self.end_headers()
        self.wfile.flush()
        try:
            for chunk in response.chunks:
                if not chunk:
                    continue
                self.wfile.write(b"%x\r\n%s\r\n" % (len(chunk), chunk))
                self.wfile.flush()
        except Exception:
            self.close_connection = True
            return
        self.wfile.write(b"0\r\n\r\n")
        self.wfile.flush()


class Gateway:
    """One `ThreadingHTTPServer` over every module's routes.

    The supervisor owns the lifetime: `serve_forever` runs the accept loop and
    `shutdown` ends it and releases the listening socket. Releasing it is the
    separate call -- `shutdown()` alone leaves the socket bound, and
    `allow_reuse_address` lets a later bind succeed over it, so absence is
    proven by a refused connection rather than by a successful bind.
    """

    def __init__(
        self,
        config: GatewayConfig,
        providers: Sequence[RouteProvider],
        *,
        session_authority: SessionAuthority | None = None,
    ) -> None:
        self.config = config
        self.routes: tuple[Route, ...] = tuple(
            route for provider in providers for route in provider.routes()
        )
        self.session_authority = session_authority
        self.static = StaticDirectory(config.static_root)
        self.admitted_hosts = config.admitted_hosts()
        self.content_security_policy = content_security_policy(self.static.index())
        self._server = _GatewayServer((config.bind_host, config.port), _Handler, self)
        self._lock = threading.Lock()

    @property
    def port(self) -> int:
        """The bound port, which a port-zero bind decides at bind time."""
        address = cast(tuple[str, int], self._server.server_address)
        return int(address[1])

    def serve_forever(self) -> None:
        self._server.serve_forever(poll_interval=0.1)

    def shutdown(self) -> None:
        with self._lock:
            self._server.shutdown()
            self._server.server_close()
