#!/usr/bin/env python3
"""Check the conversational suite's pure-Python pieces without a device.

remote/resolve-web-profile.py, remote/run-conversational-web-arm.py, and
remote/summarize-conversational-suite.py carry the logic
remote/run-conversational-suite.sh assembles: the ledger join that decides
whether a web-on arm can run at all, the per-row approval accounting and
grading that arm applies to the served page's settled reply, and the
arithmetic (mean, p90, paired delta) the final report states. Each is
checkable against a script or a fixture without a browser or a listener, and
this exercises all three; remote/test-run-conversational-suite.sh drives the
shell orchestrator itself end to end against
remote/test-fixtures/fake-chat-router.py.
"""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(HERE, "test-fixtures")


def load_module(name, path):
    specification = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


resolve_module = load_module("resolve_web_profile", os.path.join(HERE, "resolve-web-profile.py"))
web_arm_module = load_module("run_conversational_web_arm", os.path.join(HERE, "run-conversational-web-arm.py"))
summarize_module = load_module("summarize_conversational_suite", os.path.join(HERE, "summarize-conversational-suite.py"))

failures = 0


def fail(message):
    global failures
    failures += 1
    print(f"FAIL: {message}", file=sys.stderr)


# --- resolve-web-profile.py: every reason and the one success path --------

LEDGER_ROWS = "\n".join((
    "refused-profile\tmodel-refused\tvalidator-gated\t8192\t8192\t5\t2\t12000\tyes\tno\t9/10\trefused\tsearxng\tqwen-open\t-\t1\thttp://127.0.0.1:8888",
    "ui-profile\tmodel-ui\tui-mediated\t8192\t8192\t5\t2\t12000\tno\tno\t9/10\tui-mediated\tsearxng\tqwen-open\t-\t1\thttp://127.0.0.1:8888",
    "not-ready-profile\tmodel-not-ready\tvalidator-gated\t8192\t8192\t5\t2\t12000\tyes\tno\t9/10\tvalidator-gated\tsearxng\tqwen-open\t-\t1\thttp://127.0.0.1:8888",
    "ready-profile\tmodel-ready\tvalidator-gated\t8192\t8192\t5\t2\t12000\tyes\tno\t9/10\tvalidator-gated\tsearxng\tqwen-open\t-\t1\thttp://127.0.0.1:8888",
))

with tempfile.TemporaryDirectory() as directory:
    ledger_path = os.path.join(directory, "web-profiles.tsv")
    with open(ledger_path, "w", encoding="utf-8") as handle:
        handle.write("# fixture ledger, one row per reason\n" + LEDGER_ROWS + "\n")

    CASES = (
        ("model-absent", "", ("unavailable", "no_web_profile")),
        ("model-refused", "", ("unavailable", "execution_policy_refused")),
        ("model-ui", "", ("unavailable", "ui_mediated_no_tools")),
        ("model-not-ready", "", ("unavailable", "authorizer_not_ready")),
        ("model-not-ready", "not-ready-profile", ("available", "not-ready-profile")),
        ("model-ready", "ready-profile", ("available", "ready-profile")),
    )
    for model_id, served, expected in CASES:
        rows = resolve_module.load_ledger(ledger_path)
        served_ids = {part for part in served.split(",") if part}
        status, second, _third = resolve_module.resolve(model_id, rows, served_ids)
        if (status, second) != expected:
            fail(f"resolve({model_id!r}, served={served!r}) = "
                 f"{(status, second)!r}, want {expected!r}")

    # The CLI prints the same three fields tab-separated.
    completed = subprocess.run(
        [sys.executable, os.path.join(HERE, "resolve-web-profile.py"),
         "model-ready", "--ledger", ledger_path, "--served-ids", "ready-profile"],
        capture_output=True, text=True, check=True)
    if completed.stdout.strip() != "available\tready-profile\t2":
        fail(f"resolve-web-profile.py CLI printed {completed.stdout!r}")


