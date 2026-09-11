---
name: qwen-lan-bringup-and-merge-program
description: "The LAN appliance bring-up is remote/qwen-lan-launch.sh (open by default, no key); gh and the GitHub key work natively on the laptop; the 2026-09-03 merge program order and helper scripts"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-03T19:02:24.590Z
---

The LAN bring-up is `remote/qwen-lan-launch.sh` on the `unified-router-image`
branch (PR #120, commits edb3357 and ff59f10): it derives the address from
the default route, mints `~/qwen-web-token.key` once, reads the image
parameters path from the active bundle's image MCP configuration through
`read-image-mcp-server.py`, tears down a running session first, and prints
`http://qwen-laptop.local:42069/`. `QWEN_WEB_LAN_OPEN=0` keeps the bearer.
`qwen-teardown.sh` ends it. Verified 2026-09-03 from the workstation with no
environment set: 42069, 42070, 42071 all 200 by name, 16 models.

**Why:** the user refused any launch script living outside the repo on the
laptop ("how dare you place files in the laptop outside of the repo"); the
prior `~/open-lan-launch.sh` and every other home chain script were moved to
`~/qwen-webui-state/retired-home-scripts/` (48 files) and should be deleted
once the user confirms.

**How to apply:** relaunch only through the repo script after a
`sync-runtime-tree.sh` from a worktree; a bundle-bound path (parameters,
MCP configuration) is read from the bundle, never defaulted by a wrapper.

Laptop GitHub access: `~/.ssh/id_ed25519_github` copied there with a
`Host github.com` block, `origin` switched to ssh, `gh` 2.100.0 in
`~/.local/bin` (added to `~/.profile`), authenticated with the workstation
token, `git_protocol ssh`. Laptop `~/Github/qwen-apu` main tracks origin/main;
its remaining worktrees are `~/qwen-gate-lanes/{build-cache-identity,
census-timing,probe-projector-router-mode}` on `incoming/*` mirrors, to be
removed as each lane merges. Laptop has no unique commits.

Merge program (user directive 2026-09-03, PR #105 stays frozen and closes
as superseded after the seven lanes): lanes deployment-followups,
build-cache-identity, dpm-telemetry, correctness-witnesses, served-ab-harness,
shader-e4, retained-evidence; then #108, #110, #112, #117, #119, #120, #118,
#109, #107, #121; then one main-based bundle activated on the appliance.
Every lane touches `evidence/SHA256SUMS`; `scratchpad/merge-main-into-branch.sh
BRANCH` merges origin/main into a branch, regenerates the manifest on that
one conflict, and pushes. build-cache-identity converts the gate file into
`gate_cell` registrations, so any flat-list lane landing after it needs its
entries re-expressed as cells. `scratchpad/gate-runner.sh LOG BRANCH...`
gates serially on the workstation (main must carry PR #122's sh-shebang
fixture repair, merged 595ee81). Related: [[qwen-stage-a-census-state]],
[[qwen-fixed64-scoreboard-baseline]].

Session 2026-09-03 afternoon, user override (one-off): up to 8 agents (3 opus,
4 sonnet, 1 haiku); the laptop may be torn down for device campaigns; the
site is down while one opus "device conductor" agent runs the E4 holdout
witness, web-reader/web-lookup admissions, the lease-patch admission, image
phase timing, and the prefill ladder, then relaunches through
`qwen-lan-launch.sh`. The user's complaint "the website chronically needs an
API key": the page rendered the key input, LAN hint, and copy button in open
mode; commit ef0e589 on unified-router-image makes the page probe `GET /v1/models`
without a key and hide the controls on 200; served after the next relaunch. Headless Chromium on the laptop
itself against the .local name made zero page requests while the same driver
from the workstation completed a full search turn; unexplained, recorded for
the conductor.

Second landing queue (branches produced 2026-09-03 afternoon, each to be
gated and merged after its base lane lands): `compute-state-lease` (8ef5fb9,
off lane/dpm-telemetry; transaction with lease proof on fd 8, exit 3 clock
unreached, exit 4 restoration failed), `e4b-summary-producer` (off
lane/shader-e4), `e5-sdot-aco` (off e5-int24-shader), `page-key-discovery`
(folded into unified-router-image as ef0e589; the site's next relaunch must scp the page), `gate-cell-identity` (off main),
`tool-prefix-checkpoint` (off main), `device-campaigns-20260903*` (pushed
from the laptop), `split-script-columns-v2` (5db96cc, off main), `q4k-isa-attribution` (off e4b-summary-producer), `power-envelope` and `lease-bounded-stop` (off compute-state-lease), `calibration-integrity`, `telemetry-validator-strictness` (off main), `image-router-review-fixes`, `web-search-review-fixes` (off unified-router-image).

Device window 2026-09-03 outcomes (conductor): site relaunched at f028d01
with the key-discovery page (digest 527f39cb...), verified from the
workstation. E4 holdout B (holdout-12b.tsv, fresh operands): 11/12 held, one
flip at a 0.0085 nat tie that switches reasoning-span mode; the margin
contract contradicts itself at sub-threshold flips (m1 on the control's
winner is negative at every flip), re-registered, margin_robustness unset.
Web admissions: web-reader (2B) fails the served page (prose, no tool
call), web-lookup (0.8B) passes; both rows stay refused; build-web-presets
ignores web_mode so execution_policy alone decides emission. Lease patch
admitted on device (test-vulkan-workload-lease.sh reader repaired; patch
stays candidate). Image phase timing: VAE decode ~ sampler at one step,
PNGs byte-identical. Prefill ladder blocked: the forced clock policy needs
`sudo -v` on the laptop; census_engine_clock_restore swallows an
unauthorized write's status (hazard recorded). INCIDENT: raw broker session
secrets and spent grants were pushed once on device-campaigns-20260903-
web-search-live, ref deleted, branch rebuilt as -r2; the signing key
~/qwen-web-token.key was retired to the state directory so the next
bring-up mints a fresh one.

Repository scratchpad: `~/Github/qwen-apu/scratchpad/` is gitignored (branch
clangd-scratchpad, 01dfdbb, pass-four landing) and holds the session's
runner scripts, plans, review transcripts, and verdict TSVs; the /tmp
scratchpad remains the live copy while a session's runners reference it.
clangd: `remote/write-clangd-config.sh --source ~/src/llama.cpp-prefix-ckpt`
writes `.clangd` + `.clangd-include/` (headers candidate patches add) at the
repo root and `~/.config/clangd/config.yaml` with one PathMatch block per
`~/src/llama.cpp*` tree; a patched tree itself stays untouched because
prepare-llama-vulkan-source.sh reads its git status.
