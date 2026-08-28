#!/bin/sh
set -eu

# Admit the web router on the appliance against the fake provider: the
# production llama-server, a real router child, the approval broker, and the
# MCP child all run, and nothing reaches a network. The harness owns one
# outage: it records the ordinary router, tears it down, launches one
# validator-gated test profile from a ledger it writes itself, drives every
# boundary of the merged web path over HTTP, tears the test router down,
# proves absence, and restores the ordinary router. The checked-in ledger
# stays at execution_policy=refused throughout; the test ledger lives under
# OUTPUT_DIR and names one profile.
#
# The run exercises what the browser page does, in the order the page does
# it, with curl in the page's place: GET /tools composes the tool list, the
# broker's /session and /grant sign one exact-argument grant, POST /tools spends
# it, a Result ID from the search reply is redeemed by fetch, and the refusals
# the design relies on are each provoked once -- a replayed grant, a fetch past
# the profile's allowance, a fetch naming a URL rather than a Result ID, a
# grant request from a foreign Origin, a wrong session header, and a wrong
# profile_id. A chat completion then offers the model the composed tools and
# the search result, so the continuation the page performs is observed against
# the served model rather than assumed.
#
# Every check lands in OUTPUT_DIR/summary.tsv as `check<TAB>result<TAB>detail`.
# The run exits non-zero when a required check fails, and the restoration of
# the ordinary router runs on every exit path once the teardown has begun.
#
# usage: admit-web-router-fake.sh OUTPUT_DIR
#   QWEN_ADMISSION_MODEL_ID   registry row to serve, default qwen38-4b-distill
#   QWEN_ADMISSION_CONTEXT    depth the test profile requests, default 8192
#   QWEN_ADMISSION_PROFILE    profile id, default web-balanced-admission
#   QWEN_SERVER_PORT          router port, default 8080
#   QWEN_WEB_BROKER_PORT      broker port, default 8571
#   QWEN_ADMISSION_RESTORE    0 leaves the appliance down after the run

if [ "$#" -ne 1 ]; then
    printf 'usage: %s OUTPUT_DIR\n' "$0" >&2
    exit 2
fi

output_directory=$1
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
model_id=${QWEN_ADMISSION_MODEL_ID:-qwen38-4b-distill}
profile_id=${QWEN_ADMISSION_PROFILE:-web-balanced-admission}
context=${QWEN_ADMISSION_CONTEXT:-8192}
server_port=${QWEN_SERVER_PORT:-8080}
broker_port=${QWEN_WEB_BROKER_PORT:-8571}
restore=${QWEN_ADMISSION_RESTORE:-1}
registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
model_root=${QWEN_MODEL_ROOT:-"${HOME:?}/models"}
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"$HOME/qwen-webui-state"}
fixture=${QWEN_WEB_FAKE_FIXTURES:-$script_directory/test-fixtures/web-fake-provider.json}
router_origin=http://127.0.0.1:$server_port
broker_origin=http://127.0.0.1:$broker_port
query='raven2 vulkan decode'

for tool in python3 curl jq sha256sum ss pgrep; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf '%s is required\n' "$tool" >&2
        exit 2
    fi
done

mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)
summary=$output_directory/summary.tsv
: >"$summary"
failures=0
record() {
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$summary"
    printf '%s=%s %s\n' "$1" "$2" "$3"
    case $2 in
        pass | observed | skipped) ;;
        *) failures=$((failures + 1)) ;;
    esac
}
utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Every request the page would make is retained as a numbered pair, request
# body beside response body, so a failed check names the exchange.
exchange=0
call() {
    exchange=$((exchange + 1))
    call_label=$1
    call_method=$2
    call_url=$3
    call_body=${4:-}
    call_headers_file=$output_directory/http/$exchange-$call_label.headers
    call_out=$output_directory/http/$exchange-$call_label.response
    # dash ends the shell on a shift past $#, so the count is checked first.
    if [ "$#" -ge 4 ]; then
        shift 4
    else
        shift "$#"
    fi
    if [ -n "$call_body" ]; then
        printf '%s' "$call_body" >"$output_directory/http/$exchange-$call_label.request"
        curl -sS --max-time 600 -o "$call_out" -D "$call_headers_file" \
            -X "$call_method" "$call_url" -H 'Content-Type: application/json' \
            --data-binary "@$output_directory/http/$exchange-$call_label.request" \
            "$@" || true
    else
        curl -sS --max-time 60 -o "$call_out" -D "$call_headers_file" \
            -X "$call_method" "$call_url" "$@" || true
    fi
    call_status=$(sed -n '1s/^HTTP\/[0-9.]* \([0-9]*\).*/\1/p' "$call_headers_file" 2>/dev/null | tail -1)
    call_status=${call_status:-000}
}
mkdir -p "$output_directory/http"
# An early exit under set -e names itself in run.log rather than leaving an
# empty summary as the only trace.
note_exit() {
    exit_status=$?
    if [ "$exit_status" -ne 0 ]; then
        printf 'admission_aborted status=%s utc=%s\n' "$exit_status" "$(utc)" >>"$output_directory/run.log"
    fi
}
trap note_exit EXIT

# 1. The ordinary router, as found.
printf 'admission_start utc=%s host=%s\n' "$(utc)" "$(uname -n)" >"$output_directory/run.log"
cp "$state_directory/session.status" "$output_directory/ordinary-session.status" 2>/dev/null || true
ordinary_running=0
if pgrep -x llama-server >/dev/null 2>&1; then
    ordinary_running=1
    call ordinary-models GET "$router_origin/v1/models"
    jq -r '.data[].id' "$call_out" 2>/dev/null | sort >"$output_directory/ordinary-model-ids.txt" || true
    ordinary_server=$(readlink -f "/proc/$(pgrep -x llama-server | head -1)/exe")
else
    ordinary_server=${QWEN_LLAMA_SERVER:-"$HOME/src/llama.cpp-qwen-apu/build-appliance-current/bin/llama-server"}
    [ -x "$ordinary_server" ] || \
        ordinary_server=$HOME/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-server
fi
sha256sum "$ordinary_server" >"$output_directory/ordinary-llama-server.sha256"
if [ -x "$script_directory/hash-load-closure.sh" ]; then
    "$script_directory/hash-load-closure.sh" "$ordinary_server" \
        "$output_directory/ordinary-load-closure.tsv" >/dev/null 2>&1 || true
fi
record ordinary_router_recorded pass "running=$ordinary_running server=$(cut -c1-16 "$output_directory/ordinary-llama-server.sha256")"

if [ "$ordinary_running" = 1 ]; then
    if "$script_directory/qwen-teardown.sh" >"$output_directory/ordinary-teardown.log" 2>&1; then
        record ordinary_teardown pass 'no residue'
    else
        record ordinary_teardown fail "$(tail -1 "$output_directory/ordinary-teardown.log")"
        exit 1
    fi
fi

restore_ordinary() {
    if [ "$restore" != 1 ]; then
        record ordinary_restore skipped 'QWEN_ADMISSION_RESTORE=0'
        return 0
    fi
    if pgrep -x llama-server >/dev/null 2>&1; then
        "$script_directory/qwen-teardown.sh" >"$output_directory/pre-restore-teardown.log" 2>&1 || true
    fi
    if QWEN_ROUTER=1 QWEN_BIND_HOST=127.0.0.1 "$script_directory/qwen-launch.sh" low-async \
        >"$output_directory/ordinary-restore.log" 2>&1; then
        call restored-models GET "$router_origin/v1/models"
        jq -r '.data[].id' "$call_out" 2>/dev/null | sort >"$output_directory/restored-model-ids.txt" || true
        if [ -s "$output_directory/ordinary-model-ids.txt" ] && \
           ! cmp -s "$output_directory/ordinary-model-ids.txt" "$output_directory/restored-model-ids.txt"; then
            record ordinary_restore fail 'model roster differs from the one found'
        else
            record ordinary_restore pass "models=$(tr '\n' ',' <"$output_directory/restored-model-ids.txt")"
        fi
    else
        record ordinary_restore fail "$(tail -1 "$output_directory/ordinary-restore.log")"
    fi
}

