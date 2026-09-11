---
name: qwen-package-power-not-a-lever
description: Raven2 package budget (STAPM/PPT via ryzenadj) is closed as a decode lever; the part draws ~17 W under a 15 W STAPM and refuses more under 25 W
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-04T02:14:05.415Z
---

Measured 2026-09-03 on the appliance (branch power-campaign-run, evidence/power-envelope/20260904T0138Z/): twelve arms, control/20W/25W/control on 2B, 0.8B, 4B under compute-state-lease. Package draw 16.2 to 17.5 W on every arm, STAPM 15 vs 25 W moves it by at most 0.27 W; decode within -0.4% to +0.7% of control; GFXCLK 1100 on all arms; Tctl peak 59 to 78 C against the 90 C limit. HP F.69 platform defaults: STAPM 15, PPT fast 25, PPT slow 20 W (evidence/power-envelope/baseline-info.txt). ryzenadj resolves the part to FAM_PICASSO (CPUID model 24), built at 5775fc3e into ~/.local/bin on the laptop.

**Why:** the workload, not the ceiling, bounds the draw; the "thermally bound" mechanism the design registered is refuted.

**How to apply:** do not propose package-budget arms as a throughput lever; the remaining power question is per-core boost residency, unmeasured. The measure-fixed profile (nice 19) wedges a served session because monitor-qwen-runtime.sh renices to 0 and exits; served arms use the serve-fixed-package-* profiles at nice 0. Cold sclk selection needs up to 27 s (QWEN_COMPUTE_STATE_SELECT_DEADLINE_S=45). See [[qwen-gtt-and-queue-decisions]] and [[qwen-fixed64-scoreboard-baseline]].
