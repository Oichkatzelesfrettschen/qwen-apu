#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
llama_server=${1:-"${HOME:?}/src/llama.cpp/build-qwen-vulkan/bin/llama-server"}
model_path=${2:-"${HOME:?}/models/Qwen3.5-4B-GGUF/Qwen3.5-4B-Q4_K_M.gguf"}
static_path=${3:-"$script_directory/../webui"}
# The 4K allocation rung consumes 2,724 MiB of measured Vulkan memory and uses
# the admitted 4,096 MiB preflight gate. Interactive serving starts from that
# measured APU rung instead of importing another host's placement profile.
context_size=${4:-4096}
required_vulkan_mib=${5:-4096}
server_port=${6:-8080}
state_directory=${7:-"${HOME:?}/qwen-webui-state"}

umask 077
mkdir -p "$state_directory"
server_log=$state_directory/server.log
telemetry_log=$state_directory/telemetry.log
pid_file=$state_directory/server.pid
status_file=$state_directory/session.status
api_key_file=$state_directory/api.key
monitor_pid=""
server_pid=""

cleanup() {
    if [ -n "$monitor_pid" ]; then
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    fi
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
}
trap cleanup HUP INT TERM

if [ -s "$pid_file" ]; then
    prior_pid=$(sed -n '1p' "$pid_file")
    case $prior_pid in
        '' | *[!0-9]*) prior_pid=0 ;;
    esac
    if [ "$prior_pid" -gt 0 ] && kill -0 "$prior_pid" 2>/dev/null; then
        printf 'qwen Web UI server is already running with PID %s\n' "$prior_pid" >&2
        exit 2
    fi
fi

if [ ! -s "$api_key_file" ]; then
    if ! command -v openssl >/dev/null 2>&1; then
        printf 'openssl is required to create the Web UI API key\n' >&2
        exit 1
    fi
    openssl rand -hex 32 >"$api_key_file"
fi
chmod 600 "$api_key_file"

printf 'state=starting utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
"$script_directory/run-qwen-capacity-server.sh" \
    "$llama_server" "$model_path" "$context_size" "$required_vulkan_mib" \
    "$server_port" "$static_path" "$api_key_file" >"$server_log" 2>&1 &
server_pid=$!
printf '%s\n' "$server_pid" >"$pid_file"

ready_for_monitor=0
attempt=0
# The preflight runs before radv-low-priority-env.sh applies CPU 0, nice 19, and
# idle I/O policy. Monitoring starts only after the server PID carries that
# policy, so startup cannot be misclassified as a scheduling-policy breach.
while [ "$attempt" -lt 100 ]; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
        break
    fi
    affinity=$(awk '$1 == "Cpus_allowed_list:" { print $2 }' "/proc/$server_pid/status")
    nice_value=$(ps -o ni= -p "$server_pid" | tr -d ' ')
    if [ "$affinity" = 0 ] && [ "$nice_value" = 19 ]; then
        ready_for_monitor=1
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done

if [ "$ready_for_monitor" -ne 1 ]; then
    printf 'state=failed reason=server_policy_not_active utc=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
    wait "$server_pid" 2>/dev/null || true
    server_pid=""
    exit 1
fi

"$script_directory/monitor-qwen-runtime.sh" "$server_pid" "$telemetry_log" &
monitor_pid=$!
# monitor-qwen-runtime.sh samples Raven2 busy state once per second and
# terminates the server on the first value above 75 percent. Native Vulkan
# pacing fixes the model graph duty cycle at 60 percent.
printf 'state=running server_pid=%s monitor_pid=%s port=%s context=%s utc=%s\n' \
    "$server_pid" "$monitor_pid" "$server_port" "$context_size" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"

set +e
wait "$server_pid"
server_status=$?
wait "$monitor_pid"
monitor_status=$?
set -e
server_pid=""
monitor_pid=""
printf 'state=stopped server_status=%s monitor_status=%s utc=%s\n' \
    "$server_status" "$monitor_status" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >"$status_file"
exit "$server_status"
