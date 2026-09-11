---
name: dash-dot-command-aborts
description: "In dash a `.` of a missing file aborts the whole non-interactive script silently, so a detached laptop chain died with an empty log"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-06T22:56:00.655Z
---

`. file 2>/dev/null` in a POSIX `sh` script exits the shell when the file is
absent, before any later line runs; `2>/dev/null` hides the message.

**Why:** A `setsid nohup sh chain.sh` on the laptop left a zero-byte log and
no process because its second line dotted a vars file that never existed.
`pgrep -f chain.sh` from an ssh command matches the ssh command line itself,
which faked a "running" answer.

**How to apply:** Guard with `[ -r file ] && . file`, and prove a detached
job by reading its log rather than by pgrep. See
[[dash-parent-side-fd-redirections]].

The same self-match bites locally, not only over ssh. A background Bash whose
own command line contains the pattern makes `pgrep -f <pattern>` inside it
always true, so a "wait for the other job to finish" loop never breaks and
burns its whole deadline: on 2026-09-06 two chained gate waiters stalled that
way, first on `pgrep -f repository-quality-gates` and then on
`pgrep -f 'bwrap .*repository-quality-gates'`, because the wrapper's text
carried both strings. Match the executable instead -- `pgrep -x bwrap` for a
namespaced gate -- or read the other job's log for its terminal line. Also
write a long gate's output to a file rather than piping it through `tail`:
a task killed mid-run then leaves inspectable progress instead of nothing.
