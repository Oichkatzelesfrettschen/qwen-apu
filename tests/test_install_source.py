"""Parity tests for the reproducible source path.

`remote/test-prepare-llama-vulkan-source.sh` proves its cases against a local
clone of llama.cpp at the pinned commit, which a workstation may not hold; it
reports `not_run` rather than passing in that case. The synthetic cases below
prove the same properties -- apply order, refusal on a stale patch, refusal on
a digest mismatch, refusal of a candidate ahead of production -- over a
two-patch series a fixture builds, so they run everywhere. The real-tree cases
take the actual production series and skip with a reason where the upstream
tree is absent, the same rule the shell harness applies.
"""

from __future__ import annotations

import hashlib
import os
import shlex
import shutil
import subprocess
import tarfile
import tomllib
from pathlib import Path

import pytest

from qwen_apu.config.models import load_patch_series
from qwen_apu.config.schema import PatchSeriesMember
from qwen_apu.install import build as build_module
from qwen_apu.install import source as source_module
from qwen_apu.install.source import (
    PINNED_COMMIT,
    SOURCE_COMMIT_MARKER,
    AppliedFile,
    AppliedMember,
    Relocation,
    SourceError,
    acquire_upstream,
    apply_patch,
    apply_series,
    parse_patch,
    read_git_head,
    read_patched_sources,
    read_series_marker,
    series_digest,
    sha256_file,
    verify_patched_sources,
)
from qwen_apu.runtime.paths import RuntimePaths

REPOSITORY = Path(__file__).resolve().parents[1]
PATCHES = REPOSITORY / "patches"
BUILD_SCRIPT = REPOSITORY / "remote" / "build-llama-vulkan.sh"
VERIFY_SCRIPT = REPOSITORY / "remote" / "verify-llama-patch-series.sh"

ALPHA_BASE = b"one\ntwo\nthree\nfour\nfive\n"
ALPHA_AFTER_A = b"one\ntwo\nTHREE\nfour\nfive\n"
ALPHA_AFTER_B = b"one\ntwo\nTHREE\nfour\nFOUR AND A HALF\nfive\n"
BETA_AFTER_A = b"beta one\nbeta two\n"
BETA_AFTER_CANDIDATE = b"beta one\nbeta two\nbeta three\n"

PATCH_A = b"""\
diff --git a/alpha.txt b/alpha.txt
index 1111111..2222222 100644
--- a/alpha.txt
+++ b/alpha.txt
@@ -1,5 +1,5 @@
 one
 two
-three
+THREE
 four
 five
diff --git a/beta.txt b/beta.txt
new file mode 100644
index 0000000..3333333
--- /dev/null
+++ b/beta.txt
@@ -0,0 +1,2 @@
+beta one
+beta two
"""

# A member of the real series opens with prose stating its mechanism, so this
# one does too: the parser recognizes a diff by its own shape rather than by
# the file starting with one.
PATCH_B = b"""\
The second member reads the line the first member rewrote, so applying it
against the unpatched file refuses on a context mismatch rather than landing
somewhere else -- the property that makes a stale patch a failure.

diff --git a/alpha.txt b/alpha.txt
index 2222222..4444444 100644
--- a/alpha.txt
+++ b/alpha.txt
@@ -2,4 +2,5 @@
 two
 THREE
 four
+FOUR AND A HALF
 five
"""

PATCH_CANDIDATE = b"""\
diff --git a/beta.txt b/beta.txt
index 3333333..5555555 100644
--- a/beta.txt
+++ b/beta.txt
@@ -1,2 +1,3 @@
 beta one
 beta two
+beta three
"""

# A hunk header counted against a predecessor the file no longer matches: the
# context sits at line 3 and the header states line 1, the shape four hunks of
# the real production series carry.
PATCH_OFFSET = b"""\
--- a/alpha.txt
+++ b/alpha.txt
@@ -1,2 +1,3 @@
 three
 four
+FOUR AND A HALF
"""

PATCH_UNMATCHED = b"""\
--- a/alpha.txt
+++ b/alpha.txt
@@ -1,2 +1,2 @@
 nine
-ten
+TEN
"""

