"""One word brings the appliance up, one takes it down, one brings it back.

`appliance serve` holds the terminal and states a launch as fourteen flags, two
of which are facts about the machine rather than decisions: the address a
browser on the network reaches, and the documentation root the file lane reads.
`launch_argv` derives both -- the address from the interface carrying the
default route, so a new DHCP lease leaves the command unchanged, and the root
from the checkout that holds this package -- and states the rest as the
defaults an operator otherwise retypes.

The supervision path stays one. `up` runs exactly the `appliance serve` argv an
operator would have typed, detached through
`qwen_apu.runtime.supervisor.relaunch_detached` so the terminal that started it
closes without reaching it, then waits on the record that process publishes
rather than on its own clock: `Appliance._watch` transitions the record to
`ready` when the router reports serving, which is the same claim a browser
tests. `down` is `appliance.stop`, so teardown signals the recorded identities
through the pid, process group, and start-time triple that function compares,
and `report` reads the record `appliance status` renders. What this module adds
is the derivation, the detachment, the wait, and the addresses.
"""

from __future__ import annotations

import sys
import time
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path

from qwen_apu.runtime import appliance, supervisor
from qwen_apu.runtime import serve as serving
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.process import read_start_time
from qwen_apu.web import app as gateway_app
from qwen_apu.web import assemble as gateway_assembly
from qwen_apu.web import auth as gateway_auth

# `/proc/net/route` is the routing table the kernel's `rt_cache_seq_show`
# writes, one row per route with every numeric field big-endian hex.
DEFAULT_ROUTE_TABLE = Path("/proc/net/route")  # appliance-path: named
_DEFAULT_ROUTE_DESTINATION = "00000000"

# The landing page's own port, which README states as the appliance's front
# door and the two surfaces link back to. `assemble.DEFAULT_GATEWAY_PORT` is
# 8090, the port a bare gateway takes when nothing states one, so the operator
# surface names 42069 here rather than inheriting a number the documentation
# does not carry.
LANDING_PORT = 42069

# The profile pair the served appliance runs: `web-open` arms the approval rail
# the pages drive, and `image-sdxs-512-a` is the one image row that reads
# `validator-gated` in remote/image-profiles.tsv, so it is the row a launch can
# serve a reviewed generation from.
DEFAULT_IMAGE_PROFILE = "image-sdxs-512-a"

# The record states `starting` for the whole model load, which holds the
# router's readiness for up to 120 s on this part, so the wait outlasts a load
# rather than reporting a launch that is still loading as failed.
READINESS_DEADLINE_SECONDS = 240.0
POLL_SECONDS = 0.5

LOG_NAME = "appliance.log"
# What `up` prints from the log when a launch ends before it reads `ready`: the
# refusal a preflight writes sits in the last few lines, and the whole file
# carries a model load's progress the operator did not ask for.
LOG_TAIL_LINES = 12

_LIVE_STATES = frozenset({"starting", "ready"})
# Every state a record reaches on its way out. A wait that treated
# `stopping` as still pending would hold its whole deadline over an
# appliance already unwinding.
_TERMINAL_STATES = frozenset({"stopping", "failed", "stopped"})


def default_route_interface(table: Path = DEFAULT_ROUTE_TABLE) -> str | None:
    """The interface carrying the default route, by lowest metric.

    The default route is the row whose destination and mask are both zero. Two
    interfaces up at once -- wired and wireless -- each publish one, and the
    stack routes a reply out of the lower metric, so this reads the row a peer's
    packet actually returns through.
    """
    try:
        rows = table.read_text(encoding="utf-8").splitlines()
    except OSError:
        return None
    candidates: list[tuple[int, str]] = []
    for row in rows[1:]:
        fields = row.split()
        if len(fields) < 8 or fields[1] != _DEFAULT_ROUTE_DESTINATION:
            continue
        if fields[7] != _DEFAULT_ROUTE_DESTINATION:
            continue
        try:
            metric = int(fields[6])
        except ValueError:
            continue
        candidates.append((metric, fields[0]))
    if not candidates:
        return None
    return min(candidates)[1]


