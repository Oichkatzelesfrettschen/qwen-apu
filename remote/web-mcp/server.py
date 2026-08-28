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
import re
import sqlite3
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
WINDOW_CHARACTER_CAP = 24000
WINDOW_CHARACTER_DEFAULT = 12000
HIGHLIGHT_COUNT_CAP = 3
TITLE_CHARACTER_CAP = 300
AUTHOR_CHARACTER_CAP = 200
HIGHLIGHT_CHARACTER_CAP = 1200
SEARCH_OUTPUT_CHARACTER_CAP = 16000
RESULT_ID_CHARACTER_CAP = 4096
URL_CHARACTER_CAP = 2048
DOCUMENT_CHARACTER_CAP = 131072
REQUEST_TIMEOUT_SECONDS = 20.0
# The HTTP cap defends this process against a provider response of any size;
# the document cap bounds how much page text one fetched result may hold; the
# window cap bounds one reply. Three separate limits, three separate failures.
HTTP_RESPONSE_BYTE_CAP = 4 * 1024 * 1024
MAX_AGE_HOURS_CAP = 24 * 365
TOKEN_LIFETIME_DEFAULT_SECONDS = 900
TOKEN_LIFETIME_MINIMUM_SECONDS = 60
TOKEN_LIFETIME_MAXIMUM_SECONDS = 3600
SECRET_BYTE_CAP = 4096
RESULT_CLAIM_CONTEXT = "result-id"
AUTHORIZATION_CLAIM_CONTEXT = "search-authorization"

SEPARATOR_PATTERN = re.compile(r"^-{3,}$")
FAILURE_TAG_PATTERN = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")
HOSTNAME_PATTERN = re.compile(
    r"^(?=.{1,253}$)[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?"
    r"(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$"
)

EXA_SEARCH_ENDPOINT = "https://api.exa.ai/search"
EXA_CONTENTS_ENDPOINT = "https://api.exa.ai/contents"

UNTRUSTED_HEADER = "BEGIN UNTRUSTED WEB CONTENT"
UNTRUSTED_FOOTER = "END UNTRUSTED WEB CONTENT"
NONCE_BYTES = 12

