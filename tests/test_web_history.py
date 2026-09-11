"""The conversation store, its document, and the two homes a conversation has.

Each case names the mechanism it pins. The migration cases separate an empty
file from a predecessor file at `user_version` 0, because `CREATE TABLE`
without `IF NOT EXISTS` is what turns a colliding table into a refusal rather
than into an insert that fails later. The delete case holds a digest two
conversations share, so it distinguishes "every digest this conversation
named" from "every digest the deletion left unreferenced" -- a test built on
one conversation passes under both rules and pins neither.

The temporary-transcript case scans the union of `qwen-apu.sqlite3`, its
`-wal`, and its `-shm`, since a WAL database holds a just-written page in the
sidecar until a checkpoint runs, and it asserts a saved message's text IS
present in that same union, which is what keeps the absence claim from
passing over a store that wrote nothing at all.
"""

from __future__ import annotations

import json
import sqlite3
import threading
from collections.abc import Callable
from pathlib import Path

import pytest

from qwen_apu.tools.approvals import SessionOrRefusal
from qwen_apu.web import conversations as conversation_routes
from qwen_apu.web.conversations import (
    CONVERSATIONS_PATH,
    EXPORT_PATH,
    IMPORT_PATH,
    ConversationSettings,
    TemporaryConversations,
)
from qwen_apu.web.history import (
    DATABASE_FILE_NAME,
    MIGRATIONS,
    SCHEMA_VERSION,
    ConversationStore,
    DocumentRefused,
    Observation,
    SchemaCollision,
    UnknownConversation,
    credential_keys,
    utc_stamp,
)
from qwen_apu.web.history_model import AttachmentRef, Message, ToolEvent
from qwen_apu.web.http import Request, Response, match

CLIENT = "127.0.0.1"
TEMPORARY_TEXT = "ephemeral-marker-4f2c never reaches a row"
SAVED_TEXT = "durable-marker-91ab reaches a row"
# The credential-shaped key an import document is refused for carrying.
SMUGGLED_KEY = "session_secret"


def admit(request: Request) -> SessionOrRefusal:
    del request
    return SessionOrRefusal(True)


def store_at(directory: Path, clock: Callable[[], float] | None = None) -> ConversationStore:
    directory.mkdir(parents=True, exist_ok=True)
    if clock is None:
        return ConversationStore(directory)
    return ConversationStore(directory, clock=clock)


def rich_message() -> Message:
    """One message carrying every field the record declares."""
    return Message(
        role="assistant",
        content="the bars chart names JUN at 150",
        created_utc="2026-01-02T03:04:05+00:00",
        served_model="qwen38-2b-distill",
        reasoning_shown=True,
        tool_events=(
            ToolEvent(
                tool_id="web_search",
                origin="model",
                arguments_sha256="a" * 64,
                outcome="approved",
                result_sha256="b" * 64,
                detail="one result returned",
            ),
            ToolEvent(
                tool_id="read_file",
                origin="user",
                arguments_sha256="c" * 64,
                outcome="refused",
            ),
        ),
        sources=("https://example.invalid/one", "https://example.invalid/two"),
        artifacts=("d" * 64,),
        attachments=(
            AttachmentRef(name="bars.png", media_type="image/png", sha256="e" * 64, byte_count=931),
            AttachmentRef(
                name="notes.txt", media_type="text/plain", sha256="f" * 64, byte_count=12
            ),
        ),
        truncation_note="the oldest four turns left the context window",
    )


def settings_at(
    tmp_path: Path, session: Callable[[Request], SessionOrRefusal]
) -> ConversationSettings:
    return conversation_routes.build(tmp_path / "state", tmp_path / "tmp", session)


def call(
    settings: ConversationSettings,
    method: str,
    path: str,
    payload: object = None,
) -> Response:
    """Route one request the way the gateway does: match, bind params, handle."""
    found = match(conversation_routes.routes(settings), method, path)
    assert found is not None, f"no route matches {method} {path}"
    route, params = found
    body = b"" if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(
        method=method,
        path=path,
        query={},
        headers={"content-type": "application/json"},
        body=body,
        client_address=CLIENT,
        path_params=params,
    )
    answer = route.handler(request)
    assert isinstance(answer, Response)
    return answer


