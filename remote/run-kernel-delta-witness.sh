#!/bin/sh
set -eu
# A kernel that got shorter is admitted on what it computes, not on its
# bracket. The kernel-delta comparison reads reply content and token count,
# which two token sequences can share, so this witness asks the two exact
# binaries the sharper question: over six state-carrying prompts at
# temperature 0, top_k 1, a fixed seed, ignore_eos, and cache_prompt off,
# does the candidate return the control's exact token-id array, and how far
# does the selected token's log-probability move? Each binary starts twice in
# the order control, candidate, candidate, control, and each start answers
# every prompt twice, so self-consistency inside one binary is read beside
# the cross-binary comparison: a control disagreeing with itself reproduces a
# nondeterminism the candidate cannot be blamed for.
#
# The token ids are compared exactly. The log-probabilities are reported as
# the largest absolute difference over every generated token, and the
# registered bound is 1e-3 nat: the candidate reorders a floating-point
# accumulation, so the last bits may move while the argmax stays, and a
# difference past that bound names a numeric change rather than reordering.
#
# The servers are started directly, the way run-graph-alias-ab.sh starts its
# arms, with the tuple the registry names and every buffer required on
# Vulkan0, and never while the appliance serves.
#
# usage: run-kernel-delta-witness.sh CONTROL_SERVER CANDIDATE_SERVER MODEL_ID OUTPUT_DIR
if [ "$#" -ne 4 ]; then
    printf 'usage: %s CONTROL_SERVER CANDIDATE_SERVER MODEL_ID OUTPUT_DIR\n' "$0" >&2
    exit 2
fi
control_server=$1
candidate_server=$2
model_id=$3
output_directory=$4
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry_script=${QWEN_MODEL_REGISTRY_SCRIPT:-"$script_directory/model-registry.sh"}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
server_port=${QWEN_WITNESS_PORT:-8099}
run_count=${QWEN_WITNESS_RUNS:-2}
predict_tokens=${QWEN_WITNESS_PREDICT:-128}
sampling_seed=${QWEN_WITNESS_SEED:-1}
thread_count=${QWEN_WITNESS_THREADS:-2}
readiness_seconds=${QWEN_WITNESS_READY_SECONDS:-180}
request_seconds=${QWEN_WITNESS_REQUEST_SECONDS:-900}
logprob_bound=${QWEN_WITNESS_LOGPROB_BOUND:-0.001}
appliance_port=${QWEN_SERVER_PORT:-8080}

for server in "$control_server" "$candidate_server"; do
    if [ ! -x "$server" ]; then
        printf 'server is not executable: %s\n' "$server" >&2
        exit 2
    fi
done
if pgrep -x llama-server >/dev/null 2>&1; then
    printf 'llama-server is running; run %s after qwen-teardown.sh\n' "$0" >&2
    exit 2
fi
for port in "$appliance_port" "$server_port"; do
    if curl --silent --fail --max-time 2 "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
        printf 'a server answers /health on port %s\n' "$port" >&2
        exit 2
    fi
done
umask 077
if [ -e "$output_directory" ]; then
    printf 'output directory must be absent: %s\n' "$output_directory" >&2
    exit 2
fi
mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)

registry_field() {
    "$registry_script" id "$1" "$2"
}
model_file=$(registry_field "$model_id" model_file)
model_path=$models_directory/$model_file
model_context=$(registry_field "$model_id" context_default)
model_batch=$(registry_field "$model_id" batch)
model_ubatch=$(registry_field "$model_id" ubatch)
model_cache_k=$(registry_field "$model_id" cache_type_k)
model_cache_v=$(registry_field "$model_id" cache_type_v)
model_flash_attention=$(registry_field "$model_id" flash_attention)
if [ ! -r "$model_path" ]; then
    printf 'model is unreadable: %s\n' "$model_path" >&2
    exit 2
fi

