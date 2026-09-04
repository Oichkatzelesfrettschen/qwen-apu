#!/bin/sh
set -eu

# Test whether a DPM authority makes the peak engine clock a positive
# invariant of a decode rather than an observed regime.
#
# The census calibrations read the selected graphics clock at 1100 MHz over
# about nine arms, then between 750 and 857 MHz, and after a twenty-minute
# build on the laptop's own two cores at 658 MHz
# (evidence/raven2-vulkan-kernel-census/README.md, the regime paragraphs).
# Decode scales with it: 97 ms of GPU bracket per token times 1100/658 plus
# 3.4 ms of host reads is 165.6 ms per token, 6.04 tok/s, against the 5.7 to
# 6.1 tok/s those arms measured. amdgpu documents
# power_dpm_force_performance_level=high as forcing the highest power state
# and profile_peak as pinning SCLK, MCLK, and PCIe at peak with clock and
# power gating disabled for profiling, so each is a candidate authority over
# the regime. This probe measures one short decode under auto, high, and
# profile_peak and writes a clock-authority receipt per level whose verdict
# is the count of in-window samples below the top pp_dpm_sclk step.
#
# measure-dpm-force.sh already alternates auto against high and restores the
# level from a trap. What it lacked is the verdict: it summarized a modal
# FCLK and a decode rate, bound neither to the bench's own execution window,
# ran no profile_peak arm, and stated no invariant a campaign could carry as
# a contract row. Its measurement-priority block is lifted verbatim, because
# `renice --priority` writes the absolute nice level where `nice -n 19` adds
# 19 to the caller's own, and both values are read back from the kernel.
#
# The window is taken in the record's own clock. telemetry-broker.c stamps
# every row with CLOCK_MONOTONIC and `date +%s%N` is CLOCK_REALTIME, so the
# two epochs differ by boot time and a realtime instant selects no rows at
# all. The probe therefore drives the broker's control FIFO, marking
# bench_start and bench_end around the bench, and reads the two
# `# mark name=... monotonic_ns=...` lines back out of the drained record.
#
# The DPM surfaces sit on telemetry-broker.c's tenth-period channel
# (DPM_PERIOD_MULTIPLE 10), so the 20 ms sample period puts pp_dpm_sclk at
# 200 ms rather than 100 ms. The receipt records pp_dpm_period_ns read back
# from the record's own `# sample_rates` header instead of asserting a
# channel rate. Every column is emitted on every row and a row between two
# channel reads repeats the previous reading, so samples_in_window and the
# counts taken over it are time-weighted rather than measurement-weighted,
# which is the figure a decode-rate claim wants and is named as that here.
#
# The probe writes nothing to /sys/module/amdgpu/parameters/bapm. It reads
# that parameter and carries it on the summary line as an observation,
# because a `none` verdict moves the investigation to the package power
# layer -- BAPM, STAPM, thermal -- and the reader needs to know which state
# the refusal was measured under.

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    printf 'usage: %s OUTPUT_DIR MODEL_PATH [LLAMA_BENCH]\n' "$0" >&2
    exit 2
fi

