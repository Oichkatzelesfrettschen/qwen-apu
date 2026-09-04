#!/usr/bin/env python3
"""Judge a kernel-delta comparison by one pipeline's GPU bracket.

usage: summarize-bracket-ab.py ARMS_TSV ARMS_DIRECTORY --subject PIPELINE
           --null PIPELINE [--bound F] [--witness DIRECTORY]

The arms ledger carries `C K K C` quadruples the way run-served-binary-ab.sh
writes them, and every completed arm's directory holds the decode ledger the
census summarizer wrote (`pipeline-ledger-decode.tsv`) and the reply the
served runner retained (`response.json`). For each pair (inner over outer) a
delta is the candidate's value over the control's minus one, so a quantity
the patch shortens reads negative, and Student's t over the paired deltas
gives the nominal 95% interval, as summarize-census-controls.py does for the
served rate. The rows, each read by its `role`:

    subject          exclusive_bracket_ms of the subject pipeline, the
                     preregistered primary: time uniquely attributable to it
    subject-union    pipeline_bracket_union_ms of the subject: the queue
                     interval it touches, overlap included. Exclusive and
                     union must move together; exclusive shortening while the
                     union holds names an overlap-accounting change rather
                     than a shorter execution envelope
    null             exclusive_bracket_ms of the null pipeline, which the
                     patch leaves untouched; overlap-sensitive by construction
    null-union       pipeline_bracket_union_ms of the null: the principal
                     unchanged-pipeline control, since a shorter subject
                     changes what its neighbours overlap without changing
                     the neighbours
    graph-span       queue_completion_span_ms_per_graph from the ledger's
                     graphs row: the whole submitted graph, the common-mode
                     reference every family moves with
    ratio            (subject / null) per arm, candidate over control minus
                     one: a secondary statistic that survives common-mode
                     movement and was not preregistered as primary
    module_identity  spirv_executed_sha256: every control arm executes one
                     subject module, every candidate arm one, the two differ,
                     and the null module is one digest across every arm
    response_identity  reply content and predicted_n, candidate against
                     control per pair. Two token sequences can share a
                     string, so this is the reply's identity and not the
                     token array's; run-kernel-delta-witness.sh reads the ids
    clock_state      the modal graphics and fabric clocks each arm's sidecar
                     recorded over its own request window, with the graphics
                     share beside them. A device timestamp duration scales
                     with the graphics clock, so this row states the execution
                     state every bracket above was measured at rather than
                     leaving it to the arms ledger
    token_identity   the generated token ids, candidate against control, from
                     the margin witness `--witness` names. A reply can carry
                     one string over two token arrays, so the ids are what the
                     equivalence claim is read on and they come from a
                     separate run
    margin_contract  that witness's own overall verdict: positive candidate
                     margins everywhere and the registered retention held
                     wherever the control's margin clears the near-tie floor

The three rows below the response identity report beside the paired bound and
decide nothing: the campaign's exit follows the bracket rows, the null, and the
two identity rows the arms themselves carry, so a witness directory absent from
an invocation leaves its two rows `unavailable` rather than failing the run.

A pair is read over the execution state and the attribution its two arms
shared, the way summarize-census-controls.py reads a served pair. Two modal
selected graphics clocks farther apart than `--sclk-band` measure the governor
step between them, since a device timestamp duration scales with the clock, so
that pair is listed `state-changed` and stays outside the mean and the
interval while the row still reads a verdict over the pairs that held one
state. An arm whose `ownership` column reads anything but `conclusive` or the
unknown `-` carries exclusive time the census refuses to attribute to one
pipeline, and a pair whose ledger row for the named pipeline is absent or
non-positive was measured and not reported: either leaves a completed pair
unread, so the row states `incomplete` rather than a verdict issued from the
pairs that survived.

Verdicts on a bracket row: `shortened` where the whole interval sits below
-bound, `lengthened` above +bound, `unchanged` inside [-bound, +bound],
`unresolved` where it crosses a bound; on a null row `held` inside the bound
and `state-changed` otherwise; on an identity row `held`, `differs`, or
`unavailable`. Every row states its per-arm values so a reader can recompute
the delta from the retained ledgers rather than trust the mean.
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
UNKNOWN_STATE = "-"
# The band summarize-census-controls.py holds a served pair to: the appliance's
# sustained regime spreads its selected clock over about 3% and its boost
# regime sits 27% above it, so 0.06 holds one regime together and keeps the two
# apart.
DEFAULT_SCLK_BAND = 0.06
EXCLUSIVE = "exclusive_bracket_ms"
UNION = "pipeline_bracket_union_ms"
DIGEST = "spirv_executed_sha256"
SPAN = "queue_completion_span_ms_per_graph"
WITNESS_SUMMARY = "margin-summary.tsv"
WITNESS_COMPARISON = "candidate-vs-control"


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


def read_ledger(directory):
    """The pipeline rows by name and the graphs row's key=value fields."""
    path = os.path.join(directory, "pipeline-ledger-decode.tsv")
    try:
        with open(path) as handle:
            lines = [line.rstrip("\n") for line in handle if line.strip()]
    except OSError:
        return None
    header = None
    pipelines = {}
    graphs = {}
    for line in lines:
        fields = line.split("\t")
        if fields[0] == "graphs":
            for field in fields[3:]:
                if "=" in field:
                    key, value = field.split("=", 1)
                    graphs[key] = value
            continue
        if fields[0] == "pipeline" and fields[1] == "id":
            header = fields
            continue
        if header and fields[0] == "pipeline":
            record = dict(zip(header, fields))
            pipelines.setdefault(record.get("name"), []).append(record)
    if header is None:
        return None
    return pipelines, graphs


