#!/bin/sh
set -eu

# The first image-appliance campaign harness: one cold arm and one warm arm of
# the pinned stable-diffusion.cpp binary, run standalone with no llama process
# resident, strict Vulkan device selection, and the telemetry fields
# evidence/image-appliance stable-diffusion-cpp-pin.md and the image-appliance
# brief both name.
#
# evidence/image-appliance/stable-diffusion-cpp-pin.md traces device selection
# to sd-cli's own --backend flag: an unresolvable device name refuses the run
# through StableDiffusionGGML::ensure_backend_pair and a nonzero exit rather
# than a silent CPU fallback. This harness proves that refusal on every
# invocation with a short device-refusal-control arm before the two
# generation arms, then pins every module of the real arms to the one Vulkan
# device --list-devices names.
#
# QWEN_IMAGE_RUNTIME overrides the binary under test, which is what lets
# remote/test-run-image-standalone.sh exercise every path here against
# remote/test-fixtures/fake-image-runtime.sh without the device.

usage() {
    printf 'usage: %s OUTPUT_DIRECTORY MODEL_PATH\n' "$0" >&2
    printf '\nenvironment:\n' >&2
    printf '  QWEN_IMAGE_RUNTIME              path to the pinned sd-cli binary\n' >&2
    printf '  QWEN_IMAGE_PROMPT               default: a red apple on a white table, product photography\n' >&2
    printf '  QWEN_IMAGE_NEGATIVE_PROMPT      default empty\n' >&2
    printf '  QWEN_IMAGE_WIDTH QWEN_IMAGE_HEIGHT   default 512 512\n' >&2
    printf '  QWEN_IMAGE_STEPS QWEN_IMAGE_SEED QWEN_IMAGE_SAMPLER QWEN_IMAGE_CFG_SCALE\n' >&2
    printf '  QWEN_IMAGE_BACKEND               default derived from --list-devices\n' >&2
    printf '  QWEN_IMAGE_TIMEOUT_S              default 300, the runtime hard bound\n' >&2
    printf '  QWEN_IMAGE_POLL_INTERVAL_S        default 0.2\n' >&2
    printf '  QWEN_IMAGE_SKIP_MODEL_HASH=1      skip hashing MODEL_PATH\n' >&2
    printf '  QWEN_IMAGE_ALLOW_LLAMA_RESIDENT=1 skip the no-llama-process precondition\n' >&2
    printf '  QWEN_IMAGE_TAESD                  Tiny AutoEncoder file, passed through --taesd\n' >&2
    printf '  QWEN_IMAGE_VAE                    full VAE file, passed through --vae\n' >&2
    printf '  QWEN_IMAGE_LORA_DIR               LoRA directory, passed through --lora-model-dir\n' >&2
    printf '  QWEN_IMAGE_POST_LLM_CONTROL       executable post-image language health control\n' >&2
    printf '  QWEN_VULKAN_WORKLOAD_LOCK         shared Vulkan workload lease path\n' >&2
    printf '  QWEN_VULKANINFO_COMMAND, QWEN_DRM_DEVICE, QWEN_HWMON_ROOT  device probes\n' >&2
    exit 2
}

[ "$#" -eq 2 ] || usage

output_directory=$1
model_path=$2
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

# Every invocation of the pinned runtime, --list-devices included, runs under
# the RADV ICD pin remote/radv-icd-env.sh derives, so the Vulkan loader
# enumerates RADV alone and a software rasterizer never reaches
# --list-devices or a generation arm.
# shellcheck source=remote/radv-icd-env.sh
. "$script_directory/radv-icd-env.sh"

