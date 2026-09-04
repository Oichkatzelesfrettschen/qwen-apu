# The target-aware ACO lowering rung: how both drivers were built, and a correction to the manual arm

This is the branch account the E5-S1 receipts came from, retained where the path
that rests on it lives. Its four paths F0 through F3 are the lane's E5
production anchor, E5-S0, E5-S1, and E5-M in that order, and the directories it
names moved with the reframe: `isa-target-aware/f1-stock-pre-2115/` is
`../E5-S0/isa-pre-2115/`, `isa-target-aware/f2-target-aware-post-2115/` is
`isa-post-2115/` beside this file, `isa-target-aware/f3-manual-int24-unaffected/`
is `../E5-M/isa-across-2115/`, and `isa-target-aware/mnemonic-comparison.tsv` is
`mnemonic-comparison.tsv` beside this file. Every count and digest below is
unchanged by the move; `../README.md` carries the reframed hypothesis.

`evidence/raven2-vulkan-kernel-census/e5/isa-shimmed-raven2/` reads
`remote/raven2-shader-lab/lab.sh`'s ISA receipts against a device that
compiles for RAVEN2 without owning one -- RADV plus a drm-shim from the
user's Mesa fork, `mesa-26-gororoba`. That evidence names the fork in its
directory and its prose, and every one of its four arms' `driver_info`
line reads `Mesa 26.2.1-arch3.1`: the compiler that produced every prior
E5-int24 ISA receipt is Arch Linux's stock `vulkan-radeon` package. The
fork supplied the drm-shim binary that fakes the RAVEN2 device node and
nothing else -- no gororoba-built RADV or ACO reached any of those four
receipts. The question this branch answers is not "does the shim's Mesa
predate PR #2115" but the sharper one underneath it: the shim's Mesa was
never the fork's Mesa at all, so PR #2115 is not merged into a build that
was in play, and closing that gap means building the fork's own RADV for
the first time.

## PR #2115 is merged, and it is cheap to build

`mesa-26-gororoba` at `origin/main` carries
`70949d3d4846e809f38549eac6e2f942300de0ad` ("radv/aco: expand the signed
8-bit dot product where GFX9 lacks the instruction"), merged as
`f1078c57e5f02b611f2c69af9ac7e0f5aa82a0bb` (PR #2115,
2026-09-03T05:39:23-07:00). The commit's own account: `has_accelerated_dot_product`
is false for Raven, Raven2, Vega10, and Renoir, so `ac_nir` keeps
`nir_op_sdot_4x8_iadd` alive for ACO only on that condition, and
`aco_select_nir_alu.cpp`'s new `emit_soft_idot_4x8` lowers it to four
byte-extract-folded 24-bit multiplies (`v_mul_i32_i24`/`v_mul_u32_u24`)
feeding two `v_add3_u32` reductions -- six arithmetic instructions against
the seven a generic `nir_opt_algebraic` expansion produces from the same
four multiplies through an unbalanced `v_add_u32, v_add3_u32, v_add_u32`
chain. `git log --format='%H %ai %s' -1 <hash>` on the checkout at
`$HOME/workspaces/mesa/mesa-26-gororoba` is the citation; this branch adds
no Mesa source.

Building the RADV Vulkan driver alone -- `meson setup
-Dvulkan-drivers=amd -Dgallium-drivers= -Dplatforms= -Dglx=disabled
-Degl=disabled -Dgbm=disabled -Dllvm=enabled`, then `ninja
src/amd/vulkan/libvulkan_radeon.so src/amd/vulkan/radeon_devenv_icd.x86_64.json
src/amd/drm-shim/libamdgpu_noop_drm_shim.so` -- takes under a minute with
ccache warm on twelve cores. `radeon_devenv_icd` is a second custom target
CMakeLists.txt does not use that points `library_path` straight at the
build directory, so no install step or Arch package extraction is needed to
reach this ICD; `--target-env=vulkan1.2` and the SPIR-V module decide
everything about pipeline creation from there. `-Dllvm=enabled` is required
for a reason unrelated to ACO: `radv_shader.c`'s disassembler goes through
LLVM's disassembler component even though ACO does the compiling, so a
`-Dllvm=disabled` configuration (tried first, see below) makes RADV report
"Shader disassembly is not supported in the current configuration (LLVM not
available), falling back to print_program", which prints ACO's pre-RA IR in
a format `lab.sh`'s mnemonic counter cannot parse -- every counted field
reads zero and the receipt is silently worthless. `RADV_DEBUG=shaders` with
LLVM enabled reaches real disassembly, `v_mul_i32_i24_sdwa` and
`v_add3_u32` included.