# --- run-conversational-web-arm.py: accounting and grading -----------------

with tempfile.TemporaryDirectory() as directory:
    suite_path = os.path.join(directory, "suite.tsv")
    with open(suite_path, "w", encoding="utf-8") as handle:
        handle.write(
            "wc-01\tweb_current\tcontains_all\t2025-08-09\t"
            "On what date was Debian 13 released? Reply in YYYY-MM-DD form and "
            "nothing else.\tweb:\n"
            "screen-01\tscreen\tnumeric\t9.9\tWhich is larger, 9.11 or 9.9?\t-\n"
            "screen-02\tscreen\tnumeric\t4\tWhat is 2 plus 2?\t-\n"
            "vis-01\tvision\tcontains_all\tred\tName the colour.\timage:shapes\n"
        )

    reports = [
        # wc-01: a search was proposed, approved, produced a result, and the
        # settled reply carries the correct date.
        {
            "error": None,
            "dialog": {"heading": "Approve web search", "note": "", "args": {"query": "Debian 13 release date"}},
            "history": [
                {"role": "user", "content": "..."},
                {"role": "tool", "content": "Sources: debian.org - Debian 13 Trixie released 2025-08-09."},
                {"role": "assistant", "content": "It was released on 2025-08-09."},
            ],
            "selected_model_at_load": "web-open",
        },
        # screen-01: no dialog opened, and the answer is correct.
        {
            "error": None,
            "dialog": None,
            "history": [
                {"role": "user", "content": "..."},
                {"role": "assistant", "content": "9.9 is larger."},
            ],
            "selected_model_at_load": "web-open",
        },
        # screen-02: no dialog, wrong answer.
        {
            "error": None,
            "dialog": None,
            "history": [
                {"role": "user", "content": "..."},
                {"role": "assistant", "content": "The answer is 5."},
            ],
            "selected_model_at_load": "web-open",
        },
        # vis-01 is skipped for its image attachment and never reaches the
        # fixture, so only three reports are needed.
    ]
    reports_path = os.path.join(directory, "reports.json")
    with open(reports_path, "w", encoding="utf-8") as handle:
        json.dump(reports, handle)
    state_path = os.path.join(directory, "state.txt")

    output_json = os.path.join(directory, "web-on.json")
    environment = dict(os.environ)
    environment["QWEN_FAKE_PAGE_DRIVER_REPORTS"] = reports_path
    environment["QWEN_FAKE_PAGE_DRIVER_STATE"] = state_path
    completed = subprocess.run(
        [sys.executable, os.path.join(HERE, "run-conversational-web-arm.py"),
         "http://127.0.0.1:1", "web-open", output_json,
         "--suite", suite_path,
         "--page-driver", os.path.join(FIXTURES, "fake-page-driver.py")],
        capture_output=True, text=True, env=environment)
    if completed.returncode != 0:
        fail(f"run-conversational-web-arm.py exited {completed.returncode}: "
             f"{completed.stdout}\n{completed.stderr}")

    with open(output_json, encoding="utf-8") as handle:
        document = json.load(handle)
    summary = document["summary"]
    records = {record["id"]: record for record in document["records"]}

    if summary["rows"] != 3:
        fail(f"web-arm summary counted {summary['rows']} rows, want 3 (vis-01 skipped)")
    if summary["rows_skipped"] != 1:
        fail(f"web-arm summary counted {summary['rows_skipped']} skipped rows, want 1")
    if document["skipped"] != [{
        "id": "vis-01", "category": "vision", "attachment": "image:shapes",
        "reason": "attachment kind image has no transport through the served "
                  "page's turn driver",
    }]:
        fail(f"skipped row detail disagrees: {document['skipped']}")

    if not records["wc-01"]["search_proposed"] or not records["wc-01"]["search_approved"]:
        fail(f"wc-01 did not record a proposed and approved search: {records['wc-01']}")
    if not records["wc-01"]["results_produced"]:
        fail(f"wc-01 did not record a produced result: {records['wc-01']}")
    if not records["wc-01"]["passed"]:
        fail(f"wc-01 was graded wrong: {records['wc-01']}")
    if records["screen-01"]["search_proposed"] or records["screen-02"]["search_proposed"]:
        fail("a row with no dialog was counted as proposing a search")
    if not records["screen-01"]["passed"]:
        fail(f"screen-01 was graded wrong: {records['screen-01']}")
    if records["screen-02"]["passed"]:
        fail(f"screen-02 was graded as passing an incorrect reply: {records['screen-02']}")

    if summary["tool_proposal_rate"] != 1 / 3:
        fail(f"tool_proposal_rate = {summary['tool_proposal_rate']}, want 1/3")
    if summary["approvals"] != 1:
        fail(f"approvals = {summary['approvals']}, want 1")
    if summary["results_produced"] != 1:
        fail(f"results_produced = {summary['results_produced']}, want 1")
    if summary["correct_on_completed"] != 2 / 3:
        fail(f"correct_on_completed = {summary['correct_on_completed']}, want 2/3 "
             "(wc-01 and screen-01 pass, screen-02 fails)")

