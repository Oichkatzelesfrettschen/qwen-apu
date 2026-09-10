#!/usr/bin/env python3
"""Run the read-only launch-readiness check and publish one bounded record."""

from __future__ import annotations

import argparse
import datetime as dt
import errno
import json
import os
import signal
import socket
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, BinaryIO, Callable

import qwen_home

SCHEMA_VERSION = 1
POLL_SECONDS = 0.01


class DriverError(RuntimeError):
    """The driver cannot establish its bounded output contract."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def boot_metadata() -> dict[str, str]:
    metadata = {"hostname": socket.gethostname(), "boot_id": "unavailable"}
    try:
        metadata["boot_id"] = (
            Path("/proc/sys/kernel/random/boot_id").read_text(encoding="ascii").strip()
        )
    except OSError:
        pass
    return metadata


def producer_identity() -> dict[str, int | str]:
    return {
        "name": "readiness-driver",
        "pid": os.getpid(),
        "uid": os.getuid(),
        "gid": os.getgid(),
    }


def atomic_write_json(target: Path, record: dict[str, Any]) -> None:
    """Publish JSON with replace as the final fallible publication operation."""
    temporary = target.parent / f".{target.name}.{uuid.uuid4().hex}.tmp"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            json.dump(
                record, output, allow_nan=False, separators=(",", ":"), sort_keys=True
            )
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        directory_descriptor = os.open(target.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
        os.replace(temporary, target)
    except BaseException:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        raise


def create_result_directory(requested: Path | None) -> Path:
    results_root = qwen_home.path("results").resolve()
    results_root.mkdir(parents=True, exist_ok=True)
    if requested is None:
        stamp = utc_now().replace(":", "").replace("-", "")
        result_directory = (
            results_root / f"launch-readiness-{stamp}-{uuid.uuid4().hex[:12]}"
        )
    else:
        result_directory = requested.resolve()
        if result_directory.parent != results_root:
            raise DriverError(
                f"result directory must be a direct child of {results_root}"
            )
    result_directory.mkdir(mode=0o700)
    os.chmod(result_directory, 0o700)
    return result_directory


def open_log(path: Path) -> BinaryIO:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.fchmod(descriptor, 0o600)
    return os.fdopen(descriptor, "wb", buffering=0)


def read_process_session(process_id: int) -> tuple[str, int] | None:
    try:
        contents = Path(f"/proc/{process_id}/stat").read_text(encoding="ascii")
    except (FileNotFoundError, ProcessLookupError):
        return None
    closing_parenthesis = contents.rfind(")")
    fields = contents[closing_parenthesis + 2 :].split()
    if closing_parenthesis < 0 or len(fields) < 4:
        return None
    return fields[0], int(fields[3])


def process_owner_uid(process_id: int) -> int | None:
    try:
        lines = (
            Path(f"/proc/{process_id}/status").read_text(encoding="ascii").splitlines()
        )
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return None
    for line in lines:
        if line.startswith("Uid:"):
            return int(line.split()[1])
    return None


def session_census(session_id: int) -> dict[str, list[int]]:
    census: dict[str, list[int]] = {
        "live": [],
        "zombie": [],
        "unreadable_owned": [],
        "unreadable_unknown": [],
    }
    for entry in Path("/proc").iterdir():
        if not entry.name.isdecimal():
            continue
        process_id = int(entry.name)
        try:
            identity = read_process_session(process_id)
        except (OSError, UnicodeError, ValueError):
            owner_uid = process_owner_uid(process_id)
            category = (
                "unreadable_owned" if owner_uid == os.getuid() else "unreadable_unknown"
            )
            census[category].append(process_id)
            continue
        if identity is None or identity[1] != session_id:
            continue
        census["zombie" if identity[0] == "Z" else "live"].append(process_id)
    for process_ids in census.values():
        process_ids.sort()
    return census


def status_returncode(status: os.waitid_result) -> int:
    return status.si_status if status.si_code == os.CLD_EXITED else -status.si_status


@dataclass
class Runtime:
    clock_ns: Callable[[], int] = time.monotonic_ns
    sleep: Callable[[float], None] = time.sleep
    popen: Callable[..., subprocess.Popen[bytes]] = subprocess.Popen
    waitid: Callable[..., os.waitid_result | None] = os.waitid
    killpg: Callable[[int, int], None] = os.killpg
    census: Callable[[int], dict[str, list[int]]] = session_census
    publish: Callable[[Path, dict[str, Any]], None] = atomic_write_json


class Cancellation:
    def __init__(self) -> None:
        self.signal_number: int | None = None
        self.count = 0

    def __call__(self, signal_number: int, _frame: Any) -> None:
        self.count += 1
        if self.signal_number is None:
            self.signal_number = signal_number


def reserve_leader(runtime: Runtime, process_id: int) -> os.waitid_result | None:
    return runtime.waitid(os.P_PID, process_id, os.WEXITED | os.WNOHANG | os.WNOWAIT)


def signal_group(runtime: Runtime, process_id: int, signal_number: int) -> bool:
    try:
        runtime.killpg(process_id, signal_number)
        return True
    except ProcessLookupError:
        return False


def sleep_with_deadline(runtime: Runtime, deadline_ns: int) -> None:
    remaining_ns = max(0, deadline_ns - runtime.clock_ns())
    runtime.sleep(min(POLL_SECONDS, remaining_ns / 1_000_000_000))


def cleanup_session(
    runtime: Runtime,
    process_id: int,
    reserved_status: os.waitid_result | None,
    deadline_ns: int,
) -> tuple[dict[str, Any], os.waitid_result | None]:
    signals: list[str] = []
    initial = runtime.census(process_id)
    census_incomplete = bool(
        initial.get("unreadable_owned") or initial.get("unreadable_unknown")
    )
    if (initial["live"] or census_incomplete) and signal_group(
        runtime, process_id, signal.SIGTERM
    ):
        signals.append("SIGTERM")
    kill_at_ns = runtime.clock_ns() + max(0, deadline_ns - runtime.clock_ns()) // 2
    kill_sent = False
    while runtime.clock_ns() < deadline_ns:
        if reserved_status is None:
            reserved_status = reserve_leader(runtime, process_id)
        residuals = runtime.census(process_id)
        census_incomplete = census_incomplete or bool(
            residuals.get("unreadable_owned") or residuals.get("unreadable_unknown")
        )
        if not residuals["live"]:
            if reserved_status is None:
                sleep_with_deadline(runtime, deadline_ns)
                continue
            return {
                "state": "census_incomplete" if census_incomplete else "completed",
                "signals": signals,
                "leader_reserved": reserved_status is not None,
                "residuals": residuals,
            }, reserved_status
        if not kill_sent and runtime.clock_ns() >= kill_at_ns:
            if signal_group(runtime, process_id, signal.SIGKILL):
                signals.append("SIGKILL")
            kill_sent = True
        sleep_with_deadline(runtime, deadline_ns)
    residuals = runtime.census(process_id)
    census_incomplete = census_incomplete or bool(
        residuals.get("unreadable_owned") or residuals.get("unreadable_unknown")
    )
    if residuals["live"] and not kill_sent:
        if signal_group(runtime, process_id, signal.SIGKILL):
            signals.append("SIGKILL")
    return {
        "state": (
            "deadline_exceeded"
            if residuals["live"]
            else ("census_incomplete" if census_incomplete else "completed")
        ),
        "signals": signals,
        "leader_reserved": reserved_status is not None,
        "residuals": residuals,
    }, reserved_status


def parse_readiness_reply(stdout_path: Path, returncode: int | None) -> str:
    if returncode not in (0, 1):
        return "unknown"
    try:
        lines = stdout_path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return "malformed"
    replies = [
        line.split()[0] for line in lines if line.startswith("launch_readiness=")
    ]
    expected = (
        "launch_readiness=accepted" if returncode == 0 else "launch_readiness=refused"
    )
    if len(replies) != 1:
        return "malformed"
    return (
        replies[0].removeprefix("launch_readiness=")
        if replies[0] == expected
        else "unknown"
    )


def run_probe(
    result_directory: Path,
    timeout_ms: int,
    cleanup_timeout_ms: int,
    runtime: Runtime | None = None,
    command: list[str] | None = None,
) -> tuple[int, dict[str, Any]]:
    runtime = runtime or Runtime()
    command = command or [str(Path(__file__).with_name("check-launch-readiness.sh"))]
    started_ns = runtime.clock_ns()
    common = {
        "schema_version": SCHEMA_VERSION,
        "producer": producer_identity(),
        "boot": boot_metadata(),
        "started_utc": utc_now(),
        "started_monotonic_ns": started_ns,
    }
    terminal_path = result_directory / "terminal.json"
    runtime.publish(terminal_path, {**common, "record_state": "incomplete"})
    cancellation = Cancellation()
    previous_handlers = {
        number: signal.getsignal(number) for number in (signal.SIGINT, signal.SIGTERM)
    }
    signal.signal(signal.SIGINT, cancellation)
    signal.signal(signal.SIGTERM, cancellation)
    process: subprocess.Popen[bytes] | None = None
    reserved_status: os.waitid_result | None = None
    primary_state = "start_failure"
    start_error: dict[str, int | str] | None = None
    execution_error: dict[str, str] | None = None
    cleanup: dict[str, Any] = {
        "state": "not_required",
        "signals": [],
        "leader_reserved": False,
        "residuals": {
            "live": [],
            "zombie": [],
            "unreadable_owned": [],
            "unreadable_unknown": [],
        },
    }
    try:
        with (
            open_log(result_directory / "stdout.log") as stdout_log,
            open_log(result_directory / "stderr.log") as stderr_log,
        ):
            try:
                process = runtime.popen(
                    command,
                    cwd=qwen_home.tree_root(),
                    env=dict(os.environ),
                    stdin=subprocess.DEVNULL,
                    stdout=stdout_log,
                    stderr=stderr_log,
                    close_fds=True,
                    start_new_session=True,
                )
            except OSError as error:
                start_error = {"errno": error.errno or errno.EIO, "message": str(error)}
            if process is not None:
                run_deadline_ns = started_ns + timeout_ms * 1_000_000
                while True:
                    if cancellation.signal_number is not None:
                        primary_state = "cancelled"
                        break
                    try:
                        reserved_status = reserve_leader(runtime, process.pid)
                    except (OSError, RuntimeError, ValueError) as error:
                        primary_state = "internal_failure"
                        execution_error = {
                            "operation": "reserve_leader",
                            "message": str(error),
                        }
                        break
                    if reserved_status is not None:
                        primary_state = "completed"
                        break
                    if runtime.clock_ns() >= run_deadline_ns:
                        primary_state = "timed_out"
                        break
                    try:
                        sleep_with_deadline(runtime, run_deadline_ns)
                    except (OSError, RuntimeError, ValueError) as error:
                        primary_state = "internal_failure"
                        execution_error = {
                            "operation": "run_wait",
                            "message": str(error),
                        }
                        break
                cleanup_deadline_ns = (
                    runtime.clock_ns() + cleanup_timeout_ms * 1_000_000
                )
                try:
                    cleanup, reserved_status = cleanup_session(
                        runtime, process.pid, reserved_status, cleanup_deadline_ns
                    )
                except (OSError, RuntimeError, ValueError) as error:
                    primary_state = "internal_failure"
                    execution_error = {
                        "operation": "cleanup_session",
                        "message": str(error),
                    }
                    # Retry against the original cleanup deadline. The
                    # unreaped child leader still reserves its process-group
                    # identity, so this retry cannot signal a reused group.
                    try:
                        cleanup, reserved_status = cleanup_session(
                            runtime, process.pid, reserved_status, cleanup_deadline_ns
                        )
                    except (OSError, RuntimeError, ValueError) as cleanup_error:
                        emergency_signals: list[str] = []
                        if runtime.clock_ns() < cleanup_deadline_ns and signal_group(
                            runtime, process.pid, signal.SIGTERM
                        ):
                            emergency_signals.append("SIGTERM")
                        if runtime.clock_ns() < cleanup_deadline_ns and signal_group(
                            runtime, process.pid, signal.SIGKILL
                        ):
                            emergency_signals.append("SIGKILL")
                        cleanup = {
                            "state": "internal_failure",
                            "signals": emergency_signals,
                            "leader_reserved": reserved_status is not None,
                            "residuals": {
                                "live": [],
                                "zombie": [],
                                "unreadable_owned": [process.pid],
                                "unreadable_unknown": [],
                            },
                            "error": str(cleanup_error),
                        }
        returncode = status_returncode(reserved_status) if reserved_status else None
        if process is not None and reserved_status is not None:
            try:
                runtime.waitid(os.P_PID, process.pid, os.WEXITED)
                process.returncode = returncode
            except (OSError, RuntimeError, ValueError) as error:
                primary_state = "internal_failure"
                execution_error = {
                    "operation": "reap_leader",
                    "message": str(error),
                }
        census_before_leader_reap = cleanup["residuals"]
        if process is not None:
            cleanup["residuals"] = {
                process_state: [
                    process_id
                    for process_id in process_ids
                    if process_id != process.pid
                ]
                for process_state, process_ids in census_before_leader_reap.items()
            }
        cleanup["census_before_leader_reap"] = census_before_leader_reap
        reply = parse_readiness_reply(result_directory / "stdout.log", returncode)
        accepted = (
            primary_state == "completed"
            and returncode == 0
            and reply == "accepted"
            and cleanup["state"] == "completed"
            and not cleanup["residuals"]["live"]
        )
        record = {
            **common,
            "record_state": "complete",
            "outcome": "accepted" if accepted else "refused",
            "finished_utc": utc_now(),
            "finished_monotonic_ns": runtime.clock_ns(),
            "limits": {
                "run_timeout_ms": timeout_ms,
                "cleanup_timeout_ms": cleanup_timeout_ms,
            },
            "primary": {
                "state": primary_state,
                "process_id": process.pid if process is not None else None,
                "returncode": returncode,
                "start_error": start_error,
                "execution_error": execution_error,
                "cancellation_signal": cancellation.signal_number,
                "cancellation_count": cancellation.count,
                "readiness_reply": reply,
            },
            "cleanup": cleanup,
            "service_verification": "not_observed",
            "restoration": "not_applicable",
        }
        runtime.publish(terminal_path, record)
        return (0 if accepted else 1), record
    finally:
        for number, previous_handler in previous_handlers.items():
            signal.signal(number, previous_handler)


def parse_arguments(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout-ms", type=int, default=30_000)
    parser.add_argument("--cleanup-timeout-ms", type=int, default=5_000)
    parser.add_argument("--result-dir", type=Path)
    arguments = parser.parse_args(argv)
    if arguments.timeout_ms <= 0 or arguments.cleanup_timeout_ms <= 0:
        parser.error("timeouts must be positive integers")
    return arguments


def main(argv: list[str] | None = None) -> int:
    arguments = parse_arguments(argv)
    try:
        qwen_home.require_binding()
        result_directory = create_result_directory(arguments.result_dir)
        exit_status, _record = run_probe(
            result_directory, arguments.timeout_ms, arguments.cleanup_timeout_ms
        )
        print(f"readiness_result={result_directory / 'terminal.json'}")
        return exit_status
    except (DriverError, OSError, ValueError) as error:
        print(f"readiness_driver=failed reason={error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
