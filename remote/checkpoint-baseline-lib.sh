# shellcheck shell=sh
# The served session one checkpoint baseline arm is made of: one launch through
# the guarded chain, one readiness poll, one streamed request that times the
# first token, a fixed block of identical 64-token requests that measures steady
# decode, and one teardown. measure-served-decode.sh answers a different
# question with the same chain -- it loads, sends exactly one request, and tears
# down -- so its cold load is inseparable from its rate and it retains no token
# array. The three quantities this file separates exist only inside one session,
# which is why the driver lives here rather than as a flag on that runner, and
# that runner's own behavior stays bound to the fixed-64 receipts it already
# wrote.
#
# This file is sourced and runs nothing. Every function reads its arguments and
# the paths they name and writes into the arm directory it is given.

# The field separator the callers split a binding on. shellcheck reads this file
# alone and sees no reader, so the assignment states its consumer here.
# shellcheck disable=SC2034  # read by run-checkpoint-baseline.sh
baseline_tab=$(printf '\t')

# The lease this campaign runs under is the caller's rather than this shell's.
# compute-state-lease.sh holds the shared Vulkan lock on descriptor 8 for the
# whole transaction and forwards QWEN_VULKAN_EXTERNAL_LEASE_PROOF, so an arm
# proves it inherited that descriptor and lets llama-server take the lock the
# campaign is not holding against it. Taking a second exclusive lock here would
# wedge the first decode pass of every arm.
#
# baseline_require_inherited_lease STATE_DIRECTORY PROOF VERIFIER
baseline_require_inherited_lease() {
    baseline_lease_state=$1
    baseline_lease_proof=$2
    baseline_lease_verifier=$3
    if [ -z "$baseline_lease_proof" ]; then
        printf 'a baseline arm runs under compute-state-lease.sh, which forwards QWEN_VULKAN_EXTERNAL_LEASE_PROOF\n' >&2
        return 1
    fi
    if [ ! -x "$baseline_lease_verifier" ]; then
        printf 'the external Vulkan lease verifier is absent: %s\n' \
            "$baseline_lease_verifier" >&2
        return 1
    fi
    baseline_lease_expected=$baseline_lease_state/vulkan-workload.lock
    baseline_lease_inherited=$(readlink -f -- "/proc/$$/fd/8" 2>/dev/null || true)
    if [ "$baseline_lease_inherited" != "$baseline_lease_expected" ]; then
        printf 'descriptor 8 names another lease: %s against %s\n' \
            "${baseline_lease_inherited:--}" "$baseline_lease_expected" >&2
        return 1
    fi
    "$baseline_lease_verifier" "$baseline_lease_proof" \
        "$baseline_lease_expected" >/dev/null || return 1
}

# baseline_launch ARM_DIRECTORY LAUNCH_SCRIPT PROFILE ENDPOINT DEADLINE_S
#
# The launch runs in a child shell that closes descriptors 8 and 9 in its own
# table: dash applies a trailing `8>&-` written on the parent side for the
# child's whole runtime, which would empty /proc/$$/fd/8 exactly while a later
# arm proves the inherited lease. The wall interval spans the launch call and
# the readiness poll together, so load_wall_ms is the whole cost of putting the
# checkpoint on the device rather than the launcher's own return.
baseline_launch() {
    baseline_arm=$1
    baseline_launch_script=$2
    baseline_profile=$3
    baseline_endpoint=$4
    baseline_deadline=$5
    baseline_launch_begin_ns=$(python3 -c 'import time; print(time.monotonic_ns())')
    if ! sh -c 'exec "$0" "$@" 8>&- 9>&-' "$baseline_launch_script" \
        "$baseline_profile" >"$baseline_arm/launch.txt" 2>&1; then
        sed -n '1,40p' "$baseline_arm/launch.txt" >&2
        return 1
    fi
    baseline_health_elapsed=0
    while [ "$baseline_health_elapsed" -lt "$baseline_deadline" ]; do
        if curl --silent --fail --max-time 5 "$baseline_endpoint/health" \
            >/dev/null 2>&1; then
            break
        fi
        baseline_health_elapsed=$((baseline_health_elapsed + 1))
        sleep 1
    done
    if [ "$baseline_health_elapsed" -ge "$baseline_deadline" ]; then
        printf 'the served endpoint did not report health within %s seconds: %s\n' \
            "$baseline_deadline" "$baseline_endpoint" >&2
        return 1
    fi
    baseline_ready_ns=$(python3 -c 'import time; print(time.monotonic_ns())')
    {
        printf 'key\tvalue\n'
        printf 'launch_begin_ns\t%s\n' "$baseline_launch_begin_ns"
        printf 'health_ready_ns\t%s\n' "$baseline_ready_ns"
        printf 'load_wall_ms\t%s\n' \
            "$(awk -v begin="$baseline_launch_begin_ns" -v end="$baseline_ready_ns" \
                'BEGIN { printf "%.3f", (end - begin) / 1000000 }')"
    } >"$baseline_arm/load.tsv"
}

