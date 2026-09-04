# The producer-cost canary: break-even arithmetic ahead of a served comparison

`e4b-a-first-pass.md` and `evidence/e4b-summary-producer/README.md` refute the
registered E4b ceiling on the compile side and leave one term open: the
`mul_mat_vec_q4_k_prepass_f32` pipeline's own dispatch cost on the device the
ISA receipts were taken from. `remote/summarize-e4b-producer-canary.py` and
`remote/run-e4b-producer-canary.sh` answer that term from one census arm
rather than from a served kernel-delta campaign, and this page registers the
arithmetic, the falsifiers, and the three architectural forms that would
remove the dispatch cost the canary might refute.

## The break-even arithmetic

The retained receipt puts the consumer's own saving at about 0.8% of the
graph's Q4_K bracket
(`evidence/e4b-summary-producer/README.md`: -1.61% VALU through the
kernel-delta run's own 0.48 VALU-to-bracket transfer factor, one point with no
band) and the retained E4 Q4_K interval at about 49.2 ms per token:
`evidence/raven2-vulkan-kernel-census/e4/kernel-delta-20260902T2312Z/arms/02-K/pipeline-ledger-decode.tsv`
carries `mul_mat_vec_q4_k_f32_f32` at `exclusive_bracket_ms=3099.331` over 63
decode graphs, `3099.331 / 63 = 49.195`. `e4b-a-first-pass.md` names the same
family "a device whose Q4_K mat-vec median is 206 microseconds per call and a
measured 52 ms Q4_K bracket" over the whole request rather than per graph,
which is the coarser reading of the same quantity. A 2B decode graph
pays 84 producer dispatches for that saving, 36 of them serving exactly one
consumer (`e4b-a-first-pass.md`'s reuse table). The whole predicted gain is
therefore:

```text
predicted_gain_us_per_token = 0.008 * 49.2 ms * 1000 = 393.6 us
allowance_all_producers_us  = 393.6 / 84 = 4.686 us   (registered: about 4.6 us)
allowance_useful_producers_us = 393.6 / (84 - 36) = 8.2 us   (registered: about 8.1 us)
```

A producer dispatch that costs more than the all-producers allowance erases
the gain even before any forward consumer walk declines the 36 dead-end
pre-passes; one that clears the useful-producers allowance but not the
all-producers one is a case for E4b-B before it is a case for a served
comparison, since the implementation as it stands pays for every producer
dispatch it issues.

## What the canary measures, and what it does not

`summarize-e4b-producer-canary.py` reads one I1 census arm's own
`pipeline-census.tsv`, selects the request's decode graphs the way
`summarize-kernel-census.py` does (imported by path, not reimplemented, so a
census either reader refuses is refused identically here), and for every
selected graph reports the producer pipeline's own dispatch count, bracket
median, bracket union, and per-dispatch cost (bracket union divided by
dispatch count). It recomputes the allowance from the arm's own Q4_K family
bracket union per graph rather than from the 49.2 ms constant wherever that
family is present in the census, and falls back to the constant, named as
`q4k_interval_source=fallback`, only where it is not. `--single-consumer-
producers` (default 36) and `--predicted-gain-fraction` (default 0.008) stay
named constants under either path: no single arm's census can measure a VALU
delta between two builds, and this script does not itself distinguish a
single-consumer producer from a shared one -- that is
`summarize-q4k-consumer-fanout.py`'s own reading, over the same census,
described below.

Pipeline identity is the `census_pipeline.name` field, verbatim from
`ggml_vk_create_pipeline`'s own name argument
(`patches/llama-vulkan-q4k-activation-sideplane.patch`:
`"mul_mat_vec_q4_k_prepass_f32"` for the producer,
`"mul_mat_vec_q4_k_sideplane_f32_f32"` for the reading consumer), matching the
exact strings `evidence/e4b-summary-producer/receipts/producer/receipt.tsv`
and `receipts/e4b-consumer/receipt.tsv` carry as their own `module` field.
Neither script keys on pipeline id, dispatch order, or a SPIR-V digest a
compiler choice could change underneath the shader source.

The verdict compares the measured per-producer cost against the
all-producers allowance: `above_break_even` closes E4b-A as implemented
without a served kernel-delta or witness campaign, `below_break_even`
licenses exactly one graph-level producer-plus-consumer comparison through
`run-served-binary-ab.sh`, reading the union of the producer's own bracket
and the Q4_K consumer's against E4's Q4_K consumer bracket alone, the
envelope `e4b-summary-producer/README.md` already names. The
useful-producers allowance is reported beside the verdict as the bound E4b-B
would need to clear rather than as a second verdict, since the canary alone
cannot tell a single-consumer producer from a shared one.

## What the canary does not run

Neither script executes a submission and neither runs on the workstation:
both read an already-written `pipeline-census.tsv`, and the workstation's ICD
is NVIDIA, which cannot emit RADV RAVEN2 pipeline census rows.
`run-e4b-producer-canary.sh` drives `run-raven2-vulkan-kernel-census.sh` in
`QWEN_CENSUS_MODE=attribution` with `QWEN_CENSUS_ARMS=I1`, which needs the
laptop's device, the served harness, and an accepted calibration receipt this
repository has not produced -- `e4b-a-first-pass.md`'s own falsifiers list
"the pre-pass dispatch cost on RADV" as unmeasured, and it stays unmeasured
after this change lands, since a script that reads a census is not a census.
The wrapper's own precondition check (`terminal-state.tsv` readable and
`census=accepted`) is a fast local refusal ahead of the device chain;
`run-raven2-vulkan-kernel-census.sh` remains the authority on whether the
receipt is an accepted calibration binding the two servers this run names,
and this wrapper defers to it rather than duplicating its award-comparison
logic.

