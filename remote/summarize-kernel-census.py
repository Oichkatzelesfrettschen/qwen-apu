#!/usr/bin/env python3
"""Turn pipeline census rows into a per-pipeline ledger over decode graphs.

The census binary writes three row kinds into one TSV: `census_pipeline`
(identity and RADV statistics, once per pipeline on first dispatch),
`census_dispatch` (one per recorded dispatch with its GPU interval), and
`census_graph` (per graph: node count, dispatch count, the host time spent
recording and submitting, the span from graph start to the read that
retired the pool, the sum of dispatch intervals, the union from the first
timestamp to the last, an overflow flag, and where the pool was read). On
the asynchronous path the read is the synchronize the caller waits in for
the logits, so the span bounds the token and the recording time bounds only
the host's part of it; the residual is span minus union. A graph is a decode graph
where the largest MUL_MAT token column count is 1; every other graph is a
prefill or warm-up graph and is reported separately.

usage: summarize-kernel-census.py CENSUS_TSV [--phase decode|prefill|all]
Prints `pipeline` rows ranked by total GPU time inside the selected phase,
then one `graphs` row with the phase's accounting, as TSV on stdout.
"""
import argparse
import statistics
import sys


def parse(path):
    pipelines = {}
    graphs = {}
    dispatches = {}
    opened = None
    with open(path) as handle:
        for raw in handle:
            row = raw.rstrip("\n").split("\t")
            kind = row[0]
            if kind == "census_open":
                opened = dict(field.split("=", 1) for field in row[1:])
            elif kind == "census_pipeline":
                (pipeline_id, name, entry, digest, spirv_bytes, constants,
                 wg_denoms, subgroup, full_subgroups, vgprs, sgprs, spilled,
                 lds, scratch, per_simd, register_count) = row[1:17]
                pipelines[int(pipeline_id)] = {
                    "id": int(pipeline_id), "name": name, "entry": entry,
                    "spirv_fnv1a64": digest, "spirv_bytes": int(spirv_bytes),
                    "constants": constants, "wg_denoms": wg_denoms,
                    "subgroup": int(subgroup), "full_subgroups": int(full_subgroups),
                    "vgprs": int(vgprs), "sgprs": int(sgprs), "spilled_vgprs": int(spilled),
                    "lds": int(lds), "scratch": int(scratch),
                    "subgroups_per_simd": int(per_simd),
                    "register_count": int(register_count),
                }
            elif kind == "census_dispatch":
                (serial, query, pipeline_id, node_idx, fused, op, dst_name,
                 src0_name, src0_type, src1_type, dst_type, ne0, ne1, ne2, ne3,
                 src1_ne1, wg0, wg1, wg2, gpu_ns, submit_serial) = row[1:22]
                dispatches.setdefault(int(serial), []).append({
                    "pipeline": int(pipeline_id), "node": int(node_idx),
                    "fused": int(fused), "op": op, "dst": dst_name,
                    "src0": src0_name, "src0_type": src0_type,
                    "src1_type": src1_type, "dst_type": dst_type,
                    "ne": (int(ne0), int(ne1), int(ne2), int(ne3)),
                    "src1_ne1": int(src1_ne1),
                    "wg": (int(wg0), int(wg1), int(wg2)),
                    "gpu_ns": int(gpu_ns), "submit": int(submit_serial),
                })
            elif kind == "census_graph":
                (serial, n_nodes, n_dispatches, record_ns, span_ns, sum_ns,
                 union_ns, overflow, read_at) = row[1:10]
                graphs[int(serial)] = {
                    "n_nodes": int(n_nodes), "dispatches": int(n_dispatches),
                    "record_ns": int(record_ns), "span_ns": int(span_ns),
                    "sum_ns": int(sum_ns),
                    "union_ns": int(union_ns), "overflow": int(overflow),
                    "read_at": read_at,
                }
    return opened, pipelines, graphs, dispatches


def graph_tokens(rows):
    columns = [d["ne"][1] for d in rows if d["op"] in ("MUL_MAT", "MUL_MAT_ID")]
    return max(columns) if columns else 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("census")
    parser.add_argument("--phase", choices=("decode", "prefill", "all"), default="decode")
    args = parser.parse_args()
    opened, pipelines, graphs, dispatches = parse(args.census)
    if opened is None:
        print("census file carries no census_open row", file=sys.stderr)
        return 1

    selected = []
    for serial, graph in sorted(graphs.items()):
        rows = dispatches.get(serial, [])
        tokens = graph_tokens(rows)
        phase = "decode" if tokens == 1 else "prefill"
        if args.phase != "all" and phase != args.phase:
            continue
        if graph["overflow"]:
            print(f"graph {serial} overflowed its query pool and is excluded", file=sys.stderr)
            continue
        if graph["union_ns"] > graph["span_ns"]:
            print(f"graph {serial} union {graph['union_ns']} exceeds span {graph['span_ns']}; the timestamp conversion is refuted",
                  file=sys.stderr)
            return 1
        selected.append((serial, graph, rows))
    if not selected:
        print(f"no {args.phase} graphs in {args.census}", file=sys.stderr)
        return 1

    totals = {}
    for _serial, _graph, rows in selected:
        for d in rows:
            entry = totals.setdefault(d["pipeline"], {"ns": [], "wg": 0, "calls": 0})
            entry["ns"].append(d["gpu_ns"])
            entry["wg"] += d["wg"][0] * d["wg"][1] * d["wg"][2]
            entry["calls"] += 1

    n_graphs = len(selected)
    union_total = sum(g["union_ns"] for _s, g, _r in selected)
    sum_total = sum(g["sum_ns"] for _s, g, _r in selected)
    span_total = sum(g["span_ns"] for _s, g, _r in selected)
    record_total = sum(g["record_ns"] for _s, g, _r in selected)
    print("\t".join([
        "pipeline", "id", "name", "constants", "wg_denoms", "subgroup",
        "calls_per_graph", "workgroups_per_graph", "total_gpu_ms",
        "share_of_union", "median_us", "p90_us", "p99_us", "max_us",
        "vgprs", "sgprs", "spilled_vgprs", "lds", "scratch",
        "subgroups_per_simd", "spirv_fnv1a64",
    ]))
    ranked = sorted(totals.items(), key=lambda item: -sum(item[1]["ns"]))
    for pipeline_id, entry in ranked:
        p = pipelines.get(pipeline_id)
        if p is None:
            print(f"dispatch names pipeline {pipeline_id} the census never described", file=sys.stderr)
            return 1
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
            p["subgroups_per_simd"], p["spirv_fnv1a64"],
        ]))
    print("\t".join(str(v) for v in [
        "graphs", args.phase, n_graphs,
        f"sum_ms_per_graph={sum_total / n_graphs / 1e6:.3f}",
        f"union_ms_per_graph={union_total / n_graphs / 1e6:.3f}",
        f"span_ms_per_graph={span_total / n_graphs / 1e6:.3f}",
        f"record_ms_per_graph={record_total / n_graphs / 1e6:.3f}",
        f"residual_ms_per_graph={(span_total - union_total) / n_graphs / 1e6:.3f}",
        f"read_at={','.join(sorted(set(g['read_at'] for _s, g, _r in selected)))}",
        f"device={opened.get('device', '-')}",
        f"serialize_submissions={opened.get('serialize_submissions', '-')}",
    ]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
