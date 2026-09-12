"""What each tool answers for one selected conversation model.

`qwen_apu.tools.registry` states what a tool is and which artifact executes it,
which is a property of the tree. This module states what that tool does for the
model a person has selected right now, which is a property of the ledgers, the
launch, and the filesystem together. `GET /api/tools?model=ID` answers the
join, so a page renders a refusal beside the tool that carries it instead of
composing a request the gateway answers with 403 several seconds later.

Five states close the vocabulary, and each names a different party:

- `available`: the gateway serves the route and executes the call itself.
  A web row reads this where `src/qwen_apu/tools/web.py` is mounted, and
  `helper` still names the search backend that answers the query behind it.
- `available_through_helper`: the call executes in a second process or against
  a second checkpoint, and `helper` names the model or service that runs it.
- `temporarily_unavailable`: the execution path exists and the policy admits
  it, and something the call needs is absent from this launch -- a worker
  socket, a search backend URL, a mounted route.
- `not_installed`: no artifact in this tree executes the call for this
  selection, or the asset it needs was never fetched.
- `policy_refused`: a ledger or AGENTS.md denies the execution outright. The
  refusal is reported here rather than at the call, which is the whole reason
  this module exists.

The authorities, in the order the derivations read them. `remote/models.tsv`
owns `projector` (`required` pairs a checkpoint with the projector in its own
directory, `none` runs text-only), `guarded_tool_execution` (every row reads
`refused`, and the header states that only a runtime comparing emitted
arguments against the user's own authorization moves a row, which this tree
holds none of), and `tier` (`quarantine` is terminal). `remote/web-profiles.tsv`
owns `execution_policy`, `provider`, `max_fetches`, and `searxng_url`.
`remote/image-profiles.tsv` owns `execution_policy` and `review_model`. The
approval settings own which single profile this launch's broker signs for,
since `POST /api/tools/grant-image` refuses a `profile_id` other than its own,
and the filesystem owns whether the image worker's control socket is bound and
whether the launch declared a file root.
"""

from __future__ import annotations

import json
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

from qwen_apu.config import models as config_models
from qwen_apu.config.schema import ImageProfile, ModelRow, QuarantineRow, WebProfile
from qwen_apu.tools import registry
from qwen_apu.tools.registry import ToolEntry, WebDefinitions
from qwen_apu.web.http import Request, Response, Route

MATRIX_PATH = "/api/tools"
MATRIX_SCHEMA = "qwen.tool-matrix"
MATRIX_VERSION = 1


class ToolState(StrEnum):
    """What one tool answers for one selection."""

    AVAILABLE = "available"
    AVAILABLE_THROUGH_HELPER = "available_through_helper"
    TEMPORARILY_UNAVAILABLE = "temporarily_unavailable"
    NOT_INSTALLED = "not_installed"
    POLICY_REFUSED = "policy_refused"


@dataclass(frozen=True, slots=True)
class ToolOffer:
    """One tool's identity from the registry beside its state for one selection."""

    tool_id: str
    title: str
    lane: str
    approval: str
    execution_path: str
    state: ToolState
    helper: str
    reason: str
    # The ledger ceilings a caller checks a proposal against before it asks a
    # human to approve one. Only the image generation row carries them, from
    # the armed profile's own remote/image-profiles.tsv fields.
    bounds: Mapping[str, object] | None = None
    # The OpenAI function object a request body carries for this row, present
    # on a row whose state admits a call and absent on every other, so the page
    # composes a turn's tools from the same answer that states which rows run.
    definition: Mapping[str, object] | None = None

    def as_payload(self) -> dict[str, object]:
        payload: dict[str, object] = {
            "tool_id": self.tool_id,
            "title": self.title,
            "lane": self.lane,
            "approval": self.approval,
            "execution_path": self.execution_path,
            "state": str(self.state),
            "helper": self.helper,
            "reason": self.reason,
        }
        if self.bounds is not None:
            payload["bounds"] = dict(self.bounds)
        if self.definition is not None:
            payload["definition"] = dict(self.definition)
        return payload


