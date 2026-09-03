# The Q4_K mat-vec by phase, and what a shape change moves

The superblock loop the 2B decode graph dispatches 162 times issues 76 VALU
instructions per output row per 256-weight superblock on top of about 26 that
the shape amortizes, and the four phases of that 76 are the multiply-accumulate
at 26, the weight nibble decode at 22, the packed six-bit scale decode at 19,
and the address rebase at 9. The largest phase is the multiply-accumulate. The largest phase a named
mechanism removes is the address rebase, and the second is four of the
nineteen scale instructions. A packed-FP16 formulation is refuted on the
compile side rather than ranked: ACO forms `v_pk_fma_f16` on gfx902 from GLSL
and the probe that uses it issues eleven more VALU than the f32 control,
because the weights reach f32 in one `v_cvt_f32_ubyte` from a byte lane and
reach f16 only through f32.

Raising `NUM_ROWS` from 4 to 8 moves the per-row body from 82.50 to 79.50 VALU
and the per-row vector-memory demand from 38 to 30 bytes per lane, at 64 VGPRs,
zero spill, zero scratch, and the driver's own `Subgroups per SIMD: 4` on both
arms. That is a specialization-constant change with no source edit, and it is
the first candidate on the ranked list below.

## The pipeline this reads, and the name it is not

The pipeline is `mul_mat_vec_q4_k_f32_f32` in the `subgroup_no_shmem`
reduction variant, at `constants=64,4,1` and `subgroup=64`. The accepted I1
decode ledger's row names it, `evidence/raven2-vulkan-kernel-census/e1/`
carries the join from that row to the instruction stream, and the receipts
below carry `spirv_capabilities=Shader,Int8,GroupNonUniform,...` with no
`Float16`. `CLAUDE.md` calls this family the FP16-dequantize family after the
`_q8_1` family it is chosen over, and `decode-decomposition.md` and
`remote/dump-radv-shader-isa.sh` name `_f16_f32`, which is a different module
taking the same constants. The FP16 inside the executed body is eight
`v_cvt_f32_f16`, two per row, which decode the superblock `dm` pair; the
weights arrive through `v_cvt_f32_ubyte0..3`, one instruction per weight,
never through a half-precision value.

## The anchor: this host's ACO is the appliance's

`evidence/e4b-summary-producer/radv-raven2-shim-env.sh` runs RADV against a
shimmed RAVEN2 node, so a host carrying no AMD part obtains gfx902 ISA. The E4
consumer compiled here reproduces the appliance's retained receipt bit for bit
at `isa_sha256 29454587...185a1d`, VALU 810, `v_mac_f32` 152, VGPR 64, SGPR 48,
code size 6480. Its `isa.s` compares byte-identical to
`evidence/raven2-vulkan-kernel-census/e1/isa/e4-candidate-subgroup-no-shmem.s`,
so `receipts/num-rows-4/` retains no copy and that file is the disassembly
every four-row count below is read from. Two routes reach the same digest: the module
`vulkan-shaders-gen` emitted from the prepared candidate tree, and `glslc`
2026.3 over `mul_mat_vec_q4_k.comp` from that tree with the appliance's own
defines. Every run ends inside `vkCreateComputePipelines`; no arm on this page
executed a submission or measured time.

## The method, and what it joins

`evidence/raven2-vulkan-kernel-census/e1/classify-superblock-valu.py` splits
the body four ways and puts the scale decode and the weight decode in one
category, so it cannot say which of the two a restructuring would remove.
`classify-loop-phases.py` beside this file keeps E1's address rule verbatim --
a VALU is address arithmetic where a backward slice from a memory instruction's
address operand reaches it -- and divides the remainder by which load reaches
each value.

