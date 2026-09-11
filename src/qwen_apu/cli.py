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
import subprocess
import sys
from collections.abc import Sequence
from dataclasses import asdict
from pathlib import Path

from qwen_apu import __version__
from qwen_apu.config import models as registry
from qwen_apu.config.native import load_native_builds
from qwen_apu.install import build, doctor, native, source
from qwen_apu.install import models as model_installer
from qwen_apu.runtime import (
    acceptance,
    appliance,
    application_deployment,
    canary,
    deployment,
    deployment_write,
)
from qwen_apu.runtime import serve as serving
from qwen_apu.runtime.paths import RuntimePaths, RuntimeRootError, render_paths
from qwen_apu.web import assemble as gateway_assembly
from qwen_apu.web import browser_import
from qwen_apu.web.history import ConversationStore, HistoryError

UNPORTED: dict[str, str] = {
    "verify": "remote/runtime-root.sh verify-layout, verify-components, verify-live",
}


def unported(name: str) -> int:
    print(f"qwen-apu {name}: still owned by {UNPORTED[name]}", file=sys.stderr)
    return 2


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="qwen-apu")
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("bootstrap", help="lay out the runtime root and write its marker")
    install = sub.add_parser("install", help="install a verified native bundle")
    install.add_argument("--bundle", type=Path, required=True, help="native bundle tar")
    install.add_argument("--sha256", default=None, help="expected bundle digest")
    build = sub.add_parser("build", help="build native engines from the pinned recipe")
    build.add_argument("--recipe", default="llama")
    build.add_argument(
        "--source-archive",
        default=None,
        help="pinned llama.cpp archive path or URL; a git clone at the "
        "upstream path is accepted at the pinned commit",
    )
    build.add_argument("--jobs", type=int, default=2)
    native_parser = sub.add_parser("native", help="native bundle store")
    native_sub = native_parser.add_subparsers(dest="native_command", required=True)
    native_sub.add_parser("list", help="installed bundles by digest")
    stage = native_sub.add_parser("stage", help="write a bundle from finished binaries")
    stage.add_argument("--recipe", default="llama")
    stage.add_argument("--binary", action="append", default=[], metavar="NAME=PATH")
    stage.add_argument("--output", type=Path, required=True)
    stage.add_argument("--source-commit", required=True)
    stage.add_argument("--compiler-identity", required=True)
    stage.add_argument("--patch", action="append", default=[], metavar="NAME=SHA256")
    models = sub.add_parser("models", help="model registry operations")
    models_sub = models.add_subparsers(dest="models_command", required=True)
    models_list = models_sub.add_parser("list", help="every registry row, validated whole")
    models_list.add_argument("--json", action="store_true")
    models_list.add_argument("--tier", default=None)
    models_install = models_sub.add_parser("install", help="fetch model groups")
    models_install.add_argument("groups", nargs="+")
    models_install.add_argument("--dry-run", action="store_true")
    models_verify = models_sub.add_parser("verify", help="verify registry ledgers cross-consistent")
    models_verify.add_argument(
        "--artifacts", action="store_true", help="also digest installed files of the named groups"
    )
    models_verify.add_argument("groups", nargs="*")
    deployment = sub.add_parser("deployment", help="deployment lifecycle")
    deployment_sub = deployment.add_subparsers(dest="deployment_command", required=True)
    deployment_build = deployment_sub.add_parser(
        "build", help="bind release artifacts into a bundle"
    )
    deployment_build.add_argument("name")
    deployment_build.add_argument("server", type=Path)
    deployment_build.add_argument("artifact_manifest", type=Path)
    deployment_build.add_argument("ctx_ledger", type=Path)
    deployment_build.add_argument("--router-presets", type=Path, default=None)
    deployment_build.add_argument("--web-presets", type=Path, default=None)
    deployment_build.add_argument("--q4k-policy", default=None)
    deployment_build.add_argument("--root", type=Path, default=None)
    deployment_activate = deployment_sub.add_parser("activate", help="swap deployment-current")
    deployment_activate.add_argument("name")
    deployment_activate.add_argument("--root", type=Path, default=None)
    deployment_rollback = deployment_sub.add_parser("rollback", help="promote previous")
    deployment_rollback.add_argument("--root", type=Path, default=None)
    deployment_sub.add_parser("show", help="resolve the active bundle").add_argument(
        "--root", type=Path, default=None
    )
    build_application = deployment_sub.add_parser(
        "build-application",
        help="bind the page, the package, the lock, and every ledger into one immutable unit",
    )
    build_application.add_argument("name")
    build_application.add_argument("--root", type=Path, default=None)
    verify_application = deployment_sub.add_parser(
        "verify-application", help="re-digest every payload member and resolve every reference"
    )
    verify_application.add_argument("name")
    verify_application.add_argument("--root", type=Path, default=None)
    list_applications = deployment_sub.add_parser(
        "list-applications", help="every application deployment the root holds"
    )
    list_applications.add_argument("--root", type=Path, default=None)
    serve = sub.add_parser("serve", help="run one llama-server under the supervisor")
    serve.add_argument(
        "--router",
        action="store_true",
        help="serve every section of the activated deployment's router preset",
    )
    serve.add_argument("--router-max", type=int, default=serving.DEFAULT_ROUTER_MAX)
    serve.add_argument("--model", default=serving.DEFAULT_MODEL)
    serve.add_argument("--profile", default=serving.DEFAULT_PROFILE)
    serve.add_argument("--port", type=int, default=serving.DEFAULT_PORT)
    serve.add_argument("--context", type=int, default=None)
    serve.add_argument("--llama-server", type=Path, default=None)
    serve.add_argument("--model-root", type=Path, default=None)
    serve.add_argument("--daemon", action="store_true")
    serve.add_argument(
        "--no-affinity", action="store_true", help="leave the server unpinned and at nice 0"
    )
    serve.add_argument(
        "--skip-radv-icd-check",
        action="store_true",
        help="research arm on a host without RADV; the appliance keeps the check",
    )
    sub.add_parser("stop", help="stop the supervised server and prove absence")
    appliance = sub.add_parser(
        "appliance", help="the whole application: router, gateway, and lane children"
    )
    appliance_sub = appliance.add_subparsers(dest="appliance_command", required=True)
    appliance_serve = appliance_sub.add_parser("serve", help="start every owned process")
    appliance_serve.add_argument("--router", action="store_true")
    appliance_serve.add_argument("--model", default=serving.DEFAULT_MODEL)
    appliance_serve.add_argument("--profile", default=serving.DEFAULT_PROFILE)
    appliance_serve.add_argument("--port", type=int, default=serving.DEFAULT_PORT)
    appliance_serve.add_argument(
        "--gateway-port", type=int, default=gateway_assembly.DEFAULT_GATEWAY_PORT
    )
    appliance_serve.add_argument("--bind-host", default="127.0.0.1")
    appliance_serve.add_argument("--web-profile", default=gateway_assembly.DEFAULT_WEB_PROFILE)
    appliance_serve.add_argument("--image-profile", default="")
    appliance_serve.add_argument("--static", type=Path, default=None)
    appliance_serve.add_argument("--file-root", type=Path, action="append", default=[])
    appliance_serve.add_argument(
        "--image-service",
        action="append",
        default=[],
        metavar="ARG",
        help="one argv word of the image worker; repeat to build the command",
    )
    appliance_serve.add_argument(
        "--searxng",
        action="append",
        default=[],
        metavar="ARG",
        help="one argv word of the search instance; repeat to build the command",
    )
    appliance_sub.add_parser("stop", help="signal every identity the record names")
    appliance_sub.add_parser("status", help="the published application record")
    acceptance_parser = sub.add_parser(
        "acceptance", help="the launch acceptance driver over a running gateway"
    )
    acceptance_sub = acceptance_parser.add_subparsers(dest="acceptance_command", required=True)
    acceptance_run = acceptance_sub.add_parser("run", help="run every check and write the report")
    acceptance_run.add_argument(
        "--base", required=True, help="the gateway origin, as http://host:port"
    )
    acceptance_run.add_argument("--pairing-code", required=True)
    acceptance_run.add_argument(
        "--report", type=Path, required=True, help="JSON report path under the runtime root"
    )
    acceptance_run.add_argument(
        "--model",
        action="append",
        default=[],
        metavar="ID",
        help="one text model to take a turn on; repeat to name the class ladder",
    )
    acceptance_run.add_argument(
        "--vision-model",
        action="append",
        default=[],
        metavar="ID",
        help="one admitted vision profile",
    )
    acceptance_run.add_argument(
        "--restart-command",
        action="append",
        default=[],
        metavar="ARG",
        help="one argv word of the gateway restart; repeat to build the command",
    )
    acceptance_run.add_argument(
        "--stop-command",
        action="append",
        default=[],
        metavar="ARG",
        help="one argv word of the stop the teardown phase runs; repeat to build the command",
    )
    acceptance_run.add_argument("--lease-path", type=Path, default=None)
    acceptance_run.add_argument("--appliance-state", type=Path, default=None)
    acceptance_run.add_argument("--router-presets", type=Path, default=None)
    acceptance_run.add_argument("--document-fixtures", type=Path, default=None)
    acceptance_run.add_argument("--file-search-root", type=Path, default=None)
    canary_parser = sub.add_parser(
        "canary", help="the legacy and Python parity canary over one declared window"
    )
    canary_sub = canary_parser.add_subparsers(dest="canary_command", required=True)
    canary_run = canary_sub.add_parser("run", help="alternate both arms and write the verdict")
    canary_run.add_argument(
        "--report", type=Path, required=True, help="JSON report path under the runtime root"
    )
    canary_run.add_argument("--repeats", type=int, default=canary.DEFAULT_REPEATS)
    canary_run.add_argument("--ratio", type=float, default=canary.DEFAULT_RATIO)
    canary_run.add_argument("--base", default=canary.DEFAULT_BASE)
    canary_run.add_argument("--prompt", default=canary.DEFAULT_PROMPT)
    canary_run.add_argument("--tokens", type=int, default=canary.DEFAULT_TOKENS)
    canary_run.add_argument("--model", default="")
    canary_run.add_argument(
        "--readiness-deadline-s",
        type=float,
        default=canary.DEFAULT_READINESS_DEADLINE_SECONDS,
        help="how long each arm may take to report /health ok before it refuses",
    )
    for name, help_text in (
        ("legacy-start", "one argv word of the legacy launch"),
        ("legacy-stop", "one argv word of the legacy teardown"),
        ("python-start", "one argv word of the Python launch"),
        ("python-stop", "one argv word of the Python teardown"),
    ):
        canary_run.add_argument(
            f"--{name}", action="append", default=[], metavar="ARG", help=f"{help_text}; repeat"
        )
    canary_run.add_argument(
        "--sysfs",
        action="append",
        default=[],
        metavar="NAME=PATH",
        help="one sysfs file the configuration snapshot reads; repeat",
    )
    gateway = sub.add_parser("gateway", help="serve the one-origin browser gateway")
    gateway.add_argument("--port", type=int, default=gateway_assembly.DEFAULT_GATEWAY_PORT)
    gateway.add_argument(
        "--upstream-port", type=int, default=gateway_assembly.DEFAULT_UPSTREAM_PORT
    )
    gateway.add_argument("--bind-host", default="127.0.0.1")
    gateway.add_argument("--web-profile", default=gateway_assembly.DEFAULT_WEB_PROFILE)
    gateway.add_argument("--image-profile", default="")
    gateway.add_argument("--static", type=Path, default=None)
    gateway.add_argument("--file-root", type=Path, action="append", default=[])
    gateway.add_argument(
        "--no-deployment",
        action="store_true",
        help="research arm: read the upstream's own roster where no bundle is activated",
    )
    status = sub.add_parser("status", help="runtime root binding and declared paths")
    status.add_argument("--json", action="store_true")
    sub.add_parser("doctor", help="prerequisites a user-space installer can only detect")
    sub.add_parser("verify", help="layout, components, and live state")
    export = sub.add_parser("export", help="write every saved conversation as one JSON document")
    export.add_argument("output", type=Path)
    imp = sub.add_parser("import", help="import a qwen-apu export or a browser history export")
    imp.add_argument("input", type=Path)
    imp.add_argument("--browser", action="store_true", help="the page's IndexedDB export")
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


