#!/usr/bin/env python3
"""Serve two web-research tools to llama-server over stdio MCP.

llama-server spawns this process to enumerate tools, kills it, and spawns it
again for every invocation, so no in-memory state survives between calls. A
search result is therefore carried forward as an HMAC-signed opaque token that
names the canonical URL it was issued for, and fetch_exa accepts that token
alone. A model-authored URL reaches no network path.

The server name in the launch configuration is `web`, which llama-server
composes with the tool names into `web_search_exa` and `web_fetch_exa`. The
pinned llama-ui renders those two identifiers natively.

Two secrets stay outside the process image: the Exa API key and the token
signing key each live in a file that only its owner may read, and only the
paths cross into this child. The contents are read at call time and reach no
argument vector, environment value, log line, or error message.
"""

import base64
import datetime
import hashlib
import hmac
import json
import os
import stat
import sys
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request

SERVER_NAME = "web"
SERVER_VERSION = "1.0.0"
PROTOCOL_VERSION = "2025-06-18"
SUPPORTED_PROTOCOL_VERSIONS = ("2025-06-18", "2025-03-26", "2024-11-05")

QUERY_CHARACTER_CAP = 512
RESULT_COUNT_CAP = 10
DOMAIN_LIST_CAP = 10
DOMAIN_CHARACTER_CAP = 253
FETCH_CHARACTER_CAP = 24000
FETCH_CHARACTER_DEFAULT = 12000
HIGHLIGHT_COUNT_CAP = 3
REQUEST_TIMEOUT_SECONDS = 20.0
RESPONSE_BYTE_CAP = 4 * 1024 * 1024
MAX_AGE_HOURS_CAP = 24 * 365
TOKEN_LIFETIME_DEFAULT_SECONDS = 900
TOKEN_LIFETIME_MINIMUM_SECONDS = 60
TOKEN_LIFETIME_MAXIMUM_SECONDS = 3600
SECRET_BYTE_CAP = 4096
RESULT_CLAIM_CONTEXT = "result-id"
AUTHORIZATION_CLAIM_CONTEXT = "search-authorization"

EXA_SEARCH_ENDPOINT = "https://api.exa.ai/search"
EXA_CONTENTS_ENDPOINT = "https://api.exa.ai/contents"

UNTRUSTED_HEADER = "UNTRUSTED WEB CONTENT"
UNTRUSTED_FOOTER = "END UNTRUSTED WEB CONTENT"


class ToolError(Exception):
    """An expected execution failure: policy, input, or provider grounds.

    The message reaches the model inside an `isError` result, which is what
    lets the model correct its own call. A malformed request and an unexpected
    exception take JSON-RPC error codes instead, so the client distinguishes a
    tool that refused from a tool that broke.
    """


def sanitized_traceback(error):
    """Return a frame list of an unexpected exception with every value dropped.

    The exception message and the source lines can carry provider response text
    or an argument the caller supplied, so the diagnostic keeps the exception
    type and the file, line, and function of each frame and discards the rest.
    """
    frames = traceback.extract_tb(error.__traceback__)
    trail = " <- ".join(
        f"{os.path.basename(frame.filename)}:{frame.lineno} in {frame.name}"
        for frame in frames
    )
    return f"web-mcp internal error: {type(error).__name__} at {trail}"


def jsonrpc_error(identifier, code, message):
    return {
        "jsonrpc": "2.0",
        "id": identifier,
        "error": {"code": code, "message": message},
    }


def tool_result(identifier, text, is_error):
    return {
        "jsonrpc": "2.0",
        "id": identifier,
        "result": {
            "content": [{"type": "text", "text": text}],
            "isError": is_error,
        },
    }


