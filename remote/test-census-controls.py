#!/usr/bin/env python3
"""The three census campaign helpers over synthetic records.

validate-clock-sidecar.py accepts a record whose header, columns, rows,
footer, period, cost, sensors, adjacent gaps, and window coverage each
hold, and refuses one record per broken condition; a hole the run-wide
achieved period absorbs is refused by the gap bound where it falls inside
the request window and accepted where it falls outside. Under
`--required-sclk-mhz` and `--required-mclk-mhz` it states the clock
invariant a forced policy replaces the regime taxonomy with -- held over a
window whose delivered graphics frequency sits at the required step and
whose fabric clock stays at or above its floor, violated over one below
either or over no sample at all, and not_requested where the campaign ran
under the governor. The graphics figure comes from the eight-column
record's `sclk_actual_mhz` where telemetry-broker.c wrote one and from the
selected step otherwise, and both widths are read here.
summarize-census-controls.py assigns the
sidecar, compile, and collect bounds to the three registered quadruple shapes
alone, collapses every replicate of a control onto one row, judges that row by
whether its nominal 95% interval sits inside, outside, or across the bound,
marks an unregistered quadruple unclassified, names the direction of a refuted
interval, and keeps S and the warmup arm W outside the parser. It judges a
control over the pairs whose two selected graphics clocks lie within
`--sclk-band` of each other, excluding a pair that straddled a governor step
and reading the whole control `state-changed` where fewer than two comparable
pairs survive, and it counts the arms whose `regime_delta` exceeds that band
as `off_regime_arms`. A pair holding an arm whose `clock_invariant` reads
`violated` leaves the interval the same way and is named `clock-violated`. The appliance tables of 20260902T0819Z and
20260902T1302Z are replayed here: the first resolves none of the three
controls at two replicates, the second steps from 1100 MHz to 800 MHz partway
through the arm list, and its four collect pairs -- 825/837, 787/762,
775/800, and 812/825 -- are one regime under the band and four governor steps
under an exact comparison. summarize-perf-logger-slice.py classifies each block by the largest
`n` over its non-f32 matmul rows, folds the decode blocks into per-op calls
per block, and refuses a decode count other than the requested one.
"""
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
validator = os.path.join(script_directory, "validate-clock-sidecar.py")
controls = os.path.join(script_directory, "summarize-census-controls.py")
slicer = os.path.join(script_directory, "summarize-perf-logger-slice.py")
work = tempfile.mkdtemp(prefix="census-controls-")

COLUMNS = ("monotonic_ns\tpp_dpm_sclk_selected_mhz\tpp_dpm_mclk_surface_mhz"
           "\tpp_dpm_fclk_surface_mhz\tgpu_busy_percent\ttemp1_millidegrees\tsample_cost_ns")
# telemetry-broker.c appends the delivered graphics frequency, so a record is
# seven or eight columns wide and the validator reads both.
WIDE_COLUMNS = COLUMNS + "\tsclk_actual_mhz"
ATTRIBUTION_COLUMNS = (WIDE_COLUMNS
                       + "\tscheduler_runqueue_delay_lower_bound_ns"
                       + "\tunattributed_elapsed_ns")


def write(name, text):
    path = os.path.join(work, name)
    with open(path, "w") as handle:
        handle.write(text)
    return path


def sidecar_record(samples=100, period_ns=5_000_000, cost_ns=30_000, start=1_000_000_000,
                   unavailable_rows=(), footer=None, columns=COLUMNS, header_period=None,
                   footers=1, hole_after=None, hole_ns=0, achieved_period_ns=None,
                   actual_mhz=None, mclk="933", mclk_low_rows=(), mclk_low="400",
                   max_cost_ns=None, dpm_period_ns=None, dpm_read_stride=None,
                   backward_row=None, sampler_format=None,
                   scheduler_delay_ns=None, unattributed_elapsed_ns=None):
    """Write one synthetic record; hole_ns is the delay inserted after hole_after.

    A hole shifts every later row by hole_ns, so the gap it opens is the period
    plus hole_ns. The footer states the mean the rows carry, since the reader
    recomputes it and holds the footer to it; achieved_period_ns and
    max_cost_ns override that agreement for the stale-footer cases.
    dpm_period_ns writes the broker's `# sample_rates:` header and
    dpm_read_stride writes its per-row freshness markers, which are the two
    sources the invariant's fresh-sample count is read from.
    """
    def instant_of(index):
        delay = hole_ns if hole_after is not None and index > hole_after else 0
        instant = start + index * period_ns + delay
        if backward_row is not None and index == backward_row:
            instant -= period_ns * 2
        return instant

    lines = [
        f"# clock=CLOCK_MONOTONIC period_ns={header_period or period_ns} drm_device=/fake hwmon=/fake/hwmon0",
        "# interpretation: pp_dpm_sclk_selected_mhz is the selected graphics clock step",
        ("# sampler_pid=4242 nice=10 cpu_affinity=1"
         + (f" sampler_format={sampler_format}" if sampler_format else "")),
    ]
    if dpm_period_ns is not None:
        lines.append(f"# sample_rates: gpu_busy_percent_period_ns={period_ns}"
                     f" pp_dpm_period_ns={dpm_period_ns}")
    lines.append(columns)
    for index in range(samples):
        instant = instant_of(index)
        fclk = "unavailable" if index in unavailable_rows else "1067"
        # A fabric excursion below the floor, which the appliance measures a
        # sample at a time while the graphics clock holds its pinned step.
        row_mclk = mclk_low if index in mclk_low_rows else mclk
        row = f"{instant}\t400\t{row_mclk}\t{fclk}\t37\t61000\t{cost_ns}"
        if actual_mhz is not None:
            row += f"\t{actual_mhz}"
        if scheduler_delay_ns is not None:
            residual = (cost_ns - scheduler_delay_ns
                        if unattributed_elapsed_ns is None
                        else unattributed_elapsed_ns)
            row += f"\t{scheduler_delay_ns}\t{residual}"
        if dpm_read_stride is not None and index % dpm_read_stride == 0:
            lines.append(f"# dpm_read={instant}")
        lines.append(row)
    last = instant_of(samples - 1)
    first = instant_of(0)
    mean_period = (last - first) // (samples - 1) if samples > 1 else 0
    footer_line = footer or (
        f"# samples={samples} achieved_period_ns={achieved_period_ns or mean_period}"
        f" mean_sample_cost_ns={cost_ns}"
        f" max_sample_cost_ns={max_cost_ns or cost_ns}"
        f" samples_with_unavailable_sensor={len(unavailable_rows)}"
        f" first_sample_ns={first} last_sample_ns={last}"
        + (f" mean_scheduler_runqueue_delay_lower_bound_ns={scheduler_delay_ns}"
           f" max_scheduler_runqueue_delay_lower_bound_ns={scheduler_delay_ns}"
           f" mean_unattributed_elapsed_ns="
           f"{cost_ns - scheduler_delay_ns if unattributed_elapsed_ns is None else unattributed_elapsed_ns}"
           f" max_unattributed_elapsed_ns="
           f"{cost_ns - scheduler_delay_ns if unattributed_elapsed_ns is None else unattributed_elapsed_ns}"
           if scheduler_delay_ns is not None else ""))
    lines.extend([footer_line] * footers)
    return "\n".join(lines) + "\n"


