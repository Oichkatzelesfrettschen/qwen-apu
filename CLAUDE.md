# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

`~/AGENTS.md` loads through the user memory and supplies the shared baseline.
This file holds the repository doctrine and wins inside this tree.

## The repository runs on two machines

The Git tree lives on the workstation. The runtime lives on a Raven2 laptop
reached over SSH. `qwen-laptop` stands for that host throughout this
repository, and a working copy substitutes its own name. Editing a script here
changes nothing on the laptop until it is copied:

```sh
rsync -a remote/ eirikr@qwen-laptop:~/qwen-laptop-setup/remote/
```

Every `remote/` script executes from `~/qwen-laptop-setup/remote/` on the
laptop. A change tested without that copy tests the previous revision.

The laptop runs the appliance by itself. `remote/build-llama-vulkan.sh` builds
there with the distribution toolchain, the fetch scripts pull the checkpoint
from its pinned revision, and the launch and teardown scripts need nothing
else. That path is what the repository requires, and it stays free of
containers, daemons, and package managers beyond the distribution's own.

Two workstation-side helpers exist because two 2.3 GHz cores are slow, and
neither is a dependency. `remote/build-llama-ui.sh` runs Node where Node
already is and copies static files over. `remote/build-llama-on-workstation.sh`
builds llama.cpp inside an `ubuntu:24.04` container on the workstation and
rsyncs plain binaries; the image supplies the glibc 2.39 the laptop links
against, and the container stays on the workstation. What reaches the laptop is
an ELF executable.

## Hardware sets every ceiling in this repository

AMD Athlon Silver 3050U, Raven2, two Zen+ cores at 2.3 GHz, two Vega compute
units, 29 GiB of shared DDR4. Measured by `remote/run-placement-sweep.sh`
through `llama-bench`, free of the guarded launch path:

| Placement, Qwen3.5-4B Q4_K_M | prefill tok/s | decode tok/s |
| --- | ---: | ---: |
| All layers on Vulkan | 20.88 | 2.84 |
| 27 of 32 layers on Vulkan | 22.08 | 2.42 |
| CPU only, 2 threads | 16.09 | 2.63 |
| CPU only, 1 thread | 17.17 | 2.02 |

Every tested hybrid placement lost to full Vulkan, and decode rises from the
9-layer minimum through the fully offloaded endpoint. The ladder dips below
CPU-only at its first partial point: a split adds CPU-to-Vulkan synchronization
and activation transfers while both sides draw on the one DDR4 controller, so
the placements share a bandwidth domain instead of combining two.

Memory is trained at the DIMMs' rated DDR4-2133 speed. Both UMC channels report
`0x00000520` at SMN register `0x50200`; the DDR4 ratio in bits 7:0 is `0x20`,
and `(0x20 / 3) x 200` is 2133.33 MT/s. Their timing registers decode to
15-15-15-36, tRP 15, and tRC 51, which match the fastest profile in both Crucial
CT16G4SFD8213 SPD EEPROMs. Rank derating and an HP firmware speed cap are ruled
out for the installed population.

On this SMU10 path, `pp_dpm_mclk` is a misleading sysfs name: the kernel obtains
its selected value with `PPSMC_MSG_GetFclkFrequency`. The 933 and 1067 MHz
entries are dynamic fabric-clock states, not alternate DRAM training results,
and retained Vulkan telemetry shows 1067 MHz selected under load. Theoretical
dual-channel peak is therefore `2 x 8 bytes x 2133 MT/s = 34.13 GB/s`. The
15.44 GB/s two-thread host read is about 45% of that peak and bounds the two
Zen+ cores' load/store path rather than the memory controller or iGPU.

`remote/sample-gpu-clocks.sh` records dynamic FCLK beside every rate. All five
repeatability arms stayed at 933 MHz even though other retained Vulkan runs
selected 1067 MHz. The measurement spread it was added to explain is real and
lies elsewhere:
`evidence/measurement-state-and-memory-clock.md` measures 3.11 tok/s and 3.24
tok/s from identical flags ten minutes apart with `mclk` at 933 and `sclk`
peaking at 1100 in both, so a depth-0 rate on this machine carries about 4% of
uncontrolled spread that neither ladder explains.

Under desktop load that spread reaches 30.6%. `evidence/decode-bound-analysis.md`
sweeps five checkpoints four times at nice 19 and finds the 2B spanning 8.95 to
12.13 GB/s, three of those arms at 88 C with `mclk` at 933, so neither die
temperature nor memory clock orders it, and load average orders it with the
opposite sign on Q6_K. A comparison on this machine is therefore read within a
sweep, where both arms met the same machine minutes apart, and a difference
below about 20% quoted from single arms reports queue position.

A prediction band on this machine states a ratio against a checkpoint measured
in the same sweep. Four absolute bands built from the four-block means in
`evidence/decode-bound-analysis.md` all read low against the seven-checkpoint
sweep in `evidence/model-admission/universal-candidate-ladder.md`, because that
sweep ran 11.1 to 11.5% above those means on the two checkpoints common to both.
No falsifier was met, and the offset was larger than every effect the
predictions were trying to resolve, so an absolute band measures the sweep.

