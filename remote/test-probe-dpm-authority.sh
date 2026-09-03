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

# The bench is the arm, so the probe launches it through census_arm_exec and it
# runs under a closed environment. Its fixture controls therefore reach it
# through a file whose path is written into the stub here rather than through
# variables the arm no longer inherits, and it appends its own environment so a
# case reads what the arm was handed rather than what the launch named.
bench_controls=$temporary_directory/bench-controls.tsv
bench_environment=$temporary_directory/bench-environment.txt
: >"$bench_controls"
: >"$bench_environment"
{
    printf '#!/bin/sh\nset -eu\n'
    printf 'bench_controls=%s\n' "$bench_controls"
    printf 'bench_environment=%s\n' "$bench_environment"
    cat <<'STUB'
env >>"$bench_environment"
bench_control() {
    awk -F'\t' -v key="$1" '$1 == key { value = $2; found = 1 }
        END { if (found) print value }' "$bench_controls"
}
bench_sleep=$(bench_control sleep)
sleep "${bench_sleep:-0.4}"
printf '| model | size | params | backend | ngl | test | t/s |\n'
printf '| --- | ---: | ---: | --- | ---: | ---: | ---: |\n'
if [ "$(bench_control without_tg)" = 1 ]; then
    printf '| qwen3 2B Q4_K_M | 1.22 GiB | 2.03 B | Vulkan | 99 | pp512 | 21.03 +/- 0.10 |\n'
    exit 0
fi
printf '| qwen3 2B Q4_K_M | 1.22 GiB | 2.03 B | Vulkan | 99 | tg64 | 6.12 +/- 0.03 |\n'
STUB
} >"$stub_directory/llama-bench"

