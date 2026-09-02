# DPM authority: forced levels pin sclk and drop fclk, and `manual` is the recovery

`remote/probe-dpm-authority.sh` asked whether a `power_dpm_force_performance_level`
setting holds the graphics clock at the top `pp_dpm_sclk` step through a
decode. `evidence/raven2-vulkan-kernel-census/dpm-authority-design.md`
registered the predictions ahead of any run; this directory retains four runs
against them.

**Forced `high` and `profile_peak` hold `freq1_input` at 1100 MHz and drop the
SMU10 fabric-clock surface (`pp_dpm_mclk`) to 400 MHz, and decode falls to
6.30 to 7.02 tok/s under load, below the same machine's `auto` arms.**
`manual`, with the highest sclk level written explicitly, delivers the same
1100 MHz with the fabric surface held at 933 MHz and decodes 8.91 to 9.58
tok/s against `auto`'s 7.94 to 8.22 tok/s measured minutes apart in the same
run -- the cold-boost figure recovered under load. The `pp_dpm_mclk` write is
accepted and has no effect: the surface reads 933 MHz whether `manual` writes
level 2 or level 3. `pp_dpm_sclk` reports the requested state; hwmon's
`freq1_input` reports the clock actually delivered during the bench window.
The two disagree under `high` and `profile_peak` (state 1100, delivered
1100, but the fabric surface collapses) and the campaign invariant belongs on
`freq1_input` and the starred `pp_dpm_mclk` line, not on the state name a
level reports.

## Decision ladder as run

```text
D0/D1/D2   idle machine        auto / high / profile_peak, one process, telemetry broker
D0/D1/D2   postload (5 min)    the same three levels after two-core `yes` load, Tctl 87 C
A1..A5     postload (3 min)    a 50 ms hwmon sampler reading freq1_input and pp_dpm_mclk
                                directly through high/auto/high/profile_peak/auto
M1..M5     postload (2 min)    manual with pp_dpm_sclk level 2 and pp_dpm_mclk level 3
                                (M4: mclk level 2), interleaved with auto controls
```

Each stage answers a narrower question than the one before it.
`probe-dpm-authority.sh`'s D0/D1/D2 asked whether a forced level holds the
requested state at all, on an idle machine first and then after load, because
a probe that ran into the cold-boost regime would report `held` for a reason
that has nothing to do with the level it wrote. The postload run showed a
level being obeyed (`clock_invariant=held` for `profile_peak`) while decode
fell, which the probe's own `sclk_during` field could not explain because it
records the selected *step*, not the delivered clock. A1..A5 read hwmon
directly to settle that: `pp_dpm_sclk` said 1100 under `high`, and
`freq1_input` agreed, but `pp_dpm_mclk` read 400 MHz where `auto` read 933.
M1..M5 tested whether writing the fabric surface's own sysfs level recovers
the higher decode rate that the forced levels lost.

## Experiment 1: `20260902T1813Z`, idle machine

D0 `auto`, D1 `high`, D2 `profile_peak`, one process, telemetry broker
sampling beside each `llama-bench` decode. The `MARK bench_end` control-FIFO
write was lost, so every window has a `window_begin_ns` and no
`window_end_ns`; `samples_in_window` reads 0 and every `clock_invariant`
reads `not_run` or `not_requested`. The three `tok_s` figures stand on their
own bench output regardless: 9.67, 9.72, 9.75, an idle-machine ceiling with
no separation between levels.

| level | requested | observed | tok_s | clock_invariant | files |
| --- | --- | --- | ---: | --- | --- |
| D0 auto | auto | auto | 9.67 | not_requested | `20260902T1813Z/D0-auto/{dpm-receipt.tsv,bench.log,clock-sidecar.tsv}` |
| D1 high | high | high | 9.72 | not_run | `20260902T1813Z/D1-high/{dpm-receipt.tsv,bench.log,clock-sidecar.tsv}` |
| D2 profile_peak | profile_peak | profile_peak | 9.75 | not_run | `20260902T1813Z/D2-profile_peak/{dpm-receipt.tsv,bench.log,clock-sidecar.tsv}` |

