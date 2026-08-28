#!/bin/sh
set -eu

# The fallback Web UI reaches the network through one human approval, and the
# two properties that make that true are absences a reading eye loses: the
# approval dialog offers ONCE and DENY alone, and no grant or session secret
# reaches browser storage. Grep asserts both against the served file, which
# needs no Node and no browser, so the gate runs wherever the tree is cloned.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
fallback_ui=$script_directory/../webui/index.html

# The per-turn toggle governs the tool list rather than the request text, so a
# turn run with it off carries no web tool for the model to propose.
grep -F '<input type="checkbox" id="web-tools">' "$fallback_ui" >/dev/null
grep -F "if (\$('#web-tools').checked) {" "$fallback_ui" >/dev/null
grep -F 'tools.push(...await resolveWebTools(requestModel, modelStateGeneration));' \
    "$fallback_ui" >/dev/null

# The schemas come from the running server rather than from a copy kept in the
# page, so the model reads the arguments the wrapper validates. A build without
# the tool routes answers 404 and the turn carries no web tool.
grep -F "const response = await fetch('./tools', { headers: authHeaders() });" \
    "$fallback_ui" >/dev/null
grep -F 'WEB_TOOL_NAMES.includes(entry && entry.tool)' "$fallback_ui" >/dev/null
grep -F 'const { authorization, ...offered } = parameters.properties;' \
    "$fallback_ui" >/dev/null
grep -F "parameters.required.filter(name => name !== 'authorization')" \
    "$fallback_ui" >/dev/null
# The composed list belongs to one selection, so a roster change clears it
# beside the context length.
grep -F 'function forgetWebTools()' "$fallback_ui" >/dev/null
grep -F 'webToolsGeneration === generation' "$fallback_ui" >/dev/null
grep -F "const WEB_SEARCH_TOOL_NAME = 'web_search_exa'" "$fallback_ui" >/dev/null
grep -F "const WEB_FETCH_TOOL_NAME = 'web_fetch_exa'" "$fallback_ui" >/dev/null

# The dialog names every field the grant is signed over, including the live
# crawl that max_age_hours of 0 forces.
grep -F "row('query'" "$fallback_ui" >/dev/null
grep -F "row('publication interval'" "$fallback_ui" >/dev/null
grep -F "row('included domains'" "$fallback_ui" >/dev/null
grep -F "row('excluded domains'" "$fallback_ui" >/dev/null
grep -F "row('max results'" "$fallback_ui" >/dev/null
grep -F "row('live crawl'" "$fallback_ui" >/dev/null
grep -F 'id="approve-once"' "$fallback_ui" >/dev/null
grep -F 'id="approve-deny"' "$fallback_ui" >/dev/null

# The approval posts the parsed proposal and the grant reaches the executor
# inside the one POST /tools body, so the transcript keeps the proposal alone.
grep -F "await requestGrant(fields, controller.signal)" "$fallback_ui" >/dev/null
grep -F 'BROKER_SESSION_HEADER]: secret' "$fallback_ui" >/dev/null
grep -F 'searchRequestParams(fields, outcome.authorization)' "$fallback_ui" >/dev/null
grep -F "body: JSON.stringify({ tool: toolName, params })" "$fallback_ui" >/dev/null
grep -F "'The user refused this web search. It did not run.'" \
    "$fallback_ui" >/dev/null

# The grant enters one request body. A transcript message, a stored value, or a
# completion body carrying it would present a single-use token twice.
grep -F 'outcome = await streamCompletion(history, view);' "$fallback_ui" >/dev/null
if grep -E 'answerCall\([^)]*authorization' "$fallback_ui" >/dev/null; then
    printf 'fallback Web UI writes a grant into the transcript\n' >&2
    exit 1
fi
# The signed grant reaches exactly one call site, which is the params object of
# the POST /tools body.
if [ "$(grep -c 'outcome.authorization' "$fallback_ui")" -ne 1 ]; then
    printf 'fallback Web UI reads the issued grant at more than one site\n' >&2
    exit 1
fi
if grep -F 'requestMessages' "$fallback_ui" >/dev/null; then
    printf 'fallback Web UI still splices a grant into a completion request\n' >&2
    exit 1
fi

# llama-server answers an MCP refusal with `error` at HTTP 200 and a result
# with `plain_text_response`, so all three outcomes are read from the body and
# a refusal names what refused it.
grep -F "if (payload && typeof payload.error === 'string') {" "$fallback_ui" >/dev/null
grep -F 'The ${toolName} call was refused: ${payload.error}' "$fallback_ui" >/dev/null
grep -F 'The ${toolName} call returned HTTP ${response.status} and no result.' \
    "$fallback_ui" >/dev/null
grep -F "typeof payload.plain_text_response !== 'string'" "$fallback_ui" >/dev/null
grep -F 'payload.plain_text_response.slice(0, TOOL_RESULT_CHARACTER_CAP)' \
    "$fallback_ui" >/dev/null
