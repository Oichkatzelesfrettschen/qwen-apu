"""The launch acceptance driver: one named check per claim the appliance makes.

`qwen-apu acceptance run` exercises an already running gateway over its own
origin and writes what it observed. Every item is a named check with one of
three outcomes and the evidence behind it:

    pass     the claim held, and `evidence` carries what made it hold
    fail     the claim was reachable and did not hold
    skipped  the route or the input the claim needs is absent, named in `reason`

The three outcomes are separated because this branch does not mount every route
the appliance will eventually carry, and a report that folded an absent route
into a failure would make a migration look like a regression. The classification
is read from the answer rather than from a table: a 404 on a route the driver
posts to is an unmounted route and the check reports `skipped` naming the path,
while a 401 or 403 is a live gate answering and stays a failure everywhere
except the unauthenticated check, where it is the pass.

Two phases separate what a live gateway can answer from what only a stopped one
can. The live phase runs every route check against the running origin. The
teardown phase runs `--stop-command`, then reads the Vulkan workload lease and
the published appliance record, because an owned process, a socket, or a held
lease is a claim about absence and absence is observable only after the stop. A
run that names no stop argv reports both teardown items as skipped rather than
reading a lease the running server legitimately holds.

The report lands under the runtime root and nowhere else: a JSON document at the
path the caller names and a Markdown rendering beside it, so a receipt is
readable by a person and comparable by a digest.
"""

from __future__ import annotations

import base64
import binascii
import json
import socket
import struct
import subprocess
import time
import uuid
import zlib
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from functools import partial
from http.client import HTTPConnection, HTTPException, HTTPResponse
from pathlib import Path
from urllib.parse import quote, urlsplit

from qwen_apu.config import models as registry
from qwen_apu.runtime import appliance as appliance_state
from qwen_apu.runtime import policy
from qwen_apu.runtime.locks import WorkloadLease
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.process import read_start_time
from qwen_apu.tools.approvals import (
    IMAGE_CLAIM_CONTEXT,
    SESSION_HEADER,
    STALE_SESSION_SECRET_CODE,
    canonical_aspect,
    prompt_digest,
)
from qwen_apu.web import browser_import
from qwen_apu.web.auth import PAIRING_CODE_FILENAME
from qwen_apu.web.history import DOCUMENT_VERSION, conversation_to_json
from qwen_apu.web.roster import ROSTER_STATES, quantization

# The three outcomes a check reports. `PASS` names an outcome rather than a
# credential, so the hardcoded-password rule is answered here rather than by
# spelling the word differently.
PASS = "pass"  # noqa: S105
FAIL = "fail"
SKIPPED = "skipped"

DEFAULT_TEXT_MODELS: tuple[str, ...] = (
    "qwen35-08b",
    "qwen38-2b-distill",
    "qwen38-4b-distill",
)
DEFAULT_VISION_MODELS: tuple[str, ...] = ("lfm25-vl-16b",)
DEFAULT_TIMEOUT_SECONDS = 120.0
DEFAULT_MAX_TOKENS = 48
STREAM_READ_BYTES = 256
# The one request that asks for a long answer. A stream that completes before
# the driver's first read leaves nothing to abandon, so the cancel item would
# pass without ever cancelling anything.
CANCEL_TOKENS = 512
RESTART_SETTLE_SECONDS = 1.0
RESTART_DEADLINE_SECONDS = 180.0

# The prompt every text turn carries. One short, deterministic instruction keeps
# the check about attribution rather than about the answer's content: what the
# item tests is that the reply names the checkpoint the request selected.
TEXT_PROMPT = "Reply with the single word: ready."
VISION_PROMPT = "Name the tallest bar in this chart."

# The substring a document refusal carries when the format's extractor is the
# thing that is missing. `tools/document_worker.py` imports pypdf at call time,
# so a venv without it names the distribution in the refusal.
MISSING_EXTRACTOR_MARKER = "pypdf"

# The one media type long enough to earn a name of its own.
DOCX_MEDIA_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

# The route the page reads the per-launch approval secret from, the header it
# presents it under, and the two signing routes it posts a proposal to.
# `tools/approvals.py` owns all four spellings; the page in `static/js/api.js`
# reads the secret once, holds it in memory, and retries a grant once against a
# freshly read secret when a refusal carries the stale-secret code.
SESSION_ROUTE = "/api/tools/session"
GRANT_ROUTE = "/api/tools/grant"
IMAGE_GRANT_ROUTE = "/api/tools/grant-image"

# `GET /api/tools?model=ID` is the tool matrix and `POST /api/tools` is the
# executor, so one path carries both and the method separates them.
MATRIX_ROUTE = "/api/tools"
TOOLS_ROUTE = "/api/tools"
# The two matrix states that admit a call. Every other state is a lane this
# launch does not execute, and the row's own reason names which party withheld
# it.
EXECUTING_TOOL_STATES: tuple[str, str] = ("available", "available_through_helper")
TEMPORARILY_UNAVAILABLE = "temporarily_unavailable"
SEARCH_TOOL_ROW = "web_search"
IMAGE_GENERATION_ROW = "image_generation"
SEARCH_TOOL = "web_search"
READ_URL_TOOL = "read_url"

# The one query the web lane approves and runs. It names this appliance's own
# subject so a result set is recognizable in the report.
WEB_QUERY = "raven2 vulkan decode throughput"
RESULT_ID_PREFIX = "Result ID: "
# `run_read_url` returns an empty window, and with it the 200 that carries
# `state: incomplete`, for any document shorter than the character cap. The
# probe therefore reads one character at the last admitted offset:
# `start_index + max_chars` equals the cap, which the bound admits.
DOCUMENT_CHARACTER_CAP = 131072
EMPTY_WINDOW_START_INDEX = DOCUMENT_CHARACTER_CAP - 1
EMPTY_WINDOW_CHARACTERS = 1

# The generation the image lane approves. The seed is fixed rather than random
# because the grant binds it and a report states what ran.
IMAGE_PROMPT = "a red square on a white ground"
IMAGE_NEGATIVE_PROMPT = ""
IMAGE_SEED = 7
IMAGE_STEPS = 1
IMAGE_REVIEW_CONSTRAINT = (
    "declared_subject",
    "the image shows a single red square on a white ground",
)
# `POST /api/tools/grant-image` admits one unexpired grant per client address
# and the quota decays with that grant's own term, so the review's own grant
# meets 429 until the generate grant ages out. The driver waits where the
# refusal names a term inside this bound and reports the item skipped naming
# the limit otherwise, because a launch signing a 900-second term would
# otherwise hold an acceptance run for a quarter of an hour.
IMAGE_REVIEW_GRANT_WAIT_SECONDS = 30
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


# The identifier the imported page transcript carries. `web/conversations.py`
# admits 32 hexadecimal characters and nothing else, because an identifier is
# `uuid.uuid4().hex`, which is the shape the page itself writes. The value is
# drawn per run because `ConversationStore.import_document` refuses a
# conversation the store already holds, so a fixed identifier imports once and
# refuses on every later run over the same root.
def browser_conversation_id() -> str:
    return uuid.uuid4().hex


# The fixture image, declared here the way remote/generate-quality-images.py
# declares its own: three bars of stated heights on a white ground, so the
# answer a vision model gives is gradeable against a value this file states.
FIXTURE_WIDTH = 96
FIXTURE_HEIGHT = 64
FIXTURE_BARS: tuple[tuple[str, int, tuple[int, int, int]], ...] = (
    ("left", 20, (196, 64, 64)),
    ("middle", 52, (64, 128, 196)),
    ("right", 34, (64, 176, 96)),
)
FIXTURE_TALLEST = "middle"


class AcceptanceRefused(RuntimeError):
    """An argument or a destination the run refuses before it probes anything."""


@dataclass(frozen=True, slots=True)
class CheckResult:
    """One named check: its outcome, the sentence behind it, and its evidence."""

    name: str
    status: str
    reason: str = ""
    evidence: Mapping[str, object] = field(default_factory=dict)
    elapsed_s: float = 0.0

    def to_json(self) -> dict[str, object]:
        return {
            "name": self.name,
            "status": self.status,
            "reason": self.reason,
            "evidence": dict(self.evidence),
            "elapsed_s": round(self.elapsed_s, 3),
        }


