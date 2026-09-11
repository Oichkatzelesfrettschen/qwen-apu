"""Parity between remote/download-*.sh pins and the Python install layer.

Three claims are checked here. First, every remote/download-*.sh script's own
pin -- whichever form it carries, an inline `expected_bytes=`/`expected_sha256=`
pair, a `model-artifact-identity.sh` lookup, or a `fetch_one` call inside
download-sdxs-512.sh -- equals the row `remote/model-artifacts.tsv` or
`remote/image-artifacts.tsv` carries for that same artifact, so the two
ledgers this repository ships never drift from the shell scripts that read
one of them. Second, `qwen_apu.install.downloads.fetch` reproduces a download
script's own file mechanics -- the already-verified short circuit, `.part`
resume and its oversized-partial refusal, and the completed digest check --
against a local `http.server` instance rather than the network. Third, every
id `config/model-groups.toml` names resolves against `remote/models.tsv` or
`remote/image-artifacts.tsv`, and `qwen_apu.install.models.resolve_group`,
`install`, and `verify` carry that resolution through to a concrete plan.
"""

from __future__ import annotations

import hashlib
import http.server
import re
import threading
from collections.abc import Iterator
from pathlib import Path

import pytest

from qwen_apu.config.models import load_model_artifacts, load_models
from qwen_apu.config.schema import ModelArtifact
from qwen_apu.install import models as install_models
from qwen_apu.install.downloads import DownloadError, fetch
from qwen_apu.install.models import (
    ArtifactPlan,
    ImageArtifactRow,
    ModelGroupError,
    install,
    load_groups,
    load_image_artifacts,
    resolve_group,
    verify,
)
from qwen_apu.runtime.paths import RuntimePaths

TREE = Path(__file__).resolve().parents[1]
REMOTE = TREE / "remote"
DOWNLOAD_SCRIPTS = sorted(REMOTE.glob("download-*.sh"))

# Scripts whose pin is read out of remote/model-artifacts.tsv through
# remote/model-artifact-identity.sh rather than carried inline, keyed by the
# model_id the identity lookup uses.
IDENTITY_SCRIPTS: dict[str, str] = {
    "download-qwen35-08b-q80.sh": "qwen35-08b",
    "download-qwen38-2b-distill-q4km.sh": "qwen38-2b-distill",
    "download-qwen38-4b-distill-q4km.sh": "qwen38-4b-distill",
}

# Scripts whose artifacts live in remote/image-artifacts.tsv instead, keyed
# by the fetch_script column value that ledger carries for their rows.
IMAGE_SCRIPTS: frozenset[str] = frozenset(
    {
        "download-lcm-lora-sd15.sh",
        "download-sd-turbo.sh",
        "download-sd15-base.sh",
        "download-sd15-vae.sh",
        "download-sdxs-512.sh",
    }
)

# remote/download-quality-photo.sh pins a Wikimedia fixture by URL, byte
# count, and SHA-256 alone -- no HuggingFace repository or revision pair --
# so it carries no row in either ledger; remote/model-artifacts.tsv's own
# header comment states the same exclusion.
UNPINNED_SCRIPTS: frozenset[str] = frozenset({"download-quality-photo.sh"})

