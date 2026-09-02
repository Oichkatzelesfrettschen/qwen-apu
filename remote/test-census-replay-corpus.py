#!/usr/bin/env python3
"""Run the three census readers over retained Raven2 bytes, not fixtures.

`evidence/raven2-vulkan-kernel-census/replay-corpus/` holds one I1
`pipeline-census.tsv` (compressed), its clock sidecar, an S
`server-log-request.slice`, and a P clock sidecar carrying a real 42 ms
scheduler slice, all copied from the acquisition run named in the corpus README and
sanitized of the private host name and home path. A synthetic fixture proves
a reader's rules against inputs the reader's own author shaped; this script
proves the current reader still reads the device's own output the way the
corpus README records, so a reader change that agrees with every synthetic
fixture but disagrees with real bytes is caught here instead of on the next
appliance run.

Six named cases, one function each, cover the six shapes the corpus
retains: raven2-i1-good, raven2-s-mixed-phase, raven2-sidecar-gap,
raven2-sidecar-good, raven2-two-context, and raven2-f32-activation-matmul.
Each case prints `case=<name> verdict=accepted` on success; a reader change
satisfies every case here before it reaches a device request.

usage: test-census-replay-corpus.py
Exits 0 and prints `census_replay_corpus=accepted` on agreement.
"""
import importlib.util
import lzma
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
repository_root = os.path.dirname(script_directory)
corpus = os.path.join(repository_root, "evidence", "raven2-vulkan-kernel-census",
                       "replay-corpus")
census_summarizer = os.path.join(script_directory, "summarize-kernel-census.py")
slice_summarizer = os.path.join(script_directory, "summarize-perf-logger-slice.py")
sidecar_validator = os.path.join(script_directory, "validate-clock-sidecar.py")


def read_window(path):
    begin = end = None
    with open(path) as handle:
        for line in handle:
            key, _, value = line.rstrip("\n").partition("\t")
            if key == "begin_ns":
                begin = value
            elif key == "end_ns":
                end = value
    if begin is None or end is None:
        raise SystemExit(f"{path} carries no begin_ns/end_ns pair")
    return begin, end


def run(argv):
    return subprocess.run(argv, capture_output=True, text=True)


def field(row, prefix):
    for token in row:
        if token.startswith(prefix):
            return token[len(prefix):]
    raise AssertionError(f"{prefix} missing from {row}")


def load_kernel_census_module():
    """Import summarize-kernel-census.py by path for direct row inspection.

    raven2-f32-activation-matmul counts rows from the parsed census itself,
    ahead of the summarizer's own output, so the corpus test needs the
    parser as a library rather than as a subprocess.
    """
    spec = importlib.util.spec_from_file_location("summarize_kernel_census", census_summarizer)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


work = tempfile.mkdtemp(prefix="census-replay-corpus-")
i1_directory = os.path.join(corpus, "10-I1")
census_path = os.path.join(work, "pipeline-census.tsv")
with lzma.open(os.path.join(i1_directory, "pipeline-census.tsv.xz")) as compressed:
    data = compressed.read()
with open(census_path, "wb") as handle:
    handle.write(data)
window_begin, window_end = read_window(os.path.join(i1_directory, "request-window.tsv"))


def run_census_summarizer():
    return run([sys.executable, census_summarizer, census_path,
                "--window-begin-ns", window_begin, "--window-end-ns", window_end,
                "--expected-decode-graphs", "63", "--phase", "decode",
                "--overlap-threshold", "0.05"])


def case_raven2_i1_good():
    """The retained I1 census still reads 63 decode graphs under conclusive
    ownership at the bracket_union_ms_per_graph and submits_per_graph the
    acquisition run measured, so a reader regression that moves either
    figure is caught against real bytes rather than a synthetic fixture."""
    result = run_census_summarizer()
    assert result.returncode == 0, result.stderr
    graphs = result.stdout.rstrip("\n").split("\n")[-1].split("\t")
    assert graphs[0] == "graphs" and graphs[1] == "decode" and graphs[2] == "63", graphs
    assert field(graphs, "ownership=") == "conclusive", graphs
    assert field(graphs, "contexts=") == "2", graphs
    assert field(graphs, "selected_context=") == "2", graphs
    assert field(graphs, "bracket_union_ms_per_graph=") == "97.285", graphs
    assert field(graphs, "submits_per_graph=") == "40.000", graphs
    print("case=raven2-i1-good verdict=accepted")


