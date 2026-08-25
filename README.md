# Qwen APU

This repository retains the reproducible setup, policy, source patches,
runtime evidence, and benchmark results for a headless RADV Vulkan Qwen
deployment on a two-compute-unit Raven2 APU. The default runtime uses the
lowest effective amdgpu scheduling class, one in-flight Vulkan submission,
32-node submission boundaries, 32-token Vulkan microbatches, and a
normal-priority graphics-queue latency watchdog. CPU work stays on CPU 0 at
nice 19 and idle I/O priority, one inference slot is available, and any CPU
model execution fails closed. A 60% duty-cycle profile remains the measured
control.

`TASK_TRACKER.md` is the execution ledger. `remote/` contains the host-side
launchers, guards, tests, and benchmark tools. `patches/` reconstructs the
pinned llama.cpp changes. `evidence/` retains raw and synthesized evidence.
`artifacts/bin/` contains the exact verified executables through Git LFS.
`webui/` contains the same-process Raven2 test panel, and `WEBUI.md` defines its
SSH-only deployment and control commands.

GGUF weights remain external hash-pinned dependencies because their file sizes
exceed GitHub Pro's 2 GB Git LFS per-file limit. Run
`remote/download-qwen35-4b-q4km.sh` for the 4B daily candidate and
`remote/download-qwen38-9b-distill-q4km.sh` for the intermediate reasoning
candidate. Run
`remote/download-qwen38-27b-ladder.sh` for a pinned 27B benchmark quantization.
The 27B manifest records the exact source revision, byte counts, and SHA-256
values for `UD-Q2_K_XL`, `UD-IQ3_XXS`, `UD-IQ3_S`, and `UD-IQ4_XS`.

The deployment remains SSH-only. The server binds to `127.0.0.1`, requires a
generated API key for Web UI and API routes, and reaches the client browser
through loopback SSH forwarding. No script controls the remote graphical
session.

The equal-request 4B comparison measures 11.437 prompt tok/s and 1.316 decode
tok/s under the serialized default. The admitted 16-node async experiment
measures 14.103 prompt tok/s and 2.713 decode tok/s, but it remains behind the
external desktop-input and thermal-soak gates. See
`evidence/benchmarks/qwen35-4b-vulkan-priority-comparison.md`.
