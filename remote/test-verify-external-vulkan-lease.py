"""Exercise descriptor-bound external Vulkan lease verification."""

from __future__ import annotations

import importlib.util
import json
import os
import select
import subprocess
import sys
import tempfile
from pathlib import Path
from types import ModuleType
from typing import Any, cast

HOLDER_PROGRAM = r"""
import fcntl
import json
import os
import sys
from pathlib import Path

lock_path = Path(sys.argv[1])
descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
fcntl.flock(descriptor, fcntl.LOCK_EX)
if descriptor != 8:
    os.dup2(descriptor, 8, inheritable=True)
    os.close(descriptor)
else:
    os.set_inheritable(8, True)
stat_text = Path("/proc/self/stat").read_text(encoding="ascii")
start_time_ticks = int(stat_text[stat_text.rfind(")") + 2 :].split()[19])
print(json.dumps({"pid": os.getpid(), "start_time_ticks": start_time_ticks}), flush=True)
sys.stdin.buffer.read()
"""

INHERITED_CARRIER_PROGRAM = r"""
import fcntl
import json
import os
import sys
from pathlib import Path


def identity():
    stat_text = Path("/proc/self/stat").read_text(encoding="ascii")
    return {
        "pid": os.getpid(),
        "start_time_ticks": int(stat_text[stat_text.rfind(")") + 2 :].split()[19]),
    }


lock_path = Path(sys.argv[1])
descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
fcntl.flock(descriptor, fcntl.LOCK_EX)
if descriptor != 8:
    os.dup2(descriptor, 8, inheritable=True)
    os.close(descriptor)
else:
    os.set_inheritable(8, True)
print(json.dumps(identity()), flush=True)
carrier_pid = os.fork()
if carrier_pid == 0:
    print(json.dumps(identity()), flush=True)
    sys.stdin.buffer.read()
    raise SystemExit(0)
os._exit(0)
"""

UNLOCKED_DESCRIPTOR_PROGRAM = r"""
import json
import os
import sys
from pathlib import Path

lock_path = Path(sys.argv[1])
descriptor = os.open(lock_path, os.O_RDWR)
if descriptor != 8:
    os.dup2(descriptor, 8, inheritable=True)
    os.close(descriptor)
else:
    os.set_inheritable(8, True)
stat_text = Path("/proc/self/stat").read_text(encoding="ascii")
start_time_ticks = int(stat_text[stat_text.rfind(")") + 2 :].split()[19])
print(json.dumps({"pid": os.getpid(), "start_time_ticks": start_time_ticks}), flush=True)
sys.stdin.buffer.read()
"""


