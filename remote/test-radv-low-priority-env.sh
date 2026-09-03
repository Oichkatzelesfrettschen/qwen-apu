#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
wrapper=$script_directory/radv-low-priority-env.sh

capture_environment() {
    profile=$1
    # The nested shell expands its own runtime environment after the wrapper runs.
    # shellcheck disable=SC2016
    QWEN_VULKAN_PROFILE=$profile AMD_PRIORITY=1023 \
        QWEN_ONE_CORE_ACTIVE=1 QWEN_GUARD_CPU_ACTIVE=1 \
        GGML_VK_ENABLE_MEMORY_PRIORITY=1 GGML_VK_ALLOW_GRAPHICS_QUEUE=1 \
        RADV_PERFTEST=nogttspill \
        GGML_VK_DUTY_CYCLE_PERCENT=99 \
        GGML_VK_SERIALIZE_SUBMISSIONS=unexpected \
        GGML_VK_MAX_NODES_PER_SUBMIT=999 \
        "$wrapper" sh -c '
        printf "affinity=%s\n" "$(awk "/Cpus_allowed_list/ { print \$2 }" /proc/self/status)"
        printf "nice=%s\n" "$(ps -o ni= -p $$ | tr -d " ")"
        printf "io=%s\n" "$(ionice -p $$)"
        printf "profile=%s low=%s duty=%s serialized=%s max_nodes=%s strict=%s\n" \
            "$QWEN_VULKAN_PROFILE" "$GGML_VK_LOW_PRIORITY" \
            "${GGML_VK_DUTY_CYCLE_PERCENT-unset}" \
            "${GGML_VK_SERIALIZE_SUBMISSIONS-unset}" \
            "${GGML_VK_MAX_NODES_PER_SUBMIT-unset}" "$LLAMA_NO_CPU_FALLBACK"
        printf "driver=%s compatibility_driver=%s\n" "$VK_DRIVER_FILES" "$VK_ICD_FILENAMES"
        printf "display=%s wayland=%s sysmem_fallback=%s amd_priority=%s memory_priority=%s allow_graphics=%s radv_perftest=%s\n" \
            "${DISPLAY-unset}" "${WAYLAND_DISPLAY-unset}" \
            "${GGML_VK_ALLOW_SYSMEM_FALLBACK-unset}" "${AMD_PRIORITY-unset}" \
            "${GGML_VK_ENABLE_MEMORY_PRIORITY-unset}" \
            "${GGML_VK_ALLOW_GRAPHICS_QUEUE-unset}" "${RADV_PERFTEST-unset}"
        printf "model_cpu_sentinel=%s guard_cpu_sentinel=%s\n" \
            "${QWEN_ONE_CORE_ACTIVE-unset}" "${QWEN_GUARD_CPU_ACTIVE-unset}"
    '
}

environment_output=$(capture_environment paced-60)

printf '%s\n' "$environment_output"
printf '%s\n' "$environment_output" | grep -F 'affinity=0' >/dev/null
printf '%s\n' "$environment_output" | grep -F 'nice=19' >/dev/null
printf '%s\n' "$environment_output" | grep -F 'io=idle' >/dev/null
printf '%s\n' "$environment_output" | grep -F \
    'profile=paced-60 low=1 duty=60 serialized=1 max_nodes=32 strict=1' >/dev/null
printf '%s\n' "$environment_output" | grep -F \
    'display=unset wayland=unset sysmem_fallback=unset amd_priority=unset memory_priority=unset allow_graphics=unset radv_perftest=unset' >/dev/null
printf '%s\n' "$environment_output" | grep -F \
    'model_cpu_sentinel=unset guard_cpu_sentinel=unset' >/dev/null

environment_output=$(capture_environment low-serialized)
printf '%s\n' "$environment_output" | grep -F \
    'profile=low-serialized low=1 duty=unset serialized=1 max_nodes=32 strict=1' >/dev/null

