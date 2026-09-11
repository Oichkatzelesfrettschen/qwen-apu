---
name: agent-worktrees-pin-branch-names
description: "A finished agent's worktree keeps its branch checked out, so git branch -f and a second agent's checkout of that name both fail until the worktree is removed"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 725faac4-884e-4aa4-965c-889a730670c1
  modified: 2026-08-28T14:11:47.746Z
---

Agent worktrees under `.claude/worktrees/agent-*` stay registered after the agent
finishes, and each keeps its named branch checked out. `git branch -f <name>` then
refuses ("used by worktree"), and a later agent told to `checkout -B <name>` falls
back to a renamed branch (`web-profiles-rebase`, `web-research-mcp-defects`) and
reports the deviation.

**Why:** Git refuses to move a ref that any worktree has checked out; `git worktree
prune` removes only worktrees whose directories are gone.

**How to apply:** Before `git branch -f` or re-dispatching an agent onto a branch
name, run `git worktree list`, confirm the old worktree is clean, and `git worktree
remove --force <path>`. Push named branches explicitly (`git push origin
<branch>:<branch>`), never the `worktree-agent-*` ref. See [[qwen-appliance-host]]
for the laptop side of this repository.
