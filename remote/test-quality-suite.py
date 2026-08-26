#!/usr/bin/env python3
"""Check every grader against replies whose verdict is known.

A grader that silently accepts everything reports a perfect candidate, so each
kind is exercised with one reply it must accept and one it must refuse. The
suite file is checked for well-formed rows in the same run, because a row with
the wrong field count fails at measurement time rather than here.
"""

import contextlib
import io
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util

spec = importlib.util.spec_from_file_location(
    "quality_suite",
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "run-quality-suite.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

CASES = [
    ("numeric", "3168", "The product is 3168.", True),
    ("numeric", "3168", "The product is 3167.", False),
    ("numeric", "3168", "I cannot say.", False),
    ("numeric", "-11", "7 - 3*6 = 7 - 18 = -11", True),
    ("numeric", "2540", "That is 2,540 millimetres.", True),
    ("contains_all", "2|45", "The trip takes 2 hours and 45 minutes.", True),
    ("contains_all", "2|45", "The trip takes 2 hours.", False),
    ("contains_any", "off-by-one|<=", "It is an off-by-one error.", True),
    ("contains_any", "off-by-one|<=", "The loop is fine.", False),
    ("json_keys", "name|age", '{"name": "Ada", "age": 36}', True),
    ("json_keys", "name|age", '{"name": "Ada"}', False),
    ("json_keys", "name|age", 'Sure! {"name": "Ada", "age": 36}', False),
    ("json_keys", "name|age", '```json\n{"name": "Ada", "age": 36}\n```', False),
    ("json_keys", "name|age", '{"name": NaN, "age": 36}', False),
    ("json_keys", "name|age", '{"name": Infinity, "age": 36}', False),
    ("json_keys", "name|age", '{"name": -Infinity, "age": 36}', False),
    ("json_keys", "items", '[1, 2, 3]', False),
    ("regex", r"^\s*(yes|no)\s*[.!]?\s*$", "yes", True),
    ("regex", r"^\s*(yes|no)\s*[.!]?\s*$", "Yes, 12 is divisible by 4.", False),
    ("regex", r"^\s*\d{4}-\d{2}-\d{2}\s*$", "2024-02-29", True),
    ("regex", r"^\s*\d{4}-\d{2}-\d{2}\s*$", "29 February 2024", False),
    ("nonempty", "", "Any answer at all.", True),
    ("nonempty", "", "   \n  ", False),
]

failures = 0
for kind, expectation, reply, expected in CASES:
    row = {"grader": kind, "expectation": expectation}
    passed, reason = module.grade(row, reply)
    if passed != expected:
        print(f"grader={kind} expectation={expectation!r} reply={reply!r} "
              f"expected={expected} got={passed} reason={reason}",
              file=sys.stderr)
        failures += 1

suite_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "quality-suite.tsv")
rows = module.load_suite(suite_path)
identifiers = [row["id"] for row in rows]
if len(set(identifiers)) != len(identifiers):
    print("suite holds duplicate identifiers", file=sys.stderr)
    failures += 1
known = {"numeric", "contains_all", "contains_any", "json_keys", "regex", "nonempty"}
for row in rows:
    if row["grader"] not in known:
        print(f"{row['id']}: unknown grader {row['grader']}", file=sys.stderr)
        failures += 1
    if row["grader"] != "nonempty" and not row["expectation"]:
        print(f"{row['id']}: grader {row['grader']} carries no expectation",
              file=sys.stderr)
        failures += 1
    if not row["prompt"].strip():
        print(f"{row['id']}: empty prompt", file=sys.stderr)
        failures += 1

# The fact lands inside the filler and the question lands last, which is what
# makes a long-context row a retrieval test rather than a longer prompt. A fact
# left adjacent to its question is answerable from the final sentence alone.
padded = module.pad_prompt("FACT ||| QUESTION", 4000)
if len(padded) < 4000:
    print(f"padding produced {len(padded)} characters", file=sys.stderr)
    failures += 1
if not padded.endswith("QUESTION"):
    print("padding left the question away from the end", file=sys.stderr)
    failures += 1
if "FACT QUESTION" in padded or padded.index("FACT") > padded.index("QUESTION"):
    print("padding left the fact adjacent to the question", file=sys.stderr)
    failures += 1
gap = padded.index("QUESTION") - (padded.index("FACT") + len("FACT"))
if gap < 1000:
    print(f"padding left only {gap} characters between fact and question",
          file=sys.stderr)
    failures += 1
if module.pad_prompt("FACT ||| QUESTION", 0) != "FACT QUESTION":
    print("unpadded long-context prompt kept its separator", file=sys.stderr)
    failures += 1

# Every long_context row must carry the separator, or its fact stays welded to
# its question and the category silently stops testing retrieval.
for row in rows:
    if row["category"] == "long_context" and module.NEEDLE_SEPARATOR not in row["prompt"]:
        print(f"{row['id']}: long_context row holds no fact separator",
              file=sys.stderr)
        failures += 1


