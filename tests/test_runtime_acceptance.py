"""The acceptance driver against a real gateway and a scripted client.

Two layers cover the two things the driver decides. The integration layer
assembles `qwen_apu.web.assemble.assemble` over a temporary runtime root, the
way `tests/test_conversation_lifecycle.py` does, in front of the fake upstream
`tests/test_web_gateway.py` defines; the driver then runs every check against a
process that answers the real routes, which is what proves a check reads the
gateway rather than a mock of it. The scripted layer replaces the driver's
client with one that answers from a table, which is what reaches the branches a
device-free run cannot otherwise produce: an image lane behind a grant, a served
model that disagrees with the request, a vision arm that ignores its image, and
a teardown that finds residue.

`_FakeUpstream` answers a fixed roster and echoes one alias, so this file
subclasses it rather than editing it: `BEHAVIOR` carries the roster, whether a
completion states a model, whether the answer depends on the image parts, and
how many frames a stream writes.
"""

from __future__ import annotations

import fcntl
import json
import os
import socket
import sys
import threading
from collections.abc import Iterator, Mapping
from http.server import ThreadingHTTPServer
from pathlib import Path

import pytest

from qwen_apu.runtime import acceptance, appliance
from qwen_apu.runtime.acceptance import (
    FAIL,
    PASS,
    SKIPPED,
    AcceptanceRequest,
    AcceptanceRun,
    Answer,
)
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.process import read_start_time
from qwen_apu.runtime.state import RuntimeRecord, RuntimeState
from qwen_apu.web import assemble as gateway_assembly
from qwen_apu.web.auth import PAIRING_CODE_FILENAME
from qwen_apu.web.history import DOCUMENT_VERSION
from test_web_gateway import _FakeUpstream

TREE = Path(__file__).resolve().parents[1]
FIXTURES = TREE / "tests" / "fixtures" / "documents"
EXCHANGE_DEADLINE_SECONDS = 20.0

TEXT_MODELS: tuple[str, ...] = ("qwen35-08b", "qwen38-2b-distill", "qwen38-4b-distill")
VISION_MODELS: tuple[str, ...] = ("lfm25-vl-16b",)

BEHAVIOR: dict[str, object] = {
    "roster": [*TEXT_MODELS, *VISION_MODELS],
    "state_model": True,
    "image_sensitive": True,
}


def _reset_behavior() -> None:
    BEHAVIOR["roster"] = [*TEXT_MODELS, *VISION_MODELS]
    BEHAVIOR["state_model"] = True
    BEHAVIOR["image_sensitive"] = True


class _AcceptanceUpstream(_FakeUpstream):
    """`_FakeUpstream` with the three knobs a device-free acceptance run needs."""

    def do_GET(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        if self.path == "/v1/models":
            roster = BEHAVIOR["roster"]
            names = list(roster) if isinstance(roster, list) else []
            self._json({"object": "list", "data": [{"id": name} for name in names]})
            return
        super().do_GET()

    def do_POST(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        if self.path == "/tokenize":
            content = json.loads(body).get("content", "")
            self._json({"tokens": list(range(len(content.split())))})
            return
        if self.path != "/v1/chat/completions":
            self._json({"error": "no such endpoint"}, status=404)
            return
        payload = json.loads(body or b"{}")
        requested = str(payload.get("model") or "")
        text = "the tallest bar is middle" if _carries_image(payload) else "ready"
        if not BEHAVIOR["image_sensitive"]:
            text = "ready"
        if payload.get("stream"):
            self._stream(requested, text)
            return
        answer: dict[str, object] = {
            "id": "chatcmpl-whole",
            "choices": [{"index": 0, "message": {"content": text}}],
        }
        if BEHAVIOR["state_model"]:
            answer["model"] = requested
        self._json(answer)

    def _stream(self, model: str, text: str) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        try:
            for word in text.split():
                frame = json.dumps(
                    {"model": model, "choices": [{"index": 0, "delta": {"content": word}}]}
                )
                self.wfile.write(b"data: " + frame.encode("utf-8") + b"\n\n")
                self.wfile.flush()
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            # The mid-stream cancel check closes the socket while frames are
            # still being written, which is exactly this exception.
            pass


def _write_router_record(state_directory: Path, port: int) -> Path:
    """A record naming this process as a router-mode server on the fake port.

    Router mode is what admits several checkpoints at once: the standalone
    branch maps every id to the one alias its argv carried, so a fixture that
    served three models through a standalone record would expect one name for
    all three and answer 502 on two of them.
    """
    state_directory.mkdir(parents=True, exist_ok=True)
    record_path = state_directory / "runtime.json"
    RuntimeRecord(record_path).write(
        RuntimeState(
            state="ready",
            server_pid=os.getpid(),
            server_start_time=read_start_time(os.getpid()) or 0,
            port=port,
            model_id="router",
            mode="router",
            deployment="fixture",
            profile="low-async",
        )
    )
    return record_path


def _carries_image(payload: Mapping[str, object]) -> bool:
    messages = payload.get("messages")
    if not isinstance(messages, list):
        return False
    for message in messages:
        content = message.get("content") if isinstance(message, dict) else None
        if isinstance(content, list) and any(
            isinstance(part, dict) and part.get("type") == "image_url" for part in content
        ):
            return True
    return False


@pytest.fixture(autouse=True)
def _restore_process_umask() -> Iterator[None]:
    """Undo the umask `qwen_apu.tools.ledger.Ledger.__init__` leaves set.

    `assemble()` builds one `Ledger`, whose `__init__` runs `os.umask(0o077)`
    and never restores it; `os.umask` is process-wide, so without this fixture
    the leak narrows every mode a later test file asserts on a freshly created
    file, which is how a lease mode and a ledger directory mode fail in a run
    where this module happens to go first.
    """
    previous = os.umask(0o022)
    os.umask(previous)
    yield
    os.umask(previous)


@pytest.fixture(autouse=True)
def _behavior() -> Iterator[None]:
    _reset_behavior()
    yield
    _reset_behavior()


class _QuietUpstreamServer(ThreadingHTTPServer):
    """A server whose log stays free of the cancel check's own disconnects.

    `BaseHTTPRequestHandler.finish` flushes the write file after the handler
    returns, and the mid-stream cancel check closes its socket while frames are
    still pending, so the default `handle_error` prints a traceback for a
    disconnect the test deliberately caused. Every other error still prints.
    """

    def handle_error(self, request: object, client_address: object) -> None:
        kind = sys.exc_info()[0]
        if kind is not None and issubclass(kind, ConnectionError):
            return
        super().handle_error(request, client_address)  # type: ignore[arg-type]


@pytest.fixture(scope="module")
def upstream() -> Iterator[ThreadingHTTPServer]:
    server = _QuietUpstreamServer(("127.0.0.1", 0), _AcceptanceUpstream)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05})
    thread.start()
    try:
        yield server
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=EXCHANGE_DEADLINE_SECONDS)


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])


