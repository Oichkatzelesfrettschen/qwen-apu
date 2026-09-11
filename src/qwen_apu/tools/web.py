"""The web search and page retrieval the gateway executes itself.

`remote/web-mcp/server.py` is the predecessor: an MCP child llama-server
spawns per call, whose `search_exa` queries the appliance's SearXNG instance
and whose `fetch_exa` reads one source page. This module carries those two
mechanisms onto `POST /api/tools` so one origin serves the page, the approval
routes, and the execution, and the bounds travel with them: the 512-character
query, the ten-result ceiling, the 4 MiB HTTP read, the 131072-character
document, the 24000-character window, the 20-second request deadline, the
HTML-and-plain-text content types, the UTF-8 charset set, and the redirect
refusal.

Two approvals rather than one carry the chain, which is what the two grades in
`qwen_apu.tools.registry` state. `web_search` presents the
`search-authorization` grant `POST /api/tools/grant` signed over the exact
query, domain lists, publication window, cached-age bound, and result count a
human read; this module rebuilds that canonical claim from the arguments it
received, compares it field by field, and spends the grant's single use
through the ledger the way `qwen_apu.tools.images` spends an image grant, so a
replay meets the grants table's primary key. `read_url` presents the signed
Result ID that approved search issued: the HMAC covers the canonical URL, the
provider, the search, and the term, and the fetch allowance the search opened
bounds how many of its results one approval reads. A grant covers a query and
signs no URL, so a fetch carrying a search grant would have nothing to bind
against; the search's own signed reference is the authority instead.

Every destination is classified before a socket opens. `canonical_url` refuses
a loopback, private, link-local, reserved, multicast, or noncanonical numeric
literal in a result URL, `resolve_public_addresses` refuses a name that
resolves to any non-global address, and the connection pins the address that
resolution returned while the TLS handshake still authenticates the original
DNS name, so the address a check admitted is the address the request reaches.
The SearXNG endpoint is the one exception and carries the opposite polarity:
the instance runs on this machine, so its URL is required to be loopback.

A retrieval that fails answers 200 carrying `state` of `incomplete` and the
reason, because a transport error is a result the page and the model both
read: the model that asked for a page learns the page did not arrive rather
than the turn ending on a status code the page turns into silence. A refusal
of the call itself -- an absent session, an unverified grant, a replayed
grant, an argument outside its bound -- answers its own status with the same
document, so one reader parses every outcome.

Two mechanisms of the predecessor stay out by name: the `content` snapshot
table, which makes a second window of one document cost no provider request,
and the Exa provider. A window past the first therefore retrieves the source
again, and this module reads SearXNG alone.
"""

from __future__ import annotations

import hashlib
import html.parser
import http.client
import ipaddress
import json
import os
import re
import socket
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import cast

from qwen_apu.tools import approvals
from qwen_apu.tools.ledger import (
    AuthorizationDenied,
    InvalidArgument,
    ToolError,
    utc_timestamp,
)
from qwen_apu.web.http import Request, Response, Route

TOOLS_PATH = "/api/tools"

SEARCH_TOOL = "web_search"
READ_URL_TOOL = "read_url"
TOOL_NAMES: tuple[str, ...] = (SEARCH_TOOL, READ_URL_TOOL)

QUERY_CHARACTER_CAP = 512
RESULT_COUNT_CAP = 10
RESULT_COUNT_DEFAULT = 5
TITLE_CHARACTER_CAP = 300
AUTHOR_CHARACTER_CAP = 200
HIGHLIGHT_COUNT_CAP = 3
HIGHLIGHT_CHARACTER_CAP = 1200
ENGINE_LIST_CHARACTER_CAP = 256
SEARCH_OUTPUT_CHARACTER_CAP = 16000
RESULT_ID_CHARACTER_CAP = 4096
URL_CHARACTER_CAP = 2048
DOCUMENT_CHARACTER_CAP = 131072
WINDOW_CHARACTER_CAP = 24000
WINDOW_CHARACTER_DEFAULT = 12000
MAX_AGE_HOURS_CAP = 24 * 365
REQUEST_TIMEOUT_SECONDS = 20.0
# The HTTP cap defends this process against a response of any size; the
# document cap bounds how much page text one retrieval holds; the window cap
# bounds one reply. Three separate limits, three separate failures.
HTTP_RESPONSE_BYTE_CAP = 4 * 1024 * 1024
REQUEST_BODY_BYTE_CAP = 16384

RESULT_CLAIM_CONTEXT = "result-id"
OUTCOME_SCHEMA = "qwen.web-tool-outcome"
OUTCOME_VERSION = 1
STATE_COMPLETE = "complete"
STATE_INCOMPLETE = "incomplete"

SEPARATOR_PATTERN = re.compile(r"^-{3,}$")
NUMERIC_LABEL_PATTERN = re.compile(r"^(0[xX][0-9a-fA-F]+|[0-9]+)$")
GRANT_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,64}$")
CATEGORY_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
LANGUAGE_PATTERN = re.compile(r"^(all|[A-Za-z]{2,8}(-[A-Za-z0-9]{2,8})*)$")
SAFESEARCH_VALUES: tuple[str, ...] = ("0", "1", "2")

# `decode` reads text, so the retrieval admits the document types whose bodies
# are text and names a PDF or an archive by its declared type rather than by
# the decode failure it would raise.
DOCUMENT_CONTENT_TYPES: tuple[str, ...] = ("text/html", "application/xhtml+xml", "text/plain")
DOCUMENT_CHARSETS: tuple[str, ...] = ("utf-8", "utf8", "ascii", "us-ascii")
SKIPPED_ELEMENTS = frozenset(("script", "style", "noscript", "template", "svg", "head"))
BLOCK_ELEMENTS = frozenset(
    (
        "address", "article", "aside", "blockquote", "br", "dd", "div", "dl",
        "dt", "figcaption", "figure", "footer", "h1", "h2", "h3", "h4", "h5",
        "h6", "header", "hr", "li", "main", "nav", "ol", "p", "pre", "section",
        "table", "td", "th", "tr", "ul",
    )
)  # fmt: skip

UNTRUSTED_HEADER = "BEGIN UNTRUSTED WEB CONTENT"
UNTRUSTED_FOOTER = "END UNTRUSTED WEB CONTENT"
NONCE_BYTES = 12

HTTP_STATUS_FOR_TERM: Mapping[str, int] = {
    "authorization_denied": 403,
    "rate_limited": 429,
    "budget_exhausted": 429,
    "expired_result": 403,
    "invalid_argument": 400,
}


class ProviderHttpError(ToolError):
    """A provider or a source answered with a transport failure or a refusal."""

    status = "provider_http_error"


class ProviderContentError(ToolError):
    """A response verified as transport and failed a size, type, or structure rule."""

    status = "provider_content_error"


