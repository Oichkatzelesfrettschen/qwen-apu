#!/bin/sh
set -eu

# The draft-pair harness drives four servers, three prompts each, and derives
# four speculation quantities from what the server reports. Every check below
# runs against remote/test-fixtures/fake-llama-server.sh, which answers
# /completion with a timings object carrying draft_n and draft_n_accepted where
# its own argv names --spec-type, so the pair and control arms differ by the
# flag the real server differs by.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
harness=$script_directory/measure-draft-pair.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
failures=0

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

# A fabricated registry, pair ledger, and model root, so the harness runs
# without weights and without the device.
registry=$work/models.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fake-target research Target/target.gguf fetch.sh 4096 8192 8192 \
    q8_0 q4_0 on none - - - untested production 128 32 4096 - unmeasured refused \
    >"$registry"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fake-draft research Draft/draft.gguf fetch.sh 4096 8192 8192 \
    q8_0 q4_0 on none - - - untested candidate 128 32 4096 - unmeasured refused \
    >>"$registry"
quarantine=$work/quarantine.tsv
: >"$quarantine"
model_root=$work/models
mkdir -p "$model_root/Target" "$model_root/Draft"
printf 'target' >"$model_root/Target/target.gguf"
printf 'draft' >"$model_root/Draft/draft.gguf"

pairs=$work/draft-pairs.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fake-pair fake-target fake-draft candidate 2 0.00 4096 q8_0 q4_0 - \
    'target plus draft' \
    >"$pairs"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    stopped-pair fake-target fake-draft quarantine 2 0.00 4096 q8_0 q4_0 - \
    'retired pairing' \
    >>"$pairs"

build_directory=$work/build
mkdir -p "$build_directory/bin"
cp "$script_directory/test-fixtures/fake-llama-server.sh" \
    "$build_directory/bin/llama-server"
chmod 0755 "$build_directory/bin/llama-server"

server_port=18127
run_harness() {
    QWEN_MODEL_REGISTRY=$registry \
    QWEN_QUARANTINE_REGISTRY=$quarantine \
    QWEN_DRAFT_PAIRS=$pairs \
    QWEN_MODELS_DIRECTORY=$model_root \
    QWEN_PRODUCTION_BUILD_DIR=$build_directory \
    QWEN_DRAFT_PAIR_PORT=$server_port \
    QWEN_SERVER_PORT=$server_port \
    QWEN_DRAFT_PAIR_PREDICT=128 \
    QWEN_DRAFT_PAIR_READY_SECONDS=20 \
    QWEN_FAKE_SERVER_PORT=$server_port \
    QWEN_FAKE_SERVER_STATE_DIRECTORY=$1/argv \
    QWEN_FAKE_SERVER_DECODE_TOK_S=3.00 \
    QWEN_FAKE_SERVER_DECODE_TOK_S_SPEC=3.60 \
    QWEN_FAKE_SERVER_DRAFT_N=64 \
    QWEN_FAKE_SERVER_DRAFT_ACCEPTED=48 \
        "$harness" "$2" "$1"
}

# A quarantined pairing names a device failure or the absence of any safe tuple,
# and measuring it is what would construct that tuple again.
quarantine_output=$work/quarantine-run
if run_harness "$quarantine_output" stopped-pair \
    >"$work/quarantine.stdout" 2>"$work/quarantine.stderr"; then
    report quarantine_pair_refused rejected
else
    if grep -F 'is tiered quarantine' "$work/quarantine.stderr" >/dev/null; then
        report quarantine_pair_refused accepted
    else
        report quarantine_pair_refused rejected
        cat "$work/quarantine.stderr" >&2
    fi
fi

# The harness owns the device for its whole run, so a server already answering
# on the appliance port stops it before any arm starts.
resident_output=$work/resident-run
python3 - "$server_port" "$work/resident.pid" <<'PY' &
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *arguments):
        pass

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b"ok")


with open(sys.argv[2], "w") as handle:
    handle.write(str(os.getpid()))
HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
PY
resident_pid=$!
resident_iteration=0
while [ "$resident_iteration" -lt 20 ]; do
    if curl --silent --fail --max-time 1 \
        "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
        break
    fi
    resident_iteration=$((resident_iteration + 1))
    sleep 1
done
if run_harness "$resident_output" fake-pair \
    >"$work/resident.stdout" 2>"$work/resident.stderr"; then
    report resident_server_refused rejected
else
    if grep -F 'run measure-draft-pair.sh after qwen-teardown.sh' \
        "$work/resident.stderr" >/dev/null; then
        report resident_server_refused accepted
    else
        report resident_server_refused rejected
        cat "$work/resident.stderr" >&2
    fi
fi
kill -TERM "$resident_pid" 2>/dev/null || true
wait "$resident_pid" 2>/dev/null || true

# The measured run. Four arms in the order control, pair, pair, control, three
# prompts each, and the summary reads the pair against its own controls.
measured_output=$work/measured-run
run_harness "$measured_output" fake-pair >"$work/measured.stdout" \
    2>"$work/measured.stderr"

arm_order=$(awk -F'\t' 'NR > 1 { print $1 }' "$measured_output/arms.tsv" |
    awk '!seen[$0]++' | tr '\n' ' ')
if [ "$arm_order" = 'control-open pair-first pair-second control-close ' ]; then
    report arm_order accepted
