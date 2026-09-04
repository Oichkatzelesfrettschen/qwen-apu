#!/usr/bin/env python3
"""Drive read-package-energy.py against a fixture powercap tree.

The real counters are mode 0400 and rise on their own, so the fixture writes
both domains as ordinary files the test controls: the reader's arithmetic, its
wrap handling, its bracket selection, and every refusal it names are provable
on the workstation with no privilege and no device.
"""
import os
import shutil
import subprocess
import sys
import tempfile

READER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "read-package-energy.py")
WRAP_MAX_UJ = 65532610987


def write_file(path, text):
    with open(path, "w") as handle:
        handle.write(text)


def create_powercap_fixture(base_directory, package_uj=1000000, core_uj=400000,
                            package_name="package-0", core_name="core"):
    root = os.path.join(base_directory, "powercap")
    package_directory = os.path.join(root, "intel-rapl:0")
    core_directory = os.path.join(root, "intel-rapl:0:0")
    os.makedirs(package_directory, exist_ok=True)
    os.makedirs(core_directory, exist_ok=True)
    write_file(os.path.join(package_directory, "name"), package_name + "\n")
    write_file(os.path.join(core_directory, "name"), core_name + "\n")
    write_file(os.path.join(package_directory, "energy_uj"), f"{package_uj}\n")
    write_file(os.path.join(core_directory, "energy_uj"), f"{core_uj}\n")
    write_file(
        os.path.join(package_directory, "max_energy_range_uj"), f"{WRAP_MAX_UJ}\n"
    )
    write_file(
        os.path.join(core_directory, "max_energy_range_uj"), f"{WRAP_MAX_UJ}\n"
    )
    return root


def run_reader(arguments):
    return subprocess.run(
        [sys.executable, READER] + arguments,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )


def parse_rows(text):
    rows = {}
    for line in text.splitlines():
        fields = line.split("\t")
        if len(fields) == 2:
            rows[fields[0]] = fields[1]
    return rows


def write_sample_record(path, samples, period_ns=50000000,
                        schema="package-energy-sample-v1"):
    with open(path, "w") as handle:
        handle.write("key\tvalue\n")
        handle.write(f"schema\t{schema}\n")
        handle.write("clock\tCLOCK_MONOTONIC\n")
        handle.write(f"period_ns\t{period_ns}\n")
        handle.write(f"package_wrap_uj\t{WRAP_MAX_UJ + 1}\n")
        handle.write(f"core_wrap_uj\t{WRAP_MAX_UJ + 1}\n")
        handle.write("sampler_pid\t1\n")
        handle.write("monotonic_ns\tpackage_uj\tcore_uj\tsample_cost_ns\n")
        for monotonic_ns, package_uj, core_uj in samples:
            handle.write(f"{monotonic_ns}\t{package_uj}\t{core_uj}\t1000\n")
        handle.write(f"footer_sample_count\t{len(samples)}\n")
        handle.write("footer_unreadable_count\t0\n")
        handle.write(f"footer_achieved_period_ns\t{period_ns}\n")


def test_read_reports_both_domains():
    directory = tempfile.mkdtemp()
    try:
        root = create_powercap_fixture(directory)
        result = run_reader(["read", "--powercap-root", root])
        assert result.returncode == 0, result.stderr
        rows = parse_rows(result.stdout)
        assert rows["schema"] == "package-energy-read-v1"
        assert rows["package_uj"] == "1000000"
        assert rows["core_uj"] == "400000"
        assert rows["package_wrap_uj"] == str(WRAP_MAX_UJ + 1)
        assert int(rows["monotonic_ns"]) > 0
        print("test_read_reports_both_domains: PASSED")
    finally:
        shutil.rmtree(directory)


