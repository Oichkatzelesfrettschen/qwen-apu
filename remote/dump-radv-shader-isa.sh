#!/bin/sh
set -eu

# One standalone run of a llama-server build under RADV_DEBUG=shaders,shaderstats,
# retaining the disassembly and the executable statistics RADV prints for every
# compute pipeline it compiles. E1 in evidence/raven2-vulkan-kernel-census/
# decode-decomposition.md needs the pinned mul_mat_vec_q4_k_f16 shader's own
# instruction count in place of the 77-operation estimate the document derives
# from the GLSL source, and this script is that measurement's collector rather
# than its reader: remote/summarize-radv-isa.py turns the retained log into one
# row per shader.
#
# The run mirrors the low-async serving profile's own exports rather than
# invoking remote/radv-low-priority-env.sh, because that script's scrub unsets
# RADV_DEBUG before its profile case runs and RADV_DEBUG is this script's whole
# point. remote/run-raven2-vulkan-kernel-census.sh binds the census I0 arm to
# context 24576, batch 128, ubatch 32, cache-type-k q8_0, cache-type-v q4_0,
# and flash attention on; the invocation below states that tuple literally
# rather than reading it from a model registry row, so this diagnostic runs
# against any server and model path the caller names.
#
# This is a standalone diagnostic, not a served launch: no tmux session, no
# session.status, no workload lease, and no launch chain own this process. The
# script starts the server directly, waits for /health, drives one 8-token
# completion at temperature 0, ends the server with SIGTERM, and waits for it
# to exit.

usage() {
    printf 'usage: %s OUTPUT_DIR SERVER MODEL_PATH\n' "$0" >&2
}

if [ "$#" -ne 3 ]; then
    usage
    exit 2
fi

output_directory=$1
server_executable=$2
model_path=$3

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
summarizer=$script_directory/summarize-radv-isa.py

# The census runner and the served-decode harness both bind their device work
# to the measured host, because a device probe run over an inherited SSH
# session against the wrong machine proves nothing about the appliance's own
# gfx902 part.
host_shortname=$(hostname -s 2>/dev/null | LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
if [ "$host_shortname" != hp14-dk1xxx ]; then
    printf 'this diagnostic runs on the measured host hp14-dk1xxx: observed=%s\n' \
        "${host_shortname:--}" >&2
    exit 1
fi

if [ -e "$output_directory" ]; then
    printf 'output directory already exists, refusing to overwrite: %s\n' \
        "$output_directory" >&2
    exit 1
fi

if [ ! -x "$server_executable" ] || [ -d "$server_executable" ]; then
    printf 'server is not an executable file: %s\n' "$server_executable" >&2
    exit 1
fi

if [ ! -r "$model_path" ] || [ -d "$model_path" ]; then
    printf 'model path is not a readable file: %s\n' "$model_path" >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    printf 'curl is required to drive the completion request\n' >&2
    exit 1
fi

server_port=8080
if command -v ss >/dev/null 2>&1 &&
    ss -ltn "sport = :$server_port" 2>/dev/null | grep -q ":$server_port"; then
    printf 'port %s already has a listener; tear the appliance down first\n' \
        "$server_port" >&2
    exit 1
fi

mkdir -p -- "$output_directory/isa"
log_file=$output_directory/radv-shaders.log
request_file=$output_directory/request.json
response_file=$output_directory/response.json

radv_icd=${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
if [ ! -r "$radv_icd" ]; then
    printf 'RADV ICD is not readable: %s\n' "$radv_icd" >&2
    exit 1
fi

printf '{"model":"qwen-apu","messages":[{"role":"user","content":"Write one paragraph about tides."}],"max_tokens":8,"temperature":0,"top_k":1,"seed":1,"ignore_eos":true,"chat_template_kwargs":{"enable_thinking":false}}' \
    >"$request_file"

server_pid=''
teardown_ran=0
teardown_server() {
    if [ "$teardown_ran" -eq 1 ]; then
        return 0
    fi
    teardown_ran=1
    if [ -n "$server_pid" ] && kill -0 "$server_pid" 2>/dev/null; then
        kill -TERM "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
}
trap teardown_server EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# The exports below reproduce what the low-async profile leaves set after
# radv-low-priority-env.sh scrubs the ambient Vulkan and RADV environment and
# runs its case statement: VK_DRIVER_FILES and VK_ICD_FILENAMES name the RADV
# ICD, GGML_VK_LOW_PRIORITY and LLAMA_NO_CPU_FALLBACK are always on, and
# low-async exports GGML_VK_MAX_NODES_PER_SUBMIT=16 alone, leaving
# GGML_VK_SERIALIZE_SUBMISSIONS absent rather than zero. RADV_DEBUG is the one
# name that profile always unsets, so it is exported here instead of through
# that script.
(
    VK_DRIVER_FILES=$radv_icd
    VK_ICD_FILENAMES=$radv_icd
    GGML_VK_LOW_PRIORITY=1
    LLAMA_NO_CPU_FALLBACK=1
    GGML_VK_MAX_NODES_PER_SUBMIT=16
    RADV_DEBUG=shaders,shaderstats
    export VK_DRIVER_FILES VK_ICD_FILENAMES GGML_VK_LOW_PRIORITY \
        LLAMA_NO_CPU_FALLBACK GGML_VK_MAX_NODES_PER_SUBMIT RADV_DEBUG
    exec "$server_executable" \
        --host 127.0.0.1 \
        --port "$server_port" \
        --model "$model_path" \
        --ctx-size 24576 \
        --batch-size 128 \
        --ubatch-size 32 \
        --cache-type-k q8_0 \
        --cache-type-v q4_0 \
        --flash-attn on \
        --device Vulkan0 \
        --n-gpu-layers all \
        --override-tensor '.*=Vulkan0' \
        --threads 1
) >"$log_file" 2>&1 &
server_pid=$!

ready_attempts=1200
attempt=0
while [ "$attempt" -lt "$ready_attempts" ]; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
        printf 'server exited before answering /health\n' >&2
        cat "$log_file" >&2
        exit 1
    fi
    if curl --silent --fail "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done
if [ "$attempt" -ge "$ready_attempts" ]; then
    printf 'server did not answer /health within %s seconds\n' \
        "$((ready_attempts / 10))" >&2
    exit 1
fi

set +e
curl --silent --show-error --fail-with-body --max-time 300 \
    --header 'Content-Type: application/json' \
    --data @"$request_file" \
    "http://127.0.0.1:$server_port/v1/chat/completions" >"$response_file"
completion_status=$?
set -e
if [ "$completion_status" -ne 0 ]; then
    printf 'the completion request failed with status %s\n' "$completion_status" >&2
    cat "$log_file" >&2
    exit 1
fi

teardown_server

python3 "$summarizer" "$log_file" "$output_directory/isa" "$output_directory/isa-index.tsv"

printf 'radv_shader_isa_dump=complete log=%s isa_directory=%s index=%s\n' \
    "$log_file" "$output_directory/isa" "$output_directory/isa-index.tsv"
