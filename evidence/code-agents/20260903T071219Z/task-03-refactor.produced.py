"""Format a measurement line for a sweep summary.

The fixture ships three scaling functions that repeat one loop with different
tables, which is the duplication task-03-refactor asks a model to collapse.
The observable behavior is what the paired test module pins.
"""

import sys


def _format(value, units, divisor):
    """Format a value using the given units and divisor.

    Args:
        value: The numeric value to format.
        units: A list of unit strings.
        divisor: The divisor used for scaling (1024.0 or 1000.0).

    Returns:
        A formatted string like "512 B" or "2.00 KiB".
    """
    amount = float(value)
    index = 0
    while amount >= divisor and index < len(units) - 1:
        amount /= divisor
        index += 1
    if index == 0:
        return "%d %s" % (int(amount), units[index])
    return "%.2f %s" % (amount, units[index])


def format_bytes(value):
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    return _format(value, units, 1024.0)


def format_seconds(value):
    units = ["s", "ks", "Ms", "Gs"]
    return _format(value, units, 1000.0)


def format_rate(value):
    units = ["tok/s", "ktok/s", "Mtok/s"]
    return _format(value, units, 1000.0)


def summary_line(byte_count, second_count, rate):
    return "%s\t%s\t%s" % (
        format_bytes(byte_count),
        format_seconds(second_count),
        format_rate(rate),
    )


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: report.py BYTES SECONDS RATE\n")
        return 2
    print(summary_line(float(argv[0]), float(argv[1]), float(argv[2])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
