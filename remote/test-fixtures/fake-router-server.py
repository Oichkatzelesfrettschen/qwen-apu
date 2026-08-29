#!/usr/bin/env python3
"""Stand in for the patched router llama-server so an admission runs without a GPU.

`remote/test-fixtures/fake-llama-server.sh` answers `/health`, `/tokenize`, and
`/completion` for the policy, projector, and graph-alias lanes, and the image
admission needs a different surface: the roster and `/props` a page selects a
model from, `GET /tools` and `POST /tools` in the shape
`patches/llama-router-tools-proxy.patch` puts on the router port, a streaming
chat completion that proposes one `generate_image` call, and the fallback page
itself at `/`. Adding those to the shell fixture would change what three other
lanes measure, so this is a second fixture rather than a mode of the first.

What it reproduces of the router is the routing rule the admission tests. `GET
/tools` resolves the model from `?model=`, `POST /tools` resolves it from the
body's top-level `model` key, and the request reaches the MCP child the named
section's `LLAMA_ARG_MCP_SERVERS_CONFIG` configures. `tool`, `params`, and
`stream` are the only body keys forwarded, so the routing key provably stays
out of the tool arguments and the child's own schema refuses one that appears
there. An `isError` result becomes an `error` key at HTTP 200, which is what
`mcp_result_to_response` does and what the page reads a refusal from.

What it stands in for is the device. There is no model: the chat completion is
a fixed script, and `QWEN_FAKE_ROUTER_IMAGE_ARGUMENTS` names the JSON the one
proposed `generate_image` call carries. A turn that carries a tool message
already reads the closing plain-text answer, so the fixture proposes once per
turn the way a model that read its own result would.

The child is spawned per call over stdio, the way llama-server spawns an MCP
server for one invocation, and its stderr reaches this process's stderr so a
child that refused startup names its reason in the server log.

usage: fake-router-server.py --models-preset FILE --host HOST --port PORT
                             [--path STATIC] [--api-key-file FILE] [--ui]
"""

import http.server
import json
import os
import shlex
import socketserver
import subprocess
import sys
import threading
import urllib.parse

MCP_PROTOCOL_VERSION = "2024-11-05"


def parse_arguments(argv):
    """Return the router settings out of the argv the capacity policy builds.

    An unknown flag is skipped rather than refused: the policy adds submission
    geometry, cache, and profile arguments this fixture has no use for, and a
    strict parser would turn every policy change into a fixture failure.
    """
    settings = {
        "preset": "",
        "host": "127.0.0.1",
        "port": 0,
        "static": "",
        "api_key_file": "",
    }
    named = {
        "--models-preset": "preset",
        "--host": "host",
        "--port": "port",
        "--path": "static",
        "--api-key-file": "api_key_file",
    }
    index = 0
    while index < len(argv):
        token = argv[index]
        if token in named and index + 1 < len(argv):
            settings[named[token]] = argv[index + 1]
            index += 2
            continue
        index += 1
    settings["port"] = int(settings["port"])
    return settings


def read_preset(path):
    """Return the one section this preset names, as (section_id, keys).

    The fixture serves a single-section web preset, which is what
    `qwen-web-launch.sh` requires of every launch it performs, so a file
    carrying two sections is a preset this fixture cannot stand in for.
    """
    sections = {}
    order = []
    current = None
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if stripped.startswith("[") and stripped.endswith("]"):
                current = stripped[1:-1]
                sections[current] = {}
                order.append(current)
                continue
            if current is None or "=" not in stripped:
                continue
            name, value = stripped.split("=", 1)
            sections[current][name.strip()] = value.strip()
    if len(order) != 1:
        raise SystemExit(
            f"the fixture router serves one preset section; {path} names {len(order)}"
        )
    return order[0], sections[order[0]]


class MissingTools(Exception):
    """The section configures no MCP server, so the route answers as the binary does."""


class ToolChild:
    """One spawned MCP server, driven over stdio for the life of one call."""

    def __init__(self, configuration_path):
        with open(configuration_path, encoding="utf-8") as handle:
            configuration = json.load(handle)
        servers = configuration.get("mcpServers") or {}
        if not servers:
            raise MissingTools("the configuration names no server")
        self.servers = servers

    def call(self, method, params):
        """Return the result of one JSON-RPC method against every named server.

        Each server is spawned, initialized, driven once, and closed, so a
        crashed child costs one call rather than the route. The results are
        concatenated in the configuration's own key order.
        """
        results = []
        for name, definition in self.servers.items():
            results.append((name, self._one(definition, method, params)))
        return results

    @staticmethod
    def _one(definition, method, params):
        command = [definition.get("command", "python3")] + list(definition.get("args") or [])
        environment = dict(os.environ)
        environment.update({
            str(key): str(value) for key, value in (definition.get("env") or {}).items()
        })
        child = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=sys.stderr,
            env=environment,
            text=True,
        )
        try:
            # The child bounds its own call at QWEN_IMAGE_MCP_TIMEOUT_S and
            # answers a stalled service itself, so the read here waits on that
            # deadline rather than adding a second one above it.
            def exchange(payload):
                child.stdin.write(json.dumps(payload) + "\n")
                child.stdin.flush()
                line = child.stdout.readline()
                if not line:
                    raise RuntimeError("the MCP child closed its output")
                return json.loads(line)

            exchange({
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": MCP_PROTOCOL_VERSION},
            })
            return exchange(
                {"jsonrpc": "2.0", "id": 2, "method": method, "params": params}
            )
        finally:
            try:
                child.stdin.close()
            except OSError:
                pass
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()