def validate(text, status=0, window=(1_050_000_000, 1_400_000_000), tolerance="0.25",
             cost_bound="1000000", period_ms="5", allow=(), max_gap="50000000",
             max_lost="0.02", required=None, required_mclk=None,
             max_below_mclk=None):
    path = write("sidecar.tsv", text)
    command = [sys.executable, validator, path, "--sidecar-status", str(status),
               "--period-ms", period_ms, "--period-tolerance", tolerance,
               "--cost-bound-ns", cost_bound, "--max-gap-ns", max_gap,
               "--max-lost-fraction", max_lost]
    if required is not None:
        command += ["--required-sclk-mhz", required]
    if required_mclk is not None:
        command += ["--required-mclk-mhz", required_mclk]
    if max_below_mclk is not None:
        command += ["--max-below-mclk-floor-fraction", max_below_mclk]
    for column in allow:
        command += ["--allow-unavailable", column]
    if window:
        command += ["--window-begin-ns", str(window[0]), "--window-end-ns", str(window[1])]
    return subprocess.run(command, capture_output=True, text=True)


result = validate(sidecar_record())
assert result.returncode == 0, result.stdout
assert "clock_sidecar=accepted failures=-" in result.stdout, result.stdout
assert "window_coverage=accepted" in result.stdout, result.stdout
assert result.stdout.rstrip("\n").split("\n")[-1].startswith("clock_sidecar="), result.stdout
# The clock state the window ran under prints beside the verdict lines and
# counts in none of them: the fixture holds one selected step across the whole
# window, so the mode carries its full share.
assert ("clock_state=measured window_samples=71 sclk_mode_mhz=400 sclk_share=1.0000"
        " mclk_mode_mhz=933 temp_mean_c=61.0 temp_max_c=61.0 busy_mean=37.00"
        in result.stdout), result.stdout
print("sidecar_accepted=accepted")

result = validate(sidecar_record(), window=None)
assert result.returncode == 0 and "window_coverage=not_run" in result.stdout, result.stdout
assert "window_lost=not_run" in result.stdout, result.stdout
assert "clock_state=not_run no window supplied" in result.stdout, result.stdout


def refused(text, needle, **kwargs):
    result = validate(text, **kwargs)
    assert result.returncode != 0, (needle, result.stdout)
    assert f"{needle}=refused" in result.stdout, (needle, result.stdout)
    assert "clock_sidecar=refused" in result.stdout, result.stdout


refused(sidecar_record(), "sidecar_exit", status=2)
refused(sidecar_record(period_ns=7_000_000, header_period=5_000_000), "achieved_period")
refused(sidecar_record(header_period=4_000_000), "period_declared")
refused(sidecar_record(cost_ns=2_000_000), "sample_cost")
refused(sidecar_record(unavailable_rows=(3,)), "sensors")
# A column the kernel leaves empty is allowed by name, on every row; the
# allowance covers that column alone and an unknown column name is refused.
result = validate(sidecar_record(unavailable_rows=tuple(range(100))), allow=("pp_dpm_fclk_surface_mhz",))
assert result.returncode == 0 and "sensors=accepted" in result.stdout, result.stdout
refused(sidecar_record(unavailable_rows=(3,)), "sensors", allow=("gpu_busy_percent",))
refused(sidecar_record(), "allowed_columns", allow=("sample_cost_ns",))
refused(sidecar_record(footers=2), "footer_cardinality")
refused(sidecar_record(footers=0), "footer_cardinality")
refused(sidecar_record(columns=COLUMNS.replace("pp_dpm_mclk_surface_mhz", "mclk_mhz")), "columns")
refused(sidecar_record(samples=1), "samples")
refused(sidecar_record(), "window_coverage", window=(900_000_000, 1_400_000_000))
refused(sidecar_record(), "window_coverage", window=(1_050_000_000, 2_000_000_000))
# A footer whose instants disagree with the rows is a footer written by
# something other than the sampler that wrote the rows.
mismatched = sidecar_record().replace("first_sample_ns=1000000000", "first_sample_ns=999")
refused(mismatched, "footer_instants")
# A footer counting unavailable samples the rows do not carry.
miscounted = sidecar_record().replace("samples_with_unavailable_sensor=0", "samples_with_unavailable_sensor=0")
result = validate(miscounted.replace("\t1067\t37", "\tunavailable\t37", 1))
assert result.returncode != 0 and "sensor_rows=refused" in result.stdout, result.stdout
print("sidecar_refusals=accepted")

# A 100 ms hole between two 5 ms samples leaves the run-wide achieved period
# at its declared value and still loses two 2B token intervals. It is ten
# times the 5 ms period, so it refuses on both criteria: the stall bound and
# the lost fraction, and only where the hole overlaps the request window.
holed = sidecar_record(hole_after=20, hole_ns=100_000_000)
refused(holed, "gaps")
refused(holed, "window_lost")
result = validate(holed)
assert "over_max=1" in result.stdout and "gaps_in_window=1 " in result.stdout, result.stdout
result = validate(holed, window=(1_300_000_000, 1_400_000_000))
assert result.returncode == 0, result.stdout
assert "gaps=accepted" in result.stdout and "over_max=1" in result.stdout, result.stdout
assert "gaps_in_window=0 " in result.stdout, result.stdout
assert "window_lost=accepted" in result.stdout, result.stdout
# A caller supplying no window has named no interval the hole can miss, so
# an over-bound gap anywhere refuses the record and no fraction is reported.
refused(holed, "gaps", window=None)
result = validate(holed, window=None)
assert "gaps_in_window=not_run" in result.stdout, result.stdout
assert "window_lost=not_run" in result.stdout, result.stdout
# A scheduler slice is an observation rather than a refusal. A 30 ms hole
# opens a 35 ms gap, seven 5 ms periods and under the ten-period stall bound,
# and it costs 35 ms of a 350 ms window: 0.1000 refuses against the 0.02
# coverage bound and passes against a 0.15 one, the gaps line accepting both.
sliced = sidecar_record(hole_after=20, hole_ns=30_000_000)
result = validate(sliced)
assert result.returncode == 1, result.stdout
assert "gaps=accepted" in result.stdout, result.stdout
assert "over_max=0" in result.stdout and "over_missed=1" in result.stdout, result.stdout
assert "window_lost=refused window_lost_fraction=0.1000" in result.stdout, result.stdout
assert "clock_sidecar=refused failures=window_lost" in result.stdout, result.stdout
result = validate(sliced, max_lost="0.15")
assert result.returncode == 0, result.stdout
assert "window_lost=accepted window_lost_fraction=0.1000" in result.stdout, result.stdout
assert "clock_sidecar=accepted failures=-" in result.stdout, result.stdout
# Every gap 8 ms wide passes 1.5 x the requested 5 ms period on every
# interval while staying under two periods, so it misses no sample, the
# counts report the whole distribution, and the verdict stays accepted.
# The rows carry the mean the footer states, so the tolerance rather than a
# stale footer is what admits an 8 ms achieved period against a 5 ms request.
loose = sidecar_record(period_ns=8_000_000, header_period=5_000_000)
result = validate(loose, tolerance="0.7")
assert result.returncode == 0, result.stdout
assert "over_1_5x=99 over_missed=0 over_max=0" in result.stdout, result.stdout
assert "window_lost=accepted window_lost_fraction=0.0000" in result.stdout, result.stdout
assert "clock_sidecar=accepted failures=-" in result.stdout, result.stdout
refused(loose, "gaps", max_gap="7000000", tolerance="0.7")
# One row carries no adjacent gap to measure.
result = validate(sidecar_record(samples=1))
assert "gaps=not_run rows=1" in result.stdout, result.stdout
print("sidecar_gaps=accepted")

