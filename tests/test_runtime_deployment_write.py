"""Parity between qwen_apu.runtime.deployment_write and the deployment shell authorities.

Each case runs twice over one fixture: the Python transition raises or
publishes, and `remote/build-deployment-bundle.sh`,
`remote/activate-deployment-bundle.sh`, or
`remote/write-deployment-receipt.sh` answers the same way over the same bytes,
with the Python refusal text inside its stderr. The message containment is
what makes the pair a parity test rather than two independent refusals: a
Python check that refuses for another reason fails here even though both sides
refused.

The published artifacts are compared byte for byte. `bundle-manifest.tsv`
carries one row `date -u` supplies, so `created_utc` is compared by shape and
proximity and every other row by its bytes; the generation directory, its role
links, and the receipt are compared whole.

`remote/test-deployment-bundle.sh` reports 46 checks. This file reproduces the
35 that exercise assembly, activation, rollback, and the namespace around
them. Eight belong to the read side `tests/test_runtime_deployment.py` already
covers through `verify_bundle` and `resolve_active` --
`section_bound_to_own_model`, `preset_bound_to_row_formulation`,
`formulation_policy_travels_with_the_bundle`,
`bundle_states_its_own_formulation_policy`, `suffix_ambiguity_refused`,
`resolver_one_bundle`, `absence_decided_under_lock`, and `lock_leaf_verified`.
Three assert that the shell launch scripts still grep for the resolver:
`control_consults_deployment`, `launchers_read_bundled_presets`, and
`control_start_defers_the_formulation_authority`. All 13 checks of
`remote/test-write-deployment-receipt.sh` are reproduced.
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import subprocess
import threading
from dataclasses import dataclass
from pathlib import Path

import pytest

from qwen_apu.runtime.deployment import DeploymentError, NoActiveDeployment, resolve_active
from qwen_apu.runtime.deployment_write import (
    ActivationRecord,
    UsageError,
    _open_activation_lock,
    activate,
    build_bundle,
    error_messages,
    read_image_mcp_server,
    render_activation,
    render_build,
    render_receipt,
    rollback,
    verify_runtime_tree,
    write_receipt,
)
from qwen_apu.runtime.paths import RuntimePaths

TREE = Path(__file__).resolve().parents[1]
BUILDER = TREE / "remote" / "build-deployment-bundle.sh"
ACTIVATOR = TREE / "remote" / "activate-deployment-bundle.sh"
VERIFIER = TREE / "remote" / "verify-deployment-bundle.sh"
RECEIPT_WRITER = TREE / "remote" / "write-deployment-receipt.sh"
RUNTIME_ROOT = TREE / "remote" / "runtime-root.sh"
SH = shutil.which("sh")
# The shell activator execs open-verified-lock-descriptor.py to take the lock,
# so a machine with no python3 on PATH runs none of these pairs.
PYTHON3 = shutil.which("python3")
shell_required = pytest.mark.skipif(
    SH is None or PYTHON3 is None, reason="no /bin/sh or no python3 on PATH"
)

REGISTRY_ROWS = "qwen-2b\tfast-text\tqwen-2b.gguf\nqwen-08b\tfast\tqwen-08b.gguf\n"
SERVER_NATURAL = "#!/bin/sh\nexit 0\n"
SERVER_FORCED = "#!/bin/sh\nexit 1\n"
MANIFEST_ROWS = 12

IMAGE_CONFIGURATION = """{
  "mcpServers": {
    "web": {"command": "python3"},
    "image": {
      "command": "python3",
      "timeout_ms": 360000,
      "args": ["server.py"],
      "env": {
        "QWEN_IMAGE_LANGUAGE_PROFILE": "web-open",
        "QWEN_IMAGE_PROFILE": "image-sdxs-512-a",
        "QWEN_IMAGE_TOKEN_KEY_FILE": "/nonexistent/token.key",
        "QWEN_IMAGE_STATE_DIR": "/nonexistent/images",
        "QWEN_IMAGE_SERVICE_SOCKET": "/nonexistent/images/image.sock",
        "QWEN_IMAGE_PROFILES_JSON": "/nonexistent/image-parameters.json",
        "QWEN_IMAGE_MCP_TIMEOUT_S": "360"
      }
    }
  }
}
"""


def sha256_text(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


@dataclass
class Bench:
    """The fixture inputs both authorities assemble from, and two roots."""

    work: Path

    @property
    def registry(self) -> Path:
        return self.work / "models.tsv"

    @property
    def model_root(self) -> Path:
        return self.work / "models"

    @property
    def python_root(self) -> Path:
        return self.work / "python-deployments"

    @property
    def shell_root(self) -> Path:
        return self.work / "shell-deployments"

    def server(self, semantics: str) -> Path:
        return self.work / f"server-{semantics}"

    def manifest(self, semantics: str) -> Path:
        return self.work / f"manifest-{semantics}.tsv"

    def ledger(self, kind: str) -> Path:
        return self.work / f"ledger-{kind}.tsv"

    def preset(self, count: str) -> Path:
        return self.work / f"router-presets-{count}.ini"

    @property
    def web_preset(self) -> Path:
        return self.work / "web-presets.ini"

    def write_artifact_manifest(self, semantics: str, server: Path, output: Path) -> None:
        """The exec guard's executable row shape for one server."""
        output.write_text(
            f"checkpoint_semantics\t{semantics}\n"
            f"executable\tllama-server\t{server.stat().st_size}\t{sha256_text(server)}\n",
            encoding="utf-8",
        )

    def write_preset(self, count: str, output: Path) -> None:
        section = (
            "[{name}]\n"
            f"LLAMA_ARG_MODEL = {self.model_root}/qwen-2b.gguf\n"
            f"LLAMA_ARG_CTX_CHECKPOINTS = {count}\n"
        )
        output.write_text(
            "# fixture preset\n"
            + section.format(name="qwen-2b")
            + section.format(name="qwen-2b+draft"),
            encoding="utf-8",
        )

    def build(self, root: Path, name: str, **overrides: object) -> object:
        arguments: dict[str, object] = {
            "server": self.server("natural"),
            "artifact_manifest": self.manifest("natural"),
            "ctx_ledger": self.ledger("positive"),
            "router_presets": self.preset("positive"),
            "web_presets": None,
            "registry": self.registry,
        }
        arguments.update(overrides)
        return build_bundle(
            root,
            name,
            arguments.pop("server"),  # type: ignore[arg-type]
            arguments.pop("artifact_manifest"),  # type: ignore[arg-type]
            arguments.pop("ctx_ledger"),  # type: ignore[arg-type]
            **arguments,  # type: ignore[arg-type]
        )

    def shell_build(
        self,
        root: Path,
        name: str,
        *,
        server: Path | None = None,
        artifact_manifest: Path | None = None,
        ctx_ledger: Path | None = None,
        router_presets: Path | None = None,
        web_presets: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        environment = dict(os.environ, QWEN_MODEL_REGISTRY=str(self.registry))
        environment.pop("QWEN_BUNDLE_ROUTER_PRESETS", None)
        environment.pop("QWEN_BUNDLE_WEB_PRESETS", None)
        if router_presets is not None:
            environment["QWEN_BUNDLE_ROUTER_PRESETS"] = str(router_presets)
        if web_presets is not None:
            environment["QWEN_BUNDLE_WEB_PRESETS"] = str(web_presets)
        return subprocess.run(
            [
                str(SH),
                str(BUILDER),
                name,
                str(server or self.server("natural")),
                str(artifact_manifest or self.manifest("natural")),
                str(ctx_ledger or self.ledger("positive")),
                str(root),
            ],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def shell_activate(self, root: Path, selector: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SH), str(ACTIVATOR), selector, str(root)],
            env=dict(os.environ, QWEN_MODEL_REGISTRY=str(self.registry)),
            capture_output=True,
            text=True,
            check=False,
        )

    def shell_verify(self, root: Path, name: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SH), str(VERIFIER), str(root), name],
            env=dict(os.environ, QWEN_MODEL_REGISTRY=str(self.registry)),
            capture_output=True,
            text=True,
            check=False,
        )


