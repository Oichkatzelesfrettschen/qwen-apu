#!/bin/sh
set -eu

# Drives remote/test-code-agent-endpoint.sh against
# remote/test-fixtures/fake-code-agent-server.py rather than a live
# appliance, so the endpoint check's own logic -- the per-model loop, the SSE
# event parser, the forced tool_choice check, and the OpenAI chat route --
# runs in the repository gate instead of only against hardware this tree
# never reaches from a workstation clone.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
endpoint_script=$script_directory/test-code-agent-endpoint.sh
fake_server=$script_directory/test-fixtures/fake-code-agent-server.py

command -v python3 >/dev/null 2>&1 || {
    printf 'python3 is required\n' >&2
    exit 2
}

work=$(mktemp -d)
server_pid=''
cleanup() {
    if [ -n "$server_pid" ] && kill -0 "$server_pid" 2>/dev/null; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf -- "$work"
}
trap cleanup EXIT INT TERM

failures=0
report() {
    printf '%s=%s %s\n' "$1" "$2" "${3:-}"
    [ "$2" = pass ] || failures=$((failures + 1))
}

start_server() {
    python3 "$fake_server" --model served-a --model served-b \
        >"$work/server.out" 2>"$work/server.err" &
    server_pid=$!
    server_port=''
    waited=0
    while [ "$waited" -lt 100 ]; do
        if [ -s "$work/server.out" ]; then
            server_port=$(sed -n 's/^port=//p' "$work/server.out")
            [ -n "$server_port" ] && break
        fi
        if ! kill -0 "$server_pid" 2>/dev/null; then
            printf 'fake-code-agent-server exited before it printed a port\n' >&2
            cat "$work/server.err" >&2 2>/dev/null || true
            exit 2
        fi
        sleep 0.05
        waited=$((waited + 1))
    done
    [ -n "$server_port" ] || {
        printf 'fake-code-agent-server never printed a port\n' >&2
        exit 2
    }
    origin="http://127.0.0.1:$server_port"
}

start_server

key_file=$work/key
umask 077
printf 'fixture-bearer\n' >"$key_file"

# Two served ids exercises the per-model loop fix: every route check below
# must run for both rather than the first alone.
if QWEN_CODE_AGENT_ORIGIN=$origin QWEN_CODE_AGENT_KEY_FILE=$key_file \
    "$endpoint_script" served-a served-b >"$work/pass.out" 2>"$work/pass.err"; then
    report fixture_pass_exit pass ''
else
    report fixture_pass_exit fail "exit=$? $(tail -n 5 "$work/pass.out" 2>/dev/null)"
fi
if grep -q '^code_agent_endpoint=ready origin=.* models=served-a served-b$' \
    "$work/pass.out"; then
    report fixture_pass_ready_line pass ''
else
    report fixture_pass_ready_line fail "$(tail -n 3 "$work/pass.out" 2>/dev/null)"
fi
for check_name in messages_answered messages_model_echoed messages_usage \
    messages_streamed messages_stream_events messages_tool_use_answered \
    messages_tool_use_block count_tokens_answered count_tokens_counted \
    count_matches_usage chat_completions_answered chat_completions_usage \
    chat_completions_model_echoed; do
    for model_id in served-a served-b; do
        if grep -q "^${check_name}_${model_id}=pass" "$work/pass.out"; then
            report "fixture_pass_${check_name}_${model_id}" pass ''
        else
            report "fixture_pass_${check_name}_${model_id}" fail \
                "$(grep "^${check_name}_${model_id}=" "$work/pass.out" 2>/dev/null)"
        fi
    done
done

# A model absent from the served roster must fail rather than being silently
# skipped, and it must fail for its own id without masking the id that is
# present.
if QWEN_CODE_AGENT_ORIGIN=$origin QWEN_CODE_AGENT_KEY_FILE=$key_file \
    "$endpoint_script" served-a unserved-c >"$work/fail.out" 2>"$work/fail.err"; then
    report fixture_missing_model_exit fail "expected a nonzero exit"
else
    report fixture_missing_model_exit pass ''
fi
if grep -q '^model_present_unserved-c=fail' "$work/fail.out"; then
    report fixture_missing_model_reported pass ''
else
    report fixture_missing_model_reported fail "$(tail -n 5 "$work/fail.out" 2>/dev/null)"
fi
if grep -q '^model_present_served-a=pass' "$work/fail.out"; then
    report fixture_present_model_unaffected pass ''
else
    report fixture_present_model_unaffected fail "$(tail -n 5 "$work/fail.out" 2>/dev/null)"
fi

printf 'checks_failed=%d\n' "$failures"
[ "$failures" -eq 0 ] || exit 1
printf 'test_code_agent_endpoint_fixture=accepted\n'
