"""Grade task-01-write: the spec in prompt.md, executed."""

import unittest

import duration


class ParseDurationTest(unittest.TestCase):
    def test_single_units(self):
        self.assertEqual(duration.parse_duration("90s"), 90)
        self.assertEqual(duration.parse_duration("2h"), 7200)
        self.assertEqual(duration.parse_duration("45m"), 2700)
        self.assertEqual(duration.parse_duration("0s"), 0)

    def test_combined_units(self):
        self.assertEqual(duration.parse_duration("1h30m"), 5400)
        self.assertEqual(duration.parse_duration("1h2m3s"), 3723)

    def test_surrounding_whitespace(self):
        self.assertEqual(duration.parse_duration(" 45m "), 2700)

    def test_multi_digit_groups(self):
        self.assertEqual(duration.parse_duration("120m"), 7200)

    def test_rejects_malformed(self):
        for text in ("", "   ", "10", "h", "1x", "1h2", "10m5", "1.5h", "-5s"):
            with self.assertRaises(ValueError, msg=text):
                duration.parse_duration(text)

    def test_rejects_repeated_unit(self):
        with self.assertRaises(ValueError):
            duration.parse_duration("1h2h")


if __name__ == "__main__":
    unittest.main()
