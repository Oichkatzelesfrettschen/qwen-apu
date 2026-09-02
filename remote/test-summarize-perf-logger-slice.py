#!/usr/bin/env python3
"""summarize-perf-logger-slice.py over synthetic vk_perf_logger slices.

The parser reads the op as a name's leading whitespace-delimited token, so
an operand list and a shape descriptor each stay inside their own op, a
`", "` component counts as a second op only in the concurrent overload's
fused form, and a block missing its rows or its terminal `Total time:`
line refuses the slice by index.
"""
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
slicer = os.path.join(script_directory, "summarize-perf-logger-slice.py")
work = tempfile.mkdtemp(prefix="perf-logger-slice-")


def write(name, text):
    path = os.path.join(work, name)
    with open(path, "w") as handle:
        handle.write(text)
    return path


def run(lines, minimum=1, name="slice.log"):
    path = write(name, "\n".join(lines) + "\n")
    return subprocess.run([sys.executable, slicer, path, "--expected-min-blocks", str(minimum)],
                          capture_output=True, text=True)


def inventory(result):
    assert result.returncode == 0, result.stderr
    rows = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
    assert rows[0][0] == "op" and rows[-1][0] == "blocks", rows
    return {row[1]: row for row in rows[1:-1]}, rows[-1]


def block(*rows):
    return ["----------------", "Vulkan Timings:", *rows, "Total time: 1000.0 us."]


# get_node_fusion_name writes the FLASH_ATTN_EXT operands as `dst(...),  q(...)`
# with two spaces, since the stream inserts `", "` ahead of a leading-space
# operand; both that form and the single-space one name one op, because every
# operand after the leading token is lowercase.
attention = ("FLASH_ATTN_EXT dst(128,32,8,1),  q(128,32,8,1),  k(128,512,2,1),"
             "  v(128,512,2,1),  m(512,32,0,0): 8 x 300.0 us = 2400.0 us")
attention_tight = ("FLASH_ATTN_EXT dst(128,32,8,1), q(128,32,8,1), k(128,512,2,1),"
                   " v(128,512,2,1), m(512,32,0,0): 8 x 300.0 us = 2400.0 us")
ops, footer = inventory(run(block(attention, attention_tight)))
assert set(ops) == {"FLASH_ATTN_EXT"}, ops
assert ops["FLASH_ATTN_EXT"][2] == "16.000" and ops["FLASH_ATTN_EXT"][3] == "4800.0", ops
assert footer[1] == "1", footer
print("flash_attn_operands=one_op")

# The MUL_MAT branch appends the source type and the m/n/k triple to the op
# name, and `_VEC` marks the mat-vec pipeline of the same op.
ops, _ = inventory(run(block("MUL_MAT_VEC q4_K m=2048 n=1 k=2048: 24 x 120.5 us = 2892.0 us (12.3 GFLOPS/s)",
                            "MUL_MAT_ID q4_K m=2048 n=4 k=2048 n_expert=8 batch=2: 4 x 50.0 us = 200.0 us")))
assert set(ops) == {"MUL_MAT", "MUL_MAT_ID"}, ops
assert ops["MUL_MAT"][2] == "24.000" and ops["MUL_MAT"][3] == "2892.0", ops
assert ops["MUL_MAT_ID"][2] == "4.000", ops
print("mul_mat_vec_shape=one_op")

# The vector log_timing overload joins whole per-node names, so a second
# uppercase token that ends its component or opens a shape counts, while the
# CONV_2D descriptor's own `, K=` and `, N=` fields stay operands.
ops, _ = inventory(run(block("RMS_NORM(2048,1,1,1), MUL: 48 x 4.0 us = 192.0 us",
                            "ADD, RMS_NORM(2048,1,1,1): 24 x 3.0 us = 72.0 us",
                            "CONV_2D M=Cout=64, K=Cin*KW*KH=576, N=N*OW*OH=4096: 2 x 90.0 us = 180.0 us")))
assert set(ops) == {"RMS_NORM", "MUL", "ADD", "CONV_2D"}, ops
assert ops["RMS_NORM"][2] == "72.000" and ops["MUL"][2] == "48.000", ops
assert ops["ADD"][2] == "24.000" and ops["CONV_2D"][2] == "2.000", ops
print("fused_component=two_ops")

# A fusion string reaches the name as a prefix, so the fused kernel is the op.
ops, _ = inventory(run(block("RMS_NORM_MUL RMS_NORM(2048,1,1,1): 24 x 5.0 us = 120.0 us")))
assert set(ops) == {"RMS_NORM_MUL"}, ops
print("fusion_prefix=one_op")

result = run(block("ROPE: 24 x 3.0 us = 72.0 us") + ["----------------", "Vulkan Timings:",
                                                     "ROPE: 24 x 3.0 us = 72.0 us"])
assert result.returncode != 0, result.stdout
assert "perf_logger_refused" in result.stderr and "block 2" in result.stderr, result.stderr
assert "Total time:" in result.stderr, result.stderr
print("unterminated_block=refused")

result = run(["----------------", "Vulkan Timings:", "Total time: 0.0 us."]
             + block("ROPE: 24 x 3.0 us = 72.0 us"))
assert result.returncode != 0, result.stdout
assert "perf_logger_refused" in result.stderr and "block 1" in result.stderr, result.stderr
assert "no timing row" in result.stderr, result.stderr
print("empty_block=refused")

# Rows ahead of the first header belong to a block the slice opened before its
# window, so they join no block and the inventory reads the whole blocks alone.
ops, footer = inventory(run(["MUL_MAT_VEC q4_K m=2048 n=1 k=2048: 99 x 1.0 us = 99.0 us",
                             "Total time: 99.0 us."] + block("ROPE: 24 x 3.0 us = 72.0 us")))
assert set(ops) == {"ROPE"} and footer[1] == "1", (ops, footer)
print("orphan_prefix=excluded")

result = run(block("ROPE: 24 x 3.0 us = 72.0 us") + block("ROPE: 24 x 3.0 us = 72.0 us"), minimum=3)
assert result.returncode != 0, result.stdout
assert "perf_logger_refused" in result.stderr and "holds 2 blocks" in result.stderr, result.stderr
print("expected_min_blocks=refused")

for name in os.listdir(work):
    os.unlink(os.path.join(work, name))
os.rmdir(work)
print("perf_logger_slice=accepted")
