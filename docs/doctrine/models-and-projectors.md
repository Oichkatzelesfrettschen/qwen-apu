# Checkpoints: what each one measured

The doctrine in `AGENTS.md` states the rule and this file carries the mechanism, the measurements, and the evidence paths behind it in full. The directory pairing rule stays in `AGENTS.md`; this file carries the per-checkpoint measurements, the multi-token-prediction block, static admission, and the fetch discipline.

`empero-ai/Qwen3.8-4B-Distill` distills into the Qwen3.5-4B architecture, so
the pinned build loads it unchanged. It reasons in 43.3% of the base model's
tokens, reaches an answer 2.71 times faster across the five-prompt suite, and
its chat template still gates `<think>` on
`chat_template_kwargs.enable_thinking`. It ships text-only, so the vision
profile selects the base checkpoint with its revision-matched projector.
The publisher reports a gsm8k_cot fall from 0.850 to 0.785 alongside an mmlu CoT
rise from 0.354 to 0.553.

The distill's advantage over the base is throughput alone.
`evidence/model-admission/roster-quality-sweep.md` grades both at 47 of 55 with
thinking off, at the same 0.855 correct-on-completed, and within one row in every
category. The five-prompt screen that separated them at 5/5 against 4/5 scored
the base's one failure as an empty answer after 2048 predicted tokens of
reasoning, which is the termination failure thinking off removes.

`empero-ai/Qwen3.8-2B-Distill` is the same architecture at 24 layers and
2048/6144, and it decodes above the 4B in every arm that measured both. It
streams 1.263 GB per token and reaches 10.41 GB/s against the 4B's 8.11 on the
mean of four sweeps, with the 2B ahead in all four pairs, so it streams faster
rather than carrying less overhead. Read the pairs and not the means: the same
checkpoint under identical flags spans 30.6% across those four sweeps, enough
that the 2B's slowest arm falls below the 4B's fastest.

The tested 4B K-quant ladder is exhausted as a performance lever.
`evidence/decode-bound-analysis.md` measures Q4_K_M ahead of i1-Q2_K, i1-Q5_K_M,
and i1-Q6_K in every block. Q2_K streams 29.4% fewer bytes per token and decodes
no faster, which closes that low-bit route, and Q6_K and Q5_K_M close the tested
route upward. Achieved streaming forms two observed groups rather than ordering
by bit width: a Q4_K trunk and a Q6_K trunk both reach about 8.1 GB/s where a
Q5_K trunk reaches 5.9. IQ and other reconstruction kernels remain unmeasured.

The low-bit route closes at 0.8B on the measured rows. The three 0.8B-class checkpoints of
`evidence/model-admission/runtime-class-throughput.md` decode at 15.96, 15.17,
and 15.31 tok/s while streaming 0.477, 0.547, and 0.801 GB per token: 5.2% of
rate across 67.9% of bytes, over two value formats and two architectures, with
every arm inside the sweep's span criterion. The whole token time there is 63
to 66 ms, about a fifth of the 4B's 314 ms. The matched-structure pair streams
0.254 GB more per token with a 0.6 ms shorter observed token time, inside the
declared span. Architecture and format change with bytes across the wider set,
so the measurements isolate neither a marginal byte cost nor the mechanism that
sets the rate.

The consequence is a serving decision. Qwen3.5-0.8B at Q8_0 streams 46.4% more
bytes per token than the same checkpoint at Q4_K_M and the two decode rates
differ by 0.9%, inside the within-arm deviations, so the direction is
unresolved. Both registered accounts predicted the Q4_K_M 23 to 48% faster and
are refuted on magnitude; the served `qwen35-08b` Q8_0 row keeps its position
and a Q4_K_M rung of that class competes on quality rather than on throughput.
The prefill halves separate where the decode halves do not, 146.22 against
134.91 tok/s, which places Q4_K's super-block scale decode in the half where
arithmetic rather than a per-token cost dominates.

Qwen3-Zero-Coder-Reasoning-0.8B runs 42 blocks at 1024 embedding width against
the Qwen3.5-0.8B's 24 and achieves 7.62 GB/s against 8.30 at 87.3% of the bytes,
with a 24.3% prefill deficit against a 5.2% decode advantage. Achieved GB/s is
bytes times rate, so that 8.2% deficit restates the two inputs, and the rows
differ in architecture, feed-forward width, and head counts beside block count,
so a per-dispatch cost stays a correlated observation until one trunk is
measured at two depths.

Two architectures now break the size ordering of achieved rate in the same
direction. `evidence/model-admission/universal-candidate-ladder.md` recorded
LFM2's short-convolution blocks doing it, and Qwen2-VL-2B at 28 blocks of full
attention over 12 heads and 2 KV heads achieves 8.24 GB/s against the 2B
distill's 9.71 in one sweep while streaming 22.4% fewer bytes. The operator mix
rather than the byte count orders achieved rate across architectures.

