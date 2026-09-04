#!/usr/bin/env python3
"""Difference the RAPL energy counters across a served request window.

The kernel exposes no writable package constraint on this part, and
`evidence/power-envelope/README.md` records the two counters it does expose:
`/sys/class/powercap/intel-rapl:0/energy_uj` for the package-0 domain and
`intel-rapl:0:0/energy_uj` for the core domain, both mode 0400. Package power
is therefore two privileged reads of a monotonically rising microjoule counter
differenced across an interval, which is what this reader performs.

`measure-served-decode.sh` exposes no boundary hook. It stamps
`request-window.tsv` with `time.monotonic_ns()` immediately before curl and
immediately after it returns, so the two boundary reads are selected out of a
record taken across the arm rather than issued from inside the runner. `sample`
takes that record under one privileged process, `window` selects the two
boundary reads out of it, and `read` is the single paired read both are built
from. Both domains are read inside one process with one monotonic stamp between
them, so package and core watts share a denominator.

A window is bracketed twice. The inner bracket is the first sample at or after
the window's beginning and the last sample at or before its end, so its whole
interval lies inside the request; the outer bracket is the last sample at or
before the beginning and the first sample at or after the end, so the request
lies inside its interval. The inner figure is the arm's reading and the outer
figure bounds it, and the two agree to the sampling period at each edge rather
than to an asserted accuracy.

The counters wrap. `max_energy_range_uj` is documented as the maximum readable
value, so a counter runs modulo one microjoule above it, and a later reading
below an earlier one is one wrap rather than a fault. On this part at about 6 W
the wrap period is near three hours, so a wrap inside an arm is possible and a
reader that cannot express one would report a negative energy.

`sample` reads the counters directly and never calls sudo, because a sudo per
sample would cost more than the sample. The caller runs it as
`sudo -n python3 read-package-energy.py sample ...`; the record is opened before
any read, chowned to SUDO_UID and SUDO_GID where they are set, and left mode
0644, so the unprivileged summarizer reads what the privileged sampler wrote.

Every path resolves under --powercap-root, so remote/test-read-package-energy.py
drives the whole reader against a fixture tree with no privilege.

usage: read-package-energy.py read [--powercap-root PATH]
       read-package-energy.py sample OUTPUT_TSV [--period-ms N]
           [--duration-s N] [--powercap-root PATH]
       read-package-energy.py window SAMPLES_TSV --window-begin-ns N
           --window-end-ns N
"""
import argparse
import errno
import os
import signal
import sys
import time

PACKAGE_DOMAIN = "intel-rapl:0"
CORE_DOMAIN = "intel-rapl:0:0"
EXPECTED_DOMAIN_NAMES = {PACKAGE_DOMAIN: "package-0", CORE_DOMAIN: "core"}
SAMPLE_HEADER = ("monotonic_ns", "package_uj", "core_uj", "sample_cost_ns")


def fail(reason):
    sys.stderr.write(f"reason={reason}\n")
    raise SystemExit(2)


def read_counter_file(path):
    with open(path, "rb") as handle:
        text = handle.read().decode("ascii", "strict").strip()
    if not text.isdecimal():
        raise ValueError(f"counter is not a decimal integer: {path}")
    return int(text)


