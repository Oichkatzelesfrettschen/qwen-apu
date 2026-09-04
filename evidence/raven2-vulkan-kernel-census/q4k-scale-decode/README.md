# The Q4_K scale-decode candidates on the device: refuted at +1.83%

```text
measurement_status=served
served_ab_verdict=refuted
model_id=qwen38-2b-distill
mean_delta=+0.0183
ci=[+0.0163,+0.0204]
bound=0.05
comparable_pairs=4
arm_failures=0
witness=held contract=margin
control_server_sha256=5dd86b90154f6143a5303efd2590b9268a0a5e3e908c4d6791f1fde03a4782c2
candidate_server_sha256=2955d6dd653f3a5cfee6573c1361cf8b694c066905cae1622e4de0d6cb47e98b
candidate_series=llama-vulkan-q4k-scale-word-select.patch,llama-vulkan-q4k-superblock-loop-licm.patch
engine_clock=auto policy=auto census_regime=unreached arms=16
```

`evidence/q4k-scale-decode/README.md` compiled these two patches on the RAVEN2
shim and read the compiler: the served shape's superblock loop body falls from
395 instructions to 349, its VGPR allocation from 64 to 48, and the driver's
own occupancy statistic from 4 subgroups per SIMD to 5, which that page calls
the largest effect on it. Nothing there executed a submission. This directory
is the submission, and it answers the question the compiler cannot: the served
64-token decode moves +1.83%, with a nominal 95% interval of +1.63% to +2.04%
that lies entirely below the repository's +5% promotion bound. The verdict is
**refuted**, and the candidates return to the shader lane rather than to the
serving preset.

## Correctness first: the candidate returns the control's own tokens

`run-kernel-delta-witness.sh` under the `margin` contract ran the mirrored
quadruple `C K K C` over six state-carrying prompts at temperature 0, top_k 1,
seed 1, `ignore_eos`, and prompt caching off, each start answering every prompt
twice. `kernel-delta-witness-20260903T1941Z/margin-summary.tsv` reads `held` on
every row: the token-id arrays are identical over all 508 to 512 compared
positions per prompt, `min_retention` is 1 wherever a margin is read, no
position carries a nonpositive candidate margin, and `max_abs_logprob_delta` is
0 on every prompt. Both self-comparisons hold, so the control agrees with
itself and the candidate reproduces it exactly rather than within a bound. The
`logprob-bound` contract holds beside the margin contract at its own 1e-3.

The served run carries the same claim through a second route:
`served-ab-20260903T1953Z/terminal-state.tsv` reads `response_identity=held`
over 4 pairs, so every arm's reply agreed with its partner's.

Bit-identical output is what the equivalence argument predicts.
`scale-select-equivalence.py` closes the scale selection with a basis argument
over GF(2), conditional on a linearity premise the expressions carry, and the
loop restructure moves a descriptor load and twelve row-base additions out of
the body without touching the arithmetic. The witness turns that argument into a measurement on the device.

## The measurement

Nine arms, `W C K K C C K K C`, each a fixed-64 served decode through
`measure-served-decode.sh` at the registry tuple, under the fixed-64 scoreboard
receipt that binds the control. `run-served-binary-ab.sh` opened with 16 warmup
arms and the clock policy left at `auto`.

| slot | arm | tok/s | modal sclk |
| ---: | --- | ---: | ---: |
| 1 | C | 9.848 | 1100 |
| 2 | K | 10.028 | 1100 |
| 3 | K | 10.017 | 1100 |
| 4 | C | 9.821 | 1100 |
| 5 | C | 9.845 | 1100 |
| 6 | K | 10.011 | 1100 |
| 7 | K | 10.022 | 1100 |
| 8 | C | 9.842 | 1100 |

Four paired deltas, `+0.0183 +0.0200 +0.0169 +0.0183`, sample standard
deviation 0.0013, four comparable pairs, zero arm failures, zero cooldown
timeouts, and one selected graphics clock on every arm and every warmup.

## The regime precondition declined a state the run then measured cleanly

