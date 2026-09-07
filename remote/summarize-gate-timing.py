#!/usr/bin/env python3
"""Read where a repository gate run spent its time, from its own log.

`gate-cell-key.sh` emits one `cell=timing` line per cell and one `gate_timing`
line per run, so this reader recomputes every total from the per-cell lines and
compares them against the ones the run reported. A disagreement is the finding:
it means the run's own accounting and its log describe different work, and the
report says so rather than picking one.

Three phases separate here. `key_ns` derives a cell's read set and hashes it
into a key, which every cell pays whether or not it then runs. `run_ns` is the
cell's own command. `avoided_ns` is what a reused cell cost when it last ran,
read from the record it reused, so the saving is a measurement from that run
rather than a prediction about this one -- a record written before the field
existed reads `-` and is counted as unrecorded rather than as zero.

The clock is CLOCK_REALTIME through `date +%s%N`, at three boundaries per cell.
Each boundary is about two milliseconds of fork, which bounds what a `key_ns`
of a few milliseconds can be read to mean: the phase separates hashing from
execution, and does not resolve hashing to the microsecond.

usage: summarize-gate-timing.py GATE_LOG [--slowest N] [--tsv OUT.tsv]
"""

import argparse
import sys


def parse_fields(line):
    fields = {}
    for token in line.split():
        name, separator, value = token.partition("=")
        if separator:
            fields[name] = value
    return fields


def read_nanoseconds(value):
    """A field states a duration or states that it has none; `-` is not zero."""
    if value is None or value == "-":
        return None
    try:
        parsed = int(value)
    except ValueError:
        return None
    return parsed if parsed >= 0 else None


def format_seconds(nanoseconds):
    if nanoseconds is None:
        return "-"
    return f"{nanoseconds / 1_000_000_000:.3f}"


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("gate_log")
    parser.add_argument("--slowest", type=int, default=10)
    parser.add_argument("--tsv")
    arguments = parser.parse_args()

    cells = []
    reported = None
    with open(arguments.gate_log, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line.startswith("cell=timing "):
                fields = parse_fields(line)
                cells.append(
                    {
                        "name": fields.get("name", "-"),
                        "key": fields.get("key", "-"),
                        "decision": fields.get("decision", "-"),
                        "key_ns": read_nanoseconds(fields.get("key_ns")),
                        "run_ns": read_nanoseconds(fields.get("run_ns")),
                        "avoided_ns": read_nanoseconds(fields.get("avoided_ns")),
                    }
                )
            elif line.startswith("gate_timing "):
                reported = parse_fields(line)

    if not cells:
        print(f"gate_timing_summary=absent log={arguments.gate_log}")
        return 1

    recomputed = {
        "key_ns": sum(c["key_ns"] or 0 for c in cells),
        "run_ns": sum(c["run_ns"] or 0 for c in cells),
        "avoided_ns": sum(c["avoided_ns"] or 0 for c in cells),
    }
    unrecorded = sum(
        1 for c in cells if c["decision"] == "reused" and c["avoided_ns"] is None
    )

    run_cells = [c for c in cells if c["decision"] == "run"]
    reused_cells = [c for c in cells if c["decision"] == "reused"]
    rejected_cells = [c for c in cells if c["decision"] == "rejected"]

    wall = recomputed["key_ns"] + recomputed["run_ns"]
    key_share = (recomputed["key_ns"] / wall) if wall else 0.0

    print(
        f"gate_timing_summary cells={len(cells)} run={len(run_cells)} "
        f"reused={len(reused_cells)} rejected={len(rejected_cells)}"
    )
    print(
        f"phase key_s={format_seconds(recomputed['key_ns'])} "
        f"run_s={format_seconds(recomputed['run_ns'])} "
        f"accounted_s={format_seconds(wall)} key_share={key_share:.4f}"
    )
    print(
        f"reuse avoided_s={format_seconds(recomputed['avoided_ns'])} "
        f"reused_cells={len(reused_cells)} unrecorded_cells={unrecorded}"
    )

    if reported is not None:
        agreement = "accepted"
        for field in ("key_ns", "run_ns", "avoided_ns"):
            if read_nanoseconds(reported.get(field)) != recomputed[field]:
                agreement = "disagreed"
        print(
            f"reported_totals agreement={agreement} "
            f"key_ns={reported.get('key_ns', '-')} "
            f"run_ns={reported.get('run_ns', '-')} "
            f"avoided_ns={reported.get('avoided_ns', '-')} "
            f"clock={reported.get('clock', '-')}"
        )
        if agreement == "disagreed":
            print(
                "the run's own totals and its per-cell lines describe "
                "different work",
                file=sys.stderr,
            )
    else:
        print("reported_totals agreement=absent")

    ranked = sorted(run_cells, key=lambda c: c["run_ns"] or 0, reverse=True)
    for index, cell in enumerate(ranked[: arguments.slowest], start=1):
        run_seconds = format_seconds(cell["run_ns"])
        share = (cell["run_ns"] or 0) / recomputed["run_ns"] if recomputed["run_ns"] else 0.0
        print(
            f"slowest {index:2d} run_s={run_seconds:>9} share={share:.4f} "
            f"key_s={format_seconds(cell['key_ns'])} name={cell['name']}"
        )

    if arguments.tsv:
        with open(arguments.tsv, "w", encoding="utf-8") as handle:
            handle.write("name\tdecision\tkey_ns\trun_ns\tavoided_ns\tkey\n")
            for cell in cells:
                handle.write(
                    "\t".join(
                        (
                            cell["name"],
                            cell["decision"],
                            "-" if cell["key_ns"] is None else str(cell["key_ns"]),
                            "-" if cell["run_ns"] is None else str(cell["run_ns"]),
                            "-"
                            if cell["avoided_ns"] is None
                            else str(cell["avoided_ns"]),
                            cell["key"],
                        )
                    )
                    + "\n"
                )
        print(f"gate_timing_rows={len(cells)} tsv={arguments.tsv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
