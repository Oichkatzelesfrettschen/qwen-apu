#!/usr/bin/env python3
"""Read summarize-prefill-ladder.py against ledgers whose verdicts are known.

Each case builds one arms.tsv, runs the summarizer over it, and reads the row
the case is about. The interval is recomputed here from the same Student's t
critical value the summarizer holds, so a change to either the ratio or the
interval arithmetic separates the two numbers and fails the case rather than
agreeing with itself.
"""
import math
import subprocess
import sys
import tempfile
from pathlib import Path

SUMMARIZER = Path(__file__).resolve().parent / "summarize-prefill-ladder.py"

HEADER = ("slot\tdepth\tquadruple\tarm\treplicate\tserver_role\tserver_sha256"
          "\tthreads\tprompt_target\ttokenize_n\tprompt_n\tttft_ms\tprompt_ms"
          "\tprompt_tok_s\tpredicted_n\tdecode_tok_s\tsclk_mode_mhz"
          "\tclock_invariant\tstatus\treason")

T_95_ONE_DEGREE = 12.706

failures = []


def report(name, condition, detail=""):
    if condition:
        print(f"ok {name}")
        return
    failures.append(name)
    print(f"FAIL {name} {detail}", file=sys.stderr)


def arm(slot, depth, quadruple, label, replicate, ttft, prompt_ms, prompt_tok_s,
        decode_tok_s="9.000", sclk="1100", invariant="held", status="completed",
        reason="-"):
    role = "control" if label == "C" else "candidate"
    digest = "c" * 64 if label == "C" else "k" * 64
    threads = "1" if label != "T" else "2"
    return "\t".join((
        str(slot), str(depth), quadruple, label, str(replicate), role, digest,
        threads, str(depth), str(depth), str(depth), ttft, prompt_ms,
        prompt_tok_s, "16", decode_tok_s, sclk, invariant, status, reason))


def summarize(rows, *arguments):
    with tempfile.TemporaryDirectory() as directory:
        ledger = Path(directory) / "arms.tsv"
        ledger.write_text("\n".join((HEADER, *rows)) + "\n", encoding="utf-8")
        finished = subprocess.run(
            [sys.executable, str(SUMMARIZER), str(ledger), *arguments],
            capture_output=True, text=True, check=False)
    return finished


def parse(output):
    lines = [line for line in output.splitlines() if line.strip()]
    header = lines[0].split("\t")
    return header, [dict(zip(header, line.split("\t"))) for line in lines[1:]]


def row_of(rows, depth, quadruple, metric):
    for row in rows:
        if (row["depth"] == str(depth) and row["quadruple"] == quadruple
                and row["metric"] == metric):
            return row
    return None


def paired_interval(ratios):
    """The mean, deviation, and nominal 95% interval of two paired ratios."""
    count = len(ratios)
    mean = sum(ratios) / count
    deviation = math.sqrt(sum((ratio - mean) ** 2 for ratio in ratios) / (count - 1))
    half_width = T_95_ONE_DEGREE * deviation / math.sqrt(count)
    return mean, deviation, mean - half_width, mean + half_width


# A candidate prefilling faster than the control by a margin two replicates
# resolve. The ratio is subject over control on every metric, so prompt_tok_s
# above unity is the candidate filling faster and ttft_ms below unity is the
# candidate reaching the first token sooner.
resolved = [
    arm(1, 512, "binary", "C", 1, "1000.000", "900.000", "20.000"),
    arm(2, 512, "binary", "K", 1, "800.000", "720.000", "25.000"),
    arm(3, 512, "binary", "K", 2, "800.400", "720.300", "24.990"),
    arm(4, 512, "binary", "C", 2, "1000.000", "900.000", "20.000"),
]
finished = summarize(resolved)
report("resolved_run_exits_zero", finished.returncode == 0, finished.stderr)
header, rows = parse(finished.stdout)
report("header_names_every_column",
       header[:6] == ["depth", "quadruple", "subject", "metric", "sense",
                      "replicates"], header)

prompt_row = row_of(rows, 512, "binary", "prompt_tok_s")
expected_mean, expected_sd, expected_low, expected_high = paired_interval(
    [25.000 / 20.000, 24.990 / 20.000])
report("prompt_rate_ratio_is_subject_over_control",
       prompt_row is not None
       and prompt_row["mean_ratio"] == f"{expected_mean:.4f}"
       and prompt_row["sd_ratio"] == f"{expected_sd:.4f}",
       prompt_row)
report("prompt_rate_interval_matches_student_t",
       prompt_row is not None
       and prompt_row["ci_low"] == f"{expected_low:.4f}"
       and prompt_row["ci_high"] == f"{expected_high:.4f}",
       prompt_row)
report("prompt_rate_above_unity_is_the_candidate_filling_faster",
       prompt_row is not None and prompt_row["verdict"] == "above"
       and prompt_row["sense"] == "subject_faster",
       prompt_row)
report("prompt_rate_replicates_and_means",
       prompt_row is not None and prompt_row["replicates"] == "2"
       and prompt_row["control_mean"] == "20.0000"
       and prompt_row["subject_mean"] == "24.9950",
       prompt_row)

ttft_row = row_of(rows, 512, "binary", "ttft_ms")
report("first_token_latency_below_unity_is_the_candidate_arriving_sooner",
       ttft_row is not None and ttft_row["verdict"] == "below"
       and ttft_row["sense"] == "subject_slower",
       ttft_row)
report("subject_column_names_the_arm_the_ratio_measures",
       ttft_row is not None and ttft_row["subject"] == "K", ttft_row)

