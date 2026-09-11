"""The saved conversation store: one SQLite database under the runtime root.

`<state>/qwen-apu.sqlite3` holds the conversation record `web/history_model.py`
declares -- titles, message text, tool-event digests, attachment metadata,
model switches, and observations -- and holds it whole. The journal mode is
WAL here: the rows carry the operator's own transcript rather than fetched
page text, so a page image living in a `-wal` sidecar until the next
checkpoint bounds nothing this database owes a caller, which is the property
`tools/ledger.py` runs DELETE beside `secure_delete = ON` to keep for the
`content` table. What WAL buys instead is a reader concurrent with a writer:
the page lists conversations while an append writes, and both proceed.

Credentials stay out by construction. The six tables declare no column for a
bearer, a session cookie, a reusable grant, or an approval secret, so a
persisted transcript carries none, and `import_document` refuses a document
carrying a key named like one against the closed list `bearer`, `token`,
`secret`, `grant`, `api_key`, `cookie`, scanned over every nested object
before the first row is written.

Schema state lives in `PRAGMA user_version` and `MIGRATIONS` is an ordered
list read against it: a revision appends an entry and leaves every earlier
entry byte-identical, because the pragma records which entries have run and
an edited entry changes what a database at that version means. Each entry
applies inside one transaction that carries its own version bump, so an
interrupted migration leaves the database at the version it arrived with.

An observation is a note about the conversation rather than a turn in it.
A row carrying a message position is that message's truncation note and
travels with the message; a row carrying no position is a conversation-scope
note, which is what a context checkpoint record is. That split is what makes
`export` and `import_document` lossless without writing a note twice.
"""

from __future__ import annotations

import datetime as dt
import json
import sqlite3
import threading
import time
import uuid
from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, cast

from qwen_apu.web.history_model import AttachmentRef, Conversation, Message, Role, ToolEvent

DATABASE_FILE_NAME = "qwen-apu.sqlite3"
DATABASE_FILE_MODE = 0o600
BUSY_TIMEOUT_SECONDS = 10.0
BUSY_TIMEOUT_MS = 10000

DOCUMENT_VERSION = 1
DOCUMENT_VERSIONS: tuple[int, ...] = (1,)

# The closed list a key is refused against. A key is normalized to lowercase
# with `-` and spaces folded to `_`, and it refuses where any term appears in
# it, so `session_secret`, `Authorization-Token`, and `api key` all refuse.
CREDENTIAL_KEY_TERMS: tuple[str, ...] = (
    "bearer",
    "token",
    "secret",
    "grant",
    "api_key",
    "cookie",
)

ROLES: frozenset[str] = frozenset({"user", "assistant", "system", "tool"})
TOOL_ORIGINS: frozenset[str] = frozenset({"user", "model"})
TOOL_OUTCOMES: frozenset[str] = frozenset(
    {"proposed", "approved", "refused", "completed", "failed"}
)
OBSERVATION_KINDS: frozenset[str] = frozenset({"truncation", "checkpoint"})

ObservationKind = Literal["truncation", "checkpoint"]

# `ConversationStore.list` carries the listing read, so the builtin is
# shadowed inside the class body an annotation resolves in; the identifier
# sequence its import answers with is named out here.
ConversationIds = list[str]


class HistoryError(Exception):
    """A refusal this module states in its own vocabulary."""


class UnknownConversation(HistoryError):
    """The store holds no conversation under the named identifier."""


class DocumentRefused(HistoryError):
    """A record, a request body, or an import document fails a rule stated here."""


class SchemaCollision(HistoryError):
    """The database file already holds a table this schema names."""


@dataclass(frozen=True)
class Observation:
    """A conversation-scope note: a context truncation or a checkpoint record."""

    kind: ObservationKind
    note: str
    recorded_utc: str


@dataclass(frozen=True)
class Migration:
    """One schema step: the statements it runs and the version it leaves behind."""

    version: int
    statements: tuple[str, ...]


