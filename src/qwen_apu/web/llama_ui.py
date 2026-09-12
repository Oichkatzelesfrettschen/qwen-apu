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

The body is forwarded and never rewritten, so what the second origin serves is
the page the pinned build carries.
"""

from __future__ import annotations

from collections.abc import Callable, Iterator
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlencode

from qwen_apu.engines.llama import LlamaClient, UpstreamAnswer, UpstreamRefused
from qwen_apu.web.app import RequestRefused
from qwen_apu.web.http import Request, Response, Route, StreamingResponse

PAIRING_PAGE_DIRECTORY = "llama-ui"
PAIRING_PAGE_NAME = "index.html"
PAGE_PATHS = ("/", "/index.html")

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
CONTENT_SECURITY_POLICY = "; ".join(
    (
        "default-src 'none'",
        "script-src 'self' 'unsafe-inline'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: blob:",
        "font-src 'self' data:",
        "connect-src 'self'",
        "worker-src 'self'",
        "manifest-src 'self'",
        "form-action 'none'",
        "base-uri 'none'",
        "frame-ancestors 'none'",
    )
)

RequireSession = Callable[[Request], None]


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
    """One proxy: the upstream it reaches, the gate it passes, and its card."""

    client_factory: Callable[[], LlamaClient]
    require_session: RequireSession
    pairing_page: Path
    origin: str = ""


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
                "content-security-policy": CONTENT_SECURITY_POLICY,
                "cache-control": "no-store",
            },
        )

    # -- the proxy -------------------------------------------------------

    def forward(self, request: Request) -> Response | StreamingResponse:
        """Pass one request to the router and its answer back, rewriting neither."""
        if not self._paired(request):
            if request.method == "GET" and request.path in PAGE_PATHS:
                return self.pairing_card()
            self.settings.require_session(request)
        if not path_is_admitted(request.method, request.path):
            raise RequestRefused(
                404, f"the router serves no {request.method} {request.path} through this listener"
            )
        answer = self._exchange(request)
        headers = {
            **dict(answer.headers),
            "content-security-policy": CONTENT_SECURITY_POLICY,
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