class ServiceRefused(ToolError):
    """The gateway serves no executor for the call as configured."""

    status = "service_refused"


# The terms above name a retrieval that reached the network and came back
# unusable, which is the outcome the page renders as incomplete rather than as
# a refused call.
RETRIEVAL_FAILURE_TERMS: tuple[str, ...] = (
    "provider_http_error",
    "provider_content_error",
    "service_unavailable",
)


# ---------------------------------------------------------------------------
# Destination classification
# ---------------------------------------------------------------------------


def require_url_port(
    parts: urllib.parse.SplitResult, name: str, error_class: type[ToolError], default_port: int
) -> int:
    """Return one numeric port, refusing an explicit empty or malformed one."""
    try:
        port = parts.port
    except ValueError:
        raise error_class(f"{name} names an invalid port") from None
    authority = parts.netloc.rsplit("@", 1)[-1]
    if authority.endswith(":"):
        raise error_class(f"{name} names an empty port")
    if port is None:
        return default_port
    if not 1 <= port <= 65535:
        raise error_class(f"{name} names a port outside 1..65535")
    return port


def require_public_host(parts: urllib.parse.SplitResult) -> None:
    """Refuse a URL whose host names this machine or a private network.

    The check reads the literal address and the reserved `localhost` name and
    resolves no hostname, since a resolution here would differ from the one
    `resolve_public_addresses` performs immediately before the connection. A
    host whose every label parses as a decimal or hexadecimal integer is a
    legacy numeric spelling -- `2130706433`, `0x7f000001`, and `0177.0.0.1` all
    reach 127.0.0.1 through common resolvers while `ip_address` refuses them --
    so the spelling is refused rather than converted.
    """
    host = (parts.hostname or "").lower()
    if host == "localhost" or host.endswith(".localhost"):
        raise ProviderContentError("the result URL names a private host, which is refused")
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        labels = host.split(".")
        if host and all(NUMERIC_LABEL_PATTERN.match(label) for label in labels):
            raise ProviderContentError(
                "the result URL names a noncanonical numeric host, which is refused"
            ) from None
        return
    if (
        address.is_private
        or address.is_loopback
        or address.is_link_local
        or address.is_reserved
        or address.is_multicast
        or address.is_unspecified
    ):
        raise ProviderContentError("the result URL names a private address, which is refused")


def canonical_url(url: str) -> str:
    """Return the comparison form of a URL: scheme and host lowercased.

    Result ID issue and Result ID redemption both run through this function, so
    a fetch matches its search on the same string the signature covers.
    """
    if len(url) > URL_CHARACTER_CAP:
        raise ProviderContentError(f"the result URL exceeds the {URL_CHARACTER_CAP} character cap")
    try:
        parts = urllib.parse.urlsplit(url)
    except ValueError:
        raise ProviderContentError("the result URL is malformed") from None
    if parts.scheme.lower() not in ("http", "https"):
        raise ProviderContentError(f"the result URL carries an unsupported scheme: {url}")
    if not parts.netloc:
        raise ProviderContentError(f"the result URL names no host: {url}")
    if "@" in parts.netloc:
        raise ProviderContentError("the result URL carries userinfo, which is refused")
    if any(character in url for character in ("\n", "\r", "\t", " ")):
        raise ProviderContentError("the result URL carries whitespace, which is refused")
    require_url_port(
        parts,
        "the result URL",
        ProviderContentError,
        443 if parts.scheme.lower() == "https" else 80,
    )
    require_public_host(parts)
    return urllib.parse.urlunsplit(
        (parts.scheme.lower(), parts.netloc.lower(), parts.path, parts.query, "")
    )


def require_loopback_endpoint(url: str, name: str) -> str:
    """Return a SearXNG endpoint reduced to scheme and authority.

    The instance runs on this machine, so the endpoint is read the way
    `require_public_host` reads a result host and with the opposite polarity.
    `remote/web-profiles.tsv` already refuses a `searxng_url` that is not
    loopback, and this repeats the rule at the point the socket opens.
    """
    try:
        parts = urllib.parse.urlsplit(url.strip())
    except ValueError:
        raise InvalidArgument(f"{name} is not a valid URL") from None
    if parts.scheme.lower() not in ("http", "https"):
        raise InvalidArgument(f"{name} carries an unsupported scheme: {url}")
    if not parts.netloc or "@" in parts.netloc:
        raise InvalidArgument(f"{name} names no plain host: {url}")
    if parts.query or parts.fragment:
        raise InvalidArgument(f"{name} carries a query or fragment: {url}")
    require_url_port(parts, name, InvalidArgument, 443 if parts.scheme.lower() == "https" else 80)
    host = (parts.hostname or "").lower()
    loopback = host == "localhost" or host.endswith(".localhost")
    if not loopback:
        try:
            loopback = ipaddress.ip_address(host).is_loopback
        except ValueError:
            loopback = False
    if not loopback:
        raise InvalidArgument(f"{name} names a host other than loopback: {url}")
    return f"{parts.scheme.lower()}://{parts.netloc.lower()}{parts.path.rstrip('/')}"


def resolve_public_addresses(host: str, port: int) -> list[str]:
    """Resolve a source host once and return only globally routable addresses."""
    try:
        answers = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    except OSError:
        raise ProviderHttpError("the source host could not be resolved") from None
    addresses: list[str] = []
    for answer in answers:
        candidate = str(answer[4][0]).split("%", 1)[0]
        try:
            address = ipaddress.ip_address(candidate)
        except ValueError:
            raise ProviderContentError("the source resolver returned a malformed address") from None
        if not address.is_global:
            raise ProviderContentError(
                "the source host resolves to a private or non-global address"
            )
        canonical = str(address)
        if canonical not in addresses:
            addresses.append(canonical)
    if not addresses:
        raise ProviderHttpError("the source host resolved to no stream address")
    return addresses


AddressResolver = Callable[[str, int], Sequence[str]]


class PinnedHTTPConnection(http.client.HTTPConnection):
    """Connect to one validated address while retaining the URL host header.

    `Host:` still carries the name the search returned, so a virtual host
    answers the request the way it would over ordinary resolution; the address
    is the one `resolve_public_addresses` classified, which is what closes the
    window between a check on a name and a second resolution at connect time.
    """

    def __init__(self, host: str, port: int, address: str, timeout: float) -> None:
        super().__init__(host, port=port, timeout=timeout)
        self.validated_address = address

    def connect(self) -> None:
        self.sock = socket.create_connection((self.validated_address, self.port), self.timeout)


class PinnedHTTPSConnection(http.client.HTTPSConnection):
    """Connect to one validated address and authenticate the original DNS name.

    The certificate is verified against the URL's own host through
    `server_hostname`, so pinning the address changes which machine is reached
    and leaves which identity is required unchanged.
    """

    def __init__(self, host: str, port: int, address: str, timeout: float) -> None:
        super().__init__(host, port=port, timeout=timeout)
        self.validated_address = address
        self.tls_context = ssl.create_default_context()

    def connect(self) -> None:
        raw = socket.create_connection((self.validated_address, self.port), self.timeout)
        self.sock = self.tls_context.wrap_socket(raw, server_hostname=self.host)


