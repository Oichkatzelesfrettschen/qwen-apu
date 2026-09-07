#!/usr/bin/env python3
"""Classify every swept file the committed tree does not independently hold.

`evidence/home-directory-sweep-retention.tsv` joins each swept directory
against committed evidence by SHA-256 and reports 9 directories whose every
file digest is committed, 96 partly, 20 with none. A directory-level coverage
fraction orders where to look and decides nothing: the 96 partial rows carry
558 MiB whose disposition the fraction leaves open, because a directory is
covered file by file rather than in proportion.

This reader answers the file-level question. It reads the retained inventory
of the sweep -- one digest and one node row per file, both retained under
`evidence/home-sweep-recovery/sweep-inventory/` -- joins it against
`evidence/SHA256SUMS`, and emits one row per file the tree does not
independently hold, carrying the reason it misses.

Coverage is split at its source rather than summed. `refresh-evidence-manifest.sh`
enumerates through `git ls-files`, so `SHA256SUMS` now names the copies
retained under `evidence/home-sweep-recovery/`, and a swept file whose bytes
were copied there matches its own copy. Counting that as coverage states "this
was saved" where the question asked is "was this already saved": one is the
result of an act taken after the sweep and the other is what the sweep found.
`independent` names a digest committed at a path outside that directory and
`recovered` names one committed only inside it, so the two claims stay
separable and the retained copies never inflate the figure they were written
to raise.

A miss is not one finding. A file of zero bytes matches or misses without
reconstructing anything; a file whose bytes were sanitized on the way into the
tree misses by construction while its substance is retained, which the
`transformation.tsv` records make checkable by source digest; a file whose
digest repeats inside the sweep at a path that is covered loses nothing when
this copy goes. What remains after those three is the population that exists
in one place.

usage: classify-sweep-coverage.py [--tree-root DIRECTORY] [--check]
  --check   regenerate into memory and compare against the committed
            documents, exiting non-zero where either differs
"""

from __future__ import annotations

import argparse
import gzip
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

EMPTY_FILE_SHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

INVENTORY_DIRECTORY = Path("evidence/home-sweep-recovery/sweep-inventory")
RECOVERY_DIRECTORY = Path("evidence/home-sweep-recovery")
EVIDENCE_MANIFEST = Path("evidence/SHA256SUMS")
RETENTION_DOCUMENT = Path("evidence/home-directory-sweep-retention.tsv")
COVERAGE_DOCUMENT = Path("evidence/home-directory-sweep-coverage.tsv")
DIRECTORY_DOCUMENT = Path("evidence/home-directory-sweep-producers.tsv")

# Artifacts the appliance alone writes. The graphics-latency probe and the
# kernel-hazard watcher run inside the guarded launch chain against the Vulkan
# device, and the clock sidecar and the telemetry log read the amdgpu DPM
# attributes under /sys/class/drm; a workstation carries none of those nodes,
# so a directory holding one of these names holds bytes produced on the
# Raven2. It states that the directory contains such bytes rather than that
# every byte in it was produced there: a campaign directory also holds
# downloaded checkpoints and binaries a workstation container built.
DEVICE_PRODUCED_ARTIFACTS = (
    "clock-samples.tsv",
    "clock-sidecar.tsv",
    "gpu-clocks.tsv",
    "graphics-latency.log",
    "kernel-hazards.log",
    "pipeline-census.tsv",
    "telemetry.log",
)

# The sweep lives in one place, so storage is uniform and stated rather than
# derived. Storage and production are different claims: a copy taken to the
# workstation would move this column and leave producer_role untouched.
STORAGE_ROLE = "raven2-appliance"

DIRECTORY_HEADER = (
    "path",
    "files",
    "files_independently_covered",
    "files_recovered_only",
    "files_empty",
    "files_duplicate_within_sweep",
    "files_unretained",
    "unretained_distinct_bytes",
    "producer_role",
    "producer_evidence",
    "storage_role",
)

COVERAGE_HEADER = (
    "directory",
    "relative_path",
    "bytes",
    "sha256",
    "reason",
)


