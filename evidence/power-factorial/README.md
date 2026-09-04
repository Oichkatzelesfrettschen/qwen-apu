# The coupled power/CPU/clock factorial campaign

This document registers the hypothesis, the falsifiers, and the arm design
for the campaign `remote/run-power-factorial-campaign.sh` runs, ahead of any
device run. Nothing here has been measured on the appliance: this is the
workstation-side design, the scripts, and their tests. The device run happens
later under the operator's own `sudo`.

Every claim below carries an evidence class. `documented` names a primary
source that states it, `observed` names a reading already retained in this
tree, and `conjecture` names an inference with the falsifier that would settle
it.

## Base commit and owned files

Every arm this campaign runs is built from `origin/main` at `7f747fd` or
later, merged into this branch at `5eb9368`. The files this campaign owns:

| File | Owns |
| --- | --- |
| `remote/cpu-frequency-cap.sh` | the CPU-frequency-cap term: apply/restore/status |
| `remote/compute-state-lease.sh` | the profiles that compose it with the clocks, the memory scanner, and the power envelope |
| `remote/run-power-factorial-campaign.sh` | the arm sequence, the mirrored control bracket, the P4 telemetry gate |
| `remote/run-power-factorial-arm.sh` | the served and bench instruments, the CPU-side endpoint capture |
| `remote/summarize-power-factorial.py` | the verdict per arm |
| `remote/test-cpu-frequency-cap.sh`, `remote/test-compute-state-lease.sh`, `remote/test-run-power-factorial-campaign.sh` | the workstation-side proof that every write restores, that a refused restore is an incident, and that the runner refuses without a transaction |

Every arm requires the Raven2 appliance (`hp14-dk1xxx`), a cached `sudo`
credential (`sudo -v`), `cpupower` (linux-tools for the running kernel,
already installed there), and `ryzenadj` at the path
`remote/power-envelope.sh` resolves. No arm requires anything installed to
"fix" the `cpupower` boost-support discrepancy this document records below;
the sysfs state plus the delivered frequency remain the authority.

## The hypothesis and its falsifier

`evidence/raven2-vulkan-kernel-census/README.md`'s own pipeline census puts
about 97 ms of a 99 to 101 ms 2B decode token on the GPU. The two Zen+ cores
therefore hold the CPU-side remainder -- sampling, dispatch, and the host
side of each Vulkan submission -- to under 4 ms of that token, and Core
Performance Boost can raise either core to 3.1-3.2 GHz on top of the
`_PSS` table's 2.3 GHz ceiling while the GPU does its own work. The
hypothesis this campaign runs against is that capping CPU boost during
steady decode frees package and thermal budget the GPU can spend on GFXCLK
and FCLK, since the package budget and the thermal ceiling are shared
between the two Zen+ cores and the two Vega compute units on one die.

