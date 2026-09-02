#!/bin/sh
# Prove remote/await-quiescence.sh converges on a stable fixture that stars a
# middle sclk step, times out against a predicate that never clears (gpu_busy,
# and a starred highest sclk step naming sclk on stderr), times out against a
# predicate that clears instantaneously but keeps violating its hold-window
# derivative (rising temperature, and a moving starred sclk step), and times
# out while the workload lease is held. Every predicate source is a file
# under a fixture tree named through --drm-device, --hwmon, and --proc-root,
# so the poller under test never reads the real machine.
set -eu

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
under_test=$script_directory/await-quiescence.sh
temporary_directory=$(mktemp -d)
writer_pid=''

cleanup() {
    if [ -n "$writer_pid" ] && kill -0 "$writer_pid" 2>/dev/null; then
        kill "$writer_pid" 2>/dev/null || true
        wait "$writer_pid" 2>/dev/null || true
    fi
    rm -rf "$temporary_directory"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf 'FAIL %s\n' "$1" >&2
    exit 1
}

pass() {
    printf 'ok %s\n' "$1"
}

drm_device=$temporary_directory/drm/device
hwmon_root=$temporary_directory/hwmon
hwmon_device=$hwmon_root/hwmon0
proc_root=$temporary_directory/proc

mkdir -p "$drm_device" "$hwmon_device" "$proc_root"

write_stable_fixture() {
    printf '0: 200Mhz\n1: 400Mhz *\n2: 800Mhz\n' >"$drm_device/pp_dpm_sclk"
    printf '2\n' >"$drm_device/gpu_busy_percent"
    printf 'amdgpu\n' >"$hwmon_device/name"
    printf '55000\n' >"$hwmon_device/temp1_input"
    printf 'MemTotal:       30000000 kB\nMemAvailable:   20000000 kB\n' \
        >"$proc_root/meminfo"
    printf 'pswpin 5\npswpout 3\n' >"$proc_root/vmstat"
}

run_under_test() {
    # $@ = extra arguments beyond the fixture paths every case shares.
    "$under_test" --drm-device "$drm_device" --hwmon "$hwmon_root" \
        --proc-root "$proc_root" "$@"
}

field() {
    # $1 = output line, $2 = key; prints the value of key=value inside the
    # poller's own vector so a test reads the same field names the tool
    # documents rather than re-deriving them.
    printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -1
}

# Case 1: a stable fixture reaches quiescence once the hold window elapses,
# and not before it.
write_stable_fixture
started_ns=$(date +%s%N)
if ! output=$(run_under_test --max-seconds 5 --hold-ms 300); then
    fail "stable fixture did not reach quiescence: $output"
fi
finished_ns=$(date +%s%N)
wall_ms=$(( (finished_ns - started_ns) / 1000000 ))
case $output in
    quiescence=reached*) : ;;
    *) fail "stable fixture printed no reached line: $output" ;;
esac
elapsed_ms=$(field "$output" elapsed_ms)
case $elapsed_ms in
    '' | *[!0-9]*) fail "reached line carries no numeric elapsed_ms: $output" ;;
esac
if [ "$elapsed_ms" -lt 300 ]; then
    fail "reached before the 300 ms hold window: elapsed_ms=$elapsed_ms"
fi
if [ "$wall_ms" -lt 300 ]; then
    fail "wall clock shows less than the hold window: wall_ms=$wall_ms"
fi
if [ "$(field "$output" sclk_step)" != 1 ]; then
    fail "stable fixture (middle step starred) reported the wrong sclk_step: $output"
fi
if [ "$(field "$output" sclk_steps)" != 3 ]; then
    fail "stable fixture reported the wrong sclk_steps: $output"
fi
pass "stable fixture reaches quiescence after its hold window (elapsed_ms=$elapsed_ms)"

# Case 2: a fixture whose gpu_busy_percent never drops to the threshold never
# starts a hold window, so --max-seconds 2 always times out.
write_stable_fixture
printf '40\n' >"$drm_device/gpu_busy_percent"
started_ns=$(date +%s%N)
status=0
output=$(run_under_test --max-seconds 2 --hold-ms 300) || status=$?
finished_ns=$(date +%s%N)
wall_ms=$(( (finished_ns - started_ns) / 1000000 ))
if [ "$status" -ne 1 ]; then
    fail "gpu_busy=40 fixture exited $status rather than the timeout status 1"
