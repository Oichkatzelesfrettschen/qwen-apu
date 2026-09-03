#!/usr/bin/env python3
"""Test sample-clock-sidecar.py with fake sysfs files."""
import os
import subprocess
import sys
import tempfile
import shutil
import signal
import time


def create_fake_sysfs(base_dir):
    """Create a fake sysfs tree with amdgpu clock files."""
    # Create DRM device directory
    drm_device = os.path.join(base_dir, "drm_device")
    os.makedirs(drm_device, exist_ok=True)

    # Create pp_dpm_sclk with selected step at 400 MHz
    with open(os.path.join(drm_device, "pp_dpm_sclk"), "w") as f:
        f.write("0: 200Mhz\n")
        f.write("1: 400Mhz *\n")
        f.write("2: 800Mhz\n")

    # Create pp_dpm_mclk with selected step at 933 MHz
    with open(os.path.join(drm_device, "pp_dpm_mclk"), "w") as f:
        f.write("0: 800Mhz\n")
        f.write("1: 933Mhz *\n")
        f.write("2: 1067Mhz\n")

    # Create pp_dpm_fclk with selected step at 1067 MHz
    with open(os.path.join(drm_device, "pp_dpm_fclk"), "w") as f:
        f.write("0: 800Mhz\n")
        f.write("1: 933Mhz\n")
        f.write("2: 1067Mhz *\n")

    # Create gpu_busy_percent
    with open(os.path.join(drm_device, "gpu_busy_percent"), "w") as f:
        f.write("37\n")

    # Create hwmon root with amdgpu device
    hwmon_root = os.path.join(base_dir, "hwmon")
    hwmon_dev = os.path.join(hwmon_root, "hwmon0")
    os.makedirs(hwmon_dev, exist_ok=True)

    with open(os.path.join(hwmon_dev, "name"), "w") as f:
        f.write("amdgpu\n")

    with open(os.path.join(hwmon_dev, "temp1_input"), "w") as f:
        f.write("61000\n")

    return drm_device, hwmon_root