_EXECUTING_STATES = (ToolState.AVAILABLE, ToolState.AVAILABLE_THROUGH_HELPER)


@dataclass(frozen=True, slots=True)
class Ledgers:
    """The four ledgers a derivation reads, loaded whole before any row answers."""

    models: tuple[ModelRow, ...]
    web_profiles: tuple[WebProfile, ...]
    image_profiles: tuple[ImageProfile, ...]
    quarantine: tuple[QuarantineRow, ...] = ()

    @classmethod
    def load(
        cls,
        *,
        models_path: Path | str | None = None,
        web_profiles_path: Path | str | None = None,
        image_profiles_path: Path | str | None = None,
        quarantine_path: Path | str | None = None,
    ) -> Ledgers:
        models = config_models.load_models(models_path)
        return cls(
            models=models,
            web_profiles=config_models.load_web_profiles(web_profiles_path, models=models),
            image_profiles=config_models.load_image_profiles(image_profiles_path),
            quarantine=config_models.load_quarantine(quarantine_path),
        )


@dataclass(frozen=True, slots=True)
class MatrixSettings:
    """The launch facts a derivation reads beside the ledgers.

    `approval_profile` is the one web profile this launch's broker signs for.
    `image_profile` is empty where the launch armed no image lane.
    `image_socket` names the worker's control socket, which is bound while the
    worker runs and absent otherwise. `web_definitions` states both facts the
    web rows turn on: an assembly that mounted `qwen_apu.tools.web` passes the
    two schemas that executor advertises, and one that resolved no SearXNG
    instance passes None. Binding the mount and the schema to one field is what
    keeps a row from reading `available` while carrying no object a request
    body could forward, which would put the refusal after the proposal.
    """

    approval_profile: str
    image_profile: str = ""
    provider: str = "exa"
    open_lan: bool = False
    image_socket: Path | None = None
    file_roots: tuple[Path, ...] = ()
    documents_served: bool = True
    calculator_served: bool = True
    web_definitions: WebDefinitions | None = None
    ledgers: Ledgers | None = None

    @property
    def tool_execution_route(self) -> bool:
        """Whether this origin mounts a route that runs a model-proposed web tool."""
        return self.web_definitions is not None

    def tables(self) -> Ledgers:
        return self.ledgers if self.ledgers is not None else Ledgers.load()


@dataclass(frozen=True, slots=True)
class Selection:
    """The row the selector names: a web profile and its checkpoint, or a checkpoint."""

    selector: str
    kind: str
    model: ModelRow
    web_profile: WebProfile | None = None

    def as_payload(self) -> dict[str, object]:
        return {
            "selector": self.selector,
            "kind": self.kind,
            "model_id": self.model.id,
            "tier": self.model.tier,
            "projector": self.model.projector,
            "guarded_tool_execution": self.model.guarded_tool_execution,
            "web_profile": self.web_profile.profile_id if self.web_profile else "",
        }


def resolve_selection(ledgers: Ledgers, selector: str) -> Selection | None:
    """Return the row a picker entry names, web profile first.

    `remote/build-router-presets.sh` emits one picker section per web profile
    and one per servable checkpoint, so a selector is a `web-profiles.tsv`
    `profile_id` or a `models.tsv` `id`. The profile is tried first because a
    profile row carries the checkpoint's id in a field of its own, so resolving
    a profile also resolves its model while the reverse loses the policy.
    """
    by_id = {row.id: row for row in ledgers.models}
    for profile in ledgers.web_profiles:
        if profile.profile_id != selector:
            continue
        model = by_id.get(profile.model_id)
        if model is None:
            return None
        return Selection(selector, "web-profile", model, profile)
    model = by_id.get(selector)
    if model is None:
        return None
    return Selection(selector, "model", model)


