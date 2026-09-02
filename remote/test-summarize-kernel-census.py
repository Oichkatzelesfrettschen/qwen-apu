#!/usr/bin/env python3
"""summarize-kernel-census.py over synthetic pipeline-census-v3 files.

Every fixture is assembled from dispatch records, and the builders derive
the `census_graph` aggregates and the `census_emit` row from those records
through their own interval merge, so a fixture states brackets and the
ledger it implies follows. A test that wants a disagreement names the field
to override, which keeps an accepted fixture consistent by construction and
a refused one wrong in exactly one place.

The accepted ledger carries two pipelines, one prefill graph whose MUL_MAT
token column is 8, two decode graphs whose column is 1, and a warm-up
decode graph ahead of the window. The second decode graph overlaps a
mat-vec bracket with a norm bracket for 10 us, so the exclusive time, the
ambiguous overlap, the per-pipeline union, the overlap fraction, and the
ranking are each checked against numbers written here. Widening the window
admits the warm-up graph, which is what proves the window rather than the
shape excludes it, and a window edge cutting a graph in half is refused by
serial.

Validation precedes the phase filter, so a defective prefill graph inside
the window refuses a decode report. Every refusal is exercised once: the
graph defects, each reachable recomputed-aggregate disagreement, the emit
row, the close counts, the queue family, the self-test, and the header
cardinality. Two rules stay guards rather than reachable refusals, since
the recompute settles them first: a recomputed unavailable count above zero
requires a negative endpoint the bracket check already refuses, and a
recomputed union never exceeds the recomputed completion span it is bounded
by. The fixture each would state is asserted against the earlier refusal.

The section fixtures concatenate whole context sections, since a process
opening two backend contexts appends two to one file. An empty section
ahead of the run reproduces the pinned server's own shape and selects
context 2, a second section whose graphs sit past the window selects
context 1, two sections holding the window refuse by naming both, and a
missing census_close, a row after a close, a body row ahead of its own
census_open, and a census_open device that changes between sections each
refuse.
"""
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
summarizer = os.path.join(script_directory, "summarize-kernel-census.py")
QUEUE = "census_queue\tfamily=0\ttimestamp_valid_bits=64"
SELFTEST = "census_selftest\tsha256=ok\tvectors=3"
OPEN = ("census_open\tformat=pipeline-census-v3\tdevice=fixture\ttimestamp_period_ns=1.0"
        "\tserialize_submissions=0\tmax_nodes_per_submit=16\tclock=CLOCK_MONOTONIC")
WINDOW = (1_000_000, 9_000_000)

GRAPH_FIELDS = (
    "serial", "n_nodes", "dispatches", "submits", "record_ns",
    "retire_span_ns", "readback_ns", "dispatch_row_emit_ns",
    "raw_dispatch_sum_ns", "dispatch_union_ns", "queue_non_dispatch_ns",
    "queue_completion_span_ns", "overflow", "unavailable", "unbound",
    "read_at", "waited", "begin_monotonic_ns", "retire_monotonic_ns",
)
EMIT_FIELDS = ("serial", "dispatch_rows_ns", "graph_row_ns", "flush_ns",
               "total_emit_ns")


def pipeline_row(pipeline_id, name, constants):
    return "\t".join(str(v) for v in [
        "census_pipeline", pipeline_id, name, "main", "a" * 64, 4096, "b" * 64, 4104,
        constants, "1,1,1", 64, 0, 3, 48, 40, 24, 0, 0, 0, 8, 0])


def dispatch(serial, pipeline_id, node, op, ne1, reach, complete, wg=32,
             submit=1, queue_family=0, reach_query=None, complete_query=None,
             interval=None, src0_type="q8_0"):
    return {
        "serial": serial, "pipeline": pipeline_id, "node": node, "op": op,
        "ne1": ne1, "wg": wg, "submit": submit, "queue_family": queue_family,
        "src0_type": src0_type,
        "reach_ns": reach, "complete_ns": complete,
        "reach_query": 2 * node + 1 if reach_query is None else reach_query,
        "complete_query": 2 * node + 2 if complete_query is None else complete_query,
        "interval_ns": complete - reach if interval is None else interval,
    }


