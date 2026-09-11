"""The browser's only credential: one HttpOnly cookie, obtained once by pairing.

The appliance bearer authorizes the router, the broker's signing routes, and
the artifact listener, and it stays in the process that holds it: it never
reaches a URL fragment, `localStorage`, or a response body, because every one
of those persists the credential somewhere a later page read reaches. The
browser instead presents a session cookie marked HttpOnly and SameSite=Strict,
so script cannot read it and no cross-site request carries it, and Secure
joins those two wherever the gateway binds past loopback.

`POST /api/pair` is the one route that mints a session. The gateway mints a
pairing code at start, writes it to `<state>/gateway-pairing.secret` at mode
0600, and the operator reads it from `qwen-apu status`; the first success
consumes it and unlinks the file, and eight failures end pairing for the
process lifetime. The attempt meter is `server.Ledger._consume_bucket`'s fixed
window, keyed on the client address the kernel accepted the connection from:
`window_start = int(now) - int(now) % window_seconds` with the caller's next
admitted attempt bounded by the window's own close rather than by a smoothed
refill rate.
"""

from __future__ import annotations

import hmac
import os
import secrets
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from http.cookies import SimpleCookie
from pathlib import Path

from qwen_apu.web.app import RequestRefused
from qwen_apu.web.http import Request, Response, Route

SESSION_COOKIE = "qwen_apu_session"
PAIRING_CODE_FILENAME = "gateway-pairing.secret"
SECRET_MODE = 0o600

# secrets.token_urlsafe(32) encodes 32 random bytes, the width the session
# token and the pairing code both carry.
TOKEN_BYTES = 32
SESSION_LIFETIME_SECONDS = 12 * 3600

# Eight attempts across the process, and three per client address per minute:
# the first bounds a guess against one pairing code and the second bounds the
# rate at which any one peer spends them. `QWEN_WEB_GRANT_PER_CLIENT_PER_MINUTE`
# defaults to 3 in authorize-broker.py, which is the shape this reuses.
PAIRING_ATTEMPT_LIMIT = 8
PAIRING_PER_CLIENT_PER_MINUTE = 3
PAIRING_WINDOW_SECONDS = 60

# Every other `/api/*` path passes `require_session`. Health answers a probe
# that holds no session, and pairing is the route that creates one.
UNGUARDED_PATHS = frozenset({"/api/health", "/api/pair"})


class RateLimited(RequestRefused):
    """A fixed-window bucket refused this caller until the window closes."""


def retry_after_seconds(window_seconds: int, now: float) -> int:
    """Seconds until the fixed window closes.

    `server.Ledger._consume_bucket` is a fixed window rather than a rolling
    token bucket, so the caller's next admitted attempt is bounded by the
    window's own close.
    """
    return window_seconds - int(now) % window_seconds


@dataclass
class FixedWindowBucket:
    """`server.Ledger._consume_bucket`, held in memory rather than in SQLite.

    The gateway's meter bounds one process's own pairing attempts rather than
    a grant ledger several processes share, so the window lives beside the
    sessions it protects and leaves with them.
    """

    window_seconds: int
    limit: int
    _windows: dict[str, tuple[int, int]] = field(default_factory=dict)
    _lock: threading.Lock = field(default_factory=threading.Lock)

    def consume(self, name: str, now: float, units: int = 1) -> None:
        window_start = int(now) - int(now) % self.window_seconds
        with self._lock:
            recorded = self._windows.get(name)
            used = recorded[1] if recorded and recorded[0] == window_start else 0
            if used + units > self.limit:
                raise RateLimited(
                    429,
                    f"the {name} rate limit of {self.limit} per "
                    f"{self.window_seconds} seconds is exhausted",
                    retry_after_seconds(self.window_seconds, now),
                )
            self._windows[name] = (window_start, used + units)


@dataclass(frozen=True)
class Session:
    token: str
    expiry: float
    client_address: str


