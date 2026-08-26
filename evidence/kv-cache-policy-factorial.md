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

## The 16384 cell wedged the ring under the served cache triple

`d16384-kq8_0-vq4_0-faon` aborted with `vk::Queue::submit: ErrorDeviceLost`
after RADV reported `The CS has been cancelled because the context is lost`.
The kernel reset `comp_1.3.0` and the device recovered; the following cells ran.
Unlike the Nanbeige wedge, the driver produced a coredump, and it names more
than a timeout:

```
Ring timed out details
IP Type: 1 Ring Name: comp_1.3.0

[gfxhub] Page fault observed
Faulty page starting at address: 0x0000000000000000
Protection fault status register: 0x0
```

`evidence/model-admission/amdgpu-coredump-d16384-served-cache.txt` retains the
fault report and the graphics IP register dump. The gfxhub page fault is
reported with a zero faulty address and a zero protection-fault status, and
`mmGDS_PROTECTION_FAULT` and `mmGDS_VM_PROTECTION_FAULT` read 0x0fc00007 and
0x0fc00113. Whether the zero address is a null access or an uncaptured field is
not decidable from this dump, so the recorded fact is that the driver reported a
page fault rather than a duration alone.

**The depth and the submission size are confounded, and this is the decisive
open question.** llama-bench prefills a depth rung at its own batch defaults
while `qwen-capacity-policy.sh` serves with `--batch-size 128 --ubatch-size 32`,
which is two orders of magnitude smaller per submission and is the reason those
settings exist. Both wedges this tree has recorded were found under llama-bench
at its defaults, at 16384 tokens, and neither has been separated from the other.
`remote/probe-depth-wedge.sh` repeats the wedge at the harness defaults and then
at the served batch settings with everything else held. A completion at the
served batch attributes the wedge to submission size and leaves the served depth
ceiling standing. A wedge at the served batch attributes it to the depth and
puts the 24576 interactive default for this checkpoint in question, which is the
outcome that changes a shipped default rather than a measurement method.

Until that runs, the registry keeps its ceilings: the wedge is established under
llama-bench and unestablished under the served path, and lowering a ceiling on a
harness artifact would be the same error as raising one on scaled arithmetic.

## Results

Pending the 16384 block.