# 2. Test inputs: signing key, state directory, one-row ledger, preset.
umask 077
mkdir -p "$output_directory/keys" "$output_directory/web-mcp"
chmod 700 "$output_directory/keys" "$output_directory/web-mcp"
token_key_file=$output_directory/keys/token.key
if [ ! -s "$token_key_file" ]; then
    python3 -c 'import secrets; print(secrets.token_hex(32))' >"$token_key_file"
fi
chmod 600 "$token_key_file"
umask 022

registry_row=$(grep -v '^#' "$registry" | awk -F'\t' -v id="$model_id" '$1 == id')
if [ -z "$registry_row" ]; then
    printf 'model %s is absent from %s\n' "$model_id" "$registry" >&2
    exit 2
fi
registry_field() { printf '%s\n' "$registry_row" | cut -f"$1"; }
validated_depth=$(registry_field 19)
projector=$(registry_field 11)
tool_selection=$(registry_field 21)
case $projector in
    none) vision_allowed=no ;;
    *) vision_allowed=yes ;;
esac
ledger=$output_directory/web-profiles.tsv
printf '# profile_id\tmodel_id\tweb_mode\tcontext\tvalidated_filled_depth\tmax_results\tmax_fetches\tmax_chars_per_fetch\tmulti_source\tvision_allowed\ttool_selection\texecution_policy\n' >"$ledger"
printf '%s\t%s\tvalidator-gated\t%s\t%s\t3\t1\t12000\tno\t%s\t%s\tvalidator-gated\n' \
    "$profile_id" "$model_id" "$context" "$validated_depth" "$vision_allowed" "$tool_selection" >>"$ledger"

web_presets=$output_directory/web-presets.ini
if QWEN_WEB_PROFILES=$ledger QWEN_WEB_MCP_SERVER=$script_directory/web-mcp/server.py \
    QWEN_WEB_PROVIDER=fake QWEN_WEB_FAKE_FIXTURES=$fixture \
    QWEN_WEB_TOKEN_KEY_FILE=$token_key_file QWEN_WEB_STATE_DIR=$output_directory/web-mcp \
    QWEN_WEB_AUTHORIZER_READY=1 QWEN_MODEL_REGISTRY=$registry QWEN_MODEL_ROOT=$model_root \
    "$script_directory/build-web-presets.sh" "$web_presets" >"$output_directory/build-web-presets.log" 2>&1; then
    record preset_generated pass "$(grep -c '^\[' "$web_presets") section"
else
    record preset_generated fail "$(tail -1 "$output_directory/build-web-presets.log")"
    restore_ordinary
    exit 1
fi

# 3. Launch the test router.
if QWEN_WEB_PRESETS=$web_presets QWEN_WEB_PROFILES=$ledger QWEN_WEB_PROVIDER=fake \
    QWEN_WEB_TOKEN_KEY_FILE=$token_key_file QWEN_WEB_STATE_DIR=$output_directory/web-mcp \
    QWEN_WEB_BROKER_PORT=$broker_port QWEN_WEB_AUTHORIZER_READY=1 \
    QWEN_MODEL_REGISTRY=$registry \
    "$script_directory/qwen-web-launch.sh" low-async >"$output_directory/web-launch.log" 2>&1; then
    record web_launch pass "$(grep '^web_launch' "$output_directory/web-launch.log" | tr '\n' ';')"
else
    record web_launch fail "$(tail -2 "$output_directory/web-launch.log" | tr '\n' ';')"
    cp "$state_directory/session.status" "$output_directory/failed-session.status" 2>/dev/null || true
    cp "$state_directory/authorize-broker.log" "$output_directory/failed-broker.log" 2>/dev/null || true
    cp "$state_directory/server.log" "$output_directory/failed-server.log" 2>/dev/null || true
    restore_ordinary
    exit 1
