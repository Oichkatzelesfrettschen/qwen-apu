"""One extraction job, one process: read the job on stdin, write the record.

    printf '%s' "$job" | python -m qwen_apu.tools.document_worker

The job is one JSON object naming a mode. `extract`, the default, names the
input path, the original filename, the media type, the output directory, and
the limits; the worker writes `<sha256 of the source>.json` and
`chunks/<n>.txt` under that directory and exits 0, or prints one refusal
object and exits 1. `search` names a stored document's directory, its digest,
the query, and the search bounds; the worker prints every match as a chunk
index and a character span. Nothing else crosses the boundary, so the process
that owns the job decides the deadline, the working directory, and the
environment while this process decides nothing about its own lifetime.

A regular expression runs here rather than in the gateway because this
process is the one that can be ended. `arm_wall_clock` raises SIGALRM at its
default disposition, which the kernel delivers into a match that reaches no
bytecode boundary, and `apply_limits` adds the CPU and address-space caps;
the pattern's own size and group count and the candidate-chunk count refuse
ahead of the first match. Every one of those answers `search_bounded`.

The limits apply before the input is read, which is the order that makes them
bounds rather than reports. `resource.setrlimit` caps address space, CPU time,
and file size, so a decompression bomb, a pathological regular expression, and
a runaway write each end in a signal the parent reads rather than in a machine
the parent shares. The zip guard runs ahead of every OOXML member read: the
central directory's declared total and member count refuse first, and each
member is then read one byte past its own cap and refused where it exceeds
it, since a central directory states what an archive claims rather than what
it holds. The XML parts refuse a document type declaration outright, so the
internal entity expansion `xml.etree` performs for a declared entity has no
declaration to expand.

Each extractor returns the text, the boundaries that tile it, the format it
detected, and its warnings. A boundary is `(kind, index, char_start,
char_end, label)` over the extracted text, and each format states its own
vocabulary:

| Format | Primary kind | Every kind it records | What a label carries |
| --- | --- | --- | --- |
| text, source, json | line | line | -- |
| markdown | heading | heading | the heading line |
| html | heading | heading | the heading text |
| csv, tsv | row | sheet, row | the file stem on the sheet |
| docx | paragraph | page, heading, paragraph | the heading's own text |
| xlsx | sheet | sheet, row | the sheet name, and `Sheet!A1:B1` on a row |
| pptx | slide | slide | the slide's first line |
| pdf | page | page | -- |

Chunking walks the primary kind's boundaries and fills up to 1200
characters, so a chunk ends on a page, a paragraph, or a row wherever one
lands inside the budget and cuts at the last line break otherwise.

A PDF page whose extracted text is empty while the page's resources name an
image XObject is reported through `requires_ocr`, which carries the page
numbers. The document still records every other page's text, so a mixed PDF
answers with what it has beside the list of what it cannot read; a document
that yielded no text at all states `ocr_required` in the record's `state`,
which is what separates a scan from a success over an empty document.
"""

from __future__ import annotations

import csv
import hashlib
import importlib
import io
import json
import os
import re
import resource
import signal
import sys
import time
import zipfile
from collections.abc import Callable, Iterator, Mapping, Sequence
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, cast
from xml.etree import ElementTree

WORKER_NAME = "qwen-apu-document-worker"
# The version a record carries names what the extractors record, so heading
# boundaries on a DOCX, cell ranges on a spreadsheet row, and the extraction
# state move it together with the schema.
WORKER_VERSION = "2"
RECORD_SCHEMA = "qwen-apu-document-record-2"

# What one extraction established about its source. A record whose text is
# blank while its pages carry images states `ocr_required` rather than
# reporting an empty extraction as a complete one.
STATE_EXTRACTED = "extracted"
STATE_OCR_REQUIRED = "ocr_required"


def state_of(requires_ocr: Sequence[int], characters: int) -> str:
    """The state one pair of numbers reports: pages needing OCR and no characters."""
    return STATE_OCR_REQUIRED if requires_ocr and characters == 0 else STATE_EXTRACTED


CHUNK_MAX_CHARS = 1200
TOKEN_ESTIMATE_CHARS = 4
# The name stays free of the word a secret scanner reserves; the value is the
# divisor this worker names in every record.
ESTIMATE_BASIS = "chars/4"

DEFAULT_MAX_INPUT_BYTES = 32 * 1024 * 1024
DEFAULT_ADDRESS_SPACE_BYTES = 1024 * 1024 * 1024
DEFAULT_CPU_SECONDS = 60
DEFAULT_MAX_OUTPUT_BYTES = 64 * 1024 * 1024
DEFAULT_MAX_UNCOMPRESSED_BYTES = 64 * 1024 * 1024
DEFAULT_MAX_ARCHIVE_MEMBERS = 512

MODE_EXTRACT = "extract"
MODE_SEARCH = "search"
# The one name every search bound answers with, whether the pattern, the
# candidate chunks, or the clock is what it met.
SEARCH_BOUNDED = "search_bounded"
DEFAULT_MAX_PATTERN_CHARS = 200
DEFAULT_MAX_PATTERN_GROUPS = 20
DEFAULT_MAX_CANDIDATE_CHUNKS = 2048
DEFAULT_SEARCH_SECONDS = 5.0
DEFAULT_MAX_SEARCH_HITS = 200

WORD_NAMESPACE = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
SPREADSHEET_NAMESPACE = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
DRAWING_NAMESPACE = "http://schemas.openxmlformats.org/drawingml/2006/main"
OFFICE_RELATIONSHIP_NAMESPACE = (
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
)
PACKAGE_RELATIONSHIP_NAMESPACE = "http://schemas.openxmlformats.org/package/2006/relationships"

SLIDE_NAME_PATTERN = re.compile(r"^ppt/slides/slide(\d+)\.xml$")
# Word names a heading paragraph by its style id, which the publishers this
# tree reads spell `Heading1` and `Heading 1`; the outline level lives in
# `styles.xml`, so the style id is what one part answers.
HEADING_STYLE_PATTERN = re.compile(r"^heading\s*\d+$", re.IGNORECASE)
DOCTYPE_PATTERN = re.compile(rb"<!DOCTYPE", re.IGNORECASE)
HTML_BLOCK_TAGS = frozenset(
    {"p", "div", "li", "tr", "br", "section", "article", "header", "footer", "blockquote", "pre"}
)
HTML_HEADING_TAGS = ("h1", "h2", "h3", "h4", "h5", "h6")
HTML_SKIPPED_TAGS = frozenset({"script", "style", "head"})

# The extension decides the format because a browser reports `.py` as
# `text/x-python`, `application/octet-stream`, or nothing at all depending on
# the platform, while the name the operator uploaded carries the author's own
# declaration. The media type answers where the extension names no format.
FORMAT_EXTENSIONS: Mapping[str, str] = {
    ".txt": "text",
    ".text": "text",
    ".log": "text",
    ".md": "markdown",
    ".markdown": "markdown",
    ".json": "json",
    ".csv": "csv",
    ".tsv": "tsv",
    ".html": "html",
    ".htm": "html",
    ".xhtml": "html",
    ".docx": "docx",
    ".xlsx": "xlsx",
    ".pptx": "pptx",
    ".pdf": "pdf",
}

