"""Typed readers over every remote/*.tsv ledger, one function per shell subcommand.

Each loader here validates its whole ledger before returning a row, the
discipline remote/model-registry.sh names explicitly for the tuple,
draft-pair, and context-checkpoint ledgers ("a caller reading one row must
not trust a ledger a sibling row has made unsafe to read") and this module
applies uniformly to every ledger it reads. A refusal raises
`qwen_apu.config.loader.RegistryError`, and its message repeats the shell's
own wording where the shell names one field, one row, and one reason.

Two parity notes on remote/models.tsv specifically. First,
remote/model-registry.sh's own `id`/`path` selector (the code path at the
bottom of the file, reached when no earlier subcommand matches) validates
less than `emit_servable_rows` does: it skips a row on `NF < 23` alone and
never checks the closed `q4k_variant` vocabulary, while `emit_servable_rows`
(behind `servable-files`/`servable-ids`) requires `NF == 23` exactly and
refuses an out-of-vocabulary `q4k_variant`. `load_models` here always applies
the stricter rule, because "validates the whole ledger before answering" is
the behavior this module commits to for every ledger; a caller relying on the
shell's more permissive `id`/`path` path should not assume Python's
`model_by_id`/`model_by_path` tolerate a malformed row the shell's own
selector would have let through. Second, the shell's `models.tsv` row reader
never checks `tier`, `cache_type_k`, `cache_type_v`, `flash_attention`, or
`guarded_tool_execution` against a closed vocabulary at all -- those checks
exist only as the standalone `validate-tier`/`validate-cache-type`
subcommands and inline in the tuple, draft-pair, and quarantine ledgers --
so `load_models` does not invent that enforcement either; `ModelRow` carries
those fields as plain `str`.
"""

from __future__ import annotations

import re
from collections.abc import Sequence
from pathlib import Path

from qwen_apu.config.loader import (
    RegistryError,
    default_ledger_path,
    read_ledger,
    require_canonical_int,
    require_columns,
    require_repository_relative_evidence_path,
    resolve_ledger_path,
    sentinel_to_optional_float,
    sentinel_to_optional_int,
    sentinel_to_optional_str,
)
from qwen_apu.config.schema import (
    BACKEND_VALUES,
    CACHE_TYPE_VALUES,
    CTX_CHECKPOINT_ROW_FIELDS,
    DRAFT_PAIR_FIELDS,
    DRAFT_PAIR_SCOPED_FEATURES,
    FEATURE_CLAIM_FIELDS,
    FEATURE_CLAIM_STATUS_VALUES,
    FEATURE_VALUES,
    FLASH_ATTENTION_VALUES,
    MODEL_ARTIFACT_FIELDS,
    MODEL_ROW_FIELDS,
    MODEL_SCOPED_FEATURES,
    PATCH_SERIES_MEMBER_FIELDS,
    PATCH_STAGE_VALUES,
    PROJECTOR_STATE_VALUES,
    Q4K_VARIANT_VALUES,
    QUARANTINE_ROW_FIELDS,
    RUNTIME_MODE_VALUES,
    TIER_VALUES,
    TUPLE_STATUS_VALUES,
    VALIDATED_TUPLE_FIELDS,
    WEB_PROFILE_FIELDS,
    WEB_PROFILE_SCOPED_FEATURES,
    CtxCheckpointRow,
    DraftPair,
    FeatureClaim,
    ModelArtifact,
    ModelRow,
    PatchSeriesMember,
    QuarantineRow,
    ValidatedTuple,
    WebProfile,
)

_ISO_DATE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
_FRACTION = re.compile(r"^(0|1)(\.[0-9]+)?$")
_SOURCE_REPOSITORY = re.compile(r"^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$")
_LOOPBACK_SEARXNG_URL = re.compile(r"^https?://(127\.0\.0\.1|localhost)(:[0-9]+)?/?$")
_CATEGORY = re.compile(r"^[a-z][a-z0-9._-]*$")


def validate_cache_type(value: str) -> bool:
    """Port of remote/model-registry.sh's `validate_cache_type`."""
    return value in CACHE_TYPE_VALUES


def validate_tier(value: str) -> bool:
    """Port of remote/model-registry.sh's `validate_tier`."""
    return value in TIER_VALUES


def validate_q4k_variant(value: str) -> bool:
    """Port of remote/model-registry.sh's `validate_q4k_variant`."""
    return value in Q4K_VARIANT_VALUES


# ---------------------------------------------------------------------------
# remote/models.tsv
# ---------------------------------------------------------------------------


