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
# The stock envelope's own STAPM averaging window. The sustained arm exists to
# span it, and a token count states a duration only against a rate, so the
# reader divides the arm's own recorded count by its own measured rate rather
# than inferring the duration from a class estimate.
SUSTAINED_WINDOW_SECONDS = 200.0
SUSTAINED_ARM = "08-sustained-stock"
PACKAGE_ARM = "10-p4-package-25w"

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

RESTORATION_RE = re.compile(r"^restoration=(held|failed) profile=(\S+)$")


def read_key_value(path):
    """One arm's summary, refused where a key repeats or a row is malformed.

    A repeated key is what makes a later `served_status=0` overwrite an
    earlier refusal, so the reader takes a row rather than the last row: a
    duplicate and a width other than two fields both mark the whole file
    unreadable, which reads downstream as an arm carrying no accepted rate.
    """
    rows = {}
    try:
        with open(path) as handle:
            for line in handle:
                line = line.rstrip("\n")
                if not line:
                    continue
                fields = line.split("\t")
                if len(fields) != 2:
                    return None
                if fields[0] in rows:
                    return None
                rows[fields[0]] = fields[1]
    except OSError:
        return None
    return rows


def as_float(value):
    """A finite float, or None.

    `float()` accepts `inf` and `nan`, and an infinite rate clears every
    threshold this reader tests while a NaN compares false against all of
    them, so neither reaches a verdict.
    """
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None
    if parsed != parsed or parsed in (float("inf"), float("-inf")):
        return None
    return parsed


def format_optional(value, digits):
    parsed = as_float(value)
    return "unavailable" if parsed is None else f"{parsed:.{digits}f}"


def readable_rate(rows):
    """The rate of an arm whose own served (or bench) runner returned zero.

    A decode rate is a strictly positive finite number of tokens per second.
    Zero and below name an arm that produced nothing rather than an arm that
    was slow, and they divide into the relative comparison downstream.
    """
    if rows is None:
        return None
    if rows.get("served_status") != "0":
        return None
    rate = as_float(rows.get("decode_tok_s"))
    if rate is None or rate <= 0:
        return None
    return rate


