#!/usr/bin/env python3
"""Test the strictness rules validate-clock-sidecar.py added beside its
existing structural conditions: declared sampler priority and affinity held
to what a launcher expected, a `# sample_rates:` header's cadence claims held
to completeness and to arithmetic, a marker sampler's own freshness stamps
held to the cadence it declared, a recognized sampler_format, a request
window supplied whole rather than in half, and positive integer bounds. Each
function below fixes one new rule and prints `case=<name> verdict=accepted`
on success; test-census-controls.py continues to cover the conditions this
file does not touch.

usage: test-validate-clock-sidecar.py
Exits 0 and prints `validate_clock_sidecar=accepted` on agreement.
"""
import os
import subprocess
import sys
import tempfile

script_directory = os.path.dirname(os.path.abspath(__file__))
validator = os.path.join(script_directory, "validate-clock-sidecar.py")
work = tempfile.mkdtemp(prefix="validate-clock-sidecar-")

COLUMNS = ("monotonic_ns\tpp_dpm_sclk_selected_mhz\tpp_dpm_mclk_surface_mhz"
           "\tpp_dpm_fclk_surface_mhz\tgpu_busy_percent\ttemp1_millidegrees\tsample_cost_ns")


def write(name, text):
    path = os.path.join(work, name)
    with open(path, "w") as handle:
        handle.write(text)
    return path


def sidecar_record(samples=40, period_ns=5_000_000, start=1_000_000_000,
                   sample_rates=None, sampler_format=None, nice=10,
                   cpu_affinity="1", dpm_read_stride=None):
    """One narrow (7-column) record, optionally carrying a `# sample_rates:`
    line, a `sampler_format` header field, and `# dpm_read=` markers every
    dpm_read_stride-th row.

    sample_rates is a dict of the cadence keys to declare, written verbatim
    so a malformed-value fixture can pass a non-integer or non-multiple
    string directly.
    """
    lines = [
        f"# clock=CLOCK_MONOTONIC period_ns={period_ns} drm_device=/fake hwmon=/fake/hwmon0",
    ]
    if sample_rates is not None:
        declared = " ".join(f"{key}={value}" for key, value in sample_rates.items())
        lines.append(f"# sample_rates: {declared}")
    lines.append("# interpretation: pp_dpm_sclk_selected_mhz is the selected graphics clock step")
    identity = f"# sampler_pid=4242 nice={nice} cpu_affinity={cpu_affinity}"
    if sampler_format is not None:
        identity += f" sampler_format={sampler_format}"
    lines.append(identity)
    lines.append(COLUMNS)
    for index in range(samples):
        instant = start + index * period_ns
        if dpm_read_stride is not None and index % dpm_read_stride == 0:
            lines.append(f"# dpm_read={instant}")
        lines.append(f"{instant}\t400\t933\t1067\t37\t61000\t30000")
    last = start + (samples - 1) * period_ns
    mean_period = (last - start) // (samples - 1) if samples > 1 else 0
    lines.append(f"# samples={samples} achieved_period_ns={mean_period}"
                 f" mean_sample_cost_ns=30000 max_sample_cost_ns=30000"
                 f" samples_with_unavailable_sensor=0"
                 f" first_sample_ns={start} last_sample_ns={last}")
    return "\n".join(lines) + "\n", start, last


def run(argv):
    return subprocess.run(argv, capture_output=True, text=True)


def validate(text, period_ns=5_000_000, window=None, extra=()):
    path = write("sidecar.tsv", text)
    command = [sys.executable, validator, path, "--sidecar-status", "0",
              "--period-ms", str(period_ns / 1_000_000),
              "--period-tolerance", "0.25", "--cost-bound-ns", "1000000",
              "--max-gap-ns", "50000000", "--max-lost-fraction", "0.02"]
    if window:
        command += ["--window-begin-ns", str(window[0]), "--window-end-ns", str(window[1])]
    command += list(extra)
    return run(command)


def refused(text, needle, **kwargs):
    result = validate(text, **kwargs)
    assert result.returncode != 0, (needle, result.stdout)
    assert f"{needle}=refused" in result.stdout, (needle, result.stdout)
    return result


def accepted_line(text, needle, **kwargs):
    result = validate(text, **kwargs)
    assert f"{needle}=accepted" in result.stdout, (needle, result.stdout, result.stderr)
    return result