# Every model_id remote/model-artifacts.tsv carries for one of the inline
# (non-identity, non-image) download scripts above, in the order the script
# list itself appears.
SCRIPT_MODEL_ID: dict[str, str] = {
    "download-lfm25-vl-16b-mmproj.sh": "lfm25-vl-16b-mmproj",
    "download-lfm25-vl-16b-q4km.sh": "lfm25-vl-16b",
    "download-minicpm5-1b-q80.sh": "minicpm5-1b",
    "download-minicpm5-fable5-v2-q80.sh": "minicpm5-1b-fable5-v2",
    "download-ministral3-3b-mmproj.sh": "ministral3-3b-mmproj",
    "download-ministral3-3b-q4km.sh": "ministral3-3b",
    "download-nanbeige42-3b-q4km.sh": "nanbeige42-3b",
    "download-qwen35-08b-bf16.sh": "qwen35-08b-bf16",
    "download-qwen35-08b-unsloth-unc-q4km.sh": "qwen35-08b-unsloth-unc",
    "download-qwen35-2b-hauhau-q4km.sh": "qwen35-2b-hauhau",
    "download-qwen35-2b-heretic-q4km.sh": "qwen35-2b-heretic",
    "download-qwen35-2b-mmproj.sh": "qwen35-2b-mmproj",
    "download-qwen35-2b-q4km.sh": "qwen35-2b",
    "download-qwen35-2b-unredacted-q4km.sh": "qwen35-2b-unredacted",
    "download-qwen35-4b-mmproj.sh": "qwen35-4b-base-mmproj",
    "download-qwen35-4b-q4km.sh": "qwen35-4b-base",
    "download-qwen35-9b-defiant-fable-iq2m.sh": "qwen35-9b-defiant-fable",
    "download-qwen38-2b-distill-bf16.sh": "qwen38-2b-distill-bf16",
    "download-qwen38-2b-uncensored-q4km.sh": "qwen38-2b-uncensored",
    "download-qwen38-4b-distill-i1-iq3s.sh": "qwen38-4b-i1-iq3s",
    "download-qwen38-4b-distill-i1-q2k.sh": "qwen38-4b-i1-q2k",
    "download-qwen38-4b-distill-i1-q5km.sh": "qwen38-4b-i1-q5km",
    "download-qwen38-4b-distill-i1-q6k.sh": "qwen38-4b-i1-q6k",
    "download-qwen38-9b-distill-q4km.sh": "qwen38-9b-distill",
    "download-qwenseer-2b-q4km.sh": "qwenseer-2b",
}

# download-qwen38-27b-ladder.sh fetches whichever of four variants its
# argument names, each pinned in benchmarks/models/qwen38-27b-files.tsv
# rather than inline; this maps that manifest's own variant column to the
# model_id remote/model-artifacts.tsv carries for it.
LADDER_VARIANT_MODEL_ID: dict[str, str] = {
    "UD-Q2_K_XL": "qwen38-27b-q2kxl",
    "UD-IQ3_XXS": "qwen38-27b-iq3xxs",
    "UD-IQ3_S": "qwen38-27b-iq3s",
    "UD-IQ4_XS": "qwen38-27b-iq4xs",
}


def _assignment(text: str, name: str) -> str | None:
    match = re.search(rf"^{re.escape(name)}=(\S+)$", text, re.MULTILINE)
    return match.group(1) if match else None


def _inline_pin(script: Path) -> tuple[str, str, str, str]:
    """The (bytes, sha256, repository, revision) tuple one inline script carries."""
    text = script.read_text(encoding="utf-8")
    expected_bytes = _assignment(text, "expected_bytes")
    expected_sha256 = _assignment(text, "expected_sha256")
    source_revision = _assignment(text, "source_revision")
    source_repository = _assignment(text, "source_repository")
    assert expected_bytes is not None, script
    assert expected_sha256 is not None, script
    assert source_revision is not None, script
    if source_repository is None:
        # qwen35-4b-mmproj.sh and qwen35-4b-q4km.sh spell the repository
        # directly in source_url rather than in its own assignment.
        url_match = re.search(r"https://huggingface\.co/([^/]+/[^/]+)/resolve/", text)
        assert url_match is not None, script
        source_repository = url_match.group(1)
    return expected_bytes, expected_sha256, source_repository, source_revision


@pytest.fixture(scope="module")
def model_artifacts() -> dict[str, ModelArtifact]:
    return {row.model_id: row for row in load_model_artifacts()}


@pytest.fixture(scope="module")
def image_artifacts() -> dict[str, ImageArtifactRow]:
    return {row.artifact_id: row for row in load_image_artifacts()}


def test_every_download_script_is_classified() -> None:
    classified = (
        set(IDENTITY_SCRIPTS) | IMAGE_SCRIPTS | UNPINNED_SCRIPTS | set(SCRIPT_MODEL_ID)
    ) | {"download-qwen38-27b-ladder.sh"}
    names = {script.name for script in DOWNLOAD_SCRIPTS}
    assert names == classified


@pytest.mark.parametrize("script_name,model_id", sorted(IDENTITY_SCRIPTS.items()))
def test_identity_script_ledger_row_exists(
    script_name: str, model_id: str, model_artifacts: dict[str, ModelArtifact]
) -> None:
    assert model_id in model_artifacts


@pytest.mark.parametrize("script_name,model_id", sorted(SCRIPT_MODEL_ID.items()))
def test_inline_script_pin_matches_ledger(
    script_name: str, model_id: str, model_artifacts: dict[str, ModelArtifact]
) -> None:
    script = REMOTE / script_name
    expected_bytes, expected_sha256, source_repository, source_revision = _inline_pin(script)
    row = model_artifacts[model_id]
    assert row.expected_bytes == int(expected_bytes)
    assert row.expected_sha256 == expected_sha256
    assert row.source_repository == source_repository
    assert row.source_revision == source_revision


