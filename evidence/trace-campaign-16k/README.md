# The 16K submission trace campaign: T1 completes where the quarantine record wedged

`remote/run-trace-campaign.sh` ran three arms of `qwen38-4b-distill` Q4_K_M at
depth 16384 under the served cache triple, `q8_0`/`q4_0` with Flash Attention
on. The retained metadata associates the trace-capable build with commit
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`, and the retained closure records
bind the executed model and `llama-bench` files by size and SHA-256.
Every arm ran `QWEN_VULKAN_PROFILE=custom` with `GGML_VK_MAX_NODES_PER_SUBMIT=16`
and `GGML_VK_SERIALIZE_SUBMISSIONS=1`, because
`ggml/src/ggml-vulkan/ggml-vulkan-submit-trace.h` throws
`GGML_VK_SUBMIT_TRACE requires GGML_VK_SERIALIZE_SUBMISSIONS` at device
creation and `mark_completed` -- the call that advances
`last_completed_serial` -- runs on the serialized path alone. `llama-bench`
ran under `LLAMA_NO_CPU_FALLBACK=1` with `-dev Vulkan0 -ot '.*=Vulkan0'`, the
placement `qwen-capacity-policy.sh` gives the server.

## Retained-evidence limit

The imported directory omits `campaign.log`. That driver log was the only
campaign output that recorded the source-gate result or bypass notice, arm
start and stop records, and final restoration result. The per-arm logs,
summary, metadata, and closure records cannot distinguish an enforced source
gate from a run admitted with `QWEN_TRACE_SKIP_TRACE_SOURCE_GATE=1`.
Consequently, the retained evidence proves the file identities and arm
outputs described below, but it does not independently prove that the
executed binary came from a source tree accepted by the trace-source gate.

That historical gap closes only when either the original `campaign.log`
arrives with its pre-sanitization SHA-256 and provenance plus a sanitized Git
copy, or an authentic campaign rerun retains `campaign.log` beside all arm,
closure, metadata, and restoration outputs. Until one of those inputs exists,
the commit association remains metadata rather than a reproduced source-gate
result.

## Falsification criterion

`evidence/depth-versus-submission-geometry.md` validated batch 128/ubatch 32
at depth 16384 and recorded a compute-ring wedge at batch 2048/ubatch 512 at
the same depth and cache triple under `llama-bench`'s own submission
defaults, unserialized. The registered prediction for T1 was that raising
batch to 2048 reproduces that wedge under the traced, serialized regime: a
wedge would let the per-dispatch record attribute the failure to a node,
operation, and pipeline, closing the class the quarantine record left open.

**T1 did not wedge.** Batch 2048 with ubatch 32, serialized, traced, at depth
16384 completed with zero ring resets, zero GPU faults, and a passing
control. The deviation is the finding: raising batch alone does not reproduce
the quarantine wedge under this regime, so the wedge's hazard is carried by
ubatch 512, by the unserialized submission regime, or by both, and this
campaign's three arms cannot separate those two variables from each other.

## The arms

| arm | depth | batch | ubatch | trace | status | resets | faults | wall_s | decode tok/s | control status | control tok/s | mclk modal | temp_c max | health | hazard_class | trace_dump |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| P0 | 16384 | 128 | 32 | off | 0 | 0 | 0 | 1456 | 1.02 | 0 | 1.20 | 933 | 97.0 | healthy | none | off |
| P1 | 16384 | 128 | 32 | on | 0 | 0 | 0 | 1885 | 1.17 | 0 | 1.37 | 933 | 91.0 | healthy | none | present |
| T1 | 16384 | 2048 | 32 | on | 0 | 0 | 0 | 1636 | 1.09 | 0 | 1.17 | 933 | 91.0 | healthy | none | present |

Every arm carries `max_nodes_per_submit=16`, `serialize_submissions=1`,
`cache_k=q8_0`, `cache_v=q4_0`, `flash_attn=on`. P0 and P1 differ in the
trace flag alone and both completed, which establishes that the
trace-capable build decodes at depth without the instrumentation causing a
failure of its own. T1 raises batch to the geometry
`evidence/depth-versus-submission-geometry.md` wedged at while leaving
ubatch at 32 -- the quarantine wedge ran batch 2048 **and** ubatch 512
together, so T1 tests batch 2048 with ubatch 32, not the full quarantine
tuple.

The production closure carries a `depth_validation` claim of
`validated_filled_depth=16384` under the `low-async` submission profile,
whose 16384/128/32 arm decoded 3.34 tok/s
(`evidence/depth-versus-submission-geometry.md`). **The decode rates in this
table belong to the serialized-regime triple this campaign ran under and do
not compare against that 3.34 tok/s or against any other `low-async` or
`low-serialized` figure.** `GGML_VK_SERIALIZE_SUBMISSIONS` alone carries a
measured 1.348 to 2.718 decode tok/s difference against the unserialized
profile (`CLAUDE.md`), and P0's own 1.02 tok/s at the identical 16384/128/32
geometry the production row served at 3.34 is consistent with that
mechanism: this campaign's serialization forces a fence wait every submission,
which the production regime does not pay.

## What the trace dump in P1 and T1 contains

`ggml_vk_print_device_lost_info` prints the per-dispatch record -- submission
serial, node index, operation, pipeline, dispatch geometry, and bound buffers
-- from the device-lost catch sites alone
(`evidence/vulkan-submit-trace-design.md`). Neither P1 nor T1 threw
`vk::DeviceLostError`; both completed at status 0. `p1.log` and `t1.log` each
run to 10 lines and the only line containing the substring `submission trace`
is the startup banner `ggml_vulkan: AMD Radeon Graphics (RADV RAVEN2):
submission trace = on`, printed once at device creation regardless of whether
the device is later lost. Neither log carries a submission serial, a node
index, an operation name, or a buffer record. **Neither arm emitted a
per-dispatch dump. The retained logs therefore expose neither a record count
nor a last-completed serial.** The trace implementation appends an in-memory
ring record for each `vkCmdDispatch` while tracing is enabled and advances and
retires serials during successful serialized execution. Those records existed
during P1 and T1, but the successful process exits discarded them without a
device-loss print path, so their exact counts and serial values are
unavailable from the retained evidence.

`run-trace-campaign.sh`'s `trace_dump` field reads `present` for both P1 and
T1 because its detector, `grep -q 'submission trace' "$arm_log"`, matches the
startup banner as well as the per-dispatch dump header the design doc names.
The two arms produced no per-dispatch dump; the correct semantic reading of
both rows is `not-triggered` -- an arm that ran traced and completed without
loss -- and the `trace_dump=present` value the summary carries is a false
positive of the substring match rather than evidence that a dump printed.
A future campaign should tighten the detector to a string the banner cannot
produce, such as the per-record prefix, before trusting the `present` value
on a completed arm.

`p1.dmesg.txt` and `t1.dmesg.txt` each carry a short kernel delta -- a
`vmmon` module load and `userif` link-state events on P1, `userif` link-state
events alone on T1 -- with no `ring reset`, `device wedged`, `GPU reset`,
`page fault`, or `PROTECTION_FAULT` line in either arm's or its control's
delta, which is what the summary's `hazard_class=none` and `health=healthy`
state. `p0.dmesg.txt` and every `*.control.dmesg.txt` file are empty. No
`*.kernel-signature.txt` file exists for any arm, because
`run-trace-campaign.sh` extracts that signature only when `arm_status`
is nonzero and every arm here exited 0.

## What this campaign separates and what it confounds

Separated: the trace-capable build itself does not cause a failure at
16384/128/32 (P0 against the production-validated geometry, differing in
build and submission regime alone). The trace instrumentation itself does not
cause a failure at that geometry (P0 against P1, differing in the trace flag
alone). Batch 2048 with ubatch 32, serialized, does not wedge at depth 16384
(T1).

Confounded: T1 changes batch to 2048 while leaving ubatch at 32, so it never
runs the ubatch-512 half of the quarantine tuple. T1 also runs under
`GGML_VK_SERIALIZE_SUBMISSIONS=1`, which the quarantine wedge did not --
that wedge ran under `llama-bench`'s own defaults, unserialized. A campaign
that completes under serialization at batch 2048/ubatch 32 cannot say whether
an unserialized batch 2048/ubatch 32 arm would complete, because
serialization changes queue depth and fence-wait timing beside the trace's
own requirement. The three arms here cannot attribute the quarantine wedge to
ubatch 512, to the unserialized regime, or to their combination.

## Next discriminating arms, in order

1. **2048/64** serialized, traced -- the first ubatch step above T1's 32,
   holding batch fixed.
2. **2048/128** serialized, traced -- the served depth-16384 batch value
   the standalone row already validated, paired with a mid-range ubatch.
3. **2048/256** serialized, traced -- brackets 512 from below under the
   serialized regime.
4. **2048/512 serialized**, traced -- the full quarantine batch/ubatch tuple,
   still serialized. Comparison with the lower-ubatch traced arms tests whether
   the hazard appears when ubatch reaches 512 under the serialized traced
   regime; the result alone cannot isolate serialization because the original
   quarantine run had tracing disabled.
5. **2048/512 serialized, trace off** -- the same geometry and serialized
   regime as arm 4 with instrumentation disabled. Arm 4 against arm 5 measures
   the trace flag alone at the full geometry.
6. **2048/512 unserialized, trace off** -- the literal quarantine geometry,
   run last because the trace requires serialization and cannot instrument
   it. Arm 5 against arm 6 changes serialization alone while holding geometry
   and tracing fixed. A pass in arm 5 and wedge in arm 6 supports serialization
   as the discriminating condition; matching outcomes leave serialization
   unisolated. Any outcome that disagrees with the original wedge requires an
   authentic reproduction before a causal conclusion moves.

## Production closure

`restore.log` records the six-patch replay accepted at
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0` and `restore-closure.tsv` records
the promoted `llama-server`'s single-executable load closure
(`bytes=57696808`, `sha256=4117a9c4d58e530c3c5ef6934596ae6d257ca61ef80c5f0f8a5ee71d1d63ca79`),
matching the artifact manifest with no drift. The campaign's own trace build
closure (`trace-build-closure.tsv`) names the `llama-bench` binary the three
arms ran, `bytes=54199184`,
`sha256=5ff436691bf456830dc4cb889e57c8de314fdd4dc0ec4882550995f2f3a17828`,
which is a distinct executable from the promoted server and is not part of
the serving path. `trace-campaign-metadata.tsv` binds every retained row to
`model_sha256=dec96e8cf2e11b613bb46513dec485377f9ca5a351e71712ee0e244f287c6790`
and `bench_sha256=5ff436691bf456830dc4cb889e57c8de314fdd4dc0ec4882550995f2f3a17828`.
The production closure restored unchanged; the laptop serves the five-patch
binary, not the six-patch trace binary, after this campaign.