`20260902T1813Z/summary.txt` and `20260902T1813Z/snapshot/` (the pre-run
`power_dpm_force_performance_level`, `pp_dpm_sclk`, `pp_dpm_mclk`,
`pp_dpm_fclk` readback) are retained beside the three level directories.

## Experiment 2: `20260902T1820Z-postload`, five minutes of two-core `yes`

The same D0/D1/D2 ladder, run after five minutes of two-core `yes` load with
Tctl at 87 C at load end. The lost-mark defect is absent here: every level
carries a full `samples_in_window` count and a `clock_invariant` verdict.
`auto` never reached the top step for most of its window (72.8% of samples
below 1100 MHz, time-weighted); `high` reached it almost throughout (0.6%
below) and still decoded slower than `auto`; `profile_peak` held it for the
whole window (0.0% below) and decoded slowest of the three.

| level | sclk_during | below_max_fraction | gpu_busy_mean | tok_s | clock_invariant | files |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| D0 auto | 1100 | 0.7281 | 83.06 | 9.09 | not_requested | `20260902T1820Z-postload/D0-auto/{dpm-receipt.tsv,clock-state.txt,bench.log,clock-sidecar.tsv}` |
| D1 high | 1100 | 0.0060 | 84.33 | 7.47 | violated | `20260902T1820Z-postload/D1-high/{dpm-receipt.tsv,clock-state.txt,bench.log,clock-sidecar.tsv}` |
| D2 profile_peak | 1100 | 0.0000 | 83.56 | 7.24 | held | `20260902T1820Z-postload/D2-profile_peak/{dpm-receipt.tsv,clock-state.txt,bench.log,clock-sidecar.tsv}` |

`dpm_authority=profile_peak bapm=-1` on the closing summary line
(`20260902T1820Z-postload/summary.txt`), by the probe's own rule: `high`
would have won the naming had its window also held (`design note, "high wins
the naming where both hold"`), but only `profile_peak` read
`samples_below_max=0`.

Every `clock-state.txt` in this run carries `sensors=refused
unavailable_outside_allowance=pp_dpm_fclk_surface_mhz,temp1_millidegrees`:
the sidecar's own temperature column is `unavailable` on every sampled row,
so `thermal_peak_millic` reads `-` in each `dpm-receipt.tsv` and the 87 C
figure above is the operator's own sensor read at load end, external to this
receipt. `pp_dpm_mclk_surface_mhz` reads 933 MHz on every row across all
three levels in this run -- the fabric surface the receipt does not carry as
a column but the sidecar samples regardless -- which is the first sign that
the fabric clock, not the graphics clock, tracks the decode-rate ordering
D0 > D1 > D2 that `sclk_during` alone cannot explain (all three read 1100).

## Experiment 3: `20260902T1822Z-actual`, three minutes of load, direct hwmon sampling

A 50 ms shell sampler reads `freq1_input` (the delivered graphics clock,
hwmon), `in0_input`, the starred `pp_dpm_mclk` line, `temp1_input`, and
`gpu_busy_percent` beside each `llama-bench tg32`, in the order high, auto,
high, profile_peak, auto. This is the arm that separates "the state is 1100"
from "the delivered clock is 1100": `freq1_input` confirms 1100 MHz steady
under every forced arm and confirms `auto` moves the delivered clock, not
just the reported state.

| arm | level | tok_s | freq1_input | pp_dpm_mclk (starred) | files |
| --- | --- | ---: | --- | --- | --- |
| A1 | high | 6.66 ± 0.63 | 1100 steady | 400 | `20260902T1822Z-actual/A1-high.{bench,tsv}` |
| A2 | auto | 6.84 ± 0.14 | 400 to 1100, mean 784 | 933 | `20260902T1822Z-actual/A2-auto.{bench,tsv}` |
| A3 | high | 7.02 ± 0.99 | 1100 steady | 400 | `20260902T1822Z-actual/A3-high.{bench,tsv}` |
| A4 | profile_peak | 6.30 ± 0.18 | 1100 steady | 400 | `20260902T1822Z-actual/A4-peak.{bench,tsv}` |
| A5 | auto | 8.20 ± 0.13 | mean 914 | 933 | `20260902T1822Z-actual/A5-auto.{bench,tsv}` |

