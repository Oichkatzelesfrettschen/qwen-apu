# E4 in SPIR-V: sixty fused multiply-adds leave, twenty-four adds arrive, and nothing else moves

`patches/llama-vulkan-q4k-activation-group-sums.patch` reassociates the Q4_K
minimum term in `mul_mat_vec_q4_k.comp`. Compiling the control and the patched
source with the glslc and the defines the build itself uses, then freezing the
served specialization constants and optimizing, leaves exactly two opcodes
changed in the whole module: `OpExtInst GLSL.std.450 Fma` falls from 160 to 100
and `OpFAdd` rises from 15 to 39. Every other opcode in the function bodies is
equal, including `OpLoad` at 109, `OpStore` at 39, `OpAccessChain` at 117,
`OpCompositeExtract` at 166, `OpIAdd` at 76, `OpFMul` at 30, and
`OpControlBarrier` at 4. The patch is an arithmetic change and carries no
addressing, memory, or synchronization cost at the SPIR-V level.

## The compile reproduces the build byte for byte

Both build trees set `Vulkan_GLSLC_EXECUTABLE:FILEPATH=/usr/bin/glslc`, glslc
2026.3 from the 1.4.357.0 SDK. `string_to_spv_func` in
`ggml/src/ggml-vulkan/vulkan-shaders/vulkan-shaders-gen.cpp` builds the command
as `-fshader-stage=compute`, `--target-env=vulkan1.2` for every name without
`_cm2`, `-O` for every name without `bf16`, `rope`, `_dot2`, or coopmat, and one
`-D` per entry of the merged dictionary. The dequantize-mat-vec dictionary is
`{FLOAT_TYPE, FLOAT_TYPEV2}` merged with `{DATA_A_Q4_K, B_TYPE, B_TYPEV2,
B_TYPEV4, D_TYPE}` for the `_f32_f32` variant, seven defines total:

```sh
CONTROL=$HOME/src/llama.cpp-census/ggml/src/ggml-vulkan/vulkan-shaders
E4=$HOME/src/llama.cpp-e4/ggml/src/ggml-vulkan/vulkan-shaders
DEFS="-DDATA_A_Q4_K=1 -DFLOAT_TYPE=float -DFLOAT_TYPEV2=vec2 \
      -DB_TYPE=float -DB_TYPEV2=vec2 -DB_TYPEV4=vec4 -DD_TYPE=float"

glslc -fshader-stage=compute --target-env=vulkan1.2 \
    "$CONTROL/mul_mat_vec_q4_k.comp" -o "$OUT/control.spv" -O $DEFS
glslc -fshader-stage=compute --target-env=vulkan1.2 \
    "$E4/mul_mat_vec_q4_k.comp"      -o "$OUT/e4.spv"      -O $DEFS

# the same two commands with -O removed produce the pre-optimizer pair
glslc -fshader-stage=compute --target-env=vulkan1.2 \
    "$CONTROL/mul_mat_vec_q4_k.comp" -o "$OUT/control.noopt.spv" $DEFS
glslc -fshader-stage=compute --target-env=vulkan1.2 \
    "$E4/mul_mat_vec_q4_k.comp"      -o "$OUT/e4.noopt.spv"      $DEFS

# the served specialization, applied to the shipped module the way a driver does
for arm in control e4; do
    spirv-opt --set-spec-const-default-value "0:64 1:4 2:1" --freeze-spec-const -O \
        "$OUT/$arm.spv" -o "$OUT/$arm-spec-64-4-1.spv"
    spirv-dis --no-color "$OUT/$arm-spec-64-4-1.spv" \
        -o "$OUT/$arm-spec-64-4-1.spvasm"
done
```

| module | SHA-256 |
| --- | --- |
| `control.spv` (shipped, `-O`) | `ab0d087f463e87e21cefb8707b0cd41a452074492293263db66cc642b32b48b4` |
| `e4.spv` (shipped, `-O`) | `7b425720b46ed355b8b1405df0237e386d063a21eed9ed4dec6f4e188f308c2c` |
| `control.noopt.spv` | `851d82f4158c679cca9c8b66fe5469a0d757176f186ca0110ed6ca85548a1387` |
| `e4.noopt.spv` | `58da0b6f10dbc7f0e8312edc2de767e93e5a36ce91ecf0e7e8a4da5e852a9b33` |
| `control-spec-64-4-1.spv` | `03bd866dd4622b96a487160344679015444e5a0341759970171674fe6aa54c35` |
| `e4-spec-64-4-1.spv` | `2b169e27eb7990cb76e77feb6968b9a816f7c1f32025b523554e64dadd7bc658` |

The first two digests equal the modules the builds generated on their own,
`build-census/ggml/src/ggml-vulkan/vulkan-shaders.spv/mul_mat_vec_q4_k_f32_f32.spv`
and the same path under `build-e4`, so the command line above is the build's own
and the comparison reads the executed module rather than a re-derivation of it.

