"""The loopback client for llama-server, bound to the process that answers.

An HTTP exchange on a loopback port proves that something answered on that
port. `qwen_apu.runtime.health` binds each exchange to the process the
supervisor launched instead: the pid carries the start time recorded at spawn,
that pid's `/proc/<pid>/fd` holds the socket inode, and `/proc/net/tcp` shows
that inode listening on the loopback address at that port, with exactly one
match. This client reads `state/runtime.json` for that pid, start time, and
port, and brackets every exchange with `probe_listener`, so a same-pid rebind
between the observations is visible as a changed inode -- the case a foreign
answer and a restarted listener share.

`urlopen` reads through `read1`, which returns what one socket read produced
rather than filling the caller's buffer, so an SSE frame the server flushed
reaches the browser as its own chunk instead of waiting for the frame after
it. A non-2xx answer arrives as `HTTPError`, which is itself a readable
response: llama-server states a malformed request as a 400 with a JSON body,
and passing that body through is what lets the page show the server's own
reason.
"""

from __future__ import annotations

import urllib.error
import urllib.request
from collections.abc import Iterator, Mapping
from dataclasses import dataclass
from http.client import HTTPResponse
from pathlib import Path

from qwen_apu.runtime import state as runtime_state
from qwen_apu.runtime.health import ListenerAbsent, ListenerIdentity, probe_listener

CHAT_COMPLETIONS_PATH = "/v1/chat/completions"
TOKENIZE_PATH = "/tokenize"
MODELS_PATH = "/v1/models"
HEALTH_PATH = "/health"

DEFAULT_TIMEOUT_SECONDS = 30.0
STREAM_TIMEOUT_SECONDS = 600.0
READ_CHUNK_BYTES = 4096

# The headers a proxied chat request carries upstream. Every other request
# header stays behind: the browser's cookie authorizes this gateway and the
# server behind it holds no session of its own, so forwarding it would put the
# gateway's only browser credential into a second process's logs.
FORWARDED_REQUEST_HEADERS = ("content-type", "accept")
# The headers a proxied answer carries back. The upstream body states the
# served model name and passes through byte for byte.
FORWARDED_RESPONSE_HEADERS = ("content-type",)


class UpstreamRefused(RuntimeError):
    """The upstream refused the exchange, or the listener failed its identity."""


@dataclass(frozen=True)
class UpstreamBinding:
    """One llama-server, named by its port and by the process that owns it."""

    port: int
    host: str = "127.0.0.1"
    pid: int | None = None
    start_time: int | None = None

    @property
    def bound_to_process(self) -> bool:
        return self.pid is not None and self.start_time is not None

    def base_url(self) -> str:
        return f"http://{self.host}:{self.port}"


def binding_from_runtime(record_path: Path, *, fallback_port: int) -> UpstreamBinding:
    """The upstream the supervisor last published, or the fallback port alone.

    A record in a terminal state names a server that has left, so its pid
    identifies nothing and the binding falls back to the port. The port itself
    still comes from the record where one exists, because the supervisor
    rather than this module decides which port the deployment serves.
    """
    record = runtime_state.read(record_path)
    if record is None:
        return UpstreamBinding(port=fallback_port)
    port = record.port or fallback_port
    if record.is_terminal or not record.server_pid or not record.server_start_time:
        return UpstreamBinding(port=port)
    return UpstreamBinding(port=port, pid=record.server_pid, start_time=record.server_start_time)


@dataclass(frozen=True)
class UpstreamAnswer:
    """One upstream response: its status, its headers, and its body as it arrives."""

    status: int
    headers: Mapping[str, str]
    chunks: Iterator[bytes]

    @property
    def streams(self) -> bool:
        return self.headers.get("content-type", "").startswith("text/event-stream")


