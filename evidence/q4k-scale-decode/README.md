# Two Q4_K candidates: the scale halfword select, and the superblock loop's LICM

`evidence/q4k-isa-attribution/` ranks the scale decode's `v_im` halfword selection second and
the per-iteration descriptor reload fourth, and predicts -3 of the 76-instruction row for the
first and no VALU change for the second. Both are authored here as candidate patches and
compiled on the RAVEN2 shim. The measured result is larger than both predictions and its
mechanism is different from the one the ranking named: `v_perm_b32` is unreachable from GLSL
on gfx902, the four instructions the ranking targets are the unaligned-load lowering rather
than a merge ACO chose, and reading the twelve scale bytes as three four-byte-aligned words
takes the served shape's loop body from 395 to 365 instructions and its VGPR allocation from
64 to 48, which is 5 subgroups per SIMD against 4. The loop restructure then takes the body
to 349 and its scalar count from 20 to 4.

Nothing here executed a submission. Every figure is a compile receipt.

## Table 1: the served shape, spec constants 0:64 1:4 2:1

`ctrl` is the post-E4 source at blob `48778a3e8`, whose ISA reproduces the appliance's
retained receipt bit for bit at `isa_sha256 29454587...185a1d`. `body` is the superblock loop
block `depth.py` reports, which is the block the back edge returns to.

| field | ctrl | scale-word-select | loop-licm | both |
| --- | ---: | ---: | ---: | ---: |
| `isa_sha256` head | `29454587` | `4eb61f83` | `2b403f1f` | `138bab50` |
| VALU | 810 | 776 | 820 | 786 |
| SALU | 414 | 416 | 426 | 428 |
| VMEM | 56 | 40 | 56 | 40 |
| SMEM | 38 | 38 | 38 | 38 |
| `v_mac_f32` | 152 | 152 | 152 | 151 |
| `v_perm_b32` | 0 | 0 | 0 | 0 |
| `v_alignbyte_b32` | 16 | 0 | 16 | 0 |
| `v_bfi_b32` | 0 | 0 | 0 | 0 |
| `v_add_u32` | 76 | 42 | 76 | 42 |
| SDWA operand uses | 16 | 24 | 16 | 24 |
| VGPR | 64 | **48** | 64 | **48** |
| SGPR | 48 | 48 | 48 | 48 |
| spilled VGPR / SGPR | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| LDS / scratch | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| code size, bytes | 6480 | 6176 | 6580 | 6288 |
| `Subgroups per SIMD`, driver | 4 | **5** | 4 | **5** |
| body instructions | 395 | 365 | 377 | 349 |
| body VALU | 329 | 312 | 327 | 312 |
| body SALU | 19 | 20 | 4 | 4 |
| body VMEM | 24 | 16 | 24 | 16 |
| body `s_waitcnt` | 23 | 17 | 22 | 17 |
| body longest VALU chain | 17 | 12 | 17 | 12 |
| body `max_lgkm_in_flight` | 1 | 1 | **0** | **0** |

The occupancy column is the driver's own statistic and it agrees with the arithmetic a gfx9
SIMD sets: 256 VGPRs per wave64 slot, so waves per SIMD is `floor(256 / VGPR)` capped at 10,
and `floor(256/64) = 4` against `floor(256/48) = 5`. That step is the largest effect on this
page and it is larger than every instruction count on it. It appears at `NUM_ROWS = 4` alone.

`v_mac_f32` falls 152 to 151 in the combined arm while `v_mad_f32` rises 8 to 9. Both are the
same fused multiply-add with the same operands; `v_mac_f32` is the two-address VOP2 form and
`v_mad_f32` the three-address VOP3 form, and register allocation decides which. The float
operation total is 214 in all four arms.

## Table 2: NUM_ROWS 8, where the occupancy step does not appear

| field | ctrl | scale-word-select | loop-licm | both |
| --- | ---: | ---: | ---: | ---: |
| `isa_sha256` head | `299ef0ed` | `908b31fe` | `c197f9e2` | `8eb28854` |
| VALU | 1520 | 1454 | 1538 | 1473 |
| SALU | 667 | 668 | 678 | 680 |
| VMEM | 104 | 72 | 104 | 72 |
| `v_alignbyte_b32` | 32 | 0 | 32 | 0 |
| `v_add_u32` | 140 | 74 | 140 | 74 |
| VGPR / SGPR | 64 / 48 | 64 / 48 | 64 / 48 | 64 / 48 |
| spilled VGPR / SGPR | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| code size, bytes | 11668 | 11036 | 11792 | 11160 |
| `Subgroups per SIMD`, driver | 4 | 4 | 4 | 4 |
| body instructions | 742 | 684 | 720 | 656 |
| body VALU | 635 | 602 | 633 | 603 |
| body SALU | 31 | 32 | 4 | 4 |
| body VMEM | 44 | 28 | 44 | 28 |
| body longest VALU chain | 17 | 12 | 17 | 13 |
| body `max_lgkm_in_flight` | 1 | 1 | 0 | 0 |

