# Epoch main-e909cfc-r1: the first epoch served from the runtime root

This directory retains the first deployment epoch the appliance served from
the checkout-local runtime root, the migration that put it there, and the
verification a LAN peer measured against it. `receipt.tsv` is the receipt
`remote/write-deployment-receipt.sh` wrote on the appliance after the
post-purge relaunch, sanitized the way every retained record is; the
`verify-lan-site-*.tsv` files are the `results.tsv` of each
`remote/verify-lan-site.sh` run from the workstation against the mDNS name,
in the order they ran.

## What the receipt binds

| field | value |
| --- | --- |
| `main_commit` | `e909cfc9f0c50eb19969469d047bbd363439ea36` |
| `server_digest` | `5dd86b90154f6143a5303efd2590b9268a0a5e3e908c4d6791f1fde03a4782c2`, the promoted natural-boundary server every bundle since `main-f50d631-r1` carries |
| `bundle_digest` | `e472abc53b7fd671133554035844fda9de6d524a3abc25a47832aed891b245a4` |
| `router_preset_digest` | `7500aac9f80b038619b720fbd1e0af4f294c1cf89cecc2ea50c4c4e10616504a`, generated against the root |
| `qwen_home` | `$HOME/Github/qwen-apu/.runtime` |
| `runtime_manifest_sha256` | `46a185b147fe2b286bb721c08740f1d1f1544cf88553f00906160ede4da7ef2f` |
| `searxng_source_commit` | `a30b2d47492ab46ae82ce25ee62a31626565cf67` |
| `searxng_venv_identity` | `118541c556ae88c920e778bd5b08877a9f50720b1c7a5ef762ff651c7d33dc7e`, equal to the digest of `toolchains/searxng/requirements.lock` |
| `ryzenadj_digest` | `a5127380499a6bdbad5134fdab6801957b03b963a72aa9f6b8e16a0d67250803`, rebuilt into `bin/` from the moved source at 5775fc3e |
| `image_runtime_digest` | `4eb6d155c8b1e077de5613a7282410d78c2fc984e9c3aedf9287c0aa788817c8` |
| `shaderc_digest` | `absent`, since no shaderc has been installed under the root and the promoted server predates the target |
| `sudo_policy_digest` | `12ca4063486c8c3207daf6ba40cedec0790cc39c525e0ff1b81358b927820333`, the one persistent root-owned object |
| `legacy_paths_present` | `no` |
| `foreign_owned_paths` | `0` |

The three bundles cut on 2026-09-04 (`main-a9d1789-r1`, `main-a65173b-r1`,
`main-e909cfc-r1`) hold the same server bytes and the same preset bytes; each
was cut because the synced runtime tree moved under it and a receipt names
the tree it was written over. `main-f50d631-r1`, the bundle the appliance
served from `~/qwen-laptop-setup` before the migration, stays under
`deployments/` as the rollback target and was never receipted, since its
presets name `$HOME/models` and `$HOME/qwen-webui-state`.

## The migration, in the order it ran

1. Pre-migration record: the active bundle, its server digest, every model
   file with its byte count, the key modes, the legacy SearXNG commit and
   settings digest, and the account sweep (`pgrep -u searxng` empty,
   `find / -xdev -user searxng` naming only `/etc/searxng/settings.yml`,
   `/usr/local/searxng`, and the `/tmp/sxng_cache_*` files, no unit, no
   crontab).
2. `qwen-teardown.sh` from the old tree; `~/qwen-webui-state`,
   `~/qwen-deployments`, and `~/qwen-web-token.key` renamed under the root,
   which shares one filesystem with the home directory.
3. `~/models` renamed to `models/`; each served artifact rehashed by its own
   download script (`artifact_status=already_verified` is printed only after
   `sha256sum` matches the pinned digest).
4. `~/src/RyzenAdj`, `~/src/stable-diffusion.cpp-qwen-apu`,
   `~/src/llama.cpp-qwen-apu`, and `~/src/llama.cpp` renamed under `opt/`;
   `make install-ryzenadj` rebuilt the binary into `bin/`.
5. The three home-level results directories moved under `results/legacy/`
   rather than deleted.
6. A preset regenerated against the root, a bundle cut from the promoted
   server, activation, and a launch through `qwen-lan-launch.sh
   lan-authenticated`.
7. `make purge-legacy` in three passes as the script was repaired
   (`purge-legacy-privileged-residue`, `purge-legacy-cache-sidecars`), then
   `make doctor` reading `legacy_paths_present=no legacy_paths=0
   foreign_owned_paths=0` and `id searxng` reporting no such user.
8. The post-purge relaunch on the current head, the receipt, and the final
   verification below.

## What the verification measured

