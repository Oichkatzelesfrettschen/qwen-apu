"""The reproducible source path: acquire the pinned llama.cpp tree, replay the
patch series onto it in ledger order, and pin the result by digest.

`remote/prepare-llama-vulkan-source.sh` and `remote/verify-llama-patch-series.sh`
hold the shell authority and both reach the tree through git: a local clone, a
detached checkout at the pinned commit, `git apply`, and `git status
--porcelain` for the no-unrelated-change invariant. This module reaches the
same result over an archive and a pure-Python unified-diff applier, so the
optional source path needs git for neither acquisition nor replay.

Three properties differ from the shell and each is a deliberate narrowing.
`apply_series` materializes its target from the upstream tree and refuses a
target that already exists, which proves the stronger statement the shell's
porcelain comparison approximates: every byte under the target came from the
upstream tree or from a series member. The four-, five-, and seven-patch
prefix arms in `prepare-llama-vulkan-source.sh` upgrade trees a predecessor
revision prepared without a marker, and a tree this module creates carries
`.qwen-patch-series` instead, so those arms have no counterpart here.
`acquire_upstream` accepts an existing git clone only where its own HEAD is
the pinned commit, where the shell clones and detaches to that commit from
whatever HEAD the base source carries.

Four hunks of the production series carry headers counted against the pinned
commit rather than against the tree their predecessors leave, so `git apply`
relocates them and reaches the pinned digests anyway. `apply_hunks` searches
the same way and returns each hunk's displacement, which
`SeriesApplication.relocations` carries, so the replay reproduces the shell's
result while naming what the shell relocates silently.

The replay digest and the refusal text come from the shell verbatim:
`series_digest` reproduces `patch_series_sha256` byte for byte, and a digest
mismatch carries `verify_source`'s own `source replay mismatch` sentence.
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import tarfile
import tempfile
import urllib.parse
import urllib.request
from collections.abc import Iterable, Iterator, Sequence
from dataclasses import dataclass
from pathlib import Path

from qwen_apu.config.loader import default_ledger_path
from qwen_apu.config.schema import PatchSeriesMember
from qwen_apu.runtime.paths import RuntimePaths

# The commit remote/prepare-llama-vulkan-source.sh, verify-llama-patch-series.sh,
# and build-llama-vulkan.sh all pin. Every hunk offset in patches/ counts lines
# in this commit's files, so a different commit is a different series.
PINNED_COMMIT = "f280b26983ad0fdb705a0d9ebf0503e76f2899b0"

ARCHIVE_URL_TEMPLATE = "https://github.com/ggml-org/llama.cpp/archive/{commit}.tar.gz"

# The acquired tree records the commit it holds; the replayed tree records the
# ordered series it received. Both sit at the tree root beside the sources.
SOURCE_COMMIT_MARKER = ".qwen-source-commit"
PATCH_SERIES_MARKER = ".qwen-patch-series"

ARCHIVE_TIMEOUT_SECONDS = 120

_HUNK_HEADER = re.compile(rb"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")

# Extended git headers a member of this series may carry. `new file mode`
# creates a file and the rest describe the blobs; a header outside this set
# names a transformation the applier below implements nothing for.
_KNOWN_GIT_HEADERS = (b"index ", b"new file mode ", b"deleted file mode ")
_REFUSED_GIT_HEADERS = (
    b"old mode ",
    b"new mode ",
    b"rename from ",
    b"rename to ",
    b"copy from ",
    b"copy to ",
    b"similarity index ",
    b"dissimilarity index ",
    b"GIT binary patch",
    b"Binary files ",
)


class SourceError(RuntimeError):
    """An acquisition, a replay, or a digest comparison that refuses."""


@dataclass(frozen=True, slots=True)
class Hunk:
    """One `@@` block: the old and new line ranges and the body lines with
    their leading markers kept, so application reads the marker directly."""

    old_start: int
    old_count: int
    new_start: int
    new_count: int
    lines: tuple[bytes, ...]


@dataclass(frozen=True, slots=True)
class FilePatch:
    """One file's diff. `old_path` is None where the diff creates the file and
    `new_path` is None where it deletes one, the two `/dev/null` forms."""

    old_path: str | None
    new_path: str | None
    mode: int | None
    hunks: tuple[Hunk, ...]

    @property
    def path(self) -> str:
        return self.new_path or self.old_path or ""


@dataclass(frozen=True, slots=True)
class AppliedMember:
    """One series member as the replay recorded it: its stage, its file name,
    and the sha256 of the patch file that was applied."""

    stage: str
    patch: str
    sha256: str


@dataclass(frozen=True, slots=True)
class AppliedFile:
    """One file a member rewrote, and each of its hunks' displacement from the
    line that hunk's own header states."""

    path: str
    offsets: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class Relocation:
    """One hunk that landed away from its stated line. `git apply` performs the
    same relocation without reporting it; recording it here keeps a hunk header
    counted against the wrong predecessor visible to a reader."""

    patch: str
    path: str
    offset: int


