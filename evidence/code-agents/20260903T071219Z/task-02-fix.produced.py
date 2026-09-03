"""Rolling window statistics over a list of numbers.

The fixture ships this module broken on purpose: rolling_mean drops the newest
sample from every window and returns one window too few, so the paired test
module fails. task-02-fix asks a model to repair it.
"""


def rolling_mean(values, size):
    if size <= 0:
        raise ValueError("size must be positive")
    if size > len(values):
        return []
    means = []
    for start in range(len(values) - size + 1):
        window = values[start:start + size]
        means.append(sum(window) / len(window))
    return means


def rolling_max(values, size):
    if size <= 0:
        raise ValueError("size must be positive")
    if size > len(values):
        return []
    return [max(values[start:start + size]) for start in range(len(values) - size + 1)]
