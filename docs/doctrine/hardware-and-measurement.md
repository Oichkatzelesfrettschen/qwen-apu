# Hardware sets every ceiling in this repository

The doctrine in `AGENTS.md` states the rule and this file carries the mechanism, the measurements, and the evidence paths behind it in full.

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

The SMU firmware rather than the driver or the VBIOS sets the graphics ceiling.
`smu10_emit_clock_levels` obtains both `OD_RANGE` bounds with
`PPSMC_MSG_GetMinGfxclkFrequency` and `PPSMC_MSG_GetMaxGfxclkFrequency` on every
read, and `smu10_set_fine_grain_clk_vol` rejects an overdrive maximum above that
same reply, so the 200 and 1100 MHz this part prints are the firmware's own
answers and a write above 1100 is refused before any message leaves the kernel.
`amdgpu.ppfeaturemask` decides nothing here: `0xfff7bfff` is amdgpu's own
default, it clears `PP_OVERDRIVE_MASK`, and `smu10_hwmgr_backend_init` then sets
`od_enabled` to 1 unconditionally during `hw_init`, which is why
`pp_od_clk_voltage` prints at all. The board's decomposed VBIOS carries a
`powerplayinfo` table whose 1020 body bytes are zero and no `setengineclock`
command, so there is no clock table or voltage curve in the image to raise.
Boost is the CPU half of the same picture: AMD publishes 3.2 GHz for this part,
`cpufreq/boost` reads 1 over an ACPI P0 of 2.3 GHz, and both cores were observed
at 3.15 to 3.19 GHz under load. The package budget is the one power authority
that is writable, and it reaches the SMU through `remote/power-envelope.sh`,
since `/sys/class/powercap` creates no `constraint_*` file and the amdgpu hwmon
names a `PPT` label with no `power1_cap` beside it.
`evidence/power-envelope/README.md` carries the message table and registers the
package-budget campaign.

On this SMU10 path, `pp_dpm_mclk` is a misleading sysfs name: the kernel obtains
its selected value with `PPSMC_MSG_GetFclkFrequency`. The 933 and 1067 MHz
entries are dynamic fabric-clock states, not alternate DRAM training results,
and retained Vulkan telemetry shows 1067 MHz selected under load. The step
answers memory traffic rather than graphics residency: under `stress-ng --vm`
with two hogs and no Vulkan workload, `pp_dpm_mclk` sampled every 256 ms
selects 1067 MHz on 27 of 76 samples and 933 MHz on 49, which
`evidence/hp14-dk1xxx-memory-firmware-rca.md` records with the capture's
digest. Theoretical
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

That sweep proposed one scalar offset per sweep as the remedy, and
`evidence/model-admission/runtime-class-throughput.md` leaves the remedy
unconfirmed. Against the seven-checkpoint sweep the 4B distill fell 10.6% where
the 2B distill fell 16.4% in the same twelve-arm re-run, moving the pair's ratio
from 0.3634 to 0.3884, whose nominal 95% interval overlaps the registered 0.345
to 0.382 band by 0.002. Two sweeps cannot separate a size-dependent term from
their own scatter, so the anchor control fails narrowly and inconclusively. A
ratio against an in-sweep checkpoint is more stable than an absolute rate and
is not invariant; the cross-sweep term on this pair was observed at 6.9% once
and its expected size is unmeasured.

The reported deviation of a rate is not its uncertainty. `llama-bench` prints a
standard deviation over the repetitions inside one arm, and those repetitions
agree far more closely than an arm agrees with its own reverse: the 4B distill
measured 3.41 +/- 0.01 and 2.95 +/- 0.01 in one sweep, 0.3% within each arm
against 14.5% between them. Raising the repetition count measures one machine
state better rather than narrowing the spread, and four slots per checkpoint
brought that row to a 4.4% span where two slots gave 14.5%. Load peak does not
order the instability: the 0.8B Q8_0 arm at the sweep's highest load peak
landed 0.9% from its pair. Checkpoint size and queue distance remain
confounded, because the mirrored order put the large pairs nine to eleven slots
apart and the small pairs one to five, so neither is credited.

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
and has not proven a near-full cache executes, so `qwen-capacity-policy.sh`
prints the gap between the two fields on its `depth_validation` line at every
launch. The 4B distill carried 24576 and 16384 there until
`evidence/depth-validation-32k/` filled 24576 and 32768 at 128/32 with zero
resets, zero faults, and a passing control after each, so its row reads 32768
in both. Submission geometry belongs to the same
claim: at 16384 the same checkpoint, cache, and device wedged the compute ring
at 2048/512 and completed twice at 128/32, so `batch` and `ubatch` are registry
fields rather than constants in the argv.

`models.tsv` carries one `validated_filled_depth`/`batch`/`ubatch`/cache/Flash
Attention tuple per row, which cannot state that 16384 passes at batch 128 and
wedges at batch 2048 for the same model and cache triple.
`remote/validated-tuples.tsv` carries every measured arm instead, keyed by
`tuple_id`, with `model_id`, `runtime_mode`, the submission geometry, the cache
triple, `threads`, `parallel`, `projector_state`, `backend`, and `status` over
`validated`, `failed`, or `unverified`. A `validated` row requires its
`evidence` path to exist in the tree; a `failed` row carries the same fields
and belongs in the ledger because a rejected geometry is what steers a later
choice away from it. `remote/model-registry.sh tuples MODEL_ID` and
`tuple TUPLE_ID [FIELD]` read the ledger after validating every row in it, the
same discipline `emit_servable_rows` applies to the quarantine authority.
`remote/check-validated-tuples.sh` derives the tuple each `models.tsv` row with
a numeric `validated_filled_depth` already claims and requires a `validated`
ledger row matching model, depth, batch, ubatch, and cache triple; a gap
between the two files fails the gate rather than serving silently. The seeded
16384 rows carry `evidence/depth-versus-submission-geometry.md`: batch 128 at
depth 16384 passes and batch 2048 wedges the compute ring under the same
cache triple, both at the probe's own `-t 2`.

