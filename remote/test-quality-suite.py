#!/usr/bin/env python3
"""Check every grader against replies whose verdict is known.

A grader that silently accepts everything reports a perfect candidate, so each
kind is exercised with one reply it must accept and one it must refuse. The
suite file is checked for well-formed rows in the same run, because a row with
the wrong field count fails at measurement time rather than here.
"""

import os
import sys

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
    ("json_keys", "name|age", '```json\n{"name": "Ada", "age": 36}\n```', True),
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

# The filler reaches the requested length and leaves the question last, which is
# what makes a long-context row a retrieval test rather than a longer prompt.
padded = module.pad_prompt("QUESTION", 4000)
if len(padded) < 4000 or not padded.endswith("QUESTION"):
    print(f"padding produced {len(padded)} characters", file=sys.stderr)
    failures += 1

if failures:
    print(f"quality_suite_grader=rejected failures={failures}", file=sys.stderr)
    sys.exit(1)
print(f"quality_suite_grader=accepted cases={len(CASES)} rows={len(rows)}")
