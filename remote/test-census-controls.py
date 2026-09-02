#!/usr/bin/env python3
"""The three census campaign helpers over synthetic records.

validate-clock-sidecar.py accepts a record whose header, columns, rows,
footer, period, cost, sensors, and window coverage each hold, and refuses
one record per broken condition. summarize-census-controls.py assigns the
sidecar, compile, and collect bounds to the three registered quadruples
alone, reports each delta on its own, refuses compensation through a mean,
marks an unregistered quadruple unclassified, and keeps S outside the
parser. summarize-perf-logger-slice.py folds a request-local logger slice
into per-op calls per block and refuses a slice short of its blocks.
"""
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
validator = os.path.join(script_directory, "validate-clock-sidecar.py")
controls = os.path.join(script_directory, "summarize-census-controls.py")
slicer = os.path.join(script_directory, "summarize-perf-logger-slice.py")
work = tempfile.mkdtemp(prefix="census-controls-")

COLUMNS = ("monotonic_ns\tpp_dpm_sclk_selected_mhz\tpp_dpm_mclk_surface_mhz"
           "\tpp_dpm_fclk_surface_mhz\tgpu_busy_percent\ttemp1_millidegrees\tsample_cost_ns")


def write(name, text):
    path = os.path.join(work, name)
    with open(path, "w") as handle:
        handle.write(text)
    return path


def sidecar_record(samples=100, period_ns=5_000_000, cost_ns=30_000, start=1_000_000_000,
                   unavailable_rows=(), footer=None, columns=COLUMNS, header_period=None,
                   footers=1):
    lines = [
        f"# clock=CLOCK_MONOTONIC period_ns={header_period or period_ns} drm_device=/fake hwmon=/fake/hwmon0",
        "# interpretation: pp_dpm_sclk_selected_mhz is the selected graphics clock step",
        "# sampler_pid=4242 nice=10 cpu_affinity=1",
        columns,
    ]
    for index in range(samples):
        instant = start + index * period_ns
        fclk = "unavailable" if index in unavailable_rows else "1067"
        lines.append(f"{instant}\t400\t933\t{fclk}\t37\t61000\t{cost_ns}")
    last = start + (samples - 1) * period_ns
    footer_line = footer or (
        f"# samples={samples} achieved_period_ns={period_ns} mean_sample_cost_ns={cost_ns}"
        f" max_sample_cost_ns={cost_ns * 2} samples_with_unavailable_sensor={len(unavailable_rows)}"
        f" first_sample_ns={start} last_sample_ns={last}")
    lines.extend([footer_line] * footers)
    return "\n".join(lines) + "\n"


def validate(text, status=0, window=(1_050_000_000, 1_400_000_000), tolerance="0.25",
             cost_bound="1000000", period_ms="5"):
    path = write("sidecar.tsv", text)
    command = [sys.executable, validator, path, "--sidecar-status", str(status),
               "--period-ms", period_ms, "--period-tolerance", tolerance,
               "--cost-bound-ns", cost_bound]
    if window:
        command += ["--window-begin-ns", str(window[0]), "--window-end-ns", str(window[1])]
    return subprocess.run(command, capture_output=True, text=True)


result = validate(sidecar_record())
assert result.returncode == 0, result.stdout
assert "clock_sidecar=accepted failures=-" in result.stdout, result.stdout
assert "window_coverage=accepted" in result.stdout, result.stdout
print("sidecar_accepted=accepted")

result = validate(sidecar_record(), window=None)
assert result.returncode == 0 and "window_coverage=not_run" in result.stdout, result.stdout


def refused(text, needle, **kwargs):
    result = validate(text, **kwargs)
    assert result.returncode != 0, (needle, result.stdout)
    assert f"{needle}=refused" in result.stdout, (needle, result.stdout)
    assert "clock_sidecar=refused" in result.stdout, result.stdout


refused(sidecar_record(), "sidecar_exit", status=2)
refused(sidecar_record(period_ns=7_000_000, header_period=5_000_000), "achieved_period")
refused(sidecar_record(header_period=4_000_000), "period_declared")
refused(sidecar_record(cost_ns=2_000_000), "sample_cost")
refused(sidecar_record(unavailable_rows=(3,)), "sensors")
refused(sidecar_record(footers=2), "footer_cardinality")
refused(sidecar_record(footers=0), "footer_cardinality")
refused(sidecar_record(columns=COLUMNS.replace("pp_dpm_mclk_surface_mhz", "mclk_mhz")), "columns")
refused(sidecar_record(samples=1), "samples")
refused(sidecar_record(), "window_coverage", window=(900_000_000, 1_400_000_000))
refused(sidecar_record(), "window_coverage", window=(1_050_000_000, 2_000_000_000))
# A footer whose instants disagree with the rows is a footer written by
# something other than the sampler that wrote the rows.
mismatched = sidecar_record().replace("first_sample_ns=1000000000", "first_sample_ns=999")
refused(mismatched, "footer_instants")
# A footer counting unavailable samples the rows do not carry.
miscounted = sidecar_record().replace("samples_with_unavailable_sensor=0", "samples_with_unavailable_sensor=0")
result = validate(miscounted.replace("\t1067\t37", "\tunavailable\t37", 1))
assert result.returncode != 0 and "sensor_rows=refused" in result.stdout, result.stdout
print("sidecar_refusals=accepted")


def arms_ledger(rows):
    header = "slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar\tstatus"
    lines = [header]
    for slot, (arm, rate, status) in enumerate(rows, 1):
        lines.append(f"{slot}\t{arm}\tabc\t64\t6000\t{rate}\t-\ton\t{status}")
    return "\n".join(lines) + "\n"


