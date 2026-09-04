# 2B calibration on b7a3612f: the clock-state invariant's first exercise

```text
measurement_status=diagnostic
acquisition_head=b7a3612f8de448b320c1b8e24306f5d760c06d48
analysis_head=the commit that adds this file
instrument_version=pipeline-census-v3
calibration_verdict=failed
merge_authority=no
ownership_authority=provisional
```

The sixth calibration in the chain, runner and runtime tree both at
`b7a3612f`, is the first to carry the per-arm clock-state check the
0819Z and 1302Z links registered as a remedy: `arms.tsv` now carries
`sclk_mode_mhz` and `sclk_share` beside its existing columns, and
`summary.tsv` carries the paired `sclk_modes` a control's two arms ran
under. The arm set stays the twenty-six of the prior link: a warmup arm
W at slot 0, four replicates of each of the three registered controls,
and S last. The raw records stay on the appliance under
`$HOME/raven2-kernel-census-20260902T1417Z-2b-calibration-v8/`, retained
here by digest in `raw-digests.txt`.

| slot | arm | tok/s | status |
| ---: | --- | ---: | --- |
| 0 | W | 9.587 | completed |
| 1 | P-nosidecar | 9.445 | completed |
| 2 | P | 9.551 | completed |
| 3 | P | 9.414 | completed |
| 4 | P-nosidecar | 9.649 | completed |
| 5 | P-nosidecar | 9.497 | completed |
| 6 | P | 9.438 | completed |
| 7 | P | 9.395 | completed |
| 8 | P-nosidecar | 9.534 | completed |
| 9 | P | 9.079 | completed |
| 10 | I0 | 8.226 | failed |
| 11 | I0 | 7.691 | completed |
| 12 | P | 7.523 | completed |
| 13 | P | 7.152 | completed |
| 14 | I0 | 7.186 | completed |
| 15 | I0 | 7.327 | completed |
| 16 | P | 6.999 | completed |
| 17 | I0 | 7.273 | completed |
| 18 | I1 | 7.346 | completed, ownership conclusive |
| 19 | I1 | 7.296 | completed, ownership conclusive |
| 20 | I0 | 7.080 | completed |
| 21 | I0 | 7.177 | completed |
| 22 | I1 | 7.043 | completed, ownership conclusive |
| 23 | I1 | 7.287 | completed, ownership conclusive |
| 24 | I0 | 7.259 | completed |
| 25 | S | 2.365 | completed, 64 logger blocks retained |

Slot 10's I0 arm is the one failure: its sidecar refuses on
`window_lost_fraction`, and that single arm failure carries through
`terminal-state.tsv` to `census=failed`: `arm_failures=1
control_incomplete=1 control_refutations=0 control_unresolved=1
control_state_changed=1 control_unclassified=0 control_accepted=0
control_required=3 cooldown_timeouts=0`. The warmup arm W ran at slot 0
and is excluded from every pair and from the census, so it appears in
`arms.tsv` alone.

## The sidecar accepts on twenty of twenty-one sampled arms

Twenty-one of the twenty-six arms sample the sidecar (W and the four
`P-nosidecar` replicates run none). `gaps_in_window=0` against the
100 ms stall bound holds on all twenty-one, and `window_lost_fraction`
against the 0.02 bound spans 0.0000 (13-P) to 0.0161 (09-P and 20-I0) on
the twenty that accept. Slot 10's I0 arm is the exception:
`window_lost_fraction=0.0326` against the same 0.02 bound, so its
`clock_sidecar=refused failures=window_lost` line is the arm failure the
terminal state reads. Mean sample cost spans 0.251 ms (25-S) to
0.372 ms (12-P) across all twenty-one, the refused arm included, since
sample cost is a sidecar property independent of the window-loss
verdict. Every `await-quiescence.stderr` and `perf-logger.stderr` in
this run came back empty, so neither is retained.

## The regime change reproduced, and this time a control failure names it directly

The in-window graphics clock held 1100 MHz on the early sampled slots
(02-P through 09-P) and settled between 750 MHz (13-P) and 837 MHz
(17-I0) from slot 11 on. Slot 10's I0 arm carries the transition inside
its own window -- `clock_state=measured sclk_mode_mhz=914
sclk_share=0.1338` -- and that same window is the one whose
`window_lost_fraction` of 0.0326 clears the 0.02 bound and refuses the
sidecar. The clock step and the window-loss refusal land on the same
arm, so this calibration cannot separate a sampler cost that rises
during a DPM transition from a transition that happens to coincide with
one. The modal `pp_dpm_mclk_surface_mhz` reads 1067 MHz on every sampled
arm, unchanged from the prior link, so the fabric-clock surface still
does not order the step.

## The clock-state invariant works as designed, and exposes its own limit

`summary.tsv` carries the paired-mean, paired-interval verdict beside
each pair's own `sclk_modes` column, the remedy the 1302Z link
registered:

- **sidecar** (pair 1, P-nosidecar against P): mean paired delta
  -0.0085, sd 0.0151, ci [-0.0325, +0.0155] against a 0.0065 bound --
  unresolved. All four inner arms ran at `sclk_modes` `1100/-` (the
  outer P-nosidecar carries no sidecar reading), so the four replicates
  are comparable at one clock state and the interval still spans the
  bound on its own.
