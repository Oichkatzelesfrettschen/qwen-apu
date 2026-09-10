#!/usr/bin/env python3
"""Exercise browser interpreter selection and fail-closed preflight."""

from __future__ import annotations

import importlib.util
import json
import os
import pathlib
import signal
import subprocess
import sys
import tempfile
import time
import types
import venv
from collections.abc import Callable
from typing import Any, cast

SCRIPT_DIRECTORY = pathlib.Path(__file__).resolve().parent
RUNNER = SCRIPT_DIRECTORY / "run-browser-driver.sh"


def load_runner_module() -> types.ModuleType:
    """Load the runner for focused semantic fixtures."""
    specification = importlib.util.spec_from_file_location(
        "browser_driver_preflight_fixture",
        SCRIPT_DIRECTORY / "browser-driver-preflight.py",
    )
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def make_environment(root: pathlib.Path, dependency: bool) -> pathlib.Path:
    """Create one isolated browser environment fixture."""
    environment = root / "opt" / "browser-venv"
    venv.EnvBuilder(with_pip=False).create(environment)
    if dependency:
        result = subprocess.run(
            [
                str(environment / "bin" / "python"),
                "-c",
                "import sysconfig; print(sysconfig.get_path('purelib'))",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        site_packages = pathlib.Path(result.stdout.strip())
        package = site_packages / "marionette_driver"
        package.mkdir()
        (package / "__init__.py").write_text("", encoding="utf-8")
        (package / "marionette.py").write_text(
            "IDENTITY = 'fixture'\n", encoding="utf-8"
        )
        (package / "support.py").write_text("VALUE = 1\n", encoding="utf-8")
        metadata = site_packages / "marionette_driver-3.7.1.dist-info"
        metadata.mkdir()
        (metadata / "METADATA").write_text(
            "Metadata-Version: 2.1\nName: marionette_driver\nVersion: 3.7.1\n",
            encoding="utf-8",
        )
        (metadata / "RECORD").write_text(
            "marionette_driver/__init__.py,,\n"
            "marionette_driver/marionette.py,,\n"
            "marionette_driver/support.py,,\n"
            "marionette_driver-3.7.1.dist-info/METADATA,,\n"
            "marionette_driver-3.7.1.dist-info/RECORD,,\n",
            encoding="utf-8",
        )
    return environment / "bin" / "python"


def make_executable(path: pathlib.Path, body: str) -> None:
    """Write one fixture executable."""
    path.write_text(body, encoding="utf-8")
    path.chmod(0o755)


def run_fixture(
    runtime_root: pathlib.Path, record_name: str
) -> subprocess.CompletedProcess[str]:
    """Run the entry point with a hostile ambient Python first on PATH."""
    hostile = runtime_root / "hostile"
    hostile.mkdir(exist_ok=True)
    make_executable(
        hostile / "python3",
        "#!/bin/sh\nprintf 'ambient python selected\\n' >\"$QWEN_HOME/ambient-python-used\"\nexit 99\n",
    )
    driver = runtime_root / "fixture-driver.py"
    driver.write_text(
        "import os\nimport pathlib\n"
        "root = pathlib.Path(os.environ['QWEN_HOME'])\n"
        "for name in ('driver-started', 'firefox-started', 'profile-created', "
        "'image-authorized', 'image-generated'):\n    (root / name).write_text('1')\n",
        encoding="utf-8",
    )
    firefox = runtime_root / "firefox-fixture"
    make_executable(firefox, "#!/bin/sh\nexit 0\n")
    environment = os.environ.copy()
    environment["PATH"] = f"{hostile}:{environment['PATH']}"
    environment["QWEN_HOME"] = str(runtime_root)
    return subprocess.run(
        [
            str(RUNNER),
            "--driver",
            str(driver),
            "--firefox-bin",
            str(firefox),
            "--record-directory",
            str(runtime_root / "results" / record_name),
            "--preflight-only",
        ],
        check=False,
        capture_output=True,
        text=True,
        env=environment,
    )


def assert_execution_markers_absent(runtime_root: pathlib.Path) -> None:
    """Require every acquisition-side effect marker to remain absent."""
    names = (
        "ambient-python-used",
        "driver-started",
        "firefox-started",
        "profile-created",
        "image-authorized",
        "image-generated",
    )
    present = [name for name in names if (runtime_root / name).exists()]
    assert not present, present


def process_is_running(process_id: int) -> bool:
    """Return whether one process still executes rather than awaiting reaping."""
    stat_path = pathlib.Path("/proc") / str(process_id) / "stat"
    try:
        fields = stat_path.read_text(encoding="utf-8").split()
    except FileNotFoundError:
        return False
    return len(fields) > 2 and fields[2] != "Z"


def run_timeout_fixture(
    runtime_root: pathlib.Path,
) -> tuple[subprocess.CompletedProcess[str], int]:
    """Run a driver with one child and force the owned deadline."""
    (runtime_root / "results").mkdir(parents=True)
    make_environment(runtime_root, dependency=True)
    child = runtime_root / "fixture-child.py"
    child.write_text(
        "import os\nimport pathlib\nimport signal\nimport time\n"
        "root = pathlib.Path(os.environ['QWEN_HOME'])\n"
        "def stop(_signal, _frame):\n"
        "    (root / 'child-terminated').write_text('1')\n"
        "    raise SystemExit(0)\n"
        "signal.signal(signal.SIGTERM, stop)\n"
        "(root / 'child-ready').write_text('1')\n"
        "while True:\n    time.sleep(1)\n",
        encoding="utf-8",
    )
    driver = runtime_root / "fixture-driver.py"
    driver.write_text(
        "import os\nimport pathlib\nimport subprocess\nimport sys\nimport time\n"
        "root = pathlib.Path(os.environ['QWEN_HOME'])\n"
        "child = subprocess.Popen([sys.executable, str(root / 'fixture-child.py')])\n"
        "(root / 'child-pid').write_text(str(child.pid))\n"
        "for _attempt in range(100):\n"
        "    if (root / 'child-ready').exists():\n        break\n"
        "    time.sleep(0.01)\n"
        "else:\n    raise RuntimeError('fixture child did not start')\n"
        "(root / 'driver-started').write_text('1')\n"
        "while True:\n    time.sleep(1)\n",
        encoding="utf-8",
    )
    firefox = runtime_root / "firefox-fixture"
    make_executable(firefox, "#!/bin/sh\nexit 0\n")
    environment = os.environ.copy()
    environment["QWEN_HOME"] = str(runtime_root)
    result = subprocess.run(
        [
            str(RUNNER),
            "--driver",
            str(driver),
            "--firefox-bin",
            str(firefox),
            "--record-directory",
            str(runtime_root / "results" / "timeout-record"),
            "--driver-timeout-seconds",
            "0.5",
        ],
        check=False,
        capture_output=True,
        text=True,
        env=environment,
        timeout=15,
    )
    child_process_id = int((runtime_root / "child-pid").read_text())
    return result, child_process_id


def run_import_isolation_fixture(
    runtime_root: pathlib.Path,
) -> subprocess.CompletedProcess[str]:
    """Run a driver while PYTHONPATH offers a conflicting dependency."""
    (runtime_root / "results").mkdir(parents=True)
    make_environment(runtime_root, dependency=True)
    hostile_root = runtime_root / "hostile-python"
    hostile_package = hostile_root / "marionette_driver"
    hostile_package.mkdir(parents=True)
    (hostile_package / "__init__.py").write_text("", encoding="utf-8")
    (hostile_package / "marionette.py").write_text(
        "IDENTITY = 'hostile'\n", encoding="utf-8"
    )
    driver = runtime_root / "fixture-driver.py"
    driver.write_text(
        "import os\nimport pathlib\n"
        "from marionette_driver.marionette import IDENTITY\n"
        "pathlib.Path(os.environ['QWEN_HOME'], 'driver-dependency').write_text(IDENTITY)\n",
        encoding="utf-8",
    )
    firefox = runtime_root / "firefox-fixture"
    make_executable(firefox, "#!/bin/sh\nexit 0\n")
    environment = os.environ.copy()
    environment["PYTHONPATH"] = str(hostile_root)
    environment["QWEN_HOME"] = str(runtime_root)
    return subprocess.run(
        [
            str(RUNNER),
            "--driver",
            str(driver),
            "--firefox-bin",
            str(firefox),
            "--record-directory",
            str(runtime_root / "results" / "import-record"),
        ],
        check=False,
        capture_output=True,
        text=True,
        env=environment,
        timeout=15,
    )


def run_signal_fixture(
    runtime_root: pathlib.Path, signal_number: signal.Signals
) -> tuple[int, int]:
    """Interrupt the runner and return its status and owned child PID."""
    (runtime_root / "results").mkdir(parents=True)
    make_environment(runtime_root, dependency=True)
    child = runtime_root / "fixture-child.py"
    child.write_text(
        "import os\nimport pathlib\nimport signal\nimport time\n"
        "root = pathlib.Path(os.environ['QWEN_HOME'])\n"
        "def stop(_signal, _frame):\n"
        "    (root / 'signal-child-terminated').write_text('1')\n"
        "    raise SystemExit(0)\n"
        "signal.signal(signal.SIGTERM, stop)\n"
        "(root / 'signal-child-ready').write_text('1')\n"
        "while True:\n    time.sleep(1)\n",
        encoding="utf-8",
    )
    driver = runtime_root / "fixture-driver.py"
    driver.write_text(
        "import os\nimport pathlib\nimport subprocess\nimport sys\nimport time\n"
        "root = pathlib.Path(os.environ['QWEN_HOME'])\n"
        "child = subprocess.Popen([sys.executable, str(root / 'fixture-child.py')])\n"
        "(root / 'signal-child-pid').write_text(str(child.pid))\n"
        "while not (root / 'signal-child-ready').exists():\n    time.sleep(0.01)\n"
        "(root / 'signal-driver-ready').write_text('1')\n"
        "while True:\n    time.sleep(1)\n",
        encoding="utf-8",
    )
    firefox = runtime_root / "firefox-fixture"
    make_executable(firefox, "#!/bin/sh\nexit 0\n")
    environment = os.environ.copy()
    environment["QWEN_HOME"] = str(runtime_root)
    process = subprocess.Popen(
        [
            str(RUNNER),
            "--driver",
            str(driver),
            "--firefox-bin",
            str(firefox),
            "--record-directory",
            str(runtime_root / "results" / "signal-record"),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=environment,
    )
    deadline = time.monotonic() + 10
    while not (runtime_root / "signal-driver-ready").exists():
        if process.poll() is not None or time.monotonic() >= deadline:
            stdout, stderr = process.communicate(timeout=1)
            raise AssertionError((process.returncode, stdout, stderr))
        time.sleep(0.02)
    child_process_id = int((runtime_root / "signal-child-pid").read_text())
    process.send_signal(signal_number)
    return process.wait(timeout=15), child_process_id


def run_orphan_fixture(
    runtime_root: pathlib.Path,
) -> tuple[subprocess.CompletedProcess[str], int]:
    """Let the driver exit while its owned child remains alive."""
    (runtime_root / "results").mkdir(parents=True)
    make_environment(runtime_root, dependency=True)
    child = runtime_root / "fixture-child.py"
    child.write_text(
        "import os\nimport pathlib\nimport signal\nimport time\n"
        "root = pathlib.Path(os.environ['QWEN_HOME'])\n"
        "def stop(_signal, _frame):\n"
        "    (root / 'orphan-child-terminated').write_text('1')\n"
        "    raise SystemExit(0)\n"
        "signal.signal(signal.SIGTERM, stop)\n"
        "(root / 'orphan-child-ready').write_text('1')\n"
        "while True:\n    time.sleep(1)\n",
        encoding="utf-8",
    )
    driver = runtime_root / "fixture-driver.py"
    driver.write_text(
        "import os\nimport pathlib\nimport subprocess\nimport sys\nimport time\n"
        "root = pathlib.Path(os.environ['QWEN_HOME'])\n"
        "child = subprocess.Popen([sys.executable, str(root / 'fixture-child.py')])\n"
        "(root / 'orphan-child-pid').write_text(str(child.pid))\n"
        "while not (root / 'orphan-child-ready').exists():\n    time.sleep(0.01)\n",
        encoding="utf-8",
    )
    firefox = runtime_root / "firefox-fixture"
    make_executable(firefox, "#!/bin/sh\nexit 0\n")
    environment = os.environ.copy()
    environment["QWEN_HOME"] = str(runtime_root)
    result = subprocess.run(
        [
            str(RUNNER),
            "--driver",
            str(driver),
            "--firefox-bin",
            str(firefox),
            "--record-directory",
            str(runtime_root / "results" / "orphan-record"),
        ],
        check=False,
        capture_output=True,
        text=True,
        env=environment,
        timeout=15,
    )
    return result, int((runtime_root / "orphan-child-pid").read_text())


def run_start_failure_fixture(runtime_root: pathlib.Path) -> int:
    """Inject a Popen refusal after identities pass and retain its record."""
    (runtime_root / "results").mkdir(parents=True)
    expected_python = make_environment(runtime_root, dependency=True)
    driver = runtime_root / "fixture-driver.py"
    driver.write_text("raise SystemExit(0)\n", encoding="utf-8")
    firefox = runtime_root / "firefox-fixture"
    make_executable(firefox, "#!/bin/sh\nexit 0\n")
    module = load_runner_module()
    setattr(
        module,
        "interpreter_identity",
        lambda _path: {
            "role": "browser_environment_python",
            "sha256": "0" * 64,
            "version": "fixture",
        },
    )
    setattr(module, "module_identity", lambda _name: ("fixture", "1" * 64))

    def refuse_start(*_arguments: object, **_keywords: object) -> None:
        raise OSError("fixture process creation refusal")

    module_subprocess = cast(Any, getattr(module, "subprocess"))
    original_popen = module_subprocess.Popen
    module_subprocess.Popen = refuse_start
    previous_arguments = list(sys.argv)
    previous_runtime_root = os.environ.get("QWEN_BROWSER_RUNTIME_ROOT")
    sys.argv = [
        str(SCRIPT_DIRECTORY / "browser-driver-preflight.py"),
        "--expected-python",
        str(expected_python),
        "--driver",
        str(driver),
        "--firefox-bin",
        str(firefox),
        "--record-directory",
        str(runtime_root / "results" / "start-failure-record"),
    ]
    os.environ["QWEN_BROWSER_RUNTIME_ROOT"] = str(runtime_root)
    try:
        main_function = cast(Callable[[], int], getattr(module, "main"))
        return main_function()
    finally:
        module_subprocess.Popen = original_popen
        sys.argv = previous_arguments
        if previous_runtime_root is None:
            os.environ.pop("QWEN_BROWSER_RUNTIME_ROOT", None)
        else:
            os.environ["QWEN_BROWSER_RUNTIME_ROOT"] = previous_runtime_root


def assert_unreadable_dependency_refuses(runtime_root: pathlib.Path) -> None:
    """Inject one distribution-file read failure into the identity check."""
    make_environment(runtime_root, dependency=True)
    site_packages = next(
        (runtime_root / "opt" / "browser-venv" / "lib").glob("python*/site-packages")
    )
    unreadable_support = site_packages / "marionette_driver" / "support.py"
    module = load_runner_module()
    original_file_sha256 = cast(
        Callable[[pathlib.Path], str], getattr(module, "file_sha256")
    )

    def refuse_support_file(path: pathlib.Path) -> str:
        if path.resolve() == unreadable_support.resolve():
            raise PermissionError("fixture distribution-file refusal")
        return original_file_sha256(path)

    setattr(module, "file_sha256", refuse_support_file)
    previous_path = list(sys.path)
    retained_modules = {
        name: imported_module
        for name, imported_module in sys.modules.items()
        if name == "marionette_driver" or name.startswith("marionette_driver.")
    }
    for name in retained_modules:
        del sys.modules[name]
    sys.path.insert(0, str(site_packages))
    try:
        module_identity = cast(
            Callable[[str], tuple[str, str]], getattr(module, "module_identity")
        )
        preflight_refusal = cast(type[Exception], getattr(module, "PreflightRefusal"))
        try:
            module_identity("marionette_driver.marionette")
        except preflight_refusal as error:
            assert getattr(error, "stage") == "dependency_identity"
        else:
            raise AssertionError("the injected dependency read failure was accepted")
    finally:
        sys.path[:] = previous_path
        for name in tuple(sys.modules):
            if name == "marionette_driver" or name.startswith("marionette_driver."):
                del sys.modules[name]
        sys.modules.update(retained_modules)


with tempfile.TemporaryDirectory(prefix="browser-driver-preflight-") as temporary:
    temporary_root = pathlib.Path(temporary)

    accepted_root = temporary_root / "accepted"
    (accepted_root / "results").mkdir(parents=True)
    make_environment(accepted_root, dependency=True)
    accepted = run_fixture(accepted_root, "accepted-record")
    assert accepted.returncode == 0, accepted.stderr
    assert_execution_markers_absent(accepted_root)
    accepted_public = json.loads(
        (
            accepted_root / "results" / "accepted-record" / "preflight-public.json"
        ).read_text()
    )
    assert accepted_public["status"] == "accepted"
    assert accepted_public["driver_execution"] == "withheld_preflight_only"
    assert "paths" not in accepted_public
    assert (
        accepted_public["identities"]["browser_python"]["role"]
        == "browser_environment_python"
    )
    assert (
        accepted_public["identities"]["browser_dependency"]["digest_algorithm"]
        == "distribution-manifest-path-content-sha256-v1"
    )
    accepted_dependency_digest = accepted_public["identities"]["browser_dependency"][
        "sha256"
    ]
    support_file = next(
        (accepted_root / "opt" / "browser-venv" / "lib").glob(
            "python*/site-packages/marionette_driver/support.py"
        )
    )
    support_file.write_text("VALUE = 2\n", encoding="utf-8")
    changed_dependency = run_fixture(accepted_root, "changed-dependency-record")
    assert changed_dependency.returncode == 0, changed_dependency.stderr
    changed_dependency_public = json.loads(
        (
            accepted_root
            / "results"
            / "changed-dependency-record"
            / "preflight-public.json"
        ).read_text()
    )
    assert (
        changed_dependency_public["identities"]["browser_dependency"]["sha256"]
        != accepted_dependency_digest
    )

    refused_root = temporary_root / "refused"
    (refused_root / "results").mkdir(parents=True)
    make_environment(refused_root, dependency=False)
    refused = run_fixture(refused_root, "refused-record")
    assert refused.returncode == 2, refused.stderr
    assert_execution_markers_absent(refused_root)
    refused_public = json.loads(
        (
            refused_root / "results" / "refused-record" / "preflight-public.json"
        ).read_text()
    )
    assert refused_public == {
        "driver_execution": "not_started",
        "failure_stage": "dependency_import",
        "schema": "qwen-browser-driver-preflight-v2",
        "status": "refused",
    }

    assert_unreadable_dependency_refuses(temporary_root / "unreadable-dependency")

    foreign_root = temporary_root / "foreign"
    (foreign_root / "results").mkdir(parents=True)
    make_environment(foreign_root, dependency=True)
    (foreign_root / ".qwen-runtime-root").write_text(
        "tree_root=/another/checkout\n", encoding="utf-8"
    )
    foreign = run_fixture(foreign_root, "foreign-record")
    assert foreign.returncode == 2, foreign.stderr
    assert "is bound to /another/checkout" in foreign.stderr
    assert not (foreign_root / "results" / "foreign-record").exists()

    override_root = temporary_root / "override"
    (override_root / "results").mkdir(parents=True)
    make_environment(override_root, dependency=True)
    override = run_fixture(override_root, "override-record")
    assert override.returncode == 0, override.stderr
    override_attempt = subprocess.run(
        [
            str(RUNNER),
            "--driver",
            str(override_root / "fixture-driver.py"),
            "--firefox-bin",
            str(override_root / "firefox-fixture"),
            "--record-directory",
            str(override_root / "results" / "override-attempt"),
            "--runtime-root",
            str(temporary_root / "outside"),
            "--preflight-only",
        ],
        check=False,
        capture_output=True,
        text=True,
        env={**os.environ, "QWEN_HOME": str(override_root)},
    )
    assert override_attempt.returncode == 2
    assert not (temporary_root / "outside").exists()
    for non_finite_timeout in ("nan", "inf"):
        timeout_refusal = subprocess.run(
            [
                str(RUNNER),
                "--driver",
                str(override_root / "fixture-driver.py"),
                "--firefox-bin",
                str(override_root / "firefox-fixture"),
                "--record-directory",
                str(override_root / "results" / f"timeout-{non_finite_timeout}"),
                "--driver-timeout-seconds",
                non_finite_timeout,
            ],
            check=False,
            capture_output=True,
            text=True,
            env={**os.environ, "QWEN_HOME": str(override_root)},
        )
        assert timeout_refusal.returncode == 2
        assert "must be finite and positive" in timeout_refusal.stderr

    import_root = temporary_root / "import-isolation"
    import_result = run_import_isolation_fixture(import_root)
    assert import_result.returncode == 0, import_result.stderr
    assert (import_root / "driver-dependency").read_text() == "fixture"

    timeout_root = temporary_root / "timeout"
    timeout_result, child_process_id = run_timeout_fixture(timeout_root)
    try:
        assert timeout_result.returncode == 124, timeout_result.stderr
        timeout_public = json.loads(
            (
                timeout_root / "results" / "timeout-record" / "preflight-public.json"
            ).read_text()
        )
        assert timeout_public["status"] == "accepted"
        assert timeout_public["driver_execution"] == "failed"
        assert timeout_public["driver_status"] == 124
        assert timeout_public["cleanup"] in {"terminated", "killed"}
        assert (timeout_root / "driver-started").is_file()
        assert (timeout_root / "child-terminated").is_file()
        deadline = time.monotonic() + 2
        while process_is_running(child_process_id) and time.monotonic() < deadline:
            time.sleep(0.02)
        assert not process_is_running(child_process_id)
    finally:
        if process_is_running(child_process_id):
            os.kill(child_process_id, signal.SIGKILL)

    signal_root = temporary_root / "signal"
    signal_status, signal_child_process_id = run_signal_fixture(
        signal_root, signal.SIGTERM
    )
    try:
        assert signal_status == 128 + signal.SIGTERM
        signal_public = json.loads(
            (
                signal_root / "results" / "signal-record" / "preflight-public.json"
            ).read_text()
        )
        assert signal_public["driver_status"] == 128 + signal.SIGTERM
        assert signal_public["termination_signal"] == signal.SIGTERM
        assert signal_public["cleanup"] in {"terminated", "killed"}
        assert (signal_root / "signal-child-terminated").is_file()
        assert not process_is_running(signal_child_process_id)
    finally:
        if process_is_running(signal_child_process_id):
            os.kill(signal_child_process_id, signal.SIGKILL)

    hangup_root = temporary_root / "hangup"
    hangup_status, hangup_child_process_id = run_signal_fixture(
        hangup_root, signal.SIGHUP
    )
    try:
        assert hangup_status == 128 + signal.SIGHUP
        hangup_public = json.loads(
            (
                hangup_root / "results" / "signal-record" / "preflight-public.json"
            ).read_text()
        )
        assert hangup_public["termination_signal"] == signal.SIGHUP
        assert hangup_public["cleanup"] in {"terminated", "killed"}
        assert not process_is_running(hangup_child_process_id)
    finally:
        if process_is_running(hangup_child_process_id):
            os.kill(hangup_child_process_id, signal.SIGKILL)

    orphan_root = temporary_root / "orphan"
    orphan_result, orphan_child_process_id = run_orphan_fixture(orphan_root)
    try:
        assert orphan_result.returncode == 0, orphan_result.stderr
        orphan_public = json.loads(
            (
                orphan_root / "results" / "orphan-record" / "preflight-public.json"
            ).read_text()
        )
        assert orphan_public["driver_status"] == 0
        assert orphan_public["cleanup"] in {"terminated", "killed"}
        assert (orphan_root / "orphan-child-terminated").is_file()
        assert not process_is_running(orphan_child_process_id)
    finally:
        if process_is_running(orphan_child_process_id):
            os.kill(orphan_child_process_id, signal.SIGKILL)

    start_failure_root = temporary_root / "start-failure"
    assert run_start_failure_fixture(start_failure_root) == 2
    start_failure_public = json.loads(
        (
            start_failure_root
            / "results"
            / "start-failure-record"
            / "preflight-public.json"
        ).read_text()
    )
    assert start_failure_public["driver_execution"] == "not_started"
    assert start_failure_public["failure_stage"] == "driver_start"
    assert start_failure_public["schema"] == "qwen-browser-driver-preflight-v2"
    assert start_failure_public["status"] == "refused"
    assert "identities" in start_failure_public

    runner_module = load_runner_module()
    final_status = cast(
        Callable[[int, int | None, str], int],
        getattr(runner_module, "final_driver_status"),
    )
    assert final_status(0, signal.SIGTERM, "already_exited") == 128 + signal.SIGTERM

    zombie = subprocess.Popen(
        [sys.executable, "-c", "raise SystemExit(0)"], start_new_session=True
    )
    try:
        zombie_stat = pathlib.Path("/proc") / str(zombie.pid) / "stat"
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                if (
                    zombie_stat.read_text(encoding="utf-8").rsplit(")", 1)[1].split()[0]
                    == "Z"
                ):
                    break
            except FileNotFoundError:
                pass
            time.sleep(0.01)
        else:
            raise AssertionError("fixture process did not become a zombie")
        group_lives = cast(
            Callable[[int], bool], getattr(runner_module, "process_group_lives")
        )
        assert not group_lives(zombie.pid)
    finally:
        zombie.wait(timeout=5)

print("browser_driver_preflight=accepted checks=15")
