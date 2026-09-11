"""A read-only, path-scoped file search and read tool, mounted on the gateway.

`FileSearchSettings` names the declared roots a search or a read may reach and
the three caps that bound one call: how many hits it returns, how large a
file it opens, and how many bytes it reads across the whole call. `search`
walks one declared root under a glob, matches each line by substring or by
regular expression, and returns every hit's path relative to the root, its
line number, and the matching line bounded to 400 characters. `read` returns
one bounded window of a named file's lines.

Both refuse a `root` outside `settings.roots` and a `..` path segment before
either resolves anything, and both resolve every candidate path through
`Path.resolve(strict=True)` before reading it: a symlink is resolved rather
than followed blind, so a link whose target leaves the declared root answers
as absent rather than as the file it points to. `search` skips such an entry
and keeps walking, since one bad link among many files does not empty a
search; `read` names one file outright and refuses the call, since there is
no second candidate to fall back to. A file carrying a NUL byte in its first
8 KiB is binary and `search` skips it the same way, decoding nothing.

`POST /api/tools/files/search` and `POST /api/tools/files/read` sit behind an
injectable session check that defaults to refused, matching
`web/artifacts.py`'s `session_refused`: a caller that wires no session
authority serves nothing rather than serving everyone.
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import cast

from qwen_apu.web.http import Request, Response, Route

FILES_SEARCH_ROUTE = "/api/tools/files/search"
FILES_READ_ROUTE = "/api/tools/files/read"

DEFAULT_GLOB = "**/*"
BINARY_SNIFF_BYTES = 8192
MAX_LINE_CHARS = 400
MAX_READ_LINES = 2000
DEFAULT_MAX_RESULTS = 200
DEFAULT_MAX_FILE_BYTES = 1_000_000
DEFAULT_MAX_TOTAL_BYTES = 20_000_000


class FileSearchRefused(Exception):
    """One refusal: a root outside the declared set, a '..' segment, or an escaped symlink."""

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


@dataclass(frozen=True, slots=True)
class Hit:
    """One matching line: its path relative to the root, its line number, its text."""

    path: str
    line: int
    text: str


@dataclass(frozen=True, slots=True)
class ReadResult:
    """One bounded window of a file's lines, named relative to the root it was read under."""

    path: str
    start_line: int
    end_line: int
    lines: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class FileSearchSettings:
    """The declared roots a call may reach, and the three caps that bound it."""

    roots: tuple[Path, ...]
    max_results: int = DEFAULT_MAX_RESULTS
    max_file_bytes: int = DEFAULT_MAX_FILE_BYTES
    max_total_bytes: int = DEFAULT_MAX_TOTAL_BYTES

    def __post_init__(self) -> None:
        # Every declared root is resolved once here, so a later membership
        # check compares two resolved paths rather than a resolved candidate
        # against a root that still carries a symlink or a relative segment.
        object.__setattr__(self, "roots", tuple(root.resolve() for root in self.roots))


def _refuse_dotdot(raw: Path, label: str) -> None:
    if ".." in raw.parts:
        raise FileSearchRefused(f"the {label} names a '..' path segment")


def _declared_root(settings: FileSearchSettings, root: Path) -> Path:
    _refuse_dotdot(root, "root")
    resolved = root.resolve()
    if resolved not in settings.roots:
        raise FileSearchRefused(f"{root} is not a declared root")
    return resolved


def _resolve_within(root: Path, candidate: Path) -> Path | None:
    """Return `candidate`'s fully resolved path, or None where it leaves `root`.

    `Path.resolve(strict=True)` walks every symlink component and raises where
    a component is absent, so a dangling link answers None the same way an
    escaping target does: neither names a file this call may read.
    """
    try:
        resolved = candidate.resolve(strict=True)
    except OSError:
        return None
    if resolved != root and root not in resolved.parents:
        return None
    return resolved


