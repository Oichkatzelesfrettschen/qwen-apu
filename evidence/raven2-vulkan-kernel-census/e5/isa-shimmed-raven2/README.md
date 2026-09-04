# The E5-int24 ISA receipt, from a shimmed RAVEN2 on the workstation

Falsifier 1 reads which instructions ACO selects for
`mul_mat_vec_q4_k_q8_1_f32`. ACO is a property of Mesa rather than of silicon,
so the receipt needs a gfx902 target and no gfx902 part: RADV compiles a
compute pipeline for whichever family its device reports, and
`src/amd/drm-shim/amdgpu_noop_drm_shim.c` supplies that device from the
recorded RAVEN2 state in `src/amd/common/amdgpu_devices.c`. The shimmed node
executes no submission, so every run here ends inside
`vkCreateComputePipelines` and no arm on this page measures time.

`radv-raven2-shim-env.sh` beside this file is the wrapper, and
`remote/raven2-shader-lab/lab.sh` is the harness it wraps. Mesa 26.2 removed
the null winsys that `AMD_FORCE_FAMILY` used to reach, so the shim replaces it;
the shim and the ICD come from one release, since `ac_gpu_info.c` refuses an
amdgpu node below DRM 3.54.0 and a Mesa 25.x shim reports 3.49.0.

## The anchor: two pinned pipelines, and what it does not cover

`identity-anchor.tsv` carries it. `arms/production/` and
`arms/production-q6k/` are the pinned `mul_mat_vec_q4_k_f32_f32` and
`mul_mat_vec_q6_k_f32_f32` in the `subgroup_no_shmem` variant this device
executes, run here at the spec constants the appliance records. Both
`isa_sha256` values --
`ad837848d58d6167f3638a9d2bbbbe276f37b4cd282559f77ef42c7d03af2f61` and
`0d5c764334d364f5cf078d7507dcab32a82d5519cf9332be3558cc4bbe2a62ab` -- are the
values the appliance's own lab receipts
(`evidence/raven2-vulkan-kernel-census/e1/receipts/e4-control-nsh-receipt.tsv`
and `q6k-exec-receipt.tsv`) record, and the appliance's served
`RADV_DEBUG=shaders` disassemblies in `e1/isa/` hash to the same two values
once their retained leading `Compute Shader` stage-name line is dropped -- the
whole difference between each pair of files.

Each pair agrees through three differences. The SPIR-V differs, because the
appliance compiled the same GLSL with the shaderc its distribution ships and
this host compiled it with glslc 2026.3. The final NIR differs for the same
reason. The Mesa builds differ, `26.2.1+git2608201115` against
`26.2.1-arch3.1`. ACO emitted one instruction stream from all of it.

The anchor's scope is those two pipelines. Both take the FP16
dequantize-then-dot path: they emit `v_mac_f32` and `v_cvt_f32_ubyte*` and
neither compiles an `OpSDot` or emits an SDWA operand select. No retained
appliance artifact exercises the integer-dot lowering or the byte-select
machinery the int24 arm rests on, so what the anchor establishes is that this
host's ACO answers the appliance's ACO on the mat-vec family, and what closes
the int24 module's own identity is the appliance command the parent README
names.

The device string separates the hosts and stays verbatim:
`AMD Ryzen 5 5600X3D 6-Core Processor (RADV RAVEN2)` is the shimmed node,
`AMD Radeon Graphics (RADV RAVEN2)` the appliance.

## The three arms

Each directory holds the lab's `receipt.tsv`, `stats.tsv`, `depth.tsv`,
`isa.s`, `harness.txt`, `shaderstats.txt`, and `block-counts.txt`. The
receipt's `nir_sha256` names a `final.nir` this directory leaves out, so that
digest is a record rather than a checkable claim; `isa_sha256` covers the
retained `isa.s`.

