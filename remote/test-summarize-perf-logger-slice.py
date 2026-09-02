#!/usr/bin/env python3
"""summarize-perf-logger-slice.py over synthetic vk_perf_logger slices.

The parser reads the op as a name's leading whitespace-delimited token, so
an operand list and a shape descriptor each stay inside their own op, a
`", "` component counts as a second op only in the concurrent overload's
fused form, and a block missing its rows or its terminal `Total time:`
line refuses the slice by index.

Every block also states a graph shape from the largest `n` over its matmul
rows that name a non-f32 source, so each op-parsing fixture carries one
single-token weight row to sit in the decode class the aggregate reads.
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


def run(lines, decode=1, name="slice.log"):
    path = write(name, "\n".join(lines) + "\n")
    return subprocess.run([sys.executable, slicer, path, "--expected-decode-blocks", str(decode)],
                          capture_output=True, text=True)


def inventory(result):
    assert result.returncode == 0, result.stderr
    rows = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
    assert rows[0][0] == "op", rows
    summary = {row[0]: row for row in rows if row[0] != "op"}
    assert set(summary) == {"blocks", "decode_blocks", "prefill_blocks", "unknown_blocks"}, rows
    return {row[1]: row for row in rows[1:] if row[0] == "op"}, summary


# The weight rows of a single-token graph read n=1, so this row puts a block
# in the decode class the aggregate reads.
decode_marker = "MUL_MAT_VEC q4_K m=2048 n=1 k=2048: 1 x 1.0 us = 1.0 us"


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
ops, summary = inventory(run(block(attention, attention_tight, decode_marker)))
assert set(ops) == {"FLASH_ATTN_EXT", "MUL_MAT"}, ops
assert ops["FLASH_ATTN_EXT"][2] == "16.000" and ops["FLASH_ATTN_EXT"][3] == "4800.0", ops
assert ops["FLASH_ATTN_EXT"][4] == "300.000", ops
assert summary["blocks"][1] == "1" and summary["decode_blocks"][1] == "1", summary
print("flash_attn_operands=one_op")

# The MUL_MAT branch appends the source type and the m/n/k triple to the op
# name, and `_VEC` marks the mat-vec pipeline of the same op.
ops, _ = inventory(run(block("MUL_MAT_VEC q4_K m=2048 n=1 k=2048: 24 x 120.5 us = 2892.0 us (12.3 GFLOPS/s)",
                            "MUL_MAT_ID q4_K m=2048 n=1 k=2048 n_expert=8 batch=2: 4 x 50.0 us = 200.0 us")))
assert set(ops) == {"MUL_MAT", "MUL_MAT_ID"}, ops
assert ops["MUL_MAT"][2] == "24.000" and ops["MUL_MAT"][3] == "2892.0", ops
assert ops["MUL_MAT_ID"][2] == "4.000", ops
print("mul_mat_vec_shape=one_op")

# The vector log_timing overload joins whole per-node names, so a second
# uppercase token that ends its component or opens a shape counts, while the
# CONV_2D descriptor's own `, K=` and `, N=` fields stay operands.
ops, _ = inventory(run(block("RMS_NORM(2048,1,1,1), MUL: 48 x 4.0 us = 192.0 us",
                            "ADD, RMS_NORM(2048,1,1,1): 24 x 3.0 us = 72.0 us",
                            "CONV_2D M=Cout=64, K=Cin*KW*KH=576, N=N*OW*OH=4096: 2 x 90.0 us = 180.0 us",
                            decode_marker)))
assert set(ops) == {"RMS_NORM", "MUL", "ADD", "CONV_2D", "MUL_MAT"}, ops
assert ops["RMS_NORM"][2] == "72.000" and ops["MUL"][2] == "48.000", ops
assert ops["ADD"][2] == "24.000" and ops["CONV_2D"][2] == "2.000", ops
print("fused_component=two_ops")

# A fusion string reaches the name as a prefix, so the fused kernel is the op.
ops, _ = inventory(run(block("RMS_NORM_MUL RMS_NORM(2048,1,1,1): 24 x 5.0 us = 120.0 us", decode_marker)))
assert set(ops) == {"RMS_NORM_MUL", "MUL_MAT"}, ops
print("fusion_prefix=one_op")

# A fusion prefix pushes the shape descriptor off the leading token, so the
# classifier scans the whole name and reads this block's own n=1.
ops, summary = inventory(run(block("MUL_MAT_ADD MUL_MAT_VEC q4_K m=2048 n=1 k=6144: 12 x 100.0 us = 1200.0 us")))
assert set(ops) == {"MUL_MAT_ADD"} and summary["decode_blocks"][1] == "1", (ops, summary)
print("fused_matmul_descriptor=decode")

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
ops, summary = inventory(run(["MUL_MAT_VEC q4_K m=2048 n=1 k=2048: 99 x 1.0 us = 99.0 us",
                              "Total time: 99.0 us."]
                             + block("ROPE: 24 x 3.0 us = 72.0 us", decode_marker)))
assert set(ops) == {"ROPE", "MUL_MAT"} and summary["blocks"][1] == "1", (ops, summary)
assert ops["MUL_MAT"][2] == "1.000", ops
print("orphan_prefix=excluded")

# A prompt graph carries the token count on its weight rows, and the f32 chunk
# products of GATED_DELTA_NET carry a chunk dimension scaled by that count, so
# the classifier reads the weight rows alone in both classes.
prefill = block("MUL_MAT q4_K m=6144 n=19 k=2048: 56 x 6311.2 us = 353427.0 us (75.7 GFLOPS/s)",
                "MUL_MAT f32 m=64 n=608 k=64: 6 x 454.886 us = 2729.32 us",
                "MUL_MAT_VEC q6_K m=248320 n=1 k=2048: 1 x 43837.6 us = 43837.6 us",
                "SCALE: 36 x 258.516 us = 9306.6 us")
decode = block("MUL_MAT_VEC q4_K m=6144 n=1 k=2048: 56 x 1304.39 us = 73045.7 us (19.3 GFLOPS/s)",
               "MUL_MAT f32 m=64 n=32 k=64: 6 x 474.62 us = 2847.72 us",
               "MUL_MAT_VEC f32 m=256 n=8 k=256: 6 x 477.033 us = 2862.2 us",
               "MUL_MAT_VEC q6_K m=248320 n=1 k=2048: 1 x 54868.4 us = 54868.4 us",
               "ROPE: 12 x 473.34 us = 5680.08 us")
ops, summary = inventory(run(prefill + decode + decode + decode, decode=3))
assert summary["blocks"][1] == "4", summary
assert summary["decode_blocks"][1] == "3", summary
assert summary["prefill_blocks"][1] == "1" and summary["unknown_blocks"][1] == "0", summary
# SCALE appears in the prompt graph alone, so a prefill row entering the
# aggregate would put it in the inventory.
assert set(ops) == {"MUL_MAT", "ROPE"}, ops
assert ops["ROPE"][2] == "12.000" and ops["ROPE"][3] == "17040.2", ops
assert ops["MUL_MAT"][2] == "69.000", ops
print("prefill_block=excluded")

result = run(prefill + decode + decode + decode, decode=4)
assert result.returncode != 0, result.stdout
assert "perf_logger_refused" in result.stderr, result.stderr
assert "holds 3 decode blocks of 4" in result.stderr and "expects 4" in result.stderr, result.stderr
print("expected_decode_blocks=refused")

# Both operands of an f32 matmul are activations, so its n states a chunk
# dimension and the block names no token column of its own.
result = run(decode + block("MUL_MAT f32 m=64 n=32 k=64: 6 x 474.62 us = 2847.72 us"), decode=1)
assert result.returncode != 0, result.stdout
assert "perf_logger_refused" in result.stderr and "block 2" in result.stderr, result.stderr
assert "unknown" in result.stderr, result.stderr
print("unknown_block=refused")

for name in os.listdir(work):
    os.unlink(os.path.join(work, name))
os.rmdir(work)
print("perf_logger_slice=accepted")
