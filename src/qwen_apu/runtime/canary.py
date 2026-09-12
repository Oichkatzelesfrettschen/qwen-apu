"""The parity canary: the legacy launch and the Python launch on one window.

The cutover question is whether the Python control plane serves the same rates
the shell launch chain serves, and `docs/doctrine/hardware-and-measurement.md`
states what makes that question answerable. One checkpoint under identical flags
spans 30.6% across sweeps and 4% on a repeated depth-0 rate, so a difference
below about 20% quoted from single arms reports queue position rather than a
change in the software. Alternation is what buys the smaller margin: the arms
run ABAB inside one window against one machine state, so the comparison is
within a sweep rather than between two.

Three properties make the verdict answerable rather than merely computed.

The configuration is measured, not assumed. Each arm's server is located by the
process holding the listening socket, and its argv, CPU affinity, and niceness
are read from `/proc`; the delivered clocks, the KSM state, and the thermal
reading come from the sysfs files the caller names, so nothing here walks a
device tree of its own. Any field that differs between two arms refuses the
verdict and names the field with both values, because two arms measured under
two machine states are two sweeps.

The rule is pre-registered. `--ratio` declares, before the first launch, how
close the Python arm must sit to the legacy arm on the same window; the default
0.90 is a 10% margin, which sits inside the 20% band a single-arm comparison
would report, and the ABAB alternation is exactly what admits it. The report
states both numbers beside each other rather than quoting the tighter one alone.

Each arm's start argv returns once its server is up and its stop argv proves the
absence: `remote/qwen-lan-launch.sh lan-authenticated low-async` waits on
`/health` and prints the reachable addresses before returning, and
`remote/qwen-teardown.sh` exits non-zero on residue, which is the shape
`qwen-apu serve --daemon` and `qwen-apu stop` already carry on the other side.
The canary waits on `/health` itself after the start, so a start that returns
early costs a wait rather than a wrong reading, and it runs the stop whatever
the measurement did, because an arm left running holds the one Vulkan device the
next arm needs. `remote/run-device-window.sh` is the operator's outer wrapper
that tears the appliance down and relaunches it around a whole window; the
canary runs inside such a window rather than invoking it.

The evidence travels whole. Every arm's `predicted_per_second` and
`prompt_per_second` are recorded individually with the order they ran in and the
spread they showed, so a reader recomputes the verdict from the rows rather than
taking it.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import statistics
import subprocess
import time
from collections.abc import Mapping, Sequence
from dataclasses import asdict, dataclass, field
from http.client import HTTPConnection
from pathlib import Path
from urllib.parse import urlsplit

from qwen_apu.runtime.health import ListenerAbsent, _listening_inodes, _socket_inodes
from qwen_apu.runtime.paths import RuntimePaths

LEGACY_ARM = "legacy"
PYTHON_ARM = "python"

DEFAULT_REPEATS = 2
DEFAULT_RATIO = 0.90
DEFAULT_BASE = "http://127.0.0.1:8080"
DEFAULT_PROMPT = "Reply with the single word: ready."
DEFAULT_TOKENS = 64
DEFAULT_READINESS_DEADLINE_SECONDS = 240.0
READINESS_POLL_SECONDS = 0.5
EXCHANGE_DEADLINE_SECONDS = 600.0

METRICS: tuple[str, ...] = ("predicted_per_second", "prompt_per_second")

# The band a single-arm comparison reports inside, carried into the report
# beside the declared ratio so a reader sees the rule and its own limit at once.
SINGLE_ARM_BAND = 0.20

VERDICT_HELD = "held"
VERDICT_REGRESSION = "regression"
VERDICT_REFUSED = "refused"


class CanaryRefused(RuntimeError):
    """An argument or a destination the canary refuses before a launch."""


@dataclass(frozen=True)
class ArmCommands:
    """One arm's launch and teardown, each an argv list that reaches no shell."""

    start: tuple[str, ...] = ()
    stop: tuple[str, ...] = ()
    # The origin this arm listens on and the bearer its routes require; an
    # empty base falls to the request's base, and an absent bearer sends no
    # Authorization header. The production LAN launch serves its address with
    # a bearer while the Python serve stays on the loopback, and the two are
    # still one server argv apart from the transport words.
    base: str = ""
    bearer_file: Path | None = None


