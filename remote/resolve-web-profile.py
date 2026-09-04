#!/usr/bin/env python3
"""Resolve whether a servable checkpoint reaches a web-enabled router section.

remote/web-profiles.tsv joins a profile_id to one model_id and states, per
row, whether its execution_policy authorizes a tool-carrying section
(validator-gated) or emits nothing (refused, or ui-mediated, which emits a
section naming no MCP server). A row that authorizes a section still reaches
no request unless the running listener actually served it, which happens
only where the router launched under QWEN_WEB_AUTHORIZER_READY=1 and
generated that profile's section, so the served roster -- read from
GET /v1/models -- is the second half of the join. This is the availability
test remote/run-conversational-suite.sh runs before it spends any device
time driving the served page.

Prints one tab-separated line on stdout:

    available\tPROFILE_ID\tMAX_FETCHES
    unavailable\tREASON\tDETAIL

REASON is one of:
    no_web_profile           no row in the ledger names this model_id
    execution_policy_refused a row names it, but its execution_policy reads
                              refused, which emits no MCP configuration under
                              any setting
    ui_mediated_no_tools     a row names it with execution_policy ui-mediated,
                              which emits a section naming no MCP tool server
                              because the page performs retrieval itself
    authorizer_not_ready     a row authorizes a section, but the served
                              roster does not carry its profile_id, so the
                              launch did not emit it (QWEN_WEB_AUTHORIZER_READY
                              unset, or the preset predates the ledger row)

A model named by more than one row is resolved row by row in the ledger's own
order; the first row whose policy authorizes a section the listener actually
serves wins, and every earlier refusal is discarded rather than reported,
since only one profile can answer a request for this model_id.
"""

import argparse
import sys

FIELDS = (
    "profile_id", "model_id", "web_mode", "context", "validated_filled_depth",
    "max_results", "max_fetches", "max_chars_per_fetch", "multi_source",
    "vision_allowed", "tool_selection", "execution_policy", "provider",
    "primary_category", "fallback_category", "minimum_results", "searxng_url",
)


def load_ledger(path):
    rows = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                continue
            values = line.rstrip("\n").split("\t")
            if len(values) != len(FIELDS):
                raise SystemExit(
                    f"web-profiles row holds {len(values)} fields, want "
                    f"{len(FIELDS)}: {values[0] if values else '(empty)'}")
            rows.append(dict(zip(FIELDS, values)))
    return rows


def resolve(model_id, ledger_rows, served_ids):
    matches = [row for row in ledger_rows if row["model_id"] == model_id]
    if not matches:
        return "unavailable", "no_web_profile", "no row in the ledger names this model_id"
    refusals = []
    for row in matches:
        policy = row["execution_policy"]
        if policy == "refused":
            refusals.append((
                "execution_policy_refused",
                f"profile {row['profile_id']} execution_policy=refused"))
            continue
        if policy == "ui-mediated":
            refusals.append((
                "ui_mediated_no_tools",
                f"profile {row['profile_id']} execution_policy=ui-mediated"))
            continue
        if policy != "validator-gated":
            refusals.append((
                "execution_policy_refused",
                f"profile {row['profile_id']} execution_policy={policy!r} is "
                "not a recognized emitting value"))
            continue
        if row["profile_id"] not in served_ids:
            refusals.append((
                "authorizer_not_ready",
                f"profile {row['profile_id']} is not in the served roster"))
            continue
        return "available", row["profile_id"], row["max_fetches"]
    reason, detail = refusals[0]
    return "unavailable", reason, detail


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model_id")
    parser.add_argument("--ledger", required=True,
                        help="path to remote/web-profiles.tsv or a fixture of it")
    parser.add_argument("--served-ids", default="",
                        help="comma-separated ids GET /v1/models returned")
    arguments = parser.parse_args(argv[1:])

    ledger_rows = load_ledger(arguments.ledger)
    served_ids = {part for part in arguments.served_ids.split(",") if part}
    status, second, third = resolve(arguments.model_id, ledger_rows, served_ids)
    print(f"{status}\t{second}\t{third}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
