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
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
work=$(mktemp -d "$repository_root/.test-measure-draft-pair.XXXXXX")
port_lease_holder_pid=''
release_port_lease() {
    if [ -n "$port_lease_holder_pid" ]; then
        "$script_directory/test-port-lease.sh" release \
            "$port_lease_holder_pid" || true
        port_lease_holder_pid=''
    fi
}
trap 'release_port_lease; rm -rf "$work"' EXIT INT TERM
failures=0

# The production runner binds its parser and registry to sibling programs. The
# fixture copies that complete tool set under the same Git worktree so program
# ownership and source-revision recording remain production-identical.
tool_directory=$work/tools
mkdir -p "$tool_directory"
cp -- "$script_directory/measure-draft-pair.sh" "$script_directory/qwen-home.sh" \
    "$script_directory/summarize-draft-pair.py" \
    "$script_directory/model-registry.sh" "$tool_directory/"
chmod 0755 "$tool_directory/measure-draft-pair.sh" \
    "$tool_directory/model-registry.sh"
harness=$tool_directory/measure-draft-pair.sh

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

# A fabricated registry, pair ledger, and model root, so the harness runs
# without weights and without the device.
registry=$work/models.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fake-target research Target/target.gguf fetch.sh 4096 8192 8192 \
    q8_0 q4_0 on none - - - untested production 128 32 4096 - unmeasured refused - \
    >"$registry"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fake-draft research Draft/draft.gguf fetch.sh 4096 8192 8192 \
    q8_0 q4_0 on none - - - untested candidate 128 32 4096 - unmeasured refused - \
    >>"$registry"
quarantine=$work/quarantine.tsv
: >"$quarantine"
model_root=$work/models
mkdir -p "$model_root/Target" "$model_root/Draft"
printf 'target' >"$model_root/Target/target.gguf"
printf 'draft' >"$model_root/Draft/draft.gguf"

pairs=$work/draft-pairs.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fake-pair fake-target fake-draft candidate 2 0.00 0.700 4096 q8_0 q4_0 - \
    'target plus draft' \
    >"$pairs"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    stopped-pair fake-target fake-draft quarantine 2 0.00 0.700 4096 q8_0 q4_0 - \
    'retired pairing' \
    >>"$pairs"

build_directory=$work/build
mkdir -p "$build_directory/bin"
cp "$script_directory/test-fixtures/fake-llama-server.sh" \
    "$build_directory/bin/llama-server"
chmod 0755 "$build_directory/bin/llama-server"

# The production harness carries every arm through the absolute-priority and
# Vulkan-profile wrappers. These stand-ins preserve the exec chain, record its
# order and inherited environment, and keep this test independent of the
# workstation's CPU numbering and kernel priority permissions.
wrapper_directory=$work/wrappers
mkdir -p "$wrapper_directory"
priority_wrapper=$wrapper_directory/priority-wrapper.sh
vulkan_wrapper=$wrapper_directory/vulkan-wrapper.sh
cat >"$priority_wrapper" <<'WRAPPER'
#!/bin/sh
set -eu
printf 'priority command=%s\n' "$1" >>"${QWEN_DRAFT_PAIR_WRAPPER_LOG:?}"
if [ -n "${QWEN_DRAFT_PAIR_MUTATE_PATH:-}" ] &&
   [ ! -e "${QWEN_DRAFT_PAIR_MUTATE_MARKER:?}" ]; then
    printf 'mutated' >>"$QWEN_DRAFT_PAIR_MUTATE_PATH"
    : >"$QWEN_DRAFT_PAIR_MUTATE_MARKER"
fi
exec "$@"
WRAPPER
cat >"$vulkan_wrapper" <<'WRAPPER'
#!/bin/sh
set -eu
printf 'vulkan command=%s profile=%s strict=%s\n' "$1" \
    "${QWEN_VULKAN_PROFILE:-unset}" "${LLAMA_NO_CPU_FALLBACK:-unset}" \
    >>"${QWEN_DRAFT_PAIR_WRAPPER_LOG:?}"
export GGML_VK_LOW_PRIORITY=1
exec "$@"
WRAPPER
chmod 0755 "$priority_wrapper" "$vulkan_wrapper"
wrapper_log=$work/wrapper-chain.log
workload_lock=$work/vulkan-workload.lock

# Cooperating fake-network tests hold one host-wide lease before selecting
# released loopback ports. Concurrent repository gates cannot impersonate one
# another between allocation and listener startup.
network_fixture_lock=${TMPDIR:-/tmp}/qwen-apu-test-measure-draft-pair-network.lock
exec 7>"$network_fixture_lock"
flock 7

