#!/usr/bin/env python3
"""Read one E4b-A census arm and report how many Q4_K consumer dispatches
read each producer's own sideplane write, so a caller can tell a shared
producer from one that serves a single consumer.

`evidence/raven2-vulkan-kernel-census/e4/e4b-a-first-pass.md` measures the
reuse this script derives from a live-graph log
(`GGML_VK_Q4K_SIDEPLANE_LOG=1`) that the served appliance writes and this
tree does not retain: 84 keys over one 2B decode graph, 48 of them serving
two or more consumers and 36 serving exactly one, "43% of the pre-passes on
this graph are pure added cost." `pipeline-census-v3` carries no field
naming the activation tensor a consumer's group sums come from -- the census
patch (`patches/llama-vulkan-pipeline-census.patch`) records `dst_name` and
`src0_name` from the graph node the census's own hook point,
`ggml_vk_dispatch_pipeline`, is called under, and that node is the mat-vec's
output and its weight, never its activation -- so this script reads the fan
out structurally rather than by name.

The structure it reads is the one the design page's own finding rests on:
"it holds because each activation's consumers are adjacent in the node
order." A miss dispatches the producer from inside the first consumer that
triggers it, and `ggml_backend_vk_graph_compute` sets `census.current_node`
once per top-level graph node ahead of every dispatch that node issues, so a
producer dispatch and the consumer dispatch that triggered it carry the same
`node_idx`, and a later hit carries its own later `node_idx` with no
producer dispatch ahead of it. Sorting a graph's producer and Q4_K consumer
dispatches by `(node_idx, reach_ns)` and starting a new key group at every
producer dispatch reproduces the log's own grouping without reading a name
the census does not carry: a group is one producer dispatch followed by
every consumer dispatch up to the next producer dispatch or the graph's end,
and the group's consumer count is that key's fan-out. A consumer dispatch
ahead of any producer dispatch in a graph is unattributable under this model
and refuses the run rather than being silently folded into the nearest group.

usage: summarize-q4k-consumer-fanout.py CENSUS_TSV --window-begin-ns N
       --window-end-ns N --expected-decode-graphs N
       [--producer-pipeline-name NAME] [--consumer-pipeline-prefix PREFIX]
Prints one `key` row per producer dispatch across the selected decode
graphs, carrying its consumer count, then one `summary` row with the total
key count, the count of keys whose consumer count is exactly one, and the
count that survives a fan-out-of-one filter, as TSV on stdout.
"""
import argparse
import importlib.util
import os
import sys

SCRIPT_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
KERNEL_CENSUS_PATH = os.path.join(SCRIPT_DIRECTORY, "summarize-kernel-census.py")