PRODUCTION_A = PatchSeriesMember(stage="production", patch="synthetic-a.patch")
PRODUCTION_B = PatchSeriesMember(stage="production", patch="synthetic-b.patch")
CANDIDATE_C = PatchSeriesMember(stage="candidate", patch="synthetic-candidate.patch")


def _digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@pytest.fixture
def fixture(tmp_path: Path) -> dict[str, Path]:
    """An upstream tree, a patches directory, and a ledger stating the digests
    the two production members produce."""
    upstream = tmp_path / "upstream"
    upstream.mkdir()
    (upstream / "alpha.txt").write_bytes(ALPHA_BASE)
    patches = tmp_path / "patches"
    patches.mkdir()
    (patches / PRODUCTION_A.patch).write_bytes(PATCH_A)
    (patches / PRODUCTION_B.patch).write_bytes(PATCH_B)
    (patches / CANDIDATE_C.patch).write_bytes(PATCH_CANDIDATE)
    ledger = tmp_path / "patched-sources.tsv"
    ledger.write_text(
        f"# path\tsha256\nalpha.txt\t{_digest(ALPHA_AFTER_B)}\nbeta.txt\t{_digest(BETA_AFTER_A)}\n",
        encoding="utf-8",
    )
    return {
        "upstream": upstream,
        "patches": patches,
        "ledger": ledger,
        "target": tmp_path / "patched",
    }


def test_series_applies_in_ledger_order(fixture: dict[str, Path]) -> None:
    result = apply_series(
        fixture["upstream"],
        fixture["target"],
        (PRODUCTION_A, PRODUCTION_B),
        fixture["patches"],
        patched_sources=fixture["ledger"],
    )
    target = fixture["target"]
    assert (target / "alpha.txt").read_bytes() == ALPHA_AFTER_B
    assert (target / "beta.txt").read_bytes() == BETA_AFTER_A
    assert [member.patch for member in result.members] == [
        PRODUCTION_A.patch,
        PRODUCTION_B.patch,
    ]
    assert result.members[0].sha256 == _digest(PATCH_A)
    assert result.verified == (
        ("alpha.txt", _digest(ALPHA_AFTER_B)),
        ("beta.txt", _digest(BETA_AFTER_A)),
    )


def test_marker_records_the_ordered_series(fixture: dict[str, Path]) -> None:
    apply_series(
        fixture["upstream"],
        fixture["target"],
        (PRODUCTION_A, PRODUCTION_B),
        fixture["patches"],
        patched_sources=fixture["ledger"],
    )
    assert read_series_marker(fixture["target"]) == (
        AppliedMember("production", PRODUCTION_A.patch, _digest(PATCH_A)),
        AppliedMember("production", PRODUCTION_B.patch, _digest(PATCH_B)),
    )


def test_already_replayed_tree_verifies_without_reapplying(fixture: dict[str, Path]) -> None:
    """The Python counterpart of `patched_source=already_verified`: the
    recorded series and the ledger digests both answer for a tree that is
    already replayed, so a second replay is unnecessary rather than tolerated."""
    apply_series(
        fixture["upstream"],
        fixture["target"],
        (PRODUCTION_A, PRODUCTION_B),
        fixture["patches"],
        patched_sources=fixture["ledger"],
    )
    verify_patched_sources(fixture["target"], read_patched_sources(fixture["ledger"]))
    assert len(read_series_marker(fixture["target"])) == 2


def test_stale_patch_refuses_on_the_context_it_reads(fixture: dict[str, Path]) -> None:
    """Applying the second member alone reads a line the first member writes,
    so the context comparison refuses rather than relocating the hunk."""
    with pytest.raises(SourceError) as refusal:
        apply_series(
            fixture["upstream"],
            fixture["target"],
            (PRODUCTION_B,),
            fixture["patches"],
            patched_sources=fixture["ledger"],
        )
    message = str(refusal.value)
    assert "alpha.txt" in message
    assert "'THREE'" in message
    assert "'three'" in message