**Falsifier:** a decode rate under P2 (CPU-capped, otherwise P1's own state)
that falls within the in-sweep noise of P1 (uncapped), with no accompanying
change in the FCLK state share the clock sidecar records, refutes the
hypothesis. The comparison is read inside one mirrored sweep, never across
sweeps: CLAUDE.md's own decode-bound and runtime-class analyses measure
30.6% spread on one checkpoint under identical flags across sweeps, so a
cross-sweep reading cannot carry a result this hypothesis is sized to find.

"CPU maximum plus GPU maximum" is not assumed anywhere in this design --
it is exactly the hypothesis under test, and the opposite pairing has
already failed on this part. `evidence/raven2-vulkan-kernel-census/
dpm-authority/` measured `high` and `profile_peak` -- both of which pin
GFXCLK at 1100 MHz, the graphics maximum -- collapse the starred
`pp_dpm_mclk` fabric state to 400 MHz, and the 2B decoded at 6.3 to 7.0
tok/s under either against 6.8 to 8.2 under `auto`. Pinning one clock to its
own ceiling lost fabric bandwidth on this firmware; `compute-state-lease.sh`
refuses both profiles by name for exactly that reason. Nothing here assumes
that capping the CPU's own maximum reaches a different, better-behaved
region of the same firmware's joint clock selection; that is what P2 through
P4 test.

## Design: paired, mirrored, control-bracketed

Every arm is one `compute-state-lease.sh` transaction, so the graphics
clock, the fabric clock, the memory scanner, the CPU frequency cap, and the
package budget are one reversible machine state per arm, proven applied
before the command runs and proven restored (or reported as a
`restoration=failed` incident, ending the transaction with exit 4) on every
exit path.

The campaign runs one mirrored, control-bracketed sequence per checkpoint
rather than one pairwise comparison at a time, the same design
`run-power-envelope-campaign.sh` already runs as its own mirrored quadruple
(control, 20 W, 25 W, control). `01-control-open` and `09-control-close`
both run `serve-auto-baseline` -- the current CPU policy, the DPM level the
governor already selects, and the platform's own stock package limits,
still snapshotted through `platform-default` so the SMU baseline is provable
even though nothing is capped. Their agreement, read under the 20% span
criterion `evidence/power-envelope/README.md` registers, is what licenses
reading every arm between them as an effect of its own compute state rather
than as position in a sequence.

`remote/summarize-power-factorial.py` reads pairwise comparisons out of this
one sequence rather than requiring each pair to run as its own bracket, and
promotes a candidate only where it clears a **one-sided 5% bound** against
its own registered reference arm -- the bound CLAUDE.md's own E4-ladder rung
7 (`run-served-binary-ab.sh`, mirrored C K K C quadruples) states for a
mirrored, control-bracketed comparison on this machine. A candidate that
decodes slower, or faster by less than 5%, reads `not_promoted`: the null
result the falsifier above predicts if the hypothesis is wrong.

| Arm | Slot | Profile | Reference | Nice | CPU cap | FCLK | Package |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| control-open | 01 | `serve-auto-baseline` | -- | 0 | none | auto | stock |
| P1 | 02 | `serve-fixed-package-default` | control mean | 0 | none | 933 fixed | stock |
| P2 | 03 | `serve-fixed-cpu-capped` | P1 | 0 | 2.3 GHz + boost 0 | 933 fixed | stock |
| P3 | 04 | `serve-fixed-cpu-capped-fclk-range` | P2 | 0 | 2.3 GHz + boost 0 | 933-1067 | stock |
| P3 ksm-alt | 05 | `serve-fixed-cpu-capped-fclk-range-ksm-running` | P3 | 0 | 2.3 GHz + boost 0 | 933-1067 | stock |
| P3 cap-alt | 06 | `serve-fixed-fclk-range` | P3 | 0 | none | 933-1067 | stock |
| P3 nice-alt | 07 | `measure-fixed-cpu-capped-fclk-range` (bench instrument) | P3 | 19 | 2.3 GHz + boost 0 | 933-1067 | stock |
| sustained | 08 | `serve-fixed-package-default` | -- | 0 | none | 933 fixed | stock, long window |
| control-close | 09 | `serve-auto-baseline` | -- | 0 | none | auto | stock |
| P4 (gated) | 10 | `serve-fixed-cpu-capped-fclk-range-package-25w` | P3 | 0 | 2.3 GHz + boost 0 | 933-1067 | **25 W, gated** |

P3 rather than P4 is the ladder's unconditional best arm and the base every
factor-pair alternate reads against, because P4 raises the package budget
and this campaign does not raise it by default (see below).

### The nice factor-pair is a scope cut, registered

`run-power-envelope-arm.sh` measures decode through
`measure-served-decode.sh`, which launches through `qwen-launch.sh`, which
starts `monitor-qwen-runtime.sh`; that guard unconditionally renices itself
to 0 and exits `reason=monitor_exited` where it cannot, and lowering a nice
level needs `CAP_SYS_NICE` this transaction's unprivileged child does not
hold. Nice 19 therefore cannot run through the served harness at all, so the
nice factor-pair's alternate rung (`07-p3-nice-alt`) is measured with a
direct `llama-bench` invocation instead -- `run-power-factorial-arm.sh`'s
`bench` instrument -- the same substitution
`evidence/raven2-vulkan-kernel-census/dpm-authority/`'s own nice-probe
makes. That rung therefore reads two different measurement methodologies
against each other rather than one, and `summarize-power-factorial.py`
states that in its own reason column rather than hiding it. **Falsifier:**
a nice-pair result that disagrees in direction with a served-harness
measurement of the same two nice levels, taken later on this same part
outside this campaign, would mean the bench instrument's own overhead (no
KV-cache warm state, no HTTP layer, no launch-chain monitor) is large enough
to move the verdict, and the pair's own reading would need to be retracted.

