# The two-column verification pass is unattributable from retained arms

`empero-ai/Qwen3.8-4B-Distill` Q4_K_M verifies `1+N` columns per speculative
step through the same GEMV pipeline it decodes one column with, so the cost of
the MTP head is a cost of `mul_mat_vec_q4_k` at a wider `NUM_COLS`. Two retained
bodies of evidence bear on it and they do not join: the speculation matrix
measures the pass at request granularity with speculation on, and the kernel
census measures the pipelines at dispatch granularity with speculation off. No
retained record carries both, so the exclusive-time delta of the verification
pass is bounded rather than attributed, and the arm that would attribute it is
registered below.

## Every retained census arm decodes one column

Two reads over the whole retained census answer which arms measure the head
verifying. Field 13 of every `campaign-inputs.tsv` under
`evidence/raven2-vulkan-kernel-census/` reads `speculation off`, across the ten
top-level campaigns and the `e4/`, `e5/`, and `q4k-scale-decode/` subtrees, and
every `launch.txt` records `spec_type=off`. The constants column of every
retained `pipeline-ledger-decode.tsv` and `pipeline-ledger-prefill.tsv` in that
tree holds exactly two distinct mat-vec rows:

```text
mul_mat_vec_q4_k_f32_f32	64,4,1
mul_mat_vec_q6_k_f32_f32	64,4,1
```

The triple is `{BLOCK_SIZE, NUM_ROWS, NUM_COLS}` -- subgroup 64, the K-quant
family's `2*rm_kq` of four rows, and one column. A two-column mat-vec dispatch
is absent from the retained population, so the census records nothing about the
pass this document is about, and the prefill ledgers are no substitute: a
multi-token prefill routes to the mat-mat family rather than to the GEMV at a
wider `NUM_COLS`.

## The one-column denominator, in the census's own vocabulary

`evidence/raven2-vulkan-kernel-census/q4k-scale-decode/4b-attribution-20260905/`
retains three accepted I1 arms (`18-I1`, `19-I1`, `23-I1`) on the 4B under the
composed Q4_K shader at `manual-gfx1100-fclk933`, over the 63 decode graphs of
one 64-token reply. The median arm reads:

| pipeline | bracket upper bound ms | exclusive ms | ambiguous overlap ms | overlap fraction | calls per graph | median us |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `mul_mat_vec_q4_k_f32_f32` | 10885.1 | 10712.0 | 118.6 | 0.011 | 216 | 744.2 |
| `mul_mat_vec_q6_k_f32_f32` | 5147.3 | 5136.6 | 10.7 | 0.002 | 33 | 1285.3 |

Both overlap fractions sit below the 0.05 the census reads `ownership=inconclusive`
above, so the shares are read as shares: the two mat-vec families own 15848.6 ms
of the 18788 ms decode span, 84.4%, and 2939 ms of the token sits outside them.
Per graph that is 170.0 ms of Q4_K and 81.5 ms of Q6_K against a 298.2 ms graph.

The same rows carry the occupancy state of the one-column pipeline, identical
across all three arms: `vgprs=48 sgprs=48 spilled_vgprs=0 lds=0 scratch=0
subgroups_per_simd=5` for the Q4_K pipeline at `64,4,1`, and `vgprs=64 lds=512
subgroups_per_simd=4` for the Q6_K pipeline.

## The pass cost, at request granularity, from a record that retains no raw

`evidence/mtp-speculation-matrix.md` measures the same checkpoint with the head
verifying and states its own retention limit: the checkout holds the synthesized
matrix and lacks the request bodies, response bodies, server logs, token arrays,
and clock samples of every MTP arm, so those figures support the algebra and
cannot be recomputed from the tree. Under that limit it reports a one-column
target pass of 323.4 ms, a two-column pass of 463.1 +/- 3.0 ms, and an MTP draft
pass of 66.4 +/- 0.3 ms, with the column series continuing 662, 783, 1319, and
1636 ms at three, four, five, and seven columns. The second column therefore adds
139.7 ms to a pass that streams the same 2.698 GB of weights either way.

## What the two records bound together, and what they cannot separate

The two figures come from different builds and different sweeps. The census arms
run the composed Q4_K shader whose served campaign measured +6.63% over the
production shader the matrix arms ran, and the census's 298.2 ms decode graph
sits 7.8% under the matrix's 323.4 ms one-column pass -- the right direction and
the right order, which makes the pair consistent rather than controlled. This
tree measures one checkpoint under identical flags spanning 30.6% between
sweeps, so no cross-record difference below that is read as an effect.

Within that limit the attribution is an interval whose width is the whole
quantity:

