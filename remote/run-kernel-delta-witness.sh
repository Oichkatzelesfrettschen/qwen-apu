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
# The token ids are compared exactly. Two contracts read the log-probabilities.
# `logprob-bound` reports the largest absolute difference of the selected
# token's log-probability over every generated token against
# QWEN_WITNESS_LOGPROB_BOUND; the 1e-3 nat it was first registered with had
# no reference and E4 refuted it while holding every token id, so it remains
# as the recorded historical rule. `margin` is the contract that replaces it:
# QWEN_WITNESS_N_PROBS acquires the top-k log-probabilities at every
# position, and summarize-margin-witness.py reads the winner's margin over
# the runner-up in both binaries, which equals the logit margin because the
# softmax normalizer cancels. The candidate must keep every winner, keep a
# positive margin at every position, and retain at least
# QWEN_WITNESS_RETENTION of the control's margin wherever that margin is at
# least QWEN_WITNESS_NEAR_TIE_NAT; the near-tie positions below it are
# counted separately, since a ratio over a vanishing margin measures nothing.
# The rule and its constants are registered in
# evidence/raven2-vulkan-kernel-census/e4/margin-contract-design.md ahead of
# the holdout run that first applies them.
#
# QWEN_WITNESS_PROMPTS names a prompt file (id, tab, prompt, one per line) in
# place of the six discovery prompts below, so a contract frozen over the
# discovery set is judged on prompts no earlier run has read.
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
# The arm environment is closed rather than scrubbed, and census_arm_exec owns
# both halves of that: the record each arm keeps and the `env -i` it execs
# under.
# shellcheck source=census-arm-lib.sh
. "$script_directory/census-arm-lib.sh"
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
top_count=${QWEN_WITNESS_N_PROBS:-1}
contract=${QWEN_WITNESS_CONTRACT:-logprob-bound}
near_tie_nat=${QWEN_WITNESS_NEAR_TIE_NAT:-0.1}
margin_retention=${QWEN_WITNESS_RETENTION:-0.5}
prompt_source=${QWEN_WITNESS_PROMPTS:-}
# The witness starts llama-server itself rather than through
# radv-low-priority-env.sh, so the ICD the loader reads is stated here the way
# that wrapper states it. An arm runs under the closed environment
# census_arm_exec applies, so a driver selected by an ambient VK_DRIVER_FILES
# reaches nothing.
radv_icd=${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
margin_summarizer=${QWEN_WITNESS_MARGIN_SUMMARIZER:-"$script_directory/summarize-margin-witness.py"}

case $top_count in
    '' | *[!0-9]* | 0)
        printf 'QWEN_WITNESS_N_PROBS is a positive integer: %s\n' "$top_count" >&2
        exit 2
        ;;
esac
case $run_count in
    '' | *[!0-9]* | 0)
        printf 'QWEN_WITNESS_RUNS is a positive integer: %s\n' "$run_count" >&2
        exit 2
        ;;
esac
# The analyzer converts the bound with float(), which reads `inf` and `nan` as
# numbers and breaks the verdict in opposite directions: every finite delta
# passes at inf and every comparison fails at nan. A sign is refused for the
# same reason, since a negative bound admits nothing. The pattern takes plain
# decimal spellings alone, so the exponent form of the 0.001 default is written
# out.
case $logprob_bound in
    '' | . | *[!0-9.]* | *.*.*)
        printf 'QWEN_WITNESS_LOGPROB_BOUND is a nonnegative decimal number: %s\n' \
            "$logprob_bound" >&2
        exit 2
        ;;
esac
case $contract in
    logprob-bound) ;;
    margin)
        if [ "$top_count" -lt 2 ]; then
            printf 'the margin contract reads a runner-up, so QWEN_WITNESS_N_PROBS is at least 2: %s\n' "$top_count" >&2
            exit 2
        fi
        if [ ! -r "$margin_summarizer" ]; then
            printf 'margin summarizer is unreadable: %s\n' "$margin_summarizer" >&2
            exit 2
        fi
        ;;
    *)
        printf 'QWEN_WITNESS_CONTRACT is logprob-bound or margin: %s\n' "$contract" >&2
        exit 2
        ;;
esac
if [ -n "$prompt_source" ] && [ ! -r "$prompt_source" ]; then
    printf 'QWEN_WITNESS_PROMPTS is unreadable: %s\n' "$prompt_source" >&2
    exit 2
fi

for server in "$control_server" "$candidate_server"; do
    if [ ! -x "$server" ]; then
        printf 'server is not executable: %s\n' "$server" >&2
        exit 2
    fi
