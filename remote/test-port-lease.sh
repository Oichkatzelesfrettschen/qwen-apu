#!/bin/sh
set -eu

# Claim loopback TCP ports for a fixture and hold them until the fixture exits.
#
# Binding port zero and closing the socket reports a port that was free at the
# instant of the read and owns nothing afterwards, so two fixtures running at
# once on this workstation receive the same number whenever the kernel reuses
# it, and the second listener meets EADDRINUSE. A claim here is an exclusive
# flock on a per-port lease file held by a holder process for the fixture's
# whole lifetime, so a concurrent claim of the same number is refused while the
# first fixture still runs.
#
# The holder picks each candidate below the kernel's own ephemeral range
# (/proc/sys/net/ipv4/ip_local_port_range), which keeps a claimed number off
# the range an unrelated process receives from a bind to port zero, takes the
# lease file's flock without blocking, and proves the port unbound by binding
# it with SO_REUSEADDR off before publishing it. It then holds every lease
# descriptor open and sleeps, so the claim stands until the fixture kills it.
#
# QWEN_TEST_PORT_LEASE_DIR is the coordination point: two gate runs that name
# one directory serialize against each other, and two that name different
# directories coordinate nothing. The default is this tree's own gate scratch
# root, which coordinates the cells of one repository's gate run; a workstation
# gating two repositories at once sets the variable to one directory in both.
#
# claim-run leases COUNT consecutive numbers instead of COUNT independent ones,
# which is what a caller whose own children derive one port from another needs:
# webui/index.html derives the broker at the router port plus one and the
# artifact listener at plus two on a bare LAN URL, and qwen-web-launch.sh
# refuses a broker port the advertised page URL does not derive.
#
# Usage:
#   holder_pid=$(test-port-lease.sh claim COUNT PORTS_FILE)
#   holder_pid=$(test-port-lease.sh claim-run COUNT PORTS_FILE)
#   test-port-lease.sh release "$holder_pid"
#
# claim writes COUNT port numbers, one per line, to PORTS_FILE and prints the
# holder pid on stdout. release signals that holder and waits for the leases to
# drop. A fixture calls release from its own EXIT trap.

usage() {
    printf 'usage: %s claim|claim-run COUNT PORTS_FILE | %s release HOLDER_PID\n' \
        "$0" "$0" >&2
    exit 2
}

[ "$#" -ge 1 ] || usage
port_lease_command=$1
shift

port_lease_script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

port_lease_directory=${QWEN_TEST_PORT_LEASE_DIR:-}
if [ -z "$port_lease_directory" ]; then
    if [ -x "$port_lease_script_directory/qwen-home.sh" ]; then
        port_lease_directory=$("$port_lease_script_directory/qwen-home.sh" \
            print qwen_home_gate_cache)/port-leases
    else
        port_lease_directory=${TMPDIR:-/tmp}/qwen-test-port-leases
    fi
fi

case $port_lease_command in
    claim | claim-run)
        [ "$#" -eq 2 ] || usage
        port_lease_count=$1
        port_lease_ports_file=$2
        case $port_lease_count in
            '' | *[!0-9]* | 0)
                printf 'test-port-lease: COUNT must be a positive integer\n' >&2
                exit 2
                ;;
        esac
        mkdir -p "$port_lease_directory"
        : >"$port_lease_ports_file"
        # The holder writes the ports file and then blocks; the claim returns
        # once that file carries the ready marker, so a caller that reads it
        # reads a published set rather than a partial write.
        # The holder's own stdout goes to stderr: this command runs inside the
        # caller's command substitution, which reads until every writer of the
        # pipe closes it, and a holder that outlives the claim holds it open.
        QWEN_TEST_PORT_LEASE_DIR=$port_lease_directory \
            python3 -u - "$port_lease_command" "$port_lease_count" \
            "$port_lease_ports_file" >&2 <<'PYTHON' &
import os
import random
import signal
import socket
import sys
import fcntl

# The holder is forked from a shell that may already hold flocks on descriptors
# of its own -- remote/test-measure-mtp-arm.sh and remote/test-measure-draft-pair.sh
# each hold one on descriptor 7 -- and an inherited descriptor would keep that
# lock alive for the holder's whole lifetime. `python3 -` has read this program
# off stdin by now, so every descriptor above stderr goes before any lease file
# is opened.
os.closerange(3, 4096)

