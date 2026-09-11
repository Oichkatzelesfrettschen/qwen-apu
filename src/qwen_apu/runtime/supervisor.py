"""One process that starts the server, watches it, ends it, and proves it gone.

The chain this replaces spends five scripts and a tmux server on that job:
`qwen-webui-control.sh` owns the session, `qwen-webui-session.sh` spawns the
server and arms the guards, `monitor-qwen-runtime.sh` samples every second,
`watch-qwen-kernel-hazards.sh` follows the kernel log, and
`qwen-teardown.sh` recovers the guard PIDs and proves absence. The tmux
boundary is what made the recovery necessary: `tmux kill-session` ends the
session script without running its EXIT trap, so the guards are orphaned and
the teardown re-reads their PIDs from `session.status` before `stop` rewrites
it. A supervisor that is itself the parent has no such boundary -- the
children are its own, the record is written whole on every transition, and
SIGTERM reaches a handler rather than a session manager.

Three properties carry over unchanged. Every signal binds to a start time, so
a pid reused between the record and the signal is left alone. The teardown
proves absence and exits non-zero on residue, so a caller cannot mistake a
partial stop for a clean one. The Vulkan workload lease stays the child's:
the supervisor arms the file, names it in QWEN_VULKAN_WORKLOAD_LOCK, and
proves it free once the child is gone.

What the supervisor does not carry is named here rather than discovered later.
`monitor-qwen-runtime.sh` enforces a MemAvailable floor, a swap-in ceiling, a
`gpu_busy_percent` ceiling, and affinity and nice drift, and it terminates the
server on each; this loop samples child liveness, health, and kernel hazards
alone, and those thresholds belong to a telemetry surface of their own.
`/dev/kmsg` needs CAP_SYSLOG wherever `kernel.dmesg_restrict` is 1, so the
hazard watcher records a skip reason where the shell watcher ran `dmesg
--follow-new` and terminated the server on a ring timeout or a GPU reset.
"""

from __future__ import annotations

import argparse
import errno
import http.client
import json
import os
import re
import signal
import socket
import stat
import sys
import threading
import time
from collections.abc import Mapping, Sequence
from contextlib import ExitStack
from dataclasses import dataclass, field
from pathlib import Path
from types import FrameType
from typing import Any

from .health import ListenerAbsent, health_is_serving, probe_listener, wait_ready
from .locks import LeaseBusy, WorkloadLease, hold
from .paths import RuntimePaths
from .process import Owned, read_start_time, spawn, terminate
from .state import RuntimeRecord, RuntimeState, State, utc_now

# The hazard signatures `watch-qwen-kernel-hazards.sh` matches with `grep -Eai`.
# POSIX `[^[:cntrl:]]` becomes the same class in Python, and the match stays
# case-insensitive because that is what the `-i` there means.
HAZARD_PATTERN = re.compile(
    r"ring[^\x00-\x1f\x7f]*timeout"
    r"|GPU reset"
    r"|amdgpu[^\x00-\x1f\x7f]*reset"
    r"|VM fault"
    r"|device loss"
    r"|device lost"
    r"|out of memory"
    r"|oom-kill",
    re.IGNORECASE,
)
DEFAULT_HAZARD_SOURCE = Path("/dev/kmsg")

# The sample period `monitor-qwen-runtime.sh` sets, and the grace its SIGKILL
# path records as grace_milliseconds=2000.
SAMPLE_INTERVAL_SECONDS = 1.0
TERMINATION_GRACE_SECONDS = 2.0
HEALTH_EVERY_SAMPLES = 5
# One refused exchange can be an accept backlog behind a decode holding the
# handler, so the condition is two consecutive refusals a sample period apart
# rather than one.
HEALTH_FAILURE_TOLERANCE = 2

CONTROL_SOCKET_MODE = 0o600
CONTROL_ACCEPT_TIMEOUT_SECONDS = 0.25
CONTROL_LINE_BYTES = 4096
DEPLOYMENT_LOCK_NAME = ".activate.lock"
LOCK_WAIT_SECONDS = 10.0
STOP_WAIT_SECONDS = 30.0


