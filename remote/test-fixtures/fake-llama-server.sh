#!/bin/sh
set -eu

if [ -z "${QWEN_POLICY_TEST_OUTPUT:-}" ]; then
    printf 'QWEN_POLICY_TEST_OUTPUT is required\n' >&2
    exit 2
fi

{
    printf 'affinity=%s\n' "$(awk '/Cpus_allowed_list/ { print $2 }' /proc/self/status)"
    printf 'nice=%s\n' "$(ps -o ni= -p $$ | tr -d ' ')"
    printf 'io=%s\n' "$(ionice -p $$)"
    printf 'low=%s\n' "${GGML_VK_LOW_PRIORITY:-unset}"
    printf 'duty=%s\n' "${GGML_VK_DUTY_CYCLE_PERCENT:-unset}"
    printf 'serialized=%s\n' "${GGML_VK_SERIALIZE_SUBMISSIONS:-unset}"
    printf 'max_nodes=%s\n' "${GGML_VK_MAX_NODES_PER_SUBMIT:-unset}"
    printf 'profile=%s\n' "${QWEN_VULKAN_PROFILE:-unset}"
    printf 'amd_priority=%s\n' "${AMD_PRIORITY:-unset}"
    printf 'memory_priority=%s\n' "${GGML_VK_ENABLE_MEMORY_PRIORITY:-unset}"
    printf 'allow_graphics=%s\n' "${GGML_VK_ALLOW_GRAPHICS_QUEUE:-unset}"
    printf 'radv_perftest=%s\n' "${RADV_PERFTEST:-unset}"
    printf 'strict=%s\n' "${LLAMA_NO_CPU_FALLBACK:-unset}"
    printf 'display=%s\n' "${DISPLAY-unset}"
    printf 'wayland=%s\n' "${WAYLAND_DISPLAY-unset}"
    printf 'argument_count=%s\n' "$#"
    for argument in "$@"; do
        printf 'argument=%s\n' "$argument"
    done
} > "$QWEN_POLICY_TEST_OUTPUT"
