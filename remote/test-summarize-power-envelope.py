#!/usr/bin/env python3
"""Drive summarize-power-envelope.py against a fixture campaign directory.

The summarizer states a verdict, so the cases below are about what it refuses to
claim: a candidate inside the machine's own retained spread reads `unresolved`
however closely the two control arms happened to agree, a checkpoint whose
controls disagree beyond the span criterion has its candidates left unread, and
an arm that carries no rate refuses rather than defaulting.
"""
import os
import shutil
import subprocess
import sys
import tempfile

SUMMARIZER = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "summarize-power-envelope.py"
)
ROLES = ("01-control-open", "02-package-20w", "03-package-25w", "04-control-close")
PROFILES = {
    "01-control-open": "serve-fixed-package-default",
    "02-package-20w": "serve-fixed-package-20w",
    "03-package-25w": "serve-fixed-package-25w",
    "04-control-close": "serve-fixed-package-default",
}


def write_arm(campaign_directory, model_id, role, decode, package_watts="17.0",
              schema="power-envelope-arm-v1"):
    arm_directory = os.path.join(campaign_directory, "arms", f"{model_id}-{role}")
    os.makedirs(arm_directory, exist_ok=True)
    rows = [
        ("schema", schema),
        ("arm", f"{model_id}-{role}"),
        ("model_id", model_id),
        ("compute_state_profile", PROFILES[role]),
        ("served_status", "0"),
        ("energy_status", "0"),
        ("decode_tok_s", decode),
        ("package_watts", package_watts),
        ("core_watts", "1.5"),
        ("package_watts_outer", package_watts),
        ("core_watts_outer", "1.5"),
        ("window_coverage", "bracketed"),
        ("gfxclk_delivered_mean_mhz", "1100.0"),
        ("gfxclk_selected_mhz", "1100"),
        ("fclk_observed_mhz", "933"),
        ("tctl_peak_millidegrees", "62000"),
        ("edge_peak_millidegrees", "61000"),
    ]
    with open(os.path.join(arm_directory, "arm-summary.tsv"), "w") as handle:
        handle.write("key\tvalue\n")
        handle.writelines(f"{key}\t{value}\n" for key, value in rows)


def run_summarizer(campaign_directory):
    return subprocess.run(
        [sys.executable, SUMMARIZER, campaign_directory],
        capture_output=True,
        text=True,
        check=False,
    )


def verdict_rows(text):
    rows = {}
    for line in text.splitlines():
        fields = line.split("\t")
        if len(fields) == 4 and fields[0] != "model_id":
            rows[(fields[0], fields[1])] = (fields[2], fields[3])
    return rows


def test_a_small_difference_reads_unresolved():
    directory = tempfile.mkdtemp()
    try:
        # The two controls agree to 0.1%, so the checkpoint's own control spread
        # would call a 0.6% candidate a budget effect; the machine's retained 4%
        # spread is the wider band and the verdict is unresolved.
        write_arm(directory, "modelx", "01-control-open", "10.000")
        write_arm(directory, "modelx", "02-package-20w", "10.060")
        write_arm(directory, "modelx", "03-package-25w", "9.960")
        write_arm(directory, "modelx", "04-control-close", "10.010")
        result = run_summarizer(directory)
        assert result.returncode == 0, result.stderr
        rows = verdict_rows(result.stdout)
        assert rows[("modelx", "sweep")][0] == "resolved", rows
        assert rows[("modelx", "02-package-20w")][0] == "unresolved", rows
        assert "machine spread floor" in rows[("modelx", "02-package-20w")][1]
        assert rows[("modelx", "03-package-25w")][0] == "unresolved", rows
        print("test_a_small_difference_reads_unresolved: PASSED")
    finally:
        shutil.rmtree(directory)


def test_a_difference_beyond_the_floor_carries_its_sign():
    directory = tempfile.mkdtemp()
    try:
        write_arm(directory, "modelx", "01-control-open", "10.000")
        write_arm(directory, "modelx", "02-package-20w", "11.000")
        write_arm(directory, "modelx", "03-package-25w", "9.000")
        write_arm(directory, "modelx", "04-control-close", "10.010")
        result = run_summarizer(directory)
        assert result.returncode == 0, result.stderr
        rows = verdict_rows(result.stdout)
        assert rows[("modelx", "02-package-20w")][0] == "faster", rows
        assert rows[("modelx", "03-package-25w")][0] == "slower", rows
        print("test_a_difference_beyond_the_floor_carries_its_sign: PASSED")
    finally:
        shutil.rmtree(directory)


def test_disagreeing_controls_leave_the_candidates_unread():
    directory = tempfile.mkdtemp()
    try:
        write_arm(directory, "modelx", "01-control-open", "10.000")
        write_arm(directory, "modelx", "02-package-20w", "10.500")
        write_arm(directory, "modelx", "03-package-25w", "10.500")
        write_arm(directory, "modelx", "04-control-close", "5.000")
        result = run_summarizer(directory)
        assert result.returncode == 0, result.stderr
        rows = verdict_rows(result.stdout)
        assert rows[("modelx", "sweep")][0] == "unresolved", rows
        assert "span criterion" in rows[("modelx", "sweep")][1]
        assert ("modelx", "02-package-20w") not in rows, rows
        print("test_disagreeing_controls_leave_the_candidates_unread: PASSED")
    finally:
        shutil.rmtree(directory)


