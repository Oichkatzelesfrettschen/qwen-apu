"""Split the served Q8_0 mat-vec dispatches of one accepted I1 arm by shape.

Reads one arm's raw pipeline-census.tsv through the repository's own
summarize-kernel-census.py parser, selects the decode graphs the request
window holds by the summarizer's own rule, and re-runs the endpoint sweep
with the Q8_0 mat-vec pipeline's dispatches keyed by tensor shape rather
than by pipeline id, so each shape carries an exclusive interval on the
same basis the pipeline ledger reports.
"""
import importlib.util, re, os, statistics, sys

if len(sys.argv) != 3:
    sys.stderr.write("usage: split-q8-mat-vec-shapes.py ARM RUN_DIRECTORY_NAME\n")
    raise SystemExit(2)

ARM = sys.argv[1]
ROOT = os.path.expanduser("~/Github/qwen-apu")
RUN = sys.argv[2]
spec = importlib.util.spec_from_file_location("skc", ROOT + "/remote/summarize-kernel-census.py")
skc = importlib.util.module_from_spec(spec); spec.loader.exec_module(skc)

arm = "%s/.runtime/results/%s/calibration/arms/%s" % (ROOT, RUN, ARM)
win = dict(l.rstrip("\n").split("\t") for l in open(arm + "/request-window.tsv") if "\t" in l)
b, e = int(win["begin_ns"]), int(win["end_ns"])
ctx = skc.parse(arm + "/pipeline-census.tsv")
sections = ctx

target = None
for s in sections:
    graphs = s["graphs"]; disp = s["dispatches"]
    sel = []
    for serial in sorted(graphs):
        g = graphs[serial]; rows = disp.get(serial, [])
        if g["begin_monotonic_ns"] >= b and g["retire_monotonic_ns"] <= e:
            if skc.graph_tokens(rows) == 1:
                sel.append((serial, g, rows))
    if sel:
        target = sel
assert target, "no decode graphs"
print("arm=%s decode_graphs=%d" % (ARM, len(target)))

# The Q8_0 mat-vec pipeline this arm's decode graphs dispatch.
pipes = {}
for s in sections:
    pipes.update(s["pipelines"])
q8 = [p for p in pipes.values() if p["name"] == "mul_mat_vec_q8_0_f32_f32"]

ROLE = re.compile(r"^blk\.\d+\.")

def shape_key(d):
    return (ROLE.sub("", d["src0"]), d["ne"][0], d["ne"][1], d["wg"])

used = set()
for _s, _g, rows in target:
    for d in rows:
        if pipes[d["pipeline"]]["name"] == "mul_mat_vec_q8_0_f32_f32":
            used.add(d["pipeline"])
print("q8_pipelines_dispatched=%s" % sorted(used),
      "constants=%s" % [(p["id"], p["constants"], p["vgprs"], p["subgroups_per_simd"]) for p in q8])

calls = {}
intervals = {}
excl = {}
union = {}
amb = {}
total_excl_all = 0.0
for _s, _g, rows in target:
    keyed = []
    for d in rows:
        if d["pipeline"] in used:
            k = ("q8",) + shape_key(d)
        else:
            k = ("p", d["pipeline"])
        keyed.append((d, k))
        if k[0] == "q8":
            calls[k] = calls.get(k, 0) + 1
            intervals.setdefault(k, []).append(d["interval_ns"])
    brackets = [(d["reach_ns"], d["complete_ns"], k) for d, k in keyed
                if d["reach_ns"] >= 0 and d["complete_ns"] > d["reach_ns"]]
    starts, ends = {}, {}
    for r, c, k in brackets:
        starts.setdefault(r, []).append(k); ends.setdefault(c, []).append(k)
    pos = sorted(set(starts) | set(ends)); active = {}; covered = 0
    for i, p in enumerate(pos[:-1]):
        for k in ends.get(p, ()):
            active[k] -= 1
            if active[k] == 0: del active[k]
            covered -= 1
        for k in starts.get(p, ()):
            active[k] = active.get(k, 0) + 1; covered += 1
        L = pos[i+1] - p
        if covered == 0: continue
        for k in active: union[k] = union.get(k, 0) + L
        if covered == 1:
            k = next(iter(active)); excl[k] = excl.get(k, 0) + L
        else:
            for k in active: amb[k] = amb.get(k, 0) + L

n = len(target)
q8keys = [k for k in calls]
fam_excl = sum(excl.get(k, 0) for k in q8keys)
print("family_exclusive_ms_per_graph=%.3f family_calls_per_graph=%.1f"
      % (fam_excl / n / 1e6, sum(calls.values()) / n))
rows_out = []
for k in sorted(q8keys, key=lambda k: -excl.get(k, 0)):
    iv = sorted(intervals[k])
    rows_out.append(dict(
        tensor=k[1], ne0=k[2], ne1=k[3], wg=list(k[4]),
        calls_per_graph=calls[k] / n,
        exclusive_ms_per_graph=excl.get(k, 0) / n / 1e6,
        union_ms_per_graph=union.get(k, 0) / n / 1e6,
        ambiguous_ms_per_graph=amb.get(k, 0) / n / 1e6,
        median_us=statistics.median(iv) / 1e3,
        p99_us=iv[min(len(iv) - 1, int(0.99 * len(iv)))] / 1e3,
        share_of_family=excl.get(k, 0) / fam_excl if fam_excl else 0.0))
print("\t".join(("arm","tensor","ne0","wg0","calls_per_graph","exclusive_ms_per_graph",
                 "ambiguous_ms_per_graph","median_us","p99_us","share_of_family")))
for r in rows_out:
    print("%s\t%s\t%d\t%d\t%.1f\t%.3f\t%.3f\t%.1f\t%.1f\t%.4f" % (
        ARM, r["tensor"], r["ne0"], r["wg"][0], r["calls_per_graph"],
        r["exclusive_ms_per_graph"], r["ambiguous_ms_per_graph"],
        r["median_us"], r["p99_us"], r["share_of_family"]))