@pytest.fixture
def bench(tmp_path: Path) -> Bench:
    """The fixture set `remote/test-deployment-bundle.sh` assembles from.

    The registry validator requires ledger model ids to exist in the model
    registry, so the fixture carries its own two-row registry; the second row
    is a checkpoint the positive ledger leaves at 0.
    """
    fixture = Bench(work=tmp_path)
    fixture.registry.write_text(REGISTRY_ROWS, encoding="utf-8")
    for semantics, body in (("natural", SERVER_NATURAL), ("forced", SERVER_FORCED)):
        server = fixture.server(semantics)
        server.write_text(body, encoding="utf-8")
        server.chmod(0o755)
    fixture.write_artifact_manifest(
        "natural-boundary-v1", fixture.server("natural"), fixture.manifest("natural")
    )
    fixture.write_artifact_manifest(
        "forced-tail-v1", fixture.server("forced"), fixture.manifest("forced")
    )
    fixture.ledger("positive").write_text("qwen-2b\t2\tevidence/run\n", encoding="utf-8")
    fixture.ledger("zero").write_text("qwen-2b\t0\t-\n", encoding="utf-8")
    fixture.write_preset("2", fixture.preset("positive"))
    fixture.write_preset("0", fixture.preset("zero"))
    fixture.web_preset.write_text(
        f"[web-profile]\nLLAMA_ARG_MODEL = {fixture.model_root}/qwen-2b.gguf\n"
        "LLAMA_ARG_CTX_CHECKPOINTS = 2\n",
        encoding="utf-8",
    )
    fixture.python_root.mkdir()
    fixture.shell_root.mkdir()
    return fixture


def manifest_rows(bundle: Path) -> list[tuple[str, str]]:
    rows = []
    for line in (bundle / "bundle-manifest.tsv").read_text(encoding="utf-8").splitlines():
        key, _, value = line.partition("\t")
        rows.append((key, value))
    return rows


def assert_manifests_agree(python_bundle: Path, shell_bundle: Path) -> None:
    """Every manifest row byte for byte, `created_utc` by shape and proximity."""
    python_rows = manifest_rows(python_bundle)
    shell_rows = manifest_rows(shell_bundle)
    assert [key for key, _ in python_rows] == [key for key, _ in shell_rows]
    assert len(python_rows) == MANIFEST_ROWS
    for (key, python_value), (_, shell_value) in zip(python_rows, shell_rows, strict=True):
        if key == "created_utc":
            stamp = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z")
            assert stamp.fullmatch(python_value)
            assert stamp.fullmatch(shell_value)
            continue
        assert python_value == shell_value, key


def role_layout(root: Path) -> list[tuple[str, str]]:
    """Every `deployment*` entry at the root, a link by its target."""
    return sorted(
        (entry.name, os.readlink(entry) if entry.is_symlink() else "<directory>")
        for entry in root.iterdir()
        if entry.name.startswith("deployment")
    )


def generation_layout(root: Path) -> list[tuple[str, str]]:
    generation = root / os.readlink(root / "deployment-state")
    return sorted((entry.name, os.readlink(entry)) for entry in generation.iterdir())


def resolved_role(root: Path, role: str) -> str:
    return Path(os.path.realpath(root / f"deployment-{role}")).name


def generation_directories(root: Path) -> list[str]:
    return sorted(
        entry.name
        for entry in root.iterdir()
        if entry.name.startswith("deployment-state.") and entry.is_dir() and not entry.is_symlink()
    )


def refusal_text(error: DeploymentError) -> str:
    return "\n".join(error_messages(error))


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------


@shell_required
def test_natural_bundle_assembles_identically(bench: Bench) -> None:
    identity = bench.build(bench.python_root, "bundle-natural", web_presets=bench.web_preset)
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-natural",
        router_presets=bench.preset("positive"),
        web_presets=bench.web_preset,
    )
    assert completed.returncode == 0, completed.stderr
    assert (
        render_build(identity).replace(str(bench.python_root), str(bench.shell_root))
        == completed.stdout
    )

    python_bundle = bench.python_root / "bundle-natural"
    shell_bundle = bench.shell_root / "bundle-natural"
    # Every member but the manifest is byte-identical; the manifest carries the
    # one row `date -u` supplies, so it is compared row by row below.
    for member in (
        "llama-server",
        "artifact-manifest.tsv",
        "ctx-checkpoints.tsv",
        "router-presets.ini",
        "web-presets.ini",
        "q4k-policy.tsv",
    ):
        assert (python_bundle / member).is_file()
        assert (python_bundle / member).read_bytes() == (shell_bundle / member).read_bytes()
    assert (python_bundle / "bundle-manifest.tsv").is_file()
    assert sorted(p.name for p in python_bundle.iterdir()) == sorted(
        p.name for p in shell_bundle.iterdir()
    )
    assert_manifests_agree(python_bundle, shell_bundle)
    digests = dict(manifest_rows(python_bundle))
    for preset_row in ("router-presets.ini", "web-presets.ini"):
        assert re.fullmatch(r"[0-9a-f]{64}", digests[preset_row])
    assert os.access(python_bundle / "llama-server", os.X_OK)


@shell_required
def test_preset_generated_against_another_ledger_refuses(bench: Bench) -> None:
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root, "bundle-preset-mismatch", router_presets=bench.preset("zero")
        )
    assert "disagrees with the bundle ledger" in refusal_text(raised.value)
    completed = bench.shell_build(
        bench.shell_root, "bundle-preset-mismatch", router_presets=bench.preset("zero")
    )
    assert completed.returncode != 0
    assert "disagrees with the bundle ledger" in completed.stderr
    assert not (bench.python_root / "bundle-preset-mismatch").exists()


@shell_required
def test_duplicate_bundle_name_refuses(bench: Bench) -> None:
    bench.build(bench.python_root, "bundle-natural")
    with pytest.raises(DeploymentError) as raised:
        bench.build(bench.python_root, "bundle-natural")
    assert str(raised.value).startswith("bundle already exists: ")
    bench.shell_build(bench.shell_root, "bundle-natural", router_presets=bench.preset("positive"))
    completed = bench.shell_build(
        bench.shell_root, "bundle-natural", router_presets=bench.preset("positive")
    )
    assert completed.returncode != 0
    assert "bundle already exists" in completed.stderr


@shell_required
def test_positive_count_against_forced_tail_refuses(bench: Bench) -> None:
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root,
            "bundle-bad-pair",
            server=bench.server("forced"),
            artifact_manifest=bench.manifest("forced"),
            router_presets=None,
        )
    assert "requires natural-boundary-v1" in str(raised.value)
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-bad-pair",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
    )
    assert completed.returncode != 0
    assert "requires natural-boundary-v1" in completed.stderr


@shell_required
def test_malformed_ledger_count_refuses(bench: Bench) -> None:
    malformed = bench.ledger("malformed")
    malformed.write_text("qwen-2b\ttwo\tevidence/run\n", encoding="utf-8")
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root,
            "bundle-malformed",
            server=bench.server("forced"),
            artifact_manifest=bench.manifest("forced"),
            ctx_ledger=malformed,
            router_presets=None,
        )
    assert "failed registry validation" in str(raised.value)
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-malformed",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=malformed,
    )
    assert completed.returncode != 0
    assert "failed registry validation" in completed.stderr


@shell_required
def test_emergency_forced_tail_bundle_assembles(bench: Bench) -> None:
    bench.build(
        bench.python_root,
        "bundle-emergency",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=bench.preset("zero"),
    )
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-emergency",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=bench.preset("zero"),
    )
    assert completed.returncode == 0, completed.stderr
    assert_manifests_agree(
        bench.python_root / "bundle-emergency", bench.shell_root / "bundle-emergency"
    )


@shell_required
def test_manifest_describing_another_binary_refuses(bench: Bench) -> None:
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root,
            "bundle-foreign",
            artifact_manifest=bench.manifest("forced"),
            ctx_ledger=bench.ledger("zero"),
            router_presets=None,
        )
    assert "executable llama-server row does not match" in str(raised.value)
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-foreign",
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
    )
    assert completed.returncode != 0


