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

verify_artifact "$binary_directory/llama-server" 57480016 \
    2951bdfe1b5c0ecae49c75f38c64f16ba0cce6e57b05f081ffa7c50355aecc13
verify_artifact "$binary_directory/llama-cli" 57648216 \
    213c779a9bee040381754b97585ff5115a4bc1bb0e6ce230ac923f453d190cdc
verify_artifact "$model_path" 2740937888 \
    00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4
