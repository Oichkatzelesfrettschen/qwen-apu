"""The operating point the appliance states at every launch.

The part reads a decode as a low-use workload, so a launch that leaves the
choice to the governor serves at the bottom of the engine table. These cover
the table reader, the two targets, and the three answers a launch can give:
pinned, governed with a reason, and absent.
"""

from __future__ import annotations

from pathlib import Path

from qwen_apu.runtime import graphics_state

# The tables this part reports, with the delivered step marked.
ENGINE_TABLE = "0: 200Mhz \n1: 400Mhz *\n2: 1100Mhz \n"
MEMORY_TABLE = "0: 0Mhz \n1: 400Mhz \n2: 933Mhz *\n3: 1067Mhz \n"


def _device(root: Path, *, level: str = "auto") -> Path:
    device = root / "sys/class/drm/card1/device"
    device.mkdir(parents=True)
    (device / graphics_state.LEVEL_ATTRIBUTE).write_text(f"{level}\n", encoding="utf-8")
    (device / graphics_state.ENGINE_ATTRIBUTE).write_text(ENGINE_TABLE, encoding="utf-8")
    (device / graphics_state.MEMORY_ATTRIBUTE).write_text(MEMORY_TABLE, encoding="utf-8")
    return device


def test_the_reader_marks_the_step_the_part_delivers() -> None:
    engine = graphics_state.steps(ENGINE_TABLE)
    assert [step.mhz for step in engine] == [200, 400, 1100]
    delivered = graphics_state.selected(engine)
    assert delivered is not None
    assert (delivered.index, delivered.mhz) == (1, 400)
    assert graphics_state.selected(graphics_state.steps("0: 200Mhz \n")) is None


def test_the_engine_target_is_the_top_step() -> None:
    assert graphics_state.engine_target(graphics_state.steps(ENGINE_TABLE)) == 2
    assert graphics_state.engine_target(()) is None


def test_the_memory_target_stops_below_the_state_the_firmware_selects() -> None:
    """1067 MHz is firmware-selected and refuses a hard minimum, so the
    appliance asks for the highest state the part honors instead."""
    assert graphics_state.memory_target(graphics_state.steps(MEMORY_TABLE)) == 2
    without = "0: 400Mhz \n1: 933Mhz *\n"
    assert graphics_state.memory_target(graphics_state.steps(without)) == 1
    assert graphics_state.memory_target(()) is None


def test_pinning_writes_the_point_and_reports_what_the_part_delivered(
    tmp_path: Path,
) -> None:
    device = _device(tmp_path)
    state = graphics_state.pin(tmp_path)
    assert (device / graphics_state.LEVEL_ATTRIBUTE).read_text().strip() == "manual"
    assert (device / graphics_state.ENGINE_ATTRIBUTE).read_text().strip() == "2"
    assert (device / graphics_state.MEMORY_ATTRIBUTE).read_text().strip() == "2"
    # The fixture's tables do not move when written, so the reported clocks are
    # the ones the tables still mark: the point of the read is that the part
    # answers rather than the write being assumed.
    assert state.pinned is True
    assert state.level == "manual"
    assert state.as_line().startswith("graphics_state=pinned level=manual")


def test_a_device_without_write_access_reports_what_it_serves_at(
    tmp_path: Path,
) -> None:
    """An appliance that refuses to serve because a clock is low helps nobody,
    and one that serves at 400 MHz without saying so is the failure."""
    device = _device(tmp_path)
    for name in graphics_state.CLOCK_ATTRIBUTES:
        (device / name).chmod(0o444)
    try:
        state = graphics_state.pin(tmp_path)
    finally:
        for name in graphics_state.CLOCK_ATTRIBUTES:
            (device / name).chmod(0o644)
    assert state.pinned is False
    line = state.as_line()
    assert line.startswith("graphics_state=governed level=auto sclk_mhz=400 mclk_mhz=933")
    assert "install-amdgpu-clock-access.sh" in line


def test_a_host_carrying_no_amdgpu_device_says_so(tmp_path: Path) -> None:
    assert graphics_state.resolve_device(tmp_path) is None
    assert graphics_state.pin(tmp_path).as_line() == (
        "graphics_state=absent reason=no amdgpu device"
    )


def test_a_device_whose_tables_name_no_step_is_reported_rather_than_written(
    tmp_path: Path,
) -> None:
    device = _device(tmp_path)
    (device / graphics_state.ENGINE_ATTRIBUTE).write_text("", encoding="utf-8")
    state = graphics_state.pin(tmp_path)
    assert state.pinned is False
    assert "name no step" in state.as_line()
    assert (device / graphics_state.LEVEL_ATTRIBUTE).read_text().strip() == "auto"
