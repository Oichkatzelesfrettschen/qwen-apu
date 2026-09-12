"""One supervisor for the whole application: router, gateway, and the lane children.

`qwen-webui-session.sh` owns four processes at once -- the capacity server, the
approval broker, `image-service.py`, and `searxng-launch.sh` -- and a tmux
session owns that script. The tmux boundary is what made every recovery
indirect: `tmux kill-session` ends the session script without running its EXIT
trap, so each child is orphaned and the teardown re-reads pids out of
`session.status` before `stop` rewrites it. This module is the parent instead.
Each child is its own process group, started with an argv list and no shell, and
its identity is the pid together with the start time `/proc/<pid>/stat` field 22
carries. Every signal is bound to that pair, so a pid reused between the record
and the stop is left alone, and nothing here matches a process by name.

The router server keeps the supervisor that already owns it:
`qwen_apu.runtime.supervisor` holds the Vulkan workload lease, the deployment
lock, the readiness states, and `state/runtime.json`, and it runs here as a
child process rather than a thread because it installs SIGTERM and SIGINT
handlers, which `signal.signal` admits on the main thread alone. The gateway
runs in this process, since it owns no device and its shutdown is a method call.

`state/appliance.json` is published whole through a temporary leaf and
`os.replace`, the way `state/runtime.json` is, so a reader between two
transitions reads one complete record rather than a truncated one. It carries
every child's pid, process group, start time, and listener or socket identity,
the deployment the router resolved, and the readiness the supervisor published,
which is what makes `stop` able to signal exactly what this process started.
"""

from __future__ import annotations

import dataclasses
import http.client
import json
import os
import signal
import sys
import tempfile
import threading
import time
from collections.abc import Mapping, Sequence
from dataclasses import asdict, dataclass, field, replace
from pathlib import Path
from types import FrameType
from typing import Any

from qwen_apu.config import models as config_models
from qwen_apu.runtime import lanes
from qwen_apu.runtime import serve as serving
from qwen_apu.runtime import state as runtime_state
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.process import Owned, read_start_time, spawn, terminate
from qwen_apu.runtime.state import utc_now
from qwen_apu.web import assemble as gateway_assembly

SCHEMA = "qwen-apu-appliance-state-v1"
RECORD_MODE = 0o600
RECORD_NAME = "appliance.json"

ROUTER_CHILD = "router"
IMAGE_CHILD = "image-service"
SEARXNG_CHILD = "searxng"

READY_SOCKET = "socket"
READY_HEALTHZ = "healthz"
HEALTHZ_PATH = "/healthz"

SAMPLE_INTERVAL_SECONDS = 0.5
READINESS_DEADLINE_SECONDS = 240.0
TERMINATION_GRACE_SECONDS = 2.0


class ApplianceRefused(RuntimeError):
    """A refusal before any child started, naming what refused it."""


@dataclass(frozen=True, slots=True)
class ChildSpec:
    """One process the appliance owns, declared before anything is spawned.

    `socket_path` and `port` are the listener identity a reader needs to reach
    the child: the image worker answers on a Unix socket the gateway connects
    to, and SearXNG answers on a loopback TCP port.
    """

    name: str
    argv: tuple[str, ...]
    env: Mapping[str, str]
    log_name: str
    port: int | None = None
    socket_path: str = "-"
    # What proves this child reached its listener before the appliance reports
    # ready. `socket` waits for `socket_path` to be a bound Unix socket, the
    # observable `qwen-webui-session.sh` reads off the worker's own `socket`
    # line; `healthz` waits for `GET /healthz` on `port`, the route
    # `remote/searxng-launch.sh start` waits on. `-` starts the child and
    # watches it for exit alone, which is what the router supervisor needs
    # since it publishes its readiness through `state/runtime.json`.
    ready: str = "-"
    ready_deadline_s: float = 120.0


@dataclass(frozen=True, slots=True)
class ChildRecord:
    """One owned child as the record publishes it."""

    name: str
    pid: int
    pgid: int
    start_time: int
    argv0: str
    port: int | None = None
    socket_path: str = "-"
    state: str = "running"


