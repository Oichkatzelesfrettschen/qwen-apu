"""Chat and the picker roster: the gateway's two model-facing routes.

`POST /api/chat` hands the request body to llama-server's own
`/v1/chat/completions` and writes the answer back as it arrives. The body
passes through unchanged in both directions, so the `model` field the upstream
states is the served model name the page displays; the gateway names no model
of its own and rewrites none, which keeps the page's attribution equal to the
server's.

`GET /api/models` answers from `remote/models.tsv` rather than from the
upstream: the registry carries the tier, the role, the interactive depth, and
the projector pairing a picker needs, and `remote/build-router-presets.sh`
keeps a quarantined or archived row out of the picker for the same reason this
filter does. `?research=1` widens the answer to every admitted row, which is
what an experiment arm reads.
"""

from __future__ import annotations

import re
from collections.abc import Callable, Iterator
from pathlib import Path

from qwen_apu.config import models as registry
from qwen_apu.config.schema import ModelRow
from qwen_apu.engines.llama import LlamaClient, UpstreamAnswer, UpstreamRefused
from qwen_apu.web.app import RequestRefused
from qwen_apu.web.http import Request, Response, Route, StreamingResponse

# The two tiers remote/build-router-presets.sh admits into a picker section: a
# production row carries a serving tuple measured safe and useful, a candidate
# row leaves quality or performance unqualified while no reset, fault, or
# device loss exists under its admitted tuple.
PICKER_TIERS: tuple[str, ...] = ("production", "candidate")

# The quantization a GGUF filename states, as the publishers in this registry
# spell it: `Q4_K_M`, `Q8_0`, `F16`, `UD-Q2_K_XL`, `IQ3_XXS`. An imatrix marker
# such as `i1` precedes the delimiter and stays out of the value.
_QUANTIZATION = re.compile(r"[.\-_]((?:UD-)?(?:IQ|Q)[0-9]+(?:_[0-9A-Z]+)*|BF16|F16|F32)\.gguf$")
_ABSENT = "-"


def quantization(model_file: str) -> str:
    """The quantization one `model_file` names, or `-` where the name states none."""
    found = _QUANTIZATION.search(model_file)
    return found.group(1) if found else _ABSENT


def roster_entry(row: ModelRow) -> dict[str, object]:
    """One picker row: what the registry claims, without the serving argv."""
    return {
        "id": row.id,
        "role": row.role,
        "tier": row.tier,
        "context_default": row.context_default,
        "projector": row.projector,
        "quantization": quantization(row.model_file),
    }


def roster(rows: tuple[ModelRow, ...], *, research: bool) -> list[dict[str, object]]:
    admitted = rows if research else tuple(row for row in rows if row.tier in PICKER_TIERS)
    return [roster_entry(row) for row in admitted]


class ChatService:
    """The chat proxy and the picker roster over one upstream client factory."""

    def __init__(
        self,
        client_factory: Callable[[], LlamaClient],
        *,
        registry_path: Path | None = None,
    ) -> None:
        self.client_factory = client_factory
        self.registry_path = registry_path

    def routes(self) -> tuple[Route, ...]:
        return (
            Route.make("POST", "/api/chat", self.chat),
            Route.make("GET", "/api/models", self.models),
            Route.make("POST", "/api/models/tokenize", self.tokenize),
        )

    def tokenize(self, request: Request) -> Response:
        """Count a text attachment's tokens through the served model's tokenizer.

        The page attaches a text file only after this count, since the LAN
        prompt bound is measured in the model's own tokens; the body reaches
        the server whole and the answer returns whole with the server's status.
        """
        payload = request.json()
        if not isinstance(payload, dict) or not isinstance(payload.get("content"), str):
            raise RequestRefused(400, "the request body names no 'content' string")
        try:
            answer = self.client_factory().tokenize(request.body)
        except UpstreamRefused as error:
            raise RequestRefused(502, str(error)) from error
        return Response(answer.status, b"".join(answer.chunks), dict(answer.headers))

    def chat(self, request: Request) -> Response | StreamingResponse:
        """Proxy one completion, streaming where the upstream streams.

        A streamed answer reaches the browser as the chunks the socket
        produced, so the first token displays while the rest decode; a
        buffered answer -- which is what a request naming no `stream` asks for
        -- returns whole, because there is nothing to show until it completes.
        """
        payload = request.json()
        if not isinstance(payload, dict):
            raise RequestRefused(400, "the request body is not a JSON object")
        try:
            answer = self.client_factory().chat_completions(request.body, request.headers)
        except UpstreamRefused as error:
            raise RequestRefused(502, str(error)) from error
        if answer.streams:
            return StreamingResponse(
                answer.status,
                self._guarded(answer),
                {**dict(answer.headers), "cache-control": "no-store", "x-accel-buffering": "no"},
            )
        return Response(answer.status, b"".join(answer.chunks), dict(answer.headers))

    def models(self, request: Request) -> Response:
        research = request.query.get("research", "") == "1"
        rows = registry.load_models(self.registry_path)
        return Response.json({"models": roster(rows, research=research)})

    @staticmethod
    def _guarded(answer: UpstreamAnswer) -> Iterator[bytes]:
        """The upstream chunks, with a failed listener bracket ending the body.

        `LlamaClient._read` raises where the listener inode changed across the
        exchange. The bytes already written cannot be recalled, so the raise
        propagates into the gateway's chunked writer, which leaves the
        terminating zero-length chunk unwritten and closes the connection: a
        truncated body is the one signal that survives bytes already sent.
        """
        yield from answer.chunks
