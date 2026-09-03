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
rsync -a --delete patches/ eirikr@qwen-laptop:~/qwen-laptop-setup/patches/
```

Every `remote/` script executes from `~/qwen-laptop-setup/remote/` on the
laptop. A change tested without that copy tests the previous revision.
`build-llama-trace.sh` and `verify-llama-patch-series.sh` read `../patches`
from their own directory, so the patch series travels with the scripts; a
stale patch there fails the replay digest gate before any build starts.

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
configuration because the UI performs the retrieval. Every checked-in row reads
`refused`, so the generator against the shipped ledger emits nothing and says
so. Every row still meets the registry join, the copied-field comparison, the
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

Router mode leaves depth, cache triple, and submission geometry off its own
argv. `server-models.cpp` ends its preset assembly with
`preset.merge(base_preset)` and `common_preset::merge` overwrites, so a router
CLI argument replaces the same key in every model section: passing `--ctx-size
24576` served the vision row at 24576 where its section named 16384. Every
section therefore carries all six keys, since an absent one falls through to the
llama.cpp defaults of batch 2048 and ubatch 512, which is the quarantined
geometry, and `LLAMA_ARG_CTX_CHECKPOINTS` beside them for the same reason.

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

## The parts, rated and measured

The ceilings above are rates. This section states the parts those rates come
out of. Each row carries what a manufacturer, an SPD EEPROM, or a firmware
table rates the part at, beside what this tree measures or a live read
observes, and the source that makes the second column true.
`evidence/hardware/qwen-laptop-parts.md` retains the raw command outputs and
`evidence/hardware/qwen-laptop-parts.tsv` carries one row per rating.
`measured` names a retained evidence file, `observed` names a sysfs or tool
read taken from the appliance, and `derived` names arithmetic over those two
with its inputs stated. A rating without a reading is `not read` with the
reason, because a wattage recalled from a product page is not a source.

A firmware table is a rating and can be wrong: SMBIOS prints
`Configured Memory Speed: 2400 MT/s` for both DIMMs, above their own SPD
profile and above the rate the UMC registers train at.

### Processor

| Property | Rated | Measured or observed | Evidence |
| --- | --- | --- | --- |
| Model | AMD Athlon Silver 3050U with Radeon Graphics, socket FP5 | the same string from both sources | observed, `dmidecode -t processor`, `lscpu` |
| Microarchitecture | Zen+, family 23, model 24, stepping 1 | the same signature | observed, `lscpu` |
| Cores and threads | 2 cores, 2 threads | 1 thread per core, SMT disabled | observed, `lscpu` |
| Base clock | 2300 MHz | the cpufreq table tops out at 2300000 kHz | observed, `dmidecode` Current Speed, `cpuinfo_max_freq` |
| Boost clock | 3200 MHz | 3169.362 and 2554.754 MHz on the two cores in one read, both above the cpufreq ceiling | observed, `dmidecode` Max Speed, `/proc/cpuinfo` |
| cpufreq range | -- | 1400000 to 2300000 kHz, boost enabled, scaling MHz 135% | observed, `cpuinfo_min_freq`, `cpuinfo_max_freq`, `lscpu` |
| Governor | -- | `acpi-cpufreq` with `schedutil` | observed, `scaling_driver`, `scaling_governor` |
| L1 | -- | 64 KiB L1d and 128 KiB L1i over two instances | observed, `lscpu` |
| L2 | -- | 1 MiB over two instances, 512 KiB per core | observed, `lscpu` |
| L3 | -- | 4 MiB, one instance | observed, `lscpu` |
| Vector ISA | -- | AVX2, FMA, F16C, SHA_NI | observed, `lscpu` Flags |
| TDP and cTDP | -- | not read | the powercap zones carry no `constraint_0_power_limit_uw`, amdgpu hwmon carries `power1_label` alone, and SMBIOS type 39 is absent |
| Host read bandwidth | -- | 7.97 GB/s on one thread, 15.44 GB/s on two | measured, `evidence/measurement-state-and-memory-clock.md` |

`acpi-cpufreq` enumerates the ACPI `_PSS` states and stops at 2300000 kHz, so
the boost clock reaches the core through the hardware's own CPB rather than
through a table entry, and `/proc/cpuinfo` reads it back from aperf/mperf.

### Graphics

| Property | Rated | Measured or observed | Evidence |
| --- | --- | --- | --- |
| Device | Raven2 iGPU, PCI `1002:15d8` rev `cd`, subsystem `103C:879E` | AMD Radeon Graphics (RADV RAVEN2) | observed, `lspci -nn`, `vulkaninfo --summary` |
| ISA target | gfx902 to the HSA runtime, gfx909 to LLVM | `gfx902:xnack+` is the target the runtime loads | rated, `hp14-raven2-gpu/docs/raven2-capability-decomposition.md` |
| Compute units | 3 present, 2 active, one fused off | `CU per SH 3`, `active_cu_number 2` | rated, the same document's geometry table |
| SIMDs | 4 SIMD16 per CU, 128 lanes | -- | rated, the same table |
| Wavefront | 64, fixed | `minSubgroupSize` equals `maxSubgroupSize` equals 64 | rated, the same document |
| Occupancy | 10 waves per SIMD, 2560 work-items per CU | -- | rated, the same table |
| LDS | 64 KiB per CU | `maxComputeSharedMemorySize` 65536 | rated, the same document |
| GPU caches | 16 KiB L1 per CU, 1 MiB L2 | -- | rated, the same table |
| FP32 FMA ceiling | 281.6 GFLOPS | -- | derived, 128 lanes x 2 flops x 1.1 GHz |
| Packed FP16 ceiling | 563.2 GFLOPS | -- | derived, the FP32 ceiling doubled by `v_pk_fma_f16` |
| FP64 rate | 1/16 rate, about 17.6 GFLOPS | -- | derived, the FP32 ceiling divided by 16 |
| Engine clock table | 200, 400, 1100 MHz | level 1 starred on an idle machine | observed, `pp_dpm_sclk` |
| Engine clock, idle | -- | 400 MHz | observed, hwmon `freq1_input` |
| Engine clock, delivered | 1100 MHz peak | 1100 MHz on 107 of 107 busy rows under `manual` | measured, `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T2002Z-fclk-level3/` |
| Fabric clock table | 0, 400, 933, 1067 MHz | level 2 starred on an idle machine | observed, `pp_dpm_mclk` |
| Fabric clock, delivered | 1067 MHz top step | 933 MHz on 137 of 145 rows and 1067 MHz on 8, under a level-3 `manual` write | measured, the same directory |
| Fabric clock, forced | -- | 400 MHz under `high` and `profile_peak` against 933 MHz under `auto` | measured, `.../dpm-authority/20260902T1822Z-actual/` |
| Fabric clock surface | -- | `pp_dpm_fclk` reads empty; the fabric table is the one `pp_dpm_mclk` prints | observed, both files |
| VRAM carve-out | 2048 MiB | 2147483648 bytes | observed, `mem_info_vram_total` |
| GTT | -- | 15723495424 bytes, 14.64 GiB | observed, `mem_info_gtt_total` |
| Integer dot product | `VK_KHR_shader_integer_dot_product` advertised | 0 of 30 accelerated bits, and the deployed server holds no `_q8_1` pipeline | measured, `evidence/tensor-type-execution-audit.md` |
| Cooperative matrix | -- | `VK_KHR_cooperative_matrix` absent on RADV RAVEN2 | rated, the capability decomposition |
| Global float atomic add | -- | false on buffers, true on LDS | rated, the capability decomposition |
| Driver | -- | Mesa 26.2.1 RADV, device apiVersion 1.4.354 | observed, `vulkaninfo --summary` |
| Achieved streaming | 34.13 GB/s memory peak | 8.11 GB/s on the 4B Q4_K_M and 10.41 GB/s on the 2B, four-block means | measured, `evidence/decode-bound-analysis.md` |

The engine clock has three values and they answer different questions: the
table states which steps exist, hwmon's `freq1_input` states what an idle
machine delivers, and the census runs state what a decode window holds. The
operating point every campaign runs at is named `manual-gfx1100-fclk933`:
`power_dpm_force_performance_level=manual` with `pp_dpm_sclk` at level 2 and
`pp_dpm_mclk` at level 2, which delivers 1100 MHz GFXCLK on every sample and
holds FCLK at 933 MHz as both hard minimum and soft maximum. It is the
highest commandable graphics state paired with the highest fabric state the
firmware honors as a hard minimum, and a maximum of neither clock table.

`high` and `profile_peak` are invalid for inference on this machine. Both
pin GFXCLK at 1100 MHz and drop delivered FCLK to 400 MHz, and the 2B
decodes at 6 to 7 tok/s under either against 9 to 9.6 under `manual` level
2 (`evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T1822Z-actual/`
and `20260902T1826Z-manual/`). `smu10_hwmgr.c` sends the hard-coded
`SMU10_UMD_PSTATE_PEAK_FCLK` of 1200 MHz for both, which the firmware answers
with its floor, so a generic performance-mode cleanup that reintroduces either
name reintroduces the 400 MHz fabric.

The clock record is bounded evidence rather than continuous observation. An
arm's `clock_invariant` counts every sample taken, `window_lost_fraction`
bounds the samples the sampler was held off for at 0.03, and the stall bound
refuses one gap on its own at 100 ms under `auto`, where a governor step can
hide inside it, and at 250 ms under a forced level, where the firmware holds
one state and the samples at both edges bracket the gap. A 2.5% lost fraction
satisfies coverage and leaves the throughput and GPU timestamps valid; it
licenses no statement that the clock held inside the unobserved intervals.

### Memory

| Property | Rated | Measured or observed | Evidence |
| --- | --- | --- | --- |
| Modules | 2 x 16 GiB Crucial CT16G4SFD8213.C16FAD SODIMM, dual-rank, 1.2 V | the same part number in both slots | observed, `dmidecode -t memory` |
| SPD profile | DDR4-2133, 15-15-15-36 | both EEPROMs CRC-valid at that profile | rated, `evidence/measurement-state-and-memory-clock.md` |
| Trained speed | 2133 MT/s | 2133.33 MT/s, both UMC `0x50200` reading `0x00000520` | measured, the same file |
| Trained timings | 15-15-15-36, tRP 15, tRC 51 | the same values from both channels at `0x50204` and `0x50208` | measured, the same file |
| Channels | 2 channels, 64 bits each | both populated as `P0 CHANNEL A` and `P0 CHANNEL B` | observed, `dmidecode -t memory` |
| Peak bandwidth | 34.13 GB/s | -- | derived, 2 x 8 bytes x 2133.33 MT/s |
| SMBIOS configured speed | 2133 MT/s by SPD | SMBIOS prints 2400 MT/s, above SPD and above the trained rate | observed, `dmidecode -t memory` against the UMC read |
| Installed capacity | 32 GB array maximum over 2 devices | 32 GiB installed | observed, `dmidecode -t memory` |
| Host-visible | -- | 30709952 kB, 29.29 GiB, after the 2048 MiB carve-out and firmware reserves | observed, `/proc/meminfo` |

### Platform

| Property | Rated | Measured or observed | Evidence |
| --- | --- | --- | --- |
| System | HP Laptop 14-dk1xxx, family `103C_5335KV HP Notebook` | the same strings | observed, `dmidecode -t system` |
| Board | HP 879E, version 84.53 | the same strings | observed, `dmidecode -t baseboard` |
| Firmware | AMI F.69 dated 2023-04-17, BIOS revision 15.69, firmware revision 84.53, 16 MB ROM | the same strings | observed, `dmidecode -t bios` |
| Kernel | -- | 7.0.0-29-generic x86_64 | observed, `uname -r` |
| Battery capacity | 3355000 uAh design at an 11.34 V minimum design voltage | `charge_full` equals `charge_full_design` | observed, `/sys/class/power_supply/BAT0` |
| Battery energy | 38.0 Wh | -- | derived, 3.355 Ah x 11.34 V |
| Adapter | -- | not read | SMBIOS type 39 is absent and `/sys/class/power_supply/AC` exposes `type` alone |
| Package power | -- | not read | amdgpu hwmon carries `power1_label PPT` with no `power1_average` or `power1_cap`, and the powercap zones carry no constraint limit |
| Thermal sensors | -- | four carry a temperature: `k10temp` Tctl, `amdgpu` edge, `acpitz`, and `nvme`; `hp` carries `pwm1_enable` and `BAT0` carries current and voltage | observed, `/sys/class/hwmon/*/name` and each `temp*_input` |
| Sustained temperature | -- | Tctl at 87 C at the end of a five-minute two-core load; the `amdgpu` edge sensor peaks at 85 C across the `manual` arms | measured, `evidence/raven2-vulkan-kernel-census/dpm-authority/README.md`, experiments 2 and 4 |

The 1067 MHz fabric state is firmware-selected and not commandable as a
floor. `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T2048Z-fclk-rescind/`
writes hard minimums of 400, 933, and 1067 in turn: the firmware honors 400
and 933 exactly and answers the 1067 request with 933 on 279 of 282 samples,
while `auto` selects 1067 on its own for about half of one loaded arm. The
one fabric experiment left is a `manual` mask enabling levels 2 and 3
together (`echo "2 3" > pp_dpm_mclk`) with GFX pinned at 1100, run as a
production-policy arm rather than a calibration state: it asks whether the
firmware raises the fabric under this workload with the 933 floor kept, and a
promotion comparison stays at fixed 933 because a mixed 933/1067 arm pair
resolves nothing at the 1 to 4% an E4-class effect is worth. The SMU10
kernel patch that would replace the hard-coded 1200 is deprioritized by the
same refusal, since the firmware path it would reach has already declined a
1067 hard minimum. Whether DDR4-2400 modules would train faster is a
separate hardware hypothesis rather than a setting, since the Zen+ FP5
processor family rates DDR4-2400 while the installed Crucial parts are
DDR4-2133 by their own SPD and the UMC registers train them at exactly that;
the 1200 MHz the SMU requests is a fabric clock and states nothing about
what the installed DRAM can train to.

## Three runtime classes, one primary target

The 2B class is the appliance's primary performance target, the 0.8B class its
secondary fast target, and the 4B class the quality-heavy fallback that tests
size and shape scaling. The early campaign centered the 4B and its rate target
leaked into experiment selection; that ordering is retired. A general runtime
experiment -- prompt-cache checkpoints, prefill geometry, MMVQ, cache type and
Flash Attention, workgroup and compiler changes, graph optimization, n-gram
speculation, aggregate throughput -- runs the current 2B first, the current
0.8B second, and the current 4B third, and its result becomes a Raven2-wide
default only where the classes agree; a win on one class alone becomes that
class's profile setting. A representation arm follows the same order and reads
the 0.8B's Q8_0, Q4_K_M, and F16 rungs as their own comparison, because that
class already showed a fixed-cost regime the larger two do not share.
Speculation follows role: a 2B target drafted by the 0.8B leads, a 4B target
drafted by the 0.8B follows, the 2B's own prediction block at N=1 ranks beside
the first, and the 0.8B as target takes n-gram or a smaller draft where one
loads.

The two leading pairings are second-tier serving options rather than experiment
arms alone, and `remote/draft-pairs.tsv` carries them.
`qwen38-2b-distill+qwen35-08b-draft` and `qwen38-4b-distill+qwen35-08b-draft`
sit at `candidate` with `-` evidence, `build-router-presets.sh` gives each its
own picker section, and `qwen-capacity-policy.sh` admits the section that names
it, so the ordinary launch chain serves either. `model-registry.sh draft-pairs`
and `draft-pair PAIR_ID [FIELD]` validate the whole ledger before either
answers, the discipline `tuples` applies to the tuple ledger. The mechanism is
`--spec-type draft-simple`: `tools/server/server-context.cpp` builds a second
`common_params` through `common_base_params_to_speculative`, which copies the
draft path, devices, layers, tensor overrides, and cache types over the
target's, and `common_speculative_init_result` loads that path as its own model,
so a pairing holds two checkpoints resident on one carve-out. The draft context
is derived rather than configured -- the same constructor assigns
`cparams.n_ctx = llama_n_ctx(ctx_tgt)` and no argument at f280b269 sets a draft
depth -- so `draft_context` records the derived value and the preset emits no
key for it. Both rows start at `spec_draft_n_max` 2, one column clear of the
five-column occupancy step `evidence/mtp-speculation-matrix.md` measures, where
its S4 and S6 arms decoded slower than no speculation at all.
`remote/measure-draft-pair.sh PAIR_ID OUTPUT_DIR` runs the 2B pairing first and
the 4B second, measures each against a same-session control of the target alone
in the order control, pair, pair, control, holds the shared Vulkan lease,
refuses listeners on both guarded ports, and requires an absent output path.
The harness snapshots the registry reader and its three ledgers before lookup,
binds every HTTP exchange to one PID, start time, and listener inode, and runs
the retained summarizer only from one hash-verified in-memory read. A
`quarantine` row remains terminal before any server starts.
`evidence/draft-pairs/README.md` registers the falsifiers and the tokenizer
finding the pairing rests on.

Quality belongs to the learned checkpoint and throughput belongs to the
execution class. Every checkpoint in `remote/models.tsv` -- stock, distill,
uncensored, or reasoning fine-tune -- receives its own graded reasoning, code,
tool-selection, and termination admission, and the only arm a fine-tune skips
is a throughput arm whose architecture, tensor shapes, quantization, backend,
and serving tuple equal a row already measured. Registry entry needs the
strict one-token Vulkan load alone; a filled-depth arm, the graded suite, the
tool-selection grade, and a role comparison against its class control follow
when the checkpoint is chosen for a role, and visibility in the picker does
not by itself schedule device time.

## The launch chain

One command starts the appliance and one ends it. The chain between them
matters because each link adds policy the next link assumes:

```text
qwen-launch.sh            waits for /health, prints reachable addresses
  qwen-webui-control.sh   owns the tmux session, forwards environment
    qwen-webui-session.sh arms probe, monitor, kernel-hazard watcher
                          and, under QWEN_WEB_BROKER=1, the approval broker
      run-qwen-capacity-server.sh
        model-memory-preflight.sh   reports headroom
        qwen-capacity-policy.sh     builds the llama-server argv
          radv-low-priority-env.sh  scrubs env, applies profile
            qwen-router-exec-guard.sh  rechecks authority identities, execs
```

Five properties of that chain surprise a reader who meets one file alone.

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

`qwen-web-launch.sh` exports `QWEN_WEB_BROKER=1` with the broker port, state
directory, signing key path, and the profile it reads from the preset, so the
session starts `authorize-broker.py` on 127.0.0.1 as a guarded child and
records it as `broker_pid=` on the `state=running` line. The broker starts
ahead of the capacity server because it allocates nothing on the device and
model loading holds the readiness loop for up to 120 seconds. The signing key
is required whole before anything launches: `QWEN_WEB_TOKEN_KEY_FILE` names a
regular file at mode 0600 owned by the serving user with nonempty content, the
launcher applies those rules and the broker applies them again before it
prints `listening`, and only the path crosses into the child. One broker signs
for one profile, since `POST /grant` refuses a `profile_id` other than its
`--profile`, so the launcher requires exactly one preset section and names it
`QWEN_WEB_PROFILE`; a caller whose own value differs is refused. The
`listening` line proves a socket and `GET /health` proves the process: the
session reads the broker's pid, profile, provider, signing-key SHA-256, and
`/proc/self/stat` start time from that route and fails the launch on any
mismatch, then records pid and start time on a `broker_identity` line.
`qwen-teardown.sh` compares that start time with the live `/proc/PID/stat`
before it signals, so a reused pid is left alone, waits for the broker to
leave, and requires `authorize-session.secret` to be gone whether or not a pid
was recorded, since the broker unlinks that file while unwinding from SIGTERM
and a surviving secret authorizes a page against the next launch. The ordinary
`qwen-launch.sh` path leaves the marker unset, records no `broker_pid`, and
starts no broker.

`remote/admit-web-router-fake.sh` runs that chain on the appliance against
the fake provider: the promoted `llama-server`, a real router child, the
broker, and the MCP child all execute, and every request the page would make
runs with curl in its place on the router port alone, from
`GET /tools?model=` through one grant, one search, one fetch by Result ID,
and each refusal the design relies on. The page itself then runs the same
turn: `qwen-web-launch.sh` serves `webui/index.html` rather than the pinned
llama UI build, because that build neither scopes `GET /tools` by model nor
posts the routing key, and `remote/web-mcp/drive-fallback-page.py` opens the
served page in the appliance's headless Chromium over the DevTools protocol
with the standard library alone, sends the prompt, approves the one dialog,
and reports every request the page's own `fetch` made. The admission reads
that log: the listing and the search post name the router port with the
model beside the tool, the grant comes from the broker, no request leaves
those two origins, and the transcript carries the Result ID. A router
serving any other page fails the run. The generated MCP configuration
carries the names `server.py` reads -- `QWEN_WEB_EXA_KEY_FILE`,
`QWEN_WEB_FAKE_FIXTURES`, `QWEN_WEB_MAX_FETCHES_PER_SEARCH`,
`QWEN_WEB_MAX_RESULTS`, `QWEN_WEB_MAX_CHARS_PER_FETCH` -- so the ledger's
per-profile budgets bound the child rather than describing it, and its
`timeout_ms` of 30000 sits between the provider's 20 s request timeout inside
`server.py` and the router's 3600 s proxy read timeout, so a stalled provider
is answered by the child's own deadline rather than abandoned by the router.

An image generation reaches the device the way a search reaches the network,
and one lease separates the two. `remote/image_protocol.py` freezes the job
frame at version 1 and both `image-service.py` and `image-mcp/server.py` import
it, so a closed request schema, a closed response schema, the 65536-byte line
bound, and the coarse `square`/`portrait`/`landscape` label have one reading
rather than three. `remote/build-web-presets.sh` reads
`remote/image-profiles.tsv` as a second execution grant under the rules the web
ledger takes: a `refused` row emits nothing under every setting, and a
`validator-gated` row adds one `image` server to each emitted section's MCP
configuration under `QWEN_WEB_AUTHORIZER_READY=1`, naming
`remote/image-mcp/server.py` with the section's own profile as
`QWEN_IMAGE_LANGUAGE_PROFILE` because the grant binds the language profile and
the image profile together. One image profile emits, since a section carries
one `mcpServers` object, and `image-sdxs-512-a` is the checked-in row that
carries the grant. Every other row reads `refused`. A generator run that names
no image ledger therefore reads the shipped one and requires the five image MCP
inputs, so a caller arming the web lane alone names an all-refused ledger in
`QWEN_IMAGE_PROFILES` the way `test-web-presets.sh` does.

The tool schema states what the section serves rather than what the lane
admits. The emitted configuration names `QWEN_IMAGE_PROFILES_JSON`, and
`tools/list` reads that file for the profile's geometry and ceilings, so
`profile_id` lists the one served profile as its enum and the width, height,
and step maxima are the ones `image-service.py` enforces from the same file. A
model reading the listing proposes inside them, and `webui/index.html` reads
the same listing: an argument above a stated maximum is answered with a tool
message naming the bound before the dialog opens and before the per-turn
budget moves, and the dialog and the grant carry the enum's profile with the
proposed one on a note line. Every failure after the approval -- a refused
grant, a `POST /tools` error status, a service refusal at HTTP 200, an artifact
that fails to load -- answers the call with a tool message and ends the turn,
because a dialog that settles nothing holds the page busy while the model waits
on a result that never arrives.

`remote/image-profiles.tsv` carries a `review_model` column naming the vision
checkpoint a shape's artifacts are reviewed by, and it decides whether the
preset serves one section or two. A named row makes
`remote/build-web-presets.sh` emit a review-only section for that model_id --
its `remote/models.tsv` tuple, its projector, a `validated` row in
`remote/validated-tuples.tsv` at that exact tuple with `projector_state=loaded`,
no MCP configuration, tags `vision-review,review-only` -- so `GET /v1/models`
returns two ids, `GET /props?model=` reports a vision modality for the second,
and the page's Review button appears on an artifact card. Two resident
checkpoints share one carve-out the 4B alone fills to 2029 of 2048 MiB, so
`qwen-image-launch.sh` sums every model and projector the preset names, adds
the image runtime's resident cost, hands the total to
`model-memory-preflight.sh`, and reports what it answers on every launch. A
paired launch refuses on that probe's own `vulkan_budget_headroom=short` line;
a one-section launch is the shape
`evidence/image-appliance/served-turn-admission/` already ran and passed, and
it reads the figure without being gated on it.
`image-sdxs-512-a` names `lfm25-vl-16b` because the probe reported the pair
ample twice on the appliance and one page session then generated and reviewed
one artifact through it; every other row reads `-`, since the RADV RAVEN2
probe runs on the appliance alone and no run has reported those pairs.
`evidence/image-appliance/paired-review-admission/` carries the admitted run,
where the review cost 19.44 s against the generation's 11.62 s: 14.77 s of
that is prompt evaluation of the 570-token multimodal prompt, so a smaller
reply budget reaches 4.67 s of it and the roster holds no faster reviewer than
the row already named.

`remote/qwen-image-launch.sh`
rejoins the preset's image markers to the ledger, requires the row to still
read `validator-gated`, requires its `review_model` to match the preset's own
marker and the review section to carry a projector and no MCP configuration, requires the parameter file the service runs a job
under to carry the ledger's own geometry and ceilings, and proves the deadline
stack ordered from the value each layer is configured with -- the runtime at
the smaller of the profile's `timeout_s` and `image-service.py`'s 300 s
ceiling, the service at its 330 s job deadline, the tool call at the emitted
`timeout_ms`, and the page at `webui/index.html`'s own
`IMAGE_GENERATION_TIMEOUT_MS`. The router proxy configures none of its own in
this tree, so the launch reads llama-server's 3600 s default and requires it to
outlast the tool call rather than asserting the 600 s bound
`remote/image-protocol.md` proposes. `qwen-webui-session.sh` starts the service
as a guarded child beside the broker and records `image_service_pid=` on the
`state=running` line, and `qwen-teardown.sh` compares its recorded start time
with `/proc/PID/stat` before signalling and then runs
`remote/image-teardown-check.sh`, which proves no service, no runtime, no
partial artifact, and a free lease.

The generation grant joins two profiles and the broker binds them with two
arguments. `image_grant.enforce_image_authorization` compares a claim's
`language_profile` against `QWEN_IMAGE_LANGUAGE_PROFILE` and its
`image_profile` against `QWEN_IMAGE_PROFILE`, which the emitted configuration
sets to the section's own id and to the ledger's image row, so
`authorize-broker.py` takes `--image-profile` beside `--profile` and the
session hands it `QWEN_IMAGE_PROFILE`. A launch that armed no image lane
leaves it empty and every `POST /grant-image` is refused. `GET /health`
reports the pair and the session compares both before it admits the launch, so
a broker signing for another lane fails at startup rather than at the first
approved generation.

`remote/admit-image-router.sh` runs that chain against one approved
generation. It sets one `remote/image-profiles.tsv` row to `validator-gated` in
a copy under its own output directory, writes a
`ui-mediated` language row so the emitted section carries the image server
alone, generates the preset under `QWEN_WEB_AUTHORIZER_READY=1`, launches
through `qwen-image-launch.sh`, and replays every request the page makes with
curl on the router port and the artifact listener: `GET /tools?model=` lists
`image_generate_image`, since `server_mcp_tool` serves each wrapped tool as
`<server>_<tool>` and the section configures the image MCP server under the key
`image`, `POST /grant-image` signs over a seed the script chose, one
`POST /tools` carrying the grant inside `params` completes with a digest and a
provenance route, and the replayed grant, the ungranted call, the
out-of-schema argument, the foreign image profile, and the uncredentialed
artifact read are each refused once. `GET /artifacts/<sha>.png` is compared
byte-for-byte against the digest the reply named and `GET /artifacts/<sha>.json`
against the seed and profile that produced it. The page then runs the same turn
through `remote/web-mcp/drive-fallback-page.py --lane image`, and the checks
read its own request log: the grant is posted once, the generation names the
model beside the tool, every request stays on the router, broker, and artifact
origins, and the retained tool message carries the digest and the route alone.
`evidence/image-appliance/served-turn-admission/` retains the run on the
appliance that moved `image-sdxs-512-a` to `validator-gated`: 41 rows, 40
accepted and one observed, one artifact generated in 12 s by the curl replay
and one in 11.3 s by the served page, with the model's own proposal inside
every bound the tool listing states and its seed displayed before approval.
`evidence/image-appliance/paired-review-admission/` retains the paired run
that moved its `review_model` to `lfm25-vl-16b`: 48 rows, 45 accepted and 3
observed, `sections=2`, and one page session carrying the approved generation
and a parsed vision review of its own artifact.
The 4B distill proposed a schema-valid call in every run there and the 2B
distill answered in prose, which its `raw_tool_selection` grade of 2/10
already states, so an image-capable language profile names the 4B.
`remote/test-admit-image-router.sh` runs the whole harness on the workstation
against `remote/test-fixtures/fake-router-server.py` and
`remote/test-fixtures/fake-image-runtime.sh`, replacing the four device-owning
links -- the memory preflight, the graphics latency probe, the kernel-hazard
watcher, and the runtime monitor -- and leaving the launch chain, the broker,
the service, the lease, the MCP child, the served page, and the teardown as
the tree's own.

The artifact listener is a second origin the page is told about. `--http-port`
defaults to 0, so `qwen-webui-session.sh` reads the address the service printed
and records it on its `image_service_identity ... listener=` line, and the
router proxies none of `/artifacts/`. `webui/index.html` therefore resolves an
artifact origin from an `?artifacts=` query parameter, then a
`qwen-image-artifacts` meta tag, then its own field, and a page given none says
so rather than resolving the route against the router. The image route itself
is derived from the digest: `provenance_url` names the `.json` record and the
page composes `/artifacts/<sha>.png` from the same value, so one reply carries
one identity and both routes follow from it.

`~/qwen-webui-state/vulkan-workload.lock` is that lease, and it is two-sided in
time rather than tied to residency. `image-service.py` holds it from job start
to artifact rename, and its acquisition waits on a bounded deadline --
`QWEN_IMAGE_LEASE_WAIT_S`, 60 seconds by default, zero for one non-blocking
attempt -- because the chat turn that emitted the approved tool call is still
releasing when the generation request arrives; the refusal past that deadline
keeps the `lease_unavailable` reason.
`patches/llama-server-vulkan-workload-lease.patch` makes llama-server the second
writer under `QWEN_VULKAN_WORKLOAD_LOCK`, which `qwen-capacity-policy.sh`
exports from the session state directory on every launch and
`radv-low-priority-env.sh` leaves alone.
`server_context_impl::update_slots` owns the transitions: it takes the lease
where its all-idle check finds a busy slot and releases it where the check finds
none, so an idle loaded server holds nothing while every decoding pass runs
inside the lease, and the release trails the final decode by exactly one pass.
Acquisition returns whether the pass may submit: a wait ended by a terminating
signal or refused by the kernel leaves `update_slots` before it posts
`NEXT_RESPONSE`, so no graph reaches the device in a pass that holds no lease.
The acquire tries `LOCK_EX | LOCK_NB` first and logs the waiting line ahead of
the block, so a stall is visible while it lasts and the acquire line carries
`waited_ms`. The child holds it in router mode, since `server.cpp` calls
`load_model` and therefore `init()` only in its non-router branch while
`server-models.cpp` spawns each child from the `environ` snapshot in `base_env`.
`remote/test-vulkan-workload-lease.sh` admits both halves and
`evidence/vulkan-workload-lease/README.md` registers the invariant, the
falsifiers, and the appliance sequence; the patch is a candidate under
`QWEN_LLAMA_CANDIDATE_PATCHES=1` awaiting admission on the device.

A review of a generated image is the next transition through idle, and it runs
against a vision model holding no executable tool. `remote/image-review.py`
reads the artifact through `GET /artifacts/<sha256>.png` with the Web UI's own
bearer credential, hashes the bytes against the digest the caller named, and
posts one non-streamed `/v1/chat/completions` whose body omits `tools`
entirely, at temperature 0, 400 reply tokens, thinking off, and a 300 s
deadline. The reply is one JSON object carrying exactly `hard_constraints`
(one `name`/`passed`/`observation` entry per declared constraint),
`composition_change_required`, `prompt_delta`, and `regenerate`; prose, a
fenced block, an extra key, a missing key, a `passed` that is a number, a
constraint the caller never declared, and a reply carrying `tool_calls` are
each refused with the code naming the rule. The generation prompt stays out of
the request, which binds the same `prompt_hash` the image grant is signed over,
and the audit line carries counts, booleans, `delta_chars`, and the delta's
SHA-256 rather than the observation or delta text a model wrote after reading
an image. `reasoning_emitted` sits on that line because
`chat_template_kwargs.enable_thinking` is inert against a template with an
unguarded `<think>`, and a reasoning span inside 400 tokens ends the object
unclosed for the same `not_json` the fence produces.

`webui/index.html` runs that schema in the browser and bounds what a verdict
may cause. The Review button appears on an artifact card where
`GET /props?model=<id>` reports a vision modality for some roster row, the
review holds the same `busy` flag a chat turn holds, and the verdict, its
observations, and any correction stay out of `history`, so image-derived text
never enters the transcript every later request re-sends. Three facts admit a
correction -- a constraint the model marked failed, the `regenerate` flag, and
a non-empty `prompt_delta` -- and a correction is a proposal: the composed
prompt meets the tool schema's maxima, the first approval's seed travels on the
card rather than being chosen again, and the same approval dialog signs a fresh
single-use grant over the composed prompt's hash. Two approved corrections per
original request are the whole allowance, counted in the card's lineage so a
correction's own review inherits the counter rather than restarting it.
`remote/test-image-review.py` drives the module against a fake vision router
that answers a tools-carrying request with a tool-call proposal, and
`remote/web-mcp/test-fallback-page-image.py` drives the served page through one
review, two approved corrections, and the third that reports the cap.
`evidence/image-appliance/vision-review-design.md` registers the state machine,
the schema, and the falsifiers, and names `lfm25-vl-16b` as the first appliance
arm with `qwen35-2b` as its control inside one sweep.

A grammar states reply shape and leaves the source of a verdict open, so
`image-review.py` takes `--image-mode` over `real`, `withheld`, and `swapped`
with `--swap-sha256` naming the second artifact a swapped review sends.
`withheld` keeps the multipart text part and drops the image part, the
image-withheld convention `remote/run-quality-suite.py` applies to its graded
vision rows, and `swapped` sends another artifact's bytes under the same prompt
hash, constraint list, model, temperature, reply budget, thinking setting, and
absent `tools` key. Both modes still read and hash the reviewed artifact over
its own route, so every `fetch_artifact_png` refusal holds for a control arm and
the audit line and verdict record carry `image_mode` beside `swap_sha256`.
`remote/run-vision-review-control.sh` runs real-A, withheld-A,
swapped-A-with-B, and a closing real-A through one router and one artifact
listener, retains a verdict record and an audit line per arm, and prints a
summary TSV of per-arm `passed` counts and the `regenerate` flag. Every arm sends
`--no-prompt-cache`, since the four requests share the text part ahead of the
image part and a warm prefix moves an answer on this backend rather than only
its timing, so the closing arm's agreement with the opening one is what licenses
reading the two control arms as image effects rather than as position in a
request sequence.
`evidence/image-appliance/vision-review-control-design.md` registers the
hypothesis, the arm order, and the falsifiers ahead of any run: a withheld arm
passing every constraint it cannot see refutes the visual grounding, and swapped
observations agreeing with A rather than B report the same thing through a
second route.

`patches/llama-router-tools-proxy.patch` is what puts the route on the router
port. At f280b269 `server.cpp` registers `/tools` only in a process whose own
MCP manager holds a server, and the router branch proxies chat, props, and
slots without it, so an unpatched router answers `403 feature_disabled` while
the child serves the route on an internal loopback port
(`evidence/web-admission-fake.md`). The patch registers `/tools` on a router
that holds no tools of its own as `proxy_get` and `proxy_post`, so `GET`
resolves `?model=` and `POST` resolves the body's top-level `model` key the
way `/props` and `/v1/chat/completions` do, and the child that read the
section's configuration executes the call. The child's `handle_post` reads
`tool`, `params`, and `stream` alone, and `server.py` refuses any argument
outside a tool's schema by name, so the routing key provably stays out of the
tool arguments. The ordinary preset carries no MCP configuration, so the same
binary answers `403 feature_disabled` for every ordinary model: the route is
in the binary and the tool set belongs to the section.
`evidence/web-admission-router-tools.md` records the run on that closure.

`patches/llama-vulkan-view-alias-deps.patch` is the seventh member of the
production series. `ggml_vk_graph_optimize` at the pinned commit compares
view bases rather than the underlying tensor when it decides which nodes may
reorder, so two views of one buffer read as independent and a write moves past
a read. On the appliance the production build answered the same prompt with
different token arrays four requests into one process at temperature 0 on
five of six prompts, the first difference inside fourteen tokens, while the
optimizer-off arm and the patched arm were identical on every self-consistency
comparison; `evidence/vulkan-view-alias/ab-2b/` retains the run. A source tree
the promoted build compiles from must carry every series member: the
appliance's tree was one patch behind the verifier's list before this
promotion, which the digest line in the promote chain now catches before a
build.

`patches/llama-server-natural-checkpoint-boundary.patch` is the eighth member
and it decides what a positive `--ctx-checkpoints` count means.
`server-context.cpp` at the pinned commit force-breaks the prompt fill loop
`4 + n_ubatch` and `4` tokens from the end whenever checkpoints are armed, so
the decode execution shape differs between a count of 0 and a count of 2 and
the 0.8B emits a different first-turn token at zero-based index 25 on every
positive arm. The patch removes that block, leaving checkpoints on the natural
`n_batch` boundaries the loop already produces. All three classes then hold
token identity across the setting: five 4B witnesses -- frozen production c0,
candidate c0 opening, candidate c2 first, candidate c2 repeat, candidate c0
closing -- agree bit-for-bit on ids and retained logprobs over both turns while
a c2 second turn charges 28 tokens against 30,748, and the 0.8B and 2B carry
the same relation. `evidence/ctx-checkpoint-natural-boundary/` retains the runs.

The ledger and the binary are separate release artifacts, so an edit to
`remote/ctx-checkpoints.tsv` alone would pair a positive count with the
unrepaired implementation. A build earns its declaration rather than asserting
one: `build-llama-preset.sh` writes `checkpoint_semantics` as
`natural-boundary-v1` only where the repository still holds the patch at
`c9d40105...`, the `tools/server/server-context.cpp` it compiles hashes to the
`3744317b...` that `verify-llama-patch-series.sh` pins for the replayed series,
and the `checkpoint_offsets` array is absent from that source. The negative
name is earned the same way: `forced-tail-v1` requires the source to hash to
`a79cf9e1...`, the pinned commit's own `server-context.cpp` that the
seven-patch production prefix leaves untouched, and every other source writes
`unknown`, since a later upstream revision may restructure the partition or
place checkpoints by a third rule that no digest here identifies. Both names
refuse a positive count and attribute the refusal to different sources. The
manifest records `checkpoint_patch`,
`checkpoint_patch_sha256`, `checkpoint_source_sha256`, and
`checkpoint_patch_series_sha256` beside it, so the claim is checkable after the
fact rather than trusted. A preset name is a build role and proves no source
repair, and a caller-supplied value proves less, which is why neither decides
the field.

`remote/llama-patch-series.tsv` states the ordered series once.
`verify-llama-patch-series.sh` replays its `production` stage and prints one
`patch_series_sha256` over the members' own digests in ledger order,
`prepare-llama-vulkan-source.sh` applies that stage to a clean tree, and
`build-llama-preset.sh` recomputes the same digest for the manifest. A member
added to the ledger reaches all three rather than one.

`qwen-capacity-policy.sh` refuses a positive count against any declaration
other than `natural-boundary-v1` while the reason is still readable beside the
argv it would have produced, and `qwen-build-exec-guard.sh` states it again at
the exec boundary on both serving paths, after `radv-low-priority-env.sh` and
ahead of `qwen-router-exec-guard.sh` where a router launch runs one. The guard
resolves the executable through its symlinks, requires the manifest to still
hash to what the policy measured, requires exactly one executable row matching
that server's own byte count and digest, and requires exactly one
`checkpoint_semantics` row, so a symlink repointed, a manifest relabelled, or a
server replaced between assembly and exec is refused rather than served. The
requirement follows the count that will actually reach a server: the ledger's
row on the single-model path, and a positive `LLAMA_ARG_CTX_CHECKPOINTS` in
some preset section under router mode, so an all-zero preset launches a build
predating the declaration. `promote-llama-build.sh` applies the same rule at
the symlink swap and refuses a rollback to a target the current policy cannot
launch, since a rollback that leaves the appliance refusing every launch trades
a wrong answer for an outage nobody chose.

## Commands

```sh
# Start and stop the appliance (run on the laptop)
~/qwen-laptop-setup/remote/qwen-launch.sh [paced-60|low-serialized|low-async]
~/qwen-laptop-setup/remote/qwen-web-launch.sh [PROFILE]   # web presets, loopback only
~/qwen-laptop-setup/remote/qwen-image-launch.sh [PROFILE] # web presets with the image lane armed
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
remote/model-registry.sh draft-pairs | draft-pair PAIR_ID [FIELD]
remote/model-registry.sh ctx-checkpoints | ctx-checkpoint MODEL_ID
remote/measure-draft-pair.sh PAIR_ID OUTPUT_DIR
                                                # snapshot-bound ABBA pairing
remote/build-router-presets.sh [OUTPUT_INI]    # the picker, from the tier field
remote/build-web-presets.sh OUTPUT_INI         # web profiles, from the execution_policy field
remote/fetch-candidate-artifact.sh REPO REV FILE DIR  # observed, not pinned
remote/run-one-token-admission.sh RECORD [OUT]  # load every candidate once
remote/run-representation-arm.sh LABEL CONTROL SUBJECT
                                                # one value format against another, ABBA
remote/admit-web-router-fake.sh OUTPUT_DIR      # the web router against the fake provider
remote/admit-image-router.sh OUTPUT_DIR         # one approved generation through the router
remote/probe-depth-projector.sh MODEL_ID OUT   # filled depth, projector loaded
remote/image-registry.sh artifacts|models|profiles|bundle|profile
                                                # the four image authorities, validated whole
remote/run-image-standalone.sh OUT MODEL       # one image, no llama process resident
remote/build-stable-diffusion-vulkan.sh        # sd-cli from the pinned commit, Vulkan only
remote/image-service.py --state-dir DIR --profiles-json FILE
                                                # the lease owner, one generation at a time
remote/image-teardown-check.sh [STATE_DIRECTORY]
                                                # no service, runtime, partial artifact, or held lease
remote/test-vulkan-workload-lease.sh           # one workload, both writers of the lease
remote/image-review.py --router-origin URL --artifact-origin URL --model ID \
    --sha256 HEX --prompt-hash HEX --constraint NAME=DESCRIPTION \
    [--image-mode real|withheld|swapped [--swap-sha256 HEX]]
                                                # one artifact reviewed by a vision model, zero tools
remote/run-vision-review-control.sh ROUTER_ORIGIN ARTIFACT_ORIGIN MODEL \
    SHA256_A SHA256_B PROMPT_HASH OUTPUT_DIR --constraint NAME=DESCRIPTION
                                                # real, withheld, swapped, and a closing real arm
remote/run-graph-alias-ab.sh OUTPUT_DIR [MODEL_ID...]
                                                # token identity across the graph optimizer
remote/run-ctx-checkpoint-sweep.sh LABEL MODEL_ID OUT
                                                # what --ctx-checkpoints buys a second turn at 30K

# Stage A pipeline census: a diagnostic build the bundle layer refuses,
# measured through the served path under the scoreboard's own tuple.
# evidence/raven2-vulkan-kernel-census/README.md registers the design.
# The census brackets every vkCmdDispatch with a top-of-pipe timestamp
# ahead of it and an all-commands timestamp after it; the bracket is a
# queue-residency envelope, an upper bound wherever the queue lets
# neighbours overlap, so the ledger states each pipeline's bracket upper
# bound, its exclusive time from an endpoint sweep as the lower bound, and
# the ambiguous overlap, and reads ownership=inconclusive above a mean
# overlap fraction of 0.05 rather than printing a share. The pool is read
# with availability rather than a wait where the graph's fence has
# retired, each dispatch is bound to the submission serial allocated at
# submit, each pipeline is keyed by the SHA-256 of the module bytes
# vkCreateShaderModule received (self-tested against known vectors at
# census open and against sha256sum by test-census-sha256.sh), and every
# graph is stamped through clock_gettime(CLOCK_MONOTONIC), the clock
# measure-served-decode.sh retains its request window on. The summarizer
# selects the timed request's graphs by that window, validates every graph
# inside it ahead of the phase filter, refuses a graph straddling the
# window, recomputes every graph aggregate from the dispatch rows, requires
# exactly predicted_n - 1 decode graphs, and refuses overflow, an
# unavailable query, an unbound dispatch, a fallback read, or a waited
# read outright; an I1 arm completes only where it accepts. The
# instrument's own host cost sits after fence retirement in readback_ns,
# dispatch_row_emit_ns, and the census_emit row's total_emit_ns.
# Five states run, every one through measure-served-decode.sh: P is bound
# to the fixed-64 receipt's server row and its manifest, P-nosidecar is P
# with the sampler off, I0 and I1 are the census build with collection off
# and on, and S runs the pinned vk_perf_logger under the diagnostic
# profile through the launch chain, reading the server.log slice cut at
# the request window. Three quadruples carry a bound, P-nosidecar P P
# P-nosidecar, P I0 I0 P, and I0 I1 I1 I0; any other is unclassified, and
# a refuted control ends the campaign refuted with exit 3 whatever the
# arms did. QWEN_CENSUS_MODE=calibration, the default, runs exactly the
# thirteen-arm sequence and accepts on exactly three accepted controls
# with none unclassified; QWEN_CENSUS_MODE=attribution runs any registered
# arm list and requires QWEN_CENSUS_CALIBRATION_RECEIPT to name the output
# directory of an accepted calibration that bound the same two server
# digests. P's denominator is bound beside its binary: the receipt
# directory's models-resolved.tsv must resolve the model to the tuple and
# artifact digest the registry and ledger resolve now, and its
# campaign-inputs.tsv must state the low-async profile, 64 tokens, the
# fixed sampling, nice 19, Vulkan placement, and speculation off. The
# summarizer splits ambiguous overlap into same-pipeline and cross-pipeline
# halves beside the whole-overlap verdict, since cross-pipeline overlap
# alone blocks family ownership. P and I must yield one base-build
# identity (commit, patch series and checkpoint digests, compiler flags,
# CMake flags less the one census flag, and the executable's .comment
# compiler string) and I's CMake delta must be exactly
# -DGGML_VULKAN_PIPELINE_CENSUS=ON, so P/I0 measures compiled
# instrumentation alone. The FCLK allowance is granted only where a read
# of pp_dpm_fclk succeeds and returns nothing, since sysfs reports every
# attribute at one page in stat; the sidecar validator refuses an adjacent
# sample gap above 20 ms inside the request window.
# The runner writes calibration-contract.tsv (tuple, both digests,
# base-build identity, request shape, sidecar geometry and bounds, latency
# probe digest) and records its SHA-256; an attribution requires the
# receipt's calibration_contract_sha256 to equal its own, and
# QWEN_CENSUS_PRINT_CONTRACT=1 prints the contract without touching the
# device. A TERM to the runner ends the served child and the sidecar
# together. The measurement head and the analysis head are recorded
# separately, so a gated reader fix reinterprets retained raw records.
# The 10 ms sidecar on either core at nice 19 is evidence only where
# validate-clock-sidecar.py accepts its record, and its refusal fails the
# arm. A diagnostic build reaches the device through an explicit
# QWEN_LLAMA_SERVER alone: bundle assembly and activation refuse any
# manifest naming instrumentation, refuse a serving_eligible row reading
# anything but yes including an empty value, and refuse either row twice;
# the explicit-server launch is the recovery mode the bundle layer leaves
# alone.
remote/prepare-llama-census-source.sh BASE PATCHED llama-vulkan-pipeline-census.patch
QWEN_LLAMA_CANDIDATE_SELECT=llama-vulkan-pipeline-census.patch \
    remote/build-llama-preset.sh raven2-vulkan-census PATCHED
QWEN_CENSUS_PRODUCTION_SERVER=P QWEN_CENSUS_PRODUCTION_RECEIPT=identity-check.tsv \
QWEN_CENSUS_INSTRUMENTED_SERVER=I \
    remote/run-raven2-vulkan-kernel-census.sh MODEL_ID OUT
                                # calibration: P-nosidecar P P P-nosidecar, P I0 I0 P, I0 I1 I1 I0, S
QWEN_CENSUS_MODE=attribution QWEN_CENSUS_CALIBRATION_RECEIPT=OUT QWEN_CENSUS_ARMS=I1 \
    remote/run-raven2-vulkan-kernel-census.sh MODEL_ID OUT2
remote/summarize-kernel-census.py OUT/arms/NN-I1/pipeline-census.tsv \
    --window-begin-ns B --window-end-ns E --expected-decode-graphs 63
remote/summarize-census-controls.py OUT/arms.tsv --sidecar-bound 0.0065 \
    --compile-bound 0.0065 --collect-bound 0.02
remote/sample-clock-sidecar.py OUT.tsv --period-ms 10 --cpu 0,1 --nice 19
remote/validate-clock-sidecar.py OUT.tsv --sidecar-status 0 --period-ms 10 \
    --period-tolerance 0.25 --cost-bound-ns 1000000 --max-gap-ns 20000000
remote/summarize-perf-logger-slice.py OUT/arms/NN-S/server-log-request.slice \
    --expected-decode-blocks 63

# Deployment bundles: the server, its manifest, the checkpoint ledger, and
# the presets generated against that ledger as one activated unit.
# Activation and rollback are the same atomic symlink transition, serialized
# on descriptor 7 of .activate.lock under the root, which
# open-verified-lock-descriptor.py opens without following a link or
# truncating, refuses a leaf with more than one hard link, and holds
# exclusively for the activator and shared for the resolver. An automatic launch resolves the bundle once:
# resolve-active-deployment.sh follows deployment-current to one directory
# immediately below the root, verifies it whole through
# verify-deployment-bundle.sh, and the launchers and qwen-webui-control.sh
# read server, ledger, router-presets.ini, and web-presets.ini from that one
# directory as QWEN_ACTIVE_DEPLOYMENT_DIRECTORY, so an activation during a
# launch changes nothing the launch serves. An explicit
# QWEN_ACTIVE_DEPLOYMENT_DIRECTORY is verified rather than inferred, and an
# explicit QWEN_LLAMA_SERVER is the recovery mode that reads no bundle at
# all, so a broken deployment-current refuses the automatic launch and
# leaves the manual one alone. Every name read back from the root is held
# to its namespace (a role link targets exactly ../NAME, a generation link
# exactly deployment-state.N, a bundle name [A-Za-z0-9][A-Za-z0-9._-]*
# outside the root's own names, no symlinked bundle or member), assembly
# stages under a random .staging directory and verifies before the rename,
# the artifact manifest carries exactly one executable llama-server row and
# that row matches the bundled server, and a preset section is bound to the
# ledger count of the model its LLAMA_ARG_MODEL resolves to through the
# registry. A rollback to the forced-tail build therefore travels with the
# all-zero ledger and the all-zero preset it is admissible under.
# evidence/deployment-bundle-presets/ retains the router regression across
# activation, rollback, an activation under a paused launch, a recovery
# launch over a broken deployment, and a symlinked lock leaf.
QWEN_CTX_CHECKPOINT_LEDGER=LEDGER remote/build-router-presets.sh OUT.ini
QWEN_BUNDLE_ROUTER_PRESETS=OUT.ini \
    remote/build-deployment-bundle.sh NAME SERVER MANIFEST LEDGER [ROOT]
remote/activate-deployment-bundle.sh NAME|rollback [ROOT]
remote/verify-deployment-bundle.sh ROOT NAME
remote/resolve-active-deployment.sh [ROOT]     # the one bundle a launch reads
remote/verify-bundle-preset-ledger.sh PRESET LEDGER [REGISTRY]

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
remote/download-sdxs-512.sh                    # the image funnel's first rung
remote/download-sd15-base.sh
remote/download-sd15-vae.sh
remote/download-sd-turbo.sh
remote/download-lcm-lora-sd15.sh
```

Tests are standalone POSIX shell scripts that exit non-zero on failure. Run one
directly:

```sh
remote/test-qwen-runtime-guards.sh
remote/test-radv-low-priority-env.sh
remote/test-model-registry.sh
remote/test-model-tiers.sh
python3 remote/test-summarize-draft-pair.py
remote/test-measure-draft-pair.sh
remote/test-probe-depth-projector.sh
remote/test-web-presets.sh
remote/test-qwen-web-launch.sh
remote/test-image-registry.sh
remote/test-qwen-image-launch.sh
remote/test-run-image-standalone.sh
remote/test-admit-image-router.sh
remote/test-vulkan-workload-lease.sh
remote/test-fallback-webui-image-authorization.sh
python3 remote/test-image-protocol.py
python3 remote/test-image-service.py
python3 remote/image-mcp/test-image-mcp.py
python3 remote/test-image-review.py
python3 remote/web-mcp/test-fallback-page-image.py
remote/test-quality-suite.py
remote/test-quality-roster.sh
remote/test-promote-llama-build.sh
remote/test-classify-checkpoint-semantics.sh
remote/test-check-runtime-tree.sh
remote/test-deployment-bundle.sh
remote/generate-quality-images.py --check
remote/test-gguf-tokenizer-identity.py
remote/test-admit-candidate-static.py
remote/test-one-token-admission.sh
remote/test-fetch-candidate-artifact.sh
remote/test-run-graph-alias-ab.sh
remote/test-run-ctx-checkpoint-sweep.sh
python3 remote/test-summarize-kernel-census.py
python3 remote/test-census-controls.py
python3 remote/test-sample-clock-sidecar.py
python3 remote/test-summarize-perf-logger-slice.py
remote/test-census-sha256.sh
remote/test-run-raven2-vulkan-kernel-census.sh
remote/verify-llama-patch-series.sh
QWEN_LLAMA_CANDIDATE_PATCHES=1 remote/verify-llama-patch-series.sh
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

The low-bit route closes at 0.8B on the measured rows. The three 0.8B-class checkpoints of
`evidence/model-admission/runtime-class-throughput.md` decode at 15.96, 15.17,
and 15.31 tok/s while streaming 0.477, 0.547, and 0.801 GB per token: 5.2% of
rate across 67.9% of bytes, over two value formats and two architectures, with
every arm inside the sweep's span criterion. The whole token time there is 63
to 66 ms, about a fifth of the 4B's 314 ms. The matched-structure pair streams
0.254 GB more per token with a 0.6 ms shorter observed token time, inside the
declared span. Architecture and format change with bytes across the wider set,
so the measurements isolate neither a marginal byte cost nor the mechanism that
sets the rate.

The consequence is a serving decision. Qwen3.5-0.8B at Q8_0 streams 46.4% more
bytes per token than the same checkpoint at Q4_K_M and the two decode rates
differ by 0.9%, inside the within-arm deviations, so the direction is
unresolved. Both registered accounts predicted the Q4_K_M 23 to 48% faster and
are refuted on magnitude; the served `qwen35-08b` Q8_0 row keeps its position
and a Q4_K_M rung of that class competes on quality rather than on throughput.
The prefill halves separate where the decode halves do not, 146.22 against
134.91 tok/s, which places Q4_K's super-block scale decode in the half where
arithmetic rather than a per-token cost dominates.

Qwen3-Zero-Coder-Reasoning-0.8B runs 42 blocks at 1024 embedding width against
the Qwen3.5-0.8B's 24 and achieves 7.62 GB/s against 8.30 at 87.3% of the bytes,
with a 24.3% prefill deficit against a 5.2% decode advantage. Achieved GB/s is
bytes times rate, so that 8.2% deficit restates the two inputs, and the rows
differ in architecture, feed-forward width, and head counts beside block count,
so a per-dispatch cost stays a correlated observation until one trunk is
measured at two depths.

Two architectures now break the size ordering of achieved rate in the same
direction. `evidence/model-admission/universal-candidate-ladder.md` recorded
LFM2's short-convolution blocks doing it, and Qwen2-VL-2B at 28 blocks of full
attention over 12 heads and 2 KV heads achieves 8.24 GB/s against the 2B
distill's 9.71 in one sweep while streaming 22.4% fewer bytes. The operator mix
rather than the byte count orders achieved rate across architectures.

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

A candidate fetched from Hugging Face LFS is verified against the publisher.
`remote/fetch-candidate-artifact.sh` reads the pinned revision's LFS object ID,
requires the downloaded SHA-256 and byte count to match it, and reports the
digest as `verified_sha256`. A repository artifact published outside LFS has no
publisher digest; the fetcher reports that fallback as `observed_sha256`, and
promotion into `remote/models.tsv` requires a `download-*.sh` that pins the
observed digest as its expectation.

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

Use affirmative, mechanism-centered prose. Describe what the system does, the
state transitions it performs, and the observable result. State behavior
directly rather than defining it through "no," "does not," "lacks," or
"without." Use negation only when absence itself is materially relevant.

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
