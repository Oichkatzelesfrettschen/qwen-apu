# Raven2 Vulkan pipeline census: design and registered falsifiers

This directory is the home of Stage A of the execution ladder in
`evidence/vulkan-tensor-paths/gfx902-execution-ladder.md`. It states the
instrument, the execution states, the identity a measurement is keyed by,
the accounting rules, and the falsifiers ahead of any run, so a later number
is read against a claim registered before the number existed. Subdirectories
named by UTC stamp retain runs; this file carries no result.

## The denominator the census attributes

The sealed fixed-64 served scoreboard in
`evidence/fixed64-served-campaign/20260901T2011Z/` is the token time the
census divides. A census arm reproduces that arm's tuple exactly: model
bytes, context allocation, batch and ubatch, cache types, Flash Attention
state, checkpoint count and minimum step, the low-async submission profile,
a 64-token greedy request on one slot, strict Vulkan0 placement, nice 19,
and idle I/O. Sixty-three timed decode steps follow the first predicted
token, which comes from the prompt logits and is absent from
`predicted_ms`.

| Class | governing rate | target | token time | time to remove |
| --- | ---: | ---: | ---: | ---: |
| 0.8B, slowest retained arm | 16.233 | 20 | 61.60 ms | 18.84% |
| 0.8B, clean-state minimum | 18.790 | 20 | 53.22 ms | 6.05% |
| 2B, slowest arm | 9.831 | 10 | 101.72 ms | 1.69% |
| 4B, slowest arm | 3.331 | 5.25 | 300.18 ms | 36.55% |

The 2B's promotion rule is stricter than its target gap: a candidate must
gain at least 5% in every paired comparison, which is at least 4.762% of
token time removed. The 4B cannot be carried by one family below a 2x local
speedup: a family at 2x must own 73.1% of the token, at 3x 54.8%, at 4x
48.7%. The census exists to state which families own what.

## Four execution states

```text
P    the promoted production binary, the scoreboard's own bytes
I0   the census binary, instrumentation compiled in, collection off
I1   the same census binary, collection on
S    the same census binary under the diagnostic profile with the pinned
     vk_perf_logger armed: the serialized identity control
```

Two controls separate two effects. `P I0 I0 P` on the 2B measures what
compiling the instrumentation did to code layout and the compiler's
choices. `I0 I1 I1 I0` on the 2B measures what active collection costs. A
`P` against `I1` difference conflates the two and is never quoted as
instrumentation overhead. Each quadruple yields two paired deltas,
`b/a - 1` and `c/d - 1`, and the runner reports both: a pair is accepted
where both arms completed and both deltas sit inside the registered bound,
and a fast inner arm never compensates a slow one through a mean. The 2B
calibrates because its four scoreboard arms span 0.65%; that span is the
registered compile bound, a descriptive figure adopted as a tripwire
rather than a confidence interval, and the collection bound is 2%.

The census binary is a diagnostic artifact and never a serving one. Its
artifact manifest carries `instrumentation	pipeline-census-v2`,
`build_role	diagnostic`, and `serving_eligible	no`, each exactly once;
`build-deployment-bundle.sh` and `verify-deployment-bundle.sh` refuse a
manifest whose one `serving_eligible` row reads anything but `yes` and
refuse a manifest carrying that row or `instrumentation` twice, so a
census build that happens to declare valid checkpoint semantics still
cannot be activated. The contract stops there: an explicit
`QWEN_LLAMA_SERVER` launch is the bundle layer's recovery mode and reads no
bundle, so it is also the one path a diagnostic binary reaches the device
through, and the census runner is its caller.

## What the pinned build already carries, and why it is the serialized arm

At f280b269 `ggml-vulkan.cpp` holds `vk_perf_logger`, armed by
`GGML_VK_PERF_LOGGER` at device creation, which allocates a timestamp query
pool of `n_nodes + 100` entries per graph and writes one timestamp after
every enqueued node. It also changes execution: after each timestamp it
calls `ggml_vk_sync_buffers`, which records a full pipeline barrier, and at
graph end it ends the command buffer, submits against the device fence, and
waits on it before reading the pool. Every node therefore runs behind a
barrier and every graph ends in a host wait. That is the serialized
attribution arm the ladder names: exact per-node intervals, dispatch
identity, and compile-time resource statistics, under an execution shape
the serving profile never runs. The census patch leaves that logger as it
is and adds a separate facility beside it; the `S` arm runs the logger
standalone under the `diagnostic` profile with a print after every graph
and retains its stderr, so op names and call counts per graph are compared
against the `I1` dispatch rows by hand.

