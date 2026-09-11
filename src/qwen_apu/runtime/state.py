"""The runtime record, written whole on every transition.

`qwen-webui-session.sh` writes `session.status` with `>`, so each transition
truncates the file and a reader between the truncation and the write reads an
empty record; `qwen-teardown.sh` works around it by reading the guard PIDs
before it asks for a stop, because `state=stopped` drops them. This record is
written to a temporary leaf in the same directory and moved over the old one
with `os.replace`, so every reader sees one whole record and the fields
survive the transition that rewrites it.

The failure fields are two rather than one. `primary_failure` holds what ended
the service and is written once: the first cause is the one a reader acts on,
and a teardown that then fails to reach a clean machine states that separately
in `restoration_failures`, the residue the exit status reports. Overwriting
the first with the last would leave a supervisor that died of a kernel hazard
reporting a lease it could not prove free.
"""

from __future__ import annotations

import json
import os
import tempfile
from collections.abc import Mapping, Sequence
from dataclasses import asdict, dataclass, field, replace
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal

SCHEMA = "qwen-apu-runtime-state-v1"
RECORD_MODE = 0o600

State = Literal["starting", "running", "stopping", "stopped", "failed"]
STATES: tuple[State, ...] = ("starting", "running", "stopping", "stopped", "failed")
TERMINAL_STATES: frozenset[str] = frozenset({"stopped", "failed"})


def utc_now() -> str:
    """The stamp every shell record in this tree carries, to the second."""
    return datetime.now(tz=UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


@dataclass(frozen=True)
class RuntimeState:
    """One supervised service, as the supervisor last observed it."""

    state: State
    schema: str = SCHEMA
    supervisor_pid: int = 0
    supervisor_pgid: int = 0
    supervisor_start_time: int = 0
    server_pid: int = 0
    server_pgid: int = 0
    server_start_time: int = 0
    listener_inode: str = "-"
    port: int = 0
    model_id: str = "-"
    deployment: str = "-"
    profile: str = "-"
    control_socket: str = "-"
    workload_lease: str = "-"
    hazard_source: str = "-"
    hazard_skip_reason: str = "-"
    primary_failure: str | None = None
    restoration_failures: tuple[str, ...] = ()
    exit_status: int | None = None
    started_utc: str = "-"
    updated_utc: str = "-"

    def to_json(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["restoration_failures"] = list(self.restoration_failures)
        return payload

    @classmethod
    def from_json(cls, payload: Mapping[str, Any]) -> RuntimeState:
        fields = {entry.name for entry in cls.__dataclass_fields__.values()}
        values = {key: value for key, value in payload.items() if key in fields}
        restoration = values.get("restoration_failures") or ()
        if isinstance(restoration, Sequence) and not isinstance(restoration, str):
            values["restoration_failures"] = tuple(str(entry) for entry in restoration)
        else:
            values["restoration_failures"] = ()
        return cls(**values)

    @property
    def is_terminal(self) -> bool:
        return self.state in TERMINAL_STATES


@dataclass
class RuntimeRecord:
    """The file that carries one supervisor's runtime state."""

    path: Path
    current: RuntimeState | None = field(default=None)

    def read(self) -> RuntimeState | None:
        """The record as it stands, or None where no whole record is there.

        A truncated or unparseable file answers None rather than raising: the
        caller's next step is the same either way, and a supervisor that
        crashed mid-write leaves exactly that.
        """
        try:
            text = self.path.read_text(encoding="utf-8")
        except OSError:
            return None
        try:
            payload = json.loads(text)
        except ValueError:
            return None
        if not isinstance(payload, dict):
            return None
        try:
            return RuntimeState.from_json(payload)
        except TypeError:
            return None

    def write(self, record: RuntimeState) -> RuntimeState:
        """Publish one whole record: a temporary leaf beside it, then `os.replace`.

        The temporary leaf shares the directory so the rename stays inside one
        filesystem, which is what makes the replacement atomic for every
        reader.
        """
        stamped = replace(record, updated_utc=utc_now())
        self.path.parent.mkdir(parents=True, exist_ok=True)
        handle = tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=str(self.path.parent),
            prefix=f".{self.path.name}.",
            suffix=".new",
            delete=False,
        )
        temporary = Path(handle.name)
        try:
            with handle:
                json.dump(stamped.to_json(), handle, indent=2, sort_keys=True)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.chmod(temporary, RECORD_MODE)
            os.replace(temporary, self.path)
        except OSError:
            temporary.unlink(missing_ok=True)
            raise
        self.current = stamped
        return stamped

    def transition(self, state: State, **changes: Any) -> RuntimeState:
        """Move the record to one state, keeping every field the caller leaves.

        `primary_failure` is written once and every later cause joins
        `restoration_failures`, so the first cause stays readable beside
        whatever the teardown then failed to prove.
        """
        if state not in STATES:
            raise ValueError(f"unknown runtime state: {state}")
        base = self.current or self.read() or RuntimeState(state=state, started_utc=utc_now())
        failure = changes.pop("primary_failure", None)
        restoration = changes.pop("restoration_failures", None)
        record = replace(base, state=state, **changes)
        if failure is not None:
            if record.primary_failure is None:
                record = replace(record, primary_failure=failure)
            else:
                record = replace(
                    record, restoration_failures=(*record.restoration_failures, failure)
                )
        if restoration:
            record = replace(
                record,
                restoration_failures=(*record.restoration_failures, *tuple(restoration)),
            )
        return self.write(record)

    def note_restoration_failure(self, detail: str) -> RuntimeState:
        """Append one residue finding without moving the state."""
        base = self.current or self.read()
        if base is None:
            raise RuntimeError(f"no runtime record to append a residue finding to: {self.path}")
        return self.write(replace(base, restoration_failures=(*base.restoration_failures, detail)))


def read(path: Path) -> RuntimeState | None:
    """The record at a path, or None where no whole record is there."""
    return RuntimeRecord(path=path).read()
