"""llama.cpp's own Web UI, proxied onto a second listener of the same gateway.

The custom page and the built-in page are two surfaces of one router. The
gateway serves the custom page from `static/` on its own port; this module
serves the built-in page on a second port by forwarding each request to the
router on loopback through the same `LlamaClient` the chat lane uses, so the
answer is bound to the supervisor's server pid and listener inode and the
built-in page reaches no port of its own.

Three rules decide what crosses.

The session is the first: `SessionGate.guards` names `/api/` alone, and every
path here is a router path, so this handler calls `require_session` itself
rather than relying on the gateway's authority. An unpaired GET of the page
root answers the pairing card `static/llama-ui/index.html` carries, which
names the origin that mints a session; every other unpaired request is the
401 the gate states. One `SessionGate` backs both listeners and a cookie is
scoped to a host rather than to a port, so one pairing admits both origins.

The admitted set is the second. `tools/server/server.cpp` registers the route
table this module mirrors: the inference and reading routes cross, and the
routes that change server state -- `POST /props`, `POST /slots/:id_slot`,
`POST /lora-adapters`, and the router's own `/models`, `/models/load`, and
`/models/unload` -- stay behind, because a page reached through one pairing
would otherwise load and unload checkpoints on a device the capacity policy
alone places. A GET of any other well-formed asset name reaches the server's
asset table, which answers 404 for a name it does not hold. A catch-all route
per method is what keeps an unmatched path out of the gateway's static
branch, since that branch would serve the custom page's own files here.

The headers are the third. `server-http.cpp`'s `handle_gzip_header` answers
415 to a request whose `Accept-Encoding` omits gzip when the build embedded
its assets from `_gzip`, and it returns `Content-Encoding: gzip` with the
bytes, so `accept-encoding` travels up and `content-encoding` travels back or
the browser reads compressed bytes labeled as JavaScript. `ETag` and
`If-None-Match` travel for the same reason: the asset routes answer 304 from
them, and a dropped validator turns every reload into a full transfer. The
cookie stays behind, as it does on the chat lane.

The bundle is the fourth. The deployed server is configured
`-DLLAMA_BUILD_UI=OFF`, so `LLAMA_UI_HAS_ASSETS` stays undefined and its
embedded-asset branch registers no route: `--ui` alone leaves the page
unserved. `remote/build-llama-ui.sh` builds `tools/ui` with Node and the
appliance keeps the output under the runtime root, so this listener serves
those files itself. A GET whose path resolves to a regular file inside that
directory answers from disk with the headers `serve_asset_cached` sends --
`no-cache` on the files a build replaces under a stable name, the immutable
year on the hashed ones, the cross-origin isolation pair on the page itself,
and an ETag the bytes decide -- and every other path proxies to the router. A
launch whose directory holds no `index.html` names none and every path proxies.

The body is forwarded and never rewritten, so what the second origin serves is
the page the build produced.
"""

from __future__ import annotations

import hashlib
import json
import mimetypes
from collections.abc import Callable, Iterator, Sequence
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlencode

from qwen_apu.engines.llama import LlamaClient, UpstreamAnswer, UpstreamRefused
from qwen_apu.web.app import RequestRefused, StaticDirectory, inline_sources
from qwen_apu.web.http import Request, Response, Route, StreamingResponse
from qwen_apu.web.tool_gate import ToolGate, ToolRefused

PAIRING_PAGE_DIRECTORY = "llama-ui"
PAIRING_PAGE_NAME = "index.html"
PAGE_PATHS = ("/", "/index.html")
# The tool listing and the tool call, admitted through the approval gate alone.
TOOLS_PATH = "/tools"

# `tools/server/server.cpp` registers each of these with `ctx_http.get`. The
# router build adds `/models/sse`, which is the picker's own event stream.
ADMITTED_GET_PATHS = frozenset(
    {
        "/health",
        "/v1/health",
        "/metrics",
        "/props",
        "/models",
        "/v1/models",
        "/models/sse",
        "/slots",
        "/lora-adapters",
    }
)

# The `ctx_http.post` routes that answer a request and leave the server's own
# configuration as they found it.
ADMITTED_POST_PATHS = frozenset(
    {
        "/completion",
        "/completions",
        "/v1/completions",
        "/chat/completions",
        "/v1/chat/completions",
        "/v1/chat/completions/control",
        "/chat/completions/input_tokens",
        "/v1/chat/completions/input_tokens",
        "/responses",
        "/v1/responses",
        "/responses/input_tokens",
        "/v1/responses/input_tokens",
        "/v1/messages",
        "/v1/messages/count_tokens",
        "/tokenize",
        "/detokenize",
        "/apply-template",
        "/infill",
        "/embedding",
        "/embeddings",
        "/v1/embeddings",
        "/rerank",
        "/reranking",
        "/v1/rerank",
        "/v1/reranking",
    }
)

