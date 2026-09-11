"""The content-addressed artifact store: one digest names one immutable directory.

A native bundle installs under `<store root>/<bundle digest>/`, so two installs
of one bundle converge on one directory and two different bundles never share
one. `atomic_install` moves a fully staged directory into place with
`os.replace`, which the kernel performs as one rename within a filesystem, so a
reader sees either the previous directory or the complete new one.

An existing digest directory is the interesting case. Two builds that produce
identical bytes install once and the second is a no-op; a digest directory whose
contents differ from the staged tree is a digest collision or a corrupted store,
and `atomic_install` raises rather than overwriting, because the digest is the
only identity the rest of the install path has.
"""

from __future__ import annotations

import hashlib
import os
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

_READ_CHUNK = 1024 * 1024
_DIGEST_LENGTH = 64
_HEX_DIGITS = frozenset("0123456789abcdef")


class ArtifactStoreError(RuntimeError):
    """A store path, digest, or install transition fails its own rule."""


@dataclass(frozen=True, slots=True)
class InstallOutcome:
    """What `atomic_install` did: the final directory and whether it created it."""

    path: Path
    created: bool


def require_digest(digest: str) -> str:
    """A store key is 64 lowercase hex digits, the shape `hashlib.sha256().hexdigest()` returns."""
    if len(digest) != _DIGEST_LENGTH or not set(digest) <= _HEX_DIGITS:
        raise ArtifactStoreError(f"not a sha256 hex digest: {digest}")
    return digest


def store_path(root: Path, digest: str) -> Path:
    """`<root>/<digest>`, with the digest checked before it becomes a path component."""
    return root / require_digest(digest)


def digest_file(path: Path) -> str:
    """Stream one file through sha256 in 1 MiB reads.

    A llama-server binary reaches tens of megabytes and a bundle carries
    several, so the whole file never enters memory at once.
    """
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(_READ_CHUNK)
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


def digest_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _walk_files(root: Path) -> Iterator[tuple[str, Path]]:
    """Every regular file under `root` as `(relative posix path, path)`, sorted.

    A symbolic link or a device node under a staged tree is content the digest
    cannot describe, so the walk refuses one rather than ignoring it.
    """
    entries: list[tuple[str, Path]] = []
    for path in sorted(root.rglob("*")):
        if path.is_dir() and not path.is_symlink():
            continue
        if path.is_symlink() or not path.is_file():
            raise ArtifactStoreError(f"staged tree holds a non-regular entry: {path}")
        entries.append((path.relative_to(root).as_posix(), path))
    yield from sorted(entries)


def directory_digest(root: Path) -> str:
    """One digest over a directory's relative names, executable bits, and file digests.

    The executable bit joins the content because an install whose llama-server
    lost `+x` differs from one that kept it in exactly the way the launch path
    depends on, and the file bytes alone would call the two identical.
    """
    hasher = hashlib.sha256()
    for relative, path in _walk_files(root):
        executable = "1" if path.stat().st_mode & 0o111 else "0"
        hasher.update(f"{relative}\0{executable}\0{digest_file(path)}\n".encode())
    return hasher.hexdigest()


def atomic_install(staging_dir: Path, final_dir: Path) -> InstallOutcome:
    """Move a staged tree to its final digest directory, or prove the existing one identical.

    `os.replace` renames the staged directory when the final name is free.
    Where the final directory already exists the rename would raise ENOTEMPTY,
    so the contents are compared first: identical contents make the install a
    no-op and the staged tree is removed; differing contents raise, since the
    digest that named the directory claims those two trees are the same bytes.

    A concurrent installer that creates the directory between the check and the
    rename turns the rename into the same OSError, which re-enters the
    comparison rather than failing the install.
    """
    if not staging_dir.is_dir():
        raise ArtifactStoreError(f"staging directory is absent: {staging_dir}")
    staged_digest = directory_digest(staging_dir)

    if final_dir.exists():
        return _reconcile(staging_dir, final_dir, staged_digest)

    final_dir.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.replace(staging_dir, final_dir)
    except OSError:
        if not final_dir.exists():
            raise
        return _reconcile(staging_dir, final_dir, staged_digest)
    return InstallOutcome(path=final_dir, created=True)


def _reconcile(staging_dir: Path, final_dir: Path, staged_digest: str) -> InstallOutcome:
    if not final_dir.is_dir():
        raise ArtifactStoreError(f"store entry exists and is not a directory: {final_dir}")
    installed_digest = directory_digest(final_dir)
    if installed_digest != staged_digest:
        raise ArtifactStoreError(
            f"{final_dir} already holds a different tree: installed {installed_digest}, "
            f"staged {staged_digest}"
        )
    remove_tree(staging_dir)
    return InstallOutcome(path=final_dir, created=False)


def remove_tree(root: Path) -> None:
    """Delete a staged tree bottom-up through regular files and directories alone.

    The staged tree is this process's own creation, so the walk refuses a
    symbolic link rather than following or unlinking one.
    """
    if not root.exists():
        return
    for path in sorted(root.rglob("*"), key=lambda entry: len(entry.parts), reverse=True):
        if path.is_symlink() or (not path.is_dir() and not path.is_file()):
            raise ArtifactStoreError(f"staged tree holds a non-regular entry: {path}")
        if path.is_dir():
            path.rmdir()
        else:
            path.unlink()
    root.rmdir()
