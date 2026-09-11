# The launch chain, link by link

The doctrine in `AGENTS.md` states the rule and this file carries the mechanism, the measurements, and the evidence paths behind it in full. The chain diagram and its five surprises stay in `AGENTS.md`; this file carries every admission harness, broker, image, lease, review, patch, and device-window mechanism behind them.

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

`$QWEN_HOME/state/vulkan-workload.lock` is that lease, and it is two-sided in
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
`7ef5095a...` that `verify-llama-patch-series.sh` pins for the replayed series,
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

A maintenance command that needs the device idle -- a build, a fetch, a
firmware read -- stops the running session first, and every path back out of
that command has to bring the session back the same way it left. `run-device-window.sh`
names that whole operation. It takes one exclusive advisory lock on
`$QWEN_HOME/state/device-window.lock` through `open-verified-lock-descriptor.py`,
the private-leaf construction `runtime-root.sh` applies to its own deletion
lock, so a second window refuses rather than queuing behind the first: a
queued window would tear the appliance down again while the first window's
command is still using the idle device. It reads the running session's own
`state=running` line for the relaunch profile -- `lan_boundary`,
`lan_address`, `port`, and the Vulkan submission `profile` -- rather than
taking one as an argument, so a window reproduces the launch it stopped
without the caller repeating every decision that launch made. A
`lan-open-approved` boundary was admitted only because the operator supplied
`QWEN_WEB_LAN_TRUSTED_CONNECTIONS` naming a trusted NetworkManager connection,
and that variable is a policy input rather than a session fact, so it carries
no record on the status line; a window opened without it in its own
environment relaunches `lan-authenticated` instead and records the
substitution rather than silently narrowing the exposure it hands back. The
window writes one ledger row per run under `$QWEN_HOME/results/device-windows/`
naming the moment it opened, the relaunch command it derived, and the command
it ran, then stops the session through `qwen-teardown.sh`, requiring its exit
0 before the caller's command starts. An EXIT trap covering normal exit,
failure, INT, and TERM alike relaunches through `qwen-lan-launch.sh` on every
one of those paths, verifies the relaunched session's own `state=running` line
and a `GET /health` against the address and port that line names, and appends
the relaunch outcome to the ledger. The window's own exit status is the
command's exit status, or 4 where the relaunch itself failed, so a caller
reads device downtime off one number rather than off two scripts run by hand.

