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

verify_source dfac33fe7fd487fc136e2915de7d5c146a3921b231ffef55877c6dd9e4f2c164 \
    ggml/src/ggml-vulkan/ggml-vulkan.cpp
verify_source 16abd2face079cad962bb722026d7418e65de67c18c1e1f954df733c1598a70a \
    ggml/src/ggml-vulkan/ggml-vulkan-pacing.h
verify_source 4b8befd927e9b0c83cfc7cfe843d2f853a9a9db7f6a55c147ffcd4129afd95f8 \
    ggml/src/ggml-vulkan/ggml-vulkan-submit-limit.h
verify_source ac957254c09afda811983801e7dd59d7e4829d40e572804ea7e23dadba521867 \
    ggml/src/ggml-vulkan/ggml-vulkan-submit-trace.h
verify_source ecc818cdce4a7265f6f932962c325a582f42b91cb2661916fa28b5a79a49d1ad \
    src/llama-context.cpp
verify_source d0d6c8725891ac4baf68fd947ab4be75cc93ba37b1e988ca1c556881a49d0abc \
    src/llama-model-loader.cpp
verify_source d2d5cb43a83c6b2b459b85f2df181a3d976efcaef351e5cbc6b418ba839390e3 \
    tools/server/server.cpp
verify_source 3744317beb622feff234e5b7a615c50665579f34ce49921e324bcd418fb3a58a \
    tools/server/server-context.cpp

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
