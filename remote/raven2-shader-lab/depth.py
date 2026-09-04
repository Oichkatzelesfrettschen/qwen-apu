#!/usr/bin/env python3
"""Read an isa.s from remote/raven2-shader-lab/lab.sh and report, per basic
block, the longest dependent VALU chain, the memory operations in flight at
each wait, and the wait count.

An instruction count states how much work a kernel issues and says nothing
about how much of it can issue at once. gfx902 issues one wavefront
instruction per SIMD every four clocks and hides latency by holding several
waves, so a block whose VALU instructions form one long dependence chain
retires at the chain's rate whatever its total count is, and a block whose
VMEM loads all issue before one s_waitcnt overlaps their latency where a
block that waits after each load serializes them. The three columns this
script writes are the shape behind an E1 instruction inventory and the term
an E5 integer kernel changes beside the count.

Dependences are tracked over VGPRs alone. A VALU instruction's destination is
its first operand where that operand names a VGPR; the VOP3b forms that write
a carry-out to VCC or an SGPR pair, and the v_cmp family that writes only a
mask, leave the first operand naming no VGPR, so the same rule reads their
whole operand list as sources and no false destination enters the chain. A
store and an LDS write name a data source or an address in that position and
define nothing, so they are excluded by mnemonic; reading one as a write would
truncate every chain that continues through the register after it. A register
range v[2:3] expands to both of its registers on either side.

A block ends at a branch, at s_endpgm, or before a label, and the wait
accounting resets with it: an s_waitcnt constrains counters the disassembler
prints as vmcnt(k) and lgkmcnt(k), and the memory operations counted in
flight are the ones outstanding at that wait: a wait at vmcnt(k) retires the
issues down to k and leaves k of them outstanding, so that residue carries
into the next interval rather than the count restarting from zero. A vmcnt
argument above zero is the overlap the kernel keeps, so the arguments are
retained beside the counts rather than reduced to a wait total.

usage: depth.py ISA_FILE DEPTH_TSV
Writes DEPTH_TSV as one header row and one row per basic block: block,
first_line, last_line, terminator, instructions, valu, vmem, lds, salu,
waitcnt, longest_valu_chain, max_vmem_in_flight, max_lgkm_in_flight,
vmcnt_arguments, lgkmcnt_arguments.
"""
import argparse
import pathlib
import re
import sys

VGPR_SINGLE = re.compile(r"^v(\d+)$")
VGPR_RANGE = re.compile(r"^v\[(\d+):(\d+)\]$")
LABEL = re.compile(r"^[A-Za-z_.$][A-Za-z0-9_.$]*:$")
WAIT_COUNTER = re.compile(r"\b(vmcnt|lgkmcnt|expcnt|vscnt)\(\s*(\d+)\s*\)")

VMEM_PREFIXES = ("buffer_", "global_", "flat_", "scratch_", "tbuffer_", "image_")
# The VOP2 accumulate forms read their destination as the third source, so the
# accumulator carries the dependence a chain follows. v_mad and v_fma name that
# source explicitly and stay out of this set.
ACCUMULATE_PREFIXES = ("v_mac_", "v_fmac_", "v_pk_fmac_", "v_dot")
# A store and an LDS write name a data source or an address in the position a
# destination occupies, so reading their first operand as a write would put a
# store into latest_writer and truncate every chain that continues through the
# register afterward. They define nothing this analysis tracks.
STORE_MARKERS = ("_store", "ds_write", "ds_wrxchg", "_atomic")
BRANCH_PREFIXES = ("s_branch", "s_cbranch", "s_setpc", "s_swappc")

OUTPUT_COLUMNS = (
    "block",
    "first_line",
    "last_line",
    "terminator",
    "instructions",
    "valu",
    "vmem",
    "lds",
    "salu",
    "waitcnt",
    "longest_valu_chain",
    "max_vmem_in_flight",
    "max_lgkm_in_flight",
    "vmcnt_arguments",
    "lgkmcnt_arguments",
)


