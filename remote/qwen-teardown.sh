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
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"$qwen_home_state"}
server_port=${QWEN_SERVER_PORT:-8080}
status_file=$state_directory/session.status

# The session script rewrites session.status to state=stopped as it exits,
# which drops the guard PIDs, so read them before asking it to stop.
guard_pids=''
broker_pid=''
broker_secret_file=''
if [ -r "$status_file" ]; then
    guard_pids=$(sed -n '1p' "$status_file" | tr ' ' '\n' |
        sed -n 's/^\(monitor_pid\|latency_watchdog_pid\|kernel_hazard_watchdog_pid\)=//p')
    # The broker is read a second time on its own, because its absence proof
    # covers a file as well as a process: it unlinks its per-launch session
    # secret while unwinding from SIGTERM, and a secret surviving the teardown
    # authorizes a page against the next launch. A session that ran no broker
    # records no field here, so an ordinary teardown proves nothing about a
    # secret file a manual broker run left behind.
    broker_pid=$(sed -n '1p' "$status_file" | tr ' ' '\n' |
        sed -n 's/^broker_pid=//p')
    # The session records the secret's path whole on its own line, so the proof
    # reads the file the broker actually wrote: QWEN_WEB_STATE_DIR reaches that
    # session alone, and re-deriving the default here would prove the absence
    # of a file a configured launch placed elsewhere.
    broker_secret_file=$(sed -n 's/^broker secret_file=//p' "$status_file")
    # The recorded start time binds the PID to the process /health identified
    # at launch. A PID is reused once its process exits, so a number alone
    # would signal whatever now holds it.
    broker_start_time=$(sed -n 's/^broker_identity .*start_time=\([0-9]*\).*/\1/p' \
        "$status_file")
    # The image service owns the Vulkan workload lease, the control socket, and
    # any partial artifact, so its pid is read here for the reason the broker's
    # is: `tmux kill-session` ends the session script without running its EXIT
    # trap, and a surviving service holds the lease against the next launch.
    image_service_pid=$(sed -n '1p' "$status_file" | tr ' ' '\n' |
        sed -n 's/^image_service_pid=//p')
    image_service_start_time=$(sed -n \
        's/^image_service_identity .*start_time=\([0-9]*\).*/\1/p' \
        "$status_file")
    # The search instance is read the same way, and its port comes off the
    # identity line rather than from a default here: the session bound the
    # listener the profile row names, and a teardown re-deriving 8888 would
    # prove the absence of a listener another launch placed elsewhere.
    searxng_pid=$(sed -n '1p' "$status_file" | tr ' ' '\n' |
        sed -n 's/^searxng_pid=//p')
    searxng_start_time=$(sed -n \
        's/^searxng_identity .*start_time=\([0-9]*\) .*/\1/p' "$status_file")
    searxng_port=$(sed -n \
        's/^searxng_identity .*port=\([0-9]*\) .*/\1/p' "$status_file")
fi
broker_start_time=${broker_start_time:-}
image_service_pid=${image_service_pid:-}
image_service_start_time=${image_service_start_time:-}
searxng_pid=${searxng_pid:-}
searxng_start_time=${searxng_start_time:-}
searxng_port=${searxng_port:-}

# The teardown stage runs from the stop request to the server's departure. The
# record is the launch's own, named on the `state=running` line the session
# wrote, so a configured state directory is read rather than re-derived; a
# session that failed before that line names no path and the default beside the
# status file is what this teardown appends to.
stage_timing=$script_directory/stage-timing.sh
stage_timing_file=''
if [ -r "$status_file" ]; then
    stage_timing_file=$(sed -n '1p' "$status_file" | tr ' ' '\n' |
        sed -n 's/^stage_timing=//p')
fi
[ -n "$stage_timing_file" ] || stage_timing_file=$state_directory/stage-timing.tsv
stage_signal_ns=$("$stage_timing" now) || stage_signal_ns=''

"$script_directory/qwen-webui-control.sh" stop || true

