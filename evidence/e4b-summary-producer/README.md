# E4b-A, the activation summary producer: the ACO receipt refutes the registered ceiling

The consumer that reads precomputed activation group sums saves 13 of 810 VALU
instructions, 1.6%, and pays 2 additional vector-memory operations for them. That is the
finding, and it lands before any device arm runs: `evidence/raven2-vulkan-kernel-census/`
registered E4b at 2.6 to 5.2% of the Q4_K mat-vec body, and the shimmed RAVEN2 receipts
below put the consumer's whole arithmetic delta at a third of the bottom of that band. The
registered ceiling is refuted on the compile side. The sign of the served result stays
open, because the producer's 84 dispatches per 2B decode graph are unmeasured and the
retained bracket statistic resolves the difference either way.

`patches/llama-vulkan-q4k-activation-sideplane.patch`, SHA-256
`234a41deddbdf7b1e50d86de15ea21e90f16a175d536977431de0100499c442f`, carries the change and
takes a `candidate` row in `remote/llama-patch-series.tsv` after
`llama-vulkan-q4k-activation-group-sums.patch` (E4). Its `mul_mat_vec_q4_k.comp` preimage
is the E4 result at blob `48778a3e8`, so the two stack rather than compete, and E4's own
form survives verbatim as the `Q4K_SIDEPLANE`-clear branch. E4's `mul_mat_vec_q5_k.comp`
hoist is E4's alone under either selection.

`evidence/raven2-vulkan-kernel-census/e4/e4b-a-first-pass.md` carries the token identity
result, the poisoned-producer negative control, the reuse table, and the traffic table
from the workstation's own Vulkan device. This page carries the gfx902 ISA the appliance
would execute, and it answers two of that page's five open falsifiers.

## The anchor: this host's ACO reproduces the appliance's retained E4 receipt exactly

RADV compiles for whichever family its device reports, and
`src/amd/drm-shim/amdgpu_noop_drm_shim.c` supplies a RAVEN2 device from the recorded state
in `src/amd/common/amdgpu_devices.c`, so a host carrying no AMD part obtains gfx902 ISA.
The shimmed node executes no submission: every run here ends inside
`vkCreateComputePipelines` and no arm on this page measures time.

| field | appliance, `e1/receipts/e4-candidate-nsh-receipt.tsv` | this host, `receipts/e4-consumer/receipt.tsv` |
| --- | --- | --- |
| `isa_sha256` | `29454587...185a1d` | `29454587...185a1d` |
| VALU | 810 | 810 |
| `v_mac_f32` | 152 | 152 |
| VGPR / SGPR | 64 / 48 | 64 / 48 |
| code size | 6480 | 6480 |
| device | `AMD Radeon Graphics (RADV RAVEN2)` | `AMD Ryzen 5 5600X3D 6-Core Processor (RADV RAVEN2)` |
| driver | `Mesa 26.2.1+git2608201115.88947685514~n~mesarc0` | `Mesa 26.2.1-arch3.1` |

The two `spirv_sha256` values differ, because the appliance compiled the same GLSL with the
shaderc its distribution ships and this host compiled it with glslc 2026.3, and the two
`nir_sha256` values differ for the same reason. ACO emitted one instruction stream from
both. That identity is what licenses reading the E4b consumer and producer receipts on this
page as the instructions the appliance would fetch, and it is stronger than the anchor
`evidence/raven2-vulkan-kernel-census/e5/isa-shimmed-raven2/` established, which matched the
pinned pre-E4 control. A census ledger row therefore identifies these modules by
`isa_sha256`; a `spirv_executed_sha256` comparison against the values here would fail on
the compiler difference alone.

## The receipts

Every arm ran through `remote/raven2-shader-lab/lab.sh` on the shimmed node, at
`--subgroup 64` and with `robust_buffer_access` off, over the modules
`vulkan-shaders-gen` emitted from the prepared candidate tree, so they are the bytes a
build embeds, `-O` included. The two consumers are the `subgroup_no_shmem` reduction
variant this device executes, at the appliance's own `0:64 1:4 2:1`.