class ClassificationError(RuntimeError):
    """Report an input this reader cannot join."""


@dataclass
class DirectorySummary:
    """One swept directory's file population, split by what holds its bytes."""

    files: int = 0
    independent: int = 0
    recovered: int = 0
    empty: int = 0
    duplicate: int = 0
    unretained: int = 0
    # Digest to byte count, so a repeated digest contributes its bytes once.
    unretained_digests: dict[str, int] = field(default_factory=dict)


def read_inventory_digests(inventory_directory: Path) -> dict[str, str]:
    """Return relative path to SHA-256 for every file the sweep holds."""
    digests: dict[str, str] = {}
    with gzip.open(inventory_directory / "sha256.txt.gz", "rt") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            # `sha256sum` writes DIGEST, two spaces, then the path, and a path
            # carrying a backslash or a newline is escaped with a leading one.
            if line.startswith("\\"):
                raise ClassificationError(f"escaped path in the inventory: {line[:80]}")
            digest, separator, path = line.partition("  ")
            if not separator or len(digest) != 64:
                raise ClassificationError(f"unparsed inventory row: {line[:80]}")
            if path in digests:
                raise ClassificationError(f"repeated inventory path: {path}")
            digests[path] = digest
    return digests


def read_inventory_sizes(inventory_directory: Path) -> dict[str, int]:
    """Return relative path to byte count for every regular file."""
    sizes: dict[str, int] = {}
    with gzip.open(inventory_directory / "nodes.tsv.gz", "rt") as handle:
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 3:
                continue
            node_type, byte_count, path = fields
            if node_type != "f":
                continue
            sizes[path] = int(byte_count)
    return sizes


def read_evidence_digests(manifest_path: Path) -> tuple[set[str], set[str]]:
    """Return the digests committed outside and only inside the recovery tree.

    A digest reaching both sets belongs to the first: one independent copy is
    what the question asks about, and a second copy under the recovery tree
    adds nothing to it.
    """
    independent: set[str] = set()
    recovered: set[str] = set()
    # `refresh-evidence-manifest.sh` enumerates through `git ls-files`, so a
    # manifest path is repository-relative and the recovery tree is named from
    # the repository root. A prefix taken relative to `evidence/` matches
    # nothing here and silently counts every retained copy as independent,
    # which is the inflation this split exists to prevent.
    recovery_prefix = str(RECOVERY_DIRECTORY) + "/"
    with manifest_path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            digest, separator, path = line.partition("  ")
            if not separator or len(digest) != 64:
                raise ClassificationError(f"unparsed manifest row: {line[:80]}")
            if path.startswith(recovery_prefix):
                recovered.add(digest)
            else:
                independent.add(digest)
    return independent, recovered - independent


def read_sanitized_sources(recovery_directory: Path) -> set[str]:
    """Return the source digests the retained copies were sanitized from.

    A substitution changes the bytes, so the retained copy carries a digest of
    its own and the source misses every join by construction. The
    transformation record is what makes the source's retention checkable.
    """
    sources: set[str] = set()
    for record in sorted(recovery_directory.glob("*/transformation.tsv")):
        with record.open(encoding="utf-8") as handle:
            header = handle.readline().rstrip("\n").split("\t")
            try:
                source_column = header.index("source_sha256")
            except ValueError as error:
                raise ClassificationError(f"{record} names no source_sha256") from error
            for line in handle:
                fields = line.rstrip("\n").split("\t")
                if len(fields) <= source_column:
                    continue
                sources.add(fields[source_column])
    return sources


def read_retention_classes(document_path: Path) -> dict[str, str]:
    """Return the retention class the directory-level join recorded."""
    classes: dict[str, str] = {}
    with document_path.open(encoding="utf-8") as handle:
        header = handle.readline().rstrip("\n").split("\t")
        path_column = header.index("path")
        class_column = header.index("retention_class")
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            if len(fields) <= class_column:
                continue
            classes[fields[path_column]] = fields[class_column]
    return classes