The registry rather than a constant sets the admitted depth.
`remote/models.tsv` carries `context_default`, `context_ceiling`, and
`context_target` per checkpoint along with the KV cache types and the
flash-attention setting, and `qwen-capacity-policy.sh` reads them.
`QWEN_CACHE_TYPE_K`, `QWEN_CACHE_TYPE_V`, and `QWEN_FLASH_ATTN` override the
cache triple, so an experiment arm runs through the served path rather than
through llama-bench alone. Any override changes the allocation tuple and must
also set `QWEN_CACHE_OVERRIDE_CONTEXT_CEILING` to a positive depth measured for
that exact tuple. The override ceiling cannot exceed the checkpoint registry
ceiling. A ceiling never exceeds a depth measured to fail.

An allocation and a validated depth are two claims and the registry carries them
as two fields. `context_ceiling` is the depth the policy admits;
`validated_filled_depth` is the deepest depth measured to fill and decode under
the row's own cache triple, Flash Attention state, `batch`, and `ubatch`. A
server that loads a 24576-token allocation has proven it can reserve the memory
and has not proven a near-full cache executes, so the 4B distill reads 24576 and
16384 in those two fields and `qwen-capacity-policy.sh` prints the gap on its
`depth_validation` line at every launch. Submission geometry belongs to the same
claim: at 16384 the same checkpoint, cache, and device wedged the compute ring
at 2048/512 and completed twice at 128/32, so `batch` and `ubatch` are registry
fields rather than constants in the argv.

`remote/probe-depth-wedge.sh` treats an output directory as a resumable evidence
ledger. `wedge-metadata.tsv` binds the ledger to the model SHA-256, model byte
count, and recovery-control length. Startup validates every retained row against
the invocation's cache K/V and Flash Attention tuple before it selects the
requested arms. A recorded arm resumes only when its summary row is structurally
complete, unique, and carries the requested depth and submission geometry, with
its bench log, clock samples, control log, and any claimed kernel delta still
present. A different model, tuple, incomplete artifact set, duplicate row, or
legacy row without model identity requires a new output directory. The retained
row also restores health and device-corruption state, so conditional arms and
terminal halt behavior remain the same across an interrupted run.

The `tier` field states what is claimed about a row and
`remote/build-router-presets.sh` turns it into what the picker offers.
`production` is a serving tuple measured safe and useful; `candidate` leaves
quality or performance unqualified with no device failure under its admitted
tuple; `quarantine` names a reset, fault, device loss, correctness hazard, or
the absence of any validated safe tuple; `archive` is a valid artifact displaced
or too slow to serve; `rejected` lost admission on measurement without being
dangerous. Only `production` and `candidate` reach the preset file.

Tool selection and tool execution are two claims and the registry carries them
as `raw_tool_selection` and `guarded_tool_execution`. The first is the graded
tool category, the model unaided. The second states whether the row may execute
a tool, over `refused`, `validator-gated`, and `unguarded`. Every row reads
`refused`, because `tool-08` puts an instruction inside the note the user asks
about and all six measured arms carried the injected city into the call in place
of the authorized one. Reading one number for both misleads in both directions:
the 2B distill scores 2 of 10 and still serves text as the `fast-text` default,
and the 4B distill scores 9 of 10 while failing the one row an execution grant
exists to survive. A runtime that compares emitted arguments against the user's
own authorization is what moves a row to `validator-gated`, and this tree holds
none: the appliance runs without `--tools` and the server executes nothing.

The failure unit is a tuple rather than a checkpoint, so `remote/quarantine.tsv`
carries two scopes. A `model` row removes a checkpoint entirely; a `profile` row
removes one tuple of a checkpoint that otherwise serves, and
`qwen-capacity-policy.sh` refuses to construct that tuple rather than warning
about it. `evidence/quarantine/` holds one reason record per row with its kernel
signature, its validated safe tuples, and its re-entry gate.
`model-registry.sh servable-ids` and `servable-files` apply the same
router-child exclusions to the registry's default tuple, and an unreadable
or malformed quarantine registry stops router and standalone tuple
construction. Each query validates and consumes one opened quarantine snapshot,
so a replacement cannot separate semantic admission from the rows acted upon.
Profile depth, batch, and ubatch fields use canonical positive decimal integers
without leading zeroes because the runtime builds exact string tuple keys. A
research override labels every
exposed excluded tuple `quarantine` and withholds the `default` tag.
`QWEN_ROUTER_INCLUDE_QUARANTINE=1` exposes a quarantined checkpoint for research.
The generated preset records that override, and `qwen-capacity-policy.sh`
derives the listener restriction from the file on every later launch. It
refuses generated presets that predate the marker and forces an exposed preset
to `127.0.0.1`, because the appliance binds `0.0.0.0` and a warning alone would
put a model with a recorded device failure on the LAN.

Three mechanisms guard the quarantined tuple because two paths construct one
and router presets persist across registry changes. `qwen-capacity-policy.sh`
refuses the tuple on the single-model path, where the policy builds the argv the
server runs. `build-router-presets.sh` filters router-child rows while generating
the child geometry, and `test-model-tiers.sh` checks that generation. Router
startup queries the same quarantine authority and rejects a persisted section
that a later model- or profile-scope row excludes. It also rejects sections
whose registry tier moves to `archive` or `rejected`, and a `quarantine` tier
requires model-scope authority. The marked research override admits authorized
quarantine sections and forces the listener to loopback. Every persisted
quarantine section retains exactly one `LLAMA_ARG_TAGS` key that contains
`quarantine` and excludes `default` and every conflicting tier tag; startup
rejects a stale tag set before the server runs.

