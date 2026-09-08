#!/bin/sh
set -eu

# A named window in which the appliance stands torn down, bounded by an
# advisory lock that admits one window at a time and an EXIT trap that
# relaunches the appliance on every path out -- normal exit, a failing
# command, INT, and TERM alike.
#
# The device serves one llama-server at a time, so a maintenance command that
# needs the device idle -- a build, a fetch, a firmware read -- first has to
# stop the running session. Doing that by hand leaves the appliance offline
# on every path that is not the happy one: a command that fails, or a
# terminal that closes, leaves no server running and no trap to bring it
# back. This script makes the stop-relaunch pair one operation. It records
# the running session's relaunch profile before tearing down, runs the
# caller's command with the device idle, and relaunches through
# qwen-lan-launch.sh whatever the command's own exit path was.
#
# The lock is the same private-leaf construction runtime-root.sh uses for its
# deletion lock: open-verified-lock-descriptor.py opens
# $QWEN_HOME/state/device-window.lock without following a link or truncating
# retained bytes, refuses a foreign owner, a multiply-linked leaf, or a
# group-writable mode, and carries descriptor 7 across the one exec so the
# held lock survives this script replacing its own image. A non-blocking
# flock on that descriptor is the whole admission rule: a second window
# refuses rather than queuing, because a queued window would tear the
# appliance down again while the first window's command is still using the
# idle device. The re-exec carries the whole original argument list, so
# argument quoting for the caller's own command survives the descriptor
# hand-off unchanged.
#
# The relaunch profile comes from the running session's own status line
# rather than from an argument, because a window opened without repeating
# every launch decision is the point: qwen-webui-session.sh's `state=running`
# line carries `lan_boundary`, `lan_address`, `lan_open`, `host`, `port`, and
# `profile` (the Vulkan submission profile qwen-launch.sh took as its
# argument), and this script reads all five back for the relaunch. A
# `lan-open-approved` boundary was admitted at its own launch only because
# the operator supplied QWEN_WEB_LAN_TRUSTED_CONNECTIONS naming the trusted
# NetworkManager connection; that variable is not itself recorded on the
# status line (it is a policy input, not a session fact), so a window opened
# without it in its own environment cannot reproduce the open boundary and
# relaunches lan-authenticated instead, recording the substitution rather
# than silently narrowing the exposure.
#
# usage: run-device-window.sh [--no-session] NAME COMMAND [ARG...]
#        run-device-window.sh status
#   NAME                          identifies the window's own results
#                                 directory; [A-Za-z0-9][A-Za-z0-9._-]*
#   --no-session                  proceed with no running session recorded,
#                                 skipping teardown; refused by default so a
#                                 window opened against an already-idle
#                                 device does not relaunch one nobody asked
#                                 for
#   QWEN_DEVICE_WINDOW_TEARDOWN   path to run in place of qwen-teardown.sh
#   QWEN_DEVICE_WINDOW_LAUNCH     path to run in place of qwen-lan-launch.sh
#   QWEN_DEVICE_WINDOW_HEALTH_PROBE  command HOST PORT that answers the
#                                 post-relaunch health check in place of curl
#                                 (fixtures)

usage() {
    sed -n '46,59p' "$0" >&2
    exit 2
}

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

if [ "$#" -ge 1 ] && [ "$1" = status ]; then
    [ "$#" -eq 1 ] || usage
    window_status_file=$qwen_home_state/device-window.status
    if [ -f "$window_status_file" ]; then
        cat "$window_status_file"
    else
        printf 'no device window is open\n'
    fi
    exit 0
fi

# One exclusion admits one window. The descriptor is opened and carried
# across an exec ahead of anything else this script does, the discipline
# runtime-root.sh applies to its own deletion lock, so a concurrent window is
# refused before either window reads the running session or touches the
# device. The whole original argument list rides the exec unmodified.
command -v setsid >/dev/null 2>&1 || {
    printf 'setsid is required for protected restoration\n' >&2
    exit 2
}

lock_path=$qwen_home_state/device-window.lock
mkdir -p "$qwen_home_state"
case ${QWEN_DEVICE_WINDOW_LOCK_DESCRIPTOR_INHERITED:-0} in
    0)
        QWEN_DEVICE_WINDOW_LOCK_DESCRIPTOR_INHERITED=1
        export QWEN_DEVICE_WINDOW_LOCK_DESCRIPTOR_INHERITED
        exec "$script_directory/open-verified-lock-descriptor.py" open \
            "$lock_path" 7 "$0" "$@"
        ;;
    1)
        "$script_directory/open-verified-lock-descriptor.py" verify "$lock_path" 7
        ;;
    *)
        printf 'invalid device-window lock inheritance marker: %s\n' \
            "$QWEN_DEVICE_WINDOW_LOCK_DESCRIPTOR_INHERITED" >&2
        exit 2
        ;;
