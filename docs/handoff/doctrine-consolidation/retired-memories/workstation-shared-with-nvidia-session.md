---
name: workstation-shared-with-nvidia-session
description: another session renamed the repo to ~/Github/qwen-nvidia (RTX 4070 Ti fork, its own GitHub repo) and cycles CUDA llama-server on the workstation, so repository gates that refuse on any llama process cannot run here
metadata:
  type: project
---

On 2026-08-29 a second session retargeted a copy of this tree to an RTX
4070 Ti: it renamed `~/Github/qwen-apu` to `~/Github/qwen-nvidia` (remote
`origin` = Oichkatzelesfrettschen/qwen-nvidia, `apu` = qwen-apu) and runs
`~/src/llama.cpp-qwen-nvidia/build-qwen-cuda-sm89/bin/llama-server` sweeps
that restart every few seconds. A fresh clone of qwen-apu was put back at
`~/Github/qwen-apu`.

**Why:** `remote/repository-quality-gates.sh` includes fixtures
(`test-run-graph-alias-ab.sh`, `measure-bench-repeatability`) that refuse
while any `llama-server`/`llama-bench` process exists on the host, so the
gates fail here with "another llama process holds the device" through no
fault of the branch. GitHub Actions is also refusing jobs on the account
("Actions budget").

**How to apply:** run the gates on the laptop from `~/src/qwen-apu-gates`
inside a `qwen-teardown.sh` ... `qwen-launch.sh` window
(`~/qwen-laptop-setup/run-laptop-gates.sh`), and leave `qwen-nvidia` alone.
See [[github-and-harness-limits]] and [[qwen-laptop-repo-copy-and-test-paths]].
