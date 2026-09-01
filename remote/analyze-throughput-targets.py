#!/usr/bin/env python3
"""Derive exact throughput-target bounds from a repository evidence ledger."""

from __future__ import annotations

import argparse
import csv
import difflib
import io
import os
import re
import sys
import tempfile
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_EVEN, localcontext
from fractions import Fraction
from pathlib import Path


INPUT_FIELDS = (
    "analysis_id",
    "model_id",
    "baseline_surface",
    "baseline_decode_tok_s",
    "target_decode_tok_s",
    "target_evidence",
    "streamed_bytes_per_token",
    "amdahl_speedups",
    "n1_surface",
    "n1_target_pass_ms",
    "n1_draft_pass_ms",
    "baseline_evidence",
    "streamed_bytes_evidence",
    "n1_evidence",
)
OUTPUT_FIELDS = (
    "analysis_id",
    "model_id",
    "metric",
    "parameter",
    "exact_numerator",
    "exact_denominator",
    "decimal",
    "unit",
    "state",
    "baseline_surface",
    "baseline_evidence",
    "target_evidence",
    "streamed_bytes_evidence",
    "n1_evidence",
)
SAFE_IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+-]*\Z")
DECIMAL_PLACES = Decimal("0.000000000001")


class TargetAnalysisError(ValueError):
    """Report a malformed target ledger without a traceback."""


@dataclass(frozen=True)
class TargetInput:
    analysis_id: str
    model_id: str
    baseline_surface: str
    baseline_decode_tok_s: Fraction
    target_decode_tok_s: Fraction
    target_evidence: str
    streamed_bytes_per_token: int
    amdahl_speedups: tuple[tuple[str, Fraction | None], ...]
    n1_surface: str | None
    n1_target_pass_ms: Fraction | None
    n1_draft_pass_ms: Fraction | None
    baseline_evidence: str
    streamed_bytes_evidence: str
    n1_evidence: str | None


@dataclass(frozen=True)
class Metric:
    name: str
    parameter: str
    value: Fraction
    unit: str
    state: str = "derived"


def fail(message: str) -> None:
    raise TargetAnalysisError(message)


def parse_identifier(value: str, field: str, row_number: int) -> str:
    if not SAFE_IDENTIFIER.fullmatch(value):
        fail(f"row {row_number} has invalid {field}: {value!r}")
    return value


def parse_positive_fraction(value: str, field: str, row_number: int) -> Fraction:
    if value != value.strip() or not value:
        fail(f"row {row_number} has invalid {field}: {value!r}")
    try:
        parsed = Fraction(value)
    except (ValueError, ZeroDivisionError) as error:
        raise TargetAnalysisError(
            f"row {row_number} has invalid {field}: {value!r}"
        ) from error
    if parsed <= 0:
        fail(f"row {row_number} requires positive {field}: {value!r}")
    return parsed


def parse_positive_integer(value: str, field: str, row_number: int) -> int:
    if not value.isascii() or not value.isdigit() or value.startswith("0"):
        fail(f"row {row_number} has invalid {field}: {value!r}")
    parsed = int(value)
    if parsed <= 0:
        fail(f"row {row_number} requires positive {field}: {value!r}")
    return parsed


def validate_evidence_path(
    value: str, field: str, row_number: int, repository_root: Path
) -> str:
    relative_path = Path(value)
    if (
        value != value.strip()
        or not value
        or relative_path.is_absolute()
        or value == "."
        or any(part in ("", ".", "..") for part in relative_path.parts)
    ):
        fail(f"row {row_number} has unsafe {field}: {value!r}")

    candidate = repository_root
    for part in relative_path.parts:
        candidate /= part
        if candidate.is_symlink():
            fail(f"row {row_number} names {field} through a symlink: {value}")
    if not candidate.is_file():
        fail(f"row {row_number} names absent {field}: {value}")
    try:
        candidate.resolve(strict=True).relative_to(repository_root)
    except ValueError as error:
        raise TargetAnalysisError(
            f"row {row_number} names {field} outside the repository: {value}"
        ) from error
    return value


