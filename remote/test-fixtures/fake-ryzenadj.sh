#!/bin/sh
set -eu

# Stand in for ryzenadj so power-envelope.sh's writer runs without an SMU.
# `--info` prints the power-metrics table `main.c` emits at `%9.3lf` in watts
# from a fixture state file kept in milliwatts, and a `--FIELD=VALUE` write
# applies the milliwatt value the option documents, so the factor-of-a-
# thousand scale power-envelope.sh carries is exercised on both directions.
#
# QWEN_FAKE_RYZENADJ_STATE      TSV firmware state (field, milliwatt or
#                               milliampere value); seeded if absent
# QWEN_FAKE_RYZENADJ_CONTROLS   TSV control file: honor_writes,
#                               refuse_write_field, refuse_info
# QWEN_FAKE_RYZENADJ_LOG        every invocation is appended here as argv

state=${QWEN_FAKE_RYZENADJ_STATE:?}
controls=${QWEN_FAKE_RYZENADJ_CONTROLS:-}
log=${QWEN_FAKE_RYZENADJ_LOG:-}

control() {
    [ -n "$controls" ] && [ -r "$controls" ] || return 0
    awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' "$controls"
}
field() {
    [ -r "$state" ] || return 0
    awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' "$state"
}
set_field() {
    [ -r "$state" ] || : >"$state"
    awk -F'\t' -v key="$1" -v new="$2" '
        $1 == key { print key "\t" new; found = 1; next }
        { print }
        END { if (!found) print key "\t" new }' "$state" >"$state.new"
    mv -- "$state.new" "$state"
}

if [ ! -r "$state" ]; then
    {
        printf 'stapm_limit_mw\t15000\n'
        printf 'fast_limit_mw\t25000\n'
        printf 'slow_limit_mw\t20000\n'
        printf 'vrm_current_ma\t30000\n'
        printf 'vrmmax_current_ma\t45000\n'
        printf 'tctl_limit_c\t95\n'
    } >"$state"
fi

if [ -n "$log" ]; then
    printf 'ryzenadj' >>"$log"
    for argument in "$@"; do
        printf ' %s' "$argument" >>"$log"
    done
    printf '\n' >>"$log"
fi

if [ "${1:-}" = --info ]; then
    if [ "$(control refuse_info)" = 1 ]; then
        printf 'Unable to init ryzenadj\n' >&2
        exit 1
    fi
    milliwatts_to_units() {
        LC_ALL=C awk -v raw="$1" 'BEGIN { printf "%.3f\n", raw / 1000 }'
    }
    printf '|        Name         |   Value   |     Parameter      |\n'
    row() { printf '| %-19s | %9s | %-18s |\n' "$1" "$2" "$3"; }
    row 'STAPM LIMIT' "$(milliwatts_to_units "$(field stapm_limit_mw)")" stapm-limit
    row 'PPT LIMIT FAST' "$(milliwatts_to_units "$(field fast_limit_mw)")" fast-limit
    row 'PPT LIMIT SLOW' "$(milliwatts_to_units "$(field slow_limit_mw)")" slow-limit
    row 'TDC LIMIT VDD' "$(milliwatts_to_units "$(field vrm_current_ma)")" vrm-current
    row 'EDC LIMIT VDD' "$(milliwatts_to_units "$(field vrmmax_current_ma)")" vrmmax-current
    row 'THM LIMIT CORE' "$(field tctl_limit_c)" tctl-temp
    exit 0
fi

for argument in "$@"; do
    case $argument in
        --stapm-limit=*) written_field=stapm_limit_mw ;;
        --fast-limit=*) written_field=fast_limit_mw ;;
        --slow-limit=*) written_field=slow_limit_mw ;;
        --vrm-current=*) written_field=vrm_current_ma ;;
        --vrmmax-current=*) written_field=vrmmax_current_ma ;;
        *)
            printf 'unknown option: %s\n' "$argument" >&2
            exit 1
            ;;
    esac
    if [ "$(control refuse_writes)" = 1 ] || \
        [ "$(control refuse_write_field)" = "$written_field" ]; then
        printf 'Failed to set the value\n' >&2
        exit 1
    fi
    if [ "$(control honor_writes)" != 0 ]; then
        set_field "$written_field" "${argument#*=}"
    fi
done
exit 0
