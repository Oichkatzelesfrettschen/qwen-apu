#!/usr/bin/env python3
"""Stand in for remote/web-mcp/drive-fallback-page.py in
remote/test-verify-lan-site.sh, so the web-search and image-generation turn
checks run without a headless Chromium. This fixture accepts the same flags
verify-lan-site.sh passes and prints the same report shape the real driver
does, over a canned transcript rather than a driven browser.

QWEN_FAKE_PAGE_DRIVER_FAIL_LANES names a comma-separated list of `--lane`
values ("web", "image") this run should fail for, so a test can prove the
check's own pass/fail reading without touching the fixture's happy path.
"""

import argparse
import json
import os
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--origin", required=True)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--broker", default="")
    parser.add_argument("--artifacts", default="")
    parser.add_argument("--lane", choices=("web", "image"), default="web")
    parser.add_argument("--model", default="")
    parser.add_argument("--review", action="store_true")
    parser.add_argument("--review-timeout", type=int, default=420)
    parser.add_argument("--review-correction", choices=("approve", "refuse"), default="refuse")
    parser.add_argument("--api-key-file", default="")
    parser.add_argument("--chromium", default="chromium")
    parser.add_argument("--load-timeout", type=int, default=180)
    parser.add_argument("--dialog-timeout", type=int, default=600)
    parser.add_argument("--turn-timeout", type=int, default=900)
    arguments = parser.parse_args()

    failing_lanes = set(
        filter(None, os.environ.get("QWEN_FAKE_PAGE_DRIVER_FAIL_LANES", "").split(","))
    )

    report = {
        "origin": arguments.origin,
        "model": "fixture-model",
        "history": [
            {"role": "user", "content": arguments.prompt},
            {"role": "assistant", "content": "fixture reply"},
        ],
        "requests": [
            {"url": arguments.origin + "/v1/chat/completions", "method": "POST",
             "body": None, "bodyKeys": None, "bodyModel": "fixture-model"},
        ],
        "imageStates": [],
        "imageCards": [],
        "selected_model_at_load": "fixture-model",
        "dialog": None,
        "review": None,
        "error": None,
    }

    if arguments.lane in failing_lanes:
        report["error"] = {"type": "FixtureFailure",
                            "message": "QWEN_FAKE_PAGE_DRIVER_FAIL_LANES named " + arguments.lane}
        json.dump(report, sys.stdout, indent=1)
        sys.stdout.write("\n")
        return 1

    if arguments.lane == "web":
        report["dialog"] = {
            "heading": "Approve web search",
            "note": "one search, one fetch",
            "args": {"query": arguments.prompt},
        }
        if arguments.broker:
            report["requests"].append(
                {"url": arguments.broker + "/grant", "method": "POST",
                 "body": None, "bodyKeys": ["profile_id", "query"], "bodyModel": None})
        report["requests"].append(
            {"url": arguments.origin + "/tools", "method": "POST",
             "body": None, "bodyKeys": ["tool", "params"], "bodyModel": "fixture-model"})
        report["history"].append({"role": "tool", "content": "search results fixture"})
    else:
        report["dialog"] = {
            "heading": "Approve image generation",
            "note": "one generation",
            "args": {"prompt": arguments.prompt},
        }
        if arguments.broker:
            report["requests"].append(
                {"url": arguments.broker + "/grant-image", "method": "POST",
                 "body": None, "bodyKeys": ["profile_id", "prompt"], "bodyModel": None})
        report["imageStates"] = ["Image ready"]
        report["imageCards"] = [{"caption": "fixture image", "src": "data:image/png;base64,"}]
        if arguments.artifacts:
            report["requests"].append(
                {"url": arguments.artifacts + "/artifacts/fixture.png", "method": "GET",
                 "body": None, "bodyKeys": None, "bodyModel": None})

    json.dump(report, sys.stdout, indent=1)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
