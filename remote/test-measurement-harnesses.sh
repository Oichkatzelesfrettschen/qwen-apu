#!/bin/sh
set -eu

# Exercise the evidence contracts without a GPU. Missing sensors remain missing,
# failed arms cannot print a completed terminal state, and every background or
# server process reaches its cleanup path.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
cleanup() {
    rm -rf -- "$temporary_directory"
}
trap cleanup EXIT HUP INT TERM

drm_device=$temporary_directory/drm-device
hwmon_root=$temporary_directory/hwmon
mkdir -p "$drm_device" "$hwmon_root"
printf '2: 933Mhz *\n' >"$drm_device/pp_dpm_mclk"

sample_output=$temporary_directory/clocks.tsv
QWEN_DRM_DEVICE=$drm_device QWEN_HWMON_ROOT=$hwmon_root \
    "$script_directory/sample-gpu-clocks.sh" "$sample_output" 0.05 &
sample_pid=$!
sample_attempt=0
while [ ! -s "$sample_output" ] && [ "$sample_attempt" -lt 20 ]; do
    sample_attempt=$((sample_attempt + 1))
    sleep 0.05
done
kill "$sample_pid" 2>/dev/null || true
wait "$sample_pid" 2>/dev/null || true

sample_row=$(sed -n '1p' "$sample_output")
sample_mclk=$(printf '%s\n' "$sample_row" | awk -F'\t' '{ print $1 }')
sample_sclk=$(printf '%s\n' "$sample_row" | awk -F'\t' '{ print $2 }')
sample_temperature=$(printf '%s\n' "$sample_row" | awk -F'\t' '{ print $3 }')
sample_vram=$(printf '%s\n' "$sample_row" | awk -F'\t' '{ print $5 }')
sample_gtt=$(printf '%s\n' "$sample_row" | awk -F'\t' '{ print $6 }')
if [ "$sample_mclk" != 933 ] || [ "$sample_sclk" != unavailable ] || \
   [ "$sample_temperature" != unavailable ] || \
   [ "$sample_vram" != unavailable ] || [ "$sample_gtt" != unavailable ]; then
    printf 'sampler collapsed a missing sensor into a measurement: %s\n' \
        "$sample_row" >&2
    exit 1
fi
if QWEN_DRM_DEVICE=$drm_device QWEN_HWMON_ROOT=$hwmon_root \
    "$script_directory/sample-gpu-clocks.sh" "$sample_output" 0 \
    >"$temporary_directory/interval.stdout" \
    2>"$temporary_directory/interval.stderr"; then
    printf 'sampler accepted a zero interval\n' >&2
    exit 1
fi
grep -F 'interval must be a positive number' \
    "$temporary_directory/interval.stderr" >/dev/null

fake_sampler=$temporary_directory/fake-clock-sampler.sh
apply_fake_sampler=$temporary_directory/fake-sampler-body
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'output_file=$1' \
    'printf "%s\\n" "$$" >"${QWEN_TEST_SAMPLER_PID_FILE:?}"' \
    'printf "933\\t1100\\t88000\\t5.00\\t1024\\t2048\\n" >"$output_file"' \
    'trap "exit 0" HUP INT TERM' \
    'while :; do sleep 1; done' >"$apply_fake_sampler"
cp "$apply_fake_sampler" "$fake_sampler"
chmod +x "$fake_sampler"

fake_bench=$temporary_directory/llama-bench
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'case ${QWEN_TEST_BENCH_MODE:-success} in' \
    '  failure) exit 7 ;;' \
    '  unparseable) printf "benchmark produced no timing row\\n"; exit 0 ;;' \
    '  delayed_success) sleep 2 ;;' \
    'esac' \
    'printf "| fake | tg64 | 3.00 +/- 0.10 |\\n"' >"$fake_bench"
chmod +x "$fake_bench"
model_path=$temporary_directory/model.gguf
: >"$model_path"

sampler_pid_file=$temporary_directory/sampler.pid
successful_output=$temporary_directory/repeatability-success
QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_IDLE_SECONDS=0 \
    "$script_directory/measure-bench-repeatability.sh" "$model_path" \
    "$successful_output" >"$temporary_directory/success.stdout" \
    2>"$temporary_directory/success.stderr"
grep -F 'bench_repeatability=completed' \
    "$temporary_directory/success.stdout" >/dev/null
if kill -0 "$(cat "$sampler_pid_file")" 2>/dev/null; then
    printf 'successful measurement left its sampler alive\n' >&2
    exit 1
fi

failed_output=$temporary_directory/repeatability-failure
if QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_IDLE_SECONDS=0 \
    QWEN_TEST_BENCH_MODE=failure \
    "$script_directory/measure-bench-repeatability.sh" "$model_path" \
    "$failed_output" >"$temporary_directory/failure.stdout" \
    2>"$temporary_directory/failure.stderr"; then
    printf 'failed measurement returned success\n' >&2
    exit 1