def synthetic_document(content, finish_reason="stop"):
    return {
        "choices": [{
            "message": {"content": content, "reasoning_content": ""},
            "finish_reason": finish_reason,
        }],
        "timings": {
            "predicted_n": 1,
            "prompt_n": 1,
            "predicted_per_second": 1.0,
        },
        "_wall_seconds": 1.0,
    }


# The retained reply is the object that the grader reads. Truncating only the
# JSON evidence makes a later re-grade unable to reproduce the recorded verdict.
with tempfile.TemporaryDirectory() as temporary_directory:
    suite = os.path.join(temporary_directory, "suite.tsv")
    output = os.path.join(temporary_directory, "result.json")
    with open(suite, "w") as handle:
        handle.write(
            "wrong\tscreen\tnumeric\t1\tFirst prompt\n"
            "truncated\tscreen\tnumeric\t1\tSecond prompt\n"
            "long-reply\tscreen\tnonempty\t\tThird prompt\n")
    documents = iter((
        synthetic_document("2"),
        synthetic_document("1", finish_reason="length"),
        synthetic_document("x" * 700),
    ))
    original_request = module.request
    module.request = lambda *args, **kwargs: next(documents)
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            status = module.main(("run-quality-suite.py", "http://fixture", output,
                                  "--suite", suite))
    finally:
        module.request = original_request
    with open(output) as handle:
        result = json.load(handle)
    if status != 0:
        print("synthetic quality run returned failure", file=sys.stderr)
        failures += 1
    if result["records"][2]["content"] != "x" * 700:
        print("quality evidence truncated the reply used for grading",
              file=sys.stderr)
        failures += 1
    if result["summary"]["completion_rate"] != 2 / 3:
        print("truncated reply counted as completed", file=sys.stderr)
        failures += 1
    if result["summary"]["correct_on_completed"] != 0.5:
        print("truncated reply entered completed-row accuracy", file=sys.stderr)
        failures += 1

# A reset is one row's transport result, not an exception that prevents the
# remaining suite and its summary JSON from being retained.
with tempfile.TemporaryDirectory() as temporary_directory:
    suite = os.path.join(temporary_directory, "suite.tsv")
    output = os.path.join(temporary_directory, "result.json")
    with open(suite, "w") as handle:
        handle.write("reset\tscreen\tnonempty\t\tPrompt\n")
    original_request = module.request
    module.request = lambda *args, **kwargs: (_ for _ in ()).throw(
        ConnectionResetError("fixture reset"))
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            status = module.main(("run-quality-suite.py", "http://fixture", output,
                                  "--suite", suite))
    finally:
        module.request = original_request
    with open(output) as handle:
        result = json.load(handle)
    if status != 1 or "fixture reset" not in result["records"][0]["error"]:
        print("connection reset did not become a retained transport failure",
              file=sys.stderr)
        failures += 1

# Selecting a retrieval row without a real depth is an invocation error. The
# suite never silently degrades that category into short recall.
with tempfile.TemporaryDirectory() as temporary_directory:
    suite = os.path.join(temporary_directory, "suite.tsv")
    output = os.path.join(temporary_directory, "result.json")
    with open(suite, "w") as handle:
        handle.write(
            "long\tlong_context\tcontains_all\tneedle\t"
            "needle ||| What is the needle?\n")
    try:
        with contextlib.redirect_stderr(io.StringIO()):
            module.main(("run-quality-suite.py", "http://fixture", output,
                         "--suite", suite))
    except SystemExit as error:
        if error.code != 2:
            print(f"missing long-context depth exited {error.code}, expected 2",
                  file=sys.stderr)
            failures += 1
    else:
        print("quality suite accepted long-context rows without a real depth",
              file=sys.stderr)
        failures += 1

# A grader that accepts a reply carrying no answer is a no-op, and a no-op
# grader reports a perfect candidate. Every row except the termination category,
# which grades presence rather than content, must refuse this.
REFUSAL = "I am not able to answer that question right now."
for row in rows:
    if row["grader"] == "nonempty":
        continue
    passed, reason = module.grade(row, REFUSAL)
    if passed:
        print(f"{row['id']}: grader {row['grader']} accepted a reply with no "
              f"answer ({reason})", file=sys.stderr)
        failures += 1

# `$` under re.MULTILINE matches at every line end, so an unanchored pattern
# accepts a compliant line inside a reply that violated the instruction.
for row in rows:
    if row["grader"] == "regex" and not row["expectation"].startswith("\\A"):
        print(f"{row['id']}: regex expectation is not anchored at \\A",
              file=sys.stderr)
        failures += 1

if failures:
    print(f"quality_suite_grader=rejected failures={failures}", file=sys.stderr)
    sys.exit(1)
print(f"quality_suite_grader=accepted cases={len(CASES)} rows={len(rows)}")
