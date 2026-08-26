# The 2B distill decodes at 9.46 tok/s and refutes the linear cost model

`empero-ai/Qwen3.8-2B-Distill-GGUF` at revision
`f4f73582d0b149595450c719b9a7521a03894f9c`, Q4_K_M, 1,312,164,224 bytes,
`4aa0fb13c431514262f259d420ecc95a8714df58ac2a2384514e20b93983f0ff`. Full RADV
Vulkan offload, nice 19 with idle I/O, two threads, phases split.

| Checkpoint | weights | prefill tok/s | decode tok/s |
| --- | ---: | ---: | ---: |
| Qwen3.8-2B distill Q4_K_M | 1.21 GiB | 57.15 | 9.46 +/- 0.41 |
| Qwen3.8-4B distill Q4_K_M | 2.58 GiB | 23.48 | 3.07 +/- 0.02 |
| Qwen3.8-9B distill Q4_K_M | 5.37 GiB | 11.47 | 1.76 |

## The prediction failed by a factor of two

Two decode points, the 4B and the 9B, fit a linear cost model of 0.1015 s per
token plus 0.0869 s per GiB of weights. Applied to 1.21 GiB it predicts 4.82
decode tok/s. The measurement is 9.46, so the model is refuted rather than
confirmed, and the deviation is the result.

The refutation is informative because of which term fails. Reading the same
measurement as pure streaming, 1.21 GiB is 1.299 GB and 9.46 tokens per second
moves 12.29 GB/s, which is the asymptotic bandwidth the model's own slope
implies, 1/0.0869 = 11.5 GiB/s. The 2B reaches the streaming rate with the
fixed per-token term absent, so that term is not a constant of the machine. A
two-point fit across two model sizes attributed depth-dependent overhead to an
intercept, and a third point at a different depth exposes it.

## Achieved bandwidth is the thing that varies

| Checkpoint | weights | decode tok/s | achieved GB/s |
| --- | ---: | ---: | ---: |
| Qwen3.8-2B distill | 1.299 GB | 9.46 | 12.29 |
| Qwen3.8-4B distill | 2.770 GB | 3.07 | 8.50 |
| Qwen3.8-9B distill | 5.766 GB | 1.76 | 10.15 |

Sequential host read bandwidth measures 7.97 GB/s on one CPU thread and 15.44
GB/s on two. The 2B reaches 80% of the two-thread figure, so the memory path
sustains 12.29 GB/s on this hardware and that number is measured rather than
derived.

The 4B reaches 69% of what the 2B demonstrates. At 12.29 GB/s a 2.770 GB
checkpoint would decode at 4.44 tok/s, so the 4B is leaving 45% of its decode
rate to something that is neither bandwidth nor arithmetic. The ordering is not
monotonic in size, which rules out a simple per-byte or per-layer explanation:
the 9B recovers to 10.15 GB/s above the 4B's 8.50.

Prefill behaves as the compute-bound half should, with both checkpoints near the
arithmetic ceiling of 281.6 GFLOP/s: the 2B reaches 221.7 GFLOP/s at 79% and the
4B 203.3 GFLOP/s at 72%.

## What is settled and what is open

Settled: the 2B decodes 3.1 times faster than the 4B and prefills 2.4 times
faster, and the memory path sustains 12.29 GB/s.

Open, and the finding worth the next probe: why the 4B achieves 69% of a rate
the same hardware reaches under the 2B. A per-token overhead that scales with
depth is one candidate and the non-monotonic 9B row argues against it. The
hybrid attention and Gated DeltaNet layer ratios differ across these three
checkpoints, which makes the operator mix rather than the parameter count the
next thing to read.

Untested: quality. Throughput states nothing about whether the 2B answers
correctly, and the five-prompt suite and reasoning-span probe that promoted the
4B over the base have not run against it. A checkpoint that reaches an answer
three times faster and reaches a wrong one is not a candidate.
