"""One grant per human approval, served as gateway routes.

`remote/web-mcp/authorize-broker.py` is the predecessor: a loopback HTTP
service that signs a search grant or a generation grant for the exact
arguments a human has just read, and signs nothing else. This module carries
its rules to the one-origin gateway with the claims byte-identical, so a grant
minted here verifies in `remote/web-mcp/server.py` and
`remote/web-mcp/image_grant.py` unchanged and spends its single use in the
ledger both writers share.

`POST /api/tools/grant` signs `search-authorization` over a query, its domain
filters, its publication window, its cached-age bound, and a result count.
`POST /api/tools/grant-image` signs `qwen-image-generate-v1` over two
profiles, the prompt and negative-prompt digests, the seed, the aspect, the
pixel and step maxima, and the conversation generation. The approving page
posts digests rather than text, so the approved words stay in the browser and
the grant travels through a model transcript carrying an identity. Each claim
carries `max_uses` of one and the serving path spends it under the ledger's
primary key, so this surface offers one grade of approval and holds no
standing permission.

The gate chain runs in the order the predecessor fixed and each position is
what makes the one below it affordable:

1. the Host header names one entry of a closed set, a constant-cost refusal
   that spends no bucket unit, so a peer outside the set drains nothing a
   legitimate caller needs;
2. a signing route under the LAN exposure reads the gateway session, so an
   unauthenticated peer is refused before it spends a unit;
3. the aggregate `authorize-minute` bucket and then the per-client bucket,
   as two separate ledger calls, so a busy peer spends the aggregate even
   where the per-client bound then refuses it and cannot buy other peers a
   wider aggregate rate;
4. the Origin allowlist, which is the same gate that released the session
   secret, so a secret that left the admitted page buys nothing;
5. the per-launch session secret, compared with `hmac.compare_digest`;
6. the body's `profile_id`, matched against the profile this service signs
   for, so a mismatch is refused against the name the grant would carry
   rather than at the MCP child against a token that already left.

The gateway's own session replaces the Web UI bearer for a browser caller and
reaches this module as one injectable callable, so these rules test without a
listener and without the authentication module. `GET /api/tools/session`
keeps the secret handshake the served page performs.

The signing key travels from its file into `sign_claim` and into no response,
log line, or audit row.
"""

from __future__ import annotations

import base64
import datetime
import hashlib
import hmac
import json
import math
import os
import re
import secrets
import stat
import threading
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path

from qwen_apu.tools.ledger import (
    AGGREGATE_BUCKET,
    BUCKET_WINDOW_SECONDS,
    AuditRow,
    AuthorizationDenied,
    BudgetExhausted,
    ExpiredResult,
    InvalidArgument,
    Ledger,
    ToolError,
    retry_after_seconds,
    utc_timestamp,
)
from qwen_apu.web.http import Request, Response, Route

GRANT_PATH = "/api/tools/grant"
IMAGE_GRANT_PATH = "/api/tools/grant-image"
SESSION_PATH = "/api/tools/session"

LOOPBACK_HOSTS: tuple[str, ...] = ("127.0.0.1", "::1")
WILDCARD_HOST = "0.0.0.0"  # noqa: S104 -- the exposure opt-in binds it deliberately
ASCII_LABEL_CHARACTERS = frozenset("abcdefghijklmnopqrstuvwxyz0123456789-")

SESSION_SECRET_FILE_NAME = "authorize-session.secret"  # noqa: S105 -- a file name
SESSION_SECRET_BYTES = 32
SESSION_HEADER = "X-Qwen-Web-Session"
STALE_SESSION_SECRET_CODE = "stale_session_secret"  # noqa: S105 -- a refusal term

REQUEST_BODY_BYTE_CAP = 16384
KEY_MODE_FORBIDDEN_BITS = 0o077
SECRET_BYTE_CAP = 4096

AUTHORIZE_PER_MINUTE_DEFAULT = 6
# An open household-LAN launch has many peers behind the one aggregate bucket,
# so a second bucket is keyed by client address rather than replacing the
# aggregate one. Both defaults sit under the aggregate rate, since a
# per-client bucket that admitted the whole aggregate rate to one peer would
# state a limit it does nothing to enforce.
GRANT_PER_CLIENT_PER_MINUTE_DEFAULT = 3
IMAGE_GRANT_PER_CLIENT_PER_MINUTE_DEFAULT = 2
# `remote/image-service.py` runs one generation at a time and refuses a second
# without queueing, so a second unspent grant from one client buys that client
# a standing ticket ahead of every other peer's next job. "Outstanding" is
# expiry-based rather than spend-based: the grants table carries no client
# column, so this service counts the grants it signed for one address whose
# own lifetime has not yet elapsed, and a spent grant still counts until its
# term runs out.
IMAGE_MAX_OUTSTANDING_GRANTS_PER_CLIENT_DEFAULT = 1

PROVIDER_NAMES: tuple[str, ...] = ("exa", "fake", "searxng")

AUTHORIZATION_CLAIM_CONTEXT = "search-authorization"
IMAGE_CLAIM_CONTEXT = "qwen-image-generate-v1"
GRANT_MAX_USES = 1
GRANT_ID_BYTES = 12

QUERY_CHARACTER_CAP = 512
RESULT_COUNT_CAP = 10
RESULT_COUNT_DEFAULT = 5
DOMAIN_LIST_CAP = 10
DOMAIN_CHARACTER_CAP = 253
MAX_AGE_HOURS_CAP = 24 * 365
AUTHORIZATION_CHARACTER_CAP = 12288

TOKEN_LIFETIME_DEFAULT_SECONDS = 900
TOKEN_LIFETIME_MINIMUM_SECONDS = 60
TOKEN_LIFETIME_MAXIMUM_SECONDS = 3600

SEED_MAXIMUM = 2**32 - 1
DIMENSION_MINIMUM = 64
DIMENSION_MAXIMUM = 2048
DIMENSION_MULTIPLE = 64
STEP_MINIMUM = 1
STEP_MAXIMUM = 100
GENERATION_MAXIMUM = 2**31 - 1
IMAGE_GRANT_CHARACTER_CAP = 4096

HOSTNAME_PATTERN = re.compile(
    r"^(?=.{1,253}$)[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?"
    r"(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$"
)
PROFILE_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
ASPECT_PATTERN = re.compile(r"^([1-9][0-9]{0,3}):([1-9][0-9]{0,3})$")
DIGEST_PATTERN = re.compile(r"^[0-9a-f]{64}$")

IMAGE_REQUEST_FIELDS: tuple[str, ...] = (
    "context",
    "language_profile",
    "image_profile",
    "prompt_hash",
    "negative_prompt_hash",
    "seed",
    "aspect",
    "max_dimension",
    "max_steps",
    "conversation_generation",
)