The context checkpoint count is per row, and `remote/ctx-checkpoints.tsv`
carries it as `model_id`, `ctx_checkpoints`, `evidence`. A checkpoint copies
the recurrent state into host memory at the boundaries
`server-context.cpp` chooses, so a second turn sharing a long prefix restores
the newest checkpoint below the divergence point instead of reconstructing
the Gated DeltaNet state from zero: `evidence/ctx-checkpoint-sweep/` measures
turn 2 at a 30K prompt boundary charging 27 tokens under any positive count
where zero charges 30748, on all three classes. The count is a row property
rather than an appliance default because the 0.8B alone emitted a different
first-turn token at zero-based index 25 once checkpoints were armed, on every
positive arm and neither zero arm, which the forced prefill tail partition
(`checkpoint_offsets[] = {4 + n_ubatch, 4}`) produced while the 2B and 4B held
identity on both turns. The eighth production patch removes that partition and
`evidence/ctx-checkpoint-natural-boundary/` measures all three classes holding
token and log-probability identity across the setting, so every served row
reads 2 and a row absent from the ledger reads 0.
`model-registry.sh ctx-checkpoints` and `ctx-checkpoint MODEL_ID` validate the
whole ledger before answering, a count above 0 requires an evidence path, and
`QWEN_CTX_CHECKPOINT_LEDGER` names another file for a fixture. Row shape is a
property of the row and is validated wherever a ledger is read; the existence
of the file a row names is a property of the tree and belongs to
`remote/check-ledger-evidence.sh`, which the repository gate runs over all
three ledgers. The appliance runs from a copy carrying `remote/` and `patches/`
beside whatever `evidence/` a past sync left, so a reader that resolved those
paths would refuse every launch over a directory the sync never sent.
`qwen-capacity-policy.sh` sets `--ctx-checkpoints` from the row on the
single-model path, with `QWEN_CTX_CHECKPOINTS` replacing it for an experiment
arm, an explicit 0 included. Both it and `QWEN_CHECKPOINT_MIN_STEP` belong to
that path alone and router mode refuses each. The spacing reaches the router's
own argv, where `common_preset::merge` would place every child's checkpoints
from that one value while each section still matched the ledger's count, and
the ledger states a count per row where no authority states a spacing. The
count reaches neither the argv nor a section, so a router launch carrying it
would serve the ledger's count under a name claiming the arm's. In router mode the flag stays off the router argv
with the six tuple flags, because `common_preset::merge` would push one value
onto every child; `build-router-presets.sh` and `build-web-presets.sh` write
`LLAMA_ARG_CTX_CHECKPOINTS` from the row into every section, a draft-pair
section from its target row and a review-only section from its own, and the
launch requires exactly one such key per section equal to the ledger's value.
An absent key is refused rather than defaulted, since the pinned build's
default is 32.

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

`check-validated-tuples.sh` maps a `projector` field of `required` onto an
expected projector state of `loaded`, and `probe-depth-wedge.sh` drives
llama-bench, which takes no `--mmproj` and allocates no projector buffers, so
every arm it records reads `projector_state=none` and a vision row keeps `-` in
`validated_filled_depth` however many arms it accumulates.
`remote/probe-depth-projector.sh` measures the tuple those rows need. It reads
one registry row, resolves the projector through `select-projector.sh` in the
model's own directory, and runs llama-server standalone at the row's cache
triple and submission geometry with the projector attached. A probe request
measures the template and image overhead `/tokenize` cannot see, since that
route tokenizes text and the projector writes image tokens inside the chat
pipeline, and padding measured through `/tokenize` closes the remainder. The
acceptance window is asymmetric because decode follows the fill inside one
allocation: an arm passes on `DEPTH - 2% <= prompt_n <= DEPTH - 32`, where a
prompt at or above the depth evicts rather than decodes. Each arm ends on the
question `bars.png` declares the answer to, so a projector that stopped
encoding into the language model's embedding space fails the control and halts
the chain. A healthy arm emits an appendable ledger line carrying
`projector_state=loaded` beside its evidence directory rather than into
`remote/validated-tuples.tsv`, because a `validated` row requires its evidence
path to exist in the tree.

`--runtime-mode router-child` measures that arm through the serving path a
review-only vision section uses, since `build-web-presets.sh` joins an image
row's `review_model` against the ledger on `runtime_mode=router-child` with
`projector_state=loaded` and a standalone row leaves the section ungenerated.
The harness generates a one-section preset with `build-router-presets.sh` over
a one-row registry copy naming the arm's depth as `context_default`, stages the
weights and the resolved projector as symlinks so `select-projector.sh` answers
with the file the standalone arm attaches, and launches `--models-preset` with
`--models-max 1`; depth, cache triple, submission geometry, checkpoint count,
and the projector stay off that argv because `common_preset::merge` overwrites
each section key with the router argv's value of the same name, and the
generated section is read back before the server starts. Each request names the
section in the body's `model` key, which `router_validate_model` resolves the
child from. The emitted line reads `runtime_mode=router-child` with a `-router`
`tuple_id` suffix and every other field equal to the standalone line, the mode
reaches `projector-summary.tsv` and `wedge-metadata.tsv`, and an output
directory therefore holds one mode. `check-validated-tuples.sh` reads the same
join: a `validator-gated` image row whose reviewer holds no such tuple fails the
gate and prints the probe command that measures it, and any other execution
policy reports the absence as a warning, since it emits no section under every
setting. The shipped tree fails that gate, because `image-sdxs-512-a` names
`lfm25-vl-16b` and every retained projector arm is standalone;
`evidence/depth-validation-32k-projector/README.md` states the appliance run
that closes it.

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

