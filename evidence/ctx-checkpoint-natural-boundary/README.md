# The natural-boundary patch restores the uncheckpointed numerical path

Removing the forced near-end checkpoint partition restores the ordinary
prefill execution path exactly while retaining natural-boundary checkpoint
restoration. On the 0.8B witness, checkpointed inference becomes
bit-identical to uncheckpointed inference through the recorded probability
surface while reducing the repeated 30748-token prefill to 28 tokens.

`patches/llama-server-natural-checkpoint-boundary.patch` is a local repair
this repository owns. Upstream PR #20288 is provenance for the
`{4 + n_ubatch, 4}` placement mechanism the patch removes, nothing more. The
patch deletes the force-break block in `server-context.cpp`'s batch-fill
loop and changes nothing else; checkpoints then land through the existing
`near_prompt_end` and min-step conditions at natural batch boundaries, so
the fill loop partitions the prompt identically with checkpointing on or
off.

## The two-factor experiment

Four arms ran in one session at the 30720-depth greedy protocol with
`n_probs` 8: stock c=0 and c=2 on the frozen production binary (SHA-256
`40f7b775074e7d207dc2ad12f1aefc9635bd3904d5c35b68c8e43483622c4005`,
verified before the sweep), patched c=2 and c=0 on the candidate
(`binaries.txt` records both digests and the patch digest). One prompt
served every arm.

```text
stock c0 == patched c0 == patched c2    ids and logprobs, bit-identical
stock c0 != stock c2                    index-25 flip, third reproduction

turn-2 prefill    stock c0      693.9 s    30748 tokens charged
                  stock c2        2.22 s      27 tokens charged
                  patched c2      1.58 s      28 tokens charged
                  patched c0    693.9 s    30748 tokens charged
```

`three-way-comparison.txt` retains the extractor output. The patched c=2
restore charges exactly the predicted 28 tokens: the final checkpoint lands
at the natural boundary 30720 of the 30748-token turn-2 prompt. The
registered predictions -- patched c=2 bit-identical to stock c=0, a
28-token recharge, restoration in the low seconds -- all landed, and the
patched restore runs faster than the stock one because the forced 4-token
tail decode is gone.

## Localization, closed

```text
checkpoint capture              numerically neutral
checkpoint restoration          numerically neutral for turn 1
natural checkpoint placement    numerically neutral
forced near-end partition       sole measured source of perturbation
```

The patched c=0 arm closes the validity control: the deletion is inert with
checkpointing disabled. Together with `evidence/ctx-checkpoint-prob-08b/`,
the causal chain's previously unobserved link -- the partition, not the
checkpoint machinery, perturbs the logit field -- is measured by condition.

## Promotion discipline

The patch sits in the candidate series
(`QWEN_LLAMA_CANDIDATE_PATCHES=1 remote/verify-llama-patch-series.sh`
verifies it applies after the workload lease). The frozen production binary
keeps serving until compact per-class validation closes on the 2B and 4B:
patched c0 equal to stock c0, patched c2 equal to patched c0, a
natural-boundary restore, and retained restore performance. The local
checkpoint policy moves all three classes to `ctx_checkpoints=2` only when
all three close.
