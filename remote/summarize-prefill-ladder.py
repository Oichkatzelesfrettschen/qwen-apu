#!/usr/bin/env python3
"""Report the paired prefill ladder, depth by depth and metric by metric.

run-prefill-ladder.sh runs each admitted depth as two mirrored quadruples. The
`binary` quadruple is `C K K C`: the control server and the candidate server at
the same one production thread. The `threads` quadruple is `C T T C`: the
control server at one thread against the control server at the registry row's
own thread count, which is what separates a CPU-side share from a binary
difference. Both quadruples emit their arms in that mirrored order, so the
subject arm's first replicate pairs with the control's first and the second
with the second, and each pair's two arms sit adjacent in the queue.

The reported quantity is a ratio rather than a delta, because a prefill rate on
this machine is read against a checkpoint measured in the same sweep: the
repository has measured one checkpoint under identical flags spanning 30.6%
between sweeps, and an absolute band built from one sweep measures that sweep.
Each metric yields one ratio per replicate, `subject / control`, and the verdict
is over the set: the mean ratio, the sample standard deviation, and a nominal
95% interval from Student's t at n-1 degrees of freedom, the interval arithmetic
summarize-census-controls.py applies to its paired deltas. Two replicates give
one degree of freedom and a wide interval, which is what two replicates state.

The verdict compares the interval against unity rather than against a promotion
bound, since the ladder measures where a rate sits rather than whether a patch
earns promotion: `above` where the whole interval sits above 1.0, `below` where
the whole interval sits below it, and `unresolved` where the interval spans it.
A ratio above 1.0 on `ttft_ms` is the subject taking longer to first token; a
ratio above 1.0 on `prompt_tok_s` is the subject prefilling faster, so the two
metrics carry opposite senses and each row names its own.

A pair is judged over the execution state its two arms shared, exactly as the
census controls are. An arm whose `clock_invariant` reads `violated` ran off the
pinned step, and a pair whose two `sclk_mode_mhz` modes lie further apart than
`--sclk-band` measures the governor step between them, so each is excluded from
the mean and the interval and named in the `ratios` column. Fewer than two
surviving pairs reads `state-changed`; an arm that failed or carries a
non-numeric metric reads `incomplete`; a depth the runner declined reads
`skipped` and carries the runner's own reason.

`--batch-ubatch-table PATH`, when given, writes a second table to that path:
one row per depth naming the `batch` and `ubatch` the runner ran it under (a
constant pair for the whole ladder, since the allocation is one context size
for the whole run) beside the control and subject `prompt_tok_s` means and the
recommendation rule `select batch and ubatch separately by prompt depth`. The
ladder does not vary batch or ubatch by depth today -- that needs a runner
change, not a summarizer one -- so the table documents what one run actually
used at each depth rather than recommending a value; a future runner that
sweeps the pair per depth would fill the same columns with depth-varying
values, and this table's `batch`/`ubatch` columns are named for
`remote/models.tsv`'s own `batch` and `ubatch` columns, which this table
never edits.

usage: summarize-prefill-ladder.py ARMS_TSV [--sclk-band F]
                                    [--batch-ubatch-table PATH]
"""
import argparse
import math
import sys

COMPLETED_STATUS = ("completed",)

UNKNOWN_STATE = "-"

# Two-sided 95% critical values of Student's t, indexed by degrees of freedom,
# written out rather than imported so the reader runs on the appliance's own
# standard library. The table covers 2 through 8 replicates, the range the
# census campaigns admit.
T_95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365}

# The appliance's sustained regime spreads its selected graphics clock over
# about 3% and its boost regime sits 27% above it, so 6% separates the two while
# holding one regime together.
DEFAULT_SCLK_BAND = 0.06

# Each metric and the direction a ratio above unity points in. The sense is
# printed beside the verdict so a reader takes the sign from the row rather than
# from the metric's name.
METRICS = (
    ("ttft_ms", "subject_slower"),
    ("prompt_ms", "subject_slower"),
    ("prompt_tok_s", "subject_faster"),
    ("decode_tok_s", "subject_faster"),
)

