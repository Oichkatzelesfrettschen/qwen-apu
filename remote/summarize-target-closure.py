#!/usr/bin/env python3
"""The target-closure verdict over one served A/B ledger.

summarize-census-controls.py answers whether a candidate is faster than its
control by a paired bound. This script answers the other question a serving
target asks: whether the candidate's own absolute rate clears the target,
read from the same C K K C ledger in the same sweep. The statistic is the
lower endpoint of the nominal two-sided 95% t interval over the candidate
arms' `tok_s`, the interval summarize-census-controls.py already applies to
paired deltas, so the closure verdict adds no statistic the paired verdict
does not already carry.

    closed      the whole interval lies above the target
    refuted     the whole interval lies below the target
    unresolved  the interval spans the target

An arm enters the interval only where its `status` reads completed and its
`clock_invariant` reads held or `-` (the auto policy records none). Every
registered candidate arm must be complete: a failed or clock-violated
candidate arm makes the verdict `incomplete` rather than narrowing the sample
to the arms that happened to finish, since a dropped slow arm would move the
bound in the direction the verdict rewards. Fewer than --min-arms completed
arms is `incomplete` for the same reason. The control arms are summarized
beside the candidate as context and decide nothing here.

usage: summarize-target-closure.py ARMS_TSV --target TOK_S
           [--candidate-arm K] [--control-arm C] [--min-arms 4]
"""

import argparse
import csv
import math
import sys

T_95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365}
HELD = frozenset({"held", "-"})


def interval(values):
    """Mean, sample standard deviation, and the nominal 95% t interval."""
    count = len(values)
    degrees = count - 1
    if degrees not in T_95:
        raise SystemExit(f"the t table covers 2 through 8 arms; the ledger holds {count}")
    mean = sum(values) / count
    variance = sum((value - mean) ** 2 for value in values) / degrees
    deviation = math.sqrt(variance)
    half_width = T_95[degrees] * deviation / math.sqrt(count)
    return mean, deviation, mean - half_width, mean + half_width


def read_arms(path):
    with open(path, newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    required = {"slot", "arm", "tok_s", "status", "clock_invariant"}
    if not rows or not required <= set(rows[0]):
        raise SystemExit(f"{path}: arms ledger lacks one of {sorted(required)}")
    return rows


def arm_rates(rows, arm):
    """Rates of the completed arms, and the slots of the arms that are not."""
    rates, incomplete = [], []
    for row in rows:
        if row["arm"] != arm:
            continue
        if row["status"] != "completed" or row["clock_invariant"] not in HELD:
            incomplete.append(f"{row['slot']}:{row['status']}/{row['clock_invariant']}")
            continue
        try:
            rates.append(float(row["tok_s"]))
        except ValueError:
            incomplete.append(f"{row['slot']}:tok_s={row['tok_s']}")
    return rates, incomplete


def verdict(low, high, target):
    if low > target:
        return "closed", f"ci_low={low:.4f} above target={target}"
    if high < target:
        return "refuted", f"ci_high={high:.4f} below target={target}"
    return "unresolved", f"ci=[{low:.4f},{high:.4f}] spans target={target}"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("arms_tsv")
    parser.add_argument("--target", type=float, required=True, help="tok/s the candidate must clear")
    parser.add_argument("--candidate-arm", default="K")
    parser.add_argument("--control-arm", default="C")
    parser.add_argument("--min-arms", type=int, default=4)
    args = parser.parse_args()
    if args.target <= 0:
        raise SystemExit("--target is a positive tok/s")

    rows = read_arms(args.arms_tsv)
    candidate, candidate_incomplete = arm_rates(rows, args.candidate_arm)
    control, control_incomplete = arm_rates(rows, args.control_arm)

    print("role\tarm\tarms\tincomplete\tmean\tsd\tci_low\tci_high\ttarget\tverdict\tdetail")
    if candidate_incomplete or len(candidate) < args.min_arms:
        detail = (f"incomplete_arms={','.join(candidate_incomplete) or '-'}"
                  f" completed={len(candidate)} min_arms={args.min_arms}")
        print(f"candidate\t{args.candidate_arm}\t{len(candidate)}\t{len(candidate_incomplete)}"
              f"\t-\t-\t-\t-\t{args.target}\tincomplete\t{detail}")
        return 4
    mean, deviation, low, high = interval(candidate)
    state, detail = verdict(low, high, args.target)
    print(f"candidate\t{args.candidate_arm}\t{len(candidate)}\t0\t{mean:.4f}\t{deviation:.4f}"
          f"\t{low:.4f}\t{high:.4f}\t{args.target}\t{state}\t{detail}")
    if len(control) >= 2 and not control_incomplete:
        c_mean, c_deviation, c_low, c_high = interval(control)
        print(f"control\t{args.control_arm}\t{len(control)}\t0\t{c_mean:.4f}\t{c_deviation:.4f}"
              f"\t{c_low:.4f}\t{c_high:.4f}\t{args.target}\tcontext\t-")
    else:
        print(f"control\t{args.control_arm}\t{len(control)}\t{len(control_incomplete)}"
              f"\t-\t-\t-\t-\t{args.target}\tcontext\t"
              f"incomplete_arms={','.join(control_incomplete) or '-'}")
    return {"closed": 0, "refuted": 3, "unresolved": 5}[state]


if __name__ == "__main__":
    sys.exit(main())