def read_restoration(lease_stderr_path, lease_stdout_path):
    """The transaction's own restoration verdict for one arm.

    `restoration=held` reaches stdout; `restoration=failed` reaches both
    stdout and stderr, since compute-state-lease.sh prints it once to each,
    so both streams are read whole and every line is tested. An anchored
    pattern searched over a file's entire text matches its first line alone,
    which is why a lease log opening on any other row read `absent` while
    carrying a real failure further down.

    A failure dominates: an arm whose streams carry both verdicts left the
    machine on a forced state whatever an earlier line claimed. Two lines
    naming one verdict and different profiles state two transactions under
    one arm, which no reading resolves, so that reads `conflict`.
    """
    verdicts = []
    for path in (lease_stderr_path, lease_stdout_path):
        try:
            with open(path) as handle:
                for line in handle:
                    match = RESTORATION_RE.match(line.rstrip("\n"))
                    if match:
                        verdicts.append((match.group(1), match.group(2)))
        except OSError:
            continue
    if not verdicts:
        return "absent", "unknown"
    failures = [verdict for verdict in verdicts if verdict[0] == "failed"]
    if failures:
        profiles = {profile for _, profile in failures}
        if len(profiles) > 1:
            return "conflict", ",".join(sorted(profiles))
        return "failed", failures[0][1]
    profiles = {profile for _, profile in verdicts}
    if len(profiles) > 1:
        return "conflict", ",".join(sorted(profiles))
    return "held", verdicts[0][1]


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
        checkpoint_restoration_unproven = False
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
            elif rows.get("restoration_state") in ("absent", "conflict"):
                # A failure that was not observed is not invented: an arm
                # whose transaction retained no readable verdict proves
                # nothing about the state the machine was left in, which
                # withholds promotion without claiming an incident.
                checkpoint_restoration_unproven = True

        if checkpoint_restoration_unproven and not checkpoint_restoration_incident:
            verdict_lines.append(
                f"{model_id}\tsweep\tunresolved\tat least one arm retained no "
                "readable restoration verdict, so the compute state it left "
                "behind is unproven and no arm of this checkpoint promotes"
            )
            continue
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

        # The sustained arm's duration is its own token count over its own
        # measured rate. A count chosen against one checkpoint's rate spans
        # the window for that checkpoint alone, so the arm that actually ran
        # is what the reader divides.
        sustained_rows = arms.get(SUSTAINED_ARM)
        sustained_seconds = None
        sustained_reason = "the sustained arm did not run"
        if sustained_rows is not None:
            sustained_rate = readable_rate(sustained_rows)
            sustained_tokens = as_float(sustained_rows.get("generate_tokens"))
            if sustained_rate is None:
                sustained_reason = "the sustained arm carries no accepted rate"
            elif sustained_tokens is None or sustained_tokens <= 0:
                sustained_reason = "the sustained arm records no token count"
            else:
                sustained_seconds = sustained_tokens / sustained_rate
                sustained_reason = (
                    f"{sustained_tokens:.0f} tokens at {sustained_rate:.3f} tok/s "
                    f"is {sustained_seconds:.0f} s"
                )
        if sustained_seconds is not None and sustained_seconds >= SUSTAINED_WINDOW_SECONDS:
            verdict_lines.append(
                f"{model_id}\t{SUSTAINED_ARM}\tspans_the_window\t{sustained_reason}, "
                f"over the {SUSTAINED_WINDOW_SECONDS:.0f} s averaging window"
            )
        else:
            verdict_lines.append(
                f"{model_id}\t{SUSTAINED_ARM}\tunresolved\t{sustained_reason}, "
                f"under the {SUSTAINED_WINDOW_SECONDS:.0f} s averaging window, so "
                "the package snapshots bracket part of it rather than the whole"
            )

        for role, reference_role, description in COMPARISONS:
            rows = arms.get(role)
            if rows is None:
                # P4 is absent whenever the campaign's package receipt did not
                # show a binding budget; that is the gate working as
                # registered rather than a missing measurement.
                if role == PACKAGE_ARM:
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
            if role == PACKAGE_ARM and (
                sustained_seconds is None or sustained_seconds < SUSTAINED_WINDOW_SECONDS
            ):
                verdict_lines.append(
                    f"{model_id}\t{role}\tunresolved\tP4 reads the sustained "
                    f"arm's package receipt, and that arm did not span the "
                    f"{SUSTAINED_WINDOW_SECONDS:.0f} s averaging window: "
                    f"{sustained_reason}"
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

            # Two arms measured by different instruments differ by the
            # instrument as well as by the factor, and this campaign runs one
            # bench arm against served references. The comparison still reads,
            # and it names an instrument difference rather than a factor
            # effect, so it never promotes.
            candidate_instrument = rows.get("instrument", "unknown")
            reference_instrument = (
                arms.get(reference_role, {}) or {}
            ).get("instrument", "unknown") if reference_role != "control_mean" else (
                (arms.get(CONTROL_OPEN, {}) or {}).get("instrument", "unknown")
            )
            reason = (
                f"{description}: {relative:+.1%} against {reference:.3f} tok/s, "
                f"one-sided {PROMOTION_BOUND:.0%} promotion bound"
            )
            if candidate_instrument != reference_instrument:
                verdict_lines.append(
                    f"{model_id}\t{role}\tdiagnostic\t{reason}; the candidate "
                    f"reads {candidate_instrument} against a "
                    f"{reference_instrument} reference, so the difference "
                    "carries the instrument beside the factor and promotes "
                    "nothing"
                )
                continue
            if relative >= PROMOTION_BOUND:
                state = "screened"
            else:
                state = "not_screened"
            verdict_lines.append(
                f"{model_id}\t{role}\t{state}\t{reason}; a point gain over "
                "single arms is a screening result, so a promising factor "
                "reaches the matched confirmation harness before production "
                "policy moves"
            )

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