def lan_address(table: Path = DEFAULT_ROUTE_TABLE) -> str | None:
    """The IPv4 address a peer on this network reaches this machine at.

    The interface comes from the routing table and the address from
    `SIOCGIFADDR` on that interface, so a reissued lease changes the answer and
    leaves the command that asked for it unchanged.
    """
    interface = default_route_interface(table)
    if interface is None:
        return None
    return gateway_app.interface_address(interface)


@dataclass(frozen=True, slots=True)
class LaunchDefaults:
    """The launch `up` states when the operator states nothing else.

    `bind_host` is the derived address, and `exposure_mode` with `lan_open`
    carry the boundary `AGENTS.md` names: `both` binds the loopback and that
    address, and `lan_open` admits the bound interface's own network without a
    pairing code. An operator narrowing the launch to this machine alone sets
    `exposure_mode` to `local` and `lan_open` false, which is what `up --local`
    passes.
    """

    bind_host: str
    exposure_mode: str = "both"
    lan_open: bool = True
    router: bool = True
    model_id: str = serving.DEFAULT_MODEL
    profile: str = serving.DEFAULT_PROFILE
    router_port: int = serving.DEFAULT_PORT
    gateway_port: int = LANDING_PORT
    llama_ui_port: int = gateway_assembly.DEFAULT_LLAMA_UI_PORT
    image_ui_port: int = gateway_assembly.DEFAULT_IMAGE_UI_PORT
    web_profile: str = gateway_assembly.DEFAULT_WEB_PROFILE
    image_profile: str = DEFAULT_IMAGE_PROFILE
    file_roots: tuple[Path, ...] = field(default_factory=tuple)


class LaunchRefused(RuntimeError):
    """A default this surface derives from the machine has no value to take."""


def launch_defaults(
    paths: RuntimePaths,
    *,
    bind_host: str | None = None,
    local: bool = False,
    lan_open: bool = True,
    table: Path = DEFAULT_ROUTE_TABLE,
) -> LaunchDefaults:
    """Every launch field, with the machine's own two facts read off the machine.

    A stated `bind_host` wins, `local` binds the loopback, and the remaining
    case derives the address. A derivation that finds no default route refuses
    and names the flag that answers it, because an appliance that guessed an
    address here would publish a page at a place no browser reaches.
    """
    if local:
        resolved = "127.0.0.1"
    elif bind_host:
        resolved = bind_host
    else:
        derived = lan_address(table)
        if derived is None:
            raise LaunchRefused(
                "no interface carries a default route, so this launch has no LAN "
                "address to publish; state one as --bind-host ADDRESS or serve "
                "this machine alone with --local"
            )
        resolved = derived
    return LaunchDefaults(
        bind_host=resolved,
        exposure_mode="local" if local else "both",
        lan_open=lan_open and not local,
        file_roots=(paths.tree / "docs",),
    )


def launch_argv(defaults: LaunchDefaults, *, python: str | None = None) -> tuple[str, ...]:
    """The `appliance serve` argv these defaults state, as a caller would type it.

    The command re-enters this package's own CLI, so `up` adds no second
    definition of what a launch is: a field here maps to the flag `cli.py`
    already parses, and a launch started by hand and a launch started by `up`
    reach `appliance.serve` with one request shape.
    """
    argv = [python or sys.executable, "-m", "qwen_apu", "appliance", "serve"]
    if defaults.router:
        argv.append("--router")
    argv.extend([f"--{defaults.exposure_mode}"])
    if defaults.lan_open:
        argv.append("--lan-open")
    argv.extend(
        [
            "--bind-host",
            defaults.bind_host,
            "--model",
            defaults.model_id,
            "--profile",
            defaults.profile,
            "--port",
            str(defaults.router_port),
            "--gateway-port",
            str(defaults.gateway_port),
            "--llama-ui-port",
            str(defaults.llama_ui_port),
            "--image-ui-port",
            str(defaults.image_ui_port),
            "--web-profile",
            defaults.web_profile,
            "--image-profile",
            defaults.image_profile,
        ]
    )
    for root in defaults.file_roots:
        argv.extend(["--file-root", str(root)])
    return tuple(argv)