| quantity | value | basis |
| --- | ---: | --- |
| added by the second column, per pass | 139.7 ms | matrix, request granularity |
| mat-vec family share of the one-column token | 84.4% | census, exclusive brackets |
| added time attributable to the mat-vec families | 0 to 139.7 ms | unseparated |
| mat-vec exclusive per graph, if the whole delta lands there | 251.5 to 391.2 ms | +55.5% |

No retained record splits the 139.7 ms between the mat-vec families and the
2939 ms of per-token work outside them, because the only arms that carry a
per-pipeline split decode one column. The interval's lower end is zero rather
than a measured floor: attention, normalization, and the sampling path all grow
with the verified width too, and the retained data ranks none of them. The
census's own ambiguity terms bound the one-column arms alone and transfer to no
two-column reading.

One retained-data deviation belongs here rather than in the interval. The
matrix's occupancy account for the five-column cliff names "a drop from two waves
per SIMD to one", and the retained census reads `subgroups_per_simd=5` with 48
VGPRs and zero spills for the one-column Q4_K pipeline at four rows. A cliff at
the fifth column then requires crossing several occupancy steps rather than the
last one, or a mechanism other than the one named. The two readings are of
different shaders -- composed in the census, production in the matrix -- so the
deviation locates the question rather than settling it, and it is what the
registered mechanism below is stated against.

## The missing arm: `mtp-two-column-census`, device, after #55

- What it measures: the per-pipeline exclusive time of a verification pass at
  `NUM_COLS=2` on `qwen38-4b-distill`, against a one-column control taken in the
  same session.
- Shape: `QWEN_CENSUS_MODE=attribution` with `QWEN_CENSUS_CALIBRATION_RECEIPT`
  naming an accepted 4B calibration that bound the same two server digests, the
  census build reached through an explicit `QWEN_LLAMA_SERVER` since bundle
  assembly refuses an instrumented manifest, the single-model path since router
  mode refuses every speculation key, `QWEN_SPEC_TYPE=draft-mtp` with
  `QWEN_SPEC_DRAFT_N_MAX=1` to cap proposals at one; the observed target pass must establish its realized width, and a
  mirrored `C K K C` quadruple whose C arms run the same server with speculation
  off. Each arm binds its request digest, runtime identity, and clock sidecar the
  way every census arm does.
- Prediction: the ledger carries a `mul_mat_vec_q4_k_f32_f32` row with constants
  `64,4,2`; the K arms' Q4_K plus Q6_K exclusive time per verification pass
  exceeds the C arms' by 100 to 140 ms; and at least 80% of the pass delta lands
  inside those two families.
- Falsifiers: a pass delta outside 100 to 140 ms; a mat-vec share of that delta
  below 80%, which moves the cost outside the GEMV and refutes the account this
  document reasons in; or the absence of a `64,4,2` row, which says the
  verification never reached the wider GEMV and makes every column figure above
  a measurement of something else.
- Dependency: the served baseline admits the workload, and a compatible census
  calibration separately admits the instrument. A paired instrumented comparison
  lacking that calibration states its measured overhead limits. The historical
  100--140 ms prediction remains a falsifier, including a substantially faster
  result; prediction failure does not itself reject a valid acquisition.

## Q8 helper evidence remains separate from Q4_K specialization

`mul_mat_vec_base.glsl` at the pinned commit `f280b269` declares the geometry as
three specialization constants, and `mul_mat_vec_q4_k.comp` sizes its
accumulator from two of them:

```glsl
layout (constant_id = 0) const uint BLOCK_SIZE = 32;
layout (constant_id = 1) const uint NUM_ROWS   = 1;
layout (constant_id = 2) const uint NUM_COLS   = 1;
FLOAT_TYPE temp[NUM_COLS][NUM_ROWS];
```

Both counts reach the compiler at `vkCreateComputePipelines` through
`VkSpecializationInfo` rather than through the glslc frontend, so one SPIR-V
module serves every row and column count and a NUM_ROWS 1/2/4 set at two columns
is one module under three specialization triples rather than three modules. The
workstation half is therefore module identity, and the register allocation that
separates the three comes from RADV's own ACO backend on the target part.

`remote/compile-q8-mat-vec-spv.sh` over the pinned clean tree emits the Q8_0
mat-vec module and its subgroup-reduction variant, retained in
`workstation-spirv/spirv-manifest.tsv`:

| variant | SHA-256 | bytes |
| --- | --- | ---: |
| `mul_mat_vec_q8_0_f32_f32` | `a52c7af09feadfafdbb4c265bb0a9e5be552734b20398da18874bd7ccb3ebc5f` | 22828 |
| `mul_mat_vec_q8_0_f32_f32_subgroup` | `036a450cfcb73c96e779b9d7dfba24ff9e5becc4f0d295ffa36512e5ac38818c` | 22972 |

