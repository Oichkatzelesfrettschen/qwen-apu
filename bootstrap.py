#!/usr/bin/env python3
"""The zero-dependency entry point: lay out the runtime root and its venv.

    python3 bootstrap.py
    .runtime/venv/bin/qwen-apu doctor

The script imports the standard library alone, so it runs on the interpreter
the appliance ships before any project dependency exists. It resolves the
checkout and the runtime root the way `qwen_apu.runtime.paths` does, refuses
a root whose marker names another checkout, creates `venv/` under the root,
installs the project into it, and writes the marker last so a half-built root
reads as `unmarked` rather than `bound`. Every write lands under the runtime
root; the checkout itself stays untouched.

Installation takes the first of three paths. A `wheelhouse/` directory beside
this file holding `requirements.lock` installs with `--require-hashes` and the
index closed, which is the production form. A tree carrying `src/` without a
wheelhouse links the package by a `.pth` file and writes both console scripts
itself, which needs no build backend and no network and is the developer form.
`[project.scripts]` in `pyproject.toml` states the same two entry points for an
installer that runs a build backend; this form has neither, so
`link_source_tree` is what puts `qwen-apu` and `qwen` in the venv's `bin/`.
A Python whose `venv` module cannot create an environment falls to a bundled
`virtualenv.pyz` under `wheelhouse/`; the absence of both refuses with the
interpreter's own message rather than reaching for a package manager.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Any

PYTHON_REQUIRED = (3, 12)
SRC = "src"
PACKAGE = "qwen_apu"
# The two console scripts the developer form writes, matching
# `[project.scripts]`: the whole command, and the operator's four verbs over one
# appliance.
CONSOLE_SCRIPTS = (("qwen-apu", "main"), ("qwen", "operator_main"))


def fail(message: str, code: int = 2) -> int:
    print(f"bootstrap: {message}", file=sys.stderr)
    return code


def binding_refusal(paths: Any, tree: Path, rebind: str | None) -> str | None:
    """The reason this root refuses this checkout, or None where it accepts it.

    A root whose marker names another checkout refuses, which is the decision
    `RuntimePaths.lay_out` makes again at the end of a run -- except that
    `lay_out` accepts the rebind `QWEN_RUNTIME_ROOT_REBIND` names and a bare
    `require_binding` has no way to. An appliance moved to another account's home
    is exactly that case: the root and the checkout travel together and the
    marker still names where they came from. Where the variable names this tree
    the refusal is left to `lay_out`, which records the previous binding in its
    `rebound:` outcome rather than discarding it silently.
    """
    from qwen_apu.runtime.paths import RuntimeRootError  # noqa: PLC0415

    if rebind == str(tree):
        return None
    try:
        paths.require_binding()
    except RuntimeRootError as error:
        return str(error)
    return None


def main() -> int:
    if sys.version_info < PYTHON_REQUIRED:
        return fail(
            f"python {PYTHON_REQUIRED[0]}.{PYTHON_REQUIRED[1]} or newer is required; "
            f"this interpreter is {sys.version.split()[0]}"
        )
    tree = Path(__file__).resolve().parent
    # Bytecode for the checkout's own modules lands under the root rather
    # than beside the sources, which keeps the checkout untouched.
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(tree / SRC))
    from qwen_apu.runtime.paths import RuntimePaths, RuntimeRootError  # noqa: PLC0415

    paths = RuntimePaths.resolve(tree)
    rebind = os.environ.get("QWEN_RUNTIME_ROOT_REBIND")
    refusal = binding_refusal(paths, tree, rebind)
    if refusal is not None:
        return fail(refusal)
    venv_dir = paths["qwen_home_venv"]
    python = paths["qwen_home_venv_python"]

    # Every child inherits TMPDIR under the root, so pip's and ensurepip's
    # scratch directories land inside the write boundary as well.
    scratch = paths["qwen_home_tmp"]
    scratch.mkdir(parents=True, exist_ok=True)
    os.environ["TMPDIR"] = str(scratch)
    if not python.exists():
        outcome = create_venv(venv_dir, tree)
        if outcome:
            return fail(outcome)
    wheelhouse = tree / "wheelhouse"
    lock = wheelhouse / "requirements.lock"
    source = (tree / SRC / PACKAGE).is_dir()
    if not lock.is_file() and not source:
        return fail(
            "neither wheelhouse/requirements.lock nor src/qwen_apu exists beside bootstrap.py"
        )
    # The lock carries the third-party dependencies and the source link
    # carries the package itself, so a checkout holding both installs the
    # lock first and links the tree second; a lock alone is the deployed
    # wheelhouse and a tree alone is a dependency-free developer checkout.
    if lock.is_file():
        command = [
            str(python),
            "-m",
            "pip",
            "install",
            "--no-index",
            "--find-links",
            str(wheelhouse),
            "--require-hashes",
            "-r",
            str(lock),
        ]
        result = subprocess.run(command, check=False)
        if result.returncode != 0:
            return fail("hash-locked install failed", 1)
    if source:
        link_source_tree(venv_dir, python, tree)

    try:
        outcome_text = paths.lay_out(rebind=rebind)
    except RuntimeRootError as error:
        return fail(str(error))
    print(f"runtime_root={paths.root} schema={paths.marker_schema()} binding={outcome_text}")
    print(f"cli={paths['qwen_home_venv_cli']}")
    return 0


def create_venv(venv_dir: Path, tree: Path) -> str:
    """Create the environment through venv, falling to a bundled virtualenv."""
    result = subprocess.run(
        [sys.executable, "-m", "venv", "--without-pip", str(venv_dir)], check=False
    )
    if result.returncode == 0:
        pip = subprocess.run(
            [str(venv_dir / "bin" / "python"), "-m", "ensurepip", "--upgrade"],
            check=False,
            capture_output=True,
        )
        if pip.returncode == 0:
            return ""
    pyz = tree / "wheelhouse" / "virtualenv.pyz"
    if pyz.is_file():
        result = subprocess.run([sys.executable, str(pyz), str(venv_dir)], check=False)
        return "" if result.returncode == 0 else "bundled virtualenv.pyz failed"
    return (
        "this interpreter cannot create a venv with pip and wheelhouse/virtualenv.pyz is absent; "
        "the appliance prerequisites require a Python with a working venv and ensurepip"
    )


def link_source_tree(venv_dir: Path, python: Path, tree: Path) -> None:
    """Developer form: a .pth file and a console script, no build backend."""
    probe = subprocess.run(
        [str(python), "-c", "import sysconfig;print(sysconfig.get_paths()['purelib'])"],
        check=True,
        capture_output=True,
        text=True,
    )
    site = Path(probe.stdout.strip())
    site.mkdir(parents=True, exist_ok=True)
    (site / f"{PACKAGE}.pth").write_text(f"{tree / SRC}\n", encoding="utf-8")
    for name, entry in CONSOLE_SCRIPTS:
        write_console_script(venv_dir / "bin" / name, python, venv_dir, tree, entry)
    (venv_dir / "qwen-apu-tree").write_text(f"{tree}\n", encoding="utf-8")


def write_console_script(
    script: Path, python: Path, venv_dir: Path, tree: Path, entry: str
) -> None:
    """One console script, naming the root it lives under and its checkout.

    Both entry points take the same preamble: a run of `venv/bin/qwen` or
    `venv/bin/qwen-apu` from any working directory reads that root, and an
    explicit QWEN_HOME still wins. The absolute shebang is what binds a script
    to its venv, so a moved runtime root is repaired by running this file again
    rather than by editing the scripts.
    """
    script.write_text(
        f"#!{python}\nimport os\nimport sys\n"
        f"os.environ.setdefault('QWEN_HOME', {str(venv_dir.parent)!r})\n"
        f"os.environ.setdefault('QWEN_TREE_ROOT', {str(tree)!r})\n"
        f"sys.pycache_prefix = {str(venv_dir.parent / 'cache' / 'pycache')!r}\n"
        f"from {PACKAGE}.cli import {entry}\nsys.exit({entry}())\n",
        encoding="utf-8",
    )
    script.chmod(0o755)


if __name__ == "__main__":
    raise SystemExit(main())
