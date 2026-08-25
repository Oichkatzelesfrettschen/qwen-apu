#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
wrapper=$script_directory/radv-low-priority-env.sh

# The nested shell expands its own runtime environment after the wrapper runs.
# shellcheck disable=SC2016
environment_output=$(
    GGML_VK_DUTY_CYCLE_PERCENT=99 "$wrapper" sh -c '
        printf "affinity=%s\n" "$(awk "/Cpus_allowed_list/ { print \$2 }" /proc/self/status)"
        printf "nice=%s\n" "$(ps -o ni= -p $$ | tr -d " ")"
        printf "io=%s\n" "$(ionice -p $$)"
        printf "low=%s duty=%s serialized=%s strict=%s\n" "$GGML_VK_LOW_PRIORITY" "$GGML_VK_DUTY_CYCLE_PERCENT" "$GGML_VK_SERIALIZE_SUBMISSIONS" "$LLAMA_NO_CPU_FALLBACK"
        printf "driver=%s compatibility_driver=%s\n" "$VK_DRIVER_FILES" "$VK_ICD_FILENAMES"
        printf "display=%s wayland=%s sysmem_fallback=%s\n" \
            "${DISPLAY-unset}" "${WAYLAND_DISPLAY-unset}" "${GGML_VK_ALLOW_SYSMEM_FALLBACK-unset}"
    '
)

printf '%s\n' "$environment_output"
printf '%s\n' "$environment_output" | grep -F 'affinity=0' >/dev/null
printf '%s\n' "$environment_output" | grep -F 'nice=19' >/dev/null
printf '%s\n' "$environment_output" | grep -F 'io=idle' >/dev/null
printf '%s\n' "$environment_output" | grep -F 'low=1 duty=60 serialized=1 strict=1' >/dev/null
printf '%s\n' "$environment_output" | grep -F 'display=unset wayland=unset sysmem_fallback=unset' >/dev/null

device_output=$("$wrapper" vulkaninfo --summary 2>&1)
printf '%s\n' "$device_output" | grep -F 'AMD Radeon Graphics (RADV RAVEN2)' >/dev/null
printf 'radv_environment=accepted\n'
