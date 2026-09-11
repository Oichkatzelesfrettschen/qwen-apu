"""Read a deployment bundle and the pointer one launch resolves it through.

A deployment bundle binds the artifacts one activation swaps together: the
`llama-server` binary, the artifact manifest declaring its checkpoint
semantics, the context checkpoint ledger the capacity policy reads, the router
and web presets generated against that ledger, the Q4_K formulation policy the
presets were generated against, and the record of each web section's MCP
configuration. Every claim the bundle manifest states is recomputed here from
the members' own bytes, so a manifest edited to match a tampered member still
fails on the semantics, ledger, executable-row, preset, and MCP recomputation.

This module carries the read-only half: `bundle_name_is_valid` states the
namespace `remote/deployment-bundle-name.sh` defines, `verify_bundle` applies
every check `remote/verify-deployment-bundle.sh` applies in the same order and
with the same message text, and `resolve_active` follows
`deployment-current` under the shared activation lock the way
`remote/resolve-active-deployment.sh` does, through the lock contract
`remote/open-verified-lock-descriptor.py` states. The ledger validator of
`remote/model-registry.sh ctx-checkpoints` and the section checker of
`remote/verify-bundle-preset-ledger.sh` are ported inline, since the shell
verifier reaches both and this module executes no script.

`tests/test_runtime_deployment.py` runs each refusal against both authorities
over one fixture bundle, so a divergence in either direction fails there.
"""

from __future__ import annotations

import errno
import fcntl
import hashlib
import os
import re
import stat
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path

from qwen_apu.runtime.paths import tree_root

# The members a bundle directory owns, in the order the symlink refusal reads
# them. `bundle-manifest.tsv` leads because the manifest is the claim every
# other member is recomputed against.
BUNDLE_MEMBERS: tuple[str, ...] = (
    "bundle-manifest.tsv",
    "llama-server",
    "artifact-manifest.tsv",
    "ctx-checkpoints.tsv",
    "router-presets.ini",
    "web-presets.ini",
    "web-mcp-manifest.tsv",
    "q4k-policy.tsv",
)

# Keys the bundle manifest carries exactly once. `web-mcp-manifest.tsv` and
# `q4k-policy.tsv` stay out: a bundle assembled before either member existed
# carries no row for it, and the row count decides the policy rather than the
# first row's position in the file.
REQUIRED_MANIFEST_KEYS: tuple[str, ...] = (
    "bundle_name",
    "checkpoint_semantics",
    "maximum_ledger_count",
    "server_bytes",
    "llama-server",
    "artifact-manifest.tsv",
    "ctx-checkpoints.tsv",
    "router-presets.ini",
    "web-presets.ini",
)

DIGESTED_MEMBERS: tuple[str, ...] = (
    "llama-server",
    "artifact-manifest.tsv",
    "ctx-checkpoints.tsv",
)

PRESET_MEMBERS: tuple[str, ...] = ("router-presets.ini", "web-presets.ini")

# The names the deployment root owns itself. A bundle name starting with an
# alphanumeric already clears `.activate.lock`, `.staging`, `.`, and `..`;
# these four clear the role links and the generation directories.
RESERVED_BUNDLE_NAMES: frozenset[str] = frozenset(
    {"deployment-current", "deployment-previous", "deployment-state"}
)
_GENERATION_PREFIX = "deployment-state."

_BUNDLE_NAME_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
_CANONICAL_COUNT_PATTERN = re.compile(r"0|[1-9][0-9]*")
_SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")
_Q4K_PATTERN = re.compile(r"-|production/4|e4/[248]|e4-scale/[248]|e4-scale-licm/[248]")
# POSIX [[:space:]] inside the `^[[:space:]]*$` skip pattern the awk readers
# share, with the newline already removed by splitlines.
_BLANK_PATTERN = re.compile(r"[ \t\v\f\r]*")

_DIGEST_CHUNK_BYTES = 1 << 20
_PRIVATE_LOCK_MODE = 0o600
# Group and other write bits break the one-writer rule the lock leaf states,
# so 0644 and 0640 are tightened to 0600 while 0664, 0622, and 0666 refuse.
_FOREIGN_WRITE_BITS = 0o022


class DeploymentError(RuntimeError):
    """A bundle or a pointer whose bytes refuse the deployment contract.

    The message reproduces the shell authority's refusal text, and `details`
    carries the lines a nested validator wrote to its own stderr, which the
    shell's single-line refusal summarizes.
    """

    exit_status: int = 1

    def __init__(self, message: str, details: Sequence[str] = ()) -> None:
        super().__init__(message)
        self.details: tuple[str, ...] = tuple(details)


class NoActiveDeployment(DeploymentError):
    """A root that holds no `deployment-current`, the shell's exit 3.

    The promote-chain defaults apply on this state, where every other refusal
    names a corrupt or refused bundle.
    """

    exit_status: int = 3


class LockDescriptorError(DeploymentError):
    """A lock leaf or descriptor outside the private-regular-leaf contract."""