The eight-row shape carries the same instruction result and none of the register result: VGPR
holds at 64, so the occupancy step is a property of the four-row shape the host creates. The
host passes `rm_kq = 4` on the `AMD_GCN` branch of `ggml-vulkan.cpp` and the decode ledger
records `constants=64,4,1`, so the shape that gains the step is the shape that serves.

## Table 3: the phase attribution rerun

`classify-loop-phases.py` over each arm's own body range, per output row.

| phase | ctrl | scale-word-select | loop-licm | both |
| --- | ---: | ---: | ---: | ---: |
| multiply_accumulate | 26.00 | 26.00 | 26.00 | 26.25 |
| weight_decode | 22.00 | 22.00 | 22.00 | 22.00 |
| scale_decode | 19.00 | 18.00 | 19.00 | 18.00 |
| activation | 3.00 | 3.00 | 3.00 | 3.25 |
| address | 12.00 | 8.75 | 11.25 | 8.00 |
| lane_mask | 0.25 | 0.25 | 0.25 | 0.25 |
| residue | 0.25 | 0.25 | 0.25 | 0.25 |
| **body VALU per row** | **82.50** | **78.25** | **81.75** | **78.00** |
| longest chain, whole body | 17 | 12 | 17 | 12 |

The scale-word-select's -4.25 per row is -1.00 of scale decode and -3.25 of address, against
a prediction of -3 inside the scale phase. Three of the four instructions the prediction
named are classified as address arithmetic rather than as scale decode, because E1's address
rule claims any VALU a memory instruction's address operand slices back to and the byte shift
each `v_alignbyte_b32` takes is such an operand. The loop restructure's -0.75 per row is
address alone, and it stacks: the combined arm reaches 8.00 where the control is 12.00.

The scalar split names what the restructure moved. Its total is 22 against the 19 Table 1
reports, because `depth.py`'s block is the loop's own basic block and the classifier's range
runs to the back edge, which is the same relation `evidence/q4k-isa-attribution/` states for
the control.

| SALU class, body at NUM_ROWS 4 | ctrl | scale-word-select | loop-licm | both |
| --- | ---: | ---: | ---: | ---: |
| descriptor_load | 1 | 1 | **0** | **0** |
| row_base | 12 | 12 | **0** | **0** |
| mask_constant | 4 | 4 | 3 | 3 |
| exec_control | 3 | 3 | 2 | 2 |
| branch | 1 | 1 | 1 | 1 |
| other | 1 | 2 | 0 | 0 |
| **body SALU total** | **22** | **23** | **6** | **6** |

### The classifier correction this rerun required

`classify-loop-phases.py` read every `buffer_load_dwordx4` as an activation read, on the
ground that the mat-vec reads the activation vector as `vec4` and nothing else at that width.
The scale-word-select arm reads the twelve aligned scale bytes at that width, so the rule
claimed its scale loads and reported `scale_decode` at 0 with `activation` at 84 of 313. The
rule now admits a `buffer_load_dwordx4` as activation only where its own cut cone names no
scale mask, and every other load falls through to the cone rule it always used. Every retained
row of `evidence/q4k-isa-attribution/phase-attribution.tsv` and `salu-attribution.tsv`
reproduces byte-identically under the corrected rule, over all eleven labels, because the
control's four `dwordx4` cones reach the float joins without touching `0x3f3f3f3f` or
`0xc0c0c0c0`.

The four joins that validate the split against E1 hold on the control at both shapes:
`address` 48, `dot_float` = multiply_accumulate plus activation = 116, `unpack_convert` =
weight_decode plus scale_decode plus residue = 165, `lane_mask` 1.

## Candidate 1: `llama-vulkan-q4k-scale-word-select.patch`