output_directory=$1
model_path=$2
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
# The decode arm runs under the closed environment census_arm_exec applies, so
# an ambient GGML_VK_*, RADV_*, or LLAMA_* setting reaches no arm and each arm
# keeps the record of what did. The lease descriptor survives it: `env -i`
# replaces the environment and leaves the descriptor table alone, which is what
# makes the exclusion span every arm.
# shellcheck source=census-arm-lib.sh
. "$script_directory/census-arm-lib.sh"
bench=${3:-"$qwen_home_llama_census_bench"}
broker=${QWEN_TELEMETRY_BROKER:-"$script_directory/../build/telemetry-broker"}
validator=${QWEN_CLOCK_VALIDATOR:-"$script_directory/validate-clock-sidecar.py"}
drm_device=${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}
bapm_parameter=${QWEN_BAPM_PARAMETER:-/sys/module/amdgpu/parameters/bapm}
ionice_command=${QWEN_DPM_IONICE:-/usr/bin/ionice}
# The bench runs directly rather than through radv-low-priority-env.sh, so the
# ICD the loader reads is stated here the way that wrapper states it.
radv_icd=${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
hwmon_root=${QWEN_HWMON_ROOT:-/sys/class/hwmon}
sidecar_period_ms=${QWEN_DPM_SIDECAR_PERIOD_MS:-20}
sidecar_cpu=${QWEN_DPM_SIDECAR_CPU:-0,1}
generate_tokens=${QWEN_DPM_GENERATE_TOKENS:-64}
repetitions=${QWEN_DPM_REPETITIONS:-2}
level_node=$drm_device/power_dpm_force_performance_level

# The refusal names `sudo -v` because the appliance's sudoers grants a global
# timestamp for an hour and this script never prompts: a probe that stopped
# to read a password would hold the device with a terminal open.
if ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
    printf 'a cached root credential is required to write %s; run `sudo -v` first\n' \
        "$level_node" >&2
    exit 2
fi
if ! command -v pgrep >/dev/null 2>&1; then
    printf 'pgrep is required to prove the device is free\n' >&2
    exit 2
fi
if pgrep -x llama-server >/dev/null 2>&1 || pgrep -x llama-bench >/dev/null 2>&1; then
    printf 'a llama process holds the device; tear the appliance down first\n' >&2
    exit 2
fi
for surface in power_dpm_force_performance_level pp_dpm_sclk pp_dpm_mclk pp_dpm_fclk; do
    if [ ! -r "$drm_device/$surface" ]; then
        printf 'drm surface is unreadable: %s\n' "$drm_device/$surface" >&2
        exit 2
    fi
done
if [ -e "$output_directory" ]; then
    printf 'output directory already exists: %s\n' "$output_directory" >&2
    exit 2
fi
if [ ! -x "$bench" ]; then
    printf 'llama-bench is not executable: %s\n' "$bench" >&2
    exit 2
fi
if [ ! -f "$model_path" ]; then
    printf 'model file is absent: %s\n' "$model_path" >&2
    exit 2
fi
if [ ! -r "$radv_icd" ]; then
    printf 'RADV ICD is not readable: %s\n' "$radv_icd" >&2
    exit 2
fi
if [ ! -x "$broker" ]; then
    printf 'telemetry broker is not executable: %s; run build-telemetry-broker.sh\n' \
        "$broker" >&2
    exit 2
fi
if [ ! -r "$validator" ]; then
    printf 'clock sidecar validator is unreadable: %s\n' "$validator" >&2
    exit 2
fi
# The verdict is the validator's, so its counted condition is a startup
# requirement rather than an assumption: a validator without the flag prints
# no counts, every arm reads `not_run`, and an unpinned clock arrives dressed
# as an absent measurement.
if ! python3 "$validator" --help 2>/dev/null | grep -q -- '--required-sclk-mhz'; then
    printf 'clock sidecar validator states no --required-sclk-mhz condition: %s\n' \
        "$validator" >&2
    exit 2
fi

# telemetry-broker.c opens temp1_input and freq1_input from the directory
# --hwmon names, and the record's eighth column carries the delivered graphics
# frequency the validator states the invariant against. A broker launched
# without it writes `unavailable` in both, which refuses the record on its
# temperature column and leaves the invariant counting nothing, so an authority
# that held would be reported as none. The resolution is
# run-raven2-vulkan-kernel-census.sh's own rule -- the first entry under the
# hwmon root whose name attribute reads amdgpu -- and it is a startup
# requirement rather than a per-arm reading.
# The pgrep gate above reads the device once, and this probe then forces a
# performance level and runs a decode of its own across three arms. A workload
# that starts after that reading shares the level the probe wrote and lands in
# the rate the receipt carries, so the shared lease is held from before the
# first level write through the restore. The bench inherits the descriptor,
# which is what makes the exclusion span every arm.
workload_lease=${QWEN_VULKAN_WORKLOAD_LOCK:-"$qwen_home_state/vulkan-workload.lock"}
if ! command -v flock >/dev/null 2>&1; then
    printf 'flock is required to hold the shared Vulkan lease\n' >&2
    exit 2
fi
# `exec` is a special builtin, so a redirection it cannot open ends the shell
# on the redirection's own message; the directory is read here so an absent
# state directory is named the way every other refusal is.
workload_lease_directory=$(dirname -- "$workload_lease")
if [ ! -d "$workload_lease_directory" ]; then
    printf 'the shared lease directory is absent: %s\n' "$workload_lease_directory" >&2
    exit 2
fi
exec 9>"$workload_lease"
if ! flock -n 9; then
    printf 'another Vulkan workload holds the shared lease: %s\n' "$workload_lease" >&2
    exit 2
fi

sidecar_hwmon=''
for hwmon_entry in "$hwmon_root"/*; do
    [ -d "$hwmon_entry" ] || continue
    [ -r "$hwmon_entry/name" ] || continue
    if [ "$(cat "$hwmon_entry/name")" = amdgpu ]; then
        sidecar_hwmon=$hwmon_entry
        break
    fi
done
if [ -z "$sidecar_hwmon" ]; then
    printf 'no amdgpu hwmon directory under %s; the record would carry no temperature and no delivered clock\n' \
        "$hwmon_root" >&2
    exit 2
fi

/usr/bin/renice --priority 19 --pid "$$" >/dev/null 2>&1 || true
harness_nice=$(LC_ALL=C /usr/bin/awk '
    {
        stat_line = $0
        sub(/^.*[)] /, "", stat_line)
        field_count = split(stat_line, fields, /[[:space:]]+/)
        if (field_count >= 17) print fields[17]
        exit
    }
' "/proc/$$/stat" 2>/dev/null || true)
if [ "$harness_nice" != 19 ]; then
    printf 'measurement priority refused: observed=%s\n' \
        "${harness_nice:-unreadable}" >&2
    exit 2
fi
if ! "$ionice_command" -c 3 -p "$$" >/dev/null 2>&1; then
    printf 'measurement I/O priority setup failed for pid %s\n' "$$" >&2
    exit 2
fi

mkdir -p "$output_directory/snapshot"
snapshot_level=$(cat "$level_node")
for surface in power_dpm_force_performance_level pp_dpm_sclk pp_dpm_mclk pp_dpm_fclk; do
    cp "$drm_device/$surface" "$output_directory/snapshot/$surface"
done
bapm_state=$(cat "$bapm_parameter" 2>/dev/null) || bapm_state=unreadable
bapm_state=${bapm_state:-unreadable}

broker_pid=''
bench_pid=''

stop_broker() {
    [ -n "$broker_pid" ] || return 0
    kill -TERM "$broker_pid" 2>/dev/null || true
    wait "$broker_pid" 2>/dev/null || true
    broker_pid=''
}

stop_bench() {
    [ -n "$bench_pid" ] || return 0
    kill -TERM "$bench_pid" 2>/dev/null || true
    wait "$bench_pid" 2>/dev/null || true
    bench_pid=''
}

# The restore is proved rather than requested. A write the SMU declines
# leaves the laptop on a forced level after the probe exits, which is the
# state the trap exists to remove, so the readback decides the printed word.
restore_level() {
    printf '%s\n' "$snapshot_level" | sudo -n tee "$level_node" >/dev/null 2>&1 || true
    restore_observed=$(cat "$level_node" 2>/dev/null) || restore_observed=unreadable
    restore_observed=${restore_observed:-unreadable}
    if [ "$restore_observed" = "$snapshot_level" ]; then
        printf 'dpm_restore=held requested=%s observed=%s\n' \
            "$snapshot_level" "$restore_observed"
    else
        printf 'dpm_restore=violated requested=%s observed=%s\n' \
            "$snapshot_level" "$restore_observed"
    fi
}

cleanup() {
    cleanup_status=$?
    stop_bench
    stop_broker
    restore_level
    exit "$cleanup_status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

selected_step() {
    awk '/\*/ { gsub(/Mhz|MHz|:/, "", $2); print $2; exit }' "$1" 2>/dev/null
}