# baseline_request_body OUTPUT PROMPT PREDICT SEED STREAM
#
# One body shape serves both measurements and differs by the stream flag alone,
# so the first-token record and the decode block decode the same prompt at the
# same length under greedy sampling. `cache_prompt` is off because every repeat
# pays its own prefill, `ignore_eos` fixes the generated length the way
# `llama-bench -n` does, and `return_tokens` is what makes the reply an id array
# a later repeat is compared against. The two bodies are digested separately,
# since a run that recorded one digest would leave the streamed request's shape
# unstated.
baseline_request_body() {
    python3 - "$1" "$2" "$3" "$4" "$5" <<'PY'
import json
import sys

output, prompt, predict, seed, stream = sys.argv[1:6]
body = {
    "prompt": prompt,
    "n_predict": int(predict),
    "temperature": 0,
    "top_k": 1,
    "seed": int(seed),
    "ignore_eos": True,
    "cache_prompt": False,
    "return_tokens": True,
    "stream": stream == "1",
}
with open(output, "w", encoding="utf-8") as handle:
    json.dump(body, handle, separators=(",", ":"), sort_keys=True)
PY
}

# baseline_first_token ARM_DIRECTORY ENDPOINT BODY API_KEY
#
# Time to first token is the wall interval from the request leaving to the first
# streamed content delta arriving, which a non-streamed reply cannot report: its
# `prompt_ms` is prefill alone and excludes the first decode pass and the
# server's own dispatch. The stream is read chunk by chunk and the clock is
# stamped at the first event carrying content, so the value covers exactly what a
# reader of the page waits through.
baseline_first_token() {
    baseline_arm=$1
    baseline_endpoint=$2
    baseline_body=$3
    baseline_key=$4
    baseline_ttft_status=0
    python3 - "$baseline_arm" "$baseline_endpoint" "$baseline_body" \
        "$baseline_key" <<'PY' || baseline_ttft_status=$?
import json
import sys
import time
import urllib.request

arm, endpoint, body_path, api_key = sys.argv[1:5]
body = open(body_path, "rb").read()
request = urllib.request.Request(
    f"{endpoint}/completion", data=body,
    headers={"Content-Type": "application/json"},
)
if api_key:
    request.add_header("Authorization", f"Bearer {api_key}")
begin = time.monotonic_ns()
first = None
with urllib.request.urlopen(request, timeout=900) as response:
    for raw in response:
        line = raw.decode("utf-8").strip()
        if not line.startswith("data: "):
            continue
        payload = line[len("data: "):]
        if payload == "[DONE]":
            break
        event = json.loads(payload)
        if event.get("content"):
            first = time.monotonic_ns()
            break
if first is None:
    sys.stderr.write("the streamed reply carried no content delta\n")
    raise SystemExit(1)
with open(f"{arm}/ttft.tsv", "w", encoding="utf-8") as handle:
    handle.write("key\tvalue\n")
    handle.write(f"request_begin_ns\t{begin}\n")
    handle.write(f"first_token_ns\t{first}\n")
    handle.write(f"ttft_ms\t{(first - begin) / 1_000_000:.3f}\n")
PY
    return "$baseline_ttft_status"
}

