# shellcheck shell=sh
# A fixture sysfs tree for the power-factorial harness's device-facing
# scripts (compute-state-lease.sh, cpu-frequency-cap.sh): the DRM device's DPM
# tables, the amdgpu and k10temp hwmon directories, the KSM run node, and the
# per-core cpufreq directories cpu-frequency-cap.sh reads and cpupower writes.
# Sourced rather than executed, so the caller's own QWEN_SYSFS_ROOT and every
# path it derives stay in the caller's own shell.
#
# fake_sysfs_create SYSFS_ROOT builds the tree; fake_sysfs_reset SYSFS_ROOT
# resets every file to the same baseline compute-state-lease.sh's own test
# resets to, so a caller that pins QWEN_SYSFS_ROOT to a stable path (rather
# than a fresh mktemp per case) can reuse the tree across cases the way
# remote/test-compute-state-lease.sh's own reset_fixture does.

fake_sysfs_create() {
    fake_sysfs_root=$1
    fake_sysfs_drm=$fake_sysfs_root/class/drm/card1/device
    fake_sysfs_hwmon=$fake_sysfs_root/class/hwmon
    fake_sysfs_ksm=$fake_sysfs_root/kernel/mm/ksm
    fake_sysfs_cpu=$fake_sysfs_root/devices/system/cpu
    mkdir -p "$fake_sysfs_drm" "$fake_sysfs_hwmon/hwmon0" "$fake_sysfs_hwmon/hwmon1" \
        "$fake_sysfs_ksm" "$fake_sysfs_cpu/cpu0/cpufreq" "$fake_sysfs_cpu/cpu1/cpufreq" \
        "$fake_sysfs_cpu/cpufreq"
    printf 'nvme\n' >"$fake_sysfs_hwmon/hwmon0/name"
    printf '41000\n' >"$fake_sysfs_hwmon/hwmon0/temp1_input"
    printf 'amdgpu\n' >"$fake_sysfs_hwmon/hwmon1/name"
    printf '75000\n' >"$fake_sysfs_hwmon/hwmon1/temp1_input"
}

fake_sysfs_reset() {
    fake_sysfs_root=$1
    fake_sysfs_drm=$fake_sysfs_root/class/drm/card1/device
    fake_sysfs_hwmon=$fake_sysfs_root/class/hwmon
    fake_sysfs_ksm=$fake_sysfs_root/kernel/mm/ksm
    fake_sysfs_cpu=$fake_sysfs_root/devices/system/cpu
    printf 'manual\n' >"$fake_sysfs_drm/power_dpm_force_performance_level"
    printf '0: 200Mhz\n1: 400Mhz *\n2: 1100Mhz\n' >"$fake_sysfs_drm/pp_dpm_sclk"
    printf '0: 0Mhz\n1: 400Mhz *\n2: 933Mhz\n3: 1067Mhz\n' >"$fake_sysfs_drm/pp_dpm_mclk"
    printf '400000000\n' >"$fake_sysfs_hwmon/hwmon1/freq1_input"
    printf '1\n' >"$fake_sysfs_ksm/run"
    printf '3200000\n' >"$fake_sysfs_cpu/cpu0/cpufreq/scaling_max_freq"
    printf '3200000\n' >"$fake_sysfs_cpu/cpu1/cpufreq/scaling_max_freq"
    printf 'schedutil\n' >"$fake_sysfs_cpu/cpu0/cpufreq/scaling_governor"
    printf 'schedutil\n' >"$fake_sysfs_cpu/cpu1/cpufreq/scaling_governor"
    printf '1\n' >"$fake_sysfs_cpu/cpufreq/boost"
}
