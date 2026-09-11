"""Host and Vulkan headroom, the report remote/model-memory-preflight.sh prints.

The report observes and admits: it states the model's byte count, the host
memory `MemAvailable` leaves, the Vulkan budget the memory-budget probe
reports, and whether each side clears its requirement, then ends on
`model_memory_preflight=observe` whatever those two answers are. That
admission is a measured correction rather than a default. An earlier
arithmetic charged the weights twice -- once as `required_vulkan_bytes`,
which already covers the resident copy an APU carves from system RAM, and
again as `model_bytes` -- and refused Qwen3.8-9B on the doubled figure while
reading as a hardware limit. A live server holding 2.74 GB of weights measures
229 MB resident and no swap, so the file reaches those buffers through a
reclaimable mapping `MemAvailable` already counts. The load itself is the
honest test, and a load that exceeds the machine fails at once and names its
reason.

`build_report` is the arithmetic and the wording; it reads a probe transcript
and a `/proc/meminfo` path a caller names, so a test drives it over fixtures.
`probe_vulkan_budget` is the half that reaches the machine: it compiles
`remote/vulkan-memory-budget-probe.c` with the distribution `cc` and runs the
result under the RADV ICD, the way the shell does, and requires the RAVEN2
device name the appliance is measured on.

Environment variables this module reads, under the shell's own names:

    QWEN_RADV_ICD    ICD manifest the probe runs under, default
                     /usr/share/vulkan/icd.d/radeon_icd.x86_64.json
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import stat
import subprocess
import tempfile
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path

from qwen_apu.config.models import load_model_artifacts, model_by_id
from qwen_apu.install.models import model_plan
from qwen_apu.runtime.deployment import ActiveDeployment, DeploymentError, resolve_active
from qwen_apu.runtime.environment import radv_icd
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.tools.approvals import signing_key_digest
from qwen_apu.tools.ledger import ToolError

DIGEST_CHUNK_BYTES = 1 << 20
MIB_BYTES = 1048576
DEFAULT_DESKTOP_RESERVE_MIB = 4096
DEFAULT_VULKAN_MARGIN_MIB = 512
RAVEN2_DEVICE_LINE = "device_name=AMD Radeon Graphics (RADV RAVEN2)"

DEFAULT_MEMINFO = Path("/proc/meminfo")  # appliance-path: named

_PROBE_SOURCE = "vulkan-memory-budget-probe.c"
_PROBE_COMPILER_FLAGS: tuple[str, ...] = (
    "-std=c11",
    "-O2",
    "-Wall",
    "-Wextra",
    "-Wpedantic",
    "-Werror",
)


class PreflightError(RuntimeError):
    """A refusal remote/model-memory-preflight.sh prints instead of a report.

    `status` carries the exit code the shell leaves: 2 for an argument the
    usage block rejects and 1 for a probe that answers without the aggregate.
    """

    def __init__(self, message: str, status: int = 2) -> None:
        super().__init__(message)
        self.status = status


@dataclass(frozen=True, slots=True)
class PreflightReport:
    """The eleven lines the shell prints after the probe transcript.

    `host_headroom` and `vulkan_headroom` are `ample` or `short`, and the
    signed `*_surplus_bytes` field beside each carries the surplus on `ample`
    and the shortfall on `short`, which is the one number the shell prints
    under two names.
    """

    probe_output: str
    model_bytes: int
    mem_available_bytes: int
    required_host_bytes: int
    desktop_reserve_bytes: int
    required_vulkan_bytes: int
    vulkan_margin_bytes: int
    required_vulkan_with_margin_bytes: int
    swap_used_bytes: int
    aggregate_available_bytes: int
    host_headroom: str
    host_surplus_bytes: int
    vulkan_headroom: str
    vulkan_surplus_bytes: int

    def render(self) -> str:
        """The shell's own stdout, probe transcript first and `observe` last."""
        lines = [self.probe_output.rstrip("\n")]
        lines.extend(
            f"{name}={value}"
            for name, value in (
                ("model_bytes", self.model_bytes),
                ("mem_available_bytes", self.mem_available_bytes),
                ("required_host_bytes", self.required_host_bytes),
                ("desktop_reserve_bytes", self.desktop_reserve_bytes),
                ("required_vulkan_bytes", self.required_vulkan_bytes),
                ("vulkan_margin_bytes", self.vulkan_margin_bytes),
                ("required_vulkan_with_margin_bytes", self.required_vulkan_with_margin_bytes),
                ("swap_used_bytes", self.swap_used_bytes),
            )
        )
        for name, state, amount in (
            ("host_memory_headroom", self.host_headroom, self.host_surplus_bytes),
            ("vulkan_budget_headroom", self.vulkan_headroom, self.vulkan_surplus_bytes),
        ):
            field = "surplus_bytes" if state == "ample" else "shortfall_bytes"
            lines.append(f"{name}={state} {field}={abs(amount)}")
        lines.append("model_memory_preflight=observe")
        return "\n".join(lines) + "\n"


