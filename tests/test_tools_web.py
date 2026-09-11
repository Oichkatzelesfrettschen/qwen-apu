"""The web executor against a fake SearXNG instance and a fake source host.

Both fixtures bind 127.0.0.1 port zero and stay bound for the arm, so each
port comes from the server object rather than from a bind-then-close that
reserves nothing. The source host is reached by name -- `example.test` -- with
the address resolver injected, which is what lets a loopback fixture stand in
for a public host while `resolve_public_addresses` keeps its own refusal
testable on its own.
"""

from __future__ import annotations

import json
import os
import threading
import time
from collections.abc import Callable, Iterator, Sequence
from contextlib import closing
from http.client import HTTPConnection, HTTPResponse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

from qwen_apu.tools import approvals, registry
from qwen_apu.tools import web as web_tools
from qwen_apu.tools.ledger import Ledger
from qwen_apu.web.app import Gateway, GatewayConfig, RequestRefused
from qwen_apu.web.auth import SESSION_COOKIE, SessionGate
from qwen_apu.web.http import Request

PROFILE = "web-open"
CATEGORY = "qwen-open"
SOURCE_HOST = "example.test"
GROUNDED_SENTENCE = "Raven2 decodes the 2B distill at 9.46 tokens per second."
EXCHANGE_DEADLINE_SECONDS = 20.0

PAGE_HTML = (
    "<html><head><title>Raven2</title><style>p{color:red}</style></head>"
    "<body><script>var hidden = 'script text';</script>"
    f"<p>{GROUNDED_SENTENCE}</p><p>The fabric runs at 933 MHz.</p></body></html>"
)


