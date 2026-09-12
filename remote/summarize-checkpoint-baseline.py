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
import json
import math
import re
import statistics
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

SCHEMA = "checkpoint-baseline-summary-v2"
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
    if not math.isfinite(value) or not value > 0:
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
    token_digests: tuple[str, ...]

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
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line:
            continue
        try:
            ids.append(str(int(line)))
        except ValueError:
            raise SummaryError(f"token record line {number} is not an integer: {path}") from None
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
    samples = [
        line for line in path.read_text(encoding="utf-8").splitlines() if line and line[0].isdigit()
    ]
    if not samples:
        raise SummaryError(f"clock sidecar record holds no sample: {path}")
    return len(samples)


def integer(text: str, name: str, minimum: int = 0, maximum: int = 2**63 - 1) -> int:
    if not re.fullmatch(r"0|[1-9][0-9]{0,18}", text):
        raise SummaryError(f"{name} requires a canonical bounded integer: {text}")
    value = int(text)
    if not minimum <= value <= maximum:
        raise SummaryError(f"{name} outside [{minimum}, {maximum}]: {value}")
    return value


def read_json(path: Path) -> dict[str, object]:
    if not path.is_file() or path.is_symlink():
        raise SummaryError(f"repeat retained no response or request: {path}")
    try:
        value = json.loads(path.read_text())
    except (ValueError, UnicodeError) as error:
        raise SummaryError(f"malformed JSON: {path}: {error}") from error
    if not isinstance(value, dict):
        raise SummaryError(f"JSON object required: {path}")
    return value


def response_values(document: dict[str, object], predict: int) -> tuple[str, float, float, int]:
    tokens = document.get("tokens")
    if (
        not isinstance(tokens, list)
        or len(tokens) != predict
        or any(type(token) is not int or token < 0 for token in tokens)
    ):
        raise SummaryError("raw response token population differs from the request")
    timings = document.get("timings")
    if not isinstance(timings, dict):
        raise SummaryError("raw response requires timings")
    if timings.get("draft_n", 0) != 0:
        raise SummaryError("ordinary baseline refuses speculative timing population")
    for name in ("predicted_n", "prompt_n"):
        value = timings.get(name)
        if type(value) is not int or value < 1:
            raise SummaryError(f"raw {name} requires a positive integer")
    if timings["predicted_n"] != predict:
        raise SummaryError("raw predicted_n differs from the request")
    numbers: list[float] = []
    for name in ("predicted_per_second", "predicted_ms"):
        value = timings.get(name)
        if type(value) not in (float, int):
            raise SummaryError(f"raw {name} requires a finite number")
        numbers.append(positive_float(str(value), name, Path("response.json")))
    rate, elapsed = numbers
    # The pinned ordinary completion times predicted_n - 1 decode transitions.
    if not math.isclose(rate * elapsed / 1000, predict - 1, rel_tol=0.002, abs_tol=0.002):
        raise SummaryError("raw decode rate, elapsed time and transition count disagree")
    return "".join(f"{token}\n" for token in tokens), rate, elapsed, timings["prompt_n"]


