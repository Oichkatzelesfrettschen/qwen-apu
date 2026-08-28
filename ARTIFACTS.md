# Artifact retention policy

| Surface | Retention class | Repository treatment | Replay authority |
| --- | --- | --- | --- |
| Setup scripts, tests, policies, and tracker | canonical generator or synthesized truth surface | ordinary Git | tracked source |
| Kernel, allocation, build, and runtime logs | raw exact-target evidence | ordinary Git under `evidence/` | `evidence/SHA256SUMS` |
| `llama-server`, `llama-cli`, and `llama-mtmd-cli` | derived regenerable | excluded from Git and LFS | byte size and SHA-256 below, against a rebuild |
| Dual-backend `llama-bench` and its ggml backends | derived regenerable | excluded from Git and LFS | `remote/build-llama-dual.sh`, byte sizes and SHA-256 values below |
| Qwen3.5-4B, Qwen3.8-9B Distill, and Qwen3.8-27B GGUFs | external reproducible dependencies | excluded from Git and LFS | pinned Hugging Face revisions, byte sizes, and SHA-256 values |
| llama.cpp source | external canonical source plus local patch series | pinned commit and four replay patches | `remote/verify-llama-patch-series.sh` |
| llama.cpp build tree | derived regenerable | excluded | `remote/build-llama-vulkan.sh` |
| View-metadata incremental patch | superseded retain | `patches/superseded/` | folded into `llama-no-cpu-fallback.patch` |
| Raven2 diagnostic Web UI | adapted source asset | ordinary Git under `webui/` | qwen-lab 1.5.0 source plus APU-specific policy tests |

`remote/refresh-evidence-manifest.sh` regenerates `evidence/SHA256SUMS` from
the tracked `benchmarks/` and `evidence/` trees, and `--check` exits non-zero on
drift. The manifest covered 154 of 216 tracked files before it was regenerated,
because each new measurement was committed without it, so a surface it omits is
retained without a replay authority.

The Git copies replace the private laptop hostname with `qwen-laptop`, the
machine-local home prefix with `$HOME`, and network MAC addresses with
`<mac>`. `evidence/PRE_SANITIZATION_SHA256SUMS` records the imported artifact
hashes before the repository-wide identifier pass. Exact raw originals remain
on the source host.

## Exact artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `llama-server` | 57,475,792 | `3d5b158160b08cf897bb05b47186a13f67e8a17def31012f2f8282f12e95cb08` |
| `llama-cli` | 57,643,992 | `83cc86e271b7fe784d208c00ca22d1fe6875e7a956790d16b55a9e617d23cc5b` |
| `llama-mtmd-cli` | 55,610,680 | `96e01162de9b4f5c1ebbaed246ad9cfe8964812c6e006c468df9cf44322cba52` |
| `llama-bench`, dual backend | 17,920 | `5d8dc29d0b012f4b8dd5057fcfe0f1786311835efe0445a6608000c8e9536d34` |
| `libllama-bench-impl.so` | 472,200 | `b69ad09e4623116c5e6756c5210b9e29e8e2451e95c685e383ae9b82b28fae53` |
| `libggml-hip.so` | 66,553,472 | `1034a6fb7ac6319608f69e2b351b56c4c7d6c450cf092cb79a16454072114266` |
| `libggml-vulkan.so` | 43,788,776 | `57675d461a5d15cb7915bc496d1ba37fa7352cb4f4ceb045b73d839a57a7650f` |
| `Qwen3.5-4B-Q4_K_M.gguf` | 2,740,937,888 | `00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4` |
| `Qwen3.8-9B-Q4_K_M.gguf` | 5,780,090,176 | `df13d66021cef676f82be74053220fd75af6bf2a6a7fb77f5222ab9e50744a7a` |
| `Qwen3.8-2B-BF16.gguf` | 3,897,387,392 | `44763f3d83f0a1a3ee63334b60916705dc565d796cb0f2b8c320414c57f4ac48` |
| `Qwen3.5-0.8B-bf16.gguf` | 1,557,662,528 | `ad1549eedc613064971dcbbbfab6c9b7990984d1c9ab38f792c6f2ec1207bbc2` |

