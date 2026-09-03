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
# The template carries the shipped default port, 8888, unmodified: the render
# writes the profile's own port over it, and the arms below measure that
# substitution rather than a template a test hand-patched to agree with it.
cp "$script_directory/searxng/settings.template.yml" \
    "$fixture_remote/searxng/settings.template.yml"
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

instance_log=$temporary_directory/instance-requests.log
launch_command_for() {
    printf "python3 '%s' --port %s --log '%s' %s" \
        "$fake_instance" "$1" "$instance_log" "${2:-}"
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
    # The template carries the shipped default port, 8888, unmodified; the
    # rendered file must carry this launch's own port instead, which is what
    # lets a profile choosing any loopback port other than the default still
    # get an instance listening where its searxng_url says.
    grep -q "^  port: $instance_port\$" "$settings_file" || outcome=port_unsubstituted
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

# 2. The render substitutes the port and bind address into the template
# rather than comparing the template's own values, so a template missing the
# field the substitution targets is what now refuses: the rendered file stays
# the authority, and a structurally short template is the shape that defeats
# it.
malformed_template=$temporary_directory/settings-template-no-port.yml
sed '/^  port: 8888$/d' "$script_directory/searxng/settings.template.yml" \
    >"$malformed_template"
mismatch_state=$temporary_directory/state-mismatch
mkdir -p "$mismatch_state"
if QWEN_SEARXNG_PORT=$mismatched_port \
    QWEN_SEARXNG_SETTINGS_TEMPLATE=$malformed_template \
    QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$mismatched_port")" \
    "$fixture_remote/searxng-launch.sh" serve "$mismatch_state" \
    >"$temporary_directory/mismatch.log" 2>&1; then
    report rendered_port_missing_refused accepted
elif grep -q 'the settings template carries no server port line' \
    "$temporary_directory/mismatch.log"; then
    report rendered_port_missing_refused ok
else
    report rendered_port_missing_refused missing_message
    cat "$temporary_directory/mismatch.log" >&2
fi

# 3. A recorded process that exits without being reaped keeps its /proc entry
# and its recorded start time, the state an orphan can persist in when nothing
# reaps it promptly, so a liveness check by readability and start time alone
# treats it as running forever and 'start' refuses to reclaim the state
# directory. test-fixtures/fabricate-zombie.py forks the zombie directly under
# a parent that holds off waitpid(2), rather than backgrounding a shell
# subshell: bash reaps an asynchronous child through its own SIGCHLD handler
# whether or not anything calls `wait`, so that trick never leaves a zombie
# to observe.
zombie_port=18891
zombie_state=$temporary_directory/state-zombie
mkdir -p "$zombie_state/searxng"
zombie_ready=$temporary_directory/zombie-ready
python3 "$script_directory/test-fixtures/fabricate-zombie.py" "$zombie_ready" 20 &
zombie_holder_pid=$!
zombie_ready_wait=0
while [ ! -s "$zombie_ready" ] && [ "$zombie_ready_wait" -lt 300 ]; do
    zombie_ready_wait=$((zombie_ready_wait + 1))
    sleep 0.01
done
zombie_pid=$(cat "$zombie_ready")
zombie_wait=0
zombie_child_state=''
while [ "$zombie_wait" -lt 300 ]; do
    zombie_child_state=$(sed 's/^.*) //' "/proc/$zombie_pid/stat" 2>/dev/null |
        awk '{ print $1 }')
    [ "$zombie_child_state" = Z ] && break
    zombie_wait=$((zombie_wait + 1))
    sleep 0.01
done
if [ "$zombie_child_state" = Z ]; then
    zombie_start_time=$(sed 's/^.*) //' "/proc/$zombie_pid/stat" 2>/dev/null |
        awk '{ print $20 }')
    printf '%s\n%s\n' "$zombie_pid" "$zombie_start_time" \
        >"$zombie_state/searxng/searxng.pid"
    chmod 600 "$zombie_state/searxng/searxng.pid"
    if QWEN_SEARXNG_PORT=$zombie_port \
        "$fixture_remote/searxng-launch.sh" status "$zombie_state" \
        >"$temporary_directory/zombie-status.log" 2>&1; then
        report zombie_record_reads_stopped unexpectedly_running
    elif grep -q '^state=stopped' "$temporary_directory/zombie-status.log"; then
        report zombie_record_reads_stopped ok
    else
        report zombie_record_reads_stopped "$(cat "$temporary_directory/zombie-status.log")"
    fi
    if QWEN_SEARXNG_PORT=$zombie_port \
        QWEN_SEARXNG_START_TIMEOUT=20 \
        QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$zombie_port")" \
        "$fixture_remote/searxng-launch.sh" start "$zombie_state" \
        >"$temporary_directory/zombie-start.log" 2>&1; then
        zombie_new_pid=$(sed -n 's/^searxng=listening pid=\([0-9]*\).*/\1/p' \
            "$temporary_directory/zombie-start.log")
        outcome=ok
        wait_for_health "$zombie_port" || outcome=health_absent
        report zombie_record_does_not_block_start "$outcome"
        if [ -n "$zombie_new_pid" ]; then
            QWEN_SEARXNG_PORT=$zombie_port \
                "$fixture_remote/searxng-launch.sh" stop "$zombie_state" \
                >/dev/null 2>&1 || true
        fi
    else
        report zombie_record_does_not_block_start \
            "$(cat "$temporary_directory/zombie-start.log")"
    fi
else
    report zombie_record_reads_stopped zombie_unavailable
    report zombie_record_does_not_block_start zombie_unavailable
fi
kill -KILL "$zombie_holder_pid" 2>/dev/null || true
wait "$zombie_holder_pid" 2>/dev/null || true

# 4. A recorded process that lives but answers no health request is degraded
# rather than absent: `status` distinguishes it from a stopped instance, so a
# caller does not read an occupied port and a live process as nothing there.
unhealthy_state=$temporary_directory/state-unhealthy
mkdir -p "$unhealthy_state/searxng"
# `serve` is driven directly rather than through `start`, because `start`'s own
# health-timeout path now terminates and cleans up the pid record it wrote: the
# recorded-but-unhealthy state this arm measures is what `status` meets while
# the instance is still inside that window, not after it has been reaped.
QWEN_SEARXNG_PORT=$mismatched_port \
    QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$mismatched_port" '--fail-health')" \
    "$fixture_remote/searxng-launch.sh" serve "$unhealthy_state" \
    >"$unhealthy_state/serve.log" 2>&1 &
unhealthy_pid=$!
unhealthy_wait=0
while [ "$unhealthy_wait" -lt 300 ] && port_free "$mismatched_port"; do
    unhealthy_wait=$((unhealthy_wait + 1))
    sleep 0.05
done
unhealthy_start_time=$(sed 's/^.*) //' "/proc/$unhealthy_pid/stat" 2>/dev/null |
    awk '{ print $20 }')
printf '%s\n%s\n' "$unhealthy_pid" "$unhealthy_start_time" \
    >"$unhealthy_state/searxng/searxng.pid"
chmod 600 "$unhealthy_state/searxng/searxng.pid"
if port_free "$mismatched_port"; then
    report unhealthy_instance_distinguished_from_stopped instance_never_bound
else
    if QWEN_SEARXNG_PORT=$mismatched_port \
        "$fixture_remote/searxng-launch.sh" status "$unhealthy_state" \
        >"$temporary_directory/unhealthy-status.log" 2>&1; then
        report unhealthy_instance_distinguished_from_stopped read_as_running
    elif grep -q "^state=unhealthy pid=$unhealthy_pid " \
        "$temporary_directory/unhealthy-status.log"; then
        report unhealthy_instance_distinguished_from_stopped ok
    else
        report unhealthy_instance_distinguished_from_stopped \
            "$(cat "$temporary_directory/unhealthy-status.log")"
    fi
fi
kill -KILL "$unhealthy_pid" 2>/dev/null || true
wait "$unhealthy_pid" 2>/dev/null || true
rm -f -- "$unhealthy_state/searxng/searxng.pid"

# 5. The startup-timeout failure path escalates to SIGKILL past its own bounded
# wait rather than calling `wait` on a child with no deadline: an instance
# that answers no health request and also ignores SIGTERM must not hang
# `start` past QWEN_SEARXNG_START_TIMEOUT plus the escalation window, which
# QWEN_SEARXNG_STOP_TIMEOUT bounds independently here so the arm finishes
# quickly.
unresponsive_timeout_port=18895
unresponsive_timeout_state=$temporary_directory/state-unresponsive-timeout
mkdir -p "$unresponsive_timeout_state"
unresponsive_wall_start=$(date +%s)
# A bare command substitution here would hang the whole gate on exactly the
# regression this arm exists to catch: a `start` that reverted to an
# unbounded `wait` never returns, so the substitution never completes either.
# The external `timeout` is what turns that regression into a bounded,
# reported failure instead.
unresponsive_output=$(QWEN_SEARXNG_PORT=$unresponsive_timeout_port \
    QWEN_SEARXNG_START_TIMEOUT=2 \
    QWEN_SEARXNG_STOP_TIMEOUT=2 \
    QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$unresponsive_timeout_port" '--fail-health --ignore-term')" \
    timeout 30 "$fixture_remote/searxng-launch.sh" start \
        "$unresponsive_timeout_state" 2>&1) &&
    unresponsive_status=0 || unresponsive_status=$?
unresponsive_wall_elapsed=$(( $(date +%s) - unresponsive_wall_start ))
outcome=ok
[ "$unresponsive_status" -ne 0 ] || outcome=unexpectedly_healthy
[ "$unresponsive_status" -ne 124 ] || outcome=timed_out
if [ "$unresponsive_status" -eq 124 ]; then
    # The 30-second guard fired instead of the escalation, so the instance is
    # still there; it is cleared directly so a later arm does not meet a busy
    # port left over from this one's own failure.
    pkill -KILL -f "fake-searxng-server.py --port $unresponsive_timeout_port" \
        2>/dev/null || true
fi
# The 2-second start timeout plus a 2-second stop timeout plus the KILL
# escalation's own 1-second settle bounds this comfortably under the
# 30-second external guard.
[ "$unresponsive_wall_elapsed" -lt 40 ] || outcome=exit_not_bounded
# The pid record is what recorded_process_lives reads, so its removal and the
# port's release together prove the escalation actually reached the process
# rather than merely returning.
[ -e "$unresponsive_timeout_state/searxng/searxng.pid" ] && outcome=pid_file_survives
port_free "$unresponsive_timeout_port" || outcome=instance_survives
if [ "$outcome" != ok ]; then
    printf 'searxng_start_timeout_bounds_unresponsive_instance elapsed=%ss\n' \
        "$unresponsive_wall_elapsed" >&2
    printf '%s\n' "$unresponsive_output" >&2
fi
report searxng_start_timeout_bounds_unresponsive_instance "$outcome"

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

# 6. The identity lands on the status file before the readiness loop's health
# check succeeds, so a teardown that arrives while the loop is still polling
# can identify and signal the child rather than finding only the generic
# state=starting line the earlier write left in place. The instance answers
# no health request for a few seconds by construction, so the window is wide
# enough to observe reliably.
early_port=18892
early_state=$temporary_directory/state-early-identity
mkdir -p "$early_state"
QWEN_TEST_SERVER_PID_MARKER=$early_state/server.marker \
    QWEN_VULKAN_LATENCY_PROBE=$fixture_remote/latency-probe.sh \
    QWEN_WEB_SEARXNG=1 \
    QWEN_SEARXNG_PORT=$early_port \
    QWEN_SEARXNG_START_TIMEOUT=20 \
    QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$early_port" '--delay-ready 3')" \
    "$fixture_remote/qwen-webui-session.sh" \
        "$temporary_directory/fake-server" \
        "$temporary_directory/fake-model" \
        "$temporary_directory/fake-static" 4096 4096 18081 \
        "$early_state" low-serialized \
    >"$early_state/session.stdout" 2>"$early_state/session.stderr" &
early_session_pid=$!
early_attempt=0
early_identity_seen=0
while [ "$early_attempt" -lt 200 ]; do
    if grep -q '^searxng_identity ' "$early_state/session.status" 2>/dev/null; then
        early_identity_seen=1
        break
    fi
    early_attempt=$((early_attempt + 1))
    sleep 0.02
done
outcome=ok
if [ "$early_identity_seen" -eq 1 ]; then
    early_pid=$(read_status_field "$early_state" searxng_pid)
    case $early_pid in
        '' | *[!0-9]*) outcome=pid_field_absent ;;
    esac
    # The instance is still inside its delay-ready window: health has not yet
    # succeeded, so the session must not yet have reached state=running. A
    # pass here means the identity really was recorded ahead of readiness
    # rather than the loop simply outrunning a too-short observation window.
    grep -q '^state=running ' "$early_state/session.status" 2>/dev/null &&
        outcome=recorded_too_late_to_matter
