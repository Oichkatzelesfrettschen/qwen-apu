#!/usr/bin/env python3
"""Read a power-factorial campaign directory and state its verdict per arm.

Each arm retains `arm-summary.tsv` under `power-factorial-arm-v1`, and this
summarizer recomputes nothing an arm measured: it reads the served harness's
own arm-summary.tsv (under `power-envelope-arm-v1`, wrapped one directory
down) through the factorial arm's own `decode_tok_s` field, joins the ladder
into one table, and reads the opening and closing `serve-auto-baseline`
controls against each other under the 20% span criterion
evidence/power-envelope/README.md already registers for this machine's own
control-to-control agreement. A checkpoint whose controls disagree by more
than that ends `unresolved` and every candidate arm is read as `unresolved`
too, because a sweep that cannot reproduce its own opening arm cannot
attribute a difference to the compute state.

Every pairwise comparison in the ladder -- P1 against the opening control, P2
against P1, P3 against P2, P4 against P3, and each factor-pair alternate
against P4 -- is a one-sided promotion test at a 5% bound: a candidate is
`promoted` only where it exceeds its predecessor by more than 5%, `regressed`
where it falls short by more than 5%, and `unresolved` where the two sit
inside that band, which is a null result rather than a tie broken either way.
5% is the bound evidence/power-factorial/README.md registers ahead of this
summarizer's first run; it is not tuned by an arm the summarizer reads.

An arm is read only where its own served or bench instrument returned zero,
so a refused arm reads `unresolved` rather than contributing the rate it still
retains. Two arms compared here must carry the same `instrument` field
(`served` or `bench`): the nice factor-pair runs entirely under `bench`
because the served harness cannot express its nice-19 arm at all (the guarded
launch chain's monitor-qwen-runtime.sh self-renices to 0 unconditionally), and
a bench decode rate and a served decode rate are two different instruments
measuring two different execution paths, so a comparison across them is
refused outright rather than producing a number that looks like a compute-state
effect.

usage: summarize-power-factorial.py CAMPAIGN_DIRECTORY [SUMMARY_TSV]
"""

import os
import sys

CONTROL_SPAN_CRITERION = 0.20
PROMOTION_BOUND = 0.05

# (role, predecessor role, label) for every comparison the ladder reads. The
# opening and closing controls are read against each other first, separately.
LADDER_COMPARISONS = (
    ("p1-gfx-fclk-pin", "control-open", "P1 against the opening control"),
    ("p2-cpu-capped", "p1-gfx-fclk-pin", "P2 against P1"),
    ("p3-fclk-range", "p2-cpu-capped", "P3 against P2"),
    ("p4-package-25w", "p3-fclk-range", "P4 against P3"),
    ("p4-cap-alt", "p4-package-25w", "the CPU-cap factor-pair alternate against P4"),
    ("p4-ksm-alt", "p4-package-25w", "the KSM factor-pair alternate against P4"),
    (
        "p4-nice-bench-0",
        "p4-nice-bench-19",
        "the nice factor-pair's nice-0 arm against its nice-19 arm",
    ),
)


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
        parsed = float(value)
    except (TypeError, ValueError):
        return None
    return parsed


def readable_arm(rows):
    """The (decode_tok_s, instrument) pair of an arm that completed, or None.

    An arm-summary.tsv carries a decode rate whether or not the underlying
    instrument accepted it, so a verdict that read the rate alone could call a
    refused arm faster than its predecessor.
    """
    if rows is None or rows.get("schema") != "power-factorial-arm-v1":
        return None
    if rows.get("served_status") != "0":
        return None
    rate = as_float(rows.get("decode_tok_s"))
    if rate is None:
        return None
    instrument = rows.get("instrument")
    if instrument not in ("served", "bench"):
        return None
    return rate, instrument


def collect_arms(campaign_directory):
    arms_directory = os.path.join(campaign_directory, "arms")
    checkpoints = {}
    try:
        entries = sorted(os.listdir(arms_directory))
    except OSError:
        raise SystemExit(
            f"campaign holds no arms directory: {arms_directory}"
        ) from None
    for entry in entries:
        summary_path = os.path.join(arms_directory, entry, "arm-summary.tsv")
        if not os.path.isfile(summary_path):
            continue
        rows = read_key_value(summary_path)
        if rows is None or rows.get("schema") != "power-factorial-arm-v1":
            continue
        model_id = rows.get("model_id", "unknown")
        role = entry[len(model_id) + 1 :] if entry.startswith(model_id + "-") else entry
        # Strip the leading two-digit slot ("01-control-open" -> "control-open")
        # so the ladder's own role names match regardless of slot numbering.
        role_name = (
            role.split("-", 1)[1] if role[:2].isdigit() and "-" in role else role
        )
        checkpoints.setdefault(model_id, {})[role_name] = rows
    return checkpoints


