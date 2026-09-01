# Throughput targets, evidence regimes, and mechanism bounds

The performance program sets three serving targets on the Raven2 appliance:
20 tok/s for Qwen3.5-0.8B Q8_0, 10 tok/s for Qwen3.8-2B Distill Q4_K_M,
and 5.25 tok/s for Qwen3.8-4B Distill Q4_K_M. The targets name decode rate.
They do not name prompt processing, a `llama-bench` row, or a rate copied from
another checkpoint.

`remote/throughput-targets.tsv` records the planning baselines and their
evidence surfaces. Each row cites the top-level performance specification as
`target_evidence`; the ledger does not treat its own target value as sufficient
authority. `remote/analyze-throughput-targets.py` converts every input decimal
to an exact rational number and generates `results.tsv` atomically. The
generated table preserves numerator, denominator, 12-place decimal, unit,
state, and source path for every coefficient.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 remote/test-analyze-throughput-targets.py
PYTHONDONTWRITEBYTECODE=1 python3 remote/analyze-throughput-targets.py
PYTHONDONTWRITEBYTECODE=1 python3 remote/analyze-throughput-targets.py --check
```

The analyzer confines input, output, and evidence paths to the named repository,
rejects symlink traversal, rejects incomplete N=1 records, and leaves an
existing result unchanged when atomic replacement fails. The generated table
does not upgrade a reported baseline into a retained raw measurement. The
analyzer validates cited-path existence and target arithmetic; it does not
extract values from prose and therefore does not prove source-value agreement.

## Evidence regimes remain separate

The checkout contains several valid observations with different execution and
provenance contracts. A rate from one row cannot silently supply another row's
contract.

| Surface | 0.8B | 2B | 4B | Authority and limitation |
| --- | ---: | ---: | ---: | --- |
| Universal candidate sweep, reported paired mean | 18.53 | 9.19 | 3.34 | The model registry uses these rates. The checkout retains the synthesized table but lacks its raw arms. |
| Bandwidth ladder, reported four-block mean | - | 8.24 | 3.01 | `decode-bound-analysis.md` retains block values and arithmetic but states that the arm logs, clock rows, invocation records, and hash-bound censuses are absent. |
| Runtime-class `tg64` sweep | 15.31 | 8.09 | 3.18 | Raw logs survive, but the runner used model basenames with `--skip-hash`; the rates do not bind artifact bytes. |
| Runtime-class fixed-64 anchor rerun | - | 7.685 | 2.985 | The later anchor rerun covers 2B and 4B only and retains the same unhashed-artifact limitation. |
| Depth-wedge shallow controls | 18.04 mean | foreign-digest 9.64 mean | 3.335 mean | The 0.8B and 4B rows bind current registered digests. The nominal 2B row binds a different digest and cannot establish the registered artifact. Every row uses `llama-bench`. |
| Historical representation ABBA control | 20.15 | 10.02 | - | Both targets appear on reported matched Q8_0 or Q4_K_M control arms. The checkout lacks the historical raw ABBA bundles. |
| Fixed-64 exact-default balanced served campaign | absent | absent | absent | The hash-bound 32-token checkpoint sweep uses experimental checkpoint counts. It does not supply the fixed-64 registry-default-tuple denominator. |

The 0.8B and 2B goals therefore act first as reproducibility targets. Historical
ABBA prose reports values above both thresholds, while the registry and later
sweeps report values below them. No complete reported 4B prompt set or current
production-profile campaign meets 5.25. One retired n-gram arithmetic row
reaches 5.47, while the same configuration drafts nothing on code.

`remote/run-fixed64-served-campaign.sh` supplies the decisive orchestrator
above `remote/measure-served-decode.sh`, which supplies one served arm. The
orchestrator runs each current pinned artifact with fixed 64-token greedy
generation, fresh servers, exact registry-default tuples, and four separated slots
in balanced forward/reverse order. The retained bundle binds the model, server,
runner, request, response, summary, `predicted_n`, elapsed decode time, and
`predicted_per_second` by SHA-256. The checkout contains the fake-only contract
tests and lacks a real campaign bundle. A corrected 2B shallow arm repairs the
depth digest contradiction but does not replace the three-model serving
campaign.

The denominator has one execution surface: a structurally valid inherited SSH
session marker on a host whose measured, normalized shortname equals
`hp14-dk1xxx`. The orchestrator validates both observations before it claims an
output directory, retains only `execution_surface=hp14-ssh`,
`host_shortname=hp14-dk1xxx`, and `ssh_session=present`, and scrubs the raw
`SSH_CONNECTION` addresses and ports. These in-process observations identify
the intended execution surface; the invoking SSH client's host-key and account
checks remain the authentication authority.
Each arm then records the same three fields beside observed nice 19 and idle
I/O values. The sealed summarizer rejects any mismatch. Local execution and
Edge execution use nice 0 with normal or best-effort I/O and therefore remain
outside the fixed-64 campaign rather than inheriting the laptop's contention
policy.

## Fixed-64 served campaign contract

The runner accepts one absolute output directory whose final path is absent.
One invocation claims that path, runs all twelve arms inside one execution
window, and refuses every later reuse. A failed or interrupted directory stays
as retained partial evidence. A later run uses a new path because resuming
after a machine-state discontinuity would combine two windows and invalidate
the balanced denominator.

The block order is forward, forward, reverse, reverse:

```text
0.8B 2B 4B | 0.8B 2B 4B | 4B 2B 0.8B | 4B 2B 0.8B
```

Every model occupies four positions whose mean is 6.5. This ordering creates
one same-model adjacency at a block boundary; alternating every block creates
three. The schedule therefore retains the equal-position invariant while
separating more of the four observations. The ordering addresses the retained
finding that between-arm machine state dominates within-arm repetitions. The
ordering does not make the four observations independent or erase thermal,
clock, or background-load drift.

The registry snapshot fixes the registry-default tuples before slot one. The
0.8B row remains a `candidate`; the 2B and 4B rows remain `production`:

| Model ID | Role | Context | Batch | Ubatch | K cache | V cache | Flash Attention | Ctx checkpoints | Minimum step | Target |
| --- | --- | ---: | ---: | ---: | --- | --- | --- | ---: | ---: | ---: |
| `qwen35-08b` | `compact-text` | 8192 | 128 | 32 | `q8_0` | `q4_0` | on | 2 | 8192 | 20 |
| `qwen38-2b-distill` | `fast-text` | 24576 | 128 | 32 | `q8_0` | `q4_0` | on | 2 | 8192 | 10 |
| `qwen38-4b-distill` | `balanced-text` | 24576 | 128 | 32 | `q8_0` | `q4_0` | on | 2 | 8192 | 5.25 |

`qwen-webui-control.sh` forwards the retained registry, quarantine, validated
tuple, checkpoint, batch, and ubatch values across the tmux boundary. The child
therefore consumes the configuration whose identity the outer runner records,
instead of re-reading an ambient sibling ledger after the campaign starts.

Every arm uses `low-async`, one fresh guarded server, one fixed prompt,
`max_tokens=64`, `temperature=0`, `top_k=1`, seed 1, `ignore_eos=true`, and
thinking disabled. The response must report exactly 64 predicted tokens and a
positive integral prompt count plus finite positive prompt and decode times and
rates. The verifier recomputes the prompt rate as
`1000 * prompt_n / prompt_ms`, reconciles the count, time, and rate against the
closed child-summary schema, and requires one prompt count per model across its
four identical requests. The pinned llama.cpp implementation defines and
serializes that relation in
[`server-common.h`](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/tools/server/server-common.h#L414-L420)
and
[`server-common.cpp`](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/tools/server/server-common.cpp#L67-L79).
Each arm records both checkpoint values
in `inputs.txt`, `summary.tsv`, and `models-resolved.tsv`. The sealed verifier
requires exactly one `--ctx-checkpoints 2` and one
`--checkpoint-min-step 8192` in the complete captured server argv. The server
derives its first generated token from the prompt logits, so `predicted_ms`
covers 63 post-first steps. The independent check is therefore:

```text
recomputed_tok_s = 1000 * (predicted_n - 1) / predicted_ms
```

Using 64 in the numerator would overstate the served rate by 64/63, or about
1.587%. Each model meets its target only when all four arms meet the threshold.
The mean, median, range, and span remain descriptive and cannot override one
failing arm.

The bundle writes the schedule, configuration snapshots, Git index/status/HEAD
witnesses, source and publisher-pinned model identities, one directory per arm,
atomic arm status, atomic summaries, and a before/after identity reconciliation.
Each arm retains the request, response, child summary, launch and teardown
output, complete running session status, exact server process identity and argv,
server log, telemetry log, graphics-latency log, and kernel-hazard log. The
runner captures the live PID and argv before teardown, then copies runtime logs
only after teardown lets the kernel watcher drain. A valid arm requires one
terminal `watch_stop_utc` marker and rejects every retained reset, timeout,
fault, device-loss, or out-of-memory row, including a row appended during
teardown. The session treats a nonzero final watcher status as terminal.
The
identity denominator includes the RADV ICD bytes. The verifier requires the
complete canonical llama.cpp argv, including device, split mode, GPU layers,
tensor override, fit policy, thread counts, caches, checkpoints, and tuple; a
later short alias or underscore-normalized override invalidates the bundle.
The campaign executes the launch closure from a retained Git archive and
rejects a tracked-source change across the twelve-arm window.

The runner builds `.SHA256SUMS.new`, verifies its byte coverage, recomputes both
summaries, validates terminal semantics against the staged manifest, and only
then renames the file to `SHA256SUMS`. The final manifest covers every regular
bundle artifact except itself and becomes the last file published on a valid
run. A valid below-target campaign still seals its observations, exits nonzero,
and records `target_state=unmet`; measurement validity never becomes target
attainment by implication.

The hardware invocation names the same state directory that owns the Vulkan
workload lease:

```sh
campaign=$HOME/qwen-served-decode/fixed64-$(date -u +%Y%m%dT%H%M%SZ)
QWEN_SERVED_CAMPAIGN_STATE_DIRECTORY=$HOME/qwen-webui-state \
QWEN_VULKAN_WORKLOAD_LOCK=$HOME/qwen-webui-state/vulkan-workload.lock \
    remote/run-fixed64-served-campaign.sh "$campaign"
