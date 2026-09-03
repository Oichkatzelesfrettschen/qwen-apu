#!/usr/bin/env python3
"""Turn pipeline census rows into a per-pipeline envelope ledger over one
request's graphs, refusing every record that would make the ledger a guess.

The census binary writes a `pipeline-census-v3` file of seven row kinds.
One backend context contributes one section, opened by `census_queue`,
`census_selftest`, and `census_open` at device creation and closed by
`census_close` at cleanup, and the close row states the graph, pipeline,
and dispatch counts the reader must recount over that section alone. A
process opening several contexts appends several sections to one file --
the pinned server opens two, the first running no graph -- so the reader
validates every section on its own, requires the `census_open`
configuration to agree across sections because one run holds one
configuration, and selects the single section whose graphs the request
window intersects. Graph and pipeline identity is per section, since the
census counters live in the context's own state.
`census_pipeline` describes a pipeline the first time an armed graph
dispatched it: census-local id, name, entry point, source and executed
SPIR-V SHA-256 with byte counts, specialization constants, workgroup
denominators, subgroup policy, parameter count, push constant size, the six
RADV statistics, and the NVIDIA register count. `census_dispatch` carries
one dispatch: graph serial, the two query slots, pipeline id, node, fusion
count, op, names, types, shape, workgroups, then `reach_ns` (the command
processor reached the dispatch), `complete_ns` (the dispatch and everything
ahead of it completed), both relative to the graph's origin timestamp,
`interval_ns` between them, the submission serial bound at submit, the queue
family, and the command buffer identity. `census_graph` carries per graph:
node count, dispatch count, submit count, four host phases (`record_ns`,
`retire_span_ns`, `readback_ns`, `dispatch_row_emit_ns`), the raw bracket
sum, the bracket union, the queue time outside every bracket, the queue
completion span from origin to the last completion, the overflow flag, the
unavailable and unbound dispatch counts, the read point, whether the read
waited, and the graph's begin and retire instants on CLOCK_MONOTONIC.
`census_emit` splits the graph's own emission cost into the dispatch rows,
the graph row, and the flush.

A bracket is the half-open interval [reach_ns, complete_ns) of an available
dispatch. A bracket is an envelope rather than an occupancy: it opens where
the command processor reached the dispatch and closes where that dispatch
and everything ahead of it retired, so concurrent dispatches nest and
overlap. The ledger reports what each envelope bounds. The sum of a
pipeline's intervals is an upper bound on its device time; the union of its
own brackets bounds the wall span it touches; the time no other bracket
covers is exclusive and is a lower bound; the time some other bracket also
covers is ambiguous and is attributed to no single pipeline. The graphs row
carries the overlap the brackets themselves report, `raw_dispatch_sum_ns -
dispatch_union_ns` over the union, and names the ownership `conclusive`
only where the mean of that fraction stays inside the threshold. No column
states an ownership percentage, because the instrument measures no such
quantity.

A graph is selected by request membership rather than by shape alone: the
runner passes the monotonic window of the one completion request it timed,
a graph inside that window is one whose begin and retire instants both fall
inside it, a graph that straddles an edge is refused by serial because its
membership is ambiguous, and a decode graph is an in-window graph whose
largest MUL_MAT token column over weight matmuls, those whose source type
is other than f32, is 1. The decode set is required to be exactly
the expected count and contiguous in serial, so a warm-up graph, a cache
operation, or a second request cannot enter the ledger unnamed.

Every defect is terminal, and every in-window graph is validated ahead of
the phase filter, so a defective prefill graph refuses a decode report
rather than passing unread. Overflow, an unavailable query, an unbound
dispatch, a read point other than `synchronize` or `graph_end`, a read that
waited, a declared dispatch count that differs from the retained rows, a
negative bracket endpoint, a repeated query index, an interval that
disagrees with its endpoints, a recomputed aggregate that disagrees with
the graph row, a union above the completion span, a completion span above
the host retire span, a missing or inconsistent emit row, a duplicate graph
or pipeline id, a dispatch naming an undescribed pipeline or an unreported
graph, a dispatch on a foreign queue family, a self-test other than
`sha256=ok`, a close count that disagrees with the rows, a header row of
the wrong cardinality, a header or footer token stating no `key=value` pair
or repeating a key, a graph retiring ahead of its own begin instant, a pair
of instants whose difference disagrees with the declared `retire_span_ns`,
a section missing one of its four header and footer
rows, a row outside every section, a `census_open` field that differs
between sections, two sections both holding in-window graphs, a window
intersecting the graphs of no section, and an overlap threshold that is
infinite, not a number, or negative each fail the run with the reason on
stderr.

usage: summarize-kernel-census.py CENSUS_TSV --window-begin-ns N
       --window-end-ns N --expected-decode-graphs N [--phase decode|prefill]
       [--overlap-threshold F]
Prints `pipeline` rows ranked by the total bracket upper bound inside the
selected graphs, then one `graphs` row with the accounting, as TSV on
stdout. That row ends with `contexts` and the 1-based `selected_context`,
so a reader sees which section of the file the ledger was read from.
"""
import argparse
import math
import statistics
import sys

