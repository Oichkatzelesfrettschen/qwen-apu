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
from qwen_apu.engines.image import IMAGE_DIRECTORY_NAME, SOCKET_FILE_NAME, ImageControlClient
from qwen_apu.engines.llama import LlamaClient, binding_from_runtime
from qwen_apu.runtime import deployment, preflight
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.tools import approvals, calculator, documents, files, images, matrix
from qwen_apu.tools import web as web_tools
from qwen_apu.tools.ledger import Ledger
from qwen_apu.web import artifacts, chat, conversations, llama_ui, status, tool_gate
from qwen_apu.web.app import LOOPBACK_HOSTS, Gateway, GatewayConfig, RequestRefused
from qwen_apu.web.auth import SessionGate
from qwen_apu.web.http import Request, Route

DEFAULT_GATEWAY_PORT = 8090
DEFAULT_UPSTREAM_PORT = 8080
DEFAULT_WEB_PROFILE = "web-open"
# The second listener's own port. It stands clear of the router's 8080 and of
# the legacy shell lane's 42069 to 42071, which `remote/qwen-lan-launch.sh`
# gives the router, the broker, and the artifact listener, so a Python launch
# and a legacy launch bind disjoint sets on one machine.
DEFAULT_LLAMA_UI_PORT = 42072
# The built `tools/ui` bundle under the runtime root, laid down by
# `remote/build-llama-ui.sh`. The deployed server is configured
# `-DLLAMA_BUILD_UI=OFF`, so it embeds no asset table and the listener serves
# these files itself.
LLAMA_UI_ASSET_DIRECTORY = ("llama-ui", "dist")


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
    # Whether a SearXNG instance this launch armed serves the profile's own
    # `searxng_url`. A launch that derived no child for a profile naming one
    # clears this, and the executor stays unmounted so the matrix reports both
    # web rows `temporarily_unavailable` rather than letting an approved query
    # spend its single-use grant at a provider nothing is listening for.
    searxng_armed: bool = True
    # The second listener that serves llama.cpp's own page through the loopback
    # proxy. Zero starts one listener, which is the ordinary launch.
    llama_ui_port: int = 0
    # The built bundle the second listener serves. None reads the runtime
    # root's own directory where it holds an `index.html`, and leaves the
    # listener proxying every path where it does not.
    llama_ui_static: Path | None = None


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


def lan_exposure(bind_host: str) -> str:
    """The one Host literal a LAN bind admits beside the loopback names.

    A gateway bound to a routable address answers requests whose Host names
    that address, the way `QWEN_WEB_LAN=1` admits one IPv4 literal in the
    shell lane; a loopback bind adds nothing to the closed set.
    """
    return "" if bind_host in LOOPBACK_HOSTS else bind_host


def page_origin(request: GatewayRequest) -> str:
    """The origin of the chat page's own listener, as a browser spells it."""
    return f"http://{request.bind_host}:{request.port}"


def llama_ui_origin(request: GatewayRequest) -> str:
    """The second listener's origin, or the empty string where a launch starts none."""
    if request.llama_ui_port <= 0:
        return ""
    return f"http://{request.bind_host}:{request.llama_ui_port}"


def llama_ui_assets(paths: RuntimePaths, request: GatewayRequest) -> Path | None:
    """The bundle directory this listener serves from disk, or None.

    An explicit directory is taken as named and refused where it holds no
    `index.html`, since a launch that names a bundle and serves none would
    proxy to a server that has no page either. The default is the runtime
    root's own `opt/llama-ui/dist`, which answers None while no build has run.
    """
    named = request.llama_ui_static
    if named is not None:
        if not (named / "index.html").is_file():
            raise ValueError(f"the named Web UI bundle carries no index.html: {named}")
        return named
    derived = paths["qwen_home_opt"].joinpath(*LLAMA_UI_ASSET_DIRECTORY)
    return derived if (derived / "index.html").is_file() else None


def upstream_client(paths: RuntimePaths, request: GatewayRequest) -> LlamaClient:
    """One client over the server the supervisor published, or the fallback port.

    Both listeners read the same binding, so the proxied page and the chat lane
    answer from one process identity rather than from two views of a port.
    """
    return LlamaClient(
        binding_from_runtime(paths["qwen_home_runtime_state"], fallback_port=request.upstream_port)
    )


