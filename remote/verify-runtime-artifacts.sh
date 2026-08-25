#!/bin/sh
set -eu

if [ "$#" -gt 2 ]; then
    printf 'usage: %s [BINARY_DIRECTORY] [MODEL_PATH]\n' "$0" >&2
    exit 2
fi

if [ "${QWEN_ONE_CORE_ACTIVE:-0}" != 1 ]; then
    renice -n 19 -p $$ >/dev/null
    QWEN_ONE_CORE_ACTIVE=1 exec taskset -c 0 ionice -c 3 "$0" "$@"
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)
binary_directory=${1:-"$repository_directory/artifacts/bin"}
model_path=${2:-"${HOME:?}/models/Qwen3.5-4B-GGUF/Qwen3.5-4B-Q4_K_M.gguf"}

verify_artifact() {
    artifact_path=$1
    expected_bytes=$2
    expected_sha256=$3
    if [ ! -f "$artifact_path" ]; then
        printf 'artifact is missing: %s\n' "$artifact_path" >&2
        exit 1
    fi
    actual_bytes=$(stat -c %s "$artifact_path")
    actual_sha256=$(sha256sum "$artifact_path" | cut -d ' ' -f 1)
    if [ "$actual_bytes" -ne "$expected_bytes" ] || \
       [ "$actual_sha256" != "$expected_sha256" ]; then
        printf 'artifact mismatch: %s expected %s/%s found %s/%s\n' \
            "$artifact_path" "$expected_bytes" "$expected_sha256" \
            "$actual_bytes" "$actual_sha256" >&2
        exit 1
    fi
    printf 'artifact=accepted path=%s bytes=%s sha256=%s\n' \
        "$artifact_path" "$actual_bytes" "$actual_sha256"
}

verify_artifact "$binary_directory/llama-server" 57467440 \
    9c31bf00b548ac1bc7f7cb775afb3e06ee0d20eb0293ebaf2e0b6d20a5a1020f
verify_artifact "$binary_directory/llama-cli" 57639736 \
    74afcb3bad505d181989fa4daf715525db1b0b2e4d2fe240d3542ad4c961a788
verify_artifact "$model_path" 2740937888 \
    00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4