def test_basic():
    """Test basic functionality with all sensors available."""
    tmpdir = tempfile.mkdtemp()
    try:
        drm_device, hwmon_root = create_fake_sysfs(tmpdir)
        output_file = os.path.join(tmpdir, "output.tsv")

        # Start the sampler in a subprocess
        proc = subprocess.Popen(
            [
                sys.executable,
                "remote/sample-clock-sidecar.py",
                output_file,
                "--period-ms", "2",
                "--drm-device", drm_device,
                "--hwmon-root", hwmon_root,
                "--nice", "0",
                "--cpu", "0",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        # Run for about 0.3 seconds
        time.sleep(0.3)
        proc.send_signal(signal.SIGTERM)

        try:
            stdout, stderr = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            stdout, stderr = proc.communicate()

        # Check exit status
        assert proc.returncode == 0, f"Exit code {proc.returncode}; stderr: {stderr.decode()}"

        # Read and parse the output file
        with open(output_file) as f:
            lines = f.readlines()

        # Find where data rows start
        header_line_idx = None
        for i, line in enumerate(lines):
            if line.startswith("monotonic_ns"):
                header_line_idx = i
                break

        assert header_line_idx is not None, "Column header not found"

        # Check column header
        header = lines[header_line_idx].strip()
        expected_header = "monotonic_ns\tpp_dpm_sclk_selected_mhz\tpp_dpm_mclk_surface_mhz\tpp_dpm_fclk_surface_mhz\tgpu_busy_percent\ttemp1_millidegrees\tsample_cost_ns"
        assert header == expected_header, f"Header mismatch:\nExpected: {expected_header}\nGot: {header}"

        # Check header comment lines
        comment_lines = [line for line in lines[:header_line_idx] if line.startswith("#")]
        assert len(comment_lines) >= 3, f"Expected at least 3 comment lines, got {len(comment_lines)}"

        # Check first comment line format
        assert "clock=CLOCK_MONOTONIC" in comment_lines[0], f"First comment missing clock info: {comment_lines[0]}"
        assert "period_ns=" in comment_lines[0], f"First comment missing period_ns: {comment_lines[0]}"
        assert "drm_device=" in comment_lines[0], f"First comment missing drm_device: {comment_lines[0]}"

        # Check second comment line (interpretation)
        assert "interpretation:" in comment_lines[1], f"Second comment missing interpretation: {comment_lines[1]}"
        assert "pp_dpm_mclk_surface_mhz" in comment_lines[1]
        assert "pp_dpm_fclk_surface_mhz" in comment_lines[1]

        # Check third comment line (sampler_pid, nice, cpu_affinity)
        assert "sampler_pid=" in comment_lines[2], f"Third comment missing sampler_pid: {comment_lines[2]}"
        assert "nice=" in comment_lines[2]
        assert "cpu_affinity=" in comment_lines[2]

        # Check data rows
        data_lines = lines[header_line_idx + 1:]
        # Separate footer from data
        footer_line = None
        data_rows = []
        for line in data_lines:
            if line.startswith("#"):
                footer_line = line
            else:
                data_rows.append(line.strip())

        assert footer_line is not None, "Footer line not found"
        assert len(data_rows) > 20, f"Expected > 20 data rows, got {len(data_rows)}"

        # Check each data row
        for row in data_rows:
            if not row:
                continue
            fields = row.split("\t")
            assert len(fields) == 7, f"Row has {len(fields)} fields, expected 7: {row}"

            # Fields 0: monotonic_ns
            assert fields[0].isdigit(), f"monotonic_ns not numeric: {fields[0]}"

            # Fields 1-5: should be numeric or "unavailable"
            for i in range(1, 6):
                if fields[i] != "unavailable":
                    assert fields[i].isdigit(), f"Field {i} not numeric: {fields[i]}"

            # Check specific values (sclk=400, mclk=933, fclk=1067, busy=37, temp=61000)
            if fields[1] != "unavailable":
                assert fields[1] == "400", f"sclk should be 400, got {fields[1]}"
            if fields[2] != "unavailable":
                assert fields[2] == "933", f"mclk should be 933, got {fields[2]}"
            if fields[3] != "unavailable":
                assert fields[3] == "1067", f"fclk should be 1067, got {fields[3]}"
            if fields[4] != "unavailable":
                assert fields[4] == "37", f"gpu_busy should be 37, got {fields[4]}"
            if fields[5] != "unavailable":
                assert fields[5] == "61000", f"temp should be 61000, got {fields[5]}"

            # Field 6: sample_cost_ns
            assert fields[6].isdigit(), f"sample_cost_ns not numeric: {fields[6]}"

        # Check footer format
        footer = footer_line.strip()
        assert footer.startswith("#"), "Footer should start with #"
        assert "samples=" in footer, f"Footer missing samples: {footer}"
        assert "achieved_period_ns=" in footer, f"Footer missing achieved_period_ns: {footer}"
        assert "mean_sample_cost_ns=" in footer, f"Footer missing mean_sample_cost_ns: {footer}"
        assert "max_sample_cost_ns=" in footer, f"Footer missing max_sample_cost_ns: {footer}"
        assert "samples_with_unavailable_sensor=" in footer, f"Footer missing samples_with_unavailable_sensor: {footer}"
        assert "first_sample_ns=" in footer, f"Footer missing first_sample_ns: {footer}"
        assert "last_sample_ns=" in footer, f"Footer missing last_sample_ns: {footer}"

        # Parse footer values
        import re
        match = re.search(r"samples=(\d+)", footer)
        assert match, f"Could not parse samples: {footer}"
        samples = int(match.group(1))
        assert samples > 20, f"samples should be > 20, got {samples}"

        match = re.search(r"achieved_period_ns=(\d+)", footer)
        assert match, f"Could not parse achieved_period_ns: {footer}"
        achieved_period = int(match.group(1))
        # Expected around 2_000_000 ns (2 ms), but allow some variance
        assert 1_000_000 <= achieved_period <= 4_000_000, f"achieved_period_ns {achieved_period} out of range"

        match = re.search(r"samples_with_unavailable_sensor=(\d+)", footer)
        assert match, f"Could not parse samples_with_unavailable_sensor: {footer}"
        unavailable_samples = int(match.group(1))
        assert unavailable_samples == 0, f"Expected no unavailable sensors, got {unavailable_samples}"

        # Check first and last sample timestamps
        match = re.search(r"first_sample_ns=(\d+)", footer)
        assert match, f"Could not parse first_sample_ns: {footer}"
        first_ns = int(match.group(1))

        match = re.search(r"last_sample_ns=(\d+)", footer)
        assert match, f"Could not parse last_sample_ns: {footer}"
        last_ns = int(match.group(1))

        # first_ns should match the first data row
        first_row_ns = int(data_rows[0].split("\t")[0])
        assert first_ns == first_row_ns, f"first_sample_ns {first_ns} != first row {first_row_ns}"

        # last_ns should match the last data row
        last_row_ns = int(data_rows[-1].split("\t")[0])
        assert last_ns == last_row_ns, f"last_sample_ns {last_ns} != last row {last_row_ns}"

        print("test_basic: PASSED")

    finally:
        shutil.rmtree(tmpdir)


def test_missing_fclk():
    """Test with pp_dpm_fclk file missing (sensor unavailable)."""
    tmpdir = tempfile.mkdtemp()
    try:
        drm_device, hwmon_root = create_fake_sysfs(tmpdir)
        # Remove fclk file to make it unavailable
        os.remove(os.path.join(drm_device, "pp_dpm_fclk"))

        output_file = os.path.join(tmpdir, "output.tsv")

        proc = subprocess.Popen(
            [
                sys.executable,
                "remote/sample-clock-sidecar.py",
                output_file,
                "--period-ms", "2",
                "--drm-device", drm_device,
                "--hwmon-root", hwmon_root,
                "--nice", "0",
                "--cpu", "0",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        time.sleep(0.2)
        proc.send_signal(signal.SIGTERM)

        try:
            stdout, stderr = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            stdout, stderr = proc.communicate()

        assert proc.returncode == 0, f"Exit code {proc.returncode}; stderr: {stderr.decode()}"

        with open(output_file) as f:
            lines = f.readlines()

        # Find data rows
        header_line_idx = None
        for i, line in enumerate(lines):
            if line.startswith("monotonic_ns"):
                header_line_idx = i
                break

        data_lines = lines[header_line_idx + 1:]
        footer_line = None
        data_rows = []
        for line in data_lines:
            if line.startswith("#"):
                footer_line = line
            else:
                data_rows.append(line.strip())

        # Check that fclk column (column 3) is always "unavailable"
        for row in data_rows:
            if not row:
                continue
            fields = row.split("\t")
            assert fields[3] == "unavailable", f"fclk should be unavailable, got {fields[3]}"

        # Check footer
        import re
        match = re.search(r"samples=(\d+)", footer_line)
        assert match
        samples = int(match.group(1))

        match = re.search(r"samples_with_unavailable_sensor=(\d+)", footer_line)
        assert match
        unavailable_samples = int(match.group(1))
        assert unavailable_samples == samples, f"All {samples} samples should have unavailable sensor, got {unavailable_samples}"

        print("test_missing_fclk: PASSED")

    finally:
        shutil.rmtree(tmpdir)


def test_invalid_period():
    """Test that --period-ms 0 exits with code 2."""
    tmpdir = tempfile.mkdtemp()
    try:
        drm_device, hwmon_root = create_fake_sysfs(tmpdir)
        output_file = os.path.join(tmpdir, "output.tsv")

        proc = subprocess.Popen(
            [
                sys.executable,
                "remote/sample-clock-sidecar.py",
                output_file,
                "--period-ms", "0",
                "--drm-device", drm_device,
                "--hwmon-root", hwmon_root,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        stdout, stderr = proc.communicate()
        assert proc.returncode == 2, f"Expected exit code 2, got {proc.returncode}"
        assert "period" in stderr.decode().lower(), f"stderr should mention period: {stderr.decode()}"

        print("test_invalid_period: PASSED")

    finally:
        shutil.rmtree(tmpdir)


def test_nonexistent_output_dir():
    """Test that nonexistent output directory exits with code 2."""
    tmpdir = tempfile.mkdtemp()
    try:
        drm_device, hwmon_root = create_fake_sysfs(tmpdir)
        output_file = os.path.join(tmpdir, "nonexistent", "output.tsv")

        proc = subprocess.Popen(
            [
                sys.executable,
                "remote/sample-clock-sidecar.py",
                output_file,
                "--period-ms", "5",
                "--drm-device", drm_device,
                "--hwmon-root", hwmon_root,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        stdout, stderr = proc.communicate()
        assert proc.returncode == 2, f"Expected exit code 2, got {proc.returncode}"

        print("test_nonexistent_output_dir: PASSED")

    finally:
        shutil.rmtree(tmpdir)


if __name__ == "__main__":
    test_basic()
    test_missing_fclk()
    test_invalid_period()
    test_nonexistent_output_dir()
    print("sample_clock_sidecar=accepted")
