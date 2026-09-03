#!/bin/sh
set -eu

# Drive the telemetry broker against a fixture sysfs tree and read the record
# it drains with validate-clock-sidecar.py, the same reader a census arm uses.
#
# The fixture reproduces the SMU10 surfaces the appliance carries: pp_dpm_sclk
# and pp_dpm_mclk print one starred step, gpu_busy_percent and temp1_input
# print one integer, and pp_dpm_fclk is empty, which is the column the
# invocation names in --allow-unavailable. A resolved hwmon directory is
# mandatory here, since temp1_millidegrees sits outside that allowance and an
# absent sensor would refuse every row.
#
# The window and the pause. validate-clock-sidecar.py refuses an over-bound gap
# anywhere in a record supplied with no window, and a 100 ms pause is such a
# gap by construction. The test therefore reads REQUEST_START and REQUEST_END
# out of the record's own mark lines and passes them as
# --window-begin-ns/--window-end-ns, and it orders the commands so the pause
# closes before REQUEST_START. The pause gap then fails the validator's overlap
# test, `instants[i+1] > begin and instants[i] < end`, on its own timestamps
# rather than on the caller's wall clock, while window_coverage holds because
# the window is interior to the run.
#
# The achieved period the footer declares is the run mean over the sample span,
# which the pause widens: achieved ~= period x total / (total - paused). The
# 1.9 s run pauses for 0.1 s, so achieved lands near 10.5 ms against the 10 ms
# requested and the 12.5 ms ceiling admits 30 lost samples out of the nominal
# 190, which is the margin the host's preemption spends.
#
# --max-gap-ns takes the validator's stall bound of ten requested periods and
# --max-lost-fraction takes the coverage bound. The appliance contract is 0.02,
# which this workstation cannot hold and this test does not claim: the sampler
# runs at the constant nice 19 against a load average near 45 across twelve
# cores, where the appliance runs it against two cores carrying one server, and
# the appliance itself measures 0.0122 to 0.0147. The bound here is the
# workstation value QWEN_TEST_MAX_LOST_FRACTION names, the observed fraction
# prints on its own line, and the coverage claim belongs to an appliance run.
#
# A validator refusal naming only `gaps`, `achieved_period`, or `window_lost`
# repeats the arm up to three times and reports the attempt it accepted on. All
# three count samples the host withheld rather than anything the broker chose,
# and they move together. A refusal naming any other condition is a property of
# the broker and ends the test on its first occurrence.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

checks=0
failures=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
    if [ "$2" != "accepted" ]; then
        failures=$((failures + 1))
    fi
}

verdict() {
    if [ "$1" = "$2" ]; then
        report "$3" accepted
    else
        report "$3" "refused expected=$1 observed=$2"
    fi
}

finish() {
    if [ "$failures" -eq 0 ]; then
        printf 'telemetry_broker_test=accepted checks=%d failures=0\n' "$checks"
        exit 0
    fi
    printf 'telemetry_broker_test=refused checks=%d failures=%d\n' "$checks" "$failures"
    exit 1
}

# Build

broker=$work_directory/telemetry-broker
if sh "$script_directory/build-telemetry-broker.sh" "$broker" >"$work_directory/build.log" 2>&1; then
    report build accepted
else
    cat "$work_directory/build.log" >&2
    report build refused
    finish
fi

# Fixture

drm_device=$work_directory/drm
hwmon=$work_directory/hwmon
mkdir -p "$drm_device" "$hwmon"
printf '0: 200Mhz\n1: 400Mhz *\n2: 1100Mhz\n' >"$drm_device/pp_dpm_sclk"
printf '0: 400Mhz\n1: 933Mhz *\n2: 1067Mhz\n' >"$drm_device/pp_dpm_mclk"
: >"$drm_device/pp_dpm_fclk"
printf '17\n' >"$drm_device/gpu_busy_percent"
printf 'amdgpu\n' >"$hwmon/name"
printf '62000\n' >"$hwmon/temp1_input"
# The delivered graphics frequency, in the hertz the amdgpu hwmon path reports:
# 1100 MHz, which the broker normalizes into the sclk_actual_mhz column beside
# the selected step the fixture stars at 400 MHz, so the two columns are read
# apart rather than assumed equal.
printf '1100000000\n' >"$hwmon/freq1_input"