runtime=${QWEN_IMAGE_RUNTIME:-"$qwen_home_image_runtime"}
prompt=${QWEN_IMAGE_PROMPT:-'a red apple on a white table, product photography'}
negative_prompt=${QWEN_IMAGE_NEGATIVE_PROMPT:-}
image_width=${QWEN_IMAGE_WIDTH:-512}
image_height=${QWEN_IMAGE_HEIGHT:-512}
image_steps=${QWEN_IMAGE_STEPS:-1}
image_seed=${QWEN_IMAGE_SEED:-42}
image_sampler=${QWEN_IMAGE_SAMPLER:-euler}
image_cfg_scale=${QWEN_IMAGE_CFG_SCALE:-1.0}
timeout_seconds=${QWEN_IMAGE_TIMEOUT_S:-300}
poll_interval=${QWEN_IMAGE_POLL_INTERVAL_S:-0.2}
vulkaninfo_command=${QWEN_VULKANINFO_COMMAND:-vulkaninfo}
post_llm_control=${QWEN_IMAGE_POST_LLM_CONTROL:-}
workload_lock=${QWEN_VULKAN_WORKLOAD_LOCK:-}

case $timeout_seconds in
    '' | *[!0-9]* | 0)
        printf 'QWEN_IMAGE_TIMEOUT_S must be a positive integer: %s\n' "$timeout_seconds" >&2
        exit 1
        ;;
esac

if [ ! -x "$runtime" ]; then
    printf 'runtime binary is missing or not executable: %s\n' "$runtime" >&2
    exit 1
fi
# sd-cli's --model reads a single checkpoint or a diffusers directory, which
# src/model_loader.cpp resolves by fixed relative paths; SDXS-512 ships the
# directory form, so a directory is admitted when it holds safetensors files.
if [ -d "$model_path" ]; then
    for required_model_component in \
        unet/diffusion_pytorch_model.safetensors \
        vae/diffusion_pytorch_model.safetensors \
        text_encoder/model.safetensors; do
        if [ ! -f "$model_path/$required_model_component" ]; then
            printf 'model directory lacks required component %s: %s\n' \
                "$required_model_component" "$model_path" >&2
            exit 1
        fi
    done
elif [ ! -f "$model_path" ]; then
    printf 'model file is missing: %s\n' "$model_path" >&2
    exit 1
fi

if [ "${QWEN_IMAGE_ALLOW_LLAMA_RESIDENT:-0}" != 1 ] && command -v pgrep >/dev/null 2>&1; then
    if pgrep -f '(^|/)(llama-server|llama-cli|llama-bench)( |$)' >/dev/null 2>&1; then
        printf 'a llama Vulkan workload is resident; tear it down before an image run\n' >&2
        printf 'set QWEN_IMAGE_ALLOW_LLAMA_RESIDENT=1 to override\n' >&2
        exit 1
    fi
fi

if [ -e "$output_directory" ]; then
    if [ ! -d "$output_directory" ]; then
        printf 'output path is not a directory: %s\n' "$output_directory" >&2
        exit 1
    fi
    if find "$output_directory" -mindepth 1 -print -quit | grep -q .; then
        printf 'output directory is not empty; campaign artifacts are immutable: %s\n' \
            "$output_directory" >&2
        exit 1
    fi
else
    mkdir -p "$output_directory"
fi

if [ -z "$workload_lock" ] || [ "${workload_lock#/}" = "$workload_lock" ]; then
    printf 'QWEN_VULKAN_WORKLOAD_LOCK must name the absolute shared lease path\n' >&2
    exit 1
fi
if [ ! -d "$(dirname -- "$workload_lock")" ]; then
    printf 'workload lease directory is absent: %s\n' "$(dirname -- "$workload_lock")" >&2
    exit 1
fi
exec 9>"$workload_lock"
if ! flock -n 9; then
    printf 'another Vulkan workload holds the shared lease: %s\n' "$workload_lock" >&2
    exit 1
fi
if [ -z "$post_llm_control" ] || [ ! -x "$post_llm_control" ]; then
    printf 'QWEN_IMAGE_POST_LLM_CONTROL must name an executable health control\n' >&2
    exit 1
fi

binary_sha256=$(sha256sum "$runtime" | awk '{ print $1 }')
model_sha256=deferred-until-after-cold-arm

