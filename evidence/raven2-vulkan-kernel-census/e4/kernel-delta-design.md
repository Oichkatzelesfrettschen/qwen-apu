# Kernel-delta: E4 judged by the Q4_K bracket, registered ahead of the run

Three served comparisons of the production bundle against the E4 build
(`served-ab-20260902T2032Z`, `2139Z`, `2222Z`) were decided by the host: a
paired sd of about 4% under `auto`, one 113 ms sampler gap under the pinned
clock, and three coverage refusals under host load 5 to 7. E4 changes one
shader (`mul_mat_vec_q4_k.comp`, with the same hoist in `q5_k`), so the
question it can answer is whether the Q4_K mat-vec got shorter, and the
instrument that reads that is the pipeline census: a device timestamp pair
around each dispatch inside a submitted graph, which a host stall between
submissions does not move.

## The comparison

`run-served-binary-ab.sh` under `QWEN_CENSUS_AB_MODE=kernel-delta` runs
`W C K K C` four times with the census collecting in every arm:

| role | build | candidate series | server |
| --- | --- | --- | --- |
| C | census v7, `raven2-vulkan-census` | `llama-vulkan-pipeline-census.patch` | `addcae10...` |
| K | census + E4, `raven2-vulkan-census` | `llama-vulkan-pipeline-census.patch,llama-vulkan-q4k-activation-group-sums.patch` | built by chain nineteen |

Both carry `instrumentation pipeline-census-v3` from the same patch
(`53fbe4d6...`), the receipt is verified against the production bundle the
scoreboard was written over, and the two builds decode under the receipt's
tuple at `manual-gfx1100-fclk933`. The two-patch replay verifies on the
workstation with `candidate_series_sha256=42fc4ac1...`.

`summarize-bracket-ab.py` reads each arm's `pipeline-ledger-decode.tsv`,
takes `exclusive_bracket_ms` of the subject and the null pipeline, forms the
paired delta K/C - 1 per pair, and judges the nominal 95% t interval over
the pairs:

```text
subject  mul_mat_vec_q4_k_f32_f32   the pipeline E4 rewrites
null     mul_mat_vec_q6_k_f32_f32   a pipeline E4 leaves untouched, read from the same graphs
bound    0.02
identity every K reply's content and predicted_n equal to its C reply's
```

Chain seventeen's four I1 arms put the Q4_K exclusive bracket at 3225.8 ms
over 63 decode graphs, 51.2 ms per token, and Q6_K at about half of that.

## Predictions and falsifiers, stated before the run

E4's machine-code receipt reads VALU 882 to 810, `v_mac_f32` 248 to 152,
longest chain 29 to 17, VGPR and occupancy unchanged. The first-order
opportunity of 4.16 ms per token (`traffic-balance.md`) is 8.1% of the Q4_K
bracket. The kernel streams weights at about 10 GB/s of a 34 GB/s peak, so it
is not purely bandwidth-bound and an issue reduction can reach the bracket.

| outcome | reading | consequence |
| --- | --- | --- |
| subject `shortened`, interval inside -2% to -10% | the hoisted work was on the limiting path | E4 is a composable component; E4b proceeds on the remaining 8.3 ms |
| subject `unchanged` | the removed issue was not on the limiting path; the mat-vec is bound elsewhere | E4 closes; E4b's issue-count model is refuted for this kernel and the next lever is traffic or occupancy |
| subject `lengthened` | the rewrite lengthened the dependency chain the compiler schedules | E4 closes |
| subject `unresolved` at four pairs | the bracket scatter exceeds 2% | the bracket is not the low-noise metric assumed; report the sd and stop |
| null other than `held` | the machine state moved between arms | the run measured the host; rerun |
| `token_identity` other than `held` | the shorter kernel computes something else | E4 is quarantined ahead of any throughput claim |

The whole-token rate is retained beside the bracket as the reading under
instrumentation, with the sidecar column stating which arms lost coverage;
it decides nothing here.
