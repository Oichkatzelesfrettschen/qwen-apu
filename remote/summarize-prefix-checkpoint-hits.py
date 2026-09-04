#!/usr/bin/env python3
"""Report the schema-bound prefix checkpoint's hit rate and per-request charges.

measure-prefix-checkpoint-hits.sh runs one scripted sequence against a served
router: a run of stable-phase conversations sharing one system prompt and one
tool-schema set, a schema_change request under an altered tool-schema set, a
recovery request checking that the original pin survived it, a
template_change request sent to the raw completion route, and a second
recovery request checking that survival too. This reader turns the resulting
`requests.tsv` into two tables: the per-request charge table the ledger
already states, widened by what each row's outcome should have been, and a
verdict table over the five checked claims the design exists to test --
whether the mechanism reuses, invalidates on each disruptor, and recovers
after each one -- so a caller reads a confirmed or refuted claim rather than
inferring one from the raw rows.

A verdict is read against the log lines the server itself wrote, not against
the harness's own prediction of what should have happened: `hit` is only
"yes" where a "restored prefix checkpoint" line fell inside that request's own
log window, and `capture_seen` is only "yes" where a "captured prefix
checkpoint" line did. The `identity_sha256` column is the harness's own digest
over what it sent -- the system prompt and the canonicalized tool-schema array
-- so a schema or template change is checked against the request the harness
built rather than assumed from the phase label alone.

usage: summarize-prefix-checkpoint-hits.py REQUESTS_TSV
"""
import argparse
import sys

REQUIRED_HEADER = ("slot", "phase", "conversation", "route", "identity_sha256",
                    "hit", "capture_seen", "checkpoint_key", "known_pin_key",
                    "status")

REQUEST_COLUMNS = ("slot", "phase", "conversation", "route", "hit",
                    "capture_seen", "prompt_n", "prompt_tok_s",
                    "avoided_prompt_tokens", "avoided_prompt_ms",
                    "checkpoint_size_mib", "lifetime_s", "status",
                    "expected_hit", "outcome")

VERDICT_COLUMNS = ("check", "expectation", "observed", "verdict", "detail")

UNKNOWN_STATE = "-"


def read_requests(path):
    with open(path) as handle:
        lines = [line.rstrip("\n") for line in handle if line.strip()]
    if not lines:
        raise SystemExit("prefix checkpoint hits ledger is empty")
    header = lines[0].split("\t")
    missing = [name for name in REQUIRED_HEADER if name not in header]
    if missing:
        raise SystemExit(
            f"prefix checkpoint hits ledger header lacks {missing}: {header}")
    rows = []
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) != len(header):
            raise SystemExit(
                f"prefix checkpoint hits ledger row carries {len(fields)} fields"
                f" where the header names {len(header)}: {line}")
        rows.append(dict(zip(header, fields)))
    return rows


def expected_hit(row):
    """Whether this phase predicts a restore, stated ahead of reading the row.

    The first stable-phase conversation is the cold arm that pins the head, so
    it predicts no restore of its own; every later stable conversation and
    both recovery requests predict one. The two disruptor phases predict none.
    """
    phase = row["phase"]
    if phase == "stable":
        return row["conversation"] != "1"
    if phase in ("recovery_after_schema_change", "recovery_after_template_change"):
        return True
    if phase in ("schema_change", "template_change"):
        return False
    return None


def outcome_of(row, prediction):
    if row["status"] != "completed":
        return "not_measured"
    if prediction is None:
        return "unscored"
    observed = row["hit"] == "yes"
    return "matches_prediction" if observed == prediction else "contradicts_prediction"


def emit(columns, fields):
    print("\t".join(str(field) for field in fields))


def requests_table(rows):
    emit(REQUEST_COLUMNS, REQUEST_COLUMNS)
    for row in rows:
        prediction = expected_hit(row)
        outcome = outcome_of(row, prediction)
        expected_label = (UNKNOWN_STATE if prediction is None
                           else ("yes" if prediction else "no"))
        emit(REQUEST_COLUMNS, (
            row["slot"], row["phase"], row["conversation"], row["route"],
            row["hit"], row["capture_seen"], row.get("prompt_n", UNKNOWN_STATE),
            row.get("prompt_tok_s", UNKNOWN_STATE),
            row.get("avoided_prompt_tokens", UNKNOWN_STATE),
            row.get("avoided_prompt_ms", UNKNOWN_STATE),
            row.get("checkpoint_size_mib", UNKNOWN_STATE),
            row.get("lifetime_s", UNKNOWN_STATE), row["status"],
            expected_label, outcome))


