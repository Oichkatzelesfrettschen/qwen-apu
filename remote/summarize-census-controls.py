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
interval still crosses its threshold. Three shapes carry a registered bound
and a meaning:

    P-nosidecar P P P-nosidecar   sidecar bound   the sampler's own cost
    P I0 I0 P                     compile bound   the instrument compiled in
    I0 I1 I1 I0                   collect bound   collection under the sampler

Any other quadruple that matches the a b c d pattern is printed on its own
with `verdict=unclassified` and no bound, since `P I1 I1 P` conflates compile
and collection effects and `I1 S S I1` compares two submission shapes; the
S arm stays outside the pair parser entirely. A `reused` arm is an arm a
brick already ran under this run's own input closure, echoed into the ledger
at its own slot with the rate it measured, so it pairs as a completed arm;
any other status, or a row without a rate, makes the whole control
`incomplete`. The runner reads the verdict column by name to decide between
accepted, refuted, unresolved, state-changed, and failed.

A pair is judged over the execution state its two arms shared. The runner
records the modal selected graphics clock of each sampled arm's request window
as `sclk_mode_mhz`, and a pair whose two arms hold different numeric modes
measures the governor step between them rather than the change the control
names, so it is listed as `state-changed` in `deltas` and stays outside the
mean and the interval. A `-` is an unknown state rather than a state of its
own -- the sampler is off on `P-nosidecar` and `W`, and a ledger predating the
column carries `-` on every row -- so a pair carrying one holds whatever state
its partner did and remains comparable. Where fewer than two comparable pairs
survive, the whole control reads `state-changed`, a verdict distinct from
`incomplete`, which names missing arms, and from `unresolved`, which names an
interval that spans its bound.

`first_outer` through `second_delta` carry the first quadruple's own two pairs
rather than extremes of the set, so a reader compares a single replicate
against the aggregate; `deltas` lists every paired delta in campaign order and
`sclk_modes` lists each pair's `inner/outer` modes in the same order and the
same direction as the delta.

usage: summarize-census-controls.py ARMS_TSV --sidecar-bound F
       --compile-bound F --collect-bound F
"""
import argparse
import math
import sys

COMPLETED_STATUS = ("completed", "reused")

REGISTERED = {
    ("P-nosidecar", "P"): "sidecar",
    ("P", "I0"): "compile",
    ("I0", "I1"): "collect",
}

# Two-sided 95% critical values of Student's t, indexed by degrees of freedom,
# for the replicate counts a campaign admits (n = 2 through 8). The table is
# written out rather than imported so the reader runs on the appliance's own
# standard library.
T_95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365}

COLUMNS = ("pair", "control", "outer", "inner",
           "first_outer", "first_inner", "first_delta",
           "second_outer", "second_inner", "second_delta",
           "replicates", "mean_delta", "sd_delta", "ci_low", "ci_high", "deltas",
           "sclk_modes", "bound", "verdict", "detail")

UNKNOWN_STATE = "-"


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
                     fields["status"], fields.get("sclk_mode_mhz", UNKNOWN_STATE)))
    return arms


def comparable(inner, outer):
    """Whether one pair's two arms held the same selected graphics clock.

    An unknown mode takes whatever state its partner held, so the test refuses
    a pair only where both arms name a state and the two differ.
    """
    return (inner == UNKNOWN_STATE or outer == UNKNOWN_STATE
            or inner == outer)


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
    args = parser.parse_args()
    bounds = {
        "sidecar": args.sidecar_bound,
        "compile": args.compile_bound,
        "collect": args.collect_bound,
    }
    # W is the cold-load warmup and S is the identity arm; neither carries a
    # registered bound, so both stay outside the quadruple walk.
    arms = [arm for arm in read_arms(args.arms) if arm[0] not in ("S", "W")]
    print("\t".join(COLUMNS))
    for pair, (control, members) in enumerate(group(arms), 1):
        first = members[0]
        outer, inner = first[0][0], first[1][0]
        if control is None:
            print(f"{pair}\tunregistered\t{outer}\t{inner}"
                  "\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\tunclassified\t-")
            continue
        bound = bounds[control]
        replicates = 2 * len(members)
        complete = all(arm[2] in COMPLETED_STATUS and arm[1]
                       for quadruple in members for arm in quadruple)
        if not complete:
            print(f"{pair}\t{control}\t{outer}\t{inner}"
                  f"\t-\t-\t-\t-\t-\t-\t{replicates}\t-\t-\t-\t-\t-\t-"
                  f"\t{bound}\tincomplete\t-")
            continue
        # One quadruple carries two pairs and each is judged on its own state,
        # so a quadruple whose governor stepped between its second and third
        # arm keeps the pair that held one state and loses the pair that
        # straddled the step.
        deltas = []
        modes = []
        for a, b, c, d in members:
            for numerator, denominator in ((b, a), (c, d)):
                modes.append(f"{numerator[3]}/{denominator[3]}")
                if comparable(numerator[3], denominator[3]):
                    deltas.append(numerator[1] / denominator[1] - 1)
                else:
                    deltas.append(None)
        listed = " ".join("state-changed" if delta is None else f"{delta:+.4f}"
                          for delta in deltas)
        listed_modes = " ".join(modes)
        a, b, c, d = first
        first_delta = "state-changed" if deltas[0] is None else f"{deltas[0]:+.4f}"
        second_delta = "state-changed" if deltas[1] is None else f"{deltas[1]:+.4f}"
        head = (f"{pair}\t{control}\t{outer}\t{inner}"
                f"\t{a[1]:.3f}\t{b[1]:.3f}\t{first_delta}"
                f"\t{d[1]:.3f}\t{c[1]:.3f}\t{second_delta}\t{replicates}")
        measured = [delta for delta in deltas if delta is not None]
        if len(measured) < 2:
            print(f"{head}\t-\t-\t-\t-\t{listed}\t{listed_modes}"
                  f"\t{bound}\tstate-changed"
                  f"\tcomparable_pairs={len(measured)} of {replicates}")
            continue
        mean, deviation, low, high = interval(measured)
        verdict, detail = judge(low, high, bound)
        if len(measured) < replicates:
            excluded = f"comparable_pairs={len(measured)} of {replicates}"
            detail = excluded if detail == "-" else f"{detail} {excluded}"
        print(f"{head}\t{mean:+.4f}\t{deviation:.4f}\t{low:+.4f}\t{high:+.4f}"
              f"\t{listed}\t{listed_modes}"
              f"\t{bound}\t{verdict}\t{detail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
