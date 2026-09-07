#!/bin/sh
set -eu

# The device window couples a teardown, a caller's command, and a relaunch
# into one operation, so these checks substitute recorders for
# qwen-teardown.sh and qwen-lan-launch.sh and prove: a second concurrent
# window is refused, relaunch happens after a failing command, relaunch
# happens after the window receives TERM, a failed relaunch yields exit 4,
# and an absent running session is refused unless --no-session names it.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
failures=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = ok ] || failures=$((failures + 1))
}

harness=$work/harness
mkdir -p "$harness"
cp "$script_directory/run-device-window.sh" "$harness/run-device-window.sh"
cp "$script_directory/qwen-home.sh" "$harness/qwen-home.sh"
cp "$script_directory/open-verified-lock-descriptor.py" \
    "$harness/open-verified-lock-descriptor.py"
chmod 755 "$harness/run-device-window.sh" "$harness/open-verified-lock-descriptor.py"

home=$work/runtime
launch_record=$work/launch.record
teardown_record=$work/teardown.record

write_teardown() {
    cat >"$harness/fake-teardown.sh" <<EOF
#!/bin/sh
set -eu
printf 'teardown\n' >>'$teardown_record'
rm -f '$home/state/session.status'
exit \${QWEN_TEST_TEARDOWN_STATUS:-0}
EOF
    chmod 755 "$harness/fake-teardown.sh"
}

write_launch() {
    cat >"$harness/fake-launch.sh" <<EOF
#!/bin/sh
set -eu
{
    printf 'boundary=%s profile=%s\n' "\${1:-}" "\${2:-}"
} >>'$launch_record'
mkdir -p '$home/state'
if [ "\${QWEN_TEST_LAUNCH_STATUS:-0}" = 0 ]; then
    printf 'state=running server_pid=1 lan_exposure=1 lan_address=127.0.0.1 lan_open=0 lan_boundary=%s profile=%s host=127.0.0.1 port=%s\n' \
        "\${1:-}" "\${2:-}" "\${QWEN_TEST_RELAUNCH_PORT:-9200}" \
        >'$home/state/session.status'
fi
exit "\${QWEN_TEST_LAUNCH_STATUS:-0}"
EOF
    chmod 755 "$harness/fake-launch.sh"
}

write_health_probe() {
    cat >"$harness/fake-health-probe.sh" <<EOF
#!/bin/sh
exit \${QWEN_TEST_HEALTH_STATUS:-0}
EOF
    chmod 755 "$harness/fake-health-probe.sh"
}

seed_running_session() {
    mkdir -p "$home/state"
    printf 'state=running server_pid=1 lan_exposure=0 lan_address=- lan_open=0 lan_boundary=lan-authenticated profile=low-async host=127.0.0.1 port=9100 context=4096 latency_mode=chat utc=2026-01-01T00:00:00Z\n' \
        >"$home/state/session.status"
}

run_window() {
    QWEN_HOME=$home \
    QWEN_DEVICE_WINDOW_TEARDOWN=$harness/fake-teardown.sh \
    QWEN_DEVICE_WINDOW_LAUNCH=$harness/fake-launch.sh \
    QWEN_DEVICE_WINDOW_HEALTH_PROBE=$harness/fake-health-probe.sh \
        "$harness/run-device-window.sh" "$@"
}

reset_state() {
    rm -rf "$home"
    rm -f "$launch_record" "$teardown_record"
    write_teardown
    write_launch
    write_health_probe
    seed_running_session
}

# A window that opens and exits normally tears down, runs the command, and
# relaunches once, recording the ledger.
reset_state
if run_window probe-normal sh -c 'exit 0' >"$work/normal.out" 2>"$work/normal.err"; then
    report normal_exit ok
else
    report normal_exit fail
    cat "$work/normal.err" >&2
fi
ledger=$(find "$home/results/device-windows" -maxdepth 1 -name 'probe-normal-*' -print | head -n 1)
if [ -n "$ledger" ] && [ -f "$teardown_record" ] &&
    grep -q '^relaunch_status	ok$' "$ledger/window.tsv" &&
    grep -q '^command_exit_status	0$' "$ledger/window.tsv"; then
    report normal_relaunch_and_ledger ok
else
    report normal_relaunch_and_ledger fail
    [ -n "$ledger" ] && cat "$ledger/window.tsv" >&2
fi

# A second concurrent window is refused rather than queued, while the first
# window's own flock is still held open on descriptor 7.
reset_state
QWEN_HOME=$home \
QWEN_DEVICE_WINDOW_TEARDOWN=$harness/fake-teardown.sh \
QWEN_DEVICE_WINDOW_LAUNCH=$harness/fake-launch.sh \
QWEN_DEVICE_WINDOW_HEALTH_PROBE=$harness/fake-health-probe.sh \
    "$harness/run-device-window.sh" probe-hold sh -c \
    "mkdir -p '$home/state'; : >'$work/first-window-open'; sleep 5" &
first_window_pid=$!
holder_started=0
attempts=0
while [ "$attempts" -lt 50 ]; do
    [ -f "$work/first-window-open" ] && { holder_started=1; break; }
    attempts=$((attempts + 1))
    sleep 0.1
done
if [ "$holder_started" -eq 1 ]; then
    if run_window probe-second sh -c 'exit 0' >"$work/second.out" 2>"$work/second.err"; then
        report second_window_refused fail
    else
        grep -q 'a device window is already open' "$work/second.err" &&
            report second_window_refused ok || report second_window_refused fail
    fi
else
    report second_window_refused fail
fi
kill "$first_window_pid" 2>/dev/null || :
wait "$first_window_pid" 2>/dev/null || :

