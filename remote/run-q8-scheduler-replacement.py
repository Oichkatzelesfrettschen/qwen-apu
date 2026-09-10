#!/usr/bin/env python3
"""Prepare or execute one scheduler-attributed Q8 replacement calibration."""

from __future__ import annotations

import argparse
import csv
import hashlib
import math
import os
import pathlib
import signal
import subprocess
import sys
import tempfile
import time
import unicodedata
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass

import qwen_home

AUTHORIZATION_SCHEMA = "qwen-q8-scheduler-replacement-authorization-v1"
AUTHORIZATION_OPERATION = "scheduler-attributed-replacement-calibration"
AUTHORIZATION_FIELDS = (
    "schema",
    "authorization_reference",
    "operation",
    "wrapper_source_sha256",
    "proposed_tuple_sha256",
    "runner_source_sha256",
    "broker_source_sha256",
    "validator_source_sha256",
)
SHA256_FIELDS = (
    "wrapper_source_sha256",
    "proposed_tuple_sha256",
    "runner_source_sha256",
    "broker_source_sha256",
    "validator_source_sha256",
)
SCHEDSTATS_ENABLED_PATH = pathlib.Path("/proc/sys/kernel/sched_schedstats")
TASK_ROOT = pathlib.Path("/proc/self/task")
WRAPPER_PATH = pathlib.Path(__file__).resolve()
TERMINATION_GRACE_SECONDS = 10.0


class WrapperRefusal(RuntimeError):
    """Name one closed wrapper stage and its bounded refusal reason."""

    def __init__(self, stage: str, reason: str) -> None:
        super().__init__(reason)
        self.stage = stage
        self.reason = reason


@dataclass(frozen=True)
class SourcePaths:
    """Paths whose bytes bind the registered scientific tuple."""

    proposed_tuple: pathlib.Path
    runner: pathlib.Path
    broker_source: pathlib.Path
    validator: pathlib.Path


def file_sha256(path: pathlib.Path) -> str:
    """Return the SHA-256 identity of one regular file."""
    if not path.is_file():
        raise WrapperRefusal("source_identity", f"required source is absent: {path}")
    digest = hashlib.sha256()
    try:
        with path.open("rb") as source:
            for block in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(block)
    except OSError as error:
        raise WrapperRefusal(
            "source_identity", f"required source is unreadable: {path}"
        ) from error
    return digest.hexdigest()


def reject_control_characters(value: str, field: str) -> None:
    """Reject bytes that the repository's two-column TSV readers cannot carry."""
    if not value or any(
        unicodedata.category(character).startswith("C") for character in value
    ):
        raise WrapperRefusal(
            "authorization_record", f"{field} contains an empty or control value"
        )


def write_closed_tsv(path: pathlib.Path, values: Mapping[str, str]) -> None:
    """Atomically serialize one ordered two-column record through csv.writer."""
    for field, value in values.items():
        reject_control_characters(field, "field")
        reject_control_characters(value, field)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as output:
            writer = csv.writer(
                output,
                delimiter="\t",
                lineterminator="\n",
                quoting=csv.QUOTE_NONE,
                escapechar=None,
            )
            writer.writerow(("field", "value"))
            writer.writerows(values.items())
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary_name, path)
    except BaseException:
        pathlib.Path(temporary_name).unlink(missing_ok=True)
        raise


def read_closed_tsv(
    path: pathlib.Path, required_fields: Sequence[str]
) -> dict[str, str]:
    """Read the exact two-column schema used by every wrapper record."""
    try:
        with path.open("r", encoding="utf-8", newline="") as source:
            rows = list(csv.reader(source, delimiter="\t", strict=True))
    except (OSError, csv.Error, UnicodeError) as error:
        raise WrapperRefusal(
            "authorization_record", "the authorization record is unreadable"
        ) from error
    if not rows or rows[0] != ["field", "value"]:
        raise WrapperRefusal(
            "authorization_record", "the authorization record header is malformed"
        )
    expected = set(required_fields)
    values: dict[str, str] = {}
    for row in rows[1:]:
        if len(row) != 2:
            raise WrapperRefusal(
                "authorization_record", "the authorization record has a malformed row"
            )
        field, value = row
        reject_control_characters(field, "field")
        reject_control_characters(value, field)
        if field not in expected:
            raise WrapperRefusal(
                "authorization_record",
                f"the authorization record has unknown field: {field}",
            )
        if field in values:
            raise WrapperRefusal(
                "authorization_record",
                f"the authorization record repeats field: {field}",
            )
        values[field] = value
    missing = expected.difference(values)
    if missing:
        raise WrapperRefusal(
            "authorization_record",
            f"the authorization record lacks fields: {','.join(sorted(missing))}",
        )
    return values


