#!/usr/bin/env python3
"""Report the paired controls of one census campaign, control by control.

The runner orders arms as quadruples `a b c d` with `a` and `d` in one
execution state and `b` and `c` in another. A quadruple yields two paired
deltas, `b/a - 1` and `c/d - 1`, and a control repeats the quadruple until it
holds the campaign's replicate count. The verdict is over the whole set: the
mean paired delta, the sample standard deviation, and a nominal 95% interval
from Student's t at n-1 degrees of freedom decide it, because two replicates
disagreeing in sign report this machine's own arm-to-arm scatter rather than a
cost. A control is `accepted` where the whole interval sits inside
[-bound, +bound], `refuted` where the whole interval sits outside the bound on
one side -- a cost where every point is below -bound, a speedup where every
point is above +bound -- and `unresolved` where the interval spans the bound,
the state `evidence/research-claim-methodology.md` names for a direction whose
interval still crosses its threshold. Four shapes carry a registered bound
and a meaning:

    P-nosidecar P P P-nosidecar   sidecar bound   the sampler's own cost
    P I0 I0 P                     compile bound   the instrument compiled in
    I0 I1 I1 I0                   collect bound   collection under the sampler
    C K K C                       served-ab bound a candidate against a control

The first three carry a two-sided bound, because each names a cost the campaign
admits in either direction. `C K K C` is the served binary comparison
run-served-binary-ab.sh drives, and its bound is one-sided about `+bound`,
since the repository promotes a candidate on a paired gain: the verdict reads
`promoted` where the whole interval sits above the bound, `refuted` where the
whole interval sits below it -- a candidate merely no faster than the control
is refuted the way a slower one is -- and `unresolved` where the interval spans
it. The delta is the candidate's rate over the control's, so a positive mean is
the candidate decoding faster.

Any other quadruple that matches the a b c d pattern is printed on its own
with `verdict=unclassified` and no bound, since `P I1 I1 P` conflates compile
and collection effects and `I1 S S I1` compares two submission shapes; the
S arm stays outside the pair parser entirely. A `reused` arm is an arm a
brick already ran under this run's own input closure, echoed into the ledger
at its own slot with the rate it measured, so it pairs as a completed arm;
any other status, or a row without a rate, makes the whole control
`incomplete`. Each runner reads the verdict column by name: the census decides
between accepted, refuted, unresolved, state-changed, and failed, and the
served comparison between promoted, refuted, unresolved, state-changed, and
failed.

A pair is judged over the execution state its two arms shared. The runner
records the modal selected graphics clock of each sampled arm's request window
as `sclk_mode_mhz`, and a pair whose two modes lie further apart than
`--sclk-band` measures the governor step between them rather than the change
the control names, so it is listed as `state-changed` in `deltas` and stays
outside the mean and the interval. The band is a relative difference over the
larger of the two modes: under the appliance's sustained regime the selected
clock hovers across 775, 787, 800, 812, 825, 837, and 857 MHz within one
thermal state, so an exact comparison read every collect pair of 20260902T1302Z
as a step while its widest pair sits 3.18% apart, and the boost regime's 1100
against that regime's 800 sits 27.27% apart and stays state-changed. A `-` is
an unknown state rather than a state of its own -- the sampler is off on
`P-nosidecar`, and a ledger predating the column carries `-` on every row -- so
a pair carrying one holds whatever state its partner did and remains
comparable. Where fewer than two comparable pairs survive, the whole control
reads `state-changed`, a verdict distinct from `incomplete`, which names
missing arms, and from `unresolved`, which names an interval that spans its
bound.

A pair is judged the same way over a forced clock. Where the campaign pinned
the graphics clock through `power_dpm_force_performance_level`, each sampled
arm carries `clock_invariant` from `validate-clock-sidecar.py`, and a pair
holding an arm whose invariant reads `violated` ran against a clock that left
the pinned step, so it is listed as `clock-violated` in `deltas` and stays
outside the mean and the interval exactly as `state-changed` does. The
violation wins where both markers apply, since a clock that moved off a pin is
the stronger statement about the arm. An arm under the appliance's own
governor carries `-` there and pairs as before.

`first_outer` through `second_delta` carry the first quadruple's own two pairs
rather than extremes of the set, so a reader compares a single replicate
against the aggregate; `deltas` lists every paired delta in campaign order and
`sclk_modes` lists each pair's `inner/outer` modes in the same order and the
same direction as the delta. `off_regime_arms` counts the control's own arms
whose `regime_delta` -- the distance the runner recorded between that arm's
mode and the regime its warmup precondition settled on, scaled by the same
larger-of-two denominator -- exceeds the band. A pair of arms that agree with
each other and both sit outside the regime is comparable and still reports a
campaign that drifted off the state it opened in, which is what that count
states and the pair comparison cannot.

usage: summarize-census-controls.py ARMS_TSV --sidecar-bound F
       --compile-bound F --collect-bound F [--served-ab-bound F]
       [--sclk-band F]
"""
import argparse
import math
import sys

