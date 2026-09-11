"""One immutable application deployment: the page, the package, and the references.

A native deployment bundle binds `llama-server` to the ledger and presets its
argv was validated against, and `docs/handoff/application-deployment-20260911.md`
records what that leaves out: the same executable serves a different application
when the static page, the control-plane package, the dependency lock, the
conversation schema, or any registry ledger changes. This module builds the unit
that carries all of them at once, under `deployments/applications/<name>/`.

Four members are payload the directory holds, so a verification re-digests them
from the bytes on disk:

    lib/qwen_apu-<version>-py3-none-any.whl   the package, built here
    lib/requirements.lock                     the hash-locked dependencies
    static/                                   the served page, file by file
    config/                                   the typed TOML the loaders read

Everything else is a reference. The native engine store is content addressed at
`opt/<engine>/<digest>/`, and `install/native.py` already seals every
executable's size, digest, `PT_INTERP`, `DT_NEEDED`, and glibc requirement under
`manifest_sha256`; a reference therefore records the store path together with
that sealed digest, and a verification compares the store's own manifest against
it rather than re-hashing binaries. The model store is referenced the same way,
through the registry ids the activated router preset names beside the byte count
and publisher digest `remote/model-artifacts.tsv` pins, so verifying an
application costs a directory read rather than a multi-gigabyte rehash. The
boundary is exactly this: a payload member is re-digested, a reference is
resolved and compared against the identity its own authority sealed.

The wheel is written with `zipfile` alone under PEP 427 -- `METADATA`, `WHEEL`,
`entry_points.txt`, and `RECORD` in `qwen_apu-<version>.dist-info/` -- because a
build backend would put a third-party dependency between a checkout and its own
deployable form. Every member is stored sorted, uncompressed, at one fixed
timestamp and one fixed mode, so two builds from one commit produce one digest
on any host. Deflate is what the uncompressed store replaces: zlib 1.3 on the
appliance re-encodes bytes the workstation wrote to a different stream with
identical content, so a deflated wheel would carry one digest per host and the
manifest would name the machine that built it rather than the commit it came
from.

Immutability is the refusal: a build whose name already exists refuses before
anything is written, the tree is assembled under a private staging directory,
and one `os.rename` publishes it whole.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import tomllib
import zipfile
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path

from qwen_apu import __version__
from qwen_apu.config import models as registry
from qwen_apu.install import native
from qwen_apu.runtime import deployment
from qwen_apu.runtime.deployment import DeploymentError, sha256_file
from qwen_apu.runtime.deployment_write import created_utc
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.policy import preset_sections
from qwen_apu.tools.document_worker import RECORD_SCHEMA, WORKER_VERSION
from qwen_apu.web.app import (
    REQUEST_BODY_BYTE_CAP,
    REQUEST_DEADLINE_SECONDS,
    content_security_policy,
)
from qwen_apu.web.auth import PAIRING_ATTEMPT_LIMIT, SESSION_COOKIE
from qwen_apu.web.history import MIGRATIONS, SCHEMA_VERSION
from qwen_apu.web.roster import PICKER_TIERS

APPLICATIONS_DIRECTORY = "applications"
MANIFEST_NAME = "application-manifest.json"
MANIFEST_SCHEMA = 1
LIBRARY_DIRECTORY = "lib"
STATIC_DIRECTORY = "static"
CONFIG_DIRECTORY = "config"
LOCK_NAME = "requirements.lock"

_STAGING_PARENT = ".staging"
_STAGING_PREFIX = "application."
_MEMBER_MODE = 0o444
_DIRECTORY_MODE = 0o755
_STAGING_PARENT_MODE = 0o700
_ABSENT = "-"

# PEP 427 stores a DOS timestamp, whose epoch is 1980; this is the earliest
# value a zip member can carry and it is the same value on every host.
WHEEL_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
_WHEEL_TAG = "py3-none-any"

# Every ledger a launch resolves an identity through. A row that moves in any
# of them changes what the appliance serves under one unchanged executable,
# which is what makes each one a member of the application's identity.
REGISTRY_LEDGERS: tuple[str, ...] = (
    "remote/models.tsv",
    "remote/model-artifacts.tsv",
    "remote/ctx-checkpoints.tsv",
    "remote/validated-tuples.tsv",
    "remote/draft-pairs.tsv",
    "remote/quarantine.tsv",
    "remote/web-profiles.tsv",
    "remote/feature-claims.tsv",
    "remote/image-models.tsv",
    "remote/image-profiles.tsv",
    "remote/image-artifacts.tsv",
    "remote/image-quarantine.tsv",
    "remote/llama-patch-series.tsv",
)

# The formats `tools/document_worker.py` extracts without a third-party import,
# beside the one that needs the pinned wheel. An extractor identity is what a
# citation's boundary vocabulary was produced by, so the manifest names both.
_STDLIB_EXTRACTORS: tuple[str, ...] = (
    "text",
    "markdown",
    "html",
    "csv",
    "tsv",
    "json",
    "docx",
    "xlsx",
    "pptx",
)
_PINNED_EXTRACTORS: tuple[str, ...] = ("pdf",)


class ApplicationRefused(RuntimeError):
    """A build or a verification that refuses, naming the member that refused it."""

    def __init__(self, message: str, details: Sequence[str] = ()) -> None:
        super().__init__(message)
        self.details: tuple[str, ...] = tuple(details)


@dataclass(frozen=True, slots=True)
class ApplicationIdentity:
    """One built application: where it lives and what seals it."""

    directory: Path
    name: str
    manifest_sha256: str
    source_commit: str
    wheel_sha256: str
    static_tree_sha256: str

    def render(self) -> str:
        return (
            f"application_deployment={self.directory} manifest_sha256={self.manifest_sha256} "
            f"source_commit={self.source_commit} wheel_sha256={self.wheel_sha256} "
            f"static_tree_sha256={self.static_tree_sha256}\n"
        )


@dataclass(frozen=True, slots=True)
class ApplicationVerification:
    """What one verification recomputed, and every disagreement it found."""

    directory: Path
    name: str
    manifest_sha256: str
    checked: tuple[str, ...] = ()
    mismatches: tuple[str, ...] = field(default=())

    @property
    def verified(self) -> bool:
        return not self.mismatches

    def render(self) -> str:
        lines = [
            f"application_verify={self.directory} manifest_sha256={self.manifest_sha256} "
            f"checked={len(self.checked)} "
            f"result={'verified' if self.verified else 'refused'}"
        ]
        lines.extend(f"mismatch\t{detail}" for detail in self.mismatches)
        return "".join(f"{line}\n" for line in lines)


# ---------------------------------------------------------------------------
# The wheel
# ---------------------------------------------------------------------------


def _record_digest(payload: bytes) -> str:
    """PEP 376's RECORD digest: urlsafe base64 of the SHA-256, padding stripped."""
    raw = hashlib.sha256(payload).digest()
    return "sha256=" + base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _project_metadata(tree: Path) -> Mapping[str, object]:
    """The `[project]` table, read from pyproject so the wheel states one source."""
    payload = (tree / "pyproject.toml").read_bytes()
    project = tomllib.loads(payload.decode("utf-8")).get("project")
    if not isinstance(project, dict):
        raise ApplicationRefused(f"pyproject.toml declares no [project] table: {tree}")
    return project


