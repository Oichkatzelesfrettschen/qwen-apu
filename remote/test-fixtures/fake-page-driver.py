#!/usr/bin/env python3
"""Stand in for remote/web-mcp/drive-fallback-page.py: no browser, canned reports.

remote/run-conversational-web-arm.py calls its page driver once per row and
reads one JSON report from its stdout, in the shape
remote/web-mcp/drive-fallback-page.py prints. This fixture reproduces that
contract from a script rather than a browser: QWEN_FAKE_PAGE_DRIVER_REPORTS
names a JSON file holding an array of report objects, and
QWEN_FAKE_PAGE_DRIVER_STATE names a scratch file this fixture uses to track
how many times it has already been called. Each invocation pops the next
report by call order and prints it, so a test can script one canned turn per
suite row -- a proposed and approved search, a plain answer with no dialog, a
wrong answer, a transport error -- without a device or a browser.

Every other command-line argument is accepted and ignored, the same way
remote/test-fixtures/fake-router-server.py accepts and skips launch-chain
arguments it has no use for.
"""

import json
import os
import sys


def main():
    reports_path = os.environ["QWEN_FAKE_PAGE_DRIVER_REPORTS"]
    state_path = os.environ["QWEN_FAKE_PAGE_DRIVER_STATE"]
    with open(reports_path, encoding="utf-8") as handle:
        reports = json.load(handle)

    index = 0
    if os.path.exists(state_path):
        with open(state_path, encoding="utf-8") as handle:
            text = handle.read().strip()
        index = int(text) if text else 0

    if index >= len(reports):
        report = {"error": {"type": "FixtureExhausted",
                            "message": f"no canned report for call {index}"},
                  "history": [], "dialog": None, "selected_model_at_load": None}
    else:
        report = reports[index]

    with open(state_path, "w", encoding="utf-8") as handle:
        handle.write(str(index + 1))

    json.dump(report, sys.stdout)
    return 1 if report.get("error") else 0


if __name__ == "__main__":
    sys.exit(main())
