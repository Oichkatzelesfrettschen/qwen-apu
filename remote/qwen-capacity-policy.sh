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
maximum_context_size=$registry_ceiling
if [ "$context_size" -gt "$maximum_context_size" ]; then
    printf 'context size exceeds the registered ceiling for this model: %s > %s\n' \
        "$context_size" "$maximum_context_size" >&2
    exit 2
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

set -- "$llama_server" \
    --model "$model_path" \
    --host "$bind_host" \
    --port "$server_port" \
    --alias qwen-apu \
    --cors-origins "$cors_origins"

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
if [ -n "${QWEN_MMPROJ:-}" ]; then
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

    spec_draft_p_min=${QWEN_SPEC_DRAFT_P_MIN:-}
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
    --batch-size 128 \
    --ubatch-size 32 \
    --flash-attn on \
    --cache-type-k q8_0 \
    --cache-type-v q4_0 \
    --ctx-checkpoints 0 \
    --cache-ram 0 \
    --no-context-shift \
    --offline

exec "$script_directory/radv-low-priority-env.sh" "$@"
