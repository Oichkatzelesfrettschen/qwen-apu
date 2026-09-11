---
name: all-artifacts-live-in-the-repo
description: "Every report, handoff, preamble, or working document goes under ~/Github/qwen-apu (docs/handoff/ for handoffs), never in ~ or scattered directories; at low usage budget spawn no agents unless tight and haiku"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-07T20:22:46.425Z
---

The user requires every artifact produced for this project to live inside
`~/Github/qwen-apu` (handoff and operating documents under `docs/handoff/`),
never in the home directory, scratch, or any other location.

**Why:** the repo is the one place the user and any successor look; a file
in `~` is lost to them and the user has said so more than once.

**How to apply:** write reports, handoffs, and agent preambles into the repo
tree and name the repo-relative path. When the usage budget is nearly gone,
spawn no further agents unless the task is tightly scoped and runs on haiku.
Related: [[qwen-runtime-root-doctrine]].