else
    outcome=identity_not_recorded_early
fi
report searxng_identity_recorded_before_health "$outcome"
early_attempt=0
while [ "$early_attempt" -lt 900 ] && \
      ! grep -q 'state=running ' "$early_state/session.status" 2>/dev/null; do
    early_attempt=$((early_attempt + 1))
    sleep 0.1
done
kill -TERM "$early_session_pid" 2>/dev/null || true
wait "$early_session_pid" 2>/dev/null || true

# 7. The readiness loop is bounded by elapsed wall-clock time rather than by
# attempt count: an instance whose connection is accepted and then stalls
# makes an attempt-counted loop burn its own --max-time on every iteration,
# multiplying a 3-second budget toward 15 seconds (3 attempts of a 5-second
# curl each) rather than holding it near 3. The stall exceeds the whole
# budget, so a bounded loop stops within it and an unbounded one runs several
# multiples past it.
stall_port=18894
stall_state=$temporary_directory/state-stall-health
mkdir -p "$stall_state"
stall_wall_start=$(date +%s)
set +e
QWEN_TEST_SERVER_PID_MARKER=$stall_state/server.marker \
    QWEN_VULKAN_LATENCY_PROBE=$fixture_remote/latency-probe.sh \
    QWEN_WEB_SEARXNG=1 \
    QWEN_SEARXNG_PORT=$stall_port \
    QWEN_SEARXNG_START_TIMEOUT=3 \
    QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$stall_port" '--stall-health 10')" \
    "$fixture_remote/qwen-webui-session.sh" \
        "$temporary_directory/fake-server" \
        "$temporary_directory/fake-model" \
        "$temporary_directory/fake-static" 4096 4096 18083 \
        "$stall_state" low-serialized \
    >"$stall_state/session.stdout" 2>"$stall_state/session.stderr"