def dispatch_row(d):
    return "\t".join(str(v) for v in [
        "census_dispatch", d["serial"], d["reach_query"], d["complete_query"],
        d["pipeline"], d["node"], 0, d["op"], "blk.0.attn_q",
        "blk.0.attn_q.weight", d["src0_type"], "f32", "f32", 2048, d["ne1"], 1, 1,
        d["ne1"], d["wg"], 1, 1, d["reach_ns"], d["complete_ns"],
        d["interval_ns"], d["submit"], d["queue_family"], "0x1", 7])


def aggregates(records):
    """Recompute the graph aggregates from the dispatch records.

    The union is a merge of the sorted available brackets, which is a second
    implementation of the summarizer's endpoint sweep rather than a copy of
    it, so an accepted fixture agrees with the summarizer only where both
    read the same brackets.
    """
    available = [d for d in records
                 if d["reach_ns"] >= 0 and d["complete_ns"] >= 0]
    merged = []
    for reach, complete in sorted((d["reach_ns"], d["complete_ns"])
                                  for d in available if d["complete_ns"] > d["reach_ns"]):
        if merged and reach <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], complete)
        else:
            merged.append([reach, complete])
    union = sum(complete - reach for reach, complete in merged)
    span = max((d["complete_ns"] for d in available), default=0)
    return {
        "raw_dispatch_sum_ns": sum(d["interval_ns"] for d in available),
        "dispatch_union_ns": union,
        "queue_completion_span_ns": span,
        "queue_non_dispatch_ns": span - union,
        "unavailable": len(records) - len(available),
        "unbound": sum(1 for d in records if d["submit"] == 0),
        "submits": len({d["submit"] for d in records if d["submit"] != 0}),
    }


def graph_rows(serial, records, begin, retire_span, record_ns=None,
               readback_ns=1000, dispatch_row_emit_ns=2000, graph_row_ns=500,
               flush_ns=300, total_emit_ns=3000, n_nodes=None, overrides=None,
               emit_overrides=None, emit=True):
    graph = {
        "serial": serial,
        "n_nodes": len(records) if n_nodes is None else n_nodes,
        "dispatches": len(records),
        "record_ns": retire_span // 2 if record_ns is None else record_ns,
        "retire_span_ns": retire_span, "readback_ns": readback_ns,
        "dispatch_row_emit_ns": dispatch_row_emit_ns,
        "overflow": 0, "read_at": "synchronize", "waited": 0,
        "begin_monotonic_ns": begin, "retire_monotonic_ns": begin + retire_span,
    }
    graph.update(aggregates(records))
    graph.update(overrides or {})
    emit_row = {
        "serial": serial, "dispatch_rows_ns": graph["dispatch_row_emit_ns"],
        "graph_row_ns": graph_row_ns, "flush_ns": flush_ns,
        "total_emit_ns": total_emit_ns,
    }
    emit_row.update(emit_overrides or {})
    rows = [dispatch_row(d) for d in records]
    rows.append("\t".join(["census_graph"] + [str(graph[f]) for f in GRAPH_FIELDS]))
    if emit:
        rows.append("\t".join(["census_emit"] + [str(emit_row[f]) for f in EMIT_FIELDS]))
    return rows


def close_row(rows, overrides=None):
    counts = {
        "graphs": sum(1 for row in rows if row.startswith("census_graph\t")),
        "pipelines": sum(1 for row in rows if row.startswith("census_pipeline\t")),
        "dispatches": sum(1 for row in rows if row.startswith("census_dispatch\t")),
    }
    counts.update(overrides or {})
    return "census_close\t" + "\t".join(f"{k}={v}" for k, v in counts.items())


