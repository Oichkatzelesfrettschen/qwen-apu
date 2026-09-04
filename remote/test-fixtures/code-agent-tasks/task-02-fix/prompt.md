`window.py` fails its test module. `rolling_mean` returns fewer windows than
`rolling_max` over the same input and averages the wrong samples; `rolling_max`
is correct and stays as it is. Repair `rolling_mean` so every test passes,
keeping both public names and the `ValueError` on a non-positive size.

Answer with the complete repaired contents of `window.py` inside one fenced code
block marked `python`, and write no text outside that block.
