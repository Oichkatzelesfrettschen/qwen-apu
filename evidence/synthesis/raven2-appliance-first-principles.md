# The Raven2 appliance from first principles, and the gaps the derivation exposes

This document derives the appliance from the silicon upward and records, at each
layer, what a primary authority documents, what a retained run measured, what
follows by inference, and what would refute the layer's claim. It ends with a
numbered lacunae table: every gap the derivation exposed, the probe that closes
it, the evidence class that probe produces, and the falsifier that would end it.

Evidence classes are this tree's own, from
`evidence/research-claim-methodology.md`, "Claim record", item 2: **measured**,
**derived**, **estimated**, **documented**, **untested**. A source-read
mechanism is documented; an arithmetic consequence of a measured value is
derived; a retained device run is measured; a registered design with no run is
untested.

Two sibling trees supply the primary silicon description and the claim-status
discipline. The Raven2 capability decomposition lives in
`$HOME/Projects/hp14-dk1xxx/hp14-raven2-gpu/docs/`, referenced below as
`hp14-raven2-gpu/docs/NAME`. Its scope note says the repository "makes no driver-code
change and no target configuration change", and routes runtime deployment and
benchmark evidence to this tree, so the two are complementary rather than
overlapping authorities.

Three source paths in this document sit outside `main`. The Stage A census and
the DPM authority runs live on the branch `stage-a-census-brackets`; each such
citation carries the branch name and is read with `git show`. Where a claim in
this document rests on a branch path, the lacunae table carries the merge as its
own row, because a synthesis that cites an unmerged branch states a fact whose
authority a clone cannot resolve.

---

## Layer 1: silicon

### What is documented

The part is Raven2, a first-generation Vega GFX9 graphics core, PCI
`1002:15D8` revision `0xCD`, HSA target `gfx902:xnack+`, in an AMD Athlon
Silver 3050U (`hp14-raven2-gpu/docs/raven2-capability-decomposition.md`,
"Identity"). Revision `0xCD` separates the die from Picasso, which shares the
PCI ID; Mesa routes revisions at or above `0xC8` to RAVEN2, and the VBIOS
string `113-RAVEN2-117` agrees from the board side independent of any driver.

The geometry is two active compute units inside three declared CU positions,
four SIMDs of sixteen lanes each, wavefront 64 fixed, ten waves per SIMD, 64 KiB
LDS per CU, 16 KiB L1 against 1 MiB L2, one shader engine and one shader array,
peak engine clock 1100 MHz (same document, "Geometry"). `amdgpu` reports
`SE 1, SH per SE 1, CU per SH 3, active_cu_number 2` from the GC configuration
path. The wave is 64 and cannot be varied; GFX9 has no wave32 mode, so shader
code tuned for a 32-wide subgroup runs correctly at half the occupancy per wave
until it is retuned ("Subgroups").

The instruction-encoding oracle is the assembler. `llvm-mc-19 -arch=amdgcn
-mcpu=<target>` accepts `v_pk_fma_f16`, `v_pk_add_i16`, `v_mad_mix_f32`, and
`v_fma_f64` for gfx902 and rejects `v_fma_mix_f32`, `v_dot2_f32_f16`,
`v_dot4_i32_i8`, `v_dot8_i32_i4`, `v_dot2_i32_i16`, `v_fmac_f32`, and every
probed `v_mfma_*` form; gfx906 alone among the five probed Vega targets accepts
the dot family ("Math types", "Instruction encoding, per target"). The probe is
finite and claims no exhaustive silicon-ISA inventory.

Every IEEE float control is selectable at every width: signed-zero/inf/NaN
preserve, denormal preserve, denormal flush-to-zero, round-to-nearest-even, and
round-toward-zero all read true for fp16, fp32, and fp64 ("Float controls").
A shader picks denormal handling and rounding per precision rather than
inheriting one policy, so an fp16 scale factor landing in the subnormal range
survives where flushing would lose it, and RTZ remains selectable where flushing
is the faster choice.

Two constraints bound any reduction written here. Global float atomic add is
false on this part while LDS float atomic add is true, and fp16 atomics are
false in both address spaces ("Atomics"), so a float reduction reduces within
the subgroup, then within the workgroup through LDS, and writes one result per
workgroup, with any fp16 accumulation widened to fp32 in LDS first.

### What was measured

Per-kernel VALU opcode counts from `clang-19 -O3 -S` over a seven-kernel
battery, gfx902 against gfx906 ("What the compiler emits"):

| kernel | gfx902 | gfx906 |
| --- | --- | --- |
| fp32 FMA | 33 VALU, `v_fma_f32` x8 | 33, `v_fmac_f32` x8 |
| scalar `half` FMA | 41 VALU, `v_fma_f16` x8 plus 8 `v_lshrrev_b32` | same |
| `half2` FMA | 33 VALU, `v_pk_fma_f16` x8 | same |
| fp16 in, fp32 accumulate | 49 VALU, 16 `v_cvt_f32_f16` plus 8 `v_fma_f32` | 33, `v_fma_mix_f32` x8 |
| int8 4-wide dot | 69 VALU, `v_mad_i32_i24` / `v_mul_i32_i24` | 69, identical |
| int16x2 widening MAD | 100 VALU, `v_mul_lo_u32` x16 | same |
| fp64 FMA | 34 VALU, `v_fma_f64` x8 | same |

Three consequences carry into every later layer. Packed FP16 is real and lives
in the packing: `half2` reaches `v_pk_fma_f16` at 33 VALU while scalar `half`
costs 41, worse than fp32's 33, because the compiled sample pays a shift to
extract the high half. Mixed fp16-in/fp32-accumulate costs 49 VALU against
gfx906's 33, sixteen extra `v_cvt_f32_f16` per eight FMAs, because gfx902 carries
only the older `v_mad_mix_f32` and LLVM did not select it -- and that pattern is
exactly what quantized inference runs most. Integer products want 24 bits:
`v_mad_i32_i24` is the full-rate multiplier while a widening 32-bit product falls
to `v_mul_lo_u32` at quarter rate, 100 VALU against 69, worth roughly 3x on the
measured battery.

The int8 row is explicitly not evidence of absent dot hardware: it produced
identical code on gfx906, so it shows only that LLVM does not idiom-match
`v_dot4_i32_i8` from scalar C. The assembler table is the authority for absence.

At the API layer, `VK_KHR_shader_integer_dot_product` is present with 0 of 30
`*Accelerated` bits true; `VK_KHR_cooperative_matrix` is absent on RADV RAVEN2;
`shaderFloat16` and `shaderInt8` are true; the Vulkan subgroup size is fixed at
64 ("API-level properties"). The toolchain adds an independent refusal: glslang
15.1.0 rejects the `GL_EXT_integer_dot_product` extension line outright and
shaderc 2023.8 parses it with no `dotEXT` builtin, so the integer dot product is
unavailable twice over, at the hardware and at the shader compiler
("SPIR-V numeric capabilities"). The two causes are independent, which is the
reason to record both: moving this work to a GPU that accelerates dot products
still yields unaccelerated shaders until the shader compiler is upgraded.

### Memory: what this tree measured, and the correction it forces

