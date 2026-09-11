---
name: dash-parent-side-fd-redirections
description: "dash applies a command's trailing N>&- in the parent shell's fd table for the child's whole runtime, breaking /proc/$$/fd/N lease verification"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-01T18:22:17.072Z
---

dash evaluates a simple command's `8>&- 9>&-` redirections in its own
descriptor table with save/restore, so `/proc/<shell-pid>/fd/8` is absent for
the entire runtime of that child. Any verifier the child runs against the
parent's fd (the fixed-64 external Vulkan lease proof) fails deterministically,
which wedged the 2026-09-01 scoreboard in the emergency-teardown retry loop.
The repair closes descriptors inside a child shell instead:
`sh -c 'exec "$0" "$@" 8>&- 9>&-' CMD ARGS`. Reproduced on qwen-laptop in
~/fd8-repro. Related: [[qwen-decode-campaign]].