ASSET_NAME_CHARACTERS = frozenset(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
)
# `_app/version.json` is the deepest name `tools/ui/embed.cpp` requires, so two
# segments carry every asset the table holds and the bound states that.
ASSET_SEGMENT_LIMIT = 3

FORWARDED_REQUEST_HEADERS: tuple[str, ...] = (
    "content-type",
    "accept",
    "accept-encoding",
    "accept-language",
    "if-none-match",
    "if-modified-since",
    "last-event-id",
)
FORWARDED_RESPONSE_HEADERS: tuple[str, ...] = (
    "content-type",
    "content-encoding",
    "etag",
    "cache-control",
    "vary",
    "cross-origin-embedder-policy",
    "cross-origin-opener-policy",
)

# The built-in page is a SvelteKit build whose assets this checkout carries no
# source for, so the inline blocks it serves are unread here and the policy
# admits inline script and style by name rather than by digest. The falsifier
# is direct: read the inline blocks of the served `index.html` once a build
# embeds its asset table, and replace the two keywords with `hash_source`
# digests the way `web/app.py` does for the custom page. Every other directive
# is source-backed: `tools/ui/embed.cpp` requires `sw.js`, `workbox[hash].js`,
# and `manifest.webmanifest` among its assets, which is a service worker and a
# web app manifest, and the page talks to the origin it loaded from.


def content_security_policy(
    frame_ancestors: str = "'none'", script_sources: Sequence[str] = ()
) -> str:
    """The listener's policy, with the one origin admitted to frame the page.

    The shell on the chat page's port frames this listener, so the assembly
    names that origin here; a listener assembled without one keeps
    `frame-ancestors 'none'`, which is the standalone page.

    `script_sources` carries the digest of each inline script block the served
    `index.html` holds, read from the bundle on disk, so the page's own script
    executes and an injected one does not. A launch serving no bundle reads no
    page, and the empty default keeps `'unsafe-inline'` for the router's own
    embedded page.

    `style-src` keeps the keyword whatever the bundle holds. The built page
    carries a `style` attribute and its bundle calls `setAttribute("style",
    ...)` in five places; `style-src-attr` falls back to `style-src` and
    governs both, so a digest list refuses the page's own layout.
    """
    scripts = " ".join(script_sources) if script_sources else "'unsafe-inline'"
    return "; ".join(
        (
            "default-src 'none'",
            f"script-src 'self' {scripts}",
            "style-src 'self' 'unsafe-inline'",
            "img-src 'self' data: blob:",
            "font-src 'self' data:",
            "connect-src 'self'",
            "worker-src 'self'",
            "manifest-src 'self'",
            "form-action 'none'",
            "base-uri 'none'",
            f"frame-ancestors {frame_ancestors or chr(39) + 'none' + chr(39)}",
        )
    )


CONTENT_SECURITY_POLICY = content_security_policy()

RequireSession = Callable[[Request], None]

# `server-http.cpp` names these four as the assets a build replaces under a
# stable name, and `index.html` joins them because its contents change on every
# build while its name does not; every other asset carries a hash in its name
# and never changes under it.
REVALIDATED_ASSET_NAMES = frozenset(
    {"index.html", "sw.js", "manifest.webmanifest", "version.json", "build.json"}
)
IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable"
REVALIDATE_CACHE_CONTROL = "no-cache"
# `serve_asset_cached` sets both on the page alone, which is what puts the
# document in a cross-origin isolated agent cluster.
ISOLATION_HEADERS = {
    "cross-origin-embedder-policy": "require-corp",
    "cross-origin-opener-policy": "same-origin",
}
# The types `mimetypes` reads from the system table wrongly or not at all. A
# manifest served as JSON is ignored by the installer, and a module served as
# anything but a JavaScript type is refused by the browser outright.
ASSET_CONTENT_TYPES = {
    ".js": "text/javascript; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".html": "text/html; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".map": "application/json; charset=utf-8",
    ".webmanifest": "application/manifest+json",
    ".wasm": "application/wasm",
    ".svg": "image/svg+xml",
    ".woff2": "font/woff2",
}


