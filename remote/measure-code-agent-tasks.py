#!/usr/bin/env python3
"""Measure one model against the code-agent task fixtures over the Messages API.

The appliance serves POST /v1/messages and POST /v1/messages/count_tokens
(tools/server/server.cpp registers both, and server-models.cpp resolves the
router child from the body's top-level "model"), so a plain standard-library
client reaches the same route a coding agent would use while executing nothing
on the appliance. Each task sends one non-streamed turn, extracts the single
fenced block the prompt demands, writes it as the task's target file in a
throwaway workspace, and runs that workspace's unittest module. The record
carries wall time beside the exact token counts the usage object reports,
because a wall time on this machine competes with whatever else holds the
device while an input_tokens count does not.

--self-check replaces the model with each task's committed reference answer and
runs the same grading path, which proves a fixture reachable without spending
appliance time.

grade() runs the generated source under a closed sandbox rather than in this
process's own environment: `unshare --user --net` puts the graded subprocess in
a fresh network namespace with only a down loopback interface, the environment
it execs into carries the five names remote/census-arm-lib.sh's env -i
allowlist grants an arm (PATH, HOME, TMPDIR, LC_ALL,
PYTHONDONTWRITEBYTECODE), and CPU time, address space, and open file count are
bounded through resource.setrlimit ahead of the exec. A model response reached
over a compromised endpoint, or one that simply emits a wrong answer, gets a
sandbox rather than this script's own credentials, filesystem reach outside its
scratch workspace, and network path.
"""

import argparse
import json
import os
import pathlib
import re
import resource
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

FENCE = re.compile(r"```(?:python|py)?[ \t]*\r?\n(.*?)```", re.DOTALL)
DEFAULT_TASKS = ("task-01-write", "task-02-fix", "task-03-refactor")

# Bounds applied to the graded subprocess through resource.setrlimit ahead of
# its exec, so they bind the sandboxed unittest run and everything unshare
# execs in its place rather than this script. RLIMIT_NPROC is left out: it
# caps the invoking user's whole process count on Linux rather than one
# process tree, so setting it here would starve the caller's other work
# instead of the graded subprocess alone.
SANDBOX_CPU_SECONDS = 60
SANDBOX_ADDRESS_SPACE_BYTES = 1 << 30
SANDBOX_FILE_SIZE_BYTES = 64 << 20
SANDBOX_OPEN_FILES = 256
SANDBOX_TIMEOUT_SECONDS = 120


def _apply_sandbox_resource_limits():
    """Runs in the forked child ahead of exec (subprocess.run's preexec_fn),
    so the limits bind the process unshare replaces itself with rather than
    this script."""
    resource.setrlimit(
        resource.RLIMIT_CPU, (SANDBOX_CPU_SECONDS, SANDBOX_CPU_SECONDS)
    )
    resource.setrlimit(
        resource.RLIMIT_AS,
        (SANDBOX_ADDRESS_SPACE_BYTES, SANDBOX_ADDRESS_SPACE_BYTES),
    )
    resource.setrlimit(
        resource.RLIMIT_FSIZE,
        (SANDBOX_FILE_SIZE_BYTES, SANDBOX_FILE_SIZE_BYTES),
    )
    resource.setrlimit(
        resource.RLIMIT_NOFILE, (SANDBOX_OPEN_FILES, SANDBOX_OPEN_FILES)
    )


def require_sandbox_tool():
    """Refuses to run before any task is graded rather than mislabeling the
    first task transport_failed when unshare is absent or unprivileged user
    namespaces are disabled (CLAUDE.md's read-only tool set and its rule that
    a tool-enabled server stays off the LAN assume the caller's own runtime
    holds this boundary; this script is that runtime for the graded reply)."""
    if shutil.which("unshare") is None:
        sys.stderr.write(
            "unshare is required to sandbox graded code and is not on PATH\n"
        )
        return False
    probe = subprocess.run(
        ["unshare", "--user", "--map-root-user", "--net", "--", "true"],
        capture_output=True,
        text=True,
        check=False,
    )
    if probe.returncode != 0:
        sys.stderr.write(
            "unshare --user --net cannot start a sandboxed process here "
            "(unprivileged user namespaces may be disabled): %s\n"
            % probe.stderr.strip()
        )
        return False
    return True