HTTP_STATUS_FOR_TERM: Mapping[str, int] = {
    "authorization_denied": 403,
    "rate_limited": 429,
    "budget_exhausted": 429,
    "expired_result": 403,
}


class StaleSessionSecret(AuthorizationDenied):
    """A grant request presents authority from another launch."""


class OutstandingImageGrantExhausted(BudgetExhausted):
    """A client already holds its full quota of unexpired image grants.

    The quota decays with the oldest outstanding grant's own expiry rather
    than with a fixed 60-second window, so `retry_after` carries the seconds
    until that grant ages out instead of the fixed-window arithmetic the
    per-minute buckets use.
    """

    def __init__(self, message: str, retry_after: int) -> None:
        super().__init__(message)
        self.retry_after = retry_after


@dataclass(frozen=True)
class SessionOrRefusal:
    """What the gateway's session check answers about one request.

    `web/auth.py` owns the cookie and the session table; this module reads the
    verdict alone, so the approval rules test without that module and a
    deployment that has yet to arm a session refuses rather than admits.
    """

    admitted: bool
    reason: str = ""


SessionCheck = Callable[[Request], SessionOrRefusal]


def refuse_every_session(request: Request) -> SessionOrRefusal:
    """Refuse every caller, which is what an unconfigured session check owes.

    The gateway injects `web.auth.require_session` in production. The default
    stands where nothing has been injected, so a route reads a refusal rather
    than an absent check reading as an admission.
    """
    del request
    return SessionOrRefusal(False, "the gateway session check is unconfigured")


def label_is_admitted(label: str) -> bool:
    """Return whether one hostname label meets the ASCII letter-digit-hyphen rule.

    The character set stays ASCII rather than reading `str.isalnum`, which
    admits every Unicode letter: a browser sends an internationalized name in
    its Punycode form, so a name outside ASCII is refused here rather than
    admitted into a set no request ever matches.
    """
    return (
        1 <= len(label) <= 63
        and not label.startswith("-")
        and not label.endswith("-")
        and all(character in ASCII_LABEL_CHARACTERS for character in label)
    )


def exposed_host(value: str) -> str:
    """Return the non-loopback IPv4 literal the LAN exposure opt-in names.

    The Host-header comparison and the CORS Origin both read this value, so it
    is an address rather than a name: a name would send the comparison back
    through the resolver the loopback rule exists to keep out. The wildcard
    names no reachable address and the loopback default is what the opt-in
    departs from, so both are refused here. Every other IPv4 literal is
    admitted, which puts 127.0.0.2 in reach of a test that runs the exposed
    page on a host holding no LAN.
    """
    if not value:
        return ""
    parts = value.split(".")
    if len(parts) != 4 or not all(
        part.isdigit() and len(part) <= 3 and 0 <= int(part) <= 255 for part in parts
    ):
        raise InvalidArgument(f"the LAN exposure address is an IPv4 literal; {value!r} is refused")
    if value in LOOPBACK_HOSTS or value == WILDCARD_HOST:
        raise InvalidArgument(
            f"the LAN exposure address departs from the loopback default and "
            f"names a reachable address; {value!r} is the default or the wildcard"
        )
    return value


def exposed_name(value: str) -> str:
    """Return the mDNS label the LAN exposure opt-in admits beside the literal.

    A DHCP lease moves the address, so the name is what an operator bookmarks.
    Admitting it keeps the set closed rather than reopening the resolver:
    avahi publishes `<label>.local` on the link and a browser resolves that
    suffix by multicast to the hosts sharing the link, so the admitted form is
    exactly one lowercase RFC 1123 label under `.local`. A bare hostname, a
    public domain, a second label under `.local`, an uppercase letter, and a
    trailing dot each register in the ordinary resolver, where a name an
    attacker controls resolves to this socket under DNS rebinding. A single
    label carries no dot, so an all-numeric label such as `123.local` names no
    four-octet IPv4 literal and is admitted the way `web_lan_name_is_valid` in
    `remote/web-lan-exposure.sh` admits it.
    """
    if not value:
        return ""
    if not value.endswith(".local"):
        raise InvalidArgument(
            f"the LAN exposure name is a hostname a browser resolves on the "
            f"link; the admitted set holds exactly one lowercase mDNS label "
            f"under .local; {value!r} is refused"
        )
    label = value[: -len(".local")]
    if not label_is_admitted(label):
        raise InvalidArgument(
            f"the LAN exposure name carries a label outside the lowercase "
            f"letter-digit-hyphen set; {value!r} is refused"
        )
    return value


def admitted_hosts(exposure: str = "", name: str = "") -> tuple[str, ...]:
    """Return the Host-header names a request may present.

    The loopback literals stand under every setting, because the session's own
    probes reach this service over 127.0.0.1 whatever the listener binds. The
    exposure adds exactly one literal and the name adds exactly one lowercased
    hostname, so the set stays a closed list of two to four entries.
    """
    admitted = list(LOOPBACK_HOSTS)
    if exposure:
        admitted.append(exposure)
    if name:
        admitted.append(name)
    return tuple(admitted)


def host_header_names(header: str, admitted: Sequence[str]) -> str:
    """Return the admitted entry a Host header names, or an empty string.

    A browser that resolves an attacker-controlled name to a bound address
    reaches this socket with that name in the Host header, so the bind alone
    leaves DNS rebinding open. The comparison is exact string equality against
    a closed set, case-folded because DNS names are case-insensitive and the
    admitted name is stored lowercased; the literals hold digits and dots
    alone, so lowering leaves them as they stand. Equality rather than a
    prefix or suffix test is what refuses a name carrying an admitted one as a
    sub-label.
    """
    if not header:
        return ""
    value = header.strip()
    if value.startswith("["):
        closing = value.find("]")
        if closing < 0:
            return ""
        named = value[1:closing]
    else:
        named = value.split(":", 1)[0]
    if named in admitted:
        return named
    lowered = named.lower()
    return lowered if lowered in admitted else ""


def base64url_encode(payload: bytes) -> str:
    return base64.urlsafe_b64encode(payload).rstrip(b"=").decode("ascii")


def base64url_decode(text: str) -> bytes:
    padding = "=" * (-len(text) % 4)
    return base64.urlsafe_b64decode(text + padding)