COMPLETED_STATUS = ("completed", "reused")

REGISTERED = {
    ("P-nosidecar", "P"): "sidecar",
    ("P", "I0"): "compile",
    ("I0", "I1"): "collect",
    ("C", "K"): "served-ab",
}

# The controls whose bound is one-sided about +bound rather than two-sided
# about zero. A served binary comparison asks whether the candidate is faster
# by more than the promotion bound, which has no admitted band below it.
ONE_SIDED = frozenset({"served-ab"})

# Two-sided 95% critical values of Student's t, indexed by degrees of freedom,
# for the replicate counts a campaign admits (n = 2 through 8). The table is
# written out rather than imported so the reader runs on the appliance's own
# standard library.
T_95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365}

COLUMNS = ("pair", "control", "outer", "inner",
           "first_outer", "first_inner", "first_delta",
           "second_outer", "second_inner", "second_delta",
           "replicates", "mean_delta", "sd_delta", "ci_low", "ci_high", "deltas",
           "sclk_modes", "off_regime_arms", "bound", "verdict", "detail")

UNKNOWN_STATE = "-"

# The band a run states nothing about: the appliance's sustained regime spreads
# its selected clock over about 3% and its boost regime sits 27% above it, so
# 6% separates the two while holding one regime together.
DEFAULT_SCLK_BAND = 0.06


def read_arms(path):
    with open(path) as handle:
        lines = [line.rstrip("\n") for line in handle if line.strip()]
    if not lines:
        raise SystemExit("arms ledger is empty")
    header = lines[0].split("\t")
    required = ("arm", "tok_s", "status")
    if any(name not in header for name in required):
        raise SystemExit(f"arms ledger header lacks one of {required}: {header}")
    arms = []
    for line in lines[1:]:
        fields = dict(zip(header, line.split("\t")))
        rate = fields["tok_s"]
        # A ledger written before the clock-state columns existed carries the
        # unknown state on every row, which leaves every pair comparable and
        # replays those campaigns unchanged.
        arms.append((fields["arm"], float(rate) if rate != "-" else None,
                     fields["status"], fields.get("sclk_mode_mhz", UNKNOWN_STATE),
                     fields.get("regime_delta", UNKNOWN_STATE),
                     fields.get("clock_invariant", UNKNOWN_STATE)))
    return arms


def comparable(inner, outer, band):
    """Whether one pair's two arms held one selected graphics clock regime.

    An unknown mode takes whatever state its partner held, so the test refuses
    a pair only where both arms name a state and the two lie further apart
    than the band, relative to the larger of the two.
    """
    if inner == UNKNOWN_STATE or outer == UNKNOWN_STATE:
        return True
    try:
        first, second = float(inner), float(outer)
    except ValueError:
        return False
    if first <= 0 or second <= 0:
        return False
    return abs(first - second) / max(first, second) <= band