# The diagnostic profile fixes serialization and restores the diagnostic
# variables the serving profiles scrub; a serving profile carries the census
# toggle across the scrub under its QWEN_ name and nothing else.
diagnostic_output=$(GGML_VK_PERF_LOGGER=1 GGML_VK_PIPELINE_STATS=mul_mat \
    RADV_DEBUG=shaderstats QWEN_PIPELINE_CENSUS=1 QWEN_VULKAN_PROFILE=diagnostic \
    GGML_VK_SERIALIZE_SUBMISSIONS=unexpected GGML_VK_MAX_NODES_PER_SUBMIT=999 \
    "$wrapper" sh -c 'printf "profile=%s serialized=%s max_nodes=%s perf=%s stats=%s radv=%s census=%s\n" \
        "$QWEN_VULKAN_PROFILE" "${GGML_VK_SERIALIZE_SUBMISSIONS-unset}" \
        "${GGML_VK_MAX_NODES_PER_SUBMIT-unset}" "${GGML_VK_PERF_LOGGER-unset}" \
        "${GGML_VK_PIPELINE_STATS-unset}" "${RADV_DEBUG-unset}" "${GGML_VK_PIPELINE_CENSUS-unset}"')
printf '%s\n' "$diagnostic_output"
printf '%s\n' "$diagnostic_output" | grep -Fx \
    'profile=diagnostic serialized=1 max_nodes=32 perf=1 stats=mul_mat radv=shaderstats census=1' >/dev/null
serving_census_output=$(GGML_VK_PERF_LOGGER=1 GGML_VK_PIPELINE_CENSUS=stale QWEN_PIPELINE_CENSUS=1 \
    QWEN_VULKAN_PROFILE=low-async "$wrapper" sh -c 'printf "perf=%s census=%s\n" \
        "${GGML_VK_PERF_LOGGER-unset}" "${GGML_VK_PIPELINE_CENSUS-unset}"')
printf '%s\n' "$serving_census_output" | grep -Fx 'perf=unset census=1' >/dev/null
serving_plain_output=$(GGML_VK_PIPELINE_CENSUS=stale QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "census=%s\n" "${GGML_VK_PIPELINE_CENSUS-unset}"')
printf '%s\n' "$serving_plain_output" | grep -Fx 'census=unset' >/dev/null

# The int24 candidate admits its q8_1 mat-vec pipelines under
# GGML_VK_FORCE_INTEGER_DOT, so a serving profile scrubs it and `custom`
# restores what the caller asked for. The scrub is what keeps the arm and its
# control apart on one binary.
serving_force_dot_output=$(GGML_VK_FORCE_INTEGER_DOT=1 QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "force_integer_dot=%s\n" "${GGML_VK_FORCE_INTEGER_DOT-unset}"')
printf '%s\n' "$serving_force_dot_output" | grep -Fx 'force_integer_dot=unset' >/dev/null
custom_force_dot_output=$(GGML_VK_FORCE_INTEGER_DOT=1 QWEN_VULKAN_PROFILE=custom \
    "$wrapper" sh -c 'printf "force_integer_dot=%s\n" "${GGML_VK_FORCE_INTEGER_DOT-unset}"')
printf '%s\n' "$custom_force_dot_output" | grep -Fx 'force_integer_dot=1' >/dev/null
custom_control_output=$(QWEN_VULKAN_PROFILE=custom \
    "$wrapper" sh -c 'printf "force_integer_dot=%s\n" "${GGML_VK_FORCE_INTEGER_DOT-unset}"')
printf '%s\n' "$custom_control_output" | grep -Fx 'force_integer_dot=unset' >/dev/null

environment_output=$(capture_environment low-async)
printf '%s\n' "$environment_output" | grep -F \
    'profile=low-async low=1 duty=unset serialized=unset max_nodes=16 strict=1' >/dev/null

if QWEN_VULKAN_PROFILE=unknown "$wrapper" true \
    > /dev/null 2> /dev/null; then
    printf 'RADV environment wrapper accepted an unknown profile\n' >&2
    exit 1
fi

device_output=$(QWEN_VULKAN_PROFILE=low-serialized \
    "$wrapper" vulkaninfo --summary 2>&1)
printf '%s\n' "$device_output" | grep -F 'AMD Radeon Graphics (RADV RAVEN2)' >/dev/null
printf 'radv_environment=accepted\n'
