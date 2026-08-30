# Vulkan tensor paths on Raven2: ledger, representation ladder, shape tuning

This record registers the program that follows the 32K queue. It separates
three things one word covers -- where a tensor lives, how it is stored, and
which shader consumes it -- and orders the work by the mechanism each step
tests. Numbers carry their evidence class: a census figure is read from the
file, a source figure from the pinned tree at f280b26, a rate from a retained
sweep, and a proposal is marked as one.

## Three meanings of "tensor"

1. Placement. `Vulkan0` is the RADV Raven2 device; `Vulkan_Host` is a
   host-visible Vulkan buffer that receives logits and stages small transfers
   and is part of the Vulkan path rather than a CPU fallback.
2. Representation. `Q4_K`, `Q5_K`, `Q6_K`, `Q8_0`, `F16`, `F32` state how
   weights and state are stored in the file and on the device.
3. Execution kernel. The Q4_K mat-vec, the fused Gated DeltaNet
   dispatches, and the Flash Attention shader are the code that reads them.
   One kernel has three names: `ggml-vulkan.cpp` selects it from the array
   `pipeline_dequant_mul_mat_vec_f16_f32[...][GGML_TYPE_Q4_K][...]`, creates
   the Vulkan pipeline as `mul_mat_vec_q4_k_f16_f32`, and the retained
   binary audit counts the embedded shader symbol `mul_mat_vec_q4_k_f16`.
   The ledger records `pipeline_name` and `shader_symbol` as two fields and
   joins them through the generated variant and type metadata.

The serving argv (`--device Vulkan0 --split-mode none --n-gpu-layers all
--override-tensor '.*=Vulkan0' --fit off`, `LLAMA_NO_CPU_FALLBACK=1`) fixes
placement, and `remote/test-strict-vulkan-placement.sh` requires CPU tensor and
graph placement to be refused before it accepts a load whose model, KV, and
compute buffers all name Vulkan0 (`evidence/strict-vulkan-placement.md`).
Placement is therefore settled; representation and kernel are the open axes.

## What each class streams (census, appliance files)

Shares are over streamed bytes: the multi-token-prediction block is
`TENSOR_SKIP` on an ordinary load (`src/models/qwen35.cpp`), so its tensors
are subtracted before the percentage is taken, and a file-level share
(`evidence/tensor-type-execution-audit.md`) differs from these by that block.

| Checkpoint | streamed bytes | Q4_K | Q5_K | Q6_K | Q8_0 | F32 | tied embedding/output |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Qwen3.8-2B distill Q4_K_M | 1,263,435,008 | 48.70% | - | 51.13% | - | 0.17% | 417,177,600 B Q6_K |
| Qwen3.8-4B distill Q4_K_M | 2,697,836,544 | 61.08% | - | 38.78% | - | 0.14% | 521,472,000 B Q6_K |
| Qwen3.5-2B base Q4_K_M | 1,320,574,208 | 38.59% | 1.64% | 56.21% | 3.04% | 0.52% | 417,177,600 B Q6_K |
| Qwen3.5-4B base Q4_K_M | 2,729,969,664 | 49.85% | 19.01% | 30.84% | 0.15% | 0.14% | 521,472,000 B Q6_K |
| Qwen3.5-0.8B Q8_0 | 0.801 GB/token (sweep) | - | - | - | bulk | small | Q8_0 |

The two base checkpoints are the vision rows, and they are where Q5_K lives:
21.6 MB in the 2B, 519 MB in the 4B, split 346 MB attention and 173 MB Gated
DeltaNet. The tied vocabulary tensor is read as the output projection on every
generated token, so it is the largest single tensor on the decode path in
every class.

## The kernel family Raven2 runs (source, f280b26)

`ggml-vulkan.cpp:6548` ANDs `integer_dot_product` with
`integerDotProduct4x8BitPackedSignedAccelerated`, which RADV reports false on
gfx902 with the other 29 accelerated flags, so no `_q8_1` mat-vec or MMQ
pipeline is built and every K-quant and Q8_0 tensor takes a dequantize-then-
float-dot shader (`evidence/tensor-type-execution-audit.md`). Cooperative
matrix, BF16 matrix, MXFP4 and NVFP4 matrix paths, and RDNA wave32 tuning
belong to hardware this device lacks. The pinned `mul_mat_vec.comp` already
carries `K_PER_ITER 4` with aligned vec4 loads for the unquantized path, so
that upstream vectorization is in the build and is not a work item. The
backend also selects one `AMD_GCN` row-per-workgroup set for every GCN device
and every tensor shape; a 2-CU wave64 UMA part at 2048/6144 and 2560/9216 is
one point in that set's domain, which is the shape-tuning opportunity.

## Program, in order

