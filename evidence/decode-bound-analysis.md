# Decode is bound by unpacking cost, not by byte count

The 4B distill decodes at 3.2 tok/s and the interactive target is 4.5. Two
levers were priced before this measurement and both came in far under: the
embedded multi-token-prediction head returns 1.13 to 1.16 at one draft token,
and the served KV cache policy costs 1.9% at depth 0 rather than the 7% it was
credited with. The remaining published lever was byte count, and
`evidence/model-admission/qwen38-4b-low-bit-ladder.md` registered proportional
scaling before the file existed: Q2_K streaming 0.7059 of Q4_K_M's bytes was
predicted to decode at 4.34 tok/s, with a two-sided falsifier at 3.5 and 5.5.

## The measurement

`remote/run-bandwidth-ladder.sh` runs each checkpoint twice, once in each
direction of the model order, and reports achieved streaming rate rather than
tokens alone. Streamed bytes come from `remote/gguf-tensor-census.py`, which
excludes the multi-token-prediction block decode skips and counts a tied
embedding once for the lookup and once for the projection. Every arm ran with
`mclk` at 933 MHz.

| checkpoint | streamed/token | forward | reverse | mean tok/s | mean GB/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Qwen3.8-2B Q4_K_M | 1,263,000,000 | 9.33 | 9.48 | 9.41 | 11.89 |
| Qwen3.8-4B Q4_K_M | 2,697,836,544 | 3.18 | 3.23 | 3.21 | 8.65 |
| Qwen3.8-4B i1-Q2_K | 1,904,502,784 | 3.12 | 3.09 | 3.11 | 5.91 |

Position moves each figure by under 2%, and every checkpoint reproduces in both
directions, so the ordering is not an artefact of when each ran.

## Proportional scaling is falsified

Q2_K carries 29.4% fewer bytes per token and decodes 3.1% slower: 3.11 against
3.21, measured back to back. The registered falsifier was a rate below 3.5 and
the measurement is 3.11. Achieved streaming fell from 8.65 GB/s to 5.91, a 31.7%
drop that cancels the byte saving almost exactly.

**The low-bit route to 4.5 tok/s is closed for Q2_K.** Fewer bits do not convert
to more tokens on this device, and the reason is what the bytes are spent on
rather than how many there are.

## Achieved streaming orders by quantization layout

| checkpoint | Q6_K share | Q4_K share | Q3_K share | Q2_K share | achieved GB/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Qwen3.8-2B Q4_K_M | 50.08% | 48.91% | - | - | 11.89 |
| Qwen3.8-4B Q4_K_M | 38.36% | 61.11% | - | - | 8.65 |
| Qwen3.8-4B i1-Q2_K | 26.62% | 15.13% | 19.15% | 38.35% | 5.91 |

The ordering is monotonic in Q6_K share and inverse to the share of formats
below Q4_K. Q6_K stores six bits against a single per-block scale; Q4_K carries
hierarchical super-block scales that each weight's reconstruction depends on;
Q2_K and Q3_K add further indirection per weight. The device is waiting on the
arithmetic that reconstructs weights rather than on the memory that delivers
them.

`evidence/qwen38-distill-tensor-census.md` raised this as a possibility and
declined to conclude it: "the mixture does not explain the 2B unless Q6_K is
cheaper per byte than Q4_K on this device -- which is a testable claim rather
than a conclusion." The Q2_K point tests it by extending the series downward,
and the claim holds across a 2.0-fold span in achieved rate.

## What the two ceilings say

Neither the memory system nor the arithmetic units are saturated during decode.

| | prefill, pp512 | decode, tg64 |
| --- | ---: | ---: |
| arithmetic | 203 GFLOP/s | 26.6 GFLOP/s |
| share of the 281.6 GFLOP/s fp32 peak | 72% | 9.4% |
| achieved streaming | 0.12 GB/s | 8.65 GB/s |

Peak is two active compute units -- `dmesg` reports `SE 1, SH per SE 1, CU per
SH 3, active_cu_number 2`, so the third is harvested -- at 64 lanes, two flops
per lane, 1100 MHz. Prefill reuses each weight across the whole ubatch and runs
near the arithmetic ceiling. Decode reads each weight once per token and reaches
neither ceiling, which is the signature of work that waits rather than work that
saturates.

The unpacking cost is not visible in the fp32 flop count because it is integer
shift, mask, and scale arithmetic rather than multiply-add. It occupies the same
lanes and it is what the 9.4% figure leaves out.

The iGPU reaches memory through the Data Fabric rather than the load/store path
the host bandwidth figure measures, and its ceiling stays unmeasured. What
bounds it from below is this table: the device sustains 11.89 GB/s on the 2B, so
8.65 on the 4B is not a device limit.

## Registered before the larger quants run

If unpacking cost dominates, a checkpoint carrying more bytes in a cheaper
layout decodes faster. `remote/download-qwen38-4b-distill-i1-q6k.sh` pins Q6_K
at 3,563,028,992 bytes, 28% above the served Q4_K_M, and
`remote/download-qwen38-4b-distill-i1-q5km.sh` pins Q5_K_M between them.

Byte count predicts Q6_K decodes at about 2.5 tok/s, slower than the served
checkpoint. Unpacking cost predicts it approaches the rate the 2B demonstrates
for a Q6_K-heavy mixture and lands near 3.5 tok/s, faster than the served
checkpoint and at higher fidelity. The two differ by about 40% and do not
overlap, so the arm decides between them rather than weighing them.

The falsifier for the unpacking-cost account is a Q6_K achieved rate at or below
Q4_K_M's 8.65 GB/s. That would mean layout stops paying above Q4_K and the
series measured here is driven by the low end alone.

Q5_K_M carries the same super-block structure as Q4_K with wider weights, so a
smooth curve through it supports a per-format cost and a knee between Q5_K_M and
Q6_K supports a cost specific to how many levels of scale a format carries.
