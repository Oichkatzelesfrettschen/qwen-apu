#!/bin/sh
set -eu

# Measure what the embedded multi-token-prediction head buys on this APU.
# `--spec-type draft-mtp` needs no second checkpoint: common_speculative_init_
# result takes its `else if (spec_mtp)` branch and builds the draft context
# against the target model, llama_model::create_memory filters that context's
# KV cache to `il >= hparams.n_layer()` so it holds the one appended NextN
# block, and common_model_params_to_llama sets load_mtp, which clears the
# TENSOR_SKIP that makes an ordinary load report the block as unused.
#
# Every arm travels the guarded launch path, so a difference between two rows
# is a difference between two speculation settings rather than between two
# serving policies. Sampling is greedy in every arm because speculative decoding
# reproduces the target-only token sequence exactly; a divergence is a
# correctness defect rather than a quality trade, and the recorded token IDs are
# what makes that checkable.

output_directory=${1:-"${HOME:?}/qwen-speculation-matrix"}
if [ "$#" -gt 0 ]; then
    shift
fi
# The first arm is the baseline the token-identity column compares against, so
# an invocation that names its own arms names an unspeculated one first.
if [ "$#" -eq 0 ]; then
    set -- S0:none:0:0:0 S1:draft-mtp:1:0:0
fi

for arm in "$@"; do
    field_count=$(printf '%s\n' "$arm" | awk -F: '{ print NF }')
    if [ "$field_count" -ne 5 ]; then
        printf 'usage: %s [OUTPUT_DIRECTORY [ARM ...]]\n' "$0" >&2
        printf 'ARM is LABEL:SPEC_TYPE:N_MAX:BACKEND_SAMPLING:DRAFT_BACKEND_SAMPLING, got %s\n' \
            "$arm" >&2
        exit 2
    fi
done

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
model_path=${QWEN_MODEL_PATH:-"${HOME:?}/models/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf"}
profile=${QWEN_PROFILE:-low-async}
port=${QWEN_SERVER_PORT:-8080}
endpoint=http://127.0.0.1:$port
predict_tokens=${QWEN_SPEC_PREDICT_TOKENS:-128}

if [ ! -f "$model_path" ]; then
    printf 'model does not exist: %s\n' "$model_path" >&2
    exit 2
fi

umask 077
mkdir -p "$output_directory"

# Three prompt shapes because acceptance is a property of the text, not of the
# head alone: code repeats structure a one-token draft predicts well, free prose
# repeats least, and arithmetic sits between them.
prompt_name_list='code prose arithmetic'
prompt_text_code='def fibonacci(n):\n    if n < 2:\n        return n\n    return'
prompt_text_prose='The two Vega compute units of a Raven2 accelerated processing unit share'
prompt_text_arithmetic='Q: A train leaves at 14:20 and arrives at 17:05. How long is the journey?\nA:'

run_arm() {
    arm_label=$1
    arm_spec_type=$2
    arm_n_max=$3
    arm_backend_sampling=$4
    arm_draft_backend_sampling=$5
    arm_directory=$output_directory/$arm_label

    mkdir -p "$arm_directory"

    spec_type_value=$arm_spec_type
    if [ "$spec_type_value" = none ]; then
        spec_type_value=''
    fi

    QWEN_MODEL_PATH=$model_path \
    QWEN_SPEC_TYPE=$spec_type_value \
    QWEN_SPEC_DRAFT_N_MAX=$arm_n_max \
    QWEN_BACKEND_SAMPLING=$arm_backend_sampling \
    QWEN_SPEC_BACKEND_SAMPLING=$arm_draft_backend_sampling \
        "$script_directory/qwen-launch.sh" "$profile" \
        >"$arm_directory/launch.txt" 2>&1 || {
            cat "$arm_directory/launch.txt" >&2
            return 1
        }

    # The output-limit clamp decides whether a draft of N tokens is verified in
    # one target pass or degenerates into N sequential ones, so the arm records
    # what the server actually chose rather than what the argument asked for.
    grep -E 'n_outputs_max|draft|spec' "$state_directory/server.log" \
        >"$arm_directory/startup-speculation.txt" 2>/dev/null || true

    for prompt_name in $prompt_name_list; do
        eval "prompt_text=\$prompt_text_$prompt_name"
        printf '{"prompt":"%s","n_predict":%s,"temperature":0,"top_k":1,"seed":42,"cache_prompt":false,"return_tokens":true,"stream":false}\n' \
            "$prompt_text" "$predict_tokens" \
            >"$arm_directory/$prompt_name.request.json"
        curl --silent --show-error --max-time 1800 \
            --header 'Content-Type: application/json' \
            --data @"$arm_directory/$prompt_name.request.json" \
            "$endpoint/completion" >"$arm_directory/$prompt_name.json" || true
    done

    curl --silent --fail "$endpoint/metrics" >"$arm_directory/metrics.txt" 2>/dev/null || true

    "$script_directory/summarize-probe.sh" "$state_directory/graphics-latency.log" \
        >"$arm_directory/probe-summary.txt" 2>/dev/null || true

    "$script_directory/qwen-teardown.sh" >"$arm_directory/teardown.txt" 2>&1 || true

    cp "$state_directory/server.log" "$arm_directory/server.log" 2>/dev/null || true
    printf 'label=%s spec_type=%s n_max=%s backend_sampling=%s draft_backend_sampling=%s\n' \
        "$arm_label" "$arm_spec_type" "$arm_n_max" \
        "$arm_backend_sampling" "$arm_draft_backend_sampling" \
        >"$arm_directory/arm.txt"
}

