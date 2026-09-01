#!/bin/sh
set -eu

# Model the campaign-owned emergency teardown without touching workstation
# state. The runner-SIGKILL case pauses after entry so the test can prove that
# the campaign retains the host-wide Vulkan lease throughout recovery.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

result_directory=${QWEN_RESULT_DIRECTORY:?}
campaign_directory=$(dirname -- "$(dirname -- "$result_directory")")
control_directory=$campaign_directory.control
arm_name=$(basename -- "$result_directory")
slot=${arm_name%%-*}
mkdir -p -- "$control_directory"
printf '%s\n' "$slot" >>"$control_directory/emergency-teardown-invocations.tsv"
emergency_attempt=$(awk -v expected_slot="$slot" \
    '$1 == expected_slot { attempts++ } END { print attempts + 0 }' \
    "$control_directory/emergency-teardown-invocations.tsv")
forced_failure_path=$control_directory/emergency-teardown-failures-$slot
forced_failures=0
if [ -r "$forced_failure_path" ]; then
    forced_failures=$(sed -n '1p' "$forced_failure_path")
fi
case $forced_failures in
    '' | *[!0-9]*)
        printf 'fake emergency teardown failure count is malformed: %s\n' \
            "$forced_failures" >&2
        exit 2
        ;;
esac
if [ "$emergency_attempt" -le "$forced_failures" ]; then
    printf 'fake emergency teardown forced failure attempt=%s slot=%s\n' \
        "$emergency_attempt" "$slot" >&2
    exit 47
fi

ready_marker=$control_directory/runner-sigkill-ready-$slot
if [ ! -s "$ready_marker" ]; then
    printf 'fake emergency teardown completed slot=%s detached_workload=absent\n' \
        "$slot"
    exit 0
fi

workload_witness=$control_directory/detached-workload-$slot.tsv
workload_term_witness=$control_directory/detached-workload-term-$slot.tsv
teardown_entered=$control_directory/emergency-teardown-entered-$slot.tsv
teardown_release=$control_directory/emergency-teardown-release-$slot
teardown_completed=$control_directory/emergency-teardown-completed-$slot.tsv

workload_row=$(awk -F '\t' 'NR == 2 { print; rows++ }
    END { exit rows == 1 ? 0 : 1 }
' "$workload_witness") || {
    printf 'detached workload witness is absent or malformed: %s\n' \
        "$workload_witness" >&2
    exit 41
}
tab=$(printf '\t')
IFS="$tab" read -r workload_pid workload_start_time workload_parent \
    workload_process_group workload_session fd8_state fd9_state <<EOF
$workload_row
EOF
case $workload_pid:$workload_start_time in
    *[!0-9:]* | :* | *:)
        printf 'detached workload identity is malformed\n' >&2
        exit 42
        ;;
esac
case $workload_parent:$workload_process_group:$workload_session in
    *[!0-9:]* | :* | *:)
        printf 'detached workload topology is malformed\n' >&2
        exit 42
        ;;
esac
if [ "$workload_process_group" != "$workload_pid" ] || \
   [ "$workload_session" != "$workload_pid" ]; then
    printf 'detached workload does not own its process group and session\n' >&2
    exit 42
fi
if [ "$fd8_state" != closed ] || [ "$fd9_state" != closed ]; then
    printf 'detached workload inherited a campaign lease descriptor\n' >&2
    exit 42
fi

printf 'slot\tpid\tstart_time_ticks\tstate\n%s\t%s\t%s\tentered\n' \
    "$slot" "$workload_pid" "$workload_start_time" >"$teardown_entered"
release_wait=0
while [ ! -s "$teardown_release" ] && [ "$release_wait" -lt 250 ]; do
    sleep 0.02
    release_wait=$((release_wait + 1))
done
if [ ! -s "$teardown_release" ]; then
    printf 'emergency teardown release marker is absent: %s\n' \
        "$teardown_release" >&2
    exit 43
fi

observed_start_time=$(sed 's/^.*) //' "/proc/$workload_pid/stat" 2>/dev/null | \
    awk '{ print $20 }')
if [ "$observed_start_time" != "$workload_start_time" ]; then
    printf 'detached workload identity changed before teardown\n' >&2
    exit 44
fi
kill -TERM "$workload_pid"

stop_wait=0
while [ -r "/proc/$workload_pid/stat" ] && [ "$stop_wait" -lt 250 ]; do
    workload_state=$(sed 's/^.*) //' "/proc/$workload_pid/stat" 2>/dev/null | \
        awk '{ print $1 }')
    [ -n "$workload_state" ] || break
    [ "$workload_state" != Z ] || break
    sleep 0.02
    stop_wait=$((stop_wait + 1))
done
if [ -r "/proc/$workload_pid/stat" ]; then
    workload_state=$(sed 's/^.*) //' "/proc/$workload_pid/stat" 2>/dev/null | \
        awk '{ print $1 }')
    if [ -n "$workload_state" ] && [ "$workload_state" != Z ]; then
        printf 'detached workload survived emergency teardown: pid=%s\n' \
            "$workload_pid" >&2
        exit 45
    fi
fi
awk -F '\t' -v expected_pid="$workload_pid" \
    -v expected_start="$workload_start_time" '
    NR == 2 && $1 == expected_pid && $2 == expected_start &&
        $3 == "SIGTERM" && $4 == "observed" { accepted = 1 }
    END { exit accepted ? 0 : 1 }
' "$workload_term_witness" || {
    printf 'detached workload TERM witness is absent or malformed\n' >&2
    exit 46
}

printf 'fake emergency teardown slot=%s pid=%s start_time_ticks=%s\n' \
    "$slot" "$workload_pid" "$workload_start_time" \
    >"$result_directory/teardown.txt"
printf 'slot\tpid\tstart_time_ticks\tsignal\tstate\n%s\t%s\t%s\tTERM\tstopped\n' \
    "$slot" "$workload_pid" "$workload_start_time" >"$teardown_completed"
printf 'fake emergency teardown completed slot=%s pid=%s\n' \
    "$slot" "$workload_pid"