# Two leased loopback ports carry the measurement listener and the alternate
# appliance listener. Binding port zero and closing the socket reported numbers
# this fixture owned for an instant and released before the fake servers bound
# them; the lease is an exclusive flock a holder process keeps for this
# script's whole run, and the fake servers bind the ports themselves, so the
# lease rather than an inherited socket is what reserves them.
port_lease_ports_file=$work/leased-ports
port_lease_holder_pid=$("$script_directory/test-port-lease.sh" claim 2 \
    "$port_lease_ports_file")
server_port=$(sed -n 1p "$port_lease_ports_file")
unused_appliance_port=$(sed -n 2p "$port_lease_ports_file")
if [ "$server_port" = "$unused_appliance_port" ]; then
    printf 'fake network fixture leased one port twice: %s\n' "$server_port" >&2
    exit 1
fi
run_harness() {
    harness_measurement_port=${3:-$server_port}
    harness_appliance_port=${4:-$harness_measurement_port}
    harness_priority_wrapper=${QWEN_TEST_DRAFT_PAIR_PRIORITY_WRAPPER:-$priority_wrapper}
    harness_wrapper_log=${QWEN_TEST_DRAFT_PAIR_WRAPPER_LOG:-$wrapper_log}
    harness_program=${QWEN_TEST_DRAFT_PAIR_HARNESS:-$harness}
    QWEN_MODEL_REGISTRY=$registry \
    QWEN_QUARANTINE_REGISTRY=$quarantine \
    QWEN_DRAFT_PAIRS=$pairs \
    QWEN_MODELS_DIRECTORY=$model_root \
    QWEN_PRODUCTION_BUILD_DIR=$build_directory \
    QWEN_DRAFT_PAIR_PRIORITY_WRAPPER=$harness_priority_wrapper \
    QWEN_DRAFT_PAIR_VULKAN_WRAPPER=$vulkan_wrapper \
    QWEN_DRAFT_PAIR_WRAPPER_LOG=$harness_wrapper_log \
    QWEN_VULKAN_WORKLOAD_LOCK=$workload_lock \
    QWEN_DRAFT_PAIR_PORT=$harness_measurement_port \
    QWEN_SERVER_PORT=$harness_appliance_port \
    QWEN_DRAFT_PAIR_PREDICT=128 \
    QWEN_DRAFT_PAIR_READY_SECONDS=20 \
    QWEN_FAKE_SERVER_PORT=$harness_measurement_port \
    QWEN_FAKE_SERVER_STATE_DIRECTORY=$1/argv \
    QWEN_FAKE_SERVER_REQUEST_DIRECTORY=$1/wire-requests \
    QWEN_FAKE_SERVER_DECODE_TOK_S=3.00 \
    QWEN_FAKE_SERVER_DECODE_TOK_S_SPEC=3.60 \
    QWEN_FAKE_SERVER_DRAFT_N=64 \
    QWEN_FAKE_SERVER_DRAFT_ACCEPTED=48 \
        "$harness_program" "$2" "$1"
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

# The measurement port remains guarded when the appliance uses another port.
# This is the production default and the case that could otherwise accept all
# four arms from a resident process while the launched wrapper never binds.
measurement_resident_output=$work/measurement-resident-run
if run_harness "$measurement_resident_output" fake-pair \
       "$server_port" "$unused_appliance_port" \
       >"$work/measurement-resident.stdout" \
       2>"$work/measurement-resident.stderr"; then
    report measurement_port_resident_refused rejected
else
    if grep -F "a server answers /health on port $server_port" \
           "$work/measurement-resident.stderr" >/dev/null &&
       [ ! -e "$wrapper_log" ]; then
        report measurement_port_resident_refused accepted
    else
        report measurement_port_resident_refused rejected
        cat "$work/measurement-resident.stderr" >&2
    fi
fi
kill -TERM "$resident_pid" 2>/dev/null || true
wait "$resident_pid" 2>/dev/null || true

# The measurement requires exclusive ownership of the repository-wide Vulkan
# execution surface before it claims an output path or starts a server.
exec 8>"$workload_lock"
flock -n 8
competing_lock_output=$work/competing-lock-run
if run_harness "$competing_lock_output" fake-pair \
       >"$work/competing-lock.stdout" 2>"$work/competing-lock.stderr"; then
    report competing_workload_lock_refused rejected
else
    if grep -F 'another Vulkan workload holds the shared lease' \
           "$work/competing-lock.stderr" >/dev/null &&
       [ ! -e "$competing_lock_output" ]; then
        report competing_workload_lock_refused accepted
    else
        report competing_workload_lock_refused rejected
        cat "$work/competing-lock.stderr" >&2
    fi
fi
flock -u 8
exec 8>&-

# A process that appears after preflight cannot impersonate the launched exec
# chain. The wrapper stays alive while its child owns the listener, reproducing
# the race without running the intended server.
foreign_listener_wrapper=$wrapper_directory/foreign-listener-wrapper.sh
cat >"$foreign_listener_wrapper" <<'WRAPPER'
#!/bin/sh
set -eu
foreign_listener_pid=''
cleanup_foreign_listener() {
    [ -n "$foreign_listener_pid" ] || return 0
    kill -TERM "$foreign_listener_pid" 2>/dev/null || true
    wait "$foreign_listener_pid" 2>/dev/null || true
}
trap cleanup_foreign_listener EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 - "${QWEN_FAKE_SERVER_PORT:?}" <<'PY' &
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *arguments):
        pass

    def do_GET(self):
        body = b"ok"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
