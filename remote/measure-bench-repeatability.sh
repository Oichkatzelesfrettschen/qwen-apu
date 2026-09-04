#!/bin/sh
set -eu

# Establish whether a depth-0 llama-bench rate is repeatable across invocations
# before any comparison rests on one. The Nanbeige ladder recorded 3.31 tok/s
# for Qwen3.8-4B at depth 0 with an f16 cache; the cache factorial recorded 3.08
# for the same cell. Both ran `-ngl 99 -t 2 -r 3 -p 0 -n 64` on the same build
# and the same file, and they differ by 7.5%, which is larger than every effect
# the factorial set out to measure.
#
# Two candidates separate here. The ladder printed no `fa` column, so it ran the
# `auto` default while the factorial forced a value; arm one repeats the ladder's
# flag set. The factorial's f16 cells ran four minutes into sustained load on a
# 15 W part; arms two and three repeat the same cell hot and after an idle
# interval. A spread across arms two and three makes invocation order a
# confound in every depth-0 figure this tree holds.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s MODEL_PATH [OUTPUT_DIRECTORY]\n' "$0" >&2
    exit 2
fi

model_path=$1
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
output_directory=${2:-"$qwen_home_results/bench-repeatability"}
bench=${QWEN_LLAMA_BENCH:-"$qwen_home_llama_bench"}
clock_sampler=${QWEN_CLOCK_SAMPLER:-"$script_directory/sample-gpu-clocks.sh"}
idle_seconds=${QWEN_IDLE_SECONDS:-600}
sampler_term_grace_milliseconds=${QWEN_SAMPLER_TERM_GRACE_MS:-2000}
sampler_kill_grace_milliseconds=${QWEN_SAMPLER_KILL_GRACE_MS:-2000}

if [ ! -x "$bench" ] || [ ! -f "$model_path" ]; then
    printf 'llama-bench and the model must both exist\n' >&2
    exit 2
fi
if pgrep -x llama-server >/dev/null 2>&1 || pgrep -x llama-bench >/dev/null 2>&1; then
    printf 'another llama process holds the device\n' >&2
    exit 2
fi
for grace_value in "$sampler_term_grace_milliseconds" \
        "$sampler_kill_grace_milliseconds"; do
    case $grace_value in
        '' | *[!0-9]* | 0*)
            printf 'sampler teardown grace must be a canonical positive integer: %s\n' \
                "$grace_value" >&2
            exit 2
            ;;
    esac
done
if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 is required for identity-bound sampler teardown\n' >&2
    exit 2
fi

mkdir -p "$output_directory"
summary=$output_directory/repeatability-summary.tsv
printf 'arm\tflags\tdecode_tok_s\tstatus\tmclk_mhz_modal\tsclk_mhz_max\ttemp_c_max\tsamples\n' \
    >"$summary"

process_start_time_ticks() {
    identity_pid=$1
    sed 's/^.*) //' "/proc/$identity_pid/stat" 2>/dev/null |
        awk '{ print $20 }'
}

