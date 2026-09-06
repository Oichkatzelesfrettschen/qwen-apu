#!/bin/sh
set -eu

# The router lifecycle around a request cancelled while its child is loading.
#
# evidence/deployment-epochs/main-e909cfc-r1/README.md records the defect: a
# page cancelled its request 0.4 s into a child load, the child finished
# loading, and the next request, naming a second model under --models-max 1,
# sat until its own 700 s timeout while a fresh request sent afterward spawned
# within 13 s. This test holds a real router child at an explicit barrier so
# the same sequence runs deterministically against a CPU build: the child is
# held at its listener bind by remote/test-fixtures/router-child-bind-barrier.c,
# the initiating request is cancelled while the hold is provably in place,
# the follow-up is submitted and observed in the router log before the hold is
# released, and the follow-up must then terminate with a defined result. A
# deadline bounds a router that never answers; nothing here asks a sleep to
# land inside a race.
#
# Three cases run, each against a fresh router:
#   different-model  the follow-up names the second section; it must answer
#                    and the first child must give its slot up
#   same-model       the follow-up names the loading section; it must answer
#                    from the load already in flight
#   load-failure     the held child's bind is made to fail; the follow-up
#                    names the second section and must answer once the failed
#                    child has left, with the first section reading failed
#
#   QWEN_ROUTER_TEST_SERVER  a llama-server built from the pinned tree with
#                            the production series, CPU backend
#   QWEN_ROUTER_TEST_MODEL   a small GGUF both sections load (the pinned
#                            stories260K fixture from
#                            remote/fetch-test-model-stories260k.sh)
#   QWEN_ROUTER_TEST_DEADLINE_S  seconds a single wait may take, default 60
#
# usage: test-router-cancelled-load.sh [OUTPUT_DIR]

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [OUTPUT_DIR]\n' "$0" >&2
    exit 2
fi
server=${QWEN_ROUTER_TEST_SERVER:-}
model=${QWEN_ROUTER_TEST_MODEL:-}
deadline_seconds=${QWEN_ROUTER_TEST_DEADLINE_S:-60}
if [ -z "$server" ] || [ -z "$model" ]; then
    printf 'router_cancelled_load=not_run reason=QWEN_ROUTER_TEST_SERVER_or_QWEN_ROUTER_TEST_MODEL_unset\n'
    exit 0
fi
if [ ! -x "$server" ]; then
    printf 'QWEN_ROUTER_TEST_SERVER is not executable: %s\n' "$server" >&2
    exit 1
fi
if [ ! -r "$model" ]; then
    printf 'QWEN_ROUTER_TEST_MODEL is unreadable: %s\n' "$model" >&2
    exit 1
fi
for required_tool in cc curl python3 jq; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf '%s is required\n' "$required_tool" >&2
        exit 2
    fi
done

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
output_directory=${1:-$(mktemp -d)}
mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)
results=$output_directory/results.tsv
printf '# case\tcheck\tstatus\tdetail\n' >"$results"
failures=0
record() {
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >>"$results"
    printf '%s %s=%s %s\n' "$1" "$2" "$3" "$4"
    [ "$3" = pass ] || failures=$((failures + 1))
}

shim=$output_directory/router-child-bind-barrier.so
cc -shared -fPIC -O2 -o "$shim" "$script_directory/test-fixtures/router-child-bind-barrier.c" -ldl

router_pid=''
curl_pids=''
port_lease_holder_pid=''
cleanup() {
    for pid in $curl_pids; do
        kill "$pid" 2>/dev/null || true
    done
    if [ -n "$router_pid" ]; then
        kill "$router_pid" 2>/dev/null || true
        wait "$router_pid" 2>/dev/null || true
    fi
    if [ -n "$port_lease_holder_pid" ]; then
        "$script_directory/test-port-lease.sh" release \
            "$port_lease_holder_pid" || true
        port_lease_holder_pid=''
    fi
}
trap cleanup EXIT HUP INT TERM