The pinned tree's `vk_pipeline_struct` keeps one resource field,
`register_count`, filled from the NVIDIA-named `Register Count` statistic
alone. RADV publishes `VGPRs`, `SGPRs`, `Spilled VGPRs`, `LDS size`,
`Scratch size`, and `Subgroups per SIMD` through
`vkGetPipelineExecutableStatisticsKHR`, which the pinned backend already
calls wherever the extension is supported; the census stores those names
and validates each statistic's format before reading the union. They are
compiler resource statistics and occupancy inputs, and a residency figure
comes from combining them with wave size, workgroup geometry, and a
measured interval rather than from any one of them.

The production `llama-vulkan-submit-trace.patch` records, per dispatch,
the pipeline name, workgroup counts, and workgroup denominators into a ring
under `GGML_VK_SUBMIT_TRACE=1`, and refuses to arm without serialization.
Its dispatch record is the seed of the census dispatch row.

## The asynchronous timing arm

The serving profile runs `low-async`, which exports
`GGML_VK_MAX_NODES_PER_SUBMIT=16` and leaves `GGML_VK_SERIALIZE_SUBMISSIONS`
absent. Attribution under that shape needs timestamps that add no barrier
and no host wait. The census writes one top-of-pipe timestamp at graph
start and brackets every `vkCmdDispatch` with a top-of-pipe timestamp
immediately ahead of it, written when the command processor reaches the
dispatch, and an all-commands timestamp immediately after it, written when
the dispatch and everything ahead of it have completed. The bracket bounds
the dispatch's residency on the queue: it equals the kernel's duration
where a barrier separates it from its neighbours and is an upper bound
where the queue lets them overlap, and the queue time outside every bracket
is reported separately as `queue_non_dispatch_ns` rather than assigned to
whichever shader follows it. Every query is written inside the command
buffer the graph already records, into a pool per backend context that the
record store is reserved against ahead of arming, so recording allocates
nothing and a graph that outgrows the pool is marked overflowed and refused
whole.

The pool is read where the graph's own fence has retired: in
`ggml_vk_synchronize` after `ggml_vk_wait_for_fence` on the asynchronous
path and at graph end on the serialized path. Both reads ask the device for
availability and never wait, and a query the device had not written is
counted on the graph row and refuses the graph. A graph never read at
either point is read at the next graph start or at cleanup with a wait,
since its pool is reset there; the row names that read point and the
summarizer refuses the graph, so a host wait the instrument added is a
defect the run reports rather than a rate it publishes. Timestamp
differences are taken modulo the compute family's `timestampValidBits` and
convert through `timestampPeriod`.

Four host phases are kept apart. `record_ns` is what
`ggml_backend_vk_graph_compute` spent recording and submitting.
`retire_span_ns` runs from graph start to the moment the reader knew the
fence had retired and precedes every census read and write, so it is the
host-side bound on the graph that the residual is taken against.
`readback_ns` is the query read and `emit_ns` the accounting, formatting,
and file write, both of which follow retirement and are the instrument's
own cost inside the token; the `I0 I1 I1 I0` pair measures them and the
row makes them visible. On the workstation smoke `emit_ns` sits between 0.2
and 0.5 ms per 260-dispatch graph.

Per graph the census reports the raw sum of bracket intervals, the union
of the brackets, the queue time outside every bracket, the queue completion
span from the origin timestamp to the last completion, and the four host
phases. The residual is `retire_span_ns` minus the completion span: queue
idle ahead of the first dispatch, synchronization, driver work, and host
orchestration together. It is named a residual and never named CPU time.

Each dispatch is bound to its submission at the submit: `ggml_vk_submit`
allocates the serial for the compute queue of the owning context and
assigns it to every recorded dispatch whose command buffer and use counter
it carries, and a dispatch left unbound refuses its graph. The row carries
the queue family and the command buffer identity beside the serial.

Graphs are selected by request membership rather than by shape alone.
Every graph row carries its begin and retire instants on `CLOCK_MONOTONIC`,
`measure-served-decode.sh` retains the monotonic window of the one
completion request it timed, and the summarizer selects the graphs inside
that window, requires exactly `predicted_n - 1` decode graphs contiguous
in serial, and reports prefill separately. A warm-up graph, a cache
operation, or a second request therefore cannot enter the ledger unnamed.

## The identity a row is keyed by

A pipeline name is one symbol compiled under several specialization
constants, so the same name at different `NUM_ROWS`, `NUM_COLS`, subgroup
policy, or accumulation mode is a different performance object. The census
key is:

