#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    printf 'usage: %s SERVER_PID TELEMETRY_LOG\n' "$0" >&2
    exit 2
fi

server_pid=$1
telemetry_log=$2

case $server_pid in
    '' | *[!0-9]*)
        printf 'server PID must be a positive integer\n' >&2
        exit 2
        ;;
esac

if ! kill -0 "$server_pid" 2>/dev/null; then
    printf 'server PID is not running: %s\n' "$server_pid" >&2
    exit 2
fi

if [ "${QWEN_ONE_CORE_ACTIVE:-0}" != 1 ]; then
    renice -n 19 -p $$ >/dev/null
    QWEN_ONE_CORE_ACTIVE=1 exec taskset -c 0 ionice -c 3 "$0" "$@"
fi

sample_seconds=1
minimum_mem_available_kib=4194304
maximum_swapin_bytes_per_sample=67108864
maximum_temperature_millicelsius=90000
maximum_gpu_busy_percent=75
gpu_device_directory=${QWEN_GPU_DEVICE_DIRECTORY:-/sys/class/drm/card1/device}
if [ "$gpu_device_directory" != /sys/class/drm/card1/device ] && \
   [ "${QWEN_GUARD_TEST_MODE:-0}" != 1 ]; then
    printf 'GPU device override requires QWEN_GUARD_TEST_MODE=1\n' >&2
    exit 2
fi
page_size=$(getconf PAGESIZE)
previous_pswpin=$(awk '$1 == "pswpin" { print $2 }' /proc/vmstat)

terminate_server() {
    reason=$1
    printf 'abort_utc=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" \
        >>"$telemetry_log"
    kill -TERM "$server_pid" 2>/dev/null || true
    exit 3
}

{
    printf 'monitor_start_utc=%s server_pid=%s sample_seconds=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$server_pid" "$sample_seconds"
    printf 'threshold_mem_available_kib=%s threshold_swapin_bytes_per_sample=%s threshold_temperature_millicelsius=%s\n' \
        "$minimum_mem_available_kib" "$maximum_swapin_bytes_per_sample" \
        "$maximum_temperature_millicelsius"
    printf 'threshold_maximum_gpu_busy_percent=%s enforcement=terminate_on_sample_above_threshold\n' \
        "$maximum_gpu_busy_percent"
} >"$telemetry_log"

while kill -0 "$server_pid" 2>/dev/null; do
    affinity=$(awk '$1 == "Cpus_allowed_list:" { print $2 }' "/proc/$server_pid/status")
    nice_value=$(ps -o ni= -p "$server_pid" | tr -d ' ')
    rss_kib=$(awk '$1 == "VmRSS:" { print $2 }' "/proc/$server_pid/status")
    peak_rss_kib=$(awk '$1 == "VmHWM:" { print $2 }' "/proc/$server_pid/status")
    mem_available_kib=$(awk '$1 == "MemAvailable:" { print $2 }' /proc/meminfo)
    current_pswpin=$(awk '$1 == "pswpin" { print $2 }' /proc/vmstat)
    swapin_pages=$((current_pswpin - previous_pswpin))
    swapin_bytes=$((swapin_pages * page_size))
    previous_pswpin=$current_pswpin

    if [ ! -r "$gpu_device_directory/gpu_busy_percent" ] || \
       [ ! -r "$gpu_device_directory/mem_info_gtt_used" ] || \
       [ ! -r "$gpu_device_directory/mem_info_vram_used" ]; then
        terminate_server gpu_telemetry_unavailable
    fi

    gpu_busy_percent=$(cat "$gpu_device_directory/gpu_busy_percent")
    gtt_used_bytes=$(cat "$gpu_device_directory/mem_info_gtt_used")
    vram_used_bytes=$(cat "$gpu_device_directory/mem_info_vram_used")
    sclk=$(tr '\n' ';' <"$gpu_device_directory/pp_dpm_sclk")
    mclk=$(tr '\n' ';' <"$gpu_device_directory/pp_dpm_mclk")

    maximum_observed_temperature=0
    for temperature_path in /sys/class/hwmon/hwmon*/temp*_input; do
        if [ ! -r "$temperature_path" ]; then
            continue
        fi
        temperature=$(cat "$temperature_path")
        if [ "$temperature" -gt "$maximum_observed_temperature" ]; then
            maximum_observed_temperature=$temperature
        fi
    done

    printf 'sample_utc=%s affinity=%s nice=%s rss_kib=%s peak_rss_kib=%s mem_available_kib=%s swapin_bytes=%s max_temp_millicelsius=%s gpu_busy_percent=%s gtt_used_bytes=%s vram_used_bytes=%s sclk=%s mclk=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$affinity" "$nice_value" \
        "$rss_kib" "$peak_rss_kib" "$mem_available_kib" "$swapin_bytes" \
        "$maximum_observed_temperature" "$gpu_busy_percent" "$gtt_used_bytes" \
        "$vram_used_bytes" "$sclk" "$mclk" >>"$telemetry_log"

    if [ "$affinity" != 0 ]; then
        terminate_server process_affinity_changed
    fi
    if [ "$nice_value" != 19 ]; then
        terminate_server process_nice_changed
    fi
    if [ "$mem_available_kib" -lt "$minimum_mem_available_kib" ]; then
        terminate_server memory_reserve_breached
    fi
    if [ "$swapin_bytes" -gt "$maximum_swapin_bytes_per_sample" ]; then
        terminate_server swapin_rate_breached
    fi
    if [ "$maximum_observed_temperature" -ge "$maximum_temperature_millicelsius" ]; then
        terminate_server temperature_breached
    fi
    case $gpu_busy_percent in
        '' | *[!0-9]*)
            terminate_server gpu_busy_percent_invalid
            ;;
    esac
    if [ "$gpu_busy_percent" -gt "$maximum_gpu_busy_percent" ]; then
        terminate_server gpu_busy_percent_breached
    fi

    sleep "$sample_seconds"
done

printf 'monitor_stop_utc=%s reason=server_exited\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$telemetry_log"
