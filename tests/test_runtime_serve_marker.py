"""The appliance's serve request carries the authorizer marker; the bare serve leaves it off."""

from __future__ import annotations

from pathlib import Path

from qwen_apu.runtime import appliance, serve
from qwen_apu.runtime import state as runtime_state
from qwen_apu.runtime.paths import RuntimePaths


def test_the_appliance_sets_the_authorizer_marker_and_serve_leaves_it_off() -> None:
    bare = serve.ServeRequest(router=True)
    assert bare.web_authorizer_ready is False
    request = appliance.ApplianceRequest(serve=bare)
    owner = appliance.Appliance.__new__(appliance.Appliance)
    owner.request = request  # type: ignore[misc]
    assert owner._serve_request().web_authorizer_ready is True
    assert owner._serve_request().router is True


def test_the_appliance_passes_over_the_previous_runs_terminal_record(tmp_path: Path) -> None:
    paths = RuntimePaths(tree=Path(__file__).resolve().parents[1], root=tmp_path / "root")
    paths.lay_out()
    record = paths["qwen_home_runtime_state"]
    stale = runtime_state.RuntimeState(state="stopped", supervisor_pid=4242, exit_status=0)
    runtime_state.RuntimeRecord(record).write(stale)
    owner = appliance.Appliance(paths, appliance.ApplianceRequest())
    assert owner._superseded_pid == 4242
    assert owner._router_record() is None
    fresh = runtime_state.RuntimeState(state="ready", supervisor_pid=4243)
    runtime_state.RuntimeRecord(record).write(fresh)
    current = owner._router_record()
    assert current is not None and current.supervisor_pid == 4243
