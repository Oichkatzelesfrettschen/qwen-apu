Write a Python module `duration.py` that exposes one function:

    parse_duration(text) -> int

It converts a duration string into whole seconds. The string is a sequence of
one or more `<integer><unit>` groups with no separators, where the unit is one
of `h` (hours), `m` (minutes), or `s` (seconds). Surrounding whitespace is
ignored. Examples:

    parse_duration("90s")    == 90
    parse_duration("1h30m")  == 5400
    parse_duration("2h")     == 7200
    parse_duration(" 45m ")  == 2700
    parse_duration("1h2m3s") == 3723
    parse_duration("0s")     == 0

The function raises `ValueError` for an empty string, for a string holding any
character outside digits and the three unit letters, for a group missing its
unit, for a unit missing its digits, and for a unit that repeats. It uses the
Python standard library alone.

Answer with the complete contents of `duration.py` inside one fenced code block
marked `python`, and write no text outside that block.
