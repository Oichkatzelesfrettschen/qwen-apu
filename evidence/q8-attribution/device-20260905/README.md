# The 0.8B attribution, closed: Q8_0's mat-vec owns two thirds of the token, and the fixed-cost account is refuted

```text
measurement_status=attribution
calibration_verdict=failed (arm_failures=1, controls incomplete/unresolved)
attribution_arms=18-I1 19-I1 22-I1 23-I1
production_server=70aa78bc0eed708ce8d06b690467affce3bb222014714af4dbd92e00fa5ff010 (served Q8_0 build)
instrumented_server=522e6367f49d5bdabf4d0cfc786b640b6766aad99b27d4f00a1c7d7d799ec8b5 (its census twin)
engine_clock=applied policy=manual sclk_level=2 mclk_level=2 required_sclk_mhz=1100 required_mclk_mhz=933
model=qwen35-08b Q8_0, context 8192, batch 128, ubatch 32, cache k=q8_0 v=q4_0, flash attention on
```

`docs/frontier.md` asks which Q8_0 shapes own the 0.8B decode and how much time
sits outside them. `evidence/q8-attribution/fixed-cost-decomposition.md`
registered five predictions ahead of this run, framed around a class-level
signature: three 0.8B checkpoints (`evidence/model-admission/runtime-class-throughput.md`)
decode within 5.2% of each other while streaming 67.9% apart in bytes, which
that document read as evidence of a per-dispatch fixed cost the 2B and 4B
classes carry at a smaller relative weight. This record answers each
prediction from the executed ledger and refutes the account: the served
Q8_0 mat-vec owns 66.69% of the token on its own, well above either K-quant
class's mat-vec share, and the residue the fixed-cost account needed --
queue-and-host overhead, and the Gated DeltaNet/norm/rotary/attention group
-- both measure small. The 0.8B decodes faster than the 2B and 4B not
because a fixed term saturates, but because its single Q8_0 mat-vec family
is cheap enough, per dispatch, to leave the rest of the graph a bigger share
of a much shorter token.

## What ran

The canary (four arms: P, I0, I1, S) accepted with `ownership=conclusive` on
I1 and zero structure failures. The calibration ran all 25 arms at 1100/933
with `clock_invariant=held` on every sampled arm, replicate count 4, under
`manual-gfx1100-fclk933`. Its own verdict is `failed`: one P arm (slot 16)
was refused on `window_lost_fraction=0.0580` against the 0.03 bound -- the
sampler lost coverage inside the 0.8B's own 3.6 to 3.8 s decode window, a
window short enough that the sidecar's 20 ms period and the census's
retirement bookkeeping compete for the same core more visibly than they do
on the 2B's and 4B's longer windows -- and the three controls read
`unresolved` (sidecar, `ci=[-0.0538,+0.0224]` against a 0.0065 bound;
collect, `ci=[-0.0237,+0.0060]` against a 0.02 bound, mean -0.88%) or
`incomplete` (compile, 3 of 4 surviving pairs, surviving mean -2.40%). No
control licenses an instrument bound in either direction, and none of the
three moves any standing verdict in `../README.md`. The four accepted I1
arms are the attribution record read below, with the C2 collection term
(-0.88%, order "about 1%") stated beside every I1 share as its own
uncertainty rather than folded into it.

## The executed pipeline and its shares

Median of the four I1 arms (18, 19, 22, 23), each a served 64-token decode
of 63 decode graphs:

| quantity | value | evidence |
| --- | --- | --- |
| decode_ms | 3623.26 | median of 3631.20, 3528.76, 3705.33, 3615.32 |
| decode_tok_per_second | 17.40 | same four `summary.json` files |

`mul_mat_vec_q8_0_f32_f32`, the pipeline `pipeline-selection.md` predicted
from source (shared `mul_mat_vec.comp` with `-DDATA_A_Q8_0=1`, specialization
constants `{BLOCK_SIZE=64, NUM_ROWS=2, NUM_COLS=1}`, `SHADER_REDUCTION_MODE_SUBGROUP`),
executes as the `_f32_f32` variant with 40 VGPRs, 48 SGPRs, 0 spilled, 6
subgroups per SIMD, at 187 calls per graph and a 186.4 us median dispatch:

