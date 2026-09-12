"""Exercise identity-bound pidfd process-group signaling."""

from __future__ import annotations

import errno
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

GROUP_LEADER_PROGRAM = r"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
stat_text = Path("/proc/self/stat").read_text(encoding="ascii")
start_time_ticks = int(stat_text[stat_text.rfind(")") + 2 :].split()[19])
print(
    json.dumps(
        {
            "pid": os.getpid(),
            "process_group_id": os.getpgrp(),
            "session_id": os.getsid(0),
            "start_time_ticks": start_time_ticks,
            "child_pid": child.pid,
        }
    ),
    flush=True,
)
time.sleep(30)
"""

NONLEADER_PROGRAM = r"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

candidate = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
sibling = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
stat_text = Path(f"/proc/{candidate.pid}/stat").read_text(encoding="ascii")
start_time_ticks = int(stat_text[stat_text.rfind(")") + 2 :].split()[19])
print(
    json.dumps(
        {
            "leader_pid": os.getpid(),
            "candidate_pid": candidate.pid,
            "candidate_start_time_ticks": start_time_ticks,
            "sibling_pid": sibling.pid,
        }
    ),
    flush=True,
)
time.sleep(30)
"""

SUPPORT_FAILURE_PROGRAM = r"""
import errno
import importlib.util
import os
import signal
import sys
from pathlib import Path

helper_path = Path(sys.argv[1])
failure_errno = int(sys.argv[2])
spec = importlib.util.spec_from_file_location("signal_process_group", helper_path)
if spec is None or spec.loader is None:
    raise SystemExit("cannot load signal-process-group helper")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

original_fork = os.fork
original_pidfd_send_signal = signal.pidfd_send_signal
probe_child_pid = None


def recording_fork():
    global probe_child_pid
    child_pid = original_fork()
    if child_pid > 0:
        probe_child_pid = child_pid
    return child_pid


def failing_group_signal(pidfd, signal_number, siginfo=None, flags=0):
    if flags == module.PIDFD_SIGNAL_PROCESS_GROUP:
        raise OSError(failure_errno, os.strerror(failure_errno))
    return original_pidfd_send_signal(pidfd, signal_number, siginfo, flags)


module.os.fork = recording_fork
module.signal.pidfd_send_signal = failing_group_signal
try:
    module.check_kernel_support()
except module.SignalProcessGroupError as error:
    print(str(error))
else:
    raise SystemExit("failing support probe returned success")
if probe_child_pid is None:
    raise SystemExit("support probe did not record its child")
try:
    waited_pid, _ = os.waitpid(probe_child_pid, os.WNOHANG)
except ChildProcessError:
    waited_pid = probe_child_pid
if waited_pid != probe_child_pid:
    raise SystemExit("support probe left its direct child alive")
"""


def process_state(process_id: int) -> str:
    try:
        stat_text = (Path("/proc") / str(process_id) / "stat").read_text(encoding="ascii")
    except FileNotFoundError:
        return "absent"
    command_end = stat_text.rfind(")")
    if command_end < 0:
        return "malformed"
    fields = stat_text[command_end + 2 :].split()
    return fields[0] if fields else "malformed"


def stop_group(process: subprocess.Popen[str], process_group_id: int) -> None:
    if process.poll() is None:
        os.killpg(process_group_id, signal.SIGKILL)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process_group_id, signal.SIGKILL)
        process.wait(timeout=5)


