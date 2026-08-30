#!/bin/sh
set -eu

# Generate the router preset file and the tier directories from the registry.
#
# llama-server in router mode reads an INI whose sections name models and whose
# keys are LLAMA_ARG_* option names. It builds a base preset from its own argv,
# strips the SSL, API key, and models-* keys from it, and cascades the rest onto
# every child it spawns. The guarded argv that qwen-capacity-policy.sh already
# builds therefore reaches each child unchanged, and this file carries only what
# differs per checkpoint: the weights, the projector, the admitted depth, the
# cache triple, and the labels the picker shows.
#
# qwen-capacity-policy.sh refuses ambient LLAMA_ARG_* precisely so the caller's
# environment cannot override the computed argv. An INI the policy generates is
# that computation's output rather than ambient input, so the refusal stands.
#
# The tier field decides both the directory a checkpoint is linked into and the
# tag the picker groups it by. Only production and candidate reach the preset
# file. A row tiered archive or rejected is linked nowhere and named in no
# section, which removes it from the picker while leaving the weights on disk
# and the fetch script that verifies them in the tree. A row tiered quarantine
# is linked into a quarantine directory beside its reason record and reaches the
# preset file only under QWEN_ROUTER_INCLUDE_QUARANTINE=1, which the appliance
# launch never sets.
#
# A profile quarantine removes one tuple rather than a checkpoint, so the preset
# this script emits carries LLAMA_ARG_BATCH and LLAMA_ARG_UBATCH from
# the registry rather than letting them arrive by cascade. That makes each
# section state the full submission geometry it serves at, so a quarantined
# tuple is checkable against one file instead of against a file plus the argv
# that spawned the router.
#
# remote/draft-pairs.tsv adds one section per pairing beside the per-checkpoint
# sections. A pairing is a second serving shape of one target rather than a new
# checkpoint, so its section names the pair_id, carries the target row's whole
# six-key tuple, and adds the draft keys the pinned common/arg.cpp registers.
# The tier field decides emission there the same way it decides it here.
#
# Directories are linked rather than moved. A checkpoint's projector must sit in
# the checkpoint's own directory for remote/select-projector.sh to pair it, and
# linking the directory preserves that pairing while a file move would break a
# reader holding the model open.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [OUTPUT_INI]\n' "$0" >&2
    printf 'model root comes from QWEN_MODEL_ROOT, default $HOME/models\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
model_root=${QWEN_MODEL_ROOT:-"${HOME:?}/models"}
reason_source=${QWEN_QUARANTINE_REASONS:-$script_directory/../evidence/quarantine}
output_ini=${1:-"${HOME:?}/qwen-webui-state/router-presets.ini"}
include_quarantine=${QWEN_ROUTER_INCLUDE_QUARANTINE:-0}
case $include_quarantine in
    0 | 1) ;;
    *)
        printf 'QWEN_ROUTER_INCLUDE_QUARANTINE must be 0 or 1: %s\n' \
            "$include_quarantine" >&2
        exit 2
        ;;
esac
# The picker offers every servable row and the operator prefers one of them. The
# tag names that preference; llama-server has no default-model option, so this
# labels the section rather than preselecting it.
default_model_id=${QWEN_DEFAULT_MODEL_ID:-qwen38-2b-distill}

if [ ! -r "$registry" ]; then
    printf 'model registry is unreadable: %s\n' "$registry" >&2
    exit 1
fi

# Validate every authority before changing tier links or the last known-good
# preset. In particular, a malformed draft-pair ledger must leave both
# generated surfaces untouched rather than producing an ordinary-model-only
# preset that looks complete.
quarantine_rows=$("$script_directory/model-registry.sh" quarantine-rows router-child)
draft_pair_rows=$("$script_directory/model-registry.sh" draft-pairs)
# The context checkpoint count is per row and every section carries it, since
# common_preset::merge would push one router argv value onto every child. The
# ledger identity is retained beside the rows and compared again before the file
# lands, because qwen-capacity-policy.sh rejoins every persisted section to the
# ledger it reads at launch: an edit during generation would otherwise replace
# the last known-good preset with counts the launch refuses.
# One copy is the whole run's ledger: the digest names the copy's bytes and the
# rows are read from the same copy, so the emitted counts and the recorded
# identity describe one state by construction. Two live reads of the source
# cannot state that, since a file that changed and changed back between them
# answers both reads consistently while the query in the middle returns the
# state neither digest saw. The comparison before the rename then measures the
# source against that copy, and a source standing where it stood is what admits
# the preset the launch rejoins to it.
ctx_checkpoint_ledger=${QWEN_CTX_CHECKPOINT_LEDGER:-$script_directory/ctx-checkpoints.tsv}
ctx_checkpoint_snapshot=$(mktemp "${TMPDIR:-/tmp}/.ctx-checkpoints.XXXXXX")
cleanup_ctx_checkpoint_snapshot() {
    rm -f -- "$ctx_checkpoint_snapshot"
}
trap 'cleanup_ctx_checkpoint_snapshot' EXIT HUP INT TERM
cp -- "$ctx_checkpoint_ledger" "$ctx_checkpoint_snapshot"
ctx_checkpoint_ledger_identity=$(sha256sum -- "$ctx_checkpoint_snapshot")
ctx_checkpoint_ledger_sha256=${ctx_checkpoint_ledger_identity%% *}
ctx_checkpoint_rows=$(QWEN_CTX_CHECKPOINT_LEDGER=$ctx_checkpoint_snapshot \
    "$script_directory/model-registry.sh" ctx-checkpoints)
