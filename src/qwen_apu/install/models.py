"""Group-scoped model and projector install, reading config/model-groups.toml.

`resolve_group` turns a list of TOML group names into one deduplicated list
of `ArtifactPlan`s: for every remote/models.tsv row the groups name, it reads
the row's own pin from remote/model-artifacts.tsv (`qwen_apu.config.models`),
adds the row's projector where `projector == "required"`, and for the `image`
group reads remote/image-artifacts.tsv directly, since that ledger's
component_type and license columns carry a claim the six-column model
ledger's schema has no room for -- the same split
remote/model-artifacts.tsv's own header comment states. `install` fetches
each plan through `qwen_apu.install.downloads.fetch`; `verify` checks an
already-installed plan's bytes and digest without reaching the network, the
same two-step split remote/verify-models.sh's own docstring names.

Two renamed-filename gaps the six-column ledger schema cannot carry directly
are resolved here instead of by adding a seventh column. `derive-qwen35-08b-f16.sh`
produces `qwen35-08b-f16` from the already-fetched `qwen35-08b-bf16` through
`llama-quantize` rather than a network fetch, so a models.tsv row whose
`fetch_script` does not match `download-*.sh` resolves to a `derive`-kind plan
carrying no URL or pin; `install` and `verify` report it as `derive_required`
rather than raising. Nine remaining artifacts (`SOURCE_FILENAME_OVERRIDE`)
publish under a HuggingFace resolve-path filename that differs from the local
`model_file` basename the download script writes -- `ministral3-3b`, for
instance, resolves as `mistralai_Ministral-3-3B-Instruct-2512-Q4_K_M.gguf` and
lands as `Ministral-3-3B-Instruct-Q4_K_M.gguf`. Adding a seventh ledger column
for that filename would change every row's field count, and the three
scripts that source their pin through remote/model-artifact-identity.sh
(`read -r _model_id model_file expected_bytes expected_sha256 source_repository
source_revision`) hold six variables apiece: a seventh tab-separated field
would land inside `source_revision` rather than its own variable, and this
package's instructions forbid touching those download scripts to add a
seventh. The override table carries the publisher filename as install-only
metadata instead, leaving the ledger's identity columns -- the byte count and
the digest that verify a fetch -- exactly as wide as every other row.
"""

from __future__ import annotations

import tomllib
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from qwen_apu.config.loader import read_ledger, require_columns, tree_root
from qwen_apu.config.models import load_model_artifacts, load_models, load_quarantine
from qwen_apu.config.schema import ModelArtifact, ModelRow, QuarantineRow
from qwen_apu.install.downloads import DownloadError, FetchResult, fetch, sha256_file
from qwen_apu.runtime.paths import RuntimePaths

GROUPS_PATH = tree_root() / "config" / "model-groups.toml"
IMAGE_ARTIFACTS_PATH = tree_root() / "remote" / "image-artifacts.tsv"

IMAGE_ARTIFACT_FIELDS: tuple[str, ...] = (
    "artifact_id",
    "repository",
    "revision",
    "filename",
    "sha256",
    "bytes",
    "license",
    "component_type",
    "fetch_script",
)

# A models.tsv row's projector_fetch_script names a download script rather
# than a remote/model-artifacts.tsv model_id, so this table carries the
# mapping for the four projectors any admitted group can pull in. A group
# member outside this table and outside DOWNLOAD_SCRIPT_PREFIX's match is a
# gap `resolve_group` refuses rather than silently skips.
PROJECTOR_ARTIFACT_BY_FETCH_SCRIPT: dict[str, str] = {
    "download-qwen35-2b-mmproj.sh": "qwen35-2b-mmproj",
    "download-lfm25-vl-16b-mmproj.sh": "lfm25-vl-16b-mmproj",
    "download-qwen35-4b-mmproj.sh": "qwen35-4b-base-mmproj",
    "download-ministral3-3b-mmproj.sh": "ministral3-3b-mmproj",
}