def decoded(response: Response) -> dict[str, object]:
    payload = json.loads(response.body.decode("utf-8"))
    assert isinstance(payload, dict)
    return {str(key): value for key, value in payload.items()}


def members(holder: dict[str, object], key: str) -> list[dict[str, object]]:
    """The list of objects one JSON field carries, asserted rather than cast."""
    held = holder[key]
    assert isinstance(held, list)
    entries: list[dict[str, object]] = []
    for item in held:
        assert isinstance(item, dict)
        entries.append({str(name): value for name, value in item.items()})
    return entries


def database_bytes(store: ConversationStore) -> bytes:
    """The database and both WAL sidecars, which is where a written page can be."""
    joined = b""
    for suffix in ("", "-wal", "-shm"):
        candidate = Path(f"{store.path}{suffix}")
        if candidate.exists():
            joined += candidate.read_bytes()
    return joined


def test_migration_lays_out_the_schema_on_an_empty_file(tmp_path: Path) -> None:
    state = tmp_path / "state"
    state.mkdir()
    (state / DATABASE_FILE_NAME).touch()
    store = store_at(state)
    assert store.user_version() == SCHEMA_VERSION
    tables = {
        str(row[0])
        for row in store.connection.execute("SELECT name FROM sqlite_master WHERE type = 'table'")
    }
    assert {
        "conversations",
        "messages",
        "tool_events",
        "attachments",
        "model_switches",
        "observations",
    } <= tables
    # A reopen applies nothing, because the pragma records what has run.
    assert store_at(state).migrate() == SCHEMA_VERSION
    store.close()


def test_migration_adopts_a_version_zero_file_holding_a_legacy_table(tmp_path: Path) -> None:
    state = tmp_path / "state"
    state.mkdir()
    legacy = sqlite3.connect(state / DATABASE_FILE_NAME, isolation_level=None)
    legacy.execute("CREATE TABLE history_notes (note TEXT)")
    legacy.execute("INSERT INTO history_notes (note) VALUES ('written before phase 6')")
    assert int(legacy.execute("PRAGMA user_version").fetchone()[0]) == 0
    legacy.close()

    store = store_at(state)
    assert store.user_version() == SCHEMA_VERSION
    surviving = store.connection.execute("SELECT note FROM history_notes").fetchall()
    assert [str(row[0]) for row in surviving] == ["written before phase 6"]
    opened = store.create("after the migration")
    assert store.get(opened.conversation_id).title == "after the migration"
    store.close()


def test_migration_refuses_a_file_whose_table_collides(tmp_path: Path) -> None:
    state = tmp_path / "state"
    state.mkdir()
    legacy = sqlite3.connect(state / DATABASE_FILE_NAME, isolation_level=None)
    legacy.execute("CREATE TABLE conversations (id TEXT, subject TEXT)")
    legacy.close()
    with pytest.raises(SchemaCollision) as refusal:
        store_at(state)
    assert "conversations" in str(refusal.value)


def test_migrations_are_ordered_and_each_carries_its_own_version() -> None:
    versions = [migration.version for migration in MIGRATIONS]
    assert versions == sorted(set(versions))
    assert versions[-1] == SCHEMA_VERSION


def test_every_record_field_round_trips(tmp_path: Path) -> None:
    store = store_at(tmp_path / "state", clock=lambda: 1000.0)
    opened = store.create("a graded sweep")
    message = rich_message()
    assert store.append_message(opened.conversation_id, message) == 0
    assert store.append_message(opened.conversation_id, Message("user", "and again", "")) == 1
    store.record_model_switch(opened.conversation_id, "qwen38-4b-distill")
    store.record_observation(opened.conversation_id, "checkpoint", "prompt cache checkpoint at 2")

    read = store.get(opened.conversation_id)
    assert read.conversation_id == opened.conversation_id
    assert read.mode == "saved"
    assert read.title == "a graded sweep"
    assert read.created_utc == opened.created_utc
    assert read.workflow_state == "idle"
    assert read.messages[0] == message
    assert read.messages[1].content == "and again"
    assert [switch[1] for switch in read.model_switches] == ["qwen38-4b-distill"]
    assert store.observations(opened.conversation_id) == (
        Observation("checkpoint", "prompt cache checkpoint at 2", utc_stamp(1000.0)),
    )
    store.close()


