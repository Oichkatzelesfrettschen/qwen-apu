"""The supervisor against the fixture server the shell guard tests use.

Every arm waits on the event it tests and names the deadline that bounds it,
the discipline `remote/test-qwen-runtime-guards.sh` states: fixture readiness
carries no claim about the appliance and takes
QWEN_GUARD_FIXTURE_DEADLINE_S, while the interval from a condition arriving to
the supervisor acting on it is the property under test and takes
QWEN_GUARD_OBSERVATION_DEADLINE_S. A failure prints which deadline expired,
the load average, and the elapsed time.

Loopback ports come from `remote/test-port-lease.sh`, which holds an exclusive
flock on each port's lease file for the fixture's whole life. Binding port zero
and closing the socket reports a number that was free at the instant of the
read and reserves nothing afterwards, so two gate cells would receive the same
number and the second listener would meet EADDRINUSE.
"""

from __future__ import annotations

import fcntl
import json
import os
import shutil
import signal
import socket
import subprocess
import time
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Any

import pytest

from qwen_apu.runtime import state as state_module
from qwen_apu.runtime.health import ListenerAbsent, ReadinessRefused, probe_listener, wait_ready
from qwen_apu.runtime.locks import LockTimeout, WorkloadLease, hold
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.process import Owned, read_start_time, spawn, terminate
from qwen_apu.runtime.state import RuntimeRecord, RuntimeState
from qwen_apu.runtime.supervisor import (
    HAZARD_PATTERN,
    KernelHazardWatcher,
    status,
    stop,
)

TREE = Path(__file__).resolve().parents[1]
FAKE_SERVER = TREE / "remote" / "test-fixtures" / "fake-llama-server.sh"
PORT_LEASE = TREE / "remote" / "test-port-lease.sh"
SH = shutil.which("sh")
PYTHON = shutil.which("python3") or "python3"

FIXTURE_DEADLINE_SECONDS = float(os.environ.get("QWEN_GUARD_FIXTURE_DEADLINE_S", "60"))
OBSERVATION_DEADLINE_SECONDS = float(os.environ.get("QWEN_GUARD_OBSERVATION_DEADLINE_S", "30"))

shell_required = pytest.mark.skipif(SH is None, reason="no /bin/sh")


def await_condition[Value](
    deadline_name: str,
    limit_seconds: float,
    predicate: Callable[[], Value | None],
    detail: str,
) -> Value:
    """Poll until the predicate answers, then fail naming the expired deadline."""
    started = time.monotonic()
    while True:
        answer = predicate()
        if answer:
            return answer
        elapsed = time.monotonic() - started
        if elapsed >= limit_seconds:
            pytest.fail(
                f"guard test failure deadline={deadline_name} "
                f"limit_seconds={limit_seconds} elapsed_seconds={elapsed:.3f} "
                f"loadavg={os.getloadavg()} detail={detail}"
            )
        time.sleep(0.05)


@pytest.fixture
def leased_port(tmp_path: Path) -> Iterator[int]:
    """One loopback port, held by the lease holder until this fixture releases."""
    if SH is None:
        pytest.skip("no /bin/sh")
    ports_file = tmp_path / "ports.txt"
    # The claim backgrounds a holder that outlives the command and inherits
    # its stderr, so capturing that descriptor would block this read until the
    # holder itself exits. stdout carries the holder pid and closes with the
    # claim; stderr goes to the null device the way the shell leaves it to the
    # caller's own.
    claim = subprocess.run(
        [SH, str(PORT_LEASE), "claim", "1", str(ports_file)],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=True,
    )
    holder = claim.stdout.strip()
    try:
        yield int(ports_file.read_text(encoding="ascii").split()[0])
    finally:
        subprocess.run(
            [SH, str(PORT_LEASE), "release", holder],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )


@pytest.fixture
def runtime_root(tmp_path: Path) -> RuntimePaths:
    paths = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    paths.lay_out()
    return paths


def fake_server_environment(port: int | None, record: Path) -> dict[str, str]:
    environment = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "QWEN_POLICY_TEST_OUTPUT": str(record),
    }
    if port is not None:
        environment["QWEN_FAKE_SERVER_PORT"] = str(port)
    return environment


