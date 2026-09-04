# The Raven2 power envelope: CPU boost, the SMU adjusters, and the graphics clock ceiling

This document answers three questions about the appliance's AMD Athlon Silver
3050U and registers the device campaign that would move its package budget.
Every claim carries an evidence class. `documented` names a primary source that
states it, `observed` names a reading taken from the machine or a data file,
and `conjecture` names an inference with the falsifier that would settle it. The
appliance readings were taken read-only over SSH on 2026-09-03 while another
agent's campaign held the device; nothing here was written to the machine.

The hardware is `HP Laptop 14-dk1xxx`, board `879E`, AMI firmware `F.69` dated
2023-04-17, kernel 7.0.0-29-generic (observed, `/sys/class/dmi/id/*` and
`uname -r`).

## The short answers

Boost is enabled and delivers the rated 3.2 GHz on both cores at once. The
sysfs `cpufreq/boost` switch reads 1, CPUID advertises `cpb`, and twenty
delivered-frequency samples on a loaded machine peaked at 3.194 GHz against an
ACPI P0 of 2.3 GHz. AMD publishes 3.2 GHz as the part's maximum boost; the 3.4
GHz figure belongs to no AMD specification for this model.

Three of the twenty-five SMU adjusters RyzenAdj offers this part raise the
package power: `stapm-limit`, `fast-limit`, and `slow-limit`. The current
limits permit a raised budget to be reached rather than adding to it, the clock
limits redistribute inside it, the two time constants reshape when it binds,
and the thermal limit moves a different ceiling in a different risk class.

The graphics core reaches 1100 MHz and no path in this tree reaches 1.4 GHz.
The 1100 MHz figure is not a driver constant, not a VBIOS table entry, and not a
sysfs artifact: `smu10_hwmgr.c` obtains both `OD_RANGE` bounds by asking the SMU
firmware itself on every read, and it clamps an overdrive write against the
same reply, so the number the appliance prints is the firmware's own answer and
the driver refuses anything above it.

## Boost: enabled, and 3.2 GHz rather than 3.4

AMD publishes base 2.3 GHz, max boost 3.2 GHz, default TDP 15 W, and a
configurable TDP range of 12 to 25 W for the Athlon Silver 3050U (documented;
the live product URL now answers 404 and the figures come from the Wayback
capture of that same AMD page named in Sources). The operator's belief of 3.4
GHz matches no field on that page, and the aggregators that repeat AMD's numbers
repeat 3.2.

The kernel drives the part through `acpi-cpufreq` under the `schedutil`
governor, and the ACPI `_PSS` table it exposes carries three states: 2300000,
1700000, and 1400000 kHz, with `cpuinfo_max_freq` at 2300000 (observed,
`/sys/devices/system/cpu/cpu0/cpufreq/*`). Core Performance Boost is a hardware
state above P0 that the ACPI table does not enumerate, so any delivered
frequency above 2.3 GHz is itself the proof that boost is engaging.
`/sys/devices/system/cpu/cpufreq/boost` reads 1 and `/proc/cpuinfo` lists the
`cpb` flag (observed).

Twenty samples of `scaling_cur_freq` on both cores at 0.25 s spacing, under
load average 2.65 with an image runtime at 60% and a QEMU guest at 40% of the
two cores, read 3.15 to 3.19 GHz on seventeen of twenty pairs and peaked at
3.194 GHz (observed). `acpi-cpufreq` derives that file from the APERF and MPERF
counters rather than from the requested P-state, so it reports what the core
delivered. Tctl read 83.4 C during that window and the amdgpu edge sensor read
81 C, so the 3.2 GHz all-core boost holds well into the thermal range the
machine already runs at.

One reading disagrees and stays unexplained: `cpupower frequency-info` printed
`boost state support: Supported: no / Active: no` in the same unprivileged
session that read `boost=1` (observed). `cpupower` obtains that line from an
MSR rather than from sysfs, and this invocation held no MSR access, which is the
obvious candidate and is untested here. Falsifier: a `cpupower frequency-info`
run with the credential, in a device window.

A naming conflict is open and does not change any number above. This
repository's doctrine calls the two cores Zen+; the RyzenAdj wiki and the
third-party aggregators classify the 3050U's Dali silicon as Zen, with Picasso
as the Zen+ Raven derivative (reported). AMD's own product page states neither
codename nor microarchitecture generation (documented by absence). The
distinction would matter only if a tuning expectation were transferred from
Picasso's row of the RyzenAdj support table to this part's, which nothing here
does.

