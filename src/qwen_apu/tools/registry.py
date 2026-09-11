"""The tool table the appliance offers, beside what executes each one.

A tool row states three facts a caller cannot infer from a name: the artifact
in this tree that executes the call, whether a human approves the call
explicitly or the model proposes it inside an already-approved boundary, and
whether that artifact exists yet. The third is what separates a tool the
appliance serves from one the roadmap names, and it is a property of the tree
rather than of a launch: `qwen_apu.tools.matrix` joins this table against the
ledgers and the running gateway to answer what one selected model can actually
reach, so a page renders a refusal rather than discovering it at call time.

Approval follows what a call reaches rather than what it costs. A call that
leaves the machine or takes the device -- a web search, a generation --
carries `user-explicit`: one human approval mints one single-use grant over
the exact arguments the human read, which is the boundary
`qwen_apu.tools.approvals` serves. A call that stays inside a boundary a human
already approved -- reading one URL a granted search returned, reviewing an
artifact that generation produced -- carries `model-suggested`, since the
grant that admitted the first call bounds the second.

Availability is computed for the two rows this package executes. `web_search`
and `read_url` run in `qwen_apu.tools.web` against the SearXNG instance the
resolved web profile names, so a gateway assembled without that profile mounts
no executor and both rows read as planned; the same gateway with the profile
mounted reads them as served. The remaining rows are fixed, since the artifact
that executes each one either exists in this tree or is a plan.

The read-only local set is `read_file`, `file_glob_search`, `grep_search`, and
AGENTS.md fixes that boundary: `--tools all` grants shell execution and file
writing to a prompt-injectable model, and a server holding that grant stays
off the LAN. The appliance launches without `--tools`, so the router arms none
of them; the gateway's own `src/qwen_apu/tools/files.py` serves the scoped
search over the roots a launch declares, and `code_tools` stays planned because
no preset in this tree arms it.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, replace
from enum import StrEnum


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
        execution_path="src/qwen_apu/tools/web.py",
        approval=Approval.USER_EXPLICIT,
        availability=Availability.PLANNED,
        summary=(
            "one query reaches the appliance's SearXNG instance under a "
            "search-authorization grant covering the query, the domain filters, "
            "the publication window, the cached-age bound, and the result count, "
            "and the grant's single use is spent in the ledger before the request"
        ),
    ),
    ToolEntry(
        tool_id="read_url",
        title="Read a URL",
        lane="web",
        execution_path="src/qwen_apu/tools/web.py",
        approval=Approval.MODEL_SUGGESTED,
        availability=Availability.PLANNED,
        summary=(
            "one signed Result ID the approved search issued redeems one page, so "
            "the per-search fetch allowance bounds how many of that search's "
            "results one approval reads"
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
        availability=Availability.SERVED,
        summary=(
            "an upload extracts in an owned worker process under its own CPU, address "
            "space, and wall-clock limits, and one record lands under "
            "artifacts/documents/<sha256>/ after a rename from staging"
        ),
    ),
    ToolEntry(
        tool_id="calculator",
        title="Calculator",
        lane="local",
        execution_path="src/qwen_apu/tools/calculator.py",
        approval=Approval.MODEL_SUGGESTED,
        availability=Availability.SERVED,
        summary=(
            "an arithmetic expression evaluates over a closed grammar inside the "
            "gateway process, reaching neither the network nor the device"
        ),
    ),
    ToolEntry(
        tool_id="local_file_search",
        title="Local file search",
        lane="local",
        execution_path="src/qwen_apu/tools/files.py",
        approval=Approval.USER_EXPLICIT,
        availability=Availability.SERVED,
        summary=(
            "the gateway searches the roots the launch declares and refuses a symlink "
            "escape; the appliance launches without --tools, so the router's own "
            "read_file, file_glob_search, and grep_search set stays unarmed"
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


# The rows `src/qwen_apu/tools/web.py` executes. Their availability follows
# whether that executor is mounted on this gateway, so it is computed in
# `table` rather than frozen above.
WEB_EXECUTOR_ROWS: tuple[str, ...] = ("web_search", "read_url")


def table(*, web_executor_mounted: bool = False) -> tuple[ToolEntry, ...]:
    """Return the table as this gateway serves it.

    The two web rows name `src/qwen_apu/tools/web.py`, and that module answers
    `POST /api/tools` only where the assembly resolved a web profile carrying a
    SearXNG instance, so their availability is a property of the running
    gateway rather than of the tree. A gateway that mounted no executor states
    them as planned, which is what stops a page from routing a turn onto a row
    whose first call would answer a refusal.
    """
    if not web_executor_mounted:
        return TOOL_TABLE
    return tuple(
        replace(row, availability=Availability.SERVED) if row.tool_id in WEB_EXECUTOR_ROWS else row
        for row in TOOL_TABLE
    )


def entry(tool_id: str, *, web_executor_mounted: bool = False) -> ToolEntry:
    """Return one row by its identifier."""
    for candidate in table(web_executor_mounted=web_executor_mounted):
        if candidate.tool_id == tool_id:
            return candidate
    raise KeyError(tool_id)


def served(*, web_executor_mounted: bool = False) -> tuple[ToolEntry, ...]:
    """Return the rows whose execution path this gateway actually reaches."""
    return tuple(
        row
        for row in table(web_executor_mounted=web_executor_mounted)
        if row.availability is Availability.SERVED
    )


def as_payload(*, web_executor_mounted: bool = False) -> dict[str, object]:
    """Return the tool identity table, which carries no per-model state.

    `qwen_apu.tools.matrix` owns `GET /api/tools` and joins this table against
    the ledgers and the launch, so this function answers what a tool is while
    that module answers what it does for one selection. `web_executor_mounted`
    is the one launch fact the identity table reads, because the artifact that
    executes the two web rows is mounted rather than fixed by the tree.
    """
    return {
        "schema": "qwen.tool-registry",
        "version": 1,
        "tools": [asdict(row) for row in table(web_executor_mounted=web_executor_mounted)],
    }