def bundle_script_sources(assets: Path | None) -> tuple[str, ...]:
    """The inline script digests the bundle's own `index.html` carries.

    A bundle this listener serves from disk is a page whose bytes are
    readable, so its policy names those blocks by digest. An absent bundle
    leaves the router serving its own page, whose bytes never reach this
    process, and the empty tuple keeps `'unsafe-inline'` for it.
    """
    if assets is None:
        return ()
    page = assets / PAIRING_PAGE_NAME
    if not page.is_file():
        return ()
    scripts, _ = inline_sources(page.read_bytes())
    return scripts


def _unserved(request: Request) -> str:
    return f"the router serves no {request.method} {request.path} through this listener"


def asset_content_type(name: str) -> str:
    suffix = Path(name).suffix.lower()
    if suffix in ASSET_CONTENT_TYPES:
        return ASSET_CONTENT_TYPES[suffix]
    guessed, _ = mimetypes.guess_type(name)
    if guessed is None:
        return "application/octet-stream"
    if guessed.startswith("text/"):
        return f"{guessed}; charset=utf-8"
    return guessed


def asset_entity_tag(payload: bytes) -> str:
    """One strong validator the bytes decide, the way `embed.cpp` hashes an asset."""
    return f'"{hashlib.sha256(payload).hexdigest()[:32]}"'


def asset_headers(
    name: str, payload: bytes, policy: str = CONTENT_SECURITY_POLICY
) -> dict[str, str]:
    headers = {
        "content-type": asset_content_type(name),
        "content-security-policy": policy,
        "etag": asset_entity_tag(payload),
        "cache-control": (
            REVALIDATE_CACHE_CONTROL if name in REVALIDATED_ASSET_NAMES else IMMUTABLE_CACHE_CONTROL
        ),
    }
    if name == "index.html":
        headers.update(ISOLATION_HEADERS)
    return headers


def asset_path_is_admitted(path: str) -> bool:
    """Whether one GET path names a file the server's asset table could hold.

    The name carries letters, digits, and the three punctuation characters a
    hashed bundle name uses; `.` as a whole segment is refused, so no traversal
    form survives the check and the server answers 404 for every name its table
    lacks.
    """
    if not path.startswith("/"):
        return False
    segments = path[1:].split("/")
    if not 1 <= len(segments) <= ASSET_SEGMENT_LIMIT:
        return False
    return all(
        segment
        and segment not in (".", "..")
        and all(character in ASSET_NAME_CHARACTERS for character in segment)
        for segment in segments
    )


def path_is_admitted(method: str, path: str) -> bool:
    if method == "POST":
        return path in ADMITTED_POST_PATHS
    if method != "GET":
        return False
    if path in PAGE_PATHS or path in ADMITTED_GET_PATHS:
        return True
    return asset_path_is_admitted(path)


@dataclass(frozen=True)
class LlamaUiSettings:
    """One proxy: the upstream it reaches, the gate it passes, its bundle, and its card."""

    client_factory: Callable[[], LlamaClient]
    require_session: RequireSession
    pairing_page: Path
    origin: str = ""
    # The built `tools/ui` output this listener serves from disk. None leaves
    # every path to the router, which is the launch that names no directory.
    assets: Path | None = None
    # The one origin admitted to frame this page: the shell on the chat page's
    # port. `'none'` is the standalone listener.
    frame_ancestors: str = "'none'"
    # The approval gate every `POST /tools` passes. None keeps both `/tools`
    # methods off the listener, which is the launch that arms no approvals.
    tool_gate: ToolGate | None = None
    # The digest of each inline script block the served page carries, read
    # once at assembly. Empty leaves `'unsafe-inline'`, which is the launch
    # that serves no bundle of its own.
    script_sources: tuple[str, ...] = ()

    @property
    def policy(self) -> str:
        return content_security_policy(self.frame_ancestors, self.script_sources)


