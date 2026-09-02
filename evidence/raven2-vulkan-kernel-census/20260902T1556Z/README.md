# 2B calibration on 05bd95f0: the regime precondition's first exercise

```text
measurement_status=diagnostic
acquisition_head=05bd95f02417fa8c17d023f3e7655a004c6600de
analysis_head=the commit that adds this file
instrument_version=pipeline-census-v3
calibration_verdict=failed
merge_authority=no
ownership_authority=provisional
```

The seventh calibration in the chain is the first to carry the regime
precondition the 1417Z link registered as a remedy: three warmup arms run
ahead of slot 1 (`arms.tsv` slots `0a`, `0b`, `0c`, arm `W`), and the census
starts its named arms only once the sidecar's `sclk_share` settles inside
`sclk_band=0.06` around a modal clock. `inputs.tsv` records the settled state
as `regime_sclk_mhz	658.0` and `regime_arms	3`, so the three warmups are what
it took to reach precondition. 658 MHz is a third regime, below the 750 to
857 MHz sustained band the 1302Z and 1417Z links measured (1302Z stepped to
775-857 MHz across slots 9 to 12; 1417Z settled between 750 MHz and 837 MHz
from slot 11 on). The twenty-five named arms then decoded from 5.747 to
7.186 tok/s (`arms.tsv`), clustering at 5.7 to 6.1 tok/s for the eighteen
arms whose `sclk_mode_mhz` held at 640-666 MHz, with slots 2, 14, 15, and 16
running above that band at an up-regime `sclk_mode_mhz` of 750-787 MHz.

`stage-a-chain13.log` puts the E4 candidate build
(`llama-vulkan-q4k-activation-group-sums.patch`) at `build_e4_exit=0` at
15:56:35Z, and `inputs.tsv` records this campaign's own `started_utc` as
`2026-09-02T15:56:36Z` -- one second later. The campaign follows directly on
a build that ran from `prepare_e4_exit` at 15:36:41Z, about twenty minutes on
the laptop's two CPU cores, so the shared power and thermal budget the two
Zen+ cores and the Vega compute units draw from is the registered explanation
for the 658 MHz regime this run measures below the two prior runs' 750 to
857 MHz band. The falsifier is a calibration that follows an idle hour and
still settles at 658 MHz.

## Eleven of twenty-five named arms fail the sidecar's window-loss bound

`window_lost_fraction` against the `0.02` bound spans 0.0211 to 0.0625 across
the eleven failing arms, none of the fourteen accepted arms crossing it.
`arms/13-P/clock-sidecar-verdict.txt` reads
`window_lost=refused window_lost_fraction=0.0212 bound=0.0200
missed_bound_ns=20000000` at the low end, and
`arms/25-S/clock-sidecar-verdict.txt` reads `window_lost=refused
window_lost_fraction=0.0625 bound=0.0200 missed_bound_ns=20000000` at the
high end. Ten of the eleven still hold `gaps_in_window=0` against the 100 ms
stall bound, so their refusal is window-loss alone; the eleventh, 25-S, also
fails on `gaps`, with `max_ns=223225687` clearing the 100 ms bound by more
than double. The ten window-loss-only refusals carry a mean sample cost from
0.380 ms (13-P) to 0.575 ms (19-I1) under the throttled 658 MHz regime,
against the 1417Z link's own 0.251 ms to 0.372 ms across all twenty-one of
its sampled arms in its sustained 750 to 837 MHz regime, so the
10 ms sampler period costs proportionally more of each window at the lower
clock and the remedy for the next chain link is a 20 ms default period.

## The served A/B still refuses at launch

`stage-a-chain13.log` records `ab_exit=2 output=$HOME/raven2-served-ab-e4-20260902T1611Z
the control manifest holds other than one candidate_series row`. The harness
refuses a production control manifest carrying zero `candidate_series` rows
rather than reading the absence as the empty selection, so no served-decode
A/B ran this link. The remedy for the next chain link is to read an absent
`candidate_series` row as the empty selection instead of refusing outright.

## Every control lands `incomplete`

`summary.tsv` carries the paired-mean verdict beside each pair's own
`off_regime_arms` count, the field this link adds:

```text
pair	control	outer	inner	replicates	off_regime_arms	bound	verdict
1	sidecar	P-nosidecar	P	4	1	0.0065	incomplete
2	compile	P	I0	4	3	0.0065	incomplete
3	collect	I0	I1	4	0	0.02	incomplete
```

