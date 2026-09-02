#!/usr/bin/env python3
"""summarize-kernel-census.py over synthetic pipeline-census-v2 files.

The accepted fixture carries two pipelines, one prefill graph whose MUL_MAT
token column is 8, and two decode graphs whose column is 1, all inside the
request window; one bracket of the mat-vec pipeline runs twice as long as
the other, so the ranking, the calls per graph, the share of the union,
and the residual are each checkable against the numbers written here. A
warm-up decode graph before the window is excluded by the window rather
than by shape. Every refusal the summarizer makes is then exercised once:
count mismatch, non-contiguous serials, overflow, an unavailable query, an
unbound dispatch, a fallback read point, a waited read, a union above the
completion span, a completion span above the retire span, a declared
count differing from the rows, a duplicate graph, a duplicate pipeline, an
undescribed pipeline, and a header of the wrong cardinality.
"""
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
summarizer = os.path.join(script_directory, "summarize-kernel-census.py")
OPEN = ("census_open\tformat=pipeline-census-v2\tdevice=fixture\ttimestamp_period_ns=1.0"
        "\tserialize_submissions=0\tmax_nodes_per_submit=16\tclock=CLOCK_MONOTONIC")
QUEUE = "census_queue\tfamily=0\ttimestamp_valid_bits=64"
CLOSE = "census_close\tgraphs=4\tpipelines=2"


def pipeline_row(pipeline_id, name, constants):
    return "\t".join(str(v) for v in [
        "census_pipeline", pipeline_id, name, "main", "a" * 64, 4096, "b" * 64, 4104,
        constants, "1,1,1", 64, 0, 3, 48, 40, 24, 0, 0, 0, 8, 0])


def dispatch_row(serial, pipeline_id, node, op, ne1, src1_ne1, wg, reach, complete, submit=1):
    return "\t".join(str(v) for v in [
        "census_dispatch", serial, 2 * node + 1, 2 * node + 2, pipeline_id, node, 0, op,
        "blk.0.attn_q", "blk.0.attn_q.weight", "q8_0", "f32", "f32",
        2048, ne1, 1, 1, src1_ne1, wg, 1, 1, reach, complete, complete - reach,
        submit, 0, "0x1", 7])


def graph_row(serial, n_nodes, dispatches, begin, retire_span, raw_sum, union,
              non_dispatch, completion_span, overflow=0, unavailable=0,
              unbound=0, read_at="synchronize", waited=0):
    return "\t".join(str(v) for v in [
        "census_graph", serial, n_nodes, dispatches, 1, retire_span // 2, retire_span,
        1000, 2000, raw_sum, union, non_dispatch, completion_span, overflow,
        unavailable, unbound, read_at, waited, begin, begin + retire_span])


def run(rows, expected=2, window=(1_000_000, 9_000_000), phase="decode", header=(QUEUE, OPEN)):
    with tempfile.NamedTemporaryFile("w", suffix=".tsv", delete=False) as handle:
        handle.write("\n".join(list(header) + rows + [CLOSE]) + "\n")
        path = handle.name
    try:
        return subprocess.run([sys.executable, summarizer, path,
                               "--window-begin-ns", str(window[0]),
                               "--window-end-ns", str(window[1]),
                               "--expected-decode-graphs", str(expected),
                               "--phase", phase],
                              capture_output=True, text=True)
    finally:
        os.unlink(path)


base = [
    pipeline_row(1, "mul_mat_vec_q8_0_f32", "64,2,1"),
    pipeline_row(2, "rms_norm_f32", "-"),
    # warm-up decode graph ahead of the window
    dispatch_row(1, 1, 0, "MUL_MAT", 1, 1, 32, 100, 20_100),
    graph_row(1, 1, 1, 500_000, 30_000, 20_000, 20_000, 100, 20_100),
    # prefill inside the window: token column 8
    dispatch_row(2, 1, 0, "MUL_MAT", 8, 8, 32, 100, 50_100),
    dispatch_row(2, 2, 1, "RMS_NORM", 8, 0, 1, 50_200, 55_200),
    graph_row(2, 2, 2, 2_000_000, 80_000, 55_000, 55_000, 200, 55_200),
    # decode graph 3
    dispatch_row(3, 1, 0, "MUL_MAT", 1, 1, 32, 100, 20_100),
    dispatch_row(3, 2, 1, "RMS_NORM", 1, 0, 1, 20_200, 22_200),
    graph_row(3, 2, 2, 3_000_000, 30_000, 22_000, 22_000, 200, 22_200),
    # decode graph 4: the mat-vec runs twice as long
    dispatch_row(4, 1, 0, "MUL_MAT", 1, 1, 32, 100, 40_100),
    dispatch_row(4, 2, 1, "RMS_NORM", 1, 0, 1, 40_200, 42_200),
    graph_row(4, 2, 2, 4_000_000, 50_000, 42_000, 42_000, 200, 42_200),
]

