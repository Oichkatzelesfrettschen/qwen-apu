"""The image generation and review tools, mounted on the gateway.

Two routes carry one grant. `POST /api/tools/image/generate` forwards an
approved generation to the worker's control socket and answers with the
artifact identity the worker named. `POST /api/tools/image/review` reads a
published artifact, sends it to the registered vision reviewer through the
router, and reports what came back.

Both routes require a `qwen-image-generate-v1` claim, the context
`remote/web-mcp/image_grant.py` signs a single human approval under. Generate
takes the whole binding: `remote/image_signed_verifier.py`'s `verify` receives
the job as the worker will receive it, checks the signature, the term, the
structure, and the field-by-field agreement between the claim and the
arguments, and returns the profile the grant admits. Review takes the claim
alone, since a review names an artifact rather than describing a generation,
and binds it to the artifact through the provenance record: the claim's
`prompt_hash` equals the provenance's `prompt_sha256` and the provenance's
`png_sha256` equals the reviewed digest, which is the binding
`remote/image-review.py` makes over its own HTTP reads.

Every `remote/` authority here loads by path through
`qwen_apu.engines.image.load_remote_module`, so the grant context, the frozen
frame, the verdict schema, and the strict parser have one reading rather than
a transcription each. The verifier module resolves its signing key, profile
table, and two profile ids at import, so it loads inside the request rather
than at package import: a gateway serving no image lane starts without it.
"""

from __future__ import annotations

import json
import re
import secrets
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from types import ModuleType
from typing import cast

from qwen_apu.engines.image import (
    ImageControlClient,
    ImageControlError,
    ProtocolRefused,
    ServiceUnreachable,
    load_remote_module,
)
from qwen_apu.web.artifacts import ARTIFACT_ROUTE_PREFIX, ArtifactDirectory
from qwen_apu.web.http import Request, Response, Route

GENERATE_ROUTE = "/api/tools/image/generate"
REVIEW_ROUTE = "/api/tools/image/review"
IMAGE_CLAIM_CONTEXT = "qwen-image-generate-v1"
DIGEST_PATTERN = re.compile(r"^[0-9a-f]{64}$")
CONTROL_CHARACTERS = re.compile(r"[\x00-\x1f\x7f]")
SERVICE_ERROR_CHARACTER_CAP = 400
REQUEST_ID_BYTES = 8

GENERATE_STRING_FIELDS = ("profile_id", "prompt", "negative_prompt", "authorization")
# The frame admits an empty prompt and an empty negative prompt; the identifier
# and the grant carry a value or the request is refused.
GENERATE_EMPTY_ADMITTED = ("prompt", "negative_prompt")
GENERATE_INTEGER_FIELDS = ("seed", "width", "height", "steps")


class ToolRefused(Exception):
    """One refusal carrying the HTTP status the boundary answers with."""

    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


def review_module() -> ModuleType:
    """`remote/image-review.py`: the verdict schema, the strict parser, and the request shape."""
    return load_remote_module("qwen_image_review", "image-review.py")


def signed_verifier() -> ModuleType:
    """`remote/image_signed_verifier.py`: the grant-to-request binding at the worker's boundary."""
    return load_remote_module("image_signed_verifier", "image_signed_verifier.py")


def grant_module() -> ModuleType:
    """`remote/web-mcp/image_grant.py`: the claim context and its structural rules."""
    return load_remote_module("image_grant", "web-mcp/image_grant.py")


def verify_generation(request: Mapping[str, object]) -> Mapping[str, object]:
    """Return the profile parameters the grant binds this job to.

    The verifier raises on a bad signature, an expired term, a claim naming
    another language or image profile, and any argument that leaves what a
    human approved. The worker revalidates against the same key file, so
    neither side takes the other's word for what was approved; the grant's
    single use is spent by neither, which the module docstring of the ledger
    owner states.
    """
    verified: object = signed_verifier().verify(dict(request))
    if not isinstance(verified, dict):
        raise ToolRefused(403, "the signed verifier returned no profile")
    return cast(Mapping[str, object], verified)


