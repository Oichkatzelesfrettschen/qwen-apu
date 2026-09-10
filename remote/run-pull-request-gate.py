#!/usr/bin/env python3
"""Run the bounded pull-request gate for documentation and Web UI changes."""

from __future__ import annotations

import argparse
import datetime as dt
import os
import pathlib
import re
import subprocess
import tempfile
import time
from collections.abc import Sequence

FULL_GATE_EXIT = 3
FULL_GATE_PATHS = {"docs/install-requirements.tsv"}
SAFE_EXACT_PATHS = {"README.md", "remote/feature-claims.tsv"}
CI_ROUTING_PATHS = {
    ".github/workflows/repository-quality-gates.yml",
    "remote/merged-pr-gate-reuse.py",
    "remote/run-pull-request-gate.py",
    "remote/test-merged-pr-gate-reuse.py",
    "remote/test-run-pull-request-gate.py",
}
CI_ROUTING_PYTHON_PATHS = tuple(
    sorted(path for path in CI_ROUTING_PATHS if path.endswith(".py"))
)
SAFE_PREFIXES = ("docs/", "webui/")
SAFE_TEST_PATTERN = re.compile(r"remote/test-fallback-webui-[A-Za-z0-9_.-]+\Z")
SAFE_WEB_MCP_PATHS = {"remote/web-mcp/test-fallback-page-image.py"}
UI_TESTS: tuple[tuple[str, ...], ...] = (
    ("node", "remote/test-fallback-webui-model-state.mjs"),
    ("node", "remote/test-fallback-webui-conversations.mjs"),
    ("node", "remote/test-fallback-webui-fragment-key.mjs"),
    ("node", "remote/test-fallback-webui-sha256.mjs"),
    ("node", "remote/test-fallback-webui-ui-switch.mjs"),
    ("node", "remote/test-fallback-webui-roster.mjs"),
    ("node", "remote/test-fallback-webui-image-review.mjs"),
    ("remote/test-fallback-webui-model-selection.sh",),
    ("remote/test-fallback-webui-web-authorization.sh",),
    ("remote/test-fallback-webui-image-authorization.sh",),
    ("python3", "remote/web-mcp/test-fallback-page-image.py"),
)
ALWAYS_CHECKS: tuple[tuple[str, ...], ...] = (
    ("remote/refresh-evidence-manifest.sh", "--check"),
    ("python3", "remote/check-appliance-paths.py"),
    ("python3", "remote/check-text-policy.py"),
)


def validate_changed_path(value: str) -> str:
    path = pathlib.PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts or value != str(path):
        raise ValueError(f"invalid changed path: {value!r}")
    return value


def is_safe_path(path: str) -> bool:
    return (
        path in SAFE_EXACT_PATHS
        or path in SAFE_WEB_MCP_PATHS
        or path.startswith(SAFE_PREFIXES)
        or SAFE_TEST_PATTERN.fullmatch(path) is not None
    )


def classify_paths(paths: Sequence[str]) -> str:
    checked = [validate_changed_path(path) for path in paths]
    if not checked or any(path in FULL_GATE_PATHS for path in checked):
        return "full"
    if all(path in CI_ROUTING_PATHS for path in checked):
        return "ci-routing"
    if any(not is_safe_path(path) for path in checked):
        return "full"
    if all(path == "README.md" or path.startswith("docs/") for path in checked):
        return "documentation"
    return "webui"


def selected_checks(paths: Sequence[str], scope: str) -> list[tuple[str, ...]]:
    checks = list(ALWAYS_CHECKS)
    if scope == "ci-routing":
        checks.extend(
            (
                ("ruff", "check", *CI_ROUTING_PYTHON_PATHS),
                ("python3", "-m", "py_compile", *CI_ROUTING_PYTHON_PATHS),
                ("python3", "remote/test-run-pull-request-gate.py"),
                ("python3", "remote/test-merged-pr-gate-reuse.py"),
            )
        )
        return checks
    if scope != "webui":
        return checks
    changed_shell = sorted(path for path in paths if path.endswith(".sh"))
    changed_python = sorted(path for path in paths if path.endswith(".py"))
    if changed_shell:
        checks.append(("shellcheck", "-S", "warning", *changed_shell))
    if changed_python:
        checks.extend(
            (
                ("ruff", "check", *changed_python),
                ("python3", "-m", "py_compile", *changed_python),
            )
        )
    checks.append(("remote/test-feature-roster.sh",))
    checks.extend(UI_TESTS)
    return checks


