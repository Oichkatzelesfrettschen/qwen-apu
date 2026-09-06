# The registered Q8_0 kernel delta: four rows per workgroup on the tied output head

```text
measurement_status=registration, no arm run
subject_pipeline=mul_mat_vec_q8_0_f32_f32 constants=64,2,1 vgprs=40 sgprs=48 spilled=0 lds=0 subgroups_per_simd=6
subject_shape=token_embd.weight ne0=248320 workgroups=124160 calls_per_graph=1 exclusive=12.719 ms/graph
candidate_constants=64,4,1
source=ggml/src/ggml-vulkan/ggml-vulkan.cpp at c2c62855c14130a4b42b76de0c01d46209f7a7fa
ab_mode=kernel-delta arm_order=W C K K C C K K C
```

`device-20260905/shape-selection.md` splits the 187 Q8_0 mat-vec dispatches
of a decode graph into thirteen shapes and finds one dispatch holding 12.719
of the family's 38.355 ms per graph: the tied output projection
`token_embd.weight`, 248320 rows over 1024 columns, issued as 124160
workgroups. This document registers one source-level mechanism against that
shape, its compiler-visible falsifier in the shader lab, and its bracket
falsifier on the device, ahead of either run.

## The mechanism

`ggml_vk_load_shaders` sets the rows each mat-vec workgroup computes per
type. On an `AMD_GCN` device it raises `rm_stdq` to 2 and `rm_kq` to 4, and
the Q8_0 `_f32_f32` pipeline is created with `{1*rm_stdq, 1, 1}` where every
other legacy quant from Q1_0 through Q5_1 is created with `{2*rm_stdq, 1, 1}`
(`ggml-vulkan.cpp:5328-5334`). Q8_0 is therefore the one legacy quant this
device builds at two rows per workgroup rather than four, and the census
confirms the constant it executes: `64,2,1`.

The candidate creates the `_f32_f32` Q8_0 pipeline at `{2*rm_stdq, 1, 1}`
with the matching `{wg_size_subgroup, 2*rm_stdq, i+1}` specialization, so
the served shader compiles at `{BLOCK_SIZE=64, NUM_ROWS=4, NUM_COLS=1}` and
each workgroup computes four output rows. The head's dispatch then launches
62080 workgroups rather than 124160.

The argument is wave residency rather than bytes. `mul_mat_vec.comp` hoists
its two `data_b_v4` reads above the `[[unroll]] for n` row loop, so the
activation vector is already read exactly once per workgroup at any
`NUM_ROWS`; the head's 4 KB of activations sit inside the device's 1 MiB L2
and reach DRAM once. Weight traffic is unchanged, and the shape already
streams at 21.24 GB/s against the family's 20.88, so it is the family's best
streamer rather than a victim of redundant fetch. What is anomalous is the
work per wave: with `K_PER_ITER = 8` at `QUANT_R == 1`, a 64-lane workgroup
covers 512 columns per iteration, so the head's 1024-column rows run exactly
two iterations. Each of the 124160 waves issues about twenty vector-memory
operations and retires, and over two compute units at four SIMDs that is
15520 waves per SIMD in 12.719 ms with six resident, about 4.9 us of
residency each. Doubling the rows halves the wave count while doubling each
wave's iterations of useful accumulation, which is a launch-and-latency
lever on the one shape in the table that has 124160 launches to amortize.

This is not the Q4_K row-count argument. That program raised rows to
amortize a super-block scale decode whose cost is per block and independent
of the rows it feeds; Q8_0 decodes one `float16_t` scale per 32-element block
and its `get_dm` returns a zero minimum, so there is no scale arithmetic to
amortize here and none is claimed. The claim is about how many waves the
device launches for one dispatch and how long each one lives.

### The register budget, and the price of losing the baseline

The served pipeline reads 40 VGPRs, 0 spilled, and 6 subgroups per SIMD,
which is the VGPR-limited occupancy on this part (256 VGPRs per SIMD lane
slot divided by 40). That baseline is not preserved by this candidate and
the loss is priced rather than assumed away.

The in-record anchor is pipeline id 5, the same shader compiled at
`{64, 2, 2}`, which the census describes at 48 VGPRs and 5 subgroups per
SIMD. It bounds the magnitude loosely rather than predicting it: an extra
column doubles `temp` and the two `bv` vectors, while an extra pair of rows
doubles `temp` and the per-row `v`/`v2` dequant vectors and leaves the `bv`
pair alone, so the two deltas are different.

The price is stated in rows in flight per SIMD, which is the quantity the
mechanism moves:

| pipeline | VGPRs | waves per SIMD | rows per wave | rows in flight per SIMD |
| --- | ---: | ---: | ---: | ---: |
| served `64,2,1` | 40 | 6 | 2 | 12 |
| candidate at 5 waves | 44 to 51 | 5 | 4 | 20 |
| candidate at 4 waves | 52 to 64 | 4 | 4 | 16 |
| candidate at 3 waves | 65 to 85 | 3 | 4 | 12 |

The band the lab admits is 44 to 64 VGPRs, the union of the two regimes that
hold more rows in flight than the baseline.

At five or four waves the candidate holds more rows in flight than the
baseline despite fewer resident waves, which is the condition the mechanism
needs. At three waves it holds exactly the baseline's rows with half the
wave-level parallelism to hide latency with, and the arm is refused in the
lab rather than run.

## Falsifier 1: compiler-visible, in the shader lab

`remote/compile-q8-mat-vec-spv.sh` already emits the served Q8_0 mat-vec
SPIR-V at this device's own specialization, and
`remote/raven2-shader-lab/q8-mat-vec-receipt.sh` runs `lab.sh` and `depth.py`
over it under the naming `evidence/raven2-vulkan-kernel-census/e1/` uses.
`--num-rows` states the count: the control runs at the served `{64, 2, 1}` and
the candidate at `{64, 4, 1}`, and both roles read one SPIR-V module so the
delta is the specialization alone.

One module serves both because `mul_mat_vec_base.glsl:90` declares
`layout (constant_id = 1) const uint NUM_ROWS = 1`. The row count therefore
reaches the compiler at pipeline creation rather than through the glslc
frontend, and the two arms share a module digest by construction.

That decides where the arm runs, and it is a stronger constraint than the
gfx902 backend alone. `--spirv-only` closes the module identity anywhere,
including this workstation, because `spirv-dis` and the SHA-256 need no
driver -- and it applies no specialization at all, so a `--spirv-only` pair
taken at two row counts is one set of bytes under two arm labels.
`q8-mat-vec-receipt.sh` refuses a `--num-rows` away from the served 2 without
`--allow-device` for that reason, and each output directory carries a
`specialization.tsv` naming its constants, its layer, and whether a
specialization was applied. The VGPR, spill, occupancy, and instruction
counts come out of RADV's ACO backend targeting gfx902 under
`RADV_DEBUG=shaderstats`, and that script's own header states that a host
without a gfx902 part produces another vendor's ISA under a receipt that
looks the same, which is the second reason `--allow-device` exists. The lab
arm therefore needs the appliance, in the light form the lab was built for:
two pipeline creations, no model load, no server, no lease, seconds rather
than a teardown window.

    remote/raven2-shader-lab/q8-mat-vec-receipt.sh SPV OUT/control \
        --allow-device --subgroup-only --num-rows 2
    remote/raven2-shader-lab/q8-mat-vec-receipt.sh SPV OUT/candidate \
        --allow-device --subgroup-only --num-rows 4

The register rows are absolute, since the census pins the control at 40
VGPRs, 0 spilled, and 6 subgroups per SIMD. The instruction rows are
control-relative and read from the same lab run's two receipts, because no
ACO listing of this module exists yet -- `spirv/` holds SPIR-V rather than
ISA, and the census row carries registers rather than instruction classes.

| quantity | basis | prediction | refuses the arm |
| --- | --- | --- | --- |
| VGPRs | absolute, control 40 | 44 to 64 | below 44, or above 64 |
| spilled VGPRs | absolute, control 0 | 0 | any value above 0 |
| subgroups per SIMD | absolute, control 6 | 5 or 4 | 3 or fewer |
| A-side narrow loads per loop iteration | control-relative | doubles | any other ratio |
| B-side `global_load_dwordx4` per loop iteration | control-relative | unchanged | any change |

The A-side ratio follows from the row loop rather than from an absolute
count: `iter` calls `dequantize4` twice and `get_dm` once inside
`[[unroll]] for n`, so every A-side load in the body is per row and doubling
the rows doubles them. The absolute control count stays unpredicted, because
`data_a_packed16[ib].qs[iqs/2]` and `[iqs/2 + 1]` are four contiguous bytes
that ACO may merge into one dword load, and `get_dm`'s own `data_a[ib].d`
read is a further narrow load the merge does not reach. The ratio is
insensitive to both. A ratio that fails to double means the extra rows were
not unrolled into registers and the module is not the one this document
registers; VGPRs unchanged at 40 reports the same thing from the other side.
A spill refuses the arm outright, because a spilled inner loop trades the
latency this mechanism aims at for scratch traffic.