def run(rows, expected=2, window=WINDOW, phase="decode",
        header=(QUEUE, SELFTEST, OPEN), close=None, threshold=None):
    argv = [sys.executable, summarizer, "",
            "--window-begin-ns", str(window[0]),
            "--window-end-ns", str(window[1]),
            "--expected-decode-graphs", str(expected),
            "--phase", phase]
    if threshold is not None:
        argv += ["--overlap-threshold", str(threshold)]
    with tempfile.NamedTemporaryFile("w", suffix=".tsv", delete=False) as handle:
        handle.write("\n".join(list(header) + rows +
                               [close if close is not None else close_row(rows)]) + "\n")
        argv[2] = handle.name
    try:
        return subprocess.run(argv, capture_output=True, text=True)
    finally:
        os.unlink(argv[2])


# The warm-up decode graph retires at 530_000, ahead of the window.
warmup = [dispatch(1, 1, 0, "MUL_MAT", 1, 100, 20_100)]
# The prefill graph carries a token column of 8.
prefill = [dispatch(2, 1, 0, "MUL_MAT", 8, 100, 50_100),
           dispatch(2, 2, 1, "RMS_NORM", 8, 50_200, 55_200, wg=1)]
# The first decode graph holds two disjoint brackets.
decode_a = [dispatch(3, 1, 0, "MUL_MAT", 1, 100, 20_100),
            dispatch(3, 2, 1, "RMS_NORM", 1, 20_200, 22_200, wg=1)]
# The second overlaps the two pipelines for 10_000 ns.
decode_b = [dispatch(4, 1, 0, "MUL_MAT", 1, 100, 40_100),
            dispatch(4, 2, 1, "RMS_NORM", 1, 30_100, 42_100, wg=1)]

base = ([pipeline_row(1, "mul_mat_vec_q8_0_f32", "64,2,1"),
         pipeline_row(2, "rms_norm_f32", "-")]
        + graph_rows(1, warmup, 500_000, 30_000)
        + graph_rows(2, prefill, 2_000_000, 80_000)
        + graph_rows(3, decode_a, 3_000_000, 30_000)
        + graph_rows(4, decode_b, 4_000_000, 50_000))

result = run(base)
assert result.returncode == 0, result.stderr
lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
header, first, second, graphs = lines[0], lines[1], lines[2], lines[3]
assert header[0] == "pipeline" and graphs[0] == "graphs", result.stdout
assert header[8:12] == ["total_bracket_upper_bound_ms", "pipeline_bracket_union_ms",
                        "exclusive_bracket_ms", "ambiguous_overlap_ms"], header
