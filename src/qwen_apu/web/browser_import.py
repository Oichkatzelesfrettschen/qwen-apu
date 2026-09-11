"""Read the browser's saved conversations into `history_model` records.

`docs/handoff/browser-history-format.md` is the authority this module reads
against: the exact stored shape of a `qwen-apu-conversations` IndexedDB
record, the `localStorage` fallback of the same shape, and the
`qwen_apu_browser_history_export` document this module defines because
`webui/index.html` emits no export of its own. A conversation record there is
already a projection -- role, content, the served model id, tool call ids and
arguments, and an artifact's digest, provenance, seed, and geometry -- with no
broker grant, session secret, or API key inside it
(`webui/index.html:4091-4099`). This module adds one more refusal on top of
that projection: a document carrying a credential-shaped key or a string
matching the page's `#key=<bearer>` fragment pattern is not a conversation
export and is refused whole rather than imported with the credential
stripped, because a partial refusal risks importing a document a credential
leak already compromised.

Every message the browser wrote carries no timestamp of its own; only the
conversation-level `updated` field does (`webui/index.html:4588`). This
module assigns every message in a conversation that conversation's `updated`
instant as `created_utc` and records the substitution as a warning, once per
conversation, rather than inventing a per-message time the source never
recorded. The same absence rules out `Conversation.model_switches`: the
source names each assistant message's own served model but no instant a
switch happened at, so this module leaves `model_switches` empty rather than
fabricate a timestamp for it, and each message's `served_model` field alone
carries the history a caller needs to reconstruct which model answered when.

A user entry's `shown` field is what `restoredUserText`
(`webui/index.html:4735-4751`) prefers for the on-screen log, built from the
typed prompt plus an attachment name list; `restoreTranscript`
(`webui/index.html:4767`) uses the sibling `content` field to rebuild the
model-facing transcript instead. This module reads `content`, the field the
source already treats as canonical, and drops `shown` without a warning
because it is a known, display-only derivative of `content` rather than
information found nowhere else in the record.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, Literal

from qwen_apu.web.history_model import AttachmentRef, Conversation, Message, ToolEvent

MAX_DOCUMENT_BYTES = 64 * 1024 * 1024

EXPORT_VERSION = 1

# Substrings a normalized (lowercased, non-alphanumeric stripped) key or
# string is checked against. "api_key" and "apiKey" both normalize to
# "apikey", so one term covers both spellings the page uses
# (`webui/index.html:371` writes `qwen-apu-api-key`, the in-memory variable is
# `apiKey`).
CREDENTIAL_TERMS = ("bearer", "token", "secret", "grant", "apikey", "cookie")

# The one-time pairing fragment `webui/index.html:385` reads, `#key=<bearer>`.
# A string carrying this pattern anywhere in the document is a credential a
# user pasted or a page copied verbatim, never conversation content.
FRAGMENT_KEY_PREFIX = "#key="

KNOWN_TOP_LEVEL_KEYS = frozenset(
    {"qwen_apu_browser_history_export", "exported_utc", "conversations"}
)
KNOWN_CONVERSATION_KEYS = frozenset({"id", "title", "updated", "messages"})
KNOWN_USER_MESSAGE_KEYS = frozenset({"role", "content", "shown", "omitted_attachments"})
KNOWN_ASSISTANT_MESSAGE_KEYS = frozenset(
    {"role", "content", "model", "reasoning", "artifacts", "tool_calls"}
)
KNOWN_TOOL_MESSAGE_KEYS = frozenset({"role", "tool_call_id", "name", "content"})
KNOWN_OMITTED_ATTACHMENT_KEYS = frozenset({"name", "mime"})


@dataclass(frozen=True)
class ImportReport:
    """Every conversation this document yielded, and what the read noticed.

    `warnings` names a field or a substitution the source document carried
    that this module did not drop silently: an unrecognized key, a missing
    per-message timestamp. `skipped` names one conversation or message this
    module refused individually, with the reason, while the rest of the
    document still imports; a whole-document refusal (an oversized document,
    a credential-shaped key) raises instead, because nothing in the document
    is then trustworthy enough to import part of.
    """

    conversations: tuple[Conversation, ...]
    warnings: tuple[str, ...]
    skipped: tuple[str, ...]


class BrowserExportRefused(ValueError):
    """The document as a whole is refused; no part of it is imported."""


def parse_export(document: bytes) -> ImportReport:
    """Convert one `qwen_apu_browser_history_export` document into records.

    Raises `BrowserExportRefused` for a defect that taints the whole
    document: an oversized body, invalid JSON, the wrong export version, a
    credential-shaped key, or a string matching the page's fragment-key
    pattern anywhere in the structure. A defect scoped to one conversation or
    one message is instead recorded in the returned report's `skipped` list
    and the rest of the document still imports.
    """
    if len(document) > MAX_DOCUMENT_BYTES:
        raise BrowserExportRefused(
            f"the document is {len(document)} bytes, over the {MAX_DOCUMENT_BYTES}-byte bound"
        )
    try:
        payload = json.loads(document.decode("utf-8"))
    except UnicodeDecodeError as error:
        raise BrowserExportRefused(f"the document is not UTF-8: {error}") from error
    except json.JSONDecodeError as error:
        raise BrowserExportRefused(f"the document is not valid JSON: {error}") from error

    _refuse_credential_shapes(payload, path="$")

    if not isinstance(payload, dict):
        raise BrowserExportRefused("the document's top level is not a JSON object")
    version = payload.get("qwen_apu_browser_history_export")
    if version != EXPORT_VERSION:
        raise BrowserExportRefused(
            "the document names export version "
            f"{version!r}; this reader accepts version {EXPORT_VERSION}"
        )
    raw_conversations = payload.get("conversations")
    if not isinstance(raw_conversations, list):
        raise BrowserExportRefused("the document names no 'conversations' array")

    warnings: list[str] = []
    skipped: list[str] = []
    warnings.extend(
        f"the document carries an unrecognized top-level field '{key}'"
        for key in payload
        if key not in KNOWN_TOP_LEVEL_KEYS
    )

    conversations: list[Conversation] = []
    for index, raw_conversation in enumerate(raw_conversations):
        label = f"conversations[{index}]"
        try:
            conversation, conversation_warnings, conversation_skipped = _parse_conversation(
                raw_conversation, label
            )
        except _SkipConversation as skip:
            skipped.append(f"{label}: {skip}")
            continue
        conversations.append(conversation)
        warnings.extend(conversation_warnings)
        skipped.extend(conversation_skipped)

    return ImportReport(
        conversations=tuple(conversations),
        warnings=tuple(warnings),
        skipped=tuple(skipped),
    )


class _SkipConversation(Exception):
    """One conversation record is malformed; the rest of the document reads on."""


def _parse_conversation(raw: Any, label: str) -> tuple[Conversation, list[str], list[str]]:
    if not isinstance(raw, dict):
        raise _SkipConversation("is not a JSON object")
    conversation_id = raw.get("id")
    if not isinstance(conversation_id, str) or not conversation_id:
        raise _SkipConversation("names no string 'id'")
    updated = raw.get("updated")
    if not isinstance(updated, int | float) or isinstance(updated, bool):
        raise _SkipConversation("names no numeric 'updated' epoch-millisecond field")
    raw_messages = raw.get("messages")
    if not isinstance(raw_messages, list):
        raise _SkipConversation("names no 'messages' array")

    updated_utc = _epoch_millis_to_iso(updated)
    title = raw.get("title")
    if not isinstance(title, str) or not title:
        title = "untitled"

    warnings = [
        f"{label}: unrecognized field '{key}'" for key in raw if key not in KNOWN_CONVERSATION_KEYS
    ]
    warnings.append(
        f"{label}: the browser record carries no per-message timestamp; every "
        f"message's created_utc is set to the conversation's own updated_utc "
        f"({updated_utc})"
    )

    messages: list[Message] = []
    skipped: list[str] = []
    for index, raw_message in enumerate(raw_messages):
        message_label = f"{label}.messages[{index}]"
        message, message_warnings = _parse_message(
            raw_message, message_label, updated_utc, raw_messages[index + 1 :]
        )
        if message is None:
            skipped.append(f"{message_label}: {message_warnings[0]}")
            continue
        messages.append(message)
        warnings.extend(message_warnings)

    conversation = Conversation(
        conversation_id=conversation_id,
        mode="saved",
        title=title,
        created_utc=updated_utc,
        updated_utc=updated_utc,
        messages=tuple(messages),
    )
    return conversation, warnings, skipped


def _parse_message(
    raw: Any, label: str, created_utc: str, later_raw_messages: list[Any]
) -> tuple[Message | None, list[str]]:
    if not isinstance(raw, dict):
        return None, ["is not a JSON object"]
    role = raw.get("role")
    if role == "user":
        return _parse_user_message(raw, label, created_utc)
    if role == "assistant":
        return _parse_assistant_message(raw, label, created_utc, later_raw_messages)
    if role == "tool":
        return _parse_tool_message(raw, label, created_utc)
    return None, [f"names an unrecognized role {role!r}"]


def _parse_user_message(
    raw: dict[str, Any], label: str, created_utc: str
) -> tuple[Message | None, list[str]]:
    content = raw.get("content")
    if not isinstance(content, str):
        return None, ["names no string 'content'"]
    warnings = [
        f"{label}: unrecognized field '{key}'" for key in raw if key not in KNOWN_USER_MESSAGE_KEYS
    ]
    attachments = _parse_omitted_attachments(raw.get("omitted_attachments"), label, warnings)
    message = Message(
        role="user",
        content=content,
        created_utc=created_utc,
        attachments=attachments,
    )
    return message, warnings


def _parse_omitted_attachments(
    raw: Any, label: str, warnings: list[str]
) -> tuple[AttachmentRef, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        warnings.append(f"{label}: 'omitted_attachments' is not an array; ignored")
        return ()
    attachments: list[AttachmentRef] = []
    for index, entry in enumerate(raw):
        entry_label = f"{label}.omitted_attachments[{index}]"
        if not isinstance(entry, dict):
            warnings.append(f"{entry_label}: is not a JSON object; skipped")
            continue
        name = entry.get("name")
        mime = entry.get("mime")
        if not isinstance(name, str) or not name:
            warnings.append(f"{entry_label}: names no string 'name'; skipped")
            continue
        if not isinstance(mime, str):
            mime = ""
        warnings.extend(
            f"{entry_label}: unrecognized field '{key}'"
            for key in entry
            if key not in KNOWN_OMITTED_ATTACHMENT_KEYS
        )
        # The browser never stores the image's bytes or a digest of them
        # (`webui/index.html:3953-3957`), so sha256 and byte_count carry no
        # source value; both stay at the type's zero value rather than a
        # fabricated one.
        attachments.append(AttachmentRef(name=name, media_type=mime, sha256="", byte_count=0))
    return tuple(attachments)


def _parse_assistant_message(
    raw: dict[str, Any], label: str, created_utc: str, later_raw_messages: list[Any]
) -> tuple[Message | None, list[str]]:
    content = raw.get("content")
    if not isinstance(content, str):
        return None, ["names no string 'content'"]
    warnings = [
        f"{label}: unrecognized field '{key}'"
        for key in raw
        if key not in KNOWN_ASSISTANT_MESSAGE_KEYS
    ]
    served_model = raw.get("model")
    if not isinstance(served_model, str):
        served_model = ""
    reasoning = raw.get("reasoning")
    reasoning_shown = isinstance(reasoning, str) and bool(reasoning)
    if reasoning_shown:
        warnings.append(
            f"{label}: reasoning text is present in the source; history_model.Message "
            "retains only reasoning_shown, so the text itself is dropped"
        )
    tool_events = _parse_tool_calls(raw.get("tool_calls"), label, later_raw_messages, warnings)
    artifacts = _parse_artifact_digests(raw.get("artifacts"), label, warnings)
    message = Message(
        role="assistant",
        content=content,
        created_utc=created_utc,
        served_model=served_model,
        reasoning_shown=reasoning_shown,
        tool_events=tool_events,
        artifacts=artifacts,
    )
    return message, warnings


def _parse_tool_calls(
    raw: Any, label: str, later_raw_messages: list[Any], warnings: list[str]
) -> tuple[ToolEvent, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        warnings.append(f"{label}: 'tool_calls' is not an array; ignored")
        return ()
    events: list[ToolEvent] = []
    for index, call in enumerate(raw):
        call_label = f"{label}.tool_calls[{index}]"
        if not isinstance(call, dict):
            warnings.append(f"{call_label}: is not a JSON object; skipped")
            continue
        call_id = call.get("id")
        function = call.get("function")
        if not isinstance(call_id, str) or not call_id or not isinstance(function, dict):
            warnings.append(f"{call_label}: names no string 'id' and 'function' object; skipped")
            continue
        name = function.get("name")
        name = name if isinstance(name, str) else ""
        arguments = function.get("arguments")
        arguments_text = arguments if isinstance(arguments, str) else json.dumps(arguments)
        outcome, result_sha256 = _tool_call_outcome(call_id, later_raw_messages)
        events.append(
            ToolEvent(
                tool_id=call_id,
                origin="model",
                arguments_sha256=_sha256_hex(arguments_text),
                outcome=outcome,
                result_sha256=result_sha256,
                detail=name,
            )
        )
    return tuple(events)


def _tool_call_outcome(
    call_id: str, later_raw_messages: list[Any]
) -> tuple[Literal["proposed", "completed"], str]:
    for raw_message in later_raw_messages:
        if (
            isinstance(raw_message, dict)
            and raw_message.get("role") == "tool"
            and raw_message.get("tool_call_id") == call_id
        ):
            result_content = raw_message.get("content")
            result_text = result_content if isinstance(result_content, str) else ""
            return "completed", _sha256_hex(result_text)
    return "proposed", ""


def _parse_artifact_digests(raw: Any, label: str, warnings: list[str]) -> tuple[str, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        warnings.append(f"{label}: 'artifacts' is not an array; ignored")
        return ()
    digests: list[str] = []
    descriptive_keys = {"provenanceUrl", "prompt", "seed", "width", "height", "steps", "profile"}
    for index, entry in enumerate(raw):
        entry_label = f"{label}.artifacts[{index}]"
        if not isinstance(entry, dict):
            warnings.append(f"{entry_label}: is not a JSON object; skipped")
            continue
        sha256 = entry.get("sha256")
        reference = entry.get("reference")
        identifier = sha256 if isinstance(sha256, str) and sha256 else reference
        if not isinstance(identifier, str) or not identifier:
            warnings.append(f"{entry_label}: names no string 'sha256' or 'reference'; skipped")
            continue
        digests.append(identifier)
        if descriptive_keys & entry.keys():
            warnings.append(
                f"{entry_label}: history_model.Message.artifacts is a plain digest tuple; "
                f"provenance, prompt, and geometry fields on this artifact are dropped"
            )
    return tuple(digests)


def _sha256_hex(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _parse_tool_message(
    raw: dict[str, Any], label: str, created_utc: str
) -> tuple[Message | None, list[str]]:
    content = raw.get("content")
    if not isinstance(content, str):
        return None, ["names no string 'content'"]
    warnings = [
        f"{label}: unrecognized field '{key}'" for key in raw if key not in KNOWN_TOOL_MESSAGE_KEYS
    ]
    message = Message(role="tool", content=content, created_utc=created_utc)
    return message, warnings


def _epoch_millis_to_iso(epoch_millis: float) -> str:
    return (
        datetime.fromtimestamp(epoch_millis / 1000.0, tz=UTC)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def _refuse_credential_shapes(node: Any, path: str) -> None:
    """Walk the whole document and refuse a credential-shaped key or string.

    This runs ahead of every structural check because a document that fails
    this check is refused whole regardless of whether it otherwise parses as
    a conversation export: `docs/handoff/browser-history-format.md` names the
    credential list this checks against and the `#key=<bearer>` fragment
    pattern `webui/index.html:385` reads.
    """
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(key, str) and _looks_like_credential_key(key):
                raise BrowserExportRefused(
                    f"the document names a credential-shaped key '{key}' at {path}; refused whole"
                )
            _refuse_credential_shapes(value, f"{path}.{key}")
        return
    if isinstance(node, list):
        for index, entry in enumerate(node):
            _refuse_credential_shapes(entry, f"{path}[{index}]")
        return
    if isinstance(node, str) and FRAGMENT_KEY_PREFIX in node.lower():
        raise BrowserExportRefused(
            f"a string at {path} matches the page's fragment-key pattern "
            f"'{FRAGMENT_KEY_PREFIX}'; refused whole"
        )


def _looks_like_credential_key(key: str) -> bool:
    normalized = "".join(character for character in key.lower() if character.isalnum())
    return any(term in normalized for term in CREDENTIAL_TERMS)