def verify_grant_claim(token: str) -> Mapping[str, object]:
    """Return the verified `qwen-image-generate-v1` claim a review runs under.

    The context is what separates a generation grant from a search grant: the
    HMAC covers it, so a search token never verifies here. The loaded module's
    own constant is compared against the one this route names, which catches a
    checkout whose grant context moved without this file.
    """
    grant = grant_module()
    if grant.IMAGE_CLAIM_CONTEXT != IMAGE_CLAIM_CONTEXT:
        raise ToolRefused(500, f"the grant module signs a context other than {IMAGE_CLAIM_CONTEXT}")
    signing_key: object = signed_verifier().SIGNING_KEY
    claim: object = grant.verify_image_grant(signing_key, token, time.time())
    if not isinstance(claim, dict):
        raise ToolRefused(403, "the grant carries no claim")
    return cast(Mapping[str, object], claim)


@dataclass(frozen=True, slots=True)
class ImageToolSettings:
    """The worker, the artifact directory, the reviewer, and the two verifiers."""

    client: ImageControlClient
    artifacts: ArtifactDirectory
    review_model: str
    # One request to the router's `/v1/chat/completions`, returning the parsed
    # reply document. The router client belongs to the engine layer, so the
    # tool takes it as a value and this module stays free of a transport.
    router: Callable[[Mapping[str, object]], object] = field(default_factory=lambda: _router_absent)
    verify_generation: Callable[[Mapping[str, object]], Mapping[str, object]] = verify_generation
    verify_grant: Callable[[str], Mapping[str, object]] = verify_grant_claim
    # The grant's single use is spent here, between admission and the worker,
    # the way remote/image-mcp/server.py spends it; the default binds no
    # ledger and refuses, so an assembly that forgets the ledger cannot serve
    # a replayable grant.
    spend_grant: Callable[[str, float], None] = field(default_factory=lambda: _ledger_absent)


def _router_absent(payload: Mapping[str, object]) -> object:
    raise ToolRefused(503, "the gateway names no router for the image reviewer")


def _ledger_absent(grant_id: str, expiry: float) -> None:
    raise ToolRefused(503, "the gateway binds no ledger to spend the image grant")


def clip_service_error(value: object) -> str:
    """Return a peer's own message, bounded and free of control bytes.

    The text reaches a model and a page, so a reply that carried a newline or
    an escape sequence would rewrite the surrounding result rather than
    describe a failure.
    """
    if not isinstance(value, str) or not value.strip():
        return "the image service named no reason"
    return CONTROL_CHARACTERS.sub(" ", value.strip())[:SERVICE_ERROR_CHARACTER_CAP]


def _body(request: Request) -> Mapping[str, object]:
    try:
        parsed: object = request.json()
    except ValueError:
        raise ToolRefused(400, "the request body is not JSON") from None
    if not isinstance(parsed, dict):
        raise ToolRefused(400, "the request body is not a JSON object")
    return cast(Mapping[str, object], parsed)


def _string(body: Mapping[str, object], key: str, *, allow_empty: bool = False) -> str:
    """Read one string field under the frame's own emptiness rule.

    `negative_prompt` is a string the protocol admits empty, which is what a
    request naming no exclusion sends; `profile_id` is an identifier and
    `authorization` carries a grant, so both refuse an empty value.
    """
    value = body.get(key)
    if not isinstance(value, str):
        raise ToolRefused(400, f"{key} is absent or is not a string")
    if not value and not allow_empty:
        raise ToolRefused(400, f"{key} is empty")
    return value


def _integer(body: Mapping[str, object], key: str) -> int:
    value = body.get(key)
    # A JSON true is a Python int, and admitting it here would let a boolean
    # stand in for a seed or a dimension.
    if isinstance(value, bool) or not isinstance(value, int):
        raise ToolRefused(400, f"{key} is absent or is not an integer")
    return value


def protocol_aspect(width: int, height: int) -> str:
    """The coarse label the frame requires to agree with the geometry beside it."""
    if width == height:
        return "square"
    return "landscape" if width > height else "portrait"