def search(
    settings: FileSearchSettings,
    query: str,
    *,
    root: Path,
    glob: str = DEFAULT_GLOB,
    regex: bool = False,
    case_sensitive: bool = False,
) -> tuple[Hit, ...]:
    """Return every matching line under `root`, in path order, up to the settings' caps."""
    declared_root = _declared_root(settings, root)
    matches = _matcher(query, regex=regex, case_sensitive=case_sensitive)

    hits: list[Hit] = []
    total_bytes = 0
    for candidate in sorted(declared_root.glob(glob)):
        if len(hits) >= settings.max_results:
            break
        if candidate.is_dir():
            continue
        resolved = _resolve_within(declared_root, candidate)
        if resolved is None:
            continue  # a symlink escaping the root, or a dangling one, contributes no hit
        try:
            size = resolved.stat().st_size
        except OSError:
            continue
        if size > settings.max_file_bytes:
            continue
        if total_bytes + size > settings.max_total_bytes:
            break
        try:
            data = resolved.read_bytes()
        except OSError:
            continue
        total_bytes += len(data)
        if b"\x00" in data[:BINARY_SNIFF_BYTES]:
            continue  # a NUL byte in the first 8 KiB marks the file binary
        text = data.decode("utf-8", errors="replace")
        relative = candidate.relative_to(declared_root).as_posix()
        for line_number, line in enumerate(text.splitlines(), start=1):
            if len(hits) >= settings.max_results:
                break
            if matches(line):
                hits.append(Hit(path=relative, line=line_number, text=line[:MAX_LINE_CHARS]))
    return tuple(hits)


def _matcher(query: str, *, regex: bool, case_sensitive: bool) -> Callable[[str], bool]:
    if regex:
        try:
            pattern = re.compile(query, 0 if case_sensitive else re.IGNORECASE)
        except re.error as error:
            raise FileSearchRefused(
                f"the query is not a valid regular expression: {error}"
            ) from None

        def matches_regex(line: str) -> bool:
            return pattern.search(line) is not None

        return matches_regex

    needle = query if case_sensitive else query.lower()

    def matches_literal(line: str) -> bool:
        haystack = line if case_sensitive else line.lower()
        return needle in haystack

    return matches_literal


def read(
    settings: FileSearchSettings,
    path: Path,
    *,
    root: Path,
    start_line: int,
    end_line: int,
) -> ReadResult:
    """Return one bounded window of `path`'s lines, read under the declared `root`."""
    if start_line < 1:
        raise FileSearchRefused("start_line is 1 or greater")
    if end_line < start_line:
        raise FileSearchRefused("end_line does not come before start_line")
    if end_line - start_line + 1 > MAX_READ_LINES:
        raise FileSearchRefused(f"a read window exceeds {MAX_READ_LINES} lines")
    if path.is_absolute():
        raise FileSearchRefused("path is relative to the declared root, not absolute")
    declared_root = _declared_root(settings, root)
    _refuse_dotdot(path, "path")
    candidate = declared_root / path
    resolved = _resolve_within(declared_root, candidate)
    if resolved is None:
        raise FileSearchRefused(f"{path} resolves outside the declared root")
    if not resolved.is_file():
        raise FileSearchRefused(f"{path} is not a regular file")
    try:
        size = resolved.stat().st_size
    except OSError as error:
        raise FileSearchRefused(f"{path} cannot be read: {error}") from None
    if size > settings.max_file_bytes:
        raise FileSearchRefused(f"{path} exceeds the {settings.max_file_bytes}-byte read cap")
    try:
        data = resolved.read_bytes()
    except OSError as error:
        raise FileSearchRefused(f"{path} cannot be read: {error}") from None
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        raise FileSearchRefused(f"{path} is not valid UTF-8 text") from None
    lines = text.splitlines()
    window = tuple(lines[start_line - 1 : end_line])
    relative = candidate.relative_to(declared_root).as_posix()
    return ReadResult(
        path=relative, start_line=start_line, end_line=min(end_line, len(lines)), lines=window
    )