def _metadata_document(project: Mapping[str, object]) -> str:
    """The core metadata PEP 427 requires, at version 2.1."""
    license_value = project.get("license")
    license_text = ""
    if isinstance(license_value, dict):
        license_text = str(license_value.get("text", ""))
    elif isinstance(license_value, str):
        license_text = license_value
    lines = [
        "Metadata-Version: 2.1",
        f"Name: {project.get('name', 'qwen-apu')}",
        f"Version: {project.get('version', __version__)}",
    ]
    summary = project.get("description")
    if isinstance(summary, str) and summary:
        lines.append(f"Summary: {summary}")
    requires_python = project.get("requires-python")
    if isinstance(requires_python, str) and requires_python:
        lines.append(f"Requires-Python: {requires_python}")
    if license_text:
        lines.append(f"License: {license_text}")
    dependencies = project.get("dependencies")
    if isinstance(dependencies, list):
        lines.extend(f"Requires-Dist: {entry}" for entry in dependencies)
    return "\n".join(lines) + "\n"


def _wheel_document() -> str:
    """`WHEEL`, without which the archive is a zip rather than an installable wheel."""
    return (
        "Wheel-Version: 1.0\n"
        "Generator: qwen-apu application deployment\n"
        "Root-Is-Purelib: true\n"
        f"Tag: {_WHEEL_TAG}\n"
    )


