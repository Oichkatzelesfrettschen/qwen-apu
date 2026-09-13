"""The operator surface: what it derives, what it waits for, and what it prints.

Four claims are proven without a device. The launch address comes from the
routing table rather than an argument, so a fixture table decides the answer and
a table with no default route refuses the launch instead of guessing an address.
The argv `up` detaches is the one `appliance serve` parses, so a field of
`LaunchDefaults` reaches the flag that carries it. The wait ends on the record
the detached process publishes and passes over the previous run's, which a fake
interpreter writing a record proves end to end. And `down` over an absent record
reports absence rather than failing.
"""

from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

from qwen_apu.runtime import appliance, operator
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.process import read_start_time
from qwen_apu.web import auth as gateway_auth

TREE = Path(__file__).resolve().parents[1]
SH = shutil.which("sh")
SLEEP = shutil.which("sleep")

# One wired and one wireless interface, each publishing a default route, plus a
# route to one subnet. `wlp2s0` carries the lower metric, so the stack routes a
# reply out of it and the derivation reads it.
_ROUTE_HEADER = (
    "Iface\tDestination\tGateway \tFlags\tRefCnt\tUse\tMetric\tMask\t\tMTU\tWindow\tIRTT\n"
)

ROUTE_TABLE = (
    _ROUTE_HEADER
    + """enp7s0\t00000000\t0100000A\t0003\t0\t0\t100\t00000000\t0\t0\t0
wlp2s0\t00000000\t0100000A\t0003\t0\t0\t20\t00000000\t0\t0\t0
enp7s0\t0000000A\t00000000\t0001\t0\t0\t100\t00FFFFFF\t0\t0\t0
"""
)

ROUTE_TABLE_WITHOUT_DEFAULT = (
    _ROUTE_HEADER
    + """enp7s0\t0000000A\t00000000\t0001\t0\t0\t100\t00FFFFFF\t0\t0\t0
"""
)


@pytest.fixture
def root(tmp_path: Path) -> RuntimePaths:
    paths = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    paths.lay_out()
    return paths


def _table(tmp_path: Path, content: str) -> Path:
    table = tmp_path / "route"
    table.write_text(content, encoding="utf-8")
    return table


def test_default_route_reads_the_lower_metric(tmp_path: Path) -> None:
    assert operator.default_route_interface(_table(tmp_path, ROUTE_TABLE)) == "wlp2s0"


def test_a_table_without_a_default_route_derives_nothing(tmp_path: Path) -> None:
    table = _table(tmp_path, ROUTE_TABLE_WITHOUT_DEFAULT)
    assert operator.default_route_interface(table) is None
    assert operator.lan_address(table) is None


def test_an_absent_table_derives_nothing(tmp_path: Path) -> None:
    assert operator.default_route_interface(tmp_path / "absent") is None


def test_local_binds_the_loopback_and_admits_no_network(root: RuntimePaths) -> None:
    defaults = operator.launch_defaults(root, local=True)
    assert defaults.bind_host == "127.0.0.1"
    assert defaults.exposure_mode == "local"
    assert defaults.lan_open is False


def test_a_stated_address_wins_over_the_derivation(root: RuntimePaths) -> None:
    defaults = operator.launch_defaults(root, bind_host="10.0.0.2")
    assert defaults.bind_host == "10.0.0.2"
    assert defaults.exposure_mode == "both"
    assert defaults.lan_open is True


def test_no_default_route_refuses_the_launch(root: RuntimePaths, tmp_path: Path) -> None:
    with pytest.raises(operator.LaunchRefused) as refusal:
        operator.launch_defaults(root, table=_table(tmp_path, ROUTE_TABLE_WITHOUT_DEFAULT))
    assert "--bind-host" in str(refusal.value)
    assert "--local" in str(refusal.value)


