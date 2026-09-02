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
48.7%. The census exists to state which families own what, and it states
ownership only where the instrument can distinguish ownership from
residency.

## Five execution states

```text
P            the promoted production binary, the scoreboard's own bytes,
             with the clock sidecar sampling beside it
P-nosidecar  the same binary with the sidecar off
I0           the census binary, instrumentation compiled in, collection off
I1           the same census binary, collection on
S            the same census binary under the diagnostic profile with the
             pinned vk_perf_logger armed: the serialized identity control
```

Every state, S included, runs through `measure-served-decode.sh`, so the
workload lease, the process identity capture against the approved
executable, the kernel-hazard watch, the graphics-latency record, the
telemetry record, and the teardown proof hold for each arm alike.

Three controls separate three effects, and `summarize-census-controls.py`
assigns a bound to those three quadruples alone:

```text
P-nosidecar P P P-nosidecar   sidecar bound   0.65%   what the sampler costs
P I0 I0 P                     compile bound   0.65%   what compiling the instrument did
I0 I1 I1 I0                   collect bound   2%      what collection costs under the sampler
```

The sidecar runs during P, I0, and I1, so `I0 I1 I1 I0` measures collection
under a common sampler load and the sampler's own cost is a separate
control ahead of it. Each quadruple yields two paired deltas, `b/a - 1`
and `c/d - 1`, and the runner reports both: a pair is accepted where both
arms of both pairs completed and both deltas sit inside the registered
bound, and a fast inner arm never compensates a slow one through a mean.
Any other quadruple matching the `a b c d` pattern is printed
`unclassified` with no bound, since `P I1 I1 P` conflates compile and
collection effects and `I1 S S I1` compares two submission shapes; S stays
outside the pair parser. The 2B calibrates because its four scoreboard
arms span 0.65%; that span is the registered compile bound, a descriptive
figure adopted as a tripwire rather than a confidence interval.

The campaign has three terminal states and the exit status follows them: a
failed arm or an incomplete control ends it `failed` with exit 1, a refuted
registered control ends it `refuted` with exit 3 even where every arm
completed, and `accepted` alone exits 0. `terminal-state.tsv` carries the
state and the four counts, so a chain reading the exit status reads the
calibration verdict rather than the request count.

## What P stands for and how it is bound

P is bound to the scoreboard it stands for rather than to a path. Its
artifact manifest must describe exactly that executable by byte count and
digest, name no `instrumentation` row, declare `serving_eligible` yes or
carry no such row, and carry one `checkpoint_semantics` row reading
`natural-boundary-v1` wherever the registry row runs a positive checkpoint
count. `QWEN_CENSUS_PRODUCTION_RECEIPT` names the `identity-check.tsv` of
the fixed-64 sweep, whose one `server` row must carry P's digest and byte
count as both expected and observed, accepted. `inputs.tsv` records the
server digest and bytes, the manifest digest, the checkpoint semantics,
the `checkpoint_patch_series_sha256`, and the receipt digest for both
servers, so an arbitrary executable path cannot define production by name.

The census binary is a diagnostic artifact and never a serving one. Its
artifact manifest carries `instrumentation	pipeline-census-v3`,
`build_role	diagnostic`, and `serving_eligible	no`, each exactly once.
`build-deployment-bundle.sh` and `verify-deployment-bundle.sh` apply one
grammar: zero eligibility rows beside zero instrumentation rows is the
legacy shape and assembles; one eligibility row must read exactly `yes`,
so an empty value is refused by name; more than one row of either kind is
refused on cardinality; and any `instrumentation` row refuses the manifest
whatever the eligibility spelling, so deleting the `no` row from a
diagnostic manifest leaves nothing a bundle admits. The contract stops
there: an explicit `QWEN_LLAMA_SERVER` launch is the bundle layer's
recovery mode and reads no bundle, so it is also the one path a diagnostic
binary reaches the device through, and the census runner is its caller.

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
is and adds a separate facility beside it.

