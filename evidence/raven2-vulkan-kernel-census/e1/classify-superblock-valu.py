#!/usr/bin/env python3
"""Split one basic block's VALU instructions into address, dot, unpack, and lane-mask.

The block is the superblock loop body of a mat-vec kernel, named by its first and
last line in the shader lab's isa.s. A mnemonic alone cannot separate address
arithmetic from unpack arithmetic, because v_add_u32, v_lshlrev_b32, and
v_lshl_add_u32 appear in both roles. The rule this file applies instead: a VALU
instruction is address arithmetic where its result reaches the address operand of
a buffer_load, buffer_store, ds_read, or ds_write inside the block, found by a
backward slice from each memory instruction's address register to the definition
that last wrote it. Every remaining VALU whose mnemonic is a float multiply, add,
or multiply-add is dot arithmetic; v_cmp and v_cmpx are lane-mask; the rest is
unpack and convert. The residue is reported rather than folded into a category.

Reduction instructions sit outside the loop body in both kernels, so the body
carries none and the reduction is counted separately from its own blocks.
"""

import argparse
import collections
import re
import sys

FLOAT_PREFIXES = (
    "v_mac_f32",
    "v_mad_f32",
    "v_mul_f32",
    "v_fma_f32",
    "v_fmac_f32",
    "v_add_f32",
    "v_sub_f32",
    "v_subrev_f32",
    "v_madmk_f32",
    "v_madak_f32",
)
MEMORY_PREFIXES = ("buffer_load", "buffer_store", "ds_read", "ds_write")
NON_DEFINING_PREFIXES = (
    "buffer_store",
    "ds_write",
    "s_waitcnt",
    "s_cmp",
    "s_branch",
    "s_cbranch",
    "s_barrier",
    "s_endpgm",
    "s_nop",
)


def registers(text):
    found = set()
    for match in re.finditer(r"\b([vs])\[(\d+):(\d+)\]", text):
        for index in range(int(match.group(2)), int(match.group(3)) + 1):
            found.add(match.group(1) + str(index))
    for match in re.finditer(r"\b([vs])(\d+)\b", text):
        found.add(match.group(1) + match.group(2))
    return found


def parse(path, first_line, last_line):
    raw = open(path, encoding="utf-8").read().splitlines()
    body = raw[first_line - 1:last_line]
    instructions = []
    for line in body:
        stripped = line.split(";")[0].strip()
        if not stripped or re.match(r"^\S+:$", stripped):
            continue
        parts = stripped.split(None, 1)
        operands = [operand.strip() for operand in parts[1].split(",")] if len(parts) > 1 else []
        instructions.append((parts[0], operands))
    return instructions


def defined(instruction):
    mnemonic, operands = instruction
    if not operands or mnemonic.startswith(NON_DEFINING_PREFIXES):
        return set()
    return registers(operands[0])


def consumed(instruction):
    mnemonic, operands = instruction
    if not operands:
        return set()
    if mnemonic.startswith(("buffer_store", "ds_write")):
        return set().union(*[registers(operand) for operand in operands])
    if len(operands) == 1:
        return set()
    return set().union(*[registers(operand) for operand in operands[1:]])


def address_indices(instructions):
    marked = set()

    def slice_back(position, register, visited):
        for earlier in range(position - 1, -1, -1):
            if register in defined(instructions[earlier]):
                if earlier in visited:
                    return
                visited.add(earlier)
                marked.add(earlier)
                for source in consumed(instructions[earlier]):
                    slice_back(earlier, source, visited)
                return

    for position, (mnemonic, operands) in enumerate(instructions):
        if not mnemonic.startswith(MEMORY_PREFIXES) or len(operands) < 2:
            continue
        address_operand = operands[0] if mnemonic.startswith("ds_write") else operands[1]
        for register in registers(address_operand):
            if register.startswith("v"):
                slice_back(position, register, set())
    return marked


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("isa")
    parser.add_argument("first_line", type=int)
    parser.add_argument("last_line", type=int)
    parser.add_argument("label")
    parser.add_argument("--rows", type=int, default=4)
    arguments = parser.parse_args()

    sys.setrecursionlimit(20000)
    instructions = parse(arguments.isa, arguments.first_line, arguments.last_line)
    marked = address_indices(instructions)

    counts = collections.Counter()
    mnemonics = collections.defaultdict(collections.Counter)
    total = 0
    for position, (mnemonic, _operands) in enumerate(instructions):
        if not mnemonic.startswith("v_"):
            continue
        total += 1
        if position in marked:
            category = "address"
        elif mnemonic.startswith(FLOAT_PREFIXES):
            category = "dot_float"
        elif mnemonic.startswith(("v_cmp", "v_cmpx")):
            category = "lane_mask"
        else:
            category = "unpack_convert"
        counts[category] += 1
        mnemonics[category][mnemonic] += 1

    print("label\tcategory\tcount\tshare_percent\tper_row\tmnemonics")
    for category in ("dot_float", "unpack_convert", "address", "lane_mask"):
        detail = ",".join(
            "%s=%d" % (name, value) for name, value in sorted(mnemonics[category].items())
        )
        print(
            "%s\t%s\t%d\t%.1f\t%.2f\t%s"
            % (
                arguments.label,
                category,
                counts[category],
                100.0 * counts[category] / total,
                counts[category] / float(arguments.rows),
                detail or "-",
            )
        )
    print(
        "%s\tvalu_total\t%d\t100.0\t%.2f\t-"
        % (arguments.label, total, total / float(arguments.rows))
    )


if __name__ == "__main__":
    main()