class Instruction:
    def __init__(self, line_number, mnemonic, operands):
        self.line_number = line_number
        self.mnemonic = mnemonic
        self.operands = operands
        self.chain_depth = 0
        self.starts_block = False

    @property
    def is_valu(self):
        return self.mnemonic.startswith("v_")

    @property
    def is_vmem(self):
        return self.mnemonic.startswith(VMEM_PREFIXES)

    @property
    def is_lds(self):
        return self.mnemonic.startswith("ds_")

    @property
    def is_wait(self):
        return self.mnemonic.startswith("s_waitcnt")

    @property
    def is_salu(self):
        return (
            self.mnemonic.startswith("s_")
            and not self.is_wait
            and self.mnemonic not in ("s_barrier", "s_endpgm")
        )

    @property
    def defines_first_operand(self):
        return not any(marker in self.mnemonic for marker in STORE_MARKERS)

    @property
    def is_accumulate(self):
        return self.mnemonic.startswith(ACCUMULATE_PREFIXES)

    @property
    def is_terminator(self):
        return self.mnemonic.startswith(BRANCH_PREFIXES) or self.mnemonic == "s_endpgm"


def strip_encoding(line):
    """Remove the trailing "; hex words" the disassembler appends. The
    encoding is hexadecimal and would otherwise parse as operands."""
    return line.split(";", 1)[0].rstrip()


def parse_instruction(line_number, text):
    """Return an Instruction, or None where the line carries no mnemonic."""
    body = strip_encoding(text).strip()
    if not body or LABEL.match(body):
        return None
    parts = body.split(None, 1)
    mnemonic = parts[0]
    if not re.match(r"^[a-z][a-z0-9_]*$", mnemonic):
        return None
    operand_text = parts[1] if len(parts) > 1 else ""
    operands = [operand.strip() for operand in operand_text.split(",") if operand.strip()]
    return Instruction(line_number, mnemonic, operands)


def operand_register_token(operand):
    """The register an operand names, with the source modifiers the
    disassembler prints removed: a leading minus for negation, enclosing bars
    for absolute value, and the trailing SDWA or DPP modifiers that follow the
    last operand as separate whitespace-delimited words."""
    token = operand.split()[0] if operand.split() else ""
    token = token.strip("|")
    if token.startswith("-"):
        token = token[1:]
    return token


def operand_vgprs(operand):
    token = operand_register_token(operand)
    single = VGPR_SINGLE.match(token)
    if single:
        return [int(single.group(1))]
    span = VGPR_RANGE.match(token)
    if span:
        low = int(span.group(1))
        high = int(span.group(2))
        if high < low:
            low, high = high, low
        return list(range(low, high + 1))
    return []


def split_blocks(instructions):
    """Split at a label and after a terminator, so a block is a run of
    instructions entered only at its first and left only at its last."""
    blocks = []
    current = []
    for instruction in instructions:
        if current and instruction.starts_block:
            blocks.append(current)
            current = []
        current.append(instruction)
        if instruction.is_terminator:
            blocks.append(current)
            current = []
    if current:
        blocks.append(current)
    return blocks


def longest_valu_chain(block):
    """Longest path through the block's VALU instructions, where an edge runs
    from the latest writer of a VGPR to a later reader of it. A non-VALU
    writer breaks the chain rather than extending it, so the number counts
    dependent arithmetic and not dependent work in general."""
    latest_writer = {}
    longest = 0
    for instruction in block:
        source_operands = instruction.operands
        destination_vgprs = []
        if instruction.operands and instruction.defines_first_operand:
            destination_vgprs = operand_vgprs(instruction.operands[0])
            if destination_vgprs and not instruction.is_accumulate:
                source_operands = instruction.operands[1:]
        if instruction.is_valu:
            depth = 0
            for operand in source_operands:
                for register in operand_vgprs(operand):
                    writer = latest_writer.get(register)
                    if writer is not None:
                        depth = max(depth, writer.chain_depth)
            instruction.chain_depth = depth + 1
            longest = max(longest, instruction.chain_depth)
        else:
            instruction.chain_depth = 0
        for register in destination_vgprs:
            latest_writer[register] = instruction
    return longest