def test_digest_mismatch_carries_the_shell_refusal(fixture: dict[str, Path]) -> None:
    """`verify_source` in remote/verify-llama-patch-series.sh prints exactly
    this sentence, so a reader of either authority meets one message."""
    wrong = "0" * 64
    fixture["ledger"].write_text(f"# path\tsha256\nalpha.txt\t{wrong}\n", encoding="utf-8")
    with pytest.raises(SourceError) as refusal:
        apply_series(
            fixture["upstream"],
            fixture["target"],
            (PRODUCTION_A, PRODUCTION_B),
            fixture["patches"],
            patched_sources=fixture["ledger"],
        )
    assert str(refusal.value) == (
        f"source replay mismatch: alpha.txt expected {wrong} found {_digest(ALPHA_AFTER_B)}"
    )


def test_candidate_ahead_of_production_refuses(fixture: dict[str, Path]) -> None:
    with pytest.raises(SourceError, match="follows a candidate member"):
        apply_series(
            fixture["upstream"],
            fixture["target"],
            (CANDIDATE_C, PRODUCTION_A),
            fixture["patches"],
            patched_sources=fixture["ledger"],
        )


def test_candidate_applies_after_every_production_member(fixture: dict[str, Path]) -> None:
    fixture["ledger"].write_text(
        "# path\tsha256\n"
        f"alpha.txt\t{_digest(ALPHA_AFTER_B)}\n"
        f"beta.txt\t{_digest(BETA_AFTER_CANDIDATE)}\n",
        encoding="utf-8",
    )
    result = apply_series(
        fixture["upstream"],
        fixture["target"],
        (PRODUCTION_A, PRODUCTION_B, CANDIDATE_C),
        fixture["patches"],
        patched_sources=fixture["ledger"],
    )
    assert (fixture["target"] / "beta.txt").read_bytes() == BETA_AFTER_CANDIDATE
    assert result.members[-1].stage == "candidate"


def test_existing_target_refuses(fixture: dict[str, Path]) -> None:
    """`prepare-llama-vulkan-source.sh` refuses a tree carrying an unrelated
    edit through `git status --porcelain`. This module materializes the target
    itself, so an existing path is the case that refusal covers: every byte
    under a target it wrote came from the upstream tree or from a member."""
    fixture["target"].mkdir()
    with pytest.raises(SourceError, match="already exists"):
        apply_series(
            fixture["upstream"],
            fixture["target"],
            (PRODUCTION_A,),
            fixture["patches"],
            patched_sources=fixture["ledger"],
        )


def test_prefix_then_remainder_equals_the_whole_series(fixture: dict[str, Path]) -> None:
    """The property the four-, five-, and seven-patch arms of
    `prepare-llama-vulkan-source.sh` rest on: a tree carrying a production
    prefix reaches the series result through the members that follow it."""
    whole = fixture["target"]
    apply_series(
        fixture["upstream"],
        whole,
        (PRODUCTION_A, PRODUCTION_B),
        fixture["patches"],
        patched_sources=fixture["ledger"],
    )
    staged = whole.parent / "staged"
    shutil.copytree(fixture["upstream"], staged)
    apply_patch(staged, fixture["patches"] / PRODUCTION_A.patch)
    apply_patch(staged, fixture["patches"] / PRODUCTION_B.patch)
    assert (staged / "alpha.txt").read_bytes() == (whole / "alpha.txt").read_bytes()
    assert (staged / "beta.txt").read_bytes() == (whole / "beta.txt").read_bytes()


def test_creating_an_existing_file_refuses(fixture: dict[str, Path]) -> None:
    staged = fixture["target"]
    shutil.copytree(fixture["upstream"], staged)
    (staged / "beta.txt").write_bytes(b"already here\n")
    with pytest.raises(SourceError, match="already exists"):
        apply_patch(staged, fixture["patches"] / PRODUCTION_A.patch)


def test_patch_application_is_all_or_nothing(fixture: dict[str, Path]) -> None:
    """Patch A rewrites alpha.txt and creates beta.txt. A beta.txt already in
    place refuses the second file diff, and alpha.txt keeps its upstream bytes
    because every file's content is computed before the first write."""
    staged = fixture["target"]
    shutil.copytree(fixture["upstream"], staged)
    (staged / "beta.txt").write_bytes(b"already here\n")
    with pytest.raises(SourceError):
        apply_patch(staged, fixture["patches"] / PRODUCTION_A.patch)
    assert (staged / "alpha.txt").read_bytes() == ALPHA_BASE