sampler_pid=''
sampler_start_time_ticks=''
stop_sampler() {
    [ -n "$sampler_pid" ] || return 0
    teardown_pid=$sampler_pid
    teardown_start_time_ticks=$sampler_start_time_ticks
    sampler_pid=''
    sampler_start_time_ticks=''

    if [ -z "$teardown_start_time_ticks" ]; then
        if [ -e "/proc/$teardown_pid" ]; then
            printf 'sampler teardown lacks a stable process identity: pid=%s\n' \
                "$teardown_pid" >&2
            exit 1
        fi
        wait "$teardown_pid" 2>/dev/null || true
        printf 'sampler_teardown=completed signal=none state=already-exited pid=%s\n' \
            "$teardown_pid" >&2
        return 0
    fi

    sampler_teardown_status=0
    sampler_teardown_result=''
    if sampler_teardown_result=$(python3 - "$teardown_pid" \
            "$teardown_start_time_ticks" \
            "$sampler_term_grace_milliseconds" \
            "$sampler_kill_grace_milliseconds" <<'PY'
import os
import select
import signal
import sys
from pathlib import Path


def positive_integer(text: str, name: str) -> int:
    if not text.isascii() or not text.isdecimal() or text.startswith("0"):
        raise ValueError(f"{name} must be a canonical positive integer")
    value = int(text)
    if value <= 0:
        raise ValueError(f"{name} must be a canonical positive integer")
    return value


def process_start_time_ticks(process_id: int) -> int:
    stat_text = (Path("/proc") / str(process_id) / "stat").read_text(
        encoding="ascii"
    )
    command_end = stat_text.rfind(")")
    if command_end < 0 or command_end + 2 >= len(stat_text):
        raise RuntimeError("sampler process stat is malformed")
    fields = stat_text[command_end + 2 :].split()
    if len(fields) < 20:
        raise RuntimeError("sampler process stat has too few fields")
    return int(fields[19])


process_id = positive_integer(sys.argv[1], "sampler pid")
expected_start_time_ticks = positive_integer(
    sys.argv[2], "sampler start time"
)
term_grace_milliseconds = positive_integer(sys.argv[3], "TERM grace")
kill_grace_milliseconds = positive_integer(sys.argv[4], "KILL grace")

try:
    process_descriptor = os.pidfd_open(process_id)
except ProcessLookupError:
    print(
        "sampler_teardown=completed signal=none state=already-exited "
        f"pid={process_id} start_time_ticks={expected_start_time_ticks}"
    )
    raise SystemExit(0)

try:
    process_poller = select.poll()
    process_poller.register(process_descriptor, select.POLLIN)

    def process_exited(timeout_milliseconds: int) -> bool:
        return any(
            event_mask & select.POLLIN
            for _, event_mask in process_poller.poll(timeout_milliseconds)
        )

    if process_exited(0):
        print(
            "sampler_teardown=completed signal=none state=already-exited "
            f"pid={process_id} start_time_ticks={expected_start_time_ticks}"
        )
        raise SystemExit(0)
    try:
        observed_start_time_ticks = process_start_time_ticks(process_id)
    except FileNotFoundError:
        if process_exited(0):
            print(
                "sampler_teardown=completed signal=none state=already-exited "
                f"pid={process_id} start_time_ticks={expected_start_time_ticks}"
            )
            raise SystemExit(0)
        raise RuntimeError("sampler identity vanished before signaling") from None
    if observed_start_time_ticks != expected_start_time_ticks:
        raise RuntimeError(
            "sampler start time differs from the recorded process identity"
        )

    try:
        signal.pidfd_send_signal(process_descriptor, signal.SIGTERM)
    except ProcessLookupError:
        print(
            "sampler_teardown=completed signal=none state=already-exited "
            f"pid={process_id} start_time_ticks={expected_start_time_ticks}"
        )
        raise SystemExit(0)
    if process_exited(term_grace_milliseconds):
        print(
            "sampler_teardown=completed signal=TERM state=exited "
            f"pid={process_id} start_time_ticks={expected_start_time_ticks}"
        )
        raise SystemExit(0)

    try:
        signal.pidfd_send_signal(process_descriptor, signal.SIGKILL)
    except ProcessLookupError:
        print(
            "sampler_teardown=completed signal=TERM state=exited "
            f"pid={process_id} start_time_ticks={expected_start_time_ticks}"
        )
        raise SystemExit(0)
    if not process_exited(kill_grace_milliseconds):
        raise RuntimeError("sampler remained live after SIGKILL")
    print(
        "sampler_teardown=completed signal=KILL state=exited "
        f"pid={process_id} start_time_ticks={expected_start_time_ticks}"
    )
except (OSError, RuntimeError, ValueError) as error:
    print(f"sampler_teardown=failed pid={process_id} error={error}", file=sys.stderr)
    raise SystemExit(1) from None
finally:
    os.close(process_descriptor)
PY
    ); then
        sampler_teardown_status=0
    else
        sampler_teardown_status=$?
    fi
    if [ -n "$sampler_teardown_result" ]; then
        printf '%s\n' "$sampler_teardown_result" >&2
    fi
    if [ "$sampler_teardown_status" -ne 0 ]; then
        printf 'identity-bound sampler teardown failed: pid=%s start_time_ticks=%s\n' \
            "$teardown_pid" "$teardown_start_time_ticks" >&2
        exit 1
    fi

    # The pidfd poll proves the recorded process has exited. wait now reaps the
    # direct child without reopening a numeric-PID race or an unbounded wait.
    wait "$teardown_pid" 2>/dev/null || true
}
trap 'stop_sampler' EXIT
trap 'stop_sampler; exit 130' INT
trap 'stop_sampler; exit 143' TERM

measurement_failed=0

