#!/bin/sh
set -eu

# Measure what --ctx-checkpoints buys a hybrid recurrent model on a second
# turn at depth. server-context.cpp cannot roll a Gated DeltaNet state back,
# so a turn that shares a long prefix with the previous one re-prefills from
# the newest checkpoint below the divergence point, or from position zero
# where no checkpoint exists. Each arm launches the appliance through the
# guarded chain with QWEN_CTX_CHECKPOINTS set, sends one prompt of about the
# target depth, sends the same prompt with a short appended suffix, and
# retains both turns' server timings and greedy token ids. The arms run in
# mirrored order so drift meets every setting twice, and a fresh launch per
# arm keeps one setting's checkpoints out of the next.
#
# Two falsifiers are read from the retained rows. A checkpoint count above
# zero whose turn-2 prompt_ms stays within 10% of turn 1 means the checkpoint
# bought nothing; a token-id divergence between arms means a checkpoint
# changed the answer, which it is defined not to do.
#
# The registry row supplies depth ceiling, cache triple, and submission
# geometry through the served path, so the sweep measures the checkpoint
# count and nothing else. QWEN_LAUNCH_SCRIPT and QWEN_TEARDOWN_SCRIPT stand in
# for the launch chain under test.

if [ "$#" -ne 3 ]; then
    printf 'usage: %s LABEL MODEL_ID OUTPUT_DIR\n' "$0" >&2
    printf 'QWEN_CTX_CHECKPOINT_ARMS overrides the arm list (default "0 2 4 8 8 4 2 0")\n' >&2
    printf 'QWEN_CTX_TARGET_DEPTH overrides the prompt depth (default 30720)\n' >&2
    exit 2
fi

label=$1
model_id=$2
output_directory=$3
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry_script=${QWEN_MODEL_REGISTRY_SCRIPT:-"$script_directory/model-registry.sh"}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
launch_script=${QWEN_LAUNCH_SCRIPT:-"$script_directory/qwen-launch.sh"}
teardown_script=${QWEN_TEARDOWN_SCRIPT:-"$script_directory/qwen-teardown.sh"}
state_directory=${QWEN_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
profile=${QWEN_VULKAN_PROFILE_ARM:-low-async}
server_port=${QWEN_SERVER_PORT:-8080}
endpoint=http://127.0.0.1:$server_port
arm_list=${QWEN_CTX_CHECKPOINT_ARMS:-'0 2 4 8 8 4 2 0'}
target_depth=${QWEN_CTX_TARGET_DEPTH:-30720}
predict_tokens=${QWEN_CTX_PREDICT:-32}
request_seconds=${QWEN_CTX_REQUEST_SECONDS:-3600}
export QWEN_WEBUI_STATE_DIRECTORY=$state_directory

for arm in $arm_list; do
    case $arm in
        '' | *[!0-9]*)
            printf 'checkpoint arms must be non-negative integers: %s\n' "$arm" >&2
            exit 2
            ;;
    esac
done
for positive_value in "$target_depth" "$predict_tokens" "$request_seconds"; do
    case $positive_value in
        '' | *[!0-9]* | 0)
            printf 'depth, predict, and request seconds must be positive integers: %s\n' \
                "$positive_value" >&2
            exit 2
            ;;
    esac
done

model_file=$("$registry_script" id "$model_id" model_file)
model_path=$models_directory/$model_file
if [ ! -f "$model_path" ]; then
    printf 'model file is absent: %s\n' "$model_path" >&2
    exit 2
fi
context_ceiling=$("$registry_script" id "$model_id" context_ceiling)
if [ "$target_depth" -ge "$context_ceiling" ]; then
    printf 'target depth %s reaches the registry ceiling %s; the suffix and reply need room\n' \
        "$target_depth" "$context_ceiling" >&2
    exit 2
fi

# A concurrent llama-server contends for the two compute units and the one
# DDR4 controller, and the launch chain would also refuse a second session.
if command -v pgrep >/dev/null 2>&1 && pgrep -x llama-server >/dev/null 2>&1; then
    printf 'llama-server is running; run %s after qwen-teardown.sh\n' \
        "$(basename "$0")" >&2
    exit 1
fi

