# The pinned producer, and the module it compiles

The appliance's distribution shaderc prints `GL_EXT_integer_dot_product not
supported by glslc`
(`evidence/web-admission-router-tools/build-raven2-vulkan-production.log:33`),
so that host emits no packed-dot SPIR-V at all. The gate is in the producer
rather than in the driver, and this directory closes it: a pinned glslc built
into a prefix of its own compiles the Q4_K x Q8_1 mat-vec into a
content-addressed module, and the record states the compiler, the command line,
the source digest, the module digest, and the validator's verdict.

## The pin, and what it reproduces

`remote/shaderc-toolchain.tsv` names `google/shaderc` at `v2026.3`, archive
`https://github.com/google/shaderc/archive/refs/tags/v2026.3.tar.gz` at
`ee493ccf1b3038b4ef2fe024664c5eb2dc4bcc1f6b05b33e3909de0e19c81024`, measured
over the download rather than recalled.
`remote/fetch-shaderc-toolchain.sh` installs into that ledger row's `prefix`
under its own `PREFIX_ROOT`, and `build-spirv-shader-pack.sh` resolves its
default compiler through the same row and the same
`QWEN_SHADERC_PREFIX_ROOT`, so the fetch and the pack cannot name two
directories. This run passed `$HOME/.local` as the root, which is where
`qwen-shaderc-v2026.3` lives on the workstation; a run leaving the root unset
puts it under `$HOME/opt`.

`remote/fetch-shaderc-toolchain.sh "$HOME/.local"` verified that digest, ran
`utils/git-sync-deps` for the revision's own glslang and SPIRV-Tools, installed
into `qwen-shaderc-v2026.3`, and compiled its extension probe:

```text
shaderc_archive=verified sha256=ee493ccf1b3038b4ef2fe024664c5eb2dc4bcc1f6b05b33e3909de0e19c81024
shaderc_prefix=installed glslc_version=shaderc v2026.3 unknown hash, 2026-09-03 glslc_sha256=f0e11abb8ffc745bf3fc4346dd4077c726fd8b82a95576bc75ab1cfe90c956ac minimum=2023.2
shaderc_extension=accepted name=GL_EXT_integer_dot_product
```

`glslc-version.txt` carries the compiler's own three-line identity: shaderc
v2026.3, spirv-tools v2026.3, glslang 11.1.0-1493-g168d452a.

The tag is chosen by what it reproduces rather than by recency. The module this
compiler wrote is `sha256 2659f04ce6642572a017369606825384e267aaa709b222ef83b95624303ef2a1`
at 36940 bytes, which is the `spirv_sha256` and `spirv_bytes` that
`../isa-arch-toolchain/receipt.tsv`, `../isa-pre-2115/receipt.tsv`, and
`../../E5-S1/isa-post-2115/receipt.tsv` all record. The pinned prefix therefore
produces the byte-identical module every retained E5-S0 and E5-S1 ISA receipt
was measured through, so the pack carries those receipts' own subject to the
appliance rather than a second module compiled to the same description.

## The optimization setting decides the module

`vulkan-shaders-gen.cpp:352` pushes `-O` onto every shader compile, so the
served module is the optimized one. The same source under the same defines
without `-O` is 21312 bytes, which is what `../../spirv/spirv-summary.tsv`
records for this variant, and with `-O` it is 36940 -- larger, because
`spirv-opt`'s performance passes unroll the eight-iteration superblock loop.
`build-spirv-shader-pack.sh` reads `QWEN_SHADER_PACK_OPTIMIZE`, records it in
`pack-inputs.tsv` as `optimize`, and carries `-O` in the recorded command line,
so which of the two forms a pack holds follows from the record rather than from
the caller's memory. This pack sets it to 1.

## The declaration, and the source it names