A load's role is read off its own forward cone, cut at the float operations
where the phases join. The four `buffer_load_dwordx4` are the activation
`vec4` reads. A cone reaching `v_cvt_f32_f16` or masking with `0x3f3f3f3f` or
`0xc0c0c0c0` is a scale read; the role is then closed over shared cone
instructions, which is what carries the eighth-scale halfword in, since its own
chain masks `0x0f0f0f0f` alone and meets the six-bit chain only at the
`v_and_or_b32` that merges the two high bits back. Every other vector load on
the weight buffer is a nibble read. An instruction no load reaches inherits the
phase its consumers agree on, and what survives that is reported as `residue`
rather than folded away.

Four counts join the split to E1's: `address` reads 48 in both, `dot_float`
equals `multiply_accumulate` plus `activation` at 116, `unpack_convert` equals
`weight_decode` plus `scale_decode` plus the residue at 165, and `lane_mask` is
1. The pre-E4 control reproduces E1's 366 with the same four joins.

The classifier is validated on the Q4_K family and refuses reading on Q6_K. Run
against `isa/mul_mat_vec_q6_k_f32_f32.s` it reports one weight instruction per
row for sixteen weights per row, because Q6_K's own bit-plane merge masks
`0x0f0f0f0f` and joins the scale chain, and the role closure then claims the
weight loads. That is a limit of the role rule rather than a finding about
Q6_K.

The address arithmetic settles a load-width question E1 left with the right
byte total and the wrong roles. Tracing the block base through
`v_lshl_add_u32 v24, v24, 7, v25` after `v_lshlrev_b32 v25, 4, v24` gives a
stride of 144 bytes, which is `block_q4_K`'s own size, and the five loads per
row are then: the `dm` pair as one `buffer_load_dword` at offset 0, the pair
`scales[v_im]` and `scales[v_im+2]` as one `buffer_load_dwordx2` at the
four-byte-aligned scale base, `scales[v_im+4]` as one `buffer_load_ushort` at
offset 12, and the two `qs` dwords at offset 16 plus `q_offset` and plus
`q_offset + 64`. E1 read the `dwordx2` as `dm` and the plain dword as a scale
halfword; the byte total is 152 per lane per superblock either way, and the
merge is what the `v_alignbyte_b32` pair in the scale phase exists to undo.

## Table 1: every instruction of the loop body and the reduction

`NUM_ROWS = 4`, one superblock across four output rows, the served shape. The
body is lines 101-501 of the disassembly, BB10 through the back edge, which is
the range E1 uses. The reduction is BB11, lines 503-567, outside the loop.

| phase | pre-E4 | per row | E4 | per row | share | chain | the instructions |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| multiply_accumulate | 152 | 38.00 | 104 | 26.00 | 31.5% | 9 | 76 `v_mac_f32`, 4 `v_mad_f32`, 24 `v_mul_f32` |
| weight_decode | 88 | 22.00 | 88 | 22.00 | 26.7% | 3 | 64 `v_cvt_f32_ubyte0..3`, 16 `v_and_b32`, 8 `v_lshrrev_b32` |
| scale_decode | 76 | 19.00 | 76 | 19.00 | 23.0% | 7 | 32 `v_cvt_f32_ubyte0..3`, 8 `v_cvt_f32_f16`, 8 `v_alignbyte_b32`, 8 `v_and_b32`, 4 each of `v_and_or_b32`, `v_lshl_or_b32`, `v_mov_b32_sdwa`, `v_lshrrev_b32`, `v_add_u32` |
| activation | 0 | 0.00 | 12 | 3.00 | 3.6% | 3 | 12 `v_add_f32`, E4's hoisted group sums |
| address | 48 | 12.00 | 48 | 12.00 | 14.5% | 5 | 33 `v_add_u32`, 7 `v_lshlrev_b32`, 5 `v_lshl_add_u32`, 2 `v_lshrrev_b32`, 1 `v_and_b32` |
| lane_mask | 1 | 0.25 | 1 | 0.25 | 0.3% | 1 | 1 `v_cmpx_le_u32` |
| residue | 1 | 0.25 | 1 | 0.25 | 0.3% | 1 | 1 `v_add_u32`, the loop induction step |
| **body total** | **366** | **91.50** | **330** | **82.50** | **100%** | **17** | 24 VMEM, 22 SALU, 23 `s_waitcnt` |
| reduction, per workgroup | 32 | 8.00 | 32 | 8.00 | -- | 8 | 24 `v_add_f32_dpp`, 4 `v_readlane_b32`, 4 `v_cndmask_b32` |