Router mode leaves depth, cache triple, and submission geometry off its own
argv. `server-models.cpp` ends its preset assembly with
`preset.merge(base_preset)` and `common_preset::merge` overwrites, so a router
CLI argument replaces the same key in every model section: passing `--ctx-size
24576` served the vision row at 24576 where its section named 16384. Every
section therefore carries all six keys, since an absent one falls through to the
llama.cpp defaults of batch 2048 and ubatch 512, which is the quarantined
geometry.

Router startup still selects the largest installed servable GGUF as the
resident-memory preflight subject. The launcher copies the source preset to a
unique active-session snapshot, reads every section's model path from that
snapshot, and selects the largest installed artifact as the load-observation
subject. Normal and research presets therefore use the exact set they can
launch rather than separate registry enumerations. The launcher records the
snapshot SHA-256 and forwards both path and digest across the tmux boundary.
The capacity policy validates the current model and quarantine authorities and
records their SHA-256 identities. After the Vulkan wrapper configures the final
environment, `qwen-router-exec-guard.sh` remeasures the preset and both registry
identities immediately before it replaces itself with llama-server. A
terminating launch signal tears down a session whose control start has begun,
removes the launcher-owned snapshot, and exits with the signal status. The
tmux session applies the same terminating cleanup to its server, watchdogs, and
owned snapshot. The preflight reports artifact bytes and fixed host and Vulkan
headroom; the subsequent load remains the fit test. Its
standalone context ceiling never constrains the listener, because each preset
section supplies its own complete tuple. The capacity policy resolves the
section ID and model path to one registry row and requires the section's
context, cache K/V, Flash Attention, batch, and ubatch values to equal that row
before launch. The launcher's positive context argument remains a control-path
input but never reaches the router argv.

The repository fallback Web UI treats `GET /v1/models` as the request-model
authority and sends only a returned id for chat completion and attachment
tokenization. Its picker retains a still-valid choice when browser storage
permits and continues with live state when storage is denied. Each selection
uses `GET /props?model=<encoded-id>` for context metadata and retokenizes every
retained attachment with that same id. Context and token counts carry the model
identity and selection generation that produced them, so a change marks both
pending before any asynchronous response arrives. An unavailable or malformed
response leaves an explicit unknown value while the selected model remains
routable. A new API-key attempt clears the prior selection until the
authenticated roster returns, and late responses from an older attempt never
replace the newer state.

The integer dot product is advertised, functional, and unaccelerated, which
decides how most of this tree's bytes execute. RADV reports
`shaderIntegerDotProduct = true` and sets all thirty of its `*Accelerated`
capability flags false, and `ggml-vulkan.cpp:6492` gates `integer_dot_product`
on `integerDotProduct4x8BitPackedSignedAccelerated` alone, so every `_q8_1`
mat-vec and mat-mat pipeline goes unbuilt and the deployed `llama-server`
contains no `mul_mat_vec_q4_k_q8_1` symbol against seven `mul_mat_vec_q4_k_f16`
symbols. The instruction set agrees: LLVM's syntax reference lists `V_DOT2`,
`V_DOT4`, and `V_DOT8` for gfx906 and none for gfx902, which is what this device
reports. Nothing is emulated -- llama.cpp reads the driver's own report and
declines the path -- so about 83% of production streamed bytes take the
FP16-dequantize-then-dot family because the accelerated family does not exist
here. `evidence/tensor-type-execution-audit.md` carries the type shares and a
code-level account of the Q5_K trunk: Q5_K is the only one of the three K-quant
rungs paying both the packed scale-and-minimum decode and an extra bit-plane
merge, where Q4_K skips the bit-plane and Q6_K skips the complex scale, and the
three are issued with identical tile parameters so subgroup utilisation does not
order them.

RADV on this device reports `shaderFloat16 = true` and names no bfloat16
extension, so F16 is the 16-bit format the hardware advertises and BF16 is a
separate question about llama.cpp's scalar pipelines. Both publishers of this
tree's small checkpoints ship BF16 as their only 16-bit artifact, so
`remote/build-llama-vulkan.sh` builds `llama-quantize` and the appliance
produces F16 from BF16 itself. `remote/run-representation-arm.sh` measures one
value format against another on the same weights in the order control, subject,
subject, control, and reports the ratio of paired means, because this tree has
measured one checkpoint under identical flags spanning 30.6% between sweeps.
The census figure rather than the file size sets the streamed bytes a ratio
rests on, since an ordinary load skips the multi-token-prediction block the file
carries. `evidence/representation-gate-16-bit.md` registers the predictions.