prompt_file=$output_directory/prompts.tsv
cat >"$prompt_file" <<'PROMPTS'
accumulator	Start with the number 7. Apply these operations in order and show the running total after every single step: add 13, multiply by 3, subtract 8, divide by 2, add 45, multiply by 4, subtract 111, add 19, multiply by 2, subtract 37, add 88, divide by 5. State the value after each operation on its own line, then give the final value.
stack	Simulate a stack, one operation per line, printing the complete stack contents after every operation: push A, push B, push C, pop, push D, push E, pop, pop, push F, push G, push H, pop, push I, pop, pop, push J. Then report the final stack from bottom to top and the full sequence of popped values in order.
list-transform	Begin with the list [4, 9, 2, 7, 1, 8, 3, 6, 5]. Apply each rule to the result of the previous rule and print the whole list after each rule: double every element, remove every element above 15, append the sum of the current list, sort ascending, subtract the smallest element from every element, reverse the list, append the count of nonzero elements. Show every intermediate list.
variable-trace	Trace this program line by line and print the value of every variable after each line: a = 3; b = a + 4; c = b * 2; a = c - b; d = a + c; b = d - a; c = b + d; a = c - d; d = a * b; b = d - c; c = a + b; a = c * 2; b = a - d. After the trace, give the final values of a, b, c, and d.
state-machine	A machine has states S0, S1, S2, S3 and transitions: on 0 go S0->S1, S1->S2, S2->S3, S3->S0; on 1 go S0->S2, S1->S0, S2->S1, S3->S2. Starting in S0, process the input 0110100111010011 one symbol at a time. Print the state after each symbol, then report the final state and how many times each state was visited.
constraints	Five houses in a row are numbered 1 to 5. Each has one colour from red, blue, green, white, yellow and one occupant from Ana, Ben, Cara, Dan, Eve. Apply these clues one at a time, and after each clue print everything you have established so far: the red house is immediately left of the green house; Ana lives in the blue house; Cara lives in house 1; the yellow house is house 5; Ben lives immediately right of the white house; Dan does not live in house 3; the green house is house 4. Then give the complete assignment.
PROMPTS

request_builder=$output_directory/build-request.py
cat >"$request_builder" <<'PYTHON'
import json
import sys

prompt_path, predict, seed = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
with open(prompt_path, "r", encoding="utf-8") as handle:
    prompt_text = handle.read()
json.dump(
    {
        "prompt": prompt_text,
        "n_predict": predict,
        "temperature": 0,
        "top_k": 1,
        "seed": seed,
        "ignore_eos": True,
        "cache_prompt": False,
        "return_tokens": True,
        "n_probs": 1,
        "stream": False,
    },
    sys.stdout,
)
PYTHON

# One line per generated token: the id and the selected token's log-probability
# as the server reports it, so the two files a comparison reads are the
# record and not a re-derivation.
token_reader=$output_directory/read-tokens.py
cat >"$token_reader" <<'PYTHON'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
tokens = payload.get("tokens")
probabilities = payload.get("completion_probabilities")
if not isinstance(tokens, list) or not tokens:
    sys.stderr.write("response carries no token array\n")
    raise SystemExit(1)
if not isinstance(probabilities, list) or len(probabilities) != len(tokens):
    sys.stderr.write("response carries no probability entry per token\n")
    raise SystemExit(1)
for token_id, entry in zip(tokens, probabilities):
    if not isinstance(token_id, int) or entry.get("id") != token_id:
        sys.stderr.write("token array and probability entries disagree\n")
        raise SystemExit(1)
    print(f"{token_id}\t{float(entry['logprob']):.9g}")
PYTHON

server_pid=''
stop_server() {
    [ -n "$server_pid" ] || return 0
    kill "$server_pid" 2>/dev/null || true
    wait_iteration=0
    while [ "$wait_iteration" -lt 60 ] && kill -0 "$server_pid" 2>/dev/null; do
        wait_iteration=$((wait_iteration + 1))
        sleep 1
    done
    kill -9 "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    server_pid=''
}
trap 'stop_server' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

