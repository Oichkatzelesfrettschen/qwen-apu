"""What the appliance serves right now, joined from the three authorities.

The picker used to answer from `remote/models.tsv` alone, so the shadow pass
read thirteen models against one served checkpoint. Three authorities decide
the answer instead, and each one contributes a claim the other two cannot make.
The activated deployment's router preset states which checkpoints this bundle
is configured to serve; the live upstream's `/v1/models` states which of them is
resident; the registry states the tier, role, depth, and projector pairing a
picker displays. A row present in all three is `ready`, and every other row
carries the state that says which authority left it out.

`state` therefore names a condition rather than a capability:

    ready        the deployment configures it and the upstream serves it now
    loading      the deployment configures it and the upstream has yet to
                 resident it, which `--models-max 1` produces by design
    unavailable  the upstream answered no roster, so residency is unknown
    quarantined  remote/quarantine.tsv excludes the checkpoint at model scope
    refused      the registry admits no row, or the deployment serves no
                 section naming it

The single-model launch is the case that makes the served name and the registry
id differ: its argv carries `--alias qwen-apu`, so the upstream reports that
alias for whichever checkpoint the argv named. `state/runtime.json` carries both
-- `model_id` from the registry and `served_models` from the probe -- and the
join here reads that record rather than inferring the pairing from a name.
"""

from __future__ import annotations

import re
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path

from qwen_apu.config import models as registry
from qwen_apu.config.schema import ModelRow
from qwen_apu.runtime import policy
from qwen_apu.runtime import state as runtime_state

READY = "ready"
LOADING = "loading"
UNAVAILABLE = "unavailable"
QUARANTINED = "quarantined"
REFUSED = "refused"
ROSTER_STATES: tuple[str, ...] = (READY, LOADING, UNAVAILABLE, QUARANTINED, REFUSED)

# The two tiers remote/build-router-presets.sh admits into a picker section: a
# production row carries a serving tuple measured safe and useful, a candidate
# row leaves quality or performance unqualified while no reset, fault, or
# device loss exists under its admitted tuple.
PICKER_TIERS: tuple[str, ...] = ("production", "candidate")

STANDALONE_ALIAS = "qwen-apu"

# The quantization a GGUF filename states, as the publishers in this registry
# spell it: `Q4_K_M`, `Q8_0`, `F16`, `UD-Q2_K_XL`, `IQ3_XXS`. An imatrix marker
# such as `i1` precedes the delimiter and stays out of the value.
_QUANTIZATION = re.compile(r"[.\-_]((?:UD-)?(?:IQ|Q)[0-9]+(?:_[0-9A-Z]+)*|BF16|F16|F32)\.gguf$")
_ABSENT = "-"


def quantization(model_file: str) -> str:
    """The quantization one `model_file` names, or `-` where the name states none."""
    found = _QUANTIZATION.search(model_file)
    return found.group(1) if found else _ABSENT


@dataclass(frozen=True, slots=True)
class UpstreamRoster:
    """What one `/v1/models` exchange observed, reachable or not."""

    reachable: bool
    names: tuple[str, ...] = ()
    reason: str = "-"


@dataclass(frozen=True, slots=True)
class Admission:
    """What the live router admits, and the name it reports for each admitted id.

    `admitted` is what a request may name. Router mode admits every preset
    section, including the sections no load has made resident: `--models-max 1`
    keeps one model in memory and the router loads another on demand, so
    residency bounds latency rather than admission. The standalone launch admits
    the one checkpoint its argv named, under either the registry id or the
    alias.

    `served_name` maps a request's model to the name the upstream states back,
    which is the identity the served-model check compares. Router sections carry
    their own names; the standalone launch reports its alias for the registry id
    behind it.
    """

    mode: str
    admitted: frozenset[str]
    served_name: Mapping[str, str]

    def expected_name(self, requested: str) -> str:
        return self.served_name.get(requested, requested)


def resolve_admission(
    record_path: Path | None, sections: Sequence[str], upstream: UpstreamRoster
) -> Admission:
    """Join the runtime record, the preset sections, and the live roster.

    A record the supervisor never wrote, an absent path, or one in a terminal
    state admits the names the upstream itself reports: a gateway pointed at a
    server it did not supervise still serves, and the upstream's own roster is
    then the only claim available about what that server answers for.
    """
    record = runtime_state.read(record_path) if record_path is not None else None
    mode = record.mode if record is not None else "standalone"
    if mode == "router":
        admitted = frozenset(sections) | frozenset(upstream.names)
        return Admission(mode, admitted, {name: name for name in admitted})

    served = tuple(upstream.names) or (tuple(record.served_models) if record is not None else ())
    alias = served[0] if served else STANDALONE_ALIAS
    names: dict[str, str] = {name: name for name in served}
    standalone: set[str] = set(served)
    if record is not None and record.model_id not in ("", "-"):
        standalone.add(record.model_id)
        names[record.model_id] = alias
    return Admission(mode, frozenset(standalone), names)


