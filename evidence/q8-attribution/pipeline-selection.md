# Which pipeline a Q8_0 mat-vec dispatches, and from which source file

Read at `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`
(`$HOME/src/llama.cpp-census-check`, a checkout at the tree pinned by
`remote/build-llama-preset.sh` and the other `build-llama-*.sh` scripts and
verified by `git rev-parse HEAD` before every read below).

## Shader source

`ggml/src/ggml-vulkan/vulkan-shaders/vulkan-shaders-gen.cpp:737` routes a
type name through `mul_mat_vec_TYPE.comp` only for the `_k` suffix, the
`iq1_`/`iq2_`/`iq3_` prefixes, and `tq2_0`; every other type, Q8_0 included,
compiles from the shared `mul_mat_vec.comp` with `-DDATA_A_Q8_0=1`. The
dequant path for that macro is `dequant_funcs.glsl:118-125`:

```glsl
#if defined(DATA_A_Q8_0)
vec2 dequantize(uint ib, uint iqs, uint a_offset) {
    return vec2(int(data_a[a_offset + ib].qs[iqs]), int(data_a[a_offset + ib].qs[iqs + 1]));
}
vec4 dequantize4(uint ib, uint iqs, uint a_offset) {
    const i8vec2 v0 = unpack8(int32_t(data_a_packed16[a_offset + ib].qs[iqs/2])).xy;
    const i8vec2 v1 = unpack8(int32_t(data_a_packed16[a_offset + ib].qs[iqs/2 + 1])).xy;
    return vec4(v0.x, v0.y, v1.x, v1.y);
}
#endif
```

One `int()` or `unpack8` cast per pair of weights and one scale multiply per
32-weight block (`QUANT_K = 32` for Q8_0, read from `common.glsl`'s
`data_a` block declaration) is the entire unpack: no nibble split, no
high-bit fold, no packed scale-and-minimum decode. That is the mechanism
`CLAUDE.md` names when it reads the 0.8B format arm: "Q8_0 widens each
weight in one conversion," against Q4_K's nibble extraction plus scale
decode (`evidence/raven2-vulkan-kernel-census/decode-decomposition.md`,
"the pinned Q4_K path, counted").

## Pipeline construction and dispatch geometry

`ggml-vulkan.cpp:5685` and `:5713` construct the two Q8_0 mat-vec pipelines
llama.cpp ever builds for this type on any backend that lacks the `_q8_1`
path:

```cpp
ggml_vk_create_pipeline(device, ...[GGML_TYPE_Q8_0][i], "mul_mat_vec_q8_0_f32_f32",
    arr_dmmv_q8_0_f32_f32_len[reduc], arr_dmmv_q8_0_f32_f32_data[reduc], "main",
    mul_mat_vec_num_bindings, sizeof(vk_mat_vec_push_constants),
    {1*rm_stdq, 1, 1}, {wg_size_subgroup, 1*rm_stdq, i+1}, 1, true,
    use_subgroups, force_subgroup_size);
ggml_vk_create_pipeline(device, ...[GGML_TYPE_Q8_0][i], "mul_mat_vec_q8_0_f16_f32", ...);
```

No `_q8_1` variant is constructed for Q8_0 or for any type on this device;
`device->integer_dot_product` gates that family off entirely
(`evidence/tensor-type-execution-audit.md`), so these two are the whole
inventory.

Q8_0 reads its own constants rather than the K-quant family's
(`ggml-vulkan.cpp:5626-5651`):

| symbol | Q8_0 (`rm_stdq`, `wg_size_subgroup`) | Q4_K/Q5_K/Q6_K (`rm_kq`, `wg_size_subgroup16`) |
| --- | --- | --- |
| rows per invocation | `rm_stdq` | `rm_kq` |
| value on `AMD_GCN` (this device) | 2 | 4 |
| workgroup size at decode | `subgroup_size` = 64 | `subgroup_size16` = max(64, 16) = 64 |
| reduction mode at decode (`w == DMMV_WG_SIZE_SUBGROUP`) | `SHADER_REDUCTION_MODE_SUBGROUP` | `SHADER_REDUCTION_MODE_SUBGROUP` |

`device->architecture` reads `AMD_GCN` from `minSubgroupSize == maxSubgroupSize
== 64` (`evidence/tensor-type-execution-audit.md`), which is this device's own
report, so `rm_stdq = 2` and `rm_kq = 4` are not a choice made for this
audit; they are what `ggml-vulkan.cpp` already selects for every mat-vec this
device dispatches. The served spec constants for the Q8_0 `_f32_f32` pipeline
at decode are therefore `{BLOCK_SIZE=64, NUM_ROWS=2, NUM_COLS=1}`, against the
retained Q4_K receipt's `{64, 4, 1}`
(`evidence/raven2-vulkan-kernel-census/e1/receipts/q4k-exec-receipt.tsv`).
Reading a Q8_0 receipt at `NUM_ROWS=4` measures a pipeline this device never
builds.

The reduction mode agrees with the K-quant family at the decode dispatch
shape, so the same macro the retained Q4_K/Q6_K receipts compiled with
applies: `USE_SUBGROUP_ADD=1` selects `SHADER_REDUCTION_MODE_SUBGROUP`.
`remote/compile-q8-mat-vec-spv.sh` compiles both the unmarked (`SHMEM`) and
the `USE_SUBGROUP_ADD=1` (`SUBGROUP`) variant and records both; the
subgroup variant's `OpCapability` list --
`Shader, Int8, GroupNonUniform, GroupNonUniformArithmetic,
StorageBuffer16BitAccess, StorageBuffer8BitAccess` -- matches the six named
entries in the retained Q4_K and Q6_K receipts' `spirv_capabilities` field,
which is the check this document rests the macro choice on rather than an
assumption: same macro, same driver-facing request, same named capabilities.
Those two retained receipts also carry two entries their own extraction
could not name, `capability_4464` and `capability_4467`
(`shader-lab.c` prints `capability_%u` for a numeric `OpCapability` operand
it has no name for). A Q4_K module compiled on this workstation from the
same pinned source with this host's glslc (`glslc --version` reports
`2026.3`, SPIR-V target `1.4.357.0`) carries only the same six named
capabilities and neither unnamed one, so the two extra entries track the
toolchain that built the retained modules rather than the shader source;
`shape-and-receipts.md` reads that gap as open rather than resolved.

## Which of `_f32_f32` and `_f16_f32` executes

`evidence/raven2-vulkan-kernel-census/e1/README.md` records that the
accepted I1 ledger's Q4_K row names `_f32_f32` executing while
`decode-decomposition.md` and `remote/dump-radv-shader-isa.sh` name
`_f16_f32`; both take the same spec constants from different SPIR-V. No I1
census has run against a Q8_0-bearing model, so which variant the served
0.8B decode graph dispatches is not established here. `remote/compile-q8-mat-vec-spv.sh`
compiles the `_f32_f32` path (`B_TYPE=float`) to keep the comparison against
the retained Q4_K/Q6_K `_f32_f32` receipts direct; a census run against the
0.8B (Section 3, the attribution arm) settles which variant this checkpoint's
decode graph actually names, the way the ledger already settled it for the
2B.
