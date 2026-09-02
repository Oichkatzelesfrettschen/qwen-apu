#!/usr/bin/env python3
"""Drive summarize-bracket-ab.py over synthetic arms and decode ledgers.

Each case writes an arms ledger in the C K K C shape, one decode ledger per
arm carrying a subject and a null pipeline row, and one reply per arm, then
reads the verdict rows by name.
"""

import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SUMMARIZER = os.path.join(HERE, "summarize-bracket-ab.py")
LEDGER_HEADER = ("pipeline\tid\tname\tconstants\twg_denoms\tsubgroup\tcalls_per_graph"
                 "\tworkgroups_per_graph\ttotal_bracket_upper_bound_ms\tpipeline_bracket_union_ms"
                 "\texclusive_bracket_ms\tambiguous_overlap_ms\tmedian_us\tp90_us\tp99_us\tmax_us"
                 "\tvgprs\tsgprs\tspilled_vgprs\tlds\tscratch\tsubgroups_per_simd\tspirv_executed_sha256")
ARMS_HEADER = ("slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar"
               "\townership\tstatus\tsclk_mode_mhz\tsclk_share\tregime_delta\tclock_invariant"
               "\tbelow_required_fraction")


def write_arm(root, slot, arm, status, subject_ms, null_ms, content="the answer", predicted=64):
    name = f"{int(slot):02d}-{arm}" if slot.isdigit() else f"{slot}-{arm}"
    directory = os.path.join(root, "arms", name)
    os.makedirs(directory, exist_ok=True)
    if status == "completed":
        with open(os.path.join(directory, "pipeline-ledger-decode.tsv"), "w") as handle:
            handle.write("graphs\tselected=63 ownership=exclusive\n")
            handle.write(LEDGER_HEADER + "\n")
            handle.write(f"pipeline\t31\tmul_mat_vec_q4_k_f32_f32\t64,4,1\t4,1,1\t64\t162.000\t121232.0"
                         f"\t{subject_ms + 60:.3f}\t{subject_ms + 44:.3f}\t{subject_ms:.3f}\t44.335"
                         f"\t207.4\t596.8\t599.4\t613.1\t64\t48\t0\t0\t0\t4\tabc\n")
            handle.write(f"pipeline\t32\tmul_mat_vec_q6_k_f32_f32\t64,4,1\t4,1,1\t64\t81.000\t60616.0"
                         f"\t{null_ms + 30:.3f}\t{null_ms + 20:.3f}\t{null_ms:.3f}\t20.0"
                         f"\t180.0\t500.0\t520.0\t600.0\t64\t48\t0\t0\t0\t4\tdef\n")
        with open(os.path.join(directory, "response.json"), "w") as handle:
            json.dump({"choices": [{"message": {"content": content}}],
                       "timings": {"predicted_n": predicted}}, handle)
    return f"{slot}\t{arm}\tsha\t{predicted}\t6500.0\t9.5\t100\ton\texclusive\t{status}\t1100\t1.0000\t-\theld\t0.0000"


def run_case(arms, bound=0.02):
    root = tempfile.mkdtemp(prefix="bracket-ab-")
    rows = [ARMS_HEADER, write_arm(root, "0a", "W", "completed", 3200.0, 1600.0)]
    for slot, (arm, status, subject, null, content) in enumerate(arms, 1):
        rows.append(write_arm(root, str(slot), arm, status, subject, null, content))
    with open(os.path.join(root, "arms.tsv"), "w") as handle:
        handle.write("\n".join(rows) + "\n")
    completed = subprocess.run(
        [sys.executable, SUMMARIZER, os.path.join(root, "arms.tsv"), os.path.join(root, "arms"),
         "--subject", "mul_mat_vec_q4_k_f32_f32", "--null", "mul_mat_vec_q6_k_f32_f32",
         "--bound", str(bound)],
        capture_output=True, text=True)
    if completed.returncode != 0:
        return completed.returncode, completed.stderr.strip(), {}
    lines = completed.stdout.rstrip("\n").split("\n")
    header = lines[0].split("\t")
    table = {}
    for line in lines[1:]:
        record = dict(zip(header, line.split("\t")))
        table[record["role"]] = record
    return 0, "", table


