"""A client for the image worker's Unix control socket.

`remote/image-service.py` takes `image_generate`, `cancel`, and `status` as one
JSON line per connection on `<state>/image-service.sock`, because a channel
that starts GPU work belongs to the filesystem permissions of the serving user
rather than to a port. Native generation stays that worker's child process;
this module carries the control plane and nothing else.

The frame is `remote/image_protocol.py`, loaded by path rather than copied.
Version 1 freezes a closed request schema, a closed response schema, and a
65536-byte line bound, and one reading of a line is the whole point of the
module: a second transcription here would be the third reading it exists to
prevent. The load registers the module under its own name `image_protocol`, so
`remote/web-mcp/image_grant.py` and `remote/image_signed_verifier.py` -- both
of which reach it through a `sys.path` insert -- bind the same module object
and one `ProtocolError` class serves every `except` in this package.

One request per connection matches the worker's own ControlHandler, so a
`status` or `cancel` arriving during a long generation is answered on its own
connection while the worker's job lock serializes the generation itself.
"""

from __future__ import annotations

import os
import socket
import sys
import threading
from collections.abc import Mapping
from dataclasses import dataclass
from importlib import util as importlib_util
from pathlib import Path
from types import ModuleType

REMOTE_MODULES: tuple[tuple[str, str], ...] = (
    ("image_protocol", "image_protocol.py"),
    ("image_grant", "web-mcp/image_grant.py"),
    ("image_signed_verifier", "image_signed_verifier.py"),
)
# One reentrant lock over every by-path load. Registering a module in
# `sys.modules` before `exec_module` is what lets the loaded module's own
# imports resolve back to it, and it also publishes a half-initialized object
# to any other thread that looks the name up meanwhile. The lock closes that
# window; it is reentrant because a loaded module's import chain reaches this
# function again on the loading thread.
_LOAD_LOCK = threading.RLock()
DEFAULT_EXCHANGE_TIMEOUT_SECONDS = 30.0
SOCKET_FILE_NAME = "image-service.sock"
ACTION_GENERATE = "image_generate"
ACTION_CANCEL = "cancel"
ACTION_STATUS = "status"


def tree_root() -> Path:
    """The checkout that holds `remote/`, four segments above this file."""
    declared = os.environ.get("QWEN_TREE_ROOT")
    if declared:
        return Path(declared).resolve()
    return Path(__file__).resolve().parents[3]


def load_remote_module(name: str, relative_path: str) -> ModuleType:
    """Import one `remote/` module by path under its own module name.

    The name matters beyond bookkeeping: `image_grant` and
    `image_signed_verifier` import `image_protocol` through a `sys.path`
    insert, so registering this load in `sys.modules` first is what keeps one
    module object and one exception class across the three. A second object
    would leave `except ProtocolError` failing to catch the other's raise.
    """
    with _LOAD_LOCK:
        existing = sys.modules.get(name)
        if existing is not None:
            return existing
        path = tree_root() / "remote" / relative_path
        spec = importlib_util.spec_from_file_location(name, path)
        if spec is None or spec.loader is None:
            raise ImageControlError(f"the remote module {name} is unreadable at {path}")
        module = importlib_util.module_from_spec(spec)
        sys.modules[name] = module
        try:
            spec.loader.exec_module(module)
        except BaseException:
            del sys.modules[name]
            raise
        return module


def protocol() -> ModuleType:
    """The frozen version 1 frame, loaded once."""
    return load_remote_module(*REMOTE_MODULES[0])


def protocol_error() -> type[Exception]:
    """The one `ProtocolError` class every reader of the frame raises.

    The frame arrives as a dynamically loaded module, so its exception class is
    read as a value and proved to be an exception type before an `except`
    clause names it.
    """
    declared: object = protocol().ProtocolError
    if not (isinstance(declared, type) and issubclass(declared, Exception)):
        raise ImageControlError("the frozen protocol module declares no ProtocolError")
    return declared


class ImageControlError(RuntimeError):
    """One control exchange failed; the subclass names which boundary."""


class ProtocolRefused(ImageControlError):
    """A request or a reply leaves protocol version 1's closed schema."""


class ServiceUnreachable(ImageControlError):
    """The socket refused the connection, or answered nothing inside the timeout."""


