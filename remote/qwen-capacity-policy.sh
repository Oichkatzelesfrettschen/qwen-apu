#!/bin/sh
set -eu

if [ "$#" -lt 3 ] || [ "$#" -gt 6 ]; then
    printf 'usage: %s LLAMA_SERVER MODEL_PATH CONTEXT_SIZE [PORT [STATIC_PATH [API_KEY_FILE]]]\n' "$0" >&2
    exit 2
fi

llama_server=$1
model_path=$2
context_size=$3
server_port=${4:-8080}
static_path=${5:-}
api_key_file=${6:-}

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bind_host=${QWEN_BIND_HOST:-127.0.0.1}
cors_origins=${QWEN_CORS_ORIGINS:-localhost}

case $bind_host in
    127.0.0.1 | localhost | 0.0.0.0) ;;
    *[!0-9.]* | '')
        printf 'bind host must be 127.0.0.1, localhost, 0.0.0.0, or an IPv4 address: %s\n' \
            "$bind_host" >&2
        exit 2
        ;;
esac

# The API key is optional at every bind address. A key authenticates callers on
# a shared network; it grants no capability the model itself withholds, so a
# trusted network serves without one and reaches the page directly.
if [ -n "$api_key_file" ] && [ -z "$static_path" ]; then
    printf 'an API key file requires a static path\n' >&2
    exit 2
fi

if [ ! -x "$llama_server" ]; then
    printf 'llama-server is not executable: %s\n' "$llama_server" >&2
    exit 2
fi

if [ ! -f "$model_path" ]; then
    printf 'model is not a regular file: %s\n' "$model_path" >&2
    exit 2
fi

case $context_size in
    '' | *[!0-9]*)
        printf 'context size must be a positive integer\n' >&2
        exit 2
        ;;
esac

if [ "$context_size" -eq 0 ]; then
    printf 'context size must be a positive integer\n' >&2
    exit 2
fi

# The admitted depth is a property of the checkpoint rather than of the
# appliance: KV cost scales with full-attention layer count and key-value head
# width, so the 9B pays more per token of context than the 2B at the same
# depth. remote/models.tsv carries one ceiling per row and this gate reads it.
# A checkpoint outside the registry keeps the depth that the 24K allocation of
# 2,974 MiB was measured against.
registry_ceiling=$("$script_directory/model-registry.sh" path "$model_path" \
    context_ceiling 2>/dev/null) || registry_ceiling=''
case $registry_ceiling in
    '' | *[!0-9]*) registry_ceiling=24576 ;;
esac

# Cache representation, Flash Attention, and context depth form one admission
# tuple. A registry ceiling belongs only to the tuple stored in that row. An
# experiment that changes any member supplies its own positive conservative
# ceiling explicitly; silently reusing the registered ceiling would present an
# unvalidated allocation as admitted policy.
registry_cache_type_k=$("$script_directory/model-registry.sh" path "$model_path" \
    cache_type_k 2>/dev/null) || registry_cache_type_k=''
registry_cache_type_v=$("$script_directory/model-registry.sh" path "$model_path" \
    cache_type_v 2>/dev/null) || registry_cache_type_v=''
registry_flash_attention=$("$script_directory/model-registry.sh" path "$model_path" \
    flash_attention 2>/dev/null) || registry_flash_attention=''
[ -n "$registry_cache_type_k" ] || registry_cache_type_k=q8_0
[ -n "$registry_cache_type_v" ] || registry_cache_type_v=q4_0
[ -n "$registry_flash_attention" ] || registry_flash_attention=on

cache_type_k=${QWEN_CACHE_TYPE_K:-$registry_cache_type_k}
cache_type_v=${QWEN_CACHE_TYPE_V:-$registry_cache_type_v}
flash_attention=${QWEN_FLASH_ATTN:-$registry_flash_attention}
for cache_type in "$cache_type_k" "$cache_type_v"; do
    if ! "$script_directory/model-registry.sh" validate-cache-type "$cache_type"; then
        printf 'cache type is outside the set llama-server accepts: %s\n' \
            "$cache_type" >&2
        exit 2
    fi
done
case $flash_attention in
    on | off | auto) ;;
    *)
        printf 'flash attention must be on, off, or auto: %s\n' \
            "$flash_attention" >&2
        exit 2
        ;;
esac

