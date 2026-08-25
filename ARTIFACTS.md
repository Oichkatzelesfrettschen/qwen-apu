# Artifact retention policy

| Surface | Retention class | Repository treatment | Replay authority |
| --- | --- | --- | --- |
| Setup scripts, tests, policies, and tracker | canonical generator or synthesized truth surface | ordinary Git | tracked source |
| Kernel, allocation, build, and runtime logs | raw exact-target evidence | ordinary Git under `evidence/` | `evidence/SHA256SUMS` |
| `llama-server` and `llama-cli` | retained exact-build binary | Git LFS under `artifacts/bin/` | byte size and SHA-256 below |
| Qwen3.5-4B Q4_K_M GGUF | external reproducible dependency | excluded from Git and LFS | pinned Hugging Face revision, byte size, and SHA-256 |
| llama.cpp source | external canonical source plus local patch series | pinned commit and two replay patches | `remote/verify-llama-patch-series.sh` |
| llama.cpp build tree | derived regenerable | excluded | `remote/build-llama-vulkan.sh` |
| View-metadata incremental patch | superseded retain | `patches/superseded/` | folded into `llama-no-cpu-fallback.patch` |

The Git copies replace the private laptop hostname with `qwen-laptop`, the
machine-local home prefix with `$HOME`, and network MAC addresses with
`<mac>`. `evidence/PRE_SANITIZATION_SHA256SUMS` records the imported artifact
hashes before the repository-wide identifier pass. Exact raw originals remain
on the source host.

## Exact artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `artifacts/bin/llama-server` | 57,467,440 | `9c31bf00b548ac1bc7f7cb775afb3e06ee0d20eb0293ebaf2e0b6d20a5a1020f` |
| `artifacts/bin/llama-cli` | 57,639,736 | `74afcb3bad505d181989fa4daf715525db1b0b2e4d2fe240d3542ad4c961a788` |
| `Qwen3.5-4B-Q4_K_M.gguf` | 2,740,937,888 | `00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4` |

The llama.cpp source commit is
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`. Apply
`patches/llama-vulkan-low-priority.patch` followed by
`patches/llama-no-cpu-fallback.patch`. The replay verifier checks the resulting
three modified source files byte for byte against their admitted hashes.

The retained llama.cpp executables and derived source patches carry the
upstream MIT terms in `licenses/llama.cpp-LICENSE`. The external GGUF model
repository declares Apache-2.0 in its pinned Hugging Face model metadata.

The response capture
`evidence/runtime-logs/qwen-strict-vulkan-one-token-response.json` replaces one
machine-local model directory with `models/test-fixtures/`. Its original
SHA-256 is `637787208a6ce93726b7f0661547923ec3e5756711494c0777eebd4594c1cdff`;
the sanitized retained file SHA-256 is
`67d1ddc22f1f415d09b401d146395dfd1c6d56a5e6e71532838aa5ec054bfc4c`.

The partial 32K server log replaces the machine-local model directory with
`models/Qwen3.5-4B-GGUF/`. Its original SHA-256 is
`7417a6ee288ba9088eb70f51adc5788b7eb70aa3ccaaf5e896f945850c9ac116`;
the sanitized retained log SHA-256 is
`6310efb38b990fe1a06cedc508eb1c330c33fdbe11fe05314979f7c49c0843ea`.
