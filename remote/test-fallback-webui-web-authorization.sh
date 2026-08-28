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

# The grant admits one search, so a standing grade would promise a permission
# the serving path refuses on the second call.
if grep -iE 'always' "$fallback_ui" >/dev/null; then
    printf 'fallback Web UI offers a standing tool permission grade\n' >&2
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
