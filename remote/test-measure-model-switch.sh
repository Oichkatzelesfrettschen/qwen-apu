#!/bin/sh
set -eu

# The switch harness against a fake router and a synthetic server log.
#
# What the harness claims is row shape and attribution: one row per switch, the
# two served ids alternating, a `-` where the request was refused rather than a
# zero, and the router lines that landed inside each request's own byte window
# rather than whatever the log held before it. A fake router answers instantly,
# so the timings this arm produces measure the fixture and the assertions read
# the structure alone.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
router_pid=''
port_lease_holder_pid=''
cleanup_fixture() {
    if [ -n "$router_pid" ]; then
        kill -TERM "$router_pid" 2>/dev/null || true
        wait "$router_pid" 2>/dev/null || true
    fi
    if [ -n "$port_lease_holder_pid" ]; then
        "$script_directory/test-port-lease.sh" release \
            "$port_lease_holder_pid" || true
    fi
    rm -rf "$temporary_directory"
}
trap cleanup_fixture EXIT HUP INT TERM

fail() {
    printf 'test-measure-model-switch: %s\n' "$1" >&2
    exit 1
}

ports_file=$temporary_directory/leased-ports
port_lease_holder_pid=$("$script_directory/test-port-lease.sh" claim 1 "$ports_file")
router_port=$(sed -n 1p "$ports_file")

server_log=$temporary_directory/server.log
# The log the harness reads is written by the fake router as each request
# arrives, so a line lands inside the window of the request that caused it the
# way the router's own eviction lines do.
cat >"$temporary_directory/fake-router.py" <<'ROUTER'
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
log_path = sys.argv[2]
refuse_index = int(os.environ.get("FIXTURE_REFUSE_INDEX", "0"))
served = ["model-a", "model-b"]
state = {"count": 0, "loaded": None}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *arguments):
        pass

    def respond(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/v1/models"):
            self.respond({"data": [{"id": name} for name in served]})
            return
        self.send_error(404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length).decode() or "{}")
        requested = body.get("model")
        state["count"] += 1
        with open(log_path, "a", encoding="utf-8") as handle:
            if state["loaded"] is not None and state["loaded"] != requested:
                handle.write(
                    "srv  update_slots: evicting idle LRU name=%s to make room "
                    "for name=%s\n" % (state["loaded"], requested)
                )
            handle.write("srv  router: model name=%s is not loaded, loading...\n"
                         % requested)
            handle.write("srv  router: waiting until model name=%s is fully "
                         "loaded...\n" % requested)
        state["loaded"] = requested
        if refuse_index and state["count"] == refuse_index:
            self.send_error(503)
            return
        self.respond({
            "choices": [{"message": {"role": "assistant", "content": "x"}}],
        })


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
ROUTER

: >"$server_log"
FIXTURE_REFUSE_INDEX=3 python3 "$temporary_directory/fake-router.py" \
    "$router_port" "$server_log" &
router_pid=$!

attempt=0
while [ "$attempt" -lt 200 ]; do
    if curl --silent --fail "http://127.0.0.1:$router_port/v1/models" \
        >/dev/null 2>&1; then
        break
    fi
    if ! kill -0 "$router_pid" 2>/dev/null; then
        fail 'the fake router left before it answered'
    fi
    attempt=$((attempt + 1))
    sleep 0.05
done
[ "$attempt" -lt 200 ] || fail 'the fake router never answered GET /v1/models'

output_directory=$temporary_directory/run
QWEN_SWITCH_ORIGIN=http://127.0.0.1:$router_port \
QWEN_SWITCH_SERVER_LOG=$server_log \
    "$script_directory/measure-model-switch.sh" "$output_directory" 4 \
    >"$temporary_directory/run.stdout" 2>"$temporary_directory/run.stderr" ||
    fail "the harness refused: $(cat "$temporary_directory/run.stderr")"

switch_tsv=$output_directory/model-switch.tsv
if [ "$(grep -c '^switch' "$switch_tsv")" != 4 ]; then
    fail 'the run recorded other than four switch rows'
fi
grep -q '^# model_switch clock=realtime .*log_clock=absent' "$switch_tsv" ||
    fail 'the header did not record an absent log clock'
# The ids alternate, which is what makes each row a switch rather than a repeat.
if [ "$(awk -F '\t' '$1 == "switch" { print $3 }' "$switch_tsv" | tr '\n' ' ')" \
    != 'model-a model-b model-a model-b ' ]; then
    fail 'the run did not alternate the two served ids'
fi
# The refused third request records `-` rather than a duration.
if [ "$(awk -F '\t' '$1 == "switch" && $2 == 3 { print $4 }' "$switch_tsv")" != - ]; then
    fail 'a refused request recorded a duration'
fi
for measured_index in 1 2 4; do
    measured_ns=$(awk -F '\t' -v index_value="$measured_index" \
        '$1 == "switch" && $2 == index_value { print $4 }' "$switch_tsv")
    case $measured_ns in
        '' | *[!0-9]*) fail "switch $measured_index recorded no nanoseconds" ;;
    esac
done
# The first request loads without evicting; every later one evicts, so the
# window attribution separates them rather than counting the whole log.
if [ "$(awk -F '\t' '$1 == "switch" && $2 == 1 { print $5 }' "$switch_tsv")" != 2 ]; then
    fail 'the first switch matched other than its own two loading lines'
fi
if [ "$(awk -F '\t' '$1 == "switch" && $2 == 2 { print $5 }' "$switch_tsv")" != 3 ]; then
    fail 'the second switch did not carry its eviction line'
fi
grep -q 'evicting idle LRU name=model-a to make room for name=model-b' \
    "$output_directory/router-lines-2.log" ||
    fail 'the retained slice lost the eviction line'
grep -q 'model_switch n=3 method=nearest-rank' "$temporary_directory/run.stdout" ||
    fail 'the summary did not report the three measured switches'

# An existing output directory is refused rather than appended to, since a
# second run inside one would mix two series under one summary.
if QWEN_SWITCH_ORIGIN=http://127.0.0.1:$router_port \
    QWEN_SWITCH_SERVER_LOG=$server_log \
    "$script_directory/measure-model-switch.sh" "$output_directory" 2 \
    >/dev/null 2>&1; then
    fail 'an existing output directory was accepted'
fi

# A roster answering one id names no switch, so the harness refuses ahead of the
# first request rather than measuring a repeat.
one_id_directory=$temporary_directory/one-id
if QWEN_SWITCH_ORIGIN=http://127.0.0.1:$router_port \
    QWEN_SWITCH_SERVER_LOG=$server_log \
    QWEN_SWITCH_MODEL_B=model-a \
    "$script_directory/measure-model-switch.sh" "$one_id_directory" 2 \
    >/dev/null 2>"$temporary_directory/one-id.stderr"; then
    fail 'a roster carrying one distinct id was accepted'
fi
grep -q 'a switch needs two distinct served ids' \
    "$temporary_directory/one-id.stderr" ||
    fail 'the one-id refusal lost its reason'

printf 'test-measure-model-switch: accepted\n' >&2
