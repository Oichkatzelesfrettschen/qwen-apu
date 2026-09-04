# More than one token column per weight traversal on the 4B

The 4B distill serves 3.352 tok/s against a 5.25 tok/s target, a factor of
1.5663. `evidence/decode-bound-analysis.md` closes the byte-reduction route on
the measured K-quant ladder and `evidence/throughput-target-analysis/README.md` prices
a `31/19` local kernel speedup at 110.2222% ownership of the token, which is
outside one. What remains is temporal amortization: emit more than one token
per traversal of the weights, so the same 2.698 GB of streamed bytes carries
more output.

This directory registers the design, the arithmetic, and the falsifiers before
the device runs any arm. Every input is a figure this tree already holds, and
each one carries its evidence class below.

## The denominator, stated three ways

| Surface | 4B decode tok/s | Evidence class |
| --- | ---: | --- |
| Fixed-64 served campaign, four-arm mean | 3.352 | measured, `evidence/fixed64-served-campaign/README.md` |
| Bandwidth four-block reported mean | 3.01 | reported, `evidence/decode-bound-analysis.md` |
| MTP matrix unspeculated control | 3.09 to 3.10 | reported, `evidence/mtp-speculation-matrix.md` |

Those three differ by 11.4%, which is inside the 30.6% span this machine
carries on one checkpoint under identical flags across sweeps. A comparison on
this machine is therefore read inside a sweep, and
`remote/summarize-speculation-breakeven.py` reads its control rate from the run
directory rather than from any constant here. The table below uses 3.096 tok/s,
the reciprocal of the matrix's own 323 ms one-column pass, because the same
document supplies every column cost the arithmetic rests on; a break-even
quoted against a different denominator moves with it and the calculator states
the one it used.

## The cost model, and what each term is measured by

A speculative round drafts, verifies, and emits. With draft length `N`,
acceptance `a`, per-drafted-token draft cost `d`, and a verification pass over
`N + 1` columns costing `v(N+1)`:

```text
emitted per round = 1 + sum_{k=1..N} a^k
round time        = N * d + v(N+1)
rate              = (1 + sum_{k=1..N} a^k) / (N * d + v(N+1))
```

The bonus token is unconditional: `common_sampler_sample_and_accept_n` in
`common/sampling.cpp` walks the draft position by position, breaks at the first
mismatch, and samples one target token from the surviving position, so a round
that accepts nothing still emits one token and the geometric series starts at
1. The `sum a^k` form assumes a position-independent acceptance; the matrix
measures the real decay running ahead of that assumption at N=4 and N=6, where
tokens per target step reached 4.16 and 5.41 against a uniform-`a` prediction
of 4.35 and 5.69.

`v(k)` is measured. `evidence/mtp-speculation-matrix.md` decomposes each arm's
wall time by subtracting the draft time the speculation statistics report:

| columns | verification pass ms | ms per column |
| ---: | ---: | ---: |
| 1 | 323.0 | 323.0 |
| 2 | 463.1 | 231.6 |
| 3 | 662.0 | 220.7 |
| 4 | 783.0 | 195.8 |
| 5 | 1319.0 | 263.8 |
| 7 | 1636.0 | 233.7 |

Amortization works, and it works less than a bandwidth model predicts. Both a
one-column and a two-column pass stream the same 2.698 GB, so the 139.7 ms the
second column adds is arithmetic on a pass that looked bandwidth-bound. The
per-column cost falls from 323.0 to 195.8 ms across four columns, a factor of
1.65, and then steps at the fifth: `mul_mat_vec_q4_k.comp` declares
`FLOAT_TYPE temp[NUM_COLS][NUM_ROWS]` per invocation against a fixed
256-register file, and Vega occupancy falls in integer steps. Four columns is
the last point inside the measured flat region, so this design admits
`N` in {1, 2, 3} and nothing deeper.

`d` differs per mechanism and both values are measured elsewhere in this tree.

## The three mechanisms available at f280b269

### `--spec-type draft-mtp`, the distill's own prediction block

