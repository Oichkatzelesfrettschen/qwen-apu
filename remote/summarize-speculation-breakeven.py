#!/usr/bin/env python3
"""Acceptance, tokens per weight traversal, and break-even for one speculation run.

A speculative round drafts N tokens, verifies N + 1 columns in one target pass,
and emits one target token beside the drafts it accepts. With acceptance `a`
the emitted count per round is `1 + sum_{k=1..N} a^k`, because
common_sampler_sample_and_accept_n breaks at the first mismatch and then samples
one token from the surviving position, so the bonus token is unconditional.

This program reads what a run measured rather than what a model predicts. Round
time comes from the served `predicted_ms` divided by the verification step count
the served token and accepted counts imply, the control rate comes from the same
run's own control arms, and the break-even acceptance is solved against that
control. The
only inputs that are not measurements are the target rate and, where the caller
supplies one, a draft-pass cost used to split the round into its draft and
verification halves.

Three counts state one accounting identity. Every round emits one target token
beside the drafts it accepts and the first token arrives from the prompt logits,
so `steps = predicted_n - draft_n_accepted - 1` exactly. That identity is the
step-count authority because it needs nothing but the response.

The /metrics counter `spec_decode_num_drafts_total` measures the same quantity
by a second route and it is reported rather than enforced.
`server_slot::release()` calls `callback_on_reset`, which is where
`metrics_on_prediction` folds a slot's draft counters into the global ones, and
`update_slots` calls `send_final_response(slot)` immediately before
`slot.release()`. The completion body therefore leaves the inference thread
ahead of the fold, so a /metrics read taken once curl returns is unordered
against it. The summary carries the comparison as `steps_agreement` over
`accepted`, `disagree`, and `absent`, and a disagreement is a lead about that
ordering rather than a reason to discard a rate the response itself supports.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

ARM_ROLES = (
    ("control-open", "control"),
    ("spec-first", "spec"),
    ("spec-second", "spec"),
    ("control-close", "control"),
)
METRIC_DRAFTED = "spec_decode_num_draft_tokens_total"
METRIC_ACCEPTED = "spec_decode_num_accepted_tokens_total"
METRIC_STEPS = "spec_decode_num_drafts_total"
ARM_FIELDS = (
    "draft_n_max",
    "arm",
    "mode",
    "prompt",
    "predicted_n",
    "predicted_ms",
    "decode_tok_s",
    "drafted",
    "accepted",
    "acceptance",
    "steps_metrics",
    "steps_inferred",
    "round_ms",
    "tokens_per_traversal",
    "token_sha256",
    "request_sha256",
    "response_sha256",
    "request_identity",
    "listener_identity",
    "accounting",
    "steps_agreement",
)
BREAKEVEN_FIELDS = (
    "draft_n_max",
    "control_tok_s",
    "spec_tok_s",
    "spec_over_control",
    "first_ratio",
    "second_ratio",
    "acceptance_weighted",
    "acceptance_min",
    "steps",
    "round_ms",
    "tokens_per_traversal",
    "ceiling_perfect_acceptance_tok_s",
    "breakeven_acceptance",
    "target_acceptance",
    "required_round_ms",
    "required_round_removal",
    "required_verify_ms",
    "required_verify_removal",
)


class Refusal(ValueError):
    """A measurement the summary refuses to score."""


@dataclass(frozen=True)
class Measurement:
    draft_n_max: int
    arm: str
    mode: str
    prompt: str
    predicted: int | None
    predicted_ms: float | None
    rate: float | None
    drafted: int | None
    accepted: int | None
    tokens: tuple[int, ...] | None
    metrics_drafted: int | None
    metrics_accepted: int | None
    metrics_steps: int | None
    request_sha256: str | None
    response_sha256: str | None
    request_identity: bool
    listener_identity: bool
    draft_counter_keys_present: bool

    @property
    def acceptance(self) -> float | None:
        if not self.drafted or self.accepted is None:
            return None
        return self.accepted / self.drafted

    @property
    def steps_inferred(self) -> int | None:
        if self.predicted is None:
            return None
        accepted = self.accepted if self.accepted is not None else 0
        steps = self.predicted - accepted - 1
        return steps if steps > 0 else None

    @property
    def round_ms(self) -> float | None:
        if self.predicted_ms is None or not self.steps_inferred:
            return None
        return self.predicted_ms / self.steps_inferred

    @property
    def tokens_per_traversal(self) -> float | None:
        if self.predicted is None or not self.steps_inferred:
            return None
        return (self.predicted - 1) / self.steps_inferred

    @property
    def token_sha256(self) -> str | None:
        if self.tokens is None:
            return None
        encoded = json.dumps(self.tokens, separators=(",", ":")).encode("ascii")
        return hashlib.sha256(encoded).hexdigest()


def emitted_per_round(acceptance: float, draft_n_max: int) -> float:
    """Expected tokens one round emits at a position-independent acceptance."""
    return 1.0 + math.fsum(acceptance**k for k in range(1, draft_n_max + 1))


def solve_acceptance(
    draft_n_max: int, round_seconds: float, rate: float, ceiling: float = 1.0
) -> float | None:
    """The acceptance reaching `rate` at this round time, or None above `ceiling`.

    The emitted count rises monotonically in acceptance, so a bisection over
    [0, ceiling] converges wherever a root exists inside it.
    """
    if round_seconds <= 0 or rate <= 0:
        return None
    if emitted_per_round(ceiling, draft_n_max) / round_seconds < rate:
        return None
    low, high = 0.0, ceiling
    for _ in range(200):
        middle = (low + high) / 2
        if emitted_per_round(middle, draft_n_max) / round_seconds < rate:
            low = middle
        else:
            high = middle
    return (low + high) / 2


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


def read_inputs(output_directory: Path) -> dict[str, str]:
    inputs_path = output_directory / "inputs.txt"
    fields: dict[str, str] = {}
    for line in inputs_path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        name, value = line.split("=", 1)
        fields[name] = value
    for required in ("mechanism", "draft_length_list", "predict_tokens", "seed"):
        if required not in fields:
            raise Refusal(f"inputs.txt names no {required}: {inputs_path}")
    return fields


def read_prompts(prompt_path: Path) -> tuple[tuple[str, str], ...]:
    prompts: list[tuple[str, str]] = []
    for number, line in enumerate(
        prompt_path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line.strip():
            continue
        row = line.split("\t", 1)
        if len(row) != 2 or not row[0] or not row[1]:
            raise Refusal(f"invalid prompt row {number}: {prompt_path}")
        prompts.append((row[0], row[1]))
    if not prompts:
        raise Refusal(f"prompt file holds no rows: {prompt_path}")
    if len({name for name, _text in prompts}) != len(prompts):
        raise Refusal(f"prompt file holds duplicate names: {prompt_path}")
    return tuple(prompts)


def read_metric(metrics_path: Path, name: str) -> int | None:
    """One Prometheus sample, read as a non-negative integer.

    llama-server prints its counters as floating-point text, so a value that is
    not integral is a counter this reader does not understand rather than a
    count it may round.
    """
    try:
        lines = metrics_path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return None
    for line in lines:
        if line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) != 2 or fields[0] != name:
            continue
        try:
            value = float(fields[1])
        except ValueError:
            return None
        if not math.isfinite(value) or value < 0 or value != int(value):
            return None
        return int(value)
    return None


def metric_delta(arm_directory: Path, prompt: str, name: str) -> int | None:
    before = read_metric(arm_directory / f"{prompt}.metrics-before.txt", name)
    after = read_metric(arm_directory / f"{prompt}.metrics-after.txt", name)
    if before is None or after is None or after < before:
        return None
    return after - before


def load_measurement(
    output_directory: Path,
    draft_n_max: int,
    role: str,
    mode: str,
    prompt: str,
    prompt_text: str,
    predict_tokens: int,
    sampling_seed: int,
) -> Measurement:
    arm = f"n{draft_n_max}-{role}"
    arm_directory = output_directory / arm
    expected_request = {
        "prompt": prompt_text,
        "n_predict": predict_tokens,
        "temperature": 0,
        "top_k": 1,
        "seed": sampling_seed,
        "cache_prompt": False,
        "stream": False,
        "return_tokens": True,
        "ignore_eos": True,
    }
    try:
        request_bytes = (arm_directory / f"{prompt}.request.json").read_bytes()
        request_payload = json.loads(request_bytes.decode("utf-8"))
        request_sha256 = hashlib.sha256(request_bytes).hexdigest()
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        request_payload = {}
        request_sha256 = None
    request_identity = isinstance(request_payload, dict) and set(
        request_payload
    ) == set(expected_request)
    if request_identity:
        request_identity = all(
            type(request_payload[field]) is type(expected)
            and request_payload[field] == expected
            for field, expected in expected_request.items()
        )

    response_sha256 = None
    payload: object = {}
    try:
        response_bytes = (arm_directory / f"{prompt}.json").read_bytes()
        response_sha256 = hashlib.sha256(response_bytes).hexdigest()
        payload = json.loads(response_bytes.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        payload = {}
    if not isinstance(payload, dict):
        payload = {}
    timings = payload.get("timings")
    if not isinstance(timings, dict):
        timings = {}

    listener_identity = False
    try:
        listener_lines = (
            (arm_directory / f"{prompt}.listener.tsv")
            .read_text(encoding="utf-8")
            .splitlines()
        )
    except (OSError, UnicodeDecodeError):
        listener_lines = []
    if len(listener_lines) == 2:
        header = listener_lines[0].split("\t")
        values = listener_lines[1].split("\t")
        listener_identity = (
            header == ["pid", "starttime", "inode_before", "inode_after", "state"]
            and len(values) == 5
            and all(value.isdigit() for value in values[:4])
            and values[2] == values[3]
            and values[4] == "accepted"
        )

    return Measurement(
        draft_n_max=draft_n_max,
        arm=arm,
        mode=mode,
        prompt=prompt,
        predicted=parse_positive_integer(timings.get("predicted_n")),
        predicted_ms=parse_positive_number(timings.get("predicted_ms")),
        rate=parse_positive_number(timings.get("predicted_per_second")),
        drafted=parse_nonnegative_integer(timings.get("draft_n")),
        accepted=parse_nonnegative_integer(timings.get("draft_n_accepted")),
        tokens=parse_tokens(payload.get("tokens")),
        metrics_drafted=metric_delta(arm_directory, prompt, METRIC_DRAFTED),
        metrics_accepted=metric_delta(arm_directory, prompt, METRIC_ACCEPTED),
        metrics_steps=metric_delta(arm_directory, prompt, METRIC_STEPS),
        request_sha256=request_sha256,
        response_sha256=response_sha256,
        request_identity=request_identity,
        listener_identity=listener_identity,
        draft_counter_keys_present=(
            "draft_n" in timings or "draft_n_accepted" in timings
        ),
    )


def accounting_state(item: Measurement) -> str:
    """Whether the response's own counters and its token count agree.

    A control arm reports no draft counters and moves no speculation counter. A
    speculative arm reports both, accepts no more than it drafted, and drafts no
    more than the configured batch geometry allows over the steps its token
    count implies. Every term reads the response alone, so the verdict is
    independent of when the server folds a slot's statistics into the global
    ones.
    """
    if item.predicted is None or item.predicted_ms is None or item.tokens is None:
        return "measurement_absent"
    if item.mode == "control":
        if item.draft_counter_keys_present:
            return "control_draft_counters"
        metrics = (item.metrics_drafted, item.metrics_accepted, item.metrics_steps)
        if all(value is not None for value in metrics) and metrics != (0, 0, 0):
            return "control_metrics_moved"
        return "accepted"
    if not item.drafted or item.accepted is None:
        return "draft_absent"
    if item.accepted > item.drafted:
        return "accepted_above_drafted"
    if not item.steps_inferred:
        return "steps_absent"
    if item.drafted > item.draft_n_max * item.steps_inferred:
        return "draft_geometry_invalid"
    return "accepted"


def steps_agreement(item: Measurement) -> str:
    """Whether the /metrics delta reproduces the counts the response reports.

    The delta is a second route to the same three numbers and it is unordered
    against the response write, so this is reported beside the arm rather than
    gating it.
    """
    if item.mode == "control":
        return "-"
    if item.metrics_steps is None or item.metrics_drafted is None:
        return "absent"
    if (
        item.metrics_steps == item.steps_inferred
        and item.metrics_drafted == item.drafted
        and item.metrics_accepted == item.accepted
    ):
        return "accepted"
    return "disagree"


def show(value: float | None, digits: int = 3) -> str:
    return "-" if value is None else f"{value:.{digits}f}"


def render_arm(item: Measurement) -> tuple[str, ...]:
    return (
        str(item.draft_n_max),
        item.arm,
        item.mode,
        item.prompt,
        "-" if item.predicted is None else str(item.predicted),
        show(item.predicted_ms, 1),
        show(item.rate, 3),
        "-" if item.drafted is None else str(item.drafted),
        "-" if item.accepted is None else str(item.accepted),
        show(item.acceptance, 4),
        "-" if item.metrics_steps is None else str(item.metrics_steps),
        "-" if item.steps_inferred is None else str(item.steps_inferred),
        show(item.round_ms, 1),
        show(item.tokens_per_traversal, 3),
        item.token_sha256 or "-",
        item.request_sha256 or "-",
        item.response_sha256 or "-",
        "accepted" if item.request_identity else "rejected",
        "accepted" if item.listener_identity else "rejected",
        accounting_state(item),
        steps_agreement(item),
    )


def aggregate_rate(items: list[Measurement]) -> float | None:
    """Tokens per second over a set of responses, weighted by decoded tokens.

    The first token arrives from the prompt logits rather than from a decode
    step, so it enters neither the numerator nor the elapsed time.
    """
    if not items or any(item.predicted is None or item.rate is None for item in items):
        return None
    tokens = sum((item.predicted or 0) - 1 for item in items)
    seconds = math.fsum(
        ((item.predicted or 0) - 1) / (item.rate or 1.0) for item in items
    )
    return tokens / seconds if seconds > 0 else None


def ratio(numerator: float | None, denominator: float | None) -> float | None:
    if numerator is None or denominator is None or denominator <= 0:
        return None
    return numerator / denominator


def summarize_depth(
    draft_n_max: int,
    measurements: list[Measurement],
    target_rate: float,
    draft_pass_ms: float | None,
) -> tuple[dict[str, str], dict[str, float | None]]:
    control = [item for item in measurements if item.mode == "control"]
    spec = [item for item in measurements if item.mode == "spec"]
    control_rate = aggregate_rate(control)
    spec_rate = aggregate_rate(spec)
    first_ratio = ratio(
        aggregate_rate([item for item in spec if item.arm.endswith("spec-first")]),
        aggregate_rate([item for item in control if item.arm.endswith("control-open")]),
    )
    second_ratio = ratio(
        aggregate_rate([item for item in spec if item.arm.endswith("spec-second")]),
        aggregate_rate(
            [item for item in control if item.arm.endswith("control-close")]
        ),
    )

    total_drafted = sum(item.drafted or 0 for item in spec)
    total_accepted = sum(item.accepted or 0 for item in spec)
    total_steps = sum(item.steps_inferred or 0 for item in spec)
    total_predicted = sum((item.predicted or 0) - 1 for item in spec)
    total_ms = math.fsum(item.predicted_ms or 0.0 for item in spec)
    acceptance_values = [
        item.acceptance for item in spec if item.acceptance is not None
    ]
    acceptance_weighted = total_accepted / total_drafted if total_drafted else None
    acceptance_min = min(acceptance_values) if acceptance_values else None
    round_ms = total_ms / total_steps if total_steps else None
    tokens_per_traversal = total_predicted / total_steps if total_steps else None

    round_seconds = round_ms / 1000.0 if round_ms else None
    ceiling = (
        emitted_per_round(1.0, draft_n_max) / round_seconds if round_seconds else None
    )
    breakeven = (
        solve_acceptance(draft_n_max, round_seconds, control_rate)
        if round_seconds and control_rate
        else None
    )
    target_acceptance = (
        solve_acceptance(draft_n_max, round_seconds, target_rate)
        if round_seconds
        else None
    )
    # A required acceptance above one is the finding rather than a missing
    # value, so the unbounded root is reported where the physical one is absent.
    target_acceptance_unbounded = (
        solve_acceptance(draft_n_max, round_seconds, target_rate, ceiling=64.0)
        if round_seconds and target_acceptance is None
        else None
    )
    required_round_ms = (
        1000.0 * emitted_per_round(acceptance_weighted, draft_n_max) / target_rate
        if acceptance_weighted is not None
        else None
    )
    required_round_removal = (
        (round_ms - required_round_ms) / round_ms
        if round_ms and required_round_ms is not None
        else None
    )
    # Splitting the round into its draft and verification halves needs a draft
    # cost this run does not measure, so the two verification columns stay
    # absent until a caller supplies one.
    required_verify_ms = None
    required_verify_removal = None
    if draft_pass_ms is not None and required_round_ms is not None and round_ms:
        measured_verify_ms = round_ms - draft_n_max * draft_pass_ms
        required_verify_ms = required_round_ms - draft_n_max * draft_pass_ms
        if measured_verify_ms > 0:
            required_verify_removal = (
                measured_verify_ms - required_verify_ms
            ) / measured_verify_ms

    row = {
        "draft_n_max": str(draft_n_max),
        "control_tok_s": show(control_rate),
        "spec_tok_s": show(spec_rate),
        "spec_over_control": show(ratio(spec_rate, control_rate), 4),
        "first_ratio": show(first_ratio, 4),
        "second_ratio": show(second_ratio, 4),
        "acceptance_weighted": show(acceptance_weighted, 4),
        "acceptance_min": show(acceptance_min, 4),
        "steps": str(total_steps) if total_steps else "-",
        "round_ms": show(round_ms, 1),
        "tokens_per_traversal": show(tokens_per_traversal, 3),
        "ceiling_perfect_acceptance_tok_s": show(ceiling),
        "breakeven_acceptance": show(breakeven, 4),
        "target_acceptance": (
            show(target_acceptance, 4)
            if target_acceptance is not None
            else f"impossible({show(target_acceptance_unbounded, 4)})"
        ),
        "required_round_ms": show(required_round_ms, 1),
        "required_round_removal": show(required_round_removal, 4),
        "required_verify_ms": show(required_verify_ms, 1),
        "required_verify_removal": show(required_verify_removal, 4),
    }
    gates = {
        "first_ratio": first_ratio,
        "second_ratio": second_ratio,
        "acceptance_weighted": acceptance_weighted,
        "acceptance_min": acceptance_min,
        "breakeven": breakeven,
        "spec_rate": spec_rate,
    }
    return row, gates


def write_lines(path: Path, lines: list[str]) -> None:
    path.write_text("".join(f"{line}\n" for line in lines), encoding="utf-8")


def write_summary(path: Path, rows: tuple[tuple[str, str], ...]) -> int:
    path.write_text(
        "".join(f"{field}={value}\n" for field, value in rows), encoding="utf-8"
    )
    print(path.read_text(encoding="utf-8"), end="")
    return 0


def summarize(
    output_directory: Path, target_rate: float, draft_pass_ms: float | None
) -> int:
    fields = read_inputs(output_directory)
    # A retained directory travels without the state directory the run wrote
    # its corpus path into, so the copy beside the arms wins where it exists.
    retained_prompts = output_directory / "prompts.tsv"
    recorded_prompts = fields.get("prompt_corpus")
    prompt_rows = read_prompts(
        retained_prompts
        if retained_prompts.is_file() or not recorded_prompts
        else Path(recorded_prompts)
    )
    predict_tokens = int(fields["predict_tokens"])
    sampling_seed = int(fields["seed"])
    if predict_tokens <= 1:
        raise Refusal("predict_tokens must exceed the free first token")
    draft_lengths = [int(value) for value in fields["draft_length_list"].split()]
    if not draft_lengths or any(value <= 0 for value in draft_lengths):
        raise Refusal(f"draft_length_list is empty or non-positive: {fields}")
    acceptance_floor_text = fields.get("acceptance_floor", "-")
    acceptance_floor = (
        float(acceptance_floor_text) if acceptance_floor_text != "-" else None
    )

    measurements = [
        load_measurement(
            output_directory,
            draft_n_max,
            role,
            mode,
            prompt,
            prompt_text,
            predict_tokens,
            sampling_seed,
        )
        for draft_n_max in draft_lengths
        for role, mode in ARM_ROLES
        for prompt, prompt_text in prompt_rows
    ]
    write_lines(
        output_directory / "arms.tsv",
        ["\t".join(ARM_FIELDS)]
        + ["\t".join(render_arm(item)) for item in measurements],
    )

    summary_path = output_directory / "summary.txt"
    header = (
        ("mechanism", fields["mechanism"]),
        ("subject", fields.get("subject", "-")),
        ("target_rate", f"{target_rate:.3f}"),
        ("draft_lengths", " ".join(str(value) for value in draft_lengths)),
        ("acceptance_floor", acceptance_floor_text),
    )

    for reason, offenders in (
        (
            "request_mismatch",
            [f"{item.arm}:{item.prompt}" for item in measurements if not item.request_identity],
        ),
        (
            "listener_identity",
            [
                f"{item.arm}:{item.prompt}"
                for item in measurements
                if not item.listener_identity
            ],
        ),
        (
            "measurement_incomplete",
            [
                f"{item.arm}:{item.prompt}"
                for item in measurements
                if item.predicted != predict_tokens
                or item.tokens is None
                or len(item.tokens) != predict_tokens
                or item.rate is None
                or item.predicted_ms is None
            ],
        ),
    ):
        if offenders:
            write_summary(
                summary_path,
                header
                + (
                    ("state", "failed"),
                    ("reason", reason),
                    ("requests", ",".join(sorted(offenders))),
                ),
            )
            print(f"speculation summary refused: {reason}", file=sys.stderr)
            return 1

    accounting_failures = sorted(
        f"{item.arm}:{item.prompt}={state}"
        for item in measurements
        if (state := accounting_state(item)) != "accepted"
    )
    if accounting_failures:
        write_summary(
            summary_path,
            header
            + (
                ("state", "failed"),
                ("reason", "accounting"),
                ("requests", ",".join(accounting_failures)),
            ),
        )
        print(
            "one or more arms report counters the token count contradicts",
            file=sys.stderr,
        )
        return 1

    breakeven_rows: list[dict[str, str]] = []
    depth_gates: dict[int, dict[str, float | None]] = {}
    for draft_n_max in draft_lengths:
        row, gates = summarize_depth(
            draft_n_max,
            [item for item in measurements if item.draft_n_max == draft_n_max],
            target_rate,
            draft_pass_ms,
        )
        breakeven_rows.append(row)
        depth_gates[draft_n_max] = gates
    write_lines(
        output_directory / "breakeven.tsv",
        ["\t".join(BREAKEVEN_FIELDS)]
        + ["\t".join(row[field] for field in BREAKEVEN_FIELDS) for row in breakeven_rows],
    )

    # Two token comparisons answer two questions. The controls of one depth
    # differ by nothing but position in the session, so a difference there is
    # machine nondeterminism and invalidates the depth. A speculative arm
    # differing from its controls is the correctness observation, and
    # evidence/mtp-speculation-matrix.md locates that divergence at the target
    # context being built for more than one output rather than at drafting.
    determinism_failures: list[str] = []
    identity_failures: list[str] = []
    for draft_n_max in draft_lengths:
        for prompt, _text in prompt_rows:
            depth = [
                item
                for item in measurements
                if item.draft_n_max == draft_n_max and item.prompt == prompt
            ]
            controls = [item.tokens for item in depth if item.mode == "control"]
            specs = [item.tokens for item in depth if item.mode == "spec"]
            if any(tokens != controls[0] for tokens in controls):
                determinism_failures.append(f"n{draft_n_max}:{prompt}")
                continue
            if any(tokens != controls[0] for tokens in specs):
                identity_failures.append(f"n{draft_n_max}:{prompt}")

    if determinism_failures:
        write_summary(
            summary_path,
            header
            + (
                ("state", "failed"),
                ("reason", "control_determinism"),
                ("requests", ",".join(sorted(determinism_failures))),
            ),
        )
        print(
            "a depth's two control arms emitted different tokens for one prompt",
            file=sys.stderr,
        )
        return 1

    performance_depths = [
        str(draft_n_max)
        for draft_n_max in draft_lengths
        if (gates := depth_gates[draft_n_max])
        and gates["first_ratio"] is not None
        and gates["first_ratio"] >= 1.0
        and gates["second_ratio"] is not None
        and gates["second_ratio"] >= 1.0
    ]
    acceptance_depths = [
        str(draft_n_max)
        for draft_n_max in draft_lengths
        if (gates := depth_gates[draft_n_max])
        and gates["acceptance_min"] is not None
        and gates["breakeven"] is not None
        and gates["acceptance_min"] >= gates["breakeven"]
        and (acceptance_floor is None or gates["acceptance_min"] >= acceptance_floor)
    ]
    agreement_states = {
        steps_agreement(item) for item in measurements if item.mode == "spec"
    }
    admission_depths = [
        depth for depth in performance_depths if depth in set(acceptance_depths)
    ]
    best_rate = max(
        (
            gates["spec_rate"]
            for gates in depth_gates.values()
            if gates["spec_rate"] is not None
        ),
        default=None,
    )
    rows = header + (
        ("state", "completed"),
        ("control_determinism_gate", "accepted"),
        (
            "token_identity_gate",
            "accepted" if not identity_failures else "rejected",
        ),
        ("token_identity_divergences", ",".join(sorted(identity_failures)) or "-"),
        ("performance_gate", "accepted" if performance_depths else "rejected"),
        ("performance_depths", ",".join(performance_depths) or "-"),
        ("acceptance_gate", "accepted" if acceptance_depths else "rejected"),
        ("acceptance_depths", ",".join(acceptance_depths) or "-"),
        ("best_spec_tok_s", show(best_rate)),
        ("steps_agreement", ",".join(sorted(agreement_states)) or "-"),
        (
            "target_gate",
            "accepted" if best_rate is not None and best_rate >= target_rate else "rejected",
        ),
        # The same field summarize-draft-pair.py publishes, so one word decides
        # eligibility for the device-level promotion review across both
        # harnesses. The gate never edits a ledger tier. One serving tuple is
        # one draft length, so the gate reads the depths that pass performance
        # and acceptance together rather than the two lists separately: a depth
        # that beats its controls while accepting below break-even and another
        # that does the reverse name no configuration anyone can serve.
        ("admission_depths", ",".join(admission_depths) or "-"),
        (
            "admission_gate",
            "accepted" if admission_depths and not identity_failures else "rejected",
        ),
    )
    return write_summary(summary_path, rows)


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Report acceptance, tokens per weight traversal, and the "
            "break-even acceptance of one speculation measurement."
        )
    )
    parser.add_argument("output_directory", help="the run directory to read")
    parser.add_argument(
        "--target-rate",
        type=float,
        default=5.25,
        help="the decode rate the required round time is solved for",
    )
    parser.add_argument(
        "--draft-pass-ms",
        type=float,
        default=None,
        help=(
            "a measured per-drafted-token draft cost, which splits the round "
            "into its draft and verification halves"
        ),
    )
    parsed = parser.parse_args(arguments)
    if not math.isfinite(parsed.target_rate) or parsed.target_rate <= 0:
        print("--target-rate must be a positive rate", file=sys.stderr)
        return 2
    if parsed.draft_pass_ms is not None and (
        not math.isfinite(parsed.draft_pass_ms) or parsed.draft_pass_ms < 0
    ):
        print("--draft-pass-ms must be a non-negative duration", file=sys.stderr)
        return 2
    try:
        return summarize(
            Path(parsed.output_directory).resolve(),
            parsed.target_rate,
            parsed.draft_pass_ms,
        )
    except (OSError, Refusal, ValueError) as error:
        print(f"speculation summary refused: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
