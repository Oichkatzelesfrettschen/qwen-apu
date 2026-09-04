#!/usr/bin/env python3
"""Drive the graded suite's text rows through the served page, Web toggle on.

remote/run-quality-suite.py grades the API path directly; this grades the
served fallback page instead, because the page -- not the API -- is the
executor of a web search. Each row runs remote/web-mcp/drive-fallback-page.py
once, fresh: a new headless Chromium, the per-turn Web toggle turned on
before the prompt is sent, the one approval dialog a proposed search opens
auto-approved (mirroring remote/admit-web-router-live.sh), and the settled
reply read back out of the page's own transcript. A fresh page per row keeps
the row independent of prior turns in the same way remote/run-quality-suite.py
already sends one bare user message per row with no carried history; only
transport-level effects such as prefix reuse can move a row's answer, and both
arms run the suite's rows in the same order for that reason.

A row whose attachment is `image` or `tools` is out of scope: the page's turn
driver types one text prompt into the chat box and offers no path to attach an
image or declare a tool set, so grading it through this transport would
measure an unrelated failure. Those rows are recorded with
web_on="not_applicable" and excluded from every arithmetic total; every other
row -- including the `web_current` category's `web:` rows, which are exactly
what a web-on arm is expected to move -- runs through the page.

Per-row accounting separates three claims the transcript alone answers: a
search was proposed (the approval dialog opened), a search was approved (this
driver always approves the one dialog it sees, the way a human operator would
for an auto-admitted arm), and a search produced results (the retained `tool`
role message in the page's history carries no refusal marker). The graded
verdict comes from the same grade() this repository already applies to the
API path, read against the settled assistant reply the transcript holds after
the turn, imported from remote/run-quality-suite.py rather than reimplemented.
"""

import argparse
import importlib.util
import json
import os
import statistics
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))

# A tool-role message that reports a refusal or an unreached provider carries
# one of these phrases, which webui/index.html and remote/web-mcp/server.py
# both write on that path. A message present without one of them is read as a
# result the search produced.
REFUSAL_MARKERS = (
    "did not run", "refused", "grant", "expired", "exceeded", "not authorized",
    "unavailable", "error",
)


def load_quality_module(path):
    specification = importlib.util.spec_from_file_location("quality_suite", path)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def percentile(values, fraction):
    """The value at the given fraction under nearest-rank interpolation.

    llama-bench and this repository's other summarizers report p90 the same
    way, so a reader comparing this arm's timing against those figures reads
    one convention rather than two.
    """
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = fraction * (len(ordered) - 1)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


def last_assistant_content(history):
    """The settled reply the page appended after the turn.

    A turn that proposed and ran a search appends a `tool` role message
    ahead of the closing assistant reply, so the last assistant entry is what
    the model wrote after reading any result -- the same thing the API path's
    single response content is.
    """
    for entry in reversed(history or []):
        if entry.get("role") == "assistant":
            content = entry.get("content")
            if isinstance(content, str):
                return content
            if isinstance(content, list):
                return "".join(
                    part.get("text", "") for part in content
                    if isinstance(part, dict))
    return ""


def tool_result_produced(history):
    """Whether a retained tool-role message reads as a delivered result.

    The page never exposes an HTTP status to this driver, so the message text
    itself is what separates a spent grant that returned sources from one the
    broker, the provider, or the fetch budget refused.
    """
    tool_messages = [entry for entry in (history or []) if entry.get("role") == "tool"]
    if not tool_messages:
        return False
    text = " ".join(str(entry.get("content", "")) for entry in tool_messages).lower()
    if not text.strip():
        return False
    return not any(marker in text for marker in REFUSAL_MARKERS)