def validate_authorization(values: Mapping[str, str]) -> None:
    """Validate values whose exact cardinality was established by the reader."""
    if values["schema"] != AUTHORIZATION_SCHEMA:
        raise WrapperRefusal("authorization_record", "authorization schema differs")
    if values["operation"] != AUTHORIZATION_OPERATION:
        raise WrapperRefusal("authorization_record", "authorization operation differs")
    for field in SHA256_FIELDS:
        value = values[field]
        if len(value) != 64 or any(
            character not in "0123456789abcdef" for character in value
        ):
            raise WrapperRefusal(
                "authorization_record", f"{field} is not a lowercase SHA-256 identity"
            )


def authorization_values(
    authorization_reference: str, source_paths: SourcePaths
) -> dict[str, str]:
    """Build the canonical authorization record from registered source bytes."""
    reject_control_characters(authorization_reference, "authorization_reference")
    values = {
        "schema": AUTHORIZATION_SCHEMA,
        "authorization_reference": authorization_reference,
        "operation": AUTHORIZATION_OPERATION,
        "wrapper_source_sha256": file_sha256(WRAPPER_PATH),
        "proposed_tuple_sha256": file_sha256(source_paths.proposed_tuple),
        "runner_source_sha256": file_sha256(source_paths.runner),
        "broker_source_sha256": file_sha256(source_paths.broker_source),
        "validator_source_sha256": file_sha256(source_paths.validator),
    }
    validate_authorization(values)
    return values


def verify_source_identities(
    authorization: Mapping[str, str], source_paths: SourcePaths
) -> None:
    """Require each registered file to match the consumed authorization."""
    observed = {
        "wrapper_source_sha256": file_sha256(WRAPPER_PATH),
        "proposed_tuple_sha256": file_sha256(source_paths.proposed_tuple),
        "runner_source_sha256": file_sha256(source_paths.runner),
        "broker_source_sha256": file_sha256(source_paths.broker_source),
        "validator_source_sha256": file_sha256(source_paths.validator),
    }
    for field, digest in observed.items():
        if authorization[field] != digest:
            raise WrapperRefusal("source_identity", f"{field} differs")


def read_single_integer(path: pathlib.Path, refusal_prefix: str) -> int:
    """Read one decimal integer and preserve absent, unreadable, and malformed states."""
    try:
        text = path.read_text(encoding="ascii")
    except FileNotFoundError as error:
        raise WrapperRefusal(
            "scheduler_prerequisite", f"{refusal_prefix}_absent"
        ) from error
    except (OSError, UnicodeError) as error:
        raise WrapperRefusal(
            "scheduler_prerequisite", f"{refusal_prefix}_unreadable"
        ) from error
    stripped = text.strip()
    if not stripped or not stripped.isdecimal():
        raise WrapperRefusal("scheduler_prerequisite", f"{refusal_prefix}_malformed")
    return int(stripped)


def read_task_schedstat(
    task_root: pathlib.Path, process_id: int
) -> tuple[int, int, int]:
    """Read one task record using the identity of the Python process doing the read."""
    schedstat_path = task_root / str(process_id) / "schedstat"
    try:
        text = schedstat_path.read_text(encoding="ascii")
    except FileNotFoundError as error:
        raise WrapperRefusal(
            "scheduler_prerequisite", "task_schedstat_absent"
        ) from error
    except (OSError, UnicodeError) as error:
        raise WrapperRefusal(
            "scheduler_prerequisite", "task_schedstat_unreadable"
        ) from error
    fields = text.split()
    if len(fields) != 3 or any(not field.isdecimal() for field in fields):
        raise WrapperRefusal("scheduler_prerequisite", "task_schedstat_malformed")
    return (int(fields[0]), int(fields[1]), int(fields[2]))


