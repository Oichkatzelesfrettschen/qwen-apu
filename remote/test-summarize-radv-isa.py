#!/usr/bin/env python3
"""summarize-radv-isa.py over a synthetic RADV_DEBUG=shaders,shaderstats log.

The fixture below is hand-assembled rather than captured from a device,
because RADV_DEBUG runs only through RADV on a real GPU. Its shape follows
mesa-25.3.2's src/amd/vulkan/radv_shader.c read on the workstation this test
runs on: `radv_shader_dump_debug_info` prints a bare stage-name line, a
literal `disasm:` line, and the disassembly text with no other delimiter, and
`radv_dump_shader_stats` prints a blank line, `<stage name>:`,
`*** SHADER STATS ***`, one `Name: value` line per statistic, and a
twenty-asterisk closing line followed by two blank lines. Both flags write to
the same stream in shader-compile order, so a two-pipeline log interleaves as
disasm, stats, disasm, stats. This test states that interleaving as an
assumption to verify positional pairing; it is not proof of RADV's own
ordering, and a shader-only log (no shaderstats block) is exercised
separately to prove the reader tolerates that half being absent.
"""
import pathlib
import subprocess
import sys
import tempfile

script_directory = pathlib.Path(__file__).resolve().parent
summarizer = script_directory / "summarize-radv-isa.py"


def disasm_block(instructions):
    return "Compute Shader\ndisasm:\n" + "\n".join(instructions) + "\n"


def stats_block(vgprs, sgprs, spilled_vgprs, lds, scratch, code_size):
    return (
        "\nCompute Shader:\n*** SHADER STATS ***\n"
        f"SGPRS: {sgprs}\n"
        f"VGPRS: {vgprs} ({spilled_vgprs} as spill)\n"
        f"Spilled VGPRs: {spilled_vgprs}\n"
        f"Spilled SGPRs: 0\n"
        f"LDS: {lds} bytes\n"
        f"Scratch: {scratch} bytes per wave\n"
        f"Code Size: {code_size} bytes\n"
        "Max Waves: 4\n"
        "********************\n\n\n"
    )


FIRST_INSTRUCTIONS = [
    "BB0:",
    "\ts_load_dwordx4 s[0:3], s[4:5], 0x0                       // 000000000000: F4080000 FA000000",
    "\tv_mov_b32_e32 v0, 0                                      // 000000000008: 7E000280",
    "\tv_mov_b32_e32 v1, 1                                      // 00000000000C: 7E020281",
    "\tv_mad_u32_u24 v2, v0, v1, s0                              // 000000000010: D5760002 00020100",
    "\tbuffer_load_dwordx4 v[4:7], v0, s[0:3], 0 offen           // 000000000018: E0501000 80000004",
    "\tds_read_b32 v8, v0                                       // 000000000020: D8D80000 08000000",
    "\ts_endpgm                                                 // 000000000024: BF810000",
]

SECOND_INSTRUCTIONS = [
    "BB0:",
    "\tv_cvt_f32_ubyte0_e32 v0, v1                              // 000000000000: 7E000700",
    "\tv_fma_f32 v2, v0, v1, v3                                 // 000000000004: D52B0002 040D0300",
    "\ts_endpgm                                                 // 00000000000C: BF810000",
]


def run(text):
    with tempfile.TemporaryDirectory() as scratch:
        scratch_path = pathlib.Path(scratch)
        log_path = scratch_path / "radv-shaders.log"
        log_path.write_text(text, encoding="utf-8")
        isa_directory = scratch_path / "isa"
        index_tsv = scratch_path / "isa-index.tsv"
        result = subprocess.run(
            [sys.executable, str(summarizer), str(log_path), str(isa_directory), str(index_tsv)],
            capture_output=True,
            text=True,
        )
        rows = None
        shader_files = None
        if index_tsv.exists():
            rows = index_tsv.read_text(encoding="utf-8").rstrip("\n").split("\n")
        if isa_directory.exists():
            shader_files = sorted(p.name for p in isa_directory.iterdir())
        return result, rows, shader_files


