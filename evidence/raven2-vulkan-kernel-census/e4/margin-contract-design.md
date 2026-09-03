# The E4 correctness contract: decision margins over a held argmax

```text
status=registered ahead of the holdout run; run retained in margin-holdout-20260903T0456Z/, verdict differs as registered, identity-line scope re-registered below
subject=census+E4 (741a0d76...) against census v7 (addcae10...), both Vulkan0
model=qwen38-2b-distill under its registry tuple
prompts=remote/witness-prompts/holdout-12.tsv for the first run; remote/witness-prompts/holdout-12b.tsv, read by no run, for the re-registered rule
top_k=10  near_tie=0.1 nat  retention=0.5  runs=2 per start  order=C K K C  tokens=128
reader=remote/summarize-margin-witness.py through run-kernel-delta-witness.sh under QWEN_WITNESS_CONTRACT=margin
```

## What the discovery run established and what it could not

`kernel-delta-witness-20260903T0148Z/` holds the argmax on every one of 768
generated tokens over six state-carrying prompts and moves the selected
token's log-probability by at most 2.4e-2 nat. The bound it was registered
against, 1e-3 nat, is retired:

```text
registered_max_selected_logprob_delta = 1e-3 nat
verdict                              = refuted
reason                               = no calibrated or margin-based reference
```

The retirement carries no replacement figure. A bound of 0.025 chosen because
E4 measured 0.0242 would be the same guess fitted to its own answer. The two
references beside the witness place the movement rather than bound it: two
builds of the same shader source move nothing
(`witness-calibration-20260903T0203Z/`), and the CPU backend moves the argmax
on four of six prompts with log-probabilities up to 0.375
(`witness-cpu-reference-20260903T0220Z/`). The second is context rather than
a threshold, since it shows E4 is far smaller than a backend transition and
says nothing about whether every smaller perturbation is acceptable.

The selected token's log-probability also answers the wrong question. It
states how sure the model was of its choice and nothing about how close the
runner-up came, so a candidate that keeps every argmax while narrowing the
gap to a hair passes an identity check and fails the next prompt.

## The rule

At every generated position, with `w` the control's selected token:

```text
control margin     m0 = lp0(w) - max(lp0(j) for j != w)
candidate margin   m1 = lp1(w) - max(lp1(j) for j != w)
retention          r  = m1 / m0
```

Each margin is a difference of two log-probabilities from one distribution,
so the softmax normalizer cancels and it equals the logit margin. The
server fills `top_logprobs` from the full-vocabulary softmax ahead of the
sampler, so a sampler `top_k` of 1 leaves the list whole, and the reader
requires the list to open on the selected token.

The contract holds when every line below holds on every prompt:

| property | rule |
| --- | --- |
| token id | identical to the control at every position of every candidate sample |
| self-repeatability | ids and top-k lists bit-identical across the two starts and two runs of each binary |
| candidate margin | `m1 > 0` at every read position |
| retention | `r >= 0.5` at every position where `m0 >= 0.1` nat |
| near ties | positions with `m0 < 0.1` nat are counted and their `m1` reported, and a ratio is not read over them |
| coverage | an unread position is a token the server withheld as an incomplete UTF-8 piece, and the reader admits it only when the following entry carries the multi-byte sequence |

The coverage line was first written as "at most two unread positions per
sample" from the discovery run's one gap. The first holdout attempt refused
its third prompt at the reader, ahead of any margin being computed: the
reply wrote `÷` three times and `process_token` in
`tools/server/server-context.cpp` at f280b269 adds a probability entry only
when the generated text ends in complete UTF-8, so the count of withheld
entries follows content. The line above states the mechanism in place of a
cap, and the change touches which positions are read rather than how any
read position is judged.

Reported and deciding nothing: the truncated total variation over the union
of both top-10 lists with the remaining mass as one bucket each, a lower
bound on the distance between the distributions; the largest selected
log-probability movement, for continuity with the retired bound.

The constants are frozen here. The retention fraction 0.5 is a safety
factor over a margin that E4's 2.4e-2 nat maximum movement cannot halve
unless the control margin is already below 0.05 nat, which the near-tie
threshold separates. The near-tie threshold 0.1 nat is where a ratio stops
measuring the candidate and starts measuring the control's own ambiguity.
Both are choices made before any holdout position is read, and the run
README states them beside what was measured rather than adjusting either.