# sampler_nice / sampler_affinity: presence alone no longer satisfies the
# question a launcher asks -- the header's own reported niceness and CPU set
# must equal what the launcher configured.
def case_sampler_declared_identity():
    record, start, last = sidecar_record(nice=19, cpu_affinity="0,1")

    result = validate(record, extra=["--expected-nice", "19"])
    assert "sampler_nice=accepted nice=19 expected=19" in result.stdout, result.stdout
    assert "sampler_affinity=not_run" in result.stdout, result.stdout

    result = validate(record, extra=["--expected-nice", "0"])
    assert "sampler_nice=refused nice=19 expected=0" in result.stdout, result.stdout
    assert "clock_sidecar=refused" in result.stdout, result.stdout
    assert "failures=sampler_nice" in result.stdout, result.stdout

    # The affinity comparison reads a set, so a caller's list in another
    # order or with a stray space still holds against the header's own.
    result = validate(record, extra=["--expected-cpu-affinity", "1, 0"])
    assert "sampler_affinity=accepted" in result.stdout, result.stdout

    result = validate(record, extra=["--expected-cpu-affinity", "0"])
    assert "sampler_affinity=refused cpu_affinity=0,1 expected=0" in result.stdout, result.stdout

    result = validate(record)
    assert "sampler_nice=not_run no --expected-nice supplied" in result.stdout, result.stdout
    assert "sampler_affinity=not_run no --expected-cpu-affinity supplied" in result.stdout, result.stdout
    assert result.returncode == 0, result.stdout
    print("case=sampler_declared_identity verdict=accepted")


# sampler_format: a recognized value passes silently, an unrecognized one
# refuses the record rather than reading it under today's inference rules,
# and an absent key falls back to that inference (not_run).
def case_sampler_format():
    record, _, _ = sidecar_record(sampler_format="native-fresh-v1")
    result = validate(record)
    assert "sampler_format=accepted sampler_format=native-fresh-v1" in result.stdout, result.stdout
    assert result.returncode == 0, result.stdout

    record, _, _ = sidecar_record(sampler_format="future-shape-v9")
    result = validate(record)
    assert "sampler_format=refused sampler_format=future-shape-v9" in result.stdout, result.stdout
    assert "clock_sidecar=refused" in result.stdout, result.stdout
    assert "failures=sampler_format" in result.stdout, result.stdout

    record, _, _ = sidecar_record()
    result = validate(record)
    assert "sampler_format=not_run no sampler_format header key" in result.stdout, result.stdout
    print("case=sampler_format verdict=accepted")


# channel_cadence / cadence_values: a `# sample_rates:` header makes two
# checkable claims -- that it names the two channels a row column depends on,
# and that each cadence it names is a positive multiple of the requested
# period, with gpu_busy_percent_period_ns equal to it exactly.
def case_channel_cadence_and_values():
    # No sample_rates line: both conditions print not_run rather than
    # refusing a python-sampler record for a declaration it never made.
    record, _, _ = sidecar_record()
    result = validate(record)
    assert "channel_cadence=not_run no sample_rates header" in result.stdout, result.stdout
    assert "cadence_values=not_run no sample_rates header" in result.stdout, result.stdout

    # Complete and arithmetically sound: both accept.
    record, _, _ = sidecar_record(sample_rates={
        "gpu_busy_percent_period_ns": 5_000_000, "pp_dpm_period_ns": 50_000_000,
        "temp1_input_period_ns": 50_000_000})
    result = validate(record)
    assert "channel_cadence=accepted missing=-" in result.stdout, result.stdout
    assert "cadence_values=accepted -" in result.stdout, result.stdout
    assert result.returncode == 0, result.stdout

    # A header naming pp_dpm_period_ns alone leaves gpu_busy_percent_period_ns
    # missing, which is one of the two channels every row column depends on.
    record, _, _ = sidecar_record(sample_rates={"pp_dpm_period_ns": 50_000_000})
    refused(record, "channel_cadence")

    # A non-integer cadence, a non-positive one, one that does not divide the
    # requested period evenly, and a busy cadence that disagrees with the
    # requested period itself all fail cadence_values by name.
    for bad_rates, reason_fragment in (
            ({"gpu_busy_percent_period_ns": 5_000_000, "pp_dpm_period_ns": "abc"},
             "pp_dpm_period_ns=abc is not an integer"),
            ({"gpu_busy_percent_period_ns": 5_000_000, "pp_dpm_period_ns": 0},
             "pp_dpm_period_ns=0 is not positive"),
            ({"gpu_busy_percent_period_ns": 5_000_000, "pp_dpm_period_ns": 12_000_000},
             "not a multiple of the requested period"),
            ({"gpu_busy_percent_period_ns": 10_000_000, "pp_dpm_period_ns": 50_000_000},
             "gpu_busy_percent_period_ns=10000000 disagrees")):
        record, _, _ = sidecar_record(sample_rates=bad_rates)
        result = refused(record, "cadence_values")
        assert reason_fragment in result.stdout, (reason_fragment, result.stdout)
    print("case=channel_cadence_and_values verdict=accepted")


