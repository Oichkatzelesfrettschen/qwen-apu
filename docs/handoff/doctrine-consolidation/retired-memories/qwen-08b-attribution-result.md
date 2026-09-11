---
name: qwen-08b-attribution-result
description: "0.8B attribution ran 2026-09-05: 25-arm calibration (P production 70aa78bc, I production census twin 522e6367), four I1 arms; Q8_0 mat-vec owns about 67% of the 3.6 s decode at 187 calls/graph and 186 us median; controls unresolved/incomplete; record under evidence/q8-attribution/device-20260905/"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-05T21:44:26.555Z
---

`evidence/q8-attribution/device-20260905/` (branch 08b-attribution-20260905)
retains canary (accepted) plus a 25-arm calibration on qwen35-08b at manual
1100/933 with a 120 s cooldown: one P arm refused on window_lost 5.8%;
sidecar control -1.6% [-5.4, +2.2] unresolved, compile incomplete, collect
-0.9% [-2.4, +0.6] unresolved. Four I1 arms: decode 3529-3705 ms per 64
tokens (17.0-17.9 tok/s), `mul_mat_vec_q8_0_f32_f32` exclusive 2415-2418 ms
(about 67%), 187 calls/graph at 186.4 us, 40 VGPRs; next owners get_rows
140 ms, gated_delta_net 118 ms, contig_cpy 94 ms, rms_norm_mul 48 ms.
Streamed 0.801 GB/token (Q8_0 98.4%).
Reading rules: 186.4 us x 187 = 34.9 ms is not the 38.36 ms/graph family
total (use summed exclusive time); the 0.8B mat-vec share (66.7%) is below
the K-quant classes' two-family total (about 85%), so Q8_0 is the dominant
single pipeline, not a larger mat-vec share; the 17% "outside every dispatch"
remainder includes ambiguous overlap and is not host time; 20.9 GB/s is
logical bytes over the family interval, not a controller counter; the
-0.88% collect mean is not an error bar (controls unresolved).

**How to apply:** the production census twin lives at
`.runtime/opt/llama.cpp-prod-census` (candidate_series = census patch alone,
series a91a215a); P must be `.runtime/opt/llama.cpp/build-raven2-vulkan-production/bin/llama-server`
(same bytes as the bundle, but the bundle's manifest names the eight-member
series and the runner refuses the identity). A canary's first P arm can lose
coverage on its eight-token window; the calibration's warmup absorbs it.
Receipt: `.runtime/results/2b-closure-20260905T0545Z/fixed64/identity-check.tsv`.
See [[qwen-4b-null-attribution]].
