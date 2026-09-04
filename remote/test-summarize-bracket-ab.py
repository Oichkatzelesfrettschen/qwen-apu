#!/usr/bin/env python3
"""Drive summarize-bracket-ab.py over synthetic arms and decode ledgers.

Each case writes an arms ledger in the C K K C shape, one decode ledger per
arm carrying a graphs row and a subject and a null pipeline row, and one reply
per arm, then reads the rows by role.
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
               "\townership\tstatus\tsclk_mode_mhz\tsclk_share\tmclk_mode_mhz\tregime_delta"
               "\tclock_invariant\tbelow_required_fraction")


def write_arm(root, slot, arm, status, subject_ms, null_ms, content="the answer", predicted=64,
              subject_union=None, null_union=None, subject_digest=None, null_digest="nulldigest",
              span=None, ownership="conclusive", sclk_mode="1100", subject_present=True,
              sclk_share="1.0000", mclk_mode="933"):
    name = f"{int(slot):02d}-{arm}" if slot.isdigit() else f"{slot}-{arm}"
    directory = os.path.join(root, "arms", name)
    os.makedirs(directory, exist_ok=True)
    if subject_union is None:
        subject_union = subject_ms + 44
    if null_union is None:
        null_union = null_ms + 2.6
    if subject_digest is None:
        subject_digest = "controldigest" if arm == "C" else "candidatedigest"
    if span is None:
        span = (subject_ms + null_ms) / 63 * 1.8
    if status == "completed":
        with open(os.path.join(directory, "pipeline-ledger-decode.tsv"), "w") as handle:
            handle.write(f"graphs\tdecode\t63\texclusive_ms_per_graph=97.0\townership=conclusive"
                         f"\tqueue_completion_span_ms_per_graph={span:.3f}\n")
            handle.write(LEDGER_HEADER + "\n")
            if subject_present:
                handle.write(f"pipeline\t31\tmul_mat_vec_q4_k_f32_f32\t64,4,1\t4,1,1\t64\t162.000\t121232.0"
                             f"\t{subject_ms + 60:.3f}\t{subject_union:.3f}\t{subject_ms:.3f}\t44.335"
                             f"\t207.4\t596.8\t599.4\t613.1\t64\t48\t0\t0\t0\t4\t{subject_digest}\n")
            handle.write(f"pipeline\t32\tmul_mat_vec_q6_k_f32_f32\t64,4,1\t4,1,1\t64\t81.000\t60616.0"
                         f"\t{null_ms + 30:.3f}\t{null_union:.3f}\t{null_ms:.3f}\t2.6"
                         f"\t180.0\t500.0\t520.0\t600.0\t64\t48\t0\t0\t0\t4\t{null_digest}\n")
        with open(os.path.join(directory, "response.json"), "w") as handle:
            json.dump({"choices": [{"message": {"content": content}}],
                       "timings": {"predicted_n": predicted}}, handle)
    return (f"{slot}\t{arm}\tsha\t{predicted}\t6500.0\t9.5\t100\ton\t{ownership}\t{status}"
            f"\t{sclk_mode}\t{sclk_share}\t{mclk_mode}\t-\theld\t0.0000")


WITNESS_HEADER = ("prompt\tcomparison\tsamples\tid_identity\tfirst_divergence\tpositions"
                  "\tunread_positions\tnear_tie_positions\tmin_control_margin"
                  "\tmin_candidate_margin\tmin_retention\tretention_failures"
                  "\tnonpositive_candidate_margins\tmax_truncated_tv"
                  "\tmax_abs_logprob_delta\tverdict")


def write_witness(root, identity="held", overall="held", prompts=("accumulator", "variable-trace")):
    """One margin-summary.tsv in the shape run-kernel-delta-witness.sh writes."""
    directory = os.path.join(root, "witness")
    os.makedirs(directory, exist_ok=True)
    rows = [WITNESS_HEADER]
    for prompt in prompts:
        rows.append(f"{prompt}\tself-C\t4\theld\t-\t128\t-\t-\t-\t-\t-\t-\t-\t-\t0\theld")
        rows.append(f"{prompt}\tcandidate-vs-control\t4\t{identity}\t-\t512\t0\t8"
                    f"\t0.0160179\t0.0160179\t1\t0\t0\t0\t0\t{overall}")
    rows.append(f"-\toverall\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t{overall}")
    with open(os.path.join(directory, "margin-summary.tsv"), "w") as handle:
        handle.write("\n".join(rows) + "\n")
    return directory


def run_case(arms, bound=0.02, band=None, witness=None, arm_options=None):
    root = tempfile.mkdtemp(prefix="bracket-ab-")
    rows = [ARMS_HEADER, write_arm(root, "0a", "W", "completed", 3200.0, 1600.0)]
    for slot, spec in enumerate(arms, 1):
        arm, status, subject, null, content = spec[:5]
        extra = dict(arm_options or {})
        extra.update(spec[5] if len(spec) > 5 else {})
        rows.append(write_arm(root, str(slot), arm, status, subject, null, content, **extra))
    with open(os.path.join(root, "arms.tsv"), "w") as handle:
        handle.write("\n".join(rows) + "\n")
    command = [sys.executable, SUMMARIZER, os.path.join(root, "arms.tsv"),
               os.path.join(root, "arms"),
               "--subject", "mul_mat_vec_q4_k_f32_f32", "--null", "mul_mat_vec_q6_k_f32_f32",
               "--bound", str(bound)]
    if band is not None:
        command += ["--sclk-band", str(band)]
    if witness is not None:
        command += ["--witness", witness(root) if callable(witness) else witness]
    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode != 0:
        return completed.returncode, completed.stderr.strip(), {}
    lines = completed.stdout.rstrip("\n").split("\n")
    header = lines[0].split("\t")
    table = {}
    for line in lines[1:]:
        fields = line.split("\t")
        # A row short of the header misaligns every field a caller reads by
        # name, and zip() would hide it, so the arity is checked here.
        assert len(fields) == len(header), (len(fields), len(header), fields)
        record = dict(zip(header, fields))
        table[record["role"]] = record
    return 0, "", table


# A subject shortened by 8% in every pair, union with it, the null holding on
# both readings, one module per role, and equal replies: every row reads its
# passing verdict over four comparable pairs and the eight roles are present.
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1602.0, "a"),
    ("K", "completed", 2950.0, 1598.0, "a"), ("C", "completed", 3210.0, 1600.0, "a"),
    ("C", "completed", 3190.0, 1601.0, "a"), ("K", "completed", 2930.0, 1599.0, "a"),
    ("K", "completed", 2940.0, 1600.0, "a"), ("C", "completed", 3200.0, 1603.0, "a"),
])
assert status == 0, error
assert sorted(table) == ["clock_state", "graph-span", "margin_contract", "module_identity",
                         "null", "null-union", "ratio", "response_identity", "subject",
                         "subject-union", "token_identity"], sorted(table)
assert table["subject"]["verdict"] == "shortened", table["subject"]
assert table["subject"]["comparable_pairs"] == "4" and table["subject"]["replicates"] == "4", table["subject"]
assert float(table["subject"]["mean_delta"]) < -0.07, table["subject"]
assert table["subject-union"]["verdict"] == "shortened", table["subject-union"]
assert table["null"]["verdict"] == "held" and table["null-union"]["verdict"] == "held", table["null"]
assert table["graph-span"]["verdict"] == "reported" and float(table["graph-span"]["mean_delta"]) < 0, table["graph-span"]
assert table["ratio"]["verdict"] == "reported" and float(table["ratio"]["mean_delta"]) < -0.07, table["ratio"]
assert table["module_identity"]["verdict"] == "held", table["module_identity"]
assert table["module_identity"]["control_values"] == "controldigest", table["module_identity"]
assert table["module_identity"]["candidate_values"] == "candidatedigest", table["module_identity"]
assert table["response_identity"]["verdict"] == "held", table["response_identity"]
assert table["response_identity"]["comparable_pairs"] == "4", table["response_identity"]
assert table["subject"]["deltas"].split(" ")[0].startswith("-0.08"), table["subject"]
print("bracket_shortened=accepted")

# A subject that moves within the bound reads unchanged; a null that moves
# past it reads state-changed on both readings; a reply that differs in one
# pair reads differs; a candidate arm executing the control's module reads a
# differing module identity.
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 3195.0, 1700.0, "a"),
    ("K", "completed", 3198.0, 1702.0, "b", {"subject_digest": "controldigest"}),
    ("C", "completed", 3201.0, 1601.0, "a"),
    ("C", "completed", 3199.0, 1600.0, "a"), ("K", "completed", 3197.0, 1699.0, "a"),
    ("K", "completed", 3202.0, 1701.0, "a"), ("C", "completed", 3200.0, 1600.0, "a"),
])
assert status == 0, error
assert table["subject"]["verdict"] == "unchanged", table["subject"]
assert table["null"]["verdict"] == "state-changed", table["null"]
assert table["null-union"]["verdict"] == "state-changed", table["null-union"]
assert table["response_identity"]["verdict"] == "differs", table["response_identity"]
assert "pair2=differs" in table["response_identity"]["detail"], table["response_identity"]
assert table["module_identity"]["verdict"] == "differs", table["module_identity"]
print("bracket_unchanged_state_changed_differs=accepted")

# Exclusive shortened while the union holds: the two rows disagree, which the
# harness reads as an overlap-accounting change. A null module that differs
# between arms also reads differs.
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1600.0, "a", {"subject_union": 3244.0}),
    ("K", "completed", 2950.0, 1600.0, "a", {"subject_union": 3244.0, "null_digest": "othernull"}),
    ("C", "completed", 3200.0, 1600.0, "a"),
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1600.0, "a", {"subject_union": 3244.0}),
    ("K", "completed", 2950.0, 1600.0, "a", {"subject_union": 3244.0}), ("C", "completed", 3200.0, 1600.0, "a"),
])
assert status == 0, error
assert table["subject"]["verdict"] == "shortened" and table["subject-union"]["verdict"] == "unchanged", table
assert table["module_identity"]["verdict"] == "differs" and "null=2" in table["module_identity"]["detail"], table["module_identity"]
print("bracket_union_disagrees=accepted")

# A failed arm drops its pair alone, the count is stated on every row, the
# module identity reads over the arms that completed, and a single surviving
# pair is incomplete.
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
assert table["response_identity"]["verdict"] == "unavailable", table["response_identity"]
assert table["response_identity"]["comparable_pairs"] == "3", table["response_identity"]
assert table["module_identity"]["verdict"] == "held", table["module_identity"]
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1600.0, "a"),
    ("K", "completed", 2950.0, 1600.0, "a"), ("C", "failed", 0.0, 0.0, "a"),
])
assert status == 0, error
assert table["subject"]["verdict"] == "incomplete", table["subject"]
print("bracket_partial=accepted")

# A completed pair whose subject row the ledger never carried leaves the
# subject and ratio rows incomplete over three surviving deltas, while the null
# rows, which every arm reported, still read their own verdict.
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1600.0, "a"),
    ("K", "completed", 2950.0, 1600.0, "a"), ("C", "completed", 3200.0, 1600.0, "a"),
    ("C", "completed", 3190.0, 1600.0, "a"),
    ("K", "completed", 2930.0, 1600.0, "a", {"subject_present": False}),
    ("K", "completed", 2940.0, 1600.0, "a"), ("C", "completed", 3200.0, 1600.0, "a"),
])
assert status == 0, error
assert table["subject"]["verdict"] == "incomplete", table["subject"]
assert table["subject"]["comparable_pairs"] == "3", table["subject"]
assert "ledger-missing" in table["subject"]["deltas"], table["subject"]
assert table["null"]["verdict"] == "held", table["null"]
print("bracket_ledger_missing_incomplete=accepted")

# A pair whose two arms selected modal graphics clocks farther apart than the
# band measures the governor step between them, so it leaves the mean and the
# interval as state-changed and the row still reads its verdict over the three
# pairs that held one state. The same ledger under a band wide enough to hold
# both clocks reads all four.
stepped = [
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1600.0, "a"),
    ("K", "completed", 2950.0, 1600.0, "a"), ("C", "completed", 3200.0, 1600.0, "a"),
    ("C", "completed", 3190.0, 1600.0, "a", {"sclk_mode": "800"}),
    ("K", "completed", 2930.0, 1600.0, "a"),
    ("K", "completed", 2940.0, 1600.0, "a"), ("C", "completed", 3200.0, 1600.0, "a"),
]
status, error, table = run_case(stepped, band=0.06)
assert status == 0, error
assert table["subject"]["verdict"] == "shortened", table["subject"]
assert table["subject"]["comparable_pairs"] == "3", table["subject"]
assert "state-changed" in table["subject"]["deltas"], table["subject"]
status, error, table = run_case(stepped, band=0.5)
assert status == 0, error
assert table["subject"]["comparable_pairs"] == "4", table["subject"]
print("bracket_sclk_band=accepted")

# An arm the census left unable to attribute its exclusive time to one pipeline
# carries no verdict at all: the pair is listed by its reason and the row reads
# incomplete rather than judging the three pairs that were attributable.
status, error, table = run_case([
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1600.0, "a"),
    ("K", "completed", 2950.0, 1600.0, "a"), ("C", "completed", 3200.0, 1600.0, "a"),
    ("C", "completed", 3190.0, 1600.0, "a"),
    ("K", "completed", 2930.0, 1600.0, "a", {"ownership": "inconclusive"}),
    ("K", "completed", 2940.0, 1600.0, "a"), ("C", "completed", 3200.0, 1600.0, "a"),
])
assert status == 0, error
assert table["subject"]["verdict"] == "incomplete", table["subject"]
assert "ownership-inconclusive" in table["subject"]["deltas"], table["subject"]
assert table["null"]["verdict"] == "incomplete", table["null"]
print("bracket_ownership_inconclusive=accepted")

# A ledger without a C K K C quadruple is refused with its own reason.
status, error, table = run_case([("C", "completed", 3200.0, 1600.0, "a"), ("C", "completed", 3200.0, 1600.0, "a")])
assert status != 0 and "no C K K C quadruple" in error, error
print("bracket_refusals=accepted")
# The three reporting rows. The clock state names each arm's own modal graphics
# clock, its share, and its modal fabric clock, so a reader sees the execution
# state every bracket above was measured at; the witness rows carry a separate
# run's token identity and margin contract, and both name the directory they
# came from so one run's evidence is not read as another's.
PASSING = [
    ("C", "completed", 3200.0, 1600.0, "a"), ("K", "completed", 2944.0, 1602.0, "a"),
    ("K", "completed", 2950.0, 1598.0, "a"), ("C", "completed", 3210.0, 1600.0, "a"),
    ("C", "completed", 3190.0, 1601.0, "a"), ("K", "completed", 2930.0, 1599.0, "a"),
    ("K", "completed", 2940.0, 1600.0, "a"), ("C", "completed", 3200.0, 1603.0, "a"),
]
status, error, table = run_case(PASSING, witness=write_witness)
assert status == 0, error
assert table["clock_state"]["verdict"] == "measured", table["clock_state"]
assert table["clock_state"]["control_values"].split(" ")[0] == "1100/1.0000/933", table["clock_state"]
assert table["clock_state"]["comparable_pairs"] == "8", table["clock_state"]
assert "fclk_modes=933" in table["clock_state"]["detail"], table["clock_state"]
assert "min_sclk_share=1.0000" in table["clock_state"]["detail"], table["clock_state"]
assert table["token_identity"]["verdict"] == "held", table["token_identity"]
assert table["token_identity"]["comparable_pairs"] == "2", table["token_identity"]
assert "witness=" in table["token_identity"]["detail"], table["token_identity"]
assert table["margin_contract"]["verdict"] == "held", table["margin_contract"]
print("bracket_reporting_rows=accepted")

# A run whose two arms of a pair held different fabric clocks still reports the
# state rather than refusing: the graphics band decides comparability and the
# fabric mode is a nuisance term this row names for a reader to weigh.
status, error, table = run_case(PASSING, witness=write_witness,
                                arm_options={"mclk_mode": "1067"})
assert status == 0, error
assert table["clock_state"]["verdict"] == "measured", table["clock_state"]
assert "fclk_modes=1067" in table["clock_state"]["detail"], table["clock_state"]

# An arm whose sidecar recorded no clock state leaves the row unavailable, since
# an unread arm is a state the row cannot show rather than one it can average
# over the arms that were read.
status, error, table = run_case(PASSING, witness=write_witness,
                                arm_options={"mclk_mode": "-"})
assert status == 0, error
assert table["clock_state"]["verdict"] == "unavailable", table["clock_state"]
assert "arms_without_clock_state=8" in table["clock_state"]["detail"], table["clock_state"]

# The witness is optional and its absence is stated rather than assumed passing.
status, error, table = run_case(PASSING)
assert status == 0, error
assert table["token_identity"]["verdict"] == "unavailable", table["token_identity"]
assert table["margin_contract"]["verdict"] == "unavailable", table["margin_contract"]
status, error, table = run_case(PASSING, witness="/nonexistent/witness")
assert status == 0, error
assert table["token_identity"]["verdict"] == "unavailable", table["token_identity"]
assert "unreadable" in table["token_identity"]["detail"], table["token_identity"]

# Moved ids and a refused contract each reach their own row, and neither
# changes the bracket rows beside them.
status, error, table = run_case(
    PASSING, witness=lambda root: write_witness(root, identity="differs", overall="refuted"))
assert status == 0, error
assert table["token_identity"]["verdict"] == "differs", table["token_identity"]
assert table["margin_contract"]["verdict"] == "refuted", table["margin_contract"]
assert table["subject"]["verdict"] == "shortened", table["subject"]
print("bracket_witness_rows=accepted")

print("summarize_bracket_ab=accepted")
