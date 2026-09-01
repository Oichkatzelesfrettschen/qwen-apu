#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
checker=$script_directory/check-trace-source-status.sh
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
repository=$temporary_directory/source

git -c core.fsmonitor=false init -q "$repository"
git -c core.fsmonitor=false -C "$repository" config user.name fixture
git -c core.fsmonitor=false -C "$repository" config user.email fixture@example.invalid
mkdir -p "$repository/ggml/src/ggml-vulkan" "$repository/src" \
    "$repository/tools/server"
: >"$repository/.gitignore"
for tracked_path in \
    ggml/src/ggml-vulkan/ggml-vulkan.cpp \
    src/llama-context.cpp \
    src/llama-model-loader.cpp \
    tools/server/server-context.cpp \
    tools/server/server.cpp; do
    printf 'base\n' >"$repository/$tracked_path"
done
git -c core.fsmonitor=false -C "$repository" add .
git -c core.fsmonitor=false -C "$repository" commit -qm base
for tracked_path in \
    ggml/src/ggml-vulkan/ggml-vulkan.cpp \
    src/llama-context.cpp \
    src/llama-model-loader.cpp \
    tools/server/server-context.cpp \
    tools/server/server.cpp; do
    printf 'patched\n' >>"$repository/$tracked_path"
done
for added_path in \
    ggml/src/ggml-vulkan/ggml-vulkan-pacing.h \
    ggml/src/ggml-vulkan/ggml-vulkan-submit-limit.h \
    ggml/src/ggml-vulkan/ggml-vulkan-submit-trace.h; do
    printf 'patched\n' >"$repository/$added_path"
done

"$checker" "$repository" >/dev/null

printf 'unrelated\n' >"$repository/unrelated.txt"
if "$checker" "$repository" >/dev/null 2>&1; then
    printf 'trace status checker accepted an unrelated untracked path\n' >&2
    exit 1
fi
rm "$repository/unrelated.txt"

printf 'base changed\n' >>"$repository/.gitignore"
if "$checker" "$repository" >/dev/null 2>&1; then
    printf 'trace status checker accepted an unrelated tracked modification\n' >&2
    exit 1
fi

printf 'trace_source_status_tests=passed\n'