@dataclass(frozen=True)
class BundleIdentity:
    """What one verification recomputed from a bundle's own bytes."""

    directory: Path
    name: str
    server_sha256: str
    server_bytes: int
    checkpoint_semantics: str
    maximum_ledger_count: int
    member_digests: Mapping[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class ActiveDeployment:
    """The bundle one launch resolved, with the member paths it reads."""

    directory: Path
    name: str
    server: Path
    ledger: Path
    manifest: Path
    router_presets: Path | None
    web_presets: Path | None


def bundle_name_is_valid(name: str) -> bool:
    """State whether one path component names a bundle.

    The leading alphanumeric keeps the name clear of every dot-prefixed entry
    the root owns, and the explicit names keep it clear of the role links and
    the generation directories, so a directory planted as `.activate.lock` or
    `deployment-state.1` reaches no activation and no launch.
    """
    if _BUNDLE_NAME_PATTERN.fullmatch(name) is None:
        return False
    if name in RESERVED_BUNDLE_NAMES:
        return False
    return not name.startswith(_GENERATION_PREFIX)


def sha256_file(path: Path) -> str:
    """The SHA-256 of one file, streamed in 1 MiB chunks."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            chunk = stream.read(_DIGEST_CHUNK_BYTES)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def _read_lines(path: Path) -> list[str]:
    """Every line of a file, with arbitrary bytes preserved through decoding."""
    return path.read_text(encoding="utf-8", errors="surrogateescape").splitlines()


def _fields(line: str) -> list[str]:
    """The tab-separated fields of one line, where an empty line holds none.

    awk reads NF as 0 for an empty record and 1 for a record of spaces, which
    `str.split` reports as 1 in both cases.
    """
    return [] if line == "" else line.split("\t")


def _field(fields: Sequence[str], index: int) -> str:
    """One field by zero-based index, empty past the end as awk reads it."""
    return fields[index] if index < len(fields) else ""


def _is_skipped(line: str) -> bool:
    """Whether the shared awk readers skip a line as a comment or as blank."""
    return line.startswith("#") or _BLANK_PATTERN.fullmatch(line) is not None


def _readable_file(path: Path) -> bool:
    """Whether a path is a readable regular file, `[ -r ] && [ -f ]`."""
    return path.is_file() and os.access(path, os.R_OK)


def _count_rows(lines: Iterable[str], key: str) -> int:
    """Rows whose first tab field equals a key, comments included as awk reads them."""
    return sum(1 for line in lines if _field(_fields(line), 0) == key)


def _first_value(lines: Iterable[str], key: str) -> str:
    """The second field of the first row naming a key, empty where none does."""
    for line in lines:
        fields = _fields(line)
        if _field(fields, 0) == key:
            return _field(fields, 1)
    return ""


def _default_registry() -> Path:
    """The model registry every ledger and preset reading resolves against."""
    declared = os.environ.get("QWEN_MODEL_REGISTRY")
    if declared:
        return Path(declared)
    return tree_root() / "remote" / "models.tsv"


def validate_ctx_checkpoint_ledger(
    ledger_path: Path, registry_path: Path
) -> tuple[list[str], list[str]]:
    """Validate a context checkpoint ledger whole and return its rows.

    One count per model_id, validated before any reader answers, the
    discipline `remote/model-registry.sh` applies to the tuple and draft-pair
    ledgers. The returned problems reproduce the validator's own stderr lines
    and an empty list states acceptance; a model_id outside the ledger serves
    at 0, so an empty ledger is a valid one.
    """
    problems: list[str] = []
    if not os.access(ledger_path, os.R_OK):
        problems.append(f"context checkpoint ledger is unreadable: {ledger_path}")
        return [], problems
    if not os.access(registry_path, os.R_OK):
        problems.append(f"model registry is unreadable: {registry_path}")
        return [], problems

    known_model_ids: set[str] = set()
    for line in _read_lines(registry_path):
        if _is_skipped(line):
            continue
        fields = _fields(line)
        if len(fields) >= 1:
            known_model_ids.add(fields[0])

    rows: list[str] = []
    seen_model_ids: set[str] = set()
    for number, line in enumerate(_read_lines(ledger_path), start=1):
        if _is_skipped(line):
            continue
        fields = _fields(line)
        if len(fields) != 3:
            problems.append(
                f"context checkpoint row {number} holds {len(fields)} fields, expected 3"
            )
            continue
        model_id, count, evidence = fields
        if model_id == "":
            problems.append(f"context checkpoint row {number} carries an empty model_id")
        if model_id in seen_model_ids:
            problems.append(f"duplicate model_id {model_id} at context checkpoint row {number}")
        seen_model_ids.add(model_id)
        if model_id not in known_model_ids:
            problems.append(f"{model_id}: model_id is absent from the model registry")
        # common/arg.cpp reads --ctx-checkpoints as an int and the policy builds
        # exact string tuple keys, so the count is one canonical non-negative
        # decimal integer without leading zeroes.
        if _CANONICAL_COUNT_PATTERN.fullmatch(count) is None:
            problems.append(
                f"{model_id}: ctx_checkpoints {count} is not a canonical non-negative integer"
            )
        if evidence == "":
            problems.append(f"{model_id}: evidence is empty; write - for an unmeasured zero")
        elif evidence == "-" and count != "0":
            problems.append(f"{model_id}: a count above 0 requires retained evidence")
        rows.append(line)
    if problems:
        return rows, problems

    # The three-field shape is established, so each evidence path is read as one
    # word and held to the repository-relative namespace.
    for row in rows:
        model_id, _count, evidence = _fields(row)
        if evidence == "-":
            continue
        if _escapes_repository(evidence):
            problems.append(f"{model_id}: evidence is not a repository-relative path: {evidence}")
    return rows, problems


def _escapes_repository(evidence: str) -> bool:
    """Whether an evidence path leaves the repository, the shell's glob set."""
    return (
        evidence in ("", "..")
        or evidence.startswith(("/", "../"))
        or "/../" in evidence
        or evidence.endswith("/..")
    )


def _maximum_ledger_count(rows: Sequence[str]) -> int:
    """The largest count the validated rows state, 0 over an empty ledger."""
    maximum = 0
    for row in rows:
        count = int(_field(_fields(row), 1) or 0)
        maximum = max(maximum, count)
    return maximum


@dataclass
class _PresetSection:
    """One preset section's keys as the ledger checker counts them."""

    name: str
    checkpoint_keys: int = 0
    count: str = ""
    model_keys: int = 0
    model_value: str = ""
    q4k_keys: int = 0
    q4k_value: str = ""


def _parse_ledger_preset_sections(lines: Iterable[str]) -> list[_PresetSection]:
    """Sections as `verify-bundle-preset-ledger.sh` reads them.

    The section header matches `/^\\[/` at column 0 and ends at the first `]`,
    and the keys a header precedes belong to it; keys ahead of the first header
    belong to no section and are discarded with it.
    """
    sections: list[_PresetSection] = []
    current: _PresetSection | None = None
    pending = _PresetSection(name="")
    for line in lines:
        if line.startswith("["):
            name = line[1:]
            closing = name.find("]")
            if closing >= 0:
                name = name[:closing]
            current = _PresetSection(name=name)
            sections.append(current)
            continue
        target = current if current is not None else pending
        key, value = _preset_key_value(line)
        if key == "LLAMA_ARG_CTX_CHECKPOINTS":
            target.checkpoint_keys += 1
            target.count = value
        elif key == "LLAMA_ARG_VK_Q4K_VARIANT":
            target.q4k_keys += 1
            target.q4k_value = value
        elif key == "LLAMA_ARG_MODEL":
            target.model_keys += 1
            target.model_value = value
    return sections


_PRESET_KEYS = (
    "LLAMA_ARG_CTX_CHECKPOINTS",
    "LLAMA_ARG_VK_Q4K_VARIANT",
    "LLAMA_ARG_MODEL",
)


def _preset_key_value(line: str) -> tuple[str, str]:
    """One `NAME = VALUE` key, matched the way the awk patterns match it."""
    stripped = line.lstrip(" \t\v\f\r")
    for key in _PRESET_KEYS:
        remainder = stripped[len(key) :]
        if stripped.startswith(key) and remainder.lstrip(" \t\v\f\r").startswith("="):
            # `sub(/^[^=]*=[[:space:]]*/, "")` cuts through the first `=` of the
            # whole record, then the trailing whitespace goes.
            value = line.split("=", 1)[1].lstrip(" \t\v\f\r")
            return key, value.rstrip(" \t\v\f\r")
    return "", ""


def verify_preset_ledger(
    preset_path: Path,
    ledger_path: Path,
    registry_path: Path,
    q4k_policy_selector: str,
) -> list[str]:
    """Bind each preset section to its own model's bundled count and formulation.

    A section's `LLAMA_ARG_MODEL` path resolves through the registry's
    model_file column to exactly one model_id by the raw suffix rule, refusing
    a path two rows match, and the section's `LLAMA_ARG_CTX_CHECKPOINTS` must
    equal that row's ledger count, with a registry row absent from the ledger
    reading 0. `q4k_policy_selector` names the formulation authority: an empty
    value and `registry` read the registry column, `-` releases no formulation
    on any row, `legacy` states that the bundle records no policy, and any
    other value names a policy file. The returned problems reproduce the shell
    checker's stderr lines and an empty list states acceptance.
    """
    problems: list[str] = []
    for required in (preset_path, ledger_path, registry_path):
        if not os.access(required, os.R_OK):
            problems.append(f"preset ledger check input is unreadable: {required}")
    if problems:
        return problems

    policy_q4k: dict[str, str] = {}
    if q4k_policy_selector in ("", "registry"):
        policy_mode = "registry"
    elif q4k_policy_selector == "-":
        policy_mode = "none"
    elif q4k_policy_selector == "legacy":
        policy_mode = "legacy"
    else:
        policy_mode = "file"
        policy_path = Path(q4k_policy_selector)
        if not _readable_file(policy_path):
            return [f"Q4_K formulation policy is unreadable: {policy_path}"]
        for line in _read_lines(policy_path):
            if _is_skipped(line):
                continue
            fields = _fields(line)
            if len(fields) != 2 or fields[0] == "":
                problems.append(f"Q4_K policy row is malformed: {line}")
                continue
            if fields[0] in policy_q4k:
                problems.append(f"Q4_K policy names {fields[0]} twice")
                continue
            if _Q4K_PATTERN.fullmatch(fields[1]) is None:
                problems.append(
                    f"Q4_K policy row {fields[0]} carries an invalid formulation: {fields[1]}"
                )
                continue
            policy_q4k[fields[0]] = fields[1]

    registry_rows: list[tuple[str, str, str]] = []
    for line in _read_lines(registry_path):
        if _is_skipped(line):
            continue
        fields = _fields(line)
        if _field(fields, 0) == "" or _field(fields, 2) == "":
            problems.append(f"registry row is malformed: {line}")
            continue
        variant = _field(fields, 22) or "-"
        if _Q4K_PATTERN.fullmatch(variant) is None:
            problems.append(f"registry row {fields[0]} carries invalid q4k_variant: {variant}")
        registry_rows.append((fields[0], fields[2], variant))

    ledger: dict[str, str] = {}
    for line in _read_lines(ledger_path):
        if _is_skipped(line):
            continue
        fields = _fields(line)
        if len(fields) < 2 or _CANONICAL_COUNT_PATTERN.fullmatch(fields[1]) is None:
            problems.append(f"ledger row is malformed: {line}")
            continue
        ledger[fields[0]] = fields[1]

    policy_authority = "the registry" if policy_mode == "registry" else "the bundled Q4_K policy"
    sections = _parse_ledger_preset_sections(_read_lines(preset_path))
    for section in sections:
        problems.extend(
            _check_preset_section(
                section,
                registry_rows,
                ledger,
                policy_mode=policy_mode,
                policy_q4k=policy_q4k,
                policy_authority=policy_authority,
            )
        )
    if not sections:
        problems.append(f"preset carries no sections: {preset_path}")
    return problems


def _resolve_preset_model(
    path: str, registry_rows: Sequence[tuple[str, str, str]]
) -> tuple[str, str, int]:
    """The one registry row a section path ends in, by the raw suffix rule.

    `model-registry.sh` answers a path selector with its first matching row;
    this reading refuses a path more than one row matches, so a registry whose
    files are suffixes of one another binds no section by file order.
    """
    matches = 0
    model_id = ""
    variant = "-"
    for candidate_id, model_file, candidate_variant in registry_rows:
        if len(model_file) <= len(path) and path.endswith(model_file):
            matches += 1
            model_id = candidate_id
            variant = candidate_variant
    if matches != 1:
        return "", "-", matches
    return model_id, variant, matches


def _check_preset_section(
    section: _PresetSection,
    registry_rows: Sequence[tuple[str, str, str]],
    ledger: Mapping[str, str],
    *,
    policy_mode: str,
    policy_q4k: Mapping[str, str],
    policy_authority: str,
) -> list[str]:
    """One section against the bundled ledger and the bundled formulation policy."""
    name = section.name
    if section.checkpoint_keys != 1:
        return [
            f"preset section [{name}] carries {section.checkpoint_keys} "
            "LLAMA_ARG_CTX_CHECKPOINTS keys; exactly one is required"
        ]
    if _CANONICAL_COUNT_PATTERN.fullmatch(section.count) is None:
        return [f"preset section [{name}] carries a malformed checkpoint count: {section.count}"]
    if section.model_keys != 1:
        return [
            f"preset section [{name}] carries {section.model_keys} "
            "LLAMA_ARG_MODEL keys; exactly one is required"
        ]
    model_id, resolved_q4k, matches = _resolve_preset_model(section.model_value, registry_rows)
    if model_id == "":
        return [
            f"preset section [{name}] carries LLAMA_ARG_MODEL {section.model_value} that "
            f"resolves to {matches} registry rows; exactly one is required"
        ]

    problems: list[str] = []
    expected = ledger.get(model_id, "0")
    if int(section.count) != int(expected):
        problems.append(
            f"preset section [{name}] carries checkpoint count {section.count} where the "
            f"bundled ledger states {expected} for {model_id}"
        )

    policy_gap = False
    if policy_mode == "registry":
        released = resolved_q4k
    elif policy_mode in ("none", "legacy"):
        released = "-"
    elif model_id in policy_q4k:
        released = policy_q4k[model_id]
    else:
        released = ""
        policy_gap = True

    if policy_gap:
        problems.append(
            f"preset section [{name}] serves {model_id}, which the bundled Q4_K policy never names"
        )
    elif released == "-":
        if section.q4k_keys != 0 and policy_mode == "legacy":
            problems.append(
                f"preset section [{name}] carries LLAMA_ARG_VK_Q4K_VARIANT "
                f"{section.q4k_value} where the bundle records no Q4_K formulation policy "
                f"for {model_id}; re-assemble the bundle with build-deployment-bundle.sh, "
                "or name the policy it was generated against in QWEN_BUNDLE_Q4K_POLICY"
            )
        elif section.q4k_keys != 0:
            problems.append(
                f"preset section [{name}] carries LLAMA_ARG_VK_Q4K_VARIANT "
                f"{section.q4k_value} where {policy_authority} releases no Q4_K formulation "
                f"for {model_id}"
            )
    elif section.q4k_keys != 1:
        problems.append(
            f"preset section [{name}] carries {section.q4k_keys} LLAMA_ARG_VK_Q4K_VARIANT "
            f"keys where {policy_authority} releases {released} for {model_id}"
        )
    elif section.q4k_value != released:
        problems.append(
            f"preset section [{name}] carries Q4_K formulation {section.q4k_value} where "
            f"{policy_authority} releases {released} for {model_id}"
        )
    return problems


def _marker_values(lines: Iterable[str], marker: str) -> list[str]:
    """Every value a `# marker=` head line carries, in file order."""
    prefix = f"# {marker}="
    return [line[len(prefix) :] for line in lines if line.startswith(prefix)]


def _preset_mcp_rows(lines: Iterable[str]) -> list[str]:
    """Each section's `LLAMA_ARG_MCP_SERVERS_CONFIG` as `section<TAB>value`.

    This reader admits an indented section header where the ledger checker
    requires column 0, so the two parsers stay separate.
    """
    rows: list[str] = []
    section = ""
    for line in lines:
        stripped = line.lstrip(" \t\v\f\r")
        if stripped.startswith("["):
            section = stripped[1:]
            section = re.sub(r"\][ \t\v\f\r]*$", "", section)
            continue
        key = "LLAMA_ARG_MCP_SERVERS_CONFIG"
        remainder = stripped[len(key) :]
        if stripped.startswith(key) and remainder.lstrip(" \t\v\f\r").startswith("="):
            value = line.split("=", 1)[1].lstrip(" \t\v\f\r").rstrip(" \t\v\f\r")
            rows.append(f"{section}\t{value}")
    return rows


def verify_bundle(root: Path, name: str) -> BundleIdentity:
    """Recompute every claim one bundle states and answer with its identity.

    The bundle is held inside the deployment root lexically and canonically:
    its name is one path component, the directory and each member are plain
    files rather than symlinks, and the canonical directory sits immediately
    below the canonical root, so a link planted at the root carries neither an
    activation nor a launch outside it. The registry the ledger and the presets
    resolve against comes from QWEN_MODEL_REGISTRY, then `remote/models.tsv`
    beside this checkout.
    """
    registry_path = _default_registry()
    if not bundle_name_is_valid(name):
        raise DeploymentError(
            "bundle name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid the root names: " + name
        )
    if not root.is_dir():
        raise DeploymentError(f"deployment root is not a directory: {root}")
    canonical_root = Path(os.path.realpath(root))
    bundle_directory = root / name
    if bundle_directory.is_symlink():
        raise DeploymentError(
            f"bundle directory is a symlink and stays inactive: {bundle_directory}"
        )
    if not bundle_directory.is_dir():
        raise DeploymentError(f"bundle directory is absent: {bundle_directory}")
    canonical_directory = Path(os.path.realpath(bundle_directory))
    if str(canonical_directory) != f"{canonical_root}/{name}":
        raise DeploymentError(
            f"bundle directory resolves outside the deployment root: {bundle_directory} "
            f"resolves to {canonical_directory}"
        )

    for member in BUNDLE_MEMBERS:
        if (bundle_directory / member).is_symlink():
            raise DeploymentError(f"bundle member is a symlink: {bundle_directory / member}")

    bundle_manifest = bundle_directory / "bundle-manifest.tsv"
    if not _readable_file(bundle_manifest):
        raise DeploymentError(f"bundle manifest is unreadable: {bundle_manifest}")
    manifest_lines = _read_lines(bundle_manifest)
    for key in REQUIRED_MANIFEST_KEYS:
        rows = _count_rows(manifest_lines, key)
        if rows != 1:
            raise DeploymentError(
                f"bundle manifest carries {rows} rows for {key}; exactly one is required: "
                f"{bundle_manifest}"
            )
    # The web MCP record is the one key a bundle assembled before the merged
    # preset carries no row for, and such a bundle names no web section either,
    # so the row is optional here and the preset marker below decides whether it
    # has to be there.
    web_mcp_rows = _count_rows(manifest_lines, "web-mcp-manifest.tsv")
    if web_mcp_rows > 1:
        raise DeploymentError(
            f"bundle manifest carries {web_mcp_rows} rows for web-mcp-manifest.tsv; "
            f"at most one is admitted: {bundle_manifest}"
        )
    # The name a bundle was assembled under is the name it activates under, so a
    # directory renamed onto another bundle's name publishes nothing.
    declared_name = _first_value(manifest_lines, "bundle_name")
    if declared_name != name:
        raise DeploymentError(f"bundle directory {name} carries bundle_name {declared_name}")

    member_digests: dict[str, str] = {}
    for member in DIGESTED_MEMBERS:
        expected = _first_value(manifest_lines, member)
        member_path = bundle_directory / member
        if not _readable_file(member_path):
            raise DeploymentError(f"bundle member is unreadable: {member_path}")
        actual = sha256_file(member_path)
        if actual != expected:
            raise DeploymentError(
                f"bundle member diverged: {member} expected={expected} found={actual}"
            )
        member_digests[member] = actual

    server_path = bundle_directory / "llama-server"
    if not os.access(server_path, os.X_OK):
        raise DeploymentError(f"bundle server is not executable: {server_path}")

    # The semantics are recomputed from the artifact manifest and the server's
    # own bytes, and the bundle manifest must agree with what was recomputed.
    measured_bytes = server_path.stat().st_size
    declared_bytes = _first_value(manifest_lines, "server_bytes")
    if str(measured_bytes) != declared_bytes:
        raise DeploymentError(
            f"bundle server measures {measured_bytes} bytes against the declared {declared_bytes}"
        )

    artifact_manifest = bundle_directory / "artifact-manifest.tsv"
    artifact_lines = _read_lines(artifact_manifest)
    # The exec guard requires exactly one executable llama-server row and then
    # checks that row, so the bundle requires the same two facts: one named row,
    # and that row matching the bundled server's bytes and digest.
    named_rows = sum(
        1
        for line in artifact_lines
        for fields in (_fields(line),)
        if len(fields) == 4 and fields[0] == "executable" and fields[1] == "llama-server"
    )
    if named_rows != 1:
        raise DeploymentError(
            f"artifact manifest holds {named_rows} executable llama-server rows; "
            "exactly one is required"
        )
    executable_rows = sum(
        1
        for line in artifact_lines
        for fields in (_fields(line),)
        if len(fields) == 4
        and fields[0] == "executable"
        and fields[1] == "llama-server"
        and fields[2] == str(measured_bytes)
        and fields[3] == member_digests["llama-server"]
    )
    if executable_rows != 1:
        raise DeploymentError(
            "artifact manifest executable llama-server row does not match the bundled server"
        )

    _check_serving_declaration(artifact_manifest, artifact_lines)

    semantics_rows = _count_rows(artifact_lines, "checkpoint_semantics")
    if semantics_rows != 1:
        raise DeploymentError("artifact manifest must carry exactly one checkpoint_semantics row")
    recomputed_semantics = _first_value(artifact_lines, "checkpoint_semantics")
    declared_semantics = _first_value(manifest_lines, "checkpoint_semantics")
    if recomputed_semantics != declared_semantics:
        raise DeploymentError(
            f"artifact manifest declares checkpoint_semantics {recomputed_semantics} against "
            f"the bundle manifest declaration {declared_semantics}"
        )

    # The ledger is revalidated through the registry validator, and the maximum
    # count is recomputed from the validated rows.
    ledger_path = bundle_directory / "ctx-checkpoints.tsv"
    ledger_rows, ledger_problems = validate_ctx_checkpoint_ledger(ledger_path, registry_path)
    if ledger_problems:
        raise DeploymentError(
            f"bundle ledger failed registry validation: {ledger_path}", ledger_problems
        )
    recomputed_maximum = _maximum_ledger_count(ledger_rows)
    declared_maximum = _first_value(manifest_lines, "maximum_ledger_count")
    if str(recomputed_maximum) != declared_maximum:
        raise DeploymentError(
            f"bundle ledger maximum count {recomputed_maximum} disagrees with the declared "
            f"{declared_maximum}"
        )
    if recomputed_maximum > 0 and recomputed_semantics != "natural-boundary-v1":
        raise DeploymentError(
            f"bundle pairs a positive checkpoint count with {recomputed_semantics}; "
            "a positive count requires natural-boundary-v1"
        )

    q4k_policy_selector = _resolve_q4k_policy(bundle_directory, bundle_manifest, manifest_lines)
    _verify_preset_members(
        bundle_directory, manifest_lines, ledger_path, registry_path, q4k_policy_selector
    )
    _verify_web_mcp_record(bundle_directory, manifest_lines)

    return BundleIdentity(
        directory=canonical_directory,
        name=name,
        server_sha256=member_digests["llama-server"],
        server_bytes=measured_bytes,
        checkpoint_semantics=recomputed_semantics,
        maximum_ledger_count=recomputed_maximum,
        member_digests=member_digests,
    )


def _check_serving_declaration(artifact_manifest: Path, artifact_lines: Sequence[str]) -> None:
    """Hold an artifact manifest to the eligibility grammar assembly applies.

    Zero serving_eligible rows is the legacy shape and holds only beside zero
    instrumentation rows; exactly one row must read exactly `yes`, so a present
    row with an empty value is refused by its own reading. A second row of
    either kind is refused on cardinality ahead of both, and an instrumentation
    row refuses the bundle at whatever eligibility spelling accompanies it.
    """
    serving_rows = _count_rows(artifact_lines, "serving_eligible")
    instrumentation_rows = _count_rows(artifact_lines, "instrumentation")
    if serving_rows > 1 or instrumentation_rows > 1:
        raise DeploymentError(
            f"artifact manifest holds {serving_rows} serving_eligible rows and "
            f"{instrumentation_rows} instrumentation rows, at most one of each: "
            f"{artifact_manifest}"
        )
    if instrumentation_rows == 1:
        declared = _first_value(artifact_lines, "instrumentation") or "<empty>"
        raise DeploymentError(
            f"artifact manifest names instrumentation {declared}; a bundle carries serving "
            f"builds alone: {artifact_manifest}"
        )
    if serving_rows == 1:
        serving_eligible = _first_value(artifact_lines, "serving_eligible")
        if serving_eligible != "yes":
            raise DeploymentError(
                f"artifact manifest declares serving_eligible {serving_eligible or '<empty>'}; "
                f"a bundle carries serving builds alone: {artifact_manifest}"
            )


def _resolve_q4k_policy(
    bundle_directory: Path, bundle_manifest: Path, manifest_lines: Sequence[str]
) -> str:
    """Name the formulation authority the bundle's own manifest states.

    Three manifest shapes are distinct claims: no row at all is a bundle
    assembled before this member existed, which records no policy and binds
    `legacy`; one row of `-` is a bundle declaring that its member is absent
    because nothing was released; one row of a digest binds the member.
    """
    policy_path = bundle_directory / "q4k-policy.tsv"
    rows = _count_rows(manifest_lines, "q4k-policy.tsv")
    if rows > 1:
        raise DeploymentError(
            f"bundle manifest carries {rows} rows for q4k-policy.tsv; at most one is admitted: "
            f"{bundle_manifest}"
        )
    if rows == 0:
        if policy_path.exists():
            raise DeploymentError(
                "bundle carries q4k-policy.tsv that its manifest records no row for"
            )
        return "legacy"
    expected = _first_value(manifest_lines, "q4k-policy.tsv")
    # An empty second field declares nothing at all, so it is refused rather
    # than read as either the absent member or a digest.
    if expected == "":
        raise DeploymentError(
            f"bundle manifest carries an empty q4k-policy.tsv declaration: {bundle_manifest}"
        )
    if expected == "-":
        if policy_path.exists():
            raise DeploymentError(
                "bundle carries q4k-policy.tsv that its manifest records as absent"
            )
        return "-"
    if not _readable_file(policy_path):
        raise DeploymentError(f"bundle member is unreadable: {policy_path}")
    actual = sha256_file(policy_path)
    if actual != expected:
        raise DeploymentError(
            f"bundle member diverged: q4k-policy.tsv expected={expected} found={actual}"
        )
    return str(policy_path)


def _verify_preset_members(
    bundle_directory: Path,
    manifest_lines: Sequence[str],
    ledger_path: Path,
    registry_path: Path,
    q4k_policy_selector: str,
) -> None:
    """Hold each preset to its digest and re-read its sections against the bundle.

    A preset member is present exactly where the manifest digests one, and its
    sections are re-read against the bundled ledger, the bundled formulation
    policy, and the registry rather than trusted from the digest alone.
    """
    for member in PRESET_MEMBERS:
        expected = _first_value(manifest_lines, member)
        member_path = bundle_directory / member
        if expected == "-":
            if member_path.exists():
                raise DeploymentError(
                    f"bundle carries {member} that its manifest records as absent"
                )
            continue
        if not _readable_file(member_path):
            raise DeploymentError(f"bundle member is unreadable: {member_path}")
        actual = sha256_file(member_path)
        if actual != expected:
            raise DeploymentError(
                f"bundle member diverged: {member} expected={expected} found={actual}"
            )
        problems = verify_preset_ledger(
            member_path, ledger_path, registry_path, q4k_policy_selector
        )
        if problems:
            raise DeploymentError(
                f"bundle preset {member} disagrees with the bundled ledger", problems
            )


def _verify_web_mcp_record(bundle_directory: Path, manifest_lines: Sequence[str]) -> None:
    """Compare the MCP record against the preset that names the configurations.

    The preset's own `# qwen_web_sections=` marker decides whether the record
    exists at all, and the comparison reads the preset rather than the state
    directory: opening the named configurations would refuse every bundle on a
    machine that has not generated a web preset, which turns a web-lane concern
    into an outage across the whole roster.
    """
    record_path = bundle_directory / "web-mcp-manifest.tsv"
    router_preset = bundle_directory / "router-presets.ini"
    expected_digest = _first_value(manifest_lines, "web-mcp-manifest.tsv") or "-"

    preset_web_sections = ""
    preset_mcp_rows: list[str] = []
    preset_lines: list[str] = []
    if router_preset.is_file():
        preset_lines = _read_lines(router_preset)
        preset_web_sections = "\n".join(_marker_values(preset_lines, "qwen_web_sections"))
        if preset_web_sections == "-":
            preset_web_sections = ""
        preset_mcp_rows = _preset_mcp_rows(preset_lines)

    if preset_web_sections == "":
        # A preset naming no web section carries no execution grant, so a record
        # or a configuration key here claims one the marker withholds.
        if expected_digest != "-":
            raise DeploymentError(
                "bundle manifest records web-mcp-manifest.tsv where its router preset names "
                "no web section"
            )
        if record_path.exists():
            raise DeploymentError(
                "bundle carries web-mcp-manifest.tsv that its manifest records as absent"
            )
        if preset_mcp_rows:
            raise DeploymentError(
                "bundle router preset names MCP configurations and its head marker names "
                "no web section"
            )
        # An image server reaches the device from a section the web ledger
        # emitted, so a lane armed over a preset naming none claims a grant no
        # section carries.
        if router_preset.is_file():
            profiles = [
                "" if value == "-" else value
                for value in _marker_values(preset_lines, "qwen_image_profile")
            ]
            if "".join(f"{value}\n" for value in profiles).rstrip("\n") != "":
                raise DeploymentError(
                    "bundle router preset names an image profile and its head marker names "
                    "no web section"
                )
        return

    if expected_digest == "-":
        raise DeploymentError(
            f"bundle router preset names web section {preset_web_sections} and its manifest "
            "records no web-mcp-manifest.tsv"
        )
    if not _readable_file(record_path):
        raise DeploymentError(f"bundle member is unreadable: {record_path}")
    actual_digest = sha256_file(record_path)
    if actual_digest != expected_digest:
        raise DeploymentError(
            f"bundle member diverged: web-mcp-manifest.tsv expected={expected_digest} "
            f"found={actual_digest}"
        )

    # The image server rides inside the same configuration, so the record's
    # fourth column states whether each section arms a generation and the
    # preset's own marker states whether it should. A row written before that
    # column reads `-`, the withheld lane an unmarked preset also names.
    image_profiles = _marker_values(preset_lines, "qwen_image_profile")
    preset_image_profile = "\n".join(image_profiles)
    if preset_image_profile == "-":
        preset_image_profile = ""
    expected_image_column = "image" if preset_image_profile else "-"

    problems: list[str] = []
    recorded_rows: list[str] = []
    for line in _read_lines(record_path):
        if _is_skipped(line):
            continue
        fields = _fields(line)
        if (
            len(fields) not in (3, 4)
            or fields[0] == ""
            or fields[1] == ""
            or _SHA256_PATTERN.fullmatch(fields[2]) is None
        ):
            problems.append(f"web-mcp-manifest.tsv row is malformed: {line}")
            continue
        image_column = fields[3] if len(fields) == 4 else "-"
        if image_column not in ("image", "-"):
            problems.append(f"web-mcp-manifest.tsv row carries image_server {image_column}: {line}")
            continue
        if image_column != expected_image_column:
            problems.append(
                f"web-mcp-manifest.tsv records image_server {image_column} for {fields[0]} "
                f"where the preset marker reads {expected_image_column}"
            )
            continue
        recorded_rows.append(f"{fields[0]}\t{fields[1]}")
    if problems:
        raise DeploymentError(problems[0], problems)
    if "\n".join(recorded_rows) != "\n".join(preset_mcp_rows):
        raise DeploymentError(
            "web-mcp-manifest.tsv records configurations the bundled router preset does not name"
        )


def _same_file(left: os.stat_result, right: os.stat_result) -> bool:
    """Whether two stat results identify one filesystem object."""
    return left.st_dev == right.st_dev and left.st_ino == right.st_ino


def _verify_lock_identity(path: Path, descriptor: int) -> os.stat_result:
    """Verify one descriptor and its pathname identify a same-owner regular leaf."""
    descriptor_status = os.fstat(descriptor)
    if not stat.S_ISREG(descriptor_status.st_mode):
        raise LockDescriptorError(f"lock descriptor is not regular: {path}")
    effective_uid = os.geteuid()
    if descriptor_status.st_uid != effective_uid:
        raise LockDescriptorError(
            f"lock descriptor uid {descriptor_status.st_uid} differs from "
            f"effective uid {effective_uid}: {path}"
        )
    # One inode reachable by one name: a same-owner private hard link would
    # otherwise make an unrelated file the synchronization object.
    if descriptor_status.st_nlink != 1:
        raise LockDescriptorError(f"lock leaf has {descriptor_status.st_nlink} hard links: {path}")
    try:
        path_status = path.lstat()
    except OSError as error:
        raise LockDescriptorError(f"lock path is unreadable: {path}: {error}") from error
    if not stat.S_ISREG(path_status.st_mode):
        raise LockDescriptorError(f"lock path is not a regular leaf: {path}")
    if not _same_file(path_status, descriptor_status):
        raise LockDescriptorError(f"lock path changed while opening: {path}")
    return descriptor_status


def _verify_lock_status(path: Path, descriptor: int) -> None:
    """Verify one descriptor and its pathname identify a private regular leaf."""
    descriptor_status = _verify_lock_identity(path, descriptor)
    descriptor_mode = stat.S_IMODE(descriptor_status.st_mode)
    if descriptor_mode & 0o077:
        raise LockDescriptorError(
            f"lock descriptor mode {descriptor_mode:#05o} grants group or other access: {path}"
        )


def _normalize_legacy_mode(path: Path, descriptor: int, descriptor_status: os.stat_result) -> None:
    """Tighten an unlocked owner-writable legacy mode through its descriptor."""
    descriptor_mode = stat.S_IMODE(descriptor_status.st_mode)
    if not descriptor_mode & 0o077:
        return
    if descriptor_mode & _FOREIGN_WRITE_BITS:
        raise LockDescriptorError(
            f"lock descriptor mode {descriptor_mode:#05o} grants write access to another "
            f"user: {path}"
        )
    if descriptor_status.st_nlink != 1:
        raise LockDescriptorError(f"legacy lock has multiple hard links: {path}")
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as error:
        if error.errno in (errno.EACCES, errno.EAGAIN):
            raise LockDescriptorError(
                f"legacy lock mode cannot be tightened while the lock is held: {path}"
            ) from None
        raise
    # Revalidate after exclusive acquisition so a pathname replacement cannot
    # redirect or authorize the descriptor-bound permission change.
    locked_status = _verify_lock_identity(path, descriptor)
    locked_mode = stat.S_IMODE(locked_status.st_mode)
    if locked_mode & 0o077 and not locked_mode & _FOREIGN_WRITE_BITS:
        if locked_status.st_nlink != 1:
            raise LockDescriptorError(f"legacy lock gained a hard link: {path}")
        os.fchmod(descriptor, _PRIVATE_LOCK_MODE)
    _verify_lock_status(path, descriptor)


def open_verified_lock(path: Path, normalize_legacy_mode: bool = True) -> int:
    """Open a private lock leaf without following links or truncating its bytes.

    The leaf is a mutual-exclusion token the serving user owns alone, so the
    open refuses a symlink through O_NOFOLLOW, a directory through the same
    open, a foreign owner, a hard link, and a mode granting group or other
    access. `normalize_legacy_mode` tightens an owner-writable 0644 or 0640
    leaf to 0600 under an uncontended exclusive lock, and refuses a mode that
    grants write access to another user. The caller owns the returned
    descriptor and closes it, which releases whatever lock it holds.
    """
    flags = os.O_RDWR | os.O_CREAT | os.O_CLOEXEC | os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags, _PRIVATE_LOCK_MODE)
    except OSError as error:
        raise LockDescriptorError(str(error)) from error
    try:
        descriptor_status = _verify_lock_identity(path, descriptor)
        if normalize_legacy_mode:
            _normalize_legacy_mode(path, descriptor, descriptor_status)
        _verify_lock_status(path, descriptor)
    except (LockDescriptorError, OSError) as error:
        os.close(descriptor)
        if isinstance(error, LockDescriptorError):
            raise
        raise LockDescriptorError(str(error)) from error
    return descriptor