def test_new_file_mode_reaches_the_written_file(fixture: dict[str, Path]) -> None:
    staged = fixture["target"]
    shutil.copytree(fixture["upstream"], staged)
    apply_patch(staged, fixture["patches"] / PRODUCTION_A.patch)
    assert (staged / "beta.txt").stat().st_mode & 0o777 == 0o644


def test_hunk_relocates_to_the_position_its_context_names(fixture: dict[str, Path]) -> None:
    """`git apply` relocates a hunk whose header counts lines against another
    tree and reports nothing; this applier relocates the same way and returns
    the displacement, so the accommodation is visible."""
    staged = fixture["target"]
    shutil.copytree(fixture["upstream"], staged)
    (fixture["patches"] / "synthetic-offset.patch").write_bytes(PATCH_OFFSET)
    rewritten = apply_patch(staged, fixture["patches"] / "synthetic-offset.patch")
    assert rewritten == (AppliedFile(path="alpha.txt", offsets=(2,)),)
    assert (staged / "alpha.txt").read_bytes() == b"one\ntwo\nthree\nfour\nFOUR AND A HALF\nfive\n"


def test_hunk_matching_nowhere_refuses(fixture: dict[str, Path]) -> None:
    staged = fixture["target"]
    shutil.copytree(fixture["upstream"], staged)
    (fixture["patches"] / "synthetic-unmatched.patch").write_bytes(PATCH_UNMATCHED)
    with pytest.raises(SourceError, match="matches nowhere in the file"):
        apply_patch(staged, fixture["patches"] / "synthetic-unmatched.patch")


def test_unsupported_header_refuses() -> None:
    renamed = b"""\
diff --git a/alpha.txt b/gamma.txt
similarity index 100%
rename from alpha.txt
rename to gamma.txt
"""
    with pytest.raises(SourceError, match="unsupported header"):
        parse_patch(renamed)


def test_missing_newline_marker_refuses() -> None:
    truncated = b"""\
--- a/alpha.txt
+++ b/alpha.txt
@@ -1,1 +1,1 @@
-one
+ONE
\\ No newline at end of file
"""
    with pytest.raises(SourceError, match="trailing newline"):
        parse_patch(truncated)


def test_synthetic_series_digest_is_the_shell_formula(fixture: dict[str, Path]) -> None:
    expected = hashlib.sha256((_digest(PATCH_A) + _digest(PATCH_B)).encode("ascii")).hexdigest()
    assert series_digest((PRODUCTION_A, PRODUCTION_B), fixture["patches"]) == expected


def test_series_digest_refuses_a_candidate(fixture: dict[str, Path]) -> None:
    with pytest.raises(SourceError, match="production members alone"):
        series_digest((PRODUCTION_A, CANDIDATE_C), fixture["patches"])


def test_malformed_patched_sources_row_refuses(tmp_path: Path) -> None:
    ledger = tmp_path / "rows.tsv"
    ledger.write_text("# path\tsha256\nalpha.txt\n", encoding="utf-8")
    with pytest.raises(SourceError, match="malformed patched sources row"):
        read_patched_sources(ledger)


def test_absent_file_reads_as_the_empty_digest(tmp_path: Path) -> None:
    """`sha256sum PATH | cut -d ' ' -f 1` captures nothing for an absent path
    and exits zero through `cut`, so the comparison fails on an empty value."""
    assert sha256_file(tmp_path / "absent") == ""


def _archive(tmp_path: Path, commit: str) -> Path:
    root = tmp_path / "staging" / f"llama.cpp-{commit}"
    root.mkdir(parents=True)
    (root / "alpha.txt").write_bytes(ALPHA_BASE)
    archive = tmp_path / "archive.tar.gz"
    with tarfile.open(archive, "w:gz") as handle:
        handle.add(root, arcname=root.name)
    return archive


def _paths(tmp_path: Path) -> RuntimePaths:
    tree = tmp_path / "tree"
    (tree / "remote").mkdir(parents=True)
    return RuntimePaths(tree=tree, root=tmp_path / "root")


