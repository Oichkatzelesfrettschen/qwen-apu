"""One origin: every route provider mounted on one gateway.

`assemble` joins the modules that each test alone: the pairing session gate,
the chat proxy to the router on loopback, the status routes carrying the
approval identity, the approval broker's grant routes over the shared
ledger, the artifact reads, and the image tool routes whose grant spend
goes through that same ledger. The runtime root supplies every path.
"""

from __future__ import annotations

import json
import time
from collections.abc import Callable, Mapping, Sequence
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path

from qwen_apu.config import models as config_models
from qwen_apu.config.loader import RegistryError
from qwen_apu.config.schema import WebProfile
from qwen_apu.engines import llama as llama_engine
from qwen_apu.engines.image import SOCKET_FILE_NAME, ImageControlClient
from qwen_apu.engines.llama import LlamaClient, binding_from_runtime
from qwen_apu.runtime import deployment, preflight
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.tools import approvals, calculator, documents, files, images, matrix
from qwen_apu.tools import web as web_tools
from qwen_apu.tools.ledger import Ledger
from qwen_apu.web import artifacts, chat, conversations, status
from qwen_apu.web.app import Gateway, GatewayConfig, RequestRefused
from qwen_apu.web.auth import SessionGate
from qwen_apu.web.http import Request, Route

DEFAULT_GATEWAY_PORT = 8090
DEFAULT_UPSTREAM_PORT = 8080
DEFAULT_WEB_PROFILE = "web-open"


@dataclass(frozen=True)
class GatewayRequest:
    port: int = DEFAULT_GATEWAY_PORT
    upstream_port: int = DEFAULT_UPSTREAM_PORT
    bind_host: str = "127.0.0.1"
    web_profile: str = DEFAULT_WEB_PROFILE
    image_profile: str = ""
    provider: str = "searxng"
    # Empty reads the reviewer from the armed image profile's own ledger row;
    # an explicit value overrides it. `remote/image-profiles.tsv` reads `-`
    # where a shape offers no review, which leaves the reviewer empty and the
    # review route refusing rather than falling back to some other checkpoint.
    review_model: str = ""
    static_root: Path | None = None
    # Read-only roots the file search may reach; empty admits nothing.
    file_roots: tuple[Path, ...] = ()
    # The activated bundle is the roster's own authority, so the ordinary
    # gateway requires one; a research gateway against an unsupervised server
    # clears this and reads the upstream's roster alone.
    require_deployment: bool = True


def review_model_for(request: GatewayRequest) -> str:
    """The reviewer this launch runs, from the armed image profile's ledger row.

    `remote/image-profiles.tsv` pairs one vision checkpoint with one image
    shape, because the reviewer belongs to the profile that produced the
    artifact rather than to the conversation that asked for it. An explicit
    `review_model` on the request wins, an armed profile answers from its own
    row, and a `-` there leaves the reviewer empty so the review route refuses
    rather than reaching a checkpoint no ledger paired with the shape.
    """
    if request.review_model:
        return request.review_model
    if not request.image_profile:
        return ""
    try:
        return config_models.image_profile(request.image_profile).review_model or ""
    except RegistryError:
        return ""


# One ledger connection belongs to the thread that opened it, so every writer
# takes a fresh one for its own call rather than sharing a handle across the
# gateway's request threads.
LedgerFactory = Callable[[], Ledger]


def resolve_web_profile(profile_id: str) -> WebProfile | None:
    """Return the `remote/web-profiles.tsv` row this gateway serves under.

    The row carries the SearXNG endpoint, the categories, the minimum result
    count, and the three per-profile bounds together, so the executor's limits
    come from the ledger a preset is generated from rather than from constants
    chosen here. A profile the ledger does not name, and a ledger a checkout
    does not carry, leave the executor unmounted: the gateway serves chat and
    the tool listing reports both web rows as planned, which is an honest
    answer where refusing the launch would be a wrong one.
    """
    try:
        rows = config_models.load_web_profiles()
    except RegistryError:
        return None
    for row in rows:
        if row.profile_id == profile_id:
            return row
    return None