done
if [ ! -r "$radv_icd" ]; then
    printf 'RADV ICD is not readable: %s\n' "$radv_icd" >&2
    exit 2
fi
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
if [ -n "$prompt_source" ]; then
    cp "$prompt_source" "$prompt_file"
else
cat >"$prompt_file" <<'PROMPTS'
accumulator	Start with the number 7. Apply these operations in order and show the running total after every single step: add 13, multiply by 3, subtract 8, divide by 2, add 45, multiply by 4, subtract 111, add 19, multiply by 2, subtract 37, add 88, divide by 5. State the value after each operation on its own line, then give the final value.
stack	Simulate a stack, one operation per line, printing the complete stack contents after every operation: push A, push B, push C, pop, push D, push E, pop, pop, push F, push G, push H, pop, push I, pop, pop, push J. Then report the final stack from bottom to top and the full sequence of popped values in order.
list-transform	Begin with the list [4, 9, 2, 7, 1, 8, 3, 6, 5]. Apply each rule to the result of the previous rule and print the whole list after each rule: double every element, remove every element above 15, append the sum of the current list, sort ascending, subtract the smallest element from every element, reverse the list, append the count of nonzero elements. Show every intermediate list.
variable-trace	Trace this program line by line and print the value of every variable after each line: a = 3; b = a + 4; c = b * 2; a = c - b; d = a + c; b = d - a; c = b + d; a = c - d; d = a * b; b = d - c; c = a + b; a = c * 2; b = a - d. After the trace, give the final values of a, b, c, and d.
state-machine	A machine has states S0, S1, S2, S3 and transitions: on 0 go S0->S1, S1->S2, S2->S3, S3->S0; on 1 go S0->S2, S1->S0, S2->S1, S3->S2. Starting in S0, process the input 0110100111010011 one symbol at a time. Print the state after each symbol, then report the final state and how many times each state was visited.
constraints	Five houses in a row are numbered 1 to 5. Each has one colour from red, blue, green, white, yellow and one occupant from Ana, Ben, Cara, Dan, Eve. Apply these clues one at a time, and after each clue print everything you have established so far: the red house is immediately left of the green house; Ana lives in the blue house; Cara lives in house 1; the yellow house is house 5; Ben lives immediately right of the white house; Dan does not live in house 3; the green house is house 4. Then give the complete assignment.
PROMPTS
fi
# A prompt file is two tab-separated columns, ids unique and unindented, so
# a malformed holdout is refused ahead of any server start.
if ! awk -F'\t' '
    NF != 2 || $1 == "" || $2 == "" || $1 ~ /[^A-Za-z0-9_-]/ { bad = 1; exit 1 }
    seen[$1]++ { bad = 1; exit 1 }
    END { if (bad || NR == 0) exit 1 }' "$prompt_file"; then
    printf 'prompt file is not id<TAB>prompt with unique ids: %s\n' "${prompt_source:-$prompt_file}" >&2
    exit 2
fi
prompt_count=$(wc -l <"$prompt_file" | tr -d ' ')
prompt_sha256=$(sha256sum "$prompt_file" | cut -d ' ' -f 1)

request_builder=$output_directory/build-request.py
cat >"$request_builder" <<'PYTHON'
import json
import sys

prompt_path, predict, seed, top_count = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
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
        "n_probs": top_count,
        "stream": False,
    },
    sys.stdout,
)
PYTHON

# One line per generated token: the id, the selected token's log-probability
# as the server reports it, and the top-k list as `id:logprob` pairs joined
# by `;`, so the files a comparison reads are the record and not a
# re-derivation. The server fills `top_logprobs` from the full-vocabulary
# softmax ahead of sampling, so a top_k of 1 in the sampler leaves the list
# whole; the reader requires the list to hold the requested count and to
# open on the selected token, which is what greedy sampling makes true.
token_reader=$output_directory/read-tokens.py
cat >"$token_reader" <<'PYTHON'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
top_count = int(sys.argv[2])
tokens = payload.get("tokens")
probabilities = payload.get("completion_probabilities")


def top_list(entry, token_id):
    top = entry.get("top_logprobs")
    if not isinstance(top, list) or len(top) < top_count:
        sys.stderr.write(f"top_logprobs holds {len(top) if isinstance(top, list) else 'no'} entries"
                         f" where {top_count} were requested\n")
        raise SystemExit(1)
    if top[0].get("id") != token_id:
        sys.stderr.write(f"top_logprobs opens on id {top[0].get('id')} where the selected token is {token_id}\n")
        raise SystemExit(1)
    return ";".join(f"{int(item['id'])}:{float(item['logprob']):.9g}" for item in top[:top_count])

