# The Q8_0 mat-vec receipt at the served shape, and what it takes to close it

`remote/compile-q8-mat-vec-spv.sh` and
`remote/raven2-shader-lab/q8-mat-vec-receipt.sh` reproduce, on a host holding
no gfx902 device, everything the shader lab's SPIR-V layer proves: the exact
module `ggml-vulkan.cpp` hands `vkCreateShaderModule` for the Q8_0 mat-vec at
this device's served dispatch geometry, and that module's declared
capabilities and spec constants. Neither script reaches the NIR, ISA, or
register-allocation layers, because those come out of RADV's ACO backend
compiling for gfx902, and this workstation's one Vulkan device is an NVIDIA
part (`vulkaninfo --summary`, `vendorID = 0x10de`). Compiling the same
SPIR-V there would produce another vendor's instructions under a receipt
that looks like this tree's gfx902 ones; `q8-mat-vec-receipt.sh` defaults to
`lab.sh --spirv-only` for exactly that reason, and running it with
`--allow-device` is refused implicitly nowhere in code but is documented as
wrong everywhere in this file. Closing the comparison below needs the
appliance and is Section 4's job.

## What this host closes

`evidence/q8-attribution/spirv/manifest.tsv` and the two `.receipt-spirv-only.tsv`
files retain the run:

| field | `mul_mat_vec_q8_0_f32_f32` | `mul_mat_vec_q8_0_f32_f32_subgroup` |
| --- | --- | --- |
| spec constants | `0:64,1:2,2:1` | `0:64,1:2,2:1` |
| reduction macro | none (`SHMEM`) | `USE_SUBGROUP_ADD=1` (`SUBGROUP`, the mode this device dispatches at decode) |
| spirv_bytes | 22,828 | 22,972 |
| spirv_sha256 | `a52c7af0...3ebc5f` | `036a450c...c38818c` |
| OpCapability list | `Shader, Int8, GroupNonUniform, GroupNonUniformArithmetic, StorageBuffer16BitAccess, StorageBuffer8BitAccess` | same |

The capability list matches the six named entries in the retained Q4_K and
Q6_K receipts' `spirv_capabilities` field
(`evidence/raven2-vulkan-kernel-census/e1/receipts/q4k-exec-receipt.tsv`,
`q6k-exec-receipt.tsv`), which carries two further entries neither named --
`capability_4464`, `capability_4467`. A Q4_K module compiled fresh on this
workstation from the same pinned source carries only the six named
capabilities and neither unnamed one (`pipeline-selection.md`), so that gap
tracks the toolchain that produced the retained modules rather than the
shader source, and stays open rather than resolved here. The six-way match
is what licenses reading the `_subgroup`
variant as the one this device would select, rather than a label chosen for
convenience.

## The comparison row, retained columns filled and device columns pending

| field | Q4_K (`q4k-exec-receipt.tsv`, retained) | Q6_K (`q6k-exec-receipt.tsv`, retained) | Q8_0 `_subgroup` (this document) |
| --- | ---: | ---: | ---: |
| spec_constants | `64,4,1` | `64,4,1` | `64,2,1` |
| per_superblock_divisor | 256 | 256 | 32 (`QUANT_K`, not 256 -- see below) |
| vgprs | 64 | 64 | pending device run |
| sgprs | 48 | 48 | pending device run |
| spilled_vgprs / spilled_sgprs | 0 / 0 | 0 / 0 | pending device run |
| lds | 0 | 512 | pending device run |
| code_size | 6,764 | 13,420 | pending device run |
| waves_per_simd | - (not printed by this driver build) | - | pending device run |
| instruction_lines | 1,436 | 2,677 | pending device run |
| valu | 882 (3.4453/superblock) | 1,648 (6.4375/superblock) | pending device run |
| salu | 414 (1.6172/superblock) | 657 (2.5664/superblock) | pending device run |
| vmem | 56 (0.2188/superblock) | 130 (0.5078/superblock) | pending device run |
| smem | 37 (0.1445/superblock) | 54 (0.2109/superblock) | pending device run |
| lds_instructions | 0 | 50 (0.1953/superblock) | pending device run |
| waitcnt | 82 (0.3203/superblock) | 189 (0.7383/superblock) | pending device run |
| longest_valu_chain (depth.tsv, largest block) | 29 (block 6, 42, 43, 44) | not retained in this pass | pending device run |
| loop-body block count (depth.tsv rows) | 82 blocks | not retained in this pass | pending device run |

