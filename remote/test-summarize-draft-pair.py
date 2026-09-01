#!/usr/bin/env python3
"""Exercise draft-pair aggregation and terminal measurement states."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("summarize-draft-pair.py")
ARMS = ("control-open", "pair-first", "pair-second", "control-close")
PROMPTS = ("first", "second")
PROMPT_TEXT = {"first": "first prompt", "second": "second prompt"}


class SummarizeDraftPairTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.output_directory = Path(self.temporary_directory.name)
        self.prompt_path = self.output_directory / "prompts.tsv"
        self.prompt_path.write_text(
            "first\tfirst prompt\nsecond\tsecond prompt\n", encoding="utf-8"
        )
        rates = {
            "control-open": (2.0, 4.0),
            "pair-first": (3.0, 6.0),
            "pair-second": (2.5, 5.0),
            "control-close": (2.0, 4.0),
        }
        for arm in ARMS:
            arm_directory = self.output_directory / arm
            arm_directory.mkdir()
            for prompt, rate in zip(PROMPTS, rates[arm], strict=True):
                timings: dict[str, int | float] = {
                    "predicted_n": 100,
                    "predicted_per_second": rate,
                }
                if arm.startswith("pair-"):
                    timings.update({"draft_n": 20, "draft_n_accepted": 18})
                (arm_directory / f"{prompt}.request.json").write_text(
                    json.dumps(
                        {
                            "prompt": PROMPT_TEXT[prompt],
                            "n_predict": 100,
                            "temperature": 0,
                            "top_k": 1,
                            "seed": 42,
                            "cache_prompt": False,
                            "stream": False,
                            "return_tokens": True,
                            "ignore_eos": True,
                        }
                    ),
                    encoding="utf-8",
                )
                (arm_directory / f"{prompt}.json").write_text(
                    json.dumps({"tokens": list(range(100)), "timings": timings}),
                    encoding="utf-8",
                )
                (arm_directory / f"{prompt}.listener.tsv").write_text(
                    "pid\tstarttime\tinode_before\tinode_after\tstate\n"
                    "123\t456\t789\t789\taccepted\n",
                    encoding="utf-8",
                )

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def run_summary(
        self, acceptance_floor: str = "0.896", draft_n_max: str = "2"
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            (
                sys.executable,
                str(SCRIPT),
                str(self.output_directory),
                draft_n_max,
                acceptance_floor,
                str(self.prompt_path),
                "100",
                "42",
            ),
            check=False,
            capture_output=True,
            text=True,
        )

    def summary(self) -> dict[str, str]:
        return dict(
            line.split("=", 1)
            for line in (self.output_directory / "summary.txt")
            .read_text(encoding="utf-8")
            .splitlines()
        )

    def update_timings(self, arm: str, prompt: str, **updates: object) -> None:
        response_path = self.output_directory / arm / f"{prompt}.json"
        payload = json.loads(response_path.read_text(encoding="utf-8"))
        payload["timings"].update(updates)
        response_path.write_text(json.dumps(payload), encoding="utf-8")

    def test_token_time_aggregation_and_abba_gates(self) -> None:
        result = self.run_summary()
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = self.summary()
        self.assertEqual(summary["control_open_decode_tok_s"], "2.667")
        self.assertEqual(summary["pair_first_decode_tok_s"], "4.000")
        self.assertEqual(summary["pair_second_decode_tok_s"], "3.333")
        self.assertEqual(summary["pair_first_over_control_open"], "1.5000")
        self.assertEqual(summary["pair_second_over_control_close"], "1.2500")
        self.assertEqual(summary["pair_acceptance_min"], "0.9000")
        self.assertEqual(summary["pair_tokens_per_target_step"], "1.222")
        self.assertEqual(summary["token_identity_gate"], "accepted")
        self.assertEqual(summary["admission_gate"], "accepted")
        self.assertEqual(
            len((self.output_directory / "arms.tsv").read_text().splitlines()), 9
        )

    def test_acceptance_floor_requests_shorter_retry(self) -> None:
        result = self.run_summary("0.950")
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = self.summary()
        self.assertEqual(summary["acceptance_gate"], "rejected")
        self.assertEqual(summary["admission_gate"], "retry-n-max-1")

    def test_minimum_acceptance_governs_weighted_acceptance(self) -> None:
        self.update_timings("pair-first", "first", draft_n=10, draft_n_accepted=8)
        for arm, prompt in (
            ("pair-first", "second"),
            ("pair-second", "first"),
            ("pair-second", "second"),
        ):
            self.update_timings(arm, prompt, draft_n_accepted=19)
        result = self.run_summary()
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = self.summary()
        self.assertEqual(summary["pair_acceptance_min"], "0.8000")
        self.assertEqual(summary["pair_acceptance_weighted"], "0.9286")
        self.assertEqual(summary["acceptance_gate"], "rejected")

    def test_adjacent_pair_controls_govern_an_overall_gain(self) -> None:
        for prompt in PROMPTS:
            self.update_timings("pair-first", prompt, predicted_per_second=20.0)
        self.update_timings("pair-second", "first", predicted_per_second=1.9)
        self.update_timings("pair-second", "second", predicted_per_second=3.9)
        result = self.run_summary()
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = self.summary()
        self.assertGreater(float(summary["pair_over_control"]), 1.0)
        self.assertLess(float(summary["pair_second_over_control_close"]), 1.0)
        self.assertEqual(summary["performance_gate"], "rejected")
        self.assertEqual(summary["admission_gate"], "retry-n-max-1")

    def test_failed_n_max_one_has_no_retry(self) -> None:
        result = self.run_summary("0.950", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.summary()["admission_gate"], "rejected")

    def test_token_divergence_rejects_admission(self) -> None:
        response_path = self.output_directory / "pair-second" / "first.json"
        payload = json.loads(response_path.read_text(encoding="utf-8"))
        payload["tokens"][0] = 101
        response_path.write_text(json.dumps(payload), encoding="utf-8")
        result = self.run_summary()
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = self.summary()
        self.assertEqual(summary["token_identity_gate"], "rejected")
        self.assertEqual(summary["admission_gate"], "retry-n-max-1")

    def test_nonprompt_request_mutation_is_terminal(self) -> None:
        request_path = self.output_directory / "pair-first" / "first.request.json"
        payload = json.loads(request_path.read_text(encoding="utf-8"))
        payload["temperature"] = 0.25
        request_path.write_text(json.dumps(payload), encoding="utf-8")
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "request_mismatch")

    def test_missing_request_field_is_terminal(self) -> None:
        request_path = self.output_directory / "pair-first" / "first.request.json"
        payload = json.loads(request_path.read_text(encoding="utf-8"))
        del payload["return_tokens"]
        request_path.write_text(json.dumps(payload), encoding="utf-8")
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "request_mismatch")

    def test_extra_request_field_is_terminal(self) -> None:
        request_path = self.output_directory / "pair-first" / "first.request.json"
        payload = json.loads(request_path.read_text(encoding="utf-8"))
        payload["stop"] = []
        request_path.write_text(json.dumps(payload), encoding="utf-8")
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "request_mismatch")

    def test_boolean_request_field_rejects_integer_alias(self) -> None:
        request_path = self.output_directory / "pair-first" / "first.request.json"
        payload = json.loads(request_path.read_text(encoding="utf-8"))
        payload["ignore_eos"] = 1
        request_path.write_text(json.dumps(payload), encoding="utf-8")
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "request_mismatch")

    def test_early_terminal_response_is_incomplete(self) -> None:
        response_path = self.output_directory / "pair-first" / "first.json"
        payload = json.loads(response_path.read_text(encoding="utf-8"))
        payload["tokens"] = payload["tokens"][:-1]
        payload["timings"]["predicted_n"] = 99
        response_path.write_text(json.dumps(payload), encoding="utf-8")
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "measurement_incomplete")

    def test_control_draft_counters_are_terminal(self) -> None:
        self.update_timings("control-open", "first", draft_n=1, draft_n_accepted=1)
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "control_draft_counters")

    def test_invalid_control_draft_counter_keys_are_terminal(self) -> None:
        for invalid_counter in (None, "1", -1, True, {}):
            with self.subTest(invalid_counter=invalid_counter):
                self.update_timings(
                    "control-open",
                    "first",
                    draft_n=invalid_counter,
                    draft_n_accepted=invalid_counter,
                )
                result = self.run_summary()
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.summary()["reason"], "control_draft_counters")

    def test_listener_identity_is_terminal(self) -> None:
        listener_path = self.output_directory / "pair-first" / "first.listener.tsv"
        listener_path.write_text(
            "pid\tstarttime\tinode_before\tinode_after\tstate\n"
            "123\t456\t789\t790\trejected\n",
            encoding="utf-8",
        )
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "listener_identity")

    def test_missing_response_is_terminal(self) -> None:
        (self.output_directory / "pair-first" / "first.json").unlink()
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "measurement_absent")

    def test_non_object_responses_are_terminal(self) -> None:
        response_path = self.output_directory / "pair-first" / "first.json"
        for payload in ([], "reply", 1, 1.5, True, None):
            with self.subTest(payload=payload):
                response_path.write_text(json.dumps(payload), encoding="utf-8")
                result = self.run_summary()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertNotIn("Traceback", result.stderr)
                self.assertEqual(self.summary()["reason"], "measurement_absent")

    def test_acceptance_floor_preserves_ledger_text(self) -> None:
        result = self.run_summary("0.9004")
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = self.summary()
        self.assertEqual(summary["acceptance_floor"], "0.9004")
        self.assertEqual(summary["pair_acceptance_min"], "0.9000")
        self.assertEqual(summary["acceptance_gate"], "rejected")

    def test_absent_draft_is_terminal(self) -> None:
        response_path = self.output_directory / "pair-first" / "first.json"
        response_path.write_text(
            json.dumps(
                {
                    "tokens": list(range(100)),
                    "timings": {
                        "predicted_n": 100,
                        "predicted_per_second": 3.0,
                    },
                }
            ),
            encoding="utf-8",
        )
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "draft_absent")

    def test_accepted_count_above_drafted_count_is_terminal(self) -> None:
        self.update_timings("pair-first", "first", draft_n=10, draft_n_accepted=11)
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "draft_geometry_invalid")

    def test_draft_count_above_batch_geometry_is_terminal(self) -> None:
        self.update_timings("pair-first", "first", draft_n=163, draft_n_accepted=18)
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "draft_geometry_invalid")

    def test_draft_count_at_batch_geometry_is_accepted(self) -> None:
        self.update_timings("pair-first", "first", draft_n=162, draft_n_accepted=18)
        result = self.run_summary()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.summary()["state"], "completed")

    def test_counters_that_leave_no_target_step_are_terminal(self) -> None:
        self.update_timings("pair-first", "first", draft_n=99, draft_n_accepted=99)
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "draft_geometry_invalid")

    def test_free_first_token_is_excluded_from_target_steps(self) -> None:
        result = self.run_summary()
        self.assertEqual(result.returncode, 0, result.stderr)
        pair_first_row = next(
            line.split("\t")
            for line in (self.output_directory / "arms.tsv")
            .read_text(encoding="utf-8")
            .splitlines()[1:]
            if line.startswith("pair-first\tpair\tfirst\t")
        )
        self.assertEqual(pair_first_row[8], "81")
        self.assertEqual(pair_first_row[9], "1.22")

    def test_request_prompt_must_match_retained_corpus(self) -> None:
        request_path = self.output_directory / "pair-first" / "first.request.json"
        request_path.write_text(
            json.dumps({"prompt": "a different prompt"}), encoding="utf-8"
        )
        result = self.run_summary()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.summary()["reason"], "prompt_mismatch")

    def test_invalid_acceptance_floor_is_usage_error(self) -> None:
        result = self.run_summary("1.001")
        self.assertEqual(result.returncode, 2)
        self.assertIn("ACCEPTANCE_FLOOR must be inside [0,1]", result.stderr)

    def test_duplicate_prompt_name_is_usage_error(self) -> None:
        self.prompt_path.write_text(
            "first\tfirst prompt\nfirst\tsecond prompt\n", encoding="utf-8"
        )
        result = self.run_summary()
        self.assertEqual(result.returncode, 2)
        self.assertIn("prompt file holds duplicate names", result.stderr)


if __name__ == "__main__":
    unittest.main()