# baseline_decode_block ARM_DIRECTORY ENDPOINT BODY API_KEY REPEATS PREDICT
#
# The repeats run back to back inside one warm session, so the block measures
# steady decode rather than the load beside it. Each reply is retained whole and
# its token ids are written as one id per line; the digest over that canonical
# form is the row the summary compares repeat against repeat, and a divergent
# arm is recorded rather than aborted, since a checkpoint that answers one fixed
# request two ways is the finding this block exists to surface.
baseline_decode_block() {
    baseline_arm=$1
    baseline_endpoint=$2
    baseline_body=$3
    baseline_key=$4
    baseline_repeats=$5
    baseline_predict=$6
    mkdir -p "$baseline_arm/repeats"
    printf 'repeat\tdecode_tok_per_second\tdecode_ms\tprompt_n\tpredicted_n\ttokens_sha256\n' \
        >"$baseline_arm/decode-rows.tsv"
    baseline_repeat_index=1
    while [ "$baseline_repeat_index" -le "$baseline_repeats" ]; do
        baseline_repeat_label=$(printf '%02d' "$baseline_repeat_index")
        baseline_repeat_directory=$baseline_arm/repeats/$baseline_repeat_label
        mkdir -p "$baseline_repeat_directory"
        if [ -n "$baseline_key" ]; then
            curl --silent --show-error --fail-with-body --max-time 900 \
                --header 'Content-Type: application/json' \
                --header "Authorization: Bearer $baseline_key" \
                --data @"$baseline_body" "$baseline_endpoint/completion" \
                >"$baseline_repeat_directory/response.json" || return 1
        else
            curl --silent --show-error --fail-with-body --max-time 900 \
                --header 'Content-Type: application/json' \
                --data @"$baseline_body" "$baseline_endpoint/completion" \
                >"$baseline_repeat_directory/response.json" || return 1
        fi
        python3 - "$baseline_repeat_directory" "$baseline_repeat_label" \
            "$baseline_predict" >>"$baseline_arm/decode-rows.tsv" <<'PY' || return 1
import hashlib
import json
import sys

directory, label, predict = sys.argv[1:4]
document = json.load(open(f"{directory}/response.json", encoding="utf-8"))
tokens = document.get("tokens")
if not isinstance(tokens, list) or len(tokens) != int(predict):
    raise SystemExit(
        f"repeat {label} returned {len(tokens) if isinstance(tokens, list) else 'no'} "
        f"tokens where {predict} were requested"
    )
if any(isinstance(value, bool) or not isinstance(value, int) for value in tokens):
    raise SystemExit(f"repeat {label} token array holds a non-integer entry")
text = "".join(f"{value}\n" for value in tokens)
with open(f"{directory}/tokens.txt", "w", encoding="utf-8") as handle:
    handle.write(text)
timings = document.get("timings")
if not isinstance(timings, dict):
    raise SystemExit(f"repeat {label} reply carries no timings object")
rate = timings.get("predicted_per_second")
elapsed = timings.get("predicted_ms")
if not isinstance(rate, (int, float)) or not rate > 0:
    raise SystemExit(f"repeat {label} reports no positive decode rate")
digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
print(
    label, rate, elapsed, timings.get("prompt_n"), timings.get("predicted_n"),
    digest, sep="\t",
)
PY
        baseline_repeat_index=$((baseline_repeat_index + 1))
    done
}

# baseline_retain_runtime_evidence ARM_DIRECTORY STATE_DIRECTORY
#
# The session's own logs are the arm's device record: the graphics latency probe
# states what the frame path did under the decode block, and the kernel hazard
# watcher states whether a ring timeout, a GPU reset, a VM fault, or an
# out-of-memory kill landed inside the window. A hazard makes the arm's rate a
# measurement of a recovering device, so the arm fails on it here.
baseline_retain_runtime_evidence() {
    baseline_arm=$1
    baseline_state=$2
    for baseline_log in server.log graphics-latency.log kernel-hazards.log; do
        baseline_source=$baseline_state/$baseline_log
        if [ ! -f "$baseline_source" ] || [ -L "$baseline_source" ] || \
            [ ! -s "$baseline_source" ]; then
            printf 'served runtime log is absent, linked, or empty: %s\n' \
                "$baseline_source" >&2
            return 1
        fi
        cp -- "$baseline_source" "$baseline_arm/$baseline_log" || return 1
    done
    if grep -Ev '^hazard_pattern=' "$baseline_arm/kernel-hazards.log" | \
        grep -Eai 'ring[^[:cntrl:]]*timeout|GPU reset|amdgpu[^[:cntrl:]]*reset|VM fault|device loss|device lost|out of memory|oom-kill|^hazard_utc=' \
        >/dev/null; then
        printf 'the kernel hazard log records a terminal GPU or memory hazard\n' >&2
        return 1
    fi
    if [ -f "$baseline_state/session.status" ]; then
        cp -- "$baseline_state/session.status" "$baseline_arm/session.status" || return 1
    fi
}

