#!/usr/bin/env python3
"""Signal one process group through a stable reference to its leader."""

from __future__ import annotations

import errno
import os
import signal
import sys
from pathlib import Path

PIDFD_SIGNAL_PROCESS_GROUP = 1 << 2
SIGNALS = {
    "HUP": signal.SIGHUP,
    "INT": signal.SIGINT,
    "TERM": signal.SIGTERM,
}


class SignalProcessGroupError(Exception):
    """Describe a refused or unavailable identity-bound signal."""


def parse_positive_integer(value: str, name: str) -> int:
    if not value.isascii() or not value.isdecimal() or value.startswith("0"):
        raise SignalProcessGroupError(f"{name} must be a canonical positive integer")
    parsed = int(value)
    if parsed <= 0:
        raise SignalProcessGroupError(f"{name} must be a canonical positive integer")
    return parsed


def read_process_identity(process_id: int) -> tuple[int, int, int]:
    try:
        stat_text = (Path("/proc") / str(process_id) / "stat").read_text(encoding="ascii")
    except (FileNotFoundError, ProcessLookupError) as error:
        raise SignalProcessGroupError("process leader is absent") from error
    command_end = stat_text.rfind(")")
    if command_end < 0 or command_end + 2 >= len(stat_text):
        raise SignalProcessGroupError("process leader stat is malformed")
    fields = stat_text[command_end + 2 :].split()
    if len(fields) < 20:
        raise SignalProcessGroupError("process leader stat has too few fields")
    try:
        process_group_id = int(fields[2])
        session_id = int(fields[3])
        start_time_ticks = int(fields[19])
    except ValueError as error:
        raise SignalProcessGroupError("process leader stat has malformed integers") from error
    return process_group_id, session_id, start_time_ticks


def signal_process_group(
    process_id: int, expected_start_time_ticks: int, signal_number: int
) -> None:
    try:
        process_descriptor = os.pidfd_open(process_id)
    except ProcessLookupError as error:
        raise SignalProcessGroupError("process leader is absent") from error
    try:
        process_group_id, session_id, observed_start_time_ticks = read_process_identity(process_id)
        if observed_start_time_ticks != expected_start_time_ticks:
            raise SignalProcessGroupError(
                "process leader start time differs from the recorded identity"
            )
        if process_group_id != process_id or session_id != process_id:
            raise SignalProcessGroupError(
                "process leader does not own its process group and session"
            )
        try:
            signal.pidfd_send_signal(
                process_descriptor,
                signal_number,
                None,
                PIDFD_SIGNAL_PROCESS_GROUP,
            )
        except ProcessLookupError as error:
            raise SignalProcessGroupError("process group exited before signaling") from error
        except OSError as error:
            if error.errno == errno.EINVAL:
                raise SignalProcessGroupError(
                    "kernel lacks pidfd process-group signaling"
                ) from error
            raise SignalProcessGroupError(f"pidfd process-group signal failed: {error}") from error
    finally:
        os.close(process_descriptor)


def check_kernel_support() -> None:
    read_descriptor, write_descriptor = os.pipe()
    child_pid = os.fork()
    if child_pid == 0:
        os.close(read_descriptor)
        try:
            os.setsid()
            os.write(write_descriptor, b"1")
            signal.pause()
        finally:
            os._exit(0)
    os.close(write_descriptor)
    process_descriptor: int | None = None
    try:
        process_descriptor = os.pidfd_open(child_pid)
        if os.read(read_descriptor, 1) != b"1":
            raise SignalProcessGroupError("pidfd support probe did not become ready")
        signal.pidfd_send_signal(
            process_descriptor,
            0,
            None,
            PIDFD_SIGNAL_PROCESS_GROUP,
        )
        signal.pidfd_send_signal(process_descriptor, signal.SIGTERM)
    except OSError as error:
        if error.errno == errno.EINVAL:
            raise SignalProcessGroupError("kernel lacks pidfd process-group signaling") from error
        raise SignalProcessGroupError(
            f"pidfd process-group support probe failed: {error}"
        ) from error
    finally:
        os.close(read_descriptor)
        try:
            waited_pid, _ = os.waitpid(child_pid, os.WNOHANG)
        except ChildProcessError:
            waited_pid = child_pid
        if waited_pid == 0:
            try:
                if process_descriptor is not None:
                    signal.pidfd_send_signal(process_descriptor, signal.SIGKILL)
                else:
                    os.kill(child_pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                waited_pid, _ = os.waitpid(child_pid, 0)
            except ChildProcessError:
                waited_pid = child_pid
        if process_descriptor is not None:
            os.close(process_descriptor)
        if waited_pid != child_pid:
            raise SignalProcessGroupError("pidfd support probe reaped another process")


def main(arguments: list[str]) -> int:
    if arguments == ["--check"]:
        try:
            check_kernel_support()
        except SignalProcessGroupError as error:
            print(f"pidfd process-group check refused: {error}", file=sys.stderr)
            return 1
        print("pidfd_process_group=available")
        return 0
    if len(arguments) != 3:
        print(
            f"usage: {Path(sys.argv[0]).name} PID START_TIME_TICKS HUP|INT|TERM",
            file=sys.stderr,
        )
        return 2
    try:
        process_id = parse_positive_integer(arguments[0], "PID")
        start_time_ticks = parse_positive_integer(arguments[1], "START_TIME_TICKS")
        signal_number = SIGNALS.get(arguments[2])
        if signal_number is None:
            raise SignalProcessGroupError("signal must be HUP, INT, or TERM")
        signal_process_group(process_id, start_time_ticks, signal_number)
    except SignalProcessGroupError as error:
        print(f"pidfd process-group signal refused: {error}", file=sys.stderr)
        return 1
    print(
        f"pidfd_process_group=signaled pid={process_id} "
        f"start_time_ticks={start_time_ticks} signal={arguments[2]}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
