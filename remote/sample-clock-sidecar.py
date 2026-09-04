#!/usr/bin/env python3
"""Sample the amdgpu clock state at a period short against one token.

sample-gpu-clocks.sh reads the same sysfs files once a second, which places
a rate inside a minute and cannot place a 52 to 62 ms token inside a clock
transition. This sampler reads the selected SCLK, MCLK, and FCLK steps, GPU
busy, and the die temperature every PERIOD_MS on CLOCK_MONOTONIC, the clock
the census binary stamps every graph with and the served-decode runner
stamps its request window with, so a clock step is placed against a graph
rather than against a minute. Every row carries the sampler's own cost for
that sample, and the footer carries the achieved period and unavailable-sample
count, so a sampler that could not hold its period or encountered sensor
failures reports them explicitly.

Columns: monotonic_ns (sample instant on CLOCK_MONOTONIC), pp_dpm_sclk_selected_mhz
(selected graphics-clock step from pp_dpm_sclk), pp_dpm_mclk_surface_mhz (the
pp_dpm_mclk sysfs surface, which on SMU10 is a fabric-clock state rather than
the trained DRAM speed), pp_dpm_fclk_surface_mhz (the pp_dpm_fclk sysfs surface),
gpu_busy_percent, temp1_millidegrees (die temperature in millidegrees Celsius),
sample_cost_ns (wall cost of the sample operation). An unreadable sensor or a DPM
file carrying no selected step writes unavailable.

Options: --period-ms N (default 5; must be positive; milliseconds between samples),
--drm-device PATH (default /sys/class/drm/card1/device or QWEN_DRM_DEVICE),
--hwmon-root PATH (default /sys/class/hwmon or QWEN_HWMON_ROOT), --nice N (default 19;
renice the sampler to this absolute niceness), --cpu LIST (optional; pin the sampler
to CPU N with os.sched_setaffinity).

Header carries clock source, configured period in nanoseconds, drm device path, hwmon
root or "-" when not found, sampler PID, absolute nice level, CPU affinity, and
sampler_format=native-fresh-v1, the record-shape claim validate-clock-sidecar.py
checks: every column here is read fresh on every sample, since this sampler opens no
ring and caches nothing between samples, unlike telemetry-broker.c's multirate
channels. Footer carries sample count, achieved period, mean and max sample cost,
count of samples with any unavailable sensor, and first and last monotonic instants.

SIGTERM or SIGINT ends the loop and writes the footer.

usage: sample-clock-sidecar.py OUTPUT_TSV [--period-ms N]
       [--drm-device PATH] [--hwmon-root PATH] [--nice N] [--cpu LIST]
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
    parser.add_argument("--nice", type=int, default=19)
    parser.add_argument("--cpu", type=str, default=None,
                        help="comma-separated CPU list the sampler is confined to")
    args = parser.parse_args()

    if args.period_ms <= 0:
        print("period must be positive", file=sys.stderr)
        return 2

    try:
        current_nice = os.nice(0)
        delta = args.nice - current_nice
        if delta > 0:
            os.nice(delta)
        elif delta < 0:
            # Lowering niceness needs CAP_SYS_NICE; the refusal names the target.
            try:
                os.nice(delta)
            except OSError as e:
                print("cannot reach nice %d: %s" % (args.nice, e), file=sys.stderr)
                return 2
    except OSError as e:
        print("cannot set nice: %s" % e, file=sys.stderr)
        return 2

    if args.cpu is not None:
        try:
            os.sched_setaffinity(0, {int(c) for c in args.cpu.split(",") if c != ""})
        except OSError as e:
            print("cannot set CPU affinity to %s: %s" % (args.cpu, e), file=sys.stderr)
            return 2

    try:
        cpu_affinity = sorted(list(os.sched_getaffinity(0)))
    except OSError:
        cpu_affinity = []

    period_ns = int(args.period_ms * 1_000_000)

    output_dir = os.path.dirname(args.output)
    if output_dir == "":
        output_dir = "."
    if not os.path.isdir(output_dir):
        print("output directory does not exist: %s" % output_dir, file=sys.stderr)
        return 2
    if not os.access(output_dir, os.W_OK):
        print("output directory is not writable: %s" % output_dir, file=sys.stderr)
        return 2

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
    cost_max = 0
    unavailable_count = 0
    first_ns = None
    last_ns = None
    started = time.monotonic_ns()

    try:
        with open(args.output, "w") as out:
            out.write("# clock=CLOCK_MONOTONIC period_ns=%d drm_device=%s hwmon=%s\n"
                     % (period_ns, args.drm_device, hwmon if hwmon else "-"))
            out.write("# interpretation: pp_dpm_sclk_selected_mhz is the selected graphics clock step; pp_dpm_mclk_surface_mhz is the pp_dpm_mclk sysfs surface, which on SMU10 is a fabric-clock state rather than the trained DRAM speed; pp_dpm_fclk_surface_mhz is the pp_dpm_fclk sysfs surface\n")
            cpu_affinity_str = ",".join(str(c) for c in cpu_affinity) if cpu_affinity else ""
            current_nice = os.nice(0)
            out.write("# sampler_pid=%d nice=%d cpu_affinity=%s sampler_format=native-fresh-v1\n"
                     % (os.getpid(), current_nice, cpu_affinity_str))
            out.write("monotonic_ns\tpp_dpm_sclk_selected_mhz\tpp_dpm_mclk_surface_mhz\tpp_dpm_fclk_surface_mhz\tgpu_busy_percent\ttemp1_millidegrees\tsample_cost_ns\n")
            out.flush()

            next_due = started
            while not stopping:
                begin = time.monotonic_ns()
                sclk_val = selected_step(sclk_path)
                mclk_val = selected_step(mclk_path)
                fclk_val = selected_step(fclk_path)
                busy_val = read_value(busy_path)
                temp_val = read_value(temperature_path) if temperature_path else "unavailable"

                end = time.monotonic_ns()
                sample_cost = end - begin

                if any(v == "unavailable" for v in [sclk_val, mclk_val, fclk_val, busy_val, temp_val]):
                    unavailable_count += 1

                out.write("%d\t%s\t%s\t%s\t%s\t%s\t%d\n"
                         % (begin, sclk_val, mclk_val, fclk_val, busy_val, temp_val, sample_cost))

                samples += 1
                cost_total += sample_cost
                cost_max = max(cost_max, sample_cost)

                if first_ns is None:
                    first_ns = begin
                last_ns = begin

                if samples % 200 == 0:
                    out.flush()

                next_due += period_ns
                delay = next_due - time.monotonic_ns()
                if delay > 0:
                    time.sleep(delay / 1e9)
                else:
                    next_due = time.monotonic_ns()

            # Calculate achieved period
            if samples >= 2:
                achieved = (last_ns - first_ns) // (samples - 1)
            else:
                achieved = 0

            mean_cost = cost_total // samples if samples else 0

            out.write("# samples=%d achieved_period_ns=%d mean_sample_cost_ns=%d max_sample_cost_ns=%d samples_with_unavailable_sensor=%d first_sample_ns=%d last_sample_ns=%d\n"
                     % (samples, achieved, mean_cost, cost_max, unavailable_count, first_ns if first_ns is not None else 0, last_ns if last_ns is not None else 0))
            out.flush()
    except OSError as e:
        print("failed to write output: %s" % e, file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