def directory_of(relative_path: str) -> str:
    """Return the swept directory a path belongs to.

    The manifest names directories two components deep (`campaigns/NAME`), and
    a file directly under the sweep root belongs to no campaign directory.
    """
    parts = relative_path.split("/")
    if len(parts) < 3:
        return "/".join(parts[:-1]) if len(parts) > 1 else "."
    return "/".join(parts[:2])


def read_directory_basenames(inventory_directory: Path) -> dict[str, set[str]]:
    """Return the set of file basenames each swept directory holds."""
    basenames: dict[str, set[str]] = defaultdict(set)
    with gzip.open(inventory_directory / "nodes.tsv.gz", "rt") as handle:
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 3 or fields[0] != "f":
                continue
            path = fields[2]
            basenames[directory_of(path)].add(path.split("/")[-1])
    return dict(basenames)


def classify(
    tree_root: Path,
) -> tuple[list[tuple[str, ...]], list[tuple[str, ...]], dict[str, int]]:
    """Return the file rows, the directory rows, and the summary counts."""
    inventory = tree_root / INVENTORY_DIRECTORY
    digests = read_inventory_digests(inventory)
    sizes = read_inventory_sizes(inventory)
    independent, recovered = read_evidence_digests(tree_root / EVIDENCE_MANIFEST)
    sanitized_sources = read_sanitized_sources(tree_root / RECOVERY_DIRECTORY)
    retention_classes = read_retention_classes(tree_root / RETENTION_DOCUMENT)

    # A digest repeating inside the sweep is one population of bytes. Where any
    # copy of it is independently held, removing another copy loses nothing.
    occurrences: dict[str, int] = defaultdict(int)
    for digest in digests.values():
        occurrences[digest] += 1

    partial_directories = {
        path
        for path, retention in retention_classes.items()
        if retention == "retained-partial"
    }

    rows: list[tuple[str, ...]] = []
    counts: dict[str, int] = defaultdict(int)
    # Bytes are counted once per distinct digest. A file population and a byte
    # population are two figures, and summing the sizes of duplicate copies
    # states a loss larger than the bytes that exist.
    unretained_digests: dict[str, int] = {}
    for relative_path in sorted(digests):
        directory = directory_of(relative_path)
        if directory not in partial_directories:
            continue
        digest = digests[relative_path]
        byte_count = sizes.get(relative_path, 0)
        # An empty file is read before coverage rather than after it. Its
        # digest is committed somewhere in any tree that holds one empty file,
        # so a coverage test passes it while it reconstructs nothing, and
        # counting it as covered is what makes a fraction read better than the
        # population it describes.
        if digest == EMPTY_FILE_SHA256 or byte_count == 0:
            reason = "empty"
        elif digest in independent:
            counts["independent"] += 1
            continue
        elif digest in sanitized_sources:
            reason = "retained-sanitized"
        elif digest in recovered:
            reason = "retained-verbatim"
        elif occurrences[digest] > 1:
            # Another copy of these bytes sits inside the sweep, so this copy
            # alone is redundant. The population is unretained all the same:
            # every copy goes when the sweep goes.
            reason = "duplicate-within-sweep"
        else:
            reason = "unretained"
        if reason in ("unretained", "duplicate-within-sweep"):
            unretained_digests[digest] = byte_count
        counts[reason] += 1
        rows.append((directory, relative_path, str(byte_count), digest, reason))
    counts["unretained_distinct_digests"] = len(unretained_digests)
    counts["unretained_distinct_bytes"] = sum(unretained_digests.values())
    counts["partial_directories"] = len(partial_directories)

    # The per-directory summary covers every swept directory rather than the
    # partial ones alone, since a whole and an unmatched directory are the two
    # ends the partial rows sit between and a reader comparing them needs all
    # three present.
    basenames = read_directory_basenames(inventory)
    per_directory: dict[str, DirectorySummary] = defaultdict(DirectorySummary)
    for relative_path, digest in digests.items():
        summary = per_directory[directory_of(relative_path)]
        summary.files += 1
        byte_count = sizes.get(relative_path, 0)
        if digest == EMPTY_FILE_SHA256 or byte_count == 0:
            summary.empty += 1
            continue
        if digest in independent:
            summary.independent += 1
            continue
        if digest in sanitized_sources or digest in recovered:
            summary.recovered += 1
            continue
        if occurrences[digest] > 1:
            summary.duplicate += 1
        else:
            summary.unretained += 1
        summary.unretained_digests[digest] = byte_count

    directory_rows: list[tuple[str, ...]] = []
    for directory in sorted(per_directory):
        summary = per_directory[directory]
        markers = sorted(
            basenames.get(directory, set()) & set(DEVICE_PRODUCED_ARTIFACTS)
        )
        producer_role = "raven2-appliance" if markers else "unknown"
        producer_evidence = ",".join(markers) if markers else "-"
        directory_rows.append(
            (
                directory,
                str(summary.files),
                str(summary.independent),
                str(summary.recovered),
                str(summary.empty),
                str(summary.duplicate),
                str(summary.unretained),
                str(sum(summary.unretained_digests.values())),
                producer_role,
                producer_evidence,
                STORAGE_ROLE,
            )
        )
    counts["device_attributed_directories"] = sum(
        1 for row in directory_rows if row[8] == "raven2-appliance"
    )
    counts["directories"] = len(directory_rows)
    return rows, directory_rows, dict(counts)


