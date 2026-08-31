#!/bin/sh
set -eu

# One session summary derived from one immutable telemetry record. The record
# is the authority: every observed quantity here is read back out of it, and
# the provenance arguments name the identities the log itself cannot carry.
# The summary is a convenience surface, because `tmux kill-session` ends
# qwen-webui-session.sh without running its EXIT trap and leaves the log alone.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s TELEMETRY_LOG [SUMMARY_OUTPUT]\n' "$0" >&2
    printf '  provenance arrives as QWEN_TELEMETRY_MODEL_ID, _MODEL_PATH,\n' >&2
    printf '  _MODEL_SHA256, _SERVER_SHA256, _SERVER_PID\n' >&2
    exit 2
fi

telemetry_log=$1
summary_output=${2:-${telemetry_log%.log}.summary}

if [ ! -r "$telemetry_log" ]; then
    printf 'telemetry record is unreadable: %s\n' "$telemetry_log" >&2
    exit 1
fi

field_of() {
    # Last occurrence wins for a repeated key, which is what the abort and
    # termination lines want; a threshold line appears once at the head.
    awk -v key="$1" '
        {
            for (index_position = 1; index_position <= NF; index_position++) {
                split($index_position, pair, "=")
                if (pair[1] == key) { value = substr($index_position, length(key) + 2) }
            }
        }
        END { print value }
    ' "$telemetry_log"
}

sample_statistic() {
    # Minimum, maximum, sum, and count over one sample key, computed in one
    # pass so a long record is read once rather than four times.
    awk -v key="$1" -v want="$2" '
        /^sample_utc=/ {
            for (index_position = 1; index_position <= NF; index_position++) {
                split($index_position, pair, "=")
                if (pair[1] != key) { continue }
                value = substr($index_position, length(key) + 2)
                if (value ~ /^[0-9]+$/) {
                    if (count == 0 || value < minimum) { minimum = value }
                    if (count == 0 || value > maximum) { maximum = value }
                    total += value
                    count++
                }
            }
        }
        END {
            if (count == 0) { print "-"; exit }
            if (want == "minimum") { print minimum }
            else if (want == "maximum") { print maximum }
            else if (want == "total") { print total }
            else { print count }
        }
    ' "$telemetry_log"
}

first_sample_of() {
    awk -v key="$1" '
        /^sample_utc=/ {
            for (index_position = 1; index_position <= NF; index_position++) {
                split($index_position, pair, "=")
                if (pair[1] == key) { print substr($index_position, length(key) + 2); exit }
            }
        }
        END { }
    ' "$telemetry_log"
}

default_to_dash() {
    if [ -z "$1" ]; then printf -- '-\n'; else printf '%s\n' "$1"; fi
}