def open_pinned_public_url(
    url: str, accept: str, deadline: float, resolver: AddressResolver
) -> tuple[bytes, http.client.HTTPMessage]:
    """Read one public URL without redirecting or repeating DNS resolution.

    Every deadline here is the socket's own: the remaining time bounds connect,
    the request, the response headers, and the body read, so one stalled source
    cannot hold a gateway worker past the configured timeout. The predecessor
    used a POSIX interval timer, which the gateway's request threads cannot arm
    because `signal.setitimer` belongs to the main thread alone.
    """
    parts = urllib.parse.urlsplit(url)
    host = parts.hostname or ""
    port = require_url_port(
        parts,
        "the source URL",
        ProviderContentError,
        443 if parts.scheme.lower() == "https" else 80,
    )
    addresses = resolver(host, port)
    target = parts.path or "/"
    if parts.query:
        target += "?" + parts.query
    last_error: Exception | None = None
    for address in addresses:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ProviderHttpError("the source request exceeded its deadline")
        secure = parts.scheme.lower() == "https"
        connection: http.client.HTTPConnection = (
            PinnedHTTPSConnection(host, port, address, remaining)
            if secure
            else PinnedHTTPConnection(host, port, address, remaining)
        )
        try:
            connection.request("GET", target, headers={"accept": accept})
            response = connection.getresponse()
            if response.status != 200:
                raise ProviderHttpError(f"the source answered with status {response.status}")
            raw = response.read(HTTP_RESPONSE_BYTE_CAP + 1)
            return raw, response.headers
        except ProviderHttpError:
            raise
        except (OSError, http.client.HTTPException) as error:
            last_error = error
        finally:
            connection.close()
    raise ProviderHttpError("the source request failed") from last_error


class _RefuseRedirect(urllib.request.HTTPRedirectHandler):
    """End a redirect at the response that requested it.

    The instance answers on the endpoint the configuration names, so a
    redirect from it is a reachable rule change rather than a route to follow.
    """

    def redirect_request(  # noqa: PLR0917 -- urllib's own signature
        self,
        req: urllib.request.Request,
        fp: object,
        code: int,
        msg: str,
        headers: http.client.HTTPMessage,
        newurl: str,
    ) -> urllib.request.Request | None:
        return None


_LOOPBACK_OPENER = urllib.request.build_opener(_RefuseRedirect())


# ---------------------------------------------------------------------------
# HTML to the text a reader sees
# ---------------------------------------------------------------------------


class HtmlTextExtractor(html.parser.HTMLParser):
    """Reduce one HTML document to the text a reader sees.

    Script, style, and template contents are dropped because they are program
    text rather than prose, and a block element ends the line so the extracted
    document keeps the paragraph structure a model reads it by.
    """

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.suppressed = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        del attrs
        if tag in SKIPPED_ELEMENTS:
            self.suppressed += 1
        elif tag in BLOCK_ELEMENTS:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in SKIPPED_ELEMENTS:
            self.suppressed = max(0, self.suppressed - 1)
        elif tag in BLOCK_ELEMENTS:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if self.suppressed == 0:
            self.parts.append(data)

    def text(self) -> str:
        joined = "".join(self.parts)
        lines = [" ".join(line.split()) for line in joined.splitlines()]
        return "\n".join(line for line in lines if line)


def html_to_text(document: str) -> str:
    """Return the readable text of an HTML document, or the document itself.

    A malformed document reaches this parser as page bytes an attacker chose,
    so a parser failure returns the raw text: the frame around the window
    already states that the content is untrusted, and a refusal here would let
    a broken page deny the fetch its Result ID bought.
    """
    extractor = HtmlTextExtractor()
    try:
        extractor.feed(document)
        extractor.close()
    except Exception:
        return document
    return extractor.text()


# ---------------------------------------------------------------------------
# The SearXNG provider
# ---------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class SearchResult:
    """One metasearch record in the shape the renderer reads."""

    url: str
    title: str
    published: str
    author: str
    engines: tuple[str, ...]
    category: str
    highlights: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SearchConstraints:
    """The filters one approved search runs under."""

    include_domains: tuple[str, ...] = ()
    exclude_domains: tuple[str, ...] = ()
    published_after: str = ""
    published_before: str = ""
    max_age_hours: int | None = None


def host_within_domain(host: str, domain: str) -> bool:
    return host == domain or host.endswith("." + domain)


def admitted_by_domains(url: str, constraints: SearchConstraints) -> bool:
    """Return whether one canonical URL survives the granted domain lists."""
    host = (urllib.parse.urlsplit(url).hostname or "").lower()
    if constraints.include_domains and not any(
        host_within_domain(host, domain) for domain in constraints.include_domains
    ):
        return False
    return not any(host_within_domain(host, domain) for domain in constraints.exclude_domains)


