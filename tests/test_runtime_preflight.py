"""The three refusals that precede a child, each proven to leave the tree alone.

Four windows of the shadow deployment ended on the command side, and three of
them name a precondition a launch assumed: a checkpoint the runtime root does
not resolve, an absent signing key, and a key whose bytes the approvals reader
refuses. Each case below reproduces one of those windows against a fixture root
and requires the refusal to arrive before anything is written.
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path

import pytest

from qwen_apu.config.models import model_by_id
from qwen_apu.runtime import preflight
from qwen_apu.runtime.paths import RuntimePaths

TREE = Path(__file__).resolve().parents[1]

MODEL_ID = "qwen38-2b-distill"
PUBLISHER_DIRECTORY = "Qwen3.8-2B-Distill-GGUF"
# The one registry row whose fetch_script derives rather than downloads, so
# no publisher digest is recorded for it.
DERIVED_MODEL_ID = "qwen35-08b-f16"


@pytest.fixture
def root(tmp_path: Path) -> RuntimePaths:
    paths = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    paths.lay_out()
    return paths


def _install(paths: RuntimePaths, payload: bytes) -> Path:
    """Place the registry's own checkpoint where a fetch would have written it."""
    row = model_by_id(MODEL_ID)
    destination = paths["qwen_home_models"] / row.model_file
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(payload)
    return destination


def _artifacts_ledger(tmp_path: Path, payload: bytes) -> Path:
    """A one-row artifact ledger pinning the bytes just written."""
    row = model_by_id(MODEL_ID)
    ledger = tmp_path / "model-artifacts.tsv"
    header = "\t".join(
        (
            "model_id",
            "model_file",
            "expected_bytes",
            "expected_sha256",
            "source_repository",
            "source_revision",
        )
    )
    body = "\t".join(
        (
            MODEL_ID,
            row.model_file,
            str(len(payload)),
            hashlib.sha256(payload).hexdigest(),
            "fixture/repository",
            "0" * 40,
        )
    )
    ledger.write_text(f"# {header}\n{body}\n", encoding="utf-8")
    return ledger


# ---------------------------------------------------------------------------
# The model preflight
# ---------------------------------------------------------------------------


def test_a_verified_digest_reports_the_installed_path(root: RuntimePaths, tmp_path: Path) -> None:
    payload = b"gguf fixture weights"
    installed = _install(root, payload)
    report = preflight.resolve_model(
        root, MODEL_ID, artifacts_path=_artifacts_ledger(tmp_path, payload)
    )
    assert report.path == installed
    assert report.digest_state == "verified"
    assert report.bytes == len(payload)
    assert report.expected_sha256 == hashlib.sha256(payload).hexdigest()


def test_a_digest_that_disagrees_refuses_and_names_both(root: RuntimePaths, tmp_path: Path) -> None:
    ledger = _artifacts_ledger(tmp_path, b"the bytes the ledger measured")
    _install(root, b"the bytes the ledger measured, rewritten")
    with pytest.raises(preflight.ModelRefused) as refusal:
        preflight.resolve_model(root, MODEL_ID, artifacts_path=ledger)
    assert "bytes against the ledger's" in str(refusal.value)


def test_an_absent_checkpoint_refuses_before_a_digest_is_taken(
    root: RuntimePaths, tmp_path: Path
) -> None:
    """The window that linked the checkpoint where the root resolves nothing."""
    with pytest.raises(preflight.ModelRefused) as refusal:
        preflight.resolve_model(root, MODEL_ID, artifacts_path=_artifacts_ledger(tmp_path, b"x"))
    assert "is not installed at" in str(refusal.value)
    assert PUBLISHER_DIRECTORY in str(refusal.value)


def test_a_row_outside_the_registry_refuses(root: RuntimePaths) -> None:
    with pytest.raises(preflight.ModelRefused) as refusal:
        preflight.resolve_model(root, "a-checkpoint-no-publisher-ships")
    assert "no registry row" in str(refusal.value)


