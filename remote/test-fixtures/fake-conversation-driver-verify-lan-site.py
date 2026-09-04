#!/usr/bin/env python3
"""Stand in for the conversation-restoration driver
remote/verify-lan-site.sh generates, so remote/test-verify-lan-site.sh proves
the check's own reading of a driver report without a headless Chromium.

QWEN_FAKE_CONVERSATION_DRIVER_FAIL=1 reports a mismatch after reload, so a
test can prove the check fails on a driver that read one.
"""

import argparse
import json
import os
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--origin", required=True)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--api-key-file", default="")
    parser.add_argument("--chromium", default="chromium")
    parser.add_argument("--load-timeout", type=int, default=180)
    parser.add_argument("--turn-timeout", type=int, default=300)
    arguments = parser.parse_args()

    fail = os.environ.get("QWEN_FAKE_CONVERSATION_DRIVER_FAIL") == "1"
    report = {
        "conversation_id": "fixture-conversation-id",
        "title": arguments.prompt[:40],
        "message_count_before_reload": 2,
        "error": None,
    }
    if fail:
        report["conversation_id_after_reload"] = "fixture-conversation-id"
        report["message_count_after_reload"] = 0
        report["listed_after_reload"] = False
        report["id_matches"] = True
        report["messages_match"] = False
    else:
        report["conversation_id_after_reload"] = "fixture-conversation-id"
        report["message_count_after_reload"] = 2
        report["listed_after_reload"] = True
        report["id_matches"] = True
        report["messages_match"] = True

    json.dump(report, sys.stdout, indent=1)
    sys.stdout.write("\n")
    # A field mismatch is not an exception, the way the real driver's own
    # `report["error"]` stays null on a completed run whose fields simply
    # disagree; the check reads those fields rather than the exit status.
    return 0


if __name__ == "__main__":
    sys.exit(main())
