# gfx902 execution ladder

This document fixes what the Athlon Silver 3050U Raven2 path executes in the
pinned llama.cpp Vulkan backend, where headroom is plausible, and the order the
arms run in. `design.md` carries the program's ledger, controls, and quality
bound; this file carries the source-bounded hardware model and the kernel-level
stages that program runs under.

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
`FLOAT_TYPE` to `float`. The Stage A design records `pipeline_name` and
`shader_symbol` separately and joins them through generated variant metadata.

## Device facts

The source boundary uses the AMD processor catalogue, Linux v7.0, Mesa
`889476855143e855a7f92989251f09fb3b690cda`, LLVM
`937e353fb22173c5976af9ae03352f16f9c8df2a`, and llama.cpp
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`. AMD lists two graphics cores, a
1.1 GHz maximum graphics frequency, two memory channels, and DDR4-2400 maximum
memory speed for the processor. Linux KFD maps Raven GC IP 9.1.0 and 9.2.2 to
`gfx902`, while Mesa maps `CHIP_RAVEN2` to the internal LLVM processor name
`gfx909`; the names belong to different software contracts and do not identify
contradictory silicon. LLVM defines `gfx902` as ISA 9.0.2 with wave64
architecture and `FeatureMadMixInsts`. ISA 9.0.4 introduces
`FeatureFmaMixInsts`, and ISA 9.0.6 adds the dot feature set. Mesa exposes
packed 16-bit arithmetic on GFX9, excludes Raven2 from its `has_fma_mix` and
accelerated-dot predicates, and RADV consequently reports packed 4x8
integer-dot acceleration as false. Mesa's `has_fma_mix` name does not remove
LLVM's earlier MAD-mix instruction. The pinned llama.cpp gate leaves the
accelerated `_q8_1` MMQ and MMVQ pipelines unbuilt.

Primary sources: [AMD processor catalogue](https://www.amd.com/en/products/specifications/processors.html),
[Linux KFD mapping](https://github.com/torvalds/linux/blob/v7.0/drivers/gpu/drm/amd/amdkfd/kfd_device.c#L301-L313),
[Mesa family mapping](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/common/amd_family.c#L144-146),
[LLVM processor definition](https://github.com/llvm/llvm-project/blob/937e353fb22173c5976af9ae03352f16f9c8df2a/llvm/lib/Target/AMDGPU/GCNProcessors.td#L146-L149),
[LLVM ISA feature sets](https://github.com/llvm/llvm-project/blob/937e353fb22173c5976af9ae03352f16f9c8df2a/llvm/lib/Target/AMDGPU/AMDGPU.td#L1943-L1964),
[LLVM MAD-mix and FMA-mix selection](https://github.com/llvm/llvm-project/blob/937e353fb22173c5976af9ae03352f16f9c8df2a/llvm/lib/Target/AMDGPU/VOP3PInstructions.td#L455-L499),
[LLVM target restrictions](https://github.com/llvm/llvm-project/blob/937e353fb22173c5976af9ae03352f16f9c8df2a/llvm/docs/AMDGPUUsage.rst#L723-L728),
[Mesa family ordering](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/common/amd_family.h#L96-104),
[Mesa arithmetic predicates](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/common/ac_gpu_info.c#L331-L339),
[ACO NIR FMA selection](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/compiler/instruction_selection/aco_select_nir_alu.cpp#L1931-L1954),
[ACO mix optimization](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/compiler/aco_optimizer.cpp#L843-L883),
[RADV feature exposure](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/vulkan/radv_physical_device.c#L1141),
[RADV predicate binding](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/vulkan/radv_physical_device.c#L1794),
[RADV property exposure](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/vulkan/radv_physical_device.c#L2033-L2062),
[llama.cpp device gate](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/ggml/src/ggml-vulkan/ggml-vulkan.cpp#L6449),
[llama.cpp executable-statistic handling](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/ggml/src/ggml-vulkan/ggml-vulkan.cpp#L3048-L3084),
[Mesa AMD statistic names](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/util/shader_stats.xml#L104-L113),
[llama.cpp MMQ construction gate](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/ggml/src/ggml-vulkan/ggml-vulkan.cpp#L4910-L4913)
and
[llama.cpp MMVQ construction gate](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/ggml/src/ggml-vulkan/ggml-vulkan.cpp#L5297-L5301).

LLVM's `gfx9-generic` documentation table says `v_mad_mix` is unavailable on
gfx902 and gfx909, which conflicts with the same revision's processor-specific
TableGen and executable assembler behavior. The hardware model follows the
processor definitions and treats the generic-target restriction table as
conflicting upstream documentation rather than as the processor legality gate.

| Property | Value | Consequence |
| --- | ---: | --- |
| LLVM/HSA target | `gfx902` | GFX9.0.2, base Vega ISA |
| Graphics cores | 2 | derive occupancy from measured pipeline data |
| Wavefront | 64 | compare whole-wave and partitioned reductions |
| Packed 16-bit | exposed | measure ISA and sustained issue rate |
| MAD mix | LLVM feature exposed | inspect stock ACO ISA for `v_mad_mix_f32` |
| FMA mix | Mesa predicate false | `v_fma_mix_f32` requires a later feature set |
| Graphics clock | up to 1.1 GHz | product maximum, not sustained rate |
| Memory | DDR4-2400 max; [2133.33 retained][umc] | traffic unmeasured |
| Integer dot | exposed, unaccelerated | accelerated MMQ/MMVQ stay unbuilt |

[umc]: ../measurement-state-and-memory-clock.md#memory-is-trained-at-ddr4-2133-the-reported-steps-are-dynamic-fclk

The packed-half path is a candidate rather than a throughput claim. Mesa exposes
packed 16-bit arithmetic for GFX9, while no retained run establishes a sustained
packed-half issue rate. LLVM accepts `v_mad_mix_f32` for gfx902, while gfx902
lacks `v_fma_mix_f32` and gfx906-class `v_dot2_f32_f16`. Instruction legality
does not make the pinned shader's explicit FP32 `fma` chain eligible. ACO
selects fused `v_fma_f32` for that NIR operation and refuses to convert it when
Raven exposes only unfused MAD-mix. Terminal multiply and deliberately
non-fused expressions remain eligible only when their rounding and denormal
behavior is declared and tested. Stock and candidate disassembly, resource
statistics, the declared numeric oracle, and matched timestamps decide that
narrower route.
`GGML_VK_DISABLE_INTEGER_DOT_PRODUCT=1` is a falsification control with a
predicted ratio of 1.00 because the gated path is already inactive; a resolved
change reports a second selection rule.

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

The current targets are 20 tok/s for 0.8B, 10 tok/s for 2B, and 5.25 tok/s
for 4B. `evidence/throughput-target-analysis/` derives their exact latency,
bandwidth, Amdahl, and N=1 bounds. The 4B planning baseline requires 42.67%
total time removal, so the pipeline census must prove that any proposed surface
owns enough time before a shader edit can carry an end-to-end claim.

## Proposed stages

The checkout lacks `patches/llama-vulkan-pipeline-census.patch`,
`remote/run-raven2-vulkan-kernel-census.sh`, and
`evidence/raven2-vulkan-kernel-census/`. Sections A through F specify the
implementation and evidence contract rather than completed programs or measured
results. Every proposed stage runs the 2B first, the 0.8B second, and the 4B
third, and a result becomes a Raven2-wide default only where the classes agree.

### A. Pipeline census, unimplemented

The proposed `patches/llama-vulkan-pipeline-census.patch`,
`remote/run-raven2-vulkan-kernel-census.sh`, and
`evidence/raven2-vulkan-kernel-census/` record, per pipeline on first use
and in aggregate: phase, GGML op, tensor types, pipeline name, dimensions,
alignment variant, workgroup size, `NUM_ROWS`, `NUM_COLS`, accumulator
precision, dispatch count, total and percentile GPU time, VGPR and SGPR
counts, LDS bytes, spill or scratch bytes, and queue. The backend queries
pipeline executable properties, but it stores only the NVIDIA-named
`Register Count` statistic in its existing per-pipeline field. RADV instead
publishes `VGPRs`, `SGPRs`, `Spilled VGPRs`, `LDS size`, `Scratch size`, and
`Subgroups per SIMD`. The census patch stores those exact names and validates
each `VkPipelineExecutableStatisticFormatKHR` before using the union value.
RADV returns those resource fields through
[`radv_GetPipelineExecutableStatisticsKHR`](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/vulkan/radv_pipeline.c#L837-L863).
`radv-low-priority-env.sh` gains a
non-serving `diagnostic` profile that exports
`GGML_VK_SERIALIZE_SUBMISSIONS=1` and preserves `GGML_VK_PIPELINE_STATS`,
`GGML_VK_PERF_LOGGER`, `GGML_VK_PERF_LOGGER_FREQUENCY`,
`GGML_VK_MEMORY_LOGGER`, `GGML_VK_SUBMIT_TRACE`, and `RADV_DEBUG`; the
serving profiles keep scrubbing them. The submit-trace patch throws during
device construction when `GGML_VK_SUBMIT_TRACE=1` reaches a process without
serialization, so a trace-enabled launch is refused unless serialization is
active. The serialized arm supplies dispatch identity and compile-time resource
statistics. The serialized arm cannot supply serving-profile time attribution.
An asynchronous low-async arm writes
[Vulkan device timestamps](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#queries-timestamps)
around dispatches, reads them at natural synchronization points, and converts
deltas with `timestampPeriod`. Logger-off, logger-on, logger-on, logger-off on
an identical binary bounds instrumentation overhead before timestamp rows
support a gain claim. Ordinary `low-async` arms supply the serving-profile
end-to-end promotion reads. The kernels with the largest cumulative GPU time
are the ones the later stages touch.

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

A wave64 specialization keys on source-bound properties -- vendor AMD, GFX9,
subgroup 64, packed 16-bit arithmetic, unaccelerated integer dot, and two
advertised graphics cores -- and compares a W64 whole-wave variant, a W64
four-partition variant
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
accumulator, alignment). The generic selector admits 128x128 only when the grid
retains at least four tiles; the census rather than an assumed core-to-tile ratio
selects it. Flash
Attention sweeps `Br` and `Bc` at 4K, 16K, 24K, and 32K with FP32 softmax
statistics and separate FP16/FP32 QK and PV accumulation arms, and keeps KV
dequantization fused.

The Q4_K mat-vec row sweep follows resource products rather than row count
alone. Persistent accumulators require at least `NUM_COLS * NUM_ROWS` FP32
values per invocation, lexical activation loads contribute
`4 * NUM_COLS * NUM_ROWS` `vec4` loads per superblock before compiler
elimination, and shared reduction consumes
`4 * NUM_COLS * NUM_ROWS * workgroup_size` bytes when the selected reduction
uses LDS. gfx902 wave64 allocates VGPRs in groups of four from 256 VGPRs per
SIMD. A row or column change predicts an occupancy transition only when the
compiled statistics cross an allocation boundary.

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
`v_perm_b32`, `v_bfe_u32`, `v_cvt_f32_ubyte*`, DPP for fixed shuffles, and
`buffer_load_dwordx4`. The shader is patched first;
ACO is patched where the SPIR-V states the operation and the ISA misses it.

### E. ACO, on a demonstrated miss

Mesa is patched only for a pattern the census shows the compiler missing,
reduced to standalone SPIR-V: an available packed-half operation left
scalarized, a nibble unpack left as a long mask chain, a fixed shuffle reduction
lowered to LDS or `ds_bpermute`, a wave-uniform value kept in VGPRs, a spill an
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
stage and applies only to branches whose census shows unused execution capacity.
Full Vulkan placement, one router child, one slot, one orchestration
thread, nice 19, idle I/O, `low-async` at 16 nodes per submission, Flash
Attention, and the Q8_0/Q4_0 cache triple stay as served, and each
`GGML_VK_DISABLE_*` and `GGML_VK_FORCE_*` switch is a control varied one at
a time under the custom or diagnostic profile.

## Bounded candidate mechanisms

The retained rates show that logical weight bytes and reconstruction format
both affect decode, but they identify neither physical system-memory traffic
nor a single bottleneck. The candidate profile therefore combines compact
weights, cheap unpack, FP32 reduction, and wave64 specialization. Prefill,
vision encoders, and diffusion reuse weights across rows, so their profile is
native FP16, mixed MAD only for eligible non-fused expressions, small-device
matrix tiles, controlled FP16
accumulation, and LDS-efficient reuse. RADV's packed signed 4x8 property keeps
the pinned
backend's accelerated `_q8_1` MMQ and MMVQ construction gates closed;
quantized shaders still use integer bit operations for unpack. Candidate gains
can come from available packed-half instruction selection, wave64 quant decode,
shorter unpack live ranges, expanded metadata alone, smaller tiles, and fewer
LDS round trips.
