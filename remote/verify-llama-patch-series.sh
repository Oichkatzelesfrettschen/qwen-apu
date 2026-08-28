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
for patch_name in \
    llama-vulkan-low-priority.patch \
    llama-no-cpu-fallback.patch \
    llama-vulkan-duty-cycle.patch \
    llama-vulkan-runtime-submit-limit.patch \
    llama-vulkan-submit-trace.patch; do
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

verify_source 3c39e13043f1c949d3a75bbb198285e943bc832810232b25883c82cfcc7e43a4 \
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
printf 'patch_series=accepted commit=%s\n' "$expected_commit"