def parse_speedups(
    value: str, row_number: int
) -> tuple[tuple[str, Fraction | None], ...]:
    tokens = value.split(",")
    if not tokens or any(not token or token != token.strip() for token in tokens):
        fail(f"row {row_number} has invalid amdahl_speedups: {value!r}")

    parsed: list[tuple[str, Fraction | None]] = []
    seen: set[Fraction | None] = set()
    for token in tokens:
        if token == "unbounded":
            speedup = None
            normalized = token
        else:
            speedup = parse_positive_fraction(token, "amdahl speedup", row_number)
            if speedup <= 1:
                fail(f"row {row_number} requires amdahl speedup above one: {token}")
            normalized = (
                str(speedup.numerator)
                if speedup.denominator == 1
                else f"{speedup.numerator}/{speedup.denominator}"
            )
        if speedup in seen:
            fail(f"row {row_number} repeats amdahl speedup: {token}")
        seen.add(speedup)
        parsed.append((normalized, speedup))
    return tuple(parsed)


def load_targets(input_path: Path, repository_root: Path) -> tuple[TargetInput, ...]:
    try:
        input_text = input_path.read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        raise TargetAnalysisError(
            f"target ledger is not UTF-8: {input_path}"
        ) from error
    reader = csv.DictReader(io.StringIO(input_text), delimiter="\t")
    if tuple(reader.fieldnames or ()) != INPUT_FIELDS:
        fail(f"target ledger header differs from the required schema: {input_path}")

    targets: list[TargetInput] = []
    seen_ids: set[str] = set()
    for row_number, row in enumerate(reader, start=2):
        if None in row or any(value is None for value in row.values()):
            fail(f"row {row_number} has the wrong field count: {input_path}")
        analysis_id = parse_identifier(row["analysis_id"], "analysis_id", row_number)
        if analysis_id in seen_ids:
            fail(f"row {row_number} repeats analysis_id: {analysis_id}")
        seen_ids.add(analysis_id)
        model_id = parse_identifier(row["model_id"], "model_id", row_number)
        baseline_surface = parse_identifier(
            row["baseline_surface"], "baseline_surface", row_number
        )
        baseline_rate = parse_positive_fraction(
            row["baseline_decode_tok_s"], "baseline_decode_tok_s", row_number
        )
        target_rate = parse_positive_fraction(
            row["target_decode_tok_s"], "target_decode_tok_s", row_number
        )
        if target_rate <= baseline_rate:
            fail(
                f"row {row_number} target must exceed its planning baseline: "
                f"{target_rate} <= {baseline_rate}"
            )
        target_evidence = validate_evidence_path(
            row["target_evidence"], "target_evidence", row_number, repository_root
        )
        streamed_bytes = parse_positive_integer(
            row["streamed_bytes_per_token"], "streamed_bytes_per_token", row_number
        )
        speedups = parse_speedups(row["amdahl_speedups"], row_number)
        baseline_evidence = validate_evidence_path(
            row["baseline_evidence"], "baseline_evidence", row_number, repository_root
        )
        streamed_bytes_evidence = validate_evidence_path(
            row["streamed_bytes_evidence"],
            "streamed_bytes_evidence",
            row_number,
            repository_root,
        )

        n1_values = (
            row["n1_surface"],
            row["n1_target_pass_ms"],
            row["n1_draft_pass_ms"],
            row["n1_evidence"],
        )
        if all(value == "-" for value in n1_values):
            n1_surface = None
            n1_target_pass_ms = None
            n1_draft_pass_ms = None
            n1_evidence = None
        elif any(value == "-" for value in n1_values):
            fail(f"row {row_number} has an incomplete N=1 evidence group")
        else:
            n1_surface = parse_identifier(row["n1_surface"], "n1_surface", row_number)
            n1_target_pass_ms = parse_positive_fraction(
                row["n1_target_pass_ms"], "n1_target_pass_ms", row_number
            )
            n1_draft_pass_ms = parse_positive_fraction(
                row["n1_draft_pass_ms"], "n1_draft_pass_ms", row_number
            )
            n1_evidence = validate_evidence_path(
                row["n1_evidence"], "n1_evidence", row_number, repository_root
            )

        targets.append(
            TargetInput(
                analysis_id=analysis_id,
                model_id=model_id,
                baseline_surface=baseline_surface,
                baseline_decode_tok_s=baseline_rate,
                target_decode_tok_s=target_rate,
                target_evidence=target_evidence,
                streamed_bytes_per_token=streamed_bytes,
                amdahl_speedups=speedups,
                n1_surface=n1_surface,
                n1_target_pass_ms=n1_target_pass_ms,
                n1_draft_pass_ms=n1_draft_pass_ms,
                baseline_evidence=baseline_evidence,
                streamed_bytes_evidence=streamed_bytes_evidence,
                n1_evidence=n1_evidence,
            )
        )
    if not targets:
        fail(f"target ledger holds no rows: {input_path}")
    return tuple(targets)