`common/common.cpp` sets `mparams.load_mtp` where `params.speculative.types`
holds `COMMON_SPECULATIVE_TYPE_DRAFT_MTP`, which clears the `TENSOR_SKIP` that
`src/models/qwen35.cpp:42` otherwise applies through
`int mtp_flags = !ml.load_mtp ? TENSOR_SKIP : 0;`. The initializer in
`common/speculative.cpp` then takes its `!has_draft && spec_mtp` branch and
calls `llama_init_from_model(model_tgt, cparams)` with
`cparams.ctx_type = LLAMA_CONTEXT_TYPE_MTP`, so one checkpoint stays resident
and `llama_model::create_memory` filters that context's cache to
`il >= hparams.n_layer()`, the one appended block.

Resident cost: `evidence/model-admission/qwen38-distill-tensor-census.txt`
reports the 4B distill at `block_count 33`, `nextn_predict_layers 1`, and
`mtp_bytes 74641408`, so the block adds 71.18 MiB of weights, 2.68% of the
file. Its cache holds one block; the 4B's own cache measures 416.00 MiB at
32768 over 32 effective layers, which is 416 bytes per layer per token under
the row's `q8_0`/`q4_0` triple, so one block at 24576 is 9.75 MiB. The
mechanism costs about 81 MiB beside a served baseline that already allocates
2572.86 MiB of weights and 312.00 MiB of cache.

Per-token draft cost: 66.4 ms, derived twice and agreeing to 1.6%. The `dur(g)`
decomposition of the S1 arms priced it at 66.4 +/- 0.3 ms, and the `R1` arm at
`p_min 1.0` -- which runs the head to produce a confidence the floor then
rejects, discarding the result -- measured 2.53 to 2.55 tok/s against 3.08 to
3.09, which is 67.5 ms of pure loss per token.

### `--spec-type draft-simple`, the 0.8B in front of the 4B

`remote/draft-pairs.tsv` carries `qwen38-4b-distill+qwen35-08b-draft` at
`candidate` with `spec_draft_n_max 2`, `spec_draft_p_min 0.00`, and a
`q8_0`/`q4_0` draft cache. `common_base_params_to_speculative` in
`common/speculative.cpp` copies the draft's `devices`, `mparams`,
`n_gpu_layers`, and `tensor_buft_overrides` over the target's and sets the
draft cache types unconditionally, and the initializer assigns
`cparams.n_ctx = llama_n_ctx(ctx_tgt)`, so the draft context is 24576 whatever
the draft row's own `context_default` says.

Resident cost: the 0.8B Q8_0 loads 763.78 MiB of weights, measured on the
appliance's own server log, and its 24 blocks at 416 bytes per layer per token
give 234.00 MiB of cache at 24576 -- the same arithmetic that reproduces the
78.00 MiB the appliance measured at 8192. The pairing therefore adds 997.78
MiB, 12.3 times what the embedded head costs.

Per-token draft cost: the 0.8B's own served token time, 54.77 ms at the
fixed-64 campaign's 18.257 tok/s and 53.9 ms at the registry's 18.53. The
figure is a floor rather than the round's whole draft term. The draft loop in
`common_speculative_impl_draft_simple::draft()` decodes the accepted run before
it samples, so a round costs one catch-up decode beyond its `N` sampling
decodes; that catch-up is unmeasured, and the harness measures round time
directly rather than reconstructing it from `d`.

### N-gram self-speculation, closed on measurement

The pinned tree carries five n-gram mechanisms -- `ngram-simple`, `ngram-map-k`,
`ngram-map-k4v`, `ngram-mod`, `ngram-cache` -- and
`common_speculative_init` instantiates each into the same `common_speculative`
object `tools/server/server-context.cpp` drives, so the server reaches them
with no draft model and no extra resident bytes.

