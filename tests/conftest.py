"""Fixtures more than one test module takes.

`leased_port` is here rather than in either caller because two modules bind a
loopback listener: `test_runtime_supervisor` starts the fake server behind the
guards, and `test_web_gateway` assembles the whole origin. A bind to port zero
reports a number free at the instant of the read and reserves nothing
afterwards, so two modules running at once on one workstation receive the same
number and the second listener meets EADDRINUSE; `remote/test-port-lease.sh`
holds an exclusive flock on each number until the fixture releases it.
"""

from __future__ import annotations

import shutil
import subprocess
from collections.abc import Iterator
from pathlib import Path

import pytest

TREE = Path(__file__).resolve().parents[1]
PORT_LEASE = TREE / "remote" / "test-port-lease.sh"
SHELL = shutil.which("sh")


@pytest.fixture
def leased_port(tmp_path: Path) -> Iterator[int]:
    """One loopback port, held by the lease holder until this fixture releases."""
    if SHELL is None:
        pytest.skip("no /bin/sh")
    ports_file = tmp_path / "ports.txt"
    # The claim backgrounds a holder that outlives the command and inherits
    # its stderr, so capturing that descriptor would block this read until the
    # holder itself exits. stdout carries the holder pid and closes with the
    # claim; stderr goes to the null device the way the shell leaves it to the
    # caller's own.
    claim = subprocess.run(
        [SHELL, str(PORT_LEASE), "claim", "1", str(ports_file)],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=True,
    )
    holder = claim.stdout.strip()
    try:
        yield int(ports_file.read_text(encoding="ascii").split()[0])
    finally:
        subprocess.run(
            [SHELL, str(PORT_LEASE), "release", holder],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
