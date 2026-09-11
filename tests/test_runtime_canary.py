"""The parity canary over fake launch commands and a fake llama-server.

The server is a real listener in this process, so the configuration snapshot
resolves a real pid from a real socket inode through `/proc/<pid>/fd` rather
than from a stub, and the argv, affinity, and niceness it records are this
interpreter's own. The launch and teardown argv are `sys.executable -c`
one-liners that flip a marker file, so an arm's start and stop are observable
without a device: `RESPONSE` decides what the fake server answers, and a test
sets it per arm to produce a held verdict, a regression, and each refusal.

The sysfs reads come from files this test writes, which is what keeps the whole
window device-free: the canary reads only the paths a caller names, so a DPM
ladder with one marked level and a KSM file are ordinary text here.
"""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import threading
from collections.abc import Iterator
from http.server import BaseHTTPRequestHandler, HTTPServer, ThreadingHTTPServer
from pathlib import Path

import pytest

from qwen_apu.runtime import canary
from qwen_apu.runtime.canary import (
    ArmCommands,
    ArmResult,
    CanaryRequest,
    Configuration,
    Endpoint,
)
from qwen_apu.runtime.paths import RuntimePaths

TREE = Path(__file__).resolve().parents[1]
EXCHANGE_DEADLINE_SECONDS = 20.0

# One entry per arm launch, consumed in order; each is the timings block the
# fake server answers with, or None for a completion that carries none.
RESPONSE: dict[str, object] = {"queue": [], "healthy": True}


