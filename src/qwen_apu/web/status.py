"""What the gateway reports about itself, the upstream, and the supervisor.

`GET /api/health` is the probe a launcher runs before a page loads, so it
passes the session gate unguarded and answers the two facts a readiness loop
acts on: this process is up, and the upstream reports a serving model.
`GET /api/status` adds what the supervisor last published to
`state/runtime.json` and the pairing state an operator needs to reach the page.

Every field is named here rather than serialized from a record: the launch
plan the supervisor writes beside that record carries the profile environment
whole, and `QWEN_WEB_TOKEN_KEY_FILE` and the appliance bearer live in exactly
that environment. A fixed field list is what keeps a credential out of a
response no matter what a future record gains.
"""

from __future__ import annotations

import os
from collections.abc import Callable
from pathlib import Path

from qwen_apu.engines.llama import LlamaClient, UpstreamRefused, collect
from qwen_apu.runtime import state as runtime_state
from qwen_apu.runtime.health import health_is_serving
from qwen_apu.web.auth import SessionGate
from qwen_apu.web.http import Request, Response, Route

# The record fields a browser reads. Every one names a process identity, a
# deployment, or a timestamp; the launch plan, the profile environment, and
# the signing key stay out of the answer by staying off this list.
REPORTED_STATE_FIELDS: tuple[str, ...] = (
    "state",
    "server_pid",
    "server_start_time",
    "listener_inode",
    "port",
    "model_id",
    "deployment",
    "profile",
    "primary_failure",
    "started_utc",
    "updated_utc",
)


class StatusService:
    """The gateway's own health and status routes."""

    def __init__(
        self,
        client_factory: Callable[[], LlamaClient],
        *,
        runtime_record: Path,
        session_gate: SessionGate | None = None,
    ) -> None:
        self.client_factory = client_factory
        self.runtime_record = runtime_record
        self.session_gate = session_gate

    def routes(self) -> tuple[Route, ...]:
        return (
            Route.make("GET", "/api/health", self.health),
            Route.make("GET", "/api/status", self.status),
        )

    def upstream_report(self) -> dict[str, object]:
        """The upstream's own answer, reduced to what a page acts on.

        `health_is_serving` reads the status field rather than the 200:
        llama-server answers `{"status": "loading model"}` with a 200 while it
        streams a checkpoint in, and a page that reads the code alone sends a
        completion into a server that holds no model yet.
        """
        client = self.client_factory()
        try:
            answer = client.health()
            body = collect(answer).decode("utf-8", "replace")
        except UpstreamRefused as error:
            return {"reachable": False, "serving": False, "reason": str(error)}
        return {
            "reachable": True,
            "serving": answer.status == 200 and health_is_serving(body),
            "status": answer.status,
            "port": client.binding.port,
            "bound_to_process": client.binding.bound_to_process,
        }

    def health(self, request: Request) -> Response:
        return Response.json({"gateway": {"pid": os.getpid()}, "upstream": self.upstream_report()})

    def status(self, request: Request) -> Response:
        record = runtime_state.read(self.runtime_record)
        reported: dict[str, object] = {}
        if record is not None:
            payload = record.to_json()
            reported = {name: payload[name] for name in REPORTED_STATE_FIELDS}
        pairing: dict[str, object] = {}
        if self.session_gate is not None:
            pairing = {
                # The code itself stays in its 0600 file; the answer states
                # whether one is outstanding and how many attempts remain.
                "paired": not self.session_gate.secret_path.exists(),
                "attempts_spent": self.session_gate.attempts,
                "live_sessions": self.session_gate.live_sessions(),
            }
        return Response.json(
            {
                "gateway": {"pid": os.getpid(), "pairing": pairing},
                "upstream": self.upstream_report(),
                "runtime": reported,
            }
        )