## The fan-out reader

`summarize-q4k-consumer-fanout.py` reads the same census and answers a
different question: how many Q4_K consumer dispatches read each producer's
sideplane write. `pipeline-census-v3` carries no field naming the activation
tensor a mat-vec's second operand is -- `census_dispatch` records `dst_name`
and `src0_name`, the output and the weight, never `src1` -- so the reader
cannot join a consumer to its producer by tensor identity. It reads the
structure `e4b-a-first-pass.md`'s own finding rests on instead: "it holds
because each activation's consumers are adjacent in the node order." Sorting
a graph's producer and Q4_K consumer dispatches by `(node_idx, reach_ns)` and
starting a new key at every producer dispatch reproduces the sideplane log's
own grouping (`GGML_VK_Q4K_SIDEPLANE_LOG=1`, not retained in this tree)
without reading a name the census does not carry. A consumer dispatch ahead
of every producer dispatch in its own graph breaks that premise and refuses
the run rather than being folded into the nearest key silently, the same
"every defect is terminal" discipline `summarize-kernel-census.py` applies to
a malformed graph.

Run over `remote/test-summarize-q4k-consumer-fanout.py`'s own fixture -- four
producer dispatches at nodes 0, 2, 3, and 6 with two, one, three, and one
consumer dispatches following each before the next producer or the graph's
end -- the reader recovers exactly that shape: `total_keys=4`,
`single_consumer_keys=2`, `surviving_keys=2`. Run over the one real record
this tree retains,
`evidence/raven2-vulkan-kernel-census/replay-corpus/10-I1/pipeline-census.tsv.xz`
(a 2B calibration census predating both the E4b patch and this canary), it
refuses cleanly: `census_refused: the census describes no pipeline named
'mul_mat_vec_q4_k_prepass_f32'; this arm carries no producer dispatches to
group`. That refusal is itself the correct reading of a record with no
producer pipeline in it, not a defect in the reader, and it is what an E4b-A
device arm's own census would need to clear before either script reports a
number that means anything.

## Falsifiers

- **The all-producers allowance.** The canary's `verdict` field over a real
  I1 arm of the E4b-A build. `above_break_even` refutes E4b-A as implemented
  without spending a served campaign on it; `below_break_even` licenses
  exactly the one comparison named above, never a full model campaign.
- **The recomputed interval.** `q4k_interval_source` must read `measured`
  once an E4b-A census exists, since the sideplane consumer pipeline is
  present in that build by construction; a `fallback` reading on such a
  census is a defect in the pipeline-name match, not evidence about the
  producer.
