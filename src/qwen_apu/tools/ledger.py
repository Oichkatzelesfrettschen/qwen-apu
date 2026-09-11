"""The SQLite ledger a grant is metered, audited, and spent in.

`remote/web-mcp/server.py` holds the predecessor of this table set and stays
the llama-server stdio tool child, so both writers open one database file at
`<state>/web-mcp-state.sqlite3` and agree on every schema name, every bucket
name, and the primary key that spends a grant once. The child re-derives the
directory and file rules on every spawn and refuses on a mismatch, so this
module applies them identically: umask 0o077, a directory at mode 0700 owned
by this user, a regular database file chmod 0600, and the audit table's seven
provenance columns added where an earlier revision's table lacks them.

The journal mode is DELETE beside `secure_delete = ON` rather than WAL. The
`content` table holds fetched page text and a WAL leaves page images in a
sidecar until a checkpoint runs, so DELETE is what bounds a body's lifetime by
its row. `journal_mode` also lives in the database header rather than in a
connection, so a WAL conversion here would carry into the MCP child, whose own
`PRAGMA journal_mode = DELETE` returns the current mode while another
connection is open rather than changing it.

`BEGIN IMMEDIATE` holds the write lock across the read and the write of every
bucket and every grant, so two callers metering concurrently serialize rather
than reading one count and both writing it back, and `busy_timeout` of 10000
milliseconds is what lets the second wait rather than fail.

The failure classes live here because `status` names the audit vocabulary
entry a refusal is recorded under: the table and the terms it admits are one
declaration.
"""

from __future__ import annotations

import os
import sqlite3
import stat
import time
from dataclasses import dataclass, field
from pathlib import Path

LEDGER_FILE_NAME = "web-mcp-state.sqlite3"
STATE_DIRECTORY_MODE = 0o700
LEDGER_FILE_MODE = 0o600
LEDGER_BUSY_TIMEOUT_SECONDS = 10.0
LEDGER_BUSY_TIMEOUT_MS = 10000
AUDIT_RETENTION_SECONDS = 14 * 86400
GRANT_MAX_USES = 1

AGGREGATE_BUCKET = "authorize-minute"
BUCKET_WINDOW_SECONDS = 60


class ToolError(Exception):
    """An expected execution failure: policy, input, or provider grounds.

    `status` names the audit vocabulary entry the failure is recorded under.
    The message varies with the argument that produced it and the audit trail
    is queried across calls, so the row carries the fixed term and the caller
    receives the prose.
    """

    status = "invalid_argument"


class InvalidArgument(ToolError):
    """An argument, a configuration value, or a key file refuses the call."""


class AuthorizationDenied(ToolError):
    """A grant or a result identifier fails verification against the key."""

    status = "authorization_denied"


class RateLimited(ToolError):
    """A per-minute call bucket is exhausted."""

    status = "rate_limited"


class BudgetExhausted(ToolError):
    """A daily page or provider-cost budget is exhausted."""

    status = "budget_exhausted"


class ExpiredResult(ToolError):
    """A signed claim verifies and its term has run out."""

    status = "expired_result"


class GrantReplayed(AuthorizationDenied):
    """A grant whose single use the ledger already recorded."""


AUDIT_PROVENANCE_COLUMNS: tuple[tuple[str, str], ...] = (
    ("search_id", "TEXT"),
    ("category", "TEXT"),
    ("engines_attempted", "TEXT"),
    ("engines_answered", "TEXT"),
    ("engines_failed", "TEXT"),
    ("fallback_used", "INTEGER"),
    ("usable_results", "INTEGER"),
)

AUDIT_BASE_COLUMNS: tuple[str, ...] = (
    "recorded_at",
    "profile",
    "operation",
    "query_sha256",
    "domains",
    "result_count",
    "fetched_host",
    "provider_bytes",
    "returned_characters",
    "latency_ms",
    "status",
    "recorded_epoch",
)

# The trail is one table across the tools this ledger serves, so the
# vocabulary names every failure any of them records. A caller offering a term
# outside the set writes `internal_error`.
AUDIT_STATUSES: tuple[str, ...] = (
    "success",
    "authorization_denied",
    "invalid_argument",
    "rate_limited",
    "budget_exhausted",
    "provider_http_error",
    "provider_content_error",
    "expired_result",
    "service_refused",
    "service_unavailable",
    "internal_error",
)