`census_regime=unreached` after the full 16-arm warmup budget, and the reason
is the share ceiling rather than instability. The precondition reads a warmup
window's modal share and declines a mode above
`QWEN_CENSUS_REGIME_MAX_SHARE` of 0.30 because such a window reports pinned
boost rather than the hovering sustained regime the appliance serves in. Every
warmup here held 1100 MHz, from 9.797 to 9.873 tok/s, a spread of 0.8% across
sixteen arms, so the run never entered the sustained regime the precondition
waits for and spent its whole budget declining boost.

What the precondition protects against is a comparison that crosses regimes
partway through, and this run crossed nothing: all twenty-four arms held one
modal clock and the eight measured arms separate into two bands 1.8% apart
with no overlap. The measurement is therefore read on its own pair
comparability, which is the fallback the harness states for an unreached
regime, and the interval it produced is the tightest this tree has recorded.
`e4/served-ab-20260902T2032Z` is the only earlier served A/B that reached a
verdict with an interval, at `+0.0150` over `[-0.0529, +0.0828]`, a half-width
of 6.8% where this run's is 0.2%. An idle appliance under boost is a better
comparison condition than the served regime and a worse model of it, and both
halves of that belong to the reading below.

The two E4-family shader candidates land in one small band from opposite
measurement conditions: E4's activation-group-sums arm read +1.50% and this pair
reads +1.83%. E4's interval spans zero and settles nothing on its own, so the
agreement is a coincidence of two central values rather than a replication, and
it is recorded here as such.

The run held `power_dpm_force_performance_level` at `auto` throughout and wrote
the attribute never, so no compute-state transaction was opened and the
appliance's DPM authority is untouched. The `manual-gfx1100-fclk933` operating
point the campaign prefers needs `sudo -n`, which the session's keepalive did
not cover for the run window; the boost regime the machine selected on its own
delivered the same 1100 MHz graphics clock the manual policy commands, and it
leaves the fabric clock unpinned, which is the one nuisance term this run does
not control. `clock-state.tsv` is absent for the same reason: the forced-policy
readback the census writes belongs to a policy this run did not apply.

The scope of +1.83% follows from that state and is narrower than the number
looks. Every arm ran at 1100 MHz on an idle appliance with the qemu tenant
quiet, which is the boost regime the precondition declines rather than the
sustained 762 to 857 MHz regime the harness's own header says the served
appliance lives in. What this candidate is worth in the sustained regime is
**unmeasured**: a lower graphics clock lengthens every issue slot while the
DDR4 path it waits on is unchanged, so the issue-side saving this patch makes
should be worth more there rather than less, and that direction is an argument
rather than a measurement. Measuring it needs `manual` under a sudo window, or
a warmup budget long enough for the machine to leave boost on its own.

## The deviation is the finding

The compile receipt and the served rate disagree by about a factor of six, and
the disagreement is the result.

The body loses 46 of 395 instructions, 11.6%, and the whole shader loses 24 of
810 VALU with VMEM falling 56 to 40. The denominator comes from the file rather
than from a share recalled: `gguf-tensor-census.py` over
`Qwen3.8-2B-Q4_K_M.gguf` reads 641,802,240 bytes of Q4_K at 48.91% against
657,162,240 of Q6_K at 50.08%, and `decode-decomposition.md` places the Q4_K
mat-vec family at about 52 of the 2B's 101 ms token, which is the same half by a
second route. An issue-bound family converting an 11.6% body reduction at the
full ratio would move the token about 6%, and the occupancy step from 4 waves
per SIMD to 5 is a 25% rise in available latency hiding on top of it. The
measured +1.83% is under a third of the instruction-count reading alone.

That places the served Q4_K decode well away from issue-bound, and it agrees
with what this tree already measures elsewhere: the 2B streams 1.263 GB per
token and achieves 10.41 GB/s against a 34.13 GB/s theoretical peak, and RADV
reports every `shaderIntegerDotProduct` acceleration flag false, so about 83%
of streamed bytes take the FP16-dequantize-then-dot family. A `v_add_u32`
removed from a wave already waiting on DDR4 returns nothing, and an extra wave
per SIMD helps only where there is issue work to overlap the wait with.

