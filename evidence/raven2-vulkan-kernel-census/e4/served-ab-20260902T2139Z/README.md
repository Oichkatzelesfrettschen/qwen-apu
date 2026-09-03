# E4 served A/B under manual-gfx1100-fclk933: three clean pairs, one sampler gap

```text
measurement_status=diagnostic
acquisition_head=803d46837d3468841898dcc471a7bbcf45c924a9
served_ab_verdict=failed
control_server_sha256=5dd86b90154f6143a5303efd2590b9268a0a5e3e908c4d6791f1fde03a4782c2
candidate_server_sha256=7d9df19f846f0696445b55fed138d7d743d8a315ac0e238d34d023c6f94026b7
engine_clock=applied policy=manual sclk_level=2 mclk_level=2 required_sclk_mhz=1100 required_mclk_mhz=933
clock_state_name=manual-gfx1100-fclk933
```

The second served comparison of the production bundle against the E4 build
(`patches/llama-vulkan-q4k-activation-group-sums.patch`), and the first under
a commanded clock pair. Every one of the nine arms, the warmup included,
holds `clock_invariant=held` with `sclk_source=sclk_actual_mhz`,
`sclk_share=1.0000` at 1100 MHz, `mclk_mode_mhz=933`, and both below-floor
fractions at zero (`clock-state.tsv`), so the clock is removed from the
comparison for the first time.

## What the eight arms measured

| slot | arm | tok/s | lost fraction | max gap ms | verdict |
| ---: | --- | ---: | ---: | ---: | --- |
| 1 | C | 9.738 | 0.0000 | 24 | completed |
| 2 | K | 9.462 | 0.0144 | 83 | completed |
| 3 | K | 9.081 | 0.0000 | 73 | completed |
| 4 | C | 9.065 | 0.0000 | 56 | completed |
| 5 | C | 9.646 | 0.0000 | 61 | completed |
| 6 | K | 9.157 | 0.0066 | 77 | completed |
| 7 | K | 9.263 | 0.0000 | 107 | completed |
| 8 | C | 9.327 | 0.0208 | 113 | failed, `gaps` |

Slot 7 carried a 107 ms gap and passed, because the validator's stall
bound reads `over_max` inside the request window alone and that gap fell
outside it; slot 8's 113 ms gap fell inside. Coverage is asymmetric across
the pairs by up to 0.0208, which is inside the 0.01-per-pair symmetry rule
proposed after this run only for pairs 2 and 3; pair 1 (0.0000 against
0.0144) and pair 4 (0.0208 against 0.0000) would each fail it.

Three pairs survive: -0.0283, +0.0018, -0.0507, a surviving mean of -0.0257.
`summary.tsv` as written by the runner at 803d468 reports the control as
`incomplete` with no numbers, since a set missing a delta measures a
different set; the summarizer after this run carries the surviving pairs in
its detail column, and the numbers above are read from `arms.tsv` directly.

Slot 8 held the clock on all 365 samples, lost 2.08% of its window against
the 3% coverage bound, and was refused on one 113 ms gap against the 100 ms
stall bound. Under a forced policy the firmware holds one level, so a step
inside a gap has no path and the samples at both edges bracket it; the stall
bound therefore follows the policy after this run, 100 ms under `auto` and
250 ms under a forced level, and coverage alone decides a pinned arm. The
gap itself is the same host mechanism the calibration in
`../../20260902T2124Z/` refused slot 3 on.

## E4 as a served effect, over two runs

| run | clock | pairs | mean delta | 95% CI |
| --- | --- | ---: | ---: | --- |
| `served-ab-20260902T2032Z` | auto, regime-gated | 4 | +0.0150 | [-0.0529, +0.0828] |
| this run | manual-gfx1100-fclk933 | 3 of 4 | -0.0257 | (incomplete) |

The two point estimates straddle zero and each run's paired sd is about 4%,
so the served effect of E4 on the 2B at fixed 64 is indistinguishable from
zero and the registered +3.5 to +4.2% prediction is neither confirmed nor
refuted at the 5% promotion bound. E4's first-order ceiling is 4.3% of the
token (`../traffic-balance.md`), below the promotion bound on its own, and
its machine-code receipt stands: VALU 882 to 810, `v_mac_f32` 248 to 152,
longest chain 29 to 17, no VGPR or occupancy change (`../../e1/README.md`).
E4 is retained as a composable component under E4b rather than rerun on its
own. Its Q4_K bracket delta stays unmeasured, because no build carries both
the census instrument and the E4 patch; that build is the one arm E4 still
owes.

## Files

| file | content |
| --- | --- |
| `arms.tsv`, `summary.tsv`, `terminal-state.tsv`, `wall-clock.tsv`, `campaign-inputs.tsv`, `inputs.tsv` | the ledgers the runner wrote |
| `clock-state.tsv` | per-arm delivered clock mode, share, temperature, busy, and sample count |
| `arms/*/clock-sidecar-verdict.txt`, `arms/*/request-window.tsv` | the validator's verdict and request window per arm |
