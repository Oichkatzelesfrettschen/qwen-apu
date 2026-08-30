#!/bin/sh
set -eu

# Place the calling process at nice 19 and the idle I/O class, prove both from
# the kernel, then replace this shell with the command.
#
# `nice -n 19` adds 19 to the caller's own value, so a launcher started below
# nice 0 lands its workload above 19. `renice --priority 19` writes the
# absolute value through setpriority(2), and field 19 of /proc/PID/stat reads
# the kernel value back, because the request and the applied value are two
# claims. ionice(1) writes the idle class the same way and the class is read
# back the same way. Both readbacks name the value the kernel holds for this
# pid; a mismatch ends the wrapper with status 125 and the command never
# starts.
#
# exec(2) keeps the pid, the session, the process group, the nice value, and
# the I/O class, so a parent that recorded this wrapper's pid at spawn holds the
# pid of the command it later signals, and the command inherits the priority
# the kernel confirmed rather than a request it might not honour.
#
# Every utility is named by its fixed path, so PATH cannot substitute one. The
# QWEN_IDLE_PRIORITY_RENICE, QWEN_IDLE_PRIORITY_PROC_STAT,
# QWEN_IDLE_PRIORITY_AWK, and QWEN_IDLE_PRIORITY_IONICE variables override
# those paths, which is what lets
# a test stand in a renice that applies nothing or an ionice that reports
# best-effort without root.

if [ "$#" -lt 1 ]; then
    printf 'usage: %s COMMAND [ARGUMENT...]\n' "$0" >&2
    exit 2
fi

renice_program=${QWEN_IDLE_PRIORITY_RENICE:-/usr/bin/renice}
proc_stat_path=${QWEN_IDLE_PRIORITY_PROC_STAT:-/proc/$$/stat}
awk_program=${QWEN_IDLE_PRIORITY_AWK:-/usr/bin/awk}
ionice_program=${QWEN_IDLE_PRIORITY_IONICE:-/usr/bin/ionice}
required_nice=19

"$renice_program" --priority "$required_nice" --pid "$$" >/dev/null 2>&1 || true
observed_nice=$(LC_ALL=C "$awk_program" '
    {
        stat_line = $0
        sub(/^.*[)] /, "", stat_line)
        field_count = split(stat_line, fields, /[[:space:]]+/)
        if (field_count >= 17) print fields[17]
        exit
    }
' "$proc_stat_path" 2>/dev/null || true)
if [ "$observed_nice" != "$required_nice" ]; then
    printf 'priority setup refused: requested=%s observed=%s\n' \
        "$required_nice" "${observed_nice:-unreadable}" >&2
    exit 125
fi

"$ionice_program" -c 3 -p "$$" >/dev/null 2>&1 || true
observed_ioclass=$(LC_ALL=C "$ionice_program" -p "$$" 2>/dev/null |
    "$awk_program" '{ print $1; exit }')
case $observed_ioclass in
    idle | idle:) ;;
    *)
        printf 'io class setup refused: requested=idle observed=%s\n' \
            "${observed_ioclass:-unreadable}" >&2
        exit 125
        ;;
esac

exec "$@"
