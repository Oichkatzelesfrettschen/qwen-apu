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
the replacement q8_1 mat-vec pipelines and their two `quantize_y` dispatches
read. Every advertised Vulkan acceleration property reads exactly what RADV
reported under every arm.

The selection is scoped to the path the replacement exists for. The MMQ mat-mat
families, the mat-mat `quantize_y`, and `ggml_vk_fa_scalar_uses_mmq` read
`integer_dot_accelerated` instead, so a forced admission reaches the mat-vec and
stops there whichever toolchain compiled the build. Without that scope an
extension-capable E5-S build would have carried three dispatch families the lane
measured no replacement for, and a bracket read across E5-M and E5-S would have
compared different dispatch sets. E5-S0 against E5-S1 shares the whole set
regardless and differs by the driver alone, which is why that pair is read
first.

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

## The original falsifier, honored: E5-M is refuted on its own terms

The lane's first registration named falsifier 1 as: the candidate pipeline holds
`v_mul_lo_u32` **or** `v_cvt_f32_f16` in its inner loop, and the hypothesis is
refuted at the compiler. `instruction-census.tsv` reads `v_cvt_f32_f16` at 56 in
the E5-M module. That clause is met, so E5-M is refuted as a hypothesis on the
terms it registered, and this lane records it that way rather than arguing the
count into a pass. It keeps its place as the negative control, which is a role a
refuted arm can hold, and two independent results agree with the verdict: the
extension form of the same shader compiles to 318 fewer VALU instructions, and
the multiply-add fold E5-M's design predicted never forms.

The corrected byte-select reading is the sharpest of the three, and it also
cuts against E5-M. Of its 224 `v_mul_u32_u24_sdwa` products, 168 fold a byte
select into both operands and 56 read a whole DWORD on `src0`, where E5-S0 and
E5-S1 fold a byte select on both sources in all 224. The manual expansion
therefore reaches the encoding it was written for on three quarters of its
products and the compiler's own lowering reaches it on all of them. The earlier
claim that all 224 were byte-selected on both sources is withdrawn.

## The new hypothesis, registered before any further measurement

The clause that refutes E5-M cannot be carried into E5-S0 and E5-S1 unchanged,
because it discriminates nothing there. `instruction-census.tsv` reads
`v_cvt_f32_f16` at 56 in all three q8_1 modules against 16 in the FP16
production anchor, so the count reports the q8_1 scale decode the whole family
shares rather than any path's own arithmetic. A falsifier that refutes every arm
including both hypotheses measures the family, and it is replaced here rather
than reinterpreted where it was written.

```text
hypothesis   The Q4_K x Q8_1 mat-vec reached through GL_EXT_integer_dot_product
             and lowered by the driver -- generically in E5-S0, by merge request
             2115's six-operation sequence in E5-S1 -- executes the Q4_K trunk in
             a shorter combined graph envelope than the FP16 dequantize path,
             where the envelope is the activation quantizer and its consumer read
             together.
scope        the q8_1 mat-vec family alone. The forced admission writes
             integer_dot_software_lowered and the MMQ mat-mat and
             flash-attention families read integer_dot_accelerated, so those
             stay on the production shape under both hypothesis paths.
withheld     nothing about the FP16 anchor follows from the instruction tables.
             int8 through a software dot costs about 1.375 VALU per MAC where
             FP16 dot2 with FP32 accumulation costs about 1.0, so the tables
             order the three q8_1 paths against each other and decide nothing
             against F0.
```

## Falsifiers, registered ahead of any run

The order is the order a failure stops the chain, and each one names what is
measured rather than what is hoped.

1. **Pipeline creation.** The armed build creates no `mul_mat_vec_q4_k_q8_1_f32`
   pipeline, or creates one for a family the scope excludes. Read from the
   census instrument's own module dump and the info line's four states, before
   any rate is taken.
