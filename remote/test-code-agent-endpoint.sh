#!/bin/sh
set -eu

# A coding agent pointed at the appliance reaches three routes and nothing else:
# GET /v1/models supplies the registry ids it may name, POST /v1/messages runs
# the turn, and POST /v1/messages/count_tokens sizes a prompt before it is sent.
# tools/server/server.cpp registers all three and the router proxies the two
# POST routes by the body's top-level "model", so this check proves the routing
# key reaches a child and comes back echoed. It needs a running appliance and
# stays out of the repository gate for that reason.
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
        curl -sS -m 900 --config "$work_directory/api-key.curl" \
            -H 'content-type: application/json' \
            -H 'anthropic-version: 2023-06-01' \
            --data-binary @"$work_directory/body" \
            -o "$work_directory/out" -w '%{http_code}' \
            "$origin$call_route"
    fi
}

# Every field this check reads comes out of one reader over the retained reply,
# so a malformed body reports an empty field rather than aborting the shell that
# parsed it. The selectors name the three reply shapes the routes return.
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
if sys.argv[2] == "generate":
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

first_model=''
for model_id in "$@"; do
    [ -n "$first_model" ] || first_model=$model_id
    if printf '%s\n' "$served_ids" | grep -qx -- "$model_id"; then
        report "model_present_$model_id" pass ''
    else
        report "model_present_$model_id" fail "absent from GET /v1/models"
    fi
done

request_body "$first_model" generate
status=$(call POST /v1/messages) || status=000
if [ "$status" = 200 ]; then
    report messages_answered pass "status=200"
else
    report messages_answered fail "status=$status $(head -c 160 "$work_directory/out" 2>/dev/null)"
fi
reply_model=$(read_field reply_model)
if [ "$reply_model" = "$first_model" ]; then
    report messages_model_echoed pass "model=$reply_model"
else
    report messages_model_echoed fail "requested=$first_model echoed=$reply_model"
fi
# Every usage field is read here, while the retained reply is still the one the
# messages route returned; the count route overwrites that file below.
messages_input=$(read_field usage_input_tokens)
messages_output=$(read_field usage_output_tokens)
messages_cached=$(read_field usage_cache_read_input_tokens)
messages_text_length=$(read_field reply_text_length)
: "${messages_input:=-1}" "${messages_output:=-1}" "${messages_cached:=-1}"
: "${messages_text_length:=0}"
if [ "$messages_output" -gt 0 ] 2>/dev/null && [ "$messages_text_length" -gt 0 ]; then
    report messages_usage pass "input_tokens=$messages_input output_tokens=$messages_output"
else
    report messages_usage fail "output_tokens=$messages_output text_characters=$messages_text_length"
fi

request_body "$first_model" count
status=$(call POST /v1/messages/count_tokens) || status=000
if [ "$status" = 200 ]; then
    report count_tokens_answered pass "status=200"
else
    report count_tokens_answered fail "status=$status $(head -c 160 "$work_directory/out" 2>/dev/null)"
fi
counted=$(read_field input_tokens)
: "${counted:=-1}"
if [ "$counted" -gt 0 ] 2>/dev/null; then
    report count_tokens_counted pass "input_tokens=$counted"
else
    report count_tokens_counted fail "input_tokens=$counted"
fi

# The two routes tokenize one prompt and report it split differently.
# handle_count_tokens returns the whole tokenization from tokenize_mixed, while
# to_json_anthropic sets input_tokens to n_prompt_tokens - n_prompt_tokens_cache
# and puts the reused prefix in cache_read_input_tokens, so the invariant across
# a warm cache is the sum rather than either term. A gap past the few tokens a
# generation prompt adds around the turn says the router sent the two requests
# to different children.
if [ "$counted" -gt 0 ] 2>/dev/null && [ "$messages_input" -ge 0 ] 2>/dev/null \
    && [ "$messages_cached" -ge 0 ] 2>/dev/null; then
    charged=$((messages_input + messages_cached))
    spread=$((counted - charged))
    [ "$spread" -ge 0 ] || spread=$((-spread))
    if [ "$spread" -le 8 ]; then
        report count_matches_usage pass "counted=$counted charged=$charged cached=$messages_cached"
    else
        report count_matches_usage fail "counted=$counted charged=$charged cached=$messages_cached"
    fi
else
    report count_matches_usage fail "counted=$counted uncached=$messages_input cached=$messages_cached"
fi

printf 'checks_failed=%d\n' "$failures"
[ "$failures" -eq 0 ] || exit 1
printf 'code_agent_endpoint=ready origin=%s model=%s\n' "$origin" "$first_model"
