# E5: the Q4_K x Q8_1 mat-vec without a dot instruction, in three paths

gfx902 holds no `V_DOT4`, RADV reports every `integerDotProduct*Accelerated` bit
false, and `ggml-vulkan.cpp` builds no `_q8_1` mat-vec pipeline here, so the 2B
distill's Q4_K trunk streams through the FP16 dequantize-then-dot family. The
same silicon runs `v_mul_u32_u24` and `v_mul_i32_i24` at full rate where
`v_mul_lo_u32` is quarter rate. E5 asks whether a packed 8-bit dot built on that
multiplier beats the FP16 path on the device, and it now asks it through the
standard interface rather than through a rewrite.

## The hypothesis, and what it replaced

The lane opened by writing its own GLSL: sixteen straight-line masked-byte
products in place of `dotPacked4x8EXT`, because the appliance's own glslc
rejects `GL_EXT_integer_dot_product`. That rewrite works and is exact, and the
ISA receipts measure it losing to the compiler's own lowering of the same
computation by 318 VALU instructions on identical silicon. The registration is
therefore inverted: the standard route is the hypothesis and the rewrite is the
control it is read against.

```text
E5-M    manual, hand-expanded int24 GLSL          the negative control
        no dotPacked4x8EXT, no OpSDotKHR; 1646 VALU, 11704 code bytes
        the one route the appliance's own toolchain can build today

E5-S0   the standard packed dot, stock driver     the hypothesis
        GLSL dotPacked4x8EXT -> SPIR-V OpSDotKHR -> NIR sdot_4x8_iadd ->
        ACO's generic GFX9 expansion; 1328 VALU, 9496 code bytes

E5-S1   the same SPIR-V, target-aware driver      the hypothesis, sharpened
        the identical module through an isolated RADV carrying Mesa merge
        request 2115's ACO lowering: four byte-extract-folded 24-bit multiplies
        plus two v_add3_u32, six operations against the generic seven;
        1297 VALU, 9540 code bytes
```

The caller interface stays standard the whole way down, which is the point:
`dotPacked4x8EXT` in GLSL, `OpSDotKHR` in SPIR-V, `nir_op_sdot_4x8_iadd` in NIR,
and a gfx902 software sequence in ACO. Nothing in this repository rewrites a
shader for E5-S0 or E5-S1; what it supplies is a producer that can emit the
module and a driver that lowers it well.

`E5-M/README.md`, `E5-S0/README.md`, and `E5-S1/README.md` carry each path's own
receipts, mechanism, and status. `int24-design.md` is the lane's original
registration, verbatim from before a line of shader existed;
`int24-equivalence.c`, `compile-matrix.tsv`, `spirv/`, and
`isa-shimmed-raven2/` hold the arithmetic, the compile matrix, the SPIR-V
receipts, and the two production anchors all three paths are read against.

| path | valu | code_size | vgprs | blocks | longest_valu_chain | isa_sha256 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| production FP16 dequantize | 882 | 6764 | 64 | 82 | 29 | `ad837848d5...` |
| E5-S1 | 1297 | 9540 | 36 | 54 | 24 | `b9f5b4e6e2...` |
| E5-S0 | 1328 | 9496 | 36 | 54 | 23 | `a4d5f70939...` |
| E5-M | 1646 | 11704 | 36 | 54 | 35 | `8896269f54...` |

## What the arm can reach, and what admits it

`ggml_vk_should_use_mmvq` returns false on AMD below `k = 2048` and false for
Q6_K on every vendor but Intel, so the 2B distill's Q4_K trunk is the family
this lane touches and its 50.08% Q6_K by byte stays on the FP16 path. The
whole-token ceiling is that share rather than the 83% the FP16 family holds.

`GGML_VK_FORCE_INTEGER_DOT=1` admits the pipelines on a device reporting no
acceleration. `patches/llama-vulkan-q4k-int24-mmvq.patch` splits the backend's
one `integer_dot_product` bool into four fields so the variable moves the
selection alone: `integer_dot_functional` from the extension,
`integer_dot_accelerated` verbatim from the driver's own report with nothing in
the build writing it, `integer_dot_software_lowered` as the build's own claim
that the variable admits, and `integer_dot_pipeline_selected` as the disjunction
the pipeline table and every `quantize_y` dispatch read. Every advertised Vulkan
acceleration property reads exactly what RADV reported under every arm.

E5-S carries a wider dispatch set than E5-M. An extension-capable build defines
`GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT`, which also gates the MMQ mat-mat and
flash-attention int8 shaders and `ggml_vk_fa_scalar_uses_mmq`, so a comparison
across E5-M and E5-S measures more than the mat-vec unless that set is held
fixed. E5-S0 against E5-S1 shares the whole set and differs by the driver alone,
which is why that pair is read first.

## The measurable served arm