@dataclass(frozen=True)
class AcceptanceRequest:
    """One acceptance run, declared whole before the first exchange."""

    base: str
    pairing_code: str
    report: Path
    text_models: tuple[str, ...] = DEFAULT_TEXT_MODELS
    vision_models: tuple[str, ...] = DEFAULT_VISION_MODELS
    # The argv that ends and restarts the gateway between the two history
    # phases, and the argv that ends it before the teardown phase. Each is a
    # list because nothing here reaches a shell.
    restart_command: tuple[str, ...] = ()
    stop_command: tuple[str, ...] = ()
    # The report a previous run of this driver wrote. Its `conversation_open`
    # evidence names a saved conversation that a later run over the same root
    # reads back, which states survival across the restart that separated the
    # two runs without this run stopping the gateway itself.
    previous_report: Path | None = None
    lease_path: Path | None = None
    appliance_record: Path | None = None
    router_presets: Path | None = None
    document_fixtures: Path | None = None
    file_search_root: Path | None = None
    timeout_s: float = DEFAULT_TIMEOUT_SECONDS
    max_tokens: int = DEFAULT_MAX_TOKENS


# ---------------------------------------------------------------------------
# The fixture image
# ---------------------------------------------------------------------------


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", binascii.crc32(kind + payload) & 0xFFFFFFFF)
    )


