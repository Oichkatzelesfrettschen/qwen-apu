#!/usr/bin/env python3
"""Validate and summarize one immutable fixed-64 served-decode campaign."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import statistics
import tempfile
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, cast

MODEL_ORDER = (
    "qwen35-08b",
    "qwen38-2b-distill",
    "qwen38-4b-distill",
)
MODEL_CONTRACT = {
    "qwen35-08b": {
        "role": "compact-text",
        "model_file": "Qwen3.5-0.8B-GGUF/Qwen3.5-0.8B-Q8_0.gguf",
        "context": "8192",
        "batch": "128",
        "ubatch": "32",
        "cache_k": "q8_0",
        "cache_v": "q4_0",
        "flash_attention": "on",
        "ctx_checkpoints": "2",
        "checkpoint_min_step": "8192",
        "target_tok_s": "20",
    },
    "qwen38-2b-distill": {
        "role": "fast-text",
        "model_file": "Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf",
        "context": "24576",
        "batch": "128",
        "ubatch": "32",
        "cache_k": "q8_0",
        "cache_v": "q4_0",
        "flash_attention": "on",
        "ctx_checkpoints": "2",
        "checkpoint_min_step": "8192",
        "target_tok_s": "10",
    },
    "qwen38-4b-distill": {
        "role": "balanced-text",
        "model_file": "Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf",
        "context": "24576",
        "batch": "128",
        "ubatch": "32",
        "cache_k": "q8_0",
        "cache_v": "q4_0",
        "flash_attention": "on",
        "ctx_checkpoints": "2",
        "checkpoint_min_step": "8192",
        "target_tok_s": "5.25",
    },
}
BLOCK_DIRECTIONS = ("forward", "forward", "reverse", "reverse")
EXPECTED_TOKENS = 64
RATE_RELATIVE_TOLERANCE = Decimal("0.000001")
ARM_ARTIFACT_DIGEST_FIELDS = (
    ("inputs_sha256", "inputs.txt"),
    ("launch_sha256", "launch.txt"),
    ("teardown_sha256", "teardown.txt"),
    ("session_status_sha256", "session.status"),
    ("server_process_sha256", "server-process.json"),
    ("runtime_inputs_sha256", "runtime-inputs.json"),
    ("server_log_sha256", "server.log"),
    ("telemetry_log_sha256", "telemetry.log"),
    ("graphics_latency_log_sha256", "graphics-latency.log"),
    ("kernel_hazards_log_sha256", "kernel-hazards.log"),
    ("campaign_runner_stdout_sha256", "campaign-runner.stdout"),
    ("campaign_runner_stderr_sha256", "campaign-runner.stderr"),
    ("request_sha256", "request.json"),
    ("response_sha256", "response.json"),
    ("child_summary_sha256", "summary.json"),
)
EMPTY_ARM_ARTIFACTS = frozenset({"campaign-runner.stderr"})
CAMPAIGN_INPUT_KEYS = frozenset(
    {
        "schema",
        "repository_remote",
        "source_revision",
        "source_tracked_state",
        "require_clean_source",
        "runner_mode",
        "latency_probe_mode",
        "campaign_output_directory",
        "models_directory",
        "state_directory",
        "server_logical",
        "server_resolved",
        "execution_path",
        "execution_surface",
        "host_shortname",
        "ssh_session",
        "server_nice",
        "server_io_class",
        "vulkan_profile",
        "radv_icd",
        "inference_cpu",
        "server_port",
        "bind_host",
        "latency_mode",
        "router",
        "speculation",
        "backend_sampling",
        "require_api_key",
        "web_broker",
        "image_service",
        "generate_tokens",
        "sampling",
        "block_order",
        "slots_per_model",
        "cooldown_seconds",
        "workload_lock",
        "campaign_lock",
    }
)
BASE_IDENTITY_SUBJECTS = frozenset(
    {
        "orchestrator",
        "child_runner",
        "summarizer",
        "registry_reader",
        "artifact_reader",
        "signal_process_group",
        "model_registry",
        "artifact_ledger",
        "target_ledger",
        "quarantine_registry",
        "validated_tuples",
        "ctx_checkpoints",
        "launch_script",
        "teardown_script",
        "server",
        "radv_icd",
        *(f"model:{model_id}" for model_id in MODEL_ORDER),
    }
)


class CampaignError(ValueError):
    """Report an invalid retained campaign artifact."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_tsv(path: Path, expected_fields: tuple[str, ...]) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if tuple(reader.fieldnames or ()) != expected_fields:
            raise CampaignError(
                f"{path} fields differ: {reader.fieldnames!r} != {expected_fields!r}"
            )
        rows = list(reader)
    if any(None in row or any(value is None for value in row.values()) for row in rows):
        raise CampaignError(f"{path} contains a row with missing or extra fields")
    return rows


def load_json_object(path: Path) -> dict[str, Any]:
    def reject_nonfinite_constant(value: str) -> None:
        raise ValueError(f"nonfinite JSON constant: {value}")

    try:
        with path.open(encoding="utf-8") as handle:
            document = json.load(handle, parse_constant=reject_nonfinite_constant)
    except (OSError, ValueError) as error:
        raise CampaignError(f"{path} is not readable JSON: {error}") from error
    if not isinstance(document, dict):
        raise CampaignError(f"{path} must contain one JSON object")
    return document


def exact_integer(value: Any, name: str, path: Path) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise CampaignError(f"{path} field {name} must be an integer")
    # int() rather than cast(): mypy 1.x reads the isinstance-narrowed Any as
    # Any while 2.x reads a cast over it as redundant, and the constructor on
    # an int is the identity both versions accept.
    return int(value)


def exact_string(value: Any, name: str, path: Path) -> str:
    if not isinstance(value, str):
        raise CampaignError(f"{path} field {name} must be a string")
    return value


def is_sha256(value: str) -> bool:
    return len(value) == 64 and all(
        character in "0123456789abcdef" for character in value
    )


def is_git_object_id(value: str) -> bool:
    return len(value) in {40, 64} and all(
        character in "0123456789abcdef" for character in value
    )


def is_canonical_nonnegative_integer(value: str) -> bool:
    return value == "0" or (
        bool(value) and value.isascii() and value.isdecimal() and value[0] != "0"
    )


def is_ascii_nonnegative_integer(value: str) -> bool:
    return bool(value) and value.isascii() and value.isdecimal()


def read_unique_key_values(path: Path) -> dict[str, str]:
    rows = read_tsv(path, ("key", "value"))
    values = {row["key"]: row["value"] for row in rows}
    if len(values) != len(rows) or "" in values:
        raise CampaignError(f"{path} contains an empty or duplicate key")
    return values


