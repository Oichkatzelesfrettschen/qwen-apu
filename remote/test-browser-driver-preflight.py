#!/usr/bin/env python3
"""Exercise browser interpreter selection and fail-closed preflight."""

from __future__ import annotations

import json
import os
import pathlib
import signal
import subprocess
import tempfile
import time
import venv

SCRIPT_DIRECTORY = pathlib.Path(__file__).resolve().parent
RUNNER = SCRIPT_DIRECTORY / "run-browser-driver.sh"


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
        metadata = site_packages / "marionette_driver-3.7.1.dist-info"
        metadata.mkdir()
        (metadata / "METADATA").write_text(
            "Metadata-Version: 2.1\nName: marionette_driver\nVersion: 3.7.1\n",
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
    hostile.mkdir()
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
        "schema": "qwen-browser-driver-preflight-v1",
        "status": "refused",
    }

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

print("browser_driver_preflight=accepted checks=3")
