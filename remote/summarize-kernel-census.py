#!/usr/bin/env python3
"""Turn pipeline census rows into a per-pipeline ledger over one request's
decode graphs, refusing every record that would make the ledger a guess.

The census binary writes a `pipeline-census-v2` file of five row kinds.
`census_queue` and `census_open` appear once at device creation and
`census_close` once at cleanup. `census_pipeline` describes a pipeline the
first time an armed graph dispatched it: census-local id, name, entry point,
source and executed SPIR-V SHA-256 with byte counts, specialization
constants, workgroup denominators, subgroup policy, parameter count, push
constant size, the six RADV statistics, and the NVIDIA register count.
`census_dispatch` carries one dispatch: graph serial, the two query slots,
pipeline id, node, fusion count, op, names, types, shape, workgroups, then
`reach_ns` (the command processor reached the dispatch), `complete_ns` (the
dispatch and everything ahead of it completed), both relative to the graph's
origin timestamp, `interval_ns` between them, the submission serial bound at
submit, the queue family, and the command buffer identity. `census_graph`
carries per graph: node count, dispatch count, submit count, four host
phases (`record_ns`, `retire_span_ns`, `readback_ns`, `emit_ns`), the raw
bracket sum, the bracket union, the queue time outside every bracket, the
queue completion span from origin to the last completion, the overflow
flag, the count of dispatches whose queries were unavailable, the count
whose submission was never bound, the read point, whether the read waited,
and the graph's begin and retire instants on CLOCK_MONOTONIC.

A graph is selected by request membership rather than by shape alone: the
runner passes the monotonic window of the one completion request it
timed, and a decode graph is a graph inside that window whose largest
MUL_MAT token column is 1. The selected set is required to be exactly the
expected count and contiguous in serial, so a warm-up graph, a cache
operation, or a second request cannot enter the ledger unnamed.

Every defect is terminal. Overflow, an unavailable query, an unbound
dispatch, a read point other than `synchronize` or `graph_end`, a read that
waited, a duplicate graph or pipeline id, a dispatch naming an undescribed
pipeline, a declared dispatch count that differs from the retained rows, a
union above the completion span, a completion span above the host retire
span, and a header or footer row of the wrong cardinality each fail the run
with the reason on stderr.

usage: summarize-kernel-census.py CENSUS_TSV --window-begin-ns N
       --window-end-ns N --expected-decode-graphs N [--phase decode|prefill]
Prints `pipeline` rows ranked by total bracket time inside the selected
graphs, then one `graphs` row with the accounting, as TSV on stdout.
"""
import argparse
import statistics
import sys


class CensusError(Exception):
    pass


def parse(path):
    pipelines = {}
    graphs = {}
    dispatches = {}
    header = {"census_queue": 0, "census_open": 0, "census_close": 0}
    opened = None
    with open(path) as handle:
        for line_number, raw in enumerate(handle, 1):
            row = raw.rstrip("\n").split("\t")
            kind = row[0]
            if kind in header:
                header[kind] += 1
                if kind == "census_open":
                    opened = dict(field.split("=", 1) for field in row[1:])
            elif kind == "census_pipeline":
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
                 retire_span_ns, readback_ns, emit_ns, raw_sum_ns, union_ns,
                 non_dispatch_ns, completion_span_ns, overflow, unavailable,
                 unbound, read_at, waited, begin_monotonic_ns,
                 retire_monotonic_ns) = row[1:20]
                serial = int(serial)
                if serial in graphs:
                    raise CensusError(f"line {line_number}: graph {serial} reported twice")
                graphs[serial] = {
                    "n_nodes": int(n_nodes), "dispatches": int(n_dispatches),
                    "submits": int(n_submits), "record_ns": int(record_ns),
                    "retire_span_ns": int(retire_span_ns),
                    "readback_ns": int(readback_ns), "emit_ns": int(emit_ns),
                    "raw_sum_ns": int(raw_sum_ns), "union_ns": int(union_ns),
                    "non_dispatch_ns": int(non_dispatch_ns),
                    "completion_span_ns": int(completion_span_ns),
                    "overflow": int(overflow), "unavailable": int(unavailable),
                    "unbound": int(unbound), "read_at": read_at,
                    "waited": int(waited),
                    "begin_monotonic_ns": int(begin_monotonic_ns),
                    "retire_monotonic_ns": int(retire_monotonic_ns),
                }
    for kind, count in header.items():
        if count != 1:
            raise CensusError(f"{kind} appears {count} times, requires exactly one")
    if opened.get("format") != "pipeline-census-v2":
        raise CensusError(f"census format {opened.get('format', '-')} is not pipeline-census-v2")
    return opened, pipelines, graphs, dispatches


def graph_tokens(rows):
    columns = [d["ne"][1] for d in rows if d["op"] in ("MUL_MAT", "MUL_MAT_ID")]
    return max(columns) if columns else 0