def build_web_tool_settings(
    profile: WebProfile | None,
    *,
    token_key_file: Path,
    profile_id: str,
    session_admits: Callable[[Request], bool],
    ledger: LedgerFactory,
) -> web_tools.WebToolSettings:
    """Return the executor's settings, with the instance absent where the row is.

    The three ledger operations are bound here rather than inside the tool
    module: the grant's single use, the fetch allowance an approved search
    opens over its own results, and the spend of one unit of that allowance all
    write the database `qwen_apu.tools.ledger` owns, and the executor holds no
    handle on it.

    Each operation opens its own connection and closes it, the way
    `remote/web-mcp/server.py` opens the ledger per call. `sqlite3` binds a
    connection to the thread that created it, and the gateway answers every
    request on a worker, so a handle opened at assembly raises
    `ProgrammingError` on the first call rather than serializing anything;
    `BEGIN IMMEDIATE` and the 10-second busy timeout are what serialize two
    connections instead.
    """
    settings = web_tools.WebToolSettings(
        token_key_file=token_key_file,
        profile=profile_id,
        session_admits=session_admits,
    )
    if profile is None or profile.provider != "searxng" or not profile.searxng_url:
        return settings

    def spend_search_grant(grant_id: str, expiry: float) -> None:
        with closing(ledger()) as open_ledger:
            open_ledger.consume_grant(
                grant_id, profile_id, "searxng", expiry=expiry, now=time.time()
            )

    def open_search(search_id: str, allowance: int, expiry: float, urls: Sequence[str]) -> None:
        with closing(ledger()) as open_ledger:
            open_ledger.open_search(
                search_id,
                profile_id,
                "searxng",
                fetches_allowed=allowance,
                expiry=expiry,
                urls=urls,
            )

    def spend_fetch(search_id: str, url: str) -> None:
        with closing(ledger()) as open_ledger:
            open_ledger.spend_fetch(search_id, url, time.time())

    return web_tools.WebToolSettings(
        token_key_file=token_key_file,
        profile=profile_id,
        provider="searxng",
        searxng=web_tools.SearxngProvider(
            profile.searxng_url,
            profile.primary_category or "",
            fallback_category=profile.fallback_category or "",
            minimum_results=profile.minimum_results or 1,
        ),
        max_results=profile.max_results,
        max_fetches=profile.max_fetches,
        max_chars_per_fetch=profile.max_chars_per_fetch,
        session_admits=session_admits,
        spend_grant=spend_search_grant,
        open_search=open_search,
        spend_fetch=spend_fetch,
    )


class _Providers:
    def __init__(self, routes: tuple[Route, ...]) -> None:
        self._routes = routes

    def routes(self) -> tuple[Route, ...]:
        return self._routes


def preflight_gateway(paths: RuntimePaths, request: GatewayRequest) -> tuple[str, ...]:
    """Decide the gateway's two preconditions before it writes anything.

    The signing key is the credential every grant is signed from, and the
    approval settings read it at assembly, so a key that is absent, owned by
    another user, group-readable, or not UTF-8 text refuses the launch here
    rather than at the first approval a page asks for. The activated deployment
    is the authority the roster joins against, so a gateway without one would
    answer the registry's whole list as though the appliance served it, which is
    the gap this pass closes.

    `require_deployment` is the one arm that opts out: a research gateway
    pointed at a server it did not supervise reads the upstream's own roster and
    states that in the answer's `mode`.
    """
    report: list[str] = []
    report.append(preflight.verify_signing_key(paths["qwen_home_web_token_key"]).render())
    if request.require_deployment:
        active = preflight.verify_deployment(paths["qwen_home_deployments"])
        report.append(f"deployment_preflight name={active.name} directory={active.directory}")
    return tuple(report)


