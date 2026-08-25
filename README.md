# Qwen APU

This repository retains the reproducible setup, policy, source patches,
runtime evidence, and benchmark results for a headless RADV Vulkan Qwen
deployment on a two-compute-unit Raven2 APU. The runtime gives the desktop
priority through a LOW Vulkan queue, a 60% model duty cycle, 32-token Vulkan
microbatches, one-core CPU affinity, nice value 19, idle I/O scheduling, one
inference slot, and fail-closed rejection of CPU model execution.

`TASK_TRACKER.md` is the execution ledger. `remote/` contains the host-side
launchers, guards, tests, and benchmark tools. `patches/` reconstructs the
pinned llama.cpp changes. `evidence/` retains raw and synthesized evidence.
`artifacts/bin/` contains the exact verified executables through Git LFS.
`webui/` contains the same-process Raven2 test panel, and `WEBUI.md` defines its
SSH-only deployment and control commands.

GGUF weights remain external hash-pinned dependencies because their file sizes
exceed GitHub Pro's 2 GB Git LFS per-file limit. Run
`remote/download-qwen35-4b-q4km.sh` for the 4B daily candidate and
`remote/download-qwen38-27b-ladder.sh` for a pinned 27B benchmark quantization.
The 27B manifest records the exact source revision, byte counts, and SHA-256
values for `UD-Q2_K_XL`, `UD-IQ3_XXS`, `UD-IQ3_S`, and `UD-IQ4_XS`.

The deployment remains SSH-only. The server binds to `127.0.0.1`, requires a
generated API key for Web UI and API routes, and reaches the client browser
through loopback SSH forwarding. No script controls the remote graphical
session.