PY
foreign_listener_pid=$!
while ! curl --silent --fail --max-time 1 \
    "http://127.0.0.1:${QWEN_FAKE_SERVER_PORT:?}/health" >/dev/null 2>&1; do
    kill -0 "$foreign_listener_pid"
    sleep 1
done
sleep 30
WRAPPER
chmod 0755 "$foreign_listener_wrapper"
foreign_readiness_output=$work/foreign-readiness-run
if QWEN_TEST_DRAFT_PAIR_PRIORITY_WRAPPER=$foreign_listener_wrapper \
       run_harness "$foreign_readiness_output" fake-pair \
       >"$work/foreign-readiness.stdout" \
       2>"$work/foreign-readiness.stderr"; then
    report foreign_readiness_refused rejected
else
    if grep -F 'owns no loopback listener' \
           "$work/foreign-readiness.stderr" >/dev/null &&
       ! curl --silent --fail --max-time 1 \
           "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
        report foreign_readiness_refused accepted
    else
        report foreign_readiness_refused rejected
        cat "$work/foreign-readiness.stderr" >&2
    fi
fi

# The launched server owns readiness, then closes its listening socket during
# the first completion while a foreign server takes the same port. The request
# response remains valid, but the post-request process/listener check rejects
# the replacement before another response enters the retained corpus.
takeover_request_marker=$work/takeover-requested
takeover_ready_marker=$work/takeover-ready
python3 - "$server_port" "$takeover_request_marker" \
    "$takeover_ready_marker" <<'PY' &
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

port = int(sys.argv[1])
request_marker = Path(sys.argv[2])
ready_marker = Path(sys.argv[3])

while not request_marker.exists():
    time.sleep(0.01)


class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *arguments):
        pass

    def do_GET(self):
        body = b"foreign"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


server = ReusableHTTPServer(("127.0.0.1", port), Handler)
ready_marker.write_text("ready\n")
server.serve_forever()
PY
takeover_pid=$!
takeover_output=$work/post-readiness-takeover-run
if QWEN_FAKE_SERVER_TAKEOVER_REQUEST_MARKER=$takeover_request_marker \
   QWEN_FAKE_SERVER_TAKEOVER_READY_MARKER=$takeover_ready_marker \
   QWEN_TEST_DRAFT_PAIR_WRAPPER_LOG=$work/takeover-wrapper.log \
       run_harness "$takeover_output" fake-pair \
       >"$work/post-readiness-takeover.stdout" \
       2>"$work/post-readiness-takeover.stderr"; then
    report post_readiness_listener_takeover_refused rejected
else
    if grep -F 'after completion request control-open/code' \
           "$work/post-readiness-takeover.stderr" >/dev/null &&
       [ -e "$takeover_ready_marker" ] &&
       curl --silent --fail --max-time 1 \
           "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
        report post_readiness_listener_takeover_refused accepted
    else
        report post_readiness_listener_takeover_refused rejected
        cat "$work/post-readiness-takeover.stderr" >&2
    fi
fi
kill -TERM "$takeover_pid" 2>/dev/null || true
wait "$takeover_pid" 2>/dev/null || true

# The same launched PID can close and rebind its port after serving a request.
# PID and start time still match, so only listener-inode continuity detects the
# replacement endpoint.
completion_rebind_output=$work/completion-rebind-run
if QWEN_FAKE_SERVER_REBIND_ON_COMPLETION=1 \
   QWEN_TEST_DRAFT_PAIR_WRAPPER_LOG=$work/completion-rebind-wrapper.log \
       run_harness "$completion_rebind_output" fake-pair \
       >"$work/completion-rebind.stdout" \
       2>"$work/completion-rebind.stderr"; then
    report completion_listener_rebind_refused rejected
