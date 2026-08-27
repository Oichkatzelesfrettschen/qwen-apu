#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
llama_server=${1:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-server"}
model_path=${2:-"${HOME:?}/models/Qwen3.5-4B-GGUF/Qwen3.5-4B-Q4_K_M.gguf"}
static_path=${3:-"$script_directory/../webui"}
# The 4K allocation rung consumes 2,724 MiB of measured Vulkan memory and uses
# the admitted 4,096 MiB preflight gate. Interactive serving starts from that
# measured APU rung instead of importing another host's placement profile.
context_size=${4:-4096}
required_vulkan_mib=${5:-4096}
server_port=${6:-8080}
state_directory=${7:-"${HOME:?}/qwen-webui-state"}
vulkan_profile=${8:-low-serialized}

umask 077
mkdir -p "$state_directory"
server_log=$state_directory/server.log
telemetry_log=$state_directory/telemetry.log
graphics_latency_log=$state_directory/graphics-latency.log
kernel_hazard_log=$state_directory/kernel-hazards.log
pid_file=$state_directory/server.pid
status_file=$state_directory/session.status
api_key_file=$state_directory/api.key
monitor_pid=""
latency_watchdog_pid=""
kernel_hazard_watchdog_pid=""
server_pid=""

cleanup() {
    if [ -n "$monitor_pid" ]; then
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    fi
    if [ -n "$latency_watchdog_pid" ]; then
        kill "$latency_watchdog_pid" 2>/dev/null || true
        wait "$latency_watchdog_pid" 2>/dev/null || true
    fi
    if [ -n "$kernel_hazard_watchdog_pid" ]; then
        kill "$kernel_hazard_watchdog_pid" 2>/dev/null || true
        wait "$kernel_hazard_watchdog_pid" 2>/dev/null || true
    fi
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT HUP INT TERM

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

# QWEN_REQUIRE_API_KEY=1 mints a key and makes llama-server demand it. The
# default serves without one, because this deployment is a local model on a
# trusted network and a key there only stands between a reader and the page.
if [ "${QWEN_REQUIRE_API_KEY:-0}" = 1 ]; then
    if [ ! -s "$api_key_file" ]; then
        if ! command -v openssl >/dev/null 2>&1; then
            printf 'openssl is required to create the Web UI API key\n' >&2
            exit 1
        fi
        openssl rand -hex 32 >"$api_key_file"
    fi
    chmod 600 "$api_key_file"
else
    api_key_file=''
fi

printf 'state=starting utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
QWEN_VULKAN_PROFILE=$vulkan_profile \
"$script_directory/run-qwen-capacity-server.sh" \
    "$llama_server" "$model_path" "$context_size" "$required_vulkan_mib" \
    "$server_port" "$static_path" "$api_key_file" >"$server_log" 2>&1 &
server_pid=$!
printf '%s\n' "$server_pid" >"$pid_file"

ready_for_monitor=0
attempt=0
inference_cpu=${QWEN_INFERENCE_CPU:-0}
# Model loading performs one-time Vulkan allocation and transfer work before the
# HTTP service can accept inference. Arm the service-latency watchdog only after
# llama-server reports itself ready, while still requiring the runtime CPU
# policy before admitting the session.
#
# A router reports readiness differently because it loads nothing at startup: it
# binds the port and waits for a request to name a model. Waiting for the
# single-model marker there times out against a server that is already serving,
# and the session tears down a healthy listener.
readiness_marker='model loaded'
if [ "${QWEN_ROUTER:-0}" = 1 ]; then
    readiness_marker='starting server in router mode'
fi
while [ "$attempt" -lt 1200 ]; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
        break
    fi
    affinity=$(awk '$1 == "Cpus_allowed_list:" { print $2 }' "/proc/$server_pid/status")
    nice_value=$(ps -o ni= -p "$server_pid" | tr -d ' ')
    if [ "$affinity" = "$inference_cpu" ] && [ "$nice_value" = 19 ] && \
       grep -F "$readiness_marker" "$server_log" >/dev/null 2>&1; then
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

latency_probe=${QWEN_VULKAN_LATENCY_PROBE:-"$script_directory/../build/vulkan-graphics-service-probe"}
# RADV LOW global priority, CPU 0, and nice 19 are what yield the desktop the
# machine; the probe measures whether that yielding actually happens rather
# than enforcing it. The 24K ladder puts p99.9 fence service at 21,302 us
# against the 20,000 us deadline, so the deadline sits near the 99.56th
# percentile and a late frame arrives about every 3.6 seconds under load.
# `terminate` therefore ends any sustained session within seconds and is
# retained only for deliberately strict runs; `observe` counts the same
# breaches, leaves them in the log, and lets the session serve.
latency_probe_mode=${QWEN_LATENCY_MODE:-observe}
case $latency_probe_mode in
    terminate) latency_probe_mode_argument='' ;;
    observe) latency_probe_mode_argument='--observe' ;;
    *)
        printf 'QWEN_LATENCY_MODE must be terminate or observe: %s\n' \
            "$latency_probe_mode" >&2
        exit 2
        ;;