## The SMU adjusters this part accepts

RyzenAdj selects `FAM_DALI` for CPUID family 0x17 model 32 (`lib/cpuid.c`,
`case 32: return FAM_DALI;`, documented), and this part reports model 24
(`lscpu`, observed), which the same table routes to `FAM_PICASSO`: the built
binary prints `CPU Family: Picasso` on the appliance (`baseline-info.txt`,
observed). Both families share the message table below. Every adjuster below
reaches the MP1 mailbox at message address `0x3B10528` with its response at
`0x3B10564` and its argument base at `0x3B10998` (`lib/nb_smu_ops.c`,
documented). `_do_adjust` maps the mailbox reply onto three outcomes:
`PPSMC_Result_OK` becomes success, `PPSMC_Result_UnknownCmd` becomes
`ADJ_ERR_SMU_UNSUPPORTED`, and anything else becomes `ADJ_ERR_SMU_REJECTED`
(documented, `lib/api.c`), so a message this firmware does not implement is a
distinguishable failure rather than a silent one.

The write units are milliwatts, milliamperes, seconds, degrees Celsius, and
megahertz; `--info` prints the same quantities from the power-metrics table in
watts and amperes at `%9.3lf` (documented, `README.md` and `main.c`). The two
directions differ by a factor of a thousand, which
`remote/power-envelope.sh` carries as a per-field scale.

| Adjuster | MP1 message | Write unit | Mechanism | Raises package power |
| --- | ---: | --- | --- | --- |
| `stapm-limit` | 0x1a | mW | the third and slowest power tier, the sustained budget the platform holds a long workload to | yes |
| `fast-limit` | 0x1b | mW | PPT fast, the instantaneous package power limit | yes |
| `slow-limit` | 0x1c | mW | PPT slow, the averaged package power limit | yes |
| `slow-time` | 0x1d | s | the time constant the slow average is computed over | reshapes when the budget binds |
| `stapm-time` | 0x1e | s | the STAPM time constant | reshapes when the budget binds |
| `tctl-temp` | 0x1f | degree C | the core temperature limit | moves a different ceiling |
| `vrm-current` | 0x20 | mA | TDC VDD, the sustained current the core rail may draw | permits a raised budget to be reached |
| `vrmsoc-current` | 0x21 | mA | TDC SoC, the same for the SoC rail | permits |
| `vrmmax-current` | 0x22 | mA | EDC VDD, the peak current the core rail may draw | permits |
| `vrmsocmax-current` | 0x23 | mA | EDC SoC | permits |
| `psi0-current` | 0x24 | mA | the VDD current below which the regulator enters its low-power state | undetermined by the project itself |
| `psi0soc-current` | 0x25 | mA | the same for the SoC rail | undetermined |
| `prochot-deassertion-ramp` | 0x26 | ramp value | how tightly power is limited after PROCHOT clears | restricts after a thermal event |
| `max-gfxclk` | 0x46 | MHz | the graphics soft maximum | redistributes inside the budget |
| `min-gfxclk` | 0x47 | MHz | the graphics hard minimum | redistributes |
| `max-socclk-frequency` | 0x48 | MHz | the SoC clock maximum | redistributes |
| `min-socclk-frequency` | 0x49 | MHz | the SoC clock minimum | redistributes |
| `max-fclk-frequency` | 0x4A | MHz | the fabric clock maximum | redistributes |
| `min-fclk-frequency` | 0x4B | MHz | the fabric clock minimum | redistributes |
| `max-vcn` / `min-vcn` | 0x4C / 0x4D | MHz | the video core bounds | redistributes |
| `max-lclk` / `min-lclk` | 0x4E / 0x4F | MHz | the link clock bounds | redistributes |
| `power-saving` | 0x19 | mode | selects the SMU's power-saving policy | lowers |
| `max-performance` | 0x18 | mode | selects the SMU's maximum-performance policy | selects a policy |

The message IDs and the family routing are documented in `lib/api.c` at the
revision `remote/build-ryzenadj.sh` pins. `FAM_DALI` accepts no
`apu-skin-temp`, `dgpu-skin-temp`, `apu-slow-limit`, `skin-temp-limit`,
`gfx-clk`, or curve-optimizer adjuster, each of which the source restricts to
`FAM_RENOIR` and later or to `FAM_VANGOGH` (documented). `--info` still prints
the rows those adjusters read, so a `PPT LIMIT APU` line on this part carries
no number; `power-envelope.sh` treats a row that is not a decimal as absent for
that reason.

