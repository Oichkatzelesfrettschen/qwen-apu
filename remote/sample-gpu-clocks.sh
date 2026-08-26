#!/bin/sh
set -eu

# Sample the amdgpu DPM state while a measurement runs, one row per interval.
#
# Decode on this part is bandwidth-bound and the memory controller runs on a
# DPM ladder: `pp_dpm_mclk` offers 933 MHz and 1067 MHz as its top two steps, a
# 12.6% span, and the star marks the step in force. The step moves under
# sustained load, so two rates measured minutes apart can differ by more than
# every effect a sweep is trying to resolve. A rate carries its clock state or
# it is not comparable to another rate.
#
# The caller runs this in the background and kills it when the measurement ends.
# Rows are `mclk_mhz`, `sclk_mhz`, `millidegrees`; a reader that cannot be read
# writes 0 rather than stopping the sampler.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s OUTPUT_TSV [INTERVAL_SECONDS]\n' "$0" >&2
    exit 2
fi

output_tsv=$1
interval_seconds=${2:-2}
drm_device=${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}

amdgpu_hwmon=''
for candidate in /sys/class/hwmon/hwmon*; do
    if [ "$(cat "$candidate/name" 2>/dev/null)" = amdgpu ]; then
        amdgpu_hwmon=$candidate
        break
    fi
done

: >"$output_tsv"
while :; do
    mclk=$(awk '/\*/ { gsub(/Mhz|:/, "", $2); print $2; exit }' \
        "$drm_device/pp_dpm_mclk" 2>/dev/null) || mclk=''
    sclk=$(awk '/\*/ { gsub(/Mhz|:/, "", $2); print $2; exit }' \
        "$drm_device/pp_dpm_sclk" 2>/dev/null) || sclk=''
    temperature=''
    if [ -n "$amdgpu_hwmon" ]; then
        temperature=$(cat "$amdgpu_hwmon/temp1_input" 2>/dev/null) || temperature=''
    fi
    printf '%s\t%s\t%s\n' "${mclk:-0}" "${sclk:-0}" "${temperature:-0}" \
        >>"$output_tsv"
    sleep "$interval_seconds"
done
