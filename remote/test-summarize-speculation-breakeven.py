#!/usr/bin/env python3
"""Prove the break-even arithmetic and the counter accounting without a device.

Two kinds of check run here. The first drives the closed-form helpers against
figures `evidence/throughput-target-analysis/README.md` already publishes for
the 4B distill's N=1 MTP arm, so the calculator is cross-checked against the
tree rather than against itself. The second builds synthetic run directories
and requires the summary to accept a coherent one and to name the exact broken
term in each incoherent one.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

SCRIPT_DIRECTORY = Path(__file__).resolve().parent
PROMPTS = (
    ("code", "write a function"),
    ("prose", "explain a limit"),
)
PREDICT = 128
SEED = 42
ARM_ROLES = ("control-open", "spec-first", "spec-second", "control-close")


def load_summarizer():
    path = SCRIPT_DIRECTORY / "summarize-speculation-breakeven.py"
    spec = importlib.util.spec_from_file_location("speculation_breakeven", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"summarizer is unreadable: {path}")
    module = importlib.util.module_from_spec(spec)
    # dataclasses resolves a frozen class's own module through sys.modules, so
    # the module is registered before its body runs.
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


summarizer = load_summarizer()
failures = 0


def report(name, condition, detail=""):
    global failures
    state = "accepted" if condition else "rejected"
    print(f"{name}={state}{(' ' + detail) if detail and not condition else ''}")
    if not condition:
        failures += 1


def close(observed, expected, tolerance):
    return observed is not None and abs(observed - expected) <= tolerance


def speculation_counts(predicted, acceptance, draft_n_max):
    """The fixture's own derivation, so the test builds coherent counters."""
    decoded = predicted - 1
    steps = max(1, round(decoded / (1.0 + acceptance * draft_n_max)))
    steps = min(steps, decoded)
    accepted = decoded - steps
    return draft_n_max * steps, accepted, steps


