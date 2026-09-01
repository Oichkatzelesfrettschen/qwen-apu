"""Exercise private lock opening and same-owner legacy-mode tightening."""

from __future__ import annotations

import fcntl
import importlib.util
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from types import ModuleType

LOCK_WITNESS_PROGRAM = r"""
import fcntl
import os
import stat
import sys
from pathlib import Path

lock_path = Path(sys.argv[1])
descriptor = int(sys.argv[2])
descriptor_status = os.fstat(descriptor)
path_status = lock_path.stat()
if (descriptor_status.st_dev, descriptor_status.st_ino) != (
    path_status.st_dev,
    path_status.st_ino,
):
    raise SystemExit("inherited descriptor names another object")
if stat.S_IMODE(descriptor_status.st_mode) != 0o600:
    raise SystemExit("inherited descriptor mode is not 0600")
probe_descriptor = os.open(lock_path, os.O_RDWR)
try:
    try:
        fcntl.flock(probe_descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        pass
    else:
        raise SystemExit("legacy migration did not retain the exclusive lock")
finally:
    os.close(probe_descriptor)
"""


def load_helper(script_directory: Path) -> ModuleType:
    helper_path = script_directory / "open-verified-lock-descriptor.py"
    specification = importlib.util.spec_from_file_location(
        "open_verified_lock_descriptor", helper_path
    )
    if specification is None or specification.loader is None:
        raise RuntimeError(f"cannot load lock helper: {helper_path}")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def run_helper(
    helper_path: Path,
    lock_path: Path,
    *command: str,
    normalize_legacy_mode: bool = False,
) -> subprocess.CompletedProcess[str]:
    normalization_arguments = (
        ["--normalize-legacy-mode"] if normalize_legacy_mode else []
    )
    return subprocess.run(
        [
            str(helper_path),
            "open",
            *normalization_arguments,
            str(lock_path),
            "9",
            *command,
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=5,
    )


def require_rejection(operation: object, expected_error: type[BaseException]) -> None:
    if not callable(operation):
        raise AssertionError("rejection fixture is not callable")
    try:
        operation()
    except expected_error:
        return
    raise AssertionError(f"operation did not raise {expected_error.__name__}")


def main() -> None:
    script_directory = Path(__file__).resolve().parent
    helper_path = script_directory / "open-verified-lock-descriptor.py"
    helper = load_helper(script_directory)
    checks_run = 0

    with tempfile.TemporaryDirectory(prefix="qwen-lock-helper-") as temporary_text:
        temporary_directory = Path(temporary_text)

        new_lock = temporary_directory / "new.lock"
        new_result = run_helper(
            helper_path, new_lock, "/usr/bin/true", normalize_legacy_mode=True
        )
        if new_result.returncode != 0 or stat.S_IMODE(new_lock.stat().st_mode) != 0o600:
            raise AssertionError(f"new private lock failed: {new_result.stderr}")
        checks_run += 1

        legacy_lock = temporary_directory / "legacy.lock"
        legacy_bytes = b"retained legacy lock bytes\n"
        legacy_lock.write_bytes(legacy_bytes)
        legacy_lock.chmod(0o664)
        legacy_status = legacy_lock.stat()
        migrated_result = run_helper(
            helper_path,
            legacy_lock,
            sys.executable,
            "-c",
            LOCK_WITNESS_PROGRAM,
            str(legacy_lock),
            "9",
            normalize_legacy_mode=True,
        )
        migrated_status = legacy_lock.stat()
        if migrated_result.returncode != 0:
            raise AssertionError(f"legacy migration failed: {migrated_result.stderr}")
        if stat.S_IMODE(migrated_status.st_mode) != 0o600:
            raise AssertionError("legacy migration did not produce mode 0600")
        if (legacy_status.st_dev, legacy_status.st_ino) != (
            migrated_status.st_dev,
            migrated_status.st_ino,
        ):
            raise AssertionError("legacy migration replaced the lock object")
        if legacy_lock.read_bytes() != legacy_bytes:
            raise AssertionError("legacy migration changed retained lock bytes")
        checks_run += 1

        held_lock = temporary_directory / "held-legacy.lock"
        held_bytes = b"held legacy lock bytes\n"
        held_lock.write_bytes(held_bytes)
        held_lock.chmod(0o664)
        held_descriptor = os.open(held_lock, os.O_RDWR)
        try:
            fcntl.flock(held_descriptor, fcntl.LOCK_EX)
            held_result = run_helper(
                helper_path,
                held_lock,
                "/usr/bin/true",
                normalize_legacy_mode=True,
            )
        finally:
            os.close(held_descriptor)
        if held_result.returncode != 2:
            raise AssertionError("held legacy lock did not return refusal status 2")
        if "cannot be tightened while the lock is held" not in held_result.stderr:
            raise AssertionError("held legacy lock refusal reason is absent")
        if stat.S_IMODE(held_lock.stat().st_mode) != 0o664:
            raise AssertionError("held legacy lock mode changed before refusal")
        if held_lock.read_bytes() != held_bytes:
            raise AssertionError("held legacy lock bytes changed before refusal")
        checks_run += 1

        for unadmitted_mode in (0o622, 0o666, 0o777):
            unadmitted_lock = (
                temporary_directory / f"unadmitted-{unadmitted_mode:o}.lock"
            )
            unadmitted_lock.write_bytes(b"unadmitted mode bytes\n")
            unadmitted_lock.chmod(unadmitted_mode)
            unadmitted_result = run_helper(
                helper_path,
                unadmitted_lock,
                "/usr/bin/true",
                normalize_legacy_mode=True,
            )
            if unadmitted_result.returncode != 2:
                raise AssertionError(f"mode {unadmitted_mode:#05o} was normalized")
            if stat.S_IMODE(unadmitted_lock.stat().st_mode) != unadmitted_mode:
                raise AssertionError(f"mode {unadmitted_mode:#05o} changed on refusal")
            if unadmitted_lock.read_bytes() != b"unadmitted mode bytes\n":
                raise AssertionError(f"mode {unadmitted_mode:#05o} changed bytes")
            checks_run += 1

        linked_legacy_lock = temporary_directory / "hard-linked-legacy.lock"
        linked_legacy_alias = temporary_directory / "hard-linked-legacy-alias.lock"
        linked_legacy_lock.write_bytes(b"hard-linked legacy bytes\n")
        linked_legacy_lock.chmod(0o664)
        os.link(linked_legacy_lock, linked_legacy_alias)
        linked_legacy_result = run_helper(
            helper_path,
            linked_legacy_lock,
            "/usr/bin/true",
            normalize_legacy_mode=True,
        )
        if linked_legacy_result.returncode != 2:
            raise AssertionError("hard-linked legacy mode was normalized")
        if stat.S_IMODE(linked_legacy_alias.stat().st_mode) != 0o664:
            raise AssertionError("hard-linked legacy mode changed on refusal")
        if linked_legacy_alias.read_bytes() != b"hard-linked legacy bytes\n":
            raise AssertionError("hard-linked legacy bytes changed on refusal")
        checks_run += 1

        private_lock = temporary_directory / "private-owner-executable.lock"
        private_lock.touch(mode=0o700)
        private_result = run_helper(
            helper_path,
            private_lock,
            "/usr/bin/true",
            normalize_legacy_mode=True,
        )
        if private_result.returncode != 0:
            raise AssertionError(
                f"existing private mode failed: {private_result.stderr}"
            )
        if stat.S_IMODE(private_lock.stat().st_mode) != 0o700:
            raise AssertionError("existing private mode changed")
        checks_run += 1

        link_target = temporary_directory / "link-target.lock"
        link_path = temporary_directory / "linked.lock"
        link_bytes = b"linked target bytes\n"
        link_target.write_bytes(link_bytes)
        link_target.chmod(0o664)
        link_path.symlink_to(link_target)
        link_result = run_helper(
            helper_path, link_path, "/usr/bin/true", normalize_legacy_mode=True
        )
        if link_result.returncode != 2 or not link_path.is_symlink():
            raise AssertionError("final lock symlink was not preserved and refused")
        if link_target.read_bytes() != link_bytes:
            raise AssertionError("final lock symlink changed target bytes")
        if stat.S_IMODE(link_target.stat().st_mode) != 0o664:
            raise AssertionError("final lock symlink changed target mode")
        checks_run += 1

        strict_lock = temporary_directory / "strict-verify.lock"
        strict_lock.touch(mode=0o664)
        strict_lock.chmod(0o664)
        strict_descriptor = os.open(strict_lock, os.O_RDWR)
        try:
            require_rejection(
                lambda: helper.verify_status(strict_lock, strict_descriptor),
                helper.LockDescriptorError,
            )
        finally:
            os.close(strict_descriptor)
        if stat.S_IMODE(strict_lock.stat().st_mode) != 0o664:
            raise AssertionError("strict verification changed a legacy mode")
        checks_run += 1

        foreign_lock = temporary_directory / "foreign-owner.lock"
        foreign_lock.touch(mode=0o664)
        foreign_lock.chmod(0o664)
        original_geteuid = helper.os.geteuid
        helper.os.geteuid = lambda: original_geteuid() + 1
        try:
            require_rejection(
                lambda: helper.open_lock(foreign_lock, 19, True),
                helper.LockDescriptorError,
            )
        finally:
            helper.os.geteuid = original_geteuid
        if stat.S_IMODE(foreign_lock.stat().st_mode) != 0o664:
            raise AssertionError("owner mismatch changed a legacy mode")
        checks_run += 1

        pipe_read, pipe_write = os.pipe()
        try:
            require_rejection(
                lambda: helper.verify_status(new_lock, pipe_read),
                helper.LockDescriptorError,
            )
        finally:
            os.close(pipe_read)
            os.close(pipe_write)
        checks_run += 1

        raced_lock = temporary_directory / "raced.lock"
        retired_lock = temporary_directory / "retired.lock"
        replacement_lock = temporary_directory / "replacement.lock"
        raced_lock.write_bytes(b"original raced bytes\n")
        raced_lock.chmod(0o664)
        replacement_lock.write_bytes(b"replacement bytes\n")
        replacement_lock.chmod(0o666)
        original_flock = helper.fcntl.flock

        def replace_after_lock(descriptor: int, operation: int) -> None:
            original_flock(descriptor, operation)
            raced_lock.rename(retired_lock)
            replacement_lock.rename(raced_lock)

        helper.fcntl.flock = replace_after_lock
        try:
            require_rejection(
                lambda: helper.open_lock(raced_lock, 19, True),
                helper.LockDescriptorError,
            )
        finally:
            helper.fcntl.flock = original_flock
        if raced_lock.read_bytes() != b"replacement bytes\n":
            raise AssertionError("pathname race changed replacement bytes")
        if stat.S_IMODE(raced_lock.stat().st_mode) != 0o666:
            raise AssertionError("pathname race changed replacement mode")
        if stat.S_IMODE(retired_lock.stat().st_mode) != 0o664:
            raise AssertionError("pathname race changed retired inode mode")
        checks_run += 1

    print(f"open_verified_lock_descriptor=accepted checks={checks_run}")


if __name__ == "__main__":
    main()