@shell_required
def test_executable_row_cardinality_refuses_assembly(bench: Bench) -> None:
    conflicting = bench.work / "manifest-conflicting.tsv"
    conflicting.write_text(
        bench.manifest("forced").read_text(encoding="utf-8")
        + "executable\tllama-server\t1\t"
        + "0" * 64
        + "\n",
        encoding="utf-8",
    )
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root,
            "bundle-conflicting",
            server=bench.server("forced"),
            artifact_manifest=conflicting,
            ctx_ledger=bench.ledger("zero"),
            router_presets=bench.preset("zero"),
        )
    assert "holds 2 executable llama-server rows" in str(raised.value)
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-conflicting",
        server=bench.server("forced"),
        artifact_manifest=conflicting,
        ctx_ledger=bench.ledger("zero"),
        router_presets=bench.preset("zero"),
    )
    assert completed.returncode != 0
    assert "holds 2 executable llama-server rows" in completed.stderr


@shell_required
@pytest.mark.parametrize(
    ("rows", "fragment"),
    [
        (
            "instrumentation\tpipeline-census-v3\nbuild_role\tdiagnostic\nserving_eligible\tno\n",
            "names instrumentation pipeline-census-v3; a bundle carries serving builds alone",
        ),
        (
            "instrumentation\tpipeline-census-v3\nbuild_role\tdiagnostic\n",
            "names instrumentation pipeline-census-v3; a bundle carries serving builds alone",
        ),
        (
            "instrumentation\tpipeline-census-v3\nserving_eligible\tyes\n",
            "names instrumentation pipeline-census-v3; a bundle carries serving builds alone",
        ),
        (
            "serving_eligible\t\n",
            "declares serving_eligible <empty>; a bundle carries serving builds alone",
        ),
    ],
)
def test_serving_declaration_refuses_assembly(bench: Bench, rows: str, fragment: str) -> None:
    """A diagnostic build declares itself unfit to serve, and assembly honors it."""
    declared = bench.work / "manifest-declared.tsv"
    declared.write_text(
        rows + bench.manifest("forced").read_text(encoding="utf-8"), encoding="utf-8"
    )
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root,
            "bundle-declared",
            server=bench.server("forced"),
            artifact_manifest=declared,
            ctx_ledger=bench.ledger("zero"),
            router_presets=None,
        )
    assert fragment in str(raised.value)
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-declared",
        server=bench.server("forced"),
        artifact_manifest=declared,
        ctx_ledger=bench.ledger("zero"),
    )
    assert completed.returncode != 0
    assert fragment in completed.stderr


@shell_required
@pytest.mark.parametrize("reserved", [".foo", "deployment-current", "deployment-state.1", "-x"])
def test_reserved_bundle_names_refuse(bench: Bench, reserved: str) -> None:
    with pytest.raises(UsageError) as raised:
        bench.build(
            bench.python_root,
            reserved,
            server=bench.server("forced"),
            artifact_manifest=bench.manifest("forced"),
            ctx_ledger=bench.ledger("zero"),
            router_presets=bench.preset("zero"),
        )
    assert raised.value.exit_status == 2
    assert "avoid the root names" in str(raised.value)
    completed = bench.shell_build(
        bench.shell_root,
        reserved,
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=bench.preset("zero"),
    )
    assert completed.returncode == 2


@shell_required
def test_staging_leaves_unrelated_dot_entries_and_removes_itself(bench: Bench) -> None:
    """Staging is a private random directory, so nothing existing is removed."""
    keeper = bench.python_root / ".foo.staging"
    keeper.mkdir()
    (keeper / "marker").write_text("kept\n", encoding="utf-8")
    bench.build(
        bench.python_root,
        "foo",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=bench.preset("zero"),
    )
    assert (keeper / "marker").read_text(encoding="utf-8") == "kept\n"
    assert (bench.python_root / "foo").is_dir()
    assert list((bench.python_root / ".staging").iterdir()) == []


@shell_required
@pytest.mark.parametrize("planted", ["symlink", "leaf"])
def test_staging_parent_is_a_plain_directory(bench: Bench, planted: str) -> None:
    """A symlink at `.staging` would carry the copied members into what it names."""
    root = bench.work / f"staging-{planted}-root"
    root.mkdir()
    target = bench.work / f"staging-{planted}-target"
    target.mkdir()
    (target / "marker").write_text("kept\n", encoding="utf-8")
    if planted == "symlink":
        (root / ".staging").symlink_to(target)
        fragment = "staging parent is a symlink"
    else:
        (root / ".staging").write_text("leaf\n", encoding="utf-8")
        fragment = "staging parent is not a directory"
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            root,
            "bundle-staged",
            server=bench.server("forced"),
            artifact_manifest=bench.manifest("forced"),
            ctx_ledger=bench.ledger("zero"),
            router_presets=bench.preset("zero"),
        )
    assert fragment in str(raised.value)
    assert sorted(entry.name for entry in target.iterdir()) == ["marker"]
    assert not (root / "bundle-staged").exists()
    completed = bench.shell_build(
        root,
        "bundle-staged",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=bench.preset("zero"),
    )
    assert completed.returncode != 0
    assert fragment in completed.stderr


@shell_required
def test_unreadable_input_and_non_executable_server_refuse(bench: Bench) -> None:
    plain = bench.work / "server-plain"
    plain.write_text(SERVER_NATURAL, encoding="utf-8")
    plain.chmod(0o644)
    with pytest.raises(DeploymentError) as raised:
        bench.build(bench.python_root, "bundle-plain", server=plain, router_presets=None)
    assert str(raised.value) == f"bundle server is not executable: {plain}"
    completed = bench.shell_build(bench.shell_root, "bundle-plain", server=plain)
    assert completed.returncode != 0
    assert "bundle server is not executable" in completed.stderr

    absent = bench.work / "absent-ledger.tsv"
    with pytest.raises(DeploymentError) as missing:
        bench.build(bench.python_root, "bundle-absent", ctx_ledger=absent, router_presets=None)
    assert str(missing.value) == f"bundle input is unreadable: {absent}"


# ---------------------------------------------------------------------------
# The web MCP record and the image lane
# ---------------------------------------------------------------------------


def write_merged_preset(bench: Bench, name: str, head: str, configuration: Path | None) -> Path:
    preset = bench.work / name
    body = head
    body += (
        f"[qwen-2b]\nLLAMA_ARG_MODEL = {bench.model_root}/qwen-2b.gguf\n"
        "LLAMA_ARG_CTX_CHECKPOINTS = 0\n\n"
    )
    if configuration is not None:
        section = "web-other" if "web-other" in head else "web-open"
        body += (
            f"[{section}]\nLLAMA_ARG_MODEL = {bench.model_root}/qwen-2b.gguf\n"
            "LLAMA_ARG_CTX_CHECKPOINTS = 0\n"
            f"LLAMA_ARG_MCP_SERVERS_CONFIG = {configuration}\n"
        )
    preset.write_text(body, encoding="utf-8")
    return preset


@shell_required
def test_bundle_records_web_mcp_configurations(bench: Bench) -> None:
    """The record holds the path and the digest and leaves the file where it is."""
    configuration = bench.work / "web-open.json"
    configuration.write_text('{"mcpServers":{"web":{"command":"python3"}}}\n', encoding="utf-8")
    preset = write_merged_preset(
        bench, "router-presets-merged.ini", "# qwen_web_sections=web-open\n", configuration
    )
    for root in (bench.python_root, bench.shell_root):
        if root is bench.python_root:
            bench.build(
                root,
                "bundle-merged",
                server=bench.server("forced"),
                artifact_manifest=bench.manifest("forced"),
                ctx_ledger=bench.ledger("zero"),
                router_presets=preset,
            )
        else:
            completed = bench.shell_build(
                root,
                "bundle-merged",
                server=bench.server("forced"),
                artifact_manifest=bench.manifest("forced"),
                ctx_ledger=bench.ledger("zero"),
                router_presets=preset,
            )
            assert completed.returncode == 0, completed.stderr
    python_record = bench.python_root / "bundle-merged" / "web-mcp-manifest.tsv"
    shell_record = bench.shell_root / "bundle-merged" / "web-mcp-manifest.tsv"
    assert python_record.read_bytes() == shell_record.read_bytes()
    rows = python_record.read_text(encoding="utf-8").splitlines()
    assert rows[0] == "# profile_id\tconfiguration_path\tsha256\timage_server"
    assert rows[1] == f"web-open\t{configuration}\t{sha256_text(configuration)}\t-"
    assert not (bench.python_root / "bundle-merged" / "web-open.json").exists()
    assert_manifests_agree(bench.python_root / "bundle-merged", bench.shell_root / "bundle-merged")


