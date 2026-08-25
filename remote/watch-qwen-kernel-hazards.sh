#!/bin/sh
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    printf 'usage: %s SERVER_PID HAZARD_LOG [TEST_INPUT]\n' "$0" >&2
    exit 2
fi

server_pid=$1
hazard_log=$2
test_input=${3:-}

case $server_pid in
    '' | *[!0-9]*)
        printf 'server PID must be a positive integer\n' >&2
        exit 2
        ;;
esac

if ! kill -0 "$server_pid" 2>/dev/null; then
    printf 'server PID is not running: %s\n' "$server_pid" >&2
    exit 2
fi

if [ "${QWEN_ONE_CORE_ACTIVE:-0}" != 1 ]; then
    renice -n 19 -p $$ >/dev/null
    QWEN_ONE_CORE_ACTIVE=1 exec taskset -c 0 ionice -c 3 "$0" "$@"
fi

hazard_pattern='ring[^[:cntrl:]]*timeout|GPU reset|amdgpu[^[:cntrl:]]*reset|VM fault|device loss|device lost|out of memory|oom-kill'

watch_stream() {
    while IFS= read -r kernel_line; do
        printf '%s\n' "$kernel_line" >>"$hazard_log"
        if printf '%s\n' "$kernel_line" | grep -Eai "$hazard_pattern" >/dev/null; then
            printf 'hazard_utc=%s action=SIGTERM server_pid=%s\n' \
                "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$server_pid" >>"$hazard_log"
            kill -TERM "$server_pid" 2>/dev/null || true
            return 3
        fi
    done

    if kill -0 "$server_pid" 2>/dev/null; then
        printf 'hazard_stream_ended_while_server_running=yes\n' >>"$hazard_log"
        return 1
    fi
    return 0
}

{
    printf 'watch_start_utc=%s server_pid=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$server_pid"
    printf 'hazard_pattern=%s\n' "$hazard_pattern"
} >"$hazard_log"

if [ -n "$test_input" ]; then
    watch_stream <"$test_input"
else
    sudo -n true
    sudo -n journalctl -k -f -n 0 --no-pager -o short-monotonic | watch_stream
fi