cpu_count=$(nproc 2>/dev/null || echo 1)
cpu_list=0
cpu_index=1
while [ "$cpu_index" -lt "$cpu_count" ]; do
    cpu_list="$cpu_list,$cpu_index"
    cpu_index=$((cpu_index + 1))
done

# The workstation coverage bound sits above the appliance contract of 0.02
# because the sampler holds nice 19 against every other tenant of this host.
# Six arms measured 0.0000 five times and 0.0570 once, so 0.05 admits the
# quiet runs and sends the host's tail through the retry loop.
max_lost_fraction=${QWEN_TEST_MAX_LOST_FRACTION:-0.05}

mark_instant() {
    awk -v want="name=$2" \
        '$1 == "#" && $2 == "mark" && $3 == want { print substr($4, index($4, "=") + 1); exit }' \
        "$1"
}

# One arm: launch, command through the FIFO, terminate, validate.

run_arm() {
    arm_record=$1
    arm_control=$work_directory/control-$2.fifo
    arm_stderr=$work_directory/broker-$2.err
    arm_validation=$work_directory/validate-$2.log

    mkfifo "$arm_control"
    "$broker" "$arm_record" --period-ms 10 --cpu "$cpu_list" \
        --drm-device "$drm_device" --hwmon "$hwmon" --control "$arm_control" \
        >/dev/null 2>"$arm_stderr" &
    arm_pid=$!

    # The record is written at drain, so readiness is proven from the line the
    # broker prints once every descriptor is open and the handler is installed.
    arm_ready=refused
    arm_attempt=0
    while [ "$arm_attempt" -lt 100 ]; do
        if grep -q '^telemetry_broker=ready ' "$arm_stderr" 2>/dev/null; then
            arm_ready=accepted
            break
        fi
        arm_attempt=$((arm_attempt + 1))
        sleep 0.05
    done
    if [ "$arm_ready" != accepted ]; then
        kill -TERM "$arm_pid" 2>/dev/null || true
        wait "$arm_pid" 2>/dev/null || true
        arm_status=1
        return 0
    fi

    sleep 0.4
    printf 'MARK ARM_START\n' >"$arm_control"
    sleep 0.2
    printf 'PAUSE\n' >"$arm_control"
    sleep 0.1
    printf 'RESUME\n' >"$arm_control"
    sleep 0.1
    printf 'MARK REQUEST_START\n' >"$arm_control"
    sleep 0.8
    printf 'MARK REQUEST_END\n' >"$arm_control"
    sleep 0.2
    printf 'MARK ARM_END\n' >"$arm_control"
    sleep 0.1

    kill -TERM "$arm_pid"
    arm_status=0
    wait "$arm_pid" || arm_status=$?
    if [ "$arm_status" -ne 0 ] || [ ! -s "$arm_record" ]; then
        return 0
    fi

    arm_begin=$(mark_instant "$arm_record" REQUEST_START)
    arm_end=$(mark_instant "$arm_record" REQUEST_END)
    if [ -z "$arm_begin" ] || [ -z "$arm_end" ]; then
        arm_validation_status=1
        return 0
    fi

    arm_validation_status=0
    python3 "$script_directory/validate-clock-sidecar.py" "$arm_record" \
        --sidecar-status "$arm_status" \
        --period-ms 10 \
        --period-tolerance 0.25 \
        --cost-bound-ns 1000000 \
        --max-gap-ns 100000000 \
        --max-lost-fraction "$max_lost_fraction" \
        --window-begin-ns "$arm_begin" \
        --window-end-ns "$arm_end" \
        --allow-unavailable pp_dpm_fclk_surface_mhz \
        >"$arm_validation" 2>&1 || arm_validation_status=$?
}

# A refusal is retriable where every condition it names counts samples the host
# withheld: `gaps` reads the adjacent holes, `window_lost` reads the window time
# inside them, and `achieved_period` reads the mean over the same holes.
retriable_refusal() {
    [ -s "$1" ] || return 1
    refused_names=$(awk -F'failures=' '/^clock_sidecar=refused/ { print $2 }' "$1")
    [ -n "$refused_names" ] || return 1
    remainder=$(printf '%s' "$refused_names" | tr ',' '\n' \
        | grep -vxE 'gaps|window_lost|achieved_period' || true)
    [ -z "$remainder" ]
}