def pipeline_value(ledger, pipeline, column):
    if ledger is None:
        return None
    records = ledger[0].get(pipeline, [])
    if len(records) != 1 or column not in records[0]:
        return None
    try:
        return float(records[0][column])
    except ValueError:
        return None


def graph_value(ledger, key):
    if ledger is None or key not in ledger[1]:
        return None
    try:
        return float(ledger[1][key])
    except ValueError:
        return None


def pipeline_digest(ledger, pipeline):
    if ledger is None:
        return None
    records = ledger[0].get(pipeline, [])
    if len(records) != 1:
        return None
    return records[0].get(DIGEST) or None


def reply_identity(directory):
    try:
        with open(os.path.join(directory, "response.json")) as handle:
            reply = json.load(handle)
        content = reply["choices"][0]["message"]["content"]
        predicted = reply.get("timings", {}).get("predicted_n")
    except (OSError, ValueError, KeyError, IndexError, TypeError):
        return None
    return (content, predicted)


def one_clock_state(control, candidate, band):
    """Whether a pair's two arms held one selected graphics clock regime.

    An unknown mode takes whatever state its partner held, so the test refuses
    a pair only where both arms name a state and the two lie further apart than
    the band, relative to the larger of the two. A mode that parses as no
    number at all states a reading the ledger cannot be judged over and is
    refused rather than read as unknown.
    """
    first_text = control.get("sclk_mode_mhz", UNKNOWN_STATE)
    second_text = candidate.get("sclk_mode_mhz", UNKNOWN_STATE)
    if first_text == UNKNOWN_STATE or second_text == UNKNOWN_STATE:
        return True
    try:
        first, second = float(first_text), float(second_text)
    except ValueError:
        return False
    if first <= 0 or second <= 0:
        return False
    return abs(first - second) / max(first, second) <= band


def pair_state(control, candidate, band):
    """The listing a pair carries instead of a delta, or the empty string.

    `state-changed` names a governor step between the two arms and leaves the
    row's verdict standing over the pairs that held one state.
    `ownership-inconclusive` names exclusive time the census declined to
    attribute to one pipeline, which a verdict cannot be issued over.
    """
    for row in (control, candidate):
        if row["status"] not in COMPLETED_STATUS:
            continue
        ownership = row.get("ownership", UNKNOWN_STATE) or UNKNOWN_STATE
        if ownership not in ("conclusive", UNKNOWN_STATE):
            return "ownership-inconclusive"
    if not one_clock_state(control, candidate, band):
        return "state-changed"
    return ""


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