def inspect_scheduler_prerequisites(
    schedstats_enabled_path: pathlib.Path = SCHEDSTATS_ENABLED_PATH,
    task_root: pathlib.Path = TASK_ROOT,
) -> tuple[int, int, int]:
    """Classify the facility, then read this Python process's own task record."""
    enabled = read_single_integer(schedstats_enabled_path, "sched_schedstats")
    if enabled != 1:
        raise WrapperRefusal("scheduler_prerequisite", "sched_schedstats_disabled")
    return read_task_schedstat(task_root, os.getpid())


def require_fresh_result_directory(record_directory: pathlib.Path) -> None:
    """Require one direct, absent child of the declared runtime results root."""
    reject_control_characters(record_directory.name, "record_directory")
    expected_parent = qwen_home.path("results").resolve()
    if record_directory.parent.resolve() != expected_parent:
        raise WrapperRefusal(
            "record_directory",
            "record directory must be a direct runtime results child",
        )
    try:
        record_directory.mkdir(mode=0o700)
    except FileExistsError as error:
        raise WrapperRefusal(
            "record_directory", "record directory already exists"
        ) from error


def process_group_lives(process_group_id: int) -> bool:
    """Return whether one owned process group retains an executable member."""
    for stat_path in pathlib.Path("/proc").glob("[0-9]*/stat"):
        try:
            stat_text = stat_path.read_text(encoding="utf-8")
            stat_fields = stat_text.rsplit(")", 1)[1].split()
            state = stat_fields[0]
            member_process_group = int(stat_fields[2])
        except (OSError, IndexError, ValueError):
            continue
        if member_process_group == process_group_id and state != "Z":
            return True
    return False


def wait_for_process_group_exit(
    process: subprocess.Popen[bytes], timeout_seconds: float
) -> bool:
    """Reap the leader and wait for every owned group member to exit."""
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        process.poll()
        if not process_group_lives(process.pid):
            return True
        time.sleep(0.02)
    process.poll()
    return not process_group_lives(process.pid)


def terminate_process_group(process: subprocess.Popen[bytes]) -> str:
    """Terminate and reap only the runner process group owned by this wrapper."""
    process.poll()
    if not process_group_lives(process.pid):
        return "already_exited"
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return "already_exited"
    try:
        if wait_for_process_group_exit(process, TERMINATION_GRACE_SECONDS):
            return "terminated"
        os.killpg(process.pid, signal.SIGKILL)
        if not wait_for_process_group_exit(process, TERMINATION_GRACE_SECONDS):
            return "kill_incomplete"
        process.wait(timeout=0)
        return "killed"
    except ProcessLookupError:
        return "terminated"


def terminal_values(
    authorization_reference: str,
    state: str,
    wrapper_stage: str,
    prerequisite_state: str,
    runner_state: str,
    runner_exit: str,
    cleanup: str,
    detail: str,
) -> dict[str, str]:
    """Build the complete terminal record for every wrapper exit path."""
    return {
        "schema": "qwen-q8-scheduler-replacement-terminal-v1",
        "authorization_reference": authorization_reference,
        "state": state,
        "wrapper_stage": wrapper_stage,
        "scheduler_prerequisite_state": prerequisite_state,
        "telemetry_broker_state": "not_built_or_launched"
        if runner_state == "not_started"
        else "runner_owned",
        "calibration_state": "not_started"
        if runner_state == "not_started"
        else "runner_owned",
        "runner_state": runner_state,
        "runner_exit": runner_exit,
        "cleanup": cleanup,
        "q8_candidate_timing": "withheld",
        "detail": detail,
    }


