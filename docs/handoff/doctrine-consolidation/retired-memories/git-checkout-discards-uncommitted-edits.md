---
name: git-checkout-discards-uncommitted-edits
description: "git checkout FILE as \"cleanup\" discarded a whole session's uncommitted test edits; restore only from a known target, never from a file still being edited"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 725faac4-884e-4aa4-965c-889a730670c1
  modified: 2026-08-28T19:23:45.906Z
---

`git checkout -- remote/test-qwen-session-signals.sh`, run to drop one stray
change, discarded every uncommitted edit in that file and cost a re-apply of
the whole test extension.

**Why:** `git checkout FILE` restores the index copy and has no undo for the
working-tree bytes it replaces; a file with a session's edits in it is the
worst possible target.

**How to apply:** Before any `git checkout FILE`, `git restore`, or `git
stash` in this tree, run `git diff --stat` and confirm the file carries no
edits worth keeping; drop a single stray hunk with a targeted edit instead.
Commit or stash intentionally before cleanup. See
[[agent-worktrees-pin-branch-names]] for the worktree side.
