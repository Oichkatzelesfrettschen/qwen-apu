#!/usr/bin/env python3
"""summarize-e4b-producer-canary.py over a synthetic pipeline-census-v3 file.

The fixture holds one decode graph carrying four producer
(`mul_mat_vec_q4_k_prepass_f32`) dispatches interleaved with seven consumer
(`mul_mat_vec_q4_k_sideplane_f32_f32_subgroup_no_shmem`) dispatches and one
`rms_norm_f32` dispatch the Q4_K family prefix excludes. Every producer
dispatch runs 400 ns and the four are disjoint, so their bracket union is
1600 ns over 4 dispatches, a per-producer cost of 400 ns = 0.400 us. The
consumer family's seven dispatches are pairwise disjoint and sum to
30_000 ns, so this arm's own measured Q4_K interval is 0.030 ms per token
rather than the 49.2 ms fallback, and the predicted gain at the default
0.008 fraction is 0.008 * 0.030 ms * 1000 = 0.240 us, spent over 4
producers: an allowance of 0.060 us per producer, which the measured
0.400 us per-producer cost clears on the wrong side, so the accepted
fixture is checked against `verdict=above_break_even`. A second run with
`--predicted-gain-fraction` raised to 0.1 lifts the allowance to 0.750 us,
above the measured cost, and checks the `below_break_even` arm of the same
fixture together with the measured-minus-fallback useful-producer path. A
third run drops every consumer dispatch and checks the fallback to the
registered 49.2 ms constant. Every refusal
summarize-kernel-census.py itself would raise is inherited rather than
re-tested here; only the two refusals unique to this script -- a census
naming no producer pipeline -- are exercised.
"""
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
summarizer = os.path.join(script_directory, "summarize-e4b-producer-canary.py")
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


def dispatch(serial, pipeline_id, node, op, ne1, reach, complete, wg=32,
             submit=1, queue_family=0, reach_query=None, complete_query=None,
             interval=None, src0_type="q4_k"):
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
               flush_ns=300, n_nodes=None, overrides=None,
               emit_overrides=None):
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
        "total_emit_ns": graph["dispatch_row_emit_ns"] + graph_row_ns + flush_ns,
    }
    emit_row.update(emit_overrides or {})
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


def run(rows, pipeline_count, expected=1, window=WINDOW, extra_args=()):
    argv = [sys.executable, summarizer, "",
            "--window-begin-ns", str(window[0]),
            "--window-end-ns", str(window[1]),
            "--expected-decode-graphs", str(expected)] + list(extra_args)
    body = list(rows) + [close_row(rows, pipeline_count)]
    with tempfile.NamedTemporaryFile("w", suffix=".tsv", delete=False) as handle:
        handle.write("\n".join([QUEUE, SELFTEST, OPEN] + body) + "\n")
        argv[2] = handle.name
    try:
        return subprocess.run(argv, capture_output=True, text=True)
    finally:
        os.unlink(argv[2])


# id 1: producer, id 2: Q4_K sideplane consumer, id 3: rms_norm (excluded from
# the family by name even though the file could not confuse it with the
# producer either way).
PIPELINES = [pipeline_row(1, PRODUCER), pipeline_row(2, CONSUMER), pipeline_row(3, NORM)]

