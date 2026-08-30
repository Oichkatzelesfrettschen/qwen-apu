# Absolute idle priority for workload launchers

## Mechanism

`nice -n 19 COMMAND` adds 19 to the caller's own nice value through
`nice(2)`, and the kernel clamps the sum at 19. A caller at nice 0 lands the
command at 19; a caller at nice -4 lands it at 15. `renice --priority 19 --pid
PID` writes the absolute value through `setpriority(2)`, so the outcome is 19
whatever the caller held. The applied value is a second claim from the
request, so every launcher in this tree reads it back from the kernel: field
19 of `/proc/PID/stat` in Python, `ps -o ni= -p PID` in shell.

util-linux 2.39.3 on the appliance treats `renice -n 19 -p PID` as absolute as
well, both plain and under `POSIXLY_CORRECT=1`, from a caller at nice 5
(observed on the appliance, where the reading after each form was 19). Every
`download-*.sh`, build, and derive script runs `renice -n 19 -p $$` before it
spawns anything, so those launchers were already absolute on the installed
version. The two launchers below used a different mechanism and were the two
remaining defects.

## Defects

`remote/measure-dpm-force.sh` ran each arm as `nice -n 19 ionice -c 3
"$bench"` with no prior renice. The harness's own nice was whatever its caller
held, so a caller below nice 0 ran the bench above 19 while the retained
summary carried no record of the priority at all.

`remote/image-service.py` spawned sd-cli through `os.posix_spawn(...,
setsid=True)`, applied `os.setpriority(os.PRIO_PROCESS, child_pid, 19)` from
the parent, and read the value once through `read_process_nice`. The refusal
fired only when the reading was present and differed from 19: a `None`
reading survived as `nice=-` in the provenance record and the job completed.

## Fix

`remote/qwen-exec-idle-priority.sh` is the child-side wrapper. It runs
`/usr/bin/renice --priority 19 --pid "$$"`, reads field 19 back from
`/proc/$$/stat`, and exits 125 with `priority setup refused: requested=19
observed=...` on any other reading; it then runs `/usr/bin/ionice -c 3 -p
"$$"`, reads the class back through `/usr/bin/ionice -p`, and exits 125 on any
class other than `idle`; then it `exec`s the command. `exec(2)` keeps the pid,
session, process group, nice value, and I/O class, so the pid a parent recorded
at spawn is the pid of the command it later signals. Every utility is named by
its fixed path, and `QWEN_IDLE_PRIORITY_RENICE`, `QWEN_IDLE_PRIORITY_PROC_STAT`,
`QWEN_IDLE_PRIORITY_AWK`, and `QWEN_IDLE_PRIORITY_IONICE` override those paths
for a test that substitutes a failing utility.

`image-service.py` spawns `[wrapper, *runtime_argv]` with the wrapper as the
executable, resolved beside its own file and overridable through
`--priority-wrapper` or `QWEN_IMAGE_PRIORITY_WRAPPER`. `posix_spawn` stays,
since the service is multithreaded and a post-fork Python hook can block on a
lock another thread held. The parent-side `setpriority` is removed; the job's
`child_pid` is published immediately after the spawn so a cancel reaches the
wrapper's process group before or after the exec; `wait_for_process_nice`
polls `/proc` for up to one second until the value reads 19 and returns the
last observed value or `None`. Both departures fail closed: the process group
is signalled, the child is reaped, and the job fails with `the runtime
priority was unreadable after the priority wrapper` or `the runtime ran at
nice N; nice 19 is required`. The I/O class is polled through `ionice -p PID`
inside the same window and recorded as observed; the wrapper's own status 125
is what ends a runtime whose class stayed elsewhere. The provenance record
carries `priority_wrapper`, `priority_wrapper_sha256`, `runtime_argv`,
`runtime_pid`, `nice`, and `ioclass`; `runtime_argv[0]` names the runtime,
since the wrapper replaced itself with it.

`measure-dpm-force.sh` renices its own pid to 19 before the first arm, reads
the value back through `ps`, exits 2 with `measurement priority refused:
observed=...` on any other reading, applies the idle I/O class, and runs
`"$bench"` directly so the arm inherits both. `harness_nice` and
`harness_ioclass` are two new columns on every summary row and appear on each
`arm_start_utc` line.

## Fixture results

Workstation, caller shell observed at nice -4, util-linux 2.42.2, kernel
7.2.0. The negative starting nice is the case the relative form gets wrong,
so the fixtures ran from the condition under test.

| fixture | result |
| --- | --- |
| `remote/test-qwen-exec-idle-priority.sh` | `idle_priority_wrapper=passed fixtures=8`: exec target reports nice 19 and class `idle` from a `nice -n 5` caller; exec keeps the launched pid; a renice applying nothing, unreadable procfs state, and an ionice reporting `best-effort` each exit 125 with the command's marker file absent; the command's exit status passes through |
| `python3 remote/test-image-service.py` | `Ran 40 tests ... OK`: the 37 prior tests through the wrapper, plus unreadable priority fails and reaps, nice other than 19 fails and reaps, cancel during wrapper startup kills the group before exec with no runtime run and no artifact, and the provenance record carries the wrapper path, its digest, the runtime pid, `nice=19`, `ioclass=idle`, and the runtime as `runtime_argv[0]` |
| `remote/test-measure-dpm-force.sh` | `dpm_harness_priority=passed arms=2 bench_nice=19`: the harness run from `nice -n 5` writes `harness_nice=19` and `harness_ioclass=idle` on both arms and the forked bench observes nice 19 on itself |
| `remote/test-measurement-harnesses.sh` | `measurement_harnesses=accepted` |
| `remote/test-qwen-image-launch.sh` | `all checks passed` |
| `remote/test-admit-image-router.sh` | `admit_image_router=accepted`, one generation through the wrapper on the served path |

The unreadable arm points `QWEN_IMAGE_PROCFS_ROOT` at an empty directory,
which is the one way to make `/proc/PID/stat` unreadable for a live child
without root. The nice-mismatch arm substitutes a wrapper that execs without
renice, so the runtime holds the service's own nice and the refusal names it.

## Not run

The privileged appliance arm -- a caller at a negative nice on the laptop,
which requires `sudo` to lower a shell's priority -- is `not run`. The
workstation caller at nice -4 exercised the same relative-versus-absolute
condition on util-linux 2.42.2, and the appliance's own 2.39.3 renice was
observed absolute under `-n`; the `--priority` long option the wrapper uses
is the documented absolute form on both versions, and the wrapper's own
readback is what would report a divergence on the device.
