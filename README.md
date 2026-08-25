# Qwen APU

This repository retains the reproducible setup, policy, source patches,
runtime evidence, and benchmark results for a headless RADV Vulkan Qwen
deployment on a two-compute-unit Raven2 APU. The runtime gives the desktop
priority through a LOW Vulkan queue, one-core CPU affinity, nice value 19, idle
I/O scheduling, one inference slot, and fail-closed rejection of CPU model
execution.

`TASK_TRACKER.md` is the execution ledger. `remote/` contains the host-side
launchers, guards, tests, and benchmark tools. `patches/` reconstructs the
pinned llama.cpp changes. `evidence/` retains raw and synthesized evidence.
`artifacts/bin/` contains the exact verified executables through Git LFS.

The GGUF remains an external hash-pinned dependency because its 2,740,937,888
bytes exceed GitHub Pro's 2 GB Git LFS per-file limit. Run
`remote/download-qwen35-4b-q4km.sh` to obtain and verify it.

The deployment remains SSH-only. The server binds to `127.0.0.1`, the Web UI is
absent, and no script controls the remote graphical session.