fi
cp "$state_directory/session.status" "$output_directory/web-session.status"
cp "$state_directory/authorize-broker.log" "$output_directory/web-broker.log" 2>/dev/null || true
broker_pid=$(sed -n '1p' "$output_directory/web-session.status" | tr ' ' '\n' | sed -n 's/^broker_pid=//p')
secret_file=$(sed -n 's/^broker secret_file=//p' "$output_directory/web-session.status")
router_listener=$(ss -ltnp 2>/dev/null | grep ":$server_port " | grep -o '[0-9.:*]*:'"$server_port" | sort -u | tr '\n' ',')
broker_listener=$(ss -ltnp 2>/dev/null | grep ":$broker_port " | grep -o '[0-9.:*]*:'"$broker_port" | sort -u | tr '\n' ',')
case $router_listener in
    "127.0.0.1:$server_port,") record router_listener_loopback pass "$router_listener" ;;
    *) record router_listener_loopback fail "$router_listener" ;;
esac
case $broker_listener in
    "127.0.0.1:$broker_port,") record broker_listener_loopback pass "$broker_listener" ;;
    *) record broker_listener_loopback fail "$broker_listener" ;;
esac
case $broker_pid in
    '' | *[!0-9]*) record broker_pid_recorded fail "broker_pid=$broker_pid" ;;
    *) record broker_pid_recorded pass "broker_pid=$broker_pid" ;;
esac
if [ -f "$secret_file" ] && [ "$(stat -c %a "$secret_file")" = 600 ]; then
    record broker_secret_mode pass "$(stat -c %a "$secret_file")"
else
    record broker_secret_mode fail "secret_file=$secret_file"
fi

# 4. Router identity: one alias, the test tuple, the two web tools.
call models GET "$router_origin/v1/models"
model_ids=$(jq -r '.data[].id' "$call_out" 2>/dev/null | tr '\n' ',')
if [ "$model_ids" = "$profile_id," ]; then
    record router_roster pass "$model_ids"
else
    record router_roster fail "$model_ids"
fi
call props GET "$router_origin/props?model=$profile_id"
served_context=$(jq -r '.default_generation_settings.n_ctx // empty' "$call_out" 2>/dev/null)
record served_context observed "n_ctx=$served_context requested=$context"
# llama-server at f280b269 registers /tools in the process whose own MCP
# manager holds a server, and the router branch proxies chat, props, and
# slots without /tools, so the router port answers feature_disabled while
# the child that read the section's configuration serves the route on the
# internal loopback port the router assigned it. The router's answer is
# recorded, and the executor checks run against the child port, which is
# read from the listening sockets llama-server processes hold beside the
# router's own.
call router-tools GET "$router_origin/tools"
record router_tools_route observed "status=$call_status $(head -c 120 "$call_out" | tr '\n' ' ')"
call warm-child POST "$router_origin/v1/chat/completions" "$(jq -cn --arg m "$profile_id" '{model: $m, messages: [{role: "user", content: "Reply with the word ready."}], max_tokens: 4, chat_template_kwargs: {enable_thinking: false}}')"
child_port=''
for candidate in $(ss -ltnp 2>/dev/null | grep '"llama-server"' | grep -o '127\.0\.0\.1:[0-9]*' | sed 's/.*://' | sort -u); do
    [ "$candidate" != "$server_port" ] || continue
    child_port=$candidate
done
if [ -n "$child_port" ]; then
    record child_port_discovered pass "port=$child_port"
else
    record child_port_discovered fail 'no llama-server listener beside the router'
    child_port=$server_port
fi
tools_origin=http://127.0.0.1:$child_port
call tools GET "$tools_origin/tools"
tool_names=$(jq -r '.[].tool' "$call_out" 2>/dev/null | sort | tr '\n' ',')
if [ "$tool_names" = "web_fetch_exa,web_search_exa," ]; then
    record tool_enumeration pass "$tool_names via $tools_origin"