def cmd_models_install(paths: RuntimePaths, groups: list[str], dry_run: bool) -> int:
    for outcome in model_installer.install(paths, groups, dry_run=dry_run):
        print(f"{outcome.artifact_id}\t{outcome.status}\t{outcome.destination}")
    return 0


def cmd_install(paths: RuntimePaths, bundle: Path, sha256: str | None) -> int:
    installed = native.install_bundle(paths, bundle, expected_sha256=sha256)
    print(f"bundle={installed.digest} root={installed.root}")
    for record in installed.manifest.executables:
        print(f"{record.name}\t{record.sha256}\t{installed.executable_path(record.name)}")
    return 0


def cmd_native_list(paths: RuntimePaths) -> int:
    for bundle in native.installed_bundles(paths):
        print(f"{bundle.digest}\t{bundle.manifest.recipe}\t{bundle.root}")
    return 0


def cmd_native_stage(args: argparse.Namespace) -> int:
    recipe = load_native_builds().recipes[args.recipe]
    binaries = {name: Path(path) for name, path in (item.split("=", 1) for item in args.binary)}
    patches = dict(item.split("=", 1) for item in args.patch)
    manifest = native.stage_bundle(
        binaries,
        args.output,
        recipe=recipe,
        source_commit=args.source_commit,
        patch_series_digest=patches,
        compiler_identity=args.compiler_identity,
        build_defines=recipe.cmake_defines,
    )
    print(
        f"bundle={manifest.bundle_sha256} manifest={manifest.manifest_sha256} output={args.output}"
    )
    return 0