# A row whose dialog never opens and whose driver reports a transport error
# ends up refused rather than silently graded pass, and the arm reports
# failed exit status.
with tempfile.TemporaryDirectory() as directory:
    suite_path = os.path.join(directory, "suite.tsv")
    with open(suite_path, "w", encoding="utf-8") as handle:
        handle.write("term-01\ttermination\tnonempty\t\tSay something.\t-\n")
    reports_path = os.path.join(directory, "reports.json")
    with open(reports_path, "w", encoding="utf-8") as handle:
        json.dump([{"error": {"type": "TimeoutError", "message": "the page never loaded"},
                    "dialog": None, "history": [], "selected_model_at_load": None}], handle)
    state_path = os.path.join(directory, "state.txt")
    output_json = os.path.join(directory, "web-on.json")
    environment = dict(os.environ)
    environment["QWEN_FAKE_PAGE_DRIVER_REPORTS"] = reports_path
    environment["QWEN_FAKE_PAGE_DRIVER_STATE"] = state_path
    completed = subprocess.run(
        [sys.executable, os.path.join(HERE, "run-conversational-web-arm.py"),
         "http://127.0.0.1:1", "web-open", output_json,
         "--suite", suite_path,
         "--page-driver", os.path.join(FIXTURES, "fake-page-driver.py")],
        capture_output=True, text=True, env=environment)
    if completed.returncode == 0:
        fail("a transport error in the web-on arm returned success")
    with open(output_json, encoding="utf-8") as handle:
        document = json.load(handle)
    if document["records"][0]["passed"]:
        fail("a transport error was graded as a pass")
    if document["summary"]["transport_errors"] != 1:
        fail(f"transport_errors = {document['summary']['transport_errors']}, want 1")


# --- summarize-conversational-suite.py: mean, p90, and the paired delta ----