Every arm runs 2B, then 0.8B, then 4B, at depth 0, 16K, and 32K, and a result
is appliance-wide only where the classes agree (CLAUDE.md, "Three runtime
classes, one primary target").

### PR 1: tensor path ledger

`remote/report-vulkan-tensor-paths.py` joins the census (name, role, N x K,
type, bytes, activation column count per phase) to the submit trace (pipeline, workgroup, rows per workgroup,
reduction mode, dispatches per token) and to per-dispatch GPU time from
timestamp queries, with VGPR and LDS from the RADV shader dump. Output:
`evidence/vulkan-tensor-paths/<model_id>.tsv`, one row per observed tensor
execution path, keyed by tensor name, role, phase, GGML op, `pipeline_name`,
`shader_symbol`, `NUM_COLS`, accumulator precision, and alignment variant, so
the tied embedding/output tensor and a tensor dispatched under several phases
or specializations each keep every path. Static fields such as type,
dimensions, and bytes repeat across a tensor's path rows, and a census tensor
with no observed dispatch takes one row with `dispatch_count=0` and `-` in
the execution-path fields. The ledger
answers which tensor is expensive by measured GPU time rather than by bytes,
and is the precondition of every later step.

### PR 2: representation controls

2B: current Q4_K_M, pure Q4_0, pure Q8_0. 0.8B: current Q8_0, Q4_0 (Q4_K_M
already measured at 0.9% from Q8_0). 4B follows only after the 2B mechanism is
read. Each rung is quantized from the BF16 source through the appliance's own
`llama-quantize`, never from the Q4 file, and carries a paired quality run and
an exact-token comparison. Prediction: Q4_0 gains on the 2B through simpler
unpack and lower VGPR pressure; falsifier: a paired decode gain under 5%, or a
quality loss outside the registered bound. That bound is preregistered here:
the paired text-quality arm selects
`screen,arithmetic,word_problem,code,format,long_context,termination`
through `remote/run-quality-suite.py --categories`, with
`--long-context-characters 24000 --thinking off --max-tokens 1024` beside
the runner's fixed temperature 0, `top_k` 1, and seed 1: the 55-row
invocation `remote/run-quality-roster.sh` retains, so the 33/55, 40/55, and
47/55 baselines stay comparable in procedure and not in row names alone. The control is the deployed representation of
the same registry row -- Q4_K_M for the 2B and 4B rows and Q8_0 for the
0.8B row -- graded in the same sweep, and the candidate may fall at most one
row against it. Vision and photographic rows are a separate projector-quality
gate and stay out of the text total: a vision-capable candidate is compared
with the deployed representation of the same registry row under the same
projector, image fixtures, request tuple, and paired arm order, the ten
`vision` rows and nine `photo` rows are reported as two columns, neither
column may fall by more than one row, and the nineteen-row total may fall by
at most one row against its paired control. A two-row fall in either column
or overall refutes the candidate whatever its throughput. The candidate's greedy token stream on the six graph-alias prompts
(`evidence/vulkan-view-alias/ab-2b/`) is reported by first-divergence index
rather than gated, since a representation change is expected to move tokens.
A two-row fall refutes the rung whatever its rate.

### PR 3: custom quant recipes

First 2B mixture keeps F32 norms and state, the Q6_K tied tensor, and the
projector's precision, and moves GDN `attn_qkv`, GDN `ffn_down`, FFN gate/up,
and full-attention Q/K/V/O to Q4_0 through `--tensor-type`. If bulk Q4_0 wins,
the tied tensor is then tested alone at Q6_K, Q4_0, and Q8_0. The vision rows
get two variants that move Q5_K tensors alone to Q4_0 and to Q6_K, since Q5_K
pays both the packed scale-and-minimum decode and the bit-plane merge; the 4B
base at 18.94% Q5_K is the row where that can register, and the 2B base at
1.55% is its control.

### PR 4: Vulkan shape autotuner

For each unique `(type, N, K, op, NUM_COLS)` on the ledger -- the activation
column count is part of the key because one weight shape is dispatched at one
column in ordinary decode and at two to four columns under MTP verification,
and `ggml-vulkan.cpp` selects a different mat-vec variant by column count --, sweep workgroup size (32 to
256), rows per workgroup (1 to 8), reduction (subgroup, hybrid, shared), and
unroll, measured by timestamp query on the appliance, starting at the 2B shapes
2048x2048, 2048x6144, 6144x2048, the fused GDN QKV shape, and 248320x2048. The
result is a static generated header keyed by (op, weight type, N, K,
NUM_COLS, accumulator, alignment class), whose value is the selected
workgroup size, rows per workgroup, reduction, and unroll; a runtime tuning
file waits until the static form has been admitted.

### PR 5: specialized hot kernels

Only shapes the ledger ranks hot: packed half2 reconstruction with FP32
accumulation at fixed intervals, 24-bit index multiplication where both
multiplicands -- the index and the stride, rather than the final offset --
are proven to fit signed 24 bits, [-2^23, 2^23-1], for `v_mad_i32_i24`,
which sign-extends its operands, or [0, 2^24-1] for the unsigned
`v_mad_u32_u24`, with every other case keeping 32-bit arithmetic,
VGPR-lifetime reduction for
occupancy, remaining Gated DeltaNet elementwise fusion the trace shows
unfused, and Flash Attention tile geometry for the six 2B and eight 4B
full-attention layers at 32K.

## Promotion criteria

A candidate is promoted on an all-pairs gain in one interleaved ABBA block
C1, S1, S2, C2 over its preregistered primary throughput metric: with
`g1 = S1 / C1 - 1` and `g2 = S2 / C2 - 1`, promotion requires `g1 >= 0.05`
and `g2 >= 0.05`. The paired mean is reported and cannot compensate for a
pair below 5%; a split result is inconclusive, schedules another
preregistered ABBA block, and supports no promotion. Promotion further
requires an output gate split by mechanism, quality inside
the registered bound, zero ring resets, VM faults, or device losses, no
desktop-QoS regression on the graphics probe, and strict Vulkan placement.
`llama-bench`'s printed deviation is within-arm and is not the uncertainty
(CLAUDE.md); the spread is read between arms.

The output gate follows the mechanism. A representation change reports its
first-divergence index and passes through the paired quality bound, since
token identity is not its predicate. A kernel, tile, layout, or compiler
change that preserves the stored representation requires exact greedy token
arrays. A relaxed equivalence predicate for a later candidate is registered
in that candidate's design record before its device arm runs.

## Out of scope until PR 5 has reported

A new custom tensor type, quantization-aware fine-tuning toward a Raven2
representation, and any fine-tune's throughput arm whose architecture, shapes,
types, and tuple equal a measured row. Behavioral fine-tunes share the kernel
profile and take their own quality grade.
