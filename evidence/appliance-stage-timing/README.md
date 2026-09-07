# Elapsed boundaries of the launch chain

The launch chain states deadlines and states no elapsed interval. The readiness
loop admits 1200 attempts at 0.1 s, `qwen-launch.sh` waits `QWEN_READY_ATTEMPTS`
of 3000, `monitor-qwen-runtime.sh` grants a two-second SIGKILL grace, and the
image tool call carries a 30000 ms timeout; every one of those is a configured
ceiling, so a retained `session.status`, telemetry record, or deployment receipt
describes what a launch was permitted rather than what it took. This directory
registers the record that carries the intervals themselves and the falsifiers
that would retire it.

## What writes what

`remote/stage-timing.sh` is the one writer of `$QWEN_HOME/state/stage-timing.tsv`
and the one reader of its shape. A row is `stage<TAB>NAME<TAB>BEGIN_NS<TAB>END_NS`
under a header naming the clock. The record is truncated by
`qwen-webui-session.sh` beside the state directory it lives in, ahead of every
stage, because the launcher appends after the session reports `state=running`
and the teardown appends after the session has gone.

| Stage | Begins | Ends | Written by |
| --- | --- | --- | --- |
| `server_exec` | the `run-qwen-capacity-server.sh` spawn | `/proc/PID/comm` holds the server executable's basename | `qwen-webui-session.sh` |
| `model_load` | that same exec observation | the readiness marker appears in `server.log` | `qwen-webui-session.sh` |
| `launch_readiness` | the `qwen-webui-control.sh start` call | `state=running` paired with a `/health` answer | `qwen-launch.sh` |
| `teardown_signal_to_exit` | the `qwen-webui-control.sh stop` call | the `pgrep -x llama-server` wait answers empty | `qwen-teardown.sh` |

`server_exec` ends on comm rather than on a log line because the chain replaces
its process image four times without changing the PID -- the capacity server
execs the policy, which execs the Vulkan environment wrapper, which execs the
exec guard, which execs `llama-server` -- so comm holding the server's own
basename is the observable that the last link ran. Both loading stages are
sampled by the readiness loop, so each carries that loop's 0.1 s granularity
rather than the stamp's.

`model_load` names what it measures only on the single-model path. The session
branches its readiness marker: `model loaded` for a single-model launch and
`starting server in router mode` under `QWEN_ROUTER=1`, where the router binds a
port and loads nothing until a request names a model. A router launch's
`model_load` therefore measures bind-and-wait, and the model load it does not
cover is what `remote/measure-model-switch.sh` measures instead.

The three stages nest: `launch_readiness` brackets the session, which brackets
`server_exec` and `model_load`. `remote/summarize-stage-timing.py` prints one
duration per stage and no total, because a sum counts the same wall clock
several times.

## The clock

`date +%s%N` is CLOCK_REALTIME, the clock `gate-cell-key.sh` already times cells
on. Realtime rather than monotonic is what makes a stamp the session took
comparable with one the teardown took in another process minutes later. Each
stamp forks `date`, about two milliseconds by the same measurement
`summarize-gate-timing.py` records, which sits four orders below a launch stage
and would dominate a millisecond one. The record names the clock in its header,
so a reader is never left inferring it.

## The switch harness

`remote/measure-model-switch.sh OUT [N]` alternates one-token requests between
two ids `GET /v1/models` returned, N times, default 20. `--models-max 1` keeps
one child resident, so the second id evicts the first: `server-models.cpp` logs
`evicting idle LRU name=A to make room for name=B`, `model name=B is not loaded,
loading...`, `waiting until model name=B is fully loaded...`, and `spawning
server instance with name=B on port N` across the transition, and the harness
cuts `server.log` at the byte offset it held before each request and retains the
matched lines beside the row.

Two bounds are stated rather than assumed. The request is unstreamed, so
`curl`'s `time_starttransfer` is the first byte of the whole buffered one-token
response rather than a token boundary inside a stream: the column is
`first_byte_s` and measures the complete request. `common/log.cpp` emits its `MM:SS.mmm.uuu`
prefix only under `--log-timestamps`, which is off by default, so a run against
an ordinary launch records `log_clock=absent` and attributes each matched line
to the request window rather than to a clock.

Quantiles are nearest-rank at the 1-based index `ceil(p/100 * n)` clamped into
`[1, n]`, so every printed quantile is an observed sample. The count prints
beside them, because p99 of twenty samples is the maximum.

## What is measured and what is claimed

Nothing here is measured yet. The mechanism is admitted on the workstation by
`remote/test-stage-timing.sh`, which drives the real `qwen-webui-session.sh` to
`state=running` against a fake capacity server and the real `qwen-teardown.sh`
against a fake control; by `remote/test-measure-model-switch.sh`, which drives
the switch harness against a fake router and a synthetic log; and by
`remote/test-summarize-stage-timing.py`, which fixes the quantile arithmetic
and the refusals. No appliance run has produced a
row, so this directory holds a registered prediction rather than a measurement,
and a rate quoted from it before that run would be fabricated.

The appliance run that closes it, in a device window with the router down:

```sh
remote/qwen-launch.sh low-async
remote/summarize-stage-timing.py stages "$QWEN_HOME/state/stage-timing.tsv"
QWEN_ROUTER=1 remote/qwen-launch.sh low-async
remote/measure-model-switch.sh "$QWEN_HOME/results/model-switch-$(date -u +%Y%m%dT%H%M%SZ)" 20
remote/qwen-teardown.sh
remote/summarize-stage-timing.py stages "$QWEN_HOME/state/stage-timing.tsv"
```

The teardown's row lands after the session has gone, so the second summary
reads the record the launch truncated and the teardown completed.

## Falsifiers

A run meeting any of these retires the mechanism or the claim it rests on
rather than being reported as noise.

- `server_exec` records `-` on a launch that reached `state=running`. comm never
  held the server's basename, so the exec observation reads something the chain
  does not produce and the stage measures nothing.
- `model_load` begins at the spawn rather than at the exec observation on such a
  launch. The fallback fired, which means the same thing.
- Two rows carry one stage name, or a row's end precedes its begin. Both are
  refused by the writer, so either reaching a record means a second writer
  exists and the truncation ordering the session asserts is wrong.
- A duration exceeds the wall time of the launch that produced it, or reads
  negative. An NTP step landed inside the window, which is the cost realtime
  buys, and a monotonic clock is the repair.
- `launch_readiness` reads shorter than the `model_load` it contains. The
  nesting the summary asserts is wrong.
- `measure-model-switch.sh` reports `matched_lines=0` on every row. The log
  patterns name strings this build does not emit, and the patterns rather than
  the switch cost are the finding.
- The stage timing record is absent after a launch that reached `state=running`,
  or `stage_timing=` names a path the record is not at. The session's truncation
  and the launcher's append disagree about where the record lives.

## Not run

No appliance measurement: the workstation carries no Raven2 device and this
branch is workstation-only. Every figure a later reader quotes comes from a
retained run under this directory, and none exists yet.