stall_status=$?
set -e
stall_wall_elapsed=$(( $(date +%s) - stall_wall_start ))
outcome=ok
[ "$stall_status" -ne 0 ] || outcome=session_accepted
grep -q 'reason=searxng_not_answering' "$stall_state/session.status" ||
    outcome=reason_unrecorded
# A 3-second budget against a 10-second stall stays near 3 seconds when
# bounded; the pre-fix attempt count would carry it toward 3 attempts of a
# 5-second curl timeout each, past 10 seconds.
[ "$stall_wall_elapsed" -lt 10 ] || outcome=elapsed_not_bounded
if [ "$outcome" != ok ]; then
    printf 'searxng_readiness_bounded_by_elapsed_time elapsed=%ss\n' \
        "$stall_wall_elapsed" >&2
fi
report searxng_readiness_bounded_by_elapsed_time "$outcome"

# 8. The session holds the instance as a guarded child, records its pid on the
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

    # A python child of the session imports from the runtime tree, and the
    # bytecode an import writes there is a stray the manifest never names, so
    # check-runtime-tree.sh refuses the next launch over a tree the appliance
    # itself dirtied. The child reports the value it inherited.
    if grep -q '^environment pythondontwritebytecode=1$' "$instance_log"; then
        report session_child_suppresses_bytecode ok
    else
        report session_child_suppresses_bytecode \
            "$(grep '^environment ' "$instance_log" | tail -1)"
    fi

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