def generate(settings: ImageToolSettings, request: Request) -> Response:
    """Forward one approved generation and answer with the artifact identity."""
    try:
        body = _body(request)
        frame: dict[str, object] = {"request_id": secrets.token_hex(REQUEST_ID_BYTES)}
        for key in GENERATE_STRING_FIELDS:
            frame[key] = _string(body, key, allow_empty=key in GENERATE_EMPTY_ADMITTED)
        for key in GENERATE_INTEGER_FIELDS:
            frame[key] = _integer(body, key)
        width, height = cast(int, frame["width"]), cast(int, frame["height"])
        frame["aspect"] = protocol_aspect(width, height)
        # The shape check above runs ahead of the verifier, which indexes the
        # generation arguments directly: an absent key reaches it as a KeyError
        # rather than as the denial the boundary reports.
        _admit(settings, frame)
        _spend(settings, _claim(settings, cast(str, frame["authorization"])))
        reply = _run_generation(settings, frame)
    except ToolRefused as refusal:
        return _json(refusal.status, {"error": refusal.message})
    return _json(
        200,
        {
            "sha256": reply["sha256"],
            "artifact_url": f"{ARTIFACT_ROUTE_PREFIX}/{reply['sha256']}.png",
            "provenance_url": _gateway_route(reply.get("provenance_url")),
            "job_id": reply.get("job_id", ""),
            "bytes": reply.get("bytes", 0),
            "seconds": reply.get("seconds", 0),
            "profile_id": frame["profile_id"],
        },
    )


def _admit(settings: ImageToolSettings, frame: Mapping[str, object]) -> None:
    """Refuse a job the grant does not bind, whatever the verifier raises.

    Every refusal the verifier states is a denial at this boundary: a bad
    signature, an expired term, a foreign profile, and an argument that left
    the approval each reach the caller as 403 with the verifier's own sentence.
    """
    try:
        settings.verify_generation(frame)
    except ToolRefused:
        raise
    except Exception as error:
        raise ToolRefused(403, clip_service_error(str(error) or type(error).__name__)) from None


def _run_generation(
    settings: ImageToolSettings, frame: Mapping[str, object]
) -> Mapping[str, object]:
    """Exchange one job line with the worker and require a completed reply.

    `completed` alone is success. `accepted` is refused because this path is
    synchronous: a reply that opened a job and returned reaches the caller as a
    failure rather than as an image that never arrives.
    """
    try:
        reply = settings.client.generate(frame)
    except ServiceUnreachable as error:
        raise ToolRefused(503, str(error)) from None
    except (ProtocolRefused, ImageControlError) as error:
        raise ToolRefused(502, str(error)) from None
    status = reply.get("status")
    if status != "completed":
        stated = clip_service_error(reply.get("error") or reply.get("reason"))
        raise ToolRefused(502, f"the image service {status} the generation: {stated}")
    return reply


def _gateway_route(worker_route: object) -> str:
    """Rewrite the worker's own `/artifacts/...` route onto the gateway mount.

    The reply carries no origin, so the route is relative to whichever listener
    serves it. The worker's listener serves `/artifacts/<digest>.json` and this
    gateway serves `/api/artifacts/<digest>.json`, so the prefix is replaced
    and the content-addressed name travels unchanged.
    """
    if not isinstance(worker_route, str) or not worker_route.startswith("/artifacts/"):
        return ""
    return f"{ARTIFACT_ROUTE_PREFIX}/{worker_route[len('/artifacts/') :]}"


