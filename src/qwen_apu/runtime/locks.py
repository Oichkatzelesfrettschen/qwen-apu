"""The two lock families the supervisor holds, and the one it hands to the child.

`hold` is the private-leaf lock: `deployment.open_verified_lock` opens a
regular 0600 leaf the serving user owns alone, and this module adds the
acquisition. A monotonic deadline with `LOCK_NB` polling bounds the wait
because `flock` offers no timeout and bounding a blocking call would take
SIGALRM, whose delivery thread is unspecified beside the control-socket
listener; `remote/image-service.py` states the same reason for the same poll.
A timeout of zero makes exactly one attempt.

`WorkloadLease` names `$QWEN_HOME/state/vulkan-workload.lock`, the Vulkan
workload lease `patches/llama-server-vulkan-workload-lease.patch` and
`remote/image-service.py` both write. The lease belongs to the process doing
the device work: `server_context_impl::update_slots` takes it where its
all-idle check finds a busy slot and releases it where the check finds none,
so the supervisor arms the file, names it to the child in
QWEN_VULKAN_WORKLOAD_LOCK, and proves it free once the child is gone. A
supervisor holding it across the child's lifetime would block that acquire on
the server's main thread and the server would never post NEXT_RESPONSE.

The lease carries the C++ side's own contract rather than the private-leaf
one: `open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0644)`, no content, and
mutual exclusion through flock alone. `open_verified_lock` refuses that mode
and would tighten it under an exclusive acquisition, which is the blocking
call the lease exists to leave to the server, so the lease opens itself.
"""

from __future__ import annotations

import errno
import fcntl
import os
import time
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path

from .deployment import open_verified_lock

# One syscall every 50 ms, the interval `image-service.py` polls its own
# acquisition on.
LOCK_POLL_SECONDS = 0.05

# The name every other writer of the lease uses: image-service.py's
# LEASE_FILE_NAME, image-teardown-check.sh's lease_file, and the path
# qwen-capacity-policy.sh exports from the session state directory.
VULKAN_LEASE_NAME = "vulkan-workload.lock"

# The mode the patched llama-server opens the lease with. A stricter mode here
# would leave the two writers disagreeing about the same inode's permissions.
LEASE_MODE = 0o644

_BUSY_ERRNOS = (errno.EACCES, errno.EAGAIN)


class LockTimeout(RuntimeError):
    """A lock still held by another descriptor when the deadline passed."""


class LeaseBusy(RuntimeError):
    """The Vulkan workload lease is held past the boundary that proves absence."""


@contextmanager
def hold(path: Path, *, exclusive: bool, timeout: float) -> Iterator[int]:
    """Hold one private lock leaf for the body, shared or exclusive.

    The descriptor is the caller's to read and the close releases the lock,
    so the body owns the lock for exactly its own duration.
    """
    operation = fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH
    descriptor = open_verified_lock(path, normalize_legacy_mode=True)
    deadline = time.monotonic() + timeout
    try:
        while True:
            try:
                fcntl.flock(descriptor, operation | fcntl.LOCK_NB)
                break
            except OSError as error:
                if error.errno not in _BUSY_ERRNOS:
                    raise
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise LockTimeout(
                        f"{'exclusive' if exclusive else 'shared'} lock held elsewhere "
                        f"after {timeout:.3f} s: {path}"
                    ) from None
                time.sleep(min(LOCK_POLL_SECONDS, remaining))
        yield descriptor
    finally:
        os.close(descriptor)


@dataclass(frozen=True)
class WorkloadLease:
    """The one file that admits one active qwen-owned Vulkan workload."""

    path: Path

    @classmethod
    def in_state_directory(cls, state_directory: Path) -> WorkloadLease:
        return cls(path=state_directory / VULKAN_LEASE_NAME)

    @property
    def environment_value(self) -> str:
        """The value QWEN_VULKAN_WORKLOAD_LOCK carries to the child."""
        return str(self.path)

    def _open(self) -> int:
        flags = os.O_RDWR | os.O_CREAT | os.O_CLOEXEC | os.O_NOFOLLOW
        return os.open(self.path, flags, LEASE_MODE)

    def arm(self) -> None:
        """Create the lease file so the child's own open finds an existing inode.

        A named path the server cannot open fails its init(), so the file
        exists before the argv naming it does.
        """
        os.close(self._open())

    def is_free(self) -> bool:
        """Whether a non-blocking exclusive acquisition succeeds right now.

        This is `flock -n -E 75 LEASE true`, the proof `image-teardown-check.sh`
        runs: an absent file holds nothing, a refused acquisition reports the
        lease held, and the acquisition this call makes is released before it
        answers. It runs once, after the child is proven gone, because a
        momentary LOCK_EX against a decoding server writes a `vulkan workload
        lease waiting` line that otherwise reports a stall nothing caused.
        """
        if not self.path.exists():
            return True
        descriptor = self._open()
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            if error.errno in _BUSY_ERRNOS:
                return False
            raise
        else:
            fcntl.flock(descriptor, fcntl.LOCK_UN)
            return True
        finally:
            os.close(descriptor)

    def require_free(self, boundary: str) -> None:
        """Raise where the lease survives the boundary that proves absence."""
        if not self.is_free():
            raise LeaseBusy(f"vulkan workload lease is still held at {boundary}: {self.path}")