@shell_required
def test_marker_free_preset_carries_no_record(bench: Bench) -> None:
    preset = bench.work / "router-presets-marker-free.ini"
    preset.write_text(
        f"[qwen-2b]\nLLAMA_ARG_MODEL = {bench.model_root}/qwen-2b.gguf\n"
        "LLAMA_ARG_CTX_CHECKPOINTS = 0\n",
        encoding="utf-8",
    )
    bench.build(
        bench.python_root,
        "bundle-marker-free",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=preset,
    )
    assert not (bench.python_root / "bundle-marker-free" / "web-mcp-manifest.tsv").exists()
    assert (
        dict(manifest_rows(bench.python_root / "bundle-marker-free"))["web-mcp-manifest.tsv"] == "-"
    )
    record = activate(bench.python_root, "bundle-marker-free", bench.registry)
    assert record.transition == "activate"


@shell_required
def test_mcp_key_under_no_web_section_marker_refuses(bench: Bench) -> None:
    configuration = bench.work / "web-open.json"
    configuration.write_text('{"mcpServers":{"web":{"command":"python3"}}}\n', encoding="utf-8")
    preset = bench.work / "router-presets-smuggled.ini"
    preset.write_text(
        f"[qwen-2b]\nLLAMA_ARG_MODEL = {bench.model_root}/qwen-2b.gguf\n"
        "LLAMA_ARG_CTX_CHECKPOINTS = 0\n"
        f"LLAMA_ARG_MCP_SERVERS_CONFIG = {configuration}\n",
        encoding="utf-8",
    )
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root,
            "bundle-smuggled",
            server=bench.server("forced"),
            artifact_manifest=bench.manifest("forced"),
            ctx_ledger=bench.ledger("zero"),
            router_presets=preset,
        )
    assert "head marker names no web section" in str(raised.value)
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-smuggled",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=preset,
    )
    assert completed.returncode != 0
    assert "head marker names no web section" in completed.stderr


@shell_required
def test_marker_naming_a_section_with_no_configuration_refuses(bench: Bench) -> None:
    preset = bench.work / "router-presets-empty-section.ini"
    preset.write_text(
        "# qwen_web_sections=web-open\n"
        f"[web-open]\nLLAMA_ARG_MODEL = {bench.model_root}/qwen-2b.gguf\n"
        "LLAMA_ARG_CTX_CHECKPOINTS = 0\n",
        encoding="utf-8",
    )
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root,
            "bundle-empty-section",
            server=bench.server("forced"),
            artifact_manifest=bench.manifest("forced"),
            ctx_ledger=bench.ledger("zero"),
            router_presets=preset,
        )
    assert "no section carries LLAMA_ARG_MCP_SERVERS_CONFIG" in str(raised.value)
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-empty-section",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=preset,
    )
    assert completed.returncode != 0
    assert "no section carries LLAMA_ARG_MCP_SERVERS_CONFIG" in completed.stderr


@shell_required
def test_bundle_records_the_image_server(bench: Bench) -> None:
    configuration = bench.work / "web-open-image.json"
    configuration.write_text(IMAGE_CONFIGURATION, encoding="utf-8")
    preset = write_merged_preset(
        bench,
        "router-presets-imaged.ini",
        "# qwen_web_sections=web-open\n# qwen_image_profile=image-sdxs-512-a\n",
        configuration,
    )
    bench.build(
        bench.python_root,
        "bundle-imaged",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=preset,
    )
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-imaged",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=preset,
    )
    assert completed.returncode == 0, completed.stderr
    python_record = bench.python_root / "bundle-imaged" / "web-mcp-manifest.tsv"
    assert (
        python_record.read_bytes()
        == (bench.shell_root / "bundle-imaged" / "web-mcp-manifest.tsv").read_bytes()
    )
    assert python_record.read_text(encoding="utf-8").splitlines()[1].split("\t")[3] == "image"
    assert activate(bench.python_root, "bundle-imaged", bench.registry).transition == "activate"


@shell_required
def test_image_marker_over_no_web_section_refuses(bench: Bench) -> None:
    preset = bench.work / "router-presets-image-only.ini"
    preset.write_text(
        "# qwen_image_profile=image-sdxs-512-a\n"
        f"[qwen-2b]\nLLAMA_ARG_MODEL = {bench.model_root}/qwen-2b.gguf\n"
        "LLAMA_ARG_CTX_CHECKPOINTS = 0\n",
        encoding="utf-8",
    )
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root,
            "bundle-image-only",
            server=bench.server("forced"),
            artifact_manifest=bench.manifest("forced"),
            ctx_ledger=bench.ledger("zero"),
            router_presets=preset,
        )
    assert "names image profile image-sdxs-512-a and its head marker names no web section" in str(
        raised.value
    )
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-image-only",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=preset,
    )
    assert completed.returncode != 0
    assert "head marker names no web section" in completed.stderr


@shell_required
def test_stale_image_language_profile_refuses(bench: Bench) -> None:
    """The grant binds the generation to the section that proposed it."""
    configuration = bench.work / "web-open-image.json"
    configuration.write_text(IMAGE_CONFIGURATION, encoding="utf-8")
    preset = write_merged_preset(
        bench,
        "router-presets-language-mismatch.ini",
        "# qwen_web_sections=web-other\n# qwen_image_profile=image-sdxs-512-a\n",
        configuration,
    )
    with pytest.raises(DeploymentError) as raised:
        bench.build(
            bench.python_root,
            "bundle-language-mismatch",
            server=bench.server("forced"),
            artifact_manifest=bench.manifest("forced"),
            ctx_ledger=bench.ledger("zero"),
            router_presets=preset,
        )
    assert "carries an image server bound to language profile web-open" in str(raised.value)
    completed = bench.shell_build(
        bench.shell_root,
        "bundle-language-mismatch",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=preset,
    )
    assert completed.returncode != 0
    assert "carries an image server bound to language profile web-open" in completed.stderr


def test_image_mcp_reader_states_absence_and_disagreement(tmp_path: Path) -> None:
    """The reader answers the armed question and refuses two numbers for one deadline."""
    plain = tmp_path / "plain.json"
    plain.write_text('{"mcpServers":{"web":{"command":"python3"}}}\n', encoding="utf-8")
    assert read_image_mcp_server(plain).present is False
    empty = tmp_path / "empty.json"
    empty.write_text("{}\n", encoding="utf-8")
    assert read_image_mcp_server(empty).present is False
    armed = tmp_path / "armed.json"
    armed.write_text(IMAGE_CONFIGURATION, encoding="utf-8")
    report = read_image_mcp_server(armed)
    assert report.present and report.timeout_ms == 360000
    assert report.value("QWEN_IMAGE_LANGUAGE_PROFILE") == "web-open"
    disagreeing = tmp_path / "disagreeing.json"
    disagreeing.write_text(
        IMAGE_CONFIGURATION.replace(
            '"QWEN_IMAGE_MCP_TIMEOUT_S": "360"', '"QWEN_IMAGE_MCP_TIMEOUT_S": "30"'
        ),
        encoding="utf-8",
    )
    with pytest.raises(DeploymentError) as raised:
        read_image_mcp_server(disagreeing)
    assert "bounds its call at 360000 ms and its own read at 30 s" in str(raised.value)
    incomplete = tmp_path / "incomplete.json"
    incomplete.write_text(
        IMAGE_CONFIGURATION.replace('"QWEN_IMAGE_STATE_DIR": "/nonexistent/images",', ""),
        encoding="utf-8",
    )
    with pytest.raises(DeploymentError) as missing:
        read_image_mcp_server(incomplete)
    assert "names no QWEN_IMAGE_STATE_DIR" in str(missing.value)


# ---------------------------------------------------------------------------
# Activation and rollback
# ---------------------------------------------------------------------------