ledger_ctx_checkpoints() {
    printf '%s\n' "$ctx_checkpoint_rows" | awk -F'\t' -v id="$1" '
        $1 == id { count = $2; matched = 1 }
        END { print matched ? count : 0 }
    '
}

output_parent=$(dirname -- "$output_ini")
mkdir -p "$output_parent"
output_staging=$(mktemp "$output_parent/.router-presets.XXXXXX")
cleanup_output_staging() {
    cleanup_ctx_checkpoint_snapshot
    rm -f -- "$output_staging"
}
trap 'cleanup_output_staging' EXIT HUP INT TERM
production_directory=$model_root/production
candidate_directory=$model_root/candidates
quarantine_directory=$model_root/quarantine
reason_directory=$model_root/quarantine-reasons
mkdir -p "$production_directory" "$candidate_directory" \
    "$quarantine_directory" "$reason_directory"

# A stale link outlives the row that created it, so the tier directories are
# emptied of links before they are rebuilt. A real directory found where a link
# belongs is refused rather than skipped: reconciliation would leave the
# checkpoint inside it in a tier no row claims, and a quarantined model sitting
# in a real production/ directory is exactly the state the tiers exist to
# prevent.
for tier_directory in "$production_directory" "$candidate_directory" \
    "$quarantine_directory"; do
    for existing in "$tier_directory"/*; do
        [ -e "$existing" ] || [ -L "$existing" ] || continue
        if [ -L "$existing" ]; then
            rm -f "$existing"
            continue
        fi
        printf 'tier directory holds a real entry where a symlink belongs: %s\n' \
            "$existing" >&2
        printf 'move it out of the tier tree; reconciliation refuses to touch it\n' >&2
        exit 1
    done
done
for existing in "$reason_directory"/*; do
    [ -f "$existing" ] || continue
    rm -f "$existing"
done

emitted=0
skipped_unlisted=0
skipped_absent=0
quarantined=0
deploy_quarantine_reason() {
    quarantine_reason_id=$1
    if [ ! -f "$reason_source/$quarantine_reason_id.md" ]; then
        printf 'quarantine %s carries no reason record at %s\n' \
            "$quarantine_reason_id" "$reason_source/$quarantine_reason_id.md" >&2
        return 1
    fi
    cp -- "$reason_source/$quarantine_reason_id.md" \
        "$reason_directory/$quarantine_reason_id.md"
}

{
    printf '# Generated by remote/build-router-presets.sh from the model registry.\n'
    printf '# Edit remote/models.tsv and regenerate; edits here are overwritten.\n'
    printf '# qwen_router_include_quarantine=%s\n' "$include_quarantine"
    printf '\n'
} >"$output_staging"

while IFS='	' read -r id role model_file _fetch_script context_default \
    _context_ceiling _context_target cache_type_k cache_type_v flash_attention \
    projector _projector_fetch_script _decode_tok_s _prefill_tok_s _quality tier batch ubatch \
    _validated_filled_depth _validation_evidence; do
    case $id in
        '#'* | '') continue ;;
    esac
    [ -n "${tier:-}" ] || continue

    if ! "$script_directory/model-registry.sh" validate-tier "$tier"; then
        printf 'row %s carries tier %s, which is outside the vocabulary\n' \
            "$id" "$tier" >&2
        exit 1
    fi

    # Archive and rejected rows stay outside every preset even when a retained
    # model-scope quarantine record also names them. The research override
    # exposes quarantined serving candidates; it never reverses archival.
    case $tier in
        archive | rejected)
            skipped_unlisted=$((skipped_unlisted + 1))
            continue
            ;;
    esac

    model_quarantine_row=$(printf '%s\n' "$quarantine_rows" |
        awk -F'\t' -v subject="$id" '$2 == "model" && $3 == subject { print; exit }')
    profile_quarantine_row=$(printf '%s\n' "$quarantine_rows" |
        awk -F'\t' -v subject="$id" -v depth="$context_default" \
            -v row_batch="$batch" -v row_ubatch="$ubatch" \
            -v cache_k="$cache_type_k" -v cache_v="$cache_type_v" \
            -v flash="$flash_attention" '
            $2 == "profile" && $3 == subject && $5 == depth &&
            $6 == row_batch && $7 == row_ubatch && $8 == cache_k &&
            $9 == cache_v && $10 == flash { print; exit }')

    if [ "$tier" = quarantine ] && [ -z "$model_quarantine_row" ]; then
        printf 'row %s is tiered quarantine without a router-child quarantine record\n' \
            "$id" >&2
        exit 1
    fi

    effective_tier=$tier
    preset_tier=$tier
    quarantine_row=''
    if [ -n "$model_quarantine_row" ]; then
        effective_tier=quarantine
        preset_tier=quarantine
        quarantine_row=$model_quarantine_row
    elif [ -n "$profile_quarantine_row" ]; then
        preset_tier=quarantine
        quarantine_row=$profile_quarantine_row
    fi

    model_path=$model_root/$model_file
    if [ ! -f "$model_path" ]; then
        printf 'preset_skipped id=%s reason=weights_absent path=%s\n' \
            "$id" "$model_path" >&2
        skipped_absent=$((skipped_absent + 1))
        continue
    fi

    case $effective_tier in
        production) tier_directory=$production_directory ;;
        quarantine) tier_directory=$quarantine_directory ;;
        *) tier_directory=$candidate_directory ;;
    esac
    model_directory=$(dirname -- "$model_path")
    ln -sfn "$model_directory" "$tier_directory/$(basename -- "$model_directory")"

    # The quarantine registry is the exclusion authority. A model-scope row
    # overrides a stale production or candidate tier, while a profile-scope row
    # removes only the exact section tuple. The research override exposes either
    # on a preset marked for loopback enforcement by qwen-capacity-policy.sh.
    if [ -n "$quarantine_row" ]; then
        quarantined=$((quarantined + 1))
        quarantine_reason_id=$(printf '%s\n' "$quarantine_row" | awk -F'\t' '{ print $1 }')
        deploy_quarantine_reason "$quarantine_reason_id"
        if [ "$include_quarantine" != 1 ]; then
            continue
        fi
        printf 'quarantine_exposed id=%s reason=%s\n' \
            "$id" "$reason_directory/$quarantine_reason_id.md" >&2
    fi

    {
        printf '[%s]\n' "$id"
        printf 'LLAMA_ARG_MODEL = %s\n' "$model_path"
        printf 'LLAMA_ARG_ALIAS = %s\n' "$id"
        if [ "$id" = "$default_model_id" ] &&
            [ "$preset_tier" != quarantine ]; then
            printf 'LLAMA_ARG_TAGS = %s,%s,default\n' "$preset_tier" "$role"
        else
            printf 'LLAMA_ARG_TAGS = %s,%s\n' "$preset_tier" "$role"
        fi
        printf 'LLAMA_ARG_CTX_SIZE = %s\n' "$context_default"
        printf 'LLAMA_ARG_CACHE_TYPE_K = %s\n' "$cache_type_k"
        printf 'LLAMA_ARG_CACHE_TYPE_V = %s\n' "$cache_type_v"
        printf 'LLAMA_ARG_FLASH_ATTN = %s\n' "$flash_attention"
        printf 'LLAMA_ARG_BATCH = %s\n' "$batch"
        printf 'LLAMA_ARG_UBATCH = %s\n' "$ubatch"
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = %s\n' "$(ledger_ctx_checkpoints "$id")"
    } >>"$output_staging"

    if [ "$projector" = required ]; then
        projector_path=$("$script_directory/select-projector.sh" "$model_path" \
            2>/dev/null) || projector_path=''
        if [ -n "$projector_path" ]; then
            printf 'LLAMA_ARG_MMPROJ = %s\n' "$projector_path" >>"$output_staging"
        else
            printf 'preset_warning id=%s reason=projector_unresolved\n' "$id" >&2
        fi
    fi
    printf '\n' >>"$output_staging"
    emitted=$((emitted + 1))
done <"$registry"

# A draft pairing is a second serving shape of one target checkpoint, so it
# reaches the picker as its own section rather than by changing the target's.
# The section carries the target row's whole six-key tuple, because
# server-models.cpp cascades the router argv over every section and an absent
# key falls through to the llama.cpp defaults of batch 2048 and ubatch 512.
#
# The draft keys are the names common/arg.cpp registers at f280b269.
# `--spec-draft-model`, `--spec-type`, `--spec-draft-n-max`,
# `--spec-draft-p-min`, `--spec-draft-type-k`, and `--spec-draft-type-v` each
# carry a set_env, so those six sections keys are LLAMA_ARG_*; draft layers
# breaks the pattern as LLAMA_ARG_N_GPU_LAYERS_DRAFT. `--spec-draft-device` and
# `--spec-draft-override-tensor` carry no set_env at all, and
# common/preset.cpp's get_map_key_opt indexes each option by its dash-stripped
# argument names beside its env names, so the INI reaches them as
# `spec-draft-device` and `spec-draft-override-tensor`.
#
# Placement is explicit on both because common_base_params_to_speculative
# overwrites result.devices, result.n_gpu_layers, and
# result.tensor_buft_overrides with the draft's own values whenever a draft path
# is set. The router argv's `--device Vulkan0`, `--n-gpu-layers all`, and
# `--override-tensor .*=Vulkan0` therefore reach the target and leave the draft
# on the default automatic placement unless the section states it.
#
# The draft context takes no key: common/speculative.cpp assigns
# `cparams.n_ctx = llama_n_ctx(ctx_tgt)` before the draft model loads, so the
# ledger's draft_context records the derived depth and the section states the
# target's.
pairs_emitted=0
pairs_unlisted=0
pairs_absent=0
pairs_quarantined=0
while IFS='	' read -r pair_id target_model_id draft_model_id pair_tier \
    spec_draft_n_max spec_draft_p_min _draft_context draft_cache_type_k \
    draft_cache_type_v _validated_evidence pair_notes; do
    [ -n "${pair_id:-}" ] || continue

    case $pair_tier in
        production | candidate) ;;
        *)
            pairs_unlisted=$((pairs_unlisted + 1))
            continue
            ;;
    esac

    target_row=$("$script_directory/model-registry.sh" id "$target_model_id")
    target_model_file=$(printf '%s\n' "$target_row" | sed -n 's/^model_file=//p')
    target_context=$(printf '%s\n' "$target_row" | sed -n 's/^context_default=//p')
    target_cache_k=$(printf '%s\n' "$target_row" | sed -n 's/^cache_type_k=//p')
    target_cache_v=$(printf '%s\n' "$target_row" | sed -n 's/^cache_type_v=//p')
    target_flash=$(printf '%s\n' "$target_row" | sed -n 's/^flash_attention=//p')
    target_batch=$(printf '%s\n' "$target_row" | sed -n 's/^batch=//p')
    target_ubatch=$(printf '%s\n' "$target_row" | sed -n 's/^ubatch=//p')
    target_role=$(printf '%s\n' "$target_row" | sed -n 's/^role=//p')
    target_projector=$(printf '%s\n' "$target_row" | sed -n 's/^projector=//p')
    draft_model_file=$("$script_directory/model-registry.sh" id \
        "$draft_model_id" model_file)

    target_path=$model_root/$target_model_file
    draft_path=$model_root/$draft_model_file
    if [ ! -f "$target_path" ] || [ ! -f "$draft_path" ]; then
        printf 'preset_skipped pair=%s reason=weights_absent target=%s draft=%s\n' \
            "$pair_id" "$target_path" "$draft_path" >&2
        pairs_absent=$((pairs_absent + 1))
        continue
    fi
    target_projector_path=''
    if [ "$target_projector" = required ]; then
        target_projector_path=$("$script_directory/select-projector.sh" \
            "$target_path" 2>/dev/null) || target_projector_path=''
        if [ -z "$target_projector_path" ]; then
            printf 'preset_skipped pair=%s reason=projector_absent target=%s\n' \
                "$pair_id" "$target_path" >&2
            pairs_absent=$((pairs_absent + 1))
            continue
        fi
    fi

    # A pair serves the target tuple and a draft tuple at the target's derived
    # context and geometry. Profile quarantine therefore applies independently
    # to either half; matching only the target would load an explicitly refused
    # draft cache geometry.
    pair_quarantine_row=$(printf '%s\n' "$quarantine_rows" |
        awk -F'\t' -v target="$target_model_id" -v draft="$draft_model_id" \
            -v depth="$target_context" -v row_batch="$target_batch" \
            -v row_ubatch="$target_ubatch" -v cache_k="$target_cache_k" \
            -v cache_v="$target_cache_v" -v flash="$target_flash" \
            -v draft_cache_k="$draft_cache_type_k" \
            -v draft_cache_v="$draft_cache_type_v" '
            $2 == "model" && ($3 == target || $3 == draft) { print; exit }
            $2 == "profile" && $3 == target && $5 == depth &&
            $6 == row_batch && $7 == row_ubatch && $8 == cache_k &&
            $9 == cache_v && $10 == flash { print; exit }
            $2 == "profile" && $3 == draft && $5 == depth &&
            $6 == row_batch && $7 == row_ubatch && $8 == draft_cache_k &&
            $9 == draft_cache_v && $10 == flash { print; exit }')
    if [ -n "$pair_quarantine_row" ]; then
        pairs_quarantined=$((pairs_quarantined + 1))
        pair_reason_id=$(printf '%s\n' "$pair_quarantine_row" |
            awk -F'\t' '{ print $1 }')
        deploy_quarantine_reason "$pair_reason_id"
        printf 'preset_skipped pair=%s reason=quarantine record=%s\n' \
            "$pair_id" "$reason_directory/$pair_reason_id.md" >&2
        continue
    fi

    {
        printf '[%s]\n' "$pair_id"
        printf 'LLAMA_ARG_MODEL = %s\n' "$target_path"
        printf 'LLAMA_ARG_ALIAS = %s,%s\n' "$pair_id" "$pair_notes"
        printf 'LLAMA_ARG_TAGS = %s,draft-pair,%s\n' "$pair_tier" "$target_role"
        printf 'LLAMA_ARG_CTX_SIZE = %s\n' "$target_context"
        printf 'LLAMA_ARG_CACHE_TYPE_K = %s\n' "$target_cache_k"
        printf 'LLAMA_ARG_CACHE_TYPE_V = %s\n' "$target_cache_v"
        printf 'LLAMA_ARG_FLASH_ATTN = %s\n' "$target_flash"
        printf 'LLAMA_ARG_BATCH = %s\n' "$target_batch"
        printf 'LLAMA_ARG_UBATCH = %s\n' "$target_ubatch"
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = %s\n' \
            "$(ledger_ctx_checkpoints "$target_model_id")"
        printf 'LLAMA_ARG_SPEC_TYPE = draft-simple\n'
        printf 'LLAMA_ARG_SPEC_DRAFT_MODEL = %s\n' "$draft_path"
        printf 'LLAMA_ARG_SPEC_DRAFT_N_MAX = %s\n' "$spec_draft_n_max"
        printf 'LLAMA_ARG_SPEC_DRAFT_P_MIN = %s\n' "$spec_draft_p_min"
        printf 'LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_K = %s\n' "$draft_cache_type_k"
        printf 'LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_V = %s\n' "$draft_cache_type_v"
        printf 'LLAMA_ARG_N_GPU_LAYERS_DRAFT = all\n'
        printf 'spec-draft-device = Vulkan0\n'
        printf 'spec-draft-override-tensor = .*=Vulkan0\n'
        if [ -n "$target_projector_path" ]; then
            printf 'LLAMA_ARG_MMPROJ = %s\n' "$target_projector_path"
        fi
        printf '\n'
    } >>"$output_staging"
    pairs_emitted=$((pairs_emitted + 1))
done <<EOF
$draft_pair_rows
EOF

ctx_checkpoint_ledger_current_identity=$(sha256sum -- "$ctx_checkpoint_ledger")
ctx_checkpoint_ledger_current_sha256=${ctx_checkpoint_ledger_current_identity%% *}
if [ "$ctx_checkpoint_ledger_current_sha256" != "$ctx_checkpoint_ledger_sha256" ]; then
    printf 'context checkpoint ledger identity changed during generation: expected %s, measured %s\n' \
        "$ctx_checkpoint_ledger_sha256" \
        "$ctx_checkpoint_ledger_current_sha256" >&2
    exit 1
fi

chmod 600 "$output_staging"
mv -f -- "$output_staging" "$output_ini"
output_staging=''

printf 'router_presets=written path=%s models=%s unlisted=%s quarantined=%s absent=%s\n' \
    "$output_ini" "$emitted" "$skipped_unlisted" "$quarantined" "$skipped_absent"
printf 'draft_pairs=written pairs=%s unlisted=%s quarantined=%s absent=%s\n' \
    "$pairs_emitted" "$pairs_unlisted" "$pairs_quarantined" "$pairs_absent"
printf 'tier_directories production=%s candidates=%s quarantine=%s reasons=%s\n' \
    "$production_directory" "$candidate_directory" "$quarantine_directory" \
    "$reason_directory"
if [ "$include_quarantine" = 1 ]; then
    printf 'quarantine_override=on models_exposed=%s\n' "$quarantined"
fi