The whole-body chain of 17 against 330 VALU says the body is issue-bound, so a
change has to move the count. The pre-E4 control's chain is 29, and E4's whole
saving is visible in one cell: the multiply-accumulate falls 152 to 104 and its
own chain 18 to 9 while the weight decode, the scale decode, the address
arithmetic, and the 24 memory instructions are untouched. That localizes E1's
measured -36 to the phase E4 names and rules out a side effect in any other.

The per-phase chains are descriptive. A phase chain matters only where a change
would serialize on it, and the scale decode's 7 is the longest of the four
because the six-bit repack is a chain: `v_alignbyte` pair, `v_mov_b32_sdwa`
merge, `v_and_b32` mask, `v_lshrrev_b32` shift, `v_and_or_b32` merge, then the
conversion.

### The SALU stream

414 SALU shader-wide, 19 inside BB10 and 22 counting the two blocks that close
the loop. Per superblock iteration it is one `s_load_dwordx8` reloading both
buffer descriptors, three scalar instructions per output row forming that row's
block base (`s_mul_i32` and two `s_add_u32`, measured at 3, 6, 12, 24, and 48
across `NUM_ROWS` 1 to 16), four mask constants (`0x0f0f0f0f`, `0xc0c0c0c0`,
`0x3f3f3f3f`, `0x8000`), three exec-mask instructions, and the back edge.

One of the 22 is on the critical path. The `s_load_dwordx8` opens the body and
an `s_waitcnt lgkmcnt(0)` sits between it and the iteration's first
`buffer_load_dwordx4`, and `depth.py` records exactly one `lgkmcnt` wait and
`max_lgkm_in_flight 1` per iteration, so every superblock iteration begins by
waiting on a scalar-cache read of the descriptors. The other 21 are not: the
Vega ISA issues at most one instruction of each category per cycle from
different waves, so 19 SALU beside 329 VALU occupies the scalar pipe for 5.8%
of the body. That last figure is an issue-rate reading of a static count and
this receipt measures no issue.

The remaining 392 sit outside the loop. Two 49-instruction blocks are the
`get_offsets` prologues of the two inlined `compute_outputs` call sites, at
lines 15-78 and 715-778, and they carry the shader's 12 `s_mul_hi_u32` and 21
`s_sub_i32`, which is magic-number division of the batch indices. Two
reductions carry 24 `s_nop` each, inserted for the DPP read-after-write hazard.
The per-row store path carries 32 `s_cbranch_scc0`, 19 `s_cmp_ge_u32`, and 18
`s_cmp_lg_i32`. None of it runs per superblock.

## Table 2: the shape sweep

One module, one lab, five specialization values of `NUM_ROWS`. `--spec 1:N` is
the whole difference between arms; `BLOCK_SIZE` stays 64 and `NUM_COLS` 1.