# Forced tmux termination bypasses the session EXIT trap. Once control has
# stopped the only session that can own these unique snapshots, remove the
# reserved active-session files left by either forced or interrupted startup.
snapshot_residue=0
for router_preset_snapshot in "$state_directory"/.router-presets.active.*; do
    [ -e "$router_preset_snapshot" ] || \
        [ -L "$router_preset_snapshot" ] || continue
    if [ -f "$router_preset_snapshot" ] || [ -L "$router_preset_snapshot" ]; then
        rm -f -- "$router_preset_snapshot"
    else
        printf 'router snapshot path is not a regular file: %s\n' \
            "$router_preset_snapshot" >&2
        snapshot_residue=1
    fi
done

attempt=0
while [ "$attempt" -lt 300 ] && pgrep -x llama-server >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    sleep 0.1
done
# The stage ends where the wait answers, and a wait that spent its whole budget
# with a server still running records `-`: the boundary the stage measures never
# arrived, and the residue proof below is what reports the survivor.
if [ -n "$stage_signal_ns" ]; then
    stage_exit_ns=-
    if [ "$attempt" -lt 300 ]; then
        stage_exit_ns=$("$stage_timing" now) || stage_exit_ns=-
    fi
    "$stage_timing" record "$stage_timing_file" teardown_signal_to_exit \
        "$stage_signal_ns" "$stage_exit_ns" || :
fi

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

# The broker unlinks its session secret in the cleanup that runs after the
# accept loop unwinds, so the file check waits for the process to leave rather
# than reading the directory while it is still writing. A broker that survives
# the signal is residue, and so is a secret file outliving the broker that
# wrote it.
broker_residue=0
case $broker_pid in
    '' | *[!0-9]*) broker_pid='' ;;
esac
if [ -n "$broker_pid" ] && [ -n "$broker_start_time" ] && \
   [ -r "/proc/$broker_pid/stat" ]; then
    # Field 22 of /proc/PID/stat is the start time in clock ticks. The comm
    # field before it may hold spaces, so the fields are counted from the
    # closing parenthesis rather than from the line start.
    live_start_time=$(sed 's/^.*) //' "/proc/$broker_pid/stat" |
        awk '{ print $20 }')
    if [ "$live_start_time" != "$broker_start_time" ]; then
        printf 'pid %s now belongs to another process (start %s recorded, %s live); the broker is gone\n' \
            "$broker_pid" "$broker_start_time" "$live_start_time" >&2
        broker_pid=''
    fi
fi
if [ -n "$broker_pid" ]; then
    # The broker is signalled here rather than with the guards above, after
    # the start-time comparison has bound the number to the process.
    if kill -0 "$broker_pid" 2>/dev/null; then
        printf 'stopping approval broker pid %s\n' "$broker_pid"
        kill -TERM "$broker_pid" 2>/dev/null || true
    fi
    attempt=0
    while [ "$attempt" -lt 100 ] && kill -0 "$broker_pid" 2>/dev/null; do
        attempt=$((attempt + 1))
        sleep 0.1
    done
    if kill -0 "$broker_pid" 2>/dev/null; then
        printf 'approval broker still running: %s\n' "$broker_pid" >&2
        broker_residue=1
    fi
fi
# The secret file is proved absent on its own: a status file whose PID field
# is missing or malformed still names the path, and a surviving secret
# authorizes a page against the next launch whatever became of the process.
if [ -n "$broker_secret_file" ] && \
   { [ -e "$broker_secret_file" ] || [ -L "$broker_secret_file" ]; }; then
    printf 'approval broker session secret survives: %s\n' \
        "$broker_secret_file" >&2
    broker_residue=1
fi

# The image service is signalled after the start-time comparison has bound the
# number to the process, the way the broker is, and its absence is then proved
# by remote/image-teardown-check.sh, which reads process and filesystem state
# rather than the attempt: a live service, a live runtime, a partial artifact,
# or a held lease each fail it. A session that ran none records no pid, and the
# check runs anyway, because a manual run leaves the same residue.
case $image_service_pid in
    '' | *[!0-9]*) image_service_pid='' ;;
