#!/bin/sh
set -eu

# Stop the Web UI and prove nothing survived. The exit status reports the
# machine's state rather than the attempt: a surviving process, tmux session,
# or listener fails the script so a caller cannot mistake a partial stop for a
# clean one.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
server_port=${QWEN_SERVER_PORT:-8080}
status_file=$state_directory/session.status

# The session script rewrites session.status to state=stopped as it exits,
# which drops the guard PIDs, so read them before asking it to stop.
guard_pids=''
if [ -r "$status_file" ]; then
    guard_pids=$(sed -n '1p' "$status_file" | tr ' ' '\n' |
        sed -n 's/^\(monitor_pid\|latency_watchdog_pid\|kernel_hazard_watchdog_pid\)=//p')
fi

"$script_directory/qwen-webui-control.sh" stop || true

attempt=0
while [ "$attempt" -lt 300 ] && pgrep -x llama-server >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    sleep 0.1
done

# `tmux kill-session` ends the session script without running its EXIT trap, so
# the guards it launched are orphaned rather than cleaned up: a probe observed
# this way kept submitting to the graphics queue every 16 ms after the server
# had gone. The session recorded each guard's PID, so signal those rather than
# matching command lines: `pgrep -f` also matches any shell whose arguments
# happen to contain the pattern, including the one running this script.
for guard_pid in $guard_pids; do
    case $guard_pid in
        '' | *[!0-9]*) continue ;;
    esac
    if kill -0 "$guard_pid" 2>/dev/null; then
        printf 'stopping guard pid %s (%s)\n' \
            "$guard_pid" "$(ps -o comm= -p "$guard_pid" 2>/dev/null | tr -d ' ')"
        kill -TERM "$guard_pid" 2>/dev/null || true
    fi
done

# The probe is matched by executable name, which cannot collide with a shell
# that merely mentions it.
probe_pids=$(pgrep -x vulkan-graphics-service-probe 2>/dev/null || true)
for probe_pid in $probe_pids; do
    kill -TERM "$probe_pid" 2>/dev/null || true
done

attempt=0
while [ "$attempt" -lt 100 ] && \
      pgrep -x vulkan-graphics-service-probe >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    sleep 0.1
done
for probe_pid in $(pgrep -x vulkan-graphics-service-probe 2>/dev/null || true); do
    kill -KILL "$probe_pid" 2>/dev/null || true
done

residue=0
if pgrep -x llama-server >/dev/null 2>&1; then
    printf 'llama-server still running: %s\n' \
        "$(pgrep -x llama-server | tr '\n' ' ')" >&2
    residue=1
fi
if tmux -L qwen-runtime has-session -t qwen-webui 2>/dev/null; then
    printf 'tmux session qwen-webui still present\n' >&2
    residue=1
fi
if pgrep -x vulkan-graphics-service-probe >/dev/null 2>&1; then
    printf 'graphics latency probe still running: %s\n' \
        "$(pgrep -x vulkan-graphics-service-probe | tr '\n' ' ')" >&2
    residue=1
fi
if command -v ss >/dev/null 2>&1 && \
   ss -ltn "sport = :$server_port" 2>/dev/null | grep -q ":$server_port"; then
    printf 'port %s still has a listener\n' "$server_port" >&2
    residue=1
fi

rm -f "$state_directory/server.pid"
if [ "$residue" -eq 0 ]; then
    printf 'torn down: no llama-server, no tmux session, no probe, port %s free\n' \
        "$server_port"
else
    printf 'teardown incomplete\n' >&2
fi
exit "$residue"
