#!/bin/sh
set -eu

# Stand in for cpupower so cpu-frequency-cap.sh's writer runs without a CPU.
# `--cpu N frequency-set -u FREQ` and `-g GOVERNOR` write directly into a
# fixture sysfs tree, the way the real tool moves the kernel's own cpufreq
# policy, and a control file decides whether a write is honored, so the
# read-back verification the caller performs is exercised rather than
# restated.
#
# QWEN_FAKE_CPUPOWER_SYSFS_ROOT   sysfs fixture root, holding
#                                 devices/system/cpu/cpuN/cpufreq/*
# QWEN_FAKE_CPUPOWER_CONTROLS     TSV file read for refuse_writes and
#                                 refuse_cpu (a CPU number)
# QWEN_FAKE_CPUPOWER_LOG          every invocation is appended here as argv

sysfs_root=${QWEN_FAKE_CPUPOWER_SYSFS_ROOT:?}
controls=${QWEN_FAKE_CPUPOWER_CONTROLS:-}
log=${QWEN_FAKE_CPUPOWER_LOG:-}
cpu_root=$sysfs_root/devices/system/cpu

control() {
    [ -n "$controls" ] && [ -r "$controls" ] || return 0
    awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' "$controls"
}

if [ -n "$log" ]; then
    printf 'cpupower' >>"$log"
    for argument in "$@"; do
        printf ' %s' "$argument" >>"$log"
    done
    printf '\n' >>"$log"
fi

target_cpu=''
subcommand=''
mode=''
value=''
previous=''
for argument in "$@"; do
    case $previous in
        --cpu) target_cpu=$argument ;;
        -u) mode=upper; value=$argument ;;
        -g) mode=governor; value=$argument ;;
    esac
    case $argument in
        frequency-set) subcommand=frequency-set ;;
    esac
    previous=$argument
done

if [ "$subcommand" != frequency-set ] || [ -z "$target_cpu" ] || [ -z "$mode" ]; then
    printf 'unsupported invocation\n' >&2
    exit 1
fi
if [ "$(control refuse_writes)" = 1 ] || [ "$(control refuse_cpu)" = "$target_cpu" ] || \
    [ "$(control refuse_upper_value)" = "$value" ]; then
    printf 'Error setting values\n' >&2
    exit 1
fi

case $mode in
    upper)
        case $value in
            *MHz) khz=$((${value%MHz} * 1000)) ;;
            *KHz) khz=${value%KHz} ;;
            *) khz=$value ;;
        esac
        printf '%s\n' "$khz" >"$cpu_root/cpu$target_cpu/cpufreq/scaling_max_freq"
        ;;
    governor)
        printf '%s\n' "$value" >"$cpu_root/cpu$target_cpu/cpufreq/scaling_governor"
        ;;
esac
exit 0
