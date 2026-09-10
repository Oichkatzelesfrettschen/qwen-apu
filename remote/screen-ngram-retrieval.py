#!/usr/bin/env python3
"""Replay retained token sequences against bounded in-memory n-gram indices."""

from __future__ import annotations

import argparse
import collections
import dataclasses
import hashlib
import json
import math
import pathlib
import statistics
import sys
import time
import tracemalloc
from collections.abc import Iterable, Sequence

KEY_SIZES = (12, 8, 4)
MAX_DRAFT_TOKENS = 3
RESULT_SCHEMA = "qwen-ngram-retrieval-screen-v1"
HISTORICAL_TARGET_PASS_MS = {0: 323.0, 1: 459.0, 2: 662.0, 3: 783.0}
TARGET_COST_EVIDENCE = pathlib.PurePosixPath("evidence/mtp-speculation-matrix.md")


@dataclasses.dataclass(frozen=True)
class SequenceRecord:
    """One retained completion and the identity that prevents corpus leakage."""

    workload_id: str
    source_path: str
    source_sha256: str
    model_id: str
    tokens: tuple[int, ...]


@dataclasses.dataclass(frozen=True)
class Candidate:
    """One proposed continuation and its lookup origin."""

    tokens: tuple[int, ...]
    source: str
    key_size: int


@dataclasses.dataclass(frozen=True)
class RoundResult:
    """One simulated target verification round."""

    position: int
    source: str
    key_size: int
    proposed: int
    accepted: int
    committed: int
    lookup_ns: int


class ExternalIndex:
    """A bounded exact-key index built from non-held-out sequences."""

    def __init__(self, sequences: Sequence[tuple[int, ...]]) -> None:
        self.candidates: dict[
            int, dict[tuple[int, ...], collections.Counter[tuple[int, ...]]]
        ] = {key_size: {} for key_size in KEY_SIZES}
        for tokens in sequences:
            for key_size in KEY_SIZES:
                for start in range(0, len(tokens) - key_size):
                    key = tokens[start : start + key_size]
                    continuation = tokens[
                        start + key_size : start + key_size + MAX_DRAFT_TOKENS
                    ]
                    if not continuation:
                        continue
                    counter = self.candidates[key_size].setdefault(
                        key, collections.Counter()
                    )
                    counter[continuation] += 1

    def lookup(self, prefix: tuple[int, ...]) -> Candidate | None:
        """Return the longest-key candidate with deterministic frequency ties."""
        for key_size in KEY_SIZES:
            if len(prefix) < key_size:
                continue
            counter = self.candidates[key_size].get(prefix[-key_size:])
            if not counter:
                continue
            continuation = min(
                counter,
                key=lambda value: (-counter[value], value),
            )
            return Candidate(continuation, "external", key_size)
        return None

    def counts(self) -> tuple[int, int]:
        """Return key and retained candidate-token cardinalities."""
        key_count = 0
        candidate_tokens = 0
        for key_map in self.candidates.values():
            key_count += len(key_map)
            for counter in key_map.values():
                candidate_tokens += sum(len(candidate) for candidate in counter)
        return key_count, candidate_tokens


class HistoryIndex:
    """An incrementally revealed index that cannot read future target tokens."""

    def __init__(self, tokens: tuple[int, ...]) -> None:
        self.tokens = tokens
        self.positions: dict[int, dict[tuple[int, ...], list[int]]] = {
            key_size: {} for key_size in KEY_SIZES
        }
        self.next_start = {key_size: 0 for key_size in KEY_SIZES}

    def reveal(self, prefix_length: int) -> None:
        """Index keys wholly contained in the revealed prefix."""
        for key_size in KEY_SIZES:
            limit = prefix_length - key_size
            while self.next_start[key_size] <= limit:
                start = self.next_start[key_size]
                key = self.tokens[start : start + key_size]
                self.positions[key_size].setdefault(key, []).append(start)
                self.next_start[key_size] += 1

    def lookup(self, prefix_length: int) -> Candidate | None:
        """Return the most recent continuation whose bytes are already revealed."""
        self.reveal(prefix_length)
        for key_size in KEY_SIZES:
            if prefix_length < key_size:
                continue
            key = self.tokens[prefix_length - key_size : prefix_length]
            for start in reversed(self.positions[key_size].get(key, [])):
                if start == prefix_length - key_size:
                    continue
                continuation_start = start + key_size
                continuation_end = min(
                    continuation_start + MAX_DRAFT_TOKENS,
                    prefix_length,
                )
                if continuation_end > continuation_start:
                    return Candidate(
                        self.tokens[continuation_start:continuation_end],
                        "history",
                        key_size,
                    )
        return None

    def counts(self) -> tuple[int, int]:
        """Return indexed key and occurrence cardinalities."""
        key_count = sum(len(key_map) for key_map in self.positions.values())
        occurrences = sum(
            len(starts)
            for key_map in self.positions.values()
            for starts in key_map.values()
        )
        return key_count, occurrences