@dataclass(frozen=True)
class CanaryRequest:
    """One canary window, declared whole before the first launch."""

    report: Path
    legacy: ArmCommands = field(default_factory=ArmCommands)
    python: ArmCommands = field(default_factory=ArmCommands)
    repeats: int = DEFAULT_REPEATS
    ratio: float = DEFAULT_RATIO
    base: str = DEFAULT_BASE
    prompt: str = DEFAULT_PROMPT
    tokens: int = DEFAULT_TOKENS
    model: str = ""
    # name -> sysfs file. Nothing here discovers a path: the delivered clocks,
    # the KSM state, and the thermal reading are named by the caller, so the
    # canary reads a declared set and records exactly what it read.
    sysfs: Mapping[str, Path] = field(default_factory=dict)
    readiness_deadline_s: float = DEFAULT_READINESS_DEADLINE_SECONDS


@dataclass(frozen=True, slots=True)
class Configuration:
    """The machine state one arm ran under, read rather than assumed."""

    argv: tuple[str, ...] = ()
    cpu_affinity: tuple[int, ...] = ()
    niceness: int | None = None
    sysfs: Mapping[str, str] = field(default_factory=dict)
    pid: int = 0
    reason: str = ""
    preset_sha256: str = ""
    executable_sha256: str = ""

    def to_json(self) -> dict[str, object]:
        return {
            "argv": list(self.argv),
            "cpu_affinity": list(self.cpu_affinity),
            "niceness": self.niceness,
            "sysfs": dict(self.sysfs),
            "pid": self.pid,
            "reason": self.reason,
            "preset_sha256": self.preset_sha256,
            "executable_sha256": self.executable_sha256,
            "transport": self.transport(),
        }

    def comparable_argv(self) -> list[str]:
        """The policy argv: the preset word by content digest, transport words out.

        The legacy launch snapshots the merged router preset to a per-launch
        path and the Python launch names the bundle's own file, so the two
        argvs differ by that one word while the bytes the server reads are
        equal; the digest is what the arms must agree on. The listening host
        and port, the bearer file, and the CORS origins name where the server
        answers rather than how it decodes, so they are recorded under
        `transport` and left out of the comparison.
        """
        words: list[str] = []
        skip = False
        for index, word in enumerate(self.argv):
            if skip:
                skip = False
                continue
            if index == 0 and self.executable_sha256:
                words.append(f"sha256:{self.executable_sha256}")
                continue
            if word in PRESENTATION_FLAGS:
                continue
            if word in TRANSPORT_FLAGS and index + 1 < len(self.argv):
                skip = True
                continue
            if word == PRESET_FLAG and self.preset_sha256 and index + 1 < len(self.argv):
                words.append(word)
                words.append(f"sha256:{self.preset_sha256}")
                skip = True
                continue
            words.append(word)
        return words

    def transport(self) -> dict[str, str]:
        """The transport words the comparison leaves out, for the record."""
        pairs: dict[str, str] = {}
        for index, word in enumerate(self.argv[:-1]):
            if word in TRANSPORT_FLAGS:
                pairs[word] = self.argv[index + 1]
        return pairs

    def comparable(self) -> dict[str, object]:
        """The fields two arms must agree on, with the pid left out.

        A pid differs between two launches by construction, so comparing it
        would refuse every verdict; what has to hold equal is the argv the
        server runs under, the cores and niceness it runs at, and the machine
        state the named sysfs files report.
        """
        return {
            "argv": self.comparable_argv(),
            "cpu_affinity": list(self.cpu_affinity),
            "niceness": self.niceness,
            **{
                f"sysfs.{name}": comparable_sysfs_value(value)
                for name, value in sorted(self.sysfs.items())
            },
        }


