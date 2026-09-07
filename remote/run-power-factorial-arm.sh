#!/bin/sh
set -eu

# One arm of the coupled power/CPU/clock factorial campaign, run as the
# command of one compute-state-lease.sh transaction.
#
# The lease has already applied the arm's clock pin, memory-scanner state,
# process priority, and (where the profile names one) CPU frequency cap and
# package budget, and has already proven the delivered clock, before this
# script starts. Its own work is the instrument beyond what
# run-power-envelope-arm.sh already retains: the CPU-side evidence
# evidence/power-factorial/README.md's falsifiers read against --
# `cpupower frequency-info` at both ends of the arm, a per-core cpufreq
# sampler read from /proc/cpuinfo, and the roommate's QEMU guest and ksmd
# tick counts from /proc at both ends. run-power-envelope-arm.sh remains the
# instrument for everything a package-power arm already measures: the served
# decode rate, the energy window, the clock sidecar, the temperature record,
# and (where the launch chain armed one) the retained graphics-latency.log.
# This script wraps that one call rather than re-deriving its own served-decode
# invocation, so the two campaigns read one arm-summary schema apart from the
# fields this script adds.
#
# The restoration verification table is not this script's to retain: it is
# compute-state-lease.sh's own `restoration=held`/`restoration=failed` line,
# printed to the transaction's own stdout/stderr, which
# run-power-factorial-campaign.sh already redirects to
# `arms/ARM_NAME.lease.std{out,err}` beside this script's own arm directory.
# remote/summarize-power-factorial.py reads it from there.
#
# The nice factor-pair's alternate rung cannot run through the served harness
# at nice 19 at all: measure-served-decode.sh launches through qwen-launch.sh,
# which starts monitor-qwen-runtime.sh, which unconditionally renices itself
# to 0 and exits `reason=monitor_exited` where it cannot -- lowering a nice
# level needs CAP_SYS_NICE this transaction's unprivileged child does not
# hold. `QWEN_POWER_FACTORIAL_INSTRUMENT=bench` is the scope cut
# evidence/power-factorial/README.md registers ahead of any run: that one rung
# is measured with llama-bench directly instead, outside the guarded launch
# chain, the same substitution
# evidence/raven2-vulkan-kernel-census/dpm-authority/'s own nice-probe makes.
# A bench arm carries no served energy window, clock sidecar, or temperature
# record from run-power-envelope-arm.sh; it carries only the CPU-side
# instrumentation this script itself adds plus llama-bench's own decode rate,
# so the nice comparison reads two different measurement methodologies rather
# than one, and the README states that as the pair's own falsifier rather than
# hiding it.

usage() {
    printf 'usage: %s CAMPAIGN_DIRECTORY ARM_NAME MODEL_ID\n' "$0" >&2
    exit 2
}

if [ "$#" -ne 3 ]; then
    usage
fi

campaign_directory=$1
arm_name=$2
model_id=$3
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
power_envelope_arm=${QWEN_POWER_ENVELOPE_ARM:-$script_directory/run-power-envelope-arm.sh}
registry_reader=$script_directory/model-registry.sh
models_directory=${QWEN_MODELS_DIRECTORY:-"$qwen_home_models"}
llama_bench=${QWEN_LLAMA_BENCH:-"$qwen_home_llama_bench"}
bench_generate=${QWEN_BENCH_GENERATE:-64}
cpupower_command=${QWEN_CPUPOWER:-cpupower}
cpu_list=${QWEN_POWER_FACTORIAL_CPU_LIST:-0 1}
cpuinfo_period_ms=${QWEN_POWER_FACTORIAL_CPUINFO_PERIOD_MS:-200}
arm_directory=$campaign_directory/arms/$arm_name
instrument=${QWEN_POWER_FACTORIAL_INSTRUMENT:-served}

case $instrument in
    served | bench) ;;
    *)
        printf 'reason=instrument_unknown value=%s; served or bench\n' "$instrument" >&2
        exit 2
        ;;