@dataclass(frozen=True, slots=True)
class ImageControlClient:
    """One connected exchange per call against the worker's control socket."""

    socket_path: Path
    timeout: float = DEFAULT_EXCHANGE_TIMEOUT_SECONDS

    @classmethod
    def under_state(
        cls, state_directory: Path, timeout: float = DEFAULT_EXCHANGE_TIMEOUT_SECONDS
    ) -> ImageControlClient:
        """The client for the socket `qwen-webui-session.sh` starts the worker on."""
        return cls(state_directory / SOCKET_FILE_NAME, timeout)

    def generate(self, request: Mapping[str, object]) -> dict[str, object]:
        """Run one generation to its terminal reply.

        The caller supplies the job -- `request_id`, `profile_id`, the prompts,
        the seed, the geometry, the step count, and the opaque grant under
        `authorization` -- and this client names the frame, so
        `protocol_version` and `action` read the same on every call. The
        generation path is synchronous the way `remote/image-mcp/server.py`
        runs it: the reply that comes back is the outcome.
        """
        frame = dict(request)
        frame["protocol_version"] = protocol().PROTOCOL_VERSION
        frame["action"] = ACTION_GENERATE
        return self.exchange(frame)

    def cancel(self, request_id: str) -> dict[str, object]:
        """End the generation carrying `request_id`, or read its `not_running` refusal.

        A cancel names its target by the running generation's own identifier,
        which `status` reports as `job_request_id`; a stale identifier from an
        earlier turn stops nothing.
        """
        return self.exchange(self._control_frame(ACTION_CANCEL, request_id))

    def status(self, request_id: str) -> dict[str, object]:
        """Read the worker's observation of itself: phase, job, lease, and pid."""
        return self.exchange(self._control_frame(ACTION_STATUS, request_id))

    def _control_frame(self, action: str, request_id: str) -> dict[str, object]:
        """A control frame names a job and carries no field describing one.

        The closed schema refuses every generation field on a `cancel` or a
        `status`, so a control message can never smuggle a second geometry past
        the authorization that admitted the first.
        """
        return {
            "protocol_version": protocol().PROTOCOL_VERSION,
            "request_id": request_id,
            "action": action,
        }

    def exchange(self, frame: Mapping[str, object]) -> dict[str, object]:
        """Write one validated line and read one validated reply.

        The request meets the closed schema before a byte leaves, so a caller's
        unknown key is refused here rather than sent for the worker to refuse.
        The reader takes the line cap plus one byte, so a worker that writes
        bytes and no newline meets the bound rather than growing this process's
        buffer to the peer's choosing.
        """
        frozen = protocol()
        breaches = protocol_error()
        try:
            frozen.validate_request(dict(frame))
            line: str = frozen.encode_line(dict(frame))
        except breaches as breach:
            raise ProtocolRefused(f"the job leaves the image protocol: {breach}") from None

        reply_line = self._round_trip(line.encode("utf-8"))
        try:
            decoded: object = frozen.decode_line(reply_line)
        except breaches as breach:
            raise ProtocolRefused(f"the reply leaves the image protocol: {breach}") from None
        if not isinstance(decoded, dict):
            raise ProtocolRefused("the image service reply is not an object")
        try:
            frozen.validate_response(decoded, control_reply=True)
        except breaches as breach:
            raise ProtocolRefused(f"the reply leaves the image protocol: {breach}") from None
        reply: dict[str, object] = decoded
        if reply.get("protocol_version") != frozen.PROTOCOL_VERSION:
            raise ProtocolRefused("the image service answered under another protocol version")
        if reply.get("request_id") != frame.get("request_id"):
            raise ProtocolRefused("the image service reply names another request")
        return reply

    def _round_trip(self, line: bytes) -> bytes:
        cap: int = protocol().MAX_LINE_BYTES
        connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        connection.settimeout(self.timeout)
        try:
            address, directory = short_socket_address(self.socket_path)
            try:
                connection.connect(address)
            finally:
                os.close(directory)
        except OSError as error:
            connection.close()
            raise ServiceUnreachable(
                f"the image service socket is unreachable: {type(error).__name__}"
            ) from None
        try:
            connection.sendall(line)
            with connection.makefile("rb") as stream:
                reply: bytes = stream.readline(cap + 1)
        except OSError as error:
            raise ServiceUnreachable(
                f"the image service answered no reply inside {self.timeout:g} seconds: "
                f"{type(error).__name__}"
            ) from None
        finally:
            connection.close()
        if not reply:
            raise ServiceUnreachable("the image service closed the connection unanswered")
        return reply


def short_socket_address(path: Path) -> tuple[str, int]:
    """An AF_UNIX address for `path` that fits the 108-byte sun_path limit.

    The address names the socket through `/proc/self/fd/<dirfd>/<name>`, so a
    runtime root under a long path connects to the same file the short form
    would. The kernel resolves the path at the connect alone, so the caller
    closes the descriptor immediately after. `qwen_apu.runtime.supervisor`
    binds its own control socket through the identical mechanism.
    """
    directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    return f"/proc/self/fd/{directory}/{path.name}", directory  # appliance-path: named