def test_the_argv_states_every_derived_field(root: RuntimePaths) -> None:
    defaults = operator.launch_defaults(root, bind_host="10.0.0.2")
    argv = operator.launch_argv(defaults, python="python3")
    assert argv[:5] == ("python3", "-m", "qwen_apu", "appliance", "serve")
    for flag, value in (
        ("--bind-host", "10.0.0.2"),
        ("--gateway-port", str(operator.LANDING_PORT)),
        ("--llama-ui-port", "42072"),
        ("--image-ui-port", "42073"),
        ("--image-profile", operator.DEFAULT_IMAGE_PROFILE),
        ("--file-root", str(root.tree / "docs")),
    ):
        assert argv[argv.index(flag) + 1] == value
    assert "--router" in argv
    assert "--both" in argv
    assert "--lan-open" in argv


def test_no_lan_open_leaves_the_flag_off(root: RuntimePaths) -> None:
    defaults = operator.launch_defaults(root, bind_host="10.0.0.2", lan_open=False)
    assert "--lan-open" not in operator.launch_argv(defaults, python="python3")


def test_a_record_naming_a_departed_supervisor_is_not_live() -> None:
    record = appliance.ApplianceState(
        state="ready", supervisor_pid=os.getpid(), supervisor_start_time=1
    )
    assert operator.live(record) is False
    assert operator.live(None) is False
    live = appliance.ApplianceState(
        state="ready",
        supervisor_pid=os.getpid(),
        supervisor_start_time=read_start_time(os.getpid()) or 0,
    )
    assert operator.live(live) is True


def test_the_report_names_each_surface_and_the_minted_code(root: RuntimePaths) -> None:
    (root["qwen_home_state"] / gateway_auth.PAIRING_CODE_FILENAME).write_text(
        "a-code\n", encoding="utf-8"
    )
    record = appliance.ApplianceState(
        state="ready",
        gateway_origin="http://10.0.0.2:42069",
        llama_ui_origin="http://10.0.0.2:42072",
        image_ui_origin="http://10.0.0.2:42073",
        served_models=("qwen38-2b-distill",),
        deployment="python-prod-32k",
    )
    text = operator.report(record, root)
    assert "home http://10.0.0.2:42069\n" in text
    assert "chat http://10.0.0.2:42072\n" in text
    assert "image http://10.0.0.2:42073\n" in text
    assert "pairing_code=a-code\n" in text
    assert operator.surfaces(record) == (
        "http://10.0.0.2:42069",
        "http://10.0.0.2:42072",
        "http://10.0.0.2:42073",
    )


def test_an_unbound_surface_is_absent_from_the_report(root: RuntimePaths) -> None:
    record = appliance.ApplianceState(state="ready", gateway_origin="http://10.0.0.2:42069")
    text = operator.report(record, root)
    assert "image" not in text
    assert operator.report(None, root) == "appliance=absent\n"


def test_down_over_an_absent_record_reports_absence(root: RuntimePaths) -> None:
    assert operator.down(root) == 0


def _fake_interpreter(tmp_path: Path, state: str, *, log_line: str = "") -> Path:
    """An interpreter that publishes one record and leaves, ignoring its argv.

    `up` detaches an argv whose first word is the interpreter, so a shell script
    in that position exercises the detachment, the record wait, and the report
    without a model, a device, or a listener.
    """
    record = {
        "children": [],
        "deployment": "python-prod-32k",
        "gateway_origin": "http://127.0.0.1:42069",
        "llama_ui_origin": "http://127.0.0.1:42072",
        "image_ui_origin": "http://127.0.0.1:42073",
        "primary_failure": "the fixture states one" if state == "failed" else None,
        "schema": appliance.SCHEMA,
        "served_models": ["qwen38-2b-distill"],
        "state": state,
    }
    payload = json.dumps(record | {"supervisor_pid": 0}, indent=2)
    script = tmp_path / "fake-interpreter"
    script.write_text(
        "#!/bin/sh\nset -eu\n"
        + (f'printf "%s\\n" "{log_line}"\n' if log_line else "")
        + 'record="$QWEN_FAKE_RECORD"\n'
        + f"cat >\"$record\" <<'JSON'\n{payload}\nJSON\n"
        # The record must name this process, which only this process knows, so
        # the pid is substituted into the file the supervisor wait reads.
        + 'sed -i "s/\\"supervisor_pid\\": 0/\\"supervisor_pid\\": $$/" "$record"\n',
        encoding="utf-8",
    )
    script.chmod(script.stat().st_mode | stat.S_IXUSR)
    return script