fi
grep -F 'bench_repeatability=failed' \
    "$temporary_directory/failure.stderr" >/dev/null
if grep -F 'bench_repeatability=completed' \
    "$temporary_directory/failure.stdout" >/dev/null; then
    printf 'failed measurement printed a completed terminal state\n' >&2
    exit 1
fi
if kill -0 "$(cat "$sampler_pid_file")" 2>/dev/null; then
    printf 'failed measurement left its sampler alive\n' >&2
    exit 1
fi

fake_state=$temporary_directory/state
fake_result=$temporary_directory/served-result
mkdir -p "$fake_state"
fake_launch=$temporary_directory/fake-launch.sh
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'state_directory=${QWEN_WEBUI_STATE_DIRECTORY:?}' \
    'printf "%s\\n" "$state_directory" >"${QWEN_TEST_LAUNCH_STATE_MARKER:?}"' \
    'printf "server=fake\\nprofile=fake\\ncache=fake\\n" >"$state_directory/session.status"' \
    >"$fake_launch"
chmod +x "$fake_launch"
fake_teardown=$temporary_directory/fake-teardown.sh
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'printf "%s\\n" "${QWEN_WEBUI_STATE_DIRECTORY:?}" >"${QWEN_TEST_TEARDOWN_STATE_MARKER:?}"' \
    'printf "called\\n" >"${QWEN_TEST_TEARDOWN_MARKER:?}"' \
    >"$fake_teardown"
chmod +x "$fake_teardown"
teardown_marker=$temporary_directory/teardown-called
launch_state_marker=$temporary_directory/launch-state
teardown_state_marker=$temporary_directory/teardown-state
if QWEN_LAUNCH_SCRIPT=$fake_launch QWEN_TEARDOWN_SCRIPT=$fake_teardown \
    QWEN_STATE_DIRECTORY=$fake_state QWEN_RESULT_DIRECTORY=$fake_result \
    QWEN_TEST_LAUNCH_STATE_MARKER=$launch_state_marker \
    QWEN_TEST_TEARDOWN_STATE_MARKER=$teardown_state_marker \
    QWEN_TEST_TEARDOWN_MARKER=$teardown_marker QWEN_SERVER_PORT=9 \
    "$script_directory/measure-served-decode.sh" fixture "$model_path" \
    >"$temporary_directory/served.stdout" \
    2>"$temporary_directory/served.stderr"; then
    printf 'served measurement accepted a failed request\n' >&2
    exit 1
fi
test -s "$teardown_marker"
grep -Fx "$fake_state" "$launch_state_marker" >/dev/null
grep -Fx "$fake_state" "$teardown_state_marker" >/dev/null
grep -F 'served_decode=failed' "$temporary_directory/served.stderr" >/dev/null
if grep -F 'served_decode=completed' "$temporary_directory/served.stdout" >/dev/null; then
    printf 'failed served measurement printed a completed terminal state\n' >&2
    exit 1
fi

# Hazardous GPU harnesses reject both server and benchmark contention before
# creating a summary or starting a sampler.
contender_directory=$temporary_directory/contender
mkdir -p "$contender_directory"
ln -s /bin/sleep "$contender_directory/llama-bench"
"$contender_directory/llama-bench" 30 &
contender_pid=$!
contender_attempt=0
while ! pgrep -x llama-bench >/dev/null 2>&1 && \
      [ "$contender_attempt" -lt 20 ]; do
    contender_attempt=$((contender_attempt + 1))
    sleep 0.05
done
if QWEN_LLAMA_BENCH=$fake_bench \
    "$script_directory/probe-depth-wedge.sh" "$model_path" \
    "$temporary_directory/contended-wedge" \
    >"$temporary_directory/contended-wedge.stdout" \
    2>"$temporary_directory/contended-wedge.stderr"; then
    printf 'depth wedge accepted an existing llama-bench workload\n' >&2
    exit 1
fi
grep -F 'another llama process holds the device' \
    "$temporary_directory/contended-wedge.stderr" >/dev/null
if QWEN_LLAMA_BENCH=$fake_bench \
    "$script_directory/run-kv-cache-factorial.sh" "$model_path" \
    "$temporary_directory/contended-factorial" \
    >"$temporary_directory/contended-factorial.stdout" \
    2>"$temporary_directory/contended-factorial.stderr"; then
    printf 'cache factorial accepted an existing llama-bench workload\n' >&2
    exit 1
fi
grep -F 'another llama process holds the device' \
    "$temporary_directory/contended-factorial.stderr" >/dev/null
kill "$contender_pid" 2>/dev/null || true
wait "$contender_pid" 2>/dev/null || true

