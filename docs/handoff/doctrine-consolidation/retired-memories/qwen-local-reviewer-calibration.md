---
name: qwen-local-reviewer-calibration
description: The workstation 9B llama-server reviewer (scratchpad/local-review.sh, 127.0.0.1:18086) is advisory only; calibrated 2026-09-04 at recall 0/3 and no confirmed true positive over ~150 P1 lines
metadata:
  type: project
---

`scratchpad/local-review.sh` (workstation copy at `~/Github/qwen-apu/scratchpad/`) reviews a branch through the Qwen3.8-9B server the qwen-nvidia session serves on 127.0.0.1:18086, serialized on one flock. Calibrated 2026-09-04: on two Codex-reviewed branches it emitted about 150 P1 lines and every one checked against source was false; on the pre-fix lan-open-limits diff where Codex found two P1 and one P2, it found none of them.

**Why:** the user switched reviews to this server while Codex is out of usage until 2026-09-06 7:43 PM Pacific; the switch is only safe if its verdicts are weighted correctly.

**How to apply:** a local P1 is read against the source before the gate; a local NO FINDINGS is no acceptance; the gate and the retained Codex reviews remain the authority. Re-calibrate with `--calibrate DIFF` before trusting a new prompt form. See [[github-and-harness-limits]].
