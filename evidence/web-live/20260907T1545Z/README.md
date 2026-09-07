# The two ui-mediated rows against the live SearXNG instance

`remote/admit-web-router-live.sh` copies one `remote/web-profiles.tsv` row into
a ledger under its own output directory with `execution_policy` alone moved to
`validator-gated`, generates the preset under `QWEN_WEB_AUTHORIZER_READY=1`,
launches through `qwen-web-launch.sh`, replays every request the page makes with
curl on the router port, and then drives the served page through
`drive-fallback-page.py`. This run puts both `ui-mediated` rows through it:
`web-reader` on `qwen38-2b-distill` and `web-lookup` on `qwen35-08b`. The
shipped ledger is unedited; the harness's copy is what moved.

## Falsifiers, stated before the numbers

- A row whose curl replay fails any refusal check -- an ungranted call, a
  replayed grant, an argument outside the schema -- is refused a promotion
  whatever its served turn does.
- A row whose served page turn completes with a network-reaching call the model
  proposed, one human approval, and the result in the transcript is what an
  operator edit to `validator-gated` rests on. A turn where no dialog opens
  leaves the row unqualified for that edit, because the grant exists to gate a
  call the model actually proposes.
- A page request naming an origin other than the router or the broker refutes
  the containment the lane rests on, for either row.

## Result

| row | model | pass | observed | fail |
| --- | --- | ---: | ---: | ---: |
| `web-reader` | `qwen38-2b-distill` | 19 | 2 | 1 |
| `web-lookup` | `qwen35-08b` | 25 | 2 | 0 |

Both rows pass every mechanism check. The instance answered from `bing` in
2.61 s for `web-reader` and 0.74 s for `web-lookup`, a fetch by Result ID
returned 12,347 and 9,919 characters, the audit rows name the category and hold
no query text, the session secret and grant stay out of process images and
logs, and the teardown proves the router, child, broker, search instance,
secret, and all three ports absent. SearXNG cost 77.1 MB and 76.1 MB of
resident memory over five threads.

The rows separate on the served turn alone.

## The 2B is offered both tools and answers as though it had used them

`web-lookup` completes the turn: the 0.8B proposes `web_search_exa`, the dialog
opens naming the query, the publication interval, both domain lists, a result
count of 3, and the live-crawl reading, one grant is signed at the broker, the
call runs through `POST /tools` on the router, and the transcript carries a
`user, assistant, tool, assistant` sequence. Every page request names the
router or the broker origin.

`web-reader` fails `browser_turn_completed` on a 600 s timeout waiting for that
dialog. The page did its half: the request body carries both wrapped tools with
their full schemas and names `web-reader` as the model. The 2B distill proposed
neither, and its reply opens `## Results Summary` over `**Query:** "Vulkan
Compute Shader Subgroup Size"` and states what "the search results indicate",
including a `VULKAN_COMPUTE_SHADER_SUBGROUP_SIZE` parameter that does not
exist. No search ran, so the summary describes results the model composed.

The registry already grades this: `qwen38-2b-distill` carries
`raw_tool_selection` 2 of 10 and serves as the `fast-text` default. This run
measures the consequence for the web lane specifically -- offered a
network-reaching surface, the checkpoint neither reaches it nor declines it,
and answers in the register of a model that had. The failure is a property of
the checkpoint rather than of the lane, since the same preset, broker, instance,
and page carried the 0.8B's turn through to a signed grant minutes earlier.

## The operator edit this supports

`web-lookup` meets the standard the shipped `web-open` row met: a retained live
run under this harness with the served page proposing, approving, and executing
one call. An operator moving `remote/web-profiles.tsv`'s `web-lookup` row from
`ui-mediated` to `validator-gated` is a one-line edit resting on this record.

`web-reader` is not supported for that edit by this run. Its curl replay is
clean and its served turn proposes nothing, so a grant on that row would gate a
call the checkpoint does not make while the checkpoint answers as though it
had.

The edit is left to the operator; this window changed no `execution_policy`.

## Retained files

`webreader/` and `weblookup/` each hold `summary.tsv` (one row per check),
`run.log`, `browser-turn.json` (the page's own request log, transcript, and
dialog), the search and fetch responses, the audit rows, the generated preset
and profile copy, the launch, server, broker, instance, and teardown logs, and
the instance's resident cost. The signing keys and the broker state directory
are excluded from the copy. Paths name `$HOME` and the host reads
`qwen-laptop`.