# model_id -> the publisher's own resolve-path filename, for the rows whose
# download script writes a local name the publisher did not use. Absent from
# this table means the resolve-path filename equals model_file's basename,
# the case remote/model-artifact-identity.sh's three readers already assume.
SOURCE_FILENAME_OVERRIDE: dict[str, str] = {
    "ministral3-3b-mmproj": "mmproj-mistralai_Ministral-3-3B-Instruct-2512-f16.gguf",
    "ministral3-3b": "mistralai_Ministral-3-3B-Instruct-2512-Q4_K_M.gguf",
    "qwen35-08b-bf16": "Qwen_Qwen3.5-0.8B-bf16.gguf",
    "qwen35-2b-mmproj": "mmproj-Qwen_Qwen3.5-2B-f16.gguf",
    "qwen35-2b": "Qwen_Qwen3.5-2B-Q4_K_M.gguf",
    "qwen38-4b-i1-iq3s": "Qwen3.8-4B-Distill.i1-IQ3_S.gguf",
    "qwen38-4b-i1-q2k": "Qwen3.8-4B-Distill.i1-Q2_K.gguf",
    "qwen38-4b-i1-q5km": "Qwen3.8-4B-Distill.i1-Q5_K_M.gguf",
    "qwen38-4b-i1-q6k": "Qwen3.8-4B-Distill.i1-Q6_K.gguf",
}

PlanKind = Literal["fetch", "derive", "withheld"]


class ModelGroupError(RuntimeError):
    """A group name, member id, or cross-ledger reference this module cannot resolve."""


@dataclass(frozen=True, slots=True)
class ImageArtifactRow:
    """One row of remote/image-artifacts.tsv, the columns install.py reads."""

    artifact_id: str
    repository: str
    revision: str
    filename: str
    sha256: str
    bytes: int
    fetch_script: str


@dataclass(frozen=True, slots=True)
class ArtifactPlan:
    """One artifact resolve_group admits: its identity, pin, URL, and install path.

    `kind == "derive"` carries no pin or URL -- `expected_bytes`,
    `expected_sha256`, and `url` are `None` -- because the artifact is
    produced on the appliance rather than fetched.

    `kind == "withheld"` carries no pin or URL for a different reason: a
    model-scope row of remote/quarantine.tsv excludes the checkpoint, its
    weights are absent from the appliance disk by decision, and
    `withheld_failure_class` and `withheld_record` carry the row's own reason
    so a refusal names it. The plan still resolves, because `verify` reports
    the state and `install` refuses it, and a refusal raised inside
    `resolve_group` would leave `verify` unable to answer at all.
    """

    artifact_id: str
    kind: PlanKind
    destination: Path
    expected_bytes: int | None
    expected_sha256: str | None
    url: str | None
    source_repository: str | None
    source_revision: str | None
    withheld_failure_class: str | None = None
    withheld_record: str | None = None


@dataclass(frozen=True, slots=True)
class InstallOutcome:
    artifact_id: str
    status: str
    destination: Path


@dataclass(frozen=True, slots=True)
class VerifyOutcome:
    artifact_id: str
    status: str
    destination: Path


def withheld_subjects(
    quarantine: Sequence[QuarantineRow] | None = None,
) -> dict[str, QuarantineRow]:
    """Every checkpoint remote/quarantine.tsv excludes at model scope, by subject.

    A `profile` scope row excludes one serving tuple of a checkpoint whose
    weights the appliance still holds, so it names no withholding and stays
    out of this index.
    """
    rows = quarantine if quarantine is not None else load_quarantine()
    return {row.subject: row for row in rows if row.scope == "model"}


def _withheld_plan(artifact_id: str, destination: Path, row: QuarantineRow) -> ArtifactPlan:
    return ArtifactPlan(
        artifact_id=artifact_id,
        kind="withheld",
        destination=destination,
        expected_bytes=None,
        expected_sha256=None,
        url=None,
        source_repository=None,
        source_revision=None,
        withheld_failure_class=row.failure_class,
        withheld_record=row.reason_record,
    )


def withheld_refusal(plan: ArtifactPlan) -> str:
    """The one-line refusal a withheld plan produces, naming the row and its reason."""
    return (
        f"{plan.artifact_id}: remote/quarantine.tsv withholds the checkpoint at model "
        f"scope, reason {plan.withheld_failure_class}, record {plan.withheld_record}"
    )