# The harness takes nice 19 and every arm inherits it through fork.
# `renice --priority` writes the absolute value where `nice -n 19` would add
# 19 to the caller's own niceness, so a caller started below nice 0 still
# lands the run at 19. The value is read back from the kernel rather than
# asserted.
/usr/bin/renice --priority 19 --pid "$$" >/dev/null 2>&1 || true
harness_nice=$(LC_ALL=C /usr/bin/ps -o ni= -p "$$" 2>/dev/null |
    /usr/bin/awk '{ gsub(/[[:space:]]/, ""); print; exit }')
if [ "$harness_nice" != 19 ]; then
    printf 'measurement priority refused: observed=%s\n' \
        "${harness_nice:-unreadable}" >&2
    exit 2
fi

umask 077
mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)
summary_file=$output_directory/summary.tsv
printf 'label=%s\nmodel_id=%s\nmodel=%s\nprofile=%s\narms=%s\ntarget_depth=%s\npredict_tokens=%s\nharness_nice=%s\n' \
    "$label" "$model_id" "$model_path" "$profile" "$arm_list" \
    "$target_depth" "$predict_tokens" "$harness_nice" \
    >"$output_directory/inputs.txt"
printf 'arm\tctx_checkpoints\tturn\tprompt_n\tprompt_ms\tpredicted_n\tpredicted_ms\tprompt_tok_s\tdecode_tok_s\tprefill_saved_ms\n' \
    >"$summary_file"

server_started=0
teardown_server() {
    [ "$server_started" -eq 1 ] || return 0
    server_started=0
    "$teardown_script" >>"$output_directory/teardown.txt" 2>&1 || {
        printf 'teardown failed for arm %s\n' "$current_arm" >&2
        return 1
    }
}
current_arm=none
trap 'teardown_server' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

read_api_key() {
    api_key=''
    if [ -s "$state_directory/api.key" ]; then
        api_key=$(sed -n '1p' "$state_directory/api.key")
    fi
}

# POST a JSON file to a route; the bearer header is present only where the
# session minted a key. Output goes to the named file, status is returned.
post_json() {
    post_route=$1
    post_body=$2
    post_output=$3
    if [ -n "$api_key" ]; then
        curl --silent --show-error --fail-with-body \
            --max-time "$request_seconds" \
            --header 'Content-Type: application/json' \
            --header "Authorization: Bearer $api_key" \
            --data @"$post_body" "$endpoint$post_route" >"$post_output"
    else
        curl --silent --show-error --fail-with-body \
            --max-time "$request_seconds" \
            --header 'Content-Type: application/json' \
            --data @"$post_body" "$endpoint$post_route" >"$post_output"
    fi
}

# The filler is a deterministic walk over a fixed word list, so the same
# seed and word count produce byte-identical text on every arm and every
# machine. The prompt is composed once against the first arm's tokenizer,
# because the tokenizer belongs to the checkpoint rather than the launch, and
# every later arm reuses the file.
generate_filler() {
    awk -v count="$1" 'BEGIN {
        split("river stone maple harbor lantern copper meadow signal orbit " \
              "quarry timber glacier ember canyon thread anchor prism cedar " \
              "valley beacon marble summit furrow saddle willow fathom " \
              "ridge tundra basin tallow", words, " ")
        # A 16-bit Lehmer step keeps every product below 2^53, so the walk
        # is exact in awk doubles and identical across implementations.
        word_count = 30
        state = 7
        for (index_value = 1; index_value <= count; index_value++) {
            state = (state * 75 + 74) % 65537
            printf "%s", words[int(state / 7) % word_count + 1]
            if (index_value % 12 == 0) { printf ".\n" } else { printf " " }
        }
        printf "\n"
    }'
}

count_tokens() {
    count_file=$1
    python3 -c '
import json, sys
with open(sys.argv[1]) as handle:
    text = handle.read()
sys.stdout.write(json.dumps({"content": text}))
' "$count_file" >"$output_directory/tokenize-request.json"
    post_json /tokenize "$output_directory/tokenize-request.json" \
        "$output_directory/tokenize-response.json"
    python3 -c '
import json, sys
with open(sys.argv[1]) as handle:
    print(len(json.load(handle)["tokens"]))
' "$output_directory/tokenize-response.json"
}

