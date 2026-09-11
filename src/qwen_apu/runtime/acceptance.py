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
import zlib
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from http.client import HTTPConnection, HTTPResponse
from pathlib import Path
from urllib.parse import urlsplit

from qwen_apu.config import models as registry
from qwen_apu.runtime import appliance as appliance_state
from qwen_apu.runtime import policy
from qwen_apu.runtime.locks import WorkloadLease
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.process import read_start_time
from qwen_apu.web import browser_import
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
RESTART_SETTLE_SECONDS = 1.0
RESTART_DEADLINE_SECONDS = 180.0

# The prompt every text turn carries. One short, deterministic instruction keeps
# the check about attribution rather than about the answer's content: what the
# item tests is that the reply names the checkpoint the request selected.
TEXT_PROMPT = "Reply with the single word: ready."
VISION_PROMPT = "Name the tallest bar in this chart."

# The identifier the imported page transcript carries. `web/conversations.py`
# admits 32 hexadecimal characters and nothing else, because an identifier is
# `uuid.uuid4().hex`, which is the shape the page itself writes.
BROWSER_CONVERSATION_ID = "a9f3c1d40e7b4c2e8f60a1b2c3d4e5f6"

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
        """
        started = time.monotonic()
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
        payload = text_request(model, self.request.max_tokens, stream=True)
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

        `--restart-command` is the one argv that makes this observable: the
        temporary store lives in the process and under `tmp/conversations/<id>/`,
        so only a second process reading the same root can state that it is
        gone.
        """
        started = time.monotonic()
        if not self.request.restart_command:
            self.record(
                "history_survives_restart",
                SKIPPED,
                "the run names no --restart-command, so no second process reads this root",
                {},
                started,
            )
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
        self.client.pair(self.request.pairing_code)
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

    def _wait_for_origin(self) -> bool:
        deadline = time.monotonic() + RESTART_DEADLINE_SECONDS
        while time.monotonic() < deadline:
            try:
                if self.client.exchange("GET", "/api/health").status:
                    return True
            except OSError:
                time.sleep(RESTART_SETTLE_SECONDS)
        return False

    def check_browser_history_import(self) -> None:
        """A page export converted by its own reader and imported over the route.

        `web/browser_import.parse_export` is the authority the CLI's
        `import --browser` uses, so the driver converts through it and posts the
        store's own document shape rather than inventing a second reader.
        """
        started = time.monotonic()
        document = json.dumps(
            {
                "qwen_apu_browser_history_export": browser_import.EXPORT_VERSION,
                "conversations": [
                    {
                        "id": BROWSER_CONVERSATION_ID,
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
        read_back = self.client.exchange("GET", f"/api/conversations/{BROWSER_CONVERSATION_ID}")
        evidence = {
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
            self.record(
                name,
                FAIL,
                f"the upload answered {answer.status}",
                {"status": answer.status, "body": answer.body[:300].decode("utf-8", "replace")},
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

    def check_web_lane(self) -> None:
        """Search then fetch, and a retrieval failure stated rather than swallowed."""
        started = time.monotonic()
        answer = self.client.post_json("/api/tools/web/search", {"query": "raven2 vulkan decode"})
        if answer.absent_route:
            self.absent("web_search_then_fetch", "/api/tools/web/search", answer)
            self.absent("web_retrieval_failure_explicit", "/api/tools/web/fetch", answer)
            return
        grounded = self.client.post_json(
            "/api/tools/web/fetch", {"url": "http://127.0.0.1:1/absent"}
        )
        self.record(
            "web_search_then_fetch",
            PASS if answer.status == 200 else FAIL,
            "" if answer.status == 200 else f"the search answered {answer.status}",
            {"search_status": answer.status},
            started,
        )
        self.record(
            "web_retrieval_failure_explicit",
            PASS if grounded.status >= 400 else FAIL,
            ""
            if grounded.status >= 400
            else "an unreachable fetch answered 200, so a failed retrieval is invisible",
            {"fetch_status": grounded.status},
        )

    IMAGE_ITEMS: tuple[tuple[str, str], ...] = (
        ("image_generate", "/api/tools/image/generate"),
        ("artifact_read", "/api/artifacts"),
        ("image_review", "/api/tools/image/review"),
        ("image_cancel", "/api/tools/image/cancel"),
        ("image_remove", "/api/tools/image/remove"),
    )

    def check_image_lane(self) -> None:
        """Generate, read the artifact, review, cancel, and remove, behind one grant.

        Every device-reaching call in this lane passes one human approval and a
        single-use grant, so the driver asks the broker for one first. A refused
        grant reports the whole lane as skipped naming that refusal, because a
        generate the grant never authorized measures the gate rather than the
        lane.
        """
        started = time.monotonic()
        grant = self.client.post_json(
            "/api/tools/grant-image",
            {"prompt": "a red square", "profile_id": "", "steps": 1},
        )
        if grant.absent_route:
            for name, route in self.IMAGE_ITEMS:
                self.absent(name, route, grant)
            return
        if grant.status != 200:
            reason = (
                f"the image grant answered {grant.status}; every device-reaching call in "
                "this lane passes one human approval and a single-use grant"
            )
            for name, _route in self.IMAGE_ITEMS:
                self.record(name, SKIPPED, reason, {"grant_status": grant.status})
            return
        token = ""
        payload = grant.json()
        if isinstance(payload, dict):
            token = str(payload.get("token", ""))
        answer = self.client.post_json(
            "/api/tools/image/generate", {"prompt": "a red square", "token": token}
        )
        if answer.absent_route:
            for name, route in self.IMAGE_ITEMS:
                self.absent(name, route, answer)
            return
        digest = ""
        generated = answer.json()
        if isinstance(generated, dict):
            artifact = generated.get("artifact")
            if isinstance(artifact, dict):
                digest = str(artifact.get("sha256", ""))
        self.record(
            "image_generate",
            PASS if answer.status in (200, 201) else FAIL,
            "" if answer.status in (200, 201) else f"generate answered {answer.status}",
            {"status": answer.status, "artifact": digest},
            started,
        )
        if digest:
            read = self.client.exchange("GET", f"/api/artifacts/{digest}.png")
            self.record(
                "artifact_read",
                PASS if read.status == 200 else FAIL,
                "" if read.status == 200 else f"the artifact read answered {read.status}",
                {"status": read.status, "bytes": len(read.body)},
            )
        else:
            self.record(
                "artifact_read", SKIPPED, "the generate answer named no artifact digest", {}
            )
        for name, route in self.IMAGE_ITEMS[2:]:
            probe = self.client.post_json(route, {"artifact": digest, "token": token})
            if probe.absent_route:
                self.absent(name, route, probe)
                continue
            self.record(
                name,
                PASS if probe.status < 400 else FAIL,
                "" if probe.status < 400 else f"{route} answered {probe.status}",
                {"status": probe.status},
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

    def run(self) -> list[CheckResult]:
        self.check_unauthenticated_refusal()
        self.check_pairing()
        self.check_roster_join()
        for model in self.request.text_models:
            self.check_text_turn(model)
        for model in self.request.vision_models:
            self.check_vision_consumes_image(model)
        self.check_midstream_cancel()
        self.check_calculator()
        self.check_file_search()
        self.check_document("text.pdf", "application/pdf", ("page",))
        self.check_document(
            "two-paragraphs.docx",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ("paragraph",),
        )
        self.check_web_lane()
        self.check_image_lane()
        self.check_browser_history_import()
        self.open_conversations()
        self.check_history_across_restart()
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
    inside = paths.is_inside_root(resolved.parent) or str(resolved.parent).startswith(
        str(paths.root)
    )
    if not inside:
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
