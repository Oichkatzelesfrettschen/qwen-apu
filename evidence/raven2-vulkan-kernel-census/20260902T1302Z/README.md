# 2B calibration on d490a39d: a DPM clock step change inside the census window

```text
measurement_status=diagnostic
acquisition_head=d490a39dab13058e2e9f86f051094fe807127158
analysis_head=the commit that adds this file
instrument_version=pipeline-census-v3
calibration_verdict=unresolved
merge_authority=no
ownership_authority=provisional
```

The fifth calibration in the chain, runner and runtime tree both at
`d490a39d`, widens the arm set from fourteen to twenty-six: a warmup arm W
at slot 0, four replicates of each of the three registered controls, and
S last. The raw records stay on the appliance under
`$HOME/raven2-kernel-census-20260902T1302Z-2b-calibration-v8/`, retained
here by digest in `raw-digests.txt`.

The repository gate at `d490a39d` reused 49 cached test cells and ran 30
fresh, against the prior gate root.

| slot | arm | tok/s | status |
| ---: | --- | ---: | --- |
| 0 | W | 9.557 | completed |
| 1 | P-nosidecar | 9.529 | completed |
| 2 | P | 9.542 | completed |
| 3 | P | 9.485 | completed |
| 4 | P-nosidecar | 9.498 | completed |
| 5 | P-nosidecar | 9.433 | completed |
| 6 | P | 9.277 | completed |
| 7 | P | 9.470 | completed |
| 8 | P-nosidecar | 9.541 | completed |
| 9 | P | 9.087 | completed |
| 10 | I0 | 8.216 | completed |
| 11 | I0 | 7.630 | completed |
| 12 | P | 7.375 | completed |
| 13 | P | 7.302 | completed |
| 14 | I0 | 7.225 | completed |
| 15 | I0 | 7.210 | completed |
| 16 | P | 7.293 | completed |
| 17 | I0 | 7.467 | completed |
| 18 | I1 | 7.093 | completed, ownership conclusive |
| 19 | I1 | 7.040 | completed, ownership conclusive |
| 20 | I0 | 7.208 | completed |
| 21 | I0 | 7.201 | completed |
| 22 | I1 | 7.133 | completed, ownership conclusive |
| 23 | I1 | 7.255 | completed, ownership conclusive |
| 24 | I0 | 7.278 | completed |
| 25 | S | 2.405 | completed, 64 logger blocks retained |

Every one of the twenty-six arms completed; `terminal-state.tsv` reads
`arm_failures=0 control_incomplete=0 control_refutations=0
control_unresolved=3 control_unclassified=0 control_accepted=0
control_required=3 cooldown_timeouts=0`. The gate reused 49 cells and ran
30 against the prior gate root. The warmup arm W ran at slot 0 and is
excluded from every pair and from the census, so it appears in `arms.tsv`
alone.

## The sidecar accepts on every sampled arm, and window loss stays inside the bound

Twenty-one of the twenty-six arms sample the sidecar (W and the three
additional `P-nosidecar` replicates run none). Every one of those
twenty-one reads `sidecar_exit=accepted` and `clock_sidecar=accepted
failures=-` in its `clock-sidecar-verdict.txt`, and `gaps_in_window=0`
against the 100 ms stall bound on all twenty-one.

`window_lost_fraction` against the 0.02 bound spans 0.0000 (25-S) to
0.0181 (24-I0) across the twenty-one sampled arms, every value inside the
bound. Mean sample cost spans 0.242 ms (13-P) to 0.397 ms (16-P), quoted
from each arm's own `sample_cost=accepted mean_ns=...` line.

## All three controls read unresolved under the replicate rule

`summary.tsv` carries the paired-mean, paired-interval verdict the
0819Z chain link registered as its remedy, now exercised with four
replicates per control instead of one:

- **sidecar** (pair 1, P-nosidecar against P): mean paired delta -0.0060,
  sd 0.0079, ci [-0.0186, +0.0066] against a 0.0065 bound -- unresolved.
- **compile** (pair 2, P against I0): mean paired delta -0.0208, sd
  0.0544, ci [-0.1074, +0.0658] against the same 0.0065 bound --
  unresolved.
- **collect** (pair 3, I0 against I1): mean paired delta -0.0215, sd
  0.0208, ci [-0.0546, +0.0116] against a 0.02 bound -- unresolved.

All three intervals span their bound rather than clearing it on one side,
so the calibration reads `unresolved` in place of the refuted-and-accepted
mix 0819Z reported on two replicates: `control_refutations=0
control_unresolved=3 control_accepted=0`. The wider replicate count moves
the read from a two-point sign disagreement to an interval that still
crosses zero, which is the outcome the remedy predicted for a machine
carrying about 4% of uncontrolled spread on a repeated depth-0 rate.

## The decode rate steps down with a DPM clock selection inside the census window, not with temperature