def off_regime(arms, band):
    """How many of these arms sit further from the campaign's regime than the band.

    An arm whose `regime_delta` is unknown -- an unsampled arm, an unreached
    precondition, or a ledger predating the column -- is uncounted rather than
    counted as agreeing, so the count states what was measured off the regime
    rather than what failed to be measured.
    """
    count = 0
    for arm in arms:
        if arm[4] == UNKNOWN_STATE:
            continue
        try:
            delta = float(arm[4])
        except ValueError:
            continue
        if abs(delta) > band:
            count += 1
    return count


def interval(deltas):
    """Mean, sample standard deviation, and the nominal 95% t interval."""
    count = len(deltas)
    degrees = count - 1
    if degrees not in T_95:
        raise SystemExit(
            f"a control carries {count} replicates and the t table covers 2 through 8")
    mean = sum(deltas) / count
    variance = sum((delta - mean) ** 2 for delta in deltas) / degrees
    deviation = math.sqrt(variance)
    half_width = T_95[degrees] * deviation / math.sqrt(count)
    return mean, deviation, mean - half_width, mean + half_width


def judge_promotion(low, high, bound):
    """The verdict of one interval against a one-sided promotion bound.

    The bound is a gain the candidate must clear whole, so an interval sitting
    anywhere below it refutes the promotion whether it names a loss, no change,
    or a gain the bound does not admit.
    """
    if low > bound:
        return "promoted", f"exceeds bound={bound} gain ci=[{low:+.4f},{high:+.4f}]"
    if high < bound:
        return "refuted", f"below bound={bound} ci=[{low:+.4f},{high:+.4f}]"
    return "unresolved", f"spans bound={bound} ci=[{low:+.4f},{high:+.4f}]"


def judge(low, high, bound):
    """The verdict of one interval against one bound, and its own detail."""
    if -bound <= low and high <= bound:
        return "accepted", "-"
    if high < -bound:
        return "refuted", f"exceeds bound={bound} cost ci=[{low:+.4f},{high:+.4f}]"
    if low > bound:
        return "refuted", f"exceeds bound={bound} speedup ci=[{low:+.4f},{high:+.4f}]"
    return "unresolved", f"spans bound={bound} ci=[{low:+.4f},{high:+.4f}]"


def quadruples(arms):
    """Walk the arm list and yield each `a b c d` quadruple it carries."""
    index = 0
    while index + 3 < len(arms):
        a, b, c, d = arms[index:index + 4]
        if a[0] == d[0] and b[0] == c[0] and a[0] != b[0]:
            yield a, b, c, d
            index += 4
        else:
            index += 1