Every run named the router, broker, and artifact origins through the page
URL's own `?broker=` and `?artifacts=` parameters, as the launch prints it.

| run | page, health, roster, props, broker, artifacts | web search | image generation | conversation restoration | tool-prefix checkpoint |
| --- | --- | --- | --- | --- | --- |
| `a9d1789`, default model | pass | pass, one grant | fail, `crypto.subtle` undefined | pass | fail on `lfm25-vl-16b`, 114 -> 114 |
| `a9d1789-r2`, `qwen38-2b-distill` | pass | pass, one grant | fail, the same | pass | request timed out at 700 s |
| `a65173b`, `qwen38-2b-distill`, page fix served | pass | pass, one grant | pass, one artifact, 512x512, 4 steps | pass | ended by the operator after the same router wait |
| `e909cfc`, `qwen38-2b-distill`, post-purge relaunch | pass | pass, one grant | pass, one artifact, 512x512, 1 step | pass | both requests timed out at 700 s in the same router wait; the harness exits on the second and writes no row |

The final run is the one the receipt binds: nine rows pass from the LAN
against the post-purge relaunch, and the checkpoint row is the by-hand
replay recorded below, since the harness's own request met the router wait
on both attempts.

Two of those failures were the appliance's and are repaired in this tree;
one is a defect in the pinned server that this migration exposed rather than
caused.

**`crypto.subtle` is a secure-context interface.** The page hashed the
approved prompt with `crypto.subtle.digest`, which a browser defines on
`https` and on `localhost` and leaves undefined on the plain-HTTP LAN origin
`qwen-lan-launch.sh` serves, so every approved image generation on the LAN
page ended in `Cannot read properties of undefined (reading 'digest')`
before a grant request left the browser; the retained `8-image-turn.json` of
the first run holds two requests, the tool listing and the chat completion,
and none to the broker or the image service. PR #170 computes SHA-256 in
script where the interface is absent, `test-fallback-webui-sha256.mjs` holds
both paths to node's digest, and the `a65173b` run generated one artifact
through the served page. The earlier admissions ran the page in headless
Chromium on the loopback, a secure context, which is why the defect was
first seen on the LAN.

**The verifier's default checkpoint subject is the wrong architecture.**
`verify-lan-site.sh` names the roster's first id where `QWEN_VERIFY_MODEL`
is unset, and the roster orders `lfm25-vl-16b` first; the claim
`evidence/tool-prefix-checkpoint/` states is about the hybrid Qwen3.5 slot,
and the LFM2 row charged 114 tokens on both requests. Against
`qwen38-2b-distill` the same two request bodies, replayed with curl once
the child was loaded, charged 306 then 18, and a second replay pair charged
18 and 18. The row is a property of the subject, and the runs after the
first name the 2B.

**A cancelled request during a child load leaves the router waiting.** In
both the `a9d1789-r2` and `a65173b` runs the page's conversation-restoration
turn loaded `lfm25-vl-16b` as its default selection, the page cancelled that
request 0.4 to 0.5 s into the load (`request cancelled while waiting for
model name=lfm25-vl-16b`), the child then finished loading in 3.2 s, and the
verifier's next request, a chat completion naming `qwen38-2b-distill`, sat
with no `spawning server instance` line for the whole 700 s curl timeout
before the router logged it cancelled. A fresh request sent afterward
spawned the 2B within 13 s and answered, on both occasions, so the wait is
bound to a request that arrives while a cancelled load is still in flight
rather than to the model or the device. The pinned `server-models.cpp` at
f280b269 is the component; a reproduction through two curl requests, one
aborted during a load and one naming a second model, is the falsifier an
upstream report needs, and the LAN page meets exactly that sequence whenever
a peer switches models before the first load completes.

## What the migration left outside the root

- `build/vulkan-graphics-service-probe` and `build/telemetry-broker` are
  built beside the tree by their own scripts and read there by
  `qwen-webui-session.sh`; the first launch from the checkout failed
  `graphics_latency_probe_unavailable` until both were rebuilt.
- `state/image-parameters.json` is admission output carrying absolute paths
  to the runtime and the model directory; the copy the launch read was
  rewritten to root paths with the original retained beside it as
  `.pre-migration`, since `admit-image-router.sh` writes it by running a
  generation.
- Campaign output directories directly under the home directory
  (`~/image-admission-*`, `~/fixed64-scoreboard-*`, `~/bundle-router-regression-*`,
  `~/evidence`, `~/e1-lab-*`, `~/gpu-decomp`, and their logs) are outside
  the doctor's enumeration and untouched.
- The runtime manifest reads `llama-server` absent at
  `opt/llama.cpp/build-appliance-current/bin/llama-server` and `shaderc`
  absent; the served server is the bundle's own copy.
