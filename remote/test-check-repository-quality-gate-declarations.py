#!/usr/bin/env python3
"""Test exact repository gate declaration authority checks."""

from __future__ import annotations

import pathlib
import subprocess
import tempfile

SCRIPT_DIRECTORY = pathlib.Path(__file__).resolve().parent
CHECKER = SCRIPT_DIRECTORY / "check-repository-quality-gate-declarations.py"
ROOT_A = "a" * 64
ROOT_B = "b" * 64


def write_driver(path: pathlib.Path, cells: int, root: str) -> None:
    path.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        f"printf '%s\\n' 'gate_declarations=accepted cells={cells} root={root}'\n"
        "printf '%s\\n' 'repository_quality_gates=accepted'\n",
        encoding="utf-8",
    )
    path.chmod(0o755)


def write_authority(path: pathlib.Path, cells: int, root: str) -> None:
    path.write_text(
        f"field\tvalue\nschema\t1\ncells\t{cells}\nroot\t{root}\n",
        encoding="utf-8",
    )


def run_checker(driver: pathlib.Path, authority: pathlib.Path) -> int:
    return subprocess.run(
        [CHECKER, "--driver", driver, "--authority", authority],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
        close_fds=True,
        timeout=10,
    ).returncode


with tempfile.TemporaryDirectory() as temporary_directory:
    fixture_root = pathlib.Path(temporary_directory)
    driver = fixture_root / "gate.sh"
    authority = fixture_root / "authority.tsv"
    write_authority(authority, 2, ROOT_A)

    write_driver(driver, 2, ROOT_A)
    assert run_checker(driver, authority) == 0

    write_driver(driver, 1, ROOT_A)
    assert run_checker(driver, authority) == 1

    write_driver(driver, 2, ROOT_B)
    assert run_checker(driver, authority) == 1

    write_authority(authority, 2, ROOT_B)
    assert run_checker(driver, authority) == 0

print("repository_gate_declaration_authority_fixtures=accepted")