Both UMC channels report `0x00000520` at SMN register `0x50200`. Bits 7:0 encode
the DDR4 ratio as value/3 against a 200 MT/s multiplier, so `0x20` decodes to
`(32 / 3) x 200 = 2133.33 MT/s`; both channels also decode to 15-15-15-36, tRP
15, tRC 51, which is the fastest profile in both CRC-valid Crucial
CT16G4SFD8213 SPD EEPROMs (`evidence/measurement-state-and-memory-clock.md`,
"Memory is trained at DDR4-2133"; register dump in
`evidence/hp14-dk1xxx-memory-registers.log`). Theoretical dual-channel peak is
therefore `2 x 8 bytes x 2133.33 MT/s = 34.13 GB/s`, a derived figure over
measured registers. Host sequential read measures 7.97 GB/s on one thread and
15.44 GB/s on two, about 45% of that peak, which bounds the two Zen+ cores
through the load/store path and bounds nothing about the iGPU, whose route to
memory runs through the Data Fabric with its own limit.

This refutes a premise the sibling document builds on.
`hp14-raven2-gpu/docs/raven2-capability-decomposition.md`, "Memory", reads the
selected 933 MHz `pp_dpm_mclk` step as "DDR4-1866 effective" and derives a
128-bit theoretical ceiling of about 29.9 GB/s and a compute-to-bandwidth ratio
of 9.4 flops per byte; `hp14-raven2-gpu/docs/llamacpp-on-raven2.md`, "What to
expect, and why", carries that 29.9 GB/s into an idealized ceiling of about 7.5
tokens/s for a 4 GiB weight set. On this SMU10 platform `pp_dpm_mclk` is not the
DRAM clock: the kernel's `PP_MCLK` display path calls
`PPSMC_MSG_GetFclkFrequency`, so the 400/933/1067 MHz table is the data-fabric
ladder reported through a legacy memory-clock filename, and the UMC training
registers are the DRAM authority. Every figure downstream of 29.9 GB/s in the
sibling tree therefore rests on a refuted reading. The sibling's own frontier row
`raven2-memory-bandwidth` states its falsifier as "A paired retained measurement
under a named clock and workload supersedes it"
(`hp14-raven2-gpu/docs/repository-scope-and-frontier.md`,
"Maximal-decomposition frontier"), and this tree holds one, so the row should
reopen. `dmidecode` printing `Configured Memory Speed: 2400 MT/s` exceeds both
the SPD rating and the measured UMC rate, so SMBIOS is not an operating-clock
oracle on this firmware either.

### What is inferred

The FP32 FMA ceiling of 281.6 GFLOPS (128 lanes x 2 flops x 1.1 GHz), and 563.2
packed FP16, are computed from geometry rather than measured; the capability
document says so. Combining the corrected 34.13 GB/s peak with 281.6 GFLOPS
gives about 8.25 flops per byte as the theoretical balance, which is derived
arithmetic over one measured and one geometric input and is not a measured
device property.

### What would refute this layer

A retained `llvm-mc` acceptance of any `v_dot*` form for gfx902 refutes the
absence claim. A `vulkaninfo` capture on this device with any of the thirty
`*Accelerated` bits true refutes the API statement. A boot whose UMC `0x50200`
value or timing pair differs from the retained decode refutes the DDR4-2133
training claim. A measured GPU-side streaming rate above 34.13 GB/s refutes the
peak.

---

## Layer 2: firmware and power

### What the VBIOS establishes, and what it explicitly does not

The retained board VBIOS is a 54,272-byte AMD PCI option ROM with a valid image
checksum, PCI identity `1002:15d8`, ATOM signature, and entry target `0x205`;
the live target's debugfs VBIOS hashes identically
(`hp14-raven2-gpu/docs/vbios-decoder-report.md`, "Outcome"). The ROM header is
`atom_rom_header_v2_2` at `0x186`, and the two master lists it points to are
`atom_master_list_of_command_functions_v2_1` with 81 entries at `0x9380` and
`atom_master_list_of_data_tables_v2_1` with 35 entries at `0x9426`, of which 38
command tables and 16 data tables are present ("Atomfirmware table layer"). The
header struct and the master-list structs carry different version suffixes, so a
reader that names one version for the whole layer names the wrong one for half of
it. `pspdirtableoffset` is zero, so the image holds no PSP directory.

