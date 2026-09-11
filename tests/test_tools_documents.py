"""The document worker's extractors and limits, and the service's ownership rules.

The extractors run in this process because they read bytes and return values.
The limits, the deadline, and the store run through the worker as a real
child, because what they establish is the child's own fate: a signal, a killed
process group, a refusal on stdout.

`pypdf` resolves from an installed distribution, or from the wheel
`wheelhouse/requirements.lock` pins -- a pure-Python wheel imports from
`sys.path` through zipimport, so the PDF proofs run against the pinned bytes
on an interpreter that installs nothing.
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import subprocess
import sys
import threading
import time
import zipfile
from collections.abc import Callable, Iterator
from http.client import HTTPConnection
from pathlib import Path

import pytest

from qwen_apu.tools.document_worker import (
    ESTIMATE_BASIS,
    Extraction,
    ExtractionRefused,
    Limits,
    SearchBounds,
    approximate_tokens,
    build_chunks,
    extract,
    extract_delimited,
    extract_docx,
    extract_html,
    extract_json,
    extract_markdown,
    extract_pptx,
    extract_source,
    extract_text,
    extract_xlsx,
    open_archive,
    read_member,
    resolve_format,
)
from qwen_apu.tools.documents import (
    DEFAULT_MAX_REQUEST_BYTES,
    DIGEST_PATTERN,
    DOCUMENT_ROUTE,
    DOCUMENT_SEARCH_ROUTE,
    DOCUMENTS_ROUTE,
    NETWORK_ISOLATION_NAMESPACED,
    UPLOAD_BLOCK_BYTES,
    DocumentRefused,
    DocumentService,
    DocumentSettings,
    _publish,
    handle_record,
    handle_search,
    handle_upload,
    parse_upload,
    probe_network_isolation,
    routes,
    safe_filename,
    stage_body,
)
from qwen_apu.web.app import REQUEST_BODY_BYTE_CAP, Gateway, GatewayConfig
from qwen_apu.web.http import Request, Response, match

REPOSITORY = Path(__file__).resolve().parents[1]
FIXTURES = Path(__file__).resolve().parent / "fixtures" / "documents"
WHEELHOUSE = REPOSITORY / "wheelhouse"
CLIENT = "127.0.0.1"
WORKER_ARGV = (sys.executable, "-m", "qwen_apu.tools.document_worker")


def _pypdf_wheel() -> Path | None:
    """The wheel the PDF extractor imports from, or None where pypdf is installed."""
    try:
        import pypdf  # noqa: F401, PLC0415

        return None
    except ImportError:
        wheels = sorted(WHEELHOUSE.glob("pypdf-*.whl"))
        return wheels[0] if wheels else None


PYPDF_WHEEL = _pypdf_wheel()
if PYPDF_WHEEL is not None:
    sys.path.insert(0, str(PYPDF_WHEEL))
EXTRA_PYTHON_PATH: tuple[Path, ...] = () if PYPDF_WHEEL is None else (PYPDF_WHEEL,)


def _pypdf_available() -> bool:
    try:
        import pypdf  # noqa: F401, PLC0415
    except ImportError:
        return False
    return True


requires_pypdf = pytest.mark.skipif(
    not _pypdf_available(),
    reason="pypdf is neither installed nor present as a wheel under wheelhouse/",
)


def fixture(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


def request(
    method: str, path: str, body: bytes = b"", headers: dict[str, str] | None = None, **params: str
) -> Request:
    return Request(
        method=method,
        path=path,
        query={},
        headers={"host": CLIENT, **(headers or {})},
        body=body,
        client_address=CLIENT,
        path_params=params,
    )


def payload(response: Response) -> dict[str, object]:
    parsed = json.loads(response.body.decode("utf-8"))
    assert isinstance(parsed, dict)
    return parsed


def admits_every_session(request: Request) -> bool:
    return True


def tiles(extraction: Extraction, kind: str) -> bool:
    """Whether one kind's boundaries cover the text end to end without a gap."""
    spans = [
        (boundary.char_start, boundary.char_end)
        for boundary in extraction.boundaries
        if boundary.kind == kind
    ]
    if not spans:
        return False
    position = 0
    for start, end in spans:
        if start != position:
            return False
        position = end
    return position == len(extraction.text)


# --- the fixtures themselves --------------------------------------------------