`remote/build-web-presets.sh` generates a second preset file from
`remote/web-profiles.tsv`, where a section is named for a profile rather than a
checkpoint and several profiles serve one checkpoint at depths the profile
chooses. Its head marker `# qwen_web_presets=1` switches
`qwen-capacity-policy.sh` to resolve each section through its `LLAMA_ARG_MODEL`
path against the unique `model_file` column and to bound `LLAMA_ARG_CTX_SIZE` by
`context_ceiling` rather than pin it to `context_default`. A preset persists
across a registry edit, so the launch bounds that depth again by the row's
current `validated_filled_depth` and refuses a `-` outright unless the preset
carries the unvalidated-depth marker; a registry that lowers the field would
otherwise leave an unmarked section serving a depth no run has filled and
decoded. A preset also persists across an edit to the ledger, so the launch rejoins each
section to `remote/web-profiles.tsv` by its `profile_id` and requires the row to
exist, to carry an emitting `execution_policy`, and to carry the same policy the
section's `LLAMA_ARG_TAGS` claims; a row moved to `refused` or removed outright
refuses the launch rather than serving the persisted MCP configuration.
`execution_policy`
decides emission: `refused` emits nothing under every setting, `validator-gated`
emits a section carrying `LLAMA_ARG_MCP_SERVERS_CONFIG` only under
`QWEN_WEB_AUTHORIZER_READY=1`, and `ui-mediated` emits a section naming no
configuration because the UI performs the retrieval. `web-open` is the one
checked-in row carrying `validator-gated`, on the evidence of two retained live
admissions, so the generator against the shipped ledger emits that section
under `QWEN_WEB_AUTHORIZER_READY=1` and nothing without it; every other row
reads `refused` and emits nothing under either setting. Every row still meets
the registry join, the copied-field comparison, the
tier rule, and the ceiling rule before that gate, so the ledger is validated
whole and an edit to one row's `execution_policy` changes what emits rather
than turning a previously successful ledger into an error. The `# qwen-web-presets: unvalidated-depth-override` marker forces the
listener to loopback the way the quarantine marker does, and
`remote/qwen-web-launch.sh` binds 127.0.0.1 with `QWEN_ROUTER_MAX=1`, refuses
a caller who asked for any other listener, and reads every
`LLAMA_ARG_MCP_SERVERS_CONFIG` and `LLAMA_ARG_MMPROJ` path its sections name,
since router mode reads a projector only when a request selects that child.
`QWEN_WEB_REVIEW_SECTION` raises both to two for one named section, which
`qwen-image-launch.sh` sets to the review-only vision section an image row's
`review_model` produces; the broker still signs for the one language profile,
so the review section is subtracted before the profile is read.
`multi_source` reads `yes` exactly where `max_fetches` exceeds one, because the
emitted configuration carries the fetch budget alone.

One router serves the whole roster, and the head marker
`# qwen_web_sections=web-open` is what makes that safe.
`remote/build-router-presets.sh` reads `remote/web-profiles.tsv` through
`remote/web-preset-lib.sh`, the file that holds the registry join, the
copied-field comparison, the search policy, and the MCP configuration writer
once for both generators, and emits one section per `validator-gated` row
beside the registry and draft-pair sections: the thirteen servable rows and the
two pairings stay tool-free and `web-open` carries
`LLAMA_ARG_MCP_SERVERS_CONFIG` with the six tuple keys and
`LLAMA_ARG_CTX_CHECKPOINTS`, named for its `profile_id` and resolving to its
checkpoint through `LLAMA_ARG_MODEL`. `qwen-capacity-policy.sh` reads the
marker into a section set and selects the rules per section rather than per
file -- resolution through the model file, the depth bounded by
`context_ceiling` and `validated_filled_depth`, and the rejoin to the bound
ledger by `profile_id` -- while refusing an MCP key in any section the marker
never named and a draft key in any section the pair ledger never named.
`QWEN_WEB_AUTHORIZER_READY=1` admits the rows and its absence emits the fifteen
registry sections alone and says so; an unvalidated depth is refused outright
here, because this is the file an ordinary launch binds `0.0.0.0` with and
`build-web-presets.sh` keeps the experimental path on its own loopback-forced
file. `qwen-launch.sh` reads the marker off the snapshot it already took, so an
activation between the two reads cannot change what the broker signs for: one
named section becomes `QWEN_WEB_PROFILE` and arms `QWEN_WEB_BROKER=1`,
`QWEN_REQUIRE_API_KEY=1`, and `QWEN_WEB_SEARXNG=1` at the port the ledger row
names, the launch serves `webui/index.html`, and a second web section, an
unreadable signing key, an absent MCP configuration, or a non-loopback bind
without `QWEN_WEB_LAN=1` each refuse. The MCP configuration is session state --
its contents name the state directory, the signing key, and the per-profile
budgets -- so `build-deployment-bundle.sh` records its path and SHA-256 in
`web-mcp-manifest.tsv` rather than copying it, `verify-deployment-bundle.sh`
compares that record against the preset alone, since a resolution reading the
named files would refuse every bundle on a machine that never armed the lane,
and `qwen-launch.sh` compares the digests where it arms it. The same marker
decides whether the record exists: a bundle whose preset names no web section
carries none and verifies with zero rows, which is every bundle assembled
before this lane, and one whose preset carries the marker requires exactly one
row matching the sections it names. Requiring the record of every bundle
refused `natural-boundary-13d05a0-r2` outright and left the appliance serving
through the recovery form alone, where an explicit `QWEN_LLAMA_SERVER` beside
`QWEN_ROUTER_PRESETS` outranks the deployment and reads no bundle at all; the
resolution refusal now prints that form.

