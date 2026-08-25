# Artifact retention policy

| Surface | Retention class | Repository treatment | Replay authority |
| --- | --- | --- | --- |
| Setup scripts, tests, policies, and tracker | canonical generator or synthesized truth surface | ordinary Git | tracked source |
| Kernel, allocation, build, and runtime logs | raw exact-target evidence | ordinary Git under `evidence/` | `evidence/SHA256SUMS` |
| `llama-server` and `llama-cli` | retained exact-build binary | Git LFS under `artifacts/bin/` | byte size and SHA-256 below |
| Qwen3.5-4B, Qwen3.8-9B Distill, and Qwen3.8-27B GGUFs | external reproducible dependencies | excluded from Git and LFS | pinned Hugging Face revisions, byte sizes, and SHA-256 values |
| llama.cpp source | external canonical source plus local patch series | pinned commit and four replay patches | `remote/verify-llama-patch-series.sh` |
| llama.cpp build tree | derived regenerable | excluded | `remote/build-llama-vulkan.sh` |
| View-metadata incremental patch | superseded retain | `patches/superseded/` | folded into `llama-no-cpu-fallback.patch` |
| Raven2 diagnostic Web UI | adapted source asset | ordinary Git under `webui/` | qwen-lab 1.5.0 source plus APU-specific policy tests |

The Git copies replace the private laptop hostname with `qwen-laptop`, the
machine-local home prefix with `$HOME`, and network MAC addresses with
`<mac>`. `evidence/PRE_SANITIZATION_SHA256SUMS` records the imported artifact
hashes before the repository-wide identifier pass. Exact raw originals remain
on the source host.

## Exact artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `artifacts/bin/llama-server` | 57,475,792 | `3d5b158160b08cf897bb05b47186a13f67e8a17def31012f2f8282f12e95cb08` |
| `artifacts/bin/llama-cli` | 57,643,992 | `83cc86e271b7fe784d208c00ca22d1fe6875e7a956790d16b55a9e617d23cc5b` |
| `Qwen3.5-4B-Q4_K_M.gguf` | 2,740,937,888 | `00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4` |
| `Qwen3.8-9B-Q4_K_M.gguf` | 5,780,090,176 | `df13d66021cef676f82be74053220fd75af6bf2a6a7fb77f5222ab9e50744a7a` |

`benchmarks/models/qwen38-27b-files.tsv` is the replay authority for the four
external Qwen3.8-27B benchmark files. Those 9.83 GB through 14.25 GB files stay
outside Git LFS.

The llama.cpp source commit is
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`. Apply
`patches/llama-vulkan-low-priority.patch` followed by
`patches/llama-no-cpu-fallback.patch` and
`patches/llama-vulkan-duty-cycle.patch`, then
`patches/llama-vulkan-runtime-submit-limit.patch`. The replay verifier checks
the resulting five modified source files byte for byte against their admitted
hashes.

The retained llama.cpp executables and derived source patches carry the
upstream MIT terms in `licenses/llama.cpp-LICENSE`. The external GGUF model
repository declares Apache-2.0 in its pinned Hugging Face model metadata.
The adapted single-file Web UI carries its source MIT terms in
`licenses/qwen-lab-LICENSE`.

`evidence/runtime-logs/qwen-priority-build.log` retains the four-patch build.
Its original SHA-256 is
`18ec0f443fc6cd4002e35a9f615c5d77cd2843a74fe4759b8df7de974b93fc41`;
the sanitized retained log SHA-256 is
`3cc39517226054298390828a0e7b0473481932f6649016f7f6e18e9e59cc9ca4`.

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
