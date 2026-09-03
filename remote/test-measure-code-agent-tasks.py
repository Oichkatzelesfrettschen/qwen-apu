#!/usr/bin/env python3
"""Exercise measure-code-agent-tasks.py offline: extraction, the sandbox, and
the transport-level record checks around a served reply.

Every case here runs without an appliance. grade() and require_sandbox_tool()
still fork the real `unshare` binary, so this test proves the sandbox mechanism
itself -- network namespace isolation and the timeout catch -- rather than a
mock standing in for it.
"""

import importlib.util
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
SCRIPT_PATH = os.path.join(SCRIPT_DIRECTORY, "measure-code-agent-tasks.py")
FIXTURES = Path(SCRIPT_DIRECTORY) / "test-fixtures" / "code-agent-tasks"


def load_module():
    """Import measure-code-agent-tasks.py under a name a dash keeps out of
    `import`."""
    specification = importlib.util.spec_from_file_location(
        "measure_code_agent_tasks", SCRIPT_PATH
    )
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


module = load_module()


def write_task(directory, meta, prompt_text="Write it.\n"):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "meta.json").write_text(
        __import__("json").dumps(meta), encoding="utf-8"
    )
    (directory / "prompt.md").write_text(prompt_text, encoding="utf-8")


class ExtractBlockTests(unittest.TestCase):
    def test_single_fence_extracted(self):
        text = "Here you go:\n```python\nx = 1\n```\nDone."
        self.assertEqual(module.extract_block(text), "x = 1\n")

    def test_zero_or_multiple_fences_refused(self):
        self.assertIsNone(module.extract_block("no fences here"))
        self.assertIsNone(
            module.extract_block("```python\na = 1\n```\n```python\nb = 2\n```")
        )


class GradeSandboxTests(unittest.TestCase):
    def test_task_without_seed_workspace_grades_without_raising(self):
        # task-01-write ships no workspace/ directory (only task-02-fix and
        # task-03-refactor do); grade() used to raise FileNotFoundError here.
        task_directory = FIXTURES / "task-01-write"
        self.assertFalse((task_directory / "workspace").is_dir())
        meta = __import__("json").loads(
            (task_directory / "meta.json").read_text(encoding="utf-8")
        )
        reference = (task_directory / meta["reference_file"]).read_text(
            encoding="utf-8"
        )
        result = module.grade(task_directory, meta, reference, sys.executable)
        self.assertTrue(result["tests_passed"], result.get("test_output_tail"))

    def test_generated_code_reaches_no_network_route(self):
        # A fresh, empty network namespace has no default route to any
        # external address, so a connect() to a real routable IP fails with
        # ENETUNREACH regardless of whether the host itself has internet
        # access; the failure comes from the child's own empty routing
        # table, not from the destination being unreachable in general.
        with tempfile.TemporaryDirectory() as work:
            task_directory = Path(work) / "net-probe"
            write_task(
                task_directory,
                {
                    "task_id": "net-probe",
                    "kind": "write",
                    "target_file": "target.py",
                    "context_files": [],
                    "reference_file": "reference/target.py",
                },
            )
            (task_directory / "tests").mkdir()
            (task_directory / "tests" / "test_target.py").write_text(
                "import unittest\nimport target\n\n"
                "class NetworkNamespaceTest(unittest.TestCase):\n"
                "    def test_no_route_to_a_public_address(self):\n"
                "        self.assertEqual(target.CONNECT_ERROR, 'ENETUNREACH')\n",
                encoding="utf-8",
            )
            source = (
                "import errno\n"
                "import socket\n\n"
                "CONNECT_ERROR = None\n"
                "try:\n"
                "    socket.create_connection(('1.1.1.1', 80), timeout=3)\n"
                "    CONNECT_ERROR = 'CONNECTED'\n"
                "except OSError as error:\n"
                "    CONNECT_ERROR = (\n"
                "        'ENETUNREACH' if error.errno == errno.ENETUNREACH\n"
                "        else 'OTHER:%s' % error.errno\n"
                "    )\n"
            )
            meta = __import__("json").loads(
                (task_directory / "meta.json").read_text(encoding="utf-8")
            )
            result = module.grade(task_directory, meta, source, sys.executable)
            self.assertTrue(result["tests_passed"], result.get("test_output_tail"))

    def test_hung_test_is_recorded_rather_than_raised(self):
        original_timeout = module.SANDBOX_TIMEOUT_SECONDS
        module.SANDBOX_TIMEOUT_SECONDS = 2
        try:
            with tempfile.TemporaryDirectory() as work:
                task_directory = Path(work) / "hang-probe"
                write_task(
                    task_directory,
                    {
                        "task_id": "hang-probe",
                        "kind": "write",
                        "target_file": "target.py",
                        "context_files": [],
                        "reference_file": "reference/target.py",
                    },
                )
                (task_directory / "tests").mkdir()
                (task_directory / "tests" / "test_target.py").write_text(
                    "import unittest\nimport target\n\n"
                    "class HangTest(unittest.TestCase):\n"
                    "    def test_imports(self):\n"
                    "        self.assertTrue(target.LOADED)\n",
                    encoding="utf-8",
                )
                source = "import time\ntime.sleep(30)\nLOADED = True\n"
                meta = __import__("json").loads(
                    (task_directory / "meta.json").read_text(encoding="utf-8")
                )
                started = time.monotonic()
                result = module.grade(task_directory, meta, source, sys.executable)
                elapsed = time.monotonic() - started
        finally:
            module.SANDBOX_TIMEOUT_SECONDS = original_timeout
        self.assertFalse(result["tests_passed"])
        self.assertTrue(result.get("test_timed_out"))
        self.assertLess(elapsed, 15.0, "grade() waited past its own deadline")