# dpm_marker_cadence: the sampler's own `# dpm_read=` stamps checked against
# the cadence it declared for that bundle, restricted to markers whose gap
# overlaps the request window so a PAUSE/RESUME hole outside the window costs
# the arm nothing here, the same overlap discipline the row-gap check applies.
def case_dpm_marker_cadence():
    period_ns = 5_000_000
    declared = 50_000_000  # ten requested periods

    # Markers land every ten rows, exactly the declared cadence: accepted.
    record, start, last = sidecar_record(
        samples=40, period_ns=period_ns, dpm_read_stride=10,
        sample_rates={"gpu_busy_percent_period_ns": period_ns,
                      "pp_dpm_period_ns": declared})
    result = accepted_line(record, "dpm_marker_cadence",
                           period_ns=period_ns, window=(start, last))
    assert f"declared_ns={declared}" in result.stdout, result.stdout
    assert result.returncode == 0, result.stdout

    # Markers land every thirty rows inside the window -- three declared
    # periods -- which is the sampler's own freshness stamp presenting a
    # cache older than 1.5 declared periods as current.
    record, start, last = sidecar_record(
        samples=90, period_ns=period_ns, dpm_read_stride=30,
        sample_rates={"gpu_busy_percent_period_ns": period_ns,
                      "pp_dpm_period_ns": declared})
    result = refused(record, "dpm_marker_cadence",
                     period_ns=period_ns, window=(start, last))
    assert f"declared_ns={declared}" in result.stdout, result.stdout
    assert "failures=dpm_marker_cadence" in result.stdout, result.stdout

    # The same over-wide marker spacing, but the request window sits entirely
    # after the last marker inside it: dpm_marker_cadence has no in-window gap
    # to compare and reports not_run, the same way a PAUSE/RESUME hole outside
    # the window costs it nothing there -- but every window row now carries a
    # DPM value read before the window began, and dpm_freshness_reads is the
    # rule that catches a channel that never refreshed inside the window
    # rather than reading its zero fresh count as an unstated pass.
    record, start, last = sidecar_record(
        samples=90, period_ns=period_ns, dpm_read_stride=30,
        sample_rates={"gpu_busy_percent_period_ns": period_ns,
                      "pp_dpm_period_ns": declared})
    late_window = (last - 2 * period_ns, last)
    result = validate(record, period_ns=period_ns, window=late_window)
    assert "dpm_marker_cadence=not_run" in result.stdout, result.stdout
    assert "dpm_freshness_reads=refused fresh_samples=0" in result.stdout, result.stdout
    assert result.returncode != 0, result.stdout
    assert "dpm_freshness_reads" in result.stdout.rstrip("\n").split("\n")[-1], result.stdout

    # No markers at all: the derived (row-position) path is read instead and
    # this check has nothing to compare, so it stays out of the verdict.
    record, start, last = sidecar_record(
        samples=40, period_ns=period_ns,
        sample_rates={"gpu_busy_percent_period_ns": period_ns,
                      "pp_dpm_period_ns": declared})
    result = validate(record, period_ns=period_ns, window=(start, last))
    assert "dpm_marker_cadence=not_run no dpm_read markers" in result.stdout, result.stdout
    assert result.returncode == 0, result.stdout

    # One marker at the very start of the window and none after it: the
    # pairwise scan over consecutive markers has nothing to compare (a
    # single instant zips to no pair) and would report not_run while the
    # channel stays stale for the entire rest of the window -- the P1 gap a
    # terminal marker-to-window-end check closes. dpm_read_stride wider than
    # the sample count leaves only the index-0 marker.
    record, start, last = sidecar_record(
        samples=40, period_ns=period_ns, dpm_read_stride=1000,
        sample_rates={"gpu_busy_percent_period_ns": period_ns,
                      "pp_dpm_period_ns": declared})
    result = refused(record, "dpm_marker_cadence",
                     period_ns=period_ns, window=(start, last))
    terminal_gap = last - start
    assert f"max_gap_ns={terminal_gap}" in result.stdout, result.stdout
    assert "failures=dpm_marker_cadence" in result.stdout, result.stdout
    print("case=dpm_marker_cadence verdict=accepted")


