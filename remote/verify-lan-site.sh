#!/bin/sh
set -eu

# One verification of a served LAN site, run from any machine on the network
# against the appliance's own mDNS name -- the address a LAN peer actually
# types rather than the loopback the appliance answers to itself. Each check
# is one row: what it read, whether it passed, and the raw response it read
# from, retained under OUTPUT_DIR so a failure is reproducible from the
# evidence this run left rather than from a re-run against a machine state
# that may have moved on.
#
# The router, the broker, and the artifact listener are three origins, and
# the boundary CLAUDE.md documents -- the page's meta tags name the loopback,
# so a LAN browser reads the LAN address from `?broker=` and `?artifacts=`
# query parameters the launch prints on its page URL -- decides how this
# script finds the other two: SITE_URL's own query parameters first, then
# QWEN_VERIFY_BROKER_URL / QWEN_VERIFY_ARTIFACTS_URL, then the page's own meta
# tags, which read the loopback default and therefore fail their own check
# from off the appliance -- a legitimate result this script reports rather
# than silently working around.
#
# The web-search and image-generation turns run through the served page in
# headless Chromium, driven by remote/web-mcp/drive-fallback-page.py exactly
# as CLAUDE.md's admission harnesses drive it: the per-turn toggle, the one
# approval dialog, and the transcript the page itself produced. Conversation
# restoration needs a second browser action this driver has no flag for --
# a reload of the same page inside the same profile -- so this script
# generates a small driver of its own, over the same DevTools-protocol
# handshake, and QWEN_VERIFY_CONVERSATION_DRIVER replaces the generated
# script with a fixture's.
#
# The tool-prefix checkpoint check reads evidence/tool-prefix-checkpoint's own
# claim: a second request sharing the first's system prompt and tool schema,
# differing only in its final user message, restores the shared head from a
# checkpoint on this hybrid architecture's one slot and charges only the new
# message. Two direct chat completions carrying that shared head, read for
# their own `timings.prompt_n`, measure it without a browser.
#
# usage: verify-lan-site.sh SITE_URL OUTPUT_DIR [--with-relaunch]
#
# --with-relaunch tears the appliance down and relaunches it through the
# repository's own scripts, then repeats the health matrix; it runs the
# device, so only an operator on the laptop passes it.
#
#   QWEN_VERIFY_API_KEY_FILE        bearer key file; unset serves a loopback
#                                    launch, since only the LAN literal Host
#                                    requires the bearer on /health routes
#   QWEN_VERIFY_BROKER_URL          the broker origin, overriding SITE_URL's
#                                    own ?broker= and the page's meta tag
#   QWEN_VERIFY_ARTIFACTS_URL       the artifact listener origin, overriding
#                                    SITE_URL's own ?artifacts= and the tag
#   QWEN_VERIFY_SEARCH_PROMPT       the web-search turn's prompt
#   QWEN_VERIFY_IMAGE_PROMPT        the image-generation turn's prompt
#   QWEN_VERIFY_CONVERSATION_PROMPT the conversation-restoration turn's prompt
#   QWEN_VERIFY_TOOL_PREFIX_SYSTEM_PROMPT  the shared system prompt the two
#                                    tool-prefix-checkpoint requests carry
#   QWEN_VERIFY_TOOL_PREFIX_PROMPT_1/2     each request's own final message
#   QWEN_VERIFY_MODEL                the model id the props check and the
#                                    tool-prefix-checkpoint requests name.
#                                    The checkpoint claim is about the
#                                    Qwen3.5 hybrid slot, so the default is
#                                    the roster's first qwen35-* or qwen38-*
#                                    id; a roster carrying none makes the
#                                    checkpoint row fail by name, and the
#                                    props check then reads the roster's
#                                    first id. evidence/deployment-epochs/
#                                    main-e909cfc-r1 records the LFM2 row
#                                    charging 114 tokens on both requests
#                                    when the roster's first id was the
#                                    subject.
#   QWEN_VERIFY_PROMPT_PREFIX_RATIO  the second request's prompt_n must read
#                                    at or below this fraction of the first's,
#                                    default 0.5. The first request carries a
#                                    per-run nonce in its system prompt, so
#                                    its head is a cold prefix by construction
#                                    and the ratio compares a miss against a
#                                    hit rather than two hits of a head an
#                                    earlier run left warm.
#   QWEN_VERIFY_CHAT_TIMEOUT_S       seconds one chat completion may take,
#                                    default 700; a request past it writes a
#                                    fail row carrying status 000
#   QWEN_VERIFY_PAGE_DRIVER          path to drive-fallback-page.py, default
#                                    the copy beside this script
#   QWEN_VERIFY_CONVERSATION_DRIVER  path to a conversation-restoration
#                                    driver, default a script this run
#                                    generates under OUTPUT_DIR
#   QWEN_VERIFY_CHROMIUM             chromium binary the drivers launch
#   QWEN_VERIFY_REPOSITORY_DIRECTORY the checkout --with-relaunch reads its
#                                    teardown and launch scripts from
#   QWEN_VERIFY_TEARDOWN             teardown script, default
#                                    remote/qwen-teardown.sh in that checkout
#   QWEN_VERIFY_LAUNCH               launch script, default
#                                    remote/qwen-lan-launch.sh there
#   QWEN_VERIFY_RELAUNCH_PROFILE     profile argument the relaunch passes,
#                                    default low-async