@dataclass(frozen=True, slots=True)
class ArmResult:
    """One launch, one prompt, and what the server reported for it."""

    arm: str
    ordinal: int
    configuration: Configuration
    timings: Mapping[str, float] = field(default_factory=dict)
    failure: str = ""

    def to_json(self) -> dict[str, object]:
        return {
            "arm": self.arm,
            "ordinal": self.ordinal,
            "configuration": self.configuration.to_json(),
            "timings": dict(self.timings),
            "failure": self.failure,
        }


@dataclass(frozen=True, slots=True)
class MetricVerdict:
    """One metric's two medians, their ratio, and the rule applied to it."""

    metric: str
    legacy_values: tuple[float, ...]
    python_values: tuple[float, ...]
    legacy_median: float
    python_median: float
    ratio: float
    verdict: str
    reason: str = ""

    def to_json(self) -> dict[str, object]:
        payload = asdict(self)
        payload["legacy_values"] = list(self.legacy_values)
        payload["python_values"] = list(self.python_values)
        return payload


# ---------------------------------------------------------------------------
# Reading the configuration
# ---------------------------------------------------------------------------


def sysfs_from_request(entries: Sequence[str]) -> dict[str, Path]:
    """Parse `NAME=PATH` arguments into the named sysfs set the snapshot reads."""
    named: dict[str, Path] = {}
    for entry in entries:
        name, separator, value = entry.partition("=")
        if not separator or not name or not value:
            raise CanaryRefused(f"a sysfs argument reads NAME=PATH; this one reads {entry!r}")
        named[name] = Path(value)
    return named


def selected_line(text: str) -> str:
    """The delivered state of a DPM file, which is the line its driver marks.

    `pp_dpm_sclk` and `pp_dpm_mclk` list every level and mark the delivered one
    with a trailing asterisk, so reading the whole file would report the ladder
    and reading the marked line reports the state the arm actually ran at. A
    file carrying no mark reads back whole and stripped.
    """
    marked = [line.strip() for line in text.splitlines() if line.rstrip().endswith("*")]
    if marked:
        return " | ".join(marked)
    return text.strip()


def read_sysfs(named: Mapping[str, Path]) -> dict[str, str]:
    """Each named file's delivered state, with an unreadable file named as such."""
    values: dict[str, str] = {}
    for name, path in sorted(named.items()):
        try:
            values[name] = selected_line(path.read_text(encoding="utf-8"))
        except OSError as error:
            values[name] = f"unreadable: {error.strerror or error}"
    return values


def listener_pid(port: int) -> int:
    """The pid holding the listening socket on one port at any local address.

    Neither arm cooperates with this read: the legacy launch publishes its pids
    in a session status file and the Python launch publishes `state/runtime.json`,
    so a canary that read either would measure one arm through one authority and
    the other through another. The socket inode is the one identity both arms
    carry, and `/proc/<pid>/fd` is where it resolves to a process.
    """
    inodes = set(_listening_inodes(port, address=None))
    if not inodes:
        return 0
    for entry in sorted(Path("/proc").iterdir()):  # appliance-path: named
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        try:
            if _socket_inodes(pid) & inodes:
                return pid
        except (ListenerAbsent, OSError):
            # A pid whose descriptor table this user cannot read holds no
            # socket this process could have opened, and a pid that left
            # between the listing and the read holds nothing at all.
            continue
    return 0


PRESET_FLAG = "--models-preset"
LAUNCH_EXIT_GRACE_SECONDS = 60.0
LAUNCH_SETTLE_SECONDS = 1.0
TRANSPORT_FLAGS = frozenset({"--host", "--port", "--api-key-file", "--cors-origins", "--path"})
# Flag words with no value that name how the server presents rather than decodes.
PRESENTATION_FLAGS = frozenset({"--ui", "--no-ui"})
_ABSOLUTE_PATH_TOKEN = re.compile(r"/[^\s\"']+")
_DPM_MARKED_LINE = re.compile(r"^(\d+):\s.*\*\s*$")