@dataclass(frozen=True, slots=True)
class SeriesApplication:
    """The replay's result: the tree it wrote, the members it applied in order,
    the paths those members rewrote, the ledger paths whose digests it
    verified, and every relocated hunk.

    `rewritten` and `verified` state two halves of one claim: the digests prove
    every pinned path is correct and the rewritten set proves the replay
    touched nothing else, which is what `prepare-llama-vulkan-source.sh` reads
    out of `git status --porcelain`."""

    target: Path
    members: tuple[AppliedMember, ...]
    rewritten: tuple[str, ...]
    verified: tuple[tuple[str, str], ...]
    relocations: tuple[Relocation, ...]


def sha256_file(path: Path) -> str:
    """The digest `sha256sum PATH | cut -d ' ' -f 1` prints.

    An absent path reads as the empty string, which is what the shell's own
    pipeline captures: `sha256sum` fails and writes nothing to the pipe while
    `cut` exits zero, so the comparison that follows fails on an empty value
    rather than aborting the script.
    """
    if not path.is_file():
        return ""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def read_patched_sources(path: Path | None = None) -> tuple[tuple[str, str], ...]:
    """remote/llama-patched-sources.tsv as ordered (path, sha256) rows.

    The ledger states its columns in a comment line rather than a header row,
    so `qwen_apu.config.loader.read_ledger` finds no header to validate and
    this reader takes the two-column, `#`-commented shape the ledger's own
    `awk` readers in verify-llama-patch-series.sh assume.
    """
    resolved = Path(path) if path is not None else default_ledger_path("llama-patched-sources")
    rows: list[tuple[str, str]] = []
    for number, raw in enumerate(resolved.read_text(encoding="utf-8").splitlines(), start=1):
        if not raw or raw.startswith("#"):
            continue
        fields = raw.split("\t")
        if len(fields) != 2 or not fields[0] or not fields[1]:
            raise SourceError(f"malformed patched sources row: {resolved}:{number}: {raw}")
        rows.append((fields[0], fields[1]))
    if not rows:
        raise SourceError(f"patched sources ledger names no member: {resolved}")
    return tuple(rows)


def series_digest(members: Sequence[PatchSeriesMember], patches_dir: Path) -> str:
    """The `patch_series_sha256` verify-llama-patch-series.sh prints.

    The shell concatenates each production member's own sha256 hex string in
    ledger order and takes the sha256 of that concatenation, which makes a
    reordering and a substitution equally visible. Every member must carry the
    production stage, since the candidate stage has its own
    `candidate_series_sha256` computed the same way over its own names.
    """
    identity = ""
    for member in members:
        if member.stage != "production":
            raise SourceError(
                f"series digest takes production members alone: "
                f"{member.patch} carries stage {member.stage}"
            )
        digest = sha256_file(Path(patches_dir) / member.patch)
        if not digest:
            raise SourceError(f"patch series member is unreadable: {patches_dir}/{member.patch}")
        identity += digest
    if not identity:
        raise SourceError("patch series names no production member")
    return hashlib.sha256(identity.encode("ascii")).hexdigest()