class _FakeServer(BaseHTTPRequestHandler):
    """`/health` and `/v1/chat/completions`, answering from `RESPONSE`."""

    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: object) -> None:
        """Keep the fixture's request lines out of the test output."""

    def do_GET(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        if self.path != "/health":
            self._json({"error": "no such endpoint"}, status=404)
            return
        healthy = bool(RESPONSE["healthy"])
        self._json({"status": "ok" if healthy else "loading"}, status=200 if healthy else 503)

    def do_POST(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)
        if self.path != "/v1/chat/completions":
            self._json({"error": "no such endpoint"}, status=404)
            return
        queue = RESPONSE["queue"]
        timings = queue.pop(0) if isinstance(queue, list) and queue else None
        answer: dict[str, object] = {
            "id": "chatcmpl-canary",
            "choices": [{"index": 0, "message": {"content": "ready"}}],
        }
        if timings is not None:
            answer["timings"] = timings
        self._json(answer)

    def _json(self, payload: object, status: int = 200) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


@pytest.fixture(scope="module")
def server() -> Iterator[ThreadingHTTPServer]:
    running = ThreadingHTTPServer(("127.0.0.1", 0), _FakeServer)
    running.daemon_threads = True
    thread = threading.Thread(target=running.serve_forever, kwargs={"poll_interval": 0.05})
    thread.start()
    try:
        yield running
    finally:
        running.shutdown()
        running.server_close()
        thread.join(timeout=EXCHANGE_DEADLINE_SECONDS)


@pytest.fixture(autouse=True)
def _response() -> Iterator[None]:
    RESPONSE["queue"] = []
    RESPONSE["healthy"] = True
    yield
    RESPONSE["queue"] = []
    RESPONSE["healthy"] = True


@pytest.fixture
def paths(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> RuntimePaths:
    monkeypatch.setenv("QWEN_HOME", str(tmp_path / "root"))
    resolved = RuntimePaths.resolve(TREE)
    resolved.lay_out()
    return resolved


def _marker_commands(marker: Path, arm: str) -> ArmCommands:
    """A start and a stop that each append one line to a marker file."""
    program = "import pathlib,sys;pathlib.Path(sys.argv[1]).open('a').write(sys.argv[2] + '\\n')"
    return ArmCommands(
        start=(sys.executable, "-c", program, str(marker), f"{arm}-start"),
        stop=(sys.executable, "-c", program, str(marker), f"{arm}-stop"),
    )


def _timings(decode: float, prefill: float) -> dict[str, float]:
    return {"predicted_per_second": decode, "prompt_per_second": prefill}


def _request(server: ThreadingHTTPServer, tmp_path: Path, **overrides: object) -> CanaryRequest:
    marker = tmp_path / "arms.txt"
    fields: dict[str, object] = {
        "report": Path("canary/report.json"),
        "legacy": _marker_commands(marker, "legacy"),
        "python": _marker_commands(marker, "python"),
        "repeats": 2,
        "base": f"http://127.0.0.1:{server.server_address[1]}",
        "tokens": 8,
    }
    fields.update(overrides)
    return CanaryRequest(**fields)  # type: ignore[arg-type]


# ---------------------------------------------------------------------------
# The configuration snapshot
# ---------------------------------------------------------------------------


def test_the_snapshot_reads_the_listening_process(server: ThreadingHTTPServer) -> None:
    port = int(server.server_address[1])
    assert canary.listener_pid(port) == os.getpid()
    configuration = canary.snapshot(port, {})
    assert configuration.pid == os.getpid()
    assert configuration.argv == canary.read_argv(os.getpid())
    assert configuration.cpu_affinity == tuple(sorted(os.sched_getaffinity(os.getpid())))
    assert configuration.niceness == os.nice(0)


def test_a_port_nothing_listens_on_names_its_own_absence(tmp_path: Path) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        free = int(probe.getsockname()[1])
    configuration = canary.snapshot(free, {})
    assert configuration.pid == 0
    assert "no process holds the listening socket" in configuration.reason


def test_a_dpm_ladder_reports_the_marked_level(tmp_path: Path) -> None:
    ladder = tmp_path / "pp_dpm_sclk"
    ladder.write_text("0: 200Mhz\n1: 400Mhz\n2: 1100Mhz *\n", encoding="utf-8")
    ksm = tmp_path / "run"
    ksm.write_text("1\n", encoding="utf-8")
    values = canary.read_sysfs({"sclk": ladder, "ksm": ksm, "thermal": tmp_path / "absent"})
    assert values["sclk"] == "2: 1100Mhz *"
    assert values["ksm"] == "1"
    assert values["thermal"].startswith("unreadable")


def test_a_sysfs_argument_without_a_path_refuses() -> None:
    assert canary.sysfs_from_request(["sclk=/x"]) == {"sclk": Path("/x")}
    with pytest.raises(canary.CanaryRefused, match="NAME=PATH"):
        canary.sysfs_from_request(["sclk"])


# ---------------------------------------------------------------------------
# The window
# ---------------------------------------------------------------------------


def test_an_abab_window_holds_when_both_metrics_stay_inside_the_ratio(
    paths: RuntimePaths, server: ThreadingHTTPServer, tmp_path: Path
) -> None:
    RESPONSE["queue"] = [
        _timings(9.40, 21.0),
        _timings(9.20, 20.6),
        _timings(9.50, 21.2),
        _timings(9.30, 20.8),
    ]
    request = _request(server, tmp_path)
    assert canary.run(paths, request) == 0

    destination = paths["qwen_home_results"] / "canary" / "report.json"
    document = json.loads(destination.read_text(encoding="utf-8"))
    assert document["verdict"] == canary.VERDICT_HELD
    assert document["order"] == ["legacy", "python", "legacy", "python"]
    assert document["declared_ratio"] == canary.DEFAULT_RATIO
    assert document["single_arm_band"] == canary.SINGLE_ARM_BAND
    assert "queue position" in document["rule"]
    rows = {row["metric"]: row for row in document["metrics"]}
    assert rows["predicted_per_second"]["legacy_values"] == [9.40, 9.50]
    assert rows["predicted_per_second"]["python_values"] == [9.20, 9.30]
    assert rows["predicted_per_second"]["verdict"] == canary.VERDICT_HELD

    markdown = destination.with_suffix(".md").read_text(encoding="utf-8")
    assert "# Parity canary" in markdown
    assert "predicted_per_second" in markdown

    # Each arm ran its own start and its own stop, in ABAB order.
    marker = (tmp_path / "arms.txt").read_text(encoding="utf-8").split()
    assert marker == [
        "legacy-start",
        "legacy-stop",
        "python-start",
        "python-stop",
        "legacy-start",
        "legacy-stop",
        "python-start",
        "python-stop",
    ]


def test_a_python_arm_below_the_ratio_reports_a_regression(
    paths: RuntimePaths, server: ThreadingHTTPServer, tmp_path: Path
) -> None:
    RESPONSE["queue"] = [
        _timings(9.40, 21.0),
        _timings(7.00, 20.8),
        _timings(9.40, 21.0),
        _timings(7.10, 20.9),
    ]
    assert canary.run(paths, _request(server, tmp_path)) == 1
    document = json.loads(
        (paths["qwen_home_results"] / "canary" / "report.json").read_text(encoding="utf-8")
    )
    assert document["verdict"] == canary.VERDICT_REGRESSION
    assert "predicted_per_second" in document["reason"]
    rows = {row["metric"]: row for row in document["metrics"]}
    assert rows["prompt_per_second"]["verdict"] == canary.VERDICT_HELD


def test_a_single_alternation_refuses_the_verdict(
    paths: RuntimePaths, server: ThreadingHTTPServer, tmp_path: Path
) -> None:
    RESPONSE["queue"] = [_timings(9.4, 21.0), _timings(9.3, 20.9)]
    assert canary.run(paths, _request(server, tmp_path, repeats=1)) == 1
    document = json.loads(
        (paths["qwen_home_results"] / "canary" / "report.json").read_text(encoding="utf-8")
    )
    assert document["verdict"] == canary.VERDICT_REFUSED
    assert "queue position" in document["reason"]


def test_a_completion_carrying_no_timings_refuses(
    paths: RuntimePaths, server: ThreadingHTTPServer, tmp_path: Path
) -> None:
    RESPONSE["queue"] = [None, None, None, None]
    assert canary.run(paths, _request(server, tmp_path)) == 1
    document = json.loads(
        (paths["qwen_home_results"] / "canary" / "report.json").read_text(encoding="utf-8")
    )
    assert document["verdict"] == canary.VERDICT_REFUSED
    assert "no timings block" in document["reason"]


def test_a_server_that_never_reports_ready_refuses(
    paths: RuntimePaths, server: ThreadingHTTPServer, tmp_path: Path
) -> None:
    RESPONSE["healthy"] = False
    request = _request(server, tmp_path, readiness_deadline_s=0.6)
    assert canary.run(paths, request) == 1
    document = json.loads(
        (paths["qwen_home_results"] / "canary" / "report.json").read_text(encoding="utf-8")
    )
    assert document["verdict"] == canary.VERDICT_REFUSED
    assert "did not report ready" in document["reason"]


def test_an_arm_naming_no_argv_refuses(
    paths: RuntimePaths, server: ThreadingHTTPServer, tmp_path: Path
) -> None:
    RESPONSE["queue"] = [_timings(9.4, 21.0), _timings(9.3, 20.9)]
    request = _request(server, tmp_path, python=ArmCommands())
    assert canary.run(paths, request) == 1
    document = json.loads(
        (paths["qwen_home_results"] / "canary" / "report.json").read_text(encoding="utf-8")
    )
    assert document["verdict"] == canary.VERDICT_REFUSED
    assert "names no start and stop argv" in document["reason"]


def test_a_launch_that_exits_non_zero_refuses(
    paths: RuntimePaths, server: ThreadingHTTPServer, tmp_path: Path
) -> None:
    RESPONSE["queue"] = [_timings(9.4, 21.0)]
    failing = ArmCommands(
        start=(sys.executable, "-c", "raise SystemExit(4)"),
        stop=(sys.executable, "-c", "pass"),
    )
    assert canary.run(paths, _request(server, tmp_path, python=failing)) == 1
    document = json.loads(
        (paths["qwen_home_results"] / "canary" / "report.json").read_text(encoding="utf-8")
    )
    assert document["verdict"] == canary.VERDICT_REFUSED
    assert "exited 4" in document["reason"]


# ---------------------------------------------------------------------------
# The configuration refusal
# ---------------------------------------------------------------------------


def _measured(arm: str, ordinal: int, **overrides: object) -> ArmResult:
    fields: dict[str, object] = {
        "argv": ("llama-server", "--port", "8080"),
        "cpu_affinity": (0,),
        "niceness": 19,
        "sysfs": {"sclk": "2: 1100Mhz *", "mclk": "2: 1067Mhz *"},
        "pid": 4242,
    }
    fields.update(overrides)
    return ArmResult(
        arm=arm,
        ordinal=ordinal,
        configuration=Configuration(**fields),  # type: ignore[arg-type]
        timings=_timings(9.4, 21.0),
    )


def test_one_differing_configuration_field_refuses_the_verdict(paths: RuntimePaths) -> None:
    results = [
        _measured("legacy", 1),
        _measured("python", 1, sysfs={"sclk": "1: 400Mhz *", "mclk": "2: 1067Mhz *"}),
        _measured("legacy", 2),
        _measured("python", 2),
    ]
    overall, reason, rows = canary.verdict(
        CanaryRequest(report=Path("canary/report.json"), repeats=2), results
    )
    assert overall == canary.VERDICT_REFUSED
    assert "sysfs.sclk" in reason
    assert "400Mhz" in reason and "1100Mhz" in reason
    assert rows == []


def test_equal_configurations_compute_the_verdict(paths: RuntimePaths) -> None:
    results = [
        _measured("legacy", 1),
        _measured("python", 1),
        _measured("legacy", 2),
        _measured("python", 2),
    ]
    overall, reason, rows = canary.verdict(
        CanaryRequest(report=Path("canary/report.json"), repeats=2), results
    )
    assert overall == canary.VERDICT_HELD, reason
    assert len(rows) == len(canary.METRICS)


def test_a_differing_argv_refuses_by_name(paths: RuntimePaths) -> None:
    results = [
        _measured("legacy", 1),
        _measured("python", 1, argv=("llama-server", "--ctx-size", "16384")),
        _measured("legacy", 2),
        _measured("python", 2),
    ]
    overall, reason, _rows = canary.verdict(
        CanaryRequest(report=Path("canary/report.json"), repeats=2), results
    )
    assert overall == canary.VERDICT_REFUSED
    assert "argv" in reason


# ---------------------------------------------------------------------------
# Destinations and arguments
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("suffix", ("elsewhere", ""))
def test_a_report_outside_the_runtime_root_refuses(
    paths: RuntimePaths, tmp_path: Path, suffix: str
) -> None:
    """A sibling that prefixes the root's spelling is outside it all the same."""
    parent = tmp_path / suffix if suffix else Path(str(paths.root) + "-scratch")
    outside = parent / "canary.json"
    with pytest.raises(canary.CanaryRefused, match="runtime root alone"):
        canary.run(paths, CanaryRequest(report=outside))
    assert not outside.exists()
    assert not parent.exists()


def test_zero_alternations_refuse_before_a_launch(paths: RuntimePaths) -> None:
    with pytest.raises(canary.CanaryRefused, match="at least one alternation"):
        canary.run(paths, CanaryRequest(report=Path("canary/report.json"), repeats=0))


def test_a_base_that_names_no_http_origin_refuses() -> None:
    with pytest.raises(canary.CanaryRefused, match="http origin"):
        Endpoint.parse("unix:///var/run/llama.sock")


def test_two_preset_paths_with_equal_bytes_compare_equal(tmp_path: Path) -> None:
    """The legacy snapshot path and the bundle path name the same bytes."""
    first = tmp_path / "snapshot.ini"
    second = tmp_path / "bundle" / "router-presets.ini"
    second.parent.mkdir()
    first.write_text("[a]\nmodel = x\n", encoding="utf-8")
    second.write_bytes(first.read_bytes())
    common = ("llama-server", "--port", "8080")
    legacy = canary.Configuration(
        argv=(*common, "--models-preset", str(first)),
        preset_sha256=canary.preset_digest((*common, "--models-preset", str(first))),
    )
    python = canary.Configuration(
        argv=(*common, "--models-preset", str(second)),
        preset_sha256=canary.preset_digest((*common, "--models-preset", str(second))),
    )
    assert legacy.comparable() == python.comparable()
    assert legacy.comparable()["argv"][-1].startswith("sha256:")

    second.write_text("[a]\nmodel = y\n", encoding="utf-8")
    changed = canary.Configuration(
        argv=python.argv, preset_sha256=canary.preset_digest(python.argv)
    )
    assert legacy.comparable() != changed.comparable()


def test_an_unreadable_preset_leaves_the_path_word_in_place(tmp_path: Path) -> None:
    argv = ("llama-server", "--models-preset", str(tmp_path / "absent.ini"))
    assert canary.preset_digest(argv) == ""
    assert canary.Configuration(argv=argv).comparable()["argv"] == list(argv)


def test_transport_words_leave_the_comparison_and_enter_the_record() -> None:
    legacy = canary.Configuration(
        argv=(
            "llama-server",
            "--host",
            "10.0.0.170",
            "--port",
            "42069",
            "--api-key-file",
            "/k",
            "--cors-origins",
            "http://a",
            "--ctx-size",
            "24576",
        )
    )
    python = canary.Configuration(
        argv=("llama-server", "--host", "127.0.0.1", "--port", "8080", "--ctx-size", "24576")
    )
    assert legacy.comparable() == python.comparable()
    assert legacy.comparable()["argv"] == ["llama-server", "--ctx-size", "24576"]
    assert legacy.to_json()["transport"] == {
        "--host": "10.0.0.170",
        "--port": "42069",
        "--api-key-file": "/k",
        "--cors-origins": "http://a",
    }
    changed = canary.Configuration(argv=(*python.argv[:-1], "16384"))
    assert legacy.comparable() != changed.comparable()


def test_an_endpoint_sends_the_bearer_it_read(tmp_path: Path) -> None:
    seen: list[str] = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            seen.append(self.headers.get("Authorization", ""))
            body = b'{"status":"ok"}'
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args: object) -> None:
            pass

    server = HTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        key = tmp_path / "api.key"
        key.write_text("secret-token\n", encoding="utf-8")
        endpoint = canary.Endpoint.parse(f"http://127.0.0.1:{server.server_port}", key)
        status, _ = endpoint.get("/health", timeout_s=5.0)
        assert status == 200
        assert seen == ["Bearer secret-token"]
        bare = canary.Endpoint.parse(f"http://127.0.0.1:{server.server_port}")
        bare.get("/health", timeout_s=5.0)
        assert seen[-1] == ""
    finally:
        server.shutdown()
        server.server_close()
    with pytest.raises(canary.CanaryRefused):
        canary.Endpoint.parse("http://127.0.0.1:1", tmp_path / "absent")


def test_a_foreground_launch_is_left_to_the_stop(tmp_path: Path) -> None:
    """A start that holds the foreground while its server answers is admitted."""
    server = HTTPServer(("127.0.0.1", 0), _OkHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        endpoint = canary.Endpoint.parse(f"http://127.0.0.1:{server.server_port}")
        launch = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(600)"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        assert canary.wait_ready_or_exit(endpoint, 10.0, launch) == ""
        assert launch.poll() is None
        canary.LAUNCH_EXIT_GRACE_SECONDS = 0.2
        canary._end_launch(launch)
        assert launch.poll() is not None
        failing = subprocess.Popen(
            [sys.executable, "-c", "import sys; sys.stderr.write('refused'); sys.exit(3)"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        failing.wait(timeout=10)
        assert "the launch exited 3: refused" == canary.wait_ready_or_exit(
            canary.Endpoint.parse("http://127.0.0.1:1"), 5.0, failing
        )
    finally:
        server.shutdown()
        server.server_close()


class _OkHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        body = b'{"status":"ok"}'
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args: object) -> None:
        pass


def test_listener_pid_finds_a_listener_on_any_local_address() -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(("0.0.0.0", 0))  # noqa: S104 -- the read under test admits any local address
        listener.listen(1)
        assert canary.listener_pid(listener.getsockname()[1]) == os.getpid()