# key 0: node 0, producer then two consumers at nodes 0 and 1 -- fan-out 2.
# key 1: node 2, producer then one consumer -- fan-out 1.
# key 2: node 3, producer then three consumers at nodes 3, 4, 5 -- fan-out 3.
# key 3: node 6, producer then one consumer -- fan-out 1.
# A norm dispatch at node 7 stays outside the family by name.
# Two dispatches at one node (a producer and the consumer that triggered it)
# would collide on the default node-derived query pair, so every record here
# names its own query indices explicitly in dispatch order.
_raw_records = [
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
records = []
for index, (pipeline_id, node, op, reach, complete, interval) in enumerate(_raw_records):
    kwargs = {"reach_query": 2 * index + 1, "complete_query": 2 * index + 2}
    if interval is not None:
        kwargs["interval"] = interval
    if op == "RMS_NORM":
        kwargs["wg"] = 1
        kwargs["src0_type"] = "f32"
    records.append(dispatch(1, pipeline_id, node, op, 1, reach, complete, **kwargs))
base = PIPELINES + graph_rows(1, records, 3_000_000, 60_000)

# The consumer family's own bracket union: five disjoint consumer intervals
# of the seven consumer dispatches overlap only where two of node 0's
# dispatches touch (5_000 and 20_000 are disjoint at 500..5_500 and
# 6_000..26_000), so the union is the raw sum, 5_000 + 20_000 + 1_000 * 5 =
# 30_000 ns... the fixture is read back through the summarizer itself below
# rather than asserted by hand a second time, since the union computation is
# exactly what summarize-kernel-census.py's own sweep already tests.

result = run(base, len(PIPELINES))
assert result.returncode == 0, result.stderr
lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
graph_rows_out = [line for line in lines[1:] if line[0] == "graph"]
summary = next(line for line in lines if line[0] == "summary")
assert len(graph_rows_out) == 1, lines
g = graph_rows_out[0]
assert g[1] == "1" and g[2] == "4", g  # graph serial 1, 4 producer dispatches
# The four producer intervals are 400 ns each and disjoint: union 1_600 ns,
# median 400 ns, per-producer cost 1_600 / 4 = 400 ns = 0.400 us.
assert g[3] == "0.400" and g[4] == "1.600" and g[5] == "0.400", g


def field(row, key):
    for token in row[1:]:
        if token.startswith(key + "="):
            return token[len(key) + 1:]
    raise AssertionError(f"{key} missing from {row}")


assert field(summary, "decode_graphs") == "1", summary
assert field(summary, "mean_producer_dispatches_per_graph") == "4.000", summary
assert field(summary, "mean_per_producer_cost_us") == "0.400", summary
assert field(summary, "q4k_interval_source") == "measured", summary
# 5_000 + 20_000 + 1_000 * 5 = 30_000 ns = 0.030 ms.
assert field(summary, "q4k_interval_ms_per_token") == "0.030", summary
# predicted_gain_us = 0.008 * 0.030 ms * 1000 = 0.240 us over 4 producers.
assert field(summary, "predicted_gain_us_per_token") == "0.240", summary
assert field(summary, "allowance_all_producers_us") == "0.060", summary
assert field(summary, "verdict") == "above_break_even", summary
# useful_producer_count_per_graph = 4 - 36 <= 0, so the fallback path names
# the measured count instead and single_consumer_producers still reads 36.
assert field(summary, "single_consumer_producers") == "36", summary
assert field(summary, "useful_producer_count_source") == "single_consumer_producers_exceeded_measured_count", summary
print("accepted_above_break_even=ok")

# Raising the predicted-gain fraction until the allowance clears the 0.400 us
# measured cost flips the verdict on the same fixture, and naming the true
# single-consumer count (2 of 4 keys) exercises the measured-minus-fallback
# path instead of the exceeded one.
result = run(base, len(PIPELINES),
             extra_args=["--predicted-gain-fraction", "0.1", "--single-consumer-producers", "2"])
assert result.returncode == 0, result.stderr
lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
summary = next(line for line in lines if line[0] == "summary")
# predicted_gain_us = 0.1 * 0.030 ms * 1000 = 3.000 us over 4 producers = 0.750 us allowance.
assert field(summary, "allowance_all_producers_us") == "0.750", summary
assert field(summary, "verdict") == "below_break_even", summary
assert field(summary, "useful_producer_count_per_graph") == "2.000", summary
assert field(summary, "useful_producer_count_source") == "measured_minus_fallback_single_consumer", summary
# 3.000 us / 2 useful producers = 1.500 us.
assert field(summary, "allowance_useful_producers_us") == "1.500", summary
print("verdict_flip=ok")

# Dropping every consumer dispatch removes the Q4_K family from the census
# entirely, so the interval falls back to the registered constant.
no_family_records = [d for d in records if d["pipeline"] != 2]
no_family = PIPELINES + graph_rows(1, no_family_records, 3_000_000, 60_000)
result = run(no_family, len(PIPELINES))
assert result.returncode == 0, result.stderr
lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
summary = next(line for line in lines if line[0] == "summary")
assert field(summary, "q4k_interval_source") == "fallback", summary
assert field(summary, "q4k_interval_ms_per_token") == "49.200", summary
print("fallback_interval=ok")

# A census naming no producer pipeline at all refuses outright.
no_producer_pipelines = [pipeline_row(2, CONSUMER), pipeline_row(3, NORM)]
no_producer_records = [d for d in records if d["pipeline"] != 1]
no_producer = no_producer_pipelines + graph_rows(1, no_producer_records, 3_000_000, 60_000)
result = run(no_producer, len(no_producer_pipelines))
assert result.returncode == 1, result.stdout
assert "carries no producer dispatches to measure" in result.stderr, result.stderr
print("no_producer_pipeline=refused")

# A pipeline the census describes but the selected decode graphs never
# dispatch is a zero-dispatch producer, not a missing one: producer_ids is
# non-empty because the pipeline row exists, so the earlier refusal does not
# fire, and the later useful-producer allowance would divide by zero without
# an explicit check.
zero_dispatch_records = [d for d in records if d["pipeline"] != 1]
zero_dispatch = PIPELINES + graph_rows(1, zero_dispatch_records, 3_000_000, 60_000)
result = run(zero_dispatch, len(PIPELINES))
assert result.returncode == 1, result.stdout
assert "none of the 1 selected decode graphs dispatches it" in result.stderr, result.stderr
print("zero_dispatch_producer=refused")

# Two graphs with different producer dispatch counts: graph 1 keeps the base
# fixture's 4 producer dispatches (union 1_600 ns), graph 2 carries 2
# producer dispatches of 1_000 ns each, disjoint (union 2_000 ns). The
# correct per-producer cost weights by dispatch count -- total union over
# total count, (1_600 + 2_000) / (4 + 2) = 600 ns -- rather than averaging
# each graph's own union/count unweighted, which would read
# (400 + 1_000) / 2 = 700 ns and disagree with the allowance's own
# mean_count-weighted denominator.
graph2_records = [
    dispatch(2, 1, 0, "MUL_MAT_VEC_ID", 1, 100, 1_100, reach_query=1, complete_query=2, src0_type="f32"),
    dispatch(2, 1, 1, "MUL_MAT_VEC_ID", 1, 2_000, 3_000, reach_query=3, complete_query=4, src0_type="f32"),
    # graph_tokens() reads its column count from a non-f32 MUL_MAT/MUL_MAT_ID
    # dispatch alone, and the producer's own op stays outside that pair by
    # design (its op is MUL_MAT_VEC_ID and its src0 is f32), so a graph with
    # producer dispatches and no Q4_K consumer needs one such marker to read
    # as decode rather than prefill.
    dispatch(2, 3, 2, "MUL_MAT", 1, 4_000, 4_500, reach_query=5, complete_query=6),
]
variable_count = PIPELINES + graph_rows(1, records, 3_000_000, 60_000) + \
    graph_rows(2, graph2_records, 5_000_000, 10_000)
result = run(variable_count, len(PIPELINES), expected=2)
assert result.returncode == 0, result.stderr
lines = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
summary = next(line for line in lines if line[0] == "summary")
assert field(summary, "mean_producer_dispatches_per_graph") == "3.000", summary
assert field(summary, "mean_bracket_union_us") == "1.800", summary
assert field(summary, "mean_per_producer_cost_us") == "0.600", summary
print("weighted_per_producer_cost=ok")
