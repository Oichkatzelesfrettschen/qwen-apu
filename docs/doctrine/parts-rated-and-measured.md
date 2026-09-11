# The parts, rated and measured

The doctrine in `AGENTS.md` states the rule and this file carries the mechanism, the measurements, and the evidence paths behind it in full.

The ceilings above are rates. This section states the parts those rates come
out of. Each row carries what a manufacturer, an SPD EEPROM, or a firmware
table rates the part at, beside what this tree measures or a live read
observes, and the source that makes the second column true.
`evidence/hardware/qwen-laptop-parts.md` retains the raw command outputs and
`evidence/hardware/qwen-laptop-parts.tsv` carries one row per rating.
`measured` names a retained evidence file, `observed` names a sysfs or tool
read taken from the appliance, and `derived` names arithmetic over those two
with its inputs stated. A rating without a reading is `not read` with the
reason, because a wattage recalled from a product page is not a source.

A firmware table is a rating and can be wrong: SMBIOS prints
`Configured Memory Speed: 2400 MT/s` for both DIMMs, above their own SPD
profile and above the rate the UMC registers train at.

# Processor

| Property | Rated | Measured or observed | Evidence |
| --- | --- | --- | --- |
| Model | AMD Athlon Silver 3050U with Radeon Graphics, socket FP5 | the same string from both sources | observed, `dmidecode -t processor`, `lscpu` |
| Microarchitecture | Zen+, family 23, model 24, stepping 1 | the same signature | observed, `lscpu` |
| Cores and threads | 2 cores, 2 threads | 1 thread per core, SMT disabled | observed, `lscpu` |
| Base clock | 2300 MHz | the cpufreq table tops out at 2300000 kHz | observed, `dmidecode` Current Speed, `cpuinfo_max_freq` |
| Boost clock | 3200 MHz | 3169.362 and 2554.754 MHz on the two cores in one read, both above the cpufreq ceiling | observed, `dmidecode` Max Speed, `/proc/cpuinfo` |
| cpufreq range | -- | 1400000 to 2300000 kHz, boost enabled, scaling MHz 135% | observed, `cpuinfo_min_freq`, `cpuinfo_max_freq`, `lscpu` |
| Governor | -- | `acpi-cpufreq` with `schedutil` | observed, `scaling_driver`, `scaling_governor` |
| L1 | -- | 64 KiB L1d and 128 KiB L1i over two instances | observed, `lscpu` |
| L2 | -- | 1 MiB over two instances, 512 KiB per core | observed, `lscpu` |
| L3 | -- | 4 MiB, one instance | observed, `lscpu` |
| Vector ISA | -- | AVX2, FMA, F16C, SHA_NI | observed, `lscpu` Flags |
| TDP and cTDP | -- | not read | the powercap zones carry no `constraint_0_power_limit_uw`, amdgpu hwmon carries `power1_label` alone, and SMBIOS type 39 is absent |
| Host read bandwidth | -- | 7.97 GB/s on one thread, 15.44 GB/s on two | measured, `evidence/measurement-state-and-memory-clock.md` |

`acpi-cpufreq` enumerates the ACPI `_PSS` states and stops at 2300000 kHz, so
the boost clock reaches the core through the hardware's own CPB rather than
through a table entry, and `/proc/cpuinfo` reads it back from aperf/mperf.

# Graphics