## `remote/validated-tuples.tsv`: no rows added

`remote/validated-tuples.tsv`'s columns are `tuple_id`, `model_id`,
`runtime_mode`, `context`, `batch`, `ubatch`, `cache_k`, `cache_v`,
`flash_attention`, `threads`, `parallel`, `projector_state`, `backend`,
`status`, `evidence`, `llama_commit`, `runner_sha256`, `kernel`, `mesa`,
`amdgpu`, `measured_at`. No column carries `GGML_VK_MAX_NODES_PER_SUBMIT`,
`GGML_VK_SERIALIZE_SUBMISSIONS`, or `GGML_VK_SUBMIT_TRACE`, and
`remote/model-registry.sh`'s `validate_tuple_ledger` rejects a duplicate
`tuple_id`. The ledger already carries
`qwen38-4b-distill-d16384-b128-ub32` as `validated` from
`evidence/depth-versus-submission-geometry.md`, measured under the
unserialized production regime; P0 and P1 ran the identical context, batch,
and ubatch under `GGML_VK_SERIALIZE_SUBMISSIONS=1` and decoded 2.86 to 3.27
times slower than that row's 3.34 tok/s, which is the same regime difference
this README's rate table names. Reusing that tuple_id for P0 or P1 would collide under the ledger's
own uniqueness rule; minting a new tuple_id for the identical
(model, context, batch, ubatch, cache, Flash Attention) tuple the existing
row already claims, with no column to record what actually differs, would
read as a second measurement of the same production tuple and silently
carry the serialized-regime rate into a field a reader takes as comparable
to `low-async`. T1's `(2048, 32)` pair has no existing row and is not itself
a production tuple -- it never runs unserialized -- so it is a new geometry
this ledger has no honest column for either.

No row is appended for P0, P1, or T1. A `runtime_mode` or `backend` addendum
that names the submission triple is the fix that would let this campaign's
arms enter the ledger without overclaiming; until that column exists, the
serialized-regime measurements stay in this directory alone.