- **The fan-out shape.** `surviving_keys` against the registered 48 of 84 and
  `single_consumer_keys` against the registered 36. A device count that
  disagrees with the log-derived figures in `e4b-a-first-pass.md` reports
  either a different graph shape than the one measured there or a defect in
  the node-order adjacency premise, and `orphaned_consumer_dispatches`
  above zero on a real arm is the direct instrument for the second: it means
  a consumer read a sideplane no producer dispatch in that graph wrote, which
  refutes the one-slot, adjacent-consumers design `e4b-a-first-pass.md`
  measured rather than merely failing to confirm it.
- **Token identity and the margin witness**, unchanged from
  `e4b-a-first-pass.md` and `e4b-summary-producer/README.md`: this canary
  answers a cost question and states nothing about correctness on its own.

## Three forms that remove the dispatch problem

Every dispatch the canary might refute exists because the reuse the graph
offers is real but paid for with a queue round trip per miss. Three
architectural changes remove that round trip by construction rather than by
tuning the sideplane's own arithmetic further.

**E4b-B: materialize only where fan-out exceeds one.** The forward consumer
walk `e4b-a-first-pass.md` names but does not implement:
`ggml_vk_build_graph` already visits every node before dispatch, so counting
each activation's Q4_K consumers ahead of the pre-pass decision and skipping
the producer dispatch where that count is 1 removes the 36 single-consumer
dispatches `summarize-q4k-consumer-fanout.py` counts directly, at the cost of
one graph-level pass whose own overhead is unmeasured. This is a scheduling
change over the existing two-pipeline design: the consumer branch stays
exactly as `e4b-a-first-pass.md` and `e4b-summary-producer/README.md`
describe it, and only the decision to dispatch the producer at all moves.
Where the canary reads `below_break_even` against the all-producers
allowance already, E4b-B is upside rather than a requirement; where it reads
`above_break_even` against the all-producers allowance but the measured
per-producer cost clears the useful-producers allowance, E4b-B is what
would recover the arm.

**E4b-C: emit the sideplane from the activation-producing kernel.** The
producer pipeline exists because the sideplane is a separate pass over
activation data the RMS-norm or SwiGLU kernel that wrote that activation
already held in registers or LDS one dispatch earlier. Writing the four
group sums as a second output of that kernel -- a sideplane sideplane, not a
prepass -- removes the reread of the activation the current producer performs
(`e4b-summary-producer/README.md`: 4 `buffer_load_dwordx4` in the producer's
own ISA) and removes the producer dispatch and its two barriers entirely,
at the cost of a second bound buffer and extra VGPRs and stores in every
kernel that can produce a Q4_K-consumed activation -- RMS-norm and SwiGLU on
this graph's own reuse table, plus whatever other producer classes a wider
graph carries. E4b-C's own falsifier is the fused kernel's VGPR and store
count against its unfused ISA receipt, the way `e4b-summary-producer/README.md`
reads the current producer and consumer: a fusion that spills or that grows
the dependent VALU chain of the producing kernel could cost more there than
the current design costs in dispatches, and that comparison is a compile-side
question the same shader lab this page's sibling document used can answer
before any device time is spent.

**E4b-D: fuse the summary and the first consumer where topology permits.**
Where a graph's own reuse table shows fan-out exactly 1 -- the 36 dispatches
`summarize-q4k-consumer-fanout.py` already isolates -- the sideplane buys
nothing regardless of its cost, and the correct answer is not to materialize
it at all but to let that one consumer compute its own group sums the way
E4's own hoisted form already does, which is E4b-B's own conclusion stated as
a per-key decision rather than a graph-level filter. Where fan-out is exactly
2 and the two consuming workgroups are adjacent in submission order, fusing
the sum computation into the first consumer's own dispatch and having the
second read a value the first wrote to a small scratch buffer removes the
producer's queue round trip for the pair that pays it a second time (2 rather
than 1) rather than for the pair that never would. E4b-D is scoped to the
two-consumer case because a three-or-more-consumer fusion reintroduces the
ordering hazard the sideplane's own barriers exist to close, and closing it
without a barrier needs the two dispatches to share a subgroup or workgroup,
which `NUM_ROWS = 4` output-row tiling does not guarantee across two distinct
mat-vec dispatches.

None of the three has run. Each is a scope cut named against a specific
number this canary or `summarize-q4k-consumer-fanout.py` would report from a
real device arm, and none is scheduled ahead of that arm's own verdict.

