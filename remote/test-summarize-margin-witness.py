#!/usr/bin/env python3
"""summarize-margin-witness.py against synthetic witness directories."""
import os
import subprocess
import sys
import tempfile

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "summarize-margin-witness.py")


def write_sample(root, slot, arm, prompt_id, run, rows):
    directory = os.path.join(root, "arms", f"{slot}-{arm}", prompt_id)
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, f"tokens-run-{run}.tsv"), "w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(row + "\n")


def line(token, top):
    return f"{token}\t{top[0][1]:.9g}\t" + ";".join(f"{t}:{lp:.9g}" for t, lp in top)


def control_rows():
    return [
        line(10, [(10, -0.1), (11, -2.4), (12, -3.0)]),   # margin 2.3
        line(20, [(20, -0.5), (21, -1.0), (22, -4.0)]),   # margin 0.5
        line(30, [(30, -0.69), (31, -0.75), (32, -3.0)]),  # margin 0.06, near tie
    ]


def run(root, *extra):
    return subprocess.run([sys.executable, SCRIPT, root, "--top-k", "3", "--near-tie", "0.1",
                           "--retention", "0.5", *extra], capture_output=True, text=True)


def rows_of(output):
    lines = output.strip().split("\n")
    header = lines[0].split("\t")
    return [dict(zip(header, line.split("\t"))) for line in lines[1:]]


def quad(root, prompt_id, control, candidate):
    for slot, arm, rows in ((1, "C", control), (2, "K", candidate), (3, "K", candidate), (4, "C", control)):
        for run_index in (1, 2):
            write_sample(root, slot, arm, prompt_id, run_index, rows)


def case_held():
    with tempfile.TemporaryDirectory() as root:
        candidate = [
            line(10, [(10, -0.12), (11, -2.3), (12, -3.1)]),   # margin 2.18, ratio 0.95
            line(20, [(20, -0.55), (21, -0.9), (22, -4.0)]),   # margin 0.35, ratio 0.70
            line(30, [(30, -0.70), (31, -0.71), (32, -3.0)]),  # margin 0.01, near tie: counted
        ]
        quad(root, "p", control_rows(), candidate)
        result = run(root)
        assert result.returncode == 0, result.stderr
        rows = rows_of(result.stdout)
        cross = [r for r in rows if r["comparison"] == "candidate-vs-control"][0]
        assert cross["verdict"] == "held", cross
        assert cross["near_tie_positions"] == "4", cross      # one near tie per sample, four samples
        assert cross["retention_failures"] == "0", cross
        assert abs(float(cross["min_retention"]) - 0.7) < 1e-6, cross
        assert cross["positions"] == "12", cross
        assert float(cross["min_control_margin"]) == 0.06, cross
        assert float(cross["max_truncated_tv"]) > 0.0, cross
        assert rows[-1]["verdict"] == "held", rows[-1]
        selfs = [r for r in rows if r["comparison"].startswith("self-")]
        assert all(r["verdict"] == "held" and r["max_abs_logprob_delta"] == "0" for r in selfs), selfs


def case_retention_failure():
    with tempfile.TemporaryDirectory() as root:
        candidate = [
            line(10, [(10, -0.1), (11, -2.4), (12, -3.0)]),
            line(20, [(20, -0.7), (21, -0.9), (22, -4.0)]),   # margin 0.2, ratio 0.4 < 0.5
            line(30, [(30, -0.69), (31, -0.75), (32, -3.0)]),
        ]
        quad(root, "p", control_rows(), candidate)
        result = run(root)
        assert result.returncode == 0, result.stderr
        cross = [r for r in rows_of(result.stdout) if r["comparison"] == "candidate-vs-control"][0]
        assert cross["verdict"] == "differs" and cross["retention_failures"] == "4", cross
        assert cross["id_identity"] == "held", cross
        assert rows_of(result.stdout)[-1]["verdict"] == "differs"