maximum_context_size=$registry_ceiling
if [ "$cache_type_k" != "$registry_cache_type_k" ] ||
   [ "$cache_type_v" != "$registry_cache_type_v" ] ||
   [ "$flash_attention" != "$registry_flash_attention" ]; then
    override_ceiling=${QWEN_CACHE_OVERRIDE_CONTEXT_CEILING:-}
    case $override_ceiling in
        '' | *[!0-9]* | 0)
            printf 'cache-policy overrides require a positive QWEN_CACHE_OVERRIDE_CONTEXT_CEILING\n' >&2
            exit 2
            ;;
    esac
    if [ "$override_ceiling" -gt "$registry_ceiling" ]; then
        printf 'cache override ceiling must not exceed the registered ceiling: %s > %s\n' \
            "$override_ceiling" "$registry_ceiling" >&2
        exit 2
    fi
    maximum_context_size=$override_ceiling
fi
if [ "$context_size" -gt "$maximum_context_size" ]; then
    printf 'context size exceeds the admitted ceiling for this cache policy: %s > %s\n' \
        "$context_size" "$maximum_context_size" >&2
    exit 2
fi

# Submission geometry comes from the row rather than from a constant, because
# the ceiling and the geometry are one claim. At 16384 the same checkpoint,
# cache triple, Flash Attention state, and device wedged the amdgpu compute ring
# at 2048/512 and completed twice at 128/32, so a depth is admitted under a
# geometry and reading the ceiling without it reads half the measurement.
registry_batch=$("$script_directory/model-registry.sh" path "$model_path" \
    batch 2>/dev/null) || registry_batch=''
registry_ubatch=$("$script_directory/model-registry.sh" path "$model_path" \
    ubatch 2>/dev/null) || registry_ubatch=''
case $registry_batch in '' | *[!0-9]*) registry_batch=128 ;; esac
case $registry_ubatch in '' | *[!0-9]*) registry_ubatch=32 ;; esac
batch_size=${QWEN_BATCH_SIZE:-$registry_batch}
ubatch_size=${QWEN_UBATCH_SIZE:-$registry_ubatch}
for submission_value in "$batch_size" "$ubatch_size"; do
    case $submission_value in
        '' | *[!0-9]* | 0)
            printf 'batch and ubatch must be positive integers: %s\n' \
                "$submission_value" >&2
            exit 2
            ;;
    esac
done
if [ "$ubatch_size" -gt "$batch_size" ]; then
    printf 'ubatch exceeds batch: %s > %s\n' "$ubatch_size" "$batch_size" >&2
    exit 2
fi

# A quarantined profile names a tuple that produced a device failure. The launch
# refuses to construct it rather than warning about it, because the failure it
# reproduces resets the compute ring on a live desktop.
registry_id=$("$script_directory/model-registry.sh" path "$model_path" \
    id 2>/dev/null) || registry_id=''
if [ -n "$registry_id" ]; then
    quarantine_hit=$("$script_directory/model-registry.sh" quarantine-profiles |
        awk -F'\t' -v id="$registry_id" -v depth="$context_size" \
            -v batch="$batch_size" -v ubatch="$ubatch_size" \
            -v cache_k="$cache_type_k" -v cache_v="$cache_type_v" \
            -v flash="$flash_attention" '
            $1 == id && $2 == depth && $3 == batch && $4 == ubatch &&
            $5 == cache_k && $6 == cache_v && $7 == flash { print $1; exit }')
    if [ -n "$quarantine_hit" ]; then
        printf 'this tuple is quarantined: %s at depth %s, batch %s, ubatch %s, K %s, V %s, flash attention %s\n' \
            "$registry_id" "$context_size" "$batch_size" "$ubatch_size" \
            "$cache_type_k" "$cache_type_v" "$flash_attention" >&2
        printf 'the reason record is evidence/quarantine/%s-d%s-b%s-ub%s.md\n' \
            "$registry_id" "$context_size" "$batch_size" "$ubatch_size" >&2
        exit 2
    fi
fi

# The allocation and the validated depth are separate claims and the status line
# carries both, so a served depth above anything measured to fill and decode is
# a visible gap rather than an implied guarantee.
registry_validated_depth=$("$script_directory/model-registry.sh" path \
    "$model_path" validated_filled_depth 2>/dev/null) || registry_validated_depth=''
[ -n "$registry_validated_depth" ] || registry_validated_depth=-
if [ "$registry_validated_depth" = - ]; then
    printf 'depth_validation admitted=%s validated=none geometry=%s/%s\n' \
        "$context_size" "$batch_size" "$ubatch_size" >&2
elif [ "$context_size" -gt "$registry_validated_depth" ]; then
    printf 'depth_validation admitted=%s validated=%s geometry=%s/%s allocation_beyond_validation=yes\n' \
        "$context_size" "$registry_validated_depth" "$batch_size" \
        "$ubatch_size" >&2
else
    printf 'depth_validation admitted=%s validated=%s geometry=%s/%s\n' \
        "$context_size" "$registry_validated_depth" "$batch_size" \
        "$ubatch_size" >&2
fi

case $server_port in
    '' | *[!0-9]*)
        printf 'port must be an integer from 1024 through 65535\n' >&2
        exit 2
        ;;