hash_model_path() {
    if [ "${QWEN_IMAGE_SKIP_MODEL_HASH:-0}" = 1 ]; then
        printf 'unavailable\n'
        return 0
    fi
    if [ ! -d "$model_path" ]; then
        model_hash_output=$(sha256sum "$model_path") || return 1
        model_file_digest=${model_hash_output%% *}
        [ "${#model_file_digest}" -eq 64 ] || return 1
        printf '%s\n' "$model_file_digest"
        return
    fi
    component_list=$output_directory/model-components.list
    component_hashes=$output_directory/model-components.sha256
    (cd "$model_path" && find . -type f -name '*.safetensors' -print | LC_ALL=C sort) \
        >"$component_list"
    : >"$component_hashes"
    while IFS= read -r relative_component; do
        component_hash_output=$(cd "$model_path" && sha256sum "$relative_component") ||
            return 1
        component_digest=${component_hash_output%% *}
        [ "${#component_digest}" -eq 64 ] || return 1
        case $component_digest in
            *[!0-9a-f]*) return 1 ;;
        esac
        printf '%s  %s\n' "$component_digest" "$relative_component" >>"$component_hashes"
    done <"$component_list"
    sha256sum "$component_hashes" | awk '{ print $1 }'
}

# Vulkan identity, read the way remote/probe-depth-wedge.sh reads it: driver
# info from vulkaninfo, kernel release, and the amdgpu module version.
mesa_radv_version=unavailable
if command -v "$vulkaninfo_command" >/dev/null 2>&1; then
    parsed_driver=$(timeout 5s "$vulkaninfo_command" --summary 2>/dev/null |
        awk -F': *' '/driverInfo/ { print $2; exit }')
    [ -z "$parsed_driver" ] || mesa_radv_version=$parsed_driver
fi
kernel_release=$(uname -r)
amdgpu_module_version=unavailable
if command -v modinfo >/dev/null 2>&1; then
    parsed_module=$(modinfo amdgpu 2>/dev/null |
        awk -F': *' '/^version:/ { print $2; exit }')
    [ -z "$parsed_module" ] || amdgpu_module_version=$parsed_module
fi

# --list-devices is the device-name authority
# (evidence/image-appliance/stable-diffusion-cpp-pin.md): its description
# field, not a hardcoded index, is what proves the resolved device is this
# appliance's RADV RAVEN2 rather than whichever Vulkan device enumerated
# first.
# The listing contract is one `name<TAB>description` line per device on
# stdout; ggml prints its device banner on stderr with the same description,
# so reading both streams would match the banner first and pass a
# description where --backend takes a name.
device_listing_stdout=$output_directory/device-listing.stdout
device_listing_stderr=$output_directory/device-listing.stderr
if ! timeout --signal=TERM --kill-after=2 "$timeout_seconds" \
    "$runtime" --list-devices 9>&- >"$device_listing_stdout" 2>"$device_listing_stderr"; then
    printf 'runtime refused --list-devices:\n' >&2
    sed -n '1,80p' "$device_listing_stderr" >&2
    sed -n '1,80p' "$device_listing_stdout" >&2
    exit 1
fi
device_listing=$(cat "$device_listing_stdout")
device_pattern=${QWEN_IMAGE_DEVICE_PATTERN:-'RADV RAVEN2'}
device_line=$(printf '%s\n' "$device_listing" | grep -F "$device_pattern" |
    grep "$(printf '\t')" | head -n 1)
if [ -z "$device_line" ]; then
    printf 'no --list-devices entry names %s:\n%s\n' "$device_pattern" "$device_listing" >&2
    exit 1
fi
if printf '%s\n' "$device_line" | grep -Eqi 'llvmpipe|lavapipe|AMDGPU-PRO'; then
    printf 'refusing the selected non-RADV Vulkan device: %s\n' "$device_line" >&2
    exit 1
fi
device_name=$(printf '%s' "$device_line" | awk -F'\t' '{ print $1 }')
if [ -z "$device_name" ]; then
    printf 'could not parse a device name from: %s\n' "$device_line" >&2
    exit 1
fi
image_backend=${QWEN_IMAGE_BACKEND:-"te=$device_name,vae=$device_name,diffusion=$device_name"}