def summarize_arm(directory: Path) -> ArmSummary:
    identity = read_key_value(directory.parent.parent / "identity.tsv")
    repeats = integer(require(identity, "repeats", directory), "repeats", 2, 16)
    predict = integer(require(identity, "generate_tokens", directory), "generate_tokens", 2, 32768)
    terminal = read_key_value(directory / "terminal.tsv")
    if any(
        terminal.get(key) != value
        for key, value in {
            "status": "completed",
            "sidecar_status": "0",
            "validator_status": "0",
            "teardown_status": "0",
            "quiescence_status": "0",
        }.items()
    ):
        raise SummaryError(f"arm terminal admission failed: {directory}")
    validation = (directory / "clock-validation.txt").read_text()
    if (
        "clock_sidecar=accepted failures=-" not in validation
        or "clock_sidecar=refused" in validation
        or "clock_invariant=held" not in validation
        or "sclk_source=sclk_actual_mhz" not in validation
    ):
        raise SummaryError(f"clock validation refused or has another source: {directory}")
    count_samples(directory / "clock-samples.tsv")
    contract = read_key_value(directory.parent.parent / "sampler-contract.tsv")
    window_record = read_key_value(directory / "decode-window.tsv")
    arguments = [
        str(Path(__file__).with_name("validate-clock-sidecar.py")),
        str(directory / "clock-samples.tsv"),
        "--sidecar-status",
        terminal["sidecar_status"],
        "--window-begin-ns",
        window_record["begin_ns"],
        "--window-end-ns",
        window_record["end_ns"],
        "--required-sclk-mhz",
        identity["required_sclk_mhz"],
        "--required-mclk-mhz",
        identity["mclk_floor_mhz"],
    ]
    for key, flag in (
        ("period_ms", "period-ms"),
        ("period_tolerance", "period-tolerance"),
        ("cost_bound_ns", "cost-bound-ns"),
        ("max_gap_ns", "max-gap-ns"),
        ("max_lost_fraction", "max-lost-fraction"),
        ("nice", "expected-nice"),
        ("cpu_affinity", "expected-cpu-affinity"),
    ):
        arguments.extend([f"--{flag}", contract[key]])
    arguments.extend(["--allow-unavailable", contract["allowed_unavailable"]])
    # The current validator reprocesses raw telemetry; acquired code stays evidence.
    validation_run = subprocess.run(arguments, capture_output=True, text=True, timeout=15)
    if validation_run.returncode or "sclk_source=sclk_actual_mhz" not in validation_run.stdout:
        raise SummaryError(
            f"raw clock admission failed: {validation_run.stdout} {validation_run.stderr}"
        )
    process = read_key_value(directory / "process-identity.tsv")
    role = read_key_value(directory / "arm-inputs.tsv")["role"]
    for name in ("threads", "threads_batch", "device", "gpu_layers", "q4k_variant"):
        if process.get(name) != identity.get(name):
            raise SummaryError(f"process {name} differs from acquisition identity")
    served = read_key_value(directory / "served-tuple.tsv")
    argv = json.loads((directory / "server-argv.json").read_text())
    if not isinstance(argv, list) or any(not isinstance(value, str) for value in argv):
        raise SummaryError("server argv requires an array of strings")
    for flag, name in (
        ("--ctx-size", "context"),
        ("--batch-size", "batch"),
        ("--ubatch-size", "ubatch"),
        ("--cache-type-k", "cache_type_k"),
        ("--cache-type-v", "cache_type_v"),
        ("--flash-attn", "flash_attention"),
        ("--ctx-checkpoints", "ctx_checkpoints"),
    ):
        indices = [index for index, value in enumerate(argv) if value == flag]
        if (
            len(indices) != 1
            or indices[0] + 1 >= len(argv)
            or argv[indices[0] + 1] != served.get(name)
            or served.get(name) != identity.get(f"registry_{name}")
        ):
            raise SummaryError(f"served {name} differs from argv or registry")
    for flag, name in (
        ("--threads", "threads"),
        ("--threads-batch", "threads_batch"),
        ("--device", "device"),
        ("--n-gpu-layers", "gpu_layers"),
        ("--model", "model"),
        ("--parallel", "parallel"),
    ):
        indices = [index for index, value in enumerate(argv) if value == flag]
        if (
            len(indices) != 1
            or indices[0] + 1 >= len(argv)
            or argv[indices[0] + 1] != process.get(name)
        ):
            raise SummaryError(f"process {name} differs from retained argv")
    binary_role = "candidate" if role == "candidate" else "control"
    if process.get("server_sha256") != identity.get(f"{binary_role}_server_sha256"):
        raise SummaryError("process executable differs from registered role")
    load = read_key_value(directory / "load.tsv")
    ttft = read_key_value(directory / "ttft.tsv")
    rows = read_decode_rows(directory / "decode-rows.tsv")
    expected = [f"{index:02d}" for index in range(1, repeats + 1)]
    if [row["repeat"] for row in rows] != expected:
        raise SummaryError(f"expected ordered unique repeats {expected}: {directory}")
    if sorted(entry.name for entry in (directory / "repeats").iterdir()) != expected:
        raise SummaryError(f"repeat directory population differs: {directory}")
    warmup = read_json(directory / "warmup-response.json")
    if warmup.get("stop") is not True:
        raise SummaryError("warmup requires a completed terminal response")
    stream = (directory / "warmup.sse").read_text()
    events = [
        json.loads(line[6:])
        for line in stream.splitlines()
        if line.startswith("data: ") and line[6:] != "[DONE]"
    ]
    if not events or events[-1] != warmup or not any(event.get("content") for event in events):
        raise SummaryError("retained stream disagrees with its terminal response")
    warmup_tokens = [token for event in events for token in event.get("tokens", [])]
    reconstructed = dict(warmup)
    reconstructed["tokens"] = warmup_tokens
    response_values(reconstructed, predict)
    begin = integer(require(ttft, "request_begin_ns", directory), "request_begin_ns", 1)
    first = integer(require(ttft, "first_content_ns", directory), "first_content_ns", begin)
    complete = integer(require(ttft, "response_end_ns", directory), "response_end_ns", first)
    if complete <= first or ttft.get("status") != "completed":
        raise SummaryError("warmup completion chronology failed")
    ttft_ms = positive_float(require(ttft, "ttft_ms", directory), "ttft_ms", directory)
    if abs(ttft_ms - (first - begin) / 1e6) > 0.002:
        raise SummaryError("first-content timing disagrees with monotonic timestamps")
    load_ms = positive_float(require(load, "load_wall_ms", directory), "load_wall_ms", directory)
    launch_begin = integer(require(load, "launch_begin_ns", directory), "launch_begin_ns", 1)
    ready = integer(
        require(load, "health_ready_ns", directory), "health_ready_ns", launch_begin + 1
    )
    if abs(load_ms - (ready - launch_begin) / 1e6) > 0.002 or ready > begin:
        raise SummaryError("load timing disagrees with request chronology")
    rates: list[float] = []
    digests: list[str] = []
    for row in rows:
        repeat_directory = directory / "repeats" / row["repeat"]
        document = read_json(repeat_directory / "response.json")
        token_text, rate, elapsed, prompt_n = response_values(document, predict)
        recomputed = token_digest(repeat_directory / "tokens.txt")
        if (
            recomputed != row["tokens_sha256"]
            or (repeat_directory / "tokens.txt").read_text() != token_text
            or recomputed != hashlib.sha256(token_text.encode()).hexdigest()
        ):
            raise SummaryError("token digest differs from raw response or retained row")
        for key, value in (("decode_tok_per_second", rate), ("decode_ms", elapsed)):
            if not math.isclose(positive_float(row[key], key, directory), value, rel_tol=1e-9):
                raise SummaryError(f"derived {key} differs from raw response")
        if (
            integer(row["predicted_n"], "predicted_n") != predict
            or integer(row["prompt_n"], "prompt_n") != prompt_n
        ):
            raise SummaryError("derived counts differ from raw response")
        request_time = read_key_value(repeat_directory / "request-time.tsv")
        request_begin = integer(require(request_time, "begin_ns", directory), "begin_ns", complete)
        complete = integer(require(request_time, "end_ns", directory), "end_ns", request_begin + 1)
        # Server decode time is contained in the completed HTTP request interval.
        if elapsed > (complete - request_begin) / 1e6 + 2:
            raise SummaryError("server decode time exceeds request elapsed time")
        digests.append(recomputed)
        rates.append(rate)
    samples = count_samples(directory / "clock-samples.tsv")
    window = read_key_value(directory / "decode-window.tsv")
    window_begin = integer(require(window, "begin_ns", directory), "window begin", 1)
    window_end = integer(require(window, "end_ns", directory), "window end", complete)
    sample_times = [
        int(line.split("\t")[0])
        for line in (directory / "clock-samples.tsv").read_text().splitlines()
        if line and line[0].isdigit()
    ]
    if not sample_times or min(sample_times) > window_begin or max(sample_times) < window_end:
        raise SummaryError("sampler requires covering samples before and after decode")
    return ArmSummary(
        slot=require(load, "slot", directory),
        role=require(load, "role", directory),
        load_wall_ms=load_ms,
        ttft_ms=ttft_ms,
        decode_rates=tuple(rates),
        token_identity="held" if len(set(digests)) == 1 else "diverged",
        clock_samples=samples,
        token_digests=tuple(digests),
    )


