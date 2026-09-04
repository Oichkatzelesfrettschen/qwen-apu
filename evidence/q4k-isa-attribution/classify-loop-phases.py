#!/usr/bin/env python3
"""Attribute every instruction of one straight-line ISA range to a kernel phase.

`evidence/raven2-vulkan-kernel-census/e1/classify-superblock-valu.py` splits a
mat-vec superblock body four ways: address, dot, unpack, lane mask. That split
puts the packed six-bit scale decode and the weight nibble decode in one
category, so it cannot say which of the two a restructuring would remove. This
file keeps the address rule verbatim, so its address count joins E1's, and
divides the remainder by where each value came from.

The rule. A load's role is decided inside the range by the operations its own
forward cone performs, with the cone cut at the float multiplies and adds where
the phases join:

  activation        a `buffer_load_dwordx4` whose own cone names no scale mask;
                    the mat-vec reads the activation vector as `vec4`, and the
                    width alone stops separating the roles once a variant reads
                    the twelve aligned scale bytes at the same width, which is
                    what `llama-vulkan-q4k-scale-word-select.patch` does

A load takes one role for all of its destination components, so a variant whose
widened read spans two phases is read wrongly rather than refused. The arms of
`evidence/q4k-scale-decode/` stay inside the rule: the widened read there covers
the `dm` pair and the three scale words, both of which the scale role already
owns, and `weight_decode` holds at its control count on every one.
  superblock_scale  a cone reaching `v_cvt_f32_f16` (the `dm` pair) or masking
                    with 0x3f3f3f3f or 0xc0c0c0c0 (the packed six-bit scales),
                    then closed: a load joins the role where its cone shares an
                    instruction with a scale load's cone, which is what carries
                    the eight-scale halfword in, since its own chain masks
                    0x0f0f0f0f alone and meets the six-bit chain only at the
                    `v_and_or_b32` that merges the two high bits back
  weight_nibble     every other vector load on the weight buffer

A scalar constant map built from `s_mov_b32` and `s_movk_i32` inside the range
resolves a mask an instruction reads out of an SGPR, since ACO materializes
0x3f3f3f3f, 0xc0c0c0c0, and 0x0f0f0f0f once and reads them as scalar operands.

Each VALU instruction then takes a phase, in this order:

  address              the E1 backward slice from a memory address operand
  lane_mask            `v_cmp` and `v_cmpx`
  cross_lane           a DPP row or quad modifier, `v_readlane`,
                       `v_readfirstlane`, or `v_permlane`; the mechanisms that
                       move a value between lanes, which on this kernel occur
                       in the reduction alone
  multiply_accumulate  the float multiply, multiply-add, and fused forms
  activation           roles reaching it are exactly {activation}
  scale_decode         exactly {superblock_scale}
  weight_decode        exactly {weight_nibble}

An instruction that no load reaches inherits the phase its in-range consumers
agree on, which is what places the byte selector the `v_alignbyte_b32` scale
extraction reads. `lane_mask` is withheld from that inheritance, since the
exec-mask compare reads the loop counter and would otherwise claim the
induction step. What remains after that pass is reported as `residue` with its
mnemonics rather than folded into a phase.

The longest chain per phase is the longest path through that phase's own
instructions, an edge running from the latest VGPR writer to a later reader,
the same edge relation `remote/raven2-shader-lab/depth.py` follows, including
its rule that a `v_mac`, `v_fmac`, or `v_dot` reads its destination as a third
source so the accumulator carries the chain. The taint and the address slice
read operands the way E1's classifier does instead, which is what keeps the
address count joined to E1's. A phase chain is descriptive: the whole-range
chain against the whole-range VALU count is what says whether the range is
issue-bound, and a phase chain matters only where a change would serialize
on it.

usage: classify-loop-phases.py ISA FIRST_LINE LAST_LINE LABEL [--rows N]
       [--phase-tsv PATH] [--salu-tsv PATH]
"""

import argparse
import collections
import re
import sys