@dataclass(frozen=True, slots=True)
class ApplianceState:
    """The whole application as this supervisor last observed it.

    `primary_failure` is written once and holds what ended the service;
    `restoration_failures` collects everything a teardown then failed to prove.
    Overwriting the first with the last would leave an appliance that died of a
    router crash reporting a socket it could not unlink.
    """

    state: str
    schema: str = SCHEMA
    supervisor_pid: int = 0
    supervisor_start_time: int = 0
    gateway_pid: int = 0
    gateway_start_time: int = 0
    gateway_port: int = 0
    gateway_origin: str = "-"
    deployment: str = "-"
    deployment_directory: str = "-"
    router_state: str = "-"
    served_models: tuple[str, ...] = ()
    children: tuple[ChildRecord, ...] = ()
    primary_failure: str | None = None
    restoration_failures: tuple[str, ...] = ()
    exit_status: int | None = None
    started_utc: str = "-"
    updated_utc: str = "-"

    def to_json(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["served_models"] = list(self.served_models)
        payload["restoration_failures"] = list(self.restoration_failures)
        payload["children"] = [asdict(child) for child in self.children]
        return payload

    @classmethod
    def from_json(cls, payload: Mapping[str, Any]) -> ApplianceState:
        fields = {entry.name for entry in cls.__dataclass_fields__.values()}
        values = {key: value for key, value in payload.items() if key in fields}
        values["served_models"] = tuple(str(entry) for entry in values.get("served_models") or ())
        values["restoration_failures"] = tuple(
            str(entry) for entry in values.get("restoration_failures") or ()
        )
        children = values.get("children") or ()
        child_fields = {entry.name for entry in ChildRecord.__dataclass_fields__.values()}
        values["children"] = tuple(
            ChildRecord(**{key: value for key, value in dict(child).items() if key in child_fields})
            for child in children
        )
        return cls(**values)


@dataclass
class ApplianceRecord:
    """The file that carries the application's state, replaced rather than truncated."""

    path: Path
    current: ApplianceState | None = field(default=None)

    def read(self) -> ApplianceState | None:
        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return None
        if not isinstance(payload, dict):
            return None
        try:
            return ApplianceState.from_json(payload)
        except TypeError:
            return None

    def write(self, record: ApplianceState) -> ApplianceState:
        """Publish one whole record: a temporary leaf beside it, then `os.replace`.

        The leaf shares the directory so the rename stays inside one filesystem,
        which is what makes the replacement atomic for every reader.
        """
        stamped = replace(record, updated_utc=utc_now())
        self.path.parent.mkdir(parents=True, exist_ok=True)
        handle = tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=str(self.path.parent),
            prefix=f".{self.path.name}.",
            suffix=".new",
            delete=False,
        )
        temporary = Path(handle.name)
        try:
            with handle:
                json.dump(stamped.to_json(), handle, indent=2, sort_keys=True)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.chmod(temporary, RECORD_MODE)
            os.replace(temporary, self.path)
        except OSError:
            temporary.unlink(missing_ok=True)
            raise
        self.current = stamped
        return stamped

    def transition(self, state: str, **changes: Any) -> ApplianceState:
        base = self.current or self.read() or ApplianceState(state=state, started_utc=utc_now())
        failure = changes.pop("primary_failure", None)
        record = replace(base, state=state, **changes)
        if failure is not None:
            if record.primary_failure is None:
                record = replace(record, primary_failure=failure)
            else:
                record = replace(
                    record, restoration_failures=(*record.restoration_failures, failure)
                )
        return self.write(record)


@dataclass(frozen=True)
class ApplianceRequest:
    """One application launch, declared whole before a process exists."""

    serve: serving.ServeRequest = field(default_factory=serving.ServeRequest)
    gateway: gateway_assembly.GatewayRequest = field(
        default_factory=gateway_assembly.GatewayRequest
    )
    # A lane child joins the application where its profile enables it. The
    # image worker holds the Vulkan device beside the router and SearXNG holds
    # a loopback port, so each is named explicitly rather than inferred.
    image_service: ChildSpec | None = None
    searxng: ChildSpec | None = None
    readiness_deadline_s: float = READINESS_DEADLINE_SECONDS
    sample_interval_s: float = SAMPLE_INTERVAL_SECONDS


