# Raven2 decode decomposition: where a 2B token's 101 ms goes, registered ahead of the census

This file states a machine model of the Athlon 3050U's iGPU built from the
hardware record in the laptop's own notes and from the pinned shaders, derives
from it a per-token cost account for the three served classes, and registers
the predictions the first accepted I1 census will test. Every number below is
labelled by its evidence class: `measured` names the file that measured it,
`derived` is arithmetic over measured inputs, and `estimated` is a count over
source that the ISA dump registered in E1 replaces. The document is written
before any I1 ledger is read, so a ledger that contradicts a prediction here
is the finding.

## The machine, decomposed

The GPU is a gfx902 with one shader engine, one shader array, three compute
units of which two are active, four SIMD16 units per CU, a 64-wide wavefront,
ten waves per SIMD, 64 KiB of LDS per CU, a 16 KiB L1 per CU, a 1 MiB L2, and
a 1100 MHz peak engine clock (`hp14-raven2-gpu/docs/raven2-capability-decomposition.md`,
geometry table; `amdgpu` reports `CU per SH 3, active_cu_number 2`). That is
128 lanes in total, so the VALU issue ceiling is 128 lanes at 1.1 GHz, or
140.8 G lane-operations per second, and the FP32 FMA ceiling is 281.6 GFLOPS
(`derived`). Memory is two channels of DDR4-2133 behind the data fabric, a
34.13 GB/s theoretical peak (`measured`, UMC registers in
`evidence/measurement-state-and-memory-clock.md`), which makes the machine
balance 8.3 flops per byte, or 4.1 VALU operations per byte streamed at the
FMA rate (`derived`).

The instruction set is the decisive part of the decomposition. The compiled
battery in `hp14-raven2-gpu/evidence/isa/` proves by assembler acceptance that
gfx902 carries `v_pk_fma_f16`, `v_mad_mix_f32`, `v_mad_i32_i24`, and
`v_mul_u32_u24`, and carries none of `v_fma_mix_f32`, `v_dot2_f32_f16`,
`v_dot4_i32_i8`, `v_dot8_i32_i4`, or `v_fmac_f32`, all of which first appear
on gfx906. The same battery measures the consequence on one shape: an
fp16-input, fp32-accumulate FMA chain costs 49 VALU instructions on gfx902
against 33 on gfx906, because every half-precision operand is widened by a
separate `v_cvt_f32_f16` where gfx906 folds the conversion into
`v_fma_mix_f32` (`measured`, `raven2-capability-decomposition.md` lines
91-101). RADV reports every one of the thirty integer-dot acceleration bits
false, so llama.cpp builds no `_q8_1` pipeline and every quantized weight on
this device takes the FP16-dequantize-then-FMA family
(`evidence/tensor-type-execution-audit.md`).

What gfx902 does carry, and what a hand-written kernel can use, is the GCN3
through GCN5 operand machinery that a dot-product instruction replaced on
later parts:

| mechanism | what it does on gfx902 | why it matters to a dequant-dot |
| --- | --- | --- |
| SDWA on VOP1/VOP2/VOPC | selects byte 0-3 or word 0-1 of a 32-bit source, with sign or zero extension, at no extra instruction | a packed byte reaches a `v_mul_u32_u24` or a `v_cvt_f32_f16` without an unpack instruction |
| `v_cvt_f32_ubyte0..3` | converts one selected byte of a dword to FP32 in one full-rate instruction | the 8-bit scale and 4-bit nibble paths reach float in one operation per value after a mask |
| `v_perm_b32` | arbitrary byte permutation of two sources | interleaves the two nibble planes of a Q4_K dword into byte lanes without shifts |
| `v_mad_u32_u24`, `v_mad_i32_i24` | full-rate 24-bit multiply-add, VOP3 | an int8 x int8 product accumulates at the FP32 FMA rate; the 32-bit `v_mul_lo_u32` is quarter rate |
| `v_pk_fma_f16` | two FP16 FMAs per lane per instruction | doubles the FMA rate where FP16 accumulation is acceptable |
| DPP `row_shr`, `row_bcast15/31`, `ds_swizzle` | cross-lane movement inside a wave without LDS | the 16-lane and 64-lane reductions at the end of a mat-vec row cost no LDS round trip |
| `s_buffer_load_dwordx4` | scalar loads into SGPRs, once per wave | the per-superblock `dm` pair and the twelve scale bytes are wave-uniform for a given row and belong in SGPRs |
| `buffer_load_dwordx4` | 16-byte vector loads | a lane's 16 nibbles arrive in one load |

The CPU side is two Zen+ cores at 2.3 GHz. The server runs single-threaded
on core 0 at nice 19 and the sampler on core 1 at nice 19, so graph
construction, command recording, sampling, and the HTTP reply for every token
are serial on one core.

## The pinned Q4_K path, counted