The lane is closed by measurement rather than by absence. On the chat suite
`ngram-simple` measured 3.00, 3.07, and 2.92 tok/s against controls of 3.09,
3.10, and 3.10, with acceptance 0.350 and 0.208 where it drafted at all: the
drafts it generates are rejected often enough that verifying them costs more
than decoding directly. Its 4.57 and 5.47 tok/s on the retired bare-prefix
suite tracked the repeated-eight-gram fraction and nothing else, at 68% and
46% repetition against 2% on code where it drafted nothing at all.

The lane also has no depth knob to sweep. `--spec-draft-n-max` sets
`params.speculative.draft.n_max`, which the draft-model speculators read, while
`ngram-simple` reads `params.speculative.ngram_simple` and is configured by
`--spec-ngram-simple-size-n`, `-size-m`, and `-min-hits`. The matrix's N1, N2,
and N3 arms were three runs of one configuration and their agreement measured
reproducibility. This design keeps n-gram off the device sequence for that
reason: re-closing a closed lane with the wrong flag spends device time to
learn nothing.

## The break-even table

Break-even acceptance is the `a` at which the mechanism's rate equals the
unspeculated control. The target acceptance is the `a` at which it reaches
5.25 tok/s. Both solve the rate equation at the measured `v(N+1)` against a
control of 3.096 tok/s.

| Mechanism | N | round ms | ceiling at a=1 | break-even a | a for 5.25 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `draft-mtp`, d=66.4 ms | 1 | 529.5 | 3.777 | 0.639 | 1.780 |
| `draft-mtp` | 2 | 794.8 | 3.775 | 0.808 | 1.350 |
| `draft-mtp` | 3 | 982.2 | 4.072 | 0.819 | 1.172 |
| `draft-simple`, d=55.0 ms | 1 | 518.1 | 3.860 | 0.604 | 1.720 |
| `draft-simple` | 2 | 772.0 | 3.886 | 0.781 | 1.317 |
| `draft-simple` | 3 | 948.0 | 4.219 | 0.796 | 1.148 |
| free draft, d=0 | 1 | 463.1 | 4.319 | 0.434 | 1.431 |
| free draft | 2 | 662.0 | 4.532 | 0.640 | 1.151 |
| free draft | 3 | 783.0 | 5.109 | 0.671 | 1.018 |

Three readings decide the program.

**Temporal amortization alone cannot reach 5.25 at the measured verification
costs.** Every `a for 5.25` column lies outside the physical interval from
zero to one, and the bound holds even against a draft that costs nothing: a
free draft at perfect acceptance reaches 5.109 tok/s at N=3, 2.7% short. The
N=1 row reproduces the figure `evidence/throughput-target-analysis/README.md` already
registers -- 3.777 at perfect acceptance, 4.319 with a free draft, required
acceptance 1.7799 -- which is what makes this table a generalization of that
result rather than a second one.

**Both mechanisms clear break-even at the acceptance already measured.** The
chat-suite acceptance of 0.846 exceeds the 0.639 break-even at N=1, which is
the 1.13 to 1.16 times the matrix reports. It also exceeds the 0.808 at N=2 and
falls 2.7 points short of the 0.819 at N=3 under a uniform-`a` assumption the
matrix already measures running optimistic at depth.

**The pair ledger's acceptance floor is a comparison policy and not a
break-even.** `remote/draft-pairs.tsv` carries `acceptance_floor 0.896`, the
worst prompt the embedded head reached, and its own comment says so. The
calculated break-even for the 4B pair is 0.604 at N=1, so a standalone draft
between 0.604 and 0.896 speeds the target up while failing the ledger's
comparison gate. The harness records both, and the tier decision reads both.

**A cheaper draft pass is worth less than a cheaper verification pass.**
Replacing the 66.4 ms head with the 55.0 ms 0.8B moves the N=1 break-even from
0.639 to 0.604, worth about 2.2% of rate at fixed acceptance, and it costs 997.78
MiB of residency against 81 MiB. The lever with the range is `v`.

## What the combined program needs

Holding acceptance at the measured 0.846 and solving for the verification pass
that reaches 5.25:

| Mechanism | N | required v(N+1) ms | measured ms | removal |
| --- | ---: | ---: | ---: | ---: |
| `draft-mtp` | 1 | 285.2 | 463.1 | 38.41% |
| `draft-mtp` | 2 | 355.1 | 662.0 | 46.35% |
| `draft-mtp` | 3 | 404.1 | 783.0 | 48.39% |
| `draft-simple` | 1 | 296.6 | 463.1 | 35.95% |
| `draft-simple` | 2 | 377.9 | 662.0 | 42.91% |
| `draft-simple` | 3 | 438.3 | 783.0 | 44.03% |

The demand rises with depth at fixed acceptance while the ceiling at perfect
acceptance also rises with depth. The two orderings cross because acceptance
decays geometrically while the column cost falls only from 231.6 to 195.8 ms:
N=3 is the best point if drafting were free and accurate, and N=1 is the
cheapest point to combine with a kernel change at the acceptance this
checkpoint actually delivers. Which of the two the program funds is what the
measured `a` at each depth decides, and it is the reason this design sweeps
{1, 2, 3} rather than confirming N=1.

## Residency, and the budget that decides it

| Component | MiB | Class |
| --- | ---: | --- |
| 4B distill weights | 2572.86 | measured, appliance server log |
| 4B distill cache at 24576, `q8_0`/`q4_0` | 312.00 | measured, appliance server log |
| 4B distill compute buffer | 10.08 | measured, appliance server log |
| `draft-mtp` block weights | 71.18 | measured, GGUF census `mtp_bytes 74641408` |
| `draft-mtp` block cache at 24576 | 9.75 | derived, 416 bytes per layer per token over one block |
| `draft-simple` 0.8B Q8_0 weights | 763.78 | measured, appliance server log |
| `draft-simple` 0.8B cache at 24576 | 234.00 | derived, from the 78.00 MiB measured at 8192 |

The unspeculated 4B already allocates 2894.94 MiB of Vulkan buffers, above the
2048 MiB VRAM carve-out, and it serves; the heap the carve-out names is
therefore not the budget a launch is admitted against.
`remote/model-memory-preflight.sh` compares the requirement against
`aggregate_available_bytes` from its own Vulkan probe, and the paired image
launch measured `vulkan_budget_headroom=ample surplus_bytes=12261912576` with
two checkpoints and a projector resident. Both mechanisms fit that surplus with
room, and the falsifier is stated rather than assumed: a
`vulkan_budget_headroom=short` line, or a load that fails under the
`LLAMA_NO_CPU_FALLBACK=1` the harness exports, ends the arm before any rate is
recorded.

## Where the counters come from

`server_slot_stats` in `tools/server/server-common.h` accumulates
`n_draft_tokens`, `n_draft_accepted`, and `n_draft_verif_steps`;
`server-context.cpp` adds the drafted length at submission and increments
accepted and step counts after each verification. Three surfaces expose them
and they answer different questions:

- `server_slot_stats::to_json()` in `tools/server/server-common.cpp` adds
  `timings.draft_n` and `timings.draft_n_accepted` to a completion response,
  and only where `n_draft_tokens > 0`. This is the per-request authority and
  the reason a silently unspeculated arm is detectable: an arm carrying no
  `draft_n` drafted nothing.
- `/metrics` under `--metrics` carries the cumulative
  `spec_decode_num_draft_tokens_total`,
  `spec_decode_num_accepted_tokens_total`, and
  `spec_decode_num_drafts_total`. The third is the verification step count,
  which the response timings never carry, so a delta across one request
  measures the step count the summary otherwise infers.
- The `draft acceptance = ... mean len = ...` line the slot prints in
  `print_timings()` is the same three numbers as text.

The step count closes an accounting identity rather than adding a number. Every
round emits one target token beside the drafts it accepts, and the first token
arrives from the prompt logits, so

```text
verification steps = predicted_n - draft_n_accepted - 1
```

