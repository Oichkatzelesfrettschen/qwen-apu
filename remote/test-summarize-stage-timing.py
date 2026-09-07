#!/usr/bin/env python3

"""The summarizer's arithmetic and its refusals, over records written here.

Nearest-rank quantiles are exact integers over an integer sample set, so every
assertion here compares integers and no tolerance is required. The refusals are
the other half: an unterminated stage is a boundary that never arrived rather
than a zero-length one, and a duplicate stage row makes a reader that takes the
first row disagree with one that takes the last.
"""

from __future__ import annotations

import importlib.util
import io
import sys
import tempfile
from contextlib import redirect_stdout
from pathlib import Path
from types import ModuleType

MODULE_PATH = Path(__file__).resolve().parent / "summarize-stage-timing.py"


def load_module() -> ModuleType:
    specification = importlib.util.spec_from_file_location(
        "summarize_stage_timing", MODULE_PATH
    )
    assert specification is not None
    assert specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    # A dataclass resolves its own module through sys.modules, so the entry
    # precedes execution rather than following it.
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


summarizer = load_module()


def check(condition: bool, detail: str) -> None:
    if not condition:
        raise SystemExit(f"test-summarize-stage-timing: {detail}")


def test_nearest_rank() -> None:
    samples = list(range(1, 21))
    # ceil(0.50 * 20) = 10, ceil(0.95 * 20) = 19, ceil(0.99 * 20) = 20.
    check(summarizer.nearest_rank(samples, 50.0) == 10, "p50 of 1..20 is 10")
    check(summarizer.nearest_rank(samples, 95.0) == 19, "p95 of 1..20 is 19")
    check(summarizer.nearest_rank(samples, 99.0) == 20, "p99 of 1..20 is 20")
    # Every quantile of one sample is that sample, and the clamp holds at both
    # ends rather than indexing outside the list.
    check(summarizer.nearest_rank([7], 0.0) == 7, "p0 of one sample is it")
    check(summarizer.nearest_rank([7], 100.0) == 7, "p100 of one sample is it")
    # Three samples: ceil(0.50 * 3) = 2, ceil(0.95 * 3) = 3.
    check(summarizer.nearest_rank([5, 9, 30], 50.0) == 9, "p50 of three is the middle")
    check(summarizer.nearest_rank([5, 9, 30], 95.0) == 30, "p95 of three is the last")
    # The rank is taken over the sorted samples, so input order changes nothing.
    check(
        summarizer.nearest_rank(sorted([30, 5, 9]), 50.0) == 9,
        "the rank reads sorted samples",
    )


def test_format_seconds() -> None:
    check(summarizer.format_seconds(None) == "-", "an absent duration is -")
    check(summarizer.format_seconds(0) == "0.000", "zero prints as 0.000")
    check(
        summarizer.format_seconds(1_500_000_000) == "1.500",
        "1.5 s prints at millisecond resolution",
    )


def write(path: Path, text: str) -> Path:
    path.write_text(text, encoding="utf-8")
    return path