## The holdout

The six discovery prompts are what the contract was written over, so they
are discovery evidence and cannot judge it. `remote/witness-prompts/holdout-12.tsv`
holds twelve state-carrying prompts of the same kind -- a queue, a bubble
sort, three Euclidean traces, a modular counter, bracket matching,
run-length encoding, a binary counter, an inventory ledger, a grid walk,
matrix transformations, a Caesar round trip, and a running-statistics walk --
that no run in this tree has sent to either binary. The witness records the
file's SHA-256 on its `prompts_sha256` line, so the run is bound to the file
as committed:

```text
prompts_sha256=1b784918792edbfcfef38e187020d66b00af99e80ed72d63f49935be01516fdc
```

### The second holdout, for the re-registered rule

`holdout-12.tsv` is spent: `../margin-holdout-20260903T0456Z/inputs.tsv`
names it by that digest, so every one of its twelve prompts has reached both
binaries and the set is discovery evidence for the re-registered rule below.
`remote/witness-prompts/holdout-12b.tsv` is the set that judges that rule:
the same twelve kinds -- a queue, a bubble sort, three Euclidean traces, a
modular counter, bracket matching, run-length encoding, a binary counter, an
inventory ledger, a grid walk, matrix transformations, a Caesar round trip,
and a running-statistics walk -- carrying different operands, moduli, bit
widths, string contents, and step orders, so the kinds are comparable across
the two sets and no operand is shared. The prompt ids repeat the first set's
ids because an id names the kind; the evidence directory separates the runs.

```text
prompts_sha256=09f4f3a8785c9c574cb40cf1e6c92c48fdd2c6efe62504217f3e4c9eac1de4b4
```

The file and this digest are committed ahead of the run that reads them, and
the file is frozen from that commit: an operand changed after a result is
read fits the holdout to its own answer, which is the defect the first
holdout's retired 1e-3 nat bound already carries.

## Falsifiers

| observation | reading |
| --- | --- |
| any candidate sample diverges in token id | E4 changes a decision; retained as a numeric change, promotion blocked |
| any position with `m1 <= 0` | a tie or reversal E4 introduced |
| any position with `m0 >= 0.1` and `r < 0.5` | E4 erodes a decision by more than half its margin |
| self-repeatability fails on either binary | the witness measured nondeterminism rather than E4; the run is discarded |
| near-tie count grows across position | reported; a longitudinal amplification the discovery run did not see |
| all rows held | `margin_robustness=held` on twelve prompts; the quality gate remains the last pending line |

## The holdout result and what it refutes

`../margin-holdout-20260903T0456Z/` reads `differs` as registered: ten
prompts hold every line with a minimum retention of 0.786, and two prompts
flip the argmax at control margins of 0.0001 and 0.0023 nat. Both flips
sit far below the 0.1 nat near-tie threshold, so the identity line
required agreement at a distance the calibration run shows only
same-source builds deliver. The refuted element is the identity line's
scope, and the rule that replaces it is written here ahead of any run that
applies it:

| property | re-registered rule |
| --- | --- |
| token id | identical at every position whose control margin is at or above 0.1 nat |
| near-tie flips | a flip at a control margin below 0.1 nat is reported with both margins and ends identity reading for that sample, since the greedy continuation diverges from there; the count of such flips is the reported quantity and the graded suite judges the continuation |
| everything else | unchanged: exact self-repeatability, positive candidate margin, retention 0.5, coverage by withheld UTF-8 entries |

The holdout run is not re-read under this rule. A fresh holdout of twelve
prompts no run has sent judges it, and a candidate that flips at a margin
at or above the threshold on that set is refuted outright.

## What remains after the holdout

The graded suite is the quality gate: `remote/run-quality-suite.py` against
the candidate and the control inside one sweep, read the way
`evidence/model-admission/roster-quality-sweep.md` reads two checkpoints.
The E4 correctness state until that runs is:

```text
deterministic                 held
argmax_identity_observed      held over 768 discovery tokens
numerical_identity            refuted
margin_robustness             measured by this contract on the holdout
quality_nonregression         held: ../quality-gate-20260903T0547Z/, the same 40 of 65 on four arms, 64 of 65 replies identical
```