MIGRATIONS: tuple[Migration, ...] = (
    Migration(
        version=1,
        statements=(
            "CREATE TABLE conversations ("
            " conversation_id TEXT PRIMARY KEY,"
            " mode TEXT NOT NULL,"
            " title TEXT NOT NULL,"
            " created_utc TEXT NOT NULL,"
            " updated_utc TEXT NOT NULL,"
            " workflow_state TEXT NOT NULL)",
            "CREATE TABLE messages ("
            " conversation_id TEXT NOT NULL,"
            " position INTEGER NOT NULL,"
            " role TEXT NOT NULL,"
            " content TEXT NOT NULL,"
            " created_utc TEXT NOT NULL,"
            " served_model TEXT NOT NULL,"
            " reasoning_shown INTEGER NOT NULL,"
            " sources TEXT NOT NULL,"
            " artifacts TEXT NOT NULL,"
            " PRIMARY KEY (conversation_id, position))",
            "CREATE TABLE tool_events ("
            " conversation_id TEXT NOT NULL,"
            " position INTEGER NOT NULL,"
            " ordinal INTEGER NOT NULL,"
            " tool_id TEXT NOT NULL,"
            " origin TEXT NOT NULL,"
            " arguments_sha256 TEXT NOT NULL,"
            " outcome TEXT NOT NULL,"
            " result_sha256 TEXT NOT NULL,"
            " detail TEXT NOT NULL,"
            " PRIMARY KEY (conversation_id, position, ordinal))",
            "CREATE TABLE attachments ("
            " conversation_id TEXT NOT NULL,"
            " position INTEGER NOT NULL,"
            " ordinal INTEGER NOT NULL,"
            " name TEXT NOT NULL,"
            " media_type TEXT NOT NULL,"
            " sha256 TEXT NOT NULL,"
            " byte_count INTEGER NOT NULL,"
            " PRIMARY KEY (conversation_id, position, ordinal))",
            "CREATE TABLE model_switches ("
            " conversation_id TEXT NOT NULL,"
            " ordinal INTEGER NOT NULL,"
            " switched_utc TEXT NOT NULL,"
            " model_id TEXT NOT NULL,"
            " PRIMARY KEY (conversation_id, ordinal))",
            "CREATE TABLE observations ("
            " conversation_id TEXT NOT NULL,"
            " ordinal INTEGER NOT NULL,"
            " position INTEGER,"
            " kind TEXT NOT NULL,"
            " note TEXT NOT NULL,"
            " recorded_utc TEXT NOT NULL,"
            " PRIMARY KEY (conversation_id, ordinal))",
            "CREATE INDEX conversations_updated ON conversations (updated_utc)",
            "CREATE INDEX attachments_digest ON attachments (sha256)",
        ),
    ),
)

SCHEMA_VERSION = MIGRATIONS[-1].version


def utc_stamp(now: float) -> str:
    """The timestamp spelling every `*_utc` column carries."""
    return dt.datetime.fromtimestamp(now, tz=dt.UTC).isoformat(timespec="seconds")


def new_conversation_id() -> str:
    """A 32-character hexadecimal identifier, which is also the route pattern."""
    return uuid.uuid4().hex


def _normalized_key(key: str) -> str:
    return key.lower().replace("-", "_").replace(" ", "_")


def credential_keys(document: object, path: str = "$") -> list[str]:
    """Return the paths of every key named like a credential, scanned recursively.

    The scan reads keys alone and descends through every object and array, so a
    credential nested inside a message refuses the same document a top-level
    one does. Values stay unread: a key named like a credential is the whole
    rule, which keeps the refusal decidable without inspecting a transcript.
    """
    found: list[str] = []
    if isinstance(document, dict):
        for key, value in cast(dict[str, object], document).items():
            spelled = _normalized_key(str(key))
            child = f"{path}.{key}"
            if any(term in spelled for term in CREDENTIAL_KEY_TERMS):
                found.append(child)
            found.extend(credential_keys(value, child))
    elif isinstance(document, list):
        for index, value in enumerate(cast(list[object], document)):
            found.extend(credential_keys(value, f"{path}[{index}]"))
    return found


def _object(payload: object, what: str) -> dict[str, object]:
    if not isinstance(payload, dict):
        raise DocumentRefused(f"{what} is not a JSON object")
    return cast(dict[str, object], payload)


def _text(payload: dict[str, object], key: str, what: str, default: str | None = None) -> str:
    value = payload.get(key, default)
    if not isinstance(value, str):
        raise DocumentRefused(f"{what} names no string {key}")
    return value


def _strings(payload: dict[str, object], key: str, what: str) -> tuple[str, ...]:
    value = payload.get(key, [])
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise DocumentRefused(f"{what} names {key} as something other than a list of strings")
    return tuple(cast(list[str], value))


def _members(payload: dict[str, object], key: str, what: str) -> list[dict[str, object]]:
    value = payload.get(key, [])
    if not isinstance(value, list):
        raise DocumentRefused(f"{what} names {key} as something other than a list")
    return [_object(item, f"{what} {key} member") for item in cast(list[object], value)]


def tool_event_to_json(event: ToolEvent) -> dict[str, object]:
    return {
        "tool_id": event.tool_id,
        "origin": event.origin,
        "arguments_sha256": event.arguments_sha256,
        "outcome": event.outcome,
        "result_sha256": event.result_sha256,
        "detail": event.detail,
    }


def tool_event_from_json(payload: object) -> ToolEvent:
    record = _object(payload, "a tool event")
    origin = _text(record, "origin", "a tool event")
    outcome = _text(record, "outcome", "a tool event")
    if origin not in TOOL_ORIGINS:
        raise DocumentRefused(f"a tool event names the origin {origin!r}")
    if outcome not in TOOL_OUTCOMES:
        raise DocumentRefused(f"a tool event names the outcome {outcome!r}")
    return ToolEvent(
        tool_id=_text(record, "tool_id", "a tool event"),
        origin=cast(Literal["user", "model"], origin),
        arguments_sha256=_text(record, "arguments_sha256", "a tool event", ""),
        outcome=cast(
            Literal["proposed", "approved", "refused", "completed", "failed"],
            outcome,
        ),
        result_sha256=_text(record, "result_sha256", "a tool event", ""),
        detail=_text(record, "detail", "a tool event", ""),
    )


