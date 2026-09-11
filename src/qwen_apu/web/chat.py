"""Chat and the picker roster: the gateway's three model-facing routes.

`POST /api/chat` hands the request body to llama-server's own
`/v1/chat/completions` and writes the answer back as it arrives. The body passes
through unchanged in both directions, so the `model` field the upstream states
is the served model name the page displays; the gateway names no model of its
own and rewrites none.

Two checks bracket that proxy, and both exist because passing the body through
is what makes a wrong model invisible. Before the exchange, a request naming a
model the live router does not admit is refused with 409 and a reason, rather
than reaching a server that answers from whatever it has resident. After it, the
model the answer states is compared with the model the request selected, and a
difference is reported as an error: a page that displays the checkpoint it asked
for while reading another checkpoint's tokens attributes an answer to the wrong
row. The streamed path reads the first frame before any byte reaches the
browser, so a mismatch returns a clean status instead of the truncated body a
mid-stream failure produces.

`GET /api/models` answers the join `web/roster.py` builds: the deployment's
router preset sections, the live upstream's `/v1/models`, and the registry, each
entry carrying the state that says which of the three left it out. `?research=1`
widens the candidate set to every registry row, which is what an experiment arm
reads.
"""

from __future__ import annotations

import json
from collections.abc import Callable, Iterator, Sequence
from pathlib import Path

from qwen_apu.config import models as registry
from qwen_apu.engines.llama import LlamaClient, UpstreamAnswer, UpstreamRefused
from qwen_apu.runtime.health import served_model_names
from qwen_apu.web import roster as roster_module
from qwen_apu.web.app import RequestRefused
from qwen_apu.web.http import Request, Response, Route, StreamingResponse
from qwen_apu.web.roster import PICKER_TIERS, quantization

__all__ = ["PICKER_TIERS", "ChatService", "quantization", "served_model"]

# The record path an unbound gateway reads: `runtime_state.read` answers None
# for an absent file, which is the state a gateway holding no supervisor record
# is in, so the roster falls back to the upstream's own claim.
_NO_RECORD = Path("state/runtime.json")

# The chunks read ahead of the browser while the first SSE frame is looked for.
# llama-server writes one frame per flush and the first carries the model name,
# so the bound guards against a server that streams without ever naming one
# rather than bounding any ordinary answer.
FIRST_FRAME_CHUNK_LIMIT = 8
_SSE_DATA_PREFIX = b"data: "
_SSE_DONE = b"[DONE]"


def served_model(payload: object) -> str:
    """The model name one completion states, or the empty string where it states none."""
    if isinstance(payload, dict):
        name = payload.get("model")
        if isinstance(name, str):
            return name
    return ""


def _frame_model(chunk: bytes) -> str:
    """The model name the first `data:` frame of an SSE body carries."""
    for line in chunk.split(b"\n"):
        if not line.startswith(_SSE_DATA_PREFIX):
            continue
        body = line[len(_SSE_DATA_PREFIX) :].strip()
        if not body or body == _SSE_DONE:
            continue
        try:
            return served_model(json.loads(body.decode("utf-8")))
        except (ValueError, UnicodeDecodeError):
            return ""
    return ""


