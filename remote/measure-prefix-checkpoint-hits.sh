#!/bin/sh
set -eu

# Whether the schema-bound prefix checkpoint of
# patches/llama-server-prefix-checkpoint.patch actually hits, read against a
# router that is already serving. Unlike run-prefill-ladder.sh this harness
# starts no server and owns no device: the pin is process-scoped state a
# served child already carries, so the measurement is a scripted request
# sequence against that child's own origin and its own log file, read exactly
# as evidence/tool-prefix-checkpoint/README.md's falsifiers require -- from
# the server's own lines rather than from an assumption about what armed.
#
# The sequence has four phases, run in this order against one router origin:
#
#   stable    QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS chat requests sharing
#             one system prompt and one tool-schema set, each with its own
#             fixed-length user message. The first is cold -- the process's
#             first eligible request pins the head it meets, so arm one pays
#             for the whole head and every later one is offered a restore.
#   schema_change  one chat request under an altered tool-schema set, same
#             system prompt. The rendered head diverges inside itself, so the
#             pin's covers() check rejects it and the request is charged in
#             full; the pin itself survives untouched, since only a captured
#             empty pin fills, never an unrelated request's head.
#   recovery_after_schema_change  one further stable-phase request, which
#             checks that the original pin still answers after the divergent
#             request ran, rather than assuming it does.
#   template_change  one request sent to the raw /completion route instead of
#             /v1/chat/completions. No chat template runs there, so no head is
#             rendered and neither a capture nor a restore is ever attempted;
#             the request is charged in full for a different reason than the
#             schema change is.
#   recovery_after_template_change  one further stable-phase request, the
#             same check run against the other disruptor.
#
# Every request records its own identity -- the SHA-256 the harness computes
# over the system prompt and the canonicalized tool-schema array it sent -- so
# a change in that digest is what the harness calls a schema or template
# change, checked against the request rather than assumed from the phase
# label alone. The server's own checkpoint key, read off the "captured" or
# "restored" log line the request's own window carries, is recorded beside it:
# a hit is confirmed only where charged tokens fell, the log carried a
# "restored" line, and that line named the same key the previous hit or the
# capture named, and an invalidation is confirmed only where the identity
# digest moved and the log carried neither line.
#
# usage: measure-prefix-checkpoint-hits.sh ROUTER_ORIGIN SERVER_LOG OUTPUT_DIR
#   QWEN_PREFIX_CHECKPOINT_HITS_MODEL          the request body's "model"
#                                               field; default unset (omitted)
#   QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS  stable-phase conversation
#                                               count, default 3, minimum 2
#   QWEN_PREFIX_CHECKPOINT_HITS_USER_WORDS     words per fixed-length user
#                                               message, default 8
#   QWEN_PREFIX_CHECKPOINT_HITS_GENERATE       reply token budget, default 8
#   QWEN_PREFIX_CHECKPOINT_HITS_REQUEST_SECONDS  per-request deadline, default
#                                               120
#   QWEN_PREFIX_CHECKPOINT_HITS_READY_SECONDS  /health poll budget, default 30
#   QWEN_PREFIX_CHECKPOINT_HITS_SYSTEM_PROMPT  the shared system prompt
#   QWEN_PREFIX_CHECKPOINT_HITS_TOOLS_JSON     path to the shared tool-schema
#                                               array; default a two-tool
#                                               fixture the harness writes
#   QWEN_PREFIX_CHECKPOINT_HITS_ALT_TOOLS_JSON path to the altered tool-schema
#                                               array for the schema_change
#                                               phase; default a fixture with
#                                               one tool added
#   QWEN_PREFIX_CHECKPOINT_HITS_SERVER_PID     the served child's PID; when
#                                               set, lifetime_s is read from
#                                               /proc/PID/stat and /proc/uptime
#                                               the way qwen-teardown.sh reads
#                                               a guarded child's identity;
#                                               unset leaves lifetime_s "-"
#   QWEN_PREFIX_CHECKPOINT_HITS_SLOTS_ROUTE    the introspection route probed
#                                               once per request and retained
#                                               verbatim, default /slots
#   QWEN_PREFIX_CHECKPOINT_HITS_SUMMARIZER     path to the summarizer