with tempfile.TemporaryDirectory() as directory:
    def write_json(path, records, extra_summary=None):
        by_category = {}
        for record in records:
            bucket = by_category.setdefault(
                record["category"], {"attempted": 0, "passed": 0, "empty": 0})
            bucket["attempted"] += 1
            bucket["passed"] += int(record["passed"])
        completed = [r for r in records if not r.get("error")]
        summary = {
            "rows": len(records),
            "correct_on_completed": (sum(r["passed"] for r in completed) / len(completed)
                                     if completed else None),
            "by_category": by_category,
        }
        if extra_summary:
            summary.update(extra_summary)
        with open(path, "w", encoding="utf-8") as handle:
            json.dump({"summary": summary, "records": records}, handle)

    off_records = [
        {"id": "screen-01", "category": "screen", "passed": True, "wall_seconds": 1.0, "error": None},
        {"id": "screen-02", "category": "screen", "passed": False, "wall_seconds": 2.0, "error": None},
        {"id": "wc-01", "category": "web_current", "passed": False, "wall_seconds": 3.0, "error": None},
        {"id": "wc-02", "category": "web_current", "passed": False, "wall_seconds": 4.0, "error": None},
    ]
    off_path = os.path.join(directory, "off.json")
    write_json(off_path, off_records)

    on_records = [
        {"id": "screen-01", "category": "screen", "passed": True, "wall_seconds": 5.0, "error": None},
        {"id": "wc-01", "category": "web_current", "passed": True, "wall_seconds": 20.0, "error": None},
        {"id": "wc-02", "category": "web_current", "passed": True, "wall_seconds": 10.0, "error": None},
    ]
    on_path = os.path.join(directory, "on.json")
    write_json(on_path, on_records, {
        "tool_proposal_rate": 2 / 3, "approvals": 2, "results_produced": 2, "rows_skipped": 1})

    manifest_path = os.path.join(directory, "manifest.tsv")
    with open(manifest_path, "w", encoding="utf-8") as handle:
        handle.write("model_id\tweb_off_json\tweb_on_status\tweb_on_reason\tweb_on_json\n")
        handle.write(f"fixture-model\t{off_path}\tcompleted\t-\t{on_path}\n")

    output_directory = os.path.join(directory, "output")
    os.makedirs(output_directory)
    completed = subprocess.run(
        [sys.executable, os.path.join(HERE, "summarize-conversational-suite.py"),
         manifest_path, output_directory],
        capture_output=True, text=True)
    if completed.returncode != 0:
        fail(f"summarize-conversational-suite.py exited {completed.returncode}: "
             f"{completed.stdout}\n{completed.stderr}")

    with open(os.path.join(output_directory, "conversational-summary.tsv"), encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    header = lines[0].split("\t")
    values = dict(zip(header, lines[1].split("\t")))

    # web-off: correct_on_completed = 1/4; wall seconds [1,2,3,4], p90 by
    # nearest-rank interpolation lands at 3 + 0.7*(4-3) = 3.7.
    if values["web_off_correct_on_completed"] != "0.250":
        fail(f"web_off_correct_on_completed = {values['web_off_correct_on_completed']}, want 0.250")
    if values["web_off_mean_wall"] != "2.50":
        fail(f"web_off_mean_wall = {values['web_off_mean_wall']}, want 2.50")
    if values["web_off_p90_wall"] != "3.70":
        fail(f"web_off_p90_wall = {values['web_off_p90_wall']}, want 3.70")

    # web-on: correct_on_completed = 3/3 = 1.000; only 3 rows ran (one
    # skipped for its image attachment upstream, already excluded here).
    if values["web_on_correct_on_completed"] != "1.000":
        fail(f"web_on_correct_on_completed = {values['web_on_correct_on_completed']}, want 1.000")
    if values["tool_proposal_rate"] != "0.667":
        fail(f"tool_proposal_rate = {values['tool_proposal_rate']}, want 0.667")
    if values["approvals"] != "2":
        fail(f"approvals = {values['approvals']}, want 2")

    # Paired ids: screen-01 (0 -> +1... wait, both pass, delta 0), wc-01
    # (False -> True, +1), wc-02 (False -> True, +1). screen-02 ran in
    # web-off alone and is excluded from the pairing.
    if values["paired_count"] != "3":
        fail(f"paired_count = {values['paired_count']}, want 3 (screen-02 excluded)")
    if values["paired_delta_mean"] != "0.667":
        fail(f"paired_delta_mean = {values['paired_delta_mean']}, want 0.667 "
             "((0 + 1 + 1) / 3)")

    with open(os.path.join(output_directory, "conversational-summary.md"), encoding="utf-8") as handle:
        markdown = handle.read()
    if "fixture-model" not in markdown or "paired_delta_mean" not in markdown:
        fail("markdown report is missing the model row or its header")


if failures:
    print(f"conversational_suite_units=rejected failures={failures}", file=sys.stderr)
    sys.exit(1)
print("conversational_suite_units=accepted")
