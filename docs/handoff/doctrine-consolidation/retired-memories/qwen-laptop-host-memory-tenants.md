---
name: qwen-laptop-host-memory-tenants
description: "a qemu VM holds ~16.5 GiB RSS on the laptop and the runtime monitor aborts the served router when MemAvailable falls under its reserve, so builds and fetches run with the router torn down"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-08-31T22:49:44.885Z
---

On 2026-08-29 the laptop carried a `qemu-system-x86` process at 16.5 GiB RSS
and Firefox at 0.6 GiB beside the router. A two-job stable-diffusion.cpp build
beside the served 2B router drove MemAvailable below the reserve and the
runtime monitor aborted the server with `reason=memory_reserve_breached`, a
clean exit that `qwen-webui-control.sh status` reports as `state=stopped
stopped_component=server`.

`monitor-qwen-runtime.sh:85` sets `minimum_mem_available_kib=4194304`, exactly
4.000 GiB, sampled every second, and terminates at
`mem_available_kib < 4194304` (line 199); line 86 sets
`maximum_swapin_bytes_per_sample=67108864`, exactly 64 MiB, terminating as
`swapin_rate_breached` (line 203). A "4.19 GiB" triggering sample is therefore
impossible -- it was 4.19 decimal GB (about 3.90 GiB) or the sample before the
crossing. The authoritative value is the `mem_available_kib=` line immediately
preceding the reason line, and the live telemetry.log has since rotated past
that event with zero matches, so the raw figure is unrecoverable and the number
stays unquoted rather than reconstructed.

**Why:** the monitor guards the served model against host memory pressure, and
a compile or large download beside it is enough to cross the reserve while the
VM stays resident.

The VM is non-optional and stays up (stated 2026-08-31). Its ~16.5 GiB is a
standing tenant rather than a variable, so no experiment carries a VM-stopped
arm, every host reserve is measured with it resident, and any capacity claim
holds for the machine as it actually serves. A reboot ends it too, which is one
more reason a 20 GiB research boot needs its own coordination.

**How to apply:** run builds and multi-GiB fetches in a chain that begins with
`qwen-teardown.sh` and ends with `qwen-launch.sh`; a `state=stopped` router
after a build is that abort, and the telemetry log names it. The VM is the
user's and is left alone. See [[qwen-laptop-repo-copy-and-test-paths]],
[[qwen-gtt-and-queue-decisions]].
