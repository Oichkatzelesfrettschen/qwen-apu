---
name: github-and-harness-limits
description: "gh GraphQL rate limit is separate from REST and exhausts under CI polling; force-push and rm -rf are denied by the harness, so use REST merges and fresh branch names"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-08-29T03:03:18.711Z
---

`gh pr merge`, `gh pr create`, `gh pr checks`, and `gh run watch` spend the
GraphQL bucket, which exhausted after about 15 PRs of polling in one session
while REST (`gh api`) kept its 5000. `git push -f` and `rm -rf` are denied by
the permission harness regardless of user approval in chat.

**Why:** a merge loop that polls CI through GraphQL blocks itself for an hour;
a rebased agent branch cannot be force-pushed.

**How to apply:** poll runs with
`gh api "repos/O/R/actions/runs?branch=B&per_page=1"`, merge with
`gh api -X PUT repos/O/R/pulls/N/merge -f merge_method=merge`, create PRs with
`gh api repos/O/R/pulls -f base= -f head= -f title= -f body=`. Publish a
rebased branch as `git push origin branch:branch-rebased`, open a new PR, and
close the old one. Ask the user to run `! rm -rf PATH` for deletions. See
[[agent-worktrees-pin-branch-names]].

`git push -f origin HEAD:branch` run from the main checkout rather than the
agent's worktree pushed main onto the feature branch and erased its commits on
origin (2026-08-29, image-vision-review); the worktree still held them. Push a
worktree branch from inside that worktree, and never with HEAD: from main.
