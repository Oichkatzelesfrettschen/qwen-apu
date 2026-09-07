#!/bin/sh
set -eu

# The one writer of the launch chain's elapsed boundaries. The chain states
# configured deadlines -- 1200 readiness attempts at 0.1 s, a two-second SIGKILL
# grace, a 30000 ms tool timeout -- and states no elapsed interval, so a slow
# launch is indistinguishable from a fast one in every retained artifact. This
# file records the intervals themselves.
#
# A duration is measured on CLOCK_MONOTONIC through `time.monotonic_ns()`, which
# counts from an origin Linux fixes per boot and shares across every process in
# one time namespace, so a stamp the session took and a stamp the teardown takes
# minutes later in another process subtract correctly and neither an NTP step
# nor a manual clock set moves the result. The record binds the boot it was
# taken in: `/proc/sys/kernel/random/boot_id` changes across a reboot and a
# monotonic value from one boot subtracted from another's is arithmetic over two
# origins, so `record` refuses a row whose boot identity differs from the
# header's.
#
# Chronology is a separate claim and takes a separate clock. The header carries
# one CLOCK_REALTIME timestamp naming when the record was opened, which orders
# one record against another and against a telemetry log, and every duration in
# the file comes from the monotonic pair beside it.
#
# A record belongs to one launch and outlives it. `init` names a session-unique
# file and points a convenience symlink at it, the shape the telemetry records
# already take, so a later launch leaves an earlier record byte for byte rather
# than truncating the one artifact that explains a slow start.
#
# A stage is one row and one row only. `record` refuses a duplicate name, so a
# reader takes the row rather than the first row, and it accepts `-` as an end
# for a stage whose boundary never arrived -- a load terminated on the memory
# reserve, a readiness loop that expired, a teardown whose wait ran out. That
# row is the finding on exactly the launches worth explaining, so the summarizer
# refuses it rather than reading it as zero.
#
# Every caller in the launch chain appends `|| :` to its own invocation: a
# measurement records what a launch did and never decides whether it proceeds.

usage() {
    printf 'usage: %s now\n' "$0" >&2
    printf '       %s boot-id\n' "$0" >&2
    printf '       %s init DIRECTORY SYMLINK\n' "$0" >&2
    printf '       %s record FILE NAME BEGIN_NS END_NS\n' "$0" >&2
    exit 2
}

# The closed set exists so a typo in one link of the chain reads as a refusal
# rather than as a stage no summarizer knows to expect.
stage_timing_names='server_exec model_load launch_readiness teardown_signal_to_exit'

stage_timing_is_digits() {
    case ${1:-} in
        '' | *[!0-9]*) return 1 ;;
    esac
    return 0
}

# The boot this record's monotonic origin belongs to. A host exposing no such
# attribute reads `unknown`, which the header carries and the comparison then
# admits against itself alone.
stage_timing_boot_id() {
    if [ -r /proc/sys/kernel/random/boot_id ]; then
        sed -n 1p /proc/sys/kernel/random/boot_id
    else
        printf 'unknown\n'
    fi
}

command_name=${1:-}
[ -n "$command_name" ] || usage
shift

case $command_name in
    now)
        [ "$#" -eq 0 ] || usage
        # CLOCK_MONOTONIC reaches a shell through an interpreter, since `date`
        # reads CLOCK_REALTIME alone. The interpreter start is tens of
        # milliseconds, three orders below the seconds a launch stage takes and
        # the bound on what a stage of a few milliseconds could be read to mean.
        python3 -c 'import time; print(time.monotonic_ns())'
        ;;
    boot-id)
        [ "$#" -eq 0 ] || usage
        stage_timing_boot_id
        ;;
    init)
        [ "$#" -eq 2 ] || usage
        stage_timing_directory=$1
        stage_timing_symlink=$2
        mkdir -p "$stage_timing_directory"
        # The name carries the opening wall time and the opening process, so two
        # launches never collide and an aborted launch's record survives every
        # later one. The path is printed, since the caller records that exact
        # file rather than the symlink a later launch moves.
        stage_timing_name=$(date -u +%Y%m%dT%H%M%SZ)-pid$$
        stage_timing_file=$stage_timing_directory/$stage_timing_name.tsv
        printf '# stage_timing clock=monotonic source=time.monotonic_ns boot_id=%s opened_utc=%s record=%s\n' \
            "$(stage_timing_boot_id)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            "$stage_timing_name" >"$stage_timing_file"
        ln -sfn "$(basename -- "$stage_timing_directory")/$stage_timing_name.tsv" \
            "$stage_timing_symlink"
        printf '%s\n' "$stage_timing_file"
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
        # A record is opened by `init` and appended to by the links that follow,
        # so an absent file names a launch whose session never opened one rather
        # than a record to create here: a header written now would claim this
        # process's boot for stamps another process took.
        if [ ! -f "$stage_timing_file" ]; then
            printf 'stage-timing: %s names no record, which init opens\n' \
                "$stage_timing_file" >&2
            exit 1
        fi
        # The stamps are monotonic, so they mean nothing against a record opened
        # in another boot. A teardown reaching a record the machine has rebooted
        # since would otherwise subtract two origins and print a duration.
        stage_timing_header_boot=$(sed -n \
            's/^# stage_timing .*boot_id=\([^ ]*\).*/\1/p' \
            "$stage_timing_file" | sed -n 1p)
        if [ -z "$stage_timing_header_boot" ]; then
            printf 'stage-timing: %s carries no boot identity\n' \
                "$stage_timing_file" >&2
            exit 1
        fi
        if [ "$stage_timing_header_boot" != "$(stage_timing_boot_id)" ]; then
            printf 'stage-timing: %s was opened in boot %s and this stamp belongs to another\n' \
                "$stage_timing_file" "$stage_timing_header_boot" >&2
            exit 1
        fi
        if awk -F '\t' -v name="$stage_name" \
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
