"""Parity between qwen_apu.runtime.paths and remote/qwen-home.sh."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

from qwen_apu.runtime import paths as runtime_paths
from qwen_apu.runtime.paths import RuntimePaths, RuntimeRootError

TREE = Path(__file__).resolve().parents[1]
SHELL = TREE / "remote" / "qwen-home.sh"
SH = shutil.which("sh")


def shell_paths(env: dict[str, str]) -> str:
    result = subprocess.run(
        [SH or "sh", str(SHELL), "paths"], check=True, capture_output=True, text=True, env=env
    )
    return result.stdout


@pytest.mark.skipif(SH is None, reason="no sh")
@pytest.mark.parametrize("qwen_home", [None, "/var/tmp/qwen-parity-root"])  # noqa: S108
def test_declared_names_match_shell(qwen_home: str | None) -> None:
    env = {k: v for k, v in os.environ.items() if k != "QWEN_HOME"}
    if qwen_home:
        env["QWEN_HOME"] = qwen_home
        os.environ["QWEN_HOME"] = qwen_home
    else:
        os.environ.pop("QWEN_HOME", None)
    try:
        expected = shell_paths(env)
        actual = runtime_paths.render_paths(RuntimePaths.resolve(TREE), shell_only=True)
    finally:
        os.environ.pop("QWEN_HOME", None)
    assert actual == expected


def test_relative_qwen_home_refused(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("QWEN_HOME", "relative/root")
    with pytest.raises(RuntimeRootError):
        RuntimePaths.resolve(TREE)


def test_binding_states(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    root = tmp_path / "root"
    monkeypatch.setenv("QWEN_HOME", str(root))
    paths = RuntimePaths.resolve(TREE)
    assert paths.binding_state() == "unmarked"
    assert paths.lay_out() == "bound"
    assert paths.binding_state() == "bound"
    for relative in runtime_paths.LAYOUT_DIRECTORIES:
        assert (root / relative).is_dir()
    paths.marker.write_text("runtime_schema_version=1\ntree_root=/nonexistent/other\n")
    assert paths.binding_state() == "foreign:/nonexistent/other"
    with pytest.raises(RuntimeRootError):
        paths.require_binding()
    with pytest.raises(RuntimeRootError):
        paths.lay_out(rebind="/wrong")
    assert paths.lay_out(rebind=str(paths.tree)) == "rebound:/nonexistent/other"
    assert paths.binding_state() == "bound"


@pytest.mark.skipif(SH is None, reason="no sh")
def test_layout_directories_match_runtime_root_sh() -> None:
    text = (TREE / "remote" / "runtime-root.sh").read_text(encoding="utf-8")
    line = next(row for row in text.splitlines() if row.startswith("layout_directories="))
    declared = tuple(line.split("=", 1)[1].strip("'").split())
    assert declared == runtime_paths.LAYOUT_DIRECTORIES


def test_marker_bytes_match_shell_form(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("QWEN_HOME", str(tmp_path / "r"))
    paths = RuntimePaths.resolve(TREE)
    paths.lay_out()
    assert paths.marker.read_text() == f"runtime_schema_version=1\ntree_root={TREE}\n"
