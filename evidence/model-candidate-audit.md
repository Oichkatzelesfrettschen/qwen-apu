# Vulkan Model Candidate Audit

## Decision

Qwen3.8-27B remains the primary quality benchmark. The daily-model ladder is:

1. `Qwen3.5-4B-Q4_K_M` as the balanced daily candidate.
2. `Qwen3.5-9B-Q4_K_M` as the higher-quality local candidate.
3. `Qwen3.5-2B-Q6_K` as the fast draft, tool-routing, and speculative candidate.

The 4B candidate is the first model to download after the Vulkan build and
launcher preflight pass. The vision projector, MTP head, and speculative
decoding stay disabled in initial text-only runs.

The 10 token/s goal is a benchmark target, not an admission claim. Q4 4B
weights require approximately 2.55 GiB of weight traffic per generated token
before cache, graph, and synchronization costs. Only measurement can show
whether the two-CU Raven2 and shared DDR4 sustain 10 token/s. The 2B Q6 arm is
the credible fallback for exceeding that rate without CPU tensors.

## Primary Qwen candidates

The Qwen3.5 models use Apache-2.0. Their official cards specify native
262,144-token context, thinking and non-thinking operation, Qwen tool calling,
and text-only loading without the vision encoder. The pinned llama.cpp checkout
contains `LLM_ARCH_QWEN35`, a dedicated graph, MTP handling, tokenizer support,
and GGUF architecture metadata.

| Candidate | Full-attention layout | GGUF | Weight | C128 Q8/Q4 KV | Lower bound |
|---|---:|---|---:|---:|---:|
| Qwen3.5-2B | 6 layers, 2 KV heads, dim 256 | Q6_K | 1.467 GiB | 0.609 GiB | 2.076 GiB |
| Qwen3.5-4B | 8 layers, 4 KV heads, dim 256 | Q4_K_M | 2.553 GiB | 1.625 GiB | 4.178 GiB |
| Qwen3.5-9B | 8 layers, 4 KV heads, dim 256 | Q4_K_M | 5.290 GiB | 1.625 GiB | 6.915 GiB |

The KV estimate uses Q8_0 K and Q4_0 V block costs of
`34/32 + 18/32 = 1.625 bytes` per K/V element. It excludes recurrent state,
checkpoints, graphs, scratch, staging, loading peaks, prompt cache, the OS, and
the desktop reserve. It is an allocation lower bound rather than a fit proof.

Qwen3.5-4B and 9B arrange 32 layers as eight repetitions of three
linear-attention layers followed by one full-attention layer. Their C128 KV
allocation is much smaller than a dense full-attention model of similar width.

Qwen-reported results place 9B above 4B on GPQA, long context, coding,
instruction following, multilingual, and most agent measures. The official 2B
card reports strong BFCL-V4 and TAU2 scores but materially weaker math,
knowledge, and coding results. These vendor results remain hypotheses until the
common local corpus is run.

Official models and GGUF lineages:

- https://huggingface.co/Qwen/Qwen3.5-2B
- https://huggingface.co/Qwen/Qwen3.5-4B
- https://huggingface.co/Qwen/Qwen3.5-9B
- https://huggingface.co/unsloth/Qwen3.5-2B-GGUF
- https://huggingface.co/unsloth/Qwen3.5-4B-GGUF
- https://huggingface.co/unsloth/Qwen3.5-9B-GGUF

| File | Bytes | SHA-256 |
|---|---:|---|
| `Qwen3.5-2B-Q6_K.gguf` | 1,574,961,408 | `fc90339420b4298887aafb307a4291c55440b730133bbffe6ba9630503dcb548` |
| `Qwen3.5-4B-Q4_K_M.gguf` | 2,740,937,888 | `00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4` |
| `Qwen3.5-9B-Q4_K_M.gguf` | 5,680,522,464 | `03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8` |

## Qwen controls and exclusions

`Qwen3-4B-Instruct-2507-Q4_K_M` is 2.326 GiB, but its 36 dense attention
layers require approximately 7.313 GiB of C128 Q8/Q4 KV. Its 9.638 GiB lower
bound is more than twice the Qwen3.5-4B lower bound. It remains an architecture
control rather than a daily candidate.

Qwen3-Coder-30B-A3B and Qwen3.5 MoE models activate few parameters per token
but keep all expert weights resident. Their weight footprint conflicts with the
measured 15.46 GiB Vulkan budget and the desktop reserve. Active parameter count
does not make them admission candidates.

The 27B benchmark lineage remains
https://huggingface.co/unsloth/Qwen3.8-27B-GGUF. Its initial capacity arm is
`UD-Q2_K_XL`, its practical-quality arm is `UD-IQ3_XXS`, and `UD-Q4_K_M` is the
high-quality control. No 27B download occurs before the live desktop reserve,
Vulkan budget, build, and launcher gates pass.

## Non-Qwen comparators

| Candidate | License | Context claim | C128 Q4 lower bound | Disposition |
|---|---|---:|---:|---|
| Ministral 3 3B Reasoning 2512 | Apache-2.0 | 262K YaRN from 16K | 7.281 GiB | Best non-Qwen reasoning/tool comparator; dense KV is costly. |
| SmolLM3-3B | Apache-2.0 | 64K trained, 128K YaRN | 5.440 GiB at 128K | Open 64K transparency and speed control. |
| Phi-4-mini-reasoning 3.8B | MIT | 128K LongRoPE from 4K | 8.821 GiB | Math control, not a full agent/code replacement. |
| Gemma 3 4B IT | Gemma license | 128K | Sliding-window measurement required | Secondary general control without Qwen's tool contract. |

Ministral's official card reports strong AIME, GPQA, and LiveCodeBench results
and documents Mistral tool and reasoning parsers. Its 26 dense attention layers
consume approximately 5.281 GiB of C128 Q8/Q4 KV before weights. It is the
strongest non-Qwen functionality comparator found in the 3B class, but
Qwen3.5-4B has a better long-context memory topology.

SmolLM3 supports dual reasoning modes, XML or Python-form tool calls, six
languages, and public training details. Its config is 65,536 tokens; the 128K
claim uses YaRN. Phi-4-mini-reasoning is explicitly trained and evaluated for
math reasoning and warns about limited code scope. Gemma uses the Gemma license
and does not establish the same native tool-call workflow.

Sources:

- https://huggingface.co/mistralai/Ministral-3-3B-Reasoning-2512
- https://huggingface.co/mistralai/Ministral-3-3B-Reasoning-2512-GGUF
- https://huggingface.co/HuggingFaceTB/SmolLM3-3B
- https://huggingface.co/unsloth/SmolLM3-3B-GGUF
- https://huggingface.co/microsoft/Phi-4-mini-reasoning
- https://huggingface.co/unsloth/Phi-4-mini-reasoning-GGUF
- https://huggingface.co/google/gemma-3-4b-it
- https://huggingface.co/unsloth/gemma-3-4b-it-GGUF

## Evaluation contract

Every admitted model runs the same text-only corpus at 32K, 64K, 96K, and
128K where its context claim permits it. The corpus covers code, research
prose, JSON tool transcripts, multi-document retrieval, multilingual material,
and dependencies separated by tens of thousands of tokens. Measurements cover
retrieval, reasoning, valid tool calls, coding tests, prefill, decode, peak and
steady memory, GPU faults, and desktop responsiveness.

Native, trained, and extrapolated context remain separate fields. Manufacturer
scores remain cited claims until reproduced. A model becomes daily only after
the local depth curve passes without CPU tensors, hardware hazards, or a
desktop-responsiveness breach.
