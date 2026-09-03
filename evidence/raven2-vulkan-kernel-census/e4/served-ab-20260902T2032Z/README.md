# E4 served A/B: the first run against a production control

```text
measurement_status=diagnostic
served_ab=unresolved
control_server_sha256=5dd86b90154f6143a5303efd2590b9268a0a5e3e908c4d6791f1fde03a4782c2
candidate_server_sha256=7d9df19f846f0696445b55fed138d7d743d8a315ac0e238d34d023c6f94026b7
candidate_series=llama-vulkan-q4k-activation-group-sums.patch
runtime_tree_git_head=239af7052913a659856a5626c00d8bee7ea970c1
engine_clock=applied policy=manual sclk_level=2 required_sclk_mhz=1100 mclk_floor_mhz=933
```

This is the first `remote/run-served-binary-ab.sh` pass to complete against
`evidence/raven2-vulkan-kernel-census/e4/served-ab-design.md`'s registered
prediction. The 1556Z calibration link's own served A/B attempt refused at
launch on an empty `candidate_series` manifest read as an error rather than as
the empty selection; that remedy is applied here, and `candidate_series` names
`llama-vulkan-q4k-activation-group-sums.patch`, the E4 patch, throughout.

## Arms

`inputs.tsv` records the mirrored quadruple `C K K C` opened by one warmup on
the control server (`W`), all nine arms run under the manual engine-clock
policy at `sclk_level=2` (1100 MHz) with the mclk floor at 933 MHz.
`arms.tsv` and `clock-state.tsv` carry the per-arm rate and clock state:

| slot | arm | tok/s | sclk_mode_mhz | mclk_mode_mhz | sclk_share |
| --- | --- | ---: | ---: | ---: | ---: |
| 0a | W | 9.231 | 1100 | 933 | 1.0000 |
| 1 | C | 9.714 | 1100 | 933 | 1.0000 |
| 2 | K | 9.641 | 1100 | 933 | 1.0000 |
| 3 | K | 9.414 | 1100 | 933 | 1.0000 |
| 4 | C | 9.744 | 1100 | 933 | 1.0000 |
| 5 | C | 9.425 | 1100 | 933 | 1.0000 |
| 6 | K | 9.935 | 1100 | 933 | 1.0000 |
| 7 | K | 9.738 | 1100 | 933 | 1.0000 |
| 8 | C | 9.300 | 1100 | 933 | 1.0000 |

All nine arms held the graphics clock at 1100 MHz with `sclk_share=1.0000`
and the fabric clock at 933 MHz; no arm reads `clock_invariant=violated` and
no arm falls outside the engine-clock policy's own band, so every pair
compares control and candidate at one selected clock. All nine arms complete
(`arm_failures=0`).

## Verdict

`summary.tsv` carries one control, `served-ab`, over four `C K` replicate
pairs:

```text
pair	control	outer	inner	replicates	mean_delta	sd_delta	ci_low	ci_high	verdict
1	served-ab	C	K	4	+0.0150	0.0426	-0.0529	+0.0828	unresolved
```

The four paired deltas are -0.0075, -0.0339, +0.0541, and +0.0471, all four
pairs at the same selected clock (`1100/1100` on every line), so the mean and
interval carry no clock-regime contamination. `terminal-state.tsv` reads
`served_ab=unresolved mean_delta=+0.0150 ci_low=-0.0529 ci_high=+0.0828
comparable_pairs=4 arm_failures=0`.

## Read against the registered prediction

`served-ab-design.md` registers the band **+3.5% to +4.2%** and the verdict
**`refuted` or `unresolved`** ahead of this run, from an 8.2% whole-shader
VALU issue reduction over a Q4_K mat-vec family the design places at about
52 of the 2B's 101 ms token. The verdict matches: `unresolved` is one of the
two registered outcomes. The mean, +1.50%, sits inside the registered band's
own falsifier region on the low side -- `served-ab-design.md` states a mean
below +3% meets the E4 ladder's falsifier in `decode-decomposition.md` and
refutes the operation-count model for this term -- but the confidence
interval `[-0.0529, +0.0828]` still contains the whole +3.5% to +4.2% band, so
the run does not refute the model on this replicate count; it fails to
resolve it.

The paired standard deviation is 0.0426, close to the 4% of uncontrolled
spread this machine carries on a repeated depth-0 rate at a pinned clock
(`evidence/measurement-state-and-memory-clock.md`). Every pair here holds the
clock fixed at 1100/1100, so the clock is not the source of that spread: it is
the machine's own scatter with the DPM step removed, the same scatter class
`served-ab-design.md` cites when it sets the interval half-width at four
replicates to `t(3)/sqrt(4) = 1.591` sample standard deviations. Resolving a
3.5% to 4.2% effect against a 4.26% paired standard deviation needs either
more replicates -- the half-width falls as `1/sqrt(n)`, so eight replicates
roughly halve it to about 2.1 percentage points and would place a true +4%
effect outside a null interval -- or the remaining scatter source identified
and controlled, since halving the interval by replication alone assumes the
scatter is patternless rather than driven by a variable this design does not
yet track.

## Retention

Retained: `arms.tsv`, `campaign-inputs.tsv`, `inputs.tsv`, `summary.tsv`,
`terminal-state.tsv`, `wall-clock.tsv`, `clock-state.tsv`, and every one of
the nine arms' `clock-sidecar-verdict.txt` and `request-window.tsv`
(`0a`, `1` through `8`). `clock-state.tsv` is computed the way the census
calibration links compute their own: from each arm's `clock_state=measured`
line in its own `clock-sidecar-verdict.txt`. `wall-clock.tsv` puts
`cooldown_timeouts=9` -- every one of the nine arms' cooldowns reached its
30 s deadline rather than an earlier quiescence reading, the same regime the
2011Z calibration link's `cooldown_timeouts=26` shows and the same registered
cause: the quiescence predicate wants a step below the highest clock and the
manual policy pins the highest. Paths are rewritten to `$HOME` and the host to
`qwen-laptop`.