| field | E4 consumer | E4b consumer | producer |
| --- | ---: | ---: | ---: |
| module | `mul_mat_vec_q4_k_f32_f32_subgroup_no_shmem` | `mul_mat_vec_q4_k_sideplane_f32_f32_subgroup_no_shmem` | `mul_mat_vec_q4_k_prepass_f32` |
| `isa_sha256` | `29454587...185a1d` | `04430516...bd8149` | `15d40a41...9dcebd` |
| bindings | 5 | 6 | 2 |
| push constants, bytes | 52 | 52 | 12 |
| spec constants | `0:64,1:4,2:1` | `0:64,1:4,2:1` | none |
| VALU | 810 | 797 | 48 |
| `v_add_f32_e32` | 40 | 16 | 12 |
| `v_mac_f32` | 152 | 152 | 0 |
| SALU | 414 | 418 | 11 |
| VMEM | 56 | 58 | 5 |
| SMEM | 38 | 39 | 1 |
| LDS instructions | 0 | 0 | 0 |
| VGPR | 64 | 64 | 24 |
| SGPR | 48 | 48 | 32 |
| spilled VGPR / SGPR | 0 / 0 | 0 / 0 | 0 / 0 |
| LDS bytes | 0 | 0 | 0 |
| scratch | 0 | 0 | 0 |
| code size, bytes | 6480 | 6508 | 348 |
| longest VALU chain | 17 | 17 | 14 |
| basic blocks | 82 | 82 | 3 |

`receipts/receipt-diff-e4-e4b.tsv` is `receipt-diff.sh`'s own verdict over the consumer
pair: `isa_changed`, `first_divergence=spirv`, `last_divergence=isa`, `harness_alarm=-`.
`receipts/isa-mnemonics.tsv` carries the whole histogram of all three arms read from
`isa.s` directly, which is where the producer's arithmetic is legible: the lab counts
`v_mac_f32` and `v_fma_f32` among its named mechanisms and counts no plain `v_add_f32`, so
the producer reads as 48 VALU and zero named mechanisms in `receipt.tsv` alone.

`--per-superblock 256` normalizes the two consumers and the producer carries no divisor.
Its bindings, push-constant range, and dispatch geometry are all different, so the
consumer's divisor states nothing about it; its counts are raw, against an invocation
count of `K/256 x 16` per token column, which is 128 invocations in 2 workgroups at
K = 2048 and 384 in 6 at K = 6144.

## What the consumer's 13 instructions are

`v_add_f32_e32` falls 40 to 16, which is 24 instructions: the 12 adds E4 forms per column
per superblock, in each of the two inlined copies of `compute_outputs` that
`mul_mat_vec_q4_k.comp`'s `main` produces. Against that the sideplane's own address
arithmetic returns 11 instructions -- 2 `v_bfe`, 2 `v_lshrrev_b32`, 4 SALU, and the rest --
and its read adds 2 VMEM and 1 SMEM. The net is 13 VALU and 28 bytes of code.

**The four activation `vec4` loads are not saved, and the sideplane read is additive.**
`e4b-a-first-pass.md`'s operation table predicted the consumer dropping 3 of 4 `vec4`
loads; VMEM rises 56 to 58 instead. The row loop re-reads `by10`, `by132`, `by20`, and
`by232` for the weight dot at `sx` through `sw`, so those loads are required whatever the
minimum term does, ACO already shares them between the two uses, and removing the group-sum
loop removes no load. The GLSL operation count and the ISA disagree here, and the ISA is
the authority.

**Occupancy does not move.** VGPR holds at 64, SGPR at 48, LDS and scratch at zero, and the
longest dependent VALU chain at 17 in both consumers, so the arm changes no waves-per-SIMD
step in either direction. That closes `e4b-a-first-pass.md`'s second open falsifier.

