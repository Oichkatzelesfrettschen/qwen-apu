#!/bin/sh
set -eu

# The stand-in for llama-server that lets a policy test, a projector probe, and
# the graph-alias lane run without the device. It answers in three stages, and
# each stage has its own gate so no stage hides another: an identity query, the
# launch argv record, and a served endpoint.

# A build identity answers before the argv recorder runs, so an identity query
# leaves the recorded launch argv of the run under test in place.
if [ "${1:-}" = --version ]; then
    printf 'version: 0 (fake)\nbuild: 0000000 with fake\n'
    exit 0
fi

# One server answers both port names, because a fake llama-server serving
# /tokenize and /v1/chat/completions for a projector probe and one serving
# /completion for a token-identity sweep are the same process with different
# routes exercised. Two names rather than one keeps each caller's variable, and
# naming both asks one process for two listeners.
if [ -n "${QWEN_POLICY_TEST_HTTP_PORT:-}" ] && [ -n "${QWEN_FAKE_SERVER_PORT:-}" ]; then
    printf 'set one of QWEN_POLICY_TEST_HTTP_PORT and QWEN_FAKE_SERVER_PORT\n' >&2
    exit 2
fi
serving_port=${QWEN_POLICY_TEST_HTTP_PORT:-${QWEN_FAKE_SERVER_PORT:-}}

# The argv record has two destinations because it has two readers. A single
# launch under test writes one file named by QWEN_POLICY_TEST_OUTPUT; a sweep
# that starts many servers in turn writes one file per process into
# QWEN_FAKE_SERVER_STATE_DIRECTORY, since a single path would retain the last
# launch alone. Either destination satisfies the requirement, so a caller that
# names neither is the argument error it always was.
if [ -z "${QWEN_POLICY_TEST_OUTPUT:-}" ] &&
    [ -z "${QWEN_FAKE_SERVER_STATE_DIRECTORY:-}" ]; then
    printf 'QWEN_POLICY_TEST_OUTPUT is required\n' >&2
    exit 2
fi

record_launch() {
    printf 'affinity=%s\n' "$(awk '/Cpus_allowed_list/ { print $2 }' /proc/self/status)"
    printf 'nice=%s\n' "$(LC_ALL=C awk '
        {
            stat_line = $0
            sub(/^.*[)] /, "", stat_line)
            split(stat_line, fields, /[[:space:]]+/)
            print fields[17]
        }
    ' "/proc/$$/stat")"
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
    printf 'disable_graph_optimize=%s\n' "${GGML_VK_DISABLE_GRAPH_OPTIMIZE:-unset}"
    printf 'display=%s\n' "${DISPLAY-unset}"
    printf 'wayland=%s\n' "${WAYLAND_DISPLAY-unset}"
    printf 'argument_count=%s\n' "$#"
    for argument in "$@"; do
        printf 'argument=%s\n' "$argument"
    done
}

if [ -n "${QWEN_POLICY_TEST_OUTPUT:-}" ]; then
    record_launch "$@" >"$QWEN_POLICY_TEST_OUTPUT"
fi
if [ -n "${QWEN_FAKE_SERVER_STATE_DIRECTORY:-}" ]; then
    mkdir -p "$QWEN_FAKE_SERVER_STATE_DIRECTORY"
    record_launch "$@" >"$QWEN_FAKE_SERVER_STATE_DIRECTORY/argv-$$.txt"
fi

[ -n "$serving_port" ] || exit 0

# The token array /completion returns depends on the two variables the
# graph-alias lane separates: whether GGML_VK_DISABLE_GRAPH_OPTIMIZE is set,
# and whether the build directory this copy was launched from carries an
# alias-marker file. A build lacking the marker with the optimizer on returns
# the reordered sequence, which reproduces both the divergent and the identical
# outcome without a device.
fake_build_directory=$(dirname -- "$(dirname -- "$0")")
fake_tokens=${QWEN_FAKE_SERVER_TOKENS:-'10 11 12 13 14 15 16 17'}
if [ -z "${GGML_VK_DISABLE_GRAPH_OPTIMIZE:-}" ] &&
    [ ! -e "$fake_build_directory/alias-marker" ] &&
    [ -n "${QWEN_FAKE_SERVER_TOKENS_OPTIMIZE:-}" ]; then
    fake_tokens=$QWEN_FAKE_SERVER_TOKENS_OPTIMIZE