# Two replicates carry one degree of freedom, so a 22% mean gain whose two
# replicates disagree by 4% leaves the interval spanning unity. The ladder
# reports that rather than the mean alone.
unresolved = [
    arm(1, 512, "binary", "C", 1, "1000.000", "900.000", "20.000"),
    arm(2, 512, "binary", "K", 1, "800.000", "720.000", "25.000"),
    arm(3, 512, "binary", "K", 2, "830.000", "750.000", "24.000"),
    arm(4, 512, "binary", "C", 2, "1000.000", "900.000", "20.000"),
]
header, rows = parse(summarize(unresolved).stdout)
spanning = row_of(rows, 512, "binary", "prompt_tok_s")
report("two_replicates_disagreeing_leave_the_interval_spanning_unity",
       spanning is not None and spanning["verdict"] == "unresolved"
       and spanning["mean_ratio"] == "1.2250",
       spanning)

# A depth the runner declined carries its own reason and no ratio at all.
skipped = [arm(1, 32768, "binary", "-", "-", "-", "-", "-", "-", "-", "-",
               "skipped", "above_validated_filled_depth")]
header, rows = parse(summarize(skipped).stdout)
report("a_skipped_depth_carries_the_runner_reason",
       len(rows) == 1 and rows[0]["verdict"] == "skipped"
       and rows[0]["detail"] == "reason=above_validated_filled_depth"
       and rows[0]["mean_ratio"] == "-",
       rows)

# A failed arm makes the depth incomplete on every metric, since a set missing a
# pair measures a different set.
incomplete = [
    arm(1, 512, "binary", "C", 1, "1000.000", "900.000", "20.000"),
    arm(2, 512, "binary", "K", 1, "-", "-", "-", "-", "-", "-", "failed",
        "missing_timings"),
    arm(3, 512, "binary", "K", 2, "800.400", "720.300", "24.990"),
    arm(4, 512, "binary", "C", 2, "1000.000", "900.000", "20.000"),
]
header, rows = parse(summarize(incomplete).stdout)
report("a_failed_arm_makes_every_metric_incomplete",
       all(row["verdict"] == "incomplete" for row in rows) and len(rows) == 4
       and "missing_timings" in rows[0]["detail"],
       rows)

# An arm that ran off the pinned step loses its pair, and one surviving pair is
# fewer than the two an interval needs.
violated = [
    arm(1, 512, "binary", "C", 1, "1000.000", "900.000", "20.000"),
    arm(2, 512, "binary", "K", 1, "800.000", "720.000", "25.000",
        invariant="violated"),
    arm(3, 512, "binary", "K", 2, "800.400", "720.300", "24.990"),
    arm(4, 512, "binary", "C", 2, "1000.000", "900.000", "20.000"),
]
header, rows = parse(summarize(violated).stdout)
violated_row = row_of(rows, 512, "binary", "prompt_tok_s")
report("a_clock_violation_drops_its_pair",
       violated_row is not None and violated_row["verdict"] == "state-changed"
       and "clock-violated" in violated_row["ratios"]
       and violated_row["detail"] == "comparable_pairs=1 of 2",
       violated_row)

# A pair whose two arms held graphics clocks further apart than the band
# measures the governor step between them rather than the change under test.
stepped = [
    arm(1, 512, "binary", "C", 1, "1000.000", "900.000", "20.000", sclk="1100"),
    arm(2, 512, "binary", "K", 1, "800.000", "720.000", "25.000", sclk="800"),
    arm(3, 512, "binary", "K", 2, "800.400", "720.300", "24.990", sclk="1100"),
    arm(4, 512, "binary", "C", 2, "1000.000", "900.000", "20.000", sclk="1100"),
]
header, rows = parse(summarize(stepped).stdout)
stepped_row = row_of(rows, 512, "binary", "prompt_tok_s")
report("a_governor_step_across_a_pair_drops_it",
       stepped_row is not None and stepped_row["verdict"] == "state-changed"
       and "state-changed" in stepped_row["ratios"]
       and stepped_row["sclk_modes"] == "800/1100 1100/1100",
       stepped_row)

# The thread quadruple is read the same way and names its own subject arm.
threads = [
    arm(1, 512, "threads", "C", 1, "1000.000", "900.000", "20.000"),
    arm(2, 512, "threads", "T", 1, "700.000", "630.000", "28.000"),
    arm(3, 512, "threads", "T", 2, "700.300", "630.200", "27.990"),
    arm(4, 512, "threads", "C", 2, "1000.000", "900.000", "20.000"),
]
header, rows = parse(summarize(threads).stdout)
thread_row = row_of(rows, 512, "threads", "prompt_tok_s")
report("the_thread_quadruple_names_its_own_subject",
       thread_row is not None and thread_row["subject"] == "T"
       and thread_row["verdict"] == "above",
       thread_row)

# A band at or above one holds every pair of clocks in one state and retires the
# comparison it names, so it is refused where the value is parsed.
refused = summarize(resolved, "--sclk-band", "1.0")
report("a_band_of_one_is_refused", refused.returncode == 2, refused.stderr)
refused = summarize(resolved, "--sclk-band", "inf")
report("an_infinite_band_is_refused", refused.returncode == 2, refused.stderr)

# A ledger whose rows carry fewer fields than the header names is a record no
# reader can split back, so it refuses rather than reading a shifted row.
ragged = summarize([resolved[0], "1\t512\tbinary"])
report("a_ragged_ledger_row_is_refused", ragged.returncode != 0, ragged.stderr)

if failures:
    print(f"summarize_prefill_ladder_tests=failed failures={len(failures)}",
          file=sys.stderr)
    raise SystemExit(1)
print("summarize_prefill_ladder_tests=passed")
