# E5 input closure: the module, the producer, the driver, and the consumption path

The E5 candidate asks whether the Q4_K x Q8_1 mat-vec reached through
`GL_EXT_integer_dot_product` beats the FP16 dequantize path on gfx902. Everything
that decides the answer is a device measurement, and everything a device
measurement rests on is an input. This file closes the inputs on the
workstation: which compiler wrote the SPIR-V, which module it wrote, which
driver identity a device run must record, and by which lines of
`ggml-vulkan.cpp` a server selects the integer-dot pipeline on a part whose
driver reports every acceleration bit false. It states what it proves and, at
each rung, what it does not.

The one claim this file does not make is that any of it executed on Raven2. The
workstation carries an NVIDIA GeForce RTX 4070 Ti and no AMD device, no
`libvulkan_radeon.so` outside container and flatpak trees, and no prefix
`remote/build-isolated-radv.sh` created. `remote/run-e5-module-proof.sh` reads
`QWEN_RADV_ICD` and `LD_LIBRARY_PATH` out of the isolated driver's environment
fragment by name and leaves `QWEN_AMDGPU_DRM_SHIM` behind precisely so a run
against a faked RAVEN2 node cannot report `module_identity=proven`. The proof is
therefore `not run` here by its own design rather than by an omission, and the
Raven2 order at the end of this file is what a device agent executes.

## 1. The pinned shader producer, by digest

`remote/shaderc-toolchain.tsv` is the one authority that names it:
`google/shaderc` at `v2026.3`, archive
`https://github.com/google/shaderc/archive/refs/tags/v2026.3.tar.gz` at
`ee493ccf1b3038b4ef2fe024664c5eb2dc4bcc1f6b05b33e3909de0e19c81024`, installed by
`remote/fetch-shaderc-toolchain.sh` into the prefix `qwen-shaderc-v2026.3` under
its own `PREFIX_ROOT`. The pin exists because the appliance's distribution
shaderc prints `GL_EXT_integer_dot_product not supported by glslc`
(`evidence/web-admission-router-tools/build-raven2-vulkan-production.log:33`), so
the gate that would keep E5 off the device sits in the producer rather than in
the driver.

The installed prefix on the workstation is `$HOME/.local/qwen-shaderc-v2026.3`,
and the three executables this lane reads carry these digests, measured over the
installed files:

| executable | version string | sha256 |
| --- | --- | --- |
| `bin/glslc` | `shaderc v2026.3 unknown hash, 2026-09-03` | `f0e11abb8ffc745bf3fc4346dd4077c726fd8b82a95576bc75ab1cfe90c956ac` |
| `bin/spirv-val` | `SPIRV-Tools v2026.3 v2026.3-0-gb707790a` | `e9bce1b49be5d1144f051e3b629d9bcc7ed7deeebc691594fdff881fec54fedc` |
| `bin/spirv-dis` | `SPIRV-Tools v2026.3 v2026.3-0-gb707790a` | `e92633c912e4bfcbc4256287389737cbac557e8287e905d5ca23befc8d0deff3` |

`glslc-version.txt` beside the pack carries the compiler's own three-line
identity, which names glslang `11.1.0-1493-g168d452a` as the front end shaderc
vendored at that revision. The archive digest pins shaderc alone;
`utils/git-sync-deps` resolves glslang, SPIRV-Tools, and SPIRV-Headers from that
revision's own DEPS at fetch time, so the built compiler's identity is what the
two digests above record after the fact rather than what the ledger predicted.

The producer identity is reproduced rather than recalled. Regenerating the pack
on the workstation from `remote/build-spirv-shader-pack.sh` against the
committed declaration and the pinned source directory wrote
`pack_sha256=3322a9a1eaeb0809de2981b736ae7ea2cfa987d93b8caf474deb022d336722e6`,
which equals the `pack_sha256` in the committed
`E5-S0/shader-pack/pack-inputs.tsv`, with `validation=passed` and the same
`glslc_sha256`. The pinned prefix therefore still writes the module every
retained E5-S receipt was measured through.