def digest(path: pathlib.Path) -> str:
    """Return one file's SHA-256 digest."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_manifest(
    manifest_path: pathlib.Path, repository_root: pathlib.Path
) -> list[SequenceRecord]:
    """Read and verify the finite retained-sequence manifest."""
    lines = manifest_path.read_text(encoding="utf-8").splitlines()
    expected_header = "workload_id\tsource_path\tsource_sha256\tmodel_id"
    if not lines or lines[0] != expected_header:
        raise ValueError(f"manifest header differs from {expected_header!r}")
    records: list[SequenceRecord] = []
    workload_ids: set[str] = set()
    for line_number, line in enumerate(lines[1:], start=2):
        fields = line.split("\t")
        if len(fields) != 4:
            raise ValueError(f"manifest line {line_number} has {len(fields)} fields")
        workload_id, source_path, expected_sha256, model_id = fields
        relative = pathlib.PurePosixPath(source_path)
        if (
            not workload_id
            or workload_id in workload_ids
            or not model_id
            or relative.is_absolute()
            or ".." in relative.parts
            or str(relative) != source_path
        ):
            raise ValueError(f"manifest line {line_number} has an invalid identity")
        source = repository_root / source_path
        if not source.is_file() or source.is_symlink():
            raise ValueError(f"manifest source is not a regular file: {source_path}")
        measured_sha256 = digest(source)
        if measured_sha256 != expected_sha256:
            raise ValueError(
                f"manifest source digest differs for {source_path}: {measured_sha256}"
            )
        payload = json.loads(source.read_text(encoding="utf-8"))
        tokens = payload.get("tokens") if isinstance(payload, dict) else None
        if (
            not isinstance(tokens, list)
            or not tokens
            or any(type(token) is not int for token in tokens)
        ):
            raise ValueError(
                f"manifest source has no integer token sequence: {source_path}"
            )
        records.append(
            SequenceRecord(
                workload_id,
                source_path,
                expected_sha256,
                model_id,
                tuple(tokens),
            )
        )
        workload_ids.add(workload_id)
    if len(records) < 2:
        raise ValueError("the leave-one-workload-out screen requires at least two rows")
    if len({record.model_id for record in records}) != 1:
        raise ValueError("every retained sequence must name the same model identity")
    if len({record.tokens for record in records}) != len(records):
        raise ValueError("an identical token sequence appears under multiple workloads")
    return records


def accepted_prefix(candidate: tuple[int, ...], target: tuple[int, ...]) -> int:
    """Count the exact candidate prefix accepted by the held-out continuation."""
    accepted = 0
    for proposed_token, target_token in zip(candidate, target, strict=False):
        if proposed_token != target_token:
            break
        accepted += 1
    return accepted


def simulate(
    tokens: tuple[int, ...],
    configuration: str,
    external_index: ExternalIndex | None,
) -> tuple[list[RoundResult], HistoryIndex]:
    """Replay exact output while counting target passes and rejected work."""
    if configuration not in {"none", "history", "history_external"}:
        raise ValueError(f"unknown configuration: {configuration}")
    history_index = HistoryIndex(tokens)
    rounds: list[RoundResult] = []
    position = 0
    while position < len(tokens):
        lookup_start = time.perf_counter_ns()
        candidate = None
        if configuration != "none":
            candidate = history_index.lookup(position)
            if candidate is None and configuration == "history_external":
                if external_index is None:
                    raise ValueError("history_external requires an external index")
                candidate = external_index.lookup(tokens[:position])
        lookup_ns = time.perf_counter_ns() - lookup_start
        if candidate is None:
            rounds.append(RoundResult(position, "none", 0, 0, 0, 1, lookup_ns))
            position += 1
            continue
        accepted = accepted_prefix(candidate.tokens, tokens[position:])
        committed = min(accepted + 1, len(tokens) - position)
        rounds.append(
            RoundResult(
                position,
                candidate.source,
                candidate.key_size,
                len(candidate.tokens),
                accepted,
                committed,
                lookup_ns,
            )
        )
        position += committed
    return rounds, history_index


def percentile_95(values: Sequence[int]) -> int:
    """Return the nearest-rank 95th percentile."""
    if not values:
        return 0
    ordered = sorted(values)
    return ordered[math.ceil(0.95 * len(ordered)) - 1]


def result_row(
    workload_id: str,
    configuration: str,
    token_count: int,
    corpus_sequences: int,
    external_index: ExternalIndex | None,
    rounds: Sequence[RoundResult],
    history_index: HistoryIndex,
    index_peak_bytes: int,
) -> dict[str, str | int]:
    """Summarize one replay without treating lookup as target verification."""
    proposed_rounds = [round_result for round_result in rounds if round_result.proposed]
    lookup_values = [round_result.lookup_ns for round_result in rounds]
    proposed_tokens = sum(round_result.proposed for round_result in proposed_rounds)
    accepted_tokens = sum(round_result.accepted for round_result in proposed_rounds)
    history_keys, history_occurrences = history_index.counts()
    external_keys, external_candidate_tokens = (
        external_index.counts() if external_index is not None else (0, 0)
    )
    projected_target_ms = sum(
        HISTORICAL_TARGET_PASS_MS[round_result.proposed] for round_result in rounds
    )
    baseline_target_ms = token_count * HISTORICAL_TARGET_PASS_MS[0]
    return {
        "workload_id": workload_id,
        "configuration": configuration,
        "tokens": token_count,
        "corpus_sequences": corpus_sequences,
        "index_keys": history_keys + external_keys,
        "index_values": history_occurrences + external_candidate_tokens,
        "index_peak_bytes": index_peak_bytes,
        "target_passes": len(rounds),
        "projected_target_ms": f"{projected_target_ms:.3f}",
        "projected_speedup": f"{baseline_target_ms / projected_target_ms:.6f}",
        "proposed_rounds": len(proposed_rounds),
        "proposed_tokens": proposed_tokens,
        "accepted_tokens": accepted_tokens,
        "committed_per_target_pass": f"{token_count / len(rounds):.6f}",
        "acceptance": (
            f"{accepted_tokens / proposed_tokens:.6f}" if proposed_tokens else "-"
        ),
        "lookup_mean_ns": round(statistics.fmean(lookup_values)),
        "lookup_p95_ns": percentile_95(lookup_values),
        "lookup_max_ns": max(lookup_values, default=0),
        "history_proposals": sum(
            round_result.source == "history" for round_result in proposed_rounds
        ),
        "external_proposals": sum(
            round_result.source == "external" for round_result in proposed_rounds
        ),
        "replay_exact": "yes",
    }


def measure_index_peak(sequences: Sequence[tuple[int, ...]]) -> int:
    """Measure Python allocation peak while constructing one external index."""
    tracemalloc.start()
    ExternalIndex(sequences)
    _current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    return peak


def write_tsv(
    path: pathlib.Path, header: Sequence[str], rows: Iterable[Sequence[object]]
) -> None:
    """Write one complete TSV through an exclusive temporary file."""
    temporary = path.with_name(f".{path.name}.pending")
    with temporary.open("x", encoding="utf-8") as output:
        output.write("\t".join(header) + "\n")
        for row in rows:
            output.write("\t".join(str(value) for value in row) + "\n")
        output.flush()
    temporary.replace(path)


def parse_arguments() -> argparse.Namespace:
    """Parse the finite manifest and fresh result directory."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=pathlib.Path)
    parser.add_argument("output_directory", type=pathlib.Path)
    parser.add_argument(
        "--repository-root",
        type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parent.parent,
    )
    return parser.parse_args()


