#!/bin/sh
set -eu

# probe-dpm-authority.sh writes a kernel power interface and drives a real
# decode, so its gates are checked against a fixture drm directory and four
# stubs instead: a sudo that records writes and answers readbacks from the
# fixture, a pgrep that reports the device free or held, a llama-bench that
# emits one markdown tg row, and a telemetry broker that answers MARK on its
# control FIFO and drains a record whose selected graphics clock sits at the
# fixture's top step under `high` and alternates under `auto`.
#
# The fixture's snapshot level is `manual` so a restore is visible: every arm
# writes some other level, and a probe that left the laptop forced would leave
# the fixture reading that forced level after the run.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
probe=$script_directory/probe-dpm-authority.sh
temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    if [ "${QWEN_TEST_KEEP_OUTPUT:-0}" = 1 ]; then
        printf 'dpm_authority_fixture_directory=%s\n' "$temporary_directory" >&2
    else
        rm -rf -- "$temporary_directory"
    fi
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

failures=0
report() {
    if [ "$1" = 0 ]; then
        printf 'ok %s\n' "$2"
    else
        printf 'FAIL %s\n' "$2"
        failures=$((failures + 1))
    fi
}

stub_directory=$temporary_directory/stubs
mkdir -p "$stub_directory"

cat >"$stub_directory/sudo" <<'STUB'
#!/bin/sh
set -eu
if [ "${1:-}" = -n ]; then
    shift
fi
case ${1:-} in
    true)
        if [ "${QWEN_TEST_SUDO_REFUSE_ALL:-0}" = 1 ]; then
            exit 1
        fi
        exit 0
        ;;
    tee)
        target=$2
        content=$(cat)
        if [ "${QWEN_TEST_SUDO_REFUSE:-0}" = 1 ] && [ "$content" = profile_peak ]; then
            printf 'tee: %s: Invalid argument\n' "$target" >&2
            exit 1
        fi
        printf '%s\n' "$content" >"$target"
        printf '%s\n' "$content"
        exit 0
        ;;
esac
exit 1
STUB

cat >"$stub_directory/pgrep" <<'STUB'
#!/bin/sh
set -eu
if [ "${QWEN_TEST_LISTENER:-0}" = 1 ]; then
    printf '4242\n'
    exit 0
fi
exit 1
STUB

cat >"$stub_directory/llama-bench" <<'STUB'
#!/bin/sh
set -eu
sleep "${QWEN_TEST_BENCH_SLEEP:-0.4}"
printf '| model | size | params | backend | ngl | test | t/s |\n'
printf '| --- | ---: | ---: | --- | ---: | ---: | ---: |\n'
if [ "${QWEN_TEST_BENCH_WITHOUT_TG:-0}" = 1 ]; then
    printf '| qwen3 2B Q4_K_M | 1.22 GiB | 2.03 B | Vulkan | 99 | pp512 | 21.03 +/- 0.10 |\n'
    exit 0
fi
printf '| qwen3 2B Q4_K_M | 1.22 GiB | 2.03 B | Vulkan | 99 | tg64 | 6.12 +/- 0.03 |\n'
STUB

cat >"$stub_directory/telemetry-broker" <<'STUB'
#!/bin/sh
set -eu
record=$1
shift
period_ms=20
drm_device=''
control=''
while [ "$#" -gt 0 ]; do
    case $1 in
        --period-ms) period_ms=$2; shift 2 ;;
        --cpu) shift 2 ;;
        --drm-device) drm_device=$2; shift 2 ;;
        --hwmon) shift 2 ;;
        --control) control=$2; shift 2 ;;
        *) shift ;;
    esac
done
period_ns=$((period_ms * 1000000))
marks=$record.marks
: >"$marks"
now_ns() {
    awk '{ printf "%.0f\n", $1 * 1000000000 }' /proc/uptime
}
start_ns=$(now_ns)
reader_pid=''