SEARCH_PER_MINUTE_DEFAULT = 10
FETCH_PER_MINUTE_DEFAULT = 20
PROVIDER_DAILY_BUDGET_DEFAULT = 500
LEDGER_FILE_NAME = "web-mcp-state.sqlite3"


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
    if len(url) > URL_CHARACTER_CAP:
        raise ToolError(
            f"the result URL exceeds the {URL_CHARACTER_CAP} character cap"
        )
    parts = urllib.parse.urlsplit(url)
    if parts.scheme.lower() not in ("http", "https"):
        raise ToolError(f"the result URL carries an unsupported scheme: {url}")
    if not parts.netloc:
        raise ToolError(f"the result URL names no host: {url}")
    if "@" in parts.netloc:
        raise ToolError("the result URL carries userinfo, which is refused")
    if any(character in url for character in ("\n", "\r", "\t", " ")):
        raise ToolError("the result URL carries whitespace, which is refused")
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
    max_age_hours,
    max_results,
    expiry,
):
    """Return the canonical form of a search grant.

    `max_age_hours` is covered because 0 forces a live crawl, which is the one
    search parameter that spends provider budget on the model's word. Both the
    issuing subcommand and the serving path build the grant through this
    function, so the comparison runs over one spelling of every field:
    the query stripped, the domain lists normalized and sorted, and the dates
    in the calendar form `require_iso_date` produces.
    """
    return {
        "query": query.strip(),
        "include_domains": sorted(include_domains),
        "exclude_domains": sorted(exclude_domains),
        "published_after": published_after,
        "published_before": published_before,
        "max_age_hours": max_age_hours,
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
        constraints["max_age_hours"],
        max_results,
        granted.get("expiry"),
    )
    for field in (
        "query",
        "include_domains",
        "exclude_domains",
        "published_after",
        "published_before",
        "max_age_hours",
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

    def contents(self, url, max_characters):
        raise NotImplementedError


def select_by_url(entries, url):
    """Return the entry whose `url` or `id` canonicalizes to `url`.

    A provider response is attacker-influenced through the page it describes,
    so the entry is selected by the URL the signed claim carries rather than by
    position in the array.
    """
    if not isinstance(entries, list):
        return None
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        for key in ("url", "id"):
            candidate = entry.get(key)
            if not isinstance(candidate, str):
                continue
            try:
                if canonical_url(candidate) == url:
                    return entry
            except ToolError:
                continue
    return None


def failure_tag(status):
    """Return the provider's failure tag reduced to a safe short token.

    The tag reaches the model inside an error message, so a value that is not a
    short identifier is replaced rather than forwarded.
    """
    error = status.get("error")
    tag = error.get("tag") if isinstance(error, dict) else None
    if isinstance(tag, str) and FAILURE_TAG_PATTERN.match(tag.strip()):
        return tag.strip()
    return "unspecified"


class ExaProvider(Provider):
    """Exa's /search and /contents JSON APIs over urllib.

    The API key reaches the `x-api-key` header alone and is read per call from
    its file. The response body is read to one byte past the cap so an
    oversized body is refused during the read rather than after it.
    """

    name = "exa"

    def __init__(self, key_file_path):
        self.key_file_path = key_file_path
        self.response_bytes = 0

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
                raw = response.read(HTTP_RESPONSE_BYTE_CAP + 1)
            self.response_bytes += len(raw)
        except urllib.error.HTTPError as error:
            raise ToolError(
                f"the provider rejected the request with status {error.code}"
            ) from None
        except Exception:
            raise ToolError("the provider request failed") from None
        if len(raw) > HTTP_RESPONSE_BYTE_CAP:
            raise ToolError(
                f"the provider response exceeds the {HTTP_RESPONSE_BYTE_CAP} byte cap"
            )
        try:
            document = json.loads(raw.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            raise ToolError("the provider response is not valid UTF-8 JSON") from None
        if not isinstance(document, dict):
            raise ToolError("the provider response is not a JSON object")
        return document

    def search(self, query, max_results, constraints):
        body = {
            "query": query,
            "numResults": max_results,
            "contents": {
                "highlights": {
                    "query": query,
                    "maxCharacters": HIGHLIGHT_CHARACTER_CAP,
                }
            },
        }
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

    def contents(self, url, max_characters):
        """Return the content record Exa reports as retrieved for this URL.

        Exa answers a contents request with a `statuses` array beside
        `results`, and a failed URL still occupies a position in the response,
        so taking `results[0]` returns another URL's page whenever the
        requested one failed or the provider reordered the array. The status
        for this URL must read success and a result must name this URL before
        any text is returned.
        """
        document = self._post(
            EXA_CONTENTS_ENDPOINT,
            {"urls": [url], "text": {"maxCharacters": max_characters}},
        )
        status = select_by_url(document.get("statuses"), url)
        if status is None:
            raise ToolError("the provider reported no status for the result")
        if str(status.get("status", "")).lower() != "success":
            raise ToolError(
                "the provider could not retrieve the result: "
                + failure_tag(status)
            )
        record = select_by_url(document.get("results"), url)
        if record is None:
            raise ToolError("the provider returned no content for the result")
        return record


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
        self.response_bytes = 0
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

    def contents(self, url, max_characters):
        record = self.document.get("contents", {}).get(url)
        if record is None:
            raise ToolError("the provider returned no content for the result")
        return record


class Ledger:
    """A rate ledger and audit trail that outlive the process.

    llama-server kills the child after every call, so a counter in memory
    resets between two invocations and bounds nothing. SQLite in the state
    directory carries the counters across spawns, and BEGIN IMMEDIATE takes the
    database write lock for the whole read-modify-write of a bucket, so two
    children spawned for concurrent calls serialize rather than reading one
    count and both writing it back.
    """

    def __init__(self, directory):
        os.makedirs(directory, mode=0o700, exist_ok=True)
        self.connection = sqlite3.connect(
            os.path.join(directory, LEDGER_FILE_NAME),
            timeout=10.0,
            isolation_level=None,
        )
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS buckets ("
            "name TEXT PRIMARY KEY, window_start INTEGER, used INTEGER)"
        )
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS audit ("
            "recorded_at TEXT, profile TEXT, operation TEXT, query_sha256 TEXT,"
            " domains TEXT, result_count INTEGER, fetched_host TEXT,"
            " provider_bytes INTEGER, returned_characters INTEGER,"
            " latency_ms INTEGER, status TEXT)"
        )

    def consume(self, name, window_seconds, limit, now):
        window_start = int(now) - int(now) % window_seconds
        self.connection.execute("BEGIN IMMEDIATE")
        try:
            row = self.connection.execute(
                "SELECT window_start, used FROM buckets WHERE name = ?", (name,)
            ).fetchone()
            used = row[1] if row and row[0] == window_start else 0
            if used >= limit:
                raise ToolError(
                    f"the {name} rate limit of {limit} per "
                    f"{window_seconds} seconds is exhausted"
                )
            self.connection.execute(
                "INSERT INTO buckets(name, window_start, used) VALUES(?, ?, ?) "
                "ON CONFLICT(name) DO UPDATE SET window_start = excluded.window_start,"
                " used = excluded.used",
                (name, window_start, used + 1),
            )
            self.connection.execute("COMMIT")
        except BaseException:
            self.connection.execute("ROLLBACK")
            raise

    def record(self, row):
        """Append one audit row.

        The row carries the SHA-256 of the query rather than the query, the
        host rather than the URL, and byte and character counts rather than any
        text, so the trail states what ran without retaining a secret, a token,
        or a page body.
        """
        self.connection.execute(
            "INSERT INTO audit VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                row["recorded_at"],
                row["profile"],
                row["operation"],
                row["query_sha256"],
                row["domains"],
                row["result_count"],
                row["fetched_host"],
                row["provider_bytes"],
                row["returned_characters"],
                row["latency_ms"],
                row["status"],
            ),
        )
        self.connection.commit()

    def close(self):
        self.connection.close()


def integer_setting(settings, key, default):
    raw = settings.get(key) or ""
    if not raw:
        return default
    try:
        value = int(raw)
    except ValueError:
        raise ToolError(f"{key} is not an integer") from None
    if value < 1:
        raise ToolError(f"{key} must be positive")
    return value


def open_ledger(settings):
    """Return the ledger for this call.

    A state directory is what makes a limit persist across the respawn, so a
    provider that spends money and reaches the network refuses to run without
    one: an unset or unusable QWEN_WEB_STATE_DIR fails the call rather than
    serving it unmetered and unaudited. The fake provider reaches no network and
    spends nothing, so it runs unmetered and a fixture-driven test needs no
    directory.
    """
    directory = settings.get("state_dir") or ""
    if not directory:
        if settings.get("provider") == "fake":
            return None
        raise ToolError(
            "QWEN_WEB_STATE_DIR names no directory, so the rate ledger cannot "
            "persist across the respawn and the call is refused rather than "
            "served unmetered"
        )
    try:
        return Ledger(directory)
    except (OSError, sqlite3.Error):
        raise ToolError(
            "QWEN_WEB_STATE_DIR names a directory the ledger cannot open: "
            f"{directory}"
        ) from None


def spend_budget(ledger, settings, operation, now):
    per_minute = (
        integer_setting(settings, "search_per_minute", SEARCH_PER_MINUTE_DEFAULT)
        if operation == "search"
        else integer_setting(
            settings, "fetch_per_minute", FETCH_PER_MINUTE_DEFAULT
        )
    )
    ledger.consume(f"{operation}-minute", 60, per_minute, now)
    ledger.consume(
        "provider-day",
        86400,
        integer_setting(
            settings, "daily_budget", PROVIDER_DAILY_BUDGET_DEFAULT
        ),
        now,
    )


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
        entry = entry.strip().lower().rstrip(".")
        if len(entry) > DOMAIN_CHARACTER_CAP:
            raise ToolError(
                f"{key} entries exceed the {DOMAIN_CHARACTER_CAP} character cap"
            )
        if not HOSTNAME_PATTERN.match(entry):
            raise ToolError(f"{key} carries an entry that is not a hostname")
        domains.append(entry)
    return domains


def decode_content_text(record):
    """Return the UTF-8 text of a content record, bounded at the document cap.

    A `text_base64` field decodes through a strict UTF-8 decode, so a body that
    is not valid UTF-8 is refused here rather than reaching the model as
    replacement characters. A record above the HTTP byte cap is refused as a
    provider defect, and a document above the character cap is truncated, which
    the reply reports on its `Possibly Truncated:` line.
    """
    if "text_base64" in record:
        try:
            raw = base64.b64decode(record["text_base64"], validate=True)
        except (ValueError, TypeError):
            raise ToolError("the provider content is not valid base64") from None
        if len(raw) > HTTP_RESPONSE_BYTE_CAP:
            raise ToolError(
                f"the provider content exceeds the {HTTP_RESPONSE_BYTE_CAP} byte cap"
            )
        try:
            return raw.decode("utf-8")[:DOCUMENT_CHARACTER_CAP]
        except UnicodeDecodeError:
            raise ToolError("the provider content is not valid UTF-8") from None
    text = record.get("text", "")
    if not isinstance(text, str):
        raise ToolError("the provider content is not text")
    if len(text.encode("utf-8")) > HTTP_RESPONSE_BYTE_CAP:
        raise ToolError(
            f"the provider content exceeds the {HTTP_RESPONSE_BYTE_CAP} byte cap"
        )
    return text[:DOCUMENT_CHARACTER_CAP]


def render_search_results(
    results, provider_name, signing_key, search_id, issued_at, lifetime_seconds
):
    """Render one block per result in the layout the pinned llama-ui parses.

    The renderer treats everything after `Highlights:` up to the `---`
    separator as highlight text, so the result identifier and the trust label
    precede that key and the highlight lines are the last content in a block.
    `Trust: untrusted-web-result` states in the rendered surface what the
    wrapper enforces: the title, author, and highlight text below it are
    attacker-chosen. A `Results Omitted:` count follows the final separator
    where the output cap dropped results, so a short list is distinguishable
    from a short answer; the line sits outside every block, which keeps it
    clear of the highlight region.
    """
    blocks = []
    rendered_characters = 0
    for record in results:
        url = canonical_url(str(record.get("url", "")))
        highlights = record.get("highlights") or []
        if not isinstance(highlights, list):
            highlights = []
        published = record.get("publishedDate") or record.get("published") or ""
        lines = [
            f"Title: {clip(record.get('title') or url, TITLE_CHARACTER_CAP)}",
            f"URL: {url}",
            f"Published: {clip(published, 64)}",
            f"Author: {clip(record.get('author') or '', AUTHOR_CHARACTER_CAP)}",
            "Result ID: "
            + issue_result_id(
                signing_key,
                url,
                provider_name,
                search_id,
                issued_at,
                lifetime_seconds,
            ),
            "Trust: untrusted-web-result",
            "Highlights:",
        ]
        for highlight in highlights[:HIGHLIGHT_COUNT_CAP]:
            lines.append(f"- {clip(highlight, HIGHLIGHT_CHARACTER_CAP)}")
        block = "\n".join(lines)
        rendered_characters += len(block) + 4
        if rendered_characters > SEARCH_OUTPUT_CHARACTER_CAP:
            break
        blocks.append(block)
    if not blocks:
        return "No results."
    rendered = "\n---\n".join(blocks) + "\n---"
    omitted = len(results) - len(blocks)
    if omitted:
        rendered += f"\nResults Omitted: {omitted}"
    return rendered


def clip(value, cap):
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


def wrap_untrusted(url, retrieved_at, window, start_index, truncated):
    """Frame one window of page text with the state a next call needs.

    The frame carries a nonce drawn after retrieval and absent from the window,
    so page text cannot write the line that closes the frame: a body holding
    the literal footer meets a delimiter whose nonce it could not have
    predicted, and the enclosing turn still reads one frame.

    `Next Start Index` names the offset that continues the document and reads
    `end` where the window reached the last character the document holds, so
    paging is decided by the server's own count rather than by the model's
    arithmetic over a body it cannot measure.
    """
    nonce = base64url_encode(os.urandom(NONCE_BYTES))
    while nonce in window:
        nonce = base64url_encode(os.urandom(NONCE_BYTES))
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


def utc_timestamp(now):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now))