class LlamaClient:
    """A small urllib client over one bound llama-server."""

    def __init__(
        self,
        binding: UpstreamBinding,
        *,
        timeout_s: float = DEFAULT_TIMEOUT_SECONDS,
        stream_timeout_s: float = STREAM_TIMEOUT_SECONDS,
    ) -> None:
        self.binding = binding
        self.timeout_s = timeout_s
        self.stream_timeout_s = stream_timeout_s

    def observe_listener(self) -> ListenerIdentity | None:
        """The listener identity, or None where no record names a process.

        A gateway launched against a server it did not supervise reads no pid
        and observes no inode; the exchange then rests on the loopback bind
        alone, which is the weaker claim and the one this return value states.
        """
        if not self.binding.bound_to_process:
            return None
        try:
            return probe_listener(
                self.binding.port, pid=self.binding.pid, start_time=self.binding.start_time
            )
        except ListenerAbsent as error:
            raise UpstreamRefused(str(error)) from error

    def request(
        self,
        method: str,
        path: str,
        *,
        body: bytes | None = None,
        headers: Mapping[str, str] | None = None,
        stream: bool = False,
    ) -> UpstreamAnswer:
        """One bracketed exchange against the bound server."""
        before = self.observe_listener()
        url = f"{self.binding.base_url()}{path}"
        upstream = urllib.request.Request(  # noqa: S310 -- the URL is composed from
            # the loopback host and a fixed path; no caller value reaches the scheme.
            url,
            data=body,
            headers=dict(headers or {}),
            method=method.upper(),
        )
        timeout = self.stream_timeout_s if stream else self.timeout_s
        try:
            response: HTTPResponse = urllib.request.urlopen(  # noqa: S310 -- see above
                upstream, timeout=timeout
            )
        except urllib.error.HTTPError as error:
            # An HTTPError carries the upstream's own status and body, which
            # names the reason a 400 refused the request.
            response = error  # type: ignore[assignment]
        except OSError as error:
            raise UpstreamRefused(f"the upstream refused the request: {error}") from error
        answer_headers = {
            name: response.headers.get(name, "")
            for name in FORWARDED_RESPONSE_HEADERS
            if response.headers.get(name)
        }
        return UpstreamAnswer(
            status=response.status,
            headers=answer_headers,
            chunks=self._read(response, before),
        )

    def _read(self, response: HTTPResponse, before: ListenerIdentity | None) -> Iterator[bytes]:
        """Yield each socket read, then close the bracket on the listener.

        The closing observation runs after the last byte: an inode that changed
        across the exchange means the answer came from a listener other than
        the one the opening observation named, and raising here leaves the
        gateway's chunked body unterminated rather than completing a body whose
        origin is undecided.
        """
        try:
            while True:
                chunk = response.read1(READ_CHUNK_BYTES)
                if not chunk:
                    break
                yield chunk
        finally:
            response.close()
        if before is not None:
            after = self.observe_listener()
            if after is not None and after.inode != before.inode:
                raise UpstreamRefused(
                    f"listener inode changed across the exchange: {before.inode} -> {after.inode}"
                )

    def health(self) -> UpstreamAnswer:
        return self.request("GET", HEALTH_PATH)

    def models(self) -> UpstreamAnswer:
        return self.request("GET", MODELS_PATH)

    def chat_completions(self, body: bytes, headers: Mapping[str, str]) -> UpstreamAnswer:
        forwarded = {
            name: value
            for name, value in headers.items()
            if name.lower() in FORWARDED_REQUEST_HEADERS
        }
        forwarded.setdefault("content-type", "application/json")
        return self.request(
            "POST", CHAT_COMPLETIONS_PATH, body=body, headers=forwarded, stream=True
        )

    def tokenize(self, body: bytes) -> UpstreamAnswer:
        """One buffered `/tokenize` exchange: the token array for a text."""
        return self.request(
            "POST", TOKENIZE_PATH, body=body, headers={"content-type": "application/json"}
        )


def collect(answer: UpstreamAnswer) -> bytes:
    """Every chunk of one answer, joined."""
    return b"".join(answer.chunks)