def plan_payload(
    paths: RuntimePaths, port: int, record: Path, *, serve: bool = True, **overrides: Any
) -> str:
    """The plan one launch runs. `serve=False` withholds the fixture's port, so
    the child records its argv and exits rather than listening."""
    payload: dict[str, Any] = {
        "argv": [str(FAKE_SERVER)],
        "env": fake_server_environment(port if serve else None, record),
        "cwd": str(TREE),
        "port": port,
        "health_path": "/health",
        "model_id": "qwen38-2b-distill",
        "deployment": "bundle-fixture",
        "profile": "low-async",
        "readiness_deadline_s": FIXTURE_DEADLINE_SECONDS,
        "log_directory": str(paths["qwen_home_logs"]),
        "sample_interval_s": 0.1,
        "health_every_samples": 5,
        "termination_grace_s": 2.0,
    }
    payload.update(overrides)
    return json.dumps(payload)


def launch_supervisor(
    paths: RuntimePaths, tmp_path: Path, plan_text: str, hazard_source: Path
) -> subprocess.Popen[bytes]:
    plan_path = tmp_path / "plan.json"
    plan_path.write_text(plan_text, encoding="utf-8")
    environment = dict(os.environ)
    environment["QWEN_HOME"] = str(paths.root)
    environment["QWEN_TREE_ROOT"] = str(TREE)
    environment["PYTHONPATH"] = str(TREE / "src")
    return subprocess.Popen(
        [
            PYTHON,
            "-m",
            "qwen_apu.runtime.supervisor",
            "--plan",
            str(plan_path),
            "--hazard-source",
            str(hazard_source),
        ],
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def await_state(paths: RuntimePaths, wanted: str, deadline_name: str, limit: float) -> RuntimeState:
    record = RuntimeRecord(path=paths["qwen_home_runtime_state"])

    def read() -> RuntimeState | None:
        current = record.read()
        if current is not None and current.state == wanted:
            return current
        return None

    return await_condition(deadline_name, limit, read, f"runtime.json never reached {wanted}")


def require_clean_departure(paths: RuntimePaths, port: int) -> None:
    """The absence proof: lease free, control socket gone, pid file gone, port free."""
    assert WorkloadLease.in_state_directory(paths["qwen_home_state"]).is_free()
    assert not paths["qwen_home_control_socket"].exists()
    assert not paths["qwen_home_supervisor_pid"].exists()
    with pytest.raises(ListenerAbsent):
        probe_listener(port)


# -- locks ---------------------------------------------------------------


def test_hold_refuses_a_second_exclusive_holder(tmp_path: Path) -> None:
    lock = tmp_path / "workload.lock"
    with hold(lock, exclusive=True, timeout=0.0):
        with pytest.raises(LockTimeout):
            with hold(lock, exclusive=True, timeout=0.2):
                pytest.fail("a second exclusive holder acquired a held lock")
    with hold(lock, exclusive=True, timeout=0.0) as descriptor:
        assert descriptor >= 0


def test_hold_admits_two_shared_holders(tmp_path: Path) -> None:
    lock = tmp_path / "activate.lock"
    with hold(lock, exclusive=False, timeout=0.0), hold(lock, exclusive=False, timeout=0.0):
        pass


def test_lease_reports_a_held_lease_and_a_free_one(tmp_path: Path) -> None:
    lease = WorkloadLease.in_state_directory(tmp_path)
    assert lease.is_free()
    lease.arm()
    assert lease.path.exists()
    assert lease.path.stat().st_mode & 0o777 == 0o644
    assert lease.is_free()
    descriptor = os.open(lease.path, os.O_RDWR)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert not lease.is_free()
    finally:
        os.close(descriptor)
    assert lease.is_free()


# -- process ownership ---------------------------------------------------


@shell_required
def test_spawn_records_identity_and_terminate_proves_absence(tmp_path: Path) -> None:
    owned = spawn(
        [str(FAKE_SERVER)],
        env=fake_server_environment(None, tmp_path / "argv.txt"),
        cwd=TREE,
        stdout_path=tmp_path / "out.log",
        stderr_path=tmp_path / "err.log",
    )
    assert owned.pgid == owned.pid
    assert owned.start_time == read_start_time(owned.pid)
    termination = terminate(owned, grace_s=2.0)
    assert termination.absent
    assert not owned.is_same_process()
    owned.close()


def test_terminate_leaves_a_pid_whose_start_time_moved_alone() -> None:
    """A recorded pid that now carries another start time is signalled by nothing."""
    moved_start_time = (read_start_time(os.getpid()) or 0) + 1
    live = Owned(pid=os.getpid(), pgid=os.getpgid(0), start_time=moved_start_time)
    assert not live.is_same_process()
    termination = terminate(live, grace_s=0.1)
    assert termination.signalled == "none"
    assert termination.absent


# -- health --------------------------------------------------------------


@shell_required
def test_wait_ready_binds_readiness_to_the_launched_listener(
    tmp_path: Path, leased_port: int
) -> None:
    owned = spawn(
        [str(FAKE_SERVER)],
        env=fake_server_environment(leased_port, tmp_path / "argv.txt"),
        cwd=TREE,
        stdout_path=tmp_path / "out.log",
        stderr_path=tmp_path / "err.log",
    )
    try:
        readiness = wait_ready(
            f"http://127.0.0.1:{leased_port}/health",
            deadline_s=FIXTURE_DEADLINE_SECONDS,
            interval_s=0.1,
            must_be_pid=owned.pid,
            must_be_start_time=owned.start_time,
        )
        assert readiness.ready, readiness.render()
        assert readiness.listener is not None
        assert readiness.listener.pid == owned.pid
        assert readiness.listener.inode.isdigit()

        # A foreign pid owns none of that listener's socket inodes, so the same
        # answering port refuses the binding.
        with pytest.raises(ListenerAbsent):
            probe_listener(leased_port, pid=os.getpid(), start_time=read_start_time(os.getpid()))
    finally:
        terminate(owned, grace_s=2.0)
        owned.close()


def test_wait_ready_refuses_a_non_loopback_url() -> None:
    with pytest.raises(ReadinessRefused):
        wait_ready("http://192.0.2.1:8080/health", deadline_s=0.1)


# -- the record ----------------------------------------------------------


def test_record_keeps_the_primary_failure_and_appends_restoration_failures(
    tmp_path: Path,
) -> None:
    record = RuntimeRecord(path=tmp_path / "runtime.json")
    record.transition("starting", port=8080, model_id="qwen38-2b-distill")
    record.transition("running", listener_inode="4242")
    record.transition("stopping", primary_failure="server_exited status=1")
    final = record.transition("failed", primary_failure="vulkan workload lease is still held")
    assert final.primary_failure == "server_exited status=1"
    assert final.restoration_failures == ("vulkan workload lease is still held",)
    assert final.port == 8080
    assert final.model_id == "qwen38-2b-distill"
    reread = state_module.read(tmp_path / "runtime.json")
    assert reread == final


def test_record_replaces_rather_than_truncates(tmp_path: Path) -> None:
    """Every published record parses whole; no reader meets a half-written file."""
    path = tmp_path / "runtime.json"
    record = RuntimeRecord(path=path)
    for index in range(20):
        record.transition("running", port=index)
        assert json.loads(path.read_text(encoding="utf-8"))["port"] == index
    assert list(path.parent.glob(".runtime.json.*")) == []


# -- the kernel hazard watcher ------------------------------------------


@pytest.mark.parametrize(
    "line",
    [
        "amdgpu: ring gfx_0.0.0 timeout, signaled seq=12",
        "[drm] GPU reset begin!",
        "amdgpu 0000:04:00.0: amdgpu: GPU reset succeeded",
        "amdgpu: [gfxhub0] no-retry page fault, VM fault",
        "radv: device lost",
        "Out of memory: Killed process 4242 (llama-server)",
        "oom-kill:constraint=CONSTRAINT_NONE",
    ],
)
def test_hazard_pattern_matches_the_shell_signature_set(line: str) -> None:
    assert HAZARD_PATTERN.search(line) is not None


def test_hazard_watcher_reads_new_lines_from_a_file_source(tmp_path: Path) -> None:
    source = tmp_path / "kernel.log"
    source.write_text("amdgpu: ring gfx_0.0.0 timeout\n", encoding="utf-8")
    watcher = KernelHazardWatcher(source)
    assert watcher.open() is None
    assert watcher.poll() == ["amdgpu: ring gfx_0.0.0 timeout"]
    assert watcher.poll() == []
    with source.open("a", encoding="utf-8") as handle:
        handle.write("nothing of interest\n[drm] GPU reset begin!\n")
    assert watcher.poll() == ["[drm] GPU reset begin!"]
    watcher.close()


def test_hazard_watcher_records_the_reason_an_unreadable_source_is_skipped(
    tmp_path: Path,
) -> None:
    watcher = KernelHazardWatcher(tmp_path / "absent-kmsg")
    reason = watcher.open()
    assert reason is not None
    assert "unreadable" in reason
    assert watcher.poll() == []


# -- the supervisor ------------------------------------------------------


@shell_required
def test_supervisor_serves_then_stops_on_sigterm_with_no_residue(
    tmp_path: Path, runtime_root: RuntimePaths, leased_port: int
) -> None:
    hazard_source = tmp_path / "kernel.log"
    hazard_source.write_text("", encoding="utf-8")
    supervisor = launch_supervisor(
        runtime_root,
        tmp_path,
        plan_payload(runtime_root, leased_port, tmp_path / "argv.txt"),
        hazard_source,
    )
    try:
        running = await_state(runtime_root, "running", "guard_ready", FIXTURE_DEADLINE_SECONDS)
        assert running.port == leased_port
        assert running.model_id == "qwen38-2b-distill"
        assert running.deployment == "bundle-fixture"
        assert running.profile == "low-async"
        assert running.server_pid > 0
        assert running.server_pgid == running.server_pid
        assert running.server_start_time == read_start_time(running.server_pid)
        assert running.listener_inode.isdigit()
        assert running.hazard_skip_reason == "-"
        assert running.primary_failure is None
        assert runtime_root["qwen_home_supervisor_pid"].is_file()
        assert runtime_root["qwen_home_control_socket"].exists()
        # The lease is the child's while it serves: the supervisor armed the
        # file, named it, and holds nothing on it.
        assert WorkloadLease.in_state_directory(runtime_root["qwen_home_state"]).is_free()
        assert running.workload_lease.endswith("vulkan-workload.lock")

        supervisor.send_signal(signal.SIGTERM)
        assert supervisor.wait(timeout=OBSERVATION_DEADLINE_SECONDS) == 0
    finally:
        supervisor.kill()
    stopped = await_state(
        runtime_root, "stopped", "guard_observation", OBSERVATION_DEADLINE_SECONDS
    )
    assert stopped.exit_status == 0
    assert stopped.primary_failure is None
    assert stopped.restoration_failures == ()
    require_clean_departure(runtime_root, leased_port)


@shell_required
def test_supervisor_stops_over_the_control_socket(
    tmp_path: Path, runtime_root: RuntimePaths, leased_port: int
) -> None:
    hazard_source = tmp_path / "kernel.log"
    hazard_source.write_text("", encoding="utf-8")
    supervisor = launch_supervisor(
        runtime_root,
        tmp_path,
        plan_payload(runtime_root, leased_port, tmp_path / "argv.txt"),
        hazard_source,
    )
    try:
        await_state(runtime_root, "running", "guard_ready", FIXTURE_DEADLINE_SECONDS)

        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.settimeout(5.0)
        client.connect(str(runtime_root["qwen_home_control_socket"]))
        client.sendall(b"status\n")
        answer = json.loads(client.recv(65536).decode("utf-8"))
        client.close()
        assert answer["state"] == "running"
        assert answer["port"] == leased_port

        outcome = stop(runtime_root, timeout_s=OBSERVATION_DEADLINE_SECONDS)
        assert "control socket" in outcome
        assert supervisor.wait(timeout=OBSERVATION_DEADLINE_SECONDS) == 0
    finally:
        supervisor.kill()
    assert status(runtime_root) is not None
    stopped = await_state(
        runtime_root, "stopped", "guard_observation", OBSERVATION_DEADLINE_SECONDS
    )
    assert stopped.exit_status == 0
    require_clean_departure(runtime_root, leased_port)


@shell_required
def test_supervisor_reports_a_child_crash_as_failed_and_keeps_the_primary_failure(
    tmp_path: Path, runtime_root: RuntimePaths, leased_port: int
) -> None:
    hazard_source = tmp_path / "kernel.log"
    hazard_source.write_text("", encoding="utf-8")
    supervisor = launch_supervisor(
        runtime_root,
        tmp_path,
        plan_payload(runtime_root, leased_port, tmp_path / "argv.txt"),
        hazard_source,
    )
    try:
        running = await_state(runtime_root, "running", "guard_ready", FIXTURE_DEADLINE_SECONDS)
        os.kill(running.server_pid, signal.SIGKILL)
        assert supervisor.wait(timeout=OBSERVATION_DEADLINE_SECONDS) == 1
    finally:
        supervisor.kill()
    failed = await_state(runtime_root, "failed", "guard_observation", OBSERVATION_DEADLINE_SECONDS)
    assert failed.primary_failure is not None
    assert failed.primary_failure.startswith("server_exited")
    assert failed.restoration_failures == ()
    assert failed.exit_status == 1
    require_clean_departure(runtime_root, leased_port)


@shell_required
def test_supervisor_releases_the_lease_when_readiness_refuses(
    tmp_path: Path, runtime_root: RuntimePaths, leased_port: int
) -> None:
    """A child that records its argv and exits never reaches readiness."""
    hazard_source = tmp_path / "kernel.log"
    hazard_source.write_text("", encoding="utf-8")
    plan = plan_payload(
        runtime_root,
        leased_port,
        tmp_path / "argv.txt",
        serve=False,
        readiness_deadline_s=OBSERVATION_DEADLINE_SECONDS,
    )
    supervisor = launch_supervisor(runtime_root, tmp_path, plan, hazard_source)
    try:
        assert supervisor.wait(timeout=FIXTURE_DEADLINE_SECONDS) == 1
    finally:
        supervisor.kill()
    failed = await_state(runtime_root, "failed", "guard_observation", OBSERVATION_DEADLINE_SECONDS)
    assert failed.primary_failure is not None
    assert failed.primary_failure.startswith("readiness_refused")
    require_clean_departure(runtime_root, leased_port)


def test_stop_leaves_a_supervisor_pid_whose_start_time_moved_alone(
    runtime_root: RuntimePaths,
) -> None:
    """A reused pid is reported and signalled by nothing.

    The record names this very test process with a start time it never had, so
    a stop that signalled the number alone would end the test run; the
    comparison against `/proc/<pid>/stat` is what keeps it alive.
    """
    record = RuntimeRecord(path=runtime_root["qwen_home_runtime_state"])
    record.write(
        RuntimeState(
            state="running",
            supervisor_pid=os.getpid(),
            supervisor_pgid=os.getpgid(0),
            supervisor_start_time=(read_start_time(os.getpid()) or 0) + 1,
            port=1,
        )
    )
    outcome = stop(runtime_root, timeout_s=0.5)
    assert "left alone" in outcome
    assert os.getpid() > 0
    assert record.read() is not None
    assert (record.read() or RuntimeState(state="failed")).state == "running"


def test_stop_reports_an_empty_root(runtime_root: RuntimePaths) -> None:
    outcome = stop(runtime_root, timeout_s=0.1)
    assert "no runtime record" in outcome


@shell_required
def test_supervisor_stops_during_the_load_without_waiting_out_the_deadline(
    tmp_path: Path, runtime_root: RuntimePaths, leased_port: int
) -> None:
    """A stop arriving before readiness ends the launch at once, and cleanly.

    The appliance holds the readiness loop for up to 120 s on a model load, so
    a stop the loop cannot read waits out that whole interval. The child here
    lives and binds nothing, which is that wait exactly: it neither becomes
    ready nor departs, so the stop flag is the only thing that can end the
    loop. The outcome is `stopped` rather than a readiness failure, because
    the operator caused it.
    """
    hazard_source = tmp_path / "kernel.log"
    hazard_source.write_text("", encoding="utf-8")
    plan = plan_payload(
        runtime_root,
        leased_port,
        tmp_path / "argv.txt",
        serve=False,
        argv=[SH, "-c", "sleep 300"],
        readiness_deadline_s=FIXTURE_DEADLINE_SECONDS,
    )
    supervisor = launch_supervisor(runtime_root, tmp_path, plan, hazard_source)
    try:
        await_condition(
            "guard_ready",
            FIXTURE_DEADLINE_SECONDS,
            lambda: RuntimeRecord(path=runtime_root["qwen_home_runtime_state"]).read(),
            "runtime.json never appeared",
        )
        started = time.monotonic()
        supervisor.send_signal(signal.SIGTERM)
        assert supervisor.wait(timeout=OBSERVATION_DEADLINE_SECONDS) == 0
        elapsed = time.monotonic() - started
    finally:
        supervisor.kill()
    assert elapsed < OBSERVATION_DEADLINE_SECONDS / 2, (
        f"the stop waited {elapsed:.3f} s of a {OBSERVATION_DEADLINE_SECONDS:.0f} s "
        f"readiness deadline; loadavg={os.getloadavg()}"
    )
    stopped = await_state(
        runtime_root, "stopped", "guard_observation", OBSERVATION_DEADLINE_SECONDS
    )
    assert stopped.primary_failure is None
    assert stopped.exit_status == 0
    require_clean_departure(runtime_root, leased_port)


@shell_required
def test_supervisor_reports_a_held_lease_as_residue_and_exits_non_zero(
    tmp_path: Path, runtime_root: RuntimePaths, leased_port: int
) -> None:
    """A lease held past the departure proof is residue, and residue is the status.

    This test takes the lease itself, because the fixture server never does:
    without a holder the free-lease assertion elsewhere observes a file nobody
    ever locked, and `qwen-teardown.sh`'s rule that a caller cannot mistake a
    partial stop for a clean one goes untested.
    """
    hazard_source = tmp_path / "kernel.log"
    hazard_source.write_text("", encoding="utf-8")
    supervisor = launch_supervisor(
        runtime_root,
        tmp_path,
        plan_payload(runtime_root, leased_port, tmp_path / "argv.txt"),
        hazard_source,
    )
    lease = WorkloadLease.in_state_directory(runtime_root["qwen_home_state"])
    descriptor: int | None = None
    try:
        await_state(runtime_root, "running", "guard_ready", FIXTURE_DEADLINE_SECONDS)
        descriptor = os.open(lease.path, os.O_RDWR)
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        supervisor.send_signal(signal.SIGTERM)
        assert supervisor.wait(timeout=OBSERVATION_DEADLINE_SECONDS) == 1
    finally:
        supervisor.kill()
        if descriptor is not None:
            os.close(descriptor)
    stopped = await_state(
        runtime_root, "stopped", "guard_observation", OBSERVATION_DEADLINE_SECONDS
    )
    assert stopped.primary_failure is None
    assert stopped.exit_status == 1
    assert len(stopped.restoration_failures) == 1
    assert "vulkan workload lease is still held" in stopped.restoration_failures[0]
    assert not paths_listener_present(leased_port)


def paths_listener_present(port: int) -> bool:
    try:
        probe_listener(port)
    except ListenerAbsent:
        return False
    return True


@shell_required
def test_supervisor_daemonizes_into_its_own_session_and_stops_over_the_socket(
    tmp_path: Path, runtime_root: RuntimePaths, leased_port: int
) -> None:
    """`--daemon` returns once the detached copy exists; the record reports service.

    The detached copy is a session leader, so the launcher's own exit leaves it
    serving and `stop` is the only route back to it.
    """
    hazard_source = tmp_path / "kernel.log"
    hazard_source.write_text("", encoding="utf-8")
    plan_path = tmp_path / "plan.json"
    plan_path.write_text(
        plan_payload(runtime_root, leased_port, tmp_path / "argv.txt"), encoding="utf-8"
    )
    environment = dict(os.environ)
    environment["QWEN_HOME"] = str(runtime_root.root)
    environment["QWEN_TREE_ROOT"] = str(TREE)
    environment["PYTHONPATH"] = str(TREE / "src")
    launcher = subprocess.run(
        [
            PYTHON,
            "-m",
            "qwen_apu.runtime.supervisor",
            "--plan",
            str(plan_path),
            "--daemon",
            "--hazard-source",
            str(hazard_source),
        ],
        env=environment,
        # The detached copy writes to its own log files rather than to these
        # pipes, so capturing them ends with the launcher rather than with the
        # supervisor it started.
        capture_output=True,
        text=True,
        check=True,
        timeout=FIXTURE_DEADLINE_SECONDS,
    )
    assert launcher.stdout.startswith("supervisor pid=")
    daemon_pid = int(launcher.stdout.split("pid=")[1].split()[0])
    try:
        running = await_state(runtime_root, "running", "guard_ready", FIXTURE_DEADLINE_SECONDS)
        assert running.supervisor_pid == daemon_pid
        # A session leader's process group is its own pid, so the terminal that
        # started it reaches nothing.
        assert running.supervisor_pgid == daemon_pid
        assert os.getpgid(daemon_pid) == daemon_pid

        outcome = stop(runtime_root, timeout_s=OBSERVATION_DEADLINE_SECONDS)
        assert "control socket" in outcome
        await_condition(
            "guard_observation",
            OBSERVATION_DEADLINE_SECONDS,
            lambda: read_start_time(daemon_pid) is None,
            f"detached supervisor {daemon_pid} never left",
        )
    finally:
        if read_start_time(daemon_pid) is not None:
            os.kill(daemon_pid, signal.SIGKILL)
    stopped = await_state(
        runtime_root, "stopped", "guard_observation", OBSERVATION_DEADLINE_SECONDS
    )
    assert stopped.exit_status == 0
    require_clean_departure(runtime_root, leased_port)


@shell_required
def test_supervisor_names_the_workload_lease_to_the_child(
    tmp_path: Path, runtime_root: RuntimePaths, leased_port: int
) -> None:
    """QWEN_VULKAN_WORKLOAD_LOCK crosses into the child's own environment.

    The patched llama-server reads that name and fails its init() where the
    path cannot be opened, so the value reaching the child is what arms the
    lease at all. The child here prints the name it received and exits, which
    refuses readiness; the record's failure is expected and the printed value
    is the claim under test.
    """
    hazard_source = tmp_path / "kernel.log"
    hazard_source.write_text("", encoding="utf-8")
    captured = tmp_path / "child-lease.txt"
    plan = plan_payload(
        runtime_root,
        leased_port,
        tmp_path / "argv.txt",
        serve=False,
        argv=[SH, "-c", 'printenv QWEN_VULKAN_WORKLOAD_LOCK > "$1"', "sh", str(captured)],
        readiness_deadline_s=5.0,
    )
    supervisor = launch_supervisor(runtime_root, tmp_path, plan, hazard_source)
    try:
        assert supervisor.wait(timeout=FIXTURE_DEADLINE_SECONDS) == 1
    finally:
        supervisor.kill()
    lease = WorkloadLease.in_state_directory(runtime_root["qwen_home_state"])
    assert captured.read_text(encoding="utf-8").strip() == lease.environment_value
    assert lease.path.is_file()


def test_hazard_watcher_treats_a_stream_that_ended_as_uncovered(tmp_path: Path) -> None:
    """A source that stops answering disarms the watcher and records the reason.

    `watch-qwen-kernel-hazards.sh` signals the server where its reader ends
    while the server runs, so the supervise loop reads the same condition as
    terminal rather than as an empty poll.
    """
    source = tmp_path / "kernel.log"
    source.write_text("", encoding="utf-8")
    watcher = KernelHazardWatcher(source)
    assert watcher.open() is None
    assert watcher.armed
    descriptor = watcher.descriptor
    assert descriptor is not None
    os.close(descriptor)
    assert watcher.poll() == []
    assert not watcher.armed
    assert watcher.reason is not None
    assert "stopped answering" in watcher.reason
