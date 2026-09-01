#!/usr/bin/env python3
"""Open or verify a private lock leaf and carry its descriptor across exec."""

from __future__ import annotations

import argparse
import os
import stat
import sys
from pathlib import Path


class LockDescriptorError(RuntimeError):
    """Report a lock leaf or inherited descriptor that violates the contract."""


def same_file(left: os.stat_result, right: os.stat_result) -> bool:
    """Return whether two stat results identify one filesystem object."""
    return left.st_dev == right.st_dev and left.st_ino == right.st_ino


def verify_status(path: Path, descriptor: int) -> None:
    """Verify one descriptor and its pathname identify a private regular leaf."""
    descriptor_status = os.fstat(descriptor)
    if not stat.S_ISREG(descriptor_status.st_mode):
        raise LockDescriptorError(f"lock descriptor is not regular: {path}")
    effective_uid = os.geteuid()
    if descriptor_status.st_uid != effective_uid:
        raise LockDescriptorError(
            f"lock descriptor uid {descriptor_status.st_uid} differs from "
            f"effective uid {effective_uid}: {path}"
        )
    descriptor_mode = stat.S_IMODE(descriptor_status.st_mode)
    if descriptor_mode & 0o077:
        raise LockDescriptorError(
            f"lock descriptor mode {descriptor_mode:#05o} grants group or other "
            f"access: {path}"
        )
    try:
        path_status = path.lstat()
    except OSError as error:
        raise LockDescriptorError(
            f"lock path is unreadable: {path}: {error}"
        ) from error
    if not stat.S_ISREG(path_status.st_mode):
        raise LockDescriptorError(f"lock path is not a regular leaf: {path}")
    if not same_file(path_status, descriptor_status):
        raise LockDescriptorError(f"lock path changed while opening: {path}")


def open_lock(path: Path, descriptor_number: int) -> None:
    """Open a lock leaf without following links or truncating retained bytes."""
    flags = os.O_RDWR | os.O_CREAT | os.O_CLOEXEC | os.O_NOFOLLOW
    opened_descriptor = os.open(path, flags, 0o600)
    try:
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
        open_lock(arguments.path, arguments.descriptor)
        os.execvpe(arguments.command[0], arguments.command, os.environ)
    except (LockDescriptorError, OSError) as error:
        print(f"verified_lock_descriptor=rejected reason={error}", file=sys.stderr)
        return 2
    raise AssertionError("os.execvpe returned")


if __name__ == "__main__":
    raise SystemExit(main())