available_steps() {
    awk 'NF >= 2 { count++ } END { print count + 0 }' "$1" 2>/dev/null
}

maximum_step() {
    awk '{
        value = $2
        gsub(/Mhz|MHz|:/, "", value)
        if (value ~ /^[0-9]+([.][0-9]+)?$/ && value + 0 > best) { best = value + 0 }
    } END { if (best > 0) { printf "%d\n", best } else { print "" } }' "$1" 2>/dev/null
}

# validate-clock-sidecar.py owns the window and the invariant, so the receipt
# reads its lines rather than counting the same rows a second time: the
# `clock_state=` line carries the modal selected clock, its share, the window
# sample count, and the busy mean, and `--required-sclk-mhz` turns the top
# pp_dpm_sclk step into the `clock_invariant=` line's own counts at the
# validator's one-percent tolerance. This function lifts one key off one of
# those lines.
reported_value() {
    awk -v prefix="$2" -v wanted="$3" '
        index($0, prefix) == 1 {
            for (field = 1; field <= NF; field++) {
                if (index($field, wanted) == 1) {
                    print substr($field, length(wanted) + 1)
                    exit
                }
            }
        }' "$1" 2>/dev/null
}

# The one figure the validator reports in a coarser unit than the receipt
# states: its `temp_max_c` is Celsius at one decimal where the row is the
# sensor's own millidegrees, so the peak is read off the record's sixth
# column inside the same window. telemetry-broker.c appends the delivered
# graphics frequency as an eighth column, so both widths carry the same sixth
# column and both are read.
window_thermal_peak() {
    awk -F'\t' -v begin="$2" -v end="$3" '
        $1 ~ /^[0-9]+$/ && (NF == 7 || NF == 8) {
            instant = $1 + 0
            if (instant < begin || instant > end) { next }
            if ($6 != "unavailable") {
                if ($6 + 0 > peak) { peak = $6 + 0 }
                readings++
            }
        }
        END { if (readings) { printf "%d\n", peak } else { print "-" } }
    ' "$1" 2>/dev/null
}