def utc_timestamp(now: float) -> str:
    """Return the audit trail's own spelling of one instant."""
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now))


def retry_after_seconds(window_seconds: int, now: float) -> int:
    """Return the seconds until a fixed window closing at this instant refills.

    `Ledger._consume_bucket` is a fixed window rather than a rolling token
    bucket, so the caller's next admitted attempt is bounded by the window's
    own close rather than by a smoothed refill rate.
    """
    return window_seconds - int(now) % window_seconds


@dataclass(frozen=True)
class AuditRow:
    """One row of the twelve-column approval trail.

    The row carries the SHA-256 of the query rather than the query, the host
    rather than the URL, and byte and character counts rather than any text,
    so the trail states what ran while the approved words, the signing key,
    and the issued grant stay out of it. The seven provenance columns belong
    to a metasearch answer and an approval fills none, so each takes the empty
    value its declared type holds.
    """

    recorded_at: str
    profile: str
    operation: str
    query_sha256: str
    domains: str
    result_count: int
    fetched_host: str
    provider_bytes: int
    returned_characters: int
    latency_ms: int
    status: str
    recorded_epoch: int
    provenance: dict[str, str | int] = field(default_factory=dict)

    def values(self) -> list[str | int]:
        """Return the column values in `AUDIT_BASE_COLUMNS` order, provenance last."""
        status = self.status if self.status in AUDIT_STATUSES else "internal_error"
        base: list[str | int] = [
            self.recorded_at,
            self.profile,
            self.operation,
            self.query_sha256,
            self.domains,
            self.result_count,
            self.fetched_host,
            self.provider_bytes,
            self.returned_characters,
            self.latency_ms,
            status,
            int(self.recorded_epoch),
        ]
        return base + [
            self.provenance.get(column, "" if declaration == "TEXT" else 0)
            for column, declaration in AUDIT_PROVENANCE_COLUMNS
        ]


