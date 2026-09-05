# The 4B kernel-delta bracket: the composed Q4_K module is 10% shorter per dispatch than production's

```text
measurement_status=kernel-delta
ab_mode=kernel-delta arm_order=W C K K C C K K C
control_server=522e6367... (production series beneath llama-vulkan-pipeline-census.patch)
candidate_server=4844d0dc... (the same series, the five Q4_K stack patches, and the census patch)
scoreboard_receipt=denominator of ../4b-attribution-20260905/ (server 83684f3c...)
engine_clock=applied policy=manual sclk_level=2 mclk_level=2 required_sclk_mhz=1100 required_mclk_mhz=933
cooldown_deadline_s=240
bracket_verdict=shortened
```

`../4b-attribution-20260905/README.md` named this bracket as its confirmation
and predicted the Q4_K exclusive delta inside [-0.2%, +0.2%]. The prediction
is refuted. Both trees carry the census instrument as their first candidate
member, the runner proved one base-build identity for the pair, and every arm
held `clock_invariant=held` at 1100/933.

## The bracket

`bracket-summary.tsv`, four mirrored pairs:

| role | pipeline | mean delta | nominal 95% interval | deltas | verdict |
| --- | --- | ---: | --- | --- | --- |
| subject | `mul_mat_vec_q4_k_f32_f32` exclusive | -12.16% | [-17.56, -6.76] | -10.26, -10.49, -10.65, -17.25 | shortened |
| null | `mul_mat_vec_q6_k_f32_f32` exclusive | -2.53% | [-11.03, +5.96] | +0.67, -0.15, -0.12, -10.52 | held |
| graph span | queue completion per decode graph | -8.54% | [-13.81, -3.28] | -6.88, -6.51, -7.30, -13.48 | -- |

The fourth control arm (slot 8, 3.036 tok/s) ran degraded: its Q6_K median
dispatch reads 2035 us against 1281 to 1287 us on every other arm, its Q4_K
exclusive time 12.91 s against 11.93 to 11.97 s, and its graph span 321 ms
against 298 to 300 ms, so the fourth pair's Q6_K delta of -10.5% is that arm's
state rather than the shader and the intervals above carry it. Over the three
clean pairs the reading is narrower and the same in sign:

| quantity | production module, 3 arms | composed module, 4 arms | delta |
| --- | ---: | ---: | ---: |
| Q4_K exclusive over 63 decode graphs | 11.934, 11.949, 11.971 s | 10.709, 10.695, 10.696, 10.683 s | -10.5% |
| Q4_K median dispatch | 820.1, 820.6, 820.5 us | 744.3, 744.0, 744.0, 743.5 us | -9.3% |
| Q6_K exclusive | 5.104, 5.125, 5.128 s | 5.138, 5.117, 5.122, 5.102 s | -0.1% |
| graph span per decode graph | 298.9, 298.5, 299.9 ms | 278.3, 279.0, 278.1, 277.8 ms | -6.8% |
| served rate, tok/s | 3.165, 3.197, 3.217 | 3.445, 3.447, 3.487, 3.494 | +8.6% |

The executed modules are the ones the ledgers name: production's
`mul_mat_vec_q4_k_f32_f32` at `a9ac07dd...`, the digest the retained 2B
calibration `../../20260902T2124Z/` carries for the production shader, and the
composed module at `78a576ff...`, the digest `../4b-attribution-20260905/`
carries; the Q6_K module is `d584d6b4...` on both sides. `summary.tsv` reads
the served rate of the instrumented pair at +10.04% [+4.64, +15.43],
`unresolved` against the +5% bound at four pairs with the degraded control
inside it.

## What this corrects

`../served-ab-4b-r2-20260903T2115Z/` is the null the frontier asked about, and
its `inputs.tsv` names the candidate as
`llama-vulkan-q4k-scale-word-select.patch,llama-vulkan-q4k-superblock-loop-licm.patch`
over the eight-member production series: two of the five patches the composed
candidate carries, without `llama-vulkan-q4k-activation-group-sums.patch` and
`llama-vulkan-q4k-activation-sideplane.patch`. The composed stack was never
served on the 4B before 2026-09-05. That run's null is therefore a null for
the two-patch candidate on the 4B, and it stands as such; the reading
`../4b-attribution-20260905/README.md` drew from it -- that the composed
module executes on the 4B and shortens nothing -- assumed the null belonged
to the composed stack, and the bracket here refutes that reading directly:
the composed module's dispatch is about 10% shorter on the 4B's shapes.

The 4B ownership record stands unchanged: the composed module owns 57% of the
4B token and executes as the plain shader name. What changes is the answer to
the frontier's question, which becomes the third of its four: **improved
locally, with a graph effect** -- the 4B graph span shortens by 6.8 to 8.5%
and the instrumented served rate rises about 9%. The served comparison of the
uninstrumented builds, production `70aa78bc...` against the composed serving
build `83684f3c...` on the 4B under the registered `W C K K C C K K C`, is
the promotion-relevant reading and is recorded in `../README.md` beside this
directory.

## Files

`arms.tsv`, `bracket-summary.tsv`, `summary.tsv`, `inputs.tsv`,
`campaign-inputs.tsv`, `terminal-state.tsv`, `wall-clock.tsv`, and per arm
the sidecar verdict, request window, both pipeline ledgers, and the served
summary. The raw `pipeline-census.tsv` and `clock-sidecar.tsv` records stay on
the appliance under `results/4b-kernel-delta-20260905T1720Z/`.