else
    record tool_enumeration fail "$tool_names status=$call_status"
fi
cp "$call_out" "$output_directory/tools.json"

# 5. Broker identity and the session secret's gates.
call broker-health GET "$broker_origin/health" '' -H "Host: 127.0.0.1:$broker_port"
health_profile=$(jq -r '.profile // empty' "$call_out" 2>/dev/null)
health_provider=$(jq -r '.provider // empty' "$call_out" 2>/dev/null)
health_pid=$(jq -r '.pid // empty' "$call_out" 2>/dev/null)
if [ "$health_profile" = "$profile_id" ] && [ "$health_provider" = fake ] && [ "$health_pid" = "$broker_pid" ]; then
    record broker_health_identity pass "profile=$health_profile provider=$health_provider pid=$health_pid"
else
    record broker_health_identity fail "profile=$health_profile provider=$health_provider pid=$health_pid"
fi
call session GET "$broker_origin/session" '' -H "Origin: $router_origin" -H "Host: 127.0.0.1:$broker_port"
session_secret=$(jq -r '.session_secret // empty' "$call_out" 2>/dev/null)
if [ "$call_status" = 200 ] && [ -n "$session_secret" ]; then
    record session_secret_issued pass "status=$call_status"
else
    record session_secret_issued fail "status=$call_status"
fi
call session-foreign-origin GET "$broker_origin/session" '' -H "Origin: http://localhost:$server_port" -H "Host: 127.0.0.1:$broker_port"
if [ "$call_status" != 200 ]; then
    record session_foreign_origin_refused pass "status=$call_status"
else
    record session_foreign_origin_refused fail "status=$call_status"
fi
call session-no-origin GET "$broker_origin/session" '' -H "Host: 127.0.0.1:$broker_port"
if [ "$call_status" != 200 ]; then
    record session_absent_origin_refused pass "status=$call_status"
else
    record session_absent_origin_refused fail "status=$call_status"
fi
call session-name-host GET "$broker_origin/session" '' -H "Origin: $router_origin" -H 'Host: broker.example'
if [ "$call_status" != 200 ]; then
    record session_name_host_refused pass "status=$call_status"
else
    record session_name_host_refused fail "status=$call_status"
fi

# 6. One grant, signed over the exact fields the page shows.
grant_body=$(jq -cn --arg q "$query" --arg p "$profile_id" \
    '{query: $q, profile_id: $p, max_results: 3, include_domains: [], exclude_domains: []}')
call grant POST "$broker_origin/grant" "$grant_body" -H "Origin: $router_origin" \
    -H "Host: 127.0.0.1:$broker_port" -H "X-Qwen-Web-Session: $session_secret"
authorization=$(jq -r '.authorization // empty' "$call_out" 2>/dev/null)
if [ "$call_status" = 200 ] && [ -n "$authorization" ]; then
    record grant_issued pass "status=$call_status bytes=${#authorization}"
else
    record grant_issued fail "status=$call_status"
fi
wrong_profile_body=$(jq -cn --arg q "$query" '{query: $q, profile_id: "web-other", max_results: 3, include_domains: [], exclude_domains: []}')
call grant-wrong-profile POST "$broker_origin/grant" "$wrong_profile_body" -H "Origin: $router_origin" \
    -H "Host: 127.0.0.1:$broker_port" -H "X-Qwen-Web-Session: $session_secret"
if [ "$call_status" != 200 ]; then
    record grant_wrong_profile_refused pass "status=$call_status"
else
    record grant_wrong_profile_refused fail "status=$call_status"
fi
call grant-wrong-session POST "$broker_origin/grant" "$grant_body" -H "Origin: $router_origin" \
    -H "Host: 127.0.0.1:$broker_port" -H 'X-Qwen-Web-Session: not-the-secret'
if [ "$call_status" != 200 ]; then
    record grant_wrong_session_refused pass "status=$call_status"
else
    record grant_wrong_session_refused fail "status=$call_status"
