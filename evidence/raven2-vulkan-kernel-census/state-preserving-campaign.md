# The state-preserving campaign: two missions, registered ahead of their code

The prompt path went from reconstructing 30,748 tokens in 57 minutes to
restoring a natural-boundary checkpoint and processing a 28-token delta in
seconds, because the valid state was preserved and only the changed cell
was recomputed. The calibration harness carries the same mistake one level
up: every repository head has been treated as a new universe and every
thirteen-arm run as thirteen unrelated experiments, while the decode
payload the campaign exists to measure is thirteen requests of about 6.4
seconds each, 83 seconds of an 80-minute chain. This file registers the two
missions that collapse the rest, the mechanisms each installs, and the
falsifier each answers to, ahead of the code.

The doctrine, stated once: preserve every expensive state whose inputs are
unchanged, address it by the digest of those inputs, and recompute only the
dimensional cell that changed. Every item below answers the doctrine's one
question in three parts -- which expensive state is invariant, how long is
it valid, and what is the smallest exact thing that must change -- and the
fields carry the parts: `materialized state` names the invariant thing,
`reuse boundary` gives the scope over which it stays valid, `invalidation
key` names the smallest exact thing whose change ends that validity, and
`falsifier` states what would refute the item.

## Mission 1: the harness

**1.1 wall-clock ledger.**

- mechanism: `wall-clock.tsv` per chain and per arm: gate, preparation,
  shader generation, compilation, link, sync, launch, load, request,
  teardown, cooldown, analysis.
- reuse boundary: one chain and every arm inside it.
- materialized state: the named phase durations, retained as the chain's
  own record.
- invalidation key: chain identity, arm index, phase name.
- falsifier: a phase the ledger cannot name is a phase that cannot be
  collapsed.

**1.2 acquisition versus analysis.**

- mechanism: `acquisition-contract.tsv` holds every input able to change
  observed bytes; `analysis-contract.tsv` holds the readers' digests; an
  attribution requires acquisition equality alone.
- reuse boundary: every analysis head reading one acquisition.
- materialized state: the observed bytes of a device run, beside the two
  contracts.
- invalidation key: the acquisition contract digest alone; the analysis
  digest addresses readers rather than device runs.
- falsifier: a reader change that forces a device run is a defect of the
  split.

**1.3 control bricks.**

- mechanism: C0 sidecar, C1 compile, C2 collect, C3 identity, each with an
  input-closure digest and a receipt; `calibration_root = H(acquisition,
  C0..C3)`; a brick whose closure is unchanged is reused from a prior
  directory with its arms marked `reused`.
- reuse boundary: every chain whose acquisition contract matches.
- materialized state: each brick's outputs and receipt in a prior
  directory.
- invalidation key: the brick's own input-closure digest, and
  `calibration_root` over all four beside the acquisition.
- falsifier: a reused brick whose closure digest differs from the prior
  run's is refused.

**1.4 replay corpus.**

- mechanism: real Raven2 records (an I1 census, the S slice, two sidecar
  records) under `replay-corpus/` with their expected verdicts, run by the
  gate.
- reuse boundary: every reader revision, over device runs already retained.
- materialized state: the records and the expected verdict beside each.
- invalidation key: the record digests; a reader revision leaves them
  unchanged and reruns the reader alone.
- falsifier: a reader that passes its synthetic tests and fails the corpus
  never reaches the device.

**1.5 shader pack cache.**

- mechanism: `shader_pack_key = H(commit, shader sources, generator,
  options, glslc identity)`; a matching pack is restored ahead of the
  build.
- reuse boundary: every build sharing shader sources and shader toolchain.
- materialized state: the generated and compiled shader pack.
- invalidation key: `shader_pack_key`.
- falsifier: cmake regenerating regardless is reported with the flag that
  stops it.

**1.6 object cache.**

- mechanism: ccache with `CCACHE_BASEDIR` and `-ffile-prefix-map` over both
  trees; hits and misses in the manifest.
- reuse boundary: every translation unit whose preprocessed input and flags
  match, across trees at different paths.
- materialized state: the compiled objects ccache retains.
- invalidation key: ccache's own content hash, with the tree path mapped
  out of it.
- falsifier: a fresh candidate tree at another path missing the cache is a
  prefix-map defect.

