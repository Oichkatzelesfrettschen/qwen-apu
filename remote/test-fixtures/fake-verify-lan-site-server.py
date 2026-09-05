#!/usr/bin/env python3
"""Stand in for the three HTTP origins remote/verify-lan-site.sh checks: the
router, the approval broker, and the artifact listener. remote/test-verify-
lan-site.sh runs this in the background so every curl-and-jq row in the
verification -- page GET, /health, the /v1/models roster, /props, each
origin's own /health, and the tool-prefix checkpoint's two chat completions --
answers without a device, a browser, or a network.

The chat-completion route reproduces the checkpoint behavior
evidence/tool-prefix-checkpoint/README.md registers rather than a fixed
number: the first request carrying a given system-prompt-and-tool-schema head
is charged the whole head plus its own user message, the way an uncached
prompt is, and a later request sharing that exact head is charged its own
user message alone, the way a restored checkpoint is.
QWEN_FAKE_VERIFY_SERVER_NO_CHECKPOINT disables the discount, so a test can
prove the check fails against a server that never restores one.

usage: fake-verify-lan-site-server.py --router-port N --broker-port N
    --artifacts-port N --static DIR [--roster ID,ID] [--unhealthy]
"""

import argparse
import http.server
import json
import os
import threading


def make_router_handler(state):
    class RouterHandler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *arguments):  # noqa: N802
            pass

        def _send_json(self, code, payload):
            body = json.dumps(payload).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):  # noqa: N802
            path = self.path.split("?", 1)[0]
            if path in ("/", "/index.html"):
                body = state["static_page"].encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            if path == "/health":
                self._send_json(200, {"status": "ok" if state["healthy"] else "error"})
                return
            if path == "/v1/models":
                self._send_json(200, {
                    "object": "list",
                    "data": [{"id": row_id, "object": "model"} for row_id in state["roster"]],
                })
                return
            if path == "/props":
                self._send_json(200, {"default_generation_settings": {"n_ctx": 4096}})
                return
            self._send_json(404, {"error": "no route: " + path})

        def do_POST(self):  # noqa: N802
            if self.path.split("?", 1)[0] != "/v1/chat/completions":
                self._send_json(404, {"error": "no route: " + self.path})
                return
            length = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(length) if length else b"{}"
            if state["hang_chat"]:
                # a router that never answers, the shape the e909cfc epoch
                # record retains; the checker's own timeout is what ends it
                threading.Event().wait()
            try:
                body = json.loads(raw.decode("utf-8"))
            except ValueError:
                body = {}
            messages = body.get("messages") or []
            system_text = ""
            user_text = ""
            for message in messages:
                if message.get("role") == "system":
                    system_text = message.get("content") or ""
                if message.get("role") == "user":
                    user_text = message.get("content") or ""
            tools_text = json.dumps(body.get("tools") or [], sort_keys=True)
            signature = system_text + "\x00" + tools_text
            user_tokens = max(1, len(user_text.split()))
            with state["lock"]:
                restores = (not state["no_checkpoint"]) and state.get("last_signature") == signature
                if restores:
                    prompt_n = user_tokens
                else:
                    prompt_n = len(system_text.split()) + len(tools_text.split()) + user_tokens
                state["last_signature"] = signature
            self._send_json(200, {
                "id": "chatcmpl-fixture",
                "object": "chat.completion",
                "model": body.get("model"),
                "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": "4"},
                    "finish_reason": "stop",
                }],
                "timings": {"prompt_n": prompt_n},
                "usage": {"prompt_tokens": prompt_n},
            })

    return RouterHandler


def make_health_handler(protocol_name):
    class HealthHandler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *arguments):  # noqa: N802
            pass

        def do_GET(self):  # noqa: N802
            if self.path.split("?", 1)[0] == "/health":
                body = json.dumps({"protocol": protocol_name}).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            self.send_response(404)
            self.end_headers()

    return HealthHandler


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--router-port", type=int, required=True)
    parser.add_argument("--broker-port", type=int, required=True)
    parser.add_argument("--artifacts-port", type=int, required=True)
    parser.add_argument("--static", required=True)
    parser.add_argument("--roster", default="fixture-model")
    parser.add_argument("--unhealthy", action="store_true")
    parser.add_argument("--hang-chat", action="store_true",
                        help="never answer a chat completion")
    arguments = parser.parse_args()

    with open(os.path.join(arguments.static, "index.html"), encoding="utf-8") as handle:
        static_page = handle.read()

    state = {
        "roster": arguments.roster.split(","),
        "lock": threading.Lock(),
        "healthy": not arguments.unhealthy,
        "hang_chat": arguments.hang_chat,
        "static_page": static_page,
        "no_checkpoint": os.environ.get("QWEN_FAKE_VERIFY_SERVER_NO_CHECKPOINT") == "1",
        "last_signature": None,
    }

    router = http.server.ThreadingHTTPServer(("127.0.0.1", arguments.router_port),
                                              make_router_handler(state))
    broker = http.server.ThreadingHTTPServer(("127.0.0.1", arguments.broker_port),
                                              make_health_handler("qwen-web-broker/1"))
    artifacts = http.server.ThreadingHTTPServer(("127.0.0.1", arguments.artifacts_port),
                                                 make_health_handler("qwen-image-service/1"))
    for server in (router, broker, artifacts):
        threading.Thread(target=server.serve_forever, daemon=True).start()
    print("listening router={} broker={} artifacts={}".format(
        arguments.router_port, arguments.broker_port, arguments.artifacts_port), flush=True)
    threading.Event().wait()


if __name__ == "__main__":
    main()
