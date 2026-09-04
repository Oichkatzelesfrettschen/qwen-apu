# The Raven2 shader laboratory

A shader question here costs seconds. `lab.sh` creates one compute pipeline
from one `.spv`, retains every compiler layer that pipeline passes through,
and exits; no model loads, no server starts, no lease is taken, and the
appliance keeps serving while the question is asked. The alternative it
replaces is a served run, which costs a teardown window and answers a timing
question rather than a mechanism one.

## The layer ladder

```text
GLSL  --glslc-->  SPIR-V  --RADV frontend-->  NIR  --ACO-->  ISA  --device-->  kernel time
```

A source edit is erased or carried at each arrow, and each output below proves
which happened at one of them.

| output | layer | what it proves |
| --- | --- | --- |
| `spirv.dis` | SPIR-V | the module the driver was handed, disassembled by `spirv-dis`; its SHA-256 is the identity a census ledger row's `spirv_executed_sha256` is compared against |
| `final.nir` | NIR | the shader as `radv_postprocess_nir` left it, printed by `nir_print_shader` immediately before `radv_shader_nir_to_asm`, so it is the NIR ACO was given rather than the NIR the frontend produced |
| `isa.s` | ISA | the gfx902 instructions the device would fetch, `%-60s ;` followed by the encoding words, with `BB%u:` block labels, from ACO's `print_asm` |
| `stats.tsv` | register allocation | VGPR, SGPR, spill, LDS, scratch, code size, and waves per SIMD, read out of `RADV_DEBUG=shaderstats`; `radv_pipeline_capture_shader_stats` (`radv_pipeline.c:55`) turns capture on for that debug flag alone, so no pipeline creation flag is needed, and a run that produced no statistics block leaves every field reading `-` rather than discarding the ISA |
| `receipt.tsv` | all four | the three digests, the pipeline reconstruction, and the instruction-class and named-mechanism counts, one row per field |
| `depth.tsv` | ISA shape | per basic block, the longest dependent VALU chain, the memory operations in flight at each wait, and the wait count, from `depth.py` |

`radv-debug.log` retains the whole stderr stream the extraction read, and
`shaderstats.txt` the statistics block verbatim, so every derived file is
recomputable from what the driver actually wrote.

## What the driver prints, and why the extraction anchors where it does

`RADV_DEBUG=shaders` is the union `RADV_DEBUG_DUMP_SHADERS`
(mesa-25.3.2 `src/amd/vulkan/radv_debug.h:79`), which already carries
`DUMP_NIR`, `DUMP_ASM`, and `DUMP_BACKEND_IR` beside every stage bit, so the
`nir` member `lab.sh` also sets states what `shaders` implies and adds
nothing. Per compute pipeline, `radv_pipeline_compute.c` writes, in order:
the final NIR under `nir_print_shader`, ACO's own program prints headed
`After Instruction Selection:`, `After RA:`, and
`After lowering to hw instructions:`, then the stage name and the `disasm:`
block from `radv_shader.c:3282`, then the statistics block from
`radv_dump_shader_stats`. The whole sequence runs inside
`instance->shader_dump_mtx`, which is what keeps one pipeline's dumps
contiguous where several threads compile at once.

The disassembly therefore ends at whichever comes first of its own statistics
block, the next `shader:` opener, an ACO header, or the next stage-name line.
A reader that ended it at the next stage-name line alone would count the
following pipeline's NIR and ACO prints as this one's instructions, which is
the correction `remote/summarize-radv-isa.py` also carries for the served-run
dumps it reads.

`lab.sh` creates exactly one pipeline and refuses a log carrying more than one
block of any kind, so no extraction here pairs one shader's NIR with another's
ISA. A missing statistics block is the one absence it tolerates, and the stat
fields then read `-`.

## Fidelity: the pipeline is reconstructed, not minimized

`shader-lab.c` asks RADV for what llama.cpp asks it for, because four choices
change the emitted instructions without failing:

- **Descriptor set and push constants.** `ggml_vk_create_pipeline` passes
  `mul_mat_vec_num_bindings = 5` storage buffers and a push-constant range of
  `sizeof(vk_mat_vec_push_constants)`. A layout that under-declares what the
  shader indexes changes RADV's descriptor lowering, so `--bindings` and
  `--push-constants` state both.