def populate(bench: Bench, root: Path) -> None:
    """The three bundles both activation sequences move between."""
    bench.build(root, "bundle-natural", web_presets=bench.web_preset)
    bench.build(
        root,
        "bundle-emergency",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=bench.preset("zero"),
    )
    bench.build(
        root,
        "bundle-third",
        server=bench.server("forced"),
        artifact_manifest=bench.manifest("forced"),
        ctx_ledger=bench.ledger("zero"),
        router_presets=bench.preset("zero"),
    )


@shell_required
def test_activation_publishes_one_generation_and_rolls_back(bench: Bench) -> None:
    """Promotion and rollback are one transition run in opposite directions."""
    populate(bench, bench.python_root)
    populate(bench, bench.shell_root)

    first = activate(bench.python_root, "bundle-natural", bench.registry)
    assert first.transition == "activate"
    assert first.previous == ""
    assert first.generation == 1
    assert render_activation(first) == (
        "deployment_current=bundle-natural deployment_previous=- transition=activate\n"
    )
    shell_first = bench.shell_activate(bench.shell_root, "bundle-natural")
    assert shell_first.returncode == 0, shell_first.stderr
    assert shell_first.stdout == render_activation(first)
    assert (bench.python_root / "deployment-state").is_symlink()
    assert resolved_role(bench.python_root, "current") == "bundle-natural"
    assert role_layout(bench.python_root) == role_layout(bench.shell_root)
    assert generation_layout(bench.python_root) == generation_layout(bench.shell_root)

    second = activate(bench.python_root, "bundle-emergency", bench.registry)
    shell_second = bench.shell_activate(bench.shell_root, "bundle-emergency")
    assert shell_second.stdout == render_activation(second)
    assert resolved_role(bench.python_root, "current") == "bundle-emergency"
    assert resolved_role(bench.python_root, "previous") == "bundle-natural"
    # The pair changes through one generation link, so one generation directory
    # remains after a completed activation and the number is the lowest free
    # one rather than a monotonic counter.
    assert generation_directories(bench.python_root) == ["deployment-state.2"]
    assert generation_directories(bench.shell_root) == ["deployment-state.2"]
    assert generation_layout(bench.python_root) == generation_layout(bench.shell_root)

    third = activate(bench.python_root, "bundle-third", bench.registry)
    assert third.generation == 1
    assert generation_directories(bench.python_root) == ["deployment-state.1"]
    bench.shell_activate(bench.shell_root, "bundle-third")
    assert generation_directories(bench.shell_root) == ["deployment-state.1"]

    rolled = rollback(bench.python_root, bench.registry)
    shell_rolled = bench.shell_activate(bench.shell_root, "rollback")
    assert shell_rolled.stdout == render_activation(rolled)
    assert rolled.transition == "rollback"
    assert resolved_role(bench.python_root, "current") == "bundle-emergency"
    assert resolved_role(bench.python_root, "previous") == "bundle-third"
    assert role_layout(bench.python_root) == role_layout(bench.shell_root)
    assert generation_layout(bench.python_root) == generation_layout(bench.shell_root)

    # The activated bundle's preset resolves through the current alias, so the
    # launch chain reads the preset generated against the ledger it serves.
    assert (
        Path(os.path.realpath(bench.python_root / "deployment-current" / "router-presets.ini"))
        == bench.python_root / "bundle-emergency" / "router-presets.ini"
    )


@shell_required
def test_activating_the_current_bundle_is_a_no_op(bench: Bench) -> None:
    """The shell prints to stdout and exits 0, so the Python answers a record."""
    populate(bench, bench.python_root)
    populate(bench, bench.shell_root)
    activate(bench.python_root, "bundle-natural", bench.registry)
    again = activate(bench.python_root, "bundle-natural", bench.registry)
    assert again.transition == "already-current"
    assert render_activation(again) == "bundle is already deployment-current: bundle-natural\n"
    assert generation_directories(bench.python_root) == ["deployment-state.1"]
    bench.shell_activate(bench.shell_root, "bundle-natural")
    shell_again = bench.shell_activate(bench.shell_root, "bundle-natural")
    assert shell_again.returncode == 0
    assert shell_again.stdout == render_activation(again)
    assert generation_directories(bench.shell_root) == ["deployment-state.1"]


@shell_required
def test_rollback_without_a_previous_refuses(bench: Bench) -> None:
    populate(bench, bench.python_root)
    populate(bench, bench.shell_root)
    activate(bench.python_root, "bundle-natural", bench.registry)
    with pytest.raises(DeploymentError) as raised:
        rollback(bench.python_root, bench.registry)
    assert str(raised.value) == (
        f"no deployment-previous to roll back to: {bench.python_root / 'deployment-previous'}"
    )
    bench.shell_activate(bench.shell_root, "bundle-natural")
    completed = bench.shell_activate(bench.shell_root, "rollback")
    assert completed.returncode != 0
    assert "no deployment-previous to roll back to" in completed.stderr


@shell_required
def test_activation_refuses_a_root_that_is_not_a_directory(bench: Bench) -> None:
    leaf = bench.work / "not-a-root"
    leaf.write_text("leaf\n", encoding="utf-8")
    with pytest.raises(DeploymentError) as raised:
        activate(leaf, "bundle-natural", bench.registry)
    assert str(raised.value) == f"deployment root is not a directory: {leaf}"
    completed = bench.shell_activate(leaf, "bundle-natural")
    assert completed.returncode != 0
    assert "deployment root is not a directory" in completed.stderr


@shell_required
def test_activation_refuses_a_reserved_selector(bench: Bench) -> None:
    populate(bench, bench.python_root)
    with pytest.raises(UsageError) as raised:
        activate(bench.python_root, ".hidden", bench.registry)
    assert raised.value.exit_status == 2
    assert "avoid the root names" in str(raised.value)
    completed = bench.shell_activate(bench.python_root, ".hidden")
    assert completed.returncode == 2
    assert "avoid the root names" in completed.stderr


@shell_required
def test_diverged_member_stays_inactive_and_leaves_the_links(bench: Bench) -> None:
    populate(bench, bench.python_root)
    populate(bench, bench.shell_root)
    activate(bench.python_root, "bundle-natural", bench.registry)
    bench.shell_activate(bench.shell_root, "bundle-natural")
    for root in (bench.python_root, bench.shell_root):
        with (root / "bundle-emergency" / "llama-server").open("a", encoding="utf-8") as handle:
            handle.write("tampered\n")
    with pytest.raises(DeploymentError) as raised:
        activate(bench.python_root, "bundle-emergency", bench.registry)
    assert str(raised.value) == ("bundle failed verification and stays inactive: bundle-emergency")
    assert "bundle member diverged: llama-server" in refusal_text(raised.value)
    assert resolved_role(bench.python_root, "current") == "bundle-natural"
    completed = bench.shell_activate(bench.shell_root, "bundle-emergency")
    assert completed.returncode != 0
    assert "bundle member diverged: llama-server" in completed.stderr
    assert resolved_role(bench.shell_root, "current") == "bundle-natural"


@shell_required
def test_rollback_verifies_its_target(bench: Bench) -> None:
    populate(bench, bench.python_root)
    activate(bench.python_root, "bundle-natural", bench.registry)
    activate(bench.python_root, "bundle-emergency", bench.registry)
    with (bench.python_root / "bundle-natural" / "llama-server").open(
        "a", encoding="utf-8"
    ) as handle:
        handle.write("tampered\n")
    with pytest.raises(DeploymentError) as raised:
        rollback(bench.python_root, bench.registry)
    assert str(raised.value) == "rollback target failed verification and stays inactive"
    assert "bundle member diverged: llama-server" in refusal_text(raised.value)
    assert resolved_role(bench.python_root, "current") == "bundle-emergency"


@shell_required
def test_renamed_bundle_refuses_under_a_foreign_name(bench: Bench) -> None:
    """The name a bundle was assembled under is the name it activates under."""
    populate(bench, bench.python_root)
    populate(bench, bench.shell_root)
    for root in (bench.python_root, bench.shell_root):
        (root / "bundle-third").rename(root / "bundle-renamed")
    with pytest.raises(DeploymentError) as raised:
        activate(bench.python_root, "bundle-renamed", bench.registry)
    assert "carries bundle_name bundle-third" in refusal_text(raised.value)
    completed = bench.shell_activate(bench.shell_root, "bundle-renamed")
    assert completed.returncode != 0
    assert "carries bundle_name bundle-third" in completed.stderr


