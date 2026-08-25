#!/bin/sh
set -eu

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    printf 'usage: %s LLAMA_SERVER MODEL_PATH CONTEXT_SIZE [PORT]\n' "$0" >&2
    exit 2
fi

llama_server=$1
model_path=$2
context_size=$3
server_port=${4:-8080}

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

if env | awk -F= '$1 ~ /^LLAMA_ARG_/ { found = 1 } END { exit !found }'; then
    printf 'LLAMA_ARG_* environment overrides are forbidden by the fixed policy\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

exec "$script_directory/radv-low-priority-env.sh" \
    "$llama_server" \
    --model "$model_path" \
    --host 127.0.0.1 \
    --port "$server_port" \
    --no-ui \
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
    --batch-size 512 \
    --ubatch-size 128 \
    --flash-attn on \
    --cache-type-k q8_0 \
    --cache-type-v q4_0 \
    --ctx-checkpoints 0 \
    --cache-ram 0 \
    --no-context-shift