def read_secret_file(path, purpose):
    """Return the contents of a key file that only its owner reads.

    The descriptor opens with O_NOFOLLOW and O_CLOEXEC, so a symlink planted at
    the configured path fails the open rather than redirecting the read, and no
    child of this process inherits the descriptor. The regular-file and mode
    checks run against fstat of that same descriptor, which leaves no window
    between the check and the read for a replacement. Every check runs per call
    because llama-server respawns the child for each invocation.
    """
    if not path:
        raise ToolError(
            f"the {purpose} key file is unconfigured, so the call reaches no "
            "network path"
        )
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    except OSError:
        raise ToolError(f"the {purpose} key file is unreadable: {path}") from None
    try:
        file_status = os.fstat(descriptor)
        if not stat.S_ISREG(file_status.st_mode):
            raise ToolError(f"the {purpose} key file is not a regular file: {path}")
        mode = stat.S_IMODE(file_status.st_mode)
        if mode & 0o077:
            raise ToolError(
                f"the {purpose} key file {path} is mode {mode:04o}; "
                "0600 is required before a call runs"
            )
        try:
            raw = os.read(descriptor, SECRET_BYTE_CAP)
        except OSError:
            raise ToolError(
                f"the {purpose} key file is unreadable: {path}"
            ) from None
    finally:
        os.close(descriptor)
    try:
        secret = raw.decode("utf-8").strip()
    except UnicodeDecodeError:
        raise ToolError(f"the {purpose} key file is not UTF-8 text: {path}") from None
    if not secret:
        raise ToolError(f"the {purpose} key file is empty: {path}")
    return secret


def resolve_token_lifetime(settings):
    """Return the configured token lifetime in seconds.

    The lifetime bounds replay of a leaked result identifier, so the admitted
    range runs from 60 seconds, below which a reasoning turn outlives its own
    search, to 3600, beyond which a transcript outlives the appliance session.
    A value outside the range refuses the call rather than being clamped, since
    a clamp hides an operator's mistake behind a working search.
    """
    raw = settings.get("token_lifetime") or ""
    if not raw:
        return TOKEN_LIFETIME_DEFAULT_SECONDS
    try:
        lifetime = int(raw)
    except ValueError:
        raise ToolError(
            "QWEN_WEB_TOKEN_LIFETIME_SECONDS is not an integer"
        ) from None
    if not (
        TOKEN_LIFETIME_MINIMUM_SECONDS <= lifetime <= TOKEN_LIFETIME_MAXIMUM_SECONDS
    ):
        raise ToolError(
            "QWEN_WEB_TOKEN_LIFETIME_SECONDS lies outside "
            f"[{TOKEN_LIFETIME_MINIMUM_SECONDS}, "
            f"{TOKEN_LIFETIME_MAXIMUM_SECONDS}]: {lifetime}"
        )
    return lifetime


def base64url_encode(payload):
    return base64.urlsafe_b64encode(payload).rstrip(b"=").decode("ascii")


def base64url_decode(text):
    padding = "=" * (-len(text) % 4)
    return base64.urlsafe_b64decode(text + padding)


def canonical_url(url):
    """Return the comparison form of a URL: scheme and host lowercased.

    Token issue and token redemption both run through this function, so a
    fetch matches its search on the same string the signature covers.
    """
    parts = urllib.parse.urlsplit(url)
    if parts.scheme.lower() not in ("http", "https"):
        raise ToolError(f"the result URL carries an unsupported scheme: {url}")
    if not parts.netloc:
        raise ToolError(f"the result URL names no host: {url}")
    return urllib.parse.urlunsplit(
        (
            parts.scheme.lower(),
            parts.netloc.lower(),
            parts.path,
            parts.query,
            "",
        )
    )


