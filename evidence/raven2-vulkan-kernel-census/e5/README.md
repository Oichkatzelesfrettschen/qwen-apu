# E5-int24: falsifiers, arms, and what the workstation could already answer

`int24-design.md` beside this file is the registration, verbatim from before a
line of shader existed. This file states the arm the design became, the
commands the appliance runs, and the four falsifiers in the order a failure
stops the chain. `patches/llama-vulkan-q4k-int24-mmvq.patch` is the subject and
`remote/llama-patch-series.tsv` carries it at the `candidate` stage.

## Two claims, kept apart

The arm changes two things at once and the evidence separates them, because a
witness result attributed to the wrong half reads as a shader defect.

```text
claim A   int24 against dotPacked4x8EXT, same operands
          exact by construction: repack4 masks Q4_K quant bytes with
          0x0F0F0F0F and Q5_K merges one bit above that, so the signed dot
          equals the unsigned one, the bias correction is algebraic, and the
          FP32 tail is byte-identical to the pinned function
claim B   q8_1 activations against the FP16 mat-vec
          the numeric movement the design's second falsifier anticipates,
          which the pinned upstream path owns and the int24 shader contributes
          nothing to
```

The margin witness measures claim B. A `differs` verdict is read against the
registered contract rather than against token identity, and it says nothing
about the replacement arithmetic unless claim A's runtime equality arm also
moves.

## What the arm can reach

`ggml_vk_should_use_mmvq` returns false on AMD below `k = 2048` and false for
Q6_K on every vendor but Intel, so the 2B distill's Q4_K trunk is the family
this arm touches and its 50.08% Q6_K by byte stays on the FP16 path. The
whole-token ceiling is that share rather than the 83% the FP16 family holds.
`GGML_VK_FORCE_MMVQ=1` would extend the path to Q6_K and moves two things at
once, so it belongs to a separate arm.

The mat-mat and flash-attention q8_1 shaders keep the extension's own compile
gate. Where they are absent, `ggml_vk_get_mul_mat_mat_pipeline` finds an empty
pipeline set and clears `quantize_y`, so prefill and attention run the
production shape and the mat-vec is the single changed dispatch.

## The control is the same binary

`GGML_VK_FORCE_INTEGER_DOT=1` admits the pipelines and its absence leaves
`integer_dot_product` false on RAVEN2, so no q8_1 pipeline is created and
dispatch takes the production FP16 mat-vec. One build therefore carries the arm
and its control, and the code-layout difference `P I0 I0 P` exists to separate
is absent by construction. The residual difference is the unused q8_1 SPIR-V
linked into the binary and the pipeline table entries that name it.
`remote/radv-low-priority-env.sh` scrubs the variable under all four serving
profiles, `custom` among them, and restores it under `diagnostic` alone, so an
arm is asked for explicitly and a promoted build stays on the FP16 mat-vec
whatever the ambient environment holds. `remote/dump-radv-shader-isa.sh` runs
the `low-async` serving profile, so it forwards the caller's own value past
that scrub on the same `env` that reintroduces `RADV_DEBUG`, conditionally:
the two arms of the ISA receipt share one server argv and differ in that
assignment, and its completion line names the arm it collected.

## The appliance chain

