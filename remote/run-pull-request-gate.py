#!/usr/bin/env python3
"""Run the bounded pull-request gate for registered change scopes."""

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
SURFACE_ORDER = (
    "browser-preflight",
    "ci-routing",
    "documentation",
    "evidence",
    "gate-infrastructure",
    "q8-sampler-attribution",
    "webui",
)
CI_ROUTING_PATHS = {
    ".github/workflows/repository-quality-gates.yml",
    "remote/merged-pr-gate-reuse.py",
    "remote/run-pull-request-gate.py",
    "remote/test-merged-pr-gate-reuse.py",
    "remote/test-run-pull-request-gate.py",
}
GATE_INFRASTRUCTURE_PATHS = {
    "remote/check-repository-quality-gate-declarations.py",
    "remote/gate-cell-key.sh",
    "remote/repository-quality-gate-declarations.tsv",
    "remote/repository-quality-gates.sh",
    "remote/test-check-repository-quality-gate-declarations.py",
    "remote/test-repository-gate-cells.sh",
}
BROWSER_PREFLIGHT_PATHS = {
    "remote/browser-driver-preflight.py",
    "remote/qwen_home.py",
    "remote/run-browser-driver.sh",
    "remote/test-browser-driver-preflight.py",
    "remote/test-qwen-home.sh",
}
Q8_SAMPLER_ATTRIBUTION_PATHS = {
    "remote/build-telemetry-broker.sh",
    "remote/run-raven2-vulkan-kernel-census.sh",
    "remote/telemetry-broker.c",
    "remote/test-census-controls.py",
    "remote/test-run-raven2-vulkan-kernel-census.sh",
    "remote/test-telemetry-broker.sh",
    "remote/validate-clock-sidecar.py",
}
CI_ROUTING_PYTHON_PATHS = tuple(
    sorted(path for path in CI_ROUTING_PATHS if path.endswith(".py"))
)
GATE_DECLARATION_PYTHON_PATHS = (
    "remote/check-repository-quality-gate-declarations.py",
    "remote/test-check-repository-quality-gate-declarations.py",
)
SAFE_TEST_PATTERN = re.compile(r"remote/test-fallback-webui-[A-Za-z0-9_.-]+\Z")
WEBUI_INPUT_PATHS = {
    "remote/feature-claims.tsv",
    "remote/web-mcp/test-fallback-page-image.py",
}
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
TEXT_POLICY_CHECKS: tuple[tuple[str, ...], ...] = (
    ("python3", "remote/check-text-policy.py"),
)


def validate_changed_path(value: str) -> str:
    path = pathlib.PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts or value != str(path):
        raise ValueError(f"invalid changed path: {value!r}")
    return value


def path_surfaces(path: str) -> set[str]:
    if path in FULL_GATE_PATHS:
        return {"full"}
    surfaces: set[str] = set()
    if path == "README.md" or path.startswith("docs/"):
        surfaces.add("documentation")
    if path == "evidence/SHA256SUMS" or path.startswith(("benchmarks/", "evidence/")):
        surfaces.add("evidence")
    if path in CI_ROUTING_PATHS:
        surfaces.add("ci-routing")
    if path in GATE_INFRASTRUCTURE_PATHS:
        surfaces.add("gate-infrastructure")
    if path in BROWSER_PREFLIGHT_PATHS:
        surfaces.add("browser-preflight")
    if path in Q8_SAMPLER_ATTRIBUTION_PATHS:
        surfaces.add("q8-sampler-attribution")
    if (
        path.startswith("webui/")
        or path in WEBUI_INPUT_PATHS
        or SAFE_TEST_PATTERN.fullmatch(path) is not None
    ):
        surfaces.add("webui")
    return surfaces or {"full"}


def classify_paths(paths: Sequence[str]) -> str:
    checked = [validate_changed_path(path) for path in paths]
    if not checked:
        return "full"
    surfaces = set().union(*(path_surfaces(path) for path in checked))
    if "full" in surfaces:
        return "full"
    return "+".join(surface for surface in SURFACE_ORDER if surface in surfaces)


def append_unique(
    checks: list[tuple[str, ...]], additions: Sequence[tuple[str, ...]]
) -> None:
    for command in additions:
        if command not in checks:
            checks.append(command)