| quantity | value |
| --- | --- |
| exclusive_bracket_ms (median of 4 arms, whole run) | 2416.42 |
| exclusive_bracket_ms per graph | 38.36 |
| share of decode_ms | 66.69% |

The next eight pipelines by exclusive time, same median-of-four basis:

| pipeline | calls/graph | exclusive_ms, whole run | share |
| --- | ---: | ---: | ---: |
| `get_rows_f32_f32` | 37 | 139.94 | 3.86% |
| `gated_delta_net_f32_d128` | 18 | 118.43 | 3.27% |
| `contig_cpy_f32_f32` | 18 | 93.70 | 2.59% |
| `rms_norm_mul_f32` | 73 | 48.48 | 1.34% |
| `concat_i32` | 18 | 34.12 | 0.94% |
| `flash_attn_f32_f16_aligned` | 6 | 22.03 | 0.61% |
| `ssm_conv_silu_f32` | 18 | 20.68 | 0.57% |
| `cpy_f32_f32` | 24 | 19.34 | 0.53% |

Sum of every pipeline's exclusive time (26 pipelines, by id, median of the
four arms): 2993.38 ms, 82.62% of decode_ms. The remainder -- host time and
inter-dispatch queue time no dispatch's bracket covers -- is 629.88 ms,
17.38% of the token.

## Achieved bandwidth

`served-0.8b-q8_0-census.txt` reports `streamed_bytes_per_token=800881920`.
Divided by the Q8_0 mat-vec family's own per-graph exclusive time
(38.36 ms = 0.038356 s):

- **Family achieved bandwidth:** 800881920 / 0.038356 s = 20.88 GB/s, inside
  the family's own dispatches.
- **Whole-token achieved bandwidth:** decode_ms per graph is 57.51 ms
  (3623.26 / 63); 800881920 / 0.057512 s = 13.93 GB/s.

Both read well above the 34.13 GB/s theoretical dual-channel peak's usual
achieved fraction for the 2B and 4B (`evidence/decode-bound-analysis.md`: 8.11
GB/s on the 4B, 10.41 GB/s on the 2B, four-block means) -- the 0.8B's mat-vec
dispatches stream at a higher fraction of peak than either K-quant class does,
which is consistent with Q8_0's one-cast-one-multiply dequant leaving more of
the dispatch's time as memory-bound streaming rather than nibble and
scale-and-minimum arithmetic.

## Three classes, one table

Mat-vec share and the token time outside every mat-vec family, same
median-of-accepted-I1-arms basis for each class (2B: `mul_mat_vec_q4_k_f32_f32`
+ `mul_mat_vec_q6_k_f32_f32`, `evidence/raven2-vulkan-kernel-census/20260902T2124Z/arms/18-I1/`;
4B: same two families, `evidence/raven2-vulkan-kernel-census/q4k-scale-decode/4b-attribution-20260905/`;
0.8B: `mul_mat_vec_q8_0_f32_f32` alone, this record):

| class | decode_ms | mat-vec exclusive_ms | mat-vec share | time outside mat-vec |
| --- | ---: | ---: | ---: | ---: |
| 2B (Q4_K + Q6_K) | 6513 | 5533 (3226 + 2307) | 84.95% | 980 ms, 15.05% |
| 4B (Q4_K + Q6_K) | 18788 | 15849 (10712 + 5137) | 84.36% | 2939 ms, 15.64% |
| 0.8B (Q8_0) | 3623.26 | 2416.42 | 66.69% | 1206.84 ms, 33.31% |