@shell_required
def test_edited_bundle_preset_refuses_at_activation(bench: Bench) -> None:
    populate(bench, bench.python_root)
    activate(bench.python_root, "bundle-emergency", bench.registry)
    preset = bench.python_root / "bundle-natural" / "router-presets.ini"
    with preset.open("a", encoding="utf-8") as handle:
        handle.write("# edited after assembly\n")
    with pytest.raises(DeploymentError) as raised:
        activate(bench.python_root, "bundle-natural", bench.registry)
    assert "bundle member diverged: router-presets.ini" in refusal_text(raised.value)

    # A preset rewritten with a consistent digest still refuses, because the
    # ledger agreement is recomputed from the sections.
    bench.write_preset("0", preset)
    manifest = bench.python_root / "bundle-natural" / "bundle-manifest.tsv"
    manifest.write_text(
        "".join(
            f"{key}\t{sha256_text(preset) if key == 'router-presets.ini' else value}\n"
            for key, value in manifest_rows(bench.python_root / "bundle-natural")
        ),
        encoding="utf-8",
    )
    with pytest.raises(DeploymentError) as rewritten:
        activate(bench.python_root, "bundle-natural", bench.registry)
    assert "disagrees with the bundled ledger" in refusal_text(rewritten.value)
    assert resolved_role(bench.python_root, "current") == "bundle-emergency"


@shell_required
def test_consistent_semantics_rewrite_refuses(bench: Bench) -> None:
    """The semantics rule is recomputed from the artifact manifest."""
    populate(bench, bench.python_root)
    activate(bench.python_root, "bundle-emergency", bench.registry)
    bundle = bench.python_root / "bundle-natural"
    bench.write_artifact_manifest(
        "forced-tail-v1", bundle / "llama-server", bundle / "artifact-manifest.tsv"
    )
    rewritten = {
        "artifact-manifest.tsv": sha256_text(bundle / "artifact-manifest.tsv"),
        "checkpoint_semantics": "forced-tail-v1",
    }
    (bundle / "bundle-manifest.tsv").write_text(
        "".join(f"{key}\t{rewritten.get(key, value)}\n" for key, value in manifest_rows(bundle)),
        encoding="utf-8",
    )
    with pytest.raises(DeploymentError) as raised:
        activate(bench.python_root, "bundle-natural", bench.registry)
    assert "requires natural-boundary-v1" in refusal_text(raised.value)
    completed = bench.shell_activate(bench.python_root, "bundle-natural")
    assert completed.returncode != 0
    assert "requires natural-boundary-v1" in completed.stderr


@shell_required
def test_symlinked_bundle_and_member_refuse(bench: Bench) -> None:
    populate(bench, bench.python_root)
    outside = bench.work / "outside"
    outside.mkdir()
    (bench.python_root / "bundle-link").symlink_to(outside)
    with pytest.raises(DeploymentError) as raised:
        activate(bench.python_root, "bundle-link", bench.registry)
    assert "bundle directory is a symlink" in refusal_text(raised.value)
    completed = bench.shell_activate(bench.python_root, "bundle-link")
    assert completed.returncode != 0
    assert "bundle directory is a symlink" in completed.stderr
    (bench.python_root / "bundle-link").unlink()

    ledger = bench.python_root / "bundle-third" / "ctx-checkpoints.tsv"
    shutil.copy(ledger, outside / "ledger.tsv")
    ledger.unlink()
    ledger.symlink_to(outside / "ledger.tsv")
    with pytest.raises(DeploymentError) as member:
        activate(bench.python_root, "bundle-third", bench.registry)
    assert "bundle member is a symlink" in refusal_text(member.value)


@shell_required
@pytest.mark.parametrize(
    "escape",
    [
        "../../outside",
        "/absolute",
        "../bundle-natural/extra",
        "../deployment-state.1",
        "../.",
    ],
)
def test_role_link_escape_refuses_the_transition(bench: Bench, escape: str) -> None:
    """A role link targets exactly `../BUNDLE_NAME` and any other target refuses."""
    populate(bench, bench.python_root)
    outside = bench.work / "outside"
    outside.mkdir()
    sentinel = outside / "sentinel"
    sentinel.write_text("sentinel\n", encoding="utf-8")
    digest = sha256_text(sentinel)
    activate(bench.python_root, "bundle-natural", bench.registry)
    generation = bench.python_root / os.readlink(bench.python_root / "deployment-state")
    target = str(outside) if escape == "/absolute" else escape
    previous = generation / "previous"
    if previous.is_symlink():
        previous.unlink()
    previous.symlink_to(target)
    with pytest.raises(DeploymentError) as raised:
        rollback(bench.python_root, bench.registry)
    assert "exactly ../BUNDLE_NAME is admitted" in str(raised.value)
    completed = bench.shell_activate(bench.python_root, "rollback")
    assert completed.returncode != 0
    assert "exactly ../BUNDLE_NAME is admitted" in completed.stderr
    assert sha256_text(sentinel) == digest
    assert (bench.python_root / "bundle-natural").is_dir()


@shell_required
def test_state_link_escape_refuses_and_removes_nothing(bench: Bench) -> None:
    populate(bench, bench.python_root)
    outside = bench.work / "outside"
    outside.mkdir()
    sentinel = outside / "sentinel"
    sentinel.write_text("sentinel\n", encoding="utf-8")
    digest = sha256_text(sentinel)
    activate(bench.python_root, "bundle-natural", bench.registry)
    generation = os.readlink(bench.python_root / "deployment-state")
    state_link = bench.python_root / "deployment-state"
    state_link.unlink()
    state_link.symlink_to(f"{generation}/../../outside")
    with pytest.raises(DeploymentError) as raised:
        activate(bench.python_root, "bundle-third", bench.registry)
    assert "exactly deployment-state.N is admitted" in str(raised.value)
    completed = bench.shell_activate(bench.python_root, "bundle-third")
    assert completed.returncode != 0
    assert "exactly deployment-state.N is admitted" in completed.stderr
    assert outside.is_dir()
    assert sha256_text(sentinel) == digest


@shell_required
def test_legacy_role_link_is_read_and_held_to_the_namespace(bench: Bench) -> None:
    """A plain link a prior activator left at the root names one bundle."""
    populate(bench, bench.python_root)
    (bench.python_root / "deployment-current").symlink_to("bundle-natural")
    record = activate(bench.python_root, "bundle-third", bench.registry)
    assert record.previous == "bundle-natural"
    assert resolved_role(bench.python_root, "previous") == "bundle-natural"

    other = bench.work / "legacy-root"
    other.mkdir()
    populate(bench, other)
    (other / "deployment-current").symlink_to("../outside")
    with pytest.raises(DeploymentError) as raised:
        activate(other, "bundle-third", bench.registry)
    assert "exactly BUNDLE_NAME is admitted" in str(raised.value)
    completed = bench.shell_activate(other, "bundle-third")
    assert completed.returncode != 0
    assert "exactly BUNDLE_NAME is admitted" in completed.stderr


