# gfx902 execution ladder

The Radeon block of the Athlon Silver 3050U is a two-compute-unit wave64
GCN5 processor with packed-half arithmetic and no dot-product or matrix
instructions. This document fixes what that device executes for each
llama.cpp Vulkan path, where headroom is plausible, and the order the arms
run in. `design.md` carries the program's ledger, controls, and quality
bound; this file carries the hardware model and the kernel-level stages that
program runs under.

## Six types, one path

A tensor's storage type, load type, reconstructed value type, multiply type,
accumulator type, and output type are six claims. On the served path
quantized weights stay packed in memory, activations travel as FP16, the
shader reconstructs weights with integer bit operations, and the dot
reduction accumulates in FP32; only the batched matrix pipelines select true
FP16 accumulation. The Vulkan pipeline `mul_mat_vec_q4_k_f16_f32`, selected
from `pipeline_dequant_mul_mat_vec_f16_f32` and embedded under the shader
symbol `mul_mat_vec_q4_k_f16`, names Q4_K weights, an F16 right-hand input,
and F32 accumulation and output, and the mat-vec generator fixes its
`FLOAT_TYPE` to `float`. Stage A records `pipeline_name` and `shader_symbol`
separately and joins them through the generated variant metadata.

## Device facts

| Property | Value | Consequence |
| --- | ---: | --- |
| LLVM/HSA target | `gfx902` | GFX9.0.2, base Vega ISA |
| Compute units | 2, each 4 x SIMD16 | 128 FP32 lanes; occupancy and tile granularity dominate |
| Wavefront | 64 lanes, four cycles per SIMD16 | a subgroup-16 algorithm is four partitions inside one wave |
| LDS | 64 KiB per CU, 32 banks of 32 bits | pack FP16 pairs into aligned words; pad aliasing strides |
| Shader clock, observed peak | 1.1 GHz | 281.6 GFLOP/s FP32 FMA; 563.2 GFLOP/s packed-half bound |
| Memory | dual-channel DDR4-2133, 34.13 GB/s peak | host two-thread read 15.44 GB/s; the device ceiling is unmeasured |
| `V_DOT2_F32_F16`, `V_DOT4_I32_I8`, `V_DOT8_I32_I4` | absent | present from gfx906; a gfx906 build is a disassembly comparator alone |
| Cooperative matrix, MFMA, WMMA, BF16 extension | absent | matrices run as tiled VALU kernels; BF16 converts through F16 or F32 |
| `shaderIntegerDotProduct` | true, all thirty `*Accelerated` flags false | `ggml-vulkan.cpp` declines MMVQ and MMQ, so the `_q8_1` pipelines go unbuilt |

The 563.2 GFLOP/s figure is an instruction-level bound: it assumes
`V_PK_FMA_F16` sustains the FMA issue rate under sufficient occupancy, and
no retained run measures that rate. `V_MAD_MIX_F32` consumes FP16 operands
and accumulates in FP32 in one instruction, which is the instruction
quantized decode wants where the compiler emits a separate conversion ahead
of an FP32 FMA. `GGML_VK_DISABLE_INTEGER_DOT_PRODUCT=1` is a falsification
control with a predicted ratio of 1.00, because the gated path is already
inactive; a resolved change reports a second selection rule.

## What the retained measurements fix

Native F16 processes each logical byte more efficiently than any
reconstruction kernel and still loses decode on bytes: the 2B distill
streams 17.41 GiB/s at F16 against 11.78 at Q4_K_M, the 0.8B 21.98 against
15.03 at Q8_0, with prefill 3 to 6% ahead in both pairs and decode at about
half. Nominal bit width does not order decode: on the 4B ladder Q4_K and
Q6_K both reach about 8.1 GB/s where Q5_K reaches 5.9 and Q2_K 5.5, so
unpack instruction count, layout, register pressure, and reduction
structure are the targets rather than bits per weight. The 30.6% spread
between sweeps of one configuration means every arm below is read within
an ABBA block.