class SupervisorRefused(RuntimeError):
    """A launch refused before the child started, naming what refused it."""


class KernelHazardWatcher:
    """The kernel log, read for the signatures that end a serving session.

    The source is a path so a test drives the signature set from a regular
    file, which is why `watch-qwen-kernel-hazards.sh` takes an optional
    TEST_INPUT argument: `/dev/kmsg` needs CAP_SYSLOG under
    `kernel.dmesg_restrict=1` and no unprivileged run reaches the real stream.
    An unreadable source records its reason and every poll answers empty,
    which is the state the reason describes rather than a silent pass.
    """

    def __init__(self, source: Path = DEFAULT_HAZARD_SOURCE) -> None:
        self.source = source
        self.reason: str | None = None
        self._descriptor: int | None = None
        self._buffer = b""

    def open(self) -> str | None:
        """Arm the watcher; returns the skip reason where the source refuses."""
        try:
            descriptor = os.open(self.source, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
        except OSError as error:
            self.reason = f"{self.source} is unreadable: {error.strerror}"
            return self.reason
        self._descriptor = descriptor
        if stat.S_ISCHR(os.fstat(descriptor).st_mode):
            # On /dev/kmsg SEEK_END selects the newest record, so the watcher
            # reads what happens from here rather than replaying the boot log.
            os.lseek(descriptor, 0, os.SEEK_END)
        return None

    def poll(self) -> list[str]:
        """Every line the source produced since the last poll, and the matches."""
        if self._descriptor is None:
            return []
        lines: list[str] = []
        while True:
            try:
                chunk = os.read(self._descriptor, 8192)
            except BlockingIOError:
                break
            except OSError as error:
                if error.errno == errno.EPIPE:
                    # Records were overwritten between reads; the stream
                    # resumes at the newest one.
                    os.lseek(self._descriptor, 0, os.SEEK_END)
                    continue
                self.reason = f"{self.source} stopped answering: {error.strerror}"
                self.close()
                break
            if not chunk:
                break
            self._buffer += chunk
            *complete, self._buffer = self._buffer.split(b"\n")
            lines.extend(entry.decode("utf-8", "replace") for entry in complete)
        return [line for line in lines if HAZARD_PATTERN.search(line)]

    def close(self) -> None:
        if self._descriptor is not None:
            try:
                os.close(self._descriptor)
            except OSError:
                pass
            self._descriptor = None


@dataclass(frozen=True)
class SupervisionPlan:
    """Everything one supervised launch needs, resolved by its caller.

    The policy port builds this from its own launch plan: that one owns the
    argv, the scrubbed environment, and the registry row behind the model id,
    and this one owns what happens to the process that argv becomes.
    """

    argv: tuple[str, ...]
    env: Mapping[str, str]
    cwd: Path
    port: int
    health_path: str
    model_id: str
    deployment: str
    profile: str
    readiness_deadline_s: float
    log_directory: Path | None = None
    cpu_affinity: frozenset[int] | None = None
    niceness: int | None = None
    sample_interval_s: float = SAMPLE_INTERVAL_SECONDS
    health_every_samples: int = HEALTH_EVERY_SAMPLES
    termination_grace_s: float = TERMINATION_GRACE_SECONDS

    @property
    def health_url(self) -> str:
        return f"http://127.0.0.1:{self.port}{self.health_path}"

    @classmethod
    def from_json(cls, payload: Mapping[str, Any]) -> SupervisionPlan:
        affinity = payload.get("cpu_affinity")
        log_directory = payload.get("log_directory")
        return cls(
            argv=tuple(str(entry) for entry in payload["argv"]),
            env={str(key): str(value) for key, value in dict(payload["env"]).items()},
            cwd=Path(str(payload["cwd"])),
            port=int(payload["port"]),
            health_path=str(payload.get("health_path", "/health")),
            model_id=str(payload["model_id"]),
            deployment=str(payload["deployment"]),
            profile=str(payload["profile"]),
            readiness_deadline_s=float(payload["readiness_deadline_s"]),
            log_directory=Path(str(log_directory)) if log_directory else None,
            cpu_affinity=frozenset(int(entry) for entry in affinity) if affinity else None,
            niceness=int(payload["niceness"]) if payload.get("niceness") is not None else None,
            sample_interval_s=float(payload.get("sample_interval_s", SAMPLE_INTERVAL_SECONDS)),
            health_every_samples=int(payload.get("health_every_samples", HEALTH_EVERY_SAMPLES)),
            termination_grace_s=float(
                payload.get("termination_grace_s", TERMINATION_GRACE_SECONDS)
            ),
        )


@dataclass
class _StopRequest:
    """What asked the supervise loop to end, set from a signal or the socket."""

    requested: bool = False
    origin: str = "-"
    lock: threading.Lock = field(default_factory=threading.Lock)

    def raise_flag(self, origin: str) -> None:
        with self.lock:
            if not self.requested:
                self.requested = True
                self.origin = origin


class Supervisor:
    """The owner of one served model: its lease, its record, and its absence."""

    def __init__(
        self,
        paths: RuntimePaths | None = None,
        *,
        hazard_source: Path = DEFAULT_HAZARD_SOURCE,
    ) -> None:
        self.paths = paths or RuntimePaths.resolve()
        self.hazard_source = hazard_source
        self.record = RuntimeRecord(path=self.paths["qwen_home_runtime_state"])
        self.lease = WorkloadLease.in_state_directory(self.paths["qwen_home_state"])
        self._stop = _StopRequest()
        self._control_shutdown = threading.Event()
        self._control_thread: threading.Thread | None = None
        self._control_listener: socket.socket | None = None

    # -- the run ---------------------------------------------------------

    def run(self, plan: SupervisionPlan) -> int:
        """Serve one plan until it stops, and report residue in the exit status.

        The deployment lock is held shared for the whole service, so an
        activation publishing a new `deployment-current` cannot swap the bundle
        under a running server; the supervisor lock is held exclusive, so one
        supervisor owns the runtime root at a time.
        """
        state_directory = self.paths["qwen_home_state"]
        state_directory.mkdir(parents=True, exist_ok=True)
        deployment_lock = self.paths["qwen_home_deployments"] / DEPLOYMENT_LOCK_NAME
        if not deployment_lock.parent.is_dir():
            raise SupervisorRefused(f"no deployment root: {deployment_lock.parent}")

        with ExitStack() as stack:
            stack.enter_context(hold(deployment_lock, exclusive=False, timeout=LOCK_WAIT_SECONDS))
            stack.enter_context(
                hold(
                    self.paths["qwen_home_workload_lock"],
                    exclusive=True,
                    timeout=LOCK_WAIT_SECONDS,
                )
            )
            stack.callback(self._remove_supervisor_pid)
            self._write_supervisor_pid()
            self.lease.arm()
            watcher = KernelHazardWatcher(self.hazard_source)
            skip_reason = watcher.open()
            stack.callback(watcher.close)
            stack.callback(self._stop_control_socket)
            self._start_control_socket()
            stack.enter_context(self._signal_handlers())
            return self._serve(plan, watcher, skip_reason)

    def _serve(
        self, plan: SupervisionPlan, watcher: KernelHazardWatcher, skip_reason: str | None
    ) -> int:
        self.record.transition(
            "starting",
            supervisor_pid=os.getpid(),
            supervisor_pgid=os.getpgid(0),
            supervisor_start_time=read_start_time(os.getpid()) or 0,
            port=plan.port,
            model_id=plan.model_id,
            deployment=plan.deployment,
            profile=plan.profile,
            control_socket=str(self.paths["qwen_home_control_socket"]),
            workload_lease=self.lease.environment_value,
            hazard_source=str(self.hazard_source),
            hazard_skip_reason=skip_reason or "-",
            started_utc=utc_now(),
        )

        logs = plan.log_directory or self.paths["qwen_home_logs"]
        environment = dict(plan.env)
        environment["QWEN_VULKAN_WORKLOAD_LOCK"] = self.lease.environment_value
        owned = spawn(
            plan.argv,
            env=environment,
            cwd=plan.cwd,
            stdout_path=logs / "server.log",
            stderr_path=logs / "server.err",
            cpu_affinity=set(plan.cpu_affinity) if plan.cpu_affinity else None,
            niceness=plan.niceness,
        )
        self.record.transition(
            "starting",
            server_pid=owned.pid,
            server_pgid=owned.pgid,
            server_start_time=owned.start_time,
        )

        readiness = wait_ready(
            plan.health_url,
            deadline_s=plan.readiness_deadline_s,
            interval_s=plan.sample_interval_s,
            must_be_pid=owned.pid,
            must_be_start_time=owned.start_time,
            departed=owned.has_exited,
        )
        if not readiness.ready:
            return self._shut_down(
                plan, owned, primary_failure=f"readiness_refused {readiness.reason}"
            )

        self.record.transition(
            "running",
            listener_inode=readiness.listener.inode if readiness.listener else "-",
        )
        primary_failure = self._supervise(plan, owned, watcher)
        return self._shut_down(plan, owned, primary_failure=primary_failure)

    def _supervise(
        self, plan: SupervisionPlan, owned: Owned, watcher: KernelHazardWatcher
    ) -> str | None:
        """Sample the child every period until something ends the service."""
        samples = 0
        health_failures = 0
        while True:
            if self._stop.requested:
                return None
            if owned.has_exited():
                status = owned.exit_status()
                return f"server_exited status={'-' if status is None else status}"
            hazards = watcher.poll()
            if hazards:
                return f"kernel_hazard {hazards[0][:200]}"
            samples += 1
            if samples % plan.health_every_samples == 0:
                if self._health_answers(plan, owned):
                    health_failures = 0
                else:
                    health_failures += 1
                    if health_failures >= HEALTH_FAILURE_TOLERANCE:
                        return (
                            f"health_unreachable after {health_failures} consecutive samples "
                            f"on port {plan.port}"
                        )
            time.sleep(plan.sample_interval_s)

    def _health_answers(self, plan: SupervisionPlan, owned: Owned) -> bool:
        try:
            probe_listener(plan.port, pid=owned.pid, start_time=owned.start_time)
        except ListenerAbsent:
            return False
        connection = http.client.HTTPConnection("127.0.0.1", plan.port, timeout=5.0)
        try:
            connection.request("GET", plan.health_path)
            response = connection.getresponse()
            body = response.read().decode("utf-8", "replace")
        except OSError:
            return False
        finally:
            connection.close()
        return response.status == 200 and health_is_serving(body)

    # -- the teardown ----------------------------------------------------

    def _shut_down(
        self, plan: SupervisionPlan, owned: Owned, *, primary_failure: str | None
    ) -> int:
        """End the owned group, prove absence, and report residue in the status."""
        self.record.transition("stopping", primary_failure=primary_failure)
        residue: list[str] = []

        termination = terminate(owned, grace_s=plan.termination_grace_s)
        if not termination.absent:
            residue.append(f"server group {owned.pgid} survived SIGKILL ({termination.render()})")
        owned.close()

        try:
            self.lease.require_free("teardown")
        except LeaseBusy as error:
            residue.append(str(error))

        try:
            listener = probe_listener(plan.port)
        except ListenerAbsent:
            pass
        else:
            residue.append(f"port {plan.port} still has a listener: inode {listener.inode}")

        final_state: State = "failed" if primary_failure else "stopped"
        exit_status = 1 if (primary_failure or residue) else 0
        self.record.transition(
            final_state,
            restoration_failures=tuple(residue),
            exit_status=exit_status,
            server_pid=0,
            server_pgid=0,
            server_start_time=0,
            listener_inode="-",
        )
        for detail in residue:
            print(f"teardown residue: {detail}", file=sys.stderr)
        return exit_status

    # -- supervisor identity ---------------------------------------------

    def _write_supervisor_pid(self) -> None:
        """The pid and its start time, the pair a later signal binds to."""
        path = self.paths["qwen_home_supervisor_pid"]
        pid = os.getpid()
        path.write_text(f"{pid}\n{read_start_time(pid) or 0}\n", encoding="ascii")
        os.chmod(path, 0o600)

    def _remove_supervisor_pid(self) -> None:
        self.paths["qwen_home_supervisor_pid"].unlink(missing_ok=True)

    # -- signals ---------------------------------------------------------

    def _signal_handlers(self) -> _SignalHandlers:
        return _SignalHandlers(self._stop)

    # -- the control socket ----------------------------------------------

    def _start_control_socket(self) -> None:
        path = self.paths["qwen_home_control_socket"]
        _clear_stale_socket(path)
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        listener.bind(str(path))
        os.chmod(path, CONTROL_SOCKET_MODE)
        listener.listen(4)
        listener.settimeout(CONTROL_ACCEPT_TIMEOUT_SECONDS)
        self._control_listener = listener
        self._control_thread = threading.Thread(
            target=self._accept_control, name="qwen-apu-control", daemon=True
        )
        self._control_thread.start()

    def _accept_control(self) -> None:
        listener = self._control_listener
        if listener is None:
            return
        while not self._control_shutdown.is_set():
            try:
                connection, _ = listener.accept()
            except TimeoutError:
                continue
            except OSError:
                return
            with connection:
                connection.settimeout(CONTROL_ACCEPT_TIMEOUT_SECONDS * 4)
                try:
                    line = connection.recv(CONTROL_LINE_BYTES).decode("utf-8", "replace").strip()
                    connection.sendall(self._answer_control(line).encode("utf-8"))
                except OSError:
                    continue

    def _answer_control(self, line: str) -> str:
        """`status` answers the record as one JSON line; `stop` ends the service."""
        if line == "status":
            current = self.record.read()
            payload = current.to_json() if current else {"state": "unknown"}
            return json.dumps(payload, sort_keys=True) + "\n"
        if line == "stop":
            self._stop.raise_flag("control-socket")
            return "stopping\n"
        return f"unknown command: {line}\n"

    def _stop_control_socket(self) -> None:
        self._control_shutdown.set()
        if self._control_listener is not None:
            self._control_listener.close()
        if self._control_thread is not None:
            self._control_thread.join(timeout=2.0)
        self.paths["qwen_home_control_socket"].unlink(missing_ok=True)


class _SignalHandlers:
    """SIGTERM and SIGINT as a state transition rather than a process death.

    The previous handlers are restored on exit, so a caller that runs a
    supervisor inside a longer-lived process keeps its own disposition.
    """

    def __init__(self, request: _StopRequest) -> None:
        self._request = request
        self._previous: dict[int, Any] = {}

    def __enter__(self) -> _SignalHandlers:
        for number, origin in ((signal.SIGTERM, "sigterm"), (signal.SIGINT, "sigint")):
            self._previous[number] = signal.getsignal(number)
            signal.signal(number, self._handler(origin))
        return self

    def __exit__(self, *_: object) -> None:
        for number, previous in self._previous.items():
            signal.signal(number, previous)

    def _handler(self, origin: str) -> Any:
        def handle(_number: int, _frame: FrameType | None) -> None:
            self._request.raise_flag(origin)

        return handle


def _clear_stale_socket(path: Path) -> None:
    """Remove a socket leaf no supervisor still answers on.

    A live listener refuses the removal, because a second supervisor binding
    over the first one's path would take its control channel; the exclusive
    supervisor lock is what makes that case a refusal rather than a race.
    """
    if not path.exists():
        return
    if not stat.S_ISSOCK(path.lstat().st_mode):
        raise SupervisorRefused(f"control socket path is not a socket: {path}")
    probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        probe.settimeout(1.0)
        probe.connect(str(path))
    except OSError:
        path.unlink(missing_ok=True)
        return
    finally:
        probe.close()
    raise SupervisorRefused(f"another supervisor answers on the control socket: {path}")


# -- clients ------------------------------------------------------------


def status(paths: RuntimePaths | None = None) -> RuntimeState | None:
    """The published record, read from the file rather than from the socket."""
    resolved = paths or RuntimePaths.resolve()
    return RuntimeRecord(path=resolved["qwen_home_runtime_state"]).read()


def stop(paths: RuntimePaths | None = None, *, timeout_s: float = STOP_WAIT_SECONDS) -> str:
    """Ask the supervisor to stop, through the socket or through its group.

    The socket is the first route because it names one supervisor exactly. Its
    absence falls back to the record, and the fallback signals nothing until
    the recorded start time still matches `/proc/<pid>/stat`: a pid is reused
    once its process exits, and a number alone would signal whatever now holds
    it.
    """
    resolved = paths or RuntimePaths.resolve()
    record = RuntimeRecord(path=resolved["qwen_home_runtime_state"])
    socket_path = resolved["qwen_home_control_socket"]

    if socket_path.exists():
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            client.settimeout(5.0)
            client.connect(str(socket_path))
            client.sendall(b"stop\n")
            client.recv(CONTROL_LINE_BYTES)
        except OSError as error:
            outcome = f"control socket refused the stop: {error}"
        else:
            outcome = "stop requested over the control socket"
            if _await_terminal(record, timeout_s):
                return outcome
            return f"{outcome}; the record stayed non-terminal for {timeout_s:.1f} s"
        finally:
            client.close()
    else:
        outcome = "no control socket"

    current = record.read()
    if current is None:
        return f"{outcome}; no runtime record to signal"
    if current.is_terminal:
        return f"{outcome}; the record already reads {current.state}"
    if current.supervisor_pid <= 0:
        return f"{outcome}; the record names no supervisor pid"
    live = read_start_time(current.supervisor_pid)
    if live != current.supervisor_start_time:
        return (
            f"{outcome}; pid {current.supervisor_pid} carries start time {live} against the "
            f"recorded {current.supervisor_start_time}, so the supervisor is gone and the "
            "pid is left alone"
        )
    group = current.supervisor_pgid or current.supervisor_pid
    try:
        os.killpg(group, signal.SIGTERM)
    except OSError as error:
        return f"{outcome}; signalling group {group} refused: {error}"
    if _await_terminal(record, timeout_s):
        return f"{outcome}; signalled supervisor group {group}"
    return f"{outcome}; signalled supervisor group {group} and the record stayed non-terminal"


def _await_terminal(record: RuntimeRecord, timeout_s: float) -> bool:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        current = record.read()
        if current is not None and current.is_terminal:
            return True
        time.sleep(0.05)
    current = record.read()
    return current is not None and current.is_terminal


def relaunch_detached(
    command: Sequence[str],
    *,
    log_path: Path,
    env: Mapping[str, str] | None = None,
    cwd: Path | None = None,
) -> Owned:
    """Run the same argv again in its own session, with the daemon flag removed.

    The detached copy is a session leader, so the terminal that started it
    closes without reaching it, and no unit file, crontab entry, or login hook
    is involved: the service starts and stops through this call and `stop`.
    """
    return spawn(
        command,
        env=env or dict(os.environ),
        cwd=cwd or Path.cwd(),
        stdout_path=log_path,
        stderr_path=log_path.with_suffix(log_path.suffix + ".err"),
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="qwen-apu-supervisor",
        description="Supervise one llama-server from a launch plan.",
    )
    parser.add_argument("--plan", required=True, type=Path, help="the launch plan as JSON")
    parser.add_argument(
        "--daemon",
        action="store_true",
        help="relaunch this argv in its own session and return its pid",
    )
    parser.add_argument(
        "--hazard-source",
        type=Path,
        default=DEFAULT_HAZARD_SOURCE,
        help="the kernel log the hazard watcher reads",
    )
    arguments = parser.parse_args(list(argv) if argv is not None else None)

    plan = SupervisionPlan.from_json(json.loads(arguments.plan.read_text(encoding="utf-8")))
    paths = RuntimePaths.resolve()
    if arguments.daemon:
        command = [
            sys.executable,
            "-m",
            "qwen_apu.runtime.supervisor",
            "--plan",
            str(arguments.plan),
            "--hazard-source",
            str(arguments.hazard_source),
        ]
        logs = plan.log_directory or paths["qwen_home_logs"]
        owned = relaunch_detached(command, log_path=logs / "supervisor.log")
        print(f"supervisor pid={owned.pid} start_time={owned.start_time}")
        return 0
    return Supervisor(paths, hazard_source=arguments.hazard_source).run(plan)


if __name__ == "__main__":
    raise SystemExit(main())