def load_models(path: Path | str | None = None) -> tuple[ModelRow, ...]:
    """Every remote/models.tsv row, validated the way `emit_servable_rows` validates it.

    Refuses a row whose field count differs from the 23-column header and a
    row whose `q4k_variant` falls outside the closed vocabulary, the two
    checks `emit_servable_rows` applies to every row before it answers any
    query.
    """
    resolved = resolve_ledger_path(path, "QWEN_MODEL_REGISTRY", "models")
    table = read_ledger(resolved, key_index=0)
    require_columns(table, MODEL_ROW_FIELDS)
    rows: list[ModelRow] = []
    for line_number, fields in table.rows:
        row_key = f"model row {line_number}"
        q4k_variant = fields[22]
        if q4k_variant not in Q4K_VARIANT_VALUES:
            raise RegistryError(f"{row_key} carries invalid q4k_variant: {q4k_variant}")
        rows.append(
            ModelRow(
                id=fields[0],
                role=fields[1],
                model_file=fields[2],
                fetch_script=fields[3],
                context_default=require_canonical_int(
                    fields[4], field_name="context_default", row_key=row_key
                ),
                context_ceiling=require_canonical_int(
                    fields[5], field_name="context_ceiling", row_key=row_key
                ),
                context_target=require_canonical_int(
                    fields[6], field_name="context_target", row_key=row_key
                ),
                cache_type_k=fields[7],
                cache_type_v=fields[8],
                flash_attention=fields[9],
                projector=fields[10],
                projector_fetch_script=sentinel_to_optional_str(fields[11]),
                decode_tok_s=sentinel_to_optional_float(
                    fields[12], field_name="decode_tok_s", row_key=row_key
                ),
                prefill_tok_s=sentinel_to_optional_float(
                    fields[13], field_name="prefill_tok_s", row_key=row_key
                ),
                quality=fields[14],
                tier=fields[15],
                batch=require_canonical_int(fields[16], field_name="batch", row_key=row_key),
                ubatch=require_canonical_int(fields[17], field_name="ubatch", row_key=row_key),
                validated_filled_depth=sentinel_to_optional_int(
                    fields[18], field_name="validated_filled_depth", row_key=row_key
                ),
                validation_evidence=sentinel_to_optional_str(fields[19]),
                raw_tool_selection=fields[20],
                guarded_tool_execution=fields[21],
                q4k_variant=q4k_variant,
            )
        )
    return tuple(rows)


def model_by_id(model_id: str, path: Path | str | None = None) -> ModelRow:
    """Port of `model-registry.sh id SELECTOR`."""
    for row in load_models(path):
        if row.id == model_id:
            return row
    raise RegistryError(f"no registry row matches id {model_id}")


def model_by_path(model_path: str, path: Path | str | None = None) -> ModelRow:
    """Port of `model-registry.sh path SELECTOR`.

    A row matches when the caller's (typically absolute) path ends with the
    row's own repository-relative `model_file`, the same suffix test the
    shell performs with `substr`. The first matching row in file order wins,
    as it does in the shell's single-pass AWK scan.
    """
    for row in load_models(path):
        if model_path.endswith(row.model_file):
            return row
    raise RegistryError(f"no registry row matches path {model_path}")


# ---------------------------------------------------------------------------
# remote/validated-tuples.tsv
# ---------------------------------------------------------------------------


def load_validated_tuples(
    path: Path | str | None = None, *, models: Sequence[ModelRow] | None = None
) -> tuple[ValidatedTuple, ...]:
    """Port of `validate_tuple_ledger`."""
    resolved = resolve_ledger_path(path, "QWEN_VALIDATED_TUPLES", "validated-tuples")
    known_models = models if models is not None else load_models()
    known_model_ids = {row.id for row in known_models}
    table = read_ledger(resolved, key_index=0)
    require_columns(table, VALIDATED_TUPLE_FIELDS)
    rows: list[ValidatedTuple] = []
    for line_number, fields in table.rows:
        tuple_id = fields[0]
        row_key = tuple_id
        if tuple_id == "":
            raise RegistryError(f"tuple row {line_number} carries an empty tuple_id")
        if tuple_id in known_model_ids:
            # Reproduced verbatim from remote/model-registry.sh, which names
            # this collision after the draft-pair ledger's own id column even
            # inside the tuple ledger's validator.
            raise RegistryError(f"{row_key}: pair_id collides with model registry id")
        model_id = fields[1]
        if model_id not in known_model_ids:
            raise RegistryError(f"{row_key}: model_id {model_id} is absent from the model registry")
        runtime_mode = fields[2]
        if runtime_mode not in RUNTIME_MODE_VALUES:
            raise RegistryError(
                f"{row_key}: runtime_mode {runtime_mode} is not standalone or router-child"
            )
        context = require_canonical_int(fields[3], field_name="context", row_key=row_key)
        batch = require_canonical_int(fields[4], field_name="batch", row_key=row_key)
        ubatch = require_canonical_int(fields[5], field_name="ubatch", row_key=row_key)
        if ubatch > batch:
            raise RegistryError(f"{row_key}: ubatch {ubatch} exceeds batch {batch}")
        cache_k, cache_v = fields[6], fields[7]
        if cache_k not in CACHE_TYPE_VALUES:
            raise RegistryError(f"{row_key}: cache_k {cache_k} is outside the runtime vocabulary")
        if cache_v not in CACHE_TYPE_VALUES:
            raise RegistryError(f"{row_key}: cache_v {cache_v} is outside the runtime vocabulary")
        flash_attention = fields[8]
        if flash_attention not in FLASH_ATTENTION_VALUES:
            raise RegistryError(
                f"{row_key}: flash_attention {flash_attention} is not on, off, or auto"
            )
        threads = require_canonical_int(fields[9], field_name="threads", row_key=row_key)
        parallel = require_canonical_int(fields[10], field_name="parallel", row_key=row_key)
        projector_state = fields[11]
        if projector_state not in PROJECTOR_STATE_VALUES:
            raise RegistryError(
                f"{row_key}: projector_state {projector_state} is not none or loaded"
            )
        backend = fields[12]
        if backend not in BACKEND_VALUES:
            raise RegistryError(f"{row_key}: backend {backend} is not vulkan, cpu, or hip")
        status = fields[13]
        if status not in TUPLE_STATUS_VALUES:
            raise RegistryError(
                f"{row_key}: status {status} is not validated, failed, or unverified"
            )
        evidence_raw = fields[14]
        if status == "validated" and evidence_raw == "-":
            raise RegistryError(f"{row_key}: validated status carries no evidence path")
        measured_at = fields[20]
        if measured_at != "-" and not _ISO_DATE.match(measured_at):
            raise RegistryError(f"{row_key}: measured_at {measured_at} is not an ISO date or -")
        if status == "validated":
            require_repository_relative_evidence_path(
                evidence_raw, field_name="evidence", row_key=row_key
            )
        rows.append(
            ValidatedTuple(
                tuple_id=tuple_id,
                model_id=model_id,
                runtime_mode=runtime_mode,
                context=context,
                batch=batch,
                ubatch=ubatch,
                cache_k=cache_k,
                cache_v=cache_v,
                flash_attention=flash_attention,
                threads=threads,
                parallel=parallel,
                projector_state=projector_state,
                backend=backend,
                status=status,
                evidence=sentinel_to_optional_str(evidence_raw),
                llama_commit=sentinel_to_optional_str(fields[15]),
                runner_sha256=sentinel_to_optional_str(fields[16]),
                kernel=sentinel_to_optional_str(fields[17]),
                mesa=sentinel_to_optional_str(fields[18]),
                amdgpu=sentinel_to_optional_str(fields[19]),
                measured_at=sentinel_to_optional_str(measured_at),
            )
        )
    return tuple(rows)


