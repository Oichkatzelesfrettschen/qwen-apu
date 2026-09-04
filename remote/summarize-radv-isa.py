#!/usr/bin/env python3
"""Split a RADV_DEBUG=shaders,shaderstats stderr log into one file per compute
pipeline's disassembly and one index row per pipeline.

The format assumption is read from mesa-25.3.2's own source
(src/amd/vulkan/radv_shader.c, functions radv_shader_dump_debug_info and
radv_dump_shader_stats) rather than guessed from a sample log. `RADV_DEBUG=shaders` writes one block per compiled
shader as `fprintf(stderr, "%s", radv_get_shader_name(...))` followed by
`fprintf(stderr, "\\ndisasm:\\n%s\\n", shader->disasm_string)`, so a block is a
bare stage-name line (llama.cpp's compute pipelines all print "Compute
Shader", carrying no ggml pipeline name) immediately followed by a literal
`disasm:` line and then the disassembly text. `RADV_DEBUG=shaderstats` writes
one block per shader as `fprintf(output, "\\n%s:\\n", ...)` then
`"*** SHADER STATS ***\\n"`, one `Name: value` line per statistic, and a
closing `"********************\\n\\n\\n"`, so a stats block opens on a blank
line, a `<stage name>:` line, and the marker line, and closes on a line of
twenty asterisks. Both debug flags interleave into the same stream in compile order, and this
reader has not been run against a live RADV process. Pairing by discovery
order alone is unsound wherever the two counts differ: `radv_dump_shader_stats`
needs a live VkPipeline handle, so it runs after the whole pipeline object
exists, where `radv_shader_dump_debug_info` runs from the shader-compile path
and a pipeline-cache hit can skip it, and a diverging count means the
per-position pairing has been wrong from that position onward. A count
mismatch therefore blanks every stats field on every row to "-" rather than
pairing a common prefix and risking a wrong number silently reaching
`isa-index.tsv`.

RADV's own dump names a shader by its pipeline stage ("Compute Shader" for
every one of llama.cpp's compute pipelines), never by ggml's pipeline name, so
`isa-index.tsv` cannot select `mul_mat_vec_q4_k_f16_f32` by name. Two
content-derived columns stand in: `code_sha256` is the SHA-256 of the block's
own disassembly text, for diffing one run's shader against another's without
opening both files, and `q4k_signature` reads whether the code contains the
literal immediates `mul_mat_vec_q4_k.comp`'s `calc_superblock` masks with --
`3f3f3f3f` from `scale_0_4_l & 0x3F3F3F3F` and `0f0f0f0f` from
`qs0_u32 & 0x0F0F0F0F` in
ggml/src/ggml-vulkan/vulkan-shaders/mul_mat_vec_q4_k.comp -- reporting
`q4k` where both appear, `nibble-only` where `0f0f0f0f` appears without
`3f3f3f3f` (the Q4_0/Q4_1 family's own mask), and `-` otherwise. The
signature is a grep over compiled immediates rather than a proof of pipeline
identity, since ACO's constant folding or operand ordering could place a mask
differently than the GLSL source states it; a row it flags is where an
operator starts reading, not the whole of E1's identification.

Within one disassembly, an instruction line's mnemonic is its first
whitespace-separated token. `v_` counts toward VALU, `s_` toward SALU,
`buffer_`, `global_`, and `flat_` toward VMEM, and `ds_` toward the LDS
instruction count; a label, directive, or blank line matches none of them.

usage: summarize-radv-isa.py LOG_FILE ISA_DIR INDEX_TSV
Writes ISA_DIR/NNN.s for each disassembly block found, in discovery order
starting at 001, and INDEX_TSV as one header row and one row per block:
index, pipeline_name, code_sha256, q4k_signature, vgprs, sgprs,
spilled_vgprs, lds, scratch, code_size, valu_count, salu_count, vmem_count,
lds_count. A field the stats block did not carry, that carried no stats
block at all, or whose stats and disasm counts disagreed reads "-".
"""
import argparse
import hashlib
import pathlib
import re
import sys

STATS_MARKER = "*** SHADER STATS ***"
STATS_CLOSE = "*" * 20

# The exact statistic names vk_add_amd_stats emits are not confirmed against
# a live run, so a stat is matched by substring on its lowercased name rather
# than by an exact key. "Spilled VGPR" is checked ahead of the bare "VGPR"
# substring so a spill count is never read into the VGPR field.
STAT_FIELD_PATTERNS = (
    ("spilled_vgprs", ("spilled vgpr",)),
    ("vgprs", ("vgpr",)),
    ("sgprs", ("sgpr",)),
    ("lds", ("lds",)),
    ("scratch", ("scratch",)),
    ("code_size", ("code size",)),
)

