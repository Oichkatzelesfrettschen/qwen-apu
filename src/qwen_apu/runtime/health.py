"""Readiness bound to one process, one start time, and one listener inode.

An HTTP exchange on a loopback port proves that something answered on that
port. `remote/measure-draft-pair.sh` binds each exchange to the process it
launched instead: the pid still carries the start time recorded at spawn, that
pid's `/proc/<pid>/fd` holds the socket inode, and `/proc/net/tcp` shows that
inode listening on the loopback address at that port, with exactly one match.
The bracketing observations make a same-pid rebind between them visible as a
changed inode, which is the case a foreign answer and a restarted listener
share.

The probe speaks `http.client` rather than `urllib.request`: the connection
carries its own timeout, and the request never leaves loopback, which
`wait_ready` requires of the URL it is given.
"""

from __future__ import annotations

import http.client
import json
import os
import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit

from .process import read_start_time

# /proc/net/tcp renders 127.0.0.1 as a little-endian hexadecimal word, and
# state 0A is TCP_LISTEN.
LOOPBACK_HEX_ADDRESS = "0100007F"
TCP_LISTEN_STATE = "0A"
LOOPBACK_HOSTS = frozenset({"127.0.0.1", "localhost"})

DEFAULT_HEALTH_PATH = "/health"
DEFAULT_POLL_INTERVAL_SECONDS = 1.0
HEALTH_REQUEST_TIMEOUT_SECONDS = 5.0


class ListenerAbsent(RuntimeError):
    """No single loopback listener on the port answers for the named process."""


class ReadinessRefused(RuntimeError):
    """A readiness probe refused before its deadline, naming what refused it."""


@dataclass(frozen=True)
class ListenerIdentity:
    """One listening socket, named by the process that owns it."""

    port: int
    inode: str
    pid: int | None
    start_time: int | None

    def render(self) -> str:
        return (
            f"port={self.port} inode={self.inode} pid={self.pid if self.pid else '-'} "
            f"start_time={self.start_time if self.start_time else '-'}"
        )


@dataclass(frozen=True)
class Readiness:
    """What one readiness wait observed, ready or refused."""

    ready: bool
    attempts: int
    elapsed_seconds: float
    status: int | None
    body: str
    listener: ListenerIdentity | None
    reason: str

    def render(self) -> str:
        listener = self.listener.render() if self.listener else "-"
        return (
            f"ready={'yes' if self.ready else 'no'} attempts={self.attempts} "
            f"elapsed_seconds={self.elapsed_seconds:.3f} "
            f"status={self.status if self.status is not None else '-'} "
            f"listener={listener} reason={self.reason}"
        )


def _socket_inodes(pid: int) -> set[str]:
    inodes: set[str] = set()
    descriptor_directory = Path(f"/proc/{pid}/fd")  # appliance-path: named
    try:
        entries = list(descriptor_directory.iterdir())
    except OSError as error:
        raise ListenerAbsent(f"process {pid} exposes no descriptor table") from error
    for entry in entries:
        try:
            target = os.readlink(entry)
        except OSError:
            continue
        if target.startswith("socket:[") and target.endswith("]"):
            inodes.add(target[8:-1])
    return inodes


def _listening_inodes(port: int) -> list[str]:
    """Every loopback IPv4 listener inode on the port.

    `/proc/net/tcp` carries IPv4 alone, so a server bound to ::1 answers no
    match here; the appliance binds 127.0.0.1 and the refusal names the gap.
    """
    try:
        lines = Path("/proc/net/tcp").read_text(encoding="ascii").splitlines()[1:]
    except OSError as error:
        raise ListenerAbsent("/proc/net/tcp is unreadable") from error
    matches = []
    for line in lines:
        fields = line.split()
        if len(fields) < 10:
            continue
        address, _, port_hexadecimal = fields[1].partition(":")
        if address != LOOPBACK_HEX_ADDRESS or fields[3] != TCP_LISTEN_STATE:
            continue
        try:
            if int(port_hexadecimal, 16) != port:
                continue
        except ValueError:
            continue
        matches.append(fields[9])
    return matches


def probe_listener(
    port: int, *, pid: int | None = None, start_time: int | None = None
) -> ListenerIdentity:
    """Resolve the one loopback listener on the port, bound to a pid where given.

    A pid narrows the match to that process's own socket inodes and, with a
    start time, refuses before the lookup where the number has been reused.
    Exactly one match answers; zero or several refuse, because two listeners on
    one port mean the identity the caller asked for is undecided.
    """
    if pid is not None and start_time is not None:
        live_start_time = read_start_time(pid)
        if live_start_time != start_time:
            raise ListenerAbsent(
                f"pid {pid} carries start time {live_start_time} against the recorded "
                f"{start_time}, so the listener belongs to another process"
            )
    candidates = _listening_inodes(port)
    if pid is not None:
        owned = _socket_inodes(pid)
        candidates = [inode for inode in candidates if inode in owned]
    if len(candidates) != 1:
        raise ListenerAbsent(
            f"port {port} has {len(candidates)} loopback listeners"
            + (f" owned by pid {pid}" if pid is not None else "")
        )
    return ListenerIdentity(port=port, inode=candidates[0], pid=pid, start_time=start_time)