# The terminating sample is the one immediately preceding the abort line, which
# is the value an evidence document quotes. Reading it here keeps that
# quantity available after the record is compressed or archived.
terminating_sample=$(awk '
    /^sample_utc=/ { previous = $0 }
    /^abort_utc=/ { print previous; exit }
' "$telemetry_log")
terminating_mem_available_kib=$(printf '%s\n' "$terminating_sample" | awk '
    {
        for (index_position = 1; index_position <= NF; index_position++) {
            split($index_position, pair, "=")
            if (pair[1] == "mem_available_kib") { print substr($index_position, 19) }
        }
    }
')

# A qemu tenant is provenance rather than an addend: MemAvailable already
# integrates its pressure, and adding the RSS again repeats the double count
# that invalidated the original 9B host refusal.
qemu_pid=$(pgrep -x qemu-system-x86_64 2>/dev/null | head -1 || true)
if [ -z "$qemu_pid" ]; then
    qemu_pid=$(pgrep -f 'qemu-system-x86' 2>/dev/null | head -1 || true)
fi
qemu_start_ticks='-'
qemu_rss_kib='-'
if [ -n "$qemu_pid" ] && [ -r "/proc/$qemu_pid/stat" ]; then
    qemu_start_ticks=$(awk '{ print $22 }' "/proc/$qemu_pid/stat")
    qemu_rss_kib=$(awk '$1 == "VmRSS:" { print $2 }' "/proc/$qemu_pid/status" 2>/dev/null || true)
    qemu_rss_kib=$(default_to_dash "$qemu_rss_kib")
fi
qemu_pid=$(default_to_dash "$qemu_pid")

boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)

{
    printf 'telemetry_log=%s\n' "$telemetry_log"
    printf 'telemetry_log_sha256=%s\n' \
        "$(sha256sum "$telemetry_log" | cut -d ' ' -f 1)"
    printf 'model_id=%s\n' "$(default_to_dash "${QWEN_TELEMETRY_MODEL_ID:-}")"
    printf 'model_path=%s\n' "$(default_to_dash "${QWEN_TELEMETRY_MODEL_PATH:-}")"
    # The digest stays whatever the caller already knows. Hashing a five
    # gigabyte checkpoint on two 2.3 GHz cores inside a start that already
    # holds the readiness loop for up to 120 seconds costs more than the
    # field is worth, and each fetch script verifies the artifact it wrote.
    printf 'model_sha256=%s\n' "$(default_to_dash "${QWEN_TELEMETRY_MODEL_SHA256:-}")"
    printf 'llama_server_sha256=%s\n' \
        "$(default_to_dash "${QWEN_TELEMETRY_SERVER_SHA256:-}")"
    printf 'boot_id=%s\n' "$(default_to_dash "$boot_id")"
    printf 'server_pid=%s\n' "$(default_to_dash "$(field_of server_pid)")"
    printf 'qemu_pid=%s\n' "$qemu_pid"
    printf 'qemu_start_ticks=%s\n' "$qemu_start_ticks"
    printf 'qemu_rss_kib_at_summary=%s\n' "$qemu_rss_kib"
    printf 'monitor_start_utc=%s\n' \
        "$(default_to_dash "$(field_of monitor_start_utc)")"
    printf 'sample_seconds=%s\n' "$(default_to_dash "$(field_of sample_seconds)")"
    printf 'threshold_mem_available_kib=%s\n' \
        "$(default_to_dash "$(field_of threshold_mem_available_kib)")"
    printf 'threshold_swapin_bytes_per_sample=%s\n' \
        "$(default_to_dash "$(field_of threshold_swapin_bytes_per_sample)")"
    printf 'sample_count=%s\n' "$(sample_statistic mem_available_kib count)"
    printf 'initial_mem_available_kib=%s\n' \
        "$(default_to_dash "$(first_sample_of mem_available_kib)")"
    # `observed_minimum` rather than `minimum`: the monitor already spends
    # `minimum_mem_available_kib` on its 4194304 threshold, and one name for
    # a bound and for a measurement makes the record unreadable.
    printf 'observed_minimum_mem_available_kib=%s\n' \
        "$(sample_statistic mem_available_kib minimum)"
    printf 'cumulative_swapin_bytes=%s\n' "$(sample_statistic swapin_bytes total)"
    printf 'peak_server_rss_kib=%s\n' "$(sample_statistic peak_rss_kib maximum)"
    printf 'peak_gtt_used_bytes=%s\n' "$(sample_statistic gtt_used_bytes maximum)"
    printf 'peak_vram_used_bytes=%s\n' "$(sample_statistic vram_used_bytes maximum)"
    printf 'maximum_temperature_millicelsius=%s\n' \
        "$(sample_statistic max_temp_millicelsius maximum)"
    printf 'termination_reason=%s\n' \
        "$(default_to_dash "$(field_of reason)")"
    printf 'termination_sample_utc=%s\n' \
        "$(default_to_dash "$(field_of abort_utc)")"
    printf 'terminating_mem_available_kib=%s\n' \
        "$(default_to_dash "$terminating_mem_available_kib")"
} >"$summary_output"

printf 'telemetry_summary=%s\n' "$summary_output"