def _require_mib_arguments(required: str, reserve: str, margin: str) -> tuple[int, int, int]:
    """The shell's one `case` over the three values joined by colons.

    `*[!0-9:]*` refuses any character outside the digits and the separator,
    `:*` refuses an empty first value, and `*::*` refuses an empty middle one;
    an empty third value passes that glob and fails the conversion here, which
    is the one place the port states a rule the shell leaves to arithmetic.
    """
    joined = f"{required}:{reserve}:{margin}"
    malformed = (
        any(character not in "0123456789:" for character in joined)
        or joined.startswith(":")
        or "::" in joined
        or joined.endswith(":")
    )
    if malformed:
        raise PreflightError("memory arguments must be non-negative integer MiB values")
    return int(required), int(reserve), int(margin)


def read_meminfo(path: Path | str = DEFAULT_MEMINFO) -> dict[str, int]:
    """Every `/proc/meminfo` row as kibibytes, keyed without the trailing colon."""
    values: dict[str, int] = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[0].endswith(":") and fields[1].isdigit():
            values[fields[0][:-1]] = int(fields[1])
    return values


def probe_aggregate_available_bytes(probe_output: str) -> int:
    """The probe's `aggregate_available_bytes`, refused where it answers without one."""
    match = re.search(r"^aggregate_available_bytes=([0-9]+)$", probe_output, re.MULTILINE)
    if match is None:
        raise PreflightError("Vulkan budget probe did not report aggregate availability", status=1)
    return int(match.group(1))


def probe_vulkan_budget(
    script_directory: Path | str,
    ambient: Mapping[str, str],
    *,
    compiler: str | None = None,
) -> str:
    """Compile and run the memory-budget probe, requiring the RAVEN2 device name.

    The probe runs with `DISPLAY` and `WAYLAND_DISPLAY` cleared and both ICD
    names pointing at the RADV manifest, which is the environment the shell
    builds for it with `env`.
    """
    source = Path(script_directory) / _PROBE_SOURCE
    executable = compiler or shutil.which("cc")
    if executable is None:
        raise PreflightError("no C compiler is available to build the Vulkan budget probe")
    icd = radv_icd(ambient)
    with tempfile.TemporaryDirectory() as workspace:
        binary = Path(workspace) / "vulkan-memory-budget-probe"
        build: Sequence[str] = [
            executable,
            *_PROBE_COMPILER_FLAGS,
            str(source),
            "-lvulkan",
            "-o",
            str(binary),
        ]
        subprocess.run(build, check=True)
        probe_environment = {
            "DISPLAY": "",
            "WAYLAND_DISPLAY": "",
            "VK_DRIVER_FILES": icd,
            "VK_ICD_FILENAMES": icd,
        }
        completed = subprocess.run(
            [str(binary)], check=True, capture_output=True, text=True, env=probe_environment
        )
    output = completed.stdout
    if RAVEN2_DEVICE_LINE not in output.splitlines():
        raise PreflightError(
            f"Vulkan budget probe reports a device other than {RAVEN2_DEVICE_LINE}"
        )
    return output


