#!/usr/bin/env python3
"""Read a power-factorial campaign directory and state its verdict per arm.

Each arm retains `arm-summary.tsv` under `arms/MODEL-SLOT-ROLE/`, written by
run-power-factorial-arm.sh, and the transaction that ran it retains its own
`restoration=held`/`restoration=failed` line in
`arms/MODEL-SLOT-ROLE.lease.std{out,err}`. This summarizer recomputes nothing
either one measured: it joins them into one table per checkpoint, reads the
two control arms (`01-control-open` and `09-control-close`, both
serve-auto-baseline) against each other under the 20% span criterion
evidence/power-envelope/README.md registers, and reads each candidate against
its own registered reference arm under a one-sided 5% promotion bound, the
bound CLAUDE.md's own E4-ladder rung 7 (`run-served-binary-ab.sh`) states for
a mirrored, control-bracketed comparison. A candidate promotes only where it
decodes at least 5% faster than its reference; every other outcome --
slower, or faster by less than 5% -- reads `not_promoted`, because the
falsifier evidence/power-factorial/README.md registers is a null result
until an arm clears that margin.

An arm is read only where its own served_status is 0; a refused arm reads
`unresolved` rather than contributing whatever rate it still retains. The
restoration table is a pass/fail column beside the rate table: any
`restoration=failed` line for an arm marks the whole checkpoint's verdict
`restoration_incident`, because a machine left on a forced state after one
arm invalidates the "in one sweep" reading the rest depend on.

usage: summarize-power-factorial.py CAMPAIGN_DIRECTORY [SUMMARY_TSV]
"""
import os
import re
import sys

SPAN_CRITERION = 0.20
# evidence/measurement-state-and-memory-clock.md, 3.11 against 3.24 tok/s under
# identical flags ten minutes apart on this machine.
MACHINE_SPREAD_FLOOR = 0.04
PROMOTION_BOUND = 0.05

CONTROL_OPEN = "01-control-open"
CONTROL_CLOSE = "09-control-close"

# Each candidate role names the reference role its own decode rate is read
# against. P3 is the campaign's unconditional best arm and the base every
# factor-pair alternate reads against; P4 is present only where the campaign
# gated it on a binding-package receipt.
COMPARISONS = (
    ("02-p1-gfx-fclk-pin", "control_mean", "P1 against the bracketing control mean"),
    ("03-p2-cpu-capped", "02-p1-gfx-fclk-pin", "P2 (CPU cap) against P1"),
    ("04-p3-fclk-range", "03-p2-cpu-capped", "P3 (FCLK range) against P2"),
    ("05-p3-ksm-alt", "04-p3-fclk-range", "the KSM factor-pair alternate against P3"),
    ("06-p3-cap-alt", "04-p3-fclk-range", "the CPU-cap factor-pair alternate against P3"),
    (
        "07-p3-nice-alt",
        "04-p3-fclk-range",
        "the nice factor-pair alternate against P3 (bench instrument, not served)",
    ),
    ("10-p4-package-25w", "04-p3-fclk-range", "P4 (package 25 W) against P3"),
)

RESTORATION_RE = re.compile(r"^restoration=(held|failed) profile=(\S+)")


def read_key_value(path):
    rows = {}
    try:
        with open(path) as handle:
            for line in handle:
                fields = line.rstrip("\n").split("\t")
                if len(fields) == 2:
                    rows[fields[0]] = fields[1]
    except OSError:
        return None
    return rows


def as_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def format_optional(value, digits):
    parsed = as_float(value)
    return "unavailable" if parsed is None else f"{parsed:.{digits}f}"


def readable_rate(rows):
    """The rate of an arm whose own served (or bench) runner returned zero."""
    if rows is None:
        return None
    if rows.get("served_status") != "0":
        return None
    return as_float(rows.get("decode_tok_s"))


def read_restoration(lease_stderr_path, lease_stdout_path):
    """The transaction's own restoration verdict for one arm.

    `restoration=held` reaches stdout; `restoration=failed` reaches both
    stdout and stderr (compute-state-lease.sh prints it twice, once to each),
    so stderr is read first and stdout is the fallback for the ordinary case.
    """
    for path in (lease_stderr_path, lease_stdout_path):
        try:
            with open(path) as handle:
                text = handle.read()
        except OSError:
            continue
        match = RESTORATION_RE.search(text)
        if match:
            return match.group(1), match.group(2)
    return "absent", "unknown"


def collect_checkpoints(campaign_directory):
    arms_directory = os.path.join(campaign_directory, "arms")
    checkpoints = {}
    try:
        entries = sorted(os.listdir(arms_directory))
    except OSError:
        raise SystemExit(f"campaign holds no arms directory: {arms_directory}") from None
    for entry in entries:
        summary_path = os.path.join(arms_directory, entry, "arm-summary.tsv")
        if not os.path.isfile(summary_path):
            continue
        rows = read_key_value(summary_path)
        if rows is None or rows.get("schema") != "power-factorial-arm-v1":
            continue
        model_id = rows.get("model_id", "unknown")
        role = entry[len(model_id) + 1:] if entry.startswith(model_id + "-") else entry
        restoration_state, restoration_profile = read_restoration(
            os.path.join(arms_directory, f"{entry}.lease.stderr"),
            os.path.join(arms_directory, f"{entry}.lease.stdout"),
        )
        rows["restoration_state"] = restoration_state
        rows["restoration_profile"] = restoration_profile
        checkpoints.setdefault(model_id, {})[role] = rows
    return checkpoints


