#!/usr/bin/env python3
"""The lexical ratchet over owned storage: a production script names no
absolute appliance path outside the runtime root.

remote/qwen-home.sh derives every owned location from QWEN_HOME, so a literal
`/usr/local/...`, `/opt/...`, `/etc/...`, `/var/...`, `$HOME/...`, or `~/...`
in a checked-in script is either a system fact the appliance reads (the RADV
ICD, the sudo policy, `/usr/bin/renice`) or the class of defect that once put
one SearXNG install under /usr/local and a second under /opt. The allowlist
in runtime/appliance-path-allowlist.tsv names the first class by prefix with
its reason; everything else fails. A line carrying `appliance-path: named`
names a path outside the root on purpose -- the doctor's legacy table, a
sanitized ledger string, a fixture proving a foreign path is refused -- and
is admitted by that marker alone. A file whose first five lines carry
`appliance-path: fixtures` is the ratchet's own test, whose fixtures are the
violations it proves are caught, and is skipped whole.

usage: check-appliance-paths.py [--root DIR]
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ABSOLUTE = re.compile(r"(?<![\w.$/{}])(/(?:usr/local|opt|etc|var|srv|home)/[\w./$@{}-]*)")
HOME_ANCHORED = re.compile(r"(\$\{?HOME[^}/]*\}?/[\w./$@{}-]*|(?<![\w/])~/[\w./$@{}-]*)")  # appliance-path: named
NAMED_MARKER = "appliance-path: named"
FIXTURES_MARKER = "appliance-path: fixtures"
SCANNED_SUFFIXES = {".sh", ".py"}


def load_allowlist(path: Path) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    with path.open(encoding="utf-8") as handle:
        header = handle.readline().rstrip("\n").split("\t")
        if header != ["prefix", "reason"]:
            raise SystemExit(f"{path}: header is {header}, expected prefix and reason")
        for number, line in enumerate(handle, start=2):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) != 2 or not fields[0] or not fields[1]:
                raise SystemExit(f"{path}:{number}: a row carries prefix and reason")
            rows.append((fields[0], fields[1]))
    return rows


def tracked_files(root: Path) -> list[Path]:
    listing = subprocess.run(
        ["git", "-C", str(root), "-c", "core.fsmonitor=false", "ls-files", "-z", "--", "remote", "Makefile"],
        check=True, capture_output=True,
    ).stdout
    files = []
    for entry in listing.split(b"\0"):
        if not entry:
            continue
        candidate = root / entry.decode()
        if candidate.suffix in SCANNED_SUFFIXES or candidate.name == "Makefile":
            files.append(candidate)
    return files


def code_lines(path: Path) -> list[tuple[int, str]]:
    """Lines outside comments. A python docstring is prose and is skipped the
    same way a shell comment is, by tracking triple-quote parity."""
    out: list[tuple[int, str]] = []
    in_docstring = False
    for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
        stripped = line.strip()
        if path.suffix == ".py":
            quotes = stripped.count('"""') + stripped.count("'''")
            if in_docstring:
                if quotes % 2 == 1:
                    in_docstring = False
                continue
            if quotes % 2 == 1:
                in_docstring = True
                continue
            if quotes >= 2 and (stripped.startswith('"""') or stripped.startswith("'''")):
                continue
        if not stripped or stripped.startswith("#"):
            continue
        # A trailing shell comment carries prose; the code ahead of it is
        # what is scanned. A `#` inside quotes stays, since the patterns
        # below match paths rather than comments and a quoted `#` is rare.
        out.append((number, line))
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    root: Path = args.root.resolve()
    allowlist = load_allowlist(root / "runtime" / "appliance-path-allowlist.tsv")
    findings: list[str] = []
    scanned = 0
    for path in tracked_files(root):
        with path.open(encoding="utf-8", errors="replace") as handle:
            head = [handle.readline() for _ in range(5)]
        if any(FIXTURES_MARKER in line for line in head):
            continue
        scanned += 1
        for number, line in code_lines(path):
            if NAMED_MARKER in line:
                continue
            for match in list(ABSOLUTE.finditer(line)) + list(HOME_ANCHORED.finditer(line)):
                token = match.group(1)
                if any(token.startswith(prefix) for prefix, _ in allowlist):
                    continue
                findings.append(f"{path.relative_to(root)}:{number}: {token}")
    if findings:
        print("owned storage named outside the runtime root:", file=sys.stderr)
        for finding in findings:
            print("  " + finding, file=sys.stderr)
        print(f"{len(findings)} finding(s) over {scanned} file(s); derive the path from "
              "remote/qwen-home.sh or add a system prefix with its reason to "
              "runtime/appliance-path-allowlist.tsv", file=sys.stderr)
        return 1
    print(f"appliance_paths=clean files={scanned} allowlist_rows={len(allowlist)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
