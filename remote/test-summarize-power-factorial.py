#!/usr/bin/env python3
"""Drive summarize-power-factorial.py against fixture campaign directories.

Each arm reaches the reader as `arms/MODEL-SLOT-ROLE/arm-summary.tsv` beside
`arms/MODEL-SLOT-ROLE.lease.stdout` and `.lease.stderr`, so every fixture here
writes that shape and reads the verdict block the summarizer prints. The arms
carry rates rather than the reader recomputing anything, which is what makes a
malformed rate a reader question rather than a measurement one.

The suite states what the reader refuses to interpret: a rate that is not a
finite positive number, an arm summary whose keys repeat or whose row width is
wrong, a restoration verdict the reader cannot locate or cannot resolve, and a
comparison whose two arms were measured by different instruments. Each of
those reaches a verdict that withholds promotion, and the mutation controls at
the end remove one guard at a time and require the suite to notice.

usage: test-summarize-power-factorial.py
"""
import os
import pathlib
import re
import subprocess
import sys
import tempfile

SCRIPT_DIRECTORY = pathlib.Path(__file__).resolve().parent
SUMMARIZER = SCRIPT_DIRECTORY / "summarize-power-factorial.py"

MODEL = "qwen38-2b-distill"
CONTROL_OPEN = "01-control-open"
CONTROL_CLOSE = "09-control-close"
P1 = "02-p1-gfx-fclk-pin"
P2 = "03-p2-cpu-capped"
P3 = "04-p3-fclk-range"
NICE_ALT = "07-p3-nice-alt"

failures = []


def report(name, outcome):
    if outcome == "ok":
        print(f"ok {name}")
    else:
        print(f"FAIL {name}: {outcome}")
        failures.append(name)


def write_arm(
    campaign,
    role,
    rate,
    *,
    served_status="0",
    instrument="served",
    restoration="held",
    profile="measure-fixed",
    preamble=(),
    extra_rows=(),
    raw_summary=None,
):
    """One arm in the shape run-power-factorial-arm.sh leaves behind."""
    arm = f"{MODEL}-{role}"
    directory = campaign / "arms" / arm
    directory.mkdir(parents=True, exist_ok=True)
    if raw_summary is None:
        rows = [
            ("schema", "power-factorial-arm-v1"),
            ("model_id", MODEL),
            ("instrument", instrument),
            ("served_status", served_status),
            ("decode_tok_s", str(rate)),
            ("ksmd_ticks_delta", "0"),
            ("qemu_ticks_delta", "0"),
        ]
        rows.extend(extra_rows)
        raw_summary = "".join(f"{key}\t{value}\n" for key, value in rows)
    (directory / "arm-summary.tsv").write_text(raw_summary)

    # The lease prints `held` to stdout alone and `failed` to both streams,
    # so a fixture writes what the transaction would have written.
    stdout_lines = list(preamble)
    stderr_lines = []
    if restoration is not None:
        for verdict, verdict_profile in (
            restoration if isinstance(restoration, list) else [(restoration, profile)]
        ):
            stdout_lines.append(f"restoration={verdict} profile={verdict_profile}")
            if verdict == "failed":
                stderr_lines.append(f"restoration={verdict} profile={verdict_profile}")
    (campaign / "arms" / f"{arm}.lease.stdout").write_text(
        "".join(f"{line}\n" for line in stdout_lines)
    )
    (campaign / "arms" / f"{arm}.lease.stderr").write_text(
        "".join(f"{line}\n" for line in stderr_lines)
    )


def build_campaign(directory, **overrides):
    """A campaign whose controls bracket cleanly and whose P1 clears the bound."""
    campaign = pathlib.Path(directory)
    defaults = {
        CONTROL_OPEN: dict(rate=9.00),
        CONTROL_CLOSE: dict(rate=9.10),
        P1: dict(rate=10.00),
        P2: dict(rate=10.05),
        P3: dict(rate=10.10),
    }
    for role, arm in defaults.items():
        write_arm(campaign, role, **{**arm, **overrides.get(role, {})})
    for role, arm in overrides.items():
        if role not in defaults:
            write_arm(campaign, role, **arm)
    return campaign


def run_summarizer(campaign, summarizer=SUMMARIZER):
    completed = subprocess.run(
        [sys.executable, str(summarizer), str(campaign)],
        capture_output=True,
        text=True,
    )
    return completed


