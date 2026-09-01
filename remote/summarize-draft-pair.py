#!/usr/bin/env python3
"""Summarize one ABBA draft-pair measurement from retained server replies."""

from __future__ import annotations

import json
import hashlib
import math
import sys
from dataclasses import dataclass
from pathlib import Path


ARM_MODES = (
    ("control-open", "control"),
    ("pair-first", "pair"),
    ("pair-second", "pair"),
    ("control-close", "control"),
)
FIELDS = (
    "arm",
    "mode",
    "prompt",
    "predicted_n",
    "decode_tok_s",
    "drafted",
    "accepted",
    "acceptance",
    "target_steps",
    "tokens_per_target_step",
    "token_sha256",
    "request_sha256",
    "prompt_identity",
    "request_identity",
    "response_sha256",
    "listener_identity",
)


@dataclass(frozen=True)
class Measurement:
    arm: str
    mode: str
    prompt: str
    predicted: int | None
    rate: float | None
    drafted: int | None
    accepted: int | None
    tokens: tuple[int, ...] | None
    request_sha256: str | None
    response_sha256: str | None
    prompt_identity: bool
    request_identity: bool
    draft_counter_keys_present: bool
    listener_identity: bool

    @property
    def acceptance(self) -> float | None:
        if self.drafted is None or self.drafted <= 0 or self.accepted is None:
            return None
        return self.accepted / self.drafted

    @property
    def target_steps(self) -> int | None:
        if self.predicted is None or self.accepted is None:
            return None
        steps = self.predicted - self.accepted - 1
        return steps if steps > 0 else None

    @property
    def tokens_per_target_step(self) -> float | None:
        if self.predicted is None or self.target_steps is None:
            return None
        return (self.predicted - 1) / self.target_steps

    @property
    def token_sha256(self) -> str | None:
        if self.tokens is None:
            return None
        encoded = json.dumps(self.tokens, separators=(",", ":")).encode("ascii")
        return hashlib.sha256(encoded).hexdigest()


def fail(message: str) -> None:
    raise ValueError(message)


def parse_positive_integer(value: object) -> int | None:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        return None
    return value


def parse_nonnegative_integer(value: object) -> int | None:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        return None
    return value


def parse_positive_number(value: object) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    parsed = float(value)
    if not math.isfinite(parsed) or parsed <= 0:
        return None
    return parsed


def parse_tokens(value: object) -> tuple[int, ...] | None:
    if not isinstance(value, list) or not value:
        return None
    if any(
        isinstance(token, bool) or not isinstance(token, int) or token < 0
        for token in value
    ):
        return None
    return tuple(value)