def tuples_for(
    model_id: str, path: Path | str | None = None, *, models: Sequence[ModelRow] | None = None
) -> tuple[ValidatedTuple, ...]:
    """Port of `model-registry.sh tuples MODEL_ID`.

    The shell prints matching rows and exits 1 with no stderr message when
    none match, which is "not found" rather than a ledger refusal, so this
    returns an empty tuple instead of raising.
    """
    return tuple(
        row for row in load_validated_tuples(path, models=models) if row.model_id == model_id
    )


# ---------------------------------------------------------------------------
# remote/draft-pairs.tsv
# ---------------------------------------------------------------------------


def load_draft_pairs(
    path: Path | str | None = None,
    *,
    models: Sequence[ModelRow] | None = None,
    quarantine: Sequence[QuarantineRow] | None = None,
) -> tuple[DraftPair, ...]:
    """Port of `validate_draft_pair_ledger`."""
    resolved = resolve_ledger_path(path, "QWEN_DRAFT_PAIRS", "draft-pairs")
    known_models = models if models is not None else load_models()
    known_model_ids = {row.id for row in known_models}
    model_context_default = {row.id: row.context_default for row in known_models}
    known_quarantine = quarantine if quarantine is not None else load_quarantine()
    # remote/model-registry.sh's `quarantine-subjects` query, called with no
    # runtime_mode argument, filters nothing on runtime_mode and returns every
    # model-scope subject.
    quarantined_model_ids = {row.subject for row in known_quarantine if row.scope == "model"}

    table = read_ledger(resolved, key_index=0)
    require_columns(table, DRAFT_PAIR_FIELDS)
    rows: list[DraftPair] = []
    for line_number, fields in table.rows:
        pair_id = fields[0]
        row_key = pair_id
        if pair_id == "":
            raise RegistryError(f"draft pair row {line_number} carries an empty pair_id")
        target_model_id, draft_model_id = fields[1], fields[2]
        if target_model_id not in known_model_ids:
            raise RegistryError(
                f"{row_key}: target_model_id {target_model_id} is absent from the model registry"
            )
        if draft_model_id not in known_model_ids:
            raise RegistryError(
                f"{row_key}: draft_model_id {draft_model_id} is absent from the model registry"
            )
        if target_model_id == draft_model_id:
            raise RegistryError(
                f"{row_key}: target and draft name the same checkpoint {target_model_id}"
            )
        if target_model_id in quarantined_model_ids:
            raise RegistryError(
                f"{row_key}: target {target_model_id} is excluded by model quarantine"
            )
        if draft_model_id in quarantined_model_ids:
            raise RegistryError(
                f"{row_key}: draft {draft_model_id} is excluded by model quarantine"
            )
        tier = fields[3]
        if tier not in TIER_VALUES:
            raise RegistryError(f"{row_key}: tier {tier} is outside the vocabulary")
        spec_draft_n_max = require_canonical_int(
            fields[4], field_name="spec_draft_n_max", row_key=row_key
        )
        if spec_draft_n_max > 16:
            raise RegistryError(
                f"{row_key}: spec_draft_n_max {spec_draft_n_max} exceeds "
                "the operational maximum of 16"
            )
        spec_draft_p_min_raw = fields[5]
        if not _FRACTION.match(spec_draft_p_min_raw) or float(spec_draft_p_min_raw) > 1:
            raise RegistryError(
                f"{row_key}: spec_draft_p_min {spec_draft_p_min_raw} is not "
                "a decimal fraction in [0,1]"
            )
        acceptance_floor_raw = fields[6]
        if not _FRACTION.match(acceptance_floor_raw) or float(acceptance_floor_raw) > 1:
            raise RegistryError(
                f"{row_key}: acceptance_floor {acceptance_floor_raw} is not "
                "a decimal fraction in [0,1]"
            )
        draft_context = require_canonical_int(
            fields[7], field_name="draft_context", row_key=row_key
        )
        expected_draft_context = model_context_default.get(target_model_id)
        if expected_draft_context is not None and draft_context != expected_draft_context:
            raise RegistryError(
                f"{row_key}: draft_context {draft_context} differs from target "
                f"context_default {expected_draft_context}"
            )
        draft_cache_type_k, draft_cache_type_v = fields[8], fields[9]
        if draft_cache_type_k not in CACHE_TYPE_VALUES:
            raise RegistryError(
                f"{row_key}: draft_cache_type_k {draft_cache_type_k} is "
                "outside the runtime vocabulary"
            )
        if draft_cache_type_v not in CACHE_TYPE_VALUES:
            raise RegistryError(
                f"{row_key}: draft_cache_type_v {draft_cache_type_v} is "
                "outside the runtime vocabulary"
            )
        validated_evidence_raw = fields[10]
        if validated_evidence_raw == "":
            raise RegistryError(
                f"{row_key}: validated_evidence is empty; write - for an unmeasured pairing"
            )
        if tier == "production" and validated_evidence_raw == "-":
            raise RegistryError(
                f"{row_key}: production pairing requires retained validated_evidence"
            )
        if validated_evidence_raw != "-":
            require_repository_relative_evidence_path(
                validated_evidence_raw, field_name="validated_evidence", row_key=row_key
            )
        notes = fields[11]
        if notes == "" or "," in notes or notes != notes.strip():
            raise RegistryError(
                f"{row_key}: notes is the alias display name and holds no "
                f"comma or edge whitespace: {notes}"
            )
        rows.append(
            DraftPair(
                pair_id=pair_id,
                target_model_id=target_model_id,
                draft_model_id=draft_model_id,
                tier=tier,
                spec_draft_n_max=spec_draft_n_max,
                spec_draft_p_min=float(spec_draft_p_min_raw),
                acceptance_floor=float(acceptance_floor_raw),
                draft_context=draft_context,
                draft_cache_type_k=draft_cache_type_k,
                draft_cache_type_v=draft_cache_type_v,
                validated_evidence=sentinel_to_optional_str(validated_evidence_raw),
                notes=notes,
            )
        )
    return tuple(rows)


