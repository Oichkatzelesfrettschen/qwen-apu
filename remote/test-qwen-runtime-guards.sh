#!/bin/sh
set -eu

# The runtime monitor and the kernel-hazard watcher, driven against fixture
# processes and a fake amdgpu device directory.
#
# Every arm waits on the event it tests rather than on a clock. The fixture
# server lives until this script ends it, so the monitor's own observation of a
# departed server is caused by this script rather than by a `sleep 5` that a
# loaded workstation can spend before the monitor's startup preflight reaches
# its first sample; that fixed duration is what made a failing arm pass on
# rerun, since monitor-qwen-runtime.sh exits 2 with "server PID is not running"
# when the fixture is already gone at startup.
#
# Two deadlines bound each arm and the failure names which one expired.
# QWEN_GUARD_FIXTURE_DEADLINE_S bounds the fixture and the guard reaching their
# ready state, which is the harness's own setup and carries no claim about the
# appliance. QWEN_GUARD_OBSERVATION_DEADLINE_S bounds the interval from the
# condition arriving to the guard acting on it, which is the guard property
# under test; the guards' own limits -- the one-second sample period and the
# two-second SIGKILL grace -- stay exactly what monitor-qwen-runtime.sh sets.
# A failure retains the arm's log directory and prints the load average, the
# expired deadline, and the elapsed time.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
fake_gpu_directory=$temporary_directory/fake-gpu
export QWEN_GUARD_CPU_ACTIVE=1
# A quality-gate parent can run under SCHED_IDLE at nice 19 while the safety
# guards must remain responsive under SCHED_OTHER at nice 0. An optional test
# runner performs that privileged scheduler transition without weakening the
# guards' readback assertions; its target fixture nice travels in the
# QWEN_GUARD_RUNNER_TARGET_NICE environment variable.
guard_test_runner=${QWEN_GUARD_TEST_RUNNER:-}
fixture_deadline_seconds=${QWEN_GUARD_FIXTURE_DEADLINE_S:-60}
observation_deadline_seconds=${QWEN_GUARD_OBSERVATION_DEADLINE_S:-30}
test_pid=""
watchdog_pid=""
kernel_watchdog_pid=""
guard_pid=""
current_arm=initialization
retain_logs=0

if [ -n "$guard_test_runner" ] && [ ! -x "$guard_test_runner" ]; then
    printf 'guard test runner is not executable: %s\n' \
        "$guard_test_runner" >&2
    exit 2
fi

run_guard_test() {
    if [ -n "$guard_test_runner" ]; then
        "$guard_test_runner" "$@"
        return
    fi
    "$@"
}

launch_guard_fixture() {
    fixture_nice_value=$1
    shift
    if [ -n "$guard_test_runner" ]; then
        QWEN_GUARD_RUNNER_TARGET_NICE=$fixture_nice_value \
            "$guard_test_runner" "$@" &
    else
        "$@" &
    fi
    launched_fixture_pid=$!
    if [ -z "$guard_test_runner" ]; then
        renice -n "$fixture_nice_value" -p "$launched_fixture_pid" \
            >/dev/null
    fi
}