glslc 2026.3 (shaderc 1.4.357.0) produced both, and the digests are properties of
the module rather than of an arm: the manifest annotates the served triple
`0:64,1:2,2:1` beside bytes that never saw it. `workstation-spirv/receipt.tsv`
and `workstation-spirv/specialization.tsv` retain the served `--spirv-only`
receipt, whose device, driver, register, and occupancy fields all read `-`.

The three requested variants are refused rather than written, and
`workstation-spirv/spirv-only-refusals.tsv` retains the refusals verbatim at
exit 2: a `--spirv-only` receipt taken at another row or column count is the
served module's own bytes under a candidate's label. Register statistics are
`not run` for a second reason on this host: the workstation exposes an NVIDIA
GeForce RTX 4070 Ti under the NVIDIA driver and no RADV device at all, so a
device-mode run here would report another vendor's allocation under a receipt
shaped like the appliance's. Nothing labelled "workstation RADV" exists to
retain.

`remote/raven2-shader-lab/q8-mat-vec-receipt.sh` carries a Q8_0 column-selection
capability separate from the Q4_K experiment. `--num-cols N` sets specialization constant 2 the way
`--num-rows` sets constant 1, under the same uint32 value space, the same
canonical-decimal refusals, and the same rule that a value away from the served
one requires `--allow-device`; `specialization.tsv` records the column count and
the served value beside the row count. `remote/test-q8-mat-vec-receipt.sh` covers
it with five checks over the recorded argv and the retained record, and the
existing `test-q8-mat-vec-receipt` gate cell keys on both files.

The Q8_0 receipt proves Q8_0 module and helper behavior. The Q4_K subject
requires the exact module from the instrumented executable, or a fully matched
compile whose source, preprocessing definitions, compiler, target and module digest
join that executable. Retain the extracted module and pipeline receipt. An offline
RADV compiler with matched target can produce static allocation evidence on a
workstation; actual delivery and timing remain device measurements.

## The registered mechanism

Register demand of the GEMV grows with the product `NUM_COLS * NUM_ROWS`, since
`temp[NUM_COLS][NUM_ROWS]` is per-invocation storage and the unrolled column loop
holds four `vec4` loads of `b` live per column against a 256-register file per
lane. The hypothesis predicts fewer waves per SIMD for two columns at four rows and
recovered occupancy when fewer rows reduce live storage. The compiler receipts
and executed pipeline determine whether either occupancy change occurs.

- Lab subject: the Q4_K module bound to the instrumented executable. Create
  `(64,1,2)`, `(64,2,2)` and `(64,4,2)` pipelines through the general lab, retaining
  the matched `(64,4,1)` control. Read binding count and push-constant size from
  the matched module/host layout before invocation. For the base mat-vec layout
  with five storage bindings and 52 push-constant bytes:

  ```sh
  for rows in 1 2 4; do
      remote/raven2-shader-lab/lab.sh "$Q4K_SPV" "$RESULTS/q4k-rows-$rows-cols-2" \
          --spec 0:64 --spec "1:$rows" --spec 2:2 --subgroup 64 \
          --bindings 5 --push-constants 52
  done
  remote/raven2-shader-lab/lab.sh "$Q4K_SPV" "$RESULTS/q4k-rows-4-cols-1" \
      --spec 0:64 --spec 1:4 --spec 2:1 --subgroup 64 \
      --bindings 5 --push-constants 52
  ```

  Equal register allocation and occupancy across row counts refutes the proposed
  row-driven occupancy mechanism. Match each result to its module and specialization.
- Bracket falsifier, one served window: under `QWEN_CENSUS_AB_MODE=kernel-delta`,
  the row count the lab selects must shorten the two-column pass's own exclusive
  interval by at least 5%. A smaller move leaves the mechanism real and useless
  as a lever, which is the reading this tree gives an effect below the spread it
  can resolve.

Pipeline creation uses one reserved, bounded window under the established device
policy. A static receipt and a served timing answer separate questions.

The realized census retains module, specialization, proposed drafts, target-pass
widths, accepted and rejected drafts, implementation-specific bonus tokens and
committed output. A one-token proposal maximum establishes no realized width by
itself. Verification rounds differ from ordinary `predicted_n - 1` decode graphs.
The effective rate is committed output tokens divided by draft time plus target
verification time plus bookkeeping time. Residency and restore costs remain
recorded. Faster verification can lose overall when draft cost or rejection grows.