Every arm of `remote/run-served-binary-ab.sh` runs under `low-async`, and
`remote/radv-low-priority-env.sh` unsets every `GGML_VK_*` name before its
profile case, so `GGML_VK_FORCE_INTEGER_DOT` reached no server and the served
comparison was structurally unmeasurable. `QWEN_FORCE_INTEGER_DOT` crosses that
scrub under its own name the way `QWEN_PIPELINE_CENSUS` does, admitting the
exact `1` the backend compares against and refusing any other value;
`qwen-webui-control.sh` forwards it across the tmux boundary. The campaign
admits it per role:

```sh
QWEN_CENSUS_AB_MODE=served \
QWEN_AB_CANDIDATE_FORCE_INTEGER_DOT=1 \
QWEN_AB_CANDIDATE_PATCH=llama-vulkan-q4k-int24-mmvq.patch \
QWEN_CENSUS_PRODUCTION_RECEIPT=RECEIPT/identity-check.tsv \
    remote/run-served-binary-ab.sh CONTROL_SERVER ARM_SERVER \
    qwen38-2b-distill OUT
```

`inputs.tsv` and `campaign-inputs.tsv` carry `control_force_integer_dot` and
`candidate_force_integer_dot`, each arm's `arm-environment.tsv` carries the value
its role asked for, and `vulkan_profile` still reads `low-async`, which is the
field the scoreboard receipt requires. A named profile of its own would have put
a second string in that field, and `custom` exports a submission setting only
where the caller supplies one, so an arm run through it and a control run
through `low-async` would differ by node count as well -- worth 1.348 to 2.718
decode tok/s by this tree's own measurement, larger than the effect E5 exists to
resolve.

## Falsifiers, registered ahead of any run

The order is the order a failure stops the chain, and each one names what is
measured rather than what is hoped.

1. **ISA, E5-S1.** The executed gfx902 ACO ISA for
   `mul_mat_vec_q4_k_q8_1_f32_subgroup_no_shmem` holds other than four
   byte-extract-folded 24-bit multiplies plus two `v_add3_u32` per dot, or holds
   `v_mul_lo_u32` in the inner loop. The mechanism is refuted at the compiler and
   no device time is spent on the rung. The workstation has measured this through
   a drm-shimmed RAVEN2 node; the appliance's own ACO answering differently is
   what this falsifier is still open against.
2. **Combined envelope.** Activation quantization and the integer Q4_K consumer
   are measured as one graph envelope -- `quantize_q8_1_x4` beside
   `mul_mat_vec_q4_k_q8_1_f32` -- against the best E4-plus-scale-word-select
   candidate on the FP16 path. A q8_1 route whose consumer shortens while its
   producer eats the gain is refuted here, and correctness and served arms run
   only if the combined envelope is shorter. Reading the consumer alone is the
   error this gate exists to prevent.
3. **Correctness.** The margin witness reads `differs` under
   `QWEN_WITNESS_CONTRACT=margin`. This measures q8_1 activation quantization,
   which the design accepted in advance as a numeric change, so the registered
   contract decides rather than token identity. E5-M's own arithmetic is exact
   against `dotPacked4x8EXT` by construction and contributes nothing here.
4. **Whole token.** The served comparison under the scoreboard tuple leaves the
   2B's 5% one-sided promotion bound unmet.

Two standing cautions are registered as non-falsifiers, so a result that meets
either is read as predicted rather than as a defect:

```text
chain depth        E5-S1's longest dependent-VALU chain is 24 against E5-S0's
                   23 across identical 54 blocks. Trading an add tree for two
                   serially dependent v_add3_u32 reductions removes one
                   instruction and adds one to the longest path, so a bracket
                   that fails to shorten while VALU falls 2.3% refutes nothing
                   on its own.
VALU per MAC       int8 through a software dot costs about 1.375 VALU per MAC
                   where FP16 dot2 with FP32 accumulation through
                   v_mad_mix_f32 costs about 1.0. Every q8_1 path here must
                   therefore win on bracket time rather than on instruction
                   count, and the instruction tables above decide the ordering
                   among the three paths and nothing about the FP16 anchor.
```

## The compiler plan, and the file that carries each step

