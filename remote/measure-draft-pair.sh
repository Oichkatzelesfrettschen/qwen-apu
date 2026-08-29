#!/bin/sh
set -eu

# One draft pairing measured against a same-session control of the target alone.
#
# The pairing runs llama.cpp's standalone draft path: `--spec-type draft-simple`
# maps onto COMMON_SPECULATIVE_TYPE_DRAFT_SIMPLE in common/speculative.cpp, and
# tools/server/server-context.cpp builds a second common_params through
# common_base_params_to_speculative, which copies the draft path, devices,
# n_gpu_layers, tensor overrides, and cache types over the target's before
# common_speculative_init_result loads the draft as its own model with its own
# context. The draft context takes its depth from the target, since that
# constructor assigns `cparams.n_ctx = llama_n_ctx(ctx_tgt)`, so the harness
# names no draft depth.
#
# The arm order is control, pair, pair, control. This machine measures the same
# checkpoint under identical flags spanning 30.6% between sweeps, so a pairing
# is read against a control that met the same machine minutes earlier and the
# mirrored order charges any drift within the session to both halves.
#
# Every rate here is a served rate rather than a llama-bench rate, because
# acceptance exists only inside the served speculation path. The four reported
# speculation quantities come from one request: `timings.draft_n` and
# `timings.draft_n_accepted` are what tools/server/server-common.cpp emits when
# a request drafted anything, and verification steps follow exactly from
# `predicted_n - draft_n_accepted`, since each step emits one target token
# beside the draft tokens it accepted. Mean accepted length is then
# `predicted_n / steps`, which is the `1 + accepted / steps` the server prints
# on its own `draft acceptance` line.
#
# The harness owns the device for its whole run, so it refuses to start while a
# server answers on the appliance port.

if [ "$#" -ne 2 ]; then
    printf 'usage: %s PAIR_ID OUTPUT_DIRECTORY\n' "$0" >&2
    printf '  QWEN_PRODUCTION_BUILD_DIR names the promoted build (required)\n' >&2
    printf '  QWEN_MODELS_DIRECTORY names the model root, default $HOME/models\n' >&2
    exit 2
fi

pair_id=$1
output_directory=$2
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry_script=${QWEN_MODEL_REGISTRY_SCRIPT:-"$script_directory/model-registry.sh"}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
production_build_directory=${QWEN_PRODUCTION_BUILD_DIR:-}
server_relative_path=${QWEN_DRAFT_PAIR_SERVER_RELATIVE:-bin/llama-server}
server_port=${QWEN_DRAFT_PAIR_PORT:-8098}
predict_tokens=${QWEN_DRAFT_PAIR_PREDICT:-128}
sampling_seed=${QWEN_DRAFT_PAIR_SEED:-42}
thread_count=${QWEN_DRAFT_PAIR_THREADS:-1}
readiness_seconds=${QWEN_DRAFT_PAIR_READY_SECONDS:-180}
request_seconds=${QWEN_DRAFT_PAIR_REQUEST_SECONDS:-1800}
appliance_port=${QWEN_SERVER_PORT:-8080}

for positive_value in "$predict_tokens" "$thread_count" "$server_port"; do
    case $positive_value in
        '' | *[!0-9]* | 0)
            printf 'predict, threads, and port must be positive integers: %s\n' \
                "$positive_value" >&2
            exit 2
            ;;
    esac
done

if [ -z "$production_build_directory" ]; then
    printf 'QWEN_PRODUCTION_BUILD_DIR is required\n' >&2
    exit 2
fi
server_program=$production_build_directory/$server_relative_path
if [ ! -x "$server_program" ]; then
    printf 'the promoted build holds no executable server: %s\n' \
        "$server_program" >&2
    exit 1
fi

# A resident server holds the Vulkan carve-out and the workload lease, so a
# measurement started beside it reports contention rather than the pairing.
if curl --silent --fail --max-time 2 \
    "http://127.0.0.1:$appliance_port/health" >/dev/null 2>&1; then
    printf 'a server answers /health on port %s; run %s after qwen-teardown.sh\n' \
        "$appliance_port" "$(basename "$0")" >&2
    exit 1
fi