def read_key(path):
    key_path = pathlib.Path(path)
    key = key_path.read_text(encoding="utf-8").strip()
    if not key:
        raise ValueError("key file %s is empty" % path)
    return key


def post_json(origin, route, key, payload, timeout):
    request = urllib.request.Request(
        origin.rstrip("/") + route,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "content-type": "application/json",
            "authorization": "Bearer " + key,
            "anthropic-version": "2023-06-01",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def compose_prompt(task_directory, meta):
    parts = [(task_directory / "prompt.md").read_text(encoding="utf-8").rstrip()]
    for name in meta.get("context_files", []):
        source = task_directory / "workspace" / name
        if not source.exists():
            source = task_directory / name
        parts.append(
            "\n`%s`:\n\n```python\n%s```"
            % (name, source.read_text(encoding="utf-8"))
        )
    return "\n".join(parts) + "\n"


def extract_block(text):
    matches = FENCE.findall(text)
    if len(matches) != 1:
        return None
    return matches[0]


def grade(task_directory, meta, source_text, python_executable):
    """Write source_text as the target file and run the task's own tests
    inside the closed sandbox module-level require_sandbox_tool() already
    proved reachable."""
    workspace = pathlib.Path(tempfile.mkdtemp(prefix="code-agent-task-"))
    try:
        # task-01-write ships no workspace/ directory: the prompt asks for a
        # module written from a specification alone, so there is no seed
        # source to copy and an unconditional copytree raised
        # FileNotFoundError here, which main()'s transport_failed handler
        # then mislabeled as an endpoint failure rather than a graded run.
        workspace_source = task_directory / "workspace"
        if workspace_source.is_dir():
            shutil.copytree(workspace_source, workspace, dirs_exist_ok=True)
        shutil.copytree(task_directory / "tests", workspace, dirs_exist_ok=True)
        (workspace / meta["target_file"]).write_text(source_text, encoding="utf-8")
        sandbox_environment = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": str(workspace),
            "TMPDIR": str(workspace),
            "LC_ALL": "C",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        try:
            completed = subprocess.run(
                [
                    "unshare",
                    "--user",
                    "--map-root-user",
                    "--net",
                    "--",
                    python_executable,
                    "-m",
                    "unittest",
                    "discover",
                    "-v",
                ],
                cwd=str(workspace),
                env=sandbox_environment,
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                timeout=SANDBOX_TIMEOUT_SECONDS,
                check=False,
                preexec_fn=_apply_sandbox_resource_limits,
            )
        except subprocess.TimeoutExpired:
            # A generated test that hangs on import or on a blocking call
            # left this exception uncaught, which aborted main()'s whole task
            # loop rather than recording the one task that hung; every task
            # after it went ungraded.
            return {
                "tests_passed": False,
                "test_returncode": None,
                "test_output_tail": [
                    "graded subprocess exceeded its %ds sandbox deadline"
                    % SANDBOX_TIMEOUT_SECONDS
                ],
                "test_timed_out": True,
            }
        return {
            "tests_passed": completed.returncode == 0,
            "test_returncode": completed.returncode,
            "test_output_tail": completed.stderr.strip().splitlines()[-12:],
        }
    finally:
        shutil.rmtree(workspace, ignore_errors=True)


def run_task(arguments, task_directory, key):
    meta = json.loads((task_directory / "meta.json").read_text(encoding="utf-8"))
    prompt = compose_prompt(task_directory, meta)
    baseline_lines = 0
    target_in_workspace = task_directory / "workspace" / meta["target_file"]
    if target_in_workspace.exists():
        baseline_lines = len(
            target_in_workspace.read_text(encoding="utf-8").splitlines()
        )

    record = {
        "task_id": meta["task_id"],
        "kind": meta["kind"],
        "target_file": meta["target_file"],
        "model": arguments.model,
        "max_tokens": arguments.max_tokens,
        "thinking": arguments.thinking,
        "prompt_characters": len(prompt),
        "baseline_target_lines": baseline_lines,
    }

    if arguments.self_check:
        reference = (task_directory / meta["reference_file"]).read_text(
            encoding="utf-8"
        )
        record["outcome"] = "self_check"
        record["reply_lines"] = len(reference.splitlines())
        record.update(grade(task_directory, meta, reference, arguments.python))
        if record.get("test_timed_out"):
            record["outcome"] = "timed_out"
        return record

    body = {
        "model": arguments.model,
        "max_tokens": arguments.max_tokens,
        "temperature": 0,
        "messages": [{"role": "user", "content": prompt}],
    }
    if arguments.thinking != "default":
        body["chat_template_kwargs"] = {
            "enable_thinking": arguments.thinking == "on"
        }

    # The count route renders whatever template settings its own body states.
    # Omitting chat_template_kwargs here left it rendering the template's
    # default thinking marker while the generation body above rendered the
    # arguments.thinking setting, so count_tokens_input_tokens counted a
    # different prompt than the one that was sent.
    count_body = {"model": arguments.model, "messages": body["messages"]}
    if "chat_template_kwargs" in body:
        count_body["chat_template_kwargs"] = body["chat_template_kwargs"]
    counted = post_json(
        arguments.origin,
        "/v1/messages/count_tokens",
        key,
        count_body,
        arguments.timeout,
    )
    counted_tokens = counted.get("input_tokens")
    if not isinstance(counted_tokens, int) or isinstance(counted_tokens, bool) or counted_tokens <= 0:
        raise ValueError(
            "count_tokens returned a non-positive input_tokens: %r" % (counted_tokens,)
        )
    record["count_tokens_input_tokens"] = counted_tokens

    started = time.monotonic()
    reply = post_json(
        arguments.origin, "/v1/messages", key, body, arguments.timeout
    )
    record["wall_seconds"] = round(time.monotonic() - started, 3)

    usage = reply.get("usage", {})
    record["reply_model"] = reply.get("model")
    record["stop_reason"] = reply.get("stop_reason")
    record["input_tokens"] = usage.get("input_tokens")
    record["output_tokens"] = usage.get("output_tokens")
    record["cache_read_input_tokens"] = usage.get("cache_read_input_tokens")

    # A router that answers with the wrong child is a transport defect the
    # usage counters cannot reveal: the reply still parses, still carries a
    # source block, and its tests can still pass, which would attribute
    # another checkpoint's behavior to arguments.model.
    if record["reply_model"] != arguments.model:
        record["outcome"] = "model_mismatch"
        record["tests_passed"] = False
        return record

    blocks = reply.get("content", [])
    record["content_block_types"] = [block.get("type") for block in blocks]
    record["reasoning_emitted"] = "thinking" in record["content_block_types"]
    text = "".join(
        block.get("text", "") for block in blocks if block.get("type") == "text"
    )
    record["reply_characters"] = len(text)

    if record["stop_reason"] == "max_tokens":
        # The budget cut the reply before this script can tell whether a
        # complete-looking fenced block is the model's whole answer or the
        # regex matching a fence that happened to close before the cut;
        # grading either case as "extracted" would credit a truncated turn.
        record["outcome"] = "truncated"
        record["tests_passed"] = False
        record["reply_head"] = text[:400]
        return record

    source_text = extract_block(text)
    if source_text is None:
        record["outcome"] = "extraction_failed"
        record["tests_passed"] = False
        record["reply_head"] = text[:400]
        return record

    record["outcome"] = "extracted"
    record["reply_lines"] = len(source_text.splitlines())
    # A passing test says the produced file behaves; it says nothing about what
    # the model wrote, and the refactor arm's whole question is whether the
    # duplication went away. The source is retained beside the record so that
    # reading is available after the fact rather than only through a rerun.
    produced = arguments.output_directory_path / (record["task_id"] + ".produced.py")
    produced.write_text(source_text, encoding="utf-8")
    record["produced_file"] = produced.name
    record["produced_matches_baseline"] = (
        target_in_workspace.exists()
        and target_in_workspace.read_text(encoding="utf-8") == source_text
    )
    record.update(grade(task_directory, meta, source_text, arguments.python))
    if record.get("test_timed_out"):
        record["outcome"] = "timed_out"
    if not record["tests_passed"]:
        record["reply_head"] = text[:400]
    return record


def parse_arguments(argv):
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--origin", default=os.environ.get("QWEN_CODE_AGENT_ORIGIN"))
    parser.add_argument("--key-file", default=os.environ.get("QWEN_CODE_AGENT_KEY_FILE"))
    parser.add_argument("--model", default="qwen38-4b-distill")
    parser.add_argument("--output-directory", required=True)
    parser.add_argument("--max-tokens", type=int, default=2048)
    parser.add_argument(
        "--thinking", choices=("on", "off", "default"), default="off"
    )
    # A 2048-token reply at the 4B distill's roughly 3 tok/s decode runs past
    # eleven minutes, so the client deadline outlasts a reply that fills the
    # whole budget rather than cutting one short and recording a transport
    # failure where the machine was merely slow.
    parser.add_argument("--timeout", type=float, default=1800.0)
    parser.add_argument("--python", default=sys.executable)
    parser.add_argument("--task", action="append", default=[])
    parser.add_argument("--self-check", action="store_true")
    arguments = parser.parse_args(argv)
    # grade() execs this path with cwd already changed to the throwaway
    # sandbox workspace; a relative path carrying a slash (".venv/bin/python")
    # would then resolve against that workspace instead of the directory this
    # script was invoked from, and unshare would report the interpreter
    # missing.
    arguments.python = str(pathlib.Path(arguments.python).resolve())
    return arguments


def main(argv):
    arguments = parse_arguments(argv)
    if not arguments.self_check and not (arguments.origin and arguments.key_file):
        sys.stderr.write(
            "usage: measure-code-agent-tasks.py --origin URL --key-file PATH "
            "--output-directory DIR [--model ID] [--self-check]\n"
        )
        return 2

    if not require_sandbox_tool():
        return 2

    fixtures = pathlib.Path(__file__).resolve().parent / "test-fixtures" / "code-agent-tasks"
    task_ids = arguments.task or list(DEFAULT_TASKS)
    key = "" if arguments.self_check else read_key(arguments.key_file)

    output_directory = pathlib.Path(arguments.output_directory)
    output_directory.mkdir(parents=True, exist_ok=True)
    arguments.output_directory_path = output_directory

    records = []
    for task_id in task_ids:
        task_directory = fixtures / task_id
        if not task_directory.is_dir():
            sys.stderr.write("unknown task %s\n" % task_id)
            return 2
        try:
            record = run_task(arguments, task_directory, key)
        except (urllib.error.URLError, OSError, ValueError) as error:
            record = {
                "task_id": task_id,
                "outcome": "transport_failed",
                "tests_passed": False,
                "error": str(error),
            }
        records.append(record)
        (output_directory / (task_id + ".json")).write_text(
            json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(
            "%s outcome=%s tests_passed=%s wall_seconds=%s input_tokens=%s "
            "output_tokens=%s"
            % (
                record["task_id"],
                record.get("outcome"),
                record.get("tests_passed"),
                record.get("wall_seconds", "-"),
                record.get("input_tokens", "-"),
                record.get("output_tokens", "-"),
            )
        )

    columns = (
        "task_id",
        "kind",
        "model",
        "outcome",
        "tests_passed",
        "wall_seconds",
        "input_tokens",
        "output_tokens",
        "cache_read_input_tokens",
        "count_tokens_input_tokens",
        "reasoning_emitted",
        "stop_reason",
        "baseline_target_lines",
        "reply_lines",
        "produced_matches_baseline",
    )
    summary = output_directory / "summary.tsv"
    with summary.open("w", encoding="utf-8") as handle:
        handle.write("\t".join(columns) + "\n")
        for record in records:
            handle.write(
                "\t".join(str(record.get(column, "-")) for column in columns) + "\n"
            )

    failures = [record for record in records if not record.get("tests_passed")]
    print("tasks=%d passed=%d" % (len(records), len(records) - len(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