- **Device features.** `shader-lab.c` walks the module's own `OpCapability`
  list and enables exactly the matching feature bits, refusing the run and
  naming the capability where the device reports one unsupported. A capability
  compiled without its feature selects different instructions or fails inside
  the driver, and either would be read as a property of the shader.
- **Subgroup size.** `--subgroup 64` enables `subgroupSizeControl` and
  `computeFullSubgroups` at device creation and sets
  `VkPipelineShaderStageRequiredSubgroupSizeCreateInfo` beside
  `VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT`, the pair ggml
  passes as `force_subgroup_size` and `require_full_subgroups`. gfx9 compute
  defaults to wave64 already, so a pNext the driver ignored would look correct
  on this part; the receipt records requested and device-reported sizes
  separately for that reason.
- **Robustness.** ggml passes `disable_robustness = true` for these
  pipelines and `shader-lab.c` enables no robustness feature, so both compile
  with bounds checks off. Robustness on adds a check per buffer access and
  moves every count this lab reports.

## The pinned mat-vec constants

`mul_mat_vec_base.glsl` declares `constant_id = 0` `BLOCK_SIZE`,
`constant_id = 1` `NUM_ROWS`, and `constant_id = 2` `NUM_COLS`, and
`mul_mat_vec_q4_k.comp`'s `local_size_x_id = 0` aliases the first. Two routes
agree on the values this device runs them at:

- The source: `ggml-vulkan.cpp` passes `{wg_size_subgroup16, rm_kq, i+1}`,
  which on the `AMD_GCN` branch is `subgroup_size16 = 64`, `rm_kq = 4`, and
  `i + 1 = 1` for the single-column pipeline.
- The census: the accepted I1 decode ledger's `mul_mat_vec_q4_k_f32_f32` row
  records `constants=64,4,1`, `wg_denoms=4,1,1`, `subgroup=64`.

```sh
remote/raven2-shader-lab/lab.sh a9ac07dd....spv OUT \
    --spec 0:64 --spec 1:4 --spec 2:1 --subgroup 64 \
    --bindings 5 --push-constants 52 --per-superblock 256
```

`vk_mat_vec_push_constants` is thirteen `uint32_t` fields, so the range is 52
bytes; RADV inlines push constants into user SGPRs through
`args.ac.inline_push_const_mask`, and the declared size participates in that,
so a wrong byte count moves the allocation without failing.

The ledger row records `_f32_f32` executing, so E1 reads that pipeline;
`decode-decomposition.md` and `remote/dump-radv-shader-isa.sh` name
`_f16_f32`, which takes the same constants from a different SPIR-V binary.
The receipt's `spirv_sha256` compared against the ledger's
`spirv_executed_sha256` is what makes the lab's ISA the served kernel's ISA,
and it self-enforces the variant: `reduc16` selects among three prebuilt
binaries and this device takes `SHADER_REDUCTION_MODE_SUBGROUP`, so a wrong
variant fails the digest.

## `--per-superblock` is an operator claim

The ISA is the whole shader: prologue, unrolled inner loop, reduction. The
loop's trip count arrives in push constants at run time (`p.ncols` and
`num_blocks_per_row`), so no divisor is derivable from `isa.s`. `receipt.tsv`
carries every count raw, the normalized value beside it, and
`per_superblock_divisor` naming the number an operator supplied. A figure
quoted as "per 256 weights" rests on that field and on the argument the
operator makes for it, and on nothing the file measured.

## Statistic names are matched by substring

`radv_dump_shader_stats` prints whatever
`VK_KHR_pipeline_executable_properties` reports, and the exact statistic name
strings come from a header Mesa generates at build time rather than from the
source read here. `stats.tsv` therefore selects each field by lowercased
substring and carries the driver's own name in a third column, with "spilled"
tested ahead of the bare register substrings so a spill count never lands in
the allocation field.

## The instruction classes counted