else
    if grep -F 'listener inode changed at after completion request control-open/code' \
           "$work/completion-rebind.stderr" >/dev/null &&
       awk -F'\t' 'NR == 2 && $5 == "rejected" { found = 1 } \
           END { exit found ? 0 : 1 }' \
           "$completion_rebind_output/control-open/code.listener.tsv"; then
        report completion_listener_rebind_refused accepted
    else
        report completion_listener_rebind_refused rejected
        cat "$work/completion-rebind.stderr" >&2
    fi
fi

# The health request receives the same continuity check after all prompt
# requests. A same-PID rebind during that exchange remains a terminal arm.
health_rebind_output=$work/health-rebind-run
if QWEN_FAKE_SERVER_REBIND_ON_POST_HEALTH=1 \
   QWEN_TEST_DRAFT_PAIR_WRAPPER_LOG=$work/health-rebind-wrapper.log \
       run_harness "$health_rebind_output" fake-pair \
       >"$work/health-rebind.stdout" \
       2>"$work/health-rebind.stderr"; then
    report health_listener_rebind_refused rejected
else
    if grep -F 'listener inode changed at after post-arm health check control-open' \
           "$work/health-rebind.stderr" >/dev/null; then
        report health_listener_rebind_refused accepted
    else
        report health_listener_rebind_refused rejected
        cat "$work/health-rebind.stderr" >&2
    fi
fi

# The measured run. Four arms in the order control, pair, pair, control, three
# prompts each, and the summary reads the pair against its own controls.
measured_output=$work/measured-run
QWEN_DRAFT_PAIR_SUMMARIZER=/bin/false \
QWEN_MODEL_REGISTRY_SCRIPT=/bin/false \
    run_harness "$measured_output" fake-pair >"$work/measured.stdout" \
    2>"$work/measured.stderr"
measured_wrapper_log=$work/measured-wrapper-chain.log
cp -- "$wrapper_log" "$measured_wrapper_log"

if grep -Fx "summarizer_source=$tool_directory/summarize-draft-pair.py" \
       "$measured_output/inputs.txt" >/dev/null; then
    report sibling_program_ownership accepted
else
    report sibling_program_ownership rejected
    cat "$measured_output/inputs.txt" >&2
fi

retained_summary_sha256=$(sha256sum "$measured_output/summary.txt" | awk '{ print $1 }')
if run_harness "$measured_output" fake-pair >"$work/reuse.stdout" \
       2>"$work/reuse.stderr"; then
    report nonempty_output_refused rejected
else
    repeated_summary_sha256=$(sha256sum "$measured_output/summary.txt" | awk '{ print $1 }')
    if grep -F 'output path must be absent for one immutable measurement' \
           "$work/reuse.stderr" >/dev/null &&
       [ "$retained_summary_sha256" = "$repeated_summary_sha256" ]; then
        report nonempty_output_refused accepted
    else
        report nonempty_output_refused rejected
        cat "$work/reuse.stderr" >&2
    fi
fi

# The output claim precedes every artifact hash. A wrapped sha256sum that tries
# the former check-then-mkdir race observes an already owned directory.
hash_wrapper_directory=$work/hash-wrapper
mkdir -p "$hash_wrapper_directory"
real_sha256sum=$(command -v sha256sum)
cat >"$hash_wrapper_directory/sha256sum" <<'WRAPPER'
#!/bin/sh
set -eu
if [ ! -e "${QWEN_OUTPUT_RACE_MARKER:?}" ]; then
    if mkdir -- "${QWEN_OUTPUT_RACE_PATH:?}" 2>/dev/null; then
        printf 'race-claim=accepted\n' >"$QWEN_OUTPUT_RACE_MARKER"
    else
        printf 'race-claim=rejected\n' >"$QWEN_OUTPUT_RACE_MARKER"
    fi
fi
exec "${QWEN_REAL_SHA256SUM:?}" "$@"
WRAPPER
chmod 0755 "$hash_wrapper_directory/sha256sum"
output_race_directory=$work/output-race-run
output_race_marker=$work/output-race.marker
if PATH=$hash_wrapper_directory:$PATH \
   QWEN_REAL_SHA256SUM=$real_sha256sum \
   QWEN_OUTPUT_RACE_PATH=$output_race_directory \
   QWEN_OUTPUT_RACE_MARKER=$output_race_marker \
       run_harness "$output_race_directory" fake-pair \
       >"$work/output-race.stdout" 2>"$work/output-race.stderr" &&
   grep -Fx 'race-claim=rejected' "$output_race_marker" >/dev/null &&
   grep -F 'draft_pair_measurement=completed pair=fake-pair output_directory=' \
       "$work/output-race.stdout" >/dev/null; then
    report output_claim_precedes_hashing accepted
else
    report output_claim_precedes_hashing rejected
    cat "$work/output-race.stderr" >&2
