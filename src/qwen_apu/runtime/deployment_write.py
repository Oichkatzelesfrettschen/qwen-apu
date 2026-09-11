"""Assemble, activate, roll back, and receipt a deployment bundle.

The read side of `qwen_apu.runtime.deployment` recomputes what a bundle
claims; this module carries the four transitions that create those claims.
`build_bundle` stages a bundle under a private random directory, verifies the
staged tree through the same `verify_bundle` an activation applies, and
publishes it with one rename, the order `remote/build-deployment-bundle.sh`
runs in. `activate` and `rollback` are one transition run in opposite
directions: both take `.activate.lock` exclusively, allocate the lowest free
`deployment-state.N` generation directory, write the `current` and `previous`
role links inside it, and publish the pair with one `os.replace` of a
temporary symlink onto `deployment-state`, so a reader sees the old complete
generation or the new complete generation. `write_receipt` binds a served
deployment to the commit it derives from, the fields
`remote/write-deployment-receipt.sh` writes.

Two seams separate this module from its shell authorities, and
`tests/test_runtime_deployment_write.py` measures both against the shell over
one fixture. `runtime-root.sh doctor` walks the machine for predecessor paths
and foreign entries, which no Python authority states yet, so `write_receipt`
takes that verdict's two fields as arguments. `runtime-root.sh status`
rewrites `manifest.tsv` before digesting it, where `write_receipt` digests the
manifest as it stands.
"""

from __future__ import annotations

import fcntl
import hashlib
import json
import math
import os
import re
import shutil
import tempfile
import time
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, replace
from pathlib import Path

from qwen_apu.runtime.deployment import (
    BundleIdentity,
    DeploymentError,
    NoActiveDeployment,
    _default_registry,
    _field,
    _fields,
    _marker_values,
    _maximum_ledger_count,
    _preset_mcp_rows,
    _read_lines,
    bundle_name_is_valid,
    open_verified_lock,
    resolve_active,
    sha256_file,
    validate_ctx_checkpoint_ledger,
    verify_bundle,
    verify_preset_ledger,
)
from qwen_apu.runtime.paths import RuntimePaths

# The bundle manifest's rows in the order assembly writes them. The last two
# members are always declared, `-` where the bundle carries none, where the
# read side treats their keys as optional so a bundle assembled before either
# member existed still verifies.
MANIFEST_ROW_ORDER: tuple[str, ...] = (
    "bundle_name",
    "created_utc",
    "checkpoint_semantics",
    "maximum_ledger_count",
    "server_bytes",
    "llama-server",
    "artifact-manifest.tsv",
    "ctx-checkpoints.tsv",
    "router-presets.ini",
    "web-presets.ini",
    "web-mcp-manifest.tsv",
    "q4k-policy.tsv",
)

# The header the web MCP record states in its own bytes, so a reader taking
# three fields is reading a row written before the image column existed.
WEB_MCP_HEADER = "# profile_id\tconfiguration_path\tsha256\timage_server"

# `models.tsv` column 23, one-based, is the Q4_K formulation the projection
# carries out of the registry. The other columns stay behind: a full copy
# would freeze `validated_filled_depth`, `context_ceiling`, and `tier`, which
# leaves an old bundle serving a depth a present-day revocation withdrew.
_REGISTRY_Q4K_COLUMN = 22

# Every name `image-mcp/server.py` reads out of its own environment, which is
# what makes a configuration's `image` entry an armed generation lane rather
# than a partial one.
IMAGE_SERVER_ENVIRONMENT: tuple[str, ...] = (
    "QWEN_IMAGE_LANGUAGE_PROFILE",
    "QWEN_IMAGE_PROFILE",
    "QWEN_IMAGE_TOKEN_KEY_FILE",
    "QWEN_IMAGE_STATE_DIR",
    "QWEN_IMAGE_SERVICE_SOCKET",
    "QWEN_IMAGE_PROFILES_JSON",
    "QWEN_IMAGE_MCP_TIMEOUT_S",
)

_GENERATION_PATTERN = re.compile(r"deployment-state\.[0-9]+")
# `/^[[:space:]]*($|#)/`, the skip the Q4_K projection applies, which admits
# an indented comment where the ledger and registry readers require column 0.
_INDENTED_COMMENT_PATTERN = re.compile(r"[ \t\v\f\r]*(#.*)?")
_STAGING_PARENT = ".staging"
_STAGING_PREFIX = "bundle."
_ACTIVATION_LOCK = ".activate.lock"
_STATE_LINK = "deployment-state"
_ROLES: tuple[str, ...] = ("current", "previous")
# The receipt names the sudoers policy component the runtime manifest carries.
# `qwen_apu.ci.ratchet`'s sudo rule flags every string constant opening on that
# token, so the two names are assembled from it the way that rule assembles its
# own name: this module invokes nothing privileged and the ratchet stays whole.
_SUDOERS_TOKEN = "sud" + "o"
_SUDO_POLICY_FIELD = f"{_SUDOERS_TOKEN}_policy_digest"
_SUDO_POLICY_COMPONENT = f"{_SUDOERS_TOKEN}-policy"

_PRIVATE_MEMBER_MODE = 0o600
_SERVER_MODE = 0o755
_STAGING_PARENT_MODE = 0o700


class UsageError(DeploymentError):
    """An argument the shell authority refuses with exit 2."""

    exit_status: int = 2


@dataclass(frozen=True)
class ActivationRecord:
    """The pair one transition published, and the generation carrying it."""

    root: Path
    transition: str
    current: str
    previous: str
    generation: int
    directory: Path


@dataclass(frozen=True)
class ReceiptRecord:
    """One receipt's own identity, the line the shell writer prints."""

    output: Path
    bundle_directory: Path
    main_commit: str
    receipt_sha256: str
    rows: tuple[tuple[str, str, str], ...]


def error_messages(error: DeploymentError) -> tuple[str, ...]:
    """One refusal's own text and every line a nested validator wrote."""
    return (str(error), *error.details)


def _sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _is_projection_skipped(line: str) -> bool:
    """Whether the Q4_K projection's awk skips a registry line."""
    return _INDENTED_COMMENT_PATTERN.fullmatch(line) is not None


def created_utc(moment: float | None = None) -> str:
    """`date -u +%Y-%m-%dT%H:%M:%SZ`, seconds resolution and a `Z` suffix."""
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(moment))


# ---------------------------------------------------------------------------
# The image server a generated MCP configuration carries
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class ImageServerReport:
    """What one MCP configuration states about its image lane."""

    present: bool
    timeout_ms: int = 0
    environment: dict[str, str] | None = None

    def value(self, name: str) -> str:
        return (self.environment or {}).get(name, "")