# One leased port per case, held for this script's whole run by a holder
# process, so a gate cell running beside this one on the same workstation is
# refused those numbers rather than receiving one from a bind to port zero that
# this script had already released. A case takes its own number rather than
# reusing the previous case's, since the cancelled request leaves connections
# whose TIME_WAIT state a listener without SO_REUSEADDR meets as EADDRINUSE.
port_lease_ports_file=$output_directory/leased-ports
port_lease_holder_pid=$("$script_directory/test-port-lease.sh" claim 3 \
    "$port_lease_ports_file")
case_index=0

# wait_until DESCRIPTION COMMAND...: polls the command every 50 ms until it
# succeeds or the deadline passes; returns 1 on the deadline.
wait_until() {
    wait_description=$1
    shift
    wait_ticks=$((deadline_seconds * 20))
    while ! "$@" >/dev/null 2>&1; do
        wait_ticks=$((wait_ticks - 1))
        if [ "$wait_ticks" -le 0 ]; then
            printf 'deadline: %s\n' "$wait_description" >&2
            return 1
        fi
        sleep 0.05
    done
}
log_count_at_least() {
    [ "$(grep -c -- "$2" "$1" 2>/dev/null || true)" -ge "$3" ]
}
held_count_at_least() {
    [ "$(find "$1" -maxdepth 1 -name 'held-*' | wc -l)" -ge "$2" ]
}
process_gone() {
    ! kill -0 "$1" 2>/dev/null
}
# newest held file's port, so the release names the child the test just saw arrive
latest_held_port() {
    find "$1" -maxdepth 1 -name 'held-*' -printf '%T@ %f\n' | sort -rn | head -n 1 | sed 's/^.* held-//'
}
model_status() {
    curl -sS --max-time 10 "http://127.0.0.1:$2/models" | jq -r --arg id "$1" '.data[] | select(.id == $id) | .status.value'
}
model_failed() {
    curl -sS --max-time 10 "http://127.0.0.1:$2/models" | jq -r --arg id "$1" '.data[] | select(.id == $id) | .status.failed // false'
}

chat_body() {
    printf '{"model":"%s","messages":[{"role":"user","content":"Once upon a time"}],"max_tokens":4,"temperature":0}' "$1"
}