The three power tiers are ordered rather than independent: the project
documents the relation as fast limit above slow limit above STAPM limit, with
STAPM the tier a long workload settles onto (documented, RyzenAdj `Options.md`).
A campaign arm therefore raises all three together, because raising STAPM alone
leaves the two tiers above it as the binding constraint.

The current limits are the second half of a raised budget rather than a second
budget. TDC bounds the sustained current the VRM may supply and EDC bounds its
peaks (documented, `Options.md`), so raising PPT without headroom in those two
would move the binding constraint from power to current rather than raising the
delivered watts. The campaign below reads them and leaves them alone in its
first pass, because a package that never reaches its new PPT ceiling reports
that fact in its own `--info` values.

Two prohibitions belong to this table rather than to the campaign. The SMU on
this generation range-checks nothing: RyzenAdj documents a vendor-settable hard
value range as a Zen3 feature and scopes it there explicitly, and the
`ryzen_smu` author states the driver is used at the caller's own risk
(documented). The enforced backstop is thermal, not electrical: PROCHOT and the
Tctl limit are what stop the part, which is why `power-envelope.sh` reads
`THM LIMIT CORE`, refuses above its stated ceiling, and never writes
`tctl-temp`.

The platform re-asserts its own limits, and the project says so in its own FAQ:
a power-source change or an energy-mode change rewrites the vendor limits, and
"on some devices values get reset regularly after some time, even without power
mode change" (documented). A user report against a Raven-class device confirms
the symptom and the workaround the ecosystem adopted, which is periodic
re-application (reported, RyzenAdj issue 16). The campaign therefore reads
`--info` at both ends of every arm and treats a start-to-end difference as
platform re-assertion rather than as a measurement. The remedy the project's
maintainer suggests for it is a large `stapm-time`, and
`remote/power-envelope.sh` carries no field for that adjuster, so an arm that
detects re-assertion reports it and ends rather than answering it; adding
`stapm-time` to the field table is the registered response if an arm does.

### Two message tables disagree, and the return code settles it

RyzenAdj sends `stapm-limit` as MP1 message `0x1a` and `max-gfxclk` as `0x46`.
The kernel's own Raven message header assigns `0x1A` to
`PPSMC_MSG_SetDriverDramAddrHigh` and declares `PPSMC_Message_Count` as `0x42`,
above which `0x46` and `0x47` do not appear at all (documented,
`drivers/gpu/drm/amd/pm/powerplay/inc/rv_ppsmc.h`). Both writers address MP1, so
the two numberings cannot both describe this firmware's message set. The
resolution is unmeasured here: the kernel header enumerates the messages the
powerplay driver sends rather than the messages the firmware implements, and
RyzenAdj's Dali rows are marked untested by its own support table. Class:
conjecture. Falsifier: one `ryzenadj --stapm-limit=` invocation on the
appliance, whose exit status separates `ADJ_ERR_SMU_UNSUPPORTED` from a
rejection from success, with `--info` read before and after.

## The graphics clock ceiling: 1100 MHz is the firmware's own answer

The appliance prints two surfaces and they agree (observed,
`/sys/class/drm/card1/device/`):

```text
pp_dpm_sclk        0: 200Mhz    1: 400Mhz *    2: 1100Mhz
pp_od_clk_voltage  OD_SCLK  0: 200Mhz  1: 1100Mhz
                   OD_RANGE SCLK  200MHz  1100MHz
```

`OD_RANGE` is a firmware query rather than a table lookup.
`smu10_emit_clock_levels` issues `PPSMC_MSG_GetMinGfxclkFrequency` (0x2C) and
`PPSMC_MSG_GetMaxGfxclkFrequency` (0x2D) on every read of that file and prints
the two replies (documented). The literal 200 appears nowhere in
`smu10_hwmgr.c`, and no `SMU10_UMD_PSTATE_PEAK_GFXCLK` constant exists: the
`HIGH` and `PROFILE_PEAK` levels drive the graphics clock from
`gfx_max_freq_limit`, which `smu10_hwmgr_backend_init` fills from that same
`GetMaxGfxclkFrequency` reply (documented). So the 1100 the appliance reports is
what the SMU firmware answers when asked for its maximum graphics frequency.

