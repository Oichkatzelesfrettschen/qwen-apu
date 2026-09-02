# DPM authority: making 1100 MHz an invariant rather than a regime

`remote/probe-dpm-authority.sh` asks one question of the Raven2 appliance:
does a `power_dpm_force_performance_level` setting hold the selected graphics
clock at the top `pp_dpm_sclk` step through a decode. This file states the
instrument, the receipt, the predictions, and the falsifiers ahead of any run
on the device, so a later number is read against a claim that existed before
it. It carries no result. A run retains its output directory under a
UTC-stamped subdirectory of this one and this file gains a link to it.

## What motivates the question

The census calibrations measure a clock that moves without being asked to.
`20260902T1302Z` and `20260902T1417Z` each read 1100 MHz over the first nine
slots, about five minutes of arms, then settled between 750 and 857 MHz for
the rest of the campaign with die temperature falling rather than rising
(`measured`, README.md and each run's `arms.tsv`). `20260902T1556Z` started
one second after a twenty-minute build on the laptop's own two cores and
settled at 658 MHz, a third band below both (`measured`, that run's
`arms.tsv` and README.md).

Decode follows it. The 2B token decomposes into about 97 ms of GPU bracket
and about 3.4 ms of host reads (`derived`, `decode-decomposition.md`). Scaling
the GPU half by 1100/658 gives 162.2 ms, and 165.6 ms with the host half
added, which is 6.04 tok/s against the 5.7 to 6.1 tok/s those arms measured
(`derived` against `measured`). The clock rather than any candidate under
test is what moved that campaign's rates, and the campaign answered by
building a regime taxonomy around it: `QWEN_CENSUS_SCLK_BAND`, a warmup
precondition, a modal-share window, and an `off_regime_arms` count. Every one
of those exists to make an uncontrolled variable comparable rather than to
remove it.

The kernel documents two settings that would remove it. `high` forces the
highest power state. `profile_peak` pins SCLK, MCLK, and PCIe at their peak
values with clock and power gating disabled, which the amdgpu documentation
describes as the profiling mode. Neither has been measured on this part
inside a decode window.

## The instrument

Three levels run in one process, in the order D0 `auto`, D1 `high`, D2
`profile_peak`, each as one short `llama-bench` decode at nice 19 with the
telemetry broker sampling beside it. The order is least invasive first, so
the ordinary governor's own behavior is measured on the machine state the
probe found rather than on the state a forced level left behind.

The window is the bench's own execution span, taken in the record's clock.
`telemetry-broker.c` stamps every row with `CLOCK_MONOTONIC`, so the probe
drives the broker's control FIFO with `MARK bench_start` and `MARK bench_end`
and reads the two `# mark name=... monotonic_ns=...` lines back out of the
drained record. A wall-clock instant would name a different epoch and select
no rows.

`validate-clock-sidecar.py` owns the reading. Its `--required-sclk-mhz` takes
the top step read from `pp_dpm_sclk` and turns the modal observation into a
counted condition at a one-percent tolerance, and its `clock_state=` line
carries the modal step, its share, the window sample count, and the busy
mean. The probe reads those two lines rather than counting the same rows a
second time; the one figure it takes off the record itself is the thermal
peak, because the validator reports Celsius at one decimal where the receipt
row states the sensor's own millidegrees.

Two properties of the reading are named rather than assumed. The DPM
surfaces sit on `telemetry-broker.c`'s tenth-period channel
(`DPM_PERIOD_MULTIPLE` 10), so the 20 ms sample period puts `pp_dpm_sclk` at
200 ms and the receipt records `pp_dpm_period_ns` read back from the record's
own `# sample_rates` header instead of asserting a rate. Every column is
emitted on every row and a row between two channel reads repeats the previous
reading, so the counts are time-weighted rather than measurement-weighted --
which is the figure a decode-rate claim wants, and is what
`below_max_fraction` means.

The probe refuses before it touches anything: a missing cached root
credential names `sudo -v` and stops, since a probe that prompted would hold
the device with a terminal open; a live `llama-server` or `llama-bench` stops
it, since every clock reading would then read that process; an existing
output directory stops it, because this is a single run rather than a
resumable ledger. It snapshots the level and the three `pp_dpm_*` surfaces
and restores the level from an EXIT, INT, TERM, and HUP trap, printing
`dpm_restore=held` or `dpm_restore=violated` from the readback rather than
from the request.

`auto` and `high` are the levels the question rests on, so a refused write or
a readback disagreeing with the request ends the probe. `profile_peak` is the
level this part is most likely to decline, so its refusal is recorded as
`dpm_level=unsupported` with the firmware's own error text and the chain
continues to name whichever authority held.

## The receipt

One `dpm-receipt.tsv` per level, keyed rows:

```text
requested_performance_level   observed_performance_level
available_sclk_levels         max_sclk_mhz
selected_sclk_before          selected_sclk_during     selected_sclk_after
samples_in_window             samples_at_max           samples_below_max
below_max_fraction            thermal_peak_millic      gpu_busy_mean
tok_s                         clock_invariant
sclk_share                    pp_dpm_period_ns
window_begin_ns               window_end_ns
sidecar_verdict               bench_status
```

`clock_invariant` reads `held` where `samples_below_max` is 0, `violated`
where it is not, `not_requested` for D0 because a governor asked for nothing
cannot violate a policy, `not_run` where the bench carried no `tg` row for
the requested token count or the window placed no readable step, and
`unsupported` where the firmware declined the level. `held` is therefore
stated against a real decode alone.

`sidecar_verdict` is the validator's structural verdict with its own
invariant failure removed from the list, so a hovering governor refuses the
invariant while the record stays structurally accepted.

One summary line per level, and one closing line:

```text
dpm_level=NAME observed=.. sclk_during=.. below_max_fraction=.. tok_s=.. clock_invariant=..
dpm_authority=high|profile_peak|none bapm=..
```

`high` wins the naming where both hold, because it leaves clock and power
gating in place where `profile_peak` disables both, so a campaign running
under it measures a machine closer to the served one.

## The predictions, registered ahead of the run

**D1 holds.** `high` reads `samples_below_max=0` across its window and
`tok_s` lands at or above every `auto` arm this machine has produced at the
2B's tuple. The ordinary governor was the mechanism behind the three regimes,
and a forced level removes it. Consequence: the census stops waiting out a
regime and starts asserting one.

**D1 still reads about 650 MHz.** `high` applies, the readback agrees, and
the selected step inside the window sits at the sustained band anyway, at or
near the 658 MHz `20260902T1556Z` measured after a CPU build. The governor is
then falsified as the mechanism: the clock is being held down by a budget
above it, and the target moves to the package power layer -- BAPM, STAPM, and
the thermal loop -- which no setting in this probe reaches. A `dpm_authority=none`
verdict is that finding, and it is a result rather than a failure.

The two are distinguished by a pair rather than by a single figure. D0 asks
for the same top step and reports the counts while reading `not_requested`,
so its `below_max_fraction` is the run's own measurement of how far `auto`
drifts, and D1's fraction against it is the comparison -- two arms that met
the same machine minutes apart inside one run, which is the in-sweep rule
this machine's 30.6% between-sweep spread already imposes on every rate. D1
at 0 against a positive D0 is the first prediction; the two fractions
agreeing is the second. The probe is run in a state that gives the second
prediction its best chance: after a sustained CPU load rather than on a cold
machine, since a probe run into the boost regime would report `held` for a
reason that has nothing to do with the level it wrote.

Three subsidiary predictions carry their own falsifiers.

- D2 `profile_peak` applies on this part. A refused write reads
  `dpm_level=unsupported` and settles nothing about the mechanism, since a
  level that never applied measured nothing.
- D2 holds wherever D1 holds. D2 holding where D1 does not places the
  mechanism in the clock or power gating that `profile_peak` alone disables,
  which is a narrower target than the package budget.
- `tok_s` orders with `selected_sclk_during` across the three arms. A held
  1100 MHz arm decoding no faster than a hovering 650 MHz arm refutes the
  clock account of the rate spread outright, and the 97 ms GPU bracket that
  account rests on is what would then be wrong.

The BAPM state is an observation on the summary line and nothing more. The
probe reads `/sys/module/amdgpu/parameters/bapm` and writes nothing to it, so
a `none` verdict names the state its refusal was measured under and leaves
the next experiment to choose what to do about it.

## The consequence for the campaigns

A `held` verdict replaces the regime taxonomy in the performance denominator
with three contract rows:

```text
engine_clock_policy            auto | high | profile_peak
engine_clock_required_mhz      the top pp_dpm_sclk step the policy pins
clock_below_required_fraction  0
```

Under those rows a campaign states the clock it ran at rather than measuring
which band it drifted into. `QWEN_CENSUS_SCLK_BAND`, the warmup precondition,
`regime_sclk_mhz`, `regime_delta`, and `off_regime_arms` all exist to make
arms comparable across an uncontrolled clock, and a policy that pins the
clock retires them: a pair is comparable because both arms met the same
stated invariant, and an arm that fails it is refused rather than
reinterpreted. The third row is the falsifier that keeps the first two
honest, since a policy row asserting a level proves nothing without the
count that the level was obeyed inside each arm's own request window.

A `none` verdict leaves the taxonomy where it is and moves the investigation
up one layer, and the retained receipts are then the evidence that the DPM
interface was not the place to look.

## The fabric-clock ceiling: a kernel hypothesis registered ahead of a prototype

`dpm-authority/20260902T2002Z-fclk-level3/` measured `manual` writing the
highest advertised fabric step accepted without error and delivered anyway at
933 MHz on 105 of 107 busy-window samples, with 1067 MHz reached on only 2.
`high` and `profile_peak` fall further, to 400 MHz (`dpm-authority/README.md`,
experiments 2 through 4). Three settings now agree in direction -- none holds
the fabric clock at its advertised ceiling -- and this section registers a
kernel-level hypothesis for why, ahead of the prototype that would test it.

`smu10_hwmgr.c`'s `high` and `profile_peak` handling issues
`SetHardMinFclkByFreq` and `SetSoftMaxFclkByFreq` against
`SMU10_UMD_PSTATE_PEAK_FCLK`, a hard-coded 1200 MHz value rather than the
firmware table's own highest entry. This platform's table tops out at 1067
MHz (`pp_dpm_mclk`, `dpm-authority/20260902T2002Z-fclk-level3/tables-before.txt`),
so a request for 1200 MHz asks the firmware for a step it does not carry. The
observed fall to 400 MHz under both `high` and `profile_peak` is consistent
with the firmware rejecting an unsatisfiable request and returning to a
low fabric state rather than clamping to its own nearest available step. This
is stated as a hypothesis rather than a finding: no run in this directory has
read the kernel's own request value off the wire, and the 400 MHz floor is
equally consistent with a package-power mechanism unrelated to the requested
frequency.

**Falsifier.** A kernel patched to request the platform's own table maximum
(1067 MHz) rather than the hard-coded 1200 MHz constant, under `high`,
delivering 1067 MHz sustained through a decode window at the same 50 ms
sampling this directory already uses. Meeting the falsifier moves the fabric
clock from an observed 933 MHz floor to a commanded 1067 MHz ceiling under a
governor setting rather than under `manual`'s undocumented step write;
failing to meet it after removing the 1200 MHz constant would move the
mechanism to the package-power layer the earlier predictions in this file
already named as the alternative.

The prototype this falsifier requires is a kernel patch, a rebuild, and a
boot -- work this file registers as its own experiment rather than folding
into a calibration run. It follows E4 and E1 in the boot-level experiment
sequence, as a separate boot-level arm with its own before/after table
capture and its own 50 ms sampling window, not mixed into any campaign's
performance denominator until it either meets or fails the falsifier above.

## ROCm 10 and the gfx902 target: registered as a bounded ladder, not a plan

ROCm 10's Core SDK release lists no `gfx902` target, and TheRock's own build
matrix omits `gfx902` from its table. RADV Vulkan stays this repository's
primary compute path on this device; nothing above depends on HIP building.

Where a HIP arm is wanted regardless, it runs as an isolated eight-step
ladder rather than as a single build attempt, so a failure names the exact
step rather than the whole toolchain: compile a trivial kernel with
`--offload-arch=gfx902`; enumerate the device; run a vector-add kernel; run a
shared-memory, wave64 kernel; resolve the device library without a `gfx900`
override; load `hipBLAS` only after those four succeed; run a minimal
llama.cpp HIP bench only after `hipBLAS` loads; and only then run an ABBA
comparison against the fixed-clock RADV baseline this directory's `manual`
operating point now supplies. The ladder follows E4 and E1 the way the
fabric-clock falsifier above does, and it ends at the first failing step
rather than proceeding past it -- a `gfx900`-fallback device library
resolving where the fifth step asks for none, for instance, would report a
compatibility shim rather than native `gfx902` support, and every step after
it would be measuring the shim.