# Source code takes its own extractor: the text passes through verbatim and
# the language the extension names reaches the record.
SOURCE_LANGUAGES: Mapping[str, str] = {
    ".c": "c",
    ".h": "c",
    ".cc": "cpp",
    ".cpp": "cpp",
    ".hpp": "cpp",
    ".cmake": "cmake",
    ".comp": "glsl",
    ".glsl": "glsl",
    ".go": "go",
    ".ini": "ini",
    ".java": "java",
    ".js": "javascript",
    ".mjs": "javascript",
    ".patch": "diff",
    ".diff": "diff",
    ".py": "python",
    ".rb": "ruby",
    ".rs": "rust",
    ".sh": "shell",
    ".sql": "sql",
    ".toml": "toml",
    ".ts": "typescript",
    ".yaml": "yaml",
    ".yml": "yaml",
}

FORMAT_MEDIA_TYPES: Mapping[str, str] = {
    "text/plain": "text",
    "text/markdown": "markdown",
    "application/json": "json",
    "text/csv": "csv",
    "text/tab-separated-values": "tsv",
    "text/html": "html",
    "application/xhtml+xml": "html",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xlsx",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation": "pptx",
    "application/pdf": "pdf",
}


class ExtractionRefused(Exception):
    """One refusal: an unsupported format, a limit met, or a malformed container."""

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class SearchBounded(ExtractionRefused):
    """One search bound met, which the caller reads by its own name."""


@dataclass(frozen=True, slots=True)
class Limits:
    """The five caps one job runs under, each carried from the caller's settings."""

    max_input_bytes: int = DEFAULT_MAX_INPUT_BYTES
    address_space_bytes: int = DEFAULT_ADDRESS_SPACE_BYTES
    cpu_seconds: int = DEFAULT_CPU_SECONDS
    max_output_bytes: int = DEFAULT_MAX_OUTPUT_BYTES
    max_uncompressed_bytes: int = DEFAULT_MAX_UNCOMPRESSED_BYTES
    max_archive_members: int = DEFAULT_MAX_ARCHIVE_MEMBERS

    @classmethod
    def from_json(cls, payload: Mapping[str, object]) -> Limits:
        values: dict[str, int] = {}
        for name in cls.__slots__:
            raw = payload.get(name)
            if raw is None:
                continue
            if isinstance(raw, bool) or not isinstance(raw, int) or raw <= 0:
                raise ExtractionRefused(f"{name} is not a positive integer")
            values[name] = raw
        return cls(**values)

    def to_json(self) -> dict[str, int]:
        return {name: cast(int, getattr(self, name)) for name in self.__slots__}


def _positive_int(payload: Mapping[str, object], name: str, fallback: int) -> int:
    raw = payload.get(name)
    if raw is None:
        return fallback
    if isinstance(raw, bool) or not isinstance(raw, int) or raw <= 0:
        raise ExtractionRefused(f"{name} is not a positive integer")
    return raw


def _positive_float(payload: Mapping[str, object], name: str, fallback: float) -> float:
    raw = payload.get(name)
    if raw is None:
        return fallback
    if isinstance(raw, bool) or not isinstance(raw, int | float) or raw <= 0:
        raise ExtractionRefused(f"{name} is not a positive number")
    return float(raw)


@dataclass(frozen=True, slots=True)
class SearchBounds:
    """The four bounds one search runs under, each carried from the caller's settings."""

    max_pattern_chars: int = DEFAULT_MAX_PATTERN_CHARS
    max_pattern_groups: int = DEFAULT_MAX_PATTERN_GROUPS
    max_candidate_chunks: int = DEFAULT_MAX_CANDIDATE_CHUNKS
    wall_clock_seconds: float = DEFAULT_SEARCH_SECONDS

    @classmethod
    def from_json(cls, payload: Mapping[str, object]) -> SearchBounds:
        return cls(
            max_pattern_chars=_positive_int(
                payload, "max_pattern_chars", DEFAULT_MAX_PATTERN_CHARS
            ),
            max_pattern_groups=_positive_int(
                payload, "max_pattern_groups", DEFAULT_MAX_PATTERN_GROUPS
            ),
            max_candidate_chunks=_positive_int(
                payload, "max_candidate_chunks", DEFAULT_MAX_CANDIDATE_CHUNKS
            ),
            wall_clock_seconds=_positive_float(
                payload, "wall_clock_seconds", DEFAULT_SEARCH_SECONDS
            ),
        )

    def to_json(self) -> dict[str, float]:
        return {
            "max_pattern_chars": self.max_pattern_chars,
            "max_pattern_groups": self.max_pattern_groups,
            "max_candidate_chunks": self.max_candidate_chunks,
            "wall_clock_seconds": self.wall_clock_seconds,
        }


@dataclass(frozen=True, slots=True)
class Boundary:
    """One span of the extracted text: what it is, its ordinal, and where it sits."""

    kind: str
    index: int
    char_start: int
    char_end: int
    label: str = ""

    def to_json(self) -> dict[str, object]:
        return {
            "kind": self.kind,
            "index": self.index,
            "char_start": self.char_start,
            "char_end": self.char_end,
            "label": self.label,
        }

    @classmethod
    def from_json(cls, payload: Mapping[str, object]) -> Boundary:
        return cls(
            kind=str(payload["kind"]),
            index=int(cast(int, payload["index"])),
            char_start=int(cast(int, payload["char_start"])),
            char_end=int(cast(int, payload["char_end"])),
            label=str(payload.get("label", "")),
        )


@dataclass(frozen=True, slots=True)
class Chunk:
    """One retrievable span: its ordinal, its digest, and the boundaries it covers."""

    index: int
    sha256: str
    char_start: int
    char_end: int
    characters: int
    boundaries: tuple[str, ...]

    def to_json(self) -> dict[str, object]:
        return {
            "index": self.index,
            "sha256": self.sha256,
            "char_start": self.char_start,
            "char_end": self.char_end,
            "characters": self.characters,
            "boundaries": list(self.boundaries),
        }

    @classmethod
    def from_json(cls, payload: Mapping[str, object]) -> Chunk:
        raw = payload.get("boundaries", [])
        names = tuple(str(name) for name in cast(Sequence[object], raw))
        return cls(
            index=int(cast(int, payload["index"])),
            sha256=str(payload["sha256"]),
            char_start=int(cast(int, payload["char_start"])),
            char_end=int(cast(int, payload["char_end"])),
            characters=int(cast(int, payload["characters"])),
            boundaries=names,
        )


def _recorded_state(payload: Mapping[str, object], requires_ocr: Sequence[int]) -> str:
    """The state a record states, or the one its own numbers imply.

    A record written under schema 1 carries no `state`, and the pair that
    field reports survives in it: pages that require OCR beside a zero
    character count is the document that yielded nothing. Deriving it here
    keeps a stored record self-consistent, which matters because the store
    answers a second upload of the same bytes from the copy it already holds.
    """
    named = payload.get("state")
    if isinstance(named, str) and named:
        return named
    return state_of(requires_ocr, int(cast(int, payload["characters"])))


