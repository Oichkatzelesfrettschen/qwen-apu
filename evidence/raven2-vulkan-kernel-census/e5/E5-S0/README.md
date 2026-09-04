# E5-S0: the standard packed dot through the distribution driver's own lowering

E5-S0 is the pinned `mul_mat_vecq_funcs.glsl` unmodified: `dotPacked4x8EXT`
compiled under `GL_EXT_integer_dot_product` into `OpSDotKHR`, read by RADV as
`nir_op_sdot_4x8_iadd`, and expanded by ACO's generic GFX9 path into four
24-bit multiplies and an unbalanced `v_add_u32, v_add3_u32, v_add_u32` chain.
Every layer of that stack is the interface its own specification names, so the
route travels with the toolchain rather than with this repository.

The lane's hypothesis is that this route beats the hand expansion E5-M carries,
and the receipts here measure the compiler half of it: 318 fewer VALU
instructions for the identical computation on identical silicon.

## The receipts

`isa-arch-toolchain/` is Arch's stock `vulkan-radeon`, Mesa 26.2.1-arch3.1, on a
drm-shimmed RAVEN2 node. `isa-pre-2115/` is `mesa-26-gororoba` at
`a9a5f48212bfd9c4d73be36f2d90648d1bc04c91`, the merge immediately before the
target-aware lowering landed, built from source with
`-Dvulkan-drivers=amd -Dllvm=enabled`. Both read
`isa_sha256 a4d5f70939...`, so a package driver and a from-source driver a
release apart produce one instruction stream and the reproduction pipeline --
production tree, shader compile, drm-shim, ICD json -- is answering the same
question twice.

| receipt | valu | code_size | vgprs | blocks | longest_valu_chain |
| --- | ---: | ---: | ---: | ---: | ---: |
| E5-S0 | 1328 | 9496 | 36 | 54 | 23 |
| E5-M, the manual expansion | 1646 | 11704 | 36 | 54 | 35 |
| production FP16 dequantize | 882 | 6764 | 64 | 82 | 29 |

The multiplier family is the same one E5-M reaches: 224 `v_mul_i32_i24_sdwa`
against E5-M's 224 `v_mul_u32_u24_sdwa`, at identical register occupancy. The
encoding separates them before the surrounding expansion does. All 224 products
here fold a byte select into both operands, where 56 of E5-M's read a whole
DWORD on `src0`, so the compiler's own lowering absorbs the byte extraction on
every product and the hand expansion does so on 168 of them.
`../instruction-census.tsv` carries both counts.

## What blocks this route on the appliance, and what unblocks it

The appliance's distribution shaderc rejects the extension outright
(`evidence/web-admission-router-tools/build-raven2-vulkan-production.log:33`,
Vulkan 1.3.275), so no build on that host emits `OpSDotKHR` at all. The gate is
in the SPIR-V producer rather than in the driver, so it is closed by handing the
appliance SPIR-V compiled elsewhere: `remote/build-spirv-shader-pack.sh` writes
a content-addressed pack from a pinned glslc, recording compiler identity,
command line, source digest, module digest, and the `spirv-val` verdict, and
`../README.md` carries the whole plan and the order its steps run in.

`GGML_VK_FORCE_INTEGER_DOT=1` is what admits the resulting pipelines on a device
whose acceleration bits are all false. The patch's split capability state keeps
that honest: the variable writes `integer_dot_software_lowered` and every
advertised Vulkan acceleration property stays exactly what RADV reported.

## Scope: one dispatch family, under either toolchain

An extension-capable build defines `GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT`,
which is also the compile gate on the MMQ mat-mat and flash-attention int8
shaders and on `ggml_vk_fa_scalar_uses_mmq`, so an E5-S build compiles those
where E5-M leaves them absent. They stay unreached: the patch gates each of them
on `integer_dot_accelerated`, the driver's own report, which is false on this
part, so the forced admission moves the q8_1 mat-vec alone and a bracket
compared across E5-M and E5-S measures one dispatch family on both sides. E5-S0
against E5-S1 shares the compiled set as well and differs by the driver alone,
which is why that pair is read first.

## Status

| stage | state | where |
| --- | --- | --- |
| SPIR-V receipt | measured | `../spirv/`, `../compile-matrix.tsv` |
| ACO ISA, Arch toolchain | measured | `isa-arch-toolchain/` |
| ACO ISA, from-source pre-2115 driver | measured, hash matches | `isa-pre-2115/` |
| pinned extension-capable shader pack | designed, unrun | `remote/build-spirv-shader-pack.sh` |
| appliance build consuming that pack | unrun | appliance |
| combined activation-plus-consumer envelope | unrun | appliance, the gate in `../README.md` |
| margin witness, served rate | unrun | appliance, behind that gate |