2. **Executed ISA.** The executed gfx902 ACO ISA holds other than four
   byte-extract-folded 24-bit multiplies plus two `v_add3_u32` per dot, or holds
   `v_mul_lo_u32` in the inner loop. The mechanism is refuted at the compiler
   and no further device time is spent. The workstation has measured this
   through a drm-shimmed RAVEN2 node; the appliance's own ACO answering
   differently is what the falsifier is open against.
3. **Exact arithmetic.** The armed and unarmed binaries disagree on the Q4_K
   dot over the operand domain the test drives. E5-M's own form is exact against
   `dotPacked4x8EXT` by construction and `int24-equivalence.c` has measured it;
   the E5-S paths compute the extension's own operation, so this arm tests the
   driver's lowering rather than a rewrite.
4. **Top-k margin witness.** The witness reads `differs` under
   `QWEN_WITNESS_CONTRACT=margin`. This measures q8_1 activation quantization,
   which the design accepted in advance as a numeric change, so the registered
   contract decides rather than token identity. The arm reaches the witness only
   because `QWEN_WITNESS_CANDIDATE_FORCE_INTEGER_DOT=1` carries the selection
   into that harness's closed environment; without it the witness compares one
   shader against itself.
5. **Kernel-delta bracket.** The exclusive GPU bracket of
   `mul_mat_vec_q4_k_q8_1_f32` measured against the untouched null pipeline
   reads `bracket-unchanged` or `lengthened`.
6. **Whole-graph envelope.** `quantize_q8_1_x4` and its consumer read as one
   envelope against the best E4-plus-scale-word-select candidate on the FP16
   path. A route whose consumer shortens while its producer eats the gain is
   refuted here. Reading the consumer alone is the error this gate exists to
   prevent.
7. **Served A/B, only if locally faster.** The served comparison under the
   scoreboard tuple runs only where the envelope above is shorter, and it leaves
   the 2B's 5% one-sided promotion bound unmet.

That order is the device ladder: pipeline creation, executed ISA, the exact
arithmetic test, the top-k margin witness, the kernel-delta bracket, the
whole-graph envelope, and the served A/B last and conditional. Each rung costs
more device time than the one above it and each answers a question the next one
would otherwise attribute wrongly.

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

## The instruction census, and why it is analysis rather than a re-run

`instruction-census.tsv` carries every retained arm under one schema.
`remote/raven2-shader-lab/recount-isa.sh` derives it from the `isa.s` each run
retained, because `lab.sh` gained its `v_mul_i32_i24` and `v_add3_u32` fields
after four of these arms were measured and two of the drivers that produced them
are no longer installed. The measurement head and the analysis head are separate
here by the repository's own rule: the listing is what the run produced and
every count is a reader over it, so a field added later reaches every arm ever
retained. The two byte-select columns have no receipt field at all and exist
because the arm's mechanism is a claim about operand encoding rather than about
opcode choice. `remote/raven2-shader-lab/test-recount-isa.sh` drives the reader
against a fixture whose every count the fixture states.

Every listing whose digest this lane cites is retained. The two E5-M arms across
merge request 2115 kept a receipt and no listing, so each carries the file its
own recorded digest names beside an `isa-provenance.txt` stating that it was
carried in rather than retained by that run.
## The compiler plan, and the file that carries each step

