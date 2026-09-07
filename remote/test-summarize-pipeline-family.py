#!/usr/bin/env python3
"""Fixture proof for `summarize-pipeline-family.py`.

Every case writes one ledger in the shape `summarize-kernel-census.py` emits,
runs the reader over it as a subprocess, and asserts the exit status and the
rows. The fixtures state the refusal paths a retained record cannot reach --
an inconclusive verdict, cross-pipeline overlap past the threshold, a missing
or repeated `graphs` row, and an unknown value format -- beside the accepted
shape whose family arithmetic is checked against sums computed here.
"""

from __future__ import annotations

import pathlib
import subprocess
import sys
import tempfile
from typing import Dict, List, Sequence, Tuple

READER = pathlib.Path(__file__).resolve().parent / "summarize-pipeline-family.py"

PIPELINE_HEADER = [
    "pipeline",
    "id",
    "name",
    "constants",
    "wg_denoms",
    "subgroup",
    "calls_per_graph",
    "workgroups_per_graph",
    "total_bracket_upper_bound_ms",
    "pipeline_bracket_union_ms",
    "exclusive_bracket_ms",
    "ambiguous_overlap_ms",
    "median_us",
    "p90_us",
    "p99_us",
    "max_us",
    "vgprs",
    "sgprs",
    "spilled_vgprs",
    "lds",
    "scratch",
    "subgroups_per_simd",
    "spirv_executed_sha256",
]

# name, calls, workgroups, bracket upper bound, pipeline union, exclusive,
# ambiguous, vgprs
PIPELINES: Tuple[Tuple[str, float, float, float, float, float, str, str], ...] = (
    ("mul_mat_vec_q4_k_f32_f32", 162.0, 121232.0, 300.0, 298.0, 290.0, "10.0", "64"),
    ("mul_mat_vec_q6_k_f32_f32", 25.0, 83840.0, 200.0, 200.0, 198.0, "2.0", "64"),
    ("get_rows_q6_k_f32", 1.0, 2.0, 1.0, 1.0, 1.0, "0.0", "20"),
    ("set_rows_f32_q4_0_i64", 6.0, 6.0, 2.0, 2.0, 1.0, "1.0", "24"),
    ("flash_attn_f32_f16_aligned", 6.0, 24.0, 20.0, 20.0, 20.0, "0.0", "64"),
    ("get_rows_f32_f32", 37.0, 9868.0, 40.0, 40.0, 38.0, "2.0", "4"),
)


def build_ledger(
    *,
    ownership: str = "conclusive",
    cross: float = 0.0070,
    threshold: float = 0.05,
    graph_rows: int = 1,
    extra: Sequence[Tuple[str, float, float, float, float, float, str, str]] = (),
) -> str:
    lines = ["\t".join(PIPELINE_HEADER)]
    for entry in tuple(PIPELINES) + tuple(extra):
        name, calls, workgroups, upper, union, exclusive, ambiguous, vgprs = entry
        lines.append(
            "\t".join(
                str(v)
                for v in [
                    "pipeline",
                    1,
                    name,
                    "64,4,1",
                    "4,1,1",
                    64,
                    f"{calls:.3f}",
                    f"{workgroups:.1f}",
                    f"{upper:.3f}",
                    f"{union:.3f}",
                    f"{exclusive:.3f}",
                    ambiguous,
                    "1.0",
                    "1.0",
                    "1.0",
                    "1.0",
                    vgprs,
                    48,
                    0,
                    "0",
                    0,
                    4,
                    "0" * 64,
                ]
            )
        )
    graphs_row = "\t".join(
        [
            "graphs",
            "decode",
            "63",
            "raw_bracket_sum_ms_per_graph=10.000",
            "bracket_union_ms_per_graph=9.900",
            f"cross_pipeline_overlap_fraction={cross:.4f}",
            f"overlap_threshold={threshold:.4f}",
            f"ownership={ownership}",
        ]
    )
    lines.extend([graphs_row] * graph_rows)
    return "\n".join(lines) + "\n"