lease_mode = sys.argv[1]
lease_count = int(sys.argv[2])
ports_path = sys.argv[3]
lease_directory = os.environ["QWEN_TEST_PORT_LEASE_DIR"]


def candidate_range():
    """Ports below the kernel's own ephemeral range, so a claimed number is
    outside the set a bind to port zero anywhere on this machine returns."""
    try:
        with open("/proc/sys/net/ipv4/ip_local_port_range", encoding="ascii") as handle:
            ephemeral_low = int(handle.read().split()[0])
    except (OSError, ValueError, IndexError):
        ephemeral_low = 32768
    low = 20000
    high = min(ephemeral_low - 1, 32767)
    if high <= low:
        low, high = 20000, 32767
    return low, high


def port_is_unbound(port):
    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        probe.bind(("127.0.0.1", port))
    except OSError:
        return False
    finally:
        probe.close()
    return True


def take_port(port):
    """An exclusive flock on the port's lease file and a bind that proves the
    port unbound, or None where either refuses."""
    lease_path = os.path.join(lease_directory, "%d.lease" % port)
    descriptor = os.open(lease_path, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(descriptor)
        return None
    if not port_is_unbound(port):
        os.close(descriptor)
        return None
    return descriptor


held_descriptors = []
claimed_ports = []
low, high = candidate_range()
attempts = 0
while len(claimed_ports) < lease_count:
    attempts += 1
    if attempts > 4096:
        sys.stderr.write("test-port-lease: no free port after 4096 attempts\n")
        sys.exit(1)
    if lease_mode == "claim-run":
        base = random.randint(low, high - lease_count + 1)
        run_descriptors = []
        for offset in range(lease_count):
            descriptor = take_port(base + offset)
            if descriptor is None:
                break
            run_descriptors.append(descriptor)
        if len(run_descriptors) < lease_count:
            for descriptor in run_descriptors:
                os.close(descriptor)
            continue
        held_descriptors = run_descriptors
        claimed_ports = [base + offset for offset in range(lease_count)]
        break
    port = random.randint(low, high)
    if port in claimed_ports:
        continue
    descriptor = take_port(port)
    if descriptor is None:
        continue
    held_descriptors.append(descriptor)
    claimed_ports.append(port)

with open(ports_path, "w", encoding="ascii") as handle:
    for port in claimed_ports:
        handle.write("%d\n" % port)
    handle.write("ready\n")
    handle.flush()
    os.fsync(handle.fileno())

signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
signal.pause()
PYTHON
        port_lease_holder_pid=$!
        port_lease_ticks=200
        while ! grep -qx 'ready' "$port_lease_ports_file" 2>/dev/null; do
            port_lease_ticks=$((port_lease_ticks - 1))
            if [ "$port_lease_ticks" -le 0 ] || \
               ! kill -0 "$port_lease_holder_pid" 2>/dev/null; then
                printf 'test-port-lease: holder failed to publish %s ports\n' \
                    "$port_lease_count" >&2
                kill "$port_lease_holder_pid" 2>/dev/null || true
                exit 1
            fi
            sleep 0.05
        done
        # The ready marker is the publication boundary and the caller reads
        # numbers alone, so it leaves the file carrying the ports only.
        grep -vx 'ready' "$port_lease_ports_file" >"$port_lease_ports_file.ports"
        mv "$port_lease_ports_file.ports" "$port_lease_ports_file"
        printf '%s\n' "$port_lease_holder_pid"
        ;;
    release)
        [ "$#" -eq 1 ] || usage
        port_lease_holder_pid=$1
        [ -n "$port_lease_holder_pid" ] || exit 0
        kill "$port_lease_holder_pid" 2>/dev/null || true
        # The holder is a child of the claim's own command substitution rather
        # than of the fixture, so release proves its exit by polling /proc
        # through kill -0 where wait has no such child to reap.
        port_lease_ticks=100
        while kill -0 "$port_lease_holder_pid" 2>/dev/null; do
            port_lease_ticks=$((port_lease_ticks - 1))
            if [ "$port_lease_ticks" -le 0 ]; then
                kill -KILL "$port_lease_holder_pid" 2>/dev/null || true
                break
            fi
            sleep 0.05
        done
        ;;
    *)
        usage
        ;;
esac
