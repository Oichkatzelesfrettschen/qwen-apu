#!/usr/bin/env python3
"""Exercise exact throughput-target arithmetic and artifact safety."""

from __future__ import annotations

import csv
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import unittest
from fractions import Fraction
from pathlib import Path
from types import ModuleType
from unittest import mock


SCRIPT = Path(__file__).with_name("analyze-throughput-targets.py")


def load_analyzer() -> ModuleType:
    specification = importlib.util.spec_from_file_location(
        "analyze_throughput_targets", SCRIPT
    )
    if specification is None or specification.loader is None:
        raise RuntimeError(f"analyzer is unreadable: {SCRIPT}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


ANALYZER = load_analyzer()


class ThroughputTargetAnalysisTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.repository_root = Path(self.temporary_directory.name) / "repository"
        self.remote_directory = self.repository_root / "remote"
        self.evidence_directory = self.repository_root / "evidence"
        self.remote_directory.mkdir(parents=True)
        self.evidence_directory.mkdir()
        for evidence_name in ("baseline.md", "streamed.txt", "n1.md", "target.md"):
            (self.evidence_directory / evidence_name).write_text(
                f"fixture={evidence_name}\n", encoding="utf-8"
            )
        self.input_path = self.remote_directory / "targets.tsv"
        self.output_path = self.evidence_directory / "analysis" / "results.tsv"

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    @staticmethod
    def target_row(**updates: str) -> dict[str, str]:
        row = {
            "analysis_id": "qwen38-4b-bandwidth",
            "model_id": "qwen38-4b-distill",
            "baseline_surface": "bandwidth-four-block-reported-mean",
            "baseline_decode_tok_s": "3.01",
            "target_decode_tok_s": "5.25",
            "target_evidence": "evidence/target.md",
            "streamed_bytes_per_token": "2697836544",
            "amdahl_speedups": "2,4,31/19,unbounded",
            "n1_surface": "mtp-n1-reported-pass-costs",
            "n1_target_pass_ms": "463.1",
            "n1_draft_pass_ms": "66.4",
            "baseline_evidence": "evidence/baseline.md",
            "streamed_bytes_evidence": "evidence/streamed.txt",
            "n1_evidence": "evidence/n1.md",
        }
        row.update(updates)
        return row

    def write_ledger(
        self,
        rows: tuple[dict[str, str], ...] | None = None,
        fields: tuple[str, ...] | None = None,
    ) -> None:
        output = io.StringIO(newline="")
        writer = csv.DictWriter(
            output,
            fieldnames=fields or ANALYZER.INPUT_FIELDS,
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        selected_rows = (self.target_row(),) if rows is None else rows
        for row in selected_rows:
            writer.writerow(row)
        self.input_path.write_text(output.getvalue(), encoding="utf-8")

    def run_analyzer(
        self,
        *,
        input_path: Path | str = "remote/targets.tsv",
        output_path: Path | str = "evidence/analysis/results.tsv",
        check: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        command = [
            sys.executable,
            str(SCRIPT),
            "--repository-root",
            str(self.repository_root),
            "--input",
            str(input_path),
            "--output",
            str(output_path),
        ]
        if check:
            command.append("--check")
        return subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            env=os.environ | {"PYTHONDONTWRITEBYTECODE": "1"},
        )

    def metrics_for(self, row: dict[str, str]) -> dict[tuple[str, str], object]:
        self.write_ledger((row,))
        targets = ANALYZER.load_targets(self.input_path, self.repository_root)
        return {
            (metric.name, metric.parameter): metric
            for metric in ANALYZER.derive_metrics(targets[0])
        }

    def test_golden_target_fractions_are_exact(self) -> None:
        qwen08_metrics = self.metrics_for(
            self.target_row(
                analysis_id="qwen35-08b-registry",
                model_id="qwen35-08b",
                baseline_surface="universal-sweep-reported-mean",
                baseline_decode_tok_s="18.53",
                target_decode_tok_s="20",
                streamed_bytes_per_token="800881920",
                amdahl_speedups="2,4,unbounded",
                n1_surface="-",
                n1_target_pass_ms="-",
                n1_draft_pass_ms="-",
                n1_evidence="-",
            )
        )
        self.assertEqual(
            qwen08_metrics[("baseline_latency_ms", "-")].value,
            Fraction(100000, 1853),
        )
        self.assertEqual(
            qwen08_metrics[("required_latency_removal_ms", "-")].value,
            Fraction(7350, 1853),
        )
        self.assertEqual(
            qwen08_metrics[("required_speedup", "-")].value,
            Fraction(2000, 1853),
        )
        self.assertEqual(
            qwen08_metrics[("required_time_fraction", "-")].value,
            Fraction(147, 2000),
        )
        self.assertEqual(
            qwen08_metrics[("amdahl_minimum_ownership", "2")].value,
            Fraction(147, 1000),
        )
        self.assertEqual(
            qwen08_metrics[("amdahl_minimum_ownership", "4")].value,
            Fraction(49, 500),
        )
        self.assertEqual(
            qwen08_metrics[("target_logical_gb_s", "-")].value,
            Fraction(800881920 * 20, 1_000_000_000),
        )

        qwen4_metrics = self.metrics_for(self.target_row())
        self.assertEqual(
            qwen4_metrics[("required_time_fraction", "-")].value,
            Fraction(224, 525),
        )
        self.assertEqual(
            qwen4_metrics[
                ("n1_current_perfect_acceptance_tok_s", "mtp-n1-reported-pass-costs")
            ].value,
            Fraction(4000, 1059),
        )
        self.assertEqual(
            qwen4_metrics[
                ("n1_retained_draft_target_pass_bound_ms", "mtp-n1-reported-pass-costs")
            ].value,
            Fraction(33028, 105),
        )
        self.assertEqual(
            qwen4_metrics[
                ("n1_retained_draft_required_removal_ms", "mtp-n1-reported-pass-costs")
            ].value,
            Fraction(6239, 42),
        )
        self.assertEqual(
            qwen4_metrics[
                (
                    "n1_retained_draft_required_removal_fraction",
                    "mtp-n1-reported-pass-costs",
                )
            ].value,
            Fraction(31195, 97251),
        )
        self.assertEqual(
            qwen4_metrics[
                (
                    "n1_required_acceptance_at_current_costs",
                    "mtp-n1-reported-pass-costs",
                )
            ].value,
            Fraction(14239, 8000),
        )
        expected_ownership = Fraction(31195, 97251) / (1 - Fraction(19, 31))
        self.assertEqual(
            qwen4_metrics[("n1_target_pass_amdahl_minimum_ownership", "31/19")].value,
            expected_ownership,
        )
        self.assertEqual(ANALYZER.format_decimal(expected_ownership), "0.828650433757")

    def test_malformed_ledgers_are_rejected(self) -> None:
        malformed_cases = (
            self.target_row(baseline_decode_tok_s=" 3.01"),
            self.target_row(streamed_bytes_per_token="0"),
            self.target_row(amdahl_speedups="1,unbounded"),
            self.target_row(target_decode_tok_s="3.01"),
        )
        for row in malformed_cases:
            with self.subTest(row=row):
                self.write_ledger((row,))
                result = self.run_analyzer()
                self.assertEqual(result.returncode, 2, result)
                self.assertIn("throughput_target_analysis=rejected", result.stderr)

        self.write_ledger(rows=(), fields=ANALYZER.INPUT_FIELDS[:-1])
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 2, result)
        self.assertIn("header differs", result.stderr)

    def test_duplicate_analysis_identifier_is_rejected(self) -> None:
        self.write_ledger((self.target_row(), self.target_row()))
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 2, result)
        self.assertIn("repeats analysis_id", result.stderr)

    def test_target_evidence_is_retained_in_generated_rows(self) -> None:
        self.write_ledger()
        targets = ANALYZER.load_targets(self.input_path, self.repository_root)
        generated_rows = tuple(
            csv.DictReader(
                io.StringIO(ANALYZER.render_results(targets)), delimiter="\t"
            )
        )
        self.assertGreater(len(generated_rows), 0)
        self.assertEqual(
            {row["target_evidence"] for row in generated_rows},
            {"evidence/target.md"},
        )

    def test_incomplete_n1_group_is_rejected(self) -> None:
        self.write_ledger((self.target_row(n1_draft_pass_ms="-"),))
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 2, result)
        self.assertIn("incomplete N=1 evidence group", result.stderr)

    def test_input_and_evidence_paths_stay_inside_repository(self) -> None:
        self.write_ledger()
        outside_input = self.repository_root.parent / "outside.tsv"
        outside_input.write_text(
            self.input_path.read_text(encoding="utf-8"), encoding="utf-8"
        )
        result = self.run_analyzer(input_path=outside_input)
        self.assertEqual(result.returncode, 2, result)
        self.assertIn("input path is outside the repository", result.stderr)

        outside_evidence = self.repository_root.parent / "outside-evidence.md"
        outside_evidence.write_text("outside\n", encoding="utf-8")
        evidence_link = self.evidence_directory / "linked.md"
        evidence_link.symlink_to(outside_evidence)
        self.write_ledger((self.target_row(baseline_evidence="evidence/linked.md"),))
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 2, result)
        self.assertIn("through a symlink", result.stderr)

    def test_rejected_output_path_creates_nothing_outside_repository(self) -> None:
        self.write_ledger()
        outside_directory = self.repository_root.parent / "outside-output" / "nested"
        result = self.run_analyzer(output_path=outside_directory / "results.tsv")
        self.assertEqual(result.returncode, 2, result)
        self.assertIn("output path is outside the repository", result.stderr)
        self.assertFalse(outside_directory.exists())

    def test_output_symlink_is_rejected_without_writing_target(self) -> None:
        self.write_ledger()
        outside_directory = self.repository_root.parent / "symlink-output"
        outside_directory.mkdir()
        linked_directory = self.evidence_directory / "linked-output"
        linked_directory.symlink_to(outside_directory, target_is_directory=True)
        result = self.run_analyzer(output_path="evidence/linked-output/results.tsv")
        self.assertEqual(result.returncode, 2, result)
        self.assertIn("output path traverses a symlink", result.stderr)
        self.assertFalse((outside_directory / "results.tsv").exists())

    def test_stale_output_is_reported_without_rewrite(self) -> None:
        self.write_ledger()
        generated = self.run_analyzer()
        self.assertEqual(generated.returncode, 0, generated)
        self.output_path.write_text("stale\n", encoding="utf-8")
        result = self.run_analyzer(check=True)
        self.assertEqual(result.returncode, 1, result)
        self.assertIn("throughput_target_analysis=stale", result.stdout)
        self.assertIn("-stale", result.stderr)
        self.assertEqual(self.output_path.read_text(encoding="utf-8"), "stale\n")

    def test_impossible_draft_budget_remains_explicit(self) -> None:
        metrics = self.metrics_for(
            self.target_row(
                baseline_decode_tok_s="1",
                target_decode_tok_s="20",
                n1_target_pass_ms="100",
                n1_draft_pass_ms="120",
                amdahl_speedups="2,unbounded",
            )
        )
        surface = "mtp-n1-reported-pass-costs"
        self.assertEqual(
            metrics[("n1_retained_draft_target_pass_bound_ms", surface)].value,
            Fraction(-20),
        )
        self.assertEqual(
            metrics[("n1_retained_draft_target_pass_bound_ms", surface)].state,
            "impossible-draft-budget",
        )
        self.assertEqual(
            metrics[("n1_retained_draft_required_removal_fraction", surface)].value,
            Fraction(6, 5),
        )
        self.assertEqual(
            metrics[("n1_target_pass_amdahl_minimum_ownership", "unbounded")].state,
            "insufficient-mechanism-speedup",
        )

    def test_failed_atomic_replace_preserves_existing_output(self) -> None:
        output_path = self.evidence_directory / "atomic.tsv"
        output_path.write_text("retained\n", encoding="utf-8")
        with mock.patch.object(
            ANALYZER.os, "replace", side_effect=OSError("injected replace failure")
        ):
            with self.assertRaisesRegex(OSError, "injected replace failure"):
                ANALYZER.write_atomic(output_path, "replacement\n")
        self.assertEqual(output_path.read_text(encoding="utf-8"), "retained\n")
        self.assertEqual(tuple(self.evidence_directory.glob(".atomic.tsv.*")), ())


if __name__ == "__main__":
    unittest.main()