start_server() {
    arm_server=$1
    arm_log=$2
    env -u GGML_VK_DISABLE_GRAPH_OPTIMIZE LLAMA_NO_CPU_FALLBACK=1 \
        "$arm_server" \
        --model "$model_path" \
        --host 127.0.0.1 \
        --port "$server_port" \
        --ctx-size "$model_context" \
        --batch-size "$model_batch" \
        --ubatch-size "$model_ubatch" \
        --cache-type-k "$model_cache_k" \
        --cache-type-v "$model_cache_v" \
        --flash-attn "$model_flash_attention" \
        --device Vulkan0 \
        --split-mode none \
        --override-tensor '.*=Vulkan0' \
        --fit off \
        --n-gpu-layers all \
        --parallel 1 \
        --threads "$thread_count" \
        --threads-batch "$thread_count" \
        --no-context-shift \
        --offline \
        --log-verbosity 4 \
        >"$arm_log" 2>&1 &
    server_pid=$!
    ready_iteration=0
    while [ "$ready_iteration" -lt "$readiness_seconds" ]; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            printf 'llama-server exited before readiness; see %s\n' "$arm_log" >&2
            return 1
        fi
        if curl --silent --fail --max-time 2 "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
            for placement_line in 'Vulkan0 model buffer size' 'Vulkan0 KV buffer size' \
                'Vulkan0 compute buffer size'; do
                if ! grep -qF "$placement_line" "$arm_log"; then
                    printf 'placement=rejected missing=%s log=%s\n' "$placement_line" "$arm_log" >&2
                    return 1
                fi
            done
            return 0
        fi
        ready_iteration=$((ready_iteration + 1))
        sleep 1
    done
    printf 'llama-server stayed unready for %s seconds; see %s\n' "$readiness_seconds" "$arm_log" >&2
    return 1
}

{
    printf 'control_server\t%s\ncontrol_server_sha256\t%s\n' "$control_server" \
        "$(sha256sum "$control_server" | cut -d ' ' -f 1)"
    printf 'candidate_server\t%s\ncandidate_server_sha256\t%s\n' "$candidate_server" \
        "$(sha256sum "$candidate_server" | cut -d ' ' -f 1)"
    printf 'model_id\t%s\nmodel_path\t%s\nmodel_sha256\t%s\n' "$model_id" "$model_path" \
        "$(sha256sum "$model_path" | cut -d ' ' -f 1)"
    printf 'context\t%s\nbatch\t%s\nubatch\t%s\ncache_k\t%s\ncache_v\t%s\nflash_attention\t%s\n' \
        "$model_context" "$model_batch" "$model_ubatch" "$model_cache_k" "$model_cache_v" \
        "$model_flash_attention"
    printf 'runs_per_start\t%s\npredict_tokens\t%s\nseed\t%s\nthreads\t%s\nlogprob_bound\t%s\n' \
        "$run_count" "$predict_tokens" "$sampling_seed" "$thread_count" "$logprob_bound"
    printf 'arm_order\tC K K C\n'
} >"$output_directory/inputs.tsv"

slot=0
for arm in C K K C; do
    slot=$((slot + 1))
    case $arm in
        C) arm_server=$control_server ;;
        *) arm_server=$candidate_server ;;
    esac
    arm_directory=$output_directory/arms/$slot-$arm
    mkdir -p "$arm_directory"
    printf 'witness_arm=start slot=%s arm=%s server=%s\n' "$slot" "$arm" "$arm_server"
    start_server "$arm_server" "$arm_directory/server.log"
    run_index=1
    while [ "$run_index" -le "$run_count" ]; do
        while IFS="$(printf '\t')" read -r prompt_id prompt_text; do
            [ -n "$prompt_id" ] || continue
            prompt_directory=$arm_directory/$prompt_id
            mkdir -p "$prompt_directory"
            printf '%s' "$prompt_text" >"$prompt_directory/prompt.txt"
            python3 "$request_builder" "$prompt_directory/prompt.txt" "$predict_tokens" \
                "$sampling_seed" >"$prompt_directory/request.json"
            curl --silent --show-error --fail-with-body --max-time "$request_seconds" \
                --header 'Content-Type: application/json' \
                --data @"$prompt_directory/request.json" \
                "http://127.0.0.1:$server_port/completion" \
                >"$prompt_directory/response-run-$run_index.json"
            python3 "$token_reader" "$prompt_directory/response-run-$run_index.json" \
                >"$prompt_directory/tokens-run-$run_index.tsv"
        done <"$prompt_file"
        run_index=$((run_index + 1))
    done
    stop_server
    printf 'witness_arm=completed slot=%s arm=%s\n' "$slot" "$arm"
