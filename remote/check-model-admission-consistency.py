#!/usr/bin/env python3
"""Validate joins and lifecycle claims across model-admission ledgers."""

import argparse
import csv
import pathlib
import sys


class ConsistencyError(Exception):
    """Report one model-admission consistency failure."""


def read_tsv(path, header_prefix=None):
    """Read a strict TSV whose leading comments are outside the record set."""
    lines = path.read_text(encoding="utf-8").splitlines()
    if header_prefix is None:
        records = [line for line in lines if line and not line.startswith("#")]
    else:
        header = next(
            (line.removeprefix("# ") for line in lines
             if line.startswith(header_prefix)),
            None,
        )
        if header is None:
            raise ConsistencyError(f"{path}: header {header_prefix!r} is absent")
        records = [header]
        records.extend(line for line in lines if line and not line.startswith("#"))
    if not records:
        raise ConsistencyError(f"{path}: TSV is empty")
    field_names = records[0].split("\t")
    rows = []
    for line_number, values in enumerate(records[1:], start=2):
        fields = values.split("\t")
        if len(fields) != len(field_names):
            raise ConsistencyError(
                f"{path}:{line_number}: expected {len(field_names)} fields, "
                f"observed {len(fields)}"
            )
        rows.append(dict(zip(field_names, fields)))
    return rows


def index_rows(path, rows, key):
    """Index rows by a unique, nonempty key."""
    indexed = {}
    for row in rows:
        value = row.get(key, "")
        if not value:
            raise ConsistencyError(f"{path}: empty {key}")
        if value in indexed:
            raise ConsistencyError(f"{path}: duplicate {key} {value}")
        indexed[value] = row
    return indexed


def require_exact_identifiers(path, rows, fields):
    """Reject prose placeholders in machine-readable identity columns."""
    for row in rows:
        for field in fields:
            value = row.get(field, "")
            if "..." in value or "…" in value:
                raise ConsistencyError(
                    f"{path}: {field} contains an inexact identifier: {value}"
                )