## Stages

Every stage runs the 2B first, the 0.8B second, and the 4B third, and a
result becomes a Raven2-wide default only where the classes agree.

### A. Pipeline census

`patches/llama-vulkan-pipeline-census.patch`,
`remote/run-raven2-vulkan-kernel-census.sh`, and
`evidence/raven2-vulkan-kernel-census/` record, per pipeline on first use
and in aggregate: phase, GGML op, tensor types, pipeline name, dimensions,
alignment variant, workgroup size, `NUM_ROWS`, `NUM_COLS`, accumulator
precision, dispatch count, total and percentile GPU time, VGPR and SGPR
counts, LDS bytes, spill or scratch bytes, and queue. The backend already
holds a per-pipeline register count and queries pipeline executable
properties where RADV exposes them. `radv-low-priority-env.sh` gains a
non-serving `diagnostic` profile that exports
`GGML_VK_SERIALIZE_SUBMISSIONS=1` and preserves `GGML_VK_PIPELINE_STATS`,
`GGML_VK_PERF_LOGGER`, `GGML_VK_PERF_LOGGER_FREQUENCY`,
`GGML_VK_MEMORY_LOGGER`, `GGML_VK_SUBMIT_TRACE`, and `RADV_DEBUG`; the
serving profiles keep scrubbing them. The submit-trace patch throws during
device construction when `GGML_VK_SUBMIT_TRACE=1` reaches a process without
serialization, so a trace-enabled launch is refused unless serialization is
active. The serialized arm supplies dispatch attribution and resource
statistics; ordinary `low-async` arms supply the serving-profile end-to-end
throughput promotion reads. The kernels with the largest
cumulative GPU time are the ones the later stages touch.

### B. Precision, one mechanism at a time

`GGML_VK_DISABLE_F16=1` is the broad control. Separate switches
`GGML_VK_MATMUL_ACCUM`, `GGML_VK_FLASH_ATTN_ACCUM`, and
`GGML_VK_MATVEC_INPUT` over `fp16|fp32` vary one type at a time: Q4_K
decode by activation load type, quantized prefill by matmul accumulator,
Flash Attention by accumulator, F16 weights by accumulator. An
FP16-accumulator arm retains kernel outputs, final logits, top-token
identity, the graded rows, long-context retrieval, and NaN/Inf incidence
beside its rate. RMS norm, softmax, RoPE, recurrent state, and logits stay
FP32 unless an isolated arm proves otherwise. The 0.8B Q8_0/F16 pair is the
representation comparator and the 4B Q4_K_M the scaled-shape control.

### C. Wave and tile geometry

A wave64 specialization keys on measured properties -- vendor AMD, GCN,
subgroup 64, native FP16, integer dot unaccelerated, at most two shader
cores -- and compares W64 whole-wave, W64 with four 16-lane partitions
reduced by `subgroupShuffleXor` over masks 1, 2, 4, 8, W128 with subgroup
partials plus LDS, and W256, across `NUM_ROWS` 1, 2, 4 and `NUM_COLS` 1, 2,
4, 8. A variant is retained where the ISA shows fewer LDS operations,
barriers, or instructions, and a variant whose VGPR or LDS footprint leaves
one resident wave is rejected on the census before its rate is read. The
matmul tile sweep runs offline over 32x32 through 128x128 crossed with K
tile, accumulator, alignment, quant format, and batch, and promotes one
immutable lookup table keyed by (op, weight type, M range, N range, K
range, accumulator, alignment class, batch range) whose value is the tile
and K tile, distinct from the mat-vec key of (op, type, N, K, `NUM_COLS`,
accumulator, alignment); the generic selector picks 128x128 once the grid holds about
twice the shader-core count of tiles, which on two CUs is four tiles. Flash
Attention sweeps `Br` and `Bc` at 4K, 16K, 24K, and 32K with FP32 softmax
statistics and separate FP16/FP32 QK and PV accumulation arms, and keeps KV
dequantization fused.

