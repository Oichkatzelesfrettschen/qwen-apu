#!/usr/bin/env python3
"""Stand in for llama-server's Anthropic Messages and OpenAI chat routes over
one HTTP listener, so remote/test-code-agent-endpoint.sh can be driven without
an appliance.

Serves GET /health, GET /v1/models, POST /v1/messages (streamed and
non-streamed, including a forced tool_choice reply), POST
/v1/messages/count_tokens, and POST /v1/chat/completions. The listener binds
127.0.0.1:0 and prints the chosen port as one line ("port=NNNN") before
serving, so a caller never races a fixed port against the serial test runner
that owns this repository's other fixed test ports.

usage: fake-code-agent-server.py --model ID [--model ID...]
"""

import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SSE_TEXT = "ready"


def anthropic_message(model, content, stop_reason, usage):
    return {
        "id": "msg_fake0001",
        "type": "message",
        "role": "assistant",
        "model": model,
        "content": content,
        "stop_reason": stop_reason,
        "usage": usage,
    }


def sse_body(model, text):
    """The event sequence https://openrouter... (Anthropic's documented SSE
    shape) names: message_start, one content block's start/delta/stop,
    message_delta, message_stop -- each an "event: TYPE" line followed by a
    "data: {...}" line and a blank line."""
    events = []

    def emit(event_type, data):
        events.append(
            "event: %s\ndata: %s\n\n" % (event_type, json.dumps(data))
        )

    emit(
        "message_start",
        {
            "type": "message_start",
            "message": anthropic_message(
                model, [], None, {"input_tokens": 5, "output_tokens": 0}
            ),
        },
    )
    emit(
        "content_block_start",
        {
            "type": "content_block_start",
            "index": 0,
            "content_block": {"type": "text", "text": ""},
        },
    )
    emit(
        "content_block_delta",
        {
            "type": "content_block_delta",
            "index": 0,
            "delta": {"type": "text_delta", "text": text},
        },
    )
    emit("content_block_stop", {"type": "content_block_stop", "index": 0})
    emit(
        "message_delta",
        {
            "type": "message_delta",
            "delta": {"stop_reason": "end_turn"},
            "usage": {"output_tokens": len(text.split())},
        },
    )
    emit("message_stop", {"type": "message_stop"})
    return "".join(events).encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    model_ids = ()

    def log_message(self, format_string, *args):  # noqa: A002 - stdlib name
        pass

    def _read_json(self):
        length = int(self.headers.get("content-length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode("utf-8")) if raw else {}

    def _write_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802 - BaseHTTPRequestHandler naming
        if self.path == "/health":
            self._write_json(200, {"status": "ok"})
            return
        if self.path == "/v1/models":
            self._write_json(
                200, {"data": [{"id": model_id} for model_id in self.model_ids]}
            )
            return
        self._write_json(404, {"error": "not_found"})

    def do_POST(self):  # noqa: N802 - BaseHTTPRequestHandler naming
        if self.path == "/v1/messages":
            self._handle_messages()
            return
        if self.path == "/v1/messages/count_tokens":
            body = self._read_json()
            messages = body.get("messages", [])
            characters = sum(
                len(str(message.get("content", ""))) for message in messages
            )
            self._write_json(200, {"input_tokens": max(1, characters // 4) + 4})
            return
        if self.path == "/v1/chat/completions":
            self._handle_chat_completions()
            return
        self._write_json(404, {"error": "not_found"})

    def _handle_messages(self):
        body = self._read_json()
        model = body.get("model", "")
        tools = body.get("tools") or []
        tool_choice = body.get("tool_choice") or {}
        if tools and tool_choice.get("type") in ("any", "tool"):
            content = [
                {
                    "type": "tool_use",
                    "id": "toolu_fake0001",
                    "name": tools[0]["name"],
                    "input": {},
                }
            ]
            usage = {"input_tokens": 9, "output_tokens": 6}
            if body.get("stream"):
                self.send_response(200)
                self.send_header("content-type", "text/event-stream")
                self.end_headers()
                self.wfile.write(sse_body(model, SSE_TEXT))
                return
            self._write_json(
                200, anthropic_message(model, content, "tool_use", usage)
            )
            return
        if body.get("stream"):
            self.send_response(200)
            self.send_header("content-type", "text/event-stream")
            self.end_headers()
            self.wfile.write(sse_body(model, SSE_TEXT))
            return
        content = [{"type": "text", "text": SSE_TEXT}]
        usage = {
            "input_tokens": 5,
            "output_tokens": 2,
            "cache_read_input_tokens": 0,
        }
        self._write_json(200, anthropic_message(model, content, "end_turn", usage))

    def _handle_chat_completions(self):
        body = self._read_json()
        model = body.get("model", "")
        self._write_json(
            200,
            {
                "id": "chatcmpl-fake0001",
                "object": "chat.completion",
                "model": model,
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": SSE_TEXT},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {
                    "prompt_tokens": 5,
                    "completion_tokens": 2,
                    "total_tokens": 7,
                },
            },
        )


def parse_arguments(argv):
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--model", action="append", dest="models", required=True)
    return parser.parse_args(argv)


def main(argv):
    arguments = parse_arguments(argv)
    Handler.model_ids = tuple(arguments.models)
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    print("port=%d" % server.server_address[1], flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
