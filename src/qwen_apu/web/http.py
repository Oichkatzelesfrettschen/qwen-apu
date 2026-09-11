"""The gateway's route contract, shared by every module that serves a path.

A module exposes `routes() -> tuple[Route, ...]`; the application matches
the method and the compiled path pattern in registration order and calls the
handler with one `Request`. A handler returns a `Response` whole, or a
`StreamingResponse` whose `chunks` iterator the server writes as they
arrive, which is how chat completions reach the browser token by token.
The server layer alone touches sockets; a handler reads and returns values,
so a module's rules test without a listener.
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable, Iterator, Mapping
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Request:
    method: str
    path: str
    query: Mapping[str, str]
    headers: Mapping[str, str]  # header names lowercased
    body: bytes
    client_address: str
    path_params: Mapping[str, str] = field(default_factory=dict)

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

    @classmethod
    def make(cls, method: str, path: str, handler: Handler) -> Route:
        """`path` is a regex over the URL path; named groups become path_params."""
        return cls(method.upper(), re.compile(f"^{path}$"), handler)


def match(routes: tuple[Route, ...], method: str, path: str) -> tuple[Route, dict[str, str]] | None:
    for route in routes:
        if route.method != method.upper():
            continue
        found = route.pattern.match(path)
        if found:
            return route, found.groupdict()
    return None
