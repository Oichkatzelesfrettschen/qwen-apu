"""The conversation routes and the temporary transcripts that never reach disk.

Every path here is mounted on the gateway's one origin and passes an injected
session check that refuses by default, the arrangement `web/artifacts.py` and
`tools/approvals.py` already use: the gateway injects
`web.auth.SessionGate.require_session` when it assembles, and a deployment
that has yet to arm a session refuses rather than reading an absent check as
an admission. The handlers state their own refusals as responses, so a rule
tests without a listener.

A conversation is saved or temporary and stays what it was created as. A saved
conversation lives in `web/history.py`'s SQLite database; a temporary one
lives in `TemporaryConversations`, whose transcript is a tuple in memory and
whose uploads and artifacts live under `<tmp>/conversations/<ephemeral-id>/`.
`close`, `expire`, and `shutdown` remove that directory whole. The two modes
therefore have different homes rather than different flags, which is why
`PATCH` refuses a body carrying `mode` on the key's presence rather than on
its value: a mode change is a move between two stores, not a field update.

`GET /api/conversations/export` and `POST /api/conversations/import` are
registered ahead of the identifier routes, and the identifier pattern is 32
hexadecimal characters, so `export` and `import` are unmatchable as
identifiers whatever order a later edit puts the tuple in.
"""

from __future__ import annotations

import shutil
import sqlite3
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass, replace
from pathlib import Path

from qwen_apu.tools.approvals import SessionCheck, refuse_every_session
from qwen_apu.web.app import RequestRefused
from qwen_apu.web.history import (
    ConversationStore,
    DocumentRefused,
    UnknownConversation,
    conversation_to_json,
    message_from_json,
    new_conversation_id,
    utc_stamp,
)
from qwen_apu.web.history_model import Conversation, Message
from qwen_apu.web.http import Request, Response, Route

CONVERSATIONS_PATH = "/api/conversations"
EXPORT_PATH = "/api/conversations/export"
IMPORT_PATH = "/api/conversations/import"

# An identifier is `uuid.uuid4().hex`, so the route admits 32 hexadecimal
# characters and nothing else.
IDENTIFIER_PATTERN = r"(?P<conversation_id>[0-9a-f]{32})"
CONVERSATION_PATH = f"{CONVERSATIONS_PATH}/{IDENTIFIER_PATTERN}"
MESSAGES_PATH = f"{CONVERSATION_PATH}/messages"

TEMPORARY_DIRECTORY_NAME = "conversations"
TEMPORARY_DIRECTORY_MODE = 0o700
TEMPORARY_LIFETIME_SECONDS = 12 * 3600

MODES: frozenset[str] = frozenset({"saved", "temporary"})


@dataclass
class _Temporary:
    """One live temporary conversation: its record and the stamp `expire` reads."""

    conversation: Conversation
    touched: float