usage() {
    printf 'usage: %s SITE_URL OUTPUT_DIR [--with-relaunch]\n' "$0" >&2
    exit 2
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi
site_url=$1
output_directory=$2
with_relaunch=0
if [ "$#" -eq 3 ]; then
    case $3 in
        --with-relaunch) with_relaunch=1 ;;
        *) usage ;;
    esac
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_directory=${QWEN_VERIFY_REPOSITORY_DIRECTORY:-$(CDPATH='' cd -- "$script_directory/.." && pwd)}
api_key_file=${QWEN_VERIFY_API_KEY_FILE:-}
search_prompt=${QWEN_VERIFY_SEARCH_PROMPT:-'search the web for the current stable Vulkan specification version'}
image_prompt=${QWEN_VERIFY_IMAGE_PROMPT:-'a fox in a snowy field'}
conversation_prompt=${QWEN_VERIFY_CONVERSATION_PROMPT:-'say hello in one short sentence'}
tool_prefix_system_prompt=${QWEN_VERIFY_TOOL_PREFIX_SYSTEM_PROMPT:-'You are the qwen-apu appliance verification assistant. Answer plainly and call get_time only when the user explicitly asks for the time.'}
tool_prefix_prompt_1=${QWEN_VERIFY_TOOL_PREFIX_PROMPT_1:-'What is two plus two?'}
tool_prefix_prompt_2=${QWEN_VERIFY_TOOL_PREFIX_PROMPT_2:-'What is three plus three?'}
prefix_ratio=${QWEN_VERIFY_PROMPT_PREFIX_RATIO:-0.5}
chat_timeout_seconds=${QWEN_VERIFY_CHAT_TIMEOUT_S:-700}
page_driver=${QWEN_VERIFY_PAGE_DRIVER:-"$script_directory/web-mcp/drive-fallback-page.py"}
chromium=${QWEN_VERIFY_CHROMIUM:-chromium}

for required_tool in python3 curl jq sha256sum; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf '%s is required\n' "$required_tool" >&2
        exit 2
    fi
done
if [ ! -r "$page_driver" ]; then
    printf 'the web page driver is unreadable: %s\n' "$page_driver" >&2
    exit 1
fi

umask 077
mkdir -p "$output_directory/http"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)
results_tsv=$output_directory/results.tsv
printf '# check\tstatus\tdetail\n' >"$results_tsv"
failures=0
record() {
    record_detail=$(printf '%s' "$3" | tr '\t\r\n' '   ')
    printf '%s\t%s\t%s\n' "$1" "$2" "$record_detail" >>"$results_tsv"
    printf '%s=%s %s\n' "$1" "$2" "$record_detail"
    case $2 in
        pass | skip) ;;
        *) failures=$((failures + 1)) ;;
    esac
}

# The bearer reaches curl through a config file rather than argv, so it never
# sits in this process's own command line or in a printed check row.
api_key_curl_config=$(mktemp)
chmod 600 "$api_key_curl_config"
: >"$api_key_curl_config"
if [ -n "$api_key_file" ]; then
    if [ ! -r "$api_key_file" ]; then
        printf 'QWEN_VERIFY_API_KEY_FILE names an unreadable file: %s\n' "$api_key_file" >&2
        exit 1
    fi
    api_key_bytes=$(head -n 1 "$api_key_file")
    printf 'header = "Authorization: Bearer %s"\n' "$api_key_bytes" >"$api_key_curl_config"