result = run(base)
assert result.returncode == 0, result.stderr
lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
header, first, second, graphs = lines[0], lines[1], lines[2], lines[3]
assert header[0] == "pipeline" and graphs[0] == "graphs", result.stdout
assert first[2] == "mul_mat_vec_q8_0_f32" and second[2] == "rms_norm_f32", result.stdout
# 60 us of mat-vec over a 64 us union, one call per graph, 32 workgroups
assert first[6] == "1.000" and first[7] == "32.0", first
assert first[8] == "0.060" and first[9] == "0.9375", first
assert first[10] == "30.0" and first[13] == "40.0", first
assert first[20] == "b" * 64, first
assert second[9] == "0.0625", second
assert graphs[1] == "decode" and graphs[2] == "2", graphs
assert "raw_bracket_sum_ms_per_graph=0.032" in graphs, graphs
assert "bracket_union_ms_per_graph=0.032" in graphs, graphs
assert "queue_non_dispatch_ms_per_graph=0.000" in graphs, graphs
assert "queue_completion_span_ms_per_graph=0.032" in graphs, graphs
assert "retire_span_ms_per_graph=0.040" in graphs, graphs
assert "residual_ms_per_graph=0.008" in graphs, graphs
assert "record_ms_per_graph=0.020" in graphs, graphs
assert "read_at=synchronize" in graphs, graphs
print("decode_ledger=accepted")

result = run(base, phase="prefill")
assert result.returncode == 0, result.stderr
prefill = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
assert prefill[-1][2] == "1" and prefill[1][8] == "0.050", result.stdout
print("prefill_ledger=accepted")

# The window, not the shape, excludes the warm-up graph: widening the window
# admits it and the count then mismatches.
result = run(base, window=(0, 9_000_000))
assert result.returncode != 0 and "holds 3 decode graphs" in result.stderr, result.stderr
result = run(base, expected=3, window=(0, 9_000_000))
assert result.returncode != 0 and "not contiguous" in result.stderr, result.stderr
print("window_binding=accepted")


def refused(extra_rows, needle, expected=3, replace=None):
    rows = list(base)
    if replace is not None:
        rows = [row for row in rows if not row.startswith(replace)]
    rows += extra_rows
    result = run(rows, expected=expected)
    assert result.returncode != 0, (needle, result.stdout)
    assert needle in result.stderr, (needle, result.stderr)


refused([dispatch_row(5, 1, 0, "MUL_MAT", 1, 1, 32, 100, 20_100),
         graph_row(5, 1, 1, 5_000_000, 30_000, 20_000, 20_000, 100, 20_100, overflow=1)],
        "overflowed")
refused([dispatch_row(5, 1, 0, "MUL_MAT", 1, 1, 32, -1, -1),
         graph_row(5, 1, 1, 5_000_000, 30_000, 0, 0, 0, 0, unavailable=1)],
        "before the device wrote")
refused([dispatch_row(5, 1, 0, "MUL_MAT", 1, 1, 32, 100, 20_100, submit=0),
         graph_row(5, 1, 1, 5_000_000, 30_000, 20_000, 20_000, 100, 20_100, unbound=1)],
        "no submission bound")
refused([dispatch_row(5, 1, 0, "MUL_MAT", 1, 1, 32, 100, 20_100),
         graph_row(5, 1, 1, 5_000_000, 30_000, 20_000, 20_000, 100, 20_100, read_at="next_graph", waited=1)],
        "rather than at a retired fence")
refused([dispatch_row(5, 1, 0, "MUL_MAT", 1, 1, 32, 100, 20_100),
         graph_row(5, 1, 1, 5_000_000, 30_000, 20_000, 20_000, 100, 20_100, waited=1)],
        "with a wait")
refused([dispatch_row(5, 1, 0, "MUL_MAT", 1, 1, 32, 100, 20_100),
         graph_row(5, 1, 1, 5_000_000, 30_000, 20_000, 25_000, 100, 20_100)],
        "exceeds its completion span")
refused([dispatch_row(5, 1, 0, "MUL_MAT", 1, 1, 32, 100, 20_100),
         graph_row(5, 1, 1, 5_000_000, 10_000, 20_000, 20_000, 100, 20_100)],
        "exceeds the host retire span")
refused([dispatch_row(5, 1, 0, "MUL_MAT", 1, 1, 32, 100, 20_100),
         graph_row(5, 1, 2, 5_000_000, 30_000, 20_000, 20_000, 100, 20_100)],
        "declares 2 dispatches and retains 1")
refused([graph_row(4, 2, 2, 4_000_000, 50_000, 42_000, 42_000, 200, 42_200)],
        "graph 4 reported twice", expected=2)
refused([pipeline_row(2, "rms_norm_f32", "-")], "pipeline 2 described twice", expected=2)
refused([dispatch_row(5, 9, 0, "MUL_MAT", 1, 1, 32, 100, 20_100),
         graph_row(5, 1, 1, 5_000_000, 30_000, 20_000, 20_000, 100, 20_100)],
        "pipeline 9 the census never described")
result = run(base, header=(QUEUE, OPEN, OPEN))
assert result.returncode != 0 and "census_open appears 2 times" in result.stderr, result.stderr
result = run(base, header=(QUEUE, OPEN.replace("v2", "v1")))
assert result.returncode != 0 and "not pipeline-census-v2" in result.stderr, result.stderr
print("defects_terminal=accepted")
print("summarize_kernel_census=accepted")