VALU is `v_`; SALU is `s_` less `s_waitcnt`, `s_barrier`, and `s_endpgm`;
VMEM is `buffer_`, `global_`, and `flat_`; SMEM is `s_load` and
`s_buffer_load`, a named subset of SALU rather than a sibling, so an `s_load`
counts in both; LDS is `ds_`. Beside them the receipt counts the gfx902
mechanisms `decode-decomposition.md`'s own capability table turns on:
`v_cvt_f32_ubyte*`, `v_bfe_*`, `v_lshrrev_b32`, `v_lshlrev_b32`,
`v_and_b32`, `v_perm_b32`, SDWA operand uses (`src0_sel:` or `dst_sel:` on
the line), DPP uses (`row_shr`, `row_bcast`, `quad_perm`, `row_ror`),
`v_mul_lo_u32`, `v_mad_u32_u24`, `v_mad_i32_i24`, `v_mul_u32_u24`,
`v_fma_f32`, `v_mac_f32`, `v_mad_mix_f32`, `v_pk_fma_f16`, and
`v_cvt_f32_f16`. SDWA and DPP ride on ordinary VOP1 and VOP2 opcodes, so both
are counted by the operand modifier the disassembler prints rather than by a
mnemonic.

## The experiment ladder

Each rung states what it reads and what would refute it. E1 through E4 answer
mechanism questions in this lab; E5 and E6 in
`evidence/raven2-vulkan-kernel-census/decode-decomposition.md` are served
measurements that follow.

### E1, the exact ISA inventory of the pinned mat-vecs

The module is obtained before anything else. The census build writes the exact
bytes it hands `vkCreateShaderModule` to a directory named by
`GGML_VK_PIPELINE_CENSUS_DUMP`, one file per pipeline under its own
`census_spirv_executed_sha256`, which is the digest the ledger row publishes;
one instrumented run with that variable set therefore produces
`a9ac07dd....spv` and closes the identity by construction. The build tree's
own `vulkan-shaders.spv/mul_mat_vec_q4_k_f32_f32*.spv` files are the
pre-embedding intermediates and are not that module: none of the three
reduction variants hashed to the ledger's digest on the workstation's census
build, so the dump is the route and the intermediates are not.

Run `lab.sh` over the pinned `mul_mat_vec_q4_k_f32_f32` and
`mul_mat_vec_q6_k_f32_f32` SPIR-V at `--spec 0:64 --spec 1:4 --spec 2:1
--subgroup 64`, with `--per-superblock 256` for the normalization, and read
the receipt's VALU count and named mechanisms.

`decode-decomposition.md` estimates 77 issued operations per lane per
superblock per row, about 4.8 per weight, from the GLSL. The receipt replaces
that estimate with a count.

*Falsifier.* A normalized VALU count below 50 per superblock refutes the VALU
account before the census does, and the integer kernel E5 falls behind the
submission-shape work. The Q4_K-against-Q6_K comparison carries its own
prediction: the census measured Q6_K streaming its bytes at about 17 GB/s
against Q4_K's 12, which the operation-count model explains only if Q4_K's
normalized VALU count exceeds Q6_K's; a Q4_K count at or below Q6_K's refutes
that explanation and moves the deficit onto per-dispatch ramp.

### E1.5, the final NIR digests of the same executed SPIR-V

The same two runs retain `final.nir`. Its digest is the identity every later
comparison is made against, and it separates a driver-version change from a
source change without rerunning either.

*Falsifier.* Two runs of one `.spv` on one driver producing different
`nir_sha256` values refutes the assumption that this lab is deterministic, and
every receipt diff below becomes unreadable until the nondeterminism is
found. `receipt-diff.sh` reports that case as `harness_alarm`.

### E2, which multiply ACO selects

`remote/isa-probes/q4k-integer-dot.comp` against
`remote/isa-probes/q4k-float-dot.comp`, one dword of packed nibbles per lane
and everything else held fixed. Read `v_mad_u32_u24`, `v_mad_i32_i24`, and
`v_mul_lo_u32` in the receipt.

gfx902 carries a full-rate 24-bit multiply-add and a quarter-rate 32-bit
multiply, and `decode-decomposition.md` derives its 2.6-operations-per-weight
estimate for an integer Q4_K kernel from the former.

*Falsifier.* A `v_mul_lo_u32` selection with no `v_mad_*` refutes the 2.6
estimate for a GLSL-sourced kernel. The document's own remedy is then NIR
range hints through 8-bit operands, which E2b measures, or a SPIR-V post-pass.

### E2b, whether packed operands survive to the multiply

`remote/isa-probes/q4k-packed-u8-dot.comp`, which holds the nibble planes and
the activation vector in the 8-bit types
`GL_EXT_shader_explicit_arithmetic_types_int8` declares, against
`remote/isa-probes/q4k-widen-early-dot.comp`, which extracts every field into
a 32-bit local by shift and mask first. Read `sdwa_operand_uses`,
`v_perm_b32`, `v_lshrrev_b32`, and `v_and_b32` across the pair.