for arm in "$@"; do
    arm_label=${arm%%:*}
    arm_rest=${arm#*:}
    arm_spec_type=${arm_rest%%:*}
    arm_rest=${arm_rest#*:}
    arm_n_max=${arm_rest%%:*}
    arm_rest=${arm_rest#*:}
    arm_backend_sampling=${arm_rest%%:*}
    arm_draft_backend_sampling=${arm_rest#*:}

    printf 'arm_start label=%s spec_type=%s n_max=%s\n' \
        "$arm_label" "$arm_spec_type" "$arm_n_max"
    run_arm "$arm_label" "$arm_spec_type" "$arm_n_max" \
        "$arm_backend_sampling" "$arm_draft_backend_sampling"
    printf 'arm_done label=%s\n' "$arm_label"
done

python3 - "$output_directory" "$@" <<'PY'
import json, os, sys

directory = sys.argv[1]
arms = sys.argv[2:]
prompts = ('code', 'prose', 'arithmetic')

def load(arm, name):
    path = os.path.join(directory, arm, name + '.json')
    try:
        with open(path) as handle:
            return json.load(handle)
    except Exception:
        return None

baseline_tokens = {}
rows = []
for arm in arms:
    label = arm.split(':', 1)[0]
    for prompt in prompts:
        payload = load(label, prompt)
        if payload is None:
            rows.append((label, prompt, None, None, None, None, 'no response'))
            continue
        timings = payload.get('timings') or {}
        tokens = payload.get('tokens') or []
        draft_n = timings.get('draft_n')
        draft_accepted = timings.get('draft_n_accepted')
        acceptance = (draft_accepted / draft_n) if draft_n else None
        if label == arms[0].split(':', 1)[0]:
            baseline_tokens[prompt] = tokens
            identical = 'baseline'
        else:
            identical = 'match' if tokens == baseline_tokens.get(prompt) else 'DIVERGENT'
        rows.append((
            label, prompt,
            timings.get('predicted_n'),
            timings.get('predicted_per_second'),
            draft_n, acceptance, identical,
        ))

def show(value, fmt='{:.2f}'):
    return '-' if value is None else fmt.format(value)

print('| arm | prompt | tokens | decode tok/s | drafted | acceptance | token IDs |')
print('| --- | --- | ---: | ---: | ---: | ---: | --- |')
for label, prompt, n, tps, draft_n, acceptance, identical in rows:
    print('| {} | {} | {} | {} | {} | {} | {} |'.format(
        label, prompt,
        '-' if n is None else n,
        show(tps),
        '-' if draft_n is None else draft_n,
        '-' if acceptance is None else '{:.3f}'.format(acceptance),
        identical))

with open(os.path.join(directory, 'matrix.md'), 'w') as handle:
    handle.write('| arm | prompt | tokens | decode tok/s | drafted | acceptance | token IDs |\n')
    handle.write('| --- | --- | ---: | ---: | ---: | ---: | --- |\n')
    for label, prompt, n, tps, draft_n, acceptance, identical in rows:
        handle.write('| {} | {} | {} | {} | {} | {} | {} |\n'.format(
            label, prompt,
            '-' if n is None else n,
            show(tps),
            '-' if draft_n is None else draft_n,
            '-' if acceptance is None else '{:.3f}'.format(acceptance),
            identical))
PY

printf 'speculation_matrix=completed output_directory=%s\n' "$output_directory"