def atomic_write(path: pathlib.Path, text: str) -> None:
    temporary = path.with_name(f".{path.name}.pending")
    with temporary.open("x", encoding="utf-8") as output:
        output.write(text)
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, path)


def write_result(path: pathlib.Path, fields: dict[str, object]) -> None:
    rows = ["field\tvalue"]
    rows.extend(f"{name}\t{value}" for name, value in fields.items())
    atomic_write(path, "\n".join(rows) + "\n")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--changed-files", required=True, type=pathlib.Path)
    parser.add_argument("--result-root", required=True, type=pathlib.Path)
    parser.add_argument("--worktree", required=True, type=pathlib.Path)
    parser.add_argument("--timeout-seconds", type=float, default=300.0)
    arguments = parser.parse_args()
    if not 1 <= arguments.timeout_seconds <= 600:
        parser.error("--timeout-seconds must be between 1 and 600")
    return arguments


def main() -> int:
    arguments = parse_arguments()
    worktree = arguments.worktree.resolve(strict=True)
    changed_paths = [
        line
        for line in arguments.changed_files.read_text(encoding="utf-8").splitlines()
        if line
    ]
    try:
        scope = classify_paths(changed_paths)
    except ValueError as error:
        print(error)
        return 2
    if scope == "full":
        print("pull_request_gate=full reason=changed_path_requires_exhaustive_gate")
        return FULL_GATE_EXIT

    head = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=worktree,
        text=True,
        stdout=subprocess.PIPE,
        check=True,
        close_fds=True,
        timeout=10,
    ).stdout.strip()
    arguments.result_root.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    result_directory = pathlib.Path(
        tempfile.mkdtemp(
            prefix=f"{stamp}-{head[:8]}-pr-",
            dir=arguments.result_root,
        )
    )
    gate_log = result_directory / "gate.log"
    result_file = result_directory / "result.tsv"
    started_ns = time.monotonic_ns()
    deadline_ns = started_ns + int(arguments.timeout_seconds * 1_000_000_000)
    checks = selected_checks(changed_paths, scope)
    fields: dict[str, object] = {
        "status": "interrupted",
        "exit": 143,
        "worktree": worktree,
        "head": head,
        "run": result_directory.name,
        "log": gate_log,
        "scope": scope,
        "changed_files": len(changed_paths),
        "checks_run": 0,
    }
    write_result(result_file, fields)
    environment = dict(os.environ)
    environment.pop("QWEN_HOME", None)
    status = 0
    with gate_log.open("xb") as log:
        for index, command in enumerate(checks, start=1):
            remaining = (deadline_ns - time.monotonic_ns()) / 1_000_000_000
            if remaining <= 0:
                status = 124
                break
            command_started = time.monotonic_ns()
            log.write(f"check={index} command={' '.join(command)}\n".encode())
            log.flush()
            try:
                completed = subprocess.run(
                    command,
                    cwd=worktree,
                    env=environment,
                    stdin=subprocess.DEVNULL,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    close_fds=True,
                    timeout=remaining,
                    check=False,
                )
                status = completed.returncode
            except subprocess.TimeoutExpired:
                status = 124
            elapsed = (time.monotonic_ns() - command_started) / 1_000_000_000
            log.write(
                f"check={index} exit={status} elapsed_seconds={elapsed:.3f}\n".encode()
            )
            log.flush()
            fields["checks_run"] = index
            if status != 0:
                break
    elapsed = (time.monotonic_ns() - started_ns) / 1_000_000_000
    fields.update(
        status="accepted" if status == 0 else "rejected",
        exit=status,
        elapsed_seconds=f"{elapsed:.3f}",
    )
    write_result(result_file, fields)
    print(
        f"pull_request_gate={fields['status']} scope={scope} "
        f"checks={fields['checks_run']} elapsed_seconds={elapsed:.3f}"
    )
    print(f"gate_result={result_file}")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
