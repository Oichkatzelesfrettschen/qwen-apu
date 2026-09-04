# 2B calibration under manual-gfx1100-fclk933: one host stall refuses the sidecar control

```text
measurement_status=diagnostic
acquisition_head=803d46837d3468841898dcc471a7bbcf45c924a9
calibration_verdict=failed
merge_authority=no
ownership_authority=provisional
instrument_version=pipeline-census-v3
engine_clock=applied policy=manual sclk_level=2 mclk_level=2 required_sclk_mhz=1100 required_mclk_mhz=933
clock_state_name=manual-gfx1100-fclk933
```

This is the first calibration whose every sampled arm decoded under one
delivered clock pair. `acquisition-contract.tsv` records
`engine_clock_policy=manual`, `engine_clock_sclk_level=2`,
`engine_clock_mclk_level=2`, `engine_clock_required_sclk_mhz=1100`, and
`engine_clock_required_mclk_mhz=933`; the rebuilt broker reports the delivered
graphics clock from hwmon `freq1_input` and every arm's
`clock-sidecar-verdict.txt` reads `sclk_source=sclk_actual_mhz`. All 22
sampled arms hold `clock_invariant=held` with `below_required_fraction=0.0000`
and `below_mclk_floor_fraction=0.0000` over 354 to 410 samples each
(`clock-state.tsv`), so the graphics clock delivered 1100 MHz on every sample
and the fabric held its 933 MHz hard minimum on every sample. The state is
named for the pair it holds rather than as a maximum: 1100 MHz is the highest
commandable graphics level and 933 MHz is the highest fabric level the
firmware honors as a hard minimum, since a 1067 MHz request is capped at 933
(`../dpm-authority/20260902T2002Z-fclk-level3/`).

## Twenty-five of twenty-six arms complete and the sidecar control is incomplete

`terminal-state.tsv` reads `census=failed arm_failures=1 control_incomplete=1
control_unresolved=2 control_accepted=0 cooldown_timeouts=3`. One arm fails:
slot 3 (`P`) decodes at 7.711 tok/s against 9.20 to 9.79 for every other
production arm, and its verdict reads `window_lost=refused
window_lost_fraction=0.1000 bound=0.0300` with `gaps=refused max_ns=161856219`.
Its clock invariant held on all 410 samples. The refusal is a coverage
refusal, and the coverage loss and the 19% decode loss share one cause: the
sampler at nice 19 and the server at nice 19 on core 0 were both held off the
core for 60 to 162 ms at a time, fourteen times inside a 9 s window. The
`# host` lines of the arm's sidecar record carry `load1` rising from 2.53 to
4.55 across the arm while `ksm_pages_sharing` falls from 176167 to 173464,
so a nice-0 tenant and the KSM scanner were both active on the host while
this arm ran. `../dpm-authority/20260902T2154Z-nice-probe/` measures the
priority mechanism directly.

The maximum host load inside each arm's window orders the arm's rate across
this run: the four production arms above 9.7 tok/s ran under `load1` at or
below 1.86, the arm at 7.71 ran under 4.55, and the warmup at 9.49 ran under
4.00. The order is observed on one run and the correlation is not a
mechanism; the probe above is what tests one.

## The two resolved controls

| control | pair | mean | sd | 95% CI | bound | verdict |
| --- | --- | ---: | ---: | --- | ---: | --- |
| compile | P vs I0 | +0.0342 | 0.0348 | [-0.0211, +0.0895] | 0.0065 | unresolved |
| collect | I0 vs I1 | -0.0114 | 0.0064 | [-0.0215, -0.0012] | 0.02 | unresolved |

The collect control measures the census collection cost at about 1.1% with a
paired sd of 0.6%, and its interval crosses the 2% bound by 0.0015 at the low
edge; a fifth replicate at this sd would close it. The compile control's
paired sd is 3.5% over four replicates, so its 95% interval is 11 points
wide against a 0.65% bound. At that sd, an equivalence verdict at 0.65%
needs about 120 replicates. The bound was registered for a machine whose
depth-0 repeat spread was measured at 4% under `auto` and is unreachable at
this scatter; the sidecar bound is the same 0.0065 and faces the same
arithmetic. Either the scatter falls, which the priority probe addresses, or
the two compile-class bounds are re-registered at what the campaign resolves,
and this run is the evidence for that decision rather than the decision.

The compile control's four deltas read +0.0223, +0.0313, +0.0826, +0.0005:
the census build with collection off ran faster than the production bundle
in every replicate. Both manifests record `-march=znver1 -mtune=znver1` on
the same preset family, so a compiler difference is not established, and
the I0 arms sat at slots 10, 11, 14, 15, 17, 20, 21, 24 while their paired P
arms sat at 9, 12, 13, 16, which is later in the load decay this run
recorded. The sign is retained as an observation.

## Cooldowns

Three of 26 cooldowns timed out at 30 s (slots 7, 8, 24) under
`--sclk-forced`; the other 23 converged in 5.7 to 28.7 s. A forced clock
leaves the GPU busy predicate and the process predicate as the drain
signals, and the three timeouts fall in the same load-decay window as the
slow production arms.

## Files

| file | content |
| --- | --- |
| `acquisition-contract.tsv`, `analysis-contract.tsv`, `calibration-contract.tsv`, `calibration-root.tsv` | the contracts the run was acquired and judged under |
| `arms.tsv`, `summary.tsv`, `terminal-state.tsv`, `wall-clock.tsv` | the per-arm ledger, the control verdicts, the terminal state, and the phase clock |
| `clock-state.tsv` | per-arm delivered clock mode, share, temperature, busy, and sample count from each verdict |
| `arms/*/clock-sidecar-verdict.txt`, `arms/*/request-window.tsv` | the validator's verdict and the request window per arm |
| `arms/*/pipeline-ledger-{prefill,decode}.tsv` | the collected census ledgers of the four I1 arms |
| `raw-digests.txt` | SHA-256 of each I1 arm's raw `pipeline-census.tsv`, computed on the appliance |
| `bricks/*.receipt.tsv` | the four control brick receipts |
