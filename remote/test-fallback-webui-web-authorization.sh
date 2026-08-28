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
grep -F "if (\$('#web-tools').checked) tools.push(...WEB_TOOLS)" \
    "$fallback_ui" >/dev/null
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

# The approval posts the parsed proposal and carries the grant in a
# request-scoped argument copy, so the transcript keeps the proposal alone.
grep -F "await requestGrant(fields)" "$fallback_ui" >/dev/null
grep -F 'BROKER_SESSION_HEADER]: secret' "$fallback_ui" >/dev/null
grep -F 'requestMessages(authorizations)' "$fallback_ui" >/dev/null
grep -F "content: 'The user refused this web search. It did not run.'" \
    "$fallback_ui" >/dev/null
# Both decisions answer the call with a tool message, so the continuation array
# pairs every tool_calls entry with its result and stays a legal request.
grep -F "'single-use grant covers them. The search awaits its '" \
    "$fallback_ui" >/dev/null

# A fetch, demo, or other advertised call carries no approval path of its own,
# so it receives a tool message too: every tool_calls entry pairs with a
# result before the round ends, and none is skipped on the way there.
grep -F "if (calls[index].name !== WEB_SEARCH_TOOL_NAME) {" "$fallback_ui" >/dev/null
grep -F 'The served path executes no tool named' "$fallback_ui" >/dev/null
grep -F 'if (!outcome.calls.length) return;' "$fallback_ui" >/dev/null

# The final continuation round opens no approval dialog: a grant issued there
# outlives every remaining request the round budget allows.
grep -F "if (calls[index].name === WEB_SEARCH_TOOL_NAME && roundBudgetExhausted) {" \
    "$fallback_ui" >/dev/null
grep -F 'The round budget is exhausted; the search did not run.' "$fallback_ui" >/dev/null
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

printf 'fallback_webui_web_authorization=accepted\n'