@dataclass(frozen=True, slots=True)
class DocumentRecord:
    """What one extraction established about one source, written beside its chunks."""

    sha256: str
    filename: str
    media_type: str
    detected_format: str
    extractor: str
    extractor_version: str
    source_bytes: int
    characters: int
    approximate_tokens: int
    approximate_tokens_basis: str
    boundaries: tuple[Boundary, ...]
    chunks: tuple[Chunk, ...]
    warnings: tuple[str, ...] = ()
    requires_ocr: tuple[int, ...] = ()
    state: str = STATE_EXTRACTED
    network_isolation: str = "unrecorded"
    schema: str = RECORD_SCHEMA

    def to_json(self) -> dict[str, object]:
        return {
            "schema": self.schema,
            "sha256": self.sha256,
            "filename": self.filename,
            "media_type": self.media_type,
            "detected_format": self.detected_format,
            "extractor": self.extractor,
            "extractor_version": self.extractor_version,
            "source_bytes": self.source_bytes,
            "characters": self.characters,
            "approximate_tokens": self.approximate_tokens,
            "approximate_tokens_basis": self.approximate_tokens_basis,
            "boundaries": [boundary.to_json() for boundary in self.boundaries],
            "chunks": [chunk.to_json() for chunk in self.chunks],
            "warnings": list(self.warnings),
            "requires_ocr": list(self.requires_ocr),
            "state": self.state,
            "network_isolation": self.network_isolation,
        }

    @classmethod
    def from_json(cls, payload: Mapping[str, object]) -> DocumentRecord:
        boundaries = cast(Sequence[Mapping[str, object]], payload.get("boundaries", []))
        chunks = cast(Sequence[Mapping[str, object]], payload.get("chunks", []))
        warnings = cast(Sequence[object], payload.get("warnings", []))
        ocr = cast(Sequence[object], payload.get("requires_ocr", []))
        pages = tuple(int(cast(int, entry)) for entry in ocr)
        return cls(
            sha256=str(payload["sha256"]),
            filename=str(payload["filename"]),
            media_type=str(payload["media_type"]),
            detected_format=str(payload["detected_format"]),
            extractor=str(payload["extractor"]),
            extractor_version=str(payload["extractor_version"]),
            source_bytes=int(cast(int, payload["source_bytes"])),
            characters=int(cast(int, payload["characters"])),
            approximate_tokens=int(cast(int, payload["approximate_tokens"])),
            approximate_tokens_basis=str(payload["approximate_tokens_basis"]),
            boundaries=tuple(Boundary.from_json(entry) for entry in boundaries),
            chunks=tuple(Chunk.from_json(entry) for entry in chunks),
            warnings=tuple(str(entry) for entry in warnings),
            requires_ocr=pages,
            state=_recorded_state(payload, pages),
            network_isolation=str(payload.get("network_isolation", "unrecorded")),
            schema=str(payload.get("schema", RECORD_SCHEMA)),
        )


@dataclass(frozen=True, slots=True)
class Extraction:
    """One extractor's whole answer, before chunking and digesting."""

    text: str
    boundaries: tuple[Boundary, ...]
    primary_kind: str
    detected_format: str
    warnings: tuple[str, ...] = ()
    requires_ocr: tuple[int, ...] = ()

    def state(self) -> str:
        """`ocr_required` where the text is blank and the pages carry images.

        A mixed document keeps `extracted` and names its unreadable pages in
        `requires_ocr`, because it answers with the text it holds; a document
        that yielded nothing states the reason instead.
        """
        return state_of(self.requires_ocr, len(self.text.strip()))


# --- limits ------------------------------------------------------------------


def apply_limits(limits: Limits) -> None:
    """Cap address space, CPU time, and file size for this process and its children.

    Each cap sets soft and hard together, so a later call in this process
    raises rather than widening what the job runs under. RLIMIT_AS bounds a
    decompression bomb and a runaway parse to a MemoryError, RLIMIT_CPU ends a
    pathological regular expression with SIGXCPU, and RLIMIT_FSIZE ends a
    runaway write with SIGXFSZ; the parent reads the signal from the exit
    status.
    """
    resource.setrlimit(resource.RLIMIT_AS, (limits.address_space_bytes,) * 2)
    resource.setrlimit(resource.RLIMIT_CPU, (limits.cpu_seconds,) * 2)
    resource.setrlimit(resource.RLIMIT_FSIZE, (limits.max_output_bytes,) * 2)


# --- container guards ---------------------------------------------------------


def open_archive(data: bytes, limits: Limits) -> zipfile.ZipFile:
    """Open an OOXML package whose central directory meets the archive caps.

    The member count and the declared uncompressed total refuse here, before
    any member is opened. `read_member` bounds the decompressed read itself,
    because a central directory states a size an archive is free to contradict.
    """
    try:
        archive = zipfile.ZipFile(io.BytesIO(data))
    except zipfile.BadZipFile as error:
        raise ExtractionRefused(f"the file is not a readable package: {error}") from None
    members = archive.infolist()
    if len(members) > limits.max_archive_members:
        raise ExtractionRefused(
            f"the package holds {len(members)} members, past the "
            f"{limits.max_archive_members}-member cap"
        )
    declared = sum(member.file_size for member in members)
    if declared > limits.max_uncompressed_bytes:
        raise ExtractionRefused(
            f"the package declares {declared} uncompressed bytes, past the "
            f"{limits.max_uncompressed_bytes}-byte cap"
        )
    return archive


def read_member(archive: zipfile.ZipFile, name: str, limits: Limits) -> bytes:
    """Return one member's bytes, refusing where the read passes the cap."""
    try:
        with archive.open(name) as handle:
            payload = handle.read(limits.max_uncompressed_bytes + 1)
    except KeyError:
        raise ExtractionRefused(f"the package carries no {name}") from None
    except zipfile.BadZipFile as error:
        raise ExtractionRefused(f"{name} is unreadable: {error}") from None
    if len(payload) > limits.max_uncompressed_bytes:
        raise ExtractionRefused(f"{name} expands past the {limits.max_uncompressed_bytes}-byte cap")
    return payload


def parse_xml(payload: bytes, name: str) -> ElementTree.Element:
    """Parse one OOXML part, refusing a document type declaration.

    `xml.etree` expands a declared internal entity, so the nested-entity
    expansion attack needs a `<!DOCTYPE` to declare one. An OOXML part carries
    none, so refusing the declaration removes the attack rather than bounding
    it, and the address-space cap bounds whatever the parser still allocates.
    """
    if DOCTYPE_PATTERN.search(payload[:4096]):
        raise ExtractionRefused(f"{name} declares a document type, which an OOXML part does not")
    try:
        return ElementTree.fromstring(payload)  # noqa: S314
    except ElementTree.ParseError as error:
        raise ExtractionRefused(f"{name} is not well-formed XML: {error}") from None


def qualified(namespace: str, tag: str) -> str:
    return f"{{{namespace}}}{tag}"


# --- extractors ---------------------------------------------------------------


def decode_text(data: bytes, warnings: list[str]) -> str:
    """Decode as UTF-8, recording the replacement where a byte is not UTF-8."""
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        warnings.append("the source carries bytes that are not UTF-8; they decode as U+FFFD")
        return data.decode("utf-8", errors="replace")


