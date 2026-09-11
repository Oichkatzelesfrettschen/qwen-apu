"""`browser_import.parse_export` against the shape `webui/index.html` writes.

Every fixture below is the `qwen_apu_browser_history_export` document
`docs/handoff/browser-history-format.md` defines, built from the exact
record and message shapes that file cites into `webui/index.html`:
`saveConversation` (`:4584-4590`), `rememberUserMessage` (`:4410-4426`),
`rememberAssistantMessage` (`:4428-4447`), and `rememberToolMessage`
(`:4449-4453`). The browser record carries no per-message timestamp and no
conversation `created` field, only `updated` in epoch milliseconds
(`webui/index.html:4588`), which is why every case here reads `created_utc`
back as the conversation's own `updated_utc`.
"""

from __future__ import annotations

import json

import pytest

from qwen_apu.web.browser_import import (
    EXPORT_VERSION,
    BrowserExportRefused,
    ImportReport,
    parse_export,
)


def _document(conversations: list[dict[str, object]], **extra: object) -> bytes:
    payload: dict[str, object] = {
        "qwen_apu_browser_history_export": EXPORT_VERSION,
        "conversations": conversations,
    }
    payload.update(extra)
    return json.dumps(payload).encode("utf-8")


def test_two_conversations_with_an_attachment_a_model_switch_and_reasoning() -> None:
    document = _document(
        [
            {
                "id": "conv-one",
                "title": "a picture and a question",
                "updated": 1_700_000_000_000,
                "messages": [
                    {
                        "role": "user",
                        "content": "describe this\n\n[image attachment omitted from "
                        "saved conversation: bars.png, image/png]",
                        "shown": "describe this [bars.png]",
                        "omitted_attachments": [{"name": "bars.png", "mime": "image/png"}],
                    },
                    {
                        "role": "assistant",
                        "content": "the tallest bar is JUN",
                        "model": "qwen38-2b-distill",
                        "reasoning": "the bars table names JUN as tallest",
                        "artifacts": [],
                    },
                ],
            },
            {
                "id": "conv-two",
                "title": "a model switch",
                "updated": 1_700_000_100_000,
                "messages": [
                    {"role": "user", "content": "hello", "shown": "hello"},
                    {
                        "role": "assistant",
                        "content": "hi from the 2b",
                        "model": "qwen38-2b-distill",
                        "reasoning": "",
                        "artifacts": [],
                    },
                    {"role": "user", "content": "and now?", "shown": "and now?"},
                    {
                        "role": "assistant",
                        "content": "hi from the 4b",
                        "model": "qwen38-4b-distill",
                        "reasoning": "",
                        "artifacts": [],
                    },
                ],
            },
        ]
    )

    report = parse_export(document)

    assert isinstance(report, ImportReport)
    assert len(report.conversations) == 2
    assert report.skipped == ()

    first = report.conversations[0]
    assert first.conversation_id == "conv-one"
    assert first.title == "a picture and a question"
    assert first.created_utc == first.updated_utc
    assert first.updated_utc == "2023-11-14T22:13:20.000Z"
    assert len(first.messages) == 2

    user_message = first.messages[0]
    assert user_message.role == "user"
    assert len(user_message.attachments) == 1
    attachment = user_message.attachments[0]
    assert attachment.name == "bars.png"
    assert attachment.media_type == "image/png"
    assert attachment.sha256 == ""
    assert attachment.byte_count == 0

    assistant_message = first.messages[1]
    assert assistant_message.role == "assistant"
    assert assistant_message.served_model == "qwen38-2b-distill"
    assert assistant_message.reasoning_shown is True
    assert any("reasoning text is present" in warning for warning in report.warnings)

    second = report.conversations[1]
    served_models = [
        message.served_model for message in second.messages if message.role == "assistant"
    ]
    assert served_models == ["qwen38-2b-distill", "qwen38-4b-distill"]


def test_no_per_message_timestamp_warns_once_per_conversation() -> None:
    document = _document(
        [
            {
                "id": "conv-one",
                "title": "t",
                "updated": 1_700_000_000_000,
                "messages": [{"role": "user", "content": "hi", "shown": "hi"}],
            }
        ]
    )

    report = parse_export(document)

    timestamp_warnings = [
        warning for warning in report.warnings if "no per-message timestamp" in warning
    ]
    assert len(timestamp_warnings) == 1


def test_a_tool_call_pairs_with_its_result_message() -> None:
    document = _document(
        [
            {
                "id": "conv-one",
                "title": "t",
                "updated": 1_700_000_000_000,
                "messages": [
                    {"role": "user", "content": "what time is it", "shown": "what time is it"},
                    {
                        "role": "assistant",
                        "content": "",
                        "model": "qwen38-2b-distill",
                        "reasoning": "",
                        "artifacts": [],
                        "tool_calls": [
                            {
                                "id": "call_0",
                                "type": "function",
                                "function": {"name": "clock", "arguments": "{}"},
                            }
                        ],
                    },
                    {"role": "tool", "tool_call_id": "call_0", "name": "clock", "content": "noon"},
                    {
                        "role": "assistant",
                        "content": "it is noon",
                        "model": "qwen38-2b-distill",
                        "reasoning": "",
                        "artifacts": [],
                    },
                ],
            }
        ]
    )

    report = parse_export(document)

    assert report.skipped == ()
    assistant_with_call = report.conversations[0].messages[1]
    assert len(assistant_with_call.tool_events) == 1
    event = assistant_with_call.tool_events[0]
    assert event.tool_id == "call_0"
    assert event.origin == "model"
    assert event.outcome == "completed"
    assert event.detail == "clock"
    assert event.result_sha256 != ""

    tool_message = report.conversations[0].messages[2]
    assert tool_message.role == "tool"
    assert tool_message.content == "noon"