fi
call grant-foreign-origin POST "$broker_origin/grant" "$grant_body" -H "Origin: http://localhost:$server_port" \
    -H "Host: 127.0.0.1:$broker_port" -H "X-Qwen-Web-Session: $session_secret"
if [ "$call_status" != 200 ]; then
    record grant_foreign_origin_refused pass "status=$call_status"
else
    record grant_foreign_origin_refused fail "status=$call_status"
fi

# 7. The search runs through the real llama-server and its MCP child.
search_params=$(jq -cn --arg q "$query" --arg a "$authorization" \
    '{tool: "web_search_exa", params: {query: $q, max_results: 3, include_domains: [], exclude_domains: [], authorization: $a}}')
call search POST "$tools_origin/tools" "$search_params"
search_text=$(jq -r 'if type == "object" then (.error // .plain_text_response // tostring) else tostring end' "$call_out" 2>/dev/null)
cp "$call_out" "$output_directory/search-response.json"
result_id=$(printf '%s\n' "$search_text" | sed -n 's/^Result ID: //p' | head -1)
if [ "$call_status" = 200 ] && [ -n "$result_id" ] && ! jq -e '.error' "$call_out" >/dev/null 2>&1; then
    record search_executed pass "results=$(printf '%s\n' "$search_text" | grep -c '^Result ID: ')"
else
    record search_executed fail "status=$call_status $(printf '%s' "$search_text" | head -c 160)"
fi
call search-replay POST "$tools_origin/tools" "$search_params"
if [ "$call_status" = 200 ] && jq -e '.error' "$call_out" >/dev/null 2>&1; then
    record grant_replay_refused pass "$(jq -r '.error' "$call_out" | head -c 120)"
else
    record grant_replay_refused fail "status=$call_status $(head -c 120 "$call_out")"
fi
unauthorized_params=$(jq -cn --arg q "$query" \
    '{tool: "web_search_exa", params: {query: $q, max_results: 3, include_domains: [], exclude_domains: []}}')
call search-no-grant POST "$tools_origin/tools" "$unauthorized_params"
if [ "$call_status" = 200 ] && jq -e '.error' "$call_out" >/dev/null 2>&1; then
    record search_without_grant_refused pass "$(jq -r '.error' "$call_out" | head -c 120)"
else
    record search_without_grant_refused fail "status=$call_status $(head -c 120 "$call_out")"
fi

# 8. Fetch by Result ID, then the allowance and the URL refusal.
fetch_params=$(jq -cn --arg r "$result_id" '{tool: "web_fetch_exa", params: {result_id: $r}}')
call fetch POST "$tools_origin/tools" "$fetch_params"
fetch_text=$(jq -r 'if type == "object" then (.error // .plain_text_response // tostring) else tostring end' "$call_out" 2>/dev/null)
if [ "$call_status" = 200 ] && printf '%s' "$fetch_text" | grep -q 'FIXTURE-PAGE-' && ! jq -e '.error' "$call_out" >/dev/null 2>&1; then
    record fetch_by_result_id pass "chars=${#fetch_text}"
else
    record fetch_by_result_id fail "status=$call_status $(printf '%s' "$fetch_text" | head -c 160)"
fi
cp "$call_out" "$output_directory/fetch-response.json"
second_id=$(printf '%s\n' "$search_text" | sed -n 's/^Result ID: //p' | sed -n '2p')
call fetch-past-allowance POST "$tools_origin/tools" "$(jq -cn --arg r "${second_id:-$result_id}" '{tool: "web_fetch_exa", params: {result_id: $r}}')"
if [ "$call_status" = 200 ] && jq -e '.error' "$call_out" >/dev/null 2>&1; then
    record fetch_allowance_enforced pass "$(jq -r '.error' "$call_out" | head -c 120)"
else
    record fetch_allowance_enforced fail "status=$call_status $(head -c 120 "$call_out")"