class LlamaUiProxy:
    """The built-in page and the router routes it calls, on one second listener."""

    def __init__(self, settings: LlamaUiSettings) -> None:
        self.settings = settings

    def routes(self) -> tuple[Route, ...]:
        """One catch-all per admitted method.

        The pattern covers every path, so nothing falls through to the
        gateway's static branch, which serves the custom page's own root.
        """
        return (
            Route.make("GET", "/.*", self.forward),
            Route.make("POST", "/.*", self.forward),
        )

    # -- the gate --------------------------------------------------------

    def _paired(self, request: Request) -> bool:
        try:
            self.settings.require_session(request)
        except RequestRefused:
            return False
        return True

    def pairing_card(self) -> Response:
        """The card an unpaired page load answers, naming where a session is minted."""
        page = self.settings.pairing_page
        body = page.read_bytes() if page.is_file() else b"<p>pair on the gateway origin</p>"
        return Response(
            401,
            body,
            {
                "content-type": "text/html; charset=utf-8",
                "content-security-policy": self.settings.policy,
                "cache-control": "no-store",
            },
        )

    # -- the proxy -------------------------------------------------------

    # -- the bundle ------------------------------------------------------

    def asset(self, request: Request) -> Response | None:
        """The file this GET names inside the bundle, or None where it names none.

        `StaticDirectory.resolve` unquotes before resolving and refuses a
        candidate outside its own root, so `%2e%2e%2f` meets the containment
        check rather than passing as an opaque segment, and `/` maps to the
        page. A matching `If-None-Match` answers 304 without the body, which is
        the branch `serve_asset_cached` takes on the same header.
        """
        root = self.settings.assets
        if root is None or request.method != "GET":
            return None
        target = StaticDirectory(root).resolve(request.path)
        if target is None:
            return None
        payload = target.read_bytes()
        headers = asset_headers(target.name, payload, self.settings.policy)
        if request.header("if-none-match") == headers["etag"]:
            return Response(304, b"", headers)
        return Response(200, payload, headers)

    # -- the proxy -------------------------------------------------------

    def forward(self, request: Request) -> Response | StreamingResponse:
        """Serve the bundle where it holds the path, and proxy every other request."""
        if not self._paired(request):
            if request.method == "GET" and request.path in PAGE_PATHS:
                return self.pairing_card()
            self.settings.require_session(request)
        served = self.asset(request)
        if served is not None:
            return served
        if request.path == TOOLS_PATH:
            # `/tools` is asset-shaped, so it is decided here ahead of the
            # asset rule: the gate admits it, and a listener without one
            # offers the model no tool it cannot run.
            if self.settings.tool_gate is None:
                raise RequestRefused(404, _unserved(request))
            return self._tools(request)
        if not path_is_admitted(request.method, request.path):
            raise RequestRefused(404, _unserved(request))
        return self._answer(self._exchange(request))

    def _tools(self, request: Request) -> Response | StreamingResponse:
        """The tool listing passes through; a tool call passes the approval gate.

        A refusal answers 200 with the `/tools` error shape, which the page
        places in the tool message, so the model reads why the call did not
        run rather than the page reading a transport failure.
        """
        gate = self.settings.tool_gate
        assert gate is not None
        if request.method == "GET":
            return self._answer(self._exchange(request))
        try:
            body = json.loads(request.body or b"")
        except ValueError:
            return Response.json({"error": "the tool call body is not JSON"})
        if not isinstance(body, dict):
            return Response.json({"error": "the tool call body is not an object"})
        try:
            admitted = gate.admit(body, request.client_address)
        except ToolRefused as refusal:
            return Response.json({"error": str(refusal)})
        forwarded = Request(
            method=request.method,
            path=request.path,
            query=request.query,
            headers=request.headers,
            body=json.dumps(admitted).encode("utf-8"),
            client_address=request.client_address,
        )
        return self._answer(self._exchange(forwarded))

    def _answer(self, answer: UpstreamAnswer) -> Response | StreamingResponse:
        headers = {
            **dict(answer.headers),
            "content-security-policy": self.settings.policy,
        }
        if answer.streams:
            headers.update({"cache-control": "no-store", "x-accel-buffering": "no"})
            return StreamingResponse(answer.status, self._chunks(answer), headers)
        return Response(answer.status, b"".join(answer.chunks), headers)

    def _exchange(self, request: Request) -> UpstreamAnswer:
        forwarded = {
            name: value
            for name, value in request.headers.items()
            if name in FORWARDED_REQUEST_HEADERS
        }
        target = request.path
        if request.query:
            target = f"{target}?{urlencode(dict(request.query))}"
        try:
            return self.settings.client_factory().request(
                request.method,
                target,
                body=request.body or None,
                headers=forwarded,
                stream=True,
                response_headers=FORWARDED_RESPONSE_HEADERS,
            )
        except UpstreamRefused as error:
            raise RequestRefused(502, str(error)) from error

    @staticmethod
    def _chunks(answer: UpstreamAnswer) -> Iterator[bytes]:
        """The upstream chunks as they arrive, with the listener bracket intact.

        `LlamaClient._read` raises where the inode changed across the exchange,
        which leaves the gateway's chunked body unterminated: a truncated body
        is the one signal that survives bytes already written.
        """
        yield from answer.chunks
