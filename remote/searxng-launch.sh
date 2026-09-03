#!/bin/sh
set -eu

# Run one SearXNG instance as the serving user, inside the state directory a
# launch owns.
#
# The installed tree at /usr/local/searxng belongs to the searxng account:
# /etc/searxng/settings.yml is root-owned and unreadable here, and the engine
# caches the instance writes as /tmp/sxng_cache_*.db belong to that account
# too. Both are supplied from the state directory instead, so the serving user
# runs the same source tree under its own configuration and its own TMPDIR.
# remote/searxng-control.sh administers the service-account instance; this
# script owns one whose lifetime is a launch's. QWEN_SEARXNG_ROOT defaults to
# /opt/searxng-qwen-apu, the tree remote/install-searxng.sh names when the
# service account cannot traverse a caller's home directory.
#
# `serve` renders the settings and replaces itself with the instance, so the
# process the caller backgrounds is the instance itself and its PID stays the
# one the caller recorded. remote/qwen-webui-session.sh starts it that way
# under QWEN_WEB_SEARXNG=1 and holds it as a guarded child beside the approval
# broker. `start` performs the same launch for an operator, records the PID and
# its process start time, waits for GET /healthz, and prints the identity line;
# `stop` signals the process that line names and proves both the process and
# the listener gone.
#
# The rendered settings carry a fresh secret on every render, written through
# python3 at mode 0600, so the value reaches neither an argument vector nor a
# log line. The render also writes the port and bind address the profile
# ledger names over the template's own, so a profile choosing a loopback port
# other than the template's default still gets an instance listening where its
# searxng_url says. The rendered file stays the authority for the listener:
# the port and the bind address are read back from it and required to equal
# the loopback endpoint this launch serves, so a template missing either field
# refuses rather than putting the instance somewhere the profile ledger does
# not name.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s serve|start|stop|status [STATE_DIRECTORY]\n' "$0" >&2
    exit 2
fi
action=$1
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
state_directory=${2:-${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}}

instance_root=${QWEN_SEARXNG_ROOT:-/opt/searxng-qwen-apu}
source_directory=${QWEN_SEARXNG_SOURCE:-$instance_root/searxng-src}
instance_python=${QWEN_SEARXNG_PYTHON:-$instance_root/searx-pyenv/bin/python}
instance_module=${QWEN_SEARXNG_MODULE:-searx.webapp}
settings_template=${QWEN_SEARXNG_SETTINGS_TEMPLATE:-"$script_directory/searxng/settings.template.yml"}
expected_port=${QWEN_SEARXNG_PORT:-8888}
# The render substitutes this value into the rendered settings rather than
# only comparing against the template's own, so this launch's one loopback
# guarantee lives here instead: a caller naming anything but the loopback
# literal is refused before an instance ever binds it.
expected_bind_address=${QWEN_SEARXNG_BIND_ADDRESS:-127.0.0.1}
case $expected_bind_address in
    127.0.0.1) ;;
    *)
        printf 'QWEN_SEARXNG_BIND_ADDRESS must be 127.0.0.1: %s\n' \
            "$expected_bind_address" >&2
        exit 2
        ;;
esac
start_timeout_seconds=${QWEN_SEARXNG_START_TIMEOUT:-120}
case $start_timeout_seconds in
    '' | *[!0-9]*) start_timeout_seconds=120 ;;
esac
stop_timeout_seconds=${QWEN_SEARXNG_STOP_TIMEOUT:-15}
case $stop_timeout_seconds in
    '' | *[!0-9]*) stop_timeout_seconds=15 ;;
esac
# QWEN_SEARXNG_LAUNCH_COMMAND replaces the module invocation whole, which is
# what lets remote/test-web-search-live.sh drive this script against a fake
# listener on a host holding no SearXNG install.
launch_command=${QWEN_SEARXNG_LAUNCH_COMMAND:-"'$instance_python' -m $instance_module"}

instance_directory=$state_directory/searxng
settings_file=$instance_directory/settings.yml
temporary_directory=$instance_directory/tmp
log_file=$instance_directory/searxng.log
pid_file=$instance_directory/searxng.pid

process_start_time() {
    sed 's/^.*) //' "/proc/$1/stat" 2>/dev/null | awk '{ print $20 }'
}

# Field 3 of /proc/PID/stat, read back the same way qwen-webui-session.sh's
# process_running() does: a zombie keeps its /proc entry and its recorded start
# time past the process exiting, until whatever reaps it runs, so a liveness
# check that stops at readability and start time treats an unreaped zombie as
# running forever.
process_state() {
    sed 's/^.*) //' "/proc/$1/stat" 2>/dev/null | awk '{ print $1 }'
}