def verdict_for(text, role):
    """The verdict block's row for one arm.

    The summary prints three blocks -- the rate table, the restoration table,
    and the verdicts -- and the first two also key on model and arm, so a
    reader taking the first match reads a profile column as a state. The
    block is selected by its own header.
    """
    in_verdicts = False
    for line in text.splitlines():
        if line == "model_id\tarm\tstate\treason":
            in_verdicts = True
            continue
        if not in_verdicts:
            continue
        fields = line.split("\t")
        if len(fields) >= 3 and fields[0] == MODEL and fields[1] == role:
            return fields[2], fields[3] if len(fields) > 3 else ""
    return None, ""


def check(name, expectation, overrides, role, summarizer=SUMMARIZER):
    with tempfile.TemporaryDirectory() as directory:
        campaign = build_campaign(directory, **overrides)
        completed = run_summarizer(campaign, summarizer)
        if completed.returncode != 0:
            report(name, f"summarizer exited {completed.returncode}: {completed.stderr[-200:]}")
            return None
        state, reason = verdict_for(completed.stdout, role)
        if state == expectation:
            report(name, "ok")
        else:
            report(name, f"{role} read {state!r} ({reason[:90]}) rather than {expectation!r}")
        return completed.stdout


# ---- the shape the reader is meant to interpret ----
check(
    "a bracketed control pair and a clearing candidate screen",
    "screened",
    {},
    P1,
)
check(
    "a candidate inside the bound does not screen",
    "not_screened",
    {P2: dict(rate=10.05)},
    P2,
)

# ---- restoration parsing ----
# The failure sits under a preamble, which an anchored search over the whole
# file never reaches.
check(
    "a failure below a preamble is read",
    "restoration_incident",
    {P1: dict(rate=10.00, restoration="failed", preamble=("setup=done", "profile=measure-fixed"))},
    "sweep",
)
check(
    "a failure on the first line is read",
    "restoration_incident",
    {P1: dict(rate=10.00, restoration="failed")},
    "sweep",
)
check(
    "a failure dominates an earlier held line",
    "restoration_incident",
    {
        P1: dict(
            rate=10.00,
            restoration=[("held", "measure-fixed"), ("failed", "measure-fixed")],
        )
    },
    "sweep",
)
check(
    "two held lines naming different profiles conflict",
    "unresolved",
    {
        P1: dict(
            rate=10.00,
            restoration=[("held", "measure-fixed"), ("held", "serve-performance-candidate")],
        )
    },
    "sweep",
)
check(
    "an arm retaining no restoration line is unproven rather than passing",
    "unresolved",
    {P1: dict(rate=10.00, restoration=None)},
    "sweep",
)

# A held verdict must still read after the repair, or the reader refuses
# every campaign rather than the malformed ones.
with tempfile.TemporaryDirectory() as directory:
    campaign = build_campaign(directory)
    completed = run_summarizer(campaign)
    if "\theld\t" in completed.stdout or re.search(r"\theld$", completed.stdout, re.M):
        report("an ordinary held verdict still reads", "ok")
    else:
        report("an ordinary held verdict still reads", "no held row in the restoration table")

# ---- non-finite and non-positive rates ----
for label, rate in (("inf", "inf"), ("nan", "nan"), ("-inf", "-inf")):
    check(
        f"a rate of {label} carries no accepted rate",
        "unresolved",
        {P1: dict(rate=rate)},
        P1,
    )
check(
    "a zero rate carries no accepted rate",
    "unresolved",
    {P1: dict(rate="0")},
    P1,
)
check(
    "a negative rate carries no accepted rate",
    "unresolved",
    {P1: dict(rate="-3.5")},
    P1,
)
# An infinite control mean would otherwise pass the span criterion and set
# every later comparison against a reference no arm measured.
check(
    "an infinite control leaves the sweep unresolved",
    "unresolved",
    {CONTROL_OPEN: dict(rate="inf")},
    "sweep",
)

# ---- malformed and duplicated arm rows ----
duplicate_summary = (
    "schema\tpower-factorial-arm-v1\n"
    f"model_id\t{MODEL}\n"
    "instrument\tserved\n"
    "served_status\t1\n"
    "decode_tok_s\t10.0\n"
    "served_status\t0\n"
)
check(
    "a repeated served_status does not overwrite the earlier refusal",
    "unresolved",
    {P1: dict(rate=10.00, raw_summary=duplicate_summary)},
    P1,
)
malformed_summary = (
    "schema\tpower-factorial-arm-v1\n"
    f"model_id\t{MODEL}\n"
    "instrument\tserved\tstray\n"
    "served_status\t0\n"
    "decode_tok_s\t10.0\n"
)
check(
    "a row of the wrong width refuses the arm",
    "unresolved",
    {P1: dict(rate=10.00, raw_summary=malformed_summary)},
    P1,
)