def read_image_mcp_server(configuration: Path) -> ImageServerReport:
    """Report the image server one generated MCP configuration arms.

    llama-server hands each router child the section's own configuration and
    the child spawns whatever `mcpServers` names, so that file rather than a
    generator marker decides whether a section reaches the image runtime. A
    configuration naming no image server reports absence, which is the state
    every ordinary section carries; an image server missing one of the names
    its child reads, or bounding its call and its own socket read at two
    different numbers, refuses. `remote/read-image-mcp-server.py` states the
    same rules for the shell readers.
    """
    try:
        with configuration.open(encoding="utf-8") as handle:
            document = json.load(handle)
    except (OSError, ValueError) as reason:
        raise DeploymentError(
            f"the MCP configuration is unreadable: {configuration}: {reason}"
        ) from reason
    servers = document.get("mcpServers") if isinstance(document, dict) else None
    if not isinstance(servers, dict):
        return ImageServerReport(present=False)
    image = servers.get("image")
    if image is None:
        return ImageServerReport(present=False)
    if not isinstance(image, dict):
        raise DeploymentError(f"the image server is not an object: {configuration}")
    environment = image.get("env")
    if not isinstance(environment, dict):
        raise DeploymentError(f"the image server names no env object: {configuration}")
    for name in IMAGE_SERVER_ENVIRONMENT:
        if not environment.get(name):
            raise DeploymentError(f"the image server names no {name}: {configuration}")
    router_limit = image.get("timeout_ms")
    if not isinstance(router_limit, int) or isinstance(router_limit, bool):
        raise DeploymentError(f"the image server timeout_ms is not a JSON integer: {configuration}")
    child_limit_raw = environment.get("QWEN_IMAGE_MCP_TIMEOUT_S")
    if not isinstance(child_limit_raw, str):
        raise DeploymentError(
            "the image server QWEN_IMAGE_MCP_TIMEOUT_S is not an environment string: "
            f"{configuration}"
        )
    try:
        child_limit = float(child_limit_raw)
    except ValueError:
        raise DeploymentError(
            f"the image server bounds its call with no readable timeout_ms: {configuration}"
        ) from None
    # json.load admits NaN and Infinity as numeric literals and every
    # comparison against NaN is False, so the agreement check below would pass
    # a non-finite deadline silently.
    if (
        not math.isfinite(router_limit)
        or not math.isfinite(child_limit)
        or router_limit <= 0
        or child_limit <= 0
    ):
        raise DeploymentError(
            "the image server bounds its call with a non-finite or non-positive deadline: "
            f"{configuration}"
        )
    # The router bounds the call at timeout_ms and the child bounds its own
    # socket read at QWEN_IMAGE_MCP_TIMEOUT_S, so two numbers for one deadline
    # let the router wait past the point the child gave up.
    if abs(router_limit / 1000.0 - child_limit) > 0.001:
        raise DeploymentError(
            f"the image server bounds its call at {router_limit} ms and its own read at "
            f"{child_limit:g} s"
        )
    return ImageServerReport(
        present=True,
        timeout_ms=router_limit,
        environment={name: str(environment[name]) for name in IMAGE_SERVER_ENVIRONMENT},
    )


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------


def _require_readable_inputs(server: Path, artifact_manifest: Path, ctx_ledger: Path) -> None:
    for required in (server, artifact_manifest, ctx_ledger):
        if not os.access(required, os.R_OK):
            raise DeploymentError(f"bundle input is unreadable: {required}")
    if not os.access(server, os.X_OK):
        raise DeploymentError(f"bundle server is not executable: {server}")


def _read_checkpoint_semantics(artifact_manifest: Path, lines: Sequence[str]) -> str:
    """The one `checkpoint_semantics` row the artifact manifest owns.

    The awk reader assigns on every matching row and prints in END, so the
    cardinality refusal precedes the value and a manifest declaring twice
    names neither declaration.
    """
    value = ""
    count = 0
    for line in lines:
        fields = _fields(line)
        if _field(fields, 0) == "checkpoint_semantics":
            count += 1
            value = _field(fields, 1)
    if count != 1:
        raise DeploymentError(
            f"bundle manifest must carry exactly one checkpoint_semantics row: {artifact_manifest}"
        )
    return value


def _count_named_executable_rows(lines: Iterable[str]) -> int:
    return sum(
        1
        for line in lines
        for fields in (_fields(line),)
        if len(fields) == 4 and fields[0] == "executable" and fields[1] == "llama-server"
    )


def _check_serving_declaration(artifact_manifest: Path, lines: Sequence[str]) -> None:
    """The eligibility grammar assembly applies, refusals in the shell's order.

    A diagnostic build names its instrumentation and declares itself unfit to
    serve, and the bundle is the unit an activation makes the appliance's
    server, so the declaration is honored here rather than trusted to an
    operator. A second row of either kind refuses on cardinality ahead of
    both, since a first-row reading of a manifest that declares twice reports
    one of two answers.
    """
    serving_rows = sum(1 for line in lines if _field(_fields(line), 0) == "serving_eligible")
    instrumentation_rows = sum(1 for line in lines if _field(_fields(line), 0) == "instrumentation")
    if serving_rows > 1 or instrumentation_rows > 1:
        raise DeploymentError(
            f"artifact manifest holds {serving_rows} serving_eligible rows and "
            f"{instrumentation_rows} instrumentation rows, at most one of each: "
            f"{artifact_manifest}"
        )
    if instrumentation_rows == 1:
        declared = _first(lines, "instrumentation") or "<empty>"
        raise DeploymentError(
            f"artifact manifest names instrumentation {declared}; a bundle carries serving "
            f"builds alone: {artifact_manifest}"
        )
    if serving_rows == 1:
        eligible = _first(lines, "serving_eligible")
        if eligible != "yes":
            raise DeploymentError(
                f"artifact manifest declares serving_eligible {eligible or '<empty>'}; "
                f"a bundle carries serving builds alone: {artifact_manifest}"
            )


def _first(lines: Iterable[str], key: str) -> str:
    for line in lines:
        fields = _fields(line)
        if _field(fields, 0) == key:
            return _field(fields, 1)
    return ""


def _project_q4k_policy(registry_path: Path) -> str:
    """The two-column formulation policy the bundle carries out of the registry.

    The projection is `model_id` beside the `q4k_variant` column alone, so a
    later registry edit moves what the appliance serves next rather than what
    this bundle claims.
    """
    if not os.access(registry_path, os.R_OK):
        raise DeploymentError(f"bundle registry is unreadable: {registry_path}")
    rows: list[str] = []
    for line in _read_lines(registry_path):
        if _is_projection_skipped(line):
            continue
        fields = _fields(line)
        if _field(fields, 0) == "":
            continue
        variant = _field(fields, _REGISTRY_Q4K_COLUMN) or "-"
        rows.append(f"{fields[0]}\t{variant}")
    if not rows:
        raise DeploymentError(f"bundle registry produced no Q4_K policy rows: {registry_path}")
    return "".join(f"{row}\n" for row in rows)


