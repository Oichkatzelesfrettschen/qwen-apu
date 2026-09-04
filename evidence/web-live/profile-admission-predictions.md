# Two more profiles through the live admission: what each is predicted to do

```text
status=registered ahead of the runs it judges
harness=remote/admit-web-router-live.sh OUTPUT_DIR PROFILE_ID, QWEN_ADMISSION_RESTORE=0
subject=web-reader (qwen38-2b-distill) and web-lookup (qwen35-08b Q8_0)
reference=evidence/web-live/20260903T0810Z/ for web-open (qwen38-4b-distill), 29 rows, 25 pass
page origin=http://127.0.0.1:PORT
```

## What the ledger says about these two rows

`remote/web-profiles.tsv` carries both at `execution_policy=refused`, which
emits nothing, and the harness writes its own one-row ledger under its output
directory with that field alone moved to `validator-gated`. Both rows carry
`web_mode=ui-mediated` where `web-open` carries `validator-gated`.
`remote/build-web-presets.sh` reads `web_mode` into a discarded variable at its
ledger loop, so `execution_policy` alone decides emission and a `ui-mediated`
row under a `validator-gated` execution policy emits a section carrying
`LLAMA_ARG_MCP_SERVERS_CONFIG` exactly as `web-open` does. A generation against
a one-row ledger confirms it for both profiles ahead of any device time:

```text
web-reader   LLAMA_ARG_MCP_SERVERS_CONFIG set, LLAMA_ARG_TAGS = web-research,validator-gated
web-lookup   LLAMA_ARG_MCP_SERVERS_CONFIG set, LLAMA_ARG_TAGS = web-research,validator-gated
```

The consequence for the checked-in ledger is stated rather than acted on: an
operator moving either `execution_policy` to `validator-gated` on the strength
of a retained run leaves `web_mode` naming a path the row no longer takes, so
the edit moves both columns or neither.

## The predictions

| profile | model | `raw_tool_selection` | curl-replay arms | served-page proposal |
| --- | --- | --- | --- | --- |
| web-reader | qwen38-2b-distill | 2/10 | pass | predicted to fail, prose in place of a tool call |
| web-lookup | qwen35-08b Q8_0 | 9/10 | pass | predicted to pass, one fetch |

The curl replay sends the tool call itself, so the model decides nothing there
and the preset, broker, grant, search, fetch, audit, secret-hygiene, teardown,
and absence arms are predicted to pass on both rows the way they passed for
`web-open`. The one arm a model can fail is the served page, where the
checkpoint must emit a `tool_calls` object of its own.

`evidence/image-appliance/paired-review-admission/` measured the 2B distill
answering in prose where the 4B distill proposed a schema-valid call in every
run, which is what its 2/10 tool-selection grade states. The prediction for
`web-reader` follows that measurement into this lane, and a schema-valid
`web_search_exa` call from the 2B refutes it: the grade would then be
category-specific rather than a property of the checkpoint's emission.

`web-lookup` carries `max_fetches=1` and `multi_source=no`, so the emitted
budget grants one retrieval where `web-open` grants two. A page turn spending
two fetches refutes the budget's reach into the emitted configuration.

## Falsifiers

| observation | reading |
| --- | --- |
| a curl-replay arm fails on either profile where it passed for web-open | the harness or the serving path depends on the checkpoint, which the fake twin denies |
| the 2B emits a schema-valid tool call | the 2/10 grade does not predict emission in this lane; both the prediction and the grade's scope are wrong |
| the 0.8B answers in prose | a 9/10 grade fails to predict emission, and the grade orders neither direction |
| a page request reaches an origin other than the router and the broker | the page composed a request the design forbids |
| the search returns fewer results than `minimum_results` with no fallback query | the instance answered short and the fallback rule did not fire |

## The page origin

`remote/web-mcp/drive-fallback-page.py` driven from the laptop's own headless
Chromium against `hp14-dk1xxx.local` made zero page requests earlier on
2026-09-03 while the same driver from the workstation completed a full search
turn against the same address. The cause is unmeasured. Both runs here use
`http://127.0.0.1:PORT` as the page origin on the laptop, and the run record
states which origin the driver received.