def test_rename_moves_the_title_and_the_update_stamp(tmp_path: Path) -> None:
    stamps = iter([1000.0, 2000.0, 3000.0])
    store = store_at(tmp_path / "state", clock=lambda: next(stamps))
    opened = store.create("first")
    renamed = store.rename(opened.conversation_id, "second")
    assert renamed.title == "second"
    assert renamed.updated_utc != opened.updated_utc
    assert renamed.created_utc == opened.created_utc
    with pytest.raises(UnknownConversation):
        store.rename("0" * 32, "third")
    store.close()


def test_listing_answers_headers_most_recently_updated_first(tmp_path: Path) -> None:
    stamps = iter([1000.0, 2000.0, 3000.0, 4000.0])
    store = store_at(tmp_path / "state", clock=lambda: next(stamps))
    first = store.create("first")
    second = store.create("second")
    listed = store.list()
    assert [row.conversation_id for row in listed] == [
        second.conversation_id,
        first.conversation_id,
    ]
    assert listed[0].messages == ()
    store.close()


def test_delete_returns_the_digests_its_removal_left_unreferenced(tmp_path: Path) -> None:
    store = store_at(tmp_path / "state")
    doomed = store.create("the one deleted")
    surviving = store.create("the one kept")
    shared = AttachmentRef("shared.png", "image/png", "1" * 64, 10)
    sole = AttachmentRef("sole.png", "image/png", "2" * 64, 20)
    store.append_message(
        doomed.conversation_id, Message("user", "two uploads", "", attachments=(shared, sole))
    )
    store.append_message(
        surviving.conversation_id, Message("user", "one upload", "", attachments=(shared,))
    )

    freed = store.delete(doomed.conversation_id)
    assert freed == ("2" * 64,)
    with pytest.raises(UnknownConversation):
        store.get(doomed.conversation_id)
    for table in ("messages", "attachments", "tool_events", "observations", "model_switches"):
        remaining = store.connection.execute(
            f"SELECT COUNT(*) FROM {table} WHERE conversation_id = ?",  # noqa: S608
            (doomed.conversation_id,),
        ).fetchone()
        assert int(remaining[0]) == 0
    assert store.get(surviving.conversation_id).messages[0].attachments == (shared,)
    store.close()


def test_export_then_import_into_a_fresh_store_reproduces_the_records(tmp_path: Path) -> None:
    origin = store_at(tmp_path / "origin")
    first = origin.create("a graded sweep")
    origin.append_message(first.conversation_id, rich_message())
    origin.record_model_switch(first.conversation_id, "qwen38-2b-distill")
    origin.record_observation(first.conversation_id, "truncation", "the window rolled")
    second = origin.create("a second conversation")
    origin.append_message(second.conversation_id, Message("system", "a system turn", "now"))
    document = origin.export_all()

    fresh = store_at(tmp_path / "fresh")
    imported = fresh.import_document(document)
    assert set(imported) == {first.conversation_id, second.conversation_id}
    for identifier in imported:
        assert fresh.get(identifier) == origin.get(identifier)
        assert fresh.observations(identifier) == origin.observations(identifier)
    assert fresh.export_all()["conversations"] == document["conversations"]

    single = origin.export(first.conversation_id)
    assert [entry["conversation_id"] for entry in members(single, "conversations")] == [
        first.conversation_id
    ]
    origin.close()
    fresh.close()


def test_import_refuses_a_version_it_does_not_know(tmp_path: Path) -> None:
    store = store_at(tmp_path / "state")
    with pytest.raises(DocumentRefused) as refusal:
        store.import_document({"document_version": 99, "conversations": []})
    assert "99" in str(refusal.value)
    with pytest.raises(DocumentRefused):
        store.import_document({"conversations": []})
    store.close()