## 2. The validated shader pack

`evidence/raven2-vulkan-kernel-census/e5/E5-S0/shader-pack/` is the pack, and it
carries the tables rather than this file: `shader-pack.tsv` is the module ledger,
`pack-inputs.tsv` the producer and validator identity, `dot-instruction-proof.tsv`
the opcode reading, and `2659f04c....spv` the module itself at 36940 bytes. One
module is declared, and the reason it is one rather than three is a fact about
the consumption path rather than about the pack.

```text
module           mul_mat_vec_q4_k_q8_1_f32_subgroup_no_shmem
source           ggml/src/ggml-vulkan/vulkan-shaders/mul_mat_vecq.comp at
                 llama.cpp f280b26983ad0fdb705a0d9ebf0503e76f2899b0,
                 sha256 5c7078feed144c6b4706e25390be63a18666f27382119b11d8361fb9a7559260
                 (recomputed over the commit's own tree on the workstation)
defines          FLOAT_TYPE=float FLOAT_TYPEV2=vec2 DATA_A_Q4_K=1 D_TYPE=float
                 ACC_TYPE=float USE_SUBGROUP_ADD_NO_SHMEM=1
target           vulkan1.2, compiled with -O
spirv_bytes      36940
spirv_sha256     2659f04ce6642572a017369606825384e267aaa709b222ef83b95624303ef2a1
spirv-val        passed, SPIRV-Tools v2026.3 v2026.3-0-gb707790a
```

`dot-instruction-proof.tsv` reads the instruction out of that module's own
disassembly: `OpExtension SPV_KHR_integer_dot_product`, `OpCapability
DotProduct`, `OpCapability DotProductInput4x8BitPacked`, and 32 `OpSDot`, all 32
carrying `PackedVectorFormat4x8Bit`, with zero `OpUDot` and zero `OpSUDot`. The
string `OpSDotKHR` appears zero times and its absence states nothing: SPIR-V 1.6
promoted the extension into the core, so SPIRV-Tools prints opcode 4450 as
`OpSDot` and `OpSDotKHR` is the same opcode's pre-promotion alias. Signedness is
what selects `nir_op_sdot_4x8_iadd` and ACO's `emit_soft_idot_4x8`, and the
module holds only the signed packed form.

The 32 dots are the eightfold unroll of four dots per superblock iteration that
`-O` produces; the unoptimized form of the same source and defines is 21312
bytes with 4 dots, recorded in `../spirv/spirv-summary.tsv`.
`vulkan-shaders-gen.cpp:352` compiles every ggml shader with `-O`, so the
optimized form is the served one.

### Why one module rather than three

`vulkan-shaders-gen.cpp:769-771` emits three SPIR-V variants of
`mul_mat_vec_q4_k_q8_1_f32` from one source: the plain shared-memory reduction,
`_subgroup`, and `_subgroup_no_shmem`. `ggml-vulkan.cpp:1261-1262`'s generated
array orders them `{plain, _subgroup, _subgroup_no_shmem}`, which the
`shader_reduction_mode` enum at `:619-622` indexes as SHMEM, HYBRID, SUBGROUP.
`ggml_vk_load_shaders` at `:5232-5234` selects SUBGROUP for
`w == DMMV_WG_SIZE_SUBGROUP` and HYBRID for `w == DMMV_WG_SIZE_LARGE` on a
device reporting subgroup arithmetic, so a Raven2 launch creates two distinct
q4_k q8_1 modules across the two workgroup-size tables.

Dispatch selects one of them, and on AMD it is always the same one.
`ggml_vk_get_dequantize_mul_mat_vec` at `:7824-7845` raises `dmmv_wg` to
`DMMV_WG_SIZE_LARGE` only for NVIDIA past Turing and for Intel, and pins Intel
back to SUBGROUP for a Q8_1 right-hand side; on AMD `dmmv_wg` never leaves
`DMMV_WG_SIZE_SUBGROUP`, so `pipeline_dequant_mul_mat_vec_q8_1_f32[dmmv_wg][...]`
resolves to the SUBGROUP reduction and the executed module is the
`_subgroup_no_shmem` one the pack declares. The pack's single module is
therefore the whole of what Raven2 executes for this family, and the second
created module is never dispatched.