def refuse_defects(serial, graph, rows):
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
    if graph["union_ns"] > graph["completion_span_ns"]:
        raise CensusError(f"graph {serial} bracket union {graph['union_ns']} exceeds its completion span {graph['completion_span_ns']}")
    if graph["completion_span_ns"] > graph["retire_span_ns"]:
        raise CensusError(f"graph {serial} completion span {graph['completion_span_ns']} exceeds the host retire span {graph['retire_span_ns']}; the timestamp conversion is refuted")
    for d in rows:
        if d["interval_ns"] < 0 or d["reach_ns"] < 0 or d["complete_ns"] < 0:
            raise CensusError(f"graph {serial} carries a dispatch with an unavailable bracket")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("census")
    parser.add_argument("--window-begin-ns", type=int, required=True)
    parser.add_argument("--window-end-ns", type=int, required=True)
    parser.add_argument("--expected-decode-graphs", type=int, required=True)
    parser.add_argument("--phase", choices=("decode", "prefill"), default="decode")
    args = parser.parse_args()
    try:
        opened, pipelines, graphs, dispatches = parse(args.census)
        if args.window_end_ns <= args.window_begin_ns:
            raise CensusError("the request window is empty")

        in_window = []
        for serial, graph in sorted(graphs.items()):
            if graph["begin_monotonic_ns"] < args.window_begin_ns or \
                    graph["retire_monotonic_ns"] > args.window_end_ns:
                continue
            rows = dispatches.get(serial, [])
            phase = "decode" if graph_tokens(rows) == 1 else "prefill"
            in_window.append((serial, graph, rows, phase))
        for serial in dispatches:
            if serial not in graphs:
                raise CensusError(f"dispatch rows name graph {serial}, which has no graph row")
        selected = [(s, g, r) for s, g, r, phase in in_window if phase == args.phase]
        decode_serials = [s for s, _g, _r, phase in in_window if phase == "decode"]
        if len(decode_serials) != args.expected_decode_graphs:
            raise CensusError(
                f"the request window holds {len(decode_serials)} decode graphs; "
                f"the timed request expects {args.expected_decode_graphs}")
        if decode_serials and decode_serials[-1] - decode_serials[0] + 1 != len(decode_serials):
            raise CensusError("the decode graphs inside the request window are not contiguous in serial")
        if not selected:
            raise CensusError(f"no {args.phase} graphs inside the request window")
        for serial, graph, rows in selected:
            refuse_defects(serial, graph, rows)
        for pipeline_id in {d["pipeline"] for _s, _g, rows in selected for d in rows}:
            if pipeline_id not in pipelines:
                raise CensusError(f"dispatch names pipeline {pipeline_id} the census never described")
    except CensusError as error:
        print(f"census_refused: {error}", file=sys.stderr)
        return 1

    totals = {}
    for _serial, _graph, rows in selected:
        for d in rows:
            entry = totals.setdefault(d["pipeline"], {"ns": [], "wg": 0, "calls": 0})
            entry["ns"].append(d["interval_ns"])
            entry["wg"] += d["wg"][0] * d["wg"][1] * d["wg"][2]
            entry["calls"] += 1

    n_graphs = len(selected)

    def per_graph(key):
        return sum(g[key] for _s, g, _r in selected) / n_graphs / 1e6

    union_total = sum(g["union_ns"] for _s, g, _r in selected)
    print("\t".join([
        "pipeline", "id", "name", "constants", "wg_denoms", "subgroup",
        "calls_per_graph", "workgroups_per_graph", "total_bracket_ms",
        "share_of_union", "median_us", "p90_us", "p99_us", "max_us",
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
            f"{total / 1e6:.3f}", f"{total / union_total:.4f}" if union_total else "-",
            f"{statistics.median(ns) / 1000.0:.1f}", f"{quantile(0.90):.1f}",
            f"{quantile(0.99):.1f}", f"{ns[-1] / 1000.0:.1f}",
            p["vgprs"], p["sgprs"], p["spilled_vgprs"], p["lds"], p["scratch"],
            p["subgroups_per_simd"], p["spirv_executed_sha256"],
        ]))
    print("\t".join(str(v) for v in [
        "graphs", args.phase, n_graphs,
        f"raw_bracket_sum_ms_per_graph={per_graph('raw_sum_ns'):.3f}",
        f"bracket_union_ms_per_graph={per_graph('union_ns'):.3f}",
        f"queue_non_dispatch_ms_per_graph={per_graph('non_dispatch_ns'):.3f}",
        f"queue_completion_span_ms_per_graph={per_graph('completion_span_ns'):.3f}",
        f"retire_span_ms_per_graph={per_graph('retire_span_ns'):.3f}",
        f"record_ms_per_graph={per_graph('record_ns'):.3f}",
        f"readback_ms_per_graph={per_graph('readback_ns'):.3f}",
        f"emit_ms_per_graph={per_graph('emit_ns'):.3f}",
        f"residual_ms_per_graph={per_graph('retire_span_ns') - per_graph('completion_span_ns'):.3f}",
        f"submits_per_graph={sum(g['submits'] for _s, g, _r in selected) / n_graphs:.3f}",
        f"read_at={','.join(sorted(set(g['read_at'] for _s, g, _r in selected)))}",
        f"device={opened.get('device', '-')}",
        f"serialize_submissions={opened.get('serialize_submissions', '-')}",
    ]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
