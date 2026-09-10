#!/usr/bin/env python3
"""Preflight and own one browser acquisition through its declared Python."""

from __future__ import annotations

import argparse
import hashlib
import importlib
import importlib.metadata
import json
import os
import pathlib
import signal
import subprocess
import sys
import tempfile
import time
from typing import Any

SCHEMA = "qwen-browser-driver-preflight-v1"
DEPENDENCY_IMPORT = "marionette_driver.marionette"
DEPENDENCY_DISTRIBUTION = "marionette_driver"
TERMINATION_GRACE_SECONDS = 10.0


class PreflightRefusal(RuntimeError):
    """Name the first preflight stage that refused the acquisition."""

    def __init__(self, stage: str, detail: str) -> None:
        super().__init__(detail)
        self.stage = stage


def file_sha256(path: pathlib.Path) -> str:
    """Return the SHA-256 identity of one regular file."""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require_file(path: pathlib.Path, role: str, executable: bool = False) -> None:
    """Require one regular file and its optional execute permission."""
    if not path.is_file():
        raise PreflightRefusal(role, f"the {role} is absent")
    if executable and not os.access(path, os.X_OK):
        raise PreflightRefusal(role, f"the {role} is not executable")


def require_runtime_result(runtime_root: pathlib.Path, record: pathlib.Path) -> None:
    """Require a fresh result directory beneath the declared runtime root."""
    expected_parent = runtime_root.resolve() / "results"
    resolved_parent = record.parent.resolve()
    if resolved_parent != expected_parent:
        raise PreflightRefusal(
            "record_directory",
            "the record directory must be one direct child of the runtime results root",
        )
    if record.exists():
        raise PreflightRefusal(
            "record_directory", "the record directory already exists"
        )


def write_json(path: pathlib.Path, value: dict[str, Any]) -> None:
    """Atomically write one deterministic JSON record."""
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, path)
    except BaseException:
        pathlib.Path(temporary_name).unlink(missing_ok=True)
        raise


def module_identity(module_name: str) -> tuple[str, str]:
    """Import one dependency and return its version and source digest."""
    try:
        module = importlib.import_module(module_name)
    except Exception as error:
        raise PreflightRefusal(
            "dependency_import",
            f"the required browser dependency failed to import: {error}",
        ) from error
    module_path_text = getattr(module, "__file__", None)
    if not module_path_text:
        raise PreflightRefusal(
            "dependency_identity",
            "the required browser dependency has no source identity",
        )
    module_path = pathlib.Path(module_path_text)
    require_file(module_path, "dependency_identity")
    environment_root = pathlib.Path(sys.prefix).resolve()
    try:
        module_path.resolve().relative_to(environment_root)
    except ValueError as error:
        raise PreflightRefusal(
            "dependency_identity",
            "the required browser dependency resolves outside the declared environment",
        ) from error
    try:
        distribution = importlib.metadata.distribution(DEPENDENCY_DISTRIBUTION)
    except importlib.metadata.PackageNotFoundError as error:
        raise PreflightRefusal(
            "dependency_identity", "the required browser distribution has no metadata"
        ) from error
    try:
        distribution.locate_file("").resolve().relative_to(environment_root)
    except ValueError as error:
        raise PreflightRefusal(
            "dependency_identity",
            "the required browser distribution resolves outside the declared environment",
        ) from error
    return distribution.version, file_sha256(module_path)


def interpreter_identity(expected_python: pathlib.Path) -> dict[str, str]:
    """Require the running interpreter to be the declared virtual environment."""
    actual_python = pathlib.Path(sys.executable).absolute()
    expected_absolute = expected_python.absolute()
    if actual_python != expected_absolute:
        raise PreflightRefusal(
            "interpreter_selection",
            "the running interpreter differs from the declared browser Python",
        )
    if pathlib.Path(sys.prefix) == pathlib.Path(sys.base_prefix):
        raise PreflightRefusal(
            "interpreter_selection",
            "the declared browser Python is not a virtual environment",
        )
    if pathlib.Path(sys.prefix).absolute() != expected_absolute.parent.parent:
        raise PreflightRefusal(
            "interpreter_selection",
            "the running virtual environment differs from the declared browser environment",
        )
    require_file(expected_absolute, "browser_python", executable=True)
    return {
        "role": "browser_environment_python",
        "sha256": file_sha256(expected_absolute.resolve()),
        "version": sys.version.split()[0],
    }


