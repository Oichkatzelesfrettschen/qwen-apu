# Models and tool capabilities

This page separates four facts that the model picker can otherwise blur:

- **Installed** means the laptop has the registered model bytes.
- **Served** means the active router advertises the section through
  `GET /v1/models`.
- **Validated depth** means one exact runtime tuple filled and decoded at the
  stated context. A loaded model without that result remains unvalidated.
- **Tool capable** means the application offers a guarded operation. A model's
  raw ability to write a plausible tool call is only a quality observation.

The live inventory after source `6f6a9be7` found all 21 registered language
model files and every required projector on the laptop. The active roster
contained 13 base-model sections, two speculative draft sections, and
`web-open`. The serving bundle remained `lease-q4k-6b262d93-r1`.

## Language models

| Model ID | Quantization | Tier | Live roster | Depth | Vision | Raw tool selection | Application tools |
| --- | --- | --- | --- | ---: | --- | ---: | --- |
| `qwen38-4b-distill` | Q4_K_M | production | yes | 32768 | no | 9/10 | base section: none; powers `web-open` |
| `qwen38-2b-distill` | Q4_K_M | production | yes | 32768 | no | 2/10 | none |
| `qwen35-4b-base` | Q4_K_M | production | yes | unvalidated | yes | 8/10 | attachment input only |
| `qwen35-08b` | Q8_0 | candidate | yes | 32768 | no | 9/10 | none |
| `qwen35-2b` | Q4_K_M | candidate | yes | unvalidated | yes | 9/10 | attachment input only |
| `lfm25-vl-16b` | Q4_K_M | candidate | yes | unvalidated base section; 8192 reviewer tuple | yes | 8/10 | attachment input; registered image reviewer |
| `qwen35-08b-f16` | F16 | candidate | yes | 32768 | no | unmeasured | none |
| `qwen38-2b-uncensored` | Q4_K_M | candidate | yes | unvalidated | no | unmeasured | none |
| `qwen35-2b-hauhau` | Q4_K_M | candidate | yes | unvalidated | no | unmeasured | none |
| `qwen35-2b-unredacted` | Q4_K_M | candidate | yes | unvalidated | no | unmeasured | none |
| `qwen35-2b-heretic` | Q4_K_M | candidate | yes | unvalidated | no | unmeasured | none |
| `qwen35-08b-unsloth-unc` | Q4_K_M | candidate | yes | unvalidated | no | unmeasured | none |
| `qwenseer-2b` | Q4_K_M | candidate | yes | unvalidated | no | unmeasured | none |
| `qwen38-9b-distill` | Q4_K_M | archive | no | unvalidated | no | unmeasured | none |
| `qwen38-27b-q2kxl` | UD-Q2_K_XL | archive | no | unvalidated | no | unmeasured | none |
| `qwen38-27b-iq3xxs` | UD-IQ3_XXS | archive | no | unvalidated | no | unmeasured | none |
| `qwen38-4b-i1-q2k` | Q2_K | rejected | no | unvalidated | no | unmeasured | none |
| `qwen38-4b-i1-q5km` | Q5_K_M | rejected | no | unvalidated | no | unmeasured | none |
| `qwen38-4b-i1-q6k` | Q6_K | rejected | no | unvalidated | no | unmeasured | none |
| `nanbeige42-3b` | Q4_K_M | quarantine | no | no safe tuple | no | unmeasured | none |
| `ministral3-3b` | Q4_K_M | quarantine | no | router-child abort | yes | unmeasured | none |

Every file in the table is installed. The ordinary router emits production and
candidate rows. It withholds archive rows displaced from ordinary use, rejected
rows that lost admission, and quarantine rows with a recorded safety or runtime
failure. A loopback-only research override can expose quarantine rows, but that
override is not part of the user appliance.

The two additional live sections are
`qwen38-2b-distill+qwen35-08b-draft` and
`qwen38-4b-distill+qwen35-08b-draft`. They are experimental speculative-decoding
pairings, not additional weight files or tool profiles.

## Web tools

| Profile | Backing model | Policy | Served | Capability |
| --- | --- | --- | --- | --- |
| `web-open` | `qwen38-4b-distill` | validator-gated | yes | approved search and fetch, up to 5 results, 2 fetches, and 12000 characters per fetch |
| `web-balanced` | `qwen38-4b-distill` | refused | no | none |
| `web-sovereign` | `qwen38-4b-distill` | refused | no | none |
| `web-reader` | `qwen38-2b-distill` | refused | no | none |
| `web-lookup` | `qwen35-08b` | refused | no | none |
| `web-compact` | `qwen35-2b` | refused | no | none |
| `web-fast-vl` | `lfm25-vl-16b` | refused | no | none |
| `web-vision` | `qwen35-4b-base` | refused | no | none |

`web-open` uses the local SearXNG provider. The page obtains one approval for
each proposed operation, resolves short result handles within the turn, and
passes the exact approved arguments to the broker. A failed required retrieval
ends with an application-authored incomplete result. Search snippets alone do
not become a page-derived answer.

The base model rows all retain `guarded_tool_execution=refused`. This means the
llama.cpp child never executes a model-authored operation directly. The guarded
`web-open` section and page broker provide the application capability.

## Image generation and review

| Profile | Model bundle | Installed | Policy | Reviewer | Result |
| --- | --- | --- | --- | --- | --- |
| `image-sdxs-512-a` | SDXS-512 | yes | validator-gated | `lfm25-vl-16b` | generation and review served |
| `image-sdxs-512-b` | SDXS-512 | yes | refused | none | unavailable |
| `image-sd15-lcm-a` | SD 1.5 + LCM | no | refused | none | unavailable |
| `image-sd15-base-a` | SD 1.5 | no | refused | none | unavailable |
| `image-sd-turbo-a` | SD-Turbo | no | refused | none | unavailable |

The installed SDXS bundle contains its diffusion model, tiny autoencoder, and
text encoder. The admitted profile accepts 512 by 512 output, at most four
steps, and one generation per approved turn. The page verifies the returned
PNG digest and owns Open, Download, Remove, and Review controls. The model sees
only a conversation-local reference such as `image-1`.

Selecting **image** for an image-only turn requires the first completion to
produce the sole admitted image tool call. Continuation after the generated
artifact returns to automatic selection so the model can describe the result.
Selecting Web and Image together retains automatic selection because the user
has admitted more than one possible operation.

## What is ready now

- Ordinary text chat is available for all 13 production and candidate models.
- Vision attachments are registered for the three projector-backed models.
- Guarded web search and fetch are available through `web-open`.
- SDXS image generation and LFM image review are configured and have completed
  through the live page.
- All other registered language models are installed for retained research but
  stay outside the ordinary picker according to their tiers.
- Alternative image bundles are declarations only; their profiles are refused
  and their model artifacts are not installed.

The registries remain the source of truth:
[`models.tsv`](../remote/models.tsv),
[`validated-tuples.tsv`](../remote/validated-tuples.tsv),
[`web-profiles.tsv`](../remote/web-profiles.tsv), and
[`image-profiles.tsv`](../remote/image-profiles.tsv).
