# LAN resource bounds

The doctrine in `AGENTS.md` states the rule and this file carries the mechanism, the measurements, and the evidence paths behind it in full.

An open household-LAN launch admits any reachable peer to chat, and the
approval dialog gates search and image execution alone; the resource side of
that policy is a second set of bounds across the broker, the artifact
listener, the image service, the capacity policy, and the served page. Each
bound is opt-in through an environment variable a launch exports; the
component that enforces it reads a built-in default when the variable is
unset, so the mechanism is correct with no LAN launch script naming any of
them.

Prompt and output size at the model itself are two separate llama-server
mechanisms rather than one. `--n-predict` sets `params_base.n_predict`, which
`tools/server/server-context.cpp` (line 1718 at the pinned commit) applies
only where a request's own `n_predict`/`max_tokens` is `-1`; a request naming
its own larger value overrides the flag entirely, so `--n-predict` bounds an
unspecified request and never a request that names one. No server argument
bounds prompt tokens on their own: the server refuses a request only once its
prompt token count meets or exceeds the slot's context, which is `--ctx-size`
directly because `--parallel 1` is already fixed. `qwen-capacity-policy.sh`
therefore reads `QWEN_LAN_MAX_PROMPT_TOKENS` and `QWEN_LAN_MAX_OUTPUT_TOKENS`
as one combined budget rather than two independent ceilings: their sum clamps
`--ctx-size` downward (never past what the registry ceiling and validated
depth already admit), and the output bound also becomes `--n-predict`. Both
variables are required together, refused if malformed, and refused entirely
under router mode, since neither has a per-section preset field and
`common_preset::merge` would push one budget onto every served checkpoint the
way `--ctx-size` alone once did. Neither carries a default; the feature is off
until a launch sets both. `webui/index.html` is the other half of output
enforcement: it reads both bounds through the same query-parameter-then-meta-
tag cascade it already uses for the broker and artifact origins
(`?lanMaxPromptTokens=`/`?lanMaxOutputTokens=`, then
`qwen-lan-max-prompt-tokens`/`qwen-lan-max-output-tokens` meta tags, no
built-in default), counts the composed prompt through the existing
`./tokenize` route before sending, and refuses over the prompt bound with a
visible message rather than letting the server's own slot-context refusal
spend a prefill pass finding out. It narrows the request's own `max_tokens` to
the smaller of its 512-token default and the configured output bound, which is
what actually bounds output given the server's default-only reading of
`--n-predict`.

The checked-in page carries neither tag, because a bound is a property of a
launch rather than of the file, so the page the server serves is a copy the
launch writes. `remote/stage-webui-page.sh stage SOURCE OUT` copies the page
directory whole into a staging directory beside the target and renames it into
place, inserting the two tags after the `qwen-web-broker` meta from the same
`QWEN_LAN_MAX_PROMPT_TOKENS` and `QWEN_LAN_MAX_OUTPUT_TOKENS` the policy reads
and inserting none where the launch names none; a source page that already
carries either tag is refused, since the launch alone writes them.
`qwen-webui-session.sh` stages into `$QWEN_HOME/state/webui-served` ahead of
the server and records the source, the copy's SHA-256, and both bounds on a
`served_page` status line. `qwen-capacity-policy.sh` then reads the served
page's tags back through the same script's `read` command and requires them to
equal its own two bounds, `-` against `-` where the launch names none, so a
page stating another value, a bound the launch never set, or none where it set
one is refused ahead of the argv rather than handed to a browser as a
description of an enforcement the server does not perform. The tags describe
and the server enforces: a browser that strips or edits them gains nothing,
because `--ctx-size` and `--n-predict` are what refuse the request.
`write-deployment-receipt.sh` copies the `served_page` line into
`served_page_identity`, so a receipt binds the page a peer was handed to the
bounds the argv held. Router mode refuses both bounds, so its served page
carries no tag and the comparison holds `-` against `-`.

`remote/web-mcp/authorize-broker.py` metes `POST /grant` and
`POST /grant-image` per client address on top of the existing aggregate
`authorize-minute` bucket (`QWEN_WEB_AUTHORIZE_PER_MINUTE`, default 6, shared
by every caller): `QWEN_WEB_GRANT_PER_CLIENT_PER_MINUTE` (default 3) and
`QWEN_WEB_IMAGE_GRANT_PER_CLIENT_PER_MINUTE` (default 2) key a second fixed
window off `self.client_address[0]`, charged through the same
`server.Ledger.consume` the aggregate bucket uses, so a request spends the
aggregate bucket even where the per-client one then refuses. Every
rate-limited or budget-exhausted refusal carries `Retry-After`, computed from
the fixed window's own close. `image-service.py` runs one generation at a
time with no queue (`ImageService.handle_generate`'s non-blocking
`job_lock.acquire`), so a second unspent grant from one client only buys a
standing ticket ahead of every other peer's next job;
`QWEN_IMAGE_MAX_OUTSTANDING_GRANTS_PER_CLIENT` (default 1) refuses a further
`POST /grant-image` while an earlier grant to the same client has not reached
its own expiry, tracked in the broker's process memory rather than the
grants table, which carries no client column.

`image-service.py`'s `QWEN_IMAGE_MAX_PENDING` (default 1) states as policy
what the non-blocking job lock already does: a launch that names any other
value is refused at startup rather than being silently ignored, since the
service has no queue a configurable N could mean anything else against.
`GET /artifacts/<sha256>.<png|json>` is metered per client address by an
in-process `FixedWindowLimiter` (`QWEN_IMAGE_ARTIFACT_PER_CLIENT_PER_MINUTE`,
default 30) matching the broker's own window arithmetic; the meter runs after
the bearer check and before the name lookup, so an unauthenticated flood
always meets the constant-cost 401 rather than sometimes meeting a 429 that
would leak whether a client is already throttled, and `GET /health` stays
unmetered because `qwen-webui-session.sh` and `image-teardown-check.sh` poll
it during launch and teardown. The listener answers only the exact
`<sha256>.<png|json>` route pattern and never a directory listing; a listing
or traversal request meets the same 404 an unmatched route always has.
`QWEN_IMAGE_ARTIFACT_MAX_COUNT` (default 200) and
`QWEN_IMAGE_ARTIFACT_MAX_AGE_S` (default 604800, seven days) bound retention,
enforced by `ImageService.enforce_artifact_retention` at job completion.
Artifacts are content-addressed and two publication markers can name the same
`png_sha256` or `provenance_sha256` -- two identical requests, or a legacy
marker whose provenance file is named by the PNG's own digest -- so retention
computes two survivor digest sets by suffix from every marker that is not
being expired before it unlinks anything, and the job that just completed is
exempt from its own retention pass. The browser's correction-counter lineage
lives in `webui/index.html`'s own client state and is unaffected by
server-side expiry: an artifact that expires reads as gone on its card, and
the correction allowance the page already tracked does not move.