fi

# The load banner llama-server prints for a fully offloaded model. A caller that
# reads placement from the log sees the same three lines here, and
# QWEN_FAKE_SERVER_PLACEMENT=cpu withholds them so the caller's rejection path
# is reachable too.
if [ "${QWEN_FAKE_SERVER_PLACEMENT:-vulkan}" = vulkan ]; then
    printf 'load_tensors: Vulkan0 model buffer size = 1234.00 MiB\n'
    printf 'llama_kv_cache: Vulkan0 KV buffer size = 56.00 MiB\n'
    printf 'llama_context: Vulkan0 compute buffer size = 78.00 MiB\n'
fi

# One whitespace-separated word stands for one token and each image part
# contributes a fixed lump, which is the shape a projector-loaded prompt has:
# the /tokenize route sees the text alone and timings.prompt_n carries the image
# tokens beside it.
# The speculation arm is read from the argv the caller built rather than from a
# second variable, so a draft-pair harness and its control reach one fixture and
# differ by the same flag the real server differs by. tools/server has the same
# shape: server-common.cpp adds draft_n and draft_n_accepted to a request's
# timings only where that request drafted something.
fake_spec_active=0
for fake_argument in "$@"; do
    if [ "$fake_argument" = --spec-type ]; then
        fake_spec_active=1
        break
    fi
done
fake_decode_tok_s=${QWEN_FAKE_SERVER_DECODE_TOK_S:-3.00}
fake_draft_n=0
fake_draft_accepted=0
if [ "$fake_spec_active" = 1 ]; then
    fake_decode_tok_s=${QWEN_FAKE_SERVER_DECODE_TOK_S_SPEC:-$fake_decode_tok_s}
    fake_draft_n=${QWEN_FAKE_SERVER_DRAFT_N:-64}
    fake_draft_accepted=${QWEN_FAKE_SERVER_DRAFT_ACCEPTED:-48}
    if [ -n "${QWEN_FAKE_SERVER_TOKENS_SPEC:-}" ]; then
        fake_tokens=$QWEN_FAKE_SERVER_TOKENS_SPEC
    fi
fi

# The prefill ladder reads a streamed completion, so the fixture answers one
# whenever the request body sets `stream`. Six variables drive the paths that
# ladder refuses on: a first-chunk delay stands in for the prefill a time to
# first token measures, a tokenize multiplier makes the prompt-length loop
# oscillate rather than converge, a prompt_n skew separates the served count
# from the tokenized one, omitting the timings object drives the arm's
# missing-timings refusal, a predicted_n skew reports a decoded count other
# than the one requested without changing what was actually decoded, and a
# prompt_per_second override reports a rate the served counts and elapsed time
# do not back, which is the request client's positivity check.
QWEN_FAKE_SERVER_FIRST_TOKEN_DELAY_S=${QWEN_FAKE_SERVER_FIRST_TOKEN_DELAY_S:-0} \
QWEN_FAKE_SERVER_TOKENIZE_MULTIPLIER=${QWEN_FAKE_SERVER_TOKENIZE_MULTIPLIER:-1} \
QWEN_FAKE_SERVER_PROMPT_N_SKEW=${QWEN_FAKE_SERVER_PROMPT_N_SKEW:-0} \
QWEN_FAKE_SERVER_OMIT_TIMINGS=${QWEN_FAKE_SERVER_OMIT_TIMINGS:-0} \
QWEN_FAKE_SERVER_PREDICTED_N_SKEW=${QWEN_FAKE_SERVER_PREDICTED_N_SKEW:-0} \
QWEN_FAKE_SERVER_PROMPT_PER_SECOND_OVERRIDE=${QWEN_FAKE_SERVER_PROMPT_PER_SECOND_OVERRIDE:-} \
QWEN_FAKE_SERVER_PROMPT_TOK_S=${QWEN_FAKE_SERVER_PROMPT_TOK_S:-20.00} \
QWEN_FAKE_SERVER_RESOLVED_PORT=$serving_port \
QWEN_FAKE_SERVER_RESOLVED_TOKENS=$fake_tokens \
QWEN_FAKE_SERVER_RESOLVED_DECODE_TOK_S=$fake_decode_tok_s \
QWEN_FAKE_SERVER_RESOLVED_DRAFT_N=$fake_draft_n \
QWEN_FAKE_SERVER_RESOLVED_DRAFT_ACCEPTED=$fake_draft_accepted \
QWEN_POLICY_TEST_IMAGE_TOKENS=${QWEN_POLICY_TEST_IMAGE_TOKENS:-300} \
QWEN_POLICY_TEST_REPLY=${QWEN_POLICY_TEST_REPLY:-JUN} \
QWEN_POLICY_TEST_PREDICTED_CAP=${QWEN_POLICY_TEST_PREDICTED_CAP:-0} \
    exec python3 - <<'PY'