run_case() {
    case_name=$1
    followup_model=$2
    first_release_verdict=$3
    expect_second_child=$4
    expected_a_status=$5
    expected_b_status=$6

    case_index=$((case_index + 1))
    router_port=$(sed -n "${case_index}p" "$port_lease_ports_file")
    case_directory=$output_directory/$case_name
    barrier_directory=$case_directory/barrier
    mkdir -p "$barrier_directory"
    preset=$case_directory/router-presets.ini
    for section in model-a model-b; do
        printf '[%s]\nLLAMA_ARG_MODEL = %s\nLLAMA_ARG_CTX_SIZE = 256\nLLAMA_ARG_N_GPU_LAYERS = 0\nLLAMA_ARG_THREADS = 1\n\n' \
            "$section" "$model" >>"$preset"
    done
    router_log=$case_directory/router.log
    LD_PRELOAD=$shim QWEN_ROUTER_BARRIER_DIR=$barrier_directory \
        "$server" --models-preset "$preset" --models-max 1 --host 127.0.0.1 --port "$router_port" \
        >"$router_log" 2>&1 &
    router_pid=$!
    if ! wait_until "router health on $router_port" \
        curl -sf --max-time 2 -o /dev/null "http://127.0.0.1:$router_port/health"; then
        record "$case_name" router_started fail "log=$router_log"
        kill "$router_pid" 2>/dev/null || true
        wait "$router_pid" 2>/dev/null || true
        router_pid=''
        return
    fi

    # the initiating request, cancelled once its child is provably held
    chat_body model-a >"$case_directory/request-a.json"
    curl -sS --max-time "$deadline_seconds" -o "$case_directory/response-a.json" \
        -X POST "http://127.0.0.1:$router_port/v1/chat/completions" \
        -H 'Content-Type: application/json' --data-binary "@$case_directory/request-a.json" \
        >/dev/null 2>&1 &
    curl_a=$!
    curl_pids="$curl_pids $curl_a"
    if wait_until 'first child at the bind barrier' held_count_at_least "$barrier_directory" 1; then
        record "$case_name" child_a_held pass "port=$(latest_held_port "$barrier_directory")"
    else
        record "$case_name" child_a_held fail "no held file under $barrier_directory"
    fi
    held_port_a=$(latest_held_port "$barrier_directory")
    kill "$curl_a" 2>/dev/null || true
    wait "$curl_a" 2>/dev/null || true
    if wait_until 'the router logs the cancellation' \
        log_count_at_least "$router_log" 'request cancelled while waiting for model name=model-a' 1; then
        record "$case_name" request_a_cancelled_during_load pass "held_port=$held_port_a"
    else
        record "$case_name" request_a_cancelled_during_load fail 'no cancellation line'
    fi

    # the follow-up, observed by the router before the hold is released
    chat_body "$followup_model" >"$case_directory/request-b.json"
    curl -sS --max-time "$deadline_seconds" -o "$case_directory/response-b.json" \
        -w '%{http_code}' -X POST "http://127.0.0.1:$router_port/v1/chat/completions" \
        -H 'Content-Type: application/json' --data-binary "@$case_directory/request-b.json" \
        >"$case_directory/status-b" 2>"$case_directory/curl-b.stderr" &
    curl_b=$!
    curl_pids="$curl_pids $curl_b"
    if [ "$followup_model" = model-a ]; then
        followup_pattern='waiting until model name=model-a is fully loaded'
        followup_count=2
    else
        followup_pattern="request for name=$followup_model queued at position"
        followup_count=1
    fi
    if wait_until 'the router logs the follow-up waiting' \
        log_count_at_least "$router_log" "$followup_pattern" "$followup_count"; then
        record "$case_name" request_b_waiting_before_release pass "pattern=$followup_pattern"
    else
        record "$case_name" request_b_waiting_before_release fail "pattern=$followup_pattern"
    fi

    printf '%s\n' "$first_release_verdict" >"$barrier_directory/release-$held_port_a"
    if [ "$expect_second_child" = yes ]; then
        if wait_until 'second child at the bind barrier' held_count_at_least "$barrier_directory" 2; then
            held_port_b=$(latest_held_port "$barrier_directory")
            printf 'ok\n' >"$barrier_directory/release-$held_port_b"
            record "$case_name" second_child_spawned pass "port=$held_port_b"
        else
            record "$case_name" second_child_spawned fail 'no second held file before the deadline'
        fi
    fi

    if wait_until 'the follow-up request terminates' process_gone "$curl_b"; then
        status_b=$(cat "$case_directory/status-b" 2>/dev/null || true)
        if [ "$status_b" = 200 ] && jq -e '.choices | length > 0' "$case_directory/response-b.json" >/dev/null 2>&1; then
            record "$case_name" request_b_answered pass "http=$status_b"
        else
            record "$case_name" request_b_answered fail "http=${status_b:-none} body=$(head -c 200 "$case_directory/response-b.json" 2>/dev/null | tr -d '\n')"
        fi
    else
        kill "$curl_b" 2>/dev/null || true
        record "$case_name" request_b_answered fail "no answer within ${deadline_seconds}s"
    fi

    status_a=$(model_status model-a "$router_port")
    status_b_model=$(model_status model-b "$router_port")
    if [ "$status_a" = "$expected_a_status" ] && [ "$status_b_model" = "$expected_b_status" ]; then
        record "$case_name" final_model_states pass "model-a=$status_a model-b=$status_b_model"
    else
        record "$case_name" final_model_states fail "model-a=$status_a model-b=$status_b_model expected $expected_a_status/$expected_b_status"
    fi
    if [ "$first_release_verdict" = fail ]; then
        if [ "$(model_failed model-a "$router_port")" = true ]; then
            record "$case_name" model_a_reads_failed pass 'status.failed=true'
        else
            record "$case_name" model_a_reads_failed fail 'status.failed absent'
        fi
    fi

    kill "$router_pid" 2>/dev/null || true
    wait "$router_pid" 2>/dev/null || true
    router_pid=''
    curl_pids=''
}

run_case different-model model-b ok yes unloaded loaded
run_case same-model model-a ok no loaded unloaded
run_case load-failure model-b fail yes unloaded loaded

printf 'router_cancelled_load=%s failures=%s results=%s\n' \
    "$([ "$failures" = 0 ] && printf accepted || printf refused)" "$failures" "$results"
[ "$failures" = 0 ]
