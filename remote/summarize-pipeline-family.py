#!/usr/bin/env python3
"""Group one accepted `summarize-kernel-census.py` ledger by value format.

`summarize-kernel-census.py` ranks pipelines individually, which answers what
one shader cost and leaves the question a quantization decision asks -- what
every pipeline reading one value format cost together -- to arithmetic a
reader performs by hand. This reader performs it, and refuses the two ways
that arithmetic goes wrong.

The first is the arm. A ledger states its own ownership verdict on the
`graphs` row, and the campaign doctrine reads a family through the
cross-pipeline half of it: cross-pipeline overlap alone blocks family
ownership, since same-pipeline overlap between two dispatches of one shader
stays inside the family the merge forms while overlap against a foreign
pipeline is time the instrument attributes to neither. An arm is accepted
here where its ledger carries exactly one well-formed `graphs` row, that row
reads `ownership=conclusive`, and its `cross_pipeline_overlap_fraction` stays
inside the row's own `overlap_threshold`. Every other ledger is refused whole
rather than aggregated, so a failed arm's rows never reach a share.

The second is the aggregate. A sum of `total_bracket_upper_bound_ms` over a
family is additive, because each term is a sum of intervals, and it stays an
upper bound. A sum of `exclusive_bracket_ms` is additive and stays a lower
bound, because each term is time no other bracket covered. A sum of
`pipeline_bracket_union_ms` is also an upper bound on the family union,
since two pipelines' unions can overlap. No column here states an exact
family union. A sum of `ambiguous_overlap_ms`
double-counts every interval two pipelines share, so it is printed as an
upper bound on family-ambiguous time under that name.

The share denominator is `raw_bracket_sum_ms_per_graph` times the graph
count rather than the union, because the numerators are interval sums:
against the raw sum the families partition the accounting exactly, and
against the union they would sum above one by the overlap fraction. The
union figure is printed beside it as the wall span the graphs touched.

A family is read from the pipeline name's own type tokens, quantized format
before float, so `set_rows_f32_q4_0_i64` reads Q4_0 rather than Q4_K and
`mul_mat_vec_q4_k_f32_f32` reads Q4_K rather than a float format. A pipeline
naming `f16` or `bf16` and no quantized token reads that float format, which
places `flash_attn_f32_f16_aligned` in F16 on the value format its KV
operands carry. Everything else, f32-only pipelines included, reads `other`,
and `other` prints its members so the bucket is enumerated rather than
silent.

usage: summarize-pipeline-family.py LEDGER_TSV [LEDGER_TSV...]
       [--family-prefix PREFIX]
Prints one `arm` row per ledger with its accounting denominators, then
`family` rows ranked by bracket upper bound, then one `member` row per
pipeline inside each family, as TSV on stdout. `--family-prefix` restricts
every family row to the pipelines whose name starts with that prefix, which
reads one operator's families -- `mul_mat_vec` for the mat-vec kernels --
and states the restriction on the `arm` row.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Sequence, Tuple

# The value formats a family names, quantized before float. A quantized token
# is a `q<digits>` token followed by its sub-format token, so the two-token
# pair rather than a substring decides the family and `q4_0` cannot be read
# as `q4_k`.
QUANT_TOKEN = re.compile(r"^q[0-9]+$")
QUANT_SUBFORMAT = ("k", "0", "1", "s", "m", "xs", "xxs", "nl")
FLOAT_FORMATS = ("bf16", "f16")
OTHER_FAMILY = "other"

# The `graphs` row fields this reader requires and the acceptance rule it
# applies to them.
REQUIRED_GRAPH_FIELDS = (
    "raw_bracket_sum_ms_per_graph",
    "bracket_union_ms_per_graph",
    "overlap_threshold",
    "cross_pipeline_overlap_fraction",
    "ownership",
)


class FamilyError(Exception):
    pass


class Pipeline(NamedTuple):
    name: str
    family: str
    calls_per_graph: float
    bracket_upper_bound_ms: float
    exclusive_ms: float
    ambiguous_ms: float
    workgroups_per_graph: float
    vgprs: str
    lds: str
    subgroups_per_simd: str


class Arm(NamedTuple):
    path: str
    phase: str
    graphs: int
    raw_sum_ms: float
    union_ms: float
    cross_fraction: float
    threshold: float
    pipelines: Tuple[Pipeline, ...]


def classify(name: str) -> str:
    """Read one pipeline name's value format from its own type tokens."""
    tokens = name.split("_")
    for index, token in enumerate(tokens[:-1]):
        if QUANT_TOKEN.match(token) and tokens[index + 1] in QUANT_SUBFORMAT:
            return f"{token}_{tokens[index + 1]}".upper()
    for token in tokens:
        if token in FLOAT_FORMATS:
            return token.upper()
    return OTHER_FAMILY