fi
call fetch-url POST "$tools_origin/tools" "$(jq -cn '{tool: "web_fetch_exa", params: {result_id: "https://example.org/raven2"}}')"
if [ "$call_status" = 200 ] && jq -e '.error' "$call_out" >/dev/null 2>&1; then
    record fetch_url_refused pass "$(jq -r '.error' "$call_out" | head -c 120)"
else
    record fetch_url_refused fail "status=$call_status $(head -c 120 "$call_out")"
fi

# 9. The model meets the composed tools and the search result. The proposal
# is the model's own, so both halves are recorded as observations.
tools_for_chat=$(jq -c '[.[] | .definition | select(.type == "function") | .function.parameters.properties |= (del(.authorization) // {}) | .function.parameters.required |= ((. // []) | map(select(. != "authorization")))]' "$output_directory/tools.json" 2>/dev/null || printf '[]')
chat_body=$(jq -cn --arg m "$profile_id" --arg q "$query" --argjson tools "$tools_for_chat" \
    '{model: $m, messages: [{role: "user", content: ("Search the web with the query " + $q + " and report the decode rate the result states.")}], tools: $tools, tool_choice: "auto", max_tokens: 512, temperature: 0, chat_template_kwargs: {enable_thinking: false}}')
call chat-proposal POST "$router_origin/v1/chat/completions" "$chat_body"
cp "$call_out" "$output_directory/chat-proposal.json"
proposed_tool=$(jq -r '.choices[0].message.tool_calls[0].function.name // empty' "$call_out" 2>/dev/null)
proposed_arguments=$(jq -r '.choices[0].message.tool_calls[0].function.arguments // empty' "$call_out" 2>/dev/null)
served_model=$(jq -r '.model // empty' "$call_out" 2>/dev/null)
if [ "$proposed_tool" = web_search_exa ]; then
    record model_proposes_search observed "model=$served_model arguments=$(printf '%s' "$proposed_arguments" | head -c 200)"
else
    record model_proposes_search observed "model=$served_model tool=${proposed_tool:-none} finish=$(jq -r '.choices[0].finish_reason // empty' "$call_out" 2>/dev/null)"
fi
assistant_message=$(jq -c '.choices[0].message | {role, content, tool_calls}' "$call_out" 2>/dev/null || printf '{"role":"assistant","content":""}')
tool_call_id=$(jq -r '.choices[0].message.tool_calls[0].id // "call_admission"' "$call_out" 2>/dev/null)
continuation_body=$(jq -cn --arg m "$profile_id" --arg q "$query" --argjson assistant "$assistant_message" \
    --arg id "$tool_call_id" --arg text "$search_text" --argjson tools "$tools_for_chat" \
    '{model: $m, messages: [{role: "user", content: ("Search the web with the query " + $q + " and report the decode rate the result states.")}, $assistant, {role: "tool", tool_call_id: $id, content: $text}], tools: $tools, max_tokens: 512, temperature: 0, chat_template_kwargs: {enable_thinking: false}}')
call chat-continuation POST "$router_origin/v1/chat/completions" "$continuation_body"
cp "$call_out" "$output_directory/chat-continuation.json"
final_answer=$(jq -r '.choices[0].message.content // empty' "$call_out" 2>/dev/null)
if printf '%s' "$final_answer" | grep -q '3\.07'; then
    record model_reads_tool_result pass "$(printf '%s' "$final_answer" | tr '\n' ' ' | head -c 200)"
else
    record model_reads_tool_result observed "status=$call_status $(printf '%s' "$final_answer" | tr '\n' ' ' | head -c 200)"
fi

# 10. Secret hygiene: key bytes, grant, session secret, and query text stay out
# of every process image and every retained file.
key_bytes=$(cat "$token_key_file")
hygiene_failures=''
for pid in $(pgrep -x llama-server) $(pgrep -f 'web-mcp/server.py') $broker_pid; do
    [ -r "/proc/$pid/environ" ] || continue
    for needle in "$key_bytes" "$authorization" "$session_secret"; do
        [ -n "$needle" ] || continue
        if tr '\0' '\n' <"/proc/$pid/environ" | grep -qF -- "$needle" || \
           tr '\0' '\n' <"/proc/$pid/cmdline" | grep -qF -- "$needle"; then
            hygiene_failures="$hygiene_failures pid=$pid"
        fi
    done
