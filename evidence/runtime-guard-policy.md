# Qwen Runtime Guard Policy

Long prompt ingestion uses two monitors because the unprivileged model process
and the privileged kernel log have different authority boundaries.

`remote/monitor-qwen-runtime.sh` samples every second on CPU 0 at nice 19
and idle I/O priority. It records server RSS and peak RSS, MemAvailable, swap-in
bytes, the highest hwmon temperature, GPU busy percentage, GTT and VRAM usage,
and current GPU memory and core clock states. It sends SIGTERM when:

- server affinity differs from CPU 0;
- server nice differs from 19;
- MemAvailable falls below 4 GiB;
- swap-in exceeds 64 MiB in one one-second sample;
- any readable hwmon temperature reaches 90 C; or
- sampled GPU busy percentage exceeds 75%; or
- the amdgpu busy, GTT, or VRAM telemetry paths become unreadable.

The 75% check remains a fail-closed aggregate ceiling. RADV global priority
orders competing queues but exposes no per-process utilization quota. The
native Vulkan patch synchronizes each bounded intra-graph submission and
inserts enough idle time for a 60% model duty cycle. The 15-point gap leaves measured capacity for the
compositor because the amdgpu busy counter covers the complete GPU. Source:
`evidence/vulkan-duty-cycle-policy.md`.

`remote/watch-qwen-kernel-hazards.sh` starts from the cached-sudo
`qwen-admin:admin.0` TTY and follows only new kernel records. It sends SIGTERM
on a ring timeout, GPU reset, VM fault, device loss, OOM, or oom-kill record.
The watcher retains every observed line and the termination reason.

GPU jobs run through a separate tmux server selected with
`tmux -L qwen-runtime`. The original `qwen-admin` tmux server predates the
render/video permission repair and lacks those supplementary groups. A new
session on its default socket would inherit that stale group set. The separate
runtime socket is created from fresh SSH and carries groups `video` and
`render`; the admin socket retains its per-TTY sudo ticket.

`remote/test-qwen-runtime-guards.sh` proves normal target exit, forced
termination when nice differs from 19, forced termination at 76% GPU busy, and
forced termination from a synthetic amdgpu ring timeout. All guard scripts
pass warning-clean ShellCheck and shell syntax validation. Production kernel
watching remains a benchmark-time gate because it requires the live server PID
and the cached admin TTY.