def selected_checks(paths: Sequence[str], scope: str) -> list[tuple[str, ...]]:
    surfaces = set(scope.split("+"))
    checks = list(TEXT_POLICY_CHECKS)
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
    if "evidence" in surfaces:
        checks.insert(0, ("remote/refresh-evidence-manifest.sh", "--check"))
    if surfaces & {
        "browser-preflight",
        "gate-infrastructure",
        "q8-sampler-attribution",
        "webui",
    }:
        checks.insert(
            1 if "evidence" in surfaces else 0,
            ("python3", "remote/check-appliance-paths.py"),
        )
    if "q8-sampler-attribution" in surfaces:
        append_unique(
            checks,
            (
                (
                    "ruff",
                    "check",
                    "remote/run-pull-request-gate.py",
                    "remote/test-census-controls.py",
                    "remote/test-run-pull-request-gate.py",
                    "remote/validate-clock-sidecar.py",
                ),
                (
                    "python3",
                    "-m",
                    "py_compile",
                    "remote/run-pull-request-gate.py",
                    "remote/test-census-controls.py",
                    "remote/test-run-pull-request-gate.py",
                    "remote/validate-clock-sidecar.py",
                ),
                ("sh", "remote/test-telemetry-broker.sh"),
                ("python3", "remote/test-census-controls.py"),
                ("sh", "remote/test-run-raven2-vulkan-kernel-census.sh"),
                ("python3", "remote/test-run-pull-request-gate.py"),
                ("remote/repository-quality-gates.sh", "--declarations"),
            ),
        )
    if "browser-preflight" in surfaces:
        append_unique(
            checks,
            (
                (
                    "ruff",
                    "check",
                    "remote/browser-driver-preflight.py",
                    "remote/test-browser-driver-preflight.py",
                ),
                (
                    "ruff",
                    "format",
                    "--check",
                    "remote/browser-driver-preflight.py",
                    "remote/test-browser-driver-preflight.py",
                ),
                (
                    "mypy",
                    "--strict",
                    "remote/browser-driver-preflight.py",
                    "remote/test-browser-driver-preflight.py",
                ),
                ("ruff", "check", *CI_ROUTING_PYTHON_PATHS),
                ("python3", "-m", "py_compile", *CI_ROUTING_PYTHON_PATHS),
                ("python3", "remote/test-run-pull-request-gate.py"),
                ("python3", "remote/test-merged-pr-gate-reuse.py"),
                (
                    "python3",
                    "remote/check-repository-quality-gate-declarations.py",
                ),
                ("python3", "remote/test-browser-driver-preflight.py"),
                ("remote/test-qwen-home.sh",),
                ("remote/test-feature-roster.sh",),
                ("remote/repository-quality-gates.sh", "--declarations"),
            ),
        )
    if "gate-infrastructure" in surfaces:
        append_unique(
            checks,
            (
                ("remote/test-repository-gate-cells.sh",),
                (
                    "ruff",
                    "check",
                    *GATE_DECLARATION_PYTHON_PATHS,
                ),
                (
                    "python3",
                    "-m",
                    "py_compile",
                    *GATE_DECLARATION_PYTHON_PATHS,
                ),
                (
                    "python3",
                    "remote/test-check-repository-quality-gate-declarations.py",
                ),
                (
                    "python3",
                    "remote/check-repository-quality-gate-declarations.py",
                ),
                ("python3", "remote/test-q8-four-row-select.py"),
                ("python3", "remote/test-ab-shared-series.py"),
                ("ruff", "check", *CI_ROUTING_PYTHON_PATHS),
                ("python3", "-m", "py_compile", *CI_ROUTING_PYTHON_PATHS),
                ("python3", "remote/test-run-pull-request-gate.py"),
                ("python3", "remote/test-merged-pr-gate-reuse.py"),
            ),
        )
    if "ci-routing" in surfaces:
        append_unique(
            checks,
            (
                ("ruff", "check", *CI_ROUTING_PYTHON_PATHS),
                ("python3", "-m", "py_compile", *CI_ROUTING_PYTHON_PATHS),
                ("python3", "remote/test-run-pull-request-gate.py"),
                ("python3", "remote/test-merged-pr-gate-reuse.py"),
            ),
        )
    if "webui" in surfaces:
        append_unique(
            checks,
            (("remote/test-feature-roster.sh",), *UI_TESTS),
        )
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
