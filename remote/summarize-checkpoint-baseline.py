#!/usr/bin/env python3
"""Recompute a checkpoint baseline summary from the raw rows each arm retained.

The runner writes one directory per arm holding the load record, the
time-to-first-token record, one response and one token-id file per repeat, and
the decode row table derived from those responses. This reader recomputes every
aggregate from those files rather than from the runner's own arithmetic, so a
summary is checkable after the fact and a retained arm can be re-read under a
corrected reader. Every artifact the summary rests on is required: an absent
response, an absent token file, a decode row naming a repeat that retained no
response, or a token digest that fails its own recomputation ends the read with
the path that failed, because a summary computed over a partial arm reports the
repeats that survived rather than the arm that ran.

Token identity is the arm's own claim about determinism: every repeat of one arm
decodes the same fixed request under greedy sampling, so the recomputed SHA-256
over each repeat's token-id array must equal the first repeat's. A mismatch is
reported as a value rather than raising, since a divergent arm is a finding the
summary carries.

usage: summarize-checkpoint-baseline.py OUTPUT_DIRECTORY [--write]
"""

from __future__ import annotations

import hashlib
import statistics
import sys
from dataclasses import dataclass
from pathlib import Path

SCHEMA = "checkpoint-baseline-summary-v1"
DECODE_ROW_FIELDS = (
    "repeat",
    "decode_tok_per_second",
    "decode_ms",
    "prompt_n",
    "predicted_n",
    "tokens_sha256",
)


class SummaryError(Exception):
    """A raw record is absent, malformed, or inconsistent with its neighbours."""


def read_key_value(path: Path) -> dict[str, str]:
    """Read a `key<TAB>value` table whose first line is the `key\tvalue` header."""
    if not path.is_file() or path.is_symlink():
        raise SummaryError(f"record is absent or linked: {path}")
    values: dict[str, str] = {}
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "key\tvalue":
        raise SummaryError(f"record carries no key/value header: {path}")
    for number, line in enumerate(lines[1:], start=2):
        if not line:
            continue
        fields = line.split("\t")
        if len(fields) != 2 or not fields[0]:
            raise SummaryError(f"record line {number} is malformed: {path}")
        if fields[0] in values:
            raise SummaryError(f"record names {fields[0]} twice: {path}")
        values[fields[0]] = fields[1]
    return values


def require(values: dict[str, str], name: str, path: Path) -> str:
    try:
        return values[name]
    except KeyError:
        raise SummaryError(f"record names no {name}: {path}") from None


def positive_float(text: str, name: str, path: Path) -> float:
    try:
        value = float(text)
    except ValueError:
        raise SummaryError(f"{name} is not a number in {path}: {text}") from None
    if not value > 0:
        raise SummaryError(f"{name} is not positive in {path}: {text}")
    return value


@dataclass(frozen=True)
class ArmSummary:
    """One served session: its load, its first token, and its repeated decodes."""

    slot: str
    role: str
    load_wall_ms: float
    ttft_ms: float
    decode_rates: tuple[float, ...]
    token_identity: str
    clock_samples: int

    @property
    def decode_mean(self) -> float:
        return statistics.fmean(self.decode_rates)

    @property
    def decode_spread(self) -> float:
        """Relative span of the repeats, the quantity a stability claim rests on."""
        return (max(self.decode_rates) - min(self.decode_rates)) / self.decode_mean


def read_decode_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file() or path.is_symlink():
        raise SummaryError(f"decode row table is absent or linked: {path}")
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].split("\t") != list(DECODE_ROW_FIELDS):
        raise SummaryError(f"decode row table carries the wrong header: {path}")
    rows: list[dict[str, str]] = []
    for number, line in enumerate(lines[1:], start=2):
        if not line:
            continue
        fields = line.split("\t")
        if len(fields) != len(DECODE_ROW_FIELDS):
            raise SummaryError(f"decode row {number} is malformed: {path}")
        rows.append(dict(zip(DECODE_ROW_FIELDS, fields, strict=True)))
    if not rows:
        raise SummaryError(f"decode row table holds no repeat: {path}")
    return rows


def token_digest(path: Path) -> str:
    """SHA-256 over the canonical newline-joined token-id array a repeat emitted."""
    if not path.is_file() or path.is_symlink():
        raise SummaryError(f"token record is absent or linked: {path}")
    ids: list[str] = []
    for number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line:
            continue
        try:
            ids.append(str(int(line)))
        except ValueError:
            raise SummaryError(
                f"token record line {number} is not an integer: {path}"
            ) from None
    if not ids:
        raise SummaryError(f"token record holds no token: {path}")
    return hashlib.sha256(("\n".join(ids) + "\n").encode("utf-8")).hexdigest()