def judge(kind, low, high, bound):
    inside = -bound <= low and high <= bound
    if kind == "null":
        return ("held", "-") if inside else ("state-changed", f"ci=[{low:+.4f},{high:+.4f}] outside bound={bound}")
    if kind == "secondary":
        return "reported", f"ci=[{low:+.4f},{high:+.4f}] secondary"
    if high < -bound:
        return "shortened", f"ci=[{low:+.4f},{high:+.4f}] below -bound={bound}"
    if low > bound:
        return "lengthened", f"ci=[{low:+.4f},{high:+.4f}] above bound={bound}"
    if inside:
        return "unchanged", f"ci=[{low:+.4f},{high:+.4f}] inside bound={bound}"
    return "unresolved", f"ci=[{low:+.4f},{high:+.4f}] crosses bound={bound}"


def delta_row(role, pipeline, column, kind, pairs, values, bound, states):
    """One statistics row over per-pair (control, candidate) values."""
    deltas = []
    listed = []
    controls = []
    candidates = []
    # Completed pairs the row could not read: a ledger row absent or
    # non-positive, and an attribution the census left inconclusive. Each is a
    # measurement the design registered and the row cannot show, so the verdict
    # states incomplete rather than reporting the pairs that survived.
    unread = 0
    replicates = len(pairs)
    for (control, candidate), (control_value, candidate_value), state in \
            zip(pairs, values, states):
        both = (control["status"] in COMPLETED_STATUS and candidate["status"] in COMPLETED_STATUS)
        controls.append("-" if control_value is None else f"{control_value:.4f}")
        candidates.append("-" if candidate_value is None else f"{candidate_value:.4f}")
        if not both:
            listed.append("arm-failed")
            continue
        if state == "state-changed":
            listed.append(state)
            continue
        if state:
            listed.append(state)
            unread += 1
            continue
        if control_value is None or candidate_value is None or control_value <= 0:
            listed.append("ledger-missing")
            unread += 1
            continue
        delta = candidate_value / control_value - 1
        deltas.append(delta)
        listed.append(f"{delta:+.4f}")
    head = [role, pipeline, column, str(replicates), str(len(deltas))]
    tail = [" ".join(listed), " ".join(controls), " ".join(candidates), str(bound)]
    if len(deltas) < 2 or unread:
        return head + ["-", "-", "-", "-"] + tail + ["incomplete", f"comparable_pairs={len(deltas)} of {replicates}"]
    mean, deviation, low, high = interval(deltas)
    verdict, detail = judge(kind, low, high, bound)
    if len(deltas) < replicates:
        excluded = f"comparable_pairs={len(deltas)} of {replicates}"
        detail = excluded if detail == "-" else f"{detail} {excluded}"
    return head + [f"{mean:+.4f}", f"{deviation:.4f}", f"{low:+.4f}", f"{high:+.4f}"] + tail + [verdict, detail]


def module_row(pairs, ledgers, subject, null_pipeline):
    control_subject = set()
    candidate_subject = set()
    null_digests = set()
    missing = 0
    for control, candidate in pairs:
        for row, bucket in ((control, control_subject), (candidate, candidate_subject)):
            if row["status"] not in COMPLETED_STATUS:
                continue
            ledger = ledgers[row["slot"], row["arm"]]
            subject_digest = pipeline_digest(ledger, subject)
            null_digest = pipeline_digest(ledger, null_pipeline)
            if subject_digest is None or null_digest is None:
                missing += 1
                continue
            bucket.add(subject_digest)
            null_digests.add(null_digest)
    if missing or not control_subject or not candidate_subject:
        verdict, detail = "unavailable", f"arms_without_digest={missing}"
    elif len(control_subject) == 1 and len(candidate_subject) == 1 \
            and control_subject != candidate_subject and len(null_digests) == 1:
        verdict, detail = "held", "-"
    else:
        verdict = "differs"
        detail = (f"control_subject={len(control_subject)} candidate_subject={len(candidate_subject)}"
                  f" null={len(null_digests)} same_subject={control_subject == candidate_subject}")
    return ["module_identity", subject, DIGEST, str(len(pairs)), str(len(pairs)),
            "-", "-", "-", "-", "-",
            " ".join(sorted(control_subject)) or "-", " ".join(sorted(candidate_subject)) or "-",
            "-", verdict, f"{detail} null_module={' '.join(sorted(null_digests)) or '-'}"]