`mul_mat_vec_q4_k.comp` at f280b269 processes one 256-weight superblock with
sixteen lanes, each lane owning sixteen weights in four groups of four. Per
lane per superblock per row the shader issues, by source (`estimated`):

| stage | operations | count |
| --- | --- | ---: |
| scale decode | three 16-bit loads, six integer bit operations, eight `unpack8` byte conversions | 14 |
| nibble extraction | two 32-bit loads, four mask-and-shift operations, sixteen byte conversions | 20 |
| activation loads | four `vec4` loads of FP32 activations | 4 |
| weight dot | sixteen FMAs into four partial sums | 16 |
| minimum term | sixteen FMAs of activation against four scales | 16 |
| combine | seven FMAs folding `dm`, the four sums, and the minimum term into the accumulator | 7 |

That is about 77 issued operations for sixteen weights, or 4.8 per weight,
before the per-row reduction. Two rows share the loads of activations, so
the figure per weight at `NUM_ROWS = 2` is a little lower on the load side and
unchanged on the arithmetic. The 2B distill carries about 1.7 G weight
elements in the matrices the decode graph reads (`measured`, the census in
`evidence/tensor-type-execution-audit.md` gives the byte shares); at 4.8
operations per weight that is about 8 G lane-operations per token, and at
140.8 G per second the VALU alone needs about 57 ms per token with perfect
issue (`derived`). The bandwidth floor for the same token is 1.263 GB over
34.13 GB/s, or 37 ms (`derived` from the streamed-bytes census). The token
measures 101 ms at the fixed-64 scoreboard (`measured`).

The VALU account is larger than the bandwidth account. That inverts the
usual reading of a quantized decode as memory-bound, and the retained
K-quant ladder already agrees with the inverted reading: Q2_K streams 29.4%
fewer bytes than Q4_K_M and decodes no faster
(`evidence/decode-bound-analysis.md`), which a bandwidth-bound kernel cannot
do and an unpack-bound one does, since a 2-bit plane costs more operations
per weight to widen than a nibble; Q5_K reaches 5.9 GB/s where Q4_K and Q6_K
reach 8.1, and Q5_K is the rung that pays both the packed scale decode and
an extra bit-plane merge (`evidence/tensor-type-execution-audit.md`); the
0.8B at Q8_0 and at Q4_K_M decode within 0.9% of each other while the Q8_0
streams 46.4% more bytes, since Q8_0 widens each weight in one conversion.
The rate orders by operations per weight rather than by bytes per weight.

Two consequences follow for the design of any faster kernel here. The
minimum term is the cheaper one to remove: the sixteen FMAs of activation
against `sc2, sc3, sc6, sc7` depend on the activation vector and the scales
alone and on no weight, so the four 32-element group sums of the activation
are a property of the column, computable once per token in a pre-pass of
`ncols / 32` values and read by every row as four scalar loads, which turns
sixteen FMAs into four and removes about twelve of the 77 operations, 16% of
the issue budget of the family (`derived`). The larger one is the nibble
path: the conversion of a nibble to FP32 and its FMA against an FP32
activation is where gfx902 pays for the absent dot product, and the integer
alternative the machine does carry is a `v_mad_u32_u24` chain over int8
activations quantized once per token the way the `q8_1` path quantizes them
on devices that build it. Counted over a dword of eight nibbles: one mask for
the low plane, a shift and a mask for the high plane, then eight 24-bit
multiply-adds whose byte operands SDWA selects on the VOP2 `v_mul_u32_u24`
form or that `v_perm_b32` lays out for the VOP3 `v_mad_u32_u24` form, with
the group minimum folded into the same integer sum through the precomputed
int8 group sums and one FP32 fixup per 32-weight group. That is about 2.6
operations per weight against 4.8 (`estimated`), and if the VALU account
above holds it moves the 2B token from 101 ms toward about 75 ms, or from
9.9 toward 13 tok/s, with the 4B in the same proportion. The estimate is
what E1 and E2 below exist to replace with an instruction count the compiler
actually emits.

## The fixed cost the 0.8B exposes

The 0.8B class decodes at 63 to 66 ms per token across three checkpoints
whose streamed bytes span 0.477 to 0.801 GB per token
(`measured`, `evidence/model-admission/runtime-class-throughput.md`). At the
DRAM peak those bytes take 14 to 23 ms and at the VALU account above the
Q8_0 rung takes about 14 ms, so between 30 and 45 ms of every 0.8B token is
spent on neither streaming nor arithmetic. The 2B and 0.8B run the same 24
transformer blocks, and each block issues on the order of fifteen dispatches
between its two matrix families, its norms, its rotary step, and the Gated
DeltaNet recurrence, so a decode graph is on the order of 360 dispatches in
about 25 submissions of 16 nodes under the low-async profile. The census
measures this residue directly: `queue_non_dispatch_ms_per_graph` is queue
time inside the graph covered by no bracket, and `residual_ms_per_graph` is
host retirement span beyond queue completion. The serialized profile already
put a scale on it, since holding one node per submission with a host wait
took the 4B from 2.718 to 1.348 tok/s (`measured`, `CLAUDE.md` on the two
profiles): the device sits idle for whatever the host takes between
submissions, and low-async recovers most of that but not all of it.