The two K-quant classes agree with each other within 0.6 points and disagree
with the single-format 0.8B class by 18 points. A one-family, one-cast dequant
does not carry a smaller mat-vec share; it carries a much larger one, because
the token itself is short enough (57.5 ms against the 2B's 103.4 ms and the
4B's 298.2 ms per graph) that a 38.4 ms dispatch dominates it the way a
nibble-and-scale dispatch never gets the chance to on the larger classes.

## The five registered predictions, answered

| # | prediction | falsifier | measured | verdict |
| --- | --- | --- | --- | --- |
| Q1 | Q8_0 mat-vec bracket union below the 2B's Q4_K union (51.8 ms) in absolute terms, and below it as a fraction of the 0.8B's own token | a union at or above 51.8 ms refutes the trivial-dequant reading | bracket union 38.65 ms/graph (exclusive 38.36 ms/graph), below 51.8 ms; but its share of the 0.8B's own token is 66.69% against the 2B's Q4_K share of about 49.5% | **refuted** -- the absolute clause holds, but the fractional clause is the substantive one and fails by 17 points: a cheaper-per-weight dequant still ends up owning more of a shorter token |
| Q2 | queue-and-host residue (`queue_non_dispatch_ms_per_graph + residual_ms_per_graph`) reads near the 2B's 3.4 ms, or reads materially higher, which would make it the carrier of the predicted 30-45 ms fixed cost | a value below 1 ms together with an unexplained 30-45 ms gap refutes both accounts | 6.77 ms/graph (queue_non_dispatch 4.73 + residual 2.04, median of 4 arms) | **held**, first branch: 6.77 ms is single-digit like the 2B's 3.4 ms rather than tens of ms -- about double it, not "near" it exactly, but two orders of magnitude short of a 30-45 ms residue. Queue and host overhead is not the fixed-cost carrier |
| Q3 | the Gated DeltaNet/norm/rotary/attention (P3) group owns a larger share of the 0.8B token than it owns of the 2B's (about 9%, `decode-decomposition.md`) | a P3 share at or below the 2B's 9% refutes the narrower-architecture account | 242.74 ms/graph-total (146.94 gated-deltanet-family + 69.58 norm + 2.66 rotary + 23.58 attention) of 3623.26 ms, 6.70% | **refuted** -- 6.70% sits below the 2B's 9%; a narrower embedding width does not tax this group more, it taxes it less |
| Q4 | submits and dispatches per graph land near the ~25 submissions / ~360 dispatches estimated by analogy to the 2B's 24 blocks | a count far outside the estimate means the per-block estimate needs correcting | `submits_per_graph=40` (identical across all four arms) and 658 total dispatches per graph (sum of `calls_per_graph`, by pipeline id) | **refuted** -- 40 submits is 60% above the estimate and 658 dispatches is 83% above it; `attention.head_count_kv=2`, `ssm.group_count=16`, and `ssm.inner_size=2048` make this architecture issue more per-block work than the 2B's shapes, so the per-block dispatch count the estimate assumed does not transfer |
| Q5 | DRAM floor (23.5 ms) plus the mat-vec VALU account (Q1) plus P3 (Q3) plus residue (Q2) sums to within 15% of the observed token's margin above that floor | a sum outside the band means a bracket is double-counted, or an unbracketed family owns the remainder | margin = 57.51 - 23.5 = 34.01 ms/graph; Q1 + Q2 + Q3 alone = 38.36 + 6.77 + 3.85 = 48.98 ms/graph, 44% over the margin | **refuted**, by double-counting: the DRAM floor is not a term separate from the mat-vec dispatch's own exclusive time -- streaming and the dequant-and-dot arithmetic execute inside the same dispatch bracket, so adding a DRAM floor on top of the mat-vec's exclusive time counts the same bytes twice. The mat-vec exclusive time alone (38.36 ms/graph) already exceeds the margin the floor-plus-account framing predicted |

Q1 and Q3 fail in the same direction and for related reasons: Q8_0's cheap
dequant does not translate into a smaller mat-vec footprint or a
correspondingly larger footprint for everything else, because the 0.8B's
token is short enough that whatever the mat-vec pipeline costs per
dispatch dominates the graph regardless of arithmetic complexity per weight.
Q2 and Q4 rule out both alternative carriers the fixed-cost account named:
queue/host overhead stays in the single digits of milliseconds, and the
dispatch count is architecture-driven rather than fixed. The account this
directory registered ahead of the run -- that the 0.8B's flat rate-across-bytes
signature is a per-dispatch cost independent of tensor type -- is refuted by
its own falsifiers.

## Coverage limits

- The three controls (sidecar, compile, collect) all read `unresolved` or
  `incomplete`. None licenses an instrument bound in either direction, and
  none changes any standing verdict in `evidence/raven2-vulkan-kernel-census/README.md`.
  Every I1 share above is read with that absence stated, not with a
  confirmed zero-overhead instrument.
- The collect control (C2, instrumentation collection on/off) reads a mean
  delta of -0.88%, order "about 1%" against a 0.02 (2%) bound, `unresolved`
  rather than `held`. Every I1 share in this record carries that term beside
  it as an unresolved uncertainty rather than a corrected offset.
- One P arm (slot 16) refused on `window_lost_fraction=0.0580` against the
  0.03 bound: the clock sidecar lost 5.8% of its declared window inside the
  0.8B's 3.6 to 3.8 s decode, above the bound the 2B's and 4B's longer
  windows absorb more easily. `clock_invariant=held` on that arm regardless
  (1100/933 sampled at every point the sidecar did cover), so the arm's rate
  is retained in the served-rate ledger but excluded from the sidecar
  control's accepted set.
- Which of `_f32_f32` and `_f16_f32` a served 0.8B decode graph dispatches is
  now settled by this record's own `spirv_executed_sha256` column
  (`f2d4eded...`) rather than by source alone: `_f32_f32` executes, matching
  the variant `pipeline-selection.md` compiled for direct comparison and
  differing from the 2B's own I1 finding, which named the same variant for a
  different reason (`evidence/raven2-vulkan-kernel-census/e1/README.md`).
- The register-allocation and instruction-count fields this record's
  `pipeline-ledger-decode.tsv` carries (VGPRs, SGPRs, spilled VGPRs, LDS,
  subgroups per SIMD) are read directly from the device rather than derived,
  closing the one item `pipeline-selection.md` and `shape-and-receipts.md`
  marked open pending a device.

The frontier's ending condition -- "the executed-path and time-ownership
record is retained with its coverage limits" -- is met. The Q4_K program's
priorities do not transfer as priorities, though its lesson does: on the 4B
the composed Q4_K formulation shortened a dispatch owning 57% of the token by
about 10% and moved the served rate 6.6%
(`../../raven2-vulkan-kernel-census/q4k-scale-decode/4b-kernel-delta-20260905/README.md`),
and the Q8_0 family here owns 67% of a token a fifth as long, so a shader
change of the same relative size on `mul_mat_vec_q8_0_f32_f32` is worth
about 7% of the 0.8B token and nothing else in the graph is worth more than
4%.

The first Q8-specific experiment this record chooses is therefore inside
the mat-vec itself: a kernel-delta bracket on `mul_mat_vec_q8_0_f32_f32` at
its served specialization (`64,2,1`, 40 VGPRs, 6 subgroups per SIMD), the
family that streams at 20.9 GB/s inside its own dispatches, against a
candidate that changes one thing in the Q8_0 dequant-and-dot body. The
largest non-mat-vec owner, `get_rows_f32_f32` at 2.22 ms per graph (3.86%)
over 37 calls, reads f32 sources -- the Q8_0 embedding table would dispatch
`get_rows_q8_0` -- so it is a state or cache gather on the recurrent path,
and attributing those 37 dispatches to their graph nodes is an
executed-path question worth 4% at most, second in line.

## Files

- `canary/`: the four-arm canary (`arms.tsv`, `terminal-state.tsv`,
  `canary-structure.tsv`, the two contracts, `inputs.tsv`,
  `campaign-inputs.tsv`, `wall-clock.tsv`) and per arm the sidecar verdict,
  the request window, the runtime identity, the served summary, and for the
  I1 arm `pipeline-ledger-decode.tsv` and `pipeline-ledger-prefill.tsv`.
- `calibration/`: the 25-arm campaign's ledgers (`arms.tsv`, `summary.tsv`,
  `terminal-state.tsv`, `wall-clock.tsv`, the three contracts, `inputs.tsv`,
  `campaign-inputs.tsv`, `calibration-root.tsv`, `bricks/C0-C3.receipt.tsv`),
  and per arm (`calibration/arms/NN-ARM/`) the sidecar verdict, the request
  window, the runtime identity, the served summary, and for the four I1 arms
  `pipeline-ledger-decode.tsv` and `pipeline-ledger-prefill.tsv`. The raw
  `pipeline-census.tsv` and `clock-sidecar.tsv` records stay on the appliance
  under `results/08b-attribution-20260905T1835Z/`.
- `compute-state-status.txt`, `power-envelope-status.txt`: the live DPM and
  package-power snapshot read before the campaign, retained as context for
  the engine-clock policy stated above rather than as part of the census.