CENSUS_FORMAT = "pipeline-census-v3"
# `census_queue` opens a section and `census_close` ends it, so the two
# delimit; the other two header rows are counted inside the section they
# belong to.
HEADER_KINDS = ("census_queue", "census_selftest", "census_open")
# One run holds one backend configuration, so every section repeats these
# `census_open` fields verbatim.
OPEN_FIELDS = ("format", "device", "timestamp_period_ns",
               "serialize_submissions", "max_nodes_per_submit", "clock")


class CensusError(Exception):
    pass


def new_context(index):
    return {
        "index": index, "pipelines": {}, "graphs": {}, "dispatches": {},
        "emits": {}, "counts": dict.fromkeys(HEADER_KINDS, 0), "order": [],
        "queue": {}, "selftest": {}, "opened": {}, "closed": {},
    }


def metadata_fields(kind, row, line_number):
    """Read one header or footer row's `key=value` tokens into a dictionary.

    A section states one value per key, so a token carrying no '=' and a key
    stated twice each refuse the file. Dropping the first and keeping the
    last would let `census_open` declare clock=BOGUS beside
    clock=CLOCK_MONOTONIC and satisfy the clock check on the survivor, which
    hands the runner an ambiguous declaration as an accepted arm.
    """
    fields = {}
    for token in row[1:]:
        key, separator, value = token.partition("=")
        if not separator:
            raise CensusError(
                f"line {line_number}: {kind} carries the token {token!r}, which "
                f"states no key=value pair")
        if key in fields:
            raise CensusError(f"line {line_number}: {kind} states {key} twice")
        fields[key] = value
    return fields


