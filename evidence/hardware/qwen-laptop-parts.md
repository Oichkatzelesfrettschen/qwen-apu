# The appliance's parts, rated against what this tree reads

`CLAUDE.md`, section "The parts, rated and measured", carries the tables this
file supplies the raw readings for, and
`evidence/hardware/qwen-laptop-parts.tsv` carries one row per rating in
machine-readable form. Every command below ran on the appliance as
`ssh qwen-laptop <command>`, except the two static sources named as files.

## Evidence classes

| class | what it means |
| --- | --- |
| `rated` | a manufacturer, SPD EEPROM, or firmware table states the value |
| `measured` | a retained evidence file in this tree carries the value from a run |
| `observed` | a live sysfs, dmidecode, or tool read taken for this document |
| `derived` | arithmetic over values of the classes above, with the inputs named |
| `not read` | the reading was attempted and the source states nothing, with the reason |

A `rated` value states what a part is sold or programmed to do; the firmware
table is one such source and is wrong at least once here, where SMBIOS reports
`Configured Memory Speed: 2400 MT/s` against both DIMMs' own DDR4-2133 SPD and
the UMC training registers
(`evidence/measurement-state-and-memory-clock.md`). A `derived` figure is
arithmetic and carries no measurement of its own: the 34.13 GB/s dual-channel
peak, the 281.6 GFLOPS FP32 ceiling, and the 38.0 Wh battery design energy are
all derived.

Serial numbers, the system UUID, and the host name are replaced with
`<serial>`, `<uuid>`, and `qwen-laptop`. The Vulkan `deviceUUID` and
`driverUUID` are retained verbatim, since RADV derives them from the PCI
identity and the driver name rather than from the machine.

## Firmware, system, board, processor, and memory devices

`sudo -n dmidecode -t processor -t memory -t system -t baseboard -t bios`