def run(
    directory: pathlib.Path, text: str, *flags: str
) -> "subprocess.CompletedProcess[str]":
    path = directory / "ledger.tsv"
    path.write_text(text, encoding="utf-8")
    return subprocess.run(
        [sys.executable, str(READER), str(path), *flags],
        capture_output=True,
        text=True,
        check=False,
    )


def families(stdout: str) -> Dict[str, List[str]]:
    rows: Dict[str, List[str]] = {}
    for line in stdout.splitlines():
        row = line.split("\t")
        if row[0] == "family" and row[1] != "value_format":
            rows[row[1]] = row
    return rows


def case_accepted(directory: pathlib.Path) -> None:
    result = run(directory, build_ledger())
    assert result.returncode == 0, result.stderr
    rows = families(result.stdout)
    assert set(rows) == {"Q4_K", "Q6_K", "Q4_0", "F16", "other"}, sorted(rows)
    # Q6_K merges the mat-vec and the embedding gather: 200.0 + 1.0 upper,
    # 198.0 + 1.0 exclusive, against a denominator of 10.000 * 63.
    assert rows["Q6_K"][2] == "2", rows["Q6_K"]
    assert rows["Q6_K"][4] == "201.000", rows["Q6_K"]
    assert rows["Q6_K"][5] == "199.000", rows["Q6_K"]
    assert rows["Q6_K"][7] == f"{201.0 / 630.0:.4f}", rows["Q6_K"]
    assert rows["Q6_K"][8] == f"{199.0 / 630.0:.4f}", rows["Q6_K"]
    # A quantized token beats a float token in the same name, and `q4_0` is
    # its own family rather than Q4_K.
    assert rows["Q4_K"][2] == "1", rows["Q4_K"]
    assert rows["Q4_0"][2] == "1", rows["Q4_0"]
    assert rows["F16"][2] == "1", rows["F16"]
    # `other` enumerates its members rather than swallowing them.
    members = [
        line.split("\t")
        for line in result.stdout.splitlines()
        if line.startswith("member\tother\t")
    ]
    assert [m[2] for m in members] == ["get_rows_f32_f32"], members
    print("case=accepted verdict=accepted")


def case_prefix(directory: pathlib.Path) -> None:
    result = run(directory, build_ledger(), "--family-prefix", "mul_mat_vec")
    assert result.returncode == 0, result.stderr
    rows = families(result.stdout)
    assert set(rows) == {"Q4_K", "Q6_K"}, sorted(rows)
    assert rows["Q6_K"][4] == "200.000", rows["Q6_K"]
    arm = [
        row
        for row in (line.split("\t") for line in result.stdout.splitlines())
        if row[0] == "arm" and row[1] != "ledger"
    ][0]
    assert "family_prefix=mul_mat_vec" in arm, arm
    assert "pipelines_selected=2" in arm, arm
    assert "pipelines_total=6" in arm, arm
    print("case=prefix verdict=accepted")


def case_inconclusive(directory: pathlib.Path) -> None:
    result = run(directory, build_ledger(ownership="inconclusive"))
    assert result.returncode == 1, result.stdout
    assert "ownership=inconclusive" in result.stderr, result.stderr
    print("case=inconclusive verdict=accepted")


def case_cross_overlap(directory: pathlib.Path) -> None:
    result = run(directory, build_ledger(cross=0.0800))
    assert result.returncode == 1, result.stdout
    assert "blocks family ownership" in result.stderr, result.stderr
    print("case=cross-overlap verdict=accepted")


def case_graph_row_cardinality(directory: pathlib.Path) -> None:
    for count in (0, 2):
        result = run(directory, build_ledger(graph_rows=count))
        assert result.returncode == 1, result.stdout
        assert f"carries {count} graphs rows" in result.stderr, result.stderr
    print("case=graph-row-cardinality verdict=accepted")


def case_unknown_format(directory: pathlib.Path) -> None:
    extra = (("mul_mat_vec_iq4_nl_f32_f32", 4.0, 8.0, 5.0, 5.0, 5.0, "0.0", "64"),)
    result = run(directory, build_ledger(extra=extra))
    assert result.returncode == 0, result.stderr
    rows = families(result.stdout)
    # `iq4_nl` carries no `q<digits>` token, so it reads `other` and appears
    # by name rather than being counted into a K-quant family.
    assert "IQ4_NL" not in rows, sorted(rows)
    members = [
        line.split("\t")
        for line in result.stdout.splitlines()
        if line.startswith("member\tother\t")
    ]
    assert "mul_mat_vec_iq4_nl_f32_f32" in [m[2] for m in members], members
    print("case=unknown-format verdict=accepted")


