#!/bin/sh
set -eu

# Run measure-dpm-force.sh from a caller at nice 5 against a fake llama-bench,
# a writable stand-in for the performance-level node, and a sudo that runs its
# command directly. The harness writes an absolute nice 19 into its own pid
# and reads it back from the kernel, so the retained summary carries
# harness_nice=19 on every arm whatever the caller's own niceness was, and
# the bench the harness forks inherits it: the fake bench records the nice it
# observed on itself.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
active_fixture=initialization
diagnostic_file=
cleanup() {
    cleanup_status=$?
    if [ "$cleanup_status" -ne 0 ]; then
        printf 'dpm fixture failed: %s (status %s)\n' \
            "$active_fixture" "$cleanup_status" >&2
        if [ -n "$diagnostic_file" ] && [ -f "$diagnostic_file" ]; then
            sed -n '1,80p' "$diagnostic_file" >&2
        fi
    fi
    rm -rf -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

# The harness names sudo and pgrep by bare name, so a directory holding the
# two stand-ins is prepended to PATH: sudo strips its own -n and runs the
# command as this user, and pgrep reports no llama process whatever the
# workstation runs beside this test.
stub_directory=$temporary_directory/bin
mkdir -p "$stub_directory"
cat >"$stub_directory/sudo" <<'EOF'
#!/bin/sh
[ "${1:-}" != -n ] || shift
exec "$@"
EOF
printf '#!/bin/sh\nexit 1\n' >"$stub_directory/pgrep"
chmod +x "$stub_directory/sudo" "$stub_directory/pgrep"

drm_device=$temporary_directory/drm-device
mkdir -p "$drm_device"
printf 'auto\n' >"$drm_device/power_dpm_force_performance_level"
printf '2: 933Mhz *\n' >"$drm_device/pp_dpm_mclk"

# The fake bench records the nice value the kernel holds for its own pid
# beside the row the harness parses, which is the inheritance claim under
# test.
fake_bench=$temporary_directory/llama-bench
bench_nice_log=$temporary_directory/bench-nice.log
cat >"$fake_bench" <<EOF
#!/bin/sh
LC_ALL=C /usr/bin/awk '{ line = \$0; sub(/^.*[)] /, "", line); split(line, fields, /[[:space:]]+/); print fields[17] }' /proc/\$\$/stat >>'$bench_nice_log'
exec '$script_directory/test-fixtures/fake-llama-bench.sh' "\$@"
EOF
chmod +x "$fake_bench"
fake_sampler=$temporary_directory/sampler.sh
printf '#!/bin/sh\nprintf "933\\t1100\\t60000\\n" >"$1"\nwhile :; do sleep 1; done\n' \
    >"$fake_sampler"
chmod +x "$fake_sampler"
model_path=$temporary_directory/model.gguf
: >"$model_path"
output_directory=$temporary_directory/dpm

active_fixture=harness-from-nice-5
diagnostic_file=$temporary_directory/dpm.stderr
PATH=$stub_directory:$PATH QWEN_DPM_ROUNDS=1 QWEN_LLAMA_BENCH=$fake_bench \
    QWEN_CLOCK_SAMPLER=$fake_sampler QWEN_DRM_DEVICE=$drm_device \
    nice -n 5 "$script_directory/measure-dpm-force.sh" "$model_path" \
    "$output_directory" >"$temporary_directory/dpm.stdout" 2>"$diagnostic_file"

summary=$output_directory/dpm-summary.tsv
header=$(sed -n '1p' "$summary")
case $header in
    *"	harness_nice	harness_ioclass") ;;
    *)
        printf 'summary header carries no priority columns: %s\n' "$header" >&2
        exit 1
        ;;
esac
arm_rows=$(sed -n '2,$p' "$summary" | wc -l)
if [ "$arm_rows" -ne 2 ]; then
    printf 'one round writes two arms, summary holds %s\n' "$arm_rows" >&2
    exit 1
fi
if ! awk -F'\t' 'NR > 1 && ($9 != 19 || $10 != "idle") { bad = 1 }
                 END { exit bad }' "$summary"; then
    printf 'an arm ran outside nice 19 and the idle class:\n' >&2
    cat "$summary" >&2
    exit 1
fi
if [ "$(grep -c 'harness_nice=19 harness_ioclass=idle' "$temporary_directory/dpm.stdout")" -ne 2 ]; then
    printf 'the arm start lines do not name the harness priority:\n' >&2
    cat "$temporary_directory/dpm.stdout" >&2
    exit 1
fi
if [ "$(sort -u "$bench_nice_log" | tr -d '\n')" != 19 ]; then
    printf 'the bench observed nice %s rather than 19\n' \
        "$(sort -u "$bench_nice_log" | tr '\n' ' ')" >&2
    exit 1
fi
grep -F 'dpm_force=completed' "$temporary_directory/dpm.stdout" >/dev/null

# A failed class transition and a successful command whose readback remains in
# best-effort both fail before the harness writes a measurement summary.
active_fixture=ionice-command-failure
failing_ionice=$temporary_directory/failing-ionice
printf '#!/bin/sh\nexit 1\n' >"$failing_ionice"
chmod +x "$failing_ionice"
if PATH=$stub_directory:$PATH QWEN_DPM_ROUNDS=1 \
        QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
        QWEN_DRM_DEVICE=$drm_device QWEN_DPM_IONICE=$failing_ionice \
        nice -n 5 "$script_directory/measure-dpm-force.sh" "$model_path" \
        "$temporary_directory/dpm-ionice-failed" \
        >"$temporary_directory/dpm-ionice-failed.stdout" \
        2>"$temporary_directory/dpm-ionice-failed.stderr"; then
    printf 'an ionice setup failure reached the measurement\n' >&2
    exit 1
fi
grep -F 'measurement I/O priority setup failed' \
    "$temporary_directory/dpm-ionice-failed.stderr" >/dev/null
test ! -e "$temporary_directory/dpm-ionice-failed/dpm-summary.tsv"

active_fixture=ionice-readback-refusal
best_effort_ionice=$temporary_directory/best-effort-ionice
cat >"$best_effort_ionice" <<'EOF'
#!/bin/sh
if [ "${1:-}" = -p ]; then
    printf 'best-effort: prio 4\n'
fi
exit 0
EOF
chmod +x "$best_effort_ionice"
if PATH=$stub_directory:$PATH QWEN_DPM_ROUNDS=1 \
        QWEN_LLAMA_BENCH=$fake_bench QWEN_CLOCK_SAMPLER=$fake_sampler \
        QWEN_DRM_DEVICE=$drm_device QWEN_DPM_IONICE=$best_effort_ionice \
        nice -n 5 "$script_directory/measure-dpm-force.sh" "$model_path" \
        "$temporary_directory/dpm-ioclass-refused" \
        >"$temporary_directory/dpm-ioclass-refused.stdout" \
        2>"$temporary_directory/dpm-ioclass-refused.stderr"; then
    printf 'a non-idle ionice readback reached the measurement\n' >&2
    exit 1
fi
grep -F 'measurement I/O priority refused: observed=best-effort' \
    "$temporary_directory/dpm-ioclass-refused.stderr" >/dev/null
test ! -e "$temporary_directory/dpm-ioclass-refused/dpm-summary.tsv"

printf 'dpm_harness_priority=passed arms=%s bench_nice=19\n' "$arm_rows"
