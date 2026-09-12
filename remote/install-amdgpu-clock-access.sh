#!/bin/sh
set -eu
# Install the udev rule that lets the appliance state its own operating point.
#
# One privileged action, once. After it the three clock attributes carry group
# write for `video`, every later launch pins its states with no privilege at
# all, and a reboot re-applies the rule before anything serves. `verify` reads
# the modes back and writes nothing, so it answers from an ordinary shell.
#
# The rule itself is runtime/udev/90-qwen-amdgpu-clocks.rules in this checkout
# and carries the reasoning for the access it grants.

usage() {
    printf 'usage: %s install|verify\n' "$0" >&2
    exit 2
}

[ "$#" -eq 1 ] || usage
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
rule_source=$script_directory/../runtime/udev/90-qwen-amdgpu-clocks.rules
rule_target=/etc/udev/rules.d/90-qwen-amdgpu-clocks.rules
attributes='power_dpm_force_performance_level pp_dpm_sclk pp_dpm_mclk'

resolve_device() {
    for candidate in /sys/class/drm/card*/device; do
        [ -r "$candidate/pp_dpm_sclk" ] || continue
        printf '%s\n' "$candidate"
        return 0
    done
    printf 'no amdgpu device carries pp_dpm_sclk\n' >&2
    return 1
}

drm_device=$(resolve_device)

verify_access() {
    verified=0
    for attribute in $attributes; do
        if [ -w "$drm_device/$attribute" ]; then
            verified=$((verified + 1))
        else
            printf 'clock_access=absent attribute=%s\n' "$attribute"
        fi
    done
    if [ -f "$rule_target" ]; then
        rule_state=installed
    else
        rule_state=absent
    fi
    printf 'clock_access verified=%s of 3 rule=%s\n' "$verified" "$rule_state"
    [ "$verified" -eq 3 ]
}

case $1 in
    verify)
        verify_access
        ;;
    install)
        if [ ! -f "$rule_source" ]; then
            printf 'the rule is missing from this checkout: %s\n' "$rule_source" >&2
            exit 1
        fi
        if ! sudo -n true 2>/dev/null; then
            printf 'clock_access=unchanged reason=no-live-sudo-timestamp\n' >&2
            printf 'run `sudo -v` on this host, then repeat this command\n' >&2
            exit 3
        fi
        sudo -n install -m 0644 -o root -g root "$rule_source" "$rule_target"
        sudo -n udevadm control --reload-rules
        sudo -n udevadm trigger --subsystem-match=pci --action=change
        # udev applies a rule asynchronously, so the modes are read back rather
        # than assumed.
        attempt=0
        while [ "$attempt" -lt 10 ]; do
            if verify_access >/dev/null 2>&1; then
                break
            fi
            attempt=$((attempt + 1))
            sleep 1
        done
        verify_access
        ;;
    *)
        usage
        ;;
esac