def compare(predecessor_rate, candidate_rate):
    relative = (candidate_rate - predecessor_rate) / predecessor_rate
    if relative > PROMOTION_BOUND:
        return "promoted", relative
    if relative < -PROMOTION_BOUND:
        return "regressed", relative
    return "unresolved", relative


def summarize(campaign_directory, summary_path):
    checkpoints = collect_arms(campaign_directory)
    if not checkpoints:
        raise SystemExit(f"campaign holds no readable arm: {campaign_directory}")
    table_lines = ["model_id\tarm\tprofile\tinstrument\tdecode_tok_s\tstatus"]
    verdict_lines = []
    for model_id in sorted(checkpoints):
        arms = checkpoints[model_id]
        for role_name in sorted(arms):
            rows = arms[role_name]
            resolved = readable_arm(rows)
            rate_text = f"{resolved[0]:.3f}" if resolved else "-"
            instrument_text = (
                resolved[1] if resolved else rows.get("instrument", "unavailable")
            )
            status_text = "accepted" if resolved else "refused"
            table_lines.append(
                "\t".join(
                    (
                        model_id,
                        role_name,
                        rows.get("compute_state_profile", "unknown"),
                        instrument_text,
                        rate_text,
                        status_text,
                    )
                )
            )
        opening = readable_arm(arms.get("control-open"))
        closing = readable_arm(arms.get("control-close"))
        if opening is None or closing is None:
            verdict_lines.append(
                f"{model_id}\tsweep\tunresolved\tone control arm carries no accepted rate"
            )
            continue
        opening_rate, opening_instrument = opening
        closing_rate, closing_instrument = closing
        if opening_instrument != closing_instrument:
            verdict_lines.append(
                f"{model_id}\tsweep\tunresolved\tcontrol arms carry different "
                f"instruments ({opening_instrument} against {closing_instrument})"
            )
            continue
        control_mean = (opening_rate + closing_rate) / 2
        control_spread = abs(closing_rate - opening_rate) / control_mean
        if control_spread > CONTROL_SPAN_CRITERION:
            verdict_lines.append(
                f"{model_id}\tsweep\tunresolved\tcontrol spread {control_spread:.1%} "
                f"exceeds the {CONTROL_SPAN_CRITERION:.0%} span criterion"
            )
            continue
        verdict_lines.append(
            f"{model_id}\tsweep\tresolved\tcontrol spread {control_spread:.1%} "
            f"within the {CONTROL_SPAN_CRITERION:.0%} span criterion, control "
            f"mean {control_mean:.3f} tok/s"
        )
        for candidate_role, predecessor_role, label in LADDER_COMPARISONS:
            candidate_rows = arms.get(candidate_role)
            predecessor_rows = arms.get(predecessor_role)
            candidate = readable_arm(candidate_rows)
            predecessor = readable_arm(predecessor_rows)
            if candidate is None or predecessor is None:
                verdict_lines.append(
                    f"{model_id}\t{candidate_role}\tunresolved\t{label}: one "
                    "arm carries no accepted rate"
                )
                continue
            candidate_rate, candidate_instrument = candidate
            predecessor_rate, predecessor_instrument = predecessor
            if candidate_instrument != predecessor_instrument:
                verdict_lines.append(
                    f"{model_id}\t{candidate_role}\tunresolved\t{label}: "
                    f"instruments differ ({candidate_instrument} against "
                    f"{predecessor_instrument}), refused rather than compared"
                )
                continue
            state, relative = compare(predecessor_rate, candidate_rate)
            verdict_lines.append(
                f"{model_id}\t{candidate_role}\t{state}\t{label}: "
                f"{relative:+.1%} against the {PROMOTION_BOUND:.0%} one-sided bound "
                f"({predecessor_rate:.3f} to {candidate_rate:.3f} tok/s, "
                f"instrument={candidate_instrument})"
            )
    text = (
        "\n".join(table_lines)
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
