---
name: qwen-fixed64-scoreboard-baseline
description: "The first sealed fixed-64 served scoreboard (2026-09-01, source 7e79435) reads every class unmet -- 18.257 / 9.864 / 3.352 tok/s against 20 / 10 / 5.25; it is the Stage 0 denominator, and bare rsync of remote/ now breaks the runtime-tree manifest"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-01T22:56:02.423Z
---

`evidence/fixed64-served-campaign/20260901T2011Z/` is the Stage 0 throughput
denominator: twelve arms, zero failures, zero hazards, four-arm means 18.257
(0.8B), 9.864 (2B), 3.352 (4B) tok/s, spans 17.89% / 0.65% / 1.01%. The 0.8B
span is one arm whose sclk stepped through 733 and 1050 MHz. In-sweep ratios
2B/0.8B 0.540, 4B/2B 0.340, 4B/0.8B 0.184.

**Why:** Every later optimization bundle is read as a ratio against this run
inside one sweep, and the campaign only runs from a clean git worktree on the
laptop (`~/qwen-gate-84d24b4`) with `QWEN_SERVED_CAMPAIGN_LATENCY_PROBE`
bound to the runtime tree's probe; each failed invocation burns its output
path.

Task 11.1 merged as bc278a8 (2026-09-02, gate accepted on d8a3e16 with an
identical runtime payload). The appliance serves from bundle
`natural-boundary-13d05a0-r2` under `~/qwen-deployments`, which carries its
router preset; the emergency bundle
is `emergency-forced-tail-40f7b775-r2`. Pre-preset bundles at the root are
refused by the activator (manifest lacks the preset rows). Router children
spell the count `--swa-checkpoints` in argv. A launch resolves its bundle
once through `remote/resolve-active-deployment.sh` and carries it as
`QWEN_ACTIVE_DEPLOYMENT_DIRECTORY`; test harnesses that copy `qwen-launch.sh`
or the control script into a fixture must copy the resolver beside them.
`sync-runtime-tree.sh` needs the explicit destination
`eirikr@qwen-laptop:~/qwen-laptop-setup` on this workstation.

**How to apply:** Sync the laptop with `remote/sync-runtime-tree.sh`, never a
bare rsync -- the launch checks `runtime-tree-manifest.tsv` and refuses a
divergent tree (the two rsync lines in CLAUDE.md produce exactly that). Run
long laptop jobs under `setsid nohup` with a script file, since the ssh-bound
Bash timeout kills them mid-run, and never `pkill -f` a pattern that appears
in the ssh command line itself. See [[qwen-decode-campaign]] and
[[dash-parent-side-fd-redirections]].