| field | N=1 | N=2 | N=4 | N=8 | N=16 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `isa_sha256` head | `9388d4cc` | `80418d9c` | `29454587` | `299ef0ed` | `e9da0563` |
| VALU | 275 | 456 | 810 | 1520 | 2937 |
| SALU | 220 | 287 | 414 | 667 | 1170 |
| VMEM | 20 | 32 | 56 | 104 | 200 |
| SMEM | 14 | 22 | 38 | 70 | 134 |
| `v_mac_f32` | 38 | 76 | 152 | 304 | 608 |
| VGPR | 36 | 48 | 64 | 64 | 64 |
| SGPR | 48 | 48 | 48 | 48 | 48 |
| spilled VGPR / SGPR | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| LDS bytes | 0 | 0 | 0 | 0 | 0 |
| scratch | 0 | 0 | 0 | 0 | 0 |
| code size, bytes | 2568 | 3896 | 6480 | 11668 | 22040 |
| longest VALU chain | 17 | 17 | 17 | 17 | 17 |
| `Subgroups per SIMD`, driver | 7 | 5 | 4 | 4 | 4 |
| `floor(256 / VGPR)` | 7 | 5 | 4 | 4 | 4 |
| body VALU | 100 | 178 | 330 | 636 | 1245 |
| **body VALU per row** | **100.00** | **89.00** | **82.50** | **79.50** | **77.81** |
| body VMEM | 9 | 14 | 24 | 44 | 84 |
| body bytes per lane per row | 86.00 | 54.00 | 38.00 | 30.00 | 26.00 |
| reduction VALU per row | 8.00 | 8.00 | 8.00 | 8.00 | 8.00 |

The occupancy column is arithmetic checked against the driver rather than
computed silently. A gfx9 SIMD holds 256 VGPRs per wave64 slot, so the waves
per SIMD are `floor(256 / VGPR)` capped at 10, and `floor(256/36) = 7`,
`floor(256/48) = 5`, `floor(256/64) = 4` reproduce the driver's own
`Subgroups per SIMD` at every arm. `lab.sh` leaves `waves_per_simd` reading `-`
in `stats.tsv` because the driver names that statistic `Subgroups per SIMD` and
the field selector matches the substring `wave`, so the number is read from the
retained `shaderstats.txt` the way E1 reads it.

Every phase is linear in `N` and the split says which term is fixed. The
multiply-accumulate is `26N` at all five arms and the scale decode `19N` at all
five, exactly. The weight decode is `22N` at four arms and `22N + 1` at N=8,
where ACO holds one value in a `v_mov_b32`. The address phase is `9N + 12` from
N=2 up, and 19 at N=1, where the single-row form needs two fewer rebases. The
activation phase is the constant 12 the group sums cost, plus one register move
at N=8 and three at N=16. The whole body is therefore `76N + 26` exactly at
N=2 and N=4 and within three instructions at N=8 and N=16.

The per-row fall from 100.00 to 77.81 is that fixed 26 and the address phase's
own fixed 12 amortizing. The 67 per row of multiply-accumulate, weight decode,
and scale decode is a floor no shape reaches past, and the 9 per row of address
rebase is what candidate 3 targets.

No arm spilled, none allocated LDS or scratch, and the whole-shader dependent
chain held at 17 across a tenfold code-size range.

## Table 3: the packed-FP16 probes

Three `remote/isa-probes/` shaders sharing one buffer layout, one nibble
extraction, eight products per lane, and one workgroup reduction, differing in
the arithmetic type alone. `q4k-float-dot.comp` is the existing E2 control.

| field | `q4k-float-dot` | `q4k-packed-f16-dot` | `q4k-mixed-f16-dot` |
| --- | ---: | ---: | ---: |
| `spirv_sha256` head | `b192014b` | `488a7723` | `35f61f83` |
| `isa_sha256` head | `b26bab68` | `f2522e0f` | `b26bab68` |
| VALU | 96 | 107 | 96 |
| VGPR / SGPR | 36 / 16 | 36 / 16 | 36 / 16 |
| code size, bytes | 880 | 960 | 880 |
| `v_mac_f32` | 6 | 0 | 6 |
| `v_pk_fma_f16` | 0 | 3 | 0 |
| `v_pk_mul_f16` | 0 | 1 | 0 |
| `v_mad_mix_f32` | 0 | 0 | 0 |
| `v_cvt_f16_f32` | 0 | 12 | 0 |
| `v_cvt_f32_f16` | 0 | 2 | 0 |
| SDWA operand uses | 4 | 9 | 4 |

