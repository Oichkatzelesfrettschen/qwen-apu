# E1 and E1.5: the pinned mat-vec inventory, and the E4 mechanism receipt

The Q4_K mat-vec the 2B decode graph dispatches 162 times issues 91.5 VALU
instructions per lane per 256-weight superblock per output row, against the 77
`decode-decomposition.md` estimates from the GLSL. The registered falsifier for
the operation-count account is a normalized count below 50; the measurement is
83% above it, so the account stands. Address arithmetic is 13.1% of the body
against the 10% floor E3 registered, so E3's address half stands. E3's SGPR half
closes instead, and it closes on a mechanism rather than on a threshold: at
`BLOCK_SIZE = 64` the four sixteen-lane groups of one wave64 read four different
superblocks in the same iteration, so the `dm` pair and the twelve scale bytes
are sixteen-lane-uniform and no scalar load can serve them. Hoisting the
wave-uniform bases into SGPRs is unavailable at this workgroup size, and the
address arithmetic itself is what E3 has left to take. The Q4_K-against-Q6_K
prediction survives on direction and fails on magnitude: 91.5 against 86.75, a
5.5% excess where the census measured Q6_K streaming its bytes 42% faster.

`patches/llama-vulkan-q4k-activation-group-sums.patch` reaches the device.
`receipt-diff.sh` reports `isa_changed` with `first_divergence=spirv` and
`last_divergence=isa`, VGPR flat at 64, no spill, no scratch, LDS unchanged and
four subgroups per SIMD on both arms. Rung 4 of the E4 ladder passes and the
served ABBA is licensed.

The final NIR the driver hands ACO carries the redundant sixteen-term minimum
term intact, so NIR performs no hoist of its own.

## What produced these files

The census instrument wrote the executed SPIR-V under
`GGML_VK_PIPELINE_CENSUS_DUMP`, one file per pipeline named by the digest the
decode ledger publishes as `spirv_executed_sha256`. `RADV_DEBUG=shaders` over
the same served request wrote the driver's own disassembly, which
`remote/summarize-radv-isa.py` split into `isa-split/NNN.s` and indexed without
names. `remote/raven2-shader-lab/lab.sh` then created one pipeline per module
on the appliance, beside the running server, and retained each compiler layer.

| retained | what it is |
| --- | --- |
| `isa-index.tsv` | the 34 shaders the served run compiled, in compile order, with register and class counts |
| `radv-shaders.log.xz` | the whole `RADV_DEBUG=shaders` stream the index was derived from |
| `module-sha256.tsv` | the 28 dumped modules by digest |
| `isa/mul_mat_vec_q4_k_f32_f32.s`, `isa/mul_mat_vec_q6_k_f32_f32.s` | the served disassembly of the two pinned mat-vecs, split from that log |
| `isa/e4-control-subgroup-no-shmem.s`, `isa/e4-candidate-subgroup-no-shmem.s` | the E4 pair in the reduction variant the appliance executes |
| `receipts/*-receipt.tsv`, `receipts/*-depth.tsv` | one shader lab receipt and dependency-depth table per run |
| `receipts/e4-receipt-diff-*.tsv` | `receipt-diff.sh` over each E4 pair |
| `stats/*-shaderstats.txt` | the driver's statistics block verbatim |
| `nir/*-final.nir` | the NIR `radv_postprocess_nir` handed ACO |
| `superblock-valu-categories.tsv`, `classify-superblock-valu.py` | the category split and the rule that produced it |

## The join: module digest, ledger name, and log block

The census ledger names a pipeline and publishes the digest of the module that
executed it. The RADV log lists shaders in compile order and names none. The lab
closes the gap by construction: it compiles the ledger's own module and retains
the ISA, and that ISA is compared against the log's split block as text.

| ledger row | module | log index | lab `isa.s` against `isa-split/NNN.s` |
| --- | --- | ---: | --- |
| id 31 `mul_mat_vec_q4_k_f32_f32`, `constants=64,4,1`, `subgroup=64` | `a9ac07dd...4519d0d` | 31 | equal, apart from the leading `Compute Shader` stage-name line the split retains |
| id 27 `mul_mat_vec_q6_k_f32_f32`, `constants=64,4,1`, `subgroup=64` | `d584d6b4...c12c779` | 27 | equal, on the same one line |