class Ledger:
    """A rate ledger and audit trail that outlive the process that wrote them.

    llama-server kills the MCP child after every call, so a counter in memory
    resets between two invocations and bounds nothing; the gateway is
    long-lived and shares the same file with that child, so the counters live
    in SQLite for both.
    """

    def __init__(self, directory: Path | str, now: float | None = None) -> None:
        """Open the state database inside a directory this user alone reaches.

        The directory holds the audit trail, the grant and search state, and
        the content snapshots, so its ownership and mode are checked rather
        than assumed: a symlink, another uid, or any group or world bit
        refuses the call. `os.umask(0o077)` runs first and is what gives the
        database and the rollback journal SQLite creates their private modes;
        it is a process-wide setting and the journal carries no explicit chmod
        behind it.
        """
        state_directory = Path(directory)
        os.umask(0o077)
        os.makedirs(state_directory, mode=STATE_DIRECTORY_MODE, exist_ok=True)
        directory_status = os.lstat(state_directory)
        if stat.S_ISLNK(directory_status.st_mode):
            raise InvalidArgument(
                f"the state directory is a symlink, which is refused: {state_directory}"
            )
        if not stat.S_ISDIR(directory_status.st_mode):
            raise InvalidArgument(f"the state path is not a directory: {state_directory}")
        if directory_status.st_uid != os.getuid():
            raise InvalidArgument(f"the state directory belongs to another user: {state_directory}")
        directory_mode = stat.S_IMODE(directory_status.st_mode)
        if directory_mode & 0o077:
            raise InvalidArgument(
                f"the state directory {state_directory} is mode {directory_mode:04o}; "
                f"{STATE_DIRECTORY_MODE:04o} is required before a call runs"
            )
        database_path = state_directory / LEDGER_FILE_NAME
        if database_path.exists() or database_path.is_symlink():
            database_status = os.lstat(database_path)
            if not stat.S_ISREG(database_status.st_mode):
                raise InvalidArgument(f"the state database is not a regular file: {database_path}")
            if database_status.st_uid != os.getuid():
                raise InvalidArgument(
                    f"the state database belongs to another user: {database_path}"
                )
            os.chmod(database_path, LEDGER_FILE_MODE)
        self.path = database_path
        self.connection = sqlite3.connect(
            database_path,
            timeout=LEDGER_BUSY_TIMEOUT_SECONDS,
            isolation_level=None,
        )
        os.chmod(database_path, LEDGER_FILE_MODE)
        self.connection.execute(f"PRAGMA busy_timeout = {LEDGER_BUSY_TIMEOUT_MS}")
        self.connection.execute("PRAGMA journal_mode = DELETE")
        self.connection.execute("PRAGMA secure_delete = ON")
        self._create_tables()
        self._migrate_audit_provenance()
        self.prune(time.time() if now is None else now)

    def _create_tables(self) -> None:
        """Declare every table the MCP child and the gateway share.

        `searches`, `search_results`, and `content` belong to the child's own
        fetch path and are declared here so a gateway that opens a fresh state
        directory leaves the child a complete database rather than one the
        child completes on its first spawn.
        """
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS buckets ("
            "name TEXT PRIMARY KEY, window_start INTEGER, used INTEGER)"
        )
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS audit ("
            "recorded_at TEXT, profile TEXT, operation TEXT, query_sha256 TEXT,"
            " domains TEXT, result_count INTEGER, fetched_host TEXT,"
            " provider_bytes INTEGER, returned_characters INTEGER,"
            " latency_ms INTEGER, status TEXT, recorded_epoch INTEGER)"
        )
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS grants ("
            "grant_id TEXT PRIMARY KEY, profile TEXT, provider TEXT,"
            " consumed_at INTEGER, expiry INTEGER)"
        )
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS searches ("
            "search_id TEXT PRIMARY KEY, profile TEXT, provider TEXT,"
            " fetches_used INTEGER, fetches_allowed INTEGER, expiry INTEGER)"
        )
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS search_results ("
            "search_id TEXT, canonical_url TEXT, provider_result_id TEXT,"
            " PRIMARY KEY(search_id, canonical_url))"
        )
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS content ("
            "content_id TEXT PRIMARY KEY, search_id TEXT, canonical_url TEXT,"
            " text TEXT, content_sha256 TEXT, may_have_more INTEGER,"
            " provider_status TEXT, retrieved_at INTEGER, expiry INTEGER)"
        )

    def _migrate_audit_provenance(self) -> None:
        """Add each provenance column the open table lacks.

        A database written by an earlier revision holds the twelve original
        columns and `CREATE TABLE IF NOT EXISTS` leaves it as it stands, so
        every insert names its columns rather than counting on the table's
        width and the missing ones are added here under one transaction.
        """
        self.connection.execute("BEGIN IMMEDIATE")
        try:
            present = {
                str(column[1]) for column in self.connection.execute("PRAGMA table_info(audit)")
            }
            for column, declaration in AUDIT_PROVENANCE_COLUMNS:
                if column not in present:
                    # The column name and its type come from this module's own
                    # frozen tuple, so the statement carries no caller value.
                    self.connection.execute(  # noqa: S608
                        f"ALTER TABLE audit ADD COLUMN {column} {declaration}"
                    )
            self.connection.execute("COMMIT")
        except BaseException:
            self.connection.execute("ROLLBACK")
            raise

    def prune(self, now: float) -> None:
        """Drop audit, grant, search, and content rows past their retention.

        The trail answers what ran over a bounded recent period and a spent
        grant is evidence only until its own expiry passes, so retention runs
        where the database is already open rather than through a separate
        maintenance path a respawned child would never execute.
        """
        self.connection.execute(
            "DELETE FROM audit WHERE recorded_epoch IS NOT NULL AND recorded_epoch < ?",
            (int(now) - AUDIT_RETENTION_SECONDS,),
        )
        self.connection.execute("DELETE FROM grants WHERE expiry < ?", (int(now),))
        self.connection.execute("DELETE FROM searches WHERE expiry < ?", (int(now),))
        self.connection.execute(
            "DELETE FROM search_results WHERE search_id NOT IN (SELECT search_id FROM searches)"
        )
        self.connection.execute("DELETE FROM content WHERE expiry < ?", (int(now),))
        self.connection.commit()

    def _consume_bucket(
        self,
        name: str,
        window_seconds: int,
        limit: int,
        now: float,
        *,
        exhausted: type[ToolError] = RateLimited,
        units: int = 1,
    ) -> None:
        """Consume one bucket inside the caller's active transaction."""
        window_start = int(now) - int(now) % window_seconds
        row = self.connection.execute(
            "SELECT window_start, used FROM buckets WHERE name = ?", (name,)
        ).fetchone()
        used = int(row[1]) if row and row[0] == window_start else 0
        if used + units > limit:
            raise exhausted(
                f"the {name} rate limit of {limit} per {window_seconds} seconds is exhausted"
            )
        self.connection.execute(
            "INSERT INTO buckets(name, window_start, used) VALUES(?, ?, ?) "
            "ON CONFLICT(name) DO UPDATE SET window_start = excluded.window_start,"
            " used = excluded.used",
            (name, window_start, used + units),
        )

    def consume(
        self,
        name: str,
        window_seconds: int,
        limit: int,
        now: float,
        *,
        exhausted: type[ToolError] = RateLimited,
        units: int = 1,
    ) -> None:
        """Take `units` of a bucket, or refuse with the caller's failure class.

        `exhausted` states which audit term the refusal carries: a per-minute
        call bucket records `rate_limited` and a daily budget records
        `budget_exhausted`, so the trail separates a call that arrived too fast
        from one that spent an exhausted allowance.
        """
        self.connection.execute("BEGIN IMMEDIATE")
        try:
            self._consume_bucket(name, window_seconds, limit, now, exhausted=exhausted, units=units)
            self.connection.execute("COMMIT")
        except BaseException:
            self.connection.execute("ROLLBACK")
            raise

    def consume_grant(
        self, grant_id: str, profile: str, provider: str, *, expiry: float, now: float
    ) -> None:
        """Spend the single use of one grant, or refuse a replay.

        The primary key is the grant identifier, so the insert is the
        enforcement: `BEGIN IMMEDIATE` holds the write lock across the read and
        the write, and a second caller presenting the same token meets a
        constraint violation rather than a count two readers both saw as zero.
        `prune` drops the row once the grant's own expiry passes, which keeps
        the table bounded by the lifetime rather than by the traffic.
        """
        self.connection.execute("BEGIN IMMEDIATE")
        try:
            self.connection.execute(
                "INSERT INTO grants(grant_id, profile, provider, consumed_at, expiry)"
                " VALUES(?, ?, ?, ?, ?)",
                (grant_id, profile, provider, int(now), int(expiry)),
            )
            self.connection.execute("COMMIT")
        except sqlite3.IntegrityError:
            self.connection.execute("ROLLBACK")
            raise GrantReplayed(
                "the authorization is spent; a grant admits one search and "
                "the operator issues another"
            ) from None
        except BaseException:
            self.connection.execute("ROLLBACK")
            raise

    def record(self, row: AuditRow) -> None:
        """Append one audit row under the twelve-term vocabulary."""
        columns = list(AUDIT_BASE_COLUMNS) + [column for column, _ in AUDIT_PROVENANCE_COLUMNS]
        # Every name comes from this module's own frozen tuples and every
        # value travels as a bound parameter.
        self.connection.execute(  # noqa: S608
            "INSERT INTO audit ("
            + ", ".join(columns)
            + ") VALUES("
            + ", ".join("?" for _ in columns)
            + ")",
            row.values(),
        )
        self.connection.commit()

    def record_coalesced(self, row: AuditRow, window_seconds: int, bucket_epoch: float) -> None:
        """Record an outcome once per bucket window, atomically.

        An exhausted caller can continue opening connections without consuming
        a bucket unit. Recording every refusal would make the audit table grow
        at the caller's connection rate after the limiter has already stopped
        useful work, so the presence check and the insert run as one state
        transition under `BEGIN IMMEDIATE` across concurrent handlers.
        """
        epoch = int(bucket_epoch)
        window_start = epoch - epoch % window_seconds
        window_end = window_start + window_seconds
        self.connection.execute("BEGIN IMMEDIATE")
        try:
            existing = self.connection.execute(
                "SELECT 1 FROM audit WHERE operation = ? AND status = ?"
                " AND recorded_epoch >= ? AND recorded_epoch < ? LIMIT 1",
                (row.operation, row.status, window_start, window_end),
            ).fetchone()
            if existing is None:
                columns = list(AUDIT_BASE_COLUMNS) + [
                    column for column, _ in AUDIT_PROVENANCE_COLUMNS
                ]
                self.connection.execute(  # noqa: S608
                    "INSERT INTO audit ("
                    + ", ".join(columns)
                    + ") VALUES("
                    + ", ".join("?" for _ in columns)
                    + ")",
                    row.values(),
                )
            self.connection.execute("COMMIT")
        except BaseException:
            self.connection.execute("ROLLBACK")
            raise

    def close(self) -> None:
        self.connection.close()