class Fixture:
    """One assembled gateway, its runtime root, and the pairing code it printed."""

    def __init__(self, paths: RuntimePaths, port: int) -> None:
        self.paths = paths
        self.port = port
        request = gateway_assembly.GatewayRequest(
            port=port,
            static_root=paths.root / "static",
            web_profile="web-open",
            require_deployment=False,
            file_roots=(TREE / "docs",),
        )
        self.gateway, self.session = gateway_assembly.assemble(paths, request)
        self.code = self.session.start()
        self.thread = threading.Thread(target=self.gateway.serve_forever)
        self.thread.start()

    @property
    def base(self) -> str:
        return f"http://127.0.0.1:{self.port}"

    def stop(self) -> None:
        self.gateway.shutdown()
        self.thread.join(timeout=EXCHANGE_DEADLINE_SECONDS)


@pytest.fixture
def gateway(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, upstream: ThreadingHTTPServer
) -> Iterator[Fixture]:
    monkeypatch.setenv("QWEN_HOME", str(tmp_path / "root"))
    paths = RuntimePaths.resolve(TREE)
    paths.lay_out()
    key = paths["qwen_home_web_token_key"]
    key.write_text("acceptance-signing-key\n", encoding="utf-8")
    key.chmod(0o600)
    (paths.root / "static").mkdir(exist_ok=True)
    (paths.root / "static" / "index.html").write_text(
        "<!doctype html><html><body>page</body></html>\n", encoding="utf-8"
    )
    _write_router_record(paths["qwen_home_state"], int(upstream.server_address[1]))
    running = Fixture(paths, _free_port())
    try:
        yield running
    finally:
        running.stop()


def _request(gateway: Fixture, **overrides: object) -> AcceptanceRequest:
    fields: dict[str, object] = {
        "base": gateway.base,
        "pairing_code": gateway.code,
        "report": Path("acceptance/report.json"),
        "text_models": TEXT_MODELS,
        "vision_models": VISION_MODELS,
        "document_fixtures": FIXTURES,
        "file_search_root": TREE / "docs",
    }
    fields.update(overrides)
    return AcceptanceRequest(**fields)  # type: ignore[arg-type]


def _by_name(results: list[acceptance.CheckResult]) -> dict[str, acceptance.CheckResult]:
    return {result.name: result for result in results}


# ---------------------------------------------------------------------------
# The gateway-backed run
# ---------------------------------------------------------------------------


def test_a_whole_run_passes_every_reachable_check(gateway: Fixture) -> None:
    results = _by_name(AcceptanceRun(gateway.paths, _request(gateway)).run())

    assert results["unauthenticated_refusal"].status == PASS
    assert results["pairing"].status == PASS
    assert results["roster_join"].status == PASS, results["roster_join"].reason
    for model in TEXT_MODELS:
        result = results[f"text_turn:{model}"]
        assert result.status == PASS, result.reason
        assert result.evidence["served_model"] == model
    vision = results["vision_consumes_image:lfm25-vl-16b"]
    assert vision.status == PASS, vision.reason
    assert vision.evidence["with_image"] != vision.evidence["withheld"]
    assert results["midstream_cancel"].status == PASS, results["midstream_cancel"].reason
    assert results["calculator"].status == PASS, results["calculator"].reason
    assert results["file_search"].status == PASS, results["file_search"].reason
    assert results["file_search_scope"].status == PASS
    assert results["document_extraction:two-paragraphs.docx"].status == PASS
    pdf = results["document_extraction:text.pdf"]
    assert pdf.status in (PASS, SKIPPED), pdf.reason
    if pdf.status == SKIPPED:
        assert "pypdf" in pdf.reason
    assert results["browser_history_import"].status == PASS
    assert results["conversation_open"].status == PASS

    # Both lanes read the tool matrix first, and this launch arms neither: no
    # row of remote/web-profiles.tsv names the selected checkpoint and no image
    # profile is armed, so every item skips carrying the matrix's own sentence.
    assert results["web_search_then_fetch"].status == SKIPPED
    assert "web_search" in results["web_search_then_fetch"].reason
    assert results["image_generate"].status == SKIPPED
    assert "image_generation" in results["image_generate"].reason
    # No stop argv, so the two absence items name the argument they need.
    assert results["vulkan_lease_free"].status == SKIPPED
    assert results["teardown_leaves_no_residue"].status == SKIPPED


