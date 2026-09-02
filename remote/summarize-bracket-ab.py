#!/usr/bin/env python3
"""Judge a kernel-delta comparison by one pipeline's GPU bracket.

usage: summarize-bracket-ab.py ARMS_TSV ARMS_DIRECTORY --subject PIPELINE
           --null PIPELINE [--bound F] [--column exclusive_bracket_ms]

The arms ledger carries `C K K C` quadruples the way run-served-binary-ab.sh
writes them, and every completed arm's directory holds the decode ledger the
census summarizer wrote (`pipeline-ledger-decode.tsv`) and the reply the
served runner retained (`response.json`). For each pair (inner over outer) the
delta is the candidate's bracket over the control's minus one, read from the
named column of the row whose `name` matches the pipeline, so a pipeline the
patch shortens reads negative. Student's t over the paired deltas gives the
nominal 95% interval, as summarize-census-controls.py does for the served
rate, and the verdicts read:

    subject   shortened   the whole interval sits below -bound
              lengthened  the whole interval sits above +bound
              unchanged   the whole interval sits inside [-bound, +bound]
              unresolved  the interval crosses a bound
    null      held        the whole interval sits inside [-bound, +bound]
              state-changed otherwise

The null pipeline is the one the patch leaves untouched, and it is read from
the same arms and the same graphs as the subject, so a null that moves names
a machine-state change the subject's delta cannot be attributed against. A
`token_identity` row compares every candidate reply's content and predicted
token count against the control replies of the same quadruple: `held` where
all agree, `differs` where any pair disagrees, and `unavailable` where a
reply is unreadable. Greedy decoding at temperature 0 is deterministic on
this backend within a fixed request sequence, so a kernel that answers
differently computed something else.

Every row states its per-arm values so a reader can recompute the delta from
the retained ledgers rather than trust the mean.
"""

import argparse
import csv
import json
import math
import os
import sys

T_95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365}
COMPLETED_STATUS = ("completed", "reused")
COLUMNS = ("role", "pipeline", "column", "replicates", "comparable_pairs",
           "mean_delta", "sd_delta", "ci_low", "ci_high", "deltas",
           "control_values", "candidate_values", "bound", "verdict", "detail")


def read_arms(path):
    with open(path) as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    for required in ("slot", "arm", "status"):
        if rows and required not in rows[0]:
            raise SystemExit(f"arms ledger lacks column {required}")
    return [row for row in rows if row["arm"] not in ("W", "S")]


def quadruples(arms):
    index = 0
    while index + 3 < len(arms):
        a, b, c, d = arms[index:index + 4]
        if a["arm"] == d["arm"] and b["arm"] == c["arm"] and a["arm"] != b["arm"]:
            yield a, b, c, d
            index += 4
        else:
            index += 1


def arm_directory(root, row):
    slot = row["slot"]
    name = f"{int(slot):02d}-{row['arm']}" if slot.isdigit() else f"{slot}-{row['arm']}"
    return os.path.join(root, name)


def bracket_value(directory, pipeline, column):
    path = os.path.join(directory, "pipeline-ledger-decode.tsv")
    try:
        with open(path) as handle:
            lines = [line.rstrip("\n") for line in handle if line.strip()]
    except OSError:
        return None
    header = None
    matches = []
    for line in lines:
        fields = line.split("\t")
        if fields[0] == "pipeline" and fields[1] == "id":
            header = fields
            continue
        if header and fields[0] == "pipeline":
            record = dict(zip(header, fields))
            if record.get("name") == pipeline:
                matches.append(record)
    if header is None or column not in header or len(matches) != 1:
        return None
    try:
        return float(matches[0][column])
    except ValueError:
        return None


def reply_identity(directory):
    try:
        with open(os.path.join(directory, "response.json")) as handle:
            reply = json.load(handle)
        choices = reply["choices"]
        content = choices[0]["message"]["content"]
        predicted = reply.get("timings", {}).get("predicted_n")
    except (OSError, ValueError, KeyError, IndexError, TypeError):
        return None
    return (content, predicted)


def interval(deltas):
    count = len(deltas)
    degrees = count - 1
    if degrees not in T_95:
        raise SystemExit(f"{count} pairs: the t table covers 2 through 8")
    mean = sum(deltas) / count
    variance = sum((delta - mean) ** 2 for delta in deltas) / degrees
    deviation = math.sqrt(variance)
    half = T_95[degrees] * deviation / math.sqrt(count)
    return mean, deviation, mean - half, mean + half