def render(header: tuple[str, ...], rows: list[tuple[str, ...]]) -> str:
    """Return a document one rename publishes."""
    lines = ["\t".join(header)]
    lines.extend("\t".join(row) for row in rows)
    return "\n".join(lines) + "\n"


def publish(document: Path, rendered: str) -> None:
    """Write through a staging name so a reader sees one whole document."""
    staging = document.with_name(document.name + ".staging")
    staging.write_text(rendered, encoding="utf-8")
    staging.replace(document)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tree-root", type=Path, default=None)
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()

    tree_root = arguments.tree_root
    if tree_root is None:
        tree_root = Path(__file__).resolve().parent.parent

    try:
        rows, directory_rows, counts = classify(tree_root)
    except (ClassificationError, OSError, ValueError) as error:
        print(f"classify-sweep-coverage: {error}", file=sys.stderr)
        return 2

    documents = (
        (
            tree_root / COVERAGE_DOCUMENT,
            COVERAGE_DOCUMENT,
            render(COVERAGE_HEADER, rows),
        ),
        (
            tree_root / DIRECTORY_DOCUMENT,
            DIRECTORY_DOCUMENT,
            render(DIRECTORY_HEADER, directory_rows),
        ),
    )

    if arguments.check:
        for path, name, rendered in documents:
            if not path.is_file():
                print(f"absent document: {path}", file=sys.stderr)
                return 1
            if path.read_text(encoding="utf-8") != rendered:
                print(
                    f"{name} differs from what this reader derives; "
                    "run remote/classify-sweep-coverage.py",
                    file=sys.stderr,
                )
                return 1
        print(
            f"sweep_coverage=current rows={len(rows)} directories={len(directory_rows)}"
        )
        return 0

    for path, _, rendered in documents:
        publish(path, rendered)

    print(
        "sweep_coverage=written "
        f"partial_directories={counts.get('partial_directories', 0)} "
        f"independent={counts.get('independent', 0)} "
        f"rows={len(rows)}"
    )
    for reason in (
        "unretained",
        "duplicate-within-sweep",
        "retained-verbatim",
        "retained-sanitized",
        "empty",
    ):
        print(f"reason={reason} files={counts.get(reason, 0)}")
    print(
        f"unretained_distinct_digests={counts.get('unretained_distinct_digests', 0)} "
        f"unretained_distinct_bytes={counts.get('unretained_distinct_bytes', 0)}"
    )
    print(
        f"directories={counts.get('directories', 0)} "
        f"device_attributed={counts.get('device_attributed_directories', 0)} "
        f"producer_unknown={counts.get('directories', 0) - counts.get('device_attributed_directories', 0)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