The appliance's distribution shaderc prints `GL_EXT_integer_dot_product not
supported by glslc`
(`evidence/web-admission-router-tools/build-raven2-vulkan-production.log:33`), so
that host emits no `OpSDotKHR` at all. The gate sits in the SPIR-V producer, and
the driver on the appliance consumes whatever module it is handed, so the plan
separates producing the module from executing it. Each step names the file that
carries it; none of them has run.

1. **Pin the producer.** `remote/shaderc-toolchain.tsv` states the project, the
   revision, the release archive, and its SHA-256. It ships with `revision`,
   `archive_url`, and `archive_sha256` reading `-`, because a digest recalled
   rather than read from the publisher is a fabricated pin, and
   `remote/fetch-shaderc-toolchain.sh` refuses an unfilled row rather than
   downloading whatever the tag points at today. Filling those three fields from
   the upstream release is step one.
2. **Build it into a prefix of its own.**
   `remote/fetch-shaderc-toolchain.sh [PREFIX_ROOT]` verifies the archive against
   the pin, syncs shaderc's own vendored glslang and SPIRV-Tools revisions,
   installs under `PREFIX_ROOT/shaderc-pinned`, refuses a prefix that already
   exists, and compiles a one-line probe that requires the extension, so the
   fetch proves the installed compiler accepts what the pack exists to reach.
   The system toolchain is untouched.
3. **Generate the pack.**
   `remote/build-spirv-shader-pack.sh DECLARATION SOURCE_DIRECTORY OUTPUT` reads
   one declaration row per module -- module name, source relative to the source
   directory, and its define list -- and writes `modules/<spirv_sha256>.spv`
   with a named symbolic link beside it, so two declarations compiling to one
   module store one file. `shader-pack.tsv` carries the module name, the
   relative source and its digest, the defines, the target environment, the
   recorded command line, the module's byte count and digest, and the `spirv-val`
   verdict; `pack-inputs.tsv` carries the compiler's own version string and
   digest, the validator's, the declaration digest, and one digest over the
   ledger. No absolute path enters either file: the compiler is recorded as
   `glslc` and every source relative, so a pack record is comparable between
   hosts and commits clean. A validator that is absent leaves
   `not_run:validator_absent` rather than an empty verdict, and one that refuses
   a module ends the pack. `remote/test-build-spirv-shader-pack.sh` drives the
   whole format against a fake `glslc` and a fake `spirv-val`, with no toolchain
   and no device.
4. **Deploy the isolated driver.** E5-S1 reaches the device through
   `radeon_devenv_icd.x86_64.json`, a meson target whose `library_path` names the
   build directory, so `VK_ICD_FILENAMES` and the library path select it and
   nothing is installed over the system driver. `radv-low-priority-env.sh` reads
   `QWEN_RADV_ICD`, which is the one name that selects it, and the appliance's
   own `vulkan-radeon` keeps serving everything else. `-Dllvm=enabled` is
   required for the disassembler rather than for ACO: without it RADV falls back
   to printing pre-RA IR that the lab's mnemonic counter reads as zero in every
   field, which is a silently worthless receipt.
5. **Read the executed ISA.** `RADV_DEBUG=shaders,shaderstats` through
   `remote/dump-radv-shader-isa.sh`, summarized by
   `remote/summarize-radv-isa.py`, against the module the census instrument
   dumped under its own digest. Falsifier 1 is decided here.
6. **Run a short kernel-delta arm, only on a matching ISA.** Where the ISA holds
   the six-operation sequence, `QWEN_CENSUS_AB_MODE=kernel-delta` over the
   subject and the untouched null pipeline; where it does not, the rung ends and
   the device time is not spent.
7. **Measure the combined envelope.** `quantize_q8_1_x4` and
   `mul_mat_vec_q4_k_q8_1_f32` read as one graph envelope against the best
   E4-plus-scale-word-select candidate. Falsifier 2 is decided here.
8. **Run correctness and the served comparison, only if that envelope is
   shorter.** `remote/run-kernel-delta-witness.sh` under
   `QWEN_WITNESS_CONTRACT=margin`, then `run-served-binary-ab.sh` in `served`
   mode with `QWEN_AB_CANDIDATE_FORCE_INTEGER_DOT=1` under the scoreboard tuple.
   Falsifiers 3 and 4 are decided here.

## Stage status

| stage | state | where |
| --- | --- | --- |
| patch series replay, whole candidate stage | measured | `verify-llama-patch-series.sh`, workstation |
| capability split, four define combinations | measured | workstation, type-check only |
| shader compile matrix | measured | `compile-matrix.tsv`, workstation |
| SPIR-V receipt, both branches | measured | `spirv/`, workstation |
| arithmetic equivalence, E5-M | measured | `int24-equivalence.c`, workstation |
| E5-M ISA, three toolchains, one hash | measured | `E5-M/` |
| E5-S0 ISA, package and from-source drivers | measured | `E5-S0/` |
| E5-S1 ISA, target-aware lowering | measured | `E5-S1/` |
| served arm carries the admission | measured | `test-run-served-binary-ab.sh`, workstation |
| shader pack format and refusals | measured | `test-build-spirv-shader-pack.sh`, fake toolchain |
| producer pinned and fetched | unrun | step 1 and 2 above |
| pack generated from the real shaders | unrun | step 3 above |
| isolated ICD on the appliance | unrun | step 4 above |
| executed ACO ISA on the appliance | unrun | step 5, falsifier 1 |
| kernel-delta bracket | unrun | step 6 |
| combined envelope | unrun | step 7, falsifier 2 |
| margin witness and served rate | unrun | step 8, falsifiers 3 and 4 |