The overdrive write path exists and clamps against the same reply.
`smu10_hwmgr_funcs` registers no `odn_edit_dpm_table` hook and instead registers
`set_fine_grain_clk_vol`, which requires `power_dpm_force_performance_level` to
be `manual`, rejects a `PP_OD_EDIT_SCLK_VDDC_TABLE` maximum above a fresh
`GetMaxGfxclkFrequency`, and commits the staged pair with
`PPSMC_MSG_SetHardMinGfxClk` and `PPSMC_MSG_SetSoftMaxGfxClk` (documented). A
write of 1400 to `pp_od_clk_voltage` is therefore refused by the driver before
any message reaches the firmware.

Two premises in the question are wrong and the correction matters. First, the
`0xfff7bfff` feature mask is amdgpu's own default rather than an operator
setting: `/proc/cmdline` carries no `amdgpu` parameter at all and
`/etc/modprobe.d` names none (observed). Second, that mask does clear
`PP_OVERDRIVE_MASK` (0x4000, documented in `amd_shared.h`) and clearing it
changes nothing on this driver: `hwmgr_set_user_specify_caps` sets
`od_enabled` from the feature mask during `early_init`, and
`smu10_hwmgr_backend_init` then sets `hwmgr->od_enabled = 1` unconditionally
during `hw_init`, which runs after it (documented). That unconditional
assignment is why `pp_od_clk_voltage` prints on this machine at all. Overdrive
is not masked here; it is enabled and bounded by the firmware's own reply.