Text equality over 1518 and 2802 instruction lines leaves no ambiguity, so the
join rests on the instruction stream rather than on a statistic. Three
corroborations agree with it and none of them would have been sufficient alone:

- The driver's `Code size` matches: 6764 for Q4_K at index 31 and in the lab,
  13420 for Q6_K at index 27 and in the lab.
- The register triple matches: Q4_K 64 VGPR, 48 SGPR, 0 LDS; Q6_K 64, 48, 512.
  The Q4_K triple selects two index rows, 16 and 31, so the triple alone does
  not join; `code_size` and `valu_count` separate them, since index 16 reads
  1764 and 105 against index 31's 6764 and 882.
- The class counts match once the two counting conventions are reconciled.
  `summarize-radv-isa.py` reads index 31 at `salu_count` 497 where the lab reads
  414; the difference is exactly the 82 `s_waitcnt` and the one `s_endpgm` the
  lab excludes from SALU by its own stated rule, and `valu_count` 882 and
  `vmem_count` 56 are equal in both.

The `code_sha256` of the index row and the `isa_sha256` of the receipt differ
(`aa810ecd...` against `ad837848...`) because the two extractions trim their
blocks differently, and the text comparison above is what settles that they
carry the same instructions.

Every one of the 26 `pipeline` rows in the decode ledger agrees with the
same-numbered index row on VGPRs, SGPRs, LDS, spilled VGPRs, and scratch, so the
compile-order index and the census pipeline id coincide across the whole ledger.
That is a joint observation rather than the join: compile order and pipeline id
are independent enumerations, and nothing in either file requires them to agree.

## The compiler that produced the executed module is not either host's

No `glslc` on either machine reproduces `a9ac07dd...`. The appliance's shaderc
2023.8 compiles the pinned f280b269 source to `5b149b21...` for the
`_subgroup_no_shmem` variant and the workstation's shaderc 2026.3 to
`85bf7a25...`. The executed module declares `SPV_KHR_float_controls` with
`DenormPreserve 16` and `RoundingModeRTE 16` and carries no `NonReadable` or
`NonWritable` decorations, where both current compilers do the opposite. Its
function-body opcode histogram equals the appliance-compiled variant's exactly,
and ACO erases the remaining difference: the executed module and the
appliance-compiled control compile to one ISA, `isa_sha256 ad837848...`. The
executed variant is therefore `_subgroup_no_shmem`, which the ledger's `lds 0`
already implied, and the E4 control below is that module's exact instruction
stream rather than a re-derivation of it.

## The lab environment every count below is read against

| field | value |
| --- | --- |
| `device_name` | AMD Radeon Graphics (RADV RAVEN2) |
| `driver_name`, `driver_info` | radv, Mesa 26.2.1+git2608201115.88947685514~n~mesarc0 |
| `device_api_version` | 1.4.354 |
| `spec_constants` | `0:64,1:4,2:1` (`BLOCK_SIZE`, `NUM_ROWS`, `NUM_COLS`) |
| `subgroup_size_requested`, min, max | 64, 64, 64 |
| `bindings`, `push_constant_bytes` | 5, 52 |
| `robust_buffer_access` | off |
| `features_enabled` | shaderInt8, storageBuffer16BitAccess, storageBuffer8BitAccess, subgroupSizeControl, computeFullSubgroups |

## E1, the inventory

The unit is the superblock loop body of the fully unrolled
`compute_outputs(first_row, NUM_ROWS)` call site: one iteration of
`for (i = ix; i < num_blocks_per_row; i += it_size)`, which covers one
256-weight superblock across `NUM_ROWS = 4` output rows. Sixteen lanes share a
superblock in both kernels (`it_size = gl_WorkGroupSize.x/16`), each lane owning
sixteen weights, so per-lane-per-superblock-per-row is the unit
`decode-decomposition.md`'s 77-operation estimate is written in and the unit its
falsifier of 50 is written in. The block is `BB10` lines 101-536 in the Q4_K
disassembly and `BB7` lines 105-540 in the Q6_K, each closed by the back edge
`s_cbranch` to its own label.