def read_secret_file(path: Path | str, purpose: str) -> str:
    """Return the contents of a key file that only its owner reads.

    The descriptor opens with O_NOFOLLOW, O_CLOEXEC, and O_NONBLOCK, so a
    symlink planted at the configured path fails the open rather than
    redirecting the read, no child inherits the descriptor, and a FIFO returns
    at once for the regular-file check rather than waiting for a writer. The
    regular-file and mode checks run against fstat of that same descriptor,
    which leaves no window between the check and the read for a replacement.
    """
    if not path:
        raise ToolError(f"the {purpose} key file is unconfigured, so the call reaches no key")
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError:
        raise ToolError(f"the {purpose} key file is unreadable: {path}") from None
    try:
        file_status = os.fstat(descriptor)
        if not stat.S_ISREG(file_status.st_mode):
            raise ToolError(f"the {purpose} key file is not a regular file: {path}")
        mode = stat.S_IMODE(file_status.st_mode)
        if mode & KEY_MODE_FORBIDDEN_BITS:
            raise ToolError(
                f"the {purpose} key file {path} is mode {mode:04o}; "
                "0600 is required before a call runs"
            )
        try:
            raw = os.read(descriptor, SECRET_BYTE_CAP)
        except OSError:
            raise ToolError(f"the {purpose} key file is unreadable: {path}") from None
    finally:
        os.close(descriptor)
    try:
        secret = raw.decode("utf-8").strip()
    except UnicodeDecodeError:
        raise ToolError(f"the {purpose} key file is not UTF-8 text: {path}") from None
    if not secret:
        raise ToolError(f"the {purpose} key file is empty: {path}")
    return secret


def signing_key_digest(path: Path | str) -> str:
    """Return the SHA-256 of the signing key file after every rule holds.

    The digest covers the file's own bytes, where the HMAC key is that content
    stripped, so a file ending in a newline reports one digest and signs with
    another string. Each rule refuses by name and none echoes the contents: an
    unnamed path, a missing file, a symlink (the `lstat` mode bit rather than
    the resolved target), an owner other than this process's own, a mode
    carrying any group or other bit, an unreadable file, and a file of zero
    bytes. `read_secret_file` then applies the descriptor rules the serving
    path applies, which is what refuses a whitespace-only or non-UTF-8 key.
    """
    if not path:
        raise InvalidArgument(
            "every grant is signed from a key file, so the approval settings name it"
        )
    try:
        status = os.lstat(path)
    except OSError as error:
        raise InvalidArgument(f"the signing key file is unreadable: {error}") from None
    if not stat.S_ISREG(status.st_mode):
        raise InvalidArgument(
            "the signing key path names a symlink or another non-regular file, "
            "and the approval service refuses to follow it"
        )
    if status.st_uid != os.getuid():
        raise InvalidArgument(
            "the signing key file belongs to another user, and the approval "
            "service refuses a key it does not own"
        )
    if status.st_mode & KEY_MODE_FORBIDDEN_BITS:
        raise InvalidArgument(
            "the signing key file is readable or writable outside its owner; "
            "chmod 0600 or stricter before a grant is signed"
        )
    try:
        content = Path(path).read_bytes()
    except OSError as error:
        raise InvalidArgument(f"the signing key file is unreadable: {error}") from None
    if not content:
        raise InvalidArgument("the signing key file is empty")
    read_secret_file(path, "token signing")
    return hashlib.sha256(content).hexdigest()


def sign_claim(signing_key: str, context: str, claim: Mapping[str, object]) -> str:
    """Return `payload.signature` for a claim bound to one context string.

    The HMAC covers the context and the base64url payload string rather than
    the decoded object, so an encoder that admits two spellings of one object
    still signs one byte string, and a search authorization never verifies as
    a generation grant. `sort_keys`, the compact separators, and the default
    ASCII escaping are the three encoder settings both sides share.
    """
    payload = base64url_encode(json.dumps(claim, sort_keys=True, separators=(",", ":")).encode())
    signature = base64url_encode(
        hmac.new(
            signing_key.encode("utf-8"),
            f"{context}:{payload}".encode("ascii"),
            hashlib.sha256,
        ).digest()
    )
    return f"{payload}.{signature}"