`run-e5-module-proof.sh` already accepts where any created pipeline of the
`mul_mat_vec_q4_k_q8_1` prefix carries the pack's digest and byte count, which is
the right rule against a family that creates several: the HYBRID variant's
presence is not a refutation. What the two created modules do change is the ISA
reading, and that is the harness gap this rung closed -- see section 6.

## 3. The isolated RADV identity: not run, and the fields a run must record

`not run: the workstation carries no AMD device, no prefix
build-isolated-radv.sh created, and the proof refuses the drm shim by
construction.` The observed facts behind that reason: `vulkaninfo --summary`
reports one device, `NVIDIA GeForce RTX 4070 Ti` under `driverName NVIDIA`;
`lspci` lists one VGA controller, `10de:2782`; no `qwen-radv-*` prefix exists
under any prefix root; and every `libvulkan_radeon.so` on the filesystem belongs
to a container overlay, a flatpak runtime, or an unrelated Mesa 25.2.6 build tree
rather than to a build of the pinned revision.

The identity a device run records is fixed by
`remote/build-isolated-radv.sh` and read back by
`remote/run-e5-module-proof.sh`, so it is stated here as the closure rather than
left to the run:

```text
revision          9ae8ce550453b9e19f14dc1c9a41b913a9005e48, required to equal
                  the checkout's own HEAD
lowering_merge    f1078c57e5f02b611f2c69af9ac7e0f5aa82a0bb, Mesa merge request
                  2115 as merged; the revision must descend from it, since a
                  driver without it lowers nir_op_sdot_4x8_iadd generically and
                  would measure E5-S0 under E5-S1's name
receipt           PREFIX/radv-build.tsv, schema isolated-radv-v1, carrying
                  revision, lowering_merge, and icd_sha256
icd               PREFIX/.../radeon_devenv_icd.x86_64.json, whose library_path
                  must resolve inside PREFIX; the proof exits 2 where it does
                  not, since a devenv json pointing at the system driver would
                  serve the system driver under this prefix's name
digests           inputs.tsv records radv_icd_sha256 and radv_library_sha256,
                  measured over the ICD and the libvulkan_radeon.so it names
build requirement -Dllvm=enabled, for the disassembler rather than for ACO:
                  without it RADV prints pre-RA IR that the lab's mnemonic
                  counter reads as zero in every field
```

`E5-S1/aco-lowering-provenance.md` is the branch account of the two drivers the
workstation receipts were taken through, `a9a5f48212bfd9c4d73be36f2d90648d1bc04c91`
pre-2115 and `9ae8ce550453b9e19f14dc1c9a41b913a9005e48` post-2115. Those runs
used a drm-shimmed node, so they establish what ACO does with the module and
nothing about what this silicon does with it.

## 4. The consumption path: how a server selects the integer-dot pipeline

Three gates decide whether the module reaches a dispatch, and they are three
different claims at three different places. Two of them live at
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`; the third is a property of
`patches/llama-vulkan-q4k-int24-mmvq.patch` rather than of the commit, and
reading the two together is the one way this account could mislead.

### 4a. Creation, at f280b269, admits nothing on Raven2

`ggml-vulkan.cpp:828` declares one `bool integer_dot_product` on the device.
`:6247-6249` sets it true where `VK_KHR_shader_integer_dot_product` is present
and `GGML_VK_DISABLE_INTEGER_DOT_PRODUCT` is unset, inside
`#if defined(GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT)`. `:6449` then reduces it:

```c
device->integer_dot_product = device->integer_dot_product &&
    shader_integer_dot_product_props.integerDotProduct4x8BitPackedSignedAccelerated;
```