summary_path=$output_directory/summary.tsv
# SDXS-512 ships a Tiny AutoEncoder in place of a full VAE, which sd-cli loads
# through --taesd rather than from the directory's vae/ slot; the metadata
# check refuses the tiny decoder under the full-VAE slot. QWEN_IMAGE_TAESD
# names that file and the summary records its digest.
taesd_path=${QWEN_IMAGE_TAESD:-}
vae_path=${QWEN_IMAGE_VAE:-}
lora_directory=${QWEN_IMAGE_LORA_DIR:-}
taesd_sha256=-
if [ -n "$taesd_path" ]; then
    if [ ! -f "$taesd_path" ]; then
        printf 'taesd file is missing: %s\n' "$taesd_path" >&2
        exit 1
    fi
    taesd_sha256=$(sha256sum "$taesd_path" | awk '{ print $1 }')
fi
if [ -n "$vae_path" ] && [ ! -f "$vae_path" ]; then
    printf 'vae file is missing: %s\n' "$vae_path" >&2
    exit 1
fi
if [ -n "$lora_directory" ] && [ ! -d "$lora_directory" ]; then
    printf 'LoRA directory is missing: %s\n' "$lora_directory" >&2
    exit 1
fi

prompt_sha256=$(printf '%s' "$prompt" | sha256sum | awk '{ print $1 }')
negative_prompt_sha256=$(printf '%s' "$negative_prompt" | sha256sum | awk '{ print $1 }')
summary_header='arm	status	exit_status	timed_out	binary_sha256	model_sha256	device_name	backend	prompt_sha256	negative_prompt_sha256	seed	width	height	steps	sampler	cfg_scale	wall_load_s	text_encoder_s	diffusion_s	vae_s	total_generate_s	residual_encode_overhead_s	shell_wall_s	rss_peak_kib	pss_peak_kib	mem_available_min_kib	swap_free_delta_kib	vram_used_bytes	gtt_used_bytes	mclk_modal_mhz	temp_millidegrees_max	ring_resets	gpu_faults	dmesg_state	png_path	png_sha256	taesd_sha256'
printf '%s\n' "$summary_header" >"$summary_path"

start_kernel_capture() {
    capture_file=$1
    : >"$capture_file"
    if command -v dmesg >/dev/null 2>&1 && dmesg >/dev/null 2>&1; then
        dmesg --follow-new 9>&- >"$capture_file" 2>/dev/null &
        printf '%s\n' "$!"
    else
        printf '\n'
    fi
}

stop_kernel_capture() {
    capture_pid=$1
    [ -n "$capture_pid" ] || return 0
    kill -TERM "$capture_pid" 2>/dev/null || true
    wait "$capture_pid" 2>/dev/null || true
}

# Poll one child process's RSS, its smaps_rollup PSS, and system-wide
# MemAvailable/SwapFree until the process is gone. Runs in the background
# beside the timeout watchdog in run_arm.
poll_process() {
    poll_pid=$1
    poll_file=$2
    : >"$poll_file"
    while kill -0 "$poll_pid" 2>/dev/null; do
        poll_rss=$(awk '/VmRSS/ { print $2 }' "/proc/$poll_pid/status" 2>/dev/null) || poll_rss=''
        poll_pss=$(awk '/^Pss:/ { sum += $2 } END { if (NR > 0) print sum + 0 }' \
            "/proc/$poll_pid/smaps_rollup" 2>/dev/null) || poll_pss=''
        poll_mem_available=$(awk '/MemAvailable/ { print $2 }' /proc/meminfo 2>/dev/null) || poll_mem_available=''
        poll_swap_free=$(awk '/SwapFree/ { print $2 }' /proc/meminfo 2>/dev/null) || poll_swap_free=''
        printf '%s\t%s\t%s\t%s\n' "${poll_rss:-unavailable}" "${poll_pss:-unavailable}" \
            "${poll_mem_available:-unavailable}" "${poll_swap_free:-unavailable}" >>"$poll_file"
        sleep "$poll_interval" 2>/dev/null || sleep 1
    done
}