class _Fake(BaseHTTPRequestHandler):
    """One handler serving both roles, steered by attributes on its server."""

    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: object) -> None:
        """Keep the fixture's request lines out of the test output."""

    def do_GET(self) -> None:  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        plan = self.server.plan  # type: ignore[attr-defined]
        plan["requests"].append(self.path)
        delay = plan.get("delay_seconds", 0.0)
        if delay:
            time.sleep(delay)
        status = int(plan.get("status", 200))
        if status != 200:
            self._send(status, b"the fixture refuses", "text/plain; charset=utf-8")
            return
        body = plan["body"]
        payload = body.encode("utf-8") if isinstance(body, str) else body
        self._send(200, payload, plan.get("content_type", "text/html; charset=utf-8"))

    def _send(self, status: int, payload: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


def _serve(plan: dict[str, object]) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer(("127.0.0.1", 0), _Fake)
    server.plan = plan  # type: ignore[attr-defined]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def _port(server: ThreadingHTTPServer) -> int:
    return int(server.server_address[1])


def _searxng_body(urls: list[str]) -> str:
    return json.dumps(
        {
            "results": [
                {
                    "url": url,
                    "title": f"Raven2 note {index}",
                    "content": "one measured snippet",
                    "engines": ["duckduckgo"],
                    "publishedDate": "2026-09-08",
                }
                for index, url in enumerate(urls)
            ],
            "unresponsive_engines": [["google", "timeout"]],
        }
    )


@pytest.fixture
def source() -> Iterator[ThreadingHTTPServer]:
    server = _serve({"body": PAGE_HTML, "requests": []})
    try:
        yield server
    finally:
        server.shutdown()
        server.server_close()


@pytest.fixture
def searxng(source: ThreadingHTTPServer) -> Iterator[ThreadingHTTPServer]:
    url = f"http://{SOURCE_HOST}:{_port(source)}/note"
    server = _serve(
        {
            "body": _searxng_body([url]),
            "content_type": "application/json",
            "requests": [],
        }
    )
    try:
        yield server
    finally:
        server.shutdown()
        server.server_close()


class Harness:
    """The executor bound to a real ledger directory, the fixtures, and a key."""

    def __init__(self, settings: web_tools.WebToolSettings, state: Path, key: Path) -> None:
        self.settings = settings
        self.state = state
        self.key = key

    def ledger(self) -> Ledger:
        """Open one connection for one caller, as the assembly's closures do."""
        return Ledger(self.state)

    def grant(self, query: str, **overrides: object) -> str:
        fields = {
            "profile_id": PROFILE,
            "query": query,
            "include_domains": (),
            "exclude_domains": (),
            "published_after": "",
            "published_before": "",
            "max_age_hours": None,
            "max_results": 5,
        }
        fields.update(overrides)
        return approvals.issue_search_grant(
            self.key,
            approvals.SearchGrantRequest(**fields),  # type: ignore[arg-type]
            provider="searxng",
            profile=PROFILE,
            lifetime=900,
        )

    def call(self, tool: str, params: dict[str, object]) -> tuple[int, dict[str, object]]:
        request = Request(
            method="POST",
            path=web_tools.TOOLS_PATH,
            query={},
            headers={"content-type": "application/json"},
            body=json.dumps({"tool": tool, "params": params}).encode("utf-8"),
            client_address="127.0.0.1",
        )
        response = web_tools.execute(self.settings, request)
        return response.status, json.loads(response.body.decode("utf-8"))


def _spend_grant(state: Path) -> Callable[[str, float], None]:
    def spend(grant_id: str, expiry: float) -> None:
        with closing(Ledger(state)) as ledger:
            ledger.consume_grant(grant_id, PROFILE, "searxng", expiry=expiry, now=time.time())

    return spend


def _open_search(state: Path) -> Callable[[str, int, float, Sequence[str]], None]:
    def opened(search_id: str, allowance: int, expiry: float, urls: Sequence[str]) -> None:
        with closing(Ledger(state)) as ledger:
            ledger.open_search(
                search_id, PROFILE, "searxng", fetches_allowed=allowance, expiry=expiry, urls=urls
            )

    return opened


def _spend_fetch(state: Path) -> Callable[[str, str], None]:
    def spend(search_id: str, url: str) -> None:
        with closing(Ledger(state)) as ledger:
            ledger.spend_fetch(search_id, url, time.time())

    return spend


def _harness(
    tmp_path: Path,
    searxng: ThreadingHTTPServer,
    source: ThreadingHTTPServer,
    *,
    timeout_seconds: float = 10.0,
    max_fetches: int = 2,
) -> Harness:
    tmp_path.mkdir(parents=True, exist_ok=True)
    key = tmp_path / "web-token.key"
    key.write_text("a key this fixture alone reads\n", encoding="utf-8")
    os.chmod(key, 0o600)
    state = tmp_path / "state"
    state.mkdir(mode=0o700, exist_ok=True)
    source_port = _port(source)

    def resolver(host: str, port: int) -> list[str]:
        """Answer for the fixture's own name, and refuse every other host.

        The fixture stands in for a public source, so the executor's own
        `resolve_public_addresses` is replaced here alone; its refusal of a
        private answer is proved against the real function.
        """
        assert host == SOURCE_HOST and port == source_port
        return ["127.0.0.1"]

    settings = web_tools.WebToolSettings(
        token_key_file=key,
        profile=PROFILE,
        provider="searxng",
        searxng=web_tools.SearxngProvider(
            f"http://127.0.0.1:{_port(searxng)}",
            CATEGORY,
            timeout_seconds=timeout_seconds,
            address_resolver=resolver,
        ),
        max_results=5,
        max_fetches=max_fetches,
        max_chars_per_fetch=12000,
        session_admits=lambda request: True,
        spend_grant=_spend_grant(state),
        open_search=_open_search(state),
        spend_fetch=_spend_fetch(state),
    )
    return Harness(settings, state, key)


@pytest.fixture
def harness(
    tmp_path: Path, searxng: ThreadingHTTPServer, source: ThreadingHTTPServer
) -> Iterator[Harness]:
    built = _harness(tmp_path, searxng, source)
    yield built


def _result_id(text: str) -> str:
    for line in text.splitlines():
        if line.startswith("Result ID: "):
            return line[len("Result ID: ") :]
    raise AssertionError(f"the rendered search carried no Result ID:\n{text}")


# ---------------------------------------------------------------------------
# A search, then a fetch, grounded
# ---------------------------------------------------------------------------


def test_a_search_then_a_fetch_reaches_the_page_the_search_returned(harness: Harness) -> None:
    """The grounded path end to end: one grant, one search, one page.

    The fetched window carries the source's own sentence and none of its
    script or style text, which is what makes the answer grounded rather than
    a restatement of the snippet the instance supplied.
    """
    status, search = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": harness.grant("raven2 decode")},
    )
    assert status == 200
    assert search["outcome"] == "success"
    assert search["state"] == web_tools.STATE_COMPLETE
    text = str(search["text"])
    assert "Trust: untrusted-web-result" in text
    assert f"URL: http://{SOURCE_HOST}:" in text

    status, fetched = harness.call(web_tools.READ_URL_TOOL, {"result_id": _result_id(text)})
    assert status == 200
    assert fetched["state"] == web_tools.STATE_COMPLETE
    window = str(fetched["text"])
    assert GROUNDED_SENTENCE in window
    assert "script text" not in window
    assert "color:red" not in window
    assert window.startswith(web_tools.UNTRUSTED_HEADER)
    assert window.rstrip().endswith("]")
    assert "Possibly Truncated: no" in window


