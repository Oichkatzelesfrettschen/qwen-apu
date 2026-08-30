#!/usr/bin/env python3
"""A llama-server stand-in for the context checkpoint sweep.

One whitespace-separated word is 1.3 tokens through /tokenize, which makes
the harness rescale its filler at least once. /completion charges one
millisecond per prompt token it computes: a prompt sharing the previous
prompt's prefix costs the suffix alone when QWEN_FAKE_CTX_CHECKPOINTS is above
zero, and the whole prompt at zero, which is the shape a recurrent state
without a saved checkpoint forces. The greedy ids are a fixed cycle, and
QWEN_FAKE_DIVERGE_AT names one checkpoint count whose ids are shifted so a
caller's divergence check has something to find.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
ctx_checkpoints = int(os.environ.get("QWEN_FAKE_CTX_CHECKPOINTS", "0"))
diverge_at = os.environ.get("QWEN_FAKE_DIVERGE_AT", "")
previous_prompt = [""]


def tokenize(text):
    return int(len(text.split()) * 1.3)


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
            self.respond({"tokens": list(range(tokenize(body.get("content", ""))))})
            return
        if not self.path.startswith("/completion"):
            self.send_error(404)
            return
        prompt = body.get("prompt", "")
        prompt_n = tokenize(prompt)
        shared = 0
        if ctx_checkpoints > 0 and previous_prompt[0] and prompt.startswith(previous_prompt[0]):
            shared = tokenize(previous_prompt[0])
        previous_prompt[0] = prompt
        computed = prompt_n - shared
        predict = int(body.get("n_predict") or 1)
        base = 100 if diverge_at == str(ctx_checkpoints) else 10
        tokens = [base + (index % 8) for index in range(predict)]
        self.respond({
            "content": "",
            "tokens": tokens,
            "timings": {"prompt_n": prompt_n, "prompt_ms": float(computed),
                        "predicted_n": predict, "predicted_ms": predict * 10.0},
        })


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
