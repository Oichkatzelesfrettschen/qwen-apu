#!/usr/bin/env python3
"""Judge a kernel-delta witness on decision margins rather than on one bound.

The witness records, at every generated position, the token the server
selected and the top-k log-probabilities it selected it from. The selected
token's log-probability alone says how sure the model was and nothing about
how close the runner-up came, so a candidate that keeps every argmax while
narrowing the gap to a hair would pass an identity check and fail the next
prompt. This reader computes, per position, the winner's margin over the
runner-up in the control and in the candidate:

    m0 = lp0(w) - max(lp0(j) for j != w)
    m1 = lp1(w) - max(lp1(j) for j != w)

Both are log-probability differences of one distribution, so the softmax
normalizer cancels and each equals the logit margin. The contract is:

    token id          identical at every position, every sample
    self-repeatability exact within each binary (ids and top-k lists)
    candidate margin  positive at every position
    retention         m1 / m0 >= RETENTION wherever m0 >= NEAR_TIE
    near ties         positions with m0 < NEAR_TIE are counted, not judged
                      by ratio, since a ratio over a vanishing margin
                      measures nothing

The truncated total variation over the union of both top-k lists, with the
remaining mass as one bucket each, is reported as a lower bound on the
distance between the two distributions and decides nothing.

usage: summarize-margin-witness.py OUTPUT_DIR --top-k K --near-tie NAT --retention FRACTION
"""
import argparse
import glob
import math
import os
import sys

COLUMNS = [
    "prompt", "comparison", "samples", "id_identity", "first_divergence", "positions",
    "unread_positions", "near_tie_positions", "min_control_margin", "min_candidate_margin",
    "min_retention", "retention_failures", "nonpositive_candidate_margins",
    "max_truncated_tv", "max_abs_logprob_delta", "verdict",
]


def read_sample(path, top_count):
    ids, logprobs, tops = [], [], []
    with open(path, encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 3:
                raise SystemExit(f"{path}:{line_number}: a margin witness line carries id, logprob, and top-k;"
                                 f" this one carries {len(fields)} fields")
            ids.append(int(fields[0]))
            if fields[1] == "-":
                logprobs.append(None)
                tops.append(None)
                continue
            logprobs.append(float(fields[1]))
            entries = []
            for pair in fields[2].split(";"):
                token, logprob = pair.split(":")
                entries.append((int(token), float(logprob)))
            if len(entries) < top_count or entries[0][0] != ids[-1]:
                raise SystemExit(f"{path}:{line_number}: top-k list must hold {top_count} entries"
                                 f" opening on the selected token {ids[-1]}")
            tops.append(entries)
    if not ids:
        raise SystemExit(f"{path}: empty sample")
    return ids, logprobs, tops


def margin(entries):
    winner = entries[0][1]
    runner_up = max(logprob for _, logprob in entries[1:])
    return winner - runner_up


def truncated_tv(control_entries, candidate_entries):
    control = {token: math.exp(logprob) for token, logprob in control_entries}
    candidate = {token: math.exp(logprob) for token, logprob in candidate_entries}
    union = set(control) | set(candidate)
    total = sum(abs(control.get(token, 0.0) - candidate.get(token, 0.0)) for token in union)
    total += abs((1.0 - sum(control.values())) - (1.0 - sum(candidate.values())))
    return 0.5 * total


def first_divergence(ids, reference):
    shortest = min(len(ids), len(reference))
    for index in range(shortest):
        if ids[index] != reference[index]:
            return str(index)
    return str(shortest) if len(ids) != len(reference) else "-"


def fmt(value):
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.6g}"
    return str(value)


def self_row(prompt_id, arm, samples):
    reference = samples[0]
    identity, divergence, delta = "held", "-", 0.0
    for ids, logprobs, tops in samples:
        if ids != reference[0]:
            identity = "differs"
            divergence = first_divergence(ids, reference[0])
            continue
        for index in range(len(ids)):
            a, b = logprobs[index], reference[1][index]
            if a is None or b is None:
                continue
            delta = max(delta, abs(a - b))
            if tops[index] != reference[2][index]:
                delta = max(delta, max(abs(x[1] - y[1]) for x, y in zip(tops[index], reference[2][index])))
    verdict = "held" if identity == "held" and delta == 0.0 else "differs"
    row = {column: "-" for column in COLUMNS}
    row.update({"prompt": prompt_id, "comparison": f"self-{arm}", "samples": len(samples),
                "id_identity": identity, "first_divergence": divergence,
                "positions": len(reference[0]), "max_abs_logprob_delta": delta, "verdict": verdict})
    return row


