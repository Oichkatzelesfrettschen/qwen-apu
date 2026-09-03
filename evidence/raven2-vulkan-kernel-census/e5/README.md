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
`remote/radv-low-priority-env.sh` scrubs the variable under every serving
profile and restores it under `custom` alone, so an arm is asked for
explicitly.

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
environment         test-radv-low-priority-env.sh gains the three
                    GGML_VK_FORCE_INTEGER_DOT arms; the wrapper refuses this
                    workstation for want of a RADV ICD, so the three arms ran
                    against a stand-in ICD and answered unset, 1, unset
```

`spirv-summary.tsv` carries the compile receipt. The extension branch holds
four `OpSDot`, the `DotProduct` capability, and the `SPV_KHR_integer_dot_product`
extension; the int24 branch holds none of the three and reaches 33 `OpIMul`
against 30. Those are SPIR-V operations at glslc's default optimization with
the sixteen products still inside a rolled loop, so they state which arithmetic
the module asks for and count no VALU instruction.

## Not run

```text
ACO ISA receipt         the workstation carries the NVIDIA ICD alone and no
                        libvulkan_radeon, so RADV_FORCE_FAMILY=raven2 with
                        RADV_DEBUG=shaderstats has no driver to run through.
                        Falsifier 1 stays open and the appliance answers it.
runtime equality        claim A is exact by construction and unmeasured on the
                        device: the arm and its control answering one prompt
                        bit-for-bit is what turns it into a measurement.
every device arm        falsifiers 2, 3, and 4 need the appliance, which serves
                        while this branch was written.
```