**The mechanism the attribution named, and the one the source carries.** The ranking reads the
two `v_alignbyte_b32` as ACO merging `scales[v_im]` and `scales[v_im+2]` into one
`buffer_load_dwordx2` and then undoing the merge. The merge is real and the undo is not ACO's
choice: `block_q4_K_packed16` declares `scales` as `uint16_t`, so each read is a 16-bit access
at alignment 2, `nir_lower_mem_access_bit_sizes.c:145` sends the vectorized pair through
`shift_load_data_alignbyte_amd` at line 73, and that helper emits one `nir_op_alignbyte_amd`
per output component over a dword-aligned load. The control's final NIR carries 16 of them at
`NUM_ROWS = 4` and every arm here carries 0. ACO selects each as `v_alignbyte_b32`
(`aco_select_nir_alu.cpp:3347`) and merges the two halves with a `v_mov_b32_sdwa`, and the
shift operand each alignbyte takes is an address the body adds up per output row.

**Why `v_perm_b32` never forms.** The registered falsifier is met on all five formulations and
the reason is structural rather than a formulation failure. `nir_op_byte_perm_amd` exists and
ACO selects it as `v_perm_b32` (`aco_select_nir_alu.cpp:3355`), but its only producer in Mesa
26.2.1 is `radv_nir_lower_cooperative_matrix.c`; `nir_opt_algebraic.py` states no rule that
forms it, so no GLSL expression reaches it. The one other path to the instruction is ACO's own
`do_pack_2x16`, whose `v_perm_b32` branch is gated `gfx_level >= GFX10`
(`aco_lower_to_hw_instr.cpp:1656`) while the `v_alignbyte_b32` branch above it is not. gfx902
is GFX9, so the pack lowering reaches alignbyte and never perm. This restates E2b's finding on
a second chain, and it closes the byte-permute route at the compiler for every Q4_K arm on this
device rather than for this one expression.

**What the patch does instead.** `block_q4_K_packed32` carries the same twelve scale bytes as
`scales[0..2]`, four-byte aligned, so one read serves the halfword pair and the eighth-scale
halfword alike and the unaligned lowering never runs. The halfword pair is then gathered from
byte lanes under a selector `compute_outputs` hoists, since `v_im` is invariant across both
loops. ACO widens the read to one `buffer_load_dwordx4`, which covers the twelve scale bytes
and the first `qs` dword, so the body's memory instructions fall 24 to 16 per superblock: four
`buffer_load_dwordx2`, four `buffer_load_ushort`, and four of the twelve `buffer_load_dword`
are replaced by four `buffer_load_dwordx4`.

Fetched bytes per lane per superblock rise 152 to 160, because the widened read takes 16 per
row where the pair, the halfword, and the `qs` dword it absorbs took 14. That is a
request-width figure and not a DRAM figure: all
of it lands inside one 144-byte `block_q4_K` that sixteen lanes read together, so the block
reaches DRAM once either way and the difference is L1 request width.

**Equivalence.** `scale-select-equivalence.py` beside this file drives every formulation and
the control over the ninety-six single-bit scale words, both saturating words, and 200,000
random draws, against both values of `v_im`: 400,196 cases, zero mismatches on all five arms.
The float arithmetic is untouched, so the accumulated value is unchanged bit for bit and the
appliance arm predicts token identity rather than a tolerance.

**The five formulations, and the four this one was chosen over.** Whole-shader at
`NUM_ROWS = 4`.

| formulation | VALU | body instructions | VMEM | VGPR | subgroups | `v_alignbyte_b32` | `v_bfi_b32` | `v_add_u32` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| ctrl, the post-E4 form | 810 | 395 | 56 | 64 | 4 | 16 | 0 | 76 |
| s1 aligned pair, mask-or | 786 | 376 | 48 | 64 | 4 | 0 | 0 | 42 |
| s2 aligned pair, byte gather | 774 | 372 | 48 | 64 | 4 | 0 | 0 | 42 |
| s3 aligned pair, `bitfieldInsert` | 784 | 376 | 48 | 64 | 4 | 0 | 8 | 42 |
| s4 aligned triple, mask-or | 784 | 367 | 40 | 64 | 4 | 0 | 0 | 42 |
| **s5 aligned triple, byte gather** | **776** | **365** | **40** | **48** | **5** | **0** | **0** | **42** |