record=""
validation_log=""
broker_status=1
validation_status=1
attempt=1
attempts_run=0
while [ "$attempt" -le 3 ]; do
    record=$work_directory/record-$attempt.tsv
    validation_log=$work_directory/validate-$attempt.log
    arm_status=1
    arm_validation_status=1
    run_arm "$record" "$attempt"
    broker_status=$arm_status
    validation_status=$arm_validation_status
    attempts_run=$attempt
    if [ "$validation_status" -eq 0 ]; then
        break
    fi
    if ! retriable_refusal "$validation_log"; then
        break
    fi
    attempt=$((attempt + 1))
done
printf 'observation validated_attempt=%d attempts_run=%d\n' "$attempts_run" "$attempts_run"

verdict 0 "$broker_status" broker_exit
if [ ! -s "$record" ]; then
    report record_written refused
    cat "$work_directory/broker-$attempts_run.err" >&2
    finish
fi
report record_written accepted

# Marks

marks_present=accepted
for mark_name in ARM_START PAUSE RESUME REQUEST_START REQUEST_END ARM_END; do
    if [ -z "$(mark_instant "$record" "$mark_name")" ]; then
        marks_present="refused missing=$mark_name"
    fi
done
report marks_present "$marks_present"

pause_ns=$(mark_instant "$record" PAUSE)
resume_ns=$(mark_instant "$record" RESUME)
if [ -z "$pause_ns" ] || [ -z "$resume_ns" ]; then
    finish
fi

mark_order=$(awk '$1 == "#" && $2 == "mark" { split($3, field, "="); printf "%s ", field[2] }' "$record")
verdict "ARM_START PAUSE RESUME REQUEST_START REQUEST_END ARM_END " "$mark_order" mark_order

# The paused span carries no samples