# The clock invariant a forced policy replaces the regime taxonomy with. The
# fixture holds 400 MHz across the whole window, so a campaign that pinned
# 400 MHz reads every window sample at the required step and one that pinned
# 1100 MHz reads every one below it. An invocation naming no required step --
# the appliance's own governor -- states that rather than a verdict, and the
# verdict line stays last in every case.
result = validate(sidecar_record())
assert "clock_invariant=not_requested" in result.stdout, result.stdout
assert result.stdout.rstrip("\n").split("\n")[-1].startswith("clock_sidecar="), result.stdout
result = validate(sidecar_record(), required="400")
assert result.returncode == 0, result.stdout
assert ("clock_invariant=held samples_at_required=71 samples_below_required=0"
        " below_required_fraction=0.0000" in result.stdout), result.stdout
assert "clock_sidecar=accepted failures=-" in result.stdout, result.stdout
result = validate(sidecar_record(), required="1100")
assert result.returncode != 0, result.stdout
assert ("clock_invariant=violated samples_at_required=0 samples_below_required=71"
        " below_required_fraction=1.0000" in result.stdout), result.stdout
assert "clock_sidecar=refused failures=clock_invariant" in result.stdout, result.stdout
assert result.stdout.rstrip("\n").split("\n")[-1].startswith("clock_sidecar="), result.stdout
# A step one percent under the pin is that pinned step read through the
# kernel's own rounding, and 405 is where the tolerance over 400 ends.
result = validate(sidecar_record(), required="404")
assert result.returncode == 0 and "clock_invariant=held" in result.stdout, result.stdout
result = validate(sidecar_record(), required="405")
assert result.returncode != 0 and "clock_invariant=violated" in result.stdout, result.stdout
# A requested invariant no sample can answer is a violation rather than a
# vacuous pass: an unpinned clock is what the condition exists to catch.
result = validate(sidecar_record(), window=None, required="400")
assert result.returncode != 0, result.stdout
assert ("clock_invariant=violated samples_at_required=0 samples_below_required=0"
        " below_required_fraction=1.0000" in result.stdout), result.stdout
# The eight-column record telemetry-broker.c writes. The delivered frequency
# rather than the selected step answers the invariant where the column exists,
# which is the whole point of the column: a level that pins the step reads 1100
# there while the step column still says 400.
wide = sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100)
result = validate(wide)
assert result.returncode == 0, result.stdout
assert "columns=accepted" in result.stdout and "width=8" in result.stdout, result.stdout
assert "row_arity=accepted columns=8" in result.stdout, result.stdout

# The attributed broker format keeps the original cost denominator and appends
# a measured runnable-but-unscheduled delta plus its arithmetic residual. The
# reader proves both row and footer identities and refuses either field without
# inferring scheduler delay from a large wall-clock cost.
attributed = sidecar_record(
    columns=ATTRIBUTION_COLUMNS,
    actual_mhz=1100,
    sampler_format="broker-schedstat-v1",
    scheduler_delay_ns=10_000,
)
result = validate(attributed)
assert result.returncode == 0, result.stdout
assert "columns=accepted" in result.stdout and "width=10" in result.stdout, result.stdout
assert "attribution_schema=accepted" in result.stdout, result.stdout
assert "scheduler_attribution_rows=accepted rows=100 invalid=0" in result.stdout, result.stdout
assert "scheduler_attribution_footer=accepted scheduler_mean_ns=10000" in result.stdout, result.stdout
refused(attributed.replace("\t10000\t20000\n", "\t10000\t19000\n", 1),
        "scheduler_attribution_rows")
refused(sidecar_record(columns=ATTRIBUTION_COLUMNS, actual_mhz=1100,
                       scheduler_delay_ns=10_000), "attribution_schema")
refused(sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100,
                       sampler_format="broker-schedstat-v1"),
        "attribution_schema")
stale_attribution_footer = attributed.replace(
    "mean_scheduler_runqueue_delay_lower_bound_ns=10000",
    "mean_scheduler_runqueue_delay_lower_bound_ns=9999",
)
refused(stale_attribution_footer, "scheduler_attribution_footer")
long_wall_without_scheduler_delay = sidecar_record(
    columns=ATTRIBUTION_COLUMNS,
    cost_ns=900_000,
    actual_mhz=1100,
    sampler_format="broker-schedstat-v1",
    scheduler_delay_ns=0,
)
result = validate(long_wall_without_scheduler_delay)
assert result.returncode == 0, result.stdout
assert "scheduler_attribution_footer=accepted scheduler_mean_ns=0" in result.stdout, result.stdout
refused(sidecar_record(columns=ATTRIBUTION_COLUMNS, cost_ns=30_000,
                       actual_mhz=1100,
                       sampler_format="broker-schedstat-v1",
                       scheduler_delay_ns=30_001,
                       unattributed_elapsed_ns=0),
        "scheduler_attribution_rows")
refused(attributed.replace("\t10000\t20000\n",
                           "\tunavailable\t20000\n", 1),
        "cell_values")
print("sidecar_scheduler_attribution=accepted")

result = validate(wide, required="1100")
assert result.returncode == 0, result.stdout
assert ("clock_invariant=held samples_at_required=71 samples_below_required=0"
        " below_required_fraction=0.0000 sclk_source=sclk_actual_mhz"
        in result.stdout), result.stdout
# The seven-column record answers the same question from the step column, so
# the two widths differ in what they read rather than in whether they answer:
# a record whose delivered frequency fell to 400 violates a 1100 requirement
# the step column alone would have called held.
narrow = validate(sidecar_record(), required="1100")
assert narrow.returncode != 0, narrow.stdout
assert "sclk_source=pp_dpm_sclk_selected_mhz" in narrow.stdout, narrow.stdout
fallen = validate(sidecar_record(columns=WIDE_COLUMNS, actual_mhz=400), required="1100")
assert fallen.returncode != 0, fallen.stdout
assert ("clock_invariant=violated samples_at_required=0 samples_below_required=71"
        " below_required_fraction=1.0000 sclk_source=sclk_actual_mhz"
        in fallen.stdout), fallen.stdout

# The fabric floor is the second half of the operating point, and it is a floor
# rather than an equality: the appliance ran every manual arm at 933 MHz with
# the selection that would raise it accepted and ignored.
result = validate(wide, required="1100", required_mclk="933")
assert result.returncode == 0, result.stdout
assert ("samples_at_mclk_floor=71 samples_below_mclk_floor=0"
        " below_mclk_floor_fraction=0.0000" in result.stdout), result.stdout
assert "clock_invariant=held" in result.stdout, result.stdout
result = validate(sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100, mclk="1067"),
                  required="1100", required_mclk="933")