@shell_required
def test_concurrent_activations_serialize_under_the_lock(bench: Bench) -> None:
    """Two writers publish one generation and neither loses the other's pair.

    Both threads open their own descriptor inside `activate`, so `LOCK_EX`
    orders them; a shared descriptor would make the second acquisition a
    silent no-op and let both readers see the same displaced current.
    """
    populate(bench, bench.python_root)
    activate(bench.python_root, "bundle-natural", bench.registry)
    results: dict[str, ActivationRecord | BaseException] = {}
    barrier = threading.Barrier(2)

    def run(name: str) -> None:
        barrier.wait()
        try:
            results[name] = activate(bench.python_root, name, bench.registry)
        except BaseException as reason:  # noqa: BLE001 - reported by the assertions
            results[name] = reason

    threads = [
        threading.Thread(target=run, args=("bundle-emergency",)),
        threading.Thread(target=run, args=("bundle-third",)),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    for name, outcome in results.items():
        assert isinstance(outcome, ActivationRecord), f"{name}: {outcome}"
    assert generation_directories(bench.python_root) == [
        os.readlink(bench.python_root / "deployment-state")
    ]
    current = resolved_role(bench.python_root, "current")
    previous = resolved_role(bench.python_root, "previous")
    assert current in ("bundle-emergency", "bundle-third")
    # The second writer read the first writer's publish, so the rollback
    # pointer names the bundle it displaced rather than the one both read.
    assert previous == ("bundle-third" if current == "bundle-emergency" else "bundle-emergency")
    assert {current, previous} == {"bundle-emergency", "bundle-third"}
    resolved = resolve_active(bench.python_root, None, bench.registry)
    assert resolved.name == current


@shell_required
def test_a_held_lock_blocks_the_shell_activator(bench: Bench) -> None:
    """The lock is a held descriptor rather than an inherited marker."""
    populate(bench, bench.python_root)
    activate(bench.python_root, "bundle-natural", bench.registry)
    descriptor = _open_activation_lock(bench.python_root)
    try:
        blocked = subprocess.Popen(
            [str(SH), str(ACTIVATOR), "bundle-third", str(bench.python_root)],
            env=dict(
                os.environ,
                QWEN_MODEL_REGISTRY=str(bench.registry),
                QWEN_ACTIVATION_LOCK_HELD=str(bench.python_root),
            ),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        with pytest.raises(subprocess.TimeoutExpired):
            blocked.wait(timeout=2)
        assert resolved_role(bench.python_root, "current") == "bundle-natural"
    finally:
        os.close(descriptor)
    assert blocked.wait(timeout=30) == 0
    assert resolved_role(bench.python_root, "current") == "bundle-third"


# ---------------------------------------------------------------------------
# The receipt
# ---------------------------------------------------------------------------

CANDIDATE_SERIES = "patches/llama-server-prefix-checkpoint.patch"
CANDIDATE_DIGEST = hashlib.sha256(b"candidate-fixture").hexdigest()
PAGE_DIGEST = hashlib.sha256(b"page").hexdigest()
FIXTURE_HEAD = "deadbeefcafef00d1234567890abcdef12345678"
SESSION_BOUNDARY = (
    "state=running server_pid=1 profile=low-async lan_exposure=1 "
    "lan_address=192.0.2.10 lan_name=qwen-laptop.local lan_open=1\n"
)
SERVED_PAGE = (
    f"served_page source=/tmp/qwen-apu/webui sha256={PAGE_DIGEST} "
    "prompt_bound=1000 output_bound=200\n"
)


@dataclass
class ReceiptBench:
    """A verified runtime tree, an activated bundle, a session, and a root."""

    work: Path
    tree: Path
    registry: Path
    deployment_root: Path
    state: Path
    runtime_root: Path

    def write_tree_manifest(self, head: str) -> None:
        """The manifest `sync-runtime-tree.sh` writes beside a synced copy."""
        rows = []
        for relative in sorted(["remote/serve.sh", "patches/repair.patch"]):
            path = self.tree / relative
            mode = "x" if os.access(path, os.X_OK) else "-"
            rows.append(f"{relative}\t{sha256_text(path)}\t{mode}\n")
        remote = hashlib.sha256(
            "".join(row for row in rows if row.startswith("remote/")).encode()
        ).hexdigest()
        patches = hashlib.sha256(
            "".join(row for row in rows if row.startswith("patches/")).encode()
        ).hexdigest()
        (self.tree / "runtime-tree-manifest.tsv").write_text(
            f"git_head\t{head}\nremote_payload_tree_sha256\t{remote}\n"
            f"patches_payload_tree_sha256\t{patches}\n" + "".join(rows),
            encoding="utf-8",
        )

    def environment(self, *, state: Path | None = None) -> dict[str, str]:
        return dict(
            os.environ,
            QWEN_HOME=str(self.runtime_root),
            QWEN_MODEL_REGISTRY=str(self.registry),
            QWEN_RECEIPT_RUNTIME_TREE_ROOT=str(self.tree),
            QWEN_RECEIPT_MODEL_REGISTRY=str(self.registry),
            QWEN_RECEIPT_STATE_DIRECTORY=str(state or self.state),
        )

    def shell_write(
        self, output: Path, *, root: Path | None = None, state: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SH), str(RECEIPT_WRITER), str(root or self.deployment_root), str(output)],
            env=self.environment(state=state),
            capture_output=True,
            text=True,
            check=False,
        )

    def doctor(self) -> tuple[str, str]:
        """`runtime-root.sh doctor`'s verdict, the seam this port leaves open."""
        completed = subprocess.run(
            [str(SH), str(RUNTIME_ROOT), "doctor"],
            env=self.environment(),
            capture_output=True,
            text=True,
            check=False,
        )
        summary = completed.stdout.strip().splitlines()[-1]
        legacy = re.search(r"legacy_paths_present=([a-z]*)", summary)
        foreign = re.search(r"foreign_owned_paths=([0-9]*)", summary)
        assert legacy and foreign, summary
        return legacy.group(1), foreign.group(1)

    def python_write(
        self, output: Path, *, root: Path | None = None, state: Path | None = None
    ) -> object:
        legacy, foreign = self.doctor()
        return write_receipt(
            root or self.deployment_root,
            output,
            runtime_tree_root=self.tree,
            model_registry=self.registry,
            state_directory=state or self.state,
            legacy_paths_present=legacy,
            foreign_owned_paths=foreign,
            registry=self.registry,
            runtime_root=self.runtime_root,
        )


@pytest.fixture
def receipt(tmp_path: Path) -> ReceiptBench:
    fixture = ReceiptBench(
        work=tmp_path,
        tree=tmp_path / "tree",
        registry=tmp_path / "models.tsv",
        deployment_root=tmp_path / "deployments",
        state=tmp_path / "state",
        runtime_root=tmp_path / "runtime-root",
    )
    (fixture.tree / "remote").mkdir(parents=True)
    (fixture.tree / "patches").mkdir()
    served = fixture.tree / "remote" / "serve.sh"
    served.write_text("echo serving\n", encoding="utf-8")
    served.chmod(0o755)
    patch = fixture.tree / "patches" / "repair.patch"
    patch.write_text("patch body\n", encoding="utf-8")
    patch.chmod(0o644)
    fixture.write_tree_manifest(FIXTURE_HEAD)

    fixture.registry.write_text("qwen-2b\tfast-text\tqwen-2b.gguf\n", encoding="utf-8")
    model_root = tmp_path / "models"
    server = tmp_path / "llama-server"
    server.write_text(SERVER_NATURAL, encoding="utf-8")
    server.chmod(0o755)
    artifact_manifest = tmp_path / "artifact-manifest.tsv"
    artifact_manifest.write_text(
        "checkpoint_semantics\tnatural-boundary-v1\n"
        f"candidate_series\t{CANDIDATE_SERIES}\n"
        f"candidate_series_sha256\t{CANDIDATE_DIGEST}\n"
        f"executable\tllama-server\t{server.stat().st_size}\t{sha256_text(server)}\n",
        encoding="utf-8",
    )
    ledger = tmp_path / "ledger.tsv"
    ledger.write_text("qwen-2b\t0\t-\n", encoding="utf-8")
    preset = tmp_path / "router-presets.ini"
    preset.write_text(
        f"[qwen-2b]\nLLAMA_ARG_MODEL = {model_root}/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n",
        encoding="utf-8",
    )
    fixture.deployment_root.mkdir()
    build_bundle(
        fixture.deployment_root,
        "receipt-fixture",
        server,
        artifact_manifest,
        ledger,
        router_presets=preset,
        registry=fixture.registry,
    )
    activate(fixture.deployment_root, "receipt-fixture", fixture.registry)

    fixture.state.mkdir()
    (fixture.state / "session.status").write_text(SESSION_BOUNDARY + SERVED_PAGE, encoding="utf-8")

    # The runtime root is laid out by the Python authority and its manifest by
    # the shell one, since runtime-root.sh status owns that file.
    RuntimePaths(tree=TREE, root=fixture.runtime_root).lay_out()
    status = subprocess.run(
        [str(SH), str(RUNTIME_ROOT), "status"],
        env=fixture.environment(),
        capture_output=True,
        text=True,
        check=False,
    )
    assert status.returncode == 0, status.stderr
    return fixture