def write_run(
    root,
    draft_lengths,
    control_rate,
    spec_rates,
    acceptances,
    *,
    acceptance_floor="-",
    spec_tokens=None,
    control_close_tokens=None,
    metrics_drafted_skew=0,
    metrics_step_skew=0,
    control_metrics_move=False,
    omit_metrics=False,
    omit_timings_draft=False,
    metrics_lag=False,
    predicted_ms_scale=None,
):
    root.mkdir(parents=True, exist_ok=True)
    prompt_path = root / "prompts.tsv"
    prompt_path.write_text(
        "".join(f"{name}\t{text}\n" for name, text in PROMPTS), encoding="utf-8"
    )
    (root / "inputs.txt").write_text(
        "mechanism=draft-mtp\n"
        "subject=fake-target\n"
        f"draft_length_list={' '.join(str(value) for value in draft_lengths)}\n"
        f"acceptance_floor={acceptance_floor}\n"
        f"predict_tokens={PREDICT}\n"
        f"seed={SEED}\n"
        f"prompt_corpus={prompt_path}\n",
        encoding="utf-8",
    )
    base_tokens = [10 + index for index in range(8)]
    for draft_n_max in draft_lengths:
        cumulative = [0, 0, 0]
        for role in ARM_ROLES:
            mode = "control" if role.startswith("control") else "spec"
            arm = root / f"n{draft_n_max}-{role}"
            arm.mkdir(exist_ok=True)
            rate = control_rate if mode == "control" else spec_rates[draft_n_max]
            for name, text in PROMPTS:
                source = base_tokens
                if mode == "spec" and spec_tokens is not None:
                    source = spec_tokens
                if role == "control-close" and control_close_tokens is not None:
                    source = control_close_tokens
                emitted = [source[index % len(source)] for index in range(PREDICT)]
                request = {
                    "prompt": text,
                    "n_predict": PREDICT,
                    "temperature": 0,
                    "top_k": 1,
                    "seed": SEED,
                    "cache_prompt": False,
                    "stream": False,
                    "return_tokens": True,
                    "ignore_eos": True,
                }
                (arm / f"{name}.request.json").write_text(
                    json.dumps(request), encoding="utf-8"
                )
                # The reported rate and the elapsed time are separate fields, so
                # a scale here decouples the round time from the rate and lets
                # one depth pass the performance gate while another passes the
                # acceptance gate. A served response never disagrees with itself
                # this way; the branch it reaches does exist.
                scale = 1.0
                if predicted_ms_scale is not None and mode == "spec":
                    scale = predicted_ms_scale.get(draft_n_max, 1.0)
                timings = {
                    "prompt_n": 3,
                    "prompt_ms": 1000.0,
                    "prompt_per_second": 20.0,
                    "predicted_n": PREDICT,
                    "predicted_ms": (PREDICT - 1) * 1000.0 / rate * scale,
                    "predicted_per_second": rate,
                }
                drafted, accepted, steps = (0, 0, 0)
                if mode == "spec":
                    drafted, accepted, steps = speculation_counts(
                        PREDICT, acceptances[draft_n_max], draft_n_max
                    )
                    if not omit_timings_draft:
                        timings["draft_n"] = drafted
                        timings["draft_n_accepted"] = accepted
                before = list(cumulative)
                cumulative[0] += drafted + (
                    metrics_drafted_skew if mode == "spec" else 0
                )
                cumulative[1] += accepted
                cumulative[2] += steps + (metrics_step_skew if mode == "spec" else 0)
                if control_metrics_move and mode == "control":
                    cumulative = [value + 1 for value in cumulative]
                if not omit_metrics:
                    # A lagging fold leaves the after-read at the pre-request
                    # value, which is what an unordered /metrics read against
                    # send_final_response produces on the appliance.
                    after = (
                        list(before) if metrics_lag and mode == "spec" else cumulative
                    )
                    for suffix, values in (
                        ("before", before),
                        ("after", after),
                    ):
                        (arm / f"{name}.metrics-{suffix}.txt").write_text(
                            "# TYPE spec_decode_num_draft_tokens_total counter\n"
                            f"spec_decode_num_draft_tokens_total {values[0]:.1f}\n"
                            f"spec_decode_num_accepted_tokens_total {values[1]:.1f}\n"
                            f"spec_decode_num_drafts_total {values[2]:.1f}\n",
                            encoding="utf-8",
                        )
                (arm / f"{name}.json").write_text(
                    json.dumps({"content": "", "tokens": emitted, "timings": timings}),
                    encoding="utf-8",
                )
                (arm / f"{name}.listener.tsv").write_text(
                    "pid\tstarttime\tinode_before\tinode_after\tstate\n"
                    "4321\t99\t777\t777\taccepted\n",
                    encoding="utf-8",
                )
    return root


def summary_fields(root):
    fields = {}
    for line in (root / "summary.txt").read_text(encoding="utf-8").splitlines():
        if "=" in line:
            name, value = line.split("=", 1)
            fields[name] = value
    return fields


# The published N=1 arm: a 463.1 ms two-column verification pass beside a 66.4
# ms draft pass. Perfect acceptance reaches 3.777 tok/s, a free draft reaches
# 4.319, and 5.25 demands an acceptance of 1.7799, outside the physical
# interval. Reproducing all three is what ties this calculator to the tree.
mtp_round = (463.1 + 66.4) / 1000.0
report(
    "published_perfect_acceptance",
    close(summarizer.emitted_per_round(1.0, 1) / mtp_round, 3.777148, 0.001),
    f"{summarizer.emitted_per_round(1.0, 1) / mtp_round}",
)
report(
    "published_free_draft",
    close(summarizer.emitted_per_round(1.0, 1) / 0.4631, 4.318722, 0.001),
)
report(
    "published_required_acceptance_outside_one",
    summarizer.solve_acceptance(1, mtp_round, 5.25) is None,
)
report(
    "published_required_acceptance_value",
    close(summarizer.solve_acceptance(1, mtp_round, 5.25, ceiling=64.0), 1.779875, 0.001),
    f"{summarizer.solve_acceptance(1, mtp_round, 5.25, ceiling=64.0)}",
)
# The break-even against the matrix's own 323 ms one-column pass.
report(
    "breakeven_against_unspeculated_control",
    close(summarizer.solve_acceptance(1, mtp_round, 1 / 0.323), 0.639, 0.001),
    f"{summarizer.solve_acceptance(1, mtp_round, 1 / 0.323)}",
)
# A free draft at perfect acceptance and three columns of draft reaches 5.109
# tok/s, which is the ceiling temporal amortization has on this device.
report(
    "amortization_ceiling_below_target",
    close(summarizer.emitted_per_round(1.0, 3) / 0.783, 5.109, 0.001)
    and summarizer.emitted_per_round(1.0, 3) / 0.783 < 5.25,
)
report(
    "emitted_per_round_geometric",
    close(summarizer.emitted_per_round(0.5, 3), 1 + 0.5 + 0.25 + 0.125, 1e-12),
)

