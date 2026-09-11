"""`python -m qwen_apu.ci` runs the migration ratchet, then ruff, mypy, and
pytest in that order, stopping at the first job that fails. `ratchet` runs
the ratchet alone and `list` prints the job names without running any of
them.

Each hosted tool runs as a resolved argv list rather than a shell string, and
a tool the environment does not provide is skipped rather than failing the
run, since a contributor iterating on the ratchet alone need not have mypy or
pytest installed.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

from qwen_apu.ci.ratchet import run as run_ratchet

_ROOT = Path(__file__).resolve().parents[3]
_JOB_NAMES = ["ratchet", "ruff-check", "ruff-format", "mypy", "pytest"]


def _targets(root: Path) -> list[str]:
    targets = ["src", "tests"]
    if (root / "bootstrap.py").is_file():
        targets.append("bootstrap.py")
    return targets


def _tool_argv(tool: str, *args: str) -> list[str] | None:
    resolved = shutil.which(tool)
    if resolved is None:
        return None
    return [resolved, *args]


def _tool_jobs(root: Path) -> list[tuple[str, list[str] | None]]:
    targets = _targets(root)
    return [
        ("ruff-check", _tool_argv("ruff", "check", *targets)),
        ("ruff-format", _tool_argv("ruff", "format", "--check", *targets)),
        ("mypy", _tool_argv("mypy")),
        ("pytest", _tool_argv("pytest", "-q", "tests")),
    ]


def job_names() -> list[str]:
    return list(_JOB_NAMES)


def _run_ratchet(root: Path) -> int:
    violations = run_ratchet(root)
    for violation in violations:
        print(violation.render())
    if violations:
        print(f"qwen_apu.ci: ratchet failed with {len(violations)} violation(s)", file=sys.stderr)
        return 1
    print("qwen_apu.ci: ratchet clean")
    return 0


def _run_tool_job(name: str, argv: list[str], *, cwd: Path) -> int:
    print(f"qwen_apu.ci: running {name}: {' '.join(argv)}")
    completed = subprocess.run(argv, cwd=cwd, check=False)  # noqa: S603
    return completed.returncode


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    command = args[0] if args else "all"

    if command == "list":
        for name in job_names():
            print(name)
        return 0

    if command not in {"all", "ratchet"}:
        print(
            f"qwen_apu.ci: unknown command {command!r}; expected all, ratchet, or list",
            file=sys.stderr,
        )
        return 2

    root = _ROOT
    status = _run_ratchet(root)
    if status != 0:
        return status
    if command == "ratchet":
        return 0

    for name, job_argv in _tool_jobs(root):
        if job_argv is None:
            print(f"qwen_apu.ci: skipping {name}, tool not found")
            continue
        status = _run_tool_job(name, job_argv, cwd=root)
        if status != 0:
            print(f"qwen_apu.ci: {name} failed with exit {status}", file=sys.stderr)
            return status

    print("qwen_apu.ci: all jobs passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