def test_an_unknown_field_produces_a_warning_rather_than_a_silent_drop() -> None:
    document = _document(
        [
            {
                "id": "conv-one",
                "title": "t",
                "updated": 1_700_000_000_000,
                "messages": [{"role": "user", "content": "hi", "shown": "hi"}],
                "pinned": True,
            }
        ]
    )

    report = parse_export(document)

    assert len(report.conversations) == 1
    assert any("pinned" in warning for warning in report.warnings)


@pytest.mark.parametrize(
    "credential_document",
    [
        _document(
            [{"id": "c", "title": "t", "updated": 0, "messages": []}],
            bearer="s3cr3t",
        ),
        _document(
            [
                {
                    "id": "c",
                    "title": "t",
                    "updated": 0,
                    "messages": [{"role": "user", "content": "x", "api_key": "abc"}],
                }
            ]
        ),
        _document(
            [
                {
                    "id": "c",
                    "title": "t",
                    "updated": 0,
                    "messages": [{"role": "user", "content": "visit /#key=abcdef123 to sign in"}],
                }
            ]
        ),
    ],
)
def test_a_credential_shaped_document_is_refused_whole(credential_document: bytes) -> None:
    with pytest.raises(BrowserExportRefused):
        parse_export(credential_document)


def test_an_oversized_document_is_refused() -> None:
    oversized = b" " * (64 * 1024 * 1024 + 1)
    with pytest.raises(BrowserExportRefused):
        parse_export(oversized)


def test_a_malformed_conversation_is_skipped_and_the_rest_still_imports() -> None:
    document = _document(
        [
            {"id": "broken", "title": "t", "messages": []},
            {
                "id": "conv-two",
                "title": "t",
                "updated": 1_700_000_000_000,
                "messages": [{"role": "user", "content": "hi", "shown": "hi"}],
            },
        ]
    )

    report = parse_export(document)

    assert len(report.conversations) == 1
    assert report.conversations[0].conversation_id == "conv-two"
    assert len(report.skipped) == 1
    assert "broken" not in report.skipped[0]
    assert "conversations[0]" in report.skipped[0]


def test_epoch_millis_timestamp_converts_to_iso_8601_utc() -> None:
    document = _document(
        [
            {
                "id": "conv-one",
                "title": "t",
                "updated": 0,
                "messages": [{"role": "user", "content": "hi", "shown": "hi"}],
            }
        ]
    )

    report = parse_export(document)

    assert report.conversations[0].updated_utc == "1970-01-01T00:00:00.000Z"
    assert report.conversations[0].messages[0].created_utc == "1970-01-01T00:00:00.000Z"


def test_wrong_export_version_is_refused() -> None:
    payload = {"qwen_apu_browser_history_export": 2, "conversations": []}
    with pytest.raises(BrowserExportRefused):
        parse_export(json.dumps(payload).encode("utf-8"))


def test_not_json_is_refused() -> None:
    with pytest.raises(BrowserExportRefused):
        parse_export(b"not json")


def test_updated_as_an_iso_string_is_refused_rather_than_accepted() -> None:
    document = _document(
        [
            {
                "id": "conv-one",
                "title": "t",
                "updated": "2023-11-14T22:13:20Z",
                "messages": [],
            }
        ]
    )

    report = parse_export(document)

    assert report.conversations == ()
    assert len(report.skipped) == 1
    assert "numeric 'updated'" in report.skipped[0]


def test_a_message_with_an_unrecognized_role_is_skipped_not_warned() -> None:
    document = _document(
        [
            {
                "id": "conv-one",
                "title": "t",
                "updated": 1_700_000_000_000,
                "messages": [
                    {"role": "user", "content": "hi", "shown": "hi"},
                    {"role": "system", "content": "a role this reader does not carry"},
                ],
            }
        ]
    )

    report = parse_export(document)

    assert len(report.conversations) == 1
    assert len(report.conversations[0].messages) == 1
    assert len(report.skipped) == 1
    assert "conversations[0].messages[1]" in report.skipped[0]
    assert "unrecognized role" in report.skipped[0]


def test_an_attachment_missing_name_is_skipped_with_a_warning() -> None:
    document = _document(
        [
            {
                "id": "conv-one",
                "title": "t",
                "updated": 1_700_000_000_000,
                "messages": [
                    {
                        "role": "user",
                        "content": "x",
                        "shown": "x",
                        "omitted_attachments": [{"mime": "image/png"}],
                    }
                ],
            }
        ]
    )

    report = parse_export(document)

    assert report.conversations[0].messages[0].attachments == ()
    assert any("names no string 'name'" in warning for warning in report.warnings)