def test_read_refuses_an_unexpected_domain_name():
    directory = tempfile.mkdtemp()
    try:
        root = create_powercap_fixture(directory, core_name="dram")
        result = run_reader(["read", "--powercap-root", root])
        assert result.returncode == 2, result.stdout
        assert "domain_name_unexpected" in result.stderr, result.stderr
        print("test_read_refuses_an_unexpected_domain_name: PASSED")
    finally:
        shutil.rmtree(directory)


def test_read_refuses_an_absent_domain():
    directory = tempfile.mkdtemp()
    try:
        root = create_powercap_fixture(directory)
        shutil.rmtree(os.path.join(root, "intel-rapl:0:0"))
        result = run_reader(["read", "--powercap-root", root])
        assert result.returncode == 2, result.stdout
        assert "domain_absent" in result.stderr, result.stderr
        print("test_read_refuses_an_absent_domain: PASSED")
    finally:
        shutil.rmtree(directory)


def test_sample_writes_a_bounded_record():
    directory = tempfile.mkdtemp()
    try:
        root = create_powercap_fixture(directory)
        output = os.path.join(directory, "energy.tsv")
        result = run_reader(
            [
                "sample",
                output,
                "--period-ms",
                "10",
                "--duration-s",
                "0.2",
                "--powercap-root",
                root,
            ]
        )
        assert result.returncode == 0, result.stderr
        with open(output) as handle:
            text = handle.read()
        rows = parse_rows(text)
        assert rows["schema"] == "package-energy-sample-v1"
        assert rows["period_ns"] == "10000000"
        sample_count = int(rows["footer_sample_count"])
        assert 5 <= sample_count <= 40, sample_count
        assert rows["footer_unreadable_count"] == "0"
        print("test_sample_writes_a_bounded_record: PASSED")
    finally:
        shutil.rmtree(directory)


def test_sample_refuses_a_nonpositive_period():
    directory = tempfile.mkdtemp()
    try:
        root = create_powercap_fixture(directory)
        result = run_reader(
            [
                "sample",
                os.path.join(directory, "energy.tsv"),
                "--period-ms",
                "0",
                "--powercap-root",
                root,
            ]
        )
        assert result.returncode == 2, result.stdout
        assert "period_not_positive" in result.stderr, result.stderr
        print("test_sample_refuses_a_nonpositive_period: PASSED")
    finally:
        shutil.rmtree(directory)


def test_window_differences_both_brackets():
    directory = tempfile.mkdtemp()
    try:
        record = os.path.join(directory, "energy.tsv")
        # Ten samples 100 ms apart rising 600000 uJ per sample: 6 W package.
        samples = [
            (1000000000 + index * 100000000, 1000000 + index * 600000,
             400000 + index * 200000)
            for index in range(10)
        ]
        write_sample_record(record, samples, period_ns=100000000)
        # The window opens between samples 2 and 3 and closes between 6 and 7.
        result = run_reader(
            [
                "window",
                record,
                "--window-begin-ns",
                str(1000000000 + 250000000),
                "--window-end-ns",
                str(1000000000 + 650000000),
            ]
        )
        assert result.returncode == 0, result.stderr
        rows = parse_rows(result.stdout)
        assert rows["window_coverage"] == "bracketed"
        # Inner: samples 3 through 6, 0.3 s and 1.8 J package.
        assert rows["inner_interval_s"] == "0.300000", rows["inner_interval_s"]
        assert rows["inner_package_joules"] == "1.800000", rows["inner_package_joules"]
        assert abs(float(rows["inner_package_watts"]) - 6.0) < 1e-6
        assert abs(float(rows["inner_core_watts"]) - 2.0) < 1e-6
        # Outer: samples 2 through 7, 0.5 s and 3.0 J package.
        assert rows["outer_interval_s"] == "0.500000", rows["outer_interval_s"]
        assert abs(float(rows["outer_package_watts"]) - 6.0) < 1e-6
        print("test_window_differences_both_brackets: PASSED")
    finally:
        shutil.rmtree(directory)


