#!/usr/bin/env python3

"""Read the two elapsed records the appliance keeps, and state what they hold.

`stage-timing.sh` writes one row per launch-chain boundary into
`$QWEN_HOME/state/stage-timing.tsv`, and `measure-model-switch.sh` writes one
row per router model switch into its own TSV. This reader prints per-stage
durations and per-switch quantiles from either, and it asserts no continuity:
the stages nest -- `launch_readiness` contains `server_exec` and `model_load`,
which the launcher's own stamp brackets -- so a sum across them counts the same
wall clock several times and no total is printed. A switch series is likewise a
sequence of independent observations of one machine, so the quantiles describe
the samples taken and predict nothing about a switch not in the file.

A stage whose boundary never arrived carries `-` as its end, which is the
finding on exactly the launches worth explaining: a load terminated on the
memory reserve, a readiness loop that expired, a teardown whose wait ran out.
`--require-terminated` refuses such a record rather than reading `-` as zero.

Quantiles are nearest-rank over the sorted samples at the 1-based index
`ceil(p / 100 * n)` clamped into `[1, n]`, so every printed quantile is an
observed sample and no interpolation invents a value between two. The count
prints beside them, because p99 of twenty samples is the maximum and a bare
number would claim a resolution twenty samples do not carry.

usage: summarize-stage-timing.py stages STAGE_TSV [--require-terminated]
       summarize-stage-timing.py switches SWITCH_TSV
"""

from __future__ import annotations

import argparse
import math
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class StageRow:
    """One boundary pair. `end_ns` is None where the boundary never arrived."""

    name: str
    begin_ns: int
    end_ns: int | None


def read_stage_rows(path: Path) -> list[StageRow]:
    rows: list[StageRow] = []
    seen: set[str] = set()
    for number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 4 or fields[0] != "stage":
            raise ValueError(f"{path}:{number}: a stage row carries four fields")
        name, begin_text, end_text = fields[1], fields[2], fields[3]
        if name in seen:
            raise ValueError(f"{path}:{number}: {name} carries a second row")
        seen.add(name)
        begin_ns = int(begin_text)
        end_ns = None if end_text == "-" else int(end_text)
        if end_ns is not None and end_ns < begin_ns:
            raise ValueError(f"{path}:{number}: {name} ends before it begins")
        rows.append(StageRow(name=name, begin_ns=begin_ns, end_ns=end_ns))
    return rows


def format_seconds(nanoseconds: int | None) -> str:
    if nanoseconds is None:
        return "-"
    return f"{nanoseconds / 1_000_000_000:.3f}"


def nearest_rank(sorted_samples: list[int], percent: float) -> int:
    """The sample at 1-based index ceil(p/100 * n), clamped into [1, n]."""
    count = len(sorted_samples)
    index = math.ceil(percent / 100.0 * count)
    index = max(1, min(count, index))
    return sorted_samples[index - 1]


def summarize_stages(path: Path, require_terminated: bool) -> int:
    rows = read_stage_rows(path)
    if not rows:
        print(f"stage_timing=absent file={path}")
        return 1
    unterminated = [row.name for row in rows if row.end_ns is None]
    print(
        f"stage_timing stages={len(rows)} unterminated={len(unterminated)} "
        f"clock=realtime continuity=asserted-none file={path}"
    )
    for row in rows:
        elapsed = None if row.end_ns is None else row.end_ns - row.begin_ns
        print(
            f"stage name={row.name} elapsed_s={format_seconds(elapsed)} "
            f"begin_ns={row.begin_ns} "
            f"end_ns={'-' if row.end_ns is None else row.end_ns}"
        )
    if unterminated and require_terminated:
        print(
            "an unterminated stage names a boundary that never arrived, "
            f"which is not a duration: {' '.join(unterminated)}",
            file=sys.stderr,
        )
        return 1
    return 0


def read_switch_first_token(path: Path) -> list[int]:
    samples: list[int] = []
    for number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) < 4 or fields[0] != "switch":
            raise ValueError(f"{path}:{number}: a switch row carries four fields")
        if fields[3] == "-":
            continue
        samples.append(int(fields[3]))
    return samples


def summarize_switches(path: Path) -> int:
    samples = read_switch_first_token(path)
    if not samples:
        print(f"model_switch=absent file={path}")
        return 1
    ordered = sorted(samples)
    print(
        f"model_switch n={len(ordered)} method=nearest-rank "
        f"continuity=asserted-none file={path}"
    )
    for label, percent in (("p50", 50.0), ("p95", 95.0), ("p99", 99.0)):
        print(
            f"model_switch_quantile {label} "
            f"first_token_s={format_seconds(nearest_rank(ordered, percent))}"
        )
    print(
        f"model_switch_range min_s={format_seconds(ordered[0])} "
        f"max_s={format_seconds(ordered[-1])}"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(add_help=True)
    subparsers = parser.add_subparsers(dest="command", required=True)
    stages = subparsers.add_parser("stages")
    stages.add_argument("stage_tsv")
    stages.add_argument("--require-terminated", action="store_true")
    switches = subparsers.add_parser("switches")
    switches.add_argument("switch_tsv")
    arguments = parser.parse_args()

    try:
        if arguments.command == "stages":
            return summarize_stages(
                Path(arguments.stage_tsv), bool(arguments.require_terminated)
            )
        return summarize_switches(Path(arguments.switch_tsv))
    except (OSError, ValueError) as failure:
        print(f"summarize-stage-timing: {failure}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
