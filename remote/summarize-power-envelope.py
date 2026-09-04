#!/usr/bin/env python3
"""Read a package-power campaign directory and state its verdict per checkpoint.

Each arm retains `arm-summary.tsv`, and this summarizer recomputes nothing the
arm measured: it joins the four arms of a checkpoint into one table, reads the
two control arms against each other under the span criterion
`evidence/power-envelope/README.md` registers, and reads each candidate against
the control mean under the wider of that checkpoint's control spread and this
machine's own retained spread. An arm is read only where its served runner and
its energy reader both returned zero and its window came back bracketed, so a
refused arm reads `unresolved` rather than contributing the rate it still
retains.

The span criterion is 20% of the control mean, which is the single-arm span this
tree carries. A checkpoint whose controls differ by more than that ends
`unresolved` and its candidates are not read at all, because a sweep that cannot
reproduce its own opening arm cannot attribute a difference to the budget.

A candidate is then read against the wider of two bands, and the second one is
what keeps a two-point control from asserting a direction it cannot carry. The
first band is the checkpoint's own observed control-to-control difference, which
at two arms is a difference rather than an uncertainty and collapses toward zero
whenever the two controls happen to agree closely. The second is the 4% of
uncontrolled spread `evidence/measurement-state-and-memory-clock.md` measures on
this machine, where one checkpoint under identical flags read 3.11 and 3.24
tok/s ten minutes apart; that figure comes from a run outside this campaign, so
it cannot be tuned by the arms it judges. A candidate inside the wider band is
`unresolved` in direction rather than null, and the reason column carries the
raw percentage and the package watts either way, which is what separates a
budget that was never drawn from one drawn to no effect.

usage: summarize-power-envelope.py CAMPAIGN_DIRECTORY [SUMMARY_TSV]
"""
import os
import sys

SPAN_CRITERION = 0.20
# evidence/measurement-state-and-memory-clock.md, 3.11 against 3.24 tok/s under
# identical flags ten minutes apart on this machine.
MACHINE_SPREAD_FLOOR = 0.04
ARM_ROLES = ("01-control-open", "02-package-20w", "03-package-25w", "04-control-close")


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


def readable_rate(rows):
    """The rate of an arm that completed, or None.

    An arm carries a decode rate whether or not the runner, the energy reader,
    and the bracket selection accepted it, so a verdict that read the rate alone
    could call a refused arm faster than its control. The three fields the arm
    already retains are what admit it: the served runner's own status, the energy
    reader's status, and the window coverage the bracket selection reported.
    """
    if rows is None:
        return None
    if rows.get("served_status") != "0" or rows.get("energy_status") != "0":
        return None
    if rows.get("window_coverage") != "bracketed":
        return None
    return as_float(rows.get("decode_tok_s"))


def as_float(value):
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None
    return parsed


def millidegrees_to_c(value):
    parsed = as_float(value)
    return "unavailable" if parsed is None else f"{parsed / 1000:.1f}"


def format_optional(value, digits):
    parsed = as_float(value)
    return "unavailable" if parsed is None else f"{parsed:.{digits}f}"


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
        if rows is None or rows.get("schema") != "power-envelope-arm-v1":
            continue
        model_id = rows.get("model_id", "unknown")
        role = entry[len(model_id) + 1:] if entry.startswith(model_id + "-") else entry
        checkpoints.setdefault(model_id, {})[role] = rows
    return checkpoints


