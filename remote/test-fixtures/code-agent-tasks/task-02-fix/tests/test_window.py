"""Grade task-02-fix: rolling_mean matches rolling_max in window count and content."""

import unittest

import window


class RollingMeanTest(unittest.TestCase):
    def test_window_count_matches_rolling_max(self):
        values = [1, 2, 3, 4, 5, 6]
        self.assertEqual(
            len(window.rolling_mean(values, 3)),
            len(window.rolling_max(values, 3)),
        )

    def test_means(self):
        self.assertEqual(window.rolling_mean([1, 2, 3, 4, 5], 3), [2.0, 3.0, 4.0])
        self.assertEqual(window.rolling_mean([2, 4, 6, 8], 2), [3.0, 5.0, 7.0])

    def test_size_one_returns_every_value(self):
        self.assertEqual(window.rolling_mean([5, 7], 1), [5.0, 7.0])

    def test_size_equal_to_length(self):
        self.assertEqual(window.rolling_mean([1, 2, 3], 3), [2.0])

    def test_oversized_window_is_empty(self):
        self.assertEqual(window.rolling_mean([1, 2], 5), [])

    def test_rejects_nonpositive_size(self):
        with self.assertRaises(ValueError):
            window.rolling_mean([1, 2, 3], 0)

    def test_rolling_max_unchanged(self):
        self.assertEqual(window.rolling_max([1, 5, 2, 4], 2), [5, 5, 4])


if __name__ == "__main__":
    unittest.main()
