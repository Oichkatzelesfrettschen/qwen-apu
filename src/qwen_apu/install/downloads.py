"""Pinned artifact download, reproducing remote/download-*.sh over urllib.

Every remote/download-*.sh script applies the same sequence for one pinned
HuggingFace (or Wikimedia) object: verify an existing final file and exit
where it already matches the pin, resume or start a `.part` partial under a
fresh umask, stream the bytes with `curl --continue-at -`, verify the
completed partial's byte count and SHA-256, and `mv` it into place only once
both check out. `fetch` is that mechanism as one function over
`urllib.request` rather than a subprocess: no shell runs, and a downloaded
file never lands under its final name until `_verify` has read every one of
its bytes twice -- once for the count, once for the digest.
"""

from __future__ import annotations

import hashlib
import os
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

CHUNK_BYTES = 1024 * 1024
USER_AGENT = "qwen-apu-installer/1.0"
DEFAULT_TIMEOUT_S = 30.0

FetchStatus = Literal["already_verified", "downloaded"]


class DownloadError(RuntimeError):
    """An artifact's bytes, digest, or partial state refuse the pin."""


@dataclass(frozen=True, slots=True)
class FetchResult:
    """The outcome `fetch` prints as `artifact_status=STATUS path=... bytes=... sha256=...`."""

    status: FetchStatus
    path: Path
    expected_bytes: int
    expected_sha256: str

    def status_line(self) -> str:
        return (
            f"artifact_status={self.status} path={self.path} "
            f"bytes={self.expected_bytes} sha256={self.expected_sha256}"
        )


def sha256_file(path: Path, *, chunk_size: int = CHUNK_BYTES) -> str:
    """The file's SHA-256, read in `chunk_size` pieces rather than loaded whole."""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(chunk_size)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def _verify(path: Path, expected_bytes: int, expected_sha256: str) -> None:
    actual_bytes = path.stat().st_size
    if actual_bytes != expected_bytes:
        raise DownloadError(
            f"artifact byte count mismatch: expected {expected_bytes}, "
            f"found {actual_bytes} at {path}"
        )
    actual_sha256 = sha256_file(path)
    if actual_sha256 != expected_sha256:
        raise DownloadError(
            f"artifact SHA-256 mismatch: expected {expected_sha256}, "
            f"found {actual_sha256} at {path}"
        )


def _stream_to_file(url: str, partial: Path, *, resume_from: int, timeout: float) -> None:
    """Write `url`'s body to `partial`, appending from `resume_from` where the server honors it.

    A Range request the server answers with 206 appends to the existing
    bytes; one it answers with 200 (the server ignores Range and returns the
    whole body) restarts the file at offset zero rather than appending a
    second copy after the first.
    """
    headers = {"User-Agent": USER_AGENT}
    if resume_from > 0:
        headers["Range"] = f"bytes={resume_from}-"
    request = urllib.request.Request(url, headers=headers)  # noqa: S310
    with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
        appending = resume_from > 0 and response.status == 206
        mode = "ab" if appending else "wb"
        with partial.open(mode) as handle:
            while True:
                chunk = response.read(CHUNK_BYTES)
                if not chunk:
                    break
                handle.write(chunk)


def fetch(
    url: str,
    destination: Path,
    expected_bytes: int,
    expected_sha256: str,
    *,
    resume: bool = True,
    timeout: float = DEFAULT_TIMEOUT_S,
) -> FetchResult:
    """Fetch one pinned artifact into `destination`, verifying bytes and digest.

    `destination` holds the final verified file alone; `destination` with a
    `.part` suffix holds an in-progress or resumable download. A `.part` file
    already larger than `expected_bytes` is refused before any network byte
    crosses, the same refusal every download script applies ahead of a
    resume. `resume=False` discards an existing partial and starts over,
    matching a caller that wants a clean redownload rather than a continued
    one. `umask(0o077)` scopes to this call alone -- the previous mask is
    restored in a `finally` block -- so a partial and a verified file both
    land at the same permissions `umask 077` gives every download script's
    own artifacts.
    """
    destination = Path(destination)
    if destination.is_file():
        _verify(destination, expected_bytes, expected_sha256)
        return FetchResult("already_verified", destination, expected_bytes, expected_sha256)

    partial = destination.with_name(destination.name + ".part")
    previous_umask = os.umask(0o077)
    try:
        destination.parent.mkdir(parents=True, exist_ok=True)

        partial_bytes = 0
        if resume and partial.is_file():
            partial_bytes = partial.stat().st_size
            if partial_bytes > expected_bytes:
                raise DownloadError(
                    f"partial artifact exceeds expected size: {partial_bytes} > "
                    f"{expected_bytes} at {partial}"
                )
        elif partial.is_file():
            partial.unlink()

        if partial_bytes < expected_bytes:
            _stream_to_file(url, partial, resume_from=partial_bytes, timeout=timeout)

        _verify(partial, expected_bytes, expected_sha256)
        os.replace(partial, destination)
    finally:
        os.umask(previous_umask)

    return FetchResult("downloaded", destination, expected_bytes, expected_sha256)
