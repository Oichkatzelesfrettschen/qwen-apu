# Qwen3.8-4B Distill Against the Qwen3.5-4B Base

`empero-ai/Qwen3.8-4B-Distill` is a full-parameter distillation of Qwen3.8
2.4T A95B into the Qwen3.5-4B architecture, so the pinned llama.cpp build that
already loads Qwen3.5-4B loads it without a rebuild. Both checkpoints travel
`remote/compare-model-candidate.sh`, which drives the guarded launch path, one
chat request with reasoning suppressed, one with reasoning enabled, and a
teardown that captures the per-device memory breakdown llama-server prints as
it releases the context. A difference between two runs is therefore a
difference between two models.

Artifact pinning lives in `remote/download-qwen38-4b-distill-q4km.sh`:
revision `391fc7d103e3942a408def3e4f51c2f85d464417`, 2,783,446,304 bytes,
SHA-256 `dec96e8cf2e11b613bb46513dec485377f9ca5a351e71712ee0e244f287c6790`,
matching the repository's published `SHA256SUMS`.

## Measured

| Property | Qwen3.5-4B base | Qwen3.8-4B distill |
| --- | ---: | ---: |
| Weight bytes | 2,740,937,888 | 2,783,446,304 |
| Prefill tok/s, 32-token prompt | 17.70 | 17.80 |
| Decode tok/s, 301 and 227 tokens | 2.537 | 2.721 |
| Reasoning tokens for one arithmetic comparison | 301 | 227 |
| Wall clock to the same correct answer | 120.0 s | 84.7 s |
| Vulkan0 total residency | 2,974 MiB | 2,943 MiB |
| Vision modality reported by `/props` | true | false |
| Probe frames inside one 60 Hz budget | 99.87% | 99.96% |
| Probe deadline breaches | 6 in 8,509 | 2 in 5,358 |

Both answered "9.9 is larger than 9.11" correctly with reasoning in either
state.

## The chat template survives the distillation

`chat_template_kwargs.enable_thinking` still gates the `<think>` span in the
distill: the suppressed request returned no `reasoning_content` and the enabled
request returned one. The WebUI reasoning toggle therefore keeps working across
the swap. A distillation that shipped its own template could have dropped that
gating while every throughput figure stayed identical, so this is checked
directly rather than inferred from the model card.

## The distill is text-only

The `empero-ai/Qwen3.8-4B-Distill-GGUF` repository publishes five quantizations
and no projector, and `/props` reports `vision: false` under the distill. A
projector encodes images into the embedding space of the checkpoint that
exported it; a foreign projector of matching dimensions loads without error and
places image tokens where the language model does not read them, which is a
wrong answer rather than a failure. `remote/qwen-launch.sh` searches for the
projector in the model's own directory, so a checkpoint published without one
runs text-only instead of borrowing another model's.

## Quality is the publisher's measurement, not this repository's

The model card reports mmlu CoT 0.354 to 0.553 and gsm8k_cot 0.850 to 0.785
against the base. That is a trade, not an upgrade, and it lands on opposite
sides of a homework workload. This hardware cannot settle it: at 2.7 decode
tok/s with a 227-token reasoning span, one gsm8k item costs roughly 90 seconds,
and separating 0.850 from 0.785 at conventional significance needs several
hundred items per model -- a run of about a day per checkpoint. A 20-item or
60-item sample has a standard error wider than the 6.5-point difference it
would be asked to resolve, so it would report noise as a verdict.

The base model remains the default. The distill is available by argument:

```sh
QWEN_MODEL_PATH=$HOME/models/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf \
    remote/qwen-launch.sh
```