if not isinstance(tokens, list) or not tokens:
    sys.stderr.write("response carries no token array\n")
    raise SystemExit(1)
# The server returns fewer probability entries than tokens whenever a token
# ends inside a multi-byte UTF-8 sequence: `process_token` in
# tools/server/server-context.cpp at f280b269 calls `slot.add_token` only
# when `validate_utf8` finds the generated text complete, so the withheld
# token gets no entry and the next complete token's entry carries both
# pieces in its `bytes`. A reply writing `÷` three times therefore carries
# three fewer entries, and the count follows content. The entries are
# merged onto the token array by id in order; a token without an entry
# prints `-`, is compared by id alone, and is admitted only when the entry
# that follows it holds a byte at or above 0x80, which is the sequence the
# server withheld it for. Every entry must be consumed, since an entry the
# token array cannot place names a reply this reader does not understand.
if not isinstance(probabilities, list) or not probabilities:
    sys.stderr.write("response carries no probability entries\n")
    raise SystemExit(1)
entry_index = 0
withheld = []
lines = []
for position, token_id in enumerate(tokens):
    if not isinstance(token_id, int):
        sys.stderr.write("token array holds a non-integer entry\n")
        raise SystemExit(1)
    if entry_index < len(probabilities) and probabilities[entry_index].get("id") == token_id:
        entry = probabilities[entry_index]
        lines.append(f"{token_id}\t{float(entry['logprob']):.9g}\t{top_list(entry, token_id)}")
        entry_index += 1
    else:
        following = probabilities[entry_index] if entry_index < len(probabilities) else {}
        following_bytes = following.get("bytes")
        if not isinstance(following_bytes, list) or not any(isinstance(b, int) and b >= 0x80 for b in following_bytes):
            sys.stderr.write(f"token {token_id} at position {position} has no probability entry and the"
                             f" entry that follows carries no multi-byte sequence to explain it\n")
            raise SystemExit(1)
        lines.append(f"{token_id}\t-\t-")
        withheld.append(position)
if entry_index != len(probabilities):
    sys.stderr.write(f"probability entries do not align with the token array:"
                     f" consumed={entry_index} of {len(probabilities)} withheld_tokens={len(withheld)}\n")
    raise SystemExit(1)
if withheld:
    sys.stderr.write(f"withheld_utf8_positions={','.join(str(p) for p in withheld)}\n")
print("\n".join(lines))
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

# The candidate may run on the CPU backend instead of Vulkan0, which is the
# reference for what a different accumulation order costs: the CPU Q4_K dot
# product sums in another order than the Vulkan mat-vec, so the same binary
# against itself across the two backends bounds legitimate reassociation
# on this model. `--device none` places every buffer on the CPU and the
# placement lines are read for that prefix.
candidate_device=${QWEN_WITNESS_CANDIDATE_DEVICE:-Vulkan0}
case $candidate_device in
    Vulkan0 | cpu) ;;
    *)
        printf 'QWEN_WITNESS_CANDIDATE_DEVICE is Vulkan0 or cpu: %s\n' "$candidate_device" >&2
        exit 2
        ;;
esac

# A candidate whose behavior is selected at run time rather than compiled in
# reaches nothing through a closed environment unless the selection is named
# here. The E5 arm is that shape: one binary carries the q8_1 mat-vec and its
# control, and ggml_vk_force_integer_dot() decides which pipelines are created,
# so a witness run without the key compares one shader against itself and
# reports an agreement it never tested. The value is the exact "1" the backend
# compares against and is refused otherwise, so a third value cannot run the
# control under the arm's name, and it is admitted per role because the control
# arm is the same binary with the key absent.
witness_control_force_integer_dot=${QWEN_WITNESS_CONTROL_FORCE_INTEGER_DOT:-}
witness_candidate_force_integer_dot=${QWEN_WITNESS_CANDIDATE_FORCE_INTEGER_DOT:-}
for witness_force_integer_dot_value in \
    "$witness_control_force_integer_dot" "$witness_candidate_force_integer_dot"; do
    case $witness_force_integer_dot_value in
        '' | 1) ;;
        *)
            printf 'QWEN_WITNESS_CONTROL_FORCE_INTEGER_DOT and QWEN_WITNESS_CANDIDATE_FORCE_INTEGER_DOT admit 1 or an unset value: %s\n' \
                "$witness_force_integer_dot_value" >&2
            exit 2
            ;;
    esac
