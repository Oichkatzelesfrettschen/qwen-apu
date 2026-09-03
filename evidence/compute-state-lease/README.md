# The compute-state lease

`remote/compute-state-lease.sh PROFILE COMMAND [ARG...]` runs one command inside
one reversible machine-state transaction. Four authorities decide what this part
delivers, each of them machine-wide: `power_dpm_force_performance_level` and the
two DPM tables under the amdgpu device, `/sys/kernel/mm/ksm/run`, and the
process terms -- nice level, CPU affinity, I/O class -- the command inherits. A
write to any of them reaches every workload on the machine, so a run that left
one applied would leave the next measurement reading this run's state under
another campaign's name.

The transaction order is the order the risk sits in. Every refusal that needs no
write runs first: the profile name, the cached `sudo -n` credential, the drm and
hwmon surfaces, the KSM run state, the DPM tables' own frequencies at the levels
the profile names, and the process terms, which are applied to the harness and
read back from the kernel so the command inherits a proven set. The shared
Vulkan lease is taken next, ahead of the first write, because the write moves the
clock a concurrent image generation or served request would run at. The snapshot
and the restore trap follow, then the writes, then the delivered-clock proof,
then the command, then the restore and its verification, then the lease.

## The two profiles

| | `measure-fixed` | `serve-performance-candidate` |
| --- | --- | --- |
| `power_dpm_force_performance_level` | `manual` | `manual` |
| `pp_dpm_sclk` written | `2` | `2` |
| `pp_dpm_mclk` written | `2` | `2 3` |
| delivered GFXCLK required | 1100 MHz | 1100 MHz |
| selected FCLK admitted | 933 MHz | 933 or 1067 MHz |
| child nice | 19 | 0 |
| child I/O class | idle | best-effort |
| child cores | 0,1 | 0,1 |
| `/sys/kernel/mm/ksm/run` | 0 | 0 |

`measure-fixed` is one execution state for a measurement arm: the graphics clock
pinned, the fabric clock held at one value, and the host terms the fixed-64
scoreboard campaign already states. `serve-performance-candidate` keeps the
graphics pin, writes the fabric selection as a range so the firmware may choose
1067 MHz where it has headroom, and gives the server the whole scheduler.

## Invariants

The delivered graphics clock is read from the amdgpu hwmon `freq1_input` rather
than from the starred `pp_dpm_sclk` step, because that step reports the state the
governor selected and not what the part delivers. The two halves of the clock
proof are named separately, so a refusal states which one missed.

The fabric selection is written and read back rather than required. The firmware
caps a 1067 MHz hard minimum at 933, so a level the profile names is admitted at
whichever of the profile's own frequencies the device stars, and the expectation
is a set rather than a floor.

The restore is verified rather than requested. Each authority is polled back to
its snapshot inside a bounded deadline, and a value that fails to return names
itself on a `restoration=failed` line and ends the transaction with status 4,
which dominates the command's own status: a command that exited 0 over a machine
left forced still exits 4. `clock_expectation=unreached` is the separate status
3, and an arm that reports it has a held restore.

A command that ignores or delays SIGTERM cannot hold the Vulkan lease and
machine-wide DPM profile applied forever. The child shutdown sequence sends
SIGTERM and polls for termination with bounded timeouts. `QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS`
sets the grace period in seconds (default 10); after that, SIGKILL is sent.
Polling continues for 5 more seconds. If the child still persists, the
transaction cleans up and restores the machine state while the unreaped child
remains attached to the process. The `child_stop` field in the output names the
outcome: `term` if the child exited after SIGTERM, `kill` if SIGKILL was
required, or `unreaped` if the child persisted after SIGKILL.

