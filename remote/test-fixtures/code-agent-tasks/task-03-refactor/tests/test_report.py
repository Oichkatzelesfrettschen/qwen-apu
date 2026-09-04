"""Grade task-03-refactor: the refactor preserves every observable output."""

import unittest

import report


class FormatTest(unittest.TestCase):
    def test_bytes(self):
        self.assertEqual(report.format_bytes(512), "512 B")
        self.assertEqual(report.format_bytes(2048), "2.00 KiB")
        self.assertEqual(report.format_bytes(1024 * 1024 * 3), "3.00 MiB")

    def test_seconds(self):
        self.assertEqual(report.format_seconds(12), "12 s")
        self.assertEqual(report.format_seconds(2500), "2.50 ks")

    def test_rate(self):
        self.assertEqual(report.format_rate(9), "9 tok/s")
        self.assertEqual(report.format_rate(1500), "1.50 ktok/s")

    def test_summary_line(self):
        self.assertEqual(
            report.summary_line(2048, 2500, 1500),
            "2.00 KiB\t2.50 ks\t1.50 ktok/s",
        )

    def test_main_rejects_wrong_argument_count(self):
        self.assertEqual(report.main([]), 2)

    def test_main_accepts_three_arguments(self):
        self.assertEqual(report.main(["2048", "2500", "1500"]), 0)


if __name__ == "__main__":
    unittest.main()