`receipt-diff.sh` over the float and mixed pair reports the SPIR-V changed, the
final NIR changed, and `isa_sha256` the same, which is the `isa_identical`
verdict: `float16_t` operands with a `float` accumulator produce the f32
control's exact instruction stream, `v_mad_mix_f32` is never selected, and the
mixed form buys nothing at all. The packed pair changes the ISA and the receipt
says what it costs.

## The verdict: scale decode is the lever, packed FP16 is negative

ACO does form the packed instruction. The packed probe replaces six
`v_mac_f32` and one `v_mul_f32` with three `v_pk_fma_f16` and one
`v_pk_mul_f16`, saving three instructions across eight products, and it pays
twelve `v_cvt_f16_f32` to bring the operands into half precision and two
`v_cvt_f32_f16` to leave, so its VALU rises 96 to 107. The mechanism is that a
Q4_K weight reaches f32 in one `v_cvt_f32_ubyte` directly from a byte lane and
reaches f16 only through f32, so a packed formulation adds a conversion per
value instead of replacing one.

Carried onto the mat-vec, the count runs the same way, and the carry is an
extrapolation rather than a receipt. The multiply-accumulate phase is 26 per
row: 20 fused multiply-adds and 6 multiplies, of which only the 16
weight-activation products pack. The four scale products, the three
minimum-term products, the two `dm` products, and the final accumulate are f32
by construction. Sixteen packed products would be eight `v_pk_fma_f16` plus
four cross-half adds to recover `sx` through `sw`, twelve in place of sixteen,
which is -4 per row. Against that the probe spends 1.5 conversions per product
where the f32 control spends 1, and the mat-vec's own operands are 16 weights
per row and 16 activations amortizing at 16/N, so the added conversions are at
least 16 per row on the weights alone. A route through `v_cvt_f16_u16` with an
SDWA byte select would be neutral on the weight side and it is not the route
ACO takes from this GLSL. Every reading of that extrapolation is positive, and
the probe is what measures the sign.

The scale decode is 19 per row, 25.0% of the 76-per-row body, and four of those
nineteen are the `v_im` halfword selection alone: two `v_alignbyte_b32`, one
`v_mov_b32_sdwa`, and one `v_add_u32` per row undoing the `buffer_load_dwordx2`
merge. One `v_perm_b32` lays those four bytes in their place, so the phase falls
3 per row with no change to the accumulation format. One lever is -3 per row
and the other at least +12, and the scale-decode side is the one that leaves
the numerics alone, so the scale-decode restructuring is the larger lever and
the packed-FP16 formulation is refuted rather than ranked.

The largest phase is the multiply-accumulate at 26 per row. The largest
removable is the address rebase at 9 per row, 11.8% of the body, and the
mechanism it needs is stated in candidate 3 below. That 9 is a ceiling
constructed from the instruction stream rather than measured: no arm has
compiled the distributed form, where candidate 1's -3.64% is a receipt. The
list below is ordered by what a run would settle, so the measured candidate
leads and the larger unmeasured ceiling follows it.

## The ranked candidates for the next kernel-delta arm

E4's own transfer from VALU delta to exclusive bracket delta is 0.48, one
observation on this shader, device, and tuple, so a point estimate below rests
on a single point and carries no band. No candidate here reaches the 2.7 ms per
token the 2B promotion needs; E4b-A is refuted at 1.6% of the consumer, and the
whole per-row body outside the multiply-accumulate is 50 instructions of a
76-instruction row.

