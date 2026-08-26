# What the three distill checkpoints actually contain

`remote/gguf-tensor-census.py` reads the GGUF index directly and reports the
tensor mixture rather than the quantization label. Run on the appliance at
`nice 19` with idle I/O against the three `empero-ai` Q4_K_M distills. The
figures below are measured from the files; the previous estimates in
`evidence/qwen38-2b-distill-candidate.md` assumed a Q6_K token embedding for
all three and were wrong in two ways the census settles.

## Every checkpoint ships an unused multi-token-prediction block

All three declare `qwen35.nextn_predict_layers = 1`, and `block_count` counts
it: 25 for the 2B against 24 transformer layers, 33 for the 4B and the 9B
against 32. The extra block holds a complete layer -- `attn_q`, `attn_k`,
`attn_v`, `attn_output`, `ffn_gate`, `ffn_up`, `ffn_down`, their norms -- plus
`nextn.eh_proj`, `nextn.enorm`, `nextn.hnorm`, and `nextn.shared_head_norm`.

`llama_hparams::n_layer_effective` returns `n_layer_all - n_layer_nextn`, so
decode never runs it. The block is a speculative-decoding draft head that the
serving path loads and leaves idle:

| Checkpoint | MTP block | share of file |
| --- | ---: | ---: |
| Qwen3.8-2B distill | 37,767,168 | 2.88% |
| Qwen3.8-4B distill | 74,641,408 | 2.68% |
| Qwen3.8-9B distill | 150,980,608 | 2.61% |

`common/speculative.cpp` implements MTP drafting against
`llama_set_embeddings_nextn` and `llama_get_embeddings_nextn_ith`, and
`--spec-type` selects a draft type on the server, so the mechanism the block
feeds is present in the pinned build. Whether it accepts a head carried inside
the target GGUF rather than a downloaded sidecar is untested; `--mtp` in
`common/arg.cpp` is a download option and belongs to `LLAMA_EXAMPLE_DOWNLOAD`.

## Embedding tying splits the three, and the type assignment was mis-estimated

| Checkpoint | tied | `token_embd` | `output.weight` |
| --- | --- | ---: | ---: |
| Qwen3.8-2B distill | yes | 417,177,600 Q6_K | absent |
| Qwen3.8-4B distill | yes | 521,472,000 Q6_K | absent |
| Qwen3.8-9B distill | no | 572,129,280 Q4_K | 834,355,200 Q6_K |

The 9B's `token_embd` is Q4_K rather than the Q6_K the estimate assumed, so the
tensor decode skips is 572 MB and not 834 MB. Its `output.weight` is Q6_K and
decode streams all of it. The tied checkpoints carry one tensor that serves the
lookup and the logit projection together, and the projection reads it in full
every step.

## Streamed bytes per token, measured

Per-token traffic is the file minus the tensors decode does not read: the MTP
block in every case, and `token_embd` where an untied `output.weight` exists.

| Checkpoint | layers | file | streamed | decode tok/s | GB/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Qwen3.8-2B distill | 24 | 1.312 GB | 1.263 GB | 9.46 | 11.95 |
| Qwen3.8-4B distill | 32 | 2.783 GB | 2.698 GB | 3.07 | 8.28 |
| Qwen3.8-9B distill | 32 | 5.780 GB | 5.046 GB | 1.76 | 8.88 |

The two 32-layer checkpoints agree to 6.7% across a 1.9-fold span in streamed
bytes, and the 2B runs 34.6% above the 9B and 44.3% above the 4B.

The 2B result is not an overhead difference, and the arithmetic that shows it
needs no model. Fitting per-layer and per-byte terms to the two 32-layer points
gives 9.69 GB/s and 1.474 ms per layer. The 2B's entire per-token budget is
105.7 ms, while streaming its 1.263 GB at 9.69 GB/s would take 130.4 ms before
any per-layer cost at all. The 2B therefore streams strictly faster than the
rate the 32-layer pair sustains, and no reduction in fixed overhead can produce
that. The fitted model predicts 6.03 tok/s against 9.46 measured, which is the
second cost model this checkpoint refutes.

## The quantization mixture argues against itself

| Checkpoint | Q4_K | Q6_K | F32 |
| --- | ---: | ---: | ---: |
| Qwen3.8-2B distill | 48.91% | 50.08% | 0.17% |
| Qwen3.8-4B distill | 61.11% | 38.36% | 0.14% |
| Qwen3.8-9B distill | 67.15% | 32.59% | 0.07% |

The fastest checkpoint carries the largest Q6_K share. If K-quant kernel choice
were the mechanism, the ordering would run the other way, so the mixture does
not explain the 2B unless Q6_K is cheaper per byte than Q4_K on this device --
which is a testable claim rather than a conclusion, and one the operator
profile answers.

Q6_K concentrates in specific tensors rather than spreading evenly. In the 2B a
Gated DeltaNet layer carries `attn_qkv` and `ffn_down` at Q6_K with the rest at
Q4_K, while a full-attention layer is Q4_K throughout.

## The layer pattern is a fused projection, not two attention kinds

The census names disambiguate a structure `config.json` states only in the
abstract. A Gated DeltaNet layer carries `attn_qkv` fused with `ssm_a`,
`ssm_alpha`, `ssm_beta`, `ssm_conv1d`, `ssm_dt`, `ssm_norm`, and `ssm_out`. A
full-attention layer carries separate `attn_q`, `attn_k`, `attn_v`,
`attn_output` with `attn_q_norm` and `attn_k_norm`, and no `ssm` tensors. Both
kinds carry `attn_gate`, a square hidden-by-hidden projection, and both carry
`attn_norm` and `post_attention_norm`.

The three-to-one repetition holds in the files: blocks 0, 1, 2 are Gated
DeltaNet and block 3 is full attention, and the cycle repeats to the MTP block,
which is full attention.

## Open

The 2B streams faster than the 32-layer pair, and neither depth, nor width, nor
quantization mixture accounts for it on the evidence here. The profile that
separates the remaining candidates is the 2B against the 4B, with the 4B
against the 9B as the control that already rules width out.

`remote/hash-load-closure.sh` and this census both read what exists rather than
what a label implies, and the raw output is retained at
`evidence/model-admission/qwen38-distill-tensor-census.txt`.