assert "ownership_percent" not in "\t".join(header), header
# The mat-vec ranks first on 20_000 + 40_000 ns of bracket.
assert first[2] == "mul_mat_vec_q8_0_f32" and second[2] == "rms_norm_f32", result.stdout
assert first[6] == "1.000" and first[7] == "32.0", first
assert first[8] == "0.060" and first[9] == "0.060", first
# Exclusive 20_000 + 30_000, ambiguous 10_000, and the two sum to the union.
assert first[10] == "0.050" and first[11] == "0.010", first
assert first[12] == "30.0" and first[15] == "40.0", first
assert first[22] == "b" * 64, first
# The norm carries 2_000 + 12_000 of bracket, 2_000 + 2_000 exclusive.
assert second[8] == "0.014" and second[9] == "0.014", second
assert second[10] == "0.004" and second[11] == "0.010", second
assert graphs[1] == "decode" and graphs[2] == "2", graphs
assert "raw_bracket_sum_ms_per_graph=0.037" in graphs, graphs
assert "bracket_union_ms_per_graph=0.032" in graphs, graphs
assert "exclusive_ms_per_graph=0.027" in graphs, graphs
assert "ambiguous_overlap_ms_per_graph=0.005" in graphs, graphs
assert "overlap_ms_per_graph=0.005" in graphs, graphs
# (0 + 10_000/42_000) / 2 graphs
assert "overlap_fraction=0.1190" in graphs, graphs
# The 10_000 ns overlap is between two pipelines, so the derived reading
# places all of it on the cross-pipeline side.
assert "same_pipeline_overlap_ms_per_graph=0.000" in graphs, graphs
assert "cross_pipeline_overlap_ms_per_graph=0.005" in graphs, graphs
assert "cross_pipeline_overlap_fraction=0.1190" in graphs, graphs
assert "queue_non_dispatch_ms_per_graph=0.000" in graphs, graphs
assert "queue_completion_span_ms_per_graph=0.032" in graphs, graphs
assert "retire_span_ms_per_graph=0.040" in graphs, graphs
assert "residual_ms_per_graph=0.008" in graphs, graphs
assert "record_ms_per_graph=0.020" in graphs, graphs
assert "readback_ms_per_graph=0.001" in graphs, graphs
assert "dispatch_row_emit_ms_per_graph=0.002" in graphs, graphs
assert "total_emit_ms_per_graph=0.003" in graphs, graphs
assert "flush_ms_per_graph=0.000" in graphs, graphs
assert "submits_per_graph=1.000" in graphs, graphs
assert "read_at=synchronize" in graphs, graphs
assert "device=fixture" in graphs, graphs
assert "serialize_submissions=0" in graphs, graphs
assert "contexts=1" in graphs and "selected_context=1" in graphs, graphs
print("decode_ledger=accepted")

result = run(base, phase="prefill")
assert result.returncode == 0, result.stderr
prefill_lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
assert prefill_lines[-1][2] == "1", result.stdout
assert prefill_lines[1][8] == "0.050" and prefill_lines[1][10] == "0.050", result.stdout
assert "ownership=conclusive" in prefill_lines[-1], result.stdout
print("prefill_ledger=accepted")

# 0.1190 of mean overlap exceeds the 0.05 default and stays inside 0.2.
assert "ownership=inconclusive" in graphs and "overlap_threshold=0.0500" in graphs, graphs
result = run(base, threshold=0.2)
assert result.returncode == 0, result.stderr
raised = result.stdout.rstrip("\n").split("\n")[-1].split("\t")
assert "ownership=conclusive" in raised and "overlap_threshold=0.2000" in raised, raised
assert len(result.stdout.rstrip("\n").split("\n")) == 4, result.stdout
print("ownership_threshold=accepted")

# An f32 matmul is a Gated DeltaNet chunk product whose column count is a
# chunk dimension, so a decode graph carrying one at ne1=32 beside its
# weight matmuls at ne1=1 stays decode; the fixture is the accepted ledger
# with that dispatch added to the first decode graph.
decode_a_with_chunk = decode_a + [dispatch(3, 1, 2, "MUL_MAT", 32, 22_300, 23_300, src0_type="f32")]
chunk_base = ([pipeline_row(1, "mul_mat_vec_q8_0_f32", "64,2,1"),
               pipeline_row(2, "rms_norm_f32", "-")]
              + graph_rows(1, warmup, 500_000, 30_000)
              + graph_rows(2, prefill, 2_000_000, 80_000)
              + graph_rows(3, decode_a_with_chunk, 3_000_000, 30_000)
              + graph_rows(4, decode_b, 4_000_000, 50_000))
result = run(chunk_base)
assert result.returncode == 0, result.stderr
assert result.stdout.rstrip("\n").split("\n")[-1].split("\t")[2] == "2", result.stdout
print("chunk_product_stays_decode=accepted")

