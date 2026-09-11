"""`qwen-apu serve` and `stop`: the policy's argv under the supervisor.

The capacity policy builds the llama-server argv the way qwen-capacity-policy.sh
does, the profile builds the environment the way radv-low-priority-env.sh
does, and the supervisor owns the process. This module joins the three into
one `SupervisionPlan`, writes it as JSON under `state/` so a detached
supervisor reads the same plan the foreground form ran, and starts either.
"""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

from qwen_apu.config import models as registry
from qwen_apu.runtime import deployment, environment, policy, supervisor
from qwen_apu.runtime.paths import RuntimePaths

DEFAULT_MODEL = "qwen38-2b-distill"
DEFAULT_PROFILE = "low-async"
DEFAULT_PORT = 8080
READINESS_DEADLINE_SECONDS = 180.0
INFERENCE_CPUS = frozenset({0})
INFERENCE_NICENESS = 19


@dataclass(frozen=True)
class ServeRequest:
    model_id: str = DEFAULT_MODEL
    profile: str = DEFAULT_PROFILE
    port: int = DEFAULT_PORT
    context: int | None = None
    llama_server: Path | None = None
    model_root: Path | None = None
    daemon: bool = False
    readiness_deadline_s: float = READINESS_DEADLINE_SECONDS
    cpu_affinity: frozenset[int] | None = INFERENCE_CPUS
    niceness: int | None = INFERENCE_NICENESS
    require_radv_icd: bool = True


def build_plan(paths: RuntimePaths, request: ServeRequest) -> supervisor.SupervisionPlan:
    row = registry.model_by_id(request.model_id)
    model_root = request.model_root or paths["qwen_home_models"]
    model_path = model_root / row.model_file
    # The launch chain serves the activated deployment: its server carries the
    # artifact manifest the policy reads checkpoint semantics from, and its
    # ledger carries the checkpoint count. An explicit server path is a
    # research arm and takes the launch defaults, as qwen-launch.sh does when
    # no deployment-current exists.
    ledger = ""
    deployment_name = "-"
    if request.llama_server is None:
        active = deployment.resolve_active(paths["qwen_home_deployments"])
        server = active.server
        ledger = str(active.ledger)
        deployment_name = active.name
    else:
        server = request.llama_server
    context = request.context if request.context is not None else row.context_default
    launch = policy.build_launch_plan(
        server,
        model_path,
        context,
        request.port,
        script_directory=paths.tree / "remote",
        qwen_model_root=str(model_root),
        qwen_ctx_checkpoint_ledger=ledger,
        qwen_webui_state_directory=str(paths["qwen_home_state"]),
    )
    env = environment.profile_environment(
        request.profile, dict(os.environ), check_icd=request.require_radv_icd
    )
    for name in launch.environment_removals:
        env.pop(name, None)
    env.update(launch.environment_additions)
    return supervisor.SupervisionPlan(
        argv=launch.argv,
        env=env,
        cwd=paths.root,
        port=launch.port,
        health_path="/health",
        model_id=launch.model_id or request.model_id,
        deployment=deployment_name,
        profile=request.profile,
        readiness_deadline_s=request.readiness_deadline_s,
        log_directory=paths["qwen_home_logs"],
        cpu_affinity=request.cpu_affinity,
        niceness=request.niceness,
    )


def plan_to_json(plan: supervisor.SupervisionPlan) -> dict[str, object]:
    return {
        "argv": list(plan.argv),
        "env": dict(plan.env),
        "cwd": str(plan.cwd),
        "port": plan.port,
        "health_path": plan.health_path,
        "model_id": plan.model_id,
        "deployment": plan.deployment,
        "profile": plan.profile,
        "readiness_deadline_s": plan.readiness_deadline_s,
        "log_directory": str(plan.log_directory) if plan.log_directory else None,
        "cpu_affinity": sorted(plan.cpu_affinity) if plan.cpu_affinity else None,
        "niceness": plan.niceness,
    }


def serve(paths: RuntimePaths, request: ServeRequest) -> int:
    plan = build_plan(paths, request)
    plan_path = paths["qwen_home_state"] / "launch-plan.json"
    plan_path.parent.mkdir(parents=True, exist_ok=True)
    plan_path.write_text(json.dumps(plan_to_json(plan), indent=2) + "\n", encoding="utf-8")
    argv = ["--plan", str(plan_path)]
    if request.daemon:
        argv.append("--daemon")
    return supervisor.main(argv)


def stop(paths: RuntimePaths) -> int:
    outcome = supervisor.stop(paths)
    print(f"stop={outcome}")
    return 0 if outcome in ("stopped", "absent") else 1


def status(paths: RuntimePaths) -> int:
    record = supervisor.status(paths)
    if record is None:
        print("runtime=absent")
        return 0
    for key, value in record.to_json().items():
        sys.stdout.write(f"{key}={value}\n")
    return 0
