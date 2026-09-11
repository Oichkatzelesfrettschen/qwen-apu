"""Drive the approval routes through the Request dataclass, with no listener.

`remote/web-mcp/test-authorize-broker.py` measures the predecessor on the wire
because the predecessor is a process. The rules moved into
`qwen_apu.tools.approvals` are handler rules, so every case that states a
policy runs here against a `Request` and the `Response` it answers with, and
the cases that state a process property -- the request-read deadline, the
SIGTERM unwind, the `listening` line, the `--help` and README text -- belong
to the server and launch layers and are recorded as `not run` in this module's
docstring rather than approximated.

Two cross-checks run against the shell tree itself, both by importing
`remote/web-mcp/server.py` and `remote/web-mcp/image_grant.py` through
importlib: a grant minted here verifies under `server.verify_claim` with every
field intact, and its single use spends once in the ledger both writers share.
The claim inputs are chosen to exercise the normalization rather than the
happy path -- a non-ASCII query the JSON encoder escapes, a domain list
needing case folding, root-dot stripping, and sorting at once, a date in an
extended ISO form, and an absent `max_age_hours` that stays null -- since an
ASCII round trip passes even against a rewritten encoder.

Not run, with the reason:

- the request-read deadline and the peer it must not block: the deadline is a
  socket timer the gateway's server layer owns;
- the SIGTERM unwind and the session-secret residue it proves: the launch
  layer signals the process, and `disarm_session_secret` is what this module
  exposes to it;
- "no signing key in stderr": this module writes no log stream;
- the `listening` line, the `--host` and `--open-all-interfaces` bind rules,
  and the `--help` text: the gateway binds one listener for every route;
- the CORS preflight: a same-origin gateway sends none, and the Origin gate
  the preflight guarded is measured directly.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import sqlite3
import sys
import threading
import time
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest

from qwen_apu.tools import approvals, registry
from qwen_apu.tools.approvals import (
    ApprovalService,
    ApprovalSettings,
    SessionOrRefusal,
    build_settings,
)
from qwen_apu.tools.ledger import GrantReplayed, InvalidArgument, Ledger, RateLimited
from qwen_apu.web.http import Request, Response, match

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
WEB_MCP_DIRECTORY = REPOSITORY_ROOT / "remote" / "web-mcp"

TOKEN_SECRET = "broker-token-secret-QJ4LZP"  # noqa: S105 -- a fixture key
ORIGIN = "http://127.0.0.1:8080"
EXPOSED_ADDRESS = "192.0.2.10"
EXPOSED_NAME = "qwen-test.local"
NAME_ORIGIN = "http://qwen-test.local:8080"
# Every case here runs from one client address, so the per-client bucket
# admits more than any case sends unless the case overrides it to measure the
# bound itself.
PER_CLIENT_LIMIT_UNMETERED = 1000


def _load_module(name: str, path: Path) -> ModuleType:
    """Import one shell-tree module by path, the way its own tests do."""
    specification = importlib.util.spec_from_file_location(name, path)
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    sys.modules[name] = module
    specification.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def mcp_server() -> ModuleType:
    """The MCP child's own module, which verifies what this package signs."""
    for directory in (WEB_MCP_DIRECTORY, WEB_MCP_DIRECTORY.parent):
        if str(directory) not in sys.path:
            sys.path.insert(0, str(directory))
    return _load_module("server", WEB_MCP_DIRECTORY / "server.py")


@pytest.fixture(scope="module")
def mcp_image_grant(mcp_server: ModuleType) -> ModuleType:
    """The image claim's own module, which rebuilds what this package signs."""
    del mcp_server
    return _load_module("image_grant", WEB_MCP_DIRECTORY / "image_grant.py")


@pytest.fixture
def workspace(tmp_path: Path) -> Iterator[Path]:
    """A state directory and a signing key under the rules the ledger applies."""
    previous_umask = os.umask(0o077)
    state = tmp_path / "state"
    state.mkdir(mode=0o700)
    key = tmp_path / "token.key"
    key.write_text(TOKEN_SECRET + "\n", encoding="utf-8")
    key.chmod(0o600)
    yield tmp_path
    os.umask(previous_umask)


def state_directory(workspace: Path) -> Path:
    return workspace / "state"


def token_key(workspace: Path) -> Path:
    return workspace / "token.key"


def admit_every_session(request: Request) -> SessionOrRefusal:
    del request
    return SessionOrRefusal(True)


def admit_header_session(request: Request) -> SessionOrRefusal:
    """Admit a caller presenting the test session header, refuse every other."""
    if request.header("x-test-session") == "admitted":
        return SessionOrRefusal(True)
    return SessionOrRefusal(False, "no gateway session cookie")


def make_settings(workspace: Path, **overrides: Any) -> ApprovalSettings:
    arguments: dict[str, Any] = {
        "state_directory": state_directory(workspace),
        "token_key_file": token_key(workspace),
        "profile": "default",
        "origins": (ORIGIN,),
        "provider": "fake",
        "grant_per_client_per_minute": PER_CLIENT_LIMIT_UNMETERED,
        "image_grant_per_client_per_minute": PER_CLIENT_LIMIT_UNMETERED,
        "image_max_outstanding_grants_per_client": PER_CLIENT_LIMIT_UNMETERED,
        "per_minute": 100,
    }
    arguments.update(overrides)
    return build_settings(**arguments)


def make_service(
    workspace: Path,
    session_check: Any = approvals.refuse_every_session,
    **overrides: Any,
) -> ApprovalService:
    service = ApprovalService(make_settings(workspace, **overrides), session_check)
    service.arm_session_secret()
    return service


def build_request(
    method: str,
    path: str,
    *,
    service: ApprovalService | None = None,
    payload: object = None,
    host: str = "127.0.0.1:8080",
    origin: str | None = ORIGIN,
    secret: str | None = None,
    client: str = "127.0.0.1",
    extra_headers: dict[str, str] | None = None,
    body: bytes | None = None,
) -> Request:
    headers: dict[str, str] = {"content-type": "application/json"}
    if host:
        headers["host"] = host
    if origin is not None:
        headers["origin"] = origin
    if secret is None and service is not None:
        secret = service.session_secret
    if secret is not None:
        headers[approvals.SESSION_HEADER.lower()] = secret
    for name, value in (extra_headers or {}).items():
        headers[name.lower()] = value
    if body is None:
        body = b"" if payload is None else json.dumps(payload).encode("utf-8")
    return Request(method, path, {}, headers, body, client)


