"""Owning one child process by identity rather than by name.

`pgrep -x llama-server` answers for every server on the machine and
`pgrep -f PATTERN` also matches the shell carrying the pattern, so neither
states whether this supervisor's own child is gone. The identity here is the
triple a pid alone cannot forge: the pid, the process group `start_new_session`
gave it, and field 22 of `/proc/<pid>/stat`, the start time in clock ticks that
tells a reused number from the process that held it. Every signal and every
absence proof passes through `Owned.is_same_process`, which is what
`qwen-teardown.sh` compares before it signals the broker, the image service,
and the search instance.

`terminate` signals the group rather than the pid, because a child that spawns
its own children -- llama-server in router mode spawns one per loaded model --
leaves them orphaned when only the leader is signalled. A departed leader is
exactly when that matters, so the group is enumerated rather than inferred
from the leader: `group_members` reads every `/proc/<pid>/stat` whose process
group equals the owned one and whose start time is at or after the leader's,
which are the processes this spawn produced. The start-time floor is what
keeps a recycled process-group id from drawing an unrelated group into the
signal, the hazard the leader's own start-time comparison closes for the
leader. SIGTERM, a grace of 2.0 s matching `monitor-qwen-runtime.sh`'s SIGKILL
grace, then SIGKILL, and the absence proof requires the leader gone and the
group empty.
"""

from __future__ import annotations

import errno
import os
import select
import signal
import subprocess
import time
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path

# The grace `monitor-qwen-runtime.sh` records as grace_milliseconds=2000: the
# interval between the SIGTERM it sends and the SIGKILL that follows.
TERMINATION_GRACE_SECONDS = 2.0
ABSENCE_POLL_SECONDS = 0.05


class SpawnError(RuntimeError):
    """A child that left before its ownership record could be completed."""


def read_start_time(pid: int) -> int | None:
    """Field 22 of `/proc/<pid>/stat`, or None where the process is gone.

    The comm field before it may hold spaces and parentheses, so the split
    runs from the last closing parenthesis rather than from the line start:
    counting from the left makes every later identity check vacuous for a
    process whose name carries one.
    """
    try:
        text = Path(f"/proc/{pid}/stat").read_text(encoding="ascii")  # appliance-path: named
    except OSError:
        return None
    tail = text.rsplit(")", 1)
    if len(tail) != 2:
        return None
    fields = tail[1].split()
    if len(fields) < 20:
        return None
    try:
        return int(fields[19])
    except ValueError:
        return None


def read_affinity(pid: int) -> str | None:
    """`Cpus_allowed_list` from `/proc/<pid>/status`, the readback the session takes."""
    try:
        text = Path(f"/proc/{pid}/status").read_text(encoding="utf-8")  # appliance-path: named
    except OSError:
        return None
    for line in text.splitlines():
        if line.startswith("Cpus_allowed_list:"):
            return line.split(":", 1)[1].strip()
    return None


def read_niceness(pid: int) -> int | None:
    """Field 19 of `/proc/<pid>/stat`, the nice value the session requires at 19."""
    try:
        text = Path(f"/proc/{pid}/stat").read_text(encoding="ascii")  # appliance-path: named
    except OSError:
        return None
    tail = text.rsplit(")", 1)
    if len(tail) != 2:
        return None
    fields = tail[1].split()
    if len(fields) < 17:
        return None
    try:
        return int(fields[16])
    except ValueError:
        return None


@dataclass(frozen=True)
class Owned:
    """One child this supervisor started, identified past pid reuse."""

    pid: int
    pgid: int
    start_time: int
    pidfd: int | None = field(default=None, compare=False, repr=False)
    process: subprocess.Popen[bytes] | None = field(default=None, compare=False, repr=False)

    def is_same_process(self) -> bool:
        """Whether the pid still carries the start time this record was built from."""
        return read_start_time(self.pid) == self.start_time

    def has_exited(self) -> bool:
        """Whether the child has left, read from the pidfd where one opened.

        A pidfd becomes readable exactly once its process exits and answers for
        that process alone, so it survives pid reuse the way a name match does
        not. The start-time comparison answers where no pidfd opened.
        """
        if self.pidfd is not None:
            poller = select.poll()
            poller.register(self.pidfd, select.POLLIN)
            return bool(poller.poll(0))
        return not self.is_same_process()

    def exit_status(self) -> int | None:
        """The reaped status, or None while the child runs.

        Reaping goes through the Popen object, which owns the waitpid call:
        a second waitpid on the same pid from elsewhere would race it.
        """
        if self.process is None:
            return None
        return self.process.poll()

    def close(self) -> None:
        if self.pidfd is not None:
            try:
                os.close(self.pidfd)
            except OSError:
                pass


def group_members(pgid: int, *, not_before: int) -> list[int]:
    """Every live process in the group that this spawn could have produced.

    A process group id is reused once its last member leaves, so membership
    alone names whatever group now carries the number. The start-time floor is
    the leader's own, and a descendant is created after its ancestor, so a
    process in the group whose start time precedes the leader's belongs to the
    recycled group rather than to this one.
    """
    members = []
    self_pid = os.getpid()
    for entry in Path("/proc").iterdir():  # appliance-path: named
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        if pid == self_pid:
            continue
        try:
            text = (entry / "stat").read_text(encoding="ascii")
        except OSError:
            continue
        tail = text.rsplit(")", 1)
        if len(tail) != 2:
            continue
        fields = tail[1].split()
        if len(fields) < 20:
            continue
        try:
            if int(fields[2]) != pgid or int(fields[19]) < not_before:
                continue
        except ValueError:
            continue
        members.append(pid)
    return members


