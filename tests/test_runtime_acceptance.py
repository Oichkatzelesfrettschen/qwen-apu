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


@pytest.fixture(scope="module")
def upstream() -> Iterator[ThreadingHTTPServer]:
    server = ThreadingHTTPServer(("127.0.0.1", 0), _AcceptanceUpstream)
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
    assert results["browser_history_import"].status == PASS
    assert results["conversation_open"].status == PASS

    # The web lane has no route on this branch, so both items skip and name it.
    assert results["web_search_then_fetch"].status == SKIPPED
    assert "/api/tools/web/search" in results["web_search_then_fetch"].reason
    # The image lane is mounted and the driver holds no approved grant.
    assert results["image_generate"].status == SKIPPED
    assert "grant" in results["image_generate"].reason
    # No stop argv, so the two absence items name the argument they need.
    assert results["vulkan_lease_free"].status == SKIPPED
    assert results["teardown_leaves_no_residue"].status == SKIPPED


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


def test_a_report_outside_the_runtime_root_refuses(gateway: Fixture, tmp_path: Path) -> None:
    outside = tmp_path / "elsewhere" / "report.json"
    with pytest.raises(acceptance.AcceptanceRefused, match="runtime root alone"):
        acceptance.run(gateway.paths, _request(gateway, report=outside))
    assert not outside.exists()


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


def test_the_image_lane_passes_behind_a_granted_token(root: RuntimePaths) -> None:
    digest = "a" * 64
    table = {
        ("POST", "/api/tools/grant-image"): _json_answer(200, {"token": "granted"}),
        ("POST", "/api/tools/image/generate"): _json_answer(201, {"artifact": {"sha256": digest}}),
        ("GET", f"/api/artifacts/{digest}.png"): Answer(200, b"\x89PNG", {}),
        ("POST", "/api/tools/image/review"): _json_answer(200, {"judgment": "matches"}),
        ("POST", "/api/tools/image/cancel"): _json_answer(200, {"cancelled": True}),
        ("POST", "/api/tools/image/remove"): _json_answer(200, {"removed": True}),
    }
    run = _scripted(root, table)
    run.check_image_lane()
    results = _by_name(run.results)
    for name in ("image_generate", "artifact_read", "image_review", "image_cancel", "image_remove"):
        assert results[name].status == PASS, results[name].reason


def test_an_absent_image_route_skips_the_whole_lane(root: RuntimePaths) -> None:
    run = _scripted(root, {})
    run.check_image_lane()
    results = _by_name(run.results)
    assert results["image_generate"].status == SKIPPED
    assert "404" in results["image_generate"].reason or "answers 404" in (
        results["image_generate"].reason
    )


def test_the_web_lane_passes_when_both_routes_answer(root: RuntimePaths) -> None:
    table = {
        ("POST", "/api/tools/web/search"): _json_answer(200, {"results": [{"url": "x"}]}),
        ("POST", "/api/tools/web/fetch"): _json_answer(502, {"error": "unreachable"}),
    }
    run = _scripted(root, table)
    run.check_web_lane()
    results = _by_name(run.results)
    assert results["web_search_then_fetch"].status == PASS
    assert results["web_retrieval_failure_explicit"].status == PASS


def test_a_failed_retrieval_reported_as_success_fails(root: RuntimePaths) -> None:
    table = {
        ("POST", "/api/tools/web/search"): _json_answer(200, {"results": []}),
        ("POST", "/api/tools/web/fetch"): _json_answer(200, {"text": ""}),
    }
    run = _scripted(root, table)
    run.check_web_lane()
    results = _by_name(run.results)
    assert results["web_retrieval_failure_explicit"].status == FAIL
    assert "invisible" in results["web_retrieval_failure_explicit"].reason


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