def line_boundaries(text: str, kind: str) -> tuple[Boundary, ...]:
    """One boundary per line, tiling the text including each line terminator."""
    boundaries: list[Boundary] = []
    position = 0
    index = 1
    for line in text.splitlines(keepends=True):
        boundaries.append(Boundary(kind, index, position, position + len(line)))
        position += len(line)
        index += 1
    return tuple(boundaries)


def extract_text(data: bytes, filename: str) -> Extraction:
    """Plain text: the bytes decode and every line is a boundary."""
    warnings: list[str] = []
    text = decode_text(data, warnings)
    return Extraction(
        text=text,
        boundaries=line_boundaries(text, "line"),
        primary_kind="line",
        detected_format="text",
        warnings=tuple(warnings),
    )


def extract_source(data: bytes, filename: str) -> Extraction:
    """Source code: the text passes through and the extension names the language."""
    warnings: list[str] = []
    text = decode_text(data, warnings)
    language = SOURCE_LANGUAGES.get(Path(filename).suffix.lower(), "source")
    return Extraction(
        text=text,
        boundaries=line_boundaries(text, "line"),
        primary_kind="line",
        detected_format=f"source:{language}",
        warnings=tuple(warnings),
    )


def extract_markdown(data: bytes, filename: str) -> Extraction:
    """Markdown: an ATX heading opens a section and the sections tile the text."""
    warnings: list[str] = []
    text = decode_text(data, warnings)
    boundaries: list[Boundary] = []
    starts: list[tuple[int, str]] = []
    position = 0
    for line in text.splitlines(keepends=True):
        stripped = line.lstrip()
        if stripped.startswith("#"):
            starts.append((position, line.strip()))
        position += len(line)
    if not starts or starts[0][0] > 0:
        starts.insert(0, (0, ""))
    for index, (start, label) in enumerate(starts, start=1):
        end = starts[index][0] if index < len(starts) else len(text)
        boundaries.append(Boundary("heading", index, start, end, label))
    return Extraction(
        text=text,
        boundaries=tuple(boundaries),
        primary_kind="heading",
        detected_format="markdown",
        warnings=tuple(warnings),
    )