def require_nonleader_refusal(helper: Path) -> None:
    process = subprocess.Popen(
        [sys.executable, "-c", NONLEADER_PROGRAM],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    assert process.stdout is not None
    ready_line = process.stdout.readline()
    if not ready_line:
        _, stderr = process.communicate(timeout=5)
        raise AssertionError(f"nonleader fixture did not become ready: {stderr}")
    identity: dict[str, int] = json.loads(ready_line)
    leader_pid = identity["leader_pid"]
    candidate_pid = identity["candidate_pid"]
    candidate_start_time_ticks = identity["candidate_start_time_ticks"]
    sibling_pid = identity["sibling_pid"]
    try:
        if leader_pid != process.pid:
            raise AssertionError("nonleader fixture reported a different leader")
        refused = subprocess.run(
            [str(helper), str(candidate_pid), str(candidate_start_time_ticks), "TERM"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        if (
            refused.returncode != 1
            or "does not own its process group and session" not in refused.stderr
        ):
            raise AssertionError(
                "nonleader/session-member identity was not refused: "
                f"{refused.returncode} {refused.stdout} {refused.stderr}"
            )
        if (
            process.poll() is not None
            or process_state(candidate_pid) in {"absent", "Z"}
            or process_state(sibling_pid) in {"absent", "Z"}
        ):
            raise AssertionError("nonleader refusal signaled the session leader or a sibling")
    finally:
        stop_group(process, leader_pid)


def main() -> int:
    script_directory = Path(__file__).resolve().parent
    helper = script_directory / "signal-process-group.py"
    check = subprocess.run(
        [str(helper), "--check"],
        check=False,
        capture_output=True,
        text=True,
        timeout=5,
    )
    if check.returncode != 0 or check.stdout.strip() != "pidfd_process_group=available":
        raise AssertionError(f"pidfd process-group check failed: {check.returncode} {check.stderr}")

    for failure_errno, expected_message in (
        (errno.EINVAL, "kernel lacks pidfd process-group signaling"),
        (errno.EPERM, "pidfd process-group support probe failed"),
    ):
        failed_check = subprocess.run(
            [
                sys.executable,
                "-c",
                SUPPORT_FAILURE_PROGRAM,
                str(helper),
                str(failure_errno),
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        if failed_check.returncode != 0 or expected_message not in failed_check.stdout:
            raise AssertionError(
                "failing pidfd support check did not cleanly refuse: "
                f"{failed_check.returncode} {failed_check.stdout} {failed_check.stderr}"
            )

    require_nonleader_refusal(helper)

    process = subprocess.Popen(
        [sys.executable, "-c", GROUP_LEADER_PROGRAM],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    assert process.stdout is not None
    ready_line = process.stdout.readline()
    if not ready_line:
        _, stderr = process.communicate(timeout=5)
        raise AssertionError(f"process group did not become ready: {stderr}")
    identity: dict[str, Any] = json.loads(ready_line)
    process_id = int(identity["pid"])
    process_group_id = int(identity["process_group_id"])
    session_id = int(identity["session_id"])
    start_time_ticks = int(identity["start_time_ticks"])
    child_pid = int(identity["child_pid"])
    try:
        if process_id != process.pid:
            raise AssertionError("reported process identity differs from Popen")
        if process_group_id != process_id or session_id != process_id:
            raise AssertionError("fixture does not lead its process group and session")

        mismatch = subprocess.run(
            [str(helper), str(process_id), str(start_time_ticks + 1), "TERM"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        if mismatch.returncode == 0 or "start time differs" not in mismatch.stderr:
            raise AssertionError("mismatched process identity was not refused")
        if process.poll() is not None or process_state(child_pid) in {"absent", "Z"}:
            raise AssertionError("identity refusal signaled the process group")

        accepted = subprocess.run(
            [str(helper), str(process_id), str(start_time_ticks), "TERM"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        if accepted.returncode != 0 or "pidfd_process_group=signaled" not in accepted.stdout:
            raise AssertionError(f"matching process identity was not signaled: {accepted.stderr}")
        return_code = process.wait(timeout=5)
        if return_code != -signal.SIGTERM:
            raise AssertionError(f"group leader exited with {return_code}, expected SIGTERM")
        deadline = time.monotonic() + 5
        while process_state(child_pid) not in {"absent", "Z"} and time.monotonic() < deadline:
            time.sleep(0.02)
        if process_state(child_pid) not in {"absent", "Z"}:
            raise AssertionError("foreground child survived process-group signaling")
    finally:
        stop_group(process, process_group_id)

    invalid = subprocess.run(
        [str(helper), "1", "1", "KILL"],
        check=False,
        capture_output=True,
        text=True,
        timeout=5,
    )
    if invalid.returncode != 1 or "signal must be HUP, INT, or TERM" not in invalid.stderr:
        raise AssertionError("unsupported signal was not refused")
    print("test_signal_process_group=accepted")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
