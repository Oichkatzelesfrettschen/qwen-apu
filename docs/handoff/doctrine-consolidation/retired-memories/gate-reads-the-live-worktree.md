---
name: gate-reads-the-live-worktree
description: "run-repository-gate.sh executes the driver in the worktree itself, so editing files during a run produces failures that read as code regressions"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-07T12:27:56.928Z
---

`remote/run-repository-gate.sh` bwraps `--chdir "$worktree"` and runs
`$worktree/remote/repository-quality-gates.sh` in place. It copies nothing, so
a file edited while the gate runs is the file the remaining cells read. The
run's own `head=` line records the commit that was checked out at launch, which
makes a mid-run edit invisible in the result record.

On 2026-09-07 an edit to `remote/runtime-root.sh` made during a gate run
rejected `test-runtime-root` with three failures; the committed revision passed
standalone, and the same edit reproduced the failure once completed. Two
distinct causes wore one symptom.

**Why:** a rejected cell is read as caused by the branch, per the doctrine that
compares branch head against `main`. That comparison is meaningless when the
tree moved underneath the run, and it costs a full gate cycle to discover.

**How to apply:** commit, launch the gate, then leave the worktree alone until
the verdict lands. Work on something outside the tree while it runs, or open a
second worktree for the next cluster. When a cell rejects, check
`git status --porcelain` before reading the failure as a regression -- a dirty
tree at verdict time means the run measured something that was never committed.
Related: [[workstation-gates-pid-namespace]],
[[qwen-parallel-agent-merges]].