def cross_row(prompt_id, reference, samples, near_tie, retention):
    ref_ids, ref_logprobs, ref_tops = reference
    identity, divergence = "held", "-"
    positions = unread = near_ties = failures = nonpositive = 0
    min_m0 = min_m1 = min_ratio = None
    max_tv = max_delta = 0.0
    for ids, logprobs, tops in samples:
        if ids != ref_ids:
            identity = "differs"
            divergence = first_divergence(ids, ref_ids)
            continue
        for index in range(len(ids)):
            if tops[index] is None or ref_tops[index] is None:
                unread += 1
                continue
            positions += 1
            m0, m1 = margin(ref_tops[index]), margin(tops[index])
            min_m0 = m0 if min_m0 is None else min(min_m0, m0)
            min_m1 = m1 if min_m1 is None else min(min_m1, m1)
            if m1 <= 0.0:
                nonpositive += 1
            if m0 < near_tie:
                near_ties += 1
            else:
                ratio = m1 / m0
                min_ratio = ratio if min_ratio is None else min(min_ratio, ratio)
                if ratio < retention:
                    failures += 1
            max_tv = max(max_tv, truncated_tv(ref_tops[index], tops[index]))
            max_delta = max(max_delta, abs(logprobs[index] - ref_logprobs[index]))
    if identity != "held":
        verdict = "differs"
    elif positions == 0:
        verdict = "incomplete"
    elif nonpositive or failures:
        verdict = "differs"
    else:
        verdict = "held"
    return {"prompt": prompt_id, "comparison": "candidate-vs-control", "samples": len(samples),
            "id_identity": identity, "first_divergence": divergence, "positions": positions,
            "unread_positions": unread, "near_tie_positions": near_ties,
            "min_control_margin": min_m0, "min_candidate_margin": min_m1, "min_retention": min_ratio,
            "retention_failures": failures, "nonpositive_candidate_margins": nonpositive,
            "max_truncated_tv": max_tv, "max_abs_logprob_delta": max_delta, "verdict": verdict}


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("output_directory")
    parser.add_argument("--top-k", type=int, required=True)
    parser.add_argument("--near-tie", type=float, required=True)
    parser.add_argument("--retention", type=float, required=True)
    args = parser.parse_args()
    if args.top_k < 2:
        raise SystemExit("--top-k is at least 2, since a margin needs a runner-up")
    if not 0.0 < args.retention <= 1.0 or args.near_tie < 0.0:
        raise SystemExit("--retention lies in (0, 1] and --near-tie is nonnegative")

    prompts = {}
    pattern = os.path.join(args.output_directory, "arms", "*", "*", "tokens-run-*.tsv")
    for path in sorted(glob.glob(pattern)):
        arm_directory, prompt_id, name = path.split(os.sep)[-3:]
        slot, arm = arm_directory.split("-", 1)
        if arm not in ("C", "K"):
            raise SystemExit(f"{path}: arm directory names C or K")
        run = int(name[len("tokens-run-"):-len(".tsv")])
        prompts.setdefault(prompt_id, []).append((int(slot), run, arm, read_sample(path, args.top_k)))
    if not prompts:
        raise SystemExit(f"no witness samples under {pattern}")

    print("\t".join(COLUMNS))
    overall = "held"
    for prompt_id, entries in sorted(prompts.items()):
        entries.sort(key=lambda item: (item[0], item[1]))
        by_arm = {"C": [], "K": []}
        for _, _, arm, sample in entries:
            by_arm[arm].append(sample)
        rows = []
        for arm in ("C", "K"):
            if not by_arm[arm]:
                raise SystemExit(f"{prompt_id}: no {arm} samples")
            rows.append(self_row(prompt_id, arm, by_arm[arm]))
        rows.append(cross_row(prompt_id, by_arm["C"][0], by_arm["K"], args.near_tie, args.retention))
        for row in rows:
            if row["verdict"] != "held":
                overall = "differs"
            print("\t".join(fmt(row[column]) for column in COLUMNS))
    tail = {column: "-" for column in COLUMNS}
    tail.update({"comparison": "overall", "verdict": overall})
    print("\t".join(fmt(tail[column]) for column in COLUMNS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
