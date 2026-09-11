---
name: qwen-parallel-agent-merges
description: another agent merges session branches into main via reconciliation merges; verify ancestry before pushing or gating a branch
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-01T16:52:24.127Z
---

On 2026-09-01 a parallel agent merged this session's four branches
(natural-boundary-promotion 12be457, draft-pair-measurement-hardening,
telemetry-session-records, build-provenance-proofs) into main through
reconciliation merges inside PR #94, then stacked PRs #95-#101 (fixed-64
served campaign, lease identity binding, pidfd teardown). Merge fidelity was
verified superset-clean.

**Why:** a branch can land without this session pushing it; gating or
re-pushing a stale head wastes a multi-hour laptop gate.

**How to apply:** before pushing or gating any branch, run
`git merge-base --is-ancestor BRANCH origin/main`; find the carrying merge
with `git log --merges --ancestry-path` (without --first-parent). The gate
venv is `~/.qwen-gate-venv` and needs mypy installed since the campaign work
added `mypy --strict` to the gate. The laptop cannot fetch GitHub over https;
push directly with `git push ssh://eirikr@qwen-laptop/~/Github/qwen-apu
BRANCH`. See [[qwen-laptop-repo-copy-and-test-paths]].
