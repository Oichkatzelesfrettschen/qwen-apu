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
import time
from dataclasses import dataclass
from pathlib import Path

from qwen_apu.config import models as registry
from qwen_apu.runtime import deployment, environment, policy, preflight, supervisor
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.state import RuntimeRecord

DEFAULT_MODEL = "qwen38-2b-distill"
DEFAULT_PROFILE = "low-async"
DEFAULT_PORT = 8080
# `--models-max` is 1 rather than llama.cpp's 4: the 4B alone peaks at 2029 MiB
# of a 2048 MiB VRAM carve-out with 2700 MiB more in GTT, so a second resident
# model competes for a pool one already saturates.
DEFAULT_ROUTER_MAX = 1
ROUTER_ALIAS = "qwen-apu"
READINESS_DEADLINE_SECONDS = 180.0
# Router mode leaves depth to each preset section, so the positional depth
# the policy validates is a placeholder the argv never carries.
DEFAULT_ROUTER_CONTEXT = 4096
OWNERSHIP_DEADLINE_SECONDS = 60.0
OWNERSHIP_POLL_SECONDS = 0.1
INFERENCE_CPUS = frozenset({0})
INFERENCE_NICENESS = 19


@dataclass(frozen=True)
class ServeRequest:
    # Router mode serves every section of the active deployment's preset behind
    # one listener; the single-model form serves one registry row and is the
    # research arm a measurement takes.
    router: bool = False
    router_max: int = DEFAULT_ROUTER_MAX
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
    ownership_deadline_s: float = OWNERSHIP_DEADLINE_SECONDS


def _router_inputs(
    paths: RuntimePaths, request: ServeRequest, active: deployment.ActiveDeployment | None = None
) -> _RouterInputs:
    """Everything router mode reads out of the activated bundle, resolved once.

    The bundle is the authority for all five: the preset names the sections,
    the checkpoint ledger states each section's checkpoint count, `llama-server`
    is the identity the build guard measures, `q4k-policy.tsv` is the
    formulation authority the preset was generated against, and the web profile
    ledger reaches the policy through the preset's own markers rather than
    through an argument. An explicit `--llama-server` is refused here, because a
    server outside the bundle carries no artifact manifest the preset's
    checkpoint semantics were validated against.
    """
    if request.llama_server is not None:
        raise ValueError(
            "router mode serves the activated deployment's own server, so "
            "--llama-server names a research arm that takes --model instead"
        )
    if active is None:
        active = preflight.verify_deployment(paths["qwen_home_deployments"])
    if active.router_presets is None:
        raise ValueError(
            f"deployment {active.name} carries no router-presets.ini, so it serves "
            "one model at a time through --model"
        )
    # qwen-launch.sh binds the formulation authority to the preset rather than
    # to the server: a bundle answers for the preset it carries, and a bundle
    # generated before the policy file existed reads `legacy`.
    policy_file = active.directory / "q4k-policy.tsv"
    q4k_policy = str(policy_file) if policy_file.is_file() else "legacy"
    subject = policy.router_preflight_subject(active.router_presets)
    sections = tuple(section.name for section in policy.preset_sections(active.router_presets))
    return _RouterInputs(
        active=active,
        presets=active.router_presets,
        q4k_policy=q4k_policy,
        subject=subject,
        sections=sections,
    )


@dataclass(frozen=True)
class _RouterInputs:
    active: deployment.ActiveDeployment
    presets: Path
    q4k_policy: str
    subject: policy.RouterSubject
    sections: tuple[str, ...]


def build_plan(
    paths: RuntimePaths,
    request: ServeRequest,
    *,
    active: deployment.ActiveDeployment | None = None,
) -> supervisor.SupervisionPlan:
    model_root = request.model_root or paths["qwen_home_models"]
    script_directory = paths.tree / "remote"
    state_directory = str(paths["qwen_home_state"])
    if request.router:
        router = _router_inputs(paths, request, active)
        # The policy checks the positional model path and depth in router mode
        # as well, and qwen-launch.sh supplies the largest preset subject for
        # both: a preflight run against a smaller checkpoint reports headroom
        # for a load that never happens.
        launch = policy.build_launch_plan(
            router.active.server,
            router.subject.model,
            request.context if request.context is not None else DEFAULT_ROUTER_CONTEXT,
            request.port,
            script_directory=script_directory,
            qwen_router="1",
            qwen_router_presets=str(router.presets),
            qwen_router_max=str(request.router_max),
            qwen_bundle_q4k_policy=router.q4k_policy,
            qwen_model_root=str(model_root),
            qwen_ctx_checkpoint_ledger=str(router.active.ledger),
            qwen_webui_state_directory=state_directory,
        )
        return _plan_from_launch(
            paths,
            request,
            launch,
            model_id="router",
            deployment_name=router.active.name,
            expected_models=router.sections,
        )

    row = registry.model_by_id(request.model_id)
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
        script_directory=script_directory,
        qwen_model_root=str(model_root),
        qwen_ctx_checkpoint_ledger=ledger,
        qwen_webui_state_directory=state_directory,
    )
    return _plan_from_launch(
        paths,
        request,
        launch,
        model_id=launch.model_id or request.model_id,
        deployment_name=deployment_name,
        # The single-model argv carries `--alias qwen-apu`, so that alias
        # rather than the registry id is the name the server reports back.
        expected_models=(ROUTER_ALIAS,),
    )