`terminal-state.tsv` reads `census=failed census_mode=calibration
arm_failures=11 control_incomplete=3 control_refutations=0
control_unresolved=0 control_state_changed=0 control_unclassified=0
control_accepted=0 control_required=3 cooldown_timeouts=0
calibration_root_sha256=12c1545a16b98c9d7fcff608bbee77739abf3b39cb5c73335fa8f8d0f77c336a`.
Every one of the three registered controls carries at least one inner or
outer replicate among the eleven sidecar-refused arms -- pair 1 loses one of
its four `P` replicates, pair 2 loses three of its four `I0` replicates, and
pair 3 loses three of its four `I1` replicates (18, 19, and 23 all refuse;
22 alone accepts), which leaves at most one comparable replicate for a pair
that needs four -- so `incomplete` rather than a computed delta is every
pair's verdict, and none of the three reaches `unresolved`, `state-changed`,
or `accepted`.

`regime_delta` in `arms.tsv` (the named arm's `sclk_mode_mhz` measured against
the 658 MHz settled regime) spans -0.3921 (25-S, at the 400 MHz serialized
clock the S profile itself selects) to +0.1639 (15-I0 and 16-P, at the
787 MHz up-regime excursion); excluding 25-S the range is -0.0274 (7-P) to
+0.1639. The up-regime excursion at slots 2 and 14 through 16 is inside the
named-arm window this link still measures across, which is why the
precondition's own `sclk_band=0.06` bounds the settled state at slot 1 and
not every later slot.

## Collect: one I1 arm clears ownership

Slot 22's I1 arm accepted whole, `ownership=conclusive` in
`arms/22-I1/pipeline-ledger-decode.tsv`, against slots 18, 19, and 23, whose
sidecars all refuse on `window_lost`. `raw-digests.txt` carries the digests
of all four sampled I1 arms' `pipeline-census.tsv` records (slots 18, 19, 22,
23); the retained decode and prefill ledgers are the summarizer's own output
against slot 22's file, not a re-derivation here.

## The S arm fails at the sidecar, not the request

`arms/25-S/summary.json` reports `"valid": true` with a completed decode at
1.489 tok/s and 64 requested tokens; the arm's overall `status=failed` in
`arms.tsv` comes from its sidecar's `clock_sidecar=refused
failures=gaps,window_lost` alone. `arms/25-S/server-effective-env.tsv`
carries the served process's own environment -- `GGML_VK_LOW_PRIORITY=1`,
`GGML_VK_MAX_NODES_PER_SUBMIT=32`, `GGML_VK_PERF_LOGGER=1`,
`GGML_VK_PERF_LOGGER_FREQUENCY=1`, `GGML_VK_SERIALIZE_SUBMISSIONS=1`,
`QWEN_PERF_LOGGER=1`, and the two ICD names -- and nothing else in those
families. No `perf-logger-inventory.tsv` exists for this run: the harness
computes that inventory only for an accepted S arm, and this one refuses.

## Wall clock

`wall-clock.tsv` puts the campaign at 900.851 s over its twenty-eight arms
(three warmups plus twenty-five named), with launch, request, teardown, and
analysis phases summing to 339.899 s + 345.330 s + 30.500 s + 6.069 s =
721.798 s and cooldown at 175.892 s (28 arms averaging 6.282 s). Every
cooldown reached quiescence (`cooldown_timeouts=0`), the same remedy the
0819Z link registered.

## Remedies registered for the next chain link

The 10 ms sampler period costs proportionally more of each window under the
throttled 658 MHz regime than it did in the 1417Z link's sustained-high-clock
arms, so the default period moves to 20 ms. The served A/B harness refuses a
production control manifest carrying zero `candidate_series` rows rather than
reading the absence as the empty selection; the next chain link reads an
absent row as the empty selection instead.

## Retention

Retained: `acquisition-contract.tsv`, `analysis-contract.tsv`, `arms.tsv`,
`calibration-contract.tsv`, `calibration-root.tsv`, `campaign-inputs.tsv`,
`inputs.tsv`, `summary.tsv`, `terminal-state.tsv`, `wall-clock.tsv`,
`clock-state.tsv`, `bricks/C0.receipt.tsv` through `bricks/C3.receipt.tsv`,
every sampled arm's `clock-sidecar-verdict.txt` (`0a`-`0c`, `02` through
`25`; the four `P-nosidecar` arms run no sidecar), the slot 22 decode and
prefill ledgers, the slot 18, 19, 22, 23, and 25 request windows, and the S
arm's effective environment and `server-log-request.slice`. `clock-state.tsv`
is computed here the same way the 1417Z link computed its own: from each
sampled arm's raw `clock-sidecar.tsv` inside its own request window, read off
the same `clock_state=measured` line each arm's own `clock-sidecar-verdict.txt`
already carries, and holds `slot`, `arm`, `tok_s`, `sclk_mode_mhz`,
`mclk_mode_mhz`, `temp_mean_c`, `temp_max_c`, `busy_mean_percent`, `samples`,
and `sclk_share`, the three warmup arms included. The full `pipeline-census.tsv`
records for slots 18, 19, 22, and 23 stay off the tree; their digests are in
`raw-digests.txt` beside the S arm's slice digest, computed on the appliance
before copying. Paths are rewritten to `$HOME` and the host to `qwen-laptop`.