def _git_directory(tree: Path) -> Path:
    """The object store for a checkout: `.git` as a directory, or the path a
    `.git` file names for a linked worktree."""
    git = tree / ".git"
    if git.is_dir():
        return git
    if git.is_file():
        text = git.read_text(encoding="utf-8").strip()
        marker = "gitdir:"
        if not text.startswith(marker):
            raise SourceError(f"{git} names no gitdir")
        named = Path(text[len(marker) :].strip())
        return named if named.is_absolute() else (tree / named).resolve()
    raise SourceError(f"{tree} holds no git object store")


def read_git_head(tree: Path) -> str:
    """The commit a checkout's HEAD names, read from the ref files alone.

    A clone resolves HEAD through a symbolic ref, and the ref it names lives
    either as a loose file under the object store or as a row of
    `packed-refs`; `git clone` packs its refs, so the loose file is absent on
    exactly the trees this path reads most.
    """
    git = _git_directory(tree)
    try:
        head = (git / "HEAD").read_text(encoding="utf-8").strip()
    except OSError as error:
        raise SourceError(f"{tree} holds an unreadable HEAD: {error}") from error
    symbolic = "ref: "
    if not head.startswith(symbolic):
        return head
    ref = head[len(symbolic) :].strip()
    loose = git / ref
    if loose.is_file():
        return loose.read_text(encoding="utf-8").strip()
    packed = git / "packed-refs"
    if packed.is_file():
        for line in packed.read_text(encoding="utf-8").splitlines():
            if not line or line.startswith(("#", "^")):
                continue
            fields = line.split(" ", 1)
            if len(fields) == 2 and fields[1].strip() == ref:
                return fields[0]
    raise SourceError(f"{tree} resolves HEAD to {ref}, which names no commit")


def _fetch_archive(source: str, destination: Path) -> None:
    """Write the archive named by `source` to `destination`.

    An https URL reaches the network and any other form reads a local file,
    which is how a test supplies its own archive without a network.
    """
    parsed = urllib.parse.urlparse(source)
    if parsed.scheme == "https":
        # The scheme is proven https one line above, which is the audit S310
        # asks for; urlopen reaches no other protocol handler from here.
        with (
            urllib.request.urlopen(  # noqa: S310
                source, timeout=ARCHIVE_TIMEOUT_SECONDS
            ) as response,
            destination.open("wb") as handle,
        ):
            shutil.copyfileobj(response, handle)
        return
    if parsed.scheme in ("", "file"):
        local = Path(urllib.request.url2pathname(parsed.path)) if parsed.scheme else Path(source)
        shutil.copyfile(local, destination)
        return
    raise SourceError(f"archive source names an unsupported scheme: {source}")


def _extract_archive(archive: Path, tree: Path) -> None:
    """Extract a single-rooted tarball into `tree` through a staging directory.

    The `data` filter refuses an absolute member path, a path escaping the
    destination, a device node, and a symlink leaving the tree, so an archive
    this function extracts writes under the staging directory alone. The
    GitHub archive carries one top-level `llama.cpp-<commit>/` directory, and
    `os.replace` moves that inner directory into place, so the tree holds the
    sources rather than a directory holding them.
    """
    tree.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(dir=tree.parent, prefix=".source-staging-"))
    try:
        with tarfile.open(archive, "r:gz") as handle:
            handle.extractall(staging, filter="data")
        entries = sorted(staging.iterdir())
        roots = [entry for entry in entries if entry.is_dir()]
        if len(entries) != 1 or len(roots) != 1:
            names = ", ".join(entry.name for entry in entries)
            raise SourceError(f"archive holds no single top-level directory: {names}")
        os.replace(roots[0], tree)
    finally:
        shutil.rmtree(staging, ignore_errors=True)