# 9. The session's own EXIT trap bounds how long it waits on a search
# instance that ignores SIGTERM, rather than holding cleanup open until
# something else reaps it: terminate_guarded_child escalates to SIGKILL past
# QWEN_SEARXNG_STOP_TIMEOUT, and the session signalled below still exits in
# bounded time even though the instance never leaves on its own. The
# production session invokes searxng-launch.sh serve directly, the same
# 'serve' path this arm drives, rather than through its own start/stop
# actions, so this is the path an unhealthy startup would actually hang on.
cleanup_port=18893
cleanup_state=$temporary_directory/state-cleanup-bound
mkdir -p "$cleanup_state"
QWEN_TEST_SERVER_PID_MARKER=$cleanup_state/server.marker \
    QWEN_VULKAN_LATENCY_PROBE=$fixture_remote/latency-probe.sh \
    QWEN_WEB_SEARXNG=1 \
    QWEN_SEARXNG_PORT=$cleanup_port \
    QWEN_SEARXNG_STOP_TIMEOUT=2 \
    QWEN_SEARXNG_LAUNCH_COMMAND="$(launch_command_for "$cleanup_port" '--ignore-term')" \
    "$fixture_remote/qwen-webui-session.sh" \
        "$temporary_directory/fake-server" \
        "$temporary_directory/fake-model" \
        "$temporary_directory/fake-static" 4096 4096 18082 \
        "$cleanup_state" low-serialized \
    >"$cleanup_state/session.stdout" 2>"$cleanup_state/session.stderr" &