def assemble_llama_ui(
    paths: RuntimePaths,
    request: GatewayRequest,
    *,
    session: SessionGate,
    gate: tool_gate.ToolGate | None = None,
) -> Gateway | None:
    """The second listener, sharing this launch's session gate and Host set.

    The proxy holds every route of this gateway, so no request reaches the
    gateway's own static branch; the proxy reads the bundle itself, which is
    what keeps the session gate ahead of every file it serves. `SessionGate.guards` names `/api/`,
    which no router path matches, so the proxy calls `require_session` itself
    and this gateway names no session authority.
    """
    if request.llama_ui_port <= 0:
        return None
    if request.llama_ui_port == request.port:
        raise ValueError(
            "the built-in page takes a listener of its own, so its port differs "
            f"from the gateway's: {request.port}"
        )
    origin = llama_ui_origin(request)
    static_root = request.static_root or paths.tree / "static"
    card_directory = static_root / llama_ui.PAIRING_PAGE_DIRECTORY
    assets = llama_ui_assets(paths, request)
    config = GatewayConfig(
        static_root=assets or card_directory,
        port=request.llama_ui_port,
        bind_host=request.bind_host,
        origins=(origin,),
        exposure=lan_exposure(request.bind_host),
    )
    settings = llama_ui.LlamaUiSettings(
        client_factory=lambda: upstream_client(paths, request),
        require_session=session.require_session,
        pairing_page=card_directory / llama_ui.PAIRING_PAGE_NAME,
        origin=origin,
        assets=assets,
        # The shell on the chat page's port frames this page, so that origin
        # is the one `frame-ancestors` admits.
        frame_ancestors=page_origin(request),
        # The same gate the chat page's rail decides on, so a call parked from
        # llama.cpp's page is the call the operator sees there.
        tool_gate=gate,
    )
    return Gateway(config, (llama_ui.LlamaUiProxy(settings),))


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
        exposure=lan_exposure(request.bind_host),
        # The shell frames the second listener's page; a launch that binds
        # none leaves the page framing nothing.
        frame_sources=(llama_ui_origin(request),),
    )
    # The gateway serves plain HTTP on every bind, and a Secure cookie travels
    # over HTTPS alone, so a Secure attribute would make the pairing cookie one
    # the browser never returns; the attribute follows a TLS front when one
    # exists rather than the bind address.
    session = SessionGate(state, secure_cookie=False)

    def session_check(incoming: Request) -> approvals.SessionOrRefusal:
        try:
            session.require_session(incoming)
        except RequestRefused as refusal:
            return approvals.SessionOrRefusal(False, str(refusal))
        return approvals.SessionOrRefusal(True)

    def session_admits(incoming: Request) -> bool:
        return session_check(incoming).admitted

    def client() -> LlamaClient:
        return upstream_client(paths, request)

    approval_settings = approvals.build_settings(
        state,
        paths["qwen_home_web_token_key"],
        request.web_profile,
        config.origins,
        provider=request.provider,
        image_profile=request.image_profile,
        exposure=lan_exposure(request.bind_host),
    )
    approval_service = approvals.ApprovalService(approval_settings, session_check)
    # One gate signs the grants for tool calls llama.cpp's own page makes,
    # through the same settings and key the grant routes above sign with.
    approval_gate = tool_gate.ToolGate(approval_settings)
    # The per-launch secret every grant post presents is minted here, at the
    # one place this launch's service exists, and its file is what the
    # teardown proves absent; a service left unarmed compares every presented
    # secret against an empty string and admits none. Every assembly step after
    # the arming can refuse -- an occupied gateway port is the ordinary case --
    # and the teardown requires the file gone whether or not a process ran, so
    # the arming and the rest of the assembly share one lifecycle that disarms
    # on the way out.
    approval_service.arm_session_secret()
    try:
        return _assemble_armed(
            paths,
            request,
            config=config,
            state=state,
            session=session,
            session_check=session_check,
            session_admits=session_admits,
            client=client,
            approval_settings=approval_settings,
            approval_service=approval_service,
            approval_gate=approval_gate,
        )
    except BaseException:
        approval_service.disarm_session_secret()
        raise


def _assemble_armed(
    paths: RuntimePaths,
    request: GatewayRequest,
    *,
    config: GatewayConfig,
    state: Path,
    session: SessionGate,
    session_check: Callable[[Request], approvals.SessionOrRefusal],
    session_admits: Callable[[Request], bool],
    client: Callable[[], LlamaClient],
    approval_settings: approvals.ApprovalSettings,
    approval_service: approvals.ApprovalService,
    approval_gate: tool_gate.ToolGate,
) -> tuple[Gateway, SessionGate]:
    """Mount every provider on one gateway, with the session secret already armed.

    `assemble` owns the arming and the disarming, so a refusal raised anywhere
    below leaves `authorize-session.secret` absent rather than authorizing a
    page against the launch that follows this one.
    """

    def ledger() -> Ledger:
        return Ledger(state)

    def spend_grant(grant_id: str, expiry: float, client: str) -> None:
        with closing(ledger()) as open_ledger:
            open_ledger.consume_grant(
                grant_id, approval_settings.profile, "image", expiry=expiry, now=time.time()
            )
        # The reservation counted the grant until its expiry; the spend is
        # the moment it stops being outstanding, so the client's slot frees
        # for the review grant that follows a generation.
        approval_service.outstanding_image_grants.release(client, expiry)

    web_settings = build_web_tool_settings(
        resolve_web_profile(request.web_profile) if request.searxng_armed else None,
        token_key_file=paths["qwen_home_web_token_key"],
        profile_id=approval_settings.profile,
        session_admits=session_admits,
        ledger=ledger,
    )
    # The image worker publishes each verified pair and its publication
    # marker under `images/artifacts/` of the state directory it is given, so
    # the artifact routes read that directory rather than a sibling.
    artifact_directory = state / "images" / "artifacts"
    image_socket = state / IMAGE_DIRECTORY_NAME / SOCKET_FILE_NAME

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
            llama_ui_origin=llama_ui_origin(request),
        ),
        _Providers(approvals.routes(approval_service)),
        _Providers(approval_gate.routes()),
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
    gateway = Gateway(
        config,
        providers,
        session_authority=session,
        on_shutdown=(
            conversation_settings.temporary.shutdown,
            approval_service.disarm_session_secret,
        ),
    )
    # The second listener is assembled from this gateway's gate, so the calls
    # its proxy parks are the ones this gateway's pending route lists.
    gateway.tool_gate = approval_gate
    return gateway, session


def run(paths: RuntimePaths, request: GatewayRequest) -> int:
    gateway, session = assemble(paths, request)
    # `session.start()` runs inside the shutdown guard because the gateway's
    # `on_shutdown` carries the secret's disarming, and a pairing code this
    # process fails to mint would otherwise leave the file behind.
    try:
        code = session.start()
        print(f"gateway=http://{request.bind_host}:{gateway.port}/ pairing_code={code}", flush=True)
        gateway.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        gateway.shutdown()
    return 0