esac

compute_state_profile=${QWEN_COMPUTE_STATE_PROFILE:-}
if [ -z "$compute_state_profile" ]; then
    printf 'reason=compute_state_profile_absent; this arm runs as the command of compute-state-lease.sh\n' >&2
    exit 2
fi
if [ -z "${QWEN_VULKAN_EXTERNAL_LEASE_PROOF:-}" ]; then
    printf 'reason=lease_proof_absent; the transaction forwards it into the arm environment\n' >&2
    exit 2
fi
if [ "$instrument" = served ] && [ ! -x "$power_envelope_arm" ]; then
    printf 'reason=power_envelope_arm_absent path=%s\n' "$power_envelope_arm" >&2
    exit 2
fi
if [ "$instrument" = bench ] && [ ! -x "$llama_bench" ]; then
    printf 'reason=llama_bench_absent path=%s\n' "$llama_bench" >&2
    exit 2
fi
if [ -e "$arm_directory" ]; then
    printf 'reason=arm_directory_present path=%s; an arm claims its own directory\n' \
        "$arm_directory" >&2
    exit 2
fi
mkdir -p -- "$arm_directory"

# Every CPU-side pid this arm reads is resolved by comm/cmdline match rather
# than by a fixed number, since neither ksmd nor the guest's vCPU threads sit
# at a number this tree pins.
resolve_ksmd_pid() {
    for candidate in /proc/[0-9]*; do
        [ -r "$candidate/comm" ] || continue
        if [ "$(cat "$candidate/comm" 2>/dev/null)" = ksmd ]; then
            printf '%s\n' "${candidate#/proc/}"
            return 0
        fi
    done
    printf '\n'
}

# The guest's own thread group leader is what `qemu-system-*` names in
# /proc/PID/comm; its vCPU threads sit under /proc/PID/task and are summed
# rather than resolved individually, since which task ids are vCPUs versus
# I/O threads is a QEMU-internal question this campaign does not answer.
resolve_qemu_pid() {
    for candidate in /proc/[0-9]*; do
        [ -r "$candidate/comm" ] || continue
        case $(cat "$candidate/comm" 2>/dev/null) in
            qemu-system-*)
                printf '%s\n' "${candidate#/proc/}"
                return 0
                ;;
        esac
    done
    printf '\n'
}