class TemporaryConversations:
    """Transcripts held in memory, with one scratch directory each.

    A temporary conversation reaches no SQLite row: `open` mints an ephemeral
    identifier, `append` extends a tuple this registry holds, and the uploads
    and artifacts a turn produces live under
    `<tmp>/conversations/<ephemeral-id>/`. `close(id)`, `expire(now)`, and
    `shutdown()` each remove that directory whole and drop the record, so the
    end of a temporary conversation is the end of every byte it wrote.
    """

    def __init__(
        self,
        tmp_directory: Path,
        *,
        lifetime_s: float = TEMPORARY_LIFETIME_SECONDS,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.tmp_directory = tmp_directory
        self.root = tmp_directory / TEMPORARY_DIRECTORY_NAME
        self.lifetime_s = lifetime_s
        self.clock = clock
        self._live: dict[str, _Temporary] = {}
        self._lock = threading.Lock()

    def directory(self, conversation_id: str) -> Path:
        """The scratch directory one temporary conversation owns.

        The name is the ephemeral identifier itself, checked against the
        identifier alphabet before it becomes a path component, so the
        directory `close` removes is always a direct child of the registry
        root rather than a name a caller steered elsewhere.
        """
        if not _is_identifier(conversation_id):
            raise DocumentRefused(f"{conversation_id!r} is not a conversation identifier")
        return self.root / conversation_id

    def open(self, title: str) -> Conversation:
        """Mint one temporary conversation and lay out its directory at mode 0700."""
        now = self.clock()
        stamp = utc_stamp(now)
        conversation_id = new_conversation_id()
        directory = self.directory(conversation_id)
        directory.mkdir(parents=True, exist_ok=True)
        directory.chmod(TEMPORARY_DIRECTORY_MODE)
        conversation = Conversation(
            conversation_id=conversation_id,
            mode="temporary",
            title=title,
            created_utc=stamp,
            updated_utc=stamp,
        )
        with self._lock:
            self._live[conversation_id] = _Temporary(conversation, now)
        return conversation

    def holds(self, conversation_id: str) -> bool:
        with self._lock:
            return conversation_id in self._live

    def identifiers(self) -> tuple[str, ...]:
        with self._lock:
            return tuple(self._live)

    def get(self, conversation_id: str) -> Conversation:
        with self._lock:
            return self._held(conversation_id).conversation

    def rename(self, conversation_id: str, title: str) -> Conversation:
        now = self.clock()
        with self._lock:
            held = self._held(conversation_id)
            held.conversation = replace(held.conversation, title=title, updated_utc=utc_stamp(now))
            held.touched = now
            return held.conversation

    def append(self, conversation_id: str, message: Message) -> int:
        """Extend the in-memory transcript and return the position the message took.

        The read of the transcript and the write of the extended one happen
        under one lock, so two requests appending to one conversation take
        consecutive positions rather than both reading the same tuple and the
        second assignment dropping the first message. The gateway serves each
        request on its own thread, which is what makes that reachable.
        """
        now = self.clock()
        with self._lock:
            held = self._held(conversation_id)
            messages = (*held.conversation.messages, message)
            held.conversation = replace(
                held.conversation, messages=messages, updated_utc=utc_stamp(now)
            )
            held.touched = now
            return len(messages) - 1

    def close(self, conversation_id: str) -> None:
        """Drop the transcript and remove the scratch directory whole."""
        with self._lock:
            self._close_held(conversation_id)

    def _held(self, conversation_id: str) -> _Temporary:
        held = self._live.get(conversation_id)
        if held is None:
            raise UnknownConversation(
                f"no temporary conversation is open under {conversation_id!r}"
            )
        return held

    def _close_held(self, conversation_id: str) -> None:
        """Remove one conversation's directory and record, with the lock held.

        `shutil.rmtree` raises on a directory it leaves behind -- a file it
        cannot unlink, a mode it cannot traverse -- so a partial removal
        reaches the caller rather than answering as a whole one. The absent
        directory is the one stated exception, since it is the state this call
        establishes.
        """
        directory = self.directory(conversation_id)
        self._held(conversation_id)
        try:
            shutil.rmtree(directory)
        except FileNotFoundError:
            pass
        del self._live[conversation_id]

    def expire(self, now: float) -> tuple[str, ...]:
        """Close every conversation untouched for its lifetime, and name them.

        The deadline runs from the last append or rename rather than from the
        open, so a conversation in use stays open and an abandoned one takes
        its directory with it at the next sweep.
        """
        with self._lock:
            expired = tuple(
                conversation_id
                for conversation_id, held in self._live.items()
                if now - held.touched >= self.lifetime_s
            )
            for conversation_id in expired:
                self._close_held(conversation_id)
        return expired

    def shutdown(self) -> tuple[str, ...]:
        """Close every live conversation, which is what a gateway stop owes them."""
        with self._lock:
            closing = tuple(self._live)
            for conversation_id in closing:
                self._close_held(conversation_id)
        return closing


@dataclass(frozen=True)
class ConversationSettings:
    """The store, the temporary registry, and the session verdict the routes read."""

    store: ConversationStore
    temporary: TemporaryConversations
    session_check: SessionCheck = refuse_every_session


def _is_identifier(value: str) -> bool:
    return len(value) == 32 and all(character in "0123456789abcdef" for character in value)


def summary(conversation: Conversation, message_count: int | None = None) -> dict[str, object]:
    """The header a listing renders: the transcript stays with `GET /<id>`.

    A header row from the store carries an empty transcript, so the count
    comes from `ConversationStore.message_counts` where a caller passes one
    and from the tuple in hand otherwise.
    """
    return {
        "conversation_id": conversation.conversation_id,
        "mode": conversation.mode,
        "title": conversation.title,
        "created_utc": conversation.created_utc,
        "updated_utc": conversation.updated_utc,
        "workflow_state": conversation.workflow_state,
        "message_count": len(conversation.messages) if message_count is None else message_count,
    }


def _body(request: Request) -> dict[str, object]:
    try:
        payload = request.json()
    except ValueError as malformed:
        raise DocumentRefused(f"the request body is not JSON: {malformed}") from malformed
    if not isinstance(payload, dict):
        raise DocumentRefused("the request body is not a JSON object")
    return {str(key): value for key, value in payload.items()}


def _title(payload: dict[str, object], default: str = "") -> str:
    title = payload.get("title", default)
    if not isinstance(title, str):
        raise DocumentRefused("the request body names a title that is not a string")
    return title


Work = Callable[[ConversationSettings, Request], Response]


def _answer(settings: ConversationSettings, request: Request, work: Work) -> Response:
    """Run the session check, then the handler, and state every refusal as a status.

    The check runs ahead of every lookup, so a present identifier and an absent
    one answer 401 alike and the routes are no existence oracle for a caller
    holding no session.

    `sqlite3.Error` reaches here uncaught where the database file or its
    directory refuses a write -- a read-only mode bit, a full filesystem, a
    lock another process holds past the busy timeout -- and every write in
    `web/history.py` runs inside `BEGIN IMMEDIATE` with its own rollback, so
    the transaction that failed leaves no partial row behind. Answering 500
    here is what keeps that failure a status the caller reads rather than a
    dropped connection that leaves the caller unable to tell a failed save
    from a save the network lost.
    """
    verdict = settings.session_check(request)
    if not verdict.admitted:
        return Response.json({"error": verdict.reason}, status=401)
    try:
        return work(settings, request)
    except UnknownConversation as absent:
        return Response.json({"error": str(absent)}, status=404)
    except DocumentRefused as refused:
        return Response.json({"error": str(refused)}, status=400)
    except RequestRefused as refusal:
        return Response.json({"error": refusal.message}, status=refusal.status)
    except sqlite3.Error as storage_failure:
        return Response.json(
            {"error": f"the conversation store refused the write: {storage_failure}"}, status=500
        )


def _listing(settings: ConversationSettings, request: Request) -> Response:
    """Every conversation the gateway holds, the live temporary ones first.

    A temporary conversation exists for this process alone, so it heads the
    listing where the operator is working; the saved rows follow in the order
    the store reads them, most recently updated first.
    """
    del request
    temporary = [
        summary(settings.temporary.get(identifier))
        for identifier in settings.temporary.identifiers()
    ]
    counts = settings.store.message_counts()
    saved = [
        summary(conversation, counts.get(conversation.conversation_id, 0))
        for conversation in settings.store.list()
    ]
    return Response.json({"conversations": temporary + saved})


def _create(settings: ConversationSettings, request: Request) -> Response:
    payload = _body(request)
    mode = payload.get("mode", "saved")
    if not isinstance(mode, str) or mode not in MODES:
        raise DocumentRefused(f"the request names the mode {mode!r}; the modes are {sorted(MODES)}")
    title = _title(payload)
    if mode == "temporary":
        opened = settings.temporary.open(title)
        return Response.json(conversation_to_json(opened), status=201)
    created = settings.store.create(title)
    return Response.json(conversation_to_json(created), status=201)


def _identifier(request: Request) -> str:
    return request.path_params["conversation_id"]


def _read(settings: ConversationSettings, request: Request) -> Response:
    conversation_id = _identifier(request)
    if settings.temporary.holds(conversation_id):
        return Response.json(conversation_to_json(settings.temporary.get(conversation_id)))
    conversation = settings.store.get(conversation_id)
    observations = settings.store.observations(conversation_id)
    return Response.json(conversation_to_json(conversation, observations))


def _rename(settings: ConversationSettings, request: Request) -> Response:
    conversation_id = _identifier(request)
    payload = _body(request)
    if "mode" in payload:
        raise DocumentRefused(
            "a conversation never changes mode after creation: a saved conversation "
            "lives in the database and a temporary one lives in memory and under "
            "tmp/conversations/, so a mode change is a move rather than an update"
        )
    if "title" not in payload:
        raise DocumentRefused("the request body names no title")
    title = _title(payload)
    if settings.temporary.holds(conversation_id):
        return Response.json(
            conversation_to_json(settings.temporary.rename(conversation_id, title))
        )
    return Response.json(conversation_to_json(settings.store.rename(conversation_id, title)))


def _delete(settings: ConversationSettings, request: Request) -> Response:
    """Remove one conversation, and report what a caller may now collect.

    A temporary conversation's bytes leave with its directory, so the answer
    names no digest; a saved one answers the attachment digests its deletion
    left unreferenced.
    """
    conversation_id = _identifier(request)
    if settings.temporary.holds(conversation_id):
        settings.temporary.close(conversation_id)
        return Response.json({"deleted": conversation_id, "attachment_digests": []})
    freed = settings.store.delete(conversation_id)
    return Response.json({"deleted": conversation_id, "attachment_digests": list(freed)})


def _append(settings: ConversationSettings, request: Request) -> Response:
    conversation_id = _identifier(request)
    message = message_from_json(_body(request))
    if settings.temporary.holds(conversation_id):
        position = settings.temporary.append(conversation_id, message)
    else:
        position = settings.store.append_message(conversation_id, message)
    return Response.json({"conversation_id": conversation_id, "position": position}, status=201)


def _export(settings: ConversationSettings, request: Request) -> Response:
    """The saved transcripts alone: a temporary one exports nothing by design."""
    del request
    return Response.json(settings.store.export_all())


def _import(settings: ConversationSettings, request: Request) -> Response:
    imported = settings.store.import_document(_body(request))
    return Response.json({"imported": imported}, status=201)


def routes(settings: ConversationSettings) -> tuple[Route, ...]:
    """The conversation routes, export and import ahead of the identifier ones."""
    return (
        Route.make("GET", EXPORT_PATH, lambda request: _answer(settings, request, _export)),
        Route.make("POST", IMPORT_PATH, lambda request: _answer(settings, request, _import)),
        Route.make("GET", CONVERSATIONS_PATH, lambda request: _answer(settings, request, _listing)),
        Route.make("POST", CONVERSATIONS_PATH, lambda request: _answer(settings, request, _create)),
        Route.make("GET", CONVERSATION_PATH, lambda request: _answer(settings, request, _read)),
        Route.make("PATCH", CONVERSATION_PATH, lambda request: _answer(settings, request, _rename)),
        Route.make(
            "DELETE", CONVERSATION_PATH, lambda request: _answer(settings, request, _delete)
        ),
        Route.make("POST", MESSAGES_PATH, lambda request: _answer(settings, request, _append)),
    )


def build(
    state_directory: Path,
    tmp_directory: Path,
    session_check: SessionCheck = refuse_every_session,
    *,
    lifetime_s: float = TEMPORARY_LIFETIME_SECONDS,
) -> ConversationSettings:
    """Open the store and the registry from the two runtime-root directories.

    `qwen_home_state` holds the database and `qwen_home_tmp` holds the
    temporary scratch, which is the split the runtime root already declares.
    """
    return ConversationSettings(
        store=ConversationStore(state_directory),
        temporary=TemporaryConversations(tmp_directory, lifetime_s=lifetime_s),
        session_check=session_check,
    )