The image lane rides the same file. `build-router-presets.sh` reads
`remote/image-profiles.tsv` under the rules `build-web-presets.sh` applies, so a
`validator-gated` row adds one `image` server to each web section's MCP
configuration under `QWEN_WEB_AUTHORIZER_READY=1` and an all-refused ledger adds
none, and the head marker `# qwen_image_profile=` names what emitted with `-`
for a withheld lane, the reading a preset generated before the lane also
carries. `qwen-capacity-policy.sh` holds every web section's own configuration
to that marker in both directions -- a named profile requires an image server
bound to that profile and to that section as its language profile, and a
withheld marker requires none -- through `remote/read-image-mcp-server.py`, the
one parser the policy and the launch read that file with. `qwen-launch.sh` then
does what `qwen-image-launch.sh` does for the web-only preset, from
`remote/image-launch-lib.sh`: it rejoins the ledger row, validates the parameter
file the service runs a job under, proves the deadline stack ordered, exports
`QWEN_IMAGE_SERVICE=1` with the five inputs so `qwen-webui-session.sh` starts
the service as a guarded child beside the broker and the search instance, and
adds the image runtime's mebibytes to the requirement the largest-servable
selection computed. `--models-max 1` keeps the roster's sections from being
co-resident, so the runtime is the whole addition and the reviewer is the
registry row a request selects: this file already serves every vision row at its
own tuple with its projector, a second section named for that model_id would be
two sections of one name, and `# qwen_image_review_section=` names the roster
row instead. That marker is written only where the reviewer resolves whole, and
`lfm25-vl-16b` carries no `router-child` row in `remote/validated-tuples.tsv`
with the projector loaded, so the shipped ledger arms generation and withholds
the review marker beside the `probe-depth-projector.sh` command that measures
the arm. The bundle records the lane in the column it already had:
`web-mcp-manifest.tsv` gains an `image_server` field over the configuration it
names by path and digest, and `verify-deployment-bundle.sh` compares that field
against the marker without opening a file, so a three-column row written before
this lane reads `-`.

Router mode leaves depth, cache triple, and submission geometry off its own
argv. `server-models.cpp` ends its preset assembly with
`preset.merge(base_preset)` and `common_preset::merge` overwrites, so a router
CLI argument replaces the same key in every model section: passing `--ctx-size
24576` served the vision row at 24576 where its section named 16384. Every
section therefore carries all six keys, since an absent one falls through to the
llama.cpp defaults of batch 2048 and ubatch 512, which is the quarantined
geometry, and `LLAMA_ARG_CTX_CHECKPOINTS` beside them for the same reason.

The Q4_K mat-vec formulation is released per row for the same reason and
travels the same route. `remote/models.tsv` carries `q4k_variant`, closed over
`-`, `production/4`, and `e4`, `e4-scale`, and `e4-scale-licm` over `/2`, `/4`,
and `/8`, and `model-registry.sh` validates the whole registry before it emits
any row; a `-` serves the production module every build executes unkeyed, so a
measured win reaches one checkpoint while every other row keeps what it serves
now. `build-router-presets.sh` and `build-web-presets.sh` write
`LLAMA_ARG_VK_Q4K_VARIANT` into a section exactly where its row releases a key
-- a draft-pair section from its target row, a web section from the checkpoint
its `LLAMA_ARG_MODEL` resolves to, a review-only section from its own row --
and the key stays off the router argv, since `common_preset::merge` would push
one formulation onto every child the way `--ctx-size` once pushed one depth.
`qwen-capacity-policy.sh` requires each section to carry the key its row
releases and no key where the row reads `-`, and it holds every key the launch
carries to the `q4k_variants` row of the selected build's artifact manifest,
which `build-llama-preset.sh` writes from the source it compiled: a build
without the multiplexed shader and its host reader declares `-` and admits
nothing, so a key against it would serve the production module under a row
claiming a formulation. `qwen-build-exec-guard.sh` states that requirement
again at the exec boundary over the manifest it rehashes, independently of the
checkpoint requirement, and `qwen-router-exec-guard.sh` re-derives the key set
from the preset whose digest it just verified and requires it to equal what the
policy bound, so a derivation that missed a section is caught rather than
served. `verify-bundle-preset-ledger.sh` binds each section's key to the
formulation released for the row its model file resolves to, so assembly and
activation refuse a bundle whose preset names one the release never stated.
That release is bundled rather than read live. The registry's `q4k_variant`
column moves whenever a promotion lands, and a preset outlives the edit, so
reading the live column refuses in both directions at once: an already-assembled
bundle whose sections carry no key fails against a registry that has since
released one, and a bundle carrying the released key fails against the registry
it was generated before. `resolve-active-deployment.sh` verifies the active
bundle on every launch and `activate-deployment-bundle.sh` verifies a rollback
target, so those two refusals leave no order in which a release and its rollback
both verify. `build-deployment-bundle.sh` therefore projects `model_id` and
`q4k_variant` out of the registry it read into `q4k-policy.tsv` and records its
digest in `bundle-manifest.tsv`, the shape `web-mcp-manifest.tsv` already takes.
Three manifest shapes are three claims and `verify-deployment-bundle.sh` reads
them as such: exactly one digest row binds the member, exactly one row of `-`
requires the member absent and releases nothing on every row, and no row at all
is a bundle assembled before the member existed, which records no release state
and binds `legacy`. A second row, an empty declaration, a member the manifest
records no row for, and a member reached through a symlink each refuse, since
the reader takes a row rather than the first row. `legacy` and `-` agree on a
keyless preset -- which is every bundle on the appliance, where no manifest
carries the row and no section carries the key -- and separate on a keyed one,
where `legacy` refuses by naming the re-assembly and the explicit
`QWEN_BUNDLE_Q4K_POLICY` that recover the selection rather than reading the
absence as proof that nothing was released. The authority follows the preset
rather than the server: `qwen-launch.sh` and `qwen-web-launch.sh` each bind
`QWEN_BUNDLE_Q4K_POLICY` from the bundle whose preset they selected and state
`registry` for a preset the caller named or the state directory holds, since
binding an active bundle's release state to a preset that bundle never generated
refuses an agreeing pair; `qwen-webui-control.sh` defaults to `registry` and
forwards whatever a launcher stated across the tmux boundary.
`qwen-capacity-policy.sh` then compares each section against its own release,
refuses a section resolving to a model the policy never names rather than
reading it as unreleased, and states the authority on its `router_q4k_policy`
line. The projection is that one column, because a whole-registry snapshot would
also freeze `validated_filled_depth`, `context_ceiling`, and `tier` and leave an
old bundle serving a depth a present-day revocation withdrew. An empty value
reads the registry column, which is the generator's own reading; the
explicit-`QWEN_LLAMA_SERVER` recovery form reads no bundle, so an operator
serving a preset older than the registry beside it states
`QWEN_BUNDLE_Q4K_POLICY=-` there rather than editing the registry back.
`write-deployment-receipt.sh` records the whole selection as
`q4k_selection_identity` beside the build's own `q4k_variants_declared`. On the
single-model path the policy exports the row's key as `QWEN_Q4K_VARIANT`, the
one name past the `radv-low-priority-env.sh` scrub of `GGML_VK_Q4K_VARIANT`.
Precedence there is stated rather than inferred: an ambient value equal to the
row passes, and an ambient value that differs replaces the release only under
`QWEN_Q4K_EXPERIMENT_ARM=1`, which `remote/run-served-binary-ab.sh` sets for the
arm it measures, so a stale export serves nothing the registry did not release.
Router mode refuses both names outright. A key on a row whose checkpoint holds
no Q4_K tensors is admissible by syntax and dispatches no Q4_K mat-vec, and
`evidence/raven2-vulkan-kernel-census/` rather than the registry is the
authority on whether the named formulation executes.