# dpm_read_markers: a marker's own instant is checked as a digit string ahead
# of any int() conversion of it, since a marker's prefix parsing cleanly
# states nothing about the text after it -- a garbled marker refuses the
# record by name rather than raising past it with a traceback -- and
# separately checked to name a row the record actually carries, since an
# orphaned marker between two genuine ones would otherwise shrink a
# dpm_marker_cadence gap without a real refresh behind it.
def case_dpm_read_markers_malformed():
    def record(marker_line):
        return "\n".join([
            "# clock=CLOCK_MONOTONIC period_ns=5000000 drm_device=/fake hwmon=/fake/hwmon0",
            "# sample_rates: gpu_busy_percent_period_ns=5000000 pp_dpm_period_ns=50000000",
            "# interpretation: pp_dpm_sclk_selected_mhz is the selected graphics clock step",
            marker_line,
            "# sampler_pid=4242 nice=10 cpu_affinity=1",
            COLUMNS,
            "1000000000\t400\t933\t1067\t37\t61000\t30000",
            "1005000000\t400\t933\t1067\t37\t61000\t30000",
            "# samples=2 achieved_period_ns=5000000 mean_sample_cost_ns=30000"
            " max_sample_cost_ns=30000 samples_with_unavailable_sensor=0"
            " first_sample_ns=1000000000 last_sample_ns=1005000000",
        ]) + "\n"

    result = validate(record("# dpm_read=garbage"))
    assert result.returncode != 0, result.stdout
    assert "dpm_read_markers=refused invalid=garbage" in result.stdout, result.stdout
    assert "dpm_marker_cadence=not_run malformed dpm_read markers" in result.stdout, result.stdout
    assert "failures=dpm_read_markers" in result.stdout, result.stdout

    # A well-formed digit string that names no row in the record: the same
    # refusal, since a fabricated instant is exactly what would otherwise
    # narrow the gap distribution dpm_marker_cadence reads.
    result = validate(record("# dpm_read=1002500000"))
    assert result.returncode != 0, result.stdout
    assert "dpm_read_markers=refused invalid=1002500000" in result.stdout, result.stdout
    assert "failures=dpm_read_markers" in result.stdout, result.stdout
    print("case=dpm_read_markers_malformed verdict=accepted")


# The declared refresh cadence beside the freshness line: fresh_temp1_samples
# and temp1_period_multiple ride the same tail the DPM fields already carry,
# so the temperature channel is read through the same discipline rather than
# being left to a whole-window mean over every repeated cell.
def case_temperature_freshness_reported():
    period_ns = 5_000_000
    record, start, last = sidecar_record(
        samples=40, period_ns=period_ns,
        sample_rates={"gpu_busy_percent_period_ns": period_ns,
                      "pp_dpm_period_ns": 50_000_000,
                      "temp1_input_period_ns": 50_000_000})
    result = validate(record, period_ns=period_ns, window=(start, last))
    assert "temp1_period_multiple=10" in result.stdout, result.stdout
    assert "fresh_temp1_samples=4" in result.stdout, result.stdout
    assert "dpm_freshness_reads=accepted" in result.stdout, result.stdout
    assert "temp1_freshness_reads=accepted" in result.stdout, result.stdout
    assert result.returncode == 0, result.stdout
    print("case=temperature_freshness_reported verdict=accepted")