def _offer(
    entry: ToolEntry,
    state: ToolState,
    reason: str,
    helper: str = "",
    bounds: Mapping[str, object] | None = None,
) -> ToolOffer:
    """One registry row rendered as the offer it carries for this selection.

    The schema travels with the state rather than beside it: a row whose state
    admits a call carries the function object `qwen_apu.tools.registry` holds
    for it, and every refused row carries none, so a page that composes from
    the definitions and a page that reads the states select the same rows.
    """
    return ToolOffer(
        tool_id=entry.tool_id,
        title=entry.title,
        lane=entry.lane,
        approval=str(entry.approval),
        execution_path=entry.execution_path,
        state=state,
        helper=helper,
        reason=reason,
        bounds=bounds,
        definition=entry.definition if state in _EXECUTING_STATES else None,
    )


def _image_profile_row(settings: MatrixSettings, ledgers: Ledgers) -> ImageProfile | None:
    for row in ledgers.image_profiles:
        if row.profile_id == settings.image_profile:
            return row
    return None


def _web_gate(settings: MatrixSettings, selection: Selection) -> tuple[ToolState, str, str] | None:
    """Return the refusal every web row shares, or None where the lane is open.

    The order is the order a call would meet: the profile the broker signs for,
    then the ledger's own execution policy, then the search backend the profile
    names, then the executor this origin mounts.
    """
    profile = selection.web_profile
    if profile is None:
        return (
            ToolState.NOT_INSTALLED,
            f"no row of remote/web-profiles.tsv names {selection.model.id}, "
            "so no MCP child holds a web tool for this checkpoint",
            "",
        )
    if profile.profile_id != settings.approval_profile:
        return (
            ToolState.POLICY_REFUSED,
            f"this launch's broker signs for {settings.approval_profile} alone, so a grant "
            f"naming {profile.profile_id} is refused before it is minted",
            "",
        )
    if profile.execution_policy != "validator-gated":
        return (
            ToolState.POLICY_REFUSED,
            f"remote/web-profiles.tsv reads execution_policy {profile.execution_policy} "
            f"for {profile.profile_id}, which admits a shape and runs nothing",
            "",
        )
    if profile.provider == "searxng" and not profile.searxng_url:
        return (
            ToolState.TEMPORARILY_UNAVAILABLE,
            f"{profile.profile_id} names provider searxng and no instance URL",
            profile.provider,
        )
    if not settings.tool_execution_route:
        return (
            ToolState.TEMPORARILY_UNAVAILABLE,
            "this origin mounts the approval and grant routes and no tool executor, "
            "so a proposed call reaches src/qwen_apu/tools/web.py through no route here",
            profile.provider,
        )
    return None


def _admitted_profile(selection: Selection) -> WebProfile:
    """The profile `_web_gate` has already admitted.

    The gate returns a refusal for a selection carrying no profile, so every
    caller that reaches here holds one; reading it again through this function
    keeps the type narrow without an assertion the runtime would carry.
    """
    profile = selection.web_profile
    if profile is None:
        raise RuntimeError("the web gate admitted a selection naming no web profile")
    return profile


def _web_search(settings: MatrixSettings, selection: Selection, entry: ToolEntry) -> ToolOffer:
    refusal = _web_gate(settings, selection)
    if refusal is not None:
        return _offer(entry, refusal[0], refusal[1], refusal[2])
    profile = _admitted_profile(selection)
    return _offer(
        entry,
        ToolState.AVAILABLE,
        f"one human approval mints one single-use grant over the query, "
        f"src/qwen_apu/tools/web.py runs it inside this gateway, and {profile.provider} "
        f"answers at most {profile.max_results} results",
        profile.provider,
    )


