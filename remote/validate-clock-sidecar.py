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

usage: validate-clock-sidecar.py RECORD_TSV --sidecar-status N
       --period-ms F --period-tolerance F --cost-bound-ns N
       [--max-gap-ns N] [--max-lost-fraction F]
       [--window-begin-ns N --window-end-ns N]
       [--allow-unavailable COLUMN ...]
"""
import argparse
import sys

COLUMNS = (
    "monotonic_ns",
    "pp_dpm_sclk_selected_mhz",
    "pp_dpm_mclk_surface_mhz",
    "pp_dpm_fclk_surface_mhz",
    "gpu_busy_percent",
    "temp1_millidegrees",
    "sample_cost_ns",
)
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
    two states at equal counts resolve to the same one on every run.
    """
    if not values:
        return None, None
    counts = {}
    for value in values:
        counts[value] = counts.get(value, 0) + 1
    mode = sorted(counts, key=lambda value: (-counts[value], value))[0]
    return mode, counts[mode] / len(values)


def parse_key_values(text):
    values = {}
    for token in text.split():
        key, separator, value = token.partition("=")
        if not separator:
            continue
        values[key] = value
    return values


def read_record(path):
    header_lines = []
    footer_lines = []
    column_line = None
    rows = []
    with open(path) as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if line.startswith("# samples="):
                footer_lines.append(line)
            elif line.startswith("#"):
                header_lines.append(line)
            elif column_line is None:
                column_line = line
            elif line:
                rows.append(line.split("\t"))
    return header_lines, column_line, rows, footer_lines


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
    parser.add_argument("--max-lost-fraction", type=float, default=0.02)
    parser.add_argument("--window-begin-ns", type=int)
    parser.add_argument("--window-end-ns", type=int)
    parser.add_argument("--allow-unavailable", action="append", default=[])
    args = parser.parse_args()

    failures = []

    def check(name, passed, detail):
        print(f"{name}={'accepted' if passed else 'refused'} {detail}")
        if not passed:
            failures.append(name)

    check("sidecar_exit", args.sidecar_status == 0, f"status={args.sidecar_status}")
    try:
        header_lines, column_line, rows, footer_lines = read_record(args.record)
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
    check("columns", column_line == "\t".join(COLUMNS), f"columns={column_line or '-'}")
    check("footer_cardinality", len(footer_lines) == 1, f"footers={len(footer_lines)}")
    footer = parse_key_values(footer_lines[0].lstrip("# ")) if len(footer_lines) == 1 else {}
    footer_complete = all(key in footer and footer[key].lstrip("-").isdigit() for key in FOOTER_KEYS)
    check("footer_fields", footer_complete, f"present={','.join(sorted(footer))}")
    if not footer_complete:
        print("clock_sidecar=refused")
        return 1
    samples = int(footer["samples"])
    check("samples", samples > 1 and samples == len(rows), f"samples={samples} rows={len(rows)}")
    row_arity = all(len(row) == len(COLUMNS) for row in rows)
    check("row_arity", row_arity, f"columns={len(COLUMNS)}")
    achieved = int(footer["achieved_period_ns"])
    lower = requested_period_ns * (1.0 - args.period_tolerance)
    upper = requested_period_ns * (1.0 + args.period_tolerance)
    check("achieved_period", lower <= achieved <= upper,
          f"achieved_ns={achieved} requested_ns={requested_period_ns} tolerance={args.period_tolerance}")
    mean_cost = int(footer["mean_sample_cost_ns"])
    check("sample_cost", mean_cost <= args.cost_bound_ns,
          f"mean_ns={mean_cost} max_ns={footer['max_sample_cost_ns']} bound_ns={args.cost_bound_ns}")
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
        windowed = args.window_begin_ns is not None and args.window_end_ns is not None
        if windowed:
            check("window_coverage", first <= args.window_begin_ns and last >= args.window_end_ns,
                  f"first={first} begin={args.window_begin_ns} end={args.window_end_ns} last={last}")
        else:
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
    if rows and row_arity and window_defined:
        window_rows = [row for row in rows
                       if args.window_begin_ns <= int(row[0]) <= args.window_end_ns]
        sclk_mode, sclk_share = modal_value(
            [row[1] for row in window_rows if row[1] != "unavailable"])
        mclk_mode, _ = modal_value(
            [row[2] for row in window_rows if row[2] != "unavailable"])
        temperatures = [int(row[5]) / 1000.0 for row in window_rows
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
    verdict = "accepted" if not failures else "refused"
    print(f"clock_sidecar={verdict} failures={','.join(failures) or '-'}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