# The window, not the shape, excludes the warm-up graph: widening the window
# admits it and the count then mismatches.
result = run(base, window=(0, 9_000_000))
assert result.returncode != 0 and "holds 3 decode graphs" in result.stderr, result.stderr
result = run(base, expected=3, window=(0, 9_000_000))
assert result.returncode != 0 and "not contiguous" in result.stderr, result.stderr
# A window edge cutting graph 3 in half refuses by serial.
result = run(base, window=(2_500_000, 3_010_000))
assert result.returncode != 0 and "graph 3 spans an edge" in result.stderr, result.stderr
result = run(base, window=(5_000_000, 5_000_000))
assert result.returncode != 0 and "window is empty" in result.stderr, result.stderr
result = run(base, window=(2_900_000, 9_000_000), phase="prefill")
assert result.returncode != 0 and "no prefill graphs" in result.stderr, result.stderr
print("window_binding=accepted")

# A defective prefill graph inside the window refuses a decode report.
p1 = ([pipeline_row(1, "mul_mat_vec_q8_0_f32", "64,2,1"),
       pipeline_row(2, "rms_norm_f32", "-")]
      + graph_rows(2, prefill, 2_000_000, 80_000, overrides={"overflow": 1})
      + graph_rows(3, decode_a, 3_000_000, 30_000)
      + graph_rows(4, decode_b, 4_000_000, 50_000))
result = run(p1)
assert result.returncode != 0 and "graph 2 overflowed" in result.stderr, result.stderr
print("prefill_defect_refuses_decode=accepted")


def refused(needle, extra=None, expected=3, close=None, header=(QUEUE, SELFTEST, OPEN)):
    result = run(base + list(extra or []), expected=expected, close=close,
                 header=header)
    assert result.returncode != 0, (needle, result.stdout)
    assert needle in result.stderr, (needle, result.stderr)


def extra(records=None, serial=5, begin=5_000_000, retire_span=30_000, **kw):
    if records is None:
        records = [dispatch(serial, 1, 0, "MUL_MAT", 1, 100, 20_100)]
    return graph_rows(serial, records, begin, retire_span, **kw)


refused("overflowed", extra(overrides={"overflow": 1}))
refused("before the device wrote",
        extra([dispatch(5, 1, 0, "MUL_MAT", 1, -1, -1, interval=-1)],
              overrides={"unavailable": 1, "raw_dispatch_sum_ns": 0,
                         "dispatch_union_ns": 0, "queue_non_dispatch_ns": 0,
                         "queue_completion_span_ns": 0}))
refused("no submission bound",
        extra([dispatch(5, 1, 0, "MUL_MAT", 1, 100, 20_100, submit=0)],
              overrides={"unbound": 1}))
refused("rather than at a retired fence", extra(overrides={"read_at": "next_graph"}))
refused("with a wait", extra(overrides={"waited": 1}))
refused("declares 2 dispatches and retains 1", extra(overrides={"dispatches": 2}))
# A negative endpoint the graph row calls available is caught as a bracket
# defect, which is what leaves the recomputed unavailable comparison behind
# it as a consistency guard rather than a reachable refusal.
refused("unavailable bracket",
        extra([dispatch(5, 1, 0, "MUL_MAT", 1, -1, -1, interval=-1)],
              overrides={"unavailable": 0, "raw_dispatch_sum_ns": -1,
                         "dispatch_union_ns": 0,
                         "queue_non_dispatch_ns": 0,
                         "queue_completion_span_ns": 0}))
refused("is not below its complete query",
        extra([dispatch(5, 1, 0, "MUL_MAT", 1, 100, 20_100,
                        reach_query=4, complete_query=3)]))
refused("reuses a query index",
        extra([dispatch(5, 1, 0, "MUL_MAT", 1, 100, 20_100),
               dispatch(5, 2, 1, "RMS_NORM", 1, 20_200, 22_200,
                        reach_query=1, complete_query=4)]))
refused("disagrees with its endpoints",
        extra([dispatch(5, 1, 0, "MUL_MAT", 1, 100, 20_100, interval=19_000)],
              overrides={"raw_dispatch_sum_ns": 19_000}))