pair_row=$("$registry_script" draft-pair "$pair_id")
pair_field() {
    printf '%s\n' "$pair_row" | sed -n "s/^$1=//p"
}
target_model_id=$(pair_field target_model_id)
draft_model_id=$(pair_field draft_model_id)
pair_tier=$(pair_field tier)
spec_draft_n_max=$(pair_field spec_draft_n_max)
spec_draft_p_min=$(pair_field spec_draft_p_min)
draft_cache_type_k=$(pair_field draft_cache_type_k)
draft_cache_type_v=$(pair_field draft_cache_type_v)

# A quarantined pairing names a device failure or the absence of any safe tuple,
# and a measurement is the one thing that would construct that tuple again.
if [ "$pair_tier" = quarantine ]; then
    printf 'pair %s is tiered quarantine; read evidence/quarantine/ before measuring it\n' \
        "$pair_id" >&2
    exit 1
fi

registry_field() {
    "$registry_script" id "$1" "$2"
}
target_path=$models_directory/$(registry_field "$target_model_id" model_file)
draft_path=$models_directory/$(registry_field "$draft_model_id" model_file)
target_context=$(registry_field "$target_model_id" context_default)
target_batch=$(registry_field "$target_model_id" batch)
target_ubatch=$(registry_field "$target_model_id" ubatch)
target_cache_k=$(registry_field "$target_model_id" cache_type_k)
target_cache_v=$(registry_field "$target_model_id" cache_type_v)
target_flash=$(registry_field "$target_model_id" flash_attention)

for required_artifact in "$target_path" "$draft_path"; do
    if [ ! -f "$required_artifact" ]; then
        printf 'the pairing names an artifact this machine holds no file for: %s\n' \
            "$required_artifact" >&2
        exit 1
    fi
done

umask 077
mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)

{
    printf 'pair_id=%s\n' "$pair_id"
    printf 'target_model_id=%s\ndraft_model_id=%s\n' \
        "$target_model_id" "$draft_model_id"
    printf 'tier=%s\n' "$pair_tier"
    printf 'spec_draft_n_max=%s\nspec_draft_p_min=%s\n' \
        "$spec_draft_n_max" "$spec_draft_p_min"
    printf 'draft_cache_type_k=%s\ndraft_cache_type_v=%s\n' \
        "$draft_cache_type_k" "$draft_cache_type_v"
    printf 'context=%s\nbatch=%s\nubatch=%s\n' \
        "$target_context" "$target_batch" "$target_ubatch"
    printf 'cache_type_k=%s\ncache_type_v=%s\nflash_attention=%s\n' \
        "$target_cache_k" "$target_cache_v" "$target_flash"
    printf 'predict_tokens=%s\nseed=%s\nthreads=%s\n' \
        "$predict_tokens" "$sampling_seed" "$thread_count"
    printf 'production_build=%s\n' "$production_build_directory"
} >"$output_directory/inputs.txt"

