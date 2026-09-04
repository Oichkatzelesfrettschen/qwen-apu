`report.py` repeats one scaling loop in `format_bytes`, `format_seconds`, and
`format_rate`, which differ only in their unit table and their divisor. Collapse
that duplication into a single private helper the three functions call, keeping
every public name, every argument, and every returned string exactly as the test
module pins them. The standard library alone stays available.

Answer with the complete refactored contents of `report.py` inside one fenced
code block marked `python`, and write no text outside that block.