def preset_digest(argv: Sequence[str]) -> str:
    """The SHA-256 of the preset the argv names after `--models-preset`, with
    every absolute path in it reduced to its basename first, read while the
    process is alive because the legacy launch removes its snapshot at
    teardown; empty when the argv names no preset or the file is unreadable.

    The two arms name the same checkpoints and configurations under different
    roots (the legacy launch's runtime root and per-launch snapshot directory
    against the Python arm's), so the bytes differ by prefix alone while the
    policy they carry is one; the basename keeps which file, the prefix goes.
    """
    for index, word in enumerate(argv[:-1]):
        if word == PRESET_FLAG:
            try:
                text = Path(argv[index + 1]).read_text(encoding="utf-8", errors="replace")
            except OSError:
                return ""
            normalized = _ABSOLUTE_PATH_TOKEN.sub(
                lambda match: "path:" + match.group(0).rsplit("/", 1)[-1], text
            )
            return hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    return ""


def executable_digest(argv: Sequence[str]) -> str:
    """The SHA-256 of the executable the argv runs; empty when unreadable."""
    if not argv:
        return ""
    try:
        return hashlib.sha256(Path(argv[0]).read_bytes()).hexdigest()
    except OSError:
        return ""


def comparable_sysfs_value(value: str) -> str:
    """A `pp_dpm_*` marked line reduced to its level index; other values whole.

    The marked line carries the level's live frequency beside its index, and
    that frequency moves between reads of one arm; the index is the delivered
    DPM state the arms must share.
    """
    match = _DPM_MARKED_LINE.match(value.strip())
    return f"level {match.group(1)}" if match else value


def read_argv(pid: int) -> tuple[str, ...]:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()  # appliance-path: named
    except OSError:
        return ()
    return tuple(part.decode("utf-8", "replace") for part in raw.split(b"\0") if part)


def read_niceness(pid: int) -> int | None:
    """Field 19 of `/proc/<pid>/stat`, read past the comm field's own parentheses."""
    try:
        text = Path(f"/proc/{pid}/stat").read_text(encoding="utf-8")  # appliance-path: named
    except OSError:
        return None
    closing = text.rfind(")")
    if closing < 0:
        return None
    fields = text[closing + 2 :].split()
    nice_index = 16
    if len(fields) <= nice_index:
        return None
    try:
        return int(fields[nice_index])
    except ValueError:
        return None


def read_affinity(pid: int) -> tuple[int, ...]:
    try:
        return tuple(sorted(os.sched_getaffinity(pid)))
    except OSError:
        return ()


def snapshot(port: int, named_sysfs: Mapping[str, Path]) -> Configuration:
    """The whole configuration one arm ran under, read from the live process."""
    pid = listener_pid(port)
    sysfs = read_sysfs(named_sysfs)
    if pid == 0:
        return Configuration(
            sysfs=sysfs, reason=f"no process holds the listening socket on port {port}"
        )
    argv = read_argv(pid)
    return Configuration(
        argv=argv,
        cpu_affinity=read_affinity(pid),
        niceness=read_niceness(pid),
        sysfs=sysfs,
        pid=pid,
        preset_sha256=preset_digest(argv),
        executable_sha256=executable_digest(argv),
    )