**1.7 instrument binary key.**

- mechanism: `H(commit, production series, candidate series, preset, common
  flags, compiler identity, shader pack key)`; a matching retained binary
  is reused by digest.
- reuse boundary: every chain requesting that instrument.
- materialized state: the linked binary and its manifest executable row.
- invalidation key: the seven-term binary key.
- falsifier: a reused binary whose manifest executable row fails to match
  is refused.

**1.8 sparse gate.**

- mechanism: `GateCellKey = H(command, script, read set, tool versions)`; a
  recorded accepted cell is reused; universal cells always run; cheapest
  and likeliest to fail first.
- reuse boundary: the cell's own read set.
- materialized state: the recorded accepted-cell verdict.
- invalidation key: `GateCellKey`; a universal cell carries none and runs
  every time.
- falsifier: a cell whose read set cannot be bounded runs every time.

**1.9 quiescence boundary.**

- mechanism: `await-quiescence.sh`: no server, GPU busy at floor, sclk at
  its lowest step, temperature derivative and level bounded, MemAvailable
  steady, no swap-in, lease free, probe latency at baseline, held for
  800 ms; 30 s stays as the maximum.
- reuse boundary: the arm that follows the reached boundary.
- materialized state: the machine's own quiet state, held across the
  boundary rather than written to a file.
- invalidation key: any one of the named signals leaving its bound.
- falsifier: an arm that follows a reached quiescence and still reads as
  position-dependent refutes the vector.

**1.10 telemetry broker.**

- mechanism: one C process, descriptors opened once, `clock_nanosleep`
  absolute schedule, a preallocated ring, multirate channels,
  `PAUSE`/`RESUME`/`MARK` over a FIFO, drained in the sampler's own record
  format.
- reuse boundary: one broker process across every arm of a chain.
- materialized state: the opened descriptors, the preallocated ring, and
  the absolute sampling schedule.
- invalidation key: a `MARK` boundary partitions the ring, so an arm change
  costs a FIFO write rather than a process restart; a channel-set change
  restarts the broker.
- falsifier: a fast-path sample above 50 us, or a gap the scheduler still
  opens at nice 19, is measured by the same validator.

**1.11 canary.**

- mechanism: `QWEN_CENSUS_MODE=canary`: P, I0, I1, S at 8 tokens, structure
  judged alone.
- reuse boundary: the harness structure a full calibration would exercise.
- materialized state: the 8-token structural verdict over all four arms.
- invalidation key: the harness digest set the calibration reads; the model
  tuple and the token count are fixed.
- falsifier: a harness class the canary passes and the calibration fails is
  a canary gap to close.

**1.12 resident lattice.**

- mechanism: after one accepted calibration: two resident servers, P and I,
  with the census armed per request; fresh-process ABBA against
  dual-resident ABBA.
- reuse boundary: every request served by one resident server.
- materialized state: the loaded model, its Vulkan allocations, and its
  warmed pipelines, held across arms.
- invalidation key: the build identity of the resident process; the census
  arming is per request and ends no residency.
- falsifier: paired non-equivalence keeps one process at a time with
  runtime toggling alone.

## Mission 2: the compiler laboratory and the kernel

The optimization stack is six layers, and each experiment states which
layer it reads:

```text
GLSL  ->  SPIR-V  ->  NIR  ->  ACO  ->  gfx902 ISA  ->  kernel time
```

**2.1 shader lab.**

- mechanism: one pipeline created from a `.spv` with the pipeline's
  specialization constants under `RADV_DEBUG=shaders,shaderstats,nir`;
  SPIR-V, NIR, ISA digests; instruction-class counts normalized per
  256-weight superblock; dependency depth per block; a receipt diff naming
  the first layer where control and candidate differ.
- reuse boundary: every experiment reading one pipeline's layers.
- materialized state: the per-layer digests, the normalized instruction-
  class counts, and the dependency depths, retained per candidate.
- invalidation key: the SPIR-V digest crossed with the specialization
  constants and the driver identity.
- falsifier: a candidate whose ISA digest equals the control's has no
  mechanism, whatever its GLSL removed.

**E1, the pinned inventory.**

