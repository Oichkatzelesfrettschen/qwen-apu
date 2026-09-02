#!/bin/sh
set -eu

# Replace a fixed inter-arm cooldown sleep with state convergence. A census
# arm leaves Vulkan submission, clock boost, thermal drift, and page reclaim
# behind at different rates, so a constant sleep either wastes time on a
# machine that settled early or starts the next arm on a machine that has
# not. This poller samples every 100 ms and reports the instant every
# predicate below has held continuously for --hold-ms, which is the
# convergence a fixed sleep can only approximate:
#
#   - no llama-server process is running (pgrep -x llama-server empty)
#   - gpu_busy_percent is at or below 5
#   - the selected pp_dpm_sclk step sits below the highest step the file
#     lists, and that selected step has held unchanged since the hold
#     window began -- a step change restarts the window the way the
#     temperature derivative does, because the appliance's idle governor
#     state selects a middle step rather than the lowest listed one
#   - temp1_input's derivative across the hold window is at or below
#     0.5 degrees Celsius per second in either direction, and its absolute
#     reading stays below 80 degrees Celsius
#   - MemAvailable's change across the hold window is below 1% of the
#     window's first reading
#   - /proc/vmstat's pswpin counter is unchanged across the hold window
#   - the workload lease file, when named, is acquired and released with
#     flock -n (free), rather than held by another process
#   - when a latency log is named, its computed p90 sits below the
#     baseline the log itself records, when the log names one
#
# A predicate that reads as unavailable (an unreadable sysfs or proc file)
# counts as not held, since a poller cannot report convergence over a signal
# it could not read. A violation of any predicate restarts the hold window
# at the next tick that satisfies every predicate again, so a flap late in
# the window costs the whole window rather than only the flapped tick.
#
# usage: await-quiescence.sh [--max-seconds N] [--hold-ms N]
#            [--drm-device DIR] [--hwmon DIR] [--proc-root DIR]
#            [--latency-log FILE] [--lease FILE]
#
# Exit status: 0 once quiescence is reached, 1 once --max-seconds elapses
# first, 2 on a usage error. Either outcome prints one line naming which,
# the elapsed milliseconds, and the last sampled vector. A timeout also
# prints one stderr line naming every predicate that read false on the
# final tick, since the retained stdout line alone left a prior campaign's
# failing predicate unnamed.

usage() {
    printf 'usage: %s [--max-seconds N] [--hold-ms N] [--drm-device DIR] [--hwmon DIR] [--proc-root DIR] [--latency-log FILE] [--lease FILE]\n' \
        "$0" >&2
    exit 2
}

positive_integer() {
    case $1 in
        '' | *[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

max_seconds=30
hold_ms=800
drm_device=${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}
hwmon_root=${QWEN_HWMON_ROOT:-/sys/class/hwmon}
proc_root=/proc
latency_log=
lease_file=

while [ "$#" -gt 0 ]; do
    case $1 in
        --max-seconds)
            [ "$#" -ge 2 ] || usage
            max_seconds=$2
            shift 2
            ;;
        --hold-ms)
            [ "$#" -ge 2 ] || usage
            hold_ms=$2
            shift 2
            ;;
        --drm-device)
            [ "$#" -ge 2 ] || usage
            drm_device=$2
            shift 2
            ;;
        --hwmon)
            [ "$#" -ge 2 ] || usage
            hwmon_root=$2
            shift 2
            ;;
        --proc-root)
            [ "$#" -ge 2 ] || usage
            proc_root=$2
            shift 2
            ;;
        --latency-log)
            [ "$#" -ge 2 ] || usage
            latency_log=$2
            shift 2
            ;;
        --lease)
            [ "$#" -ge 2 ] || usage
            lease_file=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

positive_integer "$max_seconds" || usage
[ "$max_seconds" -gt 0 ] || usage
positive_integer "$hold_ms" || usage

poll_interval_s=0.1

