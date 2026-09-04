#!/bin/sh
set -eu

# measure-prefix-checkpoint-hits.sh reads a served router's own log for the
# schema-bound prefix checkpoint's capture and restore lines, so what a
# workstation test checks is the ledger the harness writes around a fixture
# that emits those lines the way the patched server does.
# remote/test-fixtures/fake-prefix-checkpoint-server.py answers
# /v1/chat/completions, /completion, /health, /slots, and /metrics, pins the
# first eligible chat request's rendered head, and restores it for a later
# request whose head reproduces the same bytes -- the admission rule
# evidence/tool-prefix-checkpoint/README.md states -- so a run against it
# proves the harness's own accounting rather than the mechanism, which no arm
# in this tree has run against a device.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
harness=$script_directory/measure-prefix-checkpoint-hits.sh
fixture_server=$script_directory/test-fixtures/fake-prefix-checkpoint-server.py
temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    [ -z "${server_pid:-}" ] || kill "$server_pid" 2>/dev/null || true
    [ -z "${server_pid:-}" ] || wait "$server_pid" 2>/dev/null || true
    rm -rf -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

failures=0
report() {
    if [ "$1" = 0 ]; then
        printf 'ok %s\n' "$2"
    else
        printf 'FAIL %s\n' "$2"
        failures=$((failures + 1))
    fi
}