def acquire_upstream(paths: RuntimePaths, commit: str, *, archive_url: str | None = None) -> Path:
    """The pinned llama.cpp tree at `<opt>/llama.cpp-upstream`, acquired or accepted.

    A tree already at that path is accepted on identity: a git clone through
    its own HEAD, and an archive extraction through the `.qwen-source-commit`
    this function writes. Either one naming a commit other than `commit`
    refuses rather than being replaced, since the tree is the input every
    later digest is computed against.

    An absent tree comes from the GitHub archive of the commit, which needs no
    git on the appliance. `archive_url` overrides the URL and accepts a local
    file path, so a test supplies its own tarball.
    """
    tree = paths["qwen_home_llama_upstream"]
    if tree.exists():
        if (tree / ".git").exists():
            head = read_git_head(tree)
            if head != commit:
                raise SourceError(f"upstream clone names commit {head}, expected {commit}: {tree}")
            return tree
        marker = tree / SOURCE_COMMIT_MARKER
        if not marker.is_file():
            raise SourceError(
                f"upstream tree carries neither a git object store nor "
                f"{SOURCE_COMMIT_MARKER}: {tree}"
            )
        recorded = marker.read_text(encoding="utf-8").strip()
        if recorded != commit:
            raise SourceError(f"upstream tree records commit {recorded}, expected {commit}: {tree}")
        return tree

    source = archive_url or ARCHIVE_URL_TEMPLATE.format(commit=commit)
    download = Path(tempfile.mkdtemp(prefix="qwen-upstream-archive-"))
    try:
        archive = download / f"{commit}.tar.gz"
        _fetch_archive(source, archive)
        _extract_archive(archive, tree)
    finally:
        shutil.rmtree(download, ignore_errors=True)
    (tree / SOURCE_COMMIT_MARKER).write_text(f"{commit}\n", encoding="utf-8")
    return tree


def _split_lines(data: bytes) -> list[bytes]:
    """A file's lines without their terminators. Every source this series
    rewrites ends with a newline, and `_join_lines` restores that terminator;
    a patch carrying `\\ No newline at end of file` refuses at parse time, so
    no caller reaches this function with content that ends otherwise."""
    if not data:
        return []
    lines = data.split(b"\n")
    if lines and lines[-1] == b"":
        lines.pop()
    return lines


def _join_lines(lines: Sequence[bytes]) -> bytes:
    if not lines:
        return b""
    return b"\n".join(lines) + b"\n"


def _diff_path(field: bytes) -> str | None:
    """The repository-relative path a `---` or `+++` field names, or None for
    `/dev/null`. A `git diff` field carries an `a/` or `b/` prefix and a
    quoted field names a path with bytes outside the printable set, which this
    series holds none of."""
    text = field.decode("utf-8").strip()
    if text.startswith('"'):
        raise SourceError(f"quoted diff path is unsupported: {text}")
    if text == "/dev/null":
        return None
    if text.startswith(("a/", "b/")):
        return text[2:]
    return text


def parse_patch(data: bytes) -> tuple[FilePatch, ...]:
    """Every file diff a patch file carries, in file order.

    A member of this series opens with free prose stating the mechanism, so
    the parser recognizes a diff by its own shape -- a `---` line, a `+++`
    line, and a `@@` header in sequence -- and treats every other line as
    prose. Extended git headers are read only between a `diff --git` line and
    the `---` line that follows it, which keeps a prose sentence that happens
    to open with a header word from being read as one.
    """
    lines = data.split(b"\n")
    patches: list[FilePatch] = []
    index = 0
    in_git_header = False
    mode: int | None = None
    while index < len(lines):
        line = lines[index]
        if line.startswith(b"diff --git "):
            in_git_header = True
            mode = None
            index += 1
            continue
        if in_git_header:
            for refused in _REFUSED_GIT_HEADERS:
                if line.startswith(refused):
                    raise SourceError(
                        f"patch carries an unsupported header: {line.decode('utf-8', 'replace')}"
                    )
            if line.startswith(b"new file mode "):
                mode = int(line[len(b"new file mode ") :].strip(), 8)
                index += 1
                continue
            if any(line.startswith(known) for known in _KNOWN_GIT_HEADERS):
                index += 1
                continue
        if line.startswith(b"\\ No newline at end of file"):
            raise SourceError("patch carries a file without a trailing newline")
        starts_diff = (
            line.startswith(b"--- ")
            and index + 2 < len(lines)
            and lines[index + 1].startswith(b"+++ ")
            and lines[index + 2].startswith(b"@@ ")
        )
        if not starts_diff:
            # A line inside a `diff --git` block that names no known header
            # ends the block, so the prose of the next member is read as prose.
            in_git_header = False
            index += 1
            continue
        old_path = _diff_path(line[len(b"--- ") :])
        new_path = _diff_path(lines[index + 1][len(b"+++ ") :])
        index += 2
        hunks, index = _parse_hunks(lines, index)
        patches.append(FilePatch(old_path=old_path, new_path=new_path, mode=mode, hunks=hunks))
        in_git_header = False
        mode = None
    if not patches:
        raise SourceError("patch carries no file diff")
    return tuple(patches)