esac
if ! flock -n -x 7; then
    printf 'a device window is already open; run "%s status" to see it\n' "$0" >&2
    exit 1
fi

no_session=0
if [ "$#" -ge 1 ] && [ "$1" = --no-session ]; then
    no_session=1
    shift
fi
[ "$#" -ge 2 ] || usage
window_name=$1
shift
case $window_name in
    [A-Za-z0-9][A-Za-z0-9._-]*) ;;
    *)
        printf 'NAME must start with an alphanumeric and hold only alphanumerics, dot, underscore, and hyphen: %s\n' \
            "$window_name" >&2
        exit 2
        ;;
esac
command_program=$1
shift
# "$@" is now exactly the command's own arguments, quoting intact.

teardown_script=${QWEN_DEVICE_WINDOW_TEARDOWN:-"$script_directory/qwen-teardown.sh"}
launch_script=${QWEN_DEVICE_WINDOW_LAUNCH:-"$script_directory/qwen-lan-launch.sh"}

status_file=$qwen_home_state/session.status
window_status_file=$qwen_home_state/device-window.status
opened_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

session_recorded=0
if [ -f "$status_file" ] && grep -q '^state=running' "$status_file"; then
    session_recorded=1
fi
if [ "$session_recorded" -eq 0 ] && [ "$no_session" -eq 0 ]; then
    printf 'no running session is recorded at %s; pass --no-session to open a window with no relaunch\n' \
        "$status_file" >&2
    exit 1
fi

# Read the fields the relaunch needs off the running session's own
# `state=running` line, so the window reproduces the launch it stopped
# rather than a guess.
recorded_boundary=''
recorded_lan_address=''
recorded_port=''
recorded_profile=''
if [ "$session_recorded" -eq 1 ]; then
    state_line=$(sed -n '1p' "$status_file")
    field() {
        printf '%s\n' "$state_line" | tr ' ' '\n' | sed -n "s/^$1=//p" | head -n 1
    }
    recorded_boundary=$(field lan_boundary)
    recorded_lan_address=$(field lan_address)
    recorded_port=$(field port)
    recorded_profile=$(field profile)
fi

relaunch_boundary_note=''
if [ "$recorded_boundary" = lan-open-approved ]; then
    if [ -z "${QWEN_WEB_LAN_TRUSTED_CONNECTIONS:-}" ]; then
        relaunch_boundary=lan-authenticated
        relaunch_boundary_note='downgraded from lan-open-approved: QWEN_WEB_LAN_TRUSTED_CONNECTIONS is not recorded on the session status line and none is set in this window'\''s own environment'
    else
        relaunch_boundary=lan-open-approved
    fi
elif [ -n "$recorded_boundary" ]; then
    relaunch_boundary=$recorded_boundary
else
    relaunch_boundary=lan-authenticated
    relaunch_boundary_note='no running session was recorded; relaunching lan-authenticated by default'
fi
relaunch_profile=$recorded_profile
case $relaunch_profile in
    paced-60 | low-serialized | low-async) ;;
    *) relaunch_profile=low-async ;;
esac
relaunch_command="$launch_script $relaunch_boundary $relaunch_profile"
relaunch_health_host=$recorded_lan_address
case $relaunch_health_host in
    '' | -) relaunch_health_host=127.0.0.1 ;;
esac
relaunch_health_port=$recorded_port
case $relaunch_health_port in
    '' | *[!0-9]*) relaunch_health_port=42069 ;;
esac

results_directory=$qwen_home_results/device-windows/"$window_name"-"$opened_at"
mkdir -p "$results_directory"
window_ledger=$results_directory/window.tsv
printf 'field\tvalue\n' >"$window_ledger"
printf 'opened_at\t%s\n' "$opened_at" >>"$window_ledger"
printf 'relaunch_command\t%s\n' "$relaunch_command" >>"$window_ledger"
command_display=$command_program
for command_display_argument in "$@"; do
    command_display="$command_display $command_display_argument"
done
printf 'command\t%s\n' "$command_display" >>"$window_ledger"
if [ -n "$relaunch_boundary_note" ]; then
    printf '%s\n' "$relaunch_boundary_note" >&2
    printf 'relaunch_boundary_note\t%s\n' "$relaunch_boundary_note" >>"$window_ledger"
fi

printf 'device window %s opened at %s; relaunch %s\n' \
    "$window_name" "$opened_at" "$relaunch_command" >"$window_status_file"
