#!/usr/bin/env python3
"""Drive summarize-power-factorial.py against a fixture campaign directory.

The summarizer states a one-sided 5% promotion verdict per ladder comparison,
so the cases below are about what it refuses to claim: a checkpoint whose
controls disagree beyond the 20% span criterion has its candidates left
unread, a comparison between a served arm and a bench arm is refused rather
than compared, and a candidate inside the 5% bound reads `unresolved` rather
than `promoted` or `regressed`.
"""

import os
import shutil
import subprocess
import sys
import tempfile

SUMMARIZER = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "summarize-power-factorial.py"
)
ROLES = (
    "01-control-open",
    "02-p1-gfx-fclk-pin",
    "03-p2-cpu-capped",
    "04-p3-fclk-range",
    "05-p4-package-25w",
    "06-p4-cap-alt",
    "07-p4-ksm-alt",
    "08-p4-nice-bench-19",
    "09-p4-nice-bench-0",
    "10-control-close",
)
PROFILES = {
    "01-control-open": "serve-auto-baseline",
    "02-p1-gfx-fclk-pin": "serve-fixed-package-default",
    "03-p2-cpu-capped": "serve-fixed-cpu-capped",
    "04-p3-fclk-range": "serve-fixed-cpu-capped-fclk-range",
    "05-p4-package-25w": "serve-fixed-cpu-capped-fclk-range-package-25w",
    "06-p4-cap-alt": "serve-fixed-fclk-range-package-25w",
    "07-p4-ksm-alt": "serve-fixed-cpu-capped-fclk-range-package-25w-ksm-running",
    "08-p4-nice-bench-19": "measure-fixed-cpu-capped-fclk-range-package-25w",
    "09-p4-nice-bench-0": "measure-fixed-cpu-capped-fclk-range-package-25w-nice0",
    "10-control-close": "serve-auto-baseline",
}
INSTRUMENTS = {role: "served" for role in ROLES}
INSTRUMENTS["08-p4-nice-bench-19"] = "bench"
INSTRUMENTS["09-p4-nice-bench-0"] = "bench"