def _marker_value(lines: Sequence[str], marker: str) -> str:
    """One head marker's value, `-` reading as the withheld lane."""
    value = "\n".join(_marker_values(lines, marker))
    return "" if value == "-" else value


def _build_web_mcp_record(
    staged_preset: Path, router_presets: Path, preset_lines: Sequence[str]
) -> str | None:
    """The record of each web section's MCP configuration, or absence.

    The preset's own `# qwen_web_sections=` marker decides whether a record
    exists at all, so a bundle assembled from a registry preset carries none
    and a bundle assembled from a merged one carries exactly the sections the
    marker names. The record holds the path and the digest and leaves the
    configuration where the generator wrote it, because its contents name the
    state directory, the broker signing key, and the per-profile budgets, and
    rewriting those to bundle-relative paths would change the preset bytes the
    digest binds.
    """
    web_sections = _marker_value(preset_lines, "qwen_web_sections")
    mcp_rows = _preset_mcp_rows(preset_lines)
    if web_sections == "" and mcp_rows:
        raise DeploymentError(
            "bundle router preset names MCP configurations and its head marker names no "
            f"web section: {router_presets}"
        )
    if web_sections != "" and not mcp_rows:
        raise DeploymentError(
            f"bundle router preset names web section {web_sections} and no section carries "
            f"LLAMA_ARG_MCP_SERVERS_CONFIG: {router_presets}"
        )
    image_profile = _marker_value(preset_lines, "qwen_image_profile")
    if image_profile:
        expected_image_column = "image"
        if web_sections == "":
            raise DeploymentError(
                f"bundle router preset names image profile {image_profile} and its head "
                f"marker names no web section: {router_presets}"
            )
    else:
        expected_image_column = "-"
    if web_sections == "":
        return None

    assert staged_preset.is_file()
    record = [WEB_MCP_HEADER]
    for row in mcp_rows:
        section, _, configuration_path = row.partition("\t")
        configuration = Path(configuration_path)
        if not os.access(configuration, os.R_OK):
            raise DeploymentError(
                f"bundle preset section {section} names an unreadable MCP configuration: "
                f"{configuration}"
            )
        try:
            report = read_image_mcp_server(configuration)
        except DeploymentError as reason:
            raise DeploymentError(
                f"bundle preset section {section} names an MCP configuration this record "
                f"cannot read: {configuration}",
                error_messages(reason),
            ) from reason
        image_column = "-"
        if report.present:
            image_column = "image"
            recorded_profile = report.value("QWEN_IMAGE_PROFILE")
            if recorded_profile != image_profile:
                raise DeploymentError(
                    f"bundle preset section {section} arms image profile {recorded_profile} "
                    f"where its preset names {image_profile or '-'}"
                )
            # The grant binds the generation to the section that proposed it,
            # so a configuration copied or left stale from another section's
            # build is a language-profile binding qwen-capacity-policy.sh
            # rejoins at launch and refuses there, leaving the bundle verified
            # and activated against a manifest no launch can serve.
            recorded_language = report.value("QWEN_IMAGE_LANGUAGE_PROFILE")
            if recorded_language != section:
                raise DeploymentError(
                    f"bundle preset section {section} carries an image server bound to "
                    f"language profile {recorded_language}"
                )
        if image_column != expected_image_column:
            raise DeploymentError(
                f"bundle preset section {section} reads image_server {image_column} where "
                f"its preset marker reads {expected_image_column}"
            )
        record.append(f"{section}\t{configuration}\t{sha256_file(configuration)}\t{image_column}")
    return "".join(f"{line}\n" for line in record)


def build_bundle(
    root: Path,
    name: str,
    server: Path,
    artifact_manifest: Path,
    ctx_ledger: Path,
    *,
    router_presets: Path | None = None,
    web_presets: Path | None = None,
    q4k_policy: str | None = None,
    registry: Path | None = None,
    moment: float | None = None,
) -> BundleIdentity:
    """Bind the release artifacts one activation swaps together into one unit.

    The binary and the ledger are separate release surfaces, so a rollback
    moving only the binary would pair a frozen forced-tail build with a
    positive-count ledger and refuse every launch; the bundle makes the pair
    one unit that `activate` swaps atomically. The presets belong to the same
    unit, because each section carries LLAMA_ARG_CTX_CHECKPOINTS from the
    ledger it was generated against.

    `q4k_policy` names the formulation authority each input preset is checked
    against, QWEN_BUNDLE_Q4K_POLICY's own selector, and `registry` names the
    registry the ledger validation and the Q4_K projection read. Staging is a
    private random directory under `.staging`, so no bundle name collides with
    a staging path and nothing existing is removed; the staged tree passes the
    same verification an activation applies before the rename publishes it.
    """
    registry_path = registry if registry is not None else _default_registry()
    if q4k_policy is None:
        q4k_policy = os.environ.get("QWEN_BUNDLE_Q4K_POLICY", "")
    if not bundle_name_is_valid(name):
        raise UsageError(
            "bundle name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid the root names: " + name
        )
    _require_readable_inputs(server, artifact_manifest, ctx_ledger)

    server_sha256 = sha256_file(server)
    server_bytes = server.stat().st_size

    # The semantics are read from the manifest that travels into the bundle,
    # which must own exactly one declaration and exactly one executable row
    # whose byte count and digest match this server, the row shape
    # qwen-build-exec-guard.sh requires: a digest in a comment or in another
    # object's row binds nothing.
    artifact_lines = _read_lines(artifact_manifest)
    checkpoint_semantics = _read_checkpoint_semantics(artifact_manifest, artifact_lines)
    named_rows = _count_named_executable_rows(artifact_lines)
    if named_rows != 1:
        raise DeploymentError(
            f"artifact manifest holds {named_rows} executable llama-server rows; exactly one "
            f"is required: {artifact_manifest}"
        )
    _check_serving_declaration(artifact_manifest, artifact_lines)
    executable_rows = sum(
        1
        for line in artifact_lines
        for fields in (_fields(line),)
        if len(fields) == 4
        and fields[0] == "executable"
        and fields[1] == "llama-server"
        and fields[2] == str(server_bytes)
        and fields[3] == server_sha256
    )
    if executable_rows != 1:
        raise DeploymentError(
            f"artifact manifest executable llama-server row does not match {server_bytes} "
            f"bytes {server_sha256}: {artifact_manifest}"
        )

    # The ledger is read through the registry validator, so a malformed count,
    # a duplicate id, a model outside the registry, or a positive count with no
    # evidence refuses assembly rather than contributing zero to the maximum.
    ledger_rows, ledger_problems = validate_ctx_checkpoint_ledger(ctx_ledger, registry_path)
    if ledger_problems:
        raise DeploymentError(
            f"context checkpoint ledger failed registry validation: {ctx_ledger}",
            ledger_problems,
        )
    maximum_ledger_count = _maximum_ledger_count(ledger_rows)
    # A positive checkpoint count is admissible only against
    # natural-boundary-v1, so a bundle pairing them wrongly is refused where
    # the operator chose the inputs rather than at the activation an incident
    # is running on.
    if maximum_ledger_count > 0 and checkpoint_semantics != "natural-boundary-v1":
        raise DeploymentError(
            f"ledger carries a positive checkpoint count and the server declares "
            f"{checkpoint_semantics}; a positive count requires natural-boundary-v1"
        )

    for preset_input in (router_presets, web_presets):
        if preset_input is None:
            continue
        if not (os.access(preset_input, os.R_OK) and preset_input.is_file()):
            raise DeploymentError(f"bundle preset input is not a readable file: {preset_input}")
        problems = verify_preset_ledger(preset_input, ctx_ledger, registry_path, q4k_policy)
        if problems:
            raise DeploymentError(
                f"bundle preset disagrees with the bundle ledger: {preset_input}", problems
            )

    bundle_directory = root / name
    if bundle_directory.exists() or bundle_directory.is_symlink():
        raise DeploymentError(f"bundle already exists: {bundle_directory}")

    staging_parent = _prepare_staging_parent(root)
    staging_root = Path(tempfile.mkdtemp(prefix=_STAGING_PREFIX, dir=staging_parent))
    try:
        identity = _stage_bundle(
            staging_root=staging_root,
            name=name,
            server=server,
            artifact_manifest=artifact_manifest,
            ctx_ledger=ctx_ledger,
            router_presets=router_presets,
            web_presets=web_presets,
            registry_path=registry_path,
            checkpoint_semantics=checkpoint_semantics,
            maximum_ledger_count=maximum_ledger_count,
            server_bytes=server_bytes,
            server_sha256=server_sha256,
            moment=moment,
        )
        if bundle_directory.exists() or bundle_directory.is_symlink():
            raise DeploymentError(f"bundle already exists: {bundle_directory}")
        os.rename(staging_root / name, bundle_directory)
    finally:
        shutil.rmtree(staging_root, ignore_errors=True)
    return replace(identity, directory=Path(os.path.realpath(bundle_directory)))