| Property | Rated | Measured or observed | Evidence |
| --- | --- | --- | --- |
| Device | Raven2 iGPU, PCI `1002:15d8` rev `cd`, subsystem `103C:879E` | AMD Radeon Graphics (RADV RAVEN2) | observed, `lspci -nn`, `vulkaninfo --summary` |
| ISA target | gfx902 to the HSA runtime, gfx909 to LLVM | `gfx902:xnack+` is the target the runtime loads | rated, `hp14-raven2-gpu/docs/raven2-capability-decomposition.md` |
| Compute units | 3 present, 2 active, one fused off | `CU per SH 3`, `active_cu_number 2` | rated, the same document's geometry table |
| SIMDs | 4 SIMD16 per CU, 128 lanes | -- | rated, the same table |
| Wavefront | 64, fixed | `minSubgroupSize` equals `maxSubgroupSize` equals 64 | rated, the same document |
| Occupancy | 10 waves per SIMD, 2560 work-items per CU | -- | rated, the same table |
| LDS | 64 KiB per CU | `maxComputeSharedMemorySize` 65536 | rated, the same document |
| GPU caches | 16 KiB L1 per CU, 1 MiB L2 | -- | rated, the same table |
| FP32 FMA ceiling | 281.6 GFLOPS | -- | derived, 128 lanes x 2 flops x 1.1 GHz |
| Packed FP16 ceiling | 563.2 GFLOPS | -- | derived, the FP32 ceiling doubled by `v_pk_fma_f16` |
| FP64 rate | 1/16 rate, about 17.6 GFLOPS | -- | derived, the FP32 ceiling divided by 16 |
| Engine clock table | 200, 400, 1100 MHz | level 1 starred on an idle machine | observed, `pp_dpm_sclk` |
| Engine clock, idle | -- | 400 MHz | observed, hwmon `freq1_input` |
| Engine clock, delivered | 1100 MHz peak | 1100 MHz on 107 of 107 busy rows under `manual` | measured, `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T2002Z-fclk-level3/` |
| Fabric clock table | 0, 400, 933, 1067 MHz | level 2 starred on an idle machine | observed, `pp_dpm_mclk` |
| Fabric clock, delivered | 1067 MHz top step | 933 MHz on 137 of 145 rows and 1067 MHz on 8, under a level-3 `manual` write | measured, the same directory |
| Fabric clock, forced | -- | 400 MHz under `high` and `profile_peak` against 933 MHz under `auto` | measured, `.../dpm-authority/20260902T1822Z-actual/` |
| Fabric clock surface | -- | `pp_dpm_fclk` reads empty; the fabric table is the one `pp_dpm_mclk` prints | observed, both files |
| VRAM carve-out | 2048 MiB | 2147483648 bytes | observed, `mem_info_vram_total` |
| GTT | -- | 15723495424 bytes, 14.64 GiB | observed, `mem_info_gtt_total` |
| Integer dot product | `VK_KHR_shader_integer_dot_product` advertised | 0 of 30 accelerated bits, and the deployed server holds no `_q8_1` pipeline | measured, `evidence/tensor-type-execution-audit.md` |
| Cooperative matrix | -- | `VK_KHR_cooperative_matrix` absent on RADV RAVEN2 | rated, the capability decomposition |
| Global float atomic add | -- | false on buffers, true on LDS | rated, the capability decomposition |
| Driver | -- | Mesa 26.2.1 RADV, device apiVersion 1.4.354 | observed, `vulkaninfo --summary` |
| Achieved streaming | 34.13 GB/s memory peak | 8.11 GB/s on the 4B Q4_K_M and 10.41 GB/s on the 2B, four-block means | measured, `evidence/decode-bound-analysis.md` |

The engine clock has three values and they answer different questions: the
table states which steps exist, hwmon's `freq1_input` states what an idle
machine delivers, and the census runs state what a decode window holds. The
operating point every campaign runs at is named `manual-gfx1100-fclk933`:
`power_dpm_force_performance_level=manual` with `pp_dpm_sclk` at level 2 and
`pp_dpm_mclk` at level 2, which delivers 1100 MHz GFXCLK on every sample and
holds FCLK at 933 MHz as both hard minimum and soft maximum. It is the
highest commandable graphics state paired with the highest fabric state the
firmware honors as a hard minimum, and a maximum of neither clock table.

`high` and `profile_peak` are invalid for inference on this machine. Both
pin GFXCLK at 1100 MHz and drop delivered FCLK to 400 MHz, and the 2B
decodes at 6 to 7 tok/s under either against 9 to 9.6 under `manual` level
2 (`evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T1822Z-actual/`
and `20260902T1826Z-manual/`). `smu10_hwmgr.c` sends the hard-coded
`SMU10_UMD_PSTATE_PEAK_FCLK` of 1200 MHz for both, which the firmware answers
with its floor, so a generic performance-mode cleanup that reintroduces either
name reintroduces the 400 MHz fabric.

The clock record is bounded evidence rather than continuous observation. An
arm's `clock_invariant` counts every sample taken, `window_lost_fraction`
bounds the samples the sampler was held off for at 0.03, and the stall bound
refuses one gap on its own at 100 ms under `auto`, where a governor step can
hide inside it, and at 250 ms under a forced level, where the firmware holds
one state and the samples at both edges bracket the gap. A 2.5% lost fraction
satisfies coverage and leaves the throughput and GPU timestamps valid; it
licenses no statement that the clock held inside the unobserved intervals.

# Memory