def amdahl_ownership(required_fraction: Fraction, speedup: Fraction | None) -> Fraction:
    if speedup is None:
        return required_fraction
    return required_fraction / (1 - 1 / speedup)


def derive_core_metrics(
    target: TargetInput, required_fraction: Fraction
) -> tuple[Metric, ...]:
    baseline_rate = target.baseline_decode_tok_s
    target_rate = target.target_decode_tok_s
    baseline_latency_ms = Fraction(1000) / baseline_rate
    target_latency_ms = Fraction(1000) / target_rate
    streamed_bytes = Fraction(target.streamed_bytes_per_token)
    return (
        Metric("baseline_latency_ms", "-", baseline_latency_ms, "ms/token"),
        Metric("target_latency_ms", "-", target_latency_ms, "ms/token"),
        Metric(
            "required_latency_removal_ms",
            "-",
            baseline_latency_ms - target_latency_ms,
            "ms/token",
        ),
        Metric("required_speedup", "-", target_rate / baseline_rate, "ratio"),
        Metric("required_time_fraction", "-", required_fraction, "fraction"),
        Metric(
            "declared_baseline_logical_gb_s",
            "-",
            streamed_bytes * baseline_rate / 1_000_000_000,
            "GB/s",
        ),
        Metric(
            "target_logical_gb_s",
            "-",
            streamed_bytes * target_rate / 1_000_000_000,
            "GB/s",
        ),
    )


def derive_amdahl_metrics(
    target: TargetInput, required_fraction: Fraction, metric_name: str
) -> tuple[Metric, ...]:
    metrics: list[Metric] = []
    for speedup_name, speedup in target.amdahl_speedups:
        ownership = amdahl_ownership(required_fraction, speedup)
        state = "feasible" if ownership <= 1 else "insufficient-mechanism-speedup"
        metrics.append(
            Metric(
                metric_name,
                speedup_name,
                ownership,
                "fraction",
                state,
            )
        )
    return tuple(metrics)


