---
name: codex-cli-usage
description: "How to delegate a bounded task to the Codex CLI on this workstation (model name, effort flag, sandbox limits)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-05T05:36:11.985Z
---

`codex exec` (codex-cli 0.153.x) runs a bounded task from a worktree:
`codex exec -c model_reasoning_effort=low -s workspace-write --add-dir /tmp -C DIR -o OUT.txt 'task'`.
The configured default model is `gpt-6-astra`; passing `-m astra` is refused
("not supported when using Codex with a ChatGPT account"), so name no model
and set effort through `-c`. `--full-auto` is not a flag on this version.
Its sandbox blocks socket creation and tmux, so a test that launches
listeners must be rerun outside Codex, under `bwrap --unshare-pid` on this
workstation (see [[workstation-gates-pid-namespace]]). Disclose with
`Assisted-by: Codex CLI (gpt-6-astra)` in the commit trailer.

**How to apply:** give Codex one file and one acceptance command, review the
diff, and run the acceptance command yourself.