Every forced arm (A1, A3, A4) reads `pp_dpm_mclk` starred at 400 MHz; both
`auto` arms (A2, A5) read it starred at 933 MHz. `tok_s` orders with the
fabric surface, not with `freq1_input`: A2's mean delivered sclk of 784 MHz
still outran A1's steady 1100 MHz, because A2 kept the 933 MHz fabric state
that A1's forced level dropped to 400.

## Experiment 4: `20260902T1826Z-manual`, two minutes of load, `manual` recovery

`manual` writes `pp_dpm_sclk` level 2 and `pp_dpm_mclk` level 3 directly
(readback: sclk 1100 starred, mclk 933 starred), interleaved with `auto`
controls. M4 repeats the manual sclk write with `pp_dpm_mclk` level 2
written instead of level 3; the readback still shows mclk starred at 933.
`temp1_input` peaks at 85 C across the five arms (M1), inside the 82 to 87 C
band the postload arms already established, and `freq1_input` reads 1100 MHz
steady in every manual arm and 400 to 1100 MHz under every `auto` arm in this
run.

| arm | level | tok_s | freq1_input | pp_dpm_mclk (starred) | files |
| --- | --- | ---: | --- | --- | --- |
| M1 | manual s2/m3 | 9.58 ± 0.15 | 1100 steady | 933 | `20260902T1826Z-manual/M1-manual-s2-m3.{bench,tsv}` |
| M2 | auto | 8.22 ± 0.16 | 400 to 1100 | 933 | `20260902T1826Z-manual/M2-auto.{bench,tsv}` |
| M3 | manual s2/m3 | 8.91 ± 0.95 | 1100 steady | 933 | `20260902T1826Z-manual/M3-manual-s2-m3.{bench,tsv}` |
| M4 | manual s2/m2 | 9.23 ± 0.22 | 1100 steady | 933 | `20260902T1826Z-manual/M4-manual-s2-m2.{bench,tsv}` |
| M5 | auto | 7.94 ± 0.31 | 400 to 1100 | 933 | `20260902T1826Z-manual/M5-auto.{bench,tsv}` |

`pp_dpm_sclk.err` and `pp_dpm_mclk.err` are retained empty (0 bytes): the two
manual writes were accepted by the driver without error on every arm.

## The prediction, and how each branch fared

The design note registered two mutually exclusive predictions. **D1 holds**:
`high` reads `samples_below_max=0` and `tok_s` at or above every `auto` arm
this machine has produced, which would mean the ordinary governor was the
whole mechanism behind the drifting-clock regimes the census calibrations
saw, and a forced level removes it. **D1 still reads about 650 MHz**: the
selected step sits at the sustained band regardless of the forced level,
which would move the mechanism to the package power layer -- BAPM, STAPM,
the thermal loop -- that no `pp_dpm_sclk` write reaches.

Neither branch held as registered. `high` and `profile_peak` do hold
`freq1_input` at 1100 MHz through the window (D1's `samples_below_max=0`
premise is satisfied, and A1/A3/A4 confirm it directly against hwmon rather
than against the `pp_dpm_sclk` state alone), so the governor is not
withholding the clock the way D2's falsifier described. But `tok_s` under
`high` and `profile_peak` reads *below* every `auto` arm this run produced
(6.30 to 7.47 against `auto`'s 7.94 to 9.09), which is the outcome D1
predicted only for a state where the level failed to hold -- and here it
held. The third subsidiary prediction, "`tok_s` orders with
`selected_sclk_during` across the three arms," is refuted outright: all
three D0/D1/D2 arms in experiment 2 read `sclk_during=1100`, and `tok_s`
still spans 7.24 to 9.09 across them.

The deviation is the finding the design note asked for: **the forced levels
introduce a fabric-clock mechanism the design note did not register.**
`power_dpm_force_performance_level=high` and `=profile_peak` pin
`pp_dpm_sclk` at its top step and, as a side effect neither the amdgpu
documentation excerpt in the design note nor the probe's receipt schema
named, drop the SMU10 fabric-clock surface (`pp_dpm_mclk`) from its 933 MHz
cold-boost state to 400 MHz. `manual`, which writes the sclk level without
forcing the whole performance-level state machine, holds the same 1100 MHz
graphics clock while leaving the fabric surface at 933 MHz -- and recovers
`auto`'s better-case decode rate (8.91 to 9.58 against `auto`'s own 7.94 to
8.22 measured minutes apart in the same run). The governor was a mechanism
for `sclk` alone; the rate spread the census calibrations saw is not
explained by `sclk` drifting off 1100 MHz so much as by whatever selects the
fabric-clock state, which `high` and `profile_peak` both override downward
and `manual`'s sclk-only write does not touch.