# utime (field 14) plus stime (field 15) of /proc/PID/stat, summed across
# every task under /proc/PID/task when the process is a thread-group leader
# with more than one thread, so a QEMU guest's vCPU and I/O threads are
# counted together rather than only the leader's own idle-loop ticks.
read_process_ticks() {
    [ -n "${1:-}" ] || {
        printf 'unavailable\n'
        return 0
    }
    total_ticks=0
    found_any=0
    for stat_path in "/proc/$1/task"/*/stat; do
        [ -r "$stat_path" ] || continue
        found_any=1
        task_ticks=$(LC_ALL=C awk '{
                line = $0
                sub(/^.*[)] /, "", line)
                split(line, fields, / /)
                print fields[12] + fields[13]
            }' "$stat_path" 2>/dev/null) || task_ticks=0
        case $task_ticks in
            '' | *[!0-9]*) task_ticks=0 ;;
        esac
        total_ticks=$((total_ticks + task_ticks))
    done
    if [ "$found_any" -eq 0 ]; then
        printf 'unavailable\n'
        return 0
    fi
    printf '%s\n' "$total_ticks"
}

ksmd_pid=$(resolve_ksmd_pid)
qemu_pid=$(resolve_qemu_pid)

retain_cpu_endpoint() {
    endpoint_name=$1
    "$cpupower_command" frequency-info \
        >"$arm_directory/cpupower-frequency-info-$endpoint_name.txt" 2>&1 || true
    {
        printf 'key\tvalue\n'
        printf 'endpoint\t%s\n' "$endpoint_name"
        printf 'utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'ksmd_pid\t%s\n' "${ksmd_pid:-absent}"
        printf 'ksmd_ticks\t%s\n' "$(read_process_ticks "$ksmd_pid")"
        printf 'qemu_pid\t%s\n' "${qemu_pid:-absent}"
        printf 'qemu_ticks\t%s\n' "$(read_process_ticks "$qemu_pid")"
    } >"$arm_directory/cpu-endpoint-$endpoint_name.tsv"
}

retain_cpu_endpoint start

# The per-core cpufreq sampler reads /proc/cpuinfo, which reports the kernel's
# own aperf/mperf-derived MHz per logical CPU, rather than /sys scaling_cur_freq,
# since /proc/cpuinfo is what CLAUDE.md's own boost measurement (3.169 GHz on a
# core against a 2.3 GHz cpufreq ceiling) was read from.
cpuinfo_record=$arm_directory/cpuinfo-mhz-samples.tsv
nice -n 19 python3 - "$cpuinfo_record" "$cpuinfo_period_ms" "$cpu_list" <<'PY' &
import re
import signal
import sys
import time

output_path, period_ms_text, cpu_list_text = sys.argv[1:4]
period_s = float(period_ms_text) / 1000.0
wanted_cpus = [int(entry) for entry in cpu_list_text.split()]
running = {"value": True}


def stop(_signal_number, _frame):
    running["value"] = False


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

processor_re = re.compile(r"^processor\s*:\s*(\d+)")
mhz_re = re.compile(r"^cpu MHz\s*:\s*([0-9.]+)")

with open(output_path, "w") as handle:
    handle.write("monotonic_ns\t" + "\t".join(f"cpu{cpu}_mhz" for cpu in wanted_cpus) + "\n")
    handle.flush()
    while running["value"]:
        readings = {}
        current_cpu = None
        try:
            with open("/proc/cpuinfo") as cpuinfo_handle:
                for line in cpuinfo_handle:
                    processor_match = processor_re.match(line)
                    if processor_match:
                        current_cpu = int(processor_match.group(1))
                        continue
                    mhz_match = mhz_re.match(line)
                    if mhz_match and current_cpu is not None:
                        readings[current_cpu] = mhz_match.group(1)
        except OSError:
            pass
        row = [str(time.monotonic_ns())]
        for cpu in wanted_cpus:
            row.append(readings.get(cpu, "unavailable"))
        handle.write("\t".join(row) + "\n")
        handle.flush()
        time.sleep(period_s)
PY
cpuinfo_job_pid=$!

stop_cpuinfo_sampler() {
    if [ -n "${cpuinfo_job_pid:-}" ]; then
        kill -TERM "$cpuinfo_job_pid" 2>/dev/null || true
        wait "$cpuinfo_job_pid" 2>/dev/null || true
        cpuinfo_job_pid=''
    fi
}
power_envelope_arm_pid=''
stop_power_envelope_arm() {
    if [ -n "${power_envelope_arm_pid:-}" ]; then
        kill -TERM "$power_envelope_arm_pid" 2>/dev/null || true
        wait "$power_envelope_arm_pid" 2>/dev/null || true
        power_envelope_arm_pid=''
    fi
}
trap 'stop_cpuinfo_sampler' EXIT
trap 'stop_power_envelope_arm; stop_cpuinfo_sampler; exit 143' TERM
trap 'stop_power_envelope_arm; stop_cpuinfo_sampler; exit 130' INT
trap 'stop_power_envelope_arm; stop_cpuinfo_sampler; exit 129' HUP

summary_field() {
    awk -F'\t' -v key="$1" '$1 == key { print $2; exit }' "$2" 2>/dev/null
}

if [ "$instrument" = served ]; then
    # run-power-envelope-arm.sh claims its own arm directory the same way this
    # script claims its own, so the inner call is given the campaign directory
    # and a distinct inner arm name and this script's own arm directory
    # carries a symlink to what it wrote, keeping every retained file this
    # script's own instrumentation adds and every field
    # run-power-envelope-arm.sh already retains under one arm directory a
    # summarizer can read whole.
    inner_arm_name=$arm_name.served
    set +e
    env QWEN_POWER_ENERGY_PERIOD_MS="${QWEN_POWER_ENERGY_PERIOD_MS:-50}" \
        QWEN_POWER_CLOCK_PERIOD_MS="${QWEN_POWER_CLOCK_PERIOD_MS:-10}" \
        QWEN_POWER_TEMPERATURE_PERIOD_S="${QWEN_POWER_TEMPERATURE_PERIOD_S:-1}" \
        QWEN_BENCH_GENERATE="$bench_generate" \
        "$power_envelope_arm" "$campaign_directory" "$inner_arm_name" "$model_id" \
        >"$arm_directory/served-arm.stdout" 2>"$arm_directory/served-arm.stderr" &
    power_envelope_arm_pid=$!
    wait "$power_envelope_arm_pid"
    served_status=$?
    power_envelope_arm_pid=''
    set -e

    stop_cpuinfo_sampler
    trap - EXIT HUP INT TERM
    retain_cpu_endpoint end

    inner_arm_directory=$campaign_directory/arms/$inner_arm_name
    ln -s -- "$inner_arm_directory" "$arm_directory/served" 2>/dev/null || true

    {
        printf 'key\tvalue\n'
        printf 'schema\tpower-factorial-arm-v1\n'
        printf 'arm\t%s\n' "$arm_name"
        printf 'instrument\tserved\n'
        printf 'inner_arm\t%s\n' "$inner_arm_name"
        printf 'model_id\t%s\n' "$model_id"
        printf 'compute_state_profile\t%s\n' "$compute_state_profile"
        printf 'served_status\t%s\n' "$served_status"
        printf 'generate_tokens\t%s\n' "$bench_generate"
        printf 'decode_tok_s\t%s\n' \
            "$(summary_field decode_tok_s "$inner_arm_directory/arm-summary.tsv")"
        printf 'package_watts\t%s\n' \
            "$(summary_field package_watts "$inner_arm_directory/arm-summary.tsv")"
        printf 'gfxclk_delivered_mean_mhz\t%s\n' \
            "$(summary_field gfxclk_delivered_mean_mhz "$inner_arm_directory/arm-summary.tsv")"
        printf 'fclk_observed_mhz\t%s\n' \
            "$(summary_field fclk_observed_mhz "$inner_arm_directory/arm-summary.tsv")"
        printf 'tctl_peak_millidegrees\t%s\n' \
            "$(summary_field tctl_peak_millidegrees "$inner_arm_directory/arm-summary.tsv")"
        printf 'ksmd_ticks_delta\t%s\n' "unresolved"
        printf 'qemu_ticks_delta\t%s\n' "unresolved"
    } >"$arm_directory/arm-summary.tsv.partial"
else
    # The bench instrument bypasses the guarded launch chain entirely: it
    # requires no model registry tuple beyond the file path and reads decode
    # tok/s out of llama-bench's own markdown table, at the fixed-64
    # generation length every other arm's served decode reads against. It
    # carries no energy window, clock sidecar, or temperature record --
    # exactly the scope cut evidence/power-factorial/README.md registers
    # ahead of any run for this one rung.
    registry_row=$("$registry_reader" id "$model_id")
    model_file=$(printf '%s\n' "$registry_row" | awk -F= '$1 == "model_file" { sub(/^[^=]*=/, ""); print; exit }')
    model_path=$models_directory/$model_file
    if [ ! -f "$model_path" ]; then
        printf 'reason=model_absent path=%s\n' "$model_path" >&2
        exit 2
    fi
    bench_log=$arm_directory/llama-bench.log
    set +e
    nice -n 19 ionice -c 3 "$llama_bench" -m "$model_path" \
        -ngl 99 -t 2 -r 3 -p 0 -n "$bench_generate" -o md \
        >"$bench_log" 2>&1 &
    power_envelope_arm_pid=$!
    wait "$power_envelope_arm_pid"
    served_status=$?
    power_envelope_arm_pid=''
    set -e

    stop_cpuinfo_sampler
    trap - EXIT HUP INT TERM
    retain_cpu_endpoint end

    # The markdown table's `tg${N}` row carries the decode rate in its `t/s`
    # column as `MEAN ± STDDEV`; the mean alone is what this campaign reads,
    # the same convention CLAUDE.md registers for a positive
    # QWEN_BENCH_PREFILL/QWEN_BENCH_GENERATE pair.
    bench_decode_tok_s=$(LC_ALL=C awk -v generate="tg$bench_generate" -F'|' '
        $0 ~ ("\\| *" generate " *\\|") {
            value = $(NF - 1)
            sub(/^[ \t]+/, "", value)
            sub(/[ \t]+$/, "", value)
            sub(/ ±.*/, "", value)
            print value
            found = 1
            exit
        }
        END { if (!found) print "unavailable" }' "$bench_log")

    {
        printf 'key\tvalue\n'
        printf 'schema\tpower-factorial-arm-v1\n'
        printf 'arm\t%s\n' "$arm_name"
        printf 'instrument\tbench\n'
        printf 'inner_arm\t-\n'
        printf 'model_id\t%s\n' "$model_id"
        printf 'compute_state_profile\t%s\n' "$compute_state_profile"
        printf 'served_status\t%s\n' "$served_status"
        printf 'decode_tok_s\t%s\n' "$bench_decode_tok_s"
        printf 'package_watts\tunavailable\n'
        printf 'gfxclk_delivered_mean_mhz\tunavailable\n'
        printf 'fclk_observed_mhz\tunavailable\n'
        printf 'tctl_peak_millidegrees\tunavailable\n'
        printf 'ksmd_ticks_delta\t%s\n' "unresolved"
        printf 'qemu_ticks_delta\t%s\n' "unresolved"
    } >"$arm_directory/arm-summary.tsv.partial"