class EnergyDomains:
    """The two counters, their wrap periods, and one paired read of both."""

    def __init__(self, powercap_root):
        self.package_path = os.path.join(powercap_root, PACKAGE_DOMAIN, "energy_uj")
        self.core_path = os.path.join(powercap_root, CORE_DOMAIN, "energy_uj")
        self.package_wrap = 0
        self.core_wrap = 0
        for domain, expected_name in EXPECTED_DOMAIN_NAMES.items():
            domain_directory = os.path.join(powercap_root, domain)
            name_path = os.path.join(domain_directory, "name")
            try:
                with open(name_path) as handle:
                    observed_name = handle.read().strip()
            except OSError as error:
                if error.errno == errno.EACCES:
                    fail(f"domain_name_unreadable domain={domain} path={name_path}")
                fail(f"domain_absent domain={domain} path={name_path}")
            if observed_name != expected_name:
                fail(
                    f"domain_name_unexpected domain={domain} "
                    f"observed={observed_name} expected={expected_name}"
                )
            try:
                wrap = read_counter_file(
                    os.path.join(domain_directory, "max_energy_range_uj")
                ) + 1
            except (OSError, ValueError):
                fail(f"wrap_period_unreadable domain={domain}")
            if domain == PACKAGE_DOMAIN:
                self.package_wrap = wrap
            else:
                self.core_wrap = wrap

    def read(self):
        """One paired read with the monotonic stamp taken between the two."""
        cost_begin = time.monotonic_ns()
        package_uj = read_counter_file(self.package_path)
        monotonic_ns = time.monotonic_ns()
        core_uj = read_counter_file(self.core_path)
        cost_end = time.monotonic_ns()
        return monotonic_ns, package_uj, core_uj, cost_end - cost_begin


def command_read(arguments):
    domains = EnergyDomains(arguments.powercap_root)
    try:
        monotonic_ns, package_uj, core_uj, cost_ns = domains.read()
    except (OSError, ValueError) as error:
        fail(f"counter_unreadable detail={error}")
    sys.stdout.write("key\tvalue\n")
    sys.stdout.write("schema\tpackage-energy-read-v1\n")
    sys.stdout.write("clock\tCLOCK_MONOTONIC\n")
    sys.stdout.write(f"monotonic_ns\t{monotonic_ns}\n")
    sys.stdout.write(f"package_uj\t{package_uj}\n")
    sys.stdout.write(f"core_uj\t{core_uj}\n")
    sys.stdout.write(f"package_wrap_uj\t{domains.package_wrap}\n")
    sys.stdout.write(f"core_wrap_uj\t{domains.core_wrap}\n")
    sys.stdout.write(f"sample_cost_ns\t{cost_ns}\n")
    return 0


def own_output_to_invoking_user(handle):
    """A root sampler leaves a record its unprivileged summarizer can read."""
    os.fchmod(handle.fileno(), 0o644)
    if os.geteuid() != 0:
        return
    sudo_uid = os.environ.get("SUDO_UID", "")
    sudo_gid = os.environ.get("SUDO_GID", "")
    if sudo_uid.isdecimal() and sudo_gid.isdecimal():
        os.fchown(handle.fileno(), int(sudo_uid), int(sudo_gid))


