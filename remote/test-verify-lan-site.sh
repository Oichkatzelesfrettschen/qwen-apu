#!/bin/sh
set -eu

# The LAN site verification over fixtures: a fake router/broker/artifacts
# server answers every HTTP-only row, a fake page driver stands in for the
# headless-Chromium web-search and image-generation turns, and a fake
# conversation driver stands in for the reload check, so the whole script
# runs without a device, a real browser, or a network. Each fixture also
# proves its own failure path, since the point of the checker is refusing
# rather than passing on an unread response.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
checker=$script_directory/verify-lan-site.sh
fixture_server=$script_directory/test-fixtures/fake-verify-lan-site-server.py
fixture_page_driver=$script_directory/test-fixtures/fake-page-driver-verify-lan-site.py
fixture_conversation_driver=$script_directory/test-fixtures/fake-conversation-driver-verify-lan-site.py

for required in "$checker" "$fixture_server" "$fixture_page_driver" "$fixture_conversation_driver"; do
    if [ ! -r "$required" ]; then
        printf 'required fixture is unreadable: %s\n' "$required" >&2
        exit 1
    fi
done
for required_tool in python3 curl jq; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf '%s is required\n' "$required_tool" >&2
        exit 2
    fi
done

work_directory=$(mktemp -d)
server_pid=''
cleanup() {
    [ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true
    rm -rf "$work_directory"
}
trap cleanup EXIT HUP INT TERM

checks=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
}

# A static directory the fixture server reads webui/index.html out of, the
# same file the real router serves and the real page-meta-tag check reads.
static_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)/webui

router_port=$((20000 + $$ % 10000))
broker_port=$((router_port + 1))
artifacts_port=$((router_port + 2))