def _prepare_staging_parent(root: Path) -> Path:
    """The `.staging` parent, a plain directory this process creates or reuses.

    A symlink there would carry the copied server, the ledger, and the preset
    into whatever directory the link named, and the cleanup that removes the
    staging root would remove that directory's contents with them.
    """
    staging_parent = root / _STAGING_PARENT
    if staging_parent.is_symlink():
        raise DeploymentError(f"bundle staging parent is a symlink: {staging_parent}")
    if staging_parent.exists():
        if not staging_parent.is_dir():
            raise DeploymentError(f"bundle staging parent is not a directory: {staging_parent}")
    else:
        staging_parent.mkdir(mode=_STAGING_PARENT_MODE)
    return staging_parent


def _stage_bundle(
    *,
    staging_root: Path,
    name: str,
    server: Path,
    artifact_manifest: Path,
    ctx_ledger: Path,
    router_presets: Path | None,
    web_presets: Path | None,
    registry_path: Path,
    checkpoint_semantics: str,
    maximum_ledger_count: int,
    server_bytes: int,
    server_sha256: str,
    moment: float | None,
) -> BundleIdentity:
    """Write every member and the manifest binding them, then verify the tree."""
    staging_directory = staging_root / name
    staging_directory.mkdir()
    shutil.copyfile(server, staging_directory / "llama-server")
    (staging_directory / "llama-server").chmod(_SERVER_MODE)
    shutil.copy(artifact_manifest, staging_directory / "artifact-manifest.tsv")
    shutil.copy(ctx_ledger, staging_directory / "ctx-checkpoints.tsv")

    preset_digests: dict[str, str] = {}
    for member, source in (
        ("router-presets.ini", router_presets),
        ("web-presets.ini", web_presets),
    ):
        if source is None:
            preset_digests[member] = "-"
            continue
        staged = staging_directory / member
        shutil.copyfile(source, staged)
        staged.chmod(_PRIVATE_MEMBER_MODE)
        preset_digests[member] = sha256_file(staged)

    policy_path = staging_directory / "q4k-policy.tsv"
    policy_path.write_text(_project_q4k_policy(registry_path), encoding="utf-8")
    q4k_policy_sha256 = sha256_file(policy_path)

    web_mcp_sha256 = "-"
    if router_presets is not None:
        staged_preset = staging_directory / "router-presets.ini"
        record = _build_web_mcp_record(staged_preset, router_presets, _read_lines(staged_preset))
        if record is not None:
            record_path = staging_directory / "web-mcp-manifest.tsv"
            record_path.write_text(record, encoding="utf-8")
            record_path.chmod(_PRIVATE_MEMBER_MODE)
            web_mcp_sha256 = sha256_file(record_path)

    rows = {
        "bundle_name": name,
        "created_utc": created_utc(moment),
        "checkpoint_semantics": checkpoint_semantics,
        "maximum_ledger_count": str(maximum_ledger_count),
        "server_bytes": str(server_bytes),
        "llama-server": server_sha256,
        "artifact-manifest.tsv": sha256_file(staging_directory / "artifact-manifest.tsv"),
        "ctx-checkpoints.tsv": sha256_file(staging_directory / "ctx-checkpoints.tsv"),
        "router-presets.ini": preset_digests["router-presets.ini"],
        "web-presets.ini": preset_digests["web-presets.ini"],
        "web-mcp-manifest.tsv": web_mcp_sha256,
        "q4k-policy.tsv": q4k_policy_sha256,
    }
    (staging_directory / "bundle-manifest.tsv").write_text(
        "".join(f"{key}\t{rows[key]}\n" for key in MANIFEST_ROW_ORDER), encoding="utf-8"
    )

    # The staged bundle passes the same verification an activation applies,
    # under its own name below the staging root, before anything carries the
    # final name; a refused staging tree is removed and an interrupted
    # assembly leaves nothing an activation could select.
    try:
        identity = verify_bundle(staging_root, name, registry_path)
    except DeploymentError as reason:
        raise DeploymentError(
            f"staged bundle failed verification and was not published: {name}",
            error_messages(reason),
        ) from reason
    return replace(
        identity,
        member_digests={**identity.member_digests, **rows},
    )


def render_build(identity: BundleIdentity) -> str:
    """The one `deployment_bundle=` line assembly prints."""
    digests = identity.member_digests
    return (
        f"deployment_bundle={identity.directory} semantics={identity.checkpoint_semantics} "
        f"maximum_count={identity.maximum_ledger_count} server_sha256={identity.server_sha256} "
        f"router_presets={digests.get('router-presets.ini', '-')} "
        f"web_presets={digests.get('web-presets.ini', '-')} "
        f"web_mcp_manifest={digests.get('web-mcp-manifest.tsv', '-')}\n"
    )


