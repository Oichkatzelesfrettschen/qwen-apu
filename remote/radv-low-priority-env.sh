#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
    printf 'usage: %s COMMAND [ARG ...]\n' "$0" >&2
    exit 2
fi

if [ "${QWEN_ONE_CORE_ACTIVE:-0}" != 1 ]; then
    renice -n 19 -p $$ >/dev/null
    QWEN_ONE_CORE_ACTIVE=1 exec taskset -c 0 ionice -c 3 "$0" "$@"
fi

radv_icd=${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
if [ ! -r "$radv_icd" ]; then
    printf 'RADV ICD is not readable: %s\n' "$radv_icd" >&2
    exit 1
fi

unset DISPLAY
unset WAYLAND_DISPLAY
unset GGML_VK_ALLOW_SYSMEM_FALLBACK

export VK_DRIVER_FILES="$radv_icd"
export VK_ICD_FILENAMES="$radv_icd"
export GGML_VK_LOW_PRIORITY=1
export LLAMA_NO_CPU_FALLBACK=1

exec "$@"