INSTRUCTION_PREFIXES = (
    ("valu_count", ("v_",)),
    ("salu_count", ("s_",)),
    ("vmem_count", ("buffer_", "global_", "flat_")),
    ("lds_count", ("ds_",)),
)

LEADING_NUMBER = re.compile(r"-?\d+")


class RadvLogError(Exception):
    pass


def is_disasm_header(lines, index):
    if index + 1 >= len(lines):
        return False
    header = lines[index]
    return bool(header.strip()) and lines[index + 1] == "disasm:"


def is_stats_header(lines, index):
    if index + 2 >= len(lines):
        return False
    return (
        lines[index] == ""
        and lines[index + 1].endswith(":")
        and lines[index + 1].strip() != ":"
        and lines[index + 2] == STATS_MARKER
    )


# The "shaders" option is the union RADV_DEBUG_DUMP_SHADERS
# (src/amd/vulkan/radv_debug.h:79), which carries DUMP_NIR and
# DUMP_BACKEND_IR beside DUMP_ASM, so the stream between one pipeline's
# disassembly and the next pipeline's stage-name line also holds that next
# pipeline's final NIR and ACO's three program prints. A disassembly
# therefore ends at whichever comes first of its own shaderstats block, the
# nir_print_shader opener, an aco_print_program header, and the next
# disassembly header; ending it at the next disassembly header alone appends
# a following shader's IR to this one's instruction counts.
NIR_OPENER = re.compile(r"^shader: MESA_SHADER_")
ACO_HEADER = re.compile(r"^After (Instruction Selection|Spilling|RA|lowering)")


def is_block_boundary(lines, index):
    line = lines[index]
    return (
        is_disasm_header(lines, index)
        or is_stats_header(lines, index)
        or line == STATS_MARKER
        or bool(NIR_OPENER.match(line))
        or bool(ACO_HEADER.match(line))
    )


def parse_log(text):
    """Return (disasm_blocks, stats_blocks) in discovery order.

    Each disasm block is {"header": str, "code": list[str]}; each stats
    block is {"header": str, "fields": dict[str, str]}.
    """
    lines = text.split("\n")
    disasm_blocks = []
    stats_blocks = []
    index = 0
    total = len(lines)
    while index < total:
        if is_disasm_header(lines, index):
            header = lines[index]
            index += 2
            code_start = index
            while index < total and not is_block_boundary(lines, index):
                index += 1
            code_lines = lines[code_start:index]
            # A stats block opens on a blank line and a "<stage name>:" line,
            # and radv_shader_dump_debug_info's own trailing newline leaves
            # one more blank; both belong to the delimiter rather than to the
            # code.
            while code_lines and (code_lines[-1] == "" or code_lines[-1].endswith(":")):
                code_lines.pop()
            disasm_blocks.append({"header": header, "code": code_lines})
            continue
        if is_stats_header(lines, index):
            header = lines[index + 1][:-1]
            index += 3
            stat_start = index
            while index < total and lines[index] != STATS_CLOSE:
                index += 1
            if index >= total:
                raise RadvLogError("a shaderstats block never reaches its closing line")
            stat_lines = lines[stat_start:index]
            index += 1
            stats_blocks.append({"header": header, "fields": parse_stat_lines(stat_lines)})
            continue
        index += 1
    return disasm_blocks, stats_blocks


def parse_stat_lines(stat_lines):
    fields = {}
    for line in stat_lines:
        if not line.strip():
            continue
        name, separator, value = line.partition(":")
        if not separator:
            continue
        fields[name.strip()] = value.strip()
    return fields


def select_stat_value(fields, field_name):
    patterns = dict(STAT_FIELD_PATTERNS)[field_name]
    exclude_spilled = field_name in ("vgprs", "sgprs")
    for name, value in fields.items():
        lowered = name.lower()
        if exclude_spilled and "spilled" in lowered:
            continue
        if any(pattern in lowered for pattern in patterns):
            match = LEADING_NUMBER.search(value)
            if match:
                return match.group(0)
            return value
    return "-"


def count_instructions(code_lines):
    counts = dict.fromkeys((name for name, _ in INSTRUCTION_PREFIXES), 0)
    for line in code_lines:
        stripped = line.strip()
        if not stripped:
            continue
        mnemonic = stripped.split(None, 1)[0]
        for field_name, prefixes in INSTRUCTION_PREFIXES:
            if mnemonic.startswith(prefixes):
                counts[field_name] += 1
                break
    return counts