Sequential host read bandwidth measures 7.97 GB/s on one thread and 15.44 GB/s
on two. Those figures measure the two Zen+ cores through the load/store path,
which is a different consumer of the one DDR4 controller than the two Vega
compute units, so they bound nothing about the GPU and the device ceiling
stays unmeasured. The retained runs resolve no directional nice-level cost:
`evidence/scheduling-priority-cost.md` alternates nice 19 against nice 0 arm by
arm on a desktop under load 4.9 to 7.0 and measures a paired mean difference of
1.10% in favour of nice 19, with two negative pairs, three positive pairs, and
one exact zero. A nominal paired 95% interval spans -6.1% to +3.9%, so the run
resolves no directional decode cost and does not establish equivalence. The
priority is read back from `/proc` rather than asserted. That comparison is
retained historical evidence. The live bandwidth harness now admits nice 19
alone and applies it as an absolute child priority, independent of the calling
shell's niceness.

A positive `QWEN_BENCH_PREFILL` requests a paired prefill/decode arm. A
successful `llama-bench` process must emit exactly one
`pp${QWEN_BENCH_PREFILL}` row and one `tg${QWEN_BENCH_GENERATE}` row, with an
optional depth suffix on either label. A row for another token count cannot
satisfy the requested arm. Missing or duplicate output remains `n/a` in the
retained summary and makes the ladder terminal state `failed`; one half never
promotes an incomplete pair to a completed sweep.

Decode scales with checkpoint size, and a linear cost model over it is refuted.
Two points, the 4B and the 9B, fit 0.1015 s per token plus 0.0869 s per GiB and
predict 4.82 tok/s at 1.21 GiB; the 2B measures 9.46. The intercept absorbed
depth-dependent overhead that a third depth exposes, so size predicts decode
only within a narrow band around the fitted points and
`evidence/qwen38-2b-distill-candidate.md` carries the refutation.

| Checkpoint | weights | decode tok/s |
| --- | ---: | ---: |
| Qwen3.8-2B distill Q4_K_M | 1.21 GiB | 9.46 measured |
| Qwen3.8-4B distill Q4_K_M | 2.58 GiB | 3.07 measured |
| Qwen3.5-4B base Q4_K_M | 2.54 GiB | 2.84 measured |
| Qwen3.8-9B distill Q4_K_M | 5.37 GiB | 1.76 measured |

## The launch chain

One command starts the appliance and one ends it. The chain between them
matters because each link adds policy the next link assumes:

```text
qwen-launch.sh            waits for /health, prints reachable addresses
  qwen-webui-control.sh   owns the tmux session, forwards environment
    qwen-webui-session.sh arms probe, monitor, kernel-hazard watcher
      run-qwen-capacity-server.sh
        model-memory-preflight.sh   reports headroom
        qwen-capacity-policy.sh     builds the llama-server argv
          radv-low-priority-env.sh  scrubs env, applies profile
            qwen-router-exec-guard.sh  rechecks authority identities, execs
```

Four properties of that chain surprise a reader who meets one file alone.

`radv-low-priority-env.sh` unsets every `GGML_VK_*` variable before its profile
case runs, so an ambient submission setting reaches the server only when the
`custom` profile captures it beforehand. A profile is defined by what it
exports after the scrub: `low-async` exports `GGML_VK_MAX_NODES_PER_SUBMIT=16`
alone, which leaves `GGML_VK_SERIALIZE_SUBMISSIONS` absent rather than zero,
and that absence carries the measured 1.348 to 2.718 decode tok/s difference
against `low-serialized`.

tmux starts a session from its server's environment, so
`qwen-webui-control.sh` forwards variables inside the command string. A
variable exported in the calling shell alone stops at the tmux boundary.

`tmux kill-session` ends the session script without running its EXIT trap, so
`qwen-teardown.sh` records the guard PIDs from `session.status` before calling
`stop`, which rewrites that file. The teardown then proves absence and exits
non-zero on residue.

`model-memory-preflight.sh` reports host and Vulkan headroom and admits every
launch. A load that exceeds the machine fails at once and names its reason.

## Commands

