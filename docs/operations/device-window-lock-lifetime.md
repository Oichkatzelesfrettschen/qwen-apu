# Device-window lock lifetime

The window supervisor owns descriptor 7 from admission through teardown,
workload completion, relaunch, and health verification. An inherited descriptor
refers to the same open file description and can retain its flock after the
supervisor exits. A persistent tmux server started during relaunch must therefore
receive neither descriptor 7 nor its window re-exec marker.

`run_window_child` closes that descriptor and clears the marker for teardown,
the workload, relaunch, and health verification. Other descriptors remain intact,
including the Vulkan lease and reporting channels. The supervisor waits for its
foreground child before handling cancellation; the workload must provide its own
bounded execution and cleanup contract. Cancellation exits through restoration,
and further INT/TERM signals during restoration do not release the exclusion.
Restoration commands run through `setsid --wait` in a separate session/process
group, preserving ordinary service signal dispositions while excluding signals
sent to the original foreground process group.
SIGKILL and host failure remain outside the shell cleanup guarantee.

Run `remote/test-run-device-window.sh` and ShellCheck on the runner and fixture.
The fixture leaves persistent children from all four boundaries alive. A contender
must refuse while workload cleanup or final health verification is pending, and
must succeed after the supervisor exits while those children remain alive. Normal,
command-failure, TERM, repeated TERM during restoration, and foreground-process-group INT/TERM are
covered. Descriptor
8 and removal of the window marker are checked independently.

## Existing-holder recovery preparation

The source repair prevents future inheritance; an existing holder requires a
separate, explicitly authorized recovery operation. The following is a plan,
not an executed recovery or a baseline acquisition.

1. Record the lock's device/inode and all matching descriptors, including lock
   metadata. Bind each holder to executable, UID, process start ticks, parent,
   session, and the exact tmux socket/session inventory. Recheck start ticks.
   Resolve inaccessible holders before classifying the ownership as conclusive.
2. Reconcile holder start times with completed window ledgers and check for active
   maintenance commands. A status-file absence alone cannot establish an idle
   window. Hold recovery if any legitimate work or holder remains uncertain.
3. Gate the corrected source and prepare a named recovery record, the exact
   teardown/relaunch commands, and a restoration supervisor independent of the
   tmux server being drained. Record executable and bundle identities, API-key
   file identity without its contents, VM identity, and host-state snapshots.
   Establish privileges sufficient for the complete restoration path.
4. Under the separately authorized recovery, use the existing controlled teardown
   for only the verified appliance session. Let the dedicated tmux server exit
   when its verified sessions finish. Do not kill a server containing unrelated
   sessions. Do not unlink, replace, rename, explicitly unlock, or inject a close
   into the existing lock object. Retain the original inode throughout recovery.
5. Recheck holders and acquire the same lock normally after the unintended holder
   exits. Relaunch through the fixed child boundary under supervisor ownership,
   using the preserved serving bundle and authentication mode. Verify service,
   deployment targets, VM, host settings, supervisor completion, and subsequent
   nonblocking acquire/release on the same inode. Stop if any proof fails.
6. Schedule the single repaired 2B canary only after maintenance lifecycle and
   authenticated health are proven. Keep anchor and kernel runs held.

The recovery driver must preserve restoration on cancellation and failure even
before it can acquire the legacy lock. Finalize and review that driver against the
fresh holder/session inventory before execution; the canary runner is not a
substitute for the recovery supervisor.