# ---------------------------------------------------------------------------
# One arm
# ---------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Endpoint:
    """The server the canary measures, which is the engine rather than the gateway."""

    host: str
    port: int
    bearer: str = ""

    @classmethod
    def parse(cls, base: str, bearer_file: Path | None = None) -> Endpoint:
        parts = urlsplit(base)
        if parts.scheme != "http" or not parts.hostname:
            raise CanaryRefused(
                f"the canary base names {base!r}; it reads an http origin such as "
                "http://127.0.0.1:8080"
            )
        bearer = ""
        if bearer_file is not None:
            try:
                bearer = bearer_file.read_text(encoding="utf-8").strip()
            except OSError as error:
                raise CanaryRefused(f"the bearer file is unreadable: {error}") from None
            if not bearer:
                raise CanaryRefused(f"the bearer file is empty: {bearer_file}")
        return cls(parts.hostname, parts.port or 80, bearer)

    def _headers(self, **extra: str) -> dict[str, str]:
        headers = dict(extra)
        if self.bearer:
            headers["Authorization"] = f"Bearer {self.bearer}"
        return headers

    def get(self, path: str, timeout_s: float) -> tuple[int, bytes]:
        connection = HTTPConnection(self.host, self.port, timeout=timeout_s)
        try:
            connection.request("GET", path, headers=self._headers())
            response = connection.getresponse()
            return response.status, response.read()
        finally:
            connection.close()

    def post(self, path: str, payload: object, timeout_s: float) -> tuple[int, bytes]:
        connection = HTTPConnection(self.host, self.port, timeout=timeout_s)
        try:
            connection.request(
                "POST",
                path,
                body=json.dumps(payload).encode("utf-8"),
                headers=self._headers(**{"Content-Type": "application/json"}),
            )
            response = connection.getresponse()
            return response.status, response.read()
        finally:
            connection.close()


def wait_ready(endpoint: Endpoint, deadline_s: float) -> str:
    """Poll `/health` until the server reports ok, or name what the wait ended on."""
    deadline = time.monotonic() + deadline_s
    last = "no answer"
    while time.monotonic() < deadline:
        try:
            status, body = endpoint.get("/health", timeout_s=5.0)
        except OSError as error:
            last = str(error)
        else:
            if status == 200:
                try:
                    payload = json.loads(body.decode("utf-8"))
                except (ValueError, UnicodeDecodeError):
                    payload = {}
                if isinstance(payload, dict) and payload.get("status") == "ok":
                    return ""
                last = f"/health answered {payload}"
            else:
                last = f"/health answered {status}"
        time.sleep(READINESS_POLL_SECONDS)
    return f"the server did not report ready within {deadline_s:.0f} s: {last}"


def wait_ready_or_exit(
    endpoint: Endpoint, deadline_s: float, launch: subprocess.Popen[bytes]
) -> str:
    """Wait for ready while the launch runs; a launch that exits first names its status."""
    deadline = time.monotonic() + deadline_s
    last = "no answer"
    while time.monotonic() < deadline:
        code = launch.poll()
        if code is not None and code != 0:
            _, stderr = launch.communicate(timeout=5)
            return f"the launch exited {code}: {stderr.decode('utf-8', 'replace')[:300]}"
        try:
            status, body = endpoint.get("/health", timeout_s=5.0)
        except OSError as error:
            last = str(error)
        else:
            if status == 200:
                try:
                    payload = json.loads(body.decode("utf-8"))
                except (ValueError, UnicodeDecodeError):
                    payload = {}
                if isinstance(payload, dict) and payload.get("status") == "ok":
                    return _launch_settled(launch)
                last = f"/health answered {payload}"
            else:
                last = f"/health answered {status}"
        time.sleep(READINESS_POLL_SECONDS)
    return f"the server did not report ready within {deadline_s:.0f} s: {last}"


def _launch_settled(launch: subprocess.Popen[bytes]) -> str:
    """Give a returning launch a moment to report; a non-zero status refuses the arm.

    A server that already answers can precede the launch's own exit by a
    tick, and the launch's status is the launch's verdict on what it started.
    """
    try:
        launch.wait(timeout=LAUNCH_SETTLE_SECONDS)
    except subprocess.TimeoutExpired:
        return ""
    if launch.returncode != 0:
        _, stderr = launch.communicate(timeout=5)
        return f"the launch exited {launch.returncode}: {stderr.decode('utf-8', 'replace')[:300]}"
    return ""