def draft_pair(
    pair_id: str,
    path: Path | str | None = None,
    *,
    models: Sequence[ModelRow] | None = None,
    quarantine: Sequence[QuarantineRow] | None = None,
) -> DraftPair:
    """Port of `model-registry.sh draft-pair PAIR_ID`."""
    for row in load_draft_pairs(path, models=models, quarantine=quarantine):
        if row.pair_id == pair_id:
            return row
    raise RegistryError(f"no draft pair matches pair_id {pair_id}")


# ---------------------------------------------------------------------------
# remote/ctx-checkpoints.tsv
# ---------------------------------------------------------------------------


def load_ctx_checkpoints(
    path: Path | str | None = None, *, models: Sequence[ModelRow] | None = None
) -> tuple[CtxCheckpointRow, ...]:
    """Port of `validate_ctx_checkpoint_ledger`."""
    resolved = resolve_ledger_path(path, "QWEN_CTX_CHECKPOINT_LEDGER", "ctx-checkpoints")
    known_models = models if models is not None else load_models()
    known_model_ids = {row.id for row in known_models}
    table = read_ledger(resolved, key_index=0)
    require_columns(table, CTX_CHECKPOINT_ROW_FIELDS)
    rows: list[CtxCheckpointRow] = []
    for line_number, fields in table.rows:
        model_id = fields[0]
        row_key = model_id
        if model_id == "":
            raise RegistryError(f"context checkpoint row {line_number} carries an empty model_id")
        if model_id not in known_model_ids:
            raise RegistryError(f"{row_key}: model_id is absent from the model registry")
        ctx_checkpoints = require_canonical_int(
            fields[1], field_name="ctx_checkpoints", row_key=row_key, positive=False
        )
        evidence_raw = fields[2]
        if evidence_raw == "":
            raise RegistryError(f"{row_key}: evidence is empty; write - for an unmeasured zero")
        if evidence_raw == "-" and ctx_checkpoints != 0:
            raise RegistryError(f"{row_key}: a count above 0 requires retained evidence")
        if evidence_raw != "-":
            require_repository_relative_evidence_path(
                evidence_raw, field_name="evidence", row_key=row_key
            )
        rows.append(
            CtxCheckpointRow(
                model_id=model_id,
                ctx_checkpoints=ctx_checkpoints,
                evidence=sentinel_to_optional_str(evidence_raw),
            )
        )
    return tuple(rows)