def active_router_presets(paths: RuntimePaths) -> Path | None:
    """The current bundle's router preset, or None where no bundle names one.

    The resolution runs per request rather than once at assembly, since an
    activation replaces `deployment-current` under a running gateway and the
    roster answers for the bundle that is current when the page asks.
    """
    try:
        return deployment.resolve_active(paths["qwen_home_deployments"]).router_presets
    except deployment.DeploymentError:
        return None


def assemble(paths: RuntimePaths, request: GatewayRequest) -> tuple[Gateway, SessionGate]:
    for line in preflight_gateway(paths, request):
        print(line, flush=True)
    state = paths["qwen_home_state"]
    state.mkdir(parents=True, exist_ok=True)
    state.chmod(0o700)
    static_root = request.static_root or paths.tree / "static"
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

    def ledger() -> Ledger:
        return Ledger(state)

    def spend_grant(grant_id: str, expiry: float) -> None:
        with closing(ledger()) as open_ledger:
            open_ledger.consume_grant(
                grant_id, approval_settings.profile, "image", expiry=expiry, now=time.time()
            )

    web_settings = build_web_tool_settings(
        resolve_web_profile(request.web_profile),
        token_key_file=paths["qwen_home_web_token_key"],
        profile_id=approval_settings.profile,
        session_admits=session_admits,
        ledger=ledger,
    )
    artifact_directory = state / "artifacts"
    image_socket = state / SOCKET_FILE_NAME

    def route_review(payload: Mapping[str, object]) -> object:
        """One `/v1/chat/completions` round trip against the router on loopback.

        The reviewer runs through the same upstream the chat proxy binds to the
        server's pid, and the reply is parsed here so `tools/images.py` stays
        free of a transport and reports completion, schema validity, and
        judgment over a document.
        """
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        answer = client().chat_completions(body, {"content-type": "application/json"})
        collected = llama_engine.collect(answer)
        if answer.status >= 400:
            raise images.ToolRefused(
                502, f"the router answered HTTP {answer.status} to the image reviewer"
            )
        try:
            return json.loads(collected.decode("utf-8"))
        except (UnicodeDecodeError, ValueError):
            raise images.ToolRefused(502, "the router answered the reviewer no JSON") from None

    image_settings = images.ImageToolSettings(
        client=ImageControlClient(image_socket, timeout=30.0),
        artifacts=artifacts.ArtifactDirectory(artifact_directory),
        review_model=review_model_for(request),
        router=route_review,
        spend_grant=spend_grant,
        session_admits=session_admits,
    )
    identity = {
        "profile": approval_settings.profile,
        "image_profile": approval_settings.image_profile,
        "provider": approval_settings.provider,
        "signing_key_sha256": approval_settings.signing_key_sha256,
    }
    conversation_settings = conversations.build(
        state,
        paths["qwen_home_tmp"],
        session_check,
        document_store=paths["qwen_home_artifacts"] / conversations.DOCUMENT_STORE_DIRECTORY,
    )
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
        chat.ChatService(
            client,
            runtime_record=paths["qwen_home_runtime_state"],
            router_presets=lambda: active_router_presets(paths),
        ),
        status.StatusService(
            client,
            runtime_record=paths["qwen_home_runtime_state"],
            session_gate=session,
            approval_identity=identity,
        ),
        _Providers(approvals.routes(approval_service)),
        _Providers(
            matrix.routes(
                matrix.MatrixSettings(
                    approval_profile=approval_settings.profile,
                    image_profile=approval_settings.image_profile,
                    provider=approval_settings.provider,
                    open_lan=approval_settings.open_lan,
                    image_socket=image_socket,
                    file_roots=file_roots,
                    web_definitions=(
                        web_tools.tool_definitions(web_settings) if web_settings.mounted else None
                    ),
                )
            )
        ),
        _Providers(web_tools.routes(web_settings)),
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
    return (
        Gateway(
            config,
            providers,
            session_authority=session,
            on_shutdown=(conversation_settings.temporary.shutdown,),
        ),
        session,
    )


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
