#!/usr/bin/env python3
"""Turn the request-local slice of a vk_perf_logger stream into an inventory.

The pinned perf logger prints one block per graph at frequency 1: a
`Vulkan Timings:` line, one `NAME: COUNT x MEAN us = TOTAL us` line per
distinct node name, and a `Total time:` line. The served runner retains
the bytes of server.log appended between the request window's open and
close, so every block in the slice belongs to the timed request and a
block from warm-up or a later request stays out. The inventory is per
ggml op: a name's leading token with `_VEC` removed is the op, a fused
entry such as `RMS_NORM(...), MUL` counts once under each component, and
the counts are summed over the blocks and divided by the block count.

usage: summarize-perf-logger-slice.py SLICE --expected-min-blocks N
Prints one `op` row per op with calls per block and total microseconds,
then one `blocks` row; refuses a slice with fewer blocks than expected.
"""
import argparse
import re
import sys
from collections import defaultdict

TIMING = re.compile(r"^(?P<name>.+?): (?P<count>\d+) x (?P<mean>[0-9.]+) us = (?P<total>[0-9.]+) us")


def op_names(name):
    ops = []
    for component in name.split(", "):
        token = component.strip().split(" ", 1)[0].split("(", 1)[0]
        if token.endswith("_VEC"):
            token = token[:-4]
        if token:
            ops.append(token)
    return ops


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("slice")
    parser.add_argument("--expected-min-blocks", type=int, required=True)
    args = parser.parse_args()
    blocks = 0
    calls = defaultdict(int)
    total_us = defaultdict(float)
    with open(args.slice, errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line == "Vulkan Timings:":
                blocks += 1
                continue
            match = TIMING.match(line)
            if match is None or blocks == 0:
                continue
            count = int(match.group("count"))
            total = float(match.group("total"))
            for op in op_names(match.group("name")):
                calls[op] += count
                total_us[op] += total
    if blocks < args.expected_min_blocks:
        print(f"perf_logger_refused: the slice holds {blocks} blocks; the request expects at least {args.expected_min_blocks}",
              file=sys.stderr)
        return 1
    print("op\tname\tcalls_per_block\ttotal_us")
    for op in sorted(calls, key=lambda name: (-total_us[name], name)):
        print(f"op\t{op}\t{calls[op] / blocks:.3f}\t{total_us[op]:.1f}")
    print(f"blocks\t{blocks}\tops={len(calls)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