def parse_body_row(context, row, line_number):
    """Read one pipeline, dispatch, graph, or emit row into its section."""
    pipelines = context["pipelines"]
    graphs = context["graphs"]
    dispatches = context["dispatches"]
    emits = context["emits"]
    kind = row[0]
    if kind == "census_pipeline":
        if len(row) != 21:
            raise CensusError(f"line {line_number}: census_pipeline carries {len(row) - 1} fields, requires 20")
        (pipeline_id, name, entry, source_sha256, source_bytes,
         executed_sha256, executed_bytes, constants, wg_denoms,
         subgroup, full_subgroups, parameter_count, push_constant_size,
         vgprs, sgprs, spilled, lds, scratch, per_simd,
         register_count) = row[1:21]
        pipeline_id = int(pipeline_id)
        if pipeline_id in pipelines:
            raise CensusError(f"line {line_number}: pipeline {pipeline_id} described twice")
        pipelines[pipeline_id] = {
            "id": pipeline_id, "name": name, "entry": entry,
            "spirv_source_sha256": source_sha256,
            "spirv_source_bytes": int(source_bytes),
            "spirv_executed_sha256": executed_sha256,
            "spirv_executed_bytes": int(executed_bytes),
            "constants": constants, "wg_denoms": wg_denoms,
            "subgroup": int(subgroup), "full_subgroups": int(full_subgroups),
            "parameter_count": int(parameter_count),
            "push_constant_size": int(push_constant_size),
            "vgprs": int(vgprs), "sgprs": int(sgprs), "spilled_vgprs": int(spilled),
            "lds": int(lds), "scratch": int(scratch),
            "subgroups_per_simd": int(per_simd),
            "register_count": int(register_count),
        }
    elif kind == "census_dispatch":
        if len(row) != 28:
            raise CensusError(f"line {line_number}: census_dispatch carries {len(row) - 1} fields, requires 27")
        (serial, reach_query, complete_query, pipeline_id, node_idx,
         fused, op, dst_name, src0_name, src0_type, src1_type,
         dst_type, ne0, ne1, ne2, ne3, src1_ne1, wg0, wg1, wg2,
         reach_ns, complete_ns, interval_ns, submit_serial,
         queue_family, cmd_buffer, cmd_buffer_use) = row[1:28]
        dispatches.setdefault(int(serial), []).append({
            "reach_query": int(reach_query),
            "complete_query": int(complete_query),
            "pipeline": int(pipeline_id), "node": int(node_idx),
            "fused": int(fused), "op": op, "dst": dst_name,
            "src0": src0_name, "src0_type": src0_type,
            "src1_type": src1_type, "dst_type": dst_type,
            "ne": (int(ne0), int(ne1), int(ne2), int(ne3)),
            "src1_ne1": int(src1_ne1),
            "wg": (int(wg0), int(wg1), int(wg2)),
            "reach_ns": int(reach_ns), "complete_ns": int(complete_ns),
            "interval_ns": int(interval_ns),
            "submit": int(submit_serial), "queue_family": int(queue_family),
            "cmd_buffer": cmd_buffer, "cmd_buffer_use": int(cmd_buffer_use),
        })
    elif kind == "census_graph":
        if len(row) != 20:
            raise CensusError(f"line {line_number}: census_graph carries {len(row) - 1} fields, requires 19")
        (serial, n_nodes, n_dispatches, n_submits, record_ns,
         retire_span_ns, readback_ns, dispatch_row_emit_ns, raw_sum_ns,
         union_ns, non_dispatch_ns, completion_span_ns, overflow,
         unavailable, unbound, read_at, waited, begin_monotonic_ns,
         retire_monotonic_ns) = row[1:20]
        serial = int(serial)
        if serial in graphs:
            raise CensusError(f"line {line_number}: graph {serial} reported twice")
        graphs[serial] = {
            "serial": serial,
            "n_nodes": int(n_nodes), "dispatches": int(n_dispatches),
            "submits": int(n_submits), "record_ns": int(record_ns),
            "retire_span_ns": int(retire_span_ns),
            "readback_ns": int(readback_ns),
            "dispatch_row_emit_ns": int(dispatch_row_emit_ns),
            "raw_sum_ns": int(raw_sum_ns), "union_ns": int(union_ns),
            "non_dispatch_ns": int(non_dispatch_ns),
            "completion_span_ns": int(completion_span_ns),
            "overflow": int(overflow), "unavailable": int(unavailable),
            "unbound": int(unbound), "read_at": read_at,
            "waited": int(waited),
            "begin_monotonic_ns": int(begin_monotonic_ns),
            "retire_monotonic_ns": int(retire_monotonic_ns),
        }
    elif kind == "census_emit":
        if len(row) != 6:
            raise CensusError(f"line {line_number}: census_emit carries {len(row) - 1} fields, requires 5")
        (serial, dispatch_rows_ns, graph_row_ns, flush_ns,
         total_emit_ns) = row[1:6]
        serial = int(serial)
        if serial in emits:
            raise CensusError(f"line {line_number}: graph {serial} carries two emit rows")
        emits[serial] = {
            "dispatch_rows_ns": int(dispatch_rows_ns),
            "graph_row_ns": int(graph_row_ns),
            "flush_ns": int(flush_ns),
            "total_emit_ns": int(total_emit_ns),
        }