start_server() {
    server_extra=${1:-}
    # shellcheck disable=SC2086 # server_extra is zero or one bare flag
    python3 "$fixture_server" --router-port "$router_port" --broker-port "$broker_port" \
        --artifacts-port "$artifacts_port" --static "$static_directory" \
        --roster fixture-model $server_extra >"$work_directory/server.log" 2>&1 &
    server_pid=$!
    deadline=$(($(date +%s) + 30))
    while [ "$(date +%s)" -lt "$deadline" ]; do
        if curl -sS -o /dev/null "http://127.0.0.1:$router_port/health" 2>/dev/null; then
            return 0
        fi
        if ! kill -0 "$server_pid" 2>/dev/null; then
            cat "$work_directory/server.log" >&2
            printf 'the fixture server exited before it answered /health\n' >&2
            return 1
        fi
        sleep 0.2
    done
    printf 'the fixture server never answered /health\n' >&2
    return 1
}
stop_server() {
    [ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    server_pid=''
}

# The fixture roster names no Qwen3.5-architecture id, so the checkpoint
# subject is named explicitly for every run; the runs that test the subject
# rule itself clear it, since the checker reads an empty value as unset.
export QWEN_VERIFY_MODEL=fixture-model

site_url="http://127.0.0.1:$router_port/?broker=http://127.0.0.1:$broker_port&artifacts=http://127.0.0.1:$artifacts_port"

run_checker() {
    output=$1
    rm -rf "$output"
    QWEN_VERIFY_PAGE_DRIVER=$fixture_page_driver \
    QWEN_VERIFY_CONVERSATION_DRIVER=$fixture_conversation_driver \
        "$checker" "$site_url" "$output"
}
row_of() {
    awk -F'\t' -v key="$2" '$1 == key { print; exit }' "$1"
}

# ---- the whole matrix passes over a healthy fixture --------------------------
start_server
if run_checker "$work_directory/pass-run" >"$work_directory/pass-run.stdout" 2>"$work_directory/pass-run.stderr"; then
    report all_rows_pass accepted
else
    cat "$work_directory/pass-run.stdout" "$work_directory/pass-run.stderr" >&2
    printf 'the checker failed over a healthy fixture\n' >&2
    exit 1
fi

results=$work_directory/pass-run/results.tsv
if [ ! -r "$results" ]; then
    printf 'the checker wrote no results.tsv\n' >&2
    exit 1
fi
report results_tsv_written accepted

row_status() {
    awk -F'\t' -v key="$1" '$1 == key { print $2; exit }' "$results"
}
for expected_pass in initial-page-get initial-health initial-models initial-props \
    initial-broker-health initial-artifacts-health web_search_turn \
    image_generation_turn conversation_restoration tool_prefix_checkpoint; do
    if [ "$(row_status "$expected_pass")" != pass ]; then
        printf 'expected row %s to read pass, read %s\n' \
            "$expected_pass" "$(row_status "$expected_pass")" >&2
        exit 1
    fi
done
report expected_rows_pass accepted
if [ "$(row_status relaunch)" != skip ]; then
    printf 'relaunch read %s without --with-relaunch\n' "$(row_status relaunch)" >&2
    exit 1
fi
report relaunch_skipped_without_flag accepted

for evidence_file in "$work_directory/pass-run"/http/*-initial-models.response \
    "$work_directory/pass-run"/http/*-web-search-turn.json \
    "$work_directory/pass-run"/http/*-conversation-restoration.json; do
    if [ ! -s "$evidence_file" ]; then
        printf 'expected raw evidence file is empty: %s\n' "$evidence_file" >&2
        exit 1
    fi
done
report raw_evidence_retained accepted

# The bearer value itself never reaches a retained file or this test's own
# stdout: a distinctive secret goes into an api-key file, and every file the
# checker wrote or printed is grepped for it. The page's own source names the
# literal word "Bearer" in its own Authorization header code, so that word
# alone is not the thing under test -- the value is.
bearer_secret=fixture-secret-$$-do-not-retain
api_key_file=$work_directory/api.key
printf '%s\n' "$bearer_secret" >"$api_key_file"
# A fresh fixture process is what makes this run's first tool-prefix-checkpoint
# request read as the head's first sighting again; the running fixture's
# in-memory signature would otherwise still carry the pass-run's above.
stop_server
start_server
if QWEN_VERIFY_API_KEY_FILE=$api_key_file QWEN_VERIFY_PAGE_DRIVER=$fixture_page_driver \
    QWEN_VERIFY_CONVERSATION_DRIVER=$fixture_conversation_driver \
    "$checker" "$site_url" "$work_directory/bearer-run" \
    >"$work_directory/bearer-run.stdout" 2>"$work_directory/bearer-run.stderr"; then
    report bearer_run_accepted accepted
else
    cat "$work_directory/bearer-run.stdout" "$work_directory/bearer-run.stderr" >&2
    printf 'the checker failed with a bearer key file configured\n' >&2
    exit 1
fi
if grep -rl "$bearer_secret" "$work_directory/bearer-run" \
    "$work_directory/bearer-run.stdout" "$work_directory/bearer-run.stderr" >/dev/null 2>&1; then
    printf 'the bearer secret reached a retained file or stdout/stderr\n' >&2
    exit 1
fi
report bearer_never_retained accepted
stop_server

# ---- the tool-prefix checkpoint check fails against a server that never
# restores one --------------------------------------------------------------
QWEN_FAKE_VERIFY_SERVER_NO_CHECKPOINT=1 python3 "$fixture_server" \
    --router-port "$router_port" --broker-port "$broker_port" \
    --artifacts-port "$artifacts_port" --static "$static_directory" \
    --roster fixture-model >"$work_directory/server-no-checkpoint.log" 2>&1 &
server_pid=$!
deadline=$(($(date +%s) + 30))
while [ "$(date +%s)" -lt "$deadline" ]; do
    curl -sS -o /dev/null "http://127.0.0.1:$router_port/health" 2>/dev/null && break
    sleep 0.2
done
if run_checker "$work_directory/no-checkpoint-run" >/dev/null 2>&1; then
    printf 'the checker passed against a server with no prefix checkpoint\n' >&2
    exit 1
fi
if [ "$(awk -F'\t' '$1 == "tool_prefix_checkpoint" { print $2; exit }' \
    "$work_directory/no-checkpoint-run/results.tsv")" != fail ]; then
    printf 'tool_prefix_checkpoint did not read fail against a non-restoring server\n' >&2
    exit 1
fi
report tool_prefix_checkpoint_catches_a_non_restoring_server accepted
stop_server

# ---- the checkpoint subject is a Qwen3.5-architecture id or an explicit
# QWEN_VERIFY_MODEL, never the roster's first id ------------------------------
start_server
if QWEN_VERIFY_MODEL='' QWEN_VERIFY_PAGE_DRIVER=$fixture_page_driver \
    QWEN_VERIFY_CONVERSATION_DRIVER=$fixture_conversation_driver \
    "$checker" "$site_url" "$work_directory/no-subject-run" >/dev/null 2>&1; then
    printf 'the checker passed with no checkpoint subject on the roster\n' >&2
    exit 1
fi
no_subject_row=$(row_of "$work_directory/no-subject-run/results.tsv" tool_prefix_checkpoint)
case $no_subject_row in
    *"	fail	no qwen35-* or qwen38-* id on the roster"*) ;;
    *)
        printf 'tool_prefix_checkpoint did not refuse by name without a subject: %s\n' "$no_subject_row" >&2
        exit 1
        ;;
esac
if [ "$(awk -F'\t' '$1 == "initial-props" { print $2; exit }' \
    "$work_directory/no-subject-run/results.tsv")" != pass ]; then
    printf 'initial-props did not read pass on the roster first id without a subject\n' >&2
    exit 1
fi
report checkpoint_subject_refused_by_name_without_a_qwen_row accepted
stop_server

python3 "$fixture_server" --router-port "$router_port" --broker-port "$broker_port" \
    --artifacts-port "$artifacts_port" --static "$static_directory" \
    --roster lfm-fixture,qwen38-fixture,qwen35-fixture >"$work_directory/server-qwen-roster.log" 2>&1 &
server_pid=$!
deadline=$(($(date +%s) + 30))
while [ "$(date +%s)" -lt "$deadline" ]; do
    curl -sS -o /dev/null "http://127.0.0.1:$router_port/health" 2>/dev/null && break
    sleep 0.2
done
if ! QWEN_VERIFY_MODEL='' QWEN_VERIFY_PAGE_DRIVER=$fixture_page_driver \
    QWEN_VERIFY_CONVERSATION_DRIVER=$fixture_conversation_driver \
    "$checker" "$site_url" "$work_directory/qwen-roster-run" >/dev/null 2>&1; then
    printf 'the checker failed over a roster carrying a Qwen row\n' >&2
    exit 1
fi
qwen_roster_row=$(row_of "$work_directory/qwen-roster-run/results.tsv" tool_prefix_checkpoint)
case $qwen_roster_row in
    *"model=qwen38-fixture subject_source=roster-first-qwen35-architecture-id prefix=cold nonce="*) ;;
    *)
        printf 'the checkpoint subject was not the roster first Qwen row: %s\n' "$qwen_roster_row" >&2
        exit 1
        ;;
esac
if [ "$(awk -F'\t' '$1 == "initial-props" { print $3; exit }' \
    "$work_directory/qwen-roster-run/results.tsv")" != model=qwen38-fixture ]; then
    printf 'initial-props did not read the checkpoint subject\n' >&2
    exit 1
fi
report checkpoint_subject_is_the_roster_first_qwen_row accepted

# ---- the first request's head is cold by construction: a second run against
# the same fixture process, whose in-memory signature still carries the run
# above, passes because the nonce makes the head a new one -------------------
if ! QWEN_VERIFY_MODEL='' QWEN_VERIFY_PAGE_DRIVER=$fixture_page_driver \
    QWEN_VERIFY_CONVERSATION_DRIVER=$fixture_conversation_driver \
    "$checker" "$site_url" "$work_directory/warm-fixture-run" >/dev/null 2>&1; then
    printf 'the checker failed against a fixture whose previous head was still warm\n' >&2
    exit 1
fi
first_nonce=$(printf '%s' "$qwen_roster_row" | sed 's/.*nonce=\([^ ]*\).*/\1/')
second_nonce=$(row_of "$work_directory/warm-fixture-run/results.tsv" tool_prefix_checkpoint | sed 's/.*nonce=\([^ ]*\).*/\1/')
if [ -z "$first_nonce" ] || [ "$first_nonce" = "$second_nonce" ]; then
    printf 'the two runs carried one nonce: %s %s\n' "$first_nonce" "$second_nonce" >&2
    exit 1
fi
report cold_prefix_by_nonce_passes_against_a_warm_fixture accepted
stop_server

# ---- a router that never answers leaves a terminal fail row rather than an
# absent one, and every expected row exists ------------------------------------
start_server --hang-chat
if QWEN_VERIFY_CHAT_TIMEOUT_S=2 run_checker "$work_directory/hang-run" >/dev/null 2>&1; then
    printf 'the checker passed against a router that never answers\n' >&2
    exit 1
fi
hang_row=$(row_of "$work_directory/hang-run/results.tsv" tool_prefix_checkpoint)
case $hang_row in
    *"	fail	"*"first_status=000"*) ;;
    *)
        printf 'tool_prefix_checkpoint carried no terminal row against a hung router: %s\n' "$hang_row" >&2
        exit 1
        ;;