done
tr '\0' '\n' <"/proc/$broker_pid/cmdline" >"$output_directory/broker.cmdline" 2>/dev/null || true
for pid in $(pgrep -f 'web-mcp/server.py'); do
    tr '\0' '\n' <"/proc/$pid/cmdline" >"$output_directory/mcp-child-$pid.cmdline" 2>/dev/null || true
    tr '\0' '\n' <"/proc/$pid/environ" | sed 's/=.*/=<value>/' >"$output_directory/mcp-child-$pid.environ-keys" 2>/dev/null || true
done
python3 - "$output_directory/web-mcp" "$output_directory/audit-rows.tsv" <<'PY' || true
import glob, os, sqlite3, sys
directory, out = sys.argv[1], sys.argv[2]
with open(out, "w") as handle:
    for path in glob.glob(os.path.join(directory, "*.sqlite*")) + glob.glob(os.path.join(directory, "*.db")):
        try:
            connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
            for (name,) in connection.execute("select name from sqlite_master where type='table'"):
                for row in connection.execute(f"select * from {name}"):
                    handle.write(name + "\t" + "\t".join(str(v) for v in row) + "\n")
            connection.close()
        except sqlite3.Error as error:
            handle.write(f"unreadable\t{path}\t{error}\n")
PY
for retained in "$state_directory/server.log" "$state_directory/authorize-broker.log" \
    "$state_directory/session.status" "$output_directory/audit-rows.tsv"; do
    [ -r "$retained" ] || continue
    for needle in "$key_bytes" "$authorization" "$session_secret"; do
        [ -n "$needle" ] || continue
        if grep -qF -- "$needle" "$retained"; then
            hygiene_failures="$hygiene_failures file=$(basename "$retained")"
        fi
    done
done
if grep -qF -- "$query" "$output_directory/audit-rows.tsv" 2>/dev/null; then
    hygiene_failures="$hygiene_failures audit=query-text"
fi
if [ -z "$hygiene_failures" ]; then
    record secret_hygiene pass 'key, grant, session secret, and query text absent from process images, logs, status, and audit'
else
    record secret_hygiene fail "$hygiene_failures"
fi
cp "$state_directory/server.log" "$output_directory/web-server.log" 2>/dev/null || true
cp "$state_directory/authorize-broker.log" "$output_directory/web-broker.log" 2>/dev/null || true

# 11. Teardown and absence.
if "$script_directory/qwen-teardown.sh" >"$output_directory/web-teardown.log" 2>&1; then
    record web_teardown pass "$(tail -1 "$output_directory/web-teardown.log")"
else
    record web_teardown fail "$(tail -1 "$output_directory/web-teardown.log")"
fi
absence=''
pgrep -x llama-server >/dev/null 2>&1 && absence="$absence llama-server"
pgrep -f 'web-mcp/server.py' >/dev/null 2>&1 && absence="$absence mcp-child"
kill -0 "$broker_pid" 2>/dev/null && absence="$absence broker"
[ -e "$secret_file" ] && absence="$absence secret"
ss -ltn 2>/dev/null | grep -q ":$server_port " && absence="$absence port-$server_port"
ss -ltn 2>/dev/null | grep -q ":$broker_port " && absence="$absence port-$broker_port"
if [ -z "$absence" ]; then
    record absence_proved pass 'router, child, broker, secret, and both ports'
else
    record absence_proved fail "$absence"
fi

# 12. Restore the ordinary router.
restore_ordinary
printf 'admission_end utc=%s failures=%s\n' "$(utc)" "$failures" >>"$output_directory/run.log"
if [ "$failures" -eq 0 ]; then
    printf 'web router admission against the fake provider: all required checks passed\n'
    exit 0
fi
printf 'web router admission against the fake provider: %s required checks failed\n' "$failures" >&2
exit 1
