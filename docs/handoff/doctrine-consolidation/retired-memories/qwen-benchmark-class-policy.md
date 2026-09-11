---
name: qwen-benchmark-class-policy
description: 2B is the primary performance target, 0.8B secondary, 4B the quality fallback; run general experiments 2B then 0.8B then 4B, and grade every fine-tune separately
metadata:
  type: feedback
---

On 2026-08-29 the user retired the 4B as the implicit reference model: the
2B class is the primary performance target, the 0.8B the secondary fast
target, the 4B the quality-heavy fallback. General runtime experiments run
2B, then 0.8B, then 4B; a result is appliance-wide only when the classes
agree, otherwise it is a per-class profile setting. Quality belongs to the
learned checkpoint (every fine-tune gets its own grade); throughput belongs
to the execution class (skip only truly identical throughput arms).

**Why:** the early 4B rate target (3.3 -> 4.5 tok/s) kept leaking into
experiment selection, which the user called the wrong priority.

**How to apply:** order every queue 2B -> 0.8B -> 4B; speculation priority is
2B<-0.8B draft, then 4B<-0.8B, then 2B MTP N=1. Do not benchmark all six
uncensored rows because they are visible; grade them when chosen for a role.
Recorded in CLAUDE.md "Three runtime classes, one primary target". See
[[qwen-image-turn-language-model]].