The S arm reaches that logger through the launch chain rather than around
it. `qwen-webui-control.sh` admits the `diagnostic` profile only with an
explicit `QWEN_LLAMA_SERVER` and a loopback listener, forwards
`QWEN_PERF_LOGGER` across the tmux boundary, and
`radv-low-priority-env.sh` turns a positive `QWEN_PERF_LOGGER` into
`GGML_VK_PERF_LOGGER=1` at that frequency inside the diagnostic branch
alone; under a serving profile the variable refuses the launch. The logger
prints to the server's stderr, which the session writes to `server.log`,
and `measure-served-decode.sh` records that file's byte count as the
request window opens and closes and cuts `server-log-request.slice` from
the retained copy, so the blocks the identity record reads are the ones
the timed request appended. `summarize-perf-logger-slice.py` folds the
slice into calls per block per ggml op, requires at least `predicted_n -
1` blocks, and retains the inventory beside the I1 ledger; the op-count
comparison between the two is a reader step over two retained files, and
S is serialized identity evidence rather than a throughput comparator.

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
the dispatch and everything ahead of it have completed. The bracket is a
queue-residency envelope: it runs from the pre-dispatch timestamp's
execution to the completion of the dispatch and everything preceding the
post-dispatch timestamp, equals something close to the isolated dispatch
latency only where the preceding work had already retired, and is an upper
bound wherever the queue lets neighbours overlap. The row therefore
carries `dispatch_bracket` figures and never a kernel duration. Every
query is written inside the command buffer the graph already records, into
a pool per backend context that the record store is reserved against ahead
of arming, so recording allocates nothing and a graph that outgrows the
pool is marked overflowed and refused whole.

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
convert through `timestampPeriod`. Host instants come from
`clock_gettime(CLOCK_MONOTONIC)` directly, the clock the record names.

Host phases are kept apart. `record_ns` is what
`ggml_backend_vk_graph_compute` spent recording and submitting.
`retire_span_ns` runs from graph start to the moment the reader knew the
fence had retired and precedes every census read and write, so it is the
host-side bound on the graph that the residual is taken against.
`readback_ns` is the query read. `dispatch_row_emit_ns` is the accounting
and the dispatch rows' write, and the `census_emit` row that follows the
graph row's flush carries the graph row's own write, the flush, and
`total_emit_ns` from readback end through that flush, which is the figure
an overhead analysis uses; all of them follow retirement and are the
instrument's own cost inside the token, which the `I0 I1 I1 I0` pair
measures.

Ownership is stated from what the brackets can distinguish. Summing one
pipeline's bracket durations over a graph and dividing by the union of all
brackets counts overlapping time once in the denominator and repeatedly in
the numerators, so two fully overlapping pipelines would each own the
whole graph; no such share exists in the ledger. The summarizer sweeps the
bracket endpoints of each graph instead: a segment covered by exactly one
bracket is that pipeline's exclusive time, a lower bound on what it owns;
the union of a pipeline's own brackets is its upper bound; a segment
covered by two or more brackets goes to an ambiguous-overlap bucket, both
globally and under every pipeline whose bracket covers it. Per graph
`overlap_ns` is the raw bracket sum minus the union and
`overlap_fraction` is that over the union; a ledger whose mean fraction
exceeds the preregistered threshold of 0.05 reads `ownership=inconclusive`
on its `graphs` row and still prints every bound. The S arm's serialized
ordering tests whether the low-async upper-bound ranking preserves the
same major pipeline order.