def execute_wrapper(
    authorization_path: pathlib.Path,
    record_directory: pathlib.Path,
    source_paths: SourcePaths,
    model_id: str,
    timeout_seconds: float,
    prerequisite_reader: Callable[
        [], tuple[int, int, int]
    ] = inspect_scheduler_prerequisites,
    process_factory: Callable[..., subprocess.Popen[bytes]] = subprocess.Popen,
) -> int:
    """Consume one authorization, inspect prerequisites, and own one runner."""
    authorization = read_closed_tsv(authorization_path, AUTHORIZATION_FIELDS)
    validate_authorization(authorization)
    verify_source_identities(authorization, source_paths)
    reject_control_characters(model_id, "model_id")
    qwen_home.require_binding()
    require_fresh_result_directory(record_directory)
    canonical_authorization = record_directory / "authorization.tsv"
    write_closed_tsv(canonical_authorization, authorization)
    round_trip = read_closed_tsv(canonical_authorization, AUTHORIZATION_FIELDS)
    validate_authorization(round_trip)
    if round_trip != authorization:
        raise WrapperRefusal("authorization_record", "authorization round trip differs")

    terminal_path = record_directory / "terminal-state.tsv"
    write_closed_tsv(
        terminal_path,
        terminal_values(
            authorization["authorization_reference"],
            "active",
            "prerequisite_inspection",
            "inspection_pending",
            "not_started",
            "-",
            "not_needed",
            "authorization consumed; scheduler prerequisite inspection pending",
        ),
    )
    try:
        prerequisite_reader()
    except WrapperRefusal as refusal:
        write_closed_tsv(
            terminal_path,
            terminal_values(
                authorization["authorization_reference"],
                "refused",
                refusal.stage,
                refusal.reason,
                "not_started",
                "-",
                "not_needed",
                refusal.reason,
            ),
        )
        return 2
    except Exception as error:
        detail = f"{type(error).__name__}: {error}"
        write_closed_tsv(
            terminal_path,
            terminal_values(
                authorization["authorization_reference"],
                "failed",
                "prerequisite_probe",
                "unknown",
                "not_started",
                "-",
                "not_needed",
                detail,
            ),
        )
        return 2

    acquisition_directory = record_directory / "acquisition"
    initial_values = {
        "schema": "qwen-q8-scheduler-replacement-initial-v1",
        "authorization_reference": authorization["authorization_reference"],
        "wrapper_source_sha256": authorization["wrapper_source_sha256"],
        "proposed_tuple_sha256": authorization["proposed_tuple_sha256"],
        "runner_source_sha256": authorization["runner_source_sha256"],
        "broker_source_sha256": authorization["broker_source_sha256"],
        "validator_source_sha256": authorization["validator_source_sha256"],
        "record_directory_role": "runtime_results_child",
        "acquisition_directory_role": "runner_output_child",
        "scheduler_prerequisite_state": "accepted",
        "runner_state": "not_started",
        "q8_candidate_timing": "withheld",
    }
    write_closed_tsv(record_directory / "initial-state.tsv", initial_values)

    environment = dict(os.environ)
    environment.update(
        QWEN_CENSUS_MODE="calibration",
        QWEN_CENSUS_SAMPLER="broker",
        QWEN_CENSUS_SCHEDULER_ATTRIBUTION="schedstat",
        QWEN_CENSUS_SIDECAR_COST_NS="1000000",
        QWEN_CENSUS_SIDECAR_CPU="0,1",
    )
    termination_signal: int | None = None

    def request_termination(signal_number: int, _frame: object) -> None:
        nonlocal termination_signal
        termination_signal = signal_number

    previous_handlers = {
        signal_number: signal.signal(signal_number, request_termination)
        for signal_number in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)
    }
    try:
        process = process_factory(
            [str(source_paths.runner), model_id, str(acquisition_directory)],
            env=environment,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception as error:
        for signal_number, previous_handler in previous_handlers.items():
            signal.signal(signal_number, previous_handler)
        write_closed_tsv(
            terminal_path,
            terminal_values(
                authorization["authorization_reference"],
                "failed",
                "runner_start",
                "accepted",
                "not_started",
                "-",
                "not_needed",
                f"{type(error).__name__}: {error}",
            ),
        )
        return 2

    started_ns = time.monotonic_ns()
    try:
        deadline = time.monotonic() + timeout_seconds
        while True:
            if termination_signal is not None:
                cleanup = terminate_process_group(process)
                runner_exit = 128 + termination_signal
                break
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                cleanup = terminate_process_group(process)
                runner_exit = 124
                break
            try:
                runner_exit = process.wait(timeout=min(remaining, 0.1))
                cleanup = terminate_process_group(process)
                break
            except subprocess.TimeoutExpired:
                continue
    finally:
        for signal_number, previous_handler in previous_handlers.items():
            signal.signal(signal_number, previous_handler)
    elapsed_ns = time.monotonic_ns() - started_ns
    write_closed_tsv(
        terminal_path,
        terminal_values(
            authorization["authorization_reference"],
            "completed" if runner_exit == 0 else "failed",
            "runner_completion",
            "accepted",
            "completed" if runner_exit == 0 else "failed",
            str(runner_exit),
            cleanup,
            f"runner_elapsed_ns={elapsed_ns}",
        ),
    )
    return runner_exit


def add_source_arguments(parser: argparse.ArgumentParser) -> None:
    """Add the four registered source identities to one command parser."""
    tree = pathlib.Path(__file__).resolve().parent.parent
    parser.add_argument(
        "--proposed-tuple",
        type=pathlib.Path,
        default=tree
        / "evidence/q8-attribution/sampler-cost-attribution/proposed-acquisition-tuple.tsv",
    )
    parser.add_argument(
        "--runner",
        type=pathlib.Path,
        default=pathlib.Path(__file__).with_name("run-raven2-vulkan-kernel-census.sh"),
    )
    parser.add_argument(
        "--broker-source",
        type=pathlib.Path,
        default=pathlib.Path(__file__).with_name("telemetry-broker.c"),
    )
    parser.add_argument(
        "--validator",
        type=pathlib.Path,
        default=pathlib.Path(__file__).with_name("validate-clock-sidecar.py"),
    )


def source_paths_from(arguments: argparse.Namespace) -> SourcePaths:
    """Collect the registered source paths from parsed arguments."""
    return SourcePaths(
        proposed_tuple=arguments.proposed_tuple,
        runner=arguments.runner,
        broker_source=arguments.broker_source,
        validator=arguments.validator,
    )


def prepare_authorization_record(
    output_path: pathlib.Path,
    authorization_reference: str,
    source_paths: SourcePaths,
) -> None:
    """Create one new authorization and prove it through the execution reader."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        raise WrapperRefusal(
            "authorization_record", "authorization output already exists"
        )
    values = authorization_values(authorization_reference, source_paths)
    write_closed_tsv(output_path, values)
    consumed = read_closed_tsv(output_path, AUTHORIZATION_FIELDS)
    validate_authorization(consumed)
    if consumed != values:
        raise WrapperRefusal("authorization_record", "authorization round trip differs")


def parse_arguments(arguments: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse the record-preparation and execution interfaces."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    prepare = commands.add_parser("prepare-authorization")
    prepare.add_argument("--authorization-reference", required=True)
    prepare.add_argument("--output", required=True, type=pathlib.Path)
    add_source_arguments(prepare)
    execute = commands.add_parser("execute")
    execute.add_argument("--authorization-record", required=True, type=pathlib.Path)
    execute.add_argument("--record-directory", required=True, type=pathlib.Path)
    execute.add_argument("--model-id", required=True)
    execute.add_argument("--timeout-seconds", type=float, default=21600.0)
    add_source_arguments(execute)
    parsed = parser.parse_args(arguments)
    if parsed.command == "execute" and (
        not math.isfinite(parsed.timeout_seconds) or parsed.timeout_seconds <= 0
    ):
        parser.error("--timeout-seconds must be finite and positive")
    return parsed


def main(arguments: Sequence[str] | None = None) -> int:
    """Prepare a validated record or consume one for a bounded execution."""
    parsed = parse_arguments(arguments)
    source_paths = source_paths_from(parsed)
    try:
        if parsed.command == "prepare-authorization":
            prepare_authorization_record(
                parsed.output, parsed.authorization_reference, source_paths
            )
            print(f"authorization_record=accepted path={parsed.output}")
            return 0
        return execute_wrapper(
            parsed.authorization_record,
            parsed.record_directory,
            source_paths,
            parsed.model_id,
            parsed.timeout_seconds,
        )
    except (WrapperRefusal, RuntimeError) as error:
        stage = error.stage if isinstance(error, WrapperRefusal) else "runtime_root"
        print(
            f"q8_scheduler_replacement=refused stage={stage} detail={error}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
