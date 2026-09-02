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

One slice mixes graph shapes, so a block states its own shape before it
reaches the aggregate. The matmul branch of `get_node_fusion_name` appends
the source type and the `m=.. n=.. k=..` triple, and `n` is the src1 column
count of that node. A row whose source type is `f32` multiplies two
activations -- the GATED_DELTA_NET chunk products of
`evidence/raven2-vulkan-kernel-census/20260902T0222Z/arms/09-S/perf-logger.log`
read `MUL_MAT f32 m=64 n=32 k=64` in a single-token graph and
`MUL_MAT f32 m=64 n=608 k=64` in the 19-token prompt graph, 19 times the
same chunk dimension -- so its `n` scales with the token count rather than
stating it. Every other source type names a stored weight, whose src1
column count is the graph's token count: the weight rows read `n=1` across
the 63 decode graphs of that log and `n=19` across its prompt graph. The
token column is therefore the largest `n` over the matmul rows that name a
non-f32 source, and a block carrying none of those rows is `unknown` and
refuses rather than being folded into a rate under a guess.

usage: summarize-perf-logger-slice.py SLICE --expected-decode-blocks N
Prints one `op` row per op with calls per decode block, total microseconds,
and microseconds per call, then the `blocks`, `decode_blocks`,
`prefill_blocks`, and `unknown_blocks` rows. The aggregate covers the decode
blocks alone; the slice refuses on an unknown block or a decode count other
than N.
"""
import argparse
import re
import sys
from collections import defaultdict

TIMING = re.compile(r"^(?P<name>.+?): (?P<count>\d+) x (?P<mean>[0-9.]+) us = (?P<total>[0-9.]+) us")
FUSED_COMPONENT = re.compile(r"^[A-Z][A-Z0-9_]*(\(|$)")
# The shape descriptor sits on the matmul component itself, which a fusion
# prefix pushes off the front of the name, so this scans the whole name
# rather than the leading token `op_names` reads.
MATMUL_SHAPE = re.compile(r"\bMUL_MAT(?:_VEC|_ID)? (?P<source>\S+) m=\d+ n=(?P<n>\d+) k=\d+")


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


def token_columns(name):
    """The `n` of every matmul row in the name that names a stored weight."""
    return [int(match.group("n")) for match in MATMUL_SHAPE.finditer(name)
            if match.group("source") != "f32"]


def classify(columns):
    if not columns:
        return "unknown"
    return "decode" if max(columns) == 1 else "prefill"


def refuse(message):
    print(f"perf_logger_refused: {message}", file=sys.stderr)
    return 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("slice")
    parser.add_argument("--expected-decode-blocks", type=int, required=True)
    args = parser.parse_args()
    if args.expected_decode_blocks < 1:
        return refuse("the request expects fewer than one decode block, which the aggregate divides by")
    blocks = 0
    opened = 0
    open_rows = None
    open_columns = []
    shapes = []
    calls = defaultdict(int)
    total_us = defaultdict(float)
    with open(args.slice, errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line == "Vulkan Timings:":
                if open_rows is not None:
                    return refuse(f"block {opened} ends without its `Total time:` line")
                opened += 1
                open_rows = []
                open_columns = []
                continue
            if line.startswith("Total time:"):
                if open_rows is None:
                    continue
                if not open_rows:
                    return refuse(f"block {opened} holds no timing row")
                blocks += 1
                shape = classify(open_columns)
                shapes.append(shape)
                # Only a decode block reaches the aggregate, so a prompt or
                # warm-up graph leaves both the call count and the divisor.
                if shape == "decode":
                    for count, total, name in open_rows:
                        for op in op_names(name):
                            calls[op] += count
                            total_us[op] += total
                open_rows = None
                continue
            match = TIMING.match(line)
            if match is None or open_rows is None:
                continue
            name = match.group("name")
            open_rows.append((int(match.group("count")), float(match.group("total")), name))
            open_columns.extend(token_columns(name))
    if open_rows is not None:
        return refuse(f"block {opened} ends without its `Total time:` line")
    unknown = [index for index, shape in enumerate(shapes, 1) if shape == "unknown"]
    if unknown:
        listed = ", ".join(str(index) for index in unknown)
        noun, verb = ("block", "names") if len(unknown) == 1 else ("blocks", "name")
        return refuse(f"{noun} {listed} {verb} no matmul row over a stored weight, "
                      "so the graph shape is unknown")
    decode_blocks = shapes.count("decode")
    if decode_blocks != args.expected_decode_blocks:
        return refuse(f"the slice holds {decode_blocks} decode blocks of {blocks}; "
                      f"the request expects {args.expected_decode_blocks}")
    print("op\tname\tcalls_per_block\ttotal_us\tmean_us")
    for op in sorted(calls, key=lambda name: (-total_us[name], name)):
        print(f"op\t{op}\t{calls[op] / decode_blocks:.3f}\t{total_us[op]:.1f}\t{total_us[op] / calls[op]:.3f}")
    print(f"blocks\t{blocks}\tops={len(calls)}")
    print(f"decode_blocks\t{decode_blocks}")
    print(f"prefill_blocks\t{shapes.count('prefill')}")
    print(f"unknown_blocks\t{len(unknown)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
