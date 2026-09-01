"""Exercise fixed-64 arm server-identity reconciliation."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
from pathlib import Path
from types import ModuleType
from typing import Any, Callable, cast


def load_summarizer(script_directory: Path) -> ModuleType:
    summarizer_path = script_directory / "summarize-fixed64-served-campaign.py"
    specification = importlib.util.spec_from_file_location(
        "summarize_fixed64_served_campaign", summarizer_path
    )
    if specification is None or specification.loader is None:
        raise RuntimeError(f"cannot load summarizer: {summarizer_path}")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_session_status(path: Path, server_pid: int = 1234) -> None:
    path.write_text(
        "state=running "
        f"server_pid={server_pid} "
        "monitor_pid=1235 "
        "latency_watchdog_pid=1236 "
        "kernel_hazard_watchdog_pid=1237 "
        "profile=low-async "
        "host=127.0.0.1 "
        "port=8080 "
        "context=8192 "
        "latency_mode=observe "
        "utc=2026-09-01T00:00:00Z\n"
        "speculation spec_type=off draft_backend_sampling=0 backend_sampling=0\n"
        "cache cache_type_k=q8_0 cache_type_v=q4_0 flash_attention=on\n"
        "router enabled=0\n",
        encoding="utf-8",
    )


def write_server_process(
    path: Path,
    server_path: Path,
    server_sha256: str,
    model: dict[str, str],
    campaign_directory: Path,
    expected_server_argv: Callable[[str, dict[str, str], str], list[str]],
    server_pid: int = 1234,
) -> None:
    document = {
        "schema": "served-decode-process-v2",
        "execution_surface": "hp14-ssh",
        "host_shortname": "hp14-dk1xxx",
        "ssh_session": "present",
        "pid": server_pid,
        "start_time_ticks": 5678,
        "executable": str(server_path),
        "executable_sha256": server_sha256,
        "argv": expected_server_argv(str(server_path), model, str(campaign_directory)),
        "nice": 19,
        "cpus_allowed_list": "0",
        "io_class": "idle",
    }
    path.write_text(json.dumps(document) + "\n", encoding="utf-8")


def reseal_artifacts(manifest_path: Path, artifacts: tuple[Path, ...]) -> None:
    manifest_path.write_text(
        "".join(f"{sha256_file(path)}  {path.name}\n" for path in artifacts),
        encoding="ascii",
    )
    for line in manifest_path.read_text(encoding="ascii").splitlines():
        expected_digest, artifact_name = line.split("  ", maxsplit=1)
        if sha256_file(manifest_path.parent / artifact_name) != expected_digest:
            raise AssertionError(f"resealed artifact differs: {artifact_name}")


def expect_resealed_refusal(
    summarizer: Any,
    session_status_path: Path,
    server_process_path: Path,
    server_path: Path,
    server_sha256: str,
    model: dict[str, str],
    campaign_directory: Path,
    expected_message: str,
) -> None:
    reseal_artifacts(
        campaign_directory / "SHA256SUMS",
        (session_status_path, server_process_path),
    )
    try:
        summarizer.validate_arm_server_identity(
            session_status_path,
            server_process_path,
            str(server_path),
            server_sha256,
            model,
            str(campaign_directory),
            "hp14-ssh",
            "hp14-dk1xxx",
            "present",
        )
    except summarizer.CampaignError as error:
        if expected_message not in str(error):
            raise AssertionError(
                f"identity refusal differs: {error}; expected {expected_message!r}"
            ) from error
    else:
        raise AssertionError(f"resealed mutation survived: {expected_message}")


def main() -> int:
    script_directory = Path(__file__).resolve().parent
    summarizer = cast(Any, load_summarizer(script_directory))
    with tempfile.TemporaryDirectory(prefix="fixed64-server-identity-") as temporary:
        campaign_directory = Path(temporary)
        session_status_path = campaign_directory / "session.status"
        server_process_path = campaign_directory / "server-process.json"
        server_path = campaign_directory / "llama-server"
        server_path.write_bytes(b"fixed64 server identity fixture\n")
        server_sha256 = sha256_file(server_path)
        model = cast(dict[str, str], dict(summarizer.MODEL_CONTRACT["qwen35-08b"]))
        model["model_path"] = str(campaign_directory / model["model_file"])

        write_session_status(session_status_path)
        write_server_process(
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            summarizer.expected_server_argv,
        )
        accepted_pid = summarizer.validate_arm_server_identity(
            session_status_path,
            server_process_path,
            str(server_path),
            server_sha256,
            model,
            str(campaign_directory),
            "hp14-ssh",
            "hp14-dk1xxx",
            "present",
        )
        if accepted_pid != 1234:
            raise AssertionError(f"canonical server PID differs: {accepted_pid}")

        write_session_status(session_status_path)
        state_line, *policy_lines = session_status_path.read_text(
            encoding="utf-8"
        ).splitlines()
        state_line = " ".join(
            field for field in state_line.split() if not field.startswith("server_pid=")
        )
        session_status_path.write_text(
            "\n".join((state_line, *policy_lines)) + "\n", encoding="utf-8"
        )
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "state keys differ: missing=['server_pid'] extra=[]",
        )

        write_session_status(session_status_path)
        write_server_process(
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            summarizer.expected_server_argv,
            server_pid=4321,
        )
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "pid differs from canonical server_pid",
        )

        write_session_status(session_status_path)
        state_line, *policy_lines = session_status_path.read_text(
            encoding="utf-8"
        ).splitlines()
        session_status_path.write_text(
            "\n".join((f"{state_line} unbound=value", *policy_lines)) + "\n",
            encoding="utf-8",
        )
        write_server_process(
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            summarizer.expected_server_argv,
        )
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "state keys differ: missing=[] extra=['unbound']",
        )
    print("fixed64_server_identity=accepted cases=4")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
