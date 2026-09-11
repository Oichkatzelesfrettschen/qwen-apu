"""Document extraction as an owned subprocess, a content-addressed store, and three routes.

`DocumentService.extract` hands one job to `qwen_apu.tools.document_worker`
and owns everything the worker does not: the argv list with `shell=False`, a
new session so the whole process group answers one kill, a temporary working
directory under `<tmp>/documents/<job>`, a monotonic deadline that kills that
group on expiry, and an environment holding PATH, PYTHONPATH, TMPDIR, and
PYTHONDONTWRITEBYTECODE alone. PYTHONPATH names the directory the running
`qwen_apu` package sits in plus whatever `DocumentSettings.python_path` adds,
so the worker imports the package this service was imported from and resolves
pypdf from the wheel `wheelhouse/requirements.lock` pins; the child's working
directory and any ambient PYTHONPATH decide nothing.

Network isolation is probed once at service start: a child that reaches
`os.unshare(os.CLONE_NEWUSER | os.CLONE_NEWNET)` proves the kernel admits an
unprivileged user namespace here, and every later extraction installs that
same call as its `preexec_fn`, which runs between fork and exec in the
single-threaded child. Where the kernel refuses -- `kernel.unprivileged_userns_clone`
off, a seccomp filter, or a sandbox that is already a namespace -- the service
records `network_isolation: unavailable` in every record it writes and keeps
extracting, because the worker opens no socket of its own and the isolation is
defense in depth rather than the boundary itself.

The store is content-addressed by the source digest: `<artifacts>/documents/
<sha256>/` holds `<sha256>.json` and `chunks/<n>.txt`. A second extraction of
the same bytes finds that directory and answers from it, so a collision is the
ordinary case rather than an error, and publication is one `os.rename` of the
staging directory that loses a race by dropping its own copy.

`POST /api/documents`, `GET /api/documents/<sha256>`, and
`POST /api/documents/<sha256>/search` sit behind the injectable session check
that defaults to refused, the rule `tools/files.py` and `web/artifacts.py`
both carry: a caller that wires no session authority serves nothing.

The upload route reads its own body: `Route.make(..., streams=True)` hands it
`Request.stream`, and `stage_body` copies that stream block by block into
`<tmp>/documents/upload-<token>/` under `DocumentSettings.max_request_bytes`,
refusing at the block that crosses the bound rather than after the body
arrives. The bound is the route's own, so the gateway's one-mebibyte JSON cap
decides nothing here and keeps deciding everywhere else. A multipart body
stages whole and the file part's byte range copies out of it, so the peak
memory is one block whatever the upload's size.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
import shutil
import signal
import subprocess
import sys
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import IO, cast

from qwen_apu.tools.document_worker import (
    SEARCH_BOUNDED,
    Boundary,
    Chunk,
    DocumentRecord,
    ExtractionRefused,
    Limits,
    SearchBounded,
    SearchBounds,
    compile_query,
    read_record,
)
from qwen_apu.web.http import Request, Response, Route

DOCUMENTS_ROUTE = "/api/documents"
DOCUMENT_ROUTE = r"/api/documents/(?P<digest>[0-9a-f]{64})"
DOCUMENT_SEARCH_ROUTE = r"/api/documents/(?P<digest>[0-9a-f]{64})/search"

WORKER_MODULE = "qwen_apu.tools.document_worker"
STORE_DIRECTORY = "documents"
JOB_TOKEN_BYTES = 8
DEFAULT_DEADLINE_SECONDS = 120.0
DEFAULT_MAX_UPLOAD_BYTES = 32 * 1024 * 1024
# The request body the upload route admits, which carries the file plus the
# multipart framing around it, so it sits above the file's own cap.
DEFAULT_MAX_REQUEST_BYTES = 64 * 1024 * 1024
DEFAULT_MAX_SEARCH_HITS = 200
UPLOAD_BLOCK_BYTES = 64 * 1024
# The multipart file part's own headers are read from this prefix of the
# staged body, so a form whose fields precede the file by more than this
# refuses by name rather than reading an unbounded head.
MULTIPART_HEAD_BYTES = 64 * 1024
PROBE_TIMEOUT_SECONDS = 10.0
KILL_GRACE_SECONDS = 5.0
EXCERPT_MAX_CHARS = 400
FILENAME_PATTERN = re.compile(r"^[\w][\w .()+-]{0,127}$")
DIGEST_PATTERN = re.compile(r"^[0-9a-f]{64}$")
MULTIPART_BOUNDARY_PATTERN = re.compile(r'boundary="?([^";]+)"?', re.IGNORECASE)
DISPOSITION_FILENAME_PATTERN = re.compile(r'filename="([^"]*)"', re.IGNORECASE)

NETWORK_ISOLATION_NAMESPACED = "namespaced"
NETWORK_ISOLATION_UNAVAILABLE = "unavailable"

# The probe runs the same two flags the extraction installs, so what it proves
# is what the extraction performs rather than a weaker approximation of it.
ISOLATION_PROBE_SOURCE = "import os\nos.unshare(os.CLONE_NEWUSER | os.CLONE_NEWNET)\n"


class DocumentRefused(Exception):
    """One refusal carrying the HTTP status the boundary answers with.

    `kind` names a refusal a caller acts on rather than reads: a search that
    met one of its bounds answers `search_bounded` whichever bound it was, so
    the client distinguishes it from a malformed query without parsing prose.
    """

    def __init__(self, status: int, message: str, kind: str = "") -> None:
        super().__init__(message)
        self.status = status
        self.message = message
        self.kind = kind


@dataclass(frozen=True, slots=True)
class SearchHit:
    """One match inside one chunk, named in the document's own coordinates."""

    chunk_index: int
    chunk_sha256: str
    char_start: int
    char_end: int
    text: str
    boundaries: tuple[str, ...]

    def to_json(self) -> dict[str, object]:
        return {
            "chunk_index": self.chunk_index,
            "chunk_sha256": self.chunk_sha256,
            "char_start": self.char_start,
            "char_end": self.char_end,
            "text": self.text,
            "boundaries": list(self.boundaries),
        }