@pytest.mark.skipif(SH is None, reason="no sh")
def test_up_returns_on_the_record_the_detached_launch_publishes(
    root: RuntimePaths,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv("QWEN_FAKE_RECORD", str(appliance.record_path(root)))
    interpreter = _fake_interpreter(tmp_path, "ready")
    status = operator.up(
        root,
        operator.launch_defaults(root, local=True),
        python=str(interpreter),
        deadline_s=20.0,
        poll_s=0.05,
    )
    captured = capsys.readouterr()
    assert status == 0
    assert "state=ready" in captured.out
    assert "chat http://127.0.0.1:42072" in captured.out


@pytest.mark.skipif(SH is None, reason="no sh")
def test_up_reports_the_launch_log_when_the_record_ends(
    root: RuntimePaths,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv("QWEN_FAKE_RECORD", str(appliance.record_path(root)))
    interpreter = _fake_interpreter(tmp_path, "failed", log_line="preflight refused the deployment")
    status = operator.up(
        root,
        operator.launch_defaults(root, local=True),
        python=str(interpreter),
        deadline_s=20.0,
        poll_s=0.05,
    )
    captured = capsys.readouterr()
    assert status == 1
    assert "primary_failure=the fixture states one" in captured.err
    assert "preflight refused the deployment" in captured.err


def test_the_previous_record_is_passed_over(root: RuntimePaths) -> None:
    """A stopped record from the previous run never ends this run's wait.

    The detached process spends its startup before it publishes anything, so the
    first reads land on that record; a wait that acted on its `stopped` state
    would report a failure while this launch was still starting.
    """
    previous = appliance.ApplianceState(state="stopped", supervisor_pid=424242)
    appliance.ApplianceRecord(path=appliance.record_path(root)).write(previous)
    status = operator._await_ready(
        root,
        superseded_pid=424242,
        log_path=root["qwen_home_logs"] / operator.LOG_NAME,
        deadline_s=0.3,
        poll_s=0.05,
    )
    assert status == 1


@pytest.mark.skipif(SH is None or SLEEP is None, reason="no sh or sleep")
def test_up_reaps_children_a_departed_supervisor_left(
    root: RuntimePaths,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """A record naming live children and no live supervisor is cleared first.

    The children hold the ports the next launch binds, so a launch over them
    fails at bind on a listener this appliance started. `up` ends the recorded
    identities and says which.
    """
    sleeper = subprocess.Popen([SLEEP, "300"], start_new_session=True)
    try:
        child = appliance.ChildRecord(
            name="router",
            pid=sleeper.pid,
            pgid=os.getpgid(sleeper.pid),
            start_time=read_start_time(sleeper.pid) or 0,
            argv0=SLEEP or "sleep",
            port=None,
            socket_path="-",
            state="running",
        )
        record = appliance.ApplianceState(
            state="ready", supervisor_pid=424242, supervisor_start_time=1, children=(child,)
        )
        appliance.ApplianceRecord(path=appliance.record_path(root)).write(record)
        assert operator.residue(record) == ("router",)
        monkeypatch.setenv("QWEN_FAKE_RECORD", str(appliance.record_path(root)))
        interpreter = _fake_interpreter(tmp_path, "ready")
        status = operator.up(
            root,
            operator.launch_defaults(root, local=True),
            python=str(interpreter),
            deadline_s=20.0,
            poll_s=0.05,
        )
        captured = capsys.readouterr()
        assert status == 0
        assert "reaping=router" in captured.out
        assert sleeper.poll() is not None or read_start_time(sleeper.pid) != child.start_time
    finally:
        if sleeper.poll() is None:
            sleeper.kill()
        sleeper.wait()
