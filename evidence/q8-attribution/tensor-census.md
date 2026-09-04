# The served 0.8B carries no Q4_K row

`remote/gguf-tensor-census.py` against
`~/models/Qwen3.5-0.8B-GGUF/Qwen3.5-0.8B-Q8_0.gguf`
(`sha256=37ae482d336108d23516fa35e8e0c4126688d81018b87178a18d752a1357814f`)
reports `streamed_bytes_per_token=800881920`, which equals the 0.801 GB the
Q8_0 row of `evidence/model-admission/runtime-class-throughput.md` carries, so
this is the file that measurement ran against.

## Bytes and tensors by type

| type | tensor count | bytes | byte share |
| --- | ---: | ---: | ---: |
| Q8_0 | 195 | 820,613,120 | 98.44% |
| F32 | 140 | 2,016,512 | 0.24% |

The remaining bytes are the GGUF header and tensor index (`index_bytes` is
10,962,453 of the file's 833,592,096, header space the census excludes from
`streamed_bytes_per_token`). No Q4_K, Q5_K, Q6_K, or IQ-family tensor exists
in this file: every weight matrix is Q8_0 and every norm, bias, and the
multi-token-prediction head's small tensors are F32. The full report,
including the block-count, architecture-dimension, and provenance fields, is
retained at `evidence/q8-attribution/served-0.8b-q8_0-census.txt`.

## Bytes by operation family

| family | bytes | share |
| --- | ---: | ---: |
| ffn | 280,756,224 | 33.68% |
| embedding | 270,172,160 | 32.41% |
| attention | 207,224,832 | 24.86% |
| gated_deltanet | 42,515,712 | 5.10% |
| mtp | 21,747,712 | 2.61% |
| norm | 212,992 | 0.03% |

`embedding` streams because `embeddings_tied` is `true`: the output
projection is the same tensor as the input embedding and the graph reads it
on every decode step rather than only at the vocabulary lookup. The `mtp`
share is the multi-token-prediction block `CLAUDE.md` records as skipped
under an ordinary load (`load_mtp` false); it appears here because the census
reads the file's tensor index rather than a live load closure, and it stays
out of `streamed_bytes_per_token` for that reason -- the served figure
already matches the measured 0.801 GB, so the exclusion is confirmed rather
than assumed.

## Why every weight byte takes the FP16-dequantize-then-dot path

`evidence/tensor-type-execution-audit.md` reads `ggml-vulkan.cpp:6492`:
`device->integer_dot_product` resolves `false` on this device because RADV
reports every one of `VK_KHR_shader_integer_dot_product`'s thirty
`*Accelerated` bits `false`, so llama.cpp builds no `_q8_1` pipeline for any
type, Q8_0 included. The K-quant audit already covers Q4_K, Q5_K, Q6_K, and
F16; this file is the Q8_0-specific reading of the same gate, over a
checkpoint where Q8_0 is not one rung among several but 98.44% of the bytes.