else
    report arm_order rejected
    printf 'arm order was %s\n' "$arm_order" >&2
fi

if [ "$(awk -F'\t' 'NR > 1' "$measured_output/arms.tsv" | wc -l)" = 12 ]; then
    report prompt_coverage accepted
else
    report prompt_coverage rejected
fi

# The four speculation quantities are derived from the two the server reports:
# 64 drafted with 48 accepted is an acceptance of 0.750, and 128 predicted
# tokens with 48 accepted leaves 80 verification steps at a mean accepted
# length of 1.60.
pair_row=$(awk -F'\t' '$1 == "pair-first" && $3 == "code"' \
    "$measured_output/arms.tsv")
pair_acceptance=$(printf '%s\n' "$pair_row" | cut -f8)
pair_steps=$(printf '%s\n' "$pair_row" | cut -f9)
pair_mean_length=$(printf '%s\n' "$pair_row" | cut -f10)
pair_rate=$(printf '%s\n' "$pair_row" | cut -f5)
if [ "$pair_acceptance" = 0.750 ] && [ "$pair_steps" = 80 ] &&
   [ "$pair_mean_length" = 1.60 ] && [ "$pair_rate" = 3.60 ]; then
    report speculation_quantities accepted
else
    report speculation_quantities rejected
    printf 'pair row was %s\n' "$pair_row" >&2
fi

# A control arm drafts nothing, so the server reports no draft fields and the
# derived columns stay unmeasured rather than reading as zero acceptance.
control_row=$(awk -F'\t' '$1 == "control-open" && $3 == "code"' \
    "$measured_output/arms.tsv")
if [ "$(printf '%s\n' "$control_row" | cut -f6)" = - ] &&
   [ "$(printf '%s\n' "$control_row" | cut -f8)" = - ] &&
   [ "$(printf '%s\n' "$control_row" | cut -f5)" = 3.00 ]; then
    report control_reports_no_draft accepted
else
    report control_reports_no_draft rejected
    printf 'control row was %s\n' "$control_row" >&2
fi

if grep -Fx 'pair_over_control=1.2000' "$measured_output/summary.txt" \
    >/dev/null; then
    report pair_over_control accepted
else
    report pair_over_control rejected
    cat "$measured_output/summary.txt" >&2
fi

# Every draft option reaches the pair arms and none of them reaches a control.
spec_launches=$(grep -l -- '--spec-type' "$measured_output"/argv/argv-*.txt |
    wc -l)
draft_model_launches=$(grep -c -- "argument=$model_root/Draft/draft.gguf" \
    "$measured_output"/argv/argv-*.txt | awk -F: '$2 > 0' | wc -l)
if [ "$spec_launches" = 2 ] && [ "$draft_model_launches" = 2 ] &&
   grep -q -- '--spec-draft-ngl' "$measured_output"/argv/argv-*.txt &&
   grep -q -- 'argument=--spec-draft-device' \
       "$measured_output"/argv/argv-*.txt; then
    report draft_argv_reaches_pair_arms accepted
else
    report draft_argv_reaches_pair_arms rejected
    printf 'spec launches %s, draft model launches %s\n' \
        "$spec_launches" "$draft_model_launches" >&2
fi

# A pair arm that drafted nothing decodes at the control's own rate against a
# control measuring the same thing, so the run ends rather than reporting a
# ratio. server-context.cpp reaches that state by catching the throw
# common_speculative_init raises on an incompatible vocabulary and serving
# unspeculated, which is the failure this terminal state exists for.
silent_output=$work/silent-run
if QWEN_MODEL_REGISTRY=$registry \
    QWEN_QUARANTINE_REGISTRY=$quarantine \
    QWEN_DRAFT_PAIRS=$pairs \
    QWEN_MODELS_DIRECTORY=$model_root \
    QWEN_PRODUCTION_BUILD_DIR=$build_directory \
    QWEN_DRAFT_PAIR_PORT=$server_port \
    QWEN_SERVER_PORT=$server_port \
    QWEN_DRAFT_PAIR_PREDICT=128 \
    QWEN_DRAFT_PAIR_READY_SECONDS=20 \
    QWEN_FAKE_SERVER_PORT=$server_port \
    QWEN_FAKE_SERVER_STATE_DIRECTORY=$silent_output/argv \
    QWEN_FAKE_SERVER_DRAFT_N=0 \
    QWEN_FAKE_SERVER_DRAFT_ACCEPTED=0 \
        "$harness" fake-pair "$silent_output" \
        >"$work/silent.stdout" 2>"$work/silent.stderr"; then
    report silent_draft_refused rejected
else
    if grep -Fx 'state=failed' "$silent_output/summary.txt" >/dev/null &&
       grep -Fx 'reason=draft_absent' "$silent_output/summary.txt" \
           >/dev/null &&
       ! grep -q '^pair_over_control=' "$silent_output/summary.txt"; then
        report silent_draft_refused accepted
    else
        report silent_draft_refused rejected
        cat "$silent_output/summary.txt" >&2
    fi
fi

if [ "$failures" -eq 0 ]; then
    printf 'measure_draft_pair=accepted\n'
    exit 0
fi
printf 'measure_draft_pair=rejected failures=%s\n' "$failures" >&2
exit 1