esac

if [ "$server_port" -lt 1024 ] || [ "$server_port" -gt 65535 ]; then
    printf 'port must be an integer from 1024 through 65535\n' >&2
    exit 2
fi

if [ -n "$static_path" ] && [ ! -f "$static_path/index.html" ]; then
    printf 'static path must contain index.html: %s\n' "$static_path" >&2
    exit 2
fi

if [ -n "$api_key_file" ] && [ ! -s "$api_key_file" ]; then
    printf 'API key file must be a non-empty regular file: %s\n' "$api_key_file" >&2
    exit 2
fi

if env | awk -F= '$1 ~ /^LLAMA_ARG_/ { found = 1 } END { exit !found }'; then
    printf 'LLAMA_ARG_* environment overrides are forbidden by the fixed policy\n' >&2
    exit 2
fi

# Router mode serves every admitted checkpoint behind one listener and lets the
# picker choose per chat. llama-server builds a base preset from this argv,
# strips the SSL, API key, and models-* keys from it, and cascades the rest onto
# each child it spawns, so every guard below reaches the child unchanged and the
# preset file supplies only what differs per checkpoint.
#
# models-max is 1 rather than the upstream default of 4. The 4B alone peaks at
# 2029 MiB of a 2048 MiB VRAM carve-out with 2700 MiB more in GTT, so a second
# resident model competes for a pool already saturated by one. Switching models
# unloads the previous one, which costs a reload and buys a device that fits.
router_presets=${QWEN_ROUTER_PRESETS:-"${HOME:?}/qwen-webui-state/router-presets.ini"}
router_max=${QWEN_ROUTER_MAX:-1}
if [ "${QWEN_ROUTER:-0}" = 1 ]; then
    if [ ! -r "$router_presets" ]; then
        printf 'router presets are unreadable: %s\n' "$router_presets" >&2
        printf 'generate them with remote/build-router-presets.sh\n' >&2
        exit 2
    fi
    case $router_max in
        '' | *[!0-9]*)
            printf 'router model limit must be a non-negative integer: %s\n' \
                "$router_max" >&2
            exit 2
            ;;
    esac
    # A quarantined checkpoint reaches the picker only through the research
    # override, and it stays on the loopback while it does. The appliance binds
    # 0.0.0.0 so the laptop serves the LAN, and a warning alone would leave a
    # model with a recorded device failure or no validated safe tuple reachable
    # from every host on that network. The bind host is forced rather than
    # refused, so the override runs the experiment it exists for and the
    # exposure it would create does not follow it.
    if [ "${QWEN_ROUTER_INCLUDE_QUARANTINE:-0}" = 1 ]; then
        if [ "$bind_host" != 127.0.0.1 ]; then
            printf 'quarantine override forces the listener to loopback: %s -> 127.0.0.1\n' \
                "$bind_host" >&2
            bind_host=127.0.0.1
        fi
    fi
    set -- "$llama_server" \
        --models-preset "$router_presets" \
        --models-max "$router_max" \
        --host "$bind_host" \
        --port "$server_port" \
        --cors-origins "$cors_origins"
else
    set -- "$llama_server" \
        --model "$model_path" \
        --host "$bind_host" \
        --port "$server_port" \
        --alias qwen-apu \
        --cors-origins "$cors_origins"
fi

if [ -n "$static_path" ]; then
    set -- "$@" --path "$static_path" --ui
else
    set -- "$@" --no-ui
fi

if [ -n "$api_key_file" ]; then
    set -- "$@" --api-key-file "$api_key_file"
fi

# The projector turns images into embeddings the language model consumes; a
# text GGUF alone never gains vision. It must come from the same checkpoint as
# the language weights, which download-qwen35-4b-mmproj.sh pins to the same
# repository revision. Offloading it to Vulkan costs about 672 MiB of a heap
# with over 12 GiB free, and the alternative is running a vision encoder on two
# CPU cores.
if [ -n "${QWEN_MMPROJ:-}" ] && [ "${QWEN_ROUTER:-0}" != 1 ]; then
    if [ ! -f "$QWEN_MMPROJ" ]; then
        printf 'projector is not a regular file: %s\n' "$QWEN_MMPROJ" >&2
        exit 2
    fi
    set -- "$@" --mmproj "$QWEN_MMPROJ"
    if [ "${QWEN_MMPROJ_OFFLOAD:-1}" = 0 ]; then
        set -- "$@" --no-mmproj-offload
    fi
    if [ -n "${QWEN_IMAGE_MAX_TOKENS:-}" ]; then
        set -- "$@" --image-max-tokens "$QWEN_IMAGE_MAX_TOKENS"
    fi