# A subject shortened by 8% in every pair with the null holding and the
# replies equal reads shortened / held / held, over four comparable pairs.
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1602.0, "a"),
    ("K", "completed", 2950.0, 1598.0, "a"), ("C", "completed", 3210.0, 1600.0, "a"),
    ("C", "completed", 3190.0, 1601.0, "a"), ("K", "completed", 2930.0, 1599.0, "a"),
    ("K", "completed", 2940.0, 1600.0, "a"), ("C", "completed", 3200.0, 1603.0, "a"),
])
assert status == 0, error
assert table["subject"]["verdict"] == "shortened", table["subject"]
assert table["subject"]["comparable_pairs"] == "4" and table["subject"]["replicates"] == "4", table["subject"]
assert float(table["subject"]["mean_delta"]) < -0.07, table["subject"]
assert table["null"]["verdict"] == "held", table["null"]
assert table["token_identity"]["verdict"] == "held", table["token_identity"]
assert table["subject"]["deltas"].split(" ")[0].startswith("-0.08"), table["subject"]
print("bracket_shortened=accepted")

# A subject that moves within the bound reads unchanged; a null that moves
# past it reads state-changed; a reply that differs in one pair reads differs.
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 3195.0, 1700.0, "a"),
    ("K", "completed", 3198.0, 1702.0, "b"), ("C", "completed", 3201.0, 1601.0, "a"),
    ("C", "completed", 3199.0, 1600.0, "a"), ("K", "completed", 3197.0, 1699.0, "a"),
    ("K", "completed", 3202.0, 1701.0, "a"), ("C", "completed", 3200.0, 1600.0, "a"),
])
assert status == 0, error
assert table["subject"]["verdict"] == "unchanged", table["subject"]
assert table["null"]["verdict"] == "state-changed", table["null"]
assert table["token_identity"]["verdict"] == "differs", table["token_identity"]
assert "pair2=differs" in table["token_identity"]["detail"], table["token_identity"]
print("bracket_unchanged_state_changed_differs=accepted")

# A failed arm drops its pair alone and the verdict stands on the survivors,
# with the count stated; a single surviving pair is incomplete.
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1600.0, "a"),
    ("K", "completed", 2950.0, 1600.0, "a"), ("C", "failed", 0.0, 0.0, "a"),
    ("C", "completed", 3190.0, 1600.0, "a"), ("K", "completed", 2930.0, 1600.0, "a"),
    ("K", "completed", 2940.0, 1600.0, "a"), ("C", "completed", 3200.0, 1600.0, "a"),
])
assert status == 0, error
assert table["subject"]["comparable_pairs"] == "3" and table["subject"]["verdict"] == "shortened", table["subject"]
assert "arm-failed" in table["subject"]["deltas"], table["subject"]
assert "comparable_pairs=3 of 4" in table["subject"]["detail"], table["subject"]
assert table["token_identity"]["verdict"] == "unavailable", table["token_identity"]
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1600.0, "a"),
    ("K", "completed", 2950.0, 1600.0, "a"), ("C", "failed", 0.0, 0.0, "a"),
])
assert status == 0, error
assert table["subject"]["verdict"] == "incomplete", table["subject"]
print("bracket_partial=accepted")

# A ledger without a C K K C quadruple and a subject equal to the null are
# refused with their own reason.
status, error, table = run_case([("C", "completed", 3200.0, 1600.0, "a"), ("C", "completed", 3200.0, 1600.0, "a")])
assert status != 0 and "no C K K C quadruple" in error, error
print("bracket_refusals=accepted")
print("summarize_bracket_ab=accepted")