```sh
# Start and stop the appliance (run on the laptop)
~/qwen-laptop-setup/remote/qwen-launch.sh [paced-60|low-serialized|low-async]
~/qwen-laptop-setup/remote/qwen-teardown.sh
~/qwen-laptop-setup/remote/qwen-webui-control.sh status

# Select a checkpoint, a listener, and the inference core
QWEN_MODEL_PATH=$HOME/models/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf \
QWEN_BIND_HOST=0.0.0.0 QWEN_INFERENCE_CPU=1 \
    ~/qwen-laptop-setup/remote/qwen-launch.sh

# Measurement harnesses, each of which owns its own launch and teardown
remote/compare-model-candidate.sh LABEL MODEL_PATH [PROFILE]
remote/run-placement-sweep.sh [OUTPUT]
remote/reasoning-span-probe.sh OUTPUT_JSON     # against a live server
remote/summarize-probe.sh ~/qwen-webui-state/graphics-latency.log
remote/gguf-tensor-census.py MODEL [MODEL...]   # what a Q4_K_M file holds
remote/admit-candidate-static.py REPO REV      # a header over a range read
remote/hash-load-closure.sh EXECUTABLE [OUT]    # identity of every loaded object
remote/run-rocm-vulkan-matrix.sh [OUTPUT]      # HIP against Vulkan, phase by phase
remote/run-kv-cache-factorial.sh MODEL [OUT]   # cache type crossed with flash attention
remote/measure-served-decode.sh LABEL MODEL    # served decode at a fixed length
remote/measure-bench-repeatability.sh MODEL    # what a depth-0 rate repeats to
remote/run-quality-suite.py ENDPOINT OUT_JSON --long-context-characters 24000
                                                # the 75-row graded suite at explicit depth
remote/run-quality-roster.sh [OUTPUT_DIR]      # that suite against every servable row
remote/generate-quality-images.py [DIR]        # the vision fixtures, and --check
remote/regrade-quality-roster.py RECORD...     # a grader change over retained replies
remote/sample-gpu-clocks.sh OUT_TSV [SECONDS]  # the DPM step a rate ran at
remote/measure-dpm-force.sh MODEL [OUT]         # auto against global high governor
remote/model-registry.sh id|path SELECTOR [FIELD]
remote/build-router-presets.sh [OUTPUT_INI]    # the picker, from the tier field
remote/fetch-candidate-artifact.sh REPO REV FILE DIR  # observed, not pinned
remote/run-one-token-admission.sh RECORD [OUT]  # load every candidate once
remote/run-representation-arm.sh LABEL CONTROL SUBJECT
                                                # one value format against another, ABBA

# Rebuild llama.cpp and the static UI
remote/build-llama-preset.sh PRESET [SOURCE]   # one directory per build arm
remote/build-llama-vulkan.sh                   # llama-server, llama-cli, llama-mtmd-cli
remote/build-llama-on-workstation.sh           # optional, ships binaries over
remote/build-llama-ui.sh                       # Node on the workstation
remote/build-llama-dual.sh                     # Vulkan and HIP in one binary
QWEN_FORCE_MMQ=ON remote/build-llama-dual.sh   # the MMQ kernel-policy arm

# Hash-pinned model fetches
remote/download-qwen35-4b-q4km.sh
remote/download-qwen35-4b-mmproj.sh
remote/download-qwen38-4b-distill-q4km.sh
remote/download-nanbeige42-3b-q4km.sh            # community conversion
remote/download-qwen38-2b-distill-bf16.sh       # the 16-bit rung, and the F16 source
remote/download-qwen35-08b-bf16.sh
remote/derive-qwen38-2b-distill-f16.sh         # F16 from BF16, validated
remote/derive-qwen35-08b-f16.sh
```

Tests are standalone POSIX shell scripts that exit non-zero on failure. Run one
directly:

```sh
remote/test-qwen-runtime-guards.sh
remote/test-radv-low-priority-env.sh
remote/test-model-registry.sh
remote/test-model-tiers.sh
remote/test-quality-suite.py
remote/test-quality-roster.sh
remote/test-promote-llama-build.sh
remote/generate-quality-images.py --check
remote/test-gguf-tokenizer-identity.py
remote/test-admit-candidate-static.py
remote/test-one-token-admission.sh
remote/test-fetch-candidate-artifact.sh
remote/verify-llama-patch-series.sh
GGUF_PY_PATH=~/src/llama.cpp-qwen-apu/gguf-py \
    remote/test-gguf-tensor-census.py [MODEL...]
```

`remote/test-fixtures/fake-llama-server.sh` stands in for the real server so a
guard test runs without a GPU.

## The HIP backend needs one variable to load a model at all

`remote/build-llama-dual.sh` puts Vulkan and HIP in one binary, so
`llama-bench --device` selects the backend and two rows differ by the backend
rather than by the build. Every HIP invocation exports `HSA_ENABLE_SDMA=0`.
Without it `llama_model_loader::load_all_data` parks in `hipEventSynchronize`
and never returns: `evidence/rocm-h0-operational-failure.md` records a run that
held that wait state for 51 minutes where the same binary completes in 19
seconds.

HIP measures 14.06 prefill and 2.22 decode tok/s on Qwen3.8-4B Distill Q4_K_M
against RADV Vulkan's 21.49 and 3.10 in the same phase-split protocol, so the
recorded falsification criterion is tested and unmet.

The build requires TheRock rather than the distribution. Ubuntu Noble ships HIP
5.7.31921 where `ggml/src/ggml-hip/CMakeLists.txt` requires 6.1, TheRock's
headers collide with `/usr/include/hip` when the distribution packages are also
installed, and its LLVM 24 selects GCC 14's libstdc++.
`evidence/therock-sdk-manifest.tsv` pins the nightly that produced the rows.

## Models and projectors pair by directory

`qwen-launch.sh` calls `remote/select-projector.sh`, which searches the model
file's own directory. A projector encodes images into the embedding space of the
checkpoint that exported it, and a foreign projector of matching dimensions
loads cleanly while placing image tokens where the language model reads nothing,
which answers wrongly rather than failing. Binding the search to the model's own
directory makes a checkpoint published without a projector run text-only.

Publishers name the file differently: Qwen ships `mmproj-F16.gguf` and Ornith
ships `mmproj-Ornith-1.5-9B-BF16.gguf`. The exact name wins where it exists and
a sole `mmproj*.gguf` is taken otherwise, while several candidates print nothing
and name `QWEN_MMPROJ` as the way to choose, since resolving two projectors by
sort order is the mismatch the pairing exists to prevent.

