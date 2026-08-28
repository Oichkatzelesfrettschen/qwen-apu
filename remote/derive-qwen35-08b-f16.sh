#!/bin/sh
set -eu

# bartowski/Qwen_Qwen3.5-0.8B-GGUF publishes bf16 and no f16 model file, and
# RADV on Raven2 reports shaderFloat16 true while naming no bfloat16 extension,
# so the format the device advertises is produced here rather than fetched.
# llama-quantize accepts F16 as type 1 and rewrites the value type in place:
# the census reports the same 1,505,783,040 streamed bytes per token before and
# after, with 99.17% of bytes moving from BF16 to F16.
#
# evidence/representation-gate-16-bit.md measures the result at 15.68 decode
# tok/s against the Q8_0 rung's 20.15, which is 1.88 times the bytes for 1.29
# times the decode.

renice -n 19 -p $$ >/dev/null 2>&1 || true
ionice -c 3 -p $$ >/dev/null 2>&1 || true

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [DESTINATION_DIRECTORY]\n' "$0" >&2
    printf 'environment: QWEN_LLAMA_QUANTIZE\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
destination_directory=${1:-"${HOME:?}/models/Qwen3.5-0.8B-GGUF"}
source_path=$destination_directory/Qwen3.5-0.8B-bf16.gguf
artifact_path=$destination_directory/Qwen3.5-0.8B-F16.gguf
partial_path=$artifact_path.part
quantize=${QWEN_LLAMA_QUANTIZE:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-quantize"}
quantize_threads=${QWEN_QUANTIZE_THREADS:-2}

if [ ! -x "$quantize" ]; then
    printf 'llama-quantize is absent: %s\n' "$quantize" >&2
    printf 'remote/build-llama-vulkan.sh builds it\n' >&2
    exit 1
fi

# The source is the fetch script's verified artifact, so the derivation rests on
# a pinned revision and digest rather than on whatever file holds the name.
"$script_directory/download-qwen35-08b-bf16.sh" "$destination_directory"

if [ -f "$artifact_path" ]; then
    printf 'artifact_status=already_derived path=%s bytes=%s source=%s\n' \
        "$artifact_path" "$(wc -c <"$artifact_path")" "$(basename "$source_path")"
    exit 0
fi

rm -f "$partial_path"
nice -n 19 "$quantize" "$source_path" "$partial_path" F16 "$quantize_threads"

# A conversion that changed the layout would change what an ordinary load
# streams, and the value type is the only thing this conversion may change.
source_streamed=$(GGUF_PY_PATH=${GGUF_PY_PATH:-"${HOME:?}/src/llama.cpp-qwen-apu/gguf-py"} \
    "$script_directory/gguf-tensor-census.py" "$source_path" |
    awk -F'\t' '$1 == "streamed_bytes_per_token" { print $2; exit }')
derived_streamed=$(GGUF_PY_PATH=${GGUF_PY_PATH:-"${HOME:?}/src/llama.cpp-qwen-apu/gguf-py"} \
    "$script_directory/gguf-tensor-census.py" "$partial_path" |
    awk -F'\t' '$1 == "streamed_bytes_per_token" { print $2; exit }')
if [ "$source_streamed" != "$derived_streamed" ]; then
    printf 'derivation changed the streamed byte count: %s against %s\n' \
        "$source_streamed" "$derived_streamed" >&2
    rm -f "$partial_path"
    exit 1
fi

mv "$partial_path" "$artifact_path"
printf 'artifact_status=derived path=%s bytes=%s streamed_bytes_per_token=%s source=%s\n' \
    "$artifact_path" "$(wc -c <"$artifact_path")" "$derived_streamed" \
    "$(basename "$source_path")"