def paired_delta(arms: list[ArmSummary]) -> str:
    """Descriptive ratio over two launches per role; inference needs a separate design."""
    control = [arm.decode_mean for arm in arms if arm.role == "control"]
    candidate = [arm.decode_mean for arm in arms if arm.role == "candidate"]
    if not control or not candidate:
        return "-"
    return f"{statistics.fmean(candidate) / statistics.fmean(control):.6f}"


def summarize(output_directory: Path) -> str:
    identity = read_key_value(output_directory / "identity.tsv")
    if identity.get("schema") != "checkpoint-baseline-identity-v2":
        raise SummaryError(
            "acquisition requires the baseline v2 contract; retain older acquisition identity"
        )
    for name in (
        "runtime-tree-manifest.tsv",
        "runtime-source.tar",
        "acquisition-reader.py",
        "acquisition-lib.sh",
        "acquisition-runner.sh",
        "acquisition-clock-validator.py",
        "acquisition-sampler",
        "acquisition-sampler.c",
        "acquisition-lease.sh",
        "compute-state.tsv",
        "sampler-contract.tsv",
    ):
        path = output_directory / name
        if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != identity.get(
            f"{name}_sha256"
        ):
            raise SummaryError(f"acquisition input digest differs: {name}")
    for role in ("control", "candidate"):
        if identity.get(f"{role}_manifest_sha256") != "-":
            if hashlib.sha256(
                (output_directory / f"{role}-manifest.tsv").read_bytes()
            ).hexdigest() != identity.get(f"{role}_manifest_sha256"):
                raise SummaryError(f"{role} manifest digest differs")
    mode = require(identity, "mode", output_directory)
    roles = {
        "single": ["subject"],
        "bracket": ["control", "candidate", "candidate", "control"],
    }.get(mode)
    if roles is None:
        raise SummaryError("unregistered baseline mode")
    expected = [f"{index:02d}-{role}" for index, role in enumerate(roles, 1)]
    arms_root = output_directory / "arms"
    if sorted(entry.name for entry in arms_root.iterdir()) != expected:
        raise SummaryError(f"expected complete ordered arm population {expected}")
    arm_rows = (output_directory / "arms.tsv").read_text().splitlines()
    if (
        len(arm_rows) != len(roles) + 1
        or arm_rows[0] != "slot\tarm\trole\tserver_sha256\tstatus\treason"
    ):
        raise SummaryError("arm terminal ledger population differs")
    for index, (role, line) in enumerate(zip(roles, arm_rows[1:], strict=True), 1):
        letter = "B" if mode == "single" else ("K" if role == "candidate" else "C")
        digest = identity.get(f"{'candidate' if role == 'candidate' else 'control'}_server_sha256")
        if line.split("\t") != [f"{index:02d}", letter, role, digest, "completed", "-"]:
            raise SummaryError(
                "arm terminal ledger disagrees with registered order/identity/status"
            )
    for name, stream in (("ttft", True), ("decode", False)):
        path = output_directory / f"request-{name}.json"
        request = read_json(path)
        if hashlib.sha256(path.read_bytes()).hexdigest() != identity.get(f"{name}_request_sha256"):
            raise SummaryError("request digest differs")
        for key, value in {
            "n_predict": int(identity["generate_tokens"]),
            "temperature": 0,
            "top_k": 1,
            "seed": 1,
            "ignore_eos": True,
            "cache_prompt": False,
            "return_tokens": True,
            "stream": stream,
        }.items():
            if request.get(key) != value or type(request.get(key)) is not type(value):
                raise SummaryError(f"request {key} differs from registered sampling")
    streamed = read_json(output_directory / "request-ttft.json")
    decoded = read_json(output_directory / "request-decode.json")
    streamed["stream"] = False
    if streamed != decoded:
        raise SummaryError("warmup and repeats request different computations")
    arms = [summarize_arm(arms_root / name) for name in expected]
    for index, arm in enumerate(arms, 1):
        if arm.slot != f"{index:02d}" or arm.role != roles[index - 1]:
            raise SummaryError("arm load identity differs from registered order")
    lines = [
        "\t".join(
            (
                "slot",
                "role",
                "load_wall_ms",
                "first_content_latency_ms",
                "decode_tok_per_second_mean",
                "decode_spread",
                "repeats",
                "within_arm_repeatability",
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
    by_role: dict[str, set[str]] = {}
    for arm in arms:
        by_role.setdefault(arm.role, set()).update(arm.token_digests)
    repeatability = "held" if all(len(digests) == 1 for digests in by_role.values()) else "diverged"
    lines.append("")
    lines.append(f"schema\t{SCHEMA}")
    lines.append(f"arms\t{len(arms)}")
    lines.append(f"within_binary_repeatability\t{repeatability}")
    cross = (
        "not_applicable"
        if mode == "single"
        else (
            "identical"
            if len({digest for arm in arms for digest in arm.token_digests}) == 1
            else "diverged"
        )
    )
    lines.append(f"cross_binary_token_comparison\t{cross}")
    lines.append("acquisition_completeness\tcompleted")
    lines.append("instrument_admission\taccepted")
    eligible = repeatability == "held" and cross in ("not_applicable", "identical")
    lines.append(f"performance_result\t{'descriptive' if eligible else 'withheld_correctness'}")
    lines.append(f"reader_sha256\t{hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}")
    lines.append(f"candidate_over_control\t{paired_delta(arms) if eligible else '-'}")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    write = False
    arguments = list(argv[1:])
    if arguments and arguments[-1] == "--write":
        write = True
        arguments.pop()
    if len(arguments) != 1:
        sys.stderr.write("usage: summarize-checkpoint-baseline.py OUTPUT_DIRECTORY [--write]\n")
        return 2
    output_directory = Path(arguments[0])
    try:
        text = summarize(output_directory)
    except (
        SummaryError,
        OSError,
        ValueError,
        KeyError,
        TypeError,
        subprocess.TimeoutExpired,
    ) as error:
        sys.stderr.write(f"checkpoint baseline summary failed: {error}\n")
        return 1
    summary_path = output_directory / "summary.tsv"
    if write:
        if summary_path.is_file() and summary_path.read_text() != text:
            previous = summary_path.read_bytes()
            digest = hashlib.sha256(previous).hexdigest()
            archived = output_directory / f"summary-{digest}.tsv"
            if archived.exists() and archived.read_bytes() != previous:
                raise SummaryError("analysis revision archive differs")
            archived.write_bytes(previous)
        summary_path.write_text(text, encoding="utf-8")
    elif summary_path.is_file() and summary_path.read_text(encoding="utf-8") != text:
        sys.stderr.write(f"retained summary differs from the recomputation: {summary_path}\n")
        return 1
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