write_record() {
    end_ns=$(now_ns)
    if [ -n "$reader_pid" ]; then
        kill "$reader_pid" 2>/dev/null || true
    fi
    level=$(cat "$drm_device/power_dpm_force_performance_level" 2>/dev/null) || level=auto
    {
        printf '# clock=CLOCK_MONOTONIC period_ns=%s drm_device=%s hwmon=-\n' \
            "$period_ns" "$drm_device"
        printf '# sample_rates: gpu_busy_percent_period_ns=%s pp_dpm_period_ns=%s temp1_input_period_ns=%s meminfo_period_ns=%s vmstat_period_ns=%s host_period_ns=%s\n' \
            "$period_ns" "$((period_ns * 10))" "$((period_ns * 10))" \
            "$((period_ns * 100))" "$((period_ns * 100))" "$((period_ns * 100))"
        printf '# sampler_pid=%s nice=19 cpu_affinity=0,1\n' "$$"
        printf 'monotonic_ns\tpp_dpm_sclk_selected_mhz\tpp_dpm_mclk_surface_mhz\tpp_dpm_fclk_surface_mhz\tgpu_busy_percent\ttemp1_millidegrees\tsample_cost_ns\n'
        awk -F'\t' '{ printf "# mark name=%s monotonic_ns=%s\n", substr($1, 6), $2 }' \
            "$marks"
        awk -v start="$start_ns" -v period="$period_ns" \
            -v span="$((end_ns - start_ns))" -v level="$level" '
            BEGIN {
                rows = int(span / period) + 3
                if (rows < 4) { rows = 4 }
                for (row = 0; row < rows; row++) {
                    sclk = 1100
                    if (level == "auto" && row % 2 == 1) { sclk = 650 }
                    printf "%d\t%d\t1067\t1067\t94.0\t75000\t50000\n",
                        start + row * period, sclk
                }
                printf "# samples=%d achieved_period_ns=%d mean_sample_cost_ns=50000 max_sample_cost_ns=50000 samples_with_unavailable_sensor=0 first_sample_ns=%d last_sample_ns=%d\n",
                    rows, period, start, start + (rows - 1) * period
            }'
    } >"$record"
    exit 0
}
trap write_record TERM INT

if [ -n "$control" ]; then
    (
        while :; do
            while read -r command; do
                printf '%s\t%s\n' "$command" "$(now_ns)" >>"$marks"
            done <"$control"
        done
    ) &
    reader_pid=$!
fi
printf 'telemetry_broker=ready pid=%s period_ns=%s\n' "$$" "$period_ns" >&2
while :; do
    sleep 0.05
done
STUB

chmod +x "$stub_directory/sudo" "$stub_directory/pgrep" \
    "$stub_directory/llama-bench" "$stub_directory/telemetry-broker"

drm_fixture=$temporary_directory/drm
mkdir -p "$drm_fixture"
printf 'manual\n' >"$drm_fixture/power_dpm_force_performance_level"
printf '0: 200Mhz\n1: 400Mhz\n2: 1100Mhz *\n' >"$drm_fixture/pp_dpm_sclk"
printf '0: 400Mhz\n1: 933Mhz\n2: 1067Mhz *\n' >"$drm_fixture/pp_dpm_mclk"
printf '0: 400Mhz\n1: 1067Mhz *\n' >"$drm_fixture/pp_dpm_fclk"
bapm_fixture=$temporary_directory/bapm
printf 'Y\n' >"$bapm_fixture"

model_fixture=$temporary_directory/model.gguf
printf 'not a real gguf\n' >"$model_fixture"

reset_level() {
    printf 'manual\n' >"$drm_fixture/power_dpm_force_performance_level"
}

