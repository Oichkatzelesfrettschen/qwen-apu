#!/usr/bin/env python3
"""Verify the repository gate declaration set against its reviewed authority."""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess

DECLARATION_PATTERN = re.compile(
    r"gate_declarations=accepted cells=([1-9][0-9]*) root=([0-9a-f]{64})"
)
REQUIRED_AUTHORITY_FIELDS = {"schema", "cells", "root"}


def read_authority(path: pathlib.Path) -> tuple[int, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "field\tvalue":
        raise ValueError("declaration authority header is invalid")
    fields: dict[str, str] = {}
    for line in lines[1:]:
        columns = line.split("\t")
        if len(columns) != 2 or not all(columns):
            raise ValueError("declaration authority row is invalid")
        field, value = columns
        if field in fields:
            raise ValueError(f"duplicate declaration authority field: {field}")
        fields[field] = value
    if set(fields) != REQUIRED_AUTHORITY_FIELDS:
        raise ValueError("declaration authority fields are incomplete")
    if fields["schema"] != "1":
        raise ValueError("declaration authority schema is unsupported")
    if re.fullmatch(r"[1-9][0-9]*", fields["cells"]) is None:
        raise ValueError("declaration authority cell count is invalid")
    if re.fullmatch(r"[0-9a-f]{64}", fields["root"]) is None:
        raise ValueError("declaration authority root is invalid")
    return int(fields["cells"]), fields["root"]


def read_declarations(output: str) -> tuple[int, str]:
    matches = DECLARATION_PATTERN.findall(output)
    if len(matches) != 1:
        raise ValueError("gate declaration summary is missing or duplicated")
    if output.splitlines()[-1:] != ["repository_quality_gates=accepted"]:
        raise ValueError("gate declaration traversal did not accept")
    cells, root = matches[0]
    return int(cells), root


def parse_arguments() -> argparse.Namespace:
    script_directory = pathlib.Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--driver",
        type=pathlib.Path,
        default=script_directory / "repository-quality-gates.sh",
    )
    parser.add_argument(
        "--authority",
        type=pathlib.Path,
        default=script_directory / "repository-quality-gate-declarations.tsv",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        expected = read_authority(arguments.authority)
        completed = subprocess.run(
            [arguments.driver, "--declarations"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            close_fds=True,
            timeout=30,
        )
        if completed.returncode != 0:
            raise ValueError(
                f"gate declaration traversal exited {completed.returncode}: "
                f"{completed.stderr.strip()}"
            )
        measured = read_declarations(completed.stdout)
        if measured != expected:
            raise ValueError(
                "gate declarations differ from authority: "
                f"expected_cells={expected[0]} measured_cells={measured[0]} "
                f"expected_root={expected[1]} measured_root={measured[1]}"
            )
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        print(f"repository_gate_declaration_authority=refused reason={error}")
        return 1
    print(
        "repository_gate_declaration_authority=accepted "
        f"cells={measured[0]} root={measured[1]}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