Three readings the ladder settles. The aligned read rather than the merge form is what removes
the alignbyte pair: all five arms reach 0 and 42 `v_add_u32` against 76. The byte gather beats
both arithmetic merges on instruction count at either read width, 372 against 376 and 365
against 367, which is the byte-permute shape reaching SDWA byte selects where it cannot reach
`v_perm_b32`. And the register result belongs to the pair rather than to either half: s2 and s4
each hold 64 VGPRs and only their combination reaches 48, so a formulation chosen on VALU alone
would have taken s2 and missed the occupancy step. `bitfieldInsert` does reach `v_bfi_b32`,
eight of them, and costs more instructions than either alternative.

## Candidate 2: `llama-vulkan-q4k-superblock-loop-licm.patch`

**The mechanism.** `nir_opt_licm.c:156` calls `visit_block` only where
`current_block_dominates_exit` holds, so that a hoist never speculates work a loop might not
run. A top-tested loop compiles to `loop { if (!cond) break; body }`, its exit is reached
through the header's break, and its body block therefore dominates nothing: LICM never visits
it and nothing loop-invariant leaves it. `radv_pipeline.c:385` runs `radv_nir_lower_descriptors`
ahead of the LICM pass at line 392, so the buffer descriptors' load is in the body and visible
to the pass that declines to move it. The control's body opens on `s_load_dwordx8 s[24:31]`
followed by `s_waitcnt lgkmcnt(0)` before its first `buffer_load_dwordx4`, and `depth.py`
records `max_lgkm_in_flight 1` per iteration.

**What the patch does.** The superblock loop becomes bottom-tested under an entry guard, so its
body is a block that dominates the loop exit. The iteration set is unchanged: both forms run
the body for `i = ix, ix + it_size, ...` while `i < num_blocks_per_row`, and both run it zero
times where `ix` already meets that bound.

**What moved.** The descriptor load and its wait leave the body, and `max_lgkm_in_flight` falls
1 to 0. So does the per-output-row block base, `s_mul_i32` and two `s_add_u32` against
`first_row` and `num_blocks_per_row`, which is loop-invariant for the same reason and stayed
inside for the same reason: the classifier's body scalar total falls 22 to 6 at `NUM_ROWS = 4`,
and the loop block's own falls 19 to 4 there and 31 to 4 at `NUM_ROWS = 8`. Three VALU address
instructions leave with it, 12.00 to 11.25 per row.

**What it costs.** 24 more instructions across the whole shader, which is the entry guard, the
bottom test, and the hoisted values in the preheaders of the two call sites `compute_outputs`
is inlined at. Per-lane iterations are `num_blocks_per_row / it_size`, which is `ncols / 1024`
at `BLOCK_SIZE` 64: two at the 2B distill's 2048-wide projections and six at its 6144-wide
`down_proj`. The trade is favourable from two iterations and the cost is static code the second
call site executes on the remainder path alone.

**The registered falsifier is not the one that binds.** The attribution registered
`spilled_sgprs` above 0 at 48 SGPRs. Nothing spills: the descriptor pair is 8 SGPRs live across
the loop against 48 allocated of the 102 a wave may hold, and `spilled_sgprs` reads 0 on every
arm at both shapes. The falsifier that binds is the VGPR side, since the served shape sits at
exactly 64 with `floor(256/64) = 4` subgroups per SIMD and 65 would drop it to 3. LICM hoists
everything it can now reach rather than the descriptor alone, so that is the outcome to read:
VGPR holds at 64 on this arm and reaches 48 with the scale-word-select beside it.

## Reproducing every number

The shim wrapper and its two inputs are `evidence/e4b-summary-producer/radv-raven2-shim-env.sh`
with `QWEN_RADV_ICD` naming a `radeon_icd.json` whose `library_path` points at the extracted
`libvulkan_radeon.so` of the installed Mesa and `QWEN_AMDGPU_DRM_SHIM` naming
`libamdgpu_noop_drm_shim.so` from a build of the same release. Both come from Mesa 26.2.1,
since `ac_gpu_info.c` refuses an amdgpu node below DRM 3.54.0.

