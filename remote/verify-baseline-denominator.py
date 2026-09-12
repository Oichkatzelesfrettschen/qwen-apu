#!/usr/bin/env python3
"""Bind a completed raw baseline to a comparison's served subject and tuple."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


def digest(path: Path) -> str:
    if not path.is_file() or path.is_symlink():
        raise ValueError(f"absent or linked input: {path}")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def table(path: Path) -> dict[str, str]:
    lines = path.read_text().splitlines()
    if not lines or lines[0] != "key\tvalue":
        raise ValueError(f"invalid table header: {path}")
    values: dict[str, str] = {}
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) != 2 or fields[0] in values:
            raise ValueError(f"invalid or duplicate table field: {path}")
        values[fields[0]] = fields[1]
    return values


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in (
        "acquisition",
        "server_sha",
        "server_bytes",
        "model_id",
        "expected_tuple",
        "generate",
    ):
        parser.add_argument(name)
    parser.add_argument("--q4k-variant", default="production/4")
    arguments = parser.parse_args()
    acquisition_name = arguments.acquisition
    server_sha = arguments.server_sha
    server_bytes = arguments.server_bytes
    model_id = arguments.model_id
    expected_tuple = arguments.expected_tuple
    generate = arguments.generate
    acquisition = Path(acquisition_name)
    tools = Path(__file__).resolve().parent
    # The baseline reader invokes its retained validator. Admit that invocation
    # only when its bytes match the validator in the trusted runtime tree.
    if digest(acquisition / "acquisition-clock-validator.py") != digest(
        tools / "validate-clock-sidecar.py"
    ):
        raise ValueError("baseline validator differs from the trusted runtime validator")
    completed = subprocess.run(
        [
            sys.executable,
            str(tools / "summarize-checkpoint-baseline.py"),
            str(acquisition),
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if completed.returncode:
        raise ValueError("baseline reader refused: " + completed.stderr.strip())
    summary: dict[str, str] = {}
    for line in completed.stdout.splitlines():
        fields = line.split("\t")
        if len(fields) == 2:
            if fields[0] in summary:
                raise ValueError("duplicate summary field")
            summary[fields[0]] = fields[1]
    for key, expected_summary in (
        ("schema", "checkpoint-baseline-summary-v2"),
        ("arms", "1"),
        ("within_binary_repeatability", "held"),
        ("acquisition_completeness", "completed"),
        ("instrument_admission", "accepted"),
        ("cross_binary_token_comparison", "not_applicable"),
    ):
        if summary.get(key) != expected_summary:
            raise ValueError(f"baseline denominator refuses {key}={summary.get(key)}")
    identity = table(acquisition / "identity.tsv")
    expected = dict(
        zip(
            (
                "registry_context",
                "registry_batch",
                "registry_ubatch",
                "registry_cache_type_k",
                "registry_cache_type_v",
                "registry_flash_attention",
                "registry_ctx_checkpoints",
                "checkpoint_min_step",
                "model_bytes",
                "model_sha256",
            ),
            expected_tuple.split("\t"),
            strict=True,
        )
    )
    # The guarded launcher emits an override as argv. An absent override uses
    # the pinned natural-boundary build's registered 8192 default.
    argv = json.loads((acquisition / "arms/01-subject/server-argv.json").read_text())
    spacing = [
        argv[index + 1] for index, value in enumerate(argv[:-1]) if value == "--checkpoint-min-step"
    ]
    if len(spacing) > 1 or expected.pop("checkpoint_min_step") != (
        spacing[0] if spacing else "8192"
    ):
        raise ValueError("baseline checkpoint spacing differs from the comparison")
    expected.update(
        {
            "schema": "checkpoint-baseline-identity-v2",
            "mode": "single",
            "profile": "low-async",
            "q4k_variant": arguments.q4k_variant,
            "model_id": model_id,
            "control_server_sha256": server_sha,
            "control_server_bytes": server_bytes,
            "generate_tokens": generate,
            "repeats": "4",
            "threads": "1",
            "threads_batch": "1",
            "device": "Vulkan0",
            "gpu_layers": "all",
            "compute_state_profile": "serve-baseline-fixed",
            "ksm_policy": "preserve-as-found",
            "control_checkpoint_semantics": "natural-boundary-v1",
        }
    )
    for key, value in expected.items():
        if identity.get(key) != value:
            raise ValueError(f"baseline identity differs at {key}")
    if digest(acquisition / "control-manifest.tsv") != identity["control_manifest_sha256"]:
        raise ValueError("baseline control manifest digest differs")
    print(digest(acquisition / "identity.tsv") + "\t" + digest(acquisition / "request-decode.json"))


if __name__ == "__main__":
    try:
        main()
    except (
        ValueError,
        OSError,
        KeyError,
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
    ) as error:
        raise SystemExit(f"baseline denominator refused: {error}") from error