The divisor of four is read out of each body rather than assumed from
`NUM_ROWS`, because it is the number the falsifier and the cross-kernel
comparison both rest on. Q4_K's body holds 96 `v_cvt_f32_ubyte*`, which is 24
per row -- sixteen nibbles and eight scale bytes -- and 128 fused multiply-adds
with 24 multiplies, the by-hand GLSL count at `NUM_ROWS = 4` in
`e4/spirv-comparison.md`. Q6_K's body holds 64 `v_cvt_f32_ubyte*`, sixteen
weights per row over four rows, 64 `v_add_f32` for the same weights' `- 32`
bias, and 64 fused multiply-adds for the dot, with its per-row scale arriving as
one `buffer_load_sbyte` and one `v_cvt_f32_i32`. Both bodies cover one
superblock across four rows.

A mnemonic does not name a role, since `v_add_u32`, `v_lshlrev_b32`, and
`v_lshl_add_u32` compute both addresses and unpacked fields.
`classify-superblock-valu.py` marks a VALU instruction as address arithmetic
where a backward slice from a memory instruction's address operand reaches it
inside the block, treats the float multiply, add, and multiply-add mnemonics as
dot arithmetic, `v_cmp` and `v_cmpx` as lane mask, and the residue as unpack and
convert. Nothing is left unclassified.

| category | Q4_K per superblock | per row | Q6_K per superblock | per row |
| --- | ---: | ---: | ---: | ---: |
| dot arithmetic | 152 | 38.00 | 148 | 37.00 |
| unpack and convert | 165 | 41.25 | 150 | 37.50 |
| address arithmetic | 48 | 12.00 | 49 | 12.25 |
| lane mask | 1 | 0.25 | 0 | 0.00 |
| reduction | 0 | 0.00 | 0 | 0.00 |
| **VALU total** | **366** | **91.50** | **347** | **86.75** |
| share address | 13.1% | | 14.1% | |
| VMEM in body | 24 | 6.00 | 24 | 6.00 |
| LDS in body | 0 | 0.00 | 12 | 3.00 |
| SALU in body | 19 | | 24 | |
| `s_waitcnt` in body | 22 | | 26 | |
| `longest_valu_chain` | 29 | | 22 | |

The Q4_K dot arithmetic decomposes as 124 `v_mac_f32` plus 4 `v_mad_f32`, which
is 128 fused multiply-adds, and 24 `v_mul_f32`. That is the count
`e4/spirv-comparison.md` derives by hand from the GLSL at `NUM_ROWS = 4`, 128
`Fma` and 24 `FMul`, reproduced instruction for instruction on the device. Of
the 128, sixty-four are the weight dot and sixty-four the minimum term.

The unpack path is the largest category in both kernels and it runs on the
operand machinery gfx902 does carry: 96 `v_cvt_f32_ubyte0..3` per Q4_K
superblock convert the nibble and scale bytes in one instruction each, with 8
`v_alignbyte_b32`, 8 `v_cvt_f32_f16`, and 16 SDWA operand uses beside them.
`v_perm_b32` is absent, as are every integer multiply-add form, which is the
E2 question rather than this one.

The reduction sits outside the loop in both kernels and costs 32 VALU for four
rows once per workgroup: 24 `v_add_f32_dpp`, 4 `v_readlane_b32`, and 4
`v_cndmask_b32`, with 24 `s_nop` for the DPP hazards. Q6_K's 512 bytes of LDS
are its scale cache rather than its reduction; both kernels report 32 DPP uses.

### Occupancy and register residency

| field | Q4_K | Q6_K |
| --- | ---: | ---: |
| VGPRs | 64 | 64 |
| SGPRs | 48 | 48 |
| spilled VGPRs, spilled SGPRs | 0, 0 | 0, 0 |
| scratch | 0 | 0 |
| LDS | 0 | 512 |
| Subgroups per SIMD | 4 | 4 |
| code size | 6764 | 13420 |

