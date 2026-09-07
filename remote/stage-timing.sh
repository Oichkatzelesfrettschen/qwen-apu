#!/bin/sh
set -eu

# The one writer of $QWEN_HOME/state/stage-timing.tsv, the record of when each
# launch-chain boundary was crossed. The launch chain states configured
# deadlines -- 120 seconds of readiness loop, a 2-second SIGKILL grace, a 30 s
# tool timeout -- and states no elapsed interval, so a slow launch is
# indistinguishable from a fast one in every retained artifact. This file
# records the intervals themselves.
#
# The clock is CLOCK_REALTIME through `date +%s%N`, the clock
# `gate-cell-key.sh` already times cells on. Each stamp forks `date`, about two
# milliseconds, which bounds what an interval of a few milliseconds can be read
# to mean; a launch stage is seconds, so the fork sits four orders below the
# measurement. Realtime rather than monotonic is what makes a stamp taken by
# the session comparable with one taken by the teardown, and it costs the one
# falsifier the record names: an NTP step inside a launch window moves a
# duration, and a negative or implausible interval is that step rather than the
# appliance.
#
# A stage is one row and one row only. `record` refuses a duplicate name, so a
# reader takes the row rather than the first row, and it accepts `-` as an end
# for a stage whose boundary never arrived -- a load terminated on the memory
# reserve, a readiness loop that expired, a teardown that timed out waiting for
# the server to leave. That row is the finding on exactly the launches worth
# explaining, so the summarizer refuses it rather than reading it as zero.
#
# Every caller in the launch chain appends `|| :` to its own invocation: a
# measurement records what a launch did and never decides whether it proceeds.

usage() {
    printf 'usage: %s now\n' "$0" >&2
    printf '       %s init FILE\n' "$0" >&2
    printf '       %s record FILE NAME BEGIN_NS END_NS\n' "$0" >&2
    exit 2
}

# The closed set exists so a typo in one link of the chain reads as a refusal
# rather than as a stage no summarizer knows to expect.
stage_timing_names='server_exec model_load launch_readiness teardown_signal_to_exit'
stage_timing_header='# stage_timing clock=realtime source=date +%s%N'

stage_timing_is_digits() {
    case ${1:-} in
        '' | *[!0-9]*) return 1 ;;
    esac
    return 0
}

command_name=${1:-}
[ -n "$command_name" ] || usage
shift

case $command_name in
    now)
        [ "$#" -eq 0 ] || usage
        date +%s%N
        ;;
    init)
        [ "$#" -eq 1 ] || usage
        printf '%s\n' "$stage_timing_header" >"$1"
        ;;
    record)
        [ "$#" -eq 4 ] || usage
        stage_timing_file=$1
        stage_name=$2
        stage_begin_ns=$3
        stage_end_ns=$4
        stage_name_known=0
        for stage_timing_candidate in $stage_timing_names; do
            [ "$stage_timing_candidate" = "$stage_name" ] || continue
            stage_name_known=1
            break
        done
        if [ "$stage_name_known" -ne 1 ]; then
            printf 'stage-timing: %s names no stage this record carries\n' \
                "$stage_name" >&2
            exit 1
        fi
        if ! stage_timing_is_digits "$stage_begin_ns"; then
            printf 'stage-timing: %s carries a begin that is not nanoseconds: %s\n' \
                "$stage_name" "$stage_begin_ns" >&2
            exit 1
        fi
        if [ "$stage_end_ns" != - ]; then
            if ! stage_timing_is_digits "$stage_end_ns"; then
                printf 'stage-timing: %s carries an end that is neither nanoseconds nor -: %s\n' \
                    "$stage_name" "$stage_end_ns" >&2
                exit 1
            fi
            if [ "$stage_end_ns" -lt "$stage_begin_ns" ]; then
                printf 'stage-timing: %s ends before it begins: %s %s\n' \
                    "$stage_name" "$stage_begin_ns" "$stage_end_ns" >&2
                exit 1
            fi
        fi
        # A teardown runs against a launch that wrote no record, so the header
        # is written here where the file is absent rather than requiring an
        # init that only the session performs.
        if [ ! -f "$stage_timing_file" ]; then
            printf '%s\n' "$stage_timing_header" >"$stage_timing_file"
        elif awk -F '\t' -v name="$stage_name" \
            '$1 == "stage" && $2 == name { found = 1 } END { exit found ? 0 : 1 }' \
            "$stage_timing_file"; then
            printf 'stage-timing: %s already carries a row in %s\n' \
                "$stage_name" "$stage_timing_file" >&2
            exit 1
        fi
        printf 'stage\t%s\t%s\t%s\n' \
            "$stage_name" "$stage_begin_ns" "$stage_end_ns" \
            >>"$stage_timing_file"
        ;;
    *)
        usage
        ;;
esac
