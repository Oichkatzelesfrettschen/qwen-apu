"""A conversation's whole life, over a real gateway on a temporary runtime root.

Every test here assembles `qwen_apu.web.assemble.assemble` against its own
`QWEN_HOME`, laid out the way `RuntimePaths.lay_out` lays out a fresh one, so
each test owns a database, a `tmp/conversations/` tree, and an artifact store
no other test's rows or bytes reach. The gateway binds a free loopback port
picked once and passed in explicitly, since `assemble` refuses `port=0`: the
origin it names is the one the session cookie and the CORS allowlist bind to,
so a caller states it rather than letting the OS choose after the fact.

`docs/handoff/python-control-plane.md`'s Phase 6 section is the map this file
exercises: the SQLite-backed saved store, the in-memory-plus-scratch-directory
temporary store, and the export/import document both read and write.
"""

from __future__ import annotations

import json
import os
import shutil
import socket
import threading
from collections.abc import Iterator
from http.client import HTTPConnection, HTTPResponse
from pathlib import Path

import pytest

from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.tools import documents
from qwen_apu.web import assemble as gateway_assembly
from qwen_apu.web import browser_import
from qwen_apu.web import conversations as conversations_module
from qwen_apu.web.history import ConversationStore, UnknownConversation
from qwen_apu.web.history_model import Message

TREE = Path(__file__).resolve().parents[1]
EXCHANGE_DEADLINE_SECONDS = 20.0


@pytest.fixture(autouse=True)
def _restore_process_umask() -> Iterator[None]:
    """Undo the umask `qwen_apu.tools.ledger.Ledger.__init__` leaves set.

    `Ledger.__init__` runs `os.umask(0o077)` and never restores it, because
    the mode it buys belongs to the rollback journal SQLite creates lazily at
    write time rather than at open time; every test here assembles a gateway,
    and a gateway builds one `Ledger`. `os.umask` is process-wide and this
    file is the first in the suite to call `assemble()` at all, so without
    this fixture the leaked `0o077` reaches whichever test happens to run
    after this module in the same pytest process and narrows every mode it
    asserts on a freshly created file.
    """
    previous = os.umask(0o022)
    os.umask(previous)
    yield
    os.umask(previous)


