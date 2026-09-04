#!/bin/sh
set -eu

# Runs remote/run-conversational-suite.sh whole against
# remote/test-fixtures/fake-chat-router.py, which stands in for the one
# device-owning link the orchestrator reaches over HTTP -- the servable-roster
# check and the web-off grading arm's requests -- the way
# remote/test-admit-image-router.sh stubs the memory preflight and the
# graphics probes and leaves the rest of its chain real.
# remote/test-conversational-suite-units.py already proves the resolver's
# reasons, the web-on arm's approval accounting and grading, and the
# summarizer's arithmetic in isolation; this proves the shell script wires
# them together and, specifically, that a model absent from the web-profiles
# ledger reaches the summary as web_on=unavailable rather than being skipped.
#
# No browser and no web-on arm run here: the fixture model names no row in
# the ledger this test writes, so run-conversational-suite.sh never invokes
# the page driver at all, which is what keeps this test deviceless.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
for tool in python3 curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'test-run-conversational-suite: %s is required\n' "$tool" >&2
        exit 2
    fi
done

work=$(mktemp -d "${TMPDIR:-/tmp}/qwen-conversational-suite.XXXXXX")
router_pid=0
cleanup() {
    if [ "$router_pid" -gt 0 ]; then
        kill "$router_pid" 2>/dev/null || true
        wait "$router_pid" 2>/dev/null || true
    fi
    rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

model_id=fixture-model-no-web
suite_path=$work/suite.tsv
{
    printf 'screen-01\tscreen\tnumeric\t4\tWhat is 2 plus 2? Reply with the number alone.\t-\n'
    printf 'web-01\tweb_current\tcontains_all\t2025-08-09\tOn what date was Debian 13 released? Reply in YYYY-MM-DD form and nothing else.\tweb:\n'
} >"$suite_path"

ledger_path=$work/web-profiles.tsv
printf '# fixture ledger naming no row for %s\n' "$model_id" >"$ledger_path"

router_port=$((20000 + $$ % 20000))
QWEN_FAKE_CHAT_MODELS=$model_id \
QWEN_FAKE_CHAT_CONTENT='The answer is 4.' \
    python3 "$script_directory/test-fixtures/fake-chat-router.py" --port "$router_port" \
    >"$work/router.log" 2>&1 &
router_pid=$!

ready=0
tries=0
while [ "$tries" -lt 50 ]; do
    if curl -s --max-time 2 "http://127.0.0.1:$router_port/v1/models" >/dev/null 2>&1; then
        ready=1
        break
    fi
    tries=$((tries + 1))
    sleep 0.1
done
if [ "$ready" -ne 1 ]; then
    printf 'test-run-conversational-suite: the fixture router never answered\n' >&2
    cat "$work/router.log" >&2
    exit 1
fi

output_directory=$work/output
set +e
QWEN_SERVER_PORT=$router_port \
QWEN_CONVERSATIONAL_SUITE="$suite_path" \
QWEN_WEB_PROFILES="$ledger_path" \
QWEN_CONVERSATIONAL_THINKING=off \
    "$script_directory/run-conversational-suite.sh" "$output_directory" "$model_id" \
    >"$work/run.stdout" 2>"$work/run.stderr"
run_status=$?
set -e
cat "$work/run.stdout"

if [ "$run_status" -ne 0 ]; then
    printf 'test-run-conversational-suite: the run refused\n' >&2
    cat "$work/run.stderr" >&2
    exit 1
fi

manifest="$output_directory/manifest.tsv"
if ! awk -F'\t' -v id="$model_id" \
    '$1 == id && $3 == "unavailable" && $4 == "no_web_profile" { found = 1 }
     END { exit found ? 0 : 1 }' "$manifest"; then
    printf 'test-run-conversational-suite: the manifest did not record no_web_profile\n' >&2
    cat "$manifest" >&2
    exit 1
fi
if ! awk -F'\t' 'NR > 1 && $5 != "-" { found = 1 } END { exit found ? 1 : 0 }' "$manifest"; then
    printf 'test-run-conversational-suite: a web-on JSON path was recorded for an unavailable arm\n' >&2
    cat "$manifest" >&2
    exit 1
fi
if [ -e "$output_directory/$model_id.web-on.json" ]; then
    printf 'test-run-conversational-suite: a web-on arm ran for a model with no web profile\n' >&2
    exit 1
fi

summary_tsv="$output_directory/conversational-summary.tsv"
if ! awk -F'\t' -v id="$model_id" \
    '$1 == id && $6 == "unavailable" && $7 == "no_web_profile" && $10 == "-" { found = 1 }
     END { exit found ? 0 : 1 }' "$summary_tsv"; then
    printf 'test-run-conversational-suite: the summary did not report the unavailable arm\n' >&2
    cat "$summary_tsv" >&2
    exit 1
fi

if [ ! -s "$output_directory/$model_id.web-off.json" ]; then
    printf 'test-run-conversational-suite: the web-off arm wrote no record\n' >&2
    exit 1
fi
if ! python3 -c "
import json, sys
with open('$output_directory/$model_id.web-off.json') as handle:
    document = json.load(handle)
served = document['summary'].get('served_models') or []
assert served == ['$model_id'], served
records = {r['id']: r for r in document['records']}
assert records['screen-01']['passed'] is True, records['screen-01']
assert records['web-01']['passed'] is False, records['web-01']
"; then
    printf 'test-run-conversational-suite: the web-off arm graded unexpectedly\n' >&2
    exit 1
fi

printf 'test-run-conversational-suite: all checks passed\n'
