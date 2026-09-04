#!/usr/bin/env python3
"""summarize-q4k-consumer-fanout.py over a synthetic pipeline-census-v3 file.

The fixture is the same producer/consumer node layout
test-summarize-e4b-producer-canary.py builds: four producer
(`mul_mat_vec_q4_k_prepass_f32`) dispatches at nodes 0, 2, 3, and 6, with
two, one, three, and one Q4_K sideplane consumer dispatches following each
in node order, plus an `rms_norm_f32` dispatch the consumer prefix excludes.
The accepted run checks the four key rows' consumer counts against that
layout by hand and the summary's `single_consumer_keys=2` and
`surviving_keys=2` against the fan-out-of-one filter the design page names.
A second fixture drops the first producer dispatch, leaving its two
consumers ahead of every producer dispatch in the graph, and checks the
node-order model's own refusal of an unattributable consumer rather than a
silently wrong grouping.
"""
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
summarizer = os.path.join(script_directory, "summarize-q4k-consumer-fanout.py")
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

PRODUCER = "mul_mat_vec_q4_k_prepass_f32"
CONSUMER = "mul_mat_vec_q4_k_sideplane_f32_f32_subgroup_no_shmem"
NORM = "rms_norm_f32"


def pipeline_row(pipeline_id, name):
    return "\t".join(str(v) for v in [
        "census_pipeline", pipeline_id, name, "main", "a" * 64, 4096, "b" * 64, 4104,
        "0:64,1:4,2:1", "1,1,1", 64, 0, 3, 48, 40, 24, 0, 0, 0, 8, 0])


def dispatch(serial, pipeline_id, node, op, reach, complete, wg=32,
             reach_query=None, complete_query=None, interval=None,
             src0_type="q4_k"):
    return {
        "serial": serial, "pipeline": pipeline_id, "node": node, "op": op,
        "ne1": 1, "wg": wg, "submit": 1, "queue_family": 0,
        "src0_type": src0_type,
        "reach_ns": reach, "complete_ns": complete,
        "reach_query": reach_query, "complete_query": complete_query,
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
               flush_ns=300, n_nodes=None):
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
    emit_row = {
        "serial": serial, "dispatch_rows_ns": graph["dispatch_row_emit_ns"],
        "graph_row_ns": graph_row_ns, "flush_ns": flush_ns,
        "total_emit_ns": graph["dispatch_row_emit_ns"] + graph_row_ns + flush_ns,
    }
    rows = [dispatch_row(d) for d in records]
    rows.append("\t".join(["census_graph"] + [str(graph[f]) for f in GRAPH_FIELDS]))
    rows.append("\t".join(["census_emit"] + [str(emit_row[f]) for f in EMIT_FIELDS]))
    return rows


def close_row(rows, pipeline_count):
    counts = {
        "graphs": sum(1 for row in rows if row.startswith("census_graph\t")),
        "pipelines": pipeline_count,
        "dispatches": sum(1 for row in rows if row.startswith("census_dispatch\t")),
    }
    return "census_close\t" + "\t".join(f"{k}={v}" for k, v in counts.items())


def run(rows, pipeline_count, expected=1, window=WINDOW):
    argv = [sys.executable, summarizer, "",
            "--window-begin-ns", str(window[0]),
            "--window-end-ns", str(window[1]),
            "--expected-decode-graphs", str(expected)]
    body = list(rows) + [close_row(rows, pipeline_count)]
    with tempfile.NamedTemporaryFile("w", suffix=".tsv", delete=False) as handle:
        handle.write("\n".join([QUEUE, SELFTEST, OPEN] + body) + "\n")
        argv[2] = handle.name
    try:
        return subprocess.run(argv, capture_output=True, text=True)
    finally:
        os.unlink(argv[2])


def field(row, key):
    for token in row[1:]:
        if token.startswith(key + "="):
            return token[len(key) + 1:]
    raise AssertionError(f"{key} missing from {row}")