two_pipeline_log = (
    disasm_block(FIRST_INSTRUCTIONS)
    + stats_block(vgprs=64, sgprs=24, spilled_vgprs=0, lds=0, scratch=0, code_size=40)
    + disasm_block(SECOND_INSTRUCTIONS)
    + stats_block(vgprs=12, sgprs=8, spilled_vgprs=2, lds=128, scratch=64, code_size=16)
)

result, rows, shader_files = run(two_pipeline_log)
assert result.returncode == 0, result.stderr
assert shader_files == ["001.s", "002.s"], shader_files
assert rows[0].split("\t") == [
    "index", "pipeline_name", "code_sha256", "q4k_signature", "vgprs",
    "sgprs", "spilled_vgprs", "lds", "scratch", "code_size", "valu_count",
    "salu_count", "vmem_count", "lds_count",
], rows[0]

first_row = rows[1].split("\t")
assert first_row[0] == "1" and first_row[1] == "-", first_row
assert len(first_row[2]) == 64, first_row  # code_sha256 is a hex digest
assert first_row[3] == "-", first_row  # FIRST_INSTRUCTIONS carries no q4k mask
assert first_row[4:10] == ["64", "24", "0", "0", "0", "40"], first_row
# FIRST_INSTRUCTIONS: two v_ mnemonics, one v_mad (v_), two s_ (load, endpgm),
# one buffer_ load, one ds_ read, and the BB0: label counts toward none.
assert first_row[10:] == ["3", "2", "1", "1"], first_row

second_row = rows[2].split("\t")
assert second_row[3] == "-", second_row
assert second_row[4:10] == ["12", "8", "2", "128", "64", "16"], second_row
# SECOND_INSTRUCTIONS: v_cvt_f32_ubyte0_e32 and v_fma_f32 are both v_, one s_.
assert second_row[10:] == ["2", "1", "0", "0"], second_row
assert first_row[2] != second_row[2], (first_row, second_row)  # distinct code hashes

print("two_pipeline_pairing=accepted")

# A shader-only log carries no shaderstats block, which the pinned build
# produces under RADV_DEBUG=shaders alone; every stat field reads "-" rather
# than raising, and the instruction counts still come from the disassembly.
shader_only_log = disasm_block(FIRST_INSTRUCTIONS)
result, rows, shader_files = run(shader_only_log)
assert result.returncode == 0, result.stderr
assert shader_files == ["001.s"], shader_files
row = rows[1].split("\t")
assert row[4:10] == ["-", "-", "-", "-", "-", "-"], row
assert row[10:] == ["3", "2", "1", "1"], row
print("shader_only_log=accepted")

# A mismatched block count blanks every stats field on every row rather than
# pairing a common prefix, because radv_dump_shader_stats runs after the
# whole pipeline object exists (it needs a live VkPipeline handle) where
# radv_shader_dump_debug_info runs from the shader-compile path, so a
# pipeline-cache hit can produce more stats blocks than disasm blocks, or
# fewer, and a positional pairing across that divergence is not sound at any
# position. The run still succeeds because the disasm side is what the
# caller relies on for the ISA count.
mismatched_log = (
    disasm_block(FIRST_INSTRUCTIONS)
    + disasm_block(SECOND_INSTRUCTIONS)
    + stats_block(vgprs=64, sgprs=24, spilled_vgprs=0, lds=0, scratch=0, code_size=40)
)
result, rows, shader_files = run(mismatched_log)
assert result.returncode == 0, result.stderr
assert "2 disasm blocks against 1 shaderstats blocks" in result.stderr, result.stderr
assert "unsound" in result.stderr, result.stderr
assert shader_files == ["001.s", "002.s"], shader_files
first_row = rows[1].split("\t")
second_row = rows[2].split("\t")
assert first_row[4:10] == ["-", "-", "-", "-", "-", "-"], first_row
assert second_row[4:10] == ["-", "-", "-", "-", "-", "-"], second_row
print("mismatched_block_count=accepted")