- mechanism: the pinned Q4_K and Q6_K mat-vecs' ISA inventory, address
  arithmetic apart from dot arithmetic, wave-uniform bases in SGPRs or
  leaked to VGPRs.
- reuse boundary: every later experiment quoting the pinned counts as its
  denominator.
- materialized state: the two inventories split by category, with base
  residency recorded per operand.
- invalidation key: pipeline module digest, specialization constants, RADV
  and ACO identity.
- falsifier: a Q4_K count below 50 VALU per superblock refutes the
  operation-count account.

**E1.5, the final NIR.**

- mechanism: the final NIR for the same executed SPIR-V.
- reuse boundary: the executed SPIR-V, shared by control and candidate.
- materialized state: the post-optimization NIR beside its SPIR-V digest.
- invalidation key: the SPIR-V digest and the NIR pass set.
- falsifier: a GLSL change that NIR canonicalizes away is closed as
  compiler-already-hoists.

**E2, integer product selection.**

- mechanism: an integer probe reading whether ACO selects `v_mad_u32_u24`
  or `v_mul_lo_u32` for a masked-nibble product accumulated in `int`.
- reuse boundary: every integer-kernel design decision downstream, E5b and
  E5c included.
- materialized state: the ACO selection record for the product
  instruction, with the operand range facts that produced it.
- invalidation key: GLSL operand types, the NIR range facts, ACO identity.
- falsifier: quarter-rate selection refutes the 2.6 operations per weight
  estimate for a GLSL-sourced kernel.

**E2b, packed-subword survival.**

- mechanism: a packed uint8 probe reading whether the packed form survives
  to SDWA, opsel, or `v_perm_b32` against early widening.
- reuse boundary: the same downstream integer designs, over the
  representation rather than the multiply.
- materialized state: the lowering record naming where each byte lane
  becomes a 32-bit value.
- invalidation key: GLSL operand types, the NIR range facts, ACO identity.
- falsifier: widening every byte lane ahead of the multiply leaves the
  packed representation costing what the unpacked one costs, which closes
  E5b at the GLSL level and moves it to a SPIR-V post-pass.

**E3, address generation.**

- mechanism: address-generation decomposition and pointer advance instead
  of index reconstruction.
- reuse boundary: the lane's traversal of one row, where the base advances
  rather than being rebuilt per superblock.
- materialized state: the advancing pointer and the wave-uniform bases held
  across superblocks.
- invalidation key: row index and buffer binding; the superblock step
  leaves both unchanged.
- falsifier: an address count below 10% of the superblock's VALU makes E3
  not worth a device window.

**E4, the row-local hoist, done first pass.**

- mechanism: the activation group-sum hoist traced through every layer,
  then exact-output ABBA.
- reuse boundary: the `NUM_ROWS` output rows one lane serves.
- materialized state: four activation group sums `g0..g3` per 256-element
  superblock, in registers.
- invalidation key: the superblock index within the lane's traversal.
- falsifier: ISA identical to the control closes it as
  compiler-already-hoists; a VGPR rise or an occupancy fall erasing the
  issue saving closes it the same way; ISA changed and the token unchanged
  means the removed instructions were not limiting.

The measured first pass: 32 to 20 operations per lane per superblock at
`NUM_ROWS = 2`, about 8% of the family's issue count rather than the 16%
registered for a per-token pre-pass, because the twelve group adds still
run once per column per superblock. At the served `NUM_ROWS = 4` of
`mul_mat_vec_q4_k_f32_f32`, counted over the minimum term alone per lane
per superblock, the control issues 64 operations, E4 issues 28, and a
pre-pass consumer issues 16 plus four scalar loads
(`e4/e4b-c-first-pass.md`).

**E4b-A, global sum4 sideplane.**

- mechanism: one pre-pass writes a sideplane of activation group sums that
  every Q4_K row workgroup reads.
- reuse boundary: the `stride_d / NUM_ROWS` row-block workgroups of one
  matrix, each of which recomputes the same group sums over one activation
  superblock and token column.
- materialized state: `Q4KActivationBrick { raw[256]; sum4[64] }`, the 64
  four-element sums, 25% of the raw element count at equal width. The
  sideplane carries those 64 partials per superblock in the shader's own
  lane-chunk layout, since four full group sums per superblock reassociate
  the additions and register a numerical claim of their own
  (`e4/e4b-c-first-pass.md`).