# ---------------------------------------------------------------------------
# remote/quarantine.tsv
# ---------------------------------------------------------------------------


def load_quarantine(path: Path | str | None = None) -> tuple[QuarantineRow, ...]:
    """Port of the quarantine row validator embedded in `emit_servable_rows`.

    `failure_class` carries the closed vocabulary remote/quarantine.tsv's own
    header comment documents, but the shell's row validator never checks it
    against that vocabulary, so this loader does not invent that enforcement:
    `QuarantineRow.failure_class` types as `str`.
    """
    resolved = resolve_ledger_path(path, "QWEN_QUARANTINE_REGISTRY", "quarantine")
    table = read_ledger(resolved, key_index=0)
    require_columns(table, QUARANTINE_ROW_FIELDS)
    rows: list[QuarantineRow] = []
    for line_number, fields in table.rows:
        row_id, scope, subject = fields[0], fields[1], fields[2]
        row_key = f"quarantine row {line_number}"
        if row_id == "" or subject == "":
            raise RegistryError(f"{row_key} requires non-empty id and subject")
        if scope not in {"model", "profile"}:
            raise RegistryError(f"{row_key} carries invalid scope {scope}")
        runtime_mode = fields[13]
        if runtime_mode not in {"any", "router-child", "standalone"}:
            raise RegistryError(f"{row_key} carries invalid runtime mode {runtime_mode}")
        geometry_fields = fields[4:10]
        if scope == "model":
            for index, value in enumerate(geometry_fields, start=5):
                if value != "-":
                    raise RegistryError(
                        f"model quarantine {row_key} carries tuple field {index}: {value}"
                    )
            depth = batch = ubatch = None
            cache_type_k = cache_type_v = flash_attention = None
        else:
            depth_raw, batch_raw, ubatch_raw = fields[4], fields[5], fields[6]
            if (
                not re.fullmatch(r"[1-9][0-9]*", depth_raw)
                or not re.fullmatch(r"[1-9][0-9]*", batch_raw)
                or not re.fullmatch(r"[1-9][0-9]*", ubatch_raw)
            ):
                raise RegistryError(
                    f"profile quarantine {row_key} carries invalid depth or geometry"
                )
            depth, batch, ubatch = int(depth_raw), int(batch_raw), int(ubatch_raw)
            if ubatch > batch:
                raise RegistryError(f"profile quarantine {row_key} carries ubatch above batch")
            cache_type_k, cache_type_v = fields[7], fields[8]
            if cache_type_k not in CACHE_TYPE_VALUES or cache_type_v not in CACHE_TYPE_VALUES:
                raise RegistryError(f"profile quarantine {row_key} carries invalid cache type")
            flash_attention = fields[9]
            if flash_attention not in FLASH_ATTENTION_VALUES:
                raise RegistryError(f"profile quarantine {row_key} carries invalid flash attention")
        rows.append(
            QuarantineRow(
                id=row_id,
                scope=scope,
                subject=subject,
                failure_class=fields[3],
                depth=depth,
                batch=batch,
                ubatch=ubatch,
                cache_type_k=cache_type_k,
                cache_type_v=cache_type_v,
                flash_attention=flash_attention,
                first_evidence=fields[10],
                latest_evidence=fields[11],
                reason_record=fields[12],
                runtime_mode=runtime_mode,
            )
        )
    return tuple(rows)


# ---------------------------------------------------------------------------
# remote/model-artifacts.tsv
# ---------------------------------------------------------------------------


def load_model_artifacts(path: Path | str | None = None) -> tuple[ModelArtifact, ...]:
    """Port of remote/model-artifact-identity.sh's row validation, over the whole ledger."""
    resolved = resolve_ledger_path(path, "QWEN_MODEL_ARTIFACTS", "model-artifacts")
    table = read_ledger(resolved, key_index=0)
    require_columns(table, MODEL_ARTIFACT_FIELDS)
    rows: list[ModelArtifact] = []
    for line_number, fields in table.rows:
        model_id, model_file = fields[0], fields[1]
        row_key = f"model artifact identity ledger line {line_number}"
        if model_id == "" or model_file == "":
            raise RegistryError(f"{row_key} is malformed")
        if (
            model_file.startswith("/")
            or re.search(r"(^|/)\.\.($|/)", model_file)
            or "//" in model_file
        ):
            raise RegistryError(f"{row_key} is malformed")
        expected_bytes_raw = fields[2]
        if not re.fullmatch(r"[1-9][0-9]*", expected_bytes_raw):
            raise RegistryError(f"{row_key} is malformed")
        expected_sha256 = fields[3]
        if len(expected_sha256) != 64 or re.search(r"[^0-9a-f]", expected_sha256):
            raise RegistryError(f"{row_key} is malformed")
        source_repository = fields[4]
        if not _SOURCE_REPOSITORY.match(source_repository):
            raise RegistryError(f"{row_key} is malformed")
        source_revision = fields[5]
        if len(source_revision) not in {40, 64} or re.search(r"[^0-9a-f]", source_revision):
            raise RegistryError(f"{row_key} is malformed")
        rows.append(
            ModelArtifact(
                model_id=model_id,
                model_file=model_file,
                expected_bytes=int(expected_bytes_raw),
                expected_sha256=expected_sha256,
                source_repository=source_repository,
                source_revision=source_revision,
            )
        )
    return tuple(rows)


