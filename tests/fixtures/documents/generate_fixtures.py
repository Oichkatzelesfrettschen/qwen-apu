"""Write every document fixture from the declaration in this file.

    python3 tests/fixtures/documents/generate_fixtures.py
    python3 tests/fixtures/documents/generate_fixtures.py --check

Each fixture is small enough to commit and states its own expected extraction:
`two-paragraphs.docx` carries two paragraphs around one `w:br w:type="page"`,
`two-sheets.xlsx` names its sheets Alpha and Beta, `two-slides.pptx` titles its
slides, `text.pdf` draws two text pages through an uncompressed content stream,
and `scan.pdf` draws one page whose only content is an image XObject. A test
asserts the boundaries those declarations imply, so a fixture and its assertion
move together.

`--check` compares content rather than bytes. Deflate is unreproducible across
zlib builds -- the appliance and the workstation encode the same members to
different bytes -- while inflate is fully specified, so a zip fixture compares
member by member and a plain fixture compares its bytes.
"""

from __future__ import annotations

import argparse
import io
import json
import sys
import zipfile
import zlib
from pathlib import Path

FIXTURE_DIRECTORY = Path(__file__).resolve().parent
# One fixed timestamp for every archive member, so a regenerated zip differs
# from its predecessor in the compressor's output alone.
ZIP_TIMESTAMP = (2026, 1, 1, 0, 0, 0)

CONTENT_TYPES_DOCX = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels"
 ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml"
 ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
"""

CONTENT_TYPES_XLSX = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels"
 ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml"
 ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
</Types>
"""

CONTENT_TYPES_PPTX = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels"
 ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/ppt/presentation.xml"
 ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
</Types>
"""

ROOT_RELATIONSHIPS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1"
 Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
 Target="{target}"/>
</Relationships>
"""

WORD_NAMESPACE = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
SPREADSHEET_NAMESPACE = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
DRAWING_NAMESPACE = "http://schemas.openxmlformats.org/drawingml/2006/main"
PRESENTATION_NAMESPACE = "http://schemas.openxmlformats.org/presentationml/2006/main"
OFFICE_RELATIONSHIP_NAMESPACE = (
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
)
PACKAGE_RELATIONSHIP_NAMESPACE = "http://schemas.openxmlformats.org/package/2006/relationships"

DOCUMENT_XML = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="{WORD_NAMESPACE}"><w:body>
<w:p><w:r><w:t>The first paragraph names the page it sits on.</w:t></w:r></w:p>
<w:p><w:r><w:t>The second paragraph closes the first page.</w:t></w:r></w:p>
<w:p><w:r><w:br w:type="page"/></w:r></w:p>
<w:p><w:r><w:t>The third paragraph opens the second page.</w:t></w:r></w:p>
</w:body></w:document>
"""

WORKBOOK_XML = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="{SPREADSHEET_NAMESPACE}" xmlns:r="{OFFICE_RELATIONSHIP_NAMESPACE}">
<sheets><sheet name="Alpha" sheetId="1" r:id="rId1"/>
<sheet name="Beta" sheetId="2" r:id="rId2"/></sheets>
</workbook>
"""

WORKBOOK_RELATIONSHIPS = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="{PACKAGE_RELATIONSHIP_NAMESPACE}">
<Relationship Id="rId1" Type="{OFFICE_RELATIONSHIP_NAMESPACE}/worksheet"
 Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="{OFFICE_RELATIONSHIP_NAMESPACE}/worksheet"
 Target="worksheets/sheet2.xml"/>
<Relationship Id="rId3" Type="{OFFICE_RELATIONSHIP_NAMESPACE}/sharedStrings"
 Target="sharedStrings.xml"/>
</Relationships>
"""

SHARED_STRINGS_XML = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="{SPREADSHEET_NAMESPACE}" count="4" uniqueCount="4">
<si><t>region</t></si><si><t>north</t></si><si><t>quarter</t></si><si><t>spring</t></si>
</sst>
"""

SHEET_ONE_XML = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="{SPREADSHEET_NAMESPACE}"><sheetData>
<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1"><v>11</v></c></row>
<row r="2"><c r="A2" t="s"><v>1</v></c><c r="B2"><v>12</v></c></row>
</sheetData></worksheet>
"""

SHEET_TWO_XML = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="{SPREADSHEET_NAMESPACE}"><sheetData>
<row r="1"><c r="A1" t="s"><v>2</v></c>
<c r="B1" t="inlineStr"><is><t>inline cell</t></is></c></row>
<row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2"><v>21</v></c></row>
</sheetData></worksheet>
"""

PRESENTATION_XML = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="{PRESENTATION_NAMESPACE}" xmlns:r="{OFFICE_RELATIONSHIP_NAMESPACE}">
<p:sldIdLst><p:sldId id="256" r:id="rId1"/><p:sldId id="257" r:id="rId2"/></p:sldIdLst>
</p:presentation>
"""


def slide_xml(title: str, body: str) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="{DRAWING_NAMESPACE}" xmlns:p="{PRESENTATION_NAMESPACE}"><p:cSld><p:spTree>
<p:sp><p:txBody><a:p><a:r><a:t>{title}</a:t></a:r></a:p></p:txBody></p:sp>
<p:sp><p:txBody><a:p><a:r><a:t>{body}</a:t></a:r></a:p></p:txBody></p:sp>
</p:spTree></p:cSld></p:sld>
"""