def read_timings(payload: object) -> dict[str, float]:
    """The server's own timing block, wherever the completion carries it.

    llama-server answers `/v1/chat/completions` with a `timings` object beside
    the choices, and a build that carries it under `usage` states the same
    numbers; a completion carrying neither leaves the metric absent, which the
    verdict reads as a refusal rather than as a zero.
    """
    if not isinstance(payload, dict):
        return {}
    block = payload.get("timings")
    if not isinstance(block, dict):
        usage = payload.get("usage")
        block = usage.get("timings") if isinstance(usage, dict) else None
    if not isinstance(block, dict):
        return {}
    return {
        name: float(block[name])
        for name in METRICS
        if isinstance(block.get(name), int | float) and not isinstance(block.get(name), bool)
    }


def run_arm(
    arm: str, ordinal: int, commands: ArmCommands, request: CanaryRequest, endpoint: Endpoint
) -> ArmResult:
    """Start one arm, measure one fixed prompt against it, and stop it again.

    The stop runs whatever the measurement did, since an arm left running holds
    the one Vulkan device the next arm needs.
    """
    if not commands.start or not commands.stop:
        return ArmResult(
            arm,
            ordinal,
            Configuration(reason="the arm names no start and stop argv"),
            failure=f"the {arm} arm names no start and stop argv",
        )
    # A launch either returns once its server is up (the shell chain) or holds
    # the foreground for the server's life (the appliance), so the start runs
    # as a child the readiness wait watches: an exit before ready is the
    # launch's own refusal, and a child still running at ready is left to the
    # stop argv, which ends it the way it ends the server.
    started = subprocess.Popen(  # noqa: S603
        list(commands.start), stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    try:
        waited = wait_ready_or_exit(endpoint, request.readiness_deadline_s, started)
        if waited:
            return ArmResult(arm, ordinal, Configuration(reason=waited), failure=waited)
        configuration = snapshot(endpoint.port, request.sysfs)
        body: dict[str, object] = {
            "stream": False,
            "max_tokens": request.tokens,
            "messages": [{"role": "user", "content": request.prompt}],
        }
        if request.model:
            body["model"] = request.model
        try:
            status, payload = endpoint.post(
                "/v1/chat/completions", body, timeout_s=EXCHANGE_DEADLINE_SECONDS
            )
        except OSError as error:
            return ArmResult(
                arm, ordinal, configuration, failure=f"the completion refused: {error}"
            )
        if status != 200:
            return ArmResult(
                arm, ordinal, configuration, failure=f"the completion answered {status}"
            )
        try:
            document = json.loads(payload.decode("utf-8"))
        except (ValueError, UnicodeDecodeError) as error:
            return ArmResult(
                arm, ordinal, configuration, failure=f"the completion body is not JSON: {error}"
            )
        timings = read_timings(document)
        failure = "" if timings else "the completion carries no timings block"
        return ArmResult(arm, ordinal, configuration, timings=timings, failure=failure)
    finally:
        subprocess.run(list(commands.stop), capture_output=True, check=False)  # noqa: S603
        _end_launch(started)


def _end_launch(launch: subprocess.Popen[bytes]) -> None:
    """Let a foreground launch leave after its server stopped; end one that lingers."""
    try:
        launch.communicate(timeout=LAUNCH_EXIT_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        launch.kill()
        launch.communicate(timeout=5)


# ---------------------------------------------------------------------------
# The verdict
# ---------------------------------------------------------------------------


def configuration_disagreements(results: Sequence[ArmResult]) -> list[str]:
    """Every configuration field two arms in this window disagree on.

    A field that differs makes the two arms two machine states, and two machine
    states are two sweeps; the 30.6% cross-sweep spread this tree measured is
    what a verdict computed across them would actually be reporting.
    """
    measured = [result for result in results if result.configuration.pid]
    if len(measured) < 2:
        return []
    reference = measured[0].configuration.comparable()
    disagreements: list[str] = []
    for result in measured[1:]:
        current = result.configuration.comparable()
        for key in sorted(set(reference) | set(current)):
            if reference.get(key) != current.get(key):
                disagreements.append(
                    f"{key} reads {current.get(key)!r} on the {result.arm} arm against "
                    f"{reference.get(key)!r} on the {measured[0].arm} arm"
                )
    return disagreements


def metric_verdict(metric: str, results: Sequence[ArmResult], ratio: float) -> MetricVerdict:
    def values(arm: str) -> tuple[float, ...]:
        return tuple(
            result.timings[metric]
            for result in results
            if result.arm == arm and metric in result.timings
        )

    legacy = values(LEGACY_ARM)
    python = values(PYTHON_ARM)
    if not legacy or not python:
        return MetricVerdict(
            metric,
            legacy,
            python,
            0.0,
            0.0,
            0.0,
            VERDICT_REFUSED,
            f"{metric} was measured on {len(legacy)} legacy and {len(python)} python arms",
        )
    legacy_median = statistics.median(legacy)
    python_median = statistics.median(python)
    observed = python_median / legacy_median if legacy_median else 0.0
    held = observed >= ratio
    return MetricVerdict(
        metric,
        legacy,
        python,
        legacy_median,
        python_median,
        observed,
        VERDICT_HELD if held else VERDICT_REGRESSION,
        ""
        if held
        else f"{metric} sits at {observed:.3f} of the legacy arm against the declared {ratio:.2f}",
    )


def verdict(
    request: CanaryRequest, results: Sequence[ArmResult]
) -> tuple[str, str, list[MetricVerdict]]:
    """The overall verdict, its reason, and the per-metric rows behind it."""
    failures = [result.failure for result in results if result.failure]
    disagreements = configuration_disagreements(results)
    if disagreements:
        return (
            VERDICT_REFUSED,
            "the arms ran under different configurations: " + "; ".join(disagreements),
            [],
        )
    if request.repeats < 2:
        return (
            VERDICT_REFUSED,
            f"the window ran {request.repeats} alternation; a single pair reports queue "
            "position rather than a difference between the two launches",
            [],
        )
    if failures:
        return (VERDICT_REFUSED, "an arm failed: " + "; ".join(failures), [])
    rows = [metric_verdict(metric, results, request.ratio) for metric in METRICS]
    refused = [row for row in rows if row.verdict == VERDICT_REFUSED]
    if refused:
        return (VERDICT_REFUSED, "; ".join(row.reason for row in refused), rows)
    regressed = [row for row in rows if row.verdict == VERDICT_REGRESSION]
    if regressed:
        return (VERDICT_REGRESSION, "; ".join(row.reason for row in regressed), rows)
    return (VERDICT_HELD, "", rows)


def rule_text(ratio: float) -> str:
    """The pre-registered rule, stated beside the band it sits inside."""
    return (
        f"The Python arm holds where its median sits at or above {ratio:.2f} of the legacy "
        f"arm's median on the same window. The arms run ABAB inside one window against one "
        f"machine state, which is what admits a margin of {(1 - ratio) * 100:.0f}%: a "
        f"difference below about {SINGLE_ARM_BAND * 100:.0f}% quoted from single arms across "
        "sweeps reports queue position rather than a change in the software. A configuration "
        "field that differs between arms refuses the verdict outright."
    )


def report_document(
    request: CanaryRequest,
    results: Sequence[ArmResult],
    overall: str,
    reason: str,
    rows: Sequence[MetricVerdict],
) -> dict[str, object]:
    return {
        "schema": "qwen-apu-canary-report-v1",
        "base": request.base,
        "repeats": request.repeats,
        "declared_ratio": request.ratio,
        "single_arm_band": SINGLE_ARM_BAND,
        "prompt": request.prompt,
        "tokens": request.tokens,
        "model": request.model,
        "order": [result.arm for result in results],
        "rule": rule_text(request.ratio),
        "verdict": overall,
        "reason": reason,
        "metrics": [row.to_json() for row in rows],
        "arms": [result.to_json() for result in results],
    }


def render_markdown(document: Mapping[str, object]) -> str:
    metrics = document.get("metrics")
    rows: list[object] = metrics if isinstance(metrics, list) else []
    order = document.get("order")
    order_text = " ".join(str(entry) for entry in order) if isinstance(order, list) else "-"
    lines = [
        "# Parity canary",
        "",
        str(document.get("rule", "")),
        "",
        f"Verdict: **{document.get('verdict')}**. {document.get('reason') or ''}".strip(),
        "",
        f"Order: `{order_text}`.",
        "",
        "| Metric | legacy median | python median | ratio | verdict |",
        "| --- | ---: | ---: | ---: | --- |",
    ]
    for row in rows:
        if not isinstance(row, dict):
            continue
        lines.append(
            f"| `{row['metric']}` | {row['legacy_median']:.3f} | {row['python_median']:.3f} "
            f"| {row['ratio']:.3f} | {row['verdict']} |"
        )
    lines.extend(["", "| Arm | ordinal | " + " | ".join(METRICS) + " | failure |"])
    lines.append("| --- | ---: | " + " | ".join("---:" for _ in METRICS) + " | --- |")
    arms = document.get("arms")
    for arm in arms if isinstance(arms, list) else []:
        if not isinstance(arm, dict):
            continue
        timings = arm.get("timings")
        values = timings if isinstance(timings, dict) else {}
        cells = " | ".join(
            f"{values[metric]:.3f}" if metric in values else "-" for metric in METRICS
        )
        lines.append(f"| {arm['arm']} | {arm['ordinal']} | {cells} | {arm.get('failure') or '-'} |")
    return "\n".join(lines) + "\n"


def require_inside_root(paths: RuntimePaths, report: Path) -> Path:
    resolved = report if report.is_absolute() else (paths["qwen_home_results"] / report)
    # `is_inside_root` resolves both sides and takes `relative_to`, which a
    # string prefix test does not: `<root>-scratch` prefixes the root's own
    # spelling while sitting beside it rather than under it.
    if not paths.is_inside_root(resolved.parent):
        raise CanaryRefused(
            f"the canary report writes under the runtime root alone; {resolved} is outside "
            f"{paths.root}"
        )
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def run(paths: RuntimePaths, request: CanaryRequest) -> int:
    """Alternate both arms, write the report, and exit non-zero unless the rule held."""
    destination = require_inside_root(paths, request.report)
    if request.repeats < 1:
        raise CanaryRefused(f"the canary runs at least one alternation; {request.repeats} is none")
    legacy_endpoint = Endpoint.parse(
        request.legacy.base or request.base, request.legacy.bearer_file
    )
    python_endpoint = Endpoint.parse(
        request.python.base or request.base, request.python.bearer_file
    )
    results: list[ArmResult] = []
    for ordinal in range(1, request.repeats + 1):
        results.append(run_arm(LEGACY_ARM, ordinal, request.legacy, request, legacy_endpoint))
        results.append(run_arm(PYTHON_ARM, ordinal, request.python, request, python_endpoint))
    overall, reason, rows = verdict(request, results)
    document = report_document(request, results, overall, reason, rows)
    destination.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    markdown = destination.with_suffix(".md")
    markdown.write_text(render_markdown(document), encoding="utf-8")
    print(f"canary_report={destination} markdown={markdown} verdict={overall}")
    if reason:
        print(f"reason={reason}")
    for row in rows:
        print(f"{row.metric}\tratio={row.ratio:.3f}\t{row.verdict}")
    return 0 if overall == VERDICT_HELD else 1