def parse(path):
    """Split the file into context sections and validate each one alone.

    A section runs census_queue, census_selftest, census_open, its body,
    and census_close in that order. census_queue opens a section and
    census_close ends it, so a second census_queue before a close and a row
    outside every section are both refused with their line number.
    """
    contexts = []
    current = None
    with open(path) as handle:
        for line_number, raw in enumerate(handle, 1):
            row = raw.rstrip("\n").split("\t")
            kind = row[0]
            if kind == "census_queue":
                if current is not None:
                    raise CensusError(
                        f"line {line_number}: context {current['index']} reaches a "
                        f"second census_queue before its census_close")
                current = new_context(len(contexts) + 1)
            if current is None:
                raise CensusError(f"line {line_number}: {kind} appears outside a context section")
            if kind in HEADER_KINDS:
                current["counts"][kind] += 1
                current["order"].append(kind)
                fields = metadata_fields(kind, row, line_number)
                if kind == "census_queue":
                    current["queue"] = fields
                elif kind == "census_selftest":
                    current["selftest"] = fields
                else:
                    current["opened"] = fields
            elif kind == "census_close":
                current["closed"] = metadata_fields(kind, row, line_number)
                contexts.append(current)
                current = None
            else:
                if not current["counts"]["census_open"]:
                    raise CensusError(
                        f"line {line_number}: {kind} precedes the census_open of "
                        f"context {current['index']}")
                parse_body_row(current, row, line_number)
    if current is not None:
        raise CensusError(f"context {current['index']} carries no census_close")
    if not contexts:
        raise CensusError("the census file carries no context section")
    for context in contexts:
        validate_context(context)
    # The sections come from one process against one device, so a differing
    # census_open field reports two configurations in a file the window
    # selects one section of.
    reference = contexts[0]
    for context in contexts[1:]:
        for field in OPEN_FIELDS:
            if context["opened"].get(field) != reference["opened"].get(field):
                raise CensusError(
                    f"context {context['index']} census_open declares "
                    f"{field}={context['opened'].get(field, '-')} against "
                    f"{reference['opened'].get(field, '-')} in context "
                    f"{reference['index']}; the run is one configuration")
    return contexts


def validate_context(context):
    """Refuse a section whose own rows disagree with its header or footer."""
    index = context["index"]
    pipelines = context["pipelines"]
    graphs = context["graphs"]
    dispatches = context["dispatches"]
    emits = context["emits"]
    opened = context["opened"]
    selftest = context["selftest"]
    closed = context["closed"]
    for kind in HEADER_KINDS:
        count = context["counts"][kind]
        if count != 1:
            raise CensusError(f"{kind} appears {count} times in context {index}, requires exactly one")
    if context["order"] != list(HEADER_KINDS):
        raise CensusError(
            f"context {index} orders its header rows {','.join(context['order'])} "
            f"rather than {','.join(HEADER_KINDS)}")
    if opened.get("format") != CENSUS_FORMAT:
        raise CensusError(f"context {index} census format {opened.get('format', '-')} is not {CENSUS_FORMAT}")
    if opened.get("clock") != "CLOCK_MONOTONIC":
        raise CensusError(f"context {index} census clock {opened.get('clock', '-')} is not CLOCK_MONOTONIC")
    if selftest.get("sha256") != "ok":
        raise CensusError(f"context {index} census self-test reports sha256={selftest.get('sha256', '-')} rather than ok")
    queue_family = int(context["queue"].get("family", -1))
    for serial in sorted(dispatches):
        if serial not in graphs:
            raise CensusError(f"dispatch rows name graph {serial}, which has no graph row")
        for d in dispatches[serial]:
            if d["pipeline"] not in pipelines:
                raise CensusError(f"dispatch names pipeline {d['pipeline']} the census never described")
            if d["queue_family"] != queue_family:
                raise CensusError(
                    f"graph {serial} carries a dispatch on queue family {d['queue_family']}; "
                    f"the census queue is family {queue_family}")
    for serial in sorted(emits):
        if serial not in graphs:
            raise CensusError(f"an emit row names graph {serial}, which has no graph row")
    counted = {"graphs": len(graphs), "pipelines": len(pipelines),
               "dispatches": sum(len(rows) for rows in dispatches.values())}
    for field, value in counted.items():
        declared = closed.get(field)
        if declared is None:
            raise CensusError(f"context {index} census_close states no {field} count")
        if int(declared) != value:
            raise CensusError(f"context {index} census_close declares {field}={declared} against {value} parsed rows")


def graph_tokens(rows):
    """The graph's token column, read from its weight matmuls alone.

    An f32 matmul multiplies two activations, the Gated DeltaNet chunk
    products, and its column count is a chunk dimension that scales with the
    token count (2, 8, and 32 in a one-token decode graph of the 2B) rather
    than the token count; every other source type names a stored weight
    whose column count is the graph's token count.
    """
    columns = [d["ne"][1] for d in rows
               if d["op"] in ("MUL_MAT", "MUL_MAT_ID") and d["src0_type"] != "f32"]
    return max(columns) if columns else 0


