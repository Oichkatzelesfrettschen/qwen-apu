#!/usr/bin/env python3
"""Decide whether a main push may reuse its merged pull-request gate."""

from __future__ import annotations

import argparse
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Mapping
from dataclasses import dataclass

FULL_GATE_EXIT = 3
SHA_PATTERN = re.compile(r"[0-9a-f]{40}\Z")
Json = object
Fetch = Callable[[str], Json]


@dataclass(frozen=True)
class PullRequest:
    number: int
    merge_commit_sha: str
    head_sha: str


def sha(value: object) -> str | None:
    return value if isinstance(value, str) and SHA_PATTERN.fullmatch(value) else None


def parse_pull_request(value: Json, pushed_sha: str) -> PullRequest | None:
    if not isinstance(value, Mapping):
        return None
    number = value.get("number")
    base = value.get("base")
    head = value.get("head")
    merge_sha = sha(value.get("merge_commit_sha"))
    if (
        not isinstance(number, int)
        or value.get("state") != "closed"
        or not isinstance(value.get("merged_at"), str)
        or not value["merged_at"]
        or not isinstance(base, Mapping)
        or base.get("ref") != "main"
        or not isinstance(head, Mapping)
        or merge_sha != pushed_sha
    ):
        return None
    head_sha = sha(head.get("sha"))
    if head_sha is None:
        return None
    return PullRequest(number=number, merge_commit_sha=merge_sha, head_sha=head_sha)


def select_merged_pull_request(value: Json, pushed_sha: str) -> PullRequest | None:
    if not isinstance(value, list):
        return None
    candidates = [parse_pull_request(row, pushed_sha) for row in value]
    accepted = [candidate for candidate in candidates if candidate is not None]
    return accepted[0] if len(accepted) == 1 and len(value) == 1 else None


def exhaustive_clone_local_succeeded(value: Json) -> bool:
    if not isinstance(value, Mapping):
        return False
    jobs = value.get("jobs")
    if not isinstance(jobs, list) or value.get("total_count") != len(jobs):
        return False
    clone_jobs = [
        job
        for job in jobs
        if isinstance(job, Mapping) and job.get("name") == "clone-local"
    ]
    if len(clone_jobs) != 1:
        return False
    clone_job = clone_jobs[0]
    steps = clone_job.get("steps")
    if not isinstance(steps, list):
        return False
    cache_save_steps = [
        step
        for step in steps
        if isinstance(step, Mapping)
        and step.get("name") == "Save accepted gate cell cache"
    ]
    return (
        clone_job.get("status") == "completed"
        and clone_job.get("conclusion") == "success"
        and len(cache_save_steps) == 1
        and cache_save_steps[0].get("status") == "completed"
        and cache_save_steps[0].get("conclusion") == "success"
    )


def successful_run_ids(value: Json, head_sha: str) -> list[int]:
    if not isinstance(value, Mapping):
        return []
    runs = value.get("workflow_runs")
    if not isinstance(runs, list) or value.get("total_count") != len(runs):
        return []
    identifiers: list[int] = []
    for run in runs:
        if not isinstance(run, Mapping):
            return []
        run_id = run.get("id")
        if (
            isinstance(run_id, int)
            and run.get("name") == "repository quality gates"
            and run.get("event") == "pull_request"
            and run.get("head_sha") == head_sha
            and run.get("status") == "completed"
            and run.get("conclusion") == "success"
        ):
            identifiers.append(run_id)
    return identifiers


def commit_tree_sha(value: Json) -> str | None:
    if not isinstance(value, Mapping):
        return None
    tree = value.get("tree")
    return sha(tree.get("sha")) if isinstance(tree, Mapping) else None


def api_fetcher(repository: str, token: str, api_url: str) -> Fetch:
    root = api_url.rstrip("/") + "/repos/" + repository

    def fetch(path: str) -> Json:
        request = urllib.request.Request(
            root + path,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {token}",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        with urllib.request.urlopen(request, timeout=15) as response:
            return json.loads(response.read().decode("utf-8"))

    return fetch


def reuse_is_proven(fetch: Fetch, pushed_sha: str) -> bool:
    try:
        pulls = fetch(f"/commits/{pushed_sha}/pulls?per_page=100")
        pull_request = select_merged_pull_request(pulls, pushed_sha)
        if pull_request is None:
            return False
        pushed_tree = commit_tree_sha(fetch(f"/git/commits/{pushed_sha}"))
        head_tree = commit_tree_sha(fetch(f"/git/commits/{pull_request.head_sha}"))
        if pushed_tree is None or pushed_tree != head_tree:
            return False
        encoded_sha = urllib.parse.quote(pull_request.head_sha, safe="")
        runs = fetch(
            "/actions/workflows/repository-quality-gates.yml/runs?"
            "event=pull_request&status=completed&per_page=100"
            f"&head_sha={encoded_sha}"
        )
        for run_id in successful_run_ids(runs, pull_request.head_sha):
            jobs = fetch(f"/actions/runs/{run_id}/jobs?per_page=100")
            if exhaustive_clone_local_succeeded(jobs):
                return True
    except (OSError, ValueError, urllib.error.URLError, urllib.error.HTTPError):
        return False
    return False


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event-name", required=True)
    parser.add_argument("--ref-name", required=True)
    parser.add_argument("--pushed-sha", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--api-url", default="https://api.github.com")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    token = os.environ.get("GITHUB_TOKEN", "")
    if (
        arguments.event_name != "push"
        or arguments.ref_name != "main"
        or sha(arguments.pushed_sha) is None
        or not token
    ):
        print("merged_pr_gate_reuse=full reason=event_or_credentials_ineligible")
        return FULL_GATE_EXIT
    proven = reuse_is_proven(
        api_fetcher(arguments.repository, token, arguments.api_url),
        arguments.pushed_sha,
    )
    if proven:
        print("merged_pr_gate_reuse=accepted")
        return 0
    print("merged_pr_gate_reuse=full reason=proof_unavailable")
    return FULL_GATE_EXIT


if __name__ == "__main__":
    raise SystemExit(main())
