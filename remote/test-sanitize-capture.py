#!/usr/bin/env python3
"""sanitize-capture.py over inputs whose every field is known in advance.

Each check fixes one claim the printed row makes. The two digests are computed
here from the bytes the fixture wrote and the bytes the reader is required to
write, so a substitution that silently changes the output fails on the digest
rather than on a count alone. The refusals are the other half: a sanitizer that
writes over its input destroys the source its record names, and one that writes
over an existing output leaves a record describing bytes a later run replaced.

The binary case carries the same weight as the text case. A register dump, a
VBIOS image, and a compiled module are exactly the captures this reader is
written for, and a substitution inside one corrupts the artifact its digest
identifies, so the fixture asserts the bytes pass through unchanged.
"""

from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "sanitize-capture.py"
FIXTURE_HOST = "hp14-dk1xxx"
# The home prefix the fixture substitutes is the temporary directory the run
# already owns, so the fixture states no path of its own and the substitution
# is exercised over a prefix that exists.
FIXTURE_HOME = ""

failures = 0


def report(name: str, outcome: str) -> None:
    global failures
    if outcome == "ok":
        print(f"ok {name}")
    else:
        print(f"FAIL {name}: {outcome}")
        failures += 1


def set_fixture_home(root: Path) -> None:
    """Bind the substituted home prefix to this run's temporary directory."""
    global FIXTURE_HOME
    FIXTURE_HOME = str(root)


def run(raw: Path, output: Path) -> subprocess.CompletedProcess[str]:
    environment = dict(os.environ)
    environment["QWEN_SANITIZE_HOST"] = FIXTURE_HOST
    environment["QWEN_SANITIZE_HOME"] = FIXTURE_HOME
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(raw), str(output)],
        capture_output=True,
        text=True,
        env=environment,
    )


def digest_of(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def check_text_substitutions(root: Path) -> None:
    """Three substitutions over one text capture, both digests exact."""
    raw_payload = (
        f"host_shortname\t{FIXTURE_HOST}\n"
        f"server\t{FIXTURE_HOME}\n"
        "link\tether 00:1a:2b:3c:4d:5e\n"
        "unchanged\tRADV RAVEN2 gfx902\n"
    ).encode()
    expected_payload = (
        "host_shortname\tqwen-laptop\n"
        "server\t$HOME\n"
        "link\tether <mac>\n"
        "unchanged\tRADV RAVEN2 gfx902\n"
    ).encode()
    raw = root / "capture.txt"
    raw.write_bytes(raw_payload)
    output = root / "capture.sanitized.txt"

    completed = run(raw, output)
    if completed.returncode != 0:
        report("text-substitutions", f"exit {completed.returncode}: {completed.stderr}")
        return
    fields = completed.stdout.rstrip("\n").split("\t")
    if len(fields) != 4:
        report("text-substitutions", f"the row carries {len(fields)} fields")
        return
    raw_digest, sanitized_digest, sanitizer_digest, substitutions = fields
    if raw_digest != digest_of(raw_payload):
        report("text-substitutions", "raw_sha256 differs from the fixture's bytes")
        return
    if output.read_bytes() != expected_payload:
        report("text-substitutions", "the written bytes differ from the three rules")
        return
    if sanitized_digest != digest_of(expected_payload):
        report("text-substitutions", "sanitized_sha256 differs from the written bytes")
        return
    if sanitizer_digest != digest_of(SCRIPT.read_bytes()):
        report("text-substitutions", "sanitizer_sha256 is not this reader's digest")
        return
    if substitutions != "3":
        report("text-substitutions", f"substitutions reads {substitutions}, not 3")
        return
    if raw.read_bytes() != raw_payload:
        report("text-substitutions", "the reader wrote its own input")
        return
    report("text-substitutions", "ok")


def check_binary_passthrough(root: Path) -> None:
    """A capture carrying a NUL byte passes through unchanged."""
    raw_payload = b"VBIOS\x00" + FIXTURE_HOST.encode() + b"\x00\xff\xfe"
    raw = root / "capture.rom"
    raw.write_bytes(raw_payload)
    output = root / "capture.sanitized.rom"

    completed = run(raw, output)
    if completed.returncode != 0:
        report("binary-passthrough", f"exit {completed.returncode}: {completed.stderr}")
        return
    fields = completed.stdout.rstrip("\n").split("\t")
    if fields[3] != "binary":
        report("binary-passthrough", f"substitutions reads {fields[3]}, not binary")
        return
    if output.read_bytes() != raw_payload:
        report("binary-passthrough", "the payload was substituted inside")
        return
    if fields[0] != fields[1]:
        report("binary-passthrough", "the two digests differ over identical bytes")
        return
    report("binary-passthrough", "ok")


def check_refuses_in_place(root: Path) -> None:
    """An output naming the input is refused and the input survives."""
    raw_payload = f"{FIXTURE_HOST}\n".encode()
    raw = root / "in-place.txt"
    raw.write_bytes(raw_payload)

    completed = run(raw, raw)
    if completed.returncode == 0:
        report("refuses-in-place", "the reader accepted its own input as the output")
        return
    if raw.read_bytes() != raw_payload:
        report("refuses-in-place", "the input was rewritten")
        return
    report("refuses-in-place", "ok")


def check_refuses_existing_output(root: Path) -> None:
    """An existing output is refused and its bytes stand."""
    raw = root / "source.txt"
    raw.write_bytes(f"{FIXTURE_HOST}\n".encode())
    output = root / "already-there.txt"
    standing = b"retained\n"
    output.write_bytes(standing)

    completed = run(raw, output)
    if completed.returncode == 0:
        report("refuses-existing-output", "the reader wrote over an existing file")
        return
    if output.read_bytes() != standing:
        report("refuses-existing-output", "the existing output was replaced")
        return
    report("refuses-existing-output", "ok")


def check_unmatched_capture(root: Path) -> None:
    """A capture naming none of the three patterns reports zero and copies."""
    raw_payload = b"pp_dpm_mclk\t933Mhz\n"
    raw = root / "clocks.tsv"
    raw.write_bytes(raw_payload)
    output = root / "clocks.sanitized.tsv"

    completed = run(raw, output)
    if completed.returncode != 0:
        report("unmatched-capture", f"exit {completed.returncode}: {completed.stderr}")
        return
    fields = completed.stdout.rstrip("\n").split("\t")
    if fields[3] != "0":
        report("unmatched-capture", f"substitutions reads {fields[3]}, not 0")
        return
    if fields[0] != fields[1]:
        report("unmatched-capture", "an unsubstituted copy carries a second digest")
        return
    report("unmatched-capture", "ok")


def main() -> int:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        set_fixture_home(root)
        check_text_substitutions(root)
        check_binary_passthrough(root)
        check_refuses_in_place(root)
        check_refuses_existing_output(root)
        check_unmatched_capture(root)
    print(f"failures={failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
