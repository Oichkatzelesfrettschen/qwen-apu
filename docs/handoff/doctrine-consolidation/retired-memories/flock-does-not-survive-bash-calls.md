---
name: flock-does-not-survive-bash-calls
description: "Each Bash tool call is a fresh shell, so `exec 9>lock; flock 9` in one call releases at that call's end; serialize gates with one `flock LOCK sh -c '...'` command per landing"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-07T14:15:55.049Z
---

A lock descriptor opened in one Bash tool call is closed when that shell
exits, so `exec 9>/tmp/qwen-gate/gate.lock; flock 9` followed by the gate in a
later call serializes nothing. On 2026-09-07 three subagent gates ran
concurrently under that pattern and shared the fixture port-lease authority.

**Why:** the repository gate is fixture-heavy and its port leases collide
across concurrent runs, so a collision reads as a spurious `cell=rejected`.

**How to apply:** run rebase, push, gate, and merge as one
`flock /tmp/qwen-gate/gate.lock sh -c '...'` command in a single Bash call
(run_in_background), so the lock is held across the whole landing and the
gated tree is the merged tree. The same applies to a device lease or a
relaunch trap: they live only inside the one shell that set them.
Related: [[gate-reads-the-live-worktree]], [[workstation-gates-pid-namespace]].