COLUMNS = ("depth", "quadruple", "subject", "metric", "sense", "replicates",
           "control_mean", "subject_mean", "mean_ratio", "sd_ratio",
           "ci_low", "ci_high", "ratios", "sclk_modes", "sclk_band",
           "verdict", "detail")

REQUIRED_HEADER = ("depth", "quadruple", "arm", "replicate", "status")

BATCH_UBATCH_RECOMMENDATION_RULE = "select batch and ubatch separately by prompt depth"

BATCH_UBATCH_COLUMNS = ("depth", "batch", "ubatch", "control_prompt_tok_s_mean",
                         "subject_prompt_tok_s_mean", "rule", "detail")


def read_arms(path):
    """Every ledger row as a field dictionary, in the order the runner wrote them."""
    with open(path) as handle:
        lines = [line.rstrip("\n") for line in handle if line.strip()]
    if not lines:
        raise SystemExit("prefill ladder ledger is empty")
    header = lines[0].split("\t")
    missing = [name for name in REQUIRED_HEADER if name not in header]
    if missing:
        raise SystemExit(
            f"prefill ladder ledger header lacks {missing}: {header}")
    rows = []
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) != len(header):
            raise SystemExit(
                f"prefill ladder ledger row carries {len(fields)} fields where the"
                f" header names {len(header)}: {line}")
        rows.append(dict(zip(header, fields)))
    return rows


def numeric(value):
    """One metric as a float, or None where the ledger states no measurement.

    A missing timing reaches the ledger as `-` because the runner refuses the
    arm rather than filling a zero, so this reader turns a non-numeric field
    into an absent measurement instead of a rate of nothing.
    """
    if value in (None, "", UNKNOWN_STATE):
        return None
    try:
        parsed = float(value)
    except ValueError:
        return None
    if not math.isfinite(parsed):
        return None
    return parsed


def comparable(first_mode, second_mode, band):
    """Whether one pair's two arms held one selected graphics clock regime.

    An unknown mode takes whatever state its partner held, so the test refuses a
    pair only where both arms name a state and the two lie further apart than
    the band, relative to the larger of the two.
    """
    if first_mode == UNKNOWN_STATE or second_mode == UNKNOWN_STATE:
        return True
    first, second = numeric(first_mode), numeric(second_mode)
    if first is None or second is None:
        return False
    if first <= 0 or second <= 0:
        return False
    return abs(first - second) / max(first, second) <= band


def interval(ratios):
    """Mean, sample standard deviation, and the nominal 95% t interval."""
    count = len(ratios)
    degrees = count - 1
    if degrees not in T_95:
        raise SystemExit(
            f"a depth carries {count} replicates and the t table covers 2 through 8")
    mean = sum(ratios) / count
    variance = sum((ratio - mean) ** 2 for ratio in ratios) / degrees
    deviation = math.sqrt(variance)
    half_width = T_95[degrees] * deviation / math.sqrt(count)
    return mean, deviation, mean - half_width, mean + half_width


def judge(low, high):
    """The verdict of one ratio interval against unity."""
    if low > 1.0:
        return "above", f"above unity ci=[{low:.4f},{high:.4f}]"
    if high < 1.0:
        return "below", f"below unity ci=[{low:.4f},{high:.4f}]"
    return "unresolved", f"spans unity ci=[{low:.4f},{high:.4f}]"


def group(rows):
    """Collect the ledger into one entry per depth and quadruple, in ledger order."""
    groups = []
    index_of = {}
    for row in rows:
        key = (row["depth"], row["quadruple"])
        if key not in index_of:
            index_of[key] = len(groups)
            groups.append((key, []))
        groups[index_of[key]][1].append(row)
    return groups


def emit(fields):
    print("\t".join(str(field) for field in fields))


def blank(depth, quadruple, subject, metric, sense, verdict, detail,
          replicates=UNKNOWN_STATE):
    emit((depth, quadruple, subject, metric, sense, replicates,
          UNKNOWN_STATE, UNKNOWN_STATE, UNKNOWN_STATE, UNKNOWN_STATE,
          UNKNOWN_STATE, UNKNOWN_STATE, UNKNOWN_STATE, UNKNOWN_STATE,
          UNKNOWN_STATE, verdict, detail))