def test_ladder_manifest_matches_ledger(model_artifacts: dict[str, ModelArtifact]) -> None:
    manifest = TREE / "benchmarks" / "models" / "qwen38-27b-files.tsv"
    lines = manifest.read_text(encoding="utf-8").splitlines()
    header, *rows = lines
    assert header.split("\t") == ["variant", "filename", "bytes", "sha256"]
    seen: set[str] = set()
    for row in rows:
        variant, filename, expected_bytes, expected_sha256 = row.split("\t")
        model_id = LADDER_VARIANT_MODEL_ID[variant]
        seen.add(model_id)
        ledger_row = model_artifacts[model_id]
        assert ledger_row.expected_bytes == int(expected_bytes)
        assert ledger_row.expected_sha256 == expected_sha256
        assert ledger_row.model_file.endswith(filename)
    assert seen == set(LADDER_VARIANT_MODEL_ID.values())


@pytest.mark.parametrize("script_name", sorted(IMAGE_SCRIPTS - {"download-sdxs-512.sh"}))
def test_single_file_image_script_matches_image_ledger(
    script_name: str, image_artifacts: dict[str, ImageArtifactRow]
) -> None:
    expected_bytes, expected_sha256, source_repository, source_revision = _inline_pin(
        REMOTE / script_name
    )
    matches = [row for row in image_artifacts.values() if row.fetch_script == script_name]
    assert matches, script_name
    for row in matches:
        assert row.bytes == int(expected_bytes)
        assert row.sha256 == expected_sha256
        assert row.repository == source_repository
        assert row.revision == source_revision


def test_sdxs512_script_matches_image_ledger(image_artifacts: dict[str, ImageArtifactRow]) -> None:
    text = (REMOTE / "download-sdxs-512.sh").read_text(encoding="utf-8")
    calls = re.findall(
        r"fetch_one (\S+) (\d+) \\\n\s+(\S+)",
        text,
    )
    assert len(calls) == 3
    source_repository = _assignment(text, "source_repository")
    source_revision = _assignment(text, "source_revision")
    by_filename = {
        row.filename: row
        for row in image_artifacts.values()
        if row.fetch_script == "download-sdxs-512.sh"
    }
    assert len(by_filename) == 3
    for filename, expected_bytes, expected_sha256 in calls:
        row = by_filename[filename]
        assert row.bytes == int(expected_bytes)
        assert row.sha256 == expected_sha256
        assert row.repository == source_repository
        assert row.revision == source_revision


def test_quality_photo_script_carries_no_ledger_row(
    model_artifacts: dict[str, ModelArtifact], image_artifacts: dict[str, ImageArtifactRow]
) -> None:
    text = (REMOTE / "download-quality-photo.sh").read_text(encoding="utf-8")
    assert "huggingface.co" not in text
    assert "quality-photo" not in model_artifacts
    assert "quality-photo" not in image_artifacts


def test_model_artifact_ledger_row_count() -> None:
    assert len(load_model_artifacts()) == 32


# ---------------------------------------------------------------------------
# qwen_apu.install.downloads.fetch
# ---------------------------------------------------------------------------


class _RangeAwareHandler(http.server.BaseHTTPRequestHandler):
    """Serves BODY, honoring a Range request the way huggingface.co's CDN does."""

    body: bytes = b""

    def do_GET(self) -> None:  # noqa: N802
        body = type(self).body
        range_header = self.headers.get("Range")
        if range_header is None:
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        match = re.fullmatch(r"bytes=(\d+)-", range_header)
        assert match is not None
        start = int(match.group(1))
        chunk = body[start:]
        self.send_response(206)
        self.send_header("Content-Length", str(len(chunk)))
        self.end_headers()
        self.wfile.write(chunk)

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        return


@pytest.fixture()
def artifact_server() -> Iterator[tuple[str, bytes, str]]:
    body = b"qwen-apu fixture artifact bytes" * 4096
    sha256 = hashlib.sha256(body).hexdigest()

    class Handler(_RangeAwareHandler):
        pass

    Handler.body = body
    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{port}/artifact.bin", body, sha256
    finally:
        server.shutdown()
        thread.join()


