"""One human click per network-reaching tool call from llama.cpp's own page.

llama.cpp's page runs the tool loop itself: it lists the router's tools with
`GET /tools`, offers them to the model, and executes each `tool_calls` entry
with `POST /tools`, whose body carries `tool`, `params`, and the model name.
The router forwards that call to the child that serves the model, and the
child's MCP manager hands it to `remote/web-mcp/server.py` or
`remote/image-mcp/server.py` over stdio. Both servers require an
`authorization` argument the model cannot produce: a grant signed with the
gateway's own token key over the exact arguments a human approved.

This module is where that approval happens. The second listener's proxy
hands every `POST /tools` body to `ToolGate.admit`: a call the ledgers name
as needing a grant is parked as a pending approval, the shell's rail shows it,
and the operator's decision either signs the grant into `params` and lets the
call proceed or answers the model a refusal in the `/tools` error shape. A
call no ledger guards, `fetch_exa` under its result identifier, passes
through. The wait is bounded, so a call nobody decides ends as a refusal
rather than holding the page's request and the child's slot open.

The grant is minted through the same `issue_search_grant` and
`issue_image_grant` the custom page's `/api/tools/grant` routes use, with the
same signing key and the same profile names, so the MCP servers verify a
gate-issued grant and a page-issued grant by one rule.
"""

from __future__ import annotations

import json
import secrets
import threading
import time
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field

from qwen_apu.tools import approvals
from qwen_apu.tools.ledger import InvalidArgument, ToolError
from qwen_apu.web.http import Request, Response, Route

PENDING_PATH = "/api/tools/pending"
DECISION_PATTERN = rf"{PENDING_PATH}/(?P<call_id>[A-Za-z0-9_-]+)"
DECISIONS = ("approve", "deny")
# A parked call waits this long for a click before it answers the model a
# refusal. The page's own fetch and the child's slot are both held meanwhile,
# so the bound is short enough to read as a stalled turn rather than a hang.
WAIT_SECONDS_DEFAULT = 120.0
PENDING_LIMIT = 8
SEARCH_TOOL_SUFFIX = "_search_exa"
IMAGE_TOOL_SUFFIX = "_generate_image"
# The search arguments the grant claim covers, copied from the model's call
# verbatim; every other argument of the schema is either the grant itself or
# a value the MCP server reads from the profile.
SEARCH_CLAIM_KEYS = (
    "query",
    "include_domains",
    "exclude_domains",
    "published_after",
    "published_before",
    "max_age_hours",
    "max_results",
)
# The image arguments the grant binds. Width and height fold into the aspect
# and the dimension bound, and the prompts fold into their digests, the way
# the custom page's dialog folded them.
IMAGE_CLAIM_KEYS = ("prompt", "negative_prompt", "seed", "width", "height", "steps", "profile_id")


class ToolRefused(Exception):
    """The gate answers the model this sentence instead of executing the call."""


@dataclass
class PendingCall:
    call_id: str
    tool: str
    params: dict[str, object]
    model: str
    client: str
    created_at: float
    settled: threading.Event = field(default_factory=threading.Event)
    decision: str = ""

    def as_payload(self, now: float) -> dict[str, object]:
        return {
            "id": self.call_id,
            "tool": self.tool,
            "kind": kind_of(self.tool),
            "model": self.model,
            "params": {
                key: value
                for key, value in self.params.items()
                if key in SEARCH_CLAIM_KEYS or key in IMAGE_CLAIM_KEYS
            },
            "age_seconds": max(0, int(now - self.created_at)),
        }


def kind_of(tool: str) -> str:
    """`search`, `image`, or `` for a tool no grant guards."""
    if tool.endswith(SEARCH_TOOL_SUFFIX):
        return "search"
    if tool.endswith(IMAGE_TOOL_SUFFIX):
        return "image"
    return ""