def test_acquire_upstream_extracts_an_archive(tmp_path: Path) -> None:
    paths = _paths(tmp_path)
    archive = _archive(tmp_path, PINNED_COMMIT)
    tree = acquire_upstream(paths, PINNED_COMMIT, archive_url=str(archive))
    assert tree == paths["qwen_home_llama_upstream"]
    assert (tree / "alpha.txt").read_bytes() == ALPHA_BASE
    assert (tree / SOURCE_COMMIT_MARKER).read_text(encoding="utf-8") == f"{PINNED_COMMIT}\n"


def test_acquire_upstream_accepts_a_recorded_commit(tmp_path: Path) -> None:
    paths = _paths(tmp_path)
    archive = _archive(tmp_path, PINNED_COMMIT)
    acquire_upstream(paths, PINNED_COMMIT, archive_url=str(archive))
    assert acquire_upstream(paths, PINNED_COMMIT) == paths["qwen_home_llama_upstream"]


def test_acquire_upstream_refuses_another_commit(tmp_path: Path) -> None:
    paths = _paths(tmp_path)
    archive = _archive(tmp_path, PINNED_COMMIT)
    acquire_upstream(paths, PINNED_COMMIT, archive_url=str(archive))
    with pytest.raises(SourceError, match="records commit"):
        acquire_upstream(paths, "0" * 40)


def test_acquire_upstream_refuses_an_unidentified_tree(tmp_path: Path) -> None:
    paths = _paths(tmp_path)
    tree = paths["qwen_home_llama_upstream"]
    tree.mkdir(parents=True)
    with pytest.raises(SourceError, match="neither a git object store"):
        acquire_upstream(paths, PINNED_COMMIT)


def test_acquire_upstream_refuses_an_unsupported_scheme(tmp_path: Path) -> None:
    paths = _paths(tmp_path)
    with pytest.raises(SourceError, match="unsupported scheme"):
        acquire_upstream(paths, PINNED_COMMIT, archive_url="ftp://example.invalid/x.tar.gz")


def _fake_clone(tree: Path, commit: str, *, packed: bool) -> None:
    git = tree / ".git"
    git.mkdir(parents=True)
    (git / "HEAD").write_text("ref: refs/heads/master\n", encoding="utf-8")
    if packed:
        (git / "packed-refs").write_text(
            f"# pack-refs with: peeled fully-peeled sorted\n{commit} refs/heads/master\n",
            encoding="utf-8",
        )
    else:
        loose = git / "refs" / "heads"
        loose.mkdir(parents=True)
        (loose / "master").write_text(f"{commit}\n", encoding="utf-8")


@pytest.mark.parametrize("packed", [True, False])
def test_git_head_reads_loose_and_packed_refs(tmp_path: Path, packed: bool) -> None:
    """`git clone` packs its refs, so the loose file is absent on exactly the
    trees `prepare-llama-vulkan-source.sh` creates."""
    tree = tmp_path / "clone"
    tree.mkdir()
    _fake_clone(tree, PINNED_COMMIT, packed=packed)
    assert read_git_head(tree) == PINNED_COMMIT


def test_acquire_upstream_accepts_a_clone_at_the_pinned_commit(tmp_path: Path) -> None:
    paths = _paths(tmp_path)
    tree = paths["qwen_home_llama_upstream"]
    tree.mkdir(parents=True)
    _fake_clone(tree, PINNED_COMMIT, packed=True)
    assert acquire_upstream(paths, PINNED_COMMIT) == tree


def test_acquire_upstream_refuses_a_clone_at_another_commit(tmp_path: Path) -> None:
    paths = _paths(tmp_path)
    tree = paths["qwen_home_llama_upstream"]
    tree.mkdir(parents=True)
    _fake_clone(tree, "1" * 40, packed=True)
    with pytest.raises(SourceError, match="names commit"):
        acquire_upstream(paths, PINNED_COMMIT)


def _script_command(text: str, opening: str) -> list[str]:
    """One backslash-continued command from a shell script, as shell words."""
    lines = text.splitlines()
    start = next((number for number, line in enumerate(lines) if line.startswith(opening)), None)
    if start is None:
        raise AssertionError(f"the script names no command opening with {opening!r}")
    collected: list[str] = []
    cursor = start
    continued = True
    while continued and cursor < len(lines):
        current = lines[cursor]
        continued = current.endswith("\\")
        collected.append(current[:-1] if continued else current)
        cursor += 1
    return shlex.split(" ".join(collected))


