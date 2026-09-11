"""Parity between qwen_apu.runtime.deployment and the deployment shell authorities.

Each refusal runs twice over one fixture bundle: `verify_bundle` or
`resolve_active` raises, and `remote/verify-deployment-bundle.sh` or
`remote/resolve-active-deployment.sh` exits non-zero over the same bytes with
the Python message inside its stderr. The message containment is what makes
the pair a parity test rather than two independent refusals: a Python check
that refuses for another reason fails here even though both sides refused.

The clean bundle is assembled by this file rather than by
`remote/build-deployment-bundle.sh`, and the first test requires the shell
verifier to accept it, so every tamper case below starts from bytes both
authorities call a bundle.
"""

from __future__ import annotations

import fcntl
import hashlib
import os
import shutil
import subprocess
import threading
from dataclasses import dataclass
from pathlib import Path

import pytest

from qwen_apu.runtime.deployment import (
    ActiveDeployment,
    DeploymentError,
    NoActiveDeployment,
    bundle_name_is_valid,
    open_verified_lock,
    render,
    resolve_active,
    verify_bundle,
)

TREE = Path(__file__).resolve().parents[1]
VERIFIER = TREE / "remote" / "verify-deployment-bundle.sh"
RESOLVER = TREE / "remote" / "resolve-active-deployment.sh"
SH = shutil.which("sh")
shell_required = pytest.mark.skipif(SH is None, reason="no /bin/sh")

BUNDLE_NAME = "bundle-natural"
MODEL_ROOT = "/nonexistent/models"
REGISTRY_ROWS = "qwen-2b\tfast-text\tqwen-2b.gguf\nqwen-08b\tfast\tqwen-08b.gguf\n"
POSITIVE_LEDGER = "qwen-2b\t2\tevidence/run\n"
ZERO_LEDGER = "qwen-2b\t0\t-\n"
Q4K_POLICY = "qwen-2b\t-\nqwen-08b\t-\n"
SERVER_BODY = "#!/bin/sh\nexit 0\n"