def search_id_for():
    return base64url_encode(os.urandom(9))


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
    ledger = open_ledger(settings)
    started = time.monotonic()
    now = time.time()
    audit = {
        "recorded_at": utc_timestamp(now),
        "profile": settings.get("profile") or "default",
        "operation": "search",
        "query_sha256": hashlib.sha256(query.encode("utf-8")).hexdigest(),
        "domains": ",".join(
            [f"+{domain}" for domain in constraints["include_domains"]]
            + [f"-{domain}" for domain in constraints["exclude_domains"]]
        ),
        "result_count": 0,
        "fetched_host": "",
        "provider_bytes": 0,
        "returned_characters": 0,
        "latency_ms": 0,
        "status": "refused",
    }
    try:
        signing_key = read_secret_file(settings["token_key_file"], "token signing")
        enforce_search_authorization(
            settings, signing_key, query, max_results, constraints
        )
        if ledger is not None:
            spend_budget(ledger, settings, "search", now)
        provider = select_provider(settings)
        results = provider.search(query, max_results, constraints)[:max_results]
        rendered = render_search_results(
            results,
            provider.name,
            signing_key,
            search_id_for(),
            int(now),
            resolve_token_lifetime(settings),
        )
        audit["result_count"] = len(
            [line for line in rendered.splitlines() if line.startswith("URL: ")]
        )
        audit["provider_bytes"] = provider.response_bytes
        audit["returned_characters"] = len(rendered)
        audit["status"] = "success"
        return rendered
    except ToolError:
        raise
    except Exception:
        audit["status"] = "error"
        raise
    finally:
        audit["latency_ms"] = int((time.monotonic() - started) * 1000)
        if ledger is not None:
            ledger.record(audit)
            ledger.close()


