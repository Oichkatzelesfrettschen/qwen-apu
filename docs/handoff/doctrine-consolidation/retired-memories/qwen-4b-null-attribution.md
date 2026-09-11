---
name: qwen-4b-null-attribution
description: "4B reopened and promoted 2026-09-05: the 09-03 4B null measured a two-patch candidate; the composed five-patch stack shortens the 4B Q4_K dispatch 10% (bracket) and serves +6.63% [+6.17, +7.09] promoted over production; a 4B-class result pending the operator moving the stack into the production series"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-05T21:44:22.077Z
---

`evidence/raven2-vulkan-kernel-census/q4k-scale-decode/4b-attribution-20260905/`
(calibration, composed candidate as P, census twin as I: composed shader
executes under the plain name at 64,4,1, Q4_K 57% / Q6_K 27% of the token)
and `4b-kernel-delta-20260905/` (production census twin `llama.cpp-prod-census`
vs composed census twin `llama.cpp-q4k-census`): Q4_K exclusive total -10.5% over
three clean pairs (median dispatch 744 vs 820 us is -9.3%; the two statistics
differ), graph span -6.8%, instrumented served +8.6%. The full four-pair
record reads the Q6_K null state-changed, CI [-11.03, +5.96]; slot 8 control
ran degraded (Q6_K median 2035 us), and the three-pair reading is a post hoc
sensitivity analysis, not a held null. The uninstrumented served campaign
(+6.63% [+6.17, +7.09], means 3.084 vs 3.2885 tok/s) carries the admission
claim; scope is the measured artifact qwen38-4b-distill Q4_K_M at its tuple.
The kernel-delta run supplies no token-identity witness for the release
executable; one must run before activation.

The 2026-09-03 4B served null (`served-ab-4b-r2-20260903T2115Z`) measured
`scale-word-select + superblock-loop-licm` only, without
activation-group-sums/sideplane; the composed stack had never been served
on the 4B. My first README conclusion ("selected with no local improvement")
rested on that null and is withdrawn in the record itself. Streaming
inside the Q4_K family: 4B 10.0 GB/s (production) vs Q6_K 13.1; 2B 12.5 vs
17.9. Served W C K K C C K K C of production 70aa78bc vs composed 83684f3c
on the 4B: `results/4b-served-20260905T1810Z` on the laptop (outcome in
q4k-scale-decode/README.md).

**How to apply:** the 4B needs `QWEN_CENSUS_COOLDOWN_S`/`QWEN_AB_COOLDOWN_S=240`;
the sampler loses 3-5% of the window under the 4B, so P arms get refused on
`window_lost`; a hot control arm shows as a Q6_K median far above 1282 us.
Check `candidate_series` in a retained `inputs.tsv` before calling any older
"null" the composed stack's. See [[qwen-2b-target-closure-result]].
