#!/usr/bin/env python3
"""Focused process-lifecycle tests for readiness-driver.py."""

from __future__ import annotations

import fcntl
import importlib.util
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from typing import Any, NoReturn, cast
from unittest import mock

SCRIPT = Path(__file__).with_name("readiness-driver.py")
SPECIFICATION = importlib.util.spec_from_file_location("readiness_driver", SCRIPT)
assert SPECIFICATION is not None and SPECIFICATION.loader is not None
readiness_driver = importlib.util.module_from_spec(SPECIFICATION)
sys.modules[SPECIFICATION.name] = readiness_driver
SPECIFICATION.loader.exec_module(readiness_driver)


class ReadinessDriverTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.result_directory = self.home / "results" / "probe"
        self.result_directory.mkdir(parents=True, mode=0o700)

    def run_probe(
        self,
        source: str,
        *,
        timeout_ms: int = 500,
        cleanup_timeout_ms: int = 500,
        runtime: Any = None,
    ) -> tuple[int, dict[str, Any]]:
        return cast(
            tuple[int, dict[str, Any]],
            readiness_driver.run_probe(
                self.result_directory,
                timeout_ms,
                cleanup_timeout_ms,
                runtime=runtime,
                command=[sys.executable, "-c", source],
            ),
        )

    def test_success_publishes_typed_record_and_private_artifacts(self) -> None:
        status, record = self.run_probe("print('launch_readiness=accepted scope=test')")
        self.assertEqual(status, 0)
        self.assertEqual(record["outcome"], "accepted")
        self.assertEqual(record["service_verification"], "not_observed")
        self.assertEqual(record["restoration"], "not_applicable")
        self.assertIsInstance(record["started_monotonic_ns"], int)
        self.assertEqual(self.result_directory.stat().st_mode & 0o777, 0o700)
        self.assertEqual(
            (self.result_directory / "stdout.log").stat().st_mode & 0o777, 0o600
        )
        parsed = json.loads((self.result_directory / "terminal.json").read_text())
        self.assertEqual(parsed, record)

    def test_result_directory_uses_qwen_home_results_authority(self) -> None:
        results_root = self.home / "declared-results"
        with mock.patch.object(
            readiness_driver.qwen_home, "path", return_value=results_root
        ) as path:
            result_directory = readiness_driver.create_result_directory(None)
        path.assert_called_once_with("results")
        self.assertEqual(result_directory.parent, results_root)
        self.assertEqual(result_directory.stat().st_mode & 0o777, 0o700)

    def test_start_failure_is_distinct(self) -> None:
        def missing_popen(*_args: Any, **_kwargs: Any) -> NoReturn:
            raise FileNotFoundError(2, "missing")

        runtime = readiness_driver.Runtime(popen=missing_popen)
        status, record = readiness_driver.run_probe(
            self.result_directory, 100, 100, runtime=runtime, command=["missing"]
        )
        self.assertEqual(status, 1)
        self.assertEqual(record["primary"]["state"], "start_failure")
        self.assertEqual(record["primary"]["start_error"]["errno"], 2)

    def test_timeout_is_distinct_and_cleans_owned_session(self) -> None:
        status, record = self.run_probe(
            "import signal; signal.pause()", timeout_ms=30, cleanup_timeout_ms=300
        )
        self.assertEqual(status, 1)
        self.assertEqual(record["primary"]["state"], "timed_out")
        self.assertEqual(record["cleanup"]["state"], "completed")
        self.assertIn("SIGTERM", record["cleanup"]["signals"])

    def test_wait_sleep_is_capped_to_remaining_deadline(self) -> None:
        sleeps: list[float] = []
        runtime = readiness_driver.Runtime(
            clock_ns=lambda: 9_999_500,
            sleep=sleeps.append,
        )
        readiness_driver.sleep_with_deadline(runtime, 10_000_000)
        self.assertEqual(sleeps, [0.0000005])

    def test_owned_unreadable_process_refuses_cleanup_proof(self) -> None:
        census = {
            "live": [],
            "zombie": [41],
            "unreadable_owned": [42],
            "unreadable_unknown": [],
        }
        sent_signals = []
        runtime = readiness_driver.Runtime(
            census=lambda _session_id: census,
            killpg=lambda process_id, signal_number: sent_signals.append(
                (process_id, signal_number)
            ),
        )
        cleanup, _status = readiness_driver.cleanup_session(
            runtime, 41, object(), time.monotonic_ns() + 100_000_000
        )
        self.assertEqual(cleanup["state"], "census_incomplete")
        self.assertEqual(sent_signals, [(41, signal.SIGTERM)])
        census["unreadable_owned"] = []
        census["unreadable_unknown"] = [900]
        cleanup, _status = readiness_driver.cleanup_session(
            runtime, 41, object(), time.monotonic_ns() + 100_000_000
        )
        self.assertEqual(cleanup["state"], "census_incomplete")

    def test_unknown_unreadable_process_at_deadline_refuses_cleanup_proof(self) -> None:
        census = {
            "live": [],
            "zombie": [41],
            "unreadable_owned": [],
            "unreadable_unknown": [900],
        }
        runtime = readiness_driver.Runtime(
            clock_ns=lambda: 100,
            census=lambda _session_id: census,
        )
        cleanup, _status = readiness_driver.cleanup_session(runtime, 41, object(), 100)
        self.assertEqual(cleanup["state"], "census_incomplete")

    def test_same_uid_unreadable_proc_entry_is_recorded(self) -> None:
        with (
            mock.patch.object(
                readiness_driver.Path,
                "iterdir",
                return_value=iter([Path("/proc/42")]),
            ),
            mock.patch.object(
                readiness_driver,
                "read_process_session",
                side_effect=PermissionError("hidden"),
            ),
            mock.patch.object(
                readiness_driver, "process_owner_uid", return_value=os.getuid()
            ),
        ):
            census = readiness_driver.session_census(41)
        self.assertEqual(census["unreadable_owned"], [42])

    def test_post_spawn_wait_failure_still_cleans_owned_session(self) -> None:
        failed = False

        def fail_once(_duration: float) -> None:
            nonlocal failed
            if not failed:
                failed = True
                raise RuntimeError("injected wait failure")
            time.sleep(0)

        status, record = self.run_probe(
            "import signal; signal.pause()",
            runtime=readiness_driver.Runtime(sleep=fail_once),
            cleanup_timeout_ms=300,
        )
        self.assertEqual(status, 1)
        self.assertEqual(record["primary"]["state"], "internal_failure")
        self.assertEqual(record["primary"]["execution_error"]["operation"], "run_wait")
        self.assertEqual(record["cleanup"]["state"], "completed")
        self.assertIn("SIGTERM", record["cleanup"]["signals"])

    def test_sigterm_during_spawn_is_cancellation(self) -> None:
        def cancelling_popen(*args: Any, **kwargs: Any) -> subprocess.Popen[bytes]:
            os.kill(os.getpid(), signal.SIGTERM)
            return subprocess.Popen(*args, **kwargs)

        status, record = self.run_probe(
            "import signal; signal.pause()",
            runtime=readiness_driver.Runtime(popen=cancelling_popen),
        )
        self.assertEqual(status, 1)
        self.assertEqual(record["primary"]["state"], "cancelled")
        self.assertEqual(record["primary"]["cancellation_count"], 1)

    def test_repeated_cancellation_is_idempotent(self) -> None:
        def cancelling_popen(*args: Any, **kwargs: Any) -> subprocess.Popen[bytes]:
            os.kill(os.getpid(), signal.SIGTERM)
            os.kill(os.getpid(), signal.SIGTERM)
            return subprocess.Popen(*args, **kwargs)

        status, record = self.run_probe(
            "import signal; signal.pause()",
            runtime=readiness_driver.Runtime(popen=cancelling_popen),
        )
        self.assertEqual(status, 1)
        self.assertEqual(record["primary"]["state"], "cancelled")
        self.assertEqual(record["primary"]["cancellation_count"], 2)
        self.assertEqual(record["cleanup"]["signals"].count("SIGTERM"), 1)

    def test_exited_leader_descendant_holding_logs_is_cleaned(self) -> None:
        source = (
            "import os,signal,sys;pid=os.fork();"
            "\nif pid == 0:"
            "\n signal.signal(signal.SIGTERM,signal.SIG_IGN);signal.pause();os._exit(0)"
            "\nprint('launch_readiness=accepted scope=test');sys.stdout.flush()"
        )
        status, record = self.run_probe(source, cleanup_timeout_ms=300)
        self.assertEqual(status, 0)
        self.assertTrue(record["cleanup"]["leader_reserved"])
        self.assertIn("SIGKILL", record["cleanup"]["signals"])
        self.assertEqual(record["cleanup"]["residuals"]["live"], [])

    def test_exited_leader_descendant_holding_lock_is_cleaned(self) -> None:
        lock_path = self.home / "held.lock"
        source = (
            "import fcntl,os,signal,sys;"
            f"lock=open({str(lock_path)!r},'w');"
            "read_fd,write_fd=os.pipe();pid=os.fork();"
            "\nif pid == 0:"
            "\n os.close(read_fd);fcntl.flock(lock,fcntl.LOCK_EX);"
            "os.write(write_fd,b'1');signal.pause();os._exit(0)"
            "\nos.close(write_fd);os.read(read_fd,1);"
            "print('launch_readiness=accepted scope=test');sys.stdout.flush()"
        )
        status, record = self.run_probe(source, cleanup_timeout_ms=300)
        self.assertEqual(status, 0)
        with lock_path.open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.assertEqual(record["cleanup"]["residuals"]["live"], [])

    def test_unknown_and_malformed_replies_are_refused(self) -> None:
        status, record = self.run_probe("print('something_else=accepted')")
        self.assertEqual(status, 1)
        self.assertEqual(record["primary"]["readiness_reply"], "malformed")
        other_directory = self.home / "results" / "second"
        other_directory.mkdir(mode=0o700)
        status, record = readiness_driver.run_probe(
            other_directory,
            500,
            500,
            command=[
                sys.executable,
                "-c",
                "print('launch_readiness=refused failures=1')",
            ],
        )
        self.assertEqual(status, 1)
        self.assertEqual(record["primary"]["readiness_reply"], "unknown")

    def test_final_publication_failure_preserves_incomplete_record(self) -> None:
        calls = 0

        def fail_final(target: Path, record: dict[str, Any]) -> None:
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("injected final publication failure")
            readiness_driver.atomic_write_json(target, record)

        runtime = readiness_driver.Runtime(publish=fail_final)
        with self.assertRaisesRegex(OSError, "injected final publication failure"):
            self.run_probe(
                "print('launch_readiness=accepted scope=test')", runtime=runtime
            )
        retained = json.loads((self.result_directory / "terminal.json").read_text())
        self.assertEqual(retained["record_state"], "incomplete")

    def test_json_rejects_non_finite_numbers(self) -> None:
        with self.assertRaises(ValueError):
            readiness_driver.atomic_write_json(
                self.result_directory / "nan.json", {"value": float("nan")}
            )


if __name__ == "__main__":
    unittest.main()
