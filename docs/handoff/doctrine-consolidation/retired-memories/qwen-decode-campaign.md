---
name: qwen-decode-campaign
description: "After checkpoint promotion, Stage A runs decode-first with tok/s as the product metric, and a two-level admission keeps sub-5% gains from being discarded"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-01T00:05:15.316Z
---

The ordering principle reads: preserve computed state first, raise sustained
token throughput second, expand residency capacity only for a measured need.
The natural-boundary work came first because it removed about 55 minutes of
redundant prefill from a 4B second turn, which clears the largest discontinuity
rather than subordinating decode.

Checkpoints fix repeated prompt work and change no generation rate. The
user-visible dimensions stay separate: prefill and restore latency set how long
before the model speaks, decode tok/s and inter-token latency set how long it
takes to finish, tail latency sets whether it feels smooth, and capacity plus
routing set which model runs at all. Registry rates make the stake concrete --
0.8B 18.53 tok/s (54 ms/token), 2B 9.19 (109 ms), 4B 3.34 (299 ms), 9B 1.76
(568 ms) -- so a 1000-token answer costs 54 s, 1 min 49 s, 4 min 59 s, and
9 min 28 s. A 5% decode gain saves about 14 s per 1000 tokens on the 4B and 27 s
on the 9B; even 1% saves 3 s and 5.6 s.

Prefill and decode want different work. Prefill is matrix-matrix with weight
reuse and favors packed FP16 and tile reuse; decode streams compact weights,
reconstructs quantized values, and runs matrix-vector reductions, favoring
compact representations, cheap unpack, low register pressure, wave64
specialization, and fewer memory transactions.

Stage A therefore keeps prefill and decode populations separate -- one long
prefill in a combined total hides the kernels that set tok/s -- and ranks
pipelines by cumulative decode time rather than file bytes or dispatch count.
Per class (0.8B, 2B, 4B) at depth 0, 16K, and 32K: 32 warm-up tokens discarded
then 256 measured, restores at depth. Retain mean tok/s, ms/token, p50/p95/p99
inter-token interval, first-token latency after restoration, per-pipeline GPU
time per generated token, dispatches per token, CPU wall time outside
submissions, queue idle, logical and physical bytes per token, effective GiB/s,
VGPR/SGPR/LDS/scratch/spill, sclk and mclk, and graphics-service latency. The
tied embedding/output tensor gets particular scrutiny: it is read as the output
projection on every generated token and is the largest single decode tensor in
each class. The 2B and 4B distills stream Q4_K and Q6_K mixtures, so their rate
depends on several unpack paths rather than one nominal label.

Two admission levels keep real small gains. Component retention needs the
mechanism confirmed in ISA or timestamp data, a repeatable target-kernel
improvement, no resolved whole-model regression, exact output, and safe
resource and desktop QoS. Production promotion needs an independently
remeasured bundle clearing the existing all-pairs 5% whole-model rule. Never
sum component percentages arithmetically; the combined binary itself clears the
gate. A small-change ledger records candidate, target pipeline and shape,
before/after ISA digest, instruction and memory-operation delta, VGPR/LDS/spill
delta, per-kernel timestamp delta, whole-model tok/s delta, token identity,
interaction group, and status over rejected, retained-component, promoted.

Order after promotion: decode scoreboard -> decode-only pipeline census ->
representation controls (Q4_0, Q4_K_M, Q8_0, retained mixtures, reading tok/s,
quality, and streamed bytes together) -> workgroup, NUM_ROWS, NUM_COLS,
reduction, and unroll tuning for measured hot shapes -> wave64 quantized matvec
and tied output projection specialization -> ISA picooptimizations backed by a
demonstrated instruction, liveness, spill, or LDS defect -> ACO patches only
where SPIR-V asks for what gfx902 ISA fails to express -> bundle retained
sub-5% gains and run whole-model ABBA -> CPU scheduling and LTO only once
telemetry shows a meaningful CPU fraction between tokens.

The capacity and model-admission lane (unified heap, larger models, GTT) runs
beside this rather than displacing it: a larger model that loads and produces
1.5-2 tok/s stays a specialized slow lane, and memory capacity changes no
reading speed.

Every optimization report translates kernel measurements into user time: tok/s
and ms/token before and after, seconds saved per 100, 500, and 1000 generated
tokens, first-token latency, p95 inter-token pause, long-context decode rate,
desktop latency while generating, and quality with token identity.

Related: [[qwen-natural-boundary-patch]], [[qwen-gtt-and-queue-decisions]],
[[qwen-telemetry-session-records]], [[qwen-benchmark-class-policy]].