run_probe() {
    probe_output=$1
    shift
    PATH="$stub_directory:$PATH" \
    QWEN_DRM_DEVICE="$drm_fixture" \
    QWEN_BAPM_PARAMETER="$bapm_fixture" \
    QWEN_TELEMETRY_BROKER="$stub_directory/telemetry-broker" \
        env "$@" "$probe" "$probe_output" "$model_fixture" \
        "$stub_directory/llama-bench"
}

# usage: two arguments are the minimum and four are one too many.
usage_status=0
"$probe" >"$temporary_directory/usage.log" 2>&1 || usage_status=$?
if [ "$usage_status" -eq 2 ] &&
    grep -q '^usage: .*OUTPUT_DIR MODEL_PATH \[LLAMA_BENCH\]$' \
        "$temporary_directory/usage.log"; then
    report 0 usage_refuses_argument_count
else
    report 1 usage_refuses_argument_count
fi

# sudo: the probe never prompts, so an absent cached credential ends it
# before it reads a drm surface, and the refusal names the command that
# creates one.
reset_level
sudo_status=0
run_probe "$temporary_directory/out-nosudo" QWEN_TEST_SUDO_REFUSE_ALL=1 \
    >"$temporary_directory/nosudo.log" 2>&1 || sudo_status=$?
if [ "$sudo_status" -eq 2 ] && grep -q 'sudo -v' "$temporary_directory/nosudo.log" &&
    [ ! -e "$temporary_directory/out-nosudo" ]; then
    report 0 refuses_without_cached_sudo
else
    report 1 refuses_without_cached_sudo
fi

# listener: a llama process holding the device makes every clock reading a
# reading of that process rather than of the requested level.
reset_level
listener_status=0
run_probe "$temporary_directory/out-listener" QWEN_TEST_LISTENER=1 \
    >"$temporary_directory/listener.log" 2>&1 || listener_status=$?
if [ "$listener_status" -eq 2 ] &&
    grep -q 'holds the device' "$temporary_directory/listener.log"; then
    report 0 refuses_with_llama_process_holding_device
else
    report 1 refuses_with_llama_process_holding_device
fi

# drm: an unreadable device names the surface it could not read.
reset_level
drm_status=0
PATH="$stub_directory:$PATH" QWEN_DRM_DEVICE="$temporary_directory/absent-drm" \
    QWEN_BAPM_PARAMETER="$bapm_fixture" \
    QWEN_TELEMETRY_BROKER="$stub_directory/telemetry-broker" \
    "$probe" "$temporary_directory/out-nodrm" "$model_fixture" \
    "$stub_directory/llama-bench" \
    >"$temporary_directory/nodrm.log" 2>&1 || drm_status=$?
if [ "$drm_status" -eq 2 ] &&
    grep -q 'drm surface is unreadable' "$temporary_directory/nodrm.log"; then
    report 0 refuses_unreadable_drm_device
else
    report 1 refuses_unreadable_drm_device
fi

# output directory: a resumable ledger is what this is not, so an existing
# path is refused rather than merged into.
reset_level
mkdir -p "$temporary_directory/out-existing"
existing_status=0
run_probe "$temporary_directory/out-existing" \
    >"$temporary_directory/existing.log" 2>&1 || existing_status=$?
if [ "$existing_status" -eq 2 ] &&
    grep -q 'output directory already exists' "$temporary_directory/existing.log"; then
    report 0 refuses_existing_output_directory
else
    report 1 refuses_existing_output_directory
fi

# The complete chain: three levels, three receipts, one authority.
reset_level
complete_output=$temporary_directory/out-complete
complete_status=0
run_probe "$complete_output" >"$temporary_directory/complete.log" 2>&1 ||
    complete_status=$?
if [ "$complete_status" -eq 0 ] &&
    [ -f "$complete_output/D0-auto/dpm-receipt.tsv" ] &&
    [ -f "$complete_output/D1-high/dpm-receipt.tsv" ] &&
    [ -f "$complete_output/D2-profile_peak/dpm-receipt.tsv" ] &&
    [ -f "$complete_output/snapshot/pp_dpm_sclk" ]; then
    report 0 three_levels_write_receipts