FLOAT_PRODUCT_PREFIXES = (
    "v_mac_f32",
    "v_mad_f32",
    "v_mul_f32",
    "v_fma_f32",
    "v_fmac_f32",
    "v_madmk_f32",
    "v_madak_f32",
    "v_mad_mix",
    "v_pk_fma",
    "v_dot",
)
FLOAT_JOIN_PREFIXES = FLOAT_PRODUCT_PREFIXES + (
    "v_add_f32",
    "v_sub_f32",
    "v_subrev_f32",
)
MEMORY_PREFIXES = ("buffer_load", "buffer_store", "ds_read", "ds_write")
LOAD_PREFIXES = ("buffer_load", "ds_read")
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
SCALE_MASKS = (0x3F3F3F3F, 0xC0C0C0C0)
# The VOP2 accumulate forms read their destination as a third source, which is
# depth.py's own rule; the chain follows the accumulator through them.
ACCUMULATE_PREFIXES = ("v_mac_", "v_fmac_", "v_pk_fmac_", "v_dot")
CROSS_LANE_PREFIXES = ("v_readlane", "v_readfirstlane", "v_permlane", "v_permlanex")
DPP_MARKERS = ("row_shr", "row_shl", "row_bcast", "quad_perm", "row_ror", "wave_shr")
PHASES = (
    "multiply_accumulate",
    "weight_decode",
    "scale_decode",
    "activation",
    "address",
    "cross_lane",
    "lane_mask",
    "residue",
)
SALU_CLASSES = (
    "descriptor_load",
    "row_base",
    "mask_constant",
    "exec_control",
    "branch",
    "other",
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
    """E1's rule, unchanged: a VALU is address arithmetic where a backward
    slice from a memory instruction's address operand reaches it."""
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


def scalar_constants(instructions):
    """ACO materializes each mask once and reads it as a scalar operand, so a
    mask test has to resolve the SGPR the instruction names."""
    constants = {}
    for mnemonic, operands in instructions:
        if mnemonic not in ("s_mov_b32", "s_movk_i32") or len(operands) < 2:
            continue
        destination = operands[0].strip()
        literal = operands[1].strip()
        try:
            constants[destination] = int(literal, 0)
        except ValueError:
            continue
    return constants


def latest_definitions(instructions, accumulator=False):
    """For each instruction, the position that last wrote each register it
    reads. A register with no earlier writer in the range is loop-carried.
    With `accumulator` set, an accumulate form also reads its destination,
    which is the edge depth.py follows and the taint deliberately does not."""
    writer = {}
    sources = []
    for position, instruction in enumerate(instructions):
        reads = set(consumed(instruction))
        if accumulator and instruction[0].startswith(ACCUMULATE_PREFIXES):
            reads |= defined(instruction)
        sources.append({
            register: writer[register]
            for register in reads
            if register in writer
        })
        for register in defined(instruction):
            writer[register] = position
    return sources


def load_roles(instructions, sources, constants):
    """Walk each load's forward cone, cut at the float operations where the
    phases join, and read the role off the operations the cone performs."""
    consumers = collections.defaultdict(set)
    for position, source_map in enumerate(sources):
        for producer in source_map.values():
            consumers[producer].add(position)

    def cut_cone(position):
        cone = set()
        frontier = [position]
        while frontier:
            current = frontier.pop()
            for successor in consumers[current]:
                if successor in cone:
                    continue
                if instructions[successor][0].startswith(FLOAT_JOIN_PREFIXES):
                    continue
                cone.add(successor)
                frontier.append(successor)
        return cone

    def names_scale_mask(index):
        mnemonic, operands = instructions[index]
        if mnemonic.startswith("v_cvt_f32_f16"):
            return True
        for operand in operands[1:]:
            token = operand.split()[0].strip("|-")
            value = constants.get(token)
            if value is None:
                try:
                    value = int(token, 0)
                except ValueError:
                    continue
            if value in SCALE_MASKS:
                return True
        return False

    roles = {}
    cones = {}
    for position, (mnemonic, _operands) in enumerate(instructions):
        if not mnemonic.startswith(LOAD_PREFIXES):
            continue
        cones[position] = cut_cone(position)
        names_scale = any(names_scale_mask(index) for index in cones[position])
        if mnemonic.startswith("buffer_load_dwordx4") and not names_scale:
            roles[position] = "activation"
            del cones[position]
            continue
        roles[position] = "superblock_scale" if names_scale else "weight_nibble"

    changed = True
    while changed:
        changed = False
        scale_cone = set()
        for position, role in roles.items():
            if role == "superblock_scale" and position in cones:
                scale_cone |= cones[position]
        for position, role in roles.items():
            if role != "weight_nibble" or position not in cones:
                continue
            if cones[position] & scale_cone:
                roles[position] = "superblock_scale"
                changed = True
    return roles


def propagate(instructions, sources, roles):
    """Forward union of the load roles reaching each instruction. The range is
    straight-line, so one pass in program order is a fixpoint."""
    reaching = [frozenset() for _ in instructions]
    for position, instruction in enumerate(instructions):
        if position in roles:
            reaching[position] = frozenset([roles[position]])
            continue
        union = set()
        for producer in sources[position].values():
            union |= reaching[producer]
        reaching[position] = frozenset(union)
    return reaching


def classify(instructions, address, reaching):
    phase = {}
    for position, (mnemonic, operands) in enumerate(instructions):
        if not mnemonic.startswith("v_"):
            continue
        modifiers = " ".join(operands)
        if position in address:
            phase[position] = "address"
        elif mnemonic.startswith(("v_cmp", "v_cmpx")):
            phase[position] = "lane_mask"
        elif mnemonic.startswith(CROSS_LANE_PREFIXES) or any(
            marker in modifiers for marker in DPP_MARKERS
        ):
            phase[position] = "cross_lane"
        elif mnemonic.startswith(FLOAT_PRODUCT_PREFIXES):
            phase[position] = "multiply_accumulate"
        elif reaching[position] == frozenset(["activation"]):
            phase[position] = "activation"
        elif reaching[position] == frozenset(["superblock_scale"]):
            phase[position] = "scale_decode"
        elif reaching[position] == frozenset(["weight_nibble"]):
            phase[position] = "weight_decode"
    return phase


def inherit(instructions, sources, phase):
    """An instruction no load reaches takes the phase its in-range consumers
    agree on. Repeated to a fixpoint so a two-step chain resolves."""
    consumers = collections.defaultdict(set)
    for position, source_map in enumerate(sources):
        for producer in source_map.values():
            consumers[producer].add(position)
    changed = True
    while changed:
        changed = False
        for position, (mnemonic, _operands) in enumerate(instructions):
            if not mnemonic.startswith("v_") or position in phase:
                continue
            downstream = {
                phase[user]
                for user in consumers[position]
                if user in phase and phase[user] != "lane_mask"
            }
            if len(downstream) == 1:
                phase[position] = downstream.pop()
                changed = True
    return phase


def longest_chain(sources, members):
    """Longest path through one phase's own instructions, the edge relation
    depth.py follows restricted to the member set."""
    depth = {}
    best = 0
    for position in sorted(members):
        reached = [
            depth[producer]
            for producer in sources[position].values()
            if producer in members and producer in depth
        ]
        depth[position] = (max(reached) if reached else 0) + 1
        best = max(best, depth[position])
    return best


def salu_class(mnemonic, operands, constants):
    if mnemonic.startswith(("s_load", "s_buffer_load")):
        return "descriptor_load"
    if mnemonic.startswith(("s_branch", "s_cbranch", "s_setpc", "s_swappc")):
        return "branch"
    if mnemonic in ("s_mov_b32", "s_movk_i32") and operands:
        return "mask_constant" if operands[0].strip() in constants else "other"
    if mnemonic.startswith(("s_mul_i32", "s_add_u32", "s_addk_i32", "s_lshl", "s_add_i32")):
        return "row_base"
    if mnemonic.startswith(("s_mov_b64", "s_and", "s_andn2", "s_or", "s_xor", "s_not")):
        return "exec_control"
    return "other"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("isa")
    parser.add_argument("first_line", type=int)
    parser.add_argument("last_line", type=int)
    parser.add_argument("label")
    parser.add_argument("--rows", type=int, default=4)
    parser.add_argument("--phase-tsv")
    parser.add_argument("--salu-tsv")
    arguments = parser.parse_args()

    sys.setrecursionlimit(20000)
    instructions = parse(arguments.isa, arguments.first_line, arguments.last_line)
    address = address_indices(instructions)
    constants = scalar_constants(instructions)
    sources = latest_definitions(instructions)
    chain_sources = latest_definitions(instructions, accumulator=True)
    roles = load_roles(instructions, sources, constants)
    reaching = propagate(instructions, sources, roles)
    phase = inherit(instructions, sources, classify(instructions, address, reaching))

    members = collections.defaultdict(set)
    mnemonics = collections.defaultdict(collections.Counter)
    total = 0
    for position, (mnemonic, _operands) in enumerate(instructions):
        if not mnemonic.startswith("v_"):
            continue
        total += 1
        name = phase.get(position, "residue")
        members[name].add(position)
        mnemonics[name][mnemonic] += 1

    everything = {
        position
        for position, (mnemonic, _operands) in enumerate(instructions)
        if mnemonic.startswith("v_")
    }
    phase_rows = ["label\tphase\tcount\tshare_percent\tper_row\tlongest_chain\tmnemonics"]
    for name in PHASES:
        detail = ",".join(
            "%s=%d" % (key, value) for key, value in sorted(mnemonics[name].items())
        )
        phase_rows.append(
            "%s\t%s\t%d\t%.1f\t%.2f\t%d\t%s"
            % (
                arguments.label,
                name,
                len(members[name]),
                100.0 * len(members[name]) / total,
                len(members[name]) / float(arguments.rows),
                longest_chain(chain_sources, members[name]),
                detail or "-",
            )
        )
    phase_rows.append(
        "%s\tvalu_total\t%d\t100.0\t%.2f\t%d\t-"
        % (
            arguments.label,
            total,
            total / float(arguments.rows),
            longest_chain(chain_sources, everything),
        )
    )

    salu_counts = collections.Counter()
    salu_mnemonics = collections.defaultdict(collections.Counter)
    salu_total = 0
    for mnemonic, operands in instructions:
        if not mnemonic.startswith("s_") or mnemonic in ("s_waitcnt", "s_barrier", "s_endpgm"):
            continue
        salu_total += 1
        name = salu_class(mnemonic, operands, constants)
        salu_counts[name] += 1
        salu_mnemonics[name][mnemonic] += 1
    salu_rows = ["label\tsalu_class\tcount\tshare_percent\tmnemonics"]
    for name in SALU_CLASSES:
        detail = ",".join(
            "%s=%d" % (key, value) for key, value in sorted(salu_mnemonics[name].items())
        )
        salu_rows.append(
            "%s\t%s\t%d\t%.1f\t%s"
            % (
                arguments.label,
                name,
                salu_counts[name],
                100.0 * salu_counts[name] / salu_total if salu_total else 0.0,
                detail or "-",
            )
        )
    salu_rows.append("%s\tsalu_total\t%d\t100.0\t-" % (arguments.label, salu_total))

    for row in phase_rows:
        print(row)
    for row in salu_rows:
        print(row)
    if arguments.phase_tsv:
        open(arguments.phase_tsv, "w", encoding="utf-8").write("\n".join(phase_rows) + "\n")
    if arguments.salu_tsv:
        open(arguments.salu_tsv, "w", encoding="utf-8").write("\n".join(salu_rows) + "\n")


if __name__ == "__main__":
    main()
