# The ladder is blocked on the DPM write, not on the harness

```text
status=not run
date=2026-09-03, the device campaign window that ran the E4 holdout, two web admissions,
     the workload-lease admission, and the image phase timing
head=a39c440, which carries the low-async profile, nice 19, and the clamped deepest rung
```

`remote/run-prefill-ladder.sh` was synced to the appliance at a39c440, validated its
plan, took the Vulkan workload lease, and then refused before its first server start:

```text
prefill_ladder_lease=held path=$HOME/qwen-webui-state/vulkan-workload.lock
a forced engine clock policy writes power_dpm_force_performance_level through sudo -n;
run sudo -v and start the campaign again
```

`sudo -n true` answers `sudo: a password is required` on the appliance, and
`/etc/sudoers.d/90-qwen-agent` sets `timestamp_type=global` with a 60-minute timeout, so
one `sudo -v` typed by the operator on the laptop covers the SSH sessions that follow.
No such timestamp existed in this window.

The refusal is correct rather than an obstacle. This document's own design reads every
rung as a ratio under `power_dpm_force_performance_level=manual` with the highest
graphics level selected and the highest fabric level written, because `auto` lets the
governor step `sclk` through 400, 985, 1050, and 1100 MHz inside one arm --
`evidence/image-appliance/phase-timing/` retains exactly that stepping from the same
window. Time to first token and prompt tokens per second are clock-dependent in a way
the E4 witness's token identity and the lease admission's lock transitions are not, so
running the ladder at `auto` would produce rows the registered reading declines.

## The plan the run would have executed

```text
prefill_ladder_depths_requested   512 4096 16384 32768
prefill_ladder_depths_admitted    512 4096 16384 32719
prefill_ladder_prompt_ceiling     32719
prefill_ladder_arm_order          C K K C / C T T C
prefill_ladder_context            32768
prefill_ladder_threads            1
prefill_ladder_row_threads        2
model                             qwen38-2b-distill, sha256 4aa0fb13...
```

The 32768 rung clamps to 32719 under
`model_context - generate_tokens - tail_reserve - prompt_n_slack`, which
`run-prefill-ladder.sh:338` computes as `32768 - 16 - 32 - 1`; the slack term admits one
token of excess of `timings.prompt_n` over the tokenized count, so it is held back from
the prompt the same way the generation length and the tail reserve are. Clamping rather
than skipping is the repair ba64ef3 made. The ledger's own two-thread row supplies the
`C T T C` subject, and the eight arms per depth make 32 arms.

## What the run needs

One `sudo -v` typed on the appliance inside the hour before the campaign starts. A
second requirement follows from the design rather than from the device: `C K K C` is the
control server against a candidate server, and a run passing one binary as both measures
that binary's repeatability instead. The deployed `llama-server` (5dd86b90...) is the
control; the candidate has to be named.