def model_artifact(model_id: str, path: Path | str | None = None) -> ModelArtifact:
    """Port of `model-artifact-identity.sh MODEL_ID`."""
    for row in load_model_artifacts(path):
        if row.model_id == model_id:
            return row
    raise RegistryError(f"model artifact identity requires one row for {model_id}, found 0")


# ---------------------------------------------------------------------------
# remote/llama-patch-series.tsv
# ---------------------------------------------------------------------------


def load_patch_series(path: Path | str | None = None) -> tuple[PatchSeriesMember, ...]:
    """Every remote/llama-patch-series.tsv row, production members before candidate members.

    remote/verify-llama-patch-series.sh reads the production and candidate
    stages as two separate `awk` selections rather than asserting an order
    over the file, but the ledger's own header comment states the invariant
    the two-stage reader depends on: "A `candidate` member ... applies after
    every production member." This loader enforces that invariant directly,
    refusing a production row once a candidate row has appeared, so a ledger
    edit that violates the documented order fails here rather than silently
    reordering under `verify-llama-patch-series.sh`'s per-stage filter.

    remote/llama-patch-series.tsv's own path has no environment-variable
    override in the shell tooling that reads it (unlike every other ledger
    this package reads: build-llama-preset.sh and
    verify-llama-patch-series.sh both hardcode `$script_directory/
    llama-patch-series.tsv`), so this loader honors none either -- an
    explicit `path` argument or the repository-relative default is the whole
    rule, with no environment variable in between.
    """
    resolved = Path(path) if path is not None else default_ledger_path("llama-patch-series")
    table = read_ledger(resolved, key_index=1)
    require_columns(table, PATCH_SERIES_MEMBER_FIELDS)
    rows: list[PatchSeriesMember] = []
    seen_candidate = False
    for line_number, fields in table.rows:
        stage, patch = fields[0], fields[1]
        row_key = f"patch series row {line_number}"
        if stage not in PATCH_STAGE_VALUES:
            raise RegistryError(f"{row_key} carries invalid stage: {stage}")
        if patch == "":
            raise RegistryError(f"{row_key} carries an empty patch name")
        if stage == "candidate":
            seen_candidate = True
        elif seen_candidate:
            raise RegistryError(f"{row_key}: production member {patch} follows a candidate member")
        rows.append(PatchSeriesMember(stage=stage, patch=patch))
    # The refusal above already guarantees the surviving rows read production
    # block then candidate block in file order; this reassembly stands as a
    # second, independent guarantee of the same order, so a future relaxation
    # of that refusal does not silently change what this function returns.
    production = tuple(member for member in rows if member.stage == "production")
    candidate = tuple(member for member in rows if member.stage == "candidate")
    return production + candidate


# ---------------------------------------------------------------------------
# remote/web-profiles.tsv
# ---------------------------------------------------------------------------