server_pid=''
stop_server() {
    [ -n "$server_pid" ] || return 0
    kill -TERM "$server_pid" 2>/dev/null || true
    stop_iteration=0
    while [ "$stop_iteration" -lt 30 ]; do
        kill -0 "$server_pid" 2>/dev/null || { server_pid=''; return 0; }
        stop_iteration=$((stop_iteration + 1))
        sleep 1
    done
    kill -9 "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    server_pid=''
}
trap 'stop_server' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Placement is pinned the way qwen-capacity-policy.sh pins it for the serving
# path, on both models. common_base_params_to_speculative overwrites
# result.devices, result.n_gpu_layers, and result.tensor_buft_overrides with the
# draft's values, so the target's Vulkan0 placement reaches the draft only where
# the draft options name it. LLAMA_NO_CPU_FALLBACK reaches the
# llama-no-cpu-fallback patch the promoted build carries, so a fallback fails
# the load rather than serving a control and a pair from two devices.
start_server() {
    arm_mode=$1
    arm_log=$2

    if [ "$arm_mode" = pair ]; then
        LLAMA_NO_CPU_FALLBACK=1 "$server_program" \
            --model "$target_path" \
            --host 127.0.0.1 --port "$server_port" \
            --ctx-size "$target_context" \
            --batch-size "$target_batch" --ubatch-size "$target_ubatch" \
            --cache-type-k "$target_cache_k" \
            --cache-type-v "$target_cache_v" \
            --flash-attn "$target_flash" \
            --device Vulkan0 --split-mode none \
            --override-tensor '.*=Vulkan0' --fit off --n-gpu-layers all \
            --spec-type draft-simple \
            --spec-draft-model "$draft_path" \
            --spec-draft-n-max "$spec_draft_n_max" \
            --spec-draft-p-min "$spec_draft_p_min" \
            --spec-draft-type-k "$draft_cache_type_k" \
            --spec-draft-type-v "$draft_cache_type_v" \
            --spec-draft-device Vulkan0 \
            --spec-draft-ngl all \
            --spec-draft-override-tensor '.*=Vulkan0' \
            --parallel 1 --threads "$thread_count" \
            --threads-batch "$thread_count" \
            --no-context-shift --offline --log-verbosity 4 \
            >"$arm_log" 2>&1 &
    else
        LLAMA_NO_CPU_FALLBACK=1 "$server_program" \
            --model "$target_path" \
            --host 127.0.0.1 --port "$server_port" \
            --ctx-size "$target_context" \
            --batch-size "$target_batch" --ubatch-size "$target_ubatch" \
            --cache-type-k "$target_cache_k" \
            --cache-type-v "$target_cache_v" \
            --flash-attn "$target_flash" \
            --device Vulkan0 --split-mode none \
            --override-tensor '.*=Vulkan0' --fit off --n-gpu-layers all \
            --parallel 1 --threads "$thread_count" \
            --threads-batch "$thread_count" \
            --no-context-shift --offline --log-verbosity 4 \
            >"$arm_log" 2>&1 &
    fi
    server_pid=$!

    ready_iteration=0
    while [ "$ready_iteration" -lt "$readiness_seconds" ]; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            printf 'llama-server exited before readiness; see %s\n' "$arm_log" >&2
            return 1
        fi
        if curl --silent --fail --max-time 2 \
            "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
            return 0
        fi
        ready_iteration=$((ready_iteration + 1))
        sleep 1
    done
    printf 'llama-server did not answer /health within %s seconds\n' \
        "$readiness_seconds" >&2
    return 1
}

# Three prompts that decode past the prefill: a code continuation, a prose
# continuation, and an arithmetic chain. A drafter's acceptance depends on how
# predictable the continuation is, so one prompt reports one text rather than
# the pairing.
prompt_file=${QWEN_DRAFT_PAIR_PROMPTS:-"$output_directory/prompts.tsv"}
if [ ! -s "$prompt_file" ]; then
    cat >"$prompt_file" <<'PROMPTS'
code	Write a Python function that reads a CSV file of measurements, groups the rows by their first column, and returns the mean of the third column per group. Include the imports, error handling for a missing file, and a short docstring.
prose	Explain, in plain prose, why a laptop integrated GPU that shares its memory with the CPU reaches a different decode rate than a discrete card with the same nominal compute, and what a reader should measure to tell the two limits apart.
arithmetic	Start with 12. Add 7, multiply by 3, subtract 11, divide by 2, add 40, multiply by 2, subtract 19. Show the running value after every single operation on its own line, then state the final value.
PROMPTS
fi

run_arm() {
    arm_label=$1
    arm_mode=$2
    arm_directory=$output_directory/$arm_label
    mkdir -p "$arm_directory"
    printf 'arm_start label=%s mode=%s\n' "$arm_label" "$arm_mode"
    start_server "$arm_mode" "$arm_directory/server.log"
    while IFS='	' read -r prompt_name prompt_text; do
        [ -n "$prompt_name" ] || continue
        python3 - "$prompt_text" "$predict_tokens" "$sampling_seed" \
            >"$arm_directory/$prompt_name.request.json" <<'PY'
import json
import sys

print(json.dumps({
    "prompt": sys.argv[1],
    "n_predict": int(sys.argv[2]),
    "temperature": 0,
    "top_k": 1,
    "seed": int(sys.argv[3]),
    "cache_prompt": False,
    "stream": False,
}))
PY
        curl --silent --show-error --max-time "$request_seconds" \
            --header 'Content-Type: application/json' \
            --data @"$arm_directory/$prompt_name.request.json" \
            "http://127.0.0.1:$server_port/completion" \
            >"$arm_directory/$prompt_name.json" || true
    done <"$prompt_file"
    stop_server
    printf 'arm_done label=%s\n' "$arm_label"
}

