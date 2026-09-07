#!/bin/sh
set -eu

# The stage record, driven through the writer and through two links of the
# launch chain against fixture processes.
#
# Three arms answer three questions. The writer's own arm fixes the row shape,
# the closed stage set, and the refusals a reader depends on: one row per stage,
# an end that never precedes its begin, and `-` accepted as an end a boundary
# never reached. The session arm runs the real qwen-webui-session.sh to
# `state=running` against a fake capacity server, so `server_exec` and
# `model_load` are measured across the same exec observation and readiness
# marker the appliance uses. The teardown arm runs the real qwen-teardown.sh
# against a fake control, so `teardown_signal_to_exit` comes from the wait loop
# rather than from a hand-written row.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
session_pid=''
cleanup_fixture() {
    if [ -n "$session_pid" ]; then
        kill -TERM "$session_pid" 2>/dev/null || true
        wait "$session_pid" 2>/dev/null || true
    fi
    chmod -R u+w "$temporary_directory" 2>/dev/null || true
    rm -rf "$temporary_directory"
}
trap cleanup_fixture EXIT HUP INT TERM

stage_timing=$script_directory/stage-timing.sh
summarizer=$script_directory/summarize-stage-timing.py

fail() {
    printf 'test-stage-timing: %s\n' "$1" >&2
    exit 1
}

# The stage row count, which every arm asserts against the stages it drove.
stage_rows() {
    awk -F '\t' -v name="$2" '$1 == "stage" && $2 == name' "$1" | wc -l | tr -d ' '
}

stage_field() {
    awk -F '\t' -v name="$2" -v column="$3" \
        '$1 == "stage" && $2 == name { print $column }' "$1"
}

# Every stage a record carries begins no later than it ends, and a stage the
# arm drove appears exactly once.
require_stage() {
    require_file=$1
    require_name=$2
    if [ "$(stage_rows "$require_file" "$require_name")" != 1 ]; then
        fail "$require_name appears other than once in $require_file"
    fi
    require_begin=$(stage_field "$require_file" "$require_name" 3)
    require_end=$(stage_field "$require_file" "$require_name" 4)
    case $require_begin in
        '' | *[!0-9]*) fail "$require_name carries no nanosecond begin" ;;
    esac
    if [ "$require_end" = - ]; then
        fail "$require_name recorded no end"
    fi
    case $require_end in
        '' | *[!0-9]*) fail "$require_name carries no nanosecond end" ;;
    esac
    if [ "$require_end" -lt "$require_begin" ]; then
        fail "$require_name ends before it begins"
    fi
}

# Arm one: the writer.
writer_record=$temporary_directory/writer.tsv
"$stage_timing" init "$writer_record"
grep -q '^# stage_timing clock=realtime' "$writer_record" ||
    fail 'init wrote no clock header'
first_stamp=$("$stage_timing" now)
case $first_stamp in
    '' | *[!0-9]*) fail 'now printed something other than nanoseconds' ;;
esac
"$stage_timing" record "$writer_record" server_exec 100 400
"$stage_timing" record "$writer_record" model_load 400 -
require_stage "$writer_record" server_exec
if [ "$(stage_field "$writer_record" model_load 4)" != - ]; then
    fail 'an unterminated stage did not record -'
fi
if "$stage_timing" record "$writer_record" server_exec 500 600 2>/dev/null; then
    fail 'a duplicate stage row was accepted'
fi
if "$stage_timing" record "$writer_record" launch_readiness 900 400 2>/dev/null; then
    fail 'a stage ending before it begins was accepted'
fi
if "$stage_timing" record "$writer_record" model_unload 1 2 2>/dev/null; then
    fail 'a stage outside the closed set was accepted'
fi
if "$stage_timing" record "$writer_record" launch_readiness abc 2 2>/dev/null; then
    fail 'a non-numeric begin was accepted'
fi
# A record absent where a stage is written gains the header rather than a bare
# row, which is what a teardown running against a launch that wrote none does.
absent_record=$temporary_directory/absent.tsv
"$stage_timing" record "$absent_record" teardown_signal_to_exit 10 20
grep -q '^# stage_timing clock=realtime' "$absent_record" ||
    fail 'a record created by a stage carries no clock header'
"$summarizer" stages "$writer_record" >/dev/null ||
    fail 'the summarizer refused a record carrying an unterminated stage'
if "$summarizer" stages "$writer_record" --require-terminated >/dev/null 2>&1; then
    fail '--require-terminated accepted an unterminated stage'
fi

# Arm two: the session, to state=running.
fixture_remote=$temporary_directory/remote
mkdir -p "$fixture_remote"
cp "$script_directory/qwen-webui-session.sh" "$script_directory/qwen-home.sh" \
    "$script_directory/stage-timing.sh" \
    "$script_directory/preserve-legacy-telemetry.sh" "$fixture_remote/"