Every distill ships a multi-token-prediction block that the speculation setting
decides the fate of. `qwen35.nextn_predict_layers` is 1 and `block_count` counts
it, so the 2B declares 25 blocks against 24 transformer layers.
`llama_hparams::n_layer_effective` subtracts it from the trunk, and
`src/models/qwen35.cpp` sets `mtp_flags = !ml.load_mtp ? TENSOR_SKIP : 0`, so an
ordinary load reports each of its tensors as `model has unused tensor ... --
ignoring` and skips 37,767,168 bytes on the 2B, matching the census exactly.
That block costs download and disk alone, between 2.61% and 2.88% of each file,
until `--spec-type draft-mtp` sets `load_mtp` and loads it.

The head runs in place. `common/common.cpp` sets `mparams.load_mtp` from
`params.speculative.types`, `common_speculative_init_result` takes its
`else if (spec_mtp)` branch and builds the draft context against the target
model with `cparams.ctx_type = LLAMA_CONTEXT_TYPE_MTP`, and
`llama_model::create_memory` filters that context's KV cache to
`il >= hparams.n_layer()`, so the draft cache holds the appended block rather
than a second trunk. `QWEN_SPEC_TYPE`, `QWEN_SPEC_DRAFT_N_MAX`,
`QWEN_SPEC_DRAFT_P_MIN`, `QWEN_SPEC_BACKEND_SAMPLING`, and
`QWEN_BACKEND_SAMPLING` carry those settings through the tmux boundary into
`qwen-capacity-policy.sh`, which keeps `LLAMA_ARG_*` refused.

`remote/gguf-tensor-census.py` reports these properties from the file, because
a Q4_K_M label names a recipe rather than a layout: the 2B is 50.08% Q6_K by
byte where the 9B is 32.59%.

A candidate declares its architecture and its chat template before it is
fetched. A GGUF places the metadata block and tensor index at the head of the
file, so `remote/admit-candidate-static.py` reads them over an HTTP range
request against a pinned revision and imports the census parser rather than
writing a second one. Sixteen mebibytes covers a Qwen3.5 metadata block, whose
248,320 tokens and their merges end the 2B distill's header at 10,962,034
bytes, and the reader grows the window on a short read so a truncated buffer
raises rather than reporting the trailing keys absent. The ranged read
reproduces the appliance's own full-file census on every identity field of the
served 2B, including the 37,767,168 prediction-block bytes.

The script runs on the workstation, which makes it a third workstation-side
helper beside the UI build and the container build: it needs the network and
the appliance's two 2.3 GHz cores are the wrong place to spend it.

Static admission is what makes the throughput stage small. Throughput belongs to
an architecture and a value format, so grouping candidates by architecture,
embedding width, feed-forward width, and head counts collapses the fourteen
GGUF rows of `evidence/model-admission/candidate-ledger.tsv` into four runtime
classes. Eight rows of the largest class span 0.83% in streamed bytes against
the 4% this machine carries on a repeated depth-0 rate, so a second arm inside a
class measures queue position. One class holds a reference at its own format and
three do not: the served 0.8B is Q8_0 and streams 764 MiB per token where its
Q4_K_M class members stream 493 to 522, so that class needs an arm of its own
rather than a cross-format ratio. The same read answers what no rate can: the Jackrong 0.8B Opus
reasoning distill ends its generation prompt with an unguarded `<think>` and
names `enable_thinking` nowhere, so the thinking-off request is inert
against it and its graded arm needs a budget that survives the reasoning span.
`evidence/model-admission/static-admission.md` carries the classes and the
template survey.

A runtime class establishes a shared throughput expectation and nothing about a
particular artifact, so admission by load runs every row rather than one
representative per class. `remote/run-one-token-admission.sh` fetches each
candidate and calls `remote/test-strict-vulkan-placement.sh`, which requires CPU
tensor placement and CPU graph placement to be rejected, brings a strict Vulkan
server up, drives a two-token completion, and requires the model, KV, and
compute buffers to name Vulkan0 with no CPU fallback reached. Its `fetch` stage
runs without the device, so eleven gigabytes of transfer happen while the
appliance still serves and the outage covers the loads alone. A control arm runs
the same check against a served checkpoint after each new runtime class and
after any refusal, so a later refusal reads against a device that had just
answered.

A candidate fetched from Hugging Face LFS is verified against the publisher.
`remote/fetch-candidate-artifact.sh` reads the pinned revision's LFS object ID,
requires the downloaded SHA-256 and byte count to match it, and reports the
digest as `verified_sha256`. A repository artifact published outside LFS has no
publisher digest; the fetcher reports that fallback as `observed_sha256`, and
promotion into `remote/models.tsv` requires a `download-*.sh` that pins the
observed digest as its expectation.

GGUF weights stay outside Git because their sizes exceed the LFS per-file
limit. Each download script pins a Hugging Face revision, a byte count, and a
SHA-256, and verifies an existing file in place.