fi
generated_conversation_driver=$output_directory/.generated-conversation-driver.py
# Every check owns one row. A run that ends ahead of a row -- a signal, a
# tool that exits under set -e, an operator's interrupt -- leaves that row as
# a fail naming the early end rather than as an absence a reader could take
# for a check that never existed; the e909cfc epoch record retains a run
# whose checkpoint row was missing for exactly that reason.
expected_checks='initial-page-get initial-health initial-models initial-props
initial-broker-health initial-artifacts-health web_search_turn
image_generation_turn conversation_restoration tool_prefix_checkpoint relaunch'
write_missing_rows() {
    [ -f "$results_tsv" ] || return 0
    for expected_check in $expected_checks; do
        if ! grep -q "^$expected_check	" "$results_tsv"; then
            record "$expected_check" fail 'the harness ended before this row was written'
        fi
    done
}
cleanup() {
    write_missing_rows
    rm -f "$api_key_curl_config" "$generated_conversation_driver"
}
trap cleanup EXIT
trap 'cleanup; trap - EXIT; exit 130' HUP INT TERM

exchange=0
call() {
    exchange=$((exchange + 1))
    call_label=$1
    call_method=$2
    call_url=$3
    call_body=${4:-}
    call_headers_file=$output_directory/http/$exchange-$call_label.headers
    call_out=$output_directory/http/$exchange-$call_label.response
    if [ "$#" -ge 4 ]; then shift 4; else shift "$#"; fi
    if [ -s "$api_key_curl_config" ]; then
        set -- "$@" --config "$api_key_curl_config"
    fi
    if [ -n "$call_body" ]; then
        call_request=$output_directory/http/$exchange-$call_label.request
        printf '%s' "$call_body" >"$call_request"
        curl -sS --max-time "$chat_timeout_seconds" -o "$call_out" -D "$call_headers_file" \
            -X "$call_method" "$call_url" -H 'Content-Type: application/json' \
            --data-binary "@$call_request" "$@" || true
    else
        curl -sS --max-time 60 -o "$call_out" -D "$call_headers_file" \
            -X "$call_method" "$call_url" "$@" || true
    fi
    call_status=$(sed -n '1s/^HTTP\/[0-9.]* \([0-9]*\).*/\1/p' "$call_headers_file" 2>/dev/null | tail -1)
    call_status=${call_status:-000}
    call_body_path=$call_out
}

# ---- origins: SITE_URL's own query parameters name the broker and the
# artifact listener the way the launch's printed page URL does, so this
# script reads them the same way a browser visiting that URL would. -----------
site_parts=$(python3 -c '
import sys, urllib.parse
parsed = urllib.parse.urlsplit(sys.argv[1])
query = urllib.parse.parse_qs(parsed.query)
print(urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, "", "", "")))
print((query.get("broker") or [""])[0])
print((query.get("artifacts") or [""])[0])
' "$site_url")
router_origin=$(printf '%s\n' "$site_parts" | sed -n 1p)
broker_origin=${QWEN_VERIFY_BROKER_URL:-$(printf '%s\n' "$site_parts" | sed -n 2p)}
artifacts_origin=${QWEN_VERIFY_ARTIFACTS_URL:-$(printf '%s\n' "$site_parts" | sed -n 3p)}
if [ -z "$router_origin" ]; then
    printf 'SITE_URL carries no scheme and host: %s\n' "$site_url" >&2
    exit 1
fi

url_encode() {
    python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}
meta_tag_content() {
    python3 -c '
import re, sys
try:
    html = open(sys.argv[2], encoding="utf-8", errors="replace").read()
except OSError:
    print("")
    sys.exit(0)
match = re.search(
    r"<meta\s+name=\"" + re.escape(sys.argv[1]) + r"\"\s+content=\"([^\"]*)\"", html)
print(match.group(1) if match else "")
' "$1" "$2"
}

