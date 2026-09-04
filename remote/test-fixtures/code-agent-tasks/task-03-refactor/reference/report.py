"""A hand-written answer to task-03-refactor, which proves the tests reachable."""

import sys


def _scaled(value, units, divisor):
    index = 0
    amount = float(value)
    while amount >= divisor and index < len(units) - 1:
        amount /= divisor
        index += 1
    if index == 0:
        return "%d %s" % (int(amount), units[index])
    return "%.2f %s" % (amount, units[index])


def format_bytes(value):
    return _scaled(value, ["B", "KiB", "MiB", "GiB", "TiB"], 1024.0)


def format_seconds(value):
    return _scaled(value, ["s", "ks", "Ms", "Gs"], 1000.0)


def format_rate(value):
    return _scaled(value, ["tok/s", "ktok/s", "Mtok/s"], 1000.0)


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