| Property | Rated | Measured or observed | Evidence |
| --- | --- | --- | --- |
| Modules | 2 x 16 GiB Crucial CT16G4SFD8213.C16FAD SODIMM, dual-rank, 1.2 V | the same part number in both slots | observed, `dmidecode -t memory` |
| SPD profile | DDR4-2133, 15-15-15-36 | both EEPROMs CRC-valid at that profile | rated, `evidence/measurement-state-and-memory-clock.md` |
| Trained speed | 2133 MT/s | 2133.33 MT/s, both UMC `0x50200` reading `0x00000520` | measured, the same file |
| Trained timings | 15-15-15-36, tRP 15, tRC 51 | the same values from both channels at `0x50204` and `0x50208` | measured, the same file |
| Channels | 2 channels, 64 bits each | both populated as `P0 CHANNEL A` and `P0 CHANNEL B` | observed, `dmidecode -t memory` |
| Peak bandwidth | 34.13 GB/s | -- | derived, 2 x 8 bytes x 2133.33 MT/s |
| SMBIOS configured speed | 2133 MT/s by SPD | SMBIOS prints 2400 MT/s, above SPD and above the trained rate | observed, `dmidecode -t memory` against the UMC read |
| Installed capacity | 32 GB array maximum over 2 devices | 32 GiB installed | observed, `dmidecode -t memory` |
| Host-visible | -- | 30709952 kB, 29.29 GiB, after the 2048 MiB carve-out and firmware reserves | observed, `/proc/meminfo` |

# Platform

| Property | Rated | Measured or observed | Evidence |
| --- | --- | --- | --- |
| System | HP Laptop 14-dk1xxx, family `103C_5335KV HP Notebook` | the same strings | observed, `dmidecode -t system` |
| Board | HP 879E, version 84.53 | the same strings | observed, `dmidecode -t baseboard` |
| Firmware | AMI F.69 dated 2023-04-17, BIOS revision 15.69, firmware revision 84.53, 16 MB ROM | the same strings | observed, `dmidecode -t bios` |
| Kernel | -- | 7.0.0-29-generic x86_64 | observed, `uname -r` |
| Battery capacity | 3355000 uAh design at an 11.34 V minimum design voltage | `charge_full` equals `charge_full_design` | observed, `/sys/class/power_supply/BAT0` |
| Battery energy | 38.0 Wh | -- | derived, 3.355 Ah x 11.34 V |
| Adapter | -- | not read | SMBIOS type 39 is absent and `/sys/class/power_supply/AC` exposes `type` alone |
| Package power | -- | not read | amdgpu hwmon carries `power1_label PPT` with no `power1_average` or `power1_cap`, and the powercap zones carry no constraint limit |
| Thermal sensors | -- | four carry a temperature: `k10temp` Tctl, `amdgpu` edge, `acpitz`, and `nvme`; `hp` carries `pwm1_enable` and `BAT0` carries current and voltage | observed, `/sys/class/hwmon/*/name` and each `temp*_input` |
| Sustained temperature | -- | Tctl at 87 C at the end of a five-minute two-core load; the `amdgpu` edge sensor peaks at 85 C across the `manual` arms | measured, `evidence/raven2-vulkan-kernel-census/dpm-authority/README.md`, experiments 2 and 4 |

The 1067 MHz fabric state is firmware-selected and not commandable as a
floor. `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T2048Z-fclk-rescind/`
writes hard minimums of 400, 933, and 1067 in turn: the firmware honors 400
and 933 exactly and answers the 1067 request with 933 on 279 of 282 samples,
while `auto` selects 1067 on its own for about half of one loaded arm. The
one fabric experiment left is a `manual` mask enabling levels 2 and 3
together (`echo "2 3" > pp_dpm_mclk`) with GFX pinned at 1100, run as a
production-policy arm rather than a calibration state: it asks whether the
firmware raises the fabric under this workload with the 933 floor kept, and a
promotion comparison stays at fixed 933 because a mixed 933/1067 arm pair
resolves nothing at the 1 to 4% an E4-class effect is worth. The SMU10
kernel patch that would replace the hard-coded 1200 is deprioritized by the
same refusal, since the firmware path it would reach has already declined a
1067 hard minimum. Whether DDR4-2400 modules would train faster is a
separate hardware hypothesis rather than a setting, since the Zen+ FP5
processor family rates DDR4-2400 while the installed Crucial parts are
DDR4-2133 by their own SPD and the UMC registers train them at exactly that;
the 1200 MHz the SMU requests is a fabric clock and states nothing about
what the installed DRAM can train to.