`empero-ai/Qwen3.8-4B-Distill` distills into the Qwen3.5-4B architecture, so
the pinned build loads it unchanged. It reasons in 43.3% of the base model's
tokens, reaches an answer 2.71 times faster across the five-prompt suite, and
its chat template still gates `<think>` on
`chat_template_kwargs.enable_thinking`. It ships text-only, so the vision
profile selects the base checkpoint with its revision-matched projector.
The publisher reports a gsm8k_cot fall from 0.850 to 0.785 alongside an mmlu CoT
rise from 0.354 to 0.553.

The distill's advantage over the base is throughput alone.
`evidence/model-admission/roster-quality-sweep.md` grades both at 47 of 55 with
thinking off, at the same 0.855 correct-on-completed, and within one row in every
category. The five-prompt screen that separated them at 5/5 against 4/5 scored
the base's one failure as an empty answer after 2048 predicted tokens of
reasoning, which is the termination failure thinking off removes.

`empero-ai/Qwen3.8-2B-Distill` is the same architecture at 24 layers and
2048/6144, and it decodes above the 4B in every arm that measured both. It
streams 1.263 GB per token and reaches 10.41 GB/s against the 4B's 8.11 on the
mean of four sweeps, with the 2B ahead in all four pairs, so it streams faster
rather than carrying less overhead. Read the pairs and not the means: the same
checkpoint under identical flags spans 30.6% across those four sweeps, enough
that the 2B's slowest arm falls below the 4B's fastest.

The tested 4B K-quant ladder is exhausted as a performance lever.
`evidence/decode-bound-analysis.md` measures Q4_K_M ahead of i1-Q2_K, i1-Q5_K_M,
and i1-Q6_K in every block. Q2_K streams 29.4% fewer bytes per token and decodes
no faster, which closes that low-bit route, and Q6_K and Q5_K_M close the tested
route upward. Achieved streaming forms two observed groups rather than ordering
by bit width: a Q4_K trunk and a Q6_K trunk both reach about 8.1 GB/s where a
Q5_K trunk reaches 5.9. IQ and other reconstruction kernels remain unmeasured.

Every distill ships a multi-token-prediction block that the speculation setting
decides the fate of. `qwen35.nextn_predict_layers` is 1 and `block_count` counts
it, so the 2B declares 25 blocks against 24 transformer layers.
`llama_hparams::n_layer_effective` subtracts it from the trunk, and
`src/models/qwen35.cpp` sets `mtp_flags = !ml.load_mtp ? TENSOR_SKIP : 0`, so an
ordinary load reports each of its tensors as `model has unused tensor ... --
ignoring` and skips 37,767,168 bytes on the 2B, matching the census exactly.
That block costs download and disk alone, between 2.61% and 2.88% of each file,
until `--spec-type draft-mtp` sets `load_mtp` and loads it.

The head runs in place. `common/common.cpp` sets `mparams.load_mtp` from
`params.speculative.types`, `common_speculative_init_result` takes its
`else if (spec_mtp)` branch and builds the draft context against the target
model with `cparams.ctx_type = LLAMA_CONTEXT_TYPE_MTP`, and
`llama_model::create_memory` filters that context's KV cache to
`il >= hparams.n_layer()`, so the draft cache holds the appended block rather
than a second trunk. `QWEN_SPEC_TYPE`, `QWEN_SPEC_DRAFT_N_MAX`,
`QWEN_SPEC_DRAFT_P_MIN`, `QWEN_SPEC_BACKEND_SAMPLING`, and
`QWEN_BACKEND_SAMPLING` carry those settings through the tmux boundary into
`qwen-capacity-policy.sh`, which keeps `LLAMA_ARG_*` refused.

`remote/gguf-tensor-census.py` reports these properties from the file, because
a Q4_K_M label names a recipe rather than a layout: the 2B is 50.08% Q6_K by
byte where the 9B is 32.59%.

A candidate declares its architecture and its chat template before it is
fetched. A GGUF places the metadata block and tensor index at the head of the
file, so `remote/admit-candidate-static.py` reads them over an HTTP range
request against a pinned revision and imports the census parser rather than
writing a second one. Sixteen mebibytes covers a Qwen3.5 metadata block, whose
248,320 tokens and their merges end the 2B distill's header at 10,962,034
bytes, and the reader grows the window on a short read so a truncated buffer
raises rather than reporting the trailing keys absent. The ranged read
reproduces the appliance's own full-file census on every identity field of the
served 2B, including the 37,767,168 prediction-block bytes.

The script runs on the workstation, which makes it a third workstation-side
helper beside the UI build and the container build: it needs the network and
the appliance's two 2.3 GHz cores are the wrong place to spend it.

