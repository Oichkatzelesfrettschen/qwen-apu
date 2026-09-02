#!/usr/bin/env python3
"""Turn the request-local slice of a vk_perf_logger stream into an inventory.

The pinned perf logger prints one block per graph at frequency 1: a
`Vulkan Timings:` line, one `NAME: COUNT x MEAN us = TOTAL us` line per
distinct node name, and a `Total time:` line. The served runner retains
the bytes of server.log appended between the request window's open and
close, so every block in the slice belongs to the timed request and a
block from warm-up or a later request stays out.

`vk_perf_logger::get_node_fusion_name` in ggml/src/ggml-vulkan/ggml-vulkan.cpp
builds a name as an optional fusion prefix, the ggml op name, and one
operand or shape descriptor, so the op is the leading whitespace-delimited
token with `_VEC` removed and the rest describes the node.
`MUL_MAT_VEC q4_K m=2048 n=1 k=2048` is one MUL_MAT and
`FLASH_ATTN_EXT dst(...),  q(...),  k(...)` is one FLASH_ATTN_EXT whose
lowercase operands name no op. A fused node carries its kernel as that
leading token, so `RMS_NORM_MUL RMS_NORM(...)` inventories as RMS_NORM_MUL
and a reader summing RMS_NORM alone misses the fused pipeline, which is
the pipeline distinction a census reads.

The `", "` join comes from the vector `log_timing` overload, which
concatenates whole per-node names for one timestamp span under
GGML_VK_PERF_LOGGER_CONCURRENT. A component after `", "` counts as a
second op where an uppercase op token ends it or opens its shape
parenthesis, which separates the `MUL` of `RMS_NORM(2048,1,1,1), MUL` from
the `K=Cin*KW*KH=576` of a CONV_2D descriptor. Counts sum over the blocks
and divide by the block count.

A block holds at least one timing row and its terminal `Total time:` line,
and a slice that closes mid-block refuses rather than dividing a partial
block into the rate. A slice that opens mid-block carries no header for
its orphan prefix, so those rows join no block and leave the rate alone.

usage: summarize-perf-logger-slice.py SLICE --expected-min-blocks N
Prints one `op` row per op with calls per block and total microseconds,
then one `blocks` row; refuses a slice with fewer blocks than expected.
"""
import argparse
import re
import sys
from collections import defaultdict

TIMING = re.compile(r"^(?P<name>.+?): (?P<count>\d+) x (?P<mean>[0-9.]+) us = (?P<total>[0-9.]+) us")
FUSED_COMPONENT = re.compile(r"^[A-Z][A-Z0-9_]*(\(|$)")


def op_names(name):
    ops = []
    for index, component in enumerate(name.split(", ")):
        text = component.strip()
        if index and not FUSED_COMPONENT.match(text):
            continue
        token = text.split(" ", 1)[0].split("(", 1)[0]
        if token.endswith("_VEC"):
            token = token[:-4]
        if token:
            ops.append(token)
    return ops


def refuse(message):
    print(f"perf_logger_refused: {message}", file=sys.stderr)
    return 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("slice")
    parser.add_argument("--expected-min-blocks", type=int, required=True)
    args = parser.parse_args()
    blocks = 0
    opened = 0
    open_rows = None
    calls = defaultdict(int)
    total_us = defaultdict(float)
    with open(args.slice, errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line == "Vulkan Timings:":
                if open_rows is not None:
                    return refuse(f"block {opened} ends without its `Total time:` line")
                opened += 1
                open_rows = 0
                continue
            if line.startswith("Total time:"):
                if open_rows is None:
                    continue
                if open_rows == 0:
                    return refuse(f"block {opened} holds no timing row")
                blocks += 1
                open_rows = None
                continue
            match = TIMING.match(line)
            if match is None or open_rows is None:
                continue
            open_rows += 1
            count = int(match.group("count"))
            total = float(match.group("total"))
            for op in op_names(match.group("name")):
                calls[op] += count
                total_us[op] += total
    if open_rows is not None:
        return refuse(f"block {opened} ends without its `Total time:` line")
    if blocks < args.expected_min_blocks:
        return refuse(f"the slice holds {blocks} blocks; the request expects at least {args.expected_min_blocks}")
    print("op\tname\tcalls_per_block\ttotal_us")
    for op in sorted(calls, key=lambda name: (-total_us[name], name)):
        print(f"op\t{op}\t{calls[op] / blocks:.3f}\t{total_us[op]:.1f}")
    print(f"blocks\t{blocks}\tops={len(calls)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
