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
        "context=32768 "
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
    expected_server_argv: Callable[[str, str, dict[str, str], str], list[str]],
    server_pid: int = 1234,
) -> None:
    document = {
        "schema": "served-decode-process-v3",
        "execution_surface": "hp14-ssh",
        "host_shortname": "hp14-dk1xxx",
        "ssh_session": "present",
        "pid": server_pid,
        "start_time_ticks": 5678,
        "executable": str(server_path),
        "executable_proc_link": str(server_path),
        "executable_device": server_path.stat().st_dev,
        "executable_inode": server_path.stat().st_ino,
        "executable_bytes": server_path.stat().st_size,
        "executable_sha256": server_sha256,
        "argv": expected_server_argv(
            str(server_path), "/proc/4321/fd/7", model, str(campaign_directory)
        ),
        "nice": 19,
        "cpus_allowed_list": "0",
        "io_class": "idle",
    }
    path.write_text(json.dumps(document) + "\n", encoding="utf-8")


def write_runtime_inputs(
    path: Path, server_path: Path, server_sha256: str, model: dict[str, str]
) -> None:
    model_path = Path(model["model_path"])
    document = {
        "schema": "served-runtime-inputs-v1",
        "model": {
            "path": str(model_path),
            "descriptor_path": "/proc/4321/fd/7",
            "device": model_path.stat().st_dev,
            "inode": model_path.stat().st_ino,
            "bytes": model_path.stat().st_size,
            "sha256": model["model_sha256"],
            "artifact_model_id": model["model_id"],
            "artifact_model_file": model["model_file"],
        },
        "executable": {
            "path": str(server_path),
            "descriptor_path": "/proc/4321/fd/6",
            "device": server_path.stat().st_dev,
            "inode": server_path.stat().st_ino,
            "bytes": server_path.stat().st_size,
            "sha256": server_sha256,
        },
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
    runtime_inputs_path: Path,
    server_path: Path,
    server_sha256: str,
    model: dict[str, str],
    campaign_directory: Path,
    expected_message: str,
) -> None:
    reseal_artifacts(
        campaign_directory / "SHA256SUMS",
        (session_status_path, server_process_path, runtime_inputs_path),
    )
    try:
        summarizer.validate_arm_server_identity(
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            str(server_path),
            server_sha256,
            str(server_path.stat().st_size),
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
        runtime_inputs_path = campaign_directory / "runtime-inputs.json"
        server_path = campaign_directory / "llama-server"
        server_path.write_bytes(b"fixed64 server identity fixture\n")
        server_sha256 = sha256_file(server_path)
        model = cast(dict[str, str], dict(summarizer.MODEL_CONTRACT["qwen35-08b"]))
        model["model_id"] = "qwen35-08b"
        model["model_path"] = str(campaign_directory / model["model_file"])
        model_path = Path(model["model_path"])
        model_path.parent.mkdir(parents=True)
        model_path.write_bytes(b"fixed64 model identity fixture\n")
        model["model_bytes"] = str(model_path.stat().st_size)
        model["model_sha256"] = sha256_file(model_path)

        write_session_status(session_status_path)
        write_runtime_inputs(runtime_inputs_path, server_path, server_sha256, model)
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
            runtime_inputs_path,
            str(server_path),
            server_sha256,
            str(server_path.stat().st_size),
            model,
            str(campaign_directory),
            "hp14-ssh",
            "hp14-dk1xxx",
            "present",
        )
        if accepted_pid != 1234:
            raise AssertionError(f"canonical server PID differs: {accepted_pid}")

        runtime_inputs = json.loads(runtime_inputs_path.read_text(encoding="utf-8"))
        runtime_inputs["model"]["descriptor_path"] = "/proc/04321/fd/7"
        runtime_inputs_path.write_text(json.dumps(runtime_inputs) + "\n", encoding="utf-8")
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "descriptor_path must be /proc/<positive-pid>/fd/7",
        )

        write_runtime_inputs(runtime_inputs_path, server_path, server_sha256, model)
        runtime_inputs = json.loads(runtime_inputs_path.read_text(encoding="utf-8"))
        runtime_inputs["executable"]["descriptor_path"] = "/proc/4322/fd/6"
        runtime_inputs_path.write_text(json.dumps(runtime_inputs) + "\n", encoding="utf-8")
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "model and executable descriptors use different PIDs",
        )

        write_runtime_inputs(runtime_inputs_path, server_path, server_sha256, model)
        server_process = json.loads(server_process_path.read_text(encoding="utf-8"))
        server_process["executable_inode"] += 1
        server_process_path.write_text(json.dumps(server_process) + "\n", encoding="utf-8")
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "executable identity differs from runtime-inputs",
        )

        write_server_process(
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            summarizer.expected_server_argv,
        )

        write_session_status(session_status_path)
        state_line, *policy_lines = session_status_path.read_text(encoding="utf-8").splitlines()
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
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "state keys differ: missing=['server_pid'] extra=[]",
        )

        # The LAN lane's five keys are admitted as a set on a loopback
        # session, a partial set refuses, and an exposed session refuses.
        def write_lan_status(exposure: str, open_flag: str, partial: bool) -> None:
            write_session_status(session_status_path)
            state_line, *policy_lines = session_status_path.read_text(encoding="utf-8").splitlines()
            lan_fields = (
                f"lan_exposure={exposure} lan_address=- lan_name=- "
                f"lan_open={open_flag} lan_boundary=lan-authenticated"
            )
            if partial:
                lan_fields = f"lan_exposure={exposure}"
            state_line = state_line.replace(
                "kernel_hazard_watchdog_pid=1237 ",
                f"kernel_hazard_watchdog_pid=1237 {lan_fields} ",
            )
            session_status_path.write_text(
                "\n".join((state_line, *policy_lines)) + "\n", encoding="utf-8"
            )

        write_lan_status("0", "0", False)
        write_server_process(
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            summarizer.expected_server_argv,
        )
        reseal_artifacts(
            campaign_directory / "SHA256SUMS",
            (session_status_path, server_process_path, runtime_inputs_path),
        )
        lan_pid = summarizer.validate_arm_server_identity(
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            str(server_path),
            server_sha256,
            str(server_path.stat().st_size),
            model,
            str(campaign_directory),
            "hp14-ssh",
            "hp14-dk1xxx",
            "present",
        )
        if lan_pid != 1234:
            raise AssertionError(f"LAN-keyed loopback session refused: {lan_pid}")

        write_lan_status("1", "0", False)
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "names an exposed session: lan_exposure=1 lan_open=0",
        )

        write_lan_status("0", "0", True)
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "carries a partial LAN key set: ['lan_exposure']",
        )

        # The launch serves a staged copy of the page from <state>/webui-served
        # and names its source on the served_page line: the staged --path is
        # admitted where that line names the canonical source, and refused
        # without the line or under a foreign source.
        canonical_argv = summarizer.expected_server_argv(
            str(server_path), "/proc/4321/fd/7", model, str(campaign_directory)
        )
        path_index = canonical_argv.index("--path") + 1
        canonical_source = canonical_argv[path_index]
        staged_directory = str(campaign_directory / "state/webui-served")

        def staged_argv(
            executable: str, descriptor: str, row: dict[str, str], directory: str
        ) -> list[str]:
            argv: list[str] = list(
                summarizer.expected_server_argv(executable, descriptor, row, directory)
            )
            argv[path_index] = staged_directory
            return argv

        def write_status_with_served_page(source: str | None) -> None:
            write_session_status(session_status_path)
            if source is not None:
                with session_status_path.open("a", encoding="utf-8") as handle:
                    handle.write(
                        f"served_page source={source} sha256={'0' * 64} "
                        "prompt_bound=- output_bound=-\n"
                    )

        write_status_with_served_page(canonical_source)
        write_server_process(
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            staged_argv,
        )
        reseal_artifacts(
            campaign_directory / "SHA256SUMS",
            (session_status_path, server_process_path, runtime_inputs_path),
        )
        staged_pid = summarizer.validate_arm_server_identity(
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            str(server_path),
            server_sha256,
            str(server_path.stat().st_size),
            model,
            str(campaign_directory),
            "hp14-ssh",
            "hp14-dk1xxx",
            "present",
        )
        if staged_pid != 1234:
            raise AssertionError(f"staged page path refused: {staged_pid}")

        write_status_with_served_page(None)
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            f"argv differs from the canonical launch at index {path_index}",
        )

        write_status_with_served_page("/elsewhere/webui")
        expect_resealed_refusal(
            summarizer,
            session_status_path,
            server_process_path,
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            f"argv differs from the canonical launch at index {path_index}",
        )

        write_session_status(session_status_path)
        write_server_process(
            server_process_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            summarizer.expected_server_argv,
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
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "pid differs from canonical server_pid",
        )

        write_session_status(session_status_path)
        state_line, *policy_lines = session_status_path.read_text(encoding="utf-8").splitlines()
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
            runtime_inputs_path,
            server_path,
            server_sha256,
            model,
            campaign_directory,
            "state keys differ: missing=[] extra=['unbound']",
        )
    print("fixed64_server_identity=accepted cases=7")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
