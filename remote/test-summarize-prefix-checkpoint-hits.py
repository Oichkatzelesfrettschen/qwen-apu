#!/usr/bin/env python3
"""Read summarize-prefix-checkpoint-hits.py against ledgers whose verdicts are known.

Each case builds one requests.tsv by hand and reads the verdict row the case
is about, the way test-summarize-prefill-ladder.py reads the ladder's own
summary.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

SUMMARIZER = Path(__file__).resolve().parent / "summarize-prefix-checkpoint-hits.py"

HEADER = ("slot\tphase\tconversation\troute\tidentity_sha256\tprompt_n\tprompt_ms"
          "\tprompt_tok_s\tpredicted_n\thit\tcapture_seen\tcheckpoint_key"
          "\tknown_pin_key\tcheckpoint_size_mib\toperation_ms"
          "\tavoided_prompt_tokens\tavoided_prompt_ms\tlifetime_s"
          "\tlog_bytes_scanned\tstatus\treason")

failures = []


def report(name, condition, detail=""):
    if condition:
        print(f"ok {name}")
        return
    failures.append(name)
    print(f"FAIL {name} {detail}", file=sys.stderr)


def row(slot, phase, conversation, route, identity, hit, capture_seen,
        checkpoint_key="-", prompt_n="10", prompt_ms="10.0",
        avoided_tokens="-", avoided_ms="-", status="completed", reason="-"):
    known = checkpoint_key
    return "\t".join((
        str(slot), phase, str(conversation), route, identity, prompt_n,
        prompt_ms, "1.000", "4", hit, capture_seen, checkpoint_key, known,
        "12.500", "5.00", avoided_tokens, avoided_ms, "-", "0", status, reason))


def summarize(rows):
    with tempfile.TemporaryDirectory() as directory:
        ledger = Path(directory) / "requests.tsv"
        ledger.write_text("\n".join((HEADER, *rows)) + "\n", encoding="utf-8")
        finished = subprocess.run(
            [sys.executable, str(SUMMARIZER), str(ledger)],
            capture_output=True, text=True, check=False)
    return finished


def parse(output):
    blocks = output.strip("\n").split("\n\n")
    request_lines = [line for line in blocks[0].splitlines() if line.strip()]
    request_header = request_lines[0].split("\t")
    requests = [dict(zip(request_header, line.split("\t")))
                for line in request_lines[1:]]
    verdict_lines = [line for line in blocks[1].splitlines() if line.strip()]
    verdict_header = verdict_lines[0].split("\t")
    verdicts = [dict(zip(verdict_header, line.split("\t")))
                for line in verdict_lines[1:]]
    return requests, verdicts


def verdict_of(verdicts, check):
    for entry in verdicts:
        if entry["check"] == check:
            return entry
    return None


# A healthy run: the cold conversation captures, two later stable
# conversations restore under the same key, the schema and template changes
# each recompute in full with no checkpoint line, and both recovery requests
# restore the original key.
healthy = [
    row(1, "stable", 1, "chat", "id-p", "no", "yes",
        checkpoint_key="key-p", prompt_n="30"),
    row(2, "stable", 2, "chat", "id-p", "yes", "no",
        checkpoint_key="key-p", prompt_n="8", avoided_tokens="22", avoided_ms="22.0"),
    row(3, "stable", 3, "chat", "id-p", "yes", "no",
        checkpoint_key="key-p", prompt_n="8", avoided_tokens="22", avoided_ms="22.0"),
    row(4, "schema_change", 1, "chat", "id-schema", "no", "no", prompt_n="34"),
    row(5, "recovery_after_schema_change", 1, "chat", "id-p", "yes", "no",
        checkpoint_key="key-p", prompt_n="8"),
    row(6, "template_change", 1, "raw", "id-template", "no", "no", prompt_n="12"),
    row(7, "recovery_after_template_change", 1, "chat", "id-p", "yes", "no",
        checkpoint_key="key-p", prompt_n="8"),
]
finished = summarize(healthy)
report("healthy_run_exits_zero", finished.returncode == 0, finished.stderr)
requests, verdicts = parse(finished.stdout)
report("request_table_carries_one_row_per_ledger_row", len(requests) == 7, requests)

baseline_row = requests[0]
report("baseline_expected_hit_is_no_since_it_pins",
       baseline_row["expected_hit"] == "no"
       and baseline_row["outcome"] == "matches_prediction", baseline_row)

second_row = requests[1]
report("second_stable_expected_hit_is_yes",
       second_row["expected_hit"] == "yes"
       and second_row["outcome"] == "matches_prediction", second_row)

report("stable_reuse_confirmed",
       verdict_of(verdicts, "stable_reuse")["verdict"] == "confirmed",
       verdict_of(verdicts, "stable_reuse"))
report("schema_invalidation_confirmed",
       verdict_of(verdicts, "schema_invalidation")["verdict"] == "confirmed",
       verdict_of(verdicts, "schema_invalidation"))
report("template_invalidation_confirmed",
       verdict_of(verdicts, "template_invalidation")["verdict"] == "confirmed",
       verdict_of(verdicts, "template_invalidation"))
report("recovery_after_schema_change_confirmed",
       verdict_of(verdicts, "recovery_after_schema_change")["verdict"] == "confirmed",
       verdict_of(verdicts, "recovery_after_schema_change"))
report("recovery_after_template_change_confirmed",
       verdict_of(verdicts, "recovery_after_template_change")["verdict"] == "confirmed",
       verdict_of(verdicts, "recovery_after_template_change"))

# A schema-change request that still reads a restore refutes the claim rather
# than being silently accepted.
leaky = [
    row(1, "stable", 1, "chat", "id-p", "no", "yes", checkpoint_key="key-p"),
    row(2, "stable", 2, "chat", "id-p", "yes", "no", checkpoint_key="key-p"),
    row(3, "schema_change", 1, "chat", "id-schema", "yes", "no",
        checkpoint_key="key-p"),
]
requests, verdicts = parse(summarize(leaky).stdout)
report("a_schema_change_that_still_restores_refutes_invalidation",
       verdict_of(verdicts, "schema_invalidation")["verdict"] == "refuted",
       verdict_of(verdicts, "schema_invalidation"))

# A cold conversation that itself reads a restore refutes the pinning claim,
# since the very first request of a fresh process has nothing to restore from.
already_pinned = [
    row(1, "stable", 1, "chat", "id-p", "yes", "no", checkpoint_key="key-p"),
    row(2, "stable", 2, "chat", "id-p", "yes", "no", checkpoint_key="key-p"),
]
requests, verdicts = parse(summarize(already_pinned).stdout)
report("a_cold_conversation_that_restores_refutes_stable_reuse",
       verdict_of(verdicts, "stable_reuse")["verdict"] == "refuted",
       verdict_of(verdicts, "stable_reuse"))

# A ledger too short to test reuse at all reads inconclusive rather than a
# false confirmation.
short = [row(1, "stable", 1, "chat", "id-p", "no", "yes", checkpoint_key="key-p")]
requests, verdicts = parse(summarize(short).stdout)
report("a_single_stable_conversation_is_inconclusive_for_reuse",
       verdict_of(verdicts, "stable_reuse")["verdict"] == "inconclusive",
       verdict_of(verdicts, "stable_reuse"))

# A missing phase reads inconclusive with its own reason rather than crashing.
report("a_missing_recovery_phase_is_inconclusive",
       verdict_of(verdicts, "recovery_after_schema_change")["verdict"] == "inconclusive",
       verdict_of(verdicts, "recovery_after_schema_change"))

# A failed request never becomes a confirmed or refuted claim.
failed = [
    row(1, "stable", 1, "chat", "id-p", "no", "yes", checkpoint_key="key-p"),
    row(2, "stable", 2, "chat", "-", "no", "no", status="failed", reason="request_failed"),
]
requests, verdicts = parse(summarize(failed).stdout)
report("a_failed_request_is_not_measured",
       requests[1]["outcome"] == "not_measured", requests[1])

# A ragged ledger row refuses rather than reading a shifted row.
ragged_finished = None
with tempfile.TemporaryDirectory() as directory:
    ledger = Path(directory) / "requests.tsv"
    ledger.write_text(HEADER + "\n1\tstable\t1\n", encoding="utf-8")
    ragged_finished = subprocess.run(
        [sys.executable, str(SUMMARIZER), str(ledger)],
        capture_output=True, text=True, check=False)
report("a_ragged_ledger_row_is_refused", ragged_finished.returncode != 0,
       ragged_finished.stderr)

if failures:
    print(f"summarize_prefix_checkpoint_hits_tests=failed failures={len(failures)}",
          file=sys.stderr)
    raise SystemExit(1)
print("summarize_prefix_checkpoint_hits_tests=passed")
