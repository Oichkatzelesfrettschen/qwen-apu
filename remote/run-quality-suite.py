#!/usr/bin/env python3
"""Grade a live server against remote/quality-suite.tsv.

The five-prompt screen no longer separates candidates, so admission needs a
suite wide enough to show what a lower-bit quantization trades away and a
grader that reads it the same way every time. Every row carries the program
that grades it, so a run reports correctness, completion, and reasoning span
without a reader in the loop.

Long-context rows are padded to a requested depth with generated filler placed
before the question, which measures retrieval past a prefix rather than
retrieval from a short prompt.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

FILLER_SENTENCE = (
    "The survey team recorded routine observations at the site and filed them "
    "with the district office in the usual sequence. "
)


def load_suite(path):
    rows = []
    with open(path) as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 5:
                raise SystemExit(f"suite row holds {len(fields)} fields: {fields[0]}")
            rows.append(dict(zip(
                ("id", "category", "grader", "expectation", "prompt"), fields)))
    return rows


def last_number(text):
    matches = re.findall(r"-?\d+(?:\.\d+)?", text.replace(",", ""))
    return float(matches[-1]) if matches else None


def strip_fence(text):
    fence = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    return fence.group(1).strip() if fence else text.strip()


def grade(row, reply):
    """Return (passed, reason). A grader reports why it refused, because a
    category-level pass rate without reasons hides a formatting failure inside
    a correctness figure."""
    kind, expectation = row["grader"], row["expectation"]
    body = reply.strip()
    if not body:
        return False, "empty reply"
    if kind == "nonempty":
        return True, "answered"
    if kind == "numeric":
        found = last_number(body)
        if found is None:
            return False, "no number in reply"
        want = float(expectation)
        tolerance = max(abs(want) * 1e-6, 1e-9)
        return abs(found - want) <= tolerance, f"found {found}, want {want}"
    if kind in ("contains_all", "contains_any"):
        wanted = [part.lower() for part in expectation.split("|")]
        present = [part for part in wanted if part in body.lower()]
        if kind == "contains_all":
            missing = [part for part in wanted if part not in present]
            return not missing, ("all present" if not missing
                                 else f"missing {'|'.join(missing)}")
        return bool(present), ("matched " + present[0] if present
                               else f"none of {'|'.join(wanted)}")
    if kind == "json_keys":
        try:
            document = json.loads(strip_fence(body))
        except Exception as error:
            return False, f"not JSON: {error}"
        if not isinstance(document, dict):
            return False, "JSON is not an object"
        missing = [key for key in expectation.split("|") if key not in document]
        return not missing, ("keys present" if not missing
                             else f"missing keys {'|'.join(missing)}")
    if kind == "regex":
        return (bool(re.search(expectation, body, re.I | re.M)),
                "pattern matched" if re.search(expectation, body, re.I | re.M)
                else "pattern did not match")
    return False, f"unknown grader {kind}"


def pad_prompt(prompt, depth_characters):
    if depth_characters <= 0:
        return prompt
    repeats = depth_characters // len(FILLER_SENTENCE) + 1
    return FILLER_SENTENCE * repeats + prompt


def request(endpoint, api_key, prompt, max_tokens, thinking, timeout):
    body = json.dumps({
        "model": "qwen-apu",
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "temperature": 0,
        "top_k": 1,
        "seed": 1,
        "chat_template_kwargs": {"enable_thinking": thinking},
    }).encode()
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    call = urllib.request.Request(
        f"{endpoint}/v1/chat/completions", data=body, headers=headers)
    started = time.monotonic()
    with urllib.request.urlopen(call, timeout=timeout) as response:
        document = json.load(response)
    document["_wall_seconds"] = time.monotonic() - started
    return document


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("endpoint")
    parser.add_argument("output_json")
    parser.add_argument("--suite", default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "quality-suite.tsv"))
    parser.add_argument("--categories", default="",
                        help="comma-separated subset; empty runs every row")
    parser.add_argument("--max-tokens", type=int, default=1024)
    parser.add_argument("--thinking", default="on", choices=("on", "off"))
    parser.add_argument("--long-context-characters", type=int, default=0,
                        help="filler placed before every long_context prompt")
    parser.add_argument("--timeout", type=float, default=1800)
    arguments = parser.parse_args(argv[1:])

    rows = load_suite(arguments.suite)
    if arguments.categories:
        wanted = set(arguments.categories.split(","))
        rows = [row for row in rows if row["category"] in wanted]
    if not rows:
        raise SystemExit("no suite rows selected")

    api_key = os.environ.get("QWEN_API_KEY", "")
    thinking = arguments.thinking == "on"
    records = []
    for index, row in enumerate(rows):
        prompt = row["prompt"]
        if row["category"] == "long_context":
            prompt = pad_prompt(prompt, arguments.long_context_characters)
        try:
            document = request(arguments.endpoint, api_key, prompt,
                               arguments.max_tokens, thinking, arguments.timeout)
            error = None
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as failure:
            document, error = {}, str(failure)

        choice = (document.get("choices") or [{}])[0]
        message = choice.get("message") or {}
        content = message.get("content") or ""
        reasoning = message.get("reasoning_content") or ""
        timings = document.get("timings") or {}
        # A reply cut off at the token budget is a completion failure rather
        # than a wrong answer, and the two are reported apart.
        truncated = choice.get("finish_reason") == "length"
        passed, reason = (False, error) if error else grade(row, content)

        records.append({
            "id": row["id"],
            "category": row["category"],
            "grader": row["grader"],
            "expectation": row["expectation"],
            "prompt_characters": len(prompt),
            "passed": bool(passed),
            "reason": reason,
            "truncated": truncated,
            "empty_answer": not content.strip(),
            "error": error,
            "content": content[:600],
            "reasoning_tokens": len(reasoning.split()) if reasoning else 0,
            "answer_tokens": timings.get("predicted_n"),
            "prompt_tokens": timings.get("prompt_n"),
            "decode_tok_per_second": timings.get("predicted_per_second"),
            "wall_seconds": document.get("_wall_seconds"),
        })
        print(f"row={row['id']} category={row['category']} "
              f"passed={bool(passed)} truncated={truncated} reason={reason}",
              flush=True)

    by_category = {}
    for record in records:
        bucket = by_category.setdefault(
            record["category"],
            {"attempted": 0, "passed": 0, "truncated": 0, "empty": 0})
        bucket["attempted"] += 1
        bucket["passed"] += int(record["passed"])
        bucket["truncated"] += int(record["truncated"])
        bucket["empty"] += int(record["empty_answer"])

    completed = [r for r in records if not r["error"] and not r["empty_answer"]]
    summary = {
        "rows": len(records),
        "passed": sum(r["passed"] for r in records),
        "completion_rate": len(completed) / len(records),
        "empty_answer_rate": sum(r["empty_answer"] for r in records) / len(records),
        "truncated_rate": sum(r["truncated"] for r in records) / len(records),
        # Correctness on completed rows separates a wrong answer from an answer
        # the model never produced, which a single pass rate merges.
        "correct_on_completed": (
            sum(r["passed"] for r in completed) / len(completed)
            if completed else None),
        "reasoning_tokens_total": sum(r["reasoning_tokens"] for r in records),
        "answer_tokens_total": sum(r["answer_tokens"] or 0 for r in records),
        "wall_seconds_total": sum(r["wall_seconds"] or 0 for r in records),
        "by_category": by_category,
    }

    with open(arguments.output_json, "w") as handle:
        json.dump({"summary": summary, "records": records}, handle, indent=2)

    for name in sorted(by_category):
        bucket = by_category[name]
        print(f"category={name} passed={bucket['passed']}/{bucket['attempted']} "
              f"truncated={bucket['truncated']} empty={bucket['empty']}")
    print(f"quality_suite=completed passed={summary['passed']}/{summary['rows']} "
          f"completion_rate={summary['completion_rate']:.3f} "
          f"empty_answer_rate={summary['empty_answer_rate']:.3f} "
          f"wall_seconds={summary['wall_seconds_total']:.1f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