def summarize_depth(depth, quadruple, rows, band):
    """Every metric of one depth and quadruple, printed row by row."""
    skipped = [row for row in rows if row["status"] == "skipped"]
    if skipped:
        reason = skipped[0].get("reason", UNKNOWN_STATE) or UNKNOWN_STATE
        blank(depth, quadruple, UNKNOWN_STATE, UNKNOWN_STATE, UNKNOWN_STATE,
              "skipped", f"reason={reason}")
        return
    controls = sorted((row for row in rows if row["arm"] == "C"),
                      key=lambda row: int(row["replicate"]))
    subjects = sorted((row for row in rows if row["arm"] != "C"),
                      key=lambda row: int(row["replicate"]))
    subject_names = sorted({row["arm"] for row in subjects})
    subject = subject_names[0] if len(subject_names) == 1 else UNKNOWN_STATE
    if len(subject_names) != 1 or len(controls) != len(subjects) or not controls:
        for metric, sense in METRICS:
            blank(depth, quadruple, subject, metric, sense, "incomplete",
                  f"controls={len(controls)} subjects={len(subjects)}"
                  f" subject_arms={','.join(subject_names) or '-'}")
        return
    replicates = len(controls)
    incomplete = [row for row in controls + subjects
                  if row["status"] not in COMPLETED_STATUS]
    if incomplete:
        detail = ("failed_arms="
                  + " ".join(f"{row['arm']}{row['replicate']}:"
                             f"{row.get('reason') or row['status']}"
                             for row in incomplete))
        for metric, sense in METRICS:
            blank(depth, quadruple, subject, metric, sense, "incomplete", detail,
                  replicates)
        return
    modes = [f"{subject_row.get('sclk_mode_mhz', UNKNOWN_STATE)}/"
             f"{control_row.get('sclk_mode_mhz', UNKNOWN_STATE)}"
             for subject_row, control_row in zip(subjects, controls)]
    listed_modes = " ".join(modes)
    for metric, sense in METRICS:
        ratios = []
        markers = []
        for subject_row, control_row in zip(subjects, controls):
            subject_value = numeric(subject_row.get(metric))
            control_value = numeric(control_row.get(metric))
            if "violated" in (subject_row.get("clock_invariant"),
                              control_row.get("clock_invariant")):
                ratios.append(None)
                markers.append("clock-violated")
            elif subject_value is None or control_value is None or control_value <= 0:
                ratios.append(None)
                markers.append("unmeasured")
            elif not comparable(subject_row.get("sclk_mode_mhz", UNKNOWN_STATE),
                                control_row.get("sclk_mode_mhz", UNKNOWN_STATE),
                                band):
                ratios.append(None)
                markers.append("state-changed")
            else:
                ratios.append(subject_value / control_value)
                markers.append(None)
        listed = " ".join(marker if ratio is None else f"{ratio:.4f}"
                          for ratio, marker in zip(ratios, markers))
        measured = [ratio for ratio in ratios if ratio is not None]
        control_values = [numeric(row.get(metric)) for row in controls]
        subject_values = [numeric(row.get(metric)) for row in subjects]
        control_mean = (f"{sum(control_values) / len(control_values):.4f}"
                        if all(value is not None for value in control_values)
                        else UNKNOWN_STATE)
        subject_mean = (f"{sum(subject_values) / len(subject_values):.4f}"
                        if all(value is not None for value in subject_values)
                        else UNKNOWN_STATE)
        if len(measured) < 2:
            emit((depth, quadruple, subject, metric, sense, replicates,
                  control_mean, subject_mean, UNKNOWN_STATE, UNKNOWN_STATE,
                  UNKNOWN_STATE, UNKNOWN_STATE, listed, listed_modes, band,
                  "state-changed",
                  f"comparable_pairs={len(measured)} of {replicates}"))
            continue
        mean, deviation, low, high = interval(measured)
        verdict, detail = judge(low, high)
        if len(measured) < replicates:
            detail = f"{detail} comparable_pairs={len(measured)} of {replicates}"
        emit((depth, quadruple, subject, metric, sense, replicates,
              control_mean, subject_mean, f"{mean:.4f}", f"{deviation:.4f}",
              f"{low:.4f}", f"{high:.4f}", listed, listed_modes, band,
              verdict, detail))