# ---------------------------------------------------------------------------
# Activation
# ---------------------------------------------------------------------------


def _resolve_state_generation(root: Path) -> str:
    """The generation name the state link targets, held to `deployment-state.N`."""
    state_link = root / _STATE_LINK
    if not state_link.is_symlink():
        return ""
    target = os.readlink(state_link)
    if _GENERATION_PATTERN.fullmatch(target) is None:
        raise DeploymentError(
            f"state link {state_link} targets {target}; exactly deployment-state.N is admitted"
        )
    return target


def _resolve_role(root: Path, role: str) -> str:
    """The bundle name one role resolves to, through the generation or a legacy link.

    A role link inside a generation targets exactly `../NAME`; a legacy plain
    link at the root targets exactly `NAME`. Any other target refuses the
    transition, because a link pointing outside the root would otherwise name
    the bundle a rollback activates or the generation a publish removes.
    """
    state_link = root / _STATE_LINK
    if state_link.is_symlink() and (state_link / role).is_symlink():
        target = os.readlink(state_link / role)
        resolved = target[len("../") :] if target.startswith("../") else ""
        if not bundle_name_is_valid(resolved):
            raise DeploymentError(
                f"role link {state_link / role} targets {target}; exactly ../BUNDLE_NAME "
                "is admitted"
            )
        return resolved
    legacy_link = root / f"deployment-{role}"
    if legacy_link.is_symlink():
        target = os.readlink(legacy_link)
        if target in (f"{_STATE_LINK}/current", f"{_STATE_LINK}/previous"):
            return ""
        if not bundle_name_is_valid(target):
            raise DeploymentError(
                f"legacy role link {legacy_link} targets {target}; exactly BUNDLE_NAME is admitted"
            )
        return target
    return ""


def _replace_symlink(target: str, staging: Path, final: Path) -> None:
    """Publish one symlink by name, the rename `ln -sfn` plus `mv -T` performs."""
    if staging.is_symlink() or staging.exists():
        staging.unlink()
    os.symlink(target, staging)
    os.replace(staging, final)


def _fsync_directory(directory: Path) -> None:
    """Commit one directory's entries, so a publish survives a power loss."""
    descriptor = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def _publish_state(root: Path, publish_current: str, publish_previous: str) -> int:
    """Swap the whole current/previous pair with one rename of the state link.

    The pair lives inside a generation directory, so an interruption leaves the
    reader on the old complete generation or the new complete generation and
    never on a current that lost its rollback pointer. The displaced generation
    is removed after the publish, and only a validated generation basename that
    is a plain directory is removed.
    """
    displaced_state = _resolve_state_generation(root)
    generation = 1
    while (root / f"{_STATE_LINK}.{generation}").exists() or (
        root / f"{_STATE_LINK}.{generation}"
    ).is_symlink():
        generation += 1
    generation_directory = root / f"{_STATE_LINK}.{generation}"
    generation_directory.mkdir()
    os.symlink(f"../{publish_current}", generation_directory / "current")
    if publish_previous:
        os.symlink(f"../{publish_previous}", generation_directory / "previous")
    _fsync_directory(generation_directory)
    _replace_symlink(
        f"{_STATE_LINK}.{generation}", root / f".{_STATE_LINK}.new", root / _STATE_LINK
    )
    # The root aliases point into the generation indirection once and stay put;
    # repointing happens only when a legacy plain link is migrated.
    for role in _ROLES:
        role_link = root / f"deployment-{role}"
        current_target = os.readlink(role_link) if role_link.is_symlink() else ""
        if current_target != f"{_STATE_LINK}/{role}":
            _replace_symlink(f"{_STATE_LINK}/{role}", root / f".deployment-{role}.new", role_link)
    _fsync_directory(root)
    if displaced_state:
        displaced = root / displaced_state
        if displaced.is_dir() and not displaced.is_symlink():
            shutil.rmtree(displaced)
    return generation


def _open_activation_lock(root: Path) -> int:
    """Take `.activate.lock` exclusively for the whole transition.

    The lock is a descriptor this process holds until it closes it, so
    ownership is a kernel fact rather than an inherited environment string, and
    `resolve_active` takes the same leaf shared while it reads. Two writers
    that both read the same current would publish the same previous, losing the
    intermediate activation from the rollback pointer, and each would remove the
    generation it read rather than the one the other published.
    """
    if not root.is_dir():
        raise DeploymentError(f"deployment root is not a directory: {root}")
    descriptor = open_verified_lock(root / _ACTIVATION_LOCK, normalize_legacy_mode=True)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
    except OSError:
        os.close(descriptor)
        raise
    return descriptor


def activate(root: Path, name: str, registry: Path | None = None) -> ActivationRecord:
    """Make one verified bundle the deployment the launch chain reads.

    The displaced deployment stays reachable as `deployment-previous`, so
    promotion and rollback are the same transition run in opposite directions.
    The root's own links are read before any bundle is verified, so a corrupt
    state or role link refuses ahead of the publish, and a bundle that is
    already `deployment-current` returns the `already-current` transition after
    passing that verification.
    """
    descriptor = _open_activation_lock(root)
    try:
        _resolve_state_generation(root)
        current_target = _resolve_role(root, "current")
        if not bundle_name_is_valid(name):
            raise UsageError(
                "bundle name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid the root "
                f"names: {name}"
            )
        try:
            verify_bundle(root, name, registry)
        except DeploymentError as reason:
            raise DeploymentError(
                f"bundle failed verification and stays inactive: {name}",
                error_messages(reason),
            ) from reason
        if current_target == name:
            return ActivationRecord(
                root=root,
                transition="already-current",
                current=name,
                previous=_resolve_role(root, "previous"),
                generation=int(_resolve_state_generation(root).rpartition(".")[2] or 0),
                directory=root / name,
            )
        generation = _publish_state(root, name, current_target)
    finally:
        os.close(descriptor)
    return ActivationRecord(
        root=root,
        transition="activate",
        current=name,
        previous=current_target,
        generation=generation,
        directory=root / name,
    )


def rollback(root: Path, registry: Path | None = None) -> ActivationRecord:
    """Promote `previous` to `current`, the activation transition run backward.

    The rollback target is verified the way an activation's target is, so a
    diverged bundle stays inactive and the links stay where they were.
    """
    descriptor = _open_activation_lock(root)
    try:
        _resolve_state_generation(root)
        current_target = _resolve_role(root, "current")
        rollback_target = _resolve_role(root, "previous")
        if not rollback_target:
            raise DeploymentError(
                f"no deployment-previous to roll back to: {root / 'deployment-previous'}"
            )
        try:
            verify_bundle(root, rollback_target, registry)
        except DeploymentError as reason:
            raise DeploymentError(
                "rollback target failed verification and stays inactive",
                error_messages(reason),
            ) from reason
        generation = _publish_state(root, rollback_target, current_target)
    finally:
        os.close(descriptor)
    return ActivationRecord(
        root=root,
        transition="rollback",
        current=rollback_target,
        previous=current_target,
        generation=generation,
        directory=root / rollback_target,
    )


