#!/usr/bin/env python3
"""Issue one search grant per human approval, over a loopback HTTP service.

`server.py authorize` signs a grant from a command line, which suits an
operator and suits nothing that runs while a session is open. This broker
gives the same signing path a request interface for the browser front end: a
user interface that has just shown a human the exact proposed `search_exa`
arguments posts those arguments here and receives the signed grant that admits
them, so the model receives a token bound to the query the human read rather
than the query a note in the context rewrote.

The service holds three boundaries. It binds a loopback literal alone and
refuses any other host before the socket exists, so the grant endpoint reaches
the machine that runs the router and nothing on the network; a browser on the
SSH client machine reaches it through `ssh -L PORT:127.0.0.1:PORT` rather than
through a wider bind. Every request carries a per-launch session secret in a
header, delivered through a file at mode 0600 under the state directory and
compared with `hmac.compare_digest`, so a page the operator did not open
issues nothing. The signing key travels from its file into `sign_claim` and
into no response, no log line, and no audit row.

One approval issues one grant. The claim carries `max_uses` of one and the
serving path spends it under the ledger's primary key, so this service offers
one grade of approval and holds no standing permission.
"""

import argparse
import hashlib
import hmac
import http.server
import json
import os
import secrets
import signal
import socket
import sys
import time

BROKER_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
if BROKER_DIRECTORY not in sys.path:
    sys.path.insert(0, BROKER_DIRECTORY)

import server  # noqa: E402

LOOPBACK_HOSTS = ("127.0.0.1", "::1")
SESSION_SECRET_FILE_NAME = "authorize-session.secret"
SESSION_SECRET_BYTES = 32
SESSION_HEADER = "X-Qwen-Web-Session"
REQUEST_BODY_BYTE_CAP = 16384
AUTHORIZE_PER_MINUTE_DEFAULT = 6
GRANT_PATH = "/grant"
SESSION_PATH = "/session"


def loopback_host(value):
    """Return a host string this service admits, or raise for any other.

    The refusal runs against the configured string before the socket is
    created, so a wider bind fails at startup rather than serving until
    somebody reads the listening address. The name `localhost` is refused
    beside every routable literal: it resolves through the resolver, and
    `require_public_host` refuses it in the result-URL position for the same
    reason.
    """
    if value not in LOOPBACK_HOSTS:
        raise argparse.ArgumentTypeError(
            f"the broker binds a loopback literal alone; {value!r} is refused. "
            f"Admitted hosts: {', '.join(LOOPBACK_HOSTS)}"
        )
    return value


def host_header_is_loopback(header):
    """Return whether a Host header names a loopback literal and no other name.

    A browser that resolves an attacker-controlled name to 127.0.0.1 reaches
    this socket with that name in the Host header, so the bind alone leaves
    DNS rebinding open. Comparing the header against the same literals closes
    it: a request whose Host is a name rather than an address is refused.
    """
    if not header:
        return False
    value = header.strip()
    if value.startswith("["):
        closing = value.find("]")
        if closing < 0:
            return False
        return value[1:closing] in LOOPBACK_HOSTS
    return value.split(":", 1)[0] in LOOPBACK_HOSTS


def write_session_secret(state_directory):
    """Return the per-launch secret after placing it in a file the owner reads.

    The value in memory is the authority and the file is the delivery channel
    the user interface reads once at load, so a stale file left by a killed
    broker authorizes nothing against the next launch's secret. The file is
    created with O_EXCL at mode 0600 after any predecessor is removed, which
    keeps a pre-planted symlink from redirecting the write.
    """
    path = os.path.join(state_directory, SESSION_SECRET_FILE_NAME)
    secret = secrets.token_urlsafe(SESSION_SECRET_BYTES)
    if os.path.lexists(path):
        os.unlink(path)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        os.write(descriptor, (secret + "\n").encode("ascii"))
    finally:
        os.close(descriptor)
    return secret, path


def raise_interrupt(number, frame):
    """Turn a terminating signal into the exception the accept loop unwinds on."""
    raise KeyboardInterrupt(f"signal {number}")