def live(record: appliance.ApplianceState | None) -> bool:
    """Whether the record names a supervisor this machine still runs.

    A record survives the process it describes, so the state alone admits a
    launch that was killed outright. The start time separates the two: a pid
    whose `/proc/<pid>/stat` field 22 moved belongs to a process this appliance
    never started, which is the same comparison `appliance.stop` makes before
    it signals.
    """
    if record is None or record.state not in _LIVE_STATES:
        return False
    pid = record.supervisor_pid
    return bool(pid) and read_start_time(pid) == record.supervisor_start_time


def residue(record: appliance.ApplianceState | None) -> tuple[str, ...]:
    """The recorded children this machine still runs, by name.

    A record survives the supervisor that wrote it, and a supervisor killed
    outright leaves its children running with the record still naming them. The
    start-time comparison separates a survivor from a reused pid, the same
    identity test `appliance.stop` applies before it signals.
    """
    if record is None:
        return ()
    return tuple(
        child.name for child in record.children if read_start_time(child.pid) == child.start_time
    )


def report(record: appliance.ApplianceState | None, paths: RuntimePaths) -> str:
    """The addresses a browser opens, and what the appliance is serving there.

    `42069` lands, `42072` is Chat, and `42073` is Image, so each line names the
    surface rather than the port. The pairing code is the one this launch minted
    into `state/gateway-pairing.secret`; a peer inside an admitted network never
    presents it, and a spend clears the gate's own copy while leaving the file,
    so the line states what was minted rather than what remains unspent.
    """
    if record is None:
        return "appliance=absent\n"
    lines = [f"state={record.state}"]
    if live(record):
        lines.append(f"supervisor={record.supervisor_pid}")
    surfaces = (
        ("home", record.gateway_origin),
        ("chat", record.llama_ui_origin),
        ("image", record.image_ui_origin),
    )
    lines.extend(f"{name} {origin}" for name, origin in surfaces if origin and origin != "-")
    lines.append(f"serving={','.join(record.served_models) or '-'}")
    lines.append(f"deployment={record.deployment}")
    if record.primary_failure:
        lines.append(f"primary_failure={record.primary_failure}")
    code = pairing_code(paths)
    lines.append(f"pairing_code={code or '-'}")
    return "".join(f"{line}\n" for line in lines) + appliance.render_children(record)


def pairing_code(paths: RuntimePaths) -> str:
    """The code the running launch minted, read from the file that carries it.

    `qwen_apu.web.auth.SessionGate.start` writes it at mode 0600 and names this
    read as the one way it reaches an operator, so this is the reader that
    docstring describes.
    """
    secret = paths["qwen_home_state"] / gateway_auth.PAIRING_CODE_FILENAME
    try:
        return secret.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def up(
    paths: RuntimePaths,
    defaults: LaunchDefaults,
    *,
    python: str | None = None,
    deadline_s: float = READINESS_DEADLINE_SECONDS,
    poll_s: float = POLL_SECONDS,
) -> int:
    """Detach one `appliance serve` and return when its record reads `ready`.

    A launch that is already live returns its own addresses rather than binding
    a second listener on the same ports, so the command is idempotent and an
    operator who types it twice reads the same report both times.
    """
    existing = appliance.status(paths)
    if live(existing):
        print("state=already-running")
        sys.stdout.write(report(existing, paths))
        return 0
    stale = residue(existing)
    if stale:
        # A supervisor killed outright leaves its children holding the ports the
        # next launch binds, so a bind would fail on a listener this appliance
        # itself started. The recorded identities are ended first, which is
        # `stop` over exactly the set the record names rather than a name match
        # over the process table.
        print(f"reaping={','.join(stale)}")
        appliance.stop(paths)
        existing = appliance.status(paths)
    superseded = existing.supervisor_pid if existing is not None else 0
    logs = paths["qwen_home_logs"]
    logs.mkdir(parents=True, exist_ok=True)
    log_path = logs / LOG_NAME
    argv = launch_argv(defaults, python=python)
    owned = supervisor.relaunch_detached(argv, log_path=log_path, cwd=paths.tree)
    print(f"launched pid={owned.pid} log={log_path}")
    return _await_ready(
        paths,
        superseded_pid=superseded,
        log_path=log_path,
        deadline_s=deadline_s,
        poll_s=poll_s,
    )