def _plan_from_launch(
    paths: RuntimePaths,
    request: ServeRequest,
    launch: policy.LaunchPlan,
    *,
    model_id: str,
    deployment_name: str,
    expected_models: tuple[str, ...],
) -> supervisor.SupervisionPlan:
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
        model_id=model_id,
        deployment=deployment_name,
        profile=request.profile,
        readiness_deadline_s=request.readiness_deadline_s,
        mode=launch.mode,
        expected_models=expected_models,
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
        "mode": plan.mode,
        "expected_models": list(plan.expected_models),
        "models_path": plan.models_path,
        "log_directory": str(plan.log_directory) if plan.log_directory else None,
        "cpu_affinity": sorted(plan.cpu_affinity) if plan.cpu_affinity else None,
        "niceness": plan.niceness,
    }


def _await_ownership(paths: RuntimePaths, deadline_s: float) -> int:
    """Watch the record until the detached supervisor owns a child, or fails.

    `--daemon` returns as soon as the relaunch is a session leader, which is
    before the supervisor has taken its locks, spawned the server, or published
    anything. A caller that returns there reports a launch whose first refusal
    -- a held workload lock, an unreadable deployment, a child that left at exec
    -- lands in a log file nobody reads. The wait ends at the first record
    naming an owned child, which is exactly the claim `--daemon` makes, and the
    model load continues behind it.
    """
    record = RuntimeRecord(path=paths["qwen_home_runtime_state"])
    deadline = time.monotonic() + deadline_s
    seen: list[str] = []
    while time.monotonic() < deadline:
        current = record.read()
        if current is not None and (not seen or seen[-1] != current.state):
            seen.append(current.state)
            print(f"state={current.state}")
        if current is not None and current.is_terminal:
            print(f"primary_failure={current.primary_failure or '-'}")
            return 1
        if current is not None and current.server_pid and current.state != "starting":
            print(f"server_pid={current.server_pid} start_time={current.server_start_time}")
            return 0
        time.sleep(OWNERSHIP_POLL_SECONDS)
    print(
        f"the detached supervisor published no owned child within {deadline_s:.1f} s",
        file=sys.stderr,
    )
    return 1


def run_preflights(paths: RuntimePaths, request: ServeRequest) -> tuple[str, ...]:
    """Decide every precondition a launch would otherwise assume, writing nothing.

    Three of the four windows the shadow pass ended on are decidable here: a
    checkpoint the runtime root does not resolve, an absent signing key, and a
    key whose bytes the approvals reader refuses. Each answers before a process
    exists, so a refusal leaves the tree exactly as it found it. The fourth --
    prompts sent into a server that had not loaded -- is the readiness state the
    supervisor publishes instead.

    The signing key is checked where the file exists rather than required: the
    ordinary `serve` path signs no grant, and the gateway assembly is where the
    key becomes a precondition. A key that exists and fails a rule refuses here
    all the same, because the web lane would meet that refusal after the device
    is already loaded.
    """
    report: list[str] = []
    if request.llama_server is None:
        active = preflight.verify_deployment(paths["qwen_home_deployments"])
        report.append(f"deployment_preflight name={active.name} directory={active.directory}")
    if not request.router:
        resolved = preflight.resolve_model(paths, request.model_id, model_root=request.model_root)
        report.append(resolved.render())
    key_path = paths["qwen_home_web_token_key"]
    if key_path.exists():
        report.append(preflight.verify_signing_key(key_path).render())
    else:
        report.append(f"signing_key_preflight path={key_path} state=absent")
    return tuple(report)


def serve(paths: RuntimePaths, request: ServeRequest) -> int:
    for line in run_preflights(paths, request):
        print(line)
    plan = build_plan(paths, request)
    plan_path = paths["qwen_home_state"] / "launch-plan.json"
    plan_path.parent.mkdir(parents=True, exist_ok=True)
    plan_path.write_text(json.dumps(plan_to_json(plan), indent=2) + "\n", encoding="utf-8")
    argv = ["--plan", str(plan_path)]
    if not request.daemon:
        # The foreground form is the supervise loop itself, so it reaches
        # `ready` and stays there until the service ends.
        return supervisor.main(argv)
    code = supervisor.main([*argv, "--daemon"])
    if code != 0:
        return code
    return _await_ownership(paths, request.ownership_deadline_s)


def stop(paths: RuntimePaths) -> int:
    """Exit 0 when the record ends terminal and stopped, whatever route took it there."""
    outcome = supervisor.stop(paths)
    print(f"stop={outcome}")
    record = supervisor.status(paths)
    if record is None:
        return 0
    print(f"state={record.state}")
    return 0 if record.state == "stopped" else 1


def status(paths: RuntimePaths) -> int:
    record = supervisor.status(paths)
    if record is None:
        print("runtime=absent")
        return 0
    for key, value in record.to_json().items():
        sys.stdout.write(f"{key}={value}\n")
    return 0