```text
# dmidecode 3.5
Getting SMBIOS data from sysfs.
SMBIOS 3.2.0 present.

Handle 0x0000, DMI type 0, 26 bytes
BIOS Information
	Vendor: AMI
	Version: F.69
	Release Date: 04/17/2023
	Address: 0xF0000
	Runtime Size: 64 kB
	ROM Size: 16 MB
	Characteristics:
		PCI is supported
		BIOS is upgradeable
		BIOS shadowing is allowed
		Boot from CD is supported
		Selectable boot is supported
		EDD is supported
		5.25"/1.2 MB floppy services are supported (int 13h)
		3.5"/720 kB floppy services are supported (int 13h)
		3.5"/2.88 MB floppy services are supported (int 13h)
		Print screen service is supported (int 5h)
		8042 keyboard services are supported (int 9h)
		Serial services are supported (int 14h)
		Printer services are supported (int 17h)
		ACPI is supported
		USB legacy is supported
		Smart battery is supported
		BIOS boot specification is supported
		Function key-initiated network boot is supported
		Targeted content distribution is supported
		UEFI is supported
	BIOS Revision: 15.69
	Firmware Revision: 84.53

Handle 0x0001, DMI type 1, 27 bytes
System Information
	Manufacturer: HP
	Product Name: HP Laptop 14-dk1xxx
	Version:
	Serial Number: <serial>
	UUID: <uuid>
	Wake-up Type: Power Switch
	SKU Number: 340V7UA#ABA
	Family: 103C_5335KV HP Notebook

Handle 0x0002, DMI type 2, 15 bytes
Base Board Information
	Manufacturer: HP
	Product Name: 879E
	Version: 84.53
	Serial Number: <serial>
	Asset Tag: Base Board Asset Tag
	Features:
		Board is a hosting board
		Board is replaceable
	Location In Chassis: Base Board Chassis Location
	Chassis Handle: 0x0003
	Type: Motherboard
	Contained Object Handles: 0

Handle 0x0006, DMI type 32, 20 bytes
System Boot Information
	Status: No errors detected

Handle 0x0007, DMI type 41, 11 bytes
Onboard Device
	Reference Designation:  Onboard IGD
	Type: Video
	Status: Enabled
	Type Instance: 1
	Bus Address: 0000:04:00.0

Handle 0x0009, DMI type 16, 23 bytes
Physical Memory Array
	Location: System Board Or Motherboard
	Use: System Memory
	Error Correction Type: None
	Maximum Capacity: 32 GB
	Error Information Handle: 0x0008
	Number Of Devices: 2

Handle 0x000E, DMI type 4, 48 bytes
Processor Information
	Socket Designation: FP5
	Type: Central Processor
	Family: Zen
	Manufacturer: Advanced Micro Devices, Inc.
	ID: 81 0F 81 00 FF FB 8B 17
	Signature: Family 23, Model 24, Stepping 1
	Flags:
		FPU (Floating-point unit on-chip)
		VME (Virtual mode extension)
		DE (Debugging extension)
		PSE (Page size extension)
		TSC (Time stamp counter)
		MSR (Model specific registers)
		PAE (Physical address extension)
		MCE (Machine check exception)
		CX8 (CMPXCHG8 instruction supported)
		APIC (On-chip APIC hardware supported)
		SEP (Fast system call)
		MTRR (Memory type range registers)
		PGE (Page global enable)
		MCA (Machine check architecture)
		CMOV (Conditional move instruction supported)
		PAT (Page attribute table)
		PSE-36 (36-bit page size extension)
		CLFSH (CLFLUSH instruction supported)
		MMX (MMX technology supported)
		FXSR (FXSAVE and FXSTOR instructions supported)
		SSE (Streaming SIMD extensions)
		SSE2 (Streaming SIMD extensions 2)
		HTT (Multi-threading)
	Version: AMD Athlon Silver 3050U with Radeon Graphics
	Voltage: 1.2 V
	External Clock: 100 MHz
	Max Speed: 3200 MHz
	Current Speed: 2300 MHz
	Status: Populated, Enabled
	Upgrade: None
	L1 Cache Handle: 0x000B
	L2 Cache Handle: 0x000C
	L3 Cache Handle: 0x000D
	Serial Number: Unknown
	Asset Tag: Unknown
	Part Number: Unknown
	Core Count: 2
	Core Enabled: 2
	Thread Count: 2
	Characteristics:
		64-bit capable
		Multi-Core
		Hardware Thread
		Execute Protection
		Enhanced Virtualization
		Power/Performance Control

Handle 0x0010, DMI type 17, 40 bytes
Memory Device
	Array Handle: 0x0009
	Error Information Handle: 0x000F
	Total Width: 64 bits
	Data Width: 64 bits
	Size: 16 GB
	Form Factor: SODIMM
	Set: None
	Locator: Bottom - Slot 1 (left)
	Bank Locator: P0 CHANNEL A
	Type: DDR4
	Type Detail: Synchronous Unbuffered (Unregistered)
	Speed: 2133 MT/s
	Manufacturer: Unknown
	Serial Number: <serial>
	Asset Tag: Not Specified
	Part Number: CT16G4SFD8213.C16FAD
	Rank: 2
	Configured Memory Speed: 2400 MT/s
	Minimum Voltage: 1.2 V
	Maximum Voltage: 1.2 V
	Configured Voltage: 1.2 V

Handle 0x0013, DMI type 17, 40 bytes
Memory Device
	Array Handle: 0x0009
	Error Information Handle: 0x0012
	Total Width: 64 bits
	Data Width: 64 bits
	Size: 16 GB
	Form Factor: SODIMM
	Set: None
	Locator: Bottom - Slot 2 (right)
	Bank Locator: P0 CHANNEL B
	Type: DDR4
	Type Detail: Synchronous Unbuffered (Unregistered)
	Speed: 2133 MT/s
	Manufacturer: Unknown
	Serial Number: <serial>
	Asset Tag: Not Specified
	Part Number: CT16G4SFD8213.C16FAD
	Rank: 2
	Configured Memory Speed: 2400 MT/s
	Minimum Voltage: 1.2 V
	Maximum Voltage: 1.2 V
	Configured Voltage: 1.2 V

Handle 0x0027, DMI type 41, 11 bytes
Onboard Device
	Reference Designation: Realtek PCIe FE Family Controller
	Type: Ethernet
	Status: Enabled
	Type Instance: 1
	Bus Address: 0000:02:00.0

Handle 0x002A, DMI type 13, 22 bytes
BIOS Language Information
	Language Description Format: Long
	Installable Languages: 5
		en|US|iso8859-1
		fr|FR|iso8859-1
		es|ES|iso8859-1
		zh|TW|unicode
		zh|CN|unicode
	Currently Installed Language: en|US|iso8859-1
```