def record_path(paths: RuntimePaths) -> Path:
    return paths["qwen_home_state"] / RECORD_NAME


def child_record(name: str, owned: Owned, spec: ChildSpec) -> ChildRecord:
    return ChildRecord(
        name=name,
        pid=owned.pid,
        pgid=owned.pgid,
        start_time=owned.start_time,
        argv0=spec.argv[0],
        port=spec.port,
        socket_path=spec.socket_path,
    )


def router_child_spec(paths: RuntimePaths, plan_path: Path) -> ChildSpec:
    """The supervisor, run as a child of this process rather than detached.

    `--daemon` would make the supervisor a session leader of its own and this
    process would then hold no pidfd, no exit status, and no group to signal.
    Running it as an ordinary child keeps `Owned.has_exited` and `terminate`
    answering for it.
    """
    return ChildSpec(
        name=ROUTER_CHILD,
        argv=(sys.executable, "-m", "qwen_apu.runtime.supervisor", "--plan", str(plan_path)),
        env=dict(os.environ),
        log_name="appliance-router",
        port=None,
        socket_path=str(paths["qwen_home_control_socket"]),
    )


class Appliance:
    """The owner of the router, the gateway, and whichever lane children a profile arms."""

    def __init__(self, paths: RuntimePaths, request: ApplianceRequest) -> None:
        self.paths = paths
        self.request = request
        self.record = ApplianceRecord(path=record_path(paths))
        self.runtime_record = paths["qwen_home_runtime_state"]
        # The previous run's record survives its stop, so the first reads of
        # this run land on it; the supervisor pid it names is passed over
        # until this run's supervisor publishes its own.
        previous = runtime_state.read(self.runtime_record)
        self._superseded_pid = previous.supervisor_pid if previous is not None else 0
        self._children: list[tuple[ChildSpec, Owned]] = []
        self._stop = threading.Event()

    # -- the run ---------------------------------------------------------

    def _serve_request(self) -> serving.ServeRequest:
        """The router's serve request with the authorizer marker set.

        This process owns the gateway whose approval routes and single-use
        grants the web preset sections assume, so the marker the policy
        requires for those sections is true here and nowhere else.
        """
        return dataclasses.replace(self.request.serve, web_authorizer_ready=True)

    def run(self) -> int:
        """Start every owned process, serve, and report residue in the exit status."""
        for line in serving.run_preflights(self.paths, self._serve_request()):
            print(line, flush=True)
        for line in gateway_assembly.preflight_gateway(self.paths, self.request.gateway):
            print(line, flush=True)

        self.record.transition(
            "starting",
            supervisor_pid=os.getpid(),
            supervisor_start_time=read_start_time(os.getpid()) or 0,
            started_utc=utc_now(),
        )
        plan = serving.build_plan(self.paths, self._serve_request())
        plan_path = self.paths["qwen_home_state"] / "launch-plan.json"
        plan_path.parent.mkdir(parents=True, exist_ok=True)
        plan_path.write_text(
            json.dumps(serving.plan_to_json(plan), indent=2) + "\n", encoding="utf-8"
        )

        primary_failure: str | None = None
        gateway = None
        thread: threading.Thread | None = None
        try:
            self._start(router_child_spec(self.paths, plan_path))
            for lane in (self.request.image_service, self.request.searxng):
                if lane is not None:
                    self._await_ready(lane, self._start(lane))
            gateway, _session_gate, code = self._start_gateway()
            thread = threading.Thread(target=gateway.serve_forever, name="qwen-apu-gateway")
            thread.start()
            self.record.transition(
                "starting",
                gateway_pid=os.getpid(),
                gateway_start_time=read_start_time(os.getpid()) or 0,
                gateway_port=gateway.port,
                gateway_origin=f"http://{self.request.gateway.bind_host}:{gateway.port}",
                deployment=plan.deployment,
                children=tuple(
                    child_record(spec.name, owned, spec) for spec, owned in self._children
                ),
            )
            print(
                f"appliance_gateway=http://127.0.0.1:{gateway.port}/ pairing_code={code}",
                flush=True,
            )
            with _SignalHandlers(self._stop):
                primary_failure = self._watch()
        except Exception as error:
            primary_failure = f"{type(error).__name__}: {error}"
            raise
        finally:
            if gateway is not None:
                gateway.shutdown()
            if thread is not None:
                thread.join(timeout=10.0)
            exit_status = self._shut_down(primary_failure)
        return exit_status

    def _start(self, spec: ChildSpec) -> Owned:
        logs = self.paths["qwen_home_logs"]
        owned = spawn(
            spec.argv,
            env=dict(spec.env),
            cwd=self.paths.root,
            stdout_path=logs / f"{spec.log_name}.log",
            stderr_path=logs / f"{spec.log_name}.err",
        )
        self._children.append((spec, owned))
        return owned

    def _await_ready(self, spec: ChildSpec, owned: Owned) -> None:
        """Prove one lane child's listener before the gateway mounts its routes.

        The router's own 240-second deadline would otherwise absorb a worker
        that never binds and report `router_not_ready`, naming the wrong child.
        This wait names the child, its deadline, and its listener identity.
        """
        if spec.ready == "-":
            return
        deadline = time.monotonic() + spec.ready_deadline_s
        while time.monotonic() < deadline:
            if owned.has_exited():
                status = owned.exit_status()
                raise ApplianceRefused(
                    f"{spec.name} exited status={'-' if status is None else status} before its "
                    f"listener appeared; its log is {spec.log_name}.log under the runtime root"
                )
            if self._listening(spec):
                return
            time.sleep(self.request.sample_interval_s)
        raise ApplianceRefused(
            f"{spec.name} bound no listener inside {spec.ready_deadline_s:g} s "
            f"({spec.ready}: {spec.socket_path if spec.ready == READY_SOCKET else spec.port})"
        )

    @staticmethod
    def _listening(spec: ChildSpec) -> bool:
        """The one observable the child's readiness state names."""
        if spec.ready == READY_SOCKET:
            return Path(spec.socket_path).is_socket()
        if spec.ready == READY_HEALTHZ and spec.port:
            connection = http.client.HTTPConnection("127.0.0.1", spec.port, timeout=2.0)
            try:
                connection.request("GET", HEALTHZ_PATH)
                return connection.getresponse().status < 500
            except (OSError, http.client.HTTPException):
                return False
            finally:
                connection.close()
        return False

    def _start_gateway(self) -> tuple[Any, Any, str]:
        gateway, session = gateway_assembly.assemble(self.paths, self.request.gateway)
        return gateway, session, session.start()

    def _router_record(self) -> runtime_state.RuntimeState | None:
        """This run's router record; the previous run's is read as none."""
        router = runtime_state.read(self.runtime_record)
        if (
            router is not None
            and self._superseded_pid
            and router.supervisor_pid == self._superseded_pid
        ):
            return None
        return router

    def _watch(self) -> str | None:
        """Sample the owned children and republish readiness until something ends it."""
        deadline = time.monotonic() + self.request.readiness_deadline_s
        announced_ready = False
        while not self._stop.is_set():
            for spec, owned in self._children:
                if owned.has_exited():
                    status = owned.exit_status()
                    return f"{spec.name}_exited status={'-' if status is None else status}"
            router = self._router_record()
            router_state = router.state if router is not None else "-"
            served = tuple(router.served_models) if router is not None else ()
            if router is not None and router.is_terminal:
                return f"router_terminal state={router.state} {router.primary_failure or '-'}"
            if not announced_ready and router is not None and router.is_serving:
                announced_ready = True
                self.record.transition("ready", router_state=router_state, served_models=served)
            elif announced_ready:
                self.record.transition("ready", router_state=router_state, served_models=served)
            elif time.monotonic() > deadline:
                return f"router_not_ready state={router_state}"
            time.sleep(self.request.sample_interval_s)
        return None

    def _shut_down(self, primary_failure: str | None) -> int:
        """End every owned child, prove absence, and separate residue from the cause."""
        self.record.transition("stopping", primary_failure=primary_failure)
        residue: list[str] = []
        for spec, owned in reversed(self._children):
            termination = terminate(owned, grace_s=TERMINATION_GRACE_SECONDS)
            if not termination.absent:
                residue.append(
                    f"{spec.name} group {owned.pgid} survived SIGKILL ({termination.render()})"
                )
            owned.close()
        final_state = "failed" if primary_failure else "stopped"
        exit_status = 1 if (primary_failure or residue) else 0
        self.record.transition(
            final_state,
            restoration_failures=tuple(residue),
            exit_status=exit_status,
            children=(),
            gateway_pid=0,
            gateway_start_time=0,
        )
        for detail in residue:
            print(f"appliance teardown residue: {detail}", file=sys.stderr)
        return exit_status