Both allocate 64 VGPRs, which is what puts four wave64 subgroups on a SIMD, and
the ledger's `subgroups_per_simd` of 4 and prediction P5's window of 40 to 64
VGPRs are both met. `stats.tsv` leaves `waves_per_simd` reading `-` because the
driver names the statistic `Subgroups per SIMD` and `lab.sh` selects that field
by the substring `wave`; the number is read from the retained
`stats/*-shaderstats.txt` instead.

The wave-uniform bases are not in SGPRs. The Q4_K body issues one
`s_load_dwordx8` and no `s_buffer_load`: the `dm` pair arrives as 4
`buffer_load_dwordx2`, the packed scale halfwords as 4 `buffer_load_ushort`
inside the 12 `buffer_load_dword`, and the activations as 4
`buffer_load_dwordx4`. The whole shader's 37 SMEM instructions are 16
`s_buffer_load_dword` of inlined push constants and 21 descriptor loads.

E3 registered that finding as a reason to hoist those terms into SGPRs. The
shader's own thread mapping refutes the hoist rather than inviting it. At
`BLOCK_SIZE = 64` the loop step is `it_size = gl_WorkGroupSize.x/16 = 4` and the
superblock index is `i0 + ix` with `ix = tid/16`, so the four sixteen-lane
groups of one wave64 read four different superblocks in the same iteration. The
`dm` pair and the twelve scale bytes are sixteen-lane-uniform and not
wave-uniform, and no scalar load can serve them at this workgroup size. That
leaves the address arithmetic itself, 13.1% of the body, as E3's remaining
target.

### The registered falsifiers

| falsifier | reading | outcome |
| --- | --- | --- |
| E1: a Q4_K count below 50 VALU per superblock refutes the operation-count account | 91.50 | unmet, the account stands |
| E1: the estimate it replaces | 77 estimated, 91.50 measured, 18.8% higher | the estimate undercounted |
| E1: Q4_K's normalized VALU must exceed Q6_K's for the operation count to explain the streaming gap | 91.50 against 86.75, +5.5% | direction met, magnitude short |
| E3: address arithmetic below 10% of the superblock VALU makes E3 not worth a device window | 13.1% Q4_K, 14.1% Q6_K | unmet, the address half of E3 stands |
| E3: an SMEM count at or near zero with the scale and `dm` loads appearing as `buffer_load` makes SGPR hoisting a candidate | zero `s_buffer_load` of weight data in the body | met as registered, and the hoist closes anyway on the sixteen-lane superblock mapping |
| E1.5: two runs of one module producing different `nir_sha256` is a `harness_alarm` | `cc6c1b49...` and `ad837848...` on both runs | unmet, the lab is deterministic |

The Q4_K-against-Q6_K comparison is the deviation worth naming. The census
measured Q6_K streaming its bytes at about 17 GB/s against Q4_K's 12, a 42%
gap, and the operation-count model explains it only if Q4_K issues
proportionally more per superblock. It issues 5.5% more. The direction the
prediction registered survives and the size does not.

The load widths name where part of the remainder sits. Both bodies issue 24
VMEM instructions, and they carry different byte counts: Q4_K's 12
`buffer_load_dword`, 4 `buffer_load_dwordx2`, 4 `buffer_load_ushort`, and 4
`buffer_load_dwordx4` demand 152 bytes per lane per superblock, where Q6_K's 12
`buffer_load_dwordx2`, 4 `buffer_load_sbyte`, 4 `buffer_load_short_d16`, and 4
`buffer_load_dwordx4` demand 172. Bytes per VALU instruction are therefore
0.4153 for Q4_K and 0.4957 for Q6_K, a factor of 1.194 in Q6_K's favor against
the 1.417 the census measured. The instruction inventory accounts for 1.19 of
that 1.42 and leaves 1.19 unexplained, which is where Q6_K's twelve LDS
operations inside its body, its 512 bytes of scale cache, and per-dispatch ramp
remain the open candidates. This measurement does not separate them.

The dependency depth reads the same way for both. Q4_K's body carries a longest
dependent VALU chain of 29 against 365 VALU in the block and Q6_K's 22 against
347, so the bodies are issue-bound rather than latency-bound and the instruction
count is the quantity a kernel change has to move.

