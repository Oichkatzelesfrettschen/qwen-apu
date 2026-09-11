"""The application record and the ownership its teardown signals by.

Two claims are proven here without a device. The record is published whole, so
a reader that catches the file mid-transition reads the previous record rather
than a truncated one; and `stop` signals a child only where the recorded pid
still carries the recorded start time, so a number reused after the child left
is untouched. Both use ordinary `sleep` children, since neither claim is about
what a child does.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import threading
import time
from pathlib import Path

import pytest

from qwen_apu.runtime import appliance
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.process import read_start_time

TREE = Path(__file__).resolve().parents[1]
SH = shutil.which("sh")
SLEEP = shutil.which("sleep")

pytestmark = pytest.mark.skipif(SH is None or SLEEP is None, reason="no sh or sleep")


@pytest.fixture
def root(tmp_path: Path) -> RuntimePaths:
    paths = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    paths.lay_out()
    return paths


def _orphan_sleeper(name: str, seconds: str = "300") -> appliance.ChildRecord:
    """One long-running child this test process is not the parent of.

    `qwen-apu appliance stop` runs in a process that started nothing, so a pid
    it signals leaves `/proc` as soon as it exits. A child of the test process
    would instead stay a zombie until the test reaps it, keep its
    `/proc/<pid>/stat`, and read as live through the whole SIGKILL escalation --
    which would measure the harness rather than the teardown. The shell exits
    immediately after backgrounding the sleep, so the sleep is reparented and
    the stop sees the shape production sees.
    """
    launcher = subprocess.Popen(  # noqa: S603
        # The sleep's own descriptors go to the null device: a background
        # child inheriting this pipe holds it open, and `communicate` would
        # then wait for the sleep rather than for the shell.
        [
            str(SH),
            "-c",
            'sleep "$1" >/dev/null 2>&1 </dev/null & printf "%s\\n" "$!"',
            "sh",
            seconds,
        ],
        stdout=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    stdout, _ = launcher.communicate(timeout=10.0)
    pid = int(stdout.strip())
    return appliance.ChildRecord(
        name=name,
        pid=pid,
        pgid=os.getpgid(pid),
        start_time=read_start_time(pid) or 0,
        argv0=str(SLEEP),
    )


# ---------------------------------------------------------------------------
# The record
# ---------------------------------------------------------------------------


def test_the_record_round_trips_every_child(root: RuntimePaths) -> None:
    record = appliance.ApplianceRecord(path=appliance.record_path(root))
    child = appliance.ChildRecord(
        name=appliance.IMAGE_CHILD,
        pid=4242,
        pgid=4242,
        start_time=99,
        argv0="/usr/bin/python3",
        socket_path="/run/image-service.sock",
    )
    written = record.write(
        appliance.ApplianceState(
            state="ready",
            deployment="bundle-fixture",
            router_state="ready",
            served_models=("qwen38-2b-distill",),
            children=(child,),
        )
    )
    read = appliance.ApplianceRecord(path=appliance.record_path(root)).read()
    assert read is not None
    assert read.children == (child,)
    assert read.served_models == ("qwen38-2b-distill",)
    assert read.updated_utc == written.updated_utc
    assert read.schema == appliance.SCHEMA
    assert appliance.record_path(root).stat().st_mode & 0o777 == appliance.RECORD_MODE


def test_every_read_during_a_rewrite_sees_one_whole_record(root: RuntimePaths) -> None:
    """`os.replace` over a same-directory leaf, so no reader meets a partial file.

    A record written with `>` truncates first, and a reader between the
    truncation and the write reads an empty file; that is the defect
    `session.status` carries and the reason the teardown had to recover pids
    before asking for a stop.
    """
    path = appliance.record_path(root)
    record = appliance.ApplianceRecord(path=path)
    record.write(appliance.ApplianceState(state="starting"))
    stop = threading.Event()
    observed: list[str] = []
    failures: list[str] = []

    def read_continuously() -> None:
        while not stop.is_set():
            try:
                payload = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, ValueError) as error:
                failures.append(str(error))
                continue
            observed.append(str(payload["state"]))

    reader = threading.Thread(target=read_continuously)
    reader.start()
    try:
        for index in range(200):
            record.write(
                appliance.ApplianceState(
                    state="ready" if index % 2 else "starting", gateway_port=index
                )
            )
    finally:
        stop.set()
        reader.join(timeout=10.0)
    assert failures == []
    assert set(observed) <= {"starting", "ready"}


# ---------------------------------------------------------------------------
# The teardown
# ---------------------------------------------------------------------------


def test_stop_signals_the_recorded_identities_and_leaves_the_record_stopped(
    root: RuntimePaths,
) -> None:
    first = _orphan_sleeper(appliance.ROUTER_CHILD)
    second = _orphan_sleeper(appliance.IMAGE_CHILD)
    record = appliance.ApplianceRecord(path=appliance.record_path(root))
    record.write(appliance.ApplianceState(state="ready", children=(first, second)))

    signalled = appliance.stop(root)
    assert set(signalled) == {first.pid, second.pid}
    for child in (first, second):
        assert read_start_time(child.pid) != child.start_time
    current = appliance.status(root)
    assert current is not None
    assert current.state == "stopped"
    assert current.children == ()


def test_stop_leaves_a_pid_whose_start_time_moved_alone(root: RuntimePaths) -> None:
    """A number the record names is not an identity; the pair is.

    The recorded start time is deliberately wrong here, which is what a pid
    reused after the child left looks like. The stop reports the mismatch as
    residue and signals nothing.
    """
    live = subprocess.Popen([str(SLEEP), "300"], start_new_session=True)  # noqa: S603
    try:
        actual = read_start_time(live.pid) or 0
        stale = appliance.ChildRecord(
            name=appliance.SEARXNG_CHILD,
            pid=live.pid,
            pgid=live.pid,
            start_time=actual + 1,
            argv0=str(SLEEP),
        )
        record = appliance.ApplianceRecord(path=appliance.record_path(root))
        record.write(appliance.ApplianceState(state="ready", children=(stale,)))
        assert appliance.stop(root) == ()
        # The process this appliance never started is still running.
        assert live.poll() is None
        current = appliance.status(root)
        assert current is not None
        assert any("is left alone" in detail for detail in current.restoration_failures)
    finally:
        live.kill()
        live.wait(timeout=10.0)


def test_stop_on_an_empty_root_signals_nothing(root: RuntimePaths) -> None:
    assert appliance.stop(root) == ()
    assert appliance.status(root) is None


def test_render_states_every_child_and_the_readiness(root: RuntimePaths) -> None:
    child = appliance.ChildRecord(
        name=appliance.SEARXNG_CHILD, pid=7, pgid=7, start_time=11, argv0="x", port=8888
    )
    text = appliance.render(
        appliance.ApplianceState(
            state="ready",
            deployment="bundle-fixture",
            router_state="ready",
            served_models=("qwen38-2b-distill",),
            gateway_origin="http://127.0.0.1:8090",
            children=(child,),
        )
    )
    assert "state=ready\n" in text
    assert "router_state=ready\n" in text
    assert "served_models=qwen38-2b-distill\n" in text
    assert "child name=searxng pid=7 start_time=11 port=8888" in text
    assert appliance.render(None) == "appliance=absent\n"


def test_a_child_spec_carries_an_argv_list_rather_than_a_command_string(
    root: RuntimePaths,
) -> None:
    """Every owned process is spawned from a list, so no shell parses it."""
    image, searxng = appliance.child_specs_from_request(
        root,
        image_service=["python3", "image-service.py", "--state-dir", str(root["qwen_home_state"])],
        searxng=["searxng-launch.sh", "serve", str(root["qwen_home_state"])],
    )
    assert image is not None and searxng is not None
    assert image.argv[0] == "python3"
    assert image.socket_path.endswith("image-service.sock")
    assert searxng.argv[1] == "serve"
    assert all(isinstance(word, str) for word in image.argv + searxng.argv)
    absent_image, absent_searxng = appliance.child_specs_from_request(root)
    assert absent_image is None
    assert absent_searxng is None


def test_the_router_child_runs_the_supervisor_as_this_process_child(root: RuntimePaths) -> None:
    """`--daemon` is absent, so the appliance stays the parent and can signal it."""
    spec = appliance.router_child_spec(root, root["qwen_home_state"] / "launch-plan.json")
    assert spec.name == appliance.ROUTER_CHILD
    assert spec.argv[1:4] == ("-m", "qwen_apu.runtime.supervisor", "--plan")
    assert "--daemon" not in spec.argv


def test_the_record_survives_a_reader_that_arrives_before_any_write(root: RuntimePaths) -> None:
    assert appliance.ApplianceRecord(path=appliance.record_path(root)).read() is None
    appliance.record_path(root).write_text("{not json", encoding="utf-8")
    assert appliance.ApplianceRecord(path=appliance.record_path(root)).read() is None


def test_a_terminated_child_leaves_before_the_grace_expires(root: RuntimePaths) -> None:
    child = _orphan_sleeper(appliance.ROUTER_CHILD)
    record = appliance.ApplianceRecord(path=appliance.record_path(root))
    record.write(appliance.ApplianceState(state="ready", children=(child,)))
    started = time.monotonic()
    appliance.stop(root)
    elapsed = time.monotonic() - started
    # SIGTERM alone ends the child, so the stop returns inside the grace rather
    # than spending it and escalating to SIGKILL.
    assert elapsed < appliance.TERMINATION_GRACE_SECONDS * 2