def build_report(
    model_path: Path | str,
    required_vulkan_mib: str | int,
    desktop_reserve_mib: str | int = DEFAULT_DESKTOP_RESERVE_MIB,
    vulkan_margin_mib: str | int = DEFAULT_VULKAN_MARGIN_MIB,
    *,
    probe_output: str,
    meminfo_path: Path | str = DEFAULT_MEMINFO,
) -> PreflightReport:
    """The whole report, over a probe transcript and a `/proc/meminfo` the caller names."""
    required_mib, reserve_mib, margin_mib = _require_mib_arguments(
        str(required_vulkan_mib), str(desktop_reserve_mib), str(vulkan_margin_mib)
    )
    model = Path(model_path)
    if not model.is_file():
        raise PreflightError(f"model is not a regular file: {model}")

    aggregate_available_bytes = probe_aggregate_available_bytes(probe_output)
    meminfo = read_meminfo(meminfo_path)
    for name in ("MemAvailable", "SwapTotal", "SwapFree"):
        if name not in meminfo:
            raise PreflightError(f"{meminfo_path} carries no {name} row", status=1)

    required_vulkan_bytes = required_mib * MIB_BYTES
    desktop_reserve_bytes = reserve_mib * MIB_BYTES
    vulkan_margin_bytes = margin_mib * MIB_BYTES
    mem_available_bytes = meminfo["MemAvailable"] * 1024
    # The Vulkan heap on an APU is carved from system RAM, so
    # required_vulkan_bytes already covers the resident weights and the file
    # reaches those buffers through a mapping MemAvailable counts.
    required_host_bytes = required_vulkan_bytes + desktop_reserve_bytes
    required_vulkan_with_margin_bytes = required_vulkan_bytes + vulkan_margin_bytes
    swap_used_bytes = (meminfo["SwapTotal"] - meminfo["SwapFree"]) * 1024

    host_surplus = mem_available_bytes - required_host_bytes
    vulkan_surplus = aggregate_available_bytes - required_vulkan_with_margin_bytes
    return PreflightReport(
        probe_output=probe_output,
        model_bytes=model.stat().st_size,
        mem_available_bytes=mem_available_bytes,
        required_host_bytes=required_host_bytes,
        desktop_reserve_bytes=desktop_reserve_bytes,
        required_vulkan_bytes=required_vulkan_bytes,
        vulkan_margin_bytes=vulkan_margin_bytes,
        required_vulkan_with_margin_bytes=required_vulkan_with_margin_bytes,
        swap_used_bytes=swap_used_bytes,
        aggregate_available_bytes=aggregate_available_bytes,
        host_headroom="short" if host_surplus < 0 else "ample",
        host_surplus_bytes=host_surplus,
        vulkan_headroom="short" if vulkan_surplus < 0 else "ample",
        vulkan_surplus_bytes=vulkan_surplus,
    )


# ---------------------------------------------------------------------------
# The three refusals that precede a child: weights, signing key, deployment
# ---------------------------------------------------------------------------
#
# Four windows of the shadow pass ended on the command side, and each one names
# a precondition the launch assumed rather than reported: the checkpoint linked
# under a directory the root does not resolve, the signing key absent, the
# signing key random bytes where the reader requires UTF-8 text, and prompts
# sent into a server that had not loaded. The first three are decidable before
# a process starts, so they refuse here, by name, with nothing written.


class ModelRefused(PreflightError):
    """The registry, the runtime root, or the artifact ledger refuses the weights."""

    def __init__(self, message: str) -> None:
        super().__init__(message, status=1)


class SigningKeyRefused(PreflightError):
    """The web token signing key fails a rule the approvals reader applies."""

    def __init__(self, message: str) -> None:
        super().__init__(message, status=1)


class DeploymentRefused(PreflightError):
    """The activated bundle is absent, incomplete, or fails its own verification."""

    def __init__(self, message: str, details: Sequence[str] = ()) -> None:
        super().__init__(message, status=1)
        self.details: tuple[str, ...] = tuple(details)


@dataclass(frozen=True, slots=True)
class ModelPreflight:
    """One checkpoint resolved from the typed registry and measured on disk.

    `digest_state` is `verified` where remote/model-artifacts.tsv pins the row
    and the file's bytes and SHA-256 both match, and `unrecorded` where the
    ledger carries no pin for it. A derived checkpoint the appliance quantizes
    itself has no publisher digest to compare against, so its absence is a
    recorded skip rather than a refusal; a pin that exists and disagrees is a
    refusal, because those are the bytes a measurement would have been read
    against.
    """

    model_id: str
    path: Path
    bytes: int
    digest_state: str
    expected_sha256: str | None

    def render(self) -> str:
        return (
            f"model_preflight id={self.model_id} path={self.path} bytes={self.bytes} "
            f"digest={self.digest_state}"
        )


@dataclass(frozen=True, slots=True)
class SigningKeyPreflight:
    """The signing key's identity, which is the digest the broker's health reports."""

    path: Path
    sha256: str
    mode: int

    def render(self) -> str:
        return f"signing_key_preflight path={self.path} mode={self.mode:04o} sha256={self.sha256}"


