# web-reader against the live SearXNG instance: the serving path holds, the 2B proposes nothing

```text
harness=remote/admit-web-router-live.sh OUTPUT_DIR web-reader, QWEN_ADMISSION_RESTORE=0
model=qwen38-2b-distill, context 32768 against validated_filled_depth 32768, no override
budgets=max_results 5, max_fetches 2, max_chars_per_fetch 12000
search=searxng at http://127.0.0.1:8888, primary qwen-open, fallback -, minimum 1
prediction registered ahead of the run in ../web-live/profile-admission-predictions.md
23 rows: 18 pass, 3 observed, 1 fail, 1 skipped
```

The checked-in `remote/web-profiles.tsv` row stayed at `execution_policy=refused`; the
harness wrote its own one-row ledger under `run/web-profiles.tsv` with that field alone
moved to `validator-gated`. The appliance was down when the run started, so
`ordinary_router_recorded` reads `running=0` and `ordinary_restore` is skipped by
`QWEN_ADMISSION_RESTORE=0`: this campaign owns the machine and a later campaign brings
the site back.

## What passed

Every arm the curl replay drives passed, in the same shape
`../web-live/20260903T0810Z/` measured for `web-open`: the emitted section carries the
four search-policy values read back out of the configuration it names, the launch owns
one loopback SearXNG instance and proves `GET /healthz` ahead of the capacity server,
`GET /tools?model=web-reader` enumerates `web_fetch_exa,web_search_exa` on the router
port, the broker signs one 447-byte single-use grant, the search returns 5 results from
bing against `minimum_results` 1 in 1 s, the fetch by Result ID returns 12,347
characters in 1 s, and the 259-row audit names `category=qwen-open` while holding no
query text. Teardown proved the router, child, broker, search instance, session secret,
and all three ports absent, and no key, grant, or secret appears in a process image, a
log, or the status file.

`web-open`'s own run recorded its fetch failing on the provider's 20-second deadline.
This run's fetch completed in 1 s against the same route, so that failure was the origin
rather than the timeout stack.

## The one failure, and why it was registered ahead of the run

```text
browser_turn_completed  fail  TimeoutError: waited 600s for the approval dialog
```

The page composed `body.tools` from `GET /tools?model=web-reader&autoload=true` and sent
the turn with both tools attached, at `max_tokens` 512 and thinking off. The checkpoint
answered in prose and emitted no `tool_calls` object, so no dialog ever opened and the
driver's 600-second dialog deadline ended the arm. `browser-turn.json` holds the request
that carried the tools and the reply that ignored them.

This is what `raw_tool_selection=2/10` states about this checkpoint, and
`evidence/image-appliance/paired-review-admission/` measured the same behavior in the
image lane, where the 4B distill proposed a schema-valid call in every run and the 2B
answered in prose. The prediction and its falsifier were registered before the run.

The reply's content is the sharper reading. Asked to search, the 2B wrote a confident
unsourced summary attributing Vulkan subgroups to "CUDA cores on NVIDIA GPUs" and
claiming "the programmer does not need to explicitly declare or manage subgroups", both
wrong about the API the question names. The failure mode is a plausible answer from
parametric memory rather than a refusal, which is exactly the case a retrieval tool
exists to cover and exactly the case a low tool-selection grade predicts.

## What the run leaves for an operator

The serving path is admitted for this profile and the checkpoint is not. Moving this
row's `execution_policy` to `validator-gated` would publish a section whose model never
reaches the network, so `web-reader` stays `refused` on the strength of this run rather
than in spite of it. Its `web_mode` reads `ui-mediated`, and
`remote/build-web-presets.sh` discards `web_mode` at its ledger loop while
`execution_policy` alone decides emission, so a later promotion moves both columns or
neither.

## Falsifier outcomes

| falsifier | outcome |
| --- | --- |
| a curl-replay arm fails where it passed for web-open | held: every one passed, and the fetch that failed there passed here |
| the 2B emits a schema-valid tool call | not met: it emitted prose, so the 2/10 grade predicts this lane |
| a page request reaches an origin other than the router and the broker | not met: the arm never ran, since no dialog opened |
| the search returns fewer than `minimum_results` with no fallback query | not met: 5 results against a minimum of 1 |

## The page origin

`remote/web-mcp/drive-fallback-page.py` received `http://127.0.0.1:8080`, which
`admit-web-router-live.sh` composes as its router origin. The zero-page-request
observation recorded earlier on 2026-09-03 was against the `qwen-laptop.local` name; this
run reached the page and issued requests from it, so the driver itself works from the
appliance's own Chromium over loopback and the `.local` failure is a property of that
address rather than of the driver. The cause remains unmeasured.