printf 'relaunch_command=%s\n' "$relaunch_command" >>"$window_status_file"
printf 'window_ledger=%s\n' "$window_ledger" >>"$window_status_file"

# The supervisor keeps the maintenance exclusion through final verification.
# Children may start persistent services, so only the window-owned descriptor
# and its re-exec marker are removed at these boundaries. Workload lease and
# reporting descriptors retain their independent handoffs.
run_window_child() (
    exec 7>&-
    unset QWEN_DEVICE_WINDOW_LOCK_DESCRIPTOR_INHERITED
    trap - INT TERM
    exec "$@"
)

# Restoration children leave the caller's foreground process group, so a
# repeated terminal or group signal cannot interrupt their cleanup. Normal
# signal dispositions still reach the services they launch.
run_restoration_child() {
    run_window_child setsid --wait "$@"
}

relaunched=0
relaunch_status=0

# The relaunch runs exactly once, whatever brought the trap here, and its own
# outcome is what this script's exit status names past the command's own.
# Signal handlers exit through the same EXIT trap as a normal return. The
# supervisor ignores further cancellation during restoration and retains the
# lock until the relaunch and health verification finish.
relaunch_appliance() {
    if [ "$relaunched" -eq 1 ]; then
        return "$relaunch_status"
    fi
    relaunched=1
    if [ "$session_recorded" -eq 0 ] && [ "$no_session" -eq 1 ]; then
        printf 'relaunch_status\tskipped: window opened with --no-session against no running session\n' \
            >>"$window_ledger"
        relaunch_status=0
        return 0
    fi
    launch_ok=0
    if run_restoration_child "$launch_script" "$relaunch_boundary" "$relaunch_profile" \
        >>"$window_ledger.launch.log" 2>&1; then
        launch_ok=1
    fi
    running_ok=0
    health_ok=0
    if [ "$launch_ok" -eq 1 ]; then
        if [ -f "$status_file" ] && grep -q '^state=running' "$status_file"; then
            running_ok=1
            # The relaunched session's own status line is the health probe's
            # authority rather than the stopped session's recorded values,
            # since a DHCP lease can move the address between the two.
            new_state_line=$(sed -n '1p' "$status_file")
            new_field() {
                printf '%s\n' "$new_state_line" | tr ' ' '\n' |
                    sed -n "s/^$1=//p" | head -n 1
            }
            probe_host=$(new_field lan_address)
            case $probe_host in
                '' | -) probe_host=127.0.0.1 ;;
            esac
            probe_port=$(new_field port)
            case $probe_port in
                '' | *[!0-9]*) probe_port=$relaunch_health_port ;;
            esac
        else
            probe_host=$relaunch_health_host
            probe_port=$relaunch_health_port
        fi
        if [ -n "${QWEN_DEVICE_WINDOW_HEALTH_PROBE:-}" ]; then
            if run_restoration_child $QWEN_DEVICE_WINDOW_HEALTH_PROBE "$probe_host" "$probe_port"; then
                health_ok=1
            fi
        elif run_restoration_child curl --silent --fail \
            "http://$probe_host:$probe_port/health" >/dev/null 2>&1; then
            health_ok=1
        fi
    fi
    if [ "$launch_ok" -eq 1 ] && [ "$running_ok" -eq 1 ] && [ "$health_ok" -eq 1 ]; then
        printf 'relaunch_status\tok\n' >>"$window_ledger"
        relaunch_status=0
    else
        printf 'relaunch_status\tfailed launch_ok=%s running_ok=%s health_ok=%s\n' \
            "$launch_ok" "$running_ok" "$health_ok" >>"$window_ledger"
        relaunch_status=1
    fi
    return "$relaunch_status"
}

on_exit() {
    command_status=$?
    trap - EXIT
    trap '' INT TERM
    set +e
    relaunch_appliance
    relaunch_result=$?
    set -e
    printf 'command_exit_status\t%s\n' "$command_status" >>"$window_ledger"
    rm -f "$window_status_file"
    if [ "$relaunch_result" -ne 0 ]; then
        exit 4
    fi
    exit "$command_status"
}
trap on_exit EXIT
# Foreground children finish before the shell handles a pending signal. Keep
# the exclusion until their cleanup and the relaunch verification complete.
trap 'exit 130' INT
trap 'exit 143' TERM

if [ "$session_recorded" -eq 1 ]; then
    if ! run_window_child "$teardown_script"; then
        printf 'teardown did not exit 0; the window does not open over a session left running\n' >&2
        exit 1
    fi
fi

run_window_child "$command_program" "$@"