# comm carries the basename of the file a process last exec'd, so the fixture
# server is a copy of a real executable rather than a script, whose comm would
# read as its interpreter. The capacity server prints the readiness marker and
# then execs it under the affinity and niceness the session requires.
fixture_server=$temporary_directory/fake-llama
cp "$(command -v sleep)" "$fixture_server"
cat >"$fixture_remote/run-qwen-capacity-server.sh" <<CAPACITY
#!/bin/sh
printf 'model loaded\n'
# renice sets an absolute niceness where nice adds to the caller's own, so
# the fixture reaches 19 whatever priority the test runner was started at.
renice -n 19 -p \$\$ >/dev/null
exec taskset -c 0 "$fixture_server" 600
CAPACITY
cat >"$fixture_remote/watch-qwen-kernel-hazards.sh" <<'HAZARD'
#!/bin/sh
printf 'watch_ready_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$2"
trap 'exit 0' HUP INT TERM
while :; do sleep 1; done
HAZARD
cat >"$fixture_remote/monitor-qwen-runtime.sh" <<'MONITOR'
#!/bin/sh
trap 'exit 0' HUP INT TERM
while :; do sleep 1; done
MONITOR
cat >"$fixture_remote/summarize-telemetry-session.sh" <<'SUMMARY'
#!/bin/sh
exit 0
SUMMARY
fixture_probe=$temporary_directory/fake-latency-probe
cat >"$fixture_probe" <<'PROBE'
#!/bin/sh
probe_log=''
while [ "$#" -gt 0 ]; do
    if [ "$1" = --log ]; then
        probe_log=$2
        shift
    fi
    shift
done
printf 'probe_start utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$probe_log"
trap 'exit 0' HUP INT TERM
while :; do sleep 1; done
PROBE
chmod +x "$fixture_remote"/*.sh "$fixture_probe"

session_state=$temporary_directory/session-state
mkdir -p "$session_state"
QWEN_VULKAN_LATENCY_PROBE=$fixture_probe \
QWEN_GPU_DEVICE_DIRECTORY=$temporary_directory/absent-gpu \
    "$fixture_remote/qwen-webui-session.sh" \
        "$fixture_server" "$temporary_directory/fake-model.gguf" '' \
        4096 4096 18080 "$session_state" low-serialized \
    >"$temporary_directory/session.stdout" \
    2>"$temporary_directory/session.stderr" &
session_pid=$!

session_record=$session_state/stage-timing.tsv
attempt=0
while [ "$attempt" -lt 600 ]; do
    if grep -q '^state=running ' "$session_state/session.status" 2>/dev/null; then
        break
    fi
    if ! kill -0 "$session_pid" 2>/dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done
if ! grep -q '^state=running ' "$session_state/session.status" 2>/dev/null; then
    printf 'session status:\n' >&2
    cat "$session_state/session.status" 2>/dev/null >&2 || true
    cat "$temporary_directory/session.stderr" >&2 || true
    fail 'the session never reported state=running'
fi

recorded_path=$(sed -n '1p' "$session_state/session.status" | tr ' ' '\n' |
    sed -n 's/^stage_timing=//p')
if [ "$recorded_path" != "$session_record" ]; then
    fail "the state=running line named $recorded_path rather than $session_record"
fi
require_stage "$session_record" server_exec
require_stage "$session_record" model_load
# The load runs from the exec observation to the readiness marker, so it begins
# exactly where the exec stage ends rather than at the spawn.
if [ "$(stage_field "$session_record" model_load 3)" != \
     "$(stage_field "$session_record" server_exec 4)" ]; then
    fail 'the load stage does not begin where the exec stage ends'
fi
"$summarizer" stages "$session_record" --require-terminated >/dev/null ||
    fail 'the summarizer refused the session record'

kill -TERM "$session_pid" 2>/dev/null || true
wait "$session_pid" 2>/dev/null || true
session_pid=''

# Arm three: the teardown, against a fake control and a server already gone.
teardown_remote=$temporary_directory/teardown-remote
teardown_bin=$temporary_directory/teardown-bin
mkdir -p "$teardown_remote" "$teardown_bin"
cp "$script_directory/qwen-teardown.sh" "$script_directory/qwen-home.sh" \
    "$script_directory/stage-timing.sh" "$teardown_remote/"
cat >"$teardown_remote/qwen-webui-control.sh" <<'CONTROL'
#!/bin/sh
exit 0
CONTROL
cat >"$teardown_remote/image-teardown-check.sh" <<'IMAGE'
#!/bin/sh
exit 0
IMAGE
cat >"$teardown_bin/pgrep" <<'PGREP'
#!/bin/sh
exit 1
PGREP
cat >"$teardown_bin/ss" <<'SS'
#!/bin/sh
exit 0
SS
chmod +x "$teardown_remote"/*.sh "$teardown_bin"/*

teardown_state=$temporary_directory/teardown-state
mkdir -p "$teardown_state"
teardown_record=$teardown_state/stage-timing.tsv
"$stage_timing" init "$teardown_record"
printf 'state=running server_pid=1 monitor_pid=2 latency_watchdog_pid=3 kernel_hazard_watchdog_pid=4 stage_timing=%s\n' \
    "$teardown_record" >"$teardown_state/session.status"
QWEN_WEBUI_STATE_DIRECTORY=$teardown_state PATH="$teardown_bin:$PATH" \
    "$teardown_remote/qwen-teardown.sh" \
    >"$temporary_directory/teardown.stdout" \
    2>"$temporary_directory/teardown.stderr" || true
require_stage "$teardown_record" teardown_signal_to_exit
"$summarizer" stages "$teardown_record" --require-terminated >/dev/null ||
    fail 'the summarizer refused the teardown record'

printf 'test-stage-timing: accepted\n' >&2
