#!/usr/bin/env python3
"""summarize-kernel-census.py over a synthetic census file.

The fixture carries two pipelines, one prefill graph whose MUL_MAT token
column is 8, and two decode graphs whose column is 1; one dispatch of the
mat-vec pipeline runs twice as long as the other so the ranking, the calls
per graph, the share of the union, and the residual are each checkable
against the numbers written here. A third case carries a graph whose union
exceeds its wall, which the summarizer refuses.
"""
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
summarizer = os.path.join(script_directory, "summarize-kernel-census.py")


def pipeline_row(pipeline_id, name, constants):
    return "\t".join(str(v) for v in [
        "census_pipeline", pipeline_id, name, "main", "00000000deadbeef", 4096,
        constants, "1,1,1", 64, 0, 40, 24, 0, 0, 0, 8, 0])


def dispatch_row(serial, query, pipeline_id, node, op, ne1, src1_ne1, wg, gpu_ns):
    return "\t".join(str(v) for v in [
        "census_dispatch", serial, query, pipeline_id, node, 0, op,
        "blk.0.attn_q", "blk.0.attn_q.weight", "q8_0", "f32", "f32",
        2048, ne1, 1, 1, src1_ne1, wg, 1, 1, gpu_ns, serial])


def graph_row(serial, n_nodes, dispatches, span_ns, sum_ns, union_ns, overflow=0, read_at="synchronize"):
    record_ns = span_ns // 2
    return "\t".join(str(v) for v in [
        "census_graph", serial, n_nodes, dispatches, record_ns, span_ns, sum_ns, union_ns, overflow, read_at])


def run(rows, phase="decode"):
    with tempfile.NamedTemporaryFile("w", suffix=".tsv", delete=False) as handle:
        handle.write("census_open\tformat=pipeline-census-v1\tdevice=fixture\ttimestamp_period_ns=1.0\tserialize_submissions=0\tmax_nodes_per_submit=16\n")
        handle.write("\n".join(rows) + "\n")
        path = handle.name
    try:
        return subprocess.run([sys.executable, summarizer, path, "--phase", phase],
                              capture_output=True, text=True)
    finally:
        os.unlink(path)


rows = [
    pipeline_row(1, "mul_mat_vec_q8_0_f32", "64,2,1"),
    pipeline_row(2, "rms_norm_f32", "-"),
    # prefill: token column 8
    dispatch_row(1, 1, 1, 0, "MUL_MAT", 8, 8, 32, 50_000),
    dispatch_row(1, 2, 2, 1, "RMS_NORM", 8, 0, 1, 5_000),
    graph_row(1, 2, 2, 80_000, 55_000, 55_000),
    # decode graph 2
    dispatch_row(2, 1, 1, 0, "MUL_MAT", 1, 1, 32, 20_000),
    dispatch_row(2, 2, 2, 1, "RMS_NORM", 1, 0, 1, 2_000),
    graph_row(2, 2, 2, 30_000, 22_000, 22_000),
    # decode graph 3: the mat-vec runs twice as long
    dispatch_row(3, 1, 1, 0, "MUL_MAT", 1, 1, 32, 40_000),
    dispatch_row(3, 2, 2, 1, "RMS_NORM", 1, 0, 1, 2_000),
    graph_row(3, 2, 2, 50_000, 42_000, 42_000),
]

result = run(rows)
assert result.returncode == 0, result.stderr
lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
header, first, second, graphs = lines[0], lines[1], lines[2], lines[3]
assert header[0] == "pipeline" and graphs[0] == "graphs", result.stdout
assert first[2] == "mul_mat_vec_q8_0_f32" and second[2] == "rms_norm_f32", result.stdout
# 60 us of mat-vec over a 64 us union, one call per graph, 32 workgroups
assert first[6] == "1.000" and first[7] == "32.0", first
assert first[8] == "0.060" and first[9] == "0.9375", first
assert first[10] == "30.0" and first[13] == "40.0", first
assert second[9] == "0.0625", second
assert graphs[1] == "decode" and graphs[2] == "2", graphs
assert "sum_ms_per_graph=0.032" in graphs and "union_ms_per_graph=0.032" in graphs, graphs
assert "span_ms_per_graph=0.040" in graphs and "residual_ms_per_graph=0.008" in graphs, graphs
assert "record_ms_per_graph=0.020" in graphs, graphs
print("decode_ledger=accepted")

result = run(rows, phase="prefill")
assert result.returncode == 0, result.stderr
prefill = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
assert prefill[-1][2] == "1" and prefill[1][8] == "0.050", result.stdout
print("prefill_ledger=accepted")

# A graph whose union exceeds its wall refutes the conversion and is refused.
refuted = rows + [
    dispatch_row(4, 1, 1, 0, "MUL_MAT", 1, 1, 32, 20_000),
    graph_row(4, 1, 1, 10_000, 20_000, 20_000),
]
result = run(refuted)
assert result.returncode != 0 and "exceeds span" in result.stderr, (result.returncode, result.stderr)
print("union_over_wall_refused=accepted")

# An overflowed graph is excluded and named.
overflowed = rows + [
    dispatch_row(5, 1, 1, 0, "MUL_MAT", 1, 1, 32, 20_000),
    graph_row(5, 1, 1, 30_000, 20_000, 20_000, overflow=1),
]
result = run(overflowed)
assert result.returncode == 0 and "graph 5 overflowed" in result.stderr, result.stderr
assert result.stdout.rstrip("\n").split("\n")[-1].split("\t")[2] == "2", result.stdout
print("overflow_excluded=accepted")
print("summarize_kernel_census=accepted")