def resolve_model(
    paths: RuntimePaths,
    model_id: str,
    *,
    model_root: Path | None = None,
    models_path: Path | None = None,
    artifacts_path: Path | None = None,
) -> ModelPreflight:
    """Resolve one registry id to a file under the runtime root and check its pin.

    The path comes from `qwen_apu.install.models`, which is the one authority
    that turns a registry row and its artifact pin into an install destination,
    so a launch reads the same leaf a fetch wrote rather than a second
    composition of publisher directory and filename. The resolved file is then
    required to sit inside the model root, because a path that escapes it is a
    checkpoint no `make install-models` placed and no ledger measured.
    """
    try:
        row = model_by_id(model_id, models_path)
    except (KeyError, ValueError, RuntimeError) as error:
        raise ModelRefused(f"no registry row for model {model_id}: {error}") from None
    root = model_root or paths["qwen_home_models"]
    artifacts = {entry.model_id: entry for entry in load_model_artifacts(artifacts_path)}
    try:
        plan = model_plan(row, artifacts, root)
    except RuntimeError as error:
        raise ModelRefused(str(error)) from None

    destination = plan.destination
    if not destination.is_file():
        raise ModelRefused(f"model {model_id} is not installed at {destination}")
    try:
        resolved_root = root.resolve(strict=True)
        resolved_model = destination.resolve(strict=True)
        resolved_model.relative_to(resolved_root)
    except (OSError, ValueError) as error:
        raise ModelRefused(
            f"model {model_id} resolves outside the runtime root's model store: {error}"
        ) from None

    measured_bytes = destination.stat().st_size
    if plan.expected_sha256 is None or plan.expected_bytes is None:
        return ModelPreflight(model_id, destination, measured_bytes, "unrecorded", None)
    if measured_bytes != plan.expected_bytes:
        raise ModelRefused(
            f"model {model_id} holds {measured_bytes} bytes against the ledger's "
            f"{plan.expected_bytes}: {destination}"
        )
    measured = _sha256_file(destination)
    if measured != plan.expected_sha256:
        raise ModelRefused(
            f"model {model_id} digests {measured} against the ledger's "
            f"{plan.expected_sha256}: {destination}"
        )
    return ModelPreflight(model_id, destination, measured_bytes, "verified", plan.expected_sha256)


def verify_signing_key(path: Path | str) -> SigningKeyPreflight:
    """Apply the approvals reader's own rules to the key file, ahead of a grant.

    `qwen_apu.tools.approvals.signing_key_digest` is the rule set, and calling
    it is what keeps this check equal to the one a grant meets rather than a
    second spelling of it: a regular file this user owns, no group or other
    permission bit, nonempty, and UTF-8 text after the strip the HMAC key is
    taken from. Hexadecimal is not among the rules, which one shadow window
    established from the other side by supplying random bytes and meeting the
    UTF-8 refusal.
    """
    try:
        digest = signing_key_digest(path)
    except ToolError as error:
        raise SigningKeyRefused(f"{error}: {path}") from None
    mode = stat.S_IMODE(os.stat(path).st_mode)
    return SigningKeyPreflight(Path(path), digest, mode)


def verify_deployment(
    deployment_root: Path, *, registry_path: Path | None = None
) -> ActiveDeployment:
    """Resolve and verify the activated bundle, and require every member it names.

    `resolve_active` takes the activation lock shared and verifies the bundle
    whole, so a launch that passes here holds a bundle whose manifest, ledger,
    and server digests were checked under the lock. The member check that
    follows names which file an incomplete bundle is missing, since the bundle
    verification reports the contract and a caller acts on the path.
    """
    try:
        active = resolve_active(deployment_root, registry_path=registry_path)
    except DeploymentError as error:
        raise DeploymentRefused(str(error), error.details) from None
    missing = [
        str(member)
        for member in (active.server, active.ledger, active.manifest)
        if not member.is_file()
    ]
    if missing:
        raise DeploymentRefused(f"deployment {active.name} is incomplete: {', '.join(missing)}")
    if not os.access(active.server, os.X_OK):
        raise DeploymentRefused(
            f"deployment {active.name} server is not executable: {active.server}"
        )
    return active


def _sha256_file(path: Path) -> str:
    """The SHA-256 of one file, streamed so a 5 GiB checkpoint holds no buffer."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            chunk = stream.read(DIGEST_CHUNK_BYTES)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()
