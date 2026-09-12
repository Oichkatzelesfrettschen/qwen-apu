#!/bin/sh
set -eu
# Hold the graphics part at its highest commandable states for the appliance's
# whole serving life.
#
# `power_dpm_force_performance_level=auto` hands the choice to the SMU, which
# reads a decode as a low-use workload: measured on this part on 2026-09-12 it
# selected 400 MHz of the 1100 MHz engine table while a 2B checkpoint decoded
# at 4.16 tok/s, against 9.46 tok/s recorded for the same checkpoint at the
# forced point. Serving is not a low-use workload and the part cannot infer
# that from utilization, so the operating point is stated rather than left to
# the governor.
#
# `manual` with `pp_dpm_sclk` at its top index and `pp_dpm_mclk` at 933 MHz is
# that point. The 1067 MHz memory state is firmware-selected and refuses a hard
# minimum, and `high` and `profile_peak` pin the engine at 1100 MHz while
# dropping delivered fabric to 400 MHz, which decodes the 2B at 6 to 7 tok/s:
# both are why this script writes the levels itself rather than naming a
# performance mode. docs/doctrine/hardware-and-measurement.md carries the
# register reads behind each of those numbers.
#
# The three attributes arrive owned by root at mode 0644.
# `remote/install-amdgpu-clock-access.sh` installs the udev rule that hands
# them to the `video` group once, after which every write here needs no
# privilege at all and a reboot re-applies the rule before anything serves.
# Where that rule is absent the writes fall back to `sudo -n`, which needs the
# global timestamp `/etc/sudoers.d/90-qwen-agent` declares to be live; this
# script states that rather than prompting inside a launch that has forked.

usage() {
    printf 'usage: %s apply|report|restore [DRM_DEVICE]\n' "$0" >&2
    printf 'device from QWEN_DRM_DEVICE, default the amdgpu card carrying pp_dpm_sclk\n' >&2
    exit 2
}

[ "$#" -ge 1 ] || usage
action=$1
[ "$#" -le 2 ] || usage

resolve_device() {
    if [ -n "${QWEN_DRM_DEVICE:-}" ]; then
        printf '%s\n' "$QWEN_DRM_DEVICE"
        return 0
    fi
    for candidate in /sys/class/drm/card*/device; do
        [ -r "$candidate/pp_dpm_sclk" ] || continue
        printf '%s\n' "$candidate"
        return 0
    done
    printf 'no amdgpu device carries pp_dpm_sclk\n' >&2
    return 1
}

drm_device=${2:-$(resolve_device)}
for required in power_dpm_force_performance_level pp_dpm_sclk pp_dpm_mclk; do
    if [ ! -r "$drm_device/$required" ]; then
        printf '%s carries no %s\n' "$drm_device" "$required" >&2
        exit 1
    fi
done

# The index the part currently delivers, which the table marks with `*`.
selected_index() {
    sed -n 's/^\([0-9]\+\): .*\*$/\1/p' "$drm_device/$1" | head -n 1
}

selected_clock() {
    sed -n 's/^[0-9]\+: \([0-9]\+\)Mhz .*\*$/\1/p' "$drm_device/$1" | head -n 1
}

top_index() {
    sed -n 's/^\([0-9]\+\): .*/\1/p' "$drm_device/$1" | tail -n 1
}

# The memory state this part honors as a hard minimum. The table's last entry
# is 1067 MHz, which the firmware selects for itself and refuses to be held at,
# so the highest honored state is the one below it where the table carries one.
memory_index() {
    highest=$(top_index pp_dpm_mclk)
    if [ "$(sed -n 's/^'"$highest"': \([0-9]\+\)Mhz.*/\1/p' "$drm_device/pp_dpm_mclk")" = 1067 ] &&
        [ "$highest" -gt 0 ]; then
        printf '%s\n' "$((highest - 1))"
        return 0
    fi
    printf '%s\n' "$highest"
}

# The udev rule hands these attributes to `video`, so the ordinary write is the
# one that needs nothing. A checkout on a host without that rule falls back to
# the sudo timestamp, and a host with neither reports rather than prompts.
write_attribute() {
    if [ -w "$drm_device/$1" ]; then
        printf '%s\n' "$2" > "$drm_device/$1"
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        printf '%s\n' "$2" | sudo -n tee "$drm_device/$1" >/dev/null
        return 0
    fi
    return 1
}

report_state() {
    printf 'graphics_state level=%s sclk_index=%s sclk_mhz=%s mclk_index=%s mclk_mhz=%s\n' \
        "$(cat "$drm_device/power_dpm_force_performance_level")" \
        "${1:-$(selected_index pp_dpm_sclk)}" "$(selected_clock pp_dpm_sclk)" \
        "$(selected_index pp_dpm_mclk)" "$(selected_clock pp_dpm_mclk)"
}

case $action in
    report)
        report_state
        ;;
    apply)
        engine=$(top_index pp_dpm_sclk)
        memory=$(memory_index)
        if ! write_attribute power_dpm_force_performance_level manual; then
            printf 'graphics_state=unpinned reason=no-write-access\n' >&2
            printf 'install the udev rule with remote/install-amdgpu-clock-access.sh install,\n' >&2
            printf 'or warm the sudo timestamp with `sudo -v`, then repeat this command\n' >&2
            report_state >&2
            exit 3
        fi
        write_attribute pp_dpm_sclk "$engine"
        write_attribute pp_dpm_mclk "$memory"
        # The write is a request; the delivered table is the answer, and a
        # state that did not take is reported rather than assumed.
        delivered_engine=$(selected_index pp_dpm_sclk)
        delivered_memory=$(selected_index pp_dpm_mclk)
        report_state
        if [ "$delivered_engine" != "$engine" ] || [ "$delivered_memory" != "$memory" ]; then
            printf 'graphics_state=refused requested_sclk=%s requested_mclk=%s\n' \
                "$engine" "$memory" >&2
            exit 1
        fi
        printf 'graphics_state=pinned\n'
        ;;
    restore)
        if ! write_attribute power_dpm_force_performance_level auto; then
            printf 'graphics_state=unchanged reason=no-write-access\n' >&2
            exit 3
        fi
        report_state
        ;;
    *)
        usage
        ;;
esac