def write_arm(
    campaign_directory, model_id, role, decode, served_status="0", instrument=None
):
    arm_directory = os.path.join(campaign_directory, "arms", f"{model_id}-{role}")
    os.makedirs(arm_directory, exist_ok=True)
    rows = [
        ("schema", "power-factorial-arm-v1"),
        ("arm", f"{model_id}-{role}"),
        ("inner_arm", f"{model_id}-{role}.served"),
        ("model_id", model_id),
        ("compute_state_profile", PROFILES[role]),
        ("instrument", instrument if instrument is not None else INSTRUMENTS[role]),
        ("served_status", served_status),
        ("decode_tok_s", decode),
        ("package_watts", "17.0"),
        ("gfxclk_delivered_mean_mhz", "1100.0"),
        ("fclk_observed_mhz", "933"),
        ("tctl_peak_millidegrees", "62000"),
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


def verdict_lines(stdout):
    return stdout.rsplit("model_id\tarm\tstate\treason\n", 1)[1].splitlines()


def find_verdict(lines, arm):
    for line in lines:
        fields = line.split("\t")
        if len(fields) >= 3 and fields[1] == arm:
            return fields[2], "\t".join(fields[3:])
    return None, None


def main():
    failures = 0

    def report(condition, name):
        nonlocal failures
        status = "ok" if condition else "FAIL"
        print(f"{status} {name}")
        if not condition:
            failures += 1

    workdir = tempfile.mkdtemp()
    try:
        campaign = os.path.join(workdir, "campaign")
        os.makedirs(campaign)

        # A checkpoint whose controls agree within 20% and whose P2 exceeds P1
        # by more than 5% reads promoted.
        write_arm(campaign, "m1", "01-control-open", "9.00")
        write_arm(campaign, "m1", "02-p1-gfx-fclk-pin", "9.50")
        write_arm(campaign, "m1", "03-p2-cpu-capped", "10.20")
        write_arm(campaign, "m1", "04-p3-fclk-range", "10.10")
        write_arm(campaign, "m1", "05-p4-package-25w", "10.15")
        write_arm(campaign, "m1", "06-p4-cap-alt", "10.16")
        write_arm(campaign, "m1", "07-p4-ksm-alt", "10.14")
        write_arm(campaign, "m1", "08-p4-nice-bench-19", "9.90")
        write_arm(campaign, "m1", "09-p4-nice-bench-0", "9.95")
        write_arm(campaign, "m1", "10-control-close", "9.30")
        result = run_summarizer(campaign)
        lines = verdict_lines(result.stdout)
        state, reason = find_verdict(lines, "p2-cpu-capped")
        report(
            result.returncode == 0 and state == "promoted",
            "a candidate more than 5% above its predecessor is promoted",
        )
        state, _ = find_verdict(lines, "p3-fclk-range")
        report(
            state == "unresolved",
            "a candidate inside the 5% bound is unresolved rather than promoted",
        )

        # The nice factor-pair compares a bench arm against a bench arm and
        # is read normally.
        state, reason = find_verdict(lines, "p4-nice-bench-0")
        report(
            state is not None and "instrument=bench" in (reason or ""),
            "the nice factor-pair states its bench instrument in the reason",
        )

        # A served candidate compared against a bench predecessor (a
        # miswired ladder) is refused rather than producing a number.
        shutil.rmtree(campaign)
        os.makedirs(campaign)
        write_arm(campaign, "m2", "01-control-open", "9.00")
        write_arm(campaign, "m2", "02-p1-gfx-fclk-pin", "9.10")
        write_arm(campaign, "m2", "03-p2-cpu-capped", "9.20")
        write_arm(campaign, "m2", "04-p3-fclk-range", "9.20")
        write_arm(campaign, "m2", "05-p4-package-25w", "9.20")
        write_arm(campaign, "m2", "06-p4-cap-alt", "9.20")
        write_arm(campaign, "m2", "07-p4-ksm-alt", "9.20")
        write_arm(campaign, "m2", "08-p4-nice-bench-19", "9.00", instrument="served")
        write_arm(campaign, "m2", "09-p4-nice-bench-0", "9.10")
        write_arm(campaign, "m2", "10-control-close", "9.05")
        result = run_summarizer(campaign)
        lines = verdict_lines(result.stdout)
        state, reason = find_verdict(lines, "p4-nice-bench-0")
        report(
            state == "unresolved" and "instruments differ" in (reason or ""),
            "a comparison across served and bench instruments is refused",
        )

        # A checkpoint whose controls disagree beyond 20% leaves every
        # candidate unread.
        shutil.rmtree(campaign)
        os.makedirs(campaign)
        write_arm(campaign, "m3", "01-control-open", "5.00")
        write_arm(campaign, "m3", "02-p1-gfx-fclk-pin", "9.00")
        write_arm(campaign, "m3", "10-control-close", "9.00")
        result = run_summarizer(campaign)
        lines = verdict_lines(result.stdout)
        sweep_state, _ = find_verdict(lines, "sweep")
        state, _ = find_verdict(lines, "p1-gfx-fclk-pin")
        report(
            sweep_state == "unresolved" and state is None,
            "controls beyond the span criterion leave the ladder unread",
        )

        # A refused arm (served_status nonzero) contributes no rate.
        shutil.rmtree(campaign)
        os.makedirs(campaign)
        write_arm(campaign, "m4", "01-control-open", "9.00")
        write_arm(campaign, "m4", "02-p1-gfx-fclk-pin", "10.00", served_status="1")
        write_arm(campaign, "m4", "10-control-close", "9.10")
        result = run_summarizer(campaign)
        lines = verdict_lines(result.stdout)
        state, reason = find_verdict(lines, "p1-gfx-fclk-pin")
        report(
            state == "unresolved" and "no accepted rate" in (reason or ""),
            "a refused arm reads unresolved rather than contributing its rate",
        )

        # Usage errors are refused.
        bad = subprocess.run(
            [sys.executable, SUMMARIZER],
            capture_output=True,
            text=True,
            check=False,
        )
        report(bad.returncode == 2, "a missing campaign directory argument is refused")
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    if failures:
        print(f"summarize_power_factorial_tests=failed failures={failures}")
        return 1
    print("summarize_power_factorial_tests=passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