The summarizer trusts nothing the instrument aggregated. It recomputes the
raw sum, the union, the queue time outside every bracket, the completion
span, the unavailable and unbound counts, and the distinct submission
count from the dispatch rows and requires exact agreement with the graph
row; it requires every query index distinct within a graph with the reach
index below the completion index, each interval equal to its endpoints'
difference, every dispatch on the census queue's family, one `census_emit`
row per graph consistent with the graph row, a `census_selftest` row
reading `sha256=ok`, and `census_close` counts equal to the parsed graph,
pipeline, and dispatch counts. Every graph inside the request window is
validated ahead of the phase filter, so a defective prefill graph fails a
decode ledger, and a graph that begins before the window and retires
inside it, or begins inside and retires after it, is refused as ambiguous
membership rather than sorted either way.

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
variant was built from. The digest comes from a SHA-256 embedded in the
instrument, and that implementation is held to two checks rather than
trusted: the binary hashes three known vectors at census initialization
and refuses to open a census on a mismatch, writing `census_selftest`
into the file it passed, and `remote/test-census-sha256.sh` compiles the
function out of the patch on the workstation and compares it with
`sha256sum` over the known vectors, every padding boundary from 55 to 65
bytes, and a random mebibyte. `GGML_VK_PIPELINE_CENSUS_DUMP` names a
directory the executed modules are written to as `<digest>.spv`, so one
dumped module is cross-checked against `sha256sum` by its file name. The
pipeline id is local to one census file, assigned on first dispatch, since
one pipeline object serves every backend context on the device.
`wg_denoms` is a dispatch denominator and the local workgroup size lives
in the specialization constants where the shader declares it there.

Per dispatch the row retains the dispatch count, grid and workgroup
dimensions, workgroups launched, queue identity, submission serial, the
two bracket instants and their interval, and the bytes the tensor census
attributes to the weights it read. Per pipeline variant the aggregate
retains the bracket upper bound, the pipeline's own union, its exclusive
and ambiguous time, median, p90, p99, and maximum interval, calls per
token, workgroups per token, and the six RADV statistics. A Vulkan
dispatch and a workgroup stay separate quantities: one graph node issues
one dispatch of thousands of workgroups, and command overhead and shader
geometry are told apart by carrying both.

## The clock sidecar

The one-second runtime monitor is adequate for safety and too coarse to
place a 52 to 62 ms token. `remote/sample-clock-sidecar.py` samples
`pp_dpm_sclk`, `pp_dpm_mclk`, `pp_dpm_fclk`, `gpu_busy_percent`, and
`temp1_input` every 5 ms on `CLOCK_MONOTONIC`, the clock the census stamps
every graph with and the runner stamps its request window with, so a clock
step is placed against a graph rather than against a minute. The columns
name what they read: `pp_dpm_sclk_selected_mhz` is the selected graphics
step, and `pp_dpm_mclk_surface_mhz` and `pp_dpm_fclk_surface_mhz` are the
sysfs surfaces, which on this SMU10 path are fabric-clock states rather
than the trained DRAM speed, as the header line states. The sampler is
pinned to core 1 at nice 10 while the server runs on core 0 at nice 19,
and it records its pid, niceness, and affinity in the header.

A sidecar record is evidence only where `validate-clock-sidecar.py`
accepts it: exit status 0, one footer, a sample count above one equal to
the rows, an achieved period within 25% of the requested one, a mean
sample cost under 1 ms, every sensor read on every sample, footer
instants equal to the first and last rows, and the request window covered
on both sides. The SMU10 kernel path exposes `pp_dpm_fclk` as an empty
file and reports the fabric clock through `pp_dpm_mclk`, so the runner
allows the FCLK column to read `unavailable` where that file is empty at
campaign start, records the allowance in `inputs.tsv`, and requires every
other column on every sample. Any refusal fails the arm. The
`P-nosidecar P P P-nosidecar` control runs ahead of the other two and
bounds what the sampler itself costs the served rate, because two hundred
sysfs opens per second are a real load on a two-core machine even where
each sample is cheap; the `I0 I1 I1 I0` pair then measures collection
under the sampler both arms share. The graphics probe's latency log keeps
its own clock and is read beside the sidecar rather than joined to it.
Clock selection is an execution-shape axis here, because a faster or more
fragmented shader can lower apparent demand and select a lower state that
cancels part of its own gain.

## Retained runs

