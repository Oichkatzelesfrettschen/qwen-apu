#!/bin/sh
set -eu

# A coding agent pointed at the appliance reaches five routes and nothing
# else: GET /v1/models supplies the registry ids it may name, POST
# /v1/messages runs a turn (streamed or not, plain or forcing a tool call),
# POST /v1/messages/count_tokens sizes a prompt before it is sent, and POST
# /v1/chat/completions is the OpenAI-compatible route OpenCode uses.
# tools/server/server.cpp registers all four POST routes and the router
# proxies each by the body's top-level "model", so this check proves the
# routing key reaches a child and comes back echoed, on every requested id
# rather than the first alone. It needs a running appliance and stays out of
# the repository gate for that reason; remote/test-fixtures/fake-code-agent-server.py
# stands in for one so the check logic itself is proven by
# remote/test-code-agent-endpoint-fixture.sh, which is a gate cell.
#
# usage: QWEN_CODE_AGENT_ORIGIN=http://qwen-laptop:8080 \
#        QWEN_CODE_AGENT_KEY_FILE=$HOME/.config/qwen/appliance.key \
#        remote/test-code-agent-endpoint.sh MODEL_ID [MODEL_ID...]

usage() {
    printf 'usage: QWEN_CODE_AGENT_ORIGIN=URL QWEN_CODE_AGENT_KEY_FILE=PATH %s MODEL_ID [MODEL_ID...]\n' "$0" >&2
    exit 2
}

[ "$#" -ge 1 ] || usage
origin=${QWEN_CODE_AGENT_ORIGIN:-}
key_file=${QWEN_CODE_AGENT_KEY_FILE:-}
[ -n "$origin" ] || usage
[ -n "$key_file" ] || usage
case $origin in
    http://*|https://*) ;;
    *) usage ;;
esac
origin=${origin%/}
[ -s "$key_file" ] || usage
command -v curl >/dev/null 2>&1 || usage
command -v python3 >/dev/null 2>&1 || usage

