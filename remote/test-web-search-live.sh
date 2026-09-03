#!/bin/sh
set -eu

# The SearXNG lane of the launch chain, driven on a host holding no SearXNG
# install and no device. remote/test-fixtures/fake-searxng-server.py answers
# the two routes the chain reads, remote/searxng-launch.sh runs it through
# QWEN_SEARXNG_LAUNCH_COMMAND, and every other collaborator the session reaches
# is the fixture set remote/test-qwen-session-signals.sh already applies.
#
# The arms cover what a live run cannot repeat on demand: the standalone start
# and stop path, a rendered settings file whose port the launch refuses, the
# session recording its guarded child, a teardown proving the instance gone, a
# teardown meeting a survivor, and an instance that binds its port and answers
# no health request, which ends the launch before the capacity server starts.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
fixture_remote=$temporary_directory/remote
session_pid=''
instance_pid=''
failures=0

cleanup_fixture() {
    if [ -n "$session_pid" ]; then
        kill -TERM "$session_pid" 2>/dev/null || true
        wait "$session_pid" 2>/dev/null || true
    fi
    if [ -n "$instance_pid" ]; then
        kill -KILL "$instance_pid" 2>/dev/null || true
    fi
    rm -rf "$temporary_directory"
}
trap cleanup_fixture EXIT HUP INT TERM

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = ok ] || failures=$((failures + 1))
}

# Two ports carry the arms: one for the instance a session or a standalone
# start owns, and one for the arm that proves a rendered port the launch
# refuses.
instance_port=18888
mismatched_port=18890
fake_instance=$script_directory/test-fixtures/fake-searxng-server.py

mkdir -p "$fixture_remote/searxng"
cp "$script_directory/qwen-webui-session.sh" \
    "$script_directory/preserve-legacy-telemetry.sh" \
    "$script_directory/searxng-launch.sh" \
    "$script_directory/qwen-teardown.sh" \
    "$script_directory/image-teardown-check.sh" \
    "$fixture_remote/"
# The rendered port is read back from the settings and required to equal the
# port the launch serves, so the fixture template carries the harness port and
# the arms measure that comparison rather than working around it.
sed "s/^  port: 8888$/  port: $instance_port/" \
    "$script_directory/searxng/settings.template.yml" \
    >"$fixture_remote/searxng/settings.template.yml"
cat >"$fixture_remote/monitor-qwen-runtime.sh" <<'MONITOR'
#!/bin/sh
trap 'exit 0' HUP INT TERM
while :; do
    sleep 1
done
MONITOR
cat >"$fixture_remote/watch-qwen-kernel-hazards.sh" <<'HAZARD'
#!/bin/sh
printf 'watch_ready_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$2"
trap 'exit 0' HUP INT TERM
while kill -0 "$1" 2>/dev/null; do
    sleep 0.1
done
printf 'watch_stop_utc=%s reason=server_exited\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$2"
HAZARD
# The session admits the server only once its affinity equals
# QWEN_INFERENCE_CPU, its nice value reads 19, and the readiness marker reaches
# the log, so the fixture applies each of the three to itself. Its PID marker
# is what tells an arm whether the capacity server ran at all.
cat >"$fixture_remote/run-qwen-capacity-server.sh" <<'READY'
#!/bin/sh
renice -n 19 -p $$ >/dev/null 2>&1
taskset -cp "${QWEN_INFERENCE_CPU:-0}" $$ >/dev/null 2>&1
printf '%s\n' "$$" >"$QWEN_TEST_SERVER_PID_MARKER"
printf 'model loaded\n'
trap 'exit 0' HUP INT TERM
while :; do
    sleep 1
done
READY
cat >"$fixture_remote/latency-probe.sh" <<'PROBE'
#!/bin/sh
probe_log=''
while [ "$#" -gt 0 ]; do
    case $1 in
        --log)
            probe_log=$2
            shift
            ;;
    esac
    shift
done
printf 'probe_start ok\n' >"$probe_log"
trap 'exit 0' HUP INT TERM
while :; do
    sleep 1
