#!/bin/sh
set -eu

# Run one command against RADV on a shimmed RAVEN2 node, so ACO compiles for
# gfx902 on a host that carries no AMD part.
#
# Mesa 26.2 removed the null winsys: libvulkan_radeon.so answers
# AMD_FORCE_FAMILY with "has been removed. Please use AMDGPU drm-shim now.",
# so the shim rather than an environment variable supplies the device.
# src/amd/drm-shim/amdgpu_noop_drm_shim.c interposes the amdgpu kernel
# interface and src/amd/common/amdgpu_devices.c holds the recorded RAVEN2
# state that AMDGPU_GPU_ID=raven2 selects. RADV then enumerates
# "(RADV RAVEN2)" and vkCreateComputePipelines runs ACO to completion; the
# shimmed node executes no submission, so pipeline creation is the whole
# reach of a run made through this wrapper.
#
# The shim's amdgpu DRM version and the ICD must come from one Mesa release:
# ac_gpu_info.c refuses a node below 3.54.0, which a 25.x shim reports as
# 3.49.0 against a 26.2.1 ICD.
#
# usage: radv-raven2-shim-env.sh COMMAND [ARGUMENT...]

if [ "$#" -lt 1 ]; then
    printf 'usage: %s COMMAND [ARGUMENT...]\n' "$0" >&2
    exit 2
fi

: "${QWEN_RADV_ICD:?QWEN_RADV_ICD names the radeon_icd.json to load}"
: "${QWEN_AMDGPU_DRM_SHIM:?QWEN_AMDGPU_DRM_SHIM names libamdgpu_noop_drm_shim.so}"

AMDGPU_GPU_ID="${AMDGPU_GPU_ID:-raven2}"
export AMDGPU_GPU_ID
export VK_DRIVER_FILES="$QWEN_RADV_ICD"
export LD_PRELOAD="$QWEN_AMDGPU_DRM_SHIM${LD_PRELOAD:+:$LD_PRELOAD}"

exec "$@"