def test_every_answer_carries_the_provenance_a_transcript_names(harness: Harness) -> None:
    """The record states what ran, what it cost, and the digest of what it holds."""
    _, search = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": harness.grant("raven2 decode")},
    )
    provenance = search["provenance"]
    assert isinstance(provenance, dict)
    assert provenance["operation"] == web_tools.SEARCH_TOOL
    assert provenance["query"] == "raven2 decode"
    assert provenance["status"] == "success"
    assert int(provenance["provider_bytes"]) > 0
    assert len(str(provenance["text_sha256"])) == 64
    assert str(provenance["retrieved_at"]).endswith("Z")
    assert provenance["engines_answered"] == "duckduckgo"
    assert provenance["engines_failed"] == "google"

    _, fetched = harness.call(
        web_tools.READ_URL_TOOL, {"result_id": _result_id(str(search["text"]))}
    )
    record = fetched["provenance"]
    assert isinstance(record, dict)
    assert record["operation"] == web_tools.READ_URL_TOOL
    assert str(record["url"]).startswith(f"http://{SOURCE_HOST}:")
    assert int(record["returned_characters"]) > 0
    assert len(str(record["text_sha256"])) == 64


# ---------------------------------------------------------------------------
# Destinations
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "url",
    [
        "http://127.0.0.1/page",
        "http://localhost/page",
        "http://[::1]/page",
        "http://192.168.1.10/page",
        "http://169.254.169.254/latest/meta-data",
        "http://2130706433/page",
        "http://0x7f000001/page",
        "http://user:pass@example.org/page",
        "ftp://example.org/page",
    ],
)
def test_a_private_or_malformed_destination_is_refused(url: str) -> None:
    """The classification runs on the literal, before any resolution."""
    with pytest.raises(web_tools.ProviderContentError):
        web_tools.canonical_url(url)


def test_a_name_resolving_to_a_private_address_is_refused() -> None:
    """The second guard: the name is public and its answer is not."""
    with pytest.raises(web_tools.ProviderContentError) as caught:
        web_tools.resolve_public_addresses("localhost", 80)
    assert "private or non-global" in str(caught.value)


def test_a_result_naming_a_private_host_is_dropped_rather_than_raising(
    tmp_path: Path, searxng: ThreadingHTTPServer, source: ThreadingHTTPServer
) -> None:
    """A metasearch answer mixes engines, so one bad entry among several is discarded."""
    good = f"http://{SOURCE_HOST}:{_port(source)}/note"
    searxng.plan["body"] = _searxng_body(  # type: ignore[attr-defined]
        ["http://10.0.0.5/internal", good]
    )
    built = _harness(tmp_path, searxng, source)
    _, search = built.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": built.grant("raven2 decode")},
    )
    text = str(search["text"])
    assert "10.0.0.5" not in text
    assert good in text


# ---------------------------------------------------------------------------
# Bounds
# ---------------------------------------------------------------------------