def parse_float(row: Sequence[str], index: int, column: str, path: str) -> float:
    try:
        value = float(row[index])
        if not math.isfinite(value) or value < 0:
            raise ValueError("expected a finite nonnegative number")
        return value
    except (IndexError, ValueError) as error:
        raise FamilyError(f"{path}: the {column} column reads {error}") from error


def graph_fields(row: Sequence[str], path: str) -> Dict[str, str]:
    fields: Dict[str, str] = {}
    for token in row[3:]:
        key, separator, value = token.partition("=")
        if not separator:
            raise FamilyError(
                f"{path}: the graphs row carries the token {token!r}, which "
                f"states no key=value pair"
            )
        if key in fields:
            raise FamilyError(f"{path}: the graphs row states {key} twice")
        fields[key] = value
    return fields


def read_ledger(path: str) -> Arm:
    """Read one ledger, refusing it whole where its own verdict is not accepted."""
    try:
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError as error:
        raise FamilyError(f"{path}: {error}") from error

    header: Optional[List[str]] = None
    pipelines: List[Pipeline] = []
    graph_rows: List[List[str]] = []
    for line in lines:
        row = line.split("\t")
        if row[0] == "pipeline" and header is None:
            header = row
            continue
        if row[0] == "pipeline":
            assert header is not None
            if len(row) != len(header):
                raise FamilyError(
                    f"{path}: a pipeline row carries {len(row)} columns against "
                    f"the header's {len(header)}"
                )
            index = {name: position for position, name in enumerate(header)}
            if len(index) != len(header):
                raise FamilyError(f"{path}: duplicate pipeline header columns")
            required = (
                "name",
                "calls_per_graph",
                "workgroups_per_graph",
                "total_bracket_upper_bound_ms",
                "pipeline_bracket_union_ms",
                "exclusive_bracket_ms",
                "ambiguous_overlap_ms",
                "vgprs",
                "lds",
                "subgroups_per_simd",
            )
            if any(column not in index for column in required):
                raise FamilyError(f"{path}: missing required pipeline columns")
            numeric = {}
            for column in (
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
            ):
                if column in index:
                    numeric[column] = parse_float(row, index[column], column, path)
            for column in (
                "vgprs",
                "sgprs",
                "spilled_vgprs",
                "lds",
                "scratch",
                "subgroups_per_simd",
            ):
                if column in index and not re.fullmatch(
                    r"0|[1-9][0-9]{0,8}", row[index[column]]
                ):
                    raise FamilyError(
                        f"{path}: {column} requires a canonical nonnegative count"
                    )
            # Ledger times are rounded independently to three decimal places.
            upper = numeric["total_bracket_upper_bound_ms"]
            union = numeric["pipeline_bracket_union_ms"]
            exclusive = numeric["exclusive_bracket_ms"]
            ambiguous = numeric["ambiguous_overlap_ms"]
            if (
                union > upper + 0.002
                or exclusive > union + 0.002
                or ambiguous > union + 0.002
            ):
                raise FamilyError(f"{path}: pipeline interval bounds conflict")
            name = row[index["name"]]
            pipelines.append(
                Pipeline(
                    name=name,
                    family=classify(name),
                    calls_per_graph=parse_float(
                        row, index["calls_per_graph"], "calls_per_graph", path
                    ),
                    bracket_upper_bound_ms=parse_float(
                        row,
                        index["total_bracket_upper_bound_ms"],
                        "total_bracket_upper_bound_ms",
                        path,
                    ),
                    exclusive_ms=parse_float(
                        row, index["exclusive_bracket_ms"], "exclusive_bracket_ms", path
                    ),
                    ambiguous_ms=parse_float(
                        row, index["ambiguous_overlap_ms"], "ambiguous_overlap_ms", path
                    ),
                    workgroups_per_graph=parse_float(
                        row,
                        index["workgroups_per_graph"],
                        "workgroups_per_graph",
                        path,
                    ),
                    vgprs=row[index["vgprs"]],
                    lds=row[index["lds"]],
                    subgroups_per_simd=row[index["subgroups_per_simd"]],
                )
            )
            continue
        if row[0] == "graphs":
            graph_rows.append(row)

    if header is None:
        raise FamilyError(f"{path}: the ledger carries no pipeline header row")
    if len(graph_rows) != 1:
        raise FamilyError(
            f"{path}: the ledger carries {len(graph_rows)} graphs rows rather than one"
        )
    graphs_row = graph_rows[0]
    if len(graphs_row) < 4:
        raise FamilyError(f"{path}: the graphs row carries {len(graphs_row)} columns")
    fields = graph_fields(graphs_row, path)
    missing = [key for key in REQUIRED_GRAPH_FIELDS if key not in fields]
    if missing:
        raise FamilyError(f"{path}: the graphs row states no {', '.join(missing)}")
    if fields["ownership"] != "conclusive":
        raise FamilyError(
            f"{path}: the ledger reads ownership={fields['ownership']}, so its "
            f"pipelines carry no accepted attribution to merge"
        )
    try:
        threshold = float(fields["overlap_threshold"])
        cross = float(fields["cross_pipeline_overlap_fraction"])
        raw_sum = float(fields["raw_bracket_sum_ms_per_graph"])
        union = float(fields["bracket_union_ms_per_graph"])
        if not re.fullmatch(r"[1-9][0-9]{0,8}", graphs_row[2]):
            raise ValueError(
                "graph count requires a bounded canonical positive integer"
            )
        graphs = int(graphs_row[2])
    except ValueError as error:
        raise FamilyError(f"{path}: the graphs row states {error}") from error
    if any(not math.isfinite(value) for value in (threshold, cross, raw_sum, union)):
        raise FamilyError(f"{path}: graphs fields require finite numbers")
    if not 0 <= cross <= 1 or not 0 <= threshold <= 1:
        raise FamilyError(f"{path}: overlap fractions require values in [0, 1]")
    if raw_sum <= 0 or union <= 0 or union > raw_sum + 0.002:
        raise FamilyError(f"{path}: graph time bounds conflict")
    if not math.isfinite(raw_sum * graphs) or not math.isfinite(union * graphs):
        raise FamilyError(f"{path}: graph totals overflow")
    for attribute in (
        "bracket_upper_bound_ms",
        "exclusive_ms",
        "ambiguous_ms",
        "calls_per_graph",
        "workgroups_per_graph",
    ):
        total = sum(getattr(pipeline, attribute) for pipeline in pipelines)
        if not math.isfinite(total):
            raise FamilyError(f"{path}: pipeline totals overflow")
    rounding_slack = 0.001 * (graphs + len(pipelines))
    if (
        sum(pipeline.bracket_upper_bound_ms for pipeline in pipelines)
        > raw_sum * graphs + rounding_slack
    ):
        raise FamilyError(f"{path}: pipeline upper totals exceed the raw denominator")
    if cross > threshold:
        raise FamilyError(
            f"{path}: cross_pipeline_overlap_fraction {cross:.4f} exceeds the "
            f"threshold {threshold:.4f}, so overlap against foreign pipelines "
            f"blocks family ownership"
        )
    if not pipelines:
        raise FamilyError(f"{path}: the ledger carries no pipeline rows")
    return Arm(
        path=path,
        phase=graphs_row[1],
        graphs=graphs,
        raw_sum_ms=raw_sum * graphs,
        union_ms=union * graphs,
        cross_fraction=cross,
        threshold=threshold,
        pipelines=tuple(pipelines),
    )


