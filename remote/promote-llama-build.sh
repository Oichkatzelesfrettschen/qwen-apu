#!/bin/sh
set -eu

# The serving path names one build directory, so measuring a second build arm
# means editing the control script and a rollback means editing it back. This
# promotes a preset behind a symlink instead: qwen-webui-control.sh resolves
# build-appliance-current, and switching arms is one atomic rename.
#
# Promotion is a gate rather than a rename. The manifest must exist and name the
# preset, the executable must report its own version, and it must complete one
# token entirely on Vulkan, because a binary that loads and then falls back to
# the CPU backend serves at a third of the rate while looking healthy.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s PRESET [SOURCE_DIRECTORY]\n' "$0" >&2
    printf '  --rollback restores the retained previous target\n' >&2
    exit 2
fi

preset=$1
source_directory=${2:-"${HOME:?}/src/llama.cpp-qwen-apu"}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
current_link=$source_directory/build-appliance-current
previous_link=$source_directory/build-appliance-previous

if [ "$preset" = --rollback ]; then
    if [ ! -L "$previous_link" ]; then
        printf 'no retained previous target to roll back to: %s\n' "$previous_link" >&2
        exit 1
    fi
    rollback_target=$(readlink "$previous_link")
    ln -sfn "$rollback_target" "$current_link.new"
    mv -T "$current_link.new" "$current_link"
    printf 'promotion=rolled-back target=%s\n' "$rollback_target"
    exit 0
fi

build_directory=$source_directory/build-$preset
manifest_path=$build_directory/artifact-manifest.tsv
server_path=$build_directory/bin/llama-server

if [ ! -x "$server_path" ]; then
    printf 'preset has no executable llama-server: %s\n' "$server_path" >&2
    exit 1
fi

if [ ! -r "$manifest_path" ]; then
    printf 'preset has no artifact manifest: %s\n' "$manifest_path" >&2
    exit 1
fi

manifest_preset=$(awk -F'\t' '$1 == "preset" { print $2; exit }' "$manifest_path")
if [ "$manifest_preset" != "$preset" ]; then
    printf 'manifest names a different preset: %s against %s\n' \
        "$manifest_preset" "$preset" >&2
    exit 1
fi

# Every hashed object in the manifest must still hash to what the build
# recorded, so a rebuild of one dependency under a promoted tree is caught here
# rather than in a serving difference nobody attributes.
manifest_drift=$(awk -F'\t' 'NF == 3 && $1 ~ /^\// { print $1 "\t" $3 }' "$manifest_path" |
    while IFS="$(printf '\t')" read -r object_path recorded_digest; do
        [ -f "$object_path" ] || { printf '%s missing\n' "$object_path"; continue; }
        actual_digest=$(sha256sum "$object_path" | awk '{ print $1 }')
        [ "$actual_digest" = "$recorded_digest" ] || printf '%s changed\n' "$object_path"
    done)
if [ -n "$manifest_drift" ]; then
    printf 'manifest objects no longer match the build:\n%s\n' "$manifest_drift" >&2
    exit 1
fi

"$server_path" --version >/dev/null 2>&1 || {
    printf 'llama-server does not report a version: %s\n' "$server_path" >&2
    exit 1
}

# One token, all layers on Vulkan, no CPU fallback admitted. A model is required
# because the check is that the device path completes, not that the binary runs.
promotion_model=${QWEN_PROMOTION_MODEL:-"${HOME:?}/models/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf"}
if [ -f "$promotion_model" ]; then
    strict_output=$(nice -n 19 "$build_directory/bin/llama-cli" \
        --model "$promotion_model" --device Vulkan0 --n-gpu-layers all \
        --override-tensor '.*=Vulkan0' --no-warmup --ctx-size 256 \
        --n-predict 1 --temp 0 --prompt 'ok' --no-conversation 2>&1) || {
            printf 'strict Vulkan one-token check failed:\n%s\n' "$strict_output" >&2
            exit 1
        }
    case $strict_output in
        *"CPU buffer size"*)
            printf 'strict Vulkan check placed tensors on the CPU backend\n' >&2
            printf '%s\n' "$strict_output" | grep -F 'buffer size' >&2
            exit 1
            ;;
    esac
    strict_state=passed
else
    # A check that silently skips is a check that never fails, so the absence is
    # reported rather than folded into a pass.
    printf 'promotion_model_absent path=%s strict_vulkan=not-run\n' "$promotion_model" >&2
    strict_state=not-run
fi

if [ -L "$current_link" ]; then
    ln -sfn "$(readlink "$current_link")" "$previous_link.new"
    mv -T "$previous_link.new" "$previous_link"
fi

ln -sfn "$build_directory" "$current_link.new"
mv -T "$current_link.new" "$current_link"

printf 'promotion=accepted preset=%s target=%s strict_vulkan=%s previous=%s\n' \
    "$preset" "$build_directory" "$strict_state" \
    "$([ -L "$previous_link" ] && readlink "$previous_link" || printf none)"