# --- HTTP routes -------------------------------------------------------------


def session_refused(request: Request) -> bool:
    """The default session check: no session admits a call.

    Defaulting to refused rather than to admitted keeps this module's tests
    standing alone without widening what an unconfigured mount serves, the
    rule `web/artifacts.py`'s own `session_refused` states.
    """
    return False


@dataclass(frozen=True, slots=True)
class FilesToolSettings:
    """The search settings and the injectable session check the routes run behind."""

    search: FileSearchSettings
    session_admits: Callable[[Request], bool] = session_refused


def _body(request: Request) -> Mapping[str, object]:
    try:
        parsed: object = request.json()
    except ValueError:
        raise FileSearchRefused("the request body is not JSON") from None
    if not isinstance(parsed, dict):
        raise FileSearchRefused("the request body is not a JSON object")
    return cast(Mapping[str, object], parsed)


def _string(body: Mapping[str, object], key: str) -> str:
    value = body.get(key)
    if not isinstance(value, str) or not value:
        raise FileSearchRefused(f"{key} is absent or is not a nonempty string")
    return value


def _optional_string(body: Mapping[str, object], key: str, default: str) -> str:
    value = body.get(key, default)
    if not isinstance(value, str):
        raise FileSearchRefused(f"{key} is not a string")
    return value


def _optional_bool(body: Mapping[str, object], key: str, default: bool) -> bool:
    value = body.get(key, default)
    if not isinstance(value, bool):
        raise FileSearchRefused(f"{key} is not a boolean")
    return value


def _integer(body: Mapping[str, object], key: str) -> int:
    value = body.get(key)
    if isinstance(value, bool) or not isinstance(value, int):
        raise FileSearchRefused(f"{key} is absent or is not an integer")
    return value


def _json(status: int, payload: object) -> Response:
    return Response(
        status,
        json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        {
            "content-type": "application/json",
            "cache-control": "no-store",
            "x-content-type-options": "nosniff",
        },
    )


def handle_search(settings: FilesToolSettings, request: Request) -> Response:
    """Answer one search request, behind the injectable session check."""
    if not settings.session_admits(request):
        return _json(401, {"error": "the request carries no admitted session"})
    try:
        body = _body(request)
        hits = search(
            settings.search,
            _string(body, "query"),
            root=Path(_string(body, "root")),
            glob=_optional_string(body, "glob", DEFAULT_GLOB),
            regex=_optional_bool(body, "regex", False),
            case_sensitive=_optional_bool(body, "case_sensitive", False),
        )
    except FileSearchRefused as refusal:
        return _json(400, {"error": refusal.message})
    return _json(
        200,
        {"hits": [{"path": hit.path, "line": hit.line, "text": hit.text} for hit in hits]},
    )


def handle_read(settings: FilesToolSettings, request: Request) -> Response:
    """Answer one read request, behind the injectable session check."""
    if not settings.session_admits(request):
        return _json(401, {"error": "the request carries no admitted session"})
    try:
        body = _body(request)
        result = read(
            settings.search,
            Path(_string(body, "path")),
            root=Path(_string(body, "root")),
            start_line=_integer(body, "start_line"),
            end_line=_integer(body, "end_line"),
        )
    except FileSearchRefused as refusal:
        return _json(400, {"error": refusal.message})
    return _json(
        200,
        {
            "path": result.path,
            "start_line": result.start_line,
            "end_line": result.end_line,
            "lines": list(result.lines),
        },
    )


def routes(settings: FilesToolSettings) -> tuple[Route, ...]:
    """The search and read routes, each gated by the settings' own session check."""
    return (
        Route.make("POST", FILES_SEARCH_ROUTE, lambda request: handle_search(settings, request)),
        Route.make("POST", FILES_READ_ROUTE, lambda request: handle_read(settings, request)),
    )