done
PROBE
# The teardown reads its control script and its image residue proof from its
# own directory, so the fixture control leaves any tmux session on this machine
# alone while the residue proof still runs.
cat >"$fixture_remote/qwen-webui-control.sh" <<'CONTROL'
#!/bin/sh
set -eu
printf 'stopped tmux_socket=fixture tmux_session=fixture\n'
CONTROL
chmod +x "$fixture_remote"/*.sh

launch_command_for() {
    printf "python3 '%s' --port %s %s" "$fake_instance" "$1" "${2:-}"
}

wait_for_health() {
    health_port=$1
    health_attempt=0
    while [ "$health_attempt" -lt 300 ]; do
        if curl -sS --max-time 2 -o /dev/null \
            "http://127.0.0.1:$health_port/healthz" 2>/dev/null; then
            return 0
        fi
        health_attempt=$((health_attempt + 1))
        sleep 0.1
    done
    return 1
}

port_free() {
    ! ss -ltn "sport = :$1" 2>/dev/null | grep -q ":$1"
}

# 1. The standalone path: one render, one listener, one identity line, and a
# stop that proves both the process and the port gone.
standalone_state=$temporary_directory/state-standalone
mkdir -p "$standalone_state"
start_output=$(QWEN_SEARXNG_PORT=$instance_port \
    QWEN_SEARXNG_START_TIMEOUT=20 \
    QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$instance_port")" \
    "$fixture_remote/searxng-launch.sh" start "$standalone_state" 2>&1) &&
    start_status=0 || start_status=$?
if [ "$start_status" -ne 0 ]; then
    report standalone_start refused
    printf '%s\n' "$start_output" >&2
else
    outcome=ok
    case $start_output in
        "searxng=listening pid="[0-9]*" port=$instance_port start_time="[0-9]*) ;;
        *) outcome=identity_line ;;
    esac
    instance_pid=$(printf '%s\n' "$start_output" | sed -n 's/.*pid=\([0-9]*\) .*/\1/p')
    settings_file=$standalone_state/searxng/settings.yml
    [ -s "$settings_file" ] || outcome=settings_absent
    [ "$(stat -c %a "$settings_file")" = 600 ] || outcome=settings_mode
    grep -q '__SECRET__' "$settings_file" && outcome=secret_unrendered
    grep -q 'secret_key: "[0-9a-f]\{64\}"' "$settings_file" || outcome=secret_shape
    wait_for_health "$instance_port" || outcome=health_absent
    report standalone_start "$outcome"

    if QWEN_SEARXNG_PORT=$instance_port \
        "$fixture_remote/searxng-launch.sh" status "$standalone_state" \
        >"$temporary_directory/standalone-status.log" 2>&1 &&
       grep -q "^state=running pid=$instance_pid port=$instance_port" \
        "$temporary_directory/standalone-status.log"; then
        report standalone_status ok
    else
        report standalone_status "$(cat "$temporary_directory/standalone-status.log")"
    fi

    if QWEN_SEARXNG_PORT=$instance_port \
        "$fixture_remote/searxng-launch.sh" stop "$standalone_state" \
        >"$temporary_directory/standalone-stop.log" 2>&1; then
        outcome=ok
        kill -0 "$instance_pid" 2>/dev/null && outcome=process_survives
        port_free "$instance_port" || outcome=listener_survives
        [ -e "$standalone_state/searxng/searxng.pid" ] && outcome=record_survives
        report standalone_stop "$outcome"
    else
        report standalone_stop "$(cat "$temporary_directory/standalone-stop.log")"
    fi
    instance_pid=''
fi

# 2. The rendered file rather than the template decides the listener, so a port
# the launch does not serve refuses ahead of the instance.
mismatch_state=$temporary_directory/state-mismatch
mkdir -p "$mismatch_state"
if QWEN_SEARXNG_PORT=$mismatched_port \
    QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$mismatched_port")" \
    "$fixture_remote/searxng-launch.sh" serve "$mismatch_state" \
    >"$temporary_directory/mismatch.log" 2>&1; then
    report rendered_port_mismatch_refused accepted
elif grep -q "bind port $instance_port where the launch serves $mismatched_port" \
    "$temporary_directory/mismatch.log"; then
    report rendered_port_mismatch_refused ok
else
    report rendered_port_mismatch_refused missing_message
    cat "$temporary_directory/mismatch.log" >&2
fi

start_session() {
    session_state=$1
    session_health=${2:-}
    mkdir -p "$session_state"
    QWEN_TEST_SERVER_PID_MARKER=$session_state/server.marker \
        QWEN_VULKAN_LATENCY_PROBE=$fixture_remote/latency-probe.sh \
        QWEN_WEB_SEARXNG=1 \
        QWEN_SEARXNG_PORT=$instance_port \
        QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$instance_port" "$session_health")" \
        "$fixture_remote/qwen-webui-session.sh" \
            "$temporary_directory/fake-server" \
            "$temporary_directory/fake-model" \
            "$temporary_directory/fake-static" 4096 4096 18080 \
            "$session_state" low-serialized \
      >"$session_state/session.stdout" 2>"$session_state/session.stderr" &
    session_pid=$!
}

read_status_field() {
    sed -n '1p' "$1/session.status" | tr ' ' '\n' | sed -n "s/^$2=//p"
}

# 3. The session holds the instance as a guarded child, records its pid on the
# running line, and states its identity on a line of its own.
running_state=$temporary_directory/state-running
start_session "$running_state"
attempt=0
while [ "$attempt" -lt 900 ] && \
      ! grep -q 'state=running ' "$running_state/session.status" 2>/dev/null; do
    attempt=$((attempt + 1))
    sleep 0.1
done
if ! grep -q 'state=running ' "$running_state/session.status" 2>/dev/null; then
    report session_records_searxng_child no_running_state
    cat "$running_state/session.status" "$running_state/session.stderr" >&2 2>/dev/null || true
    kill -TERM "$session_pid" 2>/dev/null || true
    wait "$session_pid" 2>/dev/null || true
    session_pid=''
