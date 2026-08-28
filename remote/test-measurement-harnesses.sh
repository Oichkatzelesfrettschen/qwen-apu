#!/bin/sh
set -eu

# Exercise the evidence contracts without a GPU. Missing sensors remain missing,
# failed arms cannot print a completed terminal state, and every background or
# server process reaches its cleanup path.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
active_fixture=initialization
diagnostic_file=
cleanup() {
    cleanup_status=$?
    if [ "$cleanup_status" -ne 0 ]; then
        printf 'measurement fixture failed: %s (status %s)\n' \
            "$active_fixture" "$cleanup_status" >&2
        if [ -n "$diagnostic_file" ] && [ -f "$diagnostic_file" ]; then
            printf 'measurement fixture diagnostic: %s\n' \
                "$diagnostic_file" >&2
            sed -n '1,160p' "$diagnostic_file" >&2
        fi
    fi
    rm -rf -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

active_fixture=gpu-clock-sampling
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

# A sampler that exits without writing reproduces what a loaded scheduler does to
# the real one: the probe kills it as soon as the arm ends, so a fast arm can
# reach the summary before the first row is written and the file never exists.
silent_sampler=$temporary_directory/silent-clock-sampler.sh
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'printf "%s\\n" "$$" >"${QWEN_TEST_SAMPLER_PID_FILE:?}"' \
    'exit 0' >"$silent_sampler"
chmod +x "$silent_sampler"

fake_bench=$temporary_directory/llama-bench
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'case ${QWEN_TEST_BENCH_MODE:-success} in' \
    '  failure) exit 7 ;;' \
    '  unparseable) printf "benchmark produced no timing row\\n"; exit 0 ;;' \
    '  delayed_success) sleep 2 ;;' \
    '  wrong_prefill) sleep 2; printf "| fake | pp512 | 99.00 +/- 0.10 |\\n| fake | tg64 | 3.00 +/- 0.10 |\\n"; exit 0 ;;' \
    '  wrong_decode) sleep 2; printf "| fake | tg128 | 99.00 +/- 0.10 |\\n"; exit 0 ;;' \
    '  misleading_columns) sleep 2; printf "| pp32 | pp512 | 99.00 +/- 0.10 |\\n| tg64 | tg128 | 99.00 +/- 0.10 |\\n"; exit 0 ;;' \
    '  exact_depth_labels) sleep 2; printf "| fake | pp32 @ d32 | 12.00 +/- 0.10 |\\n| fake | tg64 @ d32 | 3.00 +/- 0.10 |\\n"; exit 0 ;;' \
    '  device_banner) sleep 2; printf "ggml_vulkan: Found 1 Vulkan devices:\\n| fake | pp32 | 12.00 +/- 0.10 |\\n| fake | tg64 | 3.00 +/- 0.10 |\\n\\nbuild: f280b26 (1)\\n"; exit 0 ;;' \
    'esac' \
    'printf "| fake | tg64 | 3.00 +/- 0.10 |\\n"' >"$fake_bench"
chmod +x "$fake_bench"
model_path=$temporary_directory/model.gguf
: >"$model_path"

sampler_pid_file=$temporary_directory/sampler.pid
successful_output=$temporary_directory/repeatability-success
active_fixture=bench-repeatability-success
diagnostic_file=$temporary_directory/success.stderr
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
active_fixture=bench-repeatability-failure
diagnostic_file=$temporary_directory/failure.stderr
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
active_fixture=served-decode-failure
diagnostic_file=$temporary_directory/served.stderr
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
active_fixture=depth-wedge-process-contention
diagnostic_file=$temporary_directory/contended-wedge.stderr
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
active_fixture=cache-factorial-process-contention
diagnostic_file=$temporary_directory/contended-factorial.stderr
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
active_fixture=depth-wedge-unreadable-kernel-log
diagnostic_file=$temporary_directory/wedge.stderr
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

# A sampler that writes nothing leaves the arm without device covariates, which
# this probe records as `unavailable` alongside every other absent device
# reading rather than ending the sweep. It exists to find a wedge, not to
# compare rates, so a missing covariate names itself.
silent_output=$temporary_directory/wedge-silent-sampler
active_fixture=depth-wedge-silent-clock-sampler
diagnostic_file=$temporary_directory/wedge-silent.stderr
QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$silent_sampler \
QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_WEDGE_DEPTHS=1 \
QWEN_WEDGE_GEOMETRIES=1:1 PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$model_path" "$silent_output" \
    >"$temporary_directory/wedge-silent.stdout" \
    2>"$temporary_directory/wedge-silent.stderr"
# Columns 13 and 14 are the memory peaks and 17 and 18 the clock and
# temperature, so naming all four checks both readers of the sampler file.
if ! awk -F'\t' '$1 == "d1-b1-ub1" && $13 == "unavailable" && $14 == "unavailable" &&
        $17 == "unavailable" && $18 == "unavailable" {
        found = 1 } END { exit !found }' \
        "$silent_output/wedge-summary.tsv"; then
    printf 'depth wedge did not record unavailable clocks for a silent sampler\n' >&2
    cat "$silent_output/wedge-summary.tsv" >&2
    exit 1
fi

# Reusing a completed output directory resumes from retained arm identity. The
# row remains unique and the failing bench mode proves no recorded arm reruns or
# overwrites the logs that support it.
active_fixture=depth-wedge-retained-arm-resume
diagnostic_file=$temporary_directory/wedge-resume.stderr
QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_WEDGE_DEPTHS=1 \
QWEN_WEDGE_GEOMETRIES=1:1 QWEN_TEST_BENCH_MODE=failure PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$model_path" "$wedge_output" \
    >"$temporary_directory/wedge-resume.stdout" \
    2>"$temporary_directory/wedge-resume.stderr"
grep -F 'arm_resume_skip label=d1-b1-ub1 status=0' \
    "$temporary_directory/wedge-resume.stdout" >/dev/null
if [ "$(awk -F'\t' '$1 == "d1-b1-ub1" { count++ }
        END { print count + 0 }' "$wedge_output/wedge-summary.tsv")" -ne 1 ]; then
    printf 'depth wedge duplicated a recorded arm on resume\n' >&2
    exit 1
fi

active_fixture=depth-wedge-cache-policy-identity
diagnostic_file=$temporary_directory/wedge-cache-mismatch.stderr
if QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_WEDGE_DEPTHS=1 \
    QWEN_WEDGE_GEOMETRIES=1:1 QWEN_CACHE_TYPE_K=f16 PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$model_path" "$wedge_output" \
    >"$temporary_directory/wedge-cache-mismatch.stdout" \
    2>"$temporary_directory/wedge-cache-mismatch.stderr"; then
    printf 'depth wedge resumed an arm from a different cache policy\n' >&2
    exit 1
fi
grep -F 'recorded arm d1-b1-ub1 belongs to cache policy q8_0/q4_0/on, not f16/q4_0/on' \
    "$temporary_directory/wedge-cache-mismatch.stderr" >/dev/null

disjoint_policy_output=$temporary_directory/wedge-disjoint-policy
mkdir -p "$disjoint_policy_output"
cp "$wedge_output/wedge-metadata.tsv" \
    "$disjoint_policy_output/wedge-metadata.tsv"
cp "$wedge_output/wedge-summary.tsv" \
    "$disjoint_policy_output/wedge-summary.tsv"
for retained_suffix in log clocks.tsv control.log; do
    cp "$wedge_output/d1-b1-ub1.$retained_suffix" \
        "$disjoint_policy_output/d1-b1-ub1.$retained_suffix"
done
active_fixture=depth-wedge-disjoint-cache-policy
diagnostic_file=$temporary_directory/wedge-disjoint-policy.stderr
if QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_WEDGE_DEPTHS=2 \
    QWEN_WEDGE_GEOMETRIES=1:1 QWEN_CACHE_TYPE_K=f16 \
    QWEN_TEST_BENCH_MODE=failure PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$model_path" \
    "$disjoint_policy_output" \
    >"$temporary_directory/wedge-disjoint-policy.stdout" \
    2>"$temporary_directory/wedge-disjoint-policy.stderr"; then
    printf 'depth wedge mixed cache policies across disjoint arm labels\n' >&2
    exit 1
fi
grep -F 'recorded arm d1-b1-ub1 belongs to cache policy q8_0/q4_0/on, not f16/q4_0/on' \
    "$temporary_directory/wedge-disjoint-policy.stderr" >/dev/null
if [ -e "$disjoint_policy_output/d2-b1-ub1.log" ]; then
    printf 'depth wedge created an arm artifact before cache-policy admission\n' >&2
    exit 1
fi

active_fixture=depth-wedge-same-policy-extension
diagnostic_file=$temporary_directory/wedge-same-policy-extension.stderr
QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_WEDGE_DEPTHS=2 \
QWEN_WEDGE_GEOMETRIES=1:1 PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$model_path" \
    "$disjoint_policy_output" \
    >"$temporary_directory/wedge-same-policy-extension.stdout" \
    2>"$temporary_directory/wedge-same-policy-extension.stderr"
if [ "$(awk -F'\t' 'NR > 1 { count++ } END { print count + 0 }' \
        "$disjoint_policy_output/wedge-summary.tsv")" -ne 2 ]; then
    printf 'depth wedge refused a same-policy disjoint arm extension\n' >&2
    exit 1
fi

different_model_path=$temporary_directory/different-model.gguf
printf 'different model bytes\n' >"$different_model_path"
active_fixture=depth-wedge-model-identity
diagnostic_file=$temporary_directory/wedge-model-mismatch.stderr
if QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_WEDGE_DEPTHS=1 \
    QWEN_WEDGE_GEOMETRIES=1:1 PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$different_model_path" \
    "$wedge_output" >"$temporary_directory/wedge-model-mismatch.stdout" \
    2>"$temporary_directory/wedge-model-mismatch.stderr"; then
    printf 'depth wedge resumed an arm from a different model\n' >&2
    exit 1
fi
grep -F 'wedge metadata does not match the model or recovery control:' \
    "$temporary_directory/wedge-model-mismatch.stderr" >/dev/null

kernel_gap_output=$temporary_directory/wedge-kernel-gap
mkdir -p "$kernel_gap_output"
cp "$wedge_output/wedge-metadata.tsv" "$kernel_gap_output/wedge-metadata.tsv"
sed 's/\tunavailable\tunavailable\t/\t0\t0\t/' \
    "$wedge_output/wedge-summary.tsv" >"$kernel_gap_output/wedge-summary.tsv"
for retained_suffix in log clocks.tsv control.log; do
    cp "$wedge_output/d1-b1-ub1.$retained_suffix" \
        "$kernel_gap_output/d1-b1-ub1.$retained_suffix"
done
active_fixture=depth-wedge-kernel-evidence-retention
diagnostic_file=$temporary_directory/wedge-kernel-gap.stderr
if QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_WEDGE_DEPTHS=1 \
    QWEN_WEDGE_GEOMETRIES=1:1 PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$model_path" \
    "$kernel_gap_output" >"$temporary_directory/wedge-kernel-gap.stdout" \
    2>"$temporary_directory/wedge-kernel-gap.stderr"; then
    printf 'depth wedge resumed a numeric kernel row without its delta\n' >&2
    exit 1
fi
grep -F 'recorded arm d1-b1-ub1 is missing retained artifact:' \
    "$temporary_directory/wedge-kernel-gap.stderr" >/dev/null

duplicate_wedge_output=$temporary_directory/wedge-duplicate
mkdir -p "$duplicate_wedge_output"
cp "$wedge_output/wedge-metadata.tsv" \
    "$duplicate_wedge_output/wedge-metadata.tsv"
cp "$wedge_output/wedge-summary.tsv" \
    "$duplicate_wedge_output/wedge-summary.tsv"
sed -n '2p' "$wedge_output/wedge-summary.tsv" \
    >>"$duplicate_wedge_output/wedge-summary.tsv"
active_fixture=depth-wedge-unique-arm-identity
diagnostic_file=$temporary_directory/wedge-duplicate.stderr
if QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file QWEN_WEDGE_DEPTHS=1 \
    QWEN_WEDGE_GEOMETRIES=1:1 PATH="$fake_bin:$PATH" \
    "$script_directory/probe-depth-wedge.sh" "$model_path" \
    "$duplicate_wedge_output" >"$temporary_directory/wedge-duplicate.stdout" \
    2>"$temporary_directory/wedge-duplicate.stderr"; then
    printf 'depth wedge accepted duplicate retained arm identities\n' >&2
    exit 1
fi
grep -F 'wedge summary carries duplicate arm identity: d1-b1-ub1' \
    "$temporary_directory/wedge-duplicate.stderr" >/dev/null

unparseable_output=$temporary_directory/wedge-unparseable
active_fixture=depth-wedge-parser-status
diagnostic_file=$temporary_directory/unparseable.stderr
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
    active_fixture=dpm-round-validation
    diagnostic_file=$temporary_directory/dpm-rounds-$invalid_rounds.stderr
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
active_fixture=bandwidth-niceness-policy
diagnostic_file=$temporary_directory/bandwidth-nice.stderr
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
active_fixture=bandwidth-model-path-order
diagnostic_file=$temporary_directory/bandwidth.stderr
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

# A paired prefill/decode arm is incomplete when llama-bench emits no pp row.
# The retained summary keeps the missing value, and the terminal state fails
# instead of presenting the decode half as a completed paired sweep.
missing_prefill_output=$temporary_directory/bandwidth-missing-prefill
active_fixture=bandwidth-required-prefill-output
diagnostic_file=$temporary_directory/missing-prefill.stderr
if env \
    QWEN_BANDWIDTH_OUTPUT=$missing_prefill_output QWEN_LLAMA_BENCH=$fake_bench \
    QWEN_TENSOR_CENSUS=$fake_census QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file \
    QWEN_TEST_BENCH_MODE=delayed_success QWEN_BENCH_NICE_LEVELS=19 \
    QWEN_BENCH_PREFILL=32 \
    "$script_directory/run-bandwidth-ladder.sh" "$first_spaced_model" \
    >"$temporary_directory/missing-prefill.stdout" \
    2>"$temporary_directory/missing-prefill.stderr"; then
    printf 'bandwidth fixture accepted a missing requested prefill row\n' >&2
    exit 1
fi
grep -F 'arm_prefill_missing' \
    "$temporary_directory/missing-prefill.stderr" >/dev/null
grep -F 'bandwidth_ladder=failed' \
    "$temporary_directory/missing-prefill.stderr" >/dev/null
if grep -F 'bandwidth_ladder=completed' \
    "$temporary_directory/missing-prefill.stdout" >/dev/null; then
    printf 'missing prefill printed a completed terminal state\n' >&2
    exit 1
fi
awk -F'\t' 'NR > 1 && $6 == "n/a" { missing++ }
            END { exit missing == 2 ? 0 : 1 }' \
    "$missing_prefill_output/bandwidth-summary.tsv"

wrong_prefill_output=$temporary_directory/bandwidth-wrong-prefill
active_fixture=bandwidth-requested-prefill-identity
diagnostic_file=$temporary_directory/wrong-prefill.stderr
if env \
    QWEN_BANDWIDTH_OUTPUT=$wrong_prefill_output QWEN_LLAMA_BENCH=$fake_bench \
    QWEN_TENSOR_CENSUS=$fake_census QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file \
    QWEN_TEST_BENCH_MODE=wrong_prefill QWEN_BENCH_NICE_LEVELS=19 \
    QWEN_BENCH_PREFILL=32 \
    "$script_directory/run-bandwidth-ladder.sh" "$first_spaced_model" \
    >"$temporary_directory/wrong-prefill.stdout" \
    2>"$temporary_directory/wrong-prefill.stderr"; then
    printf 'bandwidth fixture accepted pp512 as evidence for pp32\n' >&2
    exit 1
fi
awk -F'\t' 'NR > 1 && $5 == "3.00" && $6 == "n/a" { found++ }
            END { exit found == 2 ? 0 : 1 }' \
    "$wrong_prefill_output/bandwidth-summary.tsv"

wrong_decode_output=$temporary_directory/bandwidth-wrong-decode
active_fixture=bandwidth-requested-decode-identity
diagnostic_file=$temporary_directory/wrong-decode.stderr
if env \
    QWEN_BANDWIDTH_OUTPUT=$wrong_decode_output QWEN_LLAMA_BENCH=$fake_bench \
    QWEN_TENSOR_CENSUS=$fake_census QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file \
    QWEN_TEST_BENCH_MODE=wrong_decode QWEN_BENCH_NICE_LEVELS=19 \
    "$script_directory/run-bandwidth-ladder.sh" "$first_spaced_model" \
    >"$temporary_directory/wrong-decode.stdout" \
    2>"$temporary_directory/wrong-decode.stderr"; then
    printf 'bandwidth fixture accepted tg128 as evidence for tg64\n' >&2
    exit 1
fi
awk -F'\t' 'NR > 1 && $5 == "n/a" { found++ }
            END { exit found == 2 ? 0 : 1 }' \
    "$wrong_decode_output/bandwidth-summary.tsv"

misleading_columns_output=$temporary_directory/bandwidth-misleading-columns
active_fixture=bandwidth-test-column-identity
diagnostic_file=$temporary_directory/misleading-columns.stderr
if env \
    QWEN_BANDWIDTH_OUTPUT=$misleading_columns_output \
    QWEN_LLAMA_BENCH=$fake_bench QWEN_TENSOR_CENSUS=$fake_census \
    QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file \
    QWEN_TEST_BENCH_MODE=misleading_columns QWEN_BENCH_NICE_LEVELS=19 \
    QWEN_BENCH_PREFILL=32 \
    "$script_directory/run-bandwidth-ladder.sh" "$first_spaced_model" \
    >"$temporary_directory/misleading-columns.stdout" \
    2>"$temporary_directory/misleading-columns.stderr"; then
    printf 'bandwidth fixture treated a non-test column as row identity\n' >&2
    exit 1
fi
awk -F'\t' 'NR > 1 && $5 == "n/a" && $6 == "n/a" { found++ }
            END { exit found == 2 ? 0 : 1 }' \
    "$misleading_columns_output/bandwidth-summary.tsv"

exact_label_output=$temporary_directory/bandwidth-exact-labels
active_fixture=bandwidth-depth-qualified-label-identity
diagnostic_file=$temporary_directory/exact-labels.stderr
env QWEN_BANDWIDTH_OUTPUT=$exact_label_output QWEN_LLAMA_BENCH=$fake_bench \
    QWEN_TENSOR_CENSUS=$fake_census QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file \
    QWEN_TEST_BENCH_MODE=exact_depth_labels QWEN_BENCH_NICE_LEVELS=19 \
    QWEN_BENCH_PREFILL=32 \
    "$script_directory/run-bandwidth-ladder.sh" "$first_spaced_model" \
    >"$temporary_directory/exact-labels.stdout" \
    2>"$temporary_directory/exact-labels.stderr"
awk -F'\t' 'NR > 1 && $5 == "3.00" && $6 == "12.00" { found++ }
            END { exit found == 2 ? 0 : 1 }' \
    "$exact_label_output/bandwidth-summary.tsv"

# The real llama-bench frames its table with lines that carry no pipe at all --
# a device banner above it, a blank line and a build line below -- while every
# fixture above emits pipe-bearing lines alone. mawk makes a negative field
# index a fatal run-time error, so an unguarded $(NF - 2) aborts on the banner,
# the extractor's END never runs, and the arm records an empty rate rather than
# the n/a a genuine miss produces. This fixture reproduces the real frame and
# requires both rates to survive it.
banner_output=$temporary_directory/bandwidth-device-banner
active_fixture=bandwidth-unpiped-frame-lines
diagnostic_file=$temporary_directory/device-banner.stderr
env QWEN_BANDWIDTH_OUTPUT=$banner_output QWEN_LLAMA_BENCH=$fake_bench \
    QWEN_TENSOR_CENSUS=$fake_census QWEN_CLOCK_SAMPLER=$fake_sampler \
    QWEN_TEST_SAMPLER_PID_FILE=$sampler_pid_file \
    QWEN_TEST_BENCH_MODE=device_banner QWEN_BENCH_NICE_LEVELS=19 \
    QWEN_BENCH_PREFILL=32 \
    "$script_directory/run-bandwidth-ladder.sh" "$first_spaced_model" \
    >"$temporary_directory/device-banner.stdout" \
    2>"$temporary_directory/device-banner.stderr"
awk -F'\t' 'NR > 1 && $5 == "3.00" && $6 == "12.00" { found++ }
            END { exit found == 2 ? 0 : 1 }' \
    "$banner_output/bandwidth-summary.tsv"
if grep -q 'negative field index' "$temporary_directory/device-banner.stderr"; then
    printf 'bandwidth extractor aborted on a line without pipes\n' >&2
    exit 1
fi

active_fixture=completed
diagnostic_file=
printf 'measurement_harnesses=accepted\n'