RADV reports that property false on Raven2, so the field is false. `:5297-5318`
guards the whole q8_1 mat-vec pipeline table on `if (device->integer_dot_product)`,
so no `mul_mat_vec_q4_k_q8_1_f32` pipeline is created at all, and `:9554` and
`:10453` guard `quantize_y` on the same field, so no activation quantizer runs.
This is why the deployed production `llama-server` holds no
`mul_mat_vec_q4_k_q8_1` symbol.

At this commit there is no environment override and no confinement: the same one
bool also guards the MMQ mat-mat `quantize_y` at `:9221` and `:10157` and
`ggml_vk_fa_scalar_uses_mmq` at `:4132-4145`. Forcing that single bool true would
admit four dispatch families at once, three of which E5 measures no replacement
for, and a bracket read across arms would then compare different dispatch sets.

### 4b. Confinement, from patches/llama-vulkan-q4k-int24-mmvq.patch

The patch is what makes an override measurable. It replaces the one bool with
four fields and routes each consumer to the field that states its own claim:

```text
integer_dot_functional         the extension is present and shaderIntegerDotProduct
                               is reported; gates the device-extension request
integer_dot_accelerated        integerDotProduct4x8BitPackedSignedAccelerated
                               verbatim from the driver, written by nothing in
                               the build
integer_dot_software_lowered   functional and not accelerated and
                               GGML_VK_FORCE_INTEGER_DOT=1; this build's own claim
integer_dot_pipeline_selected  accelerated or software_lowered
```

The routing, read off the patch's own hunks:

| consumer | field it reads |
| --- | --- |
| q8_1 mat-vec pipeline table (`ggml_vk_load_shaders`, both `w`) | `integer_dot_pipeline_selected` |
| q8_1 mat-vec-id pipeline table | `integer_dot_pipeline_selected` |
| mat-vec `quantize_y` (`ggml_vk_mul_mat_vec_q_f16`, `..._id_q_f16`) | `integer_dot_pipeline_selected` |
| mat-mat `quantize_y` (`ggml_vk_mul_mat_q_f16`, `..._id_q_f16`) | `integer_dot_accelerated` |
| `ggml_vk_fa_scalar_uses_mmq` | `integer_dot_accelerated` |
| device-extension request | `integer_dot_functional` |

So the override reaches the q8_1 mat-vec pipelines and their two `quantize_y`
dispatches and stops there. The MMQ mat-mat families and scalar flash attention
keep the production shape under every arm, and every advertised Vulkan
acceleration property still reads exactly what RADV reported. The patch also
renames the compile guard to `GGML_VULKAN_MMVQ_Q8_1_SHADERS`, so the q8_1
shaders' presence is a build fact separate from the driver's acceleration claim.

`ggml_vk_force_integer_dot()` reads `GGML_VK_FORCE_INTEGER_DOT` once per process
through a function-local static and requires the exact string `1`, so an
accidental `0` reads as the default rather than as an arm and one process cannot
hold two pipeline tables for one shader set.

### 4c. Dispatch, at f280b269, and the share it reaches

Creation is not selection. `:9554` reaches the q8_1 mat-vec only where
`ggml_vk_should_use_mmvq(device, ne01, ne11, ne10, src0->type)` also returns
true, and that function at `:9434-9481` decides per call:

- `mmvq_mode == 1` (`GGML_VK_FORCE_MMVQ`) returns true outright; `-1`
  (`GGML_VK_DISABLE_MMVQ`) returns false. Neither is set by the E5 arm.
- Q6_K returns false on every vendor but Intel, so the 2B distill's 50.08% Q6_K
  by byte stays on the FP16 path whatever the override says.
- `n > 1` returns true. Decode is `n == 1`, so the batch clause does not apply.
- On `VK_VENDOR_ID_AMD` the comparison is `if (k < 2048) return false;`, strictly
  less than. A `k` of exactly 2048 passes. Q4_K then falls to the `default:
  return true` of the type switch, since only Q8_0 is special-cased there.