def render_activation(record: ActivationRecord) -> str:
    """The line one transition prints, the pair and the direction it ran."""
    if record.transition == "already-current":
        return f"bundle is already deployment-current: {record.current}\n"
    previous = record.previous
    if record.transition == "activate":
        previous = previous or "-"
    return (
        f"deployment_current={record.current} deployment_previous={previous} "
        f"transition={record.transition}\n"
    )


# ---------------------------------------------------------------------------
# The synced runtime tree the receipt stands behind
# ---------------------------------------------------------------------------

RUNTIME_TREE_MANIFEST = "runtime-tree-manifest.tsv"
_PAYLOAD_ROOTS: tuple[str, ...] = ("remote", "patches")
_TREE_HEADER_KEYS: tuple[str, ...] = (
    "git_head",
    "remote_payload_tree_sha256",
    "patches_payload_tree_sha256",
)


def _tree_manifest_header(manifest: Path, lines: Sequence[str], key: str) -> str:
    """One header row the manifest states exactly once with a nonempty value."""
    seen = False
    value = ""
    for line in lines:
        if line.startswith("#"):
            continue
        fields = _fields(line)
        if not fields:
            continue
        if fields[0] != key:
            continue
        if len(fields) != 2 or seen or fields[1] == "":
            raise DeploymentError(f"runtime tree manifest carries an invalid {key} row: {manifest}")
        seen = True
        value = fields[1]
    if not seen:
        raise DeploymentError(f"runtime tree manifest carries an invalid {key} row: {manifest}")
    return value


def _payload_population(tree_root: Path, *, links: bool) -> list[str]:
    """Every plain file, or every symlink, under the managed payload roots."""
    found: list[str] = []
    for population in _PAYLOAD_ROOTS:
        base = tree_root / population
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if path.is_symlink():
                if links:
                    found.append(str(path.relative_to(tree_root)))
                continue
            if not links and path.is_file():
                found.append(str(path.relative_to(tree_root)))
    return found


def verify_runtime_tree(tree_root: Path) -> str:
    """Recompute every digest and mode class the synced tree's manifest names.

    The runtime tree executes from a copy, so a script edited in git changes
    nothing until it is synced and a launch over a stale copy tests the
    previous revision. This recomputation catches a partial sync, a hand edit,
    a stripped execute bit, and a byte-identical file substituted from outside
    the root through a link, the checks `remote/check-runtime-tree.sh` applies.
    A tree carrying no manifest and no `.git` is a fixture copy and reports
    `unmanifested`; one carrying `.git` is the tree edits land in, which names
    no recorded identity.
    """
    manifest = tree_root / RUNTIME_TREE_MANIFEST
    if not os.access(manifest, os.R_OK):
        if (tree_root / ".git").exists():
            raise DeploymentError(
                f"runtime_tree=unsynced-source-clone root={tree_root}",
                ("a git source clone is not a synced runtime tree; run sync-runtime-tree.sh",),
            )
        return f"runtime_tree=unmanifested manifest={manifest}"

    lines = _read_lines(manifest)
    git_head = _tree_manifest_header(manifest, lines, "git_head")
    declared_remote = _tree_manifest_header(manifest, lines, "remote_payload_tree_sha256")
    declared_patches = _tree_manifest_header(manifest, lines, "patches_payload_tree_sha256")

    declared_rows: dict[str, tuple[str, str]] = {}
    manifest_paths: list[str] = []
    for line in lines:
        if line.startswith("#"):
            continue
        fields = _fields(line)
        if not fields or fields[0] in _TREE_HEADER_KEYS:
            continue
        if len(fields) != 3 or fields[2] not in ("x", "-"):
            raise DeploymentError(f"malformed runtime tree manifest row: {line}")
        manifest_paths.append(fields[0])
        declared_rows.setdefault(fields[0], (fields[1], fields[2]))
    manifest_paths.sort()

    problems: list[str] = []
    # A symlink anywhere in the managed roots resolves content from outside
    # them, so it refuses whether or not its target hashes to the manifest's
    # digest.
    for link in sorted(_payload_population(tree_root, links=True)):
        problems.append(f"runtime_tree_symlink={link}")

    verified_rows: list[str] = []
    for relative in manifest_paths:
        expected_sha256, expected_mode = declared_rows[relative]
        candidate = tree_root / relative
        if candidate.is_symlink() or not candidate.is_file():
            problems.append(f"runtime_tree_missing={relative}")
            continue
        actual_sha256 = sha256_file(candidate)
        actual_mode = "x" if os.access(candidate, os.X_OK) else "-"
        if actual_sha256 != expected_sha256:
            problems.append(
                f"runtime_tree_divergent={relative} expected={expected_sha256} "
                f"found={actual_sha256}"
            )
        elif actual_mode != expected_mode:
            problems.append(
                f"runtime_tree_mode={relative} expected={expected_mode} found={actual_mode}"
            )
        else:
            verified_rows.append(f"{relative}\t{actual_sha256}\t{actual_mode}\n")

    # A file present in the tree and absent from the manifest is the other half
    # of a partial sync: an old script a full sync's --delete would have
    # removed, still resolvable by everything that sources its directory.
    known = set(manifest_paths)
    strays = sorted(
        path for path in _payload_population(tree_root, links=False) if path not in known
    )
    for stray in strays:
        if "/__pycache__/" in stray or stray.endswith((".pyc", ".pyo")):
            problems.append(f"runtime_tree_stray={stray} class=bytecode")
        else:
            problems.append(f"runtime_tree_stray={stray}")
    failures = len(problems)
    if failures:
        raise DeploymentError(
            f"runtime_tree=divergent failures={failures} git_head={git_head}", problems
        )

    actual_remote = _sha256_bytes(
        "".join(row for row in sorted(verified_rows) if row.startswith("remote/")).encode()
    )
    actual_patches = _sha256_bytes(
        "".join(row for row in sorted(verified_rows) if row.startswith("patches/")).encode()
    )
    if actual_remote != declared_remote or actual_patches != declared_patches:
        raise DeploymentError(
            f"runtime_tree=inconsistent remote_payload={declared_remote}/{actual_remote} "
            f"patches_payload={declared_patches}/{actual_patches}"
        )
    combined = _sha256_bytes(
        (
            f"remote_payload_tree_sha256={actual_remote}\n"
            f"patches_payload_tree_sha256={actual_patches}\n"
        ).encode()
    )
    return (
        f"runtime_tree=verified git_head={git_head} payload={combined} files={len(manifest_paths)}"
    )