| arm | module | source | spec |
| --- | --- | --- | --- |
| `int24` | `mul_mat_vec_q4_k_q8_1_f32_subgroup_no_shmem.spv` | `vulkan-shaders-gen` built with `GGML_VULKAN_INT24_DOT` | `0:64,1:1,2:1` |
| `extension` | the same name | `vulkan-shaders-gen` built with `GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT` | `0:64,1:1,2:1` |
| `production` | `mul_mat_vec_q4_k_f32_f32_subgroup_no_shmem.spv` | the same tree, unaffected by the patch | `0:64,1:4,2:1` |
| `production-q6k` | `mul_mat_vec_q6_k_f32_f32_subgroup_no_shmem.spv` | the same | `0:64,1:4,2:1` |

The two q8_1 arms carry `NUM_ROWS` 1 and the two production arms carry 4, which is
what `ggml-vulkan.cpp:5408` passes as `1*rm_kq_int` against `rm_kq`. A
`per_superblock` figure therefore covers a different amount of work in the
production column than in the other two, and the production arm belongs here as
the identity anchor rather than as a term in a comparison. `int24` against
`extension` is the one apples-to-apples pair: one shader, one define, one set of
spec constants.

The modules come from `vulkan-shaders-gen` rather than from a direct glslc call,
so they are the bytes a build embeds, `-O` included. That is why their SPIR-V
operation counts exceed the ones `../spirv/spirv-summary.tsv` records for the
same variant: that table compiled `mul_mat_vecq.comp` at a reduced define set
and at glslc's default optimization.

## What the ISA says

```text
                        int24   extension   production
v_mul_u32_u24             224           0            0
v_mul_i32_i24               0         224            0
v_mul_lo_u32                0           0            0
v_mad_u32_u24               0           0            0
v_mad_i32_i24               0           0            0
v_mac_f32                  14          14          248
v_cvt_f32_f16              56          56           16
sdwa_operand_uses         420         252           16
valu                     1646        1328          882
code_size               11704        9496         6764
vgprs                      36          36           64
```

`isa-mnemonics.tsv` carries the whole histogram and
`receipt-diff-extension-int24.tsv` the lab's own layer verdict, `isa_changed`
with `first_divergence=spirv` and `last_divergence=isa`.

**The 24-bit multiplier is reached, and the 32-bit multiply is absent.** All 224
products in the `int24` arm are `v_mul_u32_u24_sdwa` with `src0_sel:BYTE_n` and
`src1_sel:BYTE_n` operand selects, which is the masked-byte operand machinery
the design predicted. `v_mul_lo_u32` is zero. Falsifier 1's `v_mul_lo_u32`
clause is unmet and its product-count clause is unmet: the module's 214 `OpIMul`
reach 224 multiplies on the 24-bit unit.

**The multiply-add fold predicted by the design did not happen.** Both q8_1 arms
emit zero `v_mad_u32_u24` and zero `v_mad_i32_i24` and accumulate through
`v_add3_u32` and `v_add_u32` instead. The observed encodings read that as an
exclusion rather than a missed optimization: every product carries an SDWA
operand select, SDWA rides VOP1 and VOP2 on GFX9, and `v_mad_u32_u24` is VOP3,
so the extract fold into the multiply and the fold of the multiply into the add
cannot both apply to one instruction. ACO took the byte select. Confirming that
ordering in `aco_optimizer.cpp` is unrun; the reading rests on the encodings in
`arms/int24/isa.s`.

**`dotPacked4x8EXT` reaches the same multiplier on this part.** The `extension`
arm compiles to 224 `v_mul_i32_i24_sdwa`: ACO lowers `OpSDot` to the signed
24-bit multiply with the same byte selects and no dot-product instruction, which
is what a device reporting every `integerDotProduct*Accelerated` bit false
requires it to do. It reaches that in 1328 VALU against the rewrite's 1646, so
the rewrite costs 318 VALU, 2208 bytes of code, 168 further SDWA uses, 56
`v_and_b32`, and 56 `v_xor_b32` -- the explicit masking and the bias correction
ACO did not need -- at identical VGPR, SGPR, LDS, and scratch.

