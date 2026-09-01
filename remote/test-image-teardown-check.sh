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
lease_holder_pid=''
cleanup() {
    [ -z "$runtime_pid" ] || kill -KILL "$runtime_pid" 2>/dev/null || true
    [ -z "$runtime_pid" ] || wait "$runtime_pid" 2>/dev/null || true
    [ -z "$listener_pid" ] || kill -TERM "$listener_pid" 2>/dev/null || true
    [ -z "$listener_pid" ] || wait "$listener_pid" 2>/dev/null || true
    [ -z "$lease_holder_pid" ] || kill -TERM "$lease_holder_pid" 2>/dev/null || true
    [ -z "$lease_holder_pid" ] || wait "$lease_holder_pid" 2>/dev/null || true
    rm -rf "$temporary_directory"
}
trap cleanup EXIT HUP INT TERM

start_lease_holder() {
    holder_lock_path=$1
    holder_proof_path=$2
    holder_ready_path=$3
    holder_release_path=$4
    python3 - "$holder_lock_path" "$holder_proof_path" "$holder_ready_path" \
        "$holder_release_path" <<'PYTHON' &
import fcntl
import os
import sys
import time
from pathlib import Path

lock_path = Path(sys.argv[1])
proof_path = Path(sys.argv[2])
ready_path = Path(sys.argv[3])
release_path = Path(sys.argv[4])

descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
fcntl.flock(descriptor, fcntl.LOCK_EX)
if descriptor != 8:
    os.dup2(descriptor, 8, inheritable=True)
    os.close(descriptor)
else:
    os.set_inheritable(8, True)

stat_text = Path(f"/proc/{os.getpid()}/stat").read_text(encoding="ascii")
start_time_ticks = stat_text[stat_text.rfind(")") + 2 :].split()[19]
proof_path.write_text(
    "key\tvalue\n"
    "schema\tfixed64-vulkan-external-lease-v1\n"
    f"lock_path\t{lock_path}\n"
    f"holder_pid\t{os.getpid()}\n"
    f"holder_start_time_ticks\t{start_time_ticks}\n"
    "holder_fd\t8\n"
    f"source_revision\t{'0' * 40}\n",
    encoding="utf-8",
)
proof_path.chmod(0o600)
ready_path.write_text("ready\n", encoding="ascii")
while not release_path.exists():
    time.sleep(0.02)
PYTHON
    lease_holder_pid=$!
}

wait_for_file() {
    awaited_path=$1
    wait_attempt=0
    while [ ! -s "$awaited_path" ] && [ "$wait_attempt" -lt 250 ]; do
        sleep 0.02
        wait_attempt=$((wait_attempt + 1))
    done
    [ -s "$awaited_path" ]
}

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

lease_state=$temporary_directory/lease-state
lease_lock=$lease_state/vulkan-workload.lock
first_proof=$temporary_directory/first-external-lease.tsv
first_ready=$temporary_directory/first-external-lease.ready
first_release=$temporary_directory/first-external-lease.release
mkdir -p "$lease_state"
start_lease_holder "$lease_lock" "$first_proof" "$first_ready" "$first_release"
wait_for_file "$first_ready"

if QWEN_IMAGE_RUNTIME_PATTERN='^/definitely/not/matching$' \
    "$checker" "$lease_state" >"$temporary_directory/unproved-lease.out" 2>&1
then
    unproved_lease_status=refused
else
    unproved_lease_status=accepted
fi
grep -q '^vulkan workload lease is held without a verified external owner:' \
    "$temporary_directory/unproved-lease.out" || unproved_lease_status=refused

if QWEN_IMAGE_RUNTIME_PATTERN='^/definitely/not/matching$' \
    QWEN_VULKAN_EXTERNAL_LEASE_PROOF=$first_proof \
    "$checker" "$lease_state" >"$temporary_directory/verified-lease.out" 2>&1
then
    verified_lease_status=accepted
else
    verified_lease_status=refused
fi
grep -q '^vulkan workload lease has a verified external owner:' \
    "$temporary_directory/verified-lease.out" || verified_lease_status=refused

: >"$first_release"
wait "$lease_holder_pid"
lease_holder_pid=''

second_proof=$temporary_directory/second-external-lease.tsv
second_ready=$temporary_directory/second-external-lease.ready
second_release=$temporary_directory/second-external-lease.release
start_lease_holder "$lease_lock" "$second_proof" "$second_ready" "$second_release"
wait_for_file "$second_ready"
if QWEN_IMAGE_RUNTIME_PATTERN='^/definitely/not/matching$' \
    QWEN_VULKAN_EXTERNAL_LEASE_PROOF=$first_proof \
    "$checker" "$lease_state" >"$temporary_directory/stale-lease.out" 2>&1
then
    stale_lease_status=refused
else
    stale_lease_status=accepted
fi
grep -q '^external_vulkan_lease=rejected reason=' \
    "$temporary_directory/stale-lease.out" || stale_lease_status=refused
: >"$second_release"
wait "$lease_holder_pid"
lease_holder_pid=''

printf 'unproved_external_lease_rejected=%s\n' "$unproved_lease_status"
printf 'verified_external_lease_accepted=%s\n' "$verified_lease_status"
printf 'stale_external_lease_rejected=%s\n' "$stale_lease_status"
[ "$runtime_status" = accepted ]
[ "$live_socket_status" = accepted ]
[ "$stale_socket_status" = accepted ]
[ "$unproved_lease_status" = accepted ]
[ "$verified_lease_status" = accepted ]
[ "$stale_lease_status" = accepted ]
printf 'test-image-teardown-check=accepted\n'
