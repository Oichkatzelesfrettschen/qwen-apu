# E5-int24: the Q4_K x Q8_1 mat-vec through the 24-bit integer multiplier

The design as it was registered, before a line of shader existed. It reaches
the tree verbatim so a later result is read against the claim that preceded it;
`README.md` beside it carries the falsifiers with the commands the appliance
run uses, and `patches/llama-vulkan-q4k-int24-mmvq.patch` is what the design
became.

```text
status=registered, no shader written, no arm run
target=mul_mat_vec_q4_k_q8_1_f32 on RADV RAVEN2 (gfx902), the 2B distill first
authority=Mesa 26.2.1 src/amd/compiler/instruction_selection/aco_select_nir_alu.cpp:1736-1768
          Mesa 26.2.1 src/amd/compiler/aco_optimizer.cpp:4528, :1332, :2238
          llama.cpp f280b269 ggml/src/ggml-vulkan/vulkan-shaders/mul_mat_vecq_funcs.glsl (Q4_K mmvq_dot_product)
          llama.cpp f280b269 + production series: ggml/src/ggml-vulkan/ggml-vulkan.cpp:6548 (the integer_dot gate; 427 is the AMD extension early-out and 488 the Intel XE1 branch), :4993, :5397
          hp14-raven2-gpu docs/raven2-capability-decomposition.md "What the compiler emits"
```

## The hardware fact

gfx902 has no `v_dot4_i32_i8`; LLVM's syntax reference lists the dot family
for gfx906 alone, RADV reports every `integerDotProduct*Accelerated` bit
false, and llama.cpp reads that report and builds no `_q8_1` pipeline. The
same silicon runs `v_mul_u32_u24` and `v_mad_u32_u24` at full rate where the
32-bit `v_mul_lo_u32` is quarter rate, and its VOP2 encodings on GFX9 carry
SDWA operand selects that read one byte of a source register for free. The
FP16 path the appliance runs today pays a conversion per operand on the
mixed-precision pattern, since gfx902 has `v_mad_mix_f32` and ACO selects
`v_cvt_f32_f16` beside `v_fma_f32` instead.

## The compiler rule, read from the laptop's own Mesa

`nir_op_imul` with a VGPR destination takes the unsigned upper bound of each
source through `nir_unsigned_upper_bound`; where both are at most
`0xffffff` it emits `v_mul_u32_u24`, where one is a constant it emits a
shift-and-add sequence, and otherwise `v_mul_lo_u32`. The optimizer's
`add_opt(v_mul_u32_u24, v_mad_u32_u24, ...)` folds the product into a
following add, and its extract folding places a byte select of a 32-bit
word into the SDWA `sel` of the consuming VOP2 instruction.

The consequence is a design rule for the shader: every multiplicand must be
provably unsigned and below 2^24 at the NIR level, which a masked nibble
(`& 0xF`, bound 15) and an unpacked byte (`& 0xFF`, bound 255) satisfy and a
sign-extended int8 does not, because its unsigned bound is `0xffffffff`.

## The shader design

The pinned Q4_K integer function sums four `dotPacked4x8EXT(qs_a, q8)` over
sixteen values and applies the block scale and minimum once. On this device
the same sum is written without the extension:

```text
q8 biased      b = q8 + 128            unsigned byte, bound 255, produced once per
                                        activation block by quantize_q8_1 (or by
                                        the shader on load: (word ^ 0x80808080))
nibble         n = (word >> s) & 0xF   bound 15
product        n * b                   bound 3825, v_mul_u32_u24 with SDWA byte select on b
accumulate     sum_nb += n * b         v_mad_u32_u24, 32 products bound 122400
correction     sum_n  += n             the biased term: sum(n * q8) = sum_nb - 128 * sum_n
```

`128 * sum_n` is a shift, and Q4_K already carries a per-sub-block minimum
term of the same shape (`sum_m`), so the correction rides the existing
accumulator rather than adding a pass. The block result then applies
`d * scale` and `dmin * min` in FP32 exactly as the pinned function does.

Predicted per sixteen values: 4 masks, 16 `v_mad_u32_u24` with SDWA byte
selects, 2 `v_add3_u32` for the nibble sum, against the FP16 path's
extraction, conversion, and `v_mac_f32` per value. The E1 receipt for the
production pipeline reads VALU 882 and `v_mac_f32` 248 for its tile; the
receipt for this shader must show `v_mad_u32_u24` and `v_mul_u32_u24` in
place of `v_mac_f32` and no `v_cvt_f32_f16` or `v_mul_lo_u32` in the inner
loop, or the hypothesis is refuted at the ISA before any run.

## What has to change in llama.cpp for an arm

| site | today | the arm |
| --- | --- | --- |
| `mul_mat_vecq.comp:4` `#extension GL_EXT_integer_dot_product : require` | rejected by the laptop glslc | a `dotPacked4x8` replacement function under a define, extension line removed under it |
| `ggml-vulkan.cpp:6548` `integer_dot_product` device flag | false on RAVEN2 | a candidate-only override `GGML_VK_FORCE_INTEGER_DOT=1` that admits the `_q8_1` mat-vec and the `quantize_q8_1` pipeline on this device, scrubbed by `radv-low-priority-env.sh` unless the profile exports it |
| `CMakeLists.txt` `GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT` | OFF on the laptop | the replacement shader compiles under the existing toolchain, so the arm needs the pipeline table to reach it without the flag |
| activation quantization | none | `quantize_q8_1.comp` runs once per token per activation source, the producer E4b also needs |

## Falsifiers, in order

1. ISA receipt: the compiled candidate pipeline holds `v_mul_lo_u32` or
   `v_cvt_f32_f16` in its inner loop, or fewer `v_mad_u32_u24` than the
   product count predicts. Refuted before the device is touched.
2. Correctness: the margin witness on the holdout reads `differs`. Q8_1
   activation quantization moves the numerics more than E4 did by design,
   so the registered contract, not token identity alone, decides.
3. Bracket: the kernel-delta comparison against the census build reads
   `bracket-unchanged` or `lengthened` on the Q4_K family plus the
   quantize producer, measured as one envelope the way E4b is.
4. Whole token: the served rate under the scoreboard tuple.

## Reading against the other rungs

E4 removed arithmetic from the FP16 path and realized 3.9% of the bracket
from an 8.1% static opportunity. E5-int24 changes the number format of the
inner product, so its opportunity is the conversion count and the
multiplier rate rather than a hoist, and it composes with E4b's activation
summaries only where both read the same Q8_1 activation. The 0.8B's Q8_0
rows take the same path with a byte nibble replaced by a byte, and the
Q6_K trunk of the 2B (50% of its bytes) needs the six-bit unpack that the
pinned `mul_mat_vec_q6_k_q8_1` already writes.