def review(settings: ImageToolSettings, request: Request) -> Response:
    """Review one published artifact and report the reply as three findings.

    Completion, schema validity, and judgment are separate because a
    grammar-bounded reply that still fails the strict parser is itself the
    finding an appliance run exists to measure. A router that answered is a
    completion whatever its content says; a reply that parses against the
    closed four-key schema is valid whatever it judges; a judgment exists only
    where both hold.
    """
    try:
        body = _body(request)
        claim = _claim(settings, _string(body, "authorization"))
        digest = _string(body, "sha256")
        if not DIGEST_PATTERN.match(digest):
            raise ToolRefused(400, "an artifact is named by 64 lowercase hex digits")
        named_model = body.get("model")
        if named_model is not None and named_model != settings.review_model:
            raise ToolRefused(
                400, f"the registered reviewer for this shape is {settings.review_model}"
            )
        prompt_hash = _bind_provenance(settings, claim, digest)
        constraints = _constraints(body)
        png_bytes = settings.artifacts.read(digest, "png")
        if png_bytes is None:
            raise ToolRefused(404, "no such artifact")
        document = _post_review(settings, png_bytes, prompt_hash, constraints)
        findings = _findings(document, constraints, digest, prompt_hash, settings.review_model)
    except ToolRefused as refusal:
        return _json(refusal.status, {"error": refusal.message})
    return _json(200, findings)


def _spend(settings: ImageToolSettings, claim: Mapping[str, object]) -> None:
    """Spend the grant once; a replay reaches the caller as a denial."""
    grant_id, expiry = claim.get("grant_id"), claim.get("expiry")
    if not isinstance(grant_id, str) or not isinstance(expiry, (int, float)):
        raise ToolRefused(403, "the grant carries no usable grant_id or expiry")
    try:
        settings.spend_grant(grant_id, float(expiry))
    except ToolRefused:
        raise
    except Exception as error:
        raise ToolRefused(403, clip_service_error(str(error) or type(error).__name__)) from None


def _claim(settings: ImageToolSettings, token: str) -> Mapping[str, object]:
    """Return the verified claim, reporting every verifier refusal as a denial."""
    try:
        return settings.verify_grant(token)
    except ToolRefused:
        raise
    except Exception as error:
        raise ToolRefused(403, clip_service_error(str(error) or type(error).__name__)) from None


def _bind_provenance(settings: ImageToolSettings, claim: Mapping[str, object], digest: str) -> str:
    """Return the prompt digest the grant and the provenance both name.

    The publication marker is the one authority for what is readable, so the
    record is read through it rather than over the artifact route;
    `image-review.py`'s `provenance_http_error` and `provenance_unreachable`
    have no counterpart here for that reason. The two equalities it does check
    stand: the record names the reviewed PNG, and the prompt digest the record
    retained is the one the approval was signed over.
    """
    provenance = settings.artifacts.provenance_for_png(digest)
    if provenance is None:
        raise ToolRefused(404, "no such artifact")
    if provenance.get("png_sha256") != digest:
        raise ToolRefused(409, "the provenance record names another PNG digest")
    recorded = provenance.get("prompt_sha256")
    if not isinstance(recorded, str) or not DIGEST_PATTERN.match(recorded):
        raise ToolRefused(409, "the provenance record names no canonical prompt digest")
    if claim.get("prompt_hash") != recorded:
        raise ToolRefused(403, "the grant was signed over another generation prompt")
    return recorded


def _constraints(body: Mapping[str, object]) -> tuple[tuple[str, str], ...]:
    """Read the declared hard constraints, refusing a shape the reviewer cannot bound.

    `image-review.py`'s own `parse_constraint` and `validate_constraints` raise
    `SystemExit` on a bad declaration, which is the right answer for a command
    and ends a server, so the rules they state -- the name pattern, the count
    ceiling, the description cap, and the duplicate refusal -- are applied here
    against the same constants.
    """
    module = review_module()
    name_pattern: re.Pattern[str] = module.CONSTRAINT_NAME_PATTERN
    maximum: int = module.MAX_CONSTRAINTS
    description_cap: int = module.CONSTRAINT_DESCRIPTION_MAX_CHARS
    declared = body.get("constraints")
    if not isinstance(declared, list) or not declared:
        raise ToolRefused(400, "a review declares at least one hard constraint")
    if len(declared) > maximum:
        raise ToolRefused(400, f"a review declares at most {maximum} hard constraints")
    constraints: list[tuple[str, str]] = []
    for entry in declared:
        if not isinstance(entry, dict):
            raise ToolRefused(400, "a constraint is an object with name and description")
        name, description = entry.get("name"), entry.get("description")
        if not isinstance(name, str) or not name_pattern.match(name):
            raise ToolRefused(
                400,
                "a constraint name is lowercase, starts with a letter, and holds "
                "letters, digits, and underscores",
            )
        if not isinstance(description, str) or not description.strip():
            raise ToolRefused(400, f"constraint {name} states no description")
        if len(description) > description_cap:
            raise ToolRefused(
                400, f"constraint {name} states more than {description_cap} characters"
            )
        constraints.append((name, description.strip()))
    names = [name for name, _ in constraints]
    if len(set(names)) != len(names):
        raise ToolRefused(400, "a constraint name is declared twice")
    return tuple(constraints)


