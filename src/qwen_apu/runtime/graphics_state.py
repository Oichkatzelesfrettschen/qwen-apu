"""The operating point the appliance serves at, stated rather than inferred.

`power_dpm_force_performance_level` decides which engine and fabric steps the
SMU10 part selects, and `auto` hands that choice to the firmware, which reads a
decode as a low-use workload: measured on this part on 2026-09-12 it selected
400 MHz of an 1100 MHz engine table while a 2B checkpoint decoded at 4.16
tok/s, against the 9.46 tok/s `docs/doctrine/hardware-and-measurement.md`
records for the same checkpoint at the forced point. Utilization cannot tell
the part that a decode is latency-bound rather than idle, so the appliance
states the point at every launch.

The point is the top engine index with memory at 933 MHz. The 1067 MHz memory
state is firmware-selected and refuses a hard minimum, and the `high` and
`profile_peak` modes pin the engine at 1100 MHz while dropping delivered fabric
to 400 MHz, which decodes the 2B at 6 to 7 tok/s; both are why the levels are
written directly rather than a performance mode named.

`remote/install-amdgpu-clock-access.sh` installs the udev rule that hands these
three attributes to the `video` group, after which every write here needs no
privilege. That install is the one privileged step and it stays in the shell
surface, because this package names no sudo. A launch without that rule
reports the state it is serving at and carries on: serving slowly is a worse
answer than not serving, and a silent 400 MHz is worse than either.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path

DRM_GLOB = "/sys/class/drm/card*/device"
LEVEL_ATTRIBUTE = "power_dpm_force_performance_level"
ENGINE_ATTRIBUTE = "pp_dpm_sclk"
MEMORY_ATTRIBUTE = "pp_dpm_mclk"
CLOCK_ATTRIBUTES = (LEVEL_ATTRIBUTE, ENGINE_ATTRIBUTE, MEMORY_ATTRIBUTE)
FORCED_LEVEL = "manual"
# The memory state the firmware selects for itself and refuses to hold, so the
# highest state this appliance asks for is the one below it.
FIRMWARE_SELECTED_MEMORY_MHZ = 1067
_STEP = re.compile(r"^(?P<index>\d+): (?P<mhz>\d+)Mhz(?P<selected> \*)?\s*$")


@dataclass(frozen=True)
class ClockStep:
    index: int
    mhz: int
    selected: bool


@dataclass(frozen=True)
class GraphicsState:
    """What the part reports about the point it is running at."""

    device: Path | None
    level: str = ""
    engine_mhz: int = 0
    memory_mhz: int = 0
    pinned: bool = False
    reason: str = ""

    def as_line(self) -> str:
        if self.device is None:
            return f"graphics_state=absent reason={self.reason or 'no amdgpu device'}"
        state = "pinned" if self.pinned else "governed"
        line = (
            f"graphics_state={state} level={self.level or '-'} "
            f"sclk_mhz={self.engine_mhz} mclk_mhz={self.memory_mhz}"
        )
        return f"{line} reason={self.reason}" if self.reason else line


def steps(text: str) -> tuple[ClockStep, ...]:
    """Every step one `pp_dpm_*` table names, with the delivered one marked."""
    parsed: list[ClockStep] = []
    for line in text.splitlines():
        matched = _STEP.match(line)
        if matched is not None:
            parsed.append(
                ClockStep(
                    index=int(matched.group("index")),
                    mhz=int(matched.group("mhz")),
                    selected=matched.group("selected") is not None,
                )
            )
    return tuple(parsed)


def selected(table: tuple[ClockStep, ...]) -> ClockStep | None:
    for step in table:
        if step.selected:
            return step
    return None


def engine_target(table: tuple[ClockStep, ...]) -> int | None:
    """The top engine index, which is the highest commandable state."""
    return table[-1].index if table else None


def memory_target(table: tuple[ClockStep, ...]) -> int | None:
    """The highest memory state the firmware honors as a hard minimum."""
    if not table:
        return None
    if table[-1].mhz == FIRMWARE_SELECTED_MEMORY_MHZ and len(table) > 1:
        return table[-2].index
    return table[-1].index


def resolve_device(root: Path | None = None) -> Path | None:
    """The amdgpu device carrying the clock tables, or None where none does."""
    base = Path("/") if root is None else root
    for candidate in sorted(base.glob(DRM_GLOB.lstrip("/"))):
        if (candidate / ENGINE_ATTRIBUTE).is_file():
            return candidate
    return None


def read_state(device: Path | None, *, reason: str = "") -> GraphicsState:
    if device is None:
        return GraphicsState(device=None, reason=reason or "no amdgpu device")
    level = (device / LEVEL_ATTRIBUTE).read_text(encoding="utf-8").strip()
    engine = selected(steps((device / ENGINE_ATTRIBUTE).read_text(encoding="utf-8")))
    memory = selected(steps((device / MEMORY_ATTRIBUTE).read_text(encoding="utf-8")))
    return GraphicsState(
        device=device,
        level=level,
        engine_mhz=engine.mhz if engine else 0,
        memory_mhz=memory.mhz if memory else 0,
        pinned=level == FORCED_LEVEL,
        reason=reason,
    )


def pin(root: Path | None = None) -> GraphicsState:
    """State the operating point, and report what the part delivered.

    A write that the rule has not made possible leaves the state governed and
    says so, rather than raising: an appliance that refuses to serve because a
    clock is low helps nobody, and a launch that serves without saying it is at
    400 MHz is the failure this reports.
    """
    device = resolve_device(root)
    if device is None:
        return read_state(None)
    if not all((device / name).exists() for name in CLOCK_ATTRIBUTES):
        return read_state(device, reason="the device carries no clock tables")
    engine_table = steps((device / ENGINE_ATTRIBUTE).read_text(encoding="utf-8"))
    memory_table = steps((device / MEMORY_ATTRIBUTE).read_text(encoding="utf-8"))
    engine = engine_target(engine_table)
    memory = memory_target(memory_table)
    if engine is None or memory is None:
        return read_state(device, reason="the clock tables name no step")
    try:
        (device / LEVEL_ATTRIBUTE).write_text(f"{FORCED_LEVEL}\n", encoding="utf-8")
        (device / ENGINE_ATTRIBUTE).write_text(f"{engine}\n", encoding="utf-8")
        (device / MEMORY_ATTRIBUTE).write_text(f"{memory}\n", encoding="utf-8")
    except OSError:
        return read_state(
            device,
            reason=(
                "no write access; install it with remote/install-amdgpu-clock-access.sh install"
            ),
        )
    return read_state(device)


# The rule the shell installer lays down, named here so the report can say
# whether it is in place. The prefix is declared in
# `runtime/appliance-path-allowlist.tsv` with the reason it exists.
RULE_SOURCE = ("runtime", "udev", "90-qwen-amdgpu-clocks.rules")
RULE_TARGET = Path("/etc/udev/rules.d/90-qwen-amdgpu-clocks.rules")


def access_report(root: Path | None = None) -> str:
    """Whether the three attributes are writable, and whether the rule is in place."""
    device = resolve_device(root)
    if device is None:
        return "clock_access=absent reason=no amdgpu device"
    writable = sum(1 for name in CLOCK_ATTRIBUTES if os.access(device / name, os.W_OK))
    installed = "installed" if RULE_TARGET.is_file() else "absent"
    return f"clock_access writable={writable} of {len(CLOCK_ATTRIBUTES)} rule={installed}"