def group(arms):
    """Collect quadruples into one group per registered control.

    A registered control collapses to one group however many quadruples it
    holds, since its verdict is over every replicate. An unregistered
    quadruple has no group to join and keeps its own row, which is what makes
    the runner's unclassified count a count of arm-list shapes the registry
    never bound.
    """
    groups = []
    index_of = {}
    for quadruple in quadruples(arms):
        a, b = quadruple[0], quadruple[1]
        control = REGISTERED.get((a[0], b[0]))
        if control is None:
            groups.append((None, [quadruple]))
            continue
        if control not in index_of:
            index_of[control] = len(groups)
            groups.append((control, []))
        groups[index_of[control]][1].append(quadruple)
    return groups


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("arms")
    parser.add_argument("--sidecar-bound", type=float, required=True)
    parser.add_argument("--compile-bound", type=float, required=True)
    parser.add_argument("--collect-bound", type=float, required=True)
    # The served-ab bound carries a default because a census invocation names
    # no C or K arm and would otherwise have to state a bound it never uses.
    parser.add_argument("--served-ab-bound", type=float, default=0.05)
    parser.add_argument("--sclk-band", type=float, default=DEFAULT_SCLK_BAND)
    args = parser.parse_args()
    band = args.sclk_band
    bounds = {
        "sidecar": args.sidecar_bound,
        "compile": args.compile_bound,
        "collect": args.collect_bound,
        "served-ab": args.served_ab_bound,
    }
    # W is the warmup the regime precondition reads and S is the identity arm;
    # neither carries a registered bound, so both stay outside the quadruple
    # walk. A campaign runs two to eight W arms, so dropping them by name is
    # also what keeps the named arms adjacent for the walk.
    arms = [arm for arm in read_arms(args.arms) if arm[0] not in ("S", "W")]
    print("\t".join(COLUMNS))
    for pair, (control, members) in enumerate(group(arms), 1):
        first = members[0]
        outer, inner = first[0][0], first[1][0]
        if control is None:
            print(f"{pair}\tunregistered\t{outer}\t{inner}"
                  "\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\tunclassified\t-")
            continue
        bound = bounds[control]
        replicates = 2 * len(members)
        outside = off_regime([arm for quadruple in members for arm in quadruple], band)
        complete = all(arm[2] in COMPLETED_STATUS and arm[1]
                       for quadruple in members for arm in quadruple)
        if not complete:
            print(f"{pair}\t{control}\t{outer}\t{inner}"
                  f"\t-\t-\t-\t-\t-\t-\t{replicates}\t-\t-\t-\t-\t-\t-\t{outside}"
                  f"\t{bound}\tincomplete\t-")
            continue
        # One quadruple carries two pairs and each is judged on its own state,
        # so a quadruple whose governor stepped between its second and third
        # arm keeps the pair that held one state and loses the pair that
        # straddled the step.
        deltas = []
        markers = []
        modes = []
        for a, b, c, d in members:
            for numerator, denominator in ((b, a), (c, d)):
                modes.append(f"{numerator[3]}/{denominator[3]}")
                if "violated" in (numerator[5], denominator[5]):
                    deltas.append(None)
                    markers.append("clock-violated")
                elif comparable(numerator[3], denominator[3], band):
                    deltas.append(numerator[1] / denominator[1] - 1)
                    markers.append(None)
                else:
                    deltas.append(None)
                    markers.append("state-changed")
        listed = " ".join(marker if delta is None else f"{delta:+.4f}"
                          for delta, marker in zip(deltas, markers))
        listed_modes = " ".join(modes)
        a, b, c, d = first
        first_delta = markers[0] if deltas[0] is None else f"{deltas[0]:+.4f}"
        second_delta = markers[1] if deltas[1] is None else f"{deltas[1]:+.4f}"
        head = (f"{pair}\t{control}\t{outer}\t{inner}"
                f"\t{a[1]:.3f}\t{b[1]:.3f}\t{first_delta}"
                f"\t{d[1]:.3f}\t{c[1]:.3f}\t{second_delta}\t{replicates}")
        measured = [delta for delta in deltas if delta is not None]
        if len(measured) < 2:
            print(f"{head}\t-\t-\t-\t-\t{listed}\t{listed_modes}\t{outside}"
                  f"\t{bound}\tstate-changed"
                  f"\tcomparable_pairs={len(measured)} of {replicates}")
            continue
        mean, deviation, low, high = interval(measured)
        if control in ONE_SIDED:
            verdict, detail = judge_promotion(low, high, bound)
        else:
            verdict, detail = judge(low, high, bound)
        if len(measured) < replicates:
            excluded = f"comparable_pairs={len(measured)} of {replicates}"
            detail = excluded if detail == "-" else f"{detail} {excluded}"
        print(f"{head}\t{mean:+.4f}\t{deviation:.4f}\t{low:+.4f}\t{high:+.4f}"
              f"\t{listed}\t{listed_modes}\t{outside}"
              f"\t{bound}\t{verdict}\t{detail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
