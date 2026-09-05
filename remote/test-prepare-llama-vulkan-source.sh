#!/bin/sh
# Prove preparation of the production series remote/llama-patch-series.tsv
# states: recognized four-, five-, and seven-patch prefixes upgrade through
# the missing patches and every member the ledger added after them, the
# upgraded tree is then reported already verified at the ledger's own count,
# and a tree carrying an unrelated edit refuses. The script pins commit f280b269 of llama.cpp, so the
# fixture is a local clone of a checkout holding that commit; a workstation
# without one reports the test as not run rather than as passed.
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
repository_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)
base_source=${QWEN_LLAMA_BASE_SOURCE:-"$qwen_home_llama_upstream"}
pinned_commit=f280b26983ad0fdb705a0d9ebf0503e76f2899b0
production_patch_count=$(awk -F'\t' '
    /^#/ || NF == 0 { next }
    $1 == "production" { count++ }
    END { print count + 0 }' "$script_directory/llama-patch-series.tsv")

if [ ! -d "$base_source/.git" ] || \
   ! git -C "$base_source" cat-file -e "$pinned_commit^{commit}" 2>/dev/null; then
    printf 'prepare_llama_vulkan_source=not_run reason=no checkout of %s at %s\n' \
        "$pinned_commit" "$base_source"
    exit 0
fi

fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/qwen-prepare-source.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT INT TERM
patched_source=$fixture_root/llama.cpp-qwen-apu

expect_output() {
    expected=$1
    shift
    output=$("$@" 2>&1) || {
        printf 'command failed: %s\n%s\n' "$*" "$output" >&2
        exit 1
    }
    case $output in
        *"$expected"*) ;;
        *)
            printf 'expected %s in:\n%s\n' "$expected" "$output" >&2
            exit 1
            ;;
    esac
}

# Stage one: the tree a workstation prepared under the prior revision, which
# applied four patches and left tools/server/server.cpp upstream.
git clone --quiet --local --no-hardlinks --no-checkout "$base_source" "$patched_source"
git -C "$patched_source" checkout --quiet --detach "$pinned_commit"
for patch_name in \
    llama-vulkan-low-priority.patch \
    llama-no-cpu-fallback.patch \
    llama-vulkan-duty-cycle.patch \
    llama-vulkan-runtime-submit-limit.patch; do
    git -C "$patched_source" apply "$repository_directory/patches/$patch_name"
done

expect_output 'patched_source=upgraded' \
    sh "$script_directory/prepare-llama-vulkan-source.sh" "$base_source" "$patched_source"
expect_output 'patched_source=already_verified' \
    sh "$script_directory/prepare-llama-vulkan-source.sh" "$base_source" "$patched_source"
expect_output "patch_count=$production_patch_count" \
    sh "$script_directory/prepare-llama-vulkan-source.sh" "$base_source" "$patched_source"

# An unrelated edit beside an otherwise verified series refuses rather than
# passing the source-hash subset.
printf '\n' >> "$patched_source/README.md"
if output=$(QWEN_TRACE_PREPARE_ONLY=1 \
        QWEN_TRACE_STATUS_CHECKER=/bin/true \
        sh "$script_directory/build-llama-trace.sh" \
        "$base_source" "$patched_source" 2>&1); then
    printf 'build preparation accepted an extra path through a replacement checker:\n%s\n' \
        "$output" >&2
    exit 1
fi
case $output in
    *'unrecognized changes'*) ;;
    *)
        printf 'build preparation reported the wrong extra-path refusal:\n%s\n' \
            "$output" >&2
        exit 1
        ;;
esac
if output=$(sh "$script_directory/prepare-llama-vulkan-source.sh" \
        "$base_source" "$patched_source" 2>&1); then
    printf 'a tree with an unrecognized edit was accepted:\n%s\n' "$output" >&2
    exit 1
fi
case $output in
    *'unrecognized changes'*) ;;
    *)
        printf 'the refusal names the wrong reason:\n%s\n' "$output" >&2
        exit 1
        ;;
esac
git -C "$patched_source" checkout --quiet -- README.md

# A five-patch prefix already carrying the router patch upgrades through the
# submit-trace and view-alias patches.
rm -rf "$patched_source"
git clone --quiet --local --no-hardlinks --no-checkout "$base_source" "$patched_source"
git -C "$patched_source" checkout --quiet --detach "$pinned_commit"
for patch_name in \
    llama-vulkan-low-priority.patch \
    llama-no-cpu-fallback.patch \
    llama-vulkan-duty-cycle.patch \
    llama-vulkan-runtime-submit-limit.patch \
    llama-router-tools-proxy.patch; do
    git -C "$patched_source" apply "$repository_directory/patches/$patch_name"
done
expect_output 'patched_source=upgraded' \
    sh "$script_directory/prepare-llama-vulkan-source.sh" "$base_source" "$patched_source"
expect_output "patch_count=$production_patch_count" \
    sh "$script_directory/prepare-llama-vulkan-source.sh" "$base_source" "$patched_source"

# A seven-patch prefix, the shape the tree carried before the natural-boundary
# member joined the series, upgrades through that member alone.
rm -rf "$patched_source"
git clone --quiet --local --no-hardlinks --no-checkout "$base_source" "$patched_source"
git -C "$patched_source" checkout --quiet --detach "$pinned_commit"
for patch_name in \
    llama-vulkan-low-priority.patch \
    llama-no-cpu-fallback.patch \
    llama-vulkan-duty-cycle.patch \
    llama-vulkan-runtime-submit-limit.patch \
    llama-vulkan-submit-trace.patch \
    llama-router-tools-proxy.patch \
    llama-vulkan-view-alias-deps.patch; do
    git -C "$patched_source" apply "$repository_directory/patches/$patch_name"
done
expect_output 'patched_source=upgraded' \
    sh "$script_directory/prepare-llama-vulkan-source.sh" "$base_source" "$patched_source"
expect_output "patch_count=$production_patch_count" \
    sh "$script_directory/prepare-llama-vulkan-source.sh" "$base_source" "$patched_source"

# A clean pinned checkout receives the whole production series.
rm -rf "$patched_source"
git clone --quiet --local --no-hardlinks --no-checkout "$base_source" "$patched_source"
git -C "$patched_source" checkout --quiet --detach "$pinned_commit"
expect_output 'patched_source=prepared' \
    sh "$script_directory/prepare-llama-vulkan-source.sh" "$base_source" "$patched_source"

printf 'prepare_llama_vulkan_source=accepted transitions=four-prefix,five-prefix,seven-prefix,already_verified,refused,prepared build_extra_path=refused patch_count=%s\n' "$production_patch_count"