A draft-pair section is the one preset section named for something other than a
registry id. `build-router-presets.sh` emits it for a `production` or
`candidate` row of `remote/draft-pairs.tsv` under the `pair_id`, carrying the
target row's whole six-key tuple beside nine draft keys and tags
`candidate,draft-pair`. Six of those keys carry a `set_env` at f280b269 and
reach the INI as `LLAMA_ARG_SPEC_TYPE`, `LLAMA_ARG_SPEC_DRAFT_MODEL`,
`LLAMA_ARG_SPEC_DRAFT_N_MAX`, `LLAMA_ARG_SPEC_DRAFT_P_MIN`,
`LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_K`, and `LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_V`;
draft layers breaks the pattern as `LLAMA_ARG_N_GPU_LAYERS_DRAFT`. The draft
device and tensor override carry no env at all, and `get_map_key_opt` in
`common/preset.cpp` indexes every option by its dash-stripped argument names
beside its env names, so those two reach the INI as `spec-draft-device` and
`spec-draft-override-tensor`; both are stated because
`common_base_params_to_speculative` overwrites the draft's devices, layers, and
tensor overrides with its own values and leaves the router argv's Vulkan0
placement reaching the target alone. `qwen-capacity-policy.sh` resolves the
section through the ledger to the target row, requires the six tuple keys to
equal that row and the nine draft keys to equal the pair row, and refuses an
ordinary section carrying any draft key, because a draft the ledger never
admitted loads a second checkpoint no resident-set arithmetic counted.

Router startup still selects the largest installed servable GGUF as the
resident-memory preflight subject. The launcher copies the source preset to a
unique active-session snapshot, reads every section's model path from that
snapshot, and selects the largest installed artifact as the load-observation
subject. Normal and research presets therefore use the exact set they can
launch rather than separate registry enumerations. The launcher records the
snapshot SHA-256 and forwards both path and digest across the tmux boundary. A
draft-pair section counts as the sum of its two artifacts in that selection,
since the draft is a second resident model rather than a second view of the
target, and where that sum wins, `qwen-launch.sh` adds the draft's own
mebibytes to `QWEN_REQUIRED_VULKAN_MIB` and reports both on its
`router_preflight_subject=` and `router_preflight_requirement` lines.
The capacity policy validates the current model and quarantine authorities and
records their SHA-256 identities. After the Vulkan wrapper configures the final
environment, `qwen-router-exec-guard.sh` remeasures the preset and every ledger
identity immediately before it replaces itself with llama-server. The draft-pair
and web profile ledgers reach it as `-` where the preset shape holds no rows of
theirs; the context checkpoint ledger is required, since every router and web
section names a count and a replacement between validation and exec would
otherwise leave a count the ledger no longer states in front of a build whose
`n_ctx_checkpoints` default is 32. A
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

The transcript outlives the page. A conversation is a record in IndexedDB, in
localStorage where IndexedDB refuses, and in an in-memory Map where both do,
addressed by a `#/c/<id>` route and listed in a side panel that opens, renames,
and deletes one, and `history` is rebuilt from the record a reload restores.
What is written is a projection -- role, content, the served model id each
assistant message carries as its badge beside the roster tier, the tool call
ids and arguments the transcript re-sends, and an artifact's digest, provenance
route, seed, and geometry -- so a broker grant, the session secret, and the API
key reach no store and a restored image is refetched by digest over the
artifact listener's own credentialed route. Model selection and the Web and
image toggles stay per turn, and the rounds of one turn render into one turn
block so a generated image sits between the round that proposed it and the
round that describes it. The `llama.cpp UI` tab opens a notice rather than a
route: `server_http_context::init` mounts a `--path` directory at
`api_prefix + "/"` where `public_path` carries a value
(`tools/server/server-http.cpp:333-335`) and registers the compiled-in UI under
the same prefix in its else branch (`:339-427`), one `--api-prefix` reaches
whichever branch runs (`common/arg.cpp:3352-3356`), and `ctx_http.init(params)`
runs ahead of the router branch (`tools/server/server.cpp:173` against
`:188-232`), so `qwen-launch.sh` serves that UI on this same address and port
while `qwen-web-launch.sh` serves this page.

What a checkpoint can do is a claim per feature, and `remote/feature-claims.tsv`
carries it as `subject_id`, `feature`, `status`, `evidence`, `note`. The feature
decides the namespace the subject resolves in: `text-chat`, `vision`,
`tool-selection`, `guarded-tool-execution`, `long-context`,
`context-checkpoints`, `quarantine`, and `q4k-formulation` name a
`remote/models.tsv` id,
`draft-pair-speculation` a `remote/draft-pairs.tsv` pair_id, `web-search` a
`remote/web-profiles.tsv` profile_id, and `image-generation` and `image-review`
a `remote/image-profiles.tsv` profile_id, so one namespace per feature keeps the
subject column free of a scope field a typo would put at odds with the id beside
it. `status` is closed over `production`, `candidate`, `experimental`,
`unstable`, and `unsupported`; the first, second, and fourth each assert a run
and require an evidence path, and the other two admit `-` while their note names
the run that moves them. A `(subject, feature)` pair absent from the file reads
`unclaimed`, so a hole in the matrix is the absence of a claim rather than a
denial.