max_column() {
    max_file=$1
    max_field=$2
    awk -F'\t' -v field="$max_field" '
        $field != "unavailable" && $field != "" {
            if (!seen || $field > best) { best = $field; seen = 1 }
        }
        END { print seen ? best : "unavailable" }
    ' "$max_file"
}

min_column() {
    min_file=$1
    min_field=$2
    awk -F'\t' -v field="$min_field" '
        $field != "unavailable" && $field != "" {
            if (!seen || $field < best) { best = $field; seen = 1 }
        }
        END { print seen ? best : "unavailable" }
    ' "$min_file"
}

active_runtime_pid=''
active_poll_pid=''
active_clocks_pid=''
active_kernel_pid=''
cleanup_active_processes() {
    for cleanup_pid in "$active_runtime_pid" "$active_poll_pid" "$active_clocks_pid" "$active_kernel_pid"; do
        [ -n "$cleanup_pid" ] || continue
        kill -TERM "$cleanup_pid" 2>/dev/null || true
    done
    sleep 1
    for cleanup_pid in "$active_runtime_pid" "$active_poll_pid" "$active_clocks_pid" "$active_kernel_pid"; do
        [ -n "$cleanup_pid" ] || continue
        kill -KILL "$cleanup_pid" 2>/dev/null || true
        wait "$cleanup_pid" 2>/dev/null || true
    done
}
trap 'cleanup_active_processes; exit 129' HUP
trap 'cleanup_active_processes; exit 130' INT
trap 'cleanup_active_processes; exit 143' TERM

# The device-refusal control: a deliberately unresolvable backend name at the
# smallest possible workload, run before every generation arm so a launch
# that could not prove the refusal path never reports a generation result as
# strictly placed.
run_refusal_control() {
    refused_device_name=${device_name}_refusal_control_$$
    control_log=$output_directory/device-refusal-control.log
    control_dmesg=$output_directory/device-refusal-control.dmesg.txt
    control_kernel_pid=$(start_kernel_capture "$control_dmesg")
    active_kernel_pid=$control_kernel_pid
    set +e
    # QWEN_FAKE_IMAGE_MODE=device_refusal is unread by the real pinned binary,
    # which refuses on the unresolvable --backend value alone
    # (evidence/image-appliance/stable-diffusion-cpp-pin.md); it is what
    # remote/test-fixtures/fake-image-runtime.sh needs to take the same
    # refusal path, since the fixture does not itself resolve device names.
    set -- "$runtime" --model "$model_path" \
        --output "$output_directory/device-refusal-control.png" \
        --prompt "$prompt" --negative-prompt "$negative_prompt" \
        --width 64 --height 64 --steps 1 --seed "$image_seed" \
        --sampling-method "$image_sampler" --cfg-scale "$image_cfg_scale" \
        --backend "te=$refused_device_name,vae=$refused_device_name,diffusion=$refused_device_name"
    [ -z "$taesd_path" ] || set -- "$@" --taesd "$taesd_path"
    [ -z "$vae_path" ] || set -- "$@" --vae "$vae_path"
    [ -z "$lora_directory" ] || set -- "$@" --lora-model-dir "$lora_directory"
    QWEN_FAKE_IMAGE_MODE=device_refusal timeout --signal=TERM --kill-after=2 \
        "$timeout_seconds" "$@" 9>&- >"$control_log" 2>&1
    control_exit_status=$?
    set -e
    stop_kernel_capture "$control_kernel_pid"
    active_kernel_pid=''
    if [ "$control_exit_status" -eq 0 ]; then
        printf 'the device-refusal control accepted an unresolvable backend name: %s\n' \
            "$refused_device_name" >&2
        printf 'strict device selection is not proven for this binary; refusing to run generation arms\n' >&2
        exit 1
    fi
    if [ "$control_exit_status" -eq 124 ] || [ "$control_exit_status" -eq 137 ]; then
        printf 'the device-refusal control exceeded its %ss deadline\n' \
            "$timeout_seconds" >&2
        exit 1
    fi
    if ! grep -Eqi 'backend.*(not found|unresolv|failed)' "$control_log"; then
        printf 'the refusal control failed without proving backend rejection\n' >&2
        sed -n '1,80p' "$control_log" >&2
        exit 1
    fi
    if [ -e "$output_directory/device-refusal-control.png" ]; then
        printf 'the device-refusal control produced an image despite a nonzero exit\n' >&2
        exit 1
    fi
    printf 'device_refusal_control=accepted exit_status=%s device=%s\n' \
        "$control_exit_status" "$refused_device_name"
}