def test_a_response_past_the_byte_cap_is_refused_during_the_read(
    harness: Harness, source: ThreadingHTTPServer, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The cap is read one byte past itself, so an oversized body fails the read."""
    _, search = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": harness.grant("raven2 decode")},
    )
    result_id = _result_id(str(search["text"]))
    source.plan["body"] = "<p>" + "x" * 4096 + "</p>"  # type: ignore[attr-defined]
    monkeypatch.setattr(web_tools, "HTTP_RESPONSE_BYTE_CAP", 512)
    status, answer = harness.call(web_tools.READ_URL_TOOL, {"result_id": result_id})
    assert status == 200
    assert answer["state"] == web_tools.STATE_INCOMPLETE
    assert answer["status"] == "provider_content_error"
    assert "byte cap" in str(answer["reason"])


def test_a_window_reads_the_bytes_max_chars_names(harness: Harness) -> None:
    """The window bound is the reply's own, separate from the document cap."""
    _, search = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": harness.grant("raven2 decode")},
    )
    _, fetched = harness.call(
        web_tools.READ_URL_TOOL,
        {"result_id": _result_id(str(search["text"])), "max_chars": 20},
    )
    assert "Returned Characters: 20" in str(fetched["text"])
    assert "Possibly Truncated: yes" in str(fetched["text"])
    assert int(dict(fetched["provenance"])["returned_characters"]) == 20  # type: ignore[arg-type]


def test_max_chars_above_the_profiles_bound_is_refused(harness: Harness) -> None:
    """The profile's own per-fetch bound is what an argument is measured against."""
    status, answer = harness.call(web_tools.READ_URL_TOOL, {"result_id": "a.b", "max_chars": 99999})
    assert status == 400
    assert answer["status"] == "invalid_argument"
    assert "max_chars" in str(answer["reason"])


def test_a_source_that_stalls_past_the_deadline_is_refused(
    tmp_path: Path, searxng: ThreadingHTTPServer, source: ThreadingHTTPServer
) -> None:
    """The socket carries the deadline, so a request thread cannot be held open.

    The predecessor armed a POSIX interval timer, which `signal.setitimer`
    refuses outside the main thread; a gateway serves every request on a worker,
    so the bound lives on the connection instead.
    """
    built = _harness(tmp_path, searxng, source, timeout_seconds=0.4)
    try:
        _, search = built.call(
            web_tools.SEARCH_TOOL,
            {"query": "raven2 decode", "authorization": built.grant("raven2 decode")},
        )
        result_id = _result_id(str(search["text"]))
        source.plan["delay_seconds"] = 2.0  # type: ignore[attr-defined]
        started = time.monotonic()
        status, answer = built.call(web_tools.READ_URL_TOOL, {"result_id": result_id})
        elapsed = time.monotonic() - started
        assert status == 200
        assert answer["state"] == web_tools.STATE_INCOMPLETE
        assert answer["status"] == "provider_http_error"
        assert elapsed < 2.0, f"the deadline did not bound the read: {elapsed:.2f}s"
    finally:
        source.plan["delay_seconds"] = 0.0  # type: ignore[attr-defined]


def test_a_source_answering_a_type_the_fetch_cannot_read_is_refused(
    harness: Harness, source: ThreadingHTTPServer
) -> None:
    _, search = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": harness.grant("raven2 decode")},
    )
    result_id = _result_id(str(search["text"]))
    source.plan["content_type"] = "application/pdf"  # type: ignore[attr-defined]
    status, answer = harness.call(web_tools.READ_URL_TOOL, {"result_id": result_id})
    assert status == 200
    assert answer["state"] == web_tools.STATE_INCOMPLETE
    assert "application/pdf" in str(answer["reason"])


# ---------------------------------------------------------------------------
# The approval chain
# ---------------------------------------------------------------------------


def test_a_replayed_grant_is_refused_before_the_instance_is_reached(
    harness: Harness, searxng: ThreadingHTTPServer
) -> None:
    """The grants table's primary key is the enforcement, as it is for an image."""
    grant = harness.grant("raven2 decode")
    status, first = harness.call(
        web_tools.SEARCH_TOOL, {"query": "raven2 decode", "authorization": grant}
    )
    assert status == 200 and first["outcome"] == "success"
    issued = len(searxng.plan["requests"])  # type: ignore[attr-defined]

    status, replay = harness.call(
        web_tools.SEARCH_TOOL, {"query": "raven2 decode", "authorization": grant}
    )
    assert status == 403
    assert replay["status"] == "authorization_denied"
    assert "spent" in str(replay["reason"])
    assert len(searxng.plan["requests"]) == issued  # type: ignore[attr-defined]


