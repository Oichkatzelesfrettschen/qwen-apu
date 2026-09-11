---
name: qwen-model-lane-roadmap
description: "The appliance's intended model lanes (0.8B specialists through 9B deep reasoning) and what the 20 GiB GTT raise actually unblocks"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-01T01:15:17.696Z
---

The appliance is a role portfolio rather than one best model, and no audit that
names a single production winner is adopted. Lanes: fast text
(qwen38-2b-distill), long text (the same row at 24K/32K, which checkpoints make
worth having), general and vision 2B (qwen35-2b, a separate profile with 9/10
raw tool selection), compact (qwen35-08b), compact experimental (0.8B coder,
reasoning, and uncensored variants), unrestricted 2B (qwen38-2b-uncensored,
qwen35-2b-hauhau, qwen35-2b-unredacted, qwen35-2b-heretic, qwenseer-2b, all
candidates with pinned artifacts and one strict load, none graded), quality text
(qwen38-4b-distill, 47/55), quality vision (qwen35-4b base with its projector),
fast vision (lfm25-vl-16b, whose attractive footprint was measured with the
projector absent and so is not the vision service's footprint), and deep
reasoning (the 9B distill). The picker groups by role and status --
Production, Candidate, Experimental: Unrestricted, Research -- with precise
labels rather than a blanket unrestricted claim.

One model stays resident at a time, and a conversation is model-affine once
started: switching mid-conversation discards the context state whose
preservation produced the campaign's largest gain. A router may choose at
conversation start and pins thereafter unless the user changes profiles.
Deterministic routing decides (image -> vision, explicit deep -> 4B/9B,
explicit unrestricted -> the selected experimental row, short formatting ->
0.8B, ordinary text -> 2B distill); an 0.8B classifier runs only where that is
genuinely ambiguous, since invoking it every turn adds a prefill and a decode.
The security boundary is unchanged by any tuning label: text generation
allowed, tool-call proposal observable, tool execution refused, network and
filesystem actions refused absent a validator.

Two 2B rates (9.19 and 9.43 tok/s) come from different sweeps and order
nothing, per the repository's own 20% cross-sweep rule; the lanes differ by
role, vision support, tool selection, and lineage rather than by rate.

The appliance targets five serving lanes plus an experiment lane: 0.8B-class
instant specialists (routing, drafting, lint, classification, tool selection),
the 2B fast general interactive model, the 4B balanced production default, a 7B
Coder specialist for code and repository agent work, a 9B distill deep-reasoning
quality ceiling, and a capacity lane for artifacts above 14.6 GiB. A larger
parameter count never displaces the 2B or 4B by itself; each large lane enters
by beating the incumbent on its own axis. Small models get more valuable as
large ones arrive, since a 0.8B classifier that routes only hard work to the 7B
keeps the bandwidth-expensive path from running at all -- the checkpoint
principle applied to model selection.

Neither GTT capacity nor host RAM gates the existing Q4-class large weights.
`evidence/qwen38-9b-distill-admission.md` records RADV accepting the
6,979,321,856-byte working set and the gate returning 3 on a 16,517,508,416-byte
host requirement against 15,140,962,304 available. That host formula counted the
weights twice, once as Vulkan-resident and again as a simultaneous file
envelope; `model-memory-preflight.sh:67` now computes
`required_host_bytes = required_vulkan_bytes + desktop_reserve_bytes`, which
over the same run gives 6,442,450,944 + 4,294,967,296 = 10,737,418,240 against
15,140,962,304 -- a 4.10 GiB surplus rather than a refusal. The preflight is
observational and the strict load is the authority. The 9B Q4_K_M subsequently
ran and sits archived at 1.76 tok/s decode and 11.47 prefill, displaced for
serving value. It is a VM-aware scheduling concern rather than a demonstrated
capacity exclusion, and the admission document needs a supersession note.

Quantized 7B Coder (Q4_K_M ~4.68 GB, Q5_K_M ~5.44, Q6_K ~6.25, Q8_0 ~8.1) and
9B Q4_K_M sit inside the present ceiling and are testable now. Only 7B Coder
F16 (~14 GB before KV, graph, allocator margin, and desktop residency) reaches
a boundary, and heap topology rather than the ceiling is the first variable
there: RADV's default split exposes about 10.31 GiB device-local against a
15.47 GiB aggregate budget, and `remote/radv-unified-heap.d/` sets
`radv_enable_unified_heap_on_apu=true` for the separately named
`qwen-vulkan-unified-heap` executable, merging heap visibility without a reboot
and without touching production's executable identity.

Context checkpoints change the 9B's value without changing its rate: 1.76 tok/s
decode stays slow, and the natural-boundary repair removes the repeated
long-prefix reprefill that made long multi-turn use untenable.

The 9B admission contract measures the machine as it serves: subject
Qwen3.8-9B-Distill Q4_K_M under strict Vulkan placement beside the standing
~16.5 GiB qemu tenant, retaining MemAvailable at launch and its observed
minimum, server peak RSS, peak GTT and VRAM use, swap-in per sample and
cumulative, graphics-service latency, decode and prefill, temperature and
kernel hazards, and the exact termination reason. The qemu RSS is provenance
rather than an addend: `MemAvailable` already carries the VM's pressure, and
adding it again repeats the double count that invalidated the original
refusal. The preflight stays observational and the live reserve guard is the
enforcement boundary.

The result reads mechanically. A completed load and request with reserve,
swap, latency, and hazard guards intact admits the 9B beside the tenant. A
`memory_reserve_breached` or `swapin_rate_breached` termination means the 9B
conflicts with normal host tenancy and implicates the GTT ceiling not at all,
since a larger manager permits further claims on those same host pages. A
strict Vulkan allocation failure while host reserve holds is classified by
memory type and eligible heap, then retried under the reboot-free unified-heap
executable; only a unified-heap failure attributable to total eligible Vulkan
capacity produces a named subject for the 20 GiB research boot.

Order: promotion -> Stage A -> current-boot default-versus-unified heap
comparison -> quantized 7B Coder admission -> 7B Coder F16 under the unified
profile -> 9B Q4 with the VM on and off -> only then decide whether a 20 GiB
research boot has a measured subject. The staged 0.8B specialists
(qwen3-zero-coder-08b, qwen3-zero-coder-v2-08b, qwen35-08b-opus-reason; strict
Vulkan loaded, unregistered) are indifferent to all of it and can run whenever
the device is free, including while the VM lives.

Related: [[qwen-gtt-and-queue-decisions]], [[qwen-laptop-host-memory-tenants]],
[[qwen-benchmark-class-policy]], [[qwen-natural-boundary-patch]].