def summarize(campaign_directory, summary_path):
    checkpoints = collect_checkpoints(campaign_directory)
    if not checkpoints:
        raise SystemExit(f"campaign holds no readable arm: {campaign_directory}")
    table_lines = [
        (
            "model_id\tarm\tprofile\tdecode_tok_s\tpackage_watts\tcore_watts\t"
            "package_watts_outer\tgfxclk_delivered_mhz\tfclk_mhz\ttctl_peak_c\t"
            "edge_peak_c\twindow_coverage"
        )
    ]
    verdict_lines = []
    for model_id in sorted(checkpoints):
        arms = checkpoints[model_id]
        for role in ARM_ROLES:
            rows = arms.get(role)
            if rows is None:
                table_lines.append(
                    f"{model_id}\t{role}\tabsent\t-\t-\t-\t-\t-\t-\t-\t-\tabsent"
                )
                continue
            table_lines.append(
                "\t".join(
                    (
                        model_id,
                        role,
                        rows.get("compute_state_profile", "unknown"),
                        format_optional(rows.get("decode_tok_s"), 3),
                        format_optional(rows.get("package_watts"), 3),
                        format_optional(rows.get("core_watts"), 3),
                        format_optional(rows.get("package_watts_outer"), 3),
                        format_optional(rows.get("gfxclk_delivered_mean_mhz"), 1),
                        rows.get("fclk_observed_mhz", "unavailable"),
                        millidegrees_to_c(rows.get("tctl_peak_millidegrees")),
                        millidegrees_to_c(rows.get("edge_peak_millidegrees")),
                        rows.get("window_coverage", "unavailable"),
                    )
                )
            )
        opening = readable_rate(arms.get(ARM_ROLES[0]))
        closing = readable_rate(arms.get(ARM_ROLES[3]))
        if opening is None or closing is None:
            verdict_lines.append(
                f"{model_id}\tsweep\tunresolved\tone control arm carries no "
                "accepted rate"
            )
            continue
        control_mean = (opening + closing) / 2
        control_spread = abs(closing - opening) / control_mean
        if control_spread > SPAN_CRITERION:
            verdict_lines.append(
                f"{model_id}\tsweep\tunresolved\tcontrol spread {control_spread:.1%} "
                f"exceeds the {SPAN_CRITERION:.0%} span criterion"
            )
            continue
        verdict_lines.append(
            f"{model_id}\tsweep\tresolved\tcontrol spread {control_spread:.1%} "
            f"within the {SPAN_CRITERION:.0%} span criterion, control mean "
            f"{control_mean:.3f} tok/s"
        )
        for role in ARM_ROLES[1:3]:
            rows = arms.get(role)
            candidate = readable_rate(rows)
            if candidate is None:
                verdict_lines.append(
                    f"{model_id}\t{role}\tunresolved\tthe arm carries no "
                    "accepted rate"
                )
                continue
            relative = (candidate - control_mean) / control_mean
            readable_band = max(control_spread, MACHINE_SPREAD_FLOOR)
            band_source = (
                "control spread"
                if control_spread >= MACHINE_SPREAD_FLOOR
                else "machine spread floor"
            )
            if abs(relative) <= readable_band:
                state = "unresolved"
                reason = (
                    f"{relative:+.1%} against the control mean sits inside the "
                    f"{readable_band:.1%} {band_source}"
                )
            else:
                state = "faster" if relative > 0 else "slower"
                reason = (
                    f"{relative:+.1%} against the control mean exceeds the "
                    f"{readable_band:.1%} {band_source}"
                )
            control_watts = [
                as_float((arms.get(control_role) or {}).get("package_watts"))
                for control_role in (ARM_ROLES[0], ARM_ROLES[3])
            ]
            candidate_watts = as_float((rows or {}).get("package_watts"))
            if candidate_watts is not None and all(w is not None for w in control_watts):
                control_watts_mean = sum(control_watts) / len(control_watts)
                reason += (
                    f"; package {candidate_watts:.2f} W against the control mean "
                    f"{control_watts_mean:.2f} W"
                )
            verdict_lines.append(f"{model_id}\t{role}\t{state}\t{reason}")
    text = "\n".join(table_lines) + "\n\n" + \
        "model_id\tarm\tstate\treason\n" + "\n".join(verdict_lines) + "\n"
    if summary_path is not None:
        with open(summary_path, "w") as handle:
            handle.write(text)
    sys.stdout.write(text)
    return 0


def main(argv):
    if len(argv) not in (1, 2):
        sys.stderr.write("usage: summarize-power-envelope.py CAMPAIGN_DIRECTORY [SUMMARY_TSV]\n")
        return 2
    return summarize(argv[0], argv[1] if len(argv) == 2 else None)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