else
    session_searxng_pid=$(read_status_field "$running_state" searxng_pid)
    outcome=ok
    case $session_searxng_pid in
        '' | *[!0-9]*) outcome=pid_unrecorded ;;
    esac
    session_identity=$(sed -n 's/^searxng_identity //p' "$running_state/session.status")
    case $session_identity in
        "pid=$session_searxng_pid start_time="[0-9]*" port=$instance_port url=http://127.0.0.1:$instance_port") ;;
        *) outcome=identity_line ;;
    esac
    wait_for_health "$instance_port" || outcome=health_absent
    [ -s "$running_state/searxng/settings.yml" ] || outcome=settings_absent
    report session_records_searxng_child "$outcome"

    # 4. The teardown reads the pid and the port off the status file, compares
    # the recorded start time, signals the process, and proves both gone.
    # The teardown's exit status also reports every other component of the
    # machine it runs on, so this arm reads the search instance's own facts:
    # the recorded process gone, the port free, and the log naming what it
    # stopped.
    QWEN_WEBUI_STATE_DIRECTORY=$running_state QWEN_SERVER_PORT=18080 \
        "$fixture_remote/qwen-teardown.sh" \
        >"$temporary_directory/teardown.log" 2>&1 || true
    outcome=ok
    kill -0 "$session_searxng_pid" 2>/dev/null && outcome=process_survives
    port_free "$instance_port" || outcome=listener_survives
    grep -q 'search instance' "$temporary_directory/teardown.log" ||
        outcome=teardown_silent
    report teardown_proves_searxng_absent "$outcome"
    wait "$session_pid" 2>/dev/null || true
    session_pid=''
fi

# 5. An instance retaining SIGTERM is residue, and the teardown reports it
# rather than reporting a stop it could not prove.
survivor_state=$temporary_directory/state-survivor
mkdir -p "$survivor_state"
python3 "$fake_instance" --port "$instance_port" --ignore-term \
    >"$survivor_state/instance.log" 2>&1 &
instance_pid=$!
wait_for_health "$instance_port" || true
survivor_start_time=$(sed 's/^.*) //' "/proc/$instance_pid/stat" | awk '{ print $20 }')
# The fabricated status line names the search instance alone, so the teardown's
# guard loop signals nothing this harness did not start.
{
    printf 'state=running searxng_pid=%s profile=low-serialized host=127.0.0.1 port=18080 context=4096 latency_mode=observe utc=%s\n' \
        "$instance_pid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'searxng_identity pid=%s start_time=%s port=%s url=http://127.0.0.1:%s\n' \
        "$instance_pid" "$survivor_start_time" "$instance_port" "$instance_port"
} >"$survivor_state/session.status"
if QWEN_WEBUI_STATE_DIRECTORY=$survivor_state QWEN_SERVER_PORT=18080 \
    "$fixture_remote/qwen-teardown.sh" \
    >"$temporary_directory/survivor-teardown.log" 2>&1; then
    report teardown_reports_surviving_instance accepted
elif grep -q 'search instance still running' \
        "$temporary_directory/survivor-teardown.log" ||
     grep -q "search instance port $instance_port still has a listener" \
        "$temporary_directory/survivor-teardown.log"; then
    report teardown_reports_surviving_instance ok
else
    report teardown_reports_surviving_instance missing_message
    cat "$temporary_directory/survivor-teardown.log" >&2
fi
kill -KILL "$instance_pid" 2>/dev/null || true
wait "$instance_pid" 2>/dev/null || true
instance_pid=''
attempt=0
while [ "$attempt" -lt 100 ] && ! port_free "$instance_port"; do
    attempt=$((attempt + 1))
    sleep 0.1
done

# 6. An instance that binds its port and answers no health request ends the
# launch where the reason is still readable, and the capacity server never
# runs: its PID marker is what proves no model load began.
dead_state=$temporary_directory/state-dead
mkdir -p "$dead_state"
set +e
QWEN_TEST_SERVER_PID_MARKER=$dead_state/server.marker \
    QWEN_VULKAN_LATENCY_PROBE=$fixture_remote/latency-probe.sh \
    QWEN_WEB_SEARXNG=1 \
    QWEN_SEARXNG_PORT=$instance_port \
    QWEN_SEARXNG_START_TIMEOUT=5 \
    QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$instance_port" '--fail-health')" \
    "$fixture_remote/qwen-webui-session.sh" \
        "$temporary_directory/fake-server" \
        "$temporary_directory/fake-model" \
        "$temporary_directory/fake-static" 4096 4096 18080 \
        "$dead_state" low-serialized \
    >"$dead_state/session.stdout" 2>"$dead_state/session.stderr"
dead_status=$?
set -e
outcome=ok
[ "$dead_status" -ne 0 ] || outcome=session_accepted
grep -q "reason=searxng_not_answering port=$instance_port" \
    "$dead_state/session.status" || outcome=reason_unrecorded
[ -e "$dead_state/server.marker" ] && outcome=capacity_server_started
report dead_instance_stops_launch_before_the_model "$outcome"

if [ "$failures" -ne 0 ]; then
    printf 'test-web-search-live: %d check(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'test-web-search-live: all checks passed\n'
