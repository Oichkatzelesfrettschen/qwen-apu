"""The approval gate every tool call from llama.cpp's page passes.

A guarded call parks until the operator decides; approval signs the grant the
MCP server verifies into `params`, denial and the wait's end answer the
model a refusal, and a tool no ledger guards passes untouched.
"""

from __future__ import annotations

import json
import os
import threading
import time
from collections.abc import Iterator
from pathlib import Path

import pytest

from qwen_apu.tools import approvals
from qwen_apu.web import tool_gate
from qwen_apu.web.http import Request

TOKEN_SECRET = "gate-token-secret-7QK2"  # noqa: S105 -- a fixture key
PROFILE = "web-open"
IMAGE_PROFILE = "image-sdxs-512-a"


@pytest.fixture
def workspace(tmp_path: Path) -> Iterator[Path]:
    previous_umask = os.umask(0o077)
    (tmp_path / "state").mkdir(mode=0o700)
    key = tmp_path / "token.key"
    key.write_text(TOKEN_SECRET + "\n", encoding="utf-8")
    key.chmod(0o600)
    yield tmp_path
    os.umask(previous_umask)


@pytest.fixture
def gate(workspace: Path) -> tool_gate.ToolGate:
    settings = approvals.build_settings(
        workspace / "state",
        workspace / "token.key",
        PROFILE,
        ("http://127.0.0.1:42069",),
        provider="searxng",
        image_profile=IMAGE_PROFILE,
    )
    return tool_gate.ToolGate(settings, wait_seconds=2.0)


def _request(method: str, path: str, body: bytes = b"", **params: str) -> Request:
    return Request(
        method=method,
        path=path,
        query={},
        headers={},
        body=body,
        client_address="127.0.0.1",
        path_params=params,
    )


def _decide(gate: tool_gate.ToolGate, call_id: str, decision: str) -> object:
    response = gate.decide(
        _request(
            "POST",
            f"{tool_gate.PENDING_PATH}/{call_id}",
            json.dumps({"decision": decision}).encode("utf-8"),
            call_id=call_id,
        )
    )
    return response.status, json.loads(response.body)


def _admit_in_thread(
    gate: tool_gate.ToolGate, body: dict[str, object]
) -> tuple[threading.Thread, dict[str, object]]:
    outcome: dict[str, object] = {}

    def run() -> None:
        try:
            outcome["body"] = gate.admit(body, "10.0.0.5")
        except tool_gate.ToolRefused as refusal:
            outcome["refusal"] = str(refusal)

    thread = threading.Thread(target=run)
    thread.start()
    return thread, outcome


def _pending(gate: tool_gate.ToolGate) -> list[dict[str, object]]:
    deadline = time.monotonic() + 2.0
    while time.monotonic() < deadline:
        payload = json.loads(gate.list_pending(_request("GET", tool_gate.PENDING_PATH)).body)
        if payload["pending"]:
            return list(payload["pending"])
        time.sleep(0.01)
    return []


SEARCH_CALL: dict[str, object] = {
    "tool": "web_search_exa",
    "model": "web-open",
    "params": {"query": "raven2 fclk states", "max_results": 3, "include_domains": ["kernel.org"]},
}


def test_an_unguarded_tool_passes_untouched(gate: tool_gate.ToolGate) -> None:
    body = {"tool": "web_fetch_exa", "params": {"result_id": "r1"}, "model": "web-open"}
    assert gate.admit(body, "10.0.0.5") == body
    assert json.loads(gate.list_pending(_request("GET", tool_gate.PENDING_PATH)).body) == {
        "pending": []
    }


def test_an_approved_search_carries_a_grant_over_its_own_arguments(
    gate: tool_gate.ToolGate,
) -> None:
    thread, outcome = _admit_in_thread(gate, SEARCH_CALL)
    listed = _pending(gate)
    assert len(listed) == 1
    entry = listed[0]
    assert entry["kind"] == "search"
    assert entry["model"] == "web-open"
    assert entry["params"] == SEARCH_CALL["params"]
    status, decided = _decide(gate, str(entry["id"]), "approve")
    assert status == 200 and decided["decision"] == "approve"
    thread.join(timeout=5)
    forwarded = outcome["body"]
    assert isinstance(forwarded, dict)
    params = forwarded["params"]
    assert isinstance(params, dict)
    claim = approvals.verify_claim(
        TOKEN_SECRET,
        approvals.AUTHORIZATION_CLAIM_CONTEXT,
        str(params["authorization"]),
        time.time(),
        "grant",
    )
    assert claim["query"] == "raven2 fclk states"
    assert claim["max_results"] == 3
    assert claim["include_domains"] == ["kernel.org"]
    assert claim["profile_id"] == PROFILE
    assert claim["provider"] == "searxng"
    # The rest of the call travels as the model wrote it.
    assert {key: params[key] for key in SEARCH_CALL["params"]} == SEARCH_CALL["params"]  # type: ignore[union-attr]
    assert forwarded["tool"] == "web_search_exa"
    assert not _pending_now(gate)


