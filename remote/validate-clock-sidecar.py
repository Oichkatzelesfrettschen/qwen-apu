#!/usr/bin/env python3
"""Decide whether one clock sidecar record is evidence.

sample-clock-sidecar.py writes a header, one row per sample, and one footer.
A record is evidence for an arm only where the sampler exited cleanly, held
its period, cost what it claims, read every sensor on every sample, and
covered the request window on both sides; a record failing any of those is
a file that exists rather than a measurement, and the runner treats the arm
as failed. A sensor the kernel reports empty on the measured machine, which
on the SMU10 path is `pp_dpm_fclk`, is named with `--allow-unavailable` so
its column may read `unavailable` on every row while any other column may
not. Every condition prints as a `key=value` line, the last line reads
`clock_sidecar=accepted` or `clock_sidecar=refused`, and the exit status
follows it.

The run-wide achieved period the footer declares is a mean, so a 100 ms
hole surrounded by perfect 5 ms samples holds it while losing two 2B token
intervals. Coverage rather than the widest gap is what a record owes the
arm, and the two are measured separately. Every gap between consecutive
`monotonic_ns` rows is measured; a gap wider than two requested periods has
missed at least one scheduled sample, and the window-clipped duration of
those gaps summed over the request window is `window_lost_fraction`, the
fraction of the window the record can place no clock step in.
`--max-lost-fraction` bounds it, and that is the coverage criterion.

A sampler at nice 19 sharing two cores with a server at nice 19 is held off
for scheduler slices, which is measured on the appliance rather than
conjectured: per window 3 to 5 gaps over 20 ms with a 60 to 119 ms maximum
and a lost fraction of 0.0122 to 0.0147, and the gaps do not follow a slow
sysfs read, since the preceding sample cost 0.2 to 1.0 ms at almost every
one. A CFS slice is therefore an observation the `gaps` line reports with
its distribution, its maximum, and its counts. `--max-gap-ns` refuses a
stall rather than a slice: one gap of ten requested periods overlapping the
window, 100 ms at the appliance's 10 ms period, is a sampler that stopped.
A gap [t_i, t_i+1] overlaps the window where t_i+1 exceeds the window begin
and t_i falls below the window end; a record supplied with no window is
refused by an over-bound gap anywhere and reports no lost fraction.

Beside the verdict lines the reader prints one `clock_state=` line
describing the execution state the request window ran under: the modal
selected graphics clock, the fraction of window samples holding it, the
modal MCLK surface, the mean and maximum die temperature, and the mean
GPU busy percentage. A control pair whose two arms ran under different
selected graphics clocks measures the governor, so the mode is what a
campaign compares before it takes a paired delta. The line is an
observation and the verdict stays what the conditions above decide.
Sensors read `unavailable` are unknown rather than a state of their own,
so they leave the mode out of the reading and the line prints `-`.

`--required-sclk-mhz N` and `--required-mclk-mhz M` state the operating
point a campaign pinned and turn the clock reading into a verdict
condition. The graphics figure is read from `sclk_actual_mhz` where the
record carries it and from `pp_dpm_sclk_selected_mhz` otherwise, because
the delivered frequency answers what the selected step only requests: a
forced performance level pins the step and leaves the fabric clock free,
which is how an appliance arm ran every sample at the pinned 1100 MHz step
and decoded slower than the governor did. N is an equality within one
percent, since a pinned step reports one value here and its neighbouring
table entry sits several percent away, so the one percent is a window on
both sides and a sample above it joins `samples_above_required` and
violates the invariant the same way one below does; M is a floor over
`pp_dpm_mclk_surface_mhz`, since the fabric clock rises under load and a
campaign asks it to stay at or above its selection. The floor carries a
tolerance where the graphics equality carries none, because the fabric
hovers: arm 03-P of the 20260902T2011Z calibration read 933 MHz on 356 of
358 window samples with excursions to 1067 above and two samples below,
while the graphics clock read the pinned 1100 on every one.
`--max-below-mclk-floor-fraction` is the admitted share of window samples
under the floor, 0.01 by default, and the counts print whatever it admits.
`clock_invariant=held|violated
samples_at_required=.. samples_below_required=.. below_required_fraction=..`
prints ahead of the verdict with the fabric counts beside it, and a
violation of either joins `failures`. A requested invariant that can be
measured on no sample -- no window, no readable step -- reads `violated`,
since an unpinned clock is what the condition exists to catch and an empty
count proves nothing. Neither argument carries a default, so a campaign
under the appliance's own `auto` governor prints
`clock_invariant=not_requested` and the regime taxonomy beside it decides
comparability as before. The line grows at its tail, so a reader lifting a
key off a retained verdict finds it where it was.

The invariant counts fresh DPM reads rather than rows. telemetry-broker.c
reads `pp_dpm_sclk`, `pp_dpm_mclk`, and hwmon `freq1_input` once every
`DPM_PERIOD_MULTIPLE` ticks and repeats the cached value on the rows
between, so counting rows multiplies one read by that multiple and prices
the floor tolerance against an inflated denominator. A broker marking its
reads writes one `# dpm_read=INSTANT` line ahead of the row that carried
the read, and that marker is the authority, because the ring stops
appending at `SAMPLE_CAPACITY` while the tick counter advances and row
index then tracks tick no longer. A record carrying no marker -- every
retained record, and every record `sample-clock-sidecar.py` writes -- is
read through the `pp_dpm_period_ns` key of the broker's own
`# sample_rates:` header: the multiple is that period over the requested
one, every multiple-th row is fresh, and a header naming no such key is a
sampler reading the attributes on every sample, so the multiple is 1 and
every row is fresh. `dpm_freshness=marker|derived dpm_period_multiple=N
fresh_dpm_samples=M` states which of the two the verdict rests on.

Every derived quantity is computed from the rows and the footer is held to
it. `achieved_period` is `(last - first) // (samples - 1)` over the row
instants, `sample_cost` is the mean and maximum of the `sample_cost_ns`
column, and `footer_derived` refuses a footer disagreeing with either, so a
footer claiming 10 ms over rows 19 ms apart fails where the tolerance alone
admitted it. A sensor cell reads a decimal or the `unavailable` sentinel and
any other text refuses the record at `cell_values` rather than being swallowed
by the count that reads it. `monotonic_ns` rises strictly, since a
CLOCK_MONOTONIC sequence that steps backward is malformed rather than slow,
and `--window-end-ns` exceeds `--window-begin-ns`, since a reversed pair
selects no row and reports a lost fraction of zero from a clamped
denominator. Each bound argument is finite and inside the range it is
defined over, checked where it is parsed: an infinite tolerance retires the
period condition, an infinite lost fraction retires coverage, and an
infinite floor share retires the fabric half of the invariant.

usage: validate-clock-sidecar.py RECORD_TSV --sidecar-status N
       --period-ms F --period-tolerance F --cost-bound-ns N
       [--max-gap-ns N] [--max-lost-fraction F]
       [--window-begin-ns N --window-end-ns N]
       [--allow-unavailable COLUMN ...]
       [--required-sclk-mhz N] [--required-mclk-mhz M]
       [--max-below-mclk-floor-fraction F]
"""
import argparse
import math
import sys