def test_a_derived_row_records_a_skip_rather_than_refusing(root: RuntimePaths) -> None:
    """A derived checkpoint has no publisher digest, so its absence is recorded.

    `remote/model-artifacts.tsv` pins what a publisher ships. `qwen35-08b-f16`
    is derived on the appliance from the publisher's BF16, so no pin exists to
    compare against and the report states `unrecorded` rather than refusing a
    file nothing measured.
    """
    payload = b"derived weights"
    row = model_by_id(DERIVED_MODEL_ID)
    destination = root["qwen_home_models"] / row.model_file
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(payload)
    report = preflight.resolve_model(root, DERIVED_MODEL_ID)
    assert report.path == destination
    assert report.digest_state == "unrecorded"
    assert report.expected_sha256 is None


# ---------------------------------------------------------------------------
# The signing key preflight
# ---------------------------------------------------------------------------


def _key(paths: RuntimePaths, content: bytes, mode: int = 0o600) -> Path:
    path = paths["qwen_home_web_token_key"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    os.chmod(path, mode)
    return path


def test_a_utf8_key_at_0600_reports_its_digest(root: RuntimePaths) -> None:
    content = b"c0ffee1234567890abcdef\n"
    path = _key(root, content)
    report = preflight.verify_signing_key(path)
    assert report.sha256 == hashlib.sha256(content).hexdigest()
    assert report.mode == 0o600


def test_an_absent_key_refuses(root: RuntimePaths) -> None:
    with pytest.raises(preflight.SigningKeyRefused):
        preflight.verify_signing_key(root["qwen_home_web_token_key"])


def test_a_group_readable_key_refuses(root: RuntimePaths) -> None:
    path = _key(root, b"a key\n", mode=0o640)
    with pytest.raises(preflight.SigningKeyRefused) as refusal:
        preflight.verify_signing_key(path)
    assert "0600" in str(refusal.value)


def test_random_bytes_refuse_because_the_reader_requires_utf8_text(root: RuntimePaths) -> None:
    """The window that wrote `head -c 32 /dev/urandom` into the key file.

    `read_secret_file` decodes the file as UTF-8 and takes the HMAC key from the
    stripped text, so a key of random bytes fails at the decode. Hexadecimal is
    not a rule the reader applies; UTF-8 text is.
    """
    path = _key(root, bytes([0xC3, 0x28, 0xA0, 0xA1]))
    with pytest.raises(preflight.SigningKeyRefused) as refusal:
        preflight.verify_signing_key(path)
    assert "UTF-8" in str(refusal.value)


def test_an_empty_key_refuses(root: RuntimePaths) -> None:
    path = _key(root, b"   \n")
    with pytest.raises(preflight.SigningKeyRefused):
        preflight.verify_signing_key(path)


# ---------------------------------------------------------------------------
# The deployment preflight
# ---------------------------------------------------------------------------


def test_an_empty_deployment_root_refuses(root: RuntimePaths) -> None:
    with pytest.raises(preflight.DeploymentRefused) as refusal:
        preflight.verify_deployment(root["qwen_home_deployments"])
    assert "deployment-current" in str(refusal.value) or "deployment root" in str(refusal.value)


def test_a_pointer_to_nothing_refuses_without_writing(root: RuntimePaths) -> None:
    deployments = root["qwen_home_deployments"]
    before = sorted(entry.name for entry in deployments.iterdir())
    (deployments / "deployment-current").symlink_to("a-bundle-that-was-removed")
    with pytest.raises(preflight.DeploymentRefused):
        preflight.verify_deployment(deployments)
    after = sorted(entry.name for entry in deployments.iterdir())
    # The activation lock is the one leaf the resolution opens, so the refusal
    # adds that and nothing else.
    assert set(after) - set(before) <= {"deployment-current", ".activate.lock"}
