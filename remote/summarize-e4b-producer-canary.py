#!/usr/bin/env python3
"""Read one E4b-A census arm and report whether the producer's own dispatch
cost has already erased the consumer's predicted saving, ahead of any served
kernel-delta or witness campaign.

`patches/llama-vulkan-q4k-activation-sideplane.patch` adds one pipeline,
`mul_mat_vec_q4_k_prepass_f32`, that a Q4_K consumer mat-vec dispatches once
per activation key it misses in the resident sideplane slot.
`evidence/e4b-summary-producer/README.md` puts the consumer's own saving at
about 0.8% of the graph's Q4_K bracket and names the term that could erase it:
the producer's dispatch, its two full-memory barriers, its address work, and
its four loads and one store, all unmeasured on the device the ISA receipts
were taken from. This script reads that cost from a census taken with the
census patch (`patches/llama-vulkan-pipeline-census.patch`) over an
E4b-A build run with `GGML_VK_Q4K_SIDEPLANE=1`, since `ggml_vk_dispatch_pipeline`
is the census's own hook point and the producer calls it directly
(`patches/llama-vulkan-q4k-activation-sideplane.patch` line 298), so every
producer dispatch reaches the census file as its own `census_pipeline` id
under its own name, the same way every other pipeline does.

This script imports summarize-kernel-census.py by path and reuses its parser,
its per-graph defect refusal, and its decode-graph selection by request
window verbatim, so a census this script accepts is one
summarize-kernel-census.py would accept over the same window and graph count.
Pipeline identity here is the `name` field `census_pipeline` carries, never a
position or an index a build could renumber: `--producer-pipeline-name`
selects the producer by exact name and `--q4k-family-prefix` selects the
Q4_K consumer family by name prefix, excluding the producer name itself.

The break-even allowance is read from the arm's own census rather than from
a constant. The Q4_K family's bracket union over the selected decode graphs,
divided by the graph count, is this arm's own Q4_K interval per token;
`--fallback-q4k-interval-ms` supplies the registered 49.2 ms only where the
census carries no dispatch naming the family, and the output states which
source it used. The predicted consumer saving is
`--predicted-gain-fraction` (0.008, the registered 0.8%) of that interval,
and it is spent two ways: over every producer dispatch the census counts per
graph, and over the useful producers alone, `--single-consumer-producers`
(36, the registered count of one-consumer producers) subtracted from the
measured count. Both allowances are named in the output whether or not the
useful count was itself measured, since this script counts producer
dispatches directly but not their consumer fan-out --
`summarize-q4k-consumer-fanout.py` reads that from the same census.

The verdict compares the measured per-producer cost -- the producer
pipeline's bracket union over its dispatch count, per graph, averaged over
the selected graphs -- against the all-producers allowance, since every
producer dispatch the implementation issues today pays that cost regardless
of its fan-out. `above_break_even` means the measured cost exceeds the
allowance and closes E4b-A as implemented without a full served comparison;
`below_break_even` means the measured cost clears the allowance and licenses
exactly one graph-level producer-plus-consumer comparison through
run-served-binary-ab.sh. The useful-producers allowance is reported beside it
as the bound a forward consumer walk would need to clear rather than as a
second verdict, since this script cannot itself tell a single-consumer
producer from a shared one.

usage: summarize-e4b-producer-canary.py CENSUS_TSV --window-begin-ns N
       --window-end-ns N --expected-decode-graphs N
       [--producer-pipeline-name NAME] [--q4k-family-prefix PREFIX]
       [--predicted-gain-fraction F] [--fallback-q4k-interval-ms F]
       [--single-consumer-producers N]
Prints one `graph` row per selected decode graph, then one `summary` row
carrying the allowances, the interval source, and the verdict, as TSV on
stdout.
"""
import argparse
import importlib.util
import os
import statistics
import sys

SCRIPT_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
KERNEL_CENSUS_PATH = os.path.join(SCRIPT_DIRECTORY, "summarize-kernel-census.py")