def response_row(pairs, root):
    verdict = "held"
    details = []
    compared = 0
    for index, (control, candidate) in enumerate(pairs, 1):
        control_reply = reply_identity(arm_directory(root, control))
        candidate_reply = reply_identity(arm_directory(root, candidate))
        if control_reply is None or candidate_reply is None:
            verdict = "unavailable"
            details.append(f"pair{index}=unavailable")
            continue
        compared += 1
        if control_reply != candidate_reply:
            if verdict != "unavailable":
                verdict = "differs"
            details.append(f"pair{index}=differs")
        else:
            details.append(f"pair{index}=equal")
    return ["response_identity", "-", "content,predicted_n", str(len(pairs)), str(compared),
            "-", "-", "-", "-", "-", "-", "-", "-", verdict, " ".join(details) or "-"]


def clock_row(pairs):
    """The execution state each arm's request window ran at, reported.

    The sidecar validator prints one `clock_state=measured` line per arm and
    run-served-binary-ab.sh carries its modal graphics clock, that mode's
    share, and its modal fabric clock into the arms ledger. A bracket is a
    device timestamp duration and scales with the graphics clock, so the state
    belongs beside every row above; the pair comparability test one_clock_state
    already refuses a pair that straddled a graphics step, which is why this
    row states values rather than a bound.
    """
    controls, candidates = [], []
    shares = []
    fabric = set()
    unread = 0
    # comparable_pairs is a pair count in every row of this table, so a pair
    # counts here only where both of its arms carried a readable state.
    readable_pairs = 0
    for control, candidate in pairs:
        pair_readable = True
        for row, bucket in ((control, controls), (candidate, candidates)):
            sclk = row.get("sclk_mode_mhz", UNKNOWN_STATE) or UNKNOWN_STATE
            share = row.get("sclk_share", UNKNOWN_STATE) or UNKNOWN_STATE
            mclk = row.get("mclk_mode_mhz", UNKNOWN_STATE) or UNKNOWN_STATE
            bucket.append(f"{sclk}/{share}/{mclk}")
            if sclk == UNKNOWN_STATE or mclk == UNKNOWN_STATE:
                unread += 1
                pair_readable = False
                continue
            fabric.add(mclk)
            try:
                shares.append(float(share))
            except ValueError:
                unread += 1
                pair_readable = False
        if pair_readable:
            readable_pairs += 1
    if unread or not shares:
        verdict, detail = "unavailable", f"arms_without_clock_state={unread}"
    else:
        verdict = "measured"
        detail = (f"min_sclk_share={min(shares):.4f} fclk_modes={' '.join(sorted(fabric))}"
                  f" arms={len(shares)}")
    return ["clock_state", "-", "sclk_mode_mhz/sclk_share/mclk_mode_mhz",
            str(len(pairs)), str(readable_pairs), "-", "-", "-", "-", "-",
            " ".join(controls), " ".join(candidates), "-", verdict, detail]


def read_witness(directory):
    """The margin witness's per-prompt rows and its overall verdict."""
    path = os.path.join(directory, WITNESS_SUMMARY)
    try:
        with open(path) as handle:
            rows = list(csv.DictReader(handle, delimiter="\t"))
    except OSError:
        return None
    if not rows or "comparison" not in rows[0] or "verdict" not in rows[0]:
        return None
    return rows