fi

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

expected_arms_header=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
    arm mode prompt predicted_n decode_tok_s drafted accepted acceptance \
    target_steps tokens_per_target_step token_sha256 request_sha256 \
    prompt_identity request_identity response_sha256 listener_identity)
if [ "$(sed -n '1p' "$measured_output/arms.tsv")" = "$expected_arms_header" ]; then
    report arms_schema accepted
else
    report arms_schema rejected
    sed -n '1p' "$measured_output/arms.tsv" >&2
fi

retained_request_hashes=$(find "$measured_output" -mindepth 2 -maxdepth 2 \
    -type f -name '*.request.json' -exec sha256sum {} + | awk '{ print $1 }' | sort)
wire_request_hashes=$(find "$measured_output/wire-requests" -type f \
    -name 'request-*.bin' -exec sha256sum {} + | awk '{ print $1 }' | sort)
if [ "$(printf '%s\n' "$retained_request_hashes" | wc -l)" -eq 12 ] &&
   [ "$retained_request_hashes" = "$wire_request_hashes" ]; then
    report request_body_identity accepted
else
    report request_body_identity rejected
    printf 'retained request hashes:\n%s\nwire request hashes:\n%s\n' \
        "$retained_request_hashes" "$wire_request_hashes" >&2
fi

# The four speculation quantities are derived from the two the server reports:
# 64 drafted with 48 accepted is an acceptance of 0.750, and 128 predicted
# tokens include one token from the prompt logits before 79 target steps.
# Those steps emit 127 tokens at a mean accepted length of 1.61.
pair_row=$(awk -F'\t' '$1 == "pair-first" && $3 == "code"' \
    "$measured_output/arms.tsv")
pair_acceptance=$(printf '%s\n' "$pair_row" | cut -f8)
pair_target_steps=$(printf '%s\n' "$pair_row" | cut -f9)
pair_tokens_per_target_step=$(printf '%s\n' "$pair_row" | cut -f10)
pair_rate=$(printf '%s\n' "$pair_row" | cut -f5)
if [ "$pair_acceptance" = 0.750 ] && [ "$pair_target_steps" = 79 ] &&
   [ "$pair_tokens_per_target_step" = 1.61 ] && [ "$pair_rate" = 3.60 ]; then
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

wrapper_chain_state=accepted
if [ "$(grep -c '^priority command=' "$measured_wrapper_log")" != 4 ] ||
   [ "$(grep -c '^vulkan command=' "$measured_wrapper_log")" != 4 ]; then
    wrapper_chain_state=rejected
fi
if ! awk -v priority="priority command=$vulkan_wrapper" \
    -v vulkan="vulkan command=$build_directory/bin/llama-server profile=low-async strict=1" '
    NR % 2 == 1 && $0 != priority { bad = 1 }
    NR % 2 == 0 && $0 != vulkan { bad = 1 }
    END { exit bad ? 1 : 0 }
' "$measured_wrapper_log"; then
    wrapper_chain_state=rejected
fi
if ! grep -Fx 'vulkan_profile=low-async' "$measured_output/inputs.txt" \
    >/dev/null ||
   ! grep -Fx 'low=1' "$measured_output"/argv/argv-*.txt >/dev/null ||
   ! grep -Eq '^(server|priority_wrapper|vulkan_profile_wrapper)_sha256=[0-9a-f]{64}$' \
       "$measured_output/inputs.txt"; then
    wrapper_chain_state=rejected
fi
report wrapper_chain "$wrapper_chain_state"
if [ "$wrapper_chain_state" = rejected ]; then
    cat "$measured_wrapper_log" >&2
fi