class _SignalHandlers:
    """SIGTERM and SIGINT as a stop request rather than a process death."""

    def __init__(self, event: threading.Event) -> None:
        self._event = event
        self._previous: dict[int, Any] = {}

    def __enter__(self) -> _SignalHandlers:
        for number in (signal.SIGTERM, signal.SIGINT):
            self._previous[number] = signal.getsignal(number)
            signal.signal(number, self._handler())
        return self

    def __exit__(self, *_: object) -> None:
        for number, previous in self._previous.items():
            signal.signal(number, previous)

    def _handler(self) -> Any:
        def handle(_number: int, _frame: FrameType | None) -> None:
            self._event.set()

        return handle


# -- clients ------------------------------------------------------------


def status(paths: RuntimePaths) -> ApplianceState | None:
    """The published record, read from the file rather than from a socket."""
    return ApplianceRecord(path=record_path(paths)).read()


def stop(paths: RuntimePaths, *, grace_s: float = TERMINATION_GRACE_SECONDS) -> tuple[int, ...]:
    """Signal exactly the identities the record names, and leave every other pid alone.

    Each child is checked against `/proc/<pid>/stat` before a signal reaches it:
    a pid whose start time moved belongs to a process this appliance never
    started, and a number alone would signal whatever now holds it. No name
    match, no `pkill`, and no tmux session is involved, so a second appliance on
    the same machine is untouched by this one's teardown.
    """
    record = ApplianceRecord(path=record_path(paths))
    current = record.read()
    if current is None:
        return ()
    signalled: list[int] = []
    residue: list[str] = []
    for child in reversed(current.children):
        live = read_start_time(child.pid)
        if live != child.start_time:
            residue.append(
                f"{child.name} pid {child.pid} carries start time {live} against the recorded "
                f"{child.start_time}, so it is left alone"
            )
            continue
        owned = Owned(pid=child.pid, pgid=child.pgid or child.pid, start_time=child.start_time)
        termination = terminate(owned, grace_s=grace_s)
        signalled.append(child.pid)
        if not termination.absent:
            residue.append(f"{child.name} group {owned.pgid} survived SIGKILL")
    supervisor_pid = current.supervisor_pid
    if supervisor_pid and read_start_time(supervisor_pid) == current.supervisor_start_time:
        try:
            os.kill(supervisor_pid, signal.SIGTERM)
        except OSError as error:
            residue.append(f"signalling the appliance supervisor refused: {error}")
        else:
            signalled.append(supervisor_pid)
    record.write(
        replace(
            current,
            state="stopped" if not residue else current.state,
            restoration_failures=(*current.restoration_failures, *residue),
            children=(),
        )
    )
    return tuple(signalled)