def summarize(campaign_directory, summary_path):
    checkpoints = collect_checkpoints(campaign_directory)
    if not checkpoints:
        raise SystemExit(f"campaign holds no readable arm: {campaign_directory}")

    table_lines = [
        "model_id\tarm\tprofile\tinstrument\tdecode_tok_s\tksmd_ticks_delta\t"
        "qemu_ticks_delta\trestoration_state"
    ]
    restoration_lines = ["model_id\tarm\tprofile\trestoration_state"]
    verdict_lines = []

    for model_id in sorted(checkpoints):
        arms = checkpoints[model_id]
        checkpoint_restoration_incident = False
        for role in sorted(arms):
            rows = arms[role]
            table_lines.append(
                "\t".join(
                    (
                        model_id,
                        role,
                        rows.get("compute_state_profile", "unknown"),
                        rows.get("instrument", "unknown"),
                        format_optional(rows.get("decode_tok_s"), 3),
                        rows.get("ksmd_ticks_delta", "unavailable"),
                        rows.get("qemu_ticks_delta", "unavailable"),
                        rows.get("restoration_state", "absent"),
                    )
                )
            )
            restoration_lines.append(
                f"{model_id}\t{role}\t{rows.get('restoration_profile', 'unknown')}\t"
                f"{rows.get('restoration_state', 'absent')}"
            )
            if rows.get("restoration_state") == "failed":
                checkpoint_restoration_incident = True

        if checkpoint_restoration_incident:
            verdict_lines.append(
                f"{model_id}\tsweep\trestoration_incident\tat least one arm's "
                "transaction failed to restore; every reading in this "
                "checkpoint is read against a machine state nobody proved"
            )
            continue

        opening = readable_rate(arms.get(CONTROL_OPEN))
        closing = readable_rate(arms.get(CONTROL_CLOSE))
        if opening is None or closing is None:
            verdict_lines.append(
                f"{model_id}\tsweep\tunresolved\tone control arm carries no "
                "accepted rate"
            )
            continue
        control_mean = (opening + closing) / 2
        control_spread = abs(closing - opening) / control_mean if control_mean else None
        if control_spread is None or control_spread > SPAN_CRITERION:
            verdict_lines.append(
                f"{model_id}\tsweep\tunresolved\tcontrol spread "
                f"{'undefined' if control_spread is None else f'{control_spread:.1%}'} "
                f"exceeds the {SPAN_CRITERION:.0%} span criterion"
            )
            continue
        verdict_lines.append(
            f"{model_id}\tsweep\tresolved\tcontrol spread {control_spread:.1%} "
            f"within the {SPAN_CRITERION:.0%} span criterion, control mean "
            f"{control_mean:.3f} tok/s"
        )

        rates = {CONTROL_OPEN: opening, CONTROL_CLOSE: closing, "control_mean": control_mean}
        for role, reference_role, description in COMPARISONS:
            rows = arms.get(role)
            if rows is None:
                # P4 is absent whenever the campaign's package receipt did not
                # show a binding budget; that is the gate working as
                # registered rather than a missing measurement.
                if role == "10-p4-package-25w":
                    verdict_lines.append(
                        f"{model_id}\t{role}\tnot_run\tP4 requires a binding "
                        "package-limit receipt from the sustained arm; "
                        "run-power-factorial-campaign.sh did not admit it"
                    )
                    continue
                verdict_lines.append(
                    f"{model_id}\t{role}\tunresolved\tthe arm did not run"
                )
                continue
            candidate = readable_rate(rows)
            if candidate is None:
                verdict_lines.append(
                    f"{model_id}\t{role}\tunresolved\tthe arm carries no "
                    "accepted rate"
                )
                continue
            reference = rates.get(reference_role)
            if reference is None:
                reference_rows = arms.get(reference_role)
                reference = readable_rate(reference_rows)
                rates[reference_role] = reference
            if reference is None or reference == 0:
                verdict_lines.append(
                    f"{model_id}\t{role}\tunresolved\treference arm "
                    f"{reference_role} carries no accepted rate"
                )
                continue
            rates[role] = candidate
            relative = (candidate - reference) / reference
            if relative >= PROMOTION_BOUND:
                state = "promoted"
            else:
                state = "not_promoted"
            reason = (
                f"{description}: {relative:+.1%} against {reference:.3f} tok/s, "
                f"one-sided {PROMOTION_BOUND:.0%} promotion bound"
            )
            verdict_lines.append(f"{model_id}\t{role}\t{state}\t{reason}")

    text = (
        "\n".join(table_lines)
        + "\n\n"
        + "\n".join(restoration_lines)
        + "\n\n"
        + "model_id\tarm\tstate\treason\n"
        + "\n".join(verdict_lines)
        + "\n"
    )
    if summary_path is not None:
        with open(summary_path, "w") as handle:
            handle.write(text)
    sys.stdout.write(text)
    return 0


def main(argv):
    if len(argv) not in (1, 2):
        sys.stderr.write(
            "usage: summarize-power-factorial.py CAMPAIGN_DIRECTORY [SUMMARY_TSV]\n"
        )
        return 2
    return summarize(argv[0], argv[1] if len(argv) == 2 else None)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