def _entry_points_document(project: Mapping[str, object]) -> str:
    """The console script `[project.scripts]` declares, carried into the wheel.

    `bootstrap.py` links the source tree and installs the script from it; a wheel
    that replaced that link while naming no entry point would install a package
    with no `qwen-apu` command, so the declaration travels with the archive.
    """
    scripts = project.get("scripts")
    if not isinstance(scripts, dict) or not scripts:
        return ""
    rows = "".join(f"{name} = {target}\n" for name, target in sorted(scripts.items()))
    return f"[console_scripts]\n{rows}"


def _package_members(package_root: Path) -> list[tuple[str, Path]]:
    """Every file of the package, as (arcname, path), sorted and cache-free."""
    members: list[tuple[str, Path]] = []
    for path in sorted(package_root.rglob("*")):
        if not path.is_file():
            continue
        if "__pycache__" in path.parts or path.suffix == ".pyc":
            continue
        members.append((path.relative_to(package_root.parent).as_posix(), path))
    return members


def wheel_filename(version: str) -> str:
    return f"qwen_apu-{version}-{_WHEEL_TAG}.whl"


def build_wheel(tree: Path, destination: Path) -> Path:
    """Write the pure-Python wheel of `src/qwen_apu` at `destination`.

    Determinism is the whole point of the fixed timestamp, the fixed external
    attributes, the sorted member order, and the uncompressed store: the manifest
    states a wheel digest as part of the application's identity, so two builds
    from one commit have to agree on it wherever they run. The store is what
    carries that across hosts, since a deflate stream is an encoder's choice
    rather than a specified one and two zlib builds disagree on the bytes.
    """
    project = _project_metadata(tree)
    version = str(project.get("version", __version__))
    package_root = tree / "src" / "qwen_apu"
    if not package_root.is_dir():
        raise ApplicationRefused(f"the checkout holds no package at {package_root}")
    dist_info = f"qwen_apu-{version}.dist-info"
    records: list[tuple[str, str, int]] = []

    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_STORED) as archive:

        def write(arcname: str, payload: bytes) -> None:
            info = zipfile.ZipInfo(arcname, date_time=WHEEL_TIMESTAMP)
            info.compress_type = zipfile.ZIP_STORED
            info.external_attr = 0o644 << 16
            info.create_system = 3
            archive.writestr(info, payload)
            records.append((arcname, _record_digest(payload), len(payload)))

        for arcname, path in _package_members(package_root):
            write(arcname, path.read_bytes())
        write(f"{dist_info}/METADATA", _metadata_document(project).encode("utf-8"))
        write(f"{dist_info}/WHEEL", _wheel_document().encode("utf-8"))
        entry_points = _entry_points_document(project)
        if entry_points:
            write(f"{dist_info}/entry_points.txt", entry_points.encode("utf-8"))
        # RECORD lists itself with empty digest and size fields, since a row
        # carrying its own digest could never be satisfied.
        record_rows = "".join(f"{name},{digest},{size}\n" for name, digest, size in sorted(records))
        record_rows += f"{dist_info}/RECORD,,\n"
        info = zipfile.ZipInfo(f"{dist_info}/RECORD", date_time=WHEEL_TIMESTAMP)
        info.compress_type = zipfile.ZIP_STORED
        info.external_attr = 0o644 << 16
        info.create_system = 3
        archive.writestr(info, record_rows.encode("utf-8"))
    return destination