assert result.returncode == 0 and "clock_invariant=held" in result.stdout, result.stdout
result = validate(sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100, mclk="400"),
                  required="1100", required_mclk="933")
assert result.returncode != 0, result.stdout
assert ("clock_invariant=violated samples_at_required=71 samples_below_required=0"
        in result.stdout), result.stdout
assert ("samples_at_mclk_floor=0 samples_below_mclk_floor=71"
        " below_mclk_floor_fraction=1.0000" in result.stdout), result.stdout
assert "clock_sidecar=refused failures=clock_invariant" in result.stdout, result.stdout

# The floor carries a tolerance where the graphics equality carries none,
# because the fabric hovers under load: arm 03-P of the 20260902T2011Z
# calibration read 933 MHz on 356 of 358 window samples, reaching 1067 above
# its selection and falling below it on 2, while the graphics clock held the
# pinned 1100 on every one. One low sample of 71 is 0.0141 of the window, so
# the 0.01 default refuses it and a campaign admitting 0.02 reads it held.
hovering = sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100, mclk_low_rows=(30,))
result = validate(hovering, required="1100", required_mclk="933")
assert result.returncode != 0, result.stdout
assert ("clock_invariant=violated samples_at_required=71 samples_below_required=0"
        in result.stdout), result.stdout
assert ("max_below_mclk_floor_fraction=0.0100 samples_at_mclk_floor=70"
        " samples_below_mclk_floor=1 below_mclk_floor_fraction=0.0141"
        in result.stdout), result.stdout
result = validate(hovering, required="1100", required_mclk="933", max_below_mclk="0.02")
assert result.returncode == 0, result.stdout
assert "clock_invariant=held" in result.stdout, result.stdout
# The counts print whatever the bound admits, so the excursion stays readable
# in a record the verdict accepted.
assert ("max_below_mclk_floor_fraction=0.0200 samples_at_mclk_floor=70"
        " samples_below_mclk_floor=1 below_mclk_floor_fraction=0.0141"
        in result.stdout), result.stdout
# The tolerance prices a hover rather than a fabric that left its floor: a
# tenth of the window below it refuses under the same admitted share.
fallen_fabric = sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100,
                               mclk_low_rows=tuple(range(20, 40)))
result = validate(fallen_fabric, required="1100", required_mclk="933",
                  max_below_mclk="0.02")
assert result.returncode != 0, result.stdout
assert "below_mclk_floor_fraction=0.2817" in result.stdout, result.stdout
print("sidecar_clock_invariant=accepted")

# The graphics requirement is an equality on both sides. A delivered frequency
# a percent over the pin is a step the forced policy states it cannot reach,
# so it counts above the requirement and violates the invariant the way one
# below it does, while the kernel's own rounding inside the percent still
# reads at the step.
over = validate(sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1200), required="1100")
assert over.returncode != 0, over.stdout
assert ("clock_invariant=violated samples_at_required=0 samples_below_required=0"
        in over.stdout), over.stdout
assert "samples_above_required=71" in over.stdout, over.stdout
inside = validate(sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1105), required="1100")
assert inside.returncode == 0, inside.stdout
assert "clock_invariant=held" in inside.stdout, inside.stdout
assert "samples_above_required=0" in inside.stdout, inside.stdout

# A sensor cell reads a decimal or the empty sentinel. Any other text carries
# no clock evidence while satisfying a comparison against the sentinel alone,
# and it reaches each consumer differently -- the counts skip it, the mode
# reports it as a state -- so the record is refused where the cell is read.
# The allowance names a column that may read the sentinel and admits no other
# text in it.
refused(sidecar_record().replace("\t1067\t37", "\tread-error\t37"), "cell_values",
        allow=("pp_dpm_fclk_surface_mhz",))
refused(sidecar_record(columns=WIDE_COLUMNS, actual_mhz="read-error"), "cell_values")
# A non-finite delivered clock compares false against every threshold, so an
# unrefused record of them would report the invariant held out of the one
# column a forced campaign trusts.
nan_record = validate(sidecar_record(columns=WIDE_COLUMNS, actual_mhz="nan"),
                      required="1100")
assert nan_record.returncode != 0, nan_record.stdout
assert "cell_values=refused" in nan_record.stdout, nan_record.stdout
assert "clock_invariant=held" not in nan_record.stdout, nan_record.stdout

# The footer states the run mean and the maximum, and the rows carry the
# instants and costs both are functions of, so the reader recomputes each and
# holds the footer to it. A stale period passes the tolerance while every
# individual gap stays under the missed-sample threshold.
refused(sidecar_record(period_ns=6_000_000, header_period=5_000_000,
                       achieved_period_ns=5_000_000), "footer_derived")
refused(sidecar_record(max_cost_ns=60_000), "footer_derived")
# The cost bound prices the rows rather than the claim: a record whose every
# sample cost twice the bound is refused behind a footer claiming 100 ns.
expensive = (sidecar_record(cost_ns=2_000_000)
             .replace("mean_sample_cost_ns=2000000", "mean_sample_cost_ns=100")
             .replace("max_sample_cost_ns=2000000", "max_sample_cost_ns=100"))
result = validate(expensive)
assert result.returncode != 0, result.stdout
assert "footer_derived=refused" in result.stdout, result.stdout
assert "sample_cost=refused mean_ns=2000000 max_ns=2000000" in result.stdout, result.stdout

# A reversed window lies inside the record on both sides, so coverage passes
# on the endpoints while the in-window row set is empty and the lost fraction
# reports zero out of a denominator clamped to one nanosecond.
refused(sidecar_record(), "window_order", window=(1_400_000_000, 1_050_000_000))
# A CLOCK_MONOTONIC sequence rises strictly; every gap comparison is
# one-sided, so a backward instant lowers the quantiles and subtracts time
# from the lost fraction.
refused(sidecar_record(backward_row=50), "instant_order")

# Each bound argument is finite and inside the range it is defined over. An
# infinite one retires the condition it names while every other condition
# stays silent about it, so the range is checked where the value is parsed.
for keyword, flag, value in (
        ("tolerance", "--period-tolerance", "inf"),
        ("tolerance", "--period-tolerance", "nan"),
        ("max_lost", "--max-lost-fraction", "inf"),
        ("max_lost", "--max-lost-fraction", "-0.1"),
        ("max_below_mclk", "--max-below-mclk-floor-fraction", "inf")):
    result = validate(sidecar_record(), **{keyword: value})
    assert result.returncode == 2, (flag, value, result.returncode, result.stderr)
    assert f"{flag} is {float(value)}" in result.stderr, (flag, value, result.stderr)

# The mode feeds a pair-equality test that decides a campaign verdict, so two
# states at equal counts resolve to the smaller value: 35 window rows at 900
# against 35 at 1100 read 900, where a lexicographic order reads 1100.
tied = sidecar_record(mclk="900", mclk_low_rows=tuple(range(10, 45)), mclk_low="1100")
result = validate(tied, window=(1_050_000_000, 1_395_000_000))
assert result.returncode == 0, result.stdout
assert "window_samples=70" in result.stdout, result.stdout
assert "mclk_mode_mhz=900" in result.stdout, result.stdout
print("sidecar_cell_and_bound_conditions=accepted")