Static admission is what makes the throughput stage small. Throughput belongs to
an architecture and a value format, so grouping candidates by architecture,
embedding width, feed-forward width, and head counts collapses the fourteen
GGUF rows of `evidence/model-admission/candidate-ledger.tsv` into four runtime
classes. Eight rows of the largest class span 0.83% in streamed bytes against
the 4% this machine carries on a repeated depth-0 rate, so a second arm inside a
class measures queue position. One class holds a reference at its own format and
three do not: the served 0.8B is Q8_0 and streams 764 MiB per token where its
Q4_K_M class members stream 493 to 522, so that class needs an arm of its own
rather than a cross-format ratio. The same read answers what no rate can: the Jackrong 0.8B Opus
reasoning distill ends its generation prompt with an unguarded `<think>` and
names `enable_thinking` nowhere, so the thinking-off request is inert
against it and its graded arm needs a budget that survives the reasoning span.
`evidence/model-admission/static-admission.md` carries the classes and the
template survey.

A runtime class establishes a shared throughput expectation and nothing about a
particular artifact, so admission by load runs every row rather than one
representative per class. `remote/run-one-token-admission.sh` fetches each
candidate and calls `remote/test-strict-vulkan-placement.sh`, which requires CPU
tensor placement and CPU graph placement to be rejected, brings a strict Vulkan
server up, drives a two-token completion, and requires the model, KV, and
compute buffers to name Vulkan0 with no CPU fallback reached. Its `fetch` stage
runs without the device, so eleven gigabytes of transfer happen while the
appliance still serves and the outage covers the loads alone. A control arm runs
the same check against a served checkpoint after each new runtime class and
after any refusal, so a later refusal reads against a device that had just
answered.

A candidate digest is an observation rather than a pin.
`remote/fetch-candidate-artifact.sh` records the SHA-256 the download produced,
which cannot detect the substitution a hardcoded expectation exists to detect,
so promotion into `remote/models.tsv` means writing a `download-*.sh` that
carries that digest as its expectation.

GGUF weights stay outside Git because their sizes exceed the LFS per-file
limit. Each download script pins a Hugging Face revision, a byte count, and a
SHA-256, and verifies an existing file in place.

## Evidence discipline

`evidence/` holds the measurements that justify every default, and a default
changes when a measurement moves. State the falsification criterion before
running a probe; when a result deviates from prediction, the deviation is the
finding, and the evidence file records it as such. Several results in this tree
exist because a stated hypothesis failed: submission node count moved decode
3.5% where it was predicted to dominate, and asynchronous Vulkan raised probe
p90 8.6-fold under sustained prefill while leaving chat decode at zero frame
breaches.

`evidence/SHA256SUMS` and `ARTIFACTS.md` fix the retention class of every
surface. Git copies replace the private hostname with `qwen-laptop`, the home
prefix with `$HOME`, and MAC addresses with `<mac>`.

A graded result is conditioned on the request sequence that produced it. Three
repeats of the ten arithmetic rows reproduce exactly, so greedy decoding on this
backend is deterministic within a fixed sequence; prepending the five `screen`
rows moves both 2B checkpoints up one row, deterministically and in the same
direction, and `arith-05` answers 37 cold and 23 warm. Content decides it rather
than count: one unrelated 300-token predecessor leaves the answer at 37, and so
do five short unrelated ones, which is the screen block's own count. Every
arithmetic row reports the same `prompt_n` in all three conditions, so the server
charges the same prompt length warm and cold and what it reuses behind that count
stays open. The mechanism is unisolated and recorded as an effect. The measurement consequence stands on its
own: a one-row or two-row difference between two checkpoints reports position in
a sequence rather than capability, and a quality comparison is read inside one
sweep for the same reason a rate comparison is.

The graded suite reaches past text through one column. `attachment` is `-` for
a text row, `image:NAME` for a vision row, and `tools:SET` for a tool row, so a
row states what its request carries beside the prompt.
`remote/generate-quality-images.py` draws every fixture from a declaration in
its own source, which is what makes a vision answer gradeable: `bars.png` holds
four bars whose tallest is JUN at 150 because the generator's table says so.
A tool row executes nothing. The appliance runs without `--tools`, so the server
holds no tool server; the request body's `tools` field asks the model to emit a
`tool_calls` object and `tool_call` and `no_tool_call` grade that object, which
measures selection with the read-only boundary intact.
An image-withheld control retains the multipart text part and removes the image
parts, so image presence is the single changed request dimension.

The fixtures are committed and `--check` compares pixels rather than file bytes.
Deflate is not reproducible across hosts -- zlib 1.3 on the appliance re-encodes
7 of the 8 fixtures to different bytes than the workstation wrote, with
identical pixels -- while inflate is fully specified, so decoding both sides
tests the claim a fixture makes and a digest comparison tests the encoder.

A grader defect is corrected over retained replies rather than by re-running.
`nonempty` passed a reply cut at the token budget, which is the termination
failure the row tests, and `remote/regrade-quality-roster.py` re-applies the
corrected grader to the reply each record already holds. The records stay as the
harness wrote them and `evidence/quality-roster/regrade-summary.tsv` carries the
recorded total beside the corrected one. Transport and served-model attribution
failures remain failures because a content grader cannot repair evidence origin.