esac
for expected_row in initial-page-get initial-health initial-models initial-props \
    initial-broker-health initial-artifacts-health web_search_turn \
    image_generation_turn conversation_restoration tool_prefix_checkpoint relaunch; do
    if [ -z "$(row_of "$work_directory/hang-run/results.tsv" "$expected_row")" ]; then
        printf 'row %s is absent from the hung run\n' "$expected_row" >&2
        exit 1
    fi
done
report hung_router_leaves_a_terminal_row accepted
stop_server

# ---- a run ended by a signal writes the rows it never reached ---------------
start_server --hang-chat
rm -rf "$work_directory/signal-run"
QWEN_VERIFY_CHAT_TIMEOUT_S=5 \
    QWEN_VERIFY_PAGE_DRIVER=$fixture_page_driver \
    QWEN_VERIFY_CONVERSATION_DRIVER=$fixture_conversation_driver \
    "$checker" "$site_url" "$work_directory/signal-run" >/dev/null 2>&1 &
checker_pid=$!
deadline=$(($(date +%s) + 30))
first_request_sent=0
while [ "$(date +%s)" -lt "$deadline" ] && [ "$first_request_sent" = 0 ]; do
    for request_file in "$work_directory/signal-run/http/"*-tool-prefix-1.request; do
        [ -f "$request_file" ] && first_request_sent=1
    done
    sleep 0.2
