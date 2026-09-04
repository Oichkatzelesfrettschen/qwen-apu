# E5-S1: the same SPIR-V through an isolated RADV carrying the six-operation ACO lowering

E5-S1 sends E5-S0's module -- byte-identical, `spirv_sha256 2659f04ce6...`,
36940 bytes -- to a driver whose ACO knows this part has no dot instruction.
Mesa merge request 2115 (`70949d3d4846e809f38549eac6e2f942300de0ad`, merged as
`f1078c57e5f02b611f2c69af9ac7e0f5aa82a0bb`) sets `has_accelerated_dot_product`
false for Raven, Raven2, Vega10, and Renoir, keeps `nir_op_sdot_4x8_iadd` alive
for ACO on exactly that condition, and lowers it in `emit_soft_idot_4x8` to four
byte-extract-folded 24-bit multiplies feeding two `v_add3_u32` reductions: six
arithmetic instructions against the seven the generic `nir_opt_algebraic`
expansion produces from the same four multiplies.

`aco-lowering-provenance.md` beside this file is the branch account that built
both drivers and states the meson invocation, the `-Dllvm=enabled` requirement
the disassembler imposes, and the commit range. Nothing in this lane adds Mesa
source.

## The isolation

One SPIR-V module, two builds one pull request apart, nothing else moved.
`../E5-S0/isa-pre-2115/` is `a9a5f48212bfd9c4d73be36f2d90648d1bc04c91` and
`isa-post-2115/` is `9ae8ce550453b9e19f14dc1c9a41b913a9005e48`, three merges
past the change, built with the identical meson invocation.

`mnemonic-comparison.tsv` is the full instruction histogram of both, column
joined. Three rows move and every other row agrees:

| mnemonic | pre-2115 | post-2115 | delta |
| --- | ---: | ---: | ---: |
| `v_add_u32_e32` | 160 | 90 | -70 |
| `v_add3_u32` | 98 | 140 | +42 |
| `v_mov_b32_e32` | 20 | 17 | -3 |

Net -31 instructions, which is exactly the `valu` and `instruction_lines` delta
in both receipts (1328 to 1297, 1726 to 1695). No multiply changed, no VMEM or
SMEM instruction moved, and VGPR and SGPR occupancy are identical at 36 and 48.
`code_size` rose 44 bytes despite the shorter count, because `v_add3_u32` is
VOP3 at 8 bytes where the `v_add_u32_e32` it displaces is VOP2 at 4: an
instruction-count win that is not a code-size win.

| receipt | valu | code_size | vgprs | blocks | longest_valu_chain | isa_sha256 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| E5-S1 | 1297 | 9540 | 36 | 54 | 24 | `b9f5b4e6e2...` |
| E5-S0 | 1328 | 9496 | 36 | 54 | 23 | `a4d5f70939...` |
| E5-M | 1646 | 11704 | 36 | 54 | 35 | `8896269f54...` |
| production FP16 | 882 | 6764 | 64 | 82 | 29 | `ad837848d5...` |

## The registered non-falsifier this rung carries

Fewer instructions is not less time, and this rung's own receipt says so.
`depth.py`'s longest dependent-VALU chain is 24 across E5-S1's 54 blocks against
23 across E5-S0's identical 54. Trading a `v_add_u32, v_add3_u32, v_add_u32`
tree, whose two outer adds start as soon as their own inputs are ready, for two
serially dependent `v_add3_u32` reductions removes one instruction from the
count and adds one to the longest path in at least one block. GFX9 issues one
wavefront instruction per SIMD every four clocks and hides latency across
resident waves, so whether that slot costs anything depends on occupancy and on
where the block sits relative to the kernel's memory waits.

The reframe makes this the shorter form and therefore the hypothesis, which
makes the caution heavier rather than lighter: a bracket that fails to shorten
while VALU falls 2.3% is the predicted consequence of that trade and refutes
nothing on its own. What refutes E5-S1 is the combined envelope in
`../README.md`, measured against the best E4-plus-scale-word-select candidate.

## Deployment: what an isolated driver means here

E5-S1 reaches a device through `VK_ICD_FILENAMES` and a library path naming the
build directory alone. `radeon_devenv_icd.x86_64.json` is a meson target whose
`library_path` points straight at that directory, so the arm needs no install
step, no package extraction, and no change to the system driver: the appliance's
own `vulkan-radeon` keeps serving every other workload while the arm runs.
`radv-low-priority-env.sh` reads `QWEN_RADV_ICD`, which is the one name that
selects it.

## Status

| stage | state | where |
| --- | --- | --- |
| merge request 2115 merged into the fork | confirmed | `f1078c57e5f`, `aco-lowering-provenance.md` |
| RADV built pre- and post-2115 from one tree | measured | workstation |
| target-aware lowering reached, mechanism | measured | `isa-post-2115/`, `mnemonic-comparison.tsv` |
| chain depth against E5-S0 | measured, +1 | `depth.tsv` in both directories |
| isolated ICD on the appliance | unrun | appliance |
| executed ACO ISA on the appliance | unrun | appliance, falsifier 1 in `../README.md` |
| combined envelope, correctness, served rate | unrun | appliance, behind that gate |