- invalidation key: activation buffer identity, offset, K, token columns C,
  graph epoch.
- falsifier: sideplane traffic plus prepass cost exceeding the duplicated
  group-sum cost times output-row reuse, measured in bytes at the real
  activation type, against the break-even relation and the traffic-balance
  ledger below.

**E4b-B, producer-fused persistent sideplane.**

- mechanism: the operation producing the activation emits its sum4 beside
  the raw values while they are live, as a backend-private execution
  representation beside the logical tensor.
- reuse boundary: all Q4_K consumers of one activation tensor -- the gate
  and up of an FFN input, the several projections of a recurrent-layer
  activation.
- materialized state: raw activation plus sum4, emitted by the producer.
- invalidation key: activation identity, offset, K, C, graph epoch, never
  layer number or token number alone.
- falsifier: added traffic or occupancy cost erasing the measured ISA
  saving, or a consumer set of one where amortization is absent.

**E4b-C, shared-workgroup activation/sum4 brick.** Status: refuted
(structural, reuse factor 1.0), `e4/e4b-c-first-pass.md`.

- mechanism: the workgroup stages the activation slab into LDS once and one
  wave or cohort computes its sum4 for every row wave.
- reuse boundary: 1.0. `first_row` derives from `gl_WorkGroupID`, so the
  output-row block is a workgroup property and all 64 lanes serve the same
  `NUM_ROWS` rows over disjoint K slices; one workgroup is one wave at the
  served `constants=64,4,1`, and the 16-lane cohort tiles a superblock
  exactly once. The independent row waves the brick would serve have no
  referent.
- materialized state: the slab staged once into LDS with sum4 computed by
  one wave or cohort. Each lane reads back the value it wrote, so the brick
  materializes state that is already private to its consumer.
- invalidation key: the slab index within the workgroup's traversal.
- falsifier: met before implementation. LDS staging and barrier cost
  exceeding the removed duplicate group sums is the recorded outcome at
  reuse 1.0 -- 4096 bytes of LDS, one barrier per iteration, and a
  write-then-read round trip against zero removed operations and zero
  removed global loads.

The redundancy the brick aimed at lives at the E4b-A and E4b-B boundary
instead: across the `stride_d / NUM_ROWS` row-block workgroups of one
matrix first, then across the projection consumers of one activation
tensor.

**E4d, the four-axis brick, later.**

- mechanism: activation statistic x projection consumer x output-row brick
  x token column.
- reuse boundary: at C=2 the transformed activation carries both columns'
  statistics while the weight superblock is traversed once, which is the
  connection to the 4B multi-token-prediction work.
- materialized state: the two-column activation brick with its statistics,
  held across the projections that consume it.
- invalidation key: activation identity, offset, K, the column pair, graph
  epoch.
- falsifier: the two-column statistic raising VGPR past the occupancy step.

**E5a, the same representation done better.**

- mechanism: same representation, same FP activation, better unpack,
  address, and metadata path.
- reuse boundary: the family's exclusive bracket under one representation.
- materialized state: the improved unpack, address, and metadata path
  inside the pipeline itself.
- invalidation key: shader source digest and specialization constants.
- falsifier: below 5% on the family's bracket refutes the structural
  account.

**E5b, packed subword intermediates.**

- mechanism: packed subword integer intermediates, widening only before the
  FP FMA.
- reuse boundary: one lane's superblock traversal, where a packed register
  carries four values through the multiply.
- materialized state: subword integer partial products held packed until
  the widening point.
- invalidation key: the superblock index, and E2b's lowering result, which
  decides whether the packing survives at all.
- falsifier: ACO widening the intermediates ahead of the multiply leaves
  the instruction count at E5a's, which closes the representation.

**E5c, integer-quantized activations.**

- mechanism: Q4_K weights against integer-quantized activations with late
  scaling, admitted only after E2 and a numerical contract: activation
  representation, scale placement, signed range, 24-bit multiplicand bound,
  32-bit accumulation bound, rounding location, dequantization order.
- reuse boundary: the once-per-token quantized activation column, read by
  every output row of every projection that consumes it.
- materialized state: int8 activations with their scale and their int8
  group sums.