def summarize(rows, sidecar="0.0065", compile_bound="0.0065", collect="0.02"):
    path = write("arms.tsv", arms_ledger(rows))
    result = subprocess.run([sys.executable, controls, path, "--sidecar-bound", sidecar,
                             "--compile-bound", compile_bound, "--collect-bound", collect],
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    return [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]


table = summarize([
    ("P-nosidecar", "10.000", "completed"), ("P", "9.980", "completed"),
    ("P", "9.960", "completed"), ("P-nosidecar", "10.000", "completed"),
    ("P", "10.000", "completed"), ("I0", "9.950", "completed"),
    ("I0", "9.940", "completed"), ("P", "10.000", "completed"),
    ("I0", "10.000", "completed"), ("I1", "9.850", "completed"),
    ("I1", "9.900", "completed"), ("I0", "10.000", "completed"),
    ("S", "3.000", "completed"),
])
assert table[0][0] == "pair" and len(table) == 4, table
sidecar_pair, compile_pair, collect_pair = table[1], table[2], table[3]
assert sidecar_pair[1] == "sidecar" and sidecar_pair[6] == "-0.0020" and sidecar_pair[9] == "-0.0040"
assert sidecar_pair[10] == "0.0065" and sidecar_pair[11] == "accepted", sidecar_pair
assert compile_pair[1] == "compile" and compile_pair[6] == "-0.0050" and compile_pair[9] == "-0.0060"
assert compile_pair[11] == "accepted", compile_pair
assert collect_pair[1] == "collect" and collect_pair[6] == "-0.0150" and collect_pair[9] == "-0.0100"
assert collect_pair[10] == "0.02" and collect_pair[11] == "accepted", collect_pair
print("controls_accepted=accepted")

# One delta outside the bound refutes the pair even where the other delta
# is inside it and their mean would pass.
table = summarize([
    ("P", "10.000", "completed"), ("I0", "9.900", "completed"),
    ("I0", "10.000", "completed"), ("P", "10.000", "completed"),
])
assert table[1][6] == "-0.0100" and table[1][9] == "+0.0000" and table[1][11] == "refuted", table[1]
# An incomplete arm makes the pair incomplete rather than a rate.
table = summarize([
    ("I0", "10.000", "completed"), ("I1", "-", "failed"),
    ("I1", "9.900", "completed"), ("I0", "10.000", "completed"),
])
assert table[1][1] == "collect" and table[1][11] == "incomplete", table[1]
# An unregistered quadruple is printed unclassified with no bound.
table = summarize([
    ("P", "10.000", "completed"), ("I1", "9.900", "completed"),
    ("I1", "9.900", "completed"), ("P", "10.000", "completed"),
])
assert table[1][1] == "unregistered" and table[1][10] == "-" and table[1][11] == "unclassified", table[1]
# S stays outside the parser: I1 S S I1 forms no pair, and an S between two
# registered quadruples does not disturb them.
table = summarize([
    ("I1", "9.900", "completed"), ("S", "3.000", "completed"),
    ("S", "3.000", "completed"), ("I1", "9.900", "completed"),
])
assert len(table) == 1, table
table = summarize([
    ("P", "10.000", "completed"), ("I0", "9.950", "completed"),
    ("S", "3.000", "completed"),
    ("I0", "9.940", "completed"), ("P", "10.000", "completed"),
])
assert len(table) == 2 and table[1][1] == "compile" and table[1][11] == "accepted", table
print("controls_shapes=accepted")

slice_text = "\n".join([
    "srv  log_server_r: request: POST /v1/chat/completions",
    "----------------",
    "Vulkan Timings:",
    "MUL_MAT_VEC q4_K m=2048 n=1 k=2048: 24 x 120.5 us = 2892.0 us (12.3 GFLOPS/s)",
    "RMS_NORM(2048,1,1,1), MUL: 48 x 4.0 us = 192.0 us",
    "ROPE: 24 x 3.0 us = 72.0 us",
    "Total time: 3156.0 us.",
    "----------------",
    "Vulkan Timings:",
    "MUL_MAT_VEC q4_K m=2048 n=1 k=2048: 24 x 121.5 us = 2916.0 us (12.2 GFLOPS/s)",
    "RMS_NORM(2048,1,1,1), MUL: 48 x 4.0 us = 192.0 us",
    "ROPE: 24 x 3.0 us = 72.0 us",
    "Total time: 3180.0 us.",
    "",
])
slice_path = write("slice.log", slice_text)
result = subprocess.run([sys.executable, slicer, slice_path, "--expected-min-blocks", "2"],
                        capture_output=True, text=True)
assert result.returncode == 0, result.stderr
rows = [line.split("\t") for line in result.stdout.rstrip("\n").split("\n")]
assert rows[0][0] == "op" and rows[-1][0] == "blocks" and rows[-1][1] == "2", rows
inventory = {row[1]: row for row in rows[1:-1]}
assert inventory["MUL_MAT"][2] == "24.000" and inventory["MUL_MAT"][3] == "5808.0", inventory
assert inventory["RMS_NORM"][2] == "48.000" and inventory["MUL"][2] == "48.000", inventory
assert inventory["ROPE"][2] == "24.000", inventory
result = subprocess.run([sys.executable, slicer, slice_path, "--expected-min-blocks", "3"],
                        capture_output=True, text=True)
assert result.returncode != 0 and "holds 2 blocks" in result.stderr, result.stderr
print("perf_logger_slice=accepted")

for name in os.listdir(work):
    os.unlink(os.path.join(work, name))
os.rmdir(work)
print("census_controls=accepted")
