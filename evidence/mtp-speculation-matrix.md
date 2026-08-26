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
on accepted length rather than an estimate. The prediction is that the curve
peaks flat near N=2 to N=3 around 3.8 tok/s and declines, and that 4.5 tok/s is
unreachable by drafting deeper against this kernel.

The linear column term is a two-point fit, which is the extrapolation this tree
has already had refuted twice, and the code names the reason it should break.
`ggml_vk_get_dequantize_mul_mat_vec` indexes
`pipeline_dequant_mul_mat_vec_f16_f32[wg_size][type][num_cols - 1]`, so each
column count is a separately compiled shader, and `FLOAT_TYPE
temp[NUM_COLS][NUM_ROWS]` is per-invocation storage that grows with `NUM_COLS`.
Two Vega compute units hold a fixed register file, so occupancy falls at some
column count and the cost curve is piecewise rather than linear. The falsifier
is therefore two-sided: any arm above 4.1 tok/s refutes the ceiling, and any arm
more than 15% below its predicted rate refutes the linear column term and
locates the knee.

## The candidate the decomposition names

`smin` in `mul_mat_vec_q4_k.comp` is one chain of sixteen dependent fused
multiply-adds per column. Each scale multiplies four components of `b` that the
chain visits separately, so the same value is applied four times in sequence:
`sc2` against the four components of `by10`, `sc3` against `by132`, `sc6`
against `by20`, `sc7` against `by232`. Summing each `vec4` first and then
applying its scale is four independent three-add reductions feeding four
multiply-adds, which is the same sixteen operations rearranged. The arithmetic
volume is unchanged; what changes is the dependency chain, from sixteen deep to
four, and the instruction-level parallelism available to hide it.

That makes the candidate worth measuring and its size unpredicted. A chain that
is latency-bound gains; one that the compiler already reassociates gains
nothing. The measurement is the two-column target pass time against the 463.1 ms
this arm recorded, and the falsification criterion is that it does not move.

## Greedy token identity breaks, and the control rules out the easy explanation

One of three prompts reproduced the unspeculated token sequence exactly; prose
and arithmetic diverged, both at index 1, after which 122 and 121 of 128
positions differ.

The control was run before attributing that. `S0b` repeats the unspeculated arm
in a separate server launch with identical settings, and it reproduces `S0`
token for token on all three prompts at 3.07 to 3.10 tok/s. The target alone is
therefore reproducible across a reload, and the divergence belongs to the
speculative path rather than to launch ordering.

It is a near-tie flip rather than a corruption. Both continuations are fluent,
and both answer the arithmetic prompt correctly with 2 hours 45 minutes; they
differ from the second token onward the way two greedy decodes differ once the
argmax at one low-margin position goes the other way.

The mechanism the code names is pipeline selection.
`ggml_vk_get_dequantize_mul_mat_vec` indexes
`pipeline_dequant_mul_mat_vec_f16_f32[wg_size][type][num_cols - 1]`, so a
one-column pass and a two-column pass run different compiled shaders with
different unrolling and different accumulation order. The speculative arm
evaluates the target on a pipeline the unspeculated arm never uses, and greedy
argmax is not stable across that difference where two logits are close.

Two arms separate that hypothesis from its alternatives, and both are cheap.
`S1b` repeats `S1` unchanged: the same `n_max` selects the same pipeline both
times, so a reproducible divergence is consistent with pipeline selection and a
random one refutes it. `S0c` sets `QWEN_SPEC_DRAFT_N_MAX=0` with `draft-mtp`
still active, which loads the MTP block, creates the draft context, drafts
nothing, and leaves the target verifying one column. If `S0c` reproduces `S0`
exactly, column count is the whole cause and `load_mtp`'s effect on buffer
layout is exonerated; if it diverges, the hypothesis is wrong.

The operational question this raises belongs to whoever sets the criterion. The
stated rule is that speculative decoding must reproduce the target-only token
sequence and that any difference is a correctness defect rather than a quality
trade. Under that rule this arm fails regardless of cause, because the
divergence is measured. The reading that would admit it is that the rule exists
to catch a broken accept-reject test, and what is measured here is instead an
argmax that moves when the same logits are computed by a different shader --
the target's own choice at a low-margin position, not a draft token wrongly
kept. This file records the measurement and the mechanism; which of those two
readings governs the default is a decision, not a finding.
