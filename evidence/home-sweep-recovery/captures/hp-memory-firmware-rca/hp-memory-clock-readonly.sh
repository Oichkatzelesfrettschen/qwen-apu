#!/usr/bin/env bash
set -euo pipefail

date -u +%FT%TZ

for telemetry_file in \
    /sys/class/drm/card*/device/pp_dpm_mclk \
    /sys/class/drm/card*/device/pp_dpm_fclk \
    /sys/class/drm/card*/device/pp_dpm_socclk \
    /sys/class/drm/card*/device/pp_dpm_dcefclk
do
    if test -r "$telemetry_file"; then
        printf 'FILE %s\n' "$telemetry_file"
        cat "$telemetry_file"
    fi
done

for debug_file in \
    /sys/kernel/debug/dri/*/amdgpu_pm_info \
    /sys/kernel/debug/dri/*/amdgpu_firmware_info
do
    if sudo test -r "$debug_file"; then
        printf 'FILE %s\n' "$debug_file"
        sudo cat "$debug_file"
    fi
done

if test -d /sys/devices/system/edac; then
    find /sys/devices/system/edac -maxdepth 4 -type f -print -exec cat {} \; 2>/dev/null || true
fi

perf list 2>/dev/null | rg -i 'dram|umc|data fabric|amd_df|mem.*bandwidth' || true
lspci -nn \
    -s 00:18.0 -s 00:18.1 -s 00:18.2 -s 00:18.3 \
    -s 00:18.4 -s 00:18.5 -s 00:18.6 -s 00:18.7