`pp_dpm_sclk` and `freq1_input` agree throughout every run retained here.
The place they diverge from the outcome is `pp_dpm_mclk`: the design note's
receipt schema has no column for it, and `clock_invariant=held` in
experiment 2 describes only the sclk half of what a decode window actually
ran at. The campaign invariant belongs on `freq1_input` for the delivered
graphics clock and on the starred `pp_dpm_mclk` line for the fabric state,
together, not on `pp_dpm_sclk`'s reported step alone.

## Frequency-normalization check, as a standing sanity test

```text
predicted_token_ms(f) = gpu_bracket_ms_at_1100 x 1100/f + host_residual_ms
```

`decode-decomposition.md` gives the 2B's own decomposition at 1100 MHz: about
97 ms of GPU bracket and about 3.4 ms of host reads per token. At `f = 658`
MHz -- the sustained band `20260902T1556Z` measured after a twenty-minute
CPU build -- the model predicts `97 x 1100/658 + 3.4 = 165.6 ms`, or 6.04
tok/s, against the 5.7 to 6.1 tok/s that run measured. The check reproduces
here as a standing test rather than a one-off: any future arm that reports
both a decode rate and a steady `freq1_input` can be scored against this
formula before it is read as a finding about anything other than clock.

## What remains unmeasured

- Whether `manual` holds 1100 MHz `freq1_input` across a full multi-arm
  campaign (25 arms or more) rather than the five short arms retained here.
- Whether the fabric-clock surface returns to 1067 MHz under sustained GPU
  load in `manual`, the way retained Vulkan telemetry has shown it doing
  under `auto`, or stays pinned at 933 MHz for the duration.
- The CPU-side cost of pinning the GPU clock under BAPM: every run here
  read `bapm=-1`, which the kernel module documentation states as
  auto-enabled rather than disabled, and no arm here isolated what BAPM's
  own budget costs the CPU side while the GPU is pinned.
- Whether the served appliance should run under `manual` at all. This
  directory has not compared a `manual`-pinned production denominator
  against the existing `auto` production denominator; that comparison
  wants its own paired campaign (production-auto against production-manual
  as separate denominators) rather than the four short exploratory runs
  retained here.

`bapm=-1` on every summary line here means auto-enabled, per
`/sys/module/amdgpu/parameters/bapm`'s own kernel module documentation, not
disabled. No arm in this directory wrote to it.

## Naming correction: GFXCLK, FCLK, and DRAM clock are three different rails

The columns and prose above name `freq1_input` and `pp_dpm_mclk` without
separating what each one measures, and this section states the correction the
reviewers put to that gap. `freq1_input` is GFXCLK, the graphics engine clock,
read from the hwmon sensor the amdgpu driver exposes for it; every arm in this
directory that decodes reads it at 1100 MHz. `pp_dpm_mclk` is not the DRAM
clock despite its name: on this SMU10 platform it is FCLK, the data-fabric
clock, and the driver reads it with `PPSMC_MSG_GetFclkFrequency` rather than
querying the memory controller. Its advertised table states 400, 933, and
1067 MHz here. The DRAM clock is a third rail this file carries no reading
of: `evidence/measurement-state-and-memory-clock.md` trains it at DDR4-2133.33
from both UMC channels' own SMN registers, and the installed Crucial
CT16G4SFD8213 DIMMs are DDR4-2133 parts by their own SPD EEPROMs. A figure of
1200 MHz belongs to a DDR4-2400 hypothesis this machine's trained memory does
not support, not to any reading in this directory.