cat >"$stub_directory/telemetry-broker" <<'STUB'
#!/bin/sh
set -eu
record=$1
shift
period_ms=20
drm_device=''
control=''
hwmon=''
while [ "$#" -gt 0 ]; do
    case $1 in
        --period-ms) period_ms=$2; shift 2 ;;
        --cpu) shift 2 ;;
        --drm-device) drm_device=$2; shift 2 ;;
        --hwmon) hwmon=$2; shift 2 ;;
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
    # telemetry-broker.c opens temp1_input and freq1_input from the --hwmon
    # directory alone, so a broker told nothing writes `unavailable` in the
    # temperature and the delivered-frequency columns. The delivered frequency
    # tracks the selected step here, which is what makes the eighth column the
    # invariant is counted over answer under `high` and hover under `auto`.
    temperature=unavailable
    actual_available=0
    if [ -n "$hwmon" ] && [ -r "$hwmon/temp1_input" ] && [ -r "$hwmon/freq1_input" ]; then
        temperature=$(cat "$hwmon/temp1_input")
        actual_available=1
    fi
    mean_cost=50000
    if [ "${QWEN_TEST_SIDECAR_COST_NS:-}" != "" ]; then
        mean_cost=$QWEN_TEST_SIDECAR_COST_NS
    fi
    {
        printf '# clock=CLOCK_MONOTONIC period_ns=%s drm_device=%s hwmon=%s\n' \
            "$period_ns" "$drm_device" "${hwmon:--}"
        printf '# sample_rates: gpu_busy_percent_period_ns=%s pp_dpm_period_ns=%s temp1_input_period_ns=%s meminfo_period_ns=%s vmstat_period_ns=%s host_period_ns=%s\n' \
            "$period_ns" "$((period_ns * 10))" "$((period_ns * 10))" \
            "$((period_ns * 100))" "$((period_ns * 100))" "$((period_ns * 100))"
        printf '# sampler_pid=%s nice=19 cpu_affinity=0,1\n' "$$"
        printf 'monotonic_ns\tpp_dpm_sclk_selected_mhz\tpp_dpm_mclk_surface_mhz\tpp_dpm_fclk_surface_mhz\tgpu_busy_percent\ttemp1_millidegrees\tsample_cost_ns\tsclk_actual_mhz\n'
        awk -F'\t' '{ printf "# mark name=%s monotonic_ns=%s\n", substr($1, 6), $2 }' \
            "$marks"
        awk -v start="$start_ns" -v period="$period_ns" \
            -v span="$((end_ns - start_ns))" -v level="$level" \
            -v temperature="$temperature" -v actual_available="$actual_available" \
            -v mean_cost="$mean_cost" '
            BEGIN {
                rows = int(span / period) + 3
                if (rows < 4) { rows = 4 }
                unavailable_rows = (temperature == "unavailable") ? rows : 0
                for (row = 0; row < rows; row++) {
                    # The DPM surfaces sit on the tenth-period channel and
                    # the validator counts one reading per channel period,
                    # so a governor that hovers is written as a decade of
                    # rows at each step rather than as alternating rows the
                    # count never sees.
                    sclk = 1100
                    if (level == "auto" && int(row / 10) % 2 == 1) { sclk = 650 }
                    actual = (actual_available == 1) ? sclk "" : "unavailable"
                    printf "%d\t%d\t1067\t1067\t94.0\t%s\t50000\t%s\n",
                        start + row * period, sclk, temperature, actual
                }
                printf "# samples=%d achieved_period_ns=%d mean_sample_cost_ns=%d max_sample_cost_ns=%d samples_with_unavailable_sensor=%d first_sample_ns=%d last_sample_ns=%d\n",
                    rows, period, mean_cost, mean_cost, unavailable_rows, start,
                    start + (rows - 1) * period
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

lease_fixture=$temporary_directory/vulkan-workload.lock
: >"$lease_fixture"

# The hwmon rule takes the first entry whose name attribute reads amdgpu, so
# the fixture puts another sensor ahead of it in glob order.
hwmon_root_fixture=$temporary_directory/hwmon
mkdir -p "$hwmon_root_fixture/hwmon0" "$hwmon_root_fixture/hwmon1"
printf 'nvme\n' >"$hwmon_root_fixture/hwmon0/name"
printf '41000\n' >"$hwmon_root_fixture/hwmon0/temp1_input"
printf 'amdgpu\n' >"$hwmon_root_fixture/hwmon1/name"
printf '75000\n' >"$hwmon_root_fixture/hwmon1/temp1_input"
printf '1100000000\n' >"$hwmon_root_fixture/hwmon1/freq1_input"

model_fixture=$temporary_directory/model.gguf
printf 'not a real gguf\n' >"$model_fixture"

radv_icd_fixture=$temporary_directory/radeon_icd.x86_64.json
printf '{}\n' >"$radv_icd_fixture"

reset_level() {
    printf 'manual\n' >"$drm_fixture/power_dpm_force_performance_level"
}

# `exec` makes the probe the process this shell became, so a caller that needs
# the probe's own pid gets it from `$!` rather than getting a wrapper whose
# death leaves the probe, the broker, and the bench writing the fixture. Every
# ordinary case reaches it through run_probe, whose subshell absorbs the exec.
exec_probe() {
    probe_output=$1
    shift
    # The two ambient settings are what the closed arm environment exists to
    # stop: GGML_VK_Q4K_SIDEPLANE gates its pre-pass on getenv returning a
    # pointer rather than on the value, so a 0 here enables the feature a
    # control arm is defined by leaving off, and
    # QWEN_CACHE_OVERRIDE_CONTEXT_CEILING is a QWEN_ name every scrub in the
    # launch chain leaves alone. Every case runs with both set, so the arm
    # environment record and the bench's own environment are read against a
    # shell that carried them.
    exec env PATH="$stub_directory:$PATH" \
        GGML_VK_Q4K_SIDEPLANE=0 \
        QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=65536 \
        QWEN_DRM_DEVICE="$drm_fixture" \
        QWEN_BAPM_PARAMETER="$bapm_fixture" \
        QWEN_HWMON_ROOT="$hwmon_root_fixture" \
        QWEN_RADV_ICD="$radv_icd_fixture" \
        QWEN_VULKAN_WORKLOAD_LOCK="$lease_fixture" \
        QWEN_TELEMETRY_BROKER="$stub_directory/telemetry-broker" \
        "$@" "$probe" "$probe_output" "$model_fixture" \
        "$stub_directory/llama-bench"
}

run_probe() {
    ( exec_probe "$@" )
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
    QWEN_HWMON_ROOT="$hwmon_root_fixture" \
    QWEN_VULKAN_WORKLOAD_LOCK="$lease_fixture" \
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

# lease: another Vulkan workload shares whatever level this probe forces and
# lands in the rate its receipt carries, so the probe refuses before it writes
# the level rather than measuring a contended decode.
reset_level
# The holder ends on a flag file rather than on a signal, because a signalled
# `flock FILE COMMAND` leaves the command holding the inherited descriptor and
# the lease outlives the process the test killed.
lease_flag=$temporary_directory/lease-held
: >"$lease_flag"
(
    exec 9>"$lease_fixture"
    flock 9
    while [ -e "$lease_flag" ]; do
        sleep 0.05
    done
) &
lease_holder_pid=$!
lease_held() {
    lease_probe_status=0
    flock -n -E 75 "$lease_fixture" true || lease_probe_status=$?
    [ "$lease_probe_status" -eq 75 ]
}
lease_attempt=0
while [ "$lease_attempt" -lt 200 ] && ! lease_held; do
    lease_attempt=$((lease_attempt + 1))
    sleep 0.05
done
lease_status=0
run_probe "$temporary_directory/out-lease" \
    >"$temporary_directory/lease.log" 2>&1 || lease_status=$?
rm -f -- "$lease_flag"
wait "$lease_holder_pid" 2>/dev/null || true
lease_attempt=0
while [ "$lease_attempt" -lt 200 ] && lease_held; do
    lease_attempt=$((lease_attempt + 1))
    sleep 0.05
done
if [ "$lease_status" -eq 2 ] &&
    grep -q 'another Vulkan workload holds the shared lease' \
        "$temporary_directory/lease.log" &&
    [ ! -e "$temporary_directory/out-lease" ] &&
    [ "$(cat "$drm_fixture/power_dpm_force_performance_level")" = manual ]; then
    report 0 refuses_while_another_workload_holds_the_lease
else
    report 1 refuses_while_another_workload_holds_the_lease
    cat "$temporary_directory/lease.log" >&2
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

# The record is the broker's own eight-column shape, so the sixth column the
# thermal peak is read from sits inside a wider row and the peak is the hwmon
# fixture's own reading rather than an absent row.
high_thermal=$(receipt_field "$complete_output/D1-high/dpm-receipt.tsv" thermal_peak_millic)
if [ "$high_thermal" = 75000 ] &&
    grep -q "	sclk_actual_mhz$" "$complete_output/D1-high/clock-sidecar.tsv"; then
    report 0 wide_record_reports_a_thermal_peak
else
    report 1 wide_record_reports_a_thermal_peak
    printf 'thermal_peak_millic=%s\n' "$high_thermal" >&2
fi

# The invariant is counted over the delivered frequency in the eighth column,
# which the broker fills from the hwmon directory the probe resolved. A probe
# that named none would leave that column unavailable, the count at zero, and
# the invariant violated on a level that held.
high_at_max=$(receipt_field "$complete_output/D1-high/dpm-receipt.tsv" samples_at_max)
if grep -q "hwmon=$hwmon_root_fixture/hwmon1\$" \
    "$complete_output/D1-high/clock-sidecar.tsv" &&
    [ "${high_at_max:-0}" -gt 0 ]; then
    report 0 broker_reads_the_resolved_amdgpu_hwmon
else
    report 1 broker_reads_the_resolved_amdgpu_hwmon
    printf 'samples_at_max=%s\n' "$high_at_max" >&2
fi

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
printf 'without_tg\t1\n' >"$bench_controls"
run_probe "$notg_output" \
    >"$temporary_directory/notg.log" 2>&1 || notg_status=$?
: >"$bench_controls"
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

# A record the validator refuses still carries whatever the invariant counted
# over the samples it holds, so the two readings are separate: the receipt
# keeps `held` beside `refused` and the campaign-facing authority line names
# none. The mean sample cost carries the refusal because it is the one footer
# figure a stub can move without changing a single clock reading.
reset_level
refused_output=$temporary_directory/out-refused-record
refused_record_status=0
run_probe "$refused_output" QWEN_TEST_SIDECAR_COST_NS=2000000 \
    >"$temporary_directory/refused-record.log" 2>&1 || refused_record_status=$?
refused_invariant=$(receipt_field "$refused_output/D1-high/dpm-receipt.tsv" clock_invariant)
refused_verdict=$(receipt_field "$refused_output/D1-high/dpm-receipt.tsv" sidecar_verdict)
if [ "$refused_record_status" -eq 0 ] && [ "$refused_invariant" = held ] &&
    [ "$refused_verdict" = refused ] &&
    grep -q '^dpm_authority=none bapm=Y$' "$temporary_directory/refused-record.log"; then
    report 0 refused_record_names_no_authority
else
    report 1 refused_record_names_no_authority
    printf 'invariant=%s verdict=%s\n' "$refused_invariant" "$refused_verdict" >&2
fi

# A terminating signal reaches the probe while the decode is live, and the
# laptop is left on the level the run found rather than on a forced one. The
# arm execs so `$!` is the probe itself: a signal that reached a wrapper alone
# would leave the probe, its broker, and its bench running.
reset_level
term_output=$temporary_directory/out-term
printf 'sleep\t8\n' >"$bench_controls"
{ exec_probe "$term_output"; } \
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
# The broker the arm started is the witness that the signal reached the probe
# rather than a wrapper around it: the probe tears its broker down from the
# same trap that restores the level, so a probe that survived the signal leaves
# this pid alive and keeps writing the record.
term_broker_pid=$(awk '$0 ~ /^telemetry_broker=ready / {
        for (field = 1; field <= NF; field++) {
            if ($field ~ /^pid=/) { print substr($field, 5); exit }
        }
    }' "$term_output/D0-auto/clock-sidecar.stderr" 2>/dev/null || true)
kill -TERM "$term_pid" 2>/dev/null || true
term_status=0
wait "$term_pid" || term_status=$?
term_broker_alive=0
if [ -n "$term_broker_pid" ] && kill -0 "$term_broker_pid" 2>/dev/null; then
    term_broker_alive=1
    kill -TERM "$term_broker_pid" 2>/dev/null || true
fi
if [ "$term_status" -eq 143 ] &&
    grep -q '^dpm_restore=held requested=manual observed=manual$' \
        "$temporary_directory/term.log" &&
    ! grep -q '^dpm_authority=' "$temporary_directory/term.log" &&
    [ -n "$term_broker_pid" ] && [ "$term_broker_alive" -eq 0 ] &&
    [ ! -d "$term_output/D1-high" ] &&
    [ "$(cat "$drm_fixture/power_dpm_force_performance_level")" = manual ]; then
    report 0 restores_level_on_term
else
    report 1 restores_level_on_term
    printf 'term_status=%s level=%s broker_pid=%s broker_alive=%s\n' "$term_status" \
        "$(cat "$drm_fixture/power_dpm_force_performance_level")" \
        "${term_broker_pid:--}" "$term_broker_alive" >&2
fi

: >"$bench_controls"

# The closed arm environment, read from both sides. Every case above ran with
# GGML_VK_Q4K_SIDEPLANE and QWEN_CACHE_OVERRIDE_CONTEXT_CEILING set in the
# invoking shell: the record each arm keeps names neither, and neither reaches
# the bench's own environment, which is what a record alone could not prove.
environment_isolated=0
for isolation_arm in D0-auto D1-high D2-profile_peak; do
    isolation_record=$complete_output/$isolation_arm/arm-environment.tsv
    if [ ! -s "$isolation_record" ]; then
        environment_isolated=1
        printf 'arm environment record is absent: %s\n' "$isolation_record" >&2
        continue
    fi
    if [ "$(head -n 1 "$isolation_record")" != "$(printf 'name\tvalue')" ]; then
        environment_isolated=1
        printf 'arm environment record carries no header: %s\n' "$isolation_record" >&2
    fi
    for isolation_name in GGML_VK_Q4K_SIDEPLANE QWEN_CACHE_OVERRIDE_CONTEXT_CEILING; do
        if cut -f1 "$isolation_record" | grep -qx "$isolation_name"; then
            environment_isolated=1
            printf 'ambient %s reached the arm record: %s\n' "$isolation_name" \
                "$isolation_record" >&2
        fi
    done
    # The names the arm requires are what make the record a statement rather
    # than an empty set.
    for isolation_required in PATH HOME VK_DRIVER_FILES LLAMA_NO_CPU_FALLBACK; do
        if ! cut -f1 "$isolation_record" | grep -qx "$isolation_required"; then
            environment_isolated=1
            printf 'arm environment record omits %s: %s\n' "$isolation_required" \
                "$isolation_record" >&2
        fi
    done
done
if [ ! -s "$bench_environment" ]; then
    environment_isolated=1
    printf 'the bench recorded no environment of its own\n' >&2
fi
for isolation_name in GGML_VK_Q4K_SIDEPLANE QWEN_CACHE_OVERRIDE_CONTEXT_CEILING; do
    if grep -q "^$isolation_name=" "$bench_environment"; then
        environment_isolated=1
        printf 'ambient %s reached the bench environment\n' "$isolation_name" >&2
    fi
done
report "$environment_isolated" arm_environment_excludes_ambient_settings

if [ "$failures" -ne 0 ]; then
    printf 'probe_dpm_authority_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'probe_dpm_authority_tests=passed\n'