def test_a_text_row_is_refused_before_it_receives_an_image(gateway: Fixture) -> None:
    """`remote/models.tsv` reads projector none for a text row, so the arm never runs."""
    run = AcceptanceRun(gateway.paths, _request(gateway))
    run.check_pairing()
    run.check_vision_consumes_image("qwen38-2b-distill")
    result = _by_name(run.results)["vision_consumes_image:qwen38-2b-distill"]
    assert result.status == FAIL
    assert "projector none" in result.reason
    assert result.evidence["projector"] == "none"


def test_a_row_absent_from_the_registry_fails_the_vision_arm(gateway: Fixture) -> None:
    run = AcceptanceRun(gateway.paths, _request(gateway))
    run.check_pairing()
    run.check_vision_consumes_image("a-checkpoint-no-row-names")
    result = _by_name(run.results)["vision_consumes_image:a-checkpoint-no-row-names"]
    assert result.status == FAIL
    assert "carries no row" in result.reason


def test_two_imports_over_one_root_each_carry_their_own_identifier(gateway: Fixture) -> None:
    """The store refuses a conversation it already holds, so each run draws its own."""
    run = AcceptanceRun(gateway.paths, _request(gateway))
    run.check_pairing()
    run.check_browser_history_import()
    run.check_browser_history_import()
    results = [entry for entry in run.results if entry.name == "browser_history_import"]
    assert [entry.status for entry in results] == [PASS, PASS]
    first, second = (str(entry.evidence["conversation_id"]) for entry in results)
    assert first != second


def test_the_store_refuses_a_second_import_of_one_identifier(gateway: Fixture) -> None:
    """The refusal the per-run identifier exists to avoid, stated by the store itself."""
    run = AcceptanceRun(gateway.paths, _request(gateway))
    run.check_pairing()
    run.check_browser_history_import()
    held = str(_by_name(run.results)["browser_history_import"].evidence["conversation_id"])
    document = {
        "document_version": DOCUMENT_VERSION,
        "conversations": [
            {
                "conversation_id": held,
                "mode": "saved",
                "title": "a second copy",
                "created_utc": "2026-01-01T00:00:00Z",
                "updated_utc": "2026-01-01T00:00:00Z",
                "workflow_state": "idle",
                "messages": [],
            }
        ],
    }
    answer = run.client.post_json("/api/conversations/import", document)
    assert answer.status == 400
    assert "already holds" in answer.body.decode("utf-8")


def test_the_previous_report_proves_the_saved_conversation_survived(gateway: Fixture) -> None:
    opening = AcceptanceRun(gateway.paths, _request(gateway))
    opening.check_pairing()
    opening.open_conversations()
    report = gateway.paths["qwen_home_results"] / "previous.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(
        json.dumps(acceptance.report_document(_request(gateway), opening.results)),
        encoding="utf-8",
    )

    later = AcceptanceRun(gateway.paths, _request(gateway, previous_report=report))
    # A pairing code dies on its first use and a restart mints another, so this
    # second run carries the session the first one paired rather than spending
    # a code this one process will not mint again.
    later.client.cookie = opening.client.cookie
    later.check_history_across_restart()
    result = _by_name(later.results)["history_survives_restart"]
    assert result.status == PASS, result.reason
    assert result.evidence["listed"] is True
    assert result.evidence["conversation_id"] == opening.saved_conversation