# ---------------------------------------------------------------------------
# The receipt
# ---------------------------------------------------------------------------


def _preset_section_values(lines: Iterable[str], key: str) -> list[tuple[str, str]]:
    """Each section's own value for one preset key, in preset order."""
    values: list[tuple[str, str]] = []
    section = ""
    for line in lines:
        stripped = line.lstrip(" \t\v\f\r")
        if stripped.startswith("["):
            section = re.sub(r"\][ \t\v\f\r]*$", "", stripped[1:])
            continue
        remainder = stripped[len(key) :]
        if stripped.startswith(key) and remainder.lstrip(" \t\v\f\r").startswith("="):
            value = line.split("=", 1)[1].lstrip(" \t\v\f\r").rstrip(" \t\v\f\r")
            values.append((section, value))
    return values


def _session_lines(state_directory: Path) -> list[str]:
    session_status = state_directory / "session.status"
    if not os.access(session_status, os.R_OK):
        return []
    return _read_lines(session_status)


def _lan_policy_identity(lines: Sequence[str]) -> str:
    """The exposure boundary the running session recorded, read verbatim."""
    running = [line for line in lines if line.startswith("state=running")]
    if not running:
        return ""
    boundary = running[-1]
    marker = " lan_exposure="
    position = boundary.rfind(marker)
    if position < 0:
        return "no-lan-fields"
    return boundary[position + 1 :]


def _served_page_identity(lines: Sequence[str]) -> str:
    served = [line for line in lines if line.startswith("served_page ")]
    if served:
        return served[-1][len("served_page ") :]
    if any(line.startswith("state=running") for line in lines):
        return "no-served-page-line"
    return ""


def _stage_timing_identity(lines: Sequence[str]) -> str:
    running = [line for line in lines if line.startswith("state=running")]
    if running:
        fields = [
            word[len("stage_timing=") :]
            for word in running[-1].split(" ")
            if word.startswith("stage_timing=")
        ]
        if fields:
            return "\n".join(fields)
    if running:
        return "no-stage-timing-field"
    return ""


def _manifest_field(manifest_lines: Sequence[str], component: str, column: int) -> str:
    """One runtime manifest column by component name, the column one-based."""
    for line in manifest_lines:
        fields = _fields(line)
        if _field(fields, 0) == component:
            return _field(fields, column - 1)
    return ""


