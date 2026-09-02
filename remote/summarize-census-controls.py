#!/usr/bin/env python3
"""Report the paired controls of one census campaign, pair by pair.

The runner orders arms as quadruples `a b c d` with `a` and `d` in one
execution state and `b` and `c` in another. A quadruple yields two paired
deltas, `b/a - 1` and `c/d - 1`, each reported on its own: a pair is
`accepted` only where both arms of both pairs completed and both deltas sit
inside the registered bound, so a fast inner arm never compensates a slow
one through a mean. Three shapes carry a registered bound and a meaning:

    P-nosidecar P P P-nosidecar   sidecar bound   the sampler's own cost
    P I0 I0 P                     compile bound   the instrument compiled in
    I0 I1 I1 I0                   collect bound   collection under the sampler

Any other quadruple that matches the a b c d pattern is printed with
`verdict=unclassified` and no bound, since `P I1 I1 P` conflates compile
and collection effects and `I1 S S I1` compares two submission shapes; the
S arm stays outside the pair parser entirely. Arms with status other than
`completed` or without a rate make a pair `incomplete`. The runner counts
the verdict column to decide between accepted, refuted, and failed.

usage: summarize-census-controls.py ARMS_TSV --sidecar-bound F
       --compile-bound F --collect-bound F
"""
import argparse
import sys

REGISTERED = {
    ("P-nosidecar", "P"): "sidecar",
    ("P", "I0"): "compile",
    ("I0", "I1"): "collect",
}


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
        arms.append((fields["arm"], float(rate) if rate != "-" else None, fields["status"]))
    return arms


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
    arms = [arm for arm in read_arms(args.arms) if arm[0] != "S"]
    print("pair\tcontrol\touter\tinner\tfirst_outer\tfirst_inner\tfirst_delta"
          "\tsecond_outer\tsecond_inner\tsecond_delta\tbound\tverdict")
    index = 0
    pair = 0
    while index + 3 < len(arms):
        a, b, c, d = arms[index:index + 4]
        if a[0] == d[0] and b[0] == c[0] and a[0] != b[0]:
            pair += 1
            control = REGISTERED.get((a[0], b[0]))
            if control is None:
                print(f"{pair}\tunregistered\t{a[0]}\t{b[0]}\t-\t-\t-\t-\t-\t-\t-\tunclassified")
            else:
                bound = bounds[control]
                complete = all(x[2] == "completed" and x[1] for x in (a, b, c, d))
                if complete:
                    first = b[1] / a[1] - 1
                    second = c[1] / d[1] - 1
                    verdict = "accepted" if abs(first) <= bound and abs(second) <= bound else "refuted"
                    print(f"{pair}\t{control}\t{a[0]}\t{b[0]}\t{a[1]:.3f}\t{b[1]:.3f}\t{first:+.4f}"
                          f"\t{d[1]:.3f}\t{c[1]:.3f}\t{second:+.4f}\t{bound}\t{verdict}")
                else:
                    print(f"{pair}\t{control}\t{a[0]}\t{b[0]}\t-\t-\t-\t-\t-\t-\t{bound}\tincomplete")
            index += 4
        else:
            index += 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