# The DPM channel reads its attributes once every multiple-th tick and the
# rows between repeat the cached value, so the invariant counts reads rather
# than rows. The declared channel period derives the count for a record
# carrying no marker, and a broker's own markers state it directly; both read
# 8 fresh samples where the window holds 71 rows.
staggered = sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100,
                           dpm_period_ns=50_000_000)
result = validate(staggered, required="1100")
assert result.returncode == 0, result.stdout
assert ("clock_invariant=held samples_at_required=8 samples_below_required=0"
        in result.stdout), result.stdout
assert ("dpm_freshness=derived dpm_period_multiple=10 fresh_dpm_samples=8"
        in result.stdout), result.stdout
assert "clock_state=measured window_samples=71" in result.stdout, result.stdout
marked = sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100,
                        dpm_period_ns=50_000_000, dpm_read_stride=10)
result = validate(marked, required="1100")
assert result.returncode == 0, result.stdout
assert ("dpm_freshness=marker dpm_period_multiple=10 fresh_dpm_samples=8"
        in result.stdout), result.stdout
assert ("clock_invariant=held samples_at_required=8 samples_below_required=0"
        in result.stdout), result.stdout
# A record naming no channel period is a sampler reading every attribute on
# every tick, so every row is a fresh read.
plain = validate(sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100), required="1100")
assert ("dpm_freshness=derived dpm_period_multiple=1 fresh_dpm_samples=71"
        in plain.stdout), plain.stdout
# The floor tolerance is a share of what was read. One fabric excursion among
# 8 fresh reads is 0.1250 where the same excursion among 71 rows reads 0.0141,
# so a 0.02 admitted share accepts the inflated denominator and refuses the
# measured one.
excursion = sidecar_record(columns=WIDE_COLUMNS, actual_mhz=1100,
                           dpm_period_ns=50_000_000, dpm_read_stride=10,
                           mclk_low_rows=(30,))
result = validate(excursion, required="1100", required_mclk="933",
                  max_below_mclk="0.02")
assert result.returncode != 0, result.stdout
assert ("samples_at_mclk_floor=7 samples_below_mclk_floor=1"
        " below_mclk_floor_fraction=0.1250" in result.stdout), result.stdout
assert "clock_sidecar=refused failures=clock_invariant" in result.stdout, result.stdout
print("sidecar_dpm_freshness=accepted")


def arms_ledger(rows, modes=None, regime_deltas=None, invariants=None):
    """One ledger; modes is a per-row selected graphics clock, `-` by default.

    A ledger written before the clock-state columns existed omits them
    entirely, which is what `modes=None` writes, so the retained campaigns
    replay through the same reader. `regime_deltas` adds the column the
    warmup precondition fills, whose absence is the same retained shape.
    """
    header = ("slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s"
              "\tcensus_rows\tsidecar\tstatus")
    if modes is not None:
        header += "\tsclk_mode_mhz\tsclk_share"
    if regime_deltas is not None:
        header += "\tregime_delta"
    if invariants is not None:
        header += "\tclock_invariant"
    lines = [header]
    for slot, (arm, rate, status) in enumerate(rows, 1):
        line = f"{slot}\t{arm}\tabc\t64\t6000\t{rate}\t-\ton\t{status}"
        if modes is not None:
            mode = modes[slot - 1]
            share = "-" if mode == "-" else "0.9800"
            line += f"\t{mode}\t{share}"
        if regime_deltas is not None:
            line += f"\t{regime_deltas[slot - 1]}"
        if invariants is not None:
            line += f"\t{invariants[slot - 1]}"
        lines.append(line)
    return "\n".join(lines) + "\n"