FALLBACK_Q4K_INTERVAL_MS = 49.2
FALLBACK_PREDICTED_GAIN_FRACTION = 0.008
FALLBACK_SINGLE_CONSUMER_PRODUCERS = 36


def load_kernel_census_module():
    spec = importlib.util.spec_from_file_location("summarize_kernel_census", KERNEL_CENSUS_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def select_decode_graphs(kc, args):
    """Reread the window and graph selection summarize-kernel-census.py's
    main() performs, so a canary this function accepts is a census
    summarize-kernel-census.py would accept over the same arguments."""
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


def pipeline_names_by_id(pipelines):
    return {pipeline_id: entry["name"] for pipeline_id, entry in pipelines.items()}


def bracket_union_ns(rows):
    """The union of one pipeline's own dispatch brackets, over one graph.

    Two dispatches of the same pipeline in one graph do not nest -- the
    producer runs at most once per missed key, serialized by its own
    barriers -- but the union rather than the raw sum is read here so a
    census carrying an unexpected overlap reports the wall time the pipeline
    actually occupied rather than double-counting it.
    """
    available = [(d["reach_ns"], d["complete_ns"]) for d in rows
                 if d["reach_ns"] >= 0 and d["complete_ns"] > d["reach_ns"]]
    merged = []
    for reach, complete in sorted(available):
        if merged and reach <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], complete)
        else:
            merged.append([reach, complete])
    return sum(complete - reach for reach, complete in merged)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("census")
    parser.add_argument("--window-begin-ns", type=int, required=True)
    parser.add_argument("--window-end-ns", type=int, required=True)
    parser.add_argument("--expected-decode-graphs", type=int, required=True)
    parser.add_argument("--producer-pipeline-name", default="mul_mat_vec_q4_k_prepass_f32")
    parser.add_argument("--q4k-family-prefix", default="mul_mat_vec_q4_k")
    parser.add_argument("--predicted-gain-fraction", type=float,
                         default=FALLBACK_PREDICTED_GAIN_FRACTION)
    parser.add_argument("--fallback-q4k-interval-ms", type=float,
                         default=FALLBACK_Q4K_INTERVAL_MS)
    parser.add_argument("--single-consumer-producers", type=int,
                         default=FALLBACK_SINGLE_CONSUMER_PRODUCERS)
    args = parser.parse_args()

    kc = load_kernel_census_module()
    try:
        if args.predicted_gain_fraction <= 0:
            raise kc.CensusError(
                f"the predicted gain fraction {args.predicted_gain_fraction} is not "
                f"positive")
        if args.single_consumer_producers < 0:
            raise kc.CensusError(
                f"single-consumer-producers {args.single_consumer_producers} is negative")
        pipelines, decode = select_decode_graphs(kc, args)
        names = pipeline_names_by_id(pipelines)
        producer_ids = {pid for pid, name in names.items()
                        if name == args.producer_pipeline_name}
        family_ids = {pid for pid, name in names.items()
                     if name.startswith(args.q4k_family_prefix)
                     and name != args.producer_pipeline_name}
        if not producer_ids:
            raise kc.CensusError(
                f"the census describes no pipeline named {args.producer_pipeline_name!r}; "
                f"this arm carries no producer dispatches to measure")
    except kc.CensusError as error:
        print(f"census_refused: {error}", file=sys.stderr)
        return 1

    per_graph = []
    q4k_measured_ms_total = 0.0
    for serial, graph, rows in decode:
        producer_rows = [d for d in rows if d["pipeline"] in producer_ids]
        family_rows = [d for d in rows if d["pipeline"] in family_ids]
        count = len(producer_rows)
        union_ns = bracket_union_ns(producer_rows)
        intervals = sorted(d["interval_ns"] for d in producer_rows)
        median_ns = statistics.median(intervals) if intervals else 0
        per_producer_ns = union_ns / count if count else 0.0
        q4k_measured_ms_total += bracket_union_ns(family_rows) / 1e6
        per_graph.append({
            "serial": serial, "count": count, "union_ns": union_ns,
            "median_ns": median_ns, "per_producer_ns": per_producer_ns,
        })

    n_graphs = len(decode)
    mean_count = sum(g["count"] for g in per_graph) / n_graphs
    mean_union_us = sum(g["union_ns"] for g in per_graph) / n_graphs / 1000.0
    mean_median_us = sum(g["median_ns"] for g in per_graph) / n_graphs / 1000.0
    if mean_count == 0:
        # The pipeline is registered -- producer_ids is non-empty, or the
        # earlier check would already have refused -- but no selected decode
        # graph dispatches it. A mean over zero producer dispatches states
        # nothing about a per-producer cost, and the useful-producer
        # allowance below would divide by zero rather than name the reason.
        print(
            f"census_refused: the census describes {args.producer_pipeline_name!r} but "
            f"none of the {n_graphs} selected decode graphs dispatches it; there is no "
            f"producer cost to measure",
            file=sys.stderr)
        return 1
    # The per-producer cost is read the same way the allowance is: total
    # bracket union over total dispatch count, not a mean of each graph's own
    # union/count. A per-graph mean would weight every graph equally even
    # where the producer dispatch count varies graph to graph, which can flip
    # the verdict against the allowance's own weighting.
    mean_per_producer_us = mean_union_us / mean_count

    if family_ids and q4k_measured_ms_total > 0:
        q4k_interval_ms = q4k_measured_ms_total / n_graphs
        q4k_interval_source = "measured"
    else:
        q4k_interval_ms = args.fallback_q4k_interval_ms
        q4k_interval_source = "fallback"

    predicted_gain_us = args.predicted_gain_fraction * q4k_interval_ms * 1000.0
    allowance_all_producers_us = predicted_gain_us / mean_count
    useful_count = mean_count - args.single_consumer_producers
    useful_count_source = "measured_minus_fallback_single_consumer"
    if useful_count <= 0:
        useful_count = mean_count
        useful_count_source = "single_consumer_producers_exceeded_measured_count"
    allowance_useful_producers_us = predicted_gain_us / useful_count

    verdict = ("above_break_even" if mean_per_producer_us > allowance_all_producers_us
               else "below_break_even")

    print("\t".join([
        "graph", "serial", "producer_dispatches", "bracket_median_us",
        "bracket_union_us", "per_producer_cost_us",
    ]))
    for g in per_graph:
        per_producer_us = g["per_producer_ns"] / 1000.0
        print("\t".join(str(v) for v in [
            "graph", g["serial"], g["count"], f"{g['median_ns'] / 1000.0:.3f}",
            f"{g['union_ns'] / 1000.0:.3f}", f"{per_producer_us:.3f}",
        ]))
    print("\t".join(str(v) for v in [
        "summary", f"decode_graphs={n_graphs}",
        f"producer_pipeline={args.producer_pipeline_name}",
        f"mean_producer_dispatches_per_graph={mean_count:.3f}",
        f"mean_bracket_median_us={mean_median_us:.3f}",
        f"mean_bracket_union_us={mean_union_us:.3f}",
        f"mean_per_producer_cost_us={mean_per_producer_us:.3f}",
        f"q4k_interval_ms_per_token={q4k_interval_ms:.3f}",
        f"q4k_interval_source={q4k_interval_source}",
        f"fallback_q4k_interval_ms={args.fallback_q4k_interval_ms:.3f}",
        f"predicted_gain_fraction={args.predicted_gain_fraction:.4f}",
        f"predicted_gain_us_per_token={predicted_gain_us:.3f}",
        f"allowance_all_producers_us={allowance_all_producers_us:.3f}",
        f"single_consumer_producers={args.single_consumer_producers}",
        f"useful_producer_count_per_graph={useful_count:.3f}",
        f"useful_producer_count_source={useful_count_source}",
        f"allowance_useful_producers_us={allowance_useful_producers_us:.3f}",
        f"verdict={verdict}",
    ]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
