#!/bin/sh
set -eu

# Exercise qwen-exec-idle-priority.sh without root. The kernel is the authority
# for every positive check: the exec'd command reads its own nice through procfs
# and its own pid through $$, so a wrapper that only claimed the priority or
# forked a child would fail here. The refusal arms substitute a renice that
# applies nothing and an ionice that reports best-effort, which is how a
# missing renice call and an unhonoured I/O class are made observable on a
# workstation whose caller cannot lower its own priority.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
wrapper=$script_directory/qwen-exec-idle-priority.sh
temporary_directory=$(mktemp -d)
active_fixture=initialization
cleanup() {
    cleanup_status=$?
    if [ "$cleanup_status" -ne 0 ]; then
        printf 'idle priority fixture failed: %s (status %s)\n' \
            "$active_fixture" "$cleanup_status" >&2
    fi
    rm -rf -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

active_fixture=usage
if "$wrapper" >/dev/null 2>"$temporary_directory/usage.stderr"; then
    printf 'the wrapper accepted an empty command\n' >&2
    exit 1
fi
grep -F 'usage:' "$temporary_directory/usage.stderr" >/dev/null

active_fixture=exec-from-nice-5
report=$temporary_directory/report
nice -n 5 "$wrapper" sh -c \
    'printf "pid=%s nice=%s ioclass=%s\n" "$$" "$(LC_ALL=C /usr/bin/awk '\''{ line = $0; sub(/^.*[)] /, "", line); split(line, fields, /[[:space:]]+/); print fields[17] }'\'' /proc/$$/stat)" "$(LC_ALL=C /usr/bin/ionice -p $$ | /usr/bin/awk "{ print \$1 }")"' \
    >"$report"
child_nice=$(sed -n 's/.* nice=\([^ ]*\).*/\1/p' "$report")
child_ioclass=$(sed -n 's/.* ioclass=\([^ ]*\).*/\1/p' "$report")
if [ "$child_nice" != 19 ]; then
    printf 'the exec target reports nice %s rather than 19: %s\n' \
        "$child_nice" "$(cat "$report")" >&2
    exit 1
fi
case $child_ioclass in
    idle | idle:) ;;
    *)
        printf 'the exec target reports I/O class %s rather than idle\n' \
            "$child_ioclass" >&2
        exit 1
        ;;
esac

active_fixture=exec-keeps-the-pid
pid_report=$temporary_directory/pid-report
# The wrapper is launched in the background so its pid is known to this shell,
# and the exec'd command prints its own $$; the two agree exactly when exec
# replaced the wrapper in place rather than forking the command.
"$wrapper" sh -c 'printf "%s\n" "$$"' >"$pid_report" &
launched_pid=$!
wait "$launched_pid"
if [ "$(cat "$pid_report")" != "$launched_pid" ]; then
    printf 'the exec target pid %s differs from the launched wrapper pid %s\n' \
        "$(cat "$pid_report")" "$launched_pid" >&2
    exit 1
fi

active_fixture=renice-applies-nothing
fake_renice=$temporary_directory/renice
printf '#!/bin/sh\nexit 0\n' >"$fake_renice"
chmod +x "$fake_renice"
marker=$temporary_directory/ran-after-fake-renice
fake_nonrequired_stat=$temporary_directory/nonrequired-stat
LC_ALL=C /usr/bin/awk '
    {
        stat_line = $0
        sub(/^.*[)] /, "", stat_line)
        field_count = split(stat_line, fields, /[[:space:]]+/)
        fields[17] = 5
        printf "1 (fixture)"
        for (field_index = 1; field_index <= field_count; field_index++) {
            printf " %s", fields[field_index]
        }
        printf "\n"
    }
' "/proc/$$/stat" >"$fake_nonrequired_stat"
if QWEN_IDLE_PRIORITY_RENICE=$fake_renice \
    QWEN_IDLE_PRIORITY_PROC_STAT=$fake_nonrequired_stat \
    nice -n 5 "$wrapper" \
    sh -c "touch '$marker'" 2>"$temporary_directory/renice.stderr"; then
    printf 'the wrapper ran its command after renice applied nothing\n' >&2
    exit 1
fi
if [ -e "$marker" ]; then
    printf 'the command ran although the priority was refused\n' >&2
    exit 1
fi
grep -F 'priority setup refused: requested=19 observed=' \
    "$temporary_directory/renice.stderr" >/dev/null

active_fixture=renice-status-is-125
set +e
QWEN_IDLE_PRIORITY_RENICE=$fake_renice \
QWEN_IDLE_PRIORITY_PROC_STAT=$fake_nonrequired_stat \
    nice -n 5 "$wrapper" true 2>/dev/null
refused_status=$?
set -e
if [ "$refused_status" -ne 125 ]; then
    printf 'a refused priority exited %s rather than 125\n' "$refused_status" >&2
    exit 1
fi

active_fixture=proc-stat-unreadable
missing_proc_stat=$temporary_directory/missing-stat
set +e
QWEN_IDLE_PRIORITY_PROC_STAT=$missing_proc_stat "$wrapper" \
    sh -c "touch '$marker'" 2>"$temporary_directory/proc-stat.stderr"
unreadable_status=$?
set -e
if [ "$unreadable_status" -ne 125 ] || [ -e "$marker" ]; then
    printf 'an unreadable priority did not refuse with 125 (status %s)\n' \
        "$unreadable_status" >&2
    exit 1
fi
grep -F 'observed=unreadable' "$temporary_directory/proc-stat.stderr" >/dev/null

active_fixture=ionice-reports-best-effort
fake_ionice=$temporary_directory/ionice
# `-c 3 -p PID` is accepted silently and `-p PID` alone answers best-effort,
# which is the shape of an ionice whose write the kernel declined.
cat >"$fake_ionice" <<'EOF'
#!/bin/sh
case $1 in
    -c) exit 0 ;;
    *) printf 'best-effort: prio 4\n' ;;
esac
EOF
chmod +x "$fake_ionice"
set +e
QWEN_IDLE_PRIORITY_IONICE=$fake_ionice "$wrapper" sh -c "touch '$marker'" \
    2>"$temporary_directory/ionice.stderr"
ionice_status=$?
set -e
if [ "$ionice_status" -ne 125 ] || [ -e "$marker" ]; then
    printf 'a best-effort I/O class did not refuse with 125 (status %s)\n' \
        "$ionice_status" >&2
    exit 1
fi
grep -F 'io class setup refused: requested=idle observed=best-effort' \
    "$temporary_directory/ionice.stderr" >/dev/null

active_fixture=command-status-passes-through
set +e
"$wrapper" sh -c 'exit 7'
through_status=$?
set -e
if [ "$through_status" -ne 7 ]; then
    printf 'the command exit status %s did not pass through\n' "$through_status" >&2
    exit 1
fi

printf 'idle_priority_wrapper=passed fixtures=8\n'