def sha256_text(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def preset_text(count: str, head: str = "# fixture preset\n") -> str:
    section = (
        "[{name}]\n"
        f"LLAMA_ARG_MODEL = {MODEL_ROOT}/qwen-2b.gguf\n"
        f"LLAMA_ARG_CTX_CHECKPOINTS = {count}\n"
    )
    return head + section.format(name="qwen-2b") + section.format(name="qwen-2b+draft")


@dataclass
class Fixture:
    """One assembled bundle and the root, registry, and pointer around it."""

    root: Path
    registry: Path
    name: str = BUNDLE_NAME

    @property
    def directory(self) -> Path:
        return self.root / self.name

    @property
    def manifest(self) -> Path:
        return self.directory / "bundle-manifest.tsv"

    @property
    def artifact(self) -> Path:
        return self.directory / "artifact-manifest.tsv"

    def verify(self) -> None:
        verify_bundle(self.root, self.name)

    def reseal(self, member: str) -> None:
        """Recompute one member's digest into the bundle manifest."""
        set_row(self.manifest, member, sha256_text(self.directory / member))


def write_rows(path: Path, rows: str) -> None:
    path.write_text(rows, encoding="utf-8")


def set_row(path: Path, key: str, value: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    rewritten: list[str] = []
    for line in lines:
        fields = line.split("\t")
        if fields[0] == key:
            fields[1] = value
            rewritten.append("\t".join(fields))
        else:
            rewritten.append(line)
    write_rows(path, "".join(f"{line}\n" for line in rewritten))


def drop_row(path: Path, key: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    write_rows(path, "".join(f"{line}\n" for line in lines if line.split("\t")[0] != key))


def append_row(path: Path, row: str) -> None:
    with path.open("a", encoding="utf-8") as stream:
        stream.write(f"{row}\n")


def prepend_row(path: Path, row: str) -> None:
    write_rows(path, f"{row}\n" + path.read_text(encoding="utf-8"))


def build_bundle(
    root: Path,
    name: str = BUNDLE_NAME,
    *,
    semantics: str = "natural-boundary-v1",
    server_body: str = SERVER_BODY,
    ledger: str = POSITIVE_LEDGER,
    router_preset: str | None = None,
    web_preset: str | None = None,
    q4k_policy: str | None = Q4K_POLICY,
    web_mcp: str | None = None,
    artifact_head: str = "",
) -> Path:
    """Assemble one bundle the way build-deployment-bundle.sh publishes it."""
    directory = root / name
    directory.mkdir(parents=True)
    server = directory / "llama-server"
    write_rows(server, server_body)
    server.chmod(0o755)
    server_bytes = server.stat().st_size
    server_sha256 = sha256_text(server)

    write_rows(
        directory / "artifact-manifest.tsv",
        artifact_head
        + f"checkpoint_semantics\t{semantics}\n"
        + f"executable\tllama-server\t{server_bytes}\t{server_sha256}\n",
    )
    write_rows(directory / "ctx-checkpoints.tsv", ledger)
    maximum = max(
        (int(row.split("\t")[1]) for row in ledger.splitlines() if row.strip()), default=0
    )

    router_sha256 = "-"
    if router_preset is None:
        router_preset = preset_text("2" if maximum else "0")
    write_rows(directory / "router-presets.ini", router_preset)
    (directory / "router-presets.ini").chmod(0o600)
    router_sha256 = sha256_text(directory / "router-presets.ini")

    web_sha256 = "-"
    if web_preset is not None:
        write_rows(directory / "web-presets.ini", web_preset)
        (directory / "web-presets.ini").chmod(0o600)
        web_sha256 = sha256_text(directory / "web-presets.ini")

    q4k_sha256 = "-"
    if q4k_policy is not None:
        write_rows(directory / "q4k-policy.tsv", q4k_policy)
        q4k_sha256 = sha256_text(directory / "q4k-policy.tsv")

    web_mcp_sha256 = "-"
    if web_mcp is not None:
        write_rows(directory / "web-mcp-manifest.tsv", web_mcp)
        (directory / "web-mcp-manifest.tsv").chmod(0o600)
        web_mcp_sha256 = sha256_text(directory / "web-mcp-manifest.tsv")

    write_rows(
        directory / "bundle-manifest.tsv",
        f"bundle_name\t{name}\n"
        "created_utc\t2026-01-01T00:00:00Z\n"
        f"checkpoint_semantics\t{semantics}\n"
        f"maximum_ledger_count\t{maximum}\n"
        f"server_bytes\t{server_bytes}\n"
        f"llama-server\t{server_sha256}\n"
        f"artifact-manifest.tsv\t{sha256_text(directory / 'artifact-manifest.tsv')}\n"
        f"ctx-checkpoints.tsv\t{sha256_text(directory / 'ctx-checkpoints.tsv')}\n"
        f"router-presets.ini\t{router_sha256}\n"
        f"web-presets.ini\t{web_sha256}\n"
        f"web-mcp-manifest.tsv\t{web_mcp_sha256}\n"
        f"q4k-policy.tsv\t{q4k_sha256}\n",
    )
    return directory


@pytest.fixture
def fixture(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Fixture:
    registry = tmp_path / "models.tsv"
    write_rows(registry, REGISTRY_ROWS)
    monkeypatch.setenv("QWEN_MODEL_REGISTRY", str(registry))
    monkeypatch.delenv("QWEN_HOME", raising=False)
    monkeypatch.delenv("QWEN_ACTIVE_DEPLOYMENT_DIRECTORY", raising=False)
    root = tmp_path / "deployments"
    root.mkdir()
    build_bundle(root, web_preset=preset_text("2", head=""))
    return Fixture(root=root, registry=registry)


def shell_environment(**overrides: str) -> dict[str, str]:
    """The subprocess environment, with an ambient runtime root left out."""
    environment = {key: value for key, value in os.environ.items() if key != "QWEN_HOME"}
    environment.update(overrides)
    return environment


@dataclass(frozen=True)
class ShellResult:
    """One shell authority's exit status and streams, decoded verbatim.

    The streams are decoded rather than captured through `text=True`, whose
    universal-newline translation would rewrite a carriage return the shell
    printed inside a message field.
    """

    returncode: int
    stdout: str
    stderr: str


def run_shell(argv: list[str], **overrides: str) -> ShellResult:
    completed = subprocess.run(
        argv, capture_output=True, env=shell_environment(**overrides), check=False
    )
    return ShellResult(
        returncode=completed.returncode,
        stdout=completed.stdout.decode("utf-8", errors="surrogateescape"),
        stderr=completed.stderr.decode("utf-8", errors="surrogateescape"),
    )


def shell_verify(root: Path, name: str, **overrides: str) -> ShellResult:
    return run_shell([SH or "sh", str(VERIFIER), str(root), name], **overrides)


def shell_resolve(root: Path, **overrides: str) -> ShellResult:
    return run_shell([SH or "sh", str(RESOLVER), str(root)], **overrides)


def refuses_alike(fixture: Fixture) -> str:
    """Require both authorities to refuse the bundle with one message."""
    with pytest.raises(DeploymentError) as caught:
        fixture.verify()
    message = str(caught.value)
    if SH is not None:
        result = shell_verify(fixture.root, fixture.name)
        assert result.returncode != 0, f"the shell verifier accepted: {result.stdout}"
        assert message in result.stderr, f"python said {message!r}, shell said {result.stderr!r}"
    return message


def resolution_refuses_alike(
    root: Path, expected: type[DeploymentError] = DeploymentError, **overrides: str
) -> str:
    """Require both resolvers to refuse, and compare the exit class with the status."""
    directory = overrides.get("QWEN_ACTIVE_DEPLOYMENT_DIRECTORY")
    with pytest.raises(expected) as caught:
        resolve_active(root, Path(directory) if directory else None)
    message = str(caught.value)
    if SH is not None:
        result = shell_resolve(root, **overrides)
        assert result.returncode == caught.value.exit_status, result.stderr
        assert message in result.stderr, f"python said {message!r}, shell said {result.stderr!r}"
    return message


# The clean bundle: the shell verifier accepts what this file assembles, which
# is what makes every tamper case below a statement about the tamper.


@shell_required
def test_clean_bundle_accepted_by_both(fixture: Fixture) -> None:
    identity = verify_bundle(fixture.root, fixture.name)
    result = shell_verify(fixture.root, fixture.name)
    assert result.returncode == 0, result.stderr
    assert result.stdout == (
        f"deployment_bundle_verified={fixture.name} directory={identity.directory}\n"
    )
    assert identity.checkpoint_semantics == "natural-boundary-v1"
    assert identity.maximum_ledger_count == 2
    assert identity.server_bytes == len(SERVER_BODY)
    assert identity.member_digests["llama-server"] == sha256_text(
        fixture.directory / "llama-server"
    )


@pytest.mark.parametrize(
    "name",
    ["bundle-natural", "A", "0", "a.b_c-1", "deployment-states", "deployment-currentx"],
)
def test_bundle_names_admitted(name: str) -> None:
    assert bundle_name_is_valid(name)


@pytest.mark.parametrize(
    "name",
    [
        "",
        ".foo",
        "-x",
        "_x",
        "a b",
        "a/b",
        "abc\n",
        "deployment-current",
        "deployment-previous",
        "deployment-state",
        "deployment-state.1",
    ],
)
def test_bundle_names_refused(name: str) -> None:
    assert not bundle_name_is_valid(name)


@pytest.mark.parametrize(
    "name", [".foo", "-x", "deployment-current", "deployment-state.1", "abc\n"]
)
def test_reserved_name_refused_by_both(fixture: Fixture, name: str) -> None:
    fixture.name = name
    message = refuses_alike(fixture)
    assert message.startswith("bundle name must match")


# Structure: the bundle is held inside the root lexically and canonically.


def test_absent_bundle_refused(fixture: Fixture) -> None:
    fixture.name = "bundle-absent"
    assert refuses_alike(fixture).startswith("bundle directory is absent")


def test_symlinked_bundle_directory_refused(fixture: Fixture, tmp_path: Path) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    (fixture.root / "bundle-link").symlink_to(outside)
    fixture.name = "bundle-link"
    assert refuses_alike(fixture).startswith("bundle directory is a symlink")


def test_linked_root_verifies_through_its_canonical_pair(fixture: Fixture, tmp_path: Path) -> None:
    # The canonical check pairs a lexical name with a resolved directory, and a
    # root reached through a symlink resolves to the same pair. The refusal
    # behind it is reached by a linked entry, which the symlink rule ahead of it
    # names first, so both authorities report the symlink.
    linked_root = tmp_path / "linked-root"
    linked_root.symlink_to(fixture.root)
    linked = Fixture(root=linked_root, registry=fixture.registry)
    verify_bundle(linked.root, linked.name)
    if SH is not None:
        assert shell_verify(linked.root, linked.name).returncode == 0
    outside = tmp_path / "outside"
    outside.mkdir()
    (fixture.root / "bundle-alias").symlink_to(outside)
    linked.name = "bundle-alias"
    assert refuses_alike(linked).startswith("bundle directory is a symlink")


@pytest.mark.parametrize(
    "member",
    ["ctx-checkpoints.tsv", "artifact-manifest.tsv", "llama-server", "router-presets.ini"],
)
def test_symlinked_member_refused(fixture: Fixture, tmp_path: Path, member: str) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    copy = outside / member
    copy.write_bytes((fixture.directory / member).read_bytes())
    (fixture.directory / member).unlink()
    (fixture.directory / member).symlink_to(copy)
    assert refuses_alike(fixture).startswith("bundle member is a symlink")


def test_unreadable_bundle_manifest_refused(fixture: Fixture) -> None:
    fixture.manifest.unlink()
    assert refuses_alike(fixture).startswith("bundle manifest is unreadable")


# The bundle manifest: one row per key, and the name it was assembled under.


@pytest.mark.parametrize(
    "key",
    [
        "bundle_name",
        "checkpoint_semantics",
        "maximum_ledger_count",
        "server_bytes",
        "llama-server",
        "artifact-manifest.tsv",
        "ctx-checkpoints.tsv",
        "router-presets.ini",
        "web-presets.ini",
    ],
)
def test_missing_manifest_key_refused(fixture: Fixture, key: str) -> None:
    drop_row(fixture.manifest, key)
    assert refuses_alike(fixture) == (
        f"bundle manifest carries 0 rows for {key}; exactly one is required: {fixture.manifest}"
    )


def test_duplicate_manifest_key_refused(fixture: Fixture) -> None:
    append_row(fixture.manifest, f"llama-server\t{sha256_text(fixture.directory / 'llama-server')}")
    assert refuses_alike(fixture).startswith("bundle manifest carries 2 rows for llama-server")


def test_two_web_mcp_rows_refused(fixture: Fixture) -> None:
    append_row(fixture.manifest, "web-mcp-manifest.tsv\t-")
    assert "at most one is admitted" in refuses_alike(fixture)


def test_two_q4k_policy_rows_refused(fixture: Fixture) -> None:
    append_row(fixture.manifest, "q4k-policy.tsv\t-")
    assert refuses_alike(fixture).startswith(
        "bundle manifest carries 2 rows for q4k-policy.tsv; at most one is admitted"
    )


def test_renamed_bundle_refused(fixture: Fixture) -> None:
    (fixture.root / "bundle-renamed").mkdir()
    for member in fixture.directory.iterdir():
        shutil.copy2(member, fixture.root / "bundle-renamed" / member.name)
    fixture.name = "bundle-renamed"
    assert (
        refuses_alike(fixture)
        == "bundle directory bundle-renamed carries bundle_name bundle-natural"
    )


# The members' own bytes, recomputed against every claim.


@pytest.mark.parametrize("member", ["llama-server", "artifact-manifest.tsv", "ctx-checkpoints.tsv"])
def test_diverged_member_refused(fixture: Fixture, member: str) -> None:
    with (fixture.directory / member).open("a", encoding="utf-8") as stream:
        stream.write("tampered\n")
    assert refuses_alike(fixture).startswith(f"bundle member diverged: {member} expected=")


@pytest.mark.parametrize("member", ["llama-server", "artifact-manifest.tsv", "ctx-checkpoints.tsv"])
def test_absent_digested_member_refused(fixture: Fixture, member: str) -> None:
    (fixture.directory / member).unlink()
    assert refuses_alike(fixture) == f"bundle member is unreadable: {fixture.directory / member}"


def test_server_without_execute_bit_refused(fixture: Fixture) -> None:
    (fixture.directory / "llama-server").chmod(0o644)
    assert refuses_alike(fixture) == (
        f"bundle server is not executable: {fixture.directory / 'llama-server'}"
    )


def test_declared_server_bytes_compared_as_a_string(fixture: Fixture) -> None:
    # The shell compares `wc -c` against the declared field with `!=`, so a
    # leading zero is a different string and refuses on a matching digest.
    measured = (fixture.directory / "llama-server").stat().st_size
    set_row(fixture.manifest, "server_bytes", f"0{measured}")
    assert refuses_alike(fixture) == (
        f"bundle server measures {measured} bytes against the declared 0{measured}"
    )


def test_declared_server_bytes_mismatch_refused(fixture: Fixture) -> None:
    set_row(fixture.manifest, "server_bytes", "1")
    assert "bytes against the declared 1" in refuses_alike(fixture)


# The artifact manifest: the exec guard's row shape and the eligibility grammar.


def test_second_executable_row_refused(fixture: Fixture) -> None:
    append_row(fixture.artifact, "executable\tllama-server\t1\t" + "0" * 64)
    fixture.reseal("artifact-manifest.tsv")
    assert refuses_alike(fixture) == (
        "artifact manifest holds 2 executable llama-server rows; exactly one is required"
    )


def test_missing_executable_row_refused(fixture: Fixture) -> None:
    drop_row(fixture.artifact, "executable")
    fixture.reseal("artifact-manifest.tsv")
    assert refuses_alike(fixture).startswith(
        "artifact manifest holds 0 executable llama-server rows"
    )


def test_executable_row_not_matching_the_server_refused(fixture: Fixture) -> None:
    rows = fixture.artifact.read_text(encoding="utf-8").splitlines()
    rewritten = [
        "\t".join(row.split("\t")[:2] + ["1", row.split("\t")[3]])
        if row.startswith("executable")
        else row
        for row in rows
    ]
    write_rows(fixture.artifact, "".join(f"{row}\n" for row in rewritten))
    fixture.reseal("artifact-manifest.tsv")
    assert refuses_alike(fixture) == (
        "artifact manifest executable llama-server row does not match the bundled server"
    )


def test_duplicate_serving_eligible_refused(fixture: Fixture) -> None:
    prepend_row(fixture.artifact, "serving_eligible\tyes")
    prepend_row(fixture.artifact, "serving_eligible\tno")
    fixture.reseal("artifact-manifest.tsv")
    assert refuses_alike(fixture).startswith(
        "artifact manifest holds 2 serving_eligible rows and 0 instrumentation rows"
    )


def test_instrumentation_row_refused(fixture: Fixture) -> None:
    prepend_row(fixture.artifact, "instrumentation\tpipeline-census-v3")
    fixture.reseal("artifact-manifest.tsv")
    assert refuses_alike(fixture).startswith(
        "artifact manifest names instrumentation pipeline-census-v3; "
        "a bundle carries serving builds alone"
    )


def test_instrumentation_row_refused_ahead_of_an_eligible_spelling(fixture: Fixture) -> None:
    prepend_row(fixture.artifact, "serving_eligible\tyes")
    prepend_row(fixture.artifact, "instrumentation\tpipeline-census-v3")
    fixture.reseal("artifact-manifest.tsv")
    assert "names instrumentation pipeline-census-v3" in refuses_alike(fixture)


def test_empty_serving_eligible_refused(fixture: Fixture) -> None:
    prepend_row(fixture.artifact, "serving_eligible\t")
    fixture.reseal("artifact-manifest.tsv")
    assert refuses_alike(fixture).startswith(
        "artifact manifest declares serving_eligible <empty>; a bundle carries serving builds alone"
    )


def test_serving_eligible_no_refused(fixture: Fixture) -> None:
    prepend_row(fixture.artifact, "serving_eligible\tno")
    fixture.reseal("artifact-manifest.tsv")
    assert refuses_alike(fixture).startswith("artifact manifest declares serving_eligible no")


def test_serving_eligible_yes_admitted(fixture: Fixture) -> None:
    prepend_row(fixture.artifact, "serving_eligible\tyes")
    fixture.reseal("artifact-manifest.tsv")
    verify_bundle(fixture.root, fixture.name)
    if SH is not None:
        assert shell_verify(fixture.root, fixture.name).returncode == 0


@pytest.mark.parametrize("rows", [0, 2])
def test_checkpoint_semantics_cardinality_refused(fixture: Fixture, rows: int) -> None:
    if rows == 0:
        drop_row(fixture.artifact, "checkpoint_semantics")
    else:
        append_row(fixture.artifact, "checkpoint_semantics\tnatural-boundary-v1")
    fixture.reseal("artifact-manifest.tsv")
    assert refuses_alike(fixture) == (
        "artifact manifest must carry exactly one checkpoint_semantics row"
    )


def test_semantics_disagreement_refused(fixture: Fixture) -> None:
    set_row(fixture.manifest, "checkpoint_semantics", "forced-tail-v1")
    assert refuses_alike(fixture) == (
        "artifact manifest declares checkpoint_semantics natural-boundary-v1 against the "
        "bundle manifest declaration forced-tail-v1"
    )


def test_consistent_semantics_rewrite_refused_on_the_positive_count(fixture: Fixture) -> None:
    # A writer who edits the artifact manifest and updates every digest still
    # fails, because the pairing rule is recomputed rather than trusted.
    set_row(fixture.artifact, "checkpoint_semantics", "forced-tail-v1")
    fixture.reseal("artifact-manifest.tsv")
    set_row(fixture.manifest, "checkpoint_semantics", "forced-tail-v1")
    assert refuses_alike(fixture) == (
        "bundle pairs a positive checkpoint count with forced-tail-v1; "
        "a positive count requires natural-boundary-v1"
    )


# The ledger, revalidated through the registry validator.


@pytest.mark.parametrize(
    ("ledger", "detail"),
    [
        (
            "qwen-absent\t2\tevidence/run\n",
            "qwen-absent: model_id is absent from the model registry",
        ),
        ("qwen-2b\t02\tevidence/run\n", "qwen-2b: ctx_checkpoints 02 is not a canonical"),
        ("qwen-2b\t-1\tevidence/run\n", "qwen-2b: ctx_checkpoints -1 is not a canonical"),
        ("qwen-2b\t2\t-\n", "qwen-2b: a count above 0 requires retained evidence"),
        ("qwen-2b\t2\t\n", "qwen-2b: evidence is empty; write - for an unmeasured zero"),
        ("qwen-2b\t2\n", "context checkpoint row 1 holds 2 fields, expected 3"),
        (
            "qwen-2b\t2\tevidence/run\nqwen-2b\t2\tevidence/run\n",
            "duplicate model_id qwen-2b at context checkpoint row 2",
        ),
        ("qwen-2b\t2\t/etc/passwd\n", "qwen-2b: evidence is not a repository-relative path"),
        ("qwen-2b\t2\ta/../../b\n", "qwen-2b: evidence is not a repository-relative path"),
    ],
)
def test_ledger_failing_registry_validation_refused(
    fixture: Fixture, ledger: str, detail: str
) -> None:
    write_rows(fixture.directory / "ctx-checkpoints.tsv", ledger)
    fixture.reseal("ctx-checkpoints.tsv")
    with pytest.raises(DeploymentError) as caught:
        fixture.verify()
    assert str(caught.value) == (
        f"bundle ledger failed registry validation: {fixture.directory / 'ctx-checkpoints.tsv'}"
    )
    assert any(detail in line for line in caught.value.details), caught.value.details
    if SH is not None:
        result = shell_verify(fixture.root, fixture.name)
        assert result.returncode != 0
        assert str(caught.value) in result.stderr
        # The nested validator writes its own reason, which the Python details
        # carry rather than fold into the summary line.
        assert detail in result.stderr


def test_maximum_ledger_count_disagreement_refused(fixture: Fixture) -> None:
    set_row(fixture.manifest, "maximum_ledger_count", "3")
    assert refuses_alike(fixture) == "bundle ledger maximum count 2 disagrees with the declared 3"


def test_maximum_ledger_count_compared_as_a_string(fixture: Fixture) -> None:
    set_row(fixture.manifest, "maximum_ledger_count", "02")
    assert refuses_alike(fixture) == "bundle ledger maximum count 2 disagrees with the declared 02"


def test_empty_ledger_reads_zero(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    registry = tmp_path / "models.tsv"
    write_rows(registry, REGISTRY_ROWS)
    monkeypatch.setenv("QWEN_MODEL_REGISTRY", str(registry))
    root = tmp_path / "deployments"
    root.mkdir()
    build_bundle(root, semantics="forced-tail-v1", ledger="")
    identity = verify_bundle(root, BUNDLE_NAME)
    assert identity.maximum_ledger_count == 0
    if SH is not None:
        assert shell_verify(root, BUNDLE_NAME).returncode == 0


# The Q4_K formulation policy: three manifest shapes, three distinct claims.


def test_q4k_policy_divergence_refused(fixture: Fixture) -> None:
    append_row(fixture.directory / "q4k-policy.tsv", "qwen-9b\t-")
    assert refuses_alike(fixture).startswith("bundle member diverged: q4k-policy.tsv expected=")


def test_q4k_policy_recorded_absent_while_present_refused(fixture: Fixture) -> None:
    set_row(fixture.manifest, "q4k-policy.tsv", "-")
    assert refuses_alike(fixture) == (
        "bundle carries q4k-policy.tsv that its manifest records as absent"
    )


def test_q4k_policy_unrecorded_while_present_refused(fixture: Fixture) -> None:
    drop_row(fixture.manifest, "q4k-policy.tsv")
    assert refuses_alike(fixture) == (
        "bundle carries q4k-policy.tsv that its manifest records no row for"
    )


def test_empty_q4k_policy_declaration_refused(fixture: Fixture) -> None:
    set_row(fixture.manifest, "q4k-policy.tsv", "")
    assert refuses_alike(fixture) == (
        f"bundle manifest carries an empty q4k-policy.tsv declaration: {fixture.manifest}"
    )


def test_absent_q4k_policy_member_refused(fixture: Fixture) -> None:
    (fixture.directory / "q4k-policy.tsv").unlink()
    assert refuses_alike(fixture) == (
        f"bundle member is unreadable: {fixture.directory / 'q4k-policy.tsv'}"
    )


def test_legacy_bundle_without_a_q4k_policy_admitted(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    registry = tmp_path / "models.tsv"
    write_rows(registry, REGISTRY_ROWS)
    monkeypatch.setenv("QWEN_MODEL_REGISTRY", str(registry))
    root = tmp_path / "deployments"
    root.mkdir()
    directory = build_bundle(root, q4k_policy=None)
    drop_row(directory / "bundle-manifest.tsv", "q4k-policy.tsv")
    verify_bundle(root, BUNDLE_NAME)
    if SH is not None:
        assert shell_verify(root, BUNDLE_NAME).returncode == 0


def test_preset_carrying_a_variant_under_a_legacy_policy_refused(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    registry = tmp_path / "models.tsv"
    write_rows(registry, REGISTRY_ROWS)
    monkeypatch.setenv("QWEN_MODEL_REGISTRY", str(registry))
    root = tmp_path / "deployments"
    root.mkdir()
    preset = preset_text("2").replace(
        "LLAMA_ARG_CTX_CHECKPOINTS = 2",
        "LLAMA_ARG_CTX_CHECKPOINTS = 2\nLLAMA_ARG_VK_Q4K_VARIANT = e4/4",
    )
    directory = build_bundle(root, router_preset=preset, q4k_policy=None)
    drop_row(directory / "bundle-manifest.tsv", "q4k-policy.tsv")
    fixture = Fixture(root=root, registry=registry)
    message = refuses_alike(fixture)
    assert message == "bundle preset router-presets.ini disagrees with the bundled ledger"


# The presets: digested where present, and re-read against the bundled ledger.


@pytest.mark.parametrize("member", ["router-presets.ini", "web-presets.ini"])
def test_preset_divergence_refused(fixture: Fixture, member: str) -> None:
    append_row(fixture.directory / member, "# edited after assembly")
    assert refuses_alike(fixture).startswith(f"bundle member diverged: {member} expected=")


@pytest.mark.parametrize("member", ["router-presets.ini", "web-presets.ini"])
def test_preset_recorded_absent_while_present_refused(fixture: Fixture, member: str) -> None:
    set_row(fixture.manifest, member, "-")
    assert refuses_alike(fixture) == (
        f"bundle carries {member} that its manifest records as absent"
    )


@pytest.mark.parametrize("member", ["router-presets.ini", "web-presets.ini"])
def test_absent_preset_member_refused(fixture: Fixture, member: str) -> None:
    (fixture.directory / member).unlink()
    assert refuses_alike(fixture) == f"bundle member is unreadable: {fixture.directory / member}"


def test_preset_disagreeing_with_the_ledger_refused(fixture: Fixture) -> None:
    write_rows(fixture.directory / "router-presets.ini", preset_text("0"))
    fixture.reseal("router-presets.ini")
    message = refuses_alike(fixture)
    assert message == "bundle preset router-presets.ini disagrees with the bundled ledger"
    with pytest.raises(DeploymentError) as caught:
        fixture.verify()
    assert caught.value.details[0] == (
        "preset section [qwen-2b] carries checkpoint count 0 where the bundled ledger "
        "states 2 for qwen-2b"
    )


def test_preset_path_matching_two_registry_rows_refused(fixture: Fixture) -> None:
    # The raw suffix rule binds a section to one row, so a registry whose files
    # are suffixes of one another binds no section at all.
    # Both rows are suffixes of the section's path, so the raw suffix rule
    # matches twice where model-registry.sh would answer with the first row.
    write_rows(fixture.registry, REGISTRY_ROWS + "qwen-2b-copy\tfast\t2b.gguf\n")
    with pytest.raises(DeploymentError) as caught:
        fixture.verify()
    assert "resolves to 2 registry rows" in caught.value.details[0]
    assert refuses_alike(fixture) == (
        "bundle preset router-presets.ini disagrees with the bundled ledger"
    )


def test_preset_without_a_model_key_refused(fixture: Fixture) -> None:
    write_rows(
        fixture.directory / "router-presets.ini",
        "[qwen-2b]\nLLAMA_ARG_CTX_CHECKPOINTS = 2\n",
    )
    fixture.reseal("router-presets.ini")
    with pytest.raises(DeploymentError) as caught:
        fixture.verify()
    assert caught.value.details[0] == (
        "preset section [qwen-2b] carries 0 LLAMA_ARG_MODEL keys; exactly one is required"
    )
    refuses_alike(fixture)


def test_preset_carrying_no_sections_refused(fixture: Fixture) -> None:
    write_rows(fixture.directory / "router-presets.ini", "# fixture preset\n")
    fixture.reseal("router-presets.ini")
    with pytest.raises(DeploymentError) as caught:
        fixture.verify()
    assert caught.value.details[0] == (
        f"preset carries no sections: {fixture.directory / 'router-presets.ini'}"
    )
    refuses_alike(fixture)


# The web MCP record, which the preset's own head marker requires or withholds.

MERGED_CONFIGURATION = "/nonexistent/web-open.json"
MERGED_PRESET = (
    "# qwen_web_sections=web-open\n"
    f"[qwen-2b]\nLLAMA_ARG_MODEL = {MODEL_ROOT}/qwen-2b.gguf\n"
    "LLAMA_ARG_CTX_CHECKPOINTS = 0\n\n"
    f"[web-open]\nLLAMA_ARG_MODEL = {MODEL_ROOT}/qwen-2b.gguf\n"
    "LLAMA_ARG_CTX_CHECKPOINTS = 0\n"
    f"LLAMA_ARG_MCP_SERVERS_CONFIG = {MERGED_CONFIGURATION}\n"
)
MERGED_RECORD = (
    "# profile_id\tconfiguration_path\tsha256\timage_server\n"
    f"web-open\t{MERGED_CONFIGURATION}\t{'a' * 64}\t-\n"
)


@pytest.fixture
def merged(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Fixture:
    registry = tmp_path / "models.tsv"
    write_rows(registry, REGISTRY_ROWS)
    monkeypatch.setenv("QWEN_MODEL_REGISTRY", str(registry))
    monkeypatch.delenv("QWEN_HOME", raising=False)
    root = tmp_path / "deployments"
    root.mkdir()
    build_bundle(
        root,
        semantics="forced-tail-v1",
        ledger=ZERO_LEDGER,
        router_preset=MERGED_PRESET,
        web_mcp=MERGED_RECORD,
    )
    return Fixture(root=root, registry=registry)


@shell_required
def test_merged_bundle_accepted_by_both(merged: Fixture) -> None:
    verify_bundle(merged.root, merged.name)
    assert shell_verify(merged.root, merged.name).returncode == 0


def test_web_mcp_record_drift_refused(merged: Fixture) -> None:
    record = merged.directory / "web-mcp-manifest.tsv"
    write_rows(record, MERGED_RECORD.replace(MERGED_CONFIGURATION, "/nonexistent/moved.json"))
    merged.reseal("web-mcp-manifest.tsv")
    assert refuses_alike(merged) == (
        "web-mcp-manifest.tsv records configurations the bundled router preset does not name"
    )


def test_marked_preset_without_a_record_refused(merged: Fixture) -> None:
    set_row(merged.manifest, "web-mcp-manifest.tsv", "-")
    assert refuses_alike(merged) == (
        "bundle router preset names web section web-open and its manifest records no "
        "web-mcp-manifest.tsv"
    )


def test_web_mcp_record_divergence_refused(merged: Fixture) -> None:
    append_row(merged.directory / "web-mcp-manifest.tsv", "# edited after assembly")
    assert refuses_alike(merged).startswith(
        "bundle member diverged: web-mcp-manifest.tsv expected="
    )


def test_malformed_web_mcp_row_refused(merged: Fixture) -> None:
    write_rows(
        merged.directory / "web-mcp-manifest.tsv",
        MERGED_RECORD.replace("a" * 64, "not-a-digest"),
    )
    merged.reseal("web-mcp-manifest.tsv")
    assert refuses_alike(merged).startswith("web-mcp-manifest.tsv row is malformed:")


def test_image_column_without_the_marker_refused(merged: Fixture) -> None:
    write_rows(
        merged.directory / "web-mcp-manifest.tsv",
        MERGED_RECORD.replace(f"{'a' * 64}\t-", f"{'a' * 64}\timage"),
    )
    merged.reseal("web-mcp-manifest.tsv")
    assert refuses_alike(merged) == (
        "web-mcp-manifest.tsv records image_server image for web-open where the preset "
        "marker reads -"
    )


def test_foreign_image_column_refused(merged: Fixture) -> None:
    write_rows(
        merged.directory / "web-mcp-manifest.tsv",
        MERGED_RECORD.replace(f"{'a' * 64}\t-", f"{'a' * 64}\tvideo"),
    )
    merged.reseal("web-mcp-manifest.tsv")
    assert refuses_alike(merged) == (
        f"web-mcp-manifest.tsv row carries image_server video: web-open\t"
        f"{MERGED_CONFIGURATION}\t{'a' * 64}\tvideo"
    )


def test_image_marker_requires_the_image_column(merged: Fixture) -> None:
    preset = merged.directory / "router-presets.ini"
    write_rows(preset, "# qwen_image_profile=image-sdxs-512-a\n" + MERGED_PRESET)
    merged.reseal("router-presets.ini")
    assert refuses_alike(merged) == (
        "web-mcp-manifest.tsv records image_server - for web-open where the preset "
        "marker reads image"
    )


def test_record_under_an_unmarked_preset_refused(fixture: Fixture) -> None:
    write_rows(fixture.directory / "web-mcp-manifest.tsv", MERGED_RECORD)
    fixture.reseal("web-mcp-manifest.tsv")
    assert refuses_alike(fixture) == (
        "bundle manifest records web-mcp-manifest.tsv where its router preset names no web section"
    )


def test_record_file_under_an_unmarked_preset_refused(fixture: Fixture) -> None:
    write_rows(fixture.directory / "web-mcp-manifest.tsv", MERGED_RECORD)
    assert refuses_alike(fixture) == (
        "bundle carries web-mcp-manifest.tsv that its manifest records as absent"
    )


def test_mcp_key_under_an_unmarked_preset_refused(fixture: Fixture) -> None:
    write_rows(
        fixture.directory / "router-presets.ini",
        preset_text("2") + f"LLAMA_ARG_MCP_SERVERS_CONFIG = {MERGED_CONFIGURATION}\n",
    )
    fixture.reseal("router-presets.ini")
    assert refuses_alike(fixture) == (
        "bundle router preset names MCP configurations and its head marker names no web section"
    )


def test_image_marker_under_an_unmarked_preset_refused(fixture: Fixture) -> None:
    write_rows(
        fixture.directory / "router-presets.ini",
        "# qwen_image_profile=image-sdxs-512-a\n" + preset_text("2"),
    )
    fixture.reseal("router-presets.ini")
    assert refuses_alike(fixture) == (
        "bundle router preset names an image profile and its head marker names no web section"
    )


def test_withheld_image_marker_admitted(fixture: Fixture) -> None:
    write_rows(
        fixture.directory / "router-presets.ini",
        "# qwen_image_profile=-\n" + preset_text("2"),
    )
    fixture.reseal("router-presets.ini")
    verify_bundle(fixture.root, fixture.name)
    if SH is not None:
        assert shell_verify(fixture.root, fixture.name).returncode == 0


# The launch-side resolver: one canonical bundle under the shared lock.


def activate(fixture: Fixture, name: str | None = None) -> None:
    pointer = fixture.root / "deployment-current"
    if pointer.is_symlink() or pointer.exists():
        pointer.unlink()
    pointer.symlink_to(name or fixture.name)


@shell_required
def test_resolution_renders_the_shell_output_byte_for_byte(fixture: Fixture) -> None:
    activate(fixture)
    result = shell_resolve(fixture.root)
    assert result.returncode == 0, result.stderr
    assert render(resolve_active(fixture.root)) == result.stdout


@shell_required
def test_absent_preset_renders_a_dash(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    registry = tmp_path / "models.tsv"
    write_rows(registry, REGISTRY_ROWS)
    monkeypatch.setenv("QWEN_MODEL_REGISTRY", str(registry))
    monkeypatch.delenv("QWEN_HOME", raising=False)
    root = tmp_path / "deployments"
    root.mkdir()
    build_bundle(root)
    (root / "deployment-current").symlink_to(BUNDLE_NAME)
    active = resolve_active(root)
    assert active.web_presets is None
    assert "active_deployment_web_presets=-\n" in render(active)
    assert render(active) == shell_resolve(root).stdout


def test_resolution_names_the_bundle_members(fixture: Fixture) -> None:
    activate(fixture)
    active = resolve_active(fixture.root)
    assert active.name == fixture.name
    assert active.directory == Path(os.path.realpath(fixture.directory))
    assert active.server == active.directory / "llama-server"
    assert active.ledger == active.directory / "ctx-checkpoints.tsv"
    assert active.manifest == active.directory / "bundle-manifest.tsv"
    assert active.router_presets == active.directory / "router-presets.ini"


def test_no_deployment_root_reports_absence(tmp_path: Path) -> None:
    missing = tmp_path / "absent"
    message = resolution_refuses_alike(missing, NoActiveDeployment)
    assert message == f"no deployment root: {missing}"


def test_empty_root_reports_absence(tmp_path: Path) -> None:
    root = tmp_path / "empty-root"
    root.mkdir()
    message = resolution_refuses_alike(root, NoActiveDeployment)
    assert message == f"no deployment-current under {root}"


def test_plain_deployment_current_refused(fixture: Fixture) -> None:
    (fixture.root / "deployment-current").mkdir()
    assert resolution_refuses_alike(fixture.root) == (
        f"deployment-current is not a symlink: {fixture.root / 'deployment-current'}"
    )


def test_dangling_deployment_current_refused(fixture: Fixture) -> None:
    (fixture.root / "deployment-current").symlink_to("bundle-absent")
    assert resolution_refuses_alike(fixture.root) == (
        f"deployment-current does not resolve to a directory: {fixture.root / 'deployment-current'}"
    )


def test_deployment_current_outside_the_root_refused(fixture: Fixture, tmp_path: Path) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    (fixture.root / "deployment-current").symlink_to(outside)
    assert "active deployment resolves outside the deployment root" in resolution_refuses_alike(
        fixture.root
    )


def test_deployment_current_on_a_reserved_name_refused(fixture: Fixture) -> None:
    (fixture.root / ".hidden").mkdir()
    (fixture.root / "deployment-current").symlink_to(".hidden")
    assert resolution_refuses_alike(fixture.root) == (
        "active deployment name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid the root "
        "names: .hidden"
    )


def test_resolution_verifies_the_bundle_it_follows(fixture: Fixture) -> None:
    activate(fixture)
    set_row(fixture.manifest, "maximum_ledger_count", "3")
    assert resolution_refuses_alike(fixture.root) == (
        "bundle ledger maximum count 2 disagrees with the declared 3"
    )


def test_explicit_directory_is_verified_rather_than_trusted(
    fixture: Fixture, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    activate(fixture)
    monkeypatch.setenv("QWEN_ACTIVE_DEPLOYMENT_DIRECTORY", str(outside))
    assert "active deployment resolves outside the deployment root" in resolution_refuses_alike(
        fixture.root, DeploymentError, QWEN_ACTIVE_DEPLOYMENT_DIRECTORY=str(outside)
    )


def test_explicit_directory_must_be_a_plain_directory(
    fixture: Fixture, monkeypatch: pytest.MonkeyPatch
) -> None:
    linked = fixture.root / "bundle-alias"
    linked.symlink_to(fixture.directory)
    activate(fixture)
    monkeypatch.setenv("QWEN_ACTIVE_DEPLOYMENT_DIRECTORY", str(linked))
    assert (
        resolution_refuses_alike(
            fixture.root, DeploymentError, QWEN_ACTIVE_DEPLOYMENT_DIRECTORY=str(linked)
        )
        == f"QWEN_ACTIVE_DEPLOYMENT_DIRECTORY is not a plain directory: {linked}"
    )


@shell_required
def test_retained_directory_survives_a_moved_pointer(fixture: Fixture) -> None:
    build_bundle(fixture.root, "bundle-second", semantics="forced-tail-v1", ledger=ZERO_LEDGER)
    activate(fixture)
    retained = resolve_active(fixture.root)
    activate(fixture, "bundle-second")
    assert resolve_active(fixture.root).name == "bundle-second"
    again = resolve_active(fixture.root, retained.directory)
    assert again.name == fixture.name
    assert (
        render(again)
        == shell_resolve(
            fixture.root, QWEN_ACTIVE_DEPLOYMENT_DIRECTORY=str(retained.directory)
        ).stdout
    )


# The activation lock leaf, opened through the private-regular-leaf contract.


def lock_refuses_alike(root: Path) -> str:
    with pytest.raises(DeploymentError) as caught:
        resolve_active(root)
    message = str(caught.value)
    if SH is not None:
        result = shell_resolve(root)
        assert result.returncode != 0
        assert "verified_lock_descriptor=rejected" in result.stderr
        assert message in result.stderr, f"python said {message!r}, shell said {result.stderr!r}"
    return message


def test_symlinked_lock_leaf_refused(fixture: Fixture, tmp_path: Path) -> None:
    sentinel = tmp_path / "sentinel"
    write_rows(sentinel, "sentinel\n")
    activate(fixture)
    (fixture.root / ".activate.lock").symlink_to(sentinel)
    lock_refuses_alike(fixture.root)
    assert sentinel.read_text(encoding="utf-8") == "sentinel\n"


def test_directory_at_the_lock_path_refused(fixture: Fixture) -> None:
    activate(fixture)
    (fixture.root / ".activate.lock").mkdir()
    lock_refuses_alike(fixture.root)


def test_loose_lock_mode_refused(fixture: Fixture) -> None:
    activate(fixture)
    lock_path = fixture.root / ".activate.lock"
    lock_path.touch()
    lock_path.chmod(0o666)
    assert "grants write access to another user" in lock_refuses_alike(fixture.root)


def test_hard_linked_lock_leaf_refused(fixture: Fixture, tmp_path: Path) -> None:
    activate(fixture)
    private = tmp_path / "private-leaf"
    private.touch()
    private.chmod(0o600)
    os.link(private, fixture.root / ".activate.lock")
    assert "hard links" in lock_refuses_alike(fixture.root)


@shell_required
def test_legacy_lock_mode_normalized(fixture: Fixture) -> None:
    activate(fixture)
    lock_path = fixture.root / ".activate.lock"
    lock_path.touch()
    lock_path.chmod(0o644)
    resolve_active(fixture.root)
    assert lock_path.stat().st_mode & 0o777 == 0o600
    lock_path.chmod(0o644)
    assert shell_resolve(fixture.root).returncode == 0
    assert lock_path.stat().st_mode & 0o777 == 0o600


def test_legacy_lock_mode_refused_where_normalization_is_withheld(fixture: Fixture) -> None:
    lock_path = fixture.root / ".activate.lock"
    lock_path.touch()
    lock_path.chmod(0o644)
    with pytest.raises(DeploymentError) as caught:
        open_verified_lock(lock_path, normalize_legacy_mode=False)
    assert "grants group or other access" in str(caught.value)


def test_lock_leaf_created_private(fixture: Fixture) -> None:
    activate(fixture)
    resolve_active(fixture.root)
    assert (fixture.root / ".activate.lock").stat().st_mode & 0o777 == 0o600


def test_absence_is_decided_under_the_lock(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    # A resolver answering absence from a pre-lock read would report an empty
    # root while an activation was midway through publishing one.
    registry = tmp_path / "models.tsv"
    write_rows(registry, REGISTRY_ROWS)
    monkeypatch.setenv("QWEN_MODEL_REGISTRY", str(registry))
    root = tmp_path / "locked-root"
    root.mkdir()
    lock_path = root / ".activate.lock"
    lock_path.touch()
    lock_path.chmod(0o600)
    holder = os.open(lock_path, os.O_RDWR)
    resolved: list[BaseException | ActiveDeployment] = []

    def resolve() -> None:
        try:
            resolved.append(resolve_active(root))
        except BaseException as error:  # noqa: BLE001 - the thread reports either outcome
            resolved.append(error)

    try:
        fcntl.flock(holder, fcntl.LOCK_EX)
        waiter = threading.Thread(target=resolve)
        waiter.start()
        waiter.join(timeout=1.0)
        assert waiter.is_alive(), f"the resolution answered under a held lock: {resolved}"
    finally:
        fcntl.flock(holder, fcntl.LOCK_UN)
        os.close(holder)
    waiter.join(timeout=5.0)
    assert not waiter.is_alive()
    assert isinstance(resolved[0], NoActiveDeployment)


def test_empty_web_mcp_declaration_reads_as_absent(fixture: Fixture) -> None:
    # `${web_mcp_expected_sha256:--}` reads an empty declaration as the absent
    # member, where the q4k-policy.tsv reading of the same shape refuses it.
    set_row(fixture.manifest, "web-mcp-manifest.tsv", "")
    verify_bundle(fixture.root, fixture.name)
    if SH is not None:
        assert shell_verify(fixture.root, fixture.name).returncode == 0


def test_indented_section_reaches_one_parser_alone(fixture: Fixture) -> None:
    # The MCP extractor matches `^[[:space:]]*\[` where the ledger checker
    # requires column 0, so an indented header names a section for the first
    # reader and folds its keys into the preceding section for the second.
    write_rows(
        fixture.directory / "router-presets.ini",
        "# qwen_web_sections=web-open\n"
        + preset_text("2")
        + f"  [web-open]\n  LLAMA_ARG_MODEL = {MODEL_ROOT}/qwen-2b.gguf\n"
        + "  LLAMA_ARG_CTX_CHECKPOINTS = 2\n"
        + f"  LLAMA_ARG_MCP_SERVERS_CONFIG = {MERGED_CONFIGURATION}\n",
    )
    fixture.reseal("router-presets.ini")
    with pytest.raises(DeploymentError) as caught:
        fixture.verify()
    assert caught.value.details[0] == (
        "preset section [qwen-2b+draft] carries 2 LLAMA_ARG_CTX_CHECKPOINTS keys; "
        "exactly one is required"
    )
    assert refuses_alike(fixture) == (
        "bundle preset router-presets.ini disagrees with the bundled ledger"
    )


def test_carriage_return_stays_inside_the_compared_field(fixture: Fixture) -> None:
    # awk splits records on a newline alone, so a CRLF manifest carries the
    # carriage return into the field it compares; a reader splitting on every
    # line boundary would admit the bundle this refuses.
    fixture.manifest.write_bytes(
        fixture.manifest.read_bytes().replace(
            b"maximum_ledger_count\t2\n", b"maximum_ledger_count\t2\r\n"
        )
    )
    assert refuses_alike(fixture) == (
        "bundle ledger maximum count 2 disagrees with the declared 2\r"
    )
