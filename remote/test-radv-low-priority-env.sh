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

# The diagnostic profile states its whole environment from the profile name
# and QWEN_PERF_LOGGER, so the child's GGML_VK_ set is compared whole against
# the wrapper-wide low-priority flag and the profile's own four exports. The
# ambient logger, statistics, submit-trace, and RADV_DEBUG requests around it
# reach nothing. A serving profile carries the census toggle across the scrub
# under its QWEN_ name and nothing else, so that name is set here to prove the
# diagnostic branch leaves it to the block outside the profile case.
diagnostic_environment=$(GGML_VK_PERF_LOGGER=ambient GGML_VK_PIPELINE_STATS=mul_mat \
    GGML_VK_PERF_LOGGER_CONCURRENT=1 GGML_VK_PERF_LOGGER_FREQUENCY=999 \
    GGML_VK_MEMORY_LOGGER=1 GGML_VK_SUBMIT_TRACE=1 RADV_DEBUG=nohiz \
    QWEN_PERF_LOGGER=4 QWEN_VULKAN_PROFILE=diagnostic \
    GGML_VK_SERIALIZE_SUBMISSIONS=unexpected GGML_VK_MAX_NODES_PER_SUBMIT=999 \
    "$wrapper" sh -c 'env | grep "^GGML_VK_" | sort')
printf '%s\n' "$diagnostic_environment"
diagnostic_expected='GGML_VK_LOW_PRIORITY=1
GGML_VK_MAX_NODES_PER_SUBMIT=32
GGML_VK_PERF_LOGGER=1
GGML_VK_PERF_LOGGER_FREQUENCY=4
GGML_VK_SERIALIZE_SUBMISSIONS=1'
if [ "$diagnostic_environment" != "$diagnostic_expected" ]; then
    printf 'the diagnostic profile exported an environment beyond its declaration\n' >&2
    exit 1
fi
diagnostic_output=$(GGML_VK_MEMORY_LOGGER=1 GGML_VK_SUBMIT_TRACE=1 \
    GGML_VK_PERF_LOGGER_CONCURRENT=1 RADV_DEBUG=nohiz \
    QWEN_PIPELINE_CENSUS=1 QWEN_PERF_LOGGER=4 QWEN_VULKAN_PROFILE=diagnostic \
    "$wrapper" sh -c 'printf "profile=%s memory=%s trace=%s concurrent=%s radv=%s census=%s\n" \
        "$QWEN_VULKAN_PROFILE" "${GGML_VK_MEMORY_LOGGER-unset}" \
        "${GGML_VK_SUBMIT_TRACE-unset}" "${GGML_VK_PERF_LOGGER_CONCURRENT-unset}" \
        "${RADV_DEBUG-unset}" "${GGML_VK_PIPELINE_CENSUS-unset}"')
printf '%s\n' "$diagnostic_output"
printf '%s\n' "$diagnostic_output" | grep -Fx \
    'profile=diagnostic memory=unset trace=unset concurrent=unset radv=unset census=1' >/dev/null

