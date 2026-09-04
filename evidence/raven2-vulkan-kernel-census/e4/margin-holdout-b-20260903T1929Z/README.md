# E4 on the second holdout: eleven prompts held whole, one near-tie flip at 0.0085 nat

```text
contract=margin, re-registered identity line in ../margin-contract-design.md at 881d2f3 ahead of this run
prompts=remote/witness-prompts/holdout-12b.tsv sha256 09f4f3a8..., committed at 881d2f3 before the run and unedited since
control=census v7 (addcae10...), Vulkan0    candidate=census+E4 (741a0d76...), Vulkan0
model=qwen38-2b-distill Q4_K_M (4aa0fb13...), context 24576, batch 128, ubatch 32, cache q8_0/q4_0, Flash Attention on
order=C K K C, 2 runs per start, 128 tokens, temperature 0, top_k 1, seed 1, ignore_eos, cache_prompt off, top_k logprobs 10
near_tie=0.1 nat  retention=0.5  threads=2
witness=differs (the harness reads the original identity line); margin_robustness unset, since the re-registered rule leaves the one flip undecided
```

## Why this run exists

`holdout-12.tsv` is spent. `../margin-holdout-20260903T0456Z/inputs.tsv` names it by
digest `1b784918...` and sent all twelve prompts to both binaries, and
`../margin-contract-design.md` states that the re-registered identity line is judged
by "a fresh holdout of twelve prompts no run has sent". `holdout-12b.tsv` carries the
same twelve kinds at different operands, moduli, bit widths, string contents, and step
orders. Its digest was committed ahead of the run, so the set cannot be fitted to its
own answer.

## Result

| prompt | ids | positions read | unread | near ties | min control margin | min retention | max truncated TV | max logprob delta | verdict |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| binary-counter | held | 512 | 0 | 20 | 0.0073 | 0.884 | 0.0123 | 0.0209 | held |
| bracket-matching | flips at 2 | - | - | - | - | - | - | - | near-tie flip |
| bubble-sort | held | 512 | 0 | 4 | 0.0402 | 0.933 | 0.0112 | 0.0166 | held |
| gcd-trace | held | 504 | 8 | 0 | 0.2137 | 0.917 | 0.0153 | 0.0270 | held |
| grid-walk | held | 512 | 0 | 16 | 0.0334 | 0.925 | 0.0122 | 0.0175 | held |
| inventory-ledger | held | 512 | 0 | 4 | 0.0573 | 0.965 | 0.0134 | 0.0175 | held |
| matrix-rotate | held | 512 | 0 | 12 | 0.0542 | 0.875 | 0.0080 | 0.0214 | held |
| modular-counter | held | 508 | 4 | 8 | 0.0075 | 0.901 | 0.0064 | 0.0114 | held |
| queue | held | 512 | 0 | 12 | 0.0004 | 0.918 | 0.0130 | 0.0170 | held |
| run-length | held | 512 | 0 | 8 | 0.0351 | 0.945 | 0.0107 | 0.0247 | held |
| substitution-cipher | held | 512 | 0 | 4 | 0.0734 | 0.946 | 0.0331 | 0.0476 | held |
| temperature-log | held | 512 | 0 | 20 | 0.0234 | 0.933 | 0.0093 | 0.0239 | held |

Eleven prompts keep the control's whole token array over 512 read positions each, keep
a positive candidate margin at every one of them, and never fall below half a control
margin that reaches 0.1 nat: `retention_failures` and `nonpositive_candidate_margins`
are 0 on every row, and the smallest retention is 0.875 on matrix-rotate. The largest
selected log-probability movement is 0.0476 nat on substitution-cipher, twice the
discovery run's 0.024 and near the first holdout's 0.047.

The eight unread positions on gcd-trace and the four on modular-counter are entries the
server withheld as incomplete UTF-8, admitted by the following entry carrying the
multi-byte sequence: both prompts write division signs inside their traces, which is the
content-driven mechanism the coverage line states in place of a cap.

## The one flip, and what a 0.0085 nat tie decides

| | winner | runner-up | the winner's own margin |
| --- | --- | --- | ---: |
| control | 198 at -0.691068769 | 271 at -0.699598372 | 0.008530 |
| candidate | 271 at -0.692720830 | 198 at -0.697880328 | 0.005159 |

Both binaries agree on the top ten ids and their order below the first two. E4 moves
token 198 by 0.006812 nat and token 271 by 0.006878, and the gap it had to cross was
0.008530, so a perturbation of the size the discovery run already measured reversed a
pair that was already within it.

Neither 0.005159 above is the contract's `m1`. The rule fixes `w` as the control's
selected token and reads `m1 = lp1(w) - max(lp1(j) for j != w)`, so `w` is 198 here and

```text
m1 = -0.697880328 - (-0.692720830) = -0.005159 nat
```

The contract's `m1` is negative at this position, and it is negative at every flip by
construction: a flip is exactly the event that the control's winner stops winning, so
`m1 <= 0` and "the candidate argmax changed" name one occurrence rather than two. The
right-hand column above is each binary's own winner over its own runner-up, which is a
different quantity from `m1` wherever the two winners differ.