def load_web_profiles(
    path: Path | str | None = None, *, models: Sequence[ModelRow] | None = None
) -> tuple[WebProfile, ...]:
    """Port of the per-row rules remote/web-preset-lib.sh applies to every profile row.

    The registry cross-checks `require_ledger_matches_registry` applies
    (context against `context_ceiling`, `vision_allowed` against
    `projector`, `tool_selection` against `raw_tool_selection`) are left to a
    caller building a preset, since they compare a `WebProfile` against a
    `ModelRow` the way `web-preset-lib.sh` does at generation time rather
    than at ledger-read time; this loader validates what is a property of one
    row read on its own, the discipline the other loaders in this module
    apply.
    """
    resolved = resolve_ledger_path(path, "QWEN_WEB_PROFILES", "web-profiles")
    known_models = models if models is not None else load_models()
    known_model_ids = {row.id for row in known_models}
    table = read_ledger(resolved, key_index=0)
    require_columns(table, WEB_PROFILE_FIELDS)
    rows: list[WebProfile] = []
    for line_number, fields in table.rows:
        profile_id = fields[0]
        row_key = profile_id
        if profile_id == "":
            raise RegistryError(f"web profile row {line_number} carries an empty profile_id")
        model_id = fields[1]
        if model_id not in known_model_ids:
            raise RegistryError(f"{row_key}: model_id {model_id} is absent from the model registry")
        web_mode = fields[2]
        if web_mode not in {"validator-gated", "ui-mediated"}:
            raise RegistryError(f"{row_key}: web_mode {web_mode} is outside the vocabulary")
        context = require_canonical_int(fields[3], field_name="context", row_key=row_key)
        validated_filled_depth = sentinel_to_optional_int(
            fields[4], field_name="validated_filled_depth", row_key=row_key
        )
        max_results = require_canonical_int(fields[5], field_name="max_results", row_key=row_key)
        max_fetches = require_canonical_int(fields[6], field_name="max_fetches", row_key=row_key)
        max_chars_per_fetch = require_canonical_int(
            fields[7], field_name="max_chars_per_fetch", row_key=row_key
        )
        multi_source = fields[8]
        if multi_source not in {"yes", "no"}:
            raise RegistryError(f"{row_key}: multi_source {multi_source} is outside the vocabulary")
        if max_fetches > 1 and multi_source != "yes":
            raise RegistryError(
                f"{row_key}: multi_source {multi_source} with max_fetches {max_fetches} "
                "above one fetch"
            )
        if max_fetches <= 1 and multi_source != "no":
            raise RegistryError(
                f"{row_key}: multi_source {multi_source} with max_fetches {max_fetches} "
                "at one fetch or fewer"
            )
        vision_allowed = fields[9]
        if vision_allowed not in {"yes", "no"}:
            raise RegistryError(
                f"{row_key}: vision_allowed {vision_allowed} is outside the vocabulary"
            )
        tool_selection = fields[10]
        execution_policy = fields[11]
        if execution_policy not in {"refused", "validator-gated"}:
            raise RegistryError(
                f"{row_key}: execution_policy {execution_policy} is outside the vocabulary"
            )
        provider = fields[12]
        if provider not in {"searxng", "exa", "fake"}:
            raise RegistryError(f"{row_key}: provider {provider} is outside the vocabulary")
        primary_raw, fallback_raw, minimum_raw, url_raw = (
            fields[13],
            fields[14],
            fields[15],
            fields[16],
        )
        if provider != "searxng":
            for field_name, value in (
                ("primary_category", primary_raw),
                ("fallback_category", fallback_raw),
                ("minimum_results", minimum_raw),
                ("searxng_url", url_raw),
            ):
                if value != "-":
                    raise RegistryError(
                        f"{row_key}: {field_name} carries a search policy under provider "
                        f"{provider}, which reads none"
                    )
            minimum_results = None
        else:
            if primary_raw == "-" or not _CATEGORY.match(primary_raw) or len(primary_raw) > 64:
                raise RegistryError(f"{row_key}: primary_category {primary_raw} is invalid")
            if fallback_raw != "-" and (
                not _CATEGORY.match(fallback_raw) or len(fallback_raw) > 64
            ):
                raise RegistryError(f"{row_key}: fallback_category {fallback_raw} is invalid")
            minimum_results = require_canonical_int(
                minimum_raw, field_name="minimum_results", row_key=row_key, positive=False
            )
            if minimum_results > max_results:
                raise RegistryError(
                    f"{row_key}: minimum_results {minimum_results} above max_results {max_results}"
                )
            if not _LOOPBACK_SEARXNG_URL.match(url_raw):
                raise RegistryError(f"{row_key}: searxng_url {url_raw} is not a loopback URL")
        rows.append(
            WebProfile(
                profile_id=profile_id,
                model_id=model_id,
                web_mode=web_mode,
                context=context,
                validated_filled_depth=validated_filled_depth,
                max_results=max_results,
                max_fetches=max_fetches,
                max_chars_per_fetch=max_chars_per_fetch,
                multi_source=multi_source,
                vision_allowed=vision_allowed,
                tool_selection=tool_selection,
                execution_policy=execution_policy,
                provider=provider,
                primary_category=sentinel_to_optional_str(primary_raw),
                fallback_category=sentinel_to_optional_str(fallback_raw),
                minimum_results=minimum_results,
                searxng_url=sentinel_to_optional_str(url_raw),
            )
        )
    return tuple(rows)


# ---------------------------------------------------------------------------
# remote/feature-claims.tsv
# ---------------------------------------------------------------------------

_CONTROL_OR_ESCAPE = re.compile(r'["\\]|[\x01-\x1f\x7f]')


