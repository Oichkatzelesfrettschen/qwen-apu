# E5-M: the hand-expanded int24 GLSL, the lane's negative control

E5-M is `patches/llama-vulkan-q4k-int24-mmvq.patch`'s own shader under
`GGML_VK_INT24_DOT`: sixteen straight-line products of a constant-masked quant
byte by a constant-masked biased activation byte, with the bias removed once per
call, and a macro that spells the result `dotPacked4x8EXT` so the forty call
sites read the same either way. The module emits no `OpSDot`, holds no
`DotProduct` capability, and names no extension, which is what lets the
appliance's own glslc compile it: `evidence/web-admission-router-tools/build-raven2-vulkan-production.log:33`
records that toolchain printing `GL_EXT_integer_dot_product not supported by
glslc`, so E5-M is the one q8_1 route that host can build today.

It is the lane's control rather than its hypothesis because the receipts below
measure it losing to the standard route by 318 VALU on identical silicon.

## The mechanism, and the fold that does not form

`isa-arch-toolchain/` is the arm compiled through Arch's stock `vulkan-radeon`
(Mesa 26.2.1-arch3.1) on a drm-shimmed RAVEN2 node. `isa-across-2115/pre-2115/`
and `isa-across-2115/post-2115/` are the same module through two builds of
`mesa-26-gororoba` one pull request apart. All three read
`isa_sha256 8896269f54c86f1039a08740aaa1f1f3fdbef6080f8d9e7a1908ce84e2598f34`,
so three independently toolchained runs agree on the executed instruction
stream.

```text
products reached        224, every one v_mul_u32_u24_sdwa with src0_sel and
                        src1_sel byte selects; zero v_mul_lo_u32
multiply-add fold       zero v_mad_u32_u24. SDWA rides VOP1 and VOP2 on GFX9
                        while v_mad_u32_u24 is VOP3, so ACO takes the byte
                        select and cannot also take the fold; accumulation
                        runs through v_add3_u32 instead
v_cvt_f32_f16           56, the same count in the same places as the
                        dotPacked4x8EXT build of this shader, so it reports the
                        q8_1 scale decode rather than the replacement
```

The design predicted the fold and the prediction is refuted. The 24-bit
multiplier is reached exactly as intended and the arithmetic is exact by
construction -- `../int24-equivalence.c` agrees with the signed reference over
the whole single-lane domain and four million random word pairs -- so what E5-M
costs is the expansion itself rather than a defect.

| receipt | valu | code_size | vgprs | blocks | longest_valu_chain |
| --- | ---: | ---: | ---: | ---: | ---: |
| E5-M | 1646 | 11704 | 36 | 54 | 35 |
| E5-S0, the same shader through the extension | 1328 | 9496 | 36 | 54 | 23 |
| production FP16 dequantize | 882 | 6764 | 64 | 82 | 29 |

## What Mesa merge request 2115 does to it: nothing

The manual expansion emits no `nir_op_sdot_4x8_iadd`, so it never reaches the
case that merge request rewrites; its sixteen products fold to `v_mul_u32_u24`
through `aco_select_nir_alu.cpp`'s existing `nir_op_imul` handling. Mechanism
and hash agree: `isa-across-2115/` compiles the identical SPIR-V through the
commit immediately before the merge and through `origin/main` three merges past
it and reads the same `8896269f54...` on both.

## Scope

E5-M changes the mat-vec alone. The MMQ mat-mat and flash-attention int8
shaders keep reading `GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT`, which an E5-M
build leaves undefined, so `ggml_vk_get_mul_mat_mat_pipeline` finds an empty
pipeline set, clears `quantize_y`, and prefill and attention run the production
shape. An E5-S build compiled by an extension-capable toolchain admits those
families too, which `../README.md` registers as the wider dispatch set that arm
carries.

## Status

| stage | state | where |
| --- | --- | --- |
| arithmetic equivalence | measured | `../int24-equivalence.c` |
| SPIR-V receipt | measured | `../spirv/`, `../compile-matrix.tsv` |
| ACO ISA, Arch toolchain | measured | `isa-arch-toolchain/` |
| ACO ISA across merge request 2115 | measured, unchanged | `isa-across-2115/` |
| appliance build produces this module | unrun | the appliance's own glslc |
| runtime equality against the control | unrun | appliance |
| bracket, margin witness, served rate | unrun | appliance, and gated by `../README.md` |

E5-M's device arms run only where the combined-envelope gate in `../README.md`
admits some q8_1 path at all. A control measured on the device costs the same
arms as the hypothesis and answers a route already 318 VALU behind it, so the
lane spends device time on E5-S0 and E5-S1 first and reads E5-M against
whichever of them survives.