# The hwmon device is resolved once: amdgpu's hwmon number moves across
# boots and across a fixture, so every later temp1_input read goes through
# the directory found here rather than a guessed hwmon index.
hwmon_device=
if [ -d "$hwmon_root" ]; then
    for candidate in "$hwmon_root"/*; do
        [ -d "$candidate" ] || continue
        if [ -r "$candidate/name" ] && [ "$(cat "$candidate/name" 2>/dev/null)" = amdgpu ]; then
            hwmon_device=$candidate
            break
        fi
    done
fi

read_kib_field() {
    # $1 = file, $2 = field name as /proc/meminfo or /proc/vmstat spells it
    file=$1
    field=$2
    if [ ! -r "$file" ]; then
        printf 'unavailable\n'
        return
    fi
    awk -v want="$field" '$1 == want ":" || $1 == want { print $2; found = 1; exit } END { if (!found) print "unavailable" }' "$file"
}

read_gpu_busy_percent() {
    if [ ! -r "$drm_device/gpu_busy_percent" ]; then
        printf 'unavailable\n'
        return
    fi
    value=$(cat "$drm_device/gpu_busy_percent" 2>/dev/null || printf 'unavailable\n')
    case $value in
        '' | *[!0-9]*) printf 'unavailable\n' ;;
        *) printf '%s\n' "$value" ;;
    esac
}

# Reads the selected step index and the listed step count from one
# pp_dpm_sclk pass, so the two never disagree about which line of the file
# they read. The step index is the line's own leading "N:" label rather
# than its clock frequency, since the predicate below reads position in the
# listed ladder rather than an absolute rate.
read_sclk_state() {
    if [ ! -r "$drm_device/pp_dpm_sclk" ]; then
        printf 'unavailable\tunavailable\n'
        return
    fi
    awk '
        {
            idx = $1
            sub(/:$/, "", idx)
            if (idx !~ /^[0-9]+$/) next
            count++
            for (i = 1; i <= NF; i++) {
                if ($i == "*") sel = idx
            }
        }
        END {
            if (sel == "" || count == 0) {
                print "unavailable\tunavailable"
            } else {
                print sel "\t" count
            }
        }
    ' "$drm_device/pp_dpm_sclk"
}

read_temp_millicelsius() {
    if [ -z "$hwmon_device" ] || [ ! -r "$hwmon_device/temp1_input" ]; then
        printf 'unavailable\n'
        return
    fi
    value=$(cat "$hwmon_device/temp1_input" 2>/dev/null || printf 'unavailable\n')
    case $value in
        '' | *[!0-9]*) printf 'unavailable\n' ;;
        *) printf '%s\n' "$value" ;;
    esac
}

read_pswpin() {
    read_kib_field "$proc_root/vmstat" pswpin
}

lease_is_free() {
    [ -n "$lease_file" ] || { printf 'not_applicable\n'; return; }
    if [ ! -e "$lease_file" ]; then
        printf '1\n'
        return
    fi
    if flock -n -x "$lease_file" true 2>/dev/null; then
        printf '1\n'
    else
        printf '0\n'
    fi
}

# The raw probe log (remote/summarize-probe.sh's own input format) names no
# per-file baseline anywhere in its "probe_start" header or its "sample"
# lines, so a log that never grows one such field always reports
# not_applicable here rather than a synthesized threshold. A future log
# format that writes "baseline_p90_us=N" on any line is honored the moment
# it appears, because the search is a plain grep rather than a fixed line
# number.
latency_is_ok() {
    [ -n "$latency_log" ] || { printf 'not_applicable\t-\t-\n'; return; }
    if [ ! -r "$latency_log" ]; then
        printf 'not_applicable\t-\t-\n'
        return
    fi
    baseline_line=$(grep -o 'baseline_p90_us=[0-9]*' "$latency_log" 2>/dev/null | tail -1 || true)
    if [ -z "$baseline_line" ]; then
        printf 'not_applicable\t-\t-\n'
        return
    fi
    baseline=${baseline_line#baseline_p90_us=}
    p90_line=$("$script_directory/summarize-probe.sh" "$latency_log" 2>/dev/null | sed -n 's/^p90=//p')
    case $p90_line in
        '' | *[!0-9]*)
            printf '0\t%s\t%s\n' "$baseline" unavailable
            return
            ;;
    esac
    if [ "$p90_line" -lt "$baseline" ]; then
        printf '1\t%s\t%s\n' "$baseline" "$p90_line"
    else
        printf '0\t%s\t%s\n' "$baseline" "$p90_line"
    fi
}

now_ms() {
    now_ns=$(date +%s%N)
    printf '%s\n' "$((now_ns / 1000000))"
}

start_ms=$(now_ms)
deadline_ms=$((start_ms + max_seconds * 1000))

streak_active=0
streak_start_ms=0
temp_base=0
mem_base=0
pswpin_base=0
sclk_base=unavailable

last_vector=''
outcome=timeout

while :; do
    tick_ms=$(now_ms)

    process_present=0
    if pgrep -x llama-server >/dev/null 2>&1; then
        process_present=1
    fi

    gpu_busy=$(read_gpu_busy_percent)
    gpu_busy_ok=0
    case $gpu_busy in
        unavailable) gpu_busy_ok=0 ;;
        *) [ "$gpu_busy" -le 5 ] && gpu_busy_ok=1 ;;
    esac

    sclk_state=$(read_sclk_state)
    sclk_step=${sclk_state%%	*}
    sclk_steps=${sclk_state#*	}
    sclk_ok=0
    if [ "$sclk_step" != unavailable ] && [ "$sclk_steps" != unavailable ]; then
        highest_step=$((sclk_steps - 1))
        [ "$sclk_step" -lt "$highest_step" ] && sclk_ok=1
    fi

    temp_milli=$(read_temp_millicelsius)
    temp_abs_ok=0
    if [ "$temp_milli" != unavailable ]; then
        temp_abs_ok=$(awk -v m="$temp_milli" 'BEGIN { print (m + 0 < 80000) ? 1 : 0 }')
    fi

    mem_available=$(read_kib_field "$proc_root/meminfo" MemAvailable)

    pswpin_now=$(read_pswpin)

    lease_ok_raw=$(lease_is_free)
    case $lease_ok_raw in
        not_applicable) lease_ok=1 ;;
        *) lease_ok=$lease_ok_raw ;;
    esac

    latency_fields=$(latency_is_ok)
    latency_ok_raw=$(printf '%s\n' "$latency_fields" | cut -f1)
    latency_baseline=$(printf '%s\n' "$latency_fields" | cut -f2)
    latency_p90=$(printf '%s\n' "$latency_fields" | cut -f3)
    case $latency_ok_raw in
        not_applicable) latency_ok=1 ;;
        *) latency_ok=$latency_ok_raw ;;
    esac

    instantaneous_ok=0
    if [ "$process_present" -eq 0 ] && [ "$gpu_busy_ok" -eq 1 ] && \
       [ "$sclk_ok" -eq 1 ] && [ "$temp_abs_ok" -eq 1 ] && \
       [ "$lease_ok" -eq 1 ] && [ "$latency_ok" -eq 1 ] && \
       [ "$temp_milli" != unavailable ] && [ "$mem_available" != unavailable ] && \
       [ "$pswpin_now" != unavailable ]; then
        instantaneous_ok=1
    fi

    temp_rate_ok=0
    temp_rate=0.00
    mem_change_ok=0
    mem_change_pct=0.00
    pswpin_ok=0
    sclk_stable_ok=0

    if [ "$streak_active" -eq 0 ]; then
        if [ "$instantaneous_ok" -eq 1 ]; then
            streak_active=1
            streak_start_ms=$tick_ms
            temp_base=$temp_milli
            mem_base=$mem_available
            pswpin_base=$pswpin_now
            sclk_base=$sclk_step
            temp_rate_ok=1
            mem_change_ok=1
            pswpin_ok=1
            sclk_stable_ok=1
        fi
    else
        if [ "$instantaneous_ok" -eq 0 ]; then
            streak_active=0
        else
            elapsed_window_s=$(awk -v now="$tick_ms" -v start="$streak_start_ms" 'BEGIN { printf "%.3f", (now - start) / 1000 }')
            temp_rate=$(awk -v base="$temp_base" -v now="$temp_milli" -v dt="$elapsed_window_s" \
                'BEGIN { if (dt <= 0) { printf "0.00"; exit } rate = ((now - base) / 1000.0) / dt; if (rate < 0) rate = -rate; printf "%.2f", rate }')
            temp_rate_ok=$(awk -v r="$temp_rate" 'BEGIN { print (r <= 0.5) ? 1 : 0 }')

            mem_change_pct=$(awk -v base="$mem_base" -v now="$mem_available" \
                'BEGIN { if (base <= 0) { printf "0.00"; exit } d = now - base; if (d < 0) d = -d; printf "%.4f", 100.0 * d / base }')
            mem_change_ok=$(awk -v base="$mem_base" -v now="$mem_available" \
                'BEGIN { if (base <= 0) { print 0; exit } d = now - base; if (d < 0) d = -d; print (d / base < 0.01) ? 1 : 0 }')

            if [ "$pswpin_now" = "$pswpin_base" ]; then
                pswpin_ok=1
            fi

            if [ "$sclk_step" = "$sclk_base" ]; then
                sclk_stable_ok=1
            fi

            if [ "$temp_rate_ok" -eq 1 ] && [ "$mem_change_ok" -eq 1 ] && [ "$pswpin_ok" -eq 1 ] && \
               [ "$sclk_stable_ok" -eq 1 ]; then
                held_ms=$((tick_ms - streak_start_ms))
                if [ "$held_ms" -ge "$hold_ms" ]; then
                    last_vector=$(printf 'hold_ms=%s process=absent gpu_busy_percent=%s gpu_busy_ok=%s sclk_step=%s sclk_steps=%s sclk_ok=%s sclk_stable_ok=%s temp_millicelsius=%s temp_abs_ok=%s temp_rate_c_per_s=%s temp_rate_ok=%s mem_available_kib=%s mem_change_pct=%s mem_ok=%s pswpin=%s pswpin_ok=%s lease_ok=%s latency_ok=%s latency_baseline_us=%s latency_p90_us=%s' \
                        "$hold_ms" "$gpu_busy" "$gpu_busy_ok" "$sclk_step" "$sclk_steps" "$sclk_ok" "$sclk_stable_ok" \
                        "$temp_milli" "$temp_abs_ok" "$temp_rate" "$temp_rate_ok" \
                        "$mem_available" "$mem_change_pct" "$mem_change_ok" \
                        "$pswpin_now" "$pswpin_ok" "$lease_ok" "$latency_ok" "$latency_baseline" "$latency_p90")
                    outcome=reached
                    break
                fi
            else
                streak_active=0
            fi
        fi
    fi

    last_vector=$(printf 'hold_ms=%s process=%s gpu_busy_percent=%s gpu_busy_ok=%s sclk_step=%s sclk_steps=%s sclk_ok=%s sclk_stable_ok=%s temp_millicelsius=%s temp_abs_ok=%s temp_rate_c_per_s=%s temp_rate_ok=%s mem_available_kib=%s mem_change_pct=%s mem_ok=%s pswpin=%s pswpin_ok=%s lease_ok=%s latency_ok=%s latency_baseline_us=%s latency_p90_us=%s' \
        "$hold_ms" "$([ "$process_present" -eq 1 ] && printf present || printf absent)" \
        "$gpu_busy" "$gpu_busy_ok" "$sclk_step" "$sclk_steps" "$sclk_ok" "$sclk_stable_ok" \
        "$temp_milli" "$temp_abs_ok" "$temp_rate" "$temp_rate_ok" \
        "$mem_available" "$mem_change_pct" "$mem_change_ok" \
        "$pswpin_now" "$pswpin_ok" "$lease_ok" "$latency_ok" "$latency_baseline" "$latency_p90")

    now_check=$(now_ms)
    if [ "$now_check" -ge "$deadline_ms" ]; then
        outcome=timeout
        break
    fi

    sleep "$poll_interval_s"
done

final_ms=$(now_ms)
elapsed_ms=$((final_ms - start_ms))

printf 'quiescence=%s elapsed_ms=%s %s\n' "$outcome" "$elapsed_ms" "$last_vector"

if [ "$outcome" = reached ]; then
    exit 0
fi

# A timeout names every predicate that read false on the final tick, so a
# retained stderr log states the reason rather than leaving a reader to
# recompute it from the last vector alone.
process_ok=0
[ "$process_present" -eq 0 ] && process_ok=1

failed_predicates=''
add_failed_predicate() {
    # $1 = predicate name, $2 = its final-tick ok flag (0 or 1)
    [ "$2" -eq 1 ] && return 0
    if [ -z "$failed_predicates" ]; then
        failed_predicates=$1
    else
        failed_predicates="$failed_predicates,$1"
    fi
}
add_failed_predicate process "$process_ok"
add_failed_predicate gpu_busy "$gpu_busy_ok"
add_failed_predicate sclk "$sclk_ok"
add_failed_predicate sclk_stable "$sclk_stable_ok"
add_failed_predicate temp_abs "$temp_abs_ok"
add_failed_predicate temp_rate "$temp_rate_ok"
add_failed_predicate mem "$mem_change_ok"
add_failed_predicate pswpin "$pswpin_ok"
add_failed_predicate lease "$lease_ok"
add_failed_predicate latency "$latency_ok"
if [ -n "$failed_predicates" ]; then
    printf 'quiescence_timeout_predicates=%s\n' "$failed_predicates" >&2
fi

exit 1
