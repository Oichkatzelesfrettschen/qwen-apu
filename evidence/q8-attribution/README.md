# Q8-specific Stage A attribution: the workstation half

The served 0.8B is Q8_0 at 98.44% of its bytes and decodes at about 19 tok/s
where the class target is above 20 (`CLAUDE.md`). Its class already showed a
fixed-cost regime the 2B and 4B classes do not share:
`evidence/model-admission/runtime-class-throughput.md` measures three 0.8B
checkpoints at 15.96, 15.17, and 15.31 tok/s across streamed bytes spanning
0.477 to 0.801 GB per token, a 5.2% rate spread over a 67.9% byte spread. This
directory carries the workstation-side half of a Q8_0-specific version of the
Stage A pipeline census: the tensor and pipeline-selection facts a source
read settles without a device, the SPIR-V-layer half of a shader receipt a
host with no gfx902 part can still produce, a fixed-cost decomposition design
with its falsifiers registered ahead of any run, and the exact commands that
close every open half on the appliance.

| file | what it answers |
| --- | --- |
| `served-0.8b-q8_0-census.txt` | the full `remote/gguf-tensor-census.py` report against the served file |
| `tensor-census.md` | the byte share and tensor count by type, and why every weight byte takes the FP16-dequantize-then-dot path |
| `pipeline-selection.md` | which shader source and which of the two Q8_0 mat-vec pipelines `ggml-vulkan.cpp` builds, and the dispatch geometry this device selects for it |
| `shape-and-receipts.md` | the SPIR-V-layer facts this host closes, the comparison table against the retained Q4_K receipt with the device-only fields marked pending, and the per-superblock normalization trap between `QUANT_K=32` and `QUANT_K=256` |
| `fixed-cost-decomposition.md` | the mechanism account for the 0.8B's flat-rate-across-bytes signature, the census fields that read it, and five falsifiable predictions registered before the attribution arm runs |
| `device-commands.md` | the exact laptop-side command sequence that reproduces the SPIR-V, compiles it through ACO, fills the comparison table, and runs the attribution arm |
| `split-q8-mat-vec-shapes.py` | the Q8_0 mat-vec family re-keyed by tensor shape, over one accepted I1 arm's raw census record |
| `device-20260905/shape-selection.md` | the thirteen shapes with their exclusive times, the arm-to-arm agreement, and the shape the first Q8 experiment aims at |
| `q8-kernel-delta-design.md` | the registered row-count mechanism on that shape, its shader-lab falsifier, its bracket falsifier, and the planning figure |
| `spirv/` | the two compiled Q8_0 mat-vec SPIR-V modules (`SHMEM` and `SUBGROUP` reduction), their disassembly, their `--spirv-only` receipts, and a manifest of their digests |

## What is settled here and what is not

Settled by source and by a workstation-side compile, without a device:

- The served checkpoint carries 195 Q8_0 tensors and 140 F32 tensors, no
  Q4_K/Q5_K/Q6_K/IQ row.
- Every Q8_0 weight takes the FP16-dequantize path (`device->integer_dot_product`
  reads `false`; no `_q8_1` pipeline is built for any type).
- The Q8_0 mat-vec compiles from the shared `mul_mat_vec.comp` with
  `-DDATA_A_Q8_0=1`, not a dedicated `mul_mat_vec_q8_0.comp` -- there is none.
- This device's own dispatch geometry for Q8_0 is `{BLOCK_SIZE=64,
  NUM_ROWS=2, NUM_COLS=1}`, `SHADER_REDUCTION_MODE_SUBGROUP` at decode,
  which is *not* the K-quant family's `NUM_ROWS=4`.
- The compiled SPIR-V's capability list matches the six named entries in the
  retained Q4_K/Q6_K receipts' (two further, unnamed entries in those
  receipts track the toolchain that built them, not the shader source --
  `pipeline-selection.md`), which licenses reading the `USE_SUBGROUP_ADD=1`
  variant as the one this device would select.

Open, and requiring the appliance:

- Every register-allocation and instruction-count field in the comparison
  table (VALU, SALU, VMEM, VGPR, SGPR, waves per SIMD, longest VALU chain,
  waitcnt count) -- these come out of RADV's ACO backend targeting gfx902,
  which this workstation's NVIDIA Vulkan device cannot produce.
- Whether the served 0.8B's decode graph dispatches the `_f32_f32` or
  `_f16_f32` Q8_0 pipeline -- no I1 census has run against a Q8_0-bearing
  model.
- The five falsifiable predictions in `fixed-cost-decomposition.md`, which
  need the attribution arm's census ledger.

`device-commands.md` is written so an operator on the laptop can run each
open item without re-deriving what shape, what constants, or what macro to
compile with -- every command names the exact value this document already
justified.
