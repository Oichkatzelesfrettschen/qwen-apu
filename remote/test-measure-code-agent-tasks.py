#!/usr/bin/env python3
"""Exercise measure-code-agent-tasks.py offline: extraction, the sandbox, and
the transport-level record checks around a served reply.

Every case here runs without an appliance. grade() and require_sandbox_tool()
still fork the real `bwrap` binary, so this test proves the sandbox mechanism
itself -- filesystem and network namespace isolation, and the process-group
kill on timeout -- rather than a mock standing in for it.
"""

import importlib.util
import os
import subprocess
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


class VenvPythonPathTests(unittest.TestCase):
    """--python's venv override is a symlink by convention, and CPython's own
    venv detection keys off the path it was invoked through rather than the
    symlink's target -- resolving it away (Path.resolve()) both defeats
    _sandbox_python_extra_binds's pyvenv.cfg lookup and hands grade() a bare
    system interpreter that never activates the venv's site-packages."""

    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.venv_root = Path(self.temporary_directory.name) / "fake-venv"
        (self.venv_root / "bin").mkdir(parents=True)
        (self.venv_root / "pyvenv.cfg").write_text("home = /usr\n", encoding="utf-8")
        self.venv_python = self.venv_root / "bin" / "python"
        self.venv_python.symlink_to(sys.executable)

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_extra_binds_finds_the_venv_root_from_the_symlink_path(self):
        binds = module._sandbox_python_extra_binds(str(self.venv_python))
        self.assertEqual(binds, ["--ro-bind", str(self.venv_root), str(self.venv_root)])

    def test_extra_binds_is_empty_once_the_symlink_is_resolved_away(self):
        # This is the defect itself, pinned as a control: resolving the
        # symlink first (what parse_arguments must not do) loses the venv.
        resolved = str(Path(self.venv_python).resolve())
        self.assertEqual(module._sandbox_python_extra_binds(resolved), [])

    def test_parse_arguments_keeps_the_symlink_rather_than_its_target(self):
        arguments = module.parse_arguments(
            [
                "--self-check",
                "--output-directory",
                self.temporary_directory.name,
                "--python",
                str(self.venv_python),
            ]
        )
        self.assertEqual(arguments.python, str(self.venv_python))
        self.assertTrue(arguments.python.startswith(str(self.venv_root)))


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

    def test_hung_test_and_its_forked_child_are_both_reaped(self):
        # The target module forks a grandchild that outlives the direct
        # bwrap/python process and keeps the stdout/stderr pipes grade()
        # reads open; subprocess.run's own timeout= would kill bwrap alone
        # and leave that grandchild running (and the pipes unclosed), which
        # would force the post-kill communicate() below to wait out its own
        # 10-second timeout. A tight bound on total elapsed time is what
        # distinguishes "the whole process group died" from "one process in
        # it did".
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
                source = (
                    "import os\nimport time\n\n"
                    "pid = os.fork()\n"
                    "if pid == 0:\n"
                    "    time.sleep(60)\n"
                    "    os._exit(0)\n"
                    "time.sleep(60)\n"
                    "LOADED = True\n"
                )
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
        # SANDBOX_TIMEOUT_SECONDS is 2 here; a full reap finishes within a
        # few seconds of that. A grandchild left alive would push this past
        # the second communicate()'s own 10-second timeout.
        self.assertLess(
            elapsed, 8.0, "grade() waited on a descendant its kill did not reach"
        )


class GradeFilesystemIsolationTests(unittest.TestCase):
    def test_generated_code_cannot_list_the_real_host_home(self):
        # bwrap's mount namespace carries only /usr, /etc, /proc, /dev, a
        # fresh /tmp, and the workspace bind -- the real $HOME this test
        # process runs under is absent from it entirely, so a listdir raises
        # rather than returning the caller's own files under some other
        # permission outcome.
        real_home = os.path.expanduser("~")
        with tempfile.TemporaryDirectory() as work:
            task_directory = Path(work) / "home-probe"
            write_task(
                task_directory,
                {
                    "task_id": "home-probe",
                    "kind": "write",
                    "target_file": "target.py",
                    "context_files": [],
                    "reference_file": "reference/target.py",
                },
            )
            (task_directory / "tests").mkdir()
            (task_directory / "tests" / "test_target.py").write_text(
                "import unittest\nimport target\n\n"
                "class HomeVisibilityTest(unittest.TestCase):\n"
                "    def test_real_home_is_absent(self):\n"
                "        self.assertEqual(target.REAL_HOME_STATE, 'ABSENT')\n",
                encoding="utf-8",
            )
            source = (
                "import os\n\n"
                "REAL_HOME_STATE = 'PRESENT'\n"
                "try:\n"
                "    os.listdir(%r)\n"
                "except OSError:\n"
                "    REAL_HOME_STATE = 'ABSENT'\n" % real_home
            )
            meta = __import__("json").loads(
                (task_directory / "meta.json").read_text(encoding="utf-8")
            )
            result = module.grade(task_directory, meta, source, sys.executable)
            self.assertTrue(result["tests_passed"], result.get("test_output_tail"))


class TemporaryVenvSandboxTests(unittest.TestCase):
    def test_venv_under_tmp_remains_visible_after_private_tmp_mount(self):
        with tempfile.TemporaryDirectory(prefix="qwen-grade-venv-") as directory:
            venv = Path(directory) / "venv"
            subprocess.run(
                [sys.executable, "-m", "venv", "--without-pip", str(venv)], check=True
            )
            workspace = Path(directory) / "workspace"
            workspace.mkdir()
            python = str(venv / "bin/python")
            argv = module._sandbox_bwrap_argv(
                workspace, {"PATH": "/usr/bin:/bin"}, python
            )
            result = subprocess.run(
                argv + [python, "-c", "import sys; print(sys.prefix)"],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), str(venv))


class RequireSandboxToolTests(unittest.TestCase):
    def test_probe_succeeds_on_a_host_running_this_suite(self):
        # The gate that runs this test already requires bwrap (see
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
