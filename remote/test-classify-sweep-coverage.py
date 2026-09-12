#!/usr/bin/env python3
"""classify-sweep-coverage.py over a fixture tree with a known population.

The fixture builds an inventory whose every classification is decided by
construction: one file the tree independently holds, one held only under the
recovery directory, one whose sanitized source is recorded, one empty, one
duplicated inside the sweep, and one that exists nowhere else. A reader that
collapses any two of those reports a coverage figure the population does not
support, so each is asserted by reason rather than by count alone.
"""

from __future__ import annotations

import gzip
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "classify-sweep-coverage.py"
EMPTY = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

failures = 0


def report(name: str, outcome: str) -> None:
    global failures
    if outcome == "ok":
        print(f"ok {name}")
    else:
        print(f"FAIL {name}: {outcome}")
        failures += 1


def digest_of(marker: str) -> str:
    """Return a distinct 64-character hexadecimal digest for a fixture file."""
    return marker.rjust(64, "0")


def build_tree(root: Path) -> None:
    """Lay out an inventory, a manifest, and a retention document."""
    inventory = root / "evidence/home-sweep-recovery/sweep-inventory"
    inventory.mkdir(parents=True)

    # relative path, digest, byte count, and the class it must land in.
    population = [
        ("campaigns/partial/independent.log", digest_of("a1"), 100),
        ("campaigns/partial/recovered.log", digest_of("b2"), 200),
        ("campaigns/partial/sanitized.log", digest_of("c3"), 300),
        ("campaigns/partial/empty.log", EMPTY, 0),
        ("campaigns/partial/duplicate-one.log", digest_of("d4"), 400),
        ("campaigns/partial/duplicate-two.log", digest_of("d4"), 400),
        ("campaigns/partial/alone.log", digest_of("e5"), 500),
        ("campaigns/partial/clock-sidecar.tsv", digest_of("f6"), 600),
        ("campaigns/whole/held.log", digest_of("a1"), 100),
        ("campaigns/unmatched/gone.log", digest_of("99"), 900),
    ]

    with gzip.open(inventory / "sha256.txt.gz", "wt") as handle:
        for path, digest, _ in population:
            handle.write(f"{digest}  {path}\n")
    with gzip.open(inventory / "nodes.tsv.gz", "wt") as handle:
        for path, _, size in population:
            handle.write(f"f\t{size}\t{path}\n")

    # The manifest holds one independent copy, one copy only under the
    # recovery tree, and nothing for the rest.
    manifest = root / "evidence/SHA256SUMS"
    manifest.write_text(
        f"{digest_of('a1')}  evidence/campaign-report.md\n"
        f"{EMPTY}  evidence/placeholder\n"
        f"{digest_of('b2')}  evidence/home-sweep-recovery/partial/recovered.log\n",
        encoding="utf-8",
    )

    transformation = root / "evidence/home-sweep-recovery/partial"
    transformation.mkdir(parents=True, exist_ok=True)
    (transformation / "transformation.tsv").write_text(
        "relative_path\tsource_sha256\tretained_sha256\tsubstitutions\n"
        f"sanitized.log\t{digest_of('c3')}\t{digest_of('cc')}\t2\n",
        encoding="utf-8",
    )

    (root / "evidence/home-directory-sweep-retention.tsv").write_text(
        "path\tbytes\tfiles\tsource_class\tfiles_hashed\t"
        "files_digest_in_evidence\tdigest_coverage\tretention_class\n"
        "campaigns/partial\t2500\t8\tcampaign-output\t8\t1\t0.1250\tretained-partial\n"
        "campaigns/whole\t100\t1\tcampaign-output\t1\t1\t1.0000\tretained-whole\n"
        "campaigns/unmatched\t900\t1\tcampaign-output\t1\t0\t0.0000\tunmatched\n",
        encoding="utf-8",
    )

    # The receipt ledger states what wrote each record. It disagrees with the
    # artifact marker on the partial directory on purpose: a device artifact
    # says the directory holds Raven2-produced bytes and a workstation receipt
    # says that record was written elsewhere, and both claims survive.
    (root / "evidence/home-sweep-recovery/producer-receipts.tsv").write_text(
        "directory\treceipt_path\tevidence\tderived_role\n"
        "campaigns/partial\tcampaigns/partial/campaign-inputs.tsv\t"
        "workstation-host\tworkstation\n"
        "campaigns/whole\tcampaigns/whole/receipt.tsv\tRADV RAVEN2\t"
        "raven2-appliance\n"
        "campaigns/unmatched\tcampaigns/unmatched/receipt.tsv\t-\tunknown\n",
        encoding="utf-8",
    )


def run(root: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--tree-root", str(root), *arguments],
        capture_output=True,
        text=True,
        check=False,
    )


def read_rows(path: Path) -> list[list[str]]:
    lines = path.read_text(encoding="utf-8").rstrip("\n").split("\n")
    return [line.split("\t") for line in lines[1:]]


