#!/bin/sh
set -eu

if [ "$#" -gt 2 ]; then
    printf 'usage: %s [BINARY_DIRECTORY] [MODEL_PATH]\n' "$0" >&2
    exit 2
fi

renice -n 19 -p $$ >/dev/null
taskset -pc 0 $$ >/dev/null
ionice -c 3 -p $$

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

verify_artifact "$binary_directory/llama-server" 57475792 \
    3d5b158160b08cf897bb05b47186a13f67e8a17def31012f2f8282f12e95cb08
verify_artifact "$binary_directory/llama-cli" 57643992 \
    83cc86e271b7fe784d208c00ca22d1fe6875e7a956790d16b55a9e617d23cc5b
verify_artifact "$model_path" 2740937888 \
    00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4