exactly. That identity reads the completion body alone, which is why it rather
than the counter is the step-count authority: `server_slot::release()` calls
`callback_on_reset`, where `metrics_on_prediction` folds a slot's draft counters
into the global ones, and `update_slots` calls `send_final_response(slot)`
immediately before `slot.release()`. The response therefore leaves the inference
thread ahead of the fold, so a /metrics read taken once curl returns is
unordered against it and a delta that lags by one request is a property of that
ordering rather than of the measurement.

`remote/measure-mtp-arm.sh` retains the delta anyway and
`remote/summarize-speculation-breakeven.py` reports the comparison on a
`steps_agreement` line over `accepted`, `disagree`, and `absent`. What stays
terminal is every count the response carries on its own: a control reporting
draft counters or moving a speculation counter, a speculative arm reporting
none, an accepted count above its drafted count, and a drafted count above the
configured batch geometry over the steps the tokens imply. A run against a
server holding no /metrics route at all therefore still scores.

## Predictions, registered before the run

1. `draft-simple` measures acceptance below `draft-mtp` at every depth. The
   head is trained on the target's own hidden state and the 0.8B is a
   different model. Falsified by any depth where the pair's weighted
   acceptance meets or exceeds the head's in the same sweep.
2. `draft-simple` measures a shorter round time than `draft-mtp` at equal
   depth, because the 0.8B's 54.77 ms token beats the head's 66.4 ms pass.
   Falsified by a longer measured round time, which would put the draft
   loop's catch-up decode above the 11.6 ms the two draft costs differ by.
3. No arm reaches 5.25 tok/s. Falsified by any arm above it, which would
   refute the measured `v(N+1)` ladder rather than this design.
4. N=1 and N=2 beat their bracketing controls for `draft-mtp` and N=3 does
   not, from acceptance 0.846 against break-evens of 0.639, 0.808, and 0.819.
   Falsified in either direction by an arm on the wrong side of its control.
5. Every speculative arm diverges in emitted token IDs from its controls on at
   least one prompt. `evidence/mtp-speculation-matrix.md` locates that
   divergence at `n_outputs_max > 1` rather than at drafting or accepting:
   `N1b` diverged with zero drafts and `R1` diverged with the drafter silenced
   by `p_min 1.0`. Falsified by a speculative arm reproducing all controls
   exactly, which would put the cause back inside the draft path.

## The gates, and why identity is split in two

The summary reports four independent gates so a rejection on one leaves the
other three readable.

`control_determinism` compares `control-open` against `control-close` for each
prompt. Those two arms differ by nothing but position in the session, so a
difference there is machine nondeterminism and it invalidates the arm rather
than reporting anything about speculation.

`token_identity` compares each speculative arm against the controls. Prediction
5 says it rejects. The stated repository rule is that speculative decoding
reproduces the target-only sequence and that any difference is a correctness
defect; the reading that would admit it is that the rule exists to catch a
broken accept-reject test while what is measured is an argmax moving at a
low-margin position when the same logits are computed under a different
`n_outputs_max`. This design registers the decision rather than the finding:
a rejected `token_identity` withholds a `production` tier and leaves the
`candidate` tier reachable, and the rate and acceptance columns stay valid
because the divergence is measured to be independent of drafting.

`performance` requires each speculative arm to beat both of its bracketing
controls. `acceptance` compares the weighted acceptance against both the pair
ledger's `acceptance_floor` and the calculated break-even the table above
registers.

## The device sequence

The class policy runs the current 2B first, the current 0.8B second, and the
current 4B third, and a result becomes a Raven2-wide default only where the
classes agree. The 2B pairing is also the cheaper measurement: it holds 1.21
GiB of target weights rather than 2.59, and its 9.19 tok/s control finishes a
128-token request in 14 seconds against the 4B's 38.

The 0.8B class carries neither mechanism and runs no arm here. It ships no
prediction block -- `evidence/model-admission/static-admission.tsv` reads
`nextn_layers 0` on every 0.8B row -- and `remote/draft-pairs.tsv` names it only
as a draft, never as a target. Its place in the class order is the 2B pairing's
draft half.