`clock-state.tsv` reads the modal `pp_dpm_sclk_selected_mhz` and modal
`pp_dpm_mclk_surface_mhz` inside each sampled arm's own request window,
computed on the appliance from the raw `clock-sidecar.tsv` between the
`begin_ns` and `end_ns` of `request-window.tsv`. The selected graphics
clock holds 1100 MHz through slot 9 (arms 02-P through 09-P), steps down
to 942 MHz at slot 10 and 837 MHz at slot 11, and settles between 775 and
857 MHz from slot 12 on. The decode rate falls with it: about 9.1 to 9.6
tok/s on the 1100 MHz arms against about 7.0 to 7.5 tok/s from slot 12
on, a ratio close to the 800/1100 clock ratio itself. Mean temperature
inside the request window falls over the same span, from 74 to 77 C on
the 1100 MHz arms to 71 to 72 C from slot 14 on, so the rate step tracks a
falling clock selection under falling temperature rather than a thermal
ceiling. The modal `pp_dpm_mclk_surface_mhz` reads 1067 MHz on every
sampled arm, so the fabric-clock surface does not order the step.

The compile control's 5.4% standard deviation is this step: pair 2 reads
P against I0 across slots that straddle the slot 9-to-12 transition, so
part of its scatter is the clock change rather than the compiled
instrument. The cause of the clock change is unattributed. The host
carried a qemu guest at about 41% of a core and `ksmd` active at the time
of reading, and no per-arm host-load record exists yet to test either
against the step. The consequence is registered for the next chain link:
a control pair is valid only where both of its arms ran under one clock
state, so the next runner revision reads the in-window `sclk` mode per
arm from the sidecar and marks a pair whose two arms differ as
`state-changed` rather than judging it on the paired-mean rule alone.

## Collect: the first I1 arm clears ownership again

Slot 18's I1 arm accepted whole, 63 decode graphs,
`ownership=conclusive` in `arms/18-I1/pipeline-ledger-decode.tsv`: a
134.776 ms bracket union per decode graph, a 133.431 ms exclusive
bracket, and a 1.345 ms ambiguous overlap. `raw-digests.txt` carries the
digests of all four sampled I1 arms' `pipeline-census.tsv` records
(slots 18, 19, 22, 23); the retained ledgers are the summarizer's own
output against slot 18's file, not a re-derivation here.

## The S inventory, computed on the appliance

`arms/25-S/perf-logger-inventory.tsv` is the appliance's own output: 64
complete blocks, 63 decode and 1 prefill, 0 unknown, 19 ops.
`arms/25-S/server-effective-env.tsv` carries the served process's own
environment -- `GGML_VK_LOW_PRIORITY=1`, `GGML_VK_MAX_NODES_PER_SUBMIT=32`,
`GGML_VK_PERF_LOGGER=1`, `GGML_VK_PERF_LOGGER_FREQUENCY=1`,
`GGML_VK_SERIALIZE_SUBMISSIONS=1`, `QWEN_PERF_LOGGER=1`, and the two ICD
names -- the same closed profile as declared, and nothing else in those
families.

## The E1 dump

A shader-ISA dump ran after this calibration (34 shaders, 28 modules) and
is retained separately under `evidence/raven2-vulkan-kernel-census/e1/`
by another task.

## Wall clock

`wall-clock.tsv` puts the campaign at 611 s over its twenty-six arms, with
launch, request, teardown, and analysis phases summing to 239 s + 241 s +
22 s + 8 s = 510 s and cooldown at 99 s (26 arms averaging about 3.83 s).
Every cooldown reached quiescence before its deadline
(`cooldown_timeouts=0`), which confirms the remedy 0819Z registered: the
cooldown's `sclk` predicate moved from the lowest listed step to a stable
step below the highest, so a cooldown now exits once the device rests
there instead of timing out at 30 s waiting on a step this device never
reaches at idle.

## Remedies registered for the next chain link

A control pair spanning the slot 9-to-12 clock-selection step needs a
per-arm clock-state check ahead of its paired-mean verdict: the next
runner revision reads the in-window `sclk` mode from the sidecar per arm
and marks a pair `state-changed` rather than folding a clock transition
into the paired scatter the replicate rule already accounts for. The
cause of the clock step -- coincident host load from the qemu guest and
`ksmd`, or a DPM policy transition unrelated to either -- stays
unattributed pending a per-arm host-load record.

## Retention

Retained: `acquisition-contract.tsv`, `analysis-contract.tsv`,
`arms.tsv`, `calibration-contract.tsv`, `calibration-root.tsv`,
`campaign-inputs.tsv`, `inputs.tsv`, `summary.tsv`, `terminal-state.tsv`,
`wall-clock.tsv`, `clock-state.tsv`, `bricks/C0.receipt.tsv` through
`bricks/C3.receipt.tsv`, every sampled arm's `clock-sidecar-verdict.txt`
(02-P through 25-S; W and the three additional `P-nosidecar` arms run no
sidecar), the slot 18 decode and prefill ledgers, the slot 18, 19, 22,
23, and 25 request windows, and the S slice with its appliance-computed
inventory, effective environment, and `server-log-request.slice`. Every
`await-quiescence.stderr` in this run came back empty, so none is
retained. The full `pipeline-census.tsv` records for slots 18, 19, 22,
and 23 stay off the tree; their digests are in `raw-digests.txt` beside
the S arm's slice digest, computed on the appliance before copying.
`clock-state.tsv` is computed on the appliance from each sampled arm's
raw `clock-sidecar.tsv` inside its own request window and carries `slot`,
`arm`, `tok_s`, `sclk_mode_mhz`, `mclk_mode_mhz`, `temp_mean_c`,
`temp_max_c`, `busy_mean_percent`, and `samples`. Paths are rewritten to
`$HOME` and the host to `qwen-laptop`.
