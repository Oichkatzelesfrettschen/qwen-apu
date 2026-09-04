def parse_duration(text: str) -> int:
    """Convert a duration string into whole seconds.

    The string is a sequence of one or more <integer><unit> groups
    with no separators, where the unit is one of 'h' (hours), 'm' (minutes),
    or 's' (seconds). Surrounding whitespace is ignored.

    Raises:
        ValueError: If the string is empty, contains invalid characters,
                   has a group missing its unit, has a unit missing its digits,
                   or has a unit that repeats.
    """
    text = text.strip()
    if not text:
        raise ValueError("Empty string")

    units = {'h': 3600, 'm': 60, 's': 1}
    seen = set()

    total = 0
    i = 0
    while i < len(text):
        if text[i].isspace():
            i += 1
            continue

        if not text[i].isdigit():
            raise ValueError(f"Invalid character '{text[i]}' at position {i}")

        start = i
        while i < len(text) and text[i].isdigit():
            i += 1
        if i == start:
            raise ValueError("Unit missing its digits")

        num = int(text[start:i])

        if i >= len(text):
            raise ValueError("Group missing its unit")

        unit_char = text[i]
        if unit_char not in units:
            raise ValueError(f"Invalid unit '{unit_char}' at position {i}")

        if unit_char in seen:
            raise ValueError(f"Unit '{unit_char}' repeats")

        seen.add(unit_char)
        total += num * units[unit_char]
        i += 1

    return total