# ---------------------------------------------------------------------------
# The identities the manifest binds
# ---------------------------------------------------------------------------


def _git(tree: Path, *arguments: str) -> str:
    executable = shutil.which("git") or "git"
    try:
        completed = subprocess.run(  # noqa: S603
            [executable, "-C", str(tree), "-c", "core.fsmonitor=false", *arguments],
            check=True,
            capture_output=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise ApplicationRefused(
            f"the source commit is part of the application's identity and git "
            f"refused to state it: {error}"
        ) from None
    return completed.stdout.decode("utf-8", "replace").strip()


def source_identity(tree: Path) -> tuple[str, str]:
    """The commit the application is built from, and whether the tree matches it.

    A deployment built from a modified worktree names bytes no commit carries,
    so the state travels beside the commit rather than being assumed clean.
    """
    commit = _git(tree, "rev-parse", "HEAD")
    dirty = _git(tree, "status", "--porcelain")
    return commit, "modified" if dirty else "clean"


def file_digests(root: Path) -> dict[str, str]:
    """Every regular file under `root`, keyed by its POSIX-relative path."""
    return {
        path.relative_to(root).as_posix(): sha256_file(path)
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def tree_digest(digests: Mapping[str, str]) -> str:
    """One digest over the sorted `path\\0digest` rows, the form the receipt states."""
    payload = "".join(f"{name}\0{digests[name]}\n" for name in sorted(digests))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def migration_identity() -> dict[str, object]:
    """The conversation schema: its version, and a digest over every statement."""
    payload = "".join(
        f"{migration.version}\0{statement}\n"
        for migration in MIGRATIONS
        for statement in migration.statements
    )
    return {
        "schema_version": SCHEMA_VERSION,
        "versions": [migration.version for migration in MIGRATIONS],
        "statements_sha256": hashlib.sha256(payload.encode("utf-8")).hexdigest(),
    }


def registry_identity(tree: Path) -> dict[str, str]:
    """Each ledger's digest, with an absent ledger recorded rather than skipped."""
    identities: dict[str, str] = {}
    for relative in REGISTRY_LEDGERS:
        path = tree / relative
        identities[relative] = sha256_file(path) if path.is_file() else _ABSENT
    return identities


def native_identity(paths: RuntimePaths) -> list[dict[str, object]]:
    """Every native bundle in the content-addressed store, by reference.

    The store path is recorded relative to the runtime root, so an application
    built under one root and read under another resolves the same entry.
    `manifest_sha256` is the seal `install/native.py` computed over the bundle's
    provenance, and it is what a verification compares rather than the
    executables themselves.
    """
    entries: list[dict[str, object]] = []
    for bundle in native.installed_bundles(paths):
        manifest = bundle.manifest
        entries.append(
            {
                "store_path": bundle.root.relative_to(paths.root).as_posix(),
                "bundle_sha256": manifest.bundle_sha256,
                "manifest_sha256": manifest.manifest_sha256,
                "manifest_name": native.MANIFEST_NAME,
                "recipe": manifest.recipe,
                "upstream_commit": manifest.upstream_commit,
                "patch_series_sha256": manifest.patch_series_sha256,
                "executables": [
                    {"name": record.name, "bytes": record.bytes, "sha256": record.sha256}
                    for record in manifest.executables
                ],
            }
        )
    return entries


def _preset_reference(path: Path | None) -> dict[str, str]:
    if path is None or not path.is_file():
        return {"name": _ABSENT, "sha256": _ABSENT}
    return {"name": path.name, "sha256": sha256_file(path)}


def deployment_identity(paths: RuntimePaths) -> dict[str, object]:
    """The activated native deployment, referenced by the digests it already seals."""
    try:
        active = deployment.resolve_active(paths["qwen_home_deployments"])
    except DeploymentError as error:
        return {"name": _ABSENT, "reason": str(error)}
    policy_path = active.directory / "q4k-policy.tsv"
    return {
        "name": active.name,
        "directory": active.directory.name,
        "server_sha256": sha256_file(active.server) if active.server.is_file() else _ABSENT,
        "artifact_manifest": _preset_reference(active.manifest),
        "checkpoint_ledger": _preset_reference(active.ledger),
        "router_presets": _preset_reference(active.router_presets),
        "web_presets": _preset_reference(active.web_presets),
        # qwen-launch.sh reads `legacy` where a bundle predates the policy file,
        # so the absence is a value rather than a missing field.
        "q4k_policy": (
            _preset_reference(policy_path) if policy_path.is_file() else {"name": "legacy"}
        ),
    }


def model_identity(paths: RuntimePaths, model_ids: Iterable[str]) -> list[dict[str, object]]:
    """The checkpoints this application serves, referenced by the ledger's pins.

    `remote/model-artifacts.tsv` states the publisher's byte count and SHA-256,
    and the model store is content addressed by that pin rather than by a copy;
    a derived checkpoint the appliance quantizes itself carries no publisher pin
    and records `unrecorded`, the same word `runtime.preflight` uses for it.
    """
    artifacts = {entry.model_id: entry for entry in registry.load_model_artifacts()}
    rows = {row.id: row for row in registry.load_models()}
    entries: list[dict[str, object]] = []
    for model_id in sorted(set(model_ids)):
        row = rows.get(model_id)
        pin = artifacts.get(model_id)
        entries.append(
            {
                "model_id": model_id,
                "model_file": row.model_file if row else _ABSENT,
                "store_root": paths["qwen_home_models"].name,
                "bytes": pin.expected_bytes if pin else 0,
                "sha256": pin.expected_sha256 if pin else "unrecorded",
            }
        )
    return entries


def image_identity(tree: Path) -> dict[str, object]:
    """The image lane's served shapes, named from the profile ledger's own rows."""
    ledger = tree / "remote/image-profiles.tsv"
    profiles: list[str] = []
    if ledger.is_file():
        for line in ledger.read_text(encoding="utf-8").splitlines():
            if line and not line.startswith("#"):
                profiles.append(line.split("\t", 1)[0])
    return {
        "ledger": "remote/image-profiles.tsv",
        "sha256": sha256_file(ledger) if ledger.is_file() else _ABSENT,
        "profiles": sorted(set(profiles)),
    }


def extractor_identity(tree: Path) -> dict[str, object]:
    """What produced a document record's text, which is what its citations read."""
    project = _project_metadata(tree)
    dependencies = project.get("dependencies")
    pinned = list(dependencies) if isinstance(dependencies, list) else []
    return {
        "worker_version": WORKER_VERSION,
        "record_schema": RECORD_SCHEMA,
        "stdlib_formats": list(_STDLIB_EXTRACTORS),
        "pinned_formats": list(_PINNED_EXTRACTORS),
        "pinned_distributions": sorted(str(entry) for entry in pinned),
    }


def security_identity(static_root: Path) -> dict[str, object]:
    """The gate every request meets, summarized from the modules that enforce it."""
    index = static_root / "index.html"
    policy = content_security_policy(index.read_bytes()) if index.is_file() else _ABSENT
    return {
        "content_security_policy": policy,
        "session_cookie": SESSION_COOKIE,
        "pairing_attempt_limit": PAIRING_ATTEMPT_LIMIT,
        "request_body_byte_cap": REQUEST_BODY_BYTE_CAP,
        "request_deadline_seconds": REQUEST_DEADLINE_SECONDS,
        # One origin serves the page and the routes, so the Host set and the
        # Origin allowlist are the gateway's own address rather than a list a
        # manifest could fix ahead of the launch that names the port.
        "origin_policy": "the gateway's own bind host and port alone",
    }


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------


def applications_root(paths: RuntimePaths, root: Path | None = None) -> Path:
    return (root or paths["qwen_home_deployments"]) / APPLICATIONS_DIRECTORY


def canonical_manifest(payload: Mapping[str, object]) -> bytes:
    """The bytes the seal is taken over: sorted keys, one separator spelling."""
    return json.dumps(payload, sort_keys=True, indent=2).encode("utf-8") + b"\n"


def seal(payload: dict[str, object]) -> dict[str, object]:
    """Add `manifest_sha256` over every other field, the way a bundle seals itself."""
    body = {key: value for key, value in payload.items() if key != "manifest_sha256"}
    return {**body, "manifest_sha256": hashlib.sha256(canonical_manifest(body)).hexdigest()}


def _served_model_ids(paths: RuntimePaths) -> tuple[str, ...]:
    """The registry ids the activated router preset names, or every admitted row.

    A root holding no activated bundle still has an application identity, and
    the checkpoint ledger it would serve is then the registry's own picker
    tiers rather than a preset's sections.
    """
    try:
        active = deployment.resolve_active(paths["qwen_home_deployments"])
    except DeploymentError:
        active = None
    if active is not None and active.router_presets is not None:
        try:
            return tuple(section.name for section in preset_sections(active.router_presets))
        except (OSError, RuntimeError):
            return ()
    return tuple(row.id for row in registry.load_models() if row.tier in PICKER_TIERS)


def _copy_tree(source: Path, destination: Path) -> None:
    shutil.copytree(source, destination)
    for path in sorted(destination.rglob("*")):
        path.chmod(_MEMBER_MODE if path.is_file() else _DIRECTORY_MODE)


def build_application(
    paths: RuntimePaths,
    name: str,
    *,
    root: Path | None = None,
    moment: float | None = None,
) -> ApplicationIdentity:
    """Assemble one application deployment and publish it under its own name.

    The staging directory carries the whole tree before the name exists, so an
    interrupted build leaves nothing under `applications/` and a name already
    taken refuses ahead of the first byte. That refusal is what makes an
    application deployment immutable: a changed page or package takes a new
    name, and the name a receipt records keeps naming the bytes it measured.
    """
    if not deployment.bundle_name_is_valid(name):
        raise ApplicationRefused(
            "application name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid the "
            f"root names: {name}"
        )
    tree = paths.tree
    applications = applications_root(paths, root)
    final = applications / name
    if final.exists() or final.is_symlink():
        raise ApplicationRefused(f"application deployment already exists: {final}")
    static_source = tree / "static"
    config_source = tree / "config"
    lock_source = tree / "wheelhouse" / LOCK_NAME
    for required in (static_source, config_source):
        if not required.is_dir():
            raise ApplicationRefused(f"the checkout holds no {required.name} tree: {required}")
    if not lock_source.is_file():
        raise ApplicationRefused(f"the checkout holds no dependency lock: {lock_source}")

    commit, tree_state = source_identity(tree)
    applications.mkdir(parents=True, exist_ok=True)
    staging_parent = applications / _STAGING_PARENT
    if staging_parent.is_symlink() or (staging_parent.exists() and not staging_parent.is_dir()):
        raise ApplicationRefused(f"application staging parent is not a directory: {staging_parent}")
    staging_parent.mkdir(mode=_STAGING_PARENT_MODE, exist_ok=True)
    staging_root = Path(tempfile.mkdtemp(prefix=_STAGING_PREFIX, dir=staging_parent))
    try:
        staged = staging_root / name
        staged.mkdir()
        library = staged / LIBRARY_DIRECTORY
        library.mkdir()
        wheel = build_wheel(tree, library / wheel_filename(__version__))
        wheel.chmod(_MEMBER_MODE)
        lock = library / LOCK_NAME
        shutil.copyfile(lock_source, lock)
        lock.chmod(_MEMBER_MODE)
        _copy_tree(static_source, staged / STATIC_DIRECTORY)
        _copy_tree(config_source, staged / CONFIG_DIRECTORY)

        static_files = file_digests(staged / STATIC_DIRECTORY)
        config_files = file_digests(staged / CONFIG_DIRECTORY)
        static_tree_sha256 = tree_digest(static_files)
        wheel_sha256 = sha256_file(wheel)
        manifest = seal(
            {
                "schema": MANIFEST_SCHEMA,
                "name": name,
                "created_utc": created_utc(moment),
                "source_commit": commit,
                "source_tree_state": tree_state,
                "package_version": __version__,
                "wheel": {
                    "name": wheel.name,
                    "sha256": wheel_sha256,
                    "bytes": wheel.stat().st_size,
                },
                "lock": {
                    "name": LOCK_NAME,
                    "sha256": sha256_file(lock),
                    "bytes": lock.stat().st_size,
                },
                "static": {"tree_sha256": static_tree_sha256, "files": static_files},
                "config": {"tree_sha256": tree_digest(config_files), "files": config_files},
                "migrations": migration_identity(),
                "registries": registry_identity(tree),
                "native_engines": native_identity(paths),
                "native_deployment": deployment_identity(paths),
                "checkpoints": model_identity(paths, _served_model_ids(paths)),
                "image_lane": image_identity(tree),
                "document_extractors": extractor_identity(tree),
                "security_policy": security_identity(staged / STATIC_DIRECTORY),
            }
        )
        manifest_path = staged / MANIFEST_NAME
        manifest_path.write_bytes(canonical_manifest(manifest))
        manifest_path.chmod(_MEMBER_MODE)
        if final.exists() or final.is_symlink():
            raise ApplicationRefused(f"application deployment already exists: {final}")
        os.rename(staged, final)
    finally:
        shutil.rmtree(staging_root, ignore_errors=True)

    return ApplicationIdentity(
        directory=final,
        name=name,
        manifest_sha256=str(manifest["manifest_sha256"]),
        source_commit=commit,
        wheel_sha256=wheel_sha256,
        static_tree_sha256=static_tree_sha256,
    )


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------


def read_manifest(directory: Path) -> dict[str, object]:
    path = directory / MANIFEST_NAME
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise ApplicationRefused(f"application manifest is unreadable: {path}: {error}") from None
    if not isinstance(payload, dict):
        raise ApplicationRefused(f"application manifest is not a JSON object: {path}")
    return payload


def _check_file(
    directory: Path, relative: str, expected: Mapping[str, object], mismatches: list[str]
) -> str:
    path = directory / relative
    if not path.is_file():
        mismatches.append(f"{relative} is absent")
        return relative
    measured = sha256_file(path)
    if measured != str(expected.get("sha256")):
        mismatches.append(f"{relative} digests {measured} against {expected.get('sha256')}")
    measured_bytes = path.stat().st_size
    declared_bytes = expected.get("bytes")
    if isinstance(declared_bytes, int) and declared_bytes != measured_bytes:
        mismatches.append(f"{relative} holds {measured_bytes} bytes against {declared_bytes}")
    return relative


def _check_tree(
    directory: Path, prefix: str, expected: Mapping[str, object], mismatches: list[str]
) -> list[str]:
    """Re-digest one copied tree file by file, and report both directions."""
    declared = expected.get("files")
    if not isinstance(declared, dict):
        mismatches.append(f"{prefix} names no file digests")
        return []
    root = directory / prefix
    measured = file_digests(root) if root.is_dir() else {}
    checked: list[str] = []
    for relative in sorted(declared):
        checked.append(f"{prefix}/{relative}")
        if relative not in measured:
            mismatches.append(f"{prefix}/{relative} is absent")
        elif measured[relative] != str(declared[relative]):
            mismatches.append(
                f"{prefix}/{relative} digests {measured[relative]} against {declared[relative]}"
            )
    for relative in sorted(set(measured) - set(declared)):
        mismatches.append(f"{prefix}/{relative} is present and the manifest names it nowhere")
    recomputed = tree_digest({name: str(value) for name, value in declared.items()})
    if recomputed != str(expected.get("tree_sha256")):
        mismatches.append(
            f"{prefix} tree digest recomputes to {recomputed} against {expected.get('tree_sha256')}"
        )
    return checked


def _check_native_references(
    paths: RuntimePaths, entries: object, mismatches: list[str]
) -> list[str]:
    """Resolve each store reference and compare the seal its own authority wrote.

    Re-hashing the executables is what this check deliberately leaves out: the
    store is content addressed and `native-manifest.json` already seals every
    member's digest under `manifest_sha256`, so comparing that one value tests
    the same claim at the cost of one file read.
    """
    checked: list[str] = []
    if not isinstance(entries, list):
        return checked
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        store_path = str(entry.get("store_path", ""))
        checked.append(store_path)
        manifest_path = paths.root / store_path / str(entry.get("manifest_name", ""))
        if not manifest_path.is_file():
            mismatches.append(f"native engine store reference is absent: {store_path}")
            continue
        try:
            manifest = native.manifest_from_json(manifest_path.read_bytes())
        except native.NativeBundleError as error:
            mismatches.append(f"native engine manifest refused at {store_path}: {error}")
            continue
        if manifest.manifest_sha256 != str(entry.get("manifest_sha256")):
            mismatches.append(
                f"native engine {store_path} seals {manifest.manifest_sha256} against "
                f"{entry.get('manifest_sha256')}"
            )
        if manifest.bundle_sha256 != str(entry.get("bundle_sha256")):
            mismatches.append(
                f"native engine {store_path} carries bundle digest {manifest.bundle_sha256} "
                f"against {entry.get('bundle_sha256')}"
            )
    return checked


def verify_application(
    paths: RuntimePaths, name: str, *, root: Path | None = None
) -> ApplicationVerification:
    """Re-digest every payload member and resolve every reference, refusing on any mismatch.

    The seal is checked first, since a manifest whose own bytes moved states
    nothing the members can be compared against; the payload members follow,
    each re-digested from disk; the references follow last, each resolved and
    compared against the identity its own authority sealed.
    """
    directory = applications_root(paths, root) / name
    if not directory.is_dir():
        raise ApplicationRefused(f"no application deployment named {name} under {directory.parent}")
    manifest = read_manifest(directory)
    recomputed = str(seal(dict(manifest))["manifest_sha256"])
    declared_seal = str(manifest.get("manifest_sha256", _ABSENT))
    mismatches: list[str] = []
    if recomputed != declared_seal:
        mismatches.append(
            f"{MANIFEST_NAME} reseals to {recomputed} against the recorded {declared_seal}"
        )
    checked: list[str] = [MANIFEST_NAME]

    wheel = manifest.get("wheel")
    if isinstance(wheel, dict):
        checked.append(
            _check_file(directory, f"{LIBRARY_DIRECTORY}/{wheel.get('name')}", wheel, mismatches)
        )
    lock = manifest.get("lock")
    if isinstance(lock, dict):
        checked.append(
            _check_file(directory, f"{LIBRARY_DIRECTORY}/{lock.get('name')}", lock, mismatches)
        )
    for prefix, key in ((STATIC_DIRECTORY, "static"), (CONFIG_DIRECTORY, "config")):
        block = manifest.get(key)
        if isinstance(block, dict):
            checked.extend(_check_tree(directory, prefix, block, mismatches))
    checked.extend(_check_native_references(paths, manifest.get("native_engines"), mismatches))

    return ApplicationVerification(
        directory=directory,
        name=name,
        manifest_sha256=declared_seal,
        checked=tuple(checked),
        mismatches=tuple(mismatches),
    )


def applications(paths: RuntimePaths, root: Path | None = None) -> tuple[str, ...]:
    """Every application deployment the root holds, by name."""
    directory = applications_root(paths, root)
    if not directory.is_dir():
        return ()
    return tuple(
        sorted(
            entry.name
            for entry in directory.iterdir()
            if entry.is_dir() and (entry / MANIFEST_NAME).is_file()
        )
    )