paused_rows=$(awk -F'\t' -v begin="$pause_ns" -v end="$resume_ns" '
    /^#/ { next }
    $1 ~ /^[0-9]+$/ && $1 + 0 > begin && $1 + 0 < end { rows++ }
    END { print rows + 0 }' "$record")
verdict 0 "$paused_rows" paused_span_empty

# One adjacent gap brackets the PAUSE and RESUME marks and holds at least 0.8
# of the 100 ms commanded, so the wait lasted what it was asked to last. The
# bracketing is the identity test and a preemption cannot satisfy it, since a
# gap that contains both marks is the wait itself. The widest gap and the count
# above two requested periods are observations rather than verdicts, because a
# gap outside the request window belongs to the host's scheduler and
# validate-clock-sidecar.py measures the coverage inside the window.
gap_summary=$(awk -F'\t' -v begin="$pause_ns" -v end="$resume_ns" -v bound=20000000 '
    /^#/ { next }
    $1 ~ /^[0-9]+$/ {
        if (previous != "") {
            gap = $1 - previous
            if (gap > widest) { widest = gap }
            if (gap > bound) { over++ }
            if (previous <= begin && $1 >= end) { spanning = gap }
        }
        previous = $1
    }
    END { printf "%d %d %d\n", over + 0, spanning + 0, widest + 0 }' "$record")
over_bound_gaps=$(printf '%s\n' "$gap_summary" | cut -d ' ' -f 1)
spanning_gap_ns=$(printf '%s\n' "$gap_summary" | cut -d ' ' -f 2)
widest_gap_ns=$(printf '%s\n' "$gap_summary" | cut -d ' ' -f 3)
if [ "$spanning_gap_ns" -ge 80000000 ]; then
    report pause_gap_width accepted
else
    report pause_gap_width "refused gap_ns=$spanning_gap_ns"
fi
printf 'observation pause_gap_ns=%s commanded_ns=100000000 widest_gap_ns=%s gaps_over_2_periods=%s\n' \
    "$spanning_gap_ns" "$widest_gap_ns" "$over_bound_gaps"

# The slow-rate readings

meminfo_lines=$(grep -c '^# meminfo ' "$record" || true)
if [ "$meminfo_lines" -ge 2 ]; then
    report meminfo_lines accepted
else
    report meminfo_lines "refused lines=$meminfo_lines"
fi

# The host channel shares the hundredth period, so a 1.9 s arm at 10 ms carries
# its own readings beside the meminfo lines. The instant is an integer, load1
# is the decimal /proc/loadavg opens on, and pages_sharing is an integer where
# the kernel carries KSM and `unavailable` where it does not.
host_lines=$(grep -c '^# host ' "$record" || true)
if [ "$host_lines" -ge 1 ]; then
    report host_lines accepted
else
    report host_lines "refused lines=$host_lines"
fi
host_shape=$(awk '$1 == "#" && $2 == "host" {
        split($3, instant, "="); split($4, load, "="); split($5, sharing, "=")
        if (instant[1] != "monotonic_ns" || instant[2] !~ /^[0-9]+$/) { bad++; next }
        if (load[1] != "load1" || load[2] !~ /^([0-9]+\.[0-9]+|unavailable)$/) { bad++; next }
        if (sharing[1] != "ksm_pages_sharing" || sharing[2] !~ /^([0-9]+|unavailable)$/) { bad++; next }
        if (NF != 5) { bad++ }
    }
    END { print bad + 0 }' "$record")
verdict 0 "$host_shape" host_line_shape
printf 'observation host_lines=%s first=%s\n' "$host_lines" \
    "$(grep -m 1 '^# host ' "$record" | cut -d ' ' -f 4-)"

unavailable_temperature=$(awk -F'\t' '
    /^#/ { next }
    $1 ~ /^[0-9]+$/ && $6 == "unavailable" { rows++ }
    END { print rows + 0 }' "$record")
verdict 0 "$unavailable_temperature" temperature_in_every_row

# The DPM columns follow the same repeat rule on the same tenth-period channel,
# so the nine rows between two reads carry the last selected step rather than an
# unavailable. pp_dpm_fclk stays out of it: the fixture leaves that file empty,
# which is the surface the SMU10 path reports empty and the invocation allows.
unavailable_dpm=$(awk -F'\t' '
    /^#/ { next }
    $1 ~ /^[0-9]+$/ && ($2 == "unavailable" || $3 == "unavailable") { rows++ }
    END { print rows + 0 }' "$record")
verdict 0 "$unavailable_dpm" dpm_repeat_in_every_row
distinct_sclk=$(awk -F'\t' '/^#/ { next } $1 ~ /^[0-9]+$/ { print $2 }' "$record" | \
    sort -u | tr '\n' ',')
printf 'observation sclk_values=%s\n' "$distinct_sclk"

# The eighth column is the delivered graphics frequency, read from hwmon
# freq1_input on the DPM channel and normalized from hertz to megahertz. The
# fixture reports 1.1 GHz while the selected step stars 400 MHz, so a row
# carrying 1100 in the eighth column and 400 in the second proves the column is
# the sensor rather than a copy of the step.
column_line=$(awk '/^#/ { next } { print; exit }' "$record")
if [ "$column_line" = "$(printf 'monotonic_ns\tpp_dpm_sclk_selected_mhz\tpp_dpm_mclk_surface_mhz\tpp_dpm_fclk_surface_mhz\tgpu_busy_percent\ttemp1_millidegrees\tsample_cost_ns\tsclk_actual_mhz')" ]; then
    report record_columns accepted
else
    report record_columns "refused columns=$column_line"
fi
actual_rows=$(awk -F'\t' '
    /^#/ { next }
    $1 ~ /^[0-9]+$/ && NF == 8 && $8 == "1100" && $2 == "400" { rows++ }
    END { print rows + 0 }' "$record")
total_rows=$(awk -F'\t' '/^#/ { next } $1 ~ /^[0-9]+$/ { rows++ } END { print rows + 0 }' \
    "$record")
verdict "$total_rows" "$actual_rows" sclk_actual_in_every_row

# The record is evidence

sed 's/^/    /' "$validation_log"
verdict 0 "$validation_status" clock_sidecar_accepted
observed_lost_fraction=$(awk '/^gaps_in_window=/ {
    for (field = 1; field <= NF; field++) {
        if (index($field, "window_lost_fraction=") == 1) {
            print substr($field, index($field, "=") + 1)
        }
    } }' "$validation_log")
printf 'observation window_lost_fraction=%s workstation_bound=%s appliance_contract=0.02\n' \
    "${observed_lost_fraction:--}" "$max_lost_fraction"

# The fast path holds its target

footer_field() {
    awk -v want="$2=" '/^# samples=/ {
        for (field = 1; field <= NF; field++) {
            if (index($field, want) == 1) { print substr($field, index($field, "=") + 1) }
        }
    }' "$1"
}
mean_cost_ns=$(footer_field "$record" mean_sample_cost_ns)
max_cost_ns=$(footer_field "$record" max_sample_cost_ns)
if [ "$mean_cost_ns" -lt 50000 ]; then
    report mean_sample_cost accepted
else
    report mean_sample_cost "refused mean_ns=$mean_cost_ns target_ns=50000"
fi
printf 'observation mean_sample_cost_ns=%s max_sample_cost_ns=%s\n' \
    "$mean_cost_ns" "$max_cost_ns"
grep '^telemetry_broker=drained ' "$work_directory/broker-$attempts_run.err" | \
    sed 's/^/observation /'

# The absolute nice level

# setpriority takes the level rather than a delta, so a broker started from a
# shell at nice 5 reaches 19 and its header says so. The measured arm cannot
# show this, since it starts from a nice 0 shell where a relative
# implementation would land at 19 as well.
nice_record=$work_directory/record-nice.tsv
nice -n 5 "$broker" "$nice_record" --period-ms 10 \
    --drm-device "$drm_device" --hwmon "$hwmon" \
    >/dev/null 2>"$work_directory/broker-nice.err" &
nice_pid=$!
sleep 0.5
kill -TERM "$nice_pid"
nice_status=0
wait "$nice_pid" || nice_status=$?
verdict 0 "$nice_status" absolute_nice_exit
nice_header=$(awk '/^# sampler_pid=/ {
    for (field = 1; field <= NF; field++) {
        if (index($field, "nice=") == 1) { print substr($field, 6) }
    } }' "$nice_record" 2>/dev/null || true)
verdict 19 "$nice_header" absolute_nice_reached

# mark_before_term_is_kept: a MARK line written to the control FIFO with no
# sleep before the TERM that follows it must still reach the drained record.
# clock_nanosleep returns EINTR on the signal and stop_requested breaks the
# sample loop before its next scheduled drain_control call, so the fix under
# test is the one final non-blocking drain ahead of write_record. Ten arms
# with no sleep between MARK and TERM are what a race surviving at one in ten
# would show; a single arm cannot distinguish the fix from luck.

mark_race_failures=0
mark_race_attempt=1
while [ "$mark_race_attempt" -le 10 ]; do
    race_control=$work_directory/race-control-$mark_race_attempt.fifo
    race_record=$work_directory/race-record-$mark_race_attempt.tsv
    race_stderr=$work_directory/race-broker-$mark_race_attempt.err

    mkfifo "$race_control"
    "$broker" "$race_record" --period-ms 10 --cpu "$cpu_list" \
        --drm-device "$drm_device" --hwmon "$hwmon" --control "$race_control" \
        >/dev/null 2>"$race_stderr" &
    race_pid=$!

    race_ready=refused
    race_wait_attempt=0
    while [ "$race_wait_attempt" -lt 100 ]; do
        if grep -q '^telemetry_broker=ready ' "$race_stderr" 2>/dev/null; then
            race_ready=accepted
            break
        fi
        race_wait_attempt=$((race_wait_attempt + 1))
        sleep 0.05
    done
    if [ "$race_ready" != accepted ]; then
        kill -TERM "$race_pid" 2>/dev/null || true
        wait "$race_pid" 2>/dev/null || true
        mark_race_failures=$((mark_race_failures + 1))
        mark_race_attempt=$((mark_race_attempt + 1))
        continue
    fi

    printf 'MARK RACE_MARK\n' >"$race_control"
    kill -TERM "$race_pid"
    race_status=0
    wait "$race_pid" || race_status=$?

    if [ "$race_status" -ne 0 ] || [ ! -s "$race_record" ] || \
        [ -z "$(mark_instant "$race_record" RACE_MARK)" ]; then
        mark_race_failures=$((mark_race_failures + 1))
    fi

    mark_race_attempt=$((mark_race_attempt + 1))
done
verdict 0 "$mark_race_failures" mark_before_term_is_kept
printf 'observation mark_before_term_arms=10 failures=%d\n' "$mark_race_failures"

finish
