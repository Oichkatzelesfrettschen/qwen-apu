#!/usr/bin/env python3
"""Minimal HTTP fixture answering GET /v1/models and POST /v1/chat/completions.

remote/test-run-conversational-suite.sh drives remote/run-conversational-suite.sh
end to end without a device or a browser: the shell script's own HTTP calls --
the servable-roster check and the web-off grading arm's requests -- need an
endpoint, and remote/test-fixtures/fake-router-server.py answers a shape built
for the image admission's preset, tool proxy, and streaming chat completion,
none of which the web-off arm's plain graded rows exercise. This is the
narrower stand-in the same way remote/test-admit-image-router.sh stubs only
the device-owning links and leaves the rest of the chain real: the roster and
the one scripted reply travel through environment variables the test sets, and
everything downstream of this fixture -- run-quality-suite.py's grading,
resolve-web-profile.py's ledger join, the manifest, and the summarizer -- is
the tree's own code under test.

usage: fake-chat-router.py --port PORT
environment:
    QWEN_FAKE_CHAT_MODELS   comma-separated ids GET /v1/models returns
    QWEN_FAKE_CHAT_CONTENT  the message content every chat completion answers
"""

import http.server
import json
import os
import sys


class Handler(http.server.BaseHTTPRequestHandler):
    def _write(self, status, document):
        body = json.dumps(document).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        if self.path.startswith("/v1/models"):
            ids = [entry for entry in os.environ.get("QWEN_FAKE_CHAT_MODELS", "").split(",") if entry]
            self._write(200, {"object": "list",
                              "data": [{"id": entry, "object": "model"} for entry in ids]})
            return
        self._write(404, {"error": {"message": f"no route: {self.path}"}})

    def do_POST(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        if self.path.startswith("/v1/chat/completions"):
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b"{}"
            try:
                body = json.loads(raw)
            except ValueError:
                body = {}
            content = os.environ.get("QWEN_FAKE_CHAT_CONTENT", "answer")
            self._write(200, {
                "id": "chatcmpl-fixture",
                "object": "chat.completion",
                "model": body.get("model"),
                "choices": [{"index": 0,
                            "message": {"role": "assistant", "content": content},
                            "finish_reason": "stop"}],
                "timings": {"predicted_n": 1, "prompt_n": 1, "predicted_per_second": 1.0},
            })
            return
        self._write(404, {"error": {"message": f"no route: {self.path}"}})

    def log_message(self, *_arguments):
        pass


def main(argv):
    port = 0
    if "--port" in argv:
        port = int(argv[argv.index("--port") + 1])
    server = http.server.HTTPServer(("127.0.0.1", port), Handler)
    print(f"listening port={server.server_address[1]}", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
