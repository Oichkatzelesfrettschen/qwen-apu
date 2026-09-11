"""Prerequisite checks a user-space installer can detect and cannot repair.

Each check reads one system fact and reports it with a verdict. A failing
check names what an administrator must change (group membership, the kernel
driver, node permissions), because none of those is a write under the
runtime root.
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

from qwen_apu.runtime.paths import RUNTIME_SCHEMA_VERSION, RuntimePaths

RENDER_NODE_GLOB = "renderD*"
DRM_SYSFS = Path("/sys/class/drm")  # appliance-path: named
RADV_ICD_GLOBS = ("/usr/share/vulkan/icd.d/radeon_icd.*.json",)  # appliance-path: named
RAVEN2_DEVICE_IDS = frozenset({"0x15d8"})


@dataclass(frozen=True)
class Check:
    name: str
    ok: bool
    detail: str
    remedy: str = ""


def render_nodes() -> list[Path]:
    dev = Path("/dev/dri")
    if not dev.is_dir():
        return []
    return sorted(dev.glob(RENDER_NODE_GLOB))


def amdgpu_device_id(node: Path) -> str:
    sysfs = DRM_SYSFS / node.name / "device"
    try:
        driver = (sysfs / "driver").resolve().name
        device = (sysfs / "device").read_text(encoding="ascii").strip()
    except OSError:
        return ""
    return f"{driver}:{device}"


def check_python() -> Check:
    version = sys.version.split()[0]
    ok = sys.version_info >= (3, 12)
    return Check("python", ok, version, "install Python 3.12 or newer")


def check_render_node() -> Check:
    nodes = render_nodes()
    if not nodes:
        return Check(
            "render-node",
            False,
            "no /dev/dri/renderD* node",
            "load amdgpu; a user-space installer cannot load a kernel driver",
        )
    for node in nodes:
        identity = amdgpu_device_id(node)
        readable = os.access(node, os.R_OK | os.W_OK)
        if identity.startswith("amdgpu:"):
            device = identity.split(":", 1)[1]
            label = "raven2" if device in RAVEN2_DEVICE_IDS else device
            if readable:
                return Check("render-node", True, f"{node} amdgpu {label}")
            return Check(
                "render-node",
                False,
                f"{node} amdgpu {label} is not accessible",
                f"an administrator adds this user to the group owning {node} (usually render)",
            )
    return Check(
        "render-node",
        False,
        f"no amdgpu node among {[str(n) for n in nodes]}",
        "the appliance requires amdgpu on a Raven2 device",
    )


def check_radv() -> Check:
    for pattern in RADV_ICD_GLOBS:
        matches = sorted(Path("/").glob(pattern.lstrip("/")))
        if matches:
            return Check("radv-icd", True, str(matches[0]))
    return Check(
        "radv-icd",
        False,
        "no radeon_icd.*.json under the system Vulkan ICD directory",
        "install the distribution's RADV driver or a project-supplied RADV bundle",
    )


def check_runtime_root(paths: RuntimePaths) -> Check:
    state = paths.binding_state()
    schema = paths.marker_schema()
    if state == "unmarked":
        return Check("runtime-root", False, f"{paths.root} unmarked", "run python3 bootstrap.py")
    if state != "bound":
        return Check(
            "runtime-root",
            False,
            f"{paths.root} {state}",
            "bootstrap from the checkout the marker names",
        )
    if schema != RUNTIME_SCHEMA_VERSION:
        return Check(
            "runtime-root",
            False,
            f"marker schema {schema} where this package reads {RUNTIME_SCHEMA_VERSION}",
        )
    return Check("runtime-root", True, f"{paths.root} bound schema {schema}")


def check_writable_root(paths: RuntimePaths) -> Check:
    target = paths.root if paths.root.exists() else paths.root.parent
    ok = os.access(target, os.W_OK)
    return Check("root-writable", ok, str(target), "choose a QWEN_HOME the user owns")


def run(paths: RuntimePaths) -> list[Check]:
    return [
        check_python(),
        check_runtime_root(paths),
        check_writable_root(paths),
        check_render_node(),
        check_radv(),
    ]


def render(checks: list[Check]) -> str:
    lines = []
    for check in checks:
        verdict = "ok" if check.ok else "fail"
        line = f"{check.name}\t{verdict}\t{check.detail}"
        if not check.ok and check.remedy:
            line += f"\t{check.remedy}"
        lines.append(line)
    return "\n".join(lines) + "\n"
