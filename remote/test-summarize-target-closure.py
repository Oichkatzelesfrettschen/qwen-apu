#!/usr/bin/env python3
"""Drive summarize-target-closure.py over synthetic C K K C arm ledgers."""

import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SUMMARIZER = os.path.join(HERE, "summarize-target-closure.py")
HEADER = ("slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar"
          "\townership\tstatus\tsclk_mode_mhz\tsclk_share\tregime_delta\tclock_invariant"
          "\tbelow_required_fraction")


def ledger(path, arms):
    """arms: (slot, arm, tok_s, status, clock_invariant) rows."""
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(HEADER + "\n")
        for slot, arm, rate, status, held in arms:
            handle.write(f"{slot}\t{arm}\tdigest\t64\t6400\t{rate}\t0\tok\t-\t{status}\t1100"
                         f"\t1.0\t0\t{held}\t0\n")


def run(path, *extra):
    completed = subprocess.run(
        [sys.executable, SUMMARIZER, path, "--target", "10", *extra],
        capture_output=True, text=True, check=False)
    rows = [line.split("\t") for line in completed.stdout.splitlines()[1:]]
    return completed.returncode, {row[0]: row for row in rows}, completed.stderr


def quadruples(candidates, controls):
    rows = []
    slot = 1
    for pair, (k1, k2) in enumerate(zip(candidates[0::2], candidates[1::2])):
        c1, c2 = controls[2 * pair], controls[2 * pair + 1]
        for arm, rate in (("C", c1), ("K", k1), ("K", k2), ("C", c2)):
            rows.append((str(slot), arm, rate, "completed", "held"))
            slot += 1
    return rows


def main():
    failures = []

    def check(name, condition):
        print(("ok " if condition else "FAIL ") + name)
        if not condition:
            failures.append(name)

    with tempfile.TemporaryDirectory() as root:
        path = os.path.join(root, "arms.tsv")

        # The retained composed run: four candidate arms above 10, all four
        # controls below; the interval sits whole above the target.
        ledger(path, quadruples(["10.028", "10.017", "10.011", "10.022"],
                                ["9.848", "9.821", "9.845", "9.842"]))
        status, rows, _ = run(path)
        check("retained_shape_closes", status == 0 and rows["candidate"][9] == "closed")
        check("candidate_interval_above_target",
              float(rows["candidate"][6]) > 10 and float(rows["candidate"][2]) == 4)
        check("control_is_context", rows["control"][9] == "context")

        # Candidate straddling the target: interval spans it.
        ledger(path, quadruples(["10.05", "9.97", "10.02", "9.99"],
                                ["9.8", "9.8", "9.8", "9.8"]))
        status, rows, _ = run(path)
        check("straddle_is_unresolved", status == 5 and rows["candidate"][9] == "unresolved")

        # Candidate below: refuted.
        ledger(path, quadruples(["9.90", "9.91", "9.89", "9.92"],
                                ["9.8", "9.8", "9.8", "9.8"]))
        status, rows, _ = run(path)
        check("below_is_refuted", status == 3 and rows["candidate"][9] == "refuted")

        # One failed candidate arm: the verdict is incomplete, not the interval
        # over the three that finished.
        arms = quadruples(["10.03", "10.02", "10.01", "10.02"], ["9.8"] * 4)
        arms[2] = (arms[2][0], "K", "10.02", "failed", "held")
        ledger(path, arms)
        status, rows, _ = run(path)
        check("failed_arm_is_incomplete",
              status == 4 and rows["candidate"][9] == "incomplete"
              and "3:failed/held" in rows["candidate"][10])

        # A clock-violated candidate arm is dropped the same way.
        arms = quadruples(["10.03", "10.02", "10.01", "10.02"], ["9.8"] * 4)
        arms[6] = (arms[6][0], "K", "10.01", "completed", "violated")
        ledger(path, arms)
        status, rows, _ = run(path)
        check("clock_violation_is_incomplete", status == 4 and "7:completed/violated" in rows["candidate"][10])

        # Fewer than --min-arms candidate arms: incomplete.
        ledger(path, quadruples(["10.03", "10.02"], ["9.8", "9.8"]))
        status, rows, _ = run(path)
        check("two_arms_are_incomplete", status == 4 and "completed=2 min_arms=4" in rows["candidate"][10])
        status, rows, _ = run(path, "--min-arms", "2")
        check("two_arms_admitted_when_asked", status in (0, 3, 5) and rows["candidate"][2] == "2")

        # The auto policy records `-` for the invariant and still enters.
        ledger(path, [(row[0], row[1], row[2], row[3], "-") for row in
                      quadruples(["10.03", "10.02", "10.01", "10.02"], ["9.8"] * 4)])
        status, rows, _ = run(path)
        check("auto_policy_dash_enters", status == 0 and rows["candidate"][2] == "4")

        # A ledger without the columns refuses.
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("slot\tarm\n1\tK\n")
        status, _, stderr = run(path)
        check("missing_columns_refuse", status not in (0, 3, 4, 5) and "lacks" in stderr)

    if failures:
        print(f"{len(failures)} failure(s): {' '.join(failures)}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