identity_state=accepted
if ! grep -Eq '^(target_model|draft_model)_sha256=[0-9a-f]{64}$' \
        "$measured_output/inputs.txt" ||
   ! grep -Eq '^source_revision=[0-9a-f]{40,64}$' \
       "$measured_output/inputs.txt" ||
   ! grep -Eq '^(registry|model_registry|draft_pair_registry|quarantine_registry)_(source|retained)_sha256=[0-9a-f]{64}$' \
       "$measured_output/inputs.txt" ||
   ! grep -Eq '^(measurement_runner|measurement_runner_retained|summarizer|summarizer_retained)_sha256=[0-9a-f]{64}$' \
       "$measured_output/inputs.txt" ||
   ! grep -Fx 'target_model_bytes=6' "$measured_output/inputs.txt" >/dev/null ||
   ! grep -Fx 'draft_model_bytes=5' "$measured_output/inputs.txt" >/dev/null ||
   ! grep -Eq '^prompt_corpus_sha256=[0-9a-f]{64}$' \
       "$measured_output/inputs.txt" ||
   ! awk -F'\t' 'NR == 2 && $6 == "accepted" { found = 1 } \
        END { exit found ? 0 : 1 }' \
       "$measured_output/summarizer-execution-check.tsv" ||
   [ "$(awk -F'\t' 'NR > 1 && $7 == "accepted" { count++ } END { print count + 0 }' \
        "$measured_output/identity-check.tsv")" -ne 18 ] ||
   [ "$(awk -F'\t' 'NR > 1 && $4 == "accepted" { count++ } END { print count + 0 }' \
        "$measured_output/source-revision-check.tsv")" -ne 1 ] ||
   [ "$(awk -F'\t' '
        NR > 1 && $1 ~ /^(measurement-runner|summarizer)-(source|retained)$/ &&
        $7 == "accepted" { count++ }
        END { print count + 0 }
    ' "$measured_output/identity-check.tsv")" -ne 4 ] ||
   [ "$(awk -F'\t' 'NR > 1 && $13 == "accepted" && $14 == "accepted" && $16 == "accepted" { count++ } END { print count + 0 }' \
        "$measured_output/arms.tsv")" -ne 12 ]; then
    identity_state=rejected
fi
report artifact_identity "$identity_state"
if [ "$identity_state" = rejected ]; then
    cat "$measured_output/inputs.txt" \
        "$measured_output/source-revision-check.tsv" \
        "$measured_output/identity-check.tsv" >&2
fi

if grep -Fx 'acceptance_gate=accepted' "$measured_output/summary.txt" \
    >/dev/null &&
   grep -Fx 'performance_gate=accepted' "$measured_output/summary.txt" \
       >/dev/null &&
   grep -Fx 'admission_gate=accepted' "$measured_output/summary.txt" \
       >/dev/null; then
    report admission_gates accepted
else
    report admission_gates rejected
    cat "$measured_output/summary.txt" >&2
fi

token_mismatch_output=$work/token-mismatch-run
QWEN_FAKE_SERVER_TOKENS_SPEC='20 21 22 23' \
    run_harness "$token_mismatch_output" fake-pair \
    >"$work/token-mismatch.stdout" 2>"$work/token-mismatch.stderr"
if grep -Fx 'token_identity_gate=rejected' \
       "$token_mismatch_output/summary.txt" >/dev/null &&
   grep -Fx 'admission_gate=retry-n-max-1' \
       "$token_mismatch_output/summary.txt" >/dev/null; then
    report token_divergence_refused accepted
else
    report token_divergence_refused rejected
    cat "$token_mismatch_output/summary.txt" >&2
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
    QWEN_DRAFT_PAIR_PRIORITY_WRAPPER=$priority_wrapper \
    QWEN_DRAFT_PAIR_VULKAN_WRAPPER=$vulkan_wrapper \
    QWEN_DRAFT_PAIR_WRAPPER_LOG=$wrapper_log \
    QWEN_VULKAN_WORKLOAD_LOCK=$workload_lock \
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

# The external prompt path may change after the snapshot without changing any
# retained request. The snapshot becomes the corpus authority for the run.
external_prompt=$work/external-prompts.tsv
printf 'stable\tstable prompt\n' >"$external_prompt"
external_prompt_marker=$work/external-prompt-change.marker
external_prompt_output=$work/external-prompt-run
if QWEN_DRAFT_PAIR_PROMPTS=$external_prompt \
   QWEN_DRAFT_PAIR_MUTATE_PATH=$external_prompt \
   QWEN_DRAFT_PAIR_MUTATE_MARKER=$external_prompt_marker \
       run_harness "$external_prompt_output" fake-pair \
       >"$work/external-prompt.stdout" 2>"$work/external-prompt.stderr" &&
   awk -F'\t' '
       NR == 1 && NF == 2 && $1 == "stable" && $2 == "stable prompt" {
           found = 1
       }
       END { exit found ? 0 : 1 }
   ' "$external_prompt_output/prompts.tsv" &&
   [ "$(python3 - "$external_prompt_output" <<'PY'
import json
import sys
from pathlib import Path

requests = Path(sys.argv[1]).glob("*/*.request.json")
print(sum(json.loads(path.read_text())["prompt"] == "stable prompt" for path in requests))
PY
)" = 4 ]; then
    report external_prompt_mutation_isolated accepted
else
    report external_prompt_mutation_isolated rejected
    cat "$work/external-prompt.stderr" >&2
fi

# Mutation of the retained snapshot itself remains terminal even where every
# request uses the same changed bytes.
prompt_identity_output=$work/prompt-identity-change-run
prompt_identity_marker=$work/prompt-identity-change.marker
if QWEN_DRAFT_PAIR_MUTATE_PATH=$prompt_identity_output/prompts.tsv \
   QWEN_DRAFT_PAIR_MUTATE_MARKER=$prompt_identity_marker \
       run_harness "$prompt_identity_output" fake-pair \
       >"$work/prompt-identity-change.stdout" \
       2>"$work/prompt-identity-change.stderr"; then
    report prompt_identity_change_refused rejected
else
    if awk -F'\t' '$1 == "prompt-corpus" && $7 == "rejected" { found = 1 } \
            END { exit found ? 0 : 1 }' \
            "$prompt_identity_output/identity-check.tsv" &&
       grep -F 'artifact identity changed during measurement' \
           "$work/prompt-identity-change.stderr" >/dev/null; then
        report prompt_identity_change_refused accepted
    else
        report prompt_identity_change_refused rejected
        cat "$work/prompt-identity-change.stderr" >&2
    fi
fi

# The sibling summarizer may change after the runner finishes its identity pass.
# The final Python launch targets the retained verified copy, so that source
# mutation cannot replace the arithmetic that writes summary.txt.
mutation_tool_directory=$work/mutation-tools
mkdir -p "$mutation_tool_directory"
cp -- "$script_directory/measure-draft-pair.sh" "$script_directory/qwen-home.sh" \
    "$script_directory/summarize-draft-pair.py" \
    "$script_directory/model-registry.sh" "$mutation_tool_directory/"
chmod 0755 "$mutation_tool_directory/measure-draft-pair.sh" \
    "$mutation_tool_directory/model-registry.sh"
mutable_harness=$mutation_tool_directory/measure-draft-pair.sh
mutable_summarizer=$mutation_tool_directory/summarize-draft-pair.py
python_wrapper_directory=$work/python-wrapper
mkdir -p "$python_wrapper_directory"
real_python3=$(command -v python3)
cat >"$python_wrapper_directory/python3" <<'WRAPPER'
#!/bin/sh
set -eu
if { [ "${1:-}" = "${QWEN_SUMMARIZER_RETAINED_PATH:-}" ] ||
     [ "${2:-}" = "${QWEN_SUMMARIZER_RETAINED_PATH:-}" ]; } &&
   [ ! -e "${QWEN_SUMMARIZER_MUTATION_MARKER:?}" ]; then
    printf '\nraise RuntimeError("mutated source summarizer executed")\n' \
        >>"${QWEN_SUMMARIZER_MUTATION_SOURCE:?}"
    : >"$QWEN_SUMMARIZER_MUTATION_MARKER"
fi
exec "${QWEN_REAL_PYTHON3:?}" "$@"
WRAPPER
chmod 0755 "$python_wrapper_directory/python3"
summarizer_mutation_output=$work/summarizer-mutation-run
summarizer_mutation_marker=$work/summarizer-mutation.marker
if PATH=$python_wrapper_directory:$PATH \
   QWEN_REAL_PYTHON3=$real_python3 \
   QWEN_SUMMARIZER_RETAINED_PATH=$summarizer_mutation_output/summarize-draft-pair.py \
   QWEN_SUMMARIZER_MUTATION_SOURCE=$mutable_summarizer \
   QWEN_SUMMARIZER_MUTATION_MARKER=$summarizer_mutation_marker \
   QWEN_TEST_DRAFT_PAIR_HARNESS=$mutable_harness \
   QWEN_TEST_DRAFT_PAIR_WRAPPER_LOG=$work/summarizer-mutation-wrapper.log \
       run_harness "$summarizer_mutation_output" fake-pair \
       >"$work/summarizer-mutation.stdout" \
       2>"$work/summarizer-mutation.stderr" &&
   [ -e "$summarizer_mutation_marker" ] &&
   grep -F 'mutated source summarizer executed' "$mutable_summarizer" \
       >/dev/null &&
   grep -Fx "summarizer_source=$mutable_summarizer" \
       "$summarizer_mutation_output/inputs.txt" >/dev/null &&
   awk -F'\t' '$1 == "summarizer-retained" && $7 == "accepted" { found = 1 }
       END { exit found ? 0 : 1 }' \
       "$summarizer_mutation_output/identity-check.tsv" &&
   grep -Fx 'state=completed' \
       "$summarizer_mutation_output/summary.txt" >/dev/null; then
    report postcheck_summarizer_mutation_isolated accepted
else
    report postcheck_summarizer_mutation_isolated rejected
    cat "$work/summarizer-mutation.stderr" >&2
fi

# A mutation of the retained parser after identity-check.tsv is written remains
# terminal. The in-memory launcher hashes the one byte sequence it executes and
# retains that final decision separately.
retained_mutation_tool_directory=$work/retained-mutation-tools
mkdir -p "$retained_mutation_tool_directory"
cp -- "$script_directory/measure-draft-pair.sh" "$script_directory/qwen-home.sh" \
    "$script_directory/summarize-draft-pair.py" \
    "$script_directory/model-registry.sh" "$retained_mutation_tool_directory/"
chmod 0755 "$retained_mutation_tool_directory/measure-draft-pair.sh" \
    "$retained_mutation_tool_directory/model-registry.sh"
retained_mutation_harness=$retained_mutation_tool_directory/measure-draft-pair.sh
retained_mutation_output=$work/retained-summarizer-mutation-run
retained_mutation_marker=$work/retained-summarizer-mutation.marker
retained_mutation_path=$retained_mutation_output/summarize-draft-pair.py
if PATH=$python_wrapper_directory:$PATH \
   QWEN_REAL_PYTHON3=$real_python3 \
   QWEN_SUMMARIZER_RETAINED_PATH=$retained_mutation_path \
   QWEN_SUMMARIZER_MUTATION_SOURCE=$retained_mutation_path \
   QWEN_SUMMARIZER_MUTATION_MARKER=$retained_mutation_marker \
   QWEN_TEST_DRAFT_PAIR_HARNESS=$retained_mutation_harness \
   QWEN_TEST_DRAFT_PAIR_WRAPPER_LOG=$work/retained-mutation-wrapper.log \
       run_harness "$retained_mutation_output" fake-pair \
       >"$work/retained-mutation.stdout" \
       2>"$work/retained-mutation.stderr"; then
    report retained_summarizer_mutation_refused rejected
else
    if [ -e "$retained_mutation_marker" ] &&
       awk -F'\t' 'NR == 2 && $6 == "rejected" { found = 1 } \
           END { exit found ? 0 : 1 }' \
           "$retained_mutation_output/summarizer-execution-check.tsv" &&
       grep -F 'summarizer identity changed before execution' \
           "$work/retained-mutation.stderr" >/dev/null; then
        report retained_summarizer_mutation_refused accepted
    else
        report retained_summarizer_mutation_refused rejected
        cat "$work/retained-mutation.stderr" >&2
    fi
fi

identity_change_output=$work/identity-change-run
identity_change_marker=$work/identity-change.marker
if QWEN_DRAFT_PAIR_MUTATE_PATH=$model_root/Draft/draft.gguf \
   QWEN_DRAFT_PAIR_MUTATE_MARKER=$identity_change_marker \
       run_harness "$identity_change_output" fake-pair \
       >"$work/identity-change.stdout" 2>"$work/identity-change.stderr"; then
    report identity_change_refused rejected
else
    if awk -F'\t' '$1 == "draft-model" && $7 == "rejected" { found = 1 } \
            END { exit found ? 0 : 1 }' \
            "$identity_change_output/identity-check.tsv" &&
       grep -F 'artifact identity changed during measurement' \
           "$work/identity-change.stderr" >/dev/null; then
        report identity_change_refused accepted
    else
        report identity_change_refused rejected
        cat "$work/identity-change.stderr" >&2
    fi
fi

# Every model and pair query consumes the retained ledger snapshots. A source
# pair ledger mutation after server launch cannot change the tuple, and final
# identity reconciliation still makes the concurrent authority change terminal.
registry_identity_output=$work/registry-identity-change-run
registry_identity_marker=$work/registry-identity-change.marker
if QWEN_DRAFT_PAIR_MUTATE_PATH=$pairs \
   QWEN_DRAFT_PAIR_MUTATE_MARKER=$registry_identity_marker \
       run_harness "$registry_identity_output" fake-pair \
       >"$work/registry-identity-change.stdout" \
       2>"$work/registry-identity-change.stderr"; then
    report registry_identity_change_refused rejected
else
    if awk -F'\t' '
            $1 == "draft-pair-registry-source" && $7 == "rejected" {
                source_rejected = 1
            }
            $1 == "draft-pair-registry-retained" && $7 == "accepted" {
                retained_accepted = 1
            }
            END { exit source_rejected && retained_accepted ? 0 : 1 }
        ' "$registry_identity_output/identity-check.tsv" &&
       grep -F 'artifact identity changed during measurement' \
           "$work/registry-identity-change.stderr" >/dev/null; then
        report registry_identity_change_refused accepted
    else
        report registry_identity_change_refused rejected
        cat "$work/registry-identity-change.stderr" >&2
    fi
fi

if [ "$failures" -eq 0 ]; then
    printf 'measure_draft_pair=accepted\n'
    exit 0
fi
printf 'measure_draft_pair=rejected failures=%s\n' "$failures" >&2
exit 1
