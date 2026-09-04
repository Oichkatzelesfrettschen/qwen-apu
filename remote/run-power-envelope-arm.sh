#!/bin/sh
set -eu

# One arm of the package-power campaign, run as the command of one
# compute-state-lease.sh transaction.
#
# The lease owns the graphics clock, the fabric clock, the memory scanner, the
# process priority, and the package budget, and it has already proven the
# delivered clock before this script starts, so the arm's own work is the
# instrument: the energy record across the arm, the clock sidecar beside it, the
# temperature record, the firmware's power-metrics table at both ends, and the
# fixed-64 served decode between them.
#
# `measure-served-decode.sh` exposes no request-boundary hook. It stamps
# `request-window.tsv` with `time.monotonic_ns()` immediately before curl and
# immediately after it returns, so the energy sampler runs across the whole arm
# and `read-package-energy.py window` selects the two boundary reads out of that
# record afterwards. The alternative -- two reads around the runner -- would
# difference the model load as well as the decode, and a 120 second load beside
# a 7 second window would report the load.
#
# The served runner reads the lease proof out of the environment the transaction
# closed, so the server it launches skips taking the lock this arm's holder is
# already holding.

usage() {
    printf 'usage: %s CAMPAIGN_DIRECTORY ARM_NAME MODEL_ID\n' "$0" >&2
    exit 2
}

if [ "$#" -ne 3 ]; then
    usage
fi

campaign_directory=$1
arm_name=$2
model_id=$3
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
state_directory=${QWEN_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
ryzenadj_command=${QWEN_RYZENADJ:-"${HOME:?}/.local/bin/ryzenadj"}
registry_reader=$script_directory/model-registry.sh
energy_reader=$script_directory/read-package-energy.py
clock_sidecar=$script_directory/sample-clock-sidecar.py
served_runner=$script_directory/measure-served-decode.sh
energy_period_ms=${QWEN_POWER_ENERGY_PERIOD_MS:-50}
clock_period_ms=${QWEN_POWER_CLOCK_PERIOD_MS:-10}
temperature_period_s=${QWEN_POWER_TEMPERATURE_PERIOD_S:-1}
hwmon_root=${QWEN_HWMON_ROOT:-/sys/class/hwmon}
generate_tokens=${QWEN_BENCH_GENERATE:-64}
arm_directory=$campaign_directory/arms/$arm_name
campaign_inputs=$campaign_directory/campaign-inputs.tsv

if [ ! -d "$campaign_directory" ] || [ ! -r "$campaign_inputs" ]; then
    printf 'reason=campaign_inputs_absent path=%s\n' "$campaign_inputs" >&2
    exit 2
fi
if [ -e "$arm_directory" ]; then
    printf 'reason=arm_directory_present path=%s; an arm claims its own directory\n' \
        "$arm_directory" >&2
    exit 2
fi
mkdir -p -- "$arm_directory"

# The transaction hands the profile and the lease proof in through the closed
# arm environment, so an arm that lost either measures a machine state nobody
# proved.
compute_state_profile=${QWEN_COMPUTE_STATE_PROFILE:-}
if [ -z "$compute_state_profile" ]; then
    printf 'reason=compute_state_profile_absent; this arm runs as the command of compute-state-lease.sh\n' >&2
    exit 2
fi
if [ -z "${QWEN_VULKAN_EXTERNAL_LEASE_PROOF:-}" ]; then
    printf 'reason=lease_proof_absent; the transaction forwards it into the arm environment\n' >&2
    exit 2
fi
if ! sudo -n true 2>/dev/null; then
    printf 'reason=sudo_credential_absent; the energy reader and the power-metrics table both need it\n' >&2
    exit 2
fi

campaign_inputs_sha256=$(sha256sum "$campaign_inputs")
campaign_inputs_sha256=${campaign_inputs_sha256%% *}

registry_row=$("$registry_reader" id "$model_id")
registry_field() {
    printf '%s\n' "$registry_row" | awk -F= -v key="$1" '
        $1 == key { sub(/^[^=]*=/, ""); print; found = 1; exit }
        END { if (!found) exit 1 }'
}
model_file=$(registry_field model_file)
model_context=$(registry_field context_default)
model_batch=$(registry_field batch)
model_ubatch=$(registry_field ubatch)
model_cache_k=$(registry_field cache_type_k)
model_cache_v=$(registry_field cache_type_v)
model_flash=$(registry_field flash_attention)
model_path=$models_directory/$model_file
model_checkpoints=$("$registry_reader" ctx-checkpoint "$model_id" 2>/dev/null || printf '0\n')
case $model_checkpoints in
    '' | *[!0-9]*) model_checkpoints=0 ;;