# A failing command still relaunches, and the window's own exit status
# reports the command's failure rather than the relaunch's success.
reset_state
if run_window probe-fail sh -c 'exit 7' >"$work/fail.out" 2>"$work/fail.err"; then
    report failing_command_status fail
else
    [ "$?" -eq 7 ] && report failing_command_status ok || report failing_command_status fail
fi
fail_ledger=$(find "$home/results/device-windows" -maxdepth 1 -name 'probe-fail-*' -print | head -n 1)
if grep -q '^relaunch_status	ok$' "$fail_ledger/window.tsv" &&
    grep -q '^command_exit_status	7$' "$fail_ledger/window.tsv"; then
    report relaunch_after_failing_command ok
else
    report relaunch_after_failing_command fail
    cat "$fail_ledger/window.tsv" >&2
fi

# A window that receives TERM still relaunches through the trap. The
# backgrounded window is started directly by this shell, not inside a
# further subshell, so its PID stays a real job this shell can wait on.
reset_state
QWEN_HOME=$home \
QWEN_DEVICE_WINDOW_TEARDOWN=$harness/fake-teardown.sh \
QWEN_DEVICE_WINDOW_LAUNCH=$harness/fake-launch.sh \
QWEN_DEVICE_WINDOW_HEALTH_PROBE=$harness/fake-health-probe.sh \
    "$harness/run-device-window.sh" probe-term sh -c \
    ": >'$work/term-window-open'; sleep 30" &
term_window_pid=$!
term_started=0
attempts=0
while [ "$attempts" -lt 50 ]; do
    [ -f "$work/term-window-open" ] && { term_started=1; break; }
    attempts=$((attempts + 1))
    sleep 0.1
done
if [ "$term_started" -eq 1 ]; then
    kill -TERM "$term_window_pid"
    wait "$term_window_pid" 2>/dev/null || :
    term_ledger=$(find "$home/results/device-windows" -maxdepth 1 -name 'probe-term-*' -print | head -n 1)
    if [ -n "$term_ledger" ] && grep -q '^relaunch_status	ok$' "$term_ledger/window.tsv"; then
        report relaunch_after_term ok
    else
        report relaunch_after_term fail
        [ -n "$term_ledger" ] && cat "$term_ledger/window.tsv" >&2
    fi
else
    report relaunch_after_term fail
fi

# A relaunch the launch script or the health probe refuses yields exit 4.
reset_state
if QWEN_TEST_LAUNCH_STATUS=0 QWEN_TEST_HEALTH_STATUS=1 \
    run_window probe-relaunch-fail sh -c 'exit 0' \
    >"$work/relaunch-fail.out" 2>"$work/relaunch-fail.err"; then
    report relaunch_failure_status fail
else
    [ "$?" -eq 4 ] && report relaunch_failure_status ok || report relaunch_failure_status fail
fi

# An absent running session refuses without --no-session, and proceeds with
# it, skipping teardown and relaunch alike.
rm -rf "$home"
rm -f "$launch_record" "$teardown_record"
mkdir -p "$home/state"
if run_window probe-no-session sh -c 'exit 0' >"$work/nosession.out" 2>"$work/nosession.err"; then
    report absent_session_refused fail
else
    grep -q 'no running session is recorded' "$work/nosession.err" &&
        report absent_session_refused ok || report absent_session_refused fail
fi
if run_window --no-session probe-no-session-ok sh -c 'exit 0' \
    >"$work/nosession-ok.out" 2>"$work/nosession-ok.err"; then
    report no_session_flag_admits ok
else
    report no_session_flag_admits fail
    cat "$work/nosession-ok.err" >&2
fi
if [ -f "$teardown_record" ]; then
    report no_session_flag_skips_teardown fail
else
    report no_session_flag_skips_teardown ok
fi
no_session_ledger=$(find "$home/results/device-windows" -maxdepth 1 \
    -name 'probe-no-session-ok-*' -print | head -n 1)
if grep -q 'skipped: window opened with --no-session' "$no_session_ledger/window.tsv"; then
    report no_session_flag_skips_relaunch ok
else
    report no_session_flag_skips_relaunch fail
    cat "$no_session_ledger/window.tsv" >&2
fi

# The lan-open-approved boundary downgrades to lan-authenticated where
# QWEN_WEB_LAN_TRUSTED_CONNECTIONS is absent from the window's environment.
reset_state
mkdir -p "$home/state"
printf 'state=running server_pid=1 lan_exposure=1 lan_address=10.0.0.7 lan_open=1 lan_boundary=lan-open-approved profile=paced-60 host=10.0.0.7 port=9100 context=4096 latency_mode=chat utc=2026-01-01T00:00:00Z\n' \
    >"$home/state/session.status"
if run_window probe-boundary sh -c 'exit 0' >"$work/boundary.out" 2>"$work/boundary.err"; then
    report boundary_downgrade_exit ok
else
    report boundary_downgrade_exit fail
fi
if grep -q '^boundary=lan-authenticated profile=paced-60$' "$launch_record"; then
    report boundary_downgraded ok
else
    report boundary_downgraded fail
    cat "$launch_record" >&2
fi

status_output=$(QWEN_HOME=$work/no-window "$harness/run-device-window.sh" status)
if [ "$status_output" = 'no device window is open' ]; then
    report status_when_closed ok
else
    report status_when_closed fail
fi

if [ "$failures" -eq 0 ]; then
    printf 'test-run-device-window: ok\n'
else
    printf 'test-run-device-window: %s failures\n' "$failures" >&2
    exit 1
fi