# The same ambient diagnostic request reaches nothing under a serving profile,
# where the scrub alone answers for it.
serving_ambient_output=$(GGML_VK_MEMORY_LOGGER=1 GGML_VK_SUBMIT_TRACE=1 \
    GGML_VK_PERF_LOGGER_CONCURRENT=1 GGML_VK_PIPELINE_STATS=mul_mat \
    RADV_DEBUG=nohiz QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "memory=%s trace=%s concurrent=%s stats=%s radv=%s\n" \
        "${GGML_VK_MEMORY_LOGGER-unset}" "${GGML_VK_SUBMIT_TRACE-unset}" \
        "${GGML_VK_PERF_LOGGER_CONCURRENT-unset}" "${GGML_VK_PIPELINE_STATS-unset}" \
        "${RADV_DEBUG-unset}"')
printf '%s\n' "$serving_ambient_output" | grep -Fx \
    'memory=unset trace=unset concurrent=unset stats=unset radv=unset' >/dev/null

# The sideplane candidate reads its two names through getenv() != NULL, so the
# value 0 enables the feature and its log where the scrub is what keeps a
# control arm a control. The request carries 0 for that reason.
sideplane_ambient_output=$(GGML_VK_Q4K_SIDEPLANE=0 GGML_VK_Q4K_SIDEPLANE_LOG=0 \
    QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "sideplane=%s sideplane_log=%s\n" \
        "${GGML_VK_Q4K_SIDEPLANE-unset}" "${GGML_VK_Q4K_SIDEPLANE_LOG-unset}"')
printf '%s\n' "$sideplane_ambient_output" | grep -Fx \
    'sideplane=unset sideplane_log=unset' >/dev/null

# QWEN_PERF_LOGGER states the logger's frequency as one positive integer, which
# the diagnostic branch turns into the enable flag and the frequency together.
perf_logger_output=$(QWEN_PERF_LOGGER=1 QWEN_VULKAN_PROFILE=diagnostic \
    "$wrapper" sh -c 'printf "perf=%s frequency=%s\n" \
        "${GGML_VK_PERF_LOGGER-unset}" "${GGML_VK_PERF_LOGGER_FREQUENCY-unset}"')
printf '%s\n' "$perf_logger_output" | grep -Fx 'perf=1 frequency=1' >/dev/null
perf_logger_output=$(QWEN_PERF_LOGGER=4 QWEN_VULKAN_PROFILE=diagnostic \
    "$wrapper" sh -c 'printf "perf=%s frequency=%s\n" \
        "${GGML_VK_PERF_LOGGER-unset}" "${GGML_VK_PERF_LOGGER_FREQUENCY-unset}"')
printf '%s\n' "$perf_logger_output" | grep -Fx 'perf=1 frequency=4' >/dev/null
diagnostic_perf_logger_status=0
QWEN_PERF_LOGGER=x QWEN_VULKAN_PROFILE=diagnostic "$wrapper" true \
    >/dev/null 2>/dev/null || diagnostic_perf_logger_status=$?
if [ "$diagnostic_perf_logger_status" -ne 2 ]; then
    printf 'RADV environment wrapper accepted a non-integer QWEN_PERF_LOGGER\n' >&2
    exit 1
fi
# The frequency is the profile's only input, so an absent one leaves the arm's
# environment underdetermined and the profile refuses rather than serving a
# logger-free run under the diagnostic name.
absent_perf_logger_status=0
QWEN_VULKAN_PROFILE=diagnostic "$wrapper" true \
    >/dev/null 2>/dev/null || absent_perf_logger_status=$?
if [ "$absent_perf_logger_status" -ne 2 ]; then
    printf 'RADV environment wrapper accepted a diagnostic profile without QWEN_PERF_LOGGER\n' >&2
    exit 1
fi
# A serving profile measures a rate the appliance serves, so it refuses the
# logger rather than exporting it.
serving_perf_logger_status=0
serving_perf_logger_error=$(QWEN_PERF_LOGGER=1 QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" true 2>&1 >/dev/null) || serving_perf_logger_status=$?
if [ "$serving_perf_logger_status" -ne 2 ]; then
    printf 'RADV environment wrapper accepted QWEN_PERF_LOGGER under low-async\n' >&2
    exit 1
fi
printf '%s\n' "$serving_perf_logger_error" | grep -Fx \
    'QWEN_PERF_LOGGER belongs to the diagnostic profile alone' >/dev/null

serving_census_output=$(GGML_VK_PERF_LOGGER=1 GGML_VK_PIPELINE_CENSUS=stale QWEN_PIPELINE_CENSUS=1 \
    QWEN_VULKAN_PROFILE=low-async "$wrapper" sh -c 'printf "perf=%s census=%s\n" \
        "${GGML_VK_PERF_LOGGER-unset}" "${GGML_VK_PIPELINE_CENSUS-unset}"')
printf '%s\n' "$serving_census_output" | grep -Fx 'perf=unset census=1' >/dev/null
serving_plain_output=$(GGML_VK_PIPELINE_CENSUS=stale QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "census=%s\n" "${GGML_VK_PIPELINE_CENSUS-unset}"')
printf '%s\n' "$serving_plain_output" | grep -Fx 'census=unset' >/dev/null

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
