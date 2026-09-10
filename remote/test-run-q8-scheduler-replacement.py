#!/usr/bin/env python3
"""Exercise Q8 replacement wrapper identity, records, and stop semantics."""

from __future__ import annotations

import importlib.util
import os
import pathlib
import subprocess
import sys
import tempfile
import types
from collections.abc import Callable
from typing import Any, cast

SCRIPT_DIRECTORY = pathlib.Path(__file__).resolve().parent
WRAPPER_PATH = SCRIPT_DIRECTORY / "run-q8-scheduler-replacement.py"


def load_wrapper() -> types.ModuleType:
    """Load the hyphenated wrapper as a module for dependency injection."""
    specification = importlib.util.spec_from_file_location(
        "run_q8_scheduler_replacement_fixture", WRAPPER_PATH
    )
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


WRAPPER = load_wrapper()


def make_sources(root: pathlib.Path) -> Any:
    """Create four identity-bearing source fixtures."""
    paths = []
    for name in ("tuple.tsv", "runner.sh", "broker.c", "validator.py"):
        path = root / name
        path.write_text(f"fixture={name}\n", encoding="utf-8")
        paths.append(path)
    paths[1].chmod(0o755)
    return WRAPPER.SourcePaths(*paths)


def make_authorization(
    root: pathlib.Path, source_paths: Any, reference: str = "fixture-authorization"
) -> pathlib.Path:
    """Write an authorization through the production serializer."""
    path = root / "input-authorization.tsv"
    values = WRAPPER.authorization_values(reference, source_paths)
    WRAPPER.write_closed_tsv(path, values)
    return path


def require_refusal(operation: Callable[[], object], stage: str, reason: str) -> None:
    """Require one exact refusal classification."""
    try:
        operation()
    except WRAPPER.WrapperRefusal as refusal:
        assert refusal.stage == stage, (refusal.stage, stage)
        assert refusal.reason == reason, (refusal.reason, reason)
    else:
        raise AssertionError(f"expected {stage}/{reason} refusal")