default_model_id=${QWEN_VERIFY_MODEL:-}
checkpoint_subject_id=${QWEN_VERIFY_MODEL:-}
checkpoint_subject_source=${QWEN_VERIFY_MODEL:+QWEN_VERIFY_MODEL}
page_response_path=''
health_matrix() {
    prefix=$1

    call "$prefix-page-get" GET "$router_origin/"
    if [ "$call_status" = 200 ]; then
        record "$prefix-page-get" pass "http=$call_status bytes=$(wc -c <"$call_body_path" | tr -d ' ')"
    else
        record "$prefix-page-get" fail "http=$call_status"
    fi
    page_response_path=$call_body_path

    call "$prefix-health" GET "$router_origin/health"
    if [ "$call_status" = 200 ] && \
        [ "$(jq -r '.status // empty' "$call_body_path" 2>/dev/null)" = ok ]; then
        record "$prefix-health" pass "http=$call_status"
    else
        record "$prefix-health" fail "http=$call_status body=$(head -c 200 "$call_body_path" | tr -d '\n')"
    fi

    call "$prefix-models" GET "$router_origin/v1/models"
    if [ "$call_status" = 200 ] && jq -e '.data | type == "array"' "$call_body_path" >/dev/null 2>&1; then
        roster_count=$(jq '.data | length' "$call_body_path")
        roster_ids=$(jq -r '.data[].id' "$call_body_path" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        if [ -z "${QWEN_VERIFY_MODEL:-}" ]; then
            checkpoint_subject_id=$(jq -r \
                '[.data[].id | select(test("^qwen3[58]-"))][0] // empty' "$call_body_path")
            checkpoint_subject_source=roster-first-qwen35-architecture-id
            default_model_id=${checkpoint_subject_id:-$(jq -r '.data[0].id // empty' "$call_body_path")}
        fi
        record "$prefix-models" pass "count=$roster_count ids=$roster_ids"
    else
        record "$prefix-models" fail "http=$call_status"
    fi

    if [ -n "$default_model_id" ]; then
        call "$prefix-props" GET "$router_origin/props?model=$(url_encode "$default_model_id")"
        if [ "$call_status" = 200 ] && jq -e 'has("default_generation_settings")' \
            "$call_body_path" >/dev/null 2>&1; then
            record "$prefix-props" pass "model=$default_model_id"
        else
            record "$prefix-props" fail "http=$call_status model=$default_model_id"
        fi
    else
        record "$prefix-props" fail 'no default model id was read from the roster'
    fi

    resolved_broker=$broker_origin
    resolved_broker_source=explicit-or-query
    if [ -z "$resolved_broker" ]; then
        resolved_broker=$(meta_tag_content qwen-web-broker "$page_response_path")
        resolved_broker_source=page-meta-tag
    fi
    if [ -z "$resolved_broker" ]; then
        record "$prefix-broker-health" fail 'no broker origin: pass QWEN_VERIFY_BROKER_URL or a SITE_URL carrying ?broker='
    else
        call "$prefix-broker-health" GET "$resolved_broker/health"
        if [ "$call_status" = 200 ] && \
            [ "$(jq -r '.protocol // empty' "$call_body_path" 2>/dev/null)" = qwen-web-broker/1 ]; then
            record "$prefix-broker-health" pass "origin=$resolved_broker source=$resolved_broker_source"
        else
            record "$prefix-broker-health" fail "origin=$resolved_broker source=$resolved_broker_source http=$call_status"
        fi
    fi

    resolved_artifacts=$artifacts_origin
    resolved_artifacts_source=explicit-or-query
    if [ -z "$resolved_artifacts" ]; then
        resolved_artifacts=$(meta_tag_content qwen-image-artifacts "$page_response_path")
        resolved_artifacts_source=page-meta-tag
    fi
    if [ -z "$resolved_artifacts" ]; then
        record "$prefix-artifacts-health" fail 'no artifact listener origin: pass QWEN_VERIFY_ARTIFACTS_URL or a SITE_URL carrying ?artifacts='
    else
        call "$prefix-artifacts-health" GET "$resolved_artifacts/health"
        if [ "$call_status" = 200 ] && \
            [ "$(jq -r '.protocol // empty' "$call_body_path" 2>/dev/null)" = qwen-image-service/1 ]; then
            record "$prefix-artifacts-health" pass "origin=$resolved_artifacts source=$resolved_artifacts_source"
        else
            record "$prefix-artifacts-health" fail "origin=$resolved_artifacts source=$resolved_artifacts_source http=$call_status"
        fi
    fi
}

health_matrix initial
broker_origin=$resolved_broker
artifacts_origin=$resolved_artifacts

# ---- one web-search turn through the served page -----------------------------
web_search_report=$output_directory/http/$((exchange + 1))-web-search-turn.json
exchange=$((exchange + 1))
if python3 "$page_driver" --origin "$router_origin" \
    ${broker_origin:+--broker "$broker_origin"} \
    ${artifacts_origin:+--artifacts "$artifacts_origin"} \
    --prompt "$search_prompt" --lane web \
    ${api_key_file:+--api-key-file "$api_key_file"} \
    --chromium "$chromium" >"$web_search_report" 2>"$output_directory/http/$exchange-web-search-turn.stderr"; then
    driver_status=0
else
    driver_status=$?
fi
if [ "$driver_status" = 0 ] && jq -e '.error == null and .dialog != null' \
    "$web_search_report" >/dev/null 2>&1; then
    grant_seen=$(jq -r --arg b "${broker_origin:-no-broker}/grant" \
        '[.requests[] | select(.url == $b)] | length' "$web_search_report" 2>/dev/null || echo 0)
    record web_search_turn pass "dialog_heading=$(jq -r '.dialog.heading // empty' "$web_search_report") grant_requests=$grant_seen"
else
    record web_search_turn fail "driver_status=$driver_status error=$(jq -r '.error.message // empty' "$web_search_report" 2>/dev/null)"
fi

# ---- one image-generation turn through the served page -----------------------
image_report=$output_directory/http/$((exchange + 1))-image-turn.json
exchange=$((exchange + 1))
if python3 "$page_driver" --origin "$router_origin" \
    ${broker_origin:+--broker "$broker_origin"} \
    ${artifacts_origin:+--artifacts "$artifacts_origin"} \
    --prompt "$image_prompt" --lane image \
    ${api_key_file:+--api-key-file "$api_key_file"} \
    --chromium "$chromium" >"$image_report" 2>"$output_directory/http/$exchange-image-turn.stderr"; then
    driver_status=0
else
    driver_status=$?
fi
if [ "$driver_status" = 0 ] && jq -e '.error == null and ((.imageCards | length) > 0)' \
    "$image_report" >/dev/null 2>&1; then
    record image_generation_turn pass "caption=$(jq -r '.imageCards[0].caption // empty' "$image_report" | head -c 120)"
else
    record image_generation_turn fail "driver_status=$driver_status error=$(jq -r '.error.message // empty' "$image_report" 2>/dev/null) states=$(jq -c '.imageStates // []' "$image_report" 2>/dev/null)"
fi

# ---- conversation restoration -------------------------------------------------
# `write_generated_conversation_driver` reproduces the DevTools handshake
# drive-fallback-page.py already carries, over a narrower turn: send one
# plain chat message with the per-turn toggles left off, read the conversation
# store's own id and message count, navigate the same tab back to the origin
# -- a real reload, a fresh JS realm -- and read both back the way a returning
# visitor's browser would. QWEN_VERIFY_CONVERSATION_DRIVER replaces this
# generated script with a fixture's, so a test proves the check's reading of
# a report without a real Chromium.
write_generated_conversation_driver() {
    cat >"$1" <<'CONVERSATION_DRIVER_PY'
#!/usr/bin/env python3
"""Send one chat turn, reload the page, and report whether the conversation
survived the reload. Duplicates the minimal DevTools-protocol handshake
remote/web-mcp/drive-fallback-page.py uses, over a narrower turn: no lane
toggle, no approval dialog, one plain message and one reload."""
import argparse
import base64
import json
import re
import secrets
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import time
import urllib.request


class DevToolsSocket:
    def __init__(self, url):
        match = re.match(r"ws://([^:/]+):(\d+)(/.*)", url)
        host, port, path = match.group(1), int(match.group(2)), match.group(3)
        self.sock = socket.create_connection((host, port), timeout=30)
        key = base64.b64encode(secrets.token_bytes(16)).decode("ascii")
        request = (
            "GET {p} HTTP/1.1\r\nHost: {h}:{o}\r\nUpgrade: websocket\r\n"
            "Connection: Upgrade\r\nSec-WebSocket-Key: {k}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        ).format(p=path, h=host, o=port, k=key)
        self.sock.sendall(request.encode("ascii"))
        response = b""
        while b"\r\n\r\n" not in response:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("DevTools handshake closed early")
            response += chunk
        if not response.startswith(b"HTTP/1.1 101"):
            raise ConnectionError("DevTools handshake refused")
        self.buffer = response.split(b"\r\n\r\n", 1)[1]
        self.next_id = 0

    def _read_exactly(self, count):
        while len(self.buffer) < count:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("DevTools socket closed")
            self.buffer += chunk
        data, self.buffer = self.buffer[:count], self.buffer[count:]
        return data

    def send_text(self, text):
        payload = text.encode("utf-8")
        header = bytearray([0x81])
        length = len(payload)
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", length)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", length)
        mask = secrets.token_bytes(4)
        header += mask
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(bytes(header) + masked)

    def receive_text(self):
        message = b""
        while True:
            first, second = self._read_exactly(2)
            opcode = first & 0x0F
            length = second & 0x7F
            if length == 126:
                length = struct.unpack(">H", self._read_exactly(2))[0]
            elif length == 127:
                length = struct.unpack(">Q", self._read_exactly(8))[0]
            if second & 0x80:
                mask = self._read_exactly(4)
                data = bytes(b ^ mask[i % 4] for i, b in enumerate(self._read_exactly(length)))
            else:
                data = self._read_exactly(length)
            if opcode == 0x8:
                raise ConnectionError("DevTools closed the socket")
            if opcode == 0x9:
                continue
            message += data
            if first & 0x80:
                return message.decode("utf-8")

    def call(self, method, **params):
        self.next_id += 1
        call_id = self.next_id
        self.send_text(json.dumps({"id": call_id, "method": method, "params": params}))
        while True:
            reply = json.loads(self.receive_text())
            if reply.get("id") == call_id:
                if "error" in reply:
                    raise RuntimeError(method + ": " + json.dumps(reply["error"]))
                return reply.get("result", {})

    def evaluate(self, expression):
        result = self.call("Runtime.evaluate", expression=expression,
                            awaitPromise=True, returnByValue=True)
        if "exceptionDetails" in result:
            raise RuntimeError("page threw: " + json.dumps(result["exceptionDetails"])[:400])
        return result.get("result", {}).get("value")


def wait_for(socket_, expression, seconds, what):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = socket_.evaluate(expression)
        if value:
            return value
        time.sleep(0.5)
    raise TimeoutError("waited {}s for {}".format(seconds, what))


def wait_for_reload(socket_, expression, seconds, what):
    """wait_for, tolerant of the reload's own teardown window.

    A poll that lands while Page.reload is tearing down the old execution
    context reads back a protocol error -- "Cannot find context with
    specified id" -- rather than a value, which wait_for's bare evaluate()
    call would raise straight out of the wait loop. The next poll runs
    against whichever realm answers, old or new, so a lost poll here costs
    half a second rather than the whole check.
    """
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            value = socket_.evaluate(expression)
        except RuntimeError:
            value = None
        if value:
            return value
        time.sleep(0.5)
    raise TimeoutError("waited {}s for {}".format(seconds, what))


def open_page(http_origin, page_url):
    request = urllib.request.Request(
        "http://{}/json/new?{}".format(http_origin, page_url), method="PUT")
    with urllib.request.urlopen(request, timeout=30) as response:
        target = json.load(response)
    page = DevToolsSocket(target["webSocketDebuggerUrl"])
    page.call("Page.enable")
    page.call("Runtime.enable")
    return page


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--origin", required=True)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--api-key-file", default="")
    parser.add_argument("--chromium", default="chromium")
    parser.add_argument("--load-timeout", type=int, default=180)
    parser.add_argument("--turn-timeout", type=int, default=300)
    arguments = parser.parse_args()

    profile_directory = tempfile.mkdtemp(prefix="qwen-conversation-drive.")
    command = [
        arguments.chromium, "--headless=new", "--no-sandbox", "--disable-gpu",
        "--no-first-run", "--remote-debugging-port=0",
        "--user-data-dir=" + profile_directory, "about:blank",
    ]
    browser_log = open(profile_directory + "/chromium.log", "w+b")
    browser = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=browser_log)
    report = {"error": None}
    try:
        devtools = None
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline and browser.poll() is None:
            browser_log.seek(0)
            match = re.search(r"DevTools listening on (ws://\S+)",
                               browser_log.read().decode("utf-8", "replace"))
            if match:
                devtools = match.group(1)
                break
            time.sleep(0.2)
        if devtools is None:
            raise RuntimeError("Chromium printed no DevTools address")
        http_origin = re.match(r"ws://([^/]+)/", devtools).group(1)
        page = open_page(http_origin, arguments.origin + "/")
        wait_for(page, "document.readyState === 'complete' && typeof requestModel !== 'undefined'",
                 arguments.load_timeout, "the page to load")
        if arguments.api_key_file:
            with open(arguments.api_key_file, encoding="utf-8") as handle:
                api_key = handle.readline().strip()
            page.evaluate(
                "(() => { document.querySelector('#api-key').value = "
                + json.dumps(api_key)
                + "; document.querySelector('#set-key').click(); return true; })()"
            )
        wait_for(page, "requestModel", arguments.load_timeout, "the page to select a model")
        page.evaluate(
            "(() => { const box = document.querySelector('#input'); box.value = "
            + json.dumps(arguments.prompt)
            + "; document.querySelector('#send').click(); return true; })()"
        )
        wait_for(page, "busy === false", arguments.turn_timeout, "the turn to end")
        before = json.loads(page.evaluate(
            "JSON.stringify({ id: conversationId, title: conversationTitle,"
            " messages: conversationMessages.length })"
        ))
        report["conversation_id"] = before["id"]
        report["title"] = before["title"]
        report["message_count_before_reload"] = before["messages"]
        # Page.navigate to the bare origin is a same-document navigation
        # against a URL the turn already routed to `#/c/<id>` -- the fragment
        # is the only difference, so the JS realm survives and every global
        # below would read the pre-reload state without anything having been
        # restored from IndexedDB. Page.reload always re-fetches regardless
        # of the fragment. A sentinel set before the reload and awaited absent
        # after it is what proves the realm actually turned over, since the
        # first poll can otherwise land on the still-alive old context and
        # read `document.readyState === 'complete'` immediately.
        page.evaluate("(() => { window.__qwenPreReload = true; return true; })()")
        page.call("Page.reload")
        wait_for_reload(
            page,
            "typeof window.__qwenPreReload === 'undefined' &&"
            " document.readyState === 'complete' && typeof requestModel !== 'undefined'",
            arguments.load_timeout, "the page to reload",
        )
        wait_for_reload(page, "typeof conversationsReady !== 'undefined'",
                         arguments.load_timeout, "the conversation store to settle")
        after = json.loads(page.evaluate(
            "(async () => { await conversationsReady;"
            " const entries = await (await conversationStore()).list();"
            " return JSON.stringify({ id: conversationId, messages: conversationMessages.length,"
            " listed: entries.some(entry => entry.id === " + json.dumps(before["id"]) + ") }); })()"
        ))
        report["conversation_id_after_reload"] = after["id"]
        report["message_count_after_reload"] = after["messages"]
        report["listed_after_reload"] = after["listed"]
        report["id_matches"] = after["id"] == before["id"]
        report["messages_match"] = after["messages"] == before["messages"] and before["messages"] > 0
    except Exception as exc:
        report["error"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        browser_log.close()
        browser.terminate()
        try:
            browser.wait(timeout=10)
        except subprocess.TimeoutExpired:
            browser.kill()
        shutil.rmtree(profile_directory, ignore_errors=True)
    json.dump(report, sys.stdout, indent=1)
    sys.stdout.write("\n")
    return 1 if report["error"] else 0


if __name__ == "__main__":
    sys.exit(main())
CONVERSATION_DRIVER_PY
}