run_arm control-open control
run_arm pair-first pair
run_arm pair-second pair
run_arm control-close control

python3 - "$output_directory" "$spec_draft_n_max" <<'PY'
import json
import os
import sys

directory = sys.argv[1]
n_max = int(sys.argv[2])
arms = (
    ('control-open', 'control'),
    ('pair-first', 'pair'),
    ('pair-second', 'pair'),
    ('control-close', 'control'),
)
prompts = ('code', 'prose', 'arithmetic')

FIELDS = ('arm', 'mode', 'prompt', 'predicted_n', 'decode_tok_s', 'drafted',
          'accepted', 'acceptance', 'verification_steps',
          'mean_accepted_length')


def load(arm, prompt):
    path = os.path.join(directory, arm, prompt + '.json')
    try:
        with open(path) as handle:
            return json.load(handle)
    except Exception:
        return None


def show(value, digits=3):
    return '-' if value is None else '{:.{}f}'.format(value, digits)


rows = []
for arm, mode in arms:
    for prompt in prompts:
        payload = load(arm, prompt)
        if payload is None:
            rows.append((arm, mode, prompt) + ('-',) * 7)
            continue
        timings = payload.get('timings') or {}
        predicted = timings.get('predicted_n')
        rate = timings.get('predicted_per_second')
        drafted = timings.get('draft_n')
        accepted = timings.get('draft_n_accepted')
        acceptance = (accepted / drafted) if drafted else None
        # Each verification step emits one target token beside the draft tokens
        # it accepted, so the step count follows exactly from the two the server
        # reports and needs no second source.
        steps = None
        mean_length = None
        if predicted is not None and accepted is not None:
            steps = predicted - accepted
            if steps > 0:
                mean_length = predicted / steps
        rows.append((
            arm, mode, prompt,
            '-' if predicted is None else str(predicted),
            show(rate, 2),
            '-' if drafted is None else str(drafted),
            '-' if accepted is None else str(accepted),
            show(acceptance),
            '-' if steps is None else str(steps),
            show(mean_length, 2),
        ))

with open(os.path.join(directory, 'arms.tsv'), 'w') as handle:
    handle.write('\t'.join(FIELDS) + '\n')
    for row in rows:
        handle.write('\t'.join(row) + '\n')


def paired_mean(mode):
    values = [float(row[4]) for row in rows if row[1] == mode and row[4] != '-']
    return sum(values) / len(values) if values else None


# A pair arm that drafted nothing is an incomplete measurement rather than a
# slow one. server-common.cpp adds draft_n and draft_n_accepted only where the
# request drafted something, and server-context.cpp reaches that state two ways:
# a context whose common_context_can_seq_rm answers
# COMMON_CONTEXT_SEQ_RM_TYPE_NO skips common_speculative_init outright, and a
# throw from it -- which is what the vocabulary check raises -- is caught,
# logged, and leaves the server decoding unspeculated. Both produce a plausible
# rate against a control measuring the same thing, so the absence ends the run
# rather than promoting one half to a completed sweep.
incomplete = sorted({row[0] for row in rows
                     if row[1] == 'pair' and row[5] == '-'})
summary = os.path.join(directory, 'summary.txt')
if incomplete:
    with open(summary, 'w') as handle:
        handle.write('draft_n_max={}\n'.format(n_max))
        handle.write('state=failed\n')
        handle.write('reason=draft_absent\n')
        handle.write('arms={}\n'.format(','.join(incomplete)))
    print(open(summary).read(), end='')
    sys.stderr.write(
        'a pair arm reported no drafted tokens; read that arm server.log for '
        'the speculative decoding line\n')
    sys.exit(1)

control_mean = paired_mean('control')
pair_mean = paired_mean('pair')
ratio = (pair_mean / control_mean) if control_mean else None
with open(summary, 'w') as handle:
    handle.write('draft_n_max={}\n'.format(n_max))
    handle.write('state=completed\n')
    handle.write('control_mean_decode_tok_s={}\n'.format(show(control_mean, 3)))
    handle.write('pair_mean_decode_tok_s={}\n'.format(show(pair_mean, 3)))
    handle.write('pair_over_control={}\n'.format(show(ratio, 4)))
print(open(summary).read(), end='')
PY

printf 'draft_pair_measurement=completed pair=%s output_directory=%s\n' \
    "$pair_id" "$output_directory"