def attachment_to_json(attachment: AttachmentRef) -> dict[str, object]:
    return {
        "name": attachment.name,
        "media_type": attachment.media_type,
        "sha256": attachment.sha256,
        "byte_count": attachment.byte_count,
    }


def attachment_from_json(payload: object) -> AttachmentRef:
    record = _object(payload, "an attachment")
    byte_count = record.get("byte_count", 0)
    if not isinstance(byte_count, int) or isinstance(byte_count, bool) or byte_count < 0:
        raise DocumentRefused("an attachment names a byte_count that is not a whole count")
    return AttachmentRef(
        name=_text(record, "name", "an attachment"),
        media_type=_text(record, "media_type", "an attachment"),
        sha256=_text(record, "sha256", "an attachment"),
        byte_count=byte_count,
    )


def message_to_json(message: Message) -> dict[str, object]:
    return {
        "role": message.role,
        "content": message.content,
        "created_utc": message.created_utc,
        "served_model": message.served_model,
        "reasoning_shown": message.reasoning_shown,
        "truncation_note": message.truncation_note,
        "sources": list(message.sources),
        "artifacts": list(message.artifacts),
        "tool_events": [tool_event_to_json(event) for event in message.tool_events],
        "attachments": [attachment_to_json(item) for item in message.attachments],
    }


def message_from_json(payload: object) -> Message:
    """Read one message record, refusing every field the model does not admit."""
    record = _object(payload, "a message")
    role = _text(record, "role", "a message")
    if role not in ROLES:
        raise DocumentRefused(f"a message names the role {role!r}")
    reasoning_shown = record.get("reasoning_shown", False)
    if not isinstance(reasoning_shown, bool):
        raise DocumentRefused("a message names reasoning_shown as something other than a boolean")
    return Message(
        role=cast(Role, role),
        content=_text(record, "content", "a message"),
        created_utc=_text(record, "created_utc", "a message", ""),
        served_model=_text(record, "served_model", "a message", ""),
        reasoning_shown=reasoning_shown,
        tool_events=tuple(
            tool_event_from_json(item) for item in _members(record, "tool_events", "a message")
        ),
        sources=_strings(record, "sources", "a message"),
        artifacts=_strings(record, "artifacts", "a message"),
        attachments=tuple(
            attachment_from_json(item) for item in _members(record, "attachments", "a message")
        ),
        truncation_note=_text(record, "truncation_note", "a message", ""),
    )


def observation_to_json(observation: Observation) -> dict[str, object]:
    return {
        "kind": observation.kind,
        "note": observation.note,
        "recorded_utc": observation.recorded_utc,
    }


def observation_from_json(payload: object) -> Observation:
    record = _object(payload, "an observation")
    kind = _text(record, "kind", "an observation")
    if kind not in OBSERVATION_KINDS:
        raise DocumentRefused(
            f"an observation names the kind {kind!r}; the store admits {sorted(OBSERVATION_KINDS)}"
        )
    return Observation(
        kind=cast(ObservationKind, kind),
        note=_text(record, "note", "an observation"),
        recorded_utc=_text(record, "recorded_utc", "an observation", ""),
    )


def conversation_to_json(
    conversation: Conversation, observations: Sequence[Observation] = ()
) -> dict[str, object]:
    """Render one whole conversation, which is what export and `GET` both answer."""
    return {
        "conversation_id": conversation.conversation_id,
        "mode": conversation.mode,
        "title": conversation.title,
        "created_utc": conversation.created_utc,
        "updated_utc": conversation.updated_utc,
        "workflow_state": conversation.workflow_state,
        "model_switches": [list(switch) for switch in conversation.model_switches],
        "messages": [message_to_json(message) for message in conversation.messages],
        "observations": [observation_to_json(item) for item in observations],
    }


def conversation_from_json(payload: object) -> tuple[Conversation, tuple[Observation, ...]]:
    """Read one conversation record and its conversation-scope observations."""
    record = _object(payload, "a conversation")
    mode = _text(record, "mode", "a conversation", "saved")
    if mode != "saved":
        raise DocumentRefused(
            f"a conversation carries the mode {mode!r}; the store holds saved "
            "conversations and a temporary transcript stays in memory"
        )
    switches = _model_switches(record)
    conversation = Conversation(
        conversation_id=_text(record, "conversation_id", "a conversation"),
        mode="saved",
        title=_text(record, "title", "a conversation"),
        created_utc=_text(record, "created_utc", "a conversation", ""),
        updated_utc=_text(record, "updated_utc", "a conversation", ""),
        messages=tuple(
            message_from_json(item) for item in _members(record, "messages", "a conversation")
        ),
        model_switches=switches,
        workflow_state=_text(record, "workflow_state", "a conversation", "idle"),
    )
    observations = tuple(
        observation_from_json(item) for item in _members(record, "observations", "a conversation")
    )
    return conversation, observations