def call(service: ApprovalService, request: Request) -> Response:
    found = match(approvals.routes(service) + registry.routes(), request.method, request.path)
    assert found is not None, f"no route for {request.method} {request.path}"
    route, params = found
    answer = route.handler(replace(request, path_params=params))
    assert isinstance(answer, Response)
    return answer


def body_of(response: Response) -> dict[str, Any]:
    parsed = json.loads(response.body.decode("utf-8"))
    assert isinstance(parsed, dict)
    return parsed


def post_grant(
    service: ApprovalService, payload: object, **overrides: Any
) -> tuple[int, dict[str, Any], Response]:
    request = build_request(
        "POST", approvals.GRANT_PATH, service=service, payload=payload, **overrides
    )
    response = call(service, request)
    return response.status, body_of(response), response


def post_image_grant(
    service: ApprovalService, payload: object, **overrides: Any
) -> tuple[int, dict[str, Any], Response]:
    request = build_request(
        "POST", approvals.IMAGE_GRANT_PATH, service=service, payload=payload, **overrides
    )
    response = call(service, request)
    return response.status, body_of(response), response


def audit_rows(workspace: Path) -> list[tuple[Any, ...]]:
    connection = sqlite3.connect(state_directory(workspace) / "web-mcp-state.sqlite3")
    try:
        return connection.execute(
            "SELECT profile, operation, query_sha256, domains, result_count,"
            " fetched_host, provider_bytes, returned_characters, status FROM audit"
        ).fetchall()
    finally:
        connection.close()