def load_feature_claims(
    path: Path | str | None = None,
    *,
    models: Sequence[ModelRow] | None = None,
    draft_pairs: Sequence[DraftPair] | None = None,
    web_profiles: Sequence[WebProfile] | None = None,
) -> tuple[FeatureClaim, ...]:
    """Port of the claim validator inline in remote/build-feature-roster.sh.

    remote/image-profiles.tsv is outside this package's authority list, so a
    claim whose feature is `image-generation` or `image-review` is validated
    on every rule but the subject's existence in that ledger; a caller
    holding an image profile ledger of its own re-applies that one check.
    """
    resolved = resolve_ledger_path(path, "QWEN_FEATURE_CLAIMS", "feature-claims")
    known_models = models if models is not None else load_models()
    model_tier = {row.id: row.tier for row in known_models}
    known_pair_ids = {
        row.pair_id
        for row in (
            draft_pairs if draft_pairs is not None else load_draft_pairs(models=known_models)
        )
    }
    known_web_ids = {
        row.profile_id
        for row in (
            web_profiles if web_profiles is not None else load_web_profiles(models=known_models)
        )
    }

    def key_fn(fields: tuple[str, ...]) -> str:
        return f"{fields[0]}\x00{fields[1]}"

    table = read_ledger(resolved, key_fn=key_fn)
    require_columns(table, FEATURE_CLAIM_FIELDS)
    rows: list[FeatureClaim] = []
    for line_number, fields in table.rows:
        subject_id, feature, status, evidence_raw, note = fields
        row_key = f"{subject_id}/{feature}"
        if subject_id == "" or feature == "" or status == "" or evidence_raw == "" or note == "":
            raise RegistryError(f"feature claim row {line_number} carries an empty field")
        for value in fields:
            if _CONTROL_OR_ESCAPE.search(value):
                raise RegistryError(
                    f"{row_key}: a field carries a quotation mark, a backslash, or a "
                    "control character"
                )
        if feature not in FEATURE_VALUES:
            raise RegistryError(f"{row_key}: feature {feature} is outside the vocabulary")
        if status not in FEATURE_CLAIM_STATUS_VALUES:
            raise RegistryError(f"{row_key}: status {status} is outside the vocabulary")
        if feature in MODEL_SCOPED_FEATURES:
            if subject_id not in model_tier:
                raise RegistryError(f"{row_key}: subject is absent from the model registry")
        elif feature in DRAFT_PAIR_SCOPED_FEATURES:
            if subject_id not in known_pair_ids:
                raise RegistryError(f"{row_key}: subject is absent from the draft pair ledger")
        elif feature in WEB_PROFILE_SCOPED_FEATURES:
            if subject_id not in known_web_ids:
                raise RegistryError(f"{row_key}: subject is absent from the web profile ledger")
        # A claim in IMAGE_PROFILE_SCOPED_FEATURES falls through with no
        # existence check: remote/image-profiles.tsv sits outside this
        # package's authority list (see this function's docstring), so no
        # `elif feature in IMAGE_PROFILE_SCOPED_FEATURES` branch exists here.
        # A caller holding that ledger re-applies the check this branch would
        # otherwise make.
        if evidence_raw != "-":
            if not evidence_raw.startswith("evidence/") or re.search(
                r"(^|/)\.\.(/|$)", evidence_raw
            ):
                raise RegistryError(
                    f"{row_key}: evidence is not a repository-relative path under evidence/: "
                    f"{evidence_raw}"
                )
        elif status in {"production", "candidate", "unstable"}:
            raise RegistryError(f"{row_key}: status {status} requires retained evidence")
        if (
            feature in MODEL_SCOPED_FEATURES
            and status == "production"
            and model_tier.get(subject_id) == "quarantine"
        ):
            raise RegistryError(f"{row_key}: production claim over a quarantined checkpoint")
        rows.append(
            FeatureClaim(
                subject_id=subject_id,
                feature=feature,
                status=status,
                evidence=sentinel_to_optional_str(evidence_raw),
                note=note,
            )
        )
    return tuple(rows)


# ---------------------------------------------------------------------------
# remote/check-validated-tuples.sh (models.tsv <-> validated-tuples.tsv arm only)
# ---------------------------------------------------------------------------


def check_validated_filled_depth_tuples(
    models: Sequence[ModelRow] | None = None,
    tuples: Sequence[ValidatedTuple] | None = None,
) -> None:
    """Port of the models.tsv <-> validated-tuples.tsv arm of check-validated-tuples.sh.

    remote/check-validated-tuples.sh also cross-checks
    remote/image-profiles.tsv's `review_model` claim against a router-child,
    projector-loaded validated row; that ledger sits outside this package's
    authority list, so this function ports the models.tsv arm alone -- every
    model row that claims a numeric `validated_filled_depth` must own a
    `validated` row in the tuple ledger naming the same model, depth,
    geometry, cache policy, and projector state.
    """
    known_models = models if models is not None else load_models()
    known_tuples = tuples if tuples is not None else load_validated_tuples(models=known_models)
    validated_keys = {
        (
            row.model_id,
            row.context,
            row.batch,
            row.ubatch,
            row.cache_k,
            row.cache_v,
            row.flash_attention,
            row.projector_state,
        )
        for row in known_tuples
        if row.status == "validated"
    }
    gaps: list[str] = []
    for row in known_models:
        if row.validated_filled_depth is None:
            continue
        expected_projector_state = "loaded" if row.projector == "required" else "none"
        key = (
            row.id,
            row.validated_filled_depth,
            row.batch,
            row.ubatch,
            row.cache_type_k,
            row.cache_type_v,
            row.flash_attention,
            expected_projector_state,
        )
        if key not in validated_keys:
            gaps.append(
                f"{row.id}: models.tsv claims validated_filled_depth "
                f"{row.validated_filled_depth} at batch {row.batch}, ubatch {row.ubatch}, "
                f"cache {row.cache_type_k}/{row.cache_type_v}, flash attention "
                f"{row.flash_attention}, projector state {expected_projector_state}, and no "
                "validated row in validated-tuples.tsv matches"
            )
    if gaps:
        raise RegistryError("\n".join(gaps))