The strictness matters and it is stated here because it decides the reachable
share rather than a footnote. The 2B distill is 2048 wide with a 6144
feed-forward, so its Q4_K attention projections at `k = 2048` and its
feed-forward tensors at `k = 2048` and `k = 6144` all satisfy `k >= 2048` and all
reach the q8_1 mat-vec under the override. Had the comparison been `k <= 2048`,
the 2048-wide half of the trunk would have stayed on the FP16 path and the arm
would have measured the feed-forward down-projection alone.

The whole-token ceiling for the arm is therefore the Q4_K share of streamed
bytes at decode, not the 83% the FP16 family holds and not the 100% an
unconfined override would touch. `evidence/tensor-type-execution-audit.md`
carries the type shares.

### 4d. The two names an arm must set

The override is `GGML_VK_FORCE_INTEGER_DOT=1` at the backend.
`remote/radv-low-priority-env.sh` unsets every `GGML_VK_*` name before its
profile case runs, so that name alone reaches no served process: the served E5
comparison was structurally unmeasurable once for exactly this reason.
`QWEN_FORCE_INTEGER_DOT=1` is the name that crosses the scrub, admitting the
exact `1` and refusing any other value, and `qwen-webui-control.sh` forwards it
across the tmux boundary. A served arm sets the `QWEN_` name; the standalone
collector `remote/dump-radv-shader-isa.sh` reads `GGML_VK_FORCE_INTEGER_DOT`
directly, which is what `run-e5-module-proof.sh` exports.

### 4e. The producer pin decides whether the pipeline exists at all

`ggml/src/ggml-vulkan/CMakeLists.txt` runs `test_shader_extension_support` at
configure time and `find_package(Vulkan COMPONENTS glslc REQUIRED)` caches
`Vulkan_GLSLC_EXECUTABLE`, so a distribution glslc leaves
`GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT` off and the build emits no q8_1 mat-vec
variant, quietly and without an error. `remote/build-llama-e5.sh` closes that by
putting the pinned prefix on `PATH`, comparing the cached compiler against the
pin before and after the build, and requiring the built server to name
`mul_mat_vec_q4_k_q8_1_f32`.

That recipe ran on the workstation against a clean `f280b269` checkout and
accepted:

```text
preset            raven2-vulkan-census
candidate_series  llama-vulkan-pipeline-census.patch,
                  llama-vulkan-q4k-int24-mmvq.patch
source_commit     f280b26983ad0fdb705a0d9ebf0503e76f2899b0
glslc             the pinned prefix, sha256 f0e11abb8ffc745b...
server_sha256     772b8744b8db5cca4e996015da1b0f3ed5a7d5a228c60a95985764d6fcde71ed
server_bytes      70524736
q8_1_pipeline_named  mul_mat_vec_q4_k_q8_1_f32
```

The pinned producer therefore turns the compile guard on and the q8_1 mat-vec
family reaches the binary, which is the one thing this rung's build proves. The
binary is a workstation artifact: it links against this host's glibc and was
never run, and the device rung builds its own on the appliance.

## 5. The standalone shader receipt, and what it does not prove

```text
receipt          the pinned producer at glslc sha256 f0e11abb8ffc745b...
                 compiled mul_mat_vecq.comp at source sha256 5c7078feed144c6b...
                 under the six declared defines, target vulkan1.2, -O, into a
                 36940-byte module at sha256 2659f04ce6642572...
                 spirv-val at sha256 e9bce1b49be5d114... accepted it.
                 The module holds SPV_KHR_integer_dot_product, both packed-dot
                 capabilities, and 32 signed packed 4x8 dots.
                 Regenerating the pack on the workstation reproduced
                 pack_sha256 3322a9a1eaeb0809... bit for bit.
proves           that a module computing the Q4_K x Q8_1 mat-vec through the
                 standard packed integer dot exists, validates, and is
                 reproducible from a pinned producer.
proves not       that any device created a pipeline from it, that Raven2's ACO
                 lowered it to the six-operation sequence, that the arithmetic
                 agrees with the FP16 path, or that any of it is faster.
                 Compilation is not selection and selection is not execution.
                 A shader receipt is an input to the ladder in section 7 and
                 answers none of its rungs.
```