def summarize(rows, sidecar="0.0065", compile_bound="0.0065", collect="0.02",
              modes=None, regime_deltas=None, band=None, invariants=None):
    """Run the controls summarizer and return its rows as field maps.

    The verdict is over every replicate of a control, so the columns a case
    reads are named rather than counted: a row gains statistics between the
    per-replicate columns and the bound, and a positional read would follow
    the wrong field once a column lands between them.
    """
    path = write("arms.tsv", arms_ledger(rows, modes, regime_deltas, invariants))
    argv = [sys.executable, controls, path, "--sidecar-bound", sidecar,
            "--compile-bound", compile_bound, "--collect-bound", collect]
    if band is not None:
        argv += ["--sclk-band", band]
    result = subprocess.run(argv, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
    header = lines[0]
    return header, [dict(zip(header, line)) for line in lines[1:]]


def quadruple(outer, inner, outer_rate, first_inner_rate, second_inner_rate,
              second_outer_rate, status="completed", repeats=1):
    """One mirrored quadruple `outer inner inner outer`, repeated in place."""
    return repeats * [
        (outer, outer_rate, status), (inner, first_inner_rate, status),
        (inner, second_inner_rate, status), (outer, second_outer_rate, status),
    ]


HEADER = ("pair", "control", "outer", "inner", "first_outer", "first_inner", "first_delta",
          "second_outer", "second_inner", "second_delta", "replicates", "mean_delta",
          "sd_delta", "ci_low", "ci_high", "deltas", "sclk_modes", "off_regime_arms",
          "bound", "sclk_band", "verdict", "detail")

# Two replicates that agree exactly leave a degenerate interval at their own
# delta, which is the only way a two-replicate control accepts against a 0.65%
# bound: t at one degree of freedom is 12.706, so any spread at all opens the
# interval past the bound. These rates are a fixture rather than a plausible
# arm pair, and the appliance table below is what a real pair looks like.
header, rows = summarize(
    quadruple("P-nosidecar", "P", "10.000", "9.980", "9.980", "10.000")
    + quadruple("P", "I0", "10.000", "9.950", "9.950", "10.000")
    + quadruple("I0", "I1", "10.000", "9.850", "9.850", "10.000")
    + [("S", "3.000", "completed")])
assert tuple(header) == HEADER, header
assert len(rows) == 3, rows
sidecar_row, compile_row, collect_row = rows
assert sidecar_row["control"] == "sidecar" and sidecar_row["replicates"] == "2", sidecar_row
assert sidecar_row["first_delta"] == "-0.0020" and sidecar_row["second_delta"] == "-0.0020"
assert sidecar_row["mean_delta"] == "-0.0020" and sidecar_row["sd_delta"] == "0.0000"
assert sidecar_row["ci_low"] == "-0.0020" and sidecar_row["ci_high"] == "-0.0020", sidecar_row
assert sidecar_row["deltas"] == "-0.0020 -0.0020", sidecar_row
assert sidecar_row["bound"] == "0.0065" and sidecar_row["verdict"] == "accepted", sidecar_row
assert compile_row["control"] == "compile" and compile_row["verdict"] == "accepted", compile_row
assert collect_row["control"] == "collect" and collect_row["bound"] == "0.02"
assert collect_row["verdict"] == "accepted" and collect_row["mean_delta"] == "-0.0150", collect_row
assert sidecar_row["detail"] == "-" and collect_row["detail"] == "-", (sidecar_row, collect_row)
print("controls_accepted=accepted")

# The appliance calibration of 20260902T0819Z: every arm completed, every
# sidecar accepted, and the two replicates of the sidecar and compile controls
# disagreed in sign. A per-replicate bound read that as two refutations; the
# interval reads it as the arm-to-arm scatter it is, and all three controls
# come back unresolved because one degree of freedom resolves nothing at these
# bounds. The collect control, whose replicates agree in sign at -1.88% and
# -0.53% against a 2% bound, is unresolved for the same reason.
header, rows = summarize(
    quadruple("P-nosidecar", "P", "9.590", "9.475", "9.604", "9.513")
    + quadruple("P", "I0", "9.402", "9.628", "9.427", "9.522")
    + quadruple("I0", "I1", "9.530", "9.351", "9.498", "9.549")
    + [("S", "3.000", "completed")])
observed = {row["control"]: row for row in rows}
assert observed["sidecar"]["first_delta"] == "-0.0120", observed["sidecar"]
assert observed["sidecar"]["second_delta"] == "+0.0096", observed["sidecar"]
assert observed["compile"]["first_delta"] == "+0.0240", observed["compile"]
assert observed["compile"]["second_delta"] == "-0.0100", observed["compile"]
assert observed["collect"]["first_delta"] == "-0.0188", observed["collect"]
assert observed["collect"]["second_delta"] == "-0.0053", observed["collect"]
assert [row["verdict"] for row in rows] == ["unresolved", "unresolved", "unresolved"], rows
for control, row in observed.items():
    assert row["detail"].startswith(f"spans bound={row['bound']} ci=["), row
    assert float(row["ci_low"]) < -float(row["bound"]), (control, row)
    assert float(row["ci_high"]) > float(row["bound"]), (control, row)
print("controls_unresolved=accepted deltas=%s" % observed["sidecar"]["deltas"])

# A cost the whole interval clears refutes the control, and the detail names
# the direction: an interval entirely below -bound is a cost, one entirely
# above +bound a speedup, and each refutes the claim the bound states.
header, rows = summarize(quadruple("I0", "I1", "10.000", "9.700", "9.700", "10.000"))
assert rows[0]["verdict"] == "refuted", rows[0]
assert rows[0]["detail"] == "exceeds bound=0.02 cost ci=[-0.0300,-0.0300]", rows[0]
header, rows = summarize(quadruple("P", "I0", "10.000", "10.300", "10.300", "10.000"))
assert rows[0]["verdict"] == "refuted", rows[0]
assert rows[0]["detail"] == "exceeds bound=0.0065 speedup ci=[+0.0300,+0.0300]", rows[0]
# One delta outside the bound beside one inside it no longer refutes on its
# own: two replicates 1.0% apart open an interval that spans the bound.
header, rows = summarize(quadruple("P", "I0", "10.000", "9.900", "10.000", "10.000"))
assert rows[0]["first_delta"] == "-0.0100" and rows[0]["second_delta"] == "+0.0000"
assert rows[0]["verdict"] == "unresolved", rows[0]
print("controls_refuted=accepted")

# Four replicates are two quadruples of one control, and the control collapses
# to one row carrying every delta. The first_* and second_* columns stay the
# first quadruple's own two pairs rather than extremes of the set.
header, rows = summarize(
    quadruple("P-nosidecar", "P", "10.000", "9.980", "9.980", "10.000", repeats=2)
    + quadruple("P", "I0", "9.590", "9.475", "9.604", "9.513", repeats=2)
    + quadruple("I0", "I1", "10.000", "9.700", "9.720", "10.000", repeats=2)
    + [("S", "3.000", "completed")])
assert len(rows) == 3, rows
observed = {row["control"]: row for row in rows}
assert observed["sidecar"]["replicates"] == "4", observed["sidecar"]
assert observed["sidecar"]["deltas"] == "-0.0020 -0.0020 -0.0020 -0.0020", observed["sidecar"]
assert observed["sidecar"]["verdict"] == "accepted", observed["sidecar"]
assert observed["compile"]["replicates"] == "4", observed["compile"]
assert observed["compile"]["first_outer"] == "9.590", observed["compile"]
assert observed["compile"]["deltas"] == "-0.0120 +0.0096 -0.0120 +0.0096", observed["compile"]
assert observed["compile"]["mean_delta"] == "-0.0012", observed["compile"]
assert observed["compile"]["verdict"] == "unresolved", observed["compile"]
assert observed["collect"]["deltas"] == "-0.0300 -0.0280 -0.0300 -0.0280", observed["collect"]
assert observed["collect"]["mean_delta"] == "-0.0290", observed["collect"]
assert observed["collect"]["verdict"] == "refuted", observed["collect"]
assert observed["collect"]["detail"].startswith("exceeds bound=0.02 cost"), observed["collect"]
assert float(observed["collect"]["ci_high"]) < -0.02, observed["collect"]
print("controls_replicates_four=accepted")

# One incomplete arm makes the whole control incomplete, however many other
# replicates completed, since a set missing a delta measures a different set.
header, rows = summarize(
    quadruple("I0", "I1", "10.000", "9.850", "9.850", "10.000")
    + [("I0", "10.000", "completed"), ("I1", "-", "failed"),
       ("I1", "9.900", "completed"), ("I0", "10.000", "completed")])
assert len(rows) == 1 and rows[0]["control"] == "collect", rows
assert rows[0]["replicates"] == "4" and rows[0]["verdict"] == "incomplete", rows[0]
assert rows[0]["mean_delta"] == "-" and rows[0]["deltas"] == "-", rows[0]
# The detail carries the pairs whose two arms both completed: the first
# quadruple's two pairs and the second quadruple's second pair survive, the
# pair holding the failed arm is dropped, and the surviving mean is stated.
assert rows[0]["detail"].startswith("surviving_pairs=3 of 4 surviving_mean=-0.0133"), rows[0]
assert rows[0]["detail"].endswith("surviving_deltas=-0.0150 -0.0150 -0.0100"), rows[0]
# An unregistered quadruple has no control to join, so it keeps its own row
# and is printed unclassified with no bound.
header, rows = summarize(quadruple("P", "I1", "10.000", "9.900", "9.900", "10.000"))
assert rows[0]["control"] == "unregistered" and rows[0]["bound"] == "-"
assert rows[0]["verdict"] == "unclassified", rows[0]
# S stays outside the parser: I1 S S I1 forms no pair, and an S between two
# registered quadruples does not disturb them.
header, rows = summarize([
    ("I1", "9.900", "completed"), ("S", "3.000", "completed"),
    ("S", "3.000", "completed"), ("I1", "9.900", "completed"),
])
assert rows == [], rows
# The warmup arm is the cold opener and carries no registered bound, so it
# leaves the quadruple that follows it exactly where the parser expects it.
header, rows = summarize(
    [("W", "6.783", "completed")]
    + quadruple("P-nosidecar", "P", "10.000", "9.980", "9.980", "10.000"))
assert len(rows) == 1 and rows[0]["control"] == "sidecar", rows
assert rows[0]["first_outer"] == "10.000" and rows[0]["verdict"] == "accepted", rows[0]
header, rows = summarize([
    ("P", "10.000", "completed"), ("I0", "9.950", "completed"),
    ("S", "3.000", "completed"),
    ("I0", "9.950", "completed"), ("P", "10.000", "completed"),
])
assert len(rows) == 1 and rows[0]["control"] == "compile" and rows[0]["verdict"] == "accepted", rows
print("controls_shapes=accepted")

# A reused brick echoes its arms at their own slots with the rates it
# measured, so a quadruple of reused arms pairs the way an executed one does
# and a calibration whose four bricks all reuse still carries three verdicts.
header, rows = summarize(
    quadruple("P-nosidecar", "P", "10.000", "9.980", "9.980", "10.000", status="reused")
    + quadruple("P", "I0", "10.000", "9.950", "9.950", "10.000", status="reused")
    + quadruple("I0", "I1", "10.000", "9.850", "9.850", "10.000")
    + [("S", "3.000", "reused")])
assert len(rows) == 3, rows
assert [row["verdict"] for row in rows] == ["accepted", "accepted", "accepted"], rows
assert rows[0]["first_delta"] == "-0.0020" and rows[1]["first_delta"] == "-0.0050", rows
# A status outside completed and reused still makes the control incomplete.
header, rows = summarize([
    ("I0", "10.000", "reused"), ("I1", "9.900", "skipped"),
    ("I1", "9.900", "reused"), ("I0", "10.000", "reused"),
])
assert rows[0]["verdict"] == "incomplete", rows[0]
print("controls_reuse=accepted")

# The clock state a pair ran under decides whether the pair measures the
# control. The appliance calibration of 20260902T1302Z selected 1100 MHz on the
# early slots and 800 MHz from the middle of the run on, and the decode rate
# fell with it, so a pair straddling that step measures the governor. A pair
# whose two arms hold different numeric modes leaves the mean and the interval
# and reads state-changed in the deltas listing, while the pairs that held one
# state still judge the control.
header, rows = summarize(
    quadruple("P", "I0", "10.000", "9.950", "9.950", "10.000", repeats=2)
    + [("S", "3.000", "completed")],
    modes=["1100", "1100", "1100", "1100", "1100", "800", "800", "1100", "-"])
assert len(rows) == 1, rows
changed = rows[0]
assert changed["replicates"] == "4", changed
assert changed["deltas"] == "-0.0050 -0.0050 state-changed state-changed", changed
assert changed["sclk_modes"] == "1100/1100 1100/1100 800/1100 800/1100", changed
assert changed["verdict"] == "accepted", changed
assert changed["detail"] == "comparable_pairs=2 of 4", changed
print("controls_state_changed_excluded=accepted")

# Both pairs of the only quadruple straddle the step, so no comparable pair
# remains and the control reads state-changed: a verdict distinct from
# incomplete, which names a missing arm, and from unresolved, which names an
# interval that spans its bound.
header, rows = summarize(
    quadruple("P", "I0", "10.000", "9.950", "9.950", "10.000"),
    modes=["1100", "800", "800", "1100"])
assert rows[0]["verdict"] == "state-changed", rows[0]
assert rows[0]["mean_delta"] == "-" and rows[0]["ci_low"] == "-", rows[0]
assert rows[0]["first_delta"] == "state-changed", rows[0]
assert rows[0]["second_delta"] == "state-changed", rows[0]
assert rows[0]["deltas"] == "state-changed state-changed", rows[0]
assert rows[0]["detail"] == "comparable_pairs=0 of 2", rows[0]
# One surviving pair states one delta and no spread, so the control still
# reads state-changed rather than borrowing a verdict from a single arm pair.
header, rows = summarize(
    quadruple("P", "I0", "10.000", "9.950", "9.950", "10.000"),
    modes=["1100", "1100", "800", "1100"])
assert rows[0]["verdict"] == "state-changed", rows[0]
assert rows[0]["deltas"] == "-0.0050 state-changed", rows[0]
assert rows[0]["detail"] == "comparable_pairs=1 of 2", rows[0]
print("controls_state_changed_verdict=accepted")

# A forced clock policy states each sampled arm's invariant, and a pair holding
# a violated arm leaves the interval the way a pair straddling a governor step
# does. The marker names which of the two happened, and a violation wins where
# both apply, since a clock that left its pin is the stronger statement.
header, rows = summarize(
    quadruple("P", "I0", "10.000", "9.950", "9.950", "10.000", repeats=2),
    modes=["1100"] * 8,
    invariants=["held", "held", "held", "held", "held", "violated", "held", "held"])
assert len(rows) == 1, rows
violated_row = rows[0]
assert violated_row["deltas"] == "-0.0050 -0.0050 clock-violated -0.0050", violated_row
assert violated_row["replicates"] == "4", violated_row
assert violated_row["verdict"] == "accepted", violated_row
assert violated_row["detail"] == "comparable_pairs=3 of 4", violated_row
header, rows = summarize(
    quadruple("P", "I0", "10.000", "9.950", "9.950", "10.000"),
    modes=["1100", "800", "1100", "1100"],
    invariants=["held", "violated", "held", "held"])
assert rows[0]["first_delta"] == "clock-violated", rows[0]
assert rows[0]["deltas"] == "clock-violated -0.0050", rows[0]
assert rows[0]["verdict"] == "state-changed", rows[0]
assert rows[0]["detail"] == "comparable_pairs=1 of 2", rows[0]
# A ledger written under the governor names no invariant at all, which is every
# retained campaign's shape, and each pair stays comparable.
header, rows = summarize(
    quadruple("P", "I0", "10.000", "9.950", "9.950", "10.000"),
    modes=["1100"] * 4, invariants=["-"] * 4)
assert rows[0]["deltas"] == "-0.0050 -0.0050", rows[0]
print("controls_clock_violated=accepted")

# The sampler is off on P-nosidecar and W, so those arms carry the unknown
# state and take whatever state their partner held; the sidecar control
# therefore judges every pair it holds.
header, rows = summarize(
    quadruple("P-nosidecar", "P", "10.000", "9.980", "9.980", "10.000"),
    modes=["-", "1100", "800", "-"])
assert rows[0]["verdict"] == "accepted", rows[0]
assert rows[0]["deltas"] == "-0.0020 -0.0020", rows[0]
assert rows[0]["sclk_modes"] == "1100/- 800/-", rows[0]
assert rows[0]["detail"] == "-", rows[0]
# A ledger predating the columns names no mode at all, which is the retained
# campaigns' own shape, and every pair stays comparable.
header, rows = summarize(
    quadruple("I0", "I1", "10.000", "9.850", "9.850", "10.000"))
assert rows[0]["verdict"] == "accepted" and rows[0]["sclk_modes"] == "-/- -/-", rows[0]
print("controls_state_unknown=accepted")

# The sustained regime hovers across fine-grained values rather than holding a
# table step, so the four collect pairs of 20260902T1302Z read 825/837,
# 787/762, 775/800, and 812/825 although all eight arms ran in one regime. The
# band admits every one of them: the widest sits 3.18% apart against a 6%
# default, and the control is judged over four pairs rather than none.
header, rows = summarize(
    quadruple("I0", "I1", "10.000", "9.900", "9.900", "10.000", repeats=2),
    modes=["837", "825", "787", "762", "800", "775", "812", "825"])
assert len(rows) == 1, rows
banded = rows[0]
assert banded["sclk_modes"] == "825/837 787/762 775/800 812/825", banded
assert banded["deltas"] == "-0.0100 -0.0100 -0.0100 -0.0100", banded
assert banded["verdict"] == "accepted" and banded["detail"] == "-", banded
# The boost regime against the sustained one sits 27.27% apart, which no
# plausible band admits, so the step the campaign exists to exclude still
# reads state-changed.
header, rows = summarize(
    quadruple("I0", "I1", "10.000", "9.900", "9.900", "10.000"),
    modes=["1100", "800", "800", "1100"])
assert rows[0]["verdict"] == "state-changed", rows[0]
assert rows[0]["deltas"] == "state-changed state-changed", rows[0]
# The band is a setting rather than a constant: tightened below the sustained
# regime's own spread, the same eight arms lose every pair.
header, rows = summarize(
    quadruple("I0", "I1", "10.000", "9.900", "9.900", "10.000", repeats=2),
    modes=["837", "825", "787", "762", "800", "775", "812", "825"],
    band="0.005")
assert rows[0]["verdict"] == "state-changed", rows[0]
assert rows[0]["detail"] == "comparable_pairs=0 of 4", rows[0]
print("controls_sclk_band=accepted")

# regime_delta is each arm's own distance from the regime the warmups settled
# on, and off_regime_arms counts the arms of a control that exceed the band.
# Two arms agreeing with each other while both sit off the regime form a
# comparable pair, so the count states what the pair comparison cannot.
header, rows = summarize(
    quadruple("I0", "I1", "10.000", "9.900", "9.900", "10.000"),
    modes=["800", "800", "1100", "1100"],
    regime_deltas=["+0.0000", "+0.0000", "+0.2727", "+0.2727"])
assert rows[0]["off_regime_arms"] == "2", rows[0]
assert rows[0]["deltas"] == "-0.0100 -0.0100", rows[0]
assert rows[0]["verdict"] == "accepted", rows[0]
# An unknown distance is uncounted rather than counted as agreeing, so a
# ledger predating the column reports no arm off its regime.
header, rows = summarize(
    quadruple("I0", "I1", "10.000", "9.900", "9.900", "10.000"),
    modes=["800", "800", "800", "800"],
    regime_deltas=["-", "-", "-", "-"])
assert rows[0]["off_regime_arms"] == "0", rows[0]
header, rows = summarize(
    quadruple("I0", "I1", "10.000", "9.900", "9.900", "10.000"))
assert rows[0]["off_regime_arms"] == "0", rows[0]
# An incomplete control and an unregistered quadruple carry the column too,
# since a reader takes every row of this table by the one header.
header, rows = summarize([
    ("I0", "10.000", "reused"), ("I1", "9.900", "skipped"),
    ("I1", "9.900", "reused"), ("I0", "10.000", "reused"),
], modes=["800", "800", "1100", "1100"],
    regime_deltas=["+0.0000", "+0.0000", "+0.2727", "+0.2727"])
assert rows[0]["verdict"] == "incomplete" and rows[0]["off_regime_arms"] == "2", rows[0]
header, rows = summarize(
    quadruple("P", "I1", "10.000", "9.900", "9.900", "10.000"),
    modes=["800", "800", "800", "800"],
    regime_deltas=["+0.0000", "+0.0000", "+0.0000", "+0.0000"])
assert rows[0]["verdict"] == "unclassified" and rows[0]["off_regime_arms"] == "-", rows[0]
print("controls_off_regime_arms=accepted")

# The band that admitted the pair prints beside the bound that judged its
# interval, so the record states both rather than one.
header, rows = summarize(quadruple("P-nosidecar", "P", 3.0, 3.0, 3.0, 3.0), band="0.04")
assert header[header.index("bound") + 1] == "sclk_band", header
assert rows[0]["sclk_band"] == "0.04", rows[0]
header, rows = summarize(quadruple("P-nosidecar", "P", 3.0, 3.0, 3.0, 3.0))
assert rows[0]["sclk_band"] == "0.06", rows[0]

# An infinite bound places every finite interval inside itself and an infinite
# band admits every pair of positive clocks, so each retires the condition it
# names. The range is checked where argparse reads the value.
ledger = write("range-arms.tsv",
               arms_ledger(quadruple("P-nosidecar", "P", 3.0, 3.1, 2.9, 3.0)))
for flag, value in (("--sidecar-bound", "inf"), ("--sidecar-bound", "-0.1"),
                    ("--compile-bound", "nan"), ("--collect-bound", "inf"),
                    ("--served-ab-bound", "inf"), ("--sclk-band", "inf"),
                    ("--sclk-band", "1.0"), ("--sclk-band", "-0.01")):
    argv = [sys.executable, controls, ledger, "--sidecar-bound", "0.0065",
            "--compile-bound", "0.0065", "--collect-bound", "0.02"]
    argv += [flag, value]
    result = subprocess.run(argv, capture_output=True, text=True)
    assert result.returncode == 2, (flag, value, result.returncode, result.stderr)
    assert f"{flag} is {float(value)}" in result.stderr, (flag, value, result.stderr)
print("controls_bound_ranges=accepted")

slice_text = "\n".join([
    "srv  log_server_r: request: POST /v1/chat/completions",
    "----------------",
    "Vulkan Timings:",
    "MUL_MAT_VEC q4_K m=2048 n=1 k=2048: 24 x 120.5 us = 2892.0 us (12.3 GFLOPS/s)",
    "RMS_NORM(2048,1,1,1), MUL: 48 x 4.0 us = 192.0 us",
    "ROPE: 24 x 3.0 us = 72.0 us",
    "Total time: 3156.0 us.",
    "----------------",
    "Vulkan Timings:",
    "MUL_MAT_VEC q4_K m=2048 n=1 k=2048: 24 x 121.5 us = 2916.0 us (12.2 GFLOPS/s)",
    "RMS_NORM(2048,1,1,1), MUL: 48 x 4.0 us = 192.0 us",
    "ROPE: 24 x 3.0 us = 72.0 us",
    "Total time: 3180.0 us.",
    "",
])
slice_path = write("slice.log", slice_text)
result = subprocess.run([sys.executable, slicer, slice_path, "--expected-decode-blocks", "2"],
                        capture_output=True, text=True)
assert result.returncode == 0, result.stderr
rows = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
assert rows[0][0] == "op", rows
summary = {row[0]: row for row in rows if row[0] != "op"}
assert summary["blocks"][1] == "2" and summary["decode_blocks"][1] == "2", summary
assert summary["prefill_blocks"][1] == "0" and summary["unknown_blocks"][1] == "0", summary
inventory = {row[1]: row for row in rows[1:] if row[0] == "op"}
assert inventory["MUL_MAT"][2] == "24.000" and inventory["MUL_MAT"][3] == "5808.0", inventory
assert inventory["RMS_NORM"][2] == "48.000" and inventory["MUL"][2] == "48.000", inventory
assert inventory["ROPE"][2] == "24.000", inventory
result = subprocess.run([sys.executable, slicer, slice_path, "--expected-decode-blocks", "3"],
                        capture_output=True, text=True)
assert result.returncode != 0 and "holds 2 decode blocks of 2" in result.stderr, result.stderr
print("perf_logger_slice=accepted")

for name in os.listdir(work):
    os.unlink(os.path.join(work, name))
os.rmdir(work)
print("census_controls=accepted")