def load_prompts(prompt_path: Path) -> tuple[tuple[str, str], ...]:
    prompts: list[tuple[str, str]] = []
    for line_number, line in enumerate(
        prompt_path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line.strip():
            continue
        fields = line.split("\t", 1)
        if len(fields) != 2 or not fields[0] or not fields[1]:
            fail(f"invalid prompt row {line_number}: {prompt_path}")
        prompts.append((fields[0], fields[1]))
    if not prompts:
        fail(f"prompt file holds no rows: {prompt_path}")
    if len({name for name, _text in prompts}) != len(prompts):
        fail(f"prompt file holds duplicate names: {prompt_path}")
    return tuple(prompts)


def load_measurement(
    output_directory: Path,
    arm: str,
    mode: str,
    prompt: str,
    expected_prompt_text: str,
    expected_prediction: int,
    expected_seed: int,
) -> Measurement:
    request_path = output_directory / arm / f"{prompt}.request.json"
    try:
        request_bytes = request_path.read_bytes()
        request_payload = json.loads(request_bytes.decode("utf-8"))
        request_sha256 = hashlib.sha256(request_bytes).hexdigest()
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        request_payload = {}
        request_sha256 = None
    prompt_identity = (
        isinstance(request_payload, dict)
        and request_payload.get("prompt") == expected_prompt_text
    )
    expected_request = {
        "prompt": expected_prompt_text,
        "n_predict": expected_prediction,
        "temperature": 0,
        "top_k": 1,
        "seed": expected_seed,
        "cache_prompt": False,
        "stream": False,
        "return_tokens": True,
        "ignore_eos": True,
    }
    request_identity = isinstance(request_payload, dict) and set(
        request_payload
    ) == set(expected_request)
    if request_identity:
        request_identity = all(
            type(request_payload[field]) is type(expected_value)
            and request_payload[field] == expected_value
            for field, expected_value in expected_request.items()
        )
    response_path = output_directory / arm / f"{prompt}.json"
    try:
        response_bytes = response_path.read_bytes()
        response_sha256 = hashlib.sha256(response_bytes).hexdigest()
        payload = json.loads(response_bytes.decode("utf-8"))
    except OSError:
        response_sha256 = None
        payload = {}
    except (UnicodeDecodeError, json.JSONDecodeError):
        payload = {}
    if not isinstance(payload, dict):
        payload = {}
    timings = payload.get("timings")
    if not isinstance(timings, dict):
        timings = {}
    listener_path = output_directory / arm / f"{prompt}.listener.tsv"
    try:
        listener_lines = listener_path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        listener_lines = []
    listener_identity = False
    if len(listener_lines) == 2:
        listener_header = listener_lines[0].split("\t")
        listener_values = listener_lines[1].split("\t")
        listener_identity = (
            listener_header
            == [
                "pid",
                "starttime",
                "inode_before",
                "inode_after",
                "state",
            ]
            and len(listener_values) == 5
            and all(value.isdigit() for value in listener_values[:4])
            and listener_values[2] == listener_values[3]
            and listener_values[4] == "accepted"
        )
    return Measurement(
        arm=arm,
        mode=mode,
        prompt=prompt,
        predicted=parse_positive_integer(timings.get("predicted_n")),
        rate=parse_positive_number(timings.get("predicted_per_second")),
        drafted=parse_nonnegative_integer(timings.get("draft_n")),
        accepted=parse_nonnegative_integer(timings.get("draft_n_accepted")),
        tokens=parse_tokens(payload.get("tokens")),
        request_sha256=request_sha256,
        response_sha256=response_sha256,
        prompt_identity=prompt_identity,
        request_identity=request_identity,
        draft_counter_keys_present=(
            "draft_n" in timings or "draft_n_accepted" in timings
        ),
        listener_identity=listener_identity,
    )


def show(value: float | None, digits: int = 3) -> str:
    if value is None:
        return "-"
    return f"{value:.{digits}f}"


def render_row(measurement: Measurement) -> tuple[str, ...]:
    return (
        measurement.arm,
        measurement.mode,
        measurement.prompt,
        "-" if measurement.predicted is None else str(measurement.predicted),
        show(measurement.rate, 2),
        "-" if measurement.drafted is None else str(measurement.drafted),
        "-" if measurement.accepted is None else str(measurement.accepted),
        show(measurement.acceptance),
        ("-" if measurement.target_steps is None else str(measurement.target_steps)),
        show(measurement.tokens_per_target_step, 2),
        measurement.token_sha256 or "-",
        measurement.request_sha256 or "-",
        "accepted" if measurement.prompt_identity else "rejected",
        "accepted" if measurement.request_identity else "rejected",
        measurement.response_sha256 or "-",
        "accepted" if measurement.listener_identity else "rejected",
    )


def aggregate_rate(measurements: list[Measurement]) -> float | None:
    if not measurements or any(
        item.predicted is None or item.rate is None for item in measurements
    ):
        return None
    tokens = sum(
        item.predicted - 1 for item in measurements if item.predicted is not None
    )
    seconds = math.fsum(
        (item.predicted - 1) / item.rate
        for item in measurements
        if item.predicted is not None and item.rate is not None
    )
    return tokens / seconds if seconds > 0 else None


def ratio(numerator: float | None, denominator: float | None) -> float | None:
    if numerator is None or denominator is None or denominator <= 0:
        return None
    return numerator / denominator


def write_summary(path: Path, rows: tuple[tuple[str, str], ...]) -> None:
    path.write_text(
        "".join(f"{field}={value}\n" for field, value in rows),
        encoding="utf-8",
    )


def summarize(
    output_directory: Path,
    draft_n_max: int,
    acceptance_floor: float,
    acceptance_floor_text: str,
    prompt_path: Path,
    predict_tokens: int,
    sampling_seed: int,
) -> int:
    prompt_rows = load_prompts(prompt_path)
    prompts = tuple(name for name, _text in prompt_rows)
    measurements = [
        load_measurement(
            output_directory,
            arm,
            mode,
            prompt,
            prompt_text,
            predict_tokens,
            sampling_seed,
        )
        for arm, mode in ARM_MODES
        for prompt, prompt_text in prompt_rows
    ]

    arms_path = output_directory / "arms.tsv"
    arms_path.write_text(
        "\t".join(FIELDS)
        + "\n"
        + "".join("\t".join(render_row(item)) + "\n" for item in measurements),
        encoding="utf-8",
    )

    missing = sorted(
        f"{item.arm}:{item.prompt}"
        for item in measurements
        if item.predicted is None or item.rate is None or item.tokens is None
    )
    summary_path = output_directory / "summary.txt"
    prompt_mismatches = sorted(
        f"{item.arm}:{item.prompt}" for item in measurements if not item.prompt_identity
    )
    if prompt_mismatches:
        rows = (
            ("draft_n_max", str(draft_n_max)),
            ("acceptance_floor", acceptance_floor_text),
            ("state", "failed"),
            ("reason", "prompt_mismatch"),
            ("requests", ",".join(prompt_mismatches)),
        )
        write_summary(summary_path, rows)
        print(summary_path.read_text(encoding="utf-8"), end="")
        print(
            "one or more retained requests differ from the prompt corpus",
            file=sys.stderr,
        )
        return 1
    request_mismatches = sorted(
        f"{item.arm}:{item.prompt}"
        for item in measurements
        if not item.request_identity
    )
    if request_mismatches:
        rows = (
            ("draft_n_max", str(draft_n_max)),
            ("acceptance_floor", acceptance_floor_text),
            ("state", "failed"),
            ("reason", "request_mismatch"),
            ("requests", ",".join(request_mismatches)),
        )
        write_summary(summary_path, rows)
        print(summary_path.read_text(encoding="utf-8"), end="")
        print(
            "one or more retained requests differ from the fixed-length schema",
            file=sys.stderr,
        )
        return 1
    listener_mismatches = sorted(
        f"{item.arm}:{item.prompt}"
        for item in measurements
        if not item.listener_identity
    )
    if listener_mismatches:
        rows = (
            ("draft_n_max", str(draft_n_max)),
            ("acceptance_floor", acceptance_floor_text),
            ("state", "failed"),
            ("reason", "listener_identity"),
            ("requests", ",".join(listener_mismatches)),
        )
        write_summary(summary_path, rows)
        print(summary_path.read_text(encoding="utf-8"), end="")
        print(
            "one or more completion requests lack one stable listener identity",
            file=sys.stderr,
        )
        return 1
    if missing:
        rows = (
            ("draft_n_max", str(draft_n_max)),
            ("acceptance_floor", acceptance_floor_text),
            ("state", "failed"),
            ("reason", "measurement_absent"),
            ("requests", ",".join(missing)),
        )
        write_summary(summary_path, rows)
        print(summary_path.read_text(encoding="utf-8"), end="")
        print("one or more requests produced no complete measurement", file=sys.stderr)
        return 1

    incomplete = sorted(
        f"{item.arm}:{item.prompt}"
        for item in measurements
        if item.predicted != predict_tokens
        or item.tokens is None
        or len(item.tokens) != predict_tokens
    )
    if incomplete:
        rows = (
            ("draft_n_max", str(draft_n_max)),
            ("acceptance_floor", acceptance_floor_text),
            ("state", "failed"),
            ("reason", "measurement_incomplete"),
            ("requests", ",".join(incomplete)),
        )
        write_summary(summary_path, rows)
        print(summary_path.read_text(encoding="utf-8"), end="")
        print(
            "one or more responses stopped before the fixed prediction length",
            file=sys.stderr,
        )
        return 1

    control_draft_counters = sorted(
        f"{item.arm}:{item.prompt}"
        for item in measurements
        if item.mode == "control" and item.draft_counter_keys_present
    )
    if control_draft_counters:
        rows = (
            ("draft_n_max", str(draft_n_max)),
            ("acceptance_floor", acceptance_floor_text),
            ("state", "failed"),
            ("reason", "control_draft_counters"),
            ("requests", ",".join(control_draft_counters)),
        )
        write_summary(summary_path, rows)
        print(summary_path.read_text(encoding="utf-8"), end="")
        print("one or more control replies report draft counters", file=sys.stderr)
        return 1

    pair_measurements = [item for item in measurements if item.mode == "pair"]
    draft_absent = sorted(
        {
            item.arm
            for item in pair_measurements
            if item.drafted is None or item.drafted <= 0 or item.accepted is None
        }
    )
    if draft_absent:
        rows = (
            ("draft_n_max", str(draft_n_max)),
            ("acceptance_floor", acceptance_floor_text),
            ("state", "failed"),
            ("reason", "draft_absent"),
            ("arms", ",".join(draft_absent)),
        )
        write_summary(summary_path, rows)
        print(summary_path.read_text(encoding="utf-8"), end="")
        print(
            "a pair arm reported no valid drafted tokens; read that arm server.log "
            "for the speculative decoding line",
            file=sys.stderr,
        )
        return 1

    draft_geometry_invalid = sorted(
        f"{item.arm}:{item.prompt}"
        for item in pair_measurements
        if item.drafted is not None
        and item.accepted is not None
        and (
            item.accepted > item.drafted
            or item.target_steps is None
            or item.drafted > draft_n_max * item.target_steps
        )
    )
    if draft_geometry_invalid:
        rows = (
            ("draft_n_max", str(draft_n_max)),
            ("acceptance_floor", acceptance_floor_text),
            ("state", "failed"),
            ("reason", "draft_geometry_invalid"),
            ("requests", ",".join(draft_geometry_invalid)),
        )
        write_summary(summary_path, rows)
        print(summary_path.read_text(encoding="utf-8"), end="")
        print(
            "one or more pair replies exceed the configured draft batch geometry",
            file=sys.stderr,
        )
        return 1

    arm_rates = {
        arm: aggregate_rate([item for item in measurements if item.arm == arm])
        for arm, _mode in ARM_MODES
    }
    control_rate = aggregate_rate(
        [item for item in measurements if item.mode == "control"]
    )
    pair_rate = aggregate_rate(pair_measurements)
    first_ratio = ratio(arm_rates["pair-first"], arm_rates["control-open"])
    second_ratio = ratio(arm_rates["pair-second"], arm_rates["control-close"])
    overall_ratio = ratio(pair_rate, control_rate)

    acceptance_values = [item.acceptance for item in pair_measurements]
    minimum_acceptance = min(value for value in acceptance_values if value is not None)
    total_drafted = sum(item.drafted or 0 for item in pair_measurements)
    total_accepted = sum(item.accepted or 0 for item in pair_measurements)
    weighted_acceptance = total_accepted / total_drafted
    total_target_steps = sum(item.target_steps or 0 for item in pair_measurements)
    tokens_per_target_step = 1 + total_accepted / total_target_steps

    performance_gate = (
        "accepted"
        if first_ratio is not None
        and first_ratio >= 1.0
        and second_ratio is not None
        and second_ratio >= 1.0
        else "rejected"
    )
    acceptance_gate = (
        "accepted" if minimum_acceptance >= acceptance_floor else "rejected"
    )
    token_identity_gate = "accepted"
    for prompt in prompts:
        prompt_tokens = [item.tokens for item in measurements if item.prompt == prompt]
        if not prompt_tokens or any(
            tokens != prompt_tokens[0] for tokens in prompt_tokens
        ):
            token_identity_gate = "rejected"
            break
    if (
        performance_gate == "accepted"
        and acceptance_gate == "accepted"
        and token_identity_gate == "accepted"
    ):
        admission_gate = "accepted"
    elif draft_n_max > 1:
        admission_gate = "retry-n-max-1"
    else:
        admission_gate = "rejected"

    rows = (
        ("draft_n_max", str(draft_n_max)),
        ("acceptance_floor", acceptance_floor_text),
        ("state", "completed"),
        ("control_open_decode_tok_s", show(arm_rates["control-open"])),
        ("pair_first_decode_tok_s", show(arm_rates["pair-first"])),
        ("pair_second_decode_tok_s", show(arm_rates["pair-second"])),
        ("control_close_decode_tok_s", show(arm_rates["control-close"])),
        ("control_mean_decode_tok_s", show(control_rate)),
        ("pair_mean_decode_tok_s", show(pair_rate)),
        ("pair_first_over_control_open", show(first_ratio, 4)),
        ("pair_second_over_control_close", show(second_ratio, 4)),
        ("pair_over_control", show(overall_ratio, 4)),
        ("pair_acceptance_min", show(minimum_acceptance, 4)),
        ("pair_acceptance_weighted", show(weighted_acceptance, 4)),
        ("pair_tokens_per_target_step", show(tokens_per_target_step, 3)),
        ("performance_gate", performance_gate),
        ("acceptance_gate", acceptance_gate),
        ("token_identity_gate", token_identity_gate),
        ("admission_gate", admission_gate),
    )
    write_summary(summary_path, rows)
    print(summary_path.read_text(encoding="utf-8"), end="")
    return 0


def main(arguments: list[str]) -> int:
    if len(arguments) != 6:
        print(
            "usage: summarize-draft-pair.py OUTPUT_DIRECTORY "
            "DRAFT_N_MAX ACCEPTANCE_FLOOR PROMPT_FILE PREDICT_TOKENS SEED",
            file=sys.stderr,
        )
        return 2
    output_directory = Path(arguments[0]).resolve()
    try:
        draft_n_max = int(arguments[1])
        acceptance_floor_text = arguments[2]
        acceptance_floor = float(acceptance_floor_text)
        predict_tokens = int(arguments[4])
        sampling_seed = int(arguments[5])
        if draft_n_max <= 0:
            fail("DRAFT_N_MAX must be positive")
        if predict_tokens <= 1:
            fail("PREDICT_TOKENS must exceed the free first token")
        if not math.isfinite(acceptance_floor) or not 0 <= acceptance_floor <= 1:
            fail("ACCEPTANCE_FLOOR must be inside [0,1]")
        return summarize(
            output_directory,
            draft_n_max,
            acceptance_floor,
            acceptance_floor_text,
            Path(arguments[3]).resolve(),
            predict_tokens,
            sampling_seed,
        )
    except (OSError, ValueError) as error:
        print(f"draft-pair summary refused: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