def load_verifier(script_directory: Path) -> ModuleType:
    verifier_path = script_directory / "verify-external-vulkan-lease.py"
    specification = importlib.util.spec_from_file_location(
        "verify_external_vulkan_lease", verifier_path
    )
    if specification is None or specification.loader is None:
        raise RuntimeError(f"cannot load verifier: {verifier_path}")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def start_holder(lock_path: Path) -> tuple[subprocess.Popen[bytes], dict[str, Any]]:
    process = subprocess.Popen(
        [sys.executable, "-c", HOLDER_PROGRAM, str(lock_path)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert process.stdout is not None
    ready_line = process.stdout.readline()
    if not ready_line:
        _, stderr = process.communicate(timeout=5)
        raise RuntimeError(f"lease holder failed: {stderr.decode(errors='replace')}")
    return process, json.loads(ready_line)


def start_program(
    program: str,
    lock_path: Path,
) -> tuple[subprocess.Popen[bytes], dict[str, Any]]:
    process = subprocess.Popen(
        [sys.executable, "-c", program, str(lock_path)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert process.stdout is not None
    ready_line = process.stdout.readline()
    if not ready_line:
        _, stderr = process.communicate(timeout=5)
        raise RuntimeError(f"descriptor process failed: {stderr.decode(errors='replace')}")
    return process, json.loads(ready_line)


def stop_holder(process: subprocess.Popen[bytes]) -> None:
    if process.stdin is not None:
        process.stdin.close()
    process.wait(timeout=5)
    if process.returncode != 0:
        assert process.stderr is not None
        raise RuntimeError(
            f"lease holder exited {process.returncode}: "
            f"{process.stderr.read().decode(errors='replace')}"
        )


def stop_orphaned_carrier(process: subprocess.Popen[bytes], carrier_pid: int) -> None:
    pid_descriptor = os.pidfd_open(carrier_pid)
    try:
        if process.stdin is not None:
            process.stdin.close()
        poller = select.poll()
        poller.register(pid_descriptor, select.POLLIN)
        if not poller.poll(5000):
            os.kill(carrier_pid, 15)
            if not poller.poll(5000):
                raise RuntimeError(f"lease carrier did not exit: {carrier_pid}")
    finally:
        os.close(pid_descriptor)
        if process.stdout is not None:
            process.stdout.close()
        if process.stderr is not None:
            process.stderr.close()


def write_proof(path: Path, lock_path: Path, identity: dict[str, Any]) -> None:
    path.write_text(
        "key\tvalue\n"
        "schema\tfixed64-vulkan-external-lease-v1\n"
        f"lock_path\t{lock_path}\n"
        f"holder_pid\t{identity['pid']}\n"
        f"holder_start_time_ticks\t{identity['start_time_ticks']}\n"
        "holder_fd\t8\n"
        f"source_revision\t{'0' * 40}\n",
        encoding="utf-8",
    )
    path.chmod(0o600)


def main() -> int:
    script_directory = Path(__file__).resolve().parent
    verifier = cast(Any, load_verifier(script_directory))
    with tempfile.TemporaryDirectory(prefix="verify-vulkan-lease-") as temporary:
        work_directory = Path(temporary)
        lock_path = work_directory / "vulkan-workload.lock"
        displaced_path = work_directory / "vulkan-workload.lock.displaced"
        proof_path = work_directory / "external-lease.tsv"
        original_holder, original_identity = start_holder(lock_path)
        replacement_holder: subprocess.Popen[bytes] | None = None
        try:
            write_proof(proof_path, lock_path, original_identity)
            verifier.verify(proof_path, lock_path)

            original_descriptor_check = verifier.descriptor_carries_lock
            replacement_started = False

            def replace_after_holder_check(
                pid: int,
                descriptor: int,
                lock_status: Any,
            ) -> bool:
                nonlocal replacement_holder, replacement_started
                result = cast(
                    bool,
                    original_descriptor_check(pid, descriptor, lock_status),
                )
                if result and not replacement_started:
                    lock_path.rename(displaced_path)
                    replacement_holder, _ = start_holder(lock_path)
                    replacement_started = True
                return result

            verifier.descriptor_carries_lock = replace_after_holder_check
            try:
                verifier.verify(proof_path, lock_path)
            except verifier.LeaseError:
                pass
            else:
                raise AssertionError("verifier accepted contention from a replacement lock inode")
            if not replacement_started:
                raise AssertionError("inode-replacement interleaving did not execute")

            verifier.descriptor_carries_lock = original_descriptor_check
            unlocked_process, unlocked_identity = start_program(
                UNLOCKED_DESCRIPTOR_PROGRAM,
                displaced_path,
            )
            try:
                write_proof(proof_path, displaced_path, unlocked_identity)
                try:
                    verifier.verify(proof_path, displaced_path)
                except verifier.LeaseError:
                    pass
                else:
                    raise AssertionError(
                        "verifier accepted an unlocked descriptor for a contended inode"
                    )
            finally:
                stop_holder(unlocked_process)
        finally:
            if replacement_holder is not None:
                stop_holder(replacement_holder)
            stop_holder(original_holder)

        inherited_process, original_identity = start_program(
            INHERITED_CARRIER_PROGRAM,
            lock_path,
        )
        assert inherited_process.stdout is not None
        carrier_line = inherited_process.stdout.readline()
        if not carrier_line:
            raise RuntimeError("inherited lease carrier did not report readiness")
        carrier_identity = json.loads(carrier_line)
        inherited_process.wait(timeout=5)
        if inherited_process.returncode != 0:
            raise RuntimeError("original inherited-lease holder failed")
        if Path(f"/proc/{original_identity['pid']}").exists():
            raise AssertionError("original inherited-lease holder remains live")
        carrier_pid = int(carrier_identity["pid"])
        try:
            write_proof(proof_path, lock_path, carrier_identity)
            verifier.verify(proof_path, lock_path)
            checker_environment = os.environ.copy()
            checker_environment["QWEN_VULKAN_EXTERNAL_LEASE_PROOF"] = str(proof_path)
            checker_environment["QWEN_IMAGE_RUNTIME_PATTERN"] = (
                "^qwen-apu-test-runtime-that-cannot-exist$"
            )
            checker = subprocess.run(
                [
                    str(script_directory / "image-teardown-check.sh"),
                    str(work_directory),
                ],
                check=False,
                capture_output=True,
                env=checker_environment,
                text=True,
            )
            if checker.returncode != 0:
                raise AssertionError(
                    "teardown rejected an inherited lease carrier:\n"
                    f"stdout:\n{checker.stdout}\nstderr:\n{checker.stderr}"
                )
        finally:
            stop_orphaned_carrier(inherited_process, carrier_pid)
        try:
            verifier.verify(proof_path, lock_path)
        except (verifier.LeaseError, OSError):
            pass
        else:
            raise AssertionError("verifier accepted a departed inherited carrier")
    print("test_verify_external_vulkan_lease=accepted")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
