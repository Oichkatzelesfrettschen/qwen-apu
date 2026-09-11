"""One origin: every route provider mounted on one gateway.

`assemble` joins the modules that each test alone: the pairing session gate,
the chat proxy to the router on loopback, the status routes carrying the
approval identity, the approval broker's grant routes over the shared
ledger, the artifact reads, and the image tool routes whose grant spend
goes through that same ledger. The runtime root supplies every path.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

from qwen_apu.engines.image import ImageControlClient
from qwen_apu.engines.llama import LlamaClient, binding_from_runtime
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.tools import approvals, calculator, documents, files, images, registry
from qwen_apu.tools.ledger import Ledger
from qwen_apu.web import artifacts, chat, conversations, status
from qwen_apu.web.app import Gateway, GatewayConfig, RequestRefused
from qwen_apu.web.auth import SessionGate
from qwen_apu.web.http import Request, Route

DEFAULT_GATEWAY_PORT = 8090
DEFAULT_UPSTREAM_PORT = 8080
DEFAULT_WEB_PROFILE = "web-open"
DEFAULT_REVIEW_MODEL = "lfm25-vl-16b"


@dataclass(frozen=True)
class GatewayRequest:
    port: int = DEFAULT_GATEWAY_PORT
    upstream_port: int = DEFAULT_UPSTREAM_PORT
    bind_host: str = "127.0.0.1"
    web_profile: str = DEFAULT_WEB_PROFILE
    image_profile: str = ""
    provider: str = "searxng"
    review_model: str = DEFAULT_REVIEW_MODEL
    static_root: Path | None = None
    # Read-only roots the file search may reach; empty admits nothing.
    file_roots: tuple[Path, ...] = ()


class _Providers:
    def __init__(self, routes: tuple[Route, ...]) -> None:
        self._routes = routes

    def routes(self) -> tuple[Route, ...]:
        return self._routes


def assemble(paths: RuntimePaths, request: GatewayRequest) -> tuple[Gateway, SessionGate]:
    state = paths["qwen_home_state"]
    state.mkdir(parents=True, exist_ok=True)
    state.chmod(0o700)
    static_root = request.static_root or paths.tree / "webui"
    if request.port <= 0:
        raise ValueError("the gateway names its own origin, so the port must be explicit")
    # One origin serves the page and the routes, so the page origin the
    # approval rules admit is the gateway's own address.
    origin = f"http://{request.bind_host}:{request.port}"
    config = GatewayConfig(
        static_root=static_root,
        port=request.port,
        bind_host=request.bind_host,
        origins=(origin,),
    )
    session = SessionGate(state, secure_cookie=not config.binds_loopback)

    def session_check(incoming: Request) -> approvals.SessionOrRefusal:
        try:
            session.require_session(incoming)
        except RequestRefused as refusal:
            return approvals.SessionOrRefusal(False, str(refusal))
        return approvals.SessionOrRefusal(True)

    def session_admits(incoming: Request) -> bool:
        return session_check(incoming).admitted

    def client() -> LlamaClient:
        return LlamaClient(
            binding_from_runtime(
                paths["qwen_home_runtime_state"], fallback_port=request.upstream_port
            )
        )

    approval_settings = approvals.build_settings(
        state,
        paths["qwen_home_web_token_key"],
        request.web_profile,
        config.origins,
        provider=request.provider,
        image_profile=request.image_profile,
    )
    approval_service = approvals.ApprovalService(approval_settings, session_check)
    ledger = Ledger(state)

    def spend_grant(grant_id: str, expiry: float) -> None:
        ledger.consume_grant(
            grant_id, approval_settings.profile, "image", expiry=expiry, now=time.time()
        )

    artifact_directory = state / "artifacts"
    image_settings = images.ImageToolSettings(
        client=ImageControlClient(state / "image-service.sock", timeout=30.0),
        artifacts=artifacts.ArtifactDirectory(artifact_directory),
        review_model=request.review_model,
        spend_grant=spend_grant,
    )
    identity = {
        "profile": approval_settings.profile,
        "image_profile": approval_settings.image_profile,
        "provider": approval_settings.provider,
        "signing_key_sha256": approval_settings.signing_key_sha256,
    }
    conversation_settings = conversations.build(state, paths["qwen_home_tmp"], session_check)
    file_roots = tuple(root for root in request.file_roots if root.is_dir())
    providers = (
        session,
        _Providers(conversations.routes(conversation_settings)),
        _Providers(calculator.routes(calculator.CalculatorSettings(session_admits=session_admits))),
        _Providers(
            files.routes(
                files.FilesToolSettings(
                    search=files.FileSearchSettings(roots=file_roots),
                    session_admits=session_admits,
                )
            )
        ),
        _Providers(
            documents.routes(
                documents.DocumentService(
                    documents.DocumentSettings(
                        artifacts=paths["qwen_home_artifacts"],
                        tmp=paths["qwen_home_tmp"],
                        session_admits=session_admits,
                    )
                )
            )
        ),
        chat.ChatService(client),
        status.StatusService(
            client,
            runtime_record=paths["qwen_home_runtime_state"],
            session_gate=session,
            approval_identity=identity,
        ),
        _Providers(approvals.routes(approval_service)),
        _Providers(registry.routes()),
        _Providers(
            artifacts.routes(
                artifacts.ArtifactSettings(
                    directory=artifact_directory,
                    admitted_hosts=config.admitted_hosts(),
                    session_admits=session_admits,
                )
            )
        ),
        _Providers(images.routes(image_settings)),
    )
    return Gateway(config, providers, session_authority=session), session


def run(paths: RuntimePaths, request: GatewayRequest) -> int:
    gateway, session = assemble(paths, request)
    code = session.start()
    print(f"gateway=http://{request.bind_host}:{gateway.port}/ pairing_code={code}", flush=True)
    try:
        gateway.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        gateway.shutdown()
    return 0