*Falsifier.* The packed arm showing the same `v_lshrrev_b32` and `v_and_b32`
counts as the widening arm, with `sdwa_operand_uses` and `v_perm_b32` at
zero, refutes the operand-machinery route: the 8-bit type reached NIR and ACO
widened it anyway, and a kernel written in GLSL cannot reach the byte-select
path. The packed arm showing byte selects the widening arm lacks confirms it
and makes the 8-bit typing a source requirement for E5.

### E3, address arithmetic against dot arithmetic

Read `depth.tsv` and the receipt together over the pinned Q4_K mat-vec. The
question is how much of the VALU count computes addresses rather than
products, and whether the wave-uniform bases -- the per-superblock `dm` pair
and the twelve scale bytes, uniform for a given row -- sit in SGPRs through
`s_buffer_load` or are recomputed per lane in VGPRs.

*Falsifier.* An SMEM count at or near zero with the scale and `dm` loads
appearing as `buffer_load` refutes the assumption that the wave-uniform terms
are already scalar, and hoisting them into SGPRs becomes a candidate ahead of
E5. A `longest_valu_chain` short against the block's VALU count says the
kernel is issue-bound rather than latency-bound, and a chain approaching the
count says the opposite; the two readings order the same instructions
differently and the ISA cannot be read for rate without it.

### E4, the hoist traced through every layer

`decode-decomposition.md`'s activation group-sum pre-pass, compiled as a
candidate `mul_mat_vec_q4_k.comp` and run through `lab.sh` beside the
production shader, then read with `receipt-diff.sh CONTROL_DIR
CANDIDATE_DIR`. A served ABBA measures whether the token moved; this measures
whether the hoist reached the device at all, which matters because a repeated
depth-0 rate on this machine carries about 4% of uncontrolled spread and up
to 30.6% between sweeps, larger than the 5 to 9% the hoist is predicted to
buy.

The verdict is a four-rung interpretation ladder, and `receipt-diff.sh`
reports the first layer at which the two builds differ and the last:

| verdict | reading |
| --- | --- |
| `spirv_unchanged` | the shader compiler folded the edit away and the driver never saw it |
| `nir_canonicalized` | the SPIR-V differs and the final NIR is identical, so NIR's own passes reduced both forms to one |
| `isa_identical` | NIR differs and ACO emitted the same instructions, so the backend already performed the transformation |
| `isa_changed` | the device executes different instructions, and a served ABBA then measures what they cost |

*Falsifier.* Any verdict other than `isa_changed` refutes the premise of the
served E4 arm before it runs: there is no instruction difference for a timing
difference to come from, and a measured token change would be sweep position.
A `harness_alarm` of `spirv_identical_isa_changed` is a fault in the lab
rather than a finding, since one module compiled twice by one driver has no
source difference to express.

## Running it

```sh
remote/raven2-shader-lab/lab.sh SPV OUT_DIR [--spec ID:UINT]... [--subgroup N] \
    [--bindings N] [--push-constants BYTES] [--device-index N] \
    [--per-superblock N] [--spirv-only]
python3 remote/raven2-shader-lab/depth.py OUT_DIR/isa.s OUT_DIR/depth.tsv
remote/raven2-shader-lab/receipt-diff.sh CONTROL_DIR CANDIDATE_DIR
python3 remote/raven2-shader-lab/test-depth.py
cc -O2 -Wall -Wextra remote/raven2-shader-lab/shader-lab.c -lvulkan
```

`--spirv-only` stops after the disassembly, which is what a host carrying no
RADV part can do with a `.spv`. `QWEN_SHADER_LAB_REPLAY_DIR` names a
directory holding a recorded `radv-debug.log` and `harness.txt` and
substitutes them for the pipeline creation, so the extraction, the statistic
reader, the receipt writer, and `receipt-diff.sh` run on such a host too;
`test-fixtures/` holds three such recordings, every value in them invented,
and `receipt.tsv` records `run_mode` as `device`, `replay`, or `spirv-only`
so no reader mistakes one for the other.

The gfx902 part is the appliance's alone. A run against another driver
compiles the same SPIR-V with another compiler and answers a question about
that compiler, so the receipt records `device_name` and `driver_name` and a
reading is made against those two fields first.