HEADINGS_HTML = """<!doctype html>
<html><head><title>Three sections</title><style>p { color: red; }</style></head>
<body>
<p>An opening paragraph sits above every heading.</p>
<h1>Acquisition</h1>
<p>The first section describes the acquisition.</p>
<h2>Measurement</h2>
<p>The second section describes the measurement.</p>
<script>const ignored = "script text never reaches the extraction";</script>
<h2>Disposal</h2>
<p>The third section describes the disposal.</p>
</body></html>
"""

ROWS_CSV = """region,quarter,decode_tokens_per_second
north,spring,9.46
south,spring,3.07
north,summer,2.84
"""

ROWS_TSV = "region\tquarter\tdecode_tokens_per_second\nnorth\tspring\t9.46\nsouth\tspring\t3.07\n"

NOTES_MARKDOWN = """Placement sweeps run before every campaign.

# Placement

Full Vulkan decodes 2.84 tok/s against 2.63 CPU-only.

## Fabric

The fabric state the firmware selects refuses a hard minimum.

# Depth

The registry carries the ceiling a measurement established.
"""

SAMPLE_SOURCE = """/* The submission limit the profile exports, read by the Vulkan backend. */
#include <stdint.h>

enum { MAX_NODES_PER_SUBMIT = 16 };

uint32_t submit_limit(uint32_t requested) {
    return requested < MAX_NODES_PER_SUBMIT ? requested : MAX_NODES_PER_SUBMIT;
}
"""

RECORD_JSON = {
    "checkpoint": "qwen38-2b-distill",
    "decode_tokens_per_second": 9.46,
    "backend": "vulkan",
    "arms": [{"depth": 0, "rate": 9.46}, {"depth": 4096, "rate": 8.11}],
}

PLAIN_TEXT = """The appliance serves one model at a time.
The runtime root holds every generated byte.
A measurement decides each default.
"""


def build_pdf(objects: list[bytes]) -> bytes:
    """Assemble numbered objects into a PDF with a real cross-reference table.

    The content streams stay uncompressed, so the fixture's text is legible in
    the committed bytes and its extraction rests on no filter implementation.
    """
    out = bytearray(b"%PDF-1.4\n")
    offsets: list[int] = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{number} 0 obj\n".encode("ascii") + body + b"\nendobj\n"
    start_xref = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode("ascii")
    out += b"0000000000 65535 f \n"
    for offset in offsets:
        out += f"{offset:010d} 00000 n \n".encode("ascii")
    out += (
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{start_xref}\n%%EOF\n"
    ).encode("ascii")
    return bytes(out)


def text_stream(text: str) -> bytes:
    body = f"BT /F1 12 Tf 72 720 Td ({text}) Tj ET".encode("ascii")
    length = str(len(body)).encode("ascii")
    return b"<< /Length " + length + b" >>\nstream\n" + body + b"\nendstream"


def text_pdf() -> bytes:
    page = (
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
        "/Resources << /Font << /F1 7 0 R >> >> /Contents {contents} 0 R >>"
    )
    return build_pdf(
        [
            b"<< /Type /Catalog /Pages 2 0 R >>",
            b"<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>",
            page.format(contents=4).encode("ascii"),
            text_stream("The first page carries extractable text."),
            page.format(contents=6).encode("ascii"),
            text_stream("The second page carries its own line."),
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        ]
    )


def scanned_pdf() -> bytes:
    """One page whose only content is a two-by-two image XObject.

    An extraction returns no characters for this page while the page's
    resources name an image, which is the pair the worker reports as
    `requires_ocr` rather than as an empty document.
    """
    pixels = bytes([255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 0])
    compressed = zlib.compress(pixels)
    content = b"q 200 0 0 200 100 500 cm /Im1 Do Q"
    return build_pdf(
        [
            b"<< /Type /Catalog /Pages 2 0 R >>",
            b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
            b"/Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>",
            b"<< /Length "
            + str(len(content)).encode("ascii")
            + b" >>\nstream\n"
            + content
            + b"\nendstream",
            b"<< /Type /XObject /Subtype /Image /Width 2 /Height 2 /ColorSpace /DeviceRGB "
            b"/BitsPerComponent 8 /Filter /FlateDecode /Length "
            + str(len(compressed)).encode("ascii")
            + b" >>\nstream\n"
            + compressed
            + b"\nendstream",
        ]
    )


def zip_bytes(members: list[tuple[str, bytes]]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, payload in members:
            info = zipfile.ZipInfo(name, date_time=ZIP_TIMESTAMP)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, payload)
    return buffer.getvalue()