def test_window_carries_a_counter_wrap():
    directory = tempfile.mkdtemp()
    try:
        record = os.path.join(directory, "energy.tsv")
        # Both counters run modulo max_energy_range_uj + 1 and reach exactly
        # that modulus on the third sample, so the third interval is the wrap.
        samples = [
            (1000000000, WRAP_MAX_UJ - 99999, WRAP_MAX_UJ - 49999),
            (1100000000, WRAP_MAX_UJ - 49999, WRAP_MAX_UJ - 24999),
            (1200000000, 0, 0),
            (1300000000, 50000, 25000),
        ]
        write_sample_record(record, samples, period_ns=100000000)
        result = run_reader(
            [
                "window",
                record,
                "--window-begin-ns",
                "1000000000",
                "--window-end-ns",
                "1300000000",
            ]
        )
        assert result.returncode == 0, result.stderr
        rows = parse_rows(result.stdout)
        # Three intervals of 50000 uJ each, one of them across the wrap.
        assert rows["inner_package_joules"] == "0.150000", rows["inner_package_joules"]
        assert rows["inner_core_joules"] == "0.075000", rows["inner_core_joules"]
        print("test_window_carries_a_counter_wrap: PASSED")
    finally:
        shutil.rmtree(directory)


def test_window_refuses_a_record_that_ends_early():
    directory = tempfile.mkdtemp()
    try:
        record = os.path.join(directory, "energy.tsv")
        samples = [
            (1000000000, 1000000, 400000),
            (1100000000, 1600000, 600000),
        ]
        write_sample_record(record, samples, period_ns=100000000)
        result = run_reader(
            [
                "window",
                record,
                "--window-begin-ns",
                "1000000000",
                "--window-end-ns",
                "9000000000",
            ]
        )
        assert result.returncode == 3, result.stdout
        rows = parse_rows(result.stdout)
        assert rows["window_coverage"] == "unreached"
        assert rows["outer_bracket"] == "unreached"
        print("test_window_refuses_a_record_that_ends_early: PASSED")
    finally:
        shutil.rmtree(directory)


def test_window_refuses_a_foreign_schema():
    directory = tempfile.mkdtemp()
    try:
        record = os.path.join(directory, "energy.tsv")
        samples = [(1000000000, 1000000, 400000), (1100000000, 1600000, 600000)]
        write_sample_record(record, samples, schema="package-energy-sample-v0")
        result = run_reader(
            [
                "window",
                record,
                "--window-begin-ns",
                "1000000000",
                "--window-end-ns",
                "1100000000",
            ]
        )
        assert result.returncode == 2, result.stdout
        assert "sample_schema_unknown" in result.stderr, result.stderr
        print("test_window_refuses_a_foreign_schema: PASSED")
    finally:
        shutil.rmtree(directory)


def test_window_refuses_an_inverted_window():
    directory = tempfile.mkdtemp()
    try:
        record = os.path.join(directory, "energy.tsv")
        samples = [(1000000000, 1000000, 400000), (1100000000, 1600000, 600000)]
        write_sample_record(record, samples)
        result = run_reader(
            [
                "window",
                record,
                "--window-begin-ns",
                "1100000000",
                "--window-end-ns",
                "1000000000",
            ]
        )
        assert result.returncode == 2, result.stdout
        assert "window_not_positive" in result.stderr, result.stderr
        print("test_window_refuses_an_inverted_window: PASSED")
    finally:
        shutil.rmtree(directory)


if __name__ == "__main__":
    test_read_reports_both_domains()
    test_read_refuses_an_unexpected_domain_name()
    test_read_refuses_an_absent_domain()
    test_sample_writes_a_bounded_record()
    test_sample_refuses_a_nonpositive_period()
    test_window_differences_both_brackets()
    test_window_carries_a_counter_wrap()
    test_window_refuses_a_record_that_ends_early()
    test_window_refuses_a_foreign_schema()
    test_window_refuses_an_inverted_window()
    print("read_package_energy=accepted")