grep -F 'const TOOL_RESULT_CHARACTER_CAP = 8000;' "$fallback_ui" >/dev/null

# A fetch runs without a grant, because the wrapper enforces the signed Result
# ID and its own allowance, and the page bounds the pages one turn reads.
grep -F 'const WEB_FETCH_BUDGET_PER_TURN = 2;' "$fallback_ui" >/dev/null
grep -F 'if (fetchBudget.remaining <= 0) {' "$fallback_ui" >/dev/null
grep -F 'fetchBudget.remaining--;' "$fallback_ui" >/dev/null
grep -F 'answerCall(callId, toolName, await executeWebTool(toolName, params));' \
    "$fallback_ui" >/dev/null

# A demo or otherwise advertised call receives a tool message too: every
# tool_calls entry pairs with a result before the round ends.
grep -F "if (toolName !== WEB_SEARCH_TOOL_NAME) {" "$fallback_ui" >/dev/null
grep -F 'The served path executes no tool named' "$fallback_ui" >/dev/null
grep -F 'if (!outcome.calls.length) return;' "$fallback_ui" >/dev/null

# The final continuation round runs neither web tool: a result issued there
# reaches no request the round budget still sends, so the guard precedes the
# tool-name dispatch and covers the fetch beside the search.
grep -F 'if (roundBudgetExhausted && WEB_TOOL_NAMES.includes(toolName)) {' \
    "$fallback_ui" >/dev/null
grep -F 'The round budget is exhausted; ${toolName} did not run.' "$fallback_ui" >/dev/null
grep -F 'round === CONTINUATION_CAP - 1' "$fallback_ui" >/dev/null

# Tool-call ids come from a conversation-wide counter rather than a per-round
# index, so a later approved search cannot collide with an earlier call and
# overwrite its arguments through requestMessages' id lookup.
grep -F 'let toolCallSequence = 0;' "$fallback_ui" >/dev/null
grep -F 'callIds = outcome.calls.map(() => `call_${toolCallSequence++}`);' \
    "$fallback_ui" >/dev/null
grep -F "history = []; toolCallSequence = 0;" "$fallback_ui" >/dev/null

# The grant admits one search, so a standing grade would promise a permission
# the serving path refuses on the second call. The pinned llama-ui spells those
# grades ALWAYS and ALWAYS_SERVER, and the check names the approval region
# rather than the file, so ordinary prose elsewhere carries no verdict.
if sed -n '/dialog class="approval"/,/<\/dialog>/p;/^function approveWebSearch/,/^}/p' \
        "$fallback_ui" | grep -iE 'always' >/dev/null; then
    printf 'fallback Web UI offers a standing tool permission grade\n' >&2
    exit 1
fi
if grep -F 'ALWAYS_SERVER' "$fallback_ui" >/dev/null; then
    printf 'fallback Web UI carries a server-wide permission grade\n' >&2
    exit 1
fi

# The session secret and every grant live in page memory. A storage write
# naming either would outlive the launch that signed it.
if grep -E "writeBrowserStorage\([^)]*(grant|authorization|session|secret)" \
    "$fallback_ui" >/dev/null; then
    printf 'fallback Web UI persists an approval secret into browser storage\n' >&2
    exit 1
fi
if grep -E "(readBrowserStorage|writeBrowserStorage)\([^)]*brokerSession" \
    "$fallback_ui" >/dev/null; then
    printf 'fallback Web UI persists the broker session secret\n' >&2
    exit 1
fi

# The broker is reached over loopback by construction, so a default naming any
# other host would send the approval to a listener the broker refuses to be.
grep -F "const BROKER_ORIGIN_DEFAULT = 'http://127.0.0.1:" "$fallback_ui" >/dev/null

# A broker restart on the same port signs a new per-launch secret, so a 403
# against the cached one is a stale-cache signal rather than a standing
# refusal. requestGrant clears the cache and re-fetches /session once before
# it retries the same /grant body, and a second refusal still surfaces.
grep -F "if (response.status === 403) {" "$fallback_ui" >/dev/null
grep -F "brokerSessionSecret = null;" "$fallback_ui" >/dev/null
grep -F "const refreshed = await brokerSession(signal);" "$fallback_ui" >/dev/null
grep -F "await postGrant(fields, refreshed, signal)" "$fallback_ui" >/dev/null

# A denial or dismissal while requestGrant(fields) is pending must not let
# that request still land: `settled` makes completion one-shot and
# `controller.abort()` cancels the in-flight fetch so a late grant is never
# injected and a stale finish() cannot close a dialog it no longer owns.
grep -F "let settled = false;" "$fallback_ui" >/dev/null
grep -F "const controller = new AbortController();" "$fallback_ui" >/dev/null
grep -F "if (settled) return;" "$fallback_ui" >/dev/null
grep -F "controller.abort();" "$fallback_ui" >/dev/null

printf 'fallback_webui_web_authorization=accepted\n'