# ---- instrument identity ----
check(
    "a bench candidate against a served reference reads diagnostic",
    "diagnostic",
    {NICE_ALT: dict(rate=11.00, instrument="bench")},
    NICE_ALT,
)
check(
    "a bench candidate against a bench reference screens",
    "screened",
    {
        P3: dict(rate=10.10, instrument="bench"),
        NICE_ALT: dict(rate=11.00, instrument="bench"),
    },
    NICE_ALT,
)

# ---- the sustained window is measured rather than assumed ----
SUSTAINED = "08-sustained-stock"
PACKAGE = "10-p4-package-25w"
check(
    "a sustained arm clearing the window spans it",
    "spans_the_window",
    {SUSTAINED: dict(rate=9.46, extra_rows=(("generate_tokens", "2400"),))},
    SUSTAINED,
)
# 2400 tokens at a 0.8B-class rate lasts about 125 s, which is the inference
# the campaign's token count used to make from a 9.46 tok/s figure.
check(
    "a fast checkpoint does not span the window at the same token count",
    "unresolved",
    {SUSTAINED: dict(rate=19.20, extra_rows=(("generate_tokens", "2400"),))},
    SUSTAINED,
)
check(
    "a sustained arm recording no token count is unresolved",
    "unresolved",
    {SUSTAINED: dict(rate=9.46)},
    SUSTAINED,
)
check(
    "P4 is withheld where the sustained arm did not span the window",
    "unresolved",
    {
        SUSTAINED: dict(rate=19.20, extra_rows=(("generate_tokens", "2400"),)),
        PACKAGE: dict(rate=12.00),
    },
    PACKAGE,
)
check(
    "P4 reads where the sustained arm spanned the window",
    "screened",
    {
        SUSTAINED: dict(rate=9.46, extra_rows=(("generate_tokens", "2400"),)),
        PACKAGE: dict(rate=12.00),
    },
    PACKAGE,
)

# ---- mutation controls ----
# Each mutation removes one guard the suite above rests on, and the suite must
# stop accepting; a mutation the suite still passes names a claim no check
# tests.
MUTATIONS = (
    (
        "restoration failure detection",
        'if parsed != parsed or parsed in (float("inf"), float("-inf")):\n        return None\n',
        "",
        "a rate of inf carries no accepted rate",
    ),
    (
        "duplicate key refusal",
        "                if fields[0] in rows:\n                    return None\n",
        "",
        "a repeated served_status does not overwrite the earlier refusal",
    ),
    (
        "absent restoration handling",
        'elif rows.get("restoration_state") in ("absent", "conflict"):',
        'elif False:',
        "an arm retaining no restoration line is unproven rather than passing",
    ),
)

source = SUMMARIZER.read_text()
for label, original, replacement, guarded_check in MUTATIONS:
    if source.count(original) != 1:
        report(f"mutation control removes the {label}", "the guard is not uniquely present")
        continue
    with tempfile.TemporaryDirectory() as directory:
        mutant = pathlib.Path(directory) / "mutant.py"
        mutant.write_text(source.replace(original, replacement))
        os.chmod(mutant, 0o755)
        # The mutant reads its own directory for nothing, so it runs against
        # the same fixture shape the guarded check above builds.
        expectations = {
            "a rate of inf carries no accepted rate": ("unresolved", {P1: dict(rate="inf")}, P1),
            "a repeated served_status does not overwrite the earlier refusal": (
                "unresolved",
                {P1: dict(rate=10.00, raw_summary=duplicate_summary)},
                P1,
            ),
            "an arm retaining no restoration line is unproven rather than passing": (
                "unresolved",
                {P1: dict(rate=10.00, restoration=None)},
                "sweep",
            ),
        }
        expectation, overrides, role = expectations[guarded_check]
        with tempfile.TemporaryDirectory() as fixture_directory:
            campaign = build_campaign(fixture_directory, **overrides)
            completed = run_summarizer(campaign, mutant)
            state, _ = verdict_for(completed.stdout, role)
            if state == expectation:
                report(
                    f"mutation control removes the {label}",
                    f"the mutant still read {expectation!r}, so no check tests that guard",
                )
            else:
                report(f"mutation control removes the {label}", "ok")

if failures:
    print(f"summarize_power_factorial_tests=failed failures={len(failures)}", file=sys.stderr)
    raise SystemExit(1)
print("summarize_power_factorial_tests=passed")
