#!/bin/sh
set -eu

# The appliance confirmation of evidence/router-cancelled-load: the two-request
# sequence the LAN page produces when a peer switches models before the first
# load completes, run against a live router from any machine on the network.
# A first request names a model the router has not loaded, is cancelled the
# moment the router reports that model `loading`, and a second request naming
# another model is sent at once; the second must answer with no third
# request, router restart, device reset, or model change. Each step is one
# row in OUTPUT_DIR/results.tsv with the raw responses beside it.
#
# usage: confirm-router-cancelled-load.sh ROUTER_ORIGIN OUTPUT_DIR
#
#   QWEN_VERIFY_API_KEY_FILE   bearer key file, read into a curl config so the
#                              value stays off argv and out of every row
#   QWEN_CONFIRM_MODEL_A       the model the cancelled request names,
#                              default lfm25-vl-16b; it must read unloaded
#   QWEN_CONFIRM_MODEL_B       the model the follow-up names, default
#                              qwen38-2b-distill
#   QWEN_CONFIRM_DEADLINE_S    seconds the follow-up may take, default 300;
#                              a loaded 2B answers in well under a minute and
#                              the retained defect waited 700 s

if [ "$#" -ne 2 ]; then
    printf 'usage: %s ROUTER_ORIGIN OUTPUT_DIR\n' "$0" >&2
    exit 2
fi
router_origin=$1
output_directory=$2
model_a=${QWEN_CONFIRM_MODEL_A:-lfm25-vl-16b}
model_b=${QWEN_CONFIRM_MODEL_B:-qwen38-2b-distill}
deadline_seconds=${QWEN_CONFIRM_DEADLINE_S:-300}
for required_tool in curl jq python3; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf '%s is required\n' "$required_tool" >&2
        exit 2
    fi
done

umask 077
mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)
results=$output_directory/results.tsv
printf '# check\tstatus\tdetail\n' >"$results"
failures=0
record() {
    record_detail=$(printf '%s' "$3" | tr '\t\r\n' '   ')
    printf '%s\t%s\t%s\n' "$1" "$2" "$record_detail" >>"$results"
    printf '%s=%s %s\n' "$1" "$2" "$record_detail"
    [ "$2" = pass ] || failures=$((failures + 1))
}

curl_config=$(mktemp)
chmod 600 "$curl_config"
: >"$curl_config"
if [ -n "${QWEN_VERIFY_API_KEY_FILE:-}" ]; then
    printf 'header = "Authorization: Bearer %s"\n' "$(head -n 1 "$QWEN_VERIFY_API_KEY_FILE")" >"$curl_config"
fi
curl_a_pid=''
cleanup() {
    [ -z "$curl_a_pid" ] || kill "$curl_a_pid" 2>/dev/null || true
    rm -f "$curl_config"
}
trap cleanup EXIT HUP INT TERM

now_ms() {
    python3 -c 'import time; print(int(time.monotonic() * 1000))'
}
model_status() {
    curl -sS --max-time 10 --config "$curl_config" "$router_origin/models" 2>/dev/null |
        jq -r --arg id "$1" '.data[] | select(.id == $id) | .status.value // empty'
}
chat_body() {
    printf '{"model":"%s","messages":[{"role":"user","content":"Reply with the single word ready."}],"max_tokens":8,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}' "$1"
}

# ---- precondition: both ids served, model A unloaded ------------------------
status_a=$(model_status "$model_a")
status_b=$(model_status "$model_b")
if [ "$status_a" = unloaded ] && [ -n "$status_b" ]; then
    record precondition pass "model_a=$model_a:$status_a model_b=$model_b:$status_b"
else
    record precondition fail "model_a=$model_a:${status_a:-absent} model_b=$model_b:${status_b:-absent}; model A must read unloaded"
    printf 'confirm_router_cancelled_load=refused failures=%s results=%s\n' "$failures" "$results"
    exit 1
fi

# ---- request A, cancelled the moment its child reads loading -----------------
chat_body "$model_a" >"$output_directory/request-a.json"
sent_a_ms=$(now_ms)
curl -sS --max-time "$deadline_seconds" --config "$curl_config" -o "$output_directory/response-a.json" \
    -X POST "$router_origin/v1/chat/completions" -H 'Content-Type: application/json' \
    --data-binary "@$output_directory/request-a.json" >/dev/null 2>"$output_directory/curl-a.stderr" &
curl_a_pid=$!
observed_a=''
poll_ticks=$((deadline_seconds * 20))
while [ "$poll_ticks" -gt 0 ]; do
    observed_a=$(model_status "$model_a")
    [ "$observed_a" = loading ] && break
    [ "$observed_a" = loaded ] && break
    poll_ticks=$((poll_ticks - 1))
    sleep 0.05
done
kill "$curl_a_pid" 2>/dev/null || true
wait "$curl_a_pid" 2>/dev/null || true
curl_a_pid=''
cancelled_a_ms=$(now_ms)
if [ "$observed_a" = loading ]; then
    record request_a_cancelled_while_loading pass "model=$model_a cancelled_after_ms=$((cancelled_a_ms - sent_a_ms))"
else
    record request_a_cancelled_while_loading fail "model=$model_a status_at_cancel=${observed_a:-none} after_ms=$((cancelled_a_ms - sent_a_ms))"
fi

# ---- request B, sent at once, must answer with nothing else sent -------------
chat_body "$model_b" >"$output_directory/request-b.json"
sent_b_ms=$(now_ms)
status_code=$(curl -sS --max-time "$deadline_seconds" --config "$curl_config" -o "$output_directory/response-b.json" \
    -w '%{http_code}' -X POST "$router_origin/v1/chat/completions" -H 'Content-Type: application/json' \
    --data-binary "@$output_directory/request-b.json" 2>"$output_directory/curl-b.stderr" || true)
answered_b_ms=$(now_ms)
if [ "$status_code" = 200 ] && jq -e '.choices | length > 0' "$output_directory/response-b.json" >/dev/null 2>&1; then
    record request_b_answered pass "model=$model_b http=200 elapsed_ms=$((answered_b_ms - sent_b_ms)) served=$(jq -r '.model // empty' "$output_directory/response-b.json")"
else
    record request_b_answered fail "model=$model_b http=${status_code:-000} elapsed_ms=$((answered_b_ms - sent_b_ms)) body=$(head -c 200 "$output_directory/response-b.json" 2>/dev/null | tr -d '\n')"
fi

final_a=$(model_status "$model_a")
final_b=$(model_status "$model_b")
if [ "$final_b" = loaded ]; then
    record final_model_states pass "model_a=$final_a model_b=$final_b"
else
    record final_model_states fail "model_a=$final_a model_b=$final_b; the follow-up's model must read loaded"
fi
record requests_sent pass 'two: one cancelled, one follow-up; no third request, restart, or reset'

printf 'confirm_router_cancelled_load=%s failures=%s results=%s\n' \
    "$([ "$failures" = 0 ] && printf accepted || printf refused)" "$failures" "$results"
[ "$failures" = 0 ]