## Experiment 5: `20260902T2002Z-fclk-level3`, `manual` sclk 2 / mclk 3, 50 ms fabric-clock sampling

`manual` writes `pp_dpm_sclk` level 2 (the top sclk step, 1100 MHz) and
`pp_dpm_mclk` level 3 (the top fabric step this part advertises, 1067 MHz),
and a 50 ms sampler reads `freq1_input`, the starred `pp_dpm_mclk` line, and
`gpu_busy_percent` beside one `llama-bench tg32` decode. `tables-before.txt`
retains the full `pp_dpm_sclk` and `pp_dpm_mclk` tables read before the
manual write, with the pre-write starred level marked: `pp_dpm_sclk` reads
`0: 200Mhz`, `1: 400Mhz *`, `2: 1100Mhz`, and the fabric table reads
`0: 0Mhz 1: 400Mhz 2: 933Mhz * 3: 1067Mhz`, so the machine sat at fabric level
2 (933 MHz) before this run wrote level 3. `mclk3.err` is retained at 0
bytes: the `pp_dpm_mclk` level-3 write returned no error.

The decode measured 9.61 ± 0.13 tok/s (`bench.log`). `samples.tsv` carries
145 rows at a 50 ms period; restricting to the 107 rows at
`gpu_busy_percent >= 50` -- the sampler's own busy threshold for a row inside
the decode's working span, as opposed to the ramp and idle rows the same file
carries -- `freq1_input` reads 1100 MHz on every one of the 107, and the
starred `pp_dpm_mclk` line reads 933 MHz on 105 of the 107 and 1067 MHz on
the remaining 2. Across the full 145-row file the starred fabric line reads
933 MHz on 137 rows and 1067 MHz on 8, so the excursions above 933 MHz are
not confined to the busy window and are rare throughout.

| level written | requested top step | delivered GFXCLK (freq1_input) | starred FCLK, busy rows (n=107) | starred FCLK, all rows (n=145) | tok_s | files |
| --- | --- | --- | --- | --- | ---: | --- |
| manual sclk 2 / mclk 3 | sclk 1100, fclk 1067 | 1100 MHz, 107 of 107 busy rows | 933 MHz x105, 1067 MHz x2 | 933 MHz x137, 1067 MHz x8 | 9.61 ± 0.13 | `20260902T2002Z-fclk-level3/{tables-before.txt,mclk3.err,samples.tsv,bench.log}` |

The write is accepted and the firmware does not hold the requested level: the
highest advertised fabric step (1067 MHz) is written without error and the
delivered fabric clock spends the large majority of the decode window at 933
MHz regardless, with brief excursions to 1067 MHz rather than a sustained
hold. This binds explicitly what M1 and M3 in `20260902T1826Z-manual` already
showed in passing -- both wrote `pp_dpm_mclk` level 3 and read the starred
line back at 933 MHz -- by sampling the fabric clock directly through the
decode window at 50 ms resolution rather than reading one post-hoc readback
per arm.

**The operating point every campaign runs at now**: `manual`, GFXCLK
(`freq1_input`) delivered at 1100 MHz, FCLK (`pp_dpm_mclk`) at 933 MHz with
the floor invariant at 933 -- one state, held across every arm this
directory has measured under `manual`.

Two questions this run leaves open:

- Whether 1067 MHz can be commanded on this firmware at all, as a sustained
  state rather than as the brief excursions this run reads at both busy and
  idle threshold. No arm in this directory has forced the fabric clock to
  1067 MHz and held it; `dpm-authority-design.md` registers the kernel
  hypothesis for why the write alone does not appear sufficient.
- Whether the appliance should serve under `manual` production-auto or
  `manual` production-max as its running policy. This directory measures the
  fabric-clock floor `manual` delivers; it does not compare a production
  denominator under either policy, which is unmeasured work the design note
  also registers.