The specialization is `0:64 1:4 2:1`: `BLOCK_SIZE = 64`, `NUM_ROWS = 4`,
`NUM_COLS = 1`, which the accepted decode ledger records as
`constants=64,4,1` beside `subgroup=64` for `mul_mat_vec_q4_k_f32_f32`.
`ggml-vulkan.cpp` produces it from `rm_kq = 4` on the `AMD_GCN` branch. The
activation is FP32 by two authorities: the generator sets `B_TYPE=float` for
the `_f32_f32` variant, and the ledger names that pipeline as the one the
appliance dispatches 162 times per decode graph.

Retained here: `control.spvasm` and `e4.spvasm` are the shipped `-O` modules,
`control-spec-64-4-1.spvasm` and `e4-spec-64-4-1.spvasm` the specialized pair.

## Opcode histogram

Whole-module static counts. `OpExtInst` in this module is `GLSL.std.450 Fma` in
every instance. `OpVectorShuffle` is absent from all six modules.

| opcode | control, no `-O` | E4, no `-O` | control `-O` | E4 `-O` | control spec+`-O` | E4 spec+`-O` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `OpExtInst` Fma | 32 | 20 | 64 | 40 | 160 | 100 |
| `OpFAdd` | 3 | 15 | 6 | 30 | 15 | 39 |
| `OpFMul` | 6 | 6 | 12 | 12 | 30 | 30 |
| `OpFNegate` | 1 | 1 | 2 | 2 | 5 | 5 |
| `OpIAdd` | 51 | 62 | 80 | 92 | 76 | 76 |
| `OpIMul` | 20 | 24 | 30 | 34 | 30 | 30 |
| `OpUDiv` | 14 | 18 | 22 | 26 | 22 | 22 |
| `OpShiftRightLogical` | 4 | 4 | 8 | 8 | 17 | 17 |
| `OpShiftLeftLogical` | 2 | 2 | 4 | 4 | 10 | 10 |
| `OpBitwiseAnd` | 9 | 9 | 18 | 18 | 39 | 39 |
| `OpLoad` | 271 | 289 | 68 | 84 | 109 | 109 |
| `OpStore` | 111 | 121 | 16 | 24 | 39 | 39 |
| `OpAccessChain` | 111 | 127 | 72 | 96 | 117 | 117 |
| `OpCompositeExtract` | 0 | 0 | 84 | 116 | 166 | 166 |
| `OpVectorShuffle` | 0 | 0 | 0 | 0 | 0 | 0 |
| `OpControlBarrier` | 2 | 2 | 4 | 4 | 4 | 4 |
| `OpVariable` | 106 | 112 | 15 | 17 | 14 | 14 |
| `OpTypeArray` | 11 | 13 | 11 | 13 | 11 | 11 |
| `OpLoopMerge` | 12 | 13 | 24 | 26 | 11 | 11 |
| function-body instructions | 979 | 1060 | 872 | 992 | 1173 | 1137 |

Reading the columns in order:

**Before `-O`, the histogram counts source expressions.** `NUM_COLS` and
`NUM_ROWS` are specialization constants, so glslc unrolls neither the row loop
nor the column loop and each opcode is counted once per written expression. The
control's 32 `Fma` are the `smin` term's 15, the four partial dot products' 12,
and the accumulate line's 5. E4's 20 are the same 12 and 5 with the minimum
term's 15 reduced to 3, and its 12 new `OpFAdd` are the three additions per
group sum. Twelve `Fma` leave and twelve `FAdd` arrive, one for one.

**The `-O` column doubles the arithmetic and collapses the memory.** `main` has
two call sites, `compute_outputs(first_row, NUM_ROWS)` and
`compute_outputs(first_row, p.stride_d - first_row)`, and spirv-opt inlines
both, so every arithmetic count doubles. The memory counts fall instead, because
the same pass promotes the function-local variables to SSA values: `OpLoad` 271
to 68, `OpStore` 111 to 16, `OpVariable` 106 to 15 in the control.
The redundant sixteen-term expansion survives `-O` intact: 64 `Fma` against the
E4 module's 40. `OpCompositeExtract` appears here because inlining lets the
optimizer replace vector loads with component extracts, and it does so 84 times
in the control and 116 in E4 -- the difference is the private
`by_group_sum[NUM_COLS][4]` array, which the E4 column also shows as
`OpTypeArray` 13 against 11 and `OpVariable` 17 against 15.

**Freezing the specialization erases every structural difference.** With
`NUM_ROWS = 4` known, the first call site's `n` loop unrolls to four row bodies
and the private array scalarizes away. The two modules then differ in `OpFAdd`
and `OpExtInst` alone. The `by_group_sum` array costs nothing: `OpAccessChain`,
`OpLoad`, `OpStore`, `OpVariable`, and `OpTypeArray` are equal. The four extra
`vec4` activation loads the E4 pre-pass writes in GLSL are common-subexpression
eliminated against the loads the row loop already makes, so the memory behavior
is identical -- 32 `OpLoad` and 28 `OpAccessChain` in each module's
per-superblock body.

## Loop structure and group sums per superblock

After freezing, each module holds eleven `OpLoopMerge` and exactly two
`Fma`-bearing basic blocks:

| module | fully unrolled call site | tail call site |
| --- | ---: | ---: |
| control | 128 `Fma` | 32 `Fma` |
| E4 | 80 `Fma` | 20 `Fma` |

The first block is `compute_outputs(first_row, NUM_ROWS)` with `num_rows`
frozen to 4, unrolled to four row bodies of 32 and 20 `Fma`. The second is the
`first_row + NUM_ROWS > p.stride_d` tail, where `num_rows` stays a runtime
value, so the `n` loop survives as one row body per iteration. The superblock
loop, `for (i = ix; i < num_blocks_per_row; i += it_size)` with `it_size =
gl_WorkGroupSize.x / 16 = 4`, survives in both call sites of both modules.

The group sums the patch forms are per-lane four-element partials, not the
32-element group sums the term is named for. `l0 = 4 * (2 * ir + v_in)` gives
eight distinct offsets per `v_im`, so a true 32-element group is split across
the eight lanes sharing that `v_im`, and `reduce_result` assembles the minimum
term across the workgroup rather than the group sum.
`evidence/raven2-vulkan-kernel-census/e4/e4b-c-first-pass.md` enumerates the
read sets and confirms the 64 lanes of a workgroup read 1024 distinct elements
with empty overlap. Per superblock at `NUM_COLS = 1`, E4 forms four partials
per lane and 64 per superblock; the control forms none.

Group sums per superblock, per `NUM_ROWS`, counting the minimum term alone in
float operations per lane:

| `NUM_ROWS` | control, 16 per row | E4, 12 per column plus 4 per row | change |
| ---: | ---: | ---: | ---: |
| 1 | 16 | 16 | 0 |
| 2 | 32 | 20 | -12 |
| 4 (served) | 64 | 28 | -36 |
| 8 | 128 | 44 | -84 |

## Does the count agree with the first pass

Not as stated, on two counts, and the deviation is the finding.

`decode-decomposition.md` records "the minimum term falls from 32 operations per
lane per superblock to 20," counted at `NUM_ROWS = 2`. This module's
pre-optimizer histogram also reads 32 and 20, and the agreement is a
coincidence of units. The first pass's 32 is the minimum term over two rows,
`2 x 16`; the histogram's 32 is the whole shader's static `Fma` count over one
source instance, `15 + 12 + 5`. The two quantities differ in what they count
and in the loop level they count it at, and they agree numerically because the
patch removes twelve of both.

The served pipeline runs `NUM_ROWS = 4`, not 2. At the served value the minimum
term falls from 64 to 28 float operations per lane per superblock, a 56.3%
reduction of the term against the 37.5% the first pass recorded, and the whole
per-superblock body falls further than the first pass's 8% of the family's issue
count. Two independent derivations agree on the size:

- By hand from the GLSL, per lane per superblock at `NUM_ROWS = 4`: the control
  issues 128 `Fma` and 24 `FMul`, E4 issues 80 `Fma`, 12 `FAdd`, and 24 `FMul`,
  so 152 float operations become 116, a fall of 36 and of 23.7%.
- From the specialized modules, the unrolled call site's block: `Fma` 128 to 80
  and `FAdd` 0 to 12, a fall of 36; the whole-module `FAdd` rise of 24 is that
  12 counted at both call sites.

The per-superblock body around it, read from the same block:

| | control | E4 | change |
| --- | ---: | ---: | ---: |
| SPIR-V instructions | 496 | 459 | -7.5% |
| float arithmetic | 160 | 124 | -22.5% |
| `OpCompositeExtract` | 120 | 120 | 0 |
| `OpLoad` | 32 | 32 | 0 |
| `OpAccessChain` | 28 | 28 | 0 |
| integer unpack (`And`, `Or`, shifts, `Bitcast`, `ConvertUToF`) | 108 | 108 | 0 |

So E4 removes 7.5% of the per-superblock SPIR-V instruction count and 22.5% of
its float arithmetic. The registered prediction of a 10 to 16% fall in the
family's exclusive bracket sits between those two figures, which is the range a
bracket bound partly by VALU issue and partly by the integer unpack and the
loads would occupy.

## What spirv-opt does not do, and what this bounds

`-O` keeps the sixteen-term expansion in every control column: 32 before, 64
after inlining, 160 after freezing. spirv-opt performs no floating-point
reassociation here, and the reason is semantic rather than a missed pass -- the
module declares no relaxed-precision or fast-math relaxation over these
operations, and summing the four activation components before the scale changes
the result. The patch therefore states a new numerical claim, which is why E4's
identity was measured rather than asserted, and the Q5_K half of the same patch
preserves its addition order exactly and needs no such measurement.

The comparison bounds SPIR-V and nothing below it. The workstation's Vulkan ICD
is NVIDIA; it proves that both sources compile, that the specialization is
legal, and that the executed module differs in the two opcodes above. It reports
nothing about what NIR and ACO emit on RADV, where the 120 `OpCompositeExtract`
and the 108 integer unpack operations may fold into source modifiers and where a
hoist may already have happened. `RADV_DEBUG=shaders` over
`mul_mat_vec_q4_k_f32_f32` on the appliance answers that, and
`decode-decomposition.md` already assigns it to the shader lab receipt.