fi

# The delta fields need both endpoints, so they are computed after both are
# retained rather than carried as placeholders a reader must know to ignore.
start_ksmd_ticks=$(summary_field ksmd_ticks "$arm_directory/cpu-endpoint-start.tsv")
end_ksmd_ticks=$(summary_field ksmd_ticks "$arm_directory/cpu-endpoint-end.tsv")
start_qemu_ticks=$(summary_field qemu_ticks "$arm_directory/cpu-endpoint-start.tsv")
end_qemu_ticks=$(summary_field qemu_ticks "$arm_directory/cpu-endpoint-end.tsv")
compute_delta() {
    case ${1:-} in
        '' | *[!0-9]*) printf 'unavailable\n'; return 0 ;;
    esac
    case ${2:-} in
        '' | *[!0-9]*) printf 'unavailable\n'; return 0 ;;
    esac
    printf '%s\n' "$(($2 - $1))"
}
ksmd_delta=$(compute_delta "$start_ksmd_ticks" "$end_ksmd_ticks")
qemu_delta=$(compute_delta "$start_qemu_ticks" "$end_qemu_ticks")
sed \
    -e "s/^ksmd_ticks_delta\tunresolved\$/ksmd_ticks_delta\t$ksmd_delta/" \
    -e "s/^qemu_ticks_delta\tunresolved\$/qemu_ticks_delta\t$qemu_delta/" \
    "$arm_directory/arm-summary.tsv.partial" >"$arm_directory/arm-summary.tsv"
rm -f -- "$arm_directory/arm-summary.tsv.partial"

if [ "$served_status" -ne 0 ]; then
    printf 'power_factorial_arm=failed arm=%s model=%s served_status=%s\n' \
        "$arm_name" "$model_id" "$served_status" >&2
    exit 1
fi
printf 'power_factorial_arm=completed arm=%s model=%s decode_tok_s=%s\n' \
    "$arm_name" "$model_id" \
    "$(summary_field decode_tok_s "$arm_directory/arm-summary.tsv")"