`pack-declaration.tsv` names one module. Its defines are the ones
`vulkan-shaders-gen.cpp:771` merges for
`mul_mat_vec_q4_k_q8_1_f32_subgroup_no_shmem` at llama.cpp
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`: `FLOAT_TYPE=float`,
`FLOAT_TYPEV2=vec2` from `base_dict`, and `DATA_A_Q4_K=1`, `D_TYPE=float`,
`ACC_TYPE=float`, `USE_SUBGROUP_ADD_NO_SHMEM=1` beside them. The source
directory is that commit's `ggml/src/ggml-vulkan/vulkan-shaders`, and
`shader-pack.tsv` records `mul_mat_vecq.comp` at
`5c7078feed144c6b4706e25390be63a18666f27382119b11d8361fb9a7559260`. That is the
pinned shader unmodified: E5-S0 rewrites no GLSL, so
`patches/llama-vulkan-q4k-int24-mmvq.patch` reaches this module nowhere.

`spirv-val --target-env vulkan1.2` from the same prefix accepted the module,
recorded as `passed` in `shader-pack.tsv` and as
`SPIRV-Tools v2026.3 v2026.3-0-gb707790a` in `pack-inputs.tsv`.

## The dot instruction, and the name it carries

`dot-instruction-proof.tsv` is derived from the `.spvasm` beside it, and the
disassembly is what the pinned prefix's own `spirv-dis` wrote.

| field | value |
| --- | --- |
| `OpExtension` | `SPV_KHR_integer_dot_product` |
| `OpCapability DotProduct` | 1 |
| `OpCapability DotProductInput4x8BitPacked` | 1 |
| `OpSDot` | 32 |
| `OpSDot` carrying `PackedVectorFormat4x8Bit` | 32 |
| `OpUDot`, `OpSUDot` | 0 |

The string `OpSDotKHR` appears zero times, and its absence states nothing about
the instruction. SPIR-V 1.6 promoted `SPV_KHR_integer_dot_product` into the
core, so SPIRV-Tools prints opcode 4450 as `OpSDot`; `OpSDotKHR` is the same
opcode's pre-promotion alias and the disassembler no longer spells it. What
proves the instruction is the opcode carrying `PackedVectorFormat4x8Bit`
together with the `OpExtension` line and the two capabilities, all three of
which the table above reads out of this module.

Every one of the 32 is signed and packed: the module holds no `OpUDot` and no
`OpSUDot`, which is the operand signedness `nir_op_sdot_4x8_iadd` and ACO's
`emit_soft_idot_4x8` are selected by. The count is 32 rather than the 4 that
`../../spirv/spirv-summary.tsv` records for the unoptimized form because `-O`
unrolls the superblock loop eightfold; the four dots per iteration are unchanged.

## The lowering, recounted from the retained listings

Pipeline creation is `not run` here. The shimmed-RADV path needs a RADV ICD and
a version-matched `libamdgpu_noop_drm_shim.so` from one Mesa build, and this
workstation carries neither: `vulkan-radeon` is uninstalled, no
`libvulkan_radeon.so` exists anywhere on the filesystem, and the only
`libamdgpu_noop_drm_shim.so` copies sit in the trash. The rung stays open
against the appliance, and building Mesa is E5-S1's own step.

What the workstation can answer without a device is the instruction question
itself, because `remote/raven2-shader-lab/recount-isa.sh` is a reader over a
retained listing rather than a measurement. `lowering-recount.tsv` recounts the
three E5-S listings under the current schema:

| listing | `v_mul_i32_i24` | `v_add3_u32` | `v_add_u32` | `v_mul_lo_u32` |
| --- | ---: | ---: | ---: | ---: |
| E5-S0, Arch toolchain | 224 | 98 | 160 | 0 |
| E5-S0, from-source pre-2115 | 224 | 98 | 160 | 0 |
| E5-S1, post-2115 | 224 | 140 | 90 | 0 |

Both E5-S0 listings hash to `a4d5f70939...` and the E5-S1 listing to
`b9f5b4e6e2...`, the digests those receipts record, and the three moved
mnemonics reproduce the deltas `../../E5-S1/README.md` states: `v_add_u32`
160 to 90, `v_add3_u32` 98 to 140, `v_mov_b32` 20 to 17. The multiplier count is
identical across the merge and all 224 fold a byte select into both operands, so
the four byte-extract-folded 24-bit multiplies are present under either driver
and the reduction is the whole difference.

A histogram counts a kernel rather than a dot, and this one does not decompose
into one. 224 products is 56 dots, so a uniform seven-to-six trade would move
`v_add_u32` by -112 and `v_add3_u32` by +56 where the listings move -70 and +42:
ACO folds part of each reduction into the accumulate chain the dot feeds, so the
aggregate understates the per-dot change and cannot be divided by 56.
`reduction-window.txt` reads the sequence itself instead, cutting the same fifth
product and the lines after it out of both listings. E5-S1 issues the four SDWA
multiplies and reduces them through `v_add3_u32` pairs; E5-S0 issues the same
four and reaches the first partial sum through `v_add_u32_e32` before its own
`v_add3_u32`. The six-operation sequence is therefore observed in the retained
E5-S1 listing and the generic seven in the E5-S0 listing; neither is a pipeline
this session created.

## Files

| file | what it is |
| --- | --- |
| `pack-declaration.tsv` | the one declared module, its source, and its defines |
| `shader-pack.tsv` | the pack ledger: source digest, command line, module bytes and digest, `spirv-val` verdict |
| `pack-inputs.tsv` | compiler and validator identity, target environment, optimization setting, declaration and ledger digests |
| `glslc-version.txt` | the pinned compiler's own version output |
| `2659f04c....spv` | the module, retained whole at 36940 bytes |
| `2659f04c....spvasm` | its disassembly, by the pinned prefix's `spirv-dis` |
| `dot-instruction-proof.tsv` | the extension, capability, and opcode counts read out of that disassembly |
| `lowering-recount.tsv` | `recount-isa.sh` over the three retained E5-S listings |
| `reduction-window.txt` | one reduction window per lowering, cut from those listings |