if [ -n "${QWEN_VERIFY_CONVERSATION_DRIVER:-}" ]; then
    conversation_driver=$QWEN_VERIFY_CONVERSATION_DRIVER
else
    write_generated_conversation_driver "$generated_conversation_driver"
    chmod 700 "$generated_conversation_driver"
    conversation_driver=$generated_conversation_driver
fi

conversation_report=$output_directory/http/$((exchange + 1))-conversation-restoration.json
exchange=$((exchange + 1))
if python3 "$conversation_driver" --origin "$router_origin" \
    --prompt "$conversation_prompt" \
    ${api_key_file:+--api-key-file "$api_key_file"} \
    --chromium "$chromium" >"$conversation_report" 2>"$output_directory/http/$exchange-conversation-restoration.stderr"; then
    driver_status=0
else
    driver_status=$?
fi
if [ "$driver_status" = 0 ] && jq -e \
    '.error == null and .listed_after_reload == true and .id_matches == true and .messages_match == true' \
    "$conversation_report" >/dev/null 2>&1; then
    record conversation_restoration pass "id=$(jq -r '.conversation_id // empty' "$conversation_report")"
else
    record conversation_restoration fail "driver_status=$driver_status $(jq -c '{error, listed_after_reload, id_matches, messages_match}' "$conversation_report" 2>/dev/null)"