The two F16 checkpoints carry no row above, because neither publisher ships
one: `remote/download-qwen38-2b-distill-bf16.sh` and
`remote/download-qwen35-08b-bf16.sh` fetch the BF16 artifacts the rows do carry,
and `llama-quantize` produces `Qwen3.8-2B-F16.gguf` and `Qwen3.5-0.8B-F16.gguf`
from them on the appliance. The generator is the replay authority for a derived
file, so the BF16 digest above plus the conversion reproduces the F16, and the
census confirms it: the same 1,505,783,040 streamed bytes per token with 99.17%
of bytes reported as BF16 before and as F16 after.

The vision fixtures under `remote/quality-images/` are committed rather than
regenerated, because deflate is not reproducible across hosts: zlib 1.3 on the
appliance re-encodes 7 of the 8 to different bytes than the workstation wrote,
with identical pixels. `remote/generate-quality-images.py --check` therefore
decodes both sides and compares pixels, which is the claim a fixture makes;
inflate is fully specified where deflate leaves the match search to the
implementation.

`benchmarks/models/qwen38-27b-files.tsv` is the replay authority for the four
external Qwen3.8-27B benchmark files. Those 9.83 GB through 14.25 GB files stay
outside Git LFS.

GitHub bills Git LFS storage and bandwidth to the account owning the
repository, public or private alike, against a free allowance of 1 GB of each.
The two executables cost 116 MB of that allowance per clone and embedded the
builder's home directory 231 times, so they are excluded and the manifest above
carries their identity instead. `remote/build-llama-vulkan.sh` regenerates them
from the pinned commit and patch series, `remote/verify-llama-patch-series.sh`
confirms the source reproduces, and `remote/verify-runtime-artifacts.sh`
compares a rebuild against the recorded byte counts and SHA-256 values. Pass it
the directory holding the rebuilt binaries.

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

## The dual-backend measurement binary

`remote/build-llama-dual.sh` configures `-DGGML_VULKAN=ON -DGGML_HIP=ON` against
one source commit, so `llama-bench --device` selects the backend and two rows
differ by the backend rather than by the build.
`remote/run-rocm-vulkan-matrix.sh` runs it, and
`evidence/therock-sdk-manifest.tsv` pins the ROCm nightly, the HIP version, the
toolchain, and the worktree state that produced the recorded rows.

`llama-bench` is a 17 KB launcher: the measurement code lives in
`libllama-bench-impl.so` and the kernels in the two ggml backend objects, so the
artifact of a measurement is the load closure rather than the executable. Four
of its members carry identities above. `remote/hash-load-closure.sh` reads the
rest, walking what `ldd` resolves, keeping the objects the build directory owns,
and emitting one TSV row of role, name, byte count, and SHA-256 per object. The
remaining members -- `libggml.so`, `libggml-base.so`, the `libggml-cpu` variant
the loader selects, `libllama.so`, and `libmtmd.so` -- are not recorded here
because the run that produced the four recorded rows predates the walker. That
gap closes on the next dual build. The binary links `librocblas.so.5`, `libhipblas.so.3`,
and `libhipblaslt.so.1` whatever `GGML_CUDA_FORCE_MMQ` selects, because the HIP
CMake path requires and links them unconditionally; the option changes which
kernels the quantized matrix path calls rather than which libraries load.

Both backends are built from a worktree carrying the repository patch series on
top of the pinned commit, which `remote/verify-llama-patch-series.sh` checks.

## Records derived from a remote partial fetch

`evidence/model-admission/static-admission.tsv` records what fourteen candidate
GGUFs declare, and no local artifact stands behind it. Each row comes from an
HTTP range read of the first 16 MiB of one file at one pinned revision, so the
row's provenance is the repository, the revision, and the artifact name it
carries rather than a file this tree holds. `remote/admit-candidate-static.py`
reproduces any row against those three fields, and the reproduction is a claim
about the remote revision staying reachable rather than about a retained file.

The record is checkable against a local artifact at exactly one row. The served
2B distill is on the appliance, and its full local census agrees with the ranged
read on chat template hash, template byte count, vocabulary hash, vocabulary
size, tokenizer pre-tokenizer, and the 37,767,168 prediction-block bytes.