server_pid=''
server_log=''
server_port=''
start_fixture() {
    start_fixture_port=$1
    start_fixture_armed=${2:-1}
    server_port=$start_fixture_port
    server_log=$temporary_directory/server-$start_fixture_port.log
    : >"$server_log"
    QWEN_FAKE_PREFIX_CHECKPOINT_LOG=$server_log \
        QWEN_FAKE_PREFIX_CHECKPOINT_ARMED=$start_fixture_armed \
        python3 "$fixture_server" "$server_port" &
    server_pid=$!
    start_fixture_iteration=0
    while [ "$start_fixture_iteration" -lt 50 ]; do
        if curl --silent --fail --max-time 1 "http://127.0.0.1:$server_port/health" \
            >/dev/null 2>&1; then
            return 0
        fi
        start_fixture_iteration=$((start_fixture_iteration + 1))
        sleep 0.1
    done
    printf 'fixture server on port %s never answered /health\n' "$server_port" >&2
    return 1
}
stop_fixture() {
    [ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true
    [ -z "$server_pid" ] || wait "$server_pid" 2>/dev/null || true
    server_pid=''
}

# The healthy run: three stable conversations, a schema change, a recovery, a
# template change, and a second recovery, all against one process whose first
# request pins the head.
start_fixture 18190
healthy_output=$temporary_directory/healthy
healthy_status=0
QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS=3 QWEN_PREFIX_CHECKPOINT_HITS_USER_WORDS=4 \
    QWEN_PREFIX_CHECKPOINT_HITS_GENERATE=2 \
    "$harness" "http://127.0.0.1:$server_port" "$server_log" "$healthy_output" \
    >"$healthy_output.log" 2>&1 || healthy_status=$?
if [ "$healthy_status" -eq 0 ] && [ -s "$healthy_output/requests.tsv" ]; then
    report 0 healthy_run_exits_zero
else
    report 1 healthy_run_exits_zero
    sed -n '1,60p' "$healthy_output.log" >&2
fi
stop_fixture

ledger_field() {
    awk -F'\t' -v phase="$2" -v conversation="$3" -v column="$4" '
        NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
        $index_of["phase"] == phase && $index_of["conversation"] == conversation {
            print $index_of[column]; exit }' "$1"
}

healthy_requests=$healthy_output/requests.tsv

hit_state=0
[ "$(ledger_field "$healthy_requests" stable 1 hit)" = no ] || hit_state=1
[ "$(ledger_field "$healthy_requests" stable 1 capture_seen)" = yes ] || hit_state=1
[ "$(ledger_field "$healthy_requests" stable 2 hit)" = yes ] || hit_state=1
[ "$(ledger_field "$healthy_requests" stable 3 hit)" = yes ] || hit_state=1
report "$hit_state" the_cold_conversation_captures_and_later_ones_restore

key_state=0
baseline_key=$(ledger_field "$healthy_requests" stable 1 checkpoint_key)
second_key=$(ledger_field "$healthy_requests" stable 2 checkpoint_key)
[ -n "$baseline_key" ] && [ "$baseline_key" != - ] || key_state=1
[ "$baseline_key" = "$second_key" ] || key_state=1
report "$key_state" the_restored_key_matches_the_captured_key

schema_state=0
[ "$(ledger_field "$healthy_requests" schema_change 1 hit)" = no ] || schema_state=1
[ "$(ledger_field "$healthy_requests" schema_change 1 capture_seen)" = no ] || schema_state=1
report "$schema_state" the_schema_change_neither_restores_nor_recaptures

recovery_state=0
[ "$(ledger_field "$healthy_requests" recovery_after_schema_change 1 hit)" = yes ] \
    || recovery_state=1
[ "$(ledger_field "$healthy_requests" recovery_after_schema_change 1 checkpoint_key)" \
    = "$baseline_key" ] || recovery_state=1
report "$recovery_state" the_pin_survives_the_schema_change

template_state=0
[ "$(ledger_field "$healthy_requests" template_change 1 hit)" = no ] || template_state=1
[ "$(ledger_field "$healthy_requests" template_change 1 route)" = raw ] || template_state=1
report "$template_state" the_template_change_runs_the_raw_route_and_misses

recovery_b_state=0
[ "$(ledger_field "$healthy_requests" recovery_after_template_change 1 hit)" = yes ] \
    || recovery_b_state=1
report "$recovery_b_state" the_pin_survives_the_template_change

avoided_state=0
avoided_tokens=$(ledger_field "$healthy_requests" stable 2 avoided_prompt_tokens)
if ! awk -v tokens="$avoided_tokens" 'BEGIN { exit (tokens + 0 > 0) ? 0 : 1 }'; then
    avoided_state=1
    printf 'stable conversation 2 avoided_prompt_tokens is not positive: %s\n' \
        "$avoided_tokens" >&2
fi
report "$avoided_state" a_restore_avoids_a_positive_count_of_prompt_tokens

size_state=0
[ "$(ledger_field "$healthy_requests" stable 1 checkpoint_size_mib)" = 12.500 ] || size_state=1
report "$size_state" the_captured_size_is_read_from_the_log_line

# log_bytes_scanned states this request's own window, not the log's
# cumulative size: a schema-change or template-change request writes no new
# log line at all, so its window is exactly zero bytes regardless of how much
# an earlier request already appended to the shared file.
scanned_state=0
[ "$(ledger_field "$healthy_requests" schema_change 1 log_bytes_scanned)" = 0 ] \
    || scanned_state=1
[ "$(ledger_field "$healthy_requests" template_change 1 log_bytes_scanned)" = 0 ] \
    || scanned_state=1
report "$scanned_state" log_bytes_scanned_states_the_request_window_not_the_log_total

summary_state=0
summary=$healthy_output/summary.tsv
# summary.tsv carries two tables separated by one blank line, the request
# table and the verdict table, so the verdict checks read the block after the
# blank line rather than the whole file as one table.
verdicts_block=$healthy_output/verdicts.tsv
awk 'BEGIN { after = 0 } /^$/ { after = 1; next } after { print }' "$summary" \
    >"$verdicts_block"
for check in stable_reuse schema_invalidation recovery_after_schema_change \
    template_invalidation recovery_after_template_change; do
    if ! awk -F'\t' -v check="$check" '
        NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
        $index_of["check"] == check { if ($index_of["verdict"] == "confirmed") matched++ }
        END { exit matched ? 0 : 1 }' "$verdicts_block"; then
        summary_state=1
        printf 'summary does not confirm %s\n' "$check" >&2
    fi
done
if [ "$summary_state" -ne 0 ]; then
    printf 'summary.tsv:\n' >&2
    cat "$summary" >&2
fi
report "$summary_state" the_summary_confirms_every_checked_claim

# An unarmed process never captures or restores, and the harness reads that
# from the log rather than reporting a false hit.
start_fixture 18191 0
unarmed_output=$temporary_directory/unarmed
unarmed_status=0
QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS=2 QWEN_PREFIX_CHECKPOINT_HITS_USER_WORDS=4 \
    QWEN_PREFIX_CHECKPOINT_HITS_GENERATE=2 \
    "$harness" "http://127.0.0.1:$server_port" "$server_log" "$unarmed_output" \
    >"$unarmed_output.log" 2>&1 || unarmed_status=$?
stop_fixture
unarmed_state=0
[ "$unarmed_status" -eq 0 ] || unarmed_state=1
if ! awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    { total++; if ($index_of["hit"] == "no" && $index_of["capture_seen"] == "no") matched++ }
    END { exit (total > 0 && total == matched) ? 0 : 1 }' "$unarmed_output/requests.tsv"; then
    unarmed_state=1
    printf 'an unarmed process shows a hit or a capture somewhere\n' >&2
fi
report "$unarmed_state" an_unarmed_process_never_hits_or_captures

# The identity digest changes with the tool-schema set, which is what the
# harness calls a schema change rather than assuming from the phase label.
identity_state=0
baseline_identity=$(ledger_field "$healthy_requests" stable 1 identity_sha256)
schema_identity=$(ledger_field "$healthy_requests" schema_change 1 identity_sha256)
[ "$baseline_identity" != "$schema_identity" ] || identity_state=1
report "$identity_state" the_identity_digest_moves_with_the_tool_schema_set

# The argument contract, refused ahead of any request.
refuses() {
    refuses_name=$1
    refuses_phrase=$2
    shift 2
    refuses_log=$temporary_directory/$refuses_name.log
    refuses_status=0
    env "$@" "$harness" "http://127.0.0.1:19999" "$temporary_directory/no-log" \
        "$temporary_directory/refused-$refuses_name" >"$refuses_log" 2>&1 \
        || refuses_status=$?
    if [ "$refuses_status" -eq 2 ] && grep -q "$refuses_phrase" "$refuses_log" &&
        [ ! -e "$temporary_directory/refused-$refuses_name" ]; then
        report 0 "$refuses_name"
    else
        report 1 "$refuses_name"
        printf 'status=%s log:\n' "$refuses_status" >&2
        sed -n '1,20p' "$refuses_log" >&2
    fi
}
refuses conversations_zero \
    'QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS is a canonical positive integer' \
    QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS=0
refuses conversations_one \
    'at least 2 conversations' \
    QWEN_PREFIX_CHECKPOINT_HITS_CONVERSATIONS=1
refuses server_log_unreadable 'server log is unreadable'

if [ "$failures" -ne 0 ]; then
    printf 'measure_prefix_checkpoint_hits_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'measure_prefix_checkpoint_hits_tests=passed\n'