def _parse_hunks(lines: Sequence[bytes], index: int) -> tuple[tuple[Hunk, ...], int]:
    """Every hunk from `index` until a line that belongs to no hunk body."""
    hunks: list[Hunk] = []
    while index < len(lines):
        match = _HUNK_HEADER.match(lines[index])
        if match is None:
            break
        old_start = int(match.group(1))
        old_count = int(match.group(2)) if match.group(2) is not None else 1
        new_start = int(match.group(3))
        new_count = int(match.group(4)) if match.group(4) is not None else 1
        index += 1
        body: list[bytes] = []
        seen_old = 0
        seen_new = 0
        while index < len(lines) and (seen_old < old_count or seen_new < new_count):
            entry = lines[index]
            if entry.startswith(b"\\ No newline at end of file"):
                raise SourceError("patch carries a file without a trailing newline")
            marker = entry[:1]
            if marker in (b" ", b""):
                seen_old += 1
                seen_new += 1
            elif marker == b"-":
                seen_old += 1
            elif marker == b"+":
                seen_new += 1
            else:
                raise SourceError(
                    f"hunk body carries an unrecognized marker: {entry.decode('utf-8', 'replace')}"
                )
            body.append(entry)
            index += 1
        if seen_old != old_count or seen_new != new_count:
            raise SourceError(
                f"hunk @@ -{old_start},{old_count} +{new_start},{new_count} @@ "
                f"carries {seen_old} old and {seen_new} new lines"
            )
        hunks.append(
            Hunk(
                old_start=old_start,
                old_count=old_count,
                new_start=new_start,
                new_count=new_count,
                lines=tuple(body),
            )
        )
    if not hunks:
        raise SourceError("file diff carries no hunk")
    return tuple(hunks), index


def _hunk_old_lines(hunk: Hunk) -> tuple[bytes, ...]:
    """The lines a hunk reads: its context and its removals, in file order."""
    return tuple(entry[1:] for entry in hunk.lines if entry[:1] in (b" ", b"", b"-"))


def _search_positions(origin: int, lowest: int, highest: int) -> Iterator[int]:
    """The stated position, then one line forward, one back, two forward, two
    back: the order `find_pos` in git's apply.c walks its own image."""
    if lowest <= origin <= highest:
        yield origin
    for delta in range(1, max(highest - lowest, origin - lowest, highest - origin) + 1):
        for candidate in (origin + delta, origin - delta):
            if lowest <= candidate <= highest:
                yield candidate


def _mismatch_detail(original: Sequence[bytes], old: Sequence[bytes], probe: int) -> str:
    """The first line at `probe` where the hunk and the file disagree, which is
    what a reader needs to tell a stale patch from a relocated one."""
    for index, expected in enumerate(old):
        position = probe + index
        if position >= len(original):
            return f"line {position + 1} is past the file's {len(original)} lines"
        if original[position] != expected:
            return (
                f"line {position + 1} reads "
                f"{original[position].decode('utf-8', 'replace')!r} where the hunk "
                f"reads {expected.decode('utf-8', 'replace')!r}"
            )
    return "every line agrees"