def _get(host: str, port: int, path: str) -> tuple[int, str]:
    connection = http.client.HTTPConnection(host, port, timeout=HEALTH_REQUEST_TIMEOUT_SECONDS)
    try:
        connection.request("GET", path)
        response = connection.getresponse()
        body = response.read().decode("utf-8", "replace")
        return response.status, body
    finally:
        connection.close()


def health_is_serving(body: str) -> bool:
    """Whether a /health body reports a serving model.

    llama-server answers `{"status": "ok"}` once the model is loaded and
    `{"status": "loading model"}` while it streams in, so the status field
    rather than the 200 decides readiness.
    """
    try:
        payload = json.loads(body)
    except ValueError:
        return False
    if not isinstance(payload, dict):
        return False
    return payload.get("status") == "ok"


def wait_ready(
    url: str,
    *,
    deadline_s: float,
    interval_s: float = DEFAULT_POLL_INTERVAL_SECONDS,
    must_be_pid: int | None = None,
    must_be_start_time: int | None = None,
    departed: Callable[[], bool] | None = None,
    cancelled: Callable[[], bool] | None = None,
) -> Readiness:
    """Poll GET on a loopback URL until it reports a serving model.

    Each exchange is bracketed by a listener observation, so the answer comes
    from the process the caller named and from one stable inode across the
    request. The wait ends where the named process leaves, because a departed
    child cannot become ready and the remaining deadline would only delay the
    failure the caller acts on. `departed` is what answers that for a child the
    caller has not reaped: an exited process keeps its `/proc/<pid>/stat` and
    its start time until its parent collects it, so the start-time comparison
    alone reads a zombie as a live server and spends the whole deadline on it.
    `cancelled` ends the wait on an operator's stop, which arrives while a
    model is still loading: the appliance holds this loop for up to 120 s on a
    load, and a stop the loop cannot read waits out that whole interval.
    """
    parts = urlsplit(url)
    if parts.hostname not in LOOPBACK_HOSTS:
        raise ReadinessRefused(f"readiness probes loopback alone: {url}")
    if parts.port is None:
        raise ReadinessRefused(f"readiness URL names no port: {url}")
    host = parts.hostname
    port = parts.port
    path = parts.path or DEFAULT_HEALTH_PATH

    started = time.monotonic()
    deadline = started + deadline_s
    attempts = 0
    status: int | None = None
    body = ""
    reason = "deadline expired before the server reported a serving model"

    while True:
        attempts += 1
        if cancelled is not None and cancelled():
            reason = "stop requested before readiness"
            break
        if departed is not None and departed():
            reason = f"pid {must_be_pid} left before readiness"
            break
        if must_be_pid is not None and must_be_start_time is not None:
            if read_start_time(must_be_pid) != must_be_start_time:
                reason = f"pid {must_be_pid} left before readiness"
                break
        listener: ListenerIdentity | None = None
        try:
            listener = probe_listener(port, pid=must_be_pid, start_time=must_be_start_time)
        except ListenerAbsent as error:
            reason = str(error)
        if listener is not None:
            try:
                status, body = _get(host, port, path)
            except OSError as error:
                reason = f"health request refused: {error}"
            else:
                try:
                    after = probe_listener(port, pid=must_be_pid, start_time=must_be_start_time)
                except ListenerAbsent as error:
                    reason = f"listener left during the health exchange: {error}"
                else:
                    if after.inode != listener.inode:
                        reason = (
                            f"listener inode changed across the health exchange: "
                            f"{listener.inode} -> {after.inode}"
                        )
                    elif status == 200 and health_is_serving(body):
                        return Readiness(
                            ready=True,
                            attempts=attempts,
                            elapsed_seconds=time.monotonic() - started,
                            status=status,
                            body=body,
                            listener=after,
                            reason="serving",
                        )
                    else:
                        reason = f"health reported status={status} body={body.strip()[:120]}"
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        time.sleep(min(interval_s, remaining))

    return Readiness(
        ready=False,
        attempts=attempts,
        elapsed_seconds=time.monotonic() - started,
        status=status,
        body=body,
        listener=None,
        reason=reason,
    )