def emit(arm: Arm, prefix: Optional[str]) -> None:
    selected = [p for p in arm.pipelines if prefix is None or p.name.startswith(prefix)]
    print(
        "\t".join(
            str(value)
            for value in [
                "arm",
                arm.path,
                arm.phase,
                f"graphs={arm.graphs}",
                f"raw_bracket_sum_ms={arm.raw_sum_ms:.3f}",
                f"bracket_union_ms={arm.union_ms:.3f}",
                f"cross_pipeline_overlap_fraction={arm.cross_fraction:.4f}",
                f"overlap_threshold={arm.threshold:.4f}",
                f"family_prefix={prefix if prefix is not None else '-'}",
                f"pipelines_selected={len(selected)}",
                f"pipelines_total={len(arm.pipelines)}",
            ]
        )
    )
    families: Dict[str, List[Pipeline]] = {}
    for pipeline in selected:
        families.setdefault(pipeline.family, []).append(pipeline)
    ranked = sorted(
        families.items(),
        key=lambda item: (-sum(p.bracket_upper_bound_ms for p in item[1]), item[0]),
    )
    for family, members in ranked:
        upper = sum(p.bracket_upper_bound_ms for p in members)
        lower = sum(p.exclusive_ms for p in members)
        ambiguous = sum(p.ambiguous_ms for p in members)
        print(
            "\t".join(
                str(value)
                for value in [
                    "family",
                    family,
                    len(members),
                    f"{sum(p.calls_per_graph for p in members):.3f}",
                    f"{upper:.3f}",
                    f"{lower:.3f}",
                    f"{ambiguous:.3f}",
                    f"{upper / arm.raw_sum_ms:.4f}",
                    f"{lower / arm.raw_sum_ms:.4f}",
                ]
            )
        )
    for family, members in ranked:
        for pipeline in sorted(members, key=lambda p: -p.bracket_upper_bound_ms):
            print(
                "\t".join(
                    str(value)
                    for value in [
                        "member",
                        family,
                        pipeline.name,
                        f"{pipeline.calls_per_graph:.3f}",
                        f"{pipeline.workgroups_per_graph:.1f}",
                        f"{pipeline.bracket_upper_bound_ms:.3f}",
                        f"{pipeline.exclusive_ms:.3f}",
                        f"{pipeline.ambiguous_ms:.3f}",
                        pipeline.vgprs,
                        pipeline.lds,
                        pipeline.subgroups_per_simd,
                    ]
                )
            )


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("ledger", nargs="+")
    parser.add_argument("--family-prefix", default=None)
    try:
        args = parser.parse_args(argv)
    except SystemExit:
        return 2
    print(
        "\t".join(
            [
                "arm",
                "ledger",
                "phase",
                "graphs",
                "raw_bracket_sum_ms",
                "bracket_union_ms",
                "cross_pipeline_overlap_fraction",
                "overlap_threshold",
                "family_prefix",
                "pipelines_selected",
                "pipelines_total",
            ]
        )
    )
    print(
        "\t".join(
            [
                "family",
                "value_format",
                "pipelines",
                "calls_per_graph",
                "bracket_upper_bound_ms",
                "exclusive_lower_bound_ms",
                "ambiguous_overlap_ms_upper_bound",
                "upper_bound_share_of_raw_sum",
                "lower_bound_share_of_raw_sum",
            ]
        )
    )
    print(
        "\t".join(
            [
                "member",
                "value_format",
                "name",
                "calls_per_graph",
                "workgroups_per_graph",
                "bracket_upper_bound_ms",
                "exclusive_bracket_ms",
                "ambiguous_overlap_ms",
                "vgprs",
                "lds",
                "subgroups_per_simd",
            ]
        )
    )
    for path in args.ledger:
        try:
            arm = read_ledger(path)
        except FamilyError as error:
            print(f"family_refused: {error}", file=sys.stderr)
            return 1
        emit(arm, args.family_prefix)
    return 0


if __name__ == "__main__":
    sys.exit(main())