def load_groups(path: Path | None = None) -> dict[str, tuple[str, ...]]:
    """Every named group in config/model-groups.toml, as an id tuple."""
    resolved = path or GROUPS_PATH
    with resolved.open("rb") as handle:
        document = tomllib.load(handle)
    groups_table = document.get("groups", {})
    if not isinstance(groups_table, dict):
        raise ModelGroupError(f"{resolved}: [groups] is not a table")
    groups: dict[str, tuple[str, ...]] = {}
    for name, members in groups_table.items():
        if not isinstance(members, list) or not all(isinstance(m, str) for m in members):
            raise ModelGroupError(f"{resolved}: group {name!r} is not a list of strings")
        groups[name] = tuple(members)
    return groups


def load_image_artifacts(path: Path | None = None) -> tuple[ImageArtifactRow, ...]:
    """Every remote/image-artifacts.tsv row, validated the way the model ledger reader is."""
    resolved = path or IMAGE_ARTIFACTS_PATH
    table = read_ledger(resolved, key_index=0)
    require_columns(table, IMAGE_ARTIFACT_FIELDS)
    rows: list[ImageArtifactRow] = []
    for line_number, fields in table.rows:
        row_key = f"image artifact ledger line {line_number}"
        bytes_raw = fields[5]
        if not bytes_raw.isdigit() or bytes_raw == "":
            raise ModelGroupError(f"{row_key} carries a non-numeric bytes field: {bytes_raw}")
        rows.append(
            ImageArtifactRow(
                artifact_id=fields[0],
                repository=fields[1],
                revision=fields[2],
                filename=fields[3],
                sha256=fields[4],
                bytes=int(bytes_raw),
                fetch_script=fields[8],
            )
        )
    return tuple(rows)


def _image_destination_directory(fetch_script: str) -> str:
    """The `image/NAME` directory every remote/download-*.sh image script writes into.

    `NAME` is the script's own basename with the `download-` prefix and
    `.sh` suffix removed -- `download-sdxs-512.sh` writes
    `$qwen_home_models/image/sdxs-512`, and every other image download script
    follows the identical rule.
    """
    name = fetch_script
    if name.startswith("download-"):
        name = name[len("download-") :]
    if name.endswith(".sh"):
        name = name[: -len(".sh")]
    return f"image/{name}"


def _huggingface_url(repository: str, revision: str, filename: str) -> str:
    return f"https://huggingface.co/{repository}/resolve/{revision}/{filename}?download=true"


def _model_plan(
    row: ModelRow, artifacts: dict[str, ModelArtifact], models_dir: Path
) -> ArtifactPlan:
    pin = artifacts.get(row.id)
    if pin is None:
        if row.fetch_script.startswith("derive-"):
            first_component = row.model_file.split("/", 1)[0]
            destination = models_dir / first_component / Path(row.model_file).name
            return ArtifactPlan(
                artifact_id=row.id,
                kind="derive",
                destination=destination,
                expected_bytes=None,
                expected_sha256=None,
                url=None,
                source_repository=None,
                source_revision=None,
            )
        raise ModelGroupError(
            f"{row.id}: no remote/model-artifacts.tsv row and fetch_script "
            f"{row.fetch_script!r} names no derive step"
        )
    first_component = pin.model_file.split("/", 1)[0]
    destination = models_dir / first_component / Path(pin.model_file).name
    filename = SOURCE_FILENAME_OVERRIDE.get(row.id, Path(pin.model_file).name)
    url = _huggingface_url(pin.source_repository, pin.source_revision, filename)
    return ArtifactPlan(
        artifact_id=row.id,
        kind="fetch",
        destination=destination,
        expected_bytes=pin.expected_bytes,
        expected_sha256=pin.expected_sha256,
        url=url,
        source_repository=pin.source_repository,
        source_revision=pin.source_revision,
    )


def model_plan(
    row: ModelRow, artifacts: Mapping[str, ModelArtifact], models_dir: Path
) -> ArtifactPlan:
    """The install destination and pin one registry row resolves to.

    `resolve_group` answers for a group; a launch names one checkpoint and needs
    the same composition of publisher directory, filename, and artifact pin. One
    reader keeps a launch reading the leaf a fetch wrote.
    """
    return _model_plan(row, dict(artifacts), models_dir)


