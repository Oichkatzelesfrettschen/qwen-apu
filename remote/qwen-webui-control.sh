#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s start [paced-60|low-serialized|low-async]|status|stop|key\n' \
        "$0" >&2
    exit 2
fi

action=$1
# The submission sweep measured low-async at 2.718 decode tok/s against 1.348
# serialized on a chat request, with zero deadline breaches and 100.00% of probe
# submissions inside one 60 Hz frame in both. Serialization costs half the
# decode rate and buys nothing back under this workload. low-serialized remains
# for sustained long-context prefill, where the depth ladder measured async
# raising probe p90 8.6-fold.
profile=${2:-low-async}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmux_socket=qwen-runtime
tmux_session=qwen-webui
# qwen-runtime was created from a fresh SSH login after render/video group
# repair. Reusing its separate tmux server preserves offscreen Vulkan access
# without inheriting the older qwen-admin server's supplementary group set.
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
# The served depth is the operational ceiling, admitted by the measured 24K
# allocation of 2,974 MiB against this gate. QWEN_BIND_HOST and
# QWEN_LATENCY_MODE reach the session script, so `start` reproduces the
# deployed listener instead of a loopback server the documentation would then
# contradict.
context_size=${QWEN_CONTEXT_SIZE:-24576}
required_vulkan_mib=${QWEN_REQUIRED_VULKAN_MIB:-4608}
bind_host=${QWEN_BIND_HOST:-127.0.0.1}
latency_mode=${QWEN_LATENCY_MODE:-observe}
server_port=${QWEN_SERVER_PORT:-8080}
# llama-ui is a SvelteKit build produced on a machine with Node and copied here
# as static files, so the laptop serves it without a build toolchain or a second
# process. QWEN_STATIC_PATH selects it against the hand-written diagnostic page.
# The distill and the base model share the Qwen3.5-4B architecture, so a model
# swap is an argument rather than an edit. The projector is bound to the
# checkpoint that produced it and travels separately.
model_path=${QWEN_MODEL_PATH:-"${HOME:?}/models/Qwen3.5-4B-GGUF/Qwen3.5-4B-Q4_K_M.gguf"}
static_path=${QWEN_STATIC_PATH:-"$script_directory/../webui-llama-ui"}
if [ ! -f "$static_path/index.html" ]; then
    static_path=$script_directory/../webui
fi
pid_file=$state_directory/server.pid
status_file=$state_directory/session.status

case $action in
    start)
        case $profile in
            paced-60 | low-serialized | low-async | custom) ;;
            *)
                printf 'unknown Vulkan profile: %s\n' "$profile" >&2
                exit 2
                ;;
        esac
        if tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; then
            printf 'tmux session already exists: %s\n' "$tmux_session" >&2
            exit 2
        fi
        mkdir -p "$state_directory"
        # A launcher polls this file for the new session's verdict. The previous
        # run's last line would otherwise satisfy that poll before the new
        # session writes anything, reporting a stale failure as this one's.
        rm -f "$status_file"
        # tmux runs the new session from its server's environment, not this
        # shell's, so submission settings must travel in the command itself.
        forwarded_environment=''
        # The projector and its image budget must survive the tmux boundary too.
        for forwarded_name in QWEN_MMPROJ QWEN_MMPROJ_OFFLOAD QWEN_IMAGE_MAX_TOKENS; do
            eval "forwarded_value=\${$forwarded_name:-}"
            if [ -n "$forwarded_value" ]; then
                forwarded_environment="$forwarded_environment $forwarded_name=$forwarded_value"
            fi
        done
        for forwarded_name in GGML_VK_MAX_NODES_PER_SUBMIT \
                              GGML_VK_SERIALIZE_SUBMISSIONS \
                              GGML_VK_ALLOW_GRAPHICS_QUEUE \
                              GGML_VK_DUTY_CYCLE_PERCENT; do
            eval "forwarded_value=\${$forwarded_name:-}"
            if [ -n "$forwarded_value" ]; then
                forwarded_environment="$forwarded_environment $forwarded_name=$forwarded_value"
            fi
        done
        tmux -L "$tmux_socket" new-session -d -s "$tmux_session" \
            "env $forwarded_environment QWEN_BIND_HOST=\"$bind_host\" QWEN_LATENCY_MODE=\"$latency_mode\" $script_directory/qwen-webui-session.sh \"\$HOME/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-server\" \"$model_path\" \"$static_path\" $context_size $required_vulkan_mib $server_port \"$state_directory\" \"$profile\""
        printf 'started tmux_socket=%s tmux_session=%s profile=%s host=%s port=%s context=%s latency_mode=%s model=%s\n' \
            "$tmux_socket" "$tmux_session" "$profile" "$bind_host" \
            "$server_port" "$context_size" "$latency_mode" "$model_path"
        ;;
    status)
        if [ "$#" -ne 1 ]; then
            printf 'status does not accept a profile\n' >&2
            exit 2
        fi
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
        if [ "$#" -ne 1 ]; then
            printf 'key does not accept a profile\n' >&2
            exit 2
        fi
        api_key_file=$state_directory/api.key
        if [ ! -s "$api_key_file" ]; then
            printf 'API key is unavailable; start the session first\n' >&2
            exit 1
        fi
        sed -n '1p' "$api_key_file"
        ;;
    stop)
        if [ "$#" -ne 1 ]; then
            printf 'stop does not accept a profile\n' >&2
            exit 2
        fi
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
        printf 'usage: %s start [paced-60|low-serialized|low-async]|status|stop|key\n' \
            "$0" >&2
        exit 2
        ;;
esac
