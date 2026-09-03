# 2B calibration under a commanded engine clock: the first exercise on 239af705

```text
measurement_status=diagnostic
acquisition_head=239af7052913a659856a5626c00d8bee7ea970c1
calibration_verdict=failed
merge_authority=no
ownership_authority=provisional
instrument_version=pipeline-census-v3
engine_clock=applied policy=manual sclk_level=2 required_sclk_mhz=1100 mclk_floor_mhz=933
```

This calibration is the first to run under a commanded engine clock rather
than the free-running DPM regime the 0222Z through 1556Z links measured. The
regime precondition those links registered as a remedy is retired in favor of
pinning the graphics clock directly: `acquisition-contract.tsv` and
`inputs.tsv` record `engine_clock_policy=manual`, `engine_clock_sclk_level=2`,
`engine_clock_required_sclk_mhz=1100`, and `engine_clock_required_mclk_mhz=933`,
and a single priming warmup (`arms.tsv` slot `0a`, arm `W`) runs ahead of slot
1 rather than the three-warmup regime settle the 1556Z link needed. Every
sampled arm's `clock-sidecar-verdict.txt` reads `sclk_mode_mhz=1100
sclk_share=1.0000` and `mclk_mode_mhz=933` (`clock-state.tsv`), with one
exception: slot 17 (`I0`) reads `mclk_mode_mhz=1067`, the only sampled arm in
this run whose memory-clock mode departs from the commanded floor.

## Twenty-two of twenty-six arms complete

`terminal-state.tsv` reads `census=failed census_mode=calibration
arm_failures=4 cooldown_timeouts=26`. `arms.tsv` carries twenty-six slots (one
warmup plus twenty-five named arms); four fail. Three fail on
`clock_invariant`, one on `clock_sidecar`'s `window_lost` bound:

- Slot 3 (`P`): `arms/03-P/clock-sidecar-verdict.txt` reads
  `clock_state=measured window_samples=358 sclk_mode_mhz=1100 sclk_share=1.0000
  mclk_mode_mhz=933` and `clock_invariant=violated samples_at_required=358
  samples_below_required=0 below_required_fraction=0.0000 ...
  samples_at_mclk_floor=356 samples_below_mclk_floor=2
  below_mclk_floor_fraction=0.0056`. The sclk requirement holds in all 358
  samples; 2 of those 358 fabric samples read below the 933 MHz floor, which
  alone fails `clock_invariant` and the arm.
- Slot 10 (`I0`): the same shape, `samples_at_mclk_floor=356
  samples_below_mclk_floor=4` of 360 window samples.
- Slot 25 (`S`): the same shape at `samples_below_mclk_floor=4` of 1092.
- Slot 6 (`P`): `clock_invariant=held` -- the sclk and mclk requirements both
  hold across all 395 samples -- and the arm instead fails on
  `clock_sidecar`'s own bound: `window_lost=refused
  window_lost_fraction=0.0214 bound=0.0200 missed_bound_ns=40000000`, a loss
  of 2.14% of the sampling window against the 2.00% bound.

Every `clock_invariant=violated` line in this run reads
`sclk_source=pp_dpm_sclk_selected_mhz`. The runtime tree's telemetry broker
predates the delivered-frequency column the invariant check was written
against, so the check reads the selected-clock sysfs attribute rather than
the delivered one; `acquisition-contract.tsv` carries
`sidecar_source_sha256=9b87781068cc09762fae5b956b957a43f38ed5472ef9e27c5d916a37117b6607`,
distinct from the 1556Z link's `39c952fcbe6c8880dc056073f5e472b8fc74a8abd47eb5b6b722c452dbea19af`,
and the next head rebuilds the broker on this source-digest change to add the
delivered-frequency column the invariant check is meant to read.

## Decode rate recovers under load

`arms.tsv` carries the `P` arms' `tok_s` from 8.630 (slot 6, the
window-lost failure) to 9.828 (slot 13), with the completed `P` arms clustered
9.267 to 9.828, well above the cold warmup's 6.396 tok/s (slot `0a`). The
commanded clock holds the graphics engine at 1100 MHz from the warmup onward,
so the cold-to-warm recovery this run measures is throughput reaching its
served rate under sustained load rather than a DPM step to a higher clock: the
warmup's own `clock-sidecar-verdict.txt` already reads `sclk_mode_mhz=1100
sclk_share=1.0000`.

## Every cooldown times out

`terminal-state.tsv` reads `cooldown_timeouts=26` -- every one of the
twenty-six arms' cooldowns (`wall-clock.tsv`, `quiescence=timeout` on every
`cooldown` phase row). The quiescence predicate waits for a sampled clock step
below the regime's highest observed value; the manual policy pins the clock at
its highest value throughout, so no step below it ever arrives and every
cooldown runs to its 30 s deadline instead of returning early. The next head
fixes this by changing the quiescence predicate under a manually pinned clock.

## Every control lands `incomplete` or `unresolved`

`summary.tsv` carries the three registered controls:

```text
pair	control	outer	inner	replicates	mean_delta	sd_delta	ci_low	ci_high	verdict
1	sidecar	P-nosidecar	P	4	-	-	-	-	incomplete
2	compile	P	I0	4	-	-	-	-	incomplete
3	collect	I0	I1	4	+0.0294	0.0289	-0.0165	+0.0754	unresolved
```

Pair 1 (sidecar) and pair 2 (compile) both lose a comparable replicate to the
four arm failures -- slot 3 and slot 6 sit among the `P` replicates pair 1 and
pair 2 both draw on -- and land `incomplete`. Pair 3 (collect) draws its four
replicates from the `I0`/`I1` slots, none of which fail in this run: all four
comparable pairs read `1100/1100` on the selected clock, the mean paired
delta is +0.0294 with sample standard deviation 0.0289, and the nominal 95%
interval `[-0.0165, +0.0754]` spans the 0.02 collect bound, so the control
reads `unresolved` rather than `incomplete`, `refuted`, or `accepted`.
`terminal-state.tsv` matches: `control_incomplete=2 control_unresolved=1
control_refutations=0 control_state_changed=0 control_accepted=0`.

## The E1 ISA dump reproduces its module set

`raven2-e1-isa-20260902T2039Z-modules` (the sibling SPIR-V module directory
for the E1 dump at that stamp) holds 28 files, identical by name to the 28
files in `raven2-e1-isa-20260902T1312Z-modules`, so the E1 build this run
sits beside recompiles the same 28-module set as the 1312Z dump.

## Retention

Retained: `acquisition-contract.tsv`, `analysis-contract.tsv`, `arms.tsv`,
`calibration-contract.tsv`, `calibration-root.tsv`, `campaign-inputs.tsv`,
`inputs.tsv`, `summary.tsv`, `terminal-state.tsv`, `wall-clock.tsv`,
`clock-state.tsv`, `bricks/C0.receipt.tsv` through `bricks/C3.receipt.tsv`,
every sampled arm's `clock-sidecar-verdict.txt` (`0a`, `02` through `25`; the
four `P-nosidecar` arms run no sidecar), the slot 18, 19, 22, and 23 `I1`
arms' decode and prefill pipeline ledgers and request windows -- all four
accept in this run, `ownership=conclusive` on each, unlike the 1556Z link
where only slot 22 accepted -- and the slot 25 `S` arm's request window,
effective environment, and `server-log-request.slice`. `clock-state.tsv` is
computed the same way the 1556Z link computed its own: from each sampled
arm's `clock_state=measured` line in its own `clock-sidecar-verdict.txt`. The
full `pipeline-census.tsv` records for slots 18, 19, 22, and 23 stay off the
tree; their digests are in `raw-digests.txt` beside the `S` arm's slice
digest, computed on the appliance before copying. Paths are rewritten to
`$HOME` and the host to `qwen-laptop`.