The appliance's distribution shaderc prints `GL_EXT_integer_dot_product not
supported by glslc`
(`evidence/web-admission-router-tools/build-raven2-vulkan-production.log:33`), so
that host emits no packed integer dot at all. The gate sits in the SPIR-V
producer, and the driver on the appliance consumes whatever module it is handed,
so the plan separates producing the module from executing it. Each step names
the file that carries it, and the first three have run on the workstation.

1. **Pin the producer.** `remote/shaderc-toolchain.tsv` states the project, the
   revision, the release archive, and its SHA-256. It names `google/shaderc` at
   `v2026.3` against `ee493ccf1b30...`, measured over the download rather than
   recalled, and `remote/fetch-shaderc-toolchain.sh` refuses an unfilled row
   rather than downloading whatever the tag points at today. The tag is chosen
   by what it reproduces: its glslc writes the exact module every retained E5-S
   receipt names.
2. **Build it into a prefix of its own.**
   `remote/fetch-shaderc-toolchain.sh [PREFIX_ROOT]` verifies the archive against
   the pin, syncs shaderc's own vendored glslang and SPIRV-Tools revisions,
   installs under `PREFIX_ROOT/` in the ledger's own `prefix` directory, refuses
   a prefix that already exists, and compiles a one-line probe that requires the
   extension, so the fetch proves the installed compiler accepts what the pack
   exists to reach. The system toolchain is untouched.
3. **Generate the pack.**
   `remote/build-spirv-shader-pack.sh DECLARATION SOURCE_DIRECTORY OUTPUT` reads
   one declaration row per module -- module name, source relative to the source
   directory, and its define list -- and writes `modules/<spirv_sha256>.spv`
   with a named symbolic link beside it, so two declarations compiling to one
   module store one file. `shader-pack.tsv` carries the module name, the
   relative source and its digest, the defines, the target environment, the
   recorded command line, the module's byte count and digest, and the `spirv-val`
   verdict; `pack-inputs.tsv` carries the compiler's own version string and
   digest, the validator's, the declaration digest, the optimization setting,
   and one digest over the ledger. `QWEN_SHADER_PACK_OPTIMIZE=1` adds the `-O`
   that `vulkan-shaders-gen.cpp:352` compiles every ggml shader with, which is
   what separates the 36940-byte served module from the 21312-byte unoptimized
   form of the same source and defines. No absolute path enters either file: the compiler is recorded as
   `glslc` and every source relative, so a pack record is comparable between
   hosts and commits clean. A validator that is absent leaves
   `not_run:validator_absent` rather than an empty verdict, and one that refuses
   a module ends the pack. `remote/test-build-spirv-shader-pack.sh` drives the
   whole format against a fake `glslc` and a fake `spirv-val`, with no toolchain
   and no device.
4. **Deploy the isolated driver.** `remote/build-isolated-radv.sh SOURCE [PREFIX_ROOT]`
   builds it. E5-S1 reaches the device through
   `radeon_devenv_icd.x86_64.json`, a meson target whose `library_path` names the
   build directory, so `VK_ICD_FILENAMES` and the library path select it and
   nothing is installed over the system driver. `radv-low-priority-env.sh` reads
   `QWEN_RADV_ICD`, which is the one name that selects it, and the appliance's
   own `vulkan-radeon` keeps serving everything else. `-Dllvm=enabled` is
   required for the disassembler rather than for ACO: without it RADV falls back
   to printing pre-RA IR that the lab's mnemonic counter reads as zero in every
   field, which is a silently worthless receipt. The script requires the
   checkout's HEAD to equal the pinned revision and that revision to descend
   from `f1078c57e5f02b611f2c69af9ac7e0f5aa82a0bb`, since a driver without that
   merge lowers `nir_op_sdot_4x8_iadd` generically and would measure E5-S0 under
   E5-S1's name; it writes an environment fragment naming `QWEN_RADV_ICD`,
   `QWEN_AMDGPU_DRM_SHIM`, and the library path, and
   `remote/test-build-isolated-radv.sh` drives every refusal against fake meson,
   ninja, and git.
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
| producer pinned and fetched | measured | `E5-S0/shader-pack/`, workstation |
| pack generated from the real shaders | measured | `E5-S0/shader-pack/`, module digest matches every E5-S receipt |
| isolated driver build and its handoff | designed, tested against fake tools | `remote/build-isolated-radv.sh` |
| isolated ICD on the appliance | unrun | step 4 above |
| executed ACO ISA on the appliance | unrun | step 5, falsifier 1 |
| kernel-delta bracket | unrun | step 6 |
| combined envelope | unrun | step 7, falsifier 2 |
| margin witness and served rate | unrun | step 8, falsifiers 3 and 4 |
