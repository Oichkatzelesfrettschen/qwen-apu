# Checkpoint tail partitioning perturbs the logit field in both representations

Across Q8_0 and F16, checkpoint-enabled tail partitioning produces a
deterministic logit-field perturbation of roughly 0.01 to 0.15 nats. Token
divergence depends on whether the representation-specific trajectory
encounters a local decision margin thinner than the signed perturbation.
That formulation identifies a common execution-shape sensitivity while
leaving open whether the exact per-layer mechanism and magnitude remain
invariant across every representation.

Two matched sweeps at checkpoint counts 0, 2, 2, 0 ran the served launch
chain on the production binary (SHA-256
`40f7b775074e7d207dc2ad12f1aefc9635bd3904d5c35b68c8e43483622c4005`) against
`qwen35-08b` Q8_0 and `qwen35-08b-f16` at a 30725-token prompt, greedy,
`n_probs` 8 in every arm so the sampling path is one path across conditions.
The forced tail partition is `server-context.cpp:3449`,
`checkpoint_offsets[] = {4 + n_ubatch, 4}`. `quantities-q8_0.txt` and
`quantities-f16.txt` hold the extractor output; `extract-prob-quantities.py`
reproduces both from the retained arm JSON.

```text
Q8_0:
    c0 repeat = exact          c2 repeat = exact
    c0 versus c2 = deterministic logit shift, mean 0.0153, max 0.1170 nats
    first token divergence = index 25 (ordinal 26)

F16:
    c0 repeat = exact          c2 repeat = exact
    c0 versus c2 = deterministic logit shift, mean 0.0100, max 0.1449 nats
    token divergence = none in the 32-token witness
```

At Q8_0 index 25 the pairwise margin between `/ph` (85957) and ` (` (318)
moves from +0.0500 nats under c=0 to -0.0773 nats under c=2, a 0.1272-nat
sign-reversing swing over an 8/8 identical candidate set; the flipped pair
contributes at least 0.0192 to total-variation distance, with the
full-vocabulary distance unmeasured. Q8_0's perturbation concentrates at
positions 1-3 and 21-24 with the middle span at or below 1e-4; F16's
concentrates at positions 0-3 (max 0.1449 at position 0) and falls to 1e-3 or
below past position 4, so the two trajectories carry the perturbation in
different position profiles at the same scale. F16 traverses
a different token sequence whose first 32 margins stay wide enough to
preserve every greedy choice while its selected-token log-probabilities move
by the same scale, so the F16 arm shifts the causal center of gravity: the
flip is an execution-shape sensitivity meeting a near-tie rather than a
defect confined to quantized reconstruction.

The comparison windows differ by design. Q8_0 positions 0 through 24 and the
candidate distribution at position 25 share one generated history and admit
direct comparison; later positions condition on different histories and
combine the perturbation with ordinary autoregressive propagation. F16 keeps
all 32 histories identical, so every position admits the direct comparison.

Turn 2 diverged in no arm of either sweep, and every c=2 arm restored its
30748-token turn-2 prefill from a checkpoint in 2.2 to 2.3 s against 693 to
727 s uncheckpointed.

## Scope

The 2B and 4B token-identity findings in `evidence/ctx-checkpoint-sweep/`
establish output identity in their 32-token witnesses, not numerical
identity. They may carry the same hidden logit perturbation while lacking a
sufficiently narrow margin in those continuations; that reading is the
leading inference and stays unmeasured until a probability arm samples them.
Their policy admission stands on its registered witness, and universal
checkpoint invariance stays unproven.

The observed flip is benign in this prose witness, and the same 0.127-nat
margin reversal can change a numeral, JSON delimiter, tool argument, or code
token. The 0.8B serving policy therefore stands: `ctx_checkpoints=0` is the
fidelity baseline and the checkpointed profile is numerically nonidentical
and experimentally available. The finding also explains why checkpointing
usually appears identical and occasionally is not.

## Causal chain and its evidence classes

```text
checkpoint enablement                            set by condition
-> forced {4 + n_ubatch, 4} tail partition       source-supported
-> different floating-point execution ordering   leading hypothesis, unobserved
-> deterministic small logit-field perturbation  measured, both representations
-> a margin thinner than the perturbation flips  measured at Q8_0, absent at F16
-> one greedy token changes                      measured at Q8_0
```

## The decisive causal experiment

A natural-boundary checkpoint variant -- checkpoints placed at ordinary
ubatch boundaries in place of the forced tail partition -- runs as a
two-factor comparison rather than patched c=2 against stock c=0 alone:

```text
stock server:    c=0, c=2
patched server:  c=0, c=2
```

The repair succeeds when patched c=0 matches stock c=0, patched c=2 matches
the c=0 first-turn logit field at retained precision, and patched c=2 still
restores turn 2 from a natural checkpoint. The restored tail may grow from
27 tokens to at most roughly one natural ubatch plus the suffix -- tens of
tokens rather than 30748, preserving essentially the whole 300x-plus
second-turn saving. The outcomes localize the mechanism:

```text
patched c2 matches c0 numerically
    -> the forced tail partition caused the perturbation
patched c2 remains shifted
    -> checkpoint capture or recurrent-state snapshotting changes execution
       beyond the forced tail boundaries
patched c0 differs from stock c0
    -> the patch changed an unrelated path; repair arm invalid
```