The PowerPlay body is empty: `powerplayinfo` revision 9.1 occupies 1,024 bytes
whose 1,020 body bytes are all zero, and `upp` 0.2.4 refuses the revision
outright (`hp14-raven2-gpu/docs/vbios-atomfirmware-anti-patterns.md`, "Editing
the VBIOS PowerPlay table to move APU clocks"). There is no recoverable power
state, clock table, or voltage curve in this image to edit.

The clock-programming surface is absent by census rather than by assumption: the
image contains zero `pll` and zero `mc` operands across 2,412 instructions,
alongside absent `setengineclock`, `setmemoryclock`, `umc_info`, and `vram_info`
entries (`vbios-decoder-report.md`, "ATOM instruction set decomposition"). The
anti-patterns document draws the operational consequence -- "Look for engine and
memory clock programming in the SMU firmware and the platform BIOS" -- and the
frontier table carries the row `atom-pll-and-mc-programming` at state `refuted`
with the falsifier "One pll or mc operand in a present table refutes the
finding".

The twelve `PROCESSDS` blocks are resolved as a mechanism and open as a
semantics. For all twelve, the payload base at block start plus three appears
among the immediates the table adds to `ATOM_WS_DATAPTR`, and the table reads
them through `id[]` after `SETDATABLOCK 0xff`, so they are data the table
addresses rather than unreached code ("ATOM instruction set decomposition"; the
frontier row `processds-data-block-semantics` reads `known`). What remains open
is the consumer: each block sits after its table's `EOT`, the retained ATOM graph
identifies no consumer, and an x86-region consumer and a driver consumer both
remain hypotheses requiring source cross-references ("Next bounded decompilation
frontier").

The frontier table itself holds 36 mechanism rows, not twelve --
17 `known`, 9 `open`, 4 `refuted`, 2 `source-mapped`, 2 `measured elsewhere`,
1 `observed`, 1 `hypothesized` (counted directly over
`repository-scope-and-frontier.md`, "Maximal-decomposition frontier"). Twelve is
the PROCESSDS block count, which appears in that table only inside the Authority
column of `atom-instruction-coverage` and `processds-data-block-semantics`.

### The connection this layer does not make

The VBIOS findings narrow clock authority toward the kernel and SMU path by
removing the board firmware from the candidate set. They do not connect to the
FCLK refusal measured below. None of the three sibling documents makes an
affirmative claim about who selects FCLK; they establish only that this option
ROM does not. The join is an inference at the level of "the authority is
elsewhere", and the elsewhere was measured separately.

### What this tree measured about SMU10 clock authority

The retained runs live under
`evidence/raven2-vulkan-kernel-census/dpm-authority/` on the branch
`stage-a-census-brackets`, with predictions registered ahead of them in
`evidence/raven2-vulkan-kernel-census/dpm-authority-design.md`.

Three rails are separate and the sysfs names hide it. `freq1_input` is GFXCLK,
the graphics engine clock read from hwmon. `pp_dpm_mclk` is FCLK, the data-fabric
clock, read with `PPSMC_MSG_GetFclkFrequency` and advertised here at 400, 933,
and 1067 MHz. The DRAM clock is a third rail neither surface reads, trained at
DDR4-2133.33 by the UMC registers of layer 1
(`dpm-authority/README.md`, "Naming correction: GFXCLK, FCLK, and DRAM clock are
three different rails").

Forced performance levels pin the graphics clock and drop the fabric.
`power_dpm_force_performance_level` set to `high` or `profile_peak` holds
`freq1_input` steady at 1100 MHz through the bench window and drops the starred
`pp_dpm_mclk` line from 933 MHz to 400 MHz. In the postload ladder every forced
arm decodes below the `auto` control: auto 9.09, high 7.47, profile_peak 7.24
tok/s, with `sclk_during` reading 1100 in all three
(`dpm-authority/20260902T1820Z-postload/`). In the direct-hwmon run the two
ranges overlap -- forced 6.30 to 7.02 against `auto`'s 6.84 to 8.20
(`dpm-authority/20260902T1822Z-actual/`, arms A1 through A5: high 6.66 +/- 0.63,
auto 6.84 +/- 0.14, high 7.02 +/- 0.99, profile_peak 6.30 +/- 0.18, auto 8.20 +/-
0.13), so that run orders the arms against A5 and not against A2. What it settles
is the mechanism rather than the ordering: every forced arm reads the fabric
surface starred at 400 MHz and both `auto` arms read it at 933, and the `auto`
arm whose mean delivered GFXCLK was 784 MHz still outran the `high` arm steady at
1100 MHz, so rate follows the fabric state rather than the delivered graphics
clock.

`manual` is the recovery. Writing `pp_dpm_sclk` level 2 without forcing the
performance-level state machine delivers the same 1100 MHz GFXCLK while leaving
the fabric at 933 MHz, and decodes 8.91 to 9.58 tok/s against `auto`'s 7.94 to
8.22 measured minutes apart in the same run
(`dpm-authority/20260902T1826Z-manual/`, arms M1 through M5).
`manual-gfx1100-fclk933` is the commanded state every later campaign arm runs
under, and the E4 kernel-delta run holds it on every sample.

The 1067 MHz fabric state is chosen by firmware and cannot be commanded. A
`pp_dpm_mclk` level-3 write is accepted with an empty error file and the starred
line still reads 933 MHz: over 107 busy rows of a 50 ms sampler through one
decode, 105 read 933 and 2 read 1067
(`dpm-authority/20260902T2002Z-fclk-level3/samples.tsv`). A follow-up run
positioned the sampler before the write to separate a firmware refusal from a
driver-side rescind, and all 54 samples in the two seconds after the write read
933 MHz with no row above it, which refutes the rescind account and leaves
firmware refusal of the 1067 MHz hard minimum standing
(`dpm-authority/20260902T2048Z-fclk-rescind/`). The asymmetry is exact: a hard
minimum at 400 MHz and at 933 MHz lands where requested, a request at 1067 MHz
lands at 933 however it is phrased, and the same firmware selects 1067 on its own
under `auto` load -- 117 of 232 busy samples in one arm and 9 of 270 in another
arm minutes later, which makes the arbitration's own instability a finding rather
than a duty cycle.

The registered predictions both failed, and the deviation is the finding. The
design note offered `high` holding the top step and matching or beating `auto`,
or `high` sitting near 650 MHz and moving the mechanism to the package power
layer. `high` held the top step and still decoded below every `auto` arm, which
neither branch described, and the subsidiary prediction that rate orders with
`selected_sclk_during` is refuted outright: all three arms of the postload ladder
read `sclk_during=1100` while `tok_s` spanned 7.24 to 9.09
(`dpm-authority/20260902T1820Z-postload/`).

A standing normalization check follows from it. With the 2B's decomposition of
about 97 ms of GPU bracket and 3.4 ms of host reads per token,
`predicted_token_ms(f) = 97 x 1100/f + 3.4` predicts 165.6 ms, or 6.04 tok/s, at
the 658 MHz sustained band one run measured after a twenty-minute CPU build,
against that run's measured 5.7 to 6.1 tok/s. Any arm reporting both a decode
rate and a steady `freq1_input` is scored against this formula before it is read
as a finding about anything other than clock.

The earlier `auto`-against-`high` comparison on `main` remains true and is not
the same experiment. `evidence/measurement-state-and-memory-clock.md`, "The
global high governor buys nothing", alternates the two levels and measures 3.23
against 3.23 and 3.27 against 3.22 tok/s on the 4B, indistinguishable. That run
predates the fabric-surface finding, carried no `freq1_input` column, and ran the
4B where the DPM authority runs used the 2B, so it records a null on a different
checkpoint under a different instrument rather than contradicting the 6.30-to-7.02
result.

### What would refute this layer

A retained sample showing the starred `pp_dpm_mclk` line above 933 MHz sustained
across a decode window under a `manual` level-3 write refutes the firmware
refusal. A forced `high` arm whose fabric surface holds 933 MHz refutes the
side-effect claim. A `pll` or `mc` operand found in a present ATOM table refutes
the VBIOS clock-surface absence. A `gfx_info` revision 2.3 or later image would
carry `active_cu_per_sh` and reopen the CU-count route that the frontier marks
`refuted`.

---

## Layer 3: driver and compiler

### RADV and ACO decide what the integer path can be

Mesa 26.2.1 is the driver on the appliance, and its ACO backend selects the
multiplier from a NIR-level range analysis rather than from a type. In
`src/amd/compiler/instruction_selection/aco_select_nir_alu.cpp`, `nir_op_imul`
with a VGPR destination takes the unsigned upper bound of each source through
`nir_unsigned_upper_bound`; where both bounds are at most `0xffffff` it emits
`v_mul_u32_u24`, where one source is constant it emits a shift-and-add sequence,
and otherwise it falls to `v_mul_lo_u32` (lines 1736 to 1768 of that file at
26.2.1). The optimizer then folds the product into a following add:
`add_opt(v_mul_u32_u24, v_mad_u32_u24, 0x3, "120", nullptr, true)` sits in the
`v_add_u32` fold table in `src/amd/compiler/aco_optimizer.cpp` near line 4528,
beside the signed `v_mul_i32_i24` to `v_mad_i32_i24` pair.

The design rule follows directly and is a property of the shader source rather
than of the device: every multiplicand must be provably unsigned and below 2^24
at the NIR level. A masked nibble (`& 0xF`, bound 15) and an unpacked byte
(`& 0xFF`, bound 255) satisfy it; a sign-extended int8 does not, because its
unsigned bound is `0xffffffff` and the selection falls to the quarter-rate
`v_mul_lo_u32` that layer 1's kernel battery measured at 100 VALU against 69.

### The llama.cpp gate

The device flag that decides whether any `_q8_1` pipeline is built is one
conjunction, read in `$HOME/src/llama.cpp-e4` at `18b5adbfe` (the pinned
commit with the production series applied):

```
ggml/src/ggml-vulkan/ggml-vulkan.cpp:6548
device->integer_dot_product = device->integer_dot_product &&
    shader_integer_dot_product_props.integerDotProduct4x8BitPackedSignedAccelerated;
```

RADV advertises the extension and reports that bit false, so the flag is false
so six pipeline-construction sites in the same file build nothing: 4995, 5044,
5092, and 5172 each wrap a `CREATE_MMQ` block for the `_q8_1` mat-mat and
mat-mat-id pipelines, and 5382 and 5437 wrap the `_q8_1` mat-vec blocks. All six
sit inside `#if defined(GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT)`, which is layer
1's second and independent refusal expressed in the build system: that flag comes
out OFF because the installed glslang and shaderc reject the extension, so the
pipelines are absent for two separate reasons at once. Two other kinds of site
read the same flag and are not pipeline construction: 4218 selects an integer
flash-attention path, and 9404, 9736, 10340, and 10636 set `quantize_y` at
dispatch time. The deployed binary agrees: zero `mul_mat_vec_q4_k_q8_1` symbols against seven
`mul_mat_vec_q4_k_f16` symbols (`evidence/tensor-type-execution-audit.md`).

Two nearby line numbers are not this gate and are miscited elsewhere. Line 427 is
the AMD branch's extension-presence early-out (`if (!amd_shader_core_properties
|| !integer_dot_product || !subgroup_size_control) return
vk_device_architecture::OTHER;`), which only decides whether the architecture
probe continues. Line 488 is inside the Intel branch and selects `INTEL_XE1`.
`CLAUDE.md` names line 6492 for the gate and the E5-int24 design note names 427
and 488; the statement is the same in every case and the line number moves with
the applied patch series, which is why a citation to this file should pin the
statement text and the tree identity rather than a bare line number.

The architecture classification is separately correct and needs no patch. A
device reporting `minSubgroupSize == maxSubgroupSize == 64` reaches
`vk_device_architecture::AMD_GCN`, which is exactly what RADV reports here, and
that class drives the flash-attention shapes, the conv2d shared-memory padding,
and a shader-core-count branch that specifically handles fewer than 32 cores
against this device's 2 (`hp14-raven2-gpu/docs/llamacpp-on-raven2.md`, "The
Vulkan backend needs no patch"). Cooperative matrix is absent from RADV here, so
the coopmat and coopmat2 shader variants are not built and the scalar FP16 path
is what runs.

The HIP backend is the layer's counterexample and stays unadmitted.
`ggml/src/ggml-cuda/vendors/hip.h` defines `GCN5` for `__gfx900__` and
`__gfx906__` only, so a gfx902 build leaves `GCN` undefined and two sites in
`mmvq.cu` fall through to `MMVQ_PARAMETERS_GENERIC` and
`get_mmvq_mmid_max_batch_pascal_older`, tuning a wave64 GCN part with a table
written for NVIDIA Pascal (same document, "Candidate HIP classification patch").
The patch exists and applies cleanly, and the macro it keys on is confirmed live
(`clang -E -dM` predefines `__gfx902__ 1` under `--offload-arch=gfx902:xnack+`),
and this tree retains no HIP performance measurement for it. What this tree does
retain is that HIP measures 14.06 prefill and 2.22 decode tok/s on the 4B distill
against RADV Vulkan's 21.49 and 3.10 in the same phase-split protocol, and that
every HIP invocation needs `HSA_ENABLE_SDMA=0` or `load_all_data` parks in
`hipEventSynchronize` for 51 minutes where the same binary completes in 19
seconds (`evidence/rocm-h0-operational-failure.md`).

### What would refute this layer

An ACO dump of a candidate shader showing `v_mul_lo_u32` or `v_cvt_f32_f16` in
an inner loop written to the 24-bit rule refutes the selection rule as applied. A
RADV release reporting `integerDotProduct4x8BitPackedSignedAccelerated` true on
this device would build the `_q8_1` pipelines and refute the gate's consequence.
A gfx902 HIP build measured above the Vulkan rows in a paired sweep refutes the
backend choice.

---

## Layer 4: runtime

### What the appliance streams, and by which path

Summed over the five production `models.tsv` rows, 9.17 GB of tensor bytes
divide as Q4_K 40.38%, Q6_K 27.98%, F16 16.84%, Q8_0 8.99%, Q5_K 5.66%, F32
0.15% (`evidence/tensor-type-execution-audit.md`). F16 and F32 execute natively;
the four quantized types take the FP16-dequantize-then-dot family because layer
3's gate leaves the accelerated family unbuilt, so about 83% of production
streamed bytes run the path layer 1 measured at 49 VALU against gfx906's 33.

Achieved streaming forms two groups rather than ordering by bit width: Q4_K and
Q6_K trunks reach about 8.1 GB/s where a Q5_K trunk reaches about 5.9
(`evidence/decode-bound-analysis.md`). The code-level account is that Q5_K alone
pays both the packed scale-and-minimum decode and an extra bit-plane merge, where
Q4_K skips the bit-plane and Q6_K skips the complex scale, and all three shaders
issue with identical tile parameters so subgroup utilization does not order them.
That account is marked in its own document as a hypothesis with code evidence
rather than a measurement, and a pure-Q5_K arm is the check it names.

### E4: a shader edit measured at the dispatch bracket

E4 is `llama-vulkan-q4k-activation-group-sums.patch`: the Q4_K mat-vec inner loop
recomputes each activation sub-block's sum once per output row it multiplies, and
the patch computes those group sums once and reuses them across the rows, with
the same edit mirrored in Q5_K. The name and the receipt agree on that reading --
96 `v_mac_f32` leave the tile and the longest dependency chain nearly halves,
which is what reuse across rows produces -- and the diff itself is the authority a
reader should check. The static receipt is ACO VALU 882 to 810,
`v_mac_f32` 248 to 152, longest dependency chain 29 to 17, VGPR and occupancy
unchanged. The registered opportunity was 4.16 ms per token, 8.1% of the Q4_K
bracket, over a kernel streaming about 10 GB/s of the 34 GB/s peak and therefore
not purely bandwidth-bound
(`evidence/raven2-vulkan-kernel-census/e4/kernel-delta-design.md` on
`stage-a-census-brackets`).

Three served A/B runs before it were inconclusive because host noise at load 5 to
7 swamped a change this small. The kernel-delta run replaced the served
wall-clock comparison with device-timestamp brackets around each dispatch inside
the graph, and ran four pairs in W C K K C order at 63 decode graphs per arm with
the clock held at `manual-gfx1100-fclk933` on every sample
(`e4/kernel-delta-20260902T2312Z/README.md`):

| role | column | mean | sd | 95% interval | verdict |
| --- | --- | ---: | ---: | --- | --- |
| subject Q4_K | `exclusive_bracket_ms` | -0.0393 | 0.0002 | [-0.0395, -0.0390] | shortened |
| subject Q4_K | `pipeline_bracket_union_ms` | -0.0390 | 0.0002 | [-0.0393, -0.0387] | shortened |
| null Q6_K | `exclusive_bracket_ms` | -0.0001 | 0.0004 | [-0.0008, +0.0005] | held |
| graph span | `queue_completion_span_ms_per_graph` | -0.0209 | 0.0017 | [-0.0236, -0.0183] | secondary |

The bracket shortened 3.93%, inside the registered 2-to-10% window and at 48% of
the stated 8.1% opportunity; per-dispatch median moved 207.4 to 199.8 us. The
untouched Q6_K pipeline held, union tracked exclusive within 0.03 points so the
shortening is an execution-envelope effect rather than an overlap-accounting
artifact, and the disassembled candidate module matched the static receipt
exactly at VALU 810 and `v_mac_f32` 152 against the control's 882 and 248. Whole
token rate under instrumentation read +2.37% [+1.71, +3.02], the first served E4
comparison to resolve, and these arms ran at host load 2.3 rather than 5 to 7.

E4 does not reach the 5% whole-model promotion bound and was not expected to. Its
own maximum over the measured denominator is `52 x 0.08 = 4.16 ms` of a 101.4 ms
token where 5% needs 4.83 ms removed; E4b's maximum is `52 x 0.16 = 8.32 ms`, so
E4b carries 5% at about 58% realization
(`evidence/raven2-vulkan-kernel-census/state-preserving-campaign.md` on
`stage-a-census-brackets`, "The bounds these arms are read against").

### The runtime classes and the scoreboard

The 2B class is the primary performance target, the 0.8B the secondary fast
target, and the 4B the quality-heavy fallback; a general runtime experiment runs
2B first, 0.8B second, 4B third, and becomes a Raven2-wide default only where the
classes agree (`CLAUDE.md`, "Three runtime classes, one primary target"). Stage 0
of the served campaign fixes the denominators each later arm is read against, from
one sealed twelve-arm run against the promoted binary
(`evidence/fixed64-served-campaign/README.md`, run `20260901T2011Z/`):

| class | mean tok/s | min | max | span | target | mean/target |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.8B `qwen35-08b` | 18.257 | 16.233 | 19.138 | 17.89% | 20 | 0.913 |
| 2B `qwen38-2b-distill` | 9.864 | 9.831 | 9.895 | 0.65% | 10 | 0.986 |
| 4B `qwen38-4b-distill` | 3.352 | 3.331 | 3.365 | 1.01% | 5.25 | 0.638 |

All three read `unmet` at terminal state `completed-target-unmet` with 12 of 12
arms completed. The 0.8B's 17.89% span is attributed to one clock excursion on
slot 12, where `sclk` stepped through 733 and 1050 MHz while every other arm held
400 and 1100, rather than to a checkpoint property; the other three 0.8B arms sit
at 0.94 to 0.96 of target. In-sweep ratios are 2B/0.8B 0.540, 4B/2B 0.340, 4B/0.8B
0.184, and the 2B's 0.65% span is what the census README adopts as its
compile-cost bound.

### What would refute this layer

A repeated kernel-delta run reading `bracket-unchanged` or `lengthened` on Q4_K
refutes E4's mechanism. A moved Q6_K null indicates machine-state contamination
and voids the pair. A repeated Stage 0 sweep whose class means fall outside the
retained spans refutes the denominators. An IQ4_XS or Q3_K_M arm landing outside
the group its operation mix predicts refutes the two-trunk grouping.

---

## Layer 5: measurement discipline

Five rules earn their place because a run violated each of them first.

**The clock invariant belongs on fresh reads of the right rail.** A receipt
schema built on `pp_dpm_sclk`'s reported step passed `clock_invariant=held` for
a `profile_peak` arm that decoded slowest of three, because the step it recorded
was the selected state and not the delivered clock, and because the surface that
ordered the rates was FCLK, which the schema had no column for
(`dpm-authority/README.md`). The invariant now reads `freq1_input` for the
delivered graphics clock and the starred `pp_dpm_mclk` line for the fabric state,
together.

**Quiescence is a covariate, not an assumption.** A depth-0 rate on this part
carries about 4% of uncontrolled spread: identical flags measure 3.11 hot and
3.24 cold ten minutes apart with `mclk` at 933 and `sclk` peaking at 1100 in
both, so neither clock ladder explains it
(`evidence/measurement-state-and-memory-clock.md`). Under desktop load that
reaches 30.6% (`evidence/decode-bound-analysis.md`). Deep rungs are less exposed:
a 16384 rung is preceded by about thirteen minutes of prefill that settles the
part, and two independent harnesses agree there to 1.1%.

**A comparison is read inside one sweep.** Four absolute bands built from
four-block means all read low against a seven-checkpoint sweep that ran 11.1 to
11.5% above those means on the two common checkpoints, with no falsifier met and
an offset larger than every effect the predictions were trying to resolve, so an
absolute band measures the sweep. The proposed remedy of one scalar offset per
sweep is itself unconfirmed: in a twelve-arm re-run the 4B distill fell 10.6%
where the 2B fell 16.4%, moving the pair's ratio from 0.3634 to 0.3884 against a
registered 0.345-to-0.382 band it overlaps by 0.002
(`evidence/model-admission/runtime-class-throughput.md`). An in-sweep ratio is
more stable than an absolute rate and is not invariant.

**The reported deviation is not the uncertainty.** `llama-bench` prints a
standard deviation over the repetitions inside one arm, and those repetitions
agree far more closely than an arm agrees with its own reverse: the 4B distill
measured 3.41 +/- 0.01 and 2.95 +/- 0.01 in one sweep, 0.3% within each arm
against 14.5% between them. Raising the repetition count measures one machine
state better rather than narrowing the spread; four slots per checkpoint brought
that row to a 4.4% span where two slots gave 14.5%.

**A margin contract must be registered ahead of the run, and a registered
contract can still be the thing that gets refuted.** The E4 margin contract fixed
`top_k=10`, `near_tie=0.1 nat`, `retention=0.5` at commit `37c3fcb` before the
holdout ran: identity at every position, with a near-tie position exempted from
strict identity and judged instead on retaining at least half the control's
margin. Over twelve holdout prompts at temperature 0, order C K K C, 128 tokens,
10 held and 2 differed, with the tightest margin retention at 0.786 against the
0.5 floor and the largest selected-logprob movement on a held prompt at 0.047 nat
(`e4/margin-holdout-20260903T0456Z/README.md`).

The two flips are what refuted the rule rather than the change. Grid-walk flipped
at position 25 on a control top-2 margin of 0.0001 nat; temperature-log flipped
at position 15 on 0.0023 nat. Both margins sit inside the reassociation noise E4
itself produces (up to 0.024 nat in the discovery run) and below the precision at
which two builds of identical source already agree, since the calibration run
measured no movement at all between same-source builds. Requiring bit-identity
there requires bit-identical arithmetic, which only a same-source, same-build
pair delivers. The registered verdict `witness=differs` is formally upheld and
the run's summary reads `numerical_identity refuted`; what the document registers
in response is a corrected contract -- identity where the control margin is at or
above the near-tie threshold, sub-threshold flips read as ties -- and it
explicitly declines to re-read this run under the corrected rule, because that
requires a fresh independently registered run. For scale, a CPU-against-Vulkan
backend swap already served as equivalent moves argmax on 4 of 6 prompts and
logprobs by up to 0.375 nat.

The earlier 1e-3 nat bound went the same way: the token-id and logprob witness
held on all 768 generated tokens over six prompts with a maximum movement of
2.421e-2 nat, so the bound was refuted and retired without a replacement figure
(`e4/kernel-delta-witness-20260903T0148Z/README.md`).

**Priority is a contract field, and it is not the scatter mechanism.** Eleven
llama-bench arms alternating nice 19 and nice 0 on the pinned inference core,
under `manual-gfx1100-fclk933` with 1100 MHz delivered on every busy sample,
measure six adjacent pairs at a mean of +1.87% for nice 0, sd 1.25%, nominal 95%
interval [+0.56%, +3.18%] -- an interval excluding zero narrowly
(`dpm-authority/20260902T2154Z-nice-probe/README.md`). Rate follows host load
rather than priority: under nice 0 alone the rate slid from 9.74 to 9.26 tok/s as
`load1` rose from 2.3 to 3.5. The retained historical comparison on `main` reaches
the same place from the other side, measuring a paired mean difference of 1.10% in
favor of nice 19 with a nominal interval spanning -6.1% to +3.9%, which resolves
no direction and establishes no equivalence
(`evidence/scheduling-priority-cost.md`). The applied value is read back from
`/proc` rather than asserted, through `remote/qwen-exec-idle-priority.sh`, which
exits 125 on any reading other than 19 (`evidence/priority-absolute-idle.md`).

---

## Layer 6: transferable methods from two sibling repositories

Neither sibling's subject matter transfers: `open_gororoba` is Cayley-Dickson
algebra, heliospheric plasma dynamics, and lattice-Boltzmann turbulence with
Rocq proofs, and `4-bit` is an Intel 4004/4040 archive and multi-fidelity
emulator, and neither body of mathematics or emulation says anything about
quantized inference on a Vega iGPU -- what transfers is the claim-status
discipline of the first and the accuracy-level ladder of the second.

### A claims ledger, from open_gororoba

`registry/claims.toml` carries 1,551 `[[claim]]` blocks with five required
fields -- `id` (`C-NNN`), `status`, `statement`, `where_stated`, `last_verified`
-- and two optional ones, `formal_proof` (161 of 1,551) and `status_note` (594 of
1,551). The status vocabulary is larger than a three-value ladder: Verified 1232,
Refuted 117, Provisional 109, Established 44, Superseded 15, and a typed
`Closed/*` family naming the closure reason -- Methodology-Insufficient 8,
Research-Program 7, Negative-Result 6, Refuted 3, Toy 2, Source-Insufficient 2,
Analogy 2, Obstructed 1 -- beside Theoretical 3. Refutations are retained
permanently with their closure reason typed rather than deleted.

Two mechanisms are the reason it holds. `Verified` there means kernel-checked by
Rocq 9.1 -- a passing `Qed.` in a named `.v` file under `proofs/verified/` that
`formal_proof` points to -- so the strongest status is bound to an artifact a
checker either accepts or rejects. And the TOML is not the source of truth:
`registry/canonical/control_plane.sqlite3` is the canonical write target, every
exported TOML opens with `# AUTO-GENERATED: READ-ONLY COMPATIBILITY EXPORT.`
naming that path, regeneration runs through one command, and a hand edit to an
exported file produces a `content_sha` mismatch that the governance gate catches
(`docs/db/ARCHITECTURE.md`, three layers: canonical SQLite, compatibility TOML,
query CLI).

What a ledger of that shape would carry for this appliance is exactly the
material this document assembled by hand: one row per decision-grade claim, with
its evidence class, its owning evidence path, its falsifier, and the run that
last confirmed it. The differences from this tree's existing discipline are three
and they matter. This tree binds a claim to a directory rather than to a row, so
the falsifier lives in prose inside the owning document and a query cannot
enumerate every claim whose falsifier is unmet -- the paper-oriented claim map in
`evidence/research-claim-methodology.md` is six rows of that ledger written by
hand. This tree has no formal-proof analogue, because a decode rate is not a
theorem, so its strongest status is a retained paired run rather than a `Qed.`;
the honest mapping is that a `validated` row in `remote/validated-tuples.tsv`
requiring its evidence path to exist in the tree is the closest existing
mechanism, and `remote/check-ledger-evidence.sh` is its checker. And this tree
already has the canonical-store discipline in a narrower place: `models.tsv`,
`validated-tuples.tsv`, `quarantine.tsv`, `ctx-checkpoints.tsv`, and
`draft-pairs.tsv` are read only through `model-registry.sh`, which validates the
whole ledger before answering any query, which is the same fail-closed rule
applied to serving policy rather than to claims.

### An accuracy ladder, from 4-bit

`docs/ACCURACY_PROGRAM.md` defines three levels by what derives the behavior
rather than by how close the output looks. Level 1, cycle- and phase-accurate, is
the present baseline: instruction semantics match primary manuals, I/O signals
assert only in correct bus phases, fixtures execute without bus contention. Level
2, gate- and switch-level, requires behavior derived from extracted layout
connectivity and devices rather than hand-written logic, with waveform validation
against primary timing diagrams and a curated anchor-subcircuit regression suite
as the promotion gate. Level 3, electron- and analog-accurate, requires parasitic
RC extraction and a calibrated MOS model reproducing one documented
analog-sensitive phenomenon, and is blocked pending process and geometry primary
sources. Promotion is never a score; each level states its own acceptance
criteria and its own blocking dependency.

The primary-source rule is the part that maps cleanly here. `docs/AUDIT.md` is a
per-claim table of `Claim | Source | Status | Notes` whose status vocabulary is
`Verified (primary)`, `Verified (primary, OCR)`, `Verified (secondary)`,
`Verified (secondary, forensic)`, and `Derived (primary)`. Primary means sourced
from a datasheet or manual scan held in the repository and cross-checked against
an OCR sidecar under `docs/evidence/ocr/`; secondary means an external tertiary
source stands in because the held primary scans do not contain the figure. The
traceability rule in `ACCURACY_PROGRAM.md` binds both: every claim carries either
a primary reference with a local OCR excerpt path, or an explicit
secondary-or-pending marking, and must have a test or extraction artifact able to
fail if the claim is wrong. Pending items are enumerated rather than tolerated
silently, in `docs/AUDIT.md`'s "Next Verification Targets" and in the
priority-tiered `docs/evidence/PRIMARY_SOURCES_BACKLOG.md`, each with its own
acceptance criterion; the currently open ones include the 4004 and 4040
transistor counts and instructions-per-second figures, which appear only in a
secondary source.

"Pending primary confirmation" maps onto this tree's classes as a split rather
than a fourth class. A figure held only by a secondary source and searched for
without success in every primary held is **documented** as to its existence and
**untested** as to its authority; the mapping this tree needs is a second field
naming the authority level beside the evidence class, because
`evidence/research-claim-methodology.md` already separates the two in prose --
"Source reading explains a mechanism and defines a falsifier; it does not convert
a source-level expectation into silicon evidence" -- while carrying only one
field. The cases that need it exist: the Q5_K trunk account is code-read and
marked in its own document as hypothesis-with-code-evidence, and the 24-bit
selection rule of layer 3 is compiler-source-read with no ISA receipt from a
built shader.

The accuracy ladder itself transfers as the E-series structure this tree already
runs, with different rungs. A static ISA receipt from ACO is one level, a
device-timestamp dispatch bracket is the next, a served whole-token rate under
the scoreboard tuple is the next, and a graded quality suite is the gate above
them; E4 passed the first three and the fourth is outstanding. Naming those as
levels with their own promotion criteria, rather than as an ordered list of runs,
is what the 4-bit ladder adds.

---

## Lacunae

Each row names one gap the derivation exposed, the probe that closes it, the
evidence class the probe would produce, and the falsifier or acceptance rule that
ends it.

### 1. The device memory ceiling is unmeasured

The 34.13 GB/s figure is derived from UMC registers and describes the DRAM
controller; the 15.44 GB/s two-thread host read bounds the Zen+ load/store path.
The iGPU reaches memory through the Data Fabric on a third path whose limit no
run has measured, so no achieved decode rate can be stated as a fraction of the
device's own ceiling. **Probe**: a Vulkan compute kernel that streams a buffer
larger than L2 with no arithmetic, run at the `manual-gfx1100-fclk933` operating
point, sized to saturate both compute units, reporting bytes over device
timestamps. **Class**: measured. **Falsifier**: a kernel bandwidth at or above
34.13 GB/s refutes the DRAM peak as the binding constraint; one near the 8.1 GB/s
the Q4_K trunk achieves says the trunk is already at the device limit and closes
every kernel-arithmetic route below it.

### 2. The sibling repository's 29.9 GB/s premise is refuted and not yet reopened

`hp14-raven2-gpu/docs/raven2-capability-decomposition.md` derives 29.9 GB/s and
9.4 flops per byte from `pp_dpm_mclk` read as a DRAM clock, and
`llamacpp-on-raven2.md` carries it into a 7.5 tok/s idealized ceiling. This
tree's UMC decode refutes the reading, and the sibling's `raven2-memory-bandwidth`
row still reads `measured elsewhere` at 29.9 GB/s. **Probe**: file this tree's
paired register decode against that row, which its own falsifier admits, and
correct the two derived figures the sibling built on it. **Class**: documented,
since the measurement exists and the gap is the citation. **Falsifier**: a UMC
readback on that target disagreeing with this one restores the original reading
and closes the row the other way.

### 3. The compile-cost control bound is registered and unreported

The census design separates instrumentation cost into a compile arm (`P I0 I0 P`)
and a collection arm (`I0 I1 I1 I0`), and adopts the 2B's 0.65% Stage 0 span as
the compile-cost bound and 2% as the collection-cost bound
(`evidence/raven2-vulkan-kernel-census/README.md`). The retained census
directories carry calibration and control bricks, and no document in this tree
reports the two control arms' measured costs against those bounds. **Probe**: run
both control ladders under the census harness and publish the two deltas beside
the bounds. **Class**: measured. **Falsifier**: a compile-arm delta above 0.65%
voids every instrumented comparison read against a production denominator; a
collection-arm delta above 2% voids the bracket instrument itself.

### 4. The served-path priority contract rests on a bench lower bound

The nice probe measures +1.87% [+0.56%, +3.18%] for nice 0 over nice 19 on
llama-bench, which holds a shorter host critical path than the served decode -- no
sampling, no HTTP -- so the figure bounds the served-path effect from below while
`remote/census-arm-lib.sh` on `stage-a-census-brackets` requires `server_nice=19`
against the scoreboard receipt and
`qwen-webui-session.sh` admits readiness only at nice 19. **Probe**: a paired
served campaign with the server's priority as a contract field rather than a
constant, alternating nice 19 and nice 0 arms under one clock state. **Class**:
measured. **Falsifier**: a served effect at or below the bench's +1.87% confirms
the bound; one above +3.18% makes the appliance's own priority a denominator term
and every retained scoreboard figure a measurement of it.

### 5. The guest-paused diagnostic is registered and unrun

Two KVM vCPU threads at nice 0 share both cores, one L3, and one DDR4 controller
with a decode streaming about 12 GB/s of weights, and shared bandwidth and cache
is the remaining candidate mechanism for the load-ordered scatter that priority
does not remove. **Probe**: one labelled diagnostic run with the guest paused,
paired against the same arms with it running. **Class**: measured, and marked
`diagnostic` because it characterizes a machine the appliance is not.
**Falsifier**: a paired sd staying near 4% under a paused guest refutes the shared
memory account; one falling to the within-arm 1 to 2% confirms it. It decides
nothing about promotion either way.

### 6. The prefill ladder has no arm of its own

Prompt processing carries more arithmetic intensity than decode and is the
candidate surface for packed-FP16 gains, and every campaign arm in this tree is
read on decode: the scoreboard denominators are decode rates, E4 is a mat-vec
edit, and the placement sweep's prefill column is a single depth-0 figure per
placement. `evidence/model-admission/runtime-class-throughput.md` already shows
the halves separating where decode does not -- Q8_0 against Q4_K_M on the 0.8B
reads 146.22 against 134.91 tok/s prefill while the decode halves differ by 0.9%.
**Probe**: a prefill ladder at several prompt depths per runtime class under one
clock state, reporting `pp` rows against the same denominators the decode
scoreboard fixes. **Class**: measured. **Falsifier**: a prefill rate scaling with
streamed bytes the way decode does refutes the arithmetic-intensity account and
closes packed FP16 as a prefill lever.

### 7. The E5-int24 ISA receipt is unwritten

The design is registered -- rewrite the Q4_K mat-vec inner product as biased
unsigned bytes times masked nibbles so ACO's `nir_op_imul` bound check selects
`v_mul_u32_u24` and the optimizer folds it to `v_mad_u32_u24`, replacing the FP16
extraction and conversion the current path pays -- and no shader is written and no
arm is run. The design note itself is not in this tree; it exists as a session
artifact. **Probe**: write the candidate shader, compile it under the installed
toolchain, and disassemble the pipeline before touching the device; commit the
design note to `evidence/raven2-vulkan-kernel-census/` beside it. **Class**:
documented for the compiler rule, measured for the receipt. **Falsifier**: the
compiled candidate holding `v_mul_lo_u32` or `v_cvt_f32_f16` in its inner loop,
or fewer `v_mad_u32_u24` than the product count predicts, refutes the hypothesis
at the ISA before any device window is spent.

### 8. E4 has no graded quality result

Both E4 documents list general task-quality non-regression as pending the graded
suite. The margin holdout establishes that two flips occur at control margins of
0.0001 and 0.0023 nat and that both trajectories then diverge for the rest of the
reply, which is a continuation-quality question the holdout explicitly declines to
answer. **Probe**: `remote/run-quality-suite.py` against the E4 candidate and the
production control inside one sweep, read as a within-sweep comparison because a
one-row or two-row difference across sweeps reports position in a sequence.
**Class**: measured. **Falsifier**: a category-level fall against the control
inside one sweep quarantines E4 ahead of any throughput claim.

### 9. The corrected margin contract needs a fresh registration and a fresh run

The holdout refuted the strict identity line of its own contract and registered a
corrected rule -- identity where the control margin is at or above the near-tie
threshold, sub-threshold flips read as ties -- while explicitly declining to
re-read the same run under it. **Probe**: register the corrected contract as its
own design note at a named commit, then run a fresh holdout on prompts not used in
the discovery or the first holdout. **Class**: untested until run, measured after.
**Falsifier**: a flip on the fresh holdout at a control margin above the near-tie
threshold refutes E4's numerical soundness under the corrected rule, which the
first holdout could not test because both its flips sat below it.

### 10. The 0.8B and 4B census attributions are missing

Every census arm, the E4 bracket, and the whole kernel ladder run on the 2B, and
the byte-share table that justifies a Q4_K edit is summed over all five production
rows rather than per class. The 0.8B serves Q8_0 and the 4B is a different depth
of the same trunk, so neither class's bracket composition is known and a
Raven2-wide default cannot be declared from a 2B result under the tree's own
class-agreement rule. **Probe**: run the I1 census against the 0.8B and the 4B
under their own registry tuples and publish per-class pipeline attributions.
**Class**: measured. **Falsifier**: a Q4_K bracket share on either class differing
materially from the 2B's makes E4's per-class realization a separate number and
blocks the Raven2-wide promotion.

### 11. The PROCESSDS consumers are unidentified

All twelve blocks are resolved as data the table addresses through
`SETDATABLOCK 0xff` and an `ATOM_WS_DATAPTR` add, and the retained ATOM graph
identifies no consumer; each sits after its table's `EOT`, and an x86-region
consumer and a driver consumer are both hypotheses
(`vbios-decoder-report.md`, "Next bounded decompilation frontier"). **Probe**:
cross-reference the amdgpu ATOM interpreter source against each block's read path,
and follow `main_call_parser_entry` at `0x2cd8` into the interpreter to bind a
command table index to a caller (the frontier's own `parser-thunk-callee-semantics`
row). **Class**: documented. **Falsifier**: a block whose payload base is absent
from its own table's DATAPTR constants reopens the mechanism finding as well as the
semantics. This is a sibling-repository row and reaches this appliance only if a
consumer touches a clock or power path.

### 12. The FCLK 2-3 mask experiment is unrun

The firmware honors a fabric hard minimum at 400 MHz and at 933 MHz, caps a
1067 MHz hard-minimum request at 933 however it is phrased, and selects 1067 on
its own under `auto` load on 117 of 232 busy samples in one arm. A soft maximum of
1067 was accepted and still read back 933 at idle, which was probed once at idle
with no load and no sampler. **Probe**: write the `2 3` mask under `manual` and
sample the starred fabric line at 50 ms through a loaded decode window rather than
at idle, paired against a `manual` level-2 arm and an `auto` arm in one session.
**Class**: measured. **Falsifier**: sustained 1067 MHz busy samples under the mask
refute the firmware-cap account and make the fabric state commandable; a busy
window at 933 throughout confirms the cap under load and closes the sysfs route to
1067 entirely.

### 13. Whether the appliance should serve under `manual` is undecided

The DPM directory measures the fabric-clock floor that `manual` delivers and
compares no production denominator under either policy; the retained arms are four
short exploratory runs, and whether `manual` holds 1100 MHz across a twenty-five-arm
campaign is unmeasured. **Probe**: a paired campaign running production-auto and
production-manual as two separate scoreboard denominators over the full twelve-arm
Stage 0 shape. **Class**: measured. **Falsifier**: a `manual` denominator inside the
`auto` denominator's own span leaves the appliance on `auto`; one above it by more
than that span makes the operating point a policy change that
`radv-low-priority-env.sh` must carry.

### 14. The BAPM budget cost is unmeasured

Every DPM arm read `bapm=-1`, which the kernel module documentation states as
auto-enabled rather than disabled, and no arm wrote to it or isolated what BAPM's
package budget costs the CPU side while the GPU clock is pinned. **Probe**: a
paired arm at `manual` with the host under a fixed two-core load, reading CPU
frequency and package power beside the decode rate. **Class**: measured.
**Falsifier**: a CPU-side cost under a pinned GPU exceeding the decode gain
`manual` delivers makes the pin a net loss on a machine that also serves a host.

### 15. The Q5_K trunk account is code evidence without a measurement

Q5_K alone pays both the packed scale-and-minimum decode and an extra bit-plane
merge, and all three K-quant shaders issue with identical tile parameters, which
accounts for the 5.9-against-8.1 GB/s grouping without measuring it; the owning
document marks it a hypothesis with code evidence. **Probe**: a pure-Q5_K
checkpoint arm inside one sweep against a Q4_K and a Q6_K arm, or a census
attribution isolating the Q5_K mat-vec bracket. **Class**: measured.
**Falsifier**: a Q5_K trunk achieving the Q4_K/Q6_K group's rate refutes the
bit-plane account and reopens the grouping.

### 16. Line-number citations into llama.cpp drift under the patch series

`CLAUDE.md` names `ggml-vulkan.cpp:6492` for the integer-dot device gate, the
E5-int24 note names 427 and 488, and the statement sits at 6548 in the tree
carrying the production series; 427 is the AMD extension early-out and 488 is the
Intel XE1 branch. **Probe**: cite the statement text and the tree-plus-commit
identity, and add a repository gate that greps each cited statement in the pinned
source rather than checking a line number. **Class**: documented. **Falsifier**: a
cited statement absent from the pinned source fails the gate, which is the whole
point; a line-number citation that still resolves proves only that the series has
not moved yet.

### 17. The census and DPM evidence lives on an unmerged branch

Layers 2, 4, and 5 of this document cite
`evidence/raven2-vulkan-kernel-census/dpm-authority/` and
`evidence/raven2-vulkan-kernel-census/e4/`, which exist on
`stage-a-census-brackets` and not on `main`, so a clone at `main` cannot resolve
the operating point every later arm claims to run under. **Probe**: merge the
branch, or, until then, read every branch citation in this document with
`git show origin/stage-a-census-brackets:PATH`. **Class**: documented.
**Falsifier**: `remote/check-ledger-evidence.sh` and the evidence manifest see only
the checked-out tree, so a merge that omits any cited directory leaves this
document naming a path no gate can verify.

### 18. Prefill and decode share one instrument that measures decode

`QWEN_BENCH_PREFILL` requires exactly one `pp` row and one `tg` row per successful
process and makes an incomplete pair terminal, which is a correctness rule rather
than a prefill measurement, and the fixed-64 campaign's twelve arms report decode
alone. Row 6 asks for the ladder; this row names the instrument gap that would
carry it. **Probe**: extend the served campaign's arm schema with a prefill column
bound to the same clock sidecar and the same terminal-state rule. **Class**:
untested. **Falsifier**: a prefill column whose within-arm spread exceeds the
between-arm difference it is meant to resolve makes the served path the wrong
instrument for prefill, and the ladder moves to llama-bench with its own controls.

---

## What this derivation settles

The chain from silicon to served token is closed at every layer except one, and
the missing layer is a denominator for the device. Every rate in this
tree is read against another rate measured in the same sweep, which is the correct
discipline for comparison and says nothing about how much of the machine a decode
uses. Lacuna 1 is the one that would change how the rest are read: until a Vulkan
kernel measures what the iGPU can stream, an 8.1 GB/s trunk is a number without a
ceiling, and every kernel-arithmetic experiment below it is being run without
knowing whether arithmetic is what binds.