done
kill -TERM "$checker_pid"
wait "$checker_pid" 2>/dev/null || true
signal_row=$(row_of "$work_directory/signal-run/results.tsv" tool_prefix_checkpoint)
case $signal_row in
    *"	fail	the harness ended before this row was written"*) ;;
    *)
        printf 'the interrupted run left no terminal checkpoint row: %s\n' "$signal_row" >&2
        exit 1
        ;;
esac
report interrupted_run_writes_missing_rows accepted
stop_server

# ---- an unhealthy router fails the health row and the whole run --------------
start_server --unhealthy
if run_checker "$work_directory/unhealthy-run" >/dev/null 2>&1; then
    printf 'the checker passed against an unhealthy router\n' >&2
    exit 1
fi
if [ "$(awk -F'\t' '$1 == "initial-health" { print $2; exit }' \
    "$work_directory/unhealthy-run/results.tsv")" != fail ]; then
    printf 'initial-health did not read fail against an unhealthy router\n' >&2
    exit 1
fi
report unhealthy_router_fails accepted
stop_server

# ---- a failing lane in the page driver fails that row and the whole run ------
start_server
if QWEN_VERIFY_PAGE_DRIVER=$fixture_page_driver \
    QWEN_VERIFY_CONVERSATION_DRIVER=$fixture_conversation_driver \
    QWEN_FAKE_PAGE_DRIVER_FAIL_LANES=web \
    "$checker" "$site_url" "$work_directory/web-fail-run" >/dev/null 2>&1; then
    printf 'the checker passed with the web lane forced to fail\n' >&2
    exit 1
fi
if [ "$(awk -F'\t' '$1 == "web_search_turn" { print $2; exit }' \
    "$work_directory/web-fail-run/results.tsv")" != fail ]; then
    printf 'web_search_turn did not read fail with the lane forced to fail\n' >&2
    exit 1
