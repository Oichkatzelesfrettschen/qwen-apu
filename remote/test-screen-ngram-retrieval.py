#!/usr/bin/env python3
"""Focused fixtures for the bounded n-gram retrieval replay screen."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile

SCRIPT = pathlib.Path(__file__).with_name("screen-ngram-retrieval.py")
SPEC = importlib.util.spec_from_file_location("ngram_retrieval_screen", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def file_digest(path: pathlib.Path) -> str:
    """Return a fixture file digest."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_sequence(path: pathlib.Path, tokens: list[int]) -> None:
    """Write the response shape the retained corpus uses."""
    path.write_text(json.dumps({"tokens": tokens}) + "\n", encoding="utf-8")


future_tokens = (1, 2, 3, 4, 9, 1, 2, 3, 4, 8)
history = MODULE.HistoryIndex(future_tokens)
assert history.lookup(4) is None
candidate = history.lookup(9)
assert candidate is not None
assert candidate.source == "history"
assert candidate.key_size == 4
assert candidate.tokens == (9, 1, 2)

external = MODULE.ExternalIndex(
    (
        (1, 2, 3, 4, 7, 20),
        (1, 2, 3, 4, 6, 21),
    )
)
candidate = external.lookup((30, 1, 2, 3, 4))
assert candidate is not None
assert candidate.key_size == 4
assert candidate.tokens == (6, 21)

repeated = (1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 6)
rounds, _history = MODULE.simulate(repeated, "history", None)
assert sum(round_result.committed for round_result in rounds) == len(repeated)
assert len(rounds) < len(repeated)
assert any(round_result.accepted > 0 for round_result in rounds)

with tempfile.TemporaryDirectory() as temporary_name:
    root = pathlib.Path(temporary_name)
    source_a = root / "a.json"
    source_b = root / "b.json"
    source_c = root / "c.json"
    write_sequence(source_a, [1, 2, 3, 4, 5, 6, 7, 8, 9])
    write_sequence(source_b, [1, 2, 3, 4, 6, 7, 8, 9, 10])
    write_sequence(source_c, [1, 2, 3, 4, 7, 8, 9, 10, 11])
    target_cost_evidence = root / MODULE.TARGET_COST_EVIDENCE
    target_cost_evidence.parent.mkdir()
    target_cost_evidence.write_text("fixture target costs\n", encoding="utf-8")
    manifest = root / "manifest.tsv"
    manifest.write_text(
        "workload_id\tsource_path\tsource_sha256\tmodel_id\n"
        f"a\ta.json\t{file_digest(source_a)}\tmodel\n"
        f"b\tb.json\t{file_digest(source_b)}\tmodel\n"
        f"c\tc.json\t{file_digest(source_c)}\tmodel\n",
        encoding="utf-8",
    )
    output = root / "output"
    completed = subprocess.run(
        [
            "python3",
            str(SCRIPT),
            str(manifest),
            str(output),
            "--repository-root",
            str(root),
        ],
        text=True,
        capture_output=True,
        timeout=15,
        check=False,
    )
    assert completed.returncode == 0, completed.stderr
    result_lines = (output / "results.tsv").read_text(encoding="utf-8").splitlines()
    assert len(result_lines) == 10
    aggregate_lines = (
        (output / "aggregate.tsv").read_text(encoding="utf-8").splitlines()
    )
    assert len(aggregate_lines) == 4
    result_header = result_lines[0].split("\t")
    result_rows = [
        dict(zip(result_header, line.split("\t"), strict=True))
        for line in result_lines[1:]
    ]
    external_rows = [
        row for row in result_rows if row["configuration"] == "history_external"
    ]
    assert len(external_rows) == 3
    assert {row["corpus_sequences"] for row in external_rows} == {"2"}
    assert {row["replay_exact"] for row in result_rows} == {"yes"}
    assert all(float(row["projected_speedup"]) > 0 for row in result_rows)
    assert not (output / "tokens.tsv").exists()
    repeated_run = subprocess.run(
        [
            "python3",
            str(SCRIPT),
            str(manifest),
            str(output),
            "--repository-root",
            str(root),
        ],
        text=True,
        capture_output=True,
        timeout=15,
        check=False,
    )
    assert repeated_run.returncode == 2
    assert "output directory exists" in repeated_run.stderr

    malformed = root / "malformed.tsv"
    malformed.write_text(
        "workload_id\tsource_path\tsource_sha256\tmodel_id\n"
        f"same\ta.json\t{file_digest(source_a)}\tmodel\n"
        f"same\tb.json\t{file_digest(source_b)}\tmodel\n",
        encoding="utf-8",
    )
    try:
        MODULE.read_manifest(malformed, root)
    except ValueError as error:
        assert "invalid identity" in str(error)
    else:
        raise AssertionError("duplicate workload identity entered the screen")

    write_sequence(source_c, [1, 2, 3, 4, 5, 6, 7, 8, 9])
    duplicate_sequence = root / "duplicate-sequence.tsv"
    duplicate_sequence.write_text(
        "workload_id\tsource_path\tsource_sha256\tmodel_id\n"
        f"a\ta.json\t{file_digest(source_a)}\tmodel\n"
        f"b\tb.json\t{file_digest(source_b)}\tmodel\n"
        f"c\tc.json\t{file_digest(source_c)}\tmodel\n",
        encoding="utf-8",
    )
    try:
        MODULE.read_manifest(duplicate_sequence, root)
    except ValueError as error:
        assert "identical token sequence" in str(error)
    else:
        raise AssertionError(
            "held-out token sequence re-entered through another workload"
        )

print("test-screen-ngram-retrieval: 11 checks passed")