# baseline_served_tuple ARM_DIRECTORY STATE_DIRECTORY
#
# The tuple a comparison rests on is the one the server actually ran, and
# qwen-capacity-policy.sh is what built it: the registry is the policy's input
# rather than its output, so a preset section, a cache override, or a validated
# depth bound would leave a registry read stating a tuple no process served.
# The session records the server pid, the argv is read from that process, and
# the six flags are projected out of it.
baseline_served_tuple() {
    baseline_arm=$1
    baseline_state=$2
    baseline_status_file=$baseline_state/session.status
    if [ ! -f "$baseline_status_file" ]; then
        printf 'the served session recorded no status file: %s\n' \
            "$baseline_status_file" >&2
        return 1
    fi
    baseline_server_pid=$(awk '{ for (field = 1; field <= NF; field++) {
        if ($field ~ /^server_pid=/) { split($field, parts, "="); print parts[2] } } }' \
        "$baseline_status_file" | tail -n 1)
    case $baseline_server_pid in
        '' | *[!0-9]*)
            printf 'the served session names no numeric server_pid: %s\n' \
                "$baseline_status_file" >&2
            return 1
            ;;
    esac
    python3 - "$baseline_server_pid" "$baseline_arm/served-tuple.tsv" <<'PY'
import sys
from pathlib import Path

pid, output = sys.argv[1:3]
argv = Path(f"/proc/{pid}/cmdline").read_bytes().decode("utf-8").split("\0")
argv = [value for value in argv if value]
flags = {
    "--ctx-size": "context",
    "--batch-size": "batch",
    "--ubatch-size": "ubatch",
    "--cache-type-k": "cache_type_k",
    "--cache-type-v": "cache_type_v",
    "--ctx-checkpoints": "ctx_checkpoints",
}
values = {name: "-" for name in flags.values()}
values["flash_attention"] = "-"
for index, entry in enumerate(argv):
    if entry in flags and index + 1 < len(argv):
        values[flags[entry]] = argv[index + 1]
    elif entry == "--flash-attn" and index + 1 < len(argv):
        values["flash_attention"] = argv[index + 1]
with open(output, "w", encoding="utf-8") as handle:
    handle.write("key\tvalue\n")
    handle.write(f"server_pid\t{pid}\n")
    for name in sorted(values):
        handle.write(f"{name}\t{values[name]}\n")
PY
}

# baseline_compare_tuple SERVED_TUPLE CONTEXT BATCH UBATCH CACHE_K CACHE_V \
#     FLASH CTX_CHECKPOINTS
#
# The seven fields the registry states and qwen-capacity-policy.sh writes into
# the single-model argv under the same spellings: `--flash-attn` carries the
# registry's own `on` or `off` and the cache types carry the registry's own
# names, so the comparison is over literals rather than over a normalization
# that would admit two readings of one field. A difference names the field, the
# served value, and the registry value, because a tuple that moved is read by
# which field moved.
baseline_compare_tuple() {
    baseline_tuple_file=$1
    shift
    baseline_tuple_mismatch=0
    baseline_tuple_names='context batch ubatch cache_type_k cache_type_v flash_attention ctx_checkpoints'
    for baseline_tuple_name in $baseline_tuple_names; do
        baseline_tuple_expected=$1
        shift
        baseline_tuple_served=$(awk -F'\t' -v name="$baseline_tuple_name" \
            '$1 == name { count++; value = $2 }
            END { if (count != 1) exit 1; print value }' "$baseline_tuple_file") || {
            printf 'the served tuple record names %s other than once: %s\n' \
                "$baseline_tuple_name" "$baseline_tuple_file" >&2
            baseline_tuple_mismatch=1
            continue
        }
        if [ "$baseline_tuple_served" != "$baseline_tuple_expected" ]; then
            printf 'the served %s is %s where the registry row states %s\n' \
                "$baseline_tuple_name" "$baseline_tuple_served" \
                "$baseline_tuple_expected" >&2
            baseline_tuple_mismatch=1
        fi
    done
    [ "$baseline_tuple_mismatch" -eq 0 ]
}