with tempfile.TemporaryDirectory() as workspace:
    work = Path(workspace)

    # An acceptance above every depth's break-even with the speculative arms
    # ahead of both controls: every gate accepts and the token identity holds
    # because the fixture emits one array.
    healthy = write_run(
        work / "healthy",
        [1, 2],
        3.10,
        {1: 3.60, 2: 3.40},
        {1: 0.90, 2: 0.88},
    )
    code = summarizer.main([str(healthy), "--target-rate", "5.25"])
    fields = summary_fields(healthy)
    report("healthy_exit", code == 0, str(code))
    report("healthy_state", fields.get("state") == "completed", str(fields))
    report(
        "healthy_control_determinism",
        fields.get("control_determinism_gate") == "accepted",
    )
    report("healthy_token_identity", fields.get("token_identity_gate") == "accepted")
    report(
        "healthy_performance_depths", fields.get("performance_depths") == "1,2", str(fields)
    )
    report("healthy_target_gate", fields.get("target_gate") == "rejected")
    breakeven_rows = (healthy / "breakeven.tsv").read_text(encoding="utf-8").splitlines()
    header = breakeven_rows[0].split("\t")
    row_one = dict(zip(header, breakeven_rows[1].split("\t")))
    report(
        "healthy_acceptance_reported",
        close(float(row_one["acceptance_weighted"]), 0.90, 0.02),
        row_one["acceptance_weighted"],
    )
    report(
        "healthy_tokens_per_traversal",
        close(float(row_one["tokens_per_traversal"]), 1.90, 0.03),
        row_one["tokens_per_traversal"],
    )
    report(
        "healthy_round_ms_matches_rate",
        close(
            float(row_one["round_ms"]),
            float(row_one["tokens_per_traversal"]) * 1000.0 / 3.60,
            0.5,
        ),
        row_one["round_ms"],
    )
    report(
        "healthy_target_acceptance_impossible",
        row_one["target_acceptance"].startswith("impossible("),
        row_one["target_acceptance"],
    )
    report(
        "healthy_required_round_removal_positive",
        float(row_one["required_round_removal"]) > 0,
        row_one["required_round_removal"],
    )
    report(
        "healthy_verify_columns_absent_without_draft_cost",
        row_one["required_verify_ms"] == "-",
    )

    # A supplied draft cost splits the round, and the verification half is the
    # round less N draft passes.
    split = write_run(work / "split", [1], 3.10, {1: 3.60}, {1: 0.90})
    summarizer.main([str(split), "--target-rate", "5.25", "--draft-pass-ms", "66.4"])
    split_rows = (split / "breakeven.tsv").read_text(encoding="utf-8").splitlines()
    split_row = dict(zip(split_rows[0].split("\t"), split_rows[1].split("\t")))
    report(
        "draft_cost_splits_the_round",
        close(
            float(split_row["required_verify_ms"]),
            float(split_row["required_round_ms"]) - 66.4,
            0.05,
        ),
        split_row["required_verify_ms"],
    )

    # An acceptance below break-even leaves the performance gate rejected while
    # the rate and acceptance columns stay readable.
    slow = write_run(work / "slow", [1], 3.10, {1: 2.80}, {1: 0.40})
    report("slow_exit", summarizer.main([str(slow)]) == 0)
    slow_fields = summary_fields(slow)
    report("slow_performance_rejected", slow_fields.get("performance_gate") == "rejected")
    report("slow_acceptance_rejected", slow_fields.get("acceptance_gate") == "rejected")
    report("slow_state_completed", slow_fields.get("state") == "completed")

    # The ledger's own floor is a second, stricter gate: an acceptance above
    # break-even and below the floor rejects.
    floored = write_run(
        work / "floored",
        [1],
        3.10,
        {1: 3.60},
        {1: 0.80},
        acceptance_floor="0.896",
    )
    summarizer.main([str(floored)])
    floored_fields = summary_fields(floored)
    report(
        "acceptance_floor_rejects_above_breakeven",
        floored_fields.get("performance_gate") == "accepted"
        and floored_fields.get("acceptance_gate") == "rejected",
        str(floored_fields),
    )

    # A speculative arm emitting a different token array is the correctness
    # observation, and it leaves the other three gates readable.
    diverged = write_run(
        work / "diverged",
        [1],
        3.10,
        {1: 3.60},
        {1: 0.90},
        spec_tokens=[90 + index for index in range(8)],
    )
    report("diverged_exit", summarizer.main([str(diverged)]) == 0)
    diverged_fields = summary_fields(diverged)
    report(
        "token_identity_rejects_alone",
        diverged_fields.get("token_identity_gate") == "rejected"
        and diverged_fields.get("performance_gate") == "accepted"
        and diverged_fields.get("control_determinism_gate") == "accepted",
        str(diverged_fields),
    )
    report(
        "token_identity_names_the_prompts",
        diverged_fields.get("token_identity_divergences") == "n1:code,n1:prose",
        diverged_fields.get("token_identity_divergences", ""),
    )

    # Two controls of one depth differing is machine nondeterminism, and it
    # ends the summary rather than reporting a ratio against them.
    unstable = write_run(
        work / "unstable",
        [1],
        3.10,
        {1: 3.60},
        {1: 0.90},
        control_close_tokens=[50 + index for index in range(8)],
    )
    report("unstable_exit", summarizer.main([str(unstable)]) == 1)
    report(
        "control_determinism_terminal",
        summary_fields(unstable).get("reason") == "control_determinism",
    )

    # An accounting term that reads the response alone is terminal and names
    # itself. Every one of these breaks a count the completion body carries.
    for label, keywords, expected in (
        ("control_metrics_moved", {"control_metrics_move": True}, "control_metrics_moved"),
        ("draft_absent", {"omit_timings_draft": True}, "draft_absent"),
    ):
        broken = write_run(
            work / label, [1], 3.10, {1: 3.60}, {1: 0.90}, **keywords
        )
        code = summarizer.main([str(broken)])
        broken_fields = summary_fields(broken)
        report(
            f"accounting_{label}",
            code == 1
            and broken_fields.get("reason") == "accounting"
            and expected in broken_fields.get("requests", ""),
            f"{code} {broken_fields.get('requests', '')}",
        )

    # The /metrics comparison is unordered against the response write, so a
    # skew, a lag, and an absent route are reported on the steps_agreement line
    # and leave every rate and gate intact.
    for label, keywords, expected in (
        ("skew", {"metrics_drafted_skew": 3}, "disagree"),
        ("step_skew", {"metrics_step_skew": 2}, "disagree"),
        ("lag", {"metrics_lag": True}, "disagree"),
        ("absent", {"omit_metrics": True}, "absent"),
    ):
        reported = write_run(
            work / f"agreement-{label}", [1], 3.10, {1: 3.60}, {1: 0.90}, **keywords
        )
        code = summarizer.main([str(reported)])
        reported_fields = summary_fields(reported)
        report(
            f"steps_agreement_{label}",
            code == 0
            and reported_fields.get("state") == "completed"
            and reported_fields.get("steps_agreement") == expected
            and reported_fields.get("performance_gate") == "accepted",
            f"{code} {reported_fields}",
        )

    # The step count the tokens imply stays the authority, so a lagging counter
    # leaves the acceptance and traversal columns exactly where a clean run puts
    # them.
    clean_rows = (
        (work / "agreement-lag" / "breakeven.tsv").read_text(encoding="utf-8").splitlines()
    )
    lag_row = dict(zip(clean_rows[0].split("\t"), clean_rows[1].split("\t")))
    report(
        "lagging_metrics_leave_the_traversal_intact",
        close(float(lag_row["tokens_per_traversal"]), 1.90, 0.03),
        lag_row["tokens_per_traversal"],
    )

    # One serving tuple is one draft length, so a run where one depth beats its
    # controls and a different depth clears break-even names no configuration
    # anyone can serve and the admission gate rejects.
    disjoint = write_run(
        work / "disjoint",
        [1, 2],
        3.10,
        {1: 3.60, 2: 2.80},
        {1: 0.50, 2: 0.95},
        acceptance_floor="0.900",
        predicted_ms_scale={2: 0.4},
    )
    report("disjoint_exit", summarizer.main([str(disjoint)]) == 0)
    disjoint_fields = summary_fields(disjoint)
    report(
        "admission_requires_one_depth_passing_both",
        disjoint_fields.get("performance_gate") == "accepted"
        and disjoint_fields.get("acceptance_gate") == "accepted"
        and disjoint_fields.get("performance_depths") == "1"
        and disjoint_fields.get("acceptance_depths") == "2"
        and disjoint_fields.get("admission_depths") == "-"
        and disjoint_fields.get("admission_gate") == "rejected",
        str(disjoint_fields),
    )
    report(
        "admission_accepts_one_depth_passing_both",
        summary_fields(healthy).get("admission_gate") == "accepted"
        and summary_fields(healthy).get("admission_depths") == "1,2",
        str(summary_fields(healthy)),
    )
    report(
        "admission_follows_token_identity",
        summary_fields(diverged).get("admission_gate") == "rejected",
    )

    # A retained directory read after the state directory the run named is gone
    # still resolves its corpus, because the copy beside the arms wins.
    moved = write_run(work / "moved", [1], 3.10, {1: 3.60}, {1: 0.90})
    inputs_path = moved / "inputs.txt"
    inputs_path.write_text(
        inputs_path.read_text(encoding="utf-8").replace(
            f"prompt_corpus={moved / 'prompts.tsv'}",
            "prompt_corpus=/nonexistent/state/prompts.tsv",
        ),
        encoding="utf-8",
    )
    report(
        "retained_directory_resolves_its_own_corpus",
        summarizer.main([str(moved)]) == 0
        and summary_fields(moved).get("state") == "completed",
    )

    # A retained request that differs from the corpus ends the summary before
    # any rate is computed.
    tampered = write_run(work / "tampered", [1], 3.10, {1: 3.60}, {1: 0.90})
    request_path = tampered / "n1-spec-first" / "code.request.json"
    payload = json.loads(request_path.read_text(encoding="utf-8"))
    payload["temperature"] = 0.7
    request_path.write_text(json.dumps(payload), encoding="utf-8")
    report("request_identity_exit", summarizer.main([str(tampered)]) == 1)
    report(
        "request_identity_terminal",
        summary_fields(tampered).get("reason") == "request_mismatch",
    )

    # The arms table carries one row per depth, arm, and prompt with a token
    # digest a reader can compare against another run.
    arms_lines = (healthy / "arms.tsv").read_text(encoding="utf-8").splitlines()
    report(
        "arms_row_count",
        len(arms_lines) == 1 + 2 * len(ARM_ROLES) * len(PROMPTS),
        str(len(arms_lines)),
    )
    arms_header = arms_lines[0].split("\t")
    first_row = dict(zip(arms_header, arms_lines[1].split("\t")))
    expected_digest = hashlib.sha256(
        json.dumps(
            [(10 + index) % 8 + 10 for index in range(PREDICT)],
            separators=(",", ":"),
        ).encode("ascii")
    ).hexdigest()
    report(
        "arms_token_digest",
        len(first_row["token_sha256"]) == 64 and first_row["token_sha256"] != "-",
        first_row["token_sha256"],
    )
    report("arms_digest_is_reproducible", len(expected_digest) == 64)

print(f"failures={failures}")
sys.exit(1 if failures else 0)