def validate_campaign_inputs(path: Path) -> dict[str, str]:
    values = read_unique_key_values(path)
    if set(values) != CAMPAIGN_INPUT_KEYS:
        missing = sorted(CAMPAIGN_INPUT_KEYS - set(values))
        extra = sorted(set(values) - CAMPAIGN_INPUT_KEYS)
        raise CampaignError(f"{path} keys differ: missing={missing} extra={extra}")
    expected_policy = {
        "schema": "fixed64-served-campaign-v2",
        "execution_path": (
            "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ),
        "execution_surface": "hp14-ssh",
        "host_shortname": "hp14-dk1xxx",
        "ssh_session": "present",
        "server_nice": "19",
        "server_io_class": "idle",
        "vulkan_profile": "low-async",
        "inference_cpu": "0",
        "server_port": "8080",
        "bind_host": "127.0.0.1",
        "latency_mode": "observe",
        "router": "0",
        "speculation": "off",
        "backend_sampling": "0",
        "require_api_key": "0",
        "web_broker": "0",
        "image_service": "0",
        "generate_tokens": "64",
        "sampling": ("temperature=0 top_k=1 seed=1 ignore_eos=true thinking=false"),
        "block_order": "forward,forward,reverse,reverse",
        "slots_per_model": "4",
    }
    observed_policy = {key: values[key] for key in expected_policy}
    if observed_policy != expected_policy:
        raise CampaignError(f"{path} fixed v2 policy differs")

    runner_policy = (values["runner_mode"], values["latency_probe_mode"])
    if runner_policy not in {
        ("retained-git", "bound"),
        ("explicit", "not-applicable"),
    }:
        raise CampaignError(f"{path} runner and latency-probe policy differ")
    if not values["repository_remote"] or not values["server_logical"]:
        raise CampaignError(f"{path} repository or logical server is empty")
    for key in (
        "campaign_output_directory",
        "models_directory",
        "state_directory",
        "server_resolved",
        "radv_icd",
        "workload_lock",
        "campaign_lock",
    ):
        if not Path(values[key]).is_absolute():
            raise CampaignError(f"{path} {key} must be absolute")
    if not is_ascii_nonnegative_integer(values["cooldown_seconds"]):
        raise CampaignError(f"{path} cooldown_seconds must be a non-negative integer")

    state_directory = Path(values["state_directory"])
    expected_workload_lock = str(state_directory / "vulkan-workload.lock")
    if values["workload_lock"] != expected_workload_lock:
        raise CampaignError(f"{path} workload_lock differs from the state directory")
    expected_campaign_lock = str(state_directory / "fixed64-served-campaign.lock")
    if values["campaign_lock"] != expected_campaign_lock:
        raise CampaignError(f"{path} campaign_lock differs from the state directory")
    return values


def index_identity_rows(
    rows: list[dict[str, str]], path: Path
) -> dict[str, dict[str, str]]:
    indexed: dict[str, dict[str, str]] = {}
    for row in rows:
        subject = row["subject"]
        if not subject or subject in indexed:
            raise CampaignError(f"{path} contains an empty or duplicate subject")
        indexed[subject] = row
    return indexed


def read_identity_before(
    path: Path, latency_probe_mode: str
) -> dict[str, dict[str, str]]:
    rows = read_tsv(path, ("subject", "path", "bytes", "sha256"))
    indexed = index_identity_rows(rows, path)
    expected_subjects = set(BASE_IDENTITY_SUBJECTS)
    if latency_probe_mode == "bound":
        expected_subjects.add("latency_probe")
    if set(indexed) != expected_subjects:
        missing = sorted(expected_subjects - set(indexed))
        extra = sorted(set(indexed) - expected_subjects)
        raise CampaignError(
            f"{path} subject set differs: missing={missing} extra={extra}"
        )
    for subject, row in indexed.items():
        if not Path(row["path"]).is_absolute():
            raise CampaignError(f"{path} subject {subject} path must be absolute")
        if not is_canonical_nonnegative_integer(row["bytes"]) or row["bytes"] == "0":
            raise CampaignError(f"{path} subject {subject} bytes are invalid")
        if not is_sha256(row["sha256"]):
            raise CampaignError(f"{path} subject {subject} digest is invalid")
    return indexed


def validate_identity_check(before_path: Path, check_path: Path) -> None:
    before_rows = read_tsv(before_path, ("subject", "path", "bytes", "sha256"))
    before_by_subject = index_identity_rows(before_rows, before_path)
    check_rows = read_tsv(
        check_path,
        (
            "subject",
            "path",
            "expected_bytes",
            "observed_bytes",
            "expected_sha256",
            "observed_sha256",
            "state",
        ),
    )
    check_by_subject = index_identity_rows(check_rows, check_path)
    if set(check_by_subject) != set(before_by_subject):
        missing = sorted(set(before_by_subject) - set(check_by_subject))
        extra = sorted(set(check_by_subject) - set(before_by_subject))
        raise CampaignError(
            f"{check_path} differs from {before_path.name}: "
            f"missing={missing} extra={extra}"
        )
    for subject, before in before_by_subject.items():
        expected_check = {
            "subject": subject,
            "path": before["path"],
            "expected_bytes": before["bytes"],
            "observed_bytes": before["bytes"],
            "expected_sha256": before["sha256"],
            "observed_sha256": before["sha256"],
            "state": "accepted",
        }
        if check_by_subject[subject] != expected_check:
            raise CampaignError(
                f"{check_path} differs from {before_path.name}: subject {subject}"
            )


def read_model_artifact_ledger(path: Path) -> dict[str, dict[str, str]]:
    fields: tuple[str, ...] = (
        "model_id",
        "model_file",
        "publisher_bytes",
        "publisher_sha256",
        "source_repository",
        "source_revision",
    )
    rows: dict[str, dict[str, str]] = {}
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line or line.startswith("#"):
            continue
        values = line.split("\t")
        if len(values) != len(fields):
            raise CampaignError(f"{path} line {line_number} field count differs")
        row = cast(dict[str, str], dict(zip(fields, values, strict=True)))
        model_id = row["model_id"]
        if not model_id or model_id in rows:
            raise CampaignError(f"{path} line {line_number} model ID is invalid")
        rows[model_id] = row
    return rows


def require_arm_artifacts(arm_directory: Path) -> dict[str, Path]:
    artifacts = {
        filename: arm_directory / filename for _, filename in ARM_ARTIFACT_DIGEST_FIELDS
    }
    for filename, path in artifacts.items():
        if not path.is_file() or path.is_symlink():
            raise CampaignError(f"required arm artifact is absent or linked: {path}")
        if filename not in EMPTY_ARM_ARTIFACTS and path.stat().st_size == 0:
            raise CampaignError(f"required arm artifact is empty: {path}")
    return artifacts


def expected_server_argv(
    executable: str,
    model_descriptor_path: str,
    model: dict[str, str],
    campaign_output_directory: str,
) -> list[str]:
    runtime_root = Path(campaign_output_directory) / "configuration/runtime-source"
    static_path = str(runtime_root / "remote/../webui")
    return [
        executable,
        "--model",
        model_descriptor_path,
        "--host",
        "127.0.0.1",
        "--port",
        "8080",
        "--alias",
        "qwen-apu",
        "--cors-origins",
        "localhost",
        "--path",
        static_path,
        "--ui",
        "--log-verbosity",
        "4",
        "--device",
        "Vulkan0",
        "--split-mode",
        "none",
        "--n-gpu-layers",
        "all",
        "--override-tensor",
        ".*=Vulkan0",
        "--fit",
        "off",
        "--parallel",
        "1",
        "--threads",
        "1",
        "--threads-batch",
        "1",
        "--cache-ram",
        "0",
        "--no-context-shift",
        "--offline",
        "--checkpoint-min-step",
        model["checkpoint_min_step"],
        "--ctx-checkpoints",
        model["ctx_checkpoints"],
        "--ctx-size",
        model["context"],
        "--batch-size",
        model["batch"],
        "--ubatch-size",
        model["ubatch"],
        "--flash-attn",
        model["flash_attention"],
        "--cache-type-k",
        model["cache_k"],
        "--cache-type-v",
        model["cache_v"],
    ]


def require_proc_descriptor(path: str, descriptor: str, artifact_path: Path) -> str:
    parts = Path(path).parts
    if (
        len(parts) != 5
        or parts[:2] != ("/", "proc")
        or parts[3] != "fd"
        or parts[4] != descriptor
        or not is_canonical_nonnegative_integer(parts[2])
        or parts[2] == "0"
    ):
        raise CampaignError(
            f"{artifact_path} descriptor_path must be /proc/<positive-pid>/fd/{descriptor}"
        )
    return parts[2]


def validate_runtime_inputs(
    path: Path,
    expected_server: str,
    expected_server_sha256: str,
    expected_server_bytes: str,
    model: dict[str, str],
) -> dict[str, Any]:
    document = load_json_object(path)
    if set(document) != {"schema", "model", "executable"}:
        raise CampaignError(f"{path} runtime-input key set differs")
    if document["schema"] != "served-runtime-inputs-v1":
        raise CampaignError(f"{path} schema differs")

    model_identity = document["model"]
    model_keys = {
        "path",
        "descriptor_path",
        "device",
        "inode",
        "bytes",
        "sha256",
        "artifact_model_id",
        "artifact_model_file",
    }
    if not isinstance(model_identity, dict) or set(model_identity) != model_keys:
        raise CampaignError(f"{path} model identity key set differs")
    expected_model_strings = {
        "path": model["model_path"],
        "sha256": model["model_sha256"],
        "artifact_model_id": model["model_id"],
        "artifact_model_file": model["model_file"],
    }
    observed_model_strings = {
        key: exact_string(model_identity[key], key, path)
        for key in expected_model_strings
    }
    if observed_model_strings != expected_model_strings:
        raise CampaignError(f"{path} model identity differs from models-resolved.tsv")
    model_descriptor = exact_string(
        model_identity["descriptor_path"], "model.descriptor_path", path
    )
    runner_pid = require_proc_descriptor(model_descriptor, "7", path)
    for field in ("device", "inode", "bytes"):
        value = exact_integer(model_identity[field], f"model.{field}", path)
        if value < 0 or (field != "device" and value == 0):
            raise CampaignError(f"{path} model {field} must be positive")
    if model_identity["bytes"] != int(model["model_bytes"]):
        raise CampaignError(f"{path} model bytes differ from models-resolved.tsv")
    if not is_sha256(observed_model_strings["sha256"]):
        raise CampaignError(f"{path} model sha256 is invalid")

    executable_identity = document["executable"]
    executable_keys = {
        "path",
        "descriptor_path",
        "device",
        "inode",
        "bytes",
        "sha256",
    }
    if (
        not isinstance(executable_identity, dict)
        or set(executable_identity) != executable_keys
    ):
        raise CampaignError(f"{path} executable identity key set differs")
    expected_executable_strings = {
        "path": expected_server,
        "sha256": expected_server_sha256,
    }
    observed_executable_strings = {
        key: exact_string(executable_identity[key], f"executable.{key}", path)
        for key in expected_executable_strings
    }
    if observed_executable_strings != expected_executable_strings:
        raise CampaignError(f"{path} executable identity differs from identity-before")
    executable_descriptor = exact_string(
        executable_identity["descriptor_path"], "executable.descriptor_path", path
    )
    if require_proc_descriptor(executable_descriptor, "6", path) != runner_pid:
        raise CampaignError(
            f"{path} model and executable descriptors use different PIDs"
        )
    for field in ("device", "inode", "bytes"):
        value = exact_integer(executable_identity[field], f"executable.{field}", path)
        if value < 0 or (field != "device" and value == 0):
            raise CampaignError(f"{path} executable {field} must be positive")
    if executable_identity["bytes"] != int(expected_server_bytes):
        raise CampaignError(f"{path} executable bytes differ from identity-before")
    if not is_sha256(observed_executable_strings["sha256"]):
        raise CampaignError(f"{path} executable sha256 is invalid")
    return document


def validate_server_process(
    path: Path,
    expected_server: str,
    expected_server_sha256: str,
    runtime_inputs: dict[str, Any],
    model: dict[str, str],
    campaign_output_directory: str,
    execution_surface: str,
    host_shortname: str,
    ssh_session: str,
) -> int:
    document = load_json_object(path)
    expected_keys = {
        "schema",
        "execution_surface",
        "host_shortname",
        "ssh_session",
        "pid",
        "start_time_ticks",
        "executable",
        "executable_proc_link",
        "executable_device",
        "executable_inode",
        "executable_bytes",
        "executable_sha256",
        "argv",
        "nice",
        "cpus_allowed_list",
        "io_class",
    }
    if set(document) != expected_keys:
        raise CampaignError(f"{path} server-process key set differs")
    if document["schema"] != "served-decode-process-v3":
        raise CampaignError(f"{path} schema differs")
    expected_execution_contract = {
        "execution_surface": execution_surface,
        "host_shortname": host_shortname,
        "ssh_session": ssh_session,
    }
    observed_execution_contract = {
        key: exact_string(document[key], key, path)
        for key in expected_execution_contract
    }
    if observed_execution_contract != expected_execution_contract:
        raise CampaignError(f"{path} execution-surface contract differs")
    server_pid = exact_integer(document["pid"], "pid", path)
    if server_pid <= 0:
        raise CampaignError(f"{path} pid must be positive")
    if exact_integer(document["start_time_ticks"], "start_time_ticks", path) <= 0:
        raise CampaignError(f"{path} start_time_ticks must be positive")

    executable = exact_string(document["executable"], "executable", path)
    if not Path(executable).is_absolute() or executable != expected_server:
        raise CampaignError(f"{path} executable differs from server_resolved")
    executable_sha256 = exact_string(
        document["executable_sha256"], "executable_sha256", path
    )
    if not is_sha256(executable_sha256) or executable_sha256 != expected_server_sha256:
        raise CampaignError(f"{path} executable_sha256 differs from identity-before")
    runtime_executable = cast(dict[str, Any], runtime_inputs["executable"])
    observed_executable_identity = {
        "path": executable,
        "device": exact_integer(
            document["executable_device"], "executable_device", path
        ),
        "inode": exact_integer(document["executable_inode"], "executable_inode", path),
        "bytes": exact_integer(document["executable_bytes"], "executable_bytes", path),
        "sha256": executable_sha256,
    }
    expected_executable_identity = {
        key: runtime_executable[key] for key in observed_executable_identity
    }
    if observed_executable_identity != expected_executable_identity:
        raise CampaignError(f"{path} executable identity differs from runtime-inputs")
    executable_proc_link = exact_string(
        document["executable_proc_link"], "executable_proc_link", path
    )
    if executable_proc_link != runtime_executable["path"]:
        raise CampaignError(f"{path} executable_proc_link differs from runtime-inputs")

    argv_value = document["argv"]
    if (
        not isinstance(argv_value, list)
        or not argv_value
        or any(not isinstance(argument, str) for argument in argv_value)
    ):
        raise CampaignError(f"{path} argv must be a nonempty string list")
    argv = cast(list[str], argv_value)
    runtime_model = cast(dict[str, Any], runtime_inputs["model"])
    expected_argv = expected_server_argv(
        executable,
        cast(str, runtime_model["descriptor_path"]),
        model,
        campaign_output_directory,
    )
    if argv != expected_argv:
        mismatch_index = next(
            (
                index
                for index, (observed, expected) in enumerate(
                    zip(argv, expected_argv, strict=False)
                )
                if observed != expected
            ),
            min(len(argv), len(expected_argv)),
        )
        observed_argument = argv[mismatch_index] if mismatch_index < len(argv) else None
        expected_argument = (
            expected_argv[mismatch_index]
            if mismatch_index < len(expected_argv)
            else None
        )
        raise CampaignError(
            f"{path} server-process argv differs from the canonical launch "
            f"at index {mismatch_index}: "
            f"observed={observed_argument!r} expected={expected_argument!r}; "
            f"lengths={len(argv)}/{len(expected_argv)}"
        )

    if exact_integer(document["nice"], "nice", path) != 19:
        raise CampaignError(f"{path} nice value differs from 19")
    if document["cpus_allowed_list"] != "0":
        raise CampaignError(f"{path} cpus_allowed_list differs from CPU 0")
    if document["io_class"] != "idle":
        raise CampaignError(f"{path} io_class differs from idle")
    return server_pid


def parse_status_fields(line: str, prefix: str, path: Path) -> dict[str, str]:
    if prefix:
        marker = f"{prefix} "
        if not line.startswith(marker):
            raise CampaignError(f"{path} lacks the {prefix} status section")
        line = line[len(marker) :]
    fields: dict[str, str] = {}
    for token in line.split():
        key, separator, value = token.partition("=")
        if not separator or not key or not value or key in fields:
            raise CampaignError(
                f"{path} contains a malformed {prefix or 'state'} field"
            )
        fields[key] = value
    return fields


def validate_session_status(path: Path, model: dict[str, str]) -> int:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines:
        raise CampaignError(f"{path} is empty")
    state_fields = parse_status_fields(lines[0], "", path)
    expected_state_keys = {
        "state",
        "server_pid",
        "monitor_pid",
        "latency_watchdog_pid",
        "kernel_hazard_watchdog_pid",
        "profile",
        "host",
        "port",
        "context",
        "latency_mode",
        "utc",
    }
    # The session records its LAN exposure on the running line since the LAN
    # lane landed, as five keys a campaign retained before that lane lacks.
    # They are admitted as a set, and a denominator arm is a loopback launch,
    # so an exposed session refuses the arm rather than passing as a rate.
    lan_state_keys = {
        "lan_exposure",
        "lan_address",
        "lan_name",
        "lan_open",
        "lan_boundary",
    }
    present_lan_keys = set(state_fields) & lan_state_keys
    if present_lan_keys and present_lan_keys != lan_state_keys:
        raise CampaignError(
            f"{path} carries a partial LAN key set: {sorted(present_lan_keys)}"
        )
    core_fields = set(state_fields) - lan_state_keys
    if core_fields != expected_state_keys:
        missing = sorted(expected_state_keys - core_fields)
        extra = sorted(core_fields - expected_state_keys)
        raise CampaignError(
            f"{path} state keys differ: missing={missing} extra={extra}"
        )
    if present_lan_keys and (
        state_fields["lan_exposure"] != "0" or state_fields["lan_open"] != "0"
    ):
        raise CampaignError(
            f"{path} names an exposed session: lan_exposure="
            f"{state_fields['lan_exposure']} lan_open={state_fields['lan_open']}"
        )
    expected_state_values = {
        "state": "running",
        "profile": "low-async",
        "host": "127.0.0.1",
        "port": "8080",
        "context": model["context"],
        "latency_mode": "observe",
    }
    observed_state_values = {key: state_fields[key] for key in expected_state_values}
    if observed_state_values != expected_state_values:
        raise CampaignError(f"{path} state values differ from the fixed campaign")
    for pid_key in (
        "server_pid",
        "monitor_pid",
        "latency_watchdog_pid",
        "kernel_hazard_watchdog_pid",
    ):
        pid_value = state_fields[pid_key]
        if not is_canonical_nonnegative_integer(pid_value) or pid_value == "0":
            raise CampaignError(f"{path} {pid_key} must be a canonical positive PID")
    server_pid = int(state_fields["server_pid"])

    sections: dict[str, str] = {}
    for line in lines[1:]:
        section, separator, _ = line.partition(" ")
        if not separator:
            raise CampaignError(f"{path} contains a malformed status section")
        if section in {"speculation", "cache", "router"}:
            if section in sections:
                raise CampaignError(f"{path} repeats the {section} section")
            sections[section] = line
    if set(sections) != {"speculation", "cache", "router"}:
        raise CampaignError(f"{path} lacks a required policy section")

    speculation = parse_status_fields(sections["speculation"], "speculation", path)
    if (
        speculation.get("spec_type") != "off"
        or speculation.get("draft_backend_sampling") != "0"
        or speculation.get("backend_sampling") != "0"
    ):
        raise CampaignError(f"{path} enables speculation or backend sampling")
    cache = parse_status_fields(sections["cache"], "cache", path)
    if {
        "cache_type_k": cache.get("cache_type_k"),
        "cache_type_v": cache.get("cache_type_v"),
        "flash_attention": cache.get("flash_attention"),
    } != {
        "cache_type_k": model["cache_k"],
        "cache_type_v": model["cache_v"],
        "flash_attention": model["flash_attention"],
    }:
        raise CampaignError(f"{path} cache triple differs from the scheduled model")
    router = parse_status_fields(sections["router"], "router", path)
    if router.get("enabled") != "0":
        raise CampaignError(f"{path} does not declare router disabled")
    return server_pid


def validate_arm_server_identity(
    session_status_path: Path,
    server_process_path: Path,
    runtime_inputs_path: Path,
    expected_server: str,
    expected_server_sha256: str,
    expected_server_bytes: str,
    model: dict[str, str],
    campaign_output_directory: str,
    execution_surface: str,
    host_shortname: str,
    ssh_session: str,
) -> int:
    canonical_server_pid = validate_session_status(session_status_path, model)
    runtime_inputs = validate_runtime_inputs(
        runtime_inputs_path,
        expected_server,
        expected_server_sha256,
        expected_server_bytes,
        model,
    )
    captured_server_pid = validate_server_process(
        server_process_path,
        expected_server,
        expected_server_sha256,
        runtime_inputs,
        model,
        campaign_output_directory,
        execution_surface,
        host_shortname,
        ssh_session,
    )
    if captured_server_pid != canonical_server_pid:
        raise CampaignError(
            f"{server_process_path} pid differs from canonical server_pid "
            f"in {session_status_path}"
        )
    return canonical_server_pid


def positive_decimal(value: Any, name: str, path: Path) -> Decimal:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise CampaignError(f"{path} field {name} must be numeric")
    try:
        finite_value = float(value)
    except (OverflowError, ValueError) as error:
        raise CampaignError(
            f"{path} field {name} must be finite and positive"
        ) from error
    if not math.isfinite(finite_value) or finite_value <= 0:
        raise CampaignError(f"{path} field {name} must be finite and positive")
    try:
        return Decimal(str(value))
    except InvalidOperation as error:
        raise CampaignError(f"{path} field {name} is not decimal") from error


def require_exact_request(path: Path, canonical_bytes: bytes) -> str:
    request_bytes = path.read_bytes()
    if request_bytes != canonical_bytes:
        raise CampaignError(f"{path} differs from the retained canonical request")
    document = load_json_object(path)
    if set(document) != {
        "model",
        "messages",
        "max_tokens",
        "temperature",
        "top_k",
        "seed",
        "ignore_eos",
        "chat_template_kwargs",
    }:
        raise CampaignError(f"{path} request key set differs")
    expected = {
        "model": "qwen-apu",
        "messages": [{"role": "user", "content": "Write one paragraph about tides."}],
        "max_tokens": EXPECTED_TOKENS,
        "temperature": 0,
        "top_k": 1,
        "seed": 1,
        "ignore_eos": True,
        "chat_template_kwargs": {"enable_thinking": False},
    }
    if document != expected:
        raise CampaignError(f"{path} request values differ")
    return hashlib.sha256(request_bytes).hexdigest()


def expected_schedule() -> list[tuple[int, int, str, str]]:
    rows: list[tuple[int, int, str, str]] = []
    slot = 0
    for block, direction in enumerate(BLOCK_DIRECTIONS, start=1):
        model_ids = (
            MODEL_ORDER if direction == "forward" else tuple(reversed(MODEL_ORDER))
        )
        for model_id in model_ids:
            slot += 1
            rows.append((slot, block, direction, model_id))
    return rows


def summarize(
    campaign_directory: Path, summary_path: Path, model_summary_path: Path
) -> str:
    schedule_fields = (
        "slot",
        "block",
        "direction",
        "model_id",
        "role",
        "target_tok_s",
        "arm_directory",
    )
    model_fields = (
        "model_id",
        "role",
        "model_file",
        "model_path",
        "context",
        "batch",
        "ubatch",
        "cache_k",
        "cache_v",
        "flash_attention",
        "ctx_checkpoints",
        "checkpoint_min_step",
        "target_tok_s",
        "publisher_bytes",
        "publisher_sha256",
        "source_repository",
        "source_revision",
        "model_bytes",
        "model_sha256",
    )
    status_fields = ("slot", "model_id", "runner_status", "state")
    schedule = read_tsv(campaign_directory / "schedule.tsv", schedule_fields)
    models = read_tsv(campaign_directory / "models-resolved.tsv", model_fields)
    statuses = read_tsv(campaign_directory / "arm-status.tsv", status_fields)
    for witness_name in ("source-index", "source-status", "source-head"):
        before_path = campaign_directory / f"{witness_name}-before.tsv"
        after_path = campaign_directory / f"{witness_name}-after.tsv"
        if witness_name != "source-index":
            before_path = before_path.with_suffix(".txt")
            after_path = after_path.with_suffix(".txt")
        if before_path.read_bytes() != after_path.read_bytes():
            raise CampaignError(f"{witness_name} changed during the campaign")
    campaign_inputs = validate_campaign_inputs(
        campaign_directory / "campaign-inputs.tsv"
    )
    source_revision = campaign_inputs["source_revision"]
    source_head = (
        (campaign_directory / "source-head-before.txt")
        .read_text(encoding="ascii")
        .strip()
    )
    source_status_bytes = (campaign_directory / "source-status-before.txt").read_bytes()
    observed_source_state = "clean" if not source_status_bytes else "modified"
    if (
        source_revision != source_head
        or not is_git_object_id(source_revision)
        or campaign_inputs["source_tracked_state"] != observed_source_state
        or campaign_inputs["require_clean_source"] not in {"0", "1"}
        or (
            campaign_inputs["require_clean_source"] == "1"
            and observed_source_state != "clean"
        )
    ):
        raise CampaignError("campaign source identity or tracked-state policy differs")
    expected_server = campaign_inputs["server_resolved"]
    identity_before = read_identity_before(
        campaign_directory / "identity-before.tsv",
        campaign_inputs["latency_probe_mode"],
    )
    server_identity = identity_before["server"]
    expected_server_sha256 = server_identity["sha256"]
    if server_identity["path"] != expected_server:
        raise CampaignError(
            "identity-before.tsv server identity differs from server_resolved"
        )
    radv_identity = identity_before["radv_icd"]
    if radv_identity["path"] != campaign_inputs["radv_icd"]:
        raise CampaignError(
            "campaign-inputs.tsv radv_icd differs from identity-before.tsv"
        )
    if len(schedule) != 12 or len(statuses) != 12:
        raise CampaignError("the campaign requires twelve schedule and status rows")

    model_by_id = {row["model_id"]: row for row in models}
    if tuple(model_by_id) != MODEL_ORDER or len(models) != len(MODEL_ORDER):
        raise CampaignError("models-resolved.tsv differs from the three-model order")
    artifact_rows = read_model_artifact_ledger(
        campaign_directory / "configuration/model-artifacts.tsv"
    )
    if tuple(artifact_rows) != MODEL_ORDER:
        raise CampaignError("model-artifacts.tsv differs from the three-model order")
    for model_id, model in model_by_id.items():
        expected_contract = MODEL_CONTRACT[model_id]
        observed_contract = {field: model[field] for field in expected_contract}
        if observed_contract != expected_contract:
            raise CampaignError(
                f"models-resolved.tsv registry-default contract differs for {model_id}"
            )
        models_directory = campaign_inputs["models_directory"]
        expected_model_path = str(Path(models_directory) / model["model_file"])
        expected_artifact_identity = artifact_rows[model_id]
        observed_artifact_identity = {
            field: model[field] for field in expected_artifact_identity
        }
        if (
            model["model_path"] != expected_model_path
            or model["publisher_bytes"] != model["model_bytes"]
            or model["publisher_sha256"] != model["model_sha256"]
            or not model["publisher_bytes"].isdigit()
            or int(model["publisher_bytes"]) <= 0
            or not is_sha256(model["publisher_sha256"])
            or not model["source_repository"]
            or not is_git_object_id(model["source_revision"])
            or observed_artifact_identity != expected_artifact_identity
        ):
            raise CampaignError(
                f"models-resolved.tsv publisher identity differs for {model_id}"
            )
        model_identity = identity_before[f"model:{model_id}"]
        if model_identity != {
            "subject": f"model:{model_id}",
            "path": model["model_path"],
            "bytes": model["model_bytes"],
            "sha256": model["model_sha256"],
        }:
            raise CampaignError(
                f"identity-before.tsv model identity differs for {model_id}"
            )
    if campaign_inputs["require_clean_source"] == "1":
        for relative_configuration in (
            "models.tsv",
            "model-artifacts.tsv",
            "throughput-targets.tsv",
            "quarantine.tsv",
            "validated-tuples.tsv",
            "ctx-checkpoints.tsv",
        ):
            retained_path = (
                campaign_directory / "configuration" / relative_configuration
            )
            archived_path = (
                campaign_directory
                / "configuration/runtime-source/remote"
                / relative_configuration
            )
            if retained_path.read_bytes() != archived_path.read_bytes():
                raise CampaignError(
                    f"retained and Git-archived {relative_configuration} differ"
                )
    status_by_slot = {row["slot"]: row for row in statuses}
    if len(status_by_slot) != len(statuses):
        raise CampaignError("arm-status.tsv contains duplicate slots")

    expected_rows = expected_schedule()
    canonical_request_path = campaign_directory / "request.json"
    canonical_request_bytes = canonical_request_path.read_bytes()
    canonical_request_sha256 = require_exact_request(
        canonical_request_path, canonical_request_bytes
    )

    summary_fields = (
        "slot",
        "block",
        "direction",
        "model_id",
        "role",
        "target_tok_s",
        "target_state",
        "context",
        "batch",
        "ubatch",
        "cache_k",
        "cache_v",
        "flash_attention",
        "ctx_checkpoints",
        "checkpoint_min_step",
        "vulkan_profile",
        "prompt_tokens",
        "prompt_ms",
        "prefill_tok_s",
        "decode_tokens",
        "predicted_ms",
        "reported_tok_s",
        "recomputed_tok_s",
        "request_status",
        "teardown_status",
        "child_valid",
        "model_bytes",
        "model_sha256",
        *(field for field, _ in ARM_ARTIFACT_DIGEST_FIELDS),
        "arm_directory",
    )
    summary_rows: list[dict[str, str]] = []
    rates_by_model: dict[str, list[Decimal]] = {
        model_id: [] for model_id in MODEL_ORDER
    }
    prompt_counts_by_model: dict[str, set[int]] = {
        model_id: set() for model_id in MODEL_ORDER
    }

    for schedule_row, expected_row in zip(schedule, expected_rows, strict=True):
        expected_slot, expected_block, expected_direction, expected_model = expected_row
        observed_shape = (
            schedule_row["slot"],
            schedule_row["block"],
            schedule_row["direction"],
            schedule_row["model_id"],
        )
        expected_shape = (
            str(expected_slot),
            str(expected_block),
            expected_direction,
            expected_model,
        )
        if observed_shape != expected_shape:
            raise CampaignError(
                f"schedule slot {expected_slot} differs: {observed_shape!r}"
            )

        model = model_by_id[expected_model]
        if schedule_row["role"] != model["role"]:
            raise CampaignError(f"schedule role differs for {expected_model}")
        if schedule_row["target_tok_s"] != model["target_tok_s"]:
            raise CampaignError(f"schedule target differs for {expected_model}")
        status = status_by_slot.get(str(expected_slot))
        if status != {
            "slot": str(expected_slot),
            "model_id": expected_model,
            "runner_status": "0",
            "state": "completed",
        }:
            raise CampaignError(f"slot {expected_slot} did not complete cleanly")

        arm_relative = Path(schedule_row["arm_directory"])
        if arm_relative.is_absolute() or ".." in arm_relative.parts:
            raise CampaignError(f"slot {expected_slot} arm path is not relative")
        arm_directory = campaign_directory / arm_relative
        arm_artifacts = require_arm_artifacts(arm_directory)
        request_path = arm_artifacts["request.json"]
        response_path = arm_artifacts["response.json"]
        child_summary_path = arm_artifacts["summary.json"]
        input_path = arm_artifacts["inputs.txt"]
        validate_arm_server_identity(
            arm_artifacts["session.status"],
            arm_artifacts["server-process.json"],
            arm_artifacts["runtime-inputs.json"],
            expected_server,
            expected_server_sha256,
            server_identity["bytes"],
            model,
            campaign_inputs["campaign_output_directory"],
            campaign_inputs["execution_surface"],
            campaign_inputs["host_shortname"],
            campaign_inputs["ssh_session"],
        )

        request_sha256 = require_exact_request(request_path, canonical_request_bytes)
        if request_sha256 != canonical_request_sha256:
            raise CampaignError(f"slot {expected_slot} request digest differs")

        input_fields: dict[str, str] = {}
        for line in input_path.read_text(encoding="utf-8").splitlines():
            key, separator, value = line.partition("=")
            if not separator or key in input_fields:
                raise CampaignError(f"{input_path} contains a malformed field")
            input_fields[key] = value
        if set(input_fields) != {
            "label",
            "model",
            "profile",
            "cache_type_k",
            "cache_type_v",
            "flash_attention",
            "ctx_checkpoints",
            "checkpoint_min_step",
            "generate_tokens",
        }:
            raise CampaignError(f"{input_path} field set differs")
        expected_label = f"{expected_slot:02d}-{expected_direction}-{expected_model}"
        expected_inputs = {
            "label": expected_label,
            "model": model["model_path"],
            "profile": "low-async",
            "cache_type_k": model["cache_k"],
            "cache_type_v": model["cache_v"],
            "flash_attention": model["flash_attention"],
            "ctx_checkpoints": model["ctx_checkpoints"],
            "checkpoint_min_step": model["checkpoint_min_step"],
            "generate_tokens": str(EXPECTED_TOKENS),
        }
        if input_fields != expected_inputs:
            raise CampaignError(f"{input_path} values differ from the schedule")

        response = load_json_object(response_path)
        timings = response.get("timings")
        if not isinstance(timings, dict):
            raise CampaignError(f"{response_path} timings must be an object")
        prompt_n = exact_integer(timings.get("prompt_n"), "prompt_n", response_path)
        if prompt_n <= 0:
            raise CampaignError(f"{response_path} field prompt_n must be positive")
        prompt_ms = positive_decimal(
            timings.get("prompt_ms"), "prompt_ms", response_path
        )
        prompt_rate = positive_decimal(
            timings.get("prompt_per_second"),
            "prompt_per_second",
            response_path,
        )
        recomputed_prompt_rate = Decimal(1000) * Decimal(prompt_n) / prompt_ms
        prompt_rate_error = (
            abs(prompt_rate - recomputed_prompt_rate) / recomputed_prompt_rate
        )
        if prompt_rate_error > RATE_RELATIVE_TOLERANCE:
            raise CampaignError(
                f"{response_path} prompt rate differs from elapsed time: "
                f"{prompt_rate} versus {recomputed_prompt_rate}"
            )
        predicted_n = exact_integer(
            timings.get("predicted_n"), "predicted_n", response_path
        )
        if predicted_n != EXPECTED_TOKENS:
            raise CampaignError(
                f"{response_path} predicted_n is {predicted_n}, expected {EXPECTED_TOKENS}"
            )
        predicted_ms = positive_decimal(
            timings.get("predicted_ms"), "predicted_ms", response_path
        )
        reported_rate = positive_decimal(
            timings.get("predicted_per_second"),
            "predicted_per_second",
            response_path,
        )
        recomputed_rate = Decimal(1000) * Decimal(predicted_n - 1) / predicted_ms
        relative_error = abs(reported_rate - recomputed_rate) / recomputed_rate
        if relative_error > RATE_RELATIVE_TOLERANCE:
            raise CampaignError(
                f"{response_path} rate differs from post-first elapsed time: "
                f"{reported_rate} versus {recomputed_rate}"
            )

        child_summary = load_json_object(child_summary_path)
        if set(child_summary) != {
            "label",
            "request_status",
            "teardown_status",
            "prefill_tok_per_second",
            "prefill_ms",
            "decode_tok_per_second",
            "decode_ms",
            "prompt_tokens",
            "decode_tokens",
            "valid",
        }:
            raise CampaignError(f"{child_summary_path} field set differs")
        if child_summary.get("label") != expected_label:
            raise CampaignError(f"{child_summary_path} label differs")
        request_status = exact_integer(
            child_summary.get("request_status"), "request_status", child_summary_path
        )
        teardown_status = exact_integer(
            child_summary.get("teardown_status"), "teardown_status", child_summary_path
        )
        child_tokens = exact_integer(
            child_summary.get("decode_tokens"), "decode_tokens", child_summary_path
        )
        child_prompt_tokens = exact_integer(
            child_summary.get("prompt_tokens"), "prompt_tokens", child_summary_path
        )
        if child_prompt_tokens != prompt_n:
            raise CampaignError(
                f"{child_summary_path} prompt count differs from the response"
            )
        if request_status != 0 or teardown_status != 0 or child_tokens != predicted_n:
            raise CampaignError(f"{child_summary_path} carries a failed child status")
        if child_summary.get("valid") is not True:
            raise CampaignError(f"{child_summary_path} is not valid")
        child_rate = positive_decimal(
            child_summary.get("decode_tok_per_second"),
            "decode_tok_per_second",
            child_summary_path,
        )
        if abs(child_rate - reported_rate) > Decimal("0.000000001"):
            raise CampaignError(f"{child_summary_path} rate differs from the response")
        child_prompt_rate = positive_decimal(
            child_summary.get("prefill_tok_per_second"),
            "prefill_tok_per_second",
            child_summary_path,
        )
        if abs(child_prompt_rate - prompt_rate) > Decimal("0.000000001"):
            raise CampaignError(
                f"{child_summary_path} prompt rate differs from the response"
            )
        child_prompt_ms = positive_decimal(
            child_summary.get("prefill_ms"), "prefill_ms", child_summary_path
        )
        if abs(child_prompt_ms - prompt_ms) > Decimal("0.000000001"):
            raise CampaignError(
                f"{child_summary_path} prompt elapsed time differs from the response"
            )
        child_decode_ms = positive_decimal(
            child_summary.get("decode_ms"), "decode_ms", child_summary_path
        )
        if abs(child_decode_ms - predicted_ms) > Decimal("0.000000001"):
            raise CampaignError(
                f"{child_summary_path} decode elapsed time differs from the response"
            )

        target = Decimal(model["target_tok_s"])
        target_state = "met" if recomputed_rate >= target else "unmet"
        rates_by_model[expected_model].append(recomputed_rate)
        prompt_counts_by_model[expected_model].add(prompt_n)
        artifact_digests = {
            field: sha256_file(arm_artifacts[filename])
            for field, filename in ARM_ARTIFACT_DIGEST_FIELDS
        }
        summary_row = {
            "slot": str(expected_slot),
            "block": str(expected_block),
            "direction": expected_direction,
            "model_id": expected_model,
            "role": model["role"],
            "target_tok_s": model["target_tok_s"],
            "target_state": target_state,
            "context": model["context"],
            "batch": model["batch"],
            "ubatch": model["ubatch"],
            "cache_k": model["cache_k"],
            "cache_v": model["cache_v"],
            "flash_attention": model["flash_attention"],
            "ctx_checkpoints": model["ctx_checkpoints"],
            "checkpoint_min_step": model["checkpoint_min_step"],
            "vulkan_profile": "low-async",
            "prompt_tokens": str(prompt_n),
            "prompt_ms": format(prompt_ms, "f"),
            "prefill_tok_s": format(prompt_rate, "f"),
            "decode_tokens": str(predicted_n),
            "predicted_ms": format(predicted_ms, "f"),
            "reported_tok_s": format(reported_rate, "f"),
            "recomputed_tok_s": format(recomputed_rate, ".12f"),
            "request_status": str(request_status),
            "teardown_status": str(teardown_status),
            "child_valid": "true",
            "model_bytes": model["model_bytes"],
            "model_sha256": model["model_sha256"],
            "arm_directory": schedule_row["arm_directory"],
        }
        summary_row.update(artifact_digests)
        if summary_row["request_sha256"] != request_sha256:
            raise CampaignError(f"slot {expected_slot} request digest changed")
        summary_rows.append(summary_row)

    for model_id, prompt_counts in prompt_counts_by_model.items():
        if len(prompt_counts) != 1:
            raise CampaignError(
                f"model {model_id} prompt token count differs across identical requests"
            )

    with summary_path.open("x", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=summary_fields, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(summary_rows)

    model_summary_fields: tuple[str, ...] = (
        "model_id",
        "role",
        "target_tok_s",
        "arms",
        "arms_meeting_target",
        "minimum_tok_s",
        "mean_tok_s",
        "median_tok_s",
        "maximum_tok_s",
        "span_percent",
        "target_state",
    )
    model_summary_rows: list[dict[str, str]] = []
    all_models_meet_target = True
    for model_id in MODEL_ORDER:
        model = model_by_id[model_id]
        rates = rates_by_model[model_id]
        if len(rates) != 4:
            raise CampaignError(f"{model_id} has {len(rates)} arms instead of four")
        target = Decimal(model["target_tok_s"])
        passing = sum(rate >= target for rate in rates)
        minimum = min(rates)
        maximum = max(rates)
        mean = sum(rates) / Decimal(len(rates))
        median = Decimal(str(statistics.median(rates)))
        span_percent = Decimal(100) * (maximum - minimum) / mean
        target_state = "met" if passing == 4 else "unmet"
        all_models_meet_target = all_models_meet_target and target_state == "met"
        model_summary_rows.append(
            {
                "model_id": model_id,
                "role": model["role"],
                "target_tok_s": model["target_tok_s"],
                "arms": "4",
                "arms_meeting_target": str(passing),
                "minimum_tok_s": format(minimum, "f"),
                "mean_tok_s": format(mean, ".12f"),
                "median_tok_s": format(median, ".12f"),
                "maximum_tok_s": format(maximum, "f"),
                "span_percent": format(span_percent, ".9f"),
                "target_state": target_state,
            }
        )
    with model_summary_path.open("x", newline="", encoding="utf-8") as handle:
        model_summary_writer: csv.DictWriter[str] = csv.DictWriter(
            handle,
            fieldnames=model_summary_fields,
            delimiter="\t",
            lineterminator="\n",
        )
        model_summary_writer.writeheader()
        model_summary_writer.writerows(model_summary_rows)
    return "met" if all_models_meet_target else "unmet"


def verify_sealed(
    campaign_directory: Path, selected_manifest: Path | None = None
) -> None:
    campaign_resolved = campaign_directory.resolve(strict=True)
    if selected_manifest is None:
        manifest_path = campaign_directory / "SHA256SUMS"
    else:
        manifest_candidate = (
            selected_manifest
            if selected_manifest.is_absolute()
            else Path.cwd() / selected_manifest
        )
        if manifest_candidate.parent.resolve(strict=True) != campaign_resolved:
            raise CampaignError(
                "--manifest-path must name a file directly under the campaign"
            )
        manifest_path = campaign_directory / manifest_candidate.name
    if not manifest_path.is_file() or manifest_path.is_symlink():
        raise CampaignError(f"selected manifest is absent or linked: {manifest_path}")

    manifest_bytes = manifest_path.read_bytes()
    try:
        manifest_text = manifest_bytes.decode("utf-8")
    except UnicodeDecodeError as error:
        raise CampaignError(f"{manifest_path} is not UTF-8: {error}") from error
    manifest_entries: dict[str, str] = {}
    for line_number, line in enumerate(manifest_text.splitlines(), start=1):
        digest, separator, relative_path = line.partition("  ")
        if (
            not separator
            or not is_sha256(digest)
            or not relative_path.startswith("./")
            or relative_path in manifest_entries
        ):
            raise CampaignError(f"{manifest_path} line {line_number} is malformed")
        manifest_entries[relative_path] = digest

    observed_entries: dict[str, str] = {}
    for path in campaign_directory.rglob("*"):
        if path.is_symlink():
            raise CampaignError(f"sealed campaign contains a symbolic link: {path}")
        if path.is_dir():
            continue
        if not path.is_file():
            raise CampaignError(f"sealed campaign contains a special path: {path}")
        if path == manifest_path:
            continue
        relative_path = f"./{path.relative_to(campaign_directory).as_posix()}"
        observed_entries[relative_path] = sha256_file(path)
    if manifest_entries != observed_entries:
        missing = sorted(set(observed_entries) - set(manifest_entries))
        extra = sorted(set(manifest_entries) - set(observed_entries))
        changed = sorted(
            path
            for path in set(observed_entries) & set(manifest_entries)
            if observed_entries[path] != manifest_entries[path]
        )
        raise CampaignError(
            f"sealed manifest differs: missing={missing} extra={extra} changed={changed}"
        )
    expected_manifest_bytes = "".join(
        f"{digest}  {relative_path}\n"
        for relative_path, digest in sorted(observed_entries.items())
    ).encode("utf-8")
    if manifest_bytes != expected_manifest_bytes:
        raise CampaignError("sealed manifest serialization or ordering differs")

    with tempfile.TemporaryDirectory(
        prefix="fixed64-campaign-sealed-verification-"
    ) as temporary_directory:
        temporary_root = Path(temporary_directory)
        recomputed_summary = temporary_root / "summary.tsv"
        recomputed_model_summary = temporary_root / "model-summary.tsv"
        recomputed_target_state = summarize(
            campaign_directory, recomputed_summary, recomputed_model_summary
        )
        if (
            recomputed_summary.read_bytes()
            != (campaign_directory / "summary.tsv").read_bytes()
        ):
            raise CampaignError("sealed summary differs from full recomputation")
        if (
            recomputed_model_summary.read_bytes()
            != (campaign_directory / "model-summary.tsv").read_bytes()
        ):
            raise CampaignError("sealed model summary differs from full recomputation")

    with (campaign_directory / "summary.tsv").open(
        newline="", encoding="utf-8"
    ) as handle:
        summary_rows = list(csv.DictReader(handle, delimiter="\t"))
    if len(summary_rows) != 12:
        raise CampaignError("sealed summary does not contain twelve arms")
    for row in summary_rows:
        arm_directory = row.get("arm_directory", "")
        for field, filename in ARM_ARTIFACT_DIGEST_FIELDS:
            manifest_key = f"./{arm_directory}/{filename}"
            if row.get(field) != manifest_entries.get(manifest_key):
                raise CampaignError(
                    f"sealed summary field {field} differs for {arm_directory}"
                )
    canonical_request_sha256 = sha256_file(campaign_directory / "request.json")
    if any(
        row.get("request_sha256") != canonical_request_sha256 for row in summary_rows
    ):
        raise CampaignError("sealed summary request identity differs")

    validate_identity_check(
        campaign_directory / "identity-before.tsv",
        campaign_directory / "identity-check.tsv",
    )

    terminal_fields = (
        "state",
        "expected_arms",
        "completed_arms",
        "failed_arms",
        "target_state",
        "failure_scope",
    )
    terminal_rows = read_tsv(campaign_directory / "terminal-state.tsv", terminal_fields)
    if len(terminal_rows) != 1:
        raise CampaignError("sealed campaign requires one terminal row")
    terminal_row = terminal_rows[0]
    expected_terminal_state = (
        "completed" if recomputed_target_state == "met" else "completed-target-unmet"
    )
    if terminal_row != {
        "state": expected_terminal_state,
        "expected_arms": "12",
        "completed_arms": "12",
        "failed_arms": "0",
        "target_state": recomputed_target_state,
        "failure_scope": "none",
    }:
        raise CampaignError("sealed campaign terminal row differs")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify-sealed", action="store_true")
    parser.add_argument("--manifest-path", type=Path)
    parser.add_argument("campaign_directory", type=Path)
    parser.add_argument("summary_path", type=Path, nargs="?")
    parser.add_argument("model_summary_path", type=Path, nargs="?")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        if arguments.verify_sealed:
            if (
                arguments.summary_path is not None
                or arguments.model_summary_path is not None
            ):
                raise CampaignError("--verify-sealed accepts only a campaign directory")
            verify_sealed(arguments.campaign_directory, arguments.manifest_path)
            print("fixed64_campaign_seal=accepted")
            return 0
        if arguments.manifest_path is not None:
            raise CampaignError("--manifest-path requires --verify-sealed")
        if arguments.summary_path is None or arguments.model_summary_path is None:
            raise CampaignError("summary and model-summary output paths are required")
        target_state = summarize(
            arguments.campaign_directory,
            arguments.summary_path,
            arguments.model_summary_path,
        )
    except (CampaignError, OSError, UnicodeError) as error:
        print(f"fixed64_campaign_summary=failed reason={error}")
        return 1
    print(f"fixed64_campaign_summary=completed target_state={target_state}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