def case_empty_ledger(directory: pathlib.Path) -> None:
    result = run(directory, "")
    assert result.returncode == 1, result.stdout
    assert "no pipeline header row" in result.stderr, result.stderr
    print("case=empty-ledger verdict=accepted")


def case_numeric_refusals(directory: pathlib.Path) -> None:
    original = build_ledger()
    mutations = 0
    for field, accepted in (
        ("raw_bracket_sum_ms_per_graph", "10.000"),
        ("bracket_union_ms_per_graph", "9.900"),
        ("cross_pipeline_overlap_fraction", "0.0070"),
        ("overlap_threshold", "0.0500"),
    ):
        for invalid in ("nan", "inf", "-inf", "-1", "true"):
            result = run(
                directory, original.replace(f"{field}={accepted}", f"{field}={invalid}")
            )
            assert result.returncode == 1, (field, invalid, result.stdout)
            mutations += 1
    for invalid in ("0", "01", "1.5", "true", "9999999999"):
        result = run(
            directory,
            original.replace("graphs\tdecode\t63", f"graphs\tdecode\t{invalid}"),
        )
        assert result.returncode == 1, (invalid, result.stdout)
        mutations += 1
    for column in (
        "calls_per_graph",
        "workgroups_per_graph",
        "total_bracket_upper_bound_ms",
        "pipeline_bracket_union_ms",
        "exclusive_bracket_ms",
        "ambiguous_overlap_ms",
        "vgprs",
        "lds",
        "subgroups_per_simd",
        "p99_us",
    ):
        for invalid in ("nan", "inf", "-1", "true"):
            rows = [line.split("\t") for line in original.splitlines()]
            rows[1][PIPELINE_HEADER.index(column)] = invalid
            result = run(directory, "\n".join("\t".join(row) for row in rows) + "\n")
            assert result.returncode == 1, (column, invalid, result.stdout)
            mutations += 1
    for before, after in (
        ("overlap_threshold=0.0500", "overlap_threshold=1.01"),
        (
            "cross_pipeline_overlap_fraction=0.0070",
            "cross_pipeline_overlap_fraction=1.01",
        ),
        ("raw_bracket_sum_ms_per_graph=10.000", "raw_bracket_sum_ms_per_graph=0"),
        ("bracket_union_ms_per_graph=9.900", "bracket_union_ms_per_graph=11"),
        ("raw_bracket_sum_ms_per_graph=10.000", "raw_bracket_sum_ms_per_graph=1e308"),
        ("\t298.000\t290.000\t", "\t301.000\t290.000\t"),
        ("\t298.000\t290.000\t", "\t298.000\t299.000\t"),
    ):
        assert before in original
        result = run(directory, original.replace(before, after))
        assert result.returncode == 1, (after, result.stdout)
        mutations += 1
    for column in (
        "vgprs",
        "sgprs",
        "spilled_vgprs",
        "lds",
        "scratch",
        "subgroups_per_simd",
    ):
        for invalid in ("1.5", "01", "1000000000"):
            rows = [line.split("\t") for line in original.splitlines()]
            rows[1][PIPELINE_HEADER.index(column)] = invalid
            result = run(directory, "\n".join("\t".join(row) for row in rows) + "\n")
            assert result.returncode == 1, (column, invalid, result.stdout)
            mutations += 1
    print(f"case=numeric-refusals mutations={mutations} verdict=accepted")


def main() -> int:
    with tempfile.TemporaryDirectory() as name:
        directory = pathlib.Path(name)
        case_accepted(directory)
        case_prefix(directory)
        case_inconclusive(directory)
        case_cross_overlap(directory)
        case_graph_row_cardinality(directory)
        case_unknown_format(directory)
        case_empty_ledger(directory)
        case_numeric_refusals(directory)
    print("summarize_pipeline_family=accepted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