fi

# Speculation is a policy argument rather than an ambient override, so the four
# variables below are the whole surface and LLAMA_ARG_* stays refused above.
# draft-mtp needs no second checkpoint: common_speculative_init_result takes the
# `else if (spec_mtp)` branch and builds the draft context against the target
# model, and llama_model::create_memory filters the MTP KV cache to
# `il >= hparams.n_layer()`, so the draft cache holds the one appended NextN
# block. The 4B distill carries that block at 37,767,168 bytes, which the
# ordinary load reports as an unused tensor and skips.
spec_type=${QWEN_SPEC_TYPE:-}
if [ -n "$spec_type" ]; then
    case $spec_type in
        draft-mtp | ngram-simple | ngram-map-k | ngram-map-k4v | ngram-mod | ngram-cache) ;;
        *)
            printf 'speculation type must be draft-mtp or an ngram type: %s\n' \
                "$spec_type" >&2
            exit 2
            ;;
    esac
    set -- "$@" --spec-type "$spec_type"

    spec_draft_n_max=${QWEN_SPEC_DRAFT_N_MAX:-}
    if [ -n "$spec_draft_n_max" ]; then
        case $spec_draft_n_max in
            '' | *[!0-9]*)
                printf 'draft length must be a non-negative integer: %s\n' \
                    "$spec_draft_n_max" >&2
                exit 2
                ;;
        esac
        # A draft of N tokens makes the target emit N+1 output positions in one
        # pass, and common_speculative_get_output_limits clamps that count to
        # the batch size. Sixteen keeps the product inside the 128-token batch
        # this policy sets.
        if [ "$spec_draft_n_max" -gt 16 ]; then
            printf 'draft length exceeds operational maximum: %s > 16\n' \
                "$spec_draft_n_max" >&2
            exit 2
        fi
        # Zero aborts the pinned server on the first prompt:
        # common_speculative_get_output_limits sizes the target context for
        # `1 + n_draft` outputs while the speculative decode path still asks for
        # two, and llama-context.cpp:2227 asserts
        # `n_outputs_max <= cparams.n_outputs_max`. common/arg.cpp accepts any
        # value at or above zero, so the gate is here.
        if [ "$spec_draft_n_max" -eq 0 ]; then
            printf 'draft length of zero aborts the pinned server; omit QWEN_SPEC_TYPE to disable speculation\n' >&2
            exit 2
        fi
        set -- "$@" --spec-draft-n-max "$spec_draft_n_max"
    fi

    # p_min gates drafting rather than acceptance: common/speculative.cpp reads
    # llama_get_embeddings_nextn and breaks out of the draft loop when the
    # head's confidence falls below it, so a floor of 1 leaves the MTP block
    # loaded and the draft context built while no draft reaches the target.
    spec_draft_p_min=${QWEN_SPEC_DRAFT_P_MIN:-}
    if [ "$spec_draft_p_min" = 0 ]; then
        spec_draft_p_min=''
    fi
    if [ -n "$spec_draft_p_min" ]; then
        case $spec_draft_p_min in
            *[!0-9.]* | '' | *.*.*)
                printf 'draft probability floor must be a decimal fraction: %s\n' \
                    "$spec_draft_p_min" >&2
                exit 2
                ;;
        esac
        set -- "$@" --spec-draft-p-min "$spec_draft_p_min"
    fi

    if [ "${QWEN_SPEC_BACKEND_SAMPLING:-0}" = 1 ]; then
        set -- "$@" --spec-draft-backend-sampling
    fi
fi

# Backend sampling moves the supported sampler chain onto the device. This
# vocabulary is 248,320 entries wide, so the transfer it removes is the largest
# per-token host copy the server makes. It is experimental in the pinned build,
# which is why it is a variable rather than the default.
if [ "${QWEN_BACKEND_SAMPLING:-0}" = 1 ]; then
    set -- "$@" --backend-sampling
fi

set -- "$@" \
    --log-verbosity 4 \
    --device Vulkan0 \
    --split-mode none \
    --n-gpu-layers all \
    --override-tensor '.*=Vulkan0' \
    --fit off \
    --ctx-size "$context_size" \
    --parallel 1 \
    --threads 1 \
    --threads-batch 1 \
    --batch-size "$batch_size" \
    --ubatch-size "$ubatch_size" \
    --flash-attn "$flash_attention" \
    --cache-type-k "$cache_type_k" \
    --cache-type-v "$cache_type_v" \
    --ctx-checkpoints 0 \
    --cache-ram 0 \
    --no-context-shift \
    --offline

exec "$script_directory/radv-low-priority-env.sh" "$@"