def cmd_build(paths: RuntimePaths, recipe_name: str, source_archive: str | None, jobs: int) -> int:
    recipe = load_native_builds().recipes[recipe_name]
    build.require_toolchain(tuple(recipe.required_commands))
    upstream = source.acquire_upstream(paths, recipe.upstream_commit, archive_url=source_archive)
    target = paths["qwen_home_llama_source"]
    # The replay digests pin the production series; a candidate member is a
    # measurement arm and joins a build through its own preset, never here.
    production = [m for m in registry.load_patch_series() if m.stage == "production"]
    application = source.apply_series(upstream, target, production, paths.tree / "patches")
    for relocation in application.relocations:
        print(f"relocated\t{relocation}")
    build_dir = target / recipe.build_directory_name
    build.configure_and_build(
        target, build_dir, dict(recipe.cmake_defines), tuple(recipe.targets), jobs=jobs
    )
    print(f"build={build_dir}")
    return 0


def cmd_models_verify(paths: RuntimePaths, artifacts: bool, groups: list[str]) -> int:
    registry.load_models()
    registry.load_draft_pairs()
    registry.load_ctx_checkpoints()
    registry.load_quarantine()
    registry.load_patch_series()
    registry.load_model_artifacts()
    print("registry=consistent")
    if artifacts:
        failures = 0
        for outcome in model_installer.verify(paths, groups or ["all"]):
            print(f"{outcome.artifact_id}\t{outcome.status}\t{outcome.destination}")
            failures += outcome.status != "verified"
        return 1 if failures else 0
    return 0