fi
case $output in
    quiescence=timeout*) : ;;
    *) fail "gpu_busy=40 fixture printed no timeout line: $output" ;;
esac
if [ "$(field "$output" gpu_busy_ok)" != 0 ]; then
    fail "gpu_busy=40 fixture reported gpu_busy_ok=1: $output"
fi
if [ "$wall_ms" -lt 2000 ]; then
    fail "gpu_busy=40 fixture returned before --max-seconds 2 elapsed: wall_ms=$wall_ms"
fi
pass "gpu_busy_percent=40 fixture times out at --max-seconds 2"
printf '2\n' >"$drm_device/gpu_busy_percent"

# Case 3: a fixture that stars the highest listed sclk step never satisfies
# "below the highest step", so it never starts a hold window and the run
# times out. The stderr predicate line names sclk as the failing predicate,
# which proves a reader can attribute this timeout without recomputing the
# vector.
write_stable_fixture
printf '0: 200Mhz\n1: 400Mhz\n2: 800Mhz *\n' >"$drm_device/pp_dpm_sclk"
started_ns=$(date +%s%N)
status=0
output=$(run_under_test --max-seconds 2 --hold-ms 300 2>"$temporary_directory/stderr") || status=$?
stderr_output=$(cat "$temporary_directory/stderr")
finished_ns=$(date +%s%N)
wall_ms=$(( (finished_ns - started_ns) / 1000000 ))
if [ "$status" -ne 1 ]; then
    fail "highest-step-starred fixture exited $status rather than the timeout status 1"
fi
case $output in
    quiescence=timeout*) : ;;
    *) fail "highest-step-starred fixture printed no timeout line: $output" ;;
esac
if [ "$(field "$output" sclk_ok)" != 0 ]; then
    fail "highest-step-starred fixture reported sclk_ok=1: $output"
fi
if [ "$(field "$output" sclk_step)" != 2 ] || [ "$(field "$output" sclk_steps)" != 3 ]; then
    fail "highest-step-starred fixture reported the wrong sclk_step/sclk_steps: $output"
fi
timeout_predicates=$(printf '%s\n' "$stderr_output" | sed -n 's/^quiescence_timeout_predicates=//p')
case ",$timeout_predicates," in
    *,sclk,*) : ;;
    *) fail "highest-step-starred fixture's stderr did not name sclk: $stderr_output" ;;
esac
if [ "$wall_ms" -lt 2000 ]; then
    fail "highest-step-starred fixture returned before --max-seconds 2 elapsed: wall_ms=$wall_ms"
fi
pass "a fixture starring the highest listed sclk step times out and names sclk on stderr"
write_stable_fixture

# Case 4: a fixture whose temperature climbs 2 degrees Celsius across the
# hold window keeps restarting the window instead of completing it, so a
# 2 second budget times out even though every instantaneous predicate reads
# clear on every tick. The writer raises temp1_input by 0.25 degrees every
# 100 ms, 2.5 degrees Celsius per second, five times the 0.5 degree ceiling.
write_stable_fixture
(
    step=0
    while [ "$step" -lt 40 ]; do
        millicelsius=$((55000 + step * 250))
        printf '%s\n' "$millicelsius" >"$hwmon_device/temp1_input"
        step=$((step + 1))
        sleep 0.1
    done
) &
writer_pid=$!
started_ns=$(date +%s%N)
status=0
output=$(run_under_test --max-seconds 2 --hold-ms 800) || status=$?
finished_ns=$(date +%s%N)
wall_ms=$(( (finished_ns - started_ns) / 1000000 ))
kill "$writer_pid" 2>/dev/null || true
wait "$writer_pid" 2>/dev/null || true
writer_pid=''
if [ "$status" -ne 1 ]; then
    fail "rising-temperature fixture exited $status rather than the timeout status 1"
fi
case $output in
    quiescence=timeout*) : ;;
    *) fail "rising-temperature fixture printed no timeout line: $output" ;;
esac
if [ "$wall_ms" -lt 2000 ]; then
    fail "rising-temperature fixture returned before --max-seconds 2 elapsed: wall_ms=$wall_ms"
fi
pass "a 2.5 degree-per-second rise never completes the hold window"
write_stable_fixture