## E1.5, the final NIR of the executed Q4_K module

`nir/mul_mat_vec_q4_k_f32_f32-final.nir` is the shader as
`radv_postprocess_nir` left it, printed immediately before
`radv_shader_nir_to_asm`. Two runs of the module produce
`nir_sha256 cc6c1b49c6491836121adb3184a3d050b1d0f3a0ba375df2d6ccb036e4eebbda`
and `isa_sha256 ad837848d58d6167f3638a9d2bbbbe276f37b4cd282559f77ef42c7d03af2f61`,
so the harness is deterministic and every receipt diff below is readable.

NIR does not hoist the activation group sums. Whole-module float opcode counts:

| opcode | control final NIR | E4 final NIR |
| --- | ---: | ---: |
| `fmul` | 310 | 214 |
| `fadd` | 264 | 192 |
| `ffma` | 0 | 0 |
| `u2f32` | 198 | 198 |
| `iadd` | 150 | 150 |
| `iand` | 63 | 63 |

The two forms stay apart: 96 multiplies and 72 adds separate them at the NIR
`radv_postprocess_nir` produced, which is the layer that would have to
canonicalize them for the `nir_canonicalized` verdict. `ffma` is absent from
both because ACO fuses the multiply and the add at instruction selection, which
is where the 128 `v_mac_f32` and `v_mad_f32` of the superblock body come from.
The redundant sixteen-term expansion of the minimum term therefore survives
every layer between GLSL and the instruction stream: 16 fused multiply-adds per
row per superblock in the source, 128 across four rows in the SPIR-V, 128 in the
ISA.

The NIR of the executed module and the NIR of the appliance-compiled control
differ (`cc6c1b49...` against `7ace068a...`, 1902 lines against 1901), which is
the float-controls and decoration difference between the two compilers. ACO
emits one instruction stream from both.

## E4, rung 4 of the acceptance ladder

Two pairs were run. The first is the reduction variant the appliance executes,
compiled on the appliance from the pinned source and from the same source with
`patches/llama-vulkan-q4k-activation-group-sums.patch` applied; its control is
the module whose ISA equals the served kernel's byte for byte, so the diff is
against the instruction stream the device fetches. The second is the pair
`e4/spirv-comparison.md` registers, `control.spv ab0d087f...` and
`e4.spv 7b425720...`, both digests reproduced before the run.

| field | control (executed variant) | E4 | delta | control (registered pair) | E4 | delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| VGPRs | 64 | 64 | 0 | 64 | 64 | 0 |
| SGPRs | 48 | 48 | 0 | 48 | 48 | 0 |
| spilled VGPRs | 0 | 0 | 0 | 0 | 0 | 0 |
| spilled SGPRs | 0 | 0 | 0 | 0 | 0 | 0 |
| LDS | 0 | 0 | 0 | 1024 | 1024 | 0 |
| scratch | 0 | 0 | 0 | 0 | 0 | 0 |
| Subgroups per SIMD | 4 | 4 | 0 | 4 | 4 | 0 |
| code size | 6764 | 6480 | -284 | 7808 | 7536 | -272 |
| VALU | 882 | 810 | -72 | 890 | 818 | -72 |
| SALU | 414 | 414 | 0 | 411 | 412 | +1 |
| VMEM | 56 | 56 | 0 | 56 | 56 | 0 |
| SMEM | 37 | 38 | +1 | 37 | 38 | +1 |
| LDS instructions | 0 | 0 | 0 | 134 | 134 | 0 |
| `s_waitcnt` | 82 | 84 | +2 | 136 | 138 | +2 |
| `v_mac_f32` | 248 | 152 | -96 | 248 | 152 | -96 |
| `v_cvt_f32_ubyte` | 192 | 192 | 0 | 192 | 192 | 0 |
| `v_and_b32` | 54 | 54 | 0 | 54 | 54 | 0 |
| `v_lshrrev_b32` | 32 | 32 | 0 | 32 | 32 | 0 |

Inside the superblock loop body, where the saving is spent:

| category | control | E4 | delta |
| --- | ---: | ---: | ---: |
| dot arithmetic | 152 | 116 | -36, -23.7% |
| unpack and convert | 165 | 165 | 0 |
| address arithmetic | 48 | 48 | 0 |
| lane mask | 1 | 1 | 0 |
| VALU total | 366 | 330 | -36, -9.8% |
| VMEM | 24 | 24 | 0 |
| `longest_valu_chain` | 29 | 17 | -12 |

`spirv-comparison.md` predicted from the frozen SPIR-V that 152 float operations
per lane per superblock become 116, a fall of 36. The device removes exactly 36,
all of them float, and touches nothing else: the same 24 memory instructions,
the same 165 unpack instructions, the same 48 address instructions, the same
allocation. The 96 `v_mac_f32` the whole shader loses are that 36 counted at
both call sites and across the row bodies.

```text
verdict          isa_changed
first_divergence spirv
last_divergence  isa
harness_alarm    -
```

Both pairs report the same verdict. The three verdicts that would have closed
E4 are unmet: the SPIR-V differs, so not `spirv_unchanged`; the final NIR
differs, so not `nir_canonicalized`; the ISA differs, so not `isa_identical`.

The two refutations that would have erased the saving are unmet as well. VGPR
allocation is flat at 64 with no spill and no scratch, which `receipt-diff.sh`
reports directly. Occupancy is read from `stats/*-shaderstats.txt` rather than
from the diff, at `Subgroups per SIMD: 4` on both arms of both pairs, because
`receipt-diff.sh` prints `waves_per_simd - - -` on this driver for the field
selector reason above and its occupancy row is blind here. A reader taking
`isa_changed` as a complete rung-4 pass needs that second file, and the
occupancy half of the refutation is checked and unmet with it. E4 survives rung 4, and the served exact-output ABBA
is the next rung.

One caution the numbers carry. The removed instructions are 4.1% of the shader's
VALU count and 9.8% of the superblock body's, while a repeated depth-0 rate on
this machine carries about 4% of uncontrolled spread and up to 30.6% between
sweeps. The served arm has to be read inside one sweep against a same-session
control, which is what `remote/measure-draft-pair.sh` already does for a pairing
and what the E4 arm needs too.

## The exact commands

Every path is written with `$HOME`; the appliance is `qwen-laptop` and the
workstation is where the E4 SPIR-V pair of `spirv-comparison.md` is reproduced.

The served dump, already retained, came from one instrumented request:

```sh
# on qwen-laptop, in a teardown window
GGML_VK_PIPELINE_CENSUS_DUMP=$HOME/raven2-e1-isa-20260902T1312Z-modules \
RADV_DEBUG=shaders,shaderstats \
    ... llama-server, one 8-token request at temperature 0 ...
python3 $HOME/qwen-laptop-setup/remote/summarize-radv-isa.py \
    $HOME/raven2-e1-isa-20260902T1312Z/radv-shaders.log \
    $HOME/raven2-e1-isa-20260902T1312Z/isa-split \
    $HOME/raven2-e1-isa-20260902T1312Z/isa-index.tsv
```

The E4 pair in the reduction variant the appliance executes, compiled on the
appliance with its own glslc from the pinned tree and from the patched
`mul_mat_vec_q4_k.comp`:

```sh
# on qwen-laptop
SHADERS=$HOME/src/llama.cpp-alias/ggml/src/ggml-vulkan/vulkan-shaders
DEFS="-DDATA_A_Q4_K=1 -DFLOAT_TYPE=float -DFLOAT_TYPEV2=vec2 \
      -DB_TYPE=float -DB_TYPEV2=vec2 -DB_TYPEV4=vec4 -DD_TYPE=float \
      -DUSE_SUBGROUP_ADD_NO_SHMEM=1"
glslc -fshader-stage=compute --target-env=vulkan1.2 -I "$SHADERS" \
    "$SHADERS/mul_mat_vec_q4_k.comp" -o $HOME/e1-lab/control-nsh.spv -O $DEFS
glslc -fshader-stage=compute --target-env=vulkan1.2 -I "$SHADERS" \
    $HOME/e1-lab/e4-src.comp        -o $HOME/e1-lab/e4-nsh.spv      -O $DEFS
```