else
    report 1 three_levels_write_receipts
    cat "$temporary_directory/complete.log" >&2
fi

receipt_rows_present=0
for row in requested_performance_level observed_performance_level \
    available_sclk_levels max_sclk_mhz selected_sclk_before \
    selected_sclk_during selected_sclk_after samples_in_window \
    samples_at_max samples_below_max below_max_fraction \
    thermal_peak_millic gpu_busy_mean tok_s clock_invariant sclk_share \
    pp_dpm_period_ns window_begin_ns window_end_ns sidecar_verdict \
    bench_status; do
    if ! cut -f1 "$complete_output/D1-high/dpm-receipt.tsv" 2>/dev/null |
        grep -qx "$row"; then
        receipt_rows_present=1
        printf 'receipt row absent: %s\n' "$row" >&2
    fi
done
report "$receipt_rows_present" receipt_carries_every_row

receipt_field() {
    awk -F'\t' -v key="$2" '$1 == key { print $2; exit }' "$1" 2>/dev/null || true
}

# The verdict: `high` pins the fixture's top step and `auto` alternates, so
# the invariant holds on one and is violated on the other, and `auto` is
# never asked to hold.
high_invariant=$(receipt_field "$complete_output/D1-high/dpm-receipt.tsv" clock_invariant)
auto_invariant=$(receipt_field "$complete_output/D0-auto/dpm-receipt.tsv" clock_invariant)
high_below=$(receipt_field "$complete_output/D1-high/dpm-receipt.tsv" samples_below_max)
auto_below=$(receipt_field "$complete_output/D0-auto/dpm-receipt.tsv" samples_below_max)
high_during=$(receipt_field "$complete_output/D1-high/dpm-receipt.tsv" selected_sclk_during)
high_rate=$(receipt_field "$complete_output/D1-high/dpm-receipt.tsv" tok_s)
if [ "$high_invariant" = held ] && [ "$auto_invariant" = not_requested ] &&
    [ "$high_below" = 0 ] && [ "${auto_below:-0}" -gt 0 ] &&
    [ "$high_during" = 1100 ] && [ "$high_rate" = 6.12 ]; then
    report 0 high_holds_where_auto_hovers
else
    report 1 high_holds_where_auto_hovers
    printf 'high=%s auto=%s below=%s/%s during=%s rate=%s\n' \
        "$high_invariant" "$auto_invariant" "$high_below" "$auto_below" \
        "$high_during" "$high_rate" >&2
fi

# The receipt reads validate-clock-sidecar.py rather than counting the same
# rows again, so every count in it appears verbatim on that arm's retained
# clock-state lines and the structural verdict survives the invariant
# failure the validator files against the hovering governor.
counts_agree=0
for arm in D0-auto D1-high; do
    receipt=$complete_output/$arm/dpm-receipt.tsv
    state=$complete_output/$arm/clock-state.txt
    at_max=$(receipt_field "$receipt" samples_at_max)
    below_max=$(receipt_field "$receipt" samples_below_max)
    in_window=$(receipt_field "$receipt" samples_in_window)
    verdict=$(receipt_field "$receipt" sidecar_verdict)
    if ! grep -q "samples_at_required=$at_max samples_below_required=$below_max " \
        "$state" ||
        ! grep -q "window_samples=$in_window " "$state" ||
        [ "$verdict" != accepted ]; then
        counts_agree=1
        printf 'receipt and clock-state disagree for %s\n' "$arm" >&2
    fi
done
report "$counts_agree" receipt_counts_come_from_the_validator

summary_shape=0
for level in auto high profile_peak; do
    if ! grep -q "^dpm_level=$level observed=[^ ]* sclk_during=[^ ]* below_max_fraction=[^ ]* tok_s=[^ ]* clock_invariant=[^ ]*$" \
        "$temporary_directory/complete.log"; then
        summary_shape=1
        printf 'summary line absent for level %s\n' "$level" >&2
    fi