## Four paths, one probe shader, three compilers

The subject is `mul_mat_vec_q4_k_q8_1_f32_subgroup_no_shmem`, the same
pipeline E5-int24's falsifier 1 reads. `spec 0:64,1:1,2:1`, subgroup 64,
5 bindings, 52 push-constant bytes -- the tuple `isa-shimmed-raven2/`
already registered.

```text
F0  FP dequantize            production arm, unaffected by any patch here
F1  stock OpSDot lowering    dotPacked4x8EXT -> OpSDot -> nir_opt_algebraic's
                             generic GFX9 expansion (pre-#2115 ACO)
F2  target-aware ACO         the same SPIR-V through post-#2115 ACO
F3  manual int24             llama-vulkan-q4k-int24-mmvq.patch's own GLSL,
                             no dotPacked4x8EXT, no OpSDot
```

| path | valu | code_size | vgprs | blocks | longest_valu_chain | isa_sha256 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| F0 production | 882 | 6764 | 64 | 82 | 29 | `ad837848d5...` (e1, appliance-matched) |
| F1 stock OpSDot | 1328 | 9496 | 36 | 54 | 23 | `a4d5f70939...` |
| F2 target-aware | 1297 | 9540 | 36 | 54 | 24 | `b9f5b4e6e2...` |
| F3 manual int24 | 1646 | 11704 | 36 | 54 | 35 | `8896269f54...` |

F0's row is `evidence/raven2-vulkan-kernel-census/e5/isa-shimmed-raven2/arms/production/`,
unchanged by this branch. F3's row is
`evidence/raven2-vulkan-kernel-census/e5/isa-shimmed-raven2/arms/int24/`
plus this branch's own reproduction, below. F1 and F2 are new:
`isa-target-aware/f1-stock-pre-2115/` and
`isa-target-aware/f2-target-aware-post-2115/`, each carrying `receipt.tsv`,
`isa.s`, `harness.txt`, `block-counts.txt`, `shaderstats.txt`, `stats.tsv`,
and `depth.tsv` -- the seven files `isa-shimmed-raven2/README.md` names as
the lab's retained set.

## The isolation: one SPIR-V module, two builds one commit apart

