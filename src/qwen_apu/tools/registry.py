"""The tool table the appliance offers, beside what executes each one.

A tool row states three facts a caller cannot infer from a name: the artifact
in this tree that executes the call, whether a human approves the call
explicitly or the model proposes it inside an already-approved boundary, and
whether that artifact exists yet. The third is what separates a tool the
appliance serves from one the roadmap names, so `GET /api/tools` answers with
the same table under both and a page renders a planned tool as planned rather
than discovering the absence at call time.

Approval follows what a call reaches rather than what it costs. A call that
leaves the machine or takes the device -- a web search, a generation --
carries `user-explicit`: one human approval mints one single-use grant over
the exact arguments the human read, which is the boundary
`qwen_apu.tools.approvals` serves. A call that stays inside a boundary a human
already approved -- reading one URL a granted search returned, reviewing an
artifact that generation produced -- carries `model-suggested`, since the
grant that admitted the first call bounds the second.

The read-only local set is `read_file`, `file_glob_search`, `grep_search`, and
AGENTS.md fixes that boundary: `--tools all` grants shell execution and file
writing to a prompt-injectable model, and a server holding that grant stays
off the LAN. The appliance launches without `--tools`, so the local rows read
as planned rather than served and each carries `user-explicit`.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum

from qwen_apu.web.http import Request, Response, Route

TOOLS_PATH = "/api/tools"


class Approval(StrEnum):
    """Which party authorizes one call."""

    USER_EXPLICIT = "user-explicit"
    MODEL_SUGGESTED = "model-suggested"


class Availability(StrEnum):
    """Whether the execution path exists in this tree."""

    SERVED = "served"
    PLANNED = "planned"


@dataclass(frozen=True)
class ToolEntry:
    """One tool, its executor, its approval grade, and its availability."""

    tool_id: str
    title: str
    lane: str
    execution_path: str
    approval: Approval
    availability: Availability
    summary: str


TOOL_TABLE: tuple[ToolEntry, ...] = (
    ToolEntry(
        tool_id="web_search",
        title="Web search",
        lane="web",
        execution_path="remote/web-mcp/server.py",
        approval=Approval.USER_EXPLICIT,
        availability=Availability.SERVED,
        summary=(
            "search_exa runs one query against the configured provider under a "
            "search-authorization grant covering the query, the domain filters, "
            "the publication window, the cached-age bound, and the result count"
        ),
    ),
    ToolEntry(
        tool_id="read_url",
        title="Read a URL",
        lane="web",
        execution_path="remote/web-mcp/server.py",
        approval=Approval.MODEL_SUGGESTED,
        availability=Availability.SERVED,
        summary=(
            "fetch_exa redeems one signed Result ID the approved search issued, "
            "so the per-search fetch allowance and the freshness policy the "
            "approval carried bound which document it reads"
        ),
    ),
    ToolEntry(
        tool_id="wikipedia_profile",
        title="Wikipedia through the SearXNG profile",
        lane="web",
        execution_path="remote/web-mcp/server.py",
        approval=Approval.USER_EXPLICIT,
        availability=Availability.SERVED,
        summary=(
            "the SearXNG provider reaches the appliance's own instance under an "
            "engine profile naming wikipedia beside bing and google, so an "
            "encyclopedia answer takes the same grant every search takes"
        ),
    ),
    ToolEntry(
        tool_id="image_interpretation",
        title="Image interpretation",
        lane="image",
        execution_path="remote/select-projector.sh",
        approval=Approval.MODEL_SUGGESTED,
        availability=Availability.SERVED,
        summary=(
            "a checkpoint paired with the projector its own directory holds reads "
            "an attached image into the language model's embedding space, so the "
            "interpretation runs inside the turn the user already sent"
        ),
    ),
    ToolEntry(
        tool_id="image_generation",
        title="Image generation",
        lane="image",
        execution_path="remote/image-mcp/server.py",
        approval=Approval.USER_EXPLICIT,
        availability=Availability.SERVED,
        summary=(
            "a qwen-image-generate-v1 grant binds the prompt digests, the seed, "
            "the aspect, and the pixel and step maxima one human approved, and "
            "the service holds the Vulkan workload lease for one job"
        ),
    ),
    ToolEntry(
        tool_id="image_review",
        title="Image review",
        lane="image",
        execution_path="remote/image-review.py",
        approval=Approval.MODEL_SUGGESTED,
        availability=Availability.SERVED,
        summary=(
            "a vision checkpoint holding no executable tool reads an artifact the "
            "approved generation produced and answers one closed verdict object; "
            "a correction it proposes takes a fresh approval of its own"
        ),
    ),
    ToolEntry(
        tool_id="documents",
        title="Documents",
        lane="documents",
        execution_path="src/qwen_apu/tools/documents.py",
        approval=Approval.USER_EXPLICIT,
        availability=Availability.PLANNED,
        summary=(
            "reading a document the user attaches belongs to the Phase 7 surface; "
            "no artifact in this tree executes it yet"
        ),
    ),
    ToolEntry(
        tool_id="calculator",
        title="Calculator",
        lane="local",
        execution_path="src/qwen_apu/tools/calculator.py",
        approval=Approval.MODEL_SUGGESTED,
        availability=Availability.PLANNED,
        summary=(
            "an arithmetic evaluator reaches neither the network nor the device, "
            "so the model proposes it inside the turn; the Phase 7 surface owns it"
        ),
    ),
    ToolEntry(
        tool_id="local_file_search",
        title="Local file search",
        lane="local",
        execution_path="llama-server --tools read_file,file_glob_search,grep_search",
        approval=Approval.USER_EXPLICIT,
        availability=Availability.PLANNED,
        summary=(
            "the read-only set is read_file, file_glob_search, and grep_search; a "
            "server holding that grant stays off the LAN, and the appliance "
            "launches without --tools, so no served preset offers it"
        ),
    ),
    ToolEntry(
        tool_id="artifact_export",
        title="Artifact export",
        lane="export",
        execution_path="src/qwen_apu/tools/export.py",
        approval=Approval.USER_EXPLICIT,
        availability=Availability.PLANNED,
        summary=(
            "writing a conversation or an artifact out of the appliance leaves the "
            "read-only boundary, so it takes an explicit approval; the Phase 7 "
            "surface owns it"
        ),
    ),
    ToolEntry(
        tool_id="code_tools",
        title="Code tools",
        lane="code",
        execution_path="llama-server --tools all",
        approval=Approval.USER_EXPLICIT,
        availability=Availability.PLANNED,
        summary=(
            "--tools all grants shell execution and file writing to a "
            "prompt-injectable model, which AGENTS.md keeps off every LAN-reaching "
            "server; no preset in this tree arms it"
        ),
    ),
)


def entry(tool_id: str) -> ToolEntry:
    """Return one row by its identifier."""
    for candidate in TOOL_TABLE:
        if candidate.tool_id == tool_id:
            return candidate
    raise KeyError(tool_id)


def served() -> tuple[ToolEntry, ...]:
    """Return the rows whose execution path exists in this tree."""
    return tuple(row for row in TOOL_TABLE if row.availability is Availability.SERVED)


def as_payload() -> dict[str, object]:
    """Return the listing `GET /api/tools` answers with."""
    return {
        "schema": "qwen.tool-registry",
        "version": 1,
        "tools": [asdict(row) for row in TOOL_TABLE],
    }


def _handle_tools(request: Request) -> Response:
    del request
    return Response.json(as_payload())


def routes() -> tuple[Route, ...]:
    """Return the registry route mounted under the gateway."""
    return (Route.make("GET", TOOLS_PATH, _handle_tools),)
