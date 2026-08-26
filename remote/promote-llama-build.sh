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

# Every hashed object in the manifest must still hash to what the build recorded,
# so a rebuild of one dependency under a promoted tree is caught here rather than
# in a serving difference nobody attributes. hash-load-closure.sh writes
# `role<TAB>basename<TAB>bytes<TAB>sha256` and the objects sit beside the
# executable, so the basename resolves against bin/.
manifest_object_count=0
manifest_drift=''
while IFS="$(printf '\t')" read -r object_role object_name object_bytes object_digest; do
    case $object_role in
        executable | linked | loadable) ;;
        *) continue ;;
    esac
    manifest_object_count=$((manifest_object_count + 1))
    object_path=$build_directory/bin/$object_name
    if [ ! -f "$object_path" ]; then
        manifest_drift="$manifest_drift$object_name missing
"
        continue
    fi
    actual_bytes=$(stat -c %s "$object_path")
    actual_digest=$(sha256sum "$object_path" | cut -d ' ' -f 1)
    if [ "$actual_bytes" != "$object_bytes" ] || [ "$actual_digest" != "$object_digest" ]; then
        manifest_drift="$manifest_drift$object_name changed
"
    fi
done <"$manifest_path"

# A manifest that names no hashable object would otherwise pass this gate
# without checking anything, which is the failure mode the gate exists against.
if [ "$manifest_object_count" -eq 0 ]; then
    printf 'manifest names no executable, linked, or loadable object: %s\n' \
        "$manifest_path" >&2
    exit 1
fi

if [ -n "$manifest_drift" ]; then
    printf 'manifest objects no longer match the build:\n%s' "$manifest_drift" >&2
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