def validate(repository_root):
    """Validate the canonical model-admission tables under repository_root."""
    evidence_root = repository_root / "evidence" / "model-admission"
    ledger_path = evidence_root / "candidate-ledger.tsv"
    readiness_path = evidence_root / "readiness-candidates.tsv"
    appliance_path = evidence_root / "readiness-appliance-artifacts.tsv"
    static_path = evidence_root / "static-admission.tsv"
    protocol_path = evidence_root / "readiness-quality-protocols.tsv"
    models_path = repository_root / "remote" / "models.tsv"

    ledger_rows = read_tsv(ledger_path)
    readiness_rows = read_tsv(readiness_path)
    appliance_rows = read_tsv(appliance_path)
    static_rows = read_tsv(static_path)
    protocol_rows = read_tsv(protocol_path)
    model_rows = read_tsv(models_path, "# id\t")

    ledger = index_rows(ledger_path, ledger_rows, "candidate_id")
    readiness = index_rows(readiness_path, readiness_rows, "candidate_id")
    static = index_rows(static_path, static_rows, "candidate_id")
    protocols = index_rows(protocol_path, protocol_rows, "candidate_id")
    models = index_rows(models_path, model_rows, "id")

    require_exact_identifiers(
        readiness_path, readiness_rows, ("candidate_id", "source_repo", "artifact")
    )
    require_exact_identifiers(
        ledger_path,
        ledger_rows,
        ("candidate_id", "artifact_repository", "preferred_artifact"),
    )
    require_exact_identifiers(
        appliance_path,
        appliance_rows,
        ("registry_model_id", "ledger_candidate_id"),
    )

    for candidate_id, row in readiness.items():
        ledger_row = ledger.get(candidate_id)
        if ledger_row is None:
            raise ConsistencyError(
                f"{readiness_path}: candidate {candidate_id} is absent from the ledger"
            )
        if row["stage_in_ledger"] != ledger_row["admission_stage"]:
            raise ConsistencyError(
                f"{readiness_path}: candidate {candidate_id} stage "
                f"{row['stage_in_ledger']} differs from ledger stage "
                f"{ledger_row['admission_stage']}"
            )
        if row["source_repo"] != ledger_row["artifact_repository"]:
            raise ConsistencyError(
                f"{readiness_path}: candidate {candidate_id} repository "
                f"{row['source_repo']} differs from the ledger"
            )

    for row in appliance_rows:
        model_id = row["registry_model_id"]
        candidate_id = row["ledger_candidate_id"]
        if model_id != "none" and model_id not in models:
            raise ConsistencyError(
                f"{appliance_path}: registry_model_id is not a models.tsv id: "
                f"{model_id}"
            )
        if candidate_id != "none" and candidate_id not in ledger:
            raise ConsistencyError(
                f"{appliance_path}: ledger_candidate_id is not a ledger id: "
                f"{candidate_id}"
            )
        if row["category"] == "served" and candidate_id != "none":
            stage = ledger[candidate_id]["admission_stage"]
            if stage != "served":
                raise ConsistencyError(
                    f"{appliance_path}: served candidate {candidate_id} has "
                    f"ledger stage {stage}"
                )
        if row["category"] == "ledger-candidate":
            path_candidate = pathlib.PurePosixPath(row["path"].removesuffix("/*")).name
            if path_candidate != candidate_id:
                raise ConsistencyError(
                    f"{appliance_path}: staging path {path_candidate} joins "
                    f"candidate {candidate_id}"
                )

    for row in ledger_rows:
        control_id = row["quality_control_model_id"]
        reference_id = row["throughput_reference_model_id"]
        if control_id != "-" and control_id not in models:
            raise ConsistencyError(
                f"{ledger_path}: quality control is not a models.tsv id: {control_id}"
            )
        if reference_id != "-" and reference_id not in models:
            raise ConsistencyError(
                f"{ledger_path}: throughput reference is not a models.tsv id: "
                f"{reference_id}"
            )
        if row["next_test"] != "quality-sweep":
            continue
        candidate_id = row["candidate_id"]
        readiness_row = readiness.get(candidate_id)
        if readiness_row is None:
            raise ConsistencyError(
                f"{ledger_path}: quality candidate {candidate_id} lacks readiness data"
            )
        if not readiness_row["throughput_measured"].startswith("yes"):
            raise ConsistencyError(
                f"{ledger_path}: quality candidate {candidate_id} lacks "
                "artifact-specific throughput"
            )
        protocol = protocols.get(candidate_id)
        if protocol is None:
            raise ConsistencyError(
                f"{ledger_path}: quality candidate {candidate_id} lacks a protocol"
            )
        if protocol["sweep_requirement"] != "same-sweep":
            raise ConsistencyError(
                f"{protocol_path}: candidate {candidate_id} is not same-sweep"
            )
        protocol_control = protocol["quality_control_model_id"]
        expected_control = "none" if control_id == "-" else control_id
        if protocol_control != expected_control:
            raise ConsistencyError(
                f"{protocol_path}: candidate {candidate_id} control differs from ledger"
            )
        if protocol_control != "none" and protocol_control not in models:
            raise ConsistencyError(
                f"{protocol_path}: control is not a models.tsv id: {protocol_control}"
            )

    quality_candidates = {
        row["candidate_id"] for row in ledger_rows
        if row["next_test"] == "quality-sweep"
    }
    if set(protocols) != quality_candidates:
        raise ConsistencyError(
            f"{protocol_path}: protocol ids {sorted(protocols)} differ from "
            f"quality candidates {sorted(quality_candidates)}"
        )

    minicpm_ids = ("minicpm5-1b-stock", "minicpm5-1b-fable5-v2")
    minicpm_rows = []
    for candidate_id in minicpm_ids:
        static_row = static.get(candidate_id)
        ledger_row = ledger.get(candidate_id)
        readiness_row = readiness.get(candidate_id)
        if static_row is None or ledger_row is None or readiness_row is None:
            raise ConsistencyError(
                f"MiniCPM parity row is absent for {candidate_id}"
            )
        for static_field, ledger_field in (
            ("repository", "artifact_repository"),
            ("revision", "artifact_revision"),
            ("artifact", "preferred_artifact"),
            ("architecture_fingerprint", "architecture_fingerprint"),
            ("chat_template_sha256", "chat_template_hash"),
        ):
            if static_row[static_field] != ledger_row[ledger_field]:
                raise ConsistencyError(
                    f"{static_path}: {candidate_id} {static_field} differs from ledger"
                )
        if readiness_row["artifact"] != static_row["artifact"]:
            raise ConsistencyError(
                f"{readiness_path}: {candidate_id} artifact differs from static admission"
            )
        minicpm_rows.append(static_row)

    structural_fields = (
        "architecture", "block_count", "nextn_layers", "vocabulary_size",
        "chat_template_sha256", "chat_template_bytes", "tokens_sha256",
        "loaded_tensor_bytes", "skipped_mtp_bytes", "architecture_fingerprint",
    )
    stock_row, fable_row = minicpm_rows
    for field in structural_fields:
        if stock_row[field] != fable_row[field]:
            raise ConsistencyError(f"MiniCPM {field} differs across the pair")
    if stock_row["tokenizer_pre"] == fable_row["tokenizer_pre"]:
        raise ConsistencyError(
            "MiniCPM tokenizer_pre must retain the observed metadata difference"
        )

    staging_rows = [
        row for row in appliance_rows
        if row["path"].startswith("$HOME/models/candidates/")
    ]
    return {
        "candidate_rows": len(ledger_rows),
        "readiness_rows": len(readiness_rows),
        "candidate_staging_rows": len(staging_rows),
        "quality_protocol_rows": len(protocol_rows),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repository-root",
        type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parent.parent,
    )
    arguments = parser.parse_args()
    try:
        counts = validate(arguments.repository_root.resolve())
    except (ConsistencyError, OSError, csv.Error) as error:
        print(f"model_admission_consistency=rejected reason={error}", file=sys.stderr)
        return 1
    print(
        "model_admission_consistency=accepted "
        + " ".join(f"{key}={value}" for key, value in counts.items())
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