class ToolGate:
    """The pending approvals, their routes, and the grant each decision signs."""

    def __init__(
        self,
        settings: approvals.ApprovalSettings,
        *,
        wait_seconds: float = WAIT_SECONDS_DEFAULT,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.settings = settings
        self.wait_seconds = wait_seconds
        self._pending: dict[str, PendingCall] = {}
        self._lock = threading.Lock()
        self._clock = clock

    # -- the routes the shell calls ---------------------------------------

    def routes(self) -> tuple[Route, ...]:
        return (
            Route.make("GET", PENDING_PATH, self.list_pending),
            Route.make("POST", DECISION_PATTERN, self.decide),
        )

    def list_pending(self, request: Request) -> Response:
        del request
        now = self._clock()
        with self._lock:
            calls = sorted(self._pending.values(), key=lambda call: call.created_at)
            return Response.json({"pending": [call.as_payload(now) for call in calls]})

    def decide(self, request: Request) -> Response:
        call_id = request.path_params.get("call_id", "")
        try:
            body = json.loads(request.body or b"{}")
        except ValueError:
            return Response.json({"error": "the decision body is not JSON"}, status=400)
        decision = body.get("decision") if isinstance(body, dict) else None
        if decision not in DECISIONS:
            return Response.json(
                {"error": "decision names approve or deny"},
                status=400,
            )
        with self._lock:
            call = self._pending.get(call_id)
            if call is None:
                return Response.json({"error": "no such pending call"}, status=404)
            if call.decision:
                return Response.json({"error": "the call is already decided"}, status=409)
            call.decision = decision
        call.settled.set()
        return Response.json({"id": call_id, "decision": decision})

    # -- the proxy's entry ----------------------------------------------------

    def admit(self, body: Mapping[str, object], client: str) -> dict[str, object]:
        """Return the body to forward, with the grant signed in where one is due.

        A tool no ledger guards returns unchanged. A guarded tool parks until
        the operator decides or the wait ends; approval signs the grant over
        the call's own arguments, so what the operator read is what the MCP
        server verifies.
        """
        tool = body.get("tool")
        params = body.get("params")
        if not isinstance(tool, str) or not tool:
            raise ToolRefused("the call names no tool")
        kind = kind_of(tool)
        if not kind:
            return dict(body)
        if not isinstance(params, dict):
            raise ToolRefused("the call carries no params object")
        model = body.get("model")
        call = PendingCall(
            call_id=secrets.token_urlsafe(9),
            tool=tool,
            params=dict(params),
            model=model if isinstance(model, str) else "",
            client=client,
            created_at=self._clock(),
        )
        with self._lock:
            if len(self._pending) >= PENDING_LIMIT:
                raise ToolRefused("too many tool calls await approval; decide those first")
            self._pending[call.call_id] = call
        try:
            call.settled.wait(self.wait_seconds)
        finally:
            with self._lock:
                self._pending.pop(call.call_id, None)
        if call.decision != "approve":
            raise ToolRefused(
                "the operator denied this call"
                if call.decision == "deny"
                else f"no operator approved this call within {int(self.wait_seconds)} seconds"
            )
        try:
            signer = self._sign_search if kind == "search" else self._sign_image
            authorization = signer(call.params)
        except ToolError as error:
            raise ToolRefused(f"the grant was refused: {error}") from error
        forwarded = dict(body)
        forwarded["params"] = {**call.params, "authorization": authorization}
        return forwarded

    # -- the grants ------------------------------------------------------------

    def _sign_search(self, params: Mapping[str, object]) -> str:
        claim = {key: params[key] for key in SEARCH_CLAIM_KEYS if key in params}
        claim["profile_id"] = self.settings.profile
        request = approvals.parse_search_request(claim)
        return approvals.issue_search_grant(
            self.settings.token_key_file,
            request,
            provider=self.settings.provider,
            profile=self.settings.profile,
            lifetime=self.settings.lifetime,
        )

    def _sign_image(self, params: Mapping[str, object]) -> str:
        required = ("prompt", "seed", "width", "height", "steps")
        missing = [key for key in required if key not in params]
        if missing:
            raise InvalidArgument("the call omits " + ", ".join(missing))
        width, height = _integer(params, "width"), _integer(params, "height")
        profile_id = params.get("profile_id")
        image_profile = (
            profile_id
            if isinstance(profile_id, str) and profile_id
            else self.settings.image_profile
        )
        claim = {
            "context": approvals.IMAGE_CLAIM_CONTEXT,
            "language_profile": self.settings.profile,
            "image_profile": image_profile,
            "prompt_hash": approvals.prompt_digest(_string(params, "prompt")),
            "negative_prompt_hash": approvals.prompt_digest(
                _string(params, "negative_prompt", default="")
            ),
            "seed": _integer(params, "seed"),
            "aspect": approvals.canonical_aspect(width, height),
            "max_dimension": max(width, height),
            "max_steps": _integer(params, "steps"),
            "conversation_generation": 0,
        }
        request = approvals.parse_image_request(claim)
        if request.image_profile != self.settings.image_profile:
            raise InvalidArgument(
                f"the approval service serves image profile {self.settings.image_profile!r}; "
                f"the call named {request.image_profile!r}"
            )
        return approvals.issue_image_grant(
            self.settings.token_key_file, request, self.settings.lifetime
        )


def _string(params: Mapping[str, object], key: str, default: str | None = None) -> str:
    value = params.get(key, default)
    if not isinstance(value, str):
        raise InvalidArgument(f"{key} must be a string")
    return value


def _integer(params: Mapping[str, object], key: str) -> int:
    value = params.get(key)
    if isinstance(value, bool) or not isinstance(value, int):
        raise InvalidArgument(f"{key} must be an integer")
    return value