esac
# The signal goes to a pid whose identity this teardown proved. A recorded
# number with no recorded start time identifies nothing, and the service holds
# the Vulkan workload lease, so an unproven pid is left alone and
# image-teardown-check.sh reports whatever survives rather than a signal
# reaching whichever process now holds that number.
if [ -n "$image_service_pid" ]; then
    if [ -z "$image_service_start_time" ] || \
       [ ! -r "/proc/$image_service_pid/stat" ]; then
        printf 'pid %s carries no recorded start time, so the image service is left to the residue proof\n' \
            "$image_service_pid" >&2
        image_service_pid=''
    else
        live_image_start_time=$(sed 's/^.*) //' "/proc/$image_service_pid/stat" |
            awk '{ print $20 }')
        if [ "$live_image_start_time" != "$image_service_start_time" ]; then
            printf 'pid %s now belongs to another process (start %s recorded, %s live); the image service is gone\n' \
                "$image_service_pid" "$image_service_start_time" \
                "$live_image_start_time" >&2
            image_service_pid=''
        fi
    fi
fi
if [ -n "$image_service_pid" ] && kill -0 "$image_service_pid" 2>/dev/null; then
    printf 'stopping image service pid %s\n' "$image_service_pid"
    kill -TERM "$image_service_pid" 2>/dev/null || true
    attempt=0
    while [ "$attempt" -lt 200 ] && kill -0 "$image_service_pid" 2>/dev/null; do
        attempt=$((attempt + 1))
        sleep 0.1
    done
fi
# The search instance is signalled after the same start-time comparison, and
# its absence covers a process and a listener: a surviving instance holds the
# port the next launch's health gate reads, and that gate would then admit a
# launch whose own child had left.
searxng_residue=0
case $searxng_pid in
    '' | *[!0-9]*) searxng_pid='' ;;
esac
if [ -n "$searxng_pid" ]; then
    if [ -z "$searxng_start_time" ] || [ ! -r "/proc/$searxng_pid/stat" ]; then
        printf 'pid %s carries no recorded start time, so the search instance is left to the residue proof\n' \
            "$searxng_pid" >&2
        searxng_pid=''
    else
        live_searxng_start_time=$(sed 's/^.*) //' "/proc/$searxng_pid/stat" |
            awk '{ print $20 }')
        if [ "$live_searxng_start_time" != "$searxng_start_time" ]; then
            printf 'pid %s now belongs to another process (start %s recorded, %s live); the search instance is gone\n' \
                "$searxng_pid" "$searxng_start_time" \
                "$live_searxng_start_time" >&2
            searxng_pid=''
        fi
    fi
fi
if [ -n "$searxng_pid" ] && kill -0 "$searxng_pid" 2>/dev/null; then
    printf 'stopping search instance pid %s\n' "$searxng_pid"
    kill -TERM "$searxng_pid" 2>/dev/null || true
    attempt=0
    while [ "$attempt" -lt 200 ] && kill -0 "$searxng_pid" 2>/dev/null; do
        attempt=$((attempt + 1))
        sleep 0.1
    done
    if kill -0 "$searxng_pid" 2>/dev/null; then
        printf 'search instance still running: %s\n' "$searxng_pid" >&2
        searxng_residue=1
    fi
fi
if [ -n "$searxng_port" ] && command -v ss >/dev/null 2>&1 && \
   ss -ltn "sport = :$searxng_port" 2>/dev/null | grep -q ":$searxng_port"; then
    printf 'search instance port %s still has a listener\n' "$searxng_port" >&2
    searxng_residue=1
fi

image_residue=0
image_residue_prover=$script_directory/image-teardown-check.sh
if [ ! -x "$image_residue_prover" ]; then
    # An absent proof is not a proof of absence, so this counts as residue and
    # names the file rather than reaching the caller as a bare 127 from the
    # command substitution below. `rsync -a remote/` deploys the directory
    # whole, so a missing sibling states that the copy is partial.
    printf 'the image residue proof is absent or not executable: %s\n' \
        "$image_residue_prover" >&2
    image_residue=1
elif ! "$image_residue_prover" "$state_directory"; then
    image_residue=1
fi

residue=$snapshot_residue
if [ "$broker_residue" -ne 0 ]; then
    residue=1
fi
if [ "$image_residue" -ne 0 ]; then
    residue=1
fi
if [ "$searxng_residue" -ne 0 ]; then
    residue=1
fi
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
    printf 'torn down: no server, tmux session, probe, approval broker, image service, search instance, or router snapshot; port %s free\n' \
        "$server_port"
else
    printf 'teardown incomplete\n' >&2
fi
exit "$residue"
