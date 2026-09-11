# Commands

The doctrine in `AGENTS.md` states the rule and this file carries the mechanism, the measurements, and the evidence paths behind it in full. Every script also prints its own usage block on argument error.

```sh
# The runtime root, from the appliance's own checkout
make bootstrap                                  # lay out $QWEN_HOME (.runtime) and its marker
make install-searxng && make verify-searxng     # the pinned instance under opt/searxng, user-owned
make searxng-wheelhouse                         # the lock's wheels by digest under opt/searxng
make verify-searxng-wheelhouse                  # every wheel at its pinned digest, none unnamed
make install-ryzenadj install-image-runtime install-shaderc install-models build-llama
make status                                     # every claimed component into $QWEN_HOME/manifest.tsv
make doctor                                     # legacy, foreign, and transient paths, untouched
make verify-layout                              # marker, schema, binding, layout, and the path ratchet
make verify-components                          # sudo policy and every installed component identity
make verify-live                                # transient system state, passing where a node is absent
make verify                                     # the union of the three
make verify-models                              # every registry model file and projector against
                                                # the byte count and SHA-256 its fetch rule pins,
                                                # fetching nothing
QWEN_PURGE_LEGACY_CONFIRM=yes make purge-legacy # the enumerated predecessor paths, nothing else
remote/check-deletion-plan.sh plan uninstall|purge
                                                # the complete selection, one row per object, with
                                                # the plan digest an authorization names
remote/check-deletion-plan.sh fingerprint DIR   # the metadata fingerprint a decision records
remote/check-deletion-plan.sh payload-manifest DIR
                                                # the content digest a disposal requires
QWEN_RUNTIME_ROOT_CONFIRM=$PWD/.runtime make uninstall
                                                # the root minus state/ and models/; the confirm is
                                                # required where the marker binds the root to a
                                                # production checkout, and the preflight refuses the
                                                # whole plan where one selected object is unproven
QWEN_RUNTIME_ROOT_CONFIRM=$PWD/.runtime \
QWEN_DELETION_JOURNAL=/an/absolute/path/outside/the/root.tsv make purge
                                                # purge removes state/ too, so the journal it records
                                                # itself to is named outside the root

# Start and stop the appliance, from the appliance's own checkout. Every script
# here resolves its siblings and the runtime root through qwen-home.sh, which
# takes qwen_tree_root as the parent of its own directory, so a working copy
# reads correctly whatever it is named and wherever it sits.
remote/qwen-launch.sh [paced-60|low-serialized|low-async]
remote/qwen-web-launch.sh [PROFILE]   # web presets, loopback by default
remote/qwen-image-launch.sh [PROFILE] # web presets with the image lane armed

# The web lane on the operator's own network, bearer required on every route.
# The key exists before the listener does, so it is minted once and read out of
# the state directory ahead of the launch rather than after the socket is up.
# QWEN_BIND_HOST left unset binds the one QWEN_WEB_LAN_ADDRESS literal rather
# than every interface; QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 is the separate,
# loudly-printed opt-in that widens it to 0.0.0.0.
openssl rand -hex 32 >$QWEN_HOME/state/api.key
chmod 600 $QWEN_HOME/state/api.key
QWEN_WEB_LAN=1 QWEN_WEB_LAN_ADDRESS=192.168.1.10 \
QWEN_WEB_AUTHORIZER_READY=1 \
QWEN_WEB_TOKEN_KEY_FILE=$HOME/qwen-web-token.key \
    remote/qwen-web-launch.sh low-async
# The session's `lan_exposure` line in $QWEN_HOME/state/session.status names
# the page URL, which carries ?broker= and ?artifacts= because the page's meta
# tags name the loopback. The `lan_interface` line beside it names the
# interface index, name, MAC, prefix length, and NetworkManager connection
# UUID and name that literal resolved to through `ip -j addr` and
# `nmcli -t -f UUID,NAME,DEVICE connection show --active`; a git copy of that
# line sanitizes the MAC to `<mac>` the way every other retained evidence file
# does.
# One router serving the whole roster on the LAN: the registry sections stay
# tool-free and the web section carries the search tools, so the ordinary
# launcher arms the broker and the search instance from the preset itself.
# QWEN_SERVER_PORT picks the router port; under the exposure the broker
# binds one above it and the artifact listener one above that, so a page
# loaded over the LAN derives both companions from its own address and the
# bare router URL is the whole thing a browser needs.
QWEN_SERVER_PORT=42069 \
QWEN_WEB_LAN=1 QWEN_WEB_LAN_ADDRESS=192.168.1.10 \
QWEN_ROUTER=1 QWEN_WEB_AUTHORIZER_READY=1 \
QWEN_WEB_TOKEN_KEY_FILE=$HOME/qwen-web-token.key \
    remote/qwen-launch.sh low-async
# The household open mode at one permanent address with no key step.
# QWEN_WEB_LAN_OPEN=1 removes the Web UI bearer from the router, the broker,
# and the artifact listener: every reachable peer can chat, consume model
# time, and fetch a known artifact URL with no credential, and the approval
# dialog and its single-use grant remain the whole gate on search and image
# execution. The exposed interface's own NetworkManager connection must
# appear in QWEN_WEB_LAN_TRUSTED_CONNECTIONS -- a colon-separated list of
# connection UUIDs from `nmcli -t -f UUID,NAME connection show --active` --
# or the open opt-in refuses and says so; an authenticated launch on an
# undeclared connection still proceeds, since the bearer stands behind it.
QWEN_SERVER_PORT=42069 \
QWEN_WEB_LAN=1 QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_OPEN=1 \
QWEN_WEB_LAN_TRUSTED_CONNECTIONS=$(nmcli -t -f UUID,DEVICE connection show --active | \
    awk -F: '$2 == "eth0" { print $1 }') \
QWEN_ROUTER=1 QWEN_WEB_AUTHORIZER_READY=1 \
QWEN_WEB_TOKEN_KEY_FILE=$HOME/qwen-web-token.key \
    remote/qwen-launch.sh low-async

# The LAN bring-up states that whole environment once, under one of two named
# security profiles: lan-authenticated (the default, bearer required on every
# route, a one-command fallback) and lan-open-approved (the explicit household
# opt-in above). It reads the address from the default route, mints the
# broker signing key on the first run, tears down a running session first,
# reads the image parameters path from the active deployment's own image
# server, resolves the exposed interface and requires its NetworkManager
# connection in QWEN_WEB_LAN_TRUSTED_CONNECTIONS under lan-open-approved, and
# prints the active boundary in capitals before the name to open. The same
# line appears first in `qwen-webui-control.sh status`, which echoes the
# session's own recorded `state=running` line.
remote/qwen-lan-launch.sh lan-authenticated [low-async]
QWEN_WEB_LAN_TRUSTED_CONNECTIONS=$(nmcli -t -f UUID,DEVICE connection show --active | \
    awk -F: '$2 == "eth0" { print $1 }') \
    remote/qwen-lan-launch.sh lan-open-approved [low-async]
# QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 binds every interface instead of the one
# selected address; the launch prints that decision loudly rather than
# folding it into the ordinary exposure line.
remote/qwen-teardown.sh
remote/qwen-webui-control.sh status

# A named window in which the appliance stands torn down for a maintenance
# command, bounded by an advisory lock that admits one window at a time and
# an EXIT trap that relaunches the session on every path out of the window --
# normal exit, a failing command, INT, and TERM alike. The relaunch profile
# comes from the running session's own status line rather than from an
# argument; a lan-open-approved boundary downgrades to lan-authenticated
# where QWEN_WEB_LAN_TRUSTED_CONNECTIONS is absent from the window's own
# environment, and the downgrade is recorded rather than silent.
remote/run-device-window.sh NAME COMMAND [ARG...]
remote/run-device-window.sh status

# What the launch chain took rather than what it was permitted. The session
# opens one CLOCK_MONOTONIC record per launch under
# $QWEN_HOME/state/stage-timing/, points stage-timing.tsv at it, and names that
# path on the state=running line; the launcher and the teardown append their
# own rows to the named record.
remote/summarize-stage-timing.py stages $QWEN_HOME/state/stage-timing.tsv
remote/measure-model-switch.sh OUTPUT_DIRECTORY [SWITCH_COUNT]
remote/summarize-stage-timing.py switches OUTPUT_DIRECTORY/model-switch.tsv

# Select a checkpoint, a listener, and the inference core
QWEN_MODEL_PATH=$HOME/models/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf \
QWEN_BIND_HOST=0.0.0.0 QWEN_INFERENCE_CPU=1 \
    remote/qwen-launch.sh

# Measurement harnesses, each of which owns its own launch and teardown
remote/compare-model-candidate.sh LABEL MODEL_PATH [PROFILE]
remote/run-placement-sweep.sh [OUTPUT]
remote/reasoning-span-probe.sh OUTPUT_JSON     # against a live server
remote/summarize-probe.sh $QWEN_HOME/state/graphics-latency.log
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
QWEN_WEB_API_KEY_FILE=$QWEN_HOME/state/api.key \
    remote/run-conversational-suite.sh [OUTPUT_DIR] [MODEL_ID...]
                                                # the suite web-off through the API and
                                                # web-on through the served page, per
                                                # servable checkpoint a web section
                                                # reaches; evidence/conversational-suite/
remote/generate-quality-images.py [DIR]        # the vision fixtures, and --check
remote/regrade-quality-roster.py RECORD...     # a grader change over retained replies
remote/sample-gpu-clocks.sh OUT_TSV [SECONDS]  # the DPM step a rate ran at
remote/measure-dpm-force.sh MODEL [OUT]         # auto against global high governor
remote/compute-state-lease.sh PROFILE COMMAND [ARG...]
                                                # one reversible compute-state
                                                # transaction: the shared Vulkan
                                                # lease and its published proof,
                                                # a snapshot of the DPM level
                                                # with its two selections and
                                                # the KSM run state, one named
                                                # profile, a delivered clock
                                                # proven before the command, and
                                                # a verified restore after it.
                                                # measure-fixed pins GFXCLK 1100
                                                # with FCLK 933 at nice 19;
                                                # serve-performance-candidate
                                                # admits FCLK 933 or 1067 at
                                                # nice 0. Exit 3 names an
                                                # unreached clock and 4 a
                                                # restoration incident, which
                                                # dominates the command's own
                                                # status.
remote/compute-state-lease.sh status           # the live values, no credential, no write
                                                # measure-fixed-package-default,
                                                # -20w, and -25w add the power
                                                # term to that same state.
remote/power-envelope.sh apply PROFILE          # the SMU package budget, one
                                                # reversible term: ryzenadj
                                                # --info is the snapshot, a
                                                # profile writes the fields it
                                                # names in milliwatts, the
                                                # read-back is the proof, and
                                                # THM LIMIT CORE bounds the term
                                                # rather than being written.
                                                # platform-default writes
                                                # nothing and still snapshots.
                                                # A failure part way through a
                                                # profile rolls the limits it
                                                # already wrote back from the
                                                # snapshot, so exit 3 names an
                                                # arm refused with the baseline
                                                # returned and 4 a budget the
                                                # platform would not return.
                                                # The snapshot path is the
                                                # claim: it is created under
                                                # set -C, so one concurrent
                                                # apply wins, and restore acts
                                                # on the owner token that claim
                                                # recorded alone.
remote/power-envelope.sh restore | status       # the reversal, and the live
                                                # limits with no write
remote/build-ryzenadj.sh [SOURCE_DIRECTORY]    # the pinned RyzenAdj into
                                                # ~/.local/bin; needs cmake and
                                                # libpci-dev and no privilege
remote/model-registry.sh id|path SELECTOR [FIELD]
remote/model-registry.sh draft-pairs | draft-pair PAIR_ID [FIELD]
remote/model-registry.sh ctx-checkpoints | ctx-checkpoint MODEL_ID
remote/measure-draft-pair.sh PAIR_ID OUTPUT_DIR
                                                # snapshot-bound ABBA pairing
remote/build-router-presets.sh [OUTPUT_INI]    # the picker, from the tier field
# The roster plus its web section. The shipped image ledger carries one
# validator-gated row, so a generation arming the web lane alone names an
# all-refused image ledger the way remote/test-web-presets.sh does.
QWEN_WEB_AUTHORIZER_READY=1 QWEN_WEB_MCP_SERVER=remote/web-mcp/server.py \
QWEN_WEB_TOKEN_KEY_FILE=$HOME/qwen-web-token.key \
QWEN_IMAGE_PROFILES=remote/test-fixtures/image-profiles-refused.tsv \
    remote/build-router-presets.sh OUT.ini
# The roster plus its web section plus the image server that section carries.
QWEN_WEB_AUTHORIZER_READY=1 QWEN_WEB_MCP_SERVER=remote/web-mcp/server.py \
QWEN_WEB_TOKEN_KEY_FILE=$HOME/qwen-web-token.key \
QWEN_IMAGE_MCP_SERVER=remote/image-mcp/server.py \
QWEN_IMAGE_TOKEN_KEY_FILE=$HOME/qwen-web-token.key \
QWEN_IMAGE_STATE_DIR=$HOME/qwen-webui-state/images \
QWEN_IMAGE_SERVICE_SOCKET=$HOME/qwen-webui-state/images/image-service.sock \
QWEN_IMAGE_PROFILES_JSON=$QWEN_HOME/state/image-parameters.json \
    remote/build-router-presets.sh OUT.ini
remote/build-web-presets.sh OUTPUT_INI         # web profiles, from the execution_policy field
remote/build-feature-roster.sh [OUTPUT_JSON]   # webui/roster.json, from the feature claim ledger
remote/fetch-candidate-artifact.sh REPO REV FILE DIR  # observed, not pinned
remote/run-one-token-admission.sh RECORD [OUT]  # load every candidate once
remote/run-representation-arm.sh LABEL CONTROL SUBJECT
                                                # one value format against another, ABBA
remote/admit-web-router-fake.sh OUTPUT_DIR      # the web router against the fake provider
remote/admit-web-router-live.sh OUTPUT_DIR [PROFILE_ID]
                                                # the web router against the live SearXNG instance
remote/searxng-launch.sh serve|start|stop|status [STATE_DIRECTORY]
                                                # one instance as the serving user, loopback only
remote/admit-image-router.sh OUTPUT_DIR         # one approved generation through the router
remote/probe-depth-projector.sh [--runtime-mode standalone|router-child] MODEL_ID OUT
                                                # filled depth, projector loaded
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
remote/build-llama-e5.sh SOURCE [PREFIX_ROOT]   # the census-instrumented int24
                                                # binary under the pinned shaderc
remote/run-e5-module-proof.sh OUT SERVER MODEL RADV_PREFIX
                                                # the executed OpSDotKHR module
                                                # and the isolated driver, before
                                                # any rate
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
# arms did. The boundary between two arms is a campaign condition rather
# than a counter: await-quiescence.sh reports reached only where its
# process, occupancy, graphics step, step stability, absolute temperature,
# thermal derivative, memory, swap-in, lease, and latency predicates held
# together across the hold window, so any other verdict ends the campaign
# quiescence_unconverged with exit 5 before the next arm starts. The last
# arm a campaign executes polls no boundary, since the arm one would
# prepare never runs. On a verdict that ends the run, arms.tsv
# carries a boundary row whose status names the state, terminal-state.tsv
# names the slot, the arm, and the failing predicates, and no summary,
# brick receipt, or calibration root is written over the truncated ledger.
# --sclk-forced drops the step's position in the listed ladder alone.
# Runtime identity is bound at preflight and re-established by every arm:
# arms/LABEL/runtime-identity.tsv carries the bound value beside the arm's
# own reading of the model bytes and digest, the server bytes and digest,
# the runtime tree's git head and both payload digests, one
# check-runtime-tree.sh recompute over that tree, the artifact ledger
# digest, the served runner digest, and the request digest the campaign
# binds from the first body an arm sent. A field that moved ends the
# campaign identity_incident with exit 6 naming that field, since every
# later arm would measure a different experiment under one receipt.
# QWEN_CENSUS_REUSE_BRICKS revalidates a retained brick in the epoch that
# reuses it: the prior calibration root's own digest is recomputed from its
# rows, each receipt is rehashed against the digest that root records, every
# artifact row is rehashed against the bytes it names, and the current
# readers that read a raw record are rerun over those bytes and must
# accept, with paths resolved through the receipt's own reused_from chain
# so a second generation reads the records the original arms wrote. A brick whose receipt
# names no artifact, or whose arms retained no record a reader reads, is
# measured again rather than copied forward on a historical completed
# label, and the copied receipt states revalidation, revalidated_epoch,
# revalidated_readers, and revalidated_artifacts.
# QWEN_CENSUS_MODE=calibration, the default, runs exactly the
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

# Rung 7 of the E4 ladder: two serving builds on one checkpoint, mirrored
# C K K C quadruples under the production receipt binding, promoted on a
# one-sided 5% paired bound.
# evidence/raven2-vulkan-kernel-census/e4/served-ab-design.md registers the
# falsifiers and the chain.
QWEN_CENSUS_PRODUCTION_RECEIPT=RECEIPT remote/run-served-binary-ab.sh \
    CONTROL_SERVER CANDIDATE_SERVER MODEL_ID OUT

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
remote/verify-bundle-preset-ledger.sh PRESET LEDGER [REGISTRY] [Q4K_POLICY]

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
remote/test-stage-timing.sh
remote/test-measure-model-switch.sh
python3 remote/test-summarize-stage-timing.py
remote/test-radv-low-priority-env.sh
remote/test-model-registry.sh
remote/test-verify-models.sh
remote/test-model-tiers.sh
remote/test-feature-roster.sh
node remote/test-fallback-webui-roster.mjs
python3 remote/test-summarize-draft-pair.py
remote/test-measure-draft-pair.sh
remote/test-probe-depth-projector.sh
remote/test-web-presets.sh
remote/test-unified-router-presets.sh
remote/test-unified-router-launch.sh
node remote/test-fallback-webui-mixed-roster.mjs
node remote/test-fallback-webui-lan-bounds.mjs
remote/test-qwen-web-launch.sh
remote/test-run-device-window.sh
remote/test-web-search-live.sh
remote/test-image-registry.sh
remote/test-qwen-image-launch.sh
remote/test-run-image-standalone.sh
remote/test-admit-image-router.sh
remote/test-vulkan-workload-lease.sh
remote/test-fallback-webui-image-authorization.sh
node remote/test-fallback-webui-model-state.mjs
node remote/test-fallback-webui-conversations.mjs
node remote/test-fallback-webui-ui-switch.mjs
python3 remote/test-image-protocol.py
python3 remote/test-image-service.py
python3 remote/image-mcp/test-image-mcp.py
python3 remote/test-image-review.py
python3 remote/web-mcp/test-fallback-page-image.py
remote/test-quality-suite.py
remote/test-quality-roster.sh
python3 remote/test-conversational-suite-units.py
remote/test-run-conversational-suite.sh
remote/test-promote-llama-build.sh
remote/test-classify-checkpoint-semantics.sh
remote/test-prefix-checkpoint-key.sh
remote/test-run-served-binary-ab.sh
remote/test-check-runtime-tree.sh
remote/test-write-clangd-config.sh
remote/test-deployment-bundle.sh
remote/generate-quality-images.py --check
remote/test-gguf-tokenizer-identity.py
remote/test-admit-candidate-static.py
remote/test-one-token-admission.sh
remote/test-fetch-candidate-artifact.sh
remote/test-build-llama-e5.sh
remote/test-run-e5-module-proof.sh
remote/test-run-graph-alias-ab.sh
remote/test-run-ctx-checkpoint-sweep.sh
python3 remote/test-summarize-kernel-census.py
python3 remote/test-census-controls.py
python3 remote/test-sample-clock-sidecar.py
python3 remote/test-summarize-perf-logger-slice.py
remote/test-census-sha256.sh
remote/test-q8-mat-vec-receipt.sh
remote/test-compute-state-lease.sh
remote/test-power-envelope.sh
remote/test-run-raven2-vulkan-kernel-census.sh
remote/verify-llama-patch-series.sh
QWEN_LLAMA_CANDIDATE_PATCHES=1 remote/verify-llama-patch-series.sh
GGUF_PY_PATH=$QWEN_HOME/opt/llama.cpp/gguf-py \
    remote/test-gguf-tensor-census.py [MODEL...]
```