cleanup_session_pid=$!
cleanup_attempt=0
while [ "$cleanup_attempt" -lt 900 ] && \
      ! grep -q 'state=running ' "$cleanup_state/session.status" 2>/dev/null; do
    cleanup_attempt=$((cleanup_attempt + 1))
    sleep 0.1
done
if ! grep -q 'state=running ' "$cleanup_state/session.status" 2>/dev/null; then
    report cleanup_bounds_unresponsive_searxng no_running_state
    cat "$cleanup_state/session.status" "$cleanup_state/session.stderr" >&2 2>/dev/null || true
    kill -KILL "$cleanup_session_pid" 2>/dev/null || true
    wait "$cleanup_session_pid" 2>/dev/null || true
else
    cleanup_searxng_pid=$(read_status_field "$cleanup_state" searxng_pid)
    kill -TERM "$cleanup_session_pid" 2>/dev/null || true
    cleanup_wait_start=$(date +%s)
    # A bare `wait` here would hang the whole gate on exactly the regression
    # this arm exists to catch: a session that reverted to an unbounded EXIT
    # trap never leaves, so a blocking wait on its pid never returns either.
    # Polling with a bound lets that regression fail this one arm instead.
    cleanup_poll=0
    while kill -0 "$cleanup_session_pid" 2>/dev/null && \
          [ "$cleanup_poll" -lt 300 ]; do
        cleanup_poll=$((cleanup_poll + 1))
        sleep 0.1
    done
    if kill -0 "$cleanup_session_pid" 2>/dev/null; then
        kill -KILL "$cleanup_session_pid" 2>/dev/null || true
    fi
    wait "$cleanup_session_pid" 2>/dev/null || true
    cleanup_wait_elapsed=$(( $(date +%s) - cleanup_wait_start ))
    outcome=ok
    # The 2-second stop timeout plus its own escalation bounds the wait far
    # below the 30-second poll; a regression to an unbounded wait hits that
    # poll bound, gets force-killed here, and still fails on elapsed time.
    [ "$cleanup_wait_elapsed" -lt 30 ] || outcome=exit_not_bounded
    kill -0 "$cleanup_searxng_pid" 2>/dev/null && outcome=instance_survives
    if [ "$outcome" != ok ]; then
        printf 'cleanup_bounds_unresponsive_searxng elapsed=%ss\n' \
            "$cleanup_wait_elapsed" >&2
    fi
    report cleanup_bounds_unresponsive_searxng "$outcome"
fi

# 10. An instance retaining SIGTERM is residue, and the teardown reports it
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

# 11. An instance that binds its port and answers no health request ends the
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

# 12. The default root is the installed tree, and an override reaches the
# child process that reads it: qwen-webui-session.sh execs searxng-launch.sh
# across the tmux boundary qwen-webui-control.sh owns, so a name absent from
# its forwarded list never reaches the instance regardless of what the
# operator exported.
default_root_state=$temporary_directory/state-default-root
mkdir -p "$default_root_state"
if env -u QWEN_SEARXNG_LAUNCH_COMMAND -u QWEN_SEARXNG_ROOT \
    -u QWEN_SEARXNG_SOURCE -u QWEN_SEARXNG_PYTHON \
    "$fixture_remote/searxng-launch.sh" serve "$default_root_state" \
    >"$temporary_directory/default-root.log" 2>&1; then
    report default_root_is_installed_tree unexpectedly_present
elif grep -q 'the SearXNG source tree is absent: /opt/searxng-qwen-apu/searxng-src' \
    "$temporary_directory/default-root.log"; then
    report default_root_is_installed_tree ok
else
    report default_root_is_installed_tree wrong_default
    cat "$temporary_directory/default-root.log" >&2
fi

forwarded_root_names=ok
for forwarded_name in QWEN_SEARXNG_ROOT QWEN_SEARXNG_SOURCE QWEN_SEARXNG_PYTHON; do
    grep -qF "$forwarded_name" "$script_directory/qwen-webui-control.sh" ||
        forwarded_root_names="missing_$forwarded_name"
done
report searxng_root_override_crosses_tmux_boundary "$forwarded_root_names"

if [ "$failures" -ne 0 ]; then
    printf 'test-web-search-live: %d check(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'test-web-search-live: all checks passed\n'