done
if ! grep -q '^dpm_authority=high bapm=Y$' "$temporary_directory/complete.log"; then
    summary_shape=1
    printf 'authority line absent or wrong\n' >&2
fi
report "$summary_shape" summary_line_shape

if grep -q '^dpm_restore=held requested=manual observed=manual$' \
    "$temporary_directory/complete.log" &&
    [ "$(cat "$drm_fixture/power_dpm_force_performance_level")" = manual ]; then
    report 0 restores_level_on_normal_exit
else
    report 1 restores_level_on_normal_exit
fi

# A bench whose output carries no row for the requested token count states
# no rate, so the arm reads `not_run` rather than inheriting `held` from a
# clock record that no decode ran under.
reset_level
notg_output=$temporary_directory/out-notg
notg_status=0
run_probe "$notg_output" QWEN_TEST_BENCH_WITHOUT_TG=1 \
    >"$temporary_directory/notg.log" 2>&1 || notg_status=$?
notg_invariant=$(receipt_field "$notg_output/D1-high/dpm-receipt.tsv" clock_invariant)
if [ "$notg_status" -eq 0 ] && [ "$notg_invariant" = not_run ] &&
    grep -q '^dpm_authority=none bapm=Y$' "$temporary_directory/notg.log"; then
    report 0 missing_tg_row_reports_not_run
else
    report 1 missing_tg_row_reports_not_run
fi

# profile_peak declined by the firmware is a property of the part, so the
# chain records it and still names the authority that held.
reset_level
refuse_output=$temporary_directory/out-refuse
refuse_status=0
run_probe "$refuse_output" QWEN_TEST_SUDO_REFUSE=1 \
    >"$temporary_directory/refuse.log" 2>&1 || refuse_status=$?
refuse_invariant=$(receipt_field "$refuse_output/D2-profile_peak/dpm-receipt.tsv" \
    clock_invariant)
if [ "$refuse_status" -eq 0 ] && [ "$refuse_invariant" = unsupported ] &&
    grep -q '^dpm_level=unsupported requested=profile_peak observed=' \
        "$temporary_directory/refuse.log" &&
    grep -q '^dpm_authority=high bapm=Y$' "$temporary_directory/refuse.log"; then
    report 0 profile_peak_unsupported_on_refused_write
else
    report 1 profile_peak_unsupported_on_refused_write
fi

# A terminating signal reaches the probe while the decode is live, and the
# laptop is left on the level the run found rather than on a forced one.
reset_level
term_output=$temporary_directory/out-term
run_probe "$term_output" QWEN_TEST_BENCH_SLEEP=8 \
    >"$temporary_directory/term.log" 2>&1 &
term_pid=$!
term_attempt=0
while [ "$term_attempt" -lt 200 ]; do
    if grep -q '^telemetry_broker=ready ' \
        "$term_output/D0-auto/clock-sidecar.stderr" 2>/dev/null; then
        break
    fi
    term_attempt=$((term_attempt + 1))
    sleep 0.05
done
sleep 0.3
kill -TERM "$term_pid" 2>/dev/null || true
term_status=0
wait "$term_pid" || term_status=$?
if [ "$term_status" -eq 143 ] &&
    grep -q '^dpm_restore=held requested=manual observed=manual$' \
        "$temporary_directory/term.log" &&
    [ "$(cat "$drm_fixture/power_dpm_force_performance_level")" = manual ]; then
    report 0 restores_level_on_term
else
    report 1 restores_level_on_term
    printf 'term_status=%s level=%s\n' "$term_status" \
        "$(cat "$drm_fixture/power_dpm_force_performance_level")" >&2
fi

if [ "$failures" -ne 0 ]; then
    printf 'probe_dpm_authority_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'probe_dpm_authority_tests=passed\n'
