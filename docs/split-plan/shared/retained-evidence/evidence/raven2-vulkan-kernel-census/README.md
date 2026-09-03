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

## Three execution states

```text
P    the promoted production binary, the scoreboard's own bytes
I0   the census binary, instrumentation compiled in, collection off
I1   the same census binary, collection on
```

Two controls separate two effects. `P I0 I0 P` on the 2B measures what
compiling the instrumentation did to code layout and the compiler's
choices. `I0 I1 I1 I0` on the 2B measures what active collection costs. A
`P` against `I1` difference conflates the two and is never quoted as
instrumentation overhead. The 2B calibrates because its four scoreboard arms
span 0.65%; a control that moves it by more than that span is itself a
finding.

The census binary is a diagnostic artifact and never a serving one. Its
artifact manifest carries `instrumentation	pipeline-census-v1`,
`build_role	diagnostic`, and `serving_eligible	no`;
`build-deployment-bundle.sh` refuses a manifest carrying
`serving_eligible	no`, so a census build that happens to declare valid
checkpoint semantics still cannot be activated. The measurement harness is
the only consumer.

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
the serving profile never runs.

The pinned tree's `vk_pipeline_struct` keeps one resource field,
`register_count`, filled from the NVIDIA-named `Register Count` statistic
alone. RADV publishes `VGPRs`, `SGPRs`, `Spilled VGPRs`, `LDS size`,
`Scratch size`, and `Subgroups per SIMD` through
`vkGetPipelineExecutableStatisticsKHR`; the census stores those names and
validates each statistic's format before reading the union.

The production `llama-vulkan-submit-trace.patch` records, per dispatch,
the pipeline name, workgroup counts, and workgroup denominators into a ring
under `GGML_VK_SUBMIT_TRACE=1`, and refuses to arm without serialization.
Its dispatch record is the seed of the census dispatch row.

## The asynchronous timing arm

The serving profile runs `low-async`, which exports
`GGML_VK_MAX_NODES_PER_SUBMIT=16` and leaves `GGML_VK_SERIALIZE_SUBMISSIONS`
absent. Attribution under that shape needs timestamps that add no barrier
and no host wait: the census writes a timestamp query before and after each
dispatch inside the command buffer the graph already records, keeps the
per-graph query pool alive until the graph's own fence retires, and reads
the pool at the next natural synchronization point rather than at graph
end. A pool read before its fence retired is a defect and the run fails
rather than reporting a zero interval. Timestamp deltas convert through
`timestampPeriod`.

Overlap is accounted rather than assumed away. Per graph the census reports
the sum of raw dispatch intervals, the union of intervals per queue, the
host wall time of the graph, and the wall time minus the per-queue union.
That last quantity is the unattributed residual: queue gaps,
synchronization, driver work, sampling, and host orchestration together. It
is named a residual and never named CPU time.

## The identity a row is keyed by

A pipeline name is one symbol compiled under several specialization
constants, so the same name at different `NUM_ROWS`, `NUM_COLS`, subgroup
policy, or accumulation mode is a different performance object. The census
key is:

```text
spirv_sha256        entry_point       specialization_constants
layout_sha256       wg_denoms         required_subgroup_size
ggml_op             layer             tensor_role
src0_type           src1_type         accumulator_type   dst_type
N  K  C             alignment_class   phase
```

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
place a 52 to 62 ms token. The census carries a sidecar sampling selected
SCLK and MCLK state, GPU busy, temperature, and the graphics probe latency
on the same monotonic clock as token and submission boundaries, at a period
short against a token. The sampler's own cost is measured by the same
off-on control as the timestamps. Clock selection is an execution-shape
axis here, because a faster or more fragmented shader can lower apparent
demand and select a lower state that cancels part of its own gain.

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

The first v3 calibration on head e18b840 was stopped after three arms and
is retained on the appliance alone. Its `P-nosidecar` arm completed at
8.379 tok/s and both `P` arms measured 9.9 tok/s and failed on
`sensors=refused unavailable_outside_allowance=pp_dpm_fclk_surface_mhz
allowed=-`: the runner decided the FCLK allowance with a size test, and
sysfs reports every attribute at one page in `stat`, so the empty
`pp_dpm_fclk` read as full and the allowance stayed off. The runner now
reads the attribute and grants the allowance on an empty read. The
sidecar itself held a 5.033 ms period at a mean cost of 603 microseconds
over 3113 samples, inside both bounds.

`20260902T0426Z/` retains the first calibration on the v3 head 34de93f,
classified `measurement_status=diagnostic calibration_verdict=failed
ownership_authority=provisional`. Every arm launched and every rate was
measured; the run failed on the sidecar gap bound at nice 10, on the
reader's refusal of the two-context file, on the reader classifying every
graph as prefill through the f32 chunk products, and on the runtime monitor
refusing the diagnostic profile. Its two I1 ledgers, read by the analysis
head, are the first census records: 91% of a 97 ms decode graph inside the
two mat-vec families, 3.4 ms of queue idle and residual, ownership
conclusive at a 1% overlap, and the reproducibility build R byte-identical
to P. `decode-decomposition.md` reads the ledgers against the predictions
it registered ahead of them.

`20260902T0525Z/` retains the second calibration on head 59c03c8, again
`calibration_verdict=failed`, and closes two of the four failures: the S
arm ran under the admitted diagnostic profile at 2.458 tok/s with 64
logger blocks and its server exited cleanly, and the first I1 arm accepted
whole with `ownership=conclusive`. The sampler at nice 19 on core 1 still
opened holes up to 42 ms about once a second, the cadence of the guards
that sample on that core at nice 0, so it is now confined to both cores.
The two I1 arms sat 2.5% and 1.9% under their I0 neighbors, one outside
the 2% collection bound, which is what the deferred emission below exists
to remove.

