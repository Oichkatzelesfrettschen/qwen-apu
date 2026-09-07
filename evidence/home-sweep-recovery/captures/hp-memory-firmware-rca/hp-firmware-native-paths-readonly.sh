#!/usr/bin/env bash
set -u

run_probe() {
    probe_name=$1
    shift
    printf '\nPROBE %s\n' "$probe_name"
    "$@"
    probe_status=$?
    printf 'PROBE_STATUS %s %d\n' "$probe_name" "$probe_status"
}

date -u +%FT%TZ
run_probe fwupdmgr-version fwupdmgr --version
run_probe fwupdmgr-remotes fwupdmgr get-remotes
run_probe fwupdmgr-devices fwupdmgr get-devices
run_probe fwupdmgr-devices-json fwupdmgr get-devices --json
run_probe fwupdmgr-refresh fwupdmgr refresh --force
run_probe fwupdmgr-updates fwupdmgr get-updates
run_probe fwupdmgr-updates-json fwupdmgr get-updates --json
run_probe fwupdmgr-history fwupdmgr get-history
run_probe fwupdmgr-bios-settings fwupdmgr get-bios-settings
run_probe mokutil-secure-boot mokutil --sb-state
run_probe bootctl-status bootctl status
run_probe efibootmgr sudo efibootmgr -v
run_probe efi-variable-directory sudo find /sys/firmware/efi/efivars -maxdepth 1 -type f -printf '%f\n'
