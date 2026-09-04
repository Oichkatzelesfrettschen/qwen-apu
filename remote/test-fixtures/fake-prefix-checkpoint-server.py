#!/usr/bin/env python3
"""A llama-server stand-in for the schema-bound prefix checkpoint harness.

The real mechanism `patches/llama-server-prefix-checkpoint.patch` adds pins one
whole sequence state at the first eligible request's last-user-message boundary
and restores it for any later request whose rendered head reproduces the same
bytes. This fixture reproduces that admission rule at the level the harness
reads it: a rendered "head" (the system prompt and the tool schema array,
joined the way a chat template would fold them into one preamble) decides
whether a `/v1/chat/completions` request is served by a capture, a restore, or
neither, and every decision is both charged in the response `timings` and
logged in the format `server-prefix-checkpoint.h` and its call sites emit, so a
harness reading the log alone sees the same words a real server would print.

One whitespace-separated word is one token, which keeps the harness's own
fixed-length user messages exact rather than approximate.

`/completion` is the raw route the patch's own analysis names as outside the
mechanism's reach: no chat template runs over it, so no head is rendered, no
capture or restore is attempted, and the whole prompt is charged every time.

Environment:
  QWEN_FAKE_PREFIX_CHECKPOINT_LOG        path the server-format lines append to
  QWEN_FAKE_PREFIX_CHECKPOINT_SIZE_MIB   the captured blob size, default 12.5
  QWEN_FAKE_PREFIX_CHECKPOINT_MS_PER_TOKEN  prompt cost per token, default 1.0
  QWEN_FAKE_PREFIX_CHECKPOINT_OPERATION_MS  capture/restore op cost, default 5.0
  QWEN_FAKE_PREFIX_CHECKPOINT_ARMED      0 disarms the whole mechanism; every
                                          request then reads as a full-cost miss
                                          and the log carries neither line, the
                                          shape an unarmed launch produces
"""

import hashlib
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
log_path = os.environ.get("QWEN_FAKE_PREFIX_CHECKPOINT_LOG")
if not log_path:
    sys.stderr.write("QWEN_FAKE_PREFIX_CHECKPOINT_LOG is required\n")
    raise SystemExit(2)
size_mib = float(os.environ.get("QWEN_FAKE_PREFIX_CHECKPOINT_SIZE_MIB", "12.5"))
ms_per_token = float(os.environ.get("QWEN_FAKE_PREFIX_CHECKPOINT_MS_PER_TOKEN", "1.0"))
operation_ms = float(os.environ.get("QWEN_FAKE_PREFIX_CHECKPOINT_OPERATION_MS", "5.0"))
armed = os.environ.get("QWEN_FAKE_PREFIX_CHECKPOINT_ARMED", "1") != "0"

pinned = {"key": None, "head_text": None, "n_tokens": 0}


def log_line(text):
    with open(log_path, "a", encoding="utf-8") as handle:
        handle.write(text + "\n")


def tokenize(text):
    return len(text.split())


def head_text_of(system_prompt, tools):
    # A chat template folds the system prompt and the rendered tool schemas
    # into one preamble; joining the two strings with a stable separator is
    # this fixture's stand-in for that rendering.
    return system_prompt + "\x00" + json.dumps(tools, sort_keys=True)


def head_key_of(head_text):
    return hashlib.sha256(head_text.encode("utf-8")).hexdigest()


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
        elif self.path.startswith("/slots"):
            self.respond([{"id": 0, "is_processing": False}])
        elif self.path.startswith("/metrics"):
            body = b"# fake metrics\nllamacpp:requests_processing 0\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length).decode() or "{}")
        if self.path.startswith("/v1/chat/completions"):
            self.chat_completion(body)
            return
        if self.path.startswith("/completion"):
            self.raw_completion(body)
            return
        self.send_error(404)

    def raw_completion(self, body):
        # No chat template runs over this route, so no head is rendered and
        # the mechanism the harness measures never engages.
        prompt = body.get("prompt", "")
        predict = int(body.get("n_predict") or 1)
        prompt_n = tokenize(prompt)
        prompt_ms = prompt_n * ms_per_token
        self.respond(
            {
                "content": "raw reply",
                "timings": {
                    "prompt_n": prompt_n,
                    "prompt_ms": prompt_ms,
                    "prompt_per_second": (prompt_n / prompt_ms * 1000.0)
                    if prompt_ms
                    else 0.0,
                    "predicted_n": predict,
                    "predicted_ms": predict * 10.0,
                    "predicted_per_second": 100.0,
                },
            }
        )

    def chat_completion(self, body):
        messages = body.get("messages", [])
        system_prompt = next(
            (
                message.get("content", "")
                for message in messages
                if message.get("role") == "system"
            ),
            "",
        )
        user_prompt = next(
            (
                message.get("content", "")
                for message in messages
                if message.get("role") == "user"
            ),
            "",
        )
        tools = body.get("tools", [])
        predict = int(body.get("max_tokens") or body.get("n_predict") or 1)

        head_text = head_text_of(system_prompt, tools)
        head_key = head_key_of(head_text)
        head_tokens = tokenize(head_text)
        user_tokens = tokenize(user_prompt)

        if armed and pinned["key"] == head_key:
            prompt_n = user_tokens
            took_ms = operation_ms
            log_line(
                f"slot restored prefix checkpoint, n_past = {pinned['n_tokens']}, "
                f"size = {size_mib:.3f} MiB, took {took_ms:.2f} ms, key = {head_key}"
            )
        elif armed and pinned["key"] is None:
            # The first eligible request pins the head it met first; the pin
            # fills once and the capture logs before this same request is
            # charged, which is why arm A still pays for the whole head.
            pinned["key"] = head_key
            pinned["head_text"] = head_text
            pinned["n_tokens"] = head_tokens
            prompt_n = head_tokens + user_tokens
            log_line(
                f"slot captured prefix checkpoint, n_tokens = {head_tokens}, "
                f"size = {size_mib:.3f} MiB, took {operation_ms:.2f} ms, key = {head_key}"
            )
        else:
            # A divergent head, or the mechanism disarmed outright: the
            # request recomputes everything and the log states neither line,
            # since the fill-once pin is never offered a request it does not
            # cover.
            prompt_n = head_tokens + user_tokens

        prompt_ms = prompt_n * ms_per_token
        self.respond(
            {
                "choices": [{"message": {"role": "assistant", "content": "reply"}}],
                "timings": {
                    "prompt_n": prompt_n,
                    "prompt_ms": prompt_ms,
                    "prompt_per_second": (prompt_n / prompt_ms * 1000.0)
                    if prompt_ms
                    else 0.0,
                    "predicted_n": predict,
                    "predicted_ms": predict * 10.0,
                    "predicted_per_second": 100.0,
                },
            }
        )


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
