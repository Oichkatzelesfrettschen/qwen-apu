#!/usr/bin/env python3
"""Test pure merged-pull-request gate-reuse classification."""

from __future__ import annotations

import importlib.util
import pathlib
import sys
import tempfile

DRIVER = pathlib.Path(__file__).with_name("merged-pr-gate-reuse.py")
SPEC = importlib.util.spec_from_file_location("merged_pr_gate_reuse", DRIVER)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

PUSHED = "a" * 40
HEAD = "b" * 40
PULL = {
    "number": 42,
    "state": "closed",
    "merged_at": "2026-09-09T00:00:00Z",
    "base": {"ref": "main"},
    "head": {"sha": HEAD},
    "merge_commit_sha": PUSHED,
}
RUN = {
    "id": 73,
    "run_attempt": 2,
    "name": "repository quality gates",
    "event": "pull_request",
    "head_sha": HEAD,
    "status": "completed",
    "conclusion": "success",
}

assert MODULE.select_merged_pull_request([PULL], PUSHED) == MODULE.PullRequest(
    42, PUSHED, HEAD
)
assert MODULE.select_merged_pull_request([], PUSHED) is None
assert MODULE.select_merged_pull_request([PULL, PULL], PUSHED) is None
assert (
    MODULE.select_merged_pull_request([{**PULL, "merge_commit_sha": HEAD}], PUSHED)
    is None
)
assert (
    MODULE.select_merged_pull_request([{**PULL, "base": {"ref": "release"}}], PUSHED)
    is None
)
assert MODULE.select_merged_pull_request([{**PULL, "merged_at": None}], PUSHED) is None
assert MODULE.select_merged_pull_request([{**PULL, "state": "open"}], PUSHED) is None
assert MODULE.commit_tree_sha({"tree": {"sha": PUSHED}}) == PUSHED
assert MODULE.commit_tree_sha({"tree": {"sha": "bad"}}) is None


def fixture_fetch(path: str) -> object:
    fixture = {
        f"/commits/{PUSHED}/pulls?per_page=100": [PULL],
        f"/git/commits/{PUSHED}": {"tree": {"sha": "c" * 40}},
        f"/git/commits/{HEAD}": {"tree": {"sha": "c" * 40}},
        "/actions/workflows/repository-quality-gates.yml/runs?event=pull_request"
        f"&status=completed&per_page=100&head_sha={HEAD}": {
            "total_count": 1,
            "workflow_runs": [RUN],
        },
        "/actions/runs/73/jobs?per_page=100": {
            "total_count": 1,
            "jobs": [
                {
                    "name": "clone-local",
                    "status": "completed",
                    "conclusion": "success",
                    "steps": [
                        {
                            "name": "Run clone-local gates",
                            "status": "completed",
                            "conclusion": "success",
                        },
                        {
                            "name": "Save accepted gate cell cache",
                            "status": "completed",
                            "conclusion": "success",
                        },
                    ],
                }
            ],
        },
    }
    return fixture[path]


def targeted_fixture_fetch(path: str) -> object:
    if path != "/actions/runs/73/jobs?per_page=100":
        return fixture_fetch(path)
    return {
        "total_count": 1,
        "jobs": [
            {
                "name": "clone-local",
                "status": "completed",
                "conclusion": "success",
                "steps": [
                    {
                        "name": "Run clone-local gates",
                        "status": "completed",
                        "conclusion": "success",
                    },
                    {
                        "name": "Save accepted gate cell cache",
                        "status": "completed",
                        "conclusion": "skipped",
                    },
                ],
            }
        ],
    }


assert MODULE.reuse_is_proven(fixture_fetch, PUSHED)
assert MODULE.reusable_gate_source(fixture_fetch, PUSHED) == MODULE.GateSource(
    73, 2, "exhaustive"
)
assert MODULE.reusable_gate_source(targeted_fixture_fetch, PUSHED) == MODULE.GateSource(
    73, 2, "targeted"
)
with tempfile.TemporaryDirectory() as temporary_directory:
    source_result = pathlib.Path(temporary_directory) / "source.tsv"
    MODULE.write_source(str(source_result), MODULE.GateSource(73, 2, "targeted"))
    assert source_result.read_text(encoding="utf-8") == (
        "field\tvalue\nsource_run_id\t73\nsource_run_attempt\t2\n"
        "source_gate_kind\ttargeted\n"
    )
try:
    MODULE.write_source("unused", MODULE.GateSource(73, 2))
except ValueError:
    pass
else:
    raise AssertionError("an unclassified gate source was written")
assert MODULE.successful_run_sources(
    {"total_count": 1, "workflow_runs": [RUN]}, HEAD
) == [MODULE.GateSource(73, 2)]
assert (
    MODULE.successful_run_sources({"total_count": 2, "workflow_runs": [RUN]}, HEAD)
    == []
)
assert (
    MODULE.successful_run_sources({"total_count": 0, "workflow_runs": None}, HEAD) == []
)
assert (
    MODULE.successful_run_sources(
        {"total_count": 1, "workflow_runs": [{**RUN, "event": "push"}]}, HEAD
    )
    == []
)
assert (
    MODULE.successful_run_sources(
        {"total_count": 1, "workflow_runs": [{**RUN, "run_attempt": 0}]}, HEAD
    )
    == []
)
assert MODULE.exhaustive_clone_local_succeeded(
    {
        "total_count": 1,
        "jobs": [
            {
                "name": "clone-local",
                "status": "completed",
                "conclusion": "success",
                "steps": [
                    {
                        "name": "Run clone-local gates",
                        "status": "completed",
                        "conclusion": "success",
                    },
                    {
                        "name": "Save accepted gate cell cache",
                        "status": "completed",
                        "conclusion": "success",
                    },
                ],
            }
        ],
    }
)
assert (
    MODULE.clone_local_gate_kind(
        {
            "total_count": 1,
            "jobs": [
                {
                    "name": "clone-local",
                    "status": "completed",
                    "conclusion": "success",
                    "steps": [
                        {
                            "name": "Run clone-local gates",
                            "status": "completed",
                            "conclusion": "success",
                        },
                        {
                            "name": "Save accepted gate cell cache",
                            "status": "completed",
                            "conclusion": "skipped",
                        },
                    ],
                }
            ],
        }
    )
    == "targeted"
)
assert not MODULE.exhaustive_clone_local_succeeded(
    {
        "total_count": 1,
        "jobs": [
            {
                "name": "clone-local",
                "status": "completed",
                "conclusion": "failure",
                "steps": [
                    {
                        "name": "Save accepted gate cell cache",
                        "status": "completed",
                        "conclusion": "success",
                    }
                ],
            }
        ],
    }
)
assert not MODULE.exhaustive_clone_local_succeeded(
    {
        "total_count": 1,
        "jobs": [
            {
                "name": "clone-local",
                "status": "completed",
                "conclusion": "success",
                "steps": [
                    {
                        "name": "Save accepted gate cell cache",
                        "status": "completed",
                        "conclusion": "skipped",
                    }
                ],
            }
        ],
    }
)
assert not MODULE.exhaustive_clone_local_succeeded({"total_count": 0, "jobs": []})
assert MODULE.clone_local_gate_kind({"total_count": 0, "jobs": []}) is None
assert not MODULE.exhaustive_clone_local_succeeded(
    {"total_count": 2, "jobs": [{"name": "clone-local"}, {"name": "clone-local"}]}
)
print("merged_pr_gate_reuse=accepted")