def load_kernel_census_module():
    spec = importlib.util.spec_from_file_location("summarize_kernel_census", KERNEL_CENSUS_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def select_decode_graphs(kc, args):
    contexts = kc.parse(args.census)
    if args.window_end_ns <= args.window_begin_ns:
        raise kc.CensusError("the request window is empty")
    holders = [context for context in contexts
               if any(not (graph["retire_monotonic_ns"] < args.window_begin_ns
                           or graph["begin_monotonic_ns"] > args.window_end_ns)
                      for graph in context["graphs"].values())]
    if not holders:
        raise kc.CensusError(
            f"the request window {args.window_begin_ns}..{args.window_end_ns} "
            f"intersects the graphs of none of the {len(contexts)} context sections")
    if len(holders) > 1:
        named = ", ".join(str(context["index"]) for context in holders)
        raise kc.CensusError(
            f"contexts {named} each hold graphs inside the request window; "
            f"the ledger reads one context")
    selected_context = holders[0]
    pipelines = selected_context["pipelines"]
    graphs = selected_context["graphs"]
    dispatches = selected_context["dispatches"]
    emits = selected_context["emits"]

    in_window = []
    for serial, graph in sorted(graphs.items()):
        begin = graph["begin_monotonic_ns"]
        retire = graph["retire_monotonic_ns"]
        if retire < begin:
            raise kc.CensusError(f"graph {serial} retires at {retire}, ahead of its begin {begin}")
        if retire - begin != graph["retire_span_ns"]:
            raise kc.CensusError(
                f"graph {serial} spans {retire - begin} between its instants against "
                f"the declared retire_span_ns={graph['retire_span_ns']}")
        inside = begin >= args.window_begin_ns and retire <= args.window_end_ns
        outside = retire < args.window_begin_ns or begin > args.window_end_ns
        if not inside and not outside:
            raise kc.CensusError(
                f"graph {serial} spans an edge of the request window; its membership is ambiguous")
        if not inside:
            continue
        rows = dispatches.get(serial, [])
        phase = "decode" if kc.graph_tokens(rows) == 1 else "prefill"
        in_window.append((serial, graph, rows, phase))

    for serial, graph, rows, _phase in in_window:
        kc.refuse_defects(serial, graph, rows, emits.get(serial))

    decode = [(s, g, r) for s, g, r, phase in in_window if phase == "decode"]
    if len(decode) != args.expected_decode_graphs:
        raise kc.CensusError(
            f"the request window holds {len(decode)} decode graphs; "
            f"the timed request expects {args.expected_decode_graphs}")
    decode_serials = [s for s, _g, _r in decode]
    if decode_serials and decode_serials[-1] - decode_serials[0] + 1 != len(decode_serials):
        raise kc.CensusError("the decode graphs inside the request window are not contiguous in serial")
    return pipelines, decode


def group_by_producer(rows, producer_ids, consumer_ids):
    """Walk one graph's rows in node order and fold every consumer dispatch
    onto the nearest producer dispatch ahead of it.

    Returns the list of consumer counts, one per producer dispatch in the
    graph, and the count of consumer dispatches that precede every producer
    dispatch in the graph, which is unattributable under this model.
    """
    ordered = sorted(
        (d for d in rows if d["pipeline"] in producer_ids or d["pipeline"] in consumer_ids),
        key=lambda d: (d["node"], d["reach_ns"]))
    counts = []
    orphans = 0
    current = None
    for d in ordered:
        if d["pipeline"] in producer_ids:
            counts.append(0)
            current = len(counts) - 1
        else:
            if current is None:
                orphans += 1
            else:
                counts[current] += 1
    return counts, orphans


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("census")
    parser.add_argument("--window-begin-ns", type=int, required=True)
    parser.add_argument("--window-end-ns", type=int, required=True)
    parser.add_argument("--expected-decode-graphs", type=int, required=True)
    parser.add_argument("--producer-pipeline-name", default="mul_mat_vec_q4_k_prepass_f32")
    parser.add_argument("--consumer-pipeline-prefix", default="mul_mat_vec_q4_k_sideplane")
    args = parser.parse_args()

    kc = load_kernel_census_module()
    try:
        pipelines, decode = select_decode_graphs(kc, args)
        names = {pid: entry["name"] for pid, entry in pipelines.items()}
        producer_ids = {pid for pid, name in names.items()
                        if name == args.producer_pipeline_name}
        consumer_ids = {pid for pid, name in names.items()
                        if name.startswith(args.consumer_pipeline_prefix)}
        if not producer_ids:
            raise kc.CensusError(
                f"the census describes no pipeline named {args.producer_pipeline_name!r}; "
                f"this arm carries no producer dispatches to group")
        if not consumer_ids:
            raise kc.CensusError(
                f"the census describes no pipeline whose name starts with "
                f"{args.consumer_pipeline_prefix!r}; this arm carries no consumer dispatches "
                f"to group")

        rows_by_graph = {}
        orphan_total = 0
        for serial, _graph, rows in decode:
            counts, orphans = group_by_producer(rows, producer_ids, consumer_ids)
            rows_by_graph[serial] = counts
            orphan_total += orphans
        if orphan_total:
            raise kc.CensusError(
                f"{orphan_total} consumer dispatches precede every producer dispatch in "
                f"their own graph; the node-order fan-out model does not hold for this census")
    except kc.CensusError as error:
        print(f"census_refused: {error}", file=sys.stderr)
        return 1

    print("\t".join(["key", "graph_serial", "key_index", "consumer_count"]))
    total_keys = 0
    single_consumer_keys = 0
    surviving_keys = 0
    for serial, counts in rows_by_graph.items():
        for index, count in enumerate(counts):
            total_keys += 1
            if count == 1:
                single_consumer_keys += 1
            else:
                surviving_keys += 1
            print("\t".join(str(v) for v in ["key", serial, index, count]))

    print("\t".join(str(v) for v in [
        "summary", f"decode_graphs={len(decode)}",
        f"producer_pipeline={args.producer_pipeline_name}",
        f"consumer_pipeline_prefix={args.consumer_pipeline_prefix}",
        f"total_keys={total_keys}",
        f"single_consumer_keys={single_consumer_keys}",
        f"surviving_keys={surviving_keys}",
        f"mean_keys_per_graph={total_keys / len(decode):.3f}",
        f"mean_single_consumer_keys_per_graph={single_consumer_keys / len(decode):.3f}",
    ]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