```sh
# The control tree, then one tree per candidate, in ledger order.
remote/prepare-llama-census-source.sh $HOME/src/llama.cpp $SCRATCH/ctrl \
    llama-vulkan-q4k-activation-group-sums.patch
remote/prepare-llama-census-source.sh $HOME/src/llama.cpp $SCRATCH/both \
    llama-vulkan-q4k-activation-group-sums.patch \
    llama-vulkan-q4k-scale-word-select.patch \
    llama-vulkan-q4k-superblock-loop-licm.patch

# One module and one receipt per arm and shape.
SHADERS=$SCRATCH/ctrl/ggml/src/ggml-vulkan/vulkan-shaders
DEFS="-DDATA_A_Q4_K=1 -DFLOAT_TYPE=float -DFLOAT_TYPEV2=vec2 -DB_TYPE=float \
      -DB_TYPEV2=vec2 -DB_TYPEV4=vec4 -DD_TYPE=float -DUSE_SUBGROUP_ADD_NO_SHMEM=1"
glslc -fshader-stage=compute --target-env=vulkan1.2 -I "$SHADERS" \
    "$SHADERS/mul_mat_vec_q4_k.comp" -o $SCRATCH/ctrl.spv -O $DEFS
for rows in 4 8; do
    evidence/e4b-summary-producer/radv-raven2-shim-env.sh \
        remote/raven2-shader-lab/lab.sh $SCRATCH/ctrl.spv $SCRATCH/ctrl-nr$rows \
        --spec 0:64 --spec 1:$rows --spec 2:1 --subgroup 64 \
        --bindings 5 --push-constants 52 --per-superblock 256
    python3 remote/raven2-shader-lab/depth.py \
        $SCRATCH/ctrl-nr$rows/isa.s $SCRATCH/ctrl-nr$rows/depth.tsv
done

remote/raven2-shader-lab/receipt-diff.sh $SCRATCH/ctrl-nr4 $SCRATCH/both-nr4

# The phase split. Each body range runs from the line after the label of the block holding
# the four buffer_load_dwordx4 through the s_cbranch that returns to that label, and each
# reduction range is the block holding the first v_add_f32_dpp. The restructure moves the
# loop header, so the ranges are read off each arm rather than carried across.
Q=evidence/q4k-isa-attribution
python3 $Q/classify-loop-phases.py $SCRATCH/ctrl-nr4/isa.s 101 501 ctrl-body-num-rows-4 --rows 4
python3 $Q/classify-loop-phases.py $SCRATCH/ctrl-nr4/isa.s 503 567 ctrl-reduction-num-rows-4 --rows 4
python3 $Q/classify-loop-phases.py $SCRATCH/both-nr4/isa.s 124 475 both-body-num-rows-4 --rows 4
python3 $Q/classify-loop-phases.py $SCRATCH/both-nr4/isa.s 485 549 both-reduction-num-rows-4 --rows 4

python3 evidence/q4k-scale-decode/scale-select-equivalence.py
QWEN_LLAMA_CANDIDATE_PATCHES=1 remote/verify-llama-patch-series.sh
```

The body and reduction ranges of every retained arm are `ctrl` 101-501 and 503-567,
`scale-word-select` 102-472 and 474-538, `loop-licm` 124-503 and 513-577, and `both` 124-475
and 485-549 at `NUM_ROWS = 4`; at `NUM_ROWS = 8` they are 107-854 and 856-984, 106-795 and
797-925, 138-860 and 876-1004, and 138-796 and 812-940.

## The appliance arms, none of which has run

The two patches sit at `candidate` in `remote/llama-patch-series.tsv`. The scale-word-select's
preimage is the E4 result at blob `48778a3e8`; the loop-licm patch's preimage is the
scale-word-select result at `c3cf5ffb6`, because both edit `compute_outputs`' superblock loop
and one hunk region cannot carry two independent preimages. A chained
`QWEN_LLAMA_CANDIDATE_PATCHES=1` replay applies the whole candidate stage in ledger order and
accepts.

**The A/B.** The judgement is `mul_mat_vec_q4_k_f32_f32`'s exclusive bracket against the E4
control's, measured through the kernel-delta mode both binaries collect under:

```sh
QWEN_CENSUS_AB_MODE=kernel-delta \
QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual QWEN_CENSUS_SCLK_LEVEL=2 \
QWEN_CENSUS_MCLK_FLOOR_MHZ=933 \
    remote/run-served-binary-ab.sh CONTROL CANDIDATE qwen38-2b-distill OUT
```

`CONTROL` is a census build of the candidate stack through
`llama-vulkan-q4k-activation-group-sums.patch`; `CANDIDATE` is the same stack with these two
patches on top. Arms run W C K K C at `QWEN_CENSUS_REPLICATES` pairs under the
`manual-gfx1100-fclk933` operating point the DPM authority settled: GFX 1100 delivered read
from hwmon `freq1_input`, FCLK level 2 written with 933 as the floor, 1067 uncommandable.
Class order follows the benchmark policy: the 2B distill first, the 0.8B second, the 4B third,
and a result becomes a Raven2-wide default only where the classes agree.