def _model_switches(record: dict[str, object]) -> tuple[tuple[str, str], ...]:
    """Read both spellings of a model switch, in the order the document holds.

    `Conversation.model_switches` is a tuple of pairs and JSON has no tuple, so
    `conversation_to_json` writes each pair as a two-element array. The object
    form with named `switched_utc` and `model_id` fields is admitted beside it,
    because a hand-written import document reads better with names.
    """
    value = record.get("model_switches", [])
    if not isinstance(value, list):
        raise DocumentRefused("a conversation names model_switches as something other than a list")
    switches: list[tuple[str, str]] = []
    for item in cast(list[object], value):
        if isinstance(item, dict):
            member = cast(dict[str, object], item)
            switches.append(
                (
                    _text(member, "switched_utc", "a model switch"),
                    _text(member, "model_id", "a model switch"),
                )
            )
            continue
        if (
            not isinstance(item, list)
            or len(cast(list[object], item)) != 2
            or not all(isinstance(part, str) for part in cast(list[object], item))
        ):
            raise DocumentRefused(
                "a conversation names a model switch outside the [utc, model_id] form"
            )
        first, second = cast(list[str], item)
        switches.append((first, second))
    return tuple(switches)


class ConversationStore:
    """Every saved conversation, in one SQLite database under the state directory.

    A connection is thread-local: `sqlite3.Connection` objects refuse a call
    from a thread other than the one that opened them, and the gateway serves
    each request on its own thread. Every connection carries the same
    `busy_timeout`, so a second writer waits for the first to commit rather
    than raising, and every write runs inside `BEGIN IMMEDIATE`, which takes
    the write lock before the read it decides on.
    """

    def __init__(
        self,
        state_directory: Path,
        *,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.state_directory = state_directory
        self.clock = clock
        self.path = state_directory / DATABASE_FILE_NAME
        self._local = threading.local()
        state_directory.mkdir(parents=True, exist_ok=True)
        self.migrate()

    # Connections and schema.

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, timeout=BUSY_TIMEOUT_SECONDS, isolation_level=None)
        connection.execute(f"PRAGMA busy_timeout = {BUSY_TIMEOUT_MS}")
        connection.execute("PRAGMA journal_mode = WAL")
        self.path.chmod(DATABASE_FILE_MODE)
        return connection

    @property
    def connection(self) -> sqlite3.Connection:
        held = getattr(self._local, "connection", None)
        if isinstance(held, sqlite3.Connection):
            return held
        connection = self._connect()
        self._local.connection = connection
        return connection

    def close(self) -> None:
        """Close the calling thread's connection.

        `sqlite3.Connection` refuses every call from a thread other than the
        one that opened it, `close` included, so a connection is released by
        its own thread: this call releases the caller's, and a worker thread's
        connection is released when that thread's local storage is.
        """
        held = getattr(self._local, "connection", None)
        if isinstance(held, sqlite3.Connection):
            held.close()
            self._local.connection = None

    def user_version(self) -> int:
        row = self.connection.execute("PRAGMA user_version").fetchone()
        return int(row[0])

    def migrate(self) -> int:
        """Apply every migration past the recorded version and return the new one.

        Each step runs inside one transaction that carries its own version
        bump, so an interrupted run leaves the database at the version it
        arrived with rather than at a half-applied schema. A `CREATE TABLE`
        here is plain rather than `IF NOT EXISTS`: a predecessor file holding
        a table of one of these names with another shape would be adopted
        silently and fail at the first insert, so the collision refuses now
        and names the table.
        """
        connection = self.connection
        version = self.user_version()
        for migration in MIGRATIONS:
            if migration.version <= version:
                continue
            connection.execute("BEGIN IMMEDIATE")
            try:
                for statement in migration.statements:
                    connection.execute(statement)
                # The version is this module's own integer rather than a
                # caller value, and PRAGMA takes no bound parameter.
                connection.execute(f"PRAGMA user_version = {int(migration.version)}")
                connection.execute("COMMIT")
            except sqlite3.OperationalError as collision:
                connection.execute("ROLLBACK")
                raise SchemaCollision(
                    f"the database at {self.path} refuses schema version "
                    f"{migration.version}: {collision}"
                ) from collision
            except BaseException:
                connection.execute("ROLLBACK")
                raise
            version = migration.version
        return version

    # Reads.

    def _header(self, row: Sequence[object]) -> Conversation:
        return Conversation(
            conversation_id=str(row[0]),
            mode="saved",
            title=str(row[2]),
            created_utc=str(row[3]),
            updated_utc=str(row[4]),
            workflow_state=str(row[5]),
        )

    def list(self, *, with_messages: bool = False) -> tuple[Conversation, ...]:
        """Every saved conversation, most recently updated first.

        The default answers header rows: messages, tool events, attachments,
        and model switches stay empty, because a listing renders titles and
        timestamps and a transcript read belongs to `get`.
        """
        rows = self.connection.execute(
            "SELECT conversation_id, mode, title, created_utc, updated_utc, workflow_state"
            " FROM conversations ORDER BY updated_utc DESC, conversation_id ASC"
        ).fetchall()
        if not with_messages:
            return tuple(self._header(row) for row in rows)
        return tuple(self.get(str(row[0])) for row in rows)

    def get(self, conversation_id: str) -> Conversation:
        """One whole conversation: its header, its transcript, and its switches."""
        connection = self.connection
        row = connection.execute(
            "SELECT conversation_id, mode, title, created_utc, updated_utc, workflow_state"
            " FROM conversations WHERE conversation_id = ?",
            (conversation_id,),
        ).fetchone()
        if row is None:
            raise UnknownConversation(f"no conversation is stored under {conversation_id!r}")
        header = self._header(row)
        tool_events: dict[int, list[ToolEvent]] = {}
        for event in connection.execute(
            "SELECT position, tool_id, origin, arguments_sha256, outcome, result_sha256, detail"
            " FROM tool_events WHERE conversation_id = ? ORDER BY position, ordinal",
            (conversation_id,),
        ):
            tool_events.setdefault(int(event[0]), []).append(
                ToolEvent(
                    tool_id=str(event[1]),
                    origin=cast(Literal["user", "model"], str(event[2])),
                    arguments_sha256=str(event[3]),
                    outcome=cast(
                        Literal["proposed", "approved", "refused", "completed", "failed"],
                        str(event[4]),
                    ),
                    result_sha256=str(event[5]),
                    detail=str(event[6]),
                )
            )
        attachments: dict[int, list[AttachmentRef]] = {}
        for item in connection.execute(
            "SELECT position, name, media_type, sha256, byte_count"
            " FROM attachments WHERE conversation_id = ? ORDER BY position, ordinal",
            (conversation_id,),
        ):
            attachments.setdefault(int(item[0]), []).append(
                AttachmentRef(
                    name=str(item[1]),
                    media_type=str(item[2]),
                    sha256=str(item[3]),
                    byte_count=int(item[4]),
                )
            )
        notes: dict[int, str] = {}
        for note in connection.execute(
            "SELECT position, note FROM observations"
            " WHERE conversation_id = ? AND position IS NOT NULL ORDER BY ordinal",
            (conversation_id,),
        ):
            notes[int(note[0])] = str(note[1])
        messages: list[Message] = []
        for row_message in connection.execute(
            "SELECT position, role, content, created_utc, served_model, reasoning_shown,"
            " sources, artifacts FROM messages WHERE conversation_id = ? ORDER BY position",
            (conversation_id,),
        ):
            position = int(row_message[0])
            messages.append(
                Message(
                    role=cast(Role, str(row_message[1])),
                    content=str(row_message[2]),
                    created_utc=str(row_message[3]),
                    served_model=str(row_message[4]),
                    reasoning_shown=bool(row_message[5]),
                    tool_events=tuple(tool_events.get(position, ())),
                    sources=tuple(_decode_strings(str(row_message[6]))),
                    artifacts=tuple(_decode_strings(str(row_message[7]))),
                    attachments=tuple(attachments.get(position, ())),
                    truncation_note=notes.get(position, ""),
                )
            )
        switches = tuple(
            (str(switch[0]), str(switch[1]))
            for switch in connection.execute(
                "SELECT switched_utc, model_id FROM model_switches"
                " WHERE conversation_id = ? ORDER BY ordinal",
                (conversation_id,),
            )
        )
        return Conversation(
            conversation_id=header.conversation_id,
            mode="saved",
            title=header.title,
            created_utc=header.created_utc,
            updated_utc=header.updated_utc,
            messages=tuple(messages),
            model_switches=switches,
            workflow_state=header.workflow_state,
        )

    def message_counts(self) -> dict[str, int]:
        """How many messages each saved conversation holds, in one grouped read.

        A header row from `list` carries an empty transcript, so a listing
        reads its counts here rather than from the length of a tuple it did
        not fetch.
        """
        return {
            str(row[0]): int(row[1])
            for row in self.connection.execute(
                "SELECT conversation_id, COUNT(*) FROM messages GROUP BY conversation_id"
            )
        }

    def observations(self, conversation_id: str) -> tuple[Observation, ...]:
        """The conversation-scope notes: every observation carrying no position."""
        return tuple(
            Observation(
                kind=cast(ObservationKind, str(row[0])),
                note=str(row[1]),
                recorded_utc=str(row[2]),
            )
            for row in self.connection.execute(
                "SELECT kind, note, recorded_utc FROM observations"
                " WHERE conversation_id = ? AND position IS NULL ORDER BY ordinal",
                (conversation_id,),
            )
        )

    # Writes.

    def create(
        self,
        title: str,
        *,
        mode: str = "saved",
        conversation_id: str | None = None,
        workflow_state: str = "idle",
    ) -> Conversation:
        """Open one saved conversation and return the record it starts as.

        The store refuses `temporary`: a temporary transcript lives in
        `web/conversations.py`'s in-memory registry and under
        `tmp/conversations/<id>/`, and never reaches a row here. Mode is fixed
        at creation for the same reason -- the two modes have different homes,
        so a mode change would be a move rather than an update.
        """
        if mode != "saved":
            raise DocumentRefused(
                f"the store holds saved conversations and refuses the mode {mode!r}; "
                "a temporary conversation lives in memory and under tmp/conversations/"
            )
        stamp = utc_stamp(self.clock())
        identifier = conversation_id or new_conversation_id()
        connection = self.connection
        connection.execute("BEGIN IMMEDIATE")
        try:
            connection.execute(
                "INSERT INTO conversations (conversation_id, mode, title, created_utc,"
                " updated_utc, workflow_state) VALUES (?, 'saved', ?, ?, ?, ?)",
                (identifier, title, stamp, stamp, workflow_state),
            )
            connection.execute("COMMIT")
        except sqlite3.IntegrityError as collision:
            connection.execute("ROLLBACK")
            raise DocumentRefused(
                f"a conversation is already stored under {identifier!r}"
            ) from collision
        except BaseException:
            connection.execute("ROLLBACK")
            raise
        return Conversation(
            conversation_id=identifier,
            mode="saved",
            title=title,
            created_utc=stamp,
            updated_utc=stamp,
            workflow_state=workflow_state,
        )

    def rename(self, conversation_id: str, title: str) -> Conversation:
        """Set the title and the update stamp, leaving the transcript untouched."""
        stamp = utc_stamp(self.clock())
        connection = self.connection
        connection.execute("BEGIN IMMEDIATE")
        try:
            changed = connection.execute(
                "UPDATE conversations SET title = ?, updated_utc = ? WHERE conversation_id = ?",
                (title, stamp, conversation_id),
            ).rowcount
            connection.execute("COMMIT")
        except BaseException:
            connection.execute("ROLLBACK")
            raise
        if changed == 0:
            raise UnknownConversation(f"no conversation is stored under {conversation_id!r}")
        return self.get(conversation_id)

    def delete(self, conversation_id: str) -> tuple[str, ...]:
        """Remove the conversation and every row of it, and report freed digests.

        The return is the attachment digests the deletion left unreferenced:
        a digest another conversation still names stays out of it, so a caller
        collecting artifacts acts on digests nothing references rather than on
        digests this conversation happened to hold. The surviving-reference
        read runs inside the same transaction as the delete, so a concurrent
        append cannot land a reference between the two.
        """
        connection = self.connection
        connection.execute("BEGIN IMMEDIATE")
        try:
            present = connection.execute(
                "SELECT 1 FROM conversations WHERE conversation_id = ?", (conversation_id,)
            ).fetchone()
            if present is None:
                raise UnknownConversation(f"no conversation is stored under {conversation_id!r}")
            held = {
                str(row[0])
                for row in connection.execute(
                    "SELECT DISTINCT sha256 FROM attachments WHERE conversation_id = ?",
                    (conversation_id,),
                )
            }
            for table in (
                "tool_events",
                "attachments",
                "observations",
                "model_switches",
                "messages",
                "conversations",
            ):
                connection.execute(_DELETE_BY_CONVERSATION[table], (conversation_id,))
            surviving = {
                str(row[0]) for row in connection.execute("SELECT DISTINCT sha256 FROM attachments")
            }
            connection.execute("COMMIT")
        except BaseException:
            connection.execute("ROLLBACK")
            raise
        return tuple(sorted(held - surviving))

    def append_message(self, conversation_id: str, message: Message) -> int:
        """Append one message and return the position it took.

        `BEGIN IMMEDIATE` takes the write lock before the `max(position)`
        read, so two threads appending to one conversation take consecutive
        positions rather than reading one count and both writing it back. The
        absent-row check raises `UnknownConversation` without rolling back
        itself: the outer `except BaseException` is the one rollback every
        path here shares, and a second `ROLLBACK` issued ahead of it meets no
        open transaction and raises its own `OperationalError`, which is what
        reached a caller here before this rolled the check into the one path.
        """
        stamp = utc_stamp(self.clock())
        connection = self.connection
        connection.execute("BEGIN IMMEDIATE")
        try:
            present = connection.execute(
                "SELECT 1 FROM conversations WHERE conversation_id = ?", (conversation_id,)
            ).fetchone()
            if present is None:
                raise UnknownConversation(f"no conversation is stored under {conversation_id!r}")
            row = connection.execute(
                "SELECT COALESCE(MAX(position) + 1, 0) FROM messages WHERE conversation_id = ?",
                (conversation_id,),
            ).fetchone()
            position = int(row[0])
            self._write_message(connection, conversation_id, position, message)
            connection.execute(
                "UPDATE conversations SET updated_utc = ? WHERE conversation_id = ?",
                (stamp, conversation_id),
            )
            connection.execute("COMMIT")
        except BaseException:
            connection.execute("ROLLBACK")
            raise
        return position

    def _write_message(
        self,
        connection: sqlite3.Connection,
        conversation_id: str,
        position: int,
        message: Message,
    ) -> None:
        connection.execute(
            "INSERT INTO messages (conversation_id, position, role, content, created_utc,"
            " served_model, reasoning_shown, sources, artifacts)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                conversation_id,
                position,
                message.role,
                message.content,
                message.created_utc,
                message.served_model,
                int(message.reasoning_shown),
                _encode_strings(message.sources),
                _encode_strings(message.artifacts),
            ),
        )
        for ordinal, event in enumerate(message.tool_events):
            connection.execute(
                "INSERT INTO tool_events (conversation_id, position, ordinal, tool_id, origin,"
                " arguments_sha256, outcome, result_sha256, detail)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    conversation_id,
                    position,
                    ordinal,
                    event.tool_id,
                    event.origin,
                    event.arguments_sha256,
                    event.outcome,
                    event.result_sha256,
                    event.detail,
                ),
            )
        for ordinal, attachment in enumerate(message.attachments):
            connection.execute(
                "INSERT INTO attachments (conversation_id, position, ordinal, name, media_type,"
                " sha256, byte_count) VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    conversation_id,
                    position,
                    ordinal,
                    attachment.name,
                    attachment.media_type,
                    attachment.sha256,
                    attachment.byte_count,
                ),
            )
        if message.truncation_note:
            self._write_observation(
                connection,
                conversation_id,
                Observation("truncation", message.truncation_note, message.created_utc),
                position=position,
            )

    def _write_observation(
        self,
        connection: sqlite3.Connection,
        conversation_id: str,
        observation: Observation,
        *,
        position: int | None,
    ) -> None:
        row = connection.execute(
            "SELECT COALESCE(MAX(ordinal) + 1, 0) FROM observations WHERE conversation_id = ?",
            (conversation_id,),
        ).fetchone()
        connection.execute(
            "INSERT INTO observations (conversation_id, ordinal, position, kind, note,"
            " recorded_utc) VALUES (?, ?, ?, ?, ?, ?)",
            (
                conversation_id,
                int(row[0]),
                position,
                observation.kind,
                observation.note,
                observation.recorded_utc,
            ),
        )

    def record_observation(self, conversation_id: str, kind: str, note: str) -> Observation:
        """Record one conversation-scope note: a truncation or a checkpoint.

        A note attached to a message travels as that message's
        `truncation_note`, so this method writes rows carrying no position and
        the two sets stay disjoint, which is what keeps an export from
        carrying one note twice.
        """
        if kind not in OBSERVATION_KINDS:
            raise DocumentRefused(
                f"an observation names the kind {kind!r}; "
                f"the store admits {sorted(OBSERVATION_KINDS)}"
            )
        observation = Observation(cast(ObservationKind, kind), note, utc_stamp(self.clock()))
        connection = self.connection
        connection.execute("BEGIN IMMEDIATE")
        try:
            present = connection.execute(
                "SELECT 1 FROM conversations WHERE conversation_id = ?", (conversation_id,)
            ).fetchone()
            if present is None:
                raise UnknownConversation(f"no conversation is stored under {conversation_id!r}")
            self._write_observation(connection, conversation_id, observation, position=None)
            connection.execute("COMMIT")
        except BaseException:
            connection.execute("ROLLBACK")
            raise
        return observation

    def record_model_switch(self, conversation_id: str, model_id: str) -> tuple[str, str]:
        """Record the model a conversation switched to, and return the pair stored."""
        stamp = utc_stamp(self.clock())
        connection = self.connection
        connection.execute("BEGIN IMMEDIATE")
        try:
            present = connection.execute(
                "SELECT 1 FROM conversations WHERE conversation_id = ?", (conversation_id,)
            ).fetchone()
            if present is None:
                raise UnknownConversation(f"no conversation is stored under {conversation_id!r}")
            row = connection.execute(
                "SELECT COALESCE(MAX(ordinal) + 1, 0) FROM model_switches"
                " WHERE conversation_id = ?",
                (conversation_id,),
            ).fetchone()
            connection.execute(
                "INSERT INTO model_switches (conversation_id, ordinal, switched_utc, model_id)"
                " VALUES (?, ?, ?, ?)",
                (conversation_id, int(row[0]), stamp, model_id),
            )
            connection.execute(
                "UPDATE conversations SET updated_utc = ? WHERE conversation_id = ?",
                (stamp, conversation_id),
            )
            connection.execute("COMMIT")
        except BaseException:
            connection.execute("ROLLBACK")
            raise
        return (stamp, model_id)

    # The portable document.

    def export(self, conversation_id: str) -> dict[str, object]:
        """One conversation as the versioned document `import_document` reads."""
        return self._document([self.get(conversation_id)])

    def export_all(self) -> dict[str, object]:
        """Every saved conversation as one versioned document."""
        return self._document(self.list(with_messages=True))

    def _document(self, conversations: Iterable[Conversation]) -> dict[str, object]:
        return {
            "document_version": DOCUMENT_VERSION,
            "exported_utc": utc_stamp(self.clock()),
            "conversations": [
                conversation_to_json(conversation, self.observations(conversation.conversation_id))
                for conversation in conversations
            ],
        }

    def import_document(self, doc: object) -> ConversationIds:
        """Write every conversation the document carries and return their ids.

        Three refusals run before the first row is written: a
        `document_version` outside `DOCUMENT_VERSIONS`, a key named like a
        credential anywhere in the document, and an identifier the store
        already holds. The whole document then lands inside one transaction,
        so a refusal on the last conversation leaves none of the earlier ones
        behind.
        """
        document = _object(doc, "an import document")
        version = document.get("document_version")
        if not isinstance(version, int) or isinstance(version, bool):
            raise DocumentRefused("an import document names no integer document_version")
        if version not in DOCUMENT_VERSIONS:
            raise DocumentRefused(
                f"an import document names version {version}; this store reads "
                f"{list(DOCUMENT_VERSIONS)}"
            )
        offending = credential_keys(document)
        if offending:
            raise DocumentRefused(
                "an import document carries a key named like a credential at "
                f"{offending[0]}; the closed list is {list(CREDENTIAL_KEY_TERMS)} and a "
                "reusable grant, a session secret, and a bearer are never persistable"
            )
        records = [
            conversation_from_json(item)
            for item in _members(document, "conversations", "an import document")
        ]
        connection = self.connection
        connection.execute("BEGIN IMMEDIATE")
        try:
            imported: list[str] = []
            for conversation, observations in records:
                self._import_one(connection, conversation, observations)
                imported.append(conversation.conversation_id)
            connection.execute("COMMIT")
        except sqlite3.IntegrityError as collision:
            connection.execute("ROLLBACK")
            raise DocumentRefused(
                f"the import names a conversation the store already holds: {collision}"
            ) from collision
        except BaseException:
            connection.execute("ROLLBACK")
            raise
        return imported

    def _import_one(
        self,
        connection: sqlite3.Connection,
        conversation: Conversation,
        observations: Sequence[Observation],
    ) -> None:
        connection.execute(
            "INSERT INTO conversations (conversation_id, mode, title, created_utc,"
            " updated_utc, workflow_state) VALUES (?, 'saved', ?, ?, ?, ?)",
            (
                conversation.conversation_id,
                conversation.title,
                conversation.created_utc,
                conversation.updated_utc,
                conversation.workflow_state,
            ),
        )
        for position, message in enumerate(conversation.messages):
            self._write_message(connection, conversation.conversation_id, position, message)
        for observation in observations:
            self._write_observation(
                connection, conversation.conversation_id, observation, position=None
            )
        for ordinal, (switched_utc, model_id) in enumerate(conversation.model_switches):
            connection.execute(
                "INSERT INTO model_switches (conversation_id, ordinal, switched_utc, model_id)"
                " VALUES (?, ?, ?, ?)",
                (conversation.conversation_id, ordinal, switched_utc, model_id),
            )


# One statement per table, written out rather than formatted from the name,
# so no delete statement is ever built from a value.
_DELETE_BY_CONVERSATION: dict[str, str] = {
    "tool_events": "DELETE FROM tool_events WHERE conversation_id = ?",
    "attachments": "DELETE FROM attachments WHERE conversation_id = ?",
    "observations": "DELETE FROM observations WHERE conversation_id = ?",
    "model_switches": "DELETE FROM model_switches WHERE conversation_id = ?",
    "messages": "DELETE FROM messages WHERE conversation_id = ?",
    "conversations": "DELETE FROM conversations WHERE conversation_id = ?",
}


def _encode_strings(values: Sequence[str]) -> str:
    """Store an ordered list of opaque strings as one JSON array.

    `sources` and `artifacts` carry URLs and artifact digests with no fields of
    their own, so a row per element would declare a table holding one column
    and an ordinal. The six tables the schema names carry the record's
    structured parts; these two stay in the message row they belong to.
    """
    return json.dumps(list(values), separators=(",", ":"))


def _decode_strings(encoded: str) -> list[str]:
    loaded = json.loads(encoded) if encoded else []
    if not isinstance(loaded, list):
        return []
    return [str(item) for item in cast(list[object], loaded)]