def cmd_deployment(paths: RuntimePaths, args: argparse.Namespace) -> int:
    root = args.root or paths["qwen_home_deployments"]
    if args.deployment_command == "build":
        identity = deployment_write.build_bundle(
            root,
            args.name,
            args.server,
            args.artifact_manifest,
            args.ctx_ledger,
            router_presets=args.router_presets,
            web_presets=args.web_presets,
            q4k_policy=args.q4k_policy,
        )
        print(f"bundle={identity.name} server_sha256={identity.server_sha256}")
        return 0
    if args.deployment_command == "build-application":
        application = application_deployment.build_application(paths, args.name, root=args.root)
        sys.stdout.write(application.render())
        return 0
    if args.deployment_command == "verify-application":
        report = application_deployment.verify_application(paths, args.name, root=args.root)
        sys.stdout.write(report.render())
        return 0 if report.verified else 1
    if args.deployment_command == "list-applications":
        for name in application_deployment.applications(paths, args.root):
            print(name)
        return 0
    if args.deployment_command == "show":
        sys.stdout.write(deployment.render(deployment.resolve_active(root)))
        return 0
    record = (
        deployment_write.activate(root, args.name)
        if args.deployment_command == "activate"
        else deployment_write.rollback(root)
    )
    print(
        f"transition={record.transition} current={record.current} "
        f"previous={record.previous} generation={record.generation}"
    )
    return 0


def cmd_appliance(paths: RuntimePaths, args: argparse.Namespace) -> int:
    if args.appliance_command == "status":
        sys.stdout.write(appliance.render(appliance.status(paths)))
        return 0
    if args.appliance_command == "stop":
        signalled = appliance.stop(paths)
        print(f"signalled={','.join(str(pid) for pid in signalled) or '-'}")
        record = appliance.status(paths)
        return 0 if record is None or record.state == "stopped" else 1
    image, searxng = appliance.child_specs_from_request(
        paths, image_service=args.image_service, searxng=args.searxng
    )
    return appliance.serve(
        paths,
        appliance.ApplianceRequest(
            serve=serving.ServeRequest(
                router=args.router,
                model_id=args.model,
                profile=args.profile,
                port=args.port,
            ),
            gateway=gateway_assembly.GatewayRequest(
                port=args.gateway_port,
                upstream_port=args.port,
                bind_host=args.bind_host,
                web_profile=args.web_profile,
                image_profile=args.image_profile,
                static_root=args.static,
                file_roots=tuple(args.file_root),
            ),
            image_service=image,
            searxng=searxng,
        ),
    )