def _read_url(settings: MatrixSettings, selection: Selection, entry: ToolEntry) -> ToolOffer:
    refusal = _web_gate(settings, selection)
    if refusal is not None:
        return _offer(entry, refusal[0], refusal[1], refusal[2])
    profile = _admitted_profile(selection)
    return _offer(
        entry,
        ToolState.AVAILABLE,
        f"src/qwen_apu/tools/web.py reads the page inside this gateway, and the approved "
        f"search's own fetch allowance is {profile.max_fetches} document"
        f"{'' if profile.max_fetches == 1 else 's'}, redeemed through a signed Result ID",
        profile.provider,
    )


def _wikipedia(settings: MatrixSettings, selection: Selection, entry: ToolEntry) -> ToolOffer:
    refusal = _web_gate(settings, selection)
    if refusal is not None:
        return _offer(entry, refusal[0], refusal[1], refusal[2])
    profile = _admitted_profile(selection)
    if profile.provider != "searxng":
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            f"the wikipedia engine profile lives in the SearXNG instance's own settings.yml, "
            f"and {profile.profile_id} names provider {profile.provider}",
        )
    return _offer(
        entry,
        ToolState.AVAILABLE_THROUGH_HELPER,
        f"the instance answers category {profile.primary_category} under the same grant "
        "every search takes",
        profile.provider,
    )


def _image_interpretation(
    settings: MatrixSettings, selection: Selection, entry: ToolEntry
) -> ToolOffer:
    del settings
    if selection.model.projector != "required":
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            f"remote/models.tsv reads projector {selection.model.projector} for "
            f"{selection.model.id}, so remote/select-projector.sh finds none beside the "
            "checkpoint and the row runs text-only",
        )
    return _offer(
        entry,
        ToolState.AVAILABLE,
        f"{selection.model.id} loads the projector its own directory holds, so an attached "
        "image is read inside the turn the user already sent",
    )


def _image_generation(
    settings: MatrixSettings, selection: Selection, entry: ToolEntry
) -> ToolOffer:
    del selection
    ledgers = settings.tables()
    if not settings.image_profile:
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            "this launch armed no image lane, so no worker holds the Vulkan workload lease",
        )
    profile = _image_profile_row(settings, ledgers)
    if profile is None:
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            f"no row of remote/image-profiles.tsv carries profile_id {settings.image_profile}",
        )
    if profile.execution_policy != "validator-gated":
        return _offer(
            entry,
            ToolState.POLICY_REFUSED,
            f"remote/image-profiles.tsv reads execution_policy {profile.execution_policy} for "
            f"{profile.profile_id}, which admits a shape and spends no device time",
            profile.model_id,
        )
    if settings.image_socket is None or not settings.image_socket.is_socket():
        return _offer(
            entry,
            ToolState.TEMPORARILY_UNAVAILABLE,
            "the image worker's control socket is unbound, so no process holds the job lock",
            profile.model_id,
        )
    return _offer(
        entry,
        ToolState.AVAILABLE_THROUGH_HELPER,
        f"one grant binds the prompt digests, the seed, and the {profile.width}x{profile.height} "
        f"geometry at most {profile.max_steps} steps, and the worker runs one job with no queue",
        profile.model_id,
        bounds={
            "profile_id": profile.profile_id,
            "width": profile.width,
            "height": profile.height,
            "max_dimension": profile.max_dimension,
            "max_steps": profile.max_steps,
        },
    )