def judge(role, low, high, bound):
    inside = -bound <= low and high <= bound
    if role == "null":
        return ("held", "-") if inside else ("state-changed", f"ci=[{low:+.4f},{high:+.4f}] outside bound={bound}")
    if high < -bound:
        return "shortened", f"ci=[{low:+.4f},{high:+.4f}] below -bound={bound}"
    if low > bound:
        return "lengthened", f"ci=[{low:+.4f},{high:+.4f}] above bound={bound}"
    if inside:
        return "unchanged", f"ci=[{low:+.4f},{high:+.4f}] inside bound={bound}"
    return "unresolved", f"ci=[{low:+.4f},{high:+.4f}] crosses bound={bound}"


def pipeline_row(role, pipeline, column, pairs, root, bound):
    deltas = []
    listed = []
    controls = []
    candidates = []
    replicates = len(pairs)
    for control, candidate in pairs:
        both = (control["status"] in COMPLETED_STATUS and candidate["status"] in COMPLETED_STATUS)
        control_value = bracket_value(arm_directory(root, control), pipeline, column) if both else None
        candidate_value = bracket_value(arm_directory(root, candidate), pipeline, column) if both else None
        controls.append("-" if control_value is None else f"{control_value:.3f}")
        candidates.append("-" if candidate_value is None else f"{candidate_value:.3f}")
        if control_value is None or candidate_value is None or control_value <= 0:
            listed.append("arm-failed" if not both else "ledger-missing")
            continue
        delta = candidate_value / control_value - 1
        deltas.append(delta)
        listed.append(f"{delta:+.4f}")
    head = [role, pipeline, column, str(replicates), str(len(deltas))]
    tail = [" ".join(listed), " ".join(controls), " ".join(candidates), str(bound)]
    if len(deltas) < 2:
        return head + ["-", "-", "-", "-"] + tail + ["incomplete", f"comparable_pairs={len(deltas)} of {replicates}"]
    mean, deviation, low, high = interval(deltas)
    verdict, detail = judge(role, low, high, bound)
    if len(deltas) < replicates:
        excluded = f"comparable_pairs={len(deltas)} of {replicates}"
        detail = excluded if detail == "-" else f"{detail} {excluded}"
    return head + [f"{mean:+.4f}", f"{deviation:.4f}", f"{low:+.4f}", f"{high:+.4f}"] + tail + [verdict, detail]


def identity_row(pairs, root, replicates):
    verdict = "held"
    details = []
    for index, (control, candidate) in enumerate(pairs, 1):
        control_reply = reply_identity(arm_directory(root, control))
        candidate_reply = reply_identity(arm_directory(root, candidate))
        if control_reply is None or candidate_reply is None:
            verdict = "unavailable"
            details.append(f"pair{index}=unavailable")
            continue
        if control_reply != candidate_reply:
            if verdict != "unavailable":
                verdict = "differs"
            details.append(f"pair{index}=differs")
        else:
            details.append(f"pair{index}=equal")
    return ["token_identity", "-", "content,predicted_n", str(replicates), str(len(pairs)),
            "-", "-", "-", "-", "-", "-", "-", "-", verdict, " ".join(details) or "-"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("arms")
    parser.add_argument("arms_directory")
    parser.add_argument("--subject", required=True)
    parser.add_argument("--null", required=True, dest="null_pipeline")
    parser.add_argument("--bound", type=float, default=0.02)
    parser.add_argument("--column", default="exclusive_bracket_ms")
    args = parser.parse_args()
    if args.bound <= 0:
        raise SystemExit("--bound must exceed zero")
    if args.subject == args.null_pipeline:
        raise SystemExit("the subject and the null pipeline must differ")
    arms = read_arms(args.arms)
    pairs = []
    for a, b, c, d in quadruples(arms):
        if (a["arm"], b["arm"]) != ("C", "K"):
            raise SystemExit(f"a kernel-delta ledger carries C K K C quadruples: {a['arm']} {b['arm']}")
        pairs.append((a, b))
        pairs.append((d, c))
    if not pairs:
        raise SystemExit("the arms ledger carries no C K K C quadruple")
    replicates = len(pairs)
    print("\t".join(COLUMNS))
    print("\t".join(pipeline_row("subject", args.subject, args.column, pairs, args.arms_directory, args.bound)))
    print("\t".join(pipeline_row("null", args.null_pipeline, args.column, pairs, args.arms_directory, args.bound)))
    print("\t".join(identity_row(pairs, args.arms_directory, replicates)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