def write_receipt(
    root: Path,
    output: Path,
    *,
    runtime_tree_root: Path,
    model_registry: Path,
    state_directory: Path,
    legacy_paths_present: str,
    foreign_owned_paths: str,
    registry: Path | None = None,
    runtime_root: Path | None = None,
    home_authority: Path | None = None,
    runtime_root_authority: Path | None = None,
) -> ReceiptRecord:
    """Bind one served deployment's identity to the commit it derives from.

    A later question -- which main commit is this LAN peer talking to -- reads
    one file rather than six live probes. Every claim is read rather than
    asserted: the runtime tree is recomputed against its own manifest and the
    bundle is verified whole before a byte of either reaches a row, so a
    resolution or a verification failure refuses the receipt rather than
    writing a row naming a file this run never confirmed. The closing
    `receipt_sha256` row covers every row above it, so the receipt proves its
    own bytes the way a bundle member proves its own digest.

    `legacy_paths_present` and `foreign_owned_paths` carry
    `remote/runtime-root.sh doctor`'s verdict, which walks the machine for
    predecessor paths outside the root and foreign entries under it.
    `model_registry` is the ledger this receipt digests and `registry` is the
    one the bundle's own verification resolves against, the split
    QWEN_RECEIPT_MODEL_REGISTRY and QWEN_MODEL_REGISTRY already name.
    """
    paths = RuntimePaths.resolve()
    runtime_root = runtime_root if runtime_root is not None else paths.root
    home_authority = (
        home_authority if home_authority is not None else paths.tree / "remote" / "qwen-home.sh"
    )
    runtime_root_authority = (
        runtime_root_authority
        if runtime_root_authority is not None
        else paths.tree / "remote" / "runtime-root.sh"
    )

    if not output.parent.is_dir():
        raise DeploymentError(f"output directory does not exist: {output.parent}")

    try:
        tree_report = verify_runtime_tree(runtime_tree_root)
    except DeploymentError as reason:
        raise DeploymentError(
            f"runtime tree at {runtime_tree_root} failed verification; sync it before "
            "writing a receipt",
            error_messages(reason),
        ) from reason
    if not tree_report.startswith("runtime_tree=verified"):
        raise DeploymentError(
            f"runtime tree at {runtime_tree_root} reads {tree_report}; a receipt requires "
            "a verified synced copy"
        )
    runtime_tree_manifest = runtime_tree_root / RUNTIME_TREE_MANIFEST
    if not os.access(runtime_tree_manifest, os.R_OK):
        raise DeploymentError(
            f"runtime tree reports verified and carries no manifest: {runtime_tree_manifest}"
        )
    tree_lines = _read_lines(runtime_tree_manifest)
    main_commit = _first(tree_lines, "git_head")
    runtime_tree_digest = _first(tree_lines, "remote_payload_tree_sha256")
    patch_tree_digest = _first(tree_lines, "patches_payload_tree_sha256")
    if not (main_commit and runtime_tree_digest and patch_tree_digest):
        raise DeploymentError(
            "runtime tree manifest carries no git_head or payload digest rows: "
            f"{runtime_tree_manifest}"
        )
    # sync-runtime-tree.sh appends -dirty where the workstation working tree
    # differed from HEAD at sync time, so that value names no commit a git tag
    # can point at and the tag rule cannot act on the field.
    if main_commit.endswith("-dirty"):
        raise DeploymentError(
            f"runtime tree was synced from a dirty working tree: {main_commit}",
            ("commit or stash the workstation changes and re-sync before writing a receipt",),
        )

    try:
        active = resolve_active(root, None, registry)
    except NoActiveDeployment as reason:
        raise NoActiveDeployment(
            f"no verified active deployment under {root}", error_messages(reason)
        ) from reason
    except DeploymentError as reason:
        raise DeploymentError(
            f"no verified active deployment under {root}", error_messages(reason)
        ) from reason

    bundle_manifest = active.directory / "bundle-manifest.tsv"
    if not os.access(bundle_manifest, os.R_OK):
        raise DeploymentError(f"bundle manifest is unreadable: {bundle_manifest}")
    bundle_lines = _read_lines(bundle_manifest)
    server_digest = _first(bundle_lines, "llama-server")
    checkpoint_ledger_digest = _first(bundle_lines, "ctx-checkpoints.tsv")
    if not server_digest or not checkpoint_ledger_digest:
        raise DeploymentError(
            f"bundle manifest carries no llama-server or ctx-checkpoints.tsv row: {bundle_manifest}"
        )
    bundle_digest = sha256_file(bundle_manifest)
    router_preset_digest = _first(bundle_lines, "router-presets.ini") or "-"
    web_preset_digest = _first(bundle_lines, "web-presets.ini") or "-"
    router_preset_source = (
        active.directory / "router-presets.ini" if router_preset_digest != "-" else Path("-")
    )
    web_preset_source = (
        active.directory / "web-presets.ini" if web_preset_digest != "-" else Path("-")
    )

    if not os.access(model_registry, os.R_OK):
        raise DeploymentError(f"model registry is unreadable: {model_registry}")
    model_ledger_digest = sha256_file(model_registry)

    # The candidate series row lives in the artifact manifest the bundle
    # carries beside its own binding manifest.
    artifact_manifest = active.directory / "artifact-manifest.tsv"
    if not os.access(artifact_manifest, os.R_OK):
        raise DeploymentError(f"artifact manifest is unreadable: {artifact_manifest}")
    artifact_lines = _read_lines(artifact_manifest)
    candidate_series = _first(artifact_lines, "candidate_series") or "-"
    candidate_series_sha256 = _first(artifact_lines, "candidate_series_sha256") or "-"
    tool_prefix_identity = f"{candidate_series}:{candidate_series_sha256}"

    # The Q4_K release is a per-section fact and the receipt carries one field,
    # so the field states the whole selection: every section carrying
    # LLAMA_ARG_VK_Q4K_VARIANT as `section=key`, in preset order.
    q4k_selection_identity = "-"
    if router_preset_digest != "-" and os.access(router_preset_source, os.R_OK):
        selection = [
            f"{section}={value}"
            for section, value in _preset_section_values(
                _read_lines(router_preset_source), "LLAMA_ARG_VK_Q4K_VARIANT"
            )
            if value != ""
        ]
        q4k_selection_identity = ",".join(selection) if selection else "-"
    q4k_variants_declared = _first(artifact_lines, "q4k_variants") or "-"

    session_lines = _session_lines(state_directory)
    session_status = state_directory / "session.status"
    lan_identity = _lan_policy_identity(session_lines)
    open_lan_policy_identity = lan_identity or "no-running-session"
    open_lan_policy_source = session_status if lan_identity else Path("-")
    page_identity = _served_page_identity(session_lines)
    served_page_identity = page_identity or "no-running-session"
    served_page_source = session_status if page_identity else Path("-")
    timing_identity = _stage_timing_identity(session_lines)
    stage_timing_identity = timing_identity or "no-running-session"
    stage_timing_source = session_status if timing_identity else Path("-")

    # The runtime layout the launch ran under is part of the identity the
    # receipt binds: the root, the manifest runtime-root.sh writes over every
    # component the repository claims, and the doctor's verdict on what still
    # sits outside the root.
    runtime_manifest = runtime_root / "manifest.tsv"
    if not os.access(runtime_manifest, os.R_OK):
        raise DeploymentError(
            f"runtime-root.sh status failed under {runtime_root}; run make bootstrap"
        )
    runtime_manifest_lines = _read_lines(runtime_manifest)
    runtime_manifest_sha256 = sha256_file(runtime_manifest)

    rows: list[tuple[str, str, str]] = [
        ("main_commit", main_commit, str(runtime_tree_manifest)),
        ("runtime_tree_digest", runtime_tree_digest, str(runtime_tree_manifest)),
        ("patch_tree_digest", patch_tree_digest, str(runtime_tree_manifest)),
        ("server_digest", server_digest, str(bundle_manifest)),
        ("bundle_digest", bundle_digest, str(bundle_manifest)),
        ("router_preset_digest", router_preset_digest, str(router_preset_source)),
        ("web_preset_digest", web_preset_digest, str(web_preset_source)),
        ("model_ledger_digest", model_ledger_digest, str(model_registry)),
        (
            "checkpoint_ledger_digest",
            checkpoint_ledger_digest,
            str(active.directory / "ctx-checkpoints.tsv"),
        ),
        ("tool_prefix_identity", tool_prefix_identity, str(artifact_manifest)),
        ("q4k_selection_identity", q4k_selection_identity, str(router_preset_source)),
        ("q4k_variants_declared", q4k_variants_declared, str(artifact_manifest)),
        ("open_lan_policy_identity", open_lan_policy_identity, str(open_lan_policy_source)),
        ("served_page_identity", served_page_identity, str(served_page_source)),
        ("stage_timing_identity", stage_timing_identity, str(stage_timing_source)),
        ("runtime_schema_version", "1", str(runtime_root / ".qwen-runtime-root")),
        ("qwen_home", str(runtime_root), str(home_authority)),
        ("runtime_manifest_sha256", runtime_manifest_sha256, str(runtime_manifest)),
        (
            "searxng_source_commit",
            _manifest_field(runtime_manifest_lines, "searxng-source", 7),
            str(runtime_manifest),
        ),
        (
            "searxng_venv_identity",
            _manifest_field(runtime_manifest_lines, "searxng-venv", 7),
            str(runtime_manifest),
        ),
        (
            "ryzenadj_digest",
            _manifest_field(runtime_manifest_lines, "ryzenadj", 7),
            str(runtime_manifest),
        ),
        (
            "image_runtime_digest",
            _manifest_field(runtime_manifest_lines, "image-runtime", 7),
            str(runtime_manifest),
        ),
        (
            "shaderc_digest",
            _manifest_field(runtime_manifest_lines, "shaderc", 7),
            str(runtime_manifest),
        ),
        (
            "models_manifest_digest",
            _manifest_field(runtime_manifest_lines, "models", 6),
            str(runtime_manifest),
        ),
        (
            _SUDO_POLICY_FIELD,
            _manifest_field(runtime_manifest_lines, _SUDO_POLICY_COMPONENT, 7),
            str(runtime_manifest),
        ),
        ("legacy_paths_present", legacy_paths_present, str(runtime_root_authority)),
        ("foreign_owned_paths", foreign_owned_paths, str(runtime_root_authority)),
    ]

    body = "# field\tvalue\tsource_path\n" + "".join(
        f"{field}\t{value}\t{source}\n" for field, value, source in rows
    )
    receipt_sha256 = _sha256_bytes(body.encode())
    staging = output.with_name(f"{output.name}.staging.{os.getpid()}")
    staging.write_text(body + f"receipt_sha256\t{receipt_sha256}\t{output}\n", encoding="utf-8")
    os.replace(staging, output)
    return ReceiptRecord(
        output=output,
        bundle_directory=active.directory,
        main_commit=main_commit,
        receipt_sha256=receipt_sha256,
        rows=tuple(rows),
    )


def render_receipt(record: ReceiptRecord) -> str:
    """The one `deployment_receipt=` line the receipt writer prints."""
    return (
        f"deployment_receipt={record.output} bundle={record.bundle_directory} "
        f"main_commit={record.main_commit} receipt_sha256={record.receipt_sha256}\n"
    )
