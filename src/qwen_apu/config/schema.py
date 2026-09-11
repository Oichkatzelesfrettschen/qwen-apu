"""Typed rows for every TSV ledger under remote/.

Each dataclass names one row of one ledger, in the column order
remote/model-registry.sh, remote/check-validated-tuples.sh, and the sibling
readers already read. A field types as `int` where the ledger's own
production regex admits only canonical decimal digits, and as `str`
everywhere else, because a ledger id, path, or evidence pointer carries no
arithmetic meaning.

A `-` cell is the ledger's own sentinel for "no claim made here", distinct
from an empty string, which every reader here refuses as a malformed row. A
field that carries `-` on an admitted row types as `str | None` and the
loader maps `-` to `None`; a field the ledger never sets to `-` keeps a bare
`str` or `int` and a `-` there is a row the validator refuses. The one
exception is `ModelRow.q4k_variant`, whose own vocabulary counts `-` as one
of its closed members (the production module, served unkeyed) rather than as
an absent claim, so that field keeps `str` and carries the literal `-`.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

Tier = Literal["production", "candidate", "quarantine", "archive", "rejected"]
TIER_VALUES: frozenset[str] = frozenset(
    {"production", "candidate", "quarantine", "archive", "rejected"}
)

CacheType = Literal["f32", "f16", "bf16", "q8_0", "q5_1", "q5_0", "q4_1", "q4_0", "iq4_nl"]
CACHE_TYPE_VALUES: frozenset[str] = frozenset(
    {"f32", "f16", "bf16", "q8_0", "q5_1", "q5_0", "q4_1", "q4_0", "iq4_nl"}
)

FlashAttention = Literal["on", "off", "auto"]
FLASH_ATTENTION_VALUES: frozenset[str] = frozenset({"on", "off", "auto"})

Projector = Literal["none", "required"]
PROJECTOR_VALUES: frozenset[str] = frozenset({"none", "required"})

GuardedToolExecution = Literal["refused", "validator-gated", "unguarded"]
GUARDED_TOOL_EXECUTION_VALUES: frozenset[str] = frozenset(
    {"refused", "validator-gated", "unguarded"}
)

# The Q4_K mat-vec formulation vocabulary, closed the way validate_q4k_variant
# closes it in remote/model-registry.sh: `-` names the production module
# served unkeyed, `production/4` names that same module through the
# multiplexer, and the remaining eight members pair one of three named
# formulations with one of the /2, /4, /8 group widths.
Q4K_VARIANT_VALUES: frozenset[str] = frozenset(
    {
        "-",
        "production/4",
        "e4/2",
        "e4/4",
        "e4/8",
        "e4-scale/2",
        "e4-scale/4",
        "e4-scale/8",
        "e4-scale-licm/2",
        "e4-scale-licm/4",
        "e4-scale-licm/8",
    }
)
Q4KVariant = Literal[
    "-",
    "production/4",
    "e4/2",
    "e4/4",
    "e4/8",
    "e4-scale/2",
    "e4-scale/4",
    "e4-scale/8",
    "e4-scale-licm/2",
    "e4-scale-licm/4",
    "e4-scale-licm/8",
]

RuntimeMode = Literal["standalone", "router-child"]
RUNTIME_MODE_VALUES: frozenset[str] = frozenset({"standalone", "router-child"})

ProjectorState = Literal["none", "loaded"]
PROJECTOR_STATE_VALUES: frozenset[str] = frozenset({"none", "loaded"})

Backend = Literal["vulkan", "cpu", "hip"]
BACKEND_VALUES: frozenset[str] = frozenset({"vulkan", "cpu", "hip"})

TupleStatus = Literal["validated", "failed", "unverified"]
TUPLE_STATUS_VALUES: frozenset[str] = frozenset({"validated", "failed", "unverified"})

QuarantineScope = Literal["model", "profile"]
QUARANTINE_SCOPE_VALUES: frozenset[str] = frozenset({"model", "profile"})

QuarantineRuntimeMode = Literal["any", "router-child", "standalone"]
QUARANTINE_RUNTIME_MODE_VALUES: frozenset[str] = frozenset({"any", "router-child", "standalone"})

# remote/quarantine.tsv's own header comment names the closed failure_class
# vocabulary; a scope `model` row carries `-` here in every observed row, so
# the field types as a plain str that also accepts the sentinel.
FailureClass = Literal[
    "ring-timeout-only",
    "gfxhub-page-fault",
    "vm-protection-fault",
    "device-lost",
    "post-reset-control-failure",
    "no-validated-safe-tuple",
    "graph-assert-abort",
]
FAILURE_CLASS_VALUES: frozenset[str] = frozenset(
    {
        "ring-timeout-only",
        "gfxhub-page-fault",
        "vm-protection-fault",
        "device-lost",
        "post-reset-control-failure",
        "no-validated-safe-tuple",
        "graph-assert-abort",
    }
)

PatchStage = Literal["production", "candidate"]
PATCH_STAGE_VALUES: frozenset[str] = frozenset({"production", "candidate"})

WebMode = Literal["validator-gated", "ui-mediated"]
WEB_MODE_VALUES: frozenset[str] = frozenset({"validator-gated", "ui-mediated"})

ExecutionPolicy = Literal["refused", "validator-gated"]
EXECUTION_POLICY_VALUES: frozenset[str] = frozenset({"refused", "validator-gated"})

SearchProvider = Literal["searxng", "exa", "fake"]
SEARCH_PROVIDER_VALUES: frozenset[str] = frozenset({"searxng", "exa", "fake"})

YesNo = Literal["yes", "no"]
YES_NO_VALUES: frozenset[str] = frozenset({"yes", "no"})

FeatureClaimStatus = Literal["production", "candidate", "experimental", "unstable", "unsupported"]
FEATURE_CLAIM_STATUS_VALUES: frozenset[str] = frozenset(
    {"production", "candidate", "experimental", "unstable", "unsupported"}
)

# remote/build-feature-roster.sh's feature_scope table: the closed feature
# vocabulary and which ledger id namespace each member's subject_id names.
MODEL_SCOPED_FEATURES: frozenset[str] = frozenset(
    {
        "text-chat",
        "vision",
        "tool-selection",
        "guarded-tool-execution",
        "long-context",
        "context-checkpoints",
        "quarantine",
        "q4k-formulation",
    }
)
DRAFT_PAIR_SCOPED_FEATURES: frozenset[str] = frozenset({"draft-pair-speculation"})
WEB_PROFILE_SCOPED_FEATURES: frozenset[str] = frozenset({"web-search"})
IMAGE_PROFILE_SCOPED_FEATURES: frozenset[str] = frozenset({"image-generation", "image-review"})
FEATURE_VALUES: frozenset[str] = (
    MODEL_SCOPED_FEATURES
    | DRAFT_PAIR_SCOPED_FEATURES
    | WEB_PROFILE_SCOPED_FEATURES
    | IMAGE_PROFILE_SCOPED_FEATURES
)


@dataclass(frozen=True, slots=True)
class ModelRow:
    """One row of remote/models.tsv: an admitted checkpoint and its serving claim.

    `decode_tok_s` and `prefill_tok_s` carry `-` where the row is admitted on
    a different basis than the sweep, so they type as `float | None`.
    `validated_filled_depth` carries `-` where no depth has been filled and
    decoded, so it types as `int | None`; `validation_evidence` follows the
    same sentinel. `raw_tool_selection` carries `unmeasured` beside a graded
    `N/10`, so it stays `str`. `quality` mixes two incompatible scales
    (`NN/55` and `5/5-screen`) plus `untested`, so it stays `str` as well.
    """

    id: str
    role: str
    model_file: str
    fetch_script: str
    context_default: int
    context_ceiling: int
    context_target: int
    cache_type_k: str
    cache_type_v: str
    flash_attention: str
    projector: str
    projector_fetch_script: str | None
    decode_tok_s: float | None
    prefill_tok_s: float | None
    quality: str
    tier: str
    batch: int
    ubatch: int
    validated_filled_depth: int | None
    validation_evidence: str | None
    raw_tool_selection: str
    guarded_tool_execution: str
    q4k_variant: str


MODEL_ROW_FIELDS: tuple[str, ...] = (
    "id",
    "role",
    "model_file",
    "fetch_script",
    "context_default",
    "context_ceiling",
    "context_target",
    "cache_type_k",
    "cache_type_v",
    "flash_attention",
    "projector",
    "projector_fetch_script",
    "decode_tok_s",
    "prefill_tok_s",
    "quality",
    "tier",
    "batch",
    "ubatch",
    "validated_filled_depth",
    "validation_evidence",
    "raw_tool_selection",
    "guarded_tool_execution",
    "q4k_variant",
)


@dataclass(frozen=True, slots=True)
class ValidatedTuple:
    """One row of remote/validated-tuples.tsv: one measured serving arm."""

    tuple_id: str
    model_id: str
    runtime_mode: str
    context: int
    batch: int
    ubatch: int
    cache_k: str
    cache_v: str
    flash_attention: str
    threads: int
    parallel: int
    projector_state: str
    backend: str
    status: str
    evidence: str | None
    llama_commit: str | None
    runner_sha256: str | None
    kernel: str | None
    mesa: str | None
    amdgpu: str | None
    measured_at: str | None


VALIDATED_TUPLE_FIELDS: tuple[str, ...] = (
    "tuple_id",
    "model_id",
    "runtime_mode",
    "context",
    "batch",
    "ubatch",
    "cache_k",
    "cache_v",
    "flash_attention",
    "threads",
    "parallel",
    "projector_state",
    "backend",
    "status",
    "evidence",
    "llama_commit",
    "runner_sha256",
    "kernel",
    "mesa",
    "amdgpu",
    "measured_at",
)


@dataclass(frozen=True, slots=True)
class DraftPair:
    """One row of remote/draft-pairs.tsv: a target checkpoint drafted by another."""

    pair_id: str
    target_model_id: str
    draft_model_id: str
    tier: str
    spec_draft_n_max: int
    spec_draft_p_min: float
    acceptance_floor: float
    draft_context: int
    draft_cache_type_k: str
    draft_cache_type_v: str
    validated_evidence: str | None
    notes: str


DRAFT_PAIR_FIELDS: tuple[str, ...] = (
    "pair_id",
    "target_model_id",
    "draft_model_id",
    "tier",
    "spec_draft_n_max",
    "spec_draft_p_min",
    "acceptance_floor",
    "draft_context",
    "draft_cache_type_k",
    "draft_cache_type_v",
    "validated_evidence",
    "notes",
)


@dataclass(frozen=True, slots=True)
class QuarantineRow:
    """One row of remote/quarantine.tsv: a checkpoint or one of its tuples excluded.

    `scope` `model` carries `-` in every geometry field
    (depth/batch/ubatch/cache_type_k/cache_type_v/flash_attention), so those
    six fields type as `str | None` and the loader maps `-` to `None`
    regardless of scope; a `scope` `profile` row is the one that fills them.
    """

    id: str
    scope: str
    subject: str
    failure_class: str
    depth: int | None
    batch: int | None
    ubatch: int | None
    cache_type_k: str | None
    cache_type_v: str | None
    flash_attention: str | None
    first_evidence: str
    latest_evidence: str
    reason_record: str
    runtime_mode: str


QUARANTINE_ROW_FIELDS: tuple[str, ...] = (
    "id",
    "scope",
    "subject",
    "failure_class",
    "depth",
    "batch",
    "ubatch",
    "cache_type_k",
    "cache_type_v",
    "flash_attention",
    "first_evidence",
    "latest_evidence",
    "reason_record",
    "runtime_mode",
)


@dataclass(frozen=True, slots=True)
class CtxCheckpointRow:
    """One row of remote/ctx-checkpoints.tsv: the checkpoint count one model serves at."""

    model_id: str
    ctx_checkpoints: int
    evidence: str | None


CTX_CHECKPOINT_ROW_FIELDS: tuple[str, ...] = ("model_id", "ctx_checkpoints", "evidence")


@dataclass(frozen=True, slots=True)
class ModelArtifact:
    """One row of remote/model-artifacts.tsv: a publisher-pinned fetched artifact."""

    model_id: str
    model_file: str
    expected_bytes: int
    expected_sha256: str
    source_repository: str
    source_revision: str


MODEL_ARTIFACT_FIELDS: tuple[str, ...] = (
    "model_id",
    "model_file",
    "expected_bytes",
    "expected_sha256",
    "source_repository",
    "source_revision",
)


@dataclass(frozen=True, slots=True)
class PatchSeriesMember:
    """One row of remote/llama-patch-series.tsv: one patch at one stage."""

    stage: str
    patch: str


PATCH_SERIES_MEMBER_FIELDS: tuple[str, ...] = ("stage", "patch")


@dataclass(frozen=True, slots=True)
class WebProfile:
    """One row of remote/web-profiles.tsv: a policy for one web-enabled router preset.

    `primary_category`, `fallback_category`, `minimum_results`, and
    `searxng_url` read `-` under provider `exa` or `fake`, so those four type
    as `str | None` / `int | None` and the loader maps `-` to `None`.
    """

    profile_id: str
    model_id: str
    web_mode: str
    context: int
    validated_filled_depth: int | None
    max_results: int
    max_fetches: int
    max_chars_per_fetch: int
    multi_source: str
    vision_allowed: str
    tool_selection: str
    execution_policy: str
    provider: str
    primary_category: str | None
    fallback_category: str | None
    minimum_results: int | None
    searxng_url: str | None


WEB_PROFILE_FIELDS: tuple[str, ...] = (
    "profile_id",
    "model_id",
    "web_mode",
    "context",
    "validated_filled_depth",
    "max_results",
    "max_fetches",
    "max_chars_per_fetch",
    "multi_source",
    "vision_allowed",
    "tool_selection",
    "execution_policy",
    "provider",
    "primary_category",
    "fallback_category",
    "minimum_results",
    "searxng_url",
)


@dataclass(frozen=True, slots=True)
class FeatureClaim:
    """One row of remote/feature-claims.tsv: one (subject, feature) claim."""

    subject_id: str
    feature: str
    status: str
    evidence: str | None
    note: str


FEATURE_CLAIM_FIELDS: tuple[str, ...] = ("subject_id", "feature", "status", "evidence", "note")