def test_a_query_that_leaves_the_grant_is_refused(harness: Harness) -> None:
    """The grant rather than the model decides which query reaches the instance."""
    status, answer = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "another query entirely", "authorization": harness.grant("raven2 decode")},
    )
    assert status == 403
    assert "query differs" in str(answer["reason"])


def test_a_grant_naming_another_profile_is_refused(harness: Harness) -> None:
    token = approvals.issue_search_grant(
        harness.key,
        approvals.SearchGrantRequest(
            profile_id="web-compact",
            query="raven2 decode",
            include_domains=(),
            exclude_domains=(),
            published_after="",
            published_before="",
            max_age_hours=None,
            max_results=5,
        ),
        provider="searxng",
        profile="web-compact",
        lifetime=900,
    )
    status, answer = harness.call(
        web_tools.SEARCH_TOOL, {"query": "raven2 decode", "authorization": token}
    )
    assert status == 403
    assert "another profile" in str(answer["reason"])


def test_a_search_without_a_grant_reaches_no_instance(
    harness: Harness, searxng: ThreadingHTTPServer
) -> None:
    status, answer = harness.call(web_tools.SEARCH_TOOL, {"query": "raven2 decode"})
    assert status == 400
    assert answer["status"] == "invalid_argument"
    assert searxng.plan["requests"] == []  # type: ignore[attr-defined]


def test_a_forged_result_id_reaches_no_source(
    harness: Harness, source: ThreadingHTTPServer
) -> None:
    forged = approvals.sign_claim(
        "a key this gateway never signed with",
        web_tools.RESULT_CLAIM_CONTEXT,
        {
            "canonical_url": f"http://{SOURCE_HOST}:{_port(source)}/note",
            "provider": "searxng",
            "expiry": time.time() + 600,
            "search_id": "forged",
        },
    )
    status, answer = harness.call(web_tools.READ_URL_TOOL, {"result_id": forged})
    assert status == 403
    assert answer["status"] == "authorization_denied"
    assert source.plan["requests"] == []  # type: ignore[attr-defined]


def test_the_fetch_allowance_the_search_opened_bounds_the_reads(
    tmp_path: Path, searxng: ThreadingHTTPServer, source: ThreadingHTTPServer
) -> None:
    """One approval reads as many of its own results as the profile admits."""
    built = _harness(tmp_path, searxng, source, max_fetches=1)
    _, search = built.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": built.grant("raven2 decode")},
    )
    result_id = _result_id(str(search["text"]))
    status, first = built.call(web_tools.READ_URL_TOOL, {"result_id": result_id})
    assert status == 200 and first["outcome"] == "success"
    status, second = built.call(web_tools.READ_URL_TOOL, {"result_id": result_id})
    assert status == 429
    assert second["status"] == "budget_exhausted"
    assert "every one is spent" in str(second["reason"])


def test_a_result_id_naming_a_url_its_search_never_returned_is_refused(
    harness: Harness, source: ThreadingHTTPServer
) -> None:
    """The signature admits the reference and the allowance admits the URL."""
    _, search = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": harness.grant("raven2 decode")},
    )
    claim = approvals.verify_claim(
        harness.key.read_text().strip(),
        web_tools.RESULT_CLAIM_CONTEXT,
        _result_id(str(search["text"])),
        time.time(),
        "result_id",
    )
    swapped = approvals.sign_claim(
        harness.key.read_text().strip(),
        web_tools.RESULT_CLAIM_CONTEXT,
        {**claim, "canonical_url": f"http://{SOURCE_HOST}:{_port(source)}/other"},
    )
    status, answer = harness.call(web_tools.READ_URL_TOOL, {"result_id": swapped})
    assert status == 403
    assert "never returned" in str(answer["reason"])


# ---------------------------------------------------------------------------
# Incomplete rather than silent
# ---------------------------------------------------------------------------