```sh
# The candidate serving tree and its binary. build-llama-preset.sh adds
# -DGGML_VULKAN_INT24_DOT=ON exactly when the selection names the patch.
remote/prepare-llama-census-source.sh ~/src/llama.cpp ~/src/llama.cpp-int24 \
    llama-vulkan-q4k-int24-mmvq.patch
QWEN_LLAMA_CANDIDATE_SELECT=llama-vulkan-q4k-int24-mmvq.patch \
    remote/build-llama-preset.sh raven2-vulkan-production ~/src/llama.cpp-int24

# Falsifier 1, the ISA receipt: the candidate binary under
# RADV_DEBUG=shaders,shaderstats, once with the arm armed and once without.
GGML_VK_FORCE_INTEGER_DOT=1 remote/dump-radv-shader-isa.sh \
    ~/qwen-evidence/e5-isa-int24 BUILD/bin/llama-server MODEL_PATH
remote/dump-radv-shader-isa.sh \
    ~/qwen-evidence/e5-isa-control BUILD/bin/llama-server MODEL_PATH
remote/summarize-radv-isa.py ~/qwen-evidence/e5-isa-int24/radv-shaders.log

# Falsifier 3, the bracket: two census-instrumented builds differing by this
# patch alone, judged on the exclusive GPU bracket of the Q4_K mat-vec against
# a pipeline the patch leaves untouched.
remote/prepare-llama-census-source.sh ~/src/llama.cpp ~/src/llama.cpp-census-int24 \
    llama-vulkan-pipeline-census.patch llama-vulkan-q4k-int24-mmvq.patch
QWEN_LLAMA_CANDIDATE_SELECT='llama-vulkan-pipeline-census.patch llama-vulkan-q4k-int24-mmvq.patch' \
    remote/build-llama-preset.sh raven2-vulkan-census ~/src/llama.cpp-census-int24
QWEN_CENSUS_AB_MODE=kernel-delta \
QWEN_AB_CANDIDATE_PATCH=llama-vulkan-q4k-int24-mmvq.patch \
QWEN_AB_BRACKET_SUBJECT=mul_mat_vec_q4_k_q8_1_f32 \
QWEN_AB_BRACKET_NULL=mul_mat_vec_q6_k_f32_f32 \
QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual \
    remote/run-served-binary-ab.sh CENSUS_CONTROL_SERVER CENSUS_INT24_SERVER \
    qwen38-2b-distill ~/qwen-evidence/e5-kernel-delta

# Falsifier 2, the margin witness, over the same pair.
QWEN_WITNESS_CONTRACT=margin QWEN_WITNESS_N_PROBS=2 \
    remote/run-kernel-delta-witness.sh CONTROL_SERVER INT24_SERVER \
    qwen38-2b-distill ~/qwen-evidence/e5-witness

# Falsifier 4, the whole token, under the scoreboard tuple.
QWEN_CENSUS_AB_MODE=served \
QWEN_AB_CANDIDATE_PATCH=llama-vulkan-q4k-int24-mmvq.patch \
QWEN_CENSUS_PRODUCTION_RECEIPT=evidence/fixed64-served-campaign/20260901T2011Z/identity-check.tsv \
    remote/run-served-binary-ab.sh CONTROL_SERVER INT24_SERVER \
    qwen38-2b-distill ~/qwen-evidence/e5-served
```

`dump-radv-shader-isa.sh`, `run-served-binary-ab.sh`,
`run-kernel-delta-witness.sh`, `summarize-radv-isa.py`,
`summarize-bracket-ab.py`, and `summarize-census-controls.py` are the census
bracket harness. They reach the appliance with the runtime tree the campaign
syncs, and each refuses to run anywhere but the measured host, so every command
above states a precondition for the run rather than a step this workstation
took.

Both `run-served-binary-ab.sh` modes require the two binaries to share one base
build identity and to differ by exactly the named candidate. The int24
candidate meets that as the whole difference, since the CMake option travels
with the patch.

## Falsifiers, in the order a failure stops the chain

1. ISA. The candidate `mul_mat_vec_q4_k_q8_1_f32` pipeline holds
   `v_mul_lo_u32` or `v_cvt_f32_f16` in its inner loop, or fewer
   `v_mad_u32_u24` and `v_mul_u32_u24` than sixteen products per call predict.
   The hypothesis is refuted at the compiler before device time is spent, and
   the receipt names ACO's selection rather than the shader's intent.
   `isa-shimmed-raven2/` answers this without the appliance, and the answer is
   split three ways: `v_mul_lo_u32` is absent while all 224 products land on
   `v_mul_u32_u24` with SDWA byte selects, `v_mad_u32_u24` is absent because
   the byte select occupies the VOP2 encoding the VOP3 multiply-add cannot
   share, and `v_cvt_f32_f16` stands at 56 -- the same count, in the same
   places, as the `dotPacked4x8EXT` build of the same shader, so it reports the
   q8_1 scale decode rather than the replacement.
2. Correctness. The margin witness reads `differs` under
   `QWEN_WITNESS_CONTRACT=margin`. This is claim B: q8_1 activation
   quantization is a numeric change the design accepted in advance, so the
   registered contract decides rather than token identity.
3. Bracket. The kernel-delta comparison reads `bracket-unchanged` or
   `lengthened` on `mul_mat_vec_q4_k_q8_1_f32` measured against the untouched
   null pipeline, or the `quantize_q8_1_x4` producer eats the mat-vec's gain
   when the two are read as one envelope.
4. Whole token. The served comparison under the scoreboard tuple leaves the
   2B's 5% promotion bound unmet, which is the rule that decides whether the
   arm is kept.

## What ran on the workstation