def rows_of(rows, phase):
    return [row for row in rows if row["phase"] == phase]


def verdict_stable_reuse(rows):
    stable = rows_of(rows, "stable")
    if len(stable) < 2:
        return ("stable_reuse", "later stable conversations restore the pin",
                UNKNOWN_STATE, "inconclusive",
                f"stable_conversations={len(stable)}, need at least 2")
    baseline = stable[0]
    later = stable[1:]
    if baseline["status"] != "completed":
        return ("stable_reuse", "the cold conversation captures the pin",
                UNKNOWN_STATE, "inconclusive", "baseline conversation failed")
    if baseline["hit"] == "yes":
        return ("stable_reuse", "the cold conversation carries no restore",
                "restored", "refuted",
                "the first request of the run reads a hit, so it did not pin"
                " the head it should have")
    if baseline["capture_seen"] != "yes":
        return ("stable_reuse", "the cold conversation captures the pin",
                "no_capture", "refuted",
                "no capture line fell inside the cold request's own window")
    incomplete = [row for row in later if row["status"] != "completed"]
    if incomplete:
        return ("stable_reuse", "every later stable conversation restores",
                "incomplete", "inconclusive",
                f"failed_slots={','.join(row['slot'] for row in incomplete)}")
    hits = [row for row in later if row["hit"] == "yes"]
    same_key = all(row.get("checkpoint_key") == baseline.get("checkpoint_key")
                    for row in hits)
    if len(hits) == len(later) and same_key and baseline.get("checkpoint_key"):
        return ("stable_reuse", "every later stable conversation restores",
                f"{len(hits)} of {len(later)} restored, same key", "confirmed",
                f"key={baseline.get('checkpoint_key')}")
    return ("stable_reuse", "every later stable conversation restores",
            f"{len(hits)} of {len(later)} restored", "refuted",
            "same_key" if same_key else "checkpoint_key diverged across hits")


def verdict_invalidation(rows, phase, label):
    changed = rows_of(rows, phase)
    if not changed:
        return (label, "the request diverges from the pin and recomputes",
                UNKNOWN_STATE, "inconclusive", f"no {phase} request in the ledger")
    row = changed[0]
    if row["status"] != "completed":
        return (label, "the request diverges from the pin and recomputes",
                UNKNOWN_STATE, "inconclusive", "the request failed")
    if row["hit"] == "no" and row["capture_seen"] == "no":
        return (label, "the request diverges from the pin and recomputes",
                "no restore, no capture", "confirmed",
                f"identity_sha256={row['identity_sha256']}")
    return (label, "the request diverges from the pin and recomputes",
            f"hit={row['hit']} capture_seen={row['capture_seen']}", "refuted",
            "the divergent request still read a restore or a capture")


def verdict_recovery(rows, phase, label, baseline_key):
    recovered = rows_of(rows, phase)
    if not recovered:
        return (label, "the original pin still restores", UNKNOWN_STATE,
                "inconclusive", f"no {phase} request in the ledger")
    row = recovered[0]
    if row["status"] != "completed":
        return (label, "the original pin still restores", UNKNOWN_STATE,
                "inconclusive", "the request failed")
    if row["hit"] == "yes" and baseline_key and row.get("checkpoint_key") == baseline_key:
        return (label, "the original pin still restores",
                f"restored key={row.get('checkpoint_key')}", "confirmed",
                "the disruptor left the pin standing")
    return (label, "the original pin still restores",
            f"hit={row['hit']} key={row.get('checkpoint_key')}", "refuted",
            "the disruptor evicted or replaced the pin, or the baseline never"
            " captured one")


def verdicts(rows):
    stable = rows_of(rows, "stable")
    baseline_key = (stable[0].get("checkpoint_key")
                    if stable and stable[0]["status"] == "completed" else None)
    return [
        verdict_stable_reuse(rows),
        verdict_invalidation(rows, "schema_change", "schema_invalidation"),
        verdict_recovery(rows, "recovery_after_schema_change",
                          "recovery_after_schema_change", baseline_key),
        verdict_invalidation(rows, "template_change", "template_invalidation"),
        verdict_recovery(rows, "recovery_after_template_change",
                          "recovery_after_template_change", baseline_key),
    ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("requests")
    args = parser.parse_args()
    rows = read_requests(args.requests)
    requests_table(rows)
    print()
    emit(VERDICT_COLUMNS, VERDICT_COLUMNS)
    for row in verdicts(rows):
        emit(VERDICT_COLUMNS, row)
    return 0


if __name__ == "__main__":
    sys.exit(main())
