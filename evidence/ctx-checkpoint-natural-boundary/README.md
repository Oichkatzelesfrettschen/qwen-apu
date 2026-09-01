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

## The 2B and 4B classes, at the same protocol

`2b/` and `4b/` carry the per-class validations at the same 30720-depth
greedy protocol with `n_probs` 8, against the same two binaries
`binaries.txt` names. Each class holds five witnesses: the frozen production
c=0 arm under `witness/`, and the candidate's c=0 opening, c=2 first, c=2
repeat, and c=0 closing arms. Every one of the ten pairs inside a class
agrees bit-for-bit on token ids and retained log-probabilities over both
turns, at 32 recorded positions per turn, and each class's `divergence.txt`
records the same relation as `divergence=none` per arm.

```text
class   turn-2 charge, c=0    turn-2 charge, c=2    restore
2B      30748 tokens          28 tokens            1.96 s and 1.96 s
4B      30748 tokens          28 tokens            6.13 s and 7.99 s
```

The 4B's closing c=0 arm is `4b/patched-arm4b/`, retained separately because
`4b/patched/arm-4-c0/` holds the attempt that preceded it: the sweep
harness's fixed 3600 s `QWEN_CTX_REQUEST_SECONDS` ceiling expired against a
class whose full prefill measures 3251 to 3502 s, so that arm retains a
first-turn request and no tokens and `4b/patched/divergence.txt` reads
`tokens=absent` for it. The re-run raised the ceiling to 10800 s and changed
nothing else. Its model load and first pipeline ran against a warmed RADV
shader and page cache, so its latencies are not a cold-start measurement;
the identity predicate is unaffected, because the charge and the tokens both
come from a request that re-prefills all 30748 tokens after loading.

The five arms of a class span 7.94 to 9.77 prefill tok/s on the 4B and 27.40
to 29.27 on the 2B. Those spans sit inside this machine's own spread and
order nothing; the retained rates state what the arms cost rather than
comparing the settings.

## Promotion discipline

All three classes closed, so the patch is the eighth member of the
production series that `remote/verify-llama-patch-series.sh` replays, pinning
`tools/server/server-context.cpp` at
`3744317beb622feff234e5b7a615c50665579f34ce49921e324bcd418fb3a58a` -- the
source the candidate binary above compiled.

The ledger and the binary are separate release artifacts, so
`remote/ctx-checkpoints.tsv` moving all three classes to `ctx_checkpoints=2`
is guarded by the build rather than by release order.
`remote/build-llama-preset.sh` reads the `checkpoint_offsets` array out of the
source it compiles and records `checkpoint_semantics` as
`natural-boundary-v1` or `forced-tail-v0` in the build's artifact manifest,
and `remote/qwen-capacity-policy.sh` refuses any positive count against a
manifest declaring anything else, an absent declaration included.
