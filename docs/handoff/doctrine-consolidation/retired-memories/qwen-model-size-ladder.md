---
name: qwen-model-size-ladder
description: "The appliance size ladder is 0.8B -> 2B -> 4B -> 9B -> 27B; the 2B-4B gap is intentionally empty, both 3B rows are quarantined, and a Qwen3.8 3B distill does not exist and must not be invented"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-04T15:33:46.977Z
---

Canonical ladder (user's decision 2026-09-04, checked into CLAUDE.md on branch model-ladder-doctrine): `0.8B -> 2B -> 4B -> 9B -> 27B`. Qwen3.5 dense ships those sizes and empero-ai distills 2B, 4B, 9B only. `nanbeige42-3b` (pathological 44-loop/22-weight execution) and `ministral3-3b` (graph assertion abort) are quarantined at model scope in `remote/quarantine.tsv`. No publisher ships a Qwen3.8 3B distill.

**Why:** the user asked for a 3B midpoint, none exists, and said "If none exists, do not invent one"; a future "smooth size ladder" search must follow real checkpoints.

**How to apply:** an experiment wanting a midpoint reads the 2B and the 4B rows. Never register, download, or name a 3B Qwen distill. See [[qwen-benchmark-class-policy]] and [[qwen-model-lane-roadmap]].
