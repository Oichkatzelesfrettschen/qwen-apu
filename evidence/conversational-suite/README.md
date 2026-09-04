# Conversational suite: web-off against web-on

`remote/run-conversational-suite.sh` benchmarks every servable checkpoint
through the graded suite twice: once through the API with the web lane off
(`remote/run-quality-suite.py`, the path `remote/run-quality-roster.sh`
already runs), and once through the served fallback page with the per-turn
Web toggle on (`remote/run-conversational-web-arm.py`, driving
`remote/web-mcp/drive-fallback-page.py`). No arm has run on the appliance yet;
this registers the design and its falsifiers ahead of that run.

## What web-on is expected to change

The suite's `web_current` category (`web-01` through `web-10` in
`remote/quality-suite.tsv`) asks for one already-resolved dated fact per row
-- a software release date or an LTS codename -- pinned to the event rather
than to "the latest version," so the expectation stays true forever once the
event happened and a retained record stays comparable across every later run.
Each row carries the `web:` attachment, which names nothing and exists to
mark the row for this harness's grading, not to change the request the API
arm sends.

**Falsifier for the design as a whole:** the web-off arm is expected to fail
every `web_current` row (`correct_on_completed` restricted to that category
reads 0 for every checkpoint under a training cutoff earlier than the pinned
events), and the web-on arm is expected to raise it, because a proposed and
approved search reaches the event through SearXNG rather than through the
checkpoint's own weights. A `web_current` row that the web-off arm passes is
not a working grader; it reports that the fact reached the checkpoint's
training data, and the row's ground truth needs repinning to a later event
before the next run -- an operator step this design calls for rather than an
automatic one, since no offline check here can tell "the model memorized this"
apart from "the model reasoned to the right date by chance." A row that both
arms fail names either a broken grader (check the `contains_all` pattern
against a hand-run search) or a search that proposed, was approved, and still
returned nothing the model could read (check `results_produced` on that row's
web-on record).

## What web-on must leave unchanged