# Case 5: a fixture whose starred sclk step moves between step 1 and step 0
# during the hold window restarts the window on every move, the way a
# rising temperature does, and only reaches quiescence once the writer
# stops and the step holds still for the full window. The writer alternates
# every 30 ms, faster than the poller's own 100 ms tick, so no run of three
# consecutive ticks (the 300 ms hold window) can catch the same value by
# alignment alone while the writer is still moving it.
write_stable_fixture
(
    step=0
    while [ "$step" -lt 34 ]; do
        if [ $((step % 2)) -eq 0 ]; then
            printf '0: 200Mhz\n1: 400Mhz *\n2: 800Mhz\n' >"$drm_device/pp_dpm_sclk"
        else
            printf '0: 200Mhz *\n1: 400Mhz\n2: 800Mhz\n' >"$drm_device/pp_dpm_sclk"
        fi
        step=$((step + 1))
        sleep 0.03
    done
    printf '0: 200Mhz\n1: 400Mhz *\n2: 800Mhz\n' >"$drm_device/pp_dpm_sclk"
) &
writer_pid=$!
started_ns=$(date +%s%N)
if ! output=$(run_under_test --max-seconds 5 --hold-ms 300); then
    fail "moving-sclk-step fixture did not reach quiescence: $output"
fi
finished_ns=$(date +%s%N)
wait "$writer_pid" 2>/dev/null || true
writer_pid=''
wall_ms=$(( (finished_ns - started_ns) / 1000000 ))
case $output in
    quiescence=reached*) : ;;
    *) fail "moving-sclk-step fixture printed no reached line: $output" ;;
esac
if [ "$wall_ms" -lt 1000 ]; then
    fail "moving-sclk-step fixture reached before the writer stopped moving the step: wall_ms=$wall_ms"
fi
pass "a moving starred sclk step restarts the hold window and reaches only once it settles"

# Case 6: a held workload lease never reads free, so quiescence is never
# reached regardless of every other predicate.
lease_file=$temporary_directory/vulkan-workload.lock
: >"$lease_file"
exec 8>"$lease_file"
flock -x 8
started_ns=$(date +%s%N)
status=0
output=$(run_under_test --max-seconds 2 --hold-ms 300 --lease "$lease_file") || status=$?
finished_ns=$(date +%s%N)
wall_ms=$(( (finished_ns - started_ns) / 1000000 ))
exec 8>&-
if [ "$status" -ne 1 ]; then
    fail "held-lease fixture exited $status rather than the timeout status 1"
fi
case $output in
    quiescence=timeout*) : ;;
    *) fail "held-lease fixture printed no timeout line: $output" ;;
esac
if [ "$(field "$output" lease_ok)" != 0 ]; then
    fail "held-lease fixture reported lease_ok=1: $output"
fi
if [ "$wall_ms" -lt 2000 ]; then
    fail "held-lease fixture returned before --max-seconds 2 elapsed: wall_ms=$wall_ms"
fi
pass "a held workload lease times out rather than reaching quiescence"

# Case 7: releasing the same lease lets a fresh run reach quiescence, which
# proves case 6 tested the lease rather than an unrelated fixture defect.
write_stable_fixture
if ! output=$(run_under_test --max-seconds 5 --hold-ms 300 --lease "$lease_file"); then
    fail "released-lease fixture did not reach quiescence: $output"
fi
if [ "$(field "$output" lease_ok)" != 1 ]; then
    fail "released-lease fixture reported lease_ok=0: $output"
fi
pass "the same lease file reads free once released, and quiescence follows"

# Case 8: a latency log naming no baseline is not_applicable rather than a
# blocker, since remote/summarize-probe.sh's own log format never writes one.
write_stable_fixture
latency_log=$temporary_directory/graphics-latency.log
printf 'probe_start realtime_ns=1 device=fixture vendor=0x1002 device_id=0x15d8 queue_family=0 global_priority=MEDIUM deadline_us=20000 interval_ms=16 watched_pid=0\n' \
    >"$latency_log"
printf 'sample realtime_ns=2 index=1 elapsed_us=400 result=0\n' >>"$latency_log"
if ! output=$(run_under_test --max-seconds 5 --hold-ms 300 --latency-log "$latency_log"); then
    fail "no-baseline latency fixture did not reach quiescence: $output"
fi
if [ "$(field "$output" latency_ok)" != 1 ]; then
    fail "no-baseline latency fixture reported latency_ok=0: $output"
fi
if [ "$(field "$output" latency_baseline_us)" != - ]; then
    fail "no-baseline latency fixture named a baseline: $output"
fi
pass "a latency log naming no baseline is not_applicable and does not block"

printf 'await_quiescence=accepted\n'