def sign_claim(signing_key, context, claim):
    """Return `payload.signature` for a claim bound to one context string.

    The HMAC covers the context and the base64url payload string rather than
    the decoded object, so an encoder that admits two spellings of one object
    still signs one byte string, and a search authorization never verifies as a
    result identifier.
    """
    payload = base64url_encode(
        json.dumps(claim, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )
    signature = base64url_encode(
        hmac.new(
            signing_key.encode("utf-8"),
            f"{context}:{payload}".encode("ascii"),
            hashlib.sha256,
        ).digest()
    )
    return f"{payload}.{signature}"


def verify_claim(signing_key, context, token, now, label):
    """Return the claim of a token whose signature verifies and whose term runs."""
    if not isinstance(token, str) or token.count(".") != 1:
        raise ToolError(f"the {label} is malformed")
    payload, signature = token.split(".")
    expected = base64url_encode(
        hmac.new(
            signing_key.encode("utf-8"),
            f"{context}:{payload}".encode("ascii"),
            hashlib.sha256,
        ).digest()
    )
    if not hmac.compare_digest(signature, expected):
        raise ToolError(f"the {label} signature fails verification")
    try:
        claim = json.loads(base64url_decode(payload).decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        raise ToolError(f"the {label} payload is malformed") from None
    if not isinstance(claim, dict):
        raise ToolError(f"the {label} payload is malformed")
    expiry = claim.get("expiry")
    if not isinstance(expiry, (int, float)) or now >= expiry:
        raise ToolError(f"the {label} has expired")
    return claim


def issue_result_id(
    signing_key, url, provider_name, search_id, issued_at, lifetime_seconds
):
    """Sign a result reference into an opaque token.

    `search_id` records which search issued the token and is provenance rather
    than an enforced check, since the process holds no registry to check it
    against.
    """
    return sign_claim(
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


def redeem_result_id(signing_key, result_id, now):
    """Return the claim of a result identifier this server issued.

    A tampered payload fails `compare_digest` and an expired claim fails the
    term check, so the only URL a fetch reaches is one a prior search returned
    inside the lifetime.
    """
    claim = verify_claim(
        signing_key, RESULT_CLAIM_CONTEXT, result_id, now, "result_id"
    )
    if "canonical_url" not in claim:
        raise ToolError("the result_id payload is malformed")
    claim["canonical_url"] = canonical_url(str(claim["canonical_url"]))
    return claim


def authorization_claim(
    query,
    include_domains,
    exclude_domains,
    published_after,
    published_before,
    max_results,
    expiry,
):
    """Return the canonical form of a search grant.

    Both the issuing subcommand and the serving path build the grant through
    this function, so the comparison runs over one spelling of every field:
    the query stripped, the domain lists normalized and sorted, and the dates
    in the calendar form `require_iso_date` produces.
    """
    return {
        "query": query.strip(),
        "include_domains": sorted(include_domains),
        "exclude_domains": sorted(exclude_domains),
        "published_after": published_after,
        "published_before": published_before,
        "max_results": max_results,
        "expiry": expiry,
    }


def enforce_search_authorization(
    settings, signing_key, query, max_results, constraints
):
    """Admit a search that an operator grant covers.

    A search query is model-authored, and a note the model reads can rewrite it
    the way `tool-08` rewrote a tool argument in every measured arm, so the
    signed grant rather than the model decides which query reaches the
    provider. `QWEN_WEB_SEARCH_AUTH=optional` admits an unauthorized search for
    an operator who accepts that exposure; the default refuses it.
    """
    mode = settings.get("search_auth") or "required"
    if mode not in ("required", "optional"):
        raise ToolError(
            f"QWEN_WEB_SEARCH_AUTH names an unknown mode: {mode}"
        )
    token = settings.get("_authorization")
    if not token:
        if mode == "required":
            raise ToolError(
                "search_exa requires an authorization token issued by "
                "`server.py authorize`; the operator grants the query rather "
                "than the model"
            )
        return
    granted = verify_claim(
        signing_key,
        AUTHORIZATION_CLAIM_CONTEXT,
        token,
        time.time(),
        "authorization",
    )
    requested = authorization_claim(
        query,
        constraints["include_domains"],
        constraints["exclude_domains"],
        constraints["published_after"],
        constraints["published_before"],
        max_results,
        granted.get("expiry"),
    )
    for field in (
        "query",
        "include_domains",
        "exclude_domains",
        "published_after",
        "published_before",
    ):
        if granted.get(field) != requested[field]:
            raise ToolError(
                f"the search arguments leave the authorization: {field} differs"
            )
    granted_results = granted.get("max_results")
    if not isinstance(granted_results, int) or max_results > granted_results:
        raise ToolError(
            "the search arguments leave the authorization: max_results exceeds "
            "the granted count"
        )


class Provider:
    """The two operations a web-research backend supplies.

    `search` returns a list of result records with `url` and optional `title`,
    `published`, `author`, and `highlights`. `contents` returns the extracted
    text of one already-issued URL.
    """

    name = "provider"

    def search(self, query, max_results, constraints):
        raise NotImplementedError

    def contents(self, url):
        raise NotImplementedError


class ExaProvider(Provider):
    """Exa's /search and /contents JSON APIs over urllib.

    The API key reaches the `x-api-key` header alone and is read per call from
    its file. The response body is read to one byte past the cap so an
    oversized body is refused during the read rather than after it.
    """

    name = "exa"

    def __init__(self, key_file_path):
        self.key_file_path = key_file_path

    def _post(self, endpoint, body):
        api_key = read_secret_file(self.key_file_path, "Exa API")
        request = urllib.request.Request(
            endpoint,
            data=json.dumps(body).encode("utf-8"),
            headers={
                "content-type": "application/json",
                "accept": "application/json",
                "x-api-key": api_key,
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(
                request, timeout=REQUEST_TIMEOUT_SECONDS
            ) as response:
                raw = response.read(RESPONSE_BYTE_CAP + 1)
        except urllib.error.HTTPError as error:
            raise ToolError(
                f"the provider rejected the request with status {error.code}"
            ) from None
        except Exception:
            raise ToolError("the provider request failed") from None
        if len(raw) > RESPONSE_BYTE_CAP:
            raise ToolError(
                f"the provider response exceeds the {RESPONSE_BYTE_CAP} byte cap"
            )
        try:
            document = json.loads(raw.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            raise ToolError("the provider response is not valid UTF-8 JSON") from None
        if not isinstance(document, dict):
            raise ToolError("the provider response is not a JSON object")
        return document

    def search(self, query, max_results, constraints):
        body = {"query": query, "numResults": max_results}
        if constraints["published_after"]:
            body["startPublishedDate"] = constraints["published_after"]
        if constraints["published_before"]:
            body["endPublishedDate"] = constraints["published_before"]
        if constraints["max_age_hours"] is not None:
            body["maxAgeHours"] = constraints["max_age_hours"]
        if constraints["include_domains"]:
            body["includeDomains"] = constraints["include_domains"]
        if constraints["exclude_domains"]:
            body["excludeDomains"] = constraints["exclude_domains"]
        document = self._post(EXA_SEARCH_ENDPOINT, body)
        results = document.get("results")
        return results if isinstance(results, list) else []

    def contents(self, url):
        document = self._post(
            EXA_CONTENTS_ENDPOINT, {"urls": [url], "text": True}
        )
        results = document.get("results")
        if not isinstance(results, list) or not results:
            raise ToolError("the provider returned no content for the result")
        return results[0]


class FakeProvider(Provider):
    """Fixture-backed provider that runs the tools with the network absent.

    The fixture document maps a query string to a result list and a canonical
    URL to a content record. A content record supplies `text` for ordinary
    fixtures or `text_base64` for a hostile one, which lets a fixture carry
    bytes that are invalid UTF-8 while the fixture file itself stays a legal
    UTF-8 JSON document.
    """

    name = "fake"

    def __init__(self, fixture_path):
        if not fixture_path:
            raise ToolError(
                "the fake provider requires QWEN_WEB_FAKE_FIXTURES to name a "
                "fixture document"
            )
        try:
            with open(fixture_path, "rb") as handle:
                self.document = json.loads(handle.read().decode("utf-8"))
        except (OSError, ValueError, UnicodeDecodeError):
            raise ToolError(
                f"the fixture document is unreadable: {fixture_path}"
            ) from None

    def search(self, query, max_results, constraints):
        include_domains = constraints["include_domains"]
        exclude_domains = constraints["exclude_domains"]
        results = self.document.get("search", {}).get(query, [])
        selected = []
        for record in results:
            url = record.get("url", "")
            host = urllib.parse.urlsplit(url).netloc.lower()
            if include_domains and not any(
                host == domain or host.endswith("." + domain)
                for domain in include_domains
            ):
                continue
            if any(
                host == domain or host.endswith("." + domain)
                for domain in exclude_domains
            ):
                continue
            selected.append(record)
        return selected[:max_results]

    def contents(self, url):
        record = self.document.get("contents", {}).get(url)
        if record is None:
            raise ToolError("the provider returned no content for the result")
        return record


def select_provider(settings):
    if settings["provider"] == "fake":
        return FakeProvider(settings["fixtures"])
    return ExaProvider(settings["exa_key_file"])


def require_string(arguments, key, cap, required=True, default=""):
    value = arguments.get(key, default)
    if value is None:
        value = default
    if not isinstance(value, str):
        raise ToolError(f"{key} must be a string")
    value = value.strip()
    if required and not value:
        raise ToolError(f"{key} is required")
    if len(value) > cap:
        raise ToolError(f"{key} exceeds the {cap} character cap")
    return value


def require_integer(arguments, key, default, minimum, maximum):
    value = arguments.get(key, default)
    if value is None:
        value = default
    if isinstance(value, bool) or not isinstance(value, int):
        raise ToolError(f"{key} must be an integer")
    if value < minimum or value > maximum:
        raise ToolError(f"{key} must lie between {minimum} and {maximum}")
    return value


def require_iso_date(arguments, key):
    """Return an ISO 8601 calendar date, or the empty string when absent.

    `datetime.date.fromisoformat` accepts the extended forms Python admits, so
    the value is reformatted to YYYY-MM-DD; the reformatted string is what the
    provider body and the authorization claim both carry, which keeps one
    spelling of a date on both sides of the comparison.
    """
    value = arguments.get(key)
    if value in (None, ""):
        return ""
    if not isinstance(value, str):
        raise ToolError(f"{key} must be an ISO 8601 date string")
    try:
        parsed = datetime.date.fromisoformat(value.strip())
    except ValueError:
        raise ToolError(f"{key} is not an ISO 8601 date") from None
    return parsed.isoformat()


def require_optional_integer(arguments, key, minimum, maximum):
    if arguments.get(key) is None:
        return None
    return require_integer(arguments, key, minimum, minimum, maximum)


def require_domain_list(arguments, key):
    value = arguments.get(key) or []
    if not isinstance(value, list):
        raise ToolError(f"{key} must be a list of domain names")
    if len(value) > DOMAIN_LIST_CAP:
        raise ToolError(f"{key} exceeds the {DOMAIN_LIST_CAP} entry cap")
    domains = []
    for entry in value:
        if not isinstance(entry, str) or not entry.strip():
            raise ToolError(f"{key} entries must be non-empty domain names")
        entry = entry.strip().lower()
        if len(entry) > DOMAIN_CHARACTER_CAP:
            raise ToolError(
                f"{key} entries exceed the {DOMAIN_CHARACTER_CAP} character cap"
            )
        domains.append(entry)
    return domains


def decode_content_text(record):
    """Return the UTF-8 text of a content record, refusing anything else.

    A `text_base64` field decodes through a strict UTF-8 decode, so a body that
    is not valid UTF-8 is refused here rather than reaching the model as
    replacement characters.
    """
    if "text_base64" in record:
        try:
            raw = base64.b64decode(record["text_base64"], validate=True)
        except (ValueError, TypeError):
            raise ToolError("the provider content is not valid base64") from None
        if len(raw) > RESPONSE_BYTE_CAP:
            raise ToolError(
                f"the provider content exceeds the {RESPONSE_BYTE_CAP} byte cap"
            )
        try:
            return raw.decode("utf-8")
        except UnicodeDecodeError:
            raise ToolError("the provider content is not valid UTF-8") from None
    text = record.get("text", "")
    if not isinstance(text, str):
        raise ToolError("the provider content is not text")
    if len(text.encode("utf-8")) > RESPONSE_BYTE_CAP:
        raise ToolError(
            f"the provider content exceeds the {RESPONSE_BYTE_CAP} byte cap"
        )
    return text


def render_search_results(
    results, provider_name, signing_key, search_id, issued_at, lifetime_seconds
):
    """Render one block per result in the layout the pinned llama-ui parses.

    The renderer reads `Title:`, `URL:`, `Published:`, `Author:`, `Highlights:`
    and the `---` separator, so every block writes those keys in that order and
    appends the result identifier the fetch tool redeems.
    """
    blocks = []
    for record in results:
        url = canonical_url(str(record.get("url", "")))
        highlights = record.get("highlights") or []
        if not isinstance(highlights, list):
            highlights = []
        lines = [
            f"Title: {record.get('title') or url}",
            f"URL: {url}",
            f"Published: {record.get('publishedDate') or record.get('published') or ''}",
            f"Author: {record.get('author') or ''}",
            "Highlights:",
        ]
        for highlight in highlights[:HIGHLIGHT_COUNT_CAP]:
            lines.append(f"- {str(highlight).strip()}")
        lines.append(
            "Result ID: "
            + issue_result_id(
                signing_key,
                url,
                provider_name,
                search_id,
                issued_at,
                lifetime_seconds,
            )
        )
        blocks.append("\n".join(lines))
    if not blocks:
        return "No results."
    return "\n---\n".join(blocks) + "\n---"


def wrap_untrusted(url, retrieved_at, text):
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return "\n".join(
        [
            UNTRUSTED_HEADER,
            f"Source: {url}",
            f"Retrieved: {retrieved_at}",
            f"Content SHA-256: {digest}",
            text,
            UNTRUSTED_FOOTER,
        ]
    )


def utc_timestamp(now):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now))


def call_search(settings, arguments):
    query = require_string(arguments, "query", QUERY_CHARACTER_CAP)
    max_results = require_integer(arguments, "max_results", 5, 1, RESULT_COUNT_CAP)
    constraints = {
        "published_after": require_iso_date(arguments, "published_after"),
        "published_before": require_iso_date(arguments, "published_before"),
        "max_age_hours": require_optional_integer(
            arguments, "max_age_hours", 0, MAX_AGE_HOURS_CAP
        ),
        "include_domains": require_domain_list(arguments, "include_domains"),
        "exclude_domains": require_domain_list(arguments, "exclude_domains"),
    }
    if (
        constraints["published_after"]
        and constraints["published_before"]
        and constraints["published_after"] > constraints["published_before"]
    ):
        raise ToolError("published_after falls after published_before")
    settings = dict(settings)
    settings["_authorization"] = require_string(
        arguments, "authorization", 4096, required=False, default=""
    )
    signing_key = read_secret_file(settings["token_key_file"], "token signing")
    enforce_search_authorization(
        settings, signing_key, query, max_results, constraints
    )
    provider = select_provider(settings)
    results = provider.search(query, max_results, constraints)
    issued_at = int(time.time())
    search_id = base64url_encode(os.urandom(9))
    return render_search_results(
        results[:max_results],
        provider.name,
        signing_key,
        search_id,
        issued_at,
        resolve_token_lifetime(settings),
    )


def call_fetch(settings, arguments):
    result_id = arguments.get("result_id")
    start_index = require_integer(arguments, "start_index", 0, 0, 1 << 30)
    max_chars = require_integer(
        arguments, "max_chars", FETCH_CHARACTER_DEFAULT, 1, FETCH_CHARACTER_CAP
    )
    signing_key = read_secret_file(settings["token_key_file"], "token signing")
    now = time.time()
    claim = redeem_result_id(signing_key, result_id, now)
    url = claim["canonical_url"]
    provider = select_provider(settings)
    if claim.get("provider") != provider.name:
        raise ToolError(
            "the result_id was issued by another provider than the configured one"
        )
    record = provider.contents(url)
    text = decode_content_text(record)
    window = text[start_index : start_index + max_chars]
    if not window:
        window = ""
    return wrap_untrusted(url, utc_timestamp(now), window)


TOOL_DEFINITIONS = [
    {
        "name": "search_exa",
        "description": (
            "Search the web and return ranked results with titles, URLs, and "
            "highlights. Each result carries a Result ID that fetch_exa "
            "redeems for the page text."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query, at most 512 characters.",
                },
                "max_results": {
                    "type": "integer",
                    "description": "Result count, 1 to 10. Default 5.",
                },
                "published_after": {
                    "type": "string",
                    "description": (
                        "ISO 8601 date; results published before it are dropped."
                    ),
                },
                "published_before": {
                    "type": "string",
                    "description": (
                        "ISO 8601 date; results published after it are dropped."
                    ),
                },
                "max_age_hours": {
                    "type": "integer",
                    "description": (
                        "Cached page age the provider may serve. 0 forces a "
                        "live crawl. Omitted leaves the provider default."
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
                        "Operator-issued grant covering these exact search "
                        "arguments. Supply the token the user provided."
                    ),
                },
            },
            "required": ["query"],
        },
    },
    {
        "name": "fetch_exa",
        "description": (
            "Fetch the text of a page named by a Result ID from a prior "
            "search_exa call. The Result ID is the only accepted reference; a "
            "URL is refused."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "result_id": {
                    "type": "string",
                    "description": "Result ID printed by search_exa.",
                },
                "start_index": {
                    "type": "integer",
                    "description": "Character offset into the page text.",
                },
                "max_chars": {
                    "type": "integer",
                    "description": "Characters to return, at most 24000.",
                },
            },
            "required": ["result_id"],
        },
    },
]

TOOL_HANDLERS = {"search_exa": call_search, "fetch_exa": call_fetch}


def settings_from_environment(argv):
    settings = {
        "provider": os.environ.get("QWEN_WEB_PROVIDER", "exa"),
        "exa_key_file": os.environ.get("QWEN_WEB_EXA_KEY_FILE", ""),
        "token_key_file": os.environ.get("QWEN_WEB_TOKEN_KEY_FILE", ""),
        "fixtures": os.environ.get("QWEN_WEB_FAKE_FIXTURES", ""),
        "token_lifetime": os.environ.get("QWEN_WEB_TOKEN_LIFETIME_SECONDS", ""),
        "search_auth": os.environ.get("QWEN_WEB_SEARCH_AUTH", "required"),
    }
    option_keys = {
        "--provider": "provider",
        "--exa-key-file": "exa_key_file",
        "--token-key-file": "token_key_file",
        "--fixtures": "fixtures",
    }
    index = 0
    while index < len(argv):
        key = option_keys.get(argv[index])
        if key is None or index + 1 >= len(argv):
            usage()
        settings[key] = argv[index + 1]
        index += 2
    if settings["provider"] not in ("exa", "fake"):
        usage()
    return settings


def usage():
    sys.stderr.write(
        "usage: server.py [--provider exa|fake] [--exa-key-file PATH]"
        " [--token-key-file PATH] [--fixtures PATH]\n"
        "       server.py authorize --token-key-file PATH --query TEXT"
        " [--include-domain D]... [--exclude-domain D]..."
        " [--published-after DATE] [--published-before DATE]"
        " [--max-results N] [--lifetime SECONDS]\n"
    )
    raise SystemExit(2)


def run_authorize(argv):
    """Print a search grant for the exact arguments an operator names.

    The subcommand runs outside the MCP session, so the operator or the user
    interface issues the grant and the model receives a token it can spend on
    one query alone. The grant is signed with the same key file the server
    verifies against, and the key never leaves that file.
    """
    fields = {
        "token_key_file": os.environ.get("QWEN_WEB_TOKEN_KEY_FILE", ""),
        "query": None,
        "published_after": "",
        "published_before": "",
        "max_results": 5,
        "lifetime": TOKEN_LIFETIME_DEFAULT_SECONDS,
    }
    include_domains = []
    exclude_domains = []
    index = 0
    while index < len(argv):
        option = argv[index]
        if index + 1 >= len(argv):
            usage()
        value = argv[index + 1]
        if option == "--token-key-file":
            fields["token_key_file"] = value
        elif option == "--query":
            fields["query"] = value
        elif option == "--include-domain":
            include_domains.append(value)
        elif option == "--exclude-domain":
            exclude_domains.append(value)
        elif option == "--published-after":
            fields["published_after"] = value
        elif option == "--published-before":
            fields["published_before"] = value
        elif option in ("--max-results", "--lifetime"):
            try:
                fields[option[2:].replace("-", "_")] = int(value)
            except ValueError:
                usage()
        else:
            usage()
        index += 2
    if fields["query"] is None:
        usage()
    arguments = {
        "query": fields["query"],
        "published_after": fields["published_after"],
        "published_before": fields["published_before"],
        "include_domains": include_domains,
        "exclude_domains": exclude_domains,
        "max_results": fields["max_results"],
    }
    try:
        claim = authorization_claim(
            require_string(arguments, "query", QUERY_CHARACTER_CAP),
            require_domain_list(arguments, "include_domains"),
            require_domain_list(arguments, "exclude_domains"),
            require_iso_date(arguments, "published_after"),
            require_iso_date(arguments, "published_before"),
            require_integer(arguments, "max_results", 5, 1, RESULT_COUNT_CAP),
            int(time.time())
            + resolve_token_lifetime({"token_lifetime": str(fields["lifetime"])}),
        )
        signing_key = read_secret_file(fields["token_key_file"], "token signing")
    except ToolError as error:
        sys.stderr.write(f"{error}\n")
        return 2
    sys.stdout.write(
        sign_claim(signing_key, AUTHORIZATION_CLAIM_CONTEXT, claim) + "\n"
    )
    return 0


def handle_request(settings, message):
    """Return a JSON-RPC response object, or None for a notification.

    A protocol fault answers with a JSON-RPC error; a tool that refuses its
    arguments answers with a successful result carrying `isError`, which is
    what the MCP client surfaces to the model.
    """
    method = message.get("method")
    identifier = message.get("id")
    if method == "notifications/initialized" or identifier is None:
        return None
    if method == "initialize":
        requested = (message.get("params") or {}).get("protocolVersion")
        version = (
            requested if requested in SUPPORTED_PROTOCOL_VERSIONS else PROTOCOL_VERSION
        )
        return {
            "jsonrpc": "2.0",
            "id": identifier,
            "result": {
                "protocolVersion": version,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
            },
        }
    if method == "ping":
        return {"jsonrpc": "2.0", "id": identifier, "result": {}}
    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": identifier,
            "result": {"tools": TOOL_DEFINITIONS},
        }
    if method == "tools/call":
        params = message.get("params") or {}
        handler = TOOL_HANDLERS.get(params.get("name"))
        if handler is None:
            return jsonrpc_error(
                identifier, -32602, f"unknown tool: {params.get('name')}"
            )
        arguments = params.get("arguments")
        if arguments is None:
            arguments = {}
        if not isinstance(arguments, dict):
            return jsonrpc_error(
                identifier, -32602, "arguments must be a JSON object"
            )
        try:
            text = handler(settings, arguments)
        except ToolError as error:
            return tool_result(identifier, str(error), True)
        except Exception as error:
            sys.stderr.write(sanitized_traceback(error) + "\n")
            sys.stderr.flush()
            return jsonrpc_error(
                identifier, -32603, "internal error during tool execution"
            )
        return tool_result(identifier, text, False)
    return jsonrpc_error(identifier, -32601, f"unknown method: {method}")


def main(argv):
    if argv and argv[0] == "authorize":
        return run_authorize(argv[1:])
    settings = settings_from_environment(argv)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            response = jsonrpc_error(None, -32700, "parse error")
        else:
            if not isinstance(message, dict):
                response = jsonrpc_error(None, -32600, "invalid request")
            else:
                response = handle_request(settings, message)
        if response is not None:
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
