# web-lookup against the live SearXNG instance: every arm passes, and the 0.8B proposes inside its budget

```text
harness=remote/admit-web-router-live.sh OUTPUT_DIR web-lookup, QWEN_ADMISSION_RESTORE=0
model=qwen35-08b Q8_0, context 8192 against validated_filled_depth 32768, no override
budgets=max_results 3, max_fetches 1, max_chars_per_fetch 12000, multi_source no
search=searxng at http://127.0.0.1:8888, primary qwen-open, fallback -, minimum 1
prediction registered ahead of the run in ../web-live/profile-admission-predictions.md
28 rows: 24 pass, 3 observed, 1 skipped, 0 fail
```

The checked-in `remote/web-profiles.tsv` row stayed at `execution_policy=refused`; the
harness wrote its own one-row ledger with that field alone moved to `validator-gated`.
The appliance was down when the run started, so `ordinary_router_recorded` reads
`running=0` and `ordinary_restore` is skipped by `QWEN_ADMISSION_RESTORE=0`.

## The served page turn

The 0.8B emitted a schema-valid call on its first turn:

```json
{"name": "web_search_exa", "arguments": "{\"query\":\"vulkan compute shader subgroup size\",\"max_results\":3}"}
```

The proposed `max_results` is 3, which is this profile's own ledger budget rather than
the tool schema's ceiling or the model's guess, so the emitted configuration's budget
reaches the model's proposal through the tool listing. One grant was signed at the
broker, one search ran on the router port under it, every page request named
`http://127.0.0.1:8080` or `http://127.0.0.1:8571`, the transcript carries the Result ID
and the `Sources: bing` line, and the answer cites the results rather than the model's
own memory:

```text
Based on the search results, **there is no public, widely documented standard or
official specification** that defines a "vulkan compute shader subgroup size."
```

That answer is wrong about the API -- `VK_EXT_subgroup_size_control` and the
`subgroupSize` property are both specified -- but it is wrong by reading three
metasearch hits that did not carry the answer, which is a retrieval-quality result and
not a tool-selection one. Three results survived canonicalization against a
`minimum_results` of 1, so the fallback category was not queried, which is what a `-`
fallback states.

The `max_fetches=1` budget was never exercised by the page, because the model answered
from the search result highlights and proposed no `web_fetch_exa` call. The curl replay
spent the one fetch instead, returning 12,347 characters in 2 s.

## Every other arm

The emitted section carries the four search-policy values read back out of the
configuration it names, the launch owns one loopback SearXNG instance and proves
`GET /healthz` ahead of the capacity server, `GET /tools?model=web-lookup` enumerates
both tools on the router port, the broker signs one 447-byte single-use grant, the
259-row audit names `category=qwen-open` and holds no query text, no key or grant or
session secret reaches a process image or a log, and teardown proved the router, child,
broker, search instance, secret, and all three ports absent.

The instance cost 77,536 KiB and 5 threads after the turn against
`../web-live/20260903T0810Z/`'s 78,720 KiB, and 103 CPU ticks over the whole run.

## Falsifier outcomes

| falsifier | outcome |
| --- | --- |
| a curl-replay arm fails where it passed for web-open | held: every one passed |
| the 0.8B answers in prose | not met: it emitted a schema-valid call on its first turn |
| a page turn spends two fetches | not met: it spent zero, so the one-fetch budget is untested by the page |
| a page request reaches an origin other than the router and the broker | not met |
| the search returns fewer than `minimum_results` with no fallback query | not met: 3 against a minimum of 1 |

## What the run leaves for an operator

This profile met every check the harness makes, including the served page turn, which is
the arm `web-reader` failed on the same day against the same instance. The two runs
separate the serving path from the checkpoint: the path is identical and the emission is
not, which is what `raw_tool_selection` 9/10 against 2/10 states.

`web-lookup` carries `web_mode=ui-mediated`, so a promotion of its `execution_policy` to
`validator-gated` moves that column too or leaves the row naming a path it no longer
takes. `remote/build-web-presets.sh` reads `web_mode` into a discarded variable, so the
generator will not catch the divergence; this run's ledger copy moved
`execution_policy` alone, which is the harness's own rule.

The checked-in row stays `refused` here. One broker signs for one profile, so the ledger
admits one emitting section at a time and this run states what an operator would be
promoting rather than performing the promotion.

## The page origin

`remote/web-mcp/drive-fallback-page.py` received `http://127.0.0.1:8080` and completed a
full turn from the appliance's own headless Chromium. The zero-page-request observation
recorded earlier on 2026-09-03 was against the `qwen-laptop.local` name, so it is a
property of that address rather than of the driver or the host. The cause remains
unmeasured.

## Redaction

`run/http/4-session.response` and `run/http/5-grant.response` carried the broker's raw
session secret and the signed single-use authorization it issued, and the search and
fetch requests echoed the grant. Both are credentials, so both are replaced here with
`<session-secret-redacted>` and `<grant-redacted>`.
`PRE_SANITIZATION_SHA256SUMS` digests the bytes as the harness wrote them, ahead of this
redaction, so what was removed stays checkable against a re-run without being
republished. Result IDs are left as recorded, for the reason the `web-reader` record
states.