run_arm() {
    arm_label=$1
    arm_png=$output_directory/$arm_label.png
    arm_log=$output_directory/$arm_label.log
    arm_poll=$output_directory/$arm_label.proc-poll.tsv
    arm_clocks=$output_directory/$arm_label.gpu-clocks.tsv
    arm_dmesg=$output_directory/$arm_label.dmesg.txt
    rm -f "$arm_png" "$arm_log"

    "$script_directory/sample-gpu-clocks.sh" "$arm_clocks" 2 9>&- >/dev/null 2>&1 &
    clocks_pid=$!
    active_clocks_pid=$clocks_pid

    kernel_pid=$(start_kernel_capture "$arm_dmesg")
    active_kernel_pid=$kernel_pid
    shell_start_epoch=$(date +%s.%N 2>/dev/null || date +%s)

    set -- "$runtime" --model "$model_path" --output "$arm_png" \
        --prompt "$prompt" --negative-prompt "$negative_prompt" \
        --width "$image_width" --height "$image_height" --steps "$image_steps" \
        --seed "$image_seed" --sampling-method "$image_sampler" \
        --cfg-scale "$image_cfg_scale" --backend "$image_backend"
    [ -z "$taesd_path" ] || set -- "$@" --taesd "$taesd_path"
    [ -z "$vae_path" ] || set -- "$@" --vae "$vae_path"
    [ -z "$lora_directory" ] || set -- "$@" --lora-model-dir "$lora_directory"
    timeout --signal=TERM --kill-after=2 "$timeout_seconds" "$@" 9>&- \
        >"$arm_log" 2>&1 &
    child_pid=$!
    active_runtime_pid=$child_pid

    poll_process "$child_pid" "$arm_poll" 9>&- &
    poll_pid=$!
    active_poll_pid=$poll_pid

    set +e
    wait "$child_pid"
    exit_status=$?
    set -e
    active_runtime_pid=''
    timed_out=0
    if [ "$exit_status" -eq 124 ] || [ "$exit_status" -eq 137 ]; then
        timed_out=1
    fi
    wait "$poll_pid" 2>/dev/null || true
    active_poll_pid=''

    shell_end_epoch=$(date +%s.%N 2>/dev/null || date +%s)
    shell_wall_s=$(awk -v a="$shell_start_epoch" -v b="$shell_end_epoch" \
        'BEGIN { printf "%.3f", b - a }')

    kill "$clocks_pid" 2>/dev/null || true
    wait "$clocks_pid" 2>/dev/null || true
    active_clocks_pid=''
    stop_kernel_capture "$kernel_pid"
    active_kernel_pid=''

    dmesg_state=unavailable
    ring_resets=unavailable
    gpu_faults=unavailable
    if [ -f "$arm_dmesg" ]; then
        dmesg_state=captured
        ring_resets=$(grep -c 'ring reset\|Ring .* reset\|device wedged\|GPU reset' \
            "$arm_dmesg" 2>/dev/null || true)
        gpu_faults=$(grep -c 'page fault\|VM_L2_PROTECTION_FAULT\|PROTECTION_FAULT' \
            "$arm_dmesg" 2>/dev/null || true)
    fi

    text_encoder_s=$(awk -F'taking ' '/get_learned_condition completed/ { gsub(/s$/, "", $2); print $2; exit }' "$arm_log")
    diffusion_s=$(awk -F'taking ' '/sampling completed/ { gsub(/s$/, "", $2); print $2; exit }' "$arm_log")
    vae_s=$(awk -F'taking ' '/decode_first_stage completed/ { gsub(/s$/, "", $2); print $2; exit }' "$arm_log")
    total_generate_s=$(awk -F'completed in ' '/generate_image completed in/ { gsub(/s$/, "", $2); print $2; exit }' "$arm_log")
    [ -n "$text_encoder_s" ] || text_encoder_s=unavailable
    [ -n "$diffusion_s" ] || diffusion_s=unavailable
    [ -n "$vae_s" ] || vae_s=unavailable
    [ -n "$total_generate_s" ] || total_generate_s=unavailable

    residual_encode_overhead_s=unavailable
    if [ "$total_generate_s" != unavailable ] && [ "$text_encoder_s" != unavailable ] &&
        [ "$diffusion_s" != unavailable ] && [ "$vae_s" != unavailable ]; then
        residual_encode_overhead_s=$(awk -v total="$total_generate_s" -v a="$text_encoder_s" \
            -v b="$diffusion_s" -v c="$vae_s" 'BEGIN { printf "%.3f", total - a - b - c }')
    fi
    # sd-cli logs no phase-start timestamp for model loading
    # (evidence/image-appliance/stable-diffusion-cpp-pin.md), so a wall-clock
    # load duration would need a per-line timestamp reader this harness does
    # not build; unavailable is the honest reading rather than a fabricated
    # estimate.
    wall_load_s=unavailable

    rss_peak_kib=unavailable
    pss_peak_kib=unavailable
    mem_available_min_kib=unavailable
    swap_free_delta_kib=unavailable
    if [ -s "$arm_poll" ]; then
        rss_peak_kib=$(max_column "$arm_poll" 1)
        pss_peak_kib=$(max_column "$arm_poll" 2)
        mem_available_min_kib=$(min_column "$arm_poll" 3)
        swap_start=$(awk -F'\t' 'NR == 1 { print $4 }' "$arm_poll")
        swap_end=$(awk -F'\t' 'END { print $4 }' "$arm_poll")
        if [ "$swap_start" != unavailable ] && [ "$swap_end" != unavailable ] &&
            [ -n "$swap_start" ] && [ -n "$swap_end" ]; then
            swap_free_delta_kib=$((swap_start - swap_end))
        fi
    fi

    mclk_modal_mhz=unavailable
    temp_millidegrees_max=unavailable
    vram_used_bytes=unavailable
    gtt_used_bytes=unavailable
    if [ -s "$arm_clocks" ]; then
        mclk_modal_mhz=$(awk -F'\t' '$1 != "unavailable" { count[$1]++ }
            END { best = ""; bestcount = 0
                  for (v in count) { if (count[v] > bestcount) { bestcount = count[v]; best = v } }
                  print (best == "" ? "unavailable" : best) }' "$arm_clocks")
        temp_millidegrees_max=$(max_column "$arm_clocks" 3)
        vram_used_bytes=$(max_column "$arm_clocks" 5)
        gtt_used_bytes=$(max_column "$arm_clocks" 6)
    fi

    placement_ok=1
    placement_line=$(grep 'total params memory size' "$arm_log" | tail -n 1 || true)
    for placement_pair in te:text_encoders vae:vae diffusion:diffusion_model; do
        placement_key=${placement_pair%%:*}
        placement_label=${placement_pair#*:}
        expected_backend=$(printf '%s\n' "$image_backend" | tr ',' '\n' |
            awk -F= -v key="$placement_key" '$1 == key { print tolower($2) }')
        case $expected_backend in
            cpu)
                printf '%s\n' "$placement_line" | grep -F "$placement_label " |
                    grep -q '(RAM)' || placement_ok=0
                ;;
            '') placement_ok=0 ;;
            *)
                printf '%s\n' "$placement_line" | grep -F "$placement_label " |
                    grep -q '(VRAM)' || placement_ok=0
                ;;
        esac
    done

    png_sha256=unavailable
    if [ "$exit_status" -eq 0 ] && [ -f "$arm_png" ]; then
        if PYTHONDONTWRITEBYTECODE=1 python3 - "$script_directory/image-service.py" \
            "$arm_png" "$image_width" "$image_height" <<'PYTHON'