`sudo -n dmidecode -t 39` returns the SMBIOS preamble and no type 39 structure,
so the power supply this system ships with states no wattage here.

## Processor, live

`lscpu`

```text
Architecture:                            x86_64
CPU op-mode(s):                          32-bit, 64-bit
Address sizes:                           43 bits physical, 48 bits virtual
Byte Order:                              Little Endian
CPU(s):                                  2
On-line CPU(s) list:                     0,1
Vendor ID:                               AuthenticAMD
Model name:                              AMD Athlon Silver 3050U with Radeon Graphics
CPU family:                              23
Model:                                   24
Thread(s) per core:                      1
Core(s) per socket:                      2
Socket(s):                               1
Stepping:                                1
Frequency boost:                         enabled
CPU(s) scaling MHz:                      135%
CPU max MHz:                             2300.0000
CPU min MHz:                             1400.0000
BogoMIPS:                                4591.40
Flags:                                   fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ht syscall nx mmxext fxsr_opt pdpe1gb rdtscp lm constant_tsc rep_good nopl nonstop_tsc cpuid extd_apicid aperfmperf rapl pni pclmulqdq monitor ssse3 fma cx16 sse4_1 sse4_2 movbe popcnt aes xsave avx f16c rdrand lahf_lm cmp_legacy svm extapic cr8_legacy abm sse4a misalignsse 3dnowprefetch osvw skinit wdt tce topoext perfctr_core perfctr_nb bpext perfctr_llc mwaitx cpb hw_pstate ssbd ibpb vmmcall fsgsbase bmi1 avx2 smep bmi2 rdseed adx smap clflushopt sha_ni xsaveopt xsavec xgetbv1 clzero xsaveerptr arat npt lbrv svm_lock nrip_save tsc_scale vmcb_clean flushbyasid decodeassists pausefilter pfthreshold avic v_vmsave_vmload vgif overflow_recov succor smca sev sev_es
Virtualization:                          AMD-V
L1d cache:                               64 KiB (2 instances)
L1i cache:                               128 KiB (2 instances)
L2 cache:                                1 MiB (2 instances)
L3 cache:                                4 MiB (1 instance)
NUMA node(s):                            1
NUMA node0 CPU(s):                       0,1
Vulnerability Gather data sampling:      Not affected
Vulnerability Ghostwrite:                Not affected
Vulnerability Indirect target selection: Not affected
Vulnerability Itlb multihit:             Not affected
Vulnerability L1tf:                      Not affected
Vulnerability Mds:                       Not affected
Vulnerability Meltdown:                  Not affected
Vulnerability Mmio stale data:           Not affected
Vulnerability Old microcode:             Not affected
Vulnerability Reg file data sampling:    Not affected
Vulnerability Retbleed:                  Mitigation; untrained return thunk; SMT disabled
Vulnerability Spec rstack overflow:      Mitigation; SMT disabled
Vulnerability Spec store bypass:         Mitigation; Speculative Store Bypass disabled via prctl
Vulnerability Spectre v1:                Mitigation; usercopy/swapgs barriers and __user pointer sanitization
Vulnerability Spectre v2:                Mitigation; Retpolines; IBPB conditional; STIBP disabled; RSB filling; PBRSB-eIBRS Not affected; BHI Not affected
Vulnerability Srbds:                     Not affected
Vulnerability Tsa:                       Not affected
Vulnerability Tsx async abort:           Not affected
Vulnerability Vmscape:                   Mitigation; IBPB before exit to userspace
```

`head -n 30 /proc/cpuinfo`, the model and clock lines, and both cores' current
frequency:

```text
cpu family	: 23
model		: 24
model name	: AMD Athlon Silver 3050U with Radeon Graphics
stepping	: 1
cpu MHz		: 3138.508
cache size	: 512 KB
siblings	: 2
cpu cores	: 2
cpu MHz		: 3169.362
cpu MHz		: 2554.754
```