def run_row(page_driver, chromium, origin, profile_id, prompt, broker_origin,
            api_key_file, load_timeout, dialog_timeout, turn_timeout):
    argv = [
        page_driver, "--origin", origin, "--prompt", prompt, "--model", profile_id,
        "--dialog-optional", "--load-timeout", str(load_timeout),
        "--dialog-timeout", str(dialog_timeout), "--turn-timeout", str(turn_timeout),
        "--chromium", chromium,
    ]
    if broker_origin:
        argv += ["--broker", broker_origin]
    if api_key_file:
        argv += ["--api-key-file", api_key_file]
    started = time.monotonic()
    completed = subprocess.run(argv, capture_output=True, text=True, timeout=turn_timeout + load_timeout + 60)
    wall_seconds = time.monotonic() - started
    try:
        report = json.loads(completed.stdout)
    except (ValueError, TypeError):
        report = {"error": {"type": "DriverOutputError",
                            "message": f"stdout did not parse as JSON: "
                                       f"{completed.stdout[:300]!r} stderr={completed.stderr[:300]!r}"}}
    return report, wall_seconds


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("origin", help="router origin the page is served from")
    parser.add_argument("profile_id", help="the served web section's model id")
    parser.add_argument("output_json")
    parser.add_argument("--suite", default=os.path.join(HERE, "quality-suite.tsv"))
    parser.add_argument("--categories", default="",
                        help="comma-separated subset; empty runs every eligible row")
    parser.add_argument("--long-context-characters", type=int, default=24000)
    parser.add_argument("--page-driver",
                        default=os.path.join(HERE, "web-mcp", "drive-fallback-page.py"))
    parser.add_argument("--broker-origin", default="")
    parser.add_argument("--api-key-file", default="")
    parser.add_argument("--load-timeout", type=int, default=180)
    parser.add_argument("--dialog-timeout", type=int, default=300)
    parser.add_argument("--turn-timeout", type=int, default=300)
    parser.add_argument("--chromium", default="chromium")
    arguments = parser.parse_args(argv[1:])

    quality_suite = load_quality_module(
        os.path.join(HERE, "run-quality-suite.py"))
    rows = quality_suite.load_suite(arguments.suite)
    if arguments.categories:
        wanted = set(arguments.categories.split(","))
        rows = [row for row in rows if row["category"] in wanted]
    if not rows:
        raise SystemExit("no suite rows selected")

    records = []
    skipped = []
    for row in rows:
        kind, _ = quality_suite.parse_attachment(row.get("attachment"))
        if kind in ("image", "tools"):
            skipped.append({"id": row["id"], "category": row["category"],
                            "attachment": row.get("attachment", "-"),
                            "reason": f"attachment kind {kind} has no transport "
                                      "through the served page's turn driver"})
            continue

        prompt = row["prompt"]
        if row["category"] == "long_context":
            prompt = quality_suite.pad_prompt(prompt, arguments.long_context_characters)

        report, wall_seconds = run_row(
            arguments.page_driver, arguments.chromium, arguments.origin,
            arguments.profile_id, prompt, arguments.broker_origin,
            arguments.api_key_file, arguments.load_timeout,
            arguments.dialog_timeout, arguments.turn_timeout)

        error = report.get("error")
        history = report.get("history") or []
        dialog = report.get("dialog")
        content = last_assistant_content(history)
        search_proposed = dialog is not None
        search_approved = search_proposed
        results_produced = tool_result_produced(history) if search_proposed else False

        if error:
            passed, reason = False, f"{error.get('type', 'Error')}: {error.get('message', '')}"
        elif not content.strip():
            passed, reason = False, "empty reply"
        else:
            passed, reason = quality_suite.grade(row, content, truncated=False, tool_calls=())

        records.append({
            "id": row["id"],
            "category": row["category"],
            "grader": row["grader"],
            "expectation": row["expectation"],
            "attachment": row.get("attachment", "-"),
            "profile_id": arguments.profile_id,
            "selected_model_at_load": report.get("selected_model_at_load"),
            "passed": bool(passed),
            "reason": reason,
            "empty_answer": not content.strip(),
            "error": None if not error else f"{error.get('type', 'Error')}: {error.get('message', '')}",
            "content": content,
            "dialog": dialog,
            "search_proposed": search_proposed,
            "search_approved": search_approved,
            "results_produced": results_produced,
            "wall_seconds": wall_seconds,
        })
        print(f"row={row['id']} category={row['category']} "
              f"search_proposed={search_proposed} approved={search_approved} "
              f"results_produced={results_produced} passed={bool(passed)} "
              f"reason={reason}", flush=True)

    by_category = {}
    for record in records:
        bucket = by_category.setdefault(
            record["category"], {"attempted": 0, "passed": 0, "empty": 0})
        bucket["attempted"] += 1
        bucket["passed"] += int(record["passed"])
        bucket["empty"] += int(record["empty_answer"])

    completed_records = [r for r in records if not r["error"] and not r["empty_answer"]]
    served_models = sorted({
        r["selected_model_at_load"] for r in records if r["selected_model_at_load"]})
    proposed = [r for r in records if r["search_proposed"]]
    wall_seconds_list = [r["wall_seconds"] for r in records if r["wall_seconds"] is not None]

    summary = {
        "rows": len(records),
        "rows_skipped": len(skipped),
        "profile_id": arguments.profile_id,
        "served_models": served_models,
        "passed": sum(r["passed"] for r in records),
        "empty_answer_rate": (
            sum(r["empty_answer"] for r in records) / len(records) if records else None),
        "correct_on_completed": (
            sum(r["passed"] for r in completed_records) / len(completed_records)
            if completed_records else None),
        "tool_proposal_rate": len(proposed) / len(records) if records else None,
        "approvals": sum(r["search_approved"] for r in records),
        "results_produced": sum(r["results_produced"] for r in records),
        "mean_wall_seconds": statistics.fmean(wall_seconds_list) if wall_seconds_list else None,
        "p90_wall_seconds": percentile(wall_seconds_list, 0.9),
        "by_category": by_category,
        "transport_errors": sum(bool(r["error"]) for r in records),
    }

    with open(arguments.output_json, "w") as handle:
        json.dump({"summary": summary, "records": records, "skipped": skipped}, handle, indent=2)

    for name in sorted(by_category):
        bucket = by_category[name]
        print(f"category={name} passed={bucket['passed']}/{bucket['attempted']} "
              f"empty={bucket['empty']}")
    print(f"skipped_rows={len(skipped)} (image/tools attachment kinds)")
    transport_errors = summary["transport_errors"]
    terminal_state = "completed" if transport_errors == 0 else "failed"
    print(f"conversational_web_arm={terminal_state} passed={summary['passed']}/{summary['rows']} "
          f"tool_proposal_rate={summary['tool_proposal_rate']} "
          f"approvals={summary['approvals']} results_produced={summary['results_produced']} "
          f"transport_errors={transport_errors}")
    return 0 if transport_errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