def wait_accounting(block):
    """Memory operations outstanding at each wait on the same counter, with
    the counter arguments retained.

    An s_waitcnt stalls until the named counter falls to its argument, so a
    wait at vmcnt(k) retires issues down to k and leaves k of them
    outstanding. Clearing the count at every wait would credit the wave with an
    empty pipeline it never reaches and undercount every later interval, which
    is what a mat-vec body's descending vmcnt ladder consumes one entry at a
    time; min(outstanding, k) carries into the next interval instead. The peak
    is read at the wait ahead of that residue, so it is the count standing when
    the wave stalls."""
    vmem_outstanding = 0
    lgkm_outstanding = 0
    max_vmem = 0
    max_lgkm = 0
    vmcnt_arguments = []
    lgkmcnt_arguments = []
    wait_count = 0
    for instruction in block:
        if instruction.is_vmem:
            vmem_outstanding += 1
            continue
        if instruction.is_lds:
            lgkm_outstanding += 1
            continue
        if instruction.mnemonic.startswith(("s_load", "s_buffer_load")):
            lgkm_outstanding += 1
            continue
        if not instruction.is_wait:
            continue
        wait_count += 1
        counters = dict(
            (name, int(value)) for name, value in WAIT_COUNTER.findall(" ".join([instruction.mnemonic] + instruction.operands))
        )
        if "vmcnt" in counters or "vscnt" in counters:
            retained = counters.get("vmcnt", counters.get("vscnt"))
            max_vmem = max(max_vmem, vmem_outstanding)
            vmem_outstanding = min(vmem_outstanding, retained)
            vmcnt_arguments.append(str(retained))
        if "lgkmcnt" in counters:
            retained = counters["lgkmcnt"]
            max_lgkm = max(max_lgkm, lgkm_outstanding)
            lgkm_outstanding = min(lgkm_outstanding, retained)
            lgkmcnt_arguments.append(str(retained))
    return {
        "waitcnt": wait_count,
        "max_vmem_in_flight": max_vmem,
        "max_lgkm_in_flight": max_lgkm,
        "vmcnt_arguments": ",".join(vmcnt_arguments) if vmcnt_arguments else "-",
        "lgkmcnt_arguments": ",".join(lgkmcnt_arguments) if lgkmcnt_arguments else "-",
    }


def analyze(text):
    instructions = []
    label_pending = False
    for line_number, line in enumerate(text.split("\n"), start=1):
        body = strip_encoding(line).strip()
        if body and LABEL.match(body):
            # A label is a branch target, so the next instruction opens a
            # block however many blank lines the disassembler put between
            # them.
            label_pending = True
            continue
        instruction = parse_instruction(line_number, line)
        if instruction:
            instruction.starts_block = label_pending
            label_pending = False
            instructions.append(instruction)
    rows = []
    for index, block in enumerate(split_blocks(instructions), start=1):
        terminator = block[-1].mnemonic if block[-1].is_terminator else "-"
        row = {
            "block": index,
            "first_line": block[0].line_number,
            "last_line": block[-1].line_number,
            "terminator": terminator,
            "instructions": len(block),
            "valu": sum(1 for one in block if one.is_valu),
            "vmem": sum(1 for one in block if one.is_vmem),
            "lds": sum(1 for one in block if one.is_lds),
            "salu": sum(1 for one in block if one.is_salu),
            "longest_valu_chain": longest_valu_chain(block),
        }
        row.update(wait_accounting(block))
        rows.append(row)
    return rows


def main(argv):
    parser = argparse.ArgumentParser(
        description="Report per-block VALU chain depth and memory-wait shape over an ISA disassembly."
    )
    parser.add_argument("isa_file", type=pathlib.Path)
    parser.add_argument("depth_tsv", type=pathlib.Path)
    arguments = parser.parse_args(argv)

    rows = analyze(arguments.isa_file.read_text(encoding="utf-8", errors="replace"))
    if not rows:
        print(f"{arguments.isa_file}: no instruction line found", file=sys.stderr)
        return 1
    with arguments.depth_tsv.open("w", encoding="utf-8") as handle:
        handle.write("\t".join(OUTPUT_COLUMNS) + "\n")
        for row in rows:
            handle.write("\t".join(str(row[column]) for column in OUTPUT_COLUMNS) + "\n")
    print(f"blocks={len(rows)} longest_valu_chain={max(row['longest_valu_chain'] for row in rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