`20260902T0617Z/` retains the third calibration on head e4c148a, still
`calibration_verdict=failed`: the I1 arm's per-graph emission moved to a
preallocated binary buffer drained at context close, and both I1 slots then
sat 0.9 to 1.9% under their I0 neighbors, inside the 0.02 collect bound for
the first time. The sampler moved from core 1 alone to both cores and still
opens gaps in every sampled arm, three to five per window on five of the
eight P and I0 records, so the sidecar and compile pairs stay `incomplete`
in `summary.tsv` and the next instrument change targets the sampler itself
rather than the census path.

`20260902T0819Z/` retains the fourth calibration on head f5f92d8e,
`calibration_verdict=refuted`: the sampler moves to a standalone C
telemetry broker on a 100 ms `pp_dpm_*` channel and clears its own bound on
every one of fourteen completed arms, with the two collect slots again
inside the 0.02 bound, but the sidecar and compile pairs both refute on
replicates that disagree in sign, which reads as arm-to-arm scatter rather
than the mechanism under test and moves the next chain link to a
replicated-pair, paired-mean verdict.

`20260902T1302Z/` retains the fifth calibration on head d490a39d,
`calibration_verdict=unresolved`: four replicates per control move all
three intervals to spanning their bound rather than refuting or
accepting, but the selected graphics clock inside the request window
steps from 1100 MHz to between 775 and 857 MHz across slots 9 to 12 while
temperature falls rather than rises, so the decode-rate step this run
also shows is a DPM selection and not a thermal ceiling, and a control
pair straddling that step needs a per-arm clock-state check before its
next paired-mean verdict.

`20260902T1417Z/` retains the sixth calibration on head b7a3612f,
`calibration_verdict=failed`: `arms.tsv` and `summary.tsv` now carry the
per-arm clock state the prior link registered as a remedy, and the
regime step reproduces on slot 10, whose sidecar refuses on
`window_lost_fraction=0.0326` and turns the compile control
`incomplete`, while the collect control's exact-mode rule reads every
comparable pair as state-changed inside the sustained low regime the
appliance actually serves under, so the next chain link moves that rule
to a comparability band and a regime precondition ahead of slot 1.

`20260902T1556Z/` retains the seventh calibration on head 05bd95f0, the
first to run the regime precondition: three warmup arms settle the sidecar
at a 658 MHz regime, a third band below the two prior runs' 750 to 857 MHz,
and eleven of twenty-five named arms then refuse on `window_lost_fraction`
between 0.0211 and 0.0625 against the 0.02 bound, leaving all three controls
`incomplete`. The campaign starts one second after a twenty-minute build on
the laptop's own two CPU cores, which is the registered explanation for a
regime this much lower, and the served A/B still refuses at launch on an
empty `candidate_series` selection the harness reads as a manifest error
rather than as the empty set.

`20260902T2011Z/` retains the eighth calibration on head 239af705, the first
under a commanded engine clock (`sclk_level=2`, 1100 MHz, mclk floor 933 MHz)
in place of the regime precondition: twenty-two of twenty-six arms complete,
three failing on `clock_invariant`'s mclk floor and one on `clock_sidecar`'s
`window_lost` bound, the sidecar and compile controls `incomplete` on the
same failures and the collect control `unresolved` at a mean of +0.0294
across four clean `1100/1100` pairs. Every cooldown times out
(`cooldown_timeouts=26`) because the quiescence predicate wants a clock step
below the regime's highest and the manual policy pins the highest, and the
sibling E1 ISA dump at 20260902T2039Z reproduces the same 28-module set the
20260902T1312Z dump recorded.

`e4/served-ab-20260902T2032Z/` retains the first E4 served A/B to complete
against a production control, comparing the pinned production `llama-server`
(`5dd86b90...`) against the E4 candidate build (`7d9df19f...`) over four
`C K` pairs under the same manual 1100/933 clock: `served_ab=unresolved` at a
mean delta of +0.0150 (sd 0.0426, ci [-0.0529, +0.0828]), an interval wide
enough to contain the design's registered +3.5% to +4.2% band without
excluding zero, so the run neither confirms nor refutes the Q4_K
activation-group-sums prediction and a higher replicate count or an
identified scatter source is what would separate them.

## Order and falsifiers

Runs go 2B, then 0.8B, then 4B. The 2B validates the instrument, the 0.8B
tests whether the instrument preserves the clock-sensitive path, and the 4B
supplies the scaled structural case. A default becomes Raven2-wide only
where the classes agree.

- `P I0 I0 P` paired difference above the 2B's 0.65% scoreboard span
  refutes the claim that compiling the instrumentation is free.
- `I0 I1 I1 I0` paired difference above 2% refutes the claim that the
  asynchronous collection is cheap enough to attribute serving-profile
  time; the serialized arm then remains the only attribution.
- Any query pool read whose fence has not retired fails the run.
- A per-queue union exceeding the graph's host wall time refutes the
  timestamp conversion and fails the run.
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
evidence/raven2-vulkan-kernel-census/<stamp>/ retained runs
```

`radv-low-priority-env.sh` gains a non-serving `diagnostic` profile that
preserves the census variables the serving profiles scrub, and
`build-llama-preset.sh` gains the `census` preset that writes the three
diagnostic manifest rows.