def main() -> int:
    """Run the leave-one-workload-out replay and retain complete round records."""
    arguments = parse_arguments()
    repository_root = arguments.repository_root.resolve(strict=True)
    manifest_path = arguments.manifest.resolve(strict=True)
    target_cost_evidence = repository_root / TARGET_COST_EVIDENCE
    if not target_cost_evidence.is_file() or target_cost_evidence.is_symlink():
        print(
            f"target-cost evidence is not a regular file: {TARGET_COST_EVIDENCE}",
            file=sys.stderr,
        )
        return 2
    if arguments.output_directory.exists():
        print(
            f"output directory exists: {arguments.output_directory}",
            file=sys.stderr,
        )
        return 2
    try:
        records = read_manifest(manifest_path, repository_root)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ngram retrieval screen refused: {error}", file=sys.stderr)
        return 2
    arguments.output_directory.mkdir(parents=True)
    result_rows: list[dict[str, str | int]] = []
    round_rows: list[tuple[object, ...]] = []
    configurations = ("none", "history", "history_external")
    for held_out in records:
        corpus = [
            record.tokens
            for record in records
            if record.workload_id != held_out.workload_id
        ]
        external_index = ExternalIndex(corpus)
        external_peak = measure_index_peak(corpus)
        for configuration in configurations:
            selected_external = (
                external_index if configuration == "history_external" else None
            )
            rounds, history_index = simulate(
                held_out.tokens, configuration, selected_external
            )
            result_rows.append(
                result_row(
                    held_out.workload_id,
                    configuration,
                    len(held_out.tokens),
                    len(corpus) if selected_external is not None else 0,
                    selected_external,
                    rounds,
                    history_index,
                    external_peak if selected_external is not None else 0,
                )
            )
            round_rows.extend(
                (
                    held_out.workload_id,
                    configuration,
                    round_number,
                    round_result.position,
                    round_result.source,
                    round_result.key_size,
                    round_result.proposed,
                    round_result.accepted,
                    round_result.committed,
                    round_result.lookup_ns,
                )
                for round_number, round_result in enumerate(rounds, start=1)
            )
    result_header = tuple(result_rows[0])
    write_tsv(
        arguments.output_directory / "results.tsv",
        result_header,
        ([row[field] for field in result_header] for row in result_rows),
    )
    write_tsv(
        arguments.output_directory / "rounds.tsv",
        (
            "workload_id",
            "configuration",
            "round",
            "position",
            "source",
            "key_size",
            "proposed",
            "accepted",
            "committed",
            "lookup_ns",
        ),
        round_rows,
    )
    aggregate_rows = []
    for configuration in configurations:
        selected_results = [
            row for row in result_rows if row["configuration"] == configuration
        ]
        selected_rounds = [row for row in round_rows if row[1] == configuration]
        token_count = sum(int(row["tokens"]) for row in selected_results)
        target_passes = len(selected_rounds)
        proposed_rounds = sum(int(row[6]) > 0 for row in selected_rounds)
        proposed_tokens = sum(int(row[6]) for row in selected_rounds)
        accepted_tokens = sum(int(row[7]) for row in selected_rounds)
        projected_target_ms = sum(
            float(row["projected_target_ms"]) for row in selected_results
        )
        baseline_target_ms = token_count * HISTORICAL_TARGET_PASS_MS[0]
        lookup_values = [int(row[9]) for row in selected_rounds]
        aggregate_rows.append(
            (
                configuration,
                len(selected_results),
                token_count,
                target_passes,
                f"{token_count / target_passes:.6f}",
                proposed_rounds,
                proposed_tokens,
                accepted_tokens,
                (
                    f"{accepted_tokens / proposed_tokens:.6f}"
                    if proposed_tokens
                    else "-"
                ),
                f"{projected_target_ms:.3f}",
                f"{baseline_target_ms / projected_target_ms:.6f}",
                round(statistics.fmean(lookup_values)),
                percentile_95(lookup_values),
                max(lookup_values, default=0),
                sum(row[4] == "external" for row in selected_rounds),
                max(int(row["index_peak_bytes"]) for row in selected_results),
            )
        )
    write_tsv(
        arguments.output_directory / "aggregate.tsv",
        (
            "configuration",
            "workloads",
            "tokens",
            "target_passes",
            "committed_per_target_pass",
            "proposed_rounds",
            "proposed_tokens",
            "accepted_tokens",
            "acceptance",
            "projected_target_ms",
            "projected_speedup",
            "lookup_mean_ns",
            "lookup_p95_ns",
            "lookup_max_ns",
            "external_proposals",
            "max_index_peak_bytes",
        ),
        aggregate_rows,
    )
    contract_rows = (
        ("schema", RESULT_SCHEMA),
        ("manifest_sha256", digest(manifest_path)),
        ("runner_sha256", digest(pathlib.Path(__file__))),
        ("target_cost_evidence", str(TARGET_COST_EVIDENCE)),
        ("target_cost_evidence_sha256", digest(target_cost_evidence)),
        ("model_id", records[0].model_id),
        ("workloads", len(records)),
        ("key_sizes", ",".join(str(value) for value in KEY_SIZES)),
        ("max_draft_tokens", MAX_DRAFT_TOKENS),
        (
            "historical_target_pass_ms",
            ",".join(
                f"draft_{draft_tokens}:{cost_ms:.1f}"
                for draft_tokens, cost_ms in HISTORICAL_TARGET_PASS_MS.items()
            ),
        ),
        (
            "projection_scope",
            "optimistic_target_only_prior_costs_without_lookup_or_bookkeeping",
        ),
        ("external_split", "leave-one-workload-out"),
        ("prompt_token_ids", "unavailable"),
        ("target_verification", "not_run"),
    )
    write_tsv(
        arguments.output_directory / "contract.tsv",
        ("field", "value"),
        contract_rows,
    )
    write_tsv(
        arguments.output_directory / "terminal-state.tsv",
        ("field", "value"),
        (
            ("screen", "completed"),
            ("workload_rows", len(records)),
            ("configuration_rows", len(result_rows)),
            ("candidate_timing", "not_run"),
            ("appliance_contact", "none"),
        ),
    )
    print(
        f"ngram_retrieval_screen=completed workloads={len(records)} "
        f"results={len(result_rows)} output={arguments.output_directory}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
