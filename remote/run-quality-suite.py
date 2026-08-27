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
import http.client
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


def reject_nonfinite_json_constant(constant):
    """Reject Python's non-standard NaN and infinity JSON extensions."""
    raise ValueError(f"non-finite JSON constant: {constant}")


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
            document = json.loads(
                body, parse_constant=reject_nonfinite_json_constant)
        except (ValueError, RecursionError) as error:
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


NEEDLE_SEPARATOR = " ||| "


def pad_prompt(prompt, depth_characters):
    """Bury the fact inside the filler and leave the question at the end.

    A long_context row states its fact before ` ||| ` and its question after.
    Filler goes on both sides of the fact, so the model reads the fact, then a
    long stretch of irrelevant text, then the question. Placing the filler
    before an intact fact-and-question pair measures answering after a long
    prefix, which every candidate passes and which is not retrieval.
    """
    fact, separator, question = prompt.partition(NEEDLE_SEPARATOR)
    if not separator:
        fact, question = "", prompt
    if depth_characters <= 0:
        return (fact + " " + question).strip()
    half = max(depth_characters // 2, len(FILLER_SENTENCE))
    repeats = half // len(FILLER_SENTENCE) + 1
    filler = FILLER_SENTENCE * repeats
    return (filler + fact.strip() + " " + filler + question.strip()).strip()


def request(endpoint, api_key, model, prompt, max_tokens, thinking, timeout):
    body = json.dumps({
        "model": model,
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
    # Router mode routes on this name and answers 400 for one it does not hold,
    # so the served id is the name a preset section carries. A single-model
    # server accepts any name and answers with its own alias, which is why the
    # served id is recorded per row rather than assumed from this argument.
    parser.add_argument("--model", default="qwen-apu",
                        help="model id sent in the request body")
    parser.add_argument("--thinking", default="on", choices=("on", "off"))
    parser.add_argument(
        "--long-context-characters", type=int,
        help="required positive filler depth when long_context rows are selected")
    parser.add_argument("--timeout", type=float, default=1800)
    arguments = parser.parse_args(argv[1:])

    rows = load_suite(arguments.suite)
    if arguments.categories:
        wanted = set(arguments.categories.split(","))
        rows = [row for row in rows if row["category"] in wanted]
    if not rows:
        raise SystemExit("no suite rows selected")
    if any(row["category"] == "long_context" for row in rows):
        if (arguments.long_context_characters is None
                or arguments.long_context_characters <= 0):
            parser.error(
                "--long-context-characters must be positive when long_context "
                "rows are selected")

    api_key = os.environ.get("QWEN_API_KEY", "")
    thinking = arguments.thinking == "on"
    records = []
    for index, row in enumerate(rows):
        prompt = row["prompt"]
        if row["category"] == "long_context":
            prompt = pad_prompt(prompt, arguments.long_context_characters)
        try:
            document = request(arguments.endpoint, api_key, arguments.model,
                               prompt, arguments.max_tokens, thinking,
                               arguments.timeout)
            error = None
        except (urllib.error.URLError, OSError, http.client.HTTPException,
                json.JSONDecodeError) as failure:
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
            "requested_model": arguments.model,
            "served_model": document.get("model"),
            "category": row["category"],
            "grader": row["grader"],
            "expectation": row["expectation"],
            "prompt_characters": len(prompt),
            "passed": bool(passed),
            "reason": reason,
            "truncated": truncated,
            "empty_answer": not content.strip(),
            "error": error,
            "content": content,
            # The API exposes text for the reasoning span and one generated-token
            # count for the whole response. Word count stays explicitly a word
            # count instead of posing as tokenizer output.
            "reasoning_words": len(reasoning.split()) if reasoning else 0,
            "generated_tokens": timings.get("predicted_n"),
            "prompt_tokens": timings.get("prompt_n"),
            "decode_tok_per_second": timings.get("predicted_per_second"),
            "wall_seconds": document.get("_wall_seconds"),
        })
        print(f"row={row['id']} category={row['category']} "
              f"served={document.get('model')} "
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

    completed = [
        record for record in records
        if (not record["error"] and not record["empty_answer"]
            and not record["truncated"])
    ]
    # The served id comes from the response rather than from the request, so a
    # router that answered from a different preset than the one named shows up
    # here as a second entry instead of being hidden by the loop variable.
    served_models = sorted({
        record["served_model"] for record in records
        if record["served_model"]})
    summary = {
        "rows": len(records),
        "requested_model": arguments.model,
        "served_models": served_models,
        "passed": sum(r["passed"] for r in records),
        "completion_rate": len(completed) / len(records),
        "empty_answer_rate": sum(r["empty_answer"] for r in records) / len(records),
        "truncated_rate": sum(r["truncated"] for r in records) / len(records),
        # Correctness on completed rows separates a wrong answer from an answer
        # the model never produced, which a single pass rate merges.
        "correct_on_completed": (
            sum(r["passed"] for r in completed) / len(completed)
            if completed else None),
        "reasoning_words_total": sum(r["reasoning_words"] for r in records),
        "generated_tokens_total": sum(r["generated_tokens"] or 0 for r in records),
        "wall_seconds_total": sum(r["wall_seconds"] or 0 for r in records),
        "by_category": by_category,
    }

    with open(arguments.output_json, "w") as handle:
        json.dump({"summary": summary, "records": records}, handle, indent=2)

    for name in sorted(by_category):
        bucket = by_category[name]
        print(f"category={name} passed={bucket['passed']}/{bucket['attempted']} "
              f"truncated={bucket['truncated']} empty={bucket['empty']}")
    transport_errors = sum(bool(record["error"]) for record in records)
    print(f"served_models={','.join(served_models) if served_models else 'none'} "
          f"requested_model={arguments.model}")
    terminal_state = "completed" if transport_errors == 0 else "failed"
    print(f"quality_suite={terminal_state} passed={summary['passed']}/{summary['rows']} "
          f"completion_rate={summary['completion_rate']:.3f} "
          f"empty_answer_rate={summary['empty_answer_rate']:.3f} "
          f"transport_errors={transport_errors} "
          f"wall_seconds={summary['wall_seconds_total']:.1f}")
    return 0 if transport_errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