# telemetry-broker.c writes this token ahead of the row whose sample refreshed
# the DPM attributes; every other row repeats the cached reading.
DPM_READ_PREFIX = "# dpm_read="

COLUMNS = (
    "monotonic_ns",
    "pp_dpm_sclk_selected_mhz",
    "pp_dpm_mclk_surface_mhz",
    "pp_dpm_fclk_surface_mhz",
    "gpu_busy_percent",
    "temp1_millidegrees",
    "sample_cost_ns",
)
# telemetry-broker.c appends the delivered graphics frequency after the seven
# columns sample-clock-sidecar.py writes, so a record is one width or the
# other and the retained corpus reads unchanged.
ACTUAL_COLUMN = "sclk_actual_mhz"
WIDE_COLUMNS = COLUMNS + (ACTUAL_COLUMN,)
FOOTER_KEYS = (
    "samples",
    "achieved_period_ns",
    "mean_sample_cost_ns",
    "max_sample_cost_ns",
    "samples_with_unavailable_sensor",
    "first_sample_ns",
    "last_sample_ns",
)


def nearest_rank(sorted_values, permille):
    """Return the nearest-rank quantile, the ceil(q x n)-th smallest value.

    The quantile arrives in permille and the rank is computed in integers, so
    the rank of p95 over 100 gaps is 95 rather than whatever the float
    product of 0.95 and 100 rounds to.
    """
    count = len(sorted_values)
    index = -(-permille * count // 1000) - 1
    return sorted_values[min(max(index, 0), count - 1)]


def modal_value(values):
    """The most frequent value and its share, ties broken by the smaller value.

    The mode feeds a pair-equality test that decides a campaign verdict, so
    two states at equal counts resolve to the same one on every run. The
    values arrive as the record's own text and the mode prints as that text
    while the tie-break orders them as numbers, since a lexicographic order
    resolves a 900/1100 tie to 1100.
    """
    if not values:
        return None, None
    counts = {}
    for value in values:
        counts[value] = counts.get(value, 0) + 1

    def order(value):
        try:
            number = float(value)
        except ValueError:
            number = math.inf
        return (-counts[value], number, value)

    mode = sorted(counts, key=order)[0]
    return mode, counts[mode] / len(values)


def decimal_or_unavailable(cell):
    """Whether one sensor cell reads a decimal number or the empty sentinel.

    A cell reading anything else -- a kernel read error, a truncated write --
    carries no clock evidence while satisfying a comparison against the
    `unavailable` literal alone, and it surfaces differently in each consumer:
    the counts skip it, the mode reports the text as a state, and the
    temperature read raises. The record is refused where the cell is read.
    """
    if cell == "unavailable":
        return True
    try:
        return math.isfinite(float(cell))
    except ValueError:
        return False


def parse_key_values(text):
    values = {}
    for token in text.split():
        key, separator, value = token.partition("=")
        if not separator:
            continue
        values[key] = value
    return values


def count_against(rows, index, required, two_sided):
    """Split rows by where one column sits against the required megahertz.

    A sample one percent under the requirement is that value read through the
    kernel's own rounding rather than a step below it. `two_sided` decides
    what happens above it: the graphics caller states an equality, so a
    reading a percent over the pin is a step the policy claims it cannot
    reach and it counts above; the fabric caller states a floor, so
    everything at or over it counts at the floor. An `unavailable`, a
    non-finite, or an unparseable reading is unknown rather than low and
    enters no count, since a non-finite value compares false against every
    threshold and would otherwise land at the requirement. No requirement
    counts nothing.
    """
    if required is None:
        return 0, 0, 0
    lower = required * 0.99
    upper = required * 1.01
    at_required = 0
    below_required = 0
    above_required = 0
    for row in rows:
        if index >= len(row) or row[index] == "unavailable":
            continue
        try:
            value = float(row[index])
        except ValueError:
            continue
        if not math.isfinite(value):
            continue
        if value < lower:
            below_required += 1
        elif two_sided and value > upper:
            above_required += 1
        else:
            at_required += 1
    return at_required, below_required, above_required


def read_record(path):
    header_lines = []
    footer_lines = []
    column_line = None
    rows = []
    # The freshness markers keep their own list so their instants stay out of
    # the merged header dictionary the three header conditions read.
    dpm_read_instants = set()
    with open(path) as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if line.startswith("# samples="):
                footer_lines.append(line)
            elif line.startswith(DPM_READ_PREFIX):
                dpm_read_instants.add(line[len(DPM_READ_PREFIX):].strip())
            elif line.startswith("#"):
                header_lines.append(line)
            elif column_line is None:
                column_line = line
            elif line:
                rows.append(line.split("\t"))
    return header_lines, column_line, rows, footer_lines, dpm_read_instants


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("record")
    parser.add_argument("--sidecar-status", type=int, required=True)
    parser.add_argument("--period-ms", type=float, required=True)
    parser.add_argument("--period-tolerance", type=float, required=True)
    parser.add_argument("--cost-bound-ns", type=int, required=True)
    # Ten requested periods at the appliance's 10 ms sampler: a stall rather
    # than a slice. The coverage criterion is --max-lost-fraction beside it.
    parser.add_argument("--max-gap-ns", type=int, default=100_000_000)
    # Coverage for a clock-state record rather than a safety ceiling: at a
    # 20 ms period 0.03 of the window is under 15 samples of 400 and every
    # sample the record does hold still enters the clock invariant.
    parser.add_argument("--max-lost-fraction", type=float, default=0.03)
    parser.add_argument("--window-begin-ns", type=int)
    parser.add_argument("--window-end-ns", type=int)
    parser.add_argument("--allow-unavailable", action="append", default=[])
    # No default: a campaign running under the appliance's own governor states
    # no required clock, and any default would turn every retained record into
    # a verdict about a pin it never ran under.
    parser.add_argument("--required-sclk-mhz", type=int)
    parser.add_argument("--required-mclk-mhz", type=int)
    # The fabric floor takes a tolerance where the graphics equality takes
    # none: the fabric hovers under load with transient excursions on both
    # sides of its selection, which arm 03-P of the 20260902T2011Z calibration
    # measured as 2 samples of 358 below 933 MHz while the graphics clock held
    # 1100 on every one.
    parser.add_argument("--max-below-mclk-floor-fraction", type=float,
                        default=0.01)
    args = parser.parse_args()

    # Each bound reaches argparse as a bare float, and an infinite one retires
    # the condition it names while every other condition stays silent about
    # it: an infinite period tolerance admits a sampler at any cadence, an
    # infinite lost fraction admits a record that observed nothing, and an
    # infinite floor share admits a fabric that left its floor. The range is
    # checked where the value is parsed, ahead of any read of the record.
    def bounded(name, value, lower, upper):
        if not math.isfinite(value) or not lower <= value <= upper:
            parser.error(f"{name} is {value}; a finite value in "
                         f"[{lower}, {upper}] is required")

    bounded("--period-ms", args.period_ms, 1e-6, 3_600_000.0)
    bounded("--period-tolerance", args.period_tolerance, 0.0, 1.0)
    bounded("--max-lost-fraction", args.max_lost_fraction, 0.0, 1.0)
    bounded("--max-below-mclk-floor-fraction",
            args.max_below_mclk_floor_fraction, 0.0, 1.0)

    failures = []

    def check(name, passed, detail):
        print(f"{name}={'accepted' if passed else 'refused'} {detail}")
        if not passed:
            failures.append(name)

    check("sidecar_exit", args.sidecar_status == 0, f"status={args.sidecar_status}")
    try:
        (header_lines, column_line, rows, footer_lines,
         dpm_read_instants) = read_record(args.record)
    except OSError as error:
        print(f"record_readable=refused error={error}")
        print("clock_sidecar=refused")
        return 1
    check("record_readable", True, f"path={args.record}")

    header = {}
    for line in header_lines:
        header.update(parse_key_values(line.lstrip("# ")))
    requested_period_ns = int(round(args.period_ms * 1_000_000))
    check("clock", header.get("clock") == "CLOCK_MONOTONIC", f"clock={header.get('clock', '-')}")
    check("period_declared", header.get("period_ns") == str(requested_period_ns),
          f"declared={header.get('period_ns', '-')} requested={requested_period_ns}")
    check("sampler_identity", "sampler_pid" in header and "nice" in header and "cpu_affinity" in header,
          f"pid={header.get('sampler_pid', '-')} nice={header.get('nice', '-')} cpu_affinity={header.get('cpu_affinity', '-')}")
    wide = column_line == "\t".join(WIDE_COLUMNS)
    expected_columns = WIDE_COLUMNS if wide else COLUMNS
    check("columns", column_line in ("\t".join(COLUMNS), "\t".join(WIDE_COLUMNS)),
          f"columns={column_line or '-'} width={len(expected_columns)}")
    check("footer_cardinality", len(footer_lines) == 1, f"footers={len(footer_lines)}")
    footer = parse_key_values(footer_lines[0].lstrip("# ")) if len(footer_lines) == 1 else {}
    footer_complete = all(key in footer and footer[key].lstrip("-").isdigit() for key in FOOTER_KEYS)
    check("footer_fields", footer_complete, f"present={','.join(sorted(footer))}")
    if not footer_complete:
        print("clock_sidecar=refused")
        return 1
    samples = int(footer["samples"])
    check("samples", samples > 1 and samples == len(rows), f"samples={samples} rows={len(rows)}")
    row_arity = all(len(row) == len(expected_columns) for row in rows)
    check("row_arity", row_arity, f"columns={len(expected_columns)}")
    # Every later condition reads these cells as numbers, so the record is held
    # to them here rather than in each consumer. The sensor indices cover the
    # delivered-frequency column of a wide record too, since that is the column
    # the graphics invariant is read from.
    sensor_indices = list(range(1, 6)) + ([len(COLUMNS)] if wide else [])
    if rows and row_arity:
        bad_cells = sorted({
            expected_columns[index] for row in rows
            for index in [0, 6] + sensor_indices
            if (not row[index].isdigit() if index in (0, 6)
                else not decimal_or_unavailable(row[index]))})
        check("cell_values", not bad_cells,
              f"nonnumeric_columns={','.join(bad_cells) or '-'}")
        if bad_cells:
            print("clock_sidecar=refused failures="
                  f"{','.join(failures)}")
            return 1
    else:
        print("cell_values=not_run rows=%d" % len(rows))
    # The footer states the run mean and the rows carry the instants and costs
    # it is a function of, so the reader computes both and holds the footer to
    # them: a footer claiming 10 ms over rows 19 ms apart passes the tolerance
    # while every individual gap stays under the missed-sample threshold.
    # telemetry-broker.c and sample-clock-sidecar.py both floor-divide, so the
    # agreement is exact rather than within a nanosecond.
    achieved = int(footer["achieved_period_ns"])
    mean_cost = int(footer["mean_sample_cost_ns"])
    max_cost = int(footer["max_sample_cost_ns"])
    derived_achieved = achieved
    derived_mean_cost = mean_cost
    derived_max_cost = max_cost
    if rows and row_arity:
        instants = [int(row[0]) for row in rows]
        costs = [int(row[6]) for row in rows]
        derived_achieved = ((instants[-1] - instants[0]) // (len(rows) - 1)
                            if len(rows) >= 2 else 0)
        derived_mean_cost = sum(costs) // len(costs)
        derived_max_cost = max(costs)
        check("footer_derived",
              derived_achieved == achieved and derived_mean_cost == mean_cost
              and derived_max_cost == max_cost,
              f"achieved_ns={derived_achieved} footer_achieved_ns={achieved}"
              f" mean_cost_ns={derived_mean_cost} footer_mean_cost_ns={mean_cost}"
              f" max_cost_ns={derived_max_cost} footer_max_cost_ns={max_cost}")
    else:
        print("footer_derived=not_run rows=%d" % len(rows))
    lower = requested_period_ns * (1.0 - args.period_tolerance)
    upper = requested_period_ns * (1.0 + args.period_tolerance)
    check("achieved_period", lower <= derived_achieved <= upper,
          f"achieved_ns={derived_achieved} requested_ns={requested_period_ns} tolerance={args.period_tolerance}")
    check("sample_cost", derived_mean_cost <= args.cost_bound_ns,
          f"mean_ns={derived_mean_cost} max_ns={derived_max_cost} bound_ns={args.cost_bound_ns}")
    unavailable = int(footer["samples_with_unavailable_sensor"])
    allowed = set(args.allow_unavailable)
    unknown_allowed = allowed - set(COLUMNS[1:6])
    check("allowed_columns", not unknown_allowed, f"allowed={','.join(sorted(allowed)) or '-'}")
    if rows and row_arity:
        unavailable_rows = sum(1 for row in rows if "unavailable" in row[1:6])
        check("sensor_rows", unavailable_rows == unavailable,
              f"rows_with_unavailable={unavailable_rows} footer={unavailable}")
        refused_columns = sorted({
            COLUMNS[index] for row in rows for index in range(1, 6)
            if row[index] == "unavailable" and COLUMNS[index] not in allowed})
        check("sensors", not refused_columns,
              f"unavailable_outside_allowance={','.join(refused_columns) or '-'} allowed={','.join(sorted(allowed)) or '-'}")
        first = int(rows[0][0])
        last = int(rows[-1][0])
        check("footer_instants", first == int(footer["first_sample_ns"]) and last == int(footer["last_sample_ns"]),
              f"first={first} last={last}")
        # A CLOCK_MONOTONIC sequence rises strictly, so a row at or before its
        # predecessor is a malformed record rather than a slow one: every gap
        # comparison is one-sided, so a backward instant lowers the reported
        # quantiles and subtracts time from the lost fraction.
        instant_order = all(later > earlier for earlier, later
                            in zip((int(row[0]) for row in rows),
                                   (int(row[0]) for row in rows[1:])))
        check("instant_order", instant_order,
              f"first={first} last={last} rows={len(rows)}")
        windowed = args.window_begin_ns is not None and args.window_end_ns is not None
        if windowed:
            # Ordered endpoints before coverage: a reversed pair lies inside
            # the record on both sides, selects no row, and reports a lost
            # fraction of zero out of a denominator clamped to one nanosecond.
            check("window_order", args.window_end_ns > args.window_begin_ns,
                  f"begin={args.window_begin_ns} end={args.window_end_ns}")
            check("window_coverage", first <= args.window_begin_ns and last >= args.window_end_ns,
                  f"first={first} begin={args.window_begin_ns} end={args.window_end_ns} last={last}")
        else:
            print("window_order=not_run no window supplied")
            print("window_coverage=not_run no window supplied")
        # The footer's achieved period is the run mean, which a hole one token
        # wide leaves inside tolerance. The adjacent gaps carry that hole, and
        # only a gap overlapping the request window costs the arm its samples,
        # so the verdict counts over-bound gaps inside the window while the
        # detail reports the whole distribution.
        if len(rows) >= 2:
            instants = [int(row[0]) for row in rows]
            gaps = [later - earlier for earlier, later in zip(instants, instants[1:])]
            ordered = sorted(gaps)
            loose_bound = requested_period_ns * 3 // 2
            # A gap wider than two requested periods has missed at least one
            # scheduled sample, which is the threshold the lost time
            # accumulates over; the stall bound plays no part in it.
            missed_bound = requested_period_ns * 2
            over_loose = sum(1 for gap in gaps if gap > loose_bound)
            over_missed = sum(1 for gap in gaps if gap > missed_bound)
            over_max = sum(1 for gap in gaps if gap > args.max_gap_ns)
            if windowed:
                stalls_in_window = [
                    index for index, gap in enumerate(gaps)
                    if gap > args.max_gap_ns
                    and instants[index + 1] > args.window_begin_ns
                    and instants[index] < args.window_end_ns]
                in_window = len(stalls_in_window)
                # The window time inside gaps that missed a sample, as the
                # fraction of the window the record can place no clock step in.
                lost_ns = sum(
                    min(instants[index + 1], args.window_end_ns)
                    - max(instants[index], args.window_begin_ns)
                    for index, gap in enumerate(gaps)
                    if gap > missed_bound
                    and instants[index + 1] > args.window_begin_ns
                    and instants[index] < args.window_end_ns)
                window_ns = max(1, args.window_end_ns - args.window_begin_ns)
                lost_fraction = lost_ns / window_ns
            else:
                in_window = over_max
                lost_fraction = 0.0
            # The distribution is an observation of how CFS shares two cores
            # between a nice-19 sampler and a nice-19 server; the verdict on
            # this line is the stall alone.
            check("gaps", in_window == 0,
                  f"median_ns={nearest_rank(ordered, 500)} p95_ns={nearest_rank(ordered, 950)}"
                  f" p99_ns={nearest_rank(ordered, 990)} max_ns={ordered[-1]}"
                  f" over_1_5x={over_loose} over_missed={over_missed} over_max={over_max}")
            if windowed:
                check("window_lost", lost_fraction <= args.max_lost_fraction,
                      f"window_lost_fraction={lost_fraction:.4f}"
                      f" bound={args.max_lost_fraction:.4f}"
                      f" missed_bound_ns={missed_bound}")
                print(f"gaps_in_window={in_window} begin={args.window_begin_ns}"
                      f" end={args.window_end_ns} bound_ns={args.max_gap_ns}"
                      f" window_lost_fraction={lost_fraction:.4f}")
            else:
                print("window_lost=not_run no window supplied"
                      f" bound={args.max_lost_fraction:.4f}")
                print(f"gaps_in_window=not_run no window supplied bound_ns={args.max_gap_ns}")
        else:
            print(f"gaps=not_run rows={len(rows)}")
    # The execution state the request window ran under, printed beside the
    # conditions above and counted in none of them. A campaign compares the
    # modal selected graphics clock of two arms before it takes their paired
    # delta, since a pair straddling a governor step measures the step.
    window_defined = args.window_begin_ns is not None and args.window_end_ns is not None
    window_rows = []
    if rows and row_arity and window_defined:
        window_rows = [row for row in rows
                       if args.window_begin_ns <= int(row[0]) <= args.window_end_ns]
        sclk_mode, sclk_share = modal_value(
            [row[1] for row in window_rows if row[1] != "unavailable"])
        mclk_mode, _ = modal_value(
            [row[2] for row in window_rows if row[2] != "unavailable"])
        temperatures = [float(row[5]) / 1000.0 for row in window_rows
                        if row[5] != "unavailable"]
        busy = [float(row[4]) for row in window_rows if row[4] != "unavailable"]
        share_text = "-" if sclk_share is None else f"{sclk_share:.4f}"
        temp_mean = f"{sum(temperatures) / len(temperatures):.1f}" if temperatures else "-"
        temp_max = f"{max(temperatures):.1f}" if temperatures else "-"
        busy_mean = f"{sum(busy) / len(busy):.2f}" if busy else "-"
        print(f"clock_state=measured window_samples={len(window_rows)}"
              f" sclk_mode_mhz={sclk_mode if sclk_mode is not None else '-'}"
              f" sclk_share={share_text}"
              f" mclk_mode_mhz={mclk_mode if mclk_mode is not None else '-'}"
              f" temp_mean_c={temp_mean} temp_max_c={temp_max} busy_mean={busy_mean}")
    elif not window_defined:
        print("clock_state=not_run no window supplied")
    else:
        print(f"clock_state=not_run rows={len(rows)}")
    # The DPM channel reads its attributes once every multiple-th tick and the
    # rows between repeat the cached value, so the invariant counts the rows
    # that carried a read. A marker is the authority because the ring stops
    # appending at its capacity while the tick counter advances; a record
    # carrying none is read through the declared channel period, and a header
    # naming no such period is a sampler reading on every tick.
    dpm_period_ns = header.get("pp_dpm_period_ns")
    try:
        dpm_multiple = max(1, int(dpm_period_ns) // requested_period_ns)
    except (TypeError, ValueError, ZeroDivisionError):
        dpm_multiple = 1
    if dpm_read_instants:
        freshness_source = "marker"
        fresh_rows = [row for row in window_rows if row[0] in dpm_read_instants]
    else:
        freshness_source = "derived"
        fresh_instants = {rows[index][0] for index in range(0, len(rows), dpm_multiple)} \
            if rows and row_arity else set()
        fresh_rows = [row for row in window_rows if row[0] in fresh_instants]
    freshness = (f"dpm_freshness={freshness_source}"
                 f" dpm_period_multiple={dpm_multiple}"
                 f" fresh_dpm_samples={len(fresh_rows)}")
    # The invariant a forced clock policy replaces the regime taxonomy with. A
    # sample reading below the required step is the governor moving under a
    # policy that states it cannot, which is the one observation that costs the
    # arm; an unavailable step is unknown rather than low and enters neither
    # count, since the sensor conditions above already refuse it outside the
    # kernel's own empty-attribute allowance.
    if args.required_sclk_mhz is None and args.required_mclk_mhz is None:
        print(f"clock_invariant=not_requested {freshness}")
    else:
        # The delivered frequency where the record carries it, the requested
        # step otherwise. A campaign under a forced level asks the first
        # question and a record written before the column existed answers only
        # the second, so the source is named on the line rather than assumed.
        sclk_index = len(COLUMNS) if wide else 1
        sclk_source = ACTUAL_COLUMN if wide else COLUMNS[1]
        at_required, below_required, above_required = count_against(
            fresh_rows, sclk_index, args.required_sclk_mhz, True)
        sclk_counted = at_required + below_required + above_required
        sclk_held = (args.required_sclk_mhz is None
                     or (sclk_counted > 0 and below_required == 0
                         and above_required == 0))
        fraction = below_required / sclk_counted if sclk_counted else 1.0
        at_floor, below_floor, _ = count_against(fresh_rows, 2,
                                                 args.required_mclk_mhz, False)
        mclk_counted = at_floor + below_floor
        mclk_fraction = below_floor / mclk_counted if mclk_counted else 1.0
        # The floor holds within a tolerance and the graphics equality holds
        # exactly, because the two clocks answer differently: a pinned
        # graphics step reports one value on every sample, while the fabric
        # hovers under load and dips below its own selection for a sample at a
        # time. A window whose fabric never reads is unknown rather than held.
        mclk_held = (args.required_mclk_mhz is None
                     or (mclk_counted > 0
                         and mclk_fraction <= args.max_below_mclk_floor_fraction))
        held = sclk_held and mclk_held
        print(f"clock_invariant={'held' if held else 'violated'}"
              f" samples_at_required={at_required}"
              f" samples_below_required={below_required}"
              f" below_required_fraction={fraction:.4f}"
              f" sclk_source={sclk_source}"
              f" required_sclk_mhz={args.required_sclk_mhz or '-'}"
              f" required_mclk_mhz={args.required_mclk_mhz or '-'}"
              f" max_below_mclk_floor_fraction={args.max_below_mclk_floor_fraction:.4f}"
              f" samples_at_mclk_floor={at_floor}"
              f" samples_below_mclk_floor={below_floor}"
              f" below_mclk_floor_fraction={mclk_fraction:.4f}"
              f" samples_above_required={above_required}"
              f" {freshness}")
        if not held:
            failures.append("clock_invariant")
    verdict = "accepted" if not failures else "refused"
    print(f"clock_sidecar={verdict} failures={','.join(failures) or '-'}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