### D. Unpack and layout

Five Q4_K variants: generic; short-live-range, which decodes four or eight
values from one packed word and consumes them before the next load;
quarter-broadcast, where one lane per 16-lane partition loads `dm` and the
packed scale words and `subgroupShuffle` distributes them; and two
load-time metadata expansions under a backend-private layout
`Q4_K_RAVEN_W64` that keeps the nibble array compressed and stores scales
and minima as aligned UINT8 or aligned FP16. The expansion is accounted in
`get_alloc_size`, the strict-placement check, and the memory preflight, and
the GGUF on disk is unchanged. The ISA check for each variant looks for
`v_perm_b32`, `v_bfe_u32`, `v_cvt_f32_ubyte*`, `v_mad_mix_f32`, DPP for
fixed shuffles, and `buffer_load_dwordx4`. The shader is patched first;
ACO is patched where the SPIR-V states the operation and the ISA misses it.

### E. ACO, on a demonstrated miss

Mesa is patched only for a pattern the census shows the compiler missing,
reduced to standalone SPIR-V: a mixed FMA emitted as convert plus FMA, a
nibble unpack left as a long mask chain, a fixed shuffle reduction lowered
to LDS or `ds_bpermute`, a wave-uniform value kept in VGPRs, a spill an
equivalent shorter-live-range source avoids, or exposed VMEM latency behind
clustered ALU work. The comparison is installed Mesa 26.2.1, isolated Mesa
main, and isolated Mesa with the one candidate patch, on identical SPIR-V,
binary, model, clocks, and request; a patch is promoted on both the
microkernel and the whole-model arm. The LLVM backend is a diagnostic
comparator and is never promoted on a whole-model timing.

### F. Gates

Every candidate retains ABBA paired throughput, per-kernel GPU time,
logical bytes per token, VGPR/SGPR/LDS, spill state, memory and clocks,
temperature, graphics-service latency, kernel hazard delta, one-token and
logit comparison, the graded suite, long-context retrieval, and teardown
proof. Promotion needs the all-pairs 5% ABBA rule, the mechanism-specific
output gate, and the zero-fault rule `design.md` registers: a
representation change reports its first token divergence and clears the
paired quality gates, and a kernel, tile, layout, or compiler change that
preserves the stored representation requires exact greedy token arrays.

## Bounded knobs and settled policy

`radv_enable_transfer_queue` serves model, projector, and layout-transform
upload alone; inference stays on the compute-only family at LOW priority,
since the graphics queue degrades frame service in the retained runs.
`radv_enable_unified_heap_on_apu` changes accounting rather than bandwidth,
`radv_clear_lds` stays false, `override_vram_size` changes the advertised
figure alone, and the shader cache buys startup. A second LOW-priority
compute queue with timeline-semaphore dependencies ranks after every kernel
stage and applies only to branches the census shows underfilling two CUs.
Full Vulkan placement, one router child, one slot, one orchestration
thread, nice 19, idle I/O, `low-async` at 16 nodes per submission, Flash
Attention, and the Q8_0/Q4_0 cache triple stay as served, and each
`GGML_VK_DISABLE_*` and `GGML_VK_FORCE_*` switch is a control varied one at
a time under the custom or diagnostic profile.

## Expected locus of headroom

Decode is bound by quantized bytes, reconstruction, and system-memory
traffic, so its profile is compact weights, cheap unpack, FP32 reduction,
and wave64 specialization. Prefill, vision encoders, and diffusion reuse
weights across rows, so their profile is native FP16, packed FMA, two-CU
matrix tiles, controlled FP16 accumulation, and LDS-efficient reuse. The
device holds no dormant integer tensor path; the gain, where one exists,
comes from mixed-precision instruction selection, packed-half matrix work,
wave64 quant decode, shorter unpack live ranges, expanded metadata alone,
smaller tiles, and fewer LDS round trips.