```text
spirv_source_sha256    spirv_executed_sha256    entry_point
specialization_constants   required_subgroup_size   full_subgroups
parameter_count        push_constant_size        wg_denoms
ggml_op                dst and src0 names        src0 src1 dst types
ne0..ne3  src1_ne1     workgroups                phase
```

The executed digest covers the module bytes `vkCreateShaderModule`
received after the float-controls and driver-specific rewrites, which is
the module the device ran; the source digest covers the embedded module a
variant was built from. The pipeline id is local to one census file,
assigned on first dispatch, since one pipeline object serves every backend
context on the device. `wg_denoms` is a dispatch denominator and the local
workgroup size lives in the specialization constants where the shader
declares it there.

Per dispatch the row retains the dispatch count, grid and workgroup
dimensions, workgroups launched, subgroups launched where the pipeline's
subgroup size is fixed and estimated waves otherwise, queue identity,
submission serial, the GPU timestamp interval, and the bytes the tensor
census attributes to the weights it read. Per pipeline variant the
aggregate retains total GPU time, median, p90, p99, and maximum interval,
calls per token, workgroups and waves per token, and the six RADV
statistics. A Vulkan dispatch and a workgroup stay separate quantities: one
graph node issues one dispatch of thousands of workgroups, and command
overhead and shader geometry are told apart by carrying both.

## The clock sidecar

The one-second runtime monitor is adequate for safety and too coarse to
place a 52 to 62 ms token. `remote/sample-clock-sidecar.py` samples the
selected SCLK, MCLK, and FCLK steps, GPU busy, and the die temperature
every 5 ms on `CLOCK_MONOTONIC`, the clock the census stamps every graph
with and the runner stamps its request window with, so a clock step is
placed against a graph rather than against a minute. Every row carries the
sampler's own cost for that sample and the footer carries the achieved
period, so a sampler that could not hold its period says so. The runner
starts it ahead of every arm and stops it after, and the `I0 I1 I1 I0`
pair bounds what the sampler and the census together cost, since both run
on every I arm. The graphics probe's latency log keeps its own clock and is
read beside the sidecar rather than joined to it. Clock selection is an
execution-shape axis here, because a faster or more fragmented shader can
lower apparent demand and select a lower state that cancels part of its
own gain.

## Order and falsifiers

Runs go 2B, then 0.8B, then 4B. The 2B validates the instrument, the 0.8B
tests whether the instrument preserves the clock-sensitive path, and the 4B
supplies the scaled structural case. A default becomes Raven2-wide only
where the classes agree.

- Either `P I0 I0 P` paired delta outside the 2B's 0.65% scoreboard span
  refutes the claim that compiling the instrumentation leaves the served
  rate inside the class's own spread.
- Either `I0 I1 I1 I0` paired delta outside 2% refutes the claim that the
  asynchronous collection is cheap enough to attribute serving-profile
  time; the serialized arm then remains the only attribution.
- A query the device had not written when its fence retired, a read at
  `next_graph` or `cleanup`, a read that waited, an overflowed pool, or a
  dispatch no submission bound fails the arm.
- A request window holding other than `predicted_n - 1` decode graphs, or
  decode graphs that are not contiguous in serial, fails the arm.
- A bracket union exceeding the queue completion span, or a completion
  span exceeding the host retire span, refutes the timestamp conversion
  and fails the arm.
- A pipeline whose RADV statistics are absent or of an unexpected format is
  recorded with `-` in those fields and never with the NVIDIA register
  count in their place.
- Kernel hazards, swap-in, and probe deadline breaches are read from the
  same watchers the scoreboard used, and any of them fails the arm.

## Files this stage adds

```text
patches/llama-vulkan-pipeline-census.patch    candidate stage of the series
remote/run-raven2-vulkan-kernel-census.sh     the runner, one class per call
remote/summarize-kernel-census.py             rows to the per-pipeline ledger
remote/sample-clock-sidecar.py                DPM state at 5 ms on CLOCK_MONOTONIC
evidence/raven2-vulkan-kernel-census/<stamp>/ retained runs
```

`measure-served-decode.sh` retains `request-window.tsv` beside every
response, the runner's `arms.tsv` carries one row per arm and
`summary.tsv` one row per paired control with both deltas and a verdict,
and the summarizer's `pipeline-ledger-decode.tsv` ranks pipelines by total
bracket time over the selected graphs with a `graphs` row carrying every
per-graph accounting figure.

`radv-low-priority-env.sh` gains a non-serving `diagnostic` profile that
preserves the census variables the serving profiles scrub, and
`build-llama-preset.sh` gains the `census` preset that writes the three
diagnostic manifest rows.