run_arm() {
    arm_label=$1
    shift
    arm_log=$output_directory/$arm_label.log
    arm_samples=$output_directory/$arm_label.clocks.tsv
    printf 'arm_start_utc=%s arm=%s flags=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label" "$*"
    "$clock_sampler" "$arm_samples" &
    sampler_pid=$!
    sampler_start_time_ticks=$(process_start_time_ticks "$sampler_pid")
    case $sampler_start_time_ticks in
        '' | *[!0-9]* | 0)
            if [ -e "/proc/$sampler_pid" ]; then
                printf 'cannot bind sampler process identity: pid=%s\n' \
                    "$sampler_pid" >&2
                exit 1
            fi
            ;;
    esac
    set +e
    nice -n 19 ionice -c 3 "$bench" -m "$model_path" \
        -ngl 99 -t 2 -r 3 -p 0 -n 64 -o md "$@" >"$arm_log" 2>&1
    arm_status=$?
    set -e
    stop_sampler
    if [ "$arm_status" -eq 0 ]; then
        decode=$(awk -F'|' '$0 ~ /\| *tg[0-9]+( @ d[0-9]+)? *\|/ {
                                split($(NF - 1), parts, /[^0-9.]+/)
                                for (i = 1; i <= 3; i++) {
                                    if (parts[i] != "") { rate = parts[i]; break }
                                }
                                spread = parts[i + 1]
                            }
                            END {
                                if (rate == "") { print "n/a" }
                                else { printf "%s+/-%s\n", rate, (spread == "" ? "0" : spread) }
                            }' "$arm_log")
    else
        decode=n/a
    fi
    clock_report=$(awk -F'\t' '
        { samples++ }
        $1 ~ /^[0-9]+([.][0-9]+)?$/ { count[$1]++; clock_samples++ }
        $2 ~ /^[0-9]+([.][0-9]+)?$/ {
          if ($2 + 0 > sclk_max) { sclk_max = $2 + 0 }
          sclk_samples++
        }
        $3 ~ /^[0-9]+([.][0-9]+)?$/ {
          if ($3 + 0 > temp_max) { temp_max = $3 + 0 }
          temperature_samples++
        }
        END {
            for (step in count) {
                if (count[step] > best) { best = count[step]; modal = step }
            }
            printf "%s\t%s\t%s\t%d",
                (clock_samples ? modal : "unavailable"),
                (sclk_samples ? sclk_max : "unavailable"),
                (temperature_samples ? sprintf("%.1f", temp_max / 1000) : "unavailable"),
                samples
        }' "$arm_samples")
    # The caller tests this function, which suspends errexit through its whole
    # body, so the summary append carries its own failure path: a row that
    # fails to land must fail the arm rather than letting the run print
    # completed over an absent row.
    printf '%s\t%s\t%s\t%s\t%s\n' "$arm_label" "$*" "$decode" \
        "$arm_status" "$clock_report" >>"$summary" || return 1
    printf 'arm_stop_utc=%s arm=%s decode=%s status=%s clocks=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label" "$decode" "$arm_status" \
        "$(printf '%s' "$clock_report" | tr '\t' ' ')"

    if [ "$arm_status" -ne 0 ] || [ "$decode" = n/a ]; then
        return 1
    fi
    return 0
}

# The ladder's flag set: cache types left at their f16 default and flash
# attention left at `auto`, which is why its table printed neither column.
run_arm ladder-flags || measurement_failed=1
run_arm hot-f16-fa-off -ctk f16 -ctv f16 -fa off || measurement_failed=1
run_arm hot-f16-fa-auto -ctk f16 -ctv f16 || measurement_failed=1

printf 'idle_start_utc=%s seconds=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$idle_seconds"
sleep "$idle_seconds"
printf 'idle_stop_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

run_arm cold-f16-fa-off -ctk f16 -ctv f16 -fa off || measurement_failed=1
run_arm cold-ladder-flags || measurement_failed=1

if [ "$measurement_failed" -ne 0 ]; then
    printf 'bench_repeatability=failed output_directory=%s\n' \
        "$output_directory" >&2
    cat "$summary"
    exit 1
fi

# Five arms ran, so a completed run proves five summary rows; a row lost to a
# failure errexit could not surface inside the tested function fails here.
summary_row_count=$(grep -c . "$summary")
if [ "$summary_row_count" -ne 6 ]; then
    printf 'bench_repeatability=failed reason=summary_rows_%s_of_6 output_directory=%s\n' \
        "$summary_row_count" "$output_directory" >&2
    cat "$summary"
    exit 1
fi
printf 'bench_repeatability=completed output_directory=%s\n' "$output_directory"
cat "$summary"