def _runtime_paths(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> RuntimePaths:
    monkeypatch.setenv("QWEN_HOME", str(tmp_path / "root"))
    paths = RuntimePaths.resolve(TREE)
    paths.lay_out()
    signing_key = paths["qwen_home_web_token_key"]
    signing_key.write_text("conversation-lifecycle-signing-key\n", encoding="utf-8")
    signing_key.chmod(0o600)
    return paths


def _free_port() -> int:
    """A port free at this instant; `assemble.assemble` requires an explicit one."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])


class Fixture:
    """One running gateway plus the pairing code and cookie a test needs."""

    def __init__(self, gateway: gateway_assembly.Gateway, session: object) -> None:
        self.gateway = gateway
        self.session = session
        self.thread = threading.Thread(target=gateway.serve_forever)
        self.thread.start()

    def connection(self) -> HTTPConnection:
        return HTTPConnection("127.0.0.1", self.gateway.port, timeout=EXCHANGE_DEADLINE_SECONDS)

    def stop(self) -> None:
        self.gateway.shutdown()
        self.thread.join(timeout=EXCHANGE_DEADLINE_SECONDS)


def _start_gateway(paths: RuntimePaths, static_root: Path) -> Fixture:
    request = gateway_assembly.GatewayRequest(
        port=_free_port(),
        static_root=static_root,
        web_profile="web-open",
        provider="searxng",
    )
    gateway, session = gateway_assembly.assemble(paths, request)
    return Fixture(gateway, session)


def _static_root(tmp_path: Path) -> Path:
    root = tmp_path / "static"
    root.mkdir(exist_ok=True)
    return root


def _exchange(
    fixture: Fixture,
    method: str,
    path: str,
    *,
    body: dict[str, object] | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[HTTPResponse, bytes]:
    connection = fixture.connection()
    encoded = json.dumps(body).encode("utf-8") if body is not None else None
    sent_headers = dict(headers or {})
    if encoded is not None:
        sent_headers.setdefault("Content-Type", "application/json")
    try:
        connection.request(method, path, body=encoded, headers=sent_headers)
        response = connection.getresponse()
        return response, response.read()
    finally:
        connection.close()


def _pair(fixture: Fixture) -> str:
    """Start pairing, complete it, and return the session cookie."""
    code = fixture.session.start()  # type: ignore[attr-defined]
    response, _ = _exchange(fixture, "POST", "/api/pair", body={"code": code})
    assert response.status == 200
    raw = response.getheader("Set-Cookie") or ""
    return raw.split(";", 1)[0]


def _json(body: bytes) -> dict[str, object]:
    return dict(json.loads(body))


# ---------------------------------------------------------------------------
# 1. Restart drops the temporary conversation; the saved one survives.
# ---------------------------------------------------------------------------


def test_restart_keeps_the_saved_conversation_and_drops_the_temporary_one(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _runtime_paths(tmp_path, monkeypatch)
    static_root = _static_root(tmp_path)

    first = _start_gateway(paths, static_root)
    try:
        cookie = _pair(first)

        response, body = _exchange(
            first,
            "POST",
            conversations_module.CONVERSATIONS_PATH,
            body={"mode": "saved", "title": "keeper"},
            headers={"Cookie": cookie},
        )
        assert response.status == 201
        saved_id = _json(body)["conversation_id"]
        response, _ = _exchange(
            first,
            "POST",
            f"{conversations_module.CONVERSATIONS_PATH}/{saved_id}/messages",
            body={
                "role": "user",
                "content": "remember this",
                "created_utc": "2026-01-01T00:00:00Z",
            },
            headers={"Cookie": cookie},
        )
        assert response.status == 201

        response, body = _exchange(
            first,
            "POST",
            conversations_module.CONVERSATIONS_PATH,
            body={"mode": "temporary", "title": "scratch"},
            headers={"Cookie": cookie},
        )
        assert response.status == 201
        temporary_id = _json(body)["conversation_id"]
        response, _ = _exchange(
            first,
            "POST",
            f"{conversations_module.CONVERSATIONS_PATH}/{temporary_id}/messages",
            body={"role": "user", "content": "throwaway", "created_utc": "2026-01-01T00:00:00Z"},
            headers={"Cookie": cookie},
        )
        assert response.status == 201

        # A temporary attachment's bytes, staged the way an upload would stage
        # them, under the same scratch directory the registry owns.
        temporary_directory = (
            paths["qwen_home_tmp"]
            / conversations_module.TEMPORARY_DIRECTORY_NAME
            / str(temporary_id)
        )
        assert temporary_directory.is_dir()
        (temporary_directory / "upload.bin").write_bytes(b"ephemeral attachment bytes")
    finally:
        first.stop()

    # The gateway's shutdown ran every temporary conversation's teardown, so
    # the directory is gone before a second process ever opens the root.
    assert not temporary_directory.exists()

    second = _start_gateway(paths, static_root)
    try:
        cookie = _pair(second)
        response, body = _exchange(
            second, "GET", conversations_module.CONVERSATIONS_PATH, headers={"Cookie": cookie}
        )
        assert response.status == 200
        listed = {entry["conversation_id"]: entry for entry in _json(body)["conversations"]}
        assert saved_id in listed
        assert listed[saved_id]["message_count"] == 1
        assert temporary_id not in listed

        response, body = _exchange(
            second,
            "GET",
            f"{conversations_module.CONVERSATIONS_PATH}/{saved_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 200
        record = _json(body)
        assert len(record["messages"]) == 1
        assert record["messages"][0]["content"] == "remember this"

        response, _ = _exchange(
            second,
            "GET",
            f"{conversations_module.CONVERSATIONS_PATH}/{temporary_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 404
    finally:
        second.stop()


# ---------------------------------------------------------------------------
# 2. Export, delete, re-import: the record survives apart from regenerated
#    fields.
# ---------------------------------------------------------------------------


def test_export_delete_import_reproduces_the_record(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _runtime_paths(tmp_path, monkeypatch)
    fixture = _start_gateway(paths, _static_root(tmp_path))
    try:
        cookie = _pair(fixture)
        response, body = _exchange(
            fixture,
            "POST",
            conversations_module.CONVERSATIONS_PATH,
            body={"mode": "saved", "title": "roundtrip"},
            headers={"Cookie": cookie},
        )
        assert response.status == 201
        conversation_id = _json(body)["conversation_id"]

        response, _ = _exchange(
            fixture,
            "POST",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}/messages",
            body={
                "role": "user",
                "content": "what tool did you call",
                "created_utc": "2026-01-01T00:00:00Z",
            },
            headers={"Cookie": cookie},
        )
        assert response.status == 201
        response, _ = _exchange(
            fixture,
            "POST",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}/messages",
            body={
                "role": "assistant",
                "content": "the calculator",
                "created_utc": "2026-01-01T00:00:05Z",
                "served_model": "qwen38-2b-distill",
                "reasoning_shown": True,
                "sources": ["https://example.invalid/doc"],
                "artifacts": ["a" * 64],
                "tool_events": [
                    {
                        "tool_id": "call-1",
                        "origin": "model",
                        "arguments_sha256": "b" * 64,
                        "outcome": "completed",
                        "result_sha256": "c" * 64,
                        "detail": "calculator",
                    }
                ],
                "attachments": [
                    {
                        "name": "note.txt",
                        "media_type": "text/plain",
                        "sha256": "d" * 64,
                        "byte_count": 12,
                    }
                ],
                "truncation_note": "context truncated at 4096 tokens",
            },
            headers={"Cookie": cookie},
        )
        assert response.status == 201

        # Two fields the routes carry no writer for: the store itself carries
        # them, and the same database file backs the gateway's own connection.
        store = ConversationStore(paths["qwen_home_state"])
        try:
            store.record_model_switch(str(conversation_id), "qwen38-2b-distill")
            store.record_observation(str(conversation_id), "checkpoint", "manual checkpoint")
        finally:
            store.close()

        response, exported_before = _exchange(
            fixture,
            "GET",
            conversations_module.EXPORT_PATH,
            headers={"Cookie": cookie},
        )
        assert response.status == 200
        document_before = _json(exported_before)

        response, _ = _exchange(
            fixture,
            "DELETE",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 200

        response, _ = _exchange(
            fixture,
            "GET",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 404

        response, imported_body = _exchange(
            fixture,
            "POST",
            conversations_module.IMPORT_PATH,
            body=document_before,
            headers={"Cookie": cookie},
        )
        assert response.status == 201
        assert _json(imported_body)["imported"] == [conversation_id]

        response, exported_after = _exchange(
            fixture,
            "GET",
            conversations_module.EXPORT_PATH,
            headers={"Cookie": cookie},
        )
        assert response.status == 200
        document_after = _json(exported_after)

        # `exported_utc` is the one field the format declares regenerated on
        # every export; every conversation record underneath is unchanged.
        assert document_before["document_version"] == document_after["document_version"]
        assert document_before["conversations"] == document_after["conversations"]
    finally:
        fixture.stop()


# ---------------------------------------------------------------------------
# 3. One browser IndexedDB export document, in the documented shape.
# ---------------------------------------------------------------------------


def test_browser_export_document_imports_with_warnings_for_unknown_fields(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _runtime_paths(tmp_path, monkeypatch)
    document = {
        "qwen_apu_browser_history_export": 1,
        "exported_utc": "2026-09-11T00:00:00Z",
        "unexpected_top_level": "ignored but noted",
        "conversations": [
            {
                "id": "c1a2b3",
                "title": "a short heading",
                "updated": 1757548800000,
                "future_field": "carried by no reader yet",
                "messages": [
                    {
                        "role": "user",
                        "content": "draw a chart",
                        "shown": "draw a chart [bars.png]",
                        "omitted_attachments": [{"name": "bars.png", "mime": "image/png"}],
                    },
                    {
                        "role": "assistant",
                        "content": "here is the tool call",
                        "model": "qwen38-2b-distill",
                        "reasoning": "the user asked for a chart",
                        "tool_calls": [
                            {
                                "id": "call-1",
                                "type": "function",
                                "function": {"name": "calculator", "arguments": "{}"},
                            }
                        ],
                        "artifacts": [{"reference": "e" * 64, "seed": 7}],
                    },
                    {
                        "role": "tool",
                        "tool_call_id": "call-1",
                        "name": "calculator",
                        "content": "42",
                    },
                ],
            }
        ],
    }
    raw = json.dumps(document).encode("utf-8")

    report = browser_import.parse_export(raw)
    assert len(report.conversations) == 1
    assert not report.skipped
    joined_warnings = "\n".join(report.warnings)
    assert "unrecognized top-level field 'unexpected_top_level'" in joined_warnings
    assert "unrecognized field 'future_field'" in joined_warnings
    assert "no per-message timestamp" in joined_warnings
    assert "reasoning text is present" in joined_warnings
    assert "provenance, prompt, and geometry fields" in joined_warnings

    store = ConversationStore(paths["qwen_home_state"])
    try:
        imported_ids = []
        for conversation in report.conversations:
            store.create(
                conversation.title, mode="saved", conversation_id=conversation.conversation_id
            )
            for message in conversation.messages:
                store.append_message(conversation.conversation_id, message)
            imported_ids.append(conversation.conversation_id)

        assert imported_ids == ["c1a2b3"]
        record = store.get("c1a2b3")
        assert record.title == "a short heading"
        assert [message.role for message in record.messages] == ["user", "assistant", "tool"]
        user_message = record.messages[0]
        assert user_message.content == "draw a chart"
        assert user_message.attachments[0].name == "bars.png"
        assistant_message = record.messages[1]
        assert assistant_message.served_model == "qwen38-2b-distill"
        assert assistant_message.reasoning_shown is True
        assert assistant_message.artifacts == ("e" * 64,)
        assert len(assistant_message.tool_events) == 1
        event = assistant_message.tool_events[0]
        assert event.tool_id == "call-1"
        assert event.outcome == "completed"  # the trailing tool row names its result
        tool_message = record.messages[2]
        assert tool_message.content == "42"
    finally:
        store.close()


# ---------------------------------------------------------------------------
# 4. Attachment and artifact availability, honest rather than fatal.
# ---------------------------------------------------------------------------


def test_a_dangling_attachment_reads_unavailable_rather_than_crash(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A message naming a digest the document store never received still reads.

    `GET /api/conversations/<id>` decorates each attachment with `available`,
    computed fresh from `<artifacts>/documents/<sha256>/<sha256>.json` at read
    time rather than from a flag `POST .../messages` wrote once, so a digest
    nothing backs answers `available: false` on the message and the same
    clean 404 on the routes that would serve its bytes.
    """
    paths = _runtime_paths(tmp_path, monkeypatch)
    fixture = _start_gateway(paths, _static_root(tmp_path))
    try:
        cookie = _pair(fixture)
        response, body = _exchange(
            fixture,
            "POST",
            conversations_module.CONVERSATIONS_PATH,
            body={"mode": "saved", "title": "dangling"},
            headers={"Cookie": cookie},
        )
        assert response.status == 201
        conversation_id = _json(body)["conversation_id"]

        missing_digest = "f" * 64
        response, _ = _exchange(
            fixture,
            "POST",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}/messages",
            body={
                "role": "user",
                "content": "see the attached file",
                "created_utc": "2026-01-01T00:00:00Z",
                "attachments": [
                    {
                        "name": "gone.txt",
                        "media_type": "text/plain",
                        "sha256": missing_digest,
                        "byte_count": 4,
                    }
                ],
                "artifacts": [missing_digest],
            },
            headers={"Cookie": cookie},
        )
        assert response.status == 201

        response, body = _exchange(
            fixture,
            "GET",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 200
        attachment = _json(body)["messages"][0]["attachments"][0]  # type: ignore[index]
        assert attachment["sha256"] == missing_digest
        assert attachment["available"] is False

        # The document store answers a clean, JSON-carrying refusal for a
        # digest it never received, rather than raising past the route.
        response, body = _exchange(
            fixture,
            "GET",
            f"/api/documents/{missing_digest}",
            headers={"Cookie": cookie},
        )
        assert response.status == 404
        assert "error" in _json(body)

        # The image artifact listener answers the same way for a digest no
        # publication marker names.
        response, body = _exchange(
            fixture,
            "GET",
            f"/api/artifacts/{missing_digest}.png",
            headers={"Cookie": cookie},
        )
        assert response.status == 404
        assert "error" in _json(body)
    finally:
        fixture.stop()


def test_an_attachments_availability_is_computed_fresh_across_restart_and_loss(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A real attachment stays available across a restart and flips honestly on loss.

    `available` is not a flag `POST .../messages` freezes at append time: it
    is read back from the document store on every `GET`, so it survives a
    stop-and-reassemble of the gateway and still answers correctly the moment
    the backing bytes are removed out of band -- the retention sweep case
    `tools/documents.py` describes, reproduced here by deleting the store
    directory directly.
    """
    paths = _runtime_paths(tmp_path, monkeypatch)
    static_root = _static_root(tmp_path)

    document_service = documents.DocumentService(
        documents.DocumentSettings(
            artifacts=paths["qwen_home_artifacts"], tmp=paths["qwen_home_tmp"]
        )
    )
    source = tmp_path / "note.txt"
    source.write_text("a real attachment's bytes", encoding="utf-8")
    record = document_service.extract(source, "text/plain", filename="note.txt")

    first = _start_gateway(paths, static_root)
    try:
        cookie = _pair(first)
        response, body = _exchange(
            first,
            "POST",
            conversations_module.CONVERSATIONS_PATH,
            body={"mode": "saved", "title": "real attachment"},
            headers={"Cookie": cookie},
        )
        assert response.status == 201
        conversation_id = _json(body)["conversation_id"]
        response, _ = _exchange(
            first,
            "POST",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}/messages",
            body={
                "role": "user",
                "content": "see the attached note",
                "created_utc": "2026-01-01T00:00:00Z",
                "attachments": [
                    {
                        "name": "note.txt",
                        "media_type": "text/plain",
                        "sha256": record.sha256,
                        "byte_count": record.source_bytes,
                    }
                ],
            },
            headers={"Cookie": cookie},
        )
        assert response.status == 201

        response, body = _exchange(
            first,
            "GET",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 200
        assert _json(body)["messages"][0]["attachments"][0]["available"] is True  # type: ignore[index]
    finally:
        first.stop()

    second = _start_gateway(paths, static_root)
    try:
        cookie = _pair(second)
        response, body = _exchange(
            second,
            "GET",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 200
        assert _json(body)["messages"][0]["attachments"][0]["available"] is True  # type: ignore[index]

        # Bytes lost out of band -- a retention sweep, a manual cleanup --
        # flip the same read to unavailable on the very next call, since
        # nothing here is cached from the write.
        store_directory = paths["qwen_home_artifacts"] / "documents" / record.sha256
        assert store_directory.is_dir()
        shutil.rmtree(store_directory)

        response, body = _exchange(
            second,
            "GET",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 200
        record_after_loss = _json(body)
        assert record_after_loss["messages"][0]["attachments"][0]["available"] is False  # type: ignore[index]
    finally:
        second.stop()


# ---------------------------------------------------------------------------
# 5. A database write failure answers 5xx JSON; the client is never told the
#    save succeeded.
# ---------------------------------------------------------------------------


def test_a_readonly_database_answers_500_rather_than_a_silent_success(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _runtime_paths(tmp_path, monkeypatch)
    fixture = _start_gateway(paths, _static_root(tmp_path))
    state_directory = paths["qwen_home_state"]
    try:
        cookie = _pair(fixture)
        response, body = _exchange(
            fixture,
            "POST",
            conversations_module.CONVERSATIONS_PATH,
            body={"mode": "saved", "title": "will not grow"},
            headers={"Cookie": cookie},
        )
        assert response.status == 201
        conversation_id = _json(body)["conversation_id"]

        database_path = state_directory / "qwen-apu.sqlite3"
        original_state_mode = state_directory.stat().st_mode
        locked_paths = [
            candidate
            for candidate in (
                database_path,
                database_path.with_name(database_path.name + "-wal"),
                database_path.with_name(database_path.name + "-shm"),
            )
            if candidate.exists()
        ]
        original_modes = {path: path.stat().st_mode for path in locked_paths}
        try:
            for path in locked_paths:
                path.chmod(0o400)
            # WAL writes a new frame into the -wal file and a lock byte into
            # the -shm file; blocking new entries in the directory as well
            # closes the path a fresh -wal or -shm creation would otherwise
            # take around the two chmods above.
            state_directory.chmod(0o500)

            response, body = _exchange(
                fixture,
                "POST",
                f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}/messages",
                body={
                    "role": "user",
                    "content": "this never lands",
                    "created_utc": "2026-01-01T00:00:00Z",
                },
                headers={"Cookie": cookie},
            )
            assert response.status >= 500
            answer = _json(body)
            assert "error" in answer
        finally:
            state_directory.chmod(original_state_mode)
            for path, mode in original_modes.items():
                path.chmod(mode)

        # The write never landed: a fresh read over the now-writable database
        # shows the conversation exactly as it stood before the failed call.
        response, body = _exchange(
            fixture,
            "GET",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 200
        assert _json(body)["messages"] == []
    finally:
        fixture.stop()


# ---------------------------------------------------------------------------
# 6. Mode is fixed before the first message, and a deleted conversation stays
#    deleted against a delayed write.
# ---------------------------------------------------------------------------


def test_a_mode_changing_patch_after_a_message_is_refused_as_a_conflict(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _runtime_paths(tmp_path, monkeypatch)
    fixture = _start_gateway(paths, _static_root(tmp_path))
    try:
        cookie = _pair(fixture)
        response, body = _exchange(
            fixture,
            "POST",
            conversations_module.CONVERSATIONS_PATH,
            body={"mode": "saved", "title": "fixed mode"},
            headers={"Cookie": cookie},
        )
        assert response.status == 201
        conversation_id = _json(body)["conversation_id"]
        response, _ = _exchange(
            fixture,
            "POST",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}/messages",
            body={
                "role": "user",
                "content": "first message",
                "created_utc": "2026-01-01T00:00:00Z",
            },
            headers={"Cookie": cookie},
        )
        assert response.status == 201

        response, body = _exchange(
            fixture,
            "PATCH",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}",
            body={"title": "renamed", "mode": "temporary"},
            headers={"Cookie": cookie},
        )
        assert response.status == 409
        assert "never changes mode" in str(_json(body)["error"])

        # The refusal touched nothing: the title is still the one set at
        # creation and the mode is still saved.
        response, body = _exchange(
            fixture,
            "GET",
            f"{conversations_module.CONVERSATIONS_PATH}/{conversation_id}",
            headers={"Cookie": cookie},
        )
        assert response.status == 200
        record = _json(body)
        assert record["title"] == "fixed mode"
        assert record["mode"] == "saved"
    finally:
        fixture.stop()


def test_a_delayed_append_after_delete_is_refused_rather_than_recreating_the_row(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A background save task racing a delete meets a refusal, never an upsert.

    `ConversationStore.append_message` checks the conversation row exists
    inside the same `BEGIN IMMEDIATE` transaction that would otherwise insert
    the message, so a message queued before a delete and flushed after it
    finds no row to attach to rather than silently recreating one.
    """
    paths = _runtime_paths(tmp_path, monkeypatch)
    store = ConversationStore(paths["qwen_home_state"])
    try:
        conversation = store.create("about to be deleted")
        store.append_message(
            conversation.conversation_id,
            Message(role="user", content="before the delete", created_utc="2026-01-01T00:00:00Z"),
        )
        store.delete(conversation.conversation_id)

        delayed = Message(
            role="assistant", content="a delayed save", created_utc="2026-01-01T00:00:05Z"
        )
        with pytest.raises(UnknownConversation):
            store.append_message(conversation.conversation_id, delayed)

        # The delete is final: the identifier names no row at all, not a row
        # with the delayed message quietly attached.
        with pytest.raises(UnknownConversation):
            store.get(conversation.conversation_id)
    finally:
        store.close()


def test_a_delayed_append_into_a_closed_temporary_conversation_is_refused(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The in-memory registry refuses the same race the SQLite store refuses."""
    paths = _runtime_paths(tmp_path, monkeypatch)
    registry = conversations_module.TemporaryConversations(paths["qwen_home_tmp"])
    conversation = registry.open("about to close")
    registry.close(conversation.conversation_id)
    delayed = Message(role="user", content="too late", created_utc="2026-01-01T00:00:00Z")
    with pytest.raises(UnknownConversation):
        registry.append(conversation.conversation_id, delayed)