class SearxngProvider:
    """A SearXNG instance's JSON search API, and a direct read of one result.

    `GET {base}/search?q=...&format=json` returns ranked metadata carrying no
    page text, so a page comes from the host the search returned. The JSON API
    reads `categories`, `language`, `safesearch`, and `pageno` and carries no
    publication interval, so both temporal arguments are refused rather than
    approximated; domain scope and result count are honored here, since a
    record outside them is dropped before it is counted.

    Which engines answer belongs to the instance's own `settings.yml`, which
    groups them under qwen-named categories. The profile names a category and
    this provider sends it, so the engine population changes by editing the
    instance rather than by a request field a model reaches.
    """

    name = "searxng"

    def __init__(
        self,
        base_url: str,
        primary_category: str,
        *,
        fallback_category: str = "",
        minimum_results: int = 1,
        language: str = "",
        safesearch: str = "",
        timeout_seconds: float = REQUEST_TIMEOUT_SECONDS,
        address_resolver: AddressResolver = resolve_public_addresses,
    ) -> None:
        self.base_url = require_loopback_endpoint(base_url, "searxng_url")
        self.search_endpoint = self.base_url + "/search"
        self.primary_category = (primary_category or "").strip()
        if not CATEGORY_PATTERN.match(self.primary_category):
            raise InvalidArgument(
                f"primary_category names no category the instance can carry: {primary_category}"
            )
        self.fallback_category = (fallback_category or "").strip()
        if self.fallback_category in ("-", ""):
            self.fallback_category = ""
        elif not CATEGORY_PATTERN.match(self.fallback_category):
            raise InvalidArgument(
                f"fallback_category names no category the instance can carry: {fallback_category}"
            )
        if not 1 <= int(minimum_results) <= RESULT_COUNT_CAP:
            raise InvalidArgument(
                f"minimum_results lies between 1 and {RESULT_COUNT_CAP}: {minimum_results}"
            )
        self.minimum_results = int(minimum_results)
        self.language = language
        if self.language and not LANGUAGE_PATTERN.match(self.language):
            raise InvalidArgument(f"language names no language tag: {self.language}")
        self.safesearch = safesearch
        if self.safesearch and self.safesearch not in SAFESEARCH_VALUES:
            raise InvalidArgument(
                "safesearch reads one of " + ", ".join(SAFESEARCH_VALUES) + f": {self.safesearch}"
            )
        self.timeout_seconds = float(timeout_seconds)
        self.address_resolver = address_resolver
        self.response_bytes = 0
        self.request_count = 0
        self.fallback_used = 0
        self.usable_results = 0
        self.engines_answered: list[str] = []
        self.engines_failed: list[str] = []
        self.categories_issued: list[str] = []

    def refuse_unhonored_arguments(self, constraints: SearchConstraints) -> None:
        """Refuse an approved argument this provider expresses no request field for.

        A mixed category answers from engines whose recency support differs --
        Bing's web engine expresses no time range at all -- so a category
        cannot promise one, and a window silently dropped would return results
        outside what a human approved.
        """
        if constraints.published_after or constraints.published_before:
            raise InvalidArgument(
                "the searxng provider carries no publication interval, so a search "
                "naming published_after or published_before runs nowhere"
            )
        if constraints.max_age_hours is not None:
            raise InvalidArgument(
                "the searxng provider carries no cached-age bound, so a search "
                "naming max_age_hours runs nowhere"
            )

    def _open(
        self, url: str, accept: str, deadline: float, public_source: bool = False
    ) -> tuple[bytes, http.client.HTTPMessage]:
        """Return the body and headers of one bounded GET.

        The body is read to one byte past the cap, so an oversized response is
        refused during the read rather than after it is held whole.
        """
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ProviderHttpError(
                f"the provider request exceeded {self.timeout_seconds:g} seconds"
            )
        try:
            if public_source:
                raw, headers = open_pinned_public_url(url, accept, deadline, self.address_resolver)
            else:
                request = urllib.request.Request(  # noqa: S310 -- require_loopback_endpoint
                    url, headers={"accept": accept}, method="GET"
                )
                with _LOOPBACK_OPENER.open(request, timeout=remaining) as response:
                    raw = response.read(HTTP_RESPONSE_BYTE_CAP + 1)
                    headers = response.headers
            self.response_bytes += len(raw)
        except urllib.error.HTTPError as error:
            status_code = error.code
            error.close()
            raise ProviderHttpError(
                f"the provider rejected the request with status {status_code}"
            ) from None
        except (ProviderHttpError, ProviderContentError):
            raise
        except TimeoutError:
            raise ProviderHttpError(
                f"the provider request exceeded {self.timeout_seconds:g} seconds"
            ) from None
        except Exception:
            raise ProviderHttpError("the provider request failed") from None
        if len(raw) > HTTP_RESPONSE_BYTE_CAP:
            raise ProviderContentError(
                f"the provider response exceeds the {HTTP_RESPONSE_BYTE_CAP} byte cap"
            )
        return raw, headers

    def search(
        self, query: str, max_results: int, constraints: SearchConstraints
    ) -> tuple[SearchResult, ...]:
        """Query the primary category, and the fallback once where it is short.

        A record is usable when its URL canonicalizes, names a public host,
        survives the granted domain lists, and repeats no URL an earlier record
        carried, so the count that decides the fallback is the count of results
        the reply can actually carry. Exactly one fallback query runs: an
        instance suspends a failing engine on its own, so a retry loop here
        would spend the approval on the outage it is already routing around.
        """
        issued: set[str] = set()
        deadline = time.monotonic() + self.timeout_seconds
        usable = self._query_category(query, self.primary_category, constraints, issued, deadline)
        if len(usable) < self.minimum_results and self.fallback_category:
            self.fallback_used = 1
            usable = usable + self._query_category(
                query, self.fallback_category, constraints, issued, deadline
            )
        self.usable_results = len(usable)
        return tuple(usable[:max_results])

    def _query_category(
        self,
        query: str,
        category: str,
        constraints: SearchConstraints,
        issued: set[str],
        deadline: float,
    ) -> list[SearchResult]:
        """Return the usable records of one category query.

        A result naming this machine, a private network, or a domain outside
        the grant is dropped rather than raising, because a metasearch answer
        mixes engines and one bad entry among ten is an entry to discard.
        """
        parameters = [("q", query), ("format", "json"), ("categories", category)]
        if self.language:
            parameters.append(("language", self.language))
        if self.safesearch:
            parameters.append(("safesearch", self.safesearch))
        self.categories_issued.append(category)
        self.request_count += 1
        raw, _ = self._open(
            self.search_endpoint + "?" + urllib.parse.urlencode(parameters),
            "application/json",
            deadline,
        )
        try:
            document = json.loads(raw.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            raise ProviderContentError("the provider response is not valid UTF-8 JSON") from None
        if not isinstance(document, dict):
            raise ProviderContentError("the provider response is not a JSON object")
        results = document.get("results")
        if not isinstance(results, list):
            raise ProviderContentError("the provider response carries no result list")
        if any(not isinstance(record, dict) for record in results):
            raise ProviderContentError(
                "the provider response carries a result that is not an object"
            )
        for name in _unresponsive_engine_names(document.get("unresponsive_engines")):
            if name not in self.engines_failed:
                self.engines_failed.append(name)
        usable: list[SearchResult] = []
        for record in results:
            mapped = _map_result(cast(Mapping[str, object], record), category)
            try:
                url = canonical_url(mapped.url)
            except ToolError:
                continue
            if not admitted_by_domains(url, constraints) or url in issued:
                continue
            issued.add(url)
            for name in mapped.engines:
                if name not in self.engines_answered:
                    self.engines_answered.append(name)
            usable.append(
                SearchResult(
                    url=url,
                    title=mapped.title,
                    published=mapped.published,
                    author=mapped.author,
                    engines=mapped.engines,
                    category=category,
                    highlights=mapped.highlights,
                )
            )
        return usable

    def provenance(self) -> dict[str, str | int]:
        """Return the seven columns a metasearch answer fills in the audit trail."""
        attempted = list(self.engines_answered) + [
            name for name in self.engines_failed if name not in self.engines_answered
        ]
        return {
            "category": self.categories_issued[0] if self.categories_issued else "",
            "engines_attempted": ",".join(sorted(attempted)),
            "engines_answered": ",".join(sorted(self.engines_answered)),
            "engines_failed": ",".join(sorted(self.engines_failed)),
            "fallback_used": self.fallback_used,
            "usable_results": self.usable_results,
        }

    def contents(self, url: str, max_characters: int) -> tuple[str, bool]:
        """Return the text of the source page a signed Result ID names.

        `redeem_result_id` verified the signature and re-ran `canonical_url`,
        which applies `require_public_host`, so the URL reaching this GET is
        one a prior search issued over a public host. The declared content type
        decides admission, which names a PDF or an archive as the wrong
        document type rather than letting it reach the UTF-8 decode as a byte
        error.
        """
        deadline = time.monotonic() + self.timeout_seconds
        raw, headers = self._open(
            url,
            "text/html, application/xhtml+xml;q=0.9, text/plain;q=0.8",
            deadline,
            public_source=True,
        )
        content_type = (headers.get_content_type() or "").lower()
        if content_type not in DOCUMENT_CONTENT_TYPES:
            raise ProviderContentError(
                f"the source answered with content type {content_type or 'none'}, "
                "and the fetch reads HTML and plain text"
            )
        charset = (headers.get_content_charset() or "utf-8").lower()
        if charset not in DOCUMENT_CHARSETS:
            raise ProviderContentError(
                f"the source declares the {charset} character set, and the fetch reads UTF-8"
            )
        try:
            document = raw.decode("utf-8")
        except UnicodeDecodeError:
            raise ProviderContentError("the source content is not valid UTF-8") from None
        if content_type != "text/plain":
            document = html_to_text(document)
        return document[:max_characters], len(document) <= max_characters


def _unresponsive_engine_names(reported: object) -> list[str]:
    """Return the engine names an instance reported as unresponsive.

    The field carries a list of pairs on some releases and a list of strings on
    others, so both shapes are read and anything else contributes nothing.
    """
    names: list[str] = []
    if not isinstance(reported, list):
        return names
    for entry in reported:
        candidate = entry[0] if isinstance(entry, list) and entry else entry
        if isinstance(candidate, str) and candidate.strip():
            names.append(candidate.strip())
    return names


def _map_result(record: Mapping[str, object], category: str) -> SearchResult:
    """Return one SearXNG entry in the shape the renderer reads.

    `content` is the instance's own snippet, which takes the highlight
    position. The record carries no opaque identifier, so the canonical URL
    alone resolves the fetch.
    """
    engines: list[str] = []
    for key in ("engines", "engine"):
        value = record.get(key)
        if isinstance(value, str):
            value = [value]
        if isinstance(value, list):
            for entry in value:
                if isinstance(entry, str) and entry.strip() and entry.strip() not in engines:
                    engines.append(entry.strip())
    snippet = record.get("content")
    published = record.get("publishedDate")
    title = record.get("title")
    return SearchResult(
        url=str(record.get("url", "")),
        title=title if isinstance(title, str) else "",
        published=published if isinstance(published, str) else "",
        author="",
        engines=tuple(engines),
        category=category,
        highlights=(snippet,) if isinstance(snippet, str) and snippet else (),
    )


# ---------------------------------------------------------------------------
# Result references and the rendered reply
# ---------------------------------------------------------------------------


def issue_result_id(
    *,
    signing_key: str,
    url: str,
    provider_name: str,
    search_id: str,
    issued_at: int,
    lifetime_seconds: int,
) -> str:
    """Sign a result reference into an opaque token.

    `search_id` binds the reference to the search that issued it, so the fetch
    allowance that search opened is the allowance the redemption spends.
    """
    token = approvals.sign_claim(
        signing_key,
        RESULT_CLAIM_CONTEXT,
        {
            "canonical_url": url,
            "provider": provider_name,
            "issued_at": issued_at,
            "expiry": issued_at + lifetime_seconds,
            "search_id": search_id,
        },
    )
    if len(token) > RESULT_ID_CHARACTER_CAP:
        raise ProviderContentError(
            f"the result reference exceeds the {RESULT_ID_CHARACTER_CAP} character cap "
            "that redeems it"
        )
    return token


def redeem_result_id(signing_key: str, result_id: str, now: float) -> dict[str, object]:
    """Return the claim of a result identifier this gateway issued.

    A tampered payload fails `compare_digest` and an expired claim fails the
    term check, so the only URL a fetch reaches is one a prior search returned
    inside its lifetime.
    """
    claim = approvals.verify_claim(signing_key, RESULT_CLAIM_CONTEXT, result_id, now, "result_id")
    if "canonical_url" not in claim:
        raise AuthorizationDenied("the result_id payload is malformed")
    claim["canonical_url"] = canonical_url(str(claim["canonical_url"]))
    search_id = claim.get("search_id")
    claim["search_id"] = search_id if isinstance(search_id, str) else ""
    return claim


def clip(value: object, cap: int) -> str:
    """Return a provider string as one bounded line.

    Title, author, and highlight text come from the page, so both their length
    and their line structure are attacker-chosen. Collapsing every whitespace
    run to one space keeps a field inside the single line its key claims, and a
    value that is a run of dashes alone becomes a placeholder, so page text
    cannot write the `---` line that closes a result block.
    """
    text = " ".join(str(value).split())
    if SEPARATOR_PATTERN.match(text):
        text = "[separator]"
    return text[:cap]


def render_search_results(
    results: Sequence[SearchResult],
    *,
    provider_name: str,
    signing_key: str,
    search_id: str,
    issued_at: int,
    lifetime_seconds: int,
) -> tuple[str, tuple[str, ...]]:
    """Render one block per result in the layout the page's handle table parses.

    `static/js/tools.js` replaces the `Result ID:` field of a complete block
    and refuses a signed identifier anywhere else, so the field order --
    Title, URL, Published, Author, Result ID, Trust, the optional Sources line,
    then Highlights last -- is the contract rather than a presentation choice.
    A `Results Omitted:` count follows the final separator where the output cap
    dropped results, outside every block so it stays clear of the highlight
    region.
    """
    blocks: list[str] = []
    issued: list[str] = []
    block_characters = 0
    admitted_characters = SEARCH_OUTPUT_CHARACTER_CAP - len(f"\nResults Omitted: {len(results)}")
    for record in results:
        lines = [
            f"Title: {clip(record.title or record.url, TITLE_CHARACTER_CAP)}",
            f"URL: {record.url}",
            f"Published: {clip(record.published, 64)}",
            f"Author: {clip(record.author, AUTHOR_CHARACTER_CAP)}",
            "Result ID: "
            + issue_result_id(
                signing_key=signing_key,
                url=record.url,
                provider_name=provider_name,
                search_id=search_id,
                issued_at=issued_at,
                lifetime_seconds=lifetime_seconds,
            ),
            "Trust: untrusted-web-result",
        ]
        if record.engines:
            sources = clip(", ".join(record.engines), ENGINE_LIST_CHARACTER_CAP)
            if sources:
                lines.append(f"Sources: {sources}")
        lines.append("Highlights:")
        for highlight in record.highlights[:HIGHLIGHT_COUNT_CAP]:
            lines.append(f"- {clip(highlight, HIGHLIGHT_CHARACTER_CAP)}")
        block = "\n".join(lines)
        projected = block_characters + len(block) + 5 * (len(blocks) + 1) - 1
        if projected > admitted_characters:
            break
        blocks.append(block)
        block_characters += len(block)
        issued.append(record.url)
    if not blocks:
        return "No results.", ()
    rendered = "\n---\n".join(blocks) + "\n---"
    omitted = len(results) - len(blocks)
    if omitted:
        rendered += f"\nResults Omitted: {omitted}"
    return rendered, tuple(issued)


def wrap_untrusted(
    url: str, retrieved_at: str, window: str, start_index: int, truncated: bool
) -> str:
    """Frame one window of page text with the state a next call needs.

    The nonce is drawn after retrieval and is absent from the window, so page
    text cannot write the line that closes the frame: a body holding the
    literal footer meets a delimiter whose nonce it could not have predicted.
    `Next Start Index` names the offset that continues the document and reads
    `end` at the last character, so paging is decided by this server's own
    count rather than by the model's arithmetic over a body it cannot measure.
    """
    nonce = approvals.base64url_encode(os.urandom(NONCE_BYTES))
    while nonce in window:
        nonce = approvals.base64url_encode(os.urandom(NONCE_BYTES))
    digest = hashlib.sha256(window.encode("utf-8")).hexdigest()
    next_index = start_index + len(window)
    return "\n".join(
        [
            f"{UNTRUSTED_HEADER} [{nonce}]",
            f"Source: {url}",
            f"Retrieved: {retrieved_at}",
            f"Content SHA-256: {digest}",
            f"Start Index: {start_index}",
            f"Returned Characters: {len(window)}",
            f"Next Start Index: {next_index if truncated else 'end'}",
            f"Possibly Truncated: {'yes' if truncated else 'no'}",
            window,
            f"{UNTRUSTED_FOOTER} [{nonce}]",
        ]
    )


def source_identity(url: str) -> dict[str, str]:
    """Return a non-capability identity for one validated canonical URL."""
    canonical = canonical_url(url)
    parts = urllib.parse.urlsplit(canonical)
    return {
        "origin": f"{parts.scheme}://{parts.netloc}",
        "url_sha256": hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
    }


# ---------------------------------------------------------------------------
# The executor
# ---------------------------------------------------------------------------


def _grant_absent(grant_id: str, expiry: float) -> None:
    raise ServiceRefused("the gateway binds no ledger to spend the search grant")


def _search_absent(search_id: str, allowance: int, expiry: float, urls: Sequence[str]) -> None:
    raise ServiceRefused("the gateway binds no ledger to open the search's fetch allowance")


def _fetch_absent(search_id: str, url: str) -> None:
    raise ServiceRefused("the gateway binds no ledger to spend the search's fetch allowance")


def _refuse_every_session(request: Request) -> bool:
    del request
    return False


@dataclass(frozen=True, slots=True)
class WebToolSettings:
    """What one gateway launch searches with, reads with, and meters against.

    `searxng` is None where the resolved web profile names no instance, which
    is what makes the executor report itself unmounted rather than refusing a
    launch: a gateway serving chat alone starts, and `GET /api/tools` states
    the two rows as planned.

    The three ledger operations arrive as callables the way
    `qwen_apu.tools.images` takes its grant spend, so this module holds no
    database handle and its rules test without one. Each default refuses, so an
    assembly that forgets the ledger cannot serve a replayable grant.
    """

    token_key_file: Path
    profile: str
    provider: str = "searxng"
    searxng: SearxngProvider | None = None
    max_results: int = RESULT_COUNT_DEFAULT
    max_fetches: int = 2
    max_chars_per_fetch: int = WINDOW_CHARACTER_DEFAULT
    result_lifetime_seconds: int = approvals.TOKEN_LIFETIME_DEFAULT_SECONDS
    session_admits: Callable[[Request], bool] = _refuse_every_session
    spend_grant: Callable[[str, float], None] = field(default_factory=lambda: _grant_absent)
    open_search: Callable[[str, int, float, Sequence[str]], None] = field(
        default_factory=lambda: _search_absent
    )
    spend_fetch: Callable[[str, str], None] = field(default_factory=lambda: _fetch_absent)
    now: Callable[[], float] = time.time

    @property
    def mounted(self) -> bool:
        """Whether this gateway executes a web tool at all."""
        return self.searxng is not None


def result_document(
    *,
    operation: str,
    outcome: str,
    status: str,
    state: str,
    kind: str,
    scope: str,
    usable: bool,
    text: str,
    sources: Sequence[Mapping[str, str]],
    provenance: Mapping[str, object],
) -> dict[str, object]:
    """Return the one record every outcome of this route carries.

    `schema` and `version` are the predecessor's own, so a reader that parsed
    an MCP child's reply parses this one. `state` and `provenance` are what the
    gateway adds: the state separates a call the boundary refused from a
    retrieval that reached the network and came back empty, and the provenance
    names what ran, how many bytes it cost, and the digest of the text the
    record carries, so a transcript can cite the retrieval rather than the
    prose alone.
    """
    document: dict[str, object] = {
        "schema": OUTCOME_SCHEMA,
        "version": OUTCOME_VERSION,
        "outcome": outcome,
        "state": state,
        "status": status,
        "evidence": {"kind": kind, "scope": scope, "usable": usable, "sources": list(sources)},
        "text": text,
        "provenance": dict(provenance),
    }
    if outcome != "success":
        document["reason"] = text
    return document


def provenance_record(
    operation: str,
    *,
    query: str = "",
    url: str = "",
    status: str,
    provider_bytes: int = 0,
    text: str = "",
    started_at: float,
    now: float,
) -> dict[str, object]:
    """Return the retrieval's own receipt: what was asked, what came back, when."""
    return {
        "operation": operation,
        "query": query,
        "url": url,
        "status": status,
        "provider_bytes": provider_bytes,
        "returned_characters": len(text),
        "text_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
        "retrieved_at": utc_timestamp(now),
        "latency_ms": int((time.monotonic() - started_at) * 1000),
    }


def _json(status: int, payload: Mapping[str, object]) -> Response:
    return Response(
        status,
        json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        {
            "content-type": "application/json",
            "cache-control": "no-store",
            "x-content-type-options": "nosniff",
        },
    )


def _body(request: Request) -> Mapping[str, object]:
    if len(request.body) > REQUEST_BODY_BYTE_CAP:
        raise InvalidArgument(f"the request body exceeds the {REQUEST_BODY_BYTE_CAP} byte cap")
    try:
        parsed = json.loads(request.body.decode("utf-8")) if request.body else None
    except (ValueError, UnicodeDecodeError):
        raise InvalidArgument("the request body is not UTF-8 JSON") from None
    if not isinstance(parsed, dict):
        raise InvalidArgument("the request body is not a JSON object")
    return cast(Mapping[str, object], parsed)


def _constraints(params: Mapping[str, object]) -> SearchConstraints:
    published_after = approvals.require_iso_date(params.get("published_after"), "published_after")
    published_before = approvals.require_iso_date(
        params.get("published_before"), "published_before"
    )
    if published_after and published_before and published_after > published_before:
        raise InvalidArgument("published_after falls after published_before")
    return SearchConstraints(
        include_domains=tuple(
            approvals.require_domain_list(params.get("include_domains"), "include_domains")
        ),
        exclude_domains=tuple(
            approvals.require_domain_list(params.get("exclude_domains"), "exclude_domains")
        ),
        published_after=published_after,
        published_before=published_before,
        max_age_hours=approvals.require_optional_integer(
            params.get("max_age_hours"), "max_age_hours", 0, MAX_AGE_HOURS_CAP
        ),
    )


def enforce_search_authorization(
    settings: WebToolSettings,
    *,
    signing_key: str,
    token: str,
    query: str,
    max_results: int,
    constraints: SearchConstraints,
    now: float,
) -> Mapping[str, object]:
    """Return the grant this search runs under, or refuse the arguments.

    A search query is model-authored and a note the model reads can rewrite it,
    which `evidence/model-admission` records as `tool-08` carrying an injected
    argument in every measured arm, so the signed grant rather than the model
    decides which query reaches the instance. The claim is rebuilt through
    `qwen_apu.tools.approvals.authorization_claim`, the same function the
    signing route built it with, so one spelling of every field is compared.
    A smaller `max_results` narrows the grant and every other difference
    refuses.
    """
    granted = approvals.verify_claim(
        signing_key, approvals.AUTHORIZATION_CLAIM_CONTEXT, token, now, "authorization"
    )
    requested = approvals.authorization_claim(
        query,
        include_domains=list(constraints.include_domains),
        exclude_domains=list(constraints.exclude_domains),
        published_after=constraints.published_after,
        published_before=constraints.published_before,
        max_age_hours=constraints.max_age_hours,
        max_results=max_results,
        expiry=cast(int, granted.get("expiry")),
    )
    for name in (
        "query",
        "include_domains",
        "exclude_domains",
        "published_after",
        "published_before",
        "max_age_hours",
    ):
        if granted.get(name) != requested[name]:
            raise AuthorizationDenied(
                f"the search arguments leave the authorization: {name} differs"
            )
    granted_results = granted.get("max_results")
    if not isinstance(granted_results, int) or max_results > granted_results:
        raise AuthorizationDenied(
            "the search arguments leave the authorization: max_results exceeds the granted count"
        )
    if granted.get("provider") != settings.provider:
        raise AuthorizationDenied(
            "the authorization names another provider than the configured one"
        )
    if granted.get("profile_id") != settings.profile:
        raise AuthorizationDenied("the authorization names another profile than the serving one")
    if granted.get("max_uses") != approvals.GRANT_MAX_USES:
        raise AuthorizationDenied(
            f"the authorization admits a use count other than {approvals.GRANT_MAX_USES}"
        )
    grant_id = granted.get("grant_id")
    if not isinstance(grant_id, str) or not GRANT_ID_PATTERN.match(grant_id):
        raise AuthorizationDenied("the authorization carries no usable grant_id")
    return granted


def run_search(settings: WebToolSettings, params: Mapping[str, object]) -> dict[str, object]:
    """Execute one approved search and return the record it answers with."""
    provider = settings.searxng
    if provider is None:
        raise ServiceRefused("this gateway names no search instance, so no search runs")
    started_at = time.monotonic()
    now = settings.now()
    query = approvals.require_string(params.get("query"), "query", QUERY_CHARACTER_CAP)
    # The default narrows in both directions: `approvals.parse_search_request`
    # signs an omitted count at RESULT_COUNT_DEFAULT, and the grant comparison
    # refuses a resolved count above the granted one, so a profile admitting
    # more than the default would refuse every search that named none.
    max_results = approvals.require_integer(
        params.get("max_results"),
        "max_results",
        min(RESULT_COUNT_DEFAULT, settings.max_results),
        1,
        settings.max_results,
    )
    constraints = _constraints(params)
    provider.refuse_unhonored_arguments(constraints)
    token = approvals.require_string(
        params.get("authorization"), "authorization", approvals.AUTHORIZATION_CHARACTER_CAP
    )
    signing_key = approvals.read_secret_file(settings.token_key_file, "token signing")
    granted = enforce_search_authorization(
        settings,
        signing_key=signing_key,
        token=token,
        query=query,
        max_results=max_results,
        constraints=constraints,
        now=now,
    )
    # The single use is spent between admission and the request, the way
    # `tools/images.py` spends a generation grant: a replay meets the grants
    # table's primary key here and reaches no instance.
    settings.spend_grant(
        cast(str, granted["grant_id"]), float(cast(float, granted.get("expiry", now)))
    )
    results = provider.search(query, max_results, constraints)
    search_id = approvals.base64url_encode(os.urandom(9))
    rendered, issued = render_search_results(
        results,
        provider_name=provider.name,
        signing_key=signing_key,
        search_id=search_id,
        issued_at=int(now),
        lifetime_seconds=settings.result_lifetime_seconds,
    )
    settings.open_search(
        search_id, settings.max_fetches, now + settings.result_lifetime_seconds, issued
    )
    provenance = provenance_record(
        SEARCH_TOOL,
        query=query,
        status="success",
        provider_bytes=provider.response_bytes,
        text=rendered,
        started_at=started_at,
        now=now,
    )
    provenance.update(provider.provenance())
    if not issued:
        return result_document(
            operation=SEARCH_TOOL,
            outcome="failure",
            status="provider_content_error",
            state=STATE_INCOMPLETE,
            kind="none",
            scope="none",
            usable=False,
            text=f"the search for {query!r} returned no result the grant admits",
            sources=(),
            provenance=provenance,
        )
    return result_document(
        operation=SEARCH_TOOL,
        outcome="success",
        status="success",
        state=STATE_COMPLETE,
        kind="search_snippets",
        scope="result_set",
        usable=True,
        text=rendered,
        sources=[source_identity(url) for url in issued],
        provenance=provenance,
    )


def run_read_url(settings: WebToolSettings, params: Mapping[str, object]) -> dict[str, object]:
    """Read one window of the page a signed Result ID names."""
    provider = settings.searxng
    if provider is None:
        raise ServiceRefused("this gateway names no search instance, so no page is fetched")
    started_at = time.monotonic()
    now = settings.now()
    result_id = approvals.require_string(
        params.get("result_id"), "result_id", RESULT_ID_CHARACTER_CAP
    )
    start_index = approvals.require_integer(
        params.get("start_index"), "start_index", 0, 0, DOCUMENT_CHARACTER_CAP
    )
    max_characters = approvals.require_integer(
        params.get("max_chars"),
        "max_chars",
        min(WINDOW_CHARACTER_DEFAULT, settings.max_chars_per_fetch),
        1,
        min(WINDOW_CHARACTER_CAP, settings.max_chars_per_fetch),
    )
    if start_index + max_characters > DOCUMENT_CHARACTER_CAP:
        raise InvalidArgument(
            "start_index plus max_chars exceeds the "
            f"{DOCUMENT_CHARACTER_CAP} character document cap"
        )
    signing_key = approvals.read_secret_file(settings.token_key_file, "token signing")
    claim = redeem_result_id(signing_key, result_id, now)
    if claim.get("provider") != settings.provider:
        raise AuthorizationDenied(
            "the result_id was issued by another provider than the configured one"
        )
    url = cast(str, claim["canonical_url"])
    # The approved search opened an allowance over the URLs it returned, so
    # this is where the fetch's own authority is checked and spent.
    settings.spend_fetch(cast(str, claim["search_id"]), url)
    document, complete = provider.contents(url, DOCUMENT_CHARACTER_CAP)
    window = document[start_index : start_index + max_characters]
    truncated = len(document) > start_index + len(window) or not complete
    framed = wrap_untrusted(url, utc_timestamp(now), window, start_index, truncated)
    provenance = provenance_record(
        READ_URL_TOOL,
        url=url,
        status="success",
        provider_bytes=provider.response_bytes,
        text=window,
        started_at=started_at,
        now=now,
    )
    if not window:
        return result_document(
            operation=READ_URL_TOOL,
            outcome="failure",
            status="provider_content_error",
            state=STATE_INCOMPLETE,
            kind="none",
            scope="none",
            usable=False,
            text=f"the source at {url} carries no text at index {start_index}",
            sources=(),
            provenance=provenance,
        )
    return result_document(
        operation=READ_URL_TOOL,
        outcome="success",
        status="success",
        state=STATE_COMPLETE,
        kind="fetched_page",
        scope="document_window",
        usable=True,
        text=framed,
        sources=[source_identity(url)],
        provenance=provenance,
    )


def execute(settings: WebToolSettings, request: Request) -> Response:
    """Run one proposed tool call behind the session and the approval chain.

    A retrieval that reached the network and failed answers 200, because the
    model that asked for a page reads the incomplete state and the reason where
    a status code alone would leave the turn silent. Everything the boundary
    itself refuses -- an absent session, an unverified or replayed grant, an
    argument outside its bound -- answers its own status carrying the same
    document, so the page parses one shape.
    """
    started_at = time.monotonic()
    operation = "unknown"
    try:
        if not settings.session_admits(request):
            raise AuthorizationDenied("the gateway session admits this route")
        body = _body(request)
        operation = str(body.get("tool") or "")
        params = body.get("params")
        if not isinstance(params, dict):
            raise InvalidArgument("params is absent or is not an object")
        if operation == SEARCH_TOOL:
            return _json(200, run_search(settings, cast(Mapping[str, object], params)))
        if operation == READ_URL_TOOL:
            return _json(200, run_read_url(settings, cast(Mapping[str, object], params)))
        raise InvalidArgument(
            "tool names none of " + ", ".join(TOOL_NAMES) + f": {operation or 'the empty string'}"
        )
    except ToolError as error:
        document = result_document(
            operation=operation,
            outcome="failure",
            status=error.status,
            state=STATE_INCOMPLETE,
            kind="none",
            scope="none",
            usable=False,
            text=str(error),
            sources=(),
            provenance=provenance_record(
                operation,
                status=error.status,
                started_at=started_at,
                now=settings.now(),
            ),
        )
        if error.status in RETRIEVAL_FAILURE_TERMS:
            return _json(200, document)
        return _json(HTTP_STATUS_FOR_TERM.get(error.status, 400), document)


def tool_definitions(settings: WebToolSettings) -> dict[str, dict[str, object]]:
    """Return the two schemas a model proposes inside, keyed by tool identifier.

    The numeric maxima are the ones this executor enforces rather than the
    compiled ceiling, so `max_results` states the profile's own count and
    `max_chars` its own window; a model reading the listing proposes inside
    what the call would admit. Each schema is the OpenAI function object the
    request body carries, so the page forwards it rather than converting one.

    The schema states what this executor serves rather than what the tool lane
    admits, so the publication window and the cached-age bound are absent:
    `SearxngProvider.refuse_unhonored_arguments` refuses both, since the JSON
    API carries no publication interval and a mixed category answers from
    engines whose recency support differs. `authorization` is advertised and
    unrequired, because the approval route rather than the model issues it and
    the page strips the property before the definition reaches a request.
    """
    return {
        SEARCH_TOOL: {
            "type": "function",
            "function": {
                "name": SEARCH_TOOL,
                "description": (
                    "Search the web and return ranked results with titles, URLs, and "
                    "highlights. Each result carries a Result ID that read_url redeems "
                    "for the page text."
                ),
                "parameters": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": (
                                f"Search query, at most {QUERY_CHARACTER_CAP} characters."
                            ),
                        },
                        "max_results": {
                            "type": "integer",
                            "maximum": settings.max_results,
                            "description": (
                                f"Result count, 1 to {settings.max_results}. Default "
                                f"{min(RESULT_COUNT_DEFAULT, settings.max_results)}."
                            ),
                        },
                        "include_domains": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Admit these domains alone, at most 10.",
                        },
                        "exclude_domains": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Drop these domains, at most 10.",
                        },
                        "authorization": {
                            "type": "string",
                            "description": (
                                "Grant covering these exact search arguments, issued by "
                                "the approval route the human answers."
                            ),
                        },
                    },
                    "required": ["query"],
                },
            },
        },
        READ_URL_TOOL: {
            "type": "function",
            "function": {
                "name": READ_URL_TOOL,
                "description": (
                    "Read the text of a page named by a Result ID from a prior "
                    "web_search call. The Result ID is the only accepted reference; a "
                    "URL is refused."
                ),
                "parameters": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "result_id": {
                            "type": "string",
                            "description": "Result ID printed by web_search.",
                        },
                        "start_index": {
                            "type": "integer",
                            "description": "Character offset into the page text.",
                        },
                        "max_chars": {
                            "type": "integer",
                            "maximum": settings.max_chars_per_fetch,
                            "description": (
                                f"Characters to return, at most "
                                f"{settings.max_chars_per_fetch}. The reply names the "
                                "next start index when more text remains."
                            ),
                        },
                    },
                    "required": ["result_id"],
                },
            },
        },
    }


def routes(settings: WebToolSettings) -> tuple[Route, ...]:
    """The one execution route, mounted where the page already posts."""
    return (Route.make("POST", TOOLS_PATH, lambda request: execute(settings, request)),)