def render(record: ApplianceState | None) -> str:
    """The record as `key=value` lines, one child per line."""
    if record is None:
        return "appliance=absent\n"
    lines = [
        f"state={record.state}",
        f"deployment={record.deployment}",
        f"router_state={record.router_state}",
        f"served_models={','.join(record.served_models) or '-'}",
        f"gateway={record.gateway_origin}",
        f"primary_failure={record.primary_failure or '-'}",
    ]
    lines.extend(
        f"child name={child.name} pid={child.pid} start_time={child.start_time} "
        f"port={child.port if child.port else '-'} socket={child.socket_path}"
        for child in record.children
    )
    return "".join(f"{line}\n" for line in lines)


def serve(paths: RuntimePaths, request: ApplianceRequest) -> int:
    return Appliance(paths, request).run()


def child_specs_from_request(
    paths: RuntimePaths,
    *,
    image_service: Sequence[str] = (),
    searxng: Sequence[str] = (),
    image_profile: str = "",
    web_profile: str = "",
    origin: str = "",
    bind_host: str = "127.0.0.1",
) -> tuple[ChildSpec | None, ChildSpec | None]:
    """The two lane children, derived from the profile ledgers or from a whole argv.

    A caller supplying `image_service` or `searxng` states the command itself
    and this function owns the process identity alone, which is the override an
    operator serving a bundle assembled before the derivation existed needs.
    An overridden child carries `ready` at `-`: the caller composed the argv, so
    the state directory and the port a readiness wait would watch belong to the
    caller rather than to this derivation, and a wait bound to the derived path
    would expire against a worker listening where the caller put it.
    Every other launch names a profile id: `qwen_apu.runtime.lanes` reads
    remote/image-profiles.tsv, remote/image-models.tsv, remote/image-artifacts.tsv,
    and remote/web-profiles.tsv against the runtime root and composes the argv
    `qwen-webui-session.sh` composes from the same rows.

    An image profile whose `execution_policy` reads `refused` arms no worker:
    the row admits a shape and spends no device time, and
    `qwen_apu.tools.matrix` answers `policy_refused` for it whether or not a
    process exists. A web profile naming no loopback SearXNG -- provider `exa`
    or `fake` -- starts no instance the same way, and so does a root whose
    SearXNG components `remote/searxng-launch.sh check` reports absent, since
    `serve` runs that same check and leaves before it binds.
    """
    if image_service:
        image: ChildSpec | None = ChildSpec(
            name=IMAGE_CHILD,
            argv=tuple(image_service),
            env=dict(os.environ),
            log_name="appliance-image-service",
            socket_path=str(lanes.image_control_socket(paths)),
        )
    else:
        image = _derived_image_child(
            paths,
            image_profile=image_profile,
            web_profile=web_profile,
            origin=origin,
            bind_host=bind_host,
        )
    if searxng:
        search: ChildSpec | None = ChildSpec(
            name=SEARXNG_CHILD,
            argv=tuple(searxng),
            env=dict(os.environ),
            log_name="appliance-searxng",
            port=int(os.environ.get("QWEN_SEARXNG_PORT", "8888")),
        )
    else:
        search = _derived_searxng_child(paths, web_profile)
    return image, search