The block above carries core 0's `cpu MHz` from the `head -n 30` read and
then both cores from one later read. That later pair, 3169.362 and 2554.754
MHz, sits above the 2300000 kHz that `cpuinfo_max_freq` reports, which is the
boost the ACPI `_PSS` table does not enumerate. `lscpu` states the same relation as
`Frequency boost: enabled` with `CPU(s) scaling MHz: 135%`.

`cat /sys/devices/system/cpu/cpu0/cpufreq/{cpuinfo_min_freq,cpuinfo_max_freq,scaling_driver,scaling_governor,scaling_min_freq,scaling_max_freq}`

```text
cpuinfo_min_freq: 1400000
cpuinfo_max_freq: 2300000
scaling_driver: acpi-cpufreq
scaling_governor: schedutil
scaling_min_freq: 1400000
scaling_max_freq: 2300000
```

## Package power

The package power limit is `not read`. Three sources were tried and each states
nothing:

```text
intel-rapl
intel-rapl:0
intel-rapl:0:0
-- /sys/class/powercap/intel-rapl/
-- /sys/class/powercap/intel-rapl:0/
name: package-0
-- /sys/class/powercap/intel-rapl:0:0/
name: core
== amdgpu power
power1_label: PPT
```

`/sys/class/powercap/` carries `intel-rapl` zones named `package-0` and `core`
holding neither a `constraint_0_power_limit_uw` nor an `energy_uj`, the amdgpu
hwmon node carries `power1_label: PPT` with no `power1_average` and no
`power1_cap`, and SMBIOS type 39 is absent. A TDP or cTDP figure for this part
therefore has no source on this machine or in this tree.

## Graphics device

`lspci -nn`, the host bridges and the display function:

```text
00:00.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Raven/Raven2 Root Complex [1022:15d0]
00:01.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-1fh) PCIe Dummy Host Bridge [1022:1452]
00:08.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-1fh) PCIe Dummy Host Bridge [1022:1452]
00:18.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Raven/Raven2 Device 24: Function 0 [1022:15e8]
00:18.1 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Raven/Raven2 Device 24: Function 1 [1022:15e9]
00:18.2 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Raven/Raven2 Device 24: Function 2 [1022:15ea]
00:18.3 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Raven/Raven2 Device 24: Function 3 [1022:15eb]
00:18.4 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Raven/Raven2 Device 24: Function 4 [1022:15ec]
00:18.5 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Raven/Raven2 Device 24: Function 5 [1022:15ed]
00:18.6 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Raven/Raven2 Device 24: Function 6 [1022:15ee]
00:18.7 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Raven/Raven2 Device 24: Function 7 [1022:15ef]
04:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Picasso/Raven 2 [Radeon Vega Series / Radeon Vega Mobile Series] [1002:15d8] (rev cd)
04:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Raven/Raven2/Fenghuang HDMI/DP Audio Controller [1002:15de]
04:00.5 Multimedia controller [0480]: Advanced Micro Devices, Inc. [AMD] ACP/ACP3X/ACP6x Audio Coprocessor [1022:15e2]
04:00.6 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Family 17h/19h HD Audio Controller [1022:15e3]
```

`cat /sys/class/drm/card1/device/{pp_dpm_sclk,pp_dpm_mclk,pp_dpm_fclk,power_dpm_force_performance_level,gpu_busy_percent,mem_info_vram_total,mem_info_gtt_total,mem_info_vram_used}`,
read on an idle machine:

```text
== pp_dpm_sclk
0: 200Mhz
1: 400Mhz *
2: 1100Mhz
== pp_dpm_mclk
0: 0Mhz
1: 400Mhz
2: 933Mhz *
3: 1067Mhz
== pp_dpm_fclk

== pp_dpm_socclk

== power_dpm_force_performance_level
auto
== gpu_busy_percent
0
== mem_info_vram_total
2147483648
== mem_info_gtt_total
15723495424
== mem_info_vram_used
492339200
```

`pp_dpm_fclk` reads empty. On this SMU10 path the fabric-clock table is the one
`pp_dpm_mclk` prints, since the driver obtains that value with
`PPSMC_MSG_GetFclkFrequency`
(`evidence/raven2-vulkan-kernel-census/dpm-authority/README.md`, naming
correction).

`sudo -n cat /sys/kernel/debug/dri/1/amdgpu_pm_info`, the clock and temperature
head of an idle read:

```text
GFX Clocks and Power:
	933 MHz (MCLK)
	1100 MHz (SCLK)
	700 MHz (PSTATE_SCLK)
	933 MHz (PSTATE_MCLK)

GPU Temperature: 75 C
GPU Load: 7 %

VCN: Powered down
```

`vulkaninfo --summary`, the device block:

```text
GPU0:
	apiVersion         = 1.4.354
	driverVersion      = 26.2.1
	vendorID           = 0x1002
	deviceID           = 0x15d8
	deviceType         = PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU
	deviceName         = AMD Radeon Graphics (RADV RAVEN2)
	driverID           = DRIVER_ID_MESA_RADV
	driverName         = radv
	driverInfo         = Mesa 26.2.1+git2608201115.88947685514~n~mesarc0
	conformanceVersion = 1.4.5.3
	deviceUUID         = 00000000-0400-0000-0000-000000000000
	driverUUID         = 414d442d-4d45-5341-2d44-525600000000
```

`glxinfo -B` returns `Error: unable to open display`, since the appliance runs
without a session on its panel.

## Sensors

`ls /sys/class/hwmon/*/name` and the temperature nodes each labelled sensor
carries, on an idle machine:

```text
/sys/class/hwmon/hwmon0: AC
/sys/class/hwmon/hwmon1: acpitz  temp1_input=73000  temp2_input=0
/sys/class/hwmon/hwmon2: BAT0
/sys/class/hwmon/hwmon3: nvme  temp1_input=46850  temp2_input=46850  temp3_input=52850
/sys/class/hwmon/hwmon4: k10temp  temp1_input=76375
/sys/class/hwmon/hwmon5: hp
/sys/class/hwmon/hwmon6: amdgpu  temp1_input=76000
```

## Battery

`cat /sys/class/power_supply/*/...`, the fields each supply exposes:

```text
-- /sys/class/power_supply/AC
type: Mains
-- /sys/class/power_supply/BAT0
type: Battery
model_name: Primary
manufacturer: Hewlett-Packard
voltage_min_design: 11340000
status: Full
capacity: 100
charge_full_design: 3355000
charge_full: 3355000
current_now: 0
voltage_now: 12840000
```

`BAT0` reports charge rather than energy, so `energy_full_design` and
`energy_full` are absent and `charge_full_design` of 3355000 uAh with
`voltage_min_design` of 11340000 uV gives 38.0 Wh as a `derived` design
energy. `charge_full` equals `charge_full_design`, so the pack reports full
design capacity. `power_now` is absent and `current_now` reads 0 on a full
pack under mains, so no discharge power is read here.

## Installed memory

`grep MemTotal /proc/meminfo` and `free -g`:

```text
MemTotal:       30709952 kB

               total        used        free      shared  buff/cache   available
Mem:              29           9           6           0          14          19
```

30709952 kiB of MemTotal is 29.29 GiB against the 32 GiB the two SODIMMs
carry. The 2048 MiB VRAM carve-out that `mem_info_vram_total` reports accounts
for most of the difference and firmware reservations account for the rest;
that residual is `derived` and no reading here decomposes it.

## Kernel

`uname -r`

```text
7.0.0-29-generic
```

## Static sources

`hp14-raven2-gpu/docs/raven2-capability-decomposition.md` supplies the shader
geometry, the per-target instruction encoding table from `llvm-mc`, the Vulkan
and OpenCL capability queries, and the atomics and subgroup properties. Its
geometry table and the `amdgpu` register read behind it
(`SE 1, SH per SE 1, CU per SH 3, active_cu_number 2`) are the authority for
the two-of-three active compute units.

`evidence/measurement-state-and-memory-clock.md` supplies the UMC training
registers and the SPD comparison. `evidence/decode-bound-analysis.md` supplies
the achieved streaming rates. `evidence/tensor-type-execution-audit.md`
supplies the production type shares behind the unaccelerated integer dot
product.
`evidence/raven2-vulkan-kernel-census/decode-decomposition.md` restates the
geometry inside the census and supplies the per-token bracket.
`evidence/raven2-vulkan-kernel-census/dpm-authority/` supplies the delivered
graphics and fabric clocks under each `power_dpm_force_performance_level`
setting.
