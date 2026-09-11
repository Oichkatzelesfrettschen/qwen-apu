"""The `qwen-apu` console entry point.

Every documented lifecycle operation has a subcommand here. A subcommand the
Python control plane already owns runs in-process; one still owned by a shell
script exits 2 and names that script, so the CLI states the migration
boundary rather than hiding it behind a shell call.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections.abc import Sequence
from dataclasses import asdict

from qwen_apu import __version__
from qwen_apu.config import models as registry
from qwen_apu.install import doctor
from qwen_apu.runtime.paths import RuntimePaths, RuntimeRootError, render_paths

UNPORTED: dict[str, str] = {
    "install": "remote/runtime-root.sh init and the Makefile install targets",
    "build": "remote/build-llama-vulkan.sh",
    "models install": "remote/download-*.sh",
    "deployment build": "remote/build-deployment-bundle.sh",
    "deployment activate": "remote/activate-deployment-bundle.sh",
    "deployment rollback": "remote/activate-deployment-bundle.sh rollback",
    "serve": "remote/qwen-launch.sh",
    "stop": "remote/qwen-teardown.sh",
    "verify": "remote/runtime-root.sh verify-layout, verify-components, verify-live",
    "export": "no shell predecessor; arrives with conversation persistence",
    "import": "no shell predecessor; arrives with conversation persistence",
}


def unported(name: str) -> int:
    print(f"qwen-apu {name}: still owned by {UNPORTED[name]}", file=sys.stderr)
    return 2


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="qwen-apu")
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("bootstrap", help="lay out the runtime root and write its marker")
    sub.add_parser("install", help="install native binaries and models")
    sub.add_parser("build", help="build native engines from the pinned recipe")
    models = sub.add_parser("models", help="model registry operations")
    models_sub = models.add_subparsers(dest="models_command", required=True)
    models_list = models_sub.add_parser("list", help="every registry row, validated whole")
    models_list.add_argument("--json", action="store_true")
    models_list.add_argument("--tier", default=None)
    models_sub.add_parser("install", help="fetch model groups").add_argument("groups", nargs="*")
    models_verify = models_sub.add_parser("verify", help="verify registry ledgers cross-consistent")
    models_verify.add_argument(
        "--artifacts", action="store_true", help="also digest installed model files"
    )
    deployment = sub.add_parser("deployment", help="deployment lifecycle")
    deployment_sub = deployment.add_subparsers(dest="deployment_command", required=True)
    for name in ("build", "activate", "rollback"):
        deployment_sub.add_parser(name)
    sub.add_parser("serve", help="run the supervisor")
    sub.add_parser("stop", help="stop the supervisor")
    status = sub.add_parser("status", help="runtime root binding and declared paths")
    status.add_argument("--json", action="store_true")
    sub.add_parser("doctor", help="prerequisites a user-space installer can only detect")
    sub.add_parser("verify", help="layout, components, and live state")
    sub.add_parser("export", help="export conversations")
    sub.add_parser("import", help="import conversations")
    paths = sub.add_parser("paths", help="every declared runtime-root name and value")
    paths.add_argument(
        "--shell-only",
        action="store_true",
        help="the names remote/qwen-home.sh also declares, in its order",
    )
    patches = sub.add_parser("patches", help="the ordered llama.cpp patch series")
    patches.add_argument("--stage", choices=("production", "candidate"), default=None)
    return parser


def cmd_bootstrap(paths: RuntimePaths) -> int:
    outcome = paths.lay_out(rebind=os.environ.get("QWEN_RUNTIME_ROOT_REBIND"))
    print(f"runtime_root={paths.root} schema={paths.marker_schema()} binding={outcome}")
    return 0


def cmd_status(paths: RuntimePaths, as_json: bool) -> int:
    record = {
        "tree_root": str(paths.tree),
        "runtime_root": str(paths.root),
        "binding": paths.binding_state(),
        "marker_schema": paths.marker_schema(),
        "venv_cli": str(paths["qwen_home_venv_cli"]),
        "venv_present": paths["qwen_home_venv_python"].exists(),
    }
    if as_json:
        print(json.dumps(record, indent=2))
    else:
        for key, value in record.items():
            print(f"{key}={value}")
    return 0


def cmd_doctor(paths: RuntimePaths) -> int:
    checks = doctor.run(paths)
    sys.stdout.write(doctor.render(checks))
    return 0 if all(check.ok for check in checks) else 1


def cmd_models_list(as_json: bool, tier: str | None) -> int:
    rows = list(registry.load_models())
    if tier:
        rows = [row for row in rows if row.tier == tier]
    if as_json:
        print(json.dumps([asdict(row) for row in rows], indent=2, default=str))
        return 0
    for row in rows:
        print(f"{row.id}\t{row.tier}\t{row.role}\t{row.model_file}")
    return 0


def cmd_models_verify(paths: RuntimePaths, artifacts: bool) -> int:
    registry.load_models()
    registry.load_draft_pairs()
    registry.load_ctx_checkpoints()
    registry.load_quarantine()
    registry.load_patch_series()
    registry.load_model_artifacts()
    print("registry=consistent")
    if artifacts:
        print("artifact digests: still owned by remote/verify-models.sh", file=sys.stderr)
        return 2
    return 0


def cmd_patches(stage: str | None) -> int:
    for member in registry.load_patch_series():
        if stage is None or member.stage == stage:
            print(f"{member.stage}\t{member.patch}")
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        paths = RuntimePaths.resolve()
        if args.command == "bootstrap":
            return cmd_bootstrap(paths)
        if args.command == "status":
            return cmd_status(paths, args.json)
        if args.command == "doctor":
            return cmd_doctor(paths)
        if args.command == "paths":
            sys.stdout.write(render_paths(paths, shell_only=args.shell_only))
            return 0
        if args.command == "patches":
            return cmd_patches(args.stage)
        if args.command == "models":
            if args.models_command == "list":
                return cmd_models_list(args.json, args.tier)
            if args.models_command == "verify":
                return cmd_models_verify(paths, args.artifacts)
            return unported("models install")
        if args.command == "deployment":
            return unported(f"deployment {args.deployment_command}")
        return unported(args.command)
    except RuntimeRootError as error:
        print(f"qwen-apu: {error}", file=sys.stderr)
        return 2
    except ValueError as error:
        print(f"qwen-apu: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