class SessionGate:
    """The pairing route, the session store, and the gate `/api/*` passes."""

    def __init__(
        self,
        state_directory: Path,
        *,
        secure_cookie: bool = False,
        lifetime_s: float = SESSION_LIFETIME_SECONDS,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.state_directory = state_directory
        self.secure_cookie = secure_cookie
        self.lifetime_s = lifetime_s
        self.clock = clock
        self.attempts = 0
        self._code: str | None = None
        self._sessions: dict[str, Session] = {}
        self._lock = threading.Lock()
        self._bucket = FixedWindowBucket(PAIRING_WINDOW_SECONDS, PAIRING_PER_CLIENT_PER_MINUTE)

    @property
    def secret_path(self) -> Path:
        return self.state_directory / PAIRING_CODE_FILENAME

    def start(self) -> str:
        """Mint one pairing code and write it where `qwen-apu status` reads it.

        The descriptor opens with O_CREAT and the mode the file must carry, and
        `os.chmod` applies it again because the process umask clears bits at
        creation and leaves a previous file's mode untouched. The code reaches
        the operator through this file alone: it stays out of the process
        arguments, out of the environment, and out of every response body.
        """
        self.state_directory.mkdir(parents=True, exist_ok=True)
        code = secrets.token_urlsafe(TOKEN_BYTES)
        descriptor = os.open(self.secret_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, SECRET_MODE)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(f"{code}\n")
        os.chmod(self.secret_path, SECRET_MODE)
        with self._lock:
            self._code = code
            self.attempts = 0
        return code

    def routes(self) -> tuple[Route, ...]:
        return (Route.make("POST", "/api/pair", self.pair),)

    def guards(self, path: str) -> bool:
        return path.startswith("/api/") and path not in UNGUARDED_PATHS

    def pair(self, request: Request) -> Response:
        """Spend one pairing attempt, and mint a session on the one that matches.

        The meter runs ahead of the comparison because pairing carries no
        earlier credential to check: authorize-broker.py puts its bearer ahead
        of `ledger.consume` and records that the check is a no-op on a launch
        that holds no bearer, which leaves the meter first for exactly this
        case. The comparison itself is `hmac.compare_digest`, so a wrong code
        costs the same time whatever prefix it shares with the right one.
        """
        now = self.clock()
        self._bucket.consume(f"pair-client-minute:{request.client_address}", now)
        offered = self._offered_code(request)
        with self._lock:
            if self._code is None:
                raise RequestRefused(403, "the pairing code is spent; a restart mints another")
            if self.attempts >= PAIRING_ATTEMPT_LIMIT:
                raise RequestRefused(
                    403,
                    f"pairing refused: {PAIRING_ATTEMPT_LIMIT} attempts failed and the "
                    "code stays refused for this process lifetime",
                )
            self.attempts += 1
            if not hmac.compare_digest(offered, self._code):
                raise RequestRefused(403, "the pairing code does not match")
            self._code = None
            session = Session(
                token=secrets.token_urlsafe(TOKEN_BYTES),
                expiry=now + self.lifetime_s,
                client_address=request.client_address,
            )
            self._sessions[session.token] = session
        self.secret_path.unlink(missing_ok=True)
        answer = Response.json({"paired": True, "expires_in": int(self.lifetime_s)})
        return Response(
            answer.status,
            answer.body,
            {**dict(answer.headers), "set-cookie": self.cookie(session)},
        )

    def cookie(self, session: Session) -> str:
        """The one credential the browser holds.

        HttpOnly keeps script away from the value, SameSite=Strict keeps every
        cross-site request from carrying it, and Secure joins them wherever
        the listener binds past loopback, where a plaintext hop exists for a
        network attacker to read.
        """
        attributes = [
            f"{SESSION_COOKIE}={session.token}",
            "Path=/",
            f"Max-Age={int(self.lifetime_s)}",
            "HttpOnly",
            "SameSite=Strict",
        ]
        if self.secure_cookie:
            attributes.append("Secure")
        return "; ".join(attributes)

    def require_session(self, request: Request) -> None:
        """Admit a request carrying a live session cookie, and refuse every other."""
        token = self.presented_token(request)
        now = self.clock()
        with self._lock:
            session = self._sessions.get(token) if token else None
            if session is not None and session.expiry <= now:
                del self._sessions[session.token]
                session = None
        if session is None:
            raise RequestRefused(
                401,
                "the request carries no live session; pair once with the code "
                "`qwen-apu status` prints",
            )

    def presented_token(self, request: Request) -> str:
        jar = SimpleCookie()
        jar.load(request.header("cookie"))
        morsel = jar.get(SESSION_COOKIE)
        return morsel.value if morsel else ""

    def live_sessions(self) -> int:
        now = self.clock()
        with self._lock:
            return sum(1 for session in self._sessions.values() if session.expiry > now)

    @staticmethod
    def _offered_code(request: Request) -> str:
        payload = request.json()
        if not isinstance(payload, dict):
            raise RequestRefused(400, "the request body is not a JSON object")
        code = payload.get("code")
        if not isinstance(code, str) or not code:
            raise RequestRefused(400, "the request body names no pairing code")
        return code
