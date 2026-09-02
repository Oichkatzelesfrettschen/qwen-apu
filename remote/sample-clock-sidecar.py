#!/usr/bin/env python3
"""Sample the amdgpu clock state at a period short against one token.

sample-gpu-clocks.sh reads the same sysfs files once a second, which places
a rate inside a minute and cannot place a 52 to 62 ms token inside a clock
transition. This sampler reads the selected SCLK, MCLK, and FCLK steps, GPU
busy, and the die temperature every PERIOD_MS on CLOCK_MONOTONIC, the clock
the census binary stamps every graph with and the served-decode runner
stamps its request window with, so a clock step is placed against a graph
rather than against a minute. Every row carries the sampler's own cost for
that sample, and the footer carries the achieved period, so a sampler that
could not hold its period says so instead of thinning silently.

Rows: `monotonic_ns`, `sclk_mhz`, `mclk_mhz`, `fclk_mhz`, `busy_percent`,
`millidegrees`, `sample_cost_ns`. An unreadable sensor writes
`unavailable`. SIGTERM ends the loop and writes the footer.

usage: sample-clock-sidecar.py OUTPUT_TSV [--period-ms N]
       [--drm-device PATH] [--hwmon-root PATH]
"""
import argparse
import os
import signal
import sys
import time


def selected_step(path):
    try:
        with open(path) as handle:
            for line in handle:
                if "*" in line:
                    return line.split()[1].rstrip(":").replace("Mhz", "")
    except OSError:
        return "unavailable"
    return "unavailable"


def read_value(path):
    try:
        with open(path) as handle:
            return handle.read().strip() or "unavailable"
    except OSError:
        return "unavailable"


def find_hwmon(root):
    try:
        entries = sorted(os.listdir(root))
    except OSError:
        return None
    for entry in entries:
        if read_value(os.path.join(root, entry, "name")) == "amdgpu":
            return os.path.join(root, entry)
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output")
    parser.add_argument("--period-ms", type=float, default=5.0)
    parser.add_argument("--drm-device", default=os.environ.get("QWEN_DRM_DEVICE", "/sys/class/drm/card1/device"))
    parser.add_argument("--hwmon-root", default=os.environ.get("QWEN_HWMON_ROOT", "/sys/class/hwmon"))
    args = parser.parse_args()
    if args.period_ms <= 0:
        print("period must be positive", file=sys.stderr)
        return 2
    period_ns = int(args.period_ms * 1_000_000)
    hwmon = find_hwmon(args.hwmon_root)
    temperature_path = os.path.join(hwmon, "temp1_input") if hwmon else None
    sclk_path = os.path.join(args.drm_device, "pp_dpm_sclk")
    mclk_path = os.path.join(args.drm_device, "pp_dpm_mclk")
    fclk_path = os.path.join(args.drm_device, "pp_dpm_fclk")
    busy_path = os.path.join(args.drm_device, "gpu_busy_percent")

    stopping = False

    def stop(_signum, _frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    samples = 0
    cost_total = 0
    started = time.monotonic_ns()
    with open(args.output, "w") as out:
        out.write("# clock=CLOCK_MONOTONIC period_ns=%d drm_device=%s\n" % (period_ns, args.drm_device))
        out.write("monotonic_ns\tsclk_mhz\tmclk_mhz\tfclk_mhz\tbusy_percent\tmillidegrees\tsample_cost_ns\n")
        out.flush()
        next_due = started
        while not stopping:
            begin = time.monotonic_ns()
            row = (selected_step(sclk_path), selected_step(mclk_path), selected_step(fclk_path),
                   read_value(busy_path),
                   read_value(temperature_path) if temperature_path else "unavailable")
            end = time.monotonic_ns()
            out.write("%d\t%s\t%s\t%s\t%s\t%s\t%d\n" % ((begin,) + row + (end - begin,)))
            samples += 1
            cost_total += end - begin
            if samples % 200 == 0:
                out.flush()
            next_due += period_ns
            delay = next_due - time.monotonic_ns()
            if delay > 0:
                time.sleep(delay / 1e9)
            else:
                next_due = time.monotonic_ns()
        finished = time.monotonic_ns()
        achieved = (finished - started) / samples if samples else 0
        out.write("# samples=%d achieved_period_ns=%.0f mean_sample_cost_ns=%.0f\n"
                  % (samples, achieved, cost_total / samples if samples else 0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
