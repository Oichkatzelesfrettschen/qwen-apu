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

maximum_context_size=24576
if [ "$context_size" -gt "$maximum_context_size" ]; then
    printf 'context size exceeds operational maximum: %s > %s\n' \
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

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

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
    --no-context-shift

exec "$script_directory/radv-low-priority-env.sh" "$@"