def _image_review(settings: MatrixSettings, selection: Selection, entry: ToolEntry) -> ToolOffer:
    del selection
    ledgers = settings.tables()
    if not settings.image_profile:
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            "this launch armed no image lane, so no profile names a reviewer",
        )
    profile = _image_profile_row(settings, ledgers)
    if profile is None:
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            f"no row of remote/image-profiles.tsv carries profile_id {settings.image_profile}",
        )
    if profile.review_model is None:
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            f"remote/image-profiles.tsv reads review_model - for {profile.profile_id}, "
            "so the shape offers no review",
        )
    reviewer = next((row for row in ledgers.models if row.id == profile.review_model), None)
    if reviewer is None:
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            f"remote/models.tsv carries no row for the registered reviewer {profile.review_model}",
            profile.review_model,
        )
    if reviewer.projector != "required":
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            f"the registered reviewer {reviewer.id} reads projector {reviewer.projector}, "
            "so it loads no image",
            reviewer.id,
        )
    if profile.execution_policy != "validator-gated":
        return _offer(
            entry,
            ToolState.POLICY_REFUSED,
            f"a review runs under the same qwen-image-generate-v1 grant a generation takes, and "
            f"{profile.profile_id} reads execution_policy {profile.execution_policy}",
            reviewer.id,
        )
    return _offer(
        entry,
        ToolState.AVAILABLE_THROUGH_HELPER,
        f"{reviewer.id} reads the published artifact and answers one closed verdict object; "
        "completion, schema validity, and judgment are reported apart",
        reviewer.id,
    )


def _documents(settings: MatrixSettings, selection: Selection, entry: ToolEntry) -> ToolOffer:
    del selection
    if not settings.documents_served:
        return _offer(
            entry,
            ToolState.NOT_INSTALLED,
            "this gateway mounts no document routes",
        )
    return _offer(
        entry,
        ToolState.AVAILABLE,
        "an upload extracts in an owned worker process under its own limits and stores one "
        "record under artifacts/documents/<sha256>/",
    )


def _calculator(settings: MatrixSettings, selection: Selection, entry: ToolEntry) -> ToolOffer:
    del selection
    if not settings.calculator_served:
        return _offer(entry, ToolState.NOT_INSTALLED, "this gateway mounts no calculator route")
    return _offer(
        entry,
        ToolState.AVAILABLE,
        "an arithmetic expression evaluates over a closed grammar inside the gateway process",
    )


def _file_search(settings: MatrixSettings, selection: Selection, entry: ToolEntry) -> ToolOffer:
    if not settings.file_roots:
        return _offer(
            entry,
            ToolState.POLICY_REFUSED,
            "this launch declared no --file-root, so the scoped search reaches nothing",
        )
    if selection.model.guarded_tool_execution != "unguarded":
        count = len(settings.file_roots)
        return _offer(
            entry,
            ToolState.AVAILABLE,
            f"the search runs over {count} declared root{'' if count == 1 else 's'} with symlink "
            "escapes refused; remote/models.tsv reads guarded_tool_execution "
            f"{selection.model.guarded_tool_execution} for {selection.model.id}, so a person "
            "names the pattern and a model-emitted call runs nothing. The roots themselves stay "
            "off this answer, since a path is the launch's own configuration",
        )
    return _offer(
        entry,
        ToolState.AVAILABLE,
        "the search runs over the declared roots with symlink escapes refused",
    )


def _artifact_export(settings: MatrixSettings, selection: Selection, entry: ToolEntry) -> ToolOffer:
    del settings, selection
    return _offer(
        entry,
        ToolState.NOT_INSTALLED,
        "no artifact in this tree writes a conversation or an artifact out of the appliance",
    )


def _code_tools(settings: MatrixSettings, selection: Selection, entry: ToolEntry) -> ToolOffer:
    del settings
    return _offer(
        entry,
        ToolState.POLICY_REFUSED,
        "--tools all grants shell execution and file writing to a prompt-injectable model, which "
        "AGENTS.md keeps off every LAN-reaching server; remote/models.tsv reads "
        f"guarded_tool_execution {selection.model.guarded_tool_execution} for "
        f"{selection.model.id}",
    )


_DERIVATIONS = {
    "web_search": _web_search,
    "read_url": _read_url,
    "wikipedia_profile": _wikipedia,
    "image_interpretation": _image_interpretation,
    "image_generation": _image_generation,
    "image_review": _image_review,
    "documents": _documents,
    "calculator": _calculator,
    "local_file_search": _file_search,
    "artifact_export": _artifact_export,
    "code_tools": _code_tools,
}


