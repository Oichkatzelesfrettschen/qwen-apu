#!/bin/sh
set -eu

# A reusable fake `ryzenadj`, standing for the firmware rather than for the
# command line. `--info` prints the state QWEN_FAKE_RYZENADJ_STATE holds in
# the markdown table `main.c` emits at `%9.3lf` in watts and amperes; a set
# option (`--stapm-limit=N`, and so on) applies the write in the milliwatts
# `README.md` documents, so the factor of a thousand between the read
# direction and the write direction is exercised the same way the real
# binary's is. Generalizes the fixture remote/test-power-envelope.sh built
# inline, for a caller that composes ryzenadj with another term.
#
# QWEN_FAKE_RYZENADJ_STATE names a tab-separated `field_name value` file
# carrying stapm_limit_mw, fast_limit_mw, slow_limit_mw, vrm_current_ma,
# vrmmax_current_ma, and tctl_limit_c. QWEN_FAKE_RYZENADJ_CONTROLS names a
# tab-separated `key value` file: `refuse_info 1` fails `--info`,
# `honor_writes 0` accepts every set option without applying it, and
# `refuse_write_field FIELD` fails the set option for that field alone.
# QWEN_FAKE_RYZENADJ_LOG, if named, receives one line per invocation.

firmware_state=${QWEN_FAKE_RYZENADJ_STATE:?QWEN_FAKE_RYZENADJ_STATE is required}
controls=${QWEN_FAKE_RYZENADJ_CONTROLS:-}
log=${QWEN_FAKE_RYZENADJ_LOG:-}

control() {
    [ -n "$controls" ] && [ -r "$controls" ] || return 0
    LC_ALL=C awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' \
        "$controls"
}
field() {
    LC_ALL=C awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' \
        "$firmware_state"
}
set_field() {
    LC_ALL=C awk -F'\t' -v key="$1" -v new="$2" '
        $1 == key { print key "\t" new; found = 1; next }
        { print }
        END { if (!found) print key "\t" new }' "$firmware_state" >"$firmware_state.new"
    mv -- "$firmware_state.new" "$firmware_state"
}

if [ -n "$log" ]; then
    printf 'ryzenadj' >>"$log"
    for log_argument in "$@"; do
        printf ' %s' "$log_argument" >>"$log"
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
    printf '|---------------------|-----------|--------------------|\n'
    row() { printf '| %-19s | %9s | %-18s |\n' "$1" "$2" "$3"; }
    row 'STAPM LIMIT' "$(milliwatts_to_units "$(field stapm_limit_mw)")" stapm-limit
    row 'PPT LIMIT FAST' "$(milliwatts_to_units "$(field fast_limit_mw)")" fast-limit
    row 'PPT LIMIT SLOW' "$(milliwatts_to_units "$(field slow_limit_mw)")" slow-limit
    row 'TDC LIMIT VDD' "$(milliwatts_to_units "$(field vrm_current_ma)")" vrm-current
    row 'EDC LIMIT VDD' "$(milliwatts_to_units "$(field vrmmax_current_ma)")" vrmmax-current
    row 'THM LIMIT CORE' "$(field tctl_limit_c)" tctl-temp
    exit 0
fi

for invocation_argument in "$@"; do
    case $invocation_argument in
        --stapm-limit=*) written_field=stapm_limit_mw ;;
        --fast-limit=*) written_field=fast_limit_mw ;;
        --slow-limit=*) written_field=slow_limit_mw ;;
        --vrm-current=*) written_field=vrm_current_ma ;;
        --vrmmax-current=*) written_field=vrmmax_current_ma ;;
        *)
            printf 'unknown option: %s\n' "$invocation_argument" >&2
            exit 1
            ;;
    esac
    if [ "$(control refuse_writes)" = 1 ] ||
        [ "$(control refuse_write_field)" = "$written_field" ]; then
        printf 'Failed to set the value\n' >&2
        exit 1
    fi
    if [ "$(control honor_writes)" != 0 ]; then
        set_field "$written_field" "${invocation_argument#*=}"
    fi
done
exit 0