- invalidation key: activation identity, offset, K, token column,
  quantization parameters, graph epoch.
- falsifier: a violated contract bound -- an operand outside the 24-bit
  multiplicand range, an accumulation past 32 bits, or a rounding placement
  that moves the token -- refuses the arm before any rate is read.

**Q6_K as positive control.**

- mechanism: the same silicon streams Q6_K at 17 GB/s and Q4_K at 12; diff
  the two ISA inventories by category to find the work Q4_K repeats.
- reuse boundary: one silicon and one census tuple, across the two
  pipelines.
- materialized state: the two categorized inventories, retained as one
  diff.
- invalidation key: the two pipeline module digests and the census tuple.
- falsifier: a category diff naming no work Q4_K repeats leaves the
  17-against-12 GB/s gap unattributed to instruction count and moves it to
  dispatch shape.

**Q1 to Q5, the further rungs.**

- mechanism: metadata lane ownership and broadcast; streamed unpack with a
  shorter VGPR lifetime; 2D row waves over one staged 256-K brick; exact
  K8 and K24 variants; a projection-brick axis; the token-column axis for
  the 4B.
- reuse boundary: one per rung -- the wave for broadcast metadata, the lane
  for the shortened unpack lifetime, the workgroup for the staged brick,
  the projection fan-out for the projection brick, the column pair for the
  token-column axis.
- materialized state: the broadcast metadata in SGPRs, the short-lived
  unpack registers, the staged 256-K brick, the per-projection brick, and
  the second column's statistics.
- invalidation key: wave index, superblock index, slab index, activation
  identity, or column pair, each with the graph epoch.
- falsifier: each rung earns a device window only with a mechanism receipt.

Every candidate carries a mechanism receipt before a served run: control
and candidate digests per layer, counts before and after per superblock,
VGPR, SGPR, and waves per SIMD, and the predicted whole-token effect from
the census's 52 ms Q4_K denominator. The served benchmark then answers one
question, whether a demonstrated ISA change reduced real decode time.

## The reframing: sufficient-statistic extraction

The shader problem is sufficient-statistic extraction -- the smallest
activation-derived representation containing everything all output rows
need. For Q4_K that starts with raw activation microtiles plus the
sum-of-four correction statistics, and every activation-only expression in
the Q4_K ISA whose result is independent of the output row is a candidate
member of the brick. This is the checkpoint result at the shader's scale:
the checkpoint keeps the minimal historical state sufficient to continue
inference, and the brick keeps the minimal activation state sufficient to
finish a matrix row.

The relation every E4b arm is decided by:

```text
precompute cost + sideplane traffic
<
duplicate group-sum cost x output-row reuse x projection reuse
```

Each arm states its traffic-balance ledger ahead of implementation:

- saved: group-add instructions, and the repeated addressing around them.
- added: prepass instructions, sideplane writes, sideplane reads, and
  dispatch or barrier cost where the prepass is separate.
- reuse: output-row workgroups per activation, projection consumers per
  activation, token columns per activation.

## The bounds these arms are read against

Q4_K owns about 52 ms of a 101.4 ms served token. A 5% throughput
promotion needs 101.4 ms to reach 96.57 ms, about 4.83 ms removed. E4's
maximum is 52 x 0.08 = 4.16 ms, which cannot carry 5% alone. E4b's maximum
is 52 x 0.16 = 8.32 ms, so an E4b arm carries 5% at about 58%
realization. These are bounds over the measured denominator rather than
predictions of a rate, and E1 decides what ACO removes before either bound
is spent on a device window.

## Order

1.1 and 1.2 first, since every later item is measured through them; 1.3,
1.4, and 1.11 next, since they end the pattern that consumed chains one to
six; 1.5 to 1.8 in parallel, since they are pure caching; 1.9 and 1.10
together, since the sampler problem is a scheduler problem; 1.12 last and
only after an accepted calibration. In mission 2, 2.1 and E1 before any
kernel edit, E4 as the first candidate through the whole ladder, E2 and
E2b before E5b or E5c exists, then E4b-A first, since a separate pre-pass
measures the sideplane's traffic before a producer is changed, E4b-B after
it over the projection fan-out, E4b-C closed on its structural refutation,
and E4d after a two-column arm exists.