The VGPR ceiling is 64 rather than 56 so the band closes against the pricing
table: 64 VGPRs is the last value that still allows four waves per SIMD and
16 rows in flight, above the baseline's 12. A result above 64 puts the
candidate in the three-wave regime, where it holds the baseline's rows with
half the wave-level parallelism to hide latency with, and the arm ends in
the lab.

## Falsifier 2: the bracket, under kernel-delta mode

`QWEN_CENSUS_AB_MODE=kernel-delta` with `run-served-binary-ab.sh`, both
roles carrying `llama-vulkan-pipeline-census.patch` as their first candidate
member over the production series and the candidate carrying the row-count
patch beside it, mirroring
`evidence/raven2-vulkan-kernel-census/q4k-scale-decode/4b-kernel-delta-20260905/`:
arm order `W C K K C C K K C`, four mirrored pairs, the engine clock at
`manual-gfx1100-fclk933` with `clock_invariant=held` required on every arm,
and the denominator bound to the receipt of
`device-20260905/calibration/`, server `70aa78bc...` against its census twin
`522e6367...`.

The subject is the `token_embd.weight` shape's own exclusive interval, read
by `evidence/q8-attribution/split-q8-mat-vec-shapes.py` over each arm's
`pipeline-census.tsv` rather than by the pipeline ledger, since the ledger
keys by pipeline and this delta moves one shape's dispatch geometry:

| role | quantity | prediction | refutes |
| --- | --- | --- | --- |
| subject | `token_embd.weight` exclusive ms per graph | 12.08 or below, a fall of 5% or more from 12.719 | a fall under 5%, or any rise |
| geometry | the head dispatch's `wg0` in the census dispatch row | 62080, half the control's 124160 | any other count, which means the specialization did not reach the dispatch |
| in-family | the other twelve Q8_0 shapes | every one falls or holds; none rises above its own 0.25% arm spread | a rise on any shape above 1% of the family |
| null | `gated_delta_net_f32_d128` and `rms_norm_mul_f32` | `spirv_executed_sha256` identical on both sides, exclusive intervals inside their arm scatter | a changed digest, or a move outside scatter |
| identity | every non-Q8 pipeline in the decode set | `spirv_executed_sha256` identical on both sides | any changed digest |

`NUM_ROWS` is a specialization constant of the one Q8_0 mat-vec decode
pipeline, so the candidate module serves all thirteen shapes and no in-family
shape can hold its digest. The in-family row therefore predicts a sign rather
than invariance: the twelve small shapes reach at most 3072 workgroups and
have far less launch overhead to amortize, so they are expected to hold or
improve slightly, and a rise on any of them means four rows costs more than
it buys outside the head. The null control is a non-Q8 pipeline, where an
unchanged executed digest beside a moved interval reports machine state
rather than the shader.

The partial-row tail stays out of the correctness surface: every `ne0` this
graph dispatches divides by 4, so `min(NUM_ROWS, p.stride_d - first_row)`
returns 4 on every workgroup and the ragged path in `compute_outputs` runs
on no dispatch here.

## The planning figure

The diagnostic token is 57.51 ms per decode graph. Reaching 50 ms, the
20 tok/s the class target names, requires 7.51 ms, which is 19.6% of the
38.36 ms Q8_0 mat-vec family if every millisecond of the reduction came out
of that family alone.

This delta cannot deliver it. The registered shape holds 12.719 ms, so the
7.51 ms is 59% of the subject's whole time and 13.1% of the token. A 20%
win on the shape is 2.54 ms, 4.4% of the token, which moves the graph to
55.0 ms and 18.2 tok/s; a 10% win is 1.27 ms and 2.2%. The 5% bracket
falsifier above is a detection threshold on the mechanism rather than a
serving target, and the ceiling of this registration is the shape's own
12.719 ms. Reaching 50 ms requires this delta and further deltas on
`attn_qkv.weight` (5.762 ms) and the three feed-forward shapes (13.589 ms
together), or a change outside the mat-vec family.

Every figure here is conditional under unclosed instrument controls. The
record it reads carries a `failed` calibration verdict, three controls at
`unresolved` or `incomplete`, and a collect control measuring a -0.88% mean
delta against a 2% bound; no control licenses an instrument bound in either
direction. The bracket falsifier's 5% threshold sits above that term and
above the 0.25% arm spread the shape split measures, which is what makes it
readable at all under that absence.