The VBIOS carries no ceiling to raise and no voltage curve to edit. The
decomposed image for this exact board -- `raven2-vbios.rom`, 54272 bytes,
SHA-256 `6d73e8a862b98b7ab8711648d6f7c12df7686f56726347efb6e821e995bb202d`,
ATOM string `ATOMBIOSBK-AMD VER016.002.000.011.000000`, board `113-RAVEN2-117`,
PCI `1002:15d8` subsystem `103C:879E` -- declares a `powerplayinfo` table at
offset `0x9dc4` at revision 9.1 whose 1020 body bytes are all zero, and a
third-party PowerPlay editor refuses to decode it. `setengineclock` and
`setmemoryclock` are absent from its master command table, the image contains
zero PLL operands, and every voltage field in `firmwareinfo` reads 0. The only
populated clock fields are `bootup_sclk_in10khz` and `bootup_mclk_in10khz`, both
200 MHz, which are boot defaults rather than ceilings (observed, the
decomposition's own evidence tables; the parser is source-derived from the
kernel's `atomfirmware.h` and cross-checked against `atomdis` and `upp`).

One caution about that sibling repository: its capability document states a
"Peak engine clock | 1100 MHz" and computes a 281.6 GFLOPS ceiling from it, and
that line carries no authority citation and appears in no row of the repository's
own falsifier ledger. It is not an extraction from the VBIOS, which holds no such
value. Treat the 1100 MHz ceiling as established by the SMU query above, not by
that line. The 1200 and 1400 values that appear in the image are display
timing-descriptor fields for 1600x1200 and 1400x1050 modes (observed), not
clocks.

The RyzenAdj route reaches the same wall. `set_max_gfxclk_freq` sends MP1 `0x46`
for `FAM_RAVEN`, `FAM_PICASSO`, `FAM_DALI`, and `FAM_LUCIENNE` (documented).
The project's own support table grades that adjuster on Raven as accepted with
no measurable effect -- "command is accepted - no value change can be found or
measured on 2500U" -- and leaves every Dali row untested (documented). A user
setting a 1200 MHz maximum on a Raven Ridge part observed the iGPU still ranging
200 to 1100 MHz, unchanged from a 1100 setting (reported, RyzenAdj issue 80). No
primary or reported source describes a Raven-class mobile iGPU running above
1200 MHz through this mechanism; the reports above 1200 MHz are desktop Raven
Ridge parts overclocked through firmware or Ryzen Master, a different mechanism
on a different package.

This tree holds its own precedent for what the firmware does with an
out-of-table request. A manual `pp_dpm_mclk` hard minimum of 1067 MHz -- a value
the firmware's own table lists -- was accepted by the kernel and held at 933 by
the firmware, with 1067 observed in 2 of 107 samples and never commanded
(observed, `evidence/raven2-vulkan-kernel-census/dpm-authority/`). A 1400 MHz
graphics request is outside the table entirely, which is a strictly harder ask
than one this firmware already refused inside it.

The answer is therefore no along every path this tree has: the sysfs path is
refused by the driver's clamp, the VBIOS path has no table, and the SMU path is
graded as accepted-with-no-effect on the nearest tested family. Class for the
driver clamp and the firmware query: documented. Class for the SMU path on Dali
specifically: conjecture. Falsifier: `ryzenadj --max-gfxclk=1400` on the
appliance followed by `sample-gpu-clocks.sh` under a Vulkan load, where a
delivered `freq1_input` above 1100 MHz would refute this section.

## What the machine exposes read-only

The kernel offers no settable power cap on this part, which is why the campaign
needs an SMU writer at all (all observed):

| Surface | State |
| --- | --- |
| `/sys/class/powercap/intel-rapl:0/energy_uj` | present, package-0, mode 0400 root-only, `max_energy_range_uj` 65532610987 |
| `/sys/class/powercap/intel-rapl:0:0/energy_uj` | present, core domain, mode 0400 root-only |
| `/sys/class/powercap/intel-rapl:0/constraint_*` | absent, so the powercap driver exposes no writable limit |
| amdgpu hwmon `power1_label` | present, reads `PPT` |
| amdgpu hwmon `power1_average`, `power1_cap` | absent |
| amdgpu hwmon `in0_input` (vddgfx), `in1_input` (vddnb) | present as files, both answer `EOPNOTSUPP` |
| amdgpu hwmon `freq1_input` (sclk), `temp1_input` (edge) | present and readable |
| k10temp `temp1_input` | present, labelled `Tctl` |
| `pp_dpm_socclk`, `pp_dpm_fclk` | present and empty |
| `/sys/kernel/ryzen_smu_drv` | absent; `intel_rapl_msr` and `msr` are the loaded power-adjacent modules |
| `/dev/mem` | mode 0640 root:kmem, `CONFIG_STRICT_DEVMEM=y` with `CONFIG_IO_STRICT_DEVMEM` unset |

Package power is therefore measurable by differencing `energy_uj`, and that read
needs the same `sudo -n` credential the SMU writer needs, so one `sudo -v`
covers both the campaign's instrument and its treatment. RyzenAdj reaches the
SMU through PCI configuration space and the power-metrics table through
`/dev/mem`; with `CONFIG_IO_STRICT_DEVMEM` unset the MMIO mapping it needs is
permitted to root (documented kernel configuration, observed on this build).
`ryzen_smu` names both Raven Ridge 2 and Dali among its supported codenames and
would be the alternative backend, and RyzenAdj prefers it when present and falls
back to `/dev/mem` otherwise (documented); it is not installed here.

## The registered campaign

Status: `registered`. This section registers the design and its falsifiers ahead
of any measurement, which is what makes a deviation a finding. Every arm needs a
teardown window, a `sudo -v` credential, and the operator's authorization.
`remote/run-power-envelope-campaign.sh MODEL_ID CAMPAIGN_DIRECTORY` runs one
checkpoint's four arms and `remote/run-power-envelope-arm.sh` is the command each
`compute-state-lease.sh` transaction wraps.

### Subject and instrument

Fixed-64 served decode through `remote/measure-served-decode.sh` on the three
runtime classes in the order the class policy sets: `qwen38-2b-distill` first,
`qwen35-08b` second, `qwen38-4b-distill` third. Every arm runs inside one
`remote/compute-state-lease.sh` transaction, so the graphics clock, the fabric
clock, the memory scanner, the process priority, and the package budget are one
reversible state rather than five.

### Arms

| Arm | Lease profile | STAPM, PPT fast, PPT slow |
| --- | --- | --- |
| control | `measure-fixed-package-default` | the platform's own, written by nothing |
| candidate | `measure-fixed-package-20w` | 20000 mW |
| candidate | `measure-fixed-package-25w` | 25000 mW |

The package budget is machine-wide, so two campaigns cannot share it. The
snapshot path is claimed atomically by whichever transaction creates it, and a
restore acts on the owner token its own claim recorded, so a second campaign
starting mid-arm is refused rather than returning a budget the first is still
running under.

Arm order per checkpoint is control, candidate, candidate, control, which is the
mirrored order this tree reads a pair inside. The closing control's agreement
with the opening one is what licenses reading the two candidates as budget
effects rather than as position in a sequence; a closing control differing from
its opener by more than the sweep's own span criterion ends the sweep
unresolved.

The span criterion is named here ahead of the run, because choosing it after the
closing controls are read is the trap this document exists to avoid. A sweep
resolves where the two control arms of one checkpoint differ by 20% or less of
their mean, which is the single-arm span this tree already carries: a repeated
depth-0 rate on this machine spans about 4% under identical flags ten minutes
apart and 30.6% under desktop load, and the repository reads a difference below
about 20% quoted from single arms as queue position. A candidate arm is then
read as a budget effect only where its difference from the control mean exceeds
the same checkpoint's own observed control-to-control spread; below that spread
the direction is unresolved rather than null, and the package watts beside the
rate are what separate "no additional budget was drawn" from "the budget rose
and bought no throughput".

`tctl-temp` is held at whatever the platform set and is written by no arm.
`power-envelope.sh` reads `THM LIMIT CORE`, refuses the transaction above 95
degrees C, and records the reading on every apply, so an arm states the thermal
ceiling it ran under rather than assuming it.

### The platform baseline, read

AMD publishes 15 W as the part's default TDP and 12 to 25 W as its configurable
range (documented). `baseline-info.txt` retains the whole `--info` read taken
on the appliance through the pinned build at idle, over `/dev/mem` since no
`ryzen_smu` module is loaded. HP's F.69 firmware sets `STAPM LIMIT` 15 W,
`PPT LIMIT FAST` 25 W, `PPT LIMIT SLOW` 20 W, `TDC LIMIT VDD` 35 A,
`EDC LIMIT VDD` 45 A, `THM LIMIT CORE` 90 C, `StapmTimeConst` 200 s, and
`SlowPPTTimeConst` 5 s, with the APU slow limit and both skin-temperature
limits reading `nan` (observed). The 15 W conjecture held for STAPM, and the
sustained figure is the one a decode arm runs against: the slow limit already
sits at 20 W and the fast limit at 25 W, so the registered 20 W arm would
lower the fast limit by 5 W while raising STAPM by 5 W, and the 25 W arm
raises STAPM by 10 W and the slow limit by 5 W with the fast limit unchanged.
The candidate arms are therefore re-registered as STAPM and slow-limit moves
with the fast limit held at the platform's 25 W, so each arm moves the
sustained budget alone; the profile definitions in
`remote/compute-state-lease.sh` carry that change before the first candidate
runs. `intel-rapl:0/energy_uj` answers a privileged read on the appliance
(`package-0`, observed), which admits the differenced-energy instrument the
next section names.

### Retained per arm

Package watts from `intel-rapl:0/energy_uj` differenced across the request
window, and core watts from `intel-rapl:0:0` beside it.
`remote/read-package-energy.py` is that reader, and it runs under the same
`sudo -n` credential the SMU writer holds because `energy_uj` is mode 0400 while
`sample-clock-sidecar.py` and the telemetry broker sample readable files as
unprivileged nice-19 children.

Where the two boundary reads come from is a correction to this section, stated
before the first arm rather than after it. `measure-served-decode.sh` exposes no
request-boundary hook: it stamps `request-window.tsv` with `time.monotonic_ns()`
immediately before curl and immediately after it returns, and it owns its own
launch and teardown, so a pair of reads around the runner would difference a 120
second model load together with a 7 second decode and report the load. The
reader therefore samples both domains inside one privileged process across the
arm at a 50 ms period, and its `window` mode selects the two boundary reads out
of that record afterwards. The reported figure is still two reads differenced
across the request window; the record is how those two reads are obtained
without a hook.

The window is bracketed twice for the same reason a delivered clock is read
rather than asserted. The inner bracket runs from the first sample at or after
the window's beginning to the last sample at or before its end, so its whole
interval lies inside the request and it is the arm's reading; the outer bracket
runs from the last sample at or before the beginning to the first sample at or
after the end, so the request lies inside it and it bounds the reading. The two
agree to the sampling period at each edge, which on the shortest window this
campaign runs is under 2% of it. Delivered graphics clock
from the amdgpu hwmon `freq1_input` and the starred `pp_dpm_mclk` fabric step,
sampled by `remote/sample-clock-sidecar.py` and validated by
`remote/validate-clock-sidecar.py`. Tctl from k10temp and the amdgpu edge
temperature. `--info` at arm start and arm end, whole. Graphics-service latency
from the guarded probe. The GPU bracket population where the arm runs an
instrumented build.

### What a pinned-clock arm can and cannot answer

The lease profiles pin `pp_dpm_sclk` at level 2 and prove the delivered clock
from the amdgpu hwmon before the command runs, and the firmware already reports
1100 MHz as its maximum, so a raised package budget has no higher graphics state
to select. The observable a package arm therefore carries is the delivered
clock's residency at 1100 MHz, the sustained package watts, and the host-side
boost residency that shares the same budget -- not a faster graphics core.
Retained census runs under this same pin held 1100 MHz on every sample, so the
pin currently costs the campaign nothing; an arm asking whether a raised budget
changes which DPM step the governor selects would run under `auto` instead and
is not registered here.

### Predictions, registered before the run

The thermal limit binds before the power limit. Tctl read 83.4 C at load
average 2.65 with the graphics core idling at 400 MHz, which leaves about 12
degrees to the 95 the platform states, and this tree's own decode sweeps already
retain arms at 88 C. The prediction is therefore that the 20 W and 25 W arms
deliver no additional sustained package watts, because the part is already
thermally rather than electrically bound. Retaining RAPL watts beside Tctl is
what separates that outcome from "the budget rose and bought no throughput",
which is a different finding with a different remedy.

Delivered graphics clock does not move. The lease pins `pp_dpm_sclk` level 2 and
the firmware reports 1100 MHz as its maximum, so a raised package budget has no
higher graphics state to select. A candidate arm delivering above 1100 MHz would
refute the whole preceding section.

CPU boost residency rises before decode does. The two cores already reach 3.19
GHz in bursts, and decode on this appliance is dominated by the Vulkan bracket,
so a package-budget gain that shows up at all shows up first as longer boost
residency on the host side of the token rather than as graphics time.

### Promotion gate

A budget arm becomes a serving default only where the paired gain holds across
every checkpoint that ran it, at the tree's existing all-pairs whole-model rule,
with the closing control agreeing with its opener, with no arm exceeding the
thermal ceiling it declared, and with the graphics-service latency probe
reporting no additional frame breach. A gain on one class alone becomes that
class's profile setting rather than a Raven2-wide default. A campaign that meets
its own null prediction is retained as the measurement that closes the package
budget as a lever, which is the outcome the readings above make likely.

## Sources

Primary sources, each fetched or read directly:

- AMD Athlon Silver 3050U product specifications, `https://www.amd.com/en/products/apu/amd-athlon-silver-3050u` (the live URL answers 404; figures read from the 2023-12-07 capture at `http://web.archive.org/web/20231207172044/https://www.amd.com/en/products/apu/amd-athlon-silver-3050u`)
- RyzenAdj, `https://github.com/FlyGoat/RyzenAdj`, revision `5775fc3e6dbb25c7030ee2d100a1bdd6e8bf2d0a`: `lib/cpuid.c`, `lib/api.c`, `lib/nb_smu_ops.c`, `main.c`, `README.md`
- RyzenAdj wiki, `https://github.com/FlyGoat/RyzenAdj/wiki/Supported-Models`, `https://github.com/FlyGoat/RyzenAdj/wiki/Options`, `https://github.com/FlyGoat/RyzenAdj/wiki/FAQ`, `https://github.com/FlyGoat/RyzenAdj/wiki/Renoir-Tuning-Guide`
- RyzenAdj issue 16, `https://github.com/FlyGoat/RyzenAdj/issues/16`, and issue 80, `https://github.com/FlyGoat/RyzenAdj/issues/80`
- `ryzen_smu`, `https://gitlab.com/leogx9r/ryzen_smu`
- Linux `drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.c`, `.../hwmgr/smu10_hwmgr.h`, `.../inc/rv_ppsmc.h`, `.../hwmgr/hwmgr.c`, and `drivers/gpu/drm/amd/include/amd_shared.h`, read at `torvalds/linux` master commit `841e384b841a3d89c50b4b2d6c5bb6abab1a7e39`, `https://github.com/torvalds/linux`
- The board's own decomposed VBIOS: the sibling `hp14-dk1xxx` repository's `raven2-vbios.rom`, its `master-data-tables.tsv`, `decoded-data-table-fields.tsv`, `vbios-atomfirmware-anti-patterns.md`, and `test_raven2_atomfirmware.py`

In-tree evidence this document rests on:

- `evidence/raven2-vulkan-kernel-census/dpm-authority/` for the fabric-clock refusal and the forced-level measurements
- `evidence/compute-state-lease/` for the transaction the campaign arms run inside
