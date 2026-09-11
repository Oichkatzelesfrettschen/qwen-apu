"""The conversation record every store, importer, and exporter agrees on.

A saved conversation persists whole; a temporary one holds the same shape in
memory and under `tmp/conversations/<id>/` and is never written to the
database. Credentials, grants, and session secrets have no field here, so
they cannot be persisted by construction.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

Mode = Literal["saved", "temporary"]
Role = Literal["user", "assistant", "system", "tool"]


@dataclass(frozen=True)
class AttachmentRef:
    """Metadata of an upload; the bytes live under artifacts/ or tmp/ by digest."""

    name: str
    media_type: str
    sha256: str
    byte_count: int


@dataclass(frozen=True)
class ToolEvent:
    """One proposal and its outcome; the approval itself is never stored."""

    tool_id: str
    origin: Literal["user", "model"]
    arguments_sha256: str
    outcome: Literal["proposed", "approved", "refused", "completed", "failed"]
    result_sha256: str = ""
    detail: str = ""


@dataclass(frozen=True)
class Message:
    role: Role
    content: str
    created_utc: str
    served_model: str = ""
    reasoning_shown: bool = False
    tool_events: tuple[ToolEvent, ...] = ()
    sources: tuple[str, ...] = ()
    artifacts: tuple[str, ...] = ()
    attachments: tuple[AttachmentRef, ...] = ()
    truncation_note: str = ""


@dataclass(frozen=True)
class Conversation:
    conversation_id: str
    mode: Mode
    title: str
    created_utc: str
    updated_utc: str
    messages: tuple[Message, ...] = ()
    model_switches: tuple[tuple[str, str], ...] = field(default_factory=tuple)  # (utc, model_id)
    workflow_state: str = "idle"
