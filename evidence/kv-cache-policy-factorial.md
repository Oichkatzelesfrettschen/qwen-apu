# What the served KV cache policy costs, and what it buys

`remote/qwen-capacity-policy.sh` serves every checkpoint with `--flash-attn on
--cache-type-k q8_0 --cache-type-v q4_0` while `llama-bench` defaults to an f16
cache with flash attention resolved to `auto`. Comparing a rate from one against
a rate from the other changes four things at once, and
`evidence/model-admission/nanbeige42-3b-admission.md` did exactly that: it
recorded 3.31 tok/s from llama-bench against 3.07 tok/s served and assigned the
7.2% difference to the cache policy. That assignment is the claim this file
tests.

`remote/run-kv-cache-factorial.sh` crosses cache type against flash attention
inside llama-bench alone, so the harness is held fixed and the two mechanisms
separate. `QWEN_CACHE_TYPE_K`, `QWEN_CACHE_TYPE_V`, and `QWEN_FLASH_ATTN` now
override the registry row through `qwen-capacity-policy.sh`, so the served path
runs the same cells and the residual between the two harnesses is measured
rather than absorbed.

## Registered before the run

The five cells are `q8_0/q4_0` with flash attention on and off, `q8_0/f16` with
it off, and `f16/f16` with it on and off. `q8_0/q4_0` with flash attention off
is expected to be refused, which makes the discriminating pairs `f16/f16 fa on`
against `q8_0/q4_0 fa on` for cache traffic with the kernel held, and `f16/f16
fa on` against `f16/f16 fa off` for the kernel with traffic held. `q8_0/f16 fa
off` recovers a quantized-K point outside the flash-attention path.

1. **The cache policy causes the 7.2% gap.** At depth 0 the `f16/f16` cell
   exceeds the `q8_0/q4_0` cell by about 7%. The falsifier is the two agreeing
   within their spread, which assigns the gap to the harness instead and makes
   the Nanbeige file's sentence wrong in the direction it was already softened.

2. **Quantization wins at depth.** At 16384 the `q8_0/q4_0` cell exceeds the
   `f16/f16` cell, because a cache holding 2.4 times fewer bytes is 2.4 times
   less traffic per token and depth is where cache traffic dominates. The
   falsifier is f16 matching or beating it, which would leave the served policy
   justified by capacity alone.

3. **f16 at 16384 completes on the 4B.** It measured 2.69 tok/s there during the
   Nanbeige ladder. A compute-ring timeout at that depth is a result supporting
   the quantized policy rather than a failed run, and the harness counts amdgpu
   ring-reset lines around every cell so a recovered wedge is attributed to the
   arm that caused it.

Depth 0 repeats three times; each deeper rung repeats once, because a rung
reprocesses its whole prefix before every repetition and 16384 tokens of prefill
cost about 12 minutes each. A single-repetition rate carries no spread, and the
summary records the repetition count beside the rate.

## Results

Pending.