`draft-mtp` needs a checkpoint whose GGUF states `nextn_predict_layers` at one
or more; against a checkpoint without one, `load_mtp` finds no tensors to
unskip, the filtered draft cache is empty, and the harness reports
`draft_absent` after four server loads. The 2B and 4B distills both carry the
block at `block_count` 25 and 33 against 24 and 32 effective layers.

```sh
~/qwen-laptop-setup/remote/qwen-teardown.sh

# 1. The 2B pairing at the ledger's own draft length, through the existing
#    ABBA harness. The class policy puts this first and its admission gate is
#    what moves remote/draft-pairs.tsv. remote/throughput-targets.tsv sets the
#    2B's own target at 10 tok/s, so the steps below that read a target name
#    it rather than inheriting the 4B's 5.25.
QWEN_VULKAN_WORKLOAD_LOCK=$HOME/qwen-webui-state/vulkan-workload.lock \
    QWEN_PRODUCTION_BUILD_DIR=$HOME/llama.cpp-build \
    ~/qwen-laptop-setup/remote/measure-draft-pair.sh \
    qwen38-2b-distill+qwen35-08b-draft \
    ~/qwen-webui-state/draft-pairs/qwen38-2b-distill

# 2. The 2B's own prediction block over the same depths, so the class that
#    leads the policy carries both mechanisms before the 4B runs either.
QWEN_VULKAN_WORKLOAD_LOCK=$HOME/qwen-webui-state/vulkan-workload.lock \
    QWEN_PRODUCTION_BUILD_DIR=$HOME/llama.cpp-build \
    QWEN_MTP_ARM_TARGET_RATE=10 \
    ~/qwen-laptop-setup/remote/measure-mtp-arm.sh draft-mtp qwen38-2b-distill \
    ~/qwen-webui-state/temporal-amortization/2b-mtp

# 3. The 4B's embedded head at N in {1,2,3}. This is the arm the break-even
#    table predicts hardest and the one that costs 81 MiB.
QWEN_VULKAN_WORKLOAD_LOCK=$HOME/qwen-webui-state/vulkan-workload.lock \
    QWEN_PRODUCTION_BUILD_DIR=$HOME/llama.cpp-build \
    ~/qwen-laptop-setup/remote/measure-mtp-arm.sh draft-mtp qwen38-4b-distill \
    ~/qwen-webui-state/temporal-amortization/4b-mtp

# 4. The 4B pairing at the same three depths, against the same controls.
QWEN_VULKAN_WORKLOAD_LOCK=$HOME/qwen-webui-state/vulkan-workload.lock \
    QWEN_PRODUCTION_BUILD_DIR=$HOME/llama.cpp-build \
    ~/qwen-laptop-setup/remote/measure-mtp-arm.sh draft-simple \
    qwen38-4b-distill+qwen35-08b-draft \
    ~/qwen-webui-state/temporal-amortization/4b-pair

# The calculator runs inside each harness invocation and re-runs over a
# retained directory without the device.
remote/summarize-speculation-breakeven.py \
    ~/qwen-webui-state/temporal-amortization/4b-mtp --target-rate 5.25
```

Each `measure-mtp-arm.sh` invocation runs twelve servers: a mirrored
control, arm, arm, control quadruple at each of N=1, 2, and 3. At the 4B's
3.35 tok/s control and 128 predicted tokens over three prompts, one quadruple
is about 8 minutes of decode beside four model loads, so a 4B invocation runs
about 40 minutes and the 2B about 20.

## What stays unmeasured

No arm of this design has run. The acceptance the 0.8B reaches against either
target, the round time each mechanism takes at each depth, whether the 4B's
prediction block reproduces the matrix's 0.846 on this prompt corpus, and
whether the pairing's 997.78 MiB clears the preflight on the appliance are all
open. The `v(N+1)` ladder the table rests on is retained synthesis from a run
whose raw request and response bodies the checkout lacks, so a measured round
time that contradicts it refutes the ladder rather than the arm, and the
calculator reads round time from the run for that reason.