fi

# ---- a tool-prefix checkpoint hit ----------------------------------------------
if [ -z "$checkpoint_subject_id" ]; then
    record tool_prefix_checkpoint fail \
        'no qwen35-* or qwen38-* id on the roster and QWEN_VERIFY_MODEL unset; the claim is about the Qwen3.5 hybrid slot'
else
    # the nonce makes the first request's head a cold prefix by construction
    tool_prefix_nonce=$(date -u +%Y%m%dT%H%M%SZ)-$$
    tool_prefix_system_prompt="$tool_prefix_system_prompt Verification run $tool_prefix_nonce."
    tool_schema=$output_directory/.tool-prefix-schema.json
    cat >"$tool_schema" <<'TOOL_SCHEMA_JSON'
[{"type":"function","function":{"name":"get_time","description":"Return the current time for a named timezone.","parameters":{"type":"object","properties":{"timezone":{"type":"string"}},"required":["timezone"]}}}]
TOOL_SCHEMA_JSON
    build_chat_request() {
        python3 -c '
import json, sys
model, system_prompt, tools_path, user_message = sys.argv[1:5]
with open(tools_path, encoding="utf-8") as handle:
    tools = json.load(handle)
payload = {
    "model": model,
    "messages": [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message},
    ],
    "tools": tools,
    "max_tokens": 24,
    "temperature": 0,
    "chat_template_kwargs": {"enable_thinking": False},
}
print(json.dumps(payload))
' "$1" "$2" "$3" "$4"
    }
    request_1=$(build_chat_request "$checkpoint_subject_id" "$tool_prefix_system_prompt" \
        "$tool_schema" "$tool_prefix_prompt_1")
    call tool-prefix-1 POST "$router_origin/v1/chat/completions" "$request_1"
    first_status=$call_status
    first_prompt_n=$(jq -r '.timings.prompt_n // empty' "$call_body_path" 2>/dev/null || true)

    request_2=$(build_chat_request "$checkpoint_subject_id" "$tool_prefix_system_prompt" \
        "$tool_schema" "$tool_prefix_prompt_2")
    call tool-prefix-2 POST "$router_origin/v1/chat/completions" "$request_2"
    second_status=$call_status
    second_prompt_n=$(jq -r '.timings.prompt_n // empty' "$call_body_path" 2>/dev/null || true)

    checkpoint_verdict=$(python3 -c '
import sys
first_status, second_status, first_n, second_n, ratio = sys.argv[1:6]
try:
    ok = (first_status == "200" and second_status == "200" and
          int(first_n) > 0 and int(second_n) > 0 and
          int(second_n) <= int(first_n) * float(ratio))
except (ValueError, TypeError):
    ok = False
print("pass" if ok else "fail")
' "$first_status" "$second_status" "${first_prompt_n:-0}" "${second_prompt_n:-0}" "$prefix_ratio")
    record tool_prefix_checkpoint "$checkpoint_verdict" \
        "model=$checkpoint_subject_id subject_source=$checkpoint_subject_source prefix=cold nonce=$tool_prefix_nonce first_status=$first_status first_prompt_n=${first_prompt_n:-} second_status=$second_status second_prompt_n=${second_prompt_n:-} ratio<=$prefix_ratio"
fi

# ---- an operator-only teardown and relaunch, repeating the health matrix -----
if [ "$with_relaunch" = 1 ]; then
    teardown=${QWEN_VERIFY_TEARDOWN:-"$repository_directory/remote/qwen-teardown.sh"}
    launch=${QWEN_VERIFY_LAUNCH:-"$repository_directory/remote/qwen-lan-launch.sh"}
    relaunch_profile=${QWEN_VERIFY_RELAUNCH_PROFILE:-low-async}
    if [ ! -x "$teardown" ] || [ ! -x "$launch" ]; then
        record relaunch fail "teardown or launch script is not executable: $teardown $launch"
    else
        teardown_status=0
        "$teardown" >"$output_directory/relaunch-teardown.log" 2>&1 || teardown_status=$?
        launch_status=0
        "$launch" "$relaunch_profile" >"$output_directory/relaunch-launch.log" 2>&1 || launch_status=$?
        if [ "$teardown_status" = 0 ] && [ "$launch_status" = 0 ]; then
            record relaunch pass "profile=$relaunch_profile"
        else
            record relaunch fail "teardown_status=$teardown_status launch_status=$launch_status"
        fi
        health_matrix relaunch
    fi
else
    record relaunch skip 'pass --with-relaunch as an operator on the laptop to run it'
fi

printf 'verify_lan_site=%s router_origin=%s failures=%s\n' \
    "$output_directory" "$router_origin" "$failures"
[ "$failures" -eq 0 ]