`remote/build-feature-roster.sh` validates every claim before it emits any row
and writes `webui/roster.json` through one rename. It refuses a claim naming a
subject outside its feature's ledger, a duplicate pair, an evidence path outside
`evidence/`, a note carrying a quotation mark or a backslash, and a `production`
claim over a checkpoint whose registry tier reads `quarantine` or whose id the
quarantine authority names at model scope; the profile-scope rows stay out of
that read, since a profile row removes one tuple of a checkpoint that otherwise
serves. Models order by tier rank and then by the class policy -- the 2B class,
the 0.8B class, the 4B class, and a row outside the three after them by id --
and `archive` and `rejected` rows reach no picker, so they reach no roster.
`remote/repository-quality-gates.sh` regenerates into a scratch directory and
diffs the result against the committed document, so a ledger edit that leaves
the page stale fails the gate.

llama-server serves the page with `--path` over the `webui` directory, so
`webui/index.html` fetches `./roster.json` beside itself and decorates the ids
`GET /v1/models` returned. The roster contributes no id: each render iterates
the served ids and looks each one up, so a roster row for a model the listener
withheld reaches neither the picker nor the matrix and a served id the roster
omits keeps its option. The picker option carries the row's tags, a badge names
the selected row's tier, and a collapsible matrix holds one row per served
rostered id over the model-scope features with each cell's status, evidence
path, and note. An absent, malformed, or foreign-schema roster leaves both
decorations off while the picker routes.

A web search reaches the network through one human approval, and the browser is
the executor. llama-server reads `tools` from the client body alone and runs a
wrapped MCP tool through the standalone `POST /tools` route, so the page
composes `body.tools` from `GET /tools?model=<id>&autoload=true` when the per-turn Web toggle is on and
a turn run with it off offers the model no network-reaching surface. The
executor reads the toggle again where the call runs, so a proposal carried over
from a turn that offered the web tools reaches no network once it is off. A proposed
`web_search_exa` call opens a dialog naming the query, the publication
interval, both domain lists, the result count, and whether `max_age_hours` of 0
forces a live crawl, and the dialog offers one approval and a refusal because
the broker signs a single-use grant. An approval posts those exact parsed
fields to `remote/web-mcp/authorize-broker.py` and posts the returned grant
inside the `params` object of one `POST /tools` request; `history` retains the
proposal the grant was signed over and the result text, so the token reaches
the server once and stays out of the transcript every later request re-sends
and out of browser storage. A `web_fetch_exa` call runs through the same route
without a grant, because the wrapper enforces the signed Result ID and its own
fetch allowance, and the page spends at most two fetches per turn.
`mcp_result_to_response` maps an MCP `isError` result onto an `error` key at
HTTP 200, so a refused grant, a spent grant, and an argument outside the claim
are read from the response body rather than from its status and become a tool
message naming what refused. A refusal in the dialog answers the call with a
`role: 'tool'` message stating that the search did not run.

A backend states what it can carry rather than being trusted to carry
everything. Each `Provider` in `remote/web-mcp/server.py` declares
`supports_exact_date_bounds`, `supports_freshness_max_age`,
`supports_domain_filter`, `supports_num_results`, and `supports_paging`, and
`refuse_unhonored_arguments` ends a call whose approved argument the active
provider cannot express, naming the argument and the provider, ahead of the
ledger transaction that spends the grant. `exa` carries every field, at any
`max_age_hours` including the 0 that forces a live crawl.

One local SearXNG instance is the general-search endpoint, and the profile
rather than the model decides what it is asked. `remote/web-profiles.tsv`
carries `provider`, `primary_category`, `fallback_category`,
`minimum_results`, and `searxng_url` per row, `build-web-presets.sh` validates
them for every row and emits them into the MCP configuration, and
`SearXNGProvider` validates them again before its first request. Which engines
answer belongs to the instance's own `settings.yml` under qwen-named
categories, so the engine population changes by editing the instance rather
than through a request field. A search queries `primary_category` once and,
where fewer results survive canonicalization, private-target rejection, and the
granted domain lists than `minimum_results`, queries `fallback_category`
exactly once; a failing engine is suspended by the instance rather than retried
here. Both temporal arguments are refused, because SearXNG maps `time_range`
onto each engine and a mixed category cannot promise that every result met it.
Domain scope and result count are honored in the provider, over the answer. A
dropped private target leaves the answer rather than ending the call, which is
where a metasearch mix differs from Exa's own crawler. Each result carries its
`engines`, `category`, `rank`, and `score`, the reply names them on a
`Sources:` line ahead of `Highlights:`, and the audit row gains `search_id`,
`category`, `engines_attempted`, `engines_answered`, `engines_failed`,
`fallback_used`, and `usable_results` while still holding no query text. The
instance answers with result metadata alone, so `fetch_exa` retrieves the
source over one GET of the canonical URL its Result ID was signed over, and
`PROVIDER_OPENER` ends a redirect at the response that requested it.
`evidence/web-provider-contract.md` carries the flags, the profile columns, and
what a run against a live instance still leaves unmeasured.