def case_tie_and_divergence():
    with tempfile.TemporaryDirectory() as root:
        tie = [
            line(10, [(10, -0.1), (11, -2.4), (12, -3.0)]),
            line(20, [(20, -0.9), (21, -0.9), (22, -4.0)]),   # margin 0, nonpositive
            line(30, [(30, -0.69), (31, -0.75), (32, -3.0)]),
        ]
        quad(root, "tie", control_rows(), tie)
        diverged = [
            line(10, [(10, -0.1), (11, -2.4), (12, -3.0)]),
            line(21, [(21, -0.5), (20, -1.0), (22, -4.0)]),
            line(30, [(30, -0.69), (31, -0.75), (32, -3.0)]),
        ]
        quad(root, "div", control_rows(), diverged)
        result = run(root)
        assert result.returncode == 0, result.stderr
        rows = {(r["prompt"], r["comparison"]): r for r in rows_of(result.stdout)}
        tie_row = rows[("tie", "candidate-vs-control")]
        assert tie_row["verdict"] == "differs" and tie_row["nonpositive_candidate_margins"] == "4", tie_row
        div_row = rows[("div", "candidate-vs-control")]
        assert div_row["id_identity"] == "differs" and div_row["first_divergence"] == "1", div_row
        assert div_row["verdict"] == "differs", div_row


def case_self_inconsistency_and_unread():
    with tempfile.TemporaryDirectory() as root:
        control = control_rows()
        wobbling = control[:1] + [line(20, [(20, -0.50001), (21, -1.0), (22, -4.0)])] + control[2:]
        for slot, arm, rows in ((1, "C", control), (2, "K", control), (3, "K", control), (4, "C", control)):
            write_sample(root, slot, arm, "p", 1, rows)
            write_sample(root, slot, arm, "p", 2, wobbling if arm == "C" else rows)
        unread = control[:1] + ["20\t-\t-"] + control[2:]
        write_sample(root, 2, "K", "p", 2, unread)
        result = run(root)
        assert result.returncode == 0, result.stderr
        rows = {r["comparison"]: r for r in rows_of(result.stdout)}
        assert rows["self-C"]["verdict"] == "differs" and rows["self-C"]["id_identity"] == "held", rows["self-C"]
        assert rows["self-K"]["verdict"] == "held", rows["self-K"]
        cross = rows["candidate-vs-control"]
        assert cross["unread_positions"] == "1" and cross["positions"] == "11", cross
        assert cross["verdict"] == "held", cross
        assert rows["overall"]["verdict"] == "differs"


def case_refusals():
    with tempfile.TemporaryDirectory() as root:
        quad(root, "p", ["10\t-0.1", "20\t-0.5"], ["10\t-0.1", "20\t-0.5"])
        result = run(root)
        assert result.returncode != 0 and "carries id, logprob, and top-k" in result.stderr, result.stderr
    with tempfile.TemporaryDirectory() as root:
        bad = [line(10, [(11, -0.1), (10, -2.4), (12, -3.0)])]
        quad(root, "p", bad, bad)
        result = run(root)
        assert result.returncode != 0 and "opening on the selected token" in result.stderr, result.stderr
    with tempfile.TemporaryDirectory() as root:
        result = run(root)
        assert result.returncode != 0 and "no witness samples" in result.stderr, result.stderr
    with tempfile.TemporaryDirectory() as root:
        quad(root, "p", control_rows(), control_rows())
        result = subprocess.run([sys.executable, SCRIPT, root, "--top-k", "1", "--near-tie", "0.1",
                                 "--retention", "0.5"], capture_output=True, text=True)
        assert result.returncode != 0 and "at least 2" in result.stderr, result.stderr


def main():
    for case in (case_held, case_retention_failure, case_tie_and_divergence,
                 case_self_inconsistency_and_unread, case_refusals):
        case()
        print(f"ok {case.__name__}")


if __name__ == "__main__":
    main()