The direction and the reproducibility are both real. Four paired deltas
agreeing to 0.3% of each other, over binaries proven to descend from one base
build and to emit identical tokens, is as clean a positive as this machine
produces. The candidates are refuted as a serving promotion and confirmed as a
genuine, small, measurable gain.

| prediction | value | outcome |
| --- | --- | --- |
| the verdict | `refuted` or `unresolved` at bound 0.05 | met: `refuted`, the whole interval below +5% |
| the mean paired delta | above the E4 term, on an occupancy step E4 had no counterpart for | deviated: +1.83%, under a third of the body-instruction reading |
| comparable pairs | 4 of 4 at one selected graphics clock | met: 4 of 4, 1100 MHz on every arm |
| token identity | held | met, bit-for-bit, with zero logprob movement |

## The 0.8B is the null this comparison needed

The class policy runs the 0.8B second, and on this candidate that arm is a
control rather than a second reading. A Q8_0 label states a recipe rather than a
layout, so the claim is read from the file: `gguf-tensor-census.py` over
`Qwen3.5-0.8B-Q8_0.gguf` reports 820,613,120 bytes of Q8_0 at 98.44% and no
Q4_K row at all, with ffn, embedding, attention, gated_deltanet, and mtp each
carrying Q8_0 alone. The patched `mul_mat_vec_q4_k` is therefore never
dispatched on this checkpoint. A candidate that changed only that shader must
measure zero here, and any nonzero result would say the patch reached something
outside the shader it names.

| slot | arm | tok/s |
| ---: | --- | ---: |
| 1 | C | 19.059 |
| 2 | K | 19.073 |
| 3 | K | 18.990 |
| 4 | C | 19.011 |
| 5 | C | 19.032 |
| 6 | K | 19.152 |
| 7 | K | 19.084 |
| 8 | C | 18.998 |

`served_ab=refuted mean_delta=+0.0026 ci=[-0.0028,+0.0080] comparable_pairs=4
arm_failures=0`, with the four deltas `+0.0007 -0.0011 +0.0063 +0.0045`
straddling zero and every arm again at 1100 MHz. The witness holds token
identity on this class too.

The interval spans zero, so the null is met, and it does a second job the 2B arm
cannot do for itself: it measures this harness's own noise floor on this idle
machine at about +/-0.5% of a paired mean. The 2B's +1.83% with an interval of
+1.63% to +2.04% sits clear of that floor by more than a factor of three, so the
Q4_K arm's gain is an effect rather than a scheduling artifact. Reading the two
arms together is what licenses that statement; neither reads it alone.

## The eight-row shape is not a served arm

`evidence/q4k-scale-decode/README.md` Table 2 compiles the same two candidates
at `NUM_ROWS = 8` and reports the instruction result without the register
result: VGPR holds at 64 and the occupancy step is absent. No served A/B
addresses that shape, and the reason is the host rather than the harness.
`ggml-vulkan.cpp` passes `rm_kq = 4` on its `AMD_GCN` branch and the decode
ledger records `constants=64,4,1`, so a decode on this device dispatches the
four-row pipeline and the eight-row pipeline is never selected. The eight-row
arm stays a compile receipt, and a served measurement of it needs a host change
that makes the device select it, which would be a different candidate.

## Retained

```text
kernel-delta-witness-20260903T1941Z/   six prompts, C K K C, margin contract,
                                       qwen38-2b-distill
served-ab-20260903T1953Z/              16 warmups and 8 arms, policy auto,
                                       qwen38-2b-distill
kernel-delta-witness-08b-20260903T2004Z/  the same six prompts, qwen35-08b
served-ab-08b-20260903T2004Z/          16 warmups and 8 arms, policy auto,
                                       qwen35-08b, the Q8_0 null
```

Paths in every retained record carry `$HOME` for the serving user's home and
`qwen-laptop` for the appliance hostname.