if [ "$#" -ne 3 ]; then
    printf 'usage: %s ROUTER_ORIGIN SERVER_LOG OUTPUT_DIR\n' "$0" >&2
    exit 2
fi
router_origin=$1
server_log=$2
output_directory=$3
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
summarizer=${QWEN_PREFIX_CHECKPOINT_HITS_SUMMARIZER:-"$script_directory/summarize-prefix-checkpoint-hits.py"}

model_id=${QWEN_PREFIX_CHECKPOINT_HITS_MODEL:-}
conversations=${QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS:-3}
user_words=${QWEN_PREFIX_CHECKPOINT_HITS_USER_WORDS:-8}
generate_tokens=${QWEN_PREFIX_CHECKPOINT_HITS_GENERATE:-8}
request_seconds=${QWEN_PREFIX_CHECKPOINT_HITS_REQUEST_SECONDS:-120}
ready_seconds=${QWEN_PREFIX_CHECKPOINT_HITS_READY_SECONDS:-30}
system_prompt=${QWEN_PREFIX_CHECKPOINT_HITS_SYSTEM_PROMPT:-"You are a careful assistant that answers in one short sentence."}
tools_json=${QWEN_PREFIX_CHECKPOINT_HITS_TOOLS_JSON:-}
alt_tools_json=${QWEN_PREFIX_CHECKPOINT_HITS_ALT_TOOLS_JSON:-}
server_pid=${QWEN_PREFIX_CHECKPOINT_HITS_SERVER_PID:-}
slots_route=${QWEN_PREFIX_CHECKPOINT_HITS_SLOTS_ROUTE:-/slots}

positive_integer() {
    case $2 in
        '' | *[!0-9]* | 0 | 0*)
            printf '%s is a canonical positive integer: %s\n' "$1" "$2" >&2
            exit 2
            ;;
    esac
}
positive_integer QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS "$conversations"
positive_integer QWEN_PREFIX_CHECKPOINT_HITS_USER_WORDS "$user_words"
positive_integer QWEN_PREFIX_CHECKPOINT_HITS_GENERATE "$generate_tokens"
positive_integer QWEN_PREFIX_CHECKPOINT_HITS_READY_SECONDS "$ready_seconds"
positive_integer QWEN_PREFIX_CHECKPOINT_HITS_REQUEST_SECONDS "$request_seconds"
if [ "$conversations" -lt 2 ]; then
    printf 'QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS names at least 2 conversations, the cold one and one reuse candidate: %s\n' \
        "$conversations" >&2
    exit 2
fi
if [ -n "$server_pid" ]; then
    case $server_pid in
        '' | *[!0-9]*)
            printf 'QWEN_PREFIX_CHECKPOINT_HITS_SERVER_PID is a process id: %s\n' \
                "$server_pid" >&2
            exit 2
            ;;
    esac
fi
if [ ! -r "$summarizer" ]; then
    printf 'summarizer is absent: %s\n' "$summarizer" >&2
    exit 2
fi
if [ ! -r "$server_log" ]; then
    printf 'server log is unreadable: %s\n' "$server_log" >&2
    exit 2