def session_refused(request: Request) -> bool:
    """The default session check: no session admits a call."""
    return False


@dataclass(frozen=True, slots=True)
class DocumentSettings:
    """Where the store and the scratch live, what bounds a job, and who is admitted."""

    artifacts: Path
    tmp: Path
    limits: Limits = field(default_factory=Limits)
    deadline_seconds: float = DEFAULT_DEADLINE_SECONDS
    max_upload_bytes: int = DEFAULT_MAX_UPLOAD_BYTES
    max_request_bytes: int = DEFAULT_MAX_REQUEST_BYTES
    max_search_hits: int = DEFAULT_MAX_SEARCH_HITS
    search_bounds: SearchBounds = field(default_factory=SearchBounds)
    worker_command: tuple[str, ...] = ()
    python_path: tuple[Path, ...] = ()
    session_admits: Callable[[Request], bool] = session_refused

    def command(self) -> tuple[str, ...]:
        """The worker argv: the settings' own, or this interpreter running the module."""
        return self.worker_command or (sys.executable, "-m", WORKER_MODULE)

    def store(self) -> Path:
        return self.artifacts / STORE_DIRECTORY

    def scratch(self) -> Path:
        return self.tmp / STORE_DIRECTORY


def probe_network_isolation(timeout: float = PROBE_TIMEOUT_SECONDS) -> str:
    """Report whether an unprivileged user and network namespace is reachable here.

    The probe is a child rather than a call in this process: unsharing a user
    namespace in the gateway would move every later syscall into it, and a
    multithreaded process cannot unshare one at all.
    """
    try:
        completed = subprocess.run(  # noqa: S603
            [sys.executable, "-c", ISOLATION_PROBE_SOURCE],
            check=False,
            capture_output=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return NETWORK_ISOLATION_UNAVAILABLE
    if completed.returncode == 0:
        return NETWORK_ISOLATION_NAMESPACED
    return NETWORK_ISOLATION_UNAVAILABLE


def _isolate_child() -> None:
    """Drop the child into its own user and network namespace before exec.

    One syscall runs between fork and exec, which is what keeps this callable
    safe in a process that holds locks elsewhere.
    """
    os.unshare(os.CLONE_NEWUSER | os.CLONE_NEWNET)


def _package_directory() -> Path:
    """The directory holding the `qwen_apu` package this module was imported from."""
    return Path(__file__).resolve().parents[2]


def safe_filename(name: str) -> str:
    """Return the base name a record carries, refusing a name that is not one.

    The name reaches the record and the extension decides the extractor, so a
    path separator, a leading dot, and a control character all refuse here
    rather than reaching a `Path` join or a log line.
    """
    stripped = name.strip()
    if "/" in stripped or "\\" in stripped or ".." in stripped:
        raise DocumentRefused(400, f"{name!r} names a path rather than a file")
    if not FILENAME_PATTERN.match(os.path.basename(stripped)):
        raise DocumentRefused(400, f"{name!r} is not a plain file name")
    return os.path.basename(stripped)


class DocumentService:
    """Extraction, storage, and retrieval for one settings object."""

    def __init__(self, settings: DocumentSettings) -> None:
        self.settings = settings
        self.network_isolation = probe_network_isolation()

    # --- extraction ----------------------------------------------------------

    def extract(self, path: Path, media_type: str, filename: str = "") -> DocumentRecord:
        """Extract one file through the worker and publish it into the store.

        The digest decides first: bytes already in the store answer from it and
        start no process, which is what makes a re-upload cost one read.
        """
        name = safe_filename(filename or path.name)
        try:
            size = path.stat().st_size
        except OSError as error:
            raise DocumentRefused(400, f"the input is unreadable: {error}") from None
        if size > self.settings.max_upload_bytes:
            raise DocumentRefused(
                413,
                f"the input is {size} bytes, past the "
                f"{self.settings.max_upload_bytes}-byte upload cap",
            )
        digest = _digest_file(path)
        stored = self.settings.store() / digest
        if (stored / f"{digest}.json").is_file():
            return read_record(stored, digest)
        job_directory = self.settings.scratch() / secrets.token_hex(JOB_TOKEN_BYTES)
        job_directory.mkdir(parents=True)
        try:
            self._run_worker(path, name, media_type, job_directory)
            record = read_record(job_directory, digest)
            _publish(job_directory, stored)
        finally:
            shutil.rmtree(job_directory, ignore_errors=True)
        return record

    def _run_worker(self, path: Path, filename: str, media_type: str, job_directory: Path) -> None:
        """Run one extraction to completion, killing its group on the deadline."""
        job = json.dumps(
            {
                "mode": "extract",
                "input_path": str(path.resolve()),
                "filename": filename,
                "media_type": media_type,
                "output_directory": str(job_directory),
                "limits": self.settings.limits.to_json(),
                "network_isolation": self.network_isolation,
            }
        ).encode("utf-8")
        returncode, stdout, stderr = self._run_job(job, job_directory, "extraction")
        if returncode != 0:
            raise DocumentRefused(400, _worker_error(returncode, stdout, stderr))

    def _run_job(self, job: bytes, job_directory: Path, what: str) -> tuple[int, bytes, bytes]:
        """Run one worker to completion, killing its group on the deadline."""
        environment = {
            "PATH": os.environ.get("PATH", os.defpath),
            "PYTHONPATH": os.pathsep.join(
                [str(_package_directory()), *(str(entry) for entry in self.settings.python_path)]
            ),
            "PYTHONDONTWRITEBYTECODE": "1",
            "TMPDIR": str(job_directory),
        }
        isolate = _isolate_child if self.network_isolation == NETWORK_ISOLATION_NAMESPACED else None
        deadline = time.monotonic() + self.settings.deadline_seconds
        try:
            process = subprocess.Popen(  # noqa: S603
                list(self.settings.command()),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(job_directory),
                env=environment,
                start_new_session=True,
                preexec_fn=isolate,  # noqa: PLW1509
            )
        except OSError as error:
            raise DocumentRefused(500, f"the worker did not start: {error}") from None
        try:
            stdout, stderr = process.communicate(job, timeout=max(0.0, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            _kill_group(process)
            raise DocumentRefused(
                504,
                f"the {what} passed its {self.settings.deadline_seconds:g}-second deadline "
                "and its process group was killed",
            ) from None
        return process.returncode, stdout, stderr

    # --- retrieval -----------------------------------------------------------

    def record(self, digest: str) -> DocumentRecord:
        """Read one stored record, refusing an unstored digest."""
        if not DIGEST_PATTERN.match(digest):
            raise DocumentRefused(400, "the digest is not 64 lowercase hexadecimal characters")
        stored = self.settings.store() / digest
        if not (stored / f"{digest}.json").is_file():
            raise DocumentRefused(404, f"no document is stored under {digest}")
        return read_record(stored, digest)

    def search(self, digest: str, query: str, *, regex: bool = False) -> tuple[SearchHit, ...]:
        """Return every match over the stored chunks, in chunk order.

        A hit names the chunk that holds it, the chunk's digest, the match's
        own span in the document's character coordinates, and every boundary
        the match falls inside, so a caller cites a page, a paragraph, or a row
        rather than an offset alone.

        A literal query is the default and scans here: `str.find` walks each
        chunk once and backtracks over nothing, so the cost is the document's
        own size and the candidate-chunk bound is what limits it. `regex=True`
        hands the pattern to the worker, where the wall-clock timer, the CPU
        cap, and the address-space cap bound what it spends; this process
        compiles it first so an invalid pattern refuses without a spawn, and
        the worker applies every bound again as the authority. Each bound
        answers `search_bounded`.
        """
        if not query:
            raise DocumentRefused(400, "the query is empty")
        record = self.record(digest)
        stored = self.settings.store() / digest
        bounds = self.settings.search_bounds
        if len(record.chunks) > bounds.max_candidate_chunks:
            raise DocumentRefused(
                400,
                f"the document holds {len(record.chunks)} chunks, past the "
                f"{bounds.max_candidate_chunks}-chunk search bound",
                SEARCH_BOUNDED,
            )
        if regex:
            try:
                compile_query(query, regex=True, bounds=bounds)
            except SearchBounded as bounded:
                raise DocumentRefused(400, bounded.message, SEARCH_BOUNDED) from None
            except ExtractionRefused as refusal:
                raise DocumentRefused(400, refusal.message) from None
            matches = self._search_through_worker(stored, digest, query)
        else:
            matches = _literal_matches(stored, record, query, self.settings.max_search_hits)
        return _hits(stored, record, matches[: self.settings.max_search_hits])

    def _search_through_worker(
        self, stored: Path, digest: str, query: str
    ) -> list[tuple[int, int, int]]:
        """Run one regular expression in the worker and read back its matches.

        The bounds travel with the job and the worker owns them, so a pattern
        that never returns to Python ends on the timer the worker armed on
        itself; this process reads that signal from the exit status and names
        the same refusal the worker's own object carries.
        """
        job = json.dumps(
            {
                "mode": "search",
                "document_directory": str(stored),
                "digest": digest,
                "query": query,
                "regex": True,
                "bounds": self.settings.search_bounds.to_json(),
                "limits": self.settings.limits.to_json(),
                "max_hits": self.settings.max_search_hits,
            }
        ).encode("utf-8")
        directory = self.settings.scratch() / f"search-{secrets.token_hex(JOB_TOKEN_BYTES)}"
        directory.mkdir(parents=True)
        try:
            returncode, stdout, stderr = self._run_job(job, directory, "search")
        finally:
            shutil.rmtree(directory, ignore_errors=True)
        if returncode == 0:
            return _worker_matches(stdout)
        raise _search_refusal(
            returncode, stdout, stderr, self.settings.search_bounds.wall_clock_seconds
        )

    def chunk_text(self, digest: str, index: int) -> str:
        """Return one chunk's text, refusing an index the record does not carry."""
        record = self.record(digest)
        if not any(chunk.index == index for chunk in record.chunks):
            raise DocumentRefused(404, f"document {digest} carries no chunk {index}")
        return (self.settings.store() / digest / "chunks" / f"{index}.txt").read_text(
            encoding="utf-8"
        )


def _digest_file(path: Path, block: int = 1024 * 1024) -> str:
    """The source digest, read in blocks so a large upload never sits in memory twice."""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            data = handle.read(block)
            if not data:
                break
            digest.update(data)
    return digest.hexdigest()


def _publish(staging: Path, stored: Path) -> None:
    """Move the staging directory into the store, keeping the published copy.

    `os.rename` refuses a non-empty target, which is the ordinary case for a
    content-addressed store: a second extraction of the same bytes lost the
    race and drops its own copy. A target holding no `<digest>.json` published
    nothing -- a run killed between `mkdir` and the record write leaves exactly
    that -- so the partial directory goes and the rename runs again, which
    keeps a crash from making one digest permanently unreadable.
    """
    stored.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.rename(staging, stored)
        return
    except OSError:
        if (stored / f"{stored.name}.json").is_file():
            return
    shutil.rmtree(stored, ignore_errors=True)
    os.rename(staging, stored)


def _kill_group(process: subprocess.Popen[bytes]) -> None:
    """Kill the whole session the worker leads, then reap it."""
    try:
        os.killpg(os.getpgid(process.pid), 9)
    except (OSError, ProcessLookupError):
        pass
    try:
        process.communicate(timeout=KILL_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        process.kill()
        process.communicate()


def _worker_error(returncode: int, stdout: bytes, stderr: bytes) -> str:
    """The worker's own refusal text, or the signal that ended it."""
    try:
        payload: object = json.loads(stdout.decode("utf-8"))
    except ValueError:
        payload = None
    if isinstance(payload, dict):
        error = cast(Mapping[str, object], payload).get("error")
        if isinstance(error, str) and error:
            return error
    if returncode < 0:
        return f"the worker was ended by signal {-returncode}"
    tail = stderr.decode("utf-8", errors="replace").strip().splitlines()
    return tail[-1] if tail else f"the worker exited {returncode}"


def _chunk_body(stored: Path, index: int) -> str:
    return (stored / "chunks" / f"{index}.txt").read_text(encoding="utf-8")


def _literal_matches(
    stored: Path, record: DocumentRecord, query: str, max_hits: int
) -> list[tuple[int, int, int]]:
    """Every occurrence of the query's own characters, chunk by chunk.

    `str.find` advances by the query's length, which is the non-overlapping
    walk `finditer` performs, so a literal query and its escaped pattern
    report one count.
    """
    matches: list[tuple[int, int, int]] = []
    for chunk in record.chunks:
        body = _chunk_body(stored, chunk.index)
        position = body.find(query)
        while position >= 0:
            matches.append((chunk.index, position, position + len(query)))
            if len(matches) >= max_hits:
                return matches
            position = body.find(query, position + len(query))
    return matches


def _worker_matches(stdout: bytes) -> list[tuple[int, int, int]]:
    """The matches one search worker printed, as chunk index and character span."""
    try:
        payload: object = json.loads(stdout.decode("utf-8"))
    except ValueError:
        raise DocumentRefused(500, "the search worker printed no report") from None
    if not isinstance(payload, dict):
        raise DocumentRefused(500, "the search worker printed no report object")
    raw = cast(Mapping[str, object], payload).get("matches", [])
    matches: list[tuple[int, int, int]] = []
    for entry in cast(Sequence[Mapping[str, int]], raw):
        matches.append(
            (int(entry["chunk_index"]), int(entry["char_start"]), int(entry["char_end"]))
        )
    return matches


def _search_refusal(
    returncode: int, stdout: bytes, stderr: bytes, wall_clock_seconds: float
) -> DocumentRefused:
    """The refusal one failed search worker earned, named by what ended it.

    A refusal object carries its own name. A signal carries none, so the two
    the bounds raise -- SIGALRM from the worker's own timer and SIGXCPU from
    its CPU cap -- map to the same name here, since both say the pattern spent
    what the bounds allow.
    """
    try:
        payload: object = json.loads(stdout.decode("utf-8"))
    except ValueError:
        payload = None
    if isinstance(payload, dict):
        report = cast(Mapping[str, object], payload)
        if report.get("refusal") == SEARCH_BOUNDED:
            return DocumentRefused(400, str(report.get("error", "")), SEARCH_BOUNDED)
    if returncode in (-signal.SIGALRM, -signal.SIGXCPU):
        name = signal.Signals(-returncode).name
        return DocumentRefused(
            400,
            f"the search was ended by {name} at its {wall_clock_seconds:g}-second bound",
            SEARCH_BOUNDED,
        )
    return DocumentRefused(400, _worker_error(returncode, stdout, stderr))


def _hits(
    stored: Path, record: DocumentRecord, matches: Sequence[tuple[int, int, int]]
) -> tuple[SearchHit, ...]:
    """One hit per match, in the document's own coordinates.

    The chunk bodies a hit lands in are read here and nowhere else, so a
    search that matched two chunks reads two files whatever the document's
    size.
    """
    chunks = {chunk.index: chunk for chunk in record.chunks}
    bodies: dict[int, str] = {}
    hits: list[SearchHit] = []
    for index, start, end in matches:
        chunk = chunks.get(index)
        if chunk is None:
            raise DocumentRefused(500, f"the search named chunk {index}, which the record omits")
        if index not in bodies:
            bodies[index] = _chunk_body(stored, index)
        body = bodies[index]
        hits.append(
            SearchHit(
                chunk_index=index,
                chunk_sha256=chunk.sha256,
                char_start=chunk.char_start + start,
                char_end=chunk.char_start + end,
                text=_excerpt(body, start, end),
                boundaries=_covering(
                    record.boundaries, chunk.char_start + start, chunk.char_start + end
                ),
            )
        )
    return tuple(hits)


def _excerpt(body: str, start: int, end: int) -> str:
    """The line the match sits on, bounded to 400 characters."""
    line_start = body.rfind("\n", 0, start) + 1
    line_end = body.find("\n", end)
    line = body[line_start : line_end if line_end >= 0 else len(body)]
    return line[:EXCERPT_MAX_CHARS]


def _covering(boundaries: Sequence[Boundary], start: int, end: int) -> tuple[str, ...]:
    return tuple(
        f"{boundary.kind}:{boundary.index}"
        for boundary in boundaries
        if boundary.char_start < end and boundary.char_end > start
    )


# --- HTTP routes -------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Upload:
    """One uploaded file: what it is called, what it claims to be, and its bytes."""

    filename: str
    media_type: str
    data: bytes


def parse_upload(request: Request) -> Upload:
    """Read the uploaded file from a multipart body or from the raw body.

    The multipart form is split on the declared boundary rather than parsed by
    the email package, so the file part's bytes reach the store exactly as the
    browser sent them. The raw form takes the whole body and names the file
    through `X-Filename`, which is what a fetch of a File object sends.
    """
    content_type = request.header("content-type")
    if content_type.lower().startswith("multipart/form-data"):
        return _parse_multipart(content_type, request.body)
    name = request.header("x-filename")
    if not name:
        raise DocumentRefused(400, "the request names no file through X-Filename")
    if not request.body:
        raise DocumentRefused(400, "the request carries an empty body")
    return Upload(safe_filename(name), content_type.split(";")[0].strip(), request.body)


def _parse_multipart(content_type: str, body: bytes) -> Upload:
    found = MULTIPART_BOUNDARY_PATTERN.search(content_type)
    if not found:
        raise DocumentRefused(400, "the multipart content type declares no boundary")
    delimiter = b"--" + found.group(1).encode("utf-8")
    for section in body.split(delimiter):
        head, separator, payload = section.partition(b"\r\n\r\n")
        if not separator:
            continue
        headers = _part_headers(head)
        disposition = headers.get("content-disposition", "")
        name = DISPOSITION_FILENAME_PATTERN.search(disposition)
        if not name:
            continue
        data = payload[:-2] if payload.endswith(b"\r\n") else payload
        return Upload(
            safe_filename(name.group(1)),
            headers.get("content-type", "").split(";")[0].strip(),
            data,
        )
    raise DocumentRefused(400, "the multipart body carries no file part")


def stage_body(
    read: Callable[[int], bytes],
    declared: int,
    target: Path,
    bound: int,
    block: int = UPLOAD_BLOCK_BYTES,
) -> int:
    """Copy a request body into `target`, refusing at the bound while reading.

    Two refusals meet the same bound from opposite sides. A Content-Length
    past the bound refuses at constant cost, before one byte leaves the
    socket. The running count refuses at the block that crosses the bound,
    which is what answers a body whose declaration understates it: the copy
    stops there, so the staged file holds at most `bound` bytes and the reader
    is never asked for the rest.
    """
    if declared > bound:
        raise DocumentRefused(
            413, f"the request declares {declared} bytes, past the {bound}-byte upload bound"
        )
    written = 0
    with target.open("wb") as handle:
        while True:
            data = read(block)
            if not data:
                break
            written += len(data)
            if written > bound:
                raise DocumentRefused(413, f"the request body passes the {bound}-byte upload bound")
            handle.write(data)
    return written


def _find_delimiter(handle: IO[bytes], start: int, delimiter: bytes) -> int:
    """The offset of the first `CRLF--boundary` at or after `start`, or -1.

    The window keeps one byte less than the needle across reads, so a
    delimiter split across two blocks is found at the same offset a whole-file
    search would report while the memory stays one block.
    """
    needle = b"\r\n" + delimiter
    handle.seek(start)
    offset = start
    window = b""
    while True:
        data = handle.read(UPLOAD_BLOCK_BYTES)
        if not data:
            return -1
        window += data
        found = window.find(needle)
        if found >= 0:
            return offset + found
        keep = len(needle) - 1
        if len(window) > keep:
            offset += len(window) - keep
            window = window[-keep:]


def _copy_range(source: Path, target: Path, start: int, end: int) -> None:
    """Copy `[start, end)` of one file into another, one block at a time."""
    remaining = end - start
    with source.open("rb") as reader, target.open("wb") as writer:
        reader.seek(start)
        while remaining > 0:
            data = reader.read(min(UPLOAD_BLOCK_BYTES, remaining))
            if not data:
                raise DocumentRefused(400, "the multipart body ends inside its file part")
            writer.write(data)
            remaining -= len(data)


def stage_multipart_part(body: Path, content_type: str, target: Path) -> tuple[str, str]:
    """Write the file part of a staged multipart body into `target`.

    The part's own headers come from the head of the staged body and its
    content ends at the next delimiter, found by a blockwise scan, so a form
    carrying fields after the file keeps the file's exact bytes.
    """
    found = MULTIPART_BOUNDARY_PATTERN.search(content_type)
    if not found:
        raise DocumentRefused(400, "the multipart content type declares no boundary")
    delimiter = b"--" + found.group(1).encode("utf-8")
    with body.open("rb") as handle:
        head = handle.read(MULTIPART_HEAD_BYTES)
        position = head.find(delimiter)
        while position >= 0:
            end_of_headers = head.find(b"\r\n\r\n", position)
            if end_of_headers < 0:
                break
            headers = _part_headers(head[position + len(delimiter) : end_of_headers])
            name = DISPOSITION_FILENAME_PATTERN.search(headers.get("content-disposition", ""))
            if name:
                start = end_of_headers + 4
                end = _find_delimiter(handle, start, delimiter)
                if end < 0:
                    raise DocumentRefused(
                        400, "the multipart file part carries no closing boundary"
                    )
                _copy_range(body, target, start, end)
                return (
                    safe_filename(name.group(1)),
                    headers.get("content-type", "").split(";")[0].strip(),
                )
            position = head.find(delimiter, end_of_headers)
    raise DocumentRefused(
        400,
        f"the first {MULTIPART_HEAD_BYTES} bytes of the multipart body carry no file part",
    )


def _part_headers(head: bytes) -> dict[str, str]:
    headers: dict[str, str] = {}
    for line in head.decode("utf-8", errors="replace").splitlines():
        name, separator, value = line.partition(":")
        if separator:
            headers[name.strip().lower()] = value.strip()
    return headers


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


def _refused(refusal: DocumentRefused) -> Response:
    """One refusal as JSON, naming its kind where the refusal carries one."""
    body: dict[str, object] = {"error": refusal.message}
    if refusal.kind:
        body["refusal"] = refusal.kind
    return _json(refusal.status, body)


def _body(request: Request) -> Mapping[str, object]:
    try:
        parsed: object = request.json()
    except ValueError:
        raise DocumentRefused(400, "the request body is not JSON") from None
    if not isinstance(parsed, dict):
        raise DocumentRefused(400, "the request body is not a JSON object")
    return cast(Mapping[str, object], parsed)


def stage_upload(
    settings: DocumentSettings, request: Request, directory: Path
) -> tuple[Path, str, str]:
    """Put the uploaded file in `directory` and name what it is.

    A streamed request copies the socket into `body` under the request bound
    and takes its name from the multipart part or from `X-Filename`. A request
    whose body an in-process caller carries whole takes the same shape through
    `parse_upload`, which is what keeps one code path serving both.
    """
    stream = request.stream
    if stream is None:
        upload = parse_upload(request)
        if len(upload.data) > settings.max_request_bytes:
            raise DocumentRefused(
                413,
                f"the request body is {len(upload.data)} bytes, past the "
                f"{settings.max_request_bytes}-byte upload bound",
            )
        staged = directory / "body"
        staged.write_bytes(upload.data)
        return staged, upload.filename, upload.media_type
    body = directory / "body"
    written = stage_body(stream.read, stream.length, body, settings.max_request_bytes)
    if written == 0:
        raise DocumentRefused(400, "the request carries an empty body")
    content_type = request.header("content-type")
    if content_type.lower().startswith("multipart/form-data"):
        part = directory / "part"
        filename, media_type = stage_multipart_part(body, content_type, part)
        body.unlink(missing_ok=True)
        return part, filename, media_type
    name = request.header("x-filename")
    if not name:
        raise DocumentRefused(400, "the request names no file through X-Filename")
    return body, safe_filename(name), content_type.split(";")[0].strip()


def handle_upload(service: DocumentService, request: Request) -> Response:
    """Store one uploaded document and answer with its record."""
    if not service.settings.session_admits(request):
        return _json(401, {"error": "the request carries no admitted session"})
    job = service.settings.scratch() / f"upload-{secrets.token_hex(JOB_TOKEN_BYTES)}"
    try:
        job.mkdir(parents=True)
        source, filename, media_type = stage_upload(service.settings, request, job)
        record = service.extract(source, media_type, filename)
    except DocumentRefused as refusal:
        return _refused(refusal)
    finally:
        shutil.rmtree(job, ignore_errors=True)
    return _json(201, record.to_json())


def handle_record(service: DocumentService, request: Request) -> Response:
    """Answer one stored record, behind the injectable session check."""
    if not service.settings.session_admits(request):
        return _json(401, {"error": "the request carries no admitted session"})
    try:
        record = service.record(request.path_params.get("digest", ""))
    except DocumentRefused as refusal:
        return _refused(refusal)
    return _json(200, record.to_json())


def handle_search(service: DocumentService, request: Request) -> Response:
    """Answer one search over one stored document's chunks.

    `regex` is absent by default, so a query is literal unless the request
    names the flag; a bound the search meets answers `search_bounded` in the
    refusal body beside its own text.
    """
    if not service.settings.session_admits(request):
        return _json(401, {"error": "the request carries no admitted session"})
    try:
        body = _body(request)
        query = body.get("query")
        if not isinstance(query, str) or not query:
            raise DocumentRefused(400, "query is absent or is not a nonempty string")
        regex = body.get("regex", False)
        if not isinstance(regex, bool):
            raise DocumentRefused(400, "regex is not a boolean")
        digest = request.path_params.get("digest", "")
        hits = service.search(digest, query, regex=regex)
    except DocumentRefused as refusal:
        return _refused(refusal)
    return _json(200, {"sha256": digest, "hits": [hit.to_json() for hit in hits]})


def routes(service: DocumentService) -> tuple[Route, ...]:
    """The upload, record, and search routes, each gated by the settings' session check."""
    return (
        Route.make(
            "POST",
            DOCUMENTS_ROUTE,
            lambda request: handle_upload(service, request),
            streams=True,
        ),
        Route.make("POST", DOCUMENT_SEARCH_ROUTE, lambda request: handle_search(service, request)),
        Route.make("GET", DOCUMENT_ROUTE, lambda request: handle_record(service, request)),
    )


__all__ = [
    "Boundary",
    "Chunk",
    "DocumentRecord",
    "DocumentRefused",
    "DocumentService",
    "DocumentSettings",
    "Limits",
    "SearchHit",
    "Upload",
    "handle_record",
    "handle_search",
    "handle_upload",
    "parse_upload",
    "probe_network_isolation",
    "routes",
    "safe_filename",
    "stage_body",
    "stage_multipart_part",
    "stage_upload",
]