def apply_hunks(
    original: Sequence[bytes], hunks: Sequence[Hunk], path: str
) -> tuple[list[bytes], tuple[int, ...]]:
    """Apply every hunk with zero fuzz, returning the new lines and each hunk's
    displacement from the line its own header states.

    Two members of the production series carry hunk headers counted against
    the pinned commit rather than against the tree their predecessors leave,
    so four hunks land at a nonzero displacement -- three at +4 in
    llama-vulkan-duty-cycle.patch and one at -1 in
    llama-vulkan-runtime-submit-limit.patch. `git apply` relocates those hunks
    silently, which is how the shell replay reaches the digests
    remote/llama-patched-sources.tsv pins, so this applier searches the same
    way `find_pos` does and returns the displacements rather than hiding them.
    Fuzz stays zero throughout: every context and removal line matches the file
    exactly at the position the search accepts, and a hunk whose lines match
    nowhere refuses.
    """
    result: list[bytes] = []
    cursor = 0
    carried = 0
    offsets: list[int] = []
    for hunk in hunks:
        # A hunk that removes nothing states the line it inserts after, so its
        # own `old_start` is already the zero-based insertion point.
        start = hunk.old_start if hunk.old_count == 0 else hunk.old_start - 1
        old = _hunk_old_lines(hunk)
        highest = len(original) - len(old)
        if highest < cursor:
            raise SourceError(
                f"{path}: hunk at line {hunk.old_start} reads {len(old)} lines past "
                f"the file's {len(original)}"
            )
        # The running displacement moves the search origin, so a hunk that
        # follows a relocated one searches from where its text actually sits.
        origin = min(max(start + carried, cursor), highest)
        if not old:
            position = origin
        else:
            position = _locate(
                original, old, origin, lowest=cursor, highest=highest, hunk=hunk, path=path
            )
        offsets.append(position - start)
        carried = position - start
        result.extend(original[cursor:position])
        cursor = position
        for entry in hunk.lines:
            marker, text = entry[:1], entry[1:]
            if marker == b"-":
                cursor += 1
            elif marker == b"+":
                result.append(text)
            else:
                result.append(text)
                cursor += 1
    result.extend(original[cursor:])
    return result, tuple(offsets)


def _locate(
    original: Sequence[bytes],
    old: Sequence[bytes],
    origin: int,
    *,
    lowest: int,
    highest: int,
    hunk: Hunk,
    path: str,
) -> int:
    for candidate in _search_positions(origin, lowest, highest):
        if list(original[candidate : candidate + len(old)]) == list(old):
            return candidate
    raise SourceError(
        f"{path}: hunk at line {hunk.old_start} matches nowhere in the file; at "
        f"its stated position {_mismatch_detail(original, old, origin)}"
    )


def apply_patch(tree: Path, patch_path: Path) -> tuple[AppliedFile, ...]:
    """Apply one patch file to `tree` and report each file it rewrote.

    Every file's new content is computed before the first byte is written, so
    a patch whose second file diff refuses leaves the tree as it found it --
    the property `git apply --check` followed by `git apply` gives the shell.
    """
    try:
        data = patch_path.read_bytes()
    except OSError as error:
        raise SourceError(f"patch file is unreadable: {patch_path}: {error}") from error
    pending: list[tuple[Path, bytes | None, int | None]] = []
    written: list[AppliedFile] = []
    for file_patch in parse_patch(data):
        relative = file_patch.path
        if file_patch.old_path and file_patch.new_path:
            if file_patch.old_path != file_patch.new_path:
                raise SourceError(
                    f"{patch_path.name}: diff renames {file_patch.old_path} to "
                    f"{file_patch.new_path}, which this applier implements nothing for"
                )
        target = tree / relative
        if file_patch.old_path is None:
            if target.exists():
                raise SourceError(f"{patch_path.name}: {relative} already exists")
            original: list[bytes] = []
        else:
            try:
                original = _split_lines(target.read_bytes())
            except OSError as error:
                raise SourceError(
                    f"{patch_path.name}: {relative} is unreadable: {error}"
                ) from error
        updated, offsets = apply_hunks(original, file_patch.hunks, f"{patch_path.name}: {relative}")
        content = None if file_patch.new_path is None else _join_lines(updated)
        pending.append((target, content, file_patch.mode))
        written.append(AppliedFile(path=relative, offsets=offsets))
    for target, content, mode in pending:
        if content is None:
            target.unlink()
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        if mode is not None:
            target.chmod(mode & 0o7777)
    return tuple(written)