The launch owns that instance. The installed tree at `/usr/local/searxng` is
readable by the serving user and its configuration is not:
`/etc/searxng/settings.yml` is root-owned and the engine caches under `/tmp`
belong to the `searxng` account, so `remote/searxng-launch.sh` renders
`remote/searxng/settings.template.yml` into the state directory at mode 0600
with a fresh secret and runs `searx.webapp` under `SEARXNG_SETTINGS_PATH` and a
`TMPDIR` of its own. The rendered file is the authority for the listener: the
port and bind address are read back from it and required to equal the endpoint
the launch serves. Six engines answer from this address -- bing, google, and
wikipedia in `qwen-open`, joined by mdn, github, and stackoverflow in
`qwen-broad` -- against duckduckgo, startpage, and qwant answering a CAPTCHA,
brave rate-limiting, and mojeek and yep denying, at 66 to 78 MB of resident
memory, 180 to 510 ms per query, and 18 to 20 results for `qwen-open` against
37 for `qwen-broad`.
`qwen-web-launch.sh` reads `searxng_url` from the launched profile's row,
admits the loopback endpoint alone, requires the port free, and exports
`QWEN_WEB_SEARXNG=1`; `qwen-webui-session.sh` then holds the instance as a
guarded child beside the broker, records `searxng_pid=` on the `state=running`
line and a `searxng_identity` line beside it, and proves `GET /healthz` and its
own child's liveness together before `run-qwen-capacity-server.sh` runs, so a
dead instance ends the launch ahead of the model load. The health gate lives
there rather than in the launcher because the launcher ends in `exec` and the
instance it starts exists one link later. `qwen-teardown.sh` compares the
recorded start time with `/proc/PID/stat` before signalling, the rule it
applies to the broker, and reports a surviving process or a listener on the
recorded port as residue.

`remote/admit-web-router-live.sh` is the live twin of the fake admission. It
copies one `remote/web-profiles.tsv` row into a ledger under its own output
directory with `execution_policy` alone moved to `validator-gated`, generates
the preset under `QWEN_WEB_AUTHORIZER_READY=1`, launches through
`qwen-web-launch.sh`, replays the page's requests with curl on the router port,
drives the served page through `drive-fallback-page.py`, and retains per-query
timing beside the instance's own resident memory and CPU ticks from `/proc`.
The fake run stays the authority for the refusals, whose fixtures answer
instantly; this run measures what only a live instance shows. A row moves to
`validator-gated` by an operator edit after a run of this harness is retained
under `evidence/`, and `web-open` is the one row that has made that move.
`evidence/web-live/20260903T0724Z/` retains the first run, against
`web-compact`: 29 rows, 24 passing, one grant, five results from bing in 1 s,
one 12,347-character fetch by Result ID, and a page turn whose requests stay on
the router and broker origins, at 66 MB of resident memory before the first
query and 75 MB over five threads after it. Its two failures were the harness
reading the search policy from the preset INI where the section names a
configuration, and `check-runtime-tree.sh` comparing two `LC_ALL=C` lists under
the invoking locale. `evidence/web-live/20260903T0810Z/` retains the `web-open`
run under the repaired harness, where both of those pass: 25 of 29 rows pass,
the search draws five results from bing and google in 1 s, and the one failure
is a fetch of `https://www.vulkan.org/` that the provider's own 20 s deadline
ended at HTTP 200 while the child's 30 s and the router's 3600 s were still
waiting. Which origin the first Result ID names changes with the query, so a
fetch arm that must pass whatever the network does belongs to the fake run.

`QWEN_WEB_LAN=1` moves the loopback boundary by an operator's explicit
decision, and `remote/web-lan-exposure.sh` holds what the decision costs.
`QWEN_WEB_LAN_ADDRESS` names one routable IPv4 literal, because the broker and
the artifact listener close DNS rebinding by comparing a request's Host header
against a literal set and a name would send that comparison back through the
resolver; `QWEN_BIND_HOST` is the router's own listener and defaults to that
one literal, binding every interface only where `QWEN_BIND_HOST=0.0.0.0`
carries the separate `QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1` opt-in, which the
launch prints loudly rather than folding into the ordinary exposure line.
Every derived origin and Host rule still reads the literal. The exposure then
reaches three listeners bound to that one interface: llama-server binds the
literal with `QWEN_REQUIRE_API_KEY=1`, `authorize-broker.py` and
`image-service.py` bind it too and add it to their admitted Host sets, and
each accepts the wildcard bind only where its own `--open-all-interfaces`
flag names the same decision. The Web UI bearer becomes the credential each
one requires -- `--lan-exposure` makes the broker read it on `POST /grant`,
`POST /grant-image`, and a `GET /health` naming the literal, where a loopback
Host keeps `/health` open so the session's own `curl` probe (now addressed at
the bound literal rather than a hardcoded loopback, so a single-interface bind
still answers it) holds the key off a world-readable `/proc/PID/cmdline`, and
the artifact listener already read it ahead of every lookup. The launch
requires the key file to exist at mode 0600 owned by the serving user rather
than minting one beside the socket, and refuses the exposure against either
research override, since `qwen-capacity-policy.sh` forces 127.0.0.1 for the
quarantine override and the unvalidated-depth marker and an exposure combined
with one would print an address it never binds.

The literal names an address, and `web_lan_interface_report` in
`remote/web-lan-exposure.sh` is what binds that address to a link. It reads
`ip -j addr` for the interface index, name, and MAC carrying the literal and
its prefix length, then `nmcli -t -f UUID,NAME,DEVICE connection show
--active` for the NetworkManager connection running that interface, so the
exposure names a link rather than only a number a DHCP lease could hand to
any interface. `QWEN_WEB_LAN_TRUSTED_CONNECTIONS` -- a colon-separated list of
connection UUIDs an operator declares -- gates that link: a declared list
refuses a launch whose resolved connection is outside it under either bearer
mode, and an absent list refuses `QWEN_WEB_LAN_OPEN=1` alone, since the
bearer is what an authenticated launch on an undeclared connection still
stands behind. A second loopback-range literal (127.0.0.2 and beyond) carries
no interface of its own -- the whole `127.0.0.0/8` block routes through `lo`
without a per-address row -- so it is exempted the way it already was from
every other exposure rule the harnesses lean on. `qwen-webui-session.sh`
records `lan_exposure=`, `lan_address=`, `lan_name=`, `lan_open=`, and
`lan_boundary=` on its `state=running` line, a companion `lan_interface` line
carrying the index, name, MAC, prefix length, and connection UUID and name,
and prints the page URL carrying `?broker=` and `?artifacts=`, because the
page's meta tags name the loopback and a LAN browser handed the bare router
address would point both back at its own machine. A git copy of a retained
`lan_interface` line sanitizes the MAC to `<mac>`, the way every other
committed evidence file does. What the exposure changes is who reaches the
approval dialog. The single-use grant the dialog signs, the schema the
wrapper enforces, and the one human approval per network-reaching call stay
exactly what they are, and every checked-in `execution_policy` still reads
`refused`.

