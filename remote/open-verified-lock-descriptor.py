#!/usr/bin/env python3
"""Open or verify a private lock leaf and carry its descriptor across exec."""

from __future__ import annotations

import argparse
import errno
import fcntl
import os
import stat
import sys
from pathlib import Path


class LockDescriptorError(RuntimeError):
    """Report a lock leaf or inherited descriptor that violates the contract."""


PRIVATE_LOCK_MODE = 0o600
# The lock leaf is a mutual-exclusion token, so what it needs is one writer:
# the serving user owns it and no other user may write it. FOREIGN_WRITE_BITS
# names the group and other write bits that break that rule, so 0644 and 0640
# are tightened to 0600 while 0664, 0622, and 0666 are refused -- a group-write
# leaf lets a second account take the lock and publish under it.
FOREIGN_WRITE_BITS = 0o022


def same_file(left: os.stat_result, right: os.stat_result) -> bool:
    """Return whether two stat results identify one filesystem object."""
    return left.st_dev == right.st_dev and left.st_ino == right.st_ino


def verify_identity(path: Path, descriptor: int) -> os.stat_result:
    """Verify one descriptor and its pathname identify a same-owner regular leaf."""
    descriptor_status = os.fstat(descriptor)
    if not stat.S_ISREG(descriptor_status.st_mode):
        raise LockDescriptorError(f"lock descriptor is not regular: {path}")
    effective_uid = os.geteuid()
    if descriptor_status.st_uid != effective_uid:
        raise LockDescriptorError(
            f"lock descriptor uid {descriptor_status.st_uid} differs from "
            f"effective uid {effective_uid}: {path}"
        )
    # One inode reachable by one name: a same-owner private hard link would
    # otherwise make an unrelated file the synchronization object.
    if descriptor_status.st_nlink != 1:
        raise LockDescriptorError(f"lock leaf has {descriptor_status.st_nlink} hard links: {path}")
    try:
        path_status = path.lstat()
    except OSError as error:
        raise LockDescriptorError(f"lock path is unreadable: {path}: {error}") from error
    if not stat.S_ISREG(path_status.st_mode):
        raise LockDescriptorError(f"lock path is not a regular leaf: {path}")
    if not same_file(path_status, descriptor_status):
        raise LockDescriptorError(f"lock path changed while opening: {path}")
    return descriptor_status


def verify_status(path: Path, descriptor: int) -> None:
    """Verify one descriptor and its pathname identify a private regular leaf."""
    descriptor_status = verify_identity(path, descriptor)
    descriptor_mode = stat.S_IMODE(descriptor_status.st_mode)
    if descriptor_mode & 0o077:
        raise LockDescriptorError(
            f"lock descriptor mode {descriptor_mode:#05o} grants group or other access: {path}"
        )


def normalize_legacy_mode(path: Path, descriptor: int, descriptor_status: os.stat_result) -> None:
    """Tighten an unlocked owner-writable legacy mode through its descriptor."""
    descriptor_mode = stat.S_IMODE(descriptor_status.st_mode)
    if not descriptor_mode & 0o077:
        return
    if descriptor_mode & FOREIGN_WRITE_BITS:
        raise LockDescriptorError(
            f"lock descriptor mode {descriptor_mode:#05o} grants write access to "
            f"another user: {path}"
        )
    if descriptor_status.st_nlink != 1:
        raise LockDescriptorError(f"legacy lock has multiple hard links: {path}")
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as error:
        if error.errno in (errno.EACCES, errno.EAGAIN):
            raise LockDescriptorError(
                f"legacy lock mode cannot be tightened while the lock is held: {path}"
            ) from None
        raise
    # Revalidate after exclusive acquisition so a pathname replacement cannot
    # redirect or authorize the descriptor-bound permission change.
    locked_status = verify_identity(path, descriptor)
    locked_mode = stat.S_IMODE(locked_status.st_mode)
    if locked_mode & 0o077 and not locked_mode & FOREIGN_WRITE_BITS:
        if locked_status.st_nlink != 1:
            raise LockDescriptorError(f"legacy lock gained a hard link: {path}")
        os.fchmod(descriptor, PRIVATE_LOCK_MODE)
    verify_status(path, descriptor)


def open_lock(path: Path, descriptor_number: int, normalize_admitted_legacy_mode: bool) -> None:
    """Open a lock leaf without following links or truncating retained bytes."""
    flags = os.O_RDWR | os.O_CREAT | os.O_CLOEXEC | os.O_NOFOLLOW
    opened_descriptor = os.open(path, flags, PRIVATE_LOCK_MODE)
    try:
        descriptor_status = verify_identity(path, opened_descriptor)
        if normalize_admitted_legacy_mode:
            normalize_legacy_mode(path, opened_descriptor, descriptor_status)
        verify_status(path, opened_descriptor)
        if opened_descriptor != descriptor_number:
            os.dup2(opened_descriptor, descriptor_number, inheritable=True)
        else:
            os.set_inheritable(descriptor_number, True)
    finally:
        if opened_descriptor != descriptor_number:
            os.close(opened_descriptor)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="action", required=True)

    open_parser = subparsers.add_parser("open")
    open_parser.add_argument("--normalize-legacy-mode", action="store_true")
    open_parser.add_argument("path", type=Path)
    open_parser.add_argument("descriptor", type=int)
    open_parser.add_argument("command", nargs=argparse.REMAINDER)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("path", type=Path)
    verify_parser.add_argument("descriptor", type=int)
    return parser.parse_args()


def validate_descriptor_number(descriptor_number: int) -> None:
    if descriptor_number < 3:
        raise LockDescriptorError(
            f"lock descriptor must preserve standard streams: {descriptor_number}"
        )


def main() -> int:
    arguments = parse_arguments()
    try:
        validate_descriptor_number(arguments.descriptor)
        if arguments.action == "verify":
            verify_status(arguments.path, arguments.descriptor)
            return 0
        if not arguments.command:
            raise LockDescriptorError("open requires a command to execute")
        open_lock(
            arguments.path,
            arguments.descriptor,
            arguments.normalize_legacy_mode,
        )
        os.execvpe(arguments.command[0], arguments.command, os.environ)
    except (LockDescriptorError, OSError) as error:
        print(f"verified_lock_descriptor=rejected reason={error}", file=sys.stderr)
        return 2
    raise AssertionError("os.execvpe returned")


if __name__ == "__main__":
    raise SystemExit(main())
