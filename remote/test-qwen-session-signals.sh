#!/bin/sh
set -eu

# The tmux session process owns the server and router snapshot. Each terminating
# signal must stop both resources and return the conventional signal status
# instead of resuming the readiness loop after cleanup.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
fixture_remote=$temporary_directory/remote
session_pid=''
server_pid=''

cleanup_fixture() {
    if [ -n "$session_pid" ]; then
        kill -TERM "$session_pid" 2>/dev/null || true
        wait "$session_pid" 2>/dev/null || true
    fi
    if [ -n "$server_pid" ]; then
        kill -TERM "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$temporary_directory"
}
trap cleanup_fixture EXIT HUP INT TERM

mkdir -p "$fixture_remote"
cp "$script_directory/qwen-webui-session.sh" \
    "$fixture_remote/qwen-webui-session.sh"
cat >"$fixture_remote/run-qwen-capacity-server.sh" <<'SERVER'
#!/bin/sh
printf '%s\n' "$$" >"$QWEN_TEST_SERVER_PID_MARKER"
trap 'exit 0' HUP INT TERM
while :; do
    sleep 1
done
SERVER
chmod +x "$fixture_remote"/*.sh

for signal_and_status in HUP:129 INT:130 TERM:143; do
    signal_name=${signal_and_status%%:*}
    expected_status=${signal_and_status#*:}
    state_directory=$temporary_directory/state-$signal_name
    server_pid_marker=$temporary_directory/server-$signal_name.pid
    router_snapshot=$state_directory/.router-presets.active.$signal_name
    mkdir -p "$state_directory"
    : >"$router_snapshot"
    (
        trap - HUP INT TERM
        QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$router_snapshot \
        QWEN_TEST_SERVER_PID_MARKER=$server_pid_marker \
            exec "$fixture_remote/qwen-webui-session.sh" \
                "$temporary_directory/fake-server" \
                "$temporary_directory/fake-model" \
                "$temporary_directory/fake-static" 4096 4096 18080 \
                "$state_directory" low-serialized
    ) >"$temporary_directory/session-$signal_name.stdout" \
      2>"$temporary_directory/session-$signal_name.stderr" &
    session_pid=$!
    attempt=0
    while [ ! -s "$server_pid_marker" ] && [ "$attempt" -lt 100 ]; do
        attempt=$((attempt + 1))
        sleep 0.01
    done
    if [ ! -s "$server_pid_marker" ]; then
        printf '%s session did not start its server fixture\n' \
            "$signal_name" >&2
        exit 1
    fi
    server_pid=$(sed -n '1p' "$server_pid_marker")
    kill -"$signal_name" "$session_pid"
    set +e
    wait "$session_pid"
    session_status=$?
    set -e
    session_pid=''
    if [ "$session_status" -ne "$expected_status" ]; then
        printf '%s session returned %s instead of %s\n' \
            "$signal_name" "$session_status" "$expected_status" >&2
        exit 1
    fi
    if kill -0 "$server_pid" 2>/dev/null; then
        printf '%s session retained server pid %s\n' \
            "$signal_name" "$server_pid" >&2
        exit 1
    fi
    server_pid=''
    if [ -e "$router_snapshot" ] || [ -L "$router_snapshot" ]; then
        printf '%s session retained router snapshot %s\n' \
            "$signal_name" "$router_snapshot" >&2
        exit 1
    fi
done

printf 'qwen_session_signals=accepted\n'