def derive_n1_metrics(target: TargetInput) -> tuple[Metric, ...]:
    if target.n1_target_pass_ms is None or target.n1_draft_pass_ms is None:
        return ()

    target_pass_ms = target.n1_target_pass_ms
    draft_pass_ms = target.n1_draft_pass_ms
    two_token_budget_ms = Fraction(2000) / target.target_decode_tok_s
    retained_draft_bound_ms = two_token_budget_ms - draft_pass_ms
    free_draft_removal_ms = target_pass_ms - two_token_budget_ms
    retained_draft_removal_ms = target_pass_ms - retained_draft_bound_ms
    retained_draft_fraction = retained_draft_removal_ms / target_pass_ms
    perfect_acceptance_rate = Fraction(2000) / (target_pass_ms + draft_pass_ms)
    required_acceptance = (
        target.target_decode_tok_s * (target_pass_ms + draft_pass_ms) / 1000 - 1
    )
    feasible = perfect_acceptance_rate >= target.target_decode_tok_s
    feasibility_state = "feasible" if feasible else "impossible-current-costs"
    retained_bound_state = (
        "required" if retained_draft_bound_ms > 0 else "impossible-draft-budget"
    )
    removal_state = "required" if free_draft_removal_ms > 0 else "already-within-bound"
    acceptance_state = (
        "feasible" if Fraction(0) <= required_acceptance <= 1 else feasibility_state
    )
    n1_surface = target.n1_surface or "-"
    metrics = (
        Metric(
            "n1_current_perfect_acceptance_tok_s",
            n1_surface,
            perfect_acceptance_rate,
            "tok/s",
            feasibility_state,
        ),
        Metric(
            "n1_current_free_draft_tok_s",
            n1_surface,
            Fraction(2000) / target_pass_ms,
            "tok/s",
            "derived",
        ),
        Metric("n1_two_token_budget_ms", n1_surface, two_token_budget_ms, "ms"),
        Metric(
            "n1_free_draft_target_pass_bound_ms",
            n1_surface,
            two_token_budget_ms,
            "ms",
        ),
        Metric(
            "n1_free_draft_required_removal_ms",
            n1_surface,
            free_draft_removal_ms,
            "ms",
            removal_state,
        ),
        Metric(
            "n1_free_draft_required_removal_fraction",
            n1_surface,
            free_draft_removal_ms / target_pass_ms,
            "fraction",
            removal_state,
        ),
        Metric(
            "n1_retained_draft_target_pass_bound_ms",
            n1_surface,
            retained_draft_bound_ms,
            "ms",
            retained_bound_state,
        ),
        Metric(
            "n1_retained_draft_required_removal_ms",
            n1_surface,
            retained_draft_removal_ms,
            "ms",
            retained_bound_state,
        ),
        Metric(
            "n1_retained_draft_required_removal_fraction",
            n1_surface,
            retained_draft_fraction,
            "fraction",
            retained_bound_state,
        ),
        Metric(
            "n1_required_acceptance_at_current_costs",
            n1_surface,
            required_acceptance,
            "fraction",
            acceptance_state,
        ),
        Metric(
            "n1_current_cost_feasible",
            n1_surface,
            Fraction(int(feasible)),
            "boolean",
            feasibility_state,
        ),
    )
    return metrics + derive_amdahl_metrics(
        target,
        retained_draft_fraction,
        "n1_target_pass_amdahl_minimum_ownership",
    )


def derive_metrics(target: TargetInput) -> tuple[Metric, ...]:
    required_fraction = 1 - target.baseline_decode_tok_s / target.target_decode_tok_s
    return (
        derive_core_metrics(target, required_fraction)
        + derive_amdahl_metrics(target, required_fraction, "amdahl_minimum_ownership")
        + derive_n1_metrics(target)
    )


def format_decimal(value: Fraction) -> str:
    with localcontext() as context:
        context.prec = max(80, len(str(abs(value.numerator))) + 30)
        decimal_value = Decimal(value.numerator) / Decimal(value.denominator)
        return format(
            decimal_value.quantize(DECIMAL_PLACES, rounding=ROUND_HALF_EVEN), "f"
        )