def witness_rows(directory):
    """Token identity and the margin contract, each from the witness run.

    The witness is its own campaign over its own prompts, so both rows carry
    the directory they were read from: a summary that implied these arms
    generated the ids would attribute one run's evidence to another.
    """
    head_identity = ["token_identity", "-", "id_identity"]
    head_margin = ["margin_contract", "-", "verdict"]
    if directory is None:
        blank = ["-"] * 9 + ["-", "unavailable", "no --witness directory"]
        return [head_identity + blank, head_margin + blank]
    rows = read_witness(directory)
    if rows is None:
        blank = ["-"] * 9 + ["-", "unavailable", f"witness={directory} unreadable"]
        return [head_identity + blank, head_margin + blank]
    compared = [row for row in rows if row["comparison"] == WITNESS_COMPARISON]
    identities = {row.get("id_identity", UNKNOWN_STATE) for row in compared}
    overall = [row["verdict"] for row in rows if row["comparison"] == "overall"]
    if not compared or identities != {"held"}:
        identity_verdict = "differs" if compared else "unavailable"
        identity_detail = f"prompts={len(compared)} id_identity={' '.join(sorted(identities)) or '-'}"
    else:
        identity_verdict, identity_detail = "held", f"prompts={len(compared)}"
    if len(overall) != 1:
        margin_verdict, margin_detail = "unavailable", f"overall_rows={len(overall)}"
    else:
        margin_verdict = overall[0]
        margin_detail = f"prompts={len(compared)}"
    identity_row = head_identity + [str(len(compared)), str(len(compared))] + ["-"] * 8 + \
        [identity_verdict, f"{identity_detail} witness={directory}"]
    margin_row = head_margin + [str(len(compared)), str(len(compared))] + ["-"] * 8 + \
        [margin_verdict, f"{margin_detail} witness={directory}"]
    return [identity_row, margin_row]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("arms")
    parser.add_argument("arms_directory")
    parser.add_argument("--subject", required=True)
    parser.add_argument("--null", required=True, dest="null_pipeline")
    parser.add_argument("--bound", type=float, default=0.02)
    parser.add_argument("--sclk-band", type=float, default=DEFAULT_SCLK_BAND)
    parser.add_argument("--witness", help="a run-kernel-delta-witness.sh output directory")
    args = parser.parse_args()
    if args.bound <= 0:
        raise SystemExit("--bound must exceed zero")
    if args.sclk_band < 0:
        raise SystemExit("--sclk-band is a nonnegative relative distance")
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
    states = [pair_state(control, candidate, args.sclk_band) for control, candidate in pairs]
    ledgers = {}
    for control, candidate in pairs:
        for row in (control, candidate):
            key = (row["slot"], row["arm"])
            if key not in ledgers:
                ledgers[key] = read_ledger(arm_directory(args.arms_directory, row)) \
                    if row["status"] in COMPLETED_STATUS else None

    def values(function):
        return [(function(ledgers[control["slot"], control["arm"]]),
                 function(ledgers[candidate["slot"], candidate["arm"]]))
                for control, candidate in pairs]

    def ratio(ledger):
        subject_value = pipeline_value(ledger, args.subject, EXCLUSIVE)
        null_value = pipeline_value(ledger, args.null_pipeline, EXCLUSIVE)
        if subject_value is None or null_value is None or null_value <= 0:
            return None
        return subject_value / null_value

    subject, null_pipeline, bound = args.subject, args.null_pipeline, args.bound
    print("\t".join(COLUMNS))
    rows = [
        delta_row("subject", subject, EXCLUSIVE, "subject", pairs,
                  values(lambda ledger: pipeline_value(ledger, subject, EXCLUSIVE)), bound, states),
        delta_row("subject-union", subject, UNION, "subject", pairs,
                  values(lambda ledger: pipeline_value(ledger, subject, UNION)), bound, states),
        delta_row("null", null_pipeline, EXCLUSIVE, "null", pairs,
                  values(lambda ledger: pipeline_value(ledger, null_pipeline, EXCLUSIVE)), bound, states),
        delta_row("null-union", null_pipeline, UNION, "null", pairs,
                  values(lambda ledger: pipeline_value(ledger, null_pipeline, UNION)), bound, states),
        delta_row("graph-span", "-", SPAN, "secondary", pairs,
                  values(lambda ledger: graph_value(ledger, SPAN)), bound, states),
        delta_row("ratio", f"{subject}/{null_pipeline}", EXCLUSIVE, "secondary", pairs,
                  values(ratio), bound, states),
        module_row(pairs, ledgers, subject, null_pipeline),
        response_row(pairs, args.arms_directory),
        clock_row(pairs),
    ] + witness_rows(args.witness)
    for row in rows:
        print("\t".join(row))
    return 0


if __name__ == "__main__":
    sys.exit(main())
