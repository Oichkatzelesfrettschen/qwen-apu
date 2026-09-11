"""One application deployment built from this checkout, verified, and tampered with.

Every case runs against a temporary runtime root laid out the way
`RuntimePaths.lay_out` lays out a fresh one, so the build writes under that root
alone and the checkout it reads is this tree. The wheel is checked two ways: by
its own archive contents against PEP 427, and by an offline `pip install
--target`, which is the reader that refuses a missing `WHEEL` file.
"""

from __future__ import annotations

import base64
import hashlib
import json
import subprocess
import sys
import zipfile
from collections.abc import Iterator
from pathlib import Path

import pytest

from qwen_apu import __version__
from qwen_apu.install import native
from qwen_apu.runtime import application_deployment as application
from qwen_apu.runtime.paths import RuntimePaths

TREE = Path(__file__).resolve().parents[1]


@pytest.fixture
def paths(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[RuntimePaths]:
    monkeypatch.setenv("QWEN_HOME", str(tmp_path / "root"))
    resolved = RuntimePaths.resolve(TREE)
    resolved.lay_out()
    yield resolved


def _manifest(directory: Path) -> dict[str, object]:
    return dict(json.loads((directory / application.MANIFEST_NAME).read_text(encoding="utf-8")))


def _make_writable(path: Path) -> None:
    """Published members are 0o444, so a tamper opens the mode it closed."""
    path.chmod(0o644)


# ---------------------------------------------------------------------------
# The wheel
# ---------------------------------------------------------------------------


def test_wheel_carries_every_file_pep_427_requires(tmp_path: Path) -> None:
    wheel = application.build_wheel(TREE, tmp_path / application.wheel_filename(__version__))
    dist_info = f"qwen_apu-{__version__}.dist-info"
    with zipfile.ZipFile(wheel) as archive:
        names = set(archive.namelist())
        record = archive.read(f"{dist_info}/RECORD").decode("utf-8")
        wheel_document = archive.read(f"{dist_info}/WHEEL").decode("utf-8")
        metadata = archive.read(f"{dist_info}/METADATA").decode("utf-8")
        entry_points = archive.read(f"{dist_info}/entry_points.txt").decode("utf-8")
        payloads = {name: archive.read(name) for name in names}
        timestamps = {info.date_time for info in archive.infolist()}
        compressions = {info.compress_type for info in archive.infolist()}

    assert f"{dist_info}/METADATA" in names
    assert f"{dist_info}/WHEEL" in names
    assert "qwen_apu/__init__.py" in names
    assert "qwen_apu/py.typed" in names
    assert not any(name.endswith(".pyc") for name in names)
    assert "Root-Is-Purelib: true" in wheel_document
    assert "Tag: py3-none-any" in wheel_document
    assert f"Version: {__version__}" in metadata
    assert "qwen-apu = qwen_apu.cli:main" in entry_points
    # One fixed timestamp across every member is what makes the digest name the
    # source rather than the clock the build ran on.
    assert timestamps == {application.WHEEL_TIMESTAMP}
    # Every member is stored rather than deflated: a deflate stream is an
    # encoder's choice and two zlib builds disagree on the bytes, so a deflated
    # wheel would carry one digest per host.
    assert compressions == {zipfile.ZIP_STORED}

    rows = {
        line.split(",")[0]: line.split(",")[1]
        for line in record.splitlines()
        if line and "," in line
    }
    assert rows[f"{dist_info}/RECORD"] == ""
    for name, payload in payloads.items():
        if name == f"{dist_info}/RECORD":
            continue
        expected = base64.urlsafe_b64encode(hashlib.sha256(payload).digest())
        assert rows[name] == "sha256=" + expected.decode("ascii").rstrip("=")


def test_two_builds_of_one_commit_digest_identically(tmp_path: Path) -> None:
    first = application.build_wheel(TREE, tmp_path / "first.whl")
    second = application.build_wheel(TREE, tmp_path / "second.whl")
    assert first.read_bytes() == second.read_bytes()


def test_pip_installs_the_wheel_offline(tmp_path: Path) -> None:
    """The reader that refuses an archive missing `WHEEL`, run with no network."""
    wheel = application.build_wheel(TREE, tmp_path / application.wheel_filename(__version__))
    target = tmp_path / "site"
    completed = subprocess.run(
        [
            sys.executable,
            "-m",
            "pip",
            "install",
            "--quiet",
            "--no-index",
            "--no-deps",
            "--target",
            str(target),
            str(wheel),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0 and "No module named pip" in completed.stderr:
        pytest.skip("pip is absent from this interpreter")
    assert completed.returncode == 0, completed.stderr
    assert (target / "qwen_apu" / "cli.py").is_file()
    assert (target / f"qwen_apu-{__version__}.dist-info" / "WHEEL").is_file()


# ---------------------------------------------------------------------------
# Build and verify
# ---------------------------------------------------------------------------


def test_build_publishes_one_sealed_unit_and_verify_passes(paths: RuntimePaths) -> None:
    identity = application.build_application(paths, "application-a")
    assert identity.directory == paths["qwen_home_deployments"] / "applications" / "application-a"
    assert (identity.directory / application.LIBRARY_DIRECTORY / application.LOCK_NAME).is_file()
    assert (identity.directory / "static" / "index.html").is_file()
    assert (identity.directory / "config" / "native-builds.toml").is_file()
    # The staging directory leaves nothing behind under the published name.
    staged = list((identity.directory.parent / ".staging").glob("application.*"))
    assert staged == []

    manifest = _manifest(identity.directory)
    assert manifest["schema"] == application.MANIFEST_SCHEMA
    assert manifest["source_commit"] == identity.source_commit
    assert manifest["manifest_sha256"] == identity.manifest_sha256
    migrations = manifest["migrations"]
    assert isinstance(migrations, dict)
    assert migrations["schema_version"] >= 1
    registries = manifest["registries"]
    assert isinstance(registries, dict)
    assert registries["remote/models.tsv"] != "-"
    security = manifest["security_policy"]
    assert isinstance(security, dict)
    assert "script-src 'self'" in str(security["content_security_policy"])
    extractors = manifest["document_extractors"]
    assert isinstance(extractors, dict)
    assert any("pypdf" in entry for entry in extractors["pinned_distributions"])

    report = application.verify_application(paths, "application-a")
    assert report.verified, report.mismatches
    assert "static/index.html" in report.checked
    assert application.applications(paths) == ("application-a",)


def test_a_second_build_under_one_name_refuses(paths: RuntimePaths) -> None:
    application.build_application(paths, "application-a")
    with pytest.raises(application.ApplicationRefused, match="already exists"):
        application.build_application(paths, "application-a")


def test_a_tampered_static_byte_refuses(paths: RuntimePaths) -> None:
    identity = application.build_application(paths, "application-a")
    page = identity.directory / "static" / "index.html"
    _make_writable(page)
    page.write_bytes(page.read_bytes() + b"<!-- one byte more -->")
    report = application.verify_application(paths, "application-a")
    assert not report.verified
    assert any("static/index.html digests" in detail for detail in report.mismatches)


def test_a_tampered_wheel_byte_refuses(paths: RuntimePaths) -> None:
    identity = application.build_application(paths, "application-a")
    wheel = (
        identity.directory / application.LIBRARY_DIRECTORY / application.wheel_filename(__version__)
    )
    _make_writable(wheel)
    payload = bytearray(wheel.read_bytes())
    payload[-1] ^= 0xFF
    wheel.write_bytes(bytes(payload))
    report = application.verify_application(paths, "application-a")
    assert not report.verified
    assert any("digests" in detail for detail in report.mismatches)


def test_a_rewritten_manifest_field_breaks_its_own_seal(paths: RuntimePaths) -> None:
    identity = application.build_application(paths, "application-a")
    manifest_path = identity.directory / application.MANIFEST_NAME
    _make_writable(manifest_path)
    manifest = _manifest(identity.directory)
    manifest["source_commit"] = "0" * 40
    manifest_path.write_bytes(application.canonical_manifest(manifest))
    report = application.verify_application(paths, "application-a")
    assert not report.verified
    assert any("reseals to" in detail for detail in report.mismatches)


def test_an_added_static_file_refuses(paths: RuntimePaths) -> None:
    """A member the manifest names nowhere is a change the tree digest cannot see."""
    identity = application.build_application(paths, "application-a")
    (identity.directory / "static").chmod(0o755)
    (identity.directory / "static" / "extra.js").write_text("export const x = 1;\n")
    report = application.verify_application(paths, "application-a")
    assert not report.verified
    assert any("names it nowhere" in detail for detail in report.mismatches)


def test_an_absent_application_refuses_by_name(paths: RuntimePaths) -> None:
    with pytest.raises(application.ApplicationRefused, match="no application deployment named"):
        application.verify_application(paths, "absent")


def test_an_invalid_name_refuses_before_anything_is_written(paths: RuntimePaths) -> None:
    with pytest.raises(application.ApplicationRefused, match="application name must match"):
        application.build_application(paths, ".hidden")
    assert not (paths["qwen_home_deployments"] / "applications" / ".hidden").exists()


# ---------------------------------------------------------------------------
# The native store reference
# ---------------------------------------------------------------------------


def _plant_native_bundle(paths: RuntimePaths) -> Path:
    """One store entry whose manifest seals a fixture executable's identity.

    The manifest is written directly rather than staged from a build tree,
    because `stage_bundle` binds its inputs to a recipe's exact target set and
    parses each executable's ELF headers; what this test reads is the store
    reference and its seal, which a well-formed manifest supplies on its own.
    """
    executable = native.ExecutableRecord(
        name="llama-server",
        bytes=24,
        sha256="b" * 64,
        dt_needed=("libc.so.6",),
        interp="ld-linux-x86-64.so.2",
        glibc_required="GLIBC_2.39",
    )
    manifest = native.BundleManifest(
        schema=native.MANIFEST_SCHEMA,
        recipe="llama",
        profile="raven2-vulkan",
        install_prefix="llama",
        upstream_commit="c" * 40,
        source_commit="d" * 40,
        patch_series=(),
        patch_series_sha256="e" * 64,
        cmake_defines={},
        compiler_identity="fixture",
        glibc_required="GLIBC_2.39",
        executables=(executable,),
        bundle_sha256="a" * 64,
        manifest_sha256="f" * 64,
    )
    store = paths["qwen_home_opt"] / "llama" / manifest.bundle_sha256
    store.mkdir(parents=True)
    (store / native.MANIFEST_NAME).write_bytes(native.manifest_to_json(manifest))
    return store


def test_the_native_reference_resolves_and_a_resealed_manifest_refuses(
    paths: RuntimePaths,
) -> None:
    store = _plant_native_bundle(paths)
    identity = application.build_application(paths, "application-a")
    manifest = _manifest(identity.directory)
    engines = manifest["native_engines"]
    assert isinstance(engines, list)
    assert any(entry["store_path"].endswith(store.name) for entry in engines)
    assert application.verify_application(paths, "application-a").verified

    payload = json.loads((store / native.MANIFEST_NAME).read_text(encoding="utf-8"))
    payload["manifest_sha256"] = "0" * 64
    (store / native.MANIFEST_NAME).write_text(json.dumps(payload), encoding="utf-8")
    report = application.verify_application(paths, "application-a")
    assert not report.verified