def verify_claim(
    signing_key: str, context: str, token: str, now: float, label: str
) -> dict[str, object]:
    """Return the claim of a token whose signature verifies and whose term runs."""
    if not isinstance(token, str) or token.count(".") != 1:
        raise AuthorizationDenied(f"the {label} is malformed")
    payload, signature = token.split(".")
    expected = base64url_encode(
        hmac.new(
            signing_key.encode("utf-8"),
            f"{context}:{payload}".encode("ascii"),
            hashlib.sha256,
        ).digest()
    )
    if not hmac.compare_digest(signature, expected):
        raise AuthorizationDenied(f"the {label} signature fails verification")
    try:
        claim = json.loads(base64url_decode(payload).decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        raise AuthorizationDenied(f"the {label} payload is malformed") from None
    if not isinstance(claim, dict):
        raise AuthorizationDenied(f"the {label} payload is malformed")
    expiry = claim.get("expiry")
    if not isinstance(expiry, int | float) or now >= expiry:
        raise ExpiredResult(f"the {label} has expired")
    return claim


def resolve_lifetime(lifetime: int) -> int:
    """Return an admitted grant lifetime in seconds.

    Below 60 seconds an approval expires inside the turn that spends it, and
    above 3600 a token outlives the appliance session that issued it. A value
    outside the range refuses the request, since a clamp hides an operator's
    mistake behind a working grant.
    """
    if isinstance(lifetime, bool) or not isinstance(lifetime, int):
        raise InvalidArgument(f"the grant lifetime is not an integer: {lifetime!r}")
    seconds = lifetime
    if not TOKEN_LIFETIME_MINIMUM_SECONDS <= seconds <= TOKEN_LIFETIME_MAXIMUM_SECONDS:
        raise InvalidArgument(
            "the grant lifetime lies outside "
            f"[{TOKEN_LIFETIME_MINIMUM_SECONDS}, "
            f"{TOKEN_LIFETIME_MAXIMUM_SECONDS}]: {seconds}"
        )
    return seconds


def require_string(value: object, key: str, cap: int) -> str:
    if value is None:
        value = ""
    if not isinstance(value, str):
        raise ToolError(f"{key} must be a string")
    text = value.strip()
    if not text:
        raise ToolError(f"{key} is required")
    if len(text) > cap:
        raise ToolError(f"{key} exceeds the {cap} character cap")
    return text


def require_integer(value: object, key: str, default: int, minimum: int, maximum: int) -> int:
    if value is None:
        value = default
    if isinstance(value, bool) or not isinstance(value, int):
        raise ToolError(f"{key} must be an integer")
    if value < minimum or value > maximum:
        raise ToolError(f"{key} must lie between {minimum} and {maximum}")
    return value


def require_optional_integer(value: object, key: str, minimum: int, maximum: int) -> int | None:
    if value is None:
        return None
    return require_integer(value, key, minimum, minimum, maximum)


def require_iso_date(value: object, key: str) -> str:
    """Return an ISO 8601 calendar date, or the empty string when absent.

    `datetime.date.fromisoformat` accepts every extended form Python admits,
    so the value is reformatted to YYYY-MM-DD; the reformatted string is what
    the provider body and the authorization claim both carry, which keeps one
    spelling of a date on both sides of the comparison.
    """
    if value in (None, ""):
        return ""
    if not isinstance(value, str):
        raise ToolError(f"{key} must be an ISO 8601 date string")
    try:
        parsed = datetime.date.fromisoformat(value.strip())
    except ValueError:
        raise ToolError(f"{key} is not an ISO 8601 date") from None
    return parsed.isoformat()


def require_domain_list(value: object, key: str) -> list[str]:
    """Return the normalized hostname list a filter names.

    Each entry is stripped, lowercased, and cleared of a trailing dot before
    the hostname pattern reads it, so one domain reaches the claim under one
    spelling whatever case or root form the approval dialog displayed.
    """
    if value is None:
        value = []
    if not isinstance(value, list):
        raise ToolError(f"{key} must be a list of domain names")
    if len(value) > DOMAIN_LIST_CAP:
        raise ToolError(f"{key} exceeds the {DOMAIN_LIST_CAP} entry cap")
    domains: list[str] = []
    for entry in value:
        if not isinstance(entry, str) or not entry.strip():
            raise ToolError(f"{key} entries must be non-empty domain names")
        normalized = entry.strip().lower().rstrip(".")
        if len(normalized) > DOMAIN_CHARACTER_CAP:
            raise ToolError(f"{key} entries exceed the {DOMAIN_CHARACTER_CAP} character cap")
        if not HOSTNAME_PATTERN.match(normalized):
            raise ToolError(f"{key} carries an entry that is not a hostname")
        domains.append(normalized)
    return domains


@dataclass(frozen=True)
class SearchGrantRequest:
    """The exact search fields one approval names."""

    profile_id: str
    query: str
    include_domains: tuple[str, ...]
    exclude_domains: tuple[str, ...]
    published_after: str
    published_before: str
    max_age_hours: int | None
    max_results: int


@dataclass(frozen=True)
class ImageGrantRequest:
    """The exact generation fields one approval names."""

    context: str
    language_profile: str
    image_profile: str
    prompt_hash: str
    negative_prompt_hash: str
    seed: int
    aspect: str
    max_dimension: int
    max_steps: int
    conversation_generation: int


def parse_search_request(payload: object) -> SearchGrantRequest:
    """Return the search fields a grant request names.

    Shape is validated here and every cap, hostname rule, and date form
    belongs to `issue_search_grant`, which applies the helpers the serving
    path applies, so an approved argument and a served argument pass one
    validator. A field the request omits takes the same default the serving
    path takes, so a dialog that showed nothing under a field approves the
    absence the search then sends.
    """
    if not isinstance(payload, dict):
        raise InvalidArgument("the request body is not an object")
    profile_id = payload.get("profile_id")
    if not isinstance(profile_id, str) or not profile_id:
        raise InvalidArgument("profile_id must name the web profile the grant is signed for")
    query = payload.get("query")
    if not isinstance(query, str):
        raise InvalidArgument("query must be a string")
    filters: dict[str, tuple[str, ...]] = {}
    for key in ("include_domains", "exclude_domains"):
        value = payload.get(key) or []
        if not isinstance(value, list) or not all(isinstance(entry, str) for entry in value):
            raise InvalidArgument(f"{key} must be a list of strings")
        filters[key] = tuple(value)
    window: dict[str, str] = {}
    for key in ("published_after", "published_before"):
        value = payload.get(key) or ""
        if not isinstance(value, str):
            raise InvalidArgument(f"{key} must be a string")
        window[key] = require_iso_date(payload.get(key), key)
    if (
        window["published_after"]
        and window["published_before"]
        and window["published_after"] > window["published_before"]
    ):
        raise InvalidArgument("published_after falls after published_before")
    max_age_hours = payload.get("max_age_hours")
    if max_age_hours is not None and (
        not isinstance(max_age_hours, int) or isinstance(max_age_hours, bool)
    ):
        raise InvalidArgument("max_age_hours must be an integer or absent")
    max_results = payload.get("max_results")
    if max_results is None:
        max_results = RESULT_COUNT_DEFAULT
    if not isinstance(max_results, int) or isinstance(max_results, bool):
        raise InvalidArgument("max_results must be an integer")
    return SearchGrantRequest(
        profile_id=profile_id,
        query=query,
        include_domains=filters["include_domains"],
        exclude_domains=filters["exclude_domains"],
        published_after=window["published_after"],
        published_before=window["published_before"],
        max_age_hours=max_age_hours,
        max_results=max_results,
    )


def prompt_digest(text: str) -> str:
    """Return the SHA-256 of a prompt under the one spelling both sides hash.

    The string is stripped before hashing because a dialog renders trailing
    whitespace invisibly, so the human approves the stripped text and the
    execution path reaches the same digest from the model's own copy.
    """
    return hashlib.sha256(text.strip().encode("utf-8")).hexdigest()


def canonical_aspect(width: int, height: int) -> str:
    """Return the reduced `W:H` form of one pixel geometry.

    `1024:1024` and `1:1` name one geometry, so the claim carries the reduced
    spelling and the execution path reduces the emitted width and height the
    same way before comparing.
    """
    divisor = math.gcd(int(width), int(height))
    return f"{int(width) // divisor}:{int(height) // divisor}"


def require_digest(payload: Mapping[str, object], key: str) -> str:
    """Return a SHA-256 hex digest a request states rather than a text it holds."""
    value = payload.get(key)
    if not isinstance(value, str) or not DIGEST_PATTERN.match(value.strip().lower()):
        raise InvalidArgument(f"{key} must be a SHA-256 digest in lowercase hexadecimal")
    return value.strip().lower()


def require_profile_id(payload: Mapping[str, object], key: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str) or not PROFILE_ID_PATTERN.match(value):
        raise InvalidArgument(f"{key} must name a profile in [A-Za-z0-9][A-Za-z0-9._-]*")
    return value


def require_bounded_integer(
    payload: Mapping[str, object], key: str, minimum: int, maximum: int
) -> int:
    """Return an integer field, refusing an absent one and refusing a bool.

    `bool` subclasses `int`, so `True` passes an `isinstance` test and reaches
    the claim as 1. The seed is where that matters: a caller sending `true`
    where a seed belongs would authorize generation 1 while the dialog
    displayed nothing. An explicit `is None` test rather than a truth test
    admits a seed of 0, which is a value a user picks.
    """
    value = payload.get(key)
    if value is None:
        raise InvalidArgument(f"{key} is required")
    if isinstance(value, bool) or not isinstance(value, int):
        raise InvalidArgument(f"{key} must be an integer")
    if value < minimum or value > maximum:
        raise InvalidArgument(f"{key} must lie between {minimum} and {maximum}")
    return value


def require_aspect(payload: Mapping[str, object], key: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str):
        raise InvalidArgument(f"{key} must be a string of the form W:H")
    matched = ASPECT_PATTERN.match(value.strip())
    if matched is None:
        raise InvalidArgument(f"{key} must be a string of the form W:H with positive terms")
    return canonical_aspect(int(matched.group(1)), int(matched.group(2)))


def parse_image_request(payload: object) -> ImageGrantRequest:
    """Return the exact fields an image grant request names.

    The seed is required and this service generates none, so a request
    omitting it is refused rather than completed with a value no human read.
    The field allowlist refuses an unknown key by name for the same reason the
    MCP schema does: a field this service would drop silently is a field the
    dialog displayed and the grant then failed to bind.
    """
    if not isinstance(payload, dict):
        raise InvalidArgument("the request body is not an object")
    unknown = sorted(name for name in payload if name not in IMAGE_REQUEST_FIELDS)
    if unknown:
        raise InvalidArgument(
            "the grant request carries a field outside the image claim: " + ", ".join(unknown)
        )
    if payload.get("context") != IMAGE_CLAIM_CONTEXT:
        raise InvalidArgument(f"context must name the {IMAGE_CLAIM_CONTEXT} claim")
    max_dimension = require_bounded_integer(
        payload, "max_dimension", DIMENSION_MINIMUM, DIMENSION_MAXIMUM
    )
    if max_dimension % DIMENSION_MULTIPLE != 0:
        raise InvalidArgument(f"max_dimension must be a multiple of {DIMENSION_MULTIPLE}")
    return ImageGrantRequest(
        context=IMAGE_CLAIM_CONTEXT,
        language_profile=require_profile_id(payload, "language_profile"),
        image_profile=require_profile_id(payload, "image_profile"),
        prompt_hash=require_digest(payload, "prompt_hash"),
        negative_prompt_hash=require_digest(payload, "negative_prompt_hash"),
        seed=require_bounded_integer(payload, "seed", 0, SEED_MAXIMUM),
        aspect=require_aspect(payload, "aspect"),
        max_dimension=max_dimension,
        max_steps=require_bounded_integer(payload, "max_steps", STEP_MINIMUM, STEP_MAXIMUM),
        conversation_generation=require_bounded_integer(
            payload, "conversation_generation", 0, GENERATION_MAXIMUM
        ),
    )


def authorization_claim(
    query: str,
    *,
    include_domains: Sequence[str],
    exclude_domains: Sequence[str],
    published_after: str,
    published_before: str,
    max_age_hours: int | None,
    max_results: int,
    expiry: int,
) -> dict[str, object]:
    """Return the canonical form of a search grant.

    `max_age_hours` is covered because 0 forces a live crawl, which is the one
    search parameter that spends provider budget on the model's word. The
    issuing path and the serving path build the grant through one function, so
    the comparison runs over one spelling of every field: the query stripped,
    the domain lists normalized and sorted, and the dates in the calendar form
    `require_iso_date` produces.
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


def issue_search_grant(
    token_key_file: Path | str,
    request: SearchGrantRequest,
    *,
    provider: str,
    profile: str,
    lifetime: int,
    now: float | None = None,
) -> str:
    """Return the signed grant for one exact set of search arguments.

    `enforce_search_authorization` in `remote/web-mcp/server.py` compares the
    claim field by field against arguments rebuilt through the same helpers,
    so the validation, the canonical claim, and the identity fields live in
    one place here the way they live in one place there.
    """
    if provider not in PROVIDER_NAMES:
        raise InvalidArgument(
            "provider names none of " + ", ".join(PROVIDER_NAMES) + f": {provider}"
        )
    issued_at = int(time.time() if now is None else now)
    claim = authorization_claim(
        require_string(request.query, "query", QUERY_CHARACTER_CAP),
        include_domains=require_domain_list(list(request.include_domains), "include_domains"),
        exclude_domains=require_domain_list(list(request.exclude_domains), "exclude_domains"),
        published_after=require_iso_date(request.published_after, "published_after"),
        published_before=require_iso_date(request.published_before, "published_before"),
        max_age_hours=require_optional_integer(
            request.max_age_hours, "max_age_hours", 0, MAX_AGE_HOURS_CAP
        ),
        max_results=require_integer(
            request.max_results, "max_results", RESULT_COUNT_DEFAULT, 1, RESULT_COUNT_CAP
        ),
        expiry=issued_at + resolve_lifetime(lifetime),
    )
    # The identity fields bind the grant to one ledger row, one provider, and
    # one profile: `grant_id` is the primary key the single use is recorded
    # under, and the serving path refuses a grant whose provider or profile
    # differs from the one it runs as.
    claim.update(
        {
            "grant_id": base64url_encode(os.urandom(GRANT_ID_BYTES)),
            "provider": provider,
            "profile_id": profile,
            "issued_at": issued_at,
            "max_uses": GRANT_MAX_USES,
        }
    )
    token = sign_claim(
        read_secret_file(token_key_file, "token signing"), AUTHORIZATION_CLAIM_CONTEXT, claim
    )
    if len(token) > AUTHORIZATION_CHARACTER_CAP:
        # A grant the serving path refuses before signature verification buys
        # nothing, so the cap holds where the grant is issued. The message
        # states the cap alone, which keeps the oversized token out of the
        # response and out of the audit row.
        raise InvalidArgument(
            f"the grant exceeds the {AUTHORIZATION_CHARACTER_CAP} character cap "
            "the search argument admits"
        )
    return token


def image_claim(
    request: ImageGrantRequest, *, issued_at: int, expiry: int, grant_id: str
) -> dict[str, object]:
    """Return the canonical claim one generation approval signs.

    The digests replace the prompt text, so the claim states which prompt was
    approved while the text stays out of every later request that re-sends the
    grant. `conversation_generation` is signed and compared by the user
    interface that approved it, since the MCP child reads a tool call and sees
    no conversation; the single-use nonce is what stops a replay inside the
    appliance.
    """
    return {
        "language_profile": request.language_profile,
        "image_profile": request.image_profile,
        "prompt_hash": request.prompt_hash,
        "negative_prompt_hash": request.negative_prompt_hash,
        "seed": request.seed,
        "aspect": request.aspect,
        "max_dimension": request.max_dimension,
        "max_steps": request.max_steps,
        "conversation_generation": request.conversation_generation,
        "issued_at": issued_at,
        "expiry": expiry,
        "grant_id": grant_id,
        "max_uses": GRANT_MAX_USES,
    }


def issue_image_grant(
    token_key_file: Path | str,
    request: ImageGrantRequest,
    lifetime: int,
    now: float | None = None,
) -> str:
    """Return the signed grant for one exact generation."""
    issued_at = int(time.time() if now is None else now)
    claim = image_claim(
        request,
        issued_at=issued_at,
        expiry=issued_at + resolve_lifetime(lifetime),
        grant_id=base64url_encode(os.urandom(GRANT_ID_BYTES)),
    )
    token = sign_claim(
        read_secret_file(token_key_file, "token signing"), IMAGE_CLAIM_CONTEXT, claim
    )
    if len(token) > IMAGE_GRANT_CHARACTER_CAP:
        raise InvalidArgument(
            f"the image grant exceeds the {IMAGE_GRANT_CHARACTER_CAP} character cap "
            "the tool argument admits"
        )
    return token


@dataclass(frozen=True)
class ApprovalSettings:
    """What one gateway launch signs, meters, and admits.

    The cross-argument rules the predecessor's `run` applied at startup are in
    `build_settings`, so a settings object that exists is one every rule has
    already admitted.
    """

    state_directory: Path
    token_key_file: Path
    profile: str
    provider: str = "exa"
    image_profile: str = ""
    lifetime: int = TOKEN_LIFETIME_DEFAULT_SECONDS
    origins: tuple[str, ...] = ()
    per_minute: int = AUTHORIZE_PER_MINUTE_DEFAULT
    grant_per_client_per_minute: int = GRANT_PER_CLIENT_PER_MINUTE_DEFAULT
    image_grant_per_client_per_minute: int = IMAGE_GRANT_PER_CLIENT_PER_MINUTE_DEFAULT
    image_max_outstanding_grants_per_client: int = IMAGE_MAX_OUTSTANDING_GRANTS_PER_CLIENT_DEFAULT
    exposure: str = ""
    exposure_name: str = ""
    open_lan: bool = False
    admitted_hosts: tuple[str, ...] = LOOPBACK_HOSTS
    signing_key_sha256: str = ""


def build_settings(
    state_directory: Path | str,
    token_key_file: Path | str,
    profile: str,
    origins: Sequence[str],
    *,
    provider: str = "exa",
    image_profile: str = "",
    lifetime: int = TOKEN_LIFETIME_DEFAULT_SECONDS,
    per_minute: int = AUTHORIZE_PER_MINUTE_DEFAULT,
    grant_per_client_per_minute: int = GRANT_PER_CLIENT_PER_MINUTE_DEFAULT,
    image_grant_per_client_per_minute: int = IMAGE_GRANT_PER_CLIENT_PER_MINUTE_DEFAULT,
    image_max_outstanding_grants_per_client: int = (
        IMAGE_MAX_OUTSTANDING_GRANTS_PER_CLIENT_DEFAULT
    ),
    exposure: str = "",
    exposure_name: str = "",
    open_lan: bool = False,
) -> ApprovalSettings:
    """Return the settings after every rule that precedes a signature holds.

    The name widens the Host set alone and the open opt-in removes a
    credential from a listener the operator exposed, so each names the
    exposure it belongs to rather than standing on its own. The signing key is
    read whole here, which is what makes a launch fail at startup rather than
    at the first approval.
    """
    if not state_directory:
        raise InvalidArgument(
            "the approval service meters and audits through the ledger, so the "
            "settings name the state directory it lives in"
        )
    if not origins:
        raise InvalidArgument(
            "the session route admits an explicit Origin alone, so the settings "
            "name the page that reads it"
        )
    if provider not in PROVIDER_NAMES:
        raise InvalidArgument(
            "provider names none of " + ", ".join(PROVIDER_NAMES) + f": {provider}"
        )
    for name, value in (
        ("per_minute", per_minute),
        ("grant_per_client_per_minute", grant_per_client_per_minute),
        ("image_grant_per_client_per_minute", image_grant_per_client_per_minute),
        (
            "image_max_outstanding_grants_per_client",
            image_max_outstanding_grants_per_client,
        ),
    ):
        if value <= 0:
            raise InvalidArgument(f"{name} must be a positive integer: {value}")
    exposure_literal = exposed_host(exposure)
    exposure_label = exposed_name(exposure_name)
    if exposure_label and not exposure_literal:
        raise InvalidArgument(
            "the LAN exposure name adds a Host to the exposed set, so the "
            "exposure literal names the set that is built from"
        )
    if open_lan and not exposure_literal:
        raise InvalidArgument(
            "the open opt-in removes the gateway session from an exposed "
            "listener, so the exposure literal names the address it exposes"
        )
    return ApprovalSettings(
        state_directory=Path(state_directory),
        token_key_file=Path(token_key_file),
        profile=profile,
        provider=provider,
        image_profile=image_profile,
        lifetime=resolve_lifetime(lifetime),
        origins=tuple(origins),
        per_minute=per_minute,
        grant_per_client_per_minute=grant_per_client_per_minute,
        image_grant_per_client_per_minute=image_grant_per_client_per_minute,
        image_max_outstanding_grants_per_client=image_max_outstanding_grants_per_client,
        exposure=exposure_literal,
        exposure_name=exposure_label,
        open_lan=open_lan,
        admitted_hosts=admitted_hosts(exposure_literal, exposure_label),
        signing_key_sha256=signing_key_digest(token_key_file),
    )


@dataclass
class OutstandingImageGrants:
    """The unexpired image grants this service signed, keyed by client address.

    Process memory is the whole authority, so a restarted gateway starts every
    client at zero outstanding grants rather than reading state a killed
    process left behind.
    """

    limit: int
    lock: threading.Lock = field(default_factory=threading.Lock)
    expiries: dict[str, list[float]] = field(default_factory=dict)

    def reserve(self, client: str, now: float, expiry: float) -> None:
        """Reserve one slot, or refuse, under one lock hold.

        The check and the reservation run inside one `with` block rather than
        as two calls: two concurrent handlers for the same client would
        otherwise both read the same live count before either recorded its own
        grant, and both would pass a limit of one. The reservation assumes the
        grant it is about to sign succeeds, so a caller that then fails to
        sign calls `release` with the same `expiry`.
        """
        with self.lock:
            live = [stored for stored in self.expiries.get(client, ()) if stored > now]
            if len(live) >= self.limit:
                self.expiries[client] = live
                raise OutstandingImageGrantExhausted(
                    f"client {client} already holds {len(live)} outstanding "
                    f"image grant(s); {self.limit} is the limit until one expires",
                    max(1, round(min(live) - now)),
                )
            live.append(expiry)
            self.expiries[client] = live

    def release(self, client: str, expiry: float) -> None:
        """Give back a reservation whose grant was never actually issued."""
        with self.lock:
            live = self.expiries.get(client, [])
            if expiry in live:
                live.remove(expiry)


class ApprovalService:
    """The settings, the session secret, and the per-client reservations.

    One instance serves one profile, since a grant names the profile the MCP
    child compares it against, and the gateway builds one per launch.
    """

    def __init__(
        self,
        settings: ApprovalSettings,
        session_check: SessionCheck = refuse_every_session,
        session_secret: str = "",
    ) -> None:
        self.settings = settings
        self.session_check = session_check
        self.session_secret = session_secret
        self.outstanding_image_grants = OutstandingImageGrants(
            settings.image_max_outstanding_grants_per_client
        )

    def arm_session_secret(self) -> tuple[str, Path]:
        """Place a fresh per-launch secret in a file the owner alone reads.

        The value in memory is the authority and `GET /api/tools/session` is
        the browser delivery channel. The private file gives the process
        supervisor a precise cleanup target; stale bytes left by a killed
        gateway authorize nothing against the next launch's in-memory secret.
        O_EXCL creates the file at mode 0600 after predecessor removal and
        refuses a pre-planted symlink.
        """
        path = self.settings.state_directory / SESSION_SECRET_FILE_NAME
        secret = secrets.token_urlsafe(SESSION_SECRET_BYTES)
        if path.is_symlink() or path.exists():
            path.unlink()
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            os.write(descriptor, (secret + "\n").encode("ascii"))
        finally:
            os.close(descriptor)
        self.session_secret = secret
        return secret, path

    def disarm_session_secret(self) -> None:
        """Remove the secret file, which is what a teardown proves absent."""
        path = self.settings.state_directory / SESSION_SECRET_FILE_NAME
        if path.is_symlink() or path.exists():
            path.unlink()
        self.session_secret = ""

    def admitted_origin(self, request: Request) -> str:
        """Return the request Origin where the launch admits it."""
        origin = request.header("origin")
        return origin if origin and origin in self.settings.origins else ""

    def require_admitted_host(self, request: Request) -> str:
        """Require the Host header to name one admitted literal, and return it."""
        named = host_header_names(request.header("host"), self.settings.admitted_hosts)
        if not named:
            raise AuthorizationDenied(
                "the request Host names no admitted literal: "
                + ", ".join(self.settings.admitted_hosts)
            )
        return named

    def require_session(self, request: Request) -> None:
        """Require the gateway session, which the open opt-in removes.

        The open opt-in is the operator's decision that this appliance serves
        its own network without a credential step, so the check returns where
        it is set and the closed Host set, the Origin allowlist, the
        per-launch session secret, and the single-use grant carry the gate.
        """
        if self.settings.open_lan:
            return
        outcome = self.session_check(request)
        if not outcome.admitted:
            raise AuthorizationDenied(
                "the request carries no admitted gateway session"
                + (f": {outcome.reason}" if outcome.reason else "")
            )

    def require_session_secret(self, request: Request) -> None:
        presented = request.header(SESSION_HEADER)
        if not presented or not hmac.compare_digest(presented, self.session_secret):
            raise StaleSessionSecret(f"the request carries no valid {SESSION_HEADER} header")


def read_body(request: Request) -> object:
    """Return the JSON body of a request inside the byte cap."""
    if len(request.body) > REQUEST_BODY_BYTE_CAP:
        raise InvalidArgument(f"the request body exceeds the {REQUEST_BODY_BYTE_CAP} byte cap")
    try:
        return json.loads(request.body.decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        raise InvalidArgument("the request body is not UTF-8 JSON") from None


def json_response(
    status: int, payload: Mapping[str, object], origin: str = "", retry_after: int | None = None
) -> Response:
    """Return one JSON answer with the cache, sniff, and Origin headers set.

    The echoed Origin is one entry of the configured allowlist, so a wildcard
    never reaches a response, and credentials stay unallowed because the
    session header rather than a cookie carries the approval authority.
    """
    headers: dict[str, str] = {
        "content-type": "application/json",
        "cache-control": "no-store",
        "x-content-type-options": "nosniff",
    }
    if retry_after is not None:
        headers["retry-after"] = str(retry_after)
    if origin:
        headers["access-control-allow-origin"] = origin
        headers["vary"] = "Origin"
    return Response(status, json.dumps(payload).encode("utf-8"), headers)


def search_audit_row(
    settings: ApprovalSettings,
    request: SearchGrantRequest | None,
    status: str,
    started_at: float,
) -> AuditRow:
    """Return the audit row one search grant request writes.

    The trail carries the SHA-256 of the query and the domain filters rather
    than the query itself, and it carries neither the signing key nor the
    issued grant: a row retaining the token would hand a reader the
    authorization whose single use the ledger exists to spend.
    """
    query_sha256 = ""
    domains = ""
    result_count = 0
    if request is not None:
        query_sha256 = hashlib.sha256(request.query.strip().encode("utf-8")).hexdigest()
        domains = ",".join(
            sorted(request.include_domains)
            + [f"-{entry}" for entry in sorted(request.exclude_domains)]
        )
        result_count = request.max_results
    now = time.time()
    return AuditRow(
        recorded_at=utc_timestamp(now),
        profile=settings.profile,
        operation="authorize",
        query_sha256=query_sha256,
        domains=domains,
        result_count=result_count,
        fetched_host="",
        provider_bytes=0,
        returned_characters=0,
        latency_ms=int((now - started_at) * 1000),
        status=status,
        recorded_epoch=int(now),
    )


def image_audit_row(
    settings: ApprovalSettings,
    request: ImageGrantRequest | None,
    status: str,
    started_at: float,
) -> AuditRow:
    """Return the audit row one image grant request writes.

    The row fills the same twelve-column vocabulary the search trail uses, so
    one table answers what a session authorized. `query_sha256` carries the
    prompt digest, which is the value the claim itself binds, and `domains`
    carries the language and image profile pair, so a reader separates the two
    grant contexts by `operation` and reads the profiles a grant joined
    without recovering the prompt.
    """
    prompt_sha256 = ""
    profiles = ""
    if request is not None:
        prompt_sha256 = request.prompt_hash
        profiles = f"{request.language_profile}>{request.image_profile}"
    now = time.time()
    return AuditRow(
        recorded_at=utc_timestamp(now),
        profile=settings.profile,
        operation="authorize-image",
        query_sha256=prompt_sha256,
        domains=profiles,
        result_count=0,
        fetched_host="",
        provider_bytes=0,
        returned_characters=0,
        latency_ms=int((now - started_at) * 1000),
        status=status,
        recorded_epoch=int(now),
    )


def _refusal_response(error: ToolError, origin: str, started_at: float) -> Response:
    """Return the answer one refused grant request carries."""
    payload: dict[str, object] = {"error": str(error)}
    if isinstance(error, StaleSessionSecret):
        payload["code"] = STALE_SESSION_SECRET_CODE
    retry_after: int | None = None
    if isinstance(error, OutstandingImageGrantExhausted):
        retry_after = error.retry_after
    elif error.status in ("rate_limited", "budget_exhausted"):
        retry_after = retry_after_seconds(BUCKET_WINDOW_SECONDS, started_at)
    return json_response(HTTP_STATUS_FOR_TERM.get(error.status, 400), payload, origin, retry_after)


def _handle_grant(service: ApprovalService, request: Request, *, image: bool) -> Response:
    """Sign the grant for the exact arguments a human has just approved.

    Each admitted outcome writes one audit row, and every exhausted refusal
    coalesces to one row per bucket window so post-limit requests cannot grow
    the audit trail. The two routes share every gate ahead of the body: what
    differs is the context they sign under, and `sign_claim` covers the
    context string, so neither token verifies as the other.
    """
    settings = service.settings
    started_at = time.time()
    origin = service.admitted_origin(request)
    ledger: Ledger | None = None
    search_fields: SearchGrantRequest | None = None
    image_fields: ImageGrantRequest | None = None
    try:
        service.require_admitted_host(request)
        if settings.exposure:
            service.require_session(request)
        ledger = Ledger(settings.state_directory)
        ledger.consume(AGGREGATE_BUCKET, BUCKET_WINDOW_SECONDS, settings.per_minute, started_at)
        # The aggregate bucket above bounds every caller together; this one
        # bounds one peer, keyed by the connection address rather than a
        # header a caller chooses. It is a second `consume` call rather than a
        # shared transaction, so it spends the aggregate even where it then
        # refuses.
        client = request.client_address
        client_bucket = f"{'grant-image' if image else 'grant'}-client-minute:{client}"
        client_limit = (
            settings.image_grant_per_client_per_minute
            if image
            else settings.grant_per_client_per_minute
        )
        ledger.consume(client_bucket, BUCKET_WINDOW_SECONDS, client_limit, started_at)
        if not origin:
            raise AuthorizationDenied("the request Origin is absent or outside the admitted set")
        service.require_session_secret(request)
        payload = read_body(request)
        if image:
            reserved_expiry = started_at + settings.lifetime
            service.outstanding_image_grants.reserve(client, started_at, reserved_expiry)
            try:
                image_fields = parse_image_request(payload)
                token = _issue_image(settings, image_fields)
            except BaseException:
                service.outstanding_image_grants.release(client, reserved_expiry)
                raise
            ledger.record(image_audit_row(settings, image_fields, "success", started_at))
        else:
            search_fields = parse_search_request(payload)
            token = _issue_search(settings, search_fields)
            ledger.record(search_audit_row(settings, search_fields, "success", started_at))
    except ToolError as error:
        if ledger is not None:
            row = (
                image_audit_row(settings, image_fields, error.status, started_at)
                if image
                else search_audit_row(settings, search_fields, error.status, started_at)
            )
            if error.status == "rate_limited":
                ledger.record_coalesced(row, BUCKET_WINDOW_SECONDS, started_at)
            else:
                ledger.record(row)
        return _refusal_response(error, origin, started_at)
    finally:
        if ledger is not None:
            ledger.close()
    return json_response(200, {"authorization": token}, origin)


def _issue_search(settings: ApprovalSettings, request: SearchGrantRequest) -> str:
    """Sign the search grant, against the profile this service was launched for.

    The requested `profile_id` names the web profile the browser selected and
    `settings.profile` names the profile the MCP child compares a spent
    grant's `profile_id` against. Signing the requested name instead of the
    launch name would issue a grant that reads as authorized here and is
    refused at the child, so a mismatch is refused here against the same name
    the grant is actually signed with.
    """
    if request.profile_id != settings.profile:
        raise InvalidArgument(
            f"the approval service serves profile {settings.profile!r}; "
            f"the request named {request.profile_id!r}"
        )
    return issue_search_grant(
        settings.token_key_file,
        request,
        provider=settings.provider,
        profile=settings.profile,
        lifetime=settings.lifetime,
    )


def _issue_image(settings: ApprovalSettings, request: ImageGrantRequest) -> str:
    """Sign the generation grant, against both profiles the claim joins.

    `image_grant.enforce_image_authorization` compares each against a separate
    setting the MCP child reads -- `QWEN_IMAGE_LANGUAGE_PROFILE` and
    `QWEN_IMAGE_PROFILE` -- so both names are bound here and a mismatch is
    refused against the name the grant would carry rather than at the child
    against a token that already left the machine. An empty image profile is a
    launch that armed no image lane, and every generation grant is refused
    rather than signed for a profile no ledger row admitted.
    """
    if not settings.image_profile:
        raise InvalidArgument(
            "this gateway serves no image profile, so it signs no generation grant"
        )
    if request.language_profile != settings.profile:
        raise InvalidArgument(
            f"the approval service serves profile {settings.profile!r}; "
            f"the request named language profile {request.language_profile!r}"
        )
    if request.image_profile != settings.image_profile:
        raise InvalidArgument(
            f"the approval service serves image profile {settings.image_profile!r}; "
            f"the request named {request.image_profile!r}"
        )
    return issue_image_grant(settings.token_key_file, request, settings.lifetime)


def _handle_session(service: ApprovalService, request: Request) -> Response:
    """Hand the per-launch secret to an admitted page holding a session.

    The secret travels in a response body rather than a URL, so it stays out
    of the browser history, the Referer header, and any intermediary log. The
    Origin allowlist and the gateway session form the gate; an absent Origin
    or an unadmitted session releases no secret.
    """
    origin = service.admitted_origin(request)
    try:
        service.require_admitted_host(request)
        if not origin:
            raise AuthorizationDenied("the request Origin is absent or outside the admitted set")
        service.require_session(request)
    except ToolError as error:
        return json_response(
            HTTP_STATUS_FOR_TERM.get(error.status, 400), {"error": str(error)}, origin
        )
    return json_response(200, {"session_secret": service.session_secret}, origin)


def routes(service: ApprovalService) -> tuple[Route, ...]:
    """Return the approval routes mounted under the gateway."""
    return (
        Route.make(
            "POST", GRANT_PATH, lambda request: _handle_grant(service, request, image=False)
        ),
        Route.make(
            "POST",
            IMAGE_GRANT_PATH,
            lambda request: _handle_grant(service, request, image=True),
        ),
        Route.make("GET", SESSION_PATH, lambda request: _handle_session(service, request)),
    )
