"""A hand-written answer to task-01-write, which proves the tests reachable."""

import re

UNIT_SECONDS = {"h": 3600, "m": 60, "s": 1}
GROUP = re.compile(r"([0-9]+)([hms])")


def parse_duration(text):
    stripped = text.strip()
    if not stripped:
        raise ValueError("empty duration")
    total = 0
    seen = set()
    position = 0
    while position < len(stripped):
        match = GROUP.match(stripped, position)
        if match is None:
            raise ValueError("malformed duration: %r" % text)
        unit = match.group(2)
        if unit in seen:
            raise ValueError("repeated unit %r" % unit)
        seen.add(unit)
        total += int(match.group(1)) * UNIT_SECONDS[unit]
        position = match.end()
    return total
