#!/bin/sh
set -eu

<<<<<<< HEAD
# A build identity answers before the argv recorder runs, so an identity query
# leaves the recorded launch argv of the run under test in place.
if [ "${1:-}" = --version ]; then
    printf 'version: 0 (fake)\nbuild: 0000000 with fake\n'
    exit 0
fi

||||||| parent of 981c94b (patches: backport the Vulkan view-alias dependency fix as a candidate)
=======
# QWEN_FAKE_SERVER_PORT turns the fixture into a serving stand-in: it records
# its argv the way the recording branch does, then answers GET /health and
# POST /completion until it is signalled. The token array it returns depends on
# the two variables the graph-alias lane separates -- whether
# GGML_VK_DISABLE_GRAPH_OPTIMIZE is set, and whether the build directory it was
# launched from carries an alias-marker file -- so a run reproduces both the
# divergent and the identical outcome without a device.
if [ -n "${QWEN_FAKE_SERVER_PORT:-}" ]; then
    if [ -n "${QWEN_FAKE_SERVER_STATE_DIRECTORY:-}" ]; then
        mkdir -p "$QWEN_FAKE_SERVER_STATE_DIRECTORY"
        {
            printf 'argument_count=%s\n' "$#"
            for argument in "$@"; do
                printf 'argument=%s\n' "$argument"
            done
            printf 'disable_graph_optimize=%s\n' \
                "${GGML_VK_DISABLE_GRAPH_OPTIMIZE:-unset}"
        } >"$QWEN_FAKE_SERVER_STATE_DIRECTORY/argv-$$.txt"
    fi

    fake_build_directory=$(dirname -- "$(dirname -- "$0")")
    fake_tokens=${QWEN_FAKE_SERVER_TOKENS:-'10 11 12 13 14 15 16 17'}
    if [ -z "${GGML_VK_DISABLE_GRAPH_OPTIMIZE:-}" ] &&
        [ ! -e "$fake_build_directory/alias-marker" ] &&
        [ -n "${QWEN_FAKE_SERVER_TOKENS_OPTIMIZE:-}" ]; then
        fake_tokens=$QWEN_FAKE_SERVER_TOKENS_OPTIMIZE
    fi

    # The load banner llama-server prints for a fully offloaded model. A caller
    # that reads placement from the log sees the same three lines here, and
    # QWEN_FAKE_SERVER_PLACEMENT=cpu withholds them so the caller's rejection
    # path is reachable too.
    if [ "${QWEN_FAKE_SERVER_PLACEMENT:-vulkan}" = vulkan ]; then
        printf 'load_tensors: Vulkan0 model buffer size = 1234.00 MiB\n'
        printf 'llama_kv_cache: Vulkan0 KV buffer size = 56.00 MiB\n'
        printf 'llama_context: Vulkan0 compute buffer size = 78.00 MiB\n'
    fi

    exec python3 - "$QWEN_FAKE_SERVER_PORT" "$fake_tokens" <<'FAKE_SERVER'
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
tokens = [int(value) for value in sys.argv[2].split()]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *arguments):
        return

    def _send(self, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/health"):
            self._send({"status": "ok"})
        else:
            self.send_error(404)

    def do_POST(self):
        if not self.path.startswith("/completion"):
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        request = json.loads(self.rfile.read(length) or b"{}")
        predict = int(request.get("n_predict", len(tokens)))
        emitted = [tokens[index % len(tokens)] for index in range(predict)]
        self._send({"content": "", "tokens": emitted})


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
FAKE_SERVER
fi

>>>>>>> 981c94b (patches: backport the Vulkan view-alias dependency fix as a candidate)
if [ -z "${QWEN_POLICY_TEST_OUTPUT:-}" ]; then
    printf 'QWEN_POLICY_TEST_OUTPUT is required\n' >&2
    exit 2
fi

{
    printf 'affinity=%s\n' "$(awk '/Cpus_allowed_list/ { print $2 }' /proc/self/status)"
    printf 'nice=%s\n' "$(ps -o ni= -p $$ | tr -d ' ')"
    printf 'io=%s\n' "$(ionice -p $$)"
    printf 'low=%s\n' "${GGML_VK_LOW_PRIORITY:-unset}"
    printf 'duty=%s\n' "${GGML_VK_DUTY_CYCLE_PERCENT:-unset}"
    printf 'serialized=%s\n' "${GGML_VK_SERIALIZE_SUBMISSIONS:-unset}"
    printf 'max_nodes=%s\n' "${GGML_VK_MAX_NODES_PER_SUBMIT:-unset}"
    printf 'profile=%s\n' "${QWEN_VULKAN_PROFILE:-unset}"
    printf 'amd_priority=%s\n' "${AMD_PRIORITY:-unset}"
    printf 'memory_priority=%s\n' "${GGML_VK_ENABLE_MEMORY_PRIORITY:-unset}"
    printf 'allow_graphics=%s\n' "${GGML_VK_ALLOW_GRAPHICS_QUEUE:-unset}"
    printf 'radv_perftest=%s\n' "${RADV_PERFTEST:-unset}"
    printf 'strict=%s\n' "${LLAMA_NO_CPU_FALLBACK:-unset}"
    printf 'display=%s\n' "${DISPLAY-unset}"
    printf 'wayland=%s\n' "${WAYLAND_DISPLAY-unset}"
    printf 'argument_count=%s\n' "$#"
    for argument in "$@"; do
        printf 'argument=%s\n' "$argument"
    done
} > "$QWEN_POLICY_TEST_OUTPUT"

# QWEN_POLICY_TEST_HTTP_PORT turns the recorder into a served endpoint, so a
# harness that drives requests through llama-server's own routes runs without
# the device. One whitespace-separated word stands for one token and each image
# part contributes a fixed lump, which is the shape a projector-loaded prompt
# has: the /tokenize route sees the text alone and timings.prompt_n carries the
# image tokens beside it.
[ -n "${QWEN_POLICY_TEST_HTTP_PORT:-}" ] || exit 0

QWEN_POLICY_TEST_HTTP_PORT=$QWEN_POLICY_TEST_HTTP_PORT \
QWEN_POLICY_TEST_IMAGE_TOKENS=${QWEN_POLICY_TEST_IMAGE_TOKENS:-300} \
QWEN_POLICY_TEST_REPLY=${QWEN_POLICY_TEST_REPLY:-JUN} \
QWEN_POLICY_TEST_PREDICTED_CAP=${QWEN_POLICY_TEST_PREDICTED_CAP:-0} \
    exec python3 - <<'PY'
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(os.environ["QWEN_POLICY_TEST_HTTP_PORT"])
image_tokens = int(os.environ["QWEN_POLICY_TEST_IMAGE_TOKENS"])
reply = os.environ["QWEN_POLICY_TEST_REPLY"]
# A positive cap stops the reply short of the requested length, which is the
# shape a fixed-length decode fails in: the answer arrives and carries fewer
# tokens than the caller asked for.
predicted_cap = int(os.environ["QWEN_POLICY_TEST_PREDICTED_CAP"])


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *arguments):
        pass

    def respond(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/health"):
            self.respond({"status": "ok"})
        else:
            self.send_error(404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length).decode() or "{}")
        if self.path.startswith("/tokenize"):
            words = len(str(body.get("content", "")).split())
            self.respond({"tokens": list(range(words))})
            return
        if not self.path.startswith("/v1/chat/completions"):
            self.send_error(404)
            return
        prompt_tokens = 0
        for message in body.get("messages") or []:
            for part in message.get("content") or []:
                if part.get("type") == "text":
                    prompt_tokens += len(part.get("text", "").split())
                if part.get("type") == "image_url":
                    prompt_tokens += image_tokens
        predicted = int(body.get("max_tokens") or 1)
        if predicted_cap > 0:
            predicted = min(predicted, predicted_cap)
        self.respond({
            "choices": [{"message": {"role": "assistant", "content": reply}}],
            "timings": {"prompt_n": prompt_tokens, "prompt_ms": 1000.0,
                        "predicted_n": predicted, "predicted_per_second": 4.5}})


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