done

start_server() {
    arm_server=$1
    arm_log=$2
    arm_device=$3
    arm_expected_sha256=$4
    arm_environment_record=$5
    arm_force_integer_dot=$6
    # A run spans four model loads and the two paths stay writable throughout,
    # so the digest inputs.tsv records is re-read against the file about to be
    # executed rather than assumed to still describe it. A build landing on
    # either path between arms would otherwise be reported under the identity
    # the first arm measured.
    arm_observed_sha256=$(sha256sum "$arm_server" | cut -d ' ' -f 1)
    if [ "$arm_observed_sha256" != "$arm_expected_sha256" ]; then
        printf 'server changed under %s: recorded=%s observed=%s\n' \
            "$arm_server" "$arm_expected_sha256" "$arm_observed_sha256" >&2
        return 1
    fi
    # The graph optimizer setting is absent rather than removed: the closed
    # environment carries the names below and nothing else, so an ambient
    # GGML_VK_DISABLE_GRAPH_OPTIMIZE, GGML_VK_Q4K_SIDEPLANE, or RADV_PERFTEST
    # changes no arm and the record proves which set applied.
    if [ "$arm_device" = cpu ]; then
        census_arm_exec "$arm_environment_record" \
            VK_DRIVER_FILES="$radv_icd" VK_ICD_FILENAMES="$radv_icd" \
            GGML_VK_FORCE_INTEGER_DOT="$arm_force_integer_dot" \
            -- \
            "$arm_server" \
            --model "$model_path" --host 127.0.0.1 --port "$server_port" \
            --ctx-size "$model_context" --batch-size "$model_batch" --ubatch-size "$model_ubatch" \
            --cache-type-k "$model_cache_k" --cache-type-v "$model_cache_v" \
            --flash-attn "$model_flash_attention" \
            --device none --fit off --parallel 1 \
            --threads "$thread_count" --threads-batch "$thread_count" \
            --no-context-shift --offline --log-verbosity 4 \
            >"$arm_log" 2>&1 &
    else
        census_arm_exec "$arm_environment_record" \
            VK_DRIVER_FILES="$radv_icd" VK_ICD_FILENAMES="$radv_icd" \
            LLAMA_NO_CPU_FALLBACK=1 \
            GGML_VK_FORCE_INTEGER_DOT="$arm_force_integer_dot" \
            -- \
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
    fi
    server_pid=$!
    case $arm_device in
        cpu) placement_prefix='CPU[A-Za-z_]*' ;;
        *) placement_prefix='Vulkan0' ;;
    esac
    ready_iteration=0
    while [ "$ready_iteration" -lt "$readiness_seconds" ]; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            printf 'llama-server exited before readiness; see %s\n' "$arm_log" >&2
            return 1
        fi
        if curl --silent --fail --max-time 2 "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
            for placement_line in "$placement_prefix model buffer size" \
                "$placement_prefix KV buffer size" "$placement_prefix compute buffer size"; do
                if ! grep -qE "$placement_line" "$arm_log"; then
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

control_server_sha256=$(sha256sum "$control_server" | cut -d ' ' -f 1)
candidate_server_sha256=$(sha256sum "$candidate_server" | cut -d ' ' -f 1)
{
    printf 'control_server\t%s\ncontrol_server_sha256\t%s\n' "$control_server" \
        "$control_server_sha256"
    printf 'candidate_server\t%s\ncandidate_server_sha256\t%s\n' "$candidate_server" \
        "$candidate_server_sha256"
    printf 'model_id\t%s\nmodel_path\t%s\nmodel_sha256\t%s\n' "$model_id" "$model_path" \
        "$(sha256sum "$model_path" | cut -d ' ' -f 1)"
    printf 'context\t%s\nbatch\t%s\nubatch\t%s\ncache_k\t%s\ncache_v\t%s\nflash_attention\t%s\n' \
        "$model_context" "$model_batch" "$model_ubatch" "$model_cache_k" "$model_cache_v" \
        "$model_flash_attention"
    printf 'runs_per_start\t%s\npredict_tokens\t%s\nseed\t%s\nthreads\t%s\nlogprob_bound\t%s\n' \
        "$run_count" "$predict_tokens" "$sampling_seed" "$thread_count" "$logprob_bound"
    printf 'arm_order\tC K K C\ncontrol_device\tVulkan0\ncandidate_device\t%s\n' "$candidate_device"
    printf 'control_force_integer_dot\t%s\ncandidate_force_integer_dot\t%s\n' \
        "${witness_control_force_integer_dot:--}" "${witness_candidate_force_integer_dot:--}"
    printf 'contract\t%s\nn_probs\t%s\nnear_tie_nat\t%s\nmargin_retention\t%s\n' \
        "$contract" "$top_count" "$near_tie_nat" "$margin_retention"
    printf 'prompt_source\t%s\nprompt_count\t%s\nprompts_sha256\t%s\n' \
        "${prompt_source:-builtin}" "$prompt_count" "$prompt_sha256"
} >"$output_directory/inputs.tsv"