```text
patch series        verify-llama-patch-series.sh replays the eight production
                    members and all three candidates in ledger order:
                    candidate_patch=llama-vulkan-q4k-int24-mmvq.patch applies=yes
shader compile      compile-matrix.tsv, thirteen quantizations x two branches of
                    GGML_VK_INT24_DOT, glslc 2026.3 / SPIR-V 1.4.357.0, all ok
SPIR-V receipt      spirv/, the Q4_K q8_1 mat-vec disassembled on both branches
                    with spirv-val passing on all six modules
arithmetic          int24-equivalence.c, both forms against the signed reference:
                    exact over the whole single-lane domain, four million random
                    word pairs for the general form, two million random calls for
                    the Q4_K and Q5_K form over quant bytes 0 to 31
backend compile     ggml-vulkan.cpp parses and type-checks under all four
                    combinations of GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT and
                    GGML_VULKAN_INT24_DOT, and vulkan-shaders-gen.cpp compiles
                    under the same four at -Wall -Wextra
environment         test-radv-low-priority-env.sh gains seven
                    GGML_VK_FORCE_INTEGER_DOT arms -- one per serving profile,
                    the diagnostic profile armed and unarmed, and the
                    diagnostic profile refusing a value other than 1 -- beside
                    a structural check that the ISA collector still forwards
                    the value past the scrub and an executed check that the
                    collector refuses that same third value. The wrapper
                    refuses this workstation for want of a RADV ICD, so the
                    arms ran against a stand-in ICD and answered unset four
                    times, then 1, unset, and exit 2
ACO ISA receipt     isa-shimmed-raven2/, the int24 module, its dotPacked4x8EXT
                    counterpart, and the pinned Q4_K and Q6_K mat-vecs compiled
                    through RADV on a drm-shimmed RAVEN2 node; the two pinned
                    arms hash to the appliance's own ad837848 and 0d5c7643, so
                    this host's ACO answers the appliance's on the mat-vec
                    family. Both anchors take the FP16 path, so the integer-dot
                    lowering the arm rests on is outside the matched set
```

`spirv-summary.tsv` carries the compile receipt. The extension branch holds
four `OpSDot`, the `DotProduct` capability, and the `SPV_KHR_integer_dot_product`
extension; the int24 branch holds none of the three and reaches 46 `OpIMul`
against 30, which is the sixteen products the design predicts, on all three
workgroup variants. Both branches hold 73 `OpAccessChain` and zero
`OpVectorExtractDynamic`, so the replacement indexes the quant vector
statically and asks ACO for sixteen multiplies of constant-masked bytes. These
are SPIR-V operations at glslc's default optimization: they state which
arithmetic the module asks for and count no VALU instruction, which is what
falsifier 1 measures.

## The ISA receipt, and what it says about the arm

`isa-shimmed-raven2/README.md` carries the whole reading; three results decide
what the remaining device stages are worth spending time on.

The 24-bit multiplier is reached exactly as designed: 224 products, every one
`v_mul_u32_u24_sdwa` with `src0_sel`/`src1_sel` byte selects, and zero
`v_mul_lo_u32`.

The multiply-add fold the design predicted does not happen, and neither arm
loses by it. Both q8_1 arms emit zero `v_mad_u32_u24` and accumulate through
`v_add3_u32`; SDWA rides VOP1 and VOP2 on GFX9 while `v_mad_u32_u24` is VOP3,
so ACO takes the byte select and cannot also take the fold.

`dotPacked4x8EXT` reaches the same multiplier family on this part. The
extension build of the same shader compiles to 224 `v_mul_i32_i24_sdwa` in
1328 VALU against the rewrite's 1646, so the rewrite costs 318 VALU and 2208
bytes of code at identical registers. That is the price of the appliance's own
toolchain rather than of the arithmetic:
`evidence/web-admission-router-tools/build-raven2-vulkan-production.log:33`
records the appliance's build printing `GL_EXT_integer_dot_product not
supported by glslc` under Vulkan 1.3.275, so the extension form compiles
nowhere on that host and the rewrite is the only route to a `_q8_1` pipeline
there. The measurement opens a route the ladder never registered: a glslc that
accepts the extension, or SPIR-V compiled elsewhere and shipped, reaches the
24-bit multiplier in 318 fewer VALU instructions on the same silicon. No arm
has costed it.

## Stage status

| stage | state | where |
| --- | --- | --- |
| patch series replay | measured | `verify-llama-patch-series.sh`, workstation |
| shader compile matrix | measured | `compile-matrix.tsv`, workstation |
| SPIR-V receipt | measured | `spirv/`, workstation |
| arithmetic equivalence | measured | `int24-equivalence.c`, workstation |
| backend compile | measured | workstation |
| falsifier 1, ACO ISA | measured | `isa-shimmed-raven2/`, shimmed RAVEN2 on the workstation |
| appliance build produces this module | unrun | the appliance's own glslc, see below |
| runtime equality, claim A | unrun | appliance |
| falsifier 2, margin witness | unrun | appliance |
| falsifier 3, kernel-delta bracket | unrun | appliance |
| falsifier 4, whole token | unrun | appliance |

Falsifier 1's ISA question is answered and one identity question behind it is
not. The receipt compiled `mul_mat_vecq.comp` with glslc 2026.3, and the
appliance compiles it with the shaderc its distribution ships. Those two
toolchains produced different SPIR-V for the pinned `mul_mat_vec_q4_k_f32_f32`
and ACO emitted one identical instruction stream from both, which is the
anchor `identity-anchor.tsv` records; whether the same holds for the int24
module is a one-command check on the appliance rather than an inference:

```sh
# On the appliance, after the candidate build. The census instrument writes the
# executed module under its own digest, and the lab compiles that module.
GGML_VK_FORCE_INTEGER_DOT=1 GGML_VK_PIPELINE_CENSUS_DUMP=$HOME/e5-modules \
    BUILD/bin/llama-server --model MODEL_PATH ...   # one request, then teardown