def test_fetch_downloads_and_verifies(
    tmp_path: Path, artifact_server: tuple[str, bytes, str]
) -> None:
    url, body, sha256 = artifact_server
    destination = tmp_path / "models" / "artifact.bin"
    result = fetch(url, destination, len(body), sha256)
    assert result.status == "downloaded"
    assert destination.read_bytes() == body
    assert not destination.with_name(destination.name + ".part").exists()


def test_fetch_already_verified_short_circuits(
    tmp_path: Path, artifact_server: tuple[str, bytes, str]
) -> None:
    url, body, sha256 = artifact_server
    destination = tmp_path / "artifact.bin"
    destination.write_bytes(body)
    result = fetch(url, destination, len(body), sha256)
    assert result.status == "already_verified"


def test_fetch_resumes_a_smaller_partial(
    tmp_path: Path, artifact_server: tuple[str, bytes, str]
) -> None:
    url, body, sha256 = artifact_server
    destination = tmp_path / "artifact.bin"
    partial = destination.with_name(destination.name + ".part")
    partial.parent.mkdir(parents=True, exist_ok=True)
    partial.write_bytes(body[: len(body) // 2])
    result = fetch(url, destination, len(body), sha256)
    assert result.status == "downloaded"
    assert destination.read_bytes() == body


def test_fetch_refuses_an_oversized_partial(
    tmp_path: Path, artifact_server: tuple[str, bytes, str]
) -> None:
    url, body, sha256 = artifact_server
    destination = tmp_path / "artifact.bin"
    partial = destination.with_name(destination.name + ".part")
    partial.parent.mkdir(parents=True, exist_ok=True)
    partial.write_bytes(body + b"extra")
    with pytest.raises(DownloadError, match="exceeds expected size"):
        fetch(url, destination, len(body), sha256)


def test_fetch_refuses_a_digest_mismatch(
    tmp_path: Path, artifact_server: tuple[str, bytes, str]
) -> None:
    url, body, sha256 = artifact_server
    destination = tmp_path / "artifact.bin"
    with pytest.raises(DownloadError, match="SHA-256 mismatch"):
        fetch(url, destination, len(body), "0" * 64)


def test_fetch_resume_false_discards_an_existing_partial(
    tmp_path: Path, artifact_server: tuple[str, bytes, str]
) -> None:
    url, body, sha256 = artifact_server
    destination = tmp_path / "artifact.bin"
    partial = destination.with_name(destination.name + ".part")
    partial.parent.mkdir(parents=True, exist_ok=True)
    partial.write_bytes(b"stale bytes that do not belong")
    result = fetch(url, destination, len(body), sha256, resume=False)
    assert result.status == "downloaded"
    assert destination.read_bytes() == body


# ---------------------------------------------------------------------------
# config/model-groups.toml and qwen_apu.install.models
# ---------------------------------------------------------------------------


def test_every_group_member_resolves_against_a_ledger() -> None:
    groups = load_groups()
    model_ids = {row.id for row in load_models()}
    image_ids = {row.artifact_id for row in load_image_artifacts()}
    for name, members in groups.items():
        universe = image_ids if name == "image" else model_ids
        for member in members:
            assert member in universe, f"{name}: {member} names no ledger row"


def test_all_is_the_union_of_every_group() -> None:
    groups = load_groups()
    models_dir = TREE / "nonexistent-models-dir"
    plans = resolve_group(["all"], models_dir=models_dir)
    plan_ids = {plan.artifact_id for plan in plans}
    for members in groups.values():
        for member in members:
            assert member in plan_ids


def test_core_group_resolves_three_fetch_plans() -> None:
    plans = resolve_group(["core"], models_dir=TREE / "nonexistent-models-dir")
    assert {plan.artifact_id for plan in plans} == {
        "qwen35-08b",
        "qwen38-2b-distill",
        "qwen38-4b-distill",
    }
    assert all(plan.kind == "fetch" for plan in plans)


def test_vision_group_pulls_its_projectors() -> None:
    plans = resolve_group(["vision"], models_dir=TREE / "nonexistent-models-dir")
    ids = {plan.artifact_id for plan in plans}
    assert ids == {
        "qwen35-4b-base",
        "qwen35-4b-base-mmproj",
        "qwen35-2b",
        "qwen35-2b-mmproj",
        "lfm25-vl-16b",
        "lfm25-vl-16b-mmproj",
    }


def test_research_group_pulls_ministral_projector_too() -> None:
    plans = resolve_group(["research"], models_dir=TREE / "nonexistent-models-dir")
    ids = {plan.artifact_id for plan in plans}
    assert "ministral3-3b" in ids
    assert "ministral3-3b-mmproj" in ids


def test_personalities_group_includes_the_derived_f16_rung() -> None:
    plans = resolve_group(["personalities"], models_dir=TREE / "nonexistent-models-dir")
    by_id = {plan.artifact_id: plan for plan in plans}
    assert by_id["qwen35-08b-f16"].kind == "derive"
    assert by_id["qwen35-08b-f16"].expected_bytes is None


def test_image_group_resolves_the_three_sdxs_components() -> None:
    plans = resolve_group(["image"], models_dir=TREE / "nonexistent-models-dir")
    ids = {plan.artifact_id for plan in plans}
    assert ids == {"sdxs-512-diffusion", "sdxs-512-vae", "sdxs-512-text-encoder"}
    for plan in plans:
        assert plan.destination.parent.name in {"unet", "vae", "text_encoder"}
        assert plan.destination.parent.parent.name == "sdxs-512"


def test_unknown_group_name_refuses() -> None:
    with pytest.raises(ModelGroupError):
        resolve_group(["not-a-group"], models_dir=TREE / "nonexistent-models-dir")


def test_install_dry_run_reports_without_fetching(tmp_path: Path) -> None:
    runtime = RuntimePaths.resolve(tree=tmp_path)
    runtime.lay_out()
    outcomes = install(runtime, ["core"], dry_run=True)
    ids = {outcome.artifact_id for outcome in outcomes}
    assert ids == {"qwen35-08b", "qwen38-2b-distill", "qwen38-4b-distill"}
    assert all(outcome.status == "dry_run" for outcome in outcomes)
    assert all(not outcome.destination.exists() for outcome in outcomes)


def test_verify_reports_absent_before_any_fetch(tmp_path: Path) -> None:
    runtime = RuntimePaths.resolve(tree=tmp_path)
    runtime.lay_out()
    outcomes = verify(runtime, ["core"])
    assert all(outcome.status == "absent" for outcome in outcomes)


def test_verify_reports_derive_required_without_stating(tmp_path: Path) -> None:
    runtime = RuntimePaths.resolve(tree=tmp_path)
    runtime.lay_out()
    outcomes = verify(runtime, ["personalities"])
    by_id = {outcome.artifact_id: outcome for outcome in outcomes}
    assert by_id["qwen35-08b-f16"].status == "derive_required"


def test_verify_detects_bytes_and_digest_mismatch(tmp_path: Path) -> None:
    runtime = RuntimePaths.resolve(tree=tmp_path)
    runtime.lay_out()
    plans = resolve_group(["core"], models_dir=runtime["qwen_home_models"])
    target = next(plan for plan in plans if plan.artifact_id == "qwen35-08b")
    target.destination.parent.mkdir(parents=True, exist_ok=True)
    assert target.expected_bytes is not None
    target.destination.write_bytes(b"0" * target.expected_bytes)
    outcomes = verify(runtime, ["core"])
    by_id = {outcome.artifact_id: outcome for outcome in outcomes}
    assert by_id["qwen35-08b"].status == "digest-differs"


def test_verify_reports_verified_over_a_matching_fixture(tmp_path: Path) -> None:
    runtime = RuntimePaths.resolve(tree=tmp_path)
    runtime.lay_out()
    plans = resolve_group(["core"], models_dir=runtime["qwen_home_models"])
    target = next(plan for plan in plans if plan.artifact_id == "qwen35-08b")
    target.destination.parent.mkdir(parents=True, exist_ok=True)
    body = b"x" * 17
    digest = hashlib.sha256(body).hexdigest()
    object.__setattr__(target, "expected_bytes", len(body))
    object.__setattr__(target, "expected_sha256", digest)
    target.destination.write_bytes(body)

    def fake_resolve_group(
        names: list[str], *, models_dir: Path, groups_path: Path | None = None, **_: object
    ) -> list[ArtifactPlan]:
        return plans

    original = install_models.resolve_group
    install_models.resolve_group = fake_resolve_group
    try:
        outcomes = verify(runtime, ["core"])
    finally:
        install_models.resolve_group = original
    by_id = {outcome.artifact_id: outcome for outcome in outcomes}
    assert by_id["qwen35-08b"].status == "verified"