cleanup() {
    cleanup_status=$?
    if [ -n "$guard_pid" ]; then
        kill "$guard_pid" 2>/dev/null || true
        wait "$guard_pid" 2>/dev/null || true
    fi
    if [ -n "$test_pid" ]; then
        kill "$test_pid" 2>/dev/null || true
        wait "$test_pid" 2>/dev/null || true
    fi
    if [ -n "$watchdog_pid" ]; then
        kill "$watchdog_pid" 2>/dev/null || true
        wait "$watchdog_pid" 2>/dev/null || true
    fi
    if [ -n "$kernel_watchdog_pid" ]; then
        kill "$kernel_watchdog_pid" 2>/dev/null || true
        wait "$kernel_watchdog_pid" 2>/dev/null || true
    fi
    # Any nonzero exit keeps the arm's logs, not only an expired deadline: a
    # refused renice or a guard exiting 2 is the same first failure, and its
    # environment is what a reader needs.
    if [ "$retain_logs" = 1 ] || [ "$cleanup_status" -ne 0 ]; then
        printf 'test-qwen-runtime-guards: retained %s arm=%s status=%s loadavg=%s\n' \
            "$temporary_directory" "$current_arm" "$cleanup_status" \
            "$(cut -d ' ' -f 1-3 </proc/loadavg)" >&2
        exit "$cleanup_status"
    fi
    rm -rf "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

# fail_arm DEADLINE_NAME LIMIT_SECONDS ELAPSED_SECONDS DETAIL: the first
# failure keeps its own environment, so the arm's logs stay on disk and the
# load average that produced the timing is printed beside the deadline that
# expired.
fail_arm() {
    retain_logs=1
    printf 'guard test failure arm=%s deadline=%s limit_seconds=%s elapsed_seconds=%s\n' \
        "$current_arm" "$1" "$2" "$3" >&2
    printf 'guard test failure detail=%s loadavg=%s\n' \
        "$4" "$(cut -d ' ' -f 1-3 </proc/loadavg)" >&2
    exit 1
}

# await_log DEADLINE_NAME LIMIT_SECONDS LOG PATTERN: polls the log every 50 ms
# for a fixed-string line until the named deadline passes. The deadline is wall
# clock from `date +%s` rather than a poll count, since a poll costs a grep
# beside its sleep and a counted limit overstates itself under load by exactly
# the factor that makes the arm slow in the first place.
await_log() {
    await_deadline_name=$1
    await_limit_seconds=$2
    await_log_path=$3
    await_pattern=$4
    await_start_seconds=$(date +%s)
    while ! grep -Fq "$await_pattern" "$await_log_path" 2>/dev/null; do
        await_elapsed_seconds=$(($(date +%s) - await_start_seconds))
        if [ "$await_elapsed_seconds" -ge "$await_limit_seconds" ]; then
            fail_arm "$await_deadline_name" "$await_limit_seconds" \
                "$await_elapsed_seconds" "log never carried $await_pattern"
        fi
        sleep 0.05
    done
}

mkdir -p "$fake_gpu_directory"
printf '0\n' >"$fake_gpu_directory/gpu_busy_percent"
printf '0\n' >"$fake_gpu_directory/mem_info_gtt_used"
printf '0\n' >"$fake_gpu_directory/mem_info_vram_used"
printf '0: 200Mhz *\n' >"$fake_gpu_directory/pp_dpm_sclk"
printf '0: 400Mhz *\n' >"$fake_gpu_directory/pp_dpm_mclk"

# Every fixture server runs until this script ends it, so no arm carries a
# duration a slow machine can outrun.
start_persistent_test_process() {
    target_nice_value=$1
    launch_guard_fixture "$target_nice_value" \
        taskset -c 0 sh -c 'while :; do sleep 1; done'
    test_pid=$launched_fixture_pid
}

start_term_ignoring_process() {
    launch_guard_fixture 19 taskset -c 0 sh -c \
        'trap "" TERM; while :; do sleep 1; done'
    test_pid=$launched_fixture_pid
}

start_watchdog_process() {
    launch_guard_fixture 19 taskset -c 0 sh -c 'while :; do sleep 1; done'
    watchdog_pid=$launched_fixture_pid
}

start_kernel_watchdog_process() {
    launch_guard_fixture 19 taskset -c 0 sh -c 'while :; do sleep 1; done'
    kernel_watchdog_pid=$launched_fixture_pid
}

stop_process() {
    kill "$1" 2>/dev/null || true
    wait "$1" 2>/dev/null || true
}

stop_watchdogs() {
    if [ -n "$watchdog_pid" ]; then
        stop_process "$watchdog_pid"
        watchdog_pid=""
    fi
    if [ -n "$kernel_watchdog_pid" ]; then
        stop_process "$kernel_watchdog_pid"
        kernel_watchdog_pid=""
    fi
}

# start_monitor LOG PROFILE [LATENCY_PID KERNEL_PID]: runs the monitor beside
# this shell so the arm can observe its start line before causing the condition
# under test.
start_monitor() {
    monitor_log=$1
    monitor_profile=$2
    monitor_latency_pid=${3:-$watchdog_pid}
    monitor_kernel_pid=${4:-$kernel_watchdog_pid}
    QWEN_GUARD_TEST_MODE=1 QWEN_GPU_DEVICE_DIRECTORY=$fake_gpu_directory \
        run_guard_test "$script_directory/monitor-qwen-runtime.sh" \
        "$test_pid" "$monitor_log" "$monitor_profile" \
        "$monitor_latency_pid" "$monitor_kernel_pid" &
    guard_pid=$!
}

# await_guard_exit EXPECTED_STATUS: the guard has already written its terminal
# line, so this reaps it and compares the status.
await_guard_exit() {
    expected_status=$1
    set +e
    wait "$guard_pid"
    guard_status=$?
    set -e
    guard_pid=""
    if [ "$guard_status" -ne "$expected_status" ]; then
        fail_arm guard_exit_status - - \
            "guard returned $guard_status instead of $expected_status"
    fi
}

# run_server_exit_arm ARM PROFILE LOG: the monitor starts against a live
# fixture, the fixture then leaves, and the monitor reports server_exited. The
# fixture's departure is the event, so the arm is bounded by the guard's own
# observation deadline rather than by a fixture duration.
run_server_exit_arm() {
    current_arm=$1
    server_exit_profile=$2
    server_exit_log=$3
    start_persistent_test_process 19
    start_watchdog_process
    start_kernel_watchdog_process
    start_monitor "$server_exit_log" "$server_exit_profile"
    await_log guard_ready "$fixture_deadline_seconds" "$server_exit_log" \
        'monitor_start_utc='
    stop_process "$test_pid"
    test_pid=""
    await_log guard_observation "$observation_deadline_seconds" \
        "$server_exit_log" 'reason=server_exited'
    await_guard_exit 0
    stop_watchdogs
}

# run_abort_arm ARM PROFILE LOG REASON: the condition is already true when the
# monitor starts, so the observation deadline covers the interval from the
# monitor's first sample to its termination line.
run_abort_arm() {
    current_arm=$1
    abort_profile=$2
    abort_log=$3
    abort_reason=$4
    start_monitor "$abort_log" "$abort_profile" "${5:-$watchdog_pid}" \
        "${6:-$kernel_watchdog_pid}"
    await_log guard_ready "$fixture_deadline_seconds" "$abort_log" \
        'monitor_start_utc='
    await_log guard_observation "$observation_deadline_seconds" "$abort_log" \
        "reason=$abort_reason"
    await_log guard_observation "$observation_deadline_seconds" "$abort_log" \
        'termination_utc='
    await_guard_exit 3
    stop_process "$test_pid"
    test_pid=""
}

require_log_line() {
    if ! grep -Fq "$2" "$1"; then
        fail_arm log_content - - "log lacks $2"
    fi
}

run_server_exit_arm paced-60-server-exit paced-60 \
    "$temporary_directory/positive-telemetry.log"
require_log_line "$temporary_directory/positive-telemetry.log" \
    'reason=server_exited'
require_log_line "$temporary_directory/positive-telemetry.log" \
    'guard_affinity=1 guard_nice=0'

# The diagnostic profile is the census S arm's serialized shape, and the
# monitor admits it under the low-serialized gate; a profile the monitor
# leaves unnamed ends it at once and the session reports monitor_exited.
run_server_exit_arm diagnostic-profile diagnostic \
    "$temporary_directory/diagnostic-telemetry.log"
require_log_line "$temporary_directory/diagnostic-telemetry.log" \
    'profile=diagnostic'
require_log_line "$temporary_directory/diagnostic-telemetry.log" \
    'reason=server_exited'
printf 'diagnostic_profile_admitted=accepted\n'

start_persistent_test_process 18
start_watchdog_process
start_kernel_watchdog_process
run_abort_arm process-nice-changed paced-60 \
    "$temporary_directory/negative-telemetry.log" process_nice_changed
stop_watchdogs

printf '76\n' >"$fake_gpu_directory/gpu_busy_percent"
start_term_ignoring_process
start_watchdog_process
start_kernel_watchdog_process
run_abort_arm gpu-busy-ceiling paced-60 \
    "$temporary_directory/gpu-busy-telemetry.log" gpu_busy_percent_breached
require_log_line "$temporary_directory/gpu-busy-telemetry.log" \
    'action=SIGKILL grace_milliseconds=2000'
stop_watchdogs

printf '100\n' >"$fake_gpu_directory/gpu_busy_percent"
run_server_exit_arm low-serialized-ceiling low-serialized \
    "$temporary_directory/priority-first-telemetry.log"
require_log_line "$temporary_directory/priority-first-telemetry.log" \
    'threshold_maximum_gpu_busy_percent=100'

run_server_exit_arm low-async-ceiling low-async \
    "$temporary_directory/async-priority-first-telemetry.log"
require_log_line "$temporary_directory/async-priority-first-telemetry.log" \
    'threshold_maximum_gpu_busy_percent=100'

printf '0\n' >"$fake_gpu_directory/gpu_busy_percent"
start_persistent_test_process 19
run_abort_arm latency-watchdog-absent low-serialized \
    "$temporary_directory/watchdog-telemetry.log" \
    graphics_latency_watchdog_unavailable 999999999 999999998

start_persistent_test_process 19
start_watchdog_process
run_abort_arm kernel-watchdog-absent low-serialized \
    "$temporary_directory/kernel-watchdog-telemetry.log" \
    kernel_hazard_watchdog_unavailable "$watchdog_pid" 999999997
stop_watchdogs

current_arm=kernel-hazard-watcher
start_persistent_test_process 19
printf '%s\n' 'amdgpu: ring gfx timeout, signaled seq=1' \
    >"$temporary_directory/synthetic-kernel.log"
run_guard_test "$script_directory/watch-qwen-kernel-hazards.sh" "$test_pid" \
    "$temporary_directory/hazard-watch.log" \
    "$temporary_directory/synthetic-kernel.log" &
guard_pid=$!
await_log guard_ready "$fixture_deadline_seconds" \
    "$temporary_directory/hazard-watch.log" 'watch_start_utc='
await_log guard_observation "$observation_deadline_seconds" \
    "$temporary_directory/hazard-watch.log" 'action=SIGTERM'
await_guard_exit 3
stop_process "$test_pid"
test_pid=""
require_log_line "$temporary_directory/hazard-watch.log" \
    'guard_affinity=1 guard_nice=0'

printf 'runtime_monitor=accepted gpu_busy_ceiling=accepted kernel_hazard_watcher=accepted\n'
