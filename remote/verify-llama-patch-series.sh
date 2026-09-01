#!/bin/sh
set -eu

if [ "$#" -gt 2 ]; then
    printf 'usage: %s [LLAMA_SOURCE] [PATCH_DIRECTORY]\n' "$0" >&2
    exit 2
fi

renice -n 19 -p $$ >/dev/null
taskset -pc 0 $$ >/dev/null
ionice -c 3 -p $$

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)
source_directory=${1:-"${HOME:?}/src/llama.cpp"}
patch_directory=${2:-"$repository_directory/patches"}
expected_commit=f280b26983ad0fdb705a0d9ebf0503e76f2899b0
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM

if [ ! -d "$source_directory/.git" ]; then
    printf 'llama.cpp source repository is missing: %s\n' "$source_directory" >&2
    exit 1
fi

git clone --quiet --shared --no-checkout "$source_directory" \
    "$temporary_directory/llama.cpp"
git -C "$temporary_directory/llama.cpp" checkout --quiet --detach \
    "$expected_commit"

# remote/llama-patch-series.tsv is the one authority for the ordered series.
# Reading it here rather than restating it keeps a member added to the ledger
# from being missed by the replay that is supposed to pin its result.
series_ledger=$script_directory/llama-patch-series.tsv
if [ ! -r "$series_ledger" ]; then
    printf 'patch series ledger is unreadable: %s\n' "$series_ledger" >&2
    exit 1
fi
read_series_stage() {
    awk -F'\t' -v stage="$1" '
        /^#/ || NF == 0 { next }
        NF != 2 { printf "malformed patch series row: %s\n", $0 > "/dev/stderr"; exit 1 }
        $1 == stage { print $2 }
    ' "$series_ledger"
}
production_patch_names=$(read_series_stage production)
if [ -z "$production_patch_names" ]; then
    printf 'patch series ledger names no production member: %s\n' \
        "$series_ledger" >&2
    exit 1
fi
for patch_name in $production_patch_names; do
    git -C "$temporary_directory/llama.cpp" apply --check \
        "$patch_directory/$patch_name"
    git -C "$temporary_directory/llama.cpp" apply \
        "$patch_directory/$patch_name"
done
git -C "$temporary_directory/llama.cpp" diff --check

verify_source() {
    expected_sha256=$1
    relative_path=$2
    actual_sha256=$(sha256sum "$temporary_directory/llama.cpp/$relative_path" | cut -d ' ' -f 1)
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        printf 'source replay mismatch: %s expected %s found %s\n' \
            "$relative_path" "$expected_sha256" "$actual_sha256" >&2
        exit 1
    fi
    printf 'patch_replay_match=%s sha256=%s\n' "$relative_path" "$actual_sha256"
}

# remote/llama-patched-sources.tsv carries the post-replay digest of every
# file the production series rewrites, so this replay and the build's own
# source-tree comparison read one authority: a row added here reaches both.
patched_sources_ledger=$script_directory/llama-patched-sources.tsv
if [ ! -r "$patched_sources_ledger" ]; then
    printf 'patched sources ledger is unreadable: %s\n' \
        "$patched_sources_ledger" >&2
    exit 1
fi
patched_source_rows=$(awk -F'\t' '
    /^#/ || NF == 0 { next }
    NF != 2 { printf "malformed patched sources row: %s\n", $0 > "/dev/stderr"; exit 1 }
    { print $2 "\t" $1 }
' "$patched_sources_ledger")
if [ -z "$patched_source_rows" ]; then
    printf 'patched sources ledger names no member: %s\n' \
        "$patched_sources_ledger" >&2
    exit 1
fi
printf '%s\n' "$patched_source_rows" | while IFS='	' read -r row_sha256 row_path; do
    verify_source "$row_sha256" "$row_path"
done

# One digest over the ordered production series, so a build can record which
# series it compiled in a single field. It is computed over the members' own
# digests in ledger order, which makes a reordering and a substitution both
# visible; build-llama-preset.sh recomputes it the same way from the same
# ledger and records it beside the semantics it declares.
series_identity=''
for patch_name in $production_patch_names; do
    series_identity=$series_identity$(
        sha256sum "$patch_directory/$patch_name" | cut -d ' ' -f 1
    )
done
patch_series_sha256=$(printf '%s' "$series_identity" | sha256sum | cut -d ' ' -f 1)
printf 'patch_series=accepted commit=%s patch_series_sha256=%s members=%s\n' \
    "$expected_commit" "$patch_series_sha256" \
    "$(printf '%s\n' "$production_patch_names" | grep -c .)"

# A candidate patch is a backport under measurement rather than a member of the
# production series. Its stage runs after every production digest is verified
# and mutates the replay tree afterwards, so the loop above and the expected
# sums it compares against stay byte-identical whether the stage runs or not.
# QWEN_LLAMA_CANDIDATE_PATCHES=1 arms it; the printed post-apply digest is what
# a promotion would move into verify_source once its evidence lane closes. The
# stage's membership comes from remote/llama-patch-series.tsv rather than from
# a second list here.
candidate_patch_names=$(read_series_stage candidate)
# One digest line per file the candidate stage rewrites. Retained evidence
# quotes the ggml-vulkan.cpp line, so it keeps its format and its position.
candidate_digest_paths="tools/server/server-context.cpp"
if [ "${QWEN_LLAMA_CANDIDATE_PATCHES:-0}" = 1 ]; then
    for candidate_name in $candidate_patch_names; do
        git -C "$temporary_directory/llama.cpp" apply --check \
            "$patch_directory/$candidate_name"
        git -C "$temporary_directory/llama.cpp" apply \
            "$patch_directory/$candidate_name"
        git -C "$temporary_directory/llama.cpp" diff --check
        printf 'candidate_patch=%s applies=yes\n' "$candidate_name"
    done
    for candidate_digest_path in $candidate_digest_paths; do
        printf 'candidate_sha256=%s path=%s\n' \
            "$(sha256sum "$temporary_directory/llama.cpp/$candidate_digest_path" | cut -d ' ' -f 1)" \
            "$candidate_digest_path"
    done
else
    printf 'candidate_patches=not_run reason=QWEN_LLAMA_CANDIDATE_PATCHES_unset\n'
fi