def test_import_refuses_a_credential_key_nested_in_a_message(tmp_path: Path) -> None:
    store = store_at(tmp_path / "state")
    origin = store.create("a conversation")
    store.append_message(origin.conversation_id, Message("user", "hello", "now"))
    document = store.export_all()
    conversations = document["conversations"]
    assert isinstance(conversations, list)
    record = conversations[0]
    assert isinstance(record, dict)
    messages = record["messages"]
    assert isinstance(messages, list)
    smuggled = messages[0]
    assert isinstance(smuggled, dict)
    smuggled[SMUGGLED_KEY] = "a value the scan never reads"

    fresh = store_at(tmp_path / "fresh")
    with pytest.raises(DocumentRefused) as refusal:
        fresh.import_document(document)
    assert SMUGGLED_KEY in str(refusal.value)
    assert fresh.list() == ()
    store.close()
    fresh.close()


def test_every_credential_term_refuses_however_it_is_spelled() -> None:
    for key in ("Bearer", "auth-token", "API Key", "reusable_grant", "Cookie", "client_secret"):
        assert credential_keys({"conversations": [{key: "x"}]}), key
    # A value naming a term is not a key naming one: the rule reads keys alone.
    innocent = {"conversations": [{"messages": [{"content": "a token of thanks"}]}]}
    assert credential_keys(innocent) == []


def test_import_refuses_a_temporary_conversation(tmp_path: Path) -> None:
    store = store_at(tmp_path / "state")
    with pytest.raises(DocumentRefused) as refusal:
        store.import_document(
            {
                "document_version": 1,
                "conversations": [
                    {
                        "conversation_id": "a" * 32,
                        "mode": "temporary",
                        "title": "a temporary transcript",
                    }
                ],
            }
        )
    assert "temporary" in str(refusal.value)
    store.close()


def test_the_store_refuses_to_create_a_temporary_conversation(tmp_path: Path) -> None:
    store = store_at(tmp_path / "state")
    with pytest.raises(DocumentRefused):
        store.create("held in memory", mode="temporary")
    store.close()


def test_a_temporary_transcript_never_reaches_the_database_bytes(tmp_path: Path) -> None:
    settings = settings_at(tmp_path, admit)
    saved = decoded(call(settings, "POST", CONVERSATIONS_PATH, {"mode": "saved", "title": "kept"}))
    temporary = decoded(
        call(settings, "POST", CONVERSATIONS_PATH, {"mode": "temporary", "title": "ephemeral"})
    )
    assert temporary["mode"] == "temporary"
    for identifier, text in (
        (str(saved["conversation_id"]), SAVED_TEXT),
        (str(temporary["conversation_id"]), TEMPORARY_TEXT),
    ):
        answer = call(
            settings,
            "POST",
            f"{CONVERSATIONS_PATH}/{identifier}/messages",
            {"role": "user", "content": text, "created_utc": "now"},
        )
        assert answer.status == 201

    bytes_on_disk = database_bytes(settings.store)
    assert SAVED_TEXT.encode("utf-8") in bytes_on_disk
    assert TEMPORARY_TEXT.encode("utf-8") not in bytes_on_disk
    assert len(settings.store.list()) == 1
    read = decoded(call(settings, "GET", f"{CONVERSATIONS_PATH}/{temporary['conversation_id']}"))
    assert members(read, "messages")[0]["content"] == TEMPORARY_TEXT
    settings.store.close()


def test_close_expire_and_shutdown_each_remove_the_temporary_directory(tmp_path: Path) -> None:
    now = 1000.0
    registry = TemporaryConversations(tmp_path / "tmp", lifetime_s=60.0, clock=lambda: now)

    closed = registry.open("closed by hand")
    written = registry.directory(closed.conversation_id) / "upload.png"
    written.write_bytes(b"\x89PNG")
    assert written.exists()
    registry.close(closed.conversation_id)
    assert not registry.directory(closed.conversation_id).exists()
    assert not registry.holds(closed.conversation_id)

    expiring = registry.open("abandoned")
    (registry.directory(expiring.conversation_id) / "scratch.json").write_text("{}")
    assert registry.expire(now + 30.0) == ()
    assert registry.expire(now + 61.0) == (expiring.conversation_id,)
    assert not registry.directory(expiring.conversation_id).exists()

    remaining = registry.open("open at shutdown")
    (registry.directory(remaining.conversation_id) / "scratch.json").write_text("{}")
    assert registry.shutdown() == (remaining.conversation_id,)
    assert not registry.directory(remaining.conversation_id).exists()
    assert registry.identifiers() == ()


