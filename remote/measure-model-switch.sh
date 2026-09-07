#!/bin/sh
set -eu

# What a router model switch costs, against a router that is already running.
#
# `--models-max 1` keeps one child resident, so a request naming the other
# roster id evicts the loaded model and loads the named one before it decodes a
# token: `server-models.cpp` logs `evicting idle LRU name=A to make room for
# name=B`, `model name=B is not loaded, loading...`, `waiting until model
# name=B is fully loaded...`, and `spawning server instance with name=B on port
# N` across that transition. This harness alternates one-token requests between
# two ids, measures the wall time from the request leaving to the first response
# byte arriving, and reads the log lines the router wrote inside each request's
# own window, cut by the byte offset server.log held before the request.
#
# What it observes and what it asserts are two things. Each row is one switch
# measured once on one machine under whatever else that machine was doing, and
# the summary states quantiles over the rows taken and predicts nothing about a
# switch outside them. The rate spread this appliance carries -- 4% on a
# repeated depth-0 rate, 30.6% between sweeps under desktop load -- is larger
# than most differences a reader would want to draw between two rows here.
#
# Two measurement bounds are stated rather than assumed. The request is
# unstreamed, so `curl`'s `time_starttransfer` is the first byte of the whole
# buffered one-token response rather than a token boundary inside a stream: the
# field is named `first_byte_ns` and measures the complete request, and an HTTP
# error is a switch that did not complete, which `--fail` turns into a `-` row
# rather than a duration over a refusal. The router's log
# carries a timestamp only where the build ran under `--log-timestamps`, which
# `common/log.cpp` leaves off by default, so a run against an ordinary launch
# records `log_clock=absent` and attributes the matched lines to the request
# window rather than to a clock.

usage() {
    printf 'usage: %s OUTPUT_DIRECTORY [SWITCH_COUNT]\n' "$0" >&2
    printf '  QWEN_SWITCH_ORIGIN     router origin, default http://127.0.0.1:8080\n' >&2
    printf '  QWEN_SWITCH_MODEL_A    first roster id, default the first served id\n' >&2
    printf '  QWEN_SWITCH_MODEL_B    second roster id, default the second served id\n' >&2
    printf '  QWEN_SWITCH_SERVER_LOG server.log, default $QWEN_HOME/state/server.log\n' >&2
    printf '  QWEN_SWITCH_API_KEY_FILE  bearer for a launch that requires one\n' >&2
    exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
output_directory=$1
switch_count=${2:-20}
case $switch_count in
    '' | *[!0-9]* | 0) usage ;;
esac
if [ -e "$output_directory" ]; then
    printf 'the output directory already exists: %s\n' "$output_directory" >&2
    exit 1
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