## The sustained arm and the P4 telemetry gate

The stock envelope (STAPM 15 W / 200 s averaging window, PPT fast 25 W, PPT
slow 20 W) is restored on the laptop and is the state every non-power arm in
this campaign runs in. P4's package-limit increase is not a default arm: it
runs only where an earlier arm's own telemetry shows the stock budget
binding -- a PPT VALUE reading within `QWEN_POWER_FACTORIAL_PACKAGE_
BINDING_MARGIN_MW` (1000 mW default) of its own LIMIT, or the STAPM VALUE
within that same margin of 15000 mW -- read from the later of two
`ryzenadj --info` snapshots `run-power-envelope-arm.sh` already retains at
every arm's own start and end.

The `08-sustained-stock` arm exists to give that gate a receipt worth
reading: it runs the stock envelope (P1's own profile) for
`QWEN_POWER_FACTORIAL_SUSTAINED_GENERATE` tokens, 2400 by default, a margin
over the 200 s STAPM/PPT averaging window at every decode rate CLAUDE.md's
own runtime-class table carries (9.46 tok/s, the fastest of them, would
still take 254 s to emit 2400 tokens). A short arm cannot answer whether the
budget binds over a sustained window; the campaign's earlier short-horizon
arms (`evidence/power-envelope/`) already refuted a short-horizon benefit
from raising the budget and left the sustained question open, which is what
this arm closes. Its own retained fields are the STAPM and PPT VALUE/LIMIT
pairs from both `ryzenadj --info` snapshots and the Tctl trajectory the
`.served` inner arm directory already carries via
`run-power-envelope-arm.sh`'s temperature record.

`run-power-factorial-campaign.sh` runs `08-sustained-stock` inside the
default bracket and evaluates the gate immediately after, admitting
`10-p4-package-25w` only where it reads `binding=yes`.
`QWEN_POWER_FACTORIAL_PACKAGE_RECEIPT` names a directory carrying its own
`ryzenadj-info-end.txt` directly, so an operator can gate P4 on telemetry
from an earlier campaign's own sustained arm rather than always re-measuring
one.

## What is measured, per arm

- Served decode rate (`run-power-envelope-arm.sh`'s own
  `measure-served-decode.sh` call) and the clock sidecar's FCLK/GFXCLK state
  shares, for every `served`-instrument arm.
- Actual per-core CPU frequencies, sampled from `/proc/cpuinfo` at
  `QWEN_POWER_FACTORIAL_CPUINFO_PERIOD_MS` (200 ms default) --
  `run-power-factorial-arm.sh`'s own sampler, retained as
  `cpuinfo-mhz-samples.tsv`.
- `cpupower frequency-info` output, read and retained verbatim before and
  after every arm (`cpupower-frequency-info-start.txt` /
  `-end.txt`).
- GFXCLK and FCLK delivered clock state, package energy
  (`read-package-energy.py`), and Tctl/edge temperature trajectory, all via
  `run-power-envelope-arm.sh`'s own instrument for every `served` arm.
- Graphics-service latency from the probe, where the launch chain's own
  monitor retains `graphics-latency.log`; `measure-served-decode.sh`
  already copies it into the served inner arm's own directory when present.
- QEMU vCPU and ksmd CPU ticks from `/proc`, resolved by `comm` match and
  summed across every task under the resolved pid's own `/proc/PID/task`,
  read at both ends of the arm and reported as `ksmd_ticks_delta` and
  `qemu_ticks_delta`.
- A restoration verification table: `compute-state-lease.sh`'s own
  `restoration=held`/`restoration=failed` line, retained per arm in
  `arms/NAME.lease.stdout`/`.stderr` and read by
  `summarize-power-factorial.py` into its own restoration column. A
  `restoration=failed` line for any arm marks the whole checkpoint
  `restoration_incident`, because a machine left on a forced state after
  one arm invalidates the "read inside one sweep" licensing every later
  comparison depends on.
- Q4_K/Q6_K brackets: read against `evidence/decode-bound-analysis.md`'s
  own achieved-GB/s trunks for the checkpoint under measurement, at
  device-run time rather than computed here.

`run-power-factorial-arm.sh`'s `bench` instrument (the nice factor-pair
alone) carries none of the served energy window, clock sidecar, or
temperature record -- only the CPU-side endpoints this campaign's own
instrument adds, plus `llama-bench`'s own decode rate. That is the scope cut
this document registers rather than hides.