def count_samples(path: Path) -> int:
    """Rows of the arm's clock record, excluding its header.

    An absent record fails the arm rather than reading as zero coverage: the
    sidecar is the authority on what clock the rate ran at, and a summary that
    silently reported an unsampled arm would give an unpinned rate the same
    standing as a pinned one.
    """
    if not path.is_file() or path.is_symlink():
        raise SummaryError(f"clock sidecar record is absent or linked: {path}")
    lines = [line for line in path.read_text(encoding="utf-8").splitlines() if line]
    if len(lines) < 2:
        raise SummaryError(f"clock sidecar record holds no sample: {path}")
    return len(lines) - 1


def summarize_arm(directory: Path) -> ArmSummary:
    load = read_key_value(directory / "load.tsv")
    ttft = read_key_value(directory / "ttft.tsv")
    rows = read_decode_rows(directory / "decode-rows.tsv")
    rates: list[float] = []
    digests: list[str] = []
    for row in rows:
        repeat = row["repeat"]
        repeat_directory = directory / "repeats" / repeat
        response = repeat_directory / "response.json"
        if not response.is_file() or response.is_symlink():
            raise SummaryError(f"repeat retained no response: {response}")
        recomputed = token_digest(repeat_directory / "tokens.txt")
        if recomputed != row["tokens_sha256"]:
            raise SummaryError(
                f"repeat {repeat} token digest differs from its retained row: "
                f"{recomputed} against {row['tokens_sha256']}"
            )
        digests.append(recomputed)
        rates.append(
            positive_float(
                row["decode_tok_per_second"], "decode_tok_per_second", directory
            )
        )
    identity = "held" if len(set(digests)) == 1 else "diverged"
    return ArmSummary(
        slot=require(load, "slot", directory / "load.tsv"),
        role=require(load, "role", directory / "load.tsv"),
        load_wall_ms=positive_float(
            require(load, "load_wall_ms", directory / "load.tsv"),
            "load_wall_ms",
            directory / "load.tsv",
        ),
        ttft_ms=positive_float(
            require(ttft, "ttft_ms", directory / "ttft.tsv"),
            "ttft_ms",
            directory / "ttft.tsv",
        ),
        decode_rates=tuple(rates),
        token_identity=identity,
        clock_samples=count_samples(directory / "clock-samples.tsv"),
    )


def paired_delta(arms: list[ArmSummary]) -> str:
    """The bracket's own verdict input: the candidate mean over the control mean.

    A `C K K C` quadruple holds every candidate arm between two control arms, so
    the ratio is taken over the whole role rather than pair by pair; the reader
    that promotes or refutes reads this value beside the per-arm spread.
    """
    control = [arm.decode_mean for arm in arms if arm.role == "control"]
    candidate = [arm.decode_mean for arm in arms if arm.role == "candidate"]
    if not control or not candidate:
        return "-"
    return f"{statistics.fmean(candidate) / statistics.fmean(control):.6f}"


def summarize(output_directory: Path) -> str:
    arms_root = output_directory / "arms"
    if not arms_root.is_dir():
        raise SummaryError(f"output directory holds no arms directory: {arms_root}")
    directories = sorted(entry for entry in arms_root.iterdir() if entry.is_dir())
    if not directories:
        raise SummaryError(f"arms directory holds no arm: {arms_root}")
    arms = [summarize_arm(directory) for directory in directories]
    lines = [
        "\t".join(
            (
                "slot",
                "role",
                "load_wall_ms",
                "ttft_ms",
                "decode_tok_per_second_mean",
                "decode_spread",
                "repeats",
                "token_identity",
                "clock_samples",
            )
        )
    ]
    for arm in arms:
        lines.append(
            "\t".join(
                (
                    arm.slot,
                    arm.role,
                    f"{arm.load_wall_ms:.3f}",
                    f"{arm.ttft_ms:.3f}",
                    f"{arm.decode_mean:.6f}",
                    f"{arm.decode_spread:.6f}",
                    str(len(arm.decode_rates)),
                    arm.token_identity,
                    str(arm.clock_samples),
                )
            )
        )
    identity = (
        "held" if all(arm.token_identity == "held" for arm in arms) else "diverged"
    )
    lines.append("")
    lines.append(f"schema\t{SCHEMA}")
    lines.append(f"arms\t{len(arms)}")
    lines.append(f"token_identity\t{identity}")
    lines.append(f"candidate_over_control\t{paired_delta(arms)}")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    write = False
    arguments = list(argv[1:])
    if arguments and arguments[-1] == "--write":
        write = True
        arguments.pop()
    if len(arguments) != 1:
        sys.stderr.write(
            "usage: summarize-checkpoint-baseline.py OUTPUT_DIRECTORY [--write]\n"
        )
        return 2
    output_directory = Path(arguments[0])
    try:
        text = summarize(output_directory)
    except SummaryError as error:
        sys.stderr.write(f"checkpoint baseline summary failed: {error}\n")
        return 1
    summary_path = output_directory / "summary.tsv"
    if write:
        summary_path.write_text(text, encoding="utf-8")
    elif summary_path.is_file() and summary_path.read_text(encoding="utf-8") != text:
        sys.stderr.write(
            f"retained summary differs from the recomputation: {summary_path}\n"
        )
        return 1
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