def test_mixed_process_identity() -> None:
    """Reproduce the old parent PID under a child process's /proc/self."""
    parent_process_id = os.getpid()
    program = (
        "import pathlib,sys; "
        "pathlib.Path('/proc/self/task', sys.argv[1], 'schedstat').read_text()"
    )
    result = subprocess.run(
        [sys.executable, "-c", program, str(parent_process_id)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "FileNotFoundError" in result.stderr

    fields = WRAPPER.read_task_schedstat(
        pathlib.Path("/proc/self/task"), parent_process_id
    )
    assert len(fields) == 3
    assert all(value >= 0 for value in fields)
    print("mixed_process_procfs=reproduced same_reader=accepted")


def test_prerequisite_classification(root: pathlib.Path) -> None:
    """Keep absent, disabled, malformed, and task-record failures distinct."""
    enabled_path = root / "sched_schedstats"
    task_root = root / "task"
    process_task = task_root / str(os.getpid())
    process_task.mkdir(parents=True)
    schedstat_path = process_task / "schedstat"

    require_refusal(
        lambda: WRAPPER.inspect_scheduler_prerequisites(enabled_path, task_root),
        "scheduler_prerequisite",
        "sched_schedstats_absent",
    )
    enabled_path.write_text("0\n", encoding="ascii")
    require_refusal(
        lambda: WRAPPER.inspect_scheduler_prerequisites(enabled_path, task_root),
        "scheduler_prerequisite",
        "sched_schedstats_disabled",
    )
    enabled_path.write_text("enabled\n", encoding="ascii")
    require_refusal(
        lambda: WRAPPER.inspect_scheduler_prerequisites(enabled_path, task_root),
        "scheduler_prerequisite",
        "sched_schedstats_malformed",
    )
    enabled_path.write_text("1\n", encoding="ascii")
    require_refusal(
        lambda: WRAPPER.inspect_scheduler_prerequisites(enabled_path, task_root),
        "scheduler_prerequisite",
        "task_schedstat_absent",
    )
    schedstat_path.write_text("malformed\n", encoding="ascii")
    require_refusal(
        lambda: WRAPPER.inspect_scheduler_prerequisites(enabled_path, task_root),
        "scheduler_prerequisite",
        "task_schedstat_malformed",
    )
    schedstat_path.write_text("10 20 3\n", encoding="ascii")
    assert WRAPPER.inspect_scheduler_prerequisites(enabled_path, task_root) == (
        10,
        20,
        3,
    )
    print("scheduler_prerequisites=6_cases_passed")


def test_authorization_records(root: pathlib.Path, source_paths: Any) -> None:
    """Round-trip valid bytes and refuse literal escapes and duplicate fields."""
    authorization_path = make_authorization(root, source_paths)
    expected = WRAPPER.authorization_values("fixture-authorization", source_paths)
    observed = WRAPPER.read_closed_tsv(authorization_path, WRAPPER.AUTHORIZATION_FIELDS)
    WRAPPER.validate_authorization(observed)
    assert observed == expected
    original_bytes = authorization_path.read_bytes()
    require_refusal(
        lambda: WRAPPER.prepare_authorization_record(
            authorization_path, "replacement-refused", source_paths
        ),
        "authorization_record",
        "authorization output already exists",
    )
    assert authorization_path.read_bytes() == original_bytes

    literal_escape_path = root / "literal-escapes.tsv"
    literal_escape_path.write_text(
        "field\\tvalue\\nschema\\tqwen-q8-scheduler-replacement-authorization-v1\\n",
        encoding="utf-8",
    )
    require_refusal(
        lambda: WRAPPER.read_closed_tsv(
            literal_escape_path, WRAPPER.AUTHORIZATION_FIELDS
        ),
        "authorization_record",
        "the authorization record header is malformed",
    )

    duplicate_path = root / "duplicate.tsv"
    duplicate_text = authorization_path.read_text(encoding="utf-8")
    duplicate_path.write_text(
        duplicate_text + f"schema\t{WRAPPER.AUTHORIZATION_SCHEMA}\n",
        encoding="utf-8",
    )
    require_refusal(
        lambda: WRAPPER.read_closed_tsv(duplicate_path, WRAPPER.AUTHORIZATION_FIELDS),
        "authorization_record",
        "the authorization record repeats field: schema",
    )
    require_refusal(
        lambda: WRAPPER.write_closed_tsv(
            root / "control.tsv", {"field": "embedded\tvalue"}
        ),
        "authorization_record",
        "field contains an empty or control value",
    )
    print("authorization_tsv=round_trip_and_mutations_passed")


def terminal_record(record_directory: pathlib.Path) -> dict[str, str]:
    """Read a wrapper terminal record through the production consumer."""
    fields = (
        "schema",
        "authorization_reference",
        "state",
        "wrapper_stage",
        "scheduler_prerequisite_state",
        "telemetry_broker_state",
        "calibration_state",
        "runner_state",
        "runner_exit",
        "cleanup",
        "q8_candidate_timing",
        "detail",
    )
    return cast(
        dict[str, str],
        WRAPPER.read_closed_tsv(record_directory / "terminal-state.tsv", fields),
    )


def test_failure_before_calibration(root: pathlib.Path, source_paths: Any) -> None:
    """Retain a complete refusal while starting no calibration child."""
    runtime_root = root / "runtime-refusal"
    results_root = runtime_root / "results"
    results_root.mkdir(parents=True)
    os.environ["QWEN_HOME"] = str(runtime_root)
    authorization_path = make_authorization(root, source_paths, "refusal-reference")
    record_directory = results_root / "q8-refusal"
    enabled_path = root / "unchanged-sched_schedstats"
    enabled_path.write_text("0\n", encoding="ascii")
    settings_before = enabled_path.read_bytes()
    process_starts = 0

    def refuse_process_start(*_arguments: object, **_keywords: object) -> Any:
        nonlocal process_starts
        process_starts += 1
        raise AssertionError("calibration child started after prerequisite refusal")

    def refuse_prerequisite() -> tuple[int, int, int]:
        return cast(
            tuple[int, int, int],
            WRAPPER.inspect_scheduler_prerequisites(
                enabled_path, root / "unused-task-root"
            ),
        )

    status = WRAPPER.execute_wrapper(
        authorization_path,
        record_directory,
        source_paths,
        "fixture-model",
        1.0,
        prerequisite_reader=refuse_prerequisite,
        process_factory=refuse_process_start,
    )
    assert status == 2
    assert process_starts == 0
    assert enabled_path.read_bytes() == settings_before
    assert not (record_directory / "acquisition").exists()
    terminal = terminal_record(record_directory)
    assert terminal["state"] == "refused"
    assert terminal["scheduler_prerequisite_state"] == "sched_schedstats_disabled"
    assert terminal["telemetry_broker_state"] == "not_built_or_launched"
    assert terminal["calibration_state"] == "not_started"
    assert terminal["runner_state"] == "not_started"
    assert terminal["q8_candidate_timing"] == "withheld"
    canonical_authorization = WRAPPER.read_closed_tsv(
        record_directory / "authorization.tsv", WRAPPER.AUTHORIZATION_FIELDS
    )
    assert canonical_authorization["authorization_reference"] == "refusal-reference"

    protocol_runtime = root / "runtime-protocol-failure"
    protocol_results = protocol_runtime / "results"
    protocol_results.mkdir(parents=True)
    os.environ["QWEN_HOME"] = str(protocol_runtime)
    protocol_authorization = make_authorization(
        root, source_paths, "protocol-failure-reference"
    )
    protocol_record = protocol_results / "q8-protocol-failure"
    status = WRAPPER.execute_wrapper(
        protocol_authorization,
        protocol_record,
        source_paths,
        "fixture-model",
        1.0,
        prerequisite_reader=lambda: (_ for _ in ()).throw(
            FileNotFoundError("mixed /proc/self and parent process identity")
        ),
        process_factory=refuse_process_start,
    )
    assert status == 2
    assert process_starts == 0
    protocol_terminal = terminal_record(protocol_record)
    assert protocol_terminal["state"] == "failed"
    assert protocol_terminal["wrapper_stage"] == "prerequisite_probe"
    assert protocol_terminal["scheduler_prerequisite_state"] == "unknown"
    assert protocol_terminal["runner_state"] == "not_started"
    print("failure_before_calibration=terminal_complete child_starts=0")


class CompletedProcessFixture:
    """Provide the Popen surface used by one accepted integration fixture."""

    pid = 987654

    def wait(self, timeout: float | None = None) -> int:
        assert timeout is not None and timeout > 0
        return 0

    def poll(self) -> int:
        return 0


def test_accepted_integration(root: pathlib.Path, source_paths: Any) -> None:
    """Reach the registered runner boundary once without executing a device arm."""
    runtime_root = root / "runtime-accepted"
    results_root = runtime_root / "results"
    results_root.mkdir(parents=True)
    os.environ["QWEN_HOME"] = str(runtime_root)
    authorization_path = make_authorization(root, source_paths, "accepted-reference")
    record_directory = results_root / "q8-accepted"
    invocations: list[tuple[list[str], dict[str, str]]] = []

    def accept_process_start(
        command: list[str], **keywords: object
    ) -> CompletedProcessFixture:
        environment = keywords["env"]
        assert isinstance(environment, dict)
        invocations.append((command, environment))
        return CompletedProcessFixture()

    status = WRAPPER.execute_wrapper(
        authorization_path,
        record_directory,
        source_paths,
        "fixture-model",
        1.0,
        prerequisite_reader=lambda: (10, 20, 3),
        process_factory=accept_process_start,
    )
    assert status == 0
    assert len(invocations) == 1
    command, environment = invocations[0]
    assert command == [
        str(source_paths.runner),
        "fixture-model",
        str(record_directory / "acquisition"),
    ]
    assert environment["QWEN_CENSUS_MODE"] == "calibration"
    assert environment["QWEN_CENSUS_SAMPLER"] == "broker"
    assert environment["QWEN_CENSUS_SCHEDULER_ATTRIBUTION"] == "schedstat"
    assert environment["QWEN_CENSUS_SIDECAR_COST_NS"] == "1000000"
    assert environment["QWEN_CENSUS_SIDECAR_CPU"] == "0,1"
    terminal = terminal_record(record_directory)
    assert terminal["state"] == "completed"
    assert terminal["scheduler_prerequisite_state"] == "accepted"
    assert terminal["runner_state"] == "completed"
    assert terminal["q8_candidate_timing"] == "withheld"
    initial = WRAPPER.read_closed_tsv(
        record_directory / "initial-state.tsv",
        (
            "schema",
            "authorization_reference",
            "wrapper_source_sha256",
            "proposed_tuple_sha256",
            "runner_source_sha256",
            "broker_source_sha256",
            "validator_source_sha256",
            "record_directory_role",
            "acquisition_directory_role",
            "scheduler_prerequisite_state",
            "runner_state",
            "q8_candidate_timing",
        ),
    )
    assert initial["runner_state"] == "not_started"
    assert initial["acquisition_directory_role"] == "runner_output_child"
    print("accepted_integration=runner_boundary_reached_once")


def test_runner_timeout_cleanup(root: pathlib.Path, source_paths: Any) -> None:
    """Apply the deadline to one owned runner group and retain the timeout."""
    source_paths.runner.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        'printf \'%s\\n\' "$$" >"$QWEN_HOME/timeout-runner-pid"\n'
        "sleep 30\n",
        encoding="utf-8",
    )
    source_paths.runner.chmod(0o755)
    runtime_root = root / "runtime-timeout"
    results_root = runtime_root / "results"
    results_root.mkdir(parents=True)
    os.environ["QWEN_HOME"] = str(runtime_root)
    authorization_path = make_authorization(root, source_paths, "timeout-reference")
    record_directory = results_root / "q8-timeout"
    status = WRAPPER.execute_wrapper(
        authorization_path,
        record_directory,
        source_paths,
        "fixture-model",
        0.1,
        prerequisite_reader=lambda: (10, 20, 3),
    )
    assert status == 124
    runner_process_id = int(
        (runtime_root / "timeout-runner-pid").read_text(encoding="ascii")
    )
    assert not WRAPPER.process_group_lives(runner_process_id)
    terminal = terminal_record(record_directory)
    assert terminal["state"] == "failed"
    assert terminal["runner_exit"] == "124"
    assert terminal["cleanup"] in {"terminated", "killed"}
    print("runner_timeout=owned_group_stopped terminal_complete=yes")


def main() -> int:
    """Run all fixtures in one disposable workstation directory."""
    test_mixed_process_identity()
    with tempfile.TemporaryDirectory(prefix="q8-wrapper-fixture-") as temporary_name:
        root = pathlib.Path(temporary_name)
        source_paths = make_sources(root)
        test_prerequisite_classification(root)
        test_authorization_records(root, source_paths)
        test_failure_before_calibration(root, source_paths)
        test_accepted_integration(root, source_paths)
        test_runner_timeout_cleanup(root, source_paths)
    print("q8_scheduler_replacement_wrapper=accepted checks=6")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
