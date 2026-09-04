#!/bin/sh
set -eu

# Every branch of the candidate-derived CMake option set, driven as a function
# so each selection is stated one at a time. The build itself needs a pinned
# llama.cpp checkout and a Vulkan toolchain; this derivation needs neither, so
# the branch that decides whether a control compiles the candidate's source in
# is proven here rather than inferred from a whole build.
#
# The property under test is that both directions are stated. CMake keeps an
# option in CMakeCache.txt across configurations of one build directory, so an
# unstated OFF is an inherited ON wherever that directory once carried the
# candidate.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=remote/build-candidate-flags.sh
. "$script_directory/build-candidate-flags.sh"

checks=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
}
expect_flags() {
    expectation_name=$1
    selection=$2
    expected=$3
    observed=$(qwen_candidate_cmake_flags "$selection" | tr '\n' ' ' |
        sed 's/ $//')
    if [ "$observed" != "$expected" ]; then
        printf 'candidate flags for "%s": expected "%s", derived "%s"\n' \
            "$selection" "$expected" "$observed" >&2
        exit 1
    fi
    report "$expectation_name" accepted
}

# The selection that names the int24 patch turns the option on.
expect_flags int24_selected llama-vulkan-q4k-int24-mmvq.patch \
    -DGGML_VULKAN_INT24_DOT=ON

# The same patch inside a multi-patch selection, at either end and in the
# middle, since the builder passes the whole candidate list.
expect_flags int24_first \
    'llama-vulkan-q4k-int24-mmvq.patch llama-vulkan-pipeline-census.patch' \
    -DGGML_VULKAN_INT24_DOT=ON
expect_flags int24_last \
    'llama-vulkan-pipeline-census.patch llama-vulkan-q4k-int24-mmvq.patch' \
    -DGGML_VULKAN_INT24_DOT=ON
expect_flags int24_middle \
    'llama-vulkan-pipeline-census.patch llama-vulkan-q4k-int24-mmvq.patch llama-vulkan-q4k-activation-group-sums.patch' \
    -DGGML_VULKAN_INT24_DOT=ON

# An empty selection states OFF rather than nothing, which is the control the
# candidate is measured against.
expect_flags empty_selection '' -DGGML_VULKAN_INT24_DOT=OFF

# A selection naming other candidates states OFF for the same reason: the
# census pair reconfigures one directory per preset across arms.
expect_flags other_candidates_only \
    'llama-vulkan-pipeline-census.patch llama-server-vulkan-workload-lease.patch' \
    -DGGML_VULKAN_INT24_DOT=OFF

# A name the int24 patch name is a substring of matches nothing, because the
# selection is compared against blank-delimited whole names.
expect_flags substring_never_matches \
    'not-llama-vulkan-q4k-int24-mmvq.patch.disabled' \
    -DGGML_VULKAN_INT24_DOT=OFF

# The builder consumes this derivation rather than restating it, so a branch
# fixed here is fixed in the build.
if ! grep -q 'build-candidate-flags.sh' \
    "$script_directory/build-llama-preset.sh"; then
    printf 'the build no longer sources the candidate flag derivation\n' >&2
    exit 1
fi
report build_sources_derivation accepted
if ! grep -q 'qwen_candidate_cmake_flags' \
    "$script_directory/build-llama-preset.sh"; then
    printf 'the build no longer calls the candidate flag derivation\n' >&2
    exit 1
fi
report build_calls_derivation accepted

# Every candidate the ledger carries is a name this derivation has an answer
# for, and the answer for a name it holds no option for is the empty set. The
# check runs the ledger's own rows so a candidate added there reaches the
# derivation rather than only the builder.
ledger=$script_directory/llama-patch-series.tsv
if [ ! -r "$ledger" ]; then
    printf 'the patch series ledger is unreadable: %s\n' "$ledger" >&2
    exit 1
fi
ledger_candidates=$(awk -F'\t' '$1 == "candidate" { print $2 }' "$ledger")
for candidate_name in $ledger_candidates; do
    if ! qwen_candidate_cmake_flags "$candidate_name" >/dev/null; then
        printf 'the derivation failed for ledger candidate %s\n' \
            "$candidate_name" >&2
        exit 1
    fi
done
report ledger_candidates_derive accepted

printf 'build_llama_preset_flags=accepted checks=%s\n' "$checks"
