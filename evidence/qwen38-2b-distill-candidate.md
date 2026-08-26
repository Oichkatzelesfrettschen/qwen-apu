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

The refutation is informative because of which term fails. Read as pure
streaming of the whole file, 1.21 GiB is 1.299 GB and 9.46 tokens per second
moves 12.29 GB/s against the 11.5 GiB/s asymptote the model's own slope
implies, so the 2B reaches that slope with the fixed per-token term absent and
that term is not a constant of the machine. A two-point fit across two model
sizes attributed depth-dependent overhead to an intercept, and a third point at
a different depth exposes it. Both the fit and its refutation take file size as
a stand-in for per-token traffic, which the next section shows is biased by the
token embedding tensor; correcting for it lowers all three rates and leaves the
refutation standing, because the 2B correction is the largest of the three.

## Effective throughput per file byte varies, and the proxy is biased

Multiplying GGUF size by decode rate gives an effective-throughput proxy rather
than measured DRAM traffic:

| Checkpoint | file bytes | decode tok/s | GB per second of file |
| --- | ---: | ---: | ---: |
| Qwen3.8-2B distill | 1.299 GB | 9.46 | 12.29 |
| Qwen3.8-4B distill | 2.770 GB | 3.07 | 8.50 |
| Qwen3.8-9B distill | 5.766 GB | 1.76 | 10.15 |

The proxy overstates traffic by the token embedding tensor, which decode reads
as a single row lookup of a few kilobytes while the file carries the whole
tensor. The bias is size-dependent, so it distorts the comparison rather than
shifting it. `config.json` gives vocabulary 248,320 across all three
checkpoints against hidden widths of 2048, 2560, and 4096, which makes the
embedding a larger share of the smaller file. Reading the tensor at Q6_K, the
type llama.cpp's Q4_K_M recipe usually assigns it:

| Checkpoint | token_embd | share of file | streamed bytes | GB/s streamed |
| --- | ---: | ---: | ---: | ---: |
| Qwen3.8-2B distill | 0.417 GB | 32.1% | 0.882 GB | 8.34 |
| Qwen3.8-4B distill | 0.521 GB | 18.8% | 2.249 GB | 6.90 |
| Qwen3.8-9B distill | 0.834 GB | 14.5% | 4.932 GB | 8.68 |

The tensor type is estimated rather than read, so the row values are estimated;
`remote/gguf-tensor-census.py` reads the actual assignment and settles them. The
conclusion survives the assumption. At Q4_K the same arithmetic gives 9.58,
7.41, and 9.14 GB/s, so under either type the correction reorders the table:
the 2B and the 9B land within 4% of each other and the 4B alone sits about a
fifth below both. The 45% shortfall in the uncorrected table is mostly the
embedding share of a tied-embedding 1.2 GiB file, and the residual 4B anomaly
is roughly 17 to 19%.

`tie_word_embeddings` is true for the 2B and the 4B and false for the 9B, so
the 9B file carries a separate output tensor that decode does stream. That
distinction is folded into the row above and is the reason the 9B correction is
the smallest of the three.

Sequential host read bandwidth measures 7.97 GB/s on one CPU thread and 15.44
GB/s on two. Those figures measure two Zen+ cores through the load/store path,
which is a different consumer of the same DDR4 controller than the two Vega
compute units, so they bound nothing about the GPU. The physical device ceiling
stays unmeasured until a direct Vulkan buffer-read and Q4_K dequantization
benchmark runs.

Prefill behaves as the compute-bound half should, with both checkpoints near the
arithmetic ceiling of 281.6 GFLOP/s: the 2B reaches 221.7 GFLOP/s at 79% and the
4B 203.3 GFLOP/s at 72%. That ceiling is a heuristic from clock, compute-unit
count, and lane width rather than a measured device bound.

## What is settled and what is open

Settled: the 2B decodes 3.1 times faster than the 4B and prefills 2.4 times
faster, and this appliance serves a Qwen-class checkpoint at 9.46 tok/s.

Open, and the finding worth the next probe: the 4B moves roughly a fifth fewer
streamed bytes per second than either neighbour. The architecture rules out the
first explanation offered for it. `config.json` gives all three checkpoints the
same layer pattern of three linear-attention layers followed by one full
attention layer, so the Gated DeltaNet ratio is uniform and the operator mix in
that sense is constant. The three differ instead in width, in head counts, and
in embedding tying: the 2B runs 24 layers at 2048/6144 with 8 attention heads
and 16 linear value heads, while the 4B and the 9B run 32 layers at 2560/9216
and 4096/12288, both with 16 attention heads and 32 linear value heads. Tensor
shape, quantization mixture, kernel-selection thresholds, fusion, dispatch
structure, and two-compute-unit occupancy remain as candidates, and a
per-operator Vulkan profile of the 4B against the 9B separates them because
those two share layer count, head counts, and layer pattern and differ only in
width.

Untested: quality. Throughput states nothing about whether the 2B answers
correctly, and the five-prompt suite and reasoning-span probe that promoted the
4B over the base have not run against it. A checkpoint that reaches an answer
three times faster and reaches a wrong one is not a candidate.