fi
if [ "$(awk -F'\t' '$1 == "image_generation_turn" { print $2; exit }' \
    "$work_directory/web-fail-run/results.tsv")" != pass ]; then
    printf 'image_generation_turn read something other than pass while only the web lane was forced\n' >&2
    exit 1
fi
report single_lane_failure_isolated accepted

# ---- a mismatched conversation-restoration report fails that row alone -------
if QWEN_VERIFY_PAGE_DRIVER=$fixture_page_driver \
    QWEN_VERIFY_CONVERSATION_DRIVER=$fixture_conversation_driver \
    QWEN_FAKE_CONVERSATION_DRIVER_FAIL=1 \
    "$checker" "$site_url" "$work_directory/conversation-fail-run" >/dev/null 2>&1; then
    printf 'the checker passed with the conversation driver forced to mismatch\n' >&2
    exit 1
fi
if [ "$(awk -F'\t' '$1 == "conversation_restoration" { print $2; exit }' \
    "$work_directory/conversation-fail-run/results.tsv")" != fail ]; then
    printf 'conversation_restoration did not read fail with the driver forced to mismatch\n' >&2
    exit 1
fi
report conversation_mismatch_caught accepted
stop_server

# ---- --with-relaunch runs the operator-only path and repeats the matrix ------
recorder_directory=$work_directory/recorders
mkdir -p "$recorder_directory"
cat >"$recorder_directory/qwen-teardown.sh" <<'EOF'
#!/bin/sh
printf 'teardown\n' >>"$QWEN_TEST_RELAUNCH_RECORD"
exit 0
EOF
cat >"$recorder_directory/qwen-lan-launch.sh" <<'EOF'
#!/bin/sh
printf 'launch %s\n' "${1:-}" >>"$QWEN_TEST_RELAUNCH_RECORD"
exit 0
EOF
chmod 755 "$recorder_directory/qwen-teardown.sh" "$recorder_directory/qwen-lan-launch.sh"

start_server
relaunch_record=$work_directory/relaunch.record
: >"$relaunch_record"
if QWEN_VERIFY_PAGE_DRIVER=$fixture_page_driver \
    QWEN_VERIFY_CONVERSATION_DRIVER=$fixture_conversation_driver \
    QWEN_VERIFY_TEARDOWN=$recorder_directory/qwen-teardown.sh \
    QWEN_VERIFY_LAUNCH=$recorder_directory/qwen-lan-launch.sh \
    QWEN_VERIFY_RELAUNCH_PROFILE=paced-60 \
    QWEN_TEST_RELAUNCH_RECORD=$relaunch_record \
    "$checker" "$site_url" "$work_directory/relaunch-run" --with-relaunch \
    >"$work_directory/relaunch-run.stdout" 2>"$work_directory/relaunch-run.stderr"; then
    report with_relaunch_accepted accepted
else
    cat "$work_directory/relaunch-run.stdout" "$work_directory/relaunch-run.stderr" >&2
    printf 'the checker failed with --with-relaunch over a healthy fixture\n' >&2
    exit 1
fi
expected_relaunch_record=$(printf 'teardown\nlaunch paced-60')
if [ "$(cat "$relaunch_record")" != "$expected_relaunch_record" ]; then
    printf 'the relaunch record does not read teardown then launch paced-60: %s\n' \
        "$(cat "$relaunch_record")" >&2
    exit 1
fi
report relaunch_record_ordered accepted
if [ "$(awk -F'\t' '$1 == "relaunch" { print $2; exit }' \
    "$work_directory/relaunch-run/results.tsv")" != pass ]; then
    printf 'relaunch row did not read pass\n' >&2
    exit 1
fi
if [ "$(awk -F'\t' '$1 == "relaunch-health" { print $2; exit }' \
    "$work_directory/relaunch-run/results.tsv")" != pass ]; then
    printf 'the relaunch health matrix did not repeat with the relaunch- prefix\n' >&2
    exit 1
fi
report relaunch_health_matrix_repeated accepted
stop_server

printf 'test-verify-lan-site: %d checks passed\n' "$checks"