def test_committed_fixtures_match_their_declaration() -> None:
    """`generate_fixtures.py --check` compares content, so a drifted fixture fails here."""
    completed = subprocess.run(
        [sys.executable, str(FIXTURES / "generate_fixtures.py"), "--check"],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 0, completed.stderr


# --- extractors ---------------------------------------------------------------


def test_plain_text_lines_tile_the_text() -> None:
    extraction = extract_text(fixture("plain.txt"), "plain.txt")
    assert extraction.detected_format == "text"
    assert tiles(extraction, "line")
    assert extraction.boundaries[0].char_start == 0


def test_source_extension_names_the_language() -> None:
    extraction = extract_source(fixture("sample.c"), "sample.c")
    assert extraction.detected_format == "source:c"
    assert "MAX_NODES_PER_SUBMIT" in extraction.text


def test_resolve_format_reads_the_extension_before_the_media_type() -> None:
    assert resolve_format("module.py", "text/plain") == "source"
    assert resolve_format("notes.md", "") == "markdown"
    assert resolve_format("untitled", "application/pdf") == "pdf"


def test_an_unclaimed_extension_refuses_by_name() -> None:
    with pytest.raises(ExtractionRefused) as refusal:
        resolve_format("archive.tar.zst", "application/zstd")
    assert "no extractor claims" in refusal.value.message


def test_markdown_sections_open_at_each_heading() -> None:
    extraction = extract_markdown(fixture("notes.md"), "notes.md")
    labels = [boundary.label for boundary in extraction.boundaries]
    assert labels == ["", "# Placement", "## Fabric", "# Depth"]
    assert tiles(extraction, "heading")


def test_json_normalizes_key_order_so_two_spellings_share_one_text() -> None:
    first = extract_json(b'{"b": 1, "a": [2, 3]}', "one.json")
    second = extract_json(b'{\n  "a": [2,3],\n   "b": 1}', "two.json")
    assert first.text == second.text
    assert build_chunks(first)[0].sha256 == build_chunks(second)[0].sha256


def test_json_refuses_a_malformed_document() -> None:
    with pytest.raises(ExtractionRefused) as refusal:
        extract_json(b"{not json}", "broken.json")
    assert "not valid JSON" in refusal.value.message


def test_csv_rows_are_boundaries_under_one_sheet() -> None:
    extraction = extract_delimited(fixture("rows.csv"), "rows.csv", ",", "csv")
    sheets = [boundary for boundary in extraction.boundaries if boundary.kind == "sheet"]
    rows = [boundary for boundary in extraction.boundaries if boundary.kind == "row"]
    assert [sheet.index for sheet in sheets] == [1]
    assert len(rows) == 4
    assert tiles(extraction, "row")
    assert extraction.text.startswith("region\tquarter\tdecode_tokens_per_second\n")


def test_tsv_rows_are_boundaries_under_one_sheet() -> None:
    extraction = extract_delimited(fixture("rows.tsv"), "rows.tsv", "\t", "tsv")
    assert extraction.detected_format == "tsv"
    assert len([b for b in extraction.boundaries if b.kind == "row"]) == 3


def test_html_headings_open_sections_and_script_text_stays_out() -> None:
    extraction = extract_html(fixture("headings.html"), "headings.html")
    labels = [boundary.label for boundary in extraction.boundaries]
    assert labels == ["", "Acquisition", "Measurement", "Disposal"]
    assert tiles(extraction, "heading")
    assert "script text never reaches" not in extraction.text
    assert "color: red" not in extraction.text


def test_docx_paragraphs_tile_and_the_page_break_opens_a_second_page() -> None:
    extraction = extract_docx(fixture("two-paragraphs.docx"), "two-paragraphs.docx", Limits())
    pages = [boundary for boundary in extraction.boundaries if boundary.kind == "page"]
    paragraphs = [boundary for boundary in extraction.boundaries if boundary.kind == "paragraph"]
    assert len(pages) == 2
    assert len(paragraphs) == 3
    assert tiles(extraction, "paragraph")
    assert extraction.text[pages[1].char_start :].startswith("The third paragraph")
    assert extraction.warnings == ()


def docx_with(document_xml: str) -> bytes:
    """One DOCX-shaped archive carrying the given `word/document.xml`."""
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("word/document.xml", document_xml)
    return buffer.getvalue()


WORD = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"


def test_a_page_break_sharing_a_paragraph_with_text_warns() -> None:
    document = (
        f'<w:document xmlns:w="{WORD}"><w:body>'
        "<w:p><w:r><w:t>opening</w:t></w:r></w:p>"
        '<w:p><w:r><w:t>shared</w:t><w:br w:type="page"/></w:r></w:p>'
        "</w:body></w:document>"
    )
    extraction = extract_docx(docx_with(document), "shared.docx", Limits())
    assert any("page break beside text" in warning for warning in extraction.warnings)


def test_a_lastrenderedpagebreak_opens_a_page() -> None:
    document = (
        f'<w:document xmlns:w="{WORD}"><w:body>'
        "<w:p><w:r><w:t>first</w:t></w:r></w:p>"
        "<w:p><w:r><w:lastRenderedPageBreak/><w:t>second</w:t></w:r></w:p>"
        "</w:body></w:document>"
    )
    extraction = extract_docx(docx_with(document), "rendered.docx", Limits())
    assert len([b for b in extraction.boundaries if b.kind == "page"]) == 2


def test_an_xml_part_declaring_a_document_type_refuses() -> None:
    document = (
        '<?xml version="1.0"?><!DOCTYPE d [<!ENTITY a "aa">]>'
        f'<w:document xmlns:w="{WORD}"><w:body/></w:document>'
    )
    with pytest.raises(ExtractionRefused) as refusal:
        extract_docx(docx_with(document), "entity.docx", Limits())
    assert "declares a document type" in refusal.value.message


def test_xlsx_sheets_carry_their_names_and_resolve_shared_strings() -> None:
    extraction = extract_xlsx(fixture("two-sheets.xlsx"), "two-sheets.xlsx", Limits())
    sheets = [boundary for boundary in extraction.boundaries if boundary.kind == "sheet"]
    assert [sheet.label for sheet in sheets] == ["Alpha", "Beta"]
    assert tiles(extraction, "sheet")
    assert "region\t11" in extraction.text
    assert "inline cell" in extraction.text


def test_pptx_slides_are_boundaries_in_numeric_order() -> None:
    extraction = extract_pptx(fixture("two-slides.pptx"), "two-slides.pptx", Limits())
    slides = [boundary for boundary in extraction.boundaries if boundary.kind == "slide"]
    assert [slide.label for slide in slides] == ["Placement", "Depth"]
    assert tiles(extraction, "slide")


@requires_pypdf
def test_pdf_pages_carry_their_text() -> None:
    extraction = extract(fixture("text.pdf"), "text.pdf", "application/pdf", Limits())
    pages = [boundary for boundary in extraction.boundaries if boundary.kind == "page"]
    assert len(pages) == 2
    assert tiles(extraction, "page")
    assert "The first page carries extractable text." in extraction.text
    assert extraction.requires_ocr == ()


@requires_pypdf
def test_an_image_only_pdf_reports_the_pages_that_require_ocr() -> None:
    extraction = extract(fixture("scan.pdf"), "scan.pdf", "application/pdf", Limits())
    assert extraction.requires_ocr == (1,)
    assert any("require OCR" in warning for warning in extraction.warnings)
    assert extraction.text.strip() == ""


# --- chunking and counts ------------------------------------------------------


def test_chunks_end_on_a_boundary_where_one_lands_inside_the_budget() -> None:
    line = "x" * 99 + "\n"
    extraction = extract_text((line * 40).encode("utf-8"), "long.txt")
    chunks = build_chunks(extraction)
    assert len(chunks) > 1
    for chunk in chunks:
        assert chunk.characters <= 1200
        assert extraction.text[chunk.char_end - 1] == "\n"
    assert chunks[-1].char_end == len(extraction.text)


def test_a_span_longer_than_the_budget_cuts_at_the_last_line_break() -> None:
    extraction = extract_text(("y" * 3000 + "\n").encode("utf-8"), "one-line.txt")
    chunks = build_chunks(extraction)
    assert [chunk.characters for chunk in chunks] == [1200, 1200, 601]


def test_every_chunk_digest_matches_the_text_it_names() -> None:
    extraction = extract_markdown(fixture("notes.md"), "notes.md")
    for chunk in build_chunks(extraction):
        body = extraction.text[chunk.char_start : chunk.char_end]
        assert chunk.sha256 == hashlib.sha256(body.encode("utf-8")).hexdigest()
        assert chunk.boundaries


def test_the_token_estimate_is_the_character_count_over_four() -> None:
    assert ESTIMATE_BASIS == "chars/4"
    assert approximate_tokens(0) == 0
    assert approximate_tokens(1) == 1
    assert approximate_tokens(4000) == 1000


# --- archive guards -----------------------------------------------------------


def test_the_declared_uncompressed_total_refuses_before_a_member_opens() -> None:
    with pytest.raises(ExtractionRefused) as refusal:
        extract_docx(
            fixture("zip-bomb.docx"), "zip-bomb.docx", Limits(max_uncompressed_bytes=65536)
        )
    assert "declares 8389348 uncompressed bytes" in refusal.value.message


def test_the_member_count_cap_refuses() -> None:
    with pytest.raises(ExtractionRefused) as refusal:
        extract_docx(
            fixture("two-paragraphs.docx"), "two-paragraphs.docx", Limits(max_archive_members=2)
        )
    assert "past the 2-member cap" in refusal.value.message


def test_a_member_read_past_the_cap_refuses() -> None:
    """The read cap answers a central directory that understates its own member."""
    archive = open_archive(fixture("two-paragraphs.docx"), Limits())
    with pytest.raises(ExtractionRefused) as refusal:
        read_member(archive, "word/document.xml", Limits(max_uncompressed_bytes=16))
    assert "expands past the 16-byte cap" in refusal.value.message


def test_a_package_missing_its_main_part_refuses() -> None:
    empty = io.BytesIO()
    with zipfile.ZipFile(empty, "w") as archive:
        archive.writestr("other.xml", "<a/>")
    with pytest.raises(ExtractionRefused) as refusal:
        extract_docx(empty.getvalue(), "empty.docx", Limits())
    assert "carries no word/document.xml" in refusal.value.message


# --- the worker as a process --------------------------------------------------


def run_worker(job: dict[str, object]) -> tuple[int, dict[str, object]]:
    """Run the worker as the service runs it, and return its exit code and report."""
    environment = {
        "PATH": os.environ.get("PATH", os.defpath),
        "PYTHONPATH": os.pathsep.join(
            [str(REPOSITORY / "src"), *(str(entry) for entry in EXTRA_PYTHON_PATH)]
        ),
        "PYTHONDONTWRITEBYTECODE": "1",
    }
    completed = subprocess.run(
        list(WORKER_ARGV),
        check=False,
        input=json.dumps(job).encode("utf-8"),
        capture_output=True,
        env=environment,
    )
    parsed = json.loads(completed.stdout.decode("utf-8"))
    assert isinstance(parsed, dict)
    return completed.returncode, parsed


def test_the_worker_writes_the_record_and_one_file_per_chunk(tmp_path: Path) -> None:
    output = tmp_path / "job"
    code, report = run_worker(
        {
            "input_path": str(FIXTURES / "notes.md"),
            "filename": "notes.md",
            "media_type": "text/markdown",
            "output_directory": str(output),
        }
    )
    assert code == 0
    digest = hashlib.sha256(fixture("notes.md")).hexdigest()
    assert report["sha256"] == digest
    record = json.loads((output / f"{digest}.json").read_text(encoding="utf-8"))
    assert record["detected_format"] == "markdown"
    assert record["approximate_tokens_basis"] == "chars/4"
    for chunk in record["chunks"]:
        assert (output / "chunks" / f"{chunk['index']}.txt").is_file()


def test_the_worker_refuses_an_input_past_the_size_cap(tmp_path: Path) -> None:
    large = tmp_path / "large.txt"
    large.write_bytes(b"z" * 4096)
    code, report = run_worker(
        {
            "input_path": str(large),
            "filename": "large.txt",
            "media_type": "text/plain",
            "output_directory": str(tmp_path / "job"),
            "limits": {"max_input_bytes": 1024},
        }
    )
    assert code == 1
    assert report["status"] == "refused"
    assert "past the 1024-byte cap" in str(report["error"])


def test_the_worker_refuses_a_job_that_is_not_an_object() -> None:
    completed = subprocess.run(
        list(WORKER_ARGV),
        check=False,
        input=b"[1, 2]",
        capture_output=True,
        env={"PATH": os.environ.get("PATH", os.defpath), "PYTHONPATH": str(REPOSITORY / "src")},
    )
    assert completed.returncode == 1
    assert "not a JSON object" in completed.stdout.decode("utf-8")


def test_the_worker_prints_a_usage_block_on_an_argument(tmp_path: Path) -> None:
    completed = subprocess.run(
        [*WORKER_ARGV, "unexpected"],
        check=False,
        capture_output=True,
        env={"PATH": os.environ.get("PATH", os.defpath), "PYTHONPATH": str(REPOSITORY / "src")},
    )
    assert completed.returncode == 2
    assert "usage:" in completed.stderr.decode("utf-8")


# --- the resource limits ------------------------------------------------------


LIMIT_PROLOGUE = (
    "import resource, sys\n"
    "sys.path.insert(0, sys.argv[1])\n"
    "from qwen_apu.tools.document_worker import Limits, apply_limits\n"
)


def run_limited(body: str, **limits: int) -> subprocess.CompletedProcess[bytes]:
    source = LIMIT_PROLOGUE + f"apply_limits(Limits(**{limits!r}))\n" + body
    return subprocess.run(
        [sys.executable, "-c", source, str(REPOSITORY / "src")],
        check=False,
        capture_output=True,
    )


def test_apply_limits_caps_address_space_cpu_time_and_file_size() -> None:
    completed = run_limited(
        "import json\n"
        "print(json.dumps([resource.getrlimit(r) for r in "
        "(resource.RLIMIT_AS, resource.RLIMIT_CPU, resource.RLIMIT_FSIZE)]))\n",
        address_space_bytes=256 * 1024 * 1024,
        cpu_seconds=7,
        max_output_bytes=1024,
    )
    assert completed.returncode == 0
    assert json.loads(completed.stdout.decode("utf-8")) == [
        [256 * 1024 * 1024, 256 * 1024 * 1024],
        [7, 7],
        [1024, 1024],
    ]


def test_the_address_space_cap_ends_a_large_allocation() -> None:
    completed = run_limited(
        "try:\n    b'x' * (512 * 1024 * 1024)\nexcept MemoryError:\n    print('MemoryError')\n",
        address_space_bytes=256 * 1024 * 1024,
    )
    assert b"MemoryError" in completed.stdout


def test_the_cpu_cap_ends_a_spinning_worker() -> None:
    completed = run_limited("while True:\n    pass\n", cpu_seconds=1)
    # SIGXCPU ends the process; a handler-free default terminates it.
    assert completed.returncode < 0


def test_the_file_size_cap_ends_a_runaway_write(tmp_path: Path) -> None:
    target = tmp_path / "runaway"
    completed = run_limited(
        f"handle = open({str(target)!r}, 'wb')\n"
        "try:\n"
        "    handle.write(b'x' * (256 * 1024))\n"
        "    handle.flush()\n"
        "except OSError as error:\n"
        "    print(type(error).__name__)\n",
        max_output_bytes=4096,
    )
    assert completed.returncode < 0 or b"OSError" in completed.stdout
    assert target.stat().st_size <= 4096


# --- the service --------------------------------------------------------------


@pytest.fixture
def settings(tmp_path: Path) -> DocumentSettings:
    return DocumentSettings(
        artifacts=tmp_path / "artifacts",
        tmp=tmp_path / "tmp",
        python_path=EXTRA_PYTHON_PATH,
        session_admits=admits_every_session,
    )


@pytest.fixture
def service(settings: DocumentSettings) -> DocumentService:
    return DocumentService(settings)


def test_extraction_publishes_into_the_content_addressed_store(
    service: DocumentService, settings: DocumentSettings
) -> None:
    record = service.extract(FIXTURES / "notes.md", "text/markdown")
    digest = hashlib.sha256(fixture("notes.md")).hexdigest()
    assert record.sha256 == digest
    stored = settings.store() / digest
    assert (stored / f"{digest}.json").is_file()
    assert (stored / "chunks" / "1.txt").read_text(encoding="utf-8").startswith("Placement sweeps")
    assert list(settings.scratch().iterdir()) == []


def test_a_second_extraction_of_the_same_bytes_answers_from_the_store(
    service: DocumentService, settings: DocumentSettings
) -> None:
    """The store answers before the worker starts, so a failing argv still succeeds."""
    first = service.extract(FIXTURES / "notes.md", "text/markdown")
    second = DocumentService(
        DocumentSettings(
            artifacts=settings.artifacts,
            tmp=settings.tmp,
            worker_command=("/bin/false",),
            session_admits=admits_every_session,
        )
    ).extract(FIXTURES / "notes.md", "text/markdown")
    assert second.sha256 == first.sha256
    assert second.chunks == first.chunks


def test_a_partial_store_directory_is_replaced_rather_than_treated_as_published(
    service: DocumentService, settings: DocumentSettings
) -> None:
    """A run killed before its record write leaves a directory that publishes nothing."""
    digest = hashlib.sha256(fixture("rows.csv")).hexdigest()
    # A non-empty directory is what makes the rename refuse; an empty one the
    # kernel renames over, so the partial run leaves its chunk directory here.
    (settings.store() / digest / "chunks").mkdir(parents=True)
    (settings.store() / digest / "chunks" / "1.txt").write_text("partial", encoding="utf-8")
    record = service.extract(FIXTURES / "rows.csv", "text/csv")
    assert record.sha256 == digest
    assert service.record(digest).detected_format == "csv"
    assert service.search(digest, "north")


def test_a_lost_publication_race_keeps_the_published_copy(
    service: DocumentService, settings: DocumentSettings, tmp_path: Path
) -> None:
    """A published directory under the digest wins and the loser keeps its own copy."""
    first = service.extract(FIXTURES / "rows.csv", "text/csv")
    stored = settings.store() / first.sha256
    (stored / "marker").write_text("the published copy", encoding="utf-8")
    staging = tmp_path / "staging"
    (staging / "chunks").mkdir(parents=True)
    (staging / f"{first.sha256}.json").write_text("{}", encoding="utf-8")
    _publish(staging, stored)
    assert (stored / "marker").is_file()
    assert (stored / f"{first.sha256}.json").read_text(encoding="utf-8") != "{}"
    assert staging.is_dir()


def test_every_record_names_what_the_isolation_probe_established(
    service: DocumentService,
) -> None:
    record = service.extract(FIXTURES / "plain.txt", "text/plain")
    assert record.network_isolation == service.network_isolation
    assert record.network_isolation in {"namespaced", "unavailable"}


@pytest.mark.skipif(
    probe_network_isolation() != NETWORK_ISOLATION_NAMESPACED,
    reason="this kernel refuses an unprivileged user namespace, so the worker runs unisolated",
)
def test_the_worker_runs_inside_its_own_network_namespace(service: DocumentService) -> None:
    assert service.network_isolation == NETWORK_ISOLATION_NAMESPACED
    record = service.extract(FIXTURES / "plain.txt", "text/plain")
    assert record.network_isolation == NETWORK_ISOLATION_NAMESPACED


@requires_pypdf
def test_the_service_carries_the_requires_ocr_report_through_the_store(
    service: DocumentService,
) -> None:
    record = service.extract(FIXTURES / "scan.pdf", "application/pdf")
    assert record.requires_ocr == (1,)
    assert service.record(record.sha256).requires_ocr == (1,)


def test_the_upload_cap_refuses_before_any_process_starts(
    settings: DocumentSettings, tmp_path: Path
) -> None:
    service = DocumentService(
        DocumentSettings(
            artifacts=settings.artifacts,
            tmp=settings.tmp,
            max_upload_bytes=64,
            worker_command=("/bin/false",),
            session_admits=admits_every_session,
        )
    )
    with pytest.raises(DocumentRefused) as refusal:
        service.extract(FIXTURES / "notes.md", "text/markdown")
    assert refusal.value.status == 413


# A stand-in worker that forks, records the child's pid where the test reads it,
# and sleeps: both processes share one group, so a group kill ends both and a
# kill of the leader alone leaves the child running.
SLEEPING_WORKER = (
    "import os, sys, time\n"
    "child = os.fork()\n"
    "if child:\n"
    "    open(sys.argv[1], 'w').write(str(child))\n"
    "time.sleep(30)\n"
)


def departed(pid: int, deadline: float = 10.0) -> bool:
    """Whether a pid is gone or reaped, polled to the deadline."""
    end = time.monotonic() + deadline
    while time.monotonic() < end:
        try:
            os.kill(pid, 0)
        except (ProcessLookupError, PermissionError):
            return True
        try:
            state = (Path("/proc") / str(pid) / "stat").read_text(encoding="utf-8")
        except OSError:
            return True
        if ") Z" in state:
            return True
        time.sleep(0.05)
    return False


def test_the_deadline_kills_the_whole_worker_group(
    settings: DocumentSettings, tmp_path: Path
) -> None:
    marker = tmp_path / "grandchild.pid"
    service = DocumentService(
        DocumentSettings(
            artifacts=settings.artifacts,
            tmp=settings.tmp,
            deadline_seconds=1.0,
            worker_command=(sys.executable, "-c", SLEEPING_WORKER, str(marker)),
            session_admits=admits_every_session,
        )
    )
    started = time.monotonic()
    with pytest.raises(DocumentRefused) as refusal:
        service.extract(FIXTURES / "plain.txt", "text/plain")
    assert refusal.value.status == 504
    assert "deadline" in refusal.value.message
    assert time.monotonic() - started < 20.0
    child = int(marker.read_text(encoding="utf-8"))
    assert departed(child), f"pid {child} outlived its group's kill"


def test_a_worker_refusal_reaches_the_caller_as_its_own_text(
    service: DocumentService, tmp_path: Path
) -> None:
    mystery = tmp_path / "mystery.bin"
    mystery.write_bytes(b"\x00\x01\x02")
    with pytest.raises(DocumentRefused) as refusal:
        service.extract(mystery, "application/octet-stream")
    assert refusal.value.status == 400
    assert "no extractor claims" in refusal.value.message


def test_an_unstored_digest_answers_404(service: DocumentService) -> None:
    with pytest.raises(DocumentRefused) as refusal:
        service.record("0" * 64)
    assert refusal.value.status == 404


def test_a_malformed_digest_refuses_before_the_lookup(service: DocumentService) -> None:
    with pytest.raises(DocumentRefused) as refusal:
        service.record("../../etc/passwd")
    assert refusal.value.status == 400


# --- search -------------------------------------------------------------------


def test_search_reports_the_chunk_and_the_boundaries_a_hit_falls_inside(
    service: DocumentService,
) -> None:
    record = service.extract(FIXTURES / "two-paragraphs.docx", "")
    hits = service.search(record.sha256, "third paragraph")
    assert len(hits) == 1
    hit = hits[0]
    assert hit.chunk_index == 1
    assert hit.chunk_sha256 == record.chunks[0].sha256
    assert "page:2" in hit.boundaries
    assert "paragraph:3" in hit.boundaries
    assert hit.text.startswith("The third paragraph")


def test_search_takes_a_regular_expression(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "rows.csv", "text/csv")
    hits = service.search(record.sha256, r"\bnorth\b", regex=True)
    assert [hit.chunk_index for hit in hits] == [1, 1]
    assert all("sheet:1" in hit.boundaries for hit in hits)


def test_a_literal_query_matches_its_own_characters(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "rows.csv", "text/csv")
    assert service.search(record.sha256, "north.spring") == ()


def test_search_refuses_a_broken_regular_expression(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "rows.csv", "text/csv")
    with pytest.raises(DocumentRefused) as refusal:
        service.search(record.sha256, "(unclosed", regex=True)
    assert refusal.value.status == 400


def test_chunk_text_reads_back_what_the_record_names(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "notes.md", "text/markdown")
    body = service.chunk_text(record.sha256, 1)
    assert hashlib.sha256(body.encode("utf-8")).hexdigest() == record.chunks[0].sha256


# --- routes -------------------------------------------------------------------


def test_the_three_routes_match_their_methods_and_paths(service: DocumentService) -> None:
    table = routes(service)
    digest = "a" * 64
    assert match(table, "POST", DOCUMENTS_ROUTE) is not None
    found = match(table, "GET", f"/api/documents/{digest}")
    assert found is not None and found[1] == {"digest": digest}
    found = match(table, "POST", f"/api/documents/{digest}/search")
    assert found is not None and found[1] == {"digest": digest}
    assert match(table, "GET", "/api/documents/short") is None
    assert DIGEST_PATTERN.match(digest)
    assert DOCUMENT_ROUTE in DOCUMENT_SEARCH_ROUTE


def test_every_route_refuses_where_no_session_is_wired(settings: DocumentSettings) -> None:
    """The default check refuses, so an unconfigured mount serves nothing."""
    service = DocumentService(DocumentSettings(artifacts=settings.artifacts, tmp=settings.tmp))
    upload = handle_upload(service, request("POST", DOCUMENTS_ROUTE, b"body"))
    record = handle_record(service, request("GET", "/api/documents/x", digest="a" * 64))
    search = handle_search(service, request("POST", "/api/documents/x/search", b"{}"))
    assert [upload.status, record.status, search.status] == [401, 401, 401]


def test_a_raw_upload_names_its_file_through_x_filename(service: DocumentService) -> None:
    response = handle_upload(
        service,
        request(
            "POST",
            DOCUMENTS_ROUTE,
            fixture("notes.md"),
            {"content-type": "text/markdown", "x-filename": "notes.md"},
        ),
    )
    assert response.status == 201
    body = payload(response)
    assert body["detected_format"] == "markdown"
    assert body["sha256"] == hashlib.sha256(fixture("notes.md")).hexdigest()


def test_a_multipart_upload_preserves_the_bytes_it_carries(service: DocumentService) -> None:
    data = fixture("two-paragraphs.docx")
    boundary = "----qwenboundary"
    body = (
        (
            f"--{boundary}\r\n"
            'Content-Disposition: form-data; name="file"; filename="two-paragraphs.docx"\r\n'
            "Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            "\r\n\r\n"
        ).encode()
        + data
        + f"\r\n--{boundary}--\r\n".encode()
    )
    response = handle_upload(
        service,
        request(
            "POST",
            DOCUMENTS_ROUTE,
            body,
            {"content-type": f"multipart/form-data; boundary={boundary}"},
        ),
    )
    assert response.status == 201
    assert payload(response)["sha256"] == hashlib.sha256(data).hexdigest()


def test_an_upload_naming_no_file_refuses(service: DocumentService) -> None:
    response = handle_upload(service, request("POST", DOCUMENTS_ROUTE, b"body"))
    assert response.status == 400
    assert "X-Filename" in str(payload(response)["error"])


def test_a_multipart_body_without_a_boundary_refuses(service: DocumentService) -> None:
    response = handle_upload(
        service,
        request("POST", DOCUMENTS_ROUTE, b"body", {"content-type": "multipart/form-data"}),
    )
    assert response.status == 400


def test_a_filename_carrying_a_path_separator_refuses() -> None:
    with pytest.raises(DocumentRefused) as refusal:
        safe_filename("../../etc/passwd")
    assert "names a path" in refusal.value.message
    with pytest.raises(DocumentRefused):
        safe_filename(".hidden")
    assert safe_filename("two-paragraphs.docx") == "two-paragraphs.docx"


def test_parse_upload_reads_the_media_type_from_the_part(service: DocumentService) -> None:
    upload = parse_upload(
        request(
            "POST",
            DOCUMENTS_ROUTE,
            b"body",
            {"content-type": "text/plain; charset=utf-8", "x-filename": "a.txt"},
        )
    )
    assert upload.media_type == "text/plain"
    assert upload.data == b"body"


def test_the_record_route_answers_a_stored_document(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "rows.csv", "text/csv")
    response = handle_record(
        service, request("GET", f"/api/documents/{record.sha256}", digest=record.sha256)
    )
    assert response.status == 200
    assert payload(response)["detected_format"] == "csv"


def test_the_search_route_answers_hits_with_their_references(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "two-slides.pptx", "")
    response = handle_search(
        service,
        request(
            "POST",
            f"/api/documents/{record.sha256}/search",
            json.dumps({"query": "registry"}).encode("utf-8"),
            digest=record.sha256,
        ),
    )
    assert response.status == 200
    body = payload(response)
    hits = body["hits"]
    assert isinstance(hits, list) and len(hits) == 1
    assert "slide:2" in hits[0]["boundaries"]


def test_the_search_route_refuses_an_absent_query(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "rows.csv", "text/csv")
    response = handle_search(
        service,
        request("POST", "/api/documents/x/search", b"{}", digest=record.sha256),
    )
    assert response.status == 400


# --- the upload bound ---------------------------------------------------------


def _blocks_forever(limit: int) -> Callable[[int], bytes]:
    """A reader that hands out blocks and fails the test where it is read past `limit`."""
    handed = 0

    def read(size: int) -> bytes:
        nonlocal handed
        if handed > limit:
            raise AssertionError(f"the copy read {handed} bytes, past the {limit}-byte bound")
        handed += size
        return b"u" * size

    return read


def test_stage_body_refuses_at_the_bound_while_reading(tmp_path: Path) -> None:
    """The running count stops the copy, so the reader is never asked for the rest.

    The declaration states nothing here, which is the case a body longer than
    its own Content-Length presents; the reader raises where the copy keeps
    reading past the bound, so the refusal proves the copy stopped.
    """
    target = tmp_path / "body"
    bound = 4 * UPLOAD_BLOCK_BYTES
    with pytest.raises(DocumentRefused) as refusal:
        stage_body(_blocks_forever(bound + UPLOAD_BLOCK_BYTES), 0, target, bound)
    assert refusal.value.status == 413
    assert f"passes the {bound}-byte upload bound" in refusal.value.message
    assert target.stat().st_size <= bound


def test_stage_body_refuses_a_declaration_past_the_bound(tmp_path: Path) -> None:
    """A Content-Length past the bound refuses before one byte is read."""

    def unread(size: int) -> bytes:
        raise AssertionError("the copy read a body its declaration already refused")

    with pytest.raises(DocumentRefused) as refusal:
        stage_body(unread, 1 << 30, tmp_path / "body", 64)
    assert refusal.value.status == 413
    assert "declares 1073741824 bytes" in refusal.value.message


def test_stage_body_writes_what_it_reads(tmp_path: Path) -> None:
    source = io.BytesIO(b"a" * 5000)
    target = tmp_path / "body"
    written = stage_body(source.read, 5000, target, 1 << 20, block=512)
    assert written == 5000
    assert target.read_bytes() == b"a" * 5000


class Serving:
    """One gateway serving the document routes alone, on a port the bind decides."""

    def __init__(self, settings: DocumentSettings, static_root: Path) -> None:
        static_root.mkdir(parents=True, exist_ok=True)
        (static_root / "index.html").write_text("<!doctype html>\n", encoding="utf-8")
        self.gateway = Gateway(
            GatewayConfig(static_root=static_root, port=0, bind_host="127.0.0.1"),
            (_Mounted(routes(DocumentService(settings))),),
        )
        self.thread = threading.Thread(target=self.gateway.serve_forever)
        self.thread.start()

    def post(self, body: bytes, headers: dict[str, str]) -> tuple[int, dict[str, object]]:
        connection = HTTPConnection("127.0.0.1", self.gateway.port, timeout=60.0)
        try:
            connection.request("POST", DOCUMENTS_ROUTE, body=body, headers=headers)
            response = connection.getresponse()
            answer = json.loads(response.read().decode("utf-8"))
            assert isinstance(answer, dict)
            return response.status, answer
        finally:
            connection.close()

    def stop(self) -> None:
        self.gateway.shutdown()
        self.thread.join(timeout=60.0)


class _Mounted:
    def __init__(self, table: tuple[object, ...]) -> None:
        self._table = table

    def routes(self) -> tuple[object, ...]:
        return self._table


@pytest.fixture
def serve(tmp_path: Path) -> Iterator[Callable[[int], Serving]]:
    """A factory for one gateway per bound, torn down whatever the test asserts."""
    running: list[Serving] = []

    def start(bound: int) -> Serving:
        served = Serving(
            DocumentSettings(
                artifacts=tmp_path / "artifacts",
                tmp=tmp_path / "tmp",
                max_request_bytes=bound,
                python_path=EXTRA_PYTHON_PATH,
                session_admits=admits_every_session,
            ),
            tmp_path / "static",
        )
        running.append(served)
        return served

    try:
        yield start
    finally:
        for served in running:
            served.stop()


def test_the_upload_route_refuses_a_body_past_its_own_bound(
    serve: Callable[[int], Serving],
) -> None:
    """The route's bound answers the request, and the general JSON cap decides nothing.

    Content-Length is what the refusal reads, since the stream clamps every
    read to it: a body longer than its own declaration reaches the copy's
    running count, which `test_stage_body_refuses_at_the_bound_while_reading`
    proves against a reader that keeps handing out bytes.
    """
    served = serve(16 * 1024)
    status, answer = served.post(
        b"z" * (48 * 1024),
        {"Content-Type": "text/plain", "X-Filename": "large.txt"},
    )
    assert status == 413
    assert "past the 16384-byte upload bound" in str(answer["error"])


def test_the_upload_route_stores_a_body_the_gateway_cap_refuses(
    serve: Callable[[int], Serving],
) -> None:
    """Two mebibytes reach the store, twice what a route reading its body whole admits."""
    served = serve(DEFAULT_MAX_REQUEST_BYTES)
    line = ("w" * (128 * 1024 - 1) + "\n").encode("utf-8")
    body = line * 16
    assert len(body) > REQUEST_BODY_BYTE_CAP
    status, answer = served.post(body, {"Content-Type": "text/plain", "X-Filename": "long.txt"})
    assert status == 201, answer
    assert answer["sha256"] == hashlib.sha256(body).hexdigest()
    assert answer["source_bytes"] == len(body)
    assert answer["detected_format"] == "text"


def test_a_streamed_multipart_upload_preserves_the_file_part(
    serve: Callable[[int], Serving],
) -> None:
    """The part's byte range copies out of the staged body, digest for digest."""
    served = serve(DEFAULT_MAX_REQUEST_BYTES)
    data = fixture("two-paragraphs.docx")
    boundary = "----qwenstreamboundary"
    body = (
        (
            f"--{boundary}\r\n"
            'Content-Disposition: form-data; name="note"\r\n\r\n'
            "a field ahead of the file\r\n"
            f"--{boundary}\r\n"
            'Content-Disposition: form-data; name="file"; filename="two-paragraphs.docx"\r\n'
            "Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            "\r\n\r\n"
        ).encode()
        + data
        + f"\r\n--{boundary}--\r\n".encode()
    )
    status, answer = served.post(
        body, {"Content-Type": f"multipart/form-data; boundary={boundary}"}
    )
    assert status == 201, answer
    assert answer["sha256"] == hashlib.sha256(data).hexdigest()
    assert answer["detected_format"] == "docx"


def test_a_streamed_upload_naming_no_file_refuses(serve: Callable[[int], Serving]) -> None:
    served = serve(DEFAULT_MAX_REQUEST_BYTES)
    status, answer = served.post(b"a body with no name", {"Content-Type": "text/plain"})
    assert status == 400
    assert "X-Filename" in str(answer["error"])


# --- the search bounds --------------------------------------------------------


CATASTROPHIC_PATTERN = r"(a+)+$"
SEARCH_WALL_CLOCK_SECONDS = 1.0


@pytest.fixture
def bounded(tmp_path: Path) -> DocumentService:
    """A service whose search bounds are small enough for a test to meet them."""
    return DocumentService(
        DocumentSettings(
            artifacts=tmp_path / "artifacts",
            tmp=tmp_path / "tmp",
            search_bounds=SearchBounds(
                max_pattern_chars=24,
                max_pattern_groups=2,
                max_candidate_chunks=2,
                wall_clock_seconds=SEARCH_WALL_CLOCK_SECONDS,
            ),
            python_path=EXTRA_PYTHON_PATH,
            session_admits=admits_every_session,
        )
    )


def _backtracking_document(tmp_path: Path) -> Path:
    """One chunk of a thousand `a` and one `!`, where `(a+)+$` never finishes.

    The exclamation mark is what makes the match fail: the group must consume
    it to reach the end anchor and cannot, so the engine tries every partition
    of the run ahead of it.
    """
    source = tmp_path / "runs.txt"
    source.write_text("a" * 1000 + "!\n", encoding="utf-8")
    return source


def test_a_catastrophic_pattern_answers_search_bounded_inside_the_bound(
    bounded: DocumentService, tmp_path: Path
) -> None:
    """The worker's own SIGALRM ends the match, since no Python handler runs inside one."""
    record = bounded.extract(_backtracking_document(tmp_path), "text/plain")
    started = time.monotonic()
    with pytest.raises(DocumentRefused) as refusal:
        bounded.search(record.sha256, CATASTROPHIC_PATTERN, regex=True)
    elapsed = time.monotonic() - started
    assert refusal.value.kind == "search_bounded"
    assert refusal.value.status == 400
    assert "SIGALRM" in refusal.value.message
    # The lower bound proves the match ran and the timer ended it; the upper
    # one proves the refusal arrives at the bound rather than at the service's
    # own 120-second deadline.
    assert SEARCH_WALL_CLOCK_SECONDS / 2 < elapsed < SEARCH_WALL_CLOCK_SECONDS + 5.0


def test_the_same_pattern_costs_the_gateway_nothing_as_a_literal(
    bounded: DocumentService, tmp_path: Path
) -> None:
    """A literal query is the default, so the pattern's own characters are what it seeks."""
    record = bounded.extract(_backtracking_document(tmp_path), "text/plain")
    assert bounded.search(record.sha256, CATASTROPHIC_PATTERN) == ()
    assert bounded.search(record.sha256, "aaaa")


def test_a_pattern_past_the_character_bound_answers_search_bounded(
    bounded: DocumentService, tmp_path: Path
) -> None:
    record = bounded.extract(_backtracking_document(tmp_path), "text/plain")
    with pytest.raises(DocumentRefused) as refusal:
        bounded.search(record.sha256, "a" * 25, regex=True)
    assert refusal.value.kind == "search_bounded"
    assert "past the 24-character bound" in refusal.value.message


def test_a_pattern_past_the_group_bound_answers_search_bounded(
    bounded: DocumentService, tmp_path: Path
) -> None:
    record = bounded.extract(_backtracking_document(tmp_path), "text/plain")
    with pytest.raises(DocumentRefused) as refusal:
        bounded.search(record.sha256, "(a)(b)(c)", regex=True)
    assert refusal.value.kind == "search_bounded"
    assert "past the 2-group bound" in refusal.value.message


def test_a_document_past_the_candidate_chunk_bound_answers_search_bounded(
    bounded: DocumentService, tmp_path: Path
) -> None:
    """The chunk count refuses ahead of the first match, literal or not."""
    long_document = tmp_path / "many.txt"
    long_document.write_text(("x" * 1199 + "\n") * 4, encoding="utf-8")
    record = bounded.extract(long_document, "text/plain")
    assert len(record.chunks) > 2
    with pytest.raises(DocumentRefused) as refusal:
        bounded.search(record.sha256, "x")
    assert refusal.value.kind == "search_bounded"
    assert "past the 2-chunk search bound" in refusal.value.message


def test_the_worker_enforces_the_pattern_bound_the_gateway_also_states(
    bounded: DocumentService, tmp_path: Path
) -> None:
    """The bound is the worker's own, so a job naming it directly meets it there."""
    record = bounded.extract(_backtracking_document(tmp_path), "text/plain")
    stored = bounded.settings.store() / record.sha256
    code, report = run_worker(
        {
            "mode": "search",
            "document_directory": str(stored),
            "digest": record.sha256,
            "query": "a" * 25,
            "regex": True,
            "bounds": {"max_pattern_chars": 24},
        }
    )
    assert code == 1
    assert report["refusal"] == "search_bounded"
    assert "past the 24-character bound" in str(report["error"])


def test_the_search_worker_reports_its_matches_as_chunk_spans(
    service: DocumentService, tmp_path: Path
) -> None:
    record = service.extract(FIXTURES / "rows.csv", "text/csv")
    stored = service.settings.store() / record.sha256
    code, report = run_worker(
        {
            "mode": "search",
            "document_directory": str(stored),
            "digest": record.sha256,
            "query": r"\bnorth\b",
            "regex": True,
        }
    )
    assert code == 0
    assert report["status"] == "searched"
    matches = report["matches"]
    assert isinstance(matches, list) and len(matches) == 2
    assert all(entry["chunk_index"] == 1 for entry in matches)


def test_the_worker_refuses_a_mode_it_does_not_run() -> None:
    code, report = run_worker({"mode": "summarize"})
    assert code == 1
    assert "names no mode this worker runs" in str(report["error"])


def test_the_search_route_names_the_refusal_beside_its_text(
    bounded: DocumentService, tmp_path: Path
) -> None:
    record = bounded.extract(_backtracking_document(tmp_path), "text/plain")
    response = handle_search(
        bounded,
        request(
            "POST",
            f"/api/documents/{record.sha256}/search",
            json.dumps({"query": "a" * 25, "regex": True}).encode("utf-8"),
            digest=record.sha256,
        ),
    )
    assert response.status == 400
    assert payload(response)["refusal"] == "search_bounded"


# --- format qualification -----------------------------------------------------


def test_docx_headings_and_paragraphs_are_separate_boundaries() -> None:
    """A heading section runs to the next heading while the paragraphs tile the text."""
    extraction = extract_docx(fixture("headings.docx"), "headings.docx", Limits())
    headings = [boundary for boundary in extraction.boundaries if boundary.kind == "heading"]
    paragraphs = [boundary for boundary in extraction.boundaries if boundary.kind == "paragraph"]
    assert [heading.label for heading in headings] == ["", "Acquisition", "Measurement"]
    assert len(paragraphs) == 6
    assert tiles(extraction, "heading")
    assert tiles(extraction, "paragraph")
    assert extraction.primary_kind == "paragraph"
    assert extraction.text[headings[1].char_start :].startswith("Acquisition\n")


def test_a_docx_record_names_the_heading_a_chunk_sits_under(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "headings.docx", "")
    assert record.detected_format == "docx"
    assert record.state == "extracted"
    hits = service.search(record.sha256, "rate it recorded")
    assert len(hits) == 1
    assert "heading:3" in hits[0].boundaries
    assert "paragraph:5" in hits[0].boundaries


def test_xlsx_rows_name_their_sheet_and_cell_range() -> None:
    extraction = extract_xlsx(fixture("two-sheets.xlsx"), "two-sheets.xlsx", Limits())
    rows = [boundary for boundary in extraction.boundaries if boundary.kind == "row"]
    assert [row.label for row in rows] == [
        "Alpha!A1:B1",
        "Alpha!A2:B2",
        "Beta!A1:B1",
        "Beta!A2:B2",
    ]
    assert tiles(extraction, "row")


def test_an_xlsx_record_carries_the_sheet_and_the_range(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "two-sheets.xlsx", "")
    sheets = [boundary for boundary in record.boundaries if boundary.kind == "sheet"]
    rows = [boundary for boundary in record.boundaries if boundary.kind == "row"]
    assert [sheet.label for sheet in sheets] == ["Alpha", "Beta"]
    assert [row.label for row in rows][0] == "Alpha!A1:B1"
    assert [row.label for row in rows][-1] == "Beta!A2:B2"


def test_a_pptx_record_carries_one_boundary_per_slide(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "two-slides.pptx", "")
    slides = [boundary for boundary in record.boundaries if boundary.kind == "slide"]
    assert [slide.index for slide in slides] == [1, 2]
    assert [slide.label for slide in slides] == ["Placement", "Depth"]


@requires_pypdf
def test_a_text_pdf_record_carries_one_boundary_per_page(service: DocumentService) -> None:
    """The record is where a page reference is read back, so the proof reads it there."""
    record = service.extract(FIXTURES / "text.pdf", "application/pdf")
    pages = [boundary for boundary in record.boundaries if boundary.kind == "page"]
    assert [page.index for page in pages] == [1, 2]
    assert pages[0].char_end == pages[1].char_start
    assert record.state == "extracted"
    assert record.requires_ocr == ()
    first = service.search(record.sha256, "The first page")
    second = service.search(record.sha256, "The second page")
    assert first[0].boundaries == ("page:1",)
    assert second[0].boundaries == ("page:2",)


@requires_pypdf
def test_an_image_only_pdf_records_the_ocr_required_state(service: DocumentService) -> None:
    """An empty extraction states its reason rather than reporting a complete one."""
    record = service.extract(FIXTURES / "scan.pdf", "application/pdf")
    assert record.state == "ocr_required"
    assert record.requires_ocr == (1,)
    assert record.characters == 0
    assert record.chunks == ()
    assert service.record(record.sha256).state == "ocr_required"


@requires_pypdf
def test_the_upload_route_answers_the_ocr_required_state(service: DocumentService) -> None:
    response = handle_upload(
        service,
        request(
            "POST",
            DOCUMENTS_ROUTE,
            fixture("scan.pdf"),
            {"content-type": "application/pdf", "x-filename": "scan.pdf"},
        ),
    )
    assert response.status == 201
    body = payload(response)
    assert body["state"] == "ocr_required"
    assert body["requires_ocr"] == [1]


def test_a_text_record_states_that_it_extracted(service: DocumentService) -> None:
    record = service.extract(FIXTURES / "plain.txt", "text/plain")
    assert record.state == "extracted"
    assert record.extractor_version == "2"
    assert record.schema == "qwen-apu-document-record-2"