The producer spends 12 of its 48 VALU on the sums and 36 on addresses and bounds, reads
4 `buffer_load_dwordx4`, and writes 1 `buffer_store_dwordx4`. Its whole body is one basic
block of 64 instructions at a longest chain of 14.

## The hypothesis, and what the numbers predict

**Hypothesis.** The activation group sums are a property of the token column, so
materializing them once per activation and reading them from every consumer costs less
than E4's per-workgroup recomputation, and the union of the producer's census row and the
Q4_K consumer's is shorter than E4's consumer row alone.

**The invalidation key** is the activation tensor, its buffer, its offset, K, the token
column count, and a graph epoch. The tensor rather than its address is the identity:
ggml's graph allocator hands one buffer offset to many tensors in turn, and an
address-keyed draft folded `attn_norm-1`, `final_output-1`, `attn_post_norm-1`, and
`attn_norm-3` onto one key at offset 0 and produced fluent nonsense from a greedy decode.
That key is the widest boundary that is valid: wider than one workgroup, which is E4;
narrower than a graph, because an epoch bump is what keeps a reused buffer offset from
reading last graph's sums.

**The column guard, and what it leaves untested.** `ggml_vk_q4_k_sideplane_max_columns()`
admits `ne11 * ne12 * ne13 <= 1` by default, which is the decode step's own shape and the
shape every retained sideplane measurement was made at, and
`GGML_VK_Q4K_SIDEPLANE_MAX_COLUMNS` raises it as far as `mul_mat_vec_max_cols`. The two
indexings agree over that whole range because `ggml-vulkan.cpp:11326` admits the mat-vec
path at `ne11 > 1` only where `src1->ne[2] * src1->ne[3] == 1`, so exactly one of the two
factors exceeds 1: `get_offsets` sets `b_offset = batch_idx * p.batch_stride_b` and the
consumer adds `j * p.batch_stride_b`, and one of `batch_idx` and `j` is zero, which is the
producer's own `column`. `GGML_ASSERT(stride_batch_y == (uint32_t)ne10)` is what ends a
submission that violates the relation. No arm has run above one column, so the override is
the arm that measures the wider envelope rather than a setting with a result behind it.

**The conversion this lane can make.** E4 moved VALU 882 to 810, -8.16%, and the retained
kernel-delta run `evidence/raven2-vulkan-kernel-census/e4/kernel-delta-20260902T2312Z/`,
which reaches this repository through `origin/lane/retained-evidence` rather than this
lane, measured its `mul_mat_vec_q4_k_f32_f32` exclusive bracket at -3.93% over 4 of 4 pairs
at sd 0.0002. That is one observation of the transfer from VALU delta to bracket delta on this
shader, device, and tuple, 0.48, and it is a single point rather than a law. Applied to the
consumer's -1.61% it gives a point estimate of about -0.8% on the consumer's own bracket,
with no band, because one point supports none. The milliseconds behind that percentage
come from the arm's own control row rather than from this page: the prediction is stated as
a fraction and the run supplies its denominator.

**The budget that decides the sign.** A 2B decode graph runs 84 pre-passes against 162
consumer dispatches, and each miss costs one dispatch between two full memory barriers, so
the producer adds 84 dispatches and 168 barriers against the consumer's predicted 0.8%.
The census measured 206 microseconds median per Q4_K mat-vec call and 1.83 ms of queue idle
across the graph's 40 submits, so a pre-pass costing anything like a mat-vec dispatch
erases the arm several times over. 36 of the 84 pre-passes serve a single consumer and buy
nothing, so a forward walk that declines them is the first remedy if the dispatch cost is
what refutes the arm.

## The arm order

The judgement is `T_summary + T_Q4K` against E4's `T_Q4K`, never `T_Q4K` alone. The census
attributes by pipeline and the producer is a new pipeline, so its row lands outside the
Q4_K family's exclusive bracket and a comparison that omits it reports a saving the token
will not show.