def test_a_missing_control_refuses_the_sweep():
    directory = tempfile.mkdtemp()
    try:
        write_arm(directory, "modelx", "01-control-open", "10.000")
        write_arm(directory, "modelx", "02-package-20w", "10.100")
        write_arm(directory, "modelx", "03-package-25w", "10.100")
        result = run_summarizer(directory)
        assert result.returncode == 0, result.stderr
        rows = verdict_rows(result.stdout)
        assert rows[("modelx", "sweep")][0] == "unresolved", rows
        assert "one control arm carries no accepted rate" in rows[("modelx", "sweep")][1]
        assert "modelx\t04-control-close\tabsent" in result.stdout
        print("test_a_missing_control_refuses_the_sweep: PASSED")
    finally:
        shutil.rmtree(directory)


def test_a_refused_arm_is_not_read():
    directory = tempfile.mkdtemp()
    try:
        write_arm(directory, "modelx", "01-control-open", "10.000")
        write_arm(directory, "modelx", "02-package-20w", "11.000")
        write_arm(directory, "modelx", "03-package-25w", "9.000")
        write_arm(directory, "modelx", "04-control-close", "10.010")
        # The candidate completed its decode and its energy reader refused, so
        # its rate is retained and unreadable.
        arm_summary = os.path.join(
            directory, "arms", "modelx-02-package-20w", "arm-summary.tsv"
        )
        with open(arm_summary) as handle:
            text = handle.read()
        with open(arm_summary, "w") as handle:
            handle.write(text.replace("energy_status\t0", "energy_status\t3"))
        # The closing control lost its bracket, which ends the sweep unread.
        control_summary = os.path.join(
            directory, "arms", "modelx-04-control-close", "arm-summary.tsv"
        )
        with open(control_summary) as handle:
            text = handle.read()
        with open(control_summary, "w") as handle:
            handle.write(
                text.replace("window_coverage\tbracketed", "window_coverage\tunreached")
            )
        result = run_summarizer(directory)
        assert result.returncode == 0, result.stderr
        rows = verdict_rows(result.stdout)
        assert rows[("modelx", "sweep")][0] == "unresolved", rows
        assert "no accepted rate" in rows[("modelx", "sweep")][1], rows
        print("test_a_refused_arm_is_not_read: PASSED")
    finally:
        shutil.rmtree(directory)


def test_a_refused_candidate_alone_reads_unresolved():
    directory = tempfile.mkdtemp()
    try:
        write_arm(directory, "modelx", "01-control-open", "10.000")
        write_arm(directory, "modelx", "02-package-20w", "11.000")
        write_arm(directory, "modelx", "03-package-25w", "9.000")
        write_arm(directory, "modelx", "04-control-close", "10.010")
        arm_summary = os.path.join(
            directory, "arms", "modelx-02-package-20w", "arm-summary.tsv"
        )
        with open(arm_summary) as handle:
            text = handle.read()
        with open(arm_summary, "w") as handle:
            handle.write(text.replace("served_status\t0", "served_status\t1"))
        result = run_summarizer(directory)
        assert result.returncode == 0, result.stderr
        rows = verdict_rows(result.stdout)
        assert rows[("modelx", "sweep")][0] == "resolved", rows
        assert rows[("modelx", "02-package-20w")][0] == "unresolved", rows
        assert "no accepted rate" in rows[("modelx", "02-package-20w")][1], rows
        assert rows[("modelx", "03-package-25w")][0] == "slower", rows
        print("test_a_refused_candidate_alone_reads_unresolved: PASSED")
    finally:
        shutil.rmtree(directory)


def test_a_foreign_arm_schema_is_not_read():
    directory = tempfile.mkdtemp()
    try:
        for role in ROLES:
            write_arm(directory, "modelx", role, "10.000",
                      schema="power-envelope-arm-v0")
        result = run_summarizer(directory)
        assert result.returncode != 0, result.stdout
        assert "campaign holds no readable arm" in result.stderr, result.stderr
        print("test_a_foreign_arm_schema_is_not_read: PASSED")
    finally:
        shutil.rmtree(directory)


def test_an_absent_arms_directory_refuses():
    directory = tempfile.mkdtemp()
    try:
        result = run_summarizer(directory)
        assert result.returncode != 0, result.stdout
        assert "campaign holds no arms directory" in result.stderr, result.stderr
        print("test_an_absent_arms_directory_refuses: PASSED")
    finally:
        shutil.rmtree(directory)


if __name__ == "__main__":
    test_a_small_difference_reads_unresolved()
    test_a_difference_beyond_the_floor_carries_its_sign()
    test_disagreeing_controls_leave_the_candidates_unread()
    test_a_missing_control_refuses_the_sweep()
    test_a_refused_arm_is_not_read()
    test_a_refused_candidate_alone_reads_unresolved()
    test_a_foreign_arm_schema_is_not_read()
    test_an_absent_arms_directory_refuses()
    print("summarize_power_envelope=accepted")
