"""What the developer form writes into the venv, and which roots it accepts.

This deployment has no build backend to read `[project.scripts]`: `bootstrap.py`
links the package with a `.pth` file and writes the console script itself, so a
claim that `qwen-apu` runs on the appliance is a claim about `link_source_tree`
and is proven by running the script it writes. The binding check is the second
claim: a runtime root whose marker names another checkout refuses, and the
refusal lifts exactly where `QWEN_RUNTIME_ROOT_REBIND` names this tree, which is
the case an appliance moved to another account's home meets.
"""

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
from pathlib import Path

import pytest

from qwen_apu.runtime.paths import RuntimePaths

TREE = Path(__file__).resolve().parents[1]


def _bootstrap() -> object:
    """`bootstrap.py` as a module, loaded from the path it sits at.

    The file is a script beside the checkout root rather than a package member,
    so it is imported by location; it imports the standard library alone, so the
    load has no side effect beyond defining its functions.
    """
    spec = importlib.util.spec_from_file_location("qwen_bootstrap", TREE / "bootstrap.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def venv(tmp_path: Path) -> Path:
    """One real environment, since the link reads its own interpreter's purelib."""
    created = subprocess.run(
        [sys.executable, "-m", "venv", "--without-pip", str(tmp_path / "venv")],
        check=False,
        capture_output=True,
    )
    if created.returncode != 0:
        pytest.skip("this interpreter cannot create a venv")
    return tmp_path / "venv"


def test_the_console_script_is_written(venv: Path) -> None:
    module = _bootstrap()
    module.link_source_tree(venv, venv / "bin" / "python", TREE)  # type: ignore[attr-defined]
    for name, entry in module.CONSOLE_SCRIPTS:  # type: ignore[attr-defined]
        script = venv / "bin" / name
        text = script.read_text(encoding="utf-8")
        assert text.startswith(f"#!{venv / 'bin' / 'python'}\n")
        assert f"from qwen_apu.cli import {entry}" in text
        assert os.access(script, os.X_OK)
    pth = next((venv / "lib").rglob("qwen_apu.pth"))
    assert pth.read_text(encoding="utf-8").strip() == str(TREE / "src")


def test_the_written_script_runs(venv: Path) -> None:
    """The script answers, which is what `remote/qwen` reaches through this venv."""
    module = _bootstrap()
    module.link_source_tree(venv, venv / "bin" / "python", TREE)  # type: ignore[attr-defined]
    result = subprocess.run(
        [str(venv / "bin" / "qwen-apu"), "appliance", "--help"],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "up" in result.stdout


def test_a_foreign_marker_refuses_without_the_rebind(tmp_path: Path) -> None:
    module = _bootstrap()
    other = tmp_path / "other-checkout"
    (other / "remote").mkdir(parents=True)
    paths = RuntimePaths(tree=other, root=tmp_path / "runtime")
    paths.lay_out()
    moved = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    refusal = module.binding_refusal(moved, TREE, None)  # type: ignore[attr-defined]
    assert refusal is not None
    assert str(other) in refusal


def test_the_rebind_naming_this_tree_leaves_the_decision_to_lay_out(tmp_path: Path) -> None:
    """A moved root accepts the check and records the previous binding in its outcome."""
    module = _bootstrap()
    other = tmp_path / "other-checkout"
    (other / "remote").mkdir(parents=True)
    RuntimePaths(tree=other, root=tmp_path / "runtime").lay_out()
    moved = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    assert module.binding_refusal(moved, TREE, str(TREE)) is None  # type: ignore[attr-defined]
    assert moved.lay_out(rebind=str(TREE)) == f"rebound:{other}"


def test_a_bound_root_accepts_the_check(tmp_path: Path) -> None:
    module = _bootstrap()
    paths = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    paths.lay_out()
    assert module.binding_refusal(paths, TREE, None) is None  # type: ignore[attr-defined]
