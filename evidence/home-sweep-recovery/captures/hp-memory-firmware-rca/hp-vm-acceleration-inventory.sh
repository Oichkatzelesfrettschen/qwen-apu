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
run_probe lscpu lscpu
run_probe memory free -h
run_probe kvm-device ls -l /dev/kvm
run_probe kvm-modules sh -c "lsmod | grep -E '^kvm|^vfio'"
run_probe kvm-amd-parameters sh -c "for parameter_file in /sys/module/kvm_amd/parameters/*; do printf '%s=' \"\$parameter_file\"; cat \"\$parameter_file\"; done"
run_probe iommu-kernel-log sudo sh -c "dmesg | grep -Ei 'AMD-Vi|IOMMU|IVRS|VFIO'"
run_probe iommu-groups sudo sh -c "find /sys/kernel/iommu_groups -maxdepth 2 -type l -print | sort"
run_probe pci-drivers lspci -nnk
run_probe virtualization-tools sh -c "command -v qemu-system-x86_64 qemu-img virsh virt-install virt-host-validate vmware vmrun vmware-vdiskmanager"
run_probe qemu-version qemu-system-x86_64 --version
run_probe qemu-accelerators qemu-system-x86_64 -accel help
run_probe qemu-display-help qemu-system-x86_64 -display help
run_probe qemu-machine-help sh -c "qemu-system-x86_64 -machine help | head -30"
run_probe virt-host-validate sudo virt-host-validate qemu
run_probe vmware-version vmware -v
run_probe vmware-modules sh -c "lsmod | grep -E '^vmmon|^vmnet|^vmw_vmci'"
run_probe drm-nodes ls -l /dev/dri
run_probe vulkan-summary vulkaninfo --summary
run_probe block-devices lsblk -e 7 -o NAME,PATH,SIZE,TYPE,FSTYPE,FSVER,MOUNTPOINTS,MODEL
run_probe filesystems df -hT
run_probe mounts findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS
run_probe network ip -brief address
run_probe routes ip route
run_probe bridges ip -details link show type bridge
run_probe libvirt-domains virsh list --all
run_probe libvirt-networks virsh net-list --all
run_probe libvirt-pools virsh pool-list --all
run_probe user-groups id