def _ordered_members(members: Iterable[PatchSeriesMember]) -> tuple[PatchSeriesMember, ...]:
    """The members in the order the replay applies them, production first.

    remote/llama-patch-series.tsv states the invariant in its own header --
    a candidate member applies after every production member -- and
    `load_patch_series` refuses a ledger that violates it. This second check
    covers a caller that assembles a member sequence by hand.
    """
    ordered = tuple(members)
    seen_candidate = False
    for member in ordered:
        if member.stage == "candidate":
            seen_candidate = True
        elif member.stage == "production":
            if seen_candidate:
                raise SourceError(f"production member {member.patch} follows a candidate member")
        else:
            raise SourceError(f"series member {member.patch} carries stage {member.stage}")
    if not ordered:
        raise SourceError("patch series names no member")
    return ordered


def verify_patched_sources(tree: Path, rows: Sequence[tuple[str, str]]) -> None:
    """Compare every ledger row against the tree, refusing with
    `verify_source`'s own sentence from remote/verify-llama-patch-series.sh."""
    for relative, expected in rows:
        actual = sha256_file(tree / relative)
        if actual != expected:
            raise SourceError(
                f"source replay mismatch: {relative} expected {expected} found {actual}"
            )


def apply_series(
    upstream_tree: Path,
    target_tree: Path,
    members: Sequence[PatchSeriesMember],
    patches_dir: Path,
    *,
    patched_sources: Path | None = None,
) -> SeriesApplication:
    """Replay the series from `upstream_tree` into `target_tree` and pin the result.

    The target is materialized from the upstream tree and therefore refuses to
    overwrite an existing path: every byte under it comes from the upstream
    tree or from a member, which is the invariant
    `prepare-llama-vulkan-source.sh` states as `git status --porcelain`
    equalling the ledger's own porcelain shape. Production members apply
    before candidate members, and the ledger digests are verified over the
    whole tree afterwards, so a candidate that rewrites a production file is
    visible in the comparison rather than hidden by it.
    """
    ordered = _ordered_members(members)
    upstream = Path(upstream_tree)
    target = Path(target_tree)
    if not upstream.is_dir():
        raise SourceError(f"upstream source tree is missing: {upstream}")
    if target.exists():
        raise SourceError(f"patched source path already exists: {target}")
    rows = read_patched_sources(patched_sources)

    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(upstream, target, symlinks=True, ignore=shutil.ignore_patterns(".git"))
    applied: list[AppliedMember] = []
    rewritten: list[str] = []
    relocations: list[Relocation] = []
    for member in ordered:
        patch_path = Path(patches_dir) / member.patch
        digest = sha256_file(patch_path)
        if not digest:
            raise SourceError(f"patch series member is unreadable: {patch_path}")
        for changed in apply_patch(target, patch_path):
            if changed.path not in rewritten:
                rewritten.append(changed.path)
            relocations.extend(
                Relocation(patch=member.patch, path=changed.path, offset=offset)
                for offset in changed.offsets
                if offset != 0
            )
        applied.append(AppliedMember(stage=member.stage, patch=member.patch, sha256=digest))
    verify_patched_sources(target, rows)
    _write_series_marker(target, applied)
    return SeriesApplication(
        target=target,
        members=tuple(applied),
        rewritten=tuple(rewritten),
        verified=tuple(rows),
        relocations=tuple(relocations),
    )


def _write_series_marker(target: Path, applied: Sequence[AppliedMember]) -> None:
    """Record the ordered series the tree received, one row per member.

    The tree carries no git object store, so this file is what a later reader
    -- a build, a bundle, or a second replay -- identifies the tree by.
    """
    lines = ["# stage\tpatch\tsha256"]
    lines.extend(f"{member.stage}\t{member.patch}\t{member.sha256}" for member in applied)
    (target / PATCH_SERIES_MARKER).write_text("\n".join(lines) + "\n", encoding="utf-8")


def read_series_marker(target: Path) -> tuple[AppliedMember, ...]:
    """The ordered series a replayed tree records."""
    path = Path(target) / PATCH_SERIES_MARKER
    members: list[AppliedMember] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#"):
            continue
        fields = raw.split("\t")
        if len(fields) != 3:
            raise SourceError(f"malformed series marker row: {path}: {raw}")
        members.append(AppliedMember(stage=fields[0], patch=fields[1], sha256=fields[2]))
    return tuple(members)
