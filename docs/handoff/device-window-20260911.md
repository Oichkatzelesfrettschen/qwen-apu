# Device window receipt: the Python supervisor serves on the appliance

Window `pyctl-live4`, opened 2026-09-11T14:04:02Z on the laptop through
`remote/run-device-window.sh`, torn down production, ran the command below
inside a git worktree of branch `serve-inference-core` with its own runtime
root, and relaunched production (`qwen-lan-launch.sh lan-authenticated
low-async`, `relaunch_status ok`).

The command: `bootstrap.py`, `native stage` from the deployed server and the
production tool builds, `install --bundle`, the three core checkpoints hard
linked from the production model store, `models verify --artifacts core`,
`deployment build` and `activate` from the deployed bundle's members, then
`serve --model qwen38-2b-distill --port 18099 --daemon`.

| Observation | Value |
| --- | --- |
| server niceness and core | nice 19, `Cpus_allowed_list: 0` |
| `/health` | `{"status":"ok"}` |
| chat reply to "Reply with exactly: control plane ok" | `control plane ok`, finish_reason stop |
| decode rate (server timings, 23 tokens) | 9.75 tok/s |
| prompt rate | 25.4 tok/s |
| `qwen-apu stop` | requested over the control socket |
| supervisor and server pids after stop | both gone |
| listeners on 18099 after stop | 0 |
| final `runtime.json` | state stopped, primary_failure null, restoration_failures empty |
| Vulkan workload lease after stop | free |
| control socket after stop | removed |

The decode rate sits beside the registry's 9.46 tok/s for the same checkpoint
under the shell chain, read as one arm rather than a comparison.

Three windows before this one failed on the command side and each relaunched
production, except the first: `run-device-window.sh` exports the production
root's `QWEN_HOME` into the command, so a worktree bootstrap refused a root
bound to another checkout until the command set its own; the whole window
had been wrapped in `nice -n 19`, so the production 4B reload ran at idle
priority beside the 16 GiB guest and missed the 300 second health deadline,
which is why the relaunch failed once and was restored by hand; the policy
refuses a symbolic link in a model path, so the shared checkpoints became
hard links; and a deployment name reused across windows refused. Each is a
rule the command now honors.