fi
case $output_directory in
    /*) ;;
    *)
        printf 'output directory must be absolute: %s\n' "$output_directory" >&2
        exit 2
        ;;
esac
if [ -e "$output_directory" ]; then
    printf 'output directory must be absent; a run never appends to one: %s\n' \
        "$output_directory" >&2
    exit 2
fi

if ! curl --silent --fail --max-time "$ready_seconds" "$router_origin/health" \
    >/dev/null 2>&1; then
    printf 'router does not answer /health at %s within %s seconds\n' \
        "$router_origin" "$ready_seconds" >&2
    exit 2
fi

umask 077
mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)

if [ -z "$tools_json" ]; then
    tools_json=$output_directory/tools.json
    cat >"$tools_json" <<'JSON'
[
  {"type": "function", "function": {"name": "get_weather",
    "description": "Report the weather for one place.",
    "parameters": {"type": "object",
      "properties": {"place": {"type": "string"}}, "required": ["place"]}}},
  {"type": "function", "function": {"name": "convert_units",
    "description": "Convert one numeric value between two named units.",
    "parameters": {"type": "object",
      "properties": {"value": {"type": "number"},
        "from_unit": {"type": "string"}, "to_unit": {"type": "string"}},
      "required": ["value", "from_unit", "to_unit"]}}}
]
JSON
fi
if [ -z "$alt_tools_json" ]; then
    alt_tools_json=$output_directory/alt-tools.json
    cat >"$alt_tools_json" <<'JSON'
[
  {"type": "function", "function": {"name": "get_weather",
    "description": "Report the weather for one place.",
    "parameters": {"type": "object",
      "properties": {"place": {"type": "string"}}, "required": ["place"]}}},
  {"type": "function", "function": {"name": "convert_units",
    "description": "Convert one numeric value between two named units.",
    "parameters": {"type": "object",
      "properties": {"value": {"type": "number"},
        "from_unit": {"type": "string"}, "to_unit": {"type": "string"}},
      "required": ["value", "from_unit", "to_unit"]}}},
  {"type": "function", "function": {"name": "search_notes",
    "description": "Search the user's own notes for one query.",
    "parameters": {"type": "object",
      "properties": {"query": {"type": "string"}}, "required": ["query"]}}}
]
JSON
fi
for reader in "$tools_json" "$alt_tools_json"; do
    if [ ! -r "$reader" ]; then
        printf 'tool-schema file is unreadable: %s\n' "$reader" >&2
        exit 2
    fi
done

request_client=$output_directory/request-arm.py
cat >"$request_client" <<'PYTHON'
"""Post one chat or raw completion and report the fields the ledger states.

Every timing the ledger states is required, the discipline
run-prefill-ladder.sh's own request client applies: a reply whose `timings`
object omits one, or states it as something other than a finite positive
number, ends this reader with `missing_timings` rather than a zero, since a
rate of nothing pairs as a measurement.
"""
import hashlib
import json
import math
import sys
import urllib.request

(origin, route, system_prompt, user_prompt, tools_path, model_id, predict,
 deadline_s, destination) = sys.argv[1:10]
predict = int(predict)

if route == "chat":
    with open(tools_path, encoding="utf-8") as handle:
        tools = json.load(handle)
    identity = hashlib.sha256(
        (system_prompt + "\x00" + json.dumps(tools, sort_keys=True)).encode()
    ).hexdigest()
    body = {
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "tools": tools,
        "temperature": 0,
        "max_tokens": predict,
    }
    if model_id:
        body["model"] = model_id
    path = "/v1/chat/completions"
else:
    identity = hashlib.sha256(("\x00" + user_prompt).encode()).hexdigest()
    body = {
        "prompt": user_prompt,
        "n_predict": predict,
        "temperature": 0,
    }
    path = "/completion"

request = urllib.request.Request(
    f"{origin}{path}", data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json"})
with urllib.request.urlopen(request, timeout=float(deadline_s)) as response:
    payload = json.loads(response.read().decode())

timings = payload.get("timings")
if not isinstance(timings, dict):
    sys.stderr.write("missing_timings\n")
    raise SystemExit(1)
required = ("prompt_n", "prompt_ms", "predicted_n")
values = {}
for name in required:
    value = timings.get(name)
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        sys.stderr.write(f"missing_timings field={name}\n")
        raise SystemExit(1)
    value = float(value)
    if not math.isfinite(value) or value < 0:
        sys.stderr.write(f"timings_nonpositive field={name} value={value:.6g}\n")
        raise SystemExit(1)
    values[name] = value

with open(destination, "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
print(f"identity_sha256={identity}")
print(f"prompt_n={values['prompt_n']:.6g}")
print(f"prompt_ms={values['prompt_ms']:.6g}")
print(f"predicted_n={values['predicted_n']:.6g}")
PYTHON

# One field of the reader's own `name=value` record.
measurement_field() {
    awk -F= -v key="$2" '$1 == key { print $2; exit }' "$1"
}

# The log window a request's own capture or restore line must fall inside:
# the byte offset before the request and the offset after it, so a line
# written by an unrelated concurrent request on this router -- another
# section, another slot -- never attaches to this one. The window is read
# with `tail -c +OFFSET`, POSIX `tail`'s 1-based byte offset, so the first
# byte the window keeps is the first byte appended since the previous read.
# The byte count is read by the caller's own `wc -c` rather than smuggled
# through this function's stdout beside the window text: a log caught
# mid-flush -- a line written without its trailing newline yet -- would leave
# a newline-delimited "last line is the count" convention reading a partial
# line as the count instead.
log_window() {
    log_window_before=$1
    log_window_after_bytes=$(wc -c <"$server_log" | tr -d ' ')
    if [ "$log_window_after_bytes" -gt "$log_window_before" ]; then
        tail -c "+$((log_window_before + 1))" "$server_log"
    fi
}

lifetime_seconds() {
    [ -n "$server_pid" ] && [ -r "/proc/$server_pid/stat" ] || { printf -- '-\n'; return 0; }
    lifetime_ticks=$(sed 's/^.*) //' "/proc/$server_pid/stat" | awk '{ print $20 }')
    lifetime_hz=$(getconf CLK_TCK 2>/dev/null || printf '100\n')
    lifetime_uptime=$(awk '{ print $1; exit }' /proc/uptime)
    if [ -z "$lifetime_ticks" ] || [ -z "$lifetime_hz" ] || [ -z "$lifetime_uptime" ]; then
        printf -- '-\n'
        return 0
    fi
    awk -v ticks="$lifetime_ticks" -v hz="$lifetime_hz" -v uptime="$lifetime_uptime" \
        'BEGIN { printf "%.3f\n", uptime - (ticks / hz) }'
}

requests_ledger=$output_directory/requests.tsv
printf 'slot\tphase\tconversation\troute\tidentity_sha256\tprompt_n\tprompt_ms\tprompt_tok_s\tpredicted_n\thit\tcapture_seen\tcheckpoint_key\tknown_pin_key\tcheckpoint_size_mib\toperation_ms\tavoided_prompt_tokens\tavoided_prompt_ms\tlifetime_s\tlog_bytes_scanned\tstatus\treason\n' \
    >"$requests_ledger"

record_request() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" \
        "${13}" "${14}" "${15}" "${16}" "${17}" "${18}" "${19}" "${20}" "${21}" \
        >>"$requests_ledger"
}

system_prompt_sha256=$(printf '%s' "$system_prompt" | sha256sum | cut -d ' ' -f 1)
tools_json_sha256=$(sha256sum "$tools_json" | cut -d ' ' -f 1)
alt_tools_json_sha256=$(sha256sum "$alt_tools_json" | cut -d ' ' -f 1)
{
    printf 'router_origin\t%s\nserver_log\t%s\nmodel_id\t%s\n' "$router_origin" \
        "$server_log" "${model_id:--}"
    printf 'conversations\t%s\nuser_words\t%s\ngenerate_tokens\t%s\n' \
        "$conversations" "$user_words" "$generate_tokens"
    printf 'system_prompt_sha256\t%s\ntools_json\t%s\ntools_json_sha256\t%s\n' \
        "$system_prompt_sha256" "$tools_json" "$tools_json_sha256"
    printf 'alt_tools_json\t%s\nalt_tools_json_sha256\t%s\n' "$alt_tools_json" \
        "$alt_tools_json_sha256"
    printf 'server_pid\t%s\nslots_route\t%s\n' "${server_pid:--}" "$slots_route"
} >"$output_directory/inputs.tsv"

known_pin_key=-
baseline_prompt_n=-
baseline_prompt_ms=-
slot=0
request_failures=0

run_request() {
    run_request_phase=$1
    run_request_conversation=$2
    run_request_route=$3
    run_request_user_prompt=$4
    run_request_tools_json=$5
    slot=$((slot + 1))
    arm_directory=$output_directory/requests/$slot-$run_request_phase
    mkdir -p "$arm_directory"

    log_bytes_before=$(wc -c <"$server_log" | tr -d ' ')

    status=completed
    reason=-
    identity=-
    prompt_n=-
    prompt_ms=-
    prompt_tok_s=-
    predicted_n=-

    set +e
    reply=$(python3 "$request_client" "$router_origin" "$run_request_route" \
        "$system_prompt" "$run_request_user_prompt" "$run_request_tools_json" \
        "$model_id" "$generate_tokens" "$request_seconds" \
        "$arm_directory/response.json" 2>"$arm_directory/request.stderr")
    reply_status=$?
    set -e
    if [ "$reply_status" -ne 0 ]; then
        status=failed
        reason=$(awk 'NR == 1 { print $1 }' "$arm_directory/request.stderr")
        [ -n "$reason" ] || reason=request_failed
    else
        printf '%s\n' "$reply" >"$arm_directory/measurement.txt"
        identity=$(measurement_field "$arm_directory/measurement.txt" identity_sha256)
        prompt_n=$(measurement_field "$arm_directory/measurement.txt" prompt_n)
        prompt_ms=$(measurement_field "$arm_directory/measurement.txt" prompt_ms)
        predicted_n=$(measurement_field "$arm_directory/measurement.txt" predicted_n)
        if awk -v ms="$prompt_ms" 'BEGIN { exit (ms + 0 > 0) ? 0 : 1 }'; then
            prompt_tok_s=$(awk -v n="$prompt_n" -v ms="$prompt_ms" \
                'BEGIN { printf "%.6g", n / ms * 1000.0 }')
        fi
    fi

    curl --silent --fail --max-time 10 "$router_origin$slots_route" \
        >"$arm_directory/introspection.txt" 2>/dev/null || true

    log_window_text=$(log_window "$log_bytes_before")
    log_bytes_after=$(wc -c <"$server_log" | tr -d ' ')
    printf '%s\n' "$log_window_text" >"$arm_directory/log-window.txt"

    hit=no
    capture_seen=no
    checkpoint_key=-
    checkpoint_size_mib=-
    operation_ms=-
    if printf '%s\n' "$log_window_text" | grep -q 'restored prefix checkpoint'; then
        hit=yes
        restore_line=$(printf '%s\n' "$log_window_text" \
            | grep 'restored prefix checkpoint' | tail -1)
        checkpoint_size_mib=$(printf '%s\n' "$restore_line" \
            | sed -n 's/.*size = \([0-9.]*\) MiB.*/\1/p')
        operation_ms=$(printf '%s\n' "$restore_line" \
            | sed -n 's/.*took \([0-9.]*\) ms.*/\1/p')
        checkpoint_key=$(printf '%s\n' "$restore_line" \
            | sed -n 's/.*key = \([^ ,]*\).*/\1/p')
        known_pin_key=${checkpoint_key:-$known_pin_key}
    elif printf '%s\n' "$log_window_text" | grep -q 'captured prefix checkpoint'; then
        capture_seen=yes
        capture_line=$(printf '%s\n' "$log_window_text" \
            | grep 'captured prefix checkpoint' | tail -1)
        checkpoint_size_mib=$(printf '%s\n' "$capture_line" \
            | sed -n 's/.*size = \([0-9.]*\) MiB.*/\1/p')
        operation_ms=$(printf '%s\n' "$capture_line" \
            | sed -n 's/.*took \([0-9.]*\) ms.*/\1/p')
        checkpoint_key=$(printf '%s\n' "$capture_line" \
            | sed -n 's/.*key = \([^ ,]*\).*/\1/p')
        known_pin_key=${checkpoint_key:-$known_pin_key}
    fi

    avoided_tokens=-
    avoided_ms=-
    if [ "$status" = completed ] && [ "$baseline_prompt_n" != - ]; then
        avoided_tokens=$(awk -v b="$baseline_prompt_n" -v p="$prompt_n" \
            'BEGIN { printf "%.6g", b - p }')
        avoided_ms=$(awk -v b="$baseline_prompt_ms" -v p="$prompt_ms" \
            'BEGIN { printf "%.6g", b - p }')
    fi
    if [ "$status" = completed ] && [ "$baseline_prompt_n" = - ]; then
        baseline_prompt_n=$prompt_n
        baseline_prompt_ms=$prompt_ms
    fi

    # The ledger states the bytes this request's own window covered, not the
    # log's total size: a server that has been serving for a while carries
    # bytes from every earlier request, and reading the absolute size here
    # would inflate every row by that history rather than reporting what this
    # request alone appended.
    log_bytes_scanned=$((log_bytes_after - log_bytes_before))

    [ "$status" = completed ] || request_failures=$((request_failures + 1))
    record_request "$slot" "$run_request_phase" "$run_request_conversation" \
        "$run_request_route" "$identity" "$prompt_n" "$prompt_ms" \
        "$prompt_tok_s" "$predicted_n" "$hit" "$capture_seen" \
        "${checkpoint_key:--}" "$known_pin_key" "${checkpoint_size_mib:--}" \
        "${operation_ms:--}" "$avoided_tokens" "$avoided_ms" \
        "$(lifetime_seconds)" "$log_bytes_scanned" "$status" "$reason"
    printf 'prefix_checkpoint_hits_request=%s slot=%s phase=%s hit=%s capture_seen=%s prompt_n=%s reason=%s\n' \
        "$status" "$slot" "$run_request_phase" "$hit" "$capture_seen" "$prompt_n" "$reason"
}