def case_raven2_s_mixed_phase():
    """The request-local S slice carries a prefill block beyond the 63
    decode blocks, so the decode selector must recover exactly 63 decode
    blocks, one prefill block, and zero unknown blocks rather than folding
    the mixed phase into the decode aggregate or refusing the slice."""
    s_directory = os.path.join(corpus, "13-S")
    result = run([sys.executable, slice_summarizer,
                 os.path.join(s_directory, "server-log-request.slice"),
                 "--expected-decode-blocks", "63"])
    assert result.returncode == 0, result.stderr
    rows = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
    by_op = {row[1]: row for row in rows if row[0] == "op"}
    assert by_op["MUL_MAT"][2] == "181.000", by_op["MUL_MAT"]
    assert by_op["MUL_MAT_ADD"][2] == "30.000", by_op["MUL_MAT_ADD"]
    tail = {row[0]: row[1] for row in rows if row[0] in
            ("decode_blocks", "prefill_blocks", "unknown_blocks")}
    assert tail == {"decode_blocks": "63", "prefill_blocks": "1", "unknown_blocks": "0"}, tail
    print("case=raven2-s-mixed-phase verdict=accepted")


def case_raven2_sidecar_gap():
    """The 02-P sidecar carries a genuine 42 ms scheduler slice inside a
    record that otherwise loses 0.47% of its window, so the hard-gap
    contract must refuse it as a stall, the coverage contract must accept
    it as a slice, and a lost-fraction bound tighter than what it lost must
    refuse it again on window_lost alone -- the verdict follows whichever
    contract is asked rather than one fixed reading of the record."""
    p_directory = os.path.join(corpus, "02-P")
    p_begin, p_end = read_window(os.path.join(p_directory, "request-window.tsv"))
    base = [sys.executable, sidecar_validator,
            os.path.join(p_directory, "clock-sidecar.tsv"),
            "--sidecar-status", "0", "--period-ms", "10",
            "--period-tolerance", "0.25", "--cost-bound-ns", "1000000",
            "--allow-unavailable", "pp_dpm_fclk_surface_mhz",
            "--window-begin-ns", p_begin, "--window-end-ns", p_end]

    # Hard-gap contract: a stall bound narrower than the measured slice
    # refuses on the gaps line alone.
    result = run(base + ["--max-gap-ns", "20000000"])
    assert result.returncode == 1, (result.returncode, result.stdout)
    lines = result.stdout.rstrip("\n").split("\n")
    gaps_line = next(line for line in lines if line.startswith("gaps="))
    assert gaps_line.startswith("gaps=refused"), gaps_line
    assert "max_ns=42019502" in gaps_line, gaps_line
    assert lines[-1] == "clock_sidecar=refused failures=gaps", lines[-1]

    # Coverage contract: the default stall bound (100 ms) and the default
    # lost-fraction bound (0.02) read the same record as a scheduler slice
    # the window survives rather than a stall.
    result = run(base + ["--max-gap-ns", "100000000", "--max-lost-fraction", "0.02"])
    assert result.returncode == 0, (result.returncode, result.stdout, result.stderr)
    lines = result.stdout.rstrip("\n").split("\n")
    gaps_line = next(line for line in lines if line.startswith("gaps="))
    assert gaps_line.startswith("gaps=accepted"), gaps_line
    assert "max_ns=42019502" in gaps_line, gaps_line
    in_window_line = next(line for line in lines if line.startswith("gaps_in_window="))
    assert "gaps_in_window=0" in in_window_line, in_window_line
    assert "window_lost_fraction=0.0047" in in_window_line, in_window_line
    lost_line = next(line for line in lines if line.startswith("window_lost="))
    assert lost_line.startswith("window_lost=accepted"), lost_line
    assert "window_lost_fraction=0.0047 bound=0.0200" in lost_line, lost_line
    assert lines[-1] == "clock_sidecar=accepted failures=-", lines[-1]

    # Lost-fraction contract: a bound below what the record lost refuses on
    # window_lost alone, so the verdict follows the fraction rather than the
    # widest gap.
    result = run(base + ["--max-gap-ns", "100000000", "--max-lost-fraction", "0.004"])
    assert result.returncode == 1, (result.returncode, result.stdout)
    assert result.stdout.rstrip("\n").split("\n")[-1] == "clock_sidecar=refused failures=window_lost"
    print("case=raven2-sidecar-gap verdict=accepted")