def test_a_previous_conversation_the_store_lost_fails_the_history_item(
    gateway: Fixture,
) -> None:
    report = gateway.paths["qwen_home_results"] / "previous.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(
        json.dumps(
            {
                "schema": "qwen-apu-acceptance-report-v1",
                "checks": [
                    {
                        "name": "conversation_open",
                        "status": PASS,
                        "evidence": {"saved": "e" * 32, "temporary": "f" * 32},
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    run = AcceptanceRun(gateway.paths, _request(gateway, previous_report=report))
    run.check_pairing()
    run.check_history_across_restart()
    result = _by_name(run.results)["history_survives_restart"]
    assert result.status == FAIL, result.reason
    assert "absent from the listing" in result.reason
    assert result.evidence["read_status"] == 404


def test_a_run_naming_neither_history_argument_skips_the_item(gateway: Fixture) -> None:
    run = AcceptanceRun(gateway.paths, _request(gateway))
    run.check_history_across_restart()
    result = _by_name(run.results)["history_survives_restart"]
    assert result.status == SKIPPED
    assert "--previous-report" in result.reason


def test_a_completion_that_states_no_model_fails_the_text_turn(gateway: Fixture) -> None:
    BEHAVIOR["state_model"] = False
    run = AcceptanceRun(gateway.paths, _request(gateway))
    run.check_pairing()
    run.check_text_turn("qwen38-2b-distill")
    result = _by_name(run.results)["text_turn:qwen38-2b-distill"]
    assert result.status == FAIL
    assert "states no served model" in result.reason


def test_a_model_the_router_refuses_skips_rather_than_fails(gateway: Fixture) -> None:
    BEHAVIOR["roster"] = ["qwen38-2b-distill"]
    run = AcceptanceRun(gateway.paths, _request(gateway))
    run.check_pairing()
    run.check_text_turn("qwen38-4b-distill")
    result = _by_name(run.results)["text_turn:qwen38-4b-distill"]
    assert result.status == SKIPPED
    assert "does not admit" in result.reason


def test_a_vision_arm_that_ignores_its_image_fails(gateway: Fixture) -> None:
    BEHAVIOR["image_sensitive"] = False
    run = AcceptanceRun(gateway.paths, _request(gateway))
    run.check_pairing()
    run.check_vision_consumes_image("lfm25-vl-16b")
    result = _by_name(run.results)["vision_consumes_image:lfm25-vl-16b"]
    assert result.status == FAIL
    assert "changed nothing" in result.reason


def test_the_roster_refuses_a_registry_field_that_disagrees(
    gateway: Fixture, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A row whose displayed tier differs from the registry's is the join failing."""
    run = AcceptanceRun(gateway.paths, _request(gateway))
    run.check_pairing()
    original = run.client.exchange

    def altered(method: str, path: str, **kwargs: object) -> Answer:
        answer = original(method, path, **kwargs)  # type: ignore[arg-type]
        if path != "/api/models":
            return answer
        payload = answer.json()
        assert isinstance(payload, dict)
        models = payload["models"]
        assert isinstance(models, list)
        models[0]["tier"] = "invented-tier"
        return Answer(answer.status, json.dumps(payload).encode("utf-8"), answer.headers)

    monkeypatch.setattr(run.client, "exchange", altered)
    run.check_roster_join()
    result = _by_name(run.results)["roster_join"]
    assert result.status == FAIL
    assert "invented-tier" in result.reason


def test_the_report_writes_json_and_markdown_under_the_root(gateway: Fixture) -> None:
    request = _request(gateway)
    code = acceptance.run(gateway.paths, request)
    destination = gateway.paths["qwen_home_results"] / "acceptance" / "report.json"
    assert destination.is_file()
    markdown = destination.with_suffix(".md")
    assert markdown.is_file()
    document = json.loads(destination.read_text(encoding="utf-8"))
    assert document["schema"] == "qwen-apu-acceptance-report-v1"
    assert document["counts"][PASS] > 0
    assert "| Check | Result | Reason or evidence |" in markdown.read_text(encoding="utf-8")
    # Every failure is an exit status rather than a line nobody reads.
    assert code == (1 if document["counts"][FAIL] else 0)


@pytest.mark.parametrize("suffix", ("elsewhere", ""))
def test_a_report_outside_the_runtime_root_refuses(
    gateway: Fixture, tmp_path: Path, suffix: str
) -> None:
    """A sibling that prefixes the root's spelling is outside it all the same."""
    parent = tmp_path / suffix if suffix else Path(str(gateway.paths.root) + "-scratch")
    outside = parent / "report.json"
    with pytest.raises(acceptance.AcceptanceRefused, match="runtime root alone"):
        acceptance.run(gateway.paths, _request(gateway, report=outside))
    assert not outside.exists()
    assert not parent.exists()


# ---------------------------------------------------------------------------
# The scripted client: the branches a device-free gateway cannot produce
# ---------------------------------------------------------------------------


class ScriptedClient:
    """A client that answers from a table, so a check's every branch is reachable."""

    def __init__(self, table: Mapping[tuple[str, str], Answer]) -> None:
        self.table = dict(table)
        self.host = "127.0.0.1"
        self.port = 0
        self.cookie = "scripted"
        self.seen: list[tuple[str, str]] = []

    def _answer(self, method: str, path: str) -> Answer:
        self.seen.append((method, path))
        return self.table.get((method, path), Answer(404, b'{"error":"no route"}', {}))

    def exchange(self, method: str, path: str, **_kwargs: object) -> Answer:
        return self._answer(method, path)

    def post_json(self, path: str, _payload: object, **_kwargs: object) -> Answer:
        return self._answer("POST", path)

    def pair(self, _code: str) -> Answer:
        return self._answer("POST", "/api/pair")


def _scripted(
    paths: RuntimePaths, table: Mapping[tuple[str, str], Answer], **overrides: object
) -> AcceptanceRun:
    fields: dict[str, object] = {
        "base": "http://127.0.0.1:1",
        "pairing_code": "code",
        "report": Path("acceptance/report.json"),
    }
    fields.update(overrides)
    run = AcceptanceRun(paths, AcceptanceRequest(**fields))  # type: ignore[arg-type]
    run.client = ScriptedClient(table)  # type: ignore[assignment]
    return run


def _json_answer(status: int, payload: object) -> Answer:
    return Answer(status, json.dumps(payload).encode("utf-8"), {})


@pytest.fixture
def root(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> RuntimePaths:
    monkeypatch.setenv("QWEN_HOME", str(tmp_path / "root"))
    paths = RuntimePaths.resolve(TREE)
    paths.lay_out()
    return paths


# ---------------------------------------------------------------------------
# The lane gateway: the session secret, the grants, the executor, and the image
# routes, answered in process so every branch of both lanes is device-free
# ---------------------------------------------------------------------------


MATRIX_MODEL = TEXT_MODELS[0]
IMAGE_BOUNDS: dict[str, object] = {
    "profile_id": "image-sd15",
    "width": 512,
    "height": 512,
    "max_dimension": 512,
    "max_steps": 4,
}
ARTIFACT_DIGEST = "d" * 64
PAGE_TEXT = "BEGIN UNTRUSTED\nSource: https://example.invalid/page\nthe page window"


def _outcome(
    state: str, *, kind: str = "fetched_page", usable: bool = True, text: str = "", status: str = ""
) -> dict[str, object]:
    """One `qwen.web-tool-outcome` record in the shape `tools/web.py` answers with."""
    return {
        "schema": "qwen.web-tool-outcome",
        "version": 1,
        "outcome": "success" if state == "complete" else "failure",
        "state": state,
        "status": status or ("success" if state == "complete" else "provider_content_error"),
        "evidence": {"kind": kind, "scope": "document_window", "usable": usable, "sources": []},
        "text": text,
    }


def _matrix(
    *,
    search_state: str = "available",
    image_state: str = "available_through_helper",
    bounds: Mapping[str, object] | None = IMAGE_BOUNDS,
) -> dict[str, object]:
    return {
        "schema": "qwen.tool-matrix",
        "version": 1,
        "selection": {"model": MATRIX_MODEL},
        "launch": {"approval_profile": "web-open", "image_profile": "image-sd15"},
        "tools": [
            {"tool_id": "web_search", "state": search_state, "helper": "searxng", "reason": "r"},
            {
                "tool_id": "image_generation",
                "state": image_state,
                "helper": "sd15",
                "reason": "the image worker's control socket is unbound",
                **({"bounds": dict(bounds)} if bounds is not None else {}),
            },
        ],
    }


class LaneGateway:
    """The routes both lanes travel, answered from declared behavior.

    The driver's own `Client` sits in front of this, so the session read, the
    `X-Qwen-Web-Session` header, and the one retry on a stale secret are the
    driver's code under test rather than the fixture's.
    """

    def __init__(self, **behavior: object) -> None:
        self.behavior = behavior
        # The per-launch approval secret this fixture signs for. It gates a
        # grant rather than a login, and the stale-secret branch rotates it.
        self.secret = "launch-secret"  # noqa: S105
        self.rotated = False
        self.issued: set[str] = set()
        self.image_grants = 0
        self.seen: list[tuple[str, str]] = []
        self.posted: list[Mapping[str, object]] = []

    # -- the gates -------------------------------------------------------

    def _session(self) -> Answer:
        return _json_answer(200, {"session_secret": self.secret})

    def _grant(self, path: str, headers: Mapping[str, str], fields: Mapping[str, object]) -> Answer:
        if self.behavior.get("stale_once") and not self.rotated:
            # A gateway restarted on the same port signs a new secret, so the
            # held one is stale rather than wrong.
            self.rotated = True
            self.secret = "the-secret-the-restart-signed"  # noqa: S105
            return _json_answer(
                403, {"error": "stale", "code": acceptance.STALE_SESSION_SECRET_CODE}
            )
        if headers.get(acceptance.SESSION_HEADER) != self.secret:
            return _json_answer(403, {"error": "no valid session header"})
        image = path == acceptance.IMAGE_GRANT_ROUTE
        if image:
            self.image_grants += 1
            refusal = self.behavior.get("image_grant_refusal")
            if isinstance(refusal, tuple) and self.image_grants >= int(refusal[0]):
                status, retry_after = int(refusal[1]), str(refusal[2])
                return Answer(
                    status,
                    json.dumps({"error": "one outstanding grant per client"}).encode("utf-8"),
                    {"retry-after": retry_after},
                )
        refused = self.behavior.get("grant_status")
        if not image and isinstance(refused, int):
            return _json_answer(refused, {"error": "the approval broker refused"})
        self.posted.append(dict(fields))
        token = f"grant-{len(self.issued)}"
        self.issued.add(token)
        return _json_answer(200, {"authorization": token})

    # -- the executor ----------------------------------------------------

    def _execute(self, payload: Mapping[str, object]) -> Answer:
        tool = str(payload.get("tool", ""))
        params = payload.get("params")
        params = params if isinstance(params, dict) else {}
        if tool == acceptance.SEARCH_TOOL:
            if str(params.get("authorization", "")) not in self.issued:
                return _json_answer(403, _outcome("incomplete", kind="none", usable=False))
            return _json_answer(200, self.behavior.get("search") or self._search_record())
        if tool == acceptance.READ_URL_TOOL:
            if int(params.get("start_index", 0) or 0) >= acceptance.EMPTY_WINDOW_START_INDEX:
                return _json_answer(
                    200,
                    self.behavior.get("probe")
                    or _outcome("incomplete", kind="none", usable=False, text="no text at index"),
                )
            return _json_answer(
                200, self.behavior.get("fetch") or _outcome("complete", text=PAGE_TEXT)
            )
        return _json_answer(400, _outcome("incomplete", kind="none", usable=False))

    def _search_record(self) -> dict[str, object]:
        rendered = (
            "Title: a page\nURL: https://example.invalid/page\n"
            "Result ID: signed-result-0\nTrust: untrusted-web-result\nHighlights:\n---"
        )
        return _outcome("complete", kind="search_snippets", text=rendered)

    # -- the image routes ------------------------------------------------

    def _image(self, path: str, payload: Mapping[str, object]) -> Answer:
        if path == "/api/tools/image/generate":
            if str(payload.get("authorization", "")) not in self.issued:
                return _json_answer(403, {"error": "the grant is unverified"})
            answer = self.behavior.get("generate")
            if isinstance(answer, Answer):
                return answer
            return _json_answer(200, {"sha256": ARTIFACT_DIGEST, "job_id": "job-1"})
        if path == "/api/tools/image/review":
            answer = self.behavior.get("review")
            if isinstance(answer, Answer):
                return answer
            return _json_answer(
                200,
                {
                    "completion": {"answered": True, "raw_reply": "{}"},
                    "schema_validity": {"valid": True},
                },
            )
        if path == "/api/tools/image/cancel":
            return _json_answer(200, {"status": "refused", "reason": "not_running"})
        if path == "/api/tools/image/remove":
            answer = self.behavior.get("remove")
            if isinstance(answer, Answer):
                return answer
            return _json_answer(200, {"removed": True, "png_sha256": ARTIFACT_DIGEST})
        return _json_answer(404, {"error": "no route"})

    # -- the dispatch ----------------------------------------------------

    def handle(
        self, method: str, path: str, body: bytes | None, headers: Mapping[str, str]
    ) -> Answer:
        self.seen.append((method, path))
        payload = json.loads(body.decode("utf-8")) if body else {}
        payload = payload if isinstance(payload, dict) else {}
        if method == "GET" and path == acceptance.SESSION_ROUTE:
            return self._session()
        if method == "GET" and path.startswith(acceptance.MATRIX_ROUTE):
            matrix = self.behavior.get("matrix")
            if isinstance(matrix, Answer):
                return matrix
            return _json_answer(200, matrix if isinstance(matrix, dict) else _matrix())
        if method == "POST" and path in (acceptance.GRANT_ROUTE, acceptance.IMAGE_GRANT_ROUTE):
            return self._grant(path, headers, payload)
        if method == "POST" and path == acceptance.TOOLS_ROUTE:
            return self._execute(payload)
        if method == "GET" and path == f"/api/artifacts/{ARTIFACT_DIGEST}.png":
            artifact = self.behavior.get("artifact")
            if isinstance(artifact, Answer):
                return artifact
            return Answer(200, acceptance.PNG_MAGIC + b"bytes", {})
        if method == "POST" and path.startswith("/api/tools/image/"):
            return self._image(path, payload)
        return _json_answer(404, {"error": "no route"})


class LaneClient(acceptance.Client):
    """The driver's own client over the lane gateway, so its grant flow is what runs."""

    def __init__(self, gateway: LaneGateway) -> None:
        super().__init__("http://127.0.0.1:1", 1.0)
        self.gateway = gateway

    def exchange(
        self,
        method: str,
        path: str,
        *,
        body: bytes | None = None,
        headers: Mapping[str, str] | None = None,
        authenticated: bool = True,
    ) -> Answer:
        del authenticated
        return self.gateway.handle(method, path, body, dict(headers or {}))


def _lane_run(paths: RuntimePaths, **behavior: object) -> tuple[AcceptanceRun, LaneGateway]:
    run = AcceptanceRun(
        paths,
        AcceptanceRequest(
            base="http://127.0.0.1:1",
            pairing_code="code",
            report=Path("acceptance/report.json"),
            text_models=TEXT_MODELS,
        ),
    )
    gateway = LaneGateway(**behavior)
    run.client = LaneClient(gateway)
    return run, gateway


# ---------------------------------------------------------------------------
# The web lane
# ---------------------------------------------------------------------------


def test_the_web_lane_searches_then_reads_the_page_it_named(root: RuntimePaths) -> None:
    run, gateway = _lane_run(root)
    run.check_web_lane()
    results = _by_name(run.results)
    assert results["web_search_then_fetch"].status == PASS, results["web_search_then_fetch"].reason
    assert results["web_retrieval_failure_explicit"].status == PASS
    assert results["web_retrieval_failure_explicit"].evidence["proved_by"] == "empty_window"
    # The grant travelled under the session secret the driver read first.
    assert (("GET", acceptance.SESSION_ROUTE)) in gateway.seen
    assert gateway.posted[0]["query"] == acceptance.WEB_QUERY
    assert gateway.posted[0]["profile_id"] == "web-open"


def test_a_stale_session_secret_is_read_again_and_the_grant_lands(root: RuntimePaths) -> None:
    run, gateway = _lane_run(root, stale_once=True)
    run.check_web_lane()
    results = _by_name(run.results)
    assert results["web_search_then_fetch"].status == PASS, results["web_search_then_fetch"].reason
    assert gateway.seen.count(("GET", acceptance.SESSION_ROUTE)) == 2


def test_a_refused_web_grant_skips_both_items(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, grant_status=403)
    run.check_web_lane()
    results = _by_name(run.results)
    for name in acceptance.AcceptanceRun.WEB_ITEMS:
        assert results[name].status == SKIPPED
        assert "single-use grant" in results[name].reason


def test_an_unavailable_search_backend_skips_naming_the_matrix_state(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, matrix=_matrix(search_state="temporarily_unavailable"))
    run.check_web_lane()
    results = _by_name(run.results)
    for name in acceptance.AcceptanceRun.WEB_ITEMS:
        assert results[name].status == SKIPPED
        assert "temporarily_unavailable" in results[name].reason


def test_a_search_that_answers_incomplete_proves_the_explicit_failure(root: RuntimePaths) -> None:
    unreachable = _outcome(
        "incomplete", kind="none", usable=False, text="the search instance refused the connection"
    )
    run, _gateway = _lane_run(root, search=unreachable)
    run.check_web_lane()
    results = _by_name(run.results)
    assert results["web_search_then_fetch"].status == SKIPPED
    assert "the search itself answered" in results["web_search_then_fetch"].reason
    explicit = results["web_retrieval_failure_explicit"]
    assert explicit.status == PASS
    assert explicit.evidence["proved_by"] == "search"


def test_a_fetch_that_carries_no_page_window_fails_the_grounded_item(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, fetch=_outcome("complete", kind="none", usable=False, text="x"))
    run.check_web_lane()
    assert _by_name(run.results)["web_search_then_fetch"].status == FAIL


def test_an_empty_window_reported_as_complete_fails_the_explicit_item(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, probe=_outcome("complete", text="a window"))
    run.check_web_lane()
    result = _by_name(run.results)["web_retrieval_failure_explicit"]
    assert result.status == FAIL
    assert "invisible" in result.reason


# ---------------------------------------------------------------------------
# The image lane
# ---------------------------------------------------------------------------


def test_the_image_lane_passes_behind_a_granted_token(root: RuntimePaths) -> None:
    run, gateway = _lane_run(root)
    run.check_image_lane()
    results = _by_name(run.results)
    for name in acceptance.AcceptanceRun.IMAGE_ITEMS:
        assert results[name].status == PASS, results[name].reason
    grant = gateway.posted[0]
    assert grant["context"] == acceptance.IMAGE_CLAIM_CONTEXT
    assert grant["image_profile"] == IMAGE_BOUNDS["profile_id"]
    assert grant["aspect"] == "1:1"
    assert grant["max_steps"] == acceptance.IMAGE_STEPS
    assert grant["prompt_hash"] == acceptance.prompt_digest(acceptance.IMAGE_PROMPT)


def test_an_unbound_image_socket_skips_the_whole_lane(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, matrix=_matrix(image_state="temporarily_unavailable"))
    run.check_image_lane()
    results = _by_name(run.results)
    for name in acceptance.AcceptanceRun.IMAGE_ITEMS:
        assert results[name].status == SKIPPED
        assert "control socket is unbound" in results[name].reason


def test_a_refused_image_grant_skips_the_whole_lane(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, image_grant_refusal=(1, 403, ""))
    run.check_image_lane()
    results = _by_name(run.results)
    for name in acceptance.AcceptanceRun.IMAGE_ITEMS:
        assert results[name].status == SKIPPED
        assert "single-use grant" in results[name].reason


def test_an_outstanding_grant_beyond_the_wait_skips_the_review_alone(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, image_grant_refusal=(2, 429, "900"))
    run.check_image_lane()
    results = _by_name(run.results)
    assert results["image_generate"].status == PASS
    review = results["image_review"]
    assert review.status == SKIPPED
    assert "one unexpired grant per client" in review.reason
    assert results["image_cancel"].status == PASS
    assert results["image_remove"].status == PASS


def test_an_outstanding_grant_inside_the_wait_is_retried(root: RuntimePaths) -> None:
    run, gateway = _lane_run(root, image_grant_refusal=(2, 429, "0"))

    def one_refusal(path: str, headers: Mapping[str, str], fields: Mapping[str, object]) -> Answer:
        if gateway.image_grants >= 2:
            gateway.behavior.pop("image_grant_refusal", None)
        return original(path, headers, fields)

    original = gateway._grant
    gateway._grant = one_refusal  # type: ignore[method-assign]
    run.check_image_lane()
    assert _by_name(run.results)["image_review"].status == PASS


def test_a_generation_the_worker_refused_fails_and_the_rest_follow(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(
        root, generate=_json_answer(502, {"error": "the image service failed the generation"})
    )
    run.check_image_lane()
    results = _by_name(run.results)
    assert results["image_generate"].status == FAIL
    assert "502" in results["image_generate"].reason
    assert results["artifact_read"].status == SKIPPED
    assert results["image_review"].status == SKIPPED
    assert results["image_remove"].status == SKIPPED


def test_an_artifact_that_opens_with_no_png_signature_fails(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, artifact=Answer(200, b"not a png", {}))
    run.check_image_lane()
    result = _by_name(run.results)["artifact_read"]
    assert result.status == FAIL
    assert "PNG signature" in result.reason


def test_a_review_the_router_refused_fails_the_review_alone(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, review=_json_answer(502, {"error": "the router refused"}))
    run.check_image_lane()
    results = _by_name(run.results)
    assert results["image_generate"].status == PASS
    assert results["image_review"].status == FAIL
    assert results["image_remove"].status == PASS


def test_an_absent_matrix_route_skips_both_lanes(root: RuntimePaths) -> None:
    run, _gateway = _lane_run(root, matrix=_json_answer(404, {"error": "no route"}))
    run.check_web_lane()
    run.check_image_lane()
    results = _by_name(run.results)
    for name in (*acceptance.AcceptanceRun.WEB_ITEMS, *acceptance.AcceptanceRun.IMAGE_ITEMS):
        assert results[name].status == SKIPPED
        assert acceptance.MATRIX_ROUTE in results[name].reason


def test_a_held_lease_after_the_stop_fails(root: RuntimePaths) -> None:
    lease = root["qwen_home_state"] / "vulkan-workload.lock"
    run = _scripted(root, {}, lease_path=lease)
    run.check_lease_free()
    assert _by_name(run.results)["vulkan_lease_free"].status == PASS

    lease.touch()
    with lease.open("r+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        held = _scripted(root, {}, lease_path=lease)
        held.check_lease_free()
        result = _by_name(held.results)["vulkan_lease_free"]
    assert result.status == FAIL
    assert "still held" in result.reason


def test_a_record_naming_a_live_child_reports_residue(root: RuntimePaths) -> None:
    record_path = root["qwen_home_state"] / "appliance.json"
    live = appliance.ChildRecord(
        name="router",
        pid=os.getpid(),
        pgid=os.getpgid(0),
        start_time=read_start_time(os.getpid()) or 0,
        argv0="python3",
    )
    appliance.ApplianceRecord(path=record_path).write(
        appliance.ApplianceState(state="stopped", children=(live,))
    )
    run = _scripted(root, {}, appliance_record=record_path)
    run.check_no_residue()
    result = _by_name(run.results)["teardown_leaves_no_residue"]
    assert result.status == FAIL
    assert "still carries its recorded identity" in result.reason


def test_a_record_with_no_children_reports_no_residue(root: RuntimePaths) -> None:
    record_path = root["qwen_home_state"] / "appliance.json"
    appliance.ApplianceRecord(path=record_path).write(
        appliance.ApplianceState(state="stopped", children=())
    )
    run = _scripted(root, {}, appliance_record=record_path)
    run.check_no_residue()
    assert _by_name(run.results)["teardown_leaves_no_residue"].status == PASS


def test_the_fixture_image_declares_its_own_tallest_bar() -> None:
    image = acceptance.fixture_image()
    assert image.startswith(b"\x89PNG\r\n\x1a\n")
    assert acceptance.fixture_image() == image
    tallest = max(acceptance.FIXTURE_BARS, key=lambda bar: bar[1])
    assert tallest[0] == acceptance.FIXTURE_TALLEST


def test_the_restart_item_passes_when_the_saved_one_alone_survives(root: RuntimePaths) -> None:
    saved = "b" * 32
    temporary = "c" * 32
    table = {
        ("POST", "/api/pair"): _json_answer(200, {"paired": True}),
        ("GET", "/api/health"): _json_answer(200, {"status": "ok"}),
        ("GET", f"/api/conversations/{saved}"): _json_answer(200, {"conversation_id": saved}),
        ("GET", f"/api/conversations/{temporary}"): _json_answer(404, {"error": "absent"}),
    }
    run = _scripted(root, table, restart_command=(sys.executable, "-c", "pass"))
    run.saved_conversation = saved
    run.temporary_conversation = temporary
    run.check_history_across_restart()
    assert _by_name(run.results)["history_survives_restart"].status == PASS


def test_a_temporary_conversation_that_survives_the_restart_fails(root: RuntimePaths) -> None:
    saved = "b" * 32
    temporary = "c" * 32
    table = {
        ("POST", "/api/pair"): _json_answer(200, {"paired": True}),
        ("GET", "/api/health"): _json_answer(200, {"status": "ok"}),
        ("GET", f"/api/conversations/{saved}"): _json_answer(200, {"conversation_id": saved}),
        ("GET", f"/api/conversations/{temporary}"): _json_answer(
            200, {"conversation_id": temporary}
        ),
    }
    run = _scripted(root, table, restart_command=(sys.executable, "-c", "pass"))
    run.saved_conversation = saved
    run.temporary_conversation = temporary
    run.check_history_across_restart()
    result = _by_name(run.results)["history_survives_restart"]
    assert result.status == FAIL
    assert "the temporary one ends" in result.reason


def test_the_restart_pairs_with_the_code_the_restarted_gateway_minted(
    root: RuntimePaths,
) -> None:
    """The code this run was given is dead; the live one comes from the state file."""
    saved = "b" * 32
    temporary = "c" * 32
    minted = "the-code-the-restart-minted"
    (root["qwen_home_state"] / PAIRING_CODE_FILENAME).write_text(f"{minted}\n", encoding="utf-8")
    table = {
        ("POST", "/api/pair"): _json_answer(200, {"paired": True}),
        ("GET", "/api/health"): _json_answer(200, {"status": "ok"}),
        ("GET", f"/api/conversations/{saved}"): _json_answer(200, {"conversation_id": saved}),
        ("GET", f"/api/conversations/{temporary}"): _json_answer(404, {"error": "absent"}),
    }
    run = _scripted(
        root, table, pairing_code="dead", restart_command=(sys.executable, "-c", "pass")
    )
    run.saved_conversation = saved
    run.temporary_conversation = temporary
    assert run._current_pairing_code() == minted
    run.check_history_across_restart()
    assert _by_name(run.results)["history_survives_restart"].status == PASS


def test_a_refused_re_pair_after_the_restart_names_itself(root: RuntimePaths) -> None:
    table = {
        ("POST", "/api/pair"): _json_answer(401, {"error": "the code is dead"}),
        ("GET", "/api/health"): _json_answer(200, {"status": "ok"}),
    }
    run = _scripted(root, table, restart_command=(sys.executable, "-c", "pass"))
    run.saved_conversation = "b" * 32
    run.check_history_across_restart()
    result = _by_name(run.results)["history_survives_restart"]
    assert result.status == FAIL
    assert "pairing with the restarted gateway answered 401" in result.reason


def test_a_restart_command_that_exits_non_zero_fails(root: RuntimePaths) -> None:
    run = _scripted(root, {}, restart_command=(sys.executable, "-c", "raise SystemExit(3)"))
    run.saved_conversation = "b" * 32
    run.check_history_across_restart()
    result = _by_name(run.results)["history_survives_restart"]
    assert result.status == FAIL
    assert "exited 3" in result.reason


def test_the_teardown_phase_runs_the_stop_argv_and_then_reads_absence(
    root: RuntimePaths,
) -> None:
    record_path = root["qwen_home_state"] / "appliance.json"
    appliance.ApplianceRecord(path=record_path).write(
        appliance.ApplianceState(state="stopped", children=())
    )
    run = _scripted(
        root,
        {},
        stop_command=(sys.executable, "-c", "pass"),
        lease_path=root["qwen_home_state"] / "vulkan-workload.lock",
        appliance_record=record_path,
    )
    run.run_teardown()
    results = _by_name(run.results)
    assert results["stop_command"].status == PASS
    assert results["vulkan_lease_free"].status == PASS
    assert results["teardown_leaves_no_residue"].status == PASS


def test_an_origin_that_answers_nothing_reports_one_failure(
    root: RuntimePaths, tmp_path: Path
) -> None:
    """A refused connection is one named failure and a skip per live item.

    A driver that let the first `ConnectionRefusedError` leave the process would
    write no report at all, which is the one outcome an acceptance run cannot
    have.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        closed = int(probe.getsockname()[1])
    request = AcceptanceRequest(
        base=f"http://127.0.0.1:{closed}",
        pairing_code="code",
        report=Path("unreachable/report.json"),
    )
    assert acceptance.run(root, request) == 1
    document = json.loads(
        (root["qwen_home_results"] / "unreachable" / "report.json").read_text(encoding="utf-8")
    )
    results = {entry["name"]: entry for entry in document["checks"]}
    assert results["origin_reachable"]["status"] == FAIL
    assert "answered nothing" in results["origin_reachable"]["reason"]
    assert results["pairing"]["status"] == SKIPPED
    assert results["roster_join"]["status"] == SKIPPED
    assert document["counts"][FAIL] == 1


def test_a_transport_failure_mid_run_fails_that_item_alone(root: RuntimePaths) -> None:
    def refuse() -> None:
        raise ConnectionResetError("the peer reset the connection")

    run = _scripted(root, {})
    run.guarded("calculator", refuse)
    result = _by_name(run.results)["calculator"]
    assert result.status == FAIL
    assert "the exchange refused" in result.reason