The two DPM selections are verified against the snapshot only where the snapshot
level was `manual`. A governor moves the star under every other level, so
comparing it there would report the governor rather than the restore. The
appliance presents an `auto` snapshot, since the launch chain writes no
performance level, and on that path the level word carries the whole claim:
`amdgpu_set_power_dpm_force_performance_level` hands the level back to the
governor, which owns both bounds from there, and no sysfs surface reports a
residual restriction beside the star the governor is already moving. The restore
line states which of the two it verified -- `selections=verified` under a
`manual` snapshot and `selections=governor-owned` otherwise -- rather than
printing a star it did not compare.

The process terms leave with the process. The state record states what the
command ran under, and the restore covers the two machine-persistent authorities.

`env -i` replaces the environment and leaves the descriptor table alone, so the
command inherits the lease descriptor and reads the published proof through
`QWEN_VULKAN_EXTERNAL_LEASE_PROOF`; `qwen-capacity-policy.sh` answers a verified
proof by unsetting `QWEN_VULKAN_WORKLOAD_LOCK` for the server it assembles, which
is what keeps a served command from blocking in `update_slots` against the lock
this transaction holds. A grandchild the command forks and leaves behind holds
that inherited descriptor until it exits.

## Prohibitions

`high` and `profile_peak` are refused by name. Both pin the delivered graphics
clock at 1100 MHz and collapse the starred `pp_dpm_mclk` fabric state to 400 MHz,
which measured 6.3 to 7.0 tok/s against `auto`'s 6.8 to 8.2 on the 2B distill
(`evidence/raven2-vulkan-kernel-census/dpm-authority/`). Each is a slower machine
than the appliance default, so neither is a profile here.

A 1067 MHz hard minimum on `pp_dpm_mclk` is accepted by the kernel and held at
933 MHz by the firmware, with 1067 observed in 2 of 107 samples under `auto`
alone. No profile requires it and no refusal is filed against it.

`/sys/kernel/mm/ksm/run` takes 2 to unmerge every merged page, which spends the
host memory ksmd already saved. This transaction writes 0 and 1 alone, and a
snapshot reading 2 refuses at preflight rather than being written back at
restore.

`pp_dpm_mclk` is a misleading sysfs name on SMU10: the kernel obtains its value
with `PPSMC_MSG_GetFclkFrequency`, so its states are dynamic fabric clocks. The
DRAM is trained at DDR4-2133.33 whichever state is selected, and no profile here
changes a memory clock.

## The registered production-policy campaign

The question the profiles exist to answer: does
`serve-performance-candidate` decode faster than the appliance's own serving
state, on the machine the appliance actually runs on?

`serve-normal` is that serving state -- the DPM level left where the launch chain
leaves it, the server at nice 19 in the I/O idle class, and ksmd running -- and
`serve-compute` is one `serve-performance-candidate` transaction around the same
served command. The arms run `serve-normal, serve-compute, serve-compute,
serve-normal` in that order, once per class on the 0.8B, the 2B, and the 4B, with
each class's four arms inside one sweep and each arm measured by
`remote/measure-served-decode.sh` at the fixed-64 request shape.

The statistic is the paired mean of the two `serve-compute` arms against the two
`serve-normal` arms that bracket them, reported with its 95% interval, per class.
An absolute rate is not the statistic and no arm is read across sweeps: this
machine carries about 4% of uncontrolled spread on a repeated depth-0 rate and
30.6% under desktop load, and four absolute prediction bands built from retained
means all read low against a later sweep
(`evidence/model-admission/universal-candidate-ladder.md`). The mirrored order is
what keeps queue position out of the comparison.

The VM is present as a stated condition rather than removed. A 16.5 GiB qemu
guest at nice 0 and ksmd at nice 5 share the two cores with the server, and the
nice probe of `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T2154Z-nice-probe/`
measured nice 0 at +1.9% [+0.6, +3.2] on llama-bench while the rate tracked
`load1` under both levels, so guest memory traffic is the unresolved candidate.
The campaign therefore states the guest's presence and its load average per arm
and claims nothing about a machine without it.

Falsifiers, registered ahead of any run:

- The paired mean's 95% interval covers zero on all three classes. The profile
  buys no decode on this machine under the served load it will run under, and
  `serve-performance-candidate` stays a named profile with no serving claim.
- The interval clears zero in the negative direction on any class. Giving the
  server nice 0 and the fabric range costs that class decode, which refutes the
  profile for it outright rather than leaving it unresolved.
- The two `serve-normal` arms of one class differ by more than the sweep's own
  span criterion. The sweep measured its own instability rather than the profile,
  and the class's arms are discarded whatever the middle two did.
- Any arm reports `clock_expectation=unreached` or `restoration=failed`. The
  campaign halts: an arm whose machine state was neither proven nor returned
  reports the harness rather than the profile.
- The classes disagree in direction. The result is that class's profile setting
  rather than a Raven2-wide default, which is the rule
  `remote/models.tsv`'s runtime classes already carry.

The campaign is registered and not run. No device time is claimed here.

## Verification without a device

`remote/test-compute-state-lease.sh` drives the whole transaction against a
fixture sysfs tree under `mktemp` with no privilege. One `sudo` stub models the
part's firmware -- a level index moves its table's star, a graphics selection
moves the hwmon frequency, and a fabric level above the fixture's cap is clamped
the way SMU10 clamps 1067 to 933 -- and the command is an observer that records
the live values, its own nice level, its own affinity, and its own environment
while it runs, which is what makes the applied profile provable rather than only
the state before and after it. The lease, its published proof, and
`verify-external-vulkan-lease.py` run unstubbed against a real `flock`.

Eighteen cases pass: the usage form, the `high` and `profile_peak` refusals, a
refused non-integer stop grace, a clean apply-run-restore, the command's
observation of the applied profile, its inherited affinity, the KSM 0-and-back
round trip, the state record's snapshot rows, the closed arm environment
carrying the lease proof, the serving profile accepting the clamped fabric
level, an `auto` snapshot restoring the level and naming the governor as the
selections' owner, the held-lease refusal, an unreached clock expectation
refusing before the command, a failed restoration reported as an incident over
a command that exited 0, a terminating signal mid-command that still restores,
a child that traps SIGTERM and requires the SIGKILL escalation, the lease
releasing once that child is gone, and `status` reporting live values with no
credential.

The SIGKILL case is the harness's own deferred one. A command that traps
SIGTERM and loops on `sleep 1` forks a new `sleep` each iteration, and each
fork inherits the open lease descriptor `env -i` carries into every command.
`kill -KILL` reaches the tracked child alone: the `sleep 1` in flight at that
moment is reparented and keeps running for the rest of its own second, holding
the descriptor -- and the lease -- open after the transaction and its tracked
child are both gone. The fixture closes its own copy of the descriptor
(`exec 8>&-`) and traps SIGTERM before it does anything else, including the log
write a caller polls for readiness on, so a caller sending SIGTERM the instant
it observes that readiness marker cannot race the default disposition a later
trap install would still leave armed; the earlier commit's own placement did
race it, killing the fixture on SIGTERM often enough to read `child_stop=term`
where `kill` was expected. With the trap installed first, no forked `sleep`
ever holds the descriptor and the lease reads free within one poll interval of
the KILL rather than up to a second later.

Two more findings came from an independent review of the shutdown sequence
itself. `stop_child` no longer calls `wait` on a child still alive after
SIGKILL and its own 5-second poll: `kill -0` succeeding there means the kernel
cannot yet reap it, most likely an uninterruptible-sleep child, and `wait`
blocks until it is reaped -- trading the bounded shutdown this function exists
to provide for an unbounded one in exactly the case it is supposed to cover.
`QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS` is validated ahead of the first write
rather than trusted at the point `stop_child` runs it through
`$((grace_seconds * 5))` inside the EXIT trap: a non-integer value there is a
shell arithmetic error that would abort the trap ahead of `finish_transaction`
and leave the applied DPM/KSM state unrestored.