def _post_review(
    settings: ImageToolSettings,
    png_bytes: bytes,
    prompt_hash: str,
    constraints: Sequence[tuple[str, str]],
) -> object:
    """Send the review the way `image-review.py` builds it.

    `build_review_request` carries the system instruction, the multipart text
    part ahead of the image, the absent `tools` key, thinking off, the fixed
    reply budget, and the `response_format` schema the server converts to the
    grammar that bounds every sampled token.
    """
    payload: object = review_module().build_review_request(
        settings.review_model, png_bytes, prompt_hash, list(constraints)
    )
    if not isinstance(payload, dict):
        raise ToolRefused(500, "the review request builder returned no object")
    try:
        return settings.router(cast(Mapping[str, object], payload))
    except ToolRefused:
        raise
    except Exception as error:
        raise ToolRefused(502, clip_service_error(str(error) or type(error).__name__)) from None


def _findings(
    document: object,
    constraints: Sequence[tuple[str, str]],
    digest: str,
    prompt_hash: str,
    model: str,
) -> dict[str, object]:
    """Split one reply into completion, schema validity, and judgment."""
    module = review_module()
    refused: type[Exception] = module.ReviewRefused
    names = [name for name, _ in constraints]

    completion: dict[str, object] = {
        "answered": False,
        "raw_reply": None,
        "reasoning_emitted": False,
        "refusal_code": None,
    }
    try:
        message: object = module.reply_message(document)
    except refused as refusal:
        completion["refusal_code"] = getattr(refusal, "code", "reply_refused")
        return {
            "model": model,
            "artifact_sha256": digest,
            "prompt_hash": prompt_hash,
            "completion": completion,
            "schema_validity": {"valid": False, "refusal_code": None, "verdict": None},
            "judgment": None,
        }
    completion["answered"] = True
    if isinstance(message, dict):
        content = message.get("content")
        completion["raw_reply"] = content if isinstance(content, str) else None
        completion["reasoning_emitted"] = bool(message.get("reasoning_content"))

    schema: dict[str, object] = {"valid": False, "refusal_code": None, "verdict": None}
    judgment: dict[str, object] | None = None
    try:
        verdict: object = module.parse_verdict(document, names)
    except refused as refusal:
        schema["refusal_code"] = getattr(refusal, "code", "verdict_refused")
    else:
        schema["valid"] = True
        schema["verdict"] = verdict
        admitted, reason = module.correction_admitted(verdict)
        judgment = {
            "failed": list(module.failed_constraint_names(verdict)),
            "correction_admitted": bool(admitted),
            "correction_reason": str(reason),
        }
    return {
        "model": model,
        "artifact_sha256": digest,
        "prompt_hash": prompt_hash,
        "completion": completion,
        "schema_validity": schema,
        "judgment": judgment,
    }


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


def routes(settings: ImageToolSettings) -> tuple[Route, ...]:
    """The two tool routes, each gated by the grant its own claim carries."""
    return (
        Route.make("POST", GENERATE_ROUTE, lambda request: generate(settings, request)),
        Route.make("POST", REVIEW_ROUTE, lambda request: review(settings, request)),
    )