def batch_ubatch_field(row, name):
    value = row.get(name)
    return value if value not in (None, "") else UNKNOWN_STATE


def mean_prompt_tok_s(rows, want_control):
    values = []
    for row in rows:
        if row["status"] not in COMPLETED_STATUS:
            continue
        if (row["arm"] == "C") != want_control:
            continue
        value = numeric(row.get("prompt_tok_s"))
        if value is not None:
            values.append(value)
    if not values:
        return None
    return sum(values) / len(values)


def batch_ubatch_rows(rows):
    """One row per depth, over the ledger's own `binary` quadruple rows.

    The `binary` quadruple runs at every admitted depth and at the runner's own
    skip placeholder for a declined one, so it is read here rather than
    `threads`, which the runner omits entirely under
    `QWEN_PREFILL_LADDER_THREAD_ARMS=0`.
    """
    depths_seen = []
    by_depth = {}
    for row in rows:
        if row["quadruple"] != "binary":
            continue
        depth = row["depth"]
        if depth not in by_depth:
            depths_seen.append(depth)
            by_depth[depth] = []
        by_depth[depth].append(row)
    emitted = []
    for depth in depths_seen:
        members = by_depth[depth]
        if all(row["status"] == "skipped" for row in members):
            reason = members[0].get("reason", UNKNOWN_STATE) or UNKNOWN_STATE
            emitted.append((depth, UNKNOWN_STATE, UNKNOWN_STATE, UNKNOWN_STATE,
                             UNKNOWN_STATE, BATCH_UBATCH_RECOMMENDATION_RULE,
                             f"skipped reason={reason}"))
            continue
        batches = {batch_ubatch_field(row, "batch") for row in members}
        ubatches = {batch_ubatch_field(row, "ubatch") for row in members}
        detail = "-"
        batch = next(iter(batches)) if len(batches) == 1 else UNKNOWN_STATE
        ubatch = next(iter(ubatches)) if len(ubatches) == 1 else UNKNOWN_STATE
        if len(batches) > 1 or len(ubatches) > 1:
            detail = (f"depth carries more than one batch/ubatch pair:"
                       f" batch={sorted(batches)} ubatch={sorted(ubatches)}")
        control_mean = mean_prompt_tok_s(members, True)
        subject_mean = mean_prompt_tok_s(members, False)
        emitted.append((
            depth, batch, ubatch,
            f"{control_mean:.4f}" if control_mean is not None else UNKNOWN_STATE,
            f"{subject_mean:.4f}" if subject_mean is not None else UNKNOWN_STATE,
            BATCH_UBATCH_RECOMMENDATION_RULE, detail))
    return emitted


def write_batch_ubatch_table(rows, path):
    with open(path, "w") as handle:
        handle.write("\t".join(BATCH_UBATCH_COLUMNS) + "\n")
        for fields in batch_ubatch_rows(rows):
            handle.write("\t".join(str(field) for field in fields) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("arms")
    parser.add_argument("--sclk-band", type=float, default=DEFAULT_SCLK_BAND)
    parser.add_argument("--batch-ubatch-table", default=None)
    args = parser.parse_args()
    # The band is a relative difference between two clocks, so it is a fraction
    # below one: a band of one admits a pair whose two arms differ by the whole
    # of the larger clock, which retires the condition it names.
    if not math.isfinite(args.sclk_band) or not 0.0 <= args.sclk_band < 1.0:
        parser.error(f"--sclk-band is {args.sclk_band}; a finite value in"
                     " [0, 1) is required")
    rows = read_arms(args.arms)
    print("\t".join(COLUMNS))
    for (depth, quadruple), members in group(rows):
        summarize_depth(depth, quadruple, members, args.sclk_band)
    if args.batch_ubatch_table:
        write_batch_ubatch_table(rows, args.batch_ubatch_table)
    return 0


if __name__ == "__main__":
    sys.exit(main())