def test_stage_reader(directory: Path) -> None:
    header = (
        "# stage_timing clock=monotonic source=time.monotonic_ns "
        "boot_id=0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0 "
        "opened_utc=2026-09-07T12:00:00Z record=20260907T120000Z-pid7\n"
    )
    complete = write(
        directory / "complete.tsv",
        header + "stage\tserver_exec\t100\t400\nstage\tmodel_load\t400\t2000000400\n",
    )
    check(
        summarizer.read_header_field(complete, "clock") == "monotonic",
        "the header names the clock the durations came from",
    )
    check(
        summarizer.read_header_field(complete, "boot_id")
        == "0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0",
        "the header names the boot the monotonic origin belongs to",
    )
    check(
        summarizer.read_header_field(complete, "absent") == "-",
        "a field the header omits reads -",
    )
    rows = summarizer.read_stage_rows(complete)
    check(len(rows) == 2, "two rows read")
    check(rows[0].end_ns == 400, "the first row keeps its end")
    captured = io.StringIO()
    with redirect_stdout(captured):
        status = summarizer.summarize_stages(complete, True)
    check(status == 0, "a terminated record is accepted")
    output = captured.getvalue()
    check("elapsed_s=0.000" in output, "300 ns rounds to 0.000 s")
    check("elapsed_s=2.000" in output, "2 s prints at millisecond resolution")
    check("clock=monotonic" in output, "the report names the clock")
    check("boot_id=0f1e2d3c" in output, "the report names the boot identity")
    check("opened_utc=2026-09-07T12:00:00Z" in output, "the report carries chronology")
    check("continuity=asserted-none" in output, "the report asserts no continuity")
    check(
        "\naccounted" not in output and "total" not in output,
        "nesting stages get no total",
    )

    unterminated = write(
        directory / "unterminated.tsv",
        "stage\tserver_exec\t100\t400\nstage\tmodel_load\t400\t-\n",
    )
    captured = io.StringIO()
    with redirect_stdout(captured):
        status = summarizer.summarize_stages(unterminated, False)
    check(status == 0, "an unterminated record reports without --require-terminated")
    check("end_ns=-" in captured.getvalue(), "the unterminated end stays -")
    captured = io.StringIO()
    with redirect_stdout(captured):
        status = summarizer.summarize_stages(unterminated, True)
    check(status == 1, "--require-terminated refuses an unterminated stage")

    duplicate = write(
        directory / "duplicate.tsv",
        "stage\tmodel_load\t1\t2\nstage\tmodel_load\t3\t4\n",
    )
    try:
        summarizer.read_stage_rows(duplicate)
    except ValueError as failure:
        check("second row" in str(failure), "the duplicate names itself")
    else:
        raise SystemExit("a duplicate stage row was accepted")

    reversed_row = write(directory / "reversed.tsv", "stage\tmodel_load\t9\t4\n")
    try:
        summarizer.read_stage_rows(reversed_row)
    except ValueError as failure:
        check("ends before it begins" in str(failure), "the reversal names itself")
    else:
        raise SystemExit("a stage ending before it begins was accepted")

    short = write(directory / "short.tsv", "stage\tmodel_load\t9\n")
    try:
        summarizer.read_stage_rows(short)
    except ValueError as failure:
        check("four fields" in str(failure), "the short row names itself")
    else:
        raise SystemExit("a three-field stage row was accepted")

    empty = write(directory / "empty.tsv", "# stage_timing clock=monotonic\n")
    captured = io.StringIO()
    with redirect_stdout(captured):
        status = summarizer.summarize_stages(empty, False)
    check(status == 1, "a record carrying no stage refuses")


def test_switch_reader(directory: Path) -> None:
    rows = ["# model_switch clock=curl-elapsed log_clock=absent"]
    for index in range(1, 21):
        rows.append(f"switch\t{index}\tmodel-a\t{index}\t2\tslice-{index}.log")
    switches = write(directory / "switch.tsv", "\n".join(rows) + "\n")
    samples = summarizer.read_switch_first_token(switches)
    check(samples == list(range(1, 21)), "every switch row contributes one sample")
    captured = io.StringIO()
    with redirect_stdout(captured):
        status = summarizer.summarize_switches(switches)
    check(status == 0, "a switch series summarizes")
    output = captured.getvalue()
    check("n=20" in output, "the count prints beside the quantiles")
    check("p50 first_token_s=0.000" in output, "p50 is sample 10, 10 ns")
    check("method=nearest-rank" in output, "the method is named")
    check("max_s=0.000" in output, "the range prints")

    # A failed request records `-` and contributes no sample rather than a zero.
    failed = write(
        directory / "switch-failed.tsv",
        "switch\t1\tmodel-a\t-\t0\tslice-1.log\n"
        "switch\t2\tmodel-b\t5000000000\t3\tslice-2.log\n",
    )
    check(
        summarizer.read_switch_first_token(failed) == [5_000_000_000],
        "a refused request contributes no sample",
    )
    captured = io.StringIO()
    with redirect_stdout(captured):
        status = summarizer.summarize_switches(failed)
    check(status == 0, "one sample still summarizes")
    check("n=1" in captured.getvalue(), "the count states one sample")

    none_measured = write(directory / "switch-none.tsv", "switch\t1\ta\t-\t0\ts.log\n")
    captured = io.StringIO()
    with redirect_stdout(captured):
        status = summarizer.summarize_switches(none_measured)
    check(status == 1, "a series with no measured switch refuses")


def main() -> int:
    with tempfile.TemporaryDirectory() as name:
        directory = Path(name)
        test_nearest_rank()
        test_format_seconds()
        test_stage_reader(directory)
        test_switch_reader(directory)
    print("test-summarize-stage-timing: accepted", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