```sh
QWEN_CENSUS_AB_MODE=kernel-delta \
QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual QWEN_CENSUS_SCLK_LEVEL=2 \
QWEN_CENSUS_MCLK_FLOOR_MHZ=933 \
    remote/run-served-binary-ab.sh CONTROL CANDIDATE qwen38-2b-distill OUT
```

`CONTROL` is a census build of the candidate stack through
`llama-vulkan-q4k-activation-group-sums.patch`; `CANDIDATE` is the same stack with
`llama-vulkan-q4k-activation-sideplane.patch` on top and `GGML_VK_Q4K_SIDEPLANE=1` in the
served environment. Arms run W C K K C at `QWEN_CENSUS_REPLICATES` pairs, under the
`manual-gfx1100-fclk933` operating point the DPM authority settled: GFX 1100 delivered read
from hwmon `freq1_input`, FCLK level 2 written with 933 as the floor, 1067 uncommandable.
The candidate binary serves the control arm with the flag clear, so both arms are one
executable and the control is E4 bit for bit.

Order across classes follows the benchmark policy: the 2B distill first, the 0.8B second,
the 4B third, and a result becomes a Raven2-wide default only where the classes agree.

Correctness runs beside it. `QWEN_WITNESS_CONTRACT=margin` over
`remote/witness-prompts/holdout-12.tsv` reads token identity and the margin contract's
top-10 retention, and the identity line is registered at margins at or above 0.1 nat, since
the 1e-3 logprob bound was retired as refuted with no replacement figure.

## Falsifiers

- **The envelope.** The union of the producer's exclusive bracket and the Q4_K consumer's,
  against E4's Q4_K consumer bracket alone, at a margin of 0.5%. The retained bracket
  statistic carries sd 0.0002 over 4 pairs, so 0.5% is resolvable and the predicted -0.8%
  clears it; a union at or above E4's refutes the arm as implemented, and a union between
  -0.5% and 0 leaves it unresolved rather than accepted. Served tok/s is a secondary read
  and carries no falsifier: its paired sd is 4.3% under pinned clocks, which cannot
  resolve 0.8%.
- **Token identity.** The 2B distill's generated ids under the flag must equal the control's
  over the witness run. The producer stores the same four left-associated chains the
  consumer would have built in registers, so the arm predicts bit-for-bit equality rather
  than a tolerance, and any id difference refutes the layout relation rather than measuring
  a reassociation.
- **The margin witness.** `summarize-margin-witness.py` must hold the registered retention
  over `holdout-12.tsv` at margins at or above 0.1 nat. A retention below the contract with
  ids held is a finding about the contract; ids moved is the falsifier above.
- **The Q6_K null.** `mul_mat_vec_q6_k_f32_f32`'s bracket must hold across the pair. The
  patch names no Q6_K source and the feature declines on every non-Q4_K mat-vec, so a moved
  Q6_K row reports machine state rather than the arm, and the campaign reads the Q4_K
  delta only where the null holds.
- **The pre-pass dispatch cost.** Unmeasured, and the term that decides the sign. A cost
  above about 4.8 microseconds per pre-pass including its two barriers consumes the whole
  predicted consumer saving.
- **Whether declining the single-consumer pre-passes recovers time.** That 36 of 84
  pre-passes serve one consumer is measured rather than open; what the device decides is
  whether removing those dispatches moves the union, which sets whether the forward
  consumer walk is worth writing.

## Reproducing the receipts

The RADV ICD comes from the `vulkan-radeon` package matching the installed Mesa, extracted
to a scratch directory with its `library_path` rewritten to the extracted object, so
`VK_DRIVER_FILES` selects it per process and the host's own ICD directory is untouched. The
drm-shim is `libamdgpu_noop_drm_shim.so` from a Mesa build of the same release; the shim and
the ICD come from one release, since `ac_gpu_info.c` refuses an amdgpu node below DRM
3.54.0 and a 25.x shim reports 3.49.0. `radv-raven2-shim-env.sh` beside this file is the
wrapper, taken from `origin/e5-int24-shader` at `f39b893`.