def _await_ready(
    paths: RuntimePaths,
    *,
    superseded_pid: int,
    log_path: Path,
    deadline_s: float,
    poll_s: float,
) -> int:
    """Watch the record until it reads `ready`, ends, or the deadline passes.

    The detached process spends its interpreter startup and both preflights
    before it publishes anything, so the first reads land on the previous run's
    record; every record still naming `superseded_pid` is that run's and is
    passed over, the discipline `serve._await_ownership` applies to the router's
    own record for the same reason.
    """
    deadline = time.monotonic() + deadline_s
    announced = ""
    while time.monotonic() < deadline:
        record = appliance.status(paths)
        if record is None or record.supervisor_pid == superseded_pid:
            time.sleep(poll_s)
            continue
        # `report` opens on the state it found, so announcing `ready` here
        # would print that line twice for one transition.
        if record.state not in (announced, "ready"):
            announced = record.state
            print(f"state={record.state}")
        if record.state == "ready":
            sys.stdout.write(report(record, paths))
            return 0
        if record.state in _TERMINAL_STATES:
            print(f"primary_failure={record.primary_failure or '-'}", file=sys.stderr)
            sys.stderr.write(log_tail(log_path))
            return 1
        time.sleep(poll_s)
    print(
        f"the detached appliance published no ready record within {deadline_s:.1f} s",
        file=sys.stderr,
    )
    sys.stderr.write(log_tail(log_path))
    return 1


def log_tail(log_path: Path, lines: int = LOG_TAIL_LINES) -> str:
    """The last lines of the launch log, prefixed so they read as quoted output."""
    try:
        content = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return f"{log_path} holds no readable launch log\n"
    return "".join(f"{log_path.name}: {line}\n" for line in content[-lines:])


def down(paths: RuntimePaths, *, grace_s: float | None = None) -> int:
    """Signal every recorded identity and prove each one absent.

    The absence proof is `appliance.stop`, which compares each pid's start time
    before signalling and reports a survivor as restoration residue, so this
    reports what that function found rather than asserting a teardown.
    """
    record = appliance.status(paths)
    if record is None:
        print("appliance=absent")
        return 0
    signalled = appliance.stop(paths) if grace_s is None else appliance.stop(paths, grace_s=grace_s)
    print(f"signalled={','.join(str(pid) for pid in signalled) or '-'}")
    final = appliance.status(paths)
    residue = final.restoration_failures if final is not None else ()
    for detail in residue:
        print(f"residue: {detail}", file=sys.stderr)
    if final is not None and final.state == "stopped" and not residue:
        print("every recorded identity absent")
        return 0
    return 1


def restart(
    paths: RuntimePaths,
    defaults: LaunchDefaults,
    *,
    python: str | None = None,
    deadline_s: float = READINESS_DEADLINE_SECONDS,
    poll_s: float = POLL_SECONDS,
) -> int:
    """Take the appliance down, then bring it up on the same derived defaults.

    A teardown that leaves residue ends the command there: the ports the next
    launch binds are the ones a survivor still holds, so a relaunch over residue
    fails at bind time and reports that instead of the survivor.
    """
    status = down(paths)
    if status != 0:
        return status
    return up(paths, defaults, python=python, deadline_s=deadline_s, poll_s=poll_s)


def surfaces(record: appliance.ApplianceState | None) -> tuple[str, ...]:
    """Every origin the record publishes, in landing, chat, image order."""
    if record is None:
        return ()
    candidates: Sequence[str] = (
        record.gateway_origin,
        record.llama_ui_origin,
        record.image_ui_origin,
    )
    return tuple(origin for origin in candidates if origin and origin != "-")