def _pending_now(gate: tool_gate.ToolGate) -> list[object]:
    listed = gate.list_pending(_request("GET", tool_gate.PENDING_PATH))
    return list(json.loads(listed.body)["pending"])


def test_a_denied_search_answers_the_model_a_refusal(gate: tool_gate.ToolGate) -> None:
    thread, outcome = _admit_in_thread(gate, SEARCH_CALL)
    entry = _pending(gate)[0]
    _decide(gate, str(entry["id"]), "deny")
    thread.join(timeout=5)
    assert outcome["refusal"] == "the operator denied this call"
    assert not _pending_now(gate)


def test_an_undecided_call_ends_as_a_refusal_after_the_wait(workspace: Path) -> None:
    settings = approvals.build_settings(
        workspace / "state",
        workspace / "token.key",
        PROFILE,
        ("http://127.0.0.1:42069",),
        provider="searxng",
    )
    quick = tool_gate.ToolGate(settings, wait_seconds=0.2)
    with pytest.raises(tool_gate.ToolRefused, match="no operator approved"):
        quick.admit(SEARCH_CALL, "10.0.0.5")
    assert not _pending_now(quick)


def test_a_decision_on_an_unknown_or_settled_call_is_refused(gate: tool_gate.ToolGate) -> None:
    assert _decide(gate, "nope", "approve")[0] == 404
    thread, _ = _admit_in_thread(gate, SEARCH_CALL)
    entry = _pending(gate)[0]
    assert _decide(gate, str(entry["id"]), "maybe")[0] == 400
    assert _decide(gate, str(entry["id"]), "deny")[0] == 200
    thread.join(timeout=5)
    assert _decide(gate, str(entry["id"]), "approve")[0] == 404


def test_an_approved_generation_binds_the_prompt_digests_and_frame(
    gate: tool_gate.ToolGate,
) -> None:
    call = {
        "tool": "image_generate_image",
        "model": "web-open",
        "params": {
            "prompt": "  a lighthouse at dusk ",
            "negative_prompt": "text",
            "seed": 77,
            "width": 512,
            "height": 512,
            "steps": 2,
            "profile_id": IMAGE_PROFILE,
        },
    }
    thread, outcome = _admit_in_thread(gate, call)
    entry = _pending(gate)[0]
    assert entry["kind"] == "image"
    _decide(gate, str(entry["id"]), "approve")
    thread.join(timeout=5)
    forwarded = outcome["body"]
    assert isinstance(forwarded, dict)
    params = forwarded["params"]
    assert isinstance(params, dict)
    claim = approvals.verify_claim(
        TOKEN_SECRET,
        approvals.IMAGE_CLAIM_CONTEXT,
        str(params["authorization"]),
        time.time(),
        "grant",
    )
    assert claim["prompt_hash"] == approvals.prompt_digest("a lighthouse at dusk")
    assert claim["negative_prompt_hash"] == approvals.prompt_digest("text")
    assert claim["seed"] == 77
    assert claim["aspect"] == "1:1"
    assert claim["max_dimension"] == 512
    assert claim["max_steps"] == 2
    assert claim["language_profile"] == PROFILE
    assert claim["image_profile"] == IMAGE_PROFILE


def test_a_generation_for_another_profile_is_refused_at_signing(
    gate: tool_gate.ToolGate,
) -> None:
    call = {
        "tool": "image_generate_image",
        "params": {
            "prompt": "x",
            "seed": 1,
            "width": 512,
            "height": 512,
            "steps": 1,
            "profile_id": "image-sd15-lcm-a",
        },
    }
    thread, outcome = _admit_in_thread(gate, call)
    entry = _pending(gate)[0]
    _decide(gate, str(entry["id"]), "approve")
    thread.join(timeout=5)
    assert "image-sd15-lcm-a" in str(outcome["refusal"])


def test_a_malformed_call_is_refused_before_it_parks(gate: tool_gate.ToolGate) -> None:
    with pytest.raises(tool_gate.ToolRefused, match="names no tool"):
        gate.admit({"params": {}}, "10.0.0.5")
    with pytest.raises(tool_gate.ToolRefused, match="no params object"):
        gate.admit({"tool": "web_search_exa", "params": "q"}, "10.0.0.5")
    assert not _pending_now(gate)