def _quarantined_ids(quarantine_path: Path | None = None) -> frozenset[str]:
    """Every checkpoint remote/quarantine.tsv excludes at model scope.

    A `profile` scope row excludes one serving tuple rather than the checkpoint,
    and the policy refuses such a section when the preset names that tuple, so
    the roster reads the model-scope rows alone.
    """
    return frozenset(
        row.subject for row in registry.load_quarantine(quarantine_path) if row.scope == "model"
    )


def entry(model_id: str, row: ModelRow | None, state: str, served_as: str) -> dict[str, object]:
    """One picker row: what the registry claims, beside what the runtime observed."""
    return {
        "id": model_id,
        "state": state,
        "served_as": served_as,
        "role": row.role if row else "-",
        "tier": row.tier if row else "-",
        "context_default": row.context_default if row else 0,
        "projector": row.projector if row else "-",
        "quantization": quantization(row.model_file) if row else "-",
    }


def _state_of(  # noqa: PLR0917
    model_id: str,
    *,
    row: ModelRow | None,
    served: frozenset[str],
    served_as: str,
    quarantined: frozenset[str],
    admitted: frozenset[str],
    reachable: bool,
) -> str:
    """One entry's state, decided in the order the three authorities exclude.

    Quarantine is read first because it excludes a checkpoint whatever else
    admits it, and the registry second because a section the registry carries no
    row for is a preset this tree cannot describe. Residency is read last, since
    it is the one condition that changes between two reads of one deployment.
    """
    if model_id in quarantined:
        return QUARANTINED
    if row is None or model_id not in admitted:
        return REFUSED
    if not reachable:
        return UNAVAILABLE
    return READY if served_as in served else LOADING


def build(
    *,
    rows: Sequence[ModelRow],
    sections: Sequence[str] | None,
    upstream: UpstreamRoster,
    admission: Admission,
    quarantine_path: Path | None = None,
    research: bool = False,
) -> list[dict[str, object]]:
    """The roster one `GET /api/models` answers with, in a stable order.

    `sections` is `None` where no activated deployment names a router preset,
    which is what a single-model launch looks like: the candidate set is then
    what the runtime record and the upstream between them name, rather than
    every registry row. A research read widens the candidate set to the whole
    registry beside those, so an experiment sees the rows the deployment leaves
    out and the state that says why.
    """
    by_id = {row.id: row for row in rows}
    quarantined = _quarantined_ids(quarantine_path)
    served = frozenset(upstream.names)

    candidates: list[str] = []
    if sections is not None:
        # A preset section the registry carries no row for is a deployment
        # claim this tree cannot describe, so it stays in the answer as
        # `refused` rather than disappearing from it.
        candidates.extend(sections)
    else:
        # The standalone launch names its server `--alias qwen-apu`, so the
        # upstream reports the alias beside the registry id the record carries
        # and the admitted set holds both. Listing both would put two picker
        # rows behind one served checkpoint, one of them a name no registry row
        # describes, so the candidates here are the admitted names the registry
        # does describe. A gateway against a server it did not supervise
        # matches no row at all, and then the upstream's own names are the only
        # claim available and stand as the answer.
        described = [name for name in sorted(admission.admitted) if name in by_id]
        candidates.extend(described or sorted(admission.admitted))
    if research:
        candidates.extend(row.id for row in rows)

    ordered: list[str] = []
    seen: set[str] = set()
    for model_id in candidates:
        if model_id not in seen:
            seen.add(model_id)
            ordered.append(model_id)

    answer: list[dict[str, object]] = []
    for model_id in ordered:
        row = by_id.get(model_id)
        served_as = admission.expected_name(model_id)
        state = _state_of(
            model_id,
            row=row,
            served=served,
            served_as=served_as,
            quarantined=quarantined,
            admitted=admission.admitted,
            reachable=upstream.reachable,
        )
        answer.append(entry(model_id, row, state, served_as))
    return answer


def deployment_sections(presets: Path | None) -> tuple[str, ...] | None:
    """Every section the activated deployment's router preset names, or None.

    `None` states that no router preset is in play, which is what a single-model
    launch and a root holding no deployment both look like; an empty tuple would
    state a preset naming no section, which the policy refuses before a server
    starts.
    """
    if presets is None:
        return None
    return tuple(section.name for section in policy.preset_sections(presets))
