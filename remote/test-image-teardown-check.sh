#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
checker=$script_directory/image-teardown-check.sh
fake_runtime=$script_directory/test-fixtures/fake-image-runtime.sh
temporary_directory=$(mktemp -d)
runtime_pid=''
listener_pid=''
cleanup() {
    [ -z "$runtime_pid" ] || kill -KILL "$runtime_pid" 2>/dev/null || true
    [ -z "$runtime_pid" ] || wait "$runtime_pid" 2>/dev/null || true
    [ -z "$listener_pid" ] || kill -TERM "$listener_pid" 2>/dev/null || true
    [ -z "$listener_pid" ] || wait "$listener_pid" 2>/dev/null || true
    rm -rf "$temporary_directory"
}
trap cleanup EXIT HUP INT TERM

runtime_state=$temporary_directory/runtime-state
mkdir -p "$runtime_state"
QWEN_FAKE_IMAGE_MODE=hang "$fake_runtime" \
    --output "$temporary_directory/runtime.png" --width 64 --height 64 --seed 1 \
    --backend te=Vulkan0,vae=Vulkan0,diffusion=Vulkan0 \
    >"$temporary_directory/runtime.out" 2>&1 &
runtime_pid=$!
sleep 1
runtime_pattern="^(([^ ]*/)?[^ ]*sh )?$fake_runtime( |$)"
if QWEN_IMAGE_RUNTIME_PATTERN=$runtime_pattern "$checker" "$runtime_state" \
    >"$temporary_directory/runtime-check.out" 2>&1
then
    runtime_status=refused
else
    runtime_status=accepted
fi
grep -q '^image runtime processes survive:' "$temporary_directory/runtime-check.out" ||
    runtime_status=refused
kill -KILL "$runtime_pid" 2>/dev/null || true
wait "$runtime_pid" 2>/dev/null || true
runtime_pid=''
printf 'interpreter_runtime_detected=%s\n' "$runtime_status"

socket_state=$temporary_directory/socket-state
socket_path=$socket_state/images/image-service.sock
mkdir -p "$socket_state/images"
python3 - "$socket_path" <<'PYTHON' &
import signal
import socket
import sys
import time

listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
listener.bind(sys.argv[1])
listener.listen(4)
signal.signal(signal.SIGTERM, lambda _signum, _frame: sys.exit(0))
while True:
    time.sleep(0.1)
PYTHON
listener_pid=$!
wait_attempt=0
while [ ! -S "$socket_path" ] && [ "$wait_attempt" -lt 50 ]; do
    sleep 0.1
    wait_attempt=$((wait_attempt + 1))
done

if QWEN_IMAGE_RUNTIME_PATTERN='^/definitely/not/matching$' \
    "$checker" "$socket_state" >"$temporary_directory/live-socket.out" 2>&1
then
    live_socket_status=refused
else
    live_socket_status=accepted
fi
[ -S "$socket_path" ] || live_socket_status=refused
grep -q '^live control socket remains:' "$temporary_directory/live-socket.out" ||
    live_socket_status=refused
kill -TERM "$listener_pid"
wait "$listener_pid" 2>/dev/null || true
listener_pid=''

if QWEN_IMAGE_RUNTIME_PATTERN='^/definitely/not/matching$' \
    "$checker" "$socket_state" >"$temporary_directory/stale-socket.out" 2>&1
then
    stale_socket_status=accepted
else
    stale_socket_status=refused
fi
[ ! -e "$socket_path" ] || stale_socket_status=refused
grep -q '^stale control socket removed:' "$temporary_directory/stale-socket.out" ||
    stale_socket_status=refused

printf 'live_socket_preserved=%s\n' "$live_socket_status"
printf 'stale_socket_removed=%s\n' "$stale_socket_status"
[ "$runtime_status" = accepted ]
[ "$live_socket_status" = accepted ]
[ "$stale_socket_status" = accepted ]
printf 'test-image-teardown-check=accepted\n'