**1. `NUM_ROWS = 8`, a specialization constant with no source edit.** The
activation load and its group sums are per column and the address phase carries
a fixed 12, so both amortize over twice as many rows: the body falls 82.50 to
79.50 VALU per row, -3.64%, and the vector-memory demand 38 to 30 bytes per
lane per row, -21%. VGPR holds at 64, no spill, no scratch, and the driver
reports 4 subgroups per SIMD on both arms, so the occupancy step is unchanged.
Point estimate at the 0.48 transfer: -1.7% of the Q4_K exclusive bracket.
*Falsifier.* The host rather than the receipt. `ggml-vulkan.cpp` passes
`rm_kq = 4` on the `AMD_GCN` branch and the decode ledger records
`constants=64,4,1`, so the arm needs the host to create and select the eight-row
pipeline, and a row count not divisible by eight sends its remainder through
`compute_outputs(first_row, p.stride_d - first_row)`, whose blocks are the ones
the unroll does not reach. A receipt showing VGPR above 64 or `spilled_vgprs`
above 0 at the shape the host creates refutes it; both are 0 at `0:64 1:8 2:1`.

**2. The `v_im` halfword selection.** `scales[v_im]` and `scales[v_im+2]` sit
four bytes apart, so ACO merges them into one `buffer_load_dwordx2` and then
spends two `v_alignbyte_b32`, one `v_mov_b32_sdwa`, and one `v_add_u32` per row
selecting the pair back out. `v_im` is invariant across both loops, so a source
that lays the two halfwords with one `v_perm_b32` from a selector hoisted out
of the superblock loop replaces four instructions with one. Predicted -3 of 76
per row, -3.9%, constructed from the instruction stream rather than compiled,
and the accumulated value is unchanged bit for bit.
*Falsifier.* `v_perm_b32` staying at 0 in the receipt with `v_alignbyte_b32`
unchanged says GLSL cannot reach the byte permute on this chain, which closes
the candidate at the compiler and restates E2b's finding on a second chain.

**3. The address rebase through the buffer `soffset` field.** The block byte
address is `(ib0(n) + i) * 144`, where `ib0(n)` is workgroup-uniform and `i` is
lane-dependent through `ix = tid/16`. Distributing the multiply gives a uniform
`ib0(n) * 144`, which a `buffer_load` takes in its SGPR `soffset` operand, and a
divergent `i * 144`, which is row-independent and computed once. ACO does not
distribute it: the body issues `v_add_u32`, `v_lshlrev_b32`, and
`v_lshl_add_u32` per row to rebuild the base and six further `v_add_u32` to
rebuild the same five offsets, nine per row in total. Predicted ceiling -9 of 76
per row, -11.8%, the largest named block in the body and the address half E3
left open. The ceiling is constructed from the instruction stream and rests on
ACO distributing a multiply it does not distribute today, so it ranks below
candidate 1 on what a run would settle and above it on size. *Falsifier.* `address` in the phase table failing to fall below
`5N + 12` after the rewrite says the distribution did not survive NIR and the
candidate is closed at the compiler.

**4. The per-iteration descriptor load.** The body opens with
`s_load_dwordx8 s[24:31]` and an `s_waitcnt lgkmcnt(0)` before its first vector
load, so every superblock iteration begins on a scalar-cache read.
`depth.py` records one `lgkmcnt` wait and `max_lgkm_in_flight 1` per iteration.
It removes no VALU and one serialization point per iteration.
*Falsifier.* SGPR pressure. The shader allocates 48 SGPRs and reuses `s[0:1]`
for the exec save, which is why ACO rematerializes the descriptor pointer; a
receipt showing `spilled_sgprs` above 0 refutes the form.

**5. The packed-FP16 dot: refuted on the compile side, not scheduled.** The
probes above are the whole reason, and a device arm would measure the +11
instructions the receipt already reports.

## Reproducing every number

The shim wrapper and its two inputs are
`evidence/e4b-summary-producer/radv-raven2-shim-env.sh` with `QWEN_RADV_ICD`
naming a `radeon_icd.json` whose `library_path` points at the extracted
`libvulkan_radeon.so` of the installed Mesa and `QWEN_AMDGPU_DRM_SHIM` naming
`libamdgpu_noop_drm_shim.so` from a build of the same release. The ICD and the
shim come from one release, since `ac_gpu_info.c` refuses an amdgpu node below
DRM 3.54.0.

