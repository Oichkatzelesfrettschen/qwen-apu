---
name: qwen-telemetry-session-records
description: "Branch telemetry-session-records makes each session's telemetry immutable; the monitor still starts after readiness, so the model-loading peak stays unmeasured"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-01T00:04:53.157Z
---

Branch `telemetry-session-records` at 951ce41 (off main deliberately) gives each
launch its own record under `$state_directory/telemetry/`, points
`telemetry.log` at it as a convenience symlink, seals the finished record
read-only, and derives a summary through `remote/summarize-telemetry-session.sh`.
The immutable record is the authority and the summary is convenience, since
`tmux kill-session` ends the session script without its EXIT trap; a missing
summary means finalization did not run rather than that the session did not
happen. `remote/test-telemetry-session-records.sh` proves an earlier record
survives a later session byte for byte and that the advanced symlink leaves the
recorded path resolving.

The measured gap that matters most: `qwen-webui-session.sh` waits for the
readiness marker at line ~383 and starts the monitor at line ~479, so model
mapping, Vulkan allocation, weight upload, loading-time temporaries, the
MemAvailable trough, and any pre-readiness swap all execute unguarded and
unrecorded. The 4 GiB reserve and 64 MiB/sample swap-in rules protect serving
alone. The 9B operational arm needs exactly that loading peak, so the record
must span `phase=loading` (started once the child's nice and affinity are set,
latency liveness inactive) and `phase=serving` (readiness landed, latency
watchdog PID published through a session-owned file). One continuous raw record,
one Vulkan probe, a pre-spawn launch sample, and per-second sampling through the
readiness interval, since a single initial sample cannot see a transient peak.

No digest carrier exists: neither `qwen-webui-control.sh`'s tmux command string
nor the branch forwards `QWEN_MODEL_SHA256`, so `model_sha256` reads `-` today.
Add the carrier with `model_sha256_source` over `caller`, `verified-download`,
`unavailable`, keep it non-authoritative so it never gates admission, and add
the cheap observed identity tuple `model_path_resolved`, `model_size_bytes`,
`model_device`, `model_inode`, `model_mtime_ns`, which names the file object the
launch opened and joins to an earlier verified download.

Remaining work on the branch: record names carry `/proc/PID/stat` start ticks
beside timestamp and PID, exclusive-create so a collision refuses rather than
truncates, atomic symlink replacement by temporary link plus rename, sealing
only after the monitor exits and is waited for (chmod cannot stop a writer
holding an open descriptor), and a next-launch sweep that seals older writable
records whose PID and start-time identity are gone with an `incomplete` sidecar,
never appending a synthetic ending. Completeness reads from the record: a
terminal `monitor_stop` line is complete, abort plus termination lines are a
guarded abort, neither is incomplete or externally terminated.

Merge order: 4B close -> checkpoint promotion -> smoke the new binary under the
existing monitor -> retain promotion evidence -> rebase this branch onto
promoted main -> add load-phase coverage and carrier tests -> full repository
gate -> merge -> one monitor-only smoke on the unchanged promoted binary ->
Stage A. Shipping a candidate binary and a changed monitor in one smoke would
confound a failure.

Related: [[qwen-natural-boundary-patch]], [[qwen-laptop-host-memory-tenants]],
[[qwen-decode-campaign]].