def _projector_plan(
    row: ModelRow, artifacts: dict[str, ModelArtifact], models_dir: Path
) -> ArtifactPlan:
    script = row.projector_fetch_script
    if script is None:
        raise ModelGroupError(f"{row.id}: projector is required but names no fetch script")
    artifact_id = PROJECTOR_ARTIFACT_BY_FETCH_SCRIPT.get(script)
    if artifact_id is None:
        raise ModelGroupError(
            f"{row.id}: projector fetch script {script!r} has no artifact mapping"
        )
    pin = artifacts.get(artifact_id)
    if pin is None:
        raise ModelGroupError(f"{artifact_id}: no remote/model-artifacts.tsv row for projector")
    first_component = pin.model_file.split("/", 1)[0]
    destination = models_dir / first_component / Path(pin.model_file).name
    filename = SOURCE_FILENAME_OVERRIDE.get(artifact_id, Path(pin.model_file).name)
    url = _huggingface_url(pin.source_repository, pin.source_revision, filename)
    return ArtifactPlan(
        artifact_id=artifact_id,
        kind="fetch",
        destination=destination,
        expected_bytes=pin.expected_bytes,
        expected_sha256=pin.expected_sha256,
        url=url,
        source_repository=pin.source_repository,
        source_revision=pin.source_revision,
    )


def _image_plan(image_row: ImageArtifactRow, models_dir: Path) -> ArtifactPlan:
    directory = _image_destination_directory(image_row.fetch_script)
    destination = models_dir / directory / image_row.filename
    url = _huggingface_url(image_row.repository, image_row.revision, image_row.filename)
    return ArtifactPlan(
        artifact_id=image_row.artifact_id,
        kind="fetch",
        destination=destination,
        expected_bytes=image_row.bytes,
        expected_sha256=image_row.sha256,
        url=url,
        source_repository=image_row.repository,
        source_revision=image_row.revision,
    )


def resolve_group(
    names: list[str],
    *,
    models_dir: Path,
    groups_path: Path | None = None,
    models: tuple[ModelRow, ...] | None = None,
    artifacts_by_id: dict[str, ModelArtifact] | None = None,
    image_rows: tuple[ImageArtifactRow, ...] | None = None,
    quarantine: Sequence[QuarantineRow] | None = None,
) -> list[ArtifactPlan]:
    """Every artifact plan `names` (group names, `all` accepted) admits, in file order.

    `all` expands to the union of every group in config/model-groups.toml
    rather than to a stored fourth group, so adding a group there reaches
    `all` immediately. A model row whose `projector` field reads `required`
    contributes its projector plan as well, regardless of which named group
    placed the row -- `research`'s own `ministral3-3b` carries the same
    requirement `vision`'s rows do.

    A row a model-scope quarantine row names resolves to a `withheld` plan,
    and so does the projector that row pulls in, since the projector encodes
    images into the embedding space of a checkpoint the appliance no longer
    holds. The plan carries the destination and no pin: `install` refuses it
    and `verify` reports `withheld` against the path the weights would occupy.
    """
    groups = load_groups(groups_path)
    resolved_names: list[str] = []
    for name in names:
        if name == "all":
            for group_name in groups:
                resolved_names.append(group_name)
        elif name in groups:
            resolved_names.append(name)
        else:
            raise ModelGroupError(f"unknown group: {name}")

    model_rows = models if models is not None else load_models()
    models_by_id = {row.id: row for row in model_rows}
    artifacts = (
        artifacts_by_id
        if artifacts_by_id is not None
        else {row.model_id: row for row in load_model_artifacts()}
    )
    images = image_rows if image_rows is not None else load_image_artifacts()
    images_by_id = {row.artifact_id: row for row in images}
    withheld = withheld_subjects(quarantine)

    plans: dict[str, ArtifactPlan] = {}
    for group_name in resolved_names:
        for member_id in groups[group_name]:
            if group_name == "image":
                image_row = images_by_id.get(member_id)
                if image_row is None:
                    raise ModelGroupError(f"{member_id}: no remote/image-artifacts.tsv row")
                plan = _image_plan(image_row, models_dir)
                plans.setdefault(plan.artifact_id, plan)
                continue
            row = models_by_id.get(member_id)
            if row is None:
                raise ModelGroupError(f"{member_id}: no remote/models.tsv row")
            withheld_row = withheld.get(member_id)
            plan = _model_plan(row, artifacts, models_dir)
            if withheld_row is not None:
                plan = _withheld_plan(plan.artifact_id, plan.destination, withheld_row)
            plans.setdefault(plan.artifact_id, plan)
            if row.projector == "required":
                projector_plan = _projector_plan(row, artifacts, models_dir)
                if withheld_row is not None:
                    projector_plan = _withheld_plan(
                        projector_plan.artifact_id, projector_plan.destination, withheld_row
                    )
                plans.setdefault(projector_plan.artifact_id, projector_plan)

    return list(plans.values())


