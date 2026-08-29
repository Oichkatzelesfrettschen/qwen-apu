#!/bin/sh
set -eu

# A build identity answers before the argv recorder runs, so an identity query
# leaves the recorded launch argv of the run under test in place.
if [ "${1:-}" = --version ]; then
    printf 'version: 0 (fake)\nbuild: 0000000 with fake\n'
    exit 0
fi

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
    exec python3 - <<'PY'
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(os.environ["QWEN_POLICY_TEST_HTTP_PORT"])
image_tokens = int(os.environ["QWEN_POLICY_TEST_IMAGE_TOKENS"])
reply = os.environ["QWEN_POLICY_TEST_REPLY"]


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
        self.respond({
            "choices": [{"message": {"role": "assistant", "content": reply}}],
            "timings": {"prompt_n": prompt_tokens, "prompt_ms": 1000.0,
                        "predicted_n": predicted, "predicted_per_second": 4.5}})


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