# Each reachable recomputed-aggregate disagreement, one field at a time.
refused("declares raw_dispatch_sum_ns=19000 against 20000",
        extra(overrides={"raw_dispatch_sum_ns": 19_000}))
refused("declares dispatch_union_ns=19000 against 20000",
        extra(overrides={"dispatch_union_ns": 19_000,
                         "queue_non_dispatch_ns": 1_100}))
refused("declares queue_non_dispatch_ns=200 against 100",
        extra(overrides={"queue_non_dispatch_ns": 200}))
refused("declares queue_completion_span_ns=20200 against 20100",
        extra(overrides={"queue_completion_span_ns": 20_200}))
refused("declares unbound=0 against 1",
        extra(overrides={"unbound": 0},
              records=[dispatch(5, 1, 0, "MUL_MAT", 1, 100, 20_100, submit=0)]))
refused("declares submits=2 against 1", extra(overrides={"submits": 2}))

# A union above the completion span reaches the reader as a disagreeing
# aggregate, since the recomputed union of brackets ending at or below the
# recomputed maximum completion can never exceed it. The union-above-span
# rule stays a residual guard over a graph row the recompute already
# accepted, so the fixture that would state it is refused one step earlier.
refused("declares dispatch_union_ns=25000 against 20000",
        extra(overrides={"dispatch_union_ns": 25_000,
                         "queue_non_dispatch_ns": -4_900}))
refused("exceeds the host retire span", extra(retire_span=10_000))
refused("carries no census_emit row", extra(emit=False))
refused("declares dispatch_rows_ns=1999",
        extra(emit_overrides={"dispatch_rows_ns": 1999}))
refused("below the 2800 its own parts sum to",
        extra(emit_overrides={"total_emit_ns": 2799}))
refused("the census queue is family 0",
        extra(records=[dispatch(5, 1, 0, "MUL_MAT", 1, 100, 20_100,
                                queue_family=1)]))
refused("graph 4 reported twice",
        graph_rows(4, decode_b, 4_000_000, 50_000), expected=2)
refused("pipeline 2 described twice", [pipeline_row(2, "rms_norm_f32", "-")],
        expected=2)
refused("pipeline 9 the census never described",
        extra(records=[dispatch(5, 9, 0, "MUL_MAT", 1, 100, 20_100)]))
refused("dispatch rows name graph 9",
        [dispatch_row(dispatch(9, 1, 0, "MUL_MAT", 1, 100, 20_100))],
        expected=2)
refused("census_close declares graphs=9 against 4 parsed rows",
        expected=2, close=close_row(base, {"graphs": 9}))
refused("census_close declares dispatches=99 against 7 parsed rows",
        expected=2, close=close_row(base, {"dispatches": 99}))
refused("census_selftest appears 0 times", expected=2, header=(QUEUE, OPEN))
refused("self-test reports sha256=fail", expected=2,
        header=(QUEUE, SELFTEST.replace("ok", "fail"), OPEN))
refused("census_open appears 2 times", expected=2,
        header=(QUEUE, SELFTEST, OPEN, OPEN))
refused("not pipeline-census-v3", expected=2,
        header=(QUEUE, SELFTEST, OPEN.replace("v3", "v2")))
refused("is not CLOCK_MONOTONIC", expected=2,
        header=(QUEUE, SELFTEST, OPEN.replace("CLOCK_MONOTONIC", "CLOCK_REALTIME")))
print("defects_terminal=accepted")


def context_section(rows, header=(QUEUE, SELFTEST, OPEN), close=True):
    """One context section: the three header rows, a body, and the close."""
    return list(header) + rows + ([close_row(rows)] if close else [])