def _substitute(words: list[str], bindings: dict[str, str]) -> list[str]:
    return [bindings.get(word, word) for word in words]


def test_configure_argv_matches_the_build_script() -> None:
    """remote/build-llama-vulkan.sh holds the flags; an edit there fails here
    rather than leaving the Python control plane configuring a different tree."""
    text = BUILD_SCRIPT.read_text(encoding="utf-8")
    expected = _substitute(
        _script_command(text, "cmake -S "),
        {"$source_directory": "/src", "$build_directory": "/build"},
    )
    assert list(build_module.configure_argv("/src", "/build", build_module.VULKAN_DEFINES)) == (
        expected
    )


def test_build_argv_matches_the_build_script() -> None:
    text = BUILD_SCRIPT.read_text(encoding="utf-8")
    expected = _substitute(
        _script_command(text, "cmake --build "),
        {"$build_directory": "/build", "$build_jobs": "2"},
    )
    assert list(build_module.build_argv("/build", build_module.VULKAN_TARGETS, 2)) == expected


def test_required_commands_match_the_build_script() -> None:
    text = BUILD_SCRIPT.read_text(encoding="utf-8")
    line = next(line for line in text.splitlines() if line.startswith("for required_command in "))
    names = shlex.split(line[len("for required_command in ") :].removesuffix("; do"))
    assert list(build_module.REQUIRED_COMMANDS) == names


def test_toolchain_missing_names_every_absent_tool() -> None:
    with pytest.raises(build_module.ToolchainMissing) as refusal:
        build_module.require_toolchain(("qwen-absent-one", "qwen-absent-two"))
    message = str(refusal.value)
    assert "qwen-absent-one, qwen-absent-two" in message
    assert "prebuilt deployment bundle needs none of them" in message


def test_build_refuses_a_nonpositive_job_count() -> None:
    with pytest.raises(ValueError, match="must be positive"):
        build_module.configure_and_build("/src", "/build", {}, (), jobs=0)


def test_build_constants_agree_with_the_native_recipe() -> None:
    """`config/native-builds.toml` declares the same flags for the same script.
    Both statements derive from remote/build-llama-vulkan.sh, so comparing them
    here keeps two readers of one authority from drifting apart."""
    recipe_path = REPOSITORY / "config" / "native-builds.toml"
    if not recipe_path.is_file():
        pytest.skip("config/native-builds.toml is absent from this checkout")
    recipe = tomllib.loads(recipe_path.read_text(encoding="utf-8"))["llama"]
    assert recipe["generator"] == build_module.GENERATOR
    assert recipe["targets"] == list(build_module.VULKAN_TARGETS)
    assert recipe["required_commands"] == list(build_module.REQUIRED_COMMANDS)
    assert recipe["cmake_defines"] == build_module.VULKAN_DEFINES
    assert recipe["upstream_commit"] == PINNED_COMMIT


def _upstream_checkout() -> Path | None:
    """The base source the shell harness reads: `QWEN_LLAMA_BASE_SOURCE`, then
    the runtime root's own `opt/llama.cpp-upstream`."""
    declared = os.environ.get("QWEN_LLAMA_BASE_SOURCE")
    tree = Path(declared) if declared else RuntimePaths.resolve()["qwen_home_llama_upstream"]
    if not (tree / ".git").is_dir() or shutil.which("git") is None:
        return None
    probe = subprocess.run(
        ["git", "-C", str(tree), "cat-file", "-e", f"{PINNED_COMMIT}^{{commit}}"],
        capture_output=True,
        check=False,
    )
    return tree if probe.returncode == 0 else None


def _production_members() -> tuple[PatchSeriesMember, ...]:
    return tuple(row for row in load_patch_series() if row.stage == "production")