# The bench prints its rows through the markdown writer because the parse
# reads the second-to-last pipe field; -o md is stated rather than defaulted.
decode_rate() {
    awk -F'|' '$0 ~ /\| *tg[0-9]+( @ d[0-9]+)? *\|/ {
                   split($(NF - 1), parts, /[^0-9.]+/)
                   for (part = 1; part <= 3; part++) {
                       if (parts[part] != "") { rate = parts[part]; break }
                   }
                   matched++
               }
               END {
                   if (matched == 1 && rate != "") { print rate }
                   else { print "-" }
               }' "$1"
}

mark_instant() {
    awk -v name="$2" '
        $0 ~ /^# mark / {
            marked = ""
            instant = ""
            for (field = 1; field <= NF; field++) {
                if ($field ~ /^name=/) { marked = substr($field, 6) }
                if ($field ~ /^monotonic_ns=/) { instant = substr($field, 14) }
            }
            if (marked == name && instant != "") { print instant; exit }
        }' "$1" 2>/dev/null
}

dpm_channel_period() {
    awk '$0 ~ /^# sample_rates:/ {
            for (field = 1; field <= NF; field++) {
                if ($field ~ /^pp_dpm_period_ns=/) { print substr($field, 18); exit }
            }
        }' "$1" 2>/dev/null
}

held_authority=''
summary_lines=$output_directory/summary.txt
: >"$summary_lines"

receipt_row() {
    printf '%s\t%s\n' "$1" "$2" >>"$receipt"
}