def receipt_field(path: Path, key: str) -> str:
    for line in path.read_text(encoding="utf-8").splitlines():
        fields = line.split("\t")
        if fields[0] == key:
            return fields[1]
    return ""


@shell_required
def test_receipt_reproduces_the_shell_receipt(receipt: ReceiptBench) -> None:
    """Every row but the closing one, which names the file it was written to."""
    shell_output = receipt.work / "receipt-shell.tsv"
    completed = receipt.shell_write(shell_output)
    assert completed.returncode == 0, completed.stderr
    python_output = receipt.work / "receipt-python.tsv"
    record = receipt.python_write(python_output)
    assert (
        render_receipt(record).replace(  # type: ignore[arg-type]
            str(python_output), str(shell_output)
        )
        == completed.stdout
    )

    python_rows = python_output.read_text(encoding="utf-8").splitlines()
    shell_rows = shell_output.read_text(encoding="utf-8").splitlines()
    assert len(python_rows) == len(shell_rows)
    for python_row, shell_row in zip(python_rows[:-1], shell_rows[:-1], strict=True):
        assert python_row == shell_row
    # The closing row's source_path is the receipt's own file, so the two
    # differ there alone and the digest they carry is the same.
    assert python_rows[-1].split("\t")[:2] == shell_rows[-1].split("\t")[:2]
    assert python_rows[-1].split("\t")[2] == str(python_output)
    assert shell_rows[-1].split("\t")[2] == str(shell_output)


@shell_required
def test_receipt_fields_read_their_own_sources(receipt: ReceiptBench) -> None:
    output = receipt.work / "receipt.tsv"
    record = receipt.python_write(output)
    assert receipt_field(output, "main_commit") == FIXTURE_HEAD
    assert receipt_field(output, "tool_prefix_identity") == f"{CANDIDATE_SERIES}:{CANDIDATE_DIGEST}"
    assert receipt_field(output, "served_page_identity") == (
        f"source=/tmp/qwen-apu/webui sha256={PAGE_DIGEST} prompt_bound=1000 output_bound=200"
    )
    assert receipt_field(output, "open_lan_policy_identity") == (
        "lan_exposure=1 lan_address=192.0.2.10 lan_name=qwen-laptop.local lan_open=1"
    )
    server = receipt.deployment_root / "receipt-fixture" / "llama-server"
    assert receipt_field(output, "server_digest") == sha256_text(server)
    assert receipt_field(output, "model_ledger_digest") == sha256_text(receipt.registry)
    assert receipt_field(output, "qwen_home") == str(receipt.runtime_root)

    # The closing row is a digest over every row above it.
    covered = "".join(
        f"{line}\n"
        for line in output.read_text(encoding="utf-8").splitlines()
        if not line.startswith("receipt_sha256\t")
    )
    assert receipt_field(output, "receipt_sha256") == hashlib.sha256(covered.encode()).hexdigest()
    assert record.receipt_sha256 == receipt_field(output, "receipt_sha256")  # type: ignore[attr-defined]


@shell_required
def test_receipt_refuses_a_root_with_no_active_bundle(receipt: ReceiptBench) -> None:
    empty = receipt.work / "empty-deployments"
    empty.mkdir()
    with pytest.raises(NoActiveDeployment) as raised:
        receipt.python_write(receipt.work / "refused.tsv", root=empty)
    assert str(raised.value) == f"no verified active deployment under {empty}"
    assert raised.value.exit_status == 3
    completed = receipt.shell_write(receipt.work / "refused-shell.tsv", root=empty)
    assert completed.returncode == 3
    assert not (receipt.work / "refused.tsv").exists()


@shell_required
def test_receipt_refuses_a_divergent_runtime_tree(receipt: ReceiptBench) -> None:
    (receipt.tree / "remote" / "serve.sh").write_text("echo tampered\n", encoding="utf-8")
    with pytest.raises(DeploymentError) as raised:
        receipt.python_write(receipt.work / "refused.tsv")
    assert "failed verification" in str(raised.value)
    assert any("runtime_tree_divergent=remote/serve.sh" in line for line in raised.value.details)
    completed = receipt.shell_write(receipt.work / "refused-shell.tsv")
    assert completed.returncode != 0
    assert "failed verification" in completed.stderr


@shell_required
def test_receipt_refuses_a_dirty_sync(receipt: ReceiptBench) -> None:
    """A dirty sync names no commit a git tag can point at."""
    receipt.write_tree_manifest(f"{FIXTURE_HEAD}-dirty")
    with pytest.raises(DeploymentError) as raised:
        receipt.python_write(receipt.work / "refused.tsv")
    assert str(raised.value) == (
        f"runtime tree was synced from a dirty working tree: {FIXTURE_HEAD}-dirty"
    )
    completed = receipt.shell_write(receipt.work / "refused-shell.tsv")
    assert completed.returncode != 0
    assert "dirty working tree" in completed.stderr


@shell_required
def test_absent_session_records_its_absence(receipt: ReceiptBench) -> None:
    """A receipt written after teardown binds the identity a peer no longer gets."""
    absent = receipt.work / "no-session-state"
    output = receipt.work / "no-session.tsv"
    receipt.python_write(output, state=absent)
    assert receipt_field(output, "open_lan_policy_identity") == "no-running-session"
    assert receipt_field(output, "served_page_identity") == "no-running-session"
    assert receipt_field(output, "stage_timing_identity") == "no-running-session"
    shell_output = receipt.work / "no-session-shell.tsv"
    completed = receipt.shell_write(shell_output, state=absent)
    assert completed.returncode == 0, completed.stderr
    assert (
        output.read_text(encoding="utf-8").splitlines()[:-1]
        == (shell_output.read_text(encoding="utf-8").splitlines()[:-1])
    )


@shell_required
def test_receipt_refuses_an_output_directory_that_is_absent(receipt: ReceiptBench) -> None:
    missing = receipt.work / "no-such-directory" / "receipt.tsv"
    with pytest.raises(DeploymentError) as raised:
        receipt.python_write(missing)
    assert str(raised.value) == f"output directory does not exist: {missing.parent}"
    completed = receipt.shell_write(missing)
    assert completed.returncode != 0
    assert "output directory does not exist" in completed.stderr


@shell_required
def test_runtime_tree_verification_reports_its_three_states(receipt: ReceiptBench) -> None:
    """Verified, unmanifested, and unsynced-source-clone, the shell's own states."""
    verified = verify_runtime_tree(receipt.tree)
    assert verified.startswith(f"runtime_tree=verified git_head={FIXTURE_HEAD} payload=")
    assert verified.endswith(" files=2")
    completed = subprocess.run(
        [str(SH), str(TREE / "remote" / "check-runtime-tree.sh"), str(receipt.tree)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert completed.returncode == 0, completed.stderr
    assert completed.stdout.strip() == verified

    bare = receipt.work / "bare-tree"
    bare.mkdir()
    assert verify_runtime_tree(bare) == (
        f"runtime_tree=unmanifested manifest={bare / 'runtime-tree-manifest.tsv'}"
    )
    clone = receipt.work / "clone-tree"
    clone.mkdir()
    (clone / ".git").mkdir()
    with pytest.raises(DeploymentError) as raised:
        verify_runtime_tree(clone)
    assert str(raised.value) == f"runtime_tree=unsynced-source-clone root={clone}"

    # A stray file and a symlink inside the managed roots are both failures.
    (receipt.tree / "remote" / "stray.sh").write_text("stray\n", encoding="utf-8")
    (receipt.tree / "patches" / "linked.patch").symlink_to(
        receipt.tree / "patches" / "repair.patch"
    )
    with pytest.raises(DeploymentError) as divergent:
        verify_runtime_tree(receipt.tree)
    assert str(divergent.value).startswith("runtime_tree=divergent failures=2")
    assert "runtime_tree_stray=remote/stray.sh" in divergent.value.details
    assert "runtime_tree_symlink=patches/linked.patch" in divergent.value.details
