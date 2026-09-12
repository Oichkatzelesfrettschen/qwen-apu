#!/usr/bin/env python3
"""Verify that a named live process holds the shared Vulkan workload lease."""

from __future__ import annotations

import argparse
import csv
import errno
import fcntl
import os
import re
import stat
from pathlib import Path

SCHEMA = "fixed64-vulkan-external-lease-v1"
EXPECTED_KEYS = (
    "schema",
    "lock_path",
    "holder_pid",
    "holder_start_time_ticks",
    "holder_fd",
    "source_revision",
)


class LeaseError(ValueError):
    """Report a lease proof that does not identify a live kernel lock."""


def read_proof(path: Path) -> dict[str, str]:
    path_status = path.lstat()
    if not stat.S_ISREG(path_status.st_mode) or path.is_symlink():
        raise LeaseError(f"external lease proof is not a regular unlinked file: {path}")
    if path_status.st_uid != os.geteuid():
        raise LeaseError(f"external lease proof has another owner: {path}")
    if stat.S_IMODE(path_status.st_mode) & 0o077:
        raise LeaseError(f"external lease proof grants group or other access: {path}")
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if tuple(reader.fieldnames or ()) != ("key", "value"):
            raise LeaseError(f"external lease proof fields differ: {path}")
        rows = list(reader)
    if any(None in row for row in rows):
        raise LeaseError(f"external lease proof contains an extra field: {path}")
    values = {row["key"]: row["value"] for row in rows}
    if len(values) != len(rows) or tuple(values) != EXPECTED_KEYS:
        raise LeaseError(f"external lease proof keys differ: {path}")
    if values["schema"] != SCHEMA:
        raise LeaseError(f"external lease proof schema differs: {path}")
    if re.fullmatch(r"[0-9a-f]{40}", values["source_revision"]) is None:
        raise LeaseError(f"external lease proof source revision is malformed: {path}")
    return values


def process_start_time(pid: int) -> int:
    stat_text = Path(f"/proc/{pid}/stat").read_text(encoding="ascii")
    closing_parenthesis = stat_text.rfind(")")
    if closing_parenthesis < 0:
        raise LeaseError(f"holder process stat is malformed: {pid}")
    fields_after_command = stat_text[closing_parenthesis + 2 :].split()
    return int(fields_after_command[19])


def descriptor_carries_lock(
    pid: int,
    descriptor: int,
    lock_status: os.stat_result,
) -> bool:
    """Bind one live descriptor to the inherited whole-file FLOCK."""
    expected_major = os.major(lock_status.st_dev)
    expected_minor = os.minor(lock_status.st_dev)
    expected_inode = lock_status.st_ino
    descriptor_information = Path(f"/proc/{pid}/fdinfo/{descriptor}")
    for line in descriptor_information.read_text(encoding="ascii").splitlines():
        if not line.startswith("lock:"):
            continue
        fields = line.removeprefix("lock:").split()
        if len(fields) != 8 or fields[1:4] != ["FLOCK", "ADVISORY", "WRITE"]:
            continue
        if fields[6:] != ["0", "EOF"]:
            continue
        device_fields = fields[5].split(":")
        if len(device_fields) != 3:
            continue
        major_text, minor_text, inode_text = device_fields
        try:
            observed = (int(major_text, 16), int(minor_text, 16), int(inode_text))
        except ValueError:
            continue
        if observed == (expected_major, expected_minor, expected_inode):
            return True
    return False


def same_file(first: os.stat_result, second: os.stat_result) -> bool:
    return (first.st_dev, first.st_ino) == (second.st_dev, second.st_ino)


def verify_holder_identity(
    holder_pid: int,
    expected_start_time: int,
    holder_fd: int,
    lock_status: os.stat_result,
) -> None:
    if process_start_time(holder_pid) != expected_start_time:
        raise LeaseError(f"external lease holder identity changed: {holder_pid}")
    descriptor_status = Path(f"/proc/{holder_pid}/fd/{holder_fd}").stat()
    if not same_file(descriptor_status, lock_status):
        raise LeaseError("external lease holder descriptor names another file")
    if not descriptor_carries_lock(holder_pid, holder_fd, lock_status):
        raise LeaseError("holder fdinfo does not bind the descriptor to the workload lease")


def verify(proof_path: Path, expected_lock_path: Path) -> None:
    values = read_proof(proof_path)
    if values["lock_path"] != str(expected_lock_path):
        raise LeaseError(
            f"external lease proof names {values['lock_path']} instead of {expected_lock_path}"
        )
    if not expected_lock_path.is_absolute():
        raise LeaseError("expected workload lease path is not absolute")

    try:
        holder_pid = int(values["holder_pid"])
        expected_start_time = int(values["holder_start_time_ticks"])
        holder_fd = int(values["holder_fd"])
    except ValueError as error:
        raise LeaseError("external lease proof carries a non-integer process field") from error
    if holder_pid <= 0 or expected_start_time <= 0 or holder_fd != 8:
        raise LeaseError("external lease proof carries an invalid process field")

    descriptor = os.open(expected_lock_path, os.O_RDWR | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        lock_status = os.fstat(descriptor)
        path_status = expected_lock_path.lstat()
        if not stat.S_ISREG(lock_status.st_mode) or not same_file(path_status, lock_status):
            raise LeaseError(f"workload lease path changed or is not regular: {expected_lock_path}")
        verify_holder_identity(holder_pid, expected_start_time, holder_fd, lock_status)
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            if error.errno not in (errno.EACCES, errno.EAGAIN):
                raise
        else:
            fcntl.flock(descriptor, fcntl.LOCK_UN)
            raise LeaseError("workload lease permits a second exclusive holder")
        final_path_status = expected_lock_path.lstat()
        if not same_file(final_path_status, lock_status):
            raise LeaseError("workload lease pathname changed during verification")
        verify_holder_identity(holder_pid, expected_start_time, holder_fd, lock_status)
    finally:
        os.close(descriptor)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("proof_path", type=Path)
    parser.add_argument("expected_lock_path", type=Path)
    arguments = parser.parse_args()
    try:
        verify(arguments.proof_path, arguments.expected_lock_path)
    except (LeaseError, OSError, UnicodeError) as error:
        print(f"external_vulkan_lease=rejected reason={error}")
        return 1
    print(
        "external_vulkan_lease=accepted "
        f"proof={arguments.proof_path} lock={arguments.expected_lock_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