remote/raven2-shader-lab/lab.sh $HOME/e5-modules/DIGEST.spv $HOME/e5-isa-int24 \
    --spec 0:64 --spec 1:1 --spec 2:1 --subgroup 64 \
    --bindings 5 --push-constants 52 --per-superblock 256
```

An `isa_sha256` equal to
`8896269f54c86f1039a08740aaa1f1f3fdbef6080f8d9e7a1908ce84e2598f34` closes the
identity outright. A different value makes the appliance's own receipt the
authority and this one a compiler study.

## The served A/B reaches no int24 arm, and the profile scrub is why

The device window that measured the q4k scale-decode candidates
(`../q4k-scale-decode/README.md`) left this candidate **unmeasured**, on a
mechanism in this tree rather than on time or on the toolchain.

`ggml_vk_force_integer_dot()` is the admission. `ggml-vulkan.cpp` reads
`integerDotProduct4x8BitPackedSignedAccelerated || ggml_vk_force_integer_dot()`
and RADV reports that property false on RAVEN2, so a build carrying
`-DGGML_VULKAN_INT24_DOT=ON` executes the production FP16 mat-vec until
`GGML_VK_FORCE_INTEGER_DOT=1` reaches the server's environment.

`radv-low-priority-env.sh` restores that variable past its scrub under the
`diagnostic` profile alone, which is this branch's own design: the four serving
profiles leave it scrubbed so a promoted build stays on the FP16 mat-vec
whatever the ambient environment holds. `run-served-binary-ab.sh` passes
`low-async` to every arm it launches. An int24 candidate and its control would
therefore execute one shader, and the harness would report the difference
between two runs of the same code. The comparison is not refused; it completes
and reports zero, which is the worse of the two failures.

The binding above it agrees rather than offering a way around. The served A/B
requires the control to be the one accepted server row of the fixed-64
scoreboard receipt and requires that receipt's `campaign-inputs.tsv` to state
every setting the arms rerun under, and that file reads
`vulkan_profile low-async`. A diagnostic-profile arm refuses at the receipt
binding, so the profile is fixed inside this harness rather than chosen by a
caller.

The appliance glslc is a separate question and it is settled in the arm's
favor. `mul_mat_vecq.comp` requires `GL_EXT_integer_dot_product` under the
opposite branch of `GGML_VULKAN_MMVQ_Q8_1_SHADERS`, so shaderc 2023.8 compiles
the int24 module and the appliance builds this candidate. The admission is what
is absent, not the binary.

What measures it is an arm-level admission the serving profiles are written to
withhold: a serving profile that exports `GGML_VK_FORCE_INTEGER_DOT=1` and is
otherwise `low-async`, carried by a scoreboard receipt of its own, so the
control and the candidate differ by the shader rather than by the profile. That
is a change to the profile ledger and to the receipt binding together, and it
is registered here as the next rung rather than made underneath a measurement.

## Not run

```text
runtime equality        claim A is exact by construction and unmeasured on the
                        device: the arm and its control answering one prompt
                        bit-for-bit is what turns it into a measurement.
falsifier 4             blocked by the profile scrub above rather than by
                        device availability. The served A/B admits the binary
                        and runs the control's shader inside it.
falsifiers 2 and 3      run-kernel-delta-witness.sh and the kernel-delta
                        bracket pass the same serving profile, so each reaches
                        the arm only behind the same admission.
appliance module        the isa_sha256 comparison under "The appliance chain"
identity                reads the census instrument's module dump, which the
                        bundle layer refuses on a serving build.
```
