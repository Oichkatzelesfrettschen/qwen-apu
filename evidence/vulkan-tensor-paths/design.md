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
3. Execution kernel. `mul_mat_vec_q4_k_f32`, the fused Gated DeltaNet
   dispatches, and the Flash Attention shader are the code that reads them.

The serving argv (`--device Vulkan0 --split-mode none --n-gpu-layers all
--override-tensor '.*=Vulkan0' --fit off`, `LLAMA_NO_CPU_FALLBACK=1`) fixes
placement, and `remote/test-strict-vulkan-placement.sh` requires CPU tensor and
graph placement to be refused before it accepts a load whose model, KV, and
compute buffers all name Vulkan0 (`evidence/strict-vulkan-placement.md`).
Placement is therefore settled; representation and kernel are the open axes.

## What each class streams (census, appliance files)

| Checkpoint | Q4_K | Q5_K | Q6_K | Q8_0 | F32 | tied embedding/output |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Qwen3.8-2B distill Q4_K_M | 48.91% | - | 50.08% | mtp only | 0.17% | 417,177,600 B Q6_K |
| Qwen3.8-4B distill Q4_K_M | 61.11% | - | 38.36% | - | 0.14% | 521,472,000 B Q6_K |
| Qwen3.5-2B base Q4_K_M | 36.50% | 1.55% | 53.17% | 7.50% | 0.50% | 417,177,600 B Q6_K |
| Qwen3.5-4B base Q4_K_M | 49.66% | 18.94% | 30.72% | 0.15% | 0.14% | 521,472,000 B Q6_K |
| Qwen3.5-0.8B Q8_0 | - | - | - | bulk | small | Q8_0 |

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
type, bytes) to the submit trace (pipeline, workgroup, rows per workgroup,
reduction mode, dispatches per token) and to per-dispatch GPU time from
timestamp queries, with VGPR and LDS from the RADV shader dump. Output:
`evidence/vulkan-tensor-paths/<model_id>.tsv`, one row per tensor. The ledger
answers which tensor is expensive by measured GPU time rather than by bytes,
and is the precondition of every later step.

### PR 2: representation controls

2B: current Q4_K_M, pure Q4_0, pure Q8_0. 0.8B: current Q8_0, Q4_0 (Q4_K_M
already measured at 0.9% from Q8_0). 4B follows only after the 2B mechanism is
read. Each rung is quantized from the BF16 source through the appliance's own
`llama-quantize`, never from the Q4 file, and carries a paired quality run and
an exact-token comparison. Prediction: Q4_0 gains on the 2B through simpler
unpack and lower VGPR pressure; falsifier: a paired decode gain under 5%, or a
quality loss outside the registered bound.

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

For each unique `(type, N, K, op)` on the ledger, sweep workgroup size (32 to
256), rows per workgroup (1 to 8), reduction (subgroup, hybrid, shared), and
unroll, measured by timestamp query on the appliance, starting at the 2B shapes
2048x2048, 2048x6144, 6144x2048, the fused GDN QKV shape, and 248320x2048. The
result is a static generated header keyed by type and shape; a runtime
tuning file waits until the static form has been admitted.

### PR 5: specialized hot kernels

Only shapes the ledger ranks hot: packed half2 reconstruction with FP32
accumulation at fixed intervals, 24-bit index arithmetic where offsets are
proven below 2^24 so ACO selects `v_mad_i32_i24`, VGPR-lifetime reduction for
occupancy, remaining Gated DeltaNet elementwise fusion the trace shows
unfused, and Flash Attention tile geometry for the six 2B and eight 4B
full-attention layers at 32K.

## Promotion criteria

A candidate is promoted on a paired end-to-end gain of at least 5% in
interleaved ABBA arms, exact or registered-equivalent output, quality inside
the registered bound, zero ring resets, VM faults, or device losses, no
desktop-QoS regression on the graphics probe, and strict Vulkan placement.
`llama-bench`'s printed deviation is within-arm and is not the uncertainty
(CLAUDE.md); the spread is read between arms.

## Out of scope until PR 5 has reported

A new custom tensor type, quantization-aware fine-tuning toward a Raven2
representation, and any fine-tune's throughput arm whose architecture, shapes,
types, and tuple equal a measured row. Behavioral fine-tunes share the kernel
profile and take their own quality grade.