# The Q4_K signature is a grep over the compiled immediates
# calc_superblock's own masks reach ACO with: 3f3f3f3f from the scale mask
# and 0f0f0f0f from the nibble mask, together reading "q4k"; the nibble mask
# alone (the Q4_0/Q4_1 family's own extraction) reads "nibble-only"; neither
# reads "-", which the two pipelines above already exercise.
q4k_instructions = [
    "\tv_and_b32_e32 v0, 0x0f0f0f0f, v1                          // 000000000000: 260002FF 0F0F0F0F",
    "\tv_and_b32_e32 v2, 0x3f3f3f3f, v3                          // 000000000008: 260406FF 3F3F3F3F",
    "\ts_endpgm                                                 // 000000000010: BF810000",
]
result, rows, shader_files = run(disasm_block(q4k_instructions))
assert result.returncode == 0, result.stderr
row = rows[1].split("\t")
assert row[3] == "q4k", row
print("q4k_signature=accepted")

nibble_only_instructions = [
    "\tv_and_b32_e32 v0, 0x0f0f0f0f, v1                          // 000000000000: 260002FF 0F0F0F0F",
    "\ts_endpgm                                                 // 000000000008: BF810000",
]
result, rows, shader_files = run(disasm_block(nibble_only_instructions))
assert result.returncode == 0, result.stderr
row = rows[1].split("\t")
assert row[3] == "nibble-only", row
print("nibble_only_signature=accepted")

# An empty log, or one carrying no disasm block at all, is refused rather
# than producing an empty index silently.
result, rows, shader_files = run("no shader output here\n")
assert result.returncode != 0, result.stdout
assert "no RADV_DEBUG=shaders disassembly block found" in result.stderr, result.stderr
print("no_disasm_block=refused")

# RADV_DEBUG=shaders is the union RADV_DEBUG_DUMP_SHADERS
# (src/amd/vulkan/radv_debug.h:79), which turns on DUMP_NIR and
# DUMP_BACKEND_IR beside DUMP_ASM, so a log collected under that option alone
# carries each pipeline's final NIR and ACO's program prints between one
# disassembly and the next stage-name line. ACO prints an instruction that
# defines nothing under its own mnemonic, so a disassembly block that ran to
# the next stage-name line would count the following pipeline's s_waitcnt,
# ds_write_b32, and s_endpgm as its own. The counts below are the same three
# VALU, two SALU, one VMEM, and one LDS the asm-only log produces.
nir_and_aco_prelude = (
    "shader: MESA_SHADER_COMPUTE\n"
    "name: main\n"
    "decl_function main () (entrypoint)\n"
    "\t32     %0 = @load_local_invocation_index\n"
    "\t32     %1 = ishl %0, %2\n"
    "\n"
    "After Instruction Selection:\n"
    "Compute Shader\n"
    "BB0\n"
    "\tv1: %3:v[0] = v_mov_b32 0\n"
    "\ts_waitcnt lgkmcnt(0)\n"
    "\tds_write_b32 %4:v[1], %3:v[0]\n"
    "\ts_endpgm\n"
    "\n"
)
shaders_union_log = (
    nir_and_aco_prelude
    + disasm_block(FIRST_INSTRUCTIONS)
    + nir_and_aco_prelude
    + disasm_block(SECOND_INSTRUCTIONS)
)
result, rows, shader_files = run(shaders_union_log)
assert result.returncode == 0, result.stderr
assert shader_files == ["001.s", "002.s"], shader_files
first_row = rows[1].split("\t")
second_row = rows[2].split("\t")
assert first_row[10:] == ["3", "2", "1", "1"], first_row
assert second_row[10:] == ["2", "1", "0", "0"], second_row
print("shaders_union_log=accepted")

print("summarize_radv_isa=accepted")