def extract_json(data: bytes, filename: str) -> Extraction:
    """JSON: the document normalizes to sorted keys and two-space indentation.

    Normalizing before chunking makes one document's chunk digests a function
    of its values rather than of its author's whitespace, so two spellings of
    one object answer with the same chunk identities.
    """
    warnings: list[str] = []
    text = decode_text(data, warnings)
    try:
        parsed: object = json.loads(text)
    except ValueError as error:
        raise ExtractionRefused(f"the document is not valid JSON: {error}") from None
    normalized = json.dumps(parsed, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    return Extraction(
        text=normalized,
        boundaries=line_boundaries(normalized, "line"),
        primary_kind="line",
        detected_format="json",
        warnings=tuple(warnings),
    )


def extract_delimited(data: bytes, filename: str, delimiter: str, name: str) -> Extraction:
    """CSV and TSV: the csv module reads the rows and each row is a boundary.

    The sheet boundary carries index 1 because a delimited file holds one
    sheet, which is what makes a spreadsheet and a CSV answer one query shape.
    """
    warnings: list[str] = []
    text = decode_text(data, warnings)
    rows = list(csv.reader(io.StringIO(text, newline=""), delimiter=delimiter))
    rendered: list[str] = []
    boundaries: list[Boundary] = []
    position = 0
    for index, row in enumerate(rows, start=1):
        line = "\t".join(field.replace("\t", " ") for field in row) + "\n"
        rendered.append(line)
        boundaries.append(Boundary("row", index, position, position + len(line)))
        position += len(line)
    body = "".join(rendered)
    sheet = Boundary("sheet", 1, 0, len(body), Path(filename).stem)
    return Extraction(
        text=body,
        boundaries=(sheet, *boundaries),
        primary_kind="row",
        detected_format=name,
        warnings=tuple(warnings),
    )


class _HtmlText(HTMLParser):
    """Collect an HTML document's text and the position every heading opens at."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.length = 0
        self.headings: list[tuple[int, str]] = []
        self.skipping = 0
        self.in_heading = False
        self.heading_start = 0
        self.heading_text: list[str] = []

    def _append(self, text: str) -> None:
        self.parts.append(text)
        self.length += len(text)

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in HTML_SKIPPED_TAGS:
            self.skipping += 1
            return
        if tag in HTML_HEADING_TAGS:
            if self.length and not "".join(self.parts).endswith("\n"):
                self._append("\n")
            self.in_heading = True
            self.heading_start = self.length
            self.heading_text = []
            return
        if tag in HTML_BLOCK_TAGS and self.length and not "".join(self.parts).endswith("\n"):
            self._append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in HTML_SKIPPED_TAGS:
            self.skipping = max(0, self.skipping - 1)
            return
        if tag in HTML_HEADING_TAGS and self.in_heading:
            self.headings.append((self.heading_start, "".join(self.heading_text).strip()))
            self.in_heading = False
            self._append("\n")
            return
        if tag in HTML_BLOCK_TAGS:
            self._append("\n")

    def handle_data(self, data: str) -> None:
        if self.skipping:
            return
        text = re.sub(r"[ \t\r\f\v]+", " ", data)
        if not text.strip():
            if text and self.parts and not "".join(self.parts).endswith((" ", "\n")):
                self._append(" ")
            return
        self._append(text.strip() if text.strip() == text else text)
        if self.in_heading:
            self.heading_text.append(text)


def extract_html(data: bytes, filename: str) -> Extraction:
    """HTML: `html.parser` yields the text and each heading opens a section."""
    warnings: list[str] = []
    source = decode_text(data, warnings)
    parser = _HtmlText()
    parser.feed(source)
    parser.close()
    text = re.sub(r"\n{3,}", "\n\n", "".join(parser.parts))
    starts = [(0, "")] if not parser.headings or parser.headings[0][0] > 0 else []
    starts.extend(parser.headings)
    # The collapse above shortens the text, so each recorded heading start is
    # located again in the collapsed text by its own label rather than trusted.
    located: list[tuple[int, str]] = []
    cursor = 0
    for _, label in starts:
        if not label:
            located.append((0, ""))
            continue
        found = text.find(label, cursor)
        if found < 0:
            warnings.append(f"the heading {label!r} vanished under whitespace collapse")
            continue
        located.append((found, label))
        cursor = found + len(label)
    boundaries = [
        Boundary(
            "heading",
            index,
            start,
            located[index][0] if index < len(located) else len(text),
            label,
        )
        for index, (start, label) in enumerate(located, start=1)
    ]
    return Extraction(
        text=text,
        boundaries=tuple(boundaries),
        primary_kind="heading",
        detected_format="html",
        warnings=tuple(warnings),
    )


def _docx_paragraph_text(paragraph: ElementTree.Element) -> str:
    pieces: list[str] = []
    for node in paragraph.iter():
        if node.tag == qualified(WORD_NAMESPACE, "t"):
            pieces.append(node.text or "")
        elif node.tag == qualified(WORD_NAMESPACE, "tab"):
            pieces.append("\t")
        elif node.tag == qualified(WORD_NAMESPACE, "br"):
            if node.get(qualified(WORD_NAMESPACE, "type")) != "page":
                pieces.append("\n")
    return "".join(pieces)


def _docx_heading_text(paragraph: ElementTree.Element, text: str) -> str:
    """The paragraph's own text where its style names a heading, or an empty string."""
    properties = paragraph.find(qualified(WORD_NAMESPACE, "pPr"))
    if properties is None:
        return ""
    style = properties.find(qualified(WORD_NAMESPACE, "pStyle"))
    if style is None:
        return ""
    named = style.get(qualified(WORD_NAMESPACE, "val"), "")
    return text if HEADING_STYLE_PATTERN.match(named) else ""


def _sections(starts: Sequence[tuple[int, str]], length: int) -> list[Boundary]:
    """Heading boundaries spanning each start to the next, tiling the whole text.

    A document whose text opens before its first heading takes an unlabeled
    section at zero, the shape `extract_markdown` and `extract_html` both
    record, so one covering rule answers a heading query across three formats.
    """
    opened = list(starts)
    if not opened:
        return []
    if opened[0][0] > 0:
        opened.insert(0, (0, ""))
    return [
        Boundary(
            "heading",
            index,
            start,
            opened[index][0] if index < len(opened) else length,
            label,
        )
        for index, (start, label) in enumerate(opened, start=1)
    ]


def _docx_breaks_page(paragraph: ElementTree.Element) -> bool:
    for node in paragraph.iter():
        if node.tag == qualified(WORD_NAMESPACE, "lastRenderedPageBreak"):
            return True
        if (
            node.tag == qualified(WORD_NAMESPACE, "br")
            and node.get(qualified(WORD_NAMESPACE, "type")) == "page"
        ):
            return True
    return False


def extract_docx(data: bytes, filename: str, limits: Limits) -> Extraction:
    """DOCX: `word/document.xml` yields paragraphs, and a page break opens a page.

    A page break element sits inside a paragraph, so the page boundary opens at
    that paragraph's own start. A break sharing its paragraph with text puts
    the boundary one paragraph early, which the extraction records as a warning
    rather than silently relocating.

    A paragraph whose style names a heading opens a heading section that runs
    to the next one, so a hit reports the heading it sits under beside the
    paragraph that holds it. Chunking stays on the paragraphs, which is what
    keeps a chunk edge at a paragraph rather than at a section.
    """
    warnings: list[str] = []
    archive = open_archive(data, limits)
    body = parse_xml(read_member(archive, "word/document.xml", limits), "word/document.xml").find(
        qualified(WORD_NAMESPACE, "body")
    )
    if body is None:
        raise ExtractionRefused("word/document.xml carries no body")
    paragraphs: list[Boundary] = []
    pages: list[Boundary] = []
    headings: list[tuple[int, str]] = []
    pieces: list[str] = []
    position = 0
    page_start = 0
    page_index = 1
    paragraph_index = 1
    for paragraph in body.iter(qualified(WORD_NAMESPACE, "p")):
        text = _docx_paragraph_text(paragraph)
        if _docx_breaks_page(paragraph):
            if text:
                warnings.append(
                    f"paragraph {paragraph_index} carries a page break beside text; "
                    "the page boundary opens at the paragraph"
                )
            pages.append(Boundary("page", page_index, page_start, position))
            page_start = position
            page_index += 1
        if not text:
            continue
        heading = _docx_heading_text(paragraph, text)
        if heading:
            headings.append((position, heading))
        line = text + "\n"
        pieces.append(line)
        paragraphs.append(Boundary("paragraph", paragraph_index, position, position + len(line)))
        position += len(line)
        paragraph_index += 1
    whole = "".join(pieces)
    pages.append(Boundary("page", page_index, page_start, len(whole)))
    return Extraction(
        text=whole,
        boundaries=(*pages, *_sections(headings, len(whole)), *paragraphs),
        primary_kind="paragraph",
        detected_format="docx",
        warnings=tuple(warnings),
    )


def _shared_strings(archive: zipfile.ZipFile, limits: Limits) -> list[str]:
    if "xl/sharedStrings.xml" not in archive.namelist():
        return []
    root = parse_xml(read_member(archive, "xl/sharedStrings.xml", limits), "xl/sharedStrings.xml")
    strings: list[str] = []
    for entry in root.findall(qualified(SPREADSHEET_NAMESPACE, "si")):
        strings.append(
            "".join(node.text or "" for node in entry.iter(qualified(SPREADSHEET_NAMESPACE, "t")))
        )
    return strings


def _sheet_targets(archive: zipfile.ZipFile, limits: Limits) -> list[tuple[str, str]]:
    """Every sheet's name and part path, read through the workbook relationships."""
    workbook = parse_xml(read_member(archive, "xl/workbook.xml", limits), "xl/workbook.xml")
    relationships_name = "xl/_rels/workbook.xml.rels"
    targets: dict[str, str] = {}
    if relationships_name in archive.namelist():
        rels = parse_xml(read_member(archive, relationships_name, limits), relationships_name)
        for node in rels.findall(qualified(PACKAGE_RELATIONSHIP_NAMESPACE, "Relationship")):
            identifier = node.get("Id")
            target = node.get("Target")
            if identifier and target:
                targets[identifier] = target
    sheets: list[tuple[str, str]] = []
    container = workbook.find(qualified(SPREADSHEET_NAMESPACE, "sheets"))
    if container is None:
        raise ExtractionRefused("xl/workbook.xml names no sheets")
    for ordinal, node in enumerate(
        container.findall(qualified(SPREADSHEET_NAMESPACE, "sheet")), start=1
    ):
        name = node.get("name", f"sheet{ordinal}")
        identifier = node.get(qualified(OFFICE_RELATIONSHIP_NAMESPACE, "id"), "")
        target = targets.get(identifier, f"worksheets/sheet{ordinal}.xml")
        path = target[1:] if target.startswith("/") else f"xl/{target}"
        sheets.append((name, path))
    return sheets


def _cell_text(cell: ElementTree.Element, strings: Sequence[str], warnings: list[str]) -> str:
    kind = cell.get("t", "n")
    if kind == "s":
        value = cell.find(qualified(SPREADSHEET_NAMESPACE, "v"))
        if value is None or value.text is None:
            return ""
        index = int(value.text)
        if index >= len(strings):
            reference = cell.get("r", "?")
            warnings.append(f"cell {reference} names shared string {index}, which is absent")
            return ""
        return strings[index]
    if kind == "inlineStr":
        inline = cell.find(qualified(SPREADSHEET_NAMESPACE, "is"))
        if inline is None:
            return ""
        return "".join(
            node.text or "" for node in inline.iter(qualified(SPREADSHEET_NAMESPACE, "t"))
        )
    value = cell.find(qualified(SPREADSHEET_NAMESPACE, "v"))
    return value.text or "" if value is not None else ""


def _row_range(sheet: str, row: ElementTree.Element) -> str:
    """The row's label: `Sheet!A1:B1` from the cells' own references.

    The cells carry the references, so a sparse row reports the range it
    actually holds; a row whose cells name none falls back to the sheet and
    the row number the `r` attribute states.
    """
    references = [
        reference
        for reference in (
            cell.get("r", "") for cell in row.findall(qualified(SPREADSHEET_NAMESPACE, "c"))
        )
        if reference
    ]
    if references:
        return f"{sheet}!{references[0]}:{references[-1]}"
    return f"{sheet}!{row.get('r', '')}"


def extract_xlsx(data: bytes, filename: str, limits: Limits) -> Extraction:
    """XLSX: every sheet the workbook names, rendered as tab-separated rows.

    A sheet boundary carries its name and a row boundary carries the cell
    range it spans, so a hit inside a spreadsheet cites `Alpha!A2:B2` rather
    than a character offset into a tab-separated rendering.
    """
    warnings: list[str] = []
    archive = open_archive(data, limits)
    strings = _shared_strings(archive, limits)
    pieces: list[str] = []
    sheets: list[Boundary] = []
    rows: list[Boundary] = []
    position = 0
    row_index = 1
    for sheet_index, (name, path) in enumerate(_sheet_targets(archive, limits), start=1):
        start = position
        if path not in archive.namelist():
            warnings.append(f"the workbook names {path}, which the package does not carry")
            sheets.append(Boundary("sheet", sheet_index, start, position, name))
            continue
        root = parse_xml(read_member(archive, path, limits), path)
        for row in root.iter(qualified(SPREADSHEET_NAMESPACE, "row")):
            found = row.findall(qualified(SPREADSHEET_NAMESPACE, "c"))
            cells = [_cell_text(cell, strings, warnings) for cell in found]
            line = "\t".join(cells) + "\n"
            pieces.append(line)
            rows.append(
                Boundary("row", row_index, position, position + len(line), _row_range(name, row))
            )
            position += len(line)
            row_index += 1
        sheets.append(Boundary("sheet", sheet_index, start, position, name))
    return Extraction(
        text="".join(pieces),
        boundaries=(*sheets, *rows),
        primary_kind="sheet",
        detected_format="xlsx",
        warnings=tuple(warnings),
    )


def extract_pptx(data: bytes, filename: str, limits: Limits) -> Extraction:
    """PPTX: every `ppt/slides/slideN.xml`, in the numeric order of its name."""
    warnings: list[str] = []
    archive = open_archive(data, limits)
    names: list[tuple[int, str]] = []
    for name in archive.namelist():
        found = SLIDE_NAME_PATTERN.match(name)
        if found:
            names.append((int(found.group(1)), name))
    if not names:
        raise ExtractionRefused("the package carries no slide under ppt/slides/")
    pieces: list[str] = []
    slides: list[Boundary] = []
    position = 0
    for index, (_, name) in enumerate(sorted(names), start=1):
        root = parse_xml(read_member(archive, name, limits), name)
        lines: list[str] = []
        for paragraph in root.iter(qualified(DRAWING_NAMESPACE, "p")):
            text = "".join(
                node.text or "" for node in paragraph.iter(qualified(DRAWING_NAMESPACE, "t"))
            )
            if text:
                lines.append(text + "\n")
        body = "".join(lines)
        pieces.append(body)
        label = lines[0].strip() if lines else ""
        slides.append(Boundary("slide", index, position, position + len(body), label))
        position += len(body)
    return Extraction(
        text="".join(pieces),
        boundaries=tuple(slides),
        primary_kind="slide",
        detected_format="pptx",
        warnings=tuple(warnings),
    )


def _page_carries_image(page: object) -> bool:
    """Whether a PDF page's resources name an image XObject.

    The pair of an empty extraction and a present image is what separates a
    scanned page from an empty one, so the resource dictionary is read rather
    than the page's rendered content.
    """
    getter = getattr(page, "get", None)
    if getter is None:
        return False
    resources = getter("/Resources")
    resolve = getattr(resources, "get_object", None)
    if resolve is not None:
        resources = resolve()
    if not isinstance(resources, Mapping):
        return False
    xobjects = resources.get("/XObject")
    resolve = getattr(xobjects, "get_object", None)
    if resolve is not None:
        xobjects = resolve()
    if not isinstance(xobjects, Mapping):
        return False
    for value in cast(Mapping[str, Any], xobjects).values():
        resolve = getattr(value, "get_object", None)
        entry = resolve() if resolve is not None else value
        if isinstance(entry, Mapping) and entry.get("/Subtype") == "/Image":
            return True
    return False


def extract_pdf(data: bytes, filename: str) -> Extraction:
    """PDF: `pypdf` yields each page's text and every page is a boundary.

    A page whose extraction is empty while its resources name an image XObject
    reaches `requires_ocr`; the other pages keep their text, so a mixed
    document answers with what it holds beside the pages it cannot read.

    The import resolves inside the call, so every other format extracts on an
    interpreter that carries no pypdf and a PDF job refuses by name there.
    """
    try:
        pypdf = importlib.import_module("pypdf")
    except ImportError:
        raise ExtractionRefused(
            "pypdf is absent; wheelhouse/requirements.lock pins the wheel the PDF extractor reads"
        ) from None
    warnings: list[str] = []
    try:
        reader = pypdf.PdfReader(io.BytesIO(data))
    except Exception as error:  # pypdf raises its own hierarchy plus ValueError
        raise ExtractionRefused(f"the PDF is unreadable: {error}") from None
    if reader.is_encrypted:
        raise ExtractionRefused("the PDF is encrypted; the extractor decrypts nothing")
    pieces: list[str] = []
    pages: list[Boundary] = []
    scanned: list[int] = []
    position = 0
    for index, page in enumerate(reader.pages, start=1):
        try:
            text = page.extract_text() or ""
        except Exception as error:  # one page's failure leaves the others readable
            warnings.append(f"page {index} failed extraction: {error}")
            text = ""
        if not text.strip() and _page_carries_image(page):
            scanned.append(index)
        body = text if text.endswith("\n") or not text else text + "\n"
        pieces.append(body)
        pages.append(Boundary("page", index, position, position + len(body)))
        position += len(body)
    if scanned:
        warnings.append(
            f"pages {', '.join(str(number) for number in scanned)} carry an image and no text; "
            "they require OCR"
        )
    return Extraction(
        text="".join(pieces),
        boundaries=tuple(pages),
        primary_kind="page",
        detected_format="pdf",
        warnings=tuple(warnings),
        requires_ocr=tuple(scanned),
    )


# --- dispatch -----------------------------------------------------------------


def resolve_format(filename: str, media_type: str) -> str:
    """Name the format one job extracts, from the extension first.

    A source extension answers `source`, a known document extension answers its
    own format, and the media type answers where the extension names neither.
    """
    suffix = Path(filename).suffix.lower()
    if suffix in SOURCE_LANGUAGES:
        return "source"
    if suffix in FORMAT_EXTENSIONS:
        return FORMAT_EXTENSIONS[suffix]
    normalized = media_type.split(";", maxsplit=1)[0].strip().lower()
    if normalized in FORMAT_MEDIA_TYPES:
        return FORMAT_MEDIA_TYPES[normalized]
    raise ExtractionRefused(
        f"no extractor claims {filename!r} at media type {media_type!r}; "
        f"the extensions this worker extracts are "
        f"{', '.join(sorted(set(FORMAT_EXTENSIONS) | set(SOURCE_LANGUAGES)))}"
    )


def extract(data: bytes, filename: str, media_type: str, limits: Limits) -> Extraction:
    """Run the extractor the format resolves to."""
    resolved = resolve_format(filename, media_type)
    simple: Mapping[str, Callable[[bytes, str], Extraction]] = {
        "text": extract_text,
        "source": extract_source,
        "markdown": extract_markdown,
        "json": extract_json,
        "html": extract_html,
        "pdf": extract_pdf,
    }
    if resolved in simple:
        return simple[resolved](data, filename)
    if resolved == "csv":
        return extract_delimited(data, filename, ",", "csv")
    if resolved == "tsv":
        return extract_delimited(data, filename, "\t", "tsv")
    if resolved == "docx":
        return extract_docx(data, filename, limits)
    if resolved == "xlsx":
        return extract_xlsx(data, filename, limits)
    if resolved == "pptx":
        return extract_pptx(data, filename, limits)
    raise ExtractionRefused(f"the format {resolved} has no extractor")


# --- chunking -----------------------------------------------------------------


def chunk_spans(extraction: Extraction, max_chars: int = CHUNK_MAX_CHARS) -> list[tuple[int, int]]:
    """Fill chunks to `max_chars`, ending on a primary boundary wherever one lands.

    The primary boundaries tile the text, so accumulating them until the next
    one would pass the cap puts every chunk edge on a page, a paragraph, a
    slide, or a row. A single boundary longer than the cap splits at the last
    line break inside the budget, and at the cap itself where the span carries
    none.
    """
    segments = [
        (boundary.char_start, boundary.char_end)
        for boundary in extraction.boundaries
        if boundary.kind == extraction.primary_kind
    ]
    if not segments:
        segments = [(0, len(extraction.text))]
    spans: list[tuple[int, int]] = []
    start: int | None = None
    end = 0
    for segment_start, segment_end in segments:
        if start is None:
            start = segment_start
            end = segment_start
        while segment_end - end > max_chars:
            cut = extraction.text.rfind("\n", end, end + max_chars)
            boundary_cut = cut + 1 if cut > end else end + max_chars
            if end > start:
                spans.append((start, end))
                start = end
                continue
            spans.append((start, boundary_cut))
            start = boundary_cut
            end = boundary_cut
        if segment_end - start > max_chars:
            spans.append((start, end))
            start = segment_start
        end = segment_end
    if start is not None and end > start:
        spans.append((start, end))
    return [span for span in spans if span[1] > span[0]]


def build_chunks(extraction: Extraction, max_chars: int = CHUNK_MAX_CHARS) -> list[Chunk]:
    """Digest every chunk and name the boundaries it covers."""
    chunks: list[Chunk] = []
    for index, (start, end) in enumerate(chunk_spans(extraction, max_chars), start=1):
        body = extraction.text[start:end]
        covered = tuple(
            f"{boundary.kind}:{boundary.index}"
            for boundary in extraction.boundaries
            if boundary.char_start < end and boundary.char_end > start
        )
        chunks.append(
            Chunk(
                index=index,
                sha256=hashlib.sha256(body.encode("utf-8")).hexdigest(),
                char_start=start,
                char_end=end,
                characters=len(body),
                boundaries=covered,
            )
        )
    return chunks


def approximate_tokens(characters: int) -> int:
    """The chars/4 estimate, rounded up so one character reports one token."""
    return -(-characters // TOKEN_ESTIMATE_CHARS)


# --- search -------------------------------------------------------------------


def compile_query(query: str, *, regex: bool, bounds: SearchBounds) -> re.Pattern[str]:
    """Compile one query and bound what the compiled pattern carries.

    A literal query escapes into the same engine, so one matcher answers both
    forms and a literal never carries a metacharacter of its own. CPython
    publishes no size for the compiled program, so the bound reads the two
    measures the compiled pattern does publish -- the source it holds and the
    groups it captures -- which are what a nested quantifier grows. The source
    length is read ahead of the compile, since `re.compile` leaves a pattern's
    own source unchanged and compiling a refused pattern spends the process
    that is about to refuse it.
    """
    if not query:
        raise ExtractionRefused("the query is empty")
    if regex and len(query) > bounds.max_pattern_chars:
        raise SearchBounded(
            f"the pattern is {len(query)} characters, past the "
            f"{bounds.max_pattern_chars}-character bound"
        )
    try:
        pattern = re.compile(query if regex else re.escape(query))
    except re.error as error:
        raise ExtractionRefused(f"the query is not a valid regular expression: {error}") from None
    if regex:
        if pattern.groups > bounds.max_pattern_groups:
            raise SearchBounded(
                f"the pattern captures {pattern.groups} groups, past the "
                f"{bounds.max_pattern_groups}-group bound"
            )
    return pattern


def arm_wall_clock(seconds: float) -> None:
    """Bound this process's wall clock with a signal the kernel delivers itself.

    `_sre` holds the interpreter through one match and reaches no bytecode
    boundary, so a handler installed through `signal.signal` runs after the
    match returns -- which is what a catastrophically backtracking pattern
    never does. SIGALRM at its default disposition terminates the process
    instead, so the bound holds inside the match and the parent reads the
    signal from the exit status.
    """
    signal.signal(signal.SIGALRM, signal.SIG_DFL)
    signal.setitimer(signal.ITIMER_REAL, seconds)


def disarm_wall_clock() -> None:
    """Drop the timer before the answer is written, so the report outlives the bound."""
    signal.setitimer(signal.ITIMER_REAL, 0.0)


def search_chunks(
    directory: Path,
    digest: str,
    pattern: re.Pattern[str],
    bounds: SearchBounds,
    max_hits: int,
) -> list[dict[str, int]]:
    """Every match over one stored document's chunks, in chunk order.

    The chunk count refuses ahead of the first match, and the clock is read
    between chunks, so a pattern that is merely slow ends with a refusal
    object naming the bound; one that never returns from a single chunk ends
    on the timer `arm_wall_clock` set.
    """
    record = read_record(directory, digest)
    if len(record.chunks) > bounds.max_candidate_chunks:
        raise SearchBounded(
            f"the document holds {len(record.chunks)} chunks, past the "
            f"{bounds.max_candidate_chunks}-chunk bound"
        )
    deadline = time.monotonic() + bounds.wall_clock_seconds
    matches: list[dict[str, int]] = []
    for chunk in record.chunks:
        if time.monotonic() >= deadline:
            raise SearchBounded(f"the search passed its {bounds.wall_clock_seconds:g}-second bound")
        body = (directory / "chunks" / f"{chunk.index}.txt").read_text(encoding="utf-8")
        for found in pattern.finditer(body):
            if found.end() <= found.start():
                continue
            matches.append(
                {
                    "chunk_index": chunk.index,
                    "char_start": found.start(),
                    "char_end": found.end(),
                }
            )
            if len(matches) >= max_hits:
                return matches
    return matches


@dataclass(frozen=True, slots=True)
class SearchJob:
    """One search as the caller states it on stdin."""

    directory: Path
    digest: str
    query: str
    regex: bool = False
    bounds: SearchBounds = field(default_factory=SearchBounds)
    limits: Limits = field(default_factory=Limits)
    max_hits: int = DEFAULT_MAX_SEARCH_HITS

    @classmethod
    def from_json(cls, payload: Mapping[str, object]) -> SearchJob:
        directory = payload.get("document_directory")
        digest = payload.get("digest")
        query = payload.get("query")
        if not isinstance(directory, str) or not directory:
            raise ExtractionRefused("document_directory is absent or is not a nonempty string")
        if not isinstance(digest, str) or not digest:
            raise ExtractionRefused("digest is absent or is not a nonempty string")
        if not isinstance(query, str) or not query:
            raise ExtractionRefused("query is absent or is not a nonempty string")
        regex = payload.get("regex", False)
        if not isinstance(regex, bool):
            raise ExtractionRefused("regex is not a boolean")
        raw_bounds = payload.get("bounds", {})
        raw_limits = payload.get("limits", {})
        if not isinstance(raw_bounds, dict) or not isinstance(raw_limits, dict):
            raise ExtractionRefused("bounds and limits are JSON objects")
        return cls(
            directory=Path(directory),
            digest=digest,
            query=query,
            regex=regex,
            bounds=SearchBounds.from_json(cast(Mapping[str, object], raw_bounds)),
            limits=Limits.from_json(cast(Mapping[str, object], raw_limits)),
            max_hits=_positive_int(payload, "max_hits", DEFAULT_MAX_SEARCH_HITS),
        )


def run_search(job: SearchJob) -> int:
    """Run one search under every bound and print the matches it found."""
    apply_limits(job.limits)
    pattern = compile_query(job.query, regex=job.regex, bounds=job.bounds)
    arm_wall_clock(job.bounds.wall_clock_seconds)
    matches = search_chunks(job.directory, job.digest, pattern, job.bounds, job.max_hits)
    disarm_wall_clock()
    print(json.dumps({"status": "searched", "matches": matches}))
    return 0


# --- the job ------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Job:
    """One job as the caller states it on stdin."""

    input_path: Path
    filename: str
    media_type: str
    output_directory: Path
    limits: Limits = field(default_factory=Limits)
    network_isolation: str = "unrecorded"

    @classmethod
    def from_json(cls, payload: Mapping[str, object]) -> Job:
        def text(key: str, required: bool = True) -> str:
            value = payload.get(key)
            if value is None or value == "":
                if required:
                    raise ExtractionRefused(f"{key} is absent or is not a nonempty string")
                return ""
            if not isinstance(value, str):
                raise ExtractionRefused(f"{key} is not a string")
            return value

        raw_limits = payload.get("limits", {})
        if not isinstance(raw_limits, dict):
            raise ExtractionRefused("limits is not a JSON object")
        input_path = Path(text("input_path"))
        return cls(
            input_path=input_path,
            filename=text("filename", required=False) or input_path.name,
            media_type=text("media_type", required=False),
            output_directory=Path(text("output_directory")),
            limits=Limits.from_json(cast(Mapping[str, object], raw_limits)),
            network_isolation=text("network_isolation", required=False) or "unrecorded",
        )


def read_source(job: Job) -> bytes:
    """Read the input, refusing a size past the cap before the read happens."""
    try:
        size = job.input_path.stat().st_size
    except OSError as error:
        raise ExtractionRefused(f"the input is unreadable: {error}") from None
    if size > job.limits.max_input_bytes:
        raise ExtractionRefused(
            f"the input is {size} bytes, past the {job.limits.max_input_bytes}-byte cap"
        )
    try:
        return job.input_path.read_bytes()
    except OSError as error:
        raise ExtractionRefused(f"the input is unreadable: {error}") from None


def run(job: Job) -> DocumentRecord:
    """Extract one source and write its record and chunks under the output directory."""
    data = read_source(job)
    digest = hashlib.sha256(data).hexdigest()
    extraction = extract(data, job.filename, job.media_type, job.limits)
    chunks = build_chunks(extraction)
    record = DocumentRecord(
        sha256=digest,
        filename=job.filename,
        media_type=job.media_type,
        detected_format=extraction.detected_format,
        extractor=WORKER_NAME,
        extractor_version=WORKER_VERSION,
        source_bytes=len(data),
        characters=len(extraction.text),
        approximate_tokens=approximate_tokens(len(extraction.text)),
        approximate_tokens_basis=ESTIMATE_BASIS,
        boundaries=extraction.boundaries,
        chunks=tuple(chunks),
        warnings=extraction.warnings,
        requires_ocr=extraction.requires_ocr,
        state=extraction.state(),
        network_isolation=job.network_isolation,
    )
    write_outputs(job.output_directory, record, extraction.text)
    return record


def write_outputs(directory: Path, record: DocumentRecord, text: str) -> None:
    """Write `<sha256>.json` and one file per chunk under `chunks/`."""
    directory.mkdir(parents=True, exist_ok=True)
    chunk_directory = directory / "chunks"
    chunk_directory.mkdir(exist_ok=True)
    for chunk in record.chunks:
        body = text[chunk.char_start : chunk.char_end]
        (chunk_directory / f"{chunk.index}.txt").write_text(body, encoding="utf-8")
    (directory / f"{record.sha256}.json").write_text(
        json.dumps(record.to_json(), indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def read_record(directory: Path, digest: str) -> DocumentRecord:
    """Read one record back from the directory the worker wrote it into."""
    payload: object = json.loads((directory / f"{digest}.json").read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ExtractionRefused(f"{digest}.json carries no record object")
    return DocumentRecord.from_json(cast(Mapping[str, object], payload))


def read_chunks(directory: Path, record: DocumentRecord) -> Iterator[tuple[Chunk, str]]:
    """Every chunk's identity beside the text the worker wrote for it."""
    for chunk in record.chunks:
        yield chunk, (directory / "chunks" / f"{chunk.index}.txt").read_text(encoding="utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    """Read one job on stdin, run its mode, and report the answer or the refusal."""
    arguments = list(sys.argv[1:] if argv is None else argv)
    if arguments:
        print(
            f"usage: {os.path.basename(sys.argv[0])} < job.json\n"
            "An extract job names input_path, filename, media_type, output_directory, "
            "and limits; a search job names mode, document_directory, digest, query, "
            "regex, and bounds.",
            file=sys.stderr,
        )
        return 2
    try:
        payload: object = json.loads(sys.stdin.read())
        if not isinstance(payload, dict):
            raise ExtractionRefused("the job is not a JSON object")
        body = cast(Mapping[str, object], payload)
        mode = body.get("mode", MODE_EXTRACT)
        if mode == MODE_SEARCH:
            return run_search(SearchJob.from_json(body))
        if mode != MODE_EXTRACT:
            raise ExtractionRefused(f"{mode!r} names no mode this worker runs")
        job = Job.from_json(body)
        apply_limits(job.limits)
        record = run(job)
    except SearchBounded as bounded:
        print(
            json.dumps({"status": "refused", "refusal": SEARCH_BOUNDED, "error": bounded.message})
        )
        return 1
    except ExtractionRefused as refusal:
        print(json.dumps({"status": "refused", "error": refusal.message}))
        return 1
    except (OSError, ValueError, MemoryError) as error:
        print(json.dumps({"status": "failed", "error": f"{type(error).__name__}: {error}"}))
        return 1
    print(
        json.dumps(
            {
                "status": "extracted",
                "sha256": record.sha256,
                "record": f"{record.sha256}.json",
                "chunks": len(record.chunks),
                "requires_ocr": list(record.requires_ocr),
                "state": record.state,
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