F1 and F2 read the identical SPIR-V module (`spirv_sha256
2659f04ce6...`, `spirv_bytes 36940`), generated once from
`~/src/llama.cpp` at the pinned production commit
(`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`) through the tree's own
`remote/prepare-llama-vulkan-source.sh`, then compiled by
`vulkan-shaders-gen` built with `GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT`
(CMake's own `GL_EXT_integer_dot_product` probe against the workstation's
glslc 2026.3 enables it; "Enabling dot glslc support" is the configure-time
receipt). F1 came first, against
`a9a5f48212bfd9c4d73be36f2d90648d1bc04c91` -- the merge commit immediately
before PR #2115 -- built with the identical meson invocation; its ISA hash,
`a4d5f70939...`, is byte-identical to `isa-shimmed-raven2/arms/extension/isa.s`'s
own retained `a4d5f709398a68f579b86f469d1226ca5dc2a9e9a3dfb7837be803299c35b595`,
so this branch's whole reproduction pipeline -- production tree, shader
compile, drm-shim, ICD json -- reaches the same answer Arch's package
reached independently. F2 is the same SPIR-V through
`9ae8ce550453b9e19f14dc1c9a41b913a9005e48` (origin/main, three merges past
#2115). One commit range, one SPIR-V module, two ISA receipts: nothing else
in the toolchain moved between F1 and F2.

`mnemonic-comparison.tsv` is the full instruction histogram of both files,
column-joined. Every one of its rows agrees between F1 and F2 except three:

| mnemonic | F1 stock | F2 target-aware | delta |
| --- | ---: | ---: | ---: |
| `v_add_u32_e32` | 160 | 90 | -70 |
| `v_add3_u32` | 98 | 140 | +42 |
| `v_mov_b32_e32` | 20 | 17 | -3 |

Net -31 instructions, which is exactly the `valu` and `instruction_lines`
delta in both receipts (1328 to 1297, 1726 to 1695). PR #2115 touches
nothing else this kernel executes: no multiply changed, no VMEM or SMEM
instruction moved, VGPR and SGPR occupancy are identical (36/48 both arms),
and `code_size` rose by 44 bytes despite fewer instructions because
`v_add3_u32` is a VOP3 encoding (8 bytes) where the `v_add_u32_e32` it
partly displaces is VOP2 (4 bytes) -- an instruction-count win that is not
a code-size win.

## F3 never reaches the changed code path

The manual int24 rewrite emits no `dotPacked4x8EXT` and no `OpSDot`; its
16 products are ordinary masked-byte GLSL multiplies that NIR folds to
`v_mul_u32_u24` through the general 24-bit-multiply optimization
`aco_select_nir_alu.cpp`'s existing `nir_op_imul` handling already applies,
never touching the `nir_op_sdot_4x8_iadd` case PR #2115 changes. Building
`llama-vulkan-q4k-int24-mmvq.patch`'s own SPIR-V and running it through both
the pre-#2115 and post-#2115 ICDs confirms it: both produce
`isa_sha256 8896269f54c86f1039a08740aaa1f1f3fdbef6080f8d9e7a1908ce84e2598f34`,
the exact value `isa-shimmed-raven2/README.md` names as the hash that
"closes the identity outright" against the appliance's own census-dumped
module. That identity question is still unrun on the appliance -- this is a
second, independently toolchained reproduction of the same predicted value,
not a device measurement -- but it is now reached by two mesa-26-gororoba
revisions a PR apart in addition to the original Arch-toolchain run, which
is the strongest static confirmation available without appliance time.

## Chain depth: the falsifier this rung exists to guard

Fewer instructions is not less time. `depth.py`'s longest dependent-VALU
chain across F1's 54 blocks is 23; across F2's identical 54 blocks it is
24. Trading a `v_add_u32, v_add3_u32, v_add_u32` tree (which lets two of
its three adds start once their own inputs are ready) for two serially
dependent `v_add3_u32` reductions removes one instruction from the count
and adds one to the longest path in at least one block. GFX9 issues one
wavefront instruction per SIMD every four clocks and hides latency across
resident waves, so whether that one-slot difference costs anything depends
on occupancy and on where this block sits relative to the kernel's memory
waits -- a question `depth.py`'s own documentation states outright and this
branch does not resolve.

The registered falsifier is unchanged by this rung and is what every
count and hash above serves rather than replaces: **int8 through software
dot costs about 1.375 VALU per MAC where FP16 dot2 with FP32 accumulation
through `v_mad_mix_f32` costs about 1.0, so the integer path must win on
bracket time, not on instruction count.** F2's 31-instruction, 2.3% VALU
reduction over F1 at an equal-or-longer critical path is a compiler-side
result about which lowering ACO chooses; it says nothing about whether
either q8_1 path beats F0's FP16 dequantize on the device, which is what
E5-int24's falsifiers 2 through 4 measure and this branch does not run.

## Extending `lab.sh`

`isa-shimmed-raven2/README.md` recorded the defect this branch fixes:
`count_instruction_classes()` counted `v_mul_lo_u32`, `v_mad_u32_u24`,
`v_mad_i32_i24`, and `v_mul_u32_u24` without counting `v_mul_i32_i24` or
`v_add3_u32`, so the "extension" arm's 224 signed multiplies and every
target-aware `v_add3_u32` read zero in every counted field of its own
receipt; only `isa-mnemonics.tsv`, read from `isa.s` directly by a
one-off script outside the lab, stated them. `remote/raven2-shader-lab/lab.sh`
now counts both mnemonics into `receipt.tsv` beside the fields it already
tracked, and every count in this document's table came from the receipt
rather than from a substitute script.
`remote/raven2-shader-lab/test-count-i24-add3.sh` is the test: a fixture
disasm block (`test-fixtures/replay-i24-add3/`) naming three
`v_mul_i32_i24_sdwa` products and two `v_add3_u32` reductions, replayed
through `lab.sh` without a device, checked against the exact counts the
fixture states, with `v_mul_u32_u24` and `v_mul_lo_u32` checked to stay at
the fixture's zero so the new fields land beside the working ones rather
than displacing them. `remote/raven2-shader-lab` reaches this branch from
`origin/lane/shader-e4` at `8306377` (`git checkout 8306377 -- remote/raven2-shader-lab`),
the exact revision `isa-shimmed-raven2/README.md` already cited as the tool
the original E5-int24 receipts ran through, so this branch's copy is the
same tool the retained evidence names rather than a later revision.

## Stage status

| stage | state | where |
| --- | --- | --- |
| PR #2115 merged into `mesa-26-gororoba` | confirmed | `f1078c57e5f`, 2026-09-03T05:39:23-07:00 |
| RADV built from the fork, pre- and post-#2115 | measured | this branch, workstation |
| F1 rung: stock lowering, same SPIR-V as the retained "extension" arm | measured, matches retained hash | `isa-target-aware/f1-stock-pre-2115/` |
| F2 rung: target-aware lowering | measured | `isa-target-aware/f2-target-aware-post-2115/` |
| F3 unaffected by the PR (mechanism and hash both) | measured | `isa-target-aware/` runs above, hash matches the pinned `8896269f...` |
| chain-depth comparison, F1 against F2 | measured | `depth.tsv` in each F1/F2 directory |
| `lab.sh` counts `v_mul_i32_i24` and `v_add3_u32` | fixed, tested | `remote/raven2-shader-lab/lab.sh`, `test-count-i24-add3.sh` |
| activation-quantization cost (E5-int24 falsifier 2, margin witness) | unrun | appliance |
| combined Q4_K bracket, F2 against F0/F1/F3 | unrun | appliance |
| margin holdout over a served pair carrying F2 | unrun | appliance |
| kernel-delta A/B, F2 against the untouched null pipeline | unrun | appliance |

## What remains for the appliance

Nothing in this branch changes what the appliance can build. The appliance's
glslc still rejects `GL_EXT_integer_dot_product`
(`evidence/web-admission-router-tools/build-raven2-vulkan-production.log:33`),
which is a shaderc-side gate on producing `OpSDot` SPIR-V in the first
place and is wholly independent of PR #2115 -- the fork's ACO change acts on
whatever SPIR-V a driver receives, downstream of the compiler that emitted
it, so it helps F1 and F2 equally and helps neither until the appliance
either gains an extension-capable glslc or is handed SPIR-V compiled
elsewhere. F3, the route the appliance can actually build today because it
never asks glslc for the extension, is confirmed unaffected by the PR by
both mechanism and hash. So the practical consequence of this rung for the
appliance is null in the near term: the serving decision between F0's FP16
path and F3's int24 path still rests on E5-int24's own unrun falsifiers 2
through 4, and F2 becomes relevant only if a later arm ships an
extension-capable SPIR-V toolchain for the appliance to consume.

Four items carry the falsifier from instruction counts to a served
decision, none of them reachable from the workstation:

```text
activation-quantization cost   the margin witness over q8_1 activations
                                (E5-int24 falsifier 2), unmeasured by any
                                ISA count above
combined Q4_K bracket          F2 (or F3) against F0 as an exclusive GPU
                                bracket, judged against the untouched
                                Q6_K null pipeline the way E5-int24's
                                falsifier 3 already specifies
margin holdout                 a served pair carrying whichever q8_1
                                path is chosen, read against the
                                registered margin contract
kernel-delta A/B                the served comparison under the
                                scoreboard tuple, E5-int24's falsifier 4,
                                which decides whether any of this reaches
                                the 2B's 5% promotion bound
```