def tool_listing(child):
    """Return the `[{tool, definition}]` shape the page composes body.tools from."""
    listing = []
    for _, reply in child.call("tools/list", {}):
        for tool in (reply.get("result") or {}).get("tools") or []:
            listing.append({
                "tool": tool["name"],
                "definition": {
                    "type": "function",
                    "function": {
                        "name": tool["name"],
                        "description": tool.get("description", ""),
                        "parameters": tool.get("inputSchema") or {"type": "object"},
                    },
                },
            })
    return listing


def call_tool(child, name, params):
    """Return the HTTP body one tool call produces.

    `mcp_result_to_response` maps an `isError` result onto an `error` key at
    HTTP 200, so a refusal is read from the body rather than from the status,
    and the page and the shell harness both read it there.
    """
    for server_name, definition in child.servers.items():
        reply = ToolChild._one(
            definition, "tools/call", {"name": name, "arguments": params}
        )
        if "error" in reply:
            return {"error": reply["error"].get("message", "the tool call failed")}
        result = reply.get("result") or {}
        text = "".join(
            part.get("text", "") for part in (result.get("content") or [])
            if part.get("type") == "text"
        )
        if result.get("isError"):
            return {"error": text or f"{server_name} refused the call"}
        return {"plain_text_response": text}
    return {"error": "no server answered the call"}


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "qwen-fake-router/1"
    sys_version = ""

    def log_message(self, fmt, *args):
        """Drop the access log; the admission reads the page's own request log."""

    @property
    def settings(self):
        return self.server.router_settings

    def authorized(self):
        expected = self.settings["api_key"]
        if not expected:
            return True
        return self.headers.get("Authorization", "") == f"Bearer {expected}"

    def send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def send_error_object(self, status, message, kind="invalid_request_error"):
        self.send_json(status, {"error": {"code": status, "message": message, "type": kind}})

    def read_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except ValueError:
            return {}

    def resolve_model(self, named):
        """Refuse a request naming no model or one outside the roster.

        The router resolves `/tools` the way it resolves `/props`, so an absent
        and an unknown name are separate refusals and neither reaches a child.
        """
        if not named:
            self.send_error_object(400, "a model must be named")
            return False
        if named != self.settings["section"]:
            self.send_error_object(404, f"no model named {named}", "not_found_error")
            return False
        return True

    def tools_child(self):
        configuration = self.settings["mcp_configuration"]
        if not configuration:
            raise MissingTools("the section carries no MCP configuration")
        return ToolChild(configuration)

    def do_OPTIONS(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def do_GET(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        if parsed.path in ("/", "/index.html"):
            # llama-server serves --path without the API key, which is how the
            # page loads before a human types one into its own field.
            self.serve_page()
            return
        if parsed.path == "/health":
            self.send_json(200, {"status": "ok"})
            return
        if not self.authorized():
            self.send_error_object(401, "an API key is required", "authentication_error")
            return
        if parsed.path in ("/v1/models", "/models"):
            self.send_json(200, {"object": "list", "data": [{
                "id": self.settings["section"],
                "object": "model",
                "status": {"value": "loaded"},
            }]})
            return
        if parsed.path == "/props":
            if not self.resolve_model((query.get("model") or [""])[0]):
                return
            self.send_json(200, {
                "default_generation_settings": {"n_ctx": self.settings["context"]},
                "model_path": self.settings["model_path"],
            })
            return
        if parsed.path == "/tools":
            if not self.resolve_model((query.get("model") or [""])[0]):
                return
            try:
                self.send_json(200, tool_listing(self.tools_child()))
            except MissingTools:
                self.send_error_object(403, "tools are disabled", "feature_disabled")
            except (OSError, ValueError, RuntimeError) as error:
                self.send_error_object(500, f"the tool listing failed: {error}", "server_error")
            return
        self.send_error_object(404, f"no route: {parsed.path}", "not_found_error")

    def serve_page(self):
        path = os.path.join(self.settings["static"], "index.html")
        try:
            with open(path, "rb") as handle:
                body = handle.read()
        except OSError:
            self.send_error_object(404, "no page is served", "not_found_error")
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        parsed = urllib.parse.urlparse(self.path)
        if not self.authorized():
            self.send_error_object(401, "an API key is required", "authentication_error")
            return
        body = self.read_body()
        if parsed.path == "/tools":
            if not self.resolve_model(body.get("model") or ""):
                return
            name = body.get("tool")
            if not isinstance(name, str) or not name:
                self.send_error_object(400, "a tool must be named")
                return
            params = body.get("params")
            if not isinstance(params, dict):
                params = {}
            try:
                self.send_json(200, call_tool(self.tools_child(), name, params))
            except MissingTools:
                self.send_error_object(403, "tools are disabled", "feature_disabled")
            except (OSError, ValueError, RuntimeError) as error:
                self.send_error_object(500, f"the tool call failed: {error}", "server_error")
            return
        if parsed.path == "/v1/chat/completions":
            self.chat_completion(body)
            return
        self.send_error_object(404, f"no route: {parsed.path}", "not_found_error")

    def chat_completion(self, body):
        """Answer one turn, proposing the image call while no tool message exists.

        The turn shape rather than a model decides the branch: a request whose
        messages already carry a `role: tool` entry is the continuation round,
        which reads plain text and ends the turn.
        """
        continuation = any(
            message.get("role") == "tool" for message in body.get("messages") or []
        )
        offered = {
            tool.get("function", {}).get("name")
            for tool in body.get("tools") or []
            if isinstance(tool, dict)
        }
        if continuation or "generate_image" not in offered:
            chunks = [
                {"choices": [{"index": 0, "delta": {"content": self.settings["answer"]}}]},
                {"choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]},
            ]
            message = {"role": "assistant", "content": self.settings["answer"]}
            finish = "stop"
        else:
            call = {
                "index": 0,
                "id": "call_image_admission",
                "type": "function",
                "function": {
                    "name": "generate_image",
                    "arguments": self.settings["image_arguments"],
                },
            }
            chunks = [
                {"choices": [{"index": 0, "delta": {"tool_calls": [call]}}]},
                {"choices": [{"index": 0, "delta": {}, "finish_reason": "tool_calls"}]},
            ]
            message = {"role": "assistant", "content": "", "tool_calls": [call]}
            finish = "tool_calls"
        if body.get("stream"):
            payload = b""
            for chunk in chunks:
                chunk = dict(chunk, model=self.settings["section"], object="chat.completion.chunk")
                payload += b"data: " + json.dumps(chunk).encode("utf-8") + b"\n\n"
            payload += b"data: [DONE]\n\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(payload)
            return
        self.send_json(200, {
            "id": "chatcmpl-admission",
            "object": "chat.completion",
            "model": self.settings["section"],
            "choices": [{"index": 0, "message": message, "finish_reason": finish}],
        })


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main(argv):
    settings = parse_arguments(argv)
    if not settings["preset"]:
        sys.stderr.write("--models-preset names the section this fixture serves\n")
        return 2
    section, keys = read_preset(settings["preset"])
    api_key = ""
    if settings["api_key_file"]:
        with open(settings["api_key_file"], encoding="utf-8") as handle:
            api_key = handle.readline().strip()
    router_settings = {
        "section": keys.get("LLAMA_ARG_ALIAS", section),
        "mcp_configuration": keys.get("LLAMA_ARG_MCP_SERVERS_CONFIG", ""),
        "model_path": keys.get("LLAMA_ARG_MODEL", ""),
        "context": int(keys.get("LLAMA_ARG_CTX_SIZE", "4096")),
        "static": settings["static"],
        "api_key": api_key,
        "image_arguments": os.environ.get(
            "QWEN_FAKE_ROUTER_IMAGE_ARGUMENTS",
            json.dumps({
                "prompt": "a fox in a snowy field",
                "negative_prompt": "blurry",
                "width": 512,
                "height": 512,
                "steps": 1,
                "profile_id": "image-sdxs-512-a",
            }),
        ),
        "answer": os.environ.get(
            "QWEN_FAKE_ROUTER_ANSWER", "The image is ready."
        ),
    }
    server = Server((settings["host"], settings["port"]), Handler)
    server.router_settings = router_settings
    # qwen-webui-session.sh waits for llama.cpp's own router banner before it
    # arms the watchdogs, so the fixture prints the marker that readiness loop
    # greps for.
    sys.stderr.write("starting server in router mode\n")
    sys.stderr.write(
        "fake_router listening {} {} section={} tools={}\n".format(
            settings["host"],
            server.server_address[1],
            router_settings["section"],
            shlex.quote(router_settings["mcp_configuration"] or "none"),
        )
    )
    sys.stderr.flush()
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        while thread.is_alive():
            thread.join(1.0)
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
