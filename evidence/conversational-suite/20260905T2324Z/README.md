# Conversational suite on the appliance: thirteen web-off arms, one web-on arm

`remote/run-conversational-suite.sh` graded every servable checkpoint through
`remote/quality-suite.tsv` against the running LAN appliance -- the
`lan-authenticated` router on port 42069 with the broker on 42070, the
`web-open` section armed, and the SearXNG instance live -- and drove the one
checkpoint a `validator-gated` web section reaches through the served page with
the per-turn Web toggle on. The design and its falsifiers are registered in
`evidence/conversational-suite/README.md`; this directory holds the first run
that executed them.

`nice 19` applies to the harness process. Inference ran in the resident
`llama-server` the launch already owned, at that server's own priority, so the
priority states what the grading harness cost the machine rather than what the
decode ran at.

## What ran, and from where

The appliance's checkout stayed read-only for this run, so the branch's own
`remote/` and `webui/` were staged under the runtime root at
`$QWEN_HOME/results/conversational-20260905T1900Z/tree` and run from there with
`QWEN_HOME` exported to the appliance's real root. The staged
`run-conversational-suite.sh` hashes to
`822ed8cdac8471bc81fdee293f53e625605996066354e67973ac2fc6e2b00eb0`, the branch
copy before the summarizer repair below.

Three defects in the harness surfaced against a LAN-bound appliance and are
repaired on the same branch:

`run-conversational-suite.sh` composed both origins from `127.0.0.1` and read
`GET /v1/models` with no bearer. `QWEN_WEB_LAN=1` binds the router, the broker,
and the artifact listener to one routable literal and `QWEN_REQUIRE_API_KEY=1`
accompanies it, so the loopback origin reached nothing and the roster read
answered 401. `QWEN_SERVER_HOST` and `QWEN_WEB_BROKER_HOST` now carry the host,
the roster read presents the bearer through a curl configuration on stdin, and
the same bearer reaches `run-quality-suite.py` through the `QWEN_API_KEY` it
already reads.

`run-conversational-web-arm.py` executed `remote/web-mcp/drive-fallback-page.py`
by its path, and that file is tracked at mode 644, so the arm raised
`PermissionError` on its first row and wrote no record. It now runs the driver
through this interpreter where the mode bit refuses it, the way
`remote/admit-image-router.sh` already names `python3` ahead of the same path.

`summarize-conversational-suite.py` then refused the whole thirteen-model
report, because a `failed` arm that raised ahead of its row loop names a record
that does not exist. A `failed` arm with no record now folds in with `-` web-on
columns and `record_absent` on its reason; a `completed` arm claims a record and
keeps the refusal.

`conversational-summary.tsv` in this directory is the repaired summarizer run
over the records the sweep already wrote, in `summarize.log`.

## Web-off, thirteen checkpoints

94 rows per checkpoint, thinking off, 1024-token budget, 24000-character
long-context rows, graded in the row file's own order.

| Checkpoint | passed | correct_on_completed | transport errors | wall s |
| --- | ---: | ---: | ---: | ---: |
| qwen35-4b-base | 78/94 | 0.830 | 0 | 3794.3 |
| lfm25-vl-16b | 69/94 | 0.734 | 0 | 1406.8 |
| qwen35-2b | 64/94 | 0.681 | 0 | 1388.5 |
| qwen38-4b-distill | 56/94 | 0.747 | 19 | 2912.9 |
| qwenseer-2b | 49/94 | 0.662 | 19 | 1258.0 |
| qwen35-2b-heretic | 48/94 | 0.649 | 19 | 2035.1 |
| qwen35-2b-unredacted | 45/94 | 0.595 | 19 | 1053.4 |
| qwen35-08b-unsloth-unc | 44/94 | 0.587 | 19 | 492.3 |
| qwen35-2b-hauhau | 43/94 | 0.573 | 19 | 1079.2 |
| qwen38-2b-uncensored | 41/94 | 0.554 | 19 | 1739.9 |
| qwen35-08b | 40/94 | 0.533 | 19 | 428.9 |
| qwen35-08b-f16 | 40/94 | 0.533 | 19 | 497.5 |
| qwen38-2b-distill | 40/94 | 0.548 | 19 | 1768.0 |

The three arms reading zero transport errors are the three checkpoints whose
own directory holds a projector. The other ten each answer HTTP 500 on the 19
rows carrying an `image` attachment -- 10 `vision` and 9 `photo` -- because
`remote/select-projector.sh` binds the search to the model's own directory and
a text-only checkpoint has none, so `run-quality-suite.py` records
`served=None` with a transport error and the arm's status reads `failed`. That
is `run-quality-roster.sh`'s existing behavior without `--omit-images` rather
than a fault of this harness, and it is one mechanism rather than 190 findings.
`correct_on_completed` excludes those rows from its denominator and is the
cross-checkpoint column to read; `passed` out of 94 and `empty_answer_rate`
include them and are comparable only inside the projector-carrying group or
inside the text-only group.