## 6. The harness gap this rung found, and the fix

`remote/summarize-radv-isa.py` records that RADV names every compute shader
`Compute Shader` in its own dump and carries no ggml pipeline name, so
`isa-index.tsv` is content-derived and the module proof selects the q8_1 mat-vec
listing by expansion shape: the first row whose `v_mul_i32_i24` equals the 224
products every E5-S receipt records. Section 2 shows the family creates two
distinct q4_k q8_1 modules on Raven2, the SUBGROUP and HYBRID reductions of one
source, and both expand the same 224 products while their reductions differ. The
first-match-and-exit selection therefore returned whichever listing compiled
first, and `aco_lowering` -- the field the ladder's falsifier 2 is read from --
followed compile order rather than the executed shader.

`remote/run-e5-module-proof.sh` now counts every candidate row and the distinct
`v_add3_u32` values among them, records both in `verdict.tsv` as
`aco_candidate_rows` and `aco_candidate_reductions`, and reads
`aco_lowering=ambiguous` where the candidates disagree. Module identity stays
`proven` in that case and the arm still exits 0, because the module is the same
under either reduction and the design records the lowering rather than gating on
it; what changes is that a device agent reading `mr2115` now knows the reading
was unique. `remote/test-run-e5-module-proof.sh` drives a unique match, two
agreeing candidates, and two disagreeing candidates against a fake collector with
no device, and the existing `test-run-e5-module-proof` gate cell covers it.

## 7. The Raven2 order, and the falsifiers it is open against

This ordering governs the device rungs and supersedes the seven-item list in
`README.md` for the two rungs it names, because that list was written before the
module proof existed and folds pipeline creation and executed ISA into one item
that two separate artifacts now answer. Items 3 through 7 of that list are
unchanged and follow this one; the arithmetic, witness, bracket, envelope, and
served rungs keep their registered contracts.

Four classes are measured, in this order, and each costs more device time than
the one above it.

```text
E5-S0   the stock system RADV on the appliance, one arm
E5-S1   the isolated RADV at 9ae8ce55 through QWEN_RADV_ICD, the same arm
```

E5-S0 runs first because a refusal there is a refusal for both, and E5-S1 is
read against it with the module byte-identical and the driver the only thing
moved.

**Class 1, pipeline selection and executed ISA.**
`remote/run-e5-module-proof.sh OUTPUT SERVER MODEL RADV_PREFIX`, with
`GGML_VK_FORCE_INTEGER_DOT=1` exported by the script.

```text
prediction  The armed build creates at least one mul_mat_vec_q4_k_q8_1 pipeline
            whose census_spirv_source_sha256 is 2659f04ce6642572... at 36940
            bytes, and the appliance's ACO expands it to 224 v_mul_i32_i24
            products with zero v_mul_lo_u32 beside them: 98 v_add3_u32 under
            E5-S0's stock driver and 140 under E5-S1's isolated one.
falsifier   No pipeline of the family is created, or none carries the pack's
            digest and byte count, or no listing carries the 224-product
            expansion. Each ends the rung with exit 3 and a terminal-state.tsv
            naming the field that moved, and no later rung runs.
recorded    aco_lowering reading generic, other, or ambiguous is a result rather
            than a refusal. `generic` on E5-S1 refutes the isolation rather than
            the module; `ambiguous` means aco_candidate_reductions exceeded one
            and the reading is undetermined, which is repaired by reading the
            two listings' reduction windows by hand rather than by a rerun.
            v_mul_lo_u32 above zero meets the ladder's falsifier 2 second clause
            and refutes the mechanism at the compiler.
```