# Unreadable dmesg removes a stale per-arm delta instead of converting an old
# reset into a current measurement. A successful bench with no timing row is a
# parser failure for both the arm and its mandatory recovery control.
fake_bin=$temporary_directory/fake-bin
mkdir -p "$fake_bin"
printf '%s\n' '#!/bin/sh' 'exit 1' >"$fake_bin/dmesg"
chmod +x "$fake_bin/dmesg"
wedge_output=$temporary_directory/wedge
mkdir -p "$wedge_output"
printf 'GPU reset from an earlier run\n' >"$wedge_output/d1-b1-ub1.dmesg.txt"
QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_WEDGE_DEPTHS=1 \
QWEN_WEDGE_GEOMETRIES=1:1 PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$model_path" "$wedge_output" \
    >"$temporary_directory/wedge.stdout" \
    2>"$temporary_directory/wedge.stderr"
if [ -e "$wedge_output/d1-b1-ub1.dmesg.txt" ]; then
    printf 'depth wedge retained a stale kernel delta when dmesg was unreadable\n' >&2
    exit 1
fi
awk -F'\t' '$1 == "d1-b1-ub1" && $9 == "unavailable" { found = 1 }
            END { exit !found }' "$wedge_output/wedge-summary.tsv"

unparseable_output=$temporary_directory/wedge-unparseable
if QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file \
    QWEN_TEST_BENCH_MODE=unparseable QWEN_WEDGE_DEPTHS=1 \
    QWEN_WEDGE_GEOMETRIES=1:1 PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$model_path" \
    "$unparseable_output" >"$temporary_directory/unparseable.stdout" \
    2>"$temporary_directory/unparseable.stderr"; then
    printf 'depth wedge accepted an unparseable recovery control\n' >&2
    exit 1
fi
grep -F 'control_failed label=d1-b1-ub1' \
    "$temporary_directory/unparseable.stderr" >/dev/null
awk -F'\t' '$1 == "d1-b1-ub1" && $8 == 65 && $15 == 65 { found = 1 }
            END { exit !found }' "$unparseable_output/wedge-summary.tsv"

for invalid_rounds in 0 -1; do
    if QWEN_DPM_ROUNDS=$invalid_rounds QWEN_LLAMA_BENCH=$fake_bench \
        "$script_directory/measure-dpm-force.sh" "$model_path" \
        >"$temporary_directory/dpm-rounds-$invalid_rounds.stdout" \
        2>"$temporary_directory/dpm-rounds-$invalid_rounds.stderr"; then
        printf 'DPM harness accepted invalid rounds: %s\n' \
            "$invalid_rounds" >&2
        exit 1
    fi
    grep -F "DPM rounds must be a positive integer: $invalid_rounds" \
        "$temporary_directory/dpm-rounds-$invalid_rounds.stderr" >/dev/null
done

# Bash arrays preserve each model path through the reversed pass. The fixture
# uses spaces in both names and requires two arms per model.
fake_census=$temporary_directory/fake-census.py
printf '%s\n' '#!/usr/bin/env python3' \
    'print("streamed_bytes_per_token\t1000")' \
    >"$fake_census"
chmod +x "$fake_census"
first_spaced_model=$temporary_directory/'first model.gguf'
second_spaced_model=$temporary_directory/'second model.gguf'
: >"$first_spaced_model"
: >"$second_spaced_model"
bandwidth_output=$temporary_directory/bandwidth
if QWEN_BENCH_NICE_LEVELS=0 QWEN_BANDWIDTH_OUTPUT=$bandwidth_output \
    QWEN_LLAMA_BENCH=$fake_bench \
    "$script_directory/run-bandwidth-ladder.sh" \
    "$first_spaced_model" "$second_spaced_model" \
    >"$temporary_directory/bandwidth-nice.stdout" \
    2>"$temporary_directory/bandwidth-nice.stderr"; then
    printf 'bandwidth fixture accepted a priority other than nice 19\n' >&2
    exit 1
fi
grep -F 'bandwidth ladder requires nice 19: 0' \
    "$temporary_directory/bandwidth-nice.stderr" >/dev/null
if ! env \
    QWEN_BANDWIDTH_OUTPUT=$bandwidth_output QWEN_LLAMA_BENCH=$fake_bench \
    QWEN_TENSOR_CENSUS=$fake_census QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file \
    QWEN_TEST_BENCH_MODE=delayed_success QWEN_BENCH_NICE_LEVELS=19 \
    "$script_directory/run-bandwidth-ladder.sh" \
    "$first_spaced_model" "$second_spaced_model" \
    >"$temporary_directory/bandwidth.stdout" \
    2>"$temporary_directory/bandwidth.stderr"; then
    printf 'bandwidth fixture failed before path-order verification\n' >&2
    sed -n '1,160p' "$temporary_directory/bandwidth.stderr" >&2
    exit 1
fi
for model_name in 'first model' 'second model'; do
    if [ "$(awk -F'\t' -v model="$model_name" '$3 == model { count++ }
                    END { print count + 0 }' \
                    "$bandwidth_output/bandwidth-summary.tsv")" -ne 2 ]; then
        printf 'reversed bandwidth ladder split or lost model path: %s\n' \
            "$model_name" >&2
        exit 1
    fi
done

printf 'measurement_harnesses=accepted\n'
