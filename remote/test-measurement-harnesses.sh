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
    'if [ "${QWEN_TEST_BENCH_MODE:-success}" = failure ]; then exit 7; fi' \
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
    'printf "server=fake\\nprofile=fake\\ncache=fake\\n" >"${QWEN_STATE_DIRECTORY:?}/session.status"' \
    >"$fake_launch"
chmod +x "$fake_launch"
fake_teardown=$temporary_directory/fake-teardown.sh
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'printf "called\\n" >"${QWEN_TEST_TEARDOWN_MARKER:?}"' \
    >"$fake_teardown"
chmod +x "$fake_teardown"
teardown_marker=$temporary_directory/teardown-called
if QWEN_LAUNCH_SCRIPT=$fake_launch QWEN_TEARDOWN_SCRIPT=$fake_teardown \
    QWEN_STATE_DIRECTORY=$fake_state QWEN_RESULT_DIRECTORY=$fake_result \
    QWEN_TEST_TEARDOWN_MARKER=$teardown_marker QWEN_SERVER_PORT=9 \
    "$script_directory/measure-served-decode.sh" fixture "$model_path" \
    >"$temporary_directory/served.stdout" \
    2>"$temporary_directory/served.stderr"; then
    printf 'served measurement accepted a failed request\n' >&2
    exit 1
fi
test -s "$teardown_marker"
grep -F 'served_decode=failed' "$temporary_directory/served.stderr" >/dev/null
if grep -F 'served_decode=completed' "$temporary_directory/served.stdout" >/dev/null; then
    printf 'failed served measurement printed a completed terminal state\n' >&2
    exit 1
fi

printf 'measurement_harnesses=accepted\n'
