#!/bin/sh
set -eu

# Exercises remote/yacy-control.sh against `python3 -m http.server`
# `python3 -m http.server` standing in for the real service, so this test
# needs no SearXNG or YaCy install, no root, and no service account: both
# control scripts run as the invoking user when QWEN_*_SERVICE_USER names
# that user, and QWEN_*_LAUNCH_COMMAND replaces the real server invocation.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
yacy_control=$script_directory/yacy-control.sh

if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 not found: not_run\n'
    exit 0
fi

work_directory=$(mktemp -d)
port_lease_holder_pid=''
yacy_port=''
cleanup() {
    QWEN_YACY_INSTALL_DIRECTORY="$work_directory/yacy" \
        QWEN_YACY_PID_FILE="$work_directory/yacy/yacy.pid" \
        QWEN_YACY_LOG_FILE="$work_directory/yacy/yacy.log" \
        QWEN_YACY_PORT=$yacy_port \
        "$yacy_control" stop >/dev/null 2>&1 || true
    if [ -n "$port_lease_holder_pid" ]; then
        "$script_directory/test-port-lease.sh" release \
            "$port_lease_holder_pid" || true
        port_lease_holder_pid=''
    fi
    rm -rf "$work_directory"
}
trap cleanup EXIT

# The fake listener binds the port itself, so the test holds a lease over the
# number rather than the socket: a holder process keeps an exclusive flock on
# the port's lease file for this script's whole run.
port_lease_ports_file=$work_directory/leased-ports
port_lease_holder_pid=$("$script_directory/test-port-lease.sh" claim 1 \
    "$port_lease_ports_file")
yacy_port=$(sed -n 1p "$port_lease_ports_file")

mkdir -p "$work_directory/yacy"

# No real stopYACY.sh exists against a fake listener, so
# QWEN_YACY_STOP_COMMAND is the direct signal yacy-control.sh's own
# force-kill fallback would eventually send, and a short stop timeout keeps
# this test from waiting out the real, much longer production default before
# reaching it.
run_yacy_control() {
    QWEN_YACY_INSTALL_DIRECTORY="$work_directory/yacy" \
        QWEN_YACY_PID_FILE="$work_directory/yacy/yacy.pid" \
        QWEN_YACY_LOG_FILE="$work_directory/yacy/yacy.log" \
        QWEN_YACY_PORT=$yacy_port \
        QWEN_YACY_BIND_ADDRESS=127.0.0.1 \
        QWEN_YACY_LAUNCH_COMMAND="python3 -m http.server $yacy_port --bind 127.0.0.1 --directory $work_directory" \
        QWEN_YACY_STOP_COMMAND="kill -TERM \$(cat '$work_directory/yacy/yacy.pid')" \
        QWEN_YACY_START_TIMEOUT=10 \
        QWEN_YACY_STOP_TIMEOUT=10 \
        "$yacy_control" "$@"
}

check_control_lifecycle() {
    label=$1
    runner=$2
    pid_file=$3
    port=$4

    status_output=$($runner status 2>&1) && status_exit=0 || status_exit=$?
    printf '%s\n' "$status_output"
    [ "$status_exit" -eq 1 ]
    printf '%s\n' "$status_output" | grep -F 'state=stopped' >/dev/null

    start_output=$($runner start)
    printf '%s\n' "$start_output"
    printf '%s\n' "$start_output" | grep -F 'started: pid=' >/dev/null
    [ -f "$pid_file" ]

    status_output=$($runner status)
    printf '%s\n' "$status_output"
    printf '%s\n' "$status_output" | grep -F 'state=running pid=' >/dev/null
    printf '%s\n' "$status_output" | grep -F "127.0.0.1:$port" >/dev/null

    curl_status=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/")
    [ "$curl_status" -ge 200 ] && [ "$curl_status" -lt 500 ]

    already_output=$($runner start 2>&1) && already_exit=0 || already_exit=$?
    [ "$already_exit" -eq 2 ]
    printf '%s\n' "$already_output" | grep -F 'already running: pid=' >/dev/null

    stop_output=$($runner stop)
    printf '%s\n' "$stop_output"
    printf '%s\n' "$stop_output" | grep -F 'stopped: pid=' >/dev/null
    [ ! -f "$pid_file" ]

    status_output=$($runner status 2>&1) && status_exit=0 || status_exit=$?
    [ "$status_exit" -eq 1 ]
    printf '%s\n' "$status_output" | grep -F 'state=stopped' >/dev/null

    stop_again_output=$($runner stop)
    printf '%s\n' "$stop_again_output" | grep -F 'not running' >/dev/null

    printf '%s: lifecycle checks passed\n' "$label"
}

check_control_lifecycle yacy-control run_yacy_control \
    "$work_directory/yacy/yacy.pid" "$yacy_port"