import json
import os
import socket
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

port = int(os.environ["QWEN_FAKE_SERVER_RESOLVED_PORT"])
tokens = [int(value) for value in os.environ["QWEN_FAKE_SERVER_RESOLVED_TOKENS"].split()]
image_tokens = int(os.environ["QWEN_POLICY_TEST_IMAGE_TOKENS"])
reply = os.environ["QWEN_POLICY_TEST_REPLY"]
# A positive cap stops the reply short of the requested length, which is the
# shape a fixed-length decode fails in: the answer arrives and carries fewer
# tokens than the caller asked for.
predicted_cap = int(os.environ["QWEN_POLICY_TEST_PREDICTED_CAP"])
decode_tok_s = float(os.environ["QWEN_FAKE_SERVER_RESOLVED_DECODE_TOK_S"])
draft_n = int(os.environ["QWEN_FAKE_SERVER_RESOLVED_DRAFT_N"])
draft_accepted = int(os.environ["QWEN_FAKE_SERVER_RESOLVED_DRAFT_ACCEPTED"])
post_delay_s = float(os.environ.get("QWEN_POLICY_TEST_POST_DELAY_S", "0"))
first_token_delay_s = float(os.environ["QWEN_FAKE_SERVER_FIRST_TOKEN_DELAY_S"])
tokenize_multiplier = int(os.environ["QWEN_FAKE_SERVER_TOKENIZE_MULTIPLIER"])
prompt_n_skew = int(os.environ["QWEN_FAKE_SERVER_PROMPT_N_SKEW"])
omit_timings = os.environ["QWEN_FAKE_SERVER_OMIT_TIMINGS"] == "1"
predicted_n_skew = int(os.environ["QWEN_FAKE_SERVER_PREDICTED_N_SKEW"])
prompt_per_second_override_text = os.environ.get(
    "QWEN_FAKE_SERVER_PROMPT_PER_SECOND_OVERRIDE", "")
prompt_per_second_override = (
    float(prompt_per_second_override_text)
    if prompt_per_second_override_text else None)
prompt_tok_s = float(os.environ["QWEN_FAKE_SERVER_PROMPT_TOK_S"])
request_directory_text = os.environ.get("QWEN_FAKE_SERVER_REQUEST_DIRECTORY", "")
request_directory = Path(request_directory_text) if request_directory_text else None
if request_directory is not None:
    request_directory.mkdir(parents=True, exist_ok=True)
takeover_request_marker = os.environ.get(
    "QWEN_FAKE_SERVER_TAKEOVER_REQUEST_MARKER", "")
takeover_ready_marker = os.environ.get(
    "QWEN_FAKE_SERVER_TAKEOVER_READY_MARKER", "")
rebind_on_completion = os.environ.get(
    "QWEN_FAKE_SERVER_REBIND_ON_COMPLETION", "") == "1"
rebind_on_post_health = os.environ.get(
    "QWEN_FAKE_SERVER_REBIND_ON_POST_HEALTH", "") == "1"


def rebind_listener(server):
    server.server_close()
    server.socket = socket.socket(server.address_family, server.socket_type)
    server.server_bind()
    server.server_activate()


