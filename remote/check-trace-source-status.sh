#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf 'usage: %s TRACE_SOURCE\n' "$0" >&2
    exit 2
fi

trace_source=$1
if [ ! -d "$trace_source/.git" ]; then
    printf 'trace source repository is invalid: %s\n' "$trace_source" >&2
    exit 2
fi

expected_status=$(printf '%s\n' \
    ' M ggml/src/ggml-vulkan/ggml-vulkan.cpp' \
    ' M src/llama-context.cpp' \
    ' M src/llama-model-loader.cpp' \
    ' M tools/server/server-context.cpp' \
    ' M tools/server/server.cpp' \
    '?? ggml/src/ggml-vulkan/ggml-vulkan-pacing.h' \
    '?? ggml/src/ggml-vulkan/ggml-vulkan-submit-limit.h' \
    '?? ggml/src/ggml-vulkan/ggml-vulkan-submit-trace.h' | LC_ALL=C sort)
actual_status=$(git -c core.fsmonitor=false -C "$trace_source" status --porcelain=v1 \
    --untracked-files=all | LC_ALL=C sort)
if [ "$actual_status" != "$expected_status" ]; then
    printf 'trace source status differs from the exact eight-patch path set: %s\n' \
        "$trace_source" >&2
    printf 'expected:\n%s\nactual:\n%s\n' "$expected_status" \
        "${actual_status:-<clean>}" >&2
    exit 1
fi

printf 'trace_source_status=accepted paths=8\n'