class BrokerSettings:
    """What one broker launch signs, meters, and admits."""

    def __init__(self, arguments):
        self.token_key_file = arguments.token_key_file
        self.state_directory = arguments.state_dir
        self.provider = arguments.provider
        self.profile = arguments.profile
        self.lifetime = arguments.lifetime
        self.origins = tuple(arguments.origin)
        self.per_minute = arguments.per_minute
        self.session_secret = ""


def parse_request_arguments(payload):
    """Return the exact search fields a grant request names.

    The broker validates shape here and leaves every cap, hostname rule, and
    date form to `issue_grant`, which applies the helpers the serving path
    applies, so an approved argument and a served argument pass one validator.
    A field the request omits takes the same default the subcommand takes, so
    an approval dialog that shows nothing under a field approves the absence
    the search then sends.
    """
    if not isinstance(payload, dict):
        raise server.InvalidArgument("the request body is not an object")
    query = payload.get("query")
    if not isinstance(query, str):
        raise server.InvalidArgument("query must be a string")
    fields = {"query": query}
    for key in ("include_domains", "exclude_domains"):
        value = payload.get(key) or []
        if not isinstance(value, list) or not all(
            isinstance(entry, str) for entry in value
        ):
            raise server.InvalidArgument(f"{key} must be a list of strings")
        fields[key] = value
    for key in ("published_after", "published_before"):
        value = payload.get(key) or ""
        if not isinstance(value, str):
            raise server.InvalidArgument(f"{key} must be a string")
        fields[key] = value
    max_age_hours = payload.get("max_age_hours")
    if max_age_hours is not None and (
        not isinstance(max_age_hours, int) or isinstance(max_age_hours, bool)
    ):
        raise server.InvalidArgument("max_age_hours must be an integer or absent")
    fields["max_age_hours"] = max_age_hours
    max_results = payload.get("max_results")
    if max_results is None:
        max_results = 5
    if not isinstance(max_results, int) or isinstance(max_results, bool):
        raise server.InvalidArgument("max_results must be an integer")
    fields["max_results"] = max_results
    return fields


def audit_row(settings, fields, status, started_at):
    """Return the audit row one grant request writes.

    The trail carries the SHA-256 of the query and the domain filters rather
    than the query itself, which is the vocabulary `Ledger.record` already
    holds, and it carries neither the signing key nor the issued grant: a row
    retaining the token would hand a reader the authorization whose single use
    the ledger exists to spend.
    """
    query_digest = ""
    domains = ""
    result_count = 0
    if fields is not None:
        query_digest = hashlib.sha256(
            fields["query"].strip().encode("utf-8")
        ).hexdigest()
        domains = ",".join(
            sorted(fields["include_domains"])
            + [f"-{entry}" for entry in sorted(fields["exclude_domains"])]
        )
        result_count = fields["max_results"]
    now = time.time()
    return {
        "recorded_at": server.utc_timestamp(now),
        "profile": settings.profile,
        "operation": "authorize",
        "query_sha256": query_digest,
        "domains": domains,
        "result_count": result_count,
        "fetched_host": "",
        "provider_bytes": 0,
        "returned_characters": 0,
        "latency_ms": int((now - started_at) * 1000),
        "status": status,
        "recorded_epoch": int(now),
    }


def issue_for_request(settings, fields):
    """Sign the grant for exactly these arguments.

    `do_POST` charges the `authorize-minute` bucket ahead of every other check,
    including the session-header and body validation this function assumes
    already passed, so the meter here would double-charge one request.
    """
    return server.issue_grant(
        settings.token_key_file,
        fields["query"],
        fields["include_domains"],
        fields["exclude_domains"],
        fields["published_after"],
        fields["published_before"],
        fields["max_age_hours"],
        fields["max_results"],
        settings.provider,
        settings.profile,
        settings.lifetime,
    )


HTTP_STATUS_FOR_TERM = {
    "authorization_denied": 403,
    "rate_limited": 429,
    "budget_exhausted": 429,
    "expired_result": 403,
}


