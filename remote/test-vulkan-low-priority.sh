#!/bin/sh
set -eu

if [ "${QWEN_ONE_CORE_ACTIVE:-0}" != 1 ]; then
    QWEN_ONE_CORE_ACTIVE=1 exec taskset -c 0 nice -n 19 ionice -c 3 "$0" "$@"
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
llama_server_binary=""
model_path=""

if [ "$#" -gt 0 ]; then
    if [ "$#" -ne 4 ] || [ "$1" != "--llama-server" ] || \
       [ "$3" != "--model" ]; then
        printf 'usage: %s [--llama-server PATH --model PATH]\n' "$0" >&2
        exit 2
    fi
    llama_server_binary=$2
    model_path=$4
    if [ ! -x "$llama_server_binary" ]; then
        printf 'llama-server is not executable: %s\n' "$llama_server_binary" >&2
        exit 2
    fi
    if [ ! -f "$model_path" ]; then
        printf 'model is not a regular file: %s\n' "$model_path" >&2
        exit 2
    fi
fi

temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
probe_binary=$temporary_directory/vulkan-low-priority-probe

cc -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror \
    "$script_directory/vulkan-low-priority-probe.c" -lvulkan -o "$probe_binary"

radv_icd=${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
if [ ! -r "$radv_icd" ]; then
    printf 'RADV ICD is not readable: %s\n' "$radv_icd" >&2
    exit 1
fi

probe_output=$(
    env DISPLAY= WAYLAND_DISPLAY= VK_ICD_FILENAMES="$radv_icd" \
        "$probe_binary"
)
printf '%s\n' "$probe_output"
printf '%s\n' "$probe_output" | grep -F 'global_priority=LOW result=VK_SUCCESS' >/dev/null

if [ -z "$llama_server_binary" ]; then
    printf 'llama_binary=not-tested reason=not-built\n'
    exit 0
fi

default_output=$(
    env -u GGML_VK_LOW_PRIORITY DISPLAY= WAYLAND_DISPLAY= \
        VK_ICD_FILENAMES="$radv_icd" "$llama_server_binary" --list-devices 2>&1
)
if printf '%s\n' "$default_output" | grep -F 'global queue priority = LOW' >/dev/null; then
    printf 'default device listing selected LOW unexpectedly\n' >&2
    exit 1
fi

default_log=$temporary_directory/default.log
low_priority_log=$temporary_directory/low.log

set +e
env -u GGML_VK_LOW_PRIORITY DISPLAY= WAYLAND_DISPLAY= \
    VK_DRIVER_FILES="$radv_icd" VK_ICD_FILENAMES="$radv_icd" \
    timeout --signal=TERM 3 "$llama_server_binary" \
        --model "$model_path" --device Vulkan0 --split-mode none \
        --n-gpu-layers all --fit off --ctx-size 128 --parallel 1 \
        --threads 1 --threads-batch 1 --no-ui --host 127.0.0.1 \
        --port 18082 -lv 10 >"$default_log" 2>&1
default_status=$?
env GGML_VK_LOW_PRIORITY=1 DISPLAY= WAYLAND_DISPLAY= \
    VK_DRIVER_FILES="$radv_icd" VK_ICD_FILENAMES="$radv_icd" \
    timeout --signal=TERM 3 "$llama_server_binary" \
        --model "$model_path" --device Vulkan0 --split-mode none \
        --n-gpu-layers all --fit off --ctx-size 128 --parallel 1 \
        --threads 1 --threads-batch 1 --no-ui --host 127.0.0.1 \
        --port 18083 -lv 10 >"$low_priority_log" 2>&1
low_priority_status=$?
set -e

if [ "$default_status" -ne 124 ] || [ "$low_priority_status" -ne 124 ]; then
    printf 'llama-server priority probes did not remain ready until timeout: default=%s low=%s\n' \
        "$default_status" "$low_priority_status" >&2
    exit 1
fi

if grep -F 'global queue priority = LOW' "$default_log" >/dev/null; then
    printf 'default model initialization selected LOW unexpectedly\n' >&2
    exit 1
fi

low_priority_output=$(cat "$low_priority_log")
printf '%s\n' "$low_priority_output" | grep -F 'global queue priority = LOW' >/dev/null
printf '%s\n' "$low_priority_output" | grep -F 'RADV RAVEN2' >/dev/null
printf '%s\n' "$low_priority_output" | grep -F 'model loaded' >/dev/null

printf 'llama_default_priority=unchanged llama_low_priority=accepted device=RADV_RAVEN2\n'