def quarantine_refusal(ledgers: Ledgers, model: ModelRow) -> str:
    """The sentence a quarantined checkpoint refuses every row with, or `` for none.

    remote/quarantine.tsv's own header states that a reader derives the
    excluded state from the ledger rather than from the tier field alone,
    because a quarantine carries two scopes: a `model` row excludes the
    checkpoint whatever tier its registry row reads, and a `profile` row
    excludes one tuple of a checkpoint the picker still serves. A tier that
    reads `quarantine` refuses on its own as well, so a ledger row removed
    without its tier still refuses here.
    """
    for row in ledgers.quarantine:
        if row.scope == "model" and row.subject == model.id:
            return (
                f"remote/quarantine.tsv excludes {model.id} at model scope for "
                f"{row.failure_class}, recorded in {row.reason_record}"
            )
    if model.tier == "quarantine":
        return (
            f"remote/models.tsv reads tier quarantine for {model.id}, and "
            "remote/quarantine.tsv carries the reset, fault, or correctness hazard behind it"
        )
    return ""


def offers(settings: MatrixSettings, selection: Selection) -> tuple[ToolOffer, ...]:
    """Every registry row with the state it carries for one selection.

    A quarantined checkpoint refuses every row at once, because
    `remote/build-router-presets.sh` keeps a quarantined checkpoint out of the
    picker and a selector that names one has reached this route around that
    filter.
    """
    entries = registry.table(web_definitions=settings.web_definitions)
    excluded = quarantine_refusal(settings.tables(), selection.model)
    if excluded:
        return tuple(_offer(entry, ToolState.POLICY_REFUSED, excluded) for entry in entries)
    built: list[ToolOffer] = []
    for entry in entries:
        derive = _DERIVATIONS.get(entry.tool_id)
        if derive is None:
            built.append(
                _offer(
                    entry,
                    ToolState.NOT_INSTALLED,
                    "this module states no derivation for the row, so it offers nothing",
                )
            )
            continue
        built.append(derive(settings, selection, entry))
    return tuple(built)


def matrix_payload(settings: MatrixSettings, selection: Selection) -> dict[str, object]:
    """The document `GET /api/tools?model=ID` answers with."""
    return {
        "schema": MATRIX_SCHEMA,
        "version": MATRIX_VERSION,
        "selection": selection.as_payload(),
        "launch": {
            "approval_profile": settings.approval_profile,
            "image_profile": settings.image_profile,
            "provider": settings.provider,
            "open_lan": settings.open_lan,
        },
        "tools": [offer.as_payload() for offer in offers(settings, selection)],
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


def handle(settings: MatrixSettings, request: Request) -> Response:
    """Answer the matrix for the named model, or refuse with the reason.

    The selector is required rather than defaulted, because a matrix that
    described no selection would state availability for a checkpoint the page
    never chose and the page would route on it.
    """
    selector = request.query.get("model", "")
    if not selector:
        return _json(
            400,
            {"error": "GET /api/tools names the selected conversation model as ?model=ID"},
        )
    ledgers = settings.tables()
    selection = resolve_selection(ledgers, selector)
    if selection is None:
        return _json(
            404,
            {
                "error": "no row of remote/web-profiles.tsv or remote/models.tsv "
                f"carries the id {selector}"
            },
        )
    return _json(200, matrix_payload(settings, selection))


def routes(settings: MatrixSettings) -> tuple[Route, ...]:
    """The one matrix route mounted under the gateway."""
    return (Route.make("GET", MATRIX_PATH, lambda request: handle(settings, request)),)


def offered_tool_ids(payload: Sequence[dict[str, object]]) -> tuple[str, ...]:
    """The rows of one matrix payload whose state admits a call."""
    executing = {str(state) for state in _EXECUTING_STATES}
    return tuple(str(row["tool_id"]) for row in payload if row.get("state") in executing)