def install(
    paths: RuntimePaths,
    names: list[str],
    *,
    dry_run: bool = False,
    groups_path: Path | None = None,
) -> list[InstallOutcome]:
    """Fetch every plan `resolve_group(names)` admits into `paths.qwen_home_models`.

    `dry_run` resolves and reports every plan's destination without touching
    the network or the filesystem, the same admission `qwen-launch.sh`'s own
    preflight performs before a privileged step runs. A `derive`-kind plan
    reports `derive_required` under either mode, since `install` reaches only
    through `qwen_apu.install.downloads.fetch`.

    A `withheld`-kind plan refuses the whole call before the first fetch,
    naming every withheld row and its reason. The refusal covers the group
    rather than the row because `names` is what the operator asked for: a
    group holding a withheld checkpoint is a request this appliance declines,
    and `all` is the union of the groups, so it declines too. Installing the
    servable rows means naming their groups.
    """
    models_dir = paths["qwen_home_models"]
    plans = resolve_group(names, models_dir=models_dir, groups_path=groups_path)
    refusals = [withheld_refusal(plan) for plan in plans if plan.kind == "withheld"]
    if refusals:
        raise ModelGroupError("; ".join(refusals))
    outcomes: list[InstallOutcome] = []
    for plan in plans:
        if plan.kind == "derive":
            outcomes.append(InstallOutcome(plan.artifact_id, "derive_required", plan.destination))
            continue
        if dry_run:
            outcomes.append(InstallOutcome(plan.artifact_id, "dry_run", plan.destination))
            continue
        assert plan.url is not None
        assert plan.expected_bytes is not None
        assert plan.expected_sha256 is not None
        try:
            result: FetchResult = fetch(
                plan.url, plan.destination, plan.expected_bytes, plan.expected_sha256
            )
        except DownloadError as exc:
            outcomes.append(InstallOutcome(plan.artifact_id, f"failed: {exc}", plan.destination))
            continue
        outcomes.append(InstallOutcome(plan.artifact_id, result.status, plan.destination))
    return outcomes


def verify(
    paths: RuntimePaths,
    names: list[str],
    *,
    groups_path: Path | None = None,
) -> list[VerifyOutcome]:
    """Check every plan's installed bytes and digest, fetching nothing.

    Reports the same vocabulary remote/verify-models.sh's own docstring
    names for a checked file: `verified`, `absent`, `bytes-differ`, or
    `digest-differs`. A `derive`-kind plan reports `derive_required`, since
    its destination is produced on the appliance rather than pinned here.

    A `withheld`-kind plan reports `withheld` rather than `absent`. The two
    states differ in what they ask of an operator: `absent` names a fetch that
    has yet to run, and `withheld` names a checkpoint whose weights are gone
    from the appliance disk by decision, so the file's absence is the intended
    state and a repair step would undo it.
    """
    models_dir = paths["qwen_home_models"]
    plans = resolve_group(names, models_dir=models_dir, groups_path=groups_path)
    outcomes: list[VerifyOutcome] = []
    for plan in plans:
        if plan.kind == "withheld":
            outcomes.append(VerifyOutcome(plan.artifact_id, "withheld", plan.destination))
            continue
        if plan.kind == "derive":
            outcomes.append(VerifyOutcome(plan.artifact_id, "derive_required", plan.destination))
            continue
        if not plan.destination.is_file():
            outcomes.append(VerifyOutcome(plan.artifact_id, "absent", plan.destination))
            continue
        assert plan.expected_bytes is not None
        assert plan.expected_sha256 is not None
        actual_bytes = plan.destination.stat().st_size
        if actual_bytes != plan.expected_bytes:
            outcomes.append(VerifyOutcome(plan.artifact_id, "bytes-differ", plan.destination))
            continue
        if sha256_file(plan.destination) != plan.expected_sha256:
            outcomes.append(VerifyOutcome(plan.artifact_id, "digest-differs", plan.destination))
            continue
        outcomes.append(VerifyOutcome(plan.artifact_id, "verified", plan.destination))
    return outcomes