def sweep(rows):
    """Attribute every elementary segment of the bracket cover.

    The endpoints of the available brackets cut the graph-relative axis into
    segments over which the covering set is constant. A segment one bracket
    covers is that pipeline's exclusive time; a segment two or more cover is
    ambiguous and is added to the global bucket once and to each covering
    pipeline. The union is every segment some bracket covers.
    """
    brackets = [(d["reach_ns"], d["complete_ns"], d["pipeline"]) for d in rows
                if d["reach_ns"] >= 0 and d["complete_ns"] > d["reach_ns"]]
    starts = {}
    ends = {}
    for reach, complete, pipeline_id in brackets:
        starts.setdefault(reach, []).append(pipeline_id)
        ends.setdefault(complete, []).append(pipeline_id)
    positions = sorted(set(starts) | set(ends))
    active = {}
    covered = 0
    union_ns = 0
    exclusive = {}
    ambiguous = {}
    pipeline_union = {}
    ambiguous_total = 0
    # An ambiguous segment whose covering brackets all belong to one pipeline
    # still belongs to that pipeline at the family level while dispatch
    # ownership inside it stays open; a segment two pipelines cover blocks
    # family ownership. The two are counted apart so a reader can tell which
    # kind the overlap fraction is made of.
    same_pipeline_overlap = 0
    cross_pipeline_overlap = 0
    for index, position in enumerate(positions[:-1]):
        for pipeline_id in ends.get(position, ()):
            active[pipeline_id] -= 1
            if active[pipeline_id] == 0:
                del active[pipeline_id]
            covered -= 1
        for pipeline_id in starts.get(position, ()):
            active[pipeline_id] = active.get(pipeline_id, 0) + 1
            covered += 1
        length = positions[index + 1] - position
        if covered == 0:
            continue
        union_ns += length
        for pipeline_id in active:
            pipeline_union[pipeline_id] = pipeline_union.get(pipeline_id, 0) + length
        if covered == 1:
            pipeline_id = next(iter(active))
            exclusive[pipeline_id] = exclusive.get(pipeline_id, 0) + length
        else:
            ambiguous_total += length
            if len(active) == 1:
                same_pipeline_overlap += length
            else:
                cross_pipeline_overlap += length
            for pipeline_id in active:
                ambiguous[pipeline_id] = ambiguous.get(pipeline_id, 0) + length
    return {
        "union_ns": union_ns, "exclusive": exclusive, "ambiguous": ambiguous,
        "pipeline_union": pipeline_union, "ambiguous_total": ambiguous_total,
        "same_pipeline_overlap_ns": same_pipeline_overlap,
        "cross_pipeline_overlap_ns": cross_pipeline_overlap,
    }


def recompute(rows):
    available = [d for d in rows if d["reach_ns"] >= 0 and d["complete_ns"] >= 0]
    cover = sweep(available)
    completion_span = max((d["complete_ns"] for d in available), default=0)
    accounting = dict(cover)
    accounting.update({
        "raw_sum_ns": sum(d["interval_ns"] for d in available),
        "completion_span_ns": completion_span,
        "non_dispatch_ns": completion_span - cover["union_ns"],
        "unavailable": len(rows) - len(available),
        "unbound": sum(1 for d in rows if d["submit"] == 0),
        "submits": len({d["submit"] for d in rows if d["submit"] != 0}),
    })
    return accounting