## The re-registered rule does not decide this position, and that is the second finding

The control margin is 0.008530 nat, twelve times below the 0.1 nat near-tie threshold,
so the re-registered identity line tolerates this flip: identity is required at every
position whose control margin reaches 0.1 nat, and no such position moved. That line
alone reads the run as holding.

The same re-registration ends with `everything else: unchanged`, and everything else
includes `m1 > 0` at every read position. The two lines disagree here. The identity line
tolerates a sub-threshold flip and says the flip "ends identity reading for that
sample"; the margin line, unchanged, forbids the `m1 <= 0` that every flip produces.
Whether the tolerated flip's own position remains a read position is what the rule never
states.

This run therefore records two readings and adopts neither:

```text
reading A  the flip ends the sample at position 2, so no margin line applies there;
           eleven prompts hold every line and the twelfth is a counted near-tie flip
reading B  position 2 is read, m1 = -0.005159, and the registered falsifier
           "any position with m1 <= 0" is met, so the run is refuted
```

The defect is in the rule rather than in this run. The re-registration introduced a
tolerated flip class in one line and kept a margin line the tolerated event always
violates, and the first holdout could not expose it because that run was explicitly not
re-read under the re-registered rule. The disambiguation belongs in
`../margin-contract-design.md` ahead of the next holdout and is written there rather than
chosen here, because a run that picks its own reading after seeing its own answer is the
fitting this contract's holdout discipline exists to prevent.

The eleven other prompts are untouched by the ambiguity. None of them flips, so `m1` is
the control winner's own margin at all 5620 of their read positions and it is positive at
every one.

The consequence of the tie is larger than the tie. Position 2 follows `<think>`, and the
two candidates are a single newline against a double newline:

```text
control    "\n\n<think>\nThe problem asks to validate a bracket string character by character using a stack."
candidate  "\n\n<think>\n\n</think>\n\n# Balanced Parentheses Checker with Stack"
```

The control enters a reasoning span and the candidate closes an empty one and answers
directly. A greedy decode diverges for the rest of the reply from any flip, which the
first holdout already recorded; what this position adds is that the divergence can be a
whole behavioral mode rather than a phrasing, because this checkpoint's template puts a
thinking boundary two tokens into every reply and the two continuations there sit
0.0085 nat apart. The graded suite judges the continuation, and
`../quality-gate-20260903T0547Z/` measured the same 40 of 65 on four arms with 64 of 65
replies byte-identical.

## Reading against the registered rule

```text
deterministic                 held: 48 samples per binary, every sample of a prompt bit-identical on ids and top-10 lists
argmax_identity               held: no flip at any position whose control margin reaches 0.1 nat
near_tie_flips                1 of 12 prompts, control margin 0.008530, contract m1 -0.005159, top-10 order otherwise identical
candidate_margin              held on the 5620 read positions of the eleven prompts that hold identity;
                              undecided at the flip, where m1 is -0.005159 and the rule does not say
                              whether that position is read
margin_retention              held on 11 of 12 prompts, minimum 0.875; the twelfth states no ratio
coverage                      12 withheld positions, all admitted by the following multi-byte entry
numerical_identity            refuted, as the first holdout already recorded
quality_nonregression         held: ../quality-gate-20260903T0547Z/
margin_robustness             unset: the rule's two lines disagree at the one flip, and the
                              disambiguation is registered in ../margin-contract-design.md
                              ahead of the holdout that will decide it
```

The harness prints `witness=differs` and exits nonzero because its own verdict comes
from the original identity line, which requires agreement at every position. That
nonzero exit is the registered rule answering rather than the run failing. The
re-registered rule is applied here over the retained records rather than inside the
harness, which is what keeps the measurement head and the analysis head separate and is
what let this reading find the rule's own gap without touching a retained byte.

## What did not run

The pinned clock cell `manual-gfx1100-fclk933` was not applied.
`run-kernel-delta-witness.sh` carries no DPM authority -- it uses `census_arm_exec` for
the closed arm environment alone -- and `power_dpm_force_performance_level` takes a
`sudo` write that had no cached timestamp on the appliance. The machine ran at `auto`
with `pp_dpm_sclk` starred at level 1 and `pp_dpm_mclk` at level 2 (933 MHz) on the idle
reads before and after. The cell bounds nothing this run measures: a token-identity and
decision-margin comparison at temperature 0 reads arithmetic, and a clock moves timing.
The first holdout recorded no clock cell either, so the two runs are comparable on this
axis.

## Files

| file | content |
| --- | --- |
| `margin-summary.tsv` | the reader's verdict rows, one per prompt and comparison |
| `summary.tsv` | the retired log-probability bound's rows, retained for continuity |
| `inputs.tsv`, `prompts.tsv` | binaries, tuple, contract constants, prompt digest, the prompts |
| `arms/*/<prompt>/tokens-run-N.tsv` | id, selected log-probability, and top-10 list per token |
| `arms/*/<prompt>/response-run-N.json` | the replies as the server returned them |