conversation_index=0
while [ "$conversation_index" -lt "$conversations" ]; do
    conversation_index=$((conversation_index + 1))
    user_prompt=$(awk -v n="$user_words" -v tag="stable-$conversation_index" \
        'BEGIN { out = tag; for (i = 2; i <= n; i++) out = out " filler"; print out }')
    run_request stable "$conversation_index" chat "$user_prompt" "$tools_json"
done

schema_user_prompt=$(awk -v n="$user_words" \
    'BEGIN { out = "schema-change"; for (i = 2; i <= n; i++) out = out " filler"; print out }')
run_request schema_change 1 chat "$schema_user_prompt" "$alt_tools_json"

recovery_user_prompt=$(awk -v n="$user_words" \
    'BEGIN { out = "recovery-a"; for (i = 2; i <= n; i++) out = out " filler"; print out }')
run_request recovery_after_schema_change 1 chat "$recovery_user_prompt" "$tools_json"

template_user_prompt=$(awk -v n="$user_words" \
    'BEGIN { out = "template-change"; for (i = 2; i <= n; i++) out = out " filler"; print out }')
run_request template_change 1 raw "$template_user_prompt" "$tools_json"

recovery_b_user_prompt=$(awk -v n="$user_words" \
    'BEGIN { out = "recovery-b"; for (i = 2; i <= n; i++) out = out " filler"; print out }')
run_request recovery_after_template_change 1 chat "$recovery_b_user_prompt" "$tools_json"

python3 "$summarizer" "$requests_ledger" >"$output_directory/summary.tsv"
printf 'prefix_checkpoint_hits=%s failed_requests=%s output=%s\n' \
    "$([ "$request_failures" -eq 0 ] && printf completed || printf failed)" \
    "$request_failures" "$output_directory"
[ "$request_failures" -eq 0 ]
