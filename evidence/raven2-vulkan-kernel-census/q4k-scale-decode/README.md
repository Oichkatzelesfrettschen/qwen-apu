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
`scale-select-equivalence.py` closes the scale selection over GF(2) by
linearity rather than by sampling, and the loop restructure moves a descriptor
load and twelve row-base additions out of the body without touching the
arithmetic. The witness turns that argument into a measurement on the device.

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
regime, and the interval it produced is the tightest this tree has recorded --
+/-0.2% where the machine's documented uncontrolled spread on a repeated
depth-0 rate is about 4%. An idle appliance under boost is a better comparison
condition than the served regime and a worse model of it, and both halves of
that belong to the reading below.

The run held `power_dpm_force_performance_level` at `auto` throughout and wrote
the attribute never, so no compute-state transaction was opened and the
appliance's DPM authority is untouched. The `manual-gfx1100-fclk933` operating
point the campaign prefers needs `sudo -n`, which the session's keepalive did
not cover for the run window; the boost regime the machine selected on its own
delivered the same 1100 MHz graphics clock the manual policy commands, and it
leaves the fabric clock unpinned, which is the one nuisance term this run does
not control. `clock-state.tsv` is absent for the same reason: the forced-policy
readback the census writes belongs to a policy this run did not apply.

## The deviation is the finding

The compile receipt and the served rate disagree by about a factor of six, and
the disagreement is the result.

The body loses 46 of 395 instructions, 11.6%, and the whole shader loses 24 of
810 VALU with VMEM falling 56 to 40. `decode-decomposition.md` places the Q4_K
mat-vec family at about 52 of the 2B's 101 ms token. An issue-bound family
converting an 11.6% body reduction at the full ratio would move the token about
6%, and the occupancy step from 4 waves per SIMD to 5 is a 25% rise in
available latency hiding on top of it. The measured +1.83% is under a third of
the instruction-count reading alone.

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
```

Paths in every retained record carry `$HOME` for the serving user's home and
`qwen-laptop` for the appliance hostname.