# dpm_freshness_reads / temp1_freshness_reads on the derived (no-marker) path:
# a DPM reading refreshed every ~200 ms must not count as ten fresh 20 ms
# observations, and the extreme of that is a window that catches none of the
# periodic fresh rows at all, so every row it holds carries a value read
# before the window began. The derived fresh indices land on rows 0, 10, ...,
# 80 of 90, so a window opening at row 81 catches none of them for either
# channel.
def case_freshness_reads_zero_in_window():
    period_ns = 5_000_000
    record, start, last = sidecar_record(
        samples=90, period_ns=period_ns,
        sample_rates={"gpu_busy_percent_period_ns": period_ns,
                      "pp_dpm_period_ns": 50_000_000,
                      "temp1_input_period_ns": 50_000_000})
    tail_window = (start + 81 * period_ns, last)
    result = validate(record, period_ns=period_ns, window=tail_window)
    assert result.returncode != 0, result.stdout
    assert "dpm_freshness_reads=refused fresh_samples=0 window_samples=9" \
        " period_multiple=10" in result.stdout, result.stdout
    assert "temp1_freshness_reads=refused fresh_samples=0 window_samples=9" \
        " period_multiple=10" in result.stdout, result.stdout
    assert "failures=dpm_freshness_reads,temp1_freshness_reads" in result.stdout, result.stdout

    # A window with no declared multiple above one, and no window at all,
    # both make no claim either check can fail.
    plain, start, last = sidecar_record(samples=90, period_ns=period_ns)
    result = validate(plain, period_ns=period_ns, window=tail_window)
    assert "dpm_freshness_reads=not_run period_multiple=1" in result.stdout, result.stdout
    assert "temp1_freshness_reads=not_run period_multiple=1" in result.stdout, result.stdout
    assert result.returncode == 0, result.stdout

    result = validate(record, period_ns=period_ns)
    assert "dpm_freshness_reads=not_run no window supplied" in result.stdout, result.stdout
    assert "temp1_freshness_reads=not_run no window supplied" in result.stdout, result.stdout
    print("case=freshness_reads_zero_in_window verdict=accepted")


# Argument-level defects: checked where they are parsed, ahead of any read of
# the record, the way the existing finite-range bounds already are.
def case_argument_bounds():
    record, start, last = sidecar_record()
    path = write("plain.tsv", record)

    def parse_error(extra_args):
        command = [sys.executable, validator, path, "--sidecar-status", "0",
                  "--period-ms", "5", "--period-tolerance", "0.25",
                  "--cost-bound-ns", "1000000", "--max-gap-ns", "50000000",
                  "--max-lost-fraction", "0.02"] + extra_args
        return run(command)

    # A window supplied on one side alone is refused rather than silently
    # degrading coverage, clock_state, and every fresh-row selection to
    # not_run.
    result = parse_error(["--window-begin-ns", "1000"])
    assert result.returncode == 2, result.stderr
    assert "together" in result.stderr, result.stderr

    result = parse_error(["--window-end-ns", "2000"])
    assert result.returncode == 2, result.stderr

    result = parse_error(["--window-begin-ns", "-5", "--window-end-ns", "2000"])
    assert result.returncode == 2, result.stderr
    assert "nonnegative" in result.stderr, result.stderr

    for bad_args, name in (
            (["--cost-bound-ns", "0"], "--cost-bound-ns"),
            (["--max-gap-ns", "-1"], "--max-gap-ns"),
            (["--required-sclk-mhz", "0"], "--required-sclk-mhz"),
            (["--required-mclk-mhz", "-100"], "--required-mclk-mhz")):
        result = parse_error(bad_args)
        assert result.returncode == 2, (name, result.stderr)
        assert name in result.stderr, (name, result.stderr)

    # A window supplied whole, with nonnegative and ordered bounds, and every
    # positive integer bound still reaches the record-level checks.
    result = validate(record, window=(start, last))
    assert result.returncode == 0, result.stdout
    print("case=argument_bounds verdict=accepted")


case_sampler_declared_identity()
case_sampler_format()
case_channel_cadence_and_values()
case_dpm_marker_cadence()
case_dpm_read_markers_malformed()
case_temperature_freshness_reported()
case_freshness_reads_zero_in_window()
case_argument_bounds()
print("validate_clock_sidecar=accepted")