class ChatService:
    """The chat proxy, the admission gate, and the picker roster over one upstream."""

    def __init__(
        self,
        client_factory: Callable[[], LlamaClient],
        *,
        registry_path: Path | None = None,
        runtime_record: Path | None = None,
        router_presets: Callable[[], Path | None] | None = None,
    ) -> None:
        self.client_factory = client_factory
        self.registry_path = registry_path
        self.runtime_record = runtime_record
        # A callable rather than a path, because an activation replaces the
        # deployment under a running gateway and the roster reads whichever
        # bundle is current at the request.
        self.router_presets = router_presets

    def routes(self) -> tuple[Route, ...]:
        return (
            Route.make("POST", "/api/chat", self.chat),
            Route.make("GET", "/api/models", self.models),
            Route.make("POST", "/api/models/tokenize", self.tokenize),
        )

    # -- the join --------------------------------------------------------

    def _sections(self) -> tuple[str, ...] | None:
        if self.router_presets is None:
            return None
        try:
            return roster_module.deployment_sections(self.router_presets())
        except (OSError, RuntimeError):
            # A preset the policy would refuse is a deployment serving nothing,
            # which the roster reports as an absent section set rather than by
            # failing the page's own load.
            return None

    def _upstream_roster(self, client: LlamaClient) -> roster_module.UpstreamRoster:
        try:
            answer = client.models()
            body = b"".join(answer.chunks).decode("utf-8", "replace")
        except UpstreamRefused as error:
            return roster_module.UpstreamRoster(False, (), str(error))
        if answer.status != 200:
            return roster_module.UpstreamRoster(False, (), f"status={answer.status}")
        return roster_module.UpstreamRoster(True, served_model_names(body))

    def _admission(self, client: LlamaClient) -> roster_module.Admission:
        sections = self._sections()
        upstream = self._upstream_roster(client)
        return roster_module.resolve_admission(
            self.runtime_record or _NO_RECORD, sections or (), upstream
        )

    def _require_admitted(self, client: LlamaClient, payload: dict[str, object]) -> str:
        """Refuse a named model the live router does not admit, and name the reason.

        A request naming no model leaves the selection to the server, which is
        what the single-model launch expects, so the check applies to a request
        that states one.
        """
        requested = payload.get("model")
        if not isinstance(requested, str) or not requested:
            return ""
        admission = self._admission(client)
        if requested in admission.admitted:
            return requested
        offered = ", ".join(sorted(admission.admitted)) or "no model"
        raise RequestRefused(
            409, f"the live router does not admit {requested}; it serves {offered}"
        )

    @staticmethod
    def _require_match(requested: str, expected: str, stated: str) -> None:
        """Refuse an answer whose served model is not the selected one.

        An answer stating no model at all passes: llama.cpp's own error bodies
        carry none, and that absence is silence rather than a contrary claim.
        """
        if stated and stated != expected:
            raise RequestRefused(
                502, f"the request selected {requested} and the upstream served {stated}"
            )

    # -- the routes ------------------------------------------------------

    def tokenize(self, request: Request) -> Response:
        """Count a text attachment's tokens through the served model's tokenizer.

        The page attaches a text file only after this count, since the LAN
        prompt bound is measured in the model's own tokens; the body reaches the
        server whole and the answer returns whole with the server's status. A
        count taken through a model the router will refuse at the completion
        measures a tokenizer the prompt never meets, so the admission check runs
        here as well.
        """
        payload = request.json()
        if not isinstance(payload, dict) or not isinstance(payload.get("content"), str):
            raise RequestRefused(400, "the request body names no 'content' string")
        client = self.client_factory()
        self._require_admitted(client, payload)
        try:
            answer = client.tokenize(request.body)
        except UpstreamRefused as error:
            raise RequestRefused(502, str(error)) from error
        return Response(answer.status, b"".join(answer.chunks), dict(answer.headers))

    def chat(self, request: Request) -> Response | StreamingResponse:
        """Proxy one completion, streaming where the upstream streams.

        A streamed answer reaches the browser as the chunks the socket produced,
        so the first token displays while the rest decode; a buffered answer --
        which is what a request naming no `stream` asks for -- returns whole,
        because there is nothing to show until it completes.
        """
        payload = request.json()
        if not isinstance(payload, dict):
            raise RequestRefused(400, "the request body is not a JSON object")
        client = self.client_factory()
        requested = self._require_admitted(client, payload)
        expected = self._admission(client).expected_name(requested) if requested else ""
        try:
            answer = client.chat_completions(request.body, request.headers)
        except UpstreamRefused as error:
            raise RequestRefused(502, str(error)) from error
        if answer.streams:
            return self._streamed(answer, requested, expected)
        body = b"".join(answer.chunks)
        if answer.status == 200 and expected:
            try:
                stated = served_model(json.loads(body.decode("utf-8")))
            except (ValueError, UnicodeDecodeError):
                stated = ""
            self._require_match(requested, expected, stated)
        return Response(answer.status, body, dict(answer.headers))

    def _streamed(self, answer: UpstreamAnswer, requested: str, expected: str) -> StreamingResponse:
        """Read the first frame, check its model, then replay it ahead of the rest.

        The check runs before any byte reaches the browser: once the chunked
        body has started, the only signal left is a truncation, which is the
        listener-identity case rather than this one.
        """
        buffered: list[bytes] = []
        if expected:
            for chunk in answer.chunks:
                buffered.append(chunk)
                stated = _frame_model(chunk)
                if stated:
                    self._require_match(requested, expected, stated)
                    break
                if len(buffered) >= FIRST_FRAME_CHUNK_LIMIT:
                    break
        headers = {
            **dict(answer.headers),
            "cache-control": "no-store",
            "x-accel-buffering": "no",
        }
        return StreamingResponse(answer.status, self._guarded(answer, buffered), headers)

    def models(self, request: Request) -> Response:
        research = request.query.get("research", "") == "1"
        rows = registry.load_models(self.registry_path)
        client = self.client_factory()
        sections = self._sections()
        upstream = self._upstream_roster(client)
        admission = roster_module.resolve_admission(
            self.runtime_record or _NO_RECORD, sections or (), upstream
        )
        entries = roster_module.build(
            rows=rows,
            sections=sections,
            upstream=upstream,
            admission=admission,
            research=research,
        )
        return Response.json(
            {
                "models": entries,
                "mode": admission.mode,
                "upstream_reachable": upstream.reachable,
            }
        )

    @staticmethod
    def _guarded(answer: UpstreamAnswer, buffered: Sequence[bytes]) -> Iterator[bytes]:
        """The upstream chunks, with a failed listener bracket ending the body.

        `LlamaClient._read` raises where the listener inode changed across the
        exchange. The bytes already written cannot be recalled, so the raise
        propagates into the gateway's chunked writer, which leaves the
        terminating zero-length chunk unwritten and closes the connection: a
        truncated body is the one signal that survives bytes already sent.
        """
        yield from buffered
        yield from answer.chunks