def test_a_patch_carrying_mode_is_refused_for_either_home(tmp_path: Path) -> None:
    settings = settings_at(tmp_path, admit)
    saved = decoded(call(settings, "POST", CONVERSATIONS_PATH, {"mode": "saved", "title": "kept"}))
    temporary = decoded(
        call(settings, "POST", CONVERSATIONS_PATH, {"mode": "temporary", "title": "ephemeral"})
    )
    for identifier in (saved["conversation_id"], temporary["conversation_id"]):
        refusal = call(
            settings,
            "PATCH",
            f"{CONVERSATIONS_PATH}/{identifier}",
            {"title": "renamed", "mode": "saved"},
        )
        assert refusal.status == 400
        assert "never changes mode" in str(decoded(refusal)["error"])
    # The same PATCH without the key renames.
    renamed = call(
        settings, "PATCH", f"{CONVERSATIONS_PATH}/{saved['conversation_id']}", {"title": "renamed"}
    )
    assert decoded(renamed)["title"] == "renamed"
    settings.store.close()


def test_every_route_refuses_a_request_carrying_no_session(tmp_path: Path) -> None:
    refusing = settings_at(tmp_path, conversation_routes.refuse_every_session)
    admitting = ConversationSettings(refusing.store, refusing.temporary, admit)
    opened = decoded(
        call(admitting, "POST", CONVERSATIONS_PATH, {"mode": "saved", "title": "kept"})
    )
    identifier = str(opened["conversation_id"])
    exchanges = (
        ("GET", CONVERSATIONS_PATH, None),
        ("POST", CONVERSATIONS_PATH, {"mode": "saved", "title": "another"}),
        ("GET", f"{CONVERSATIONS_PATH}/{identifier}", None),
        ("PATCH", f"{CONVERSATIONS_PATH}/{identifier}", {"title": "renamed"}),
        ("DELETE", f"{CONVERSATIONS_PATH}/{identifier}", None),
        ("POST", f"{CONVERSATIONS_PATH}/{identifier}/messages", {"role": "user", "content": "x"}),
        ("GET", EXPORT_PATH, None),
        ("POST", IMPORT_PATH, {"document_version": 1, "conversations": []}),
    )
    for method, path, payload in exchanges:
        answer = call(refusing, method, path, payload)
        assert answer.status == 401, f"{method} {path} answered {answer.status}"
    # The refusals changed nothing.
    assert [row.conversation_id for row in refusing.store.list()] == [identifier]
    refusing.store.close()


def test_an_absent_conversation_answers_404_and_a_bad_body_answers_400(tmp_path: Path) -> None:
    settings = settings_at(tmp_path, admit)
    assert call(settings, "GET", f"{CONVERSATIONS_PATH}/{'0' * 32}").status == 404
    opened = decoded(call(settings, "POST", CONVERSATIONS_PATH, {"title": "kept"}))
    identifier = str(opened["conversation_id"])
    refused = call(
        settings, "POST", f"{CONVERSATIONS_PATH}/{identifier}/messages", {"role": "narrator"}
    )
    assert refused.status == 400
    assert call(settings, "POST", CONVERSATIONS_PATH, {"mode": "archived"}).status == 400
    settings.store.close()


def test_the_export_route_is_unreachable_as_an_identifier(tmp_path: Path) -> None:
    settings = settings_at(tmp_path, admit)
    routes = conversation_routes.routes(settings)
    found = match(routes, "GET", EXPORT_PATH)
    assert found is not None
    assert found[1] == {}
    assert match(routes, "GET", f"{CONVERSATIONS_PATH}/export") is not None
    assert match(routes, "GET", f"{CONVERSATIONS_PATH}/not-a-hex-identifier") is None
    settings.store.close()


