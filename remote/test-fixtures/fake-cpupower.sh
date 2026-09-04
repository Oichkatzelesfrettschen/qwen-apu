#!/bin/sh
set -eu

# A reusable fake `cpupower`, standing for the writer rather than for the
# kernel: `--cpu N frequency-set -u FREQ -g GOVERNOR` writes
# QWEN_FAKE_CPUPOWER_CPU_ROOT/cpuN/cpufreq/scaling_max_freq and
# scaling_governor directly, the same files remote/cpu-frequency-cap.sh reads
# back through sysfs, so the fake models the write path without modeling the
# read path a second time.
#
# QWEN_FAKE_CPUPOWER_CPU_ROOT names the `cpu` devices root (the fixture's
# `.../devices/system/cpu`). QWEN_FAKE_CPUPOWER_CONTROLS names a
# tab-separated `key value` file: `refuse_writes 1` fails every write, and
# `refuse_cpu N` fails the write for cpu N alone. Every invocation is
# appended to QWEN_FAKE_CPUPOWER_LOG, so the exact argv a term built is
# provable.
#
# `-u` accepts a bare integer, or an integer suffixed `kHz`/`KHz`/`MHz`/`GHz`
# the way the real binary's frequency parser does; the value is normalized to
# kilohertz before it is written, so a caller passing `2.3GHz` and a caller
# passing `2300000kHz` are read back identically.

cpu_root=${QWEN_FAKE_CPUPOWER_CPU_ROOT:?QWEN_FAKE_CPUPOWER_CPU_ROOT is required}
controls=${QWEN_FAKE_CPUPOWER_CONTROLS:-}
log=${QWEN_FAKE_CPUPOWER_LOG:-}

control() {
    [ -n "$controls" ] && [ -r "$controls" ] || return 0
    LC_ALL=C awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' \
        "$controls"
}

if [ -n "$log" ]; then
    printf 'cpupower' >>"$log"
    for log_argument in "$@"; do
        printf ' %s' "$log_argument" >>"$log"
    done
    printf '\n' >>"$log"
fi

normalize_khz() {
    LC_ALL=C awk -v raw="$1" 'BEGIN {
        value = raw
        unit = 1
        if (value ~ /[Gg][Hh][Zz]$/) { unit = 1000000; sub(/[Gg][Hh][Zz]$/, "", value) }
        else if (value ~ /[Mm][Hh][Zz]$/) { unit = 1000; sub(/[Mm][Hh][Zz]$/, "", value) }
        else if (value ~ /[Kk][Hh][Zz]$/) { unit = 1; sub(/[Kk][Hh][Zz]$/, "", value) }
        printf "%d\n", (value + 0) * unit
    }'
}

target_cpu=''
upper_value=''
governor_value=''
subcommand=''
while [ "$#" -gt 0 ]; do
    case $1 in
        --cpu)
            target_cpu=$2
            shift 2
            ;;
        frequency-set) subcommand=frequency-set; shift ;;
        frequency-info | -b | --boost) subcommand=frequency-info; shift ;;
        -u)
            upper_value=$(normalize_khz "$2")
            shift 2
            ;;
        -g)
            governor_value=$2
            shift 2
            ;;
        *) shift ;;
    esac
done

if [ "$subcommand" = frequency-info ]; then
    printf 'boost state support:\n'
    printf '  Supported: no\n'
    printf '  Active: no\n'
    exit 0
fi

if [ "$subcommand" != frequency-set ] || [ -z "$target_cpu" ]; then
    printf 'fake-cpupower: unsupported invocation\n' >&2
    exit 1
fi

if [ "$(control refuse_writes)" = 1 ] || [ "$(control refuse_cpu)" = "$target_cpu" ]; then
    printf 'Error setting new values. Common errors:\n' >&2
    exit 1
fi

policy_directory=$cpu_root/cpu$target_cpu/cpufreq
if [ ! -d "$policy_directory" ]; then
    printf 'fake-cpupower: no such policy: %s\n' "$policy_directory" >&2
    exit 1
fi
if [ -n "$upper_value" ]; then
    printf '%s\n' "$upper_value" >"$policy_directory/scaling_max_freq"
fi
if [ -n "$governor_value" ]; then
    printf '%s\n' "$governor_value" >"$policy_directory/scaling_governor"
fi
exit 0
