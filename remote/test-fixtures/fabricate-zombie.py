#!/usr/bin/env python3
"""Fork a child that exits immediately and hold it as a zombie.

A shell subshell backgrounded under bash does not serve this purpose: bash
reaps an asynchronous child through its own SIGCHLD handler as soon as it
exits, whether or not anything calls `wait`, so /proc/PID/stat for such a
child is already gone by the time a caller checks it. A bare fork(2) installs
no such handler, so the child this process forks stays a zombie -- readable at
/proc/PID/stat with state Z, its start time frozen -- for as long as this
process holds off calling waitpid(2) on it.

Writes the child's pid to the path named by argv[1] once it exists, then
sleeps for the seconds named by argv[2] (20 by default) before reaping it and
exiting. A caller that needs the zombie gone sooner sends this process SIGKILL:
the child reparents to the nearest subreaper, which reaps it promptly.
"""

import os
import sys
import time

ready_path = sys.argv[1]
hold_seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 20.0

child_pid = os.fork()
if child_pid == 0:
    os._exit(0)

with open(ready_path, "w", encoding="utf-8") as handle:
    handle.write("%d\n" % child_pid)

time.sleep(hold_seconds)
os.waitpid(child_pid, 0)
