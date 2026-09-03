# The ladder is blocked on the DPM write, not on the harness

```text
status=not run
date=2026-09-03, the device campaign window that ran the E4 holdout, two web admissions,
     the workload-lease admission, and the image phase timing
head=a39c440 when the refusal was captured; 0bfe788 when the lane was declared ready
```

The lane advanced to 0bfe788 while this window was still open -- 4906f7b runs each arm
under the low-async profile at nice 19 read back from `/proc` and recorded in
`inputs.tsv` and the `arms.tsv` `server_nice` column, 1d3f8b1 takes the lease before the
output directory is created, and a merge brought main in. The refusal below was captured
at a39c440 and applies unchanged at 0bfe788: `git diff a39c440 0bfe788 --
remote/census-arm-lib.sh` is empty, so the whole clock authority is byte-identical, and
the only change the diff shows in `run-prefill-ladder.sh`'s clock region is a comment.
`sudo -n true` still answers `sudo: a password is required` on the appliance at the end
of this window.

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

**A sudo timestamp that outlives the campaign, not one that starts it.** A single
`sudo -v` before the run is what this record first asked for and it is wrong. The
acquire and the restore fail differently:

```text
census-arm-lib.sh:387  census_engine_clock_write   sudo -n tee ... || exit 2
census-arm-lib.sh:475  census_engine_clock_restore sudo -n tee ... >/dev/null 2>&1 || true
```

The acquire refuses loudly, which is the refusal this window met. The restore discards
its write's exit status, so a restore attempted past
`/etc/sudoers.d/90-qwen-agent`'s 60-minute `timestamp_type=global` timeout writes
`power_dpm_force_performance_level` through an unauthorized `sudo -n`, continues, and
leaves the appliance pinned at `manual` with the highest graphics and fabric levels
selected for every workload that follows.

The failure is reported, and reported weakly. `census_engine_clock_restore` reads the
node back after writing and prints one of three lines:

```text
dpm_restore=restored level=auto requested=auto ...
dpm_restore=mismatch level=manual requested=auto ...
dpm_restore=unreadable level=- requested=auto ...
```

A failed restore therefore emits `dpm_restore=mismatch` naming the level the device is
actually in. What it does not do is fail: the function returns 0, the campaign's exit
status is unchanged, and nothing refuses. An operator who reads the tail of the run log
sees the stranded clock; one who reads only the exit status does not.

Whether this campaign crosses the hour is unmeasured. No ladder arm has run on this
machine, so no per-arm duration exists: the 1800-second per-request timeout is a
ceiling rather than a floor, and the 32 cooldowns total eight minutes. The requirement
does not depend on the answer, because the restore's exit status does not either. Two
ways to close it, and the operator picks one before starting:

```text
refresh   keep the sudo timestamp alive for the campaign's duration
verify    tee the run's stdout, read its dpm_restore= line, and read
          power_dpm_force_performance_level with pp_dpm_sclk and pp_dpm_mclk off the
          device afterwards; restore the line's requested= policy and its sclk_level=
          and mclk_level= indices by hand where they differ
```

`census_engine_clock_restore` discarding its write's status while still reporting the
resulting mismatch is a property of `remote/census-arm-lib.sh` rather than of the
ladder, and it belongs to the lane that owns that file. It is named here because the
ladder is the longest campaign that calls it, and a restore that exited nonzero on a
mismatch would turn this operational requirement into a refusal the harness raises by
itself rather than a line an operator has to look for.

A second requirement follows from the design rather than from the device: `C K K C` is
the control server against a candidate server, and a run passing one binary as both
measures that binary's repeatability instead. The deployed `llama-server` (5dd86b90...)
is the control; the candidate has to be named.