The registered pair reproduces on the workstation with the command
`e4/spirv-comparison.md` records, glslc 2026.3 from the 1.4.357.0 SDK, and both
digests were confirmed before the run.

The seven lab runs, each at nice 19 beside the serving appliance:

```sh
# on qwen-laptop
LAB=$HOME/qwen-laptop-setup/remote/raven2-shader-lab
MODULES=$HOME/raven2-e1-isa-20260902T1312Z-modules
CONST="--spec 0:64 --spec 1:4 --spec 2:1 --subgroup 64 \
       --bindings 5 --push-constants 52 --per-superblock 256"

nice -n 19 "$LAB/lab.sh" \
    $MODULES/a9ac07dd4063e0903662cd5f1be68a5c2fbf06b0de924acd223525c7e4519d0d.spv \
    $HOME/e1-lab/q4k-exec $CONST
nice -n 19 "$LAB/lab.sh" \
    $MODULES/a9ac07dd4063e0903662cd5f1be68a5c2fbf06b0de924acd223525c7e4519d0d.spv \
    $HOME/e1-lab/q4k-exec-rerun $CONST
nice -n 19 "$LAB/lab.sh" \
    $MODULES/d584d6b41c26085ac1bef3236b4c24e71f0e98ddcf63ff12da46381b0c12c779.spv \
    $HOME/e1-lab/q6k-exec $CONST
nice -n 19 "$LAB/lab.sh" $HOME/e1-lab/control-nsh.spv $HOME/e1-lab/e4-control-nsh   $CONST
nice -n 19 "$LAB/lab.sh" $HOME/e1-lab/e4-nsh.spv      $HOME/e1-lab/e4-candidate-nsh $CONST
nice -n 19 "$LAB/lab.sh" $HOME/e1-lab/control.spv     $HOME/e1-lab/e4-control-shmem   $CONST
nice -n 19 "$LAB/lab.sh" $HOME/e1-lab/e4.spv          $HOME/e1-lab/e4-candidate-shmem $CONST

for arm in q4k-exec q4k-exec-rerun q6k-exec e4-control-nsh e4-candidate-nsh \
           e4-control-shmem e4-candidate-shmem; do
    nice -n 19 python3 "$LAB/depth.py" \
        $HOME/e1-lab/$arm/isa.s $HOME/e1-lab/$arm/depth.tsv
done

"$LAB/receipt-diff.sh" $HOME/e1-lab/e4-control-nsh   $HOME/e1-lab/e4-candidate-nsh
"$LAB/receipt-diff.sh" $HOME/e1-lab/e4-control-shmem $HOME/e1-lab/e4-candidate-shmem
```

The category split, run over the retained disassembly:

```sh
E1=evidence/raven2-vulkan-kernel-census/e1
python3 $E1/classify-superblock-valu.py $E1/isa/mul_mat_vec_q4_k_f32_f32.s 102 537 \
    mul_mat_vec_q4_k_f32_f32
python3 $E1/classify-superblock-valu.py $E1/isa/mul_mat_vec_q6_k_f32_f32.s 106 541 \
    mul_mat_vec_q6_k_f32_f32
python3 $E1/classify-superblock-valu.py $E1/isa/e4-control-subgroup-no-shmem.s 101 536 \
    e4-control
python3 $E1/classify-superblock-valu.py $E1/isa/e4-candidate-subgroup-no-shmem.s 101 501 \
    e4-candidate
```

The line ranges name the loop body in each file. The two served files carry the
`Compute Shader` stage-name line the split retains, so their ranges sit one line
below the lab's own.

## What the next rung reads

The served E4 arm compares 366 VALU per superblock against 330 on the 2B first,
the 0.8B second, and the 4B third, inside one sweep against a same-session
control, under the runtime-class order `CLAUDE.md` registers. E2 and E2b read
the same lab over the integer probes, and this inventory is their denominator:
the 128 fused multiply-adds and 96 byte conversions per Q4_K superblock are what
an integer kernel replaces, and the 48 address instructions are what it keeps.
