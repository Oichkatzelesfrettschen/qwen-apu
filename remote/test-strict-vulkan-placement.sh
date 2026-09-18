#!/bin/sh
set -eu

if [ "$#" -ne 4 ] || [ "$1" != "--llama-server" ] || [ "$3" != "--model" ]; then
    printf 'usage: %s --llama-server PATH --model PATH\n' "$0" >&2
    exit 2
fi

llama_server_binary=$2
model_path=$4

if [ ! -x "$llama_server_binary" ]; then
    printf 'llama-server is not executable: %s\n' "$llama_server_binary" >&2
    exit 2
fi
if [ ! -f "$model_path" ]; then
    printf 'model is not a regular file: %s\n' "$model_path" >&2
    exit 2
fi

renice -n 19 -p $$ >/dev/null
taskset -pc 0 $$ >/dev/null
ionice -c 3 -p $$

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
wrapper=$script_directory/radv-low-priority-env.sh
temporary_directory=$(mktemp -d)
evidence_directory=${QWEN_TEST_EVIDENCE_DIRECTORY:-}
server_pid=""

cleanup() {
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    if [ -n "$evidence_directory" ]; then
        mkdir -p "$evidence_directory"
        cp -f "$temporary_directory"/* "$evidence_directory"/ 2>/dev/null || true
    fi
    rm -rf "$temporary_directory"
}
trap cleanup EXIT HUP INT TERM

set +e
env LLAMA_NO_CPU_FALLBACK=1 DISPLAY= WAYLAND_DISPLAY= \
    timeout --signal=TERM 10 "$llama_server_binary" \
        --model "$model_path" --fit off --ctx-size 128 --parallel 1 \
        --threads 1 --threads-batch 1 --batch-size 128 --ubatch-size 128 \
        --no-ui --host 127.0.0.1 -lv 10 \
        --device none --n-gpu-layers 0 --port 18084 \
        >"$temporary_directory/cpu-tensor.log" 2>&1
tensor_status=$?
set -e
if [ "$tensor_status" -eq 0 ] || [ "$tensor_status" -eq 124 ]; then
    printf 'CPU tensor placement was not rejected: status=%s\n' "$tensor_status" >&2
    exit 1
fi
grep -F 'selected CPU buffer' "$temporary_directory/cpu-tensor.log" >/dev/null

set +e
QWEN_VULKAN_PROFILE=paced-60 "$wrapper" \
    timeout --signal=TERM 10 "$llama_server_binary" \
    --model "$model_path" --fit off --ctx-size 128 --parallel 1 \
    --threads 1 --threads-batch 1 --batch-size 128 --ubatch-size 128 \
    --no-ui --host 127.0.0.1 -lv 10 \
    --device Vulkan0 --split-mode none --n-gpu-layers all \
    --port 18085 >"$temporary_directory/cpu-graph.log" 2>&1
graph_status=$?
set -e
if [ "$graph_status" -eq 0 ] || [ "$graph_status" -eq 124 ]; then
    printf 'CPU graph placement was not rejected: status=%s\n' "$graph_status" >&2
    exit 1
fi
grep -E 'CPU fallback rejected for graph node [^ ]+ \(GET_ROWS\)' \
    "$temporary_directory/cpu-graph.log" >/dev/null

positive_log=$temporary_directory/vulkan-positive.log
response_path=$temporary_directory/response.json
QWEN_VULKAN_PROFILE=paced-60 "$wrapper" "$llama_server_binary" \
    --model "$model_path" --fit off --ctx-size 128 --parallel 1 \
    --threads 1 --threads-batch 1 --batch-size 128 --ubatch-size 128 \
    --no-ui --host 127.0.0.1 -lv 10 \
    --device Vulkan0 --split-mode none --n-gpu-layers all \
    --override-tensor '.*=Vulkan0' --port 18086 >"$positive_log" 2>&1 &
server_pid=$!

server_ready=0
attempt=0
while [ "$attempt" -lt 300 ]; do
    if curl --silent --fail http://127.0.0.1:18086/health >/dev/null 2>&1; then
        server_ready=1
        break
    fi
    if ! kill -0 "$server_pid" 2>/dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done
if [ "$server_ready" -ne 1 ]; then
    printf 'strict Vulkan server did not become ready\n' >&2
    exit 1
fi

http_status=$(
    printf '%s\n' '{"prompt":"Hello","n_predict":2,"temperature":0}' |
        curl --silent --show-error --output "$response_path" \
            --write-out '%{http_code}' -H 'Content-Type: application/json' \
            --data-binary @- http://127.0.0.1:18086/completion
)

kill "$server_pid" 2>/dev/null || true
wait "$server_pid" 2>/dev/null || true
server_pid=""

if [ "$http_status" != 200 ]; then
    printf 'strict Vulkan completion returned HTTP %s\n' "$http_status" >&2
    exit 1
fi
# Each requirement names itself on refusal. A bare `grep` under `set -e` ends
# this script with status 1, no message, and an empty log, which is how a model
# that loads and serves but returns one empty token read as an unexplained
# rejection: the summary's detail column stayed blank and the cause took a
# `sh -x` run to find. A refusal states what it required and what it found.
require_line() {
    require_description=$1
    require_pattern=$2
    require_file=$3
    if grep -F "$require_pattern" "$require_file" >/dev/null; then
        return 0
    fi
    printf 'strict Vulkan placement refused: %s\n' "$require_description" >&2
    printf '  required: %s\n' "$require_pattern" >&2
    printf '  in: %s\n' "$require_file" >&2
    exit 1
}

if ! grep -F '"tokens_predicted":2' "$response_path" >/dev/null; then
    observed_tokens=$(sed -n 's/.*"tokens_predicted":\([0-9][0-9]*\).*/\1/p' \
        "$response_path" | sed -n 1p)
    printf 'strict Vulkan placement refused: the completion predicted %s tokens rather than 2\n' \
        "${observed_tokens:-no}" >&2
    printf '  a model that loads and serves can still emit an immediate end of sequence\n' >&2
    exit 1
fi
require_line 'the model buffer is not on Vulkan0' 'Vulkan0 model buffer size' "$positive_log"
require_line 'the KV buffer is not on Vulkan0' 'Vulkan0 KV buffer size' "$positive_log"
require_line 'the compute buffer is not on Vulkan0' 'Vulkan0 compute buffer size' "$positive_log"
require_line 'the queue priority is not LOW' 'global queue priority = LOW' "$positive_log"
require_line 'the duty cycle is not 60%' 'duty cycle = 60%' "$positive_log"
if grep -F 'CPU fallback rejected' "$positive_log" >/dev/null; then
    printf 'strict Vulkan completion reached a CPU graph node\n' >&2
    exit 1
fi

printf 'cpu_tensor_rejection=accepted cpu_graph_rejection=accepted strict_vulkan_completion=accepted duty_cycle=60 low_priority=accepted\n'