- **compile** (pair 2, P against I0): `incomplete`, since slot 10's I0
  arm is the pairing's fourth inner replicate and the sidecar refusal
  that arm carries leaves the pair without a verdict to compute.
- **collect** (pair 3, I0 against I1): `state-changed`,
  `comparable_pairs=0 of 4`. The exact-mode rule compares 825/837,
  787/762, 775/800, and 812/825 -- four pairs whose two arms differ by
  12 to 25 MHz apiece, which is one sustained regime hovering across
  fine-grained clock values rather than two regimes a paired-mean rule
  should read as changed.

The exact-mode rule the invariant applies is stricter than the regime it
was built to detect: it flags every collect pair as state-changed
because the sustained low regime never re-selects one exact clock across
a pair, not because the machine crossed the slot 9-to-12 step inside
pair 3. The remedy for the next chain link is comparability within a
band (on the order of 6%) rather than exact-mode equality, together with
a regime precondition of warmup arms ahead of slot 1, since the served
appliance lives in the sustained low regime and that regime is the one
worth measuring precisely.

## Collect: the first I1 arm clears ownership again

Slot 18's I1 arm accepted whole, 63 decode graphs,
`ownership=conclusive` in `arms/18-I1/pipeline-ledger-decode.tsv`: a
129.075 ms bracket union per decode graph, a 127.780 ms exclusive
bracket, and a 1.295 ms ambiguous overlap. `raw-digests.txt` carries the
digests of all four sampled I1 arms' `pipeline-census.tsv` records
(slots 18, 19, 22, 23); the retained ledgers are the summarizer's own
output against slot 18's file, not a re-derivation here.

## The S inventory, computed on the appliance

`arms/25-S/perf-logger-inventory.tsv` is the appliance's own output: 64
complete blocks, 63 decode and 1 prefill, 0 unknown, 19 ops, matching
the prior link's own count under the same closed profile.
`arms/25-S/server-effective-env.tsv` carries the served process's own
environment -- `GGML_VK_LOW_PRIORITY=1`, `GGML_VK_MAX_NODES_PER_SUBMIT=32`,
`GGML_VK_PERF_LOGGER=1`, `GGML_VK_PERF_LOGGER_FREQUENCY=1`,
`GGML_VK_SERIALIZE_SUBMISSIONS=1`, `QWEN_PERF_LOGGER=1`, and the two ICD
names -- and nothing else in those families.

## The E1 dump reruns identically

A shader-ISA dump ran after this calibration under
`raven2-e1-isa-20260902T1427Z` on the appliance and is retained
separately under `evidence/raven2-vulkan-kernel-census/e1/` by another
task. Its module directory carries 28 `.spv` files named by their own
content digest, and the appliance's `raven2-e1-isa-20260902T1312Z-modules`
and `raven2-e1-isa-20260902T1427Z-modules` directories hold the same
28 names, so the two dumps are identical by digest.

## Wall clock

`wall-clock.tsv` puts the campaign at 614 s over its twenty-six arms,
with launch, request, teardown, and analysis phases summing to
238 s + 242 s + 22 s + 8 s = 510 s and cooldown at 102 s (26 arms
averaging about 3.94 s). Every cooldown reached quiescence
(`cooldown_timeouts=0`), the same remedy the 0819Z link registered.

## Remedies registered for the next chain link

The clock-state invariant needs a comparability band rather than exact
clock-mode equality: the sustained low regime this appliance serves
under hovers across fine-grained DPM values close enough together that
an exact-mode rule reads every pair as state-changed, which is the
opposite failure from the paired-mean rule folding a real regime
transition into scatter. A regime precondition -- warmup arms run ahead
of slot 1 until the sidecar reports the sustained regime -- keeps a
future compile or collect pair from landing across the one-time 1100 MHz
to low-regime step this link's slot 10 still carries. The cause of that
step stays unattributed, as it was at 1302Z.

## Retention

Retained: `acquisition-contract.tsv`, `analysis-contract.tsv`,
`arms.tsv`, `calibration-contract.tsv`, `calibration-root.tsv`,
`campaign-inputs.tsv`, `inputs.tsv`, `summary.tsv`, `terminal-state.tsv`,
`wall-clock.tsv`, `clock-state.tsv`, `bricks/C0.receipt.tsv` through
`bricks/C3.receipt.tsv`, every sampled arm's `clock-sidecar-verdict.txt`
(02-P through 25-S; W and the four `P-nosidecar` arms run no sidecar),
the slot 18 decode and prefill ledgers, the slot 18, 19, 22, 23, and 25
request windows, and the S slice with its appliance-computed inventory,
effective environment, and `server-log-request.slice`. Every
`await-quiescence.stderr` and `perf-logger.stderr` in this run came back
empty, so neither is retained. The full `pipeline-census.tsv` records for
slots 18, 19, 22, and 23 stay off the tree; their digests are in
`raw-digests.txt` beside the S arm's slice digest, computed on the
appliance before copying. `clock-state.tsv` is computed on the appliance
from each sampled arm's raw `clock-sidecar.tsv` inside its own request
window, read off the same `clock_state=measured` line each arm's own
`clock-sidecar-verdict.txt` already carries, and holds `slot`, `arm`,
`tok_s`, `sclk_mode_mhz`, `mclk_mode_mhz`, `temp_mean_c`, `temp_max_c`,
`busy_mean_percent`, `samples`, and `sclk_share`. Paths are rewritten to
`$HOME` and the host to `qwen-laptop`.
