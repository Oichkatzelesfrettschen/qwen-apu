# The composed Q4_K candidate served on the 4B: promoted at +6.6%

```text
measurement_status=served-ab
arm_order=W C K K C C K K C
control_server=70aa78bc... (nine-member production series, the bytes bundle main-7f8f2ed-r1 serves)
candidate_server=83684f3c... (the same series plus the five Q4_K stack patches; the composed formulation is the build's default)
scoreboard_receipt=ad69c27c... (evidence/q4k-scale-decode/target-closure-20260905/denominator/)
engine_clock=applied policy=manual sclk_level=2 mclk_level=2 required_sclk_mhz=1100 required_mclk_mhz=933
cooldown_deadline_s=240
served_ab=promoted mean_delta=+0.0663 ci=[+0.0617,+0.0709] comparable_pairs=4 arm_failures=0
```

The 4B was reopened for the composition by `../4b-kernel-delta-20260905/`,
which read the composed module's median dispatch 9.3% shorter than
production's (744 against 820 us on the clean arms) and its aggregate Q4_K
exclusive time 12.16% shorter [-17.56, -6.76] over the whole four-pair
acquisition, 10.5% over the three clean pairs. That bracket carries the census instrument in
both trees and one degraded control arm, so it explains the mechanism and
prices no promotion; this run carries the performance-admission claim, since
both its builds are the uninstrumented serving executables. This run is the served comparison of the two uninstrumented
serving builds under the registration's own shape and rule
(`evidence/q4k-scale-decode/target-closure-preregistration.md`: one priming
warmup, two mirrored quadruples, the one-sided +5% paired bound), the shape
that read the 2B unresolved twice at +5.3% and +5.5%.

| slot | arm | tok/s | clock |
| ---: | --- | ---: | --- |
| 0a | W | 3.063 | 1100/933 held |
| 1 | C | 3.085 | 1100/933 held |
| 2 | K | 3.291 | 1100/933 held |
| 3 | K | 3.299 | 1100/933 held |
| 4 | C | 3.088 | 1100/933 held |
| 5 | C | 3.087 | 1100/933 held |
| 6 | K | 3.297 | 1100/933 held |
| 7 | K | 3.267 | 1100/933 held |
| 8 | C | 3.076 | 1100/933 held |

Paired deltas +6.68, +6.83, +6.80, +6.21%; mean +6.63%, sd 0.29%, nominal 95%
interval [+6.17, +7.09]; every arm's sidecar accepted and no pair left the
clock band. The control's four arms span 3.076 to 3.088 and the candidate's
3.267 to 3.299, so the two sets separate by more than twenty control spreads.
The whole interval sits above the bound and the summarizer reads
**promoted**.

The number agrees with the bracket: the composed module shortens a dispatch
that owns 57% of the token by about a tenth, which is about 6% of the token,
and the served rate moves 6.6%. The control mean is 3.084 tok/s and the
candidate mean 3.2885. Against the 5.25 tok/s interactive target of
`evidence/decode-bound-analysis.md`, +6.63% removes about 6.22% of the time
per token and leaves about 59.6% of rate still to find; both figures describe
this window's machine state rather than a replacement baseline. It also disagrees with the null retained on
2026-09-03 for the reason `../4b-kernel-delta-20260905/README.md` states:
that null measured a two-patch candidate without the activation patches, and
the composed five-patch stack had never been served on the 4B before this run.

## What this licenses

By `AGENTS.md`'s class rule, a general runtime experiment becomes a
Raven2-wide default only where the classes agree, and a win on one class alone
becomes that class's profile setting. The 2B reads unresolved at +5.3% and
+5.5% against the same bound and the 0.8B dispatches this shader never, so the
composition is a 4B-class result under that rule, measured on one artifact:
`qwen38-4b-distill` Q4_K_M at this receipt's tuple under the composed stack's
own shader selection. Another 4B checkpoint, another quantization, another
depth, and a projector-carrying configuration each stay unmeasured here. The
candidate build's composed default is the formulation the 4B row would serve.
Two separate facts leave the composition without a correctness witness. The
bracket's `summary.tsv` reads `token_identity` and `margin_contract`
`unavailable` with `no --witness directory`, which establishes nothing about
either executable. The one retained 4B witness,
`../kernel-delta-witness-4b-20260903T2020Z/inputs.tsv`, names
`candidate_server_sha256` `2955d6dd...`, the earlier two-patch build. Neither
the census candidate `4844d0dc...` nor this serving candidate `83684f3c...`
carries a witness, so a witness run over the release executable precedes
activation. What that takes is a serving decision
rather than another measurement -- the five candidate patches would move to
the production stage of `remote/llama-patch-series.tsv`, which changes the
series digest every receipt binds, and the 4B row would carry the selection
-- and that decision is the operator's. The control rates here, 3.08 tok/s
against the 3.38 the same server read on 2026-09-03, are the machine's state on
this afternoon (the warmup read 3.06 and every arm held the clock pair), and a
paired delta is what the shape isolates from it.