def fixture_image() -> bytes:
    """A three-bar chart drawn from `FIXTURE_BARS`, encoded as a PNG with zlib.

    The declaration is what makes a vision answer gradeable: the middle bar is
    the tallest because the table above says so, and an answer that names it
    read the pixels rather than the prompt.
    """
    rows: list[bytes] = []
    column_width = FIXTURE_WIDTH // len(FIXTURE_BARS)
    for y in range(FIXTURE_HEIGHT):
        pixels = bytearray()
        for x in range(FIXTURE_WIDTH):
            index = min(x // column_width, len(FIXTURE_BARS) - 1)
            _, height, color = FIXTURE_BARS[index]
            inside = (FIXTURE_HEIGHT - y) <= height and (x % column_width) < column_width - 4
            pixels.extend(color if inside else (255, 255, 255))
        rows.append(b"\x00" + bytes(pixels))
    raw = zlib.compress(b"".join(rows), 9)
    header = struct.pack(">IIBBBBB", FIXTURE_WIDTH, FIXTURE_HEIGHT, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", raw)
        + _png_chunk(b"IEND", b"")
    )


# ---------------------------------------------------------------------------
# The client
# ---------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Answer:
    """One exchange, read whole."""

    status: int
    body: bytes
    headers: Mapping[str, str]

    def json(self) -> object:
        try:
            return json.loads(self.body.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return None

    def header(self, name: str) -> str:
        """One header by name, matched without case.

        `HTTPResponse.getheaders` returns whatever spelling the writer emitted,
        and the gateway writes `set-cookie` in lower case, so a case-sensitive
        read of `Set-Cookie` silently loses the session and every later check
        reads an unpaired gateway.
        """
        wanted = name.lower()
        for key, value in self.headers.items():
            if key.lower() == wanted:
                return value
        return ""

    @property
    def absent_route(self) -> bool:
        """Whether this answer is an unmounted route rather than a refusal.

        404 is the gateway's answer for a path no provider claims, and it is
        also what a route answers for an identifier it does not hold; the
        callers that can meet the second case check the body before reading
        this.
        """
        return self.status == 404


class Client:
    """One origin, one session cookie, and exchanges bound to both."""

    def __init__(self, base: str, timeout_s: float) -> None:
        parts = urlsplit(base)
        if parts.scheme != "http" or not parts.hostname:
            raise AcceptanceRefused(
                f"the acceptance base names {base!r}; it reads an http origin such as "
                "http://127.0.0.1:8090"
            )
        self.host = parts.hostname
        self.port = parts.port or 80
        self.origin = f"http://{self.host}:{self.port}"
        self.timeout_s = timeout_s
        self.cookie = ""
        # The per-launch approval secret, read once and held for the run the
        # way `static/js/api.js` holds it for the life of the page.
        self.session_secret = ""

    def connection(self) -> HTTPConnection:
        return HTTPConnection(self.host, self.port, timeout=self.timeout_s)

    def headers(self, extra: Mapping[str, str] | None = None) -> dict[str, str]:
        headers = {"Host": f"{self.host}:{self.port}", "Origin": self.origin}
        if self.cookie:
            headers["Cookie"] = self.cookie
        headers.update(extra or {})
        return headers

    def exchange(
        self,
        method: str,
        path: str,
        *,
        body: bytes | None = None,
        headers: Mapping[str, str] | None = None,
        authenticated: bool = True,
    ) -> Answer:
        sent = self.headers(headers) if authenticated else {"Host": f"{self.host}:{self.port}"}
        connection = self.connection()
        try:
            connection.request(method, path, body=body, headers=sent)
            response = connection.getresponse()
            payload = response.read()
            return Answer(response.status, payload, dict(response.getheaders()))
        finally:
            connection.close()

    def post_json(self, path: str, payload: object, **kwargs: object) -> Answer:
        headers = {"Content-Type": "application/json"}
        extra = kwargs.get("headers")
        if isinstance(extra, Mapping):
            headers.update({str(key): str(value) for key, value in extra.items()})
        return self.exchange(
            "POST", path, body=json.dumps(payload).encode("utf-8"), headers=headers
        )

    def pair(self, code: str) -> Answer:
        answer = self.post_json("/api/pair", {"code": code})
        raw = answer.header("Set-Cookie")
        if raw:
            self.cookie = raw.split(";", 1)[0]
        return answer

    def approval_session(self) -> Answer:
        """Read the per-launch approval secret and hold it for the run.

        `GET /api/tools/session` releases the secret behind the admitted Host,
        the Origin allowlist, and the gateway session, and the value travels in
        the body rather than the URL.
        """
        answer = self.exchange("GET", SESSION_ROUTE)
        payload = answer.json()
        if answer.status == 200 and isinstance(payload, dict):
            self.session_secret = str(payload.get("session_secret", ""))
        return answer

    def post_grant(self, route: str, fields: Mapping[str, object]) -> Answer:
        """Post one grant proposal under the session secret, retrying a stale one.

        A gateway restarted on the same port signs a new secret, so a held one
        is stale rather than wrong: the refusal carries the stale-secret code
        and one retry against a freshly read secret recovers it, which is the
        flow the page performs. A second refusal is a genuine one and reaches
        the caller.
        """
        if not self.session_secret:
            session = self.approval_session()
            if not self.session_secret:
                return session
        headers = {SESSION_HEADER: self.session_secret}
        answer = self.post_json(route, dict(fields), headers=headers)
        payload = answer.json()
        stale = isinstance(payload, dict) and payload.get("code") == STALE_SESSION_SECRET_CODE
        if answer.status == 403 and stale:
            self.session_secret = ""
            session = self.approval_session()
            if not self.session_secret:
                return session
            answer = self.post_json(
                route, dict(fields), headers={SESSION_HEADER: self.session_secret}
            )
        return answer

    def open_stream(self, path: str, payload: object) -> tuple[HTTPConnection, HTTPResponse]:
        """Start a streamed exchange and hand back both halves unread.

        The mid-stream cancel check needs the socket still open with bytes
        pending, which is exactly what an unread response object holds.
        """
        connection = self.connection()
        connection.request(
            "POST",
            path,
            body=json.dumps(payload).encode("utf-8"),
            headers=self.headers({"Content-Type": "application/json"}),
        )
        return connection, connection.getresponse()


# ---------------------------------------------------------------------------
# Request shapes
# ---------------------------------------------------------------------------


def text_request(model: str, max_tokens: int, *, stream: bool = False) -> dict[str, object]:
    return {
        "model": model,
        "stream": stream,
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": TEXT_PROMPT}],
    }


def vision_request(
    model: str, max_tokens: int, image: bytes | None, prompt: str = VISION_PROMPT
) -> dict[str, object]:
    """The multipart content the withheld control keeps the text part of.

    The control retains the text part and removes the image parts, so image
    presence is the single changed request dimension between the two arms; a
    control that also dropped the instruction would compare two prompts.
    """
    parts: list[dict[str, object]] = [{"type": "text", "text": prompt}]
    if image is not None:
        encoded = base64.b64encode(image).decode("ascii")
        parts.append(
            {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{encoded}"}}
        )
    return {
        "model": model,
        "stream": False,
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": parts}],
    }


def grant_token(answer: Answer) -> str:
    """The signed grant one approval answered with, or the empty string."""
    payload = answer.json()
    if not isinstance(payload, dict):
        return ""
    return str(payload.get("authorization", ""))


def refusal_sentence(answer: Answer) -> str:
    """The sentence a refused route stated, or its first bytes."""
    payload = answer.json()
    if isinstance(payload, dict) and isinstance(payload.get("error"), str):
        return str(payload["error"])
    return answer.body[:200].decode("utf-8", "replace")


def tool_offer(payload: object, tool_id: str) -> Mapping[str, object] | None:
    """One row of the tool matrix by its identifier."""
    tools = payload.get("tools") if isinstance(payload, dict) else None
    if not isinstance(tools, list):
        return None
    for row in tools:
        if isinstance(row, dict) and row.get("tool_id") == tool_id:
            return row
    return None


def bound_value(bounds: Mapping[str, object], key: str, fallback: int = 0) -> int:
    """One integer of a matrix row's `bounds` block, or the stated fallback."""
    value = bounds.get(key, fallback)
    return int(value) if isinstance(value, int) and not isinstance(value, bool) else fallback


def launch_field(payload: object, key: str) -> str:
    """One field of the matrix's `launch` block, which names what this launch armed."""
    launch = payload.get("launch") if isinstance(payload, dict) else None
    return str(launch.get(key, "")) if isinstance(launch, dict) else ""


def outcome_state(answer: Answer) -> tuple[str, str, str]:
    """The state, the status term, and the text of one execution record."""
    payload = answer.json()
    if not isinstance(payload, dict):
        return ("", "", "")
    return (
        str(payload.get("state", "")),
        str(payload.get("status", "")),
        str(payload.get("text", "")),
    )


def usable_page(answer: Answer) -> bool:
    """Whether one record carries a page window a model can read.

    `evidence.kind` and `evidence.usable` are what the executor states about
    the retrieval, so the item reads them rather than the length of a frame
    whose header is non-empty under every outcome.
    """
    payload = answer.json()
    evidence = payload.get("evidence") if isinstance(payload, dict) else None
    if not isinstance(evidence, dict):
        return False
    return evidence.get("kind") == "fetched_page" and bool(evidence.get("usable"))


def result_identifiers(rendered: str) -> tuple[str, ...]:
    """Every signed Result ID one rendered search block carries.

    `render_search_results` writes the identifier on its own `Result ID:` line,
    which is the same field `static/js/tools.js` reads to build the page's own
    handle table.
    """
    found = [
        line[len(RESULT_ID_PREFIX) :].strip()
        for line in rendered.splitlines()
        if line.startswith(RESULT_ID_PREFIX)
    ]
    return tuple(entry for entry in found if entry)


def previous_saved_conversation(document: object) -> str:
    """The saved conversation identifier a previous report's `conversation_open` names."""
    checks = document.get("checks") if isinstance(document, dict) else None
    if not isinstance(checks, list):
        return ""
    for entry in checks:
        if not isinstance(entry, dict) or entry.get("name") != "conversation_open":
            continue
        evidence = entry.get("evidence")
        if isinstance(evidence, dict):
            return str(evidence.get("saved", ""))
    return ""


def listed_conversation_ids(answer: Answer) -> tuple[str, ...]:
    """Every conversation identifier one listing answered with."""
    payload = answer.json()
    rows = payload.get("conversations") if isinstance(payload, dict) else None
    if not isinstance(rows, list):
        return ()
    return tuple(str(row.get("conversation_id", "")) for row in rows if isinstance(row, dict))


def completion_text(payload: object) -> str:
    """The assistant content of one non-streamed completion, or the empty string."""
    if not isinstance(payload, dict):
        return ""
    choices = payload.get("choices")
    if not isinstance(choices, list) or not choices:
        return ""
    first = choices[0]
    if not isinstance(first, dict):
        return ""
    message = first.get("message")
    if isinstance(message, dict) and isinstance(message.get("content"), str):
        return str(message["content"])
    return ""


def served_name(payload: object) -> str:
    return str(payload["model"]) if isinstance(payload, dict) and "model" in payload else ""


# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------


class AcceptanceRun:
    """Every check, in the order a launch acceptance reads them."""

    def __init__(self, paths: RuntimePaths, request: AcceptanceRequest) -> None:
        self.paths = paths
        self.request = request
        self.client = Client(request.base, request.timeout_s)
        self.results: list[CheckResult] = []
        self.saved_conversation = ""
        self.temporary_conversation = ""

    # -- bookkeeping -----------------------------------------------------

    def record(
        self,
        name: str,
        status: str,
        reason: str = "",
        evidence: Mapping[str, object] | None = None,
        started: float | None = None,
    ) -> CheckResult:
        result = CheckResult(
            name=name,
            status=status,
            reason=reason,
            evidence=dict(evidence or {}),
            elapsed_s=0.0 if started is None else time.monotonic() - started,
        )
        self.results.append(result)
        return result

    def absent(self, name: str, route: str, answer: Answer) -> CheckResult:
        return self.record(
            name,
            SKIPPED,
            f"the route {route} answers 404 on this branch, so the claim has no surface yet",
            {"route": route, "status": answer.status},
        )

    # -- the live phase --------------------------------------------------

    def check_unauthenticated_refusal(self) -> None:
        started = time.monotonic()
        answer = self.client.exchange(
            "POST",
            "/api/chat",
            body=b"{}",
            headers={"Content-Type": "application/json"},
            authenticated=False,
        )
        if answer.status == 401:
            self.record(
                "unauthenticated_refusal",
                PASS,
                "",
                {"status": answer.status},
                started,
            )
            return
        self.record(
            "unauthenticated_refusal",
            FAIL,
            f"an unpaired POST /api/chat answered {answer.status} rather than 401",
            {"status": answer.status, "body": answer.body[:200].decode("utf-8", "replace")},
            started,
        )

    def check_pairing(self) -> None:
        started = time.monotonic()
        answer = self.client.pair(self.request.pairing_code)
        if answer.status == 200 and self.client.cookie:
            self.record("pairing", PASS, "", {"status": answer.status}, started)
            return
        self.record(
            "pairing",
            FAIL,
            f"pairing answered {answer.status} and set "
            f"{'a' if self.client.cookie else 'no'} cookie",
            {"status": answer.status},
            started,
        )

    def check_roster_join(self) -> None:
        """The live roster against the registry rows and the preset sections.

        Two halves make the join checkable. The registry half re-derives every
        displayed field from `remote/models.tsv` and compares it with the
        answer, so a row the gateway decorated from another authority differs
        here. The preset half compares the answered id set with the sections the
        bundle's own router preset names, and it runs where `--router-presets`
        supplies that file; a run without it reports the registry half alone and
        says so.
        """
        started = time.monotonic()
        answer = self.client.exchange("GET", "/api/models")
        if answer.status != 200:
            self.record(
                "roster_join",
                FAIL,
                f"GET /api/models answered {answer.status}",
                {"status": answer.status},
                started,
            )
            return
        payload = answer.json()
        entries = payload.get("models") if isinstance(payload, dict) else None
        if not isinstance(entries, list):
            self.record("roster_join", FAIL, "the roster answer names no models list", {}, started)
            return
        rows = {row.id: row for row in registry.load_models()}
        disagreements: list[str] = []
        for entry in entries:
            if not isinstance(entry, dict):
                disagreements.append("an entry is not a JSON object")
                continue
            model_id = str(entry.get("id", ""))
            if str(entry.get("state")) not in ROSTER_STATES:
                disagreements.append(f"{model_id} carries the state {entry.get('state')!r}")
            row = rows.get(model_id)
            if row is None:
                continue
            expected = {
                "role": row.role,
                "tier": row.tier,
                "context_default": row.context_default,
                "projector": row.projector,
                "quantization": quantization(row.model_file),
            }
            for key, value in expected.items():
                if entry.get(key) != value:
                    disagreements.append(
                        f"{model_id}.{key} is {entry.get(key)!r} against {value!r}"
                    )
        section_state = "not supplied"
        if self.request.router_presets is not None:
            sections = tuple(
                section.name for section in policy.preset_sections(self.request.router_presets)
            )
            answered = tuple(str(entry.get("id")) for entry in entries if isinstance(entry, dict))
            section_state = "compared"
            if set(answered) != set(sections):
                disagreements.append(
                    f"the roster answers {sorted(set(answered))} against the preset's "
                    f"{sorted(set(sections))}"
                )
        self.record(
            "roster_join",
            PASS if not disagreements else FAIL,
            "; ".join(disagreements),
            {
                "entries": len(entries),
                "mode": payload.get("mode") if isinstance(payload, dict) else "-",
                "preset_sections": section_state,
            },
            started,
        )

    def check_text_turn(self, model: str) -> None:
        started = time.monotonic()
        answer = self.client.post_json("/api/chat", text_request(model, self.request.max_tokens))
        if answer.status == 409:
            self.record(
                f"text_turn:{model}",
                SKIPPED,
                f"the live router does not admit {model}",
                {"status": answer.status},
                started,
            )
            return
        if answer.status != 200:
            self.record(
                f"text_turn:{model}",
                FAIL,
                f"POST /api/chat answered {answer.status}",
                {"status": answer.status, "body": answer.body[:200].decode("utf-8", "replace")},
                started,
            )
            return
        payload = answer.json()
        stated = served_name(payload)
        content = completion_text(payload)
        if not stated:
            self.record(
                f"text_turn:{model}",
                FAIL,
                "the completion states no served model",
                {"content": content[:200]},
                started,
            )
            return
        self.record(
            f"text_turn:{model}",
            PASS,
            "",
            {"served_model": stated, "content": content[:200]},
            started,
        )

    def check_vision_consumes_image(self, model: str) -> None:
        """The admitted profile against its own image-withheld control.

        Equal answers are the failure the check exists for: a projector of
        matching dimensions loads cleanly while writing image tokens the
        language model reads nothing from, so a vision lane that ignores the
        bytes answers rather than erroring.

        The registry decides whether the row is asked at all. `remote/models.tsv`
        reads `projector required` for a row whose own directory holds one and
        `none` for a row that runs text-only, and
        `remote/select-projector.sh` binds the search to that directory, so a
        text row receiving image parts has no path that consumes them and the
        server answers 500. The item fails naming the column rather than sending
        the image, because the finding is the argument rather than the server.
        """
        started = time.monotonic()
        rows = {row.id: row for row in registry.load_models()}
        row = rows.get(model)
        if row is None:
            self.record(
                f"vision_consumes_image:{model}",
                FAIL,
                f"remote/models.tsv carries no row for {model}, so no projector claim "
                "stands behind this vision arm",
                {"registry_row": "absent"},
                started,
            )
            return
        if row.projector != "required":
            self.record(
                f"vision_consumes_image:{model}",
                FAIL,
                f"remote/models.tsv reads projector {row.projector} for {model}, so the "
                "row runs text-only and consumes no image",
                {"projector": row.projector, "role": row.role},
                started,
            )
            return
        image = fixture_image()
        with_image = self.client.post_json(
            "/api/chat", vision_request(model, self.request.max_tokens, image)
        )
        if with_image.status == 409:
            self.record(
                f"vision_consumes_image:{model}",
                SKIPPED,
                f"the live router does not admit {model}",
                {"status": with_image.status},
                started,
            )
            return
        withheld = self.client.post_json(
            "/api/chat", vision_request(model, self.request.max_tokens, None)
        )
        if with_image.status != 200 or withheld.status != 200:
            self.record(
                f"vision_consumes_image:{model}",
                FAIL,
                f"the image arm answered {with_image.status} and the control {withheld.status}",
                {"image_status": with_image.status, "control_status": withheld.status},
                started,
            )
            return
        seen = completion_text(with_image.json())
        control = completion_text(withheld.json())
        evidence = {
            "image_bytes": len(image),
            "declared_tallest": FIXTURE_TALLEST,
            "with_image": seen[:200],
            "withheld": control[:200],
        }
        if seen and control and seen != control:
            self.record(f"vision_consumes_image:{model}", PASS, "", evidence, started)
            return
        self.record(
            f"vision_consumes_image:{model}",
            FAIL,
            "the image arm and the withheld control answered the same text, so the "
            "image bytes changed nothing",
            evidence,
            started,
        )

    def check_midstream_cancel(self) -> None:
        """A stream abandoned mid-body, then a plain request against the same origin."""
        started = time.monotonic()
        model = self.request.text_models[0] if self.request.text_models else ""
        payload = text_request(model, CANCEL_TOKENS, stream=True)
        connection, response = self.client.open_stream("/api/chat", payload)
        first = b""
        try:
            if response.status == 409:
                self.record(
                    "midstream_cancel",
                    SKIPPED,
                    f"the live router does not admit {model}",
                    {"status": response.status},
                    started,
                )
                return
            first = response.read(STREAM_READ_BYTES)
        finally:
            connection.close()
        health = self.client.exchange("GET", "/api/health")
        follow = self.client.post_json("/api/chat", text_request(model, self.request.max_tokens))
        evidence = {
            "stream_status": response.status,
            "first_bytes": len(first),
            "health_status": health.status,
            "follow_status": follow.status,
        }
        if health.status == 200 and follow.status == 200:
            self.record("midstream_cancel", PASS, "", evidence, started)
            return
        self.record(
            "midstream_cancel",
            FAIL,
            f"after the abandoned stream /api/health answered {health.status} and the next "
            f"completion {follow.status}",
            evidence,
            started,
        )

    # -- conversations ---------------------------------------------------

    def open_conversations(self) -> None:
        """Create one saved and one temporary conversation, each with a message."""
        started = time.monotonic()
        created: dict[str, str] = {}
        for mode in ("saved", "temporary"):
            answer = self.client.post_json(
                "/api/conversations", {"mode": mode, "title": f"acceptance {mode}"}
            )
            if answer.status != 201:
                self.record(
                    "conversation_open",
                    FAIL,
                    f"creating a {mode} conversation answered {answer.status}",
                    {"mode": mode, "status": answer.status},
                    started,
                )
                return
            payload = answer.json()
            identifier = (
                str(payload.get("conversation_id", "")) if isinstance(payload, dict) else ""
            )
            created[mode] = identifier
            self.client.post_json(
                f"/api/conversations/{identifier}/messages",
                {"role": "user", "content": f"acceptance {mode} message"},
            )
        self.saved_conversation = created["saved"]
        self.temporary_conversation = created["temporary"]
        self.record("conversation_open", PASS, "", dict(created), started)

    def check_history_across_restart(self) -> None:
        """The saved conversation survives a gateway restart and the temporary one ends.

        Two arguments make this observable and each states a different half.
        `--restart-command` restarts the gateway inside this run, so the
        temporary store, which lives in the process and under
        `tmp/conversations/<id>/`, is read as gone by a second process over the
        same root. `--previous-report` reads the saved conversation a previous
        run created and proves it is still listed and readable here, which
        states survival across whatever restart separated the two runs without
        this run stopping the gateway itself.
        """
        started = time.monotonic()
        if not self.request.restart_command:
            self.check_history_from_previous_report(started)
            return
        if not self.saved_conversation:
            self.record(
                "history_survives_restart",
                SKIPPED,
                "no conversation was opened, so the restart has nothing to carry",
                {},
                started,
            )
            return
        completed = subprocess.run(  # noqa: S603
            list(self.request.restart_command), capture_output=True, check=False
        )
        if completed.returncode != 0:
            self.record(
                "history_survives_restart",
                FAIL,
                f"the restart command exited {completed.returncode}",
                {"stderr": completed.stderr.decode("utf-8", "replace")[:400]},
                started,
            )
            return
        if not self._wait_for_origin():
            self.record(
                "history_survives_restart",
                FAIL,
                "the origin did not answer again after the restart command",
                {},
                started,
            )
            return
        paired = self.client.pair(self._current_pairing_code())
        if paired.status != 200:
            self.record(
                "history_survives_restart",
                FAIL,
                f"pairing with the restarted gateway answered {paired.status}",
                {"status": paired.status},
                started,
            )
            return
        saved = self.client.exchange("GET", f"/api/conversations/{self.saved_conversation}")
        temporary = self.client.exchange("GET", f"/api/conversations/{self.temporary_conversation}")
        evidence = {"saved_status": saved.status, "temporary_status": temporary.status}
        if saved.status == 200 and temporary.status == 404:
            self.record("history_survives_restart", PASS, "", evidence, started)
            return
        self.record(
            "history_survives_restart",
            FAIL,
            f"the saved conversation answered {saved.status} and the temporary one "
            f"{temporary.status}; the saved one survives and the temporary one ends",
            evidence,
            started,
        )

    def check_history_from_previous_report(self, started: float) -> None:
        """Read the previous run's saved conversation back out of this one."""
        report = self.request.previous_report
        if report is None:
            self.record(
                "history_survives_restart",
                SKIPPED,
                "the run names neither --restart-command nor --previous-report, so no "
                "second process reads this root",
                {},
                started,
            )
            return
        try:
            document = json.loads(report.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            self.record(
                "history_survives_restart",
                FAIL,
                f"the previous report {report} is unreadable: {error}",
                {"previous_report": str(report)},
                started,
            )
            return
        previous = previous_saved_conversation(document)
        if not previous:
            self.record(
                "history_survives_restart",
                SKIPPED,
                f"the previous report {report} names no saved conversation, so its "
                "conversation_open item created none to read back",
                {"previous_report": str(report)},
                started,
            )
            return
        read_back = self.client.exchange("GET", f"/api/conversations/{previous}")
        listing = self.client.exchange("GET", "/api/conversations")
        listed = previous in listed_conversation_ids(listing)
        evidence = {
            "previous_report": str(report),
            "conversation_id": previous,
            "read_status": read_back.status,
            "listed": listed,
            "listing_status": listing.status,
        }
        if read_back.status == 200 and listed:
            self.record("history_survives_restart", PASS, "", evidence, started)
            return
        self.record(
            "history_survives_restart",
            FAIL,
            f"the previous run's saved conversation reads back {read_back.status} and is "
            f"{'listed' if listed else 'absent from the listing'}",
            evidence,
            started,
        )

    def _current_pairing_code(self) -> str:
        """The code the restarted gateway minted, read from the file it wrote.

        `SessionGate.start` mints a fresh code on every launch and a code dies
        on its first use, so the code this run was given is dead the moment the
        restart command returns. Re-pairing with it would answer 401 on every
        later exchange and report a surviving conversation as a lost one, so the
        driver reads `state/gateway-pairing.secret`, which is where the gate
        writes the live code at mode 0600 and the only place it publishes it.
        """
        secret = self.paths["qwen_home_state"] / PAIRING_CODE_FILENAME
        try:
            return secret.read_text(encoding="utf-8").strip()
        except OSError:
            return self.request.pairing_code

    def _wait_for_origin(self) -> bool:
        """Poll the origin until it answers 200, over a restart that closes sockets.

        A gateway coming back refuses, resets, and half-answers before it
        listens, and `http.client` raises `HTTPException` rather than `OSError`
        for the half-answers, so both are the wait's own condition rather than
        an exception that ends the run.
        """
        deadline = time.monotonic() + RESTART_DEADLINE_SECONDS
        while time.monotonic() < deadline:
            try:
                if self.client.exchange("GET", "/api/health").status == 200:
                    return True
            except (OSError, HTTPException):
                pass
            time.sleep(RESTART_SETTLE_SECONDS)
        return False

    def check_browser_history_import(self) -> None:
        """A page export converted by its own reader and imported over the route.

        `web/browser_import.parse_export` is the authority the CLI's
        `import --browser` uses, so the driver converts through it and posts the
        store's own document shape rather than inventing a second reader.

        The identifier is drawn per run because `ConversationStore.import_document`
        refuses a conversation the store already holds: a fixed identifier
        imports on the first run over a root and answers 400 on every later one,
        which reports a working route as a regression.
        """
        started = time.monotonic()
        identifier = browser_conversation_id()
        document = json.dumps(
            {
                "qwen_apu_browser_history_export": browser_import.EXPORT_VERSION,
                "conversations": [
                    {
                        "id": identifier,
                        "title": "an imported page transcript",
                        "updated": 1_700_000_000_000,
                        "messages": [
                            {"role": "user", "content": "what is the capital of Norway"},
                            {
                                "role": "assistant",
                                "content": "Oslo",
                                "model": "qwen38-2b-distill",
                            },
                        ],
                    }
                ],
            }
        ).encode("utf-8")
        report = browser_import.parse_export(document)
        payload = {
            "document_version": DOCUMENT_VERSION,
            "conversations": [
                conversation_to_json(conversation) for conversation in report.conversations
            ],
        }
        answer = self.client.post_json("/api/conversations/import", payload)
        if answer.absent_route:
            self.absent("browser_history_import", "/api/conversations/import", answer)
            return
        if answer.status != 201:
            self.record(
                "browser_history_import",
                FAIL,
                f"the import answered {answer.status}",
                {"status": answer.status, "body": answer.body[:300].decode("utf-8", "replace")},
                started,
            )
            return
        read_back = self.client.exchange("GET", f"/api/conversations/{identifier}")
        evidence = {
            "conversation_id": identifier,
            "warnings": list(report.warnings),
            "skipped": list(report.skipped),
            "read_back_status": read_back.status,
        }
        if read_back.status == 200:
            self.record("browser_history_import", PASS, "", evidence, started)
            return
        self.record(
            "browser_history_import",
            FAIL,
            f"the imported conversation reads back {read_back.status}",
            evidence,
            started,
        )

    # -- documents and deterministic tools -------------------------------

    def check_document(self, fixture: str, media_type: str, boundary_kinds: Sequence[str]) -> None:
        started = time.monotonic()
        name = f"document_extraction:{fixture}"
        root = self.request.document_fixtures
        if root is None:
            self.record(
                name, SKIPPED, "the run names no --document-fixtures directory", {}, started
            )
            return
        source = root / fixture
        if not source.is_file():
            self.record(name, SKIPPED, f"the fixture is absent: {source}", {}, started)
            return
        answer = self.client.exchange(
            "POST",
            "/api/documents",
            body=source.read_bytes(),
            headers={"Content-Type": media_type, "X-Filename": fixture},
        )
        if answer.absent_route:
            self.absent(name, "/api/documents", answer)
            return
        if answer.status != 201:
            detail = answer.body[:300].decode("utf-8", "replace")
            # The PDF extractor is `pypdf`, imported at call time, so a venv
            # without it extracts every other format and names this one. That is
            # a missing input rather than a broken claim.
            if MISSING_EXTRACTOR_MARKER in detail.lower():
                self.record(
                    name,
                    SKIPPED,
                    f"the extractor this format needs is absent: {detail}",
                    {"status": answer.status},
                    started,
                )
                return
            self.record(
                name,
                FAIL,
                f"the upload answered {answer.status}",
                {"status": answer.status, "body": detail},
                started,
            )
            return
        record = answer.json()
        if not isinstance(record, dict):
            self.record(name, FAIL, "the upload answer is not a record object", {}, started)
            return
        digest = str(record.get("sha256", ""))
        declared = record.get("boundaries")
        kinds = sorted(
            {
                str(boundary.get("kind"))
                for boundary in (declared if isinstance(declared, list) else [])
                if isinstance(boundary, dict)
            }
        )
        evidence = {
            "sha256": digest,
            "state": record.get("state"),
            "characters": record.get("characters"),
            "boundary_kinds": kinds,
            "expected_boundary_kinds": list(boundary_kinds),
        }
        missing = [kind for kind in boundary_kinds if kind not in kinds]
        if missing:
            self.record(
                name,
                FAIL,
                f"the record names no boundary of kind {', '.join(missing)}",
                evidence,
                started,
            )
            return
        read_back = self.client.exchange("GET", f"/api/documents/{digest}")
        evidence["read_back_status"] = read_back.status
        self.record(
            name,
            PASS if read_back.status == 200 else FAIL,
            "" if read_back.status == 200 else f"the record reads back {read_back.status}",
            evidence,
            started,
        )

    def check_calculator(self) -> None:
        started = time.monotonic()
        answer = self.client.post_json("/api/tools/calculator", {"expression": "12 kib to b"})
        if answer.absent_route:
            self.absent("calculator", "/api/tools/calculator", answer)
            return
        payload = answer.json()
        value = str(payload.get("value")) if isinstance(payload, dict) else ""
        evidence = {"status": answer.status, "value": value}
        if answer.status == 200 and value.startswith("12288"):
            self.record("calculator", PASS, "", evidence, started)
            return
        self.record(
            "calculator",
            FAIL,
            f"12 kib to b answered {answer.status} with {value!r} against 12288",
            evidence,
            started,
        )

    def check_file_search(self) -> None:
        """A search inside a declared root, and a root outside the declared set.

        The scope probe runs whatever the first search answered, because a
        search that failed and an escape that succeeded are two separate
        findings and folding them together would hide the second.
        """
        started = time.monotonic()
        root = self.request.file_search_root
        if root is None:
            reason = "the run names no --file-search-root"
            self.record("file_search", SKIPPED, reason, {}, started)
            self.record("file_search_scope", SKIPPED, reason, {})
            return
        answer = self.client.post_json(
            "/api/tools/files/search", {"query": "the", "root": str(root), "glob": "*"}
        )
        if answer.absent_route:
            self.absent("file_search", "/api/tools/files/search", answer)
            self.absent("file_search_scope", "/api/tools/files/search", answer)
            return
        payload = answer.json()
        hits = payload.get("hits") if isinstance(payload, dict) else None
        admitted = answer.status == 200 and isinstance(hits, list)
        self.record(
            "file_search",
            PASS if admitted else FAIL,
            "" if admitted else f"the scoped search answered {answer.status}",
            {"status": answer.status, "hits": len(hits) if isinstance(hits, list) else 0},
            started,
        )
        escape = self.client.post_json(
            "/api/tools/files/search",
            {"query": "the", "root": str(root.parent.parent), "glob": "*"},
        )
        refused = escape.status >= 400
        self.record(
            "file_search_scope",
            PASS if refused else FAIL,
            ""
            if refused
            else f"a root outside the declared set answered {escape.status} rather than a refusal",
            {"status": escape.status},
        )

    # -- the lanes this branch may not carry -----------------------------

    WEB_ITEMS: tuple[str, str] = ("web_search_then_fetch", "web_retrieval_failure_explicit")

    def read_matrix(self) -> tuple[Answer, object]:
        """`GET /api/tools?model=ID` for the first text model this run names.

        The matrix states what each lane answers for one selection, so a lane
        that no launch armed is read from the row's own state rather than
        inferred from a refusal the driver provoked.
        """
        model = self.request.text_models[0] if self.request.text_models else ""
        answer = self.client.exchange("GET", f"{MATRIX_ROUTE}?model={quote(model)}")
        return answer, answer.json()

    def lane_unavailable(
        self, names: Sequence[str], offer: Mapping[str, object] | None, row: str
    ) -> bool:
        """Report a lane this launch does not execute, and say which party withheld it.

        A row absent from the matrix, a `temporarily_unavailable` row naming the
        socket or the search backend it waits on, and a `not_installed` or
        `policy_refused` row each leave the lane unexecuted, so every item skips
        carrying the matrix's own sentence rather than a status code the driver
        produced by calling anyway.
        """
        if offer is None:
            for name in names:
                self.record(name, SKIPPED, f"the tool matrix carries no {row} row", {"row": row})
            return True
        state = str(offer.get("state", ""))
        if state in EXECUTING_TOOL_STATES:
            return False
        evidence = {"row": row, "state": state, "helper": str(offer.get("helper", ""))}
        reason = f"the matrix reads {state} for {row}: {offer.get('reason', '')}"
        for name in names:
            self.record(name, SKIPPED, reason, evidence)
        return True

    def check_web_lane(self) -> None:
        """One approved search, the page one of its results names, and a stated failure.

        The executor is `POST /api/tools`: `web_search` runs behind a
        `search-authorization` grant covering the exact arguments, and
        `read_url` redeems one signed Result ID that search issued. The second
        item reads one character at the last admitted offset of the same
        document, which returns an empty window and with it the 200 carrying
        `state: incomplete` that keeps a failed retrieval from reading as a
        turn that went quiet.
        """
        started = time.monotonic()
        grounded, explicit = self.WEB_ITEMS
        matrix, payload = self.read_matrix()
        if matrix.absent_route:
            for name in self.WEB_ITEMS:
                self.absent(name, MATRIX_ROUTE, matrix)
            return
        if matrix.status != 200:
            for name in self.WEB_ITEMS:
                self.record(
                    name,
                    FAIL,
                    f"GET {MATRIX_ROUTE} answered {matrix.status}",
                    {"status": matrix.status},
                )
            return
        offer = tool_offer(payload, SEARCH_TOOL_ROW)
        if self.lane_unavailable(self.WEB_ITEMS, offer, SEARCH_TOOL_ROW):
            return
        model = self.request.text_models[0] if self.request.text_models else ""
        grant = self.client.post_grant(
            GRANT_ROUTE,
            {
                "profile_id": launch_field(payload, "approval_profile"),
                "query": WEB_QUERY,
                "include_domains": [],
                "exclude_domains": [],
            },
        )
        token = grant_token(grant)
        if not token:
            reason = (
                f"the search grant answered {grant.status}: {refusal_sentence(grant)}; "
                "every network-reaching call in this lane passes one human approval "
                "and a single-use grant"
            )
            for name in self.WEB_ITEMS:
                self.record(name, SKIPPED, reason, {"grant_status": grant.status})
            return
        search = self.client.post_json(
            TOOLS_ROUTE,
            {
                "model": model,
                "tool": SEARCH_TOOL,
                "params": {"query": WEB_QUERY, "authorization": token},
                "stream": False,
            },
        )
        state, term, rendered = outcome_state(search)
        if search.status == 200 and state == "incomplete":
            # The search reached the boundary and came back empty, which the
            # explicit-failure item is exactly the claim about; the grounded
            # item has no page to read and names the instance that answered.
            self.record(
                grounded,
                SKIPPED,
                f"the search itself answered {term}, so no result was issued to fetch: "
                f"{rendered[:200]}",
                {"status": search.status, "state": state, "term": term},
                started,
            )
            self.record(
                explicit,
                PASS,
                "",
                {"proved_by": "search", "status": search.status, "state": state, "term": term},
            )
            return
        if search.status != 200 or state != "complete":
            for name in self.WEB_ITEMS:
                self.record(
                    name,
                    FAIL,
                    f"the search answered {search.status} in state {state or 'none'}: "
                    f"{rendered[:200] or refusal_sentence(search)}",
                    {"status": search.status, "state": state, "term": term},
                )
            return
        issued = result_identifiers(rendered)
        if not issued:
            reason = "the search answered complete and issued no Result ID, so no page is named"
            self.record(grounded, FAIL, reason, {"status": search.status}, started)
            self.record(explicit, SKIPPED, reason, {"status": search.status})
            return
        self.check_web_fetch(grounded, explicit, model, issued[0], started)

    def check_web_fetch(
        self, grounded: str, explicit: str, model: str, result_id: str, started: float
    ) -> None:
        """Read one page through its Result ID, then read a window that holds no text."""
        fetch = self.client.post_json(
            TOOLS_ROUTE,
            {
                "model": model,
                "tool": READ_URL_TOOL,
                "params": {"result_id": result_id},
                "stream": False,
            },
        )
        state, term, text = outcome_state(fetch)
        usable = usable_page(fetch)
        self.record(
            grounded,
            PASS if fetch.status == 200 and state == "complete" and usable and text else FAIL,
            ""
            if fetch.status == 200 and state == "complete" and usable and text
            else f"the fetch answered {fetch.status} in state {state or 'none'} "
            f"carrying {'a' if usable else 'no'} page window: {text[:200]}",
            {"status": fetch.status, "state": state, "term": term, "characters": len(text)},
            started,
        )
        probe = self.client.post_json(
            TOOLS_ROUTE,
            {
                "model": model,
                "tool": READ_URL_TOOL,
                "params": {
                    "result_id": result_id,
                    "start_index": EMPTY_WINDOW_START_INDEX,
                    "max_chars": EMPTY_WINDOW_CHARACTERS,
                },
                "stream": False,
            },
        )
        probe_state, probe_term, probe_text = outcome_state(probe)
        held = probe.status == 200 and probe_state == "incomplete"
        self.record(
            explicit,
            PASS if held else FAIL,
            ""
            if held
            else f"a retrieval that returned no text answered {probe.status} in state "
            f"{probe_state or 'none'}, so a failed retrieval is invisible: {probe_text[:200]}",
            {
                "proved_by": "empty_window",
                "start_index": EMPTY_WINDOW_START_INDEX,
                "status": probe.status,
                "state": probe_state,
                "term": probe_term,
            },
        )

    IMAGE_ITEMS: tuple[str, ...] = (
        "image_generate",
        "artifact_read",
        "image_review",
        "image_cancel",
        "image_remove",
    )

    def image_grant_fields(self, bounds: Mapping[str, object], language: str) -> dict[str, object]:
        """The proposal the page posts, built from the armed profile's own bounds.

        `image_grant.enforce_image_authorization` compares the prompt digests,
        the seed, and the aspect for equality and the width, height, and step
        count as `<=` bounds, so the aspect is the reduced form of the geometry
        the generate call then sends and the maxima are the profile's own.
        """
        width = bound_value(bounds, "width")
        height = bound_value(bounds, "height")
        return {
            "context": IMAGE_CLAIM_CONTEXT,
            "language_profile": language,
            "image_profile": str(bounds.get("profile_id", "")),
            "prompt_hash": prompt_digest(IMAGE_PROMPT),
            "negative_prompt_hash": prompt_digest(IMAGE_NEGATIVE_PROMPT),
            "seed": IMAGE_SEED,
            "aspect": canonical_aspect(width, height),
            "max_dimension": bound_value(bounds, "max_dimension"),
            "max_steps": min(IMAGE_STEPS, bound_value(bounds, "max_steps", IMAGE_STEPS)),
            "conversation_generation": 0,
        }

    def check_image_lane(self) -> None:
        """Generate, read the artifact, review, cancel, and remove, each behind its gate.

        The matrix states whether the lane executes at all, and a
        `temporarily_unavailable` row names the worker's control socket, so a
        launch that armed no worker reports the lane skipped naming that socket
        rather than failing five items against a service nobody started.
        """
        started = time.monotonic()
        matrix, payload = self.read_matrix()
        if matrix.absent_route:
            for name in self.IMAGE_ITEMS:
                self.absent(name, MATRIX_ROUTE, matrix)
            return
        if matrix.status != 200:
            for name in self.IMAGE_ITEMS:
                self.record(
                    name,
                    FAIL,
                    f"GET {MATRIX_ROUTE} answered {matrix.status}",
                    {"status": matrix.status},
                )
            return
        offer = tool_offer(payload, IMAGE_GENERATION_ROW)
        if self.lane_unavailable(self.IMAGE_ITEMS, offer, IMAGE_GENERATION_ROW):
            return
        bounds = offer.get("bounds") if offer is not None else None
        if not isinstance(bounds, Mapping):
            reason = "the matrix row admits the lane and carries no geometry bounds"
            for name in self.IMAGE_ITEMS:
                self.record(name, SKIPPED, reason, {"row": IMAGE_GENERATION_ROW})
            return
        language = launch_field(payload, "approval_profile")
        fields = self.image_grant_fields(bounds, language)
        grant = self.client.post_grant(IMAGE_GRANT_ROUTE, fields)
        token = grant_token(grant)
        if not token:
            reason = (
                f"the image grant answered {grant.status}: {refusal_sentence(grant)}; "
                "every device-reaching call in this lane passes one human approval "
                "and a single-use grant"
            )
            for name in self.IMAGE_ITEMS:
                self.record(name, SKIPPED, reason, {"grant_status": grant.status})
            return
        digest = self.check_image_generate(bounds, token, started)
        self.check_artifact_read(digest)
        self.check_image_review(bounds, language, digest)
        self.check_image_control(digest)

    def check_image_generate(self, bounds: Mapping[str, object], token: str, started: float) -> str:
        """Spend the grant on one job and return the artifact digest it published."""
        answer = self.client.post_json(
            "/api/tools/image/generate",
            {
                "profile_id": str(bounds.get("profile_id", "")),
                "prompt": IMAGE_PROMPT,
                "negative_prompt": IMAGE_NEGATIVE_PROMPT,
                "authorization": token,
                "seed": IMAGE_SEED,
                "width": bound_value(bounds, "width"),
                "height": bound_value(bounds, "height"),
                "steps": min(IMAGE_STEPS, bound_value(bounds, "max_steps", IMAGE_STEPS)),
            },
        )
        payload = answer.json()
        digest = str(payload.get("sha256", "")) if isinstance(payload, dict) else ""
        held = answer.status == 200 and bool(digest)
        self.record(
            "image_generate",
            PASS if held else FAIL,
            ""
            if held
            else f"generate answered {answer.status} naming "
            f"{'no artifact' if answer.status == 200 else refusal_sentence(answer)}",
            {"status": answer.status, "artifact": digest},
            started,
        )
        return digest

    def check_artifact_read(self, digest: str) -> None:
        """Read the published PNG over the credentialed artifact route."""
        if not digest:
            self.record(
                "artifact_read", SKIPPED, "the generate answer named no artifact digest", {}
            )
            return
        read = self.client.exchange("GET", f"/api/artifacts/{digest}.png")
        held = read.status == 200 and read.body.startswith(PNG_MAGIC)
        self.record(
            "artifact_read",
            PASS if held else FAIL,
            ""
            if held
            else f"the artifact read answered {read.status} carrying "
            f"{len(read.body)} bytes that open with no PNG signature",
            {"status": read.status, "bytes": len(read.body)},
        )

    def check_image_review(self, bounds: Mapping[str, object], language: str, digest: str) -> None:
        """Review the artifact against one declared constraint, behind its own grant.

        A review carries the claim alone and binds to the artifact through the
        provenance record, so its grant is signed over the same prompt digest
        the generation was. The lane admits one unexpired grant per client
        address, so this second grant waits where the refusal names a term
        inside the declared bound and reports the item skipped otherwise.
        """
        if not digest:
            self.record("image_review", SKIPPED, "no artifact was published to review", {})
            return
        fields = self.image_grant_fields(bounds, language)
        grant = self.client.post_grant(IMAGE_GRANT_ROUTE, fields)
        if grant.status == 429:
            waited = self.wait_for_image_grant(grant, fields)
            if waited is None:
                self.record(
                    "image_review",
                    SKIPPED,
                    f"the lane admits one unexpired grant per client and the generate "
                    f"grant's term leaves {grant.header('Retry-After') or 'an unstated'} "
                    f"second(s), above the {IMAGE_REVIEW_GRANT_WAIT_SECONDS} second bound "
                    f"this run declares",
                    {"grant_status": grant.status, "retry_after": grant.header("Retry-After")},
                )
                return
            grant = waited
        token = grant_token(grant)
        if not token:
            self.record(
                "image_review",
                SKIPPED,
                f"the review grant answered {grant.status}: {refusal_sentence(grant)}",
                {"grant_status": grant.status},
            )
            return
        name, description = IMAGE_REVIEW_CONSTRAINT
        answer = self.client.post_json(
            "/api/tools/image/review",
            {
                "authorization": token,
                "sha256": digest,
                "constraints": [{"name": name, "description": description}],
            },
        )
        payload = answer.json()
        completion = payload.get("completion") if isinstance(payload, dict) else None
        answered = bool(completion.get("answered")) if isinstance(completion, dict) else False
        schema = payload.get("schema_validity") if isinstance(payload, dict) else None
        valid = bool(schema.get("valid")) if isinstance(schema, dict) else False
        held = answer.status == 200 and answered
        self.record(
            "image_review",
            PASS if held else FAIL,
            ""
            if held
            else f"the review answered {answer.status} and the reviewer "
            f"{'returned no completion' if answer.status == 200 else refusal_sentence(answer)}",
            {"status": answer.status, "answered": answered, "schema_valid": valid},
        )

    def wait_for_image_grant(self, refusal: Answer, fields: Mapping[str, object]) -> Answer | None:
        """Retry one refused image grant inside the declared wait, or report none.

        The quota decays with the outstanding grant's own term, so `Retry-After`
        names the seconds until it ages out rather than a fixed window.
        """
        stated = refusal.header("Retry-After")
        try:
            seconds = int(stated)
        except ValueError:
            return None
        if seconds < 0 or seconds > IMAGE_REVIEW_GRANT_WAIT_SECONDS:
            return None
        time.sleep(seconds + 1)
        return self.client.post_grant(IMAGE_GRANT_ROUTE, fields)

    def check_image_control(self, digest: str) -> None:
        """Cancel a job this run does not hold, then retract the artifact.

        A cancel naming a job the worker is not running answers `not_running`
        inside a 200, which is the truth the caller asked for, so the item reads
        the status rather than requiring a job to interrupt. Remove runs last
        because it retracts the publication marker the review read.
        """
        request_id = uuid.uuid4().hex
        cancel = self.client.post_json("/api/tools/image/cancel", {"request_id": request_id})
        payload = cancel.json()
        observed = str(payload.get("status", "")) if isinstance(payload, dict) else ""
        self.record(
            "image_cancel",
            PASS if cancel.status == 200 else FAIL,
            "" if cancel.status == 200 else f"the cancel answered {cancel.status}",
            {"status": cancel.status, "worker_status": observed, "request_id": request_id},
        )
        if not digest:
            self.record("image_remove", SKIPPED, "no artifact was published to retract", {})
            return
        remove = self.client.post_json("/api/tools/image/remove", {"sha256": digest})
        payload = remove.json()
        removed = bool(payload.get("removed")) if isinstance(payload, dict) else False
        held = remove.status == 200 and removed
        self.record(
            "image_remove",
            PASS if held else FAIL,
            "" if held else f"the removal answered {remove.status}: {refusal_sentence(remove)}",
            {"status": remove.status, "removed": removed},
        )

    # -- the teardown phase ----------------------------------------------

    def run_teardown(self) -> None:
        started = time.monotonic()
        if not self.request.stop_command:
            reason = "the run names no --stop-command, so nothing here observes an absence"
            self.record("vulkan_lease_free", SKIPPED, reason, {}, started)
            self.record("teardown_leaves_no_residue", SKIPPED, reason, {})
            return
        completed = subprocess.run(  # noqa: S603
            list(self.request.stop_command), capture_output=True, check=False
        )
        stop_evidence = {
            "exit_status": completed.returncode,
            "stdout": completed.stdout.decode("utf-8", "replace")[:400],
        }
        self.record(
            "stop_command",
            PASS if completed.returncode == 0 else FAIL,
            "" if completed.returncode == 0 else f"the stop command exited {completed.returncode}",
            stop_evidence,
            started,
        )
        self.check_lease_free()
        self.check_no_residue()

    def check_lease_free(self) -> None:
        started = time.monotonic()
        path = self.request.lease_path
        if path is None:
            self.record("vulkan_lease_free", SKIPPED, "the run names no --lease-path", {}, started)
            return
        free = WorkloadLease(path=path).is_free()
        self.record(
            "vulkan_lease_free",
            PASS if free else FAIL,
            "" if free else f"the Vulkan workload lease is still held after the stop: {path}",
            {"lease": str(path), "free": free},
            started,
        )

    def check_no_residue(self) -> None:
        """Every identity the appliance record named, proven gone after the stop."""
        started = time.monotonic()
        path = self.request.appliance_record
        if path is None:
            self.record(
                "teardown_leaves_no_residue",
                SKIPPED,
                "the run names no --appliance-state",
                {},
                started,
            )
            return
        record = appliance_state.ApplianceRecord(path=path).read()
        if record is None:
            self.record(
                "teardown_leaves_no_residue",
                SKIPPED,
                f"the appliance record is unreadable or absent: {path}",
                {},
                started,
            )
            return
        residue: list[str] = []
        ports: list[int] = [self.client.port]
        for child in record.children:
            if read_start_time(child.pid) == child.start_time:
                residue.append(f"{child.name} pid {child.pid} still carries its recorded identity")
            if child.port:
                ports.append(child.port)
            if child.socket_path not in ("", "-") and Path(child.socket_path).exists():
                residue.append(f"{child.name} left its socket at {child.socket_path}")
        if record.gateway_port:
            ports.append(record.gateway_port)
        listening = [
            port for port in sorted(set(ports)) if _listener_answers(self.client.host, port)
        ]
        residue.extend(f"a listener still answers on port {port}" for port in listening)
        if record.state not in ("stopped", "failed"):
            residue.append(f"the record state is {record.state} rather than stopped")
        self.record(
            "teardown_leaves_no_residue",
            PASS if not residue else FAIL,
            "; ".join(residue),
            {
                "record_state": record.state,
                "children": len(record.children),
                "listening_ports": listening,
            },
            started,
        )

    # -- the whole run ---------------------------------------------------

    def check_origin_reachable(self) -> bool:
        """Whether the origin answers at all, decided before any claim is read.

        An origin that refuses the connection makes every live check fail for
        one reason, and a driver that let the first `ConnectionRefusedError`
        leave the process would write no report at all. This answers once, and a
        refusal short-circuits the live phase into one named skip rather than
        thirty copies of the same sentence.
        """
        started = time.monotonic()
        try:
            answer = self.client.exchange("GET", "/api/health", authenticated=False)
        except (OSError, HTTPException) as error:
            self.record(
                "origin_reachable",
                FAIL,
                f"{self.request.base} answered nothing: {error}",
                {"base": self.request.base},
                started,
            )
            return False
        self.record("origin_reachable", PASS, "", {"status": answer.status}, started)
        return True

    def guarded(self, name: str, check: Callable[[], None]) -> None:
        """Run one check, and turn a transport failure into that check's own failure.

        A socket that refuses, resets, or half-answers mid-run is a finding
        about the gateway rather than an end to the run, so it lands as this
        item's failure and the remaining items still report.
        """
        try:
            check()
        except (OSError, HTTPException) as error:
            self.record(name, FAIL, f"the exchange refused: {error}", {})

    def live_checks(self) -> tuple[tuple[str, Callable[[], None]], ...]:
        """Every check the live phase runs, named so a short-circuit can list them."""
        checks: list[tuple[str, Callable[[], None]]] = [
            ("unauthenticated_refusal", self.check_unauthenticated_refusal),
            ("pairing", self.check_pairing),
            ("roster_join", self.check_roster_join),
        ]
        checks.extend(
            (f"text_turn:{model}", partial(self.check_text_turn, model))
            for model in self.request.text_models
        )
        checks.extend(
            (f"vision_consumes_image:{model}", partial(self.check_vision_consumes_image, model))
            for model in self.request.vision_models
        )
        checks.extend(
            [
                ("midstream_cancel", self.check_midstream_cancel),
                ("calculator", self.check_calculator),
                ("file_search", self.check_file_search),
                (
                    "document_extraction:text.pdf",
                    partial(self.check_document, "text.pdf", "application/pdf", ("page",)),
                ),
                (
                    "document_extraction:two-paragraphs.docx",
                    partial(
                        self.check_document,
                        "two-paragraphs.docx",
                        DOCX_MEDIA_TYPE,
                        ("paragraph",),
                    ),
                ),
                ("web_search_then_fetch", self.check_web_lane),
                ("image_generate", self.check_image_lane),
                ("browser_history_import", self.check_browser_history_import),
                ("conversation_open", self.open_conversations),
                ("history_survives_restart", self.check_history_across_restart),
            ]
        )
        return tuple(checks)

    def run(self) -> list[CheckResult]:
        live = self.live_checks()
        if self.check_origin_reachable():
            for name, check in live:
                self.guarded(name, check)
        else:
            for name, _check in live:
                self.record(
                    name,
                    SKIPPED,
                    f"the origin {self.request.base} answered nothing, so no live claim was read",
                    {},
                )
        self.run_teardown()
        return self.results


def _listener_answers(host: str, port: int) -> bool:
    """Whether a TCP connect to one loopback port succeeds right now."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.5)
        try:
            probe.connect((host, port))
        except OSError:
            return False
        return True


# ---------------------------------------------------------------------------
# The report
# ---------------------------------------------------------------------------


def counts(results: Sequence[CheckResult]) -> dict[str, int]:
    return {
        status: sum(1 for result in results if result.status == status)
        for status in (PASS, FAIL, SKIPPED)
    }


def report_document(
    request: AcceptanceRequest, results: Sequence[CheckResult]
) -> dict[str, object]:
    return {
        "schema": "qwen-apu-acceptance-report-v1",
        "base": request.base,
        "text_models": list(request.text_models),
        "vision_models": list(request.vision_models),
        "restart_command": list(request.restart_command),
        "stop_command": list(request.stop_command),
        "counts": counts(results),
        "checks": [result.to_json() for result in results],
    }


def render_markdown(request: AcceptanceRequest, results: Sequence[CheckResult]) -> str:
    tally = counts(results)
    lines = [
        "# Launch acceptance",
        "",
        f"Origin `{request.base}`. "
        f"{tally[PASS]} pass, {tally[FAIL]} fail, {tally[SKIPPED]} skipped.",
        "",
        "| Check | Result | Reason or evidence |",
        "| --- | --- | --- |",
    ]
    for result in results:
        detail = result.reason or ", ".join(
            f"{key}={value}" for key, value in sorted(result.evidence.items())
        )
        escaped = detail.replace("|", r"\|")
        lines.append(f"| `{result.name}` | {result.status} | {escaped} |")
    lines.append("")
    lines.append(
        "A skipped item names the route or the argument its claim needs; a 404 from a "
        "route this branch does not mount is a skip, and a 401 or 403 is a live gate "
        "answering and stays a failure."
    )
    return "\n".join(lines) + "\n"


def require_inside_root(paths: RuntimePaths, report: Path) -> Path:
    """The report lands under the runtime root, which is the only tree this writes to."""
    resolved = report if report.is_absolute() else (paths["qwen_home_results"] / report)
    # `is_inside_root` resolves both sides and takes `relative_to`, which a
    # string prefix test does not: `<root>-scratch` prefixes the root's own
    # spelling while sitting beside it rather than under it.
    if not paths.is_inside_root(resolved.parent):
        raise AcceptanceRefused(
            f"the acceptance report writes under the runtime root alone; {resolved} is outside "
            f"{paths.root}"
        )
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def run(paths: RuntimePaths, request: AcceptanceRequest) -> int:
    """Run every check, write both reports, and exit non-zero on any failure."""
    destination = require_inside_root(paths, request.report)
    results = AcceptanceRun(paths, request).run()
    document = report_document(request, results)
    destination.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    markdown = destination.with_suffix(".md")
    markdown.write_text(render_markdown(request, results), encoding="utf-8")
    tally = counts(results)
    print(
        f"acceptance_report={destination} markdown={markdown} "
        f"pass={tally[PASS]} fail={tally[FAIL]} skipped={tally[SKIPPED]}"
    )
    for result in results:
        if result.status != PASS:
            print(f"{result.status}\t{result.name}\t{result.reason}")
    return 1 if tally[FAIL] else 0