class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True


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

    def stream_completion(self, emitted, timings):
        """One server-sent event per token, closed by the chunk carrying timings.

        The first chunk is held back by the configured delay, so a reader
        measuring the wall time to the first content delta reads that delay
        rather than the socket's own latency. Each event is flushed where it is
        written, which is what makes the delay observable at all.
        """
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        if first_token_delay_s > 0:
            time.sleep(first_token_delay_s)
        for token_id in emitted:
            self.wfile.write(
                f"data: {json.dumps({'content': str(token_id), 'stop': False})}\n\n".encode())
            self.wfile.flush()
        final = {"content": "", "stop": True, "tokens": emitted}
        if not omit_timings:
            final["timings"] = timings
        self.wfile.write(f"data: {json.dumps(final)}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()

    def do_GET(self):
        if self.path.startswith("/health"):
            if (
                rebind_on_post_health
                and self.server.request_count > 0
                and not self.server.health_rebound
            ):
                self.server.health_rebound = True
                rebind_listener(self.server)
            self.respond({"status": "ok"})
        else:
            self.send_error(404)

    def do_POST(self):
        if post_delay_s > 0:
            time.sleep(post_delay_s)
        length = int(self.headers.get("Content-Length") or 0)
        request_bytes = self.rfile.read(length)
        self.server.request_count += 1
        if request_directory is not None:
            request_path = request_directory / (
                f"request-{os.getpid()}-{self.server.request_count}.bin"
            )
            request_path.write_bytes(request_bytes)
        body = json.loads(request_bytes.decode() or "{}")
        if self.path.startswith("/tokenize"):
            words = len(str(body.get("content", "")).split())
            self.respond({"tokens": list(range(words * tokenize_multiplier))})
            return
        # The token-identity route. A fixed cycle over the configured array
        # fills the requested length, so the reply is exactly as long as
        # n_predict asked and differs between arms only where the array does.
        if self.path.startswith("/completion"):
            predict = int(body.get("n_predict") or len(tokens))
            emitted = [tokens[index % len(tokens)] for index in range(predict)]
            prompt_n = (len(str(body.get("prompt", "")).split())
                        * tokenize_multiplier + prompt_n_skew)
            reported_prompt_per_second = (
                prompt_per_second_override
                if prompt_per_second_override is not None else prompt_tok_s)
            timings = {
                "prompt_n": prompt_n,
                "prompt_ms": prompt_n * 1000.0 / prompt_tok_s,
                "prompt_per_second": reported_prompt_per_second,
                # The emitted array below stays exactly `predict` tokens long,
                # so a nonzero skew here reports a decoded count the server
                # never actually decoded rather than changing what it did.
                "predicted_n": predict + predicted_n_skew,
                "predicted_ms": max(predict - 1, 0) * 1000.0 / decode_tok_s,
                "predicted_per_second": decode_tok_s,
            }
            if body.get("stream"):
                self.stream_completion(emitted, timings)
                return
            if draft_n > 0:
                timings["draft_n"] = draft_n
                timings["draft_n_accepted"] = draft_accepted
            if rebind_on_completion and not self.server.completion_rebound:
                self.server.completion_rebound = True
                rebind_listener(self.server)
            if takeover_request_marker and not self.server.takeover_started:
                self.server.takeover_started = True
                self.server.server_close()
                Path(takeover_request_marker).write_text("requested\n")
                takeover_deadline = time.monotonic() + 10
                while not Path(takeover_ready_marker).exists():
                    if time.monotonic() >= takeover_deadline:
                        raise RuntimeError("listener takeover did not become ready")
                    time.sleep(0.01)
            self.respond({"content": "", "tokens": emitted,
                          "timings": timings})
            return
        if not self.path.startswith("/v1/chat/completions"):
            self.send_error(404)
            return
        prompt_tokens = 0
        for message in body.get("messages") or []:
            content = message.get("content") or ""
            if isinstance(content, str):
                prompt_tokens += len(content.split())
                continue
            for part in content:
                if not isinstance(part, dict):
                    continue
                if part.get("type") == "text":
                    prompt_tokens += len(part.get("text", "").split())
                if part.get("type") == "image_url":
                    prompt_tokens += image_tokens
        predicted = int(body.get("max_tokens") or 1)
        if predicted_cap > 0:
            predicted = min(predicted, predicted_cap)
        predicted_ms = max(predicted - 1, 0) * 1000.0 / decode_tok_s
        self.respond({
            "choices": [{"message": {"role": "assistant", "content": reply}}],
            "timings": {"prompt_n": prompt_tokens, "prompt_ms": 1000.0,
                        "prompt_per_second": float(prompt_tokens),
                        "predicted_n": predicted,
                        "predicted_ms": predicted_ms,
                        "predicted_per_second": decode_tok_s}})


server = ReusableHTTPServer(("127.0.0.1", port), Handler)
server.takeover_started = False
server.completion_rebound = False
server.health_rebound = False
server.request_count = 0
server.serve_forever()
PY