def run_file(lines, expected=2, window=WINDOW, phase="decode"):
    """Run the summarizer over a file written verbatim from `lines`."""
    argv = [sys.executable, summarizer, "",
            "--window-begin-ns", str(window[0]),
            "--window-end-ns", str(window[1]),
            "--expected-decode-graphs", str(expected),
            "--phase", phase]
    with tempfile.NamedTemporaryFile("w", suffix=".tsv", delete=False) as handle:
        handle.write("\n".join(lines) + "\n")
        argv[2] = handle.name
    try:
        return subprocess.run(argv, capture_output=True, text=True)
    finally:
        os.unlink(argv[2])


# The pinned server opens two backend contexts and the first runs no graph,
# so the retained file carries an empty section ahead of the run. Serials
# restart per context, which the late section states by numbering from 0.
empty_context = context_section([])
late = ([pipeline_row(1, "mul_mat_vec_q8_0_f32", "64,2,1")]
        + graph_rows(0, [dispatch(0, 1, 0, "MUL_MAT", 1, 100, 20_100)],
                     20_000_000, 30_000))

result = run_file(empty_context + context_section(base))
assert result.returncode == 0, result.stderr
two_context_graphs = result.stdout.rstrip("\n").split("\n")[-1].split("\t")
assert "contexts=2" in two_context_graphs, two_context_graphs
assert "selected_context=2" in two_context_graphs, two_context_graphs
# The section the window selects carries the whole ledger, so the accounting
# equals the single-section run of the same rows.
assert two_context_graphs[3:] == graphs[3:-2] + ["contexts=2", "selected_context=2"], two_context_graphs

result = run_file(context_section(base) + context_section(late))
assert result.returncode == 0, result.stderr
first_selected = result.stdout.rstrip("\n").split("\n")[-1].split("\t")
assert "contexts=2" in first_selected and "selected_context=1" in first_selected, first_selected
print("context_selection=accepted")

result = run_file(context_section(base) + context_section(base))
assert result.returncode != 0, result.stdout
assert "contexts 1, 2 each hold graphs inside the request window" in result.stderr, result.stderr
result = run_file(context_section(base) + context_section(late),
                  window=(15_000_000, 16_000_000))
assert result.returncode != 0, result.stdout
assert "intersects the graphs of none of the 2 context sections" in result.stderr, result.stderr
print("context_ambiguity=accepted")

# A section stops at its census_close, so a missing one is refused both at
# the next census_queue and at end of file.
result = run_file(context_section(base, close=False))
assert result.returncode != 0 and "context 1 carries no census_close" in result.stderr, result.stderr
result = run_file(context_section(base, close=False) + context_section(late))
assert result.returncode != 0, result.stdout
assert "context 1 reaches a second census_queue" in result.stderr, result.stderr
# A body row after a close belongs to no section.
result = run_file(context_section(base) + [dispatch_row(dispatch(9, 1, 0, "MUL_MAT", 1, 100, 20_100))])
assert result.returncode != 0, result.stdout
assert "census_dispatch appears outside a context section" in result.stderr, result.stderr
# A body row ahead of its own census_open is refused with its line number.
result = run_file([QUEUE, SELFTEST] + base + [OPEN, close_row(base)])
assert result.returncode != 0, result.stdout
assert "precedes the census_open of context 1" in result.stderr, result.stderr
print("section_shape=accepted")

result = run_file(context_section(base) + context_section(
    late, header=(QUEUE, SELFTEST, OPEN.replace("device=fixture", "device=second"))))
assert result.returncode != 0, result.stdout
assert "context 2 census_open declares device=second against fixture in context 1" in result.stderr, result.stderr
assert "the run is one configuration" in result.stderr, result.stderr
# The rule covers every census_open field rather than the device alone.
result = run_file(context_section(base) + context_section(
    late, header=(QUEUE, SELFTEST,
                  OPEN.replace("serialize_submissions=0", "serialize_submissions=1"))))
assert result.returncode != 0, result.stdout
assert "declares serialize_submissions=1 against 0" in result.stderr, result.stderr
print("one_configuration=accepted")

print("summarize_kernel_census=accepted")