slot=0
for arm in C K K C; do
    slot=$((slot + 1))
    case $arm in
        C)
            arm_server=$control_server
            arm_device=Vulkan0
            arm_sha256=$control_server_sha256
            arm_force_integer_dot=$witness_control_force_integer_dot
            ;;
        *)
            arm_server=$candidate_server
            arm_device=$candidate_device
            arm_sha256=$candidate_server_sha256
            arm_force_integer_dot=$witness_candidate_force_integer_dot
            ;;
    esac
    arm_directory=$output_directory/arms/$slot-$arm
    mkdir -p "$arm_directory"
    printf 'witness_arm=start slot=%s arm=%s server=%s device=%s force_integer_dot=%s\n' \
        "$slot" "$arm" "$arm_server" "$arm_device" "${arm_force_integer_dot:--}"
    start_server "$arm_server" "$arm_directory/server.log" "$arm_device" \
        "$arm_sha256" "$arm_directory/arm-environment.tsv" "$arm_force_integer_dot"
    run_index=1
    while [ "$run_index" -le "$run_count" ]; do
        while IFS="$(printf '\t')" read -r prompt_id prompt_text; do
            [ -n "$prompt_id" ] || continue
            prompt_directory=$arm_directory/$prompt_id
            mkdir -p "$prompt_directory"
            printf '%s' "$prompt_text" >"$prompt_directory/prompt.txt"
            python3 "$request_builder" "$prompt_directory/prompt.txt" "$predict_tokens" \
                "$sampling_seed" "$top_count" >"$prompt_directory/request.json"
            curl --silent --show-error --fail-with-body --max-time "$request_seconds" \
                --header 'Content-Type: application/json' \
                --data @"$prompt_directory/request.json" \
                "http://127.0.0.1:$server_port/completion" \
                >"$prompt_directory/response-run-$run_index.json"
            python3 "$token_reader" "$prompt_directory/response-run-$run_index.json" "$top_count" \
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
            token_id, logprob = line.rstrip("\n").split("\t")[:2]
            ids.append(int(token_id))
            logprobs.append(None if logprob == "-" else float(logprob))
    return ids, logprobs


def largest_delta(current, a_values, b_values):
    return max([current] + [abs(a - b) for a, b in zip(a_values, b_values)
                            if a is not None and b is not None])


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
                delta = largest_delta(delta, logprobs, ref_logprobs)
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
            delta = largest_delta(delta, logprobs, ref_logprobs)
    verdict = "held" if identity == "held" and delta <= bound else "differs"
    if verdict != "held":
        overall = "differs"
    print(f"{prompt_id}\tcandidate-vs-control\t{len(cross_rows)}\t{identity}\t{divergence}\t{delta:.3e}\t{verdict}")
print(f"-\toverall\t-\t-\t-\t-\t{overall}")
PYTHON
bound_overall=$(awk -F'\t' '$2 == "overall" { print $7 }' "$output_directory/summary.tsv")
# Under the margin contract the verdict comes from the margin summary and the
# log-probability bound row is retained as a report; both are printed so a
# reader sees which rule decided.
if [ "$contract" = margin ]; then
    python3 "$margin_summarizer" "$output_directory" --top-k "$top_count" \
        --near-tie "$near_tie_nat" --retention "$margin_retention" \
        >"$output_directory/margin-summary.tsv" || {
        printf 'margin summarizer failed; see %s\n' "$output_directory/margin-summary.tsv" >&2
        exit 1
    }
    overall=$(awk -F'\t' '$2 == "overall" { print $NF }' "$output_directory/margin-summary.tsv")
else
    overall=$bound_overall
fi
printf 'witness=%s contract=%s logprob_bound_verdict=%s prompts=%s output=%s\n' "$overall" "$contract" \
    "$bound_overall" "$prompt_count" "$output_directory"
[ "$overall" = held ]