**What the arms would settle, and what no compile receipt can.** Two effects move in the same
direction and only the device separates them. The instruction result is -4.5% of the body at
the served shape, which E4's own transfer of 0.48 from VALU delta to bracket delta -- one
observation on this shader, device, and tuple, carrying no band -- puts at about -2% of the
Q4_K exclusive bracket. The occupancy step from 4 to 5 subgroups per SIMD is 25% more waves
per SIMD and is not an instruction count at all; on a decode this memory-bound it buys latency
hiding rather than issue slots, and how much is exactly what a static receipt cannot say.

**Falsifiers, registered before the run.**

- **The bracket.** `mul_mat_vec_q4_k_f32_f32`'s exclusive bracket must fall against E4's at a
  margin of 0.5%, the figure the retained kernel-delta statistic supports at sd 0.0002 over 4
  pairs. A bracket at or above E4's refutes both patches as implemented; between -0.5% and 0 is
  unresolved rather than accepted. Served tok/s is a secondary read and carries no falsifier,
  since its paired sd is 4.3% under pinned clocks.
- **Token identity.** The 2B distill's generated ids must equal the control's over
  `remote/witness-prompts/holdout-12.tsv`. The scale decode's integer result is enumerated
  identical here and neither patch moves a float operation or an addition order, so the arms
  predict bit-for-bit equality rather than a tolerance. Any id difference refutes the
  equivalence claim rather than measuring a reassociation, which is what separates these arms
  from E4's.
- **The margin witness.** `QWEN_WITNESS_CONTRACT=margin` with `summarize-margin-witness.py`
  must hold the registered top-10 retention at margins at or above 0.1 nat. Ids held with
  retention below the contract is a finding about the contract; ids moved is the falsifier
  above.
- **The Q6_K null.** `mul_mat_vec_q6_k_f32_f32`'s bracket must hold across the pair. Neither
  patch names a Q6_K source, so a moved Q6_K row reports machine state and the Q4_K delta is
  read only where the null holds.
- **The occupancy claim.** The served pipeline must be created at `constants=64,4,1` and the
  driver must report 5 subgroups per SIMD for it. A build whose host selects another shape
  loses the register result entirely, since VGPR holds at 64 at `NUM_ROWS = 8`.

## What is retained

| file | what it is |
| --- | --- |
| `arm-receipts-num-rows-4.tsv` | Table 1 and the formulation ladder, whole-shader beside the body |
| `arm-receipts-num-rows-8.tsv` | Table 2 |
| `phase-attribution.tsv` | Table 3, body and reduction, four arms at two shapes |
| `salu-attribution.tsv` | the SALU class split for the same sixteen ranges |
| `scale-select-equivalence.py` | the enumeration behind the bit-identity claim |
| `receipts/ARM-nrN/` | `lab.sh`'s own receipt, statistics, depth table, and disassembly per arm and shape |
| `receipts/receipt-diff-*.tsv` | `receipt-diff.sh`'s verdict over each pair |

The `pipeline_created` and `spirv_path` fields carry `$SCRATCH` in place of the working
directory, the convention `evidence/e4b-summary-producer/` sets. Each receipt records
`run_mode=device`, `device_name`, and `driver_name`, and a reading is made against those three
first: another driver compiles the same SPIR-V with another compiler and answers a question
about that compiler.

## What did not run

- **Every device arm.** No submission executed; the shimmed node ends at pipeline creation and
  no figure here is a time. The served kernel-delta A/B, the margin witness, and the Q6_K null
  all need the appliance and a teardown window, and the laptop belongs to another lane.
- **A build of the whole binary.** The candidate trees prepare and their shader compiles; no
  `build-llama-preset.sh` run and no manifest was produced here, because the arm's build
  belongs to the appliance chain that measures it.
- **Q5_K.** `mul_mat_vec_q5_k.comp` carries the same twelve-byte scale block and the same
  two-byte-aligned reads, and E4 patched it beside Q4_K. Neither patch here names it. The
  tensor-type audit reads Q5_K as its own trunk at 5.9 GB/s against the Q4_K trunk's 8.1, so
  the arm is worth taking and it is a separate one.
- **The repository gate.** `refresh-evidence-manifest.sh --check` and `check-text-policy.py`
  ran, with `shellcheck` over `remote/raven2-shader-lab/lab.sh` and both shader-lab tests. The
  full gate did not, since it carries device tests that refuse while a server holds the device.
