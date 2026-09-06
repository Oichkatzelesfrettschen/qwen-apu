# The 0.8B attribution, closed: Q8_0's mat-vec owns two thirds of the token, and the registered fixed-cost account is refuted

```text
measurement_status=attribution
record_class=diagnostic attribution with unbounded instrument perturbation
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
prediction from the executed ledger and refutes that registered account:
`mul_mat_vec_q8_0_f32_f32` is the dominant individual pipeline of the 0.8B
decode graph at 66.69% of the token, above the 2B's Q4_K family read alone
(49.53%) and below the two K-quant families read together (2B 84.95%, 4B
84.35%), and the residue the fixed-cost account needed -- queue-and-host
overhead, and the Gated DeltaNet/norm/rotary/attention group -- both
measure small. What the three-class comparison states is the complement:
work outside the mat-vec families occupies 33.31% of this shorter token
against 15.05% on the 2B and 15.64% on the 4B.

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
collect, `ci=[-0.0237,+0.0060]` against a 0.02 bound) or `incomplete`
(compile, 3 of 4 surviving pairs, surviving mean -2.40%), all four figures
verbatim from `calibration/summary.tsv`. No control licenses an instrument
bound in either direction, and none of the three moves any standing verdict
in `../README.md`. The four accepted I1 arms are the attribution record read
below, and the record's class is diagnostic attribution with unbounded
instrument perturbation: the collect control's interval spans its bound, so
its point estimate is a sample of an unresolved comparison rather than an
error bar any share below carries.

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

The median dispatch and the family total are distinct quantities and the
ownership arithmetic uses the summed exclusive durations alone. Multiplying
the 186.4 us median by 187 calls gives 34.86 ms per graph against the
family's own 38.36 ms per graph (2416.42 / 63), because the distribution has
a long upper tail: `pipeline-ledger-decode.tsv` carries p90 315.8 us, p99
326.4 us, and max 13597.8 us on arm 18-I1, so one representative dispatch
loses the information the sum keeps. A Q8 comparison that wants the shape
split -- a first dispatch of a submit against a later one, a wide row block
against a narrow one -- needs the per-dispatch rows rather than this ledger,
which carries one row per pipeline; those rows stay in the raw
`pipeline-census.tsv` on the appliance under
`results/08b-attribution-20260905T1835Z/`.

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

Sum of every pipeline's exclusive time (25 pipelines, by id, median of the
four arms): 2993.38 ms, 82.62% of decode_ms, so 629.88 ms and 17.38% of the
token sit outside every dispatch's exclusive bracket.

## What the 17% outside every dispatch contains

That remainder is a subtraction of exclusive pipeline time from served
decode time, so it holds every quantity the exclusive brackets exclude,
starting with the ambiguous overlap the ledger reports separately. Built
per arm from that arm's own `graphs` row of `pipeline-ledger-decode.tsv`
and its `summary.json` `decode_ms`, the token divides into five terms that
close the arithmetic (all values ms per decode graph, `decode_ms` over the
63 graphs of a 64-token reply):

| arm | exclusive | ambiguous overlap | queue span outside the bracket union | retirement beyond queue span | served time beyond retirement | total | decode_ms/63 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 18-I1 | 47.538 | 0.608 | 4.529 | 2.868 | 2.095 | 57.638 | 57.638 |
| 19-I1 | 47.460 | 0.605 | 3.569 | 2.075 | 2.302 | 56.011 | 56.012 |
| 22-I1 | 47.523 | 0.607 | 5.605 | 2.007 | 3.074 | 58.816 | 58.815 |
| 23-I1 | 47.515 | 0.607 | 4.938 | 1.941 | 2.384 | 57.385 | 57.386 |

The first three columns are ledger fields --
`exclusive_ms_per_graph`, `ambiguous_overlap_ms_per_graph`, and
`queue_non_dispatch_ms_per_graph`, the last of which is
`queue_completion_span_ms_per_graph` minus `bracket_union_ms_per_graph`, an
identity the retained values reproduce to rounding. The fourth is
`retire_span_ms_per_graph` minus `queue_completion_span_ms_per_graph`, which
is the definition `../fixed-cost-decomposition.md` gives
`residual_ms_per_graph`, so the ledger already carries that column under its
own name. The fifth is `decode_ms / 63` minus `retire_span_ms_per_graph` and
has no ledger field of its own. The bases differ between this table and the
82.62% above it: the share is a median of medians over the four arms, where
each bridge row is one arm's own reading, so arm 18-I1 puts exclusive time
at 82.48% of its own token and its 25 pipeline medians sum to 47.51 ms per
graph against its own graph row's 47.538.

The instrument's own retained cost sits outside the span chain and inside
the last term. `record_ms_per_graph`, `readback_ms_per_graph`, and
`dispatch_row_emit_ms_per_graph` are census bookkeeping fields rather than
members of the bracket-to-served-time sequence, and the census places its
host cost after fence retirement, so on arm 18-I1 the 0.048 ms readback and
0.198 ms row emit land within the 2.095 ms served-time term, about 12% of
it. That is the retained part of the perturbation the controls leave
unbounded, not its measure.

The bridge closes to a thousandth of a millisecond on every arm, and that
is all it establishes. Vulkan timestamps delimit execution-stage intervals
-- a top-of-pipe write ahead of each dispatch and an all-commands write
after it -- so a bracket bounds queue residency rather than measuring
arithmetic occupancy, and the differences between successive spans are not
proven to be independent serial costs or uniquely attributable CPU phases.
The terms name where the arithmetic goes, not what a processor was doing.

## Logical bytes over a measured interval

`served-0.8b-q8_0-census.txt` reports `streamed_bytes_per_token=800881920`,
the logical weight bytes an ordinary load reads once per token. Divided by a
measured interval it gives a comparison figure, and each figure names its
own denominator:

- **Over the Q8_0 mat-vec family's exclusive time** (38.36 ms per graph):
  800881920 / 0.038356 s = 20.88 GB/s.
- **Over the whole token** (57.51 ms per graph, 3623.26 / 63): 800881920 /
  0.057512 s = 13.93 GB/s.

Neither is a memory-controller counter. The numerator is a census of tensor
bytes rather than a read of transferred bytes, so cache hits, KV traffic,
activation traffic, and any refetch inside a dispatch all sit outside it,
and neither figure states that the memory system reached a ceiling.

The comparable figure against `evidence/decode-bound-analysis.md`'s 8.11
GB/s on the 4B and 10.41 GB/s on the 2B is the whole-token 13.93 GB/s, since
those two are whole-token four-block means; the 20.88 GB/s carries a
family-interval denominator and compares to neither. On the matched
whole-token basis the 0.8B moves more logical bytes per second than either
K-quant class, which restates that its token is short rather than
establishing where in the memory system the difference arises.

## Three classes, one table

Mat-vec share and the token time outside every mat-vec family. Each class
carries its own basis, which the three campaigns' own accepted sets fix
rather than a shared rule: the 0.8B row is the median of four accepted I1
arms of this record; the 4B row the median of the three accepted I1 arms
(18, 19, 23) of
`evidence/raven2-vulkan-kernel-census/q4k-scale-decode/4b-attribution-20260905/`,
whose 22-I1 the census reader refused; the 2B row the one retained I1 arm 18
of `evidence/raven2-vulkan-kernel-census/20260902T2124Z/`. The 2B
denominator is that arm's `predicted_ms` from `arms.tsv` where the other two
are `decode_ms` from `summary.json`; both campaigns compute `tok_s` as 64
tokens over that same quantity, so the two names read one served decode
interval.

| class | mat-vec families | decode_ms | mat-vec exclusive_ms | mat-vec share | time outside mat-vec |
| --- | --- | ---: | ---: | ---: | ---: |
| 2B | Q4_K + Q6_K | 6513.24 | 5533.32 (3225.84 + 2307.48) | 84.95% | 979.93 ms, 15.05% |
| 4B | Q4_K + Q6_K | 18788.43 | 15848.64 (10712.01 + 5136.64) | 84.35% | 2939.79 ms, 15.65% |
| 0.8B | Q8_0 | 3623.26 | 2416.42 | 66.69% | 1206.84 ms, 33.31% |

Read the last column rather than the fourth. Q8_0 is the dominant individual
pipeline of its graph, and its single-family share exceeds the 2B's Q4_K
family read alone, 66.69% against 3225.84 / 6513.24 = 49.53%; against the
two K-quant families summed it is 18 points smaller. What separates the
classes is therefore the complement: work outside the mat-vec families
occupies 33.31% of the 0.8B token against 15.05% and 15.65%, on a token
short enough (57.51 ms against the 2B's 103.38 ms and the 4B's 298.23 ms per
graph) that the same non-mat-vec dispatch inventory buys a fifth of the
graph rather than a sixth of a much longer one.

## The five registered predictions, answered

| # | prediction | falsifier | measured | verdict |
| --- | --- | --- | --- | --- |
| Q1 | Q8_0 mat-vec bracket union below the 2B's Q4_K union (51.8 ms) in absolute terms, and below it as a fraction of the 0.8B's own token | a union at or above 51.8 ms refutes the trivial-dequant reading | bracket union 38.65 ms/graph (exclusive 38.36 ms/graph), below 51.8 ms; but its share of the 0.8B's own token is 66.69% against the 2B's Q4_K share of about 49.5% | **refuted** -- the absolute clause holds, but the fractional clause is the substantive one and fails by 17 points: a cheaper-per-weight dequant still ends up owning more of a shorter token |
| Q2 | queue-and-host residue (`queue_non_dispatch_ms_per_graph + residual_ms_per_graph`) reads near the 2B's 3.4 ms, or reads materially higher, which would make it the carrier of the predicted 30-45 ms fixed cost | a value below 1 ms together with an unexplained 30-45 ms gap refutes both accounts | 6.77 ms/graph (queue_non_dispatch 4.73 + residual 2.04, median of 4 arms) | **held**, first branch: 6.77 ms is single-digit like the 2B's 3.4 ms rather than tens of ms -- about double it, not "near" it exactly, but two orders of magnitude short of a 30-45 ms residue. Queue and host overhead is not the fixed-cost carrier |
| Q3 | the Gated DeltaNet/norm/rotary/attention (P3) group owns a larger share of the 0.8B token than it owns of the 2B's (about 9%, `decode-decomposition.md`) | a P3 share at or below the 2B's 9% refutes the narrower-architecture account | 242.74 ms/graph-total (146.94 gated-deltanet-family + 69.58 norm + 2.66 rotary + 23.58 attention) of 3623.26 ms, 6.70% | **refuted** -- 6.70% sits below the 2B's 9%; a narrower embedding width does not tax this group more, it taxes it less |
| Q4 | submits and dispatches per graph land near the ~25 submissions / ~360 dispatches estimated by analogy to the 2B's 24 blocks | a count far outside the estimate means the per-block estimate needs correcting | `submits_per_graph=40` (identical across all four arms) and 658 total dispatches per graph (sum of `calls_per_graph`, by pipeline id) | **refuted** -- 40 submits is 60% above the estimate and 658 dispatches is 83% above it; `attention.head_count_kv=2`, `ssm.group_count=16`, and `ssm.inner_size=2048` make this architecture issue more per-block work than the 2B's shapes, so the per-block dispatch count the estimate assumed does not transfer |
| Q5 | DRAM floor (23.5 ms) plus the mat-vec VALU account (Q1) plus P3 (Q3) plus residue (Q2) sums to within 15% of the observed token's margin above that floor | a sum outside the band means a bracket is double-counted, or an unbracketed family owns the remainder | margin = 57.51 - 23.5 = 34.01 ms/graph; Q1 + Q2 + Q3 alone = 38.36 + 6.77 + 3.85 = 48.98 ms/graph, 44% over the margin | **refuted**, by double-counting: the DRAM floor is not a term separate from the mat-vec dispatch's own exclusive time -- streaming and the dequant-and-dot arithmetic execute inside the same dispatch bracket, so adding a DRAM floor on top of the mat-vec's exclusive time counts the same bytes twice. The mat-vec exclusive time alone (38.36 ms/graph) already exceeds the margin the floor-plus-account framing predicted |

What these four verdicts refute is the specific account
`fixed-cost-decomposition.md` registered -- that the 0.8B's flat
rate-across-bytes signature is a per-dispatch cost independent of tensor
type -- through the falsifiers that document wrote for it. Each verdict
carries a narrower reading than the account's own framing invites.

Q1 and Q3 fail in the same direction: Q8_0's cheap dequant does not
translate into a smaller mat-vec footprint or a correspondingly larger
footprint for everything else, because the 0.8B's token is short enough that
whatever the mat-vec pipeline costs per dispatch dominates the graph
regardless of arithmetic complexity per weight. Q3's outcome is a
measurement of one family group on one architecture; a fractional-ownership
prediction failing for the P3 group establishes that group's share and
nothing about a universal bandwidth mechanism setting the rate.

Q4 refutes the estimated dispatch inventory rather than per-dispatch
overhead as such: 40 submits and 658 dispatches against ~25 and ~360 says
the per-block estimate carried over from the 2B does not transfer to this
architecture, which leaves the cost of a dispatch unmeasured in either
direction. Q2 is the reading that bears on the carrier, and it bounds it:
queue and host residue reads 6.77 ms per graph rather than the 30 to 45 ms
the account needed.

Q5 refutes the additive model rather than the floor. A DRAM floor computed
from streamed bytes and a mat-vec exclusive bracket are not separable terms,
because memory service for those bytes happens inside that bracket, so
summing them counts the same traffic twice; the arithmetic fails for that
reason and states nothing about whether a bandwidth floor of that size
exists.

## Coverage limits

- The three controls (sidecar, compile, collect) all read `unresolved` or
  `incomplete`. None licenses an instrument bound in either direction, and
  none changes any standing verdict in `evidence/raven2-vulkan-kernel-census/README.md`.
  Every I1 share above is read with that absence stated, not with a
  confirmed zero-overhead instrument.
- The collect control (C2, instrumentation collection on/off) reads
  `ci=[-0.0237,+0.0060]` against a 0.02 bound and `unresolved` rather than
  `held`, because that interval spans the bound. An unresolved comparison
  supplies no error bar, so every I1 share in this record stands with the
  instrument's perturbation unbounded rather than with a stated term
  subtracted from or added to it.
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
change of the same relative size on `mul_mat_vec_q8_0_f32_f32` moves 38.36 x
0.10 = 3.84 ms of a 57.51 ms token, 6.7%, and nothing else in the graph is
worth more than 4%.

The same lever read from a planning target rather than from the 4B
precedent: reaching a 50 ms token from the diagnostic 57.51 ms one needs
7.51 ms removed, and taken entirely from the 38.36 ms Q8_0 family that is a
19.6% local reduction. Both figures describe one shader and one token; the
6.7% is what a 4B-sized delta buys, the 19.6% is what a 50 ms token would
demand of it. The 57.51 ms denominator is the instrumented I1 token under
controls that closed neither the sidecar nor the collect comparison, so the
figure is a conditional planning estimate rather than a production target,
and a production number comes from a served A/B under a bound instrument.

`shape-selection.md` re-keys this record's own brackets by tensor and names
the dispatch that experiment aims at: the tied output projection
`token_embd.weight`, one dispatch of 124160 workgroups holding 12.719 of the
family's 38.355 ms per graph, 33.16% of the family and 22.12% of the token.
`../q8-kernel-delta-design.md` registers the mechanism and both falsifiers.

The first Q8-specific experiment this record chooses is therefore inside
the mat-vec itself: a kernel-delta bracket on `mul_mat_vec_q8_0_f32_f32` at
its served specialization against a candidate that changes one thing in the
Q8_0 dequant-and-dot body. The mechanism receipt preserves the baseline this
record measures -- `mul_mat_vec_q8_0_f32_f32`, specialization constants
`64,2,1`, subgroup 64, 40 VGPRs, 48 SGPRs, zero spilled VGPRs, 6 subgroups
per SIMD, 187 calls per graph -- and a candidate is read against every one
of those fields rather than against its rate alone. A larger row tile is the
obvious candidate and the one this baseline argues caution about: raising
NUM_ROWS raises register pressure, and 6 subgroups per SIMD at 40 VGPRs is
the occupancy that hides this shader's memory latency, so a formulation that
falls to fewer resident subgroups can lose more to exposed latency than it
gains in reuse. The
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