def test_the_routes_export_and_import_one_document(tmp_path: Path) -> None:
    settings = settings_at(tmp_path, admit)
    opened = decoded(call(settings, "POST", CONVERSATIONS_PATH, {"title": "kept"}))
    identifier = str(opened["conversation_id"])
    call(
        settings,
        "POST",
        f"{CONVERSATIONS_PATH}/{identifier}/messages",
        {"role": "user", "content": "one turn", "created_utc": "now"},
    )
    document = decoded(call(settings, "GET", EXPORT_PATH))
    assert document["document_version"] == 1

    fresh = settings_at(tmp_path / "second", admit)
    answer = call(fresh, "POST", IMPORT_PATH, document)
    assert answer.status == 201
    assert decoded(answer)["imported"] == [identifier]
    assert fresh.store.get(identifier).messages[0].content == "one turn"

    listing = decoded(call(fresh, "GET", CONVERSATIONS_PATH))
    assert members(listing, "conversations")[0]["message_count"] == 1
    settings.store.close()
    fresh.store.close()


def test_delete_through_the_route_reports_digests_and_closes_a_temporary(tmp_path: Path) -> None:
    settings = settings_at(tmp_path, admit)
    saved = decoded(call(settings, "POST", CONVERSATIONS_PATH, {"title": "kept"}))
    identifier = str(saved["conversation_id"])
    call(
        settings,
        "POST",
        f"{CONVERSATIONS_PATH}/{identifier}/messages",
        {
            "role": "user",
            "content": "with an upload",
            "created_utc": "now",
            "attachments": [
                {"name": "bars.png", "media_type": "image/png", "sha256": "3" * 64, "byte_count": 9}
            ],
        },
    )
    answer = decoded(call(settings, "DELETE", f"{CONVERSATIONS_PATH}/{identifier}"))
    assert answer["attachment_digests"] == ["3" * 64]

    temporary = decoded(
        call(settings, "POST", CONVERSATIONS_PATH, {"mode": "temporary", "title": "ephemeral"})
    )
    ephemeral = str(temporary["conversation_id"])
    directory = settings.temporary.directory(ephemeral)
    assert directory.is_dir()
    closed = decoded(call(settings, "DELETE", f"{CONVERSATIONS_PATH}/{ephemeral}"))
    assert closed["attachment_digests"] == []
    assert not directory.exists()
    settings.store.close()


def test_two_threads_appending_take_consecutive_positions(tmp_path: Path) -> None:
    """`BEGIN IMMEDIATE` holds the write lock across the read of MAX(position).

    A lost update would repeat a position or skip one, so the case asserts the
    set of positions equals `range(2 * PER_THREAD)` rather than asserting that
    the order merely rises.
    """
    per_thread = 25
    store = store_at(tmp_path / "state")
    opened = store.create("two writers")
    taken: list[int] = []
    lock = threading.Lock()
    failures: list[BaseException] = []

    def append(marker: str) -> None:
        try:
            for index in range(per_thread):
                position = store.append_message(
                    opened.conversation_id,
                    Message("user", f"{marker}-{index}", "now"),
                )
                with lock:
                    taken.append(position)
        except BaseException as failure:  # the thread's failure belongs to the test
            with lock:
                failures.append(failure)

    threads = [threading.Thread(target=append, args=(marker,)) for marker in ("first", "second")]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert failures == []
    assert sorted(taken) == list(range(2 * per_thread))

    read = store.get(opened.conversation_id)
    assert len(read.messages) == 2 * per_thread
    for marker in ("first", "second"):
        held = [message.content for message in read.messages if message.content.startswith(marker)]
        assert held == [f"{marker}-{index}" for index in range(per_thread)]
    store.close()


def test_a_conversation_record_carries_no_credential_column(tmp_path: Path) -> None:
    """The schema declares no home for a bearer, a grant, or a session secret."""
    store = store_at(tmp_path / "state")
    columns: set[str] = set()
    for table in (
        "conversations",
        "messages",
        "tool_events",
        "attachments",
        "model_switches",
        "observations",
    ):
        for row in store.connection.execute(f"PRAGMA table_info({table})"):
            columns.add(str(row[1]).lower())
    assert "conversation_id" in columns
    assert credential_keys(dict.fromkeys(columns, "")) == []
    store.close()