@dataclass(frozen=True)
class Termination:
    """What one termination did and what it proved afterwards."""

    signalled: str
    waited_seconds: float
    exit_status: int | None
    absent: bool
    survivors: tuple[int, ...] = ()

    def render(self) -> str:
        survivors = ",".join(str(pid) for pid in self.survivors) or "-"
        return (
            f"signalled={self.signalled} waited_seconds={self.waited_seconds:.3f} "
            f"exit_status={'-' if self.exit_status is None else self.exit_status} "
            f"absent={'yes' if self.absent else 'no'} survivors={survivors}"
        )


def _open_pidfd(pid: int) -> int | None:
    try:
        return os.pidfd_open(pid)
    except (OSError, AttributeError):
        return None


def spawn(
    argv: Sequence[str],
    *,
    env: Mapping[str, str],
    cwd: Path,
    stdout_path: Path,
    stderr_path: Path,
    cpu_affinity: set[int] | None = None,
    niceness: int | None = None,
) -> Owned:
    """Start one child in its own session and record what identifies it.

    `shell=False` with an argv list keeps the command out of a shell's parsing,
    and `start_new_session=True` makes the child a session and process-group
    leader, so its pgid equals its pid and one `killpg` reaches everything it
    spawns. Affinity and niceness are applied to the child pid after the fork
    rather than in a `preexec_fn`, because this process runs a control-socket
    listener beside the supervise loop and `preexec_fn` between fork and exec
    in a multithreaded process is unsafe; the readback below is what proves the
    policy actually landed, and the window before it is the interval the child
    runs unpinned.
    """
    stdout_path.parent.mkdir(parents=True, exist_ok=True)
    stderr_path.parent.mkdir(parents=True, exist_ok=True)
    with stdout_path.open("wb") as out_handle, stderr_path.open("wb") as error_handle:
        process = subprocess.Popen(  # noqa: S603
            list(argv),
            env=dict(env),
            cwd=str(cwd),
            stdin=subprocess.DEVNULL,
            stdout=out_handle,
            stderr=error_handle,
            shell=False,
            start_new_session=True,
            close_fds=True,
        )
    pid = process.pid
    pidfd = _open_pidfd(pid)
    start_time = read_start_time(pid)
    if start_time is None:
        process.poll()
        if pidfd is not None:
            os.close(pidfd)
        raise SpawnError(f"child {pid} left before its start time could be read: {argv[0]}")

    if cpu_affinity is not None:
        try:
            os.sched_setaffinity(pid, cpu_affinity)
        except OSError as error:
            raise SpawnError(f"child {pid} refused cpu affinity {sorted(cpu_affinity)}") from error
    if niceness is not None:
        try:
            os.setpriority(os.PRIO_PROCESS, pid, niceness)
        except OSError as error:
            raise SpawnError(f"child {pid} refused nice {niceness}") from error

    # `start_new_session` makes the child a process-group leader, so its pgid
    # equals its pid; the readback confirms it and the pid answers where the
    # child left between the fork and this call.
    try:
        pgid = os.getpgid(pid)
    except ProcessLookupError:
        pgid = pid
    return Owned(pid=pid, pgid=pgid, start_time=start_time, pidfd=pidfd, process=process)


def _signal_group(owned: Owned, number: int) -> bool:
    """Signal the owned process group, whose membership the caller has proved."""
    try:
        os.killpg(owned.pgid, number)
    except ProcessLookupError:
        return False
    except OSError as error:
        if error.errno == errno.ESRCH:
            return False
        raise
    return True


def _survivors(owned: Owned) -> list[int]:
    """The group members outliving one termination attempt, leader included."""
    if owned.process is not None:
        owned.process.poll()
    remaining = group_members(owned.pgid, not_before=owned.start_time)
    if owned.is_same_process() and owned.pid not in remaining:
        remaining.append(owned.pid)
    return remaining


def _await_absence(owned: Owned, limit_seconds: float) -> list[int]:
    deadline = time.monotonic() + limit_seconds
    while True:
        remaining = _survivors(owned)
        if not remaining:
            return []
        if time.monotonic() >= deadline:
            return remaining
        time.sleep(ABSENCE_POLL_SECONDS)


def terminate(owned: Owned, *, grace_s: float = TERMINATION_GRACE_SECONDS) -> Termination:
    """End the owned group and prove it gone, never by matching a name.

    SIGTERM reaches the group, the grace is the 2.0 s
    `monitor-qwen-runtime.sh` allows, SIGKILL follows where the group outlives
    it, and the absence proof requires the leader's start time gone and no
    group member this spawn could have produced. A leader that exited leaving
    children is the case the group enumeration exists for: its own identity
    check answers absent while its children still hold the device.
    """
    started = time.monotonic()
    if not _survivors(owned):
        return Termination(
            signalled="none",
            waited_seconds=0.0,
            exit_status=owned.exit_status(),
            absent=True,
        )

    _signal_group(owned, signal.SIGTERM)
    if not _await_absence(owned, grace_s):
        return Termination(
            signalled="SIGTERM",
            waited_seconds=time.monotonic() - started,
            exit_status=owned.exit_status(),
            absent=True,
        )

    _signal_group(owned, signal.SIGKILL)
    survivors = _await_absence(owned, grace_s)
    return Termination(
        signalled="SIGKILL",
        waited_seconds=time.monotonic() - started,
        exit_status=owned.exit_status(),
        absent=not survivors,
        survivors=tuple(survivors),
    )