compose_prompt() {
    prompt_file=$output_directory/prompt-turn1.txt
    depth_tolerance=$((target_depth / 50))
    filler_words=$target_depth
    attempt=0
    while :; do
        attempt=$((attempt + 1))
        {
            printf 'Read the following record and then answer the question at its end.\n\n'
            generate_filler "$filler_words"
            printf '\nQuestion: which word opened the record?\nAnswer:'
        } >"$prompt_file"
        prompt_tokens=$(count_tokens "$prompt_file")
        difference=$((prompt_tokens - target_depth))
        [ "$difference" -ge 0 ] || difference=$((-difference))
        if [ "$difference" -le "$depth_tolerance" ]; then
            break
        fi
        if [ "$attempt" -ge 8 ]; then
            printf 'prompt did not converge on depth %s after %s attempts: %s tokens\n' \
                "$target_depth" "$attempt" "$prompt_tokens" >&2
            return 1
        fi
        # Rescale the word count by the measured tokens-per-word ratio.
        filler_words=$((filler_words * target_depth / prompt_tokens))
    done
    printf 'prompt_tokens=%s\nattempts=%s\nfiller_words=%s\n' \
        "$prompt_tokens" "$attempt" "$filler_words" \
        >"$output_directory/prompt-depth.txt"
    {
        cat "$prompt_file"
        printf ' The record opened with a word.\n\nQuestion: how many sentences does the record hold, roughly?\nAnswer:'
    } >"$output_directory/prompt-turn2.txt"
}

# One completion through the raw route: greedy, fixed length, cache_prompt on
# so the server reuses what it can of the previous turn, return_tokens so the
# comparison runs over ids rather than text.
run_turn() {
    turn_prompt=$1
    turn_output=$2
    python3 - "$turn_prompt" "$predict_tokens" >"$turn_output.request.json" <<'PY'
import json, sys
with open(sys.argv[1]) as handle:
    prompt = handle.read()
sys.stdout.write(json.dumps({
    "prompt": prompt,
    "n_predict": int(sys.argv[2]),
    "temperature": 0,
    "top_k": 1,
    "seed": 1,
    "ignore_eos": True,
    "cache_prompt": True,
    "return_tokens": True,
}))
PY
    post_json /completion "$turn_output.request.json" "$turn_output"
}

arm_index=0
failed_arms=0
for arm in $arm_list; do
    arm_index=$((arm_index + 1))
    current_arm=$arm_index
    arm_directory=$output_directory/arm-$arm_index-c$arm
    mkdir -p "$arm_directory"
    if ! QWEN_MODEL_PATH=$model_path QWEN_CTX_CHECKPOINTS=$arm \
        "$launch_script" "$profile" >"$arm_directory/launch.txt" 2>&1; then
        printf 'launch failed for arm %s (ctx_checkpoints=%s)\n' \
            "$arm_index" "$arm" >&2
        failed_arms=$((failed_arms + 1))
        server_started=1
        teardown_server || true
        continue
    fi
    server_started=1
    read_api_key
    if [ ! -s "$output_directory/prompt-turn2.txt" ]; then
        compose_prompt
    fi
    turn_status=0
    run_turn "$output_directory/prompt-turn1.txt" "$arm_directory/turn1.json" \
        || turn_status=$?
    if [ "$turn_status" -eq 0 ]; then
        run_turn "$output_directory/prompt-turn2.txt" \
            "$arm_directory/turn2.json" || turn_status=$?
    fi
    cp "$state_directory/server.log" "$arm_directory/server.log" 2>/dev/null || true
    sed -n '1,4p' "$state_directory/session.status" \
        >"$arm_directory/session.status" 2>/dev/null || true
    teardown_server || turn_status=1
    if [ "$turn_status" -ne 0 ]; then
        printf 'request failed for arm %s (ctx_checkpoints=%s): status %s\n' \
            "$arm_index" "$arm" "$turn_status" >&2
        failed_arms=$((failed_arms + 1))
        continue
    fi
    python3 - "$arm_directory" "$arm_index" "$arm" "$summary_file" \
        "$target_depth" "$predict_tokens" <<'PY' || failed_arms=$((failed_arms + 1))
import json, sys