```

An ordinary Web session acquires the campaign-control lease on descriptor 9
before it removes shared status or creates tmux state. A dedicated holder keeps
that same open file description locked until the exact tmux session ID and
creation timestamp disappear. The campaign holds descriptor 9 for its full
twelve-arm window, so ordinary startup and campaign startup exclude each other
across every mutation rather than relying on a short preflight probe. Both tmux
children and campaign runners prove descriptor 9 closed at their execution
boundaries.

The outer orchestrator acquires the host-wide workload lease on descriptor 8,
and every detached arm runner inherits that descriptor. An abrupt outer-holder
exit therefore leaves the lease held for the remaining arm lifetime. Each arm
runner atomically publishes a carrier proof that names its own PID, start tick,
and inherited descriptor before launch. The runner closes descriptors 8 and 9
only on the launcher and teardown command boundaries, before either command can
contact or create the tmux server. This split prevents tmux from retaining the
lease after an arm while preserving serialization and a verifiable live carrier
through an outer `SIGKILL`. The deterministic tests kill the outer acquirer,
verify the carrier through the production verifier and image teardown check,
observe a second exclusive request refused, reject an unrelated open descriptor
for the same inode, and observe the lock available after the carrier exits.

The campaign requires Linux 6.9 or newer because Linux 6.9 adds
`PIDFD_SIGNAL_PROCESS_GROUP`. The preflight runs
`signal-process-group.py --check` before it claims the campaign output path.
Signal delivery opens a pidfd for the recorded runner PID, verifies the recorded
`/proc` start tick, requires the runner to own both its process group and
session, and sends HUP, INT, or TERM with the process-group flag. A recycled PID,
non-leader identity, unavailable kernel flag, or signaling error produces a
fail-closed terminal scope. The stable pidfd prevents stale numeric process-group
identity from selecting a later process. The Linux
[`pidfd_send_signal(2)`](https://man7.org/linux/man-pages/man2/pidfd_send_signal.2.html)
interface and the
[`PIDFD_SIGNAL_PROCESS_GROUP` addition](https://github.com/torvalds/linux/commit/e1fb1dc08e73)
provide the primary kernel authority.

A nonzero arm runner or a catchable campaign signal masks HUP, INT, and TERM
while the outer holder runs emergency teardown. The recovery path retains
descriptor 8, closes descriptors 8 and 9 only in each teardown child, records
every attempt, and retries after five seconds until teardown proves absence.
The path verifies that a second exclusive request remains refused before and
after teardown. Any emergency evidence-write failure leaves the recovered
campaign in a fail-stop loop with the workload lease retained. A new campaign
removes stale same-UID regular proof files only after acquiring a new exclusive
kernel lease.

Simultaneous `SIGKILL` delivery to both the outer holder and the arm runner
bypasses both in-process recovery actors. The detached tmux workload owns
neither lease descriptor, so that double-kill boundary cannot preserve
serialization. The operator must treat that case as an external recovery event
and prove workload absence before starting another GPU workload.

`verify-external-vulkan-lease.py` proves that a live same-UID process with the
recorded start time and descriptor owns the expected kernel lock and that a
second exclusive holder is refused. The verifier opens the lock once with
`O_NOFOLLOW`, binds every holder and contention check to that descriptor's
device and inode, requires the descriptor-local `/proc/PID/fdinfo/FD` whole-file
`FLOCK ADVISORY WRITE` row, and rejects a pathname replacement during
validation. The fdinfo row binds the exact open file description even when the
global `/proc/locks` owner PID still names the departed historical acquirer.
The Linux 6.8
[`__show_fd_locks` implementation](https://github.com/torvalds/linux/blob/v6.8/fs/locks.c#L2828-L2844)
emits a descriptor row only when the queried file object and lock owner match.
Linux same-UID process visibility lets
another process reproduce those public holder fields. The proof therefore
establishes cooperative same-UID lock liveness and inode identity; it does not
authenticate delegation from the recorded holder to an arbitrary caller. The
campaign supplies the proof through its private `0600` state path, and the
appliance treats all processes under that UID as one cooperative operator
boundary rather than as mutually hostile principals. The proof's
`source_revision` field remains descriptive; the verifier does not authenticate
that field.

`remote/test-run-fixed64-served-campaign.sh` exercises the full contract with
tiny fake artifacts and enforces an exact 91-check denominator. The checks cover
ordering, slot balance, ambient sanitization, publisher identity, exact token
count, prompt count/time/rate domains and coherence, response-child
reconciliation, closed child-summary fields, decode timing coherence, target
failure, immutable output, child and teardown
failure, effective argv aliases, closed input schema, the full identity
denominator, RADV ICD identity, request/model/runner/source drift, atomic
summary and manifest publication, descriptor-bound runtime model and executable
identity, both workload leases, stale proof removal,
TERM recovery, runner `SIGKILL` retry and fail-stop behavior, outer `SIGKILL`
descriptor inheritance, and host-wide serialization. The companion image
teardown suite rejects unproved and stale external holders while accepting a
verified holder. The descriptor-bound verifier test injects a lock-path inode
replacement. The tests start no real server, model, GPU, or remote workload.

Each served arm hashes the model through descriptor 7 and binds the publisher
artifact ID, registry filename, device, inode, and byte count in
`runtime-inputs.json`. The runner carries that identity through the tmux
command. The capacity policy re-stats the model descriptor, opens the registry
once on a private descriptor, validates one unique 22-field row, matches the
publisher filename, and caches the row before constructing server policy.
Renaming, unlinking, or atomically replacing the logical pathname therefore
changes neither the bytes opened by llama-server nor the registry ceiling,
cache geometry, quarantine row, validated depth, or checkpoint count. The tuple
does not detect an in-place, same-size write to the open inode after hashing;
the current contract records that residual rather than claiming immutable model
contents.

## Exact target coefficients

For baseline rate `r` and goal `g`, the analyzer derives:

```text
baseline_latency_ms       = 1000 / r
target_latency_ms         = 1000 / g
required_latency_removal  = 1000 / r - 1000 / g
required_speedup          = g / r
required_time_fraction F  = 1 - r / g
minimum_owned_fraction p  = F / (1 - 1 / s)
target_logical_GB_s       = streamed_bytes_per_token * g / 1e9
```

The planning ledger deliberately uses the 18.53 universal mean for 0.8B and
the later 8.24 and 3.01 bandwidth means for 2B and 4B. The ledger keeps the
more conservative later surfaces visible instead of selecting the most
favorable historical arm. The two surfaces are non-substitutable and differ
by 11.0 to 11.5% on their shared checkpoints, so a row-to-row comparison
across this table carries that cross-sweep offset inside it: the 0.8B row's
stated gap of 7.35% is smaller than the offset between the surfaces the
table mixes, and a target decision on that row waits for all three
baselines measured inside one sweep.

| Model | Baseline to target | Speedup | Current to target latency | Removal | Removed fraction | Target logical GB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 0.8B | 18.53 to 20 | 1.079330815x | 53.966541 to 50.000000 ms/token | 3.966541 ms | 7.3500% | 16.017638400 |
| 2B | 8.24 to 10 | 1.213592233x | 121.359223 to 100.000000 ms/token | 21.359223 ms | 17.6000% | 12.634350080 |
| 4B | 3.01 to 5.25 | 1.744186047x | 332.225914 to 190.476190 ms/token | 141.749723 ms | 42.6667% | 14.163641856 |

The generated 4B baseline bandwidth equals 8.12048799744 decimal GB/s. The
separately reported bandwidth-table mean equals 8.11 GB/s after averaging the
four rounded block values. The two figures describe related inputs and remain
distinct.

| Model | 2x mechanism ownership | 4x mechanism ownership | Unbounded ownership | Additional bound |
| --- | ---: | ---: | ---: | --- |
| 0.8B | 14.7000% | 9.8000% | 7.3500% | A close matched control can decide the target without a code change. |
| 2B | 35.2000% | 23.4667% | 17.6000% | The reported 10.02 ABBA control proves reachability only on its historical harness surface. |
| 4B | 85.3333% | 56.8889% | 42.6667% | A 31/19 local speedup requires 110.2222% ownership and therefore cannot lift the whole 3.01 tok/s path to 5.25. |

The 4B row supplies the strongest scope adjustment. A fast microkernel cannot
reach 5.25 unless the microkernel owns enough measured token time. A
`31/19 = 1.6316x` local gain falls short even when the mechanism owns the whole
3.01 tok/s baseline. The optimization program must combine surfaces or produce
a larger local speedup.

## N=1 speculation requires a structural cost reduction

The reported N=1 arm records a 463.1 ms two-column target pass and a 66.4 ms
draft pass. With acceptance `a`, the idealized rate is:

```text
rate = 1000 * (1 + a) / (draft_pass_ms + target_pass_ms)
```

Perfect acceptance at current cost reaches 3.777148 tok/s. A free draft at the
current target-pass cost reaches 4.318722 tok/s. Both ceilings miss 5.25. The
current costs would require acceptance 1.779875, which lies outside the
physical interval from zero to one.

| Acceptance | Target-pass limit with 66.4 ms draft | Removal from 463.1 ms | Fraction removed |
| ---: | ---: | ---: | ---: |
| 0.846 | 285.219048 ms | 177.880952 ms | 38.41% |
| 0.934 | 301.980952 ms | 161.119048 ms | 34.79% |
| 1.000 | 314.552381 ms | 148.547619 ms | 32.0768% |

The perfect-acceptance row gives the least demanding bound. A mechanism with
local speedup `31/19` must own 82.865043% of the two-column target pass to
remove the required 32.076791%. The older 47.4% ownership figure prices the
superseded 4.5 tok/s target and cannot govern the 5.25 tok/s program.

The measured one-column target pass costs 323.4 ms. Perfect acceptance with a
66.4 ms draft reaches only 5.1308 tok/s, so recovering the one-column target
cost alone still misses 5.25. At acceptance 0.934 and a 323.4 ms target pass,
the draft pass must fall from 66.4 ms to 44.981 ms. The 4B route therefore
needs target-pass work plus draft work, or a target-pass result below the
one-column historical cost.

## gfx902 exposes mixed MAD but lacks accelerated dot

Primary sources correct a stale mechanism statement in the earlier execution
ladder:

| Predicate | Primary source | Bounded conclusion |
| --- | --- | --- |
| Raven maps to gfx target 90002 | [Linux v7.0 `kfd_device.c`](https://github.com/torvalds/linux/blob/v7.0/drivers/gpu/drm/amd/amdkfd/kfd_device.c#L301-L313) | The target maps to ISA 9.0.2. |
| `gfx902` names ISA 9.0.2 | [LLVM `GCNProcessors.td`](https://github.com/llvm/llvm-project/blob/937e353fb22173c5976af9ae03352f16f9c8df2a/llvm/lib/Target/AMDGPU/GCNProcessors.td#L146-L149) | LLVM's processor model matches the kernel mapping. |
| ISA 9.0.2 carries `FeatureMadMixInsts`; 9.0.4 introduces `FeatureFmaMixInsts`; 9.0.6 adds dot features | [LLVM `AMDGPU.td`](https://github.com/llvm/llvm-project/blob/937e353fb22173c5976af9ae03352f16f9c8df2a/llvm/lib/Target/AMDGPU/AMDGPU.td#L1943-L1964) | gfx902 supports MAD-mix and lacks the later FMA-mix and dot feature sets. |
| LLVM selects `V_MAD_MIX_F32` under `HasMadMixInsts` | [LLVM `VOP3PInstructions.td`](https://github.com/llvm/llvm-project/blob/937e353fb22173c5976af9ae03352f16f9c8df2a/llvm/lib/Target/AMDGPU/VOP3PInstructions.td#L455-L499) | Mixed FP16-input, FP32-output MAD is a legal compiler target. |
| Mesa reports packed 16-bit math, family-limited FMA-mix, and an explicit accelerated-dot family predicate | [Mesa `ac_gpu_info.c`](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/common/ac_gpu_info.c#L329-L339) | Raven exposes packed 16-bit arithmetic and lacks Mesa's FMA-mix and accelerated-dot predicates. |
| ACO preserves explicit FP32 fused `fma` when the target exposes only unfused MAD-mix | [ACO NIR selection](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/compiler/instruction_selection/aco_select_nir_alu.cpp#L1931-L1954) and [mix optimization](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/compiler/aco_optimizer.cpp#L843-L883) | The pinned Q4_K shader's explicit `fma` chain is not an ACO MAD-mix miss on Raven. Eligible terminal multiply or deliberately non-fused expressions form a separate semantic surface. |

A session-only LLVM 22.1.8 probe accepts `v_mad_mix_f32` for `-mcpu=gfx902`,
rejects `v_dot2_f32_f16` for gfx902, and accepts `v_dot2_f32_f16` for gfx906;
the checkout retains neither commands nor output. Processor-specific TableGen
establishes instruction legality independently. A candidate probe begins only
with a terminal multiply or an expression whose non-fused rounding and denormal
behavior is intentional. It fails when ACO emits no useful `v_mad_mix_f32`,
compiled resources regress, matched target-pass time stays inside variation,
or the candidate violates its declared numeric oracle.

## Successful-run attribution precedes shader edits

Pinned llama.cpp already discovers `VK_KHR_pipeline_executable_properties` and
queries executable statistics. RADV returns VGPR, SGPR, spill, code-size, LDS,
scratch, and maximum-wave fields through
[`radv_GetPipelineExecutableStatisticsKHR`](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/amd/vulkan/radv_pipeline.c#L837-L863).
Pinned llama.cpp stores only the NVIDIA-named `Register Count` field in its
[`register_count` member](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/ggml/src/ggml-vulkan/ggml-vulkan.cpp#L3048-L3084).
RADV publishes the exact names through Mesa's
[`shader_stats.xml`](https://gitlab.freedesktop.org/mesa/mesa/-/blob/889476855143e855a7f92989251f09fb3b690cda/src/util/shader_stats.xml#L104-L113).
A Raven census must store those names and validate each statistic format before
the fields become target evidence.
The Vulkan extension defines the statistics as a debugging and performance
surface, so field names and meanings remain implementation-defined rather than
portable performance counters.

[Vulkan timestamp queries](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#queries-timestamps)
write device timestamps on queue families whose `timestampValidBits` is
nonzero. The host converts deltas with `VkPhysicalDeviceLimits::timestampPeriod`.
A decisive census therefore writes timestamps around dispatches, reads query
results at natural synchronization points, and joins each row to operation,
tensor type and shape, specialization constants, resource statistics, and
dispatch count. A per-record fence wait changes the schedule and cannot supply
serving attribution.

The hp14 SSH profiling environment follows this exact nesting because
`remote/radv-low-priority-env.sh` scrubs incoming diagnostic variables and
applies the laptop workload policy:

```sh
remote/qwen-exec-idle-priority.sh \
remote/radv-low-priority-env.sh \
env GGML_VK_PIPELINE_STATS=mul_mat_vec_q4_k_f16_f32 COMMAND ARGUMENTS...
```

The eventual timestamp campaign first runs logger-off, logger-on, logger-on,
logger-off against an identical binary. The ABBA control measures query and
synchronization overhead before any timestamp-derived attribution supports an
end-to-end gain. Every real fixed-64 hp14 SSH arm retains absolute nice 19,
idle I/O, LOW RADV queue priority, and the production `low-async` comparison.
Local and Edge real workloads run at nice 0 with normal or best-effort I/O and
use neither priority wrapper above. `radv-low-priority-env.sh` also applies the
laptop's nice-19 and idle-I/O policy and therefore belongs only to the hp14
launch chain. The checkout supplies no local or Edge production profiling
launcher or retained local or Edge scheduling readback. Fake-only tests encode
the hp14 contract values as fixture data rather than workload observations. The
current work executes zero real model or GPU workloads.

## Per-model mechanism order

| Order | 0.8B | 2B | 4B |
| ---: | --- | --- | --- |
| 1 | Reproduce the serving target with the current digest; the historical ABBA control already reaches 20.15. | Reproduce the serving target with the current digest; the historical ABBA control already reaches 10.02 and the depth bundle binds a foreign digest. | Attribute successful-run GPU time and compiled resources before selecting a kernel. |
| 2 | If matched serving remains below 20, inspect the dominant dispatch and its row/workgroup specialization. | If matched serving remains below 10, inspect shape-specific Q4_K row/workgroup selection before changing representation. | Sweep column-aware `NUM_ROWS` values 1, 2, and 4 while preserving wave64 and shared Q4 unpack. |
| 3 | Confirm explicit `fma` remains fused; inspect only eligible terminal or deliberately non-fused expressions for MAD-mix. | Inspect stock ACO ISA and compiled resources; target a demonstrated compiler or resource miss. | Shorten C=2 accumulator and activation live ranges only when resource statistics show a higher VGPR bucket, spill, or lower maximum waves. |
| 4 | Reject any code change whose gain stays inside matched run variation or violates its numeric oracle. | Reject a candidate whose matched effect stays inside variation, violates serving parity, or misses its mechanism prediction; compare the cumulative accepted portfolio with 21.359 ms. | Test MAD-mix only on an eligible expression with declared rounding and denormal behavior; never label the route FP16 dot hardware. |
| 5 | - | - | Attribute and reduce the 66.4 ms draft head because one-column target-pass recovery alone still misses 5.25. |

The Q4_K shader's persistent accumulator lower bound equals `C * R` FP32
values per thread for column count `C` and row count `R`. Lexical activation
loads equal `4 * C * R` `vec4` loads per superblock before compiler common
subexpression elimination. The one-subgroup reduction uses zero reduction LDS;
other reductions consume `4 * C * R * W` bytes for workgroup width `W`. gfx902
wave64 allocates VGPRs in groups of four from 256 VGPRs per SIMD, so occupancy
transitions require compiled resource values rather than timing folklore.

Every mechanism remains a hypothesis until a retained campaign supplies the
named falsifier. The target table remains a specification and coefficient
ledger until one serving campaign reaches all three rates under their exact
registry-default tuples.