def build_records(raw):
    records = []
    for index, (pipeline_id, node, op, reach, complete, interval) in enumerate(raw):
        kwargs = {"reach_query": 2 * index + 1, "complete_query": 2 * index + 2}
        if interval is not None:
            kwargs["interval"] = interval
        if op == "RMS_NORM":
            kwargs["wg"] = 1
            kwargs["src0_type"] = "f32"
        records.append(dispatch(1, pipeline_id, node, op, reach, complete, **kwargs))
    return records


PIPELINES = [pipeline_row(1, PRODUCER), pipeline_row(2, CONSUMER), pipeline_row(3, NORM)]

# key 0: node 0 producer, then consumers at nodes 0 and 1 -- fan-out 2.
# key 1: node 2 producer, then one consumer at node 2 -- fan-out 1.
# key 2: node 3 producer, then consumers at nodes 3, 4, 5 -- fan-out 3.
# key 3: node 6 producer, then one consumer at node 6 -- fan-out 1.
RAW = [
    (1, 0, "MUL_MAT", 100, 500, None),
    (2, 0, "MUL_MAT", 500, 5_500, 5_000),
    (2, 1, "MUL_MAT", 6_000, 26_000, 20_000),
    (1, 2, "MUL_MAT", 30_000, 30_400, None),
    (2, 2, "MUL_MAT", 30_400, 31_400, 1_000),
    (1, 3, "MUL_MAT", 40_000, 40_400, None),
    (2, 3, "MUL_MAT", 40_400, 41_400, 1_000),
    (2, 4, "MUL_MAT", 42_000, 43_000, 1_000),
    (2, 5, "MUL_MAT", 44_000, 45_000, 1_000),
    (1, 6, "MUL_MAT", 50_000, 50_400, None),
    (2, 6, "MUL_MAT", 50_400, 51_400, 1_000),
    (3, 7, "RMS_NORM", 52_000, 53_000, 1_000),
]

base = PIPELINES + graph_rows(1, build_records(RAW), 3_000_000, 60_000)
result = run(base, len(PIPELINES))
assert result.returncode == 0, result.stderr
lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
keys = [line for line in lines[1:] if line[0] == "key"]
summary = next(line for line in lines if line[0] == "summary")
assert len(keys) == 4, lines
counts = [line[3] for line in keys]
assert counts == ["2", "1", "3", "1"], keys
assert field(summary, "total_keys") == "4", summary
assert field(summary, "single_consumer_keys") == "2", summary
assert field(summary, "surviving_keys") == "2", summary
assert field(summary, "mean_keys_per_graph") == "4.000", summary
assert field(summary, "mean_single_consumer_keys_per_graph") == "2.000", summary
print("fanout_layout=ok")

# Dropping the first producer dispatch leaves its two consumers with no
# producer ahead of them in the graph, which the node-order model refuses
# rather than folding onto the next key.
orphaned_raw = [row for row in RAW if row[:2] != (1, 0)]
orphaned = PIPELINES + graph_rows(1, build_records(orphaned_raw), 3_000_000, 60_000)
result = run(orphaned, len(PIPELINES))
assert result.returncode == 1, result.stdout
assert "consumer dispatches precede every producer dispatch" in result.stderr, result.stderr
print("orphaned_consumers=refused")

# A census naming no consumer pipeline refuses outright.
no_consumer_pipelines = [pipeline_row(1, PRODUCER), pipeline_row(3, NORM)]
no_consumer_raw = [row for row in RAW if row[0] != 2]
no_consumer = no_consumer_pipelines + graph_rows(1, build_records(no_consumer_raw), 3_000_000, 60_000)
result = run(no_consumer, len(no_consumer_pipelines))
assert result.returncode == 1, result.stdout
assert "carries no consumer dispatches to group" in result.stderr, result.stderr
print("no_consumer_pipeline=refused")
