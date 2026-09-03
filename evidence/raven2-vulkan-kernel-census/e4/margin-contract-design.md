# The E4 correctness contract: decision margins over a held argmax

```text
status=registered ahead of the holdout run
subject=census+E4 (741a0d76...) against census v7 (addcae10...), both Vulkan0
model=qwen38-2b-distill under its registry tuple
prompts=remote/witness-prompts/holdout-12.tsv, read by no earlier run
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
| coverage | at most two unread positions per sample, the server's own probability-array gap |

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

## Falsifiers

| observation | reading |
| --- | --- |
| any candidate sample diverges in token id | E4 changes a decision; retained as a numeric change, promotion blocked |
| any position with `m1 <= 0` | a tie or reversal E4 introduced |
| any position with `m0 >= 0.1` and `r < 0.5` | E4 erodes a decision by more than half its margin |
| self-repeatability fails on either binary | the witness measured nondeterminism rather than E4; the run is discarded |
| near-tie count grows across position | reported; a longitudinal amplification the discovery run did not see |
| all rows held | `margin_robustness=held` on twelve prompts; the quality gate remains the last pending line |

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
quality_nonregression         pending
```
