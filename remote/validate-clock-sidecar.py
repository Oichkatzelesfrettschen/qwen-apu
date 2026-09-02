#!/usr/bin/env python3
"""Decide whether one clock sidecar record is evidence.

sample-clock-sidecar.py writes a header, one row per sample, and one footer.
A record is evidence for an arm only where the sampler exited cleanly, held
its period, cost what it claims, read every sensor on every sample, and
covered the request window on both sides; a record failing any of those is
a file that exists rather than a measurement, and the runner treats the arm
as failed. Every condition prints as a `key=value` line, the last line reads
`clock_sidecar=accepted` or `clock_sidecar=refused`, and the exit status
follows it.

usage: validate-clock-sidecar.py RECORD_TSV --sidecar-status N
       --period-ms F --period-tolerance F --cost-bound-ns N
       [--window-begin-ns N --window-end-ns N]
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
    parser.add_argument("--window-begin-ns", type=int)
    parser.add_argument("--window-end-ns", type=int)
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
    check("sensors", unavailable == 0, f"samples_with_unavailable_sensor={unavailable}")
    if rows and row_arity:
        unavailable_rows = sum(1 for row in rows if "unavailable" in row[1:6])
        check("sensor_rows", unavailable_rows == unavailable,
              f"rows_with_unavailable={unavailable_rows} footer={unavailable}")
        first = int(rows[0][0])
        last = int(rows[-1][0])
        check("footer_instants", first == int(footer["first_sample_ns"]) and last == int(footer["last_sample_ns"]),
              f"first={first} last={last}")
        if args.window_begin_ns is not None and args.window_end_ns is not None:
            check("window_coverage", first <= args.window_begin_ns and last >= args.window_end_ns,
                  f"first={first} begin={args.window_begin_ns} end={args.window_end_ns} last={last}")
        else:
            print("window_coverage=not_run no window supplied")
    verdict = "accepted" if not failures else "refused"
    print(f"clock_sidecar={verdict} failures={','.join(failures) or '-'}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