def render_results(targets: tuple[TargetInput, ...]) -> str:
    output = io.StringIO(newline="")
    writer = csv.writer(output, delimiter="\t", lineterminator="\n")
    writer.writerow(OUTPUT_FIELDS)
    for target in targets:
        for metric in derive_metrics(target):
            writer.writerow(
                (
                    target.analysis_id,
                    target.model_id,
                    metric.name,
                    metric.parameter,
                    metric.value.numerator,
                    metric.value.denominator,
                    format_decimal(metric.value),
                    metric.unit,
                    metric.state,
                    target.baseline_surface,
                    target.baseline_evidence,
                    target.target_evidence,
                    target.streamed_bytes_evidence,
                    target.n1_evidence or "-",
                )
            )
    return output.getvalue()


def repository_path(
    supplied_path: Path,
    repository_root: Path,
    field: str,
    *,
    require_file: bool,
) -> Path:
    if ".." in supplied_path.parts:
        fail(f"{field} contains a parent traversal: {supplied_path}")
    candidate = (
        supplied_path
        if supplied_path.is_absolute()
        else repository_root / supplied_path
    )
    try:
        relative_path = candidate.relative_to(repository_root)
    except ValueError as error:
        raise TargetAnalysisError(
            f"{field} is outside the repository: {supplied_path}"
        ) from error
    if not relative_path.parts:
        fail(f"{field} names the repository root: {supplied_path}")

    candidate = repository_root
    for part in relative_path.parts:
        candidate /= part
        if candidate.is_symlink():
            fail(f"{field} traverses a symlink: {supplied_path}")
    if require_file and not candidate.is_file():
        fail(f"{field} is absent or is not a regular file: {supplied_path}")
    return candidate


def validate_output_path(output_path: Path, repository_root: Path) -> Path:
    candidate = repository_path(
        output_path,
        repository_root,
        "output path",
        require_file=False,
    )
    if candidate.exists() and not candidate.is_file():
        fail(f"output path is not a regular file: {output_path}")
    candidate.parent.mkdir(parents=True, exist_ok=True)
    return candidate


def write_atomic(output_path: Path, content: str) -> None:
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="",
            dir=output_path.parent,
            prefix=f".{output_path.name}.",
            delete=False,
        ) as temporary_file:
            temporary_file.write(content)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
            temporary_path = Path(temporary_file.name)
        os.replace(temporary_path, output_path)
        temporary_path = None
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def parse_args(argv: list[str]) -> argparse.Namespace:
    repository_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repository-root", type=Path, default=repository_root, help=argparse.SUPPRESS
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=repository_root / "remote" / "throughput-targets.tsv",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=repository_root
        / "evidence"
        / "throughput-target-analysis"
        / "results.tsv",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="compare generated bytes with the existing output",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    arguments = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        repository_root = arguments.repository_root.resolve(strict=True)
        input_path = repository_path(
            arguments.input,
            repository_root,
            "input path",
            require_file=True,
        )
        targets = load_targets(input_path, repository_root)
        rendered = render_results(targets)
        if arguments.check:
            output_path = repository_path(
                arguments.output,
                repository_root,
                "output path",
                require_file=False,
            )
            try:
                current = output_path.read_text(encoding="utf-8")
            except FileNotFoundError:
                print(f"throughput_target_analysis=missing output={output_path}")
                return 1
            if current != rendered:
                sys.stderr.writelines(
                    difflib.unified_diff(
                        current.splitlines(keepends=True),
                        rendered.splitlines(keepends=True),
                        fromfile=str(output_path),
                        tofile="generated",
                    )
                )
                print(f"throughput_target_analysis=stale output={output_path}")
                return 1
            print(
                "throughput_target_analysis=current "
                f"analyses={len(targets)} metrics={sum(len(derive_metrics(target)) for target in targets)}"
            )
            return 0
        output_path = validate_output_path(arguments.output, repository_root)
        write_atomic(output_path, rendered)
        print(
            "throughput_target_analysis=written "
            f"analyses={len(targets)} metrics={sum(len(derive_metrics(target)) for target in targets)} "
            f"output={output_path}"
        )
        return 0
    except (OSError, TargetAnalysisError) as error:
        print(f"throughput_target_analysis=rejected detail={error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