def search_payload(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {"query": "raven2 vulkan decode", "profile_id": "default"}
    payload.update(overrides)
    return payload


def image_payload(**overrides: Any) -> dict[str, Any]:
    empty = hashlib.sha256(b"").hexdigest()
    payload: dict[str, Any] = {
        "context": "qwen-image-generate-v1",
        "language_profile": "default",
        "image_profile": "image-fixture-a",
        "prompt_hash": hashlib.sha256(b"a fox").hexdigest(),
        "negative_prompt_hash": empty,
        "seed": 7,
        "aspect": "1:1",
        "max_dimension": 512,
        "max_steps": 4,
        "conversation_generation": 0,
    }
    payload.update(overrides)
    return payload


# The signing key rules, which the predecessor applied before its socket
# existed and this package applies before a settings object exists.


def test_an_unnamed_signing_key_path_is_refused(workspace: Path) -> None:
    with pytest.raises(InvalidArgument, match="name it"):
        make_settings(workspace, token_key_file="")


def test_an_absent_signing_key_path_is_refused(workspace: Path) -> None:
    with pytest.raises(InvalidArgument, match="unreadable"):
        make_settings(workspace, token_key_file=workspace / "no-such-key")


def test_a_signing_key_readable_outside_its_owner_is_refused(workspace: Path) -> None:
    loose = workspace / "loose.key"
    loose.write_text(TOKEN_SECRET + "\n", encoding="utf-8")
    loose.chmod(0o644)
    with pytest.raises(InvalidArgument, match="chmod 0600"):
        make_settings(workspace, token_key_file=loose)


def test_a_signing_key_that_is_a_symlink_is_refused(workspace: Path) -> None:
    link = workspace / "key.link"
    link.symlink_to(token_key(workspace))
    with pytest.raises(InvalidArgument, match="symlink"):
        make_settings(workspace, token_key_file=link)


def test_an_empty_signing_key_is_refused(workspace: Path) -> None:
    empty = workspace / "empty.key"
    empty.write_bytes(b"")
    empty.chmod(0o600)
    with pytest.raises(InvalidArgument, match="empty"):
        make_settings(workspace, token_key_file=empty)


def test_a_whitespace_signing_key_is_refused(workspace: Path) -> None:
    blank = workspace / "whitespace.key"
    blank.write_text(" \t\n", encoding="utf-8")
    blank.chmod(0o600)
    with pytest.raises(approvals.ToolError, match="empty"):
        make_settings(workspace, token_key_file=blank)


def test_a_non_utf8_signing_key_is_refused(workspace: Path) -> None:
    invalid = workspace / "invalid-utf8.key"
    invalid.write_bytes(b"\xff\xfe")
    invalid.chmod(0o600)
    with pytest.raises(approvals.ToolError, match="not UTF-8 text"):
        make_settings(workspace, token_key_file=invalid)


def test_the_key_digest_covers_the_file_bytes_and_the_hmac_key_is_stripped(
    workspace: Path,
) -> None:
    """One file yields two values and neither substitutes for the other.

    `/health` on the predecessor reports the digest of the file's own bytes,
    trailing newline included, while `sign_claim` keys the HMAC with that
    content stripped. Collapsing them would change every signature.
    """
    settings = make_settings(workspace)
    assert settings.signing_key_sha256 == hashlib.sha256((TOKEN_SECRET + "\n").encode()).hexdigest()
    assert approvals.read_secret_file(token_key(workspace), "token signing") == TOKEN_SECRET


# The cross-argument settings rules.


def test_the_settings_require_a_state_directory_and_an_origin(workspace: Path) -> None:
    with pytest.raises(InvalidArgument, match="state directory"):
        make_settings(workspace, state_directory="")
    with pytest.raises(InvalidArgument, match="Origin"):
        make_settings(workspace, origins=())


def test_a_nonpositive_rate_is_refused(workspace: Path) -> None:
    for name in (
        "per_minute",
        "grant_per_client_per_minute",
        "image_grant_per_client_per_minute",
        "image_max_outstanding_grants_per_client",
    ):
        with pytest.raises(InvalidArgument, match="positive integer"):
            make_settings(workspace, **{name: 0})


def test_a_lifetime_outside_the_admitted_range_is_refused(workspace: Path) -> None:
    for lifetime in (59, 3601):
        with pytest.raises(InvalidArgument, match=r"\[60, 3600\]"):
            make_settings(workspace, lifetime=lifetime)


def test_the_lan_name_requires_the_exposure_it_widens(workspace: Path) -> None:
    with pytest.raises(InvalidArgument, match="exposure literal"):
        make_settings(workspace, exposure_name=EXPOSED_NAME)


def test_the_open_opt_in_requires_the_exposure_it_opens(workspace: Path) -> None:
    with pytest.raises(InvalidArgument, match="exposure literal"):
        make_settings(workspace, open_lan=True)


def test_exposed_name_admits_only_one_local_label() -> None:
    """The LAN name is exactly one lowercase RFC 1123 label under .local.

    A bare hostname, a public domain, and a second label under .local each
    register in the ordinary resolver, so a name an attacker controls there
    would resolve to this gateway under DNS rebinding were any admitted; an
    uppercase letter and a trailing dot name the same resolvable form under a
    different spelling. A single label carries no dot, so `123.local` names no
    four-octet IPv4 literal and is admitted.
    """
    assert approvals.exposed_name("") == ""
    assert approvals.exposed_name("qwen-test.local") == "qwen-test.local"
    assert approvals.exposed_name("123.local") == "123.local"
    for refused in (
        "qwen-test",
        "attacker.example.com",
        "QWEN-Test.LOCAL",
        "qwen-test.local.",
        "a.b.local",
        "192.168.1.5",
        "localhost",
    ):
        with pytest.raises(InvalidArgument):
            approvals.exposed_name(refused)


def test_exposed_host_admits_a_routable_literal_alone() -> None:
    assert approvals.exposed_host("") == ""
    assert approvals.exposed_host(EXPOSED_ADDRESS) == EXPOSED_ADDRESS
    assert approvals.exposed_host("127.0.0.2") == "127.0.0.2"
    for refused in ("127.0.0.1", "0.0.0.0", "::1", "qwen-test.local", "192.0.2"):  # noqa: S104
        with pytest.raises(InvalidArgument):
            approvals.exposed_host(refused)


# The Host set, which is the first gate and spends no bucket unit.


def test_a_host_header_naming_a_resolved_name_is_refused(workspace: Path) -> None:
    service = make_service(workspace)
    status, payload, _ = post_grant(service, search_payload(), host="rebind.example.net:8080")
    assert status == 403
    assert "no admitted literal" in payload["error"]


def test_the_exposure_admits_its_literal_and_refuses_every_other_host(
    workspace: Path,
) -> None:
    service = make_service(workspace, admit_every_session, exposure=EXPOSED_ADDRESS)
    for host, expected in (
        ("127.0.0.1:8080", 200),
        (f"{EXPOSED_ADDRESS}:8080", 200),
        ("198.51.100.7:8080", 403),
        ("rebind.example.net:8080", 403),
    ):
        status, _, _ = post_grant(service, search_payload(), host=host)
        assert status == expected, host


def test_the_exposure_name_joins_the_admitted_host_set(workspace: Path) -> None:
    """Equality against a closed set is what refuses every near-miss form.

    A prefix or suffix comparison would admit a name carrying the admitted one
    as a sub-label, which is exactly the rebinding the closed set exists to
    refuse.
    """
    service = make_service(
        workspace,
        admit_every_session,
        exposure=EXPOSED_ADDRESS,
        exposure_name=EXPOSED_NAME,
        origins=(NAME_ORIGIN,),
    )
    for host, expected in (
        ("127.0.0.1:8080", 200),
        (f"{EXPOSED_ADDRESS}:8080", 200),
        (f"{EXPOSED_NAME}:8080", 200),
        ("QWEN-TEST.LOCAL:8080", 200),
        ("rebind.example.net:8080", 403),
        (f"evil-{EXPOSED_NAME}:8080", 403),
        (f"{EXPOSED_NAME}.evil.example:8080", 403),
        (f"sub.{EXPOSED_NAME}:8080", 403),
        (f"x{EXPOSED_NAME}:8080", 403),
    ):
        status, _, _ = post_grant(service, search_payload(), host=host, origin=NAME_ORIGIN)
        assert status == expected, host


def test_a_bracketed_ipv6_host_reads_the_literal_inside_the_brackets() -> None:
    admitted = approvals.admitted_hosts()
    assert approvals.host_header_names("[::1]:8080", admitted) == "::1"
    assert approvals.host_header_names("[::1", admitted) == ""
    assert approvals.host_header_names("", admitted) == ""


# The session secret and the Origin allowlist.


def test_a_grant_request_without_the_session_secret_is_refused(workspace: Path) -> None:
    service = make_service(workspace)
    for secret in (None, "", "a-secret-this-launch-never-wrote"):
        request = build_request(
            "POST", approvals.GRANT_PATH, payload=search_payload(), secret=secret
        )
        response = call(service, request)
        payload = body_of(response)
        assert response.status == 403
        assert approvals.SESSION_HEADER in payload["error"]
        assert "authorization" not in payload


def test_a_stale_session_refusal_has_an_explicit_retry_code(workspace: Path) -> None:
    service = make_service(workspace)
    status, payload, _ = post_grant(
        service,
        search_payload(),
        secret="a-secret-this-launch-never-wrote",  # noqa: S106 -- the refusal under test
    )
    assert status == 403
    assert payload["code"] == approvals.STALE_SESSION_SECRET_CODE


def test_a_grant_request_from_a_foreign_origin_is_refused(workspace: Path) -> None:
    """The secret alone buys nothing from a page the launch did not name.

    An opaque origin -- a sandboxed iframe, a data: URL, a file: page -- sends
    the literal string "null" rather than omitting the header, and it names no
    page this launch served.
    """
    service = make_service(workspace)
    for origin in ("http://localhost:8080", None, "null"):
        status, payload, _ = post_grant(service, search_payload(), origin=origin)
        assert status == 403
        assert "Origin" in payload["error"]
        assert "authorization" not in payload


def test_the_session_route_requires_origin_and_the_gateway_session(workspace: Path) -> None:
    service = make_service(workspace, admit_header_session)
    for origin, extra in (
        (None, None),
        ("https://evil.example.net", {"x-test-session": "admitted"}),
        (ORIGIN, None),
    ):
        request = build_request(
            "GET", approvals.SESSION_PATH, origin=origin, extra_headers=extra, secret=""
        )
        response = call(service, request)
        assert response.status == 403
        assert service.session_secret not in response.body.decode("utf-8")


def test_the_session_route_releases_the_secret_to_an_admitted_page(workspace: Path) -> None:
    service = make_service(workspace, admit_header_session)
    request = build_request(
        "GET",
        approvals.SESSION_PATH,
        origin=ORIGIN,
        extra_headers={"x-test-session": "admitted"},
        secret="",
    )
    response = call(service, request)
    assert response.status == 200
    assert body_of(response)["session_secret"] == service.session_secret
    assert response.headers["access-control-allow-origin"] == ORIGIN
    assert "access-control-allow-credentials" not in response.headers


# The gateway session, which replaces the predecessor's Web UI bearer.


def test_the_loopback_default_signs_a_grant_carrying_no_session(workspace: Path) -> None:
    """A loopback launch reads no credential; the refusing default is inert.

    The predecessor called `require_api_key` on a signing route only under the
    exposure opt-in, so this position is the same one and an unexposed launch
    signs against the Host set, the Origin allowlist, and the session secret.
    """
    service = make_service(workspace)
    status, payload, _ = post_grant(service, search_payload())
    assert status == 200
    assert payload["authorization"]


def test_the_exposure_requires_the_session_on_both_signing_routes(workspace: Path) -> None:
    service = make_service(
        workspace,
        admit_header_session,
        exposure=EXPOSED_ADDRESS,
        image_profile="image-fixture-a",
    )
    host = f"{EXPOSED_ADDRESS}:8080"
    for path, payload in (
        (approvals.GRANT_PATH, search_payload()),
        (approvals.IMAGE_GRANT_PATH, image_payload()),
    ):
        request = build_request("POST", path, service=service, payload=payload, host=host)
        response = call(service, request)
        assert response.status == 403
        assert "gateway session" in body_of(response)["error"]
        assert "authorization" not in body_of(response)
        admitted = build_request(
            "POST",
            path,
            service=service,
            payload=payload,
            host=host,
            extra_headers={"x-test-session": "admitted"},
        )
        answer = call(service, admitted)
        assert answer.status == 200, answer.body
        assert body_of(answer)["authorization"]


def test_the_exposure_session_check_precedes_the_shared_bucket(workspace: Path) -> None:
    """An unauthenticated peer cannot exhaust the bucket a session holder needs.

    Five sessionless requests each fail at the session check ahead of
    `ledger.consume`, so none spends the two-unit aggregate bucket and a
    caller that then presents a session still clears both of its own units.
    """
    service = make_service(workspace, admit_header_session, exposure=EXPOSED_ADDRESS, per_minute=2)
    host = f"{EXPOSED_ADDRESS}:8080"
    for _ in range(5):
        status, payload, _ = post_grant(service, search_payload(), host=host)
        assert status == 403
        assert "gateway session" in payload["error"]
    admitted = {"x-test-session": "admitted"}
    for _ in range(2):
        status, _, _ = post_grant(service, search_payload(), host=host, extra_headers=admitted)
        assert status == 200
    status, payload, _ = post_grant(service, search_payload(), host=host, extra_headers=admitted)
    assert status == 429
    assert "authorize-minute" in payload["error"]


def test_the_open_opt_in_signs_without_a_session_and_keeps_the_host_set(
    workspace: Path,
) -> None:
    """The session goes; the Host set, the Origin, and the secret stay."""
    service = make_service(
        workspace,
        exposure=EXPOSED_ADDRESS,
        exposure_name=EXPOSED_NAME,
        open_lan=True,
        origins=(NAME_ORIGIN,),
    )
    for host, expected in (
        (f"{EXPOSED_ADDRESS}:8080", 200),
        (f"{EXPOSED_NAME}:8080", 200),
        ("rebind.example.net:8080", 403),
    ):
        status, _, _ = post_grant(service, search_payload(), host=host, origin=NAME_ORIGIN)
        assert status == expected, host
    status, payload, _ = post_grant(
        service,
        search_payload(),
        host=f"{EXPOSED_NAME}:8080",
        origin=NAME_ORIGIN,
        secret="a-stale-secret",  # noqa: S106 -- the refusal under test
    )
    assert status == 403
    assert payload["code"] == approvals.STALE_SESSION_SECRET_CODE
    request = build_request(
        "GET", approvals.SESSION_PATH, origin="http://attacker.example", secret=""
    )
    assert call(service, request).status == 403


# The request body, refused before a key is read.


def test_a_malformed_field_is_refused(workspace: Path) -> None:
    service = make_service(workspace)
    for payload in (
        {"query": 5, "profile_id": "default"},
        {"query": "q", "profile_id": "default", "max_results": "many"},
        {"query": "q", "profile_id": "default", "include_domains": "example.org"},
        {"query": "q", "profile_id": "default", "max_age_hours": "soon"},
    ):
        status, body, _ = post_grant(service, payload)
        assert status == 400, payload
        assert "authorization" not in body


def test_a_request_naming_no_profile_id_is_refused(workspace: Path) -> None:
    """The grant binds the profile the MCP child verifies it against.

    A request naming no profile is refused before a token is signed rather
    than signed against this service's own launch profile silently.
    """
    service = make_service(workspace)
    for payload in (
        {"query": "raven2 vulkan decode"},
        {"query": "raven2 vulkan decode", "profile_id": ""},
        {"query": "raven2 vulkan decode", "profile_id": 7},
    ):
        status, body, _ = post_grant(service, payload)
        assert status == 400
        assert "profile_id" in body["error"]
        assert "authorization" not in body


def test_a_request_naming_another_profile_is_refused(workspace: Path) -> None:
    service = make_service(workspace, profile="fast-text")
    status, body, _ = post_grant(service, search_payload(profile_id="vision"))
    assert status == 400
    assert "fast-text" in body["error"]
    assert "vision" in body["error"]
    assert "authorization" not in body
    assert "invalid_argument" in [row[8] for row in audit_rows(workspace)]


def test_an_inverted_publication_window_is_refused_before_signing(workspace: Path) -> None:
    service = make_service(workspace)
    status, body, _ = post_grant(
        service,
        search_payload(published_after="2026-08-01", published_before="2026-07-31"),
    )
    assert status == 400
    assert "published_after falls after published_before" in body["error"]
    assert "authorization" not in body


def test_a_body_past_the_byte_cap_is_refused(workspace: Path) -> None:
    service = make_service(workspace)
    oversized = b"{" + b"a" * (approvals.REQUEST_BODY_BYTE_CAP + 1) + b"}"
    request = build_request("POST", approvals.GRANT_PATH, service=service, body=oversized)
    response = call(service, request)
    assert response.status == 400
    assert "byte cap" in body_of(response)["error"]


def test_a_body_that_is_not_json_is_refused(workspace: Path) -> None:
    service = make_service(workspace)
    request = build_request("POST", approvals.GRANT_PATH, service=service, body=b"{not json")
    response = call(service, request)
    assert response.status == 400
    assert "UTF-8 JSON" in body_of(response)["error"]


# The two rate buckets and the audit trail.


def test_the_aggregate_bucket_bounds_the_approval_route(workspace: Path) -> None:
    service = make_service(workspace, per_minute=2)
    for _ in range(2):
        status, _, _ = post_grant(service, search_payload())
        assert status == 200
    for _ in range(5):
        status, payload, response = post_grant(service, search_payload())
        assert status == 429
        assert "authorize-minute" in payload["error"]
        assert 0 <= int(response.headers["retry-after"]) <= 60
    statuses = [row[8] for row in audit_rows(workspace)]
    assert statuses.count("rate_limited") == 1


def test_a_per_client_bucket_bounds_one_address_beneath_the_aggregate(
    workspace: Path,
) -> None:
    """A 429 here can come only from the per-client bucket, and names it."""
    service = make_service(workspace, per_minute=100, grant_per_client_per_minute=2)
    for _ in range(2):
        status, _, _ = post_grant(service, search_payload())
        assert status == 200
    status, payload, response = post_grant(service, search_payload())
    assert status == 429
    assert "grant-client-minute:127.0.0.1" in payload["error"]
    assert "retry-after" in response.headers
    assert [row[8] for row in audit_rows(workspace)].count("rate_limited") == 1


def test_the_per_client_bucket_is_keyed_by_the_connection_address(workspace: Path) -> None:
    service = make_service(workspace, per_minute=100, grant_per_client_per_minute=1)
    assert post_grant(service, search_payload())[0] == 200
    assert post_grant(service, search_payload())[0] == 429
    assert post_grant(service, search_payload(), client="127.0.0.5")[0] == 200


def test_a_bad_session_secret_spends_the_same_bucket(workspace: Path) -> None:
    """A caller that never presents a real session cannot outrun the meter."""
    service = make_service(workspace, per_minute=2)
    stale = "a-secret-this-launch-never-wrote"
    for _ in range(2):
        status, payload, _ = post_grant(service, search_payload(), secret=stale)
        assert status == 403
        assert approvals.SESSION_HEADER in payload["error"]
    status, payload, _ = post_grant(service, search_payload(), secret=stale)
    assert status == 429
    assert "authorize-minute" in payload["error"]
    statuses = [row[8] for row in audit_rows(workspace)]
    assert statuses.count("authorization_denied") == 2
    assert statuses.count("rate_limited") == 1
    assert post_grant(service, search_payload())[0] == 429


def test_the_audit_trail_carries_the_digest_and_no_secret(workspace: Path) -> None:
    service = make_service(workspace)
    status, payload, _ = post_grant(
        service,
        search_payload(
            max_results=4,
            include_domains=["example.org"],
            exclude_domains=["evil.example.net"],
        ),
    )
    assert status == 200
    token = payload["authorization"]
    post_grant(service, {"query": 5, "profile_id": "default"})
    rows = audit_rows(workspace)
    assert [row[1] for row in rows] == ["authorize", "authorize"]
    assert sorted(row[8] for row in rows) == ["invalid_argument", "success"]
    issued = next(row for row in rows if row[8] == "success")
    assert issued[2] == hashlib.sha256(b"raven2 vulkan decode").hexdigest()
    assert issued[3] == "example.org,-evil.example.net"
    assert issued[4] == 4
    flattened = "\n".join(str(field) for row in rows for field in row)
    assert TOKEN_SECRET not in flattened
    assert token not in flattened
    assert "raven2 vulkan decode" not in flattened
    assert service.session_secret not in flattened


def test_an_image_refusal_records_its_own_operation(workspace: Path) -> None:
    service = make_service(workspace, image_profile="image-fixture-a")
    status, body, _ = post_image_grant(service, image_payload(image_profile="image-other"))
    assert status == 400
    assert "image profile" in body["error"]
    assert [row[1] for row in audit_rows(workspace)] == ["authorize-image"]


def test_concurrent_grants_use_independent_ledger_connections(workspace: Path) -> None:
    request_count = 4
    service = make_service(workspace, per_minute=request_count)

    def issue(index: int) -> int:
        return post_grant(service, search_payload(query=f"raven2 vulkan decode {index}"))[0]

    with ThreadPoolExecutor(max_workers=request_count) as executor:
        statuses = list(executor.map(issue, range(request_count)))
    assert statuses == [200] * request_count
    assert [row[8] for row in audit_rows(workspace)].count("success") == request_count


# The image lane: two profiles, and one outstanding grant per client.


def test_image_grant_binds_both_profiles(workspace: Path) -> None:
    """The claim joins two profiles, so two settings bind them.

    `enforce_image_authorization` on the MCP child compares the claim's
    `language_profile` against `QWEN_IMAGE_LANGUAGE_PROFILE` and its
    `image_profile` against `QWEN_IMAGE_PROFILE`. One setting for both would
    sign a claim naming the language profile twice, which the child then
    refuses, so no grant could ever be spent.
    """
    service = make_service(workspace, image_profile="image-fixture-a")
    status, body, _ = post_image_grant(service, image_payload())
    assert status == 200, body
    assert body["authorization"]
    for overrides, named in (
        ({"image_profile": "image-other"}, "image profile"),
        ({"language_profile": "web-other"}, "language profile"),
    ):
        status, body, _ = post_image_grant(service, image_payload(**overrides))
        assert status == 400, body
        assert named in body["error"]


def test_image_grant_refused_where_no_lane_is_armed(workspace: Path) -> None:
    service = make_service(workspace)
    status, body, _ = post_image_grant(service, image_payload())
    assert status == 400
    assert "no image profile" in body["error"]


def test_an_unknown_image_field_is_refused_by_name(workspace: Path) -> None:
    service = make_service(workspace, image_profile="image-fixture-a")
    status, body, _ = post_image_grant(service, {**image_payload(), "prompt": "a fox"})
    assert status == 400
    assert "prompt" in body["error"]


def test_a_boolean_seed_is_refused(workspace: Path) -> None:
    """`bool` subclasses `int`, so `true` would reach the claim as seed 1."""
    service = make_service(workspace, image_profile="image-fixture-a")
    status, body, _ = post_image_grant(service, image_payload(seed=True))
    assert status == 400
    assert "seed must be an integer" in body["error"]


def test_a_seed_of_zero_is_admitted(workspace: Path) -> None:
    service = make_service(workspace, image_profile="image-fixture-a")
    assert post_image_grant(service, image_payload(seed=0))[0] == 200


def test_a_max_dimension_off_the_multiple_is_refused(workspace: Path) -> None:
    service = make_service(workspace, image_profile="image-fixture-a")
    status, body, _ = post_image_grant(service, image_payload(max_dimension=500))
    assert status == 400
    assert "multiple of 64" in body["error"]


def test_a_second_outstanding_image_grant_is_refused_until_the_first_expires(
    workspace: Path,
) -> None:
    """The image service runs one job at a time with no queue.

    A second unexpired grant from one client buys that client a standing
    ticket ahead of every other peer's next job, so it is refused rather than
    signed; the refusal reads distinctly from the per-minute buckets, which
    stay wide open here.
    """
    service = make_service(
        workspace,
        image_profile="image-fixture-a",
        image_max_outstanding_grants_per_client=1,
        lifetime=60,
    )
    assert post_image_grant(service, image_payload())[0] == 200
    status, payload, response = post_image_grant(service, image_payload())
    assert status == 429
    assert "outstanding" in payload["error"]
    assert 0 < int(response.headers["retry-after"]) <= 60


def test_a_refused_image_grant_returns_its_reservation(workspace: Path) -> None:
    """A reservation assumes the signature succeeds; a refusal gives it back."""
    service = make_service(
        workspace,
        image_profile="image-fixture-a",
        image_max_outstanding_grants_per_client=1,
        lifetime=60,
    )
    assert post_image_grant(service, image_payload(seed=True))[0] == 400
    assert post_image_grant(service, image_payload())[0] == 200


def test_concurrent_outstanding_image_grants_admit_exactly_the_limit(
    workspace: Path,
) -> None:
    """Two simultaneous requests cannot both pass a limit of one.

    `OutstandingImageGrants.reserve` holds one lock across the read and the
    append, so two handler threads racing this check cannot both observe zero
    outstanding grants before either records its own.
    """
    service = make_service(
        workspace,
        image_profile="image-fixture-a",
        image_max_outstanding_grants_per_client=1,
        lifetime=60,
    )
    barrier = threading.Barrier(8)

    def attempt(_index: int) -> int:
        barrier.wait()
        return post_image_grant(service, image_payload())[0]

    with ThreadPoolExecutor(max_workers=8) as executor:
        statuses = list(executor.map(attempt, range(8)))
    assert statuses.count(200) == 1, statuses
    assert statuses.count(429) == 7, statuses


# The session secret file.


def test_the_secret_file_is_private_and_disarms(workspace: Path) -> None:
    service = make_service(workspace)
    path = state_directory(workspace) / approvals.SESSION_SECRET_FILE_NAME
    assert path.stat().st_mode & 0o777 == 0o600
    assert path.read_text(encoding="ascii").strip() == service.session_secret
    service.disarm_session_secret()
    assert not path.exists()


def test_arming_twice_replaces_the_predecessor(workspace: Path) -> None:
    service = make_service(workspace)
    first = service.session_secret
    second, path = service.arm_session_secret()
    assert first != second
    assert path.read_text(encoding="ascii").strip() == second
    assert post_grant(service, search_payload(), secret=first)[0] == 403


# The ledger the MCP child shares.


def test_the_ledger_journal_mode_stays_delete(workspace: Path) -> None:
    """WAL would leave page images in a sidecar the retention rule excludes.

    `journal_mode` lives in the database header rather than in a connection,
    so a conversion here would carry into the MCP child, whose own
    `PRAGMA journal_mode = DELETE` returns the current mode rather than
    changing it while a second connection is open.
    """
    ledger = Ledger(state_directory(workspace))
    try:
        mode = ledger.connection.execute("PRAGMA journal_mode").fetchone()[0]
        secure = ledger.connection.execute("PRAGMA secure_delete").fetchone()[0]
    finally:
        ledger.close()
    assert mode == "delete"
    assert secure == 1


def test_the_ledger_schema_matches_the_mcp_server(
    workspace: Path, tmp_path: Path, mcp_server: ModuleType
) -> None:
    """One file, one schema: both writers declare the same tables and columns."""
    theirs_directory = tmp_path / "theirs"
    theirs_directory.mkdir(mode=0o700)
    ours = Ledger(state_directory(workspace))
    theirs = mcp_server.Ledger(str(theirs_directory))
    try:
        assert ours.path.name == mcp_server.LEDGER_FILE_NAME

        def schema(connection: sqlite3.Connection) -> dict[str, list[str]]:
            tables = sorted(
                str(row[0])
                for row in connection.execute("SELECT name FROM sqlite_master WHERE type = 'table'")
                if not str(row[0]).startswith("sqlite_")
            )
            return {
                table: [
                    str(column[1]) for column in connection.execute(f"PRAGMA table_info({table})")
                ]
                for table in tables
            }

        assert schema(ours.connection) == schema(theirs.connection)
    finally:
        ours.close()
        theirs.close()


def test_a_ledger_state_directory_outside_its_mode_is_refused(tmp_path: Path) -> None:
    loose = tmp_path / "loose"
    loose.mkdir(mode=0o755)
    with pytest.raises(InvalidArgument, match="mode 0755"):
        Ledger(loose)


def test_a_symlinked_state_directory_is_refused(tmp_path: Path) -> None:
    real = tmp_path / "real"
    real.mkdir(mode=0o700)
    link = tmp_path / "link"
    link.symlink_to(real, target_is_directory=True)
    with pytest.raises(InvalidArgument, match="symlink"):
        Ledger(link)


def test_a_bucket_refusal_names_the_bucket_and_the_window(workspace: Path) -> None:
    ledger = Ledger(state_directory(workspace))
    try:
        now = time.time()
        ledger.consume("probe-minute", 60, 1, now)
        with pytest.raises(RateLimited, match="probe-minute rate limit of 1 per 60 seconds"):
            ledger.consume("probe-minute", 60, 1, now)
    finally:
        ledger.close()


# The encoder, pinned against itself before the shell tree reads it.


def test_a_signed_claim_verifies_under_its_own_context() -> None:
    """`sign_claim` and `verify_claim` agree on one byte string.

    The round trip pins the encoder independently of the shell tree: a claim
    carrying a non-ASCII value, a null, and a nested list survives whole, and
    the same token refuses under a second context because the HMAC covers the
    context string beside the payload.
    """
    claim: dict[str, object] = {
        "query": "raven2 Vulkan decode uberandert",
        "include_domains": ["b.example", "example.org"],
        "max_age_hours": None,
        "expiry": int(time.time()) + 60,
    }
    token = approvals.sign_claim(TOKEN_SECRET, "search-authorization", claim)
    assert (
        approvals.verify_claim(TOKEN_SECRET, "search-authorization", token, time.time(), "grant")
        == claim
    )
    with pytest.raises(approvals.AuthorizationDenied, match="signature fails verification"):
        approvals.verify_claim(TOKEN_SECRET, "qwen-image-generate-v1", token, time.time(), "grant")


def test_a_tampered_payload_fails_the_signature(workspace: Path) -> None:
    del workspace
    token = approvals.sign_claim(
        TOKEN_SECRET, "search-authorization", {"expiry": int(time.time()) + 60}
    )
    payload, signature = token.split(".")
    flipped = ("A" if payload[0] != "A" else "B") + payload[1:]
    with pytest.raises(approvals.AuthorizationDenied, match="signature fails verification"):
        approvals.verify_claim(
            TOKEN_SECRET, "search-authorization", f"{flipped}.{signature}", time.time(), "grant"
        )
    with pytest.raises(approvals.AuthorizationDenied, match="malformed"):
        approvals.verify_claim(TOKEN_SECRET, "search-authorization", payload, time.time(), "grant")


def test_a_claim_past_its_term_reads_as_expired() -> None:
    token = approvals.sign_claim(
        TOKEN_SECRET, "search-authorization", {"expiry": int(time.time()) - 1}
    )
    with pytest.raises(approvals.ExpiredResult, match="has expired"):
        approvals.verify_claim(TOKEN_SECRET, "search-authorization", token, time.time(), "grant")


# The cross-checks against the shell tree's own modules.


def test_a_minted_search_grant_verifies_through_the_mcp_server(
    workspace: Path, mcp_server: ModuleType
) -> None:
    """The claim bytes agree field for field with the serving path.

    The inputs exercise the normalization rather than the happy path: a
    non-ASCII query the JSON encoder escapes under `ensure_ascii`, a domain
    list needing case folding, root-dot stripping, and sorting at once, a date
    in an extended ISO form `date.fromisoformat` reformats, and an absent
    `max_age_hours` that stays null rather than becoming 0.
    """
    service = make_service(workspace, provider="fake")
    status, payload, _ = post_grant(
        service,
        search_payload(
            query="  raven2 Vulkan decode uberändert  ",
            include_domains=["Example.ORG.", "b.example"],
            exclude_domains=["Evil.Example.NET"],
            published_after="2026-01-05",
            published_before="2026-08-31",
            max_results=4,
        ),
    )
    assert status == 200, payload
    token = payload["authorization"]
    claim = mcp_server.verify_claim(
        TOKEN_SECRET, mcp_server.AUTHORIZATION_CLAIM_CONTEXT, token, time.time(), "authorization"
    )
    assert set(claim) == {
        "query",
        "include_domains",
        "exclude_domains",
        "published_after",
        "published_before",
        "max_age_hours",
        "max_results",
        "expiry",
        "grant_id",
        "provider",
        "profile_id",
        "issued_at",
        "max_uses",
    }
    assert claim["query"] == "raven2 Vulkan decode uberändert"
    assert claim["include_domains"] == ["b.example", "example.org"]
    assert claim["exclude_domains"] == ["evil.example.net"]
    assert claim["published_after"] == "2026-01-05"
    assert claim["published_before"] == "2026-08-31"
    assert claim["max_age_hours"] is None
    assert claim["max_results"] == 4
    assert claim["provider"] == "fake"
    assert claim["profile_id"] == "default"
    assert claim["max_uses"] == mcp_server.GRANT_MAX_USES
    assert mcp_server.GRANT_ID_PATTERN.match(str(claim["grant_id"]))
    assert claim["expiry"] - claim["issued_at"] == service.settings.lifetime
    # The serving path rebuilds the claim from the arguments it receives and
    # compares field by field, so the rebuilt form is the real cross-check.
    rebuilt = mcp_server.authorization_claim(
        "raven2 Vulkan decode uberändert",
        ["example.org", "b.example"],
        ["evil.example.net"],
        "2026-01-05",
        "2026-08-31",
        None,
        4,
        claim["expiry"],
    )
    for field_name, value in rebuilt.items():
        assert claim[field_name] == value, field_name


def test_an_extended_iso_date_reaches_the_claim_reformatted(
    workspace: Path, mcp_server: ModuleType
) -> None:
    """`date.fromisoformat` admits every extended form and one spelling reaches the claim."""
    service = make_service(workspace)
    status, payload, _ = post_grant(service, search_payload(published_after="20260105"))
    assert status == 200, payload
    claim = mcp_server.verify_claim(
        TOKEN_SECRET,
        mcp_server.AUTHORIZATION_CLAIM_CONTEXT,
        payload["authorization"],
        time.time(),
        "authorization",
    )
    assert claim["published_after"] == "2026-01-05"


def test_a_minted_grant_spends_once_in_the_shared_ledger(
    workspace: Path, mcp_server: ModuleType
) -> None:
    """The child's own ledger spends the use, and this package's refuses the replay.

    Both writers open one file under one primary key, so the single use
    survives the process boundary the MCP child crosses on every spawn.
    """
    service = make_service(workspace)
    status, payload, _ = post_grant(service, search_payload())
    assert status == 200
    claim = mcp_server.verify_claim(
        TOKEN_SECRET,
        mcp_server.AUTHORIZATION_CLAIM_CONTEXT,
        payload["authorization"],
        time.time(),
        "authorization",
    )
    theirs = mcp_server.Ledger(str(state_directory(workspace)))
    try:
        theirs.consume_grant(claim["grant_id"], "default", "fake", claim["expiry"], time.time())
    finally:
        theirs.close()
    ours = Ledger(state_directory(workspace))
    try:
        with pytest.raises(GrantReplayed, match="spent"):
            ours.consume_grant(
                str(claim["grant_id"]),
                "default",
                "fake",
                expiry=float(claim["expiry"]),
                now=time.time(),
            )
    finally:
        ours.close()


def test_a_minted_image_grant_verifies_through_image_grant(
    workspace: Path, mcp_image_grant: ModuleType
) -> None:
    """The generation claim agrees with the module both sides build it from."""
    service = make_service(workspace, image_profile="image-fixture-a")
    status, payload, _ = post_image_grant(
        service, image_payload(aspect="1024:768", max_dimension=1024, seed=0)
    )
    assert status == 200, payload
    claim = mcp_image_grant.verify_image_grant(TOKEN_SECRET, payload["authorization"], time.time())
    assert set(claim) == {
        "language_profile",
        "image_profile",
        "prompt_hash",
        "negative_prompt_hash",
        "seed",
        "aspect",
        "max_dimension",
        "max_steps",
        "conversation_generation",
        "issued_at",
        "expiry",
        "grant_id",
        "max_uses",
    }
    # 1024:768 reduces to 4:3, and the execution path reduces the emitted
    # width and height the same way before comparing.
    assert claim["aspect"] == mcp_image_grant.canonical_aspect(1024, 768) == "4:3"
    assert claim["seed"] == 0
    assert claim["max_uses"] == mcp_image_grant.IMAGE_GRANT_MAX_USES
    rebuilt = mcp_image_grant.image_claim(
        {
            "language_profile": "default",
            "image_profile": "image-fixture-a",
            "prompt_hash": hashlib.sha256(b"a fox").hexdigest(),
            "negative_prompt_hash": hashlib.sha256(b"").hexdigest(),
            "seed": 0,
            "aspect": "4:3",
            "max_dimension": 1024,
            "max_steps": 4,
            "conversation_generation": 0,
        },
        claim["issued_at"],
        claim["expiry"],
        claim["grant_id"],
    )
    assert claim == rebuilt


def test_an_image_grant_admits_the_generation_the_dialog_approved(
    workspace: Path, mcp_image_grant: ModuleType
) -> None:
    """`enforce_image_authorization` runs the claim against the emitted call."""
    service = make_service(workspace, image_profile="image-fixture-a")
    status, payload, _ = post_image_grant(service, image_payload(max_dimension=512, max_steps=4))
    assert status == 200, payload
    claim = mcp_image_grant.verify_image_grant(TOKEN_SECRET, payload["authorization"], time.time())
    arguments = {
        "profile_id": "image-fixture-a",
        "prompt": "a fox",
        "negative_prompt": "",
        "seed": 7,
        "width": 512,
        "height": 512,
        "steps": 4,
    }
    mcp_image_grant.enforce_image_authorization(claim, "default", "image-fixture-a", arguments)
    rewritten = {**arguments, "prompt": "a fox in a hat"}
    with pytest.raises(Exception, match="prompt differs"):
        mcp_image_grant.enforce_image_authorization(claim, "default", "image-fixture-a", rewritten)


def test_a_search_grant_never_verifies_as_a_generation_grant(
    workspace: Path, mcp_image_grant: ModuleType, mcp_server: ModuleType
) -> None:
    """`sign_claim` covers the context string, so neither token reads as the other."""
    service = make_service(workspace, image_profile="image-fixture-a")
    search_token = post_grant(service, search_payload())[1]["authorization"]
    image_token = post_image_grant(service, image_payload())[1]["authorization"]
    with pytest.raises(Exception, match="signature fails verification"):
        mcp_image_grant.verify_image_grant(TOKEN_SECRET, search_token, time.time())
    with pytest.raises(Exception, match="signature fails verification"):
        mcp_server.verify_claim(
            TOKEN_SECRET,
            mcp_server.AUTHORIZATION_CLAIM_CONTEXT,
            image_token,
            time.time(),
            "authorization",
        )


def test_a_tampered_grant_fails_verification(workspace: Path, mcp_server: ModuleType) -> None:
    service = make_service(workspace)
    token = post_grant(service, search_payload())[1]["authorization"]
    payload_part, signature = token.split(".")
    tampered = json.loads(approvals.base64url_decode(payload_part).decode("utf-8"))
    tampered["max_results"] = 10
    forged = (
        approvals.base64url_encode(json.dumps(tampered, sort_keys=True).encode()) + "." + signature
    )
    with pytest.raises(Exception, match="signature fails verification"):
        mcp_server.verify_claim(
            TOKEN_SECRET,
            mcp_server.AUTHORIZATION_CLAIM_CONTEXT,
            forged,
            time.time(),
            "authorization",
        )


# The tool registry.


def test_the_registry_lists_every_tool_with_its_executor() -> None:
    payload = registry.as_payload()
    tools = payload["tools"]
    assert isinstance(tools, list)
    identifiers = [entry["tool_id"] for entry in tools]
    assert identifiers == [
        "web_search",
        "read_url",
        "wikipedia_profile",
        "image_interpretation",
        "image_generation",
        "image_review",
        "documents",
        "calculator",
        "local_file_search",
        "artifact_export",
        "code_tools",
    ]
    assert len({entry["tool_id"] for entry in tools}) == len(tools)
    for entry in tools:
        assert entry["approval"] in ("user-explicit", "model-suggested")
        assert entry["availability"] in ("served", "planned")
        assert entry["execution_path"]
        assert entry["summary"]


def test_every_served_row_names_a_path_this_tree_holds() -> None:
    """A served row states an artifact a reader opens, not a plan."""
    for row in registry.served():
        assert (REPOSITORY_ROOT / row.execution_path).exists(), row.tool_id


def test_a_network_or_device_reaching_tool_takes_an_explicit_approval() -> None:
    for tool_id in ("web_search", "wikipedia_profile", "image_generation"):
        assert registry.entry(tool_id).approval is registry.Approval.USER_EXPLICIT
    for tool_id in ("read_url", "image_review"):
        assert registry.entry(tool_id).approval is registry.Approval.MODEL_SUGGESTED


def test_the_local_rows_stay_planned_under_the_read_only_boundary() -> None:
    """The appliance launches without --tools, so no preset serves a local row."""
    for tool_id in ("local_file_search", "code_tools"):
        row = registry.entry(tool_id)
        assert row.availability is registry.Availability.PLANNED
        assert row.approval is registry.Approval.USER_EXPLICIT


def test_the_tools_route_answers_the_table(workspace: Path) -> None:
    service = make_service(workspace)
    response = call(service, build_request("GET", registry.TOOLS_PATH, secret=""))
    assert response.status == 200
    payload = body_of(response)
    assert payload["schema"] == "qwen.tool-registry"
    assert len(payload["tools"]) == len(registry.TOOL_TABLE)
