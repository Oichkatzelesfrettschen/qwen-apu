---
name: background-agents-model-choice
description: "Every background agent (Agent tool) must name model haiku, sonnet, or opus explicitly; never leave the model to inherit"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-02T04:28:18.795Z
---

Background agents run only as haiku, sonnet, or opus. Every Agent call
passes `model` explicitly, scoped to the task: haiku for narrow lookups,
sonnet for ordinary implementation or exploration, opus for reviews and
multi-file changes.

**Why:** The user asked for this directly ("remember to use only haiku,
sonnet, opus background agents!"); an unspecified model inherits the parent
session's model and spends its budget on work a smaller model covers.

**How to apply:** Set `model` on every Agent invocation, including Explore
and other named agent types; forks are the one exception since they always
run on the parent model, so prefer a fresh agent with a named model over a
fork.

Codex review gate (user directive 2026-09-03): every agent runs, before its
final report, `codex review -c 'model="gpt-daybreak-blue-latest"' -c
model_reasoning_effort=low --base REF` (or `--commit SHA`; `--commit`/`--base`
exclude a custom prompt; `-m` is not a `review` flag; the model id carries the
`gpt-` prefix, `daybreak-blue-latest` alone is refused under the ChatGPT
login), addresses P1/P2 findings in a follow-up commit, reruns once, and
reports a "Codex review" section. CLAUDE.md wins over the reviewer.

Agent wait discipline (2026-09-03): the task-output directory is shared by
every agent of the project, and `pgrep -c codex` counts every agent's
review plus a persistent `codex app-server`; an agent waiting on its own
codex run must run it in the foreground with a timeout or scope a wait to
its own worktree (cwd), and must read the review file's tail for the
verdict. Background codex runs inside agents stalled twice this session.