def _pinned_inputs(members: tuple[PatchSeriesMember, ...]) -> tuple[str, ...]:
    """Every path the production series reads at the pinned commit: the `a/`
    side of each file diff, with the three headers the series creates absent."""
    paths: list[str] = []
    for member in members:
        for file_patch in parse_patch((PATCHES / member.patch).read_bytes()):
            if file_patch.old_path and file_patch.old_path not in paths:
                paths.append(file_patch.old_path)
    return tuple(paths)


def test_real_series_reaches_the_ledger_digests(tmp_path: Path) -> None:
    """Apply the actual production series to the pinned versions of the files
    it reads and compare every digest against remote/llama-patched-sources.tsv."""
    upstream_checkout = _upstream_checkout()
    if upstream_checkout is None:
        pytest.skip(f"no checkout holding {PINNED_COMMIT}; set QWEN_LLAMA_BASE_SOURCE to one")
    members = _production_members()
    inputs = _pinned_inputs(members)
    upstream = tmp_path / "upstream"
    for relative in inputs:
        blob = subprocess.run(
            ["git", "-C", str(upstream_checkout), "show", f"{PINNED_COMMIT}:{relative}"],
            capture_output=True,
            check=True,
        ).stdout
        destination = upstream / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(blob)

    result = apply_series(upstream, tmp_path / "patched", members, PATCHES)
    rows = read_patched_sources()
    # The ledger pins ten paths and the replay rewrites exactly those ten,
    # which is the property `prepare-llama-vulkan-source.sh` reads out of `git
    # status --porcelain`: a digest comparison alone leaves a file the series
    # touched and the ledger omits unmeasured.
    assert set(result.rewritten) == {path for path, _ in rows}
    assert set(inputs) <= set(result.rewritten)
    for relative, expected in rows:
        assert sha256_file(result.target / relative) == expected
    assert [member.patch for member in result.members] == [row.patch for row in members]
    # Two members count their hunk headers against the pinned commit rather
    # than against the tree their predecessors leave, so these four hunks land
    # away from their stated lines. `git apply` relocates them without saying
    # so, which is how the shell replay reaches the same digests.
    vulkan = "ggml/src/ggml-vulkan/ggml-vulkan.cpp"
    assert result.relocations == (
        Relocation("llama-vulkan-duty-cycle.patch", vulkan, 4),
        Relocation("llama-vulkan-duty-cycle.patch", vulkan, 4),
        Relocation("llama-vulkan-duty-cycle.patch", vulkan, 4),
        Relocation("llama-vulkan-runtime-submit-limit.patch", vulkan, -1),
    )


def test_series_digest_matches_the_shell_replay(tmp_path: Path) -> None:
    """`remote/verify-llama-patch-series.sh` prints `patch_series_sha256`; the
    Python value is compared against that run rather than against a recorded
    constant, so a change to either authority is visible here."""
    upstream_checkout = _upstream_checkout()
    if upstream_checkout is None:
        pytest.skip(f"no checkout holding {PINNED_COMMIT}; set QWEN_LLAMA_BASE_SOURCE to one")
    for command in ("sh", "renice", "taskset", "ionice", "sha256sum"):
        if shutil.which(command) is None:
            pytest.skip(f"the replay script needs {command}")
    environment = dict(os.environ)
    environment["TMPDIR"] = str(tmp_path)
    completed = subprocess.run(
        ["sh", str(VERIFY_SCRIPT), str(upstream_checkout)],
        capture_output=True,
        check=True,
        env=environment,
        text=True,
    )
    field = "patch_series_sha256="
    printed = next(
        word[len(field) :]
        for line in completed.stdout.splitlines()
        for word in line.split()
        if word.startswith(field)
    )
    members = _production_members()
    assert series_digest(members, PATCHES) == printed
    assert f"members={len(members)}" in completed.stdout


def test_module_reports_the_pinned_commit_the_scripts_name() -> None:
    """Three shell scripts hardcode the commit; a Python value that drifts from
    them would acquire a tree every hunk offset counts lines against wrongly."""
    for script in ("prepare-llama-vulkan-source.sh", "verify-llama-patch-series.sh"):
        text = (REPOSITORY / "remote" / script).read_text(encoding="utf-8")
        assert f"expected_commit={PINNED_COMMIT}" in text
    assert source_module.PINNED_COMMIT == PINNED_COMMIT