## The `cpupower` boost-support discrepancy, recorded exactly

`cpupower frequency-info` reports `boost state support: Supported: no /
Active: no` on this part, obtained from the northbridge boost-state count
rather than from sysfs. `/sys/devices/system/cpu/cpufreq/boost` reads `1`,
and cores have been observed delivering 3.1 to 3.17 GHz under load, above
the `_PSS` table's 2.3 GHz P0. The authority this campaign reads is the
sysfs `boost` state plus the delivered frequency `/proc/cpuinfo` reports,
not `cpupower`'s own northbridge-derived line; nothing is installed on the
laptop to reconcile the two. `cpu-frequency-cap.sh` writes and reads back
`/sys/devices/system/cpu/cpufreq/boost` directly for exactly this reason,
rather than trusting `cpupower`'s own boost-state report.

## Falsifiers, ahead of any run

1. **The primary hypothesis** (above): P2 within P1's in-sweep noise, no
   FCLK state-share change, refutes CPU-cap-frees-GPU-budget.
2. **The nice factor-pair's methodology**: a served-harness nice-level
   comparison that disagrees in direction with the bench-instrument result
   retracts the bench reading (above).
3. **The sustained-window claim**: `08-sustained-stock` reading no PPT or
   STAPM value within the binding margin of its own limit, across the whole
   2400-token window, means the stock envelope does not bind under this
   campaign's own decode load, and P4 stays gated shut on that checkpoint --
   which is itself an answer to the question this campaign's earlier
   short-horizon arms left open, not an inconclusive run.
4. **The restoration guarantee**: any `restoration=failed` line anywhere in
   a checkpoint's own arm sequence is `compute-state-lease.sh`'s or
   `cpu-frequency-cap.sh`'s own incident report (exit 4) and ends that
   checkpoint's whole sweep `restoration_incident` rather than reading any
   arm inside it, since the licensing every comparison depends on requires
   every arm to have run under a proven, provably-returned machine state.

## Commands

```sh
# Workstation-side gates, all fixture-driven and device-free:
remote/test-cpu-frequency-cap.sh
remote/test-compute-state-lease.sh
remote/test-run-power-factorial-campaign.sh

# The device run, later, under the operator's own sudo -v:
remote/run-power-factorial-campaign.sh MODEL_ID OUTPUT_DIRECTORY
remote/summarize-power-factorial.py OUTPUT_DIRECTORY OUTPUT_DIRECTORY/summary.tsv

# Gate P4 on a receipt from an earlier campaign's own sustained arm instead
# of re-measuring one:
QWEN_POWER_FACTORIAL_PACKAGE_RECEIPT=PRIOR_OUTPUT_DIRECTORY/arms/MODEL-08-sustained-stock.served \
    remote/run-power-factorial-campaign.sh MODEL_ID OUTPUT_DIRECTORY
```