**Class 2, integer-lowering arithmetic.** Only where class 1 accepts.
`remote/run-kernel-delta-witness.sh` under `QWEN_WITNESS_CONTRACT=margin`, with
`QWEN_WITNESS_CANDIDATE_FORCE_INTEGER_DOT=1` carrying the selection into that
harness's closed environment -- without it the witness compares one shader
against itself.

```text
prediction  The Q4_K dot computed through OpSDot agrees with dotPacked4x8EXT's
            defined result over the operand domain the test drives, since the
            E5-S paths compute the extension's own operation and the driver's
            lowering is what is under test rather than a rewrite.
falsifier   The armed and unarmed binaries disagree on the dot itself, as
            distinct from the activation quantization of class 3. A disagreement
            here refutes the driver's lowering and ends the candidate.
```

**Class 3, activation-quantization numerics.** The q8_1 activation quantizer is a
numeric change the design accepted in advance, so token identity decides nothing
and the registered `margin` contract decides instead.

```text
prediction  The top-k margin witness reads `holds` under
            QWEN_WITNESS_CONTRACT=margin.
falsifier   The witness reads `differs`. This is the ladder's falsifier 4 and it
            is about quantize_q8_1_x4 rather than about the dot, so it is
            reported against the quantizer and not against the lowering.
```

**Class 4, timing.** Only where classes 1 through 3 pass, and read as one
envelope rather than as a consumer alone.

```text
prediction  quantize_q8_1_x4 and mul_mat_vec_q4_k_q8_1_f32 read together are a
            shorter GPU envelope than the best E4-plus-scale-word-select
            candidate on the FP16 path.
falsifier   The combined envelope reads unchanged or lengthened. A route whose
            consumer shortens while its producer eats the gain is refuted here;
            reading the consumer alone is the error this gate exists to prevent.
            The served A/B under the scoreboard tuple runs only where this
            envelope is shorter, and leaving the 2B's one-sided 5% promotion
            bound unmet closes the candidate.
non-falsifier
            E5-S1's longest dependent-VALU chain is 24 against E5-S0's 23 across
            identical 54 blocks, so a bracket that fails to shorten while VALU
            falls 2.3% is the predicted consequence of trading an add tree for
            two serially dependent v_add3_u32 reductions and refutes nothing on
            its own. int8 through a software dot costs about 1.375 VALU per MAC
            where FP16 dot2 with FP32 accumulation costs about 1.0, so the
            instruction tables order the three q8_1 paths against each other and
            decide nothing against the FP16 anchor.
```

**The combined envelope is what closes the candidate.** A losing envelope in
class 4 ends E5 for both driver arms, because the two arms differ by 31 VALU
instructions out of 1297 and no driver change recovers a producer cost the
consumer never earns back. E5-S0 losing while E5-S1 wins keeps the candidate
alive against the isolated driver alone, which is a deployment question rather
than a mechanism question and is decided by whether the appliance carries the
isolated ICD.

## 8. Status of every input

| input | state | where |
| --- | --- | --- |
| producer pinned and its digest reproduced | measured, workstation | `remote/shaderc-toolchain.tsv`, section 1 |
| pack regenerated bit for bit from the pin | measured, workstation | section 1, `pack_sha256 3322a9a1...` |
| module validated, its dot instruction read | measured, workstation | `E5-S0/shader-pack/` |
| source digest recomputed at f280b269 | measured, workstation | section 2 |
| one dispatched module rather than three | measured by source reading | section 2, `ggml-vulkan.cpp:7824-7845` |
| creation, confinement, dispatch lines | measured by source reading | section 4 |
| `k < 2048` strictness on AMD | measured by source reading | `ggml-vulkan.cpp:9472` |
| isolated RADV identity | not run: no AMD device on the workstation | section 3 |
| module-and-driver proof on the appliance | not run: same reason | section 7, class 1 |
| E5 build recipe emits the q8_1 pipeline | measured, workstation | section 4e |
| arithmetic, witness, envelope, served rate | unrun | section 7, classes 2 through 4 |
