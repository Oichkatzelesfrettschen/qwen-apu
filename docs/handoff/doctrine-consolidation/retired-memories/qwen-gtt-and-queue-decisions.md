---
name: qwen-gtt-and-queue-decisions
description: "20 GiB GTT is a conditional research boot rather than a queued step; unified RADV heap is the first thing to test, and the settled device queue"
metadata:
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-01T00:05:33.122Z
---

REVISED 2026-08-31: the 20 GiB GTT raise leaves the mandatory queue. The
normal boot stays at the current 14.64 GiB ceiling, and
`ttm.pages_limit=5242880` becomes an alternate GRUB entry used only after a
current-boot load proves a named high-precision artifact cannot fit. The
default entry stays the ordinary appliance; `ttm.page_pool_size` stays
automatic and `amdgpu.gttsize` stays unset. Nothing reaches /etc/default/grub
without an explicit user reboot window, since nick's 16 GiB debian13 VM dies
with the host.

Nothing in production needs it. The 9B distill Q4_K_M already loaded and ran
(1.76 tok/s decode, 11.47 prefill, archived for serving value), and quantized
7B Coder weights sit inside the present ceiling. Only 7B Coder F16 and larger
high-precision artifacts reach a boundary at all.

Heap topology is the first variable, not the ceiling. RADV's default split
exposes about 10.31 GiB device-local against a 15.47 GiB aggregate budget, so
an aggregate figure does not prove a DEVICE_LOCAL-requiring allocation fits.
`remote/radv-unified-heap.d/10-qwen-unified-heap.conf` already sets
`radv_enable_unified_heap_on_apu=true` for the separately named
`qwen-vulkan-unified-heap` executable, which merges heap visibility while
adding no physical capacity and needs no reboot; production keeps its own
executable identity, and the heap topology is read back from the Vulkan probe
rather than trusted from the executable name. Enlarging GTT under the default
split would still expose roughly two thirds as device-local, so the two changes
solve different constraints and unified heap resolves first.

Dynamic GTT does not exist in the sense that matters. TTM populates backing
pages on demand and VK_EXT_memory_budget reports live budgets, but AMDGPU reads
`ttm.pages_limit` at device init and hands a fixed size to
`amdgpu_gtt_mgr_init()`; a post-boot sysfs write changes global page accounting
and leaves the created GTT manager, `mem_info_gtt_total`, and every existing
Vulkan physical device untouched. Module reload or PCI rebind would recreate it
while tearing down the display and desktop, which is less controlled than a
reboot and stays out of the appliance.

A 20 GiB boot needs all of: an operationally valuable named model, a failure
under the current unified heap, a failure attributable to total eligible Vulkan
capacity rather than a per-allocation or buffer limit or host pressure, a
largest single allocation inside the driver limit, measured host reserve with
the VM resident, predicted 20 GiB margin sufficient, and user authorization.
The VM stays up as a standing tenant, so a VM-stopped arm never runs and every
capacity figure describes the machine as it serves.

Four repository corrections are queued behind the 4B close, since the gate
needs a device window: a supersession note on
`evidence/qwen38-9b-distill-admission.md` tying its host refusal to the
corrected preflight and the later successful run; `model-memory-preflight.sh`
reporting eligible per-heap budgets rather than aggregate alone
(`radv_heap_profile`, `memory_heap_count`, `device_local_heap_bytes`,
`device_local_budget_bytes`, `aggregate_budget_bytes`, required device-local
and staging bytes, maximum single-allocation and buffer requirements); heap
topology in every capacity record; and the GTT queue entry rewritten as
conditional.

One principle orders the queue: preserve computed state first, raise sustained
token throughput second, and expand residency capacity only for a measured
need. Capacity work runs beside the decode campaign in [[qwen-decode-campaign]]
rather than ahead of it; unified heap is still tested before any ceiling. The
natural-boundary repair set the size of the first prize: a 4B second turn fell
from 3402.090 s of reprefill to 6.134 and 7.985 s of restore, 544.9x and 438.5x,
along the measured production numerical path.

Live queue: 4B compact close -> three-class checkpoint promotion -> Stage A
census of the newly promoted binary -> current-boot default-versus-unified heap
capacity comparison -> quantized 7B Coder admission (Q4_K_M, Q6_K, Q8_0) ->
7B Coder F16 under the unified profile with failure classified by cause ->
9B Q4 operational arm with the VM resident (MemAvailable at launch, peak RSS,
GTT and VRAM use, swap-in delta, desktop latency, decode and prefill, kernel
hazards) -> decide whether a 20 GiB research boot has a measured subject -> 0.8B GPU/CPU telemetry sweep ->
CPU mtune/LTO factorial (four arms, tuning x LTO, -march=znver1 as a fifth
target-only arm; never combine mtune and LTO in one subject).

Related: [[qwen-model-lane-roadmap]], [[qwen-laptop-host-memory-tenants]],
[[qwen-benchmark-class-policy]].

Power envelope facts (read 2026-09-03, no writes): acpi-cpufreq with
schedutil, `cpufreq/boost=1`, cores observed 3.1-3.2 GHz (the 3050U's rated
boost is 3.2 GHz; 3.4 is not the part's spec); no amd_pstate on kernel
7.0.0-29. `amdgpu.ppfeaturemask=0xfff7bfff` leaves overdrive masked while
`pp_od_clk_voltage` still prints OD_SCLK 200/1100 and OD_RANGE 200-1100 MHz,
so a GPU clock past 1100 is a firmware/SMU question, not a sysfs one.
`sudo` requires the user's password (ALL, global 60 min timestamp); ryzenadj
is not installed. The user wants STAPM/PPT/TDC/EDC and package power raised
where viable and asked whether the GPU reaches 1.4 GHz; both belong to a
research boot/device window, never to a running campaign.

Power envelope answers (branch power-envelope, 2026-09-03, evidence in
evidence/power-envelope/README.md): boost is on and observed at 3.194 GHz
peak (3050U rated 3.2, cTDP 12-25 W, default 15 W; ACPI _PSS lists only
2300/1700/1400, CPB is unenumerated). Three Dali SMU messages raise package
power: stapm-limit 0x1a, fast-limit 0x1b, slow-limit 0x1c; TDC/EDC only
permit reaching it; the SMU range-checks nothing on this generation, so
PROCHOT/Tctl is the backstop and the platform re-asserts its own limits.
The GPU cannot reach 1.4 GHz: smu10 reads OD_RANGE from
GetMin/GetMaxGfxclkFrequency each time and rejects an OD max above the fresh
firmware answer (1100); 0xfff7bfff is amdgpu's built-in default and
od_enabled is set unconditionally in hw_init, so overdrive is enabled and
firmware-bounded, not masked. The decomposed VBIOS powerplayinfo body is all
zeros; the sibling repo's "Peak engine clock 1100 MHz" line has no cited
authority. remote/power-envelope.sh (apply/restore/status via sudo -n
ryzenadj, O_EXCL snapshot with owner token) is a lease profile term
(measure-fixed-package-{default,20w,25w}); remote/build-ryzenadj.sh pins
5775fc3e. Not yet run on the laptop; the campaign's RAPL energy reader is
still to build (energy_uj is 0400).
