"""A hand-written answer to task-02-fix, which proves the tests reachable."""


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