```sh
# The module, either route; both reach isa_sha256 29454587...185a1d.
SHADERS=$HOME/src/llama.cpp-e4b-stack/ggml/src/ggml-vulkan/vulkan-shaders
DEFS="-DDATA_A_Q4_K=1 -DFLOAT_TYPE=float -DFLOAT_TYPEV2=vec2 -DB_TYPE=float \
      -DB_TYPEV2=vec2 -DB_TYPEV4=vec4 -DD_TYPE=float -DUSE_SUBGROUP_ADD_NO_SHMEM=1"
glslc -fshader-stage=compute --target-env=vulkan1.2 -I "$SHADERS" \
    "$SHADERS/mul_mat_vec_q4_k.comp" -o $SCRATCH/base.spv -O $DEFS

# One receipt per shape. NUM_ROWS is spec constant 1.
for rows in 1 2 4 8 16; do
    evidence/e4b-summary-producer/radv-raven2-shim-env.sh \
        remote/raven2-shader-lab/lab.sh $SCRATCH/base.spv $SCRATCH/nr$rows \
        --spec 0:64 --spec 1:$rows --spec 2:1 --subgroup 64 \
        --bindings 5 --push-constants 52 --per-superblock 256
    python3 remote/raven2-shader-lab/depth.py \
        $SCRATCH/nr$rows/isa.s $SCRATCH/nr$rows/depth.tsv
done

# The three FP16 probes, at the bindings run-probe.c declares.
for probe in q4k-float-dot q4k-packed-f16-dot q4k-mixed-f16-dot; do
    glslc --target-env=vulkan1.3 -O -fshader-stage=compute \
        remote/isa-probes/$probe.comp -o remote/isa-probes/$probe.spv
    evidence/e4b-summary-producer/radv-raven2-shim-env.sh \
        remote/raven2-shader-lab/lab.sh remote/isa-probes/$probe.spv \
        $SCRATCH/probe-$probe --subgroup 64 --bindings 3
done
remote/raven2-shader-lab/receipt-diff.sh \
    $SCRATCH/probe-q4k-float-dot $SCRATCH/probe-q4k-mixed-f16-dot
remote/raven2-shader-lab/receipt-diff.sh \
    $SCRATCH/probe-q4k-float-dot $SCRATCH/probe-q4k-packed-f16-dot

# The phase split. The line ranges name the loop body and the reduction in
# each file: BB10 through the back edge, and the block holding v_add_f32_dpp.
E1=evidence/raven2-vulkan-kernel-census/e1
Q=evidence/q4k-isa-attribution
python3 $Q/classify-loop-phases.py $E1/isa/e4-control-subgroup-no-shmem.s \
    101 536 pre-e4-control-body --rows 4

# Every shape, over the disassembly each row was read from. N=4 reads the E1
# file, since receipts/num-rows-4/ retains no copy of a byte-identical stream.
# The four numbers per row are the body range then the reduction range.
printf '%s\n' "1 97 228 230 246"   "2 99 320 322 354"  "4 101 501 503 567" \
               "8 107 854 856 984" "16 113 1571 1573 1829" |
while read -r rows body_first body_last reduce_first reduce_last; do
    isa=$Q/receipts/num-rows-$rows/isa.s
    [ "$rows" = 4 ] && isa=$E1/isa/e4-candidate-subgroup-no-shmem.s
    python3 $Q/classify-loop-phases.py "$isa" "$body_first" "$body_last" \
        e4-body-num-rows-$rows --rows "$rows"
    python3 $Q/classify-loop-phases.py "$isa" "$reduce_first" "$reduce_last" \
        e4-reduction-num-rows-$rows --rows "$rows"
done
```

Each body range runs from the line after the label of the block holding the
four `buffer_load_dwordx4` through the `s_cbranch` that branches back to that
label, and each reduction range is the block holding the first
`v_add_f32_dpp`. Both are derived rather than read off: the body's first line
is the label line plus two and the reduction ends before the next label.