def refuse_defects(serial, graph, rows, emit):
    if graph["overflow"]:
        raise CensusError(f"graph {serial} overflowed its query pool")
    if graph["unavailable"]:
        raise CensusError(f"graph {serial} read {graph['unavailable']} dispatches before the device wrote their queries")
    if graph["unbound"]:
        raise CensusError(f"graph {serial} retains {graph['unbound']} dispatches no submission bound")
    if graph["read_at"] not in ("synchronize", "graph_end"):
        raise CensusError(f"graph {serial} was read at {graph['read_at']} rather than at a retired fence")
    if graph["waited"]:
        raise CensusError(f"graph {serial} was read with a wait the instrument added")
    if graph["dispatches"] != len(rows):
        raise CensusError(f"graph {serial} declares {graph['dispatches']} dispatches and retains {len(rows)} rows")
    for d in rows:
        if d["interval_ns"] < 0 or d["reach_ns"] < 0 or d["complete_ns"] < 0:
            raise CensusError(f"graph {serial} carries a dispatch with an unavailable bracket")
    indices = []
    for d in rows:
        indices.extend((d["reach_query"], d["complete_query"]))
        if d["reach_query"] >= d["complete_query"]:
            raise CensusError(
                f"graph {serial} carries a dispatch whose reach query {d['reach_query']} "
                f"is not below its complete query {d['complete_query']}")
    if len(set(indices)) != len(indices):
        raise CensusError(f"graph {serial} reuses a query index across its dispatches")
    for d in rows:
        if d["interval_ns"] != d["complete_ns"] - d["reach_ns"]:
            raise CensusError(
                f"graph {serial} carries a dispatch whose interval {d['interval_ns']} "
                f"disagrees with its endpoints {d['complete_ns']} - {d['reach_ns']}")
    accounting = recompute(rows)
    for field, key in (("raw_dispatch_sum_ns", "raw_sum_ns"),
                       ("dispatch_union_ns", "union_ns"),
                       ("queue_non_dispatch_ns", "non_dispatch_ns"),
                       ("queue_completion_span_ns", "completion_span_ns"),
                       ("unavailable", "unavailable"),
                       ("unbound", "unbound"),
                       ("submits", "submits")):
        if graph[key] != accounting[key]:
            raise CensusError(
                f"graph {serial} declares {field}={graph[key]} against {accounting[key]} "
                f"recomputed from its dispatch rows")
    if graph["union_ns"] > graph["completion_span_ns"]:
        raise CensusError(f"graph {serial} bracket union {graph['union_ns']} exceeds its completion span {graph['completion_span_ns']}")
    if graph["completion_span_ns"] > graph["retire_span_ns"]:
        raise CensusError(f"graph {serial} completion span {graph['completion_span_ns']} exceeds the host retire span {graph['retire_span_ns']}; the timestamp conversion is refuted")
    if emit is None:
        raise CensusError(f"graph {serial} carries no census_emit row")
    if emit["dispatch_rows_ns"] != graph["dispatch_row_emit_ns"]:
        raise CensusError(
            f"graph {serial} declares dispatch_rows_ns={emit['dispatch_rows_ns']} against "
            f"dispatch_row_emit_ns={graph['dispatch_row_emit_ns']}")
    # The instrument sets the total to the sum of its three parts, so a total
    # above them is as unemittable as one below and reappears as
    # total_emit_ms_per_graph, publishing an instrumentation cost no run
    # measured.
    parts = emit["dispatch_rows_ns"] + emit["graph_row_ns"] + emit["flush_ns"]
    if emit["total_emit_ns"] != parts:
        raise CensusError(
            f"graph {serial} declares total_emit_ns={emit['total_emit_ns']} against the "
            f"{parts} its own parts sum to")
    return accounting


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("census")
    parser.add_argument("--window-begin-ns", type=int, required=True)
    parser.add_argument("--window-end-ns", type=int, required=True)
    parser.add_argument("--expected-decode-graphs", type=int, required=True)
    parser.add_argument("--phase", choices=("decode", "prefill"), default="decode")
    parser.add_argument("--overlap-threshold", type=float, default=0.05)
    args = parser.parse_args()
    try:
        # argparse takes any float here, and inf makes every finite mean
        # overlap satisfy the comparison, so a census whose brackets are
        # overwhelmingly ambiguous would publish ownership=conclusive.
        if not math.isfinite(args.overlap_threshold) or args.overlap_threshold < 0:
            raise CensusError(
                f"the overlap threshold {args.overlap_threshold} is not a finite "
                f"value at or above zero")
        contexts = parse(args.census)
        if args.window_end_ns <= args.window_begin_ns:
            raise CensusError("the request window is empty")

        # A section holds the request where one of its graphs touches the
        # window at all, which keeps a section whose only claim is a graph
        # straddling an edge selectable and refuses it by serial below
        # rather than reporting an empty file.
        holders = [context for context in contexts
                   if any(not (graph["retire_monotonic_ns"] < args.window_begin_ns
                               or graph["begin_monotonic_ns"] > args.window_end_ns)
                          for graph in context["graphs"].values())]
        if not holders:
            raise CensusError(
                f"the request window {args.window_begin_ns}..{args.window_end_ns} "
                f"intersects the graphs of none of the {len(contexts)} context sections")
        if len(holders) > 1:
            named = ", ".join(str(context["index"]) for context in holders)
            raise CensusError(
                f"contexts {named} each hold graphs inside the request window; "
                f"the ledger reads one context")
        selected_context = holders[0]
        context_index = selected_context["index"]
        opened = selected_context["opened"]
        pipelines = selected_context["pipelines"]
        graphs = selected_context["graphs"]
        dispatches = selected_context["dispatches"]
        emits = selected_context["emits"]

        in_window = []
        for serial, graph in sorted(graphs.items()):
            begin = graph["begin_monotonic_ns"]
            retire = graph["retire_monotonic_ns"]
            # Membership reads both instants against the window and the
            # window alone relates them, so the pair is checked against
            # itself first. The instrument sets retire_span_ns to
            # retire_monotonic_ns minus the graph's begin, which makes the
            # equality exact and an unrelated graph placed wholly inside the
            # window detectable here rather than attributed to the request.
            if retire < begin:
                raise CensusError(
                    f"graph {serial} retires at {retire}, ahead of its begin {begin}")
            if retire - begin != graph["retire_span_ns"]:
                raise CensusError(
                    f"graph {serial} spans {retire - begin} between its instants against "
                    f"the declared retire_span_ns={graph['retire_span_ns']}")
            inside = begin >= args.window_begin_ns and retire <= args.window_end_ns
            outside = retire < args.window_begin_ns or begin > args.window_end_ns
            if not inside and not outside:
                raise CensusError(
                    f"graph {serial} spans an edge of the request window; its membership "
                    f"is ambiguous")
            if not inside:
                continue
            rows = dispatches.get(serial, [])
            phase = "decode" if graph_tokens(rows) == 1 else "prefill"
            in_window.append((serial, graph, rows, phase))

        accounted = {}
        for serial, graph, rows, _phase in in_window:
            accounted[serial] = refuse_defects(serial, graph, rows,
                                               emits.get(serial))

        decode_serials = [s for s, _g, _r, phase in in_window if phase == "decode"]
        if len(decode_serials) != args.expected_decode_graphs:
            raise CensusError(
                f"the request window holds {len(decode_serials)} decode graphs; "
                f"the timed request expects {args.expected_decode_graphs}")
        if decode_serials and decode_serials[-1] - decode_serials[0] + 1 != len(decode_serials):
            raise CensusError("the decode graphs inside the request window are not contiguous in serial")
        selected = [(s, g, r) for s, g, r, phase in in_window if phase == args.phase]
        if not selected:
            raise CensusError(f"no {args.phase} graphs inside the request window")
    except CensusError as error:
        print(f"census_refused: {error}", file=sys.stderr)
        return 1

    totals = {}
    overlap_fractions = []
    overlap_ns_total = 0
    exclusive_total = 0
    ambiguous_total = 0
    same_pipeline_total = 0
    cross_pipeline_total = 0
    cross_fractions = []
    for serial, graph, rows in selected:
        accounting = accounted[serial]
        overlap_ns = graph["raw_sum_ns"] - graph["union_ns"]
        overlap_ns_total += overlap_ns
        overlap_fractions.append(overlap_ns / graph["union_ns"] if graph["union_ns"] else 0.0)
        exclusive_total += sum(accounting["exclusive"].values())
        ambiguous_total += accounting["ambiguous_total"]
        same_pipeline_total += accounting["same_pipeline_overlap_ns"]
        cross_pipeline_total += accounting["cross_pipeline_overlap_ns"]
        cross_fractions.append(accounting["cross_pipeline_overlap_ns"] / graph["union_ns"]
                               if graph["union_ns"] else 0.0)
        for d in rows:
            entry = totals.setdefault(d["pipeline"], {
                "ns": [], "wg": 0, "calls": 0, "exclusive": 0,
                "ambiguous": 0, "union": 0})
            entry["ns"].append(d["interval_ns"])
            entry["wg"] += d["wg"][0] * d["wg"][1] * d["wg"][2]
            entry["calls"] += 1
        for pipeline_id, value in accounting["exclusive"].items():
            totals[pipeline_id]["exclusive"] += value
        for pipeline_id, value in accounting["ambiguous"].items():
            totals[pipeline_id]["ambiguous"] += value
        for pipeline_id, value in accounting["pipeline_union"].items():
            totals[pipeline_id]["union"] += value

    n_graphs = len(selected)
    mean_overlap_fraction = sum(overlap_fractions) / n_graphs
    mean_cross_fraction = sum(cross_fractions) / n_graphs
    # The verdict reads the whole overlap, which withholds attribution rather
    # than manufacturing it; the same- and cross-pipeline halves beside it
    # are the derived reading, since cross-pipeline overlap alone blocks
    # family ownership.
    ownership = "conclusive" if mean_overlap_fraction <= args.overlap_threshold else "inconclusive"

    def per_graph(key):
        return sum(g[key] for _s, g, _r in selected) / n_graphs / 1e6

    def per_graph_emit(key):
        return sum(emits[s][key] for s, _g, _r in selected) / n_graphs / 1e6

    print("\t".join([
        "pipeline", "id", "name", "constants", "wg_denoms", "subgroup",
        "calls_per_graph", "workgroups_per_graph",
        "total_bracket_upper_bound_ms", "pipeline_bracket_union_ms",
        "exclusive_bracket_ms", "ambiguous_overlap_ms",
        "median_us", "p90_us", "p99_us", "max_us",
        "vgprs", "sgprs", "spilled_vgprs", "lds", "scratch",
        "subgroups_per_simd", "spirv_executed_sha256",
    ]))
    ranked = sorted(totals.items(), key=lambda item: (-sum(item[1]["ns"]), item[0]))
    for pipeline_id, entry in ranked:
        p = pipelines[pipeline_id]
        ns = sorted(entry["ns"])
        total = sum(ns)

        def quantile(q):
            index = min(len(ns) - 1, int(round(q * (len(ns) - 1))))
            return ns[index] / 1000.0

        print("\t".join(str(v) for v in [
            "pipeline", p["id"], p["name"], p["constants"], p["wg_denoms"], p["subgroup"],
            f"{entry['calls'] / n_graphs:.3f}", f"{entry['wg'] / n_graphs:.1f}",
            f"{total / 1e6:.3f}", f"{entry['union'] / 1e6:.3f}",
            f"{entry['exclusive'] / 1e6:.3f}", f"{entry['ambiguous'] / 1e6:.3f}",
            f"{statistics.median(ns) / 1000.0:.1f}", f"{quantile(0.90):.1f}",
            f"{quantile(0.99):.1f}", f"{ns[-1] / 1000.0:.1f}",
            p["vgprs"], p["sgprs"], p["spilled_vgprs"], p["lds"], p["scratch"],
            p["subgroups_per_simd"], p["spirv_executed_sha256"],
        ]))
    print("\t".join(str(v) for v in [
        "graphs", args.phase, n_graphs,
        f"raw_bracket_sum_ms_per_graph={per_graph('raw_sum_ns'):.3f}",
        f"bracket_union_ms_per_graph={per_graph('union_ns'):.3f}",
        f"exclusive_ms_per_graph={exclusive_total / n_graphs / 1e6:.3f}",
        f"ambiguous_overlap_ms_per_graph={ambiguous_total / n_graphs / 1e6:.3f}",
        f"same_pipeline_overlap_ms_per_graph={same_pipeline_total / n_graphs / 1e6:.3f}",
        f"cross_pipeline_overlap_ms_per_graph={cross_pipeline_total / n_graphs / 1e6:.3f}",
        f"overlap_ms_per_graph={overlap_ns_total / n_graphs / 1e6:.3f}",
        f"overlap_fraction={mean_overlap_fraction:.4f}",
        f"cross_pipeline_overlap_fraction={mean_cross_fraction:.4f}",
        f"overlap_threshold={args.overlap_threshold:.4f}",
        f"ownership={ownership}",
        f"queue_non_dispatch_ms_per_graph={per_graph('non_dispatch_ns'):.3f}",
        f"queue_completion_span_ms_per_graph={per_graph('completion_span_ns'):.3f}",
        f"retire_span_ms_per_graph={per_graph('retire_span_ns'):.3f}",
        f"record_ms_per_graph={per_graph('record_ns'):.3f}",
        f"readback_ms_per_graph={per_graph('readback_ns'):.3f}",
        f"dispatch_row_emit_ms_per_graph={per_graph('dispatch_row_emit_ns'):.3f}",
        f"total_emit_ms_per_graph={per_graph_emit('total_emit_ns'):.3f}",
        f"flush_ms_per_graph={per_graph_emit('flush_ns'):.3f}",
        f"residual_ms_per_graph={per_graph('retire_span_ns') - per_graph('completion_span_ns'):.3f}",
        f"submits_per_graph={sum(g['submits'] for _s, g, _r in selected) / n_graphs:.3f}",
        f"read_at={','.join(sorted(set(g['read_at'] for _s, g, _r in selected)))}",
        f"device={opened.get('device', '-')}",
        f"serialize_submissions={opened.get('serialize_submissions', '-')}",
        f"contexts={len(contexts)}",
        f"selected_context={context_index}",
    ]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