```sh
# The prepared candidate tree, E4 then this patch.
remote/prepare-llama-census-source.sh BASE PATCHED \
    llama-server-vulkan-workload-lease.patch llama-vulkan-pipeline-census.patch \
    llama-vulkan-q4k-activation-group-sums.patch \
    llama-vulkan-q4k-activation-sideplane.patch

# The three modules, as a build embeds them.
g++ -O2 -std=c++17 -o vsgen \
    PATCHED/ggml/src/ggml-vulkan/vulkan-shaders/vulkan-shaders-gen.cpp -lpthread
vsgen --glslc /usr/bin/glslc --output-dir SPV --target-hpp SPV/gen.hpp \
    --target-cpp SPV/gen.cpp \
    --source PATCHED/ggml/src/ggml-vulkan/vulkan-shaders/mul_mat_vec_q4_k.comp
vsgen --glslc /usr/bin/glslc --output-dir SPV --target-hpp SPV/gen2.hpp \
    --target-cpp SPV/gen2.cpp \
    --source PATCHED/ggml/src/ggml-vulkan/vulkan-shaders/mul_mat_vec_q4_k_prepass.comp

# One receipt per arm.
export QWEN_RADV_ICD=ICD_JSON QWEN_AMDGPU_DRM_SHIM=SHIM_SO
evidence/e4b-summary-producer/radv-raven2-shim-env.sh \
    remote/raven2-shader-lab/lab.sh \
    SPV/mul_mat_vec_q4_k_f32_f32_subgroup_no_shmem.spv OUT/e4-consumer \
    --spec 0:64 --spec 1:4 --spec 2:1 --subgroup 64 \
    --bindings 5 --push-constants 52 --per-superblock 256
evidence/e4b-summary-producer/radv-raven2-shim-env.sh \
    remote/raven2-shader-lab/lab.sh \
    SPV/mul_mat_vec_q4_k_sideplane_f32_f32_subgroup_no_shmem.spv OUT/e4b-consumer \
    --spec 0:64 --spec 1:4 --spec 2:1 --subgroup 64 \
    --bindings 6 --push-constants 52 --per-superblock 256
evidence/e4b-summary-producer/radv-raven2-shim-env.sh \
    remote/raven2-shader-lab/lab.sh \
    SPV/mul_mat_vec_q4_k_prepass_f32.spv OUT/producer \
    --subgroup 64 --bindings 2 --push-constants 12

python3 remote/raven2-shader-lab/depth.py OUT/ARM/isa.s OUT/ARM/depth.tsv
remote/raven2-shader-lab/receipt-diff.sh OUT/e4-consumer OUT/e4b-consumer
```

Each arm's `receipt.tsv` records `run_mode=device`, `device_name`, and `driver_name`, and a
reading is made against those three fields first: another driver compiles the same SPIR-V
with another compiler and answers a question about that compiler.

## What did not run

- **The device arms.** No arm on this page executed a submission; the shimmed node ends at
  pipeline creation. The served kernel-delta A/B, the witness, and the Q6_K null all need
  the appliance and a teardown window.
- **The producer's dispatch cost.** The one term that decides the sign, and it is a device
  measurement.
- **A build of the whole binary.** `ggml-vulkan.cpp` compiles clean under the candidate
  stack with this patch applied, at `-DGGML_BUILD_TYPE=Release -DGGML_VULKAN=ON
  -DGGML_NATIVE=OFF`, which is what closed the guard's own compilation. The census preset's
  full `build-llama-preset.sh` run and its manifest were not produced here, because the
  arm's build belongs to the appliance chain that measures it.