## What is retained

| file | what it is |
| --- | --- |
| `phase-attribution.tsv` | every phase row of both tables, eleven labels |
| `salu-attribution.tsv` | the SALU class split for the same eleven ranges |
| `shape-sweep.tsv` | Table 2, whole-shader receipt fields beside the body-derived per-row figures |
| `fp16-probe-receipts.tsv` | Table 3 |
| `classify-loop-phases.py` | the rule that produced the phase rows |
| `receipts/num-rows-N/` | `lab.sh`'s own receipt, statistics, depth table, and disassembly per shape; N=4 keeps no `isa.s`, since it is byte-identical to `e1/isa/e4-candidate-subgroup-no-shmem.s` |
| `receipts/probe-*/` | the same six files per probe |
| `receipts/receipt-diff-float-*.tsv` | `receipt-diff.sh`'s own verdict over each probe pair |

The `pipeline_created` and `spirv_path` fields carry `$SCRATCH` in place of the
working directory, the convention `evidence/e4b-summary-producer/` sets. Each
receipt records `run_mode=device`, `device_name`, and `driver_name`, and a
reading is made against those three first: another driver compiles the same
SPIR-V with another compiler and answers a question about that compiler.

## What did not run

- **Every device arm.** No submission executed; the shimmed node ends at
  pipeline creation and no figure here is a time. The served kernel-delta A/B,
  the margin witness, and the Q6_K null all need the appliance and a teardown
  window, and the laptop belongs to another lane.
- **The host side of `NUM_ROWS = 8`.** `ggml-vulkan.cpp` creates the four-row
  pipeline; nothing here changes what it creates or selects, so candidate 1 is
  a receipt and not yet an arm.
- **The independent-wave Y variant.** `mul_mat_vec_q4_k.comp` declares
  `local_size_y = 1` and `compute_outputs` threads its whole indexing through
  `gl_WorkGroupSize.x`, from `it_size = gl_WorkGroupSize.x/16` to the `tid`
  `reduce_result` reduces over, so giving y its own row brick is a source change
  reaching the reduction rather than a specialization value. It is out of scope
  here and the FP16 probes took its place.
- **Candidates 2, 3, and 4 as receipts.** Each is a prediction the lab settles
  in one run, and none of the three source forms was written.
- **The repository gate.** `refresh-evidence-manifest.sh --check` and
  `check-text-policy.py` ran; the full gate did not, since it carries device
  tests that refuse while a server holds the device.
- **shellcheck.** No shell file was added or edited on this lane.

## The wait-accounting correction these tables were regenerated under

`depth.py` cleared its outstanding-memory counter at every `s_waitcnt`, but a
wait at `vmcnt(k)` retires issues down to `k` and leaves `k` of them
outstanding, so a descending ladder of partial waits undercounted every
interval after the first. `wait_accounting` now carries `min(outstanding, k)`
into the next interval, and `test-depth.py` gains a third block whose three
loads, `vmcnt(2)`, two further loads, and `vmcnt(0)` read a peak of 4 where the
cleared counter read 3.

`longest_valu_chain` never touched that counter: it is the longest path over
register definitions and uses, so no chain figure on this page moves. Two
fields do, and every retained table in this tree was regenerated to find them.
`max_lgkm_in_flight` rises 17 to 18 in the reduction block of all three FP16
probes, whose LDS reduction is a descending `lgkmcnt` ladder, and
`max_vmem_in_flight` rises 15 to 23 in the loop body of
`evidence/e4b-summary-producer/receipts/e4b-consumer/depth.tsv`, whose
sideplane read splits the body's single ladder in two. Every shape-sweep arm is
unchanged, since the Q4_K body issues all 24 of its loads before its first
wait, and so are the E4 consumer and producer tables and both E4 pair tables in
`evidence/raven2-vulkan-kernel-census/e1/receipts/`. No number quoted on this
page changed.
