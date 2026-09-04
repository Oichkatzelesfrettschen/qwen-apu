#!/usr/bin/env python3
"""Fold a web-off/web-on manifest into one TSV and one markdown report.

remote/run-conversational-suite.sh writes one manifest row per model:
web_off_json always exists, web_on_json exists only where web_on_status reads
`available`. This reads both records per model, reports each arm's rows,
correct-on-completed, category breakdown, tool-proposal rate, approvals, mean
and p90 wall time, and the paired per-row delta web-on minus web-off computed
only over row ids both arms actually graded -- the pairing count travels next
to the delta so a partial pairing cannot read as a full-suite gain.

usage: summarize-conversational-suite.py MANIFEST_TSV OUTPUT_DIRECTORY
"""

import argparse
import json
import statistics
import sys

MANIFEST_FIELDS = ("model_id", "web_off_json", "web_on_status", "web_on_reason", "web_on_json")


def percentile(values, fraction):
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


def load_manifest(path):
    rows = []
    with open(path, encoding="utf-8") as handle:
        header = handle.readline().rstrip("\n").split("\t")
        if tuple(header) != MANIFEST_FIELDS:
            raise SystemExit(f"manifest header disagrees: {header}")
        for line in handle:
            if not line.strip():
                continue
            values = line.rstrip("\n").split("\t")
            if len(values) != len(MANIFEST_FIELDS):
                raise SystemExit(f"manifest row holds {len(values)} fields: {values}")
            rows.append(dict(zip(MANIFEST_FIELDS, values)))
    return rows


def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def wall_seconds_list(records, key="wall_seconds"):
    return [r[key] for r in records if r.get(key) is not None]


def summarize_off_arm(document):
    summary = document["summary"]
    records = document["records"]
    walls = wall_seconds_list(records)
    return {
        "rows": summary["rows"],
        "correct_on_completed": summary.get("correct_on_completed"),
        "mean_wall": statistics.fmean(walls) if walls else None,
        "p90_wall": percentile(walls, 0.9),
        "by_category": summary.get("by_category", {}),
        "by_id": {r["id"]: bool(r["passed"]) for r in records},
    }


def summarize_on_arm(document):
    summary = document["summary"]
    records = document["records"]
    walls = wall_seconds_list(records)
    return {
        "rows": summary["rows"],
        "correct_on_completed": summary.get("correct_on_completed"),
        "mean_wall": statistics.fmean(walls) if walls else None,
        "p90_wall": percentile(walls, 0.9),
        "by_category": summary.get("by_category", {}),
        "by_id": {r["id"]: bool(r["passed"]) for r in records},
        "tool_proposal_rate": summary.get("tool_proposal_rate"),
        "approvals": summary.get("approvals"),
        "results_produced": summary.get("results_produced"),
        "rows_skipped": summary.get("rows_skipped"),
    }


def fmt(value, spec="{:.3f}"):
    return "-" if value is None else spec.format(value)


TSV_FIELDS = (
    "model_id",
    "web_off_rows", "web_off_correct_on_completed", "web_off_mean_wall", "web_off_p90_wall",
    "web_on_status", "web_on_reason",
    "web_on_rows", "web_on_correct_on_completed", "web_on_mean_wall", "web_on_p90_wall",
    "tool_proposal_rate", "approvals", "results_produced",
    "paired_count", "paired_delta_mean",
)


def build_row(manifest_row):
    off_document = load_json(manifest_row["web_off_json"])
    off = summarize_off_arm(off_document)

    status = manifest_row["web_on_status"]
    on = None
    paired_count = 0
    paired_delta_mean = None
    if status == "available" and manifest_row["web_on_json"] != "-":
        on_document = load_json(manifest_row["web_on_json"])
        on = summarize_on_arm(on_document)
        shared_ids = sorted(set(off["by_id"]) & set(on["by_id"]))
        deltas = [int(on["by_id"][i]) - int(off["by_id"][i]) for i in shared_ids]
        paired_count = len(deltas)
        paired_delta_mean = statistics.fmean(deltas) if deltas else None

    row = {
        "model_id": manifest_row["model_id"],
        "web_off_rows": off["rows"],
        "web_off_correct_on_completed": fmt(off["correct_on_completed"]),
        "web_off_mean_wall": fmt(off["mean_wall"], "{:.2f}"),
        "web_off_p90_wall": fmt(off["p90_wall"], "{:.2f}"),
        "web_on_status": status,
        "web_on_reason": manifest_row["web_on_reason"],
        "web_on_rows": on["rows"] if on else "-",
        "web_on_correct_on_completed": fmt(on["correct_on_completed"]) if on else "-",
        "web_on_mean_wall": fmt(on["mean_wall"], "{:.2f}") if on else "-",
        "web_on_p90_wall": fmt(on["p90_wall"], "{:.2f}") if on else "-",
        "tool_proposal_rate": fmt(on["tool_proposal_rate"]) if on else "-",
        "approvals": on["approvals"] if on else "-",
        "results_produced": on["results_produced"] if on else "-",
        "paired_count": paired_count,
        "paired_delta_mean": fmt(paired_delta_mean),
    }
    return row, off, on


def category_lines(model_id, arm_name, by_category):
    lines = []
    for category in sorted(by_category):
        bucket = by_category[category]
        lines.append(
            f"| {model_id} | {arm_name} | {category} | {bucket['passed']}/{bucket['attempted']} |")
    return lines


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest")
    parser.add_argument("output_directory")
    arguments = parser.parse_args(argv[1:])

    manifest_rows = load_manifest(arguments.manifest)
    tsv_rows = []
    category_table_lines = []
    for manifest_row in manifest_rows:
        row, off, on = build_row(manifest_row)
        tsv_rows.append(row)
        category_table_lines += category_lines(manifest_row["model_id"], "web-off", off["by_category"])
        if on:
            category_table_lines += category_lines(manifest_row["model_id"], "web-on", on["by_category"])

    tsv_path = f"{arguments.output_directory}/conversational-summary.tsv"
    with open(tsv_path, "w", encoding="utf-8") as handle:
        handle.write("\t".join(TSV_FIELDS) + "\n")
        for row in tsv_rows:
            handle.write("\t".join(str(row[field]) for field in TSV_FIELDS) + "\n")

    md_path = f"{arguments.output_directory}/conversational-summary.md"
    with open(md_path, "w", encoding="utf-8") as handle:
        handle.write("# Conversational suite: web-off against web-on\n\n")
        handle.write("Both arms grade the suite's rows in the row file's own order; the "
                     "web-on arm runs only where a served web section reaches the model, "
                     "and its `paired_delta_mean` is computed over the row ids both arms "
                     "actually graded, named by `paired_count`.\n\n")
        handle.write("| " + " | ".join(TSV_FIELDS) + " |\n")
        handle.write("|" + "|".join("---" for _ in TSV_FIELDS) + "|\n")
        for row in tsv_rows:
            handle.write("| " + " | ".join(str(row[field]) for field in TSV_FIELDS) + " |\n")
        handle.write("\n## Category breakdown\n\n")
        handle.write("| model_id | arm | category | passed/attempted |\n")
        handle.write("|---|---|---|---|\n")
        for line in category_table_lines:
            handle.write(line + "\n")

    print(f"conversational_summary=written rows={len(tsv_rows)} tsv={tsv_path} md={md_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