That comparison is a compiler result and not yet an argument against the arm,
because the appliance cannot compile the extension form.
`evidence/web-admission-router-tools/build-raven2-vulkan-production.log:33`
records its own build printing `GL_EXT_integer_dot_product not supported by
glslc` against `Found Vulkan ... version "1.3.275"`, so
`GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT` is OFF there and no `_q8_1` pipeline of
either form exists without the rewrite. The `extension` arm on this page was
compiled by glslc 2026.3, which the appliance does not carry. What the pair
measures is therefore the price of the rewrite against a toolchain the appliance
would have to gain, and it opens a route no arm has costed: a newer glslc, or
SPIR-V compiled elsewhere and shipped, reaches the same 24-bit multiplier in 318
fewer VALU instructions.

**`v_cvt_f32_f16` is present and does not separate the arm.** Both q8_1 arms
hold 56, the same instructions in the same places, against the production arm's
16. They decode the Q4_K `d`/`dmin` pair and the q8_1 block's own `ds` pair,
which is the FP32 tail the patch leaves byte-identical to the pinned function.
Falsifier 1 names `v_cvt_f32_f16` in the inner loop as a refutation; the count
is nonzero and identical to the arm's own reference implementation of the same
shader, so it reports the q8_1 mat-vec's scale decode rather than anything the
int24 replacement introduced. Which reading the falsifier takes belongs to the
arm's author.

## A lab defect this run exposes

`lab.sh` counts `v_mul_lo_u32`, `v_mul_u32_u24`, `v_mad_u32_u24`, and
`v_mad_i32_i24` among its named mechanisms and does not count
`v_mul_i32_i24`. The `extension` arm's 224 multiplies therefore read as zero in
every counted multiply field of `arms/extension/receipt.tsv` and of
`receipt-diff-extension-int24.tsv`, and only `isa-mnemonics.tsv`, read from
`isa.s` directly, states them. Adding the mnemonic to the receipt's mechanism
list repairs it.

## Reproducing this

```sh
# The RADV ICD and the matching drm-shim, both from Mesa 26.2.1. Neither is
# installed: `sudo pacman -Sw vulkan-radeon` populates the package cache
# without a transaction, `tar -I zstd -x` unpacks libvulkan_radeon.so and
# radeon_icd.json into a scratch directory, and the JSON's library_path is
# rewritten to the extracted object, so VK_DRIVER_FILES selects it per process
# and the host's own ICD directory is untouched. The shim is one meson target:
#   meson setup build -Dvulkan-drivers=amd -Dgallium-drivers= -Dglx=disabled \
#       -Degl=disabled -Dgbm=disabled -Dplatforms= -Dtools=drm-shim
#   ninja src/amd/drm-shim/libamdgpu_noop_drm_shim.so
#
# The modules, from the prepared candidate tree.
remote/prepare-llama-census-source.sh BASE PATCHED llama-vulkan-q4k-int24-mmvq.patch
g++ -O2 -std=c++17 -DGGML_VULKAN_INT24_DOT -o vsgen-int24 \
    PATCHED/ggml/src/ggml-vulkan/vulkan-shaders/vulkan-shaders-gen.cpp -lpthread
vsgen-int24 --glslc /usr/bin/glslc --source SHADERS/mul_mat_vecq.comp \
    --input-dir SHADERS --output-dir SPV --target-hpp SPV/gen.hpp --target-cpp SPV/gen.cpp

# The receipt.
QWEN_RADV_ICD=ICD_JSON QWEN_AMDGPU_DRM_SHIM=SHIM_SO \
    evidence/raven2-vulkan-kernel-census/e5/isa-shimmed-raven2/radv-raven2-shim-env.sh \
    remote/raven2-shader-lab/lab.sh \
    SPV/mul_mat_vec_q4_k_q8_1_f32_subgroup_no_shmem.spv OUT_DIR \
    --spec 0:64 --spec 1:1 --spec 2:1 --subgroup 64 \
    --bindings 5 --push-constants 52 --per-superblock 256
```

`radv-low-priority-env.sh` scrubs `RADV_DEBUG` and the layer variables and
leaves `VK_DRIVER_FILES`, `LD_PRELOAD`, and `AMDGPU_GPU_ID` alone, so the
wrapper's selection survives the scrub the lab applies. Each receipt's
`environment_names` line records what reached the driver.
`remote/raven2-shader-lab/` reaches this branch through
`origin/lane/shader-e4` at `8306377`; these runs used that revision.