**The per-superblock normalization does not carry over unchanged.** Q4_K,
Q5_K, and Q6_K share `QUANT_K = 256`, the K-quant super-block size, and every
retained per-superblock figure above divides by 256. Q8_0's block is 32
weights (`QUANT_K = 32` from `dequant_funcs.glsl`'s `data_a` declaration,
confirmed against `remote/gguf-tensor-census.py`'s block-size table for type
`Q8_0`). `q8-mat-vec-receipt.sh` passes `--per-superblock 32`, and a reader
who instead divides a Q8_0 VALU count by 256 understates its per-block cost
eightfold. Comparing Q8_0 against the K-quant family on equal footing means
comparing *per streamed byte* or *per weight*, not per superblock: Q8_0's
block is one byte per weight plus a 2-byte scale (34 bytes / 32 weights =
1.0625 bytes/weight) against Q4_K's block at 144 bytes / 256
weights = 0.5625 bytes/weight (`remote/gguf-tensor-census.py`'s block-size
table: type 12, `(256, 144, "Q4_K")`), so a fair comparison of the two receipts below
divides each `per_superblock` figure by its own `QUANT_K` before comparing,
which the reader that closes this table on-device should compute alongside
the raw counts rather than read the two `per_superblock` columns against each
other directly.

## What the closed table would settle

Three readings this table is built to discriminate, once the device columns
are filled:

- **Issue-bound.** If `valu`/32 for Q8_0 sits well above `valu`/256 x (32/256)
  == `valu`/2048 scaled back to a common per-weight basis -- i.e. Q8_0 costs
  materially more than Q4_K per weight despite the trivial dequant above --
  the deficit is elsewhere: dispatch count, occupancy, or the reduction
  itself, not the unpack. `decode-decomposition.md`'s reading of the 0.8B
  format arm ("Q8_0 widens each weight in one conversion") predicts the
  opposite: Q8_0 should cost *fewer* VALU operations per weight than Q4_K,
  since it has no nibble split, no high-bit fold, and no packed
  scale-and-minimum decode to pay for.
- **VMEM-bound.** Q8_0's `dequantize4` reads two packed 16-bit loads per four
  weights against Q4_K's four-group nibble load; if `vmem`/weight is higher
  for Q8_0 despite streaming more bytes per weight (1.0625 against 0.5625),
  the block layout rather than the instruction count is what costs bandwidth
  efficiency, which is a different fix (loosen the block or widen the
  vector load) than an issue-bound finding is.
- **Occupancy-bound.** `vgprs` and `waves_per_simd` decide this leg. The
  retained Q4_K and Q6_K receipts both report 64 VGPRs and (per
  `decode-decomposition.md`'s P5 reading) 4 waves per SIMD, the ceiling this
  device's 10-waves-per-SIMD limit and 64 KiB LDS per CU do not further
  constrain at that VGPR count. A Q8_0 VGPR count materially above 64 would
  drop waves per SIMD below 4 and make occupancy, not issue or VMEM, the
  limit -- structurally plausible here because Q8_0's `NUM_ROWS` is 2 against
  Q4_K's 4, so each invocation carries fewer rows' worth of live
  accumulators but the same per-lane unpack registers, and the net register
  pressure is a device question rather than a source-reading one.

Section 4 states the exact commands that fill this table.