A DHCP lease moves that literal, so `QWEN_WEB_LAN_NAME` adds one mDNS label to
the admitted set and the set stays closed to exactly one lowercase RFC 1123
label under `.local`. It defaults to this machine's own `hostname -s`
lowercased under `.local` where avahi-daemon runs and an explicit empty value
serves the literal alone. The rebinding closure holds for the name because a
browser resolves a `.local` name by multicast to the hosts sharing the link
rather than through a recursive resolver, so a bare hostname, a public domain,
a second label under `.local`, an uppercase letter, and a trailing dot are each
refused by name: every one of them registers in the ordinary resolver, and
admitting one would let a name an attacker controls in public DNS resolve to
this socket under DNS rebinding. `web_lan_name_is_valid` in
`remote/web-lan-exposure.sh` and `exposed_name` in `authorize-broker.py --lan-name`
and `image-service.py --lan-name` apply the identical rule, so a name the
launcher admits is a name both children admit too; each listener adds both page
origins to its CORS allowlist, and `trustedArtifactOrigin` admits the page's own
hostname whether address or name -- the browser already resolved that host to
fetch the page and the bearer is stored per page origin, so the credential
returns to the machine that served the page and no other. The
launcher names the page by the name with the literal beside it, since the name
outlives the lease.

`QWEN_WEB_LAN_OPEN=1` is the second explicit decision and it removes that
bearer. The router serves with `QWEN_REQUIRE_API_KEY` at 0, `--open-lan` makes
the broker sign `POST /grant` and `POST /grant-image` and answer an exposed
`GET /health` for a request presenting the session secret alone, and the
artifact listener reads an artifact for any admitted Host; both children read
no key file under the flag, because `read_secret_file` refuses the empty path a
keyless launch hands them. Every peer on the network can then chat, approve a
search, and approve a generation, and the launcher and `session.status` say so
on a `lan_open=1` line. What stands is every gate that is not the bearer: the
closed Host set, the Origin allowlist, the per-launch session secret, the
single-use grant, each wrapped tool's schema, and one human approval per
network-reaching and device-reaching call. The opt-in requires
`QWEN_WEB_LAN=1`, since a listener the operator never exposed has no bearer to
remove, and it meets both research-override refusals on the exposure's own
terms. Under the bearer mode the launcher prints the page link carrying
`#key=<bearer>` only where `[ -t 1 ]` finds stdout on a terminal, so the key
stays out of a redirected log; the page reads that fragment once, stores it,
and rewrites the address bar without it. `webui/index.html` never asks for the
key unconditionally: `boot()` probes `GET /v1/models` with no Authorization
header first, and a 200 there proves the router open, hiding the key field,
the LAN hint, and the copy button outright and dropping any key this browser
remembered rather than send a stale bearer to a listener that wants none. A
401 proves the router requires the bearer, and only then does an authenticated
retry carry a remembered or fragment key; the field reveals itself with a
one-line hint naming the launcher's printed link only where no such key exists
or the retry itself came back rejected.

`remote/qwen-lan-launch.sh` states the whole exposure decision as one of two
named security profiles rather than a bearer flag among nine others.
`lan-authenticated` is the default and the one-command fallback: every route
requires the Web UI bearer, matching the ordinary loopback launch's own
posture moved onto the network. `lan-open-approved` is the explicit household
opt-in this file's policy section names: every reachable peer chats, consumes
model time, and fetches a known artifact URL with no bearer, while the
approval dialog and its single-use grant remain the whole gate on search and
image execution. A caller naming a profile and a conflicting
`QWEN_WEB_LAN_OPEN` states two different bearer policies and the launch
refuses rather than picking one silently. `QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1`
and `QWEN_WEB_LAN_TRUSTED_CONNECTIONS` reach the launch from the same two
environment variables `web-lan-exposure.sh` reads, and the wrapper prints
`LAN BOUNDARY: lan-open-approved` or `LAN BOUNDARY: lan-authenticated` in
capitals at the end of every launch; `qwen-webui-control.sh status` echoes the
same line first, since it is the session's own recorded `state=running` line.
No unit file, crontab entry, or login hook starts either profile: the service
starts and stops through the launch and teardown scripts alone, so a reboot
leaves the machine with nothing listening under either boundary.

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
value format against another after matching architecture dimensions, tokenizer
identity, and tensor layout, in the order control, subject, subject, control.
The header check does not prove numeric tensor-value equality. The runner
reports the ratio of paired means because this tree has
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

That comparison predates the standing guest. The appliance pins its server to
core 0 at nice 19, and a qemu guest runs two vCPU threads at nice 0 across
both cores beside `ksmd` at nice 5, so under CFS a runnable vCPU on core 0
leaves the server weight 15 against 1024.
`evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T2154Z-nice-probe/`
measures llama-bench on core 0 under the commanded clock pair at nice 0
against nice 19 over six adjacent pairs: nice 0 decodes 1.9% faster, interval
+0.6% to +3.2%. The rate follows `load1` under both priorities, sliding from
9.74 to 9.26 tok/s at nice 0 as `load1` rose from 2.3 to 3.5, so the
priority is a 2% term and the guest's memory traffic through the shared L3 and
DDR4 controller is the candidate for the remaining 4% paired scatter; its
falsifier is one labelled diagnostic with the guest paused, which
characterizes a machine the appliance is not and decides nothing about
promotion.

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

