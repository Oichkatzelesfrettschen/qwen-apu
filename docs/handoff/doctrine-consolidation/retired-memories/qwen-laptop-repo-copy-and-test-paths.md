---
name: qwen-laptop-repo-copy-and-test-paths
description: the laptop holds a full repo copy at ~/Github/qwen-apu beside ~/qwen-laptop-setup/remote; registry tests need the repo copy and device harness tests need the router down
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-01T00:41:52.619Z
---

Since 2026-08-28 the laptop (qwen-laptop) carries a full rsync of the repo at
`~/Github/qwen-apu` in addition to the runtime copy at
`~/qwen-laptop-setup/remote/`. Both come from the same `rsync` of main.

**Why:** `test-model-registry.sh` resolves `evidence/depth-validation-32k/...`
relative to the repo root, so it fails under `~/qwen-laptop-setup` (which holds
`remote/` alone) with "validation evidence is unreadable". Device harness tests
(`test-probe-depth-projector.sh`) refuse with "another llama process holds the
device" while the router serves; that is a refusal, not a defect.

`build-llama-trace.sh` and `verify-llama-patch-series.sh` read `../patches` from
their own directory, so `~/qwen-laptop-setup/patches/` must be rsynced beside
`remote/`; a stale patch there fails the six-patch digest gate (seen 2026-08-29
with llama-vulkan-submit-trace.patch).

Admission harnesses resolve `validated_evidence` against their own tree and
the session needs `../build/vulkan-graphics-service-probe`, which only
`~/qwen-laptop-setup/build/` holds, so a harness runs from
`~/qwen-laptop-setup/remote` after the tracked tree is synced into that copy:
`git ls-files -z | rsync -a --files-from=- --from0 ./ eirikr@qwen-laptop:~/qwen-laptop-setup/`
(no `--delete`, so `build/` survives).

The rule is discipline rather than an executable invariant, and it failed once
in exactly the way that predicts: on 2026-09-01 a re-run script set
`R=$HOME/Github/qwen-apu/remote`, the launch reached
`state=failed reason=graphics_latency_probe_unavailable` only after
`llama-server` had already loaded the model and taken the device, and the
failure left an orphan process that had to be killed by PID. The incident
record reads `reason=wrong_runtime_tree measurement_status=invalid`; it enters
no sweep and alters no checkpoint evidence.

The fix, queued after promotion and kept off both the promotion and the
telemetry branch: resolve and verify the runtime root before the first fork,
require the graphics probe, monitor, kernel watcher, selected server binary,
and a runtime marker to exist and be executable ahead of any spawn, record the
server PID and `/proc/PID/stat` start ticks immediately after spawning,
terminate that exact identity and prove it absent on every pre-readiness
failure, and test a clone-shaped tree that holds `remote/` without the runtime
`build/` so the launch refuses before creating any `llama-server`. A
runtime-only marker such as `~/qwen-laptop-setup/runtime-tree.identity`,
binding the resolved root and the installed probe digest, keeps a source clone
that happens to carry an unrelated `build/` from passing by accident.

**How to apply:** run registry and evidence tests from `~/Github/qwen-apu/remote`
on the laptop; run device harness tests only after `qwen-teardown.sh`. Sync `remote/` and `patches/` into `~/qwen-laptop-setup` and the whole tree into
`~/Github/qwen-apu` in one step. See [[qwen-appliance-host]].
