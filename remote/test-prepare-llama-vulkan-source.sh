#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)
base_source=${QWEN_LLAMA_BASE_SOURCE:-"${HOME:?}/src/llama.cpp"}
pinned_commit=f280b26983ad0fdb705a0d9ebf0503e76f2899b0

if [ ! -d "$base_source/.git" ] || \
   ! git -C "$base_source" cat-file -e "$pinned_commit^{commit}" 2>/dev/null; then
    printf 'prepare_llama_vulkan_source=not_run reason=no_checkout path=%s commit=%s\n' \
        "$base_source" "$pinned_commit"
    exit 0
fi

fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/qwen-prepare-source.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT HUP INT TERM
patched_source=$fixture_root/llama.cpp-qwen-apu

expect_output() {
    expected_output=$1
    shift
    command_output=$("$@" 2>&1) || {
        printf 'command failed: %s\n%s\n' "$*" "$command_output" >&2
        exit 1
    }
    case $command_output in
        *"$expected_output"*) ;;
        *)
            printf 'expected %s in:\n%s\n' "$expected_output" "$command_output" >&2
            exit 1
            ;;
    esac
}

git clone --quiet --local --no-hardlinks --no-checkout \
    "$base_source" "$patched_source"
git -C "$patched_source" checkout --quiet --detach "$pinned_commit"
for patch_name in \
    llama-vulkan-low-priority.patch \
    llama-no-cpu-fallback.patch \
    llama-vulkan-duty-cycle.patch \
    llama-vulkan-runtime-submit-limit.patch; do
    git -C "$patched_source" apply "$repository_directory/patches/$patch_name"
done

expect_output 'patched_source=upgraded' \
    "$script_directory/prepare-llama-vulkan-source.sh" \
    "$base_source" "$patched_source"
expect_output 'patched_source=already_verified' \
    "$script_directory/prepare-llama-vulkan-source.sh" \
    "$base_source" "$patched_source"

printf '\nfixture edit\n' >>"$patched_source/README.md"
if command_output=$("$script_directory/prepare-llama-vulkan-source.sh" \
        "$base_source" "$patched_source" 2>&1); then
    printf 'a tree with an unrecognized edit was accepted:\n%s\n' \
        "$command_output" >&2
    exit 1
fi
case $command_output in
    *'unrecognized changes'*) ;;
    *)
        printf 'the refusal names the wrong reason:\n%s\n' \
            "$command_output" >&2
        exit 1
        ;;
esac

rm -rf "$patched_source"
expect_output 'patched_source=prepared' \
    "$script_directory/prepare-llama-vulkan-source.sh" \
    "$base_source" "$patched_source"

printf 'prepare_llama_vulkan_source=accepted transitions=upgraded,already_verified,refused,prepared\n'
