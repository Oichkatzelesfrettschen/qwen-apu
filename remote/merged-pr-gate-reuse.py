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


@dataclass(frozen=True)
class GateSource:
    run_id: int
    run_attempt: int


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


def successful_run_sources(value: Json, head_sha: str) -> list[GateSource]:
    if not isinstance(value, Mapping):
        return []
    runs = value.get("workflow_runs")
    if not isinstance(runs, list) or value.get("total_count") != len(runs):
        return []
    sources: list[GateSource] = []
    for run in runs:
        if not isinstance(run, Mapping):
            return []
        run_id = run.get("id")
        run_attempt = run.get("run_attempt")
        if (
            isinstance(run_id, int)
            and run_id > 0
            and isinstance(run_attempt, int)
            and run_attempt > 0
            and run.get("name") == "repository quality gates"
            and run.get("event") == "pull_request"
            and run.get("head_sha") == head_sha
            and run.get("status") == "completed"
            and run.get("conclusion") == "success"
        ):
            sources.append(GateSource(run_id=run_id, run_attempt=run_attempt))
    return sources


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


def reusable_gate_source(fetch: Fetch, pushed_sha: str) -> GateSource | None:
    try:
        pulls = fetch(f"/commits/{pushed_sha}/pulls?per_page=100")
        pull_request = select_merged_pull_request(pulls, pushed_sha)
        if pull_request is None:
            return None
        pushed_tree = commit_tree_sha(fetch(f"/git/commits/{pushed_sha}"))
        head_tree = commit_tree_sha(fetch(f"/git/commits/{pull_request.head_sha}"))
        if pushed_tree is None or pushed_tree != head_tree:
            return None
        encoded_sha = urllib.parse.quote(pull_request.head_sha, safe="")
        runs = fetch(
            "/actions/workflows/repository-quality-gates.yml/runs?"
            "event=pull_request&status=completed&per_page=100"
            f"&head_sha={encoded_sha}"
        )
        for source in successful_run_sources(runs, pull_request.head_sha):
            jobs = fetch(f"/actions/runs/{source.run_id}/jobs?per_page=100")
            if exhaustive_clone_local_succeeded(jobs):
                return source
    except (OSError, ValueError, urllib.error.URLError, urllib.error.HTTPError):
        return None
    return None


def reuse_is_proven(fetch: Fetch, pushed_sha: str) -> bool:
    return reusable_gate_source(fetch, pushed_sha) is not None


def write_source(path: str, source: GateSource) -> None:
    destination = os.path.abspath(path)
    temporary = f"{destination}.pending"
    with open(temporary, "x", encoding="utf-8") as output:
        output.write("field\tvalue\n")
        output.write(f"source_run_id\t{source.run_id}\n")
        output.write(f"source_run_attempt\t{source.run_attempt}\n")
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, destination)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event-name", required=True)
    parser.add_argument("--ref-name", required=True)
    parser.add_argument("--pushed-sha", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--api-url", default="https://api.github.com")
    parser.add_argument("--source-result", required=True)
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
    source = reusable_gate_source(
        api_fetcher(arguments.repository, token, arguments.api_url),
        arguments.pushed_sha,
    )
    if source is not None:
        try:
            write_source(arguments.source_result, source)
        except OSError as error:
            print(
                f"merged_pr_gate_reuse=full reason=source_result_error detail={error}"
            )
            return FULL_GATE_EXIT
        print(
            "merged_pr_gate_reuse=accepted "
            f"source_run_id={source.run_id} "
            f"source_run_attempt={source.run_attempt}"
        )
        return 0
    print("merged_pr_gate_reuse=full reason=proof_unavailable")
    return FULL_GATE_EXIT


if __name__ == "__main__":
    raise SystemExit(main())