class BrokerHandler(http.server.BaseHTTPRequestHandler):
    """The two endpoints a user interface calls around one human approval."""

    protocol_version = "HTTP/1.1"
    server_version = "qwen-web-authorize-broker/1.0"
    sys_version = ""

    def log_message(self, fmt, *args):
        """Drop the default access log.

        A request line reaching stderr would carry the query an audit row
        deliberately reduces to a digest, so the ledger is the trail and this
        handler writes none of its own.
        """

    @property
    def settings(self):
        return self.server.broker_settings

    def allowed_origin(self):
        """Return the request Origin when the launch admits it, or an empty string."""
        origin = self.headers.get("Origin", "")
        return origin if origin and origin in self.settings.origins else ""

    def send_json(self, http_status, payload, origin=""):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(http_status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if origin:
            # The echoed value is one entry of the configured allowlist, so a
            # wildcard never reaches a response, and credentials stay
            # unallowed because the session header rather than a cookie
            # carries the authority.
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        self.end_headers()
        self.wfile.write(body)

    def require_loopback_host(self):
        if not host_header_is_loopback(self.headers.get("Host", "")):
            raise server.AuthorizationDenied(
                "the request Host names something other than a loopback literal"
            )

    def require_session_secret(self):
        presented = self.headers.get(SESSION_HEADER, "")
        if not presented or not hmac.compare_digest(
            presented, self.settings.session_secret
        ):
            raise server.AuthorizationDenied(
                f"the request carries no valid {SESSION_HEADER} header"
            )

    def read_body(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            raise server.InvalidArgument(
                "Content-Length is not an integer"
            ) from None
        if length < 0 or length > REQUEST_BODY_BYTE_CAP:
            raise server.InvalidArgument(
                f"the request body exceeds the {REQUEST_BODY_BYTE_CAP} byte cap"
            )
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            raise server.InvalidArgument(
                "the request body is not UTF-8 JSON"
            ) from None

    def do_OPTIONS(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        """Answer the preflight a custom header and a JSON body force.

        A browser sends this ahead of every grant request and a Python client
        sends it ahead of none, so the arm lives here and in the test rather
        than being discovered by a front end that fails while every test
        passes.
        """
        origin = self.allowed_origin()
        self.send_response(204 if origin else 403)
        self.send_header("Content-Length", "0")
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header(
                "Access-Control-Allow-Headers", f"Content-Type, {SESSION_HEADER}"
            )
            self.send_header("Access-Control-Max-Age", "60")
            self.send_header("Vary", "Origin")
        self.end_headers()

    def do_GET(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        """Hand the per-launch session secret to a page the launch admits.

        The secret travels in a response body rather than a URL, so it stays
        out of the browser history, the Referer header, and any intermediary
        log. The Origin allowlist is the gate and an absent Origin is refused,
        which leaves no fallback a cross-origin caller reaches by omitting the
        header.
        """
        origin = self.allowed_origin()
        if self.path.split("?", 1)[0] != SESSION_PATH:
            self.send_json(404, {"error": "no such endpoint"}, origin)
            return
        try:
            self.require_loopback_host()
            if not origin:
                raise server.AuthorizationDenied(
                    "the request Origin is absent or outside the admitted set"
                )
        except server.ToolError as error:
            self.send_json(
                HTTP_STATUS_FOR_TERM.get(error.status, 400),
                {"error": str(error)},
                origin,
            )
            return
        self.send_json(200, {"session_secret": self.settings.session_secret}, origin)

    def do_POST(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        """Sign the grant for the exact arguments a human has just approved.

        Each outcome writes one audit row under the nine-term vocabulary, so
        the trail separates a request refused for its session header from one
        refused for a malformed field, from one that exhausted the bucket,
        from a grant that issued -- while the grant itself stays in the
        response alone. The `authorize-minute` bucket is charged before the
        loopback-host and session-header checks run, so a caller that holds
        neither cannot reach `ledger.record` faster than the bucket admits;
        without that ordering an unauthenticated loopback process floods the
        session check alone and grows the audit table at whatever rate it
        can open connections, since every refusal still writes a row.
        """
        started_at = time.time()
        origin = self.allowed_origin()
        if self.path.split("?", 1)[0] != GRANT_PATH:
            self.send_json(404, {"error": "no such endpoint"}, origin)
            return
        ledger = self.server.broker_ledger
        fields = None
        try:
            ledger.consume("authorize-minute", 60, self.settings.per_minute, started_at)
            self.require_loopback_host()
            self.require_session_secret()
            fields = parse_request_arguments(self.read_body())
            token = issue_for_request(self.settings, fields)
        except server.ToolError as error:
            ledger.record(audit_row(self.settings, fields, error.status, started_at))
            self.send_json(
                HTTP_STATUS_FOR_TERM.get(error.status, 400),
                {"error": str(error)},
                origin,
            )
            return
        ledger.record(audit_row(self.settings, fields, "success", started_at))
        self.send_json(200, {"authorization": token}, origin)


class BrokerServer(http.server.HTTPServer):
    """One approval at a time over one ledger connection.

    The single-threaded server is the choice the SQLite connection makes: a
    threading server would hand one connection to several threads, and the
    approval this endpoint serves is a human action that arrives one at a
    time.
    """

    allow_reuse_address = False

    def __init__(self, address, settings, ledger):
        self.address_family = socket.AF_INET6 if ":" in address[0] else socket.AF_INET
        self.broker_settings = settings
        self.broker_ledger = ledger
        super().__init__(address, BrokerHandler)


def build_parser():
    parser = argparse.ArgumentParser(
        prog="authorize-broker.py",
        description="issue one search grant per human approval over loopback",
    )
    parser.add_argument("--host", type=loopback_host, default="127.0.0.1")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument(
        "--token-key-file", default=os.environ.get("QWEN_WEB_TOKEN_KEY_FILE", "")
    )
    parser.add_argument("--state-dir", default=os.environ.get("QWEN_WEB_STATE_DIR", ""))
    parser.add_argument("--provider", default=os.environ.get("QWEN_WEB_PROVIDER", "exa"))
    parser.add_argument(
        "--profile", default=os.environ.get("QWEN_WEB_PROFILE", "default")
    )
    parser.add_argument(
        "--lifetime", type=int, default=server.TOKEN_LIFETIME_DEFAULT_SECONDS
    )
    parser.add_argument("--per-minute", type=int, default=AUTHORIZE_PER_MINUTE_DEFAULT)
    parser.add_argument("--origin", action="append", default=None)
    return parser


def run(argv):
    """Serve until the caller ends the process, then remove the secret file."""
    arguments = build_parser().parse_args(argv)
    if arguments.origin is None:
        configured = os.environ.get("QWEN_WEB_BROKER_ORIGIN", "")
        arguments.origin = [entry for entry in configured.split(",") if entry]
    if not arguments.state_dir:
        sys.stderr.write(
            "the broker meters and audits through the ledger, so "
            "QWEN_WEB_STATE_DIR or --state-dir names the directory it lives in\n"
        )
        return 2
    if not arguments.origin:
        sys.stderr.write(
            "the session endpoint admits an explicit Origin alone, so "
            "QWEN_WEB_BROKER_ORIGIN or --origin names the page that reads it\n"
        )
        return 2
    settings = BrokerSettings(arguments)
    try:
        ledger = server.Ledger(arguments.state_dir)
    except (OSError, server.ToolError) as error:
        sys.stderr.write(f"the broker cannot open the ledger: {error}\n")
        return 2
    settings.session_secret, secret_path = write_session_secret(arguments.state_dir)
    service = BrokerServer((arguments.host, arguments.port), settings, ledger)
    # The port reaches the caller on stdout because an ephemeral bind is the
    # default: a launcher reads the line rather than guessing the number.
    sys.stdout.write(f"listening {arguments.host} {service.server_address[1]}\n")
    sys.stdout.flush()
    # A terminating signal raises inside the accept loop rather than ending the
    # process where it stands, so the cleanup below runs and the secret file
    # goes with the launch that wrote it. The default SIGTERM disposition would
    # leave that file behind for the next launch to find.
    for terminating_signal in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(terminating_signal, raise_interrupt)
    try:
        service.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        service.server_close()
        ledger.close()
        if os.path.lexists(secret_path):
            os.unlink(secret_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(run(sys.argv[1:]))