`20260902T0222Z/` retains the chain run on head 7e9e09b with the v2
instrument, ahead of the review that produced v3. It is classified
`measurement_status=diagnostic instrument_version=pipeline-census-v2-pre-review
merge_authority=no ownership_authority=no`. Its eight served arms refused
at launch on `descriptor-backed model path requires approved model
identity`, because the runner passed no artifact ledger and the served
harness derives the approved identity from that ledger alone; the runner
now requires the ledger and records its digest. The S arm completed at
2.485 tok/s with 66 logger blocks under the serialized profile, and the
sidecar held a 5.0001 ms period at a mean cost of 614 microseconds per
sample on the appliance, which is the figure the sampler control exists
to bound. No bracket, overlap, or ownership figure exists from that run.

## Order and falsifiers

Runs go 2B, then 0.8B, then 4B. The 2B validates the instrument, the 0.8B
tests whether the instrument preserves the clock-sensitive path, and the 4B
supplies the scaled structural case. A default becomes Raven2-wide only
where the classes agree. A census proper on any class follows a 2B
calibration in which all three registered controls accepted on the exact
instrument the census runs.

- Either `P-nosidecar P P P-nosidecar` paired delta outside 0.65% refutes
  the claim that the 5 ms sampler leaves the served rate inside the
  class's own spread.
- Either `P I0 I0 P` paired delta outside the 2B's 0.65% scoreboard span
  refutes the claim that compiling the instrumentation leaves the served
  rate inside the class's own spread.
- Either `I0 I1 I1 I0` paired delta outside 2% refutes the claim that the
  asynchronous collection is cheap enough to attribute serving-profile
  time; the serialized arm then remains the only attribution.
- A mean bracket overlap fraction above 0.05 over the selected decode
  graphs makes ownership inconclusive: the ledger keeps its upper and
  lower bounds and states no owner.
- A query the device had not written when its fence retired, a read at
  `next_graph` or `cleanup`, a read that waited, an overflowed pool, or a
  dispatch no submission bound fails the arm.
- A graph aggregate the summarizer cannot reproduce from the dispatch
  rows, a reused query index, an interval disagreeing with its endpoints,
  a missing or inconsistent emit row, a failed self-test, or a close row
  disagreeing with the parsed counts fails the arm.
- A request window holding other than `predicted_n - 1` decode graphs,
  decode graphs that are not contiguous in serial, a graph partially
  inside the window, or a defective graph of either phase inside it fails
  the arm.
- A bracket union exceeding the queue completion span, or a completion
  span exceeding the host retire span, refutes the timestamp conversion
  and fails the arm.
- A sidecar record refused by the validator fails the arm.
- An S slice holding fewer than `predicted_n - 1` logger blocks fails the
  arm.
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
remote/summarize-census-controls.py           the three registered controls
remote/summarize-perf-logger-slice.py         the S arm's op inventory
remote/sample-clock-sidecar.py                DPM state at 5 ms on CLOCK_MONOTONIC
remote/validate-clock-sidecar.py              whether a sidecar record is evidence
remote/test-census-sha256.sh                  the embedded hash against sha256sum
evidence/raven2-vulkan-kernel-census/<stamp>/ retained runs
```

`measure-served-decode.sh` retains `request-window.tsv` and
`server-log-request.slice` beside every response, the runner's `arms.tsv`
carries one row per arm with its sidecar and ownership state,
`summary.tsv` one row per quadruple with both deltas and a verdict,
`terminal-state.tsv` the campaign state and counts, and the summarizer's
`pipeline-ledger-decode.tsv` ranks pipelines by bracket upper bound over
the selected graphs with a `graphs` row carrying every per-graph
accounting figure and the ownership status.

`radv-low-priority-env.sh` carries the non-serving `diagnostic` profile
that preserves the logger variables the serving profiles scrub, the launch
chain admits that profile for an explicit server on loopback alone, and
`build-llama-preset.sh` gains the `census` preset that writes the three
diagnostic manifest rows.
