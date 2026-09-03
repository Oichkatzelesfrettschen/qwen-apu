#!/usr/bin/env python3
"""Drive remote/raven2-shader-lab/depth.py over a synthetic gfx902 fragment
whose every row is computable by hand, and compare the whole depth.tsv against
those hand-computed values.

The fragment exercises the four parsing decisions that decide a wrong number
rather than an error: a register range destination (buffer_load_dwordx2 into
v[2:3]), an SDWA operand-select suffix trailing the last operand, a VOP3b
carry-out destination that names VCC in the position a source would occupy,
and a second basic block entered at a label after a conditional branch. It
also puts an accumulate form in the second block, where the destination is
also the third source and a chain that ignored that would read one shorter,
and a read of a register after a buffer_store names it, where treating the
store's data operand as a definition would truncate the chain there.

usage: test-depth.py
Exits 0 where every field matches and non-zero naming the first that does not.
"""
import pathlib
import subprocess
import sys
import tempfile

FRAGMENT = """BB0:
\ts_load_dwordx4 s[0:3], s[8:9], 0x0                          ; C00A0002 00000000
\tv_lshlrev_b32_e32 v1, 2, v0                                 ; 34020082
\ts_waitcnt lgkmcnt(0)                                        ; BF8CC07F
\tbuffer_load_dwordx2 v[2:3], v1, s[0:3], 0 offen             ; E0509000 80000201
\tbuffer_load_dword v4, v1, s[0:3], 0 offen offset:8          ; E0501008 80000401
\ts_waitcnt vmcnt(1)                                          ; BF8C0F71
\tv_add_co_u32_e32 v5, vcc, v2, v3                            ; 320A0702
\tv_and_b32_sdwa v6, v5, v4 dst_sel:DWORD src0_sel:BYTE_0     ; 7A0C0905
\tv_mad_u32_u24 v7, v6, v5, v4                                ; D1C30007 04120B06
\ts_cbranch_scc1 BB1                                          ; BF850001

BB1:
\tv_mov_b32_e32 v8, 0                                         ; 7E100280
\tds_read_b32 v9, v1                                          ; D86C0000 00090001
\ts_waitcnt lgkmcnt(0)                                        ; BF8CC07F
\tv_mac_f32_e32 v8, v9, v9                                    ; 2C101309
\tbuffer_store_dword v8, v1, s[0:3], 0 offen                  ; E0701000 80000801
\tv_add_f32_e32 v10, v8, v8                                   ; 02141108
\ts_endpgm                                                    ; BF810000
"""

EXPECTED_HEADER = (
    "block\tfirst_line\tlast_line\tterminator\tinstructions\tvalu\tvmem\tlds\tsalu\twaitcnt\t"
    "longest_valu_chain\tmax_vmem_in_flight\tmax_lgkm_in_flight\tvmcnt_arguments\tlgkmcnt_arguments"
)

# Block 1 runs from the s_load on line 2 to the branch on line 11. Its VALU
# chain is v_add_co_u32 (v2 and v3 arrive from a load, so depth 1), then
# v_and_b32_sdwa reading v5 (2), then v_mad_u32_u24 reading v6 (3); the vcc
# operand in the carry-out position names no VGPR and adds nothing. Two loads
# stand in flight at the vmcnt(1) wait, and the one scalar load stands at the
# lgkmcnt(0) wait ahead of them.
#
# Block 2 opens at the label on line 13 with its first instruction on line 14.
# v_mac_f32 reads its own destination, so v_mov into v8 and the accumulate
# form a chain of 2, and v_add_f32 reading v8 past the buffer_store that also
# names it extends that chain to 3. ds_read supplies v9 and counts against
# lgkmcnt alone, and the store issues with no later wait, so nothing stands in
# flight at a vmcnt boundary.
EXPECTED_ROWS = (
    "1\t2\t11\ts_cbranch_scc1\t10\t4\t2\t0\t2\t2\t3\t2\t1\t1\t0",
    "2\t14\t20\ts_endpgm\t7\t3\t1\t1\t0\t1\t3\t0\t1\t-\t0",
)


def main():
    script_directory = pathlib.Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory() as work_directory:
        work = pathlib.Path(work_directory)
        isa_file = work / "isa.s"
        depth_file = work / "depth.tsv"
        isa_file.write_text(FRAGMENT, encoding="utf-8")
        completed = subprocess.run(
            [sys.executable, str(script_directory / "depth.py"), str(isa_file), str(depth_file)],
            capture_output=True,
            text=True,
            check=False,
        )
        if completed.returncode != 0:
            print(f"depth.py exited {completed.returncode}: {completed.stderr}", file=sys.stderr)
            return 1
        produced = depth_file.read_text(encoding="utf-8").rstrip("\n").split("\n")

    expected = [EXPECTED_HEADER, *EXPECTED_ROWS]
    if len(produced) != len(expected):
        print(f"depth.tsv carries {len(produced)} lines against the {len(expected)} expected", file=sys.stderr)
        for line in produced:
            print(f"  {line}", file=sys.stderr)
        return 1
    for position, (produced_line, expected_line) in enumerate(zip(produced, expected)):
        if produced_line != expected_line:
            print(f"line {position + 1} differs", file=sys.stderr)
            print(f"  expected: {expected_line}", file=sys.stderr)
            print(f"  produced: {produced_line}", file=sys.stderr)
            return 1
    print(f"test-depth=pass blocks={len(EXPECTED_ROWS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