def call_fetch(settings, arguments):
    result_id = require_string(arguments, "result_id", RESULT_ID_CHARACTER_CAP)
    start_index = require_integer(
        arguments, "start_index", 0, 0, DOCUMENT_CHARACTER_CAP
    )
    max_chars = require_integer(
        arguments, "max_chars", WINDOW_CHARACTER_DEFAULT, 1, WINDOW_CHARACTER_CAP
    )
    window_end = start_index + max_chars
    if window_end > DOCUMENT_CHARACTER_CAP:
        raise ToolError(
            "start_index plus max_chars exceeds the "
            f"{DOCUMENT_CHARACTER_CAP} character document cap"
        )
    now = time.time()
    ledger = open_ledger(settings)
    started = time.monotonic()
    audit = {
        "recorded_at": utc_timestamp(now),
        "profile": settings.get("profile") or "default",
        "operation": "fetch",
        "query_sha256": "",
        "domains": "",
        "result_count": 0,
        "fetched_host": "",
        "provider_bytes": 0,
        "returned_characters": 0,
        "latency_ms": 0,
        "status": "refused",
    }
    try:
        signing_key = read_secret_file(settings["token_key_file"], "token signing")
        claim = redeem_result_id(signing_key, result_id, now)
        url = claim["canonical_url"]
        audit["fetched_host"] = urllib.parse.urlsplit(url).netloc
        provider = select_provider(settings)
        if claim.get("provider") != provider.name:
            raise ToolError(
                "the result_id was issued by another provider than the "
                "configured one"
            )
        if ledger is not None:
            spend_budget(ledger, settings, "fetch", now)
        record = provider.contents(url, window_end)
        text = decode_content_text(record)
        window = text[start_index:window_end]
        truncated = len(text) > start_index + len(window)
        audit["result_count"] = 1
        audit["provider_bytes"] = provider.response_bytes
        audit["returned_characters"] = len(window)
        audit["status"] = "success"
        return wrap_untrusted(
            url, utc_timestamp(now), window, start_index, truncated
        )
    except ToolError:
        raise
    except Exception:
        audit["status"] = "error"
        raise
    finally:
        audit["latency_ms"] = int((time.monotonic() - started) * 1000)
        if ledger is not None:
            ledger.record(audit)
            ledger.close()


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
                    "description": (
                        "Characters to return, at most 24000. The reply names "
                        "the next start index when more text remains."
                    ),
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
        "state_dir": os.environ.get("QWEN_WEB_STATE_DIR", ""),
        "profile": os.environ.get("QWEN_WEB_PROFILE", "default"),
        "search_per_minute": os.environ.get("QWEN_WEB_SEARCH_PER_MINUTE", ""),
        "fetch_per_minute": os.environ.get("QWEN_WEB_FETCH_PER_MINUTE", ""),
        "daily_budget": os.environ.get("QWEN_WEB_DAILY_BUDGET", ""),
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
        " [--max-age-hours N]"
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
        "max_age_hours": None,
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
        elif option in ("--max-results", "--lifetime", "--max-age-hours"):
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
        "max_age_hours": fields["max_age_hours"],
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
            require_optional_integer(
                arguments, "max_age_hours", 0, MAX_AGE_HOURS_CAP
            ),
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
