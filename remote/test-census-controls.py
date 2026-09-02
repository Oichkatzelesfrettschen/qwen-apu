#!/usr/bin/env python3
"""The three census campaign helpers over synthetic records.

validate-clock-sidecar.py accepts a record whose header, columns, rows,
footer, period, cost, sensors, adjacent gaps, and window coverage each
hold, and refuses one record per broken condition; a hole the run-wide
achieved period absorbs is refused by the gap bound where it falls inside
the request window and accepted where it falls outside.
summarize-census-controls.py assigns the
sidecar, compile, and collect bounds to the three registered quadruple shapes
alone, collapses every replicate of a control onto one row, judges that row by
whether its nominal 95% interval sits inside, outside, or across the bound,
marks an unregistered quadruple unclassified, names the direction of a refuted
interval, and keeps S and the warmup arm W outside the parser. It judges a
control over the pairs whose two arms held one selected graphics clock,
excluding a pair that straddled a governor step and reading the whole control
`state-changed` where fewer than two comparable pairs survive. The appliance
tables of 20260902T0819Z and 20260902T1302Z are replayed here: the first
resolves none of the three controls at two replicates, and the second steps
from 1100 MHz to 800 MHz partway through the arm list. summarize-perf-logger-slice.py classifies each block by the largest
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


def write(name, text):
    path = os.path.join(work, name)
    with open(path, "w") as handle:
        handle.write(text)
    return path


def sidecar_record(samples=100, period_ns=5_000_000, cost_ns=30_000, start=1_000_000_000,
                   unavailable_rows=(), footer=None, columns=COLUMNS, header_period=None,
                   footers=1, hole_after=None, hole_ns=0, achieved_period_ns=None):
    """Write one synthetic record; hole_ns is the delay inserted after hole_after.

    A hole shifts every later row by hole_ns, so the gap it opens is the
    period plus hole_ns, and achieved_period_ns keeps the footer declaring
    the mean a real sampler would report where the rows carry a hole or a
    period of their own.
    """
    def instant_of(index):
        delay = hole_ns if hole_after is not None and index > hole_after else 0
        return start + index * period_ns + delay

    lines = [
        f"# clock=CLOCK_MONOTONIC period_ns={header_period or period_ns} drm_device=/fake hwmon=/fake/hwmon0",
        "# interpretation: pp_dpm_sclk_selected_mhz is the selected graphics clock step",
        "# sampler_pid=4242 nice=10 cpu_affinity=1",
        columns,
    ]
    for index in range(samples):
        instant = instant_of(index)
        fclk = "unavailable" if index in unavailable_rows else "1067"
        lines.append(f"{instant}\t400\t933\t{fclk}\t37\t61000\t{cost_ns}")
    last = instant_of(samples - 1)
    footer_line = footer or (
        f"# samples={samples} achieved_period_ns={achieved_period_ns or period_ns}"
        f" mean_sample_cost_ns={cost_ns}"
        f" max_sample_cost_ns={cost_ns * 2} samples_with_unavailable_sensor={len(unavailable_rows)}"
        f" first_sample_ns={start} last_sample_ns={last}")
    lines.extend([footer_line] * footers)
    return "\n".join(lines) + "\n"


def validate(text, status=0, window=(1_050_000_000, 1_400_000_000), tolerance="0.25",
             cost_bound="1000000", period_ms="5", allow=(), max_gap="50000000",
             max_lost="0.02"):
    path = write("sidecar.tsv", text)
    command = [sys.executable, validator, path, "--sidecar-status", str(status),
               "--period-ms", period_ms, "--period-tolerance", tolerance,
               "--cost-bound-ns", cost_bound, "--max-gap-ns", max_gap,
               "--max-lost-fraction", max_lost]
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
holed = sidecar_record(hole_after=20, hole_ns=100_000_000, achieved_period_ns=5_000_000)
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
sliced = sidecar_record(hole_after=20, hole_ns=30_000_000, achieved_period_ns=5_000_000)
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
loose = sidecar_record(period_ns=8_000_000, header_period=5_000_000,
                       achieved_period_ns=5_000_000)
result = validate(loose)
assert result.returncode == 0, result.stdout
assert "over_1_5x=99 over_missed=0 over_max=0" in result.stdout, result.stdout
assert "window_lost=accepted window_lost_fraction=0.0000" in result.stdout, result.stdout
assert "clock_sidecar=accepted failures=-" in result.stdout, result.stdout
refused(loose, "gaps", max_gap="7000000")
# One row carries no adjacent gap to measure.
result = validate(sidecar_record(samples=1))
assert "gaps=not_run rows=1" in result.stdout, result.stdout
print("sidecar_gaps=accepted")


def arms_ledger(rows, modes=None):
    """One ledger; modes is a per-row selected graphics clock, `-` by default.

    A ledger written before the clock-state columns existed omits them
    entirely, which is what `modes=None` writes, so the retained campaigns
    replay through the same reader.
    """
    header = ("slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s"
              "\tcensus_rows\tsidecar\tstatus")
    if modes is not None:
        header += "\tsclk_mode_mhz\tsclk_share"
    lines = [header]
    for slot, (arm, rate, status) in enumerate(rows, 1):
        line = f"{slot}\t{arm}\tabc\t64\t6000\t{rate}\t-\ton\t{status}"
        if modes is not None:
            mode = modes[slot - 1]
            share = "-" if mode == "-" else "0.9800"
            line += f"\t{mode}\t{share}"
        lines.append(line)
    return "\n".join(lines) + "\n"


def summarize(rows, sidecar="0.0065", compile_bound="0.0065", collect="0.02",
              modes=None):
    """Run the controls summarizer and return its rows as field maps.

    The verdict is over every replicate of a control, so the columns a case
    reads are named rather than counted: a row gains statistics between the
    per-replicate columns and the bound, and a positional read would follow
    the wrong field once a column lands between them.
    """
    path = write("arms.tsv", arms_ledger(rows, modes))
    result = subprocess.run([sys.executable, controls, path, "--sidecar-bound", sidecar,
                             "--compile-bound", compile_bound, "--collect-bound", collect],
                            capture_output=True, text=True)
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
          "sd_delta", "ci_low", "ci_high", "deltas", "sclk_modes", "bound", "verdict",
          "detail")

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
