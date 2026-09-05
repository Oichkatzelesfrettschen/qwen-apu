# A request cancelled during a child load left the router's one slot unclaimable

`evidence/deployment-epochs/main-e909cfc-r1/README.md` records the defect on
the appliance: the page cancelled a request 0.4 s into the `lfm25-vl-16b`
child load, the child finished loading 3.2 s later, and the verifier's next
request, naming `qwen38-2b-distill` under `--models-max 1`, waited its whole
700 s curl timeout while a fresh request sent afterward spawned within 13 s.
This directory retains the deterministic reproduction on the workstation, the
trace that locates the transition, and the repaired run.

## The fixture

`remote/test-router-cancelled-load.sh` runs a CPU-only `llama-server` built
from the pinned commit with the production series, over the 260K-parameter
TinyStories checkpoint `remote/fetch-test-model-stories260k.sh` pins, with two
preset sections naming that one file. The child is a real router child held at
an explicit barrier: `remote/test-fixtures/router-child-bind-barrier.c` is an
`LD_PRELOAD` shim that interposes `bind(2)` only in a process carrying
`LLAMA_SERVER_ROUTER_PORT`, writes `held-<port>` and waits for
`release-<port>`, and the child binds its listener ahead of loading the model
and ahead of the READY line it prints to the router. The test therefore
cancels the initiating request while the load is provably in flight, submits
the follow-up and reads the router's own `queued at position` line before it
releases the hold, and bounds the follow-up with a deadline over a state that
never changes rather than a sleep asked to land inside a race. Three cases run
against a fresh router each: a follow-up naming the second section, one naming
the loading section, and one where the held child's bind fails.

## The trace

`unpatched-different-model-router.log` holds the transition, with timestamps
from the router's own log:

| t | line |
| --- | --- |
| 0.111 | `model name=model-a is not loaded, loading...` and the spawn |
| 0.311 | `request cancelled while waiting for model name=model-a` |
| 0.321 | `models_max reached, request for name=model-b queued at position 1` |
| 0.268 (child clock) | model-a's child initializing, then LOADED |
| 30.396 | `request cancelled while waiting for model name=model-b`, the test's deadline |

`server_lru_sched::on_model_idle` is the one path that gives a slot to the
queue, and `proxy_request`'s cleanup lambda is its one caller, firing when a
proxied request ends and `req_count` reaches zero. A child loaded by a request
that was cancelled before proxying never carries a request, so that path never
fires for it. The queued request picked its victim once, at join time, when
`pick_victim` refused model-a as `!is_ready_or_sleep()` because the child was
still loading; the loop that waits afterward retries `try_claim`, which needs
capacity, and never re-picks. The observed wait is a slot hand-off that has no
sender rather than a lost notification or a generation mismatch, and the
patched run's line 61, `model name=model-a went idle, giving up its slot to a
queued request`, is the hand-off the repair adds.

## The repair

`patches/llama-router-cancelled-load-idle.patch` adds two things to
`server-models.cpp`. `n_waiting` counts the requests inside
`ensure_model_ready` waiting for each model, kept beside `mapping` because
`load()` replaces the instance it would otherwise live in, and `pick_victim`
and `on_model_idle` treat a model with a waiter as busy, since the request
that waited for it is about to proxy to it. `release_if_idle` then runs where
a child reaches READY and where a waiter leaves by exception: a model that is
up with no request on it and no waiter for it hands its slot to the queue
through the existing `on_model_idle`. The same-model follow-up is a waiter and
keeps the load, and a failed child leaves through the existing UNLOADED path.

The window between `ensure_model_ready` returning and `proxy_request`
incrementing `req_count` is unchanged by this patch: a request that finishes
on another model inside it could evict the model the first request is about
to use, and it could before the patch. It is stated here as a limit rather
than repaired, since the retained defect is a different transition.

## Results

| build | different-model | same-model | load-failure |
| --- | --- | --- | --- |
| pinned commit plus production series | fail: no second child, follow-up ended at the 30 s deadline, model-a loaded and model-b unloaded | pass | pass |
| the same plus the candidate patch | pass: model-a gave up its slot, model-b spawned and answered | pass | pass |

`unpatched-results.tsv` and `patched-results.tsv` are the rows;
`patched-different-model-router.log` is the repaired trace. The candidate
patch replays under `QWEN_LLAMA_CANDIDATE_PATCHES=1
QWEN_LLAMA_CANDIDATE_SELECT=llama-router-cancelled-load-idle.patch` and
rewrites only `tools/server/server-models.cpp` and
`tools/server/server-models.h`. The appliance confirmation on the exact
patched executable, with no third request, router restart, device reset, or
model-stack change, is the arm that moves the row to `production`, and it is
recorded beside this file when it runs.