import importlib.util
import sys

specification = importlib.util.spec_from_file_location("image_service", sys.argv[1])
module = importlib.util.module_from_spec(specification)
specification.loader.exec_module(module)
with open(sys.argv[2], "rb") as handle:
    raw = handle.read(module.ARTIFACT_BYTE_CAP + 1)
module.parse_png(raw, int(sys.argv[3]), int(sys.argv[4]))
PYTHON
        then
            png_sha256=$(sha256sum "$arm_png" | awk '{ print $1 }')
            arm_status=completed
        else
            arm_status=invalid_output
            rm -f "$arm_png"
        fi
    elif [ "$exit_status" -eq 0 ]; then
        arm_status=missing_output
    else
        arm_status=failed
        # A nonzero exit is a refusal to stand behind whatever the runtime
        # wrote before it failed; a leftover file at the output path is not
        # provenance for a failed arm, so it is removed rather than left to
        # be mistaken for one.
        rm -f "$arm_png"
    fi
    if [ "$exit_status" -eq 0 ] && [ "$placement_ok" -ne 1 ]; then
        arm_status=placement_mismatch
        rm -f "$arm_png"
        png_sha256=unavailable
    fi
    if { [ "$ring_resets" != unavailable ] && [ "$ring_resets" -gt 0 ]; } ||
       { [ "$gpu_faults" != unavailable ] && [ "$gpu_faults" -gt 0 ]; }; then
        arm_status=gpu_hazard
        rm -f "$arm_png"
        png_sha256=unavailable
    fi
    if [ "$arm_status" != completed ]; then
        campaign_failed=1
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$arm_label" "$arm_status" "$exit_status" "$timed_out" "$binary_sha256" "$model_sha256" \
        "$device_name" "$image_backend" "$prompt_sha256" "$negative_prompt_sha256" "$image_seed" \
        "$image_width" "$image_height" "$image_steps" "$image_sampler" "$image_cfg_scale" "$wall_load_s" "$text_encoder_s" \
        "$diffusion_s" "$vae_s" "$total_generate_s" "$residual_encode_overhead_s" "$shell_wall_s" \
        "$rss_peak_kib" "$pss_peak_kib" "$mem_available_min_kib" "$swap_free_delta_kib" \
        "$vram_used_bytes" "$gtt_used_bytes" "$mclk_modal_mhz" "$temp_millidegrees_max" "$ring_resets" \
        "$gpu_faults" "$dmesg_state" "$arm_png" "$png_sha256" "$taesd_sha256" >>"$summary_path"

    printf 'arm=%s status=%s exit_status=%s wall_s=%s png=%s\n' \
        "$arm_label" "$arm_status" "$exit_status" "$shell_wall_s" "$arm_png"
}