class RequireSandboxToolTests(unittest.TestCase):
    def test_probe_succeeds_on_a_host_running_this_suite(self):
        # The gate that runs this test already requires unshare (see
        # required_command in remote/repository-quality-gates.sh); a host
        # that cannot start a sandboxed process should fail the probe rather
        # than this assertion.
        self.assertTrue(module.require_sandbox_tool())


class RunTaskTransportTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.task_directory = Path(self.temporary_directory.name) / "task"
        write_task(
            self.task_directory,
            {
                "task_id": "transport-probe",
                "kind": "write",
                "target_file": "target.py",
                "context_files": [],
                "reference_file": "reference/target.py",
            },
        )
        (self.task_directory / "tests").mkdir(parents=True, exist_ok=True)
        (self.task_directory / "tests" / "test_target.py").write_text(
            "import unittest\nimport target\n\n"
            "class PlaceholderTest(unittest.TestCase):\n"
            "    def test_imports(self):\n"
            "        pass\n",
            encoding="utf-8",
        )
        self.arguments = module.parse_arguments(
            [
                "--origin",
                "http://127.0.0.1:0",
                "--key-file",
                "/dev/null",
                "--output-directory",
                self.temporary_directory.name,
                "--model",
                "requested-model",
            ]
        )
        self.arguments.output_directory_path = Path(self.temporary_directory.name)

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_reply_from_a_different_model_is_rejected(self):
        calls = []

        def fake_post_json(origin, route, key, payload, timeout):
            calls.append(route)
            if route == "/v1/messages/count_tokens":
                return {"input_tokens": 12}
            return {
                "model": "some-other-model",
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 12, "output_tokens": 4},
                "content": [{"type": "text", "text": "```python\nx = 1\n```"}],
            }

        original = module.post_json
        module.post_json = fake_post_json
        try:
            record = module.run_task(self.arguments, self.task_directory, "key")
        finally:
            module.post_json = original
        self.assertEqual(record["outcome"], "model_mismatch")
        self.assertFalse(record["tests_passed"])
        self.assertEqual(record["reply_model"], "some-other-model")

    def test_count_tokens_receives_the_generation_template_kwargs(self):
        seen_count_payloads = []

        def fake_post_json(origin, route, key, payload, timeout):
            if route == "/v1/messages/count_tokens":
                seen_count_payloads.append(payload)
                return {"input_tokens": 12}
            return {
                "model": self.arguments.model,
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 12, "output_tokens": 4},
                "content": [{"type": "text", "text": "```python\nx = 1\n```"}],
            }

        original = module.post_json
        module.post_json = fake_post_json
        try:
            module.run_task(self.arguments, self.task_directory, "key")
        finally:
            module.post_json = original
        self.assertEqual(len(seen_count_payloads), 1)
        # arguments.thinking defaults to "off", which sets
        # chat_template_kwargs on the generation body; the count body must
        # carry the same setting or it tokenizes a different template render.
        self.assertEqual(
            seen_count_payloads[0].get("chat_template_kwargs"),
            {"enable_thinking": False},
        )

    def test_count_tokens_non_positive_input_tokens_is_refused(self):
        def fake_post_json(origin, route, key, payload, timeout):
            if route == "/v1/messages/count_tokens":
                return {"input_tokens": 0}
            self.fail("the messages route must not run past a bad count")

        original = module.post_json
        module.post_json = fake_post_json
        try:
            with self.assertRaises(ValueError):
                module.run_task(self.arguments, self.task_directory, "key")
        finally:
            module.post_json = original

    def test_max_tokens_stop_is_truncated_even_with_a_complete_fence(self):
        def fake_post_json(origin, route, key, payload, timeout):
            if route == "/v1/messages/count_tokens":
                return {"input_tokens": 12}
            return {
                "model": self.arguments.model,
                "stop_reason": "max_tokens",
                "usage": {"input_tokens": 12, "output_tokens": 400},
                "content": [
                    {
                        "type": "text",
                        "text": "```python\nx = 1\n```\nand here is why that works:",
                    }
                ],
            }

        original = module.post_json
        module.post_json = fake_post_json
        try:
            record = module.run_task(self.arguments, self.task_directory, "key")
        finally:
            module.post_json = original
        self.assertEqual(record["outcome"], "truncated")
        self.assertFalse(record["tests_passed"])


if __name__ == "__main__":
    unittest.main()
