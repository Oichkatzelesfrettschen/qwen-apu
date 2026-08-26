# The embedded MTP head accepts 93% of its drafts and buys 1.2x

`empero-ai/Qwen3.8-4B-Distill` Q4_K_M through the guarded launch path on the
Raven2 laptop, full RADV Vulkan offload, `low-async`, 24576 context, greedy
sampling with `temperature 0`, `top_k 1`, `seed 42`, `cache_prompt false`,
128 predicted tokens per prompt. `remote/run-speculation-matrix.sh` owns every
launch and teardown, so a difference between two rows is a difference between
two speculation settings.

## The head needs no patch and no sidecar

An earlier revision of `evidence/qwen38-distill-tensor-census.md` recorded
whether `draft-mtp` could reach a head embedded in the target GGUF as the
untested question. The pinned source answers it. `common/common.cpp` sets
`mparams.load_mtp` when `params.speculative.types` holds
`COMMON_SPECULATIVE_TYPE_DRAFT_MTP`, which clears the `TENSOR_SKIP` that
`src/models/qwen35.cpp` otherwise applies to the appended block.
`common_speculative_init_result` then takes its `else if (spec_mtp)` branch and
calls `llama_init_from_model(model_tgt, cparams)` with
`cparams.ctx_type = LLAMA_CONTEXT_TYPE_MTP`, so the draft context runs against
the target model and `-md` stays unused. `llama_model::create_memory` filters
that context's KV cache with `il >= hparams.n_layer()`, so the draft cache
holds the one appended block rather than a second trunk.

The server log confirms each step:

```
common_speculative_init_result: creating MTP draft context against the target model
llama_context: n_outputs_max = 2
spec common_specu: adding speculative implementation 'draft-mtp'
spec common_specu: - n_max=1, n_min=0, p_min=0.00, n_embd=2560, backend_sampling=1
```

`n_outputs_max = 2` on the target context is what makes one pass verify the
drafted position together with the bonus position. Without it a draft of N
tokens would decay into N sequential passes and every arm would report no gain
for a plumbing reason.

## Acceptance clears the admission threshold by a wide margin

| arm | prompt | decode tok/s | verification steps | acceptance | mean accepted length |
| --- | --- | ---: | ---: | ---: | ---: |
| S0 | code | 3.09 | - | - | - |
| S0 | prose | 3.10 | - | - | - |
| S0 | arithmetic | 3.09 | - | - | - |
| S1 | code | 3.63 | 67 | 0.896 | 1.90 |
| S1 | prose | 3.70 | 65 | 0.938 | 1.94 |
| S1 | arithmetic | 3.76 | 64 | 0.969 | 1.97 |

The one-token admission threshold was stated before the run: the 4B needs
1.466 times its 3.07 tok/s to reach 4.5, so an idealized one-draft-token
speculation needs acceptance above 0.466, and 0.55 to 0.60 was the plausible
figure once the head's own cost is counted. Measured acceptance is 0.934 across
the three prompts, so the threshold is cleared and the arm is admitted on that
criterion.

Speedup is 1.17 to 1.22 times, not the 1.90 the accepted length implies. The
gap between those two numbers is the finding.

## Decode on this APU is not bandwidth-bound, and the matrix shows where

The target ran 67 passes to produce 128 tokens where the unspeculated arm ran
128. If a two-column pass cost what a one-column pass costs, the whole 1.90
would arrive as wall clock. Splitting each arm's measured time into target and
draft with the per-request `dur(g)` the speculation statistics report:

| quantity | value |
| --- | ---: |
| one-column target pass | 323.4 ms |
| two-column target pass | 463.1 +/- 3.0 ms |
| MTP draft pass | 66.4 +/- 0.3 ms |

Both target passes stream the same 2.698 GB of weights, so the 139.7 ms the
second column adds is arithmetic rather than traffic. That decomposes a
verification pass into a fixed 183 ms and 140 ms per column, and it contradicts
the model the rest of this tree reasons in: at 8.35 GB/s the one-column pass
looks bandwidth-bound, while the second column costs as if the kernel had spare
bandwidth and no spare arithmetic.

The dispatch explanation is refuted by reading the code rather than by running
an arm. `ggml-vulkan.cpp` sets `mul_mat_vec_max_cols = 8` and routes to
`ggml_vk_mul_mat_vec_q_f16` whenever `dst->ne[1] <= mul_mat_vec_max_cols`, so
every arm from N=1 through N=7 stays on the same GEMV kernel and none of them
falls back to the GEMM path. `mul_mat_vec_q4_k.comp` already hoists the
dequantization out of its `NUM_COLS` loop: the sixteen `q4_*` values and the
eight scales are computed once per row and reused. What the loop does per
column is the dot product and the `smin` correction, roughly 31 fused
multiply-adds per 32-element chunk, and that is the work the measurement bills
at 140 ms.

## Prediction, recorded before the deeper arms run

The MTP head drafts sequentially, so an arm at N pays N draft passes and
verifies 1+N columns. Time per verification step is therefore
`323 + 206.4 N` ms. Mean accepted length under a uniform per-position
acceptance of 0.93 is `sum_{k=0}^{N} 0.93^k`, which reproduces the measured
1.90 to 1.97 at N=1.

| arm | predicted step ms | predicted accepted length | predicted decode tok/s |
| --- | ---: | ---: | ---: |
| S2 | 735.8 | 2.80 | 3.81 |
| S3 | 942.2 | 3.60 | 3.82 |
| S4 | 1148.6 | 4.35 | 3.79 |
| S6 | 1561.4 | 5.69 | 3.64 |

Per-position acceptance falls with draft depth, so each row is an upper bound
rather than an estimate. The prediction is that the curve peaks flat near N=2
to N=3 around 3.8 tok/s and declines, and that 4.5 tok/s is unreachable by
drafting deeper against this kernel. The falsifier is any arm above 4.1 tok/s.

## The candidate the decomposition names

`smin` in `mul_mat_vec_q4_k.comp` accumulates sixteen fused multiply-adds per
column, four per `vec4`, each pairing one component of `b` with a scale that is
constant across the four. Factoring it to four horizontal sums and four
multiply-adds removes roughly half the per-column arithmetic, which the
decomposition prices at 70 ms of the 140. Applied to N=2 that predicts 3.81
rising toward 4.2 tok/s. This is a derived candidate rather than a measured
result, and it is stated here so the shader arm has a falsifiable target before
it is written.

## Greedy token identity is unresolved

Two of six comparisons reproduced the unspeculated token sequence exactly and
two diverged, the prose pair at index 1. A speculative decoder must reproduce
the target-only sequence, so a divergence is a correctness defect rather than a
quality trade. The comparison as constructed cannot yet make that call: each
arm is a separate server launch, and a near-tie in the logits flips under any
reordering between two launches. `S0b` repeats the unspeculated arm with
identical settings to measure whether the target alone reproduces itself across
a reload. Until that control reports, the divergence is unexplained rather than
attributed.