campaign_failed=0
printf 'runtime=%s binary_sha256=%s model_sha256=%s device_name=%s backend=%s mesa_radv=%s kernel=%s amdgpu_module=%s\n' \
    "$runtime" "$binary_sha256" "$model_sha256" "$device_name" "$image_backend" \
    "$mesa_radv_version" "$kernel_release" "$amdgpu_module_version"

run_refusal_control
run_arm cold
if ! model_sha256=$(hash_model_path); then
    printf 'model hashing failed after the cold arm: %s\n' "$model_path" >&2
    exit 1
fi
summary_rewrite=$summary_path.model-hash
awk -F'\t' -v OFS='\t' -v digest="$model_sha256" \
    'NR == 1 { print; next } { $6 = digest; print }' \
    "$summary_path" >"$summary_rewrite"
mv "$summary_rewrite" "$summary_path"
run_arm warm

if [ "$campaign_failed" -ne 0 ]; then
    printf 'one or more image arms failed validation; post-image LLM control is withheld\n' >&2
    exit 1
fi

flock -u 9
if ! timeout --signal=TERM --kill-after=2 "$timeout_seconds" "$post_llm_control"; then
    printf 'the post-image LLM health control failed\n' >&2
    exit 1
fi

printf 'summary=%s\n' "$summary_path"