router_origin=${QWEN_SWITCH_ORIGIN:-http://127.0.0.1:8080}
server_log=${QWEN_SWITCH_SERVER_LOG:-"$qwen_home_state/server.log"}
api_key_file=${QWEN_SWITCH_API_KEY_FILE:-}

mkdir -p "$output_directory"
switch_tsv=$output_directory/model-switch.tsv
roster_json=$output_directory/models.json

authorization_header=''
if [ -n "$api_key_file" ]; then
    if [ ! -r "$api_key_file" ]; then
        printf 'the api key file is unreadable: %s\n' "$api_key_file" >&2
        exit 1
    fi
    authorization_header="Authorization: Bearer $(cat "$api_key_file")"
fi

router_get() {
    if [ -n "$authorization_header" ]; then
        curl --silent --fail --header "$authorization_header" "$1"
    else
        curl --silent --fail "$1"
    fi
}

if ! router_get "$router_origin/v1/models" >"$roster_json"; then
    printf 'the router did not answer GET /v1/models at %s\n' "$router_origin" >&2
    exit 1
fi

# `GET /v1/models` is the request-model authority the served page reads, so the
# ids this harness alternates come from the listener rather than from a registry
# a launch may not be serving.
served_ids=$(python3 -c '
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
for entry in payload.get("data") or []:
    identifier = entry.get("id")
    if identifier:
        print(identifier)
' "$roster_json")

model_a=${QWEN_SWITCH_MODEL_A:-$(printf '%s\n' "$served_ids" | sed -n 1p)}
model_b=${QWEN_SWITCH_MODEL_B:-$(printf '%s\n' "$served_ids" | sed -n 2p)}
if [ -z "$model_a" ] || [ -z "$model_b" ] || [ "$model_a" = "$model_b" ]; then
    printf 'a switch needs two distinct served ids; the roster answered:\n' >&2
    printf '%s\n' "$served_ids" >&2
    exit 1
fi

log_readable=1
[ -r "$server_log" ] || log_readable=0
if [ "$log_readable" -eq 0 ]; then
    printf 'server log unreadable, so no router line is attributed: %s\n' \
        "$server_log" >&2
fi

# A timestamped line carries `MM:SS.mmm.uuu` ahead of its level, which
# `common/log.cpp` emits only under --log-timestamps. The reading is recorded
# once for the whole run rather than guessed per line.
log_clock=absent
if [ "$log_readable" -eq 1 ] &&
    grep -Eq '^[0-9][0-9]:[0-9][0-9]\.[0-9]{3}\.[0-9]{3}' "$server_log"; then
    log_clock=relative
fi

printf '# model_switch clock=realtime origin=%s model_a=%s model_b=%s log_clock=%s\n' \
    "$router_origin" "$model_a" "$model_b" "$log_clock" >"$switch_tsv"

log_offset() {
    if [ "$log_readable" -eq 1 ]; then
        wc -c <"$server_log" | tr -d ' '
    else
        printf '0\n'
    fi
}

switch_index=0
while [ "$switch_index" -lt "$switch_count" ]; do
    switch_index=$((switch_index + 1))
    if [ $((switch_index % 2)) -eq 1 ]; then
        requested_model=$model_a
    else
        requested_model=$model_b
    fi
    request_body=$output_directory/request-$switch_index.json
    response_body=$output_directory/response-$switch_index.json
    log_slice=$output_directory/router-lines-$switch_index.log
    printf '{"model":"%s","messages":[{"role":"user","content":"hi"}],"max_tokens":1,"temperature":0,"stream":false}\n' \
        "$requested_model" >"$request_body"
    begin_offset=$(log_offset)
    set +e
    if [ -n "$authorization_header" ]; then
        first_byte_seconds=$(curl --silent --show-error --fail \
            --output "$response_body" \
            --write-out '%{time_starttransfer}' \
            --header 'Content-Type: application/json' \
            --header "$authorization_header" \
            --data @"$request_body" \
            "$router_origin/v1/chat/completions")
    else
        first_byte_seconds=$(curl --silent --show-error --fail \
            --output "$response_body" \
            --write-out '%{time_starttransfer}' \
            --header 'Content-Type: application/json' \
            --data @"$request_body" \
            "$router_origin/v1/chat/completions")
    fi
    request_status=$?
    set -e
    if [ "$request_status" -ne 0 ]; then
        first_byte_ns=-
    else
        first_byte_ns=$(printf '%s\n' "$first_byte_seconds" |
            awk '{ printf "%.0f\n", $1 * 1000000000 }')
    fi
    if [ "$log_readable" -eq 1 ]; then
        tail -c "+$((begin_offset + 1))" "$server_log" |
            grep -E 'evicting idle LRU|removing LRU name=|is not loaded, loading|waiting until model|spawning server instance|stopping model instance' \
            >"$log_slice" || :
    else
        : >"$log_slice"
    fi
    matched_lines=$(wc -l <"$log_slice" | tr -d ' ')
    printf 'switch\t%s\t%s\t%s\t%s\t%s\n' \
        "$switch_index" "$requested_model" "$first_byte_ns" \
        "$matched_lines" "$log_slice" >>"$switch_tsv"
done

printf 'model_switch_rows=%s tsv=%s\n' "$switch_count" "$switch_tsv"
"$script_directory/summarize-stage-timing.py" switches "$switch_tsv"