esac
if [ ! -x "$latency_probe" ]; then
    printf 'state=failed reason=graphics_latency_probe_unavailable path=%s utc=%s\n' \
        "$latency_probe" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
    exit 1
fi

: >"$graphics_latency_log"
(
    unset AMD_PRIORITY DISPLAY WAYLAND_DISPLAY
    export VK_DRIVER_FILES=${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
    export VK_ICD_FILENAMES=$VK_DRIVER_FILES
    exec taskset -c 1 ionice -c 3 "$latency_probe" \
        --log "$graphics_latency_log" --watch-pid "$server_pid" \
        --interval-ms 16 --deadline-us 20000 $latency_probe_mode_argument
) &
latency_watchdog_pid=$!

latency_ready=0
attempt=0
while [ "$attempt" -lt 100 ]; do
    if grep -F 'probe_start ' "$graphics_latency_log" >/dev/null 2>&1; then
        latency_ready=1
        break
    fi
    if ! kill -0 "$latency_watchdog_pid" 2>/dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done
if [ "$latency_ready" -ne 1 ]; then
    printf 'state=failed reason=graphics_latency_probe_not_ready utc=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
    exit 1
fi

"$script_directory/watch-qwen-kernel-hazards.sh" \
    "$server_pid" "$kernel_hazard_log" &
kernel_hazard_watchdog_pid=$!

kernel_watch_ready=0
attempt=0
while [ "$attempt" -lt 100 ]; do
    if grep -F 'watch_ready_utc=' "$kernel_hazard_log" >/dev/null 2>&1; then
        kernel_watch_ready=1
        break
    fi
    if ! kill -0 "$kernel_hazard_watchdog_pid" 2>/dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done
if [ "$kernel_watch_ready" -ne 1 ]; then
    printf 'state=failed reason=kernel_hazard_watchdog_not_ready utc=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
    exit 1
fi

"$script_directory/monitor-qwen-runtime.sh" "$server_pid" "$telemetry_log" \
    "$vulkan_profile" "$latency_watchdog_pid" \
    "$kernel_hazard_watchdog_pid" &
monitor_pid=$!
# The paced profile uses the aggregate busy ceiling. The serialized LOW
# profile uses the MEDIUM graphics-family deadline as its responsiveness gate.
printf 'state=running server_pid=%s monitor_pid=%s latency_watchdog_pid=%s kernel_hazard_watchdog_pid=%s profile=%s host=%s port=%s context=%s latency_mode=%s utc=%s\n' \
    "$server_pid" "$monitor_pid" "$latency_watchdog_pid" \
    "$kernel_hazard_watchdog_pid" "$vulkan_profile" \
    "${QWEN_BIND_HOST:-127.0.0.1}" "$server_port" "$context_size" \
    "$latency_probe_mode" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
# The speculation settings occupy a second line because the control script and
# the teardown script both read the first line alone, the teardown to recover
# the guard PIDs before `stop` rewrites the file.
printf 'speculation spec_type=%s draft_n_max=%s draft_p_min=%s draft_backend_sampling=%s backend_sampling=%s\n' \
    "${QWEN_SPEC_TYPE:-off}" "${QWEN_SPEC_DRAFT_N_MAX:-default}" \
    "${QWEN_SPEC_DRAFT_P_MIN:-default}" \
    "${QWEN_SPEC_BACKEND_SAMPLING:-0}" "${QWEN_BACKEND_SAMPLING:-0}" >>"$status_file"
# The cache triple lands on a third line for the same reason, and it records
# `registry` where the row supplied the value, so a retained status file
# distinguishes an experiment arm from the served default.
printf 'cache cache_type_k=%s cache_type_v=%s flash_attention=%s\n' \
    "${QWEN_CACHE_TYPE_K:-registry}" "${QWEN_CACHE_TYPE_V:-registry}" \
    "${QWEN_FLASH_ATTN:-registry}" >>"$status_file"
# Router state lands on a fourth line. A router listener serves several
# checkpoints behind one port and spawns a child process per loaded model, so a
# retained status file that named only the default model would describe one of
# the processes running rather than the service.
printf 'router enabled=%s presets=%s models_max=%s\n' \
    "${QWEN_ROUTER:-0}" \
    "${QWEN_ROUTER_PRESETS:-default}" "${QWEN_ROUTER_MAX:-1}" >>"$status_file"

set +e
wait "$server_pid"
server_status=$?
wait "$monitor_pid"
monitor_status=$?
wait "$latency_watchdog_pid"
latency_status=$?
wait "$kernel_hazard_watchdog_pid"
kernel_hazard_status=$?
set -e
server_pid=""
monitor_pid=""
latency_watchdog_pid=""
kernel_hazard_watchdog_pid=""
printf 'state=stopped server_status=%s monitor_status=%s latency_status=%s kernel_hazard_status=%s profile=%s utc=%s\n' \
    "$server_status" "$monitor_status" "$latency_status" \
    "$kernel_hazard_status" "$vulkan_profile" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >"$status_file"
exit "$server_status"