run_level() {
    arm_id=$1
    arm_level=$2
    arm_directory=$output_directory/$arm_id-$arm_level
    mkdir -p "$arm_directory"
    receipt=$arm_directory/dpm-receipt.tsv
    : >"$receipt"
    record=$arm_directory/clock-sidecar.tsv
    control_fifo=$arm_directory/broker-control
    bench_log=$arm_directory/bench.log

    write_status=0
    printf '%s\n' "$arm_level" | sudo -n tee "$level_node" \
        >/dev/null 2>"$arm_directory/level-write.err" || write_status=$?
    observed_level=$(cat "$level_node" 2>/dev/null) || observed_level=unreadable
    observed_level=${observed_level:-unreadable}

    # A level the SMU declines is a property of the firmware rather than a
    # harness failure, and profile_peak is the level this part is most
    # likely to decline, so its refusal is recorded and the chain continues.
    # auto and high are the levels the regime question rests on, so a
    # refused write or a readback that disagrees with the request ends the
    # probe rather than producing a receipt for a level that never applied.
    if [ "$write_status" -ne 0 ] || [ "$observed_level" != "$arm_level" ]; then
        if [ "$arm_level" = profile_peak ]; then
            level_error=$(tr '\n' ' ' <"$arm_directory/level-write.err")
            level_error=${level_error:-readback=$observed_level}
            receipt_row requested_performance_level "$arm_level"
            receipt_row observed_performance_level "$observed_level"
            receipt_row available_sclk_levels "$(available_steps "$drm_device/pp_dpm_sclk")"
            receipt_row max_sclk_mhz "$(maximum_step "$drm_device/pp_dpm_sclk")"
            for absent_row in selected_sclk_before selected_sclk_during \
                selected_sclk_after samples_in_window samples_at_max \
                samples_below_max below_max_fraction thermal_peak_millic \
                gpu_busy_mean tok_s; do
                receipt_row "$absent_row" -
            done
            receipt_row clock_invariant unsupported
            receipt_row sclk_share -
            receipt_row pp_dpm_period_ns -
            receipt_row window_begin_ns -
            receipt_row window_end_ns -
            receipt_row sidecar_verdict not_run
            receipt_row bench_status not_run
            printf 'dpm_level=unsupported requested=%s observed=%s error=%s\n' \
                "$arm_level" "$observed_level" "$level_error" | tee -a "$summary_lines"
            printf 'dpm_level=%s observed=%s sclk_during=- below_max_fraction=- tok_s=- clock_invariant=unsupported\n' \
                "$arm_level" "$observed_level" | tee -a "$summary_lines"
            return 0
        fi
        printf 'performance level did not take: asked %s, node reads %s\n' \
            "$arm_level" "$observed_level" >&2
        return 1
    fi

    sclk_before=$(selected_step "$drm_device/pp_dpm_sclk")
    sclk_before=${sclk_before:--}
    # The top step is what the invariant is stated against, so a surface that
    # names none ends the probe rather than producing arms whose verdict
    # would read `not_run` for a reason no receipt row records.
    sclk_ceiling=$(maximum_step "$drm_device/pp_dpm_sclk")
    case $sclk_ceiling in
        '' | *[!0-9]*)
            printf 'pp_dpm_sclk names no numeric top step: %s\n' \
                "${sclk_ceiling:-empty}" >&2
            return 1
            ;;
    esac

    rm -f "$control_fifo"
    mkfifo "$control_fifo"
    # nice 19 is the broker's own constant, so the launch names the period,
    # the cores, the surfaces, and the control FIFO alone.
    "$broker" "$record" \
        --period-ms "$sidecar_period_ms" --cpu "$sidecar_cpu" \
        --drm-device "$drm_device" --hwmon "$sidecar_hwmon" \
        --control "$control_fifo" \
        2>"$arm_directory/clock-sidecar.stderr" &
    broker_pid=$!
    # The record is formatted at drain, so the readiness line on stderr is
    # what proves every surface is open and the termination handler is
    # installed. A bench started ahead of it measures the wrong span.
    broker_ready=0
    broker_attempt=0
    while [ "$broker_attempt" -lt 200 ]; do
        if grep -q '^telemetry_broker=ready ' \
            "$arm_directory/clock-sidecar.stderr" 2>/dev/null; then
            broker_ready=1
            break
        fi
        broker_attempt=$((broker_attempt + 1))
        sleep 0.05
    done
    if [ "$broker_ready" -eq 0 ]; then
        stop_broker
        printf 'telemetry broker never reached readiness for level %s\n' \
            "$arm_level" >&2
        return 1
    fi

    printf 'MARK bench_start\n' >"$control_fifo"
    # The bench runs as a background job under wait, so a terminating signal
    # reaches this script while the decode is live rather than after it.
    set +e
    census_arm_exec "$arm_directory/arm-environment.tsv" \
        VK_DRIVER_FILES="$radv_icd" VK_ICD_FILENAMES="$radv_icd" \
        LLAMA_NO_CPU_FALLBACK=1 \
        -- \
        "$bench" -m "$model_path" -p 0 -n "$generate_tokens" -r "$repetitions" \
        -ngl 99 -t 2 -o md >"$bench_log" 2>&1 &
    bench_pid=$!
    wait "$bench_pid"
    bench_status=$?
    set -e
    bench_pid=''
    printf 'MARK bench_end\n' >"$control_fifo"
    # The broker reads its control FIFO inside the same poll loop a
    # terminating signal ends, so a mark written in the same instant as the
    # signal is lost; the first appliance run recorded bench_start alone.
    # Three sample periods pass before the stop so the loop has taken the
    # line.
    sleep 0.3
    stop_broker

    sclk_after=$(selected_step "$drm_device/pp_dpm_sclk")
    sclk_after=${sclk_after:--}
    window_begin=$(mark_instant "$record" bench_start)
    window_end=$(mark_instant "$record" bench_end)
    channel_period=$(dpm_channel_period "$record")
    channel_period=${channel_period:--}
    tokens_per_second=$(decode_rate "$bench_log")

    sidecar_verdict=not_run
    sclk_share=-
    sclk_during=-
    samples_in_window=0
    samples_at_max=-
    samples_below_max=-
    below_max_fraction=-
    busy_mean=-
    reported_invariant=not_run
    thermal_peak=-
    # Every arm asks for the top step, `auto` included, because the counts are
    # what state how far that governor drifts; the receipt then reports
    # `not_requested` for D0, since a governor asked for nothing cannot
    # violate a policy. The validator files an invariant violation among its
    # own failures, so the structural verdict here is taken over the failures
    # that remain once `clock_invariant` is removed from the list.
    if [ -n "$window_begin" ] && [ -n "$window_end" ] && [ -n "$sclk_ceiling" ]; then
        set +e
        python3 "$validator" "$record" \
            --sidecar-status 0 --period-ms "$sidecar_period_ms" \
            --period-tolerance 0.25 --cost-bound-ns 1000000 \
            --window-begin-ns "$window_begin" --window-end-ns "$window_end" \
            --required-sclk-mhz "$sclk_ceiling" \
            --expected-nice 19 --expected-cpu-affinity "$sidecar_cpu" \
            >"$arm_directory/clock-state.txt" 2>&1
        set -e
        residual_failures=$(reported_value "$arm_directory/clock-state.txt" \
            clock_sidecar= failures= |
            tr ',' '\n' | grep -v '^clock_invariant$' | grep -v '^-$' | tr '\n' ',')
        if [ -z "$residual_failures" ]; then
            sidecar_verdict=accepted
        else
            sidecar_verdict=refused
        fi
        sclk_during=$(reported_value "$arm_directory/clock-state.txt" \
            clock_state= sclk_mode_mhz=)
        sclk_share=$(reported_value "$arm_directory/clock-state.txt" \
            clock_state= sclk_share=)
        samples_in_window=$(reported_value "$arm_directory/clock-state.txt" \
            clock_state= window_samples=)
        busy_mean=$(reported_value "$arm_directory/clock-state.txt" \
            clock_state= busy_mean=)
        samples_at_max=$(reported_value "$arm_directory/clock-state.txt" \
            clock_invariant= samples_at_required=)
        samples_below_max=$(reported_value "$arm_directory/clock-state.txt" \
            clock_invariant= samples_below_required=)
        below_max_fraction=$(reported_value "$arm_directory/clock-state.txt" \
            clock_invariant= below_required_fraction=)
        reported_invariant=$(awk 'index($0, "clock_invariant=") == 1 {
                print substr($1, 17); exit
            }' "$arm_directory/clock-state.txt")
        thermal_peak=$(window_thermal_peak "$record" "$window_begin" "$window_end")
        sclk_during=${sclk_during:--}
        sclk_share=${sclk_share:--}
        samples_in_window=${samples_in_window:-0}
        busy_mean=${busy_mean:--}
        samples_at_max=${samples_at_max:--}
        samples_below_max=${samples_below_max:--}
        below_max_fraction=${below_max_fraction:--}
        reported_invariant=${reported_invariant:-not_run}
        thermal_peak=${thermal_peak:--}
    fi

    # `held` is stated against a real decode alone. A bench that failed or
    # printed a row for a token count other than the requested one carries no
    # rate, and a window the record places no readable clock step in carries
    # no count, so both read `not_run` rather than inheriting a verdict.
    if [ "$arm_level" = auto ]; then
        clock_invariant=not_requested
    elif [ "$bench_status" -ne 0 ] || [ "$tokens_per_second" = - ] ||
        [ "$samples_below_max" = - ] || [ "$samples_at_max" = - ] ||
        [ "$((samples_at_max + samples_below_max))" -eq 0 ]; then
        clock_invariant=not_run
    else
        clock_invariant=$reported_invariant
        # An authority is named from a record the validator accepts. The
        # invariant is counted over the samples the record holds, so a record
        # refused for coverage, period, cost, or a sensor carries a held
        # invariant over a window it only partly describes; the receipt keeps
        # both readings and the campaign-facing name requires the pair.
        if [ "$clock_invariant" = held ] && [ "$sidecar_verdict" = accepted ] &&
            [ -z "$held_authority" ]; then
            held_authority=$arm_level
        fi
    fi

    receipt_row requested_performance_level "$arm_level"
    receipt_row observed_performance_level "$observed_level"
    receipt_row available_sclk_levels "$(available_steps "$drm_device/pp_dpm_sclk")"
    receipt_row max_sclk_mhz "${sclk_ceiling:--}"
    receipt_row selected_sclk_before "$sclk_before"
    receipt_row selected_sclk_during "$sclk_during"
    receipt_row selected_sclk_after "$sclk_after"
    receipt_row samples_in_window "$samples_in_window"
    receipt_row samples_at_max "$samples_at_max"
    receipt_row samples_below_max "$samples_below_max"
    receipt_row below_max_fraction "$below_max_fraction"
    receipt_row thermal_peak_millic "$thermal_peak"
    receipt_row gpu_busy_mean "$busy_mean"
    receipt_row tok_s "$tokens_per_second"
    receipt_row clock_invariant "$clock_invariant"
    receipt_row sclk_share "$sclk_share"
    receipt_row pp_dpm_period_ns "$channel_period"
    receipt_row window_begin_ns "${window_begin:--}"
    receipt_row window_end_ns "${window_end:--}"
    receipt_row sidecar_verdict "$sidecar_verdict"
    receipt_row bench_status "$bench_status"

    printf 'dpm_level=%s observed=%s sclk_during=%s below_max_fraction=%s tok_s=%s clock_invariant=%s\n' \
        "$arm_level" "$observed_level" "$sclk_during" "$below_max_fraction" \
        "$tokens_per_second" "$clock_invariant" | tee -a "$summary_lines"
    return 0
}

run_level D0 auto
run_level D1 high
run_level D2 profile_peak

# `high` wins the naming where both hold, because it leaves clock and power
# gating in place where profile_peak disables both, so a campaign running
# under it measures a machine closer to the served one.
printf 'dpm_authority=%s bapm=%s\n' "${held_authority:-none}" "$bapm_state" |
    tee -a "$summary_lines"