def command_sample(arguments):
    if arguments.period_ms <= 0:
        fail(f"period_not_positive period_ms={arguments.period_ms}")
    if arguments.duration_s is not None and arguments.duration_s <= 0:
        fail(f"duration_not_positive duration_s={arguments.duration_s}")
    domains = EnergyDomains(arguments.powercap_root)
    period_ns = int(arguments.period_ms * 1000000)
    running = {"value": True}

    def stop(_signal_number, _frame):
        running["value"] = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    with open(arguments.output, "w") as handle:
        own_output_to_invoking_user(handle)
        handle.write("key\tvalue\n")
        handle.write("schema\tpackage-energy-sample-v1\n")
        handle.write("clock\tCLOCK_MONOTONIC\n")
        handle.write(f"period_ns\t{period_ns}\n")
        handle.write(f"package_wrap_uj\t{domains.package_wrap}\n")
        handle.write(f"core_wrap_uj\t{domains.core_wrap}\n")
        handle.write(f"sampler_pid\t{os.getpid()}\n")
        handle.write("\t".join(SAMPLE_HEADER) + "\n")
        handle.flush()
        sample_count = 0
        unreadable_count = 0
        first_ns = None
        last_ns = None
        begin_ns = time.monotonic_ns()
        deadline_ns = None
        if arguments.duration_s is not None:
            deadline_ns = begin_ns + int(arguments.duration_s * 1000000000)
        while running["value"]:
            try:
                monotonic_ns, package_uj, core_uj, cost_ns = domains.read()
            except (OSError, ValueError):
                unreadable_count += 1
                monotonic_ns = time.monotonic_ns()
                handle.write(f"{monotonic_ns}\tunavailable\tunavailable\tunavailable\n")
            else:
                sample_count += 1
                if first_ns is None:
                    first_ns = monotonic_ns
                last_ns = monotonic_ns
                handle.write(
                    f"{monotonic_ns}\t{package_uj}\t{core_uj}\t{cost_ns}\n"
                )
            handle.flush()
            now_ns = time.monotonic_ns()
            if deadline_ns is not None and now_ns >= deadline_ns:
                break
            elapsed_periods = (now_ns - begin_ns) // period_ns
            next_ns = begin_ns + (elapsed_periods + 1) * period_ns
            sleep_s = (next_ns - now_ns) / 1000000000
            if sleep_s > 0:
                time.sleep(sleep_s)
        achieved_period_ns = "unavailable"
        if sample_count > 1:
            achieved_period_ns = str((last_ns - first_ns) // (sample_count - 1))
        handle.write(f"footer_sample_count\t{sample_count}\n")
        handle.write(f"footer_unreadable_count\t{unreadable_count}\n")
        handle.write(f"footer_achieved_period_ns\t{achieved_period_ns}\n")
        handle.write(f"footer_first_monotonic_ns\t{first_ns if first_ns is not None else 'unavailable'}\n")
        handle.write(f"footer_last_monotonic_ns\t{last_ns if last_ns is not None else 'unavailable'}\n")
    return 0


def load_sample_record(path):
    header = {}
    samples = []
    footer = {}
    seen_columns = False
    with open(path) as handle:
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            if not seen_columns:
                if tuple(fields) == SAMPLE_HEADER:
                    seen_columns = True
                elif len(fields) == 2:
                    header[fields[0]] = fields[1]
                else:
                    fail(f"sample_record_malformed path={path} line={line!r}")
                continue
            if len(fields) == 2:
                footer[fields[0]] = fields[1]
                continue
            if len(fields) != len(SAMPLE_HEADER):
                fail(f"sample_record_malformed path={path} line={line!r}")
            if fields[1] == "unavailable" or fields[2] == "unavailable":
                continue
            try:
                samples.append(
                    (int(fields[0]), int(fields[1]), int(fields[2]))
                )
            except ValueError:
                fail(f"sample_record_malformed path={path} line={line!r}")
    if not seen_columns:
        fail(f"sample_record_headerless path={path}")
    if header.get("schema") != "package-energy-sample-v1":
        fail(f"sample_schema_unknown schema={header.get('schema', 'absent')}")
    if header.get("clock") != "CLOCK_MONOTONIC":
        fail(f"sample_clock_unknown clock={header.get('clock', 'absent')}")
    for wrap_key in ("package_wrap_uj", "core_wrap_uj"):
        wrap_text = header.get(wrap_key, "")
        if not wrap_text.isdecimal() or int(wrap_text) <= 0:
            fail(f"sample_wrap_period_invalid key={wrap_key}")
    for index in range(1, len(samples)):
        if samples[index][0] <= samples[index - 1][0]:
            fail("sample_record_not_monotonic")
    return header, samples, footer


def counter_delta(earlier_uj, later_uj, wrap_uj):
    """A later reading below an earlier one is one wrap of the counter."""
    delta = later_uj - earlier_uj
    if delta < 0:
        delta += wrap_uj
    return delta


def bracket_window(samples, begin_ns, end_ns, mode):
    if mode == "inner":
        opening = next((s for s in samples if s[0] >= begin_ns), None)
        closing = next((s for s in reversed(samples) if s[0] <= end_ns), None)
    else:
        opening = next((s for s in reversed(samples) if s[0] <= begin_ns), None)
        closing = next((s for s in samples if s[0] >= end_ns), None)
    if opening is None or closing is None or closing[0] <= opening[0]:
        return None
    return opening, closing


def emit_bracket(header, samples, begin_ns, end_ns, mode):
    bracket = bracket_window(samples, begin_ns, end_ns, mode)
    if bracket is None:
        sys.stdout.write(f"{mode}_bracket\tunreached\n")
        return False
    opening, closing = bracket
    interval_ns = closing[0] - opening[0]
    package_uj = counter_delta(
        opening[1], closing[1], int(header["package_wrap_uj"])
    )
    core_uj = counter_delta(opening[2], closing[2], int(header["core_wrap_uj"]))
    interval_s = interval_ns / 1000000000
    sys.stdout.write(f"{mode}_begin_ns\t{opening[0]}\n")
    sys.stdout.write(f"{mode}_end_ns\t{closing[0]}\n")
    sys.stdout.write(f"{mode}_interval_s\t{interval_s:.6f}\n")
    sys.stdout.write(f"{mode}_package_joules\t{package_uj / 1000000:.6f}\n")
    sys.stdout.write(f"{mode}_core_joules\t{core_uj / 1000000:.6f}\n")
    sys.stdout.write(f"{mode}_package_watts\t{package_uj / 1000000 / interval_s:.6f}\n")
    sys.stdout.write(f"{mode}_core_watts\t{core_uj / 1000000 / interval_s:.6f}\n")
    return True


def command_window(arguments):
    if arguments.window_end_ns <= arguments.window_begin_ns:
        fail(
            f"window_not_positive begin_ns={arguments.window_begin_ns} "
            f"end_ns={arguments.window_end_ns}"
        )
    header, samples, footer = load_sample_record(arguments.samples)
    if len(samples) < 2:
        fail(f"sample_record_too_short samples={len(samples)}")
    window_s = (arguments.window_end_ns - arguments.window_begin_ns) / 1000000000
    sys.stdout.write("key\tvalue\n")
    sys.stdout.write("schema\tpackage-energy-window-v1\n")
    sys.stdout.write("clock\tCLOCK_MONOTONIC\n")
    sys.stdout.write(f"window_begin_ns\t{arguments.window_begin_ns}\n")
    sys.stdout.write(f"window_end_ns\t{arguments.window_end_ns}\n")
    sys.stdout.write(f"window_s\t{window_s:.6f}\n")
    sys.stdout.write(f"sample_count\t{len(samples)}\n")
    sys.stdout.write(
        f"sample_period_ns\t{header.get('period_ns', 'unavailable')}\n"
    )
    sys.stdout.write(
        f"unreadable_count\t{footer.get('footer_unreadable_count', 'unavailable')}\n"
    )
    inner_reached = emit_bracket(
        header, samples, arguments.window_begin_ns, arguments.window_end_ns, "inner"
    )
    outer_reached = emit_bracket(
        header, samples, arguments.window_begin_ns, arguments.window_end_ns, "outer"
    )
    if not inner_reached or not outer_reached:
        sys.stdout.write("window_coverage\tunreached\n")
        sys.stderr.write(
            "reason=window_outside_sample_record; the sampler did not span the "
            "request window at both edges\n"
        )
        return 3
    sys.stdout.write("window_coverage\tbracketed\n")
    return 0


def parse_arguments(argv):
    parser = argparse.ArgumentParser(add_help=True)
    subparsers = parser.add_subparsers(dest="command", required=True)

    read_parser = subparsers.add_parser("read")
    read_parser.add_argument(
        "--powercap-root", default=os.environ.get("QWEN_POWERCAP_ROOT", "/sys/class/powercap")
    )
    read_parser.set_defaults(handler=command_read)

    sample_parser = subparsers.add_parser("sample")
    sample_parser.add_argument("output")
    sample_parser.add_argument("--period-ms", type=float, default=50.0)
    sample_parser.add_argument("--duration-s", type=float, default=None)
    sample_parser.add_argument(
        "--powercap-root", default=os.environ.get("QWEN_POWERCAP_ROOT", "/sys/class/powercap")
    )
    sample_parser.set_defaults(handler=command_sample)

    window_parser = subparsers.add_parser("window")
    window_parser.add_argument("samples")
    window_parser.add_argument("--window-begin-ns", type=int, required=True)
    window_parser.add_argument("--window-end-ns", type=int, required=True)
    window_parser.set_defaults(handler=command_window)

    return parser.parse_args(argv)


def main(argv):
    arguments = parse_arguments(argv)
    return arguments.handler(arguments)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
