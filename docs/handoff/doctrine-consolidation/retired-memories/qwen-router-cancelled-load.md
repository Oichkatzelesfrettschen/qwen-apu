---
name: qwen-router-cancelled-load
description: "The router slot hand-off defect (cancelled request during a child load) is repaired by llama-router-cancelled-load-idle.patch, confirmed on the appliance 2026-09-04, promoted to the ninth production member; epoch main-7f8f2ed-r1 serves it"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-05T06:14:40.657Z
---

At llama.cpp f280b269 `server_lru_sched::on_model_idle` was the only path
giving a `--models-max` slot to a queued request and `proxy_request`'s
cleanup its only caller, so a child loaded by a request cancelled before
proxying held its slot until the queued request's own timeout.
`patches/llama-router-cancelled-load-idle.patch` counts waiters per model
and hands the slot on where a child comes up with nobody waiting; it is the
ninth `production` member of `remote/llama-patch-series.tsv` (series digest
now a91a215a..., nine members) with server-models.cpp/.h pinned in
`remote/llama-patched-sources.tsv`. Evidence: `evidence/router-cancelled-load/`
(deterministic workstation fixture `remote/test-router-cancelled-load.sh`,
LD_PRELOAD bind barrier, stories260K fixture from
`remote/fetch-test-model-stories260k.sh`) and
`evidence/deployment-epochs/main-7f8f2ed-r1/` (appliance confirmation via
`remote/confirm-router-cancelled-load.sh`: cancel at 591 ms, follow-up in
7.9 s). Workstation CPU build for the fixture:
`~/src/llama.cpp-router-fix/build-cpu/bin/llama-server` (worktree of
`~/src/llama.cpp`, detached at f280b269, eight production patches plus the
router patch applied unstaged).

**Why:** the LAN page hits this whenever a peer switches models before the
first load completes, and the verifier's checkpoint row timed out on it twice.

**How to apply:** a bundle cut from the runtime root's tree now carries it by
default (the tree at `.runtime/opt/llama.cpp` on the laptop has the patch
applied). The 2B target-closure control is the nine-member production build
`70aa78bc` (same bytes as `main-7f8f2ed-r1`), since the served A/B binds
both binaries to one series digest; see [[qwen-2b-target-closure-result]]. The
verifier defaults its checkpoint subject to the roster's first `qwen3[58]-*`
id and stamps a nonce so the first request is cold.
