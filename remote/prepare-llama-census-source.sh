#!/bin/sh
set -eu

# The source tree the census preset compiles: the production series prepared
# and verified by prepare-llama-vulkan-source.sh, then the candidate patches
# named on the command line applied on top, in ledger order. The patched
# tree must not exist beforehand, so the production verification runs over
# a fresh clone and the candidates land on exactly that state; a tree that
# already carries candidates is rebuilt rather than re-verified here, since
# build-llama-preset.sh verifies the compiled tree against a replay of the
# same selection through QWEN_LLAMA_CANDIDATE_SELECT.
#
# A caller who removes the previous tree and prepares the next one at the same
# path keeps the build cache warm. The binary key is content-addressed and
# crosses paths, so an unchanged selection reuses its executables from
# anywhere; the shader pack additionally carries ninja's build and dependency
# logs, whose command hashes and output keys name the source and build
# directories absolutely, so it is stored per path pair and reused where that
# pair repeats.
#
# usage: prepare-llama-census-source.sh BASE_SOURCE PATCHED_SOURCE PATCH [PATCH...]

if [ "$#" -lt 3 ]; then
    printf 'usage: %s BASE_SOURCE PATCHED_SOURCE PATCH [PATCH...]\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)
base_source=$1
patched_source=$2
shift 2

if [ -e "$patched_source" ]; then
    printf 'patched source exists; a candidate tree is prepared fresh: %s\n' \
        "$patched_source" >&2
    exit 1
fi
series_ledger=$script_directory/llama-patch-series.tsv
for candidate_name in "$@"; do
    if ! awk -F'\t' -v name="$candidate_name" \
        '$1 == "candidate" && $2 == name { found = 1 } END { exit found ? 0 : 1 }' \
        "$series_ledger"; then
        printf 'patch is not a candidate-stage member of %s: %s\n' \
            "$series_ledger" "$candidate_name" >&2
        exit 1
    fi
done

"$script_directory/prepare-llama-vulkan-source.sh" "$base_source" "$patched_source"

applied=''
for candidate_name in "$@"; do
    git -C "$patched_source" apply --check "$repository_directory/patches/$candidate_name"
    git -C "$patched_source" apply "$repository_directory/patches/$candidate_name"
    applied="$applied${applied:+,}$candidate_name"
done
git -C "$patched_source" diff --check
printf 'census_source=prepared path=%s candidates=%s\n' "$patched_source" "$applied"
printf 'build with: QWEN_LLAMA_CANDIDATE_SELECT="%s" %s/build-llama-preset.sh raven2-vulkan-census %s\n' \
    "$(printf '%s' "$applied" | tr ',' ' ')" "$script_directory" "$patched_source"