def test_a_source_answering_5xx_reports_an_incomplete_result_at_200(
    harness: Harness, source: ThreadingHTTPServer
) -> None:
    """The model learns the page did not arrive rather than the turn going quiet."""
    _, search = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": harness.grant("raven2 decode")},
    )
    result_id = _result_id(str(search["text"]))
    source.plan["status"] = 503  # type: ignore[attr-defined]
    status, answer = harness.call(web_tools.READ_URL_TOOL, {"result_id": result_id})
    assert status == 200
    assert answer["outcome"] == "failure"
    assert answer["state"] == web_tools.STATE_INCOMPLETE
    assert answer["status"] == "provider_http_error"
    assert "503" in str(answer["reason"])
    assert dict(answer["evidence"])["usable"] is False  # type: ignore[arg-type]


def test_an_instance_answering_5xx_reports_an_incomplete_search_at_200(
    harness: Harness, searxng: ThreadingHTTPServer
) -> None:
    searxng.plan["status"] = 502  # type: ignore[attr-defined]
    status, answer = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": harness.grant("raven2 decode")},
    )
    assert status == 200
    assert answer["state"] == web_tools.STATE_INCOMPLETE
    assert answer["status"] == "provider_http_error"


def test_an_instance_returning_nothing_reports_an_incomplete_search(
    harness: Harness, searxng: ThreadingHTTPServer
) -> None:
    searxng.plan["body"] = json.dumps({"results": []})  # type: ignore[attr-defined]
    status, answer = harness.call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": harness.grant("raven2 decode")},
    )
    assert status == 200
    assert answer["state"] == web_tools.STATE_INCOMPLETE
    assert "no result the grant admits" in str(answer["reason"])


# ---------------------------------------------------------------------------
# The matrix and the unmounted gateway
# ---------------------------------------------------------------------------


def test_the_matrix_names_the_two_rows_planned_until_the_executor_is_mounted() -> None:
    for tool_id in registry.WEB_EXECUTOR_ROWS:
        assert registry.entry(tool_id).availability is registry.Availability.PLANNED
        assert (
            registry.entry(tool_id, web_executor_mounted=True).availability
            is registry.Availability.SERVED
        )
        assert registry.entry(tool_id).execution_path == "src/qwen_apu/tools/web.py"
    payload = registry.as_payload(web_executor_mounted=True)
    rows = {row["tool_id"]: row for row in payload["tools"]}  # type: ignore[union-attr,index]
    assert rows["web_search"]["availability"] == "served"
    assert rows["read_url"]["availability"] == "served"


def test_a_gateway_without_an_instance_serves_no_call_and_mounts_nothing(
    tmp_path: Path,
) -> None:
    key = tmp_path / "web-token.key"
    key.write_text("a key\n", encoding="utf-8")
    os.chmod(key, 0o600)
    settings = web_tools.WebToolSettings(
        token_key_file=key, profile=PROFILE, session_admits=lambda request: True
    )
    assert settings.mounted is False
    harness = Harness(settings, tmp_path / "state", key)
    status, answer = harness.call(web_tools.SEARCH_TOOL, {"query": "raven2"})
    assert status == 400
    assert answer["status"] == "service_refused"


def test_an_assembly_that_forgets_the_ledger_cannot_spend_a_grant(tmp_path: Path) -> None:
    """The default refuses, so a replayable grant cannot be served by omission."""
    key = tmp_path / "web-token.key"
    key.write_text("a key\n", encoding="utf-8")
    os.chmod(key, 0o600)
    settings = web_tools.WebToolSettings(token_key_file=key, profile=PROFILE)
    with pytest.raises(web_tools.ServiceRefused):
        settings.spend_grant("grant", time.time())
    with pytest.raises(web_tools.ServiceRefused):
        settings.spend_fetch("search", "http://example.org/")


# ---------------------------------------------------------------------------
# The route on a listening gateway
# ---------------------------------------------------------------------------


class _Providers:
    def __init__(self, routes: tuple[object, ...]) -> None:
        self._routes = routes

    def routes(self) -> tuple[object, ...]:
        return self._routes