## Registered predictions for the first accepted I1 ledger (2B, decode phase)

| prediction | value | falsifier |
| --- | --- | --- |
| P1 the mat-vec families' bracket union per graph | 50 to 65 ms | below 40 ms refutes the VALU account; the token is then bound elsewhere and the integer kernel is second priority |
| P2 `queue_non_dispatch + residual` per graph | 25 to 40 ms | below 15 ms refutes the fixed-cost account; fusion and submission shape are then third priority |
| P3 Gated DeltaNet, norm, rotary, and attention families together | 8 to 15 ms | above 25 ms makes the recurrence the second target ahead of submission shape |
| P4 `ownership` at the 0.05 threshold | `conclusive`, cross-pipeline overlap fraction below 0.05 | `inconclusive` with cross-pipeline overlap above 0.05 means low-async lets consecutive dispatches overlap on the queue and family ownership needs the S ordering |
| P5 `mul_mat_vec_q4_k_f16` VGPR count | 40 to 64, `subgroups_per_simd` 4 or more | above 84 VGPRs leaves three waves per SIMD and makes occupancy, not issue, the first target |
| P6 the sidecar `pp_dpm_sclk_selected_mhz` during decode graphs | 1100 on every in-window sample | a lower selected step during graphs means the DPM governor, not the kernel, sets part of the token |
| P7 the 0.8B `queue_non_dispatch + residual` per graph, once its census runs | 30 to 45 ms, the same order as the 2B's | a value near the 2B's in absolute terms confirms the residue is per dispatch rather than per byte |

P1 and P2 together account for the 101 ms token; P3 is the remainder. If P1
holds and P2 holds, the order of work is the integer Q4_K kernel first, the
activation group-sum pre-pass second because it is small and composes with
either kernel, and dispatch fusion third.

## Experiment ladder, each with its falsifier

- **E1, the ISA of the pinned shader.** On the appliance, in a teardown
  window, run the I0 build once with `RADV_DEBUG=shaders` under the census
  tuple and retain the disassembly of `mul_mat_vec_q4_k_f16_f32` and its
  Q6_K and Q8_0 siblings, with `RADV_DEBUG=shaderstats` beside it. Count
  VALU instructions per superblock. The count replaces the 77 above; a
  count below 50 refutes the VALU account before the census does.
- **E2, the integer inner product through ACO.** Write one standalone GLSL
  compute shader that multiplies masked nibbles by int8 activations and
  accumulates in `int`, compile it through RADV on the appliance with
  `RADV_DEBUG=shaders`, and read whether ACO selects `v_mad_u32_u24` or
  `v_mul_lo_u32` for the product. `v_mul_lo_u32` is quarter rate and refutes
  the 2.6 estimate for a GLSL-sourced kernel; the remedy is then either
  NIR range hints through `GL_EXT_shader_explicit_arithmetic_types_int8`
  operands, which NIR's range analysis narrows to 24 bits, or a SPIR-V
  post-pass, and both are measured the same way.
- **E3, the census read.** P1 through P6 against the accepted 2B I1
  ledgers, then P7 against the 0.8B attribution.
- **E4, the activation group-sum pre-pass.** A candidate patch to
  `mul_mat_vec_q4_k.comp` and the `q5_k`/`q6_k` siblings that reads four
  precomputed group sums per superblock. Prediction: the family's exclusive
  bracket falls 10 to 16% and the token 5 to 9% on the 2B, ABBA against
  production; below 3% on the token refutes the operation-count model for
  this term.
- **E5, the integer Q4_K kernel.** The `_q8_1`-shaped pipeline built
  without the dot-product gate, using the E2-proven instruction. Prediction:
  the family's bracket union falls 35 to 45% and the 2B token 20 to 30%;
  below 10% on the token refutes the VALU account outright.
- **E6, dispatch count.** The census's `submits_per_graph` and dispatch
  count per graph against P2; the fusion candidates the trace already names,
  the Gated DeltaNet elementwise chain first, measured by the same ABBA rule.

## What would move these numbers wholesale

The per-weight counts are per lane, and gfx902 issues one VALU instruction
per wave per four cycles on each SIMD16, so a wave's 64 lanes complete one
instruction in four clocks and the 140.8 G figure already accounts for that.
A dual-issue or co-issue of scalar and vector work does not change the VALU
count and is not credited. The one mechanism that would change the account
wholesale is `v_pk_fma_f16`: an FP16-accumulate dot with packed halves does
two FMAs per instruction, which halves the weight-dot and minimum stages,
at the cost the tree already registered for FP16 accumulation over 256-wide
groups; it is a Section B precision arm rather than a free lever, and it
composes with the integer path only for the FP32 fixup, so it sits behind E5.