failures=0
work_directory=$(mktemp -d)
cleanup() {
    rm -f -- "$work_directory/api-key.curl" "$work_directory/body" "$work_directory/out"
    rmdir -- "$work_directory" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

report() {
    printf '%s=%s %s\n' "$1" "$2" "${3:-}"
    [ "$2" = pass ] || failures=$((failures + 1))
}

# The key reaches curl through a 0600 config file, so it stays out of the
# process arguments every other user on the host can read.
umask 077
printf 'header = "Authorization: Bearer %s"\n' "$(sed -n '1p' "$key_file")" \
    >"$work_directory/api-key.curl"

call() {
    call_method=$1
    call_route=$2
    if [ "$call_method" = GET ]; then
        curl -sS -m 900 --config "$work_directory/api-key.curl" \
            -o "$work_directory/out" -w '%{http_code}' \
            "$origin$call_route"
    else
        curl -sS -N -m 900 --config "$work_directory/api-key.curl" \
            -H 'content-type: application/json' \
            -H 'anthropic-version: 2023-06-01' \
            --data-binary @"$work_directory/body" \
            -o "$work_directory/out" -w '%{http_code}' \
            "$origin$call_route"
    fi
}

# Every field this check reads comes out of one reader over the retained reply,
# so a malformed body reports an empty field rather than aborting the shell that
# parsed it. The selectors name the reply shapes the routes return.
read_field() {
    python3 - "$work_directory/out" "$1" <<'PYTHON' 2>/dev/null || true
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        document = json.load(handle)
except (OSError, ValueError):
    sys.exit(1)

selector = sys.argv[2]
if selector == "model_ids":
    for entry in document.get("data", []):
        print(entry.get("id", ""))
elif selector == "reply_model":
    print(document.get("model", ""))
elif selector == "reply_text_length":
    print(len("".join(
        block.get("text", "")
        for block in document.get("content", [])
        if block.get("type") == "text"
    ).strip()))
elif selector == "input_tokens":
    print(document.get("input_tokens", -1))
elif selector == "usage_input_tokens":
    print(document.get("usage", {}).get("input_tokens", -1))
elif selector == "usage_output_tokens":
    print(document.get("usage", {}).get("output_tokens", -1))
elif selector == "usage_cache_read_input_tokens":
    print(document.get("usage", {}).get("cache_read_input_tokens", -1))
elif selector == "tool_use_name":
    for block in document.get("content", []):
        if block.get("type") == "tool_use":
            print(block.get("name", ""))
            break
elif selector == "tool_use_id_present":
    found = False
    for block in document.get("content", []):
        if block.get("type") == "tool_use":
            print(1 if block.get("id") else 0)
            found = True
            break
    if not found:
        print(0)
elif selector == "chat_completion_model":
    print(document.get("model", ""))
elif selector == "chat_completion_text_length":
    choices = document.get("choices", [])
    text = ""
    if choices:
        message = choices[0].get("message", {}) or {}
        text = message.get("content", "") or ""
    print(len(text.strip()))
PYTHON
}

# The SSE reply is not one JSON document; it is a sequence of "event: TYPE"
# lines each followed by a "data: {...}" line. The summary reads the union of
# both -- the event line's own name and the "type" field inside its data --
# because format_anthropic_sse's exact framing is not in this repository to
# grep, and a parser keyed on one alone would silently pass a stream that
# carries the type only in the other.
read_sse_summary() {
    python3 - "$work_directory/out" <<'PYTHON' 2>/dev/null || true
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
except OSError:
    print("start=False delta=False stop=False order=False events=0")
    raise SystemExit

event_types = []
for line in text.splitlines():
    if line.startswith("event: "):
        event_types.append(line[len("event: "):].strip())
    elif line.startswith("data: "):
        try:
            payload = json.loads(line[len("data: "):])
        except ValueError:
            continue
        data_type = payload.get("type")
        if data_type:
            event_types.append(data_type)

has_start = "message_start" in event_types
has_delta = "content_block_delta" in event_types
has_stop = "message_stop" in event_types
in_order = (
    has_start and has_stop
    and event_types.index("message_start") < event_types.index("message_stop")
)
print(
    "start=%s delta=%s stop=%s order=%s events=%d"
    % (has_start, has_delta, has_stop, in_order, len(event_types))
)
PYTHON
}

request_body() {
    python3 - "$1" "$2" >"$work_directory/body" <<'PYTHON'
import json
import sys

body = {
    "model": sys.argv[1],
    "messages": [{"role": "user", "content": "Reply with the single word ready."}],
}
mode = sys.argv[2]
if mode in ("generate", "stream"):
    body["max_tokens"] = 32
    body["temperature"] = 0
    body["chat_template_kwargs"] = {"enable_thinking": False}
    if mode == "stream":
        body["stream"] = True
elif mode == "tools":
    body["max_tokens"] = 64
    body["temperature"] = 0
    body["chat_template_kwargs"] = {"enable_thinking": False}
    body["tools"] = [
        {
            "name": "report_ready",
            "description": "Report that the endpoint answered. Takes no arguments.",
            "input_schema": {
                "type": "object",
                "properties": {},
                "additionalProperties": False,
            },
        }
    ]
    # "any" rather than a forced tool name: this proves the Anthropic tool
    # conversion round-trips a tool_use block without depending on
    # forced-by-name support, which is a narrower and separately variable
    # capability.
    body["tool_choice"] = {"type": "any"}
elif mode == "chat":
    body["max_tokens"] = 32
    body["temperature"] = 0
    body["chat_template_kwargs"] = {"enable_thinking": False}
print(json.dumps(body))
PYTHON
}

status=$(call GET /health) || status=000
if [ "$status" = 200 ]; then
    report health pass "status=200"
else
    report health fail "status=$status"
fi

status=$(call GET /v1/models) || status=000
if [ "$status" = 200 ]; then
    report models_listed pass "status=200"
else
    report models_listed fail "status=$status"
fi
served_ids=$(read_field model_ids)

# Every requested id runs the full route set below rather than the first
# alone, so a checkpoint present in the roster but broken at inference time --
# a missing file, a child that fails to start -- is caught for each id a
# caller names.
check_model() {
    model_id=$1

    if printf '%s\n' "$served_ids" | grep -qx -- "$model_id"; then
        report "model_present_$model_id" pass ''
    else
        report "model_present_$model_id" fail "absent from GET /v1/models"
    fi

    request_body "$model_id" generate
    status=$(call POST /v1/messages) || status=000
    if [ "$status" = 200 ]; then
        report "messages_answered_$model_id" pass "status=200"
    else
        report "messages_answered_$model_id" fail "status=$status $(head -c 160 "$work_directory/out" 2>/dev/null)"
    fi
    reply_model=$(read_field reply_model)
    if [ "$reply_model" = "$model_id" ]; then
        report "messages_model_echoed_$model_id" pass "model=$reply_model"
    else
        report "messages_model_echoed_$model_id" fail "requested=$model_id echoed=$reply_model"
    fi
    # Every usage field is read here, while the retained reply is still the one
    # the messages route returned; the routes called after this overwrite that
    # file.
    messages_input=$(read_field usage_input_tokens)
    messages_output=$(read_field usage_output_tokens)
    messages_cached=$(read_field usage_cache_read_input_tokens)
    messages_text_length=$(read_field reply_text_length)
    : "${messages_input:=-1}" "${messages_output:=-1}" "${messages_cached:=-1}"
    : "${messages_text_length:=0}"
    if [ "$messages_output" -gt 0 ] 2>/dev/null && [ "$messages_text_length" -gt 0 ]; then
        report "messages_usage_$model_id" pass "input_tokens=$messages_input output_tokens=$messages_output"
    else
        report "messages_usage_$model_id" fail "output_tokens=$messages_output text_characters=$messages_text_length"
    fi

    # A router that buffers or corrupts Anthropic SSE can still answer the
    # non-streamed request above with a complete JSON body, so streaming needs
    # its own request rather than being inferred from it.
    request_body "$model_id" stream
    status=$(call POST /v1/messages) || status=000
    if [ "$status" = 200 ]; then
        report "messages_streamed_$model_id" pass "status=200"
    else
        report "messages_streamed_$model_id" fail "status=$status $(head -c 160 "$work_directory/out" 2>/dev/null)"
    fi
    sse_summary=$(read_sse_summary)
    case $sse_summary in
        "start=True delta=True stop=True order=True"*)
            report "messages_stream_events_$model_id" pass "$sse_summary" ;;
        *)
            report "messages_stream_events_$model_id" fail "$sse_summary" ;;
    esac

    # A model that answers plain text fine can still fail the Anthropic tool
    # conversion Claude Code depends on for every file read, edit, and command;
    # forcing a call proves a tool_use block round-trips.
    request_body "$model_id" tools
    status=$(call POST /v1/messages) || status=000
    if [ "$status" = 200 ]; then
        report "messages_tool_use_answered_$model_id" pass "status=200"
    else
        report "messages_tool_use_answered_$model_id" fail "status=$status $(head -c 160 "$work_directory/out" 2>/dev/null)"
    fi
    tool_use_name=$(read_field tool_use_name)
    tool_use_id_present=$(read_field tool_use_id_present)
    : "${tool_use_id_present:=0}"
    if [ "$tool_use_name" = report_ready ] && [ "$tool_use_id_present" = 1 ]; then
        report "messages_tool_use_block_$model_id" pass "name=$tool_use_name"
    else
        report "messages_tool_use_block_$model_id" fail "name=$tool_use_name id_present=$tool_use_id_present"
    fi

    request_body "$model_id" count
    status=$(call POST /v1/messages/count_tokens) || status=000
    if [ "$status" = 200 ]; then
        report "count_tokens_answered_$model_id" pass "status=200"
    else
        report "count_tokens_answered_$model_id" fail "status=$status $(head -c 160 "$work_directory/out" 2>/dev/null)"
    fi
    counted=$(read_field input_tokens)
    : "${counted:=-1}"
    if [ "$counted" -gt 0 ] 2>/dev/null; then
        report "count_tokens_counted_$model_id" pass "input_tokens=$counted"
    else
        report "count_tokens_counted_$model_id" fail "input_tokens=$counted"
    fi

    # The two routes tokenize one prompt and report it split differently.
    # handle_count_tokens returns the whole tokenization from tokenize_mixed,
    # while to_json_anthropic sets input_tokens to n_prompt_tokens -
    # n_prompt_tokens_cache and puts the reused prefix in
    # cache_read_input_tokens, so the invariant across a warm cache is the sum
    # rather than either term. The count route tokenizes the message content
    # while the messages route charges the rendered chat template, so the
    # charged figure runs a couple of tokens ahead of the counted one; a gap
    # past that says the router sent the two requests to different children.
    if [ "$counted" -gt 0 ] 2>/dev/null && [ "$messages_input" -ge 0 ] 2>/dev/null \
        && [ "$messages_cached" -ge 0 ] 2>/dev/null; then
        charged=$((messages_input + messages_cached))
        spread=$((counted - charged))
        [ "$spread" -ge 0 ] || spread=$((-spread))
        if [ "$spread" -le 8 ]; then
            report "count_matches_usage_$model_id" pass "counted=$counted charged=$charged cached=$messages_cached"
        else
            report "count_matches_usage_$model_id" fail "counted=$counted charged=$charged cached=$messages_cached"
        fi
    else
        report "count_matches_usage_$model_id" fail "counted=$counted uncached=$messages_input cached=$messages_cached"
    fi

    # OpenCode reaches the OpenAI-compatible chat route rather than the
    # Anthropic Messages route; a regression confined to that proxy path
    # leaves every check above green while OpenCode itself cannot serve a
    # turn.
    request_body "$model_id" chat
    status=$(call POST /v1/chat/completions) || status=000
    if [ "$status" = 200 ]; then
        report "chat_completions_answered_$model_id" pass "status=200"
    else
        report "chat_completions_answered_$model_id" fail "status=$status $(head -c 160 "$work_directory/out" 2>/dev/null)"
    fi
    chat_text_length=$(read_field chat_completion_text_length)
    : "${chat_text_length:=0}"
    if [ "$chat_text_length" -gt 0 ] 2>/dev/null; then
        report "chat_completions_usage_$model_id" pass "text_characters=$chat_text_length"
    else
        report "chat_completions_usage_$model_id" fail "text_characters=$chat_text_length"
    fi
    chat_reply_model=$(read_field chat_completion_model)
    if [ "$chat_reply_model" = "$model_id" ]; then
        report "chat_completions_model_echoed_$model_id" pass "model=$chat_reply_model"
    else
        report "chat_completions_model_echoed_$model_id" fail "requested=$model_id echoed=$chat_reply_model"
    fi
}

for model_id in "$@"; do
    check_model "$model_id"
done

printf 'checks_failed=%d\n' "$failures"
[ "$failures" -eq 0 ] || exit 1
printf 'code_agent_endpoint=ready origin=%s models=%s\n' "$origin" "$*"