def resolve_active(root: Path, explicit_directory: Path | None = None) -> ActiveDeployment:
    """Resolve the active deployment once for a whole launch.

    The activation lock is taken shared, `deployment-current` is followed to
    one bundle, that bundle is required to sit immediately below the deployment
    root under a plain name and is verified whole, and the canonical member
    paths answer. The caller retains the directory and reads every member from
    it, so a later activation replaces the pointer while the launch keeps the
    bundle it resolved. An explicit directory is verified rather than trusted:
    it must be a bundle below the root and passes the same verification.
    Absence is decided under the lock, so an activation publishing its links
    between the read and the lock leaves no launch reporting an empty root.
    """
    if not root.is_dir():
        raise NoActiveDeployment(f"no deployment root: {root}")
    canonical_root = os.path.realpath(root)

    descriptor = open_verified_lock(root / ".activate.lock", normalize_legacy_mode=True)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_SH)
        current_link = root / "deployment-current"
        if explicit_directory is not None:
            if explicit_directory.is_symlink() or not explicit_directory.is_dir():
                raise DeploymentError(
                    "QWEN_ACTIVE_DEPLOYMENT_DIRECTORY is not a plain directory: "
                    f"{explicit_directory}"
                )
            canonical_directory = os.path.realpath(explicit_directory)
        else:
            if not current_link.exists() and not current_link.is_symlink():
                raise NoActiveDeployment(f"no deployment-current under {root}")
            if not current_link.is_symlink():
                raise DeploymentError(f"deployment-current is not a symlink: {current_link}")
            if not current_link.is_dir():
                raise DeploymentError(
                    f"deployment-current does not resolve to a directory: {current_link}"
                )
            canonical_directory = os.path.realpath(current_link)

        bundle_name = canonical_directory.rpartition("/")[2]
        if canonical_directory.rpartition("/")[0] != canonical_root:
            raise DeploymentError(
                f"active deployment resolves outside the deployment root: {canonical_directory}"
            )
        # The resolved basename meets the bundle namespace here as well, so a
        # launch refuses a directory carrying one of the root's own names before
        # it hands the name to verification.
        if not bundle_name_is_valid(bundle_name):
            raise DeploymentError(
                "active deployment name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid "
                f"the root names: {bundle_name}"
            )
        verify_bundle(root, bundle_name)
    finally:
        os.close(descriptor)

    directory = Path(canonical_directory)
    router_presets = directory / "router-presets.ini"
    web_presets = directory / "web-presets.ini"
    return ActiveDeployment(
        directory=directory,
        name=bundle_name,
        server=directory / "llama-server",
        ledger=directory / "ctx-checkpoints.tsv",
        manifest=directory / "bundle-manifest.tsv",
        router_presets=router_presets if router_presets.is_file() else None,
        web_presets=web_presets if web_presets.is_file() else None,
    )


def render(active: ActiveDeployment) -> str:
    """The seven `active_deployment_*=` lines a launch reads, an absent preset `-`."""
    return "".join(
        f"{key}={value}\n"
        for key, value in (
            ("active_deployment_directory", active.directory),
            ("active_deployment_name", active.name),
            ("active_deployment_server", active.server),
            ("active_deployment_ledger", active.ledger),
            ("active_deployment_manifest", active.manifest),
            ("active_deployment_router_presets", active.router_presets or "-"),
            ("active_deployment_web_presets", active.web_presets or "-"),
        )
    )
