---
name: qwen-4b-row-scoped-release
description: "Row-scoped 4B release LANDED 2026-09-06: qwen38-4b-distill serves e4-scale-licm/4 under epoch main-2c1fa9de-r1; the bundled q4k-policy.tsv is what lets the keyless rollback main-7f8f2ed-r1 keep verifying"
metadata:
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-06T23:48:58.309Z
---

Landed 2026-09-06. `main` is 2c1fa9de (PR #194 the bundled formulation policy,
PR #197 the registry flip). The serving epoch is `main-2c1fa9de-r1`, server
`92015c149b3f4ffe` from `.runtime/opt/llama.cpp-q4k-release/build-raven2-vulkan-production`,
with `main-7f8f2ed-r1` (server 70aa78bc) retained as `deployment-previous` and
re-verified after the flip.

Mechanism: `patches/llama-vulkan-q4k-row-select.patch` (variant 3 = pinned
production module, unkeyed default; `--vk-q4k-variant` /
`LLAMA_ARG_VK_Q4K_VARIANT` per preset section), `remote/models.tsv` column 23
`q4k_variant`, and the policy/exec-guards/bundle-verifier chain binding the key
to the row and to the build manifest's `q4k_variants`.

The release also required a repair, because `verify-bundle-preset-ledger.sh`
read the formulation off the reader's own registry: a keyless preset then
refuses against a registry that has since released one AND a keyed preset
refuses against the registry it predates, so no activation order existed where
release and rollback both verify. `build-deployment-bundle.sh` now projects
model_id + q4k_variant into a bundle member `q4k-policy.tsv`. Three manifest
shapes are three claims: no row = `legacy` (records nothing; admits a keyless
preset, refuses a keyed one naming the recovery), one row `-` = declares
nothing released, one digest row = the member binds. Authority follows the
preset, not the server: `qwen-launch.sh` and `qwen-web-launch.sh` bind from the
bundle whose preset they selected and state `registry` otherwise;
`qwen-webui-control.sh` defaults to `registry`.

**Why:** the appliance's twelve deployments all carry zero policy rows and zero
section keys, so `legacy` preserves every real rollback target and the
migration message covers a keyed pre-member bundle that does not yet exist.

**How to apply:** the served proof is `.runtime/state/server.log`, where the
backend prints `q4k_variant=e4-scale-licm/4 q4k_rows=4` for the 4B-family
children and the 2B and 0.8B children print no such line at all. 16 sections,
exactly 3 keyed (`qwen38-4b-distill`, its draft pair, `web-open` -- all three
resolve to the 4B model file). Receipt at
`.runtime/results/release-main-2c1fa9de-r1/deployment-receipt.tsv`
(`q4k_selection_identity`, sha256 6a2da8bf). The window scripts are
`$S/release-phase-a.sh` (verify + build + verify, no teardown) and
`$S/release-phase-b.sh` (teardown, activate, relaunch, auto-rollback on a
failed launch). Probe the router at the LAN literal, never loopback, and read a
child's formulation from the server log rather than `/proc/PID/environ` -- the
per-section keys reach the child through preset merge, so `LLAMA_ARG_CTX_SIZE`
is absent from the child environ too.
See [[qwen-4b-null-attribution]] and [[qwen-runtime-root-doctrine]].