# The recorded pair binds a number to a process: a PID is reused once its
# process exits, and field 22 of /proc/PID/stat separates the two.
recorded_pid=''
recorded_start_time=''
read_process_record() {
    recorded_pid=''
    recorded_start_time=''
    [ -s "$pid_file" ] || return 1
    recorded_pid=$(sed -n '1p' "$pid_file")
    recorded_start_time=$(sed -n '2p' "$pid_file")
    case $recorded_pid in
        '' | *[!0-9]*) recorded_pid=''; return 1 ;;
    esac
    case $recorded_start_time in
        '' | *[!0-9]*) recorded_start_time=''; return 1 ;;
    esac
    return 0
}

recorded_process_lives() {
    read_process_record || return 1
    [ -r "/proc/$recorded_pid/stat" ] || return 1
    [ "$(process_start_time "$recorded_pid")" = "$recorded_start_time" ] || return 1
    case $(process_state "$recorded_pid") in
        Z | X) return 1 ;;
    esac
    return 0
}

# The bounded TERM-then-KILL sequence `stop` already applied is what a startup
# failure needs too: a child that ignores or is stuck handling SIGTERM would
# otherwise leave the caller inside an unbounded `wait`. recorded_process_lives
# reads the pid file both callers already wrote, so one deadline serves both.
terminate_recorded_process() {
    terminate_pid=$1
    kill -TERM "$terminate_pid" 2>/dev/null || true
    terminate_waited=0
    while [ "$terminate_waited" -lt "$stop_timeout_seconds" ] && \
        recorded_process_lives; do
        sleep 1
        terminate_waited=$((terminate_waited + 1))
    done
    if recorded_process_lives; then
        kill -KILL "$terminate_pid" 2>/dev/null || true
        sleep 1
    fi
}

listener_present() {
    command -v ss >/dev/null 2>&1 || return 1
    ss -ltn "sport = :$expected_port" 2>/dev/null |
        grep -q ":$expected_port"
}

health_answers() {
    curl -fsS --max-time 5 -o /dev/null \
        "http://$expected_bind_address:$expected_port/healthz" 2>/dev/null
}