def _derived_image_child(
    paths: RuntimePaths,
    *,
    image_profile: str,
    web_profile: str,
    origin: str,
    bind_host: str,
) -> ChildSpec | None:
    """The image worker this launch's own image profile declares."""
    if not image_profile:
        return None
    row = config_models.image_profile(image_profile)
    if row.execution_policy != "validator-gated":
        return None
    parameters = lanes.write_image_parameters(paths, image_profile)
    argv = lanes.image_service_argv(
        paths,
        origin=origin,
        bind_host=bind_host,
        parameters=parameters,
        api_key_file=lanes.image_artifact_key(paths),
    )
    return ChildSpec(
        name=IMAGE_CHILD,
        argv=argv,
        env=lanes.image_service_env(
            paths, profile_id=image_profile, web_profile=web_profile, parameters=parameters
        ),
        log_name="appliance-image-service",
        socket_path=str(lanes.image_control_socket(paths)),
        ready=READY_SOCKET,
    )


def _derived_searxng_child(paths: RuntimePaths, web_profile: str) -> ChildSpec | None:
    """The instance the web profile's own `searxng_url` names, where it names one."""
    if not web_profile:
        return None
    row = next(
        (entry for entry in config_models.load_web_profiles() if entry.profile_id == web_profile),
        None,
    )
    if row is None:
        return None
    endpoint = lanes.searxng_endpoint(row)
    if endpoint is None:
        return None
    absent = lanes.searxng_components_present(paths)
    if absent:
        print(f"searxng_lane=unarmed profile={web_profile} reason={absent}", flush=True)
        return None
    host, port = endpoint
    return ChildSpec(
        name=SEARXNG_CHILD,
        argv=lanes.searxng_argv(paths),
        env=lanes.searxng_env(host=host, port=port),
        log_name="appliance-searxng",
        port=port,
        ready=READY_HEALTHZ,
    )
