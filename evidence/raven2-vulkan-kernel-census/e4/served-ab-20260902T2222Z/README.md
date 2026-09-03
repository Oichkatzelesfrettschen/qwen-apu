# E4 served A/B under manual-gfx1100-fclk933: the host under load 5 to 7

```text
measurement_status=diagnostic
acquisition_head=8e852f8d19740f7c478fd3212c39580cf5cd7921
served_ab_verdict=failed
control_server_sha256=5dd86b90154f6143a5303efd2590b9268a0a5e3e908c4d6791f1fde03a4782c2
candidate_server_sha256=7d9df19f846f0696445b55fed138d7d743d8a315ac0e238d34d023c6f94026b7
engine_clock=applied policy=manual sclk_level=2 mclk_level=2 required_sclk_mhz=1100 required_mclk_mhz=933
clock_state_name=manual-gfx1100-fclk933
stall_bound_ms=250
```

The third served comparison of the production bundle against the E4 build,
run under the stall bound that follows the policy. Every arm held the clock
pair on every sample (`clock-state.tsv`); three arms were refused on
coverage alone.

| slot | arm | tok/s | lost fraction | host load1 during the arm | status |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | C | 9.233 | 0.0063 | | completed |
| 2 | K | 9.009 | 0.0225 | | completed |
| 3 | K | 8.911 | 0.0056 | 4.8 to 5.8 | completed |
| 4 | C | 7.255 | 0.0730 | 5.6 to 7.3 | failed, `window_lost` |
| 5 | C | 7.108 | 0.0767 | 6.8 to 7.4 | failed, `window_lost` |
| 6 | K | 9.104 | 0.0000 | 5.7 to 6.2 | completed |
| 7 | K | 9.320 | 0.0431 | | failed, `window_lost` |
| 8 | C | 9.461 | 0.0093 | | completed |

The `# host` lines of the slot 3 through 6 sidecar records carry `load1`
between 4.8 and 7.4 on a two-core machine and `ksm_pages_sharing` rising
from 207343 to 216606 across four arms, about 40 pages merged per second, so
the guest was running a burst and the KSM scanner was merging its pages
while these arms decoded. The two arms at 7.1 and 7.3 tok/s are the arms
that lost 7% of their samples; the sampler and the server were held off the
core by the same tenants. The run started 12 s after the repository gate
finished, so the gate's own load was decaying into it as well.

This is the third served E4 comparison in a row decided by the host rather
than by the binaries, and the reason the kernel-delta mode reads a GPU
bracket instead: a device timestamp inside a submitted graph is not moved by
a stall between submissions, and under a pinned clock a coverage refusal
with the invariant held keeps the arm for the bracket while its tok/s reads
beside a `refused` sidecar column.

## Files

| file | content |
| --- | --- |
| `arms.tsv`, `summary.tsv`, `terminal-state.tsv`, `wall-clock.tsv`, `campaign-inputs.tsv`, `inputs.tsv` | the ledgers the runner wrote |
| `clock-state.tsv` | per-arm delivered clock mode, share, temperature, busy, and sample count |
| `arms/*/clock-sidecar-verdict.txt`, `arms/*/request-window.tsv` | the validator's verdict and request window per arm |