Q4K_SCALE_MASK = "3f3f3f3f"
Q4K_NIBBLE_MASK = "0f0f0f0f"


def q4k_signature(code_lines):
    """Grep the compiled immediates mul_mat_vec_q4_k.comp's calc_superblock
    masks with, to give an operator a starting point for locating the Q4_K
    mat-vec pipeline among many identically-named "Compute Shader" blocks.
    This is a heuristic over immediates ACO chose to keep or fold, not a
    proof of pipeline identity.
    """
    lowered = "\n".join(code_lines).lower()
    has_scale_mask = Q4K_SCALE_MASK in lowered
    has_nibble_mask = Q4K_NIBBLE_MASK in lowered
    if has_scale_mask and has_nibble_mask:
        return "q4k"
    if has_nibble_mask:
        return "nibble-only"
    return "-"


def build_index_rows(disasm_blocks, stats_blocks):
    # radv_dump_shader_stats needs a live VkPipeline handle and so runs after
    # the whole pipeline object exists, where radv_shader_dump_debug_info
    # runs from the shader-compile path and a pipeline-cache hit can skip it.
    # A diverging count means positional pairing is wrong from the first
    # divergence onward, so every stats field is blanked rather than pairing
    # a prefix that might already be misattributed.
    pairing_sound = bool(stats_blocks) and len(stats_blocks) == len(disasm_blocks)
    if stats_blocks and not pairing_sound:
        print(
            f"warning: {len(disasm_blocks)} disasm blocks against "
            f"{len(stats_blocks)} shaderstats blocks; positional pairing is "
            "unsound, every stats field reads -",
            file=sys.stderr,
        )
    rows = []
    for position, block in enumerate(disasm_blocks):
        stats = stats_blocks[position]["fields"] if pairing_sound else {}
        counts = count_instructions(block["code"])
        code_sha256 = hashlib.sha256("\n".join(block["code"]).encode("utf-8")).hexdigest()
        row = {
            "index": position + 1,
            # RADV's own dump names the shader stage ("Compute Shader") and
            # carries no ggml pipeline name, so this field is always "-".
            "pipeline_name": "-",
            "code_sha256": code_sha256,
            "q4k_signature": q4k_signature(block["code"]),
        }
        for field_name, _ in STAT_FIELD_PATTERNS:
            row[field_name] = select_stat_value(stats, field_name) if stats else "-"
        row.update(counts)
        rows.append(row)
    return rows


INDEX_COLUMNS = (
    "index", "pipeline_name", "code_sha256", "q4k_signature", "vgprs",
    "sgprs", "spilled_vgprs", "lds", "scratch", "code_size", "valu_count",
    "salu_count", "vmem_count", "lds_count",
)


def write_outputs(disasm_blocks, rows, isa_directory, index_path):
    isa_directory.mkdir(parents=True, exist_ok=True)
    for position, block in enumerate(disasm_blocks):
        shader_path = isa_directory / f"{position + 1:03d}.s"
        shader_path.write_text(
            block["header"] + "\n" + "\n".join(block["code"]) + "\n",
            encoding="utf-8",
        )
    with index_path.open("w", encoding="utf-8") as handle:
        handle.write("\t".join(INDEX_COLUMNS) + "\n")
        for row in rows:
            handle.write("\t".join(str(row[column]) for column in INDEX_COLUMNS) + "\n")


def main(argv):
    parser = argparse.ArgumentParser(
        description="Split a RADV_DEBUG=shaders,shaderstats log into per-shader ISA and an index."
    )
    parser.add_argument("log_file", type=pathlib.Path)
    parser.add_argument("isa_dir", type=pathlib.Path)
    parser.add_argument("index_tsv", type=pathlib.Path)
    args = parser.parse_args(argv)

    text = args.log_file.read_text(encoding="utf-8", errors="replace")
    try:
        disasm_blocks, stats_blocks = parse_log(text)
    except RadvLogError as error:
        print(f"{args.log_file}: {error}", file=sys.stderr)
        return 1

    if not disasm_blocks:
        print(f"{args.log_file}: no RADV_DEBUG=shaders disassembly block found", file=sys.stderr)
        return 1

    rows = build_index_rows(disasm_blocks, stats_blocks)
    write_outputs(disasm_blocks, rows, args.isa_dir, args.index_tsv)
    print(f"shaders={len(disasm_blocks)} shaderstats={len(stats_blocks)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
