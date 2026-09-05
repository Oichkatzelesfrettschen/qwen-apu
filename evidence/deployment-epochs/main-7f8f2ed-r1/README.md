# Epoch main-7f8f2ed-r1: the qualified baseline

The bundle carries the router cancelled-load repair and is the first epoch
qualified on all three availability predicates in one window: the
cancelled-load sequence recovers on the appliance, the LAN verification
passes in every row, and rollback to a root-compatible bundle launches and
returns. `receipt.tsv` is what the appliance claimed to be running,
`verify-lan-site-7f8f2ed.tsv` is what a peer on the network received from
it, `confirm-router-cancelled-load.tsv` is the recovery, and
`rollback-proof.log` is the transition both ways. The tag
`deploy/main-7f8f2ed-r1` names the main commit the receipt binds.

## The receipt

| field | value |
| --- | --- |
| `main_commit` | `7f8f2ed99ca0515ab9f49dd48377180203d51f1b`, the merge of the router repair |
| `server_digest` | `70aa78bc0eed708ce8d06b690467affce3bb222014714af4dbd92e00fa5ff010`, built on the appliance from the runtime root's tree with `QWEN_LLAMA_CANDIDATE_SELECT=llama-router-cancelled-load-idle.patch`, `checkpoint_semantics=natural-boundary-v1`, `serving_eligible=yes` |
| `bundle_digest` | `921e93d0e0a758d2f83470ebf192f28ef652ed02aaabb817e8f29956accbec45` |
| `tool_prefix_identity` | `llama-router-cancelled-load-idle.patch:40f8aa4f...`, the candidate series the build carried; the field names any candidate series and this one is the router repair rather than the prefix-checkpoint patch its name was coined for |
| `open_lan_policy_identity` | `lan_exposure=1 lan_name=qwen-laptop.local lan_open=0 lan_boundary=lan-authenticated profile=low-async` |
| `receipt_sha256` | `609e4d49a3ec79febf6cde00fafe9d16f4fed26cc1816d5bd23c1e895ba34d2d` |

The build ran on the appliance's own two cores from a clean configure, since
the build directory the migration moved still carried a CMake cache naming
the predecessor source path and was set aside as
`build-raven2-vulkan-production.pre-root-<utc>`; the presets were regenerated
against the root and the bundle was cut, verified, and activated over
`main-e909cfc-r1`, which became `deployment-previous`.

## Router recovery on the appliance

`remote/confirm-router-cancelled-load.sh` ran from the workstation against
the LAN name with the Web UI bearer: a request for `lfm25-vl-16b` was
cancelled 591 ms after it was sent, at the moment the router reported that
child `loading`; a request for `qwen38-2b-distill` sent at once answered
with HTTP 200 in 7.9 s, served by the 2B; the vision child had given up its
slot and read `unloaded` while the 2B read `loaded`. Two requests were sent
and nothing else: no third request, no router restart, no device reset, no
model-stack change, shaders unchanged. `evidence/router-cancelled-load/`
holds the deterministic workstation reproduction the repair was built
against; this run is the arm that moves
`patches/llama-router-cancelled-load-idle.patch` into the production stage of
`remote/llama-patch-series.tsv`, with `tools/server/server-models.cpp` and
`tools/server/server-models.h` pinned in `remote/llama-patched-sources.tsv`
at the digests the replay reaches.

## The LAN matrix, every row

| row | result |
| --- | --- |
| page, health, roster (16 ids), props | pass |
| broker and artifact listener health on the LAN name | pass |
| web search through the served page | pass, one grant |
| image generation through the served page | pass, one 512x512 artifact at 1 step |
| conversation restoration across a reload | pass |
| tool-prefix checkpoint, subject `qwen35-08b` by the roster's first Qwen3.5-architecture id, cold by nonce | pass, 334 tokens then 18 |
| relaunch | skip, operator-only |

Every row is present, which is the repair `remote/verify-lan-site.sh` took
in the same merge: an explicit or architecture-selected subject, a per-run
nonce so the first request is a cold prefix, and a terminal row for every
check a run ends ahead of.

## Rollback

`remote/activate-deployment-bundle.sh rollback` moved `deployment-current` to
`main-e909cfc-r1` with `main-7f8f2ed-r1` as previous, the launch resolved
that bundle and reached `state=running` on the lan-authenticated boundary,
and the reverse activation returned `main-7f8f2ed-r1` to service the same
way; the live site then answered `/health` ok with the 16-row roster.
`main-e909cfc-r1` is therefore the standing recovery target. `main-f50d631-r1`
stays historical evidence: its presets name predecessor paths the migration
removed, and it is not a recovery target.

## What this qualifies and leaves

This epoch is the qualified baseline for availability: recovery, the whole
matrix, and rollback on one bundle. It states nothing about throughput; the
registered 2B composition, the 4B and 0.8B attributions, and E5 read
`docs/frontier.md` for their own conditions. The verifier's health probe in
`rollback-proof.log` reads `000` because it addressed loopback where the
lan-authenticated router binds the LAN literal alone, so the launch exit
status and each launch log's `state=running` line are the rollback evidence
and the loopback probe is a defect of the proof script rather than of the
appliance.