def cmd_export(paths: RuntimePaths, output: Path) -> int:
    store = ConversationStore(paths["qwen_home_state"])
    document = store.export_all()
    output.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    exported = document.get("conversations")
    count = len(exported) if isinstance(exported, list) else 0
    print(f"exported={count} path={output}")
    return 0


def cmd_import(paths: RuntimePaths, source: Path, browser: bool) -> int:
    store = ConversationStore(paths["qwen_home_state"])
    data = source.read_bytes()
    if not browser:
        imported = store.import_document(json.loads(data))
        print(f"imported={len(imported)}")
        return 0
    report = browser_import.parse_export(data)
    for conversation in report.conversations:
        store.create(conversation.title, mode="saved", conversation_id=conversation.conversation_id)
        for message in conversation.messages:
            store.append_message(conversation.conversation_id, message)
    for warning in report.warnings:
        print(f"warning\t{warning}", file=sys.stderr)
    print(f"imported={len(report.conversations)} warnings={len(report.warnings)}")
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
            code = cmd_status(paths, args.json)
            return code or serving.status(paths)
        if args.command == "serve":
            request = serving.ServeRequest(
                router=args.router,
                router_max=args.router_max,
                model_id=args.model,
                profile=args.profile,
                port=args.port,
                context=args.context,
                llama_server=args.llama_server,
                model_root=args.model_root,
                daemon=args.daemon,
                cpu_affinity=None if args.no_affinity else serving.INFERENCE_CPUS,
                niceness=None if args.no_affinity else serving.INFERENCE_NICENESS,
                require_radv_icd=not args.skip_radv_icd_check,
            )
            return serving.serve(paths, request)
        if args.command == "stop":
            return serving.stop(paths)
        if args.command == "appliance":
            return cmd_appliance(paths, args)
        if args.command == "acceptance":
            return acceptance.run(
                paths,
                acceptance.AcceptanceRequest(
                    base=args.base,
                    pairing_code=args.pairing_code,
                    report=args.report,
                    text_models=tuple(args.model) or acceptance.DEFAULT_TEXT_MODELS,
                    vision_models=tuple(args.vision_model) or acceptance.DEFAULT_VISION_MODELS,
                    restart_command=tuple(args.restart_command),
                    stop_command=tuple(args.stop_command),
                    lease_path=args.lease_path,
                    appliance_record=args.appliance_state,
                    router_presets=args.router_presets,
                    document_fixtures=args.document_fixtures,
                    file_search_root=args.file_search_root,
                ),
            )
        if args.command == "canary":
            return canary.run(
                paths,
                canary.CanaryRequest(
                    report=args.report,
                    repeats=args.repeats,
                    ratio=args.ratio,
                    base=args.base,
                    prompt=args.prompt,
                    tokens=args.tokens,
                    model=args.model,
                    legacy=canary.ArmCommands(
                        start=tuple(args.legacy_start), stop=tuple(args.legacy_stop)
                    ),
                    python=canary.ArmCommands(
                        start=tuple(args.python_start), stop=tuple(args.python_stop)
                    ),
                    sysfs=canary.sysfs_from_request(args.sysfs),
                    readiness_deadline_s=args.readiness_deadline_s,
                ),
            )
        if args.command == "gateway":
            return gateway_assembly.run(
                paths,
                gateway_assembly.GatewayRequest(
                    port=args.port,
                    upstream_port=args.upstream_port,
                    bind_host=args.bind_host,
                    web_profile=args.web_profile,
                    image_profile=args.image_profile,
                    static_root=args.static,
                    file_roots=tuple(args.file_root),
                    require_deployment=not args.no_deployment,
                ),
            )
        if args.command == "export":
            return cmd_export(paths, args.output)
        if args.command == "import":
            return cmd_import(paths, args.input, args.browser)
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
                return cmd_models_verify(paths, args.artifacts, args.groups)
            return cmd_models_install(paths, args.groups, args.dry_run)
        if args.command == "install":
            return cmd_install(paths, args.bundle, args.sha256)
        if args.command == "build":
            return cmd_build(paths, args.recipe, args.source_archive, args.jobs)
        if args.command == "native":
            if args.native_command == "list":
                return cmd_native_list(paths)
            return cmd_native_stage(args)
        if args.command == "deployment":
            return cmd_deployment(paths, args)
        return unported(args.command)
    except RuntimeRootError as error:
        print(f"qwen-apu: {error}", file=sys.stderr)
        return 2
    except (ValueError, RuntimeError, HistoryError) as error:
        print(f"qwen-apu: {error}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as error:
        print(f"qwen-apu: {error.cmd[0]} exited {error.returncode}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