# The rendered file rather than the template decides where the instance binds,
# because the template is what an operator edits and the launch chain is what
# the profile ledger's searxng_url has to meet.
settings_field() {
    awk -v block="$1" -v field="$2" '
        /^[^[:space:]#]/ { section = $1; next }
        section == block ":" && $1 == field ":" {
            value = $2
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "$settings_file"
}

render_settings() {
    mkdir -p "$instance_directory" "$temporary_directory"
    chmod 700 "$instance_directory" "$temporary_directory"
    if [ ! -r "$settings_template" ]; then
        printf 'the settings template is unreadable: %s\n' \
            "$settings_template" >&2
        exit 2
    fi
    if ! python3 - "$settings_template" "$settings_file" "$expected_port" \
        "$expected_bind_address" <<'PY'
import os
import re
import secrets
import sys

template_path, settings_path, port, bind_address = sys.argv[1:5]
with open(template_path, "r", encoding="utf-8") as handle:
    template = handle.read()
if "__SECRET__" not in template:
    sys.stderr.write("the settings template carries no __SECRET__ placeholder\n")
    raise SystemExit(2)
rendered = template.replace("__SECRET__", secrets.token_hex(32))
# A profile names its own loopback port in web-profiles.tsv, and the render is
# what makes that port the one the instance actually binds: the template's own
# port and bind_address lines are placeholders this launch overwrites rather
# than a value an operator edit is required to match.
rendered, port_subs = re.subn(
    r"(?m)^(  port: )[0-9]+$", r"\g<1>" + port, rendered, count=1
)
if port_subs != 1:
    sys.stderr.write("the settings template carries no server port line\n")
    raise SystemExit(2)
rendered, bind_subs = re.subn(
    r'(?m)^(  bind_address: )"[^"]*"$',
    r'\g<1>"' + bind_address + '"',
    rendered,
    count=1,
)
if bind_subs != 1:
    sys.stderr.write("the settings template carries no server bind_address line\n")
    raise SystemExit(2)
descriptor = os.open(settings_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
    handle.write(rendered)
PY
    then
        printf 'the settings render failed: %s\n' "$settings_file" >&2
        exit 1
    fi
    chmod 600 "$settings_file"
    rendered_port=$(settings_field server port)
    rendered_bind_address=$(settings_field server bind_address)
    if [ "$rendered_port" != "$expected_port" ]; then
        printf 'the rendered settings bind port %s where the launch serves %s\n' \
            "${rendered_port:-<absent>}" "$expected_port" >&2
        exit 2
    fi
    if [ "$rendered_bind_address" != "$expected_bind_address" ]; then
        printf 'the rendered settings bind %s where the launch serves %s\n' \
            "${rendered_bind_address:-<absent>}" "$expected_bind_address" >&2
        exit 2
    fi
}

case $action in
    serve)
        if [ -z "${QWEN_SEARXNG_LAUNCH_COMMAND:-}" ]; then
            if [ ! -d "$source_directory" ]; then
                printf 'the SearXNG source tree is absent: %s\n' \
                    "$source_directory" >&2
                exit 2
            fi
            if [ ! -x "$instance_python" ]; then
                printf 'the SearXNG interpreter is absent: %s\n' \
                    "$instance_python" >&2
                exit 2
            fi
            cd "$source_directory"
        fi
        render_settings
        # The instance replaces this shell, so the PID the caller recorded from
        # its own fork stays the instance's for the rest of its life.
        TMPDIR=$temporary_directory \
        SEARXNG_SETTINGS_PATH=$settings_file \
            exec sh -c "exec $launch_command"
        ;;

    start)
        if recorded_process_lives; then
            printf 'the instance already runs: pid=%s\n' "$recorded_pid" >&2
            exit 2
        fi
        if listener_present; then
            printf 'port %s already carries a listener this launch does not own\n' \
                "$expected_port" >&2
            exit 2
        fi
        mkdir -p "$instance_directory"
        chmod 700 "$instance_directory"
        rm -f -- "$pid_file"
        : >"$log_file"
        chmod 600 "$log_file"
        # The redirections are applied inside a child shell, because a
        # parent-side descriptor assignment on a background simple command
        # empties this shell's own /proc entry for the child's whole runtime.
        (
            exec >"$log_file" 2>&1 </dev/null
            exec "$0" serve "$state_directory"
        ) &
        instance_pid=$!
        instance_start_time=$(process_start_time "$instance_pid")
        case $instance_start_time in
            '' | *[!0-9]*)
                printf 'the instance left before its identity could be read\n' >&2
                exit 1
                ;;
        esac
        printf '%s\n%s\n' "$instance_pid" "$instance_start_time" >"$pid_file"
        chmod 600 "$pid_file"
        waited=0
        while [ "$waited" -lt "$start_timeout_seconds" ]; do
            if ! kill -0 "$instance_pid" 2>/dev/null; then
                break
            fi
            if health_answers; then
                printf 'searxng=listening pid=%s port=%s start_time=%s\n' \
                    "$instance_pid" "$expected_port" "$instance_start_time"
                exit 0
            fi
            sleep 1
            waited=$((waited + 1))
        done
        printf 'the instance answered no health request within %ss\n' \
            "$start_timeout_seconds" >&2
        tail -n 40 "$log_file" >&2 2>/dev/null || true
        # A child that ignores SIGTERM or is stuck handling it must not hang
        # this caller past the advertised timeout, so the escalation `stop`
        # applies runs here too rather than an unbounded wait.
        terminate_recorded_process "$instance_pid"
        wait "$instance_pid" 2>/dev/null || true
        rm -f -- "$pid_file"
        exit 1
        ;;

    stop)
        # The exit status reports the machine's state rather than the attempt,
        # the rule remote/qwen-teardown.sh applies: a surviving process or a
        # listener on the port fails this path.
        if ! read_process_record; then
            if listener_present; then
                printf 'no recorded instance, and port %s still carries a listener\n' \
                    "$expected_port" >&2
                exit 1
            fi
            rm -f -- "$pid_file"
            printf 'searxng=absent port=%s\n' "$expected_port"
            exit 0
        fi
        if recorded_process_lives; then
            terminate_recorded_process "$recorded_pid"
        fi
        residue=''
        if recorded_process_lives; then
            residue="$residue pid=$recorded_pid"
        fi
        if listener_present; then
            residue="$residue port=$expected_port"
        fi
        if [ -n "$residue" ]; then
            printf 'the instance survives the stop:%s\n' "$residue" >&2
            exit 1
        fi
        rm -f -- "$pid_file"
        printf 'searxng=stopped pid=%s port=%s\n' "$recorded_pid" "$expected_port"
        ;;

    status)
        # A recorded process that lives and answers is running; one that lives
        # but answers no health request is degraded rather than absent, since
        # an occupied port and a live process are not what `stopped` means to
        # a caller deciding whether `start` may claim this state directory.
        if recorded_process_lives; then
            if health_answers; then
                printf 'state=running pid=%s port=%s start_time=%s\n' \
                    "$recorded_pid" "$expected_port" "$recorded_start_time"
                exit 0
            fi
            printf 'state=unhealthy pid=%s port=%s start_time=%s\n' \
                "$recorded_pid" "$expected_port" "$recorded_start_time"
            exit 1
        fi
        printf 'state=stopped port=%s\n' "$expected_port"
        exit 1
        ;;

    *)
        printf 'usage: %s serve|start|stop|status [STATE_DIRECTORY]\n' "$0" >&2
        exit 2
        ;;
esac