directory, arm_index, arm, summary_file = sys.argv[1:5]
target_depth = int(sys.argv[5])
predict_tokens = int(sys.argv[6])
rows = []
prompt_ms = {}
for turn in (1, 2):
    with open(f"{directory}/turn{turn}.json") as handle:
        document = json.load(handle)
    timings = document.get("timings") or {}
    tokens = document.get("tokens")
    fields = {}
    for name in ("prompt_n", "prompt_ms", "predicted_n", "predicted_ms"):
        value = timings.get(name)
        if not isinstance(value, (int, float)):
            print(f"arm {arm_index} turn {turn}: timings.{name} is absent",
                  file=sys.stderr)
            sys.exit(1)
        fields[name] = value
    if not isinstance(tokens, list) or len(tokens) != predict_tokens:
        print(f"arm {arm_index} turn {turn}: expected {predict_tokens} token ids",
              file=sys.stderr)
        sys.exit(1)
    if turn == 1 and abs(fields["prompt_n"] - target_depth) > target_depth // 50:
        print(f"arm {arm_index}: turn 1 prompt_n {fields['prompt_n']} is outside "
              f"2% of {target_depth}", file=sys.stderr)
        sys.exit(1)
    with open(f"{directory}/turn{turn}.tokens", "w") as handle:
        handle.write(" ".join(str(token) for token in tokens) + "\n")
    prompt_ms[turn] = fields["prompt_ms"]
    prompt_rate = fields["prompt_n"] / fields["prompt_ms"] * 1000 if fields["prompt_ms"] else 0.0
    decode_rate = fields["predicted_n"] / fields["predicted_ms"] * 1000 if fields["predicted_ms"] else 0.0
    saved = "-" if turn == 1 else f"{prompt_ms[1] - prompt_ms[2]:.3f}"
    rows.append("\t".join([arm_index, arm, str(turn), str(fields["prompt_n"]),
                           f"{fields['prompt_ms']:.3f}", str(fields["predicted_n"]),
                           f"{fields['predicted_ms']:.3f}", f"{prompt_rate:.3f}",
                           f"{decode_rate:.3f}", saved]))
with open(summary_file, "a") as handle:
    handle.write("\n".join(rows) + "\n")
print(f"arm={arm_index} ctx_checkpoints={arm} turn1_prompt_ms={prompt_ms[1]:.1f} "
      f"turn2_prompt_ms={prompt_ms[2]:.1f} prefill_saved_ms={prompt_ms[1] - prompt_ms[2]:.1f}")
PY
done

# Checkpoints restore a state the server computed once, so the greedy ids of
# every arm are one sequence. The first index where any arm departs from arm 1
# is the correctness finding, reported per turn.
divergence_status=0
python3 - "$output_directory" "$arm_list" <<'PY' >"$output_directory/divergence.txt" || divergence_status=$?
import os, sys

directory = sys.argv[1]
arms = sys.argv[2].split()
status = 0
for turn in (1, 2):
    reference = None
    reference_name = None
    for index, arm in enumerate(arms, 1):
        path = f"{directory}/arm-{index}-c{arm}/turn{turn}.tokens"
        if not os.path.exists(path):
            print(f"turn={turn} arm={index} ctx_checkpoints={arm} tokens=absent")
            continue
        with open(path) as handle:
            tokens = handle.read().split()
        if reference is None:
            reference, reference_name = tokens, f"arm {index}"
            print(f"turn={turn} arm={index} ctx_checkpoints={arm} reference=self")
            continue
        divergence = next((i for i, (a, b) in enumerate(zip(reference, tokens)) if a != b),
                          None)
        if divergence is None and len(reference) != len(tokens):
            divergence = min(len(reference), len(tokens))
        if divergence is None:
            print(f"turn={turn} arm={index} ctx_checkpoints={arm} divergence=none")
        else:
            status = 1
            print(f"turn={turn} arm={index} ctx_checkpoints={arm} "
                  f"divergence={divergence} against={reference_name}")
sys.exit(status)
PY
cat "$output_directory/divergence.txt"

if [ "$failed_arms" -ne 0 ] || [ "$divergence_status" -ne 0 ]; then
    printf 'ctx_checkpoint_sweep=failed label=%s failed_arms=%s divergence=%s output=%s\n' \
        "$label" "$failed_arms" "$divergence_status" "$output_directory" >&2
    exit 1
fi
printf 'ctx_checkpoint_sweep=completed label=%s arms=%s output=%s\n' \
    "$label" "$arm_index" "$output_directory"