def docx_bytes() -> bytes:
    return zip_bytes(
        [
            ("[Content_Types].xml", CONTENT_TYPES_DOCX.encode("utf-8")),
            (
                "_rels/.rels",
                ROOT_RELATIONSHIPS.format(target="word/document.xml").encode("utf-8"),
            ),
            ("word/document.xml", DOCUMENT_XML.encode("utf-8")),
        ]
    )


def xlsx_bytes() -> bytes:
    return zip_bytes(
        [
            ("[Content_Types].xml", CONTENT_TYPES_XLSX.encode("utf-8")),
            ("_rels/.rels", ROOT_RELATIONSHIPS.format(target="xl/workbook.xml").encode("utf-8")),
            ("xl/workbook.xml", WORKBOOK_XML.encode("utf-8")),
            ("xl/_rels/workbook.xml.rels", WORKBOOK_RELATIONSHIPS.encode("utf-8")),
            ("xl/sharedStrings.xml", SHARED_STRINGS_XML.encode("utf-8")),
            ("xl/worksheets/sheet1.xml", SHEET_ONE_XML.encode("utf-8")),
            ("xl/worksheets/sheet2.xml", SHEET_TWO_XML.encode("utf-8")),
        ]
    )


def pptx_bytes() -> bytes:
    first = slide_xml("Placement", "Full Vulkan wins every hybrid comparison.")
    second = slide_xml("Depth", "The registry carries the measured ceiling.")
    return zip_bytes(
        [
            ("[Content_Types].xml", CONTENT_TYPES_PPTX.encode("utf-8")),
            (
                "_rels/.rels",
                ROOT_RELATIONSHIPS.format(target="ppt/presentation.xml").encode("utf-8"),
            ),
            ("ppt/presentation.xml", PRESENTATION_XML.encode("utf-8")),
            ("ppt/slides/slide1.xml", first.encode("utf-8")),
            ("ppt/slides/slide2.xml", second.encode("utf-8")),
        ]
    )


def zip_bomb_bytes() -> bytes:
    """A DOCX-shaped archive whose one member declares eight mebibytes.

    Eight mebibytes of one repeated byte deflate to a few kibibytes, so the
    committed fixture stays small while its central directory declares a size
    the worker's uncompressed cap refuses before it opens the member.
    """
    return zip_bytes(
        [
            ("[Content_Types].xml", CONTENT_TYPES_DOCX.encode("utf-8")),
            ("_rels/.rels", ROOT_RELATIONSHIPS.format(target="word/document.xml").encode("utf-8")),
            ("word/document.xml", b"<" * (8 * 1024 * 1024)),
        ]
    )


FIXTURES: dict[str, bytes] = {
    "plain.txt": PLAIN_TEXT.encode("utf-8"),
    "notes.md": NOTES_MARKDOWN.encode("utf-8"),
    "sample.c": SAMPLE_SOURCE.encode("utf-8"),
    "record.json": (json.dumps(RECORD_JSON, indent=4) + "\n").encode("utf-8"),
    "rows.csv": ROWS_CSV.encode("utf-8"),
    "rows.tsv": ROWS_TSV.encode("utf-8"),
    "headings.html": HEADINGS_HTML.encode("utf-8"),
    "two-paragraphs.docx": docx_bytes(),
    "two-sheets.xlsx": xlsx_bytes(),
    "two-slides.pptx": pptx_bytes(),
    "text.pdf": text_pdf(),
    "scan.pdf": scanned_pdf(),
    "zip-bomb.docx": zip_bomb_bytes(),
}


def zip_members(payload: bytes) -> dict[str, bytes]:
    buffer = io.BytesIO(payload)
    with zipfile.ZipFile(buffer) as archive:
        return {name: archive.read(name) for name in sorted(archive.namelist())}


def check() -> int:
    """Compare every committed fixture against a fresh generation."""
    differences = []
    for name, payload in FIXTURES.items():
        path = FIXTURE_DIRECTORY / name
        if not path.is_file():
            differences.append(f"{name}: absent")
            continue
        committed = path.read_bytes()
        if name.endswith((".docx", ".xlsx", ".pptx")):
            if zip_members(committed) != zip_members(payload):
                differences.append(f"{name}: members differ")
        elif committed != payload:
            differences.append(f"{name}: bytes differ")
    for difference in differences:
        print(f"generate_fixtures: {difference}", file=sys.stderr)
    if differences:
        return 1
    print(f"generate_fixtures: {len(FIXTURES)} fixtures match their declaration")
    return 0


def write() -> int:
    for name, payload in FIXTURES.items():
        (FIXTURE_DIRECTORY / name).write_bytes(payload)
    print(f"generate_fixtures: wrote {len(FIXTURES)} fixtures to {FIXTURE_DIRECTORY}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="generate_fixtures.py", description="Write or check the document fixtures."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="compare the committed fixtures with this declaration instead of writing them",
    )
    arguments = parser.parse_args()
    return check() if arguments.check else write()


if __name__ == "__main__":
    raise SystemExit(main())