Two pairs the registry already accounts for appear here as measurements.
`qwen35-08b` at Q8_0 and `qwen35-08b-f16` land on the same 0.533, one row apart
across every category, which is the 16-bit rung of one checkpoint reading as
the same model. `qwen38-2b-distill` and `qwen38-2b-uncensored` both grade 2/10
on the `tool` category against `qwen38-4b-distill`'s 9/10 and
`qwen35-4b-base`'s 10/10, which is the `raw_tool_selection` grade
`remote/models.tsv` already carries for those rows.

Every checkpoint scored 0/10 on `web_current` web-off except `qwen35-4b-base`,
which passed `web-10` (the GNOME 47.0 release date) and failed the other nine.
The design's web-off prediction is met on twelve of thirteen. That one pass is
the operator step `evidence/conversational-suite/README.md` calls for: the row
reports that its fact reached that checkpoint's training data rather than that
the grader is broken, and repinning it to a later event belongs to an operator
before the next run.

## Web-on, one checkpoint

`web-open` is the one row of `remote/web-profiles.tsv` whose
`execution_policy` reads `validator-gated`, the launched preset's head marker
reads `# qwen_web_sections=web-open`, and `remote/resolve-web-profile.py`
resolves exactly one model to it: `qwen38-4b-distill`. The other twelve
checkpoints record `unavailable` -- five `execution_policy_refused` where a
ledger row names the model and reads `refused`, seven `no_web_profile` where no
row names it -- which is the ledger join working rather than twelve broken
arms.

`4b-rerun/` holds that arm and the web-off arm it is paired against. Both come
from one invocation of the harness after the mode-bit repair, because the
sweep's own web-on arm raised before its first row; the sweep's 4B web-off arm
is retained too, six hours earlier, and the two are not paired with each other,
since a comparison on this machine is read inside one sweep.

| Arm | rows | correct_on_completed | mean wall s |
| --- | ---: | ---: | ---: |
| web-off | 94 | 0.747 | 33.71 |
| web-on | 65 | 0.746 | 185.58 |

29 rows carry an `image` or `tools` attachment and have no transport through
the page's turn driver, so 65 of 94 reach the web-on arm. The paired delta over
all 65 shared rows is -0.046 with a paired count of 65.

**The web-on arm proposed a search on one row of 65.** `tool_proposal_rate`
reads 0.015: only `web-10` opened the approval dialog, on nine other
`web_current` rows the model answered from its own weights with the search
tools offered, and `web_current` moved from 0/10 web-off to 2/10 web-on with
neither pass involving a search. That is a tool-selection finding about the 4B
distill rather than a retrieval result, and it stands beside the same
checkpoint's 9/10 `raw_tool_selection` grade on the suite's own `tool` rows:
the model emits a well-formed call when a row's request declares a tool set and
declines to reach for one when a dated fact is asked of it in prose.

The one proposal was well formed. The dialog named query `GNOME 47.0 release
date`, any publication date, every domain, 3 results, and the provider's own
cache decision; the harness approved it; and the broker ledger records the
grant consumed at 09:05:21Z and a `search` operation completing `success` in
1752 ms with 3 results from `bing,google`, 20 usable results, and 2285 returned
characters. The turn then produced an empty reply, and the record reads
`results_produced=False`. Those two disagree, and the ledger is the authority:
the search ran and returned. The audit's next row is a `fetch` at 09:08:42Z
reading `authorization_denied` against a search whose `fetches_used` is 0 of 2
allowed and whose grant had not expired, so the wrapper refused a fetch the
page proposed after a successful search and the turn ended with no assistant
content. Why that fetch failed its Result ID check is unresolved here; the
falsifier is one repeat with the page's own tool message retained, which
`run-conversational-web-arm.py` folds into `results_produced` without keeping
the text `evidence/conversational-suite/README.md` already warns a reader to
check.

All five `long_context` rows failed the web-on arm as `TimeoutError: waited
300s for the approval dialog or the turn to end`, against 5/5 passing web-off
in the same invocation. A 24000-character prompt prefills longer than the
driver's 300 s dialog-or-turn ceiling on this machine, so those five report the
timeout rather than the checkpoint. Raising `QWEN_CONVERSATIONAL_DIALOG_TIMEOUT`
past the measured prefill is what makes that category comparable across the two
arms; the paired delta above includes the five as web-on failures and is
therefore a lower bound.

## Files

`manifest.tsv` and `conversational-summary.tsv`/`.md` are the harness's own
report over the thirteen arms. `MODEL.web-off.json` retains every row's
request, reply, and grade; `MODEL.web-off.log` is that arm's stdout.
`sweep.log` is the whole run, `summarize.log` the repaired summarizer over it.
`4b-rerun/` holds the paired invocation with its own manifest, summary, and
both arms' records, and `4b-rerun/qwen38-4b-distill.web-on.json` carries the
approval dialog's fields per row.

The records carry no bearer, no session secret, and no grant: the web-off arm
sends its bearer in a header the record never holds, and the web-on records
retain the dialog's parsed fields rather than the token signed over them. The
git copies replace the appliance hostname with `qwen-laptop` and the home
prefix with `$HOME`.