def parse_arguments() -> argparse.Namespace:
    """Parse the bounded runner interface."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected-python", required=True, type=pathlib.Path)
    parser.add_argument("--runtime-root", required=True, type=pathlib.Path)
    parser.add_argument("--driver", required=True, type=pathlib.Path)
    parser.add_argument("--firefox-bin", required=True, type=pathlib.Path)
    parser.add_argument("--record-directory", required=True, type=pathlib.Path)
    parser.add_argument("--driver-timeout-seconds", type=float, default=1800.0)
    parser.add_argument("--preflight-only", action="store_true")
    parser.add_argument("driver_arguments", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()
    if arguments.driver_timeout_seconds <= 0:
        parser.error("--driver-timeout-seconds must be positive")
    if arguments.driver_arguments[:1] == ["--"]:
        arguments.driver_arguments = arguments.driver_arguments[1:]
    if any(
        argument == "--firefox-bin" or argument.startswith("--firefox-bin=")
        for argument in arguments.driver_arguments
    ):
        parser.error("the preflight owns the driver's --firefox-bin argument")
    return arguments


def terminate_process_group(process: subprocess.Popen[bytes]) -> str:
    """Terminate one owned process group within the cleanup deadline."""
    if process.poll() is not None:
        return "already_exited"
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=TERMINATION_GRACE_SECONDS)
        return "terminated"
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=TERMINATION_GRACE_SECONDS)
        return "killed"


def main() -> int:
    """Refuse before driver execution or own the accepted driver process."""
    arguments = parse_arguments()
    runtime_root = arguments.runtime_root.absolute()
    record_directory = arguments.record_directory.absolute()
    expected_python = arguments.expected_python.absolute()
    driver = arguments.driver.absolute()
    firefox = arguments.firefox_bin.absolute()

    require_runtime_result(runtime_root, record_directory)
    record_directory.mkdir(mode=0o700)
    private_record = record_directory / "preflight-private.json"
    public_record = record_directory / "preflight-public.json"
    private: dict[str, Any] = {
        "schema": SCHEMA,
        "status": "refused",
        "driver_execution": "not_started",
        "paths": {
            "driver": str(driver),
            "expected_python": str(expected_python),
            "firefox": str(firefox),
            "record_directory": str(record_directory),
            "runtime_root": str(runtime_root),
        },
    }
    public: dict[str, Any] = {
        "schema": SCHEMA,
        "status": "refused",
        "driver_execution": "not_started",
    }

    try:
        python_identity = interpreter_identity(expected_python)
        require_file(driver, "acquisition_driver")
        require_file(firefox, "firefox_executable", executable=True)
        dependency_version, dependency_digest = module_identity(DEPENDENCY_IMPORT)
        identities = {
            "acquisition_driver": {
                "role": "acquisition_driver",
                "sha256": file_sha256(driver),
            },
            "browser_dependency": {
                "import": DEPENDENCY_IMPORT,
                "role": "browser_dependency",
                "sha256": dependency_digest,
                "version": dependency_version,
            },
            "browser_python": python_identity,
            "firefox_executable": {
                "role": "firefox_executable",
                "sha256": file_sha256(firefox),
            },
        }
        private["identities"] = identities
        public["identities"] = identities
        private["status"] = "accepted"
        public["status"] = "accepted"
    except PreflightRefusal as error:
        private["failure_stage"] = error.stage
        private["failure_detail"] = str(error)
        public["failure_stage"] = error.stage
        write_json(private_record, private)
        write_json(public_record, public)
        return 2

    if arguments.preflight_only:
        private["driver_execution"] = "withheld_preflight_only"
        public["driver_execution"] = "withheld_preflight_only"
        write_json(private_record, private)
        write_json(public_record, public)
        return 0

    started_monotonic_ns = time.monotonic_ns()
    process = subprocess.Popen(
        [
            str(expected_python),
            str(driver),
            "--firefox-bin",
            str(firefox),
            *arguments.driver_arguments,
        ],
        start_new_session=True,
    )
    private["driver_execution"] = "started"
    public["driver_execution"] = "started"
    private["driver_pid"] = process.pid
    try:
        driver_status = process.wait(timeout=arguments.driver_timeout_seconds)
        cleanup = "already_exited"
    except subprocess.TimeoutExpired:
        driver_status = 124
        cleanup = terminate_process_group(process)
    private["driver_status"] = driver_status
    private["cleanup"] = cleanup
    private["elapsed_ns"] = time.monotonic_ns() - started_monotonic_ns
    public["driver_status"] = driver_status
    public["cleanup"] = cleanup
    public["driver_execution"] = "completed" if driver_status == 0 else "failed"
    private["driver_execution"] = public["driver_execution"]
    write_json(private_record, private)
    write_json(public_record, public)
    return driver_status


if __name__ == "__main__":
    raise SystemExit(main())
