---
name: workstation-gates-pid-namespace
description: Run qwen-apu workstation gates under bwrap --unshare-pid --dev-bind / / --proc /proc; omitting --proc breaks every /proc/PID read in a fixture
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-07T02:25:27.440Z
---

Run `remote/repository-quality-gates.sh` on the workstation under
`bwrap --unshare-pid --dev-bind / / --proc /proc --chdir <worktree>`. The
`--unshare-pid` hides foreign `llama-server` and fixture processes belonging to
another session, and `--proc /proc` is required beside it: `--dev-bind / /`
carries the host's procfs into the new PID namespace, so `$!` is a namespace PID
that resolves to nothing or to a different process there.

**Why:** without `--proc /proc`, `searxng-launch.sh`'s
`process_start_time "$instance_pid"` reads an absent `/proc/<nspid>/stat` and
`test-install-searxng.sh` fails `verify_passes_through_launch_path` with "the
instance left before its identity could be read". The same failure reproduces
at a known-green `main`, so it reads as a code regression when it is the
harness. Any fixture that records a PID and its start time has this shape.

**How to apply:** always pass `--proc /proc`. When a gate cell fails, run that
one test standalone at `main` before treating it as caused by the branch; a
failure at both heads points at the invocation rather than the diff.

Gates run from a worktree under `~/worktrees/<repo>/<branch>`, never the
primary checkout -- `test-runtime-root` refuses because the marker binds to the
production checkout. Set `QWEN_HOME` and `QWEN_TEST_PORT_LEASE_DIR` under that
worktree. See [[qwen-runtime-root-doctrine]] and
[[workstation-shared-with-nvidia-session]].