def case_raven2_sidecar_good():
    """The 10-I1 sidecar accepts under the coverage contract with zero
    window loss at the record's own widest gap, proving the reader's
    accept path against a record that never missed a scheduled sample
    inside the request window."""
    result = run([sys.executable, sidecar_validator,
                 os.path.join(i1_directory, "clock-sidecar.tsv"),
                 "--sidecar-status", "0", "--period-ms", "10",
                 "--period-tolerance", "0.25", "--cost-bound-ns", "1000000",
                 "--max-gap-ns", "100000000", "--max-lost-fraction", "0.02",
                 "--allow-unavailable", "pp_dpm_fclk_surface_mhz",
                 "--window-begin-ns", window_begin, "--window-end-ns", window_end])
    assert result.returncode == 0, (result.returncode, result.stdout, result.stderr)
    lines = result.stdout.rstrip("\n").split("\n")
    gaps_line = next(line for line in lines if line.startswith("gaps="))
    assert gaps_line.startswith("gaps=accepted"), gaps_line
    assert "max_ns=21087138" in gaps_line, gaps_line
    in_window_line = next(line for line in lines if line.startswith("gaps_in_window="))
    assert "gaps_in_window=0" in in_window_line, in_window_line
    assert "window_lost_fraction=0.0000" in in_window_line, in_window_line
    assert lines[-1] == "clock_sidecar=accepted failures=-", lines[-1]
    print("case=raven2-sidecar-good verdict=accepted")


def case_raven2_two_context():
    """The I1 census stream carries two Vulkan contexts, the first opening
    and closing with zero graphs; the reader must select the section whose
    graphs the request window intersects and report both contexts=2 and
    selected_context=2. The reader names no flag for choosing a context
    directly, so a request naming a context absent from the stream is a
    window that intersects no section's graphs at all, and that window
    must refuse rather than default to one."""
    result = run_census_summarizer()
    assert result.returncode == 0, result.stderr
    graphs = result.stdout.rstrip("\n").split("\n")[-1].split("\t")
    assert field(graphs, "contexts=") == "2", graphs
    assert field(graphs, "selected_context=") == "2", graphs

    result = run([sys.executable, census_summarizer, census_path,
                 "--window-begin-ns", "1", "--window-end-ns", "1000",
                 "--expected-decode-graphs", "63", "--phase", "decode",
                 "--overlap-threshold", "0.05"])
    assert result.returncode == 1, result.stdout
    assert "intersects the graphs of none of the 2 context sections" in result.stderr, result.stderr
    print("case=raven2-two-context verdict=accepted")


def case_raven2_f32_activation_matmul():
    """Gated DeltaNet's f32 chunk-product matmuls carry ne1 of 2, 8, and 32
    inside the retained decode graphs, values that are not the graph's
    token count; the decode selector must read a decode graph's token
    count from its non-f32 weight matmuls alone, or a chunk-product row
    would flip a real decode graph to prefill or unknown. The corpus proves
    the shape is present by counting the f32 rows directly from the parsed
    census, then proves the reader classifies through it by rerunning the
    summarizer and requiring 63 decode graphs regardless."""
    module = load_kernel_census_module()
    contexts = module.parse(census_path)
    served = next(context for context in contexts if context["graphs"])
    begin_bound, end_bound = int(window_begin), int(window_end)
    decode_serials = []
    for serial, graph in sorted(served["graphs"].items()):
        begin = graph["begin_monotonic_ns"]
        retire = graph["retire_monotonic_ns"]
        if begin >= begin_bound and retire <= end_bound:
            rows = served["dispatches"].get(serial, [])
            if module.graph_tokens(rows) == 1:
                decode_serials.append(serial)
    assert len(decode_serials) == 63, len(decode_serials)

    f32_activation_rows = [
        dispatch for serial in decode_serials
        for dispatch in served["dispatches"].get(serial, [])
        if dispatch["op"] in ("MUL_MAT", "MUL_MAT_ID")
        and dispatch["src0_type"] == "f32" and dispatch["ne"][1] > 1]
    assert len(f32_activation_rows) == 1512, len(f32_activation_rows)
    assert {dispatch["ne"][1] for dispatch in f32_activation_rows} == {2, 8, 32}, \
        sorted({dispatch["ne"][1] for dispatch in f32_activation_rows})

    result = run_census_summarizer()
    assert result.returncode == 0, result.stderr
    graphs = result.stdout.rstrip("\n").split("\n")[-1].split("\t")
    assert graphs[0] == "graphs" and graphs[1] == "decode" and graphs[2] == "63", graphs
    print("case=raven2-f32-activation-matmul verdict=accepted")


case_raven2_i1_good()
case_raven2_s_mixed_phase()
case_raven2_sidecar_gap()
case_raven2_sidecar_good()
case_raven2_two_context()
case_raven2_f32_activation_matmul()

print("census_replay_corpus=accepted")
