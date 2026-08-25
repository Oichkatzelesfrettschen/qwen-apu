#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf 'usage: %s start|status|stop|key\n' "$0" >&2
    exit 2
fi

action=$1
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmux_socket=qwen-runtime
tmux_session=qwen-webui
# qwen-runtime was created from a fresh SSH login after render/video group
# repair. Reusing its separate tmux server preserves offscreen Vulkan access
# without inheriting the older qwen-admin server's supplementary group set.
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
pid_file=$state_directory/server.pid
status_file=$state_directory/session.status

case $action in
    start)
        if tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; then
            printf 'tmux session already exists: %s\n' "$tmux_session" >&2
            exit 2
        fi
        mkdir -p "$state_directory"
        tmux -L "$tmux_socket" new-session -d -s "$tmux_session" \
            "$script_directory/qwen-webui-session.sh"
        printf 'started tmux_socket=%s tmux_session=%s\n' \
            "$tmux_socket" "$tmux_session"
        ;;
    status)
        recorded_status=state=not-started
        if [ -r "$status_file" ]; then
            recorded_status=$(sed -n '1p' "$status_file")
        fi
        server_running=0
        if [ -r "$pid_file" ]; then
            status_pid=$(sed -n '1p' "$pid_file")
            case $status_pid in
                '' | *[!0-9]*) status_pid=0 ;;
            esac
            if [ "$status_pid" -gt 0 ] && kill -0 "$status_pid" 2>/dev/null && \
               [ "$(ps -o comm= -p "$status_pid" | tr -d ' ')" = llama-server ]; then
                server_running=1
            fi
        fi
        tmux_running=0
        if tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; then
            tmux_running=1
        fi
        case $recorded_status:$server_running:$tmux_running in
            state=running*:0:0)
                printf 'state=stale recorded_status=%s\n' "$recorded_status"
                ;;
            *)
                printf '%s\n' "$recorded_status"
                ;;
        esac
        if [ "$tmux_running" -eq 1 ]; then
            printf 'tmux=running socket=%s session=%s\n' "$tmux_socket" "$tmux_session"
        else
            printf 'tmux=absent socket=%s session=%s\n' "$tmux_socket" "$tmux_session"
        fi
        if [ -r "$state_directory/server.log" ]; then
            printf 'server_log_tail\n'
            tail -n 10 "$state_directory/server.log"
        fi
        if [ -r "$state_directory/telemetry.log" ]; then
            printf 'telemetry_log_tail\n'
            tail -n 5 "$state_directory/telemetry.log"
        fi
        ;;
    key)
        api_key_file=$state_directory/api.key
        if [ ! -s "$api_key_file" ]; then
            printf 'API key is unavailable; start the session first\n' >&2
            exit 1
        fi
        sed -n '1p' "$api_key_file"
        ;;
    stop)
        if [ -r "$pid_file" ]; then
            server_pid=$(sed -n '1p' "$pid_file")
            case $server_pid in
                '' | *[!0-9]*) server_pid=0 ;;
            esac
            if [ "$server_pid" -gt 0 ] && kill -0 "$server_pid" 2>/dev/null; then
                server_command=$(ps -o comm= -p "$server_pid" | tr -d ' ')
                if [ "$server_command" = llama-server ]; then
                    kill -TERM "$server_pid"
                else
                    printf 'stale PID file names non-llama process %s; leaving it running\n' \
                        "$server_pid" >&2
                fi
            fi
        fi
        wait_attempt=0
        while [ "$wait_attempt" -lt 100 ] && \
              tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; do
            wait_attempt=$((wait_attempt + 1))
            sleep 0.1
        done
        if tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; then
            tmux -L "$tmux_socket" kill-session -t "$tmux_session"
        fi
        printf 'stopped tmux_socket=%s tmux_session=%s\n' \
            "$tmux_socket" "$tmux_session"
        ;;
    *)
        printf 'usage: %s start|status|stop|key\n' "$0" >&2
        exit 2
        ;;
esac