esac
if [ ! -f "$model_path" ]; then
    printf 'reason=model_absent path=%s\n' "$model_path" >&2
    exit 2
fi

# The served runner pins the executable on descriptor 6 and compares the running
# process's mapped image against it, so an arm that named no server ends on
# `approved executable identity is unreadable` after a complete decode. The
# bundle the appliance would launch anyway is that server, resolved once here so
# every arm of a checkpoint measures the same binary.
approved_server=${QWEN_LLAMA_SERVER:-}
if [ -z "$approved_server" ]; then
    approved_server=$("$script_directory/resolve-active-deployment.sh" |
        awk -F= '$1 == "active_deployment_server" { print $2; exit }')
fi
if [ ! -x "$approved_server" ]; then
    printf 'reason=server_absent path=%s\n' "${approved_server:-absent}" >&2
    exit 2
fi

# The k10temp Tctl sensor and the amdgpu edge sensor sit in different hwmon
# instances whose numbers move across boots, so each is resolved by its name.
resolve_hwmon_by_name() {
    for hwmon_entry in "$hwmon_root"/*; do
        [ -r "$hwmon_entry/name" ] || continue
        if [ "$(cat "$hwmon_entry/name")" = "$1" ]; then
            printf '%s\n' "$hwmon_entry"
            return 0
        fi
    done
    printf '\n'
    return 0
}
k10temp_hwmon=$(resolve_hwmon_by_name k10temp)
amdgpu_hwmon=$(resolve_hwmon_by_name amdgpu)

read_or_unavailable() {
    if [ -r "$1" ]; then
        cat -- "$1" 2>/dev/null || printf 'unavailable\n'
    else
        printf 'unavailable\n'
    fi
}

retain_endpoint_state() {
    endpoint_name=$1
    # The redirect is this shell's own, into a directory the unprivileged
    # campaign owns, so the privileged reader writes nothing itself.
    # shellcheck disable=SC2024
    sudo -n "$ryzenadj_command" --info \
        >"$arm_directory/ryzenadj-info-$endpoint_name.txt" 2>&1 || true
    {
        printf 'key\tvalue\n'
        printf 'endpoint\t%s\n' "$endpoint_name"
        printf 'utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'monotonic_ns\t%s\n' \
            "$(python3 -c 'import time; print(time.monotonic_ns())')"
        printf 'tctl_millidegrees\t%s\n' \
            "$(read_or_unavailable "${k10temp_hwmon:-/nonexistent}/temp1_input")"
        printf 'edge_millidegrees\t%s\n' \
            "$(read_or_unavailable "${amdgpu_hwmon:-/nonexistent}/temp1_input")"
        printf 'freq1_hz\t%s\n' \
            "$(read_or_unavailable "${amdgpu_hwmon:-/nonexistent}/freq1_input")"
        printf 'load1\t%s\n' "$(awk '{ print $1; exit }' /proc/loadavg)"
    } >"$arm_directory/endpoint-$endpoint_name.tsv"
}

retain_endpoint_state start

# The transaction leaves this arm at nice 0 because the guarded launch chain
# owns the served process priorities, so each sampler takes nice 19 here rather
# than inheriting it: a sampler beside the server competes for the same two
# cores the decode runs on.
sudo -n nice -n 19 python3 "$energy_reader" sample \
    "$arm_directory/energy-samples.tsv" --period-ms "$energy_period_ms" &
energy_job_pid=$!
python3 "$clock_sidecar" "$arm_directory/clock-samples.tsv" \
    --period-ms "$clock_period_ms" --nice 19 &
clock_job_pid=$!

# The device record carries the two sensors the clock sidecar leaves out: the
# k10temp Tctl the platform's thermal ceiling is stated against, and the amdgpu
# hwmon `freq1_input` the delivered graphics clock is read from, beside the edge
# sensor. One second is a coarse period because a peak over an arm is a coarse
# quantity, and the loop is one process rather than a fork per sample, so its
# own cost stays out of the rate the arm measures.
temperature_record=$arm_directory/device-samples.tsv
nice -n 19 python3 - "$temperature_record" "$temperature_period_s" \
    "${k10temp_hwmon:-/nonexistent}/temp1_input" \
    "${amdgpu_hwmon:-/nonexistent}/temp1_input" \
    "${amdgpu_hwmon:-/nonexistent}/freq1_input" <<'PY' &
import signal
import sys
import time

output_path, period_text = sys.argv[1:3]
sensor_paths = sys.argv[3:]
period_s = float(period_text)
running = {"value": True}


def stop(_signal_number, _frame):
    running["value"] = False


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)


def read_sensor(path):
    try:
        with open(path) as handle:
            text = handle.read().strip()
    except OSError:
        return "unavailable"
    return text if text.isdecimal() else "unavailable"


with open(output_path, "w") as handle:
    handle.write("monotonic_ns\ttctl_millidegrees\tedge_millidegrees\tfreq1_hz\n")
    handle.flush()
    while running["value"]:
        readings = [read_sensor(path) for path in sensor_paths]
        handle.write(f"{time.monotonic_ns()}\t" + "\t".join(readings) + "\n")
        handle.flush()
        time.sleep(period_s)
PY
temperature_job_pid=$!

stop_samplers() {
    if [ -n "${temperature_job_pid:-}" ]; then
        kill -TERM "$temperature_job_pid" 2>/dev/null || true
        wait "$temperature_job_pid" 2>/dev/null || true
        temperature_job_pid=''
    fi
    if [ -n "${clock_job_pid:-}" ]; then
        kill -TERM "$clock_job_pid" 2>/dev/null || true
        wait "$clock_job_pid" 2>/dev/null || true
        clock_job_pid=''
    fi
    if [ -n "${energy_job_pid:-}" ]; then
        # sudo may exec the sampler in place or hold it as a child, so the
        # sampler's own recorded pid is signalled beside the job this shell
        # started and the record keeps every row it flushed either way.
        sampler_pid=$(awk -F'\t' '$1 == "sampler_pid" { print $2; exit }' \
            "$arm_directory/energy-samples.tsv" 2>/dev/null || true)
        case ${sampler_pid:-} in
            '' | *[!0-9]*) ;;
            *) sudo -n kill -TERM "$sampler_pid" 2>/dev/null || true ;;
        esac
        kill -TERM "$energy_job_pid" 2>/dev/null || true
        wait "$energy_job_pid" 2>/dev/null || true
        energy_job_pid=''
    fi
}
served_runner_pid=''
stop_served_runner() {
    if [ -n "${served_runner_pid:-}" ]; then
        kill -TERM "$served_runner_pid" 2>/dev/null || true
        wait "$served_runner_pid" 2>/dev/null || true
        served_runner_pid=''
    fi
}
# The runner is a background job this shell waits on, so a terminating signal
# reaches it through the trap rather than after curl's own 900 second deadline.
trap 'stop_samplers' EXIT
trap 'stop_served_runner; stop_samplers; exit 143' TERM
trap 'stop_served_runner; stop_samplers; exit 130' INT
trap 'stop_served_runner; stop_samplers; exit 129' HUP

set +e
# The registry and the artifact ledger travel with the arm because the served
# runner derives the approved model identity from them: it hands llama-server a
# descriptor path rather than a mutable pathname, and qwen-capacity-policy.sh
# refuses a descriptor-backed model that carries no publisher identity.
env \
    QWEN_LLAMA_SERVER="$approved_server" \
    QWEN_MODEL_REGISTRY="$script_directory/models.tsv" \
    QWEN_MODEL_ARTIFACTS="$script_directory/model-artifacts.tsv" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_STATE_DIRECTORY="$state_directory" \
    QWEN_RESULT_DIRECTORY="$arm_directory" \
    QWEN_CONTEXT_SIZE="$model_context" \
    QWEN_BATCH_SIZE="$model_batch" \
    QWEN_UBATCH_SIZE="$model_ubatch" \
    QWEN_CACHE_TYPE_K="$model_cache_k" \
    QWEN_CACHE_TYPE_V="$model_cache_v" \
    QWEN_FLASH_ATTN="$model_flash" \
    QWEN_CTX_CHECKPOINTS="$model_checkpoints" \
    QWEN_SPEC_TYPE=off \
    QWEN_BACKEND_SAMPLING=0 QWEN_SPEC_BACKEND_SAMPLING=0 \
    QWEN_ROUTER=0 QWEN_INFERENCE_CPU=0 \
    QWEN_SERVER_PORT=8080 QWEN_BIND_HOST=127.0.0.1 \
    QWEN_LATENCY_MODE=observe QWEN_REQUIRE_API_KEY=0 \
    QWEN_WEB_BROKER=0 QWEN_IMAGE_SERVICE=0 \
    QWEN_EXECUTION_SURFACE=hp14-ssh \
    QWEN_HOST_SHORTNAME=hp14-dk1xxx \
    QWEN_SSH_SESSION=present \
    QWEN_EXECUTION_PROOF="$campaign_inputs" \
    QWEN_EXECUTION_PROOF_SHA256="$campaign_inputs_sha256" \
    QWEN_BENCH_GENERATE="$generate_tokens" \
    "$served_runner" "$arm_name" "$model_path" low-async \
    >"$arm_directory/served-runner.stdout" 2>"$arm_directory/served-runner.stderr" &
served_runner_pid=$!
wait "$served_runner_pid"
served_status=$?
served_runner_pid=''
set -e

stop_samplers
trap - EXIT HUP INT TERM
retain_endpoint_state end

window_begin_ns=$(awk -F'\t' '$1 == "begin_ns" { print $2; exit }' \
    "$arm_directory/request-window.tsv" 2>/dev/null || true)
window_end_ns=$(awk -F'\t' '$1 == "end_ns" { print $2; exit }' \
    "$arm_directory/request-window.tsv" 2>/dev/null || true)
energy_status=1
case ${window_begin_ns:-}${window_end_ns:-} in
    '' | *[!0-9]*) ;;
    *)
        set +e
        python3 "$energy_reader" window "$arm_directory/energy-samples.tsv" \
            --window-begin-ns "$window_begin_ns" \
            --window-end-ns "$window_end_ns" \
            >"$arm_directory/energy-window.tsv" \
            2>"$arm_directory/energy-window.stderr"
        energy_status=$?
        set -e
        ;;
esac

summary_field() {
    awk -F'\t' -v key="$1" '$1 == key { print $2; exit }' "$2" 2>/dev/null
}
decode_rate=$(python3 -c '
import json
import sys

try:
    with open(sys.argv[1]) as handle:
        document = json.load(handle)
except Exception:
    print("unavailable")
    sys.exit(0)
value = document.get("decode_tok_per_second")
valid = document.get("valid")
print(value if valid is True and isinstance(value, (int, float)) else "unavailable")
' "$arm_directory/summary.json" 2>/dev/null || printf 'unavailable\n')
tctl_peak=$(awk -F'\t' '$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $2 + 0 > peak { peak = $2 }
    END { print (peak ? peak : "unavailable") }' "$temperature_record")
edge_peak=$(awk -F'\t' '$1 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ && $3 + 0 > peak { peak = $3 }
    END { print (peak ? peak : "unavailable") }' "$temperature_record")
# The delivered graphics clock is the amdgpu hwmon reading in hertz; the sidecar
# reports the selected pp_dpm_sclk step beside it, and the two answer different
# questions.
gfxclk_delivered=$(awk -F'\t' '
    $1 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ { total += $4 / 1000000; count++ }
    END { if (count) printf "%.1f\n", total / count; else print "unavailable" }' \
    "$temperature_record")
gfxclk_selected=$(awk -F'\t' '
    $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ { seen[$2]++ }
    END {
        out = ""
        for (value in seen) out = (out == "" ? value : out "," value)
        print (out == "" ? "unavailable" : out)
    }' "$arm_directory/clock-samples.tsv" 2>/dev/null || printf 'unavailable\n')
fclk_selected=$(awk -F'\t' '
    $1 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ { seen[$3]++ }
    END {
        out = ""
        for (value in seen) out = (out == "" ? value : out "," value)
        print (out == "" ? "unavailable" : out)
    }' "$arm_directory/clock-samples.tsv" 2>/dev/null || printf 'unavailable\n')

{
    printf 'key\tvalue\n'
    printf 'schema\tpower-envelope-arm-v1\n'
    printf 'arm\t%s\n' "$arm_name"
    printf 'model_id\t%s\n' "$model_id"
    printf 'compute_state_profile\t%s\n' "$compute_state_profile"
    printf 'served_status\t%s\n' "$served_status"
    printf 'energy_status\t%s\n' "$energy_status"
    printf 'decode_tok_s\t%s\n' "${decode_rate:-unavailable}"
    printf 'package_watts\t%s\n' \
        "$(summary_field inner_package_watts "$arm_directory/energy-window.tsv")"
    printf 'core_watts\t%s\n' \
        "$(summary_field inner_core_watts "$arm_directory/energy-window.tsv")"
    printf 'package_watts_outer\t%s\n' \
        "$(summary_field outer_package_watts "$arm_directory/energy-window.tsv")"
    printf 'core_watts_outer\t%s\n' \
        "$(summary_field outer_core_watts "$arm_directory/energy-window.tsv")"
    printf 'window_coverage\t%s\n' \
        "$(summary_field window_coverage "$arm_directory/energy-window.tsv")"
    printf 'gfxclk_delivered_mean_mhz\t%s\n' "$gfxclk_delivered"
    printf 'gfxclk_selected_mhz\t%s\n' "$gfxclk_selected"
    printf 'fclk_observed_mhz\t%s\n' "$fclk_selected"
    printf 'tctl_peak_millidegrees\t%s\n' "$tctl_peak"
    printf 'edge_peak_millidegrees\t%s\n' "$edge_peak"
} >"$arm_directory/arm-summary.tsv"

if [ "$served_status" -ne 0 ]; then
    printf 'power_envelope_arm=failed arm=%s model=%s served_status=%s\n' \
        "$arm_name" "$model_id" "$served_status" >&2
    exit 1
fi
if [ "$energy_status" -ne 0 ]; then
    printf 'power_envelope_arm=failed arm=%s model=%s energy_status=%s\n' \
        "$arm_name" "$model_id" "$energy_status" >&2
    exit 1
fi
printf 'power_envelope_arm=completed arm=%s model=%s decode_tok_s=%s\n' \
    "$arm_name" "$model_id" "${decode_rate:-unavailable}"