@pytest.fixture
def served(
    tmp_path: Path, searxng: ThreadingHTTPServer, source: ThreadingHTTPServer
) -> Iterator[tuple[Gateway, SessionGate, str, Harness]]:
    """One listening gateway carrying the executor behind its own session."""
    built = _harness(tmp_path / "executor", searxng, source)
    state = tmp_path / "session"
    state.mkdir(mode=0o700)
    gate = SessionGate(state)
    code = gate.start()
    settings = web_tools.WebToolSettings(
        token_key_file=built.settings.token_key_file,
        profile=built.settings.profile,
        provider=built.settings.provider,
        searxng=built.settings.searxng,
        max_results=built.settings.max_results,
        max_fetches=built.settings.max_fetches,
        max_chars_per_fetch=built.settings.max_chars_per_fetch,
        session_admits=_admits(gate),
        spend_grant=built.settings.spend_grant,
        open_search=built.settings.open_search,
        spend_fetch=built.settings.spend_fetch,
    )
    config = GatewayConfig(static_root=tmp_path, port=0, origins=("http://127.0.0.1:8090",))
    gateway = Gateway(
        config,
        (gate, _Providers(web_tools.routes(settings))),  # type: ignore[arg-type]
        session_authority=gate,
    )
    thread = threading.Thread(target=gateway.serve_forever)
    thread.start()
    try:
        yield gateway, gate, code, built
    finally:
        gateway.shutdown()
        thread.join(timeout=EXCHANGE_DEADLINE_SECONDS)


def _admits(gate: SessionGate) -> Callable[[Request], bool]:
    """Read the session gate's verdict the way `web/assemble.py` reads it."""

    def admits(request: Request) -> bool:
        try:
            gate.require_session(request)
        except RequestRefused:
            return False
        return True

    return admits


def _exchange(
    gateway: Gateway, path: str, body: bytes, headers: dict[str, str]
) -> tuple[HTTPResponse, bytes]:
    connection = HTTPConnection("127.0.0.1", gateway.port, timeout=EXCHANGE_DEADLINE_SECONDS)
    try:
        connection.request("POST", path, body=body, headers=headers)
        response = connection.getresponse()
        return response, response.read()
    finally:
        connection.close()


def test_a_call_without_a_session_reaches_no_instance(
    tmp_path: Path, searxng: ThreadingHTTPServer, source: ThreadingHTTPServer
) -> None:
    """The executor holds its own session check, so a mounted route is never open."""
    built = _harness(tmp_path, searxng, source)
    closed = web_tools.WebToolSettings(
        token_key_file=built.settings.token_key_file,
        profile=built.settings.profile,
        provider=built.settings.provider,
        searxng=built.settings.searxng,
        session_admits=lambda request: False,
    )
    status, answer = Harness(closed, built.state, built.key).call(
        web_tools.SEARCH_TOOL,
        {"query": "raven2 decode", "authorization": built.grant("raven2 decode")},
    )
    assert status == 403
    assert answer["status"] == "authorization_denied"
    assert searxng.plan["requests"] == []  # type: ignore[attr-defined]


def test_the_route_runs_a_search_behind_the_gateway_session(
    served: tuple[Gateway, SessionGate, str, Harness],
) -> None:
    gateway, _gate, code, built = served
    body = json.dumps(
        {
            "tool": web_tools.SEARCH_TOOL,
            "params": {
                "query": "raven2 decode",
                "authorization": built.grant("raven2 decode"),
            },
        }
    ).encode("utf-8")
    headers = {"Content-Type": "application/json", "Host": f"127.0.0.1:{gateway.port}"}

    # `SessionGate.guards` covers every `/api/` path but the pairing route, so
    # an unpaired caller meets the gateway's own 401 and the executor's session
    # check never runs; the two gates stack rather than one standing in for the
    # other, which `test_a_call_without_a_session_reaches_no_instance` proves
    # from the module side.
    refused, _ = _exchange(gateway, web_tools.TOOLS_PATH, body, headers)
    assert refused.status == 401

    paired, _ = _exchange(
        gateway,
        "/api/pair",
        json.dumps({"code": code}).encode("utf-8"),
        headers,
    )
    assert paired.status == 200
    cookie = (paired.getheader("Set-Cookie") or "").split(";", 1)[0]
    assert cookie.startswith(SESSION_COOKIE)

    answered, payload = _exchange(
        gateway, web_tools.TOOLS_PATH, body, {**headers, "Cookie": cookie}
    )
    assert answered.status == 200
    document = json.loads(payload)
    assert document["schema"] == web_tools.OUTCOME_SCHEMA
    assert document["state"] == web_tools.STATE_COMPLETE
    assert f"URL: http://{SOURCE_HOST}:" in document["text"]