done

# The comparison: every candidate sample against the first control start's
# first run per prompt, every sample against its own binary's first run for
# self-consistency, ids exactly and log-probabilities by their largest
# absolute difference.
python3 - "$output_directory" "$logprob_bound" >"$output_directory/summary.tsv" <<'PYTHON'
import glob
import os
import sys

root, bound = sys.argv[1], float(sys.argv[2])


def read(path):
    ids, logprobs = [], []
    with open(path) as handle:
        for line in handle:
            token_id, logprob = line.rstrip("\n").split("\t")
            ids.append(int(token_id))
            logprobs.append(float(logprob))
    return ids, logprobs


samples = {}
for path in sorted(glob.glob(os.path.join(root, "arms", "*", "*", "tokens-run-*.tsv"))):
    arm_directory, prompt_id, name = path.split(os.sep)[-3:]
    slot, arm = arm_directory.split("-", 1)
    run = name[len("tokens-run-"):-len(".tsv")]
    samples.setdefault(prompt_id, []).append((int(slot), arm, int(run), read(path)))

print("prompt\tcomparison\tsamples\tid_identity\tfirst_divergence\tmax_abs_logprob_delta\tverdict")
overall = "held"
for prompt_id, rows in sorted(samples.items()):
    rows.sort()
    reference = {"C": None, "K": None}
    for slot, arm, run, sample in rows:
        if reference[arm] is None:
            reference[arm] = sample
    for arm in ("C", "K"):
        same = [s for s in rows if s[1] == arm]
        identity, divergence, delta = "held", "-", 0.0
        for slot, _, run, (ids, logprobs) in same:
            ref_ids, ref_logprobs = reference[arm]
            if ids != ref_ids:
                identity = "differs"
                divergence = str(next(i for i in range(min(len(ids), len(ref_ids)) + 1)
                                      if i >= min(len(ids), len(ref_ids)) or ids[i] != ref_ids[i]))
            else:
                delta = max([delta] + [abs(a - b) for a, b in zip(logprobs, ref_logprobs)])
        verdict = "held" if identity == "held" and delta <= bound else "differs"
        if verdict != "held":
            overall = "differs"
        print(f"{prompt_id}\tself-{arm}\t{len(same)}\t{identity}\t{divergence}\t{delta:.3e}\t{verdict}")
    cross_rows = [s for s in rows if s[1] == "K"]
    ref_ids, ref_logprobs = reference["C"]
    identity, divergence, delta = "held", "-", 0.0
    for slot, _, run, (ids, logprobs) in cross_rows:
        if ids != ref_ids:
            identity = "differs"
            divergence = str(next(i for i in range(min(len(ids), len(ref_ids)) + 1)
                                  if i >= min(len(ids), len(ref_ids)) or ids[i] != ref_ids[i]))
        else:
            delta = max([delta] + [abs(a - b) for a, b in zip(logprobs, ref_logprobs)])
    verdict = "held" if identity == "held" and delta <= bound else "differs"
    if verdict != "held":
        overall = "differs"
    print(f"{prompt_id}\tcandidate-vs-control\t{len(cross_rows)}\t{identity}\t{divergence}\t{delta:.3e}\t{verdict}")
print(f"-\toverall\t-\t-\t-\t-\t{overall}")
PYTHON
overall=$(awk -F'\t' '$2 == "overall" { print $7 }' "$output_directory/summary.tsv")
printf 'witness=%s prompts=%s output=%s\n' "$overall" \
    "$(awk -F'\t' 'NR > 1 && $2 == "candidate-vs-control" { n++ } END { print n + 0 }' "$output_directory/summary.tsv")" \
    "$output_directory"
[ "$overall" = held ]
