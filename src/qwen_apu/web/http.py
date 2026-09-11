"""The gateway's route contract, shared by every module that serves a path.

A module exposes `routes() -> tuple[Route, ...]`; the application matches
the method and the compiled path pattern in registration order and calls the
handler with one `Request`. A handler returns a `Response` whole, or a
`StreamingResponse` whose `chunks` iterator the server writes as they
arrive, which is how chat completions reach the browser token by token.
The server layer alone touches sockets; a handler reads and returns values,
so a module's rules test without a listener.

A route declared with `streams=True` reads its own request body: the server
hands it a `BodyStream` over the bytes still in the socket and applies no byte
cap of its own, so that route states the bound an upload meets while the
gateway's JSON cap keeps bounding every other route. `BodyStream.remaining`
reports what the handler left unread, which is how the server decides whether
the connection carries a second request.
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable, Iterator, Mapping
from dataclasses import dataclass, field
from typing import Protocol

BODY_STREAM_BLOCK_BYTES = 64 * 1024


class ByteReader(Protocol):
    """What a body stream reads from: the socket's buffered reader, or a test's own."""

    def read(self, size: int, /) -> bytes: ...


class BodyStream:
    """The request body as bytes still in the socket, read by the route that bounds it.

    Each read clamps to what Content-Length declares, so a handler reading
    past the body takes none of the next request's bytes, and the connection's
    own timeout bounds a client that stops sending mid-body.
    """

    def __init__(self, source: ByteReader, length: int) -> None:
        self.source = source
        self.length = length
        self.remaining = length

    @property
    def exhausted(self) -> bool:
        return self.remaining <= 0

    def read(self, size: int) -> bytes:
        if self.remaining <= 0 or size <= 0:
            return b""
        data = self.source.read(min(size, self.remaining))
        self.remaining -= len(data)
        return data

    def blocks(self, block: int = BODY_STREAM_BLOCK_BYTES) -> Iterator[bytes]:
        while True:
            data = self.read(block)
            if not data:
                return
            yield data


@dataclass(frozen=True)
class Request:
    method: str
    path: str
    query: Mapping[str, str]
    headers: Mapping[str, str]  # header names lowercased
    body: bytes
    client_address: str
    path_params: Mapping[str, str] = field(default_factory=dict)
    # A route declared `streams=True` reads this and leaves `body` empty.
    stream: BodyStream | None = None

    def header(self, name: str, default: str = "") -> str:
        return self.headers.get(name.lower(), default)

    def json(self) -> object:
        return json.loads(self.body.decode("utf-8")) if self.body else None


@dataclass(frozen=True)
class Response:
    status: int
    body: bytes = b""
    headers: Mapping[str, str] = field(default_factory=dict)

    @classmethod
    def json(cls, payload: object, status: int = 200, **headers: str) -> Response:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        return cls(status, data, {"content-type": "application/json", **headers})

    @classmethod
    def text(cls, text: str, status: int = 200, **headers: str) -> Response:
        return cls(
            status, text.encode("utf-8"), {"content-type": "text/plain; charset=utf-8", **headers}
        )


@dataclass(frozen=True)
class StreamingResponse:
    status: int
    chunks: Iterator[bytes]
    headers: Mapping[str, str] = field(default_factory=dict)


Handler = Callable[[Request], Response | StreamingResponse]


@dataclass(frozen=True)
class Route:
    method: str
    pattern: re.Pattern[str]
    handler: Handler
    # True where the handler reads the body itself under its own byte bound.
    streams: bool = False

    @classmethod
    def make(cls, method: str, path: str, handler: Handler, *, streams: bool = False) -> Route:
        """`path` is a regex over the URL path; named groups become path_params."""
        return cls(method.upper(), re.compile(f"^{path}$"), handler, streams)


def match(routes: tuple[Route, ...], method: str, path: str) -> tuple[Route, dict[str, str]] | None:
    for route in routes:
        if route.method != method.upper():
            continue
        found = route.pattern.match(path)
        if found:
            return route, found.groupdict()
    return None