def main() -> int:
    with tempfile.TemporaryDirectory() as workspace:
        root = Path(workspace)
        build_tree(root)

        completed = run(root)
        if completed.returncode != 0:
            report("generator_runs", completed.stderr.strip() or "non-zero exit")
            return 1
        report("generator_runs", "ok")

        coverage = read_rows(root / "evidence/home-directory-sweep-coverage.tsv")
        by_path = {row[1]: row[4] for row in coverage}

        # Only the partial directory contributes file rows.
        directories = {row[0] for row in coverage}
        report(
            "file_rows_cover_the_partial_directory_alone",
            "ok" if directories == {"campaigns/partial"} else str(sorted(directories)),
        )

        expected = {
            "campaigns/partial/recovered.log": "retained-verbatim",
            "campaigns/partial/sanitized.log": "retained-sanitized",
            "campaigns/partial/empty.log": "empty",
            "campaigns/partial/duplicate-one.log": "duplicate-within-sweep",
            "campaigns/partial/duplicate-two.log": "duplicate-within-sweep",
            "campaigns/partial/alone.log": "unretained",
            "campaigns/partial/clock-sidecar.tsv": "unretained",
        }
        for path, reason in expected.items():
            report(
                f"reason_{reason.replace('-', '_')}_{Path(path).stem.replace('-', '_')}",
                "ok" if by_path.get(path) == reason else f"read {by_path.get(path)}",
            )

        # A file the tree independently holds carries no row at all.
        report(
            "independently_held_file_carries_no_row",
            "ok" if "campaigns/partial/independent.log" not in by_path else "row emitted",
        )

        # The recovery copy must not read as independent coverage. This is the
        # inflation the split exists to prevent, and the manifest path is
        # repository-relative, so a prefix taken relative to evidence/ silently
        # counts every retained copy as pre-existing.
        report(
            "recovery_copy_is_not_independent_coverage",
            "ok"
            if by_path.get("campaigns/partial/recovered.log") == "retained-verbatim"
            else f"read {by_path.get('campaigns/partial/recovered.log')}",
        )

        # An empty file's digest is committed in any tree holding one empty
        # file, so coverage passes it while it reconstructs nothing.
        report(
            "empty_file_reads_empty_rather_than_covered",
            "ok" if by_path.get("campaigns/partial/empty.log") == "empty" else "read as covered",
        )

        producers = read_rows(root / "evidence/home-directory-sweep-producers.tsv")
        rows = {row[0]: row for row in producers}
        report(
            "producer_document_covers_every_directory",
            "ok"
            if set(rows) == {"campaigns/partial", "campaigns/whole", "campaigns/unmatched"}
            else str(sorted(rows)),
        )
        partial = rows["campaigns/partial"]
        report(
            "disagreeing_sources_read_mixed_and_name_both",
            "ok"
            if partial[8] == "mixed"
            and partial[9]
            == "artifact:clock-sidecar.tsv" + ",receipt:campaigns/partial/campaign-inputs.tsv"
            else f"{partial[8]} / {partial[9]}",
        )
        report(
            "receipt_attributes_a_directory_carrying_no_artifact",
            "ok"
            if rows["campaigns/whole"][8] == "raven2-appliance"
            and rows["campaigns/whole"][9] == "receipt:campaigns/whole/receipt.tsv"
            else str(rows["campaigns/whole"][8:10]),
        )
        report(
            "a_silent_receipt_attributes_nothing",
            "ok"
            if rows["campaigns/unmatched"][8] == "unknown" and rows["campaigns/unmatched"][9] == "-"
            else str(rows["campaigns/unmatched"][8:10]),
        )
        report(
            "storage_role_is_stated_not_derived",
            "ok" if all(row[10] == "raven2-appliance" for row in producers) else "varies",
        )
        # Bytes count once per distinct digest: the duplicated pair is 400
        # bytes of population rather than 800, beside 500 and 600 alone.
        report(
            "unretained_bytes_count_each_digest_once",
            "ok" if partial[7] == "1500" else f"read {partial[7]}",
        )

        # A second run over unchanged inputs agrees with the published pair.
        check = run(root, "--check")
        report(
            "check_passes_on_current_documents",
            "ok" if check.returncode == 0 else check.stderr.strip(),
        )

        (root / "evidence/home-directory-sweep-coverage.tsv").write_text(
            "directory\trelative_path\tbytes\tsha256\treason\n", encoding="utf-8"
        )
        stale = run(root, "--check")
        report(
            "check_refuses_a_stale_document",
            "ok" if stale.returncode == 1 else f"exit {stale.returncode}",
        )

        # A receipt row attributing a directory it was not read inside would
        # infer production from location, which is the reading this ledger
        # replaces rather than extends.
        foreign = root / "foreign-receipts.tsv"
        foreign.write_text(
            "directory\treceipt_path\tevidence\tderived_role\n"
            "campaigns/whole\tcampaigns/partial/receipt.tsv\tRADV RAVEN2\t"
            "raven2-appliance\n",
            encoding="utf-8",
        )
        refused = run(root, "--producer-receipts", str(foreign))
        report(
            "refuses_a_receipt_outside_its_directory",
            "ok" if refused.returncode == 2 else f"exit {refused.returncode}",
        )

    if failures:
        print(f"test-classify-sweep-coverage: {failures} check(s) failed", file=sys.stderr)
        return 1
    print("test-classify-sweep-coverage: all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