`llama-mtmd-cli` is built beside `llama-server` because the projector path fails
by answering rather than by erroring. A projector of matching dimensions loads
cleanly while writing image tokens the language model reads nothing from, so
`remote/promote-llama-build.sh` reads an image whose content this repository
declares and requires the answer to carry it. Promotion requires the text model,
vision model, projector, and image before either smoke stage begins. The artifact
manifest owns `llama-server`, `llama-cli`, `llama-mtmd-cli`, and the multimodal
consumer's current load closure. Promotion stops when load-closure enumeration
fails, including a helper failure that emits a partial prefix, because that
prefix does not establish a complete dependency identity.
`tools/mtmd/mtmd-cli.cpp:403` sets
`is_single_turn` from a non-empty prompt **and** a non-empty image, so
`--prompt` alone enters the interactive chat loop and a single-shot text run
through that binary is unavailable at the pinned commit.

`evidence/research-claim-methodology.md` defines the article-facing claim
record, architecture authorities, missing-data semantics, experimental design,
and publication gate. A performance document states unresolved direction where
its uncertainty still crosses zero; equivalence requires a declared margin and
two one-sided bounds inside it.

`README.md` states the selected operating configuration. This file governs
repository work, and `evidence/` retains the measurements that put each default
where it is.

## Prose and comments

Prefer affirmative, mechanism-centered prose. Describe what the system does,
the state transitions it performs, and the observable result. Avoid defining
behavior primarily through negation such as "no," "does not," "lacks," or
"without" when the actual behavior can be stated directly. Use negation only
when the absence itself is the relevant fact.

Comments, commit messages, durable docs, thinking, replies in session, and
end-of-session summaries share one voice: direct, declarative, indicative
present tense, artifact as subject.

The voice reaches conversation whole. A reply opens on the finding rather than
on a preamble, states the mechanism before the consequence, and gives each
number its evidence class. Length follows the count of decisive facts, so a
one-fact answer is one or two sentences and a measurement table earns its rows.
A result that contradicts a prediction leads, because the deviation is the
finding; a correction states what is true now and continues, since the
narration of an error costs more than the error. Ceremony, restatement of the
request, and summaries of work about to be described all fall away.

Conversation keeps what its purpose requires. A question the user must answer
is asked plainly, uncertainty is named with its falsifier, and a
recommendation carries the reasoning that would change it. Those are content,
so the voice carries them the same way it carries a register fact.

Write the mechanism first. Name the authority that makes the statement true --
the function, register, spec chapter, environment variable, or measured value
-- then the consequence. The count of distinct decisive facts sets the length;
a sentence that paraphrases another is removed.

State what a thing is and does, and let the positive form carry the absence a
negation would spell out. A binary contrast becomes its positive term. A
stacked absence collapses to the category its members share. A boundary becomes
the restriction it imposes (`loopback only`), the home its content belongs in
(`chronology lives in the commit message`), or the mechanism itself (`the
profile exports one variable, so the rest stay absent`). Each positive form
entails what a negation would state, so the negation stays off the page. A
hard-stop safety or security boundary keeps its prohibition, where that is the
whole content.

Mechanism controls comment length. A single local fact takes one sentence; a
connected relation takes a causal sentence; a short block belongs where the
code depends on a driver rule, a measured quirk, and an observed failure
together. Split when the actor, ownership, phase, evidence class, or invariant
changes. Architecture that persists across a file lives at file scope and the
point of use keeps the local link.

Mark evidence class. Documented behavior takes the plain indicative; behavior
reproduced and undocumented names where it was observed; conjecture is marked
or removed.

Chronology lives in commit messages. Task numbers, phase and wave labels,
session dates, reviewer breadcrumbs, agent names, private hostnames, local
absolute paths, and deictic terms such as `currently` stay out of source
comments. Durable names describe target, mechanism, and outcome.

"Load-bearing" is banned; name the dependency instead -- which value, which
caller, which invariant fails, and what breaks when it changes.

Commit subjects carry a component prefix and a mechanism. The body makes the
invariant, the change, and the evidence reviewable in one to five sentences.
AI participation is disclosed as `Assisted-by: TOOL (MODEL)`, or
`Generated-by:` when AI wrote nearly all of it; `Co-authored-by:` stays
reserved for human co-authors.

## Hard rules

- Checked-in text is emoji-free.
- Straight quotes over curly, `--` over an em dash, `...` over an ellipsis
  glyph. Mathematical operators, Greek letters, arrows, box-drawing, degree and
  micro signs, and accented characters in names stay verbatim.
- Secrets, local absolute paths, and private hostnames stay out of commits.
  `api.key` files stay outside the repository and their contents stay unprinted
  and untransmitted.
- `/etc/sudoers.d/90-qwen-agent` sets `timestamp_type=global` with a 60 minute
  timeout, so one `sudo -v` on the laptop covers the SSH sessions that
  administer it. The user types the password; it stays out of SSH command
  lines, scripts, logs, and project files.
- New files carry no copyright line. Existing upstream headers stay verbatim.
- Scripts are POSIX `sh` with `set -eu`, long descriptive variable names, and a
  usage block that exits 2 on argument error.
- `docker compose` (v2) rather than legacy `docker-compose`.
- `--tools all` grants shell execution and file writing to a prompt-injectable
  model. The read-only set is `read_file,file_glob_search,grep_search`, and a
  tool-enabled server stays off the LAN.
- The service starts and stops through the launch and teardown scripts alone.
  No unit file, crontab entry, or login hook starts it, so a reboot leaves the
  laptop with nothing listening.