The other 75 rows -- arithmetic, word problems, code, format, long-context
retrieval, termination, vision, tool selection, and photo interpretation --
carry answers the model either knows or does not from its own weights and
training data; nothing about them requires the network. The web-on arm is
expected to move their pass/fail outcomes by at most the ordinary
run-to-run noise this repository already documents for a graded suite (the
warm/cold prefix-reuse effect CLAUDE.md's evidence-discipline section
describes on `arith-05`), not systematically. A category outside
`web_current` whose `paired_delta_mean` (from
`remote/summarize-conversational-suite.py`'s per-model report) departs from
zero by more than that noise band is the falsifier for "the page performs no
retrieval a text row needs": either the model proposed and ran a search on a
row that did not call for one (check `search_proposed` on that row's web-on
record), or the page's own turn shape -- system prompt, template, or a
carried-over tool listing -- changed what a text row's answer looks like
independent of any search.

## What the web-on arm does not attempt

Two attachment kinds have no transport through the page's turn driver:
`image` (vision and photo rows) and `tools` (tool-selection rows). The
driver types one text prompt into the chat box and clicks Send; it offers no
path to attach a fixture image or declare a tool set the way
`remote/run-quality-suite.py`'s direct API call does. `run-conversational-web-arm.py`
records those rows under `skipped` with the reason
`attachment kind KIND has no transport through the served page's turn
driver`, rather than driving them through an unrelated transport and grading
a result that measures something else. This is a scope cut named rather than
made silently: 65 of the 85 rows (75 original plus 10 `web_current`) reach
the web-on arm; the remaining 20 (10 `vision`, 10 `tool`, and the `photo`
category's rows, all attachment kind `image` or `tools`) run in the web-off
arm alone.

## Row order and comparability

Both arms grade the suite's rows in the row file's own order.
`remote/run-quality-suite.py` sends one bare user message per row with no
carried conversation history, and `run-conversational-web-arm.py` opens a
fresh browser page per row for the same reason -- an explicit-history
carryover would confound the web-on delta with a multi-turn effect the
web-off arm never runs. What both still share is a server-side effect
CLAUDE.md's evidence-discipline section already measured: a warm KV cache or
prefix reuse can move a row's answer depending on what ran immediately before
it (`arith-05` answers 37 cold and 23 warm after the `screen` block).
Running both arms in the row file's own order keeps that effect identical
between them rather than introducing a second, uncontrolled ordering
difference.

## What the harness measures per row and cannot measure

The web-on arm reads three claims off the page's own transcript after each
turn: `search_proposed` (the approval dialog opened), `search_approved`
(this harness always approves the one dialog it sees, auto-approving the way
`remote/admit-web-router-live.sh` does for its own admission), and
`results_produced` (the retained `tool`-role message carries no refusal
marker -- `"did not run"`, `"refused"`, `"grant"`, `"expired"`, `"exceeded"`,
`"not authorized"`, `"unavailable"`, `"error"`). `results_produced` is a text
heuristic over the page's own transcript rather than an HTTP status the
driver has no way to read, and a legitimate answer that happens to discuss
one of those words in its own prose would misclassify; a run that reports an
unexpected `results_produced=False` should be checked against the row's
retained `content` before it is read as a provider failure.

`truncated` is not measurable on the web-on arm: the page's transcript
carries no `finish_reason`, so every web-on record reads `truncated=False`
regardless of whether the reply was cut at a token budget. A `termination`-category
row is therefore graded the same way on both arms (the `nonempty` grader
reads presence, not length) but a web-on truncation would not be
distinguishable from a short complete answer the way the API arm's
`finish_reason` lets it be.

## Device command

The web-on arm needs one router serving the whole roster with the web
section armed, which is the unified launch rather than the single-profile
`qwen-web-launch.sh` (that path serves one profile at `QWEN_ROUTER_MAX=1` and
cannot also serve every other registry row the web-off arm grades):

```sh
openssl rand -hex 32 >~/qwen-webui-state/api.key
chmod 600 ~/qwen-webui-state/api.key
QWEN_ROUTER=1 QWEN_WEB_AUTHORIZER_READY=1 \
QWEN_WEB_TOKEN_KEY_FILE=$HOME/qwen-web-token.key \
    ~/qwen-laptop-setup/remote/qwen-launch.sh low-async

QWEN_WEB_API_KEY_FILE=~/qwen-webui-state/api.key \
    ~/qwen-laptop-setup/remote/run-conversational-suite.sh \
    ~/qwen-conversational-roster
```

`run-conversational-suite.sh` checks the router's own served roster
(`GET /v1/models`) before it spends any device time: a registry row the
listener does not hold refuses the whole run the way
`run-quality-roster.sh` already does, and a checkpoint whose
`remote/web-profiles.tsv` row authorizes a section that the listener does not
serve (the launch ran without `QWEN_WEB_AUTHORIZER_READY=1`, or the preset
predates the ledger row) records `web_on=unavailable
reason=authorizer_not_ready` per model rather than failing the run.

The manifest's `web_on_status` column carries the arm's actual outcome
rather than only the ledger join's answer: `unavailable` where no web
section reaches the model (the resolver's reason names why, `web_on_json`
reads `-`), `completed` where the web-on arm ran every eligible row and
wrote its record, or `failed` where the arm exited nonzero on a transport
error partway through. `run-conversational-web-arm.py` writes its output
file after the row loop regardless of the arm's own exit status, so a
`failed` arm's partial record still folds into `conversational-summary.tsv`
labelled `failed` rather than being read as a completed comparison or
silently dropped.

## What is tested without a device

`remote/test-quality-suite.py` checks the new `web:` attachment parsing, the
`web_current` cross-checks, and that every `web_current` row still clears the
suite's existing invariants (anchored regex, non-blank expectation, the
refusal-reply check). `remote/test-conversational-suite-units.py` checks
`remote/resolve-web-profile.py`'s four unavailability reasons and its one
success path against a fixture ledger, `remote/run-conversational-web-arm.py`'s
approval accounting and grading against
`remote/test-fixtures/fake-page-driver.py` (a canned-report stand-in for the
browser), and `remote/summarize-conversational-suite.py`'s mean, p90, and
paired-delta arithmetic against hand-computed fixture records.
`remote/test-run-conversational-suite.sh` drives the shell orchestrator
itself against `remote/test-fixtures/fake-chat-router.py` (a minimal HTTP
stand-in for the router's `/v1/models` and `/v1/chat/completions`, narrower
than `remote/test-fixtures/fake-router-server.py`'s image-admission preset
and tool-proxy shape, which the web-off arm's plain graded rows do not
exercise) and proves the manifest and summary record `web_on=unavailable
reason=no_web_profile` for a model absent from the ledger, with no page
driver invoked. None of the four exercise a real browser, a real router
child, or the live web-on arm end to end; that proof is the device command
above, retained under a later `evidence/conversational-suite/` run directory
once one executes.
