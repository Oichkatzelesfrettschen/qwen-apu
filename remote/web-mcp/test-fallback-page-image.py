#!/usr/bin/env python3
"""Drive the served fallback page through one image-generation turn.

The Image half of PR D is the same one-human-approval discipline as the web
search tool, with its own grant context (qwen-image-generate-v1) and its own
synchronous state line. This test stands up one stub HTTP server that plays
every route the page touches -- the model roster, the tool listing, a
streamed chat completion that proposes image_generate_image, the broker's session
and grant-image routes, the executor's POST /tools, and the artifact PNG --
and drives the served page in headless Chromium over the DevTools protocol,
the way drive-fallback-page.py drives the web search turn. It reuses that
script's DevToolsSocket, wait_for, and fetch-recording helpers rather than
reimplementing browser plumbing a second time.

Exit status is non-zero on any assertion failure; a human-readable summary
of what passed is printed on success.
"""

import base64
import hashlib
import http.server
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

THIS_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(THIS_DIRECTORY))
FALLBACK_UI_PATH = os.path.join(REPO_ROOT, "webui", "index.html")

# A well-known minimal 1x1 transparent PNG, used as the served artifact body.
ONE_PIXEL_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
    "+A8AAQUBAScY42YAAAAASUVORK5CYII="
)
ARTIFACT_SHA256 = hashlib.sha256(ONE_PIXEL_PNG).hexdigest()
ARTIFACT_PATH = "/artifacts/{}.png".format(ARTIFACT_SHA256)
# image-service.py derives both routes from the digest: artifact_url names
# the PNG and provenance_url names the retained record. The page reads the
# record's identity out of the result and composes the image route itself,
# so the stub answers with the provenance route the service answers with.
PROVENANCE_PATH = "/artifacts/{}.json".format(ARTIFACT_SHA256)
API_KEY = "test-image-key"
GRANT_TOKEN = "grant-token-abc"
SESSION_SECRET = "session-secret-xyz"
# llama-server serves an MCP tool as `<server>_<tool>`: server_mcp_tool sets
# name = server_name + "_" + tool_name (tools/server/server-tools.cpp:1814) and
# the listing composes the same string (:2046), so the section's `image` server
# serves `generate_image` as `image_generate_image` and the page addresses it by
# that name. The stub composes it here once, the way the router does.
IMAGE_MCP_SERVER_NAME = "image"
IMAGE_MCP_TOOL_NAME = "generate_image"
IMAGE_TOOL_NAME = "{}_{}".format(IMAGE_MCP_SERVER_NAME, IMAGE_MCP_TOOL_NAME)

# Load drive-fallback-page.py by path: its filename carries a hyphen, so it
# is not importable as a normal module.
_spec = importlib.util.spec_from_file_location(
    "drive_fallback_page", os.path.join(THIS_DIRECTORY, "drive-fallback-page.py"))
drive_fallback_page = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(drive_fallback_page)


class RecordingState:
    def __init__(self):
        self.lock = threading.Lock()
        self.grant_image_bodies = []
        self.tools_post_bodies = []
        self.artifact_auth_headers = []


def make_handler(state):
    fallback_html = open(FALLBACK_UI_PATH, "rb").read()

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *_args):
            pass

        def _send_json(self, status, payload):
            body = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        def _read_json_body(self):
            length = int(self.headers.get("Content-Length", "0") or "0")
            raw = self.rfile.read(length) if length else b""
            return json.loads(raw.decode("utf-8")) if raw else {}

        def do_OPTIONS(self):  # noqa: N802
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Headers", "*")
            self.send_header("Access-Control-Allow-Methods", "*")
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_GET(self):  # noqa: N802
            parsed_path = self.path.split("?", 1)[0]
            if parsed_path in ("/", "/index.html"):
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.send_header("Content-Length", str(len(fallback_html)))
                self.end_headers()
                self.wfile.write(fallback_html)
                return
            if parsed_path == "/v1/models":
                self._send_json(200, {"data": [{"id": "image-test-profile"}]})
                return
            if parsed_path == "/props":
                self._send_json(200, {"default_generation_settings": {"n_ctx": 4096}})
                return
            if parsed_path == "/tools":
                self._send_json(200, [{
                    "tool": IMAGE_TOOL_NAME,
                    "definition": {
                        "type": "function",
                        "function": {
                            "name": IMAGE_TOOL_NAME,
                            "description": "Generate one image.",
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    "prompt": {"type": "string"},
                                    "negative_prompt": {"type": "string"},
                                    "width": {"type": "integer"},
                                    "height": {"type": "integer"},
                                    "steps": {"type": "integer"},
                                    "profile_id": {"type": "string"},
                                    "seed": {"type": "integer"},
                                    "authorization": {"type": "string"},
                                },
                                "required": ["prompt", "profile_id", "width", "height", "steps"],
                            },
                        },
                    },
                }])
                return
            if parsed_path == "/session":
                self._send_json(200, {"session_secret": SESSION_SECRET})
                return
            if parsed_path == ARTIFACT_PATH:
                auth = self.headers.get("Authorization", "")
                with state.lock:
                    state.artifact_auth_headers.append(auth)
                if auth != "Bearer " + API_KEY:
                    self._send_json(401, {"error": "missing or wrong credential"})
                    return
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Content-Length", str(len(ONE_PIXEL_PNG)))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(ONE_PIXEL_PNG)
                return
            self._send_json(404, {"error": "no route: " + self.path})

        def do_POST(self):  # noqa: N802
            parsed_path = self.path.split("?", 1)[0]
            if parsed_path == "/v1/chat/completions":
                request_body = self._read_json_body()
                already_ran = any(
                    message.get("role") == "tool"
                    for message in request_body.get("messages", []))
                if already_ran:
                    # The model proposes the image tool exactly once; the
                    # continuation round after the tool result reads plain
                    # text with no further calls, so the turn ends the way an
                    # ordinary model turn would rather than the fixture
                    # re-proposing the same call every round.
                    chunks = [
                        {"choices": [{"delta": {"content": "Here is your fox."}}]},
                        {"choices": [{"delta": {}, "finish_reason": "stop"}],
                         "usage": {"completion_tokens": 4}},
                    ]
                else:
                    arguments = json.dumps({
                        "prompt": "a fox in a snowy field",
                        "negative_prompt": "blurry, low quality",
                        "width": 512, "height": 512, "steps": 4,
                        "profile_id": "sdxs-512-arm-a",
                    })
                    chunks = [
                        {"choices": [{"delta": {"tool_calls": [{
                            "index": 0,
                            "function": {"name": IMAGE_TOOL_NAME, "arguments": arguments},
                        }]}}]},
                        {"choices": [{"delta": {}, "finish_reason": "tool_calls"}],
                         "usage": {"completion_tokens": 1}},
                    ]
                body = b""
                for chunk in chunks:
                    body += ("data: " + json.dumps(chunk) + "\n\n").encode("utf-8")
                body += b"data: [DONE]\n\n"
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            if parsed_path == "/grant-image":
                payload = self._read_json_body()
                with state.lock:
                    state.grant_image_bodies.append(payload)
                if self.headers.get("X-Qwen-Web-Session") != SESSION_SECRET:
                    self._send_json(403, {"error": "bad session"})
                    return
                if payload.get("context") != "qwen-image-generate-v1":
                    self._send_json(400, {"error": "wrong grant context"})
                    return
                self._send_json(200, {"authorization": GRANT_TOKEN})
                return
            if parsed_path == "/tools":
                payload = self._read_json_body()
                with state.lock:
                    state.tools_post_bodies.append(payload)
                if payload.get("tool") != IMAGE_TOOL_NAME:
                    self._send_json(200, {"error": "unknown tool"})
                    return
                params = payload.get("params") or {}
                if params.get("authorization") != GRANT_TOKEN:
                    self._send_json(200, {"error": "grant did not verify"})
                    return
                result = {
                    "status": "completed",
                    "sha256": ARTIFACT_SHA256,
                    "provenance_url": PROVENANCE_PATH,
                }
                self._send_json(200, {"plain_text_response": json.dumps(result)})
                return
            self._send_json(404, {"error": "no route: " + self.path})

    return Handler


# The finding this scenario reproduces: against the real qwen38-4b-distill,
# the model sometimes spends its whole reply budget on prose and proposes no
# tool call, so the approval dialog never opens and drive-fallback-page.py's
# wait_for() raises TimeoutError. The prose text is asserted for verbatim so
# the test fails if a future edit stops retaining the model's reply on that
# path.
PROSE_REPLY = (
    "I can describe a fox in a snowy field for you, but I have not called "
    "any tool to draw one."
)


def make_prose_handler():
    """Plays a router whose model never proposes the image tool.

    Serves the same page, roster, and tool listing as make_handler(), and
    answers every /v1/chat/completions call with plain text and
    finish_reason: stop -- no tool_calls delta -- so the page's approval
    dialog for the image lane never opens.
    """
    fallback_html = open(FALLBACK_UI_PATH, "rb").read()

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *_args):
            pass

        def _send_json(self, status, payload):
            body = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        def do_OPTIONS(self):  # noqa: N802
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Headers", "*")
            self.send_header("Access-Control-Allow-Methods", "*")
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_GET(self):  # noqa: N802
            parsed_path = self.path.split("?", 1)[0]
            if parsed_path in ("/", "/index.html"):
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.send_header("Content-Length", str(len(fallback_html)))
                self.end_headers()
                self.wfile.write(fallback_html)
                return
            if parsed_path == "/v1/models":
                self._send_json(200, {"data": [{"id": "image-test-profile"}]})
                return
            if parsed_path == "/props":
                self._send_json(200, {"default_generation_settings": {"n_ctx": 4096}})
                return
            if parsed_path == "/tools":
                self._send_json(200, [{
                    "tool": IMAGE_TOOL_NAME,
                    "definition": {
                        "type": "function",
                        "function": {
                            "name": IMAGE_TOOL_NAME,
                            "description": "Generate one image.",
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    "prompt": {"type": "string"},
                                    "profile_id": {"type": "string"},
                                    "width": {"type": "integer"},
                                    "height": {"type": "integer"},
                                    "steps": {"type": "integer"},
                                },
                                "required": ["prompt", "profile_id", "width", "height", "steps"],
                            },
                        },
                    },
                }])
                return
            self._send_json(404, {"error": "no route: " + self.path})

        def do_POST(self):  # noqa: N802
            parsed_path = self.path.split("?", 1)[0]
            if parsed_path == "/v1/chat/completions":
                chunks = [
                    {"choices": [{"delta": {"content": PROSE_REPLY}}]},
                    {"choices": [{"delta": {}, "finish_reason": "stop"}],
                     "usage": {"completion_tokens": 24}},
                ]
                body = b""
                for chunk in chunks:
                    body += ("data: " + json.dumps(chunk) + "\n\n").encode("utf-8")
                body += b"data: [DONE]\n\n"
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            self._send_json(404, {"error": "no route: " + self.path})

    return Handler


def test_timeout_without_proposal():
    """Runs drive-fallback-page.py as admit-image-router.sh does: as a

    subprocess against a router that answers prose without a proposal, so
    the approval dialog never opens. Asserts the process exits non-zero, still
    writes a parseable JSON report on stdout, names the TimeoutError, and
    retains the model's prose reply in `history` rather than losing it to an
    uncaught traceback.
    """
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), make_prose_handler())
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    origin = "http://127.0.0.1:{}".format(port)
    chromium = os.environ.get("QWEN_CHROMIUM", "chromium")
    driver = os.path.join(THIS_DIRECTORY, "drive-fallback-page.py")
    try:
        result = subprocess.run(
            [sys.executable, driver, "--origin", origin, "--prompt", "draw a fox",
             "--lane", "image", "--chromium", chromium,
             "--load-timeout", "30", "--dialog-timeout", "3", "--turn-timeout", "10"],
            capture_output=True, text=True, timeout=90)
    finally:
        server.shutdown()
        thread.join(timeout=5)

    failures = []
    if result.returncode == 0:
        failures.append(
            "drive-fallback-page.py exited 0 against a router that proposed no tool call")

    try:
        report = json.loads(result.stdout)
    except json.JSONDecodeError:
        sys.stderr.write("test-fallback-page-image (timeout-without-proposal) stdout: "
                          + result.stdout[:2000] + "\n")
        sys.stderr.write("test-fallback-page-image (timeout-without-proposal) stderr: "
                          + result.stderr[:2000] + "\n")
        failures.append(
            "drive-fallback-page.py wrote no parseable JSON report on the dialog timeout")
        return failures

    error = report.get("error") or {}
    if error.get("type") != "TimeoutError":
        failures.append("report[\"error\"][\"type\"] was not TimeoutError: " + repr(error))
    if "dialog" not in report or report["dialog"] is not None:
        failures.append("report[\"dialog\"] was not null: " + repr(report.get("dialog")))

    assistant_messages = [m for m in (report.get("history") or []) if m.get("role") == "assistant"]
    if not assistant_messages:
        failures.append("the report retained no assistant message from the model's prose reply")
    else:
        last = assistant_messages[-1]
        if PROSE_REPLY not in (last.get("content") or ""):
            failures.append(
                "the retained assistant message did not carry the model's prose: "
                + repr(last.get("content")))
        if last.get("tool_calls"):
            failures.append(
                "the retained assistant message carried a tool call the fixture never proposed")
    return failures


def test_full_authorization():
    state = RecordingState()
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), make_handler(state))
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    origin = "http://127.0.0.1:{}".format(port)

    profile_directory = tempfile.mkdtemp(prefix="qwen-image-page-drive.")
    chromium = os.environ.get("QWEN_CHROMIUM", "chromium")
    command = [
        chromium, "--headless=new", "--no-sandbox", "--disable-gpu",
        "--no-first-run", "--remote-debugging-port=0",
        "--user-data-dir=" + profile_directory, "about:blank",
    ]
    browser_log = open(os.path.join(profile_directory, "chromium.log"), "w+b")
    browser = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=browser_log)
    try:
        devtools = None
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline and browser.poll() is None:
            browser_log.seek(0)
            match = re.search(
                r"DevTools listening on (ws://\S+)",
                browser_log.read().decode("utf-8", "replace"))
            if match:
                devtools = match.group(1)
                break
            time.sleep(0.2)
        if devtools is None:
            raise RuntimeError("Chromium printed no DevTools address")
        http_origin = re.match(r"ws://([^/]+)/", devtools).group(1)

        # The broker origin defaults to the hardcoded loopback fallback the
        # page ships with; this stub plays both the router and the broker on
        # one origin, so the page must be told to use it via ?broker=, the
        # same override qwen-webui-session.sh's own operator uses.
        import urllib.parse as _urlparse
        page_url = origin + "/?broker=" + _urlparse.quote(origin, safe="")
        request = urllib.request.Request(
            "http://{}/json/new?{}".format(http_origin, page_url), method="PUT")
        with urllib.request.urlopen(request, timeout=30) as response:
            target = json.load(response)
        page = drive_fallback_page.DevToolsSocket(target["webSocketDebuggerUrl"])
        page.call("Page.enable")
        page.call("Runtime.enable")

        drive_fallback_page.wait_for(
            page, "document.readyState === 'complete' && typeof requestModel !== 'undefined'",
            30, "the page to load")
        page.evaluate(
            "(() => { document.querySelector('#api-key').value = " + json.dumps(API_KEY) +
            "; document.querySelector('#set-key').click(); return true; })()")
        # The stub serves the artifact routes on its own origin, and the real
        # listener binds an ephemeral port, so the page is told where it is
        # the way an operator tells it: through the field.
        page.evaluate(
            "(() => { document.querySelector('#artifact-origin').value = " + json.dumps(origin) +
            "; return true; })()")
        drive_fallback_page.wait_for(page, "requestModel", 30, "the page to select a model")
        page.evaluate(drive_fallback_page.FETCH_RECORDER)
        page.evaluate(
            "(() => { document.querySelector('#image-tools').checked = true; return true; })()")
        page.evaluate(
            "(() => { document.querySelector('#input').value = 'draw a fox'; "
            "document.querySelector('#send').click(); return true; })()")

        drive_fallback_page.wait_for(
            page, "document.querySelector('#image-approval').open", 30,
            "the image approval dialog")
        dialog_fields = page.evaluate(
            "(() => { const args = {}; document.querySelectorAll('#image-approval-args dt')"
            ".forEach(dt => { args[dt.textContent.trim()] = "
            "(dt.nextElementSibling || {}).textContent; }); return args; })()")

        state_after_approval = page.evaluate(
            "(() => (document.querySelector('.image-state') || {}).textContent || null)()")
        if state_after_approval is not None:
            raise AssertionError(
                "an image-state element exists before approval: " + repr(state_after_approval))

        page.evaluate(
            "(() => { document.querySelector('#image-approve-once').click(); return true; })()")

        drive_fallback_page.wait_for(
            page,
            "(() => { const el = document.querySelector('.image-state'); "
            "return el && el.textContent === 'Image complete'; })()",
            60, "the image generation to complete")

        report = page.evaluate(
            "JSON.stringify({ history, requests: window.__qwenRequests, "
            "imgSrc: (document.querySelector('.image-artifact img') || {}).src || null, "
            "caption: (document.querySelector('.image-artifact figcaption') || {}).textContent "
            "|| null })")
        report = json.loads(report)
    finally:
        browser_log.close()
        browser.terminate()
        try:
            browser.wait(timeout=10)
        except subprocess.TimeoutExpired:
            browser.kill()
        for root, directories, files in os.walk(profile_directory, topdown=False):
            for name in files:
                os.unlink(os.path.join(root, name))
            for name in directories:
                os.rmdir(os.path.join(root, name))
        os.rmdir(profile_directory)
        server.shutdown()
        thread.join(timeout=5)

    # ---- Assertions -------------------------------------------------------
    failures = []

    if "generated by this page" not in (dialog_fields.get("seed") or ""):
        failures.append("dialog did not name the generated seed: " + repr(dialog_fields.get("seed")))
    if dialog_fields.get("prompt") != "a fox in a snowy field":
        failures.append("dialog prompt field mismatch: " + repr(dialog_fields.get("prompt")))
    if dialog_fields.get("profile") != "sdxs-512-arm-a":
        failures.append("dialog profile field mismatch: " + repr(dialog_fields.get("profile")))

    with state.lock:
        grant_bodies = list(state.grant_image_bodies)
        tools_bodies = list(state.tools_post_bodies)
        artifact_headers = list(state.artifact_auth_headers)

    if len(grant_bodies) != 1:
        failures.append("expected exactly one POST /grant-image, saw {}".format(len(grant_bodies)))
    else:
        grant = grant_bodies[0]
        if grant.get("context") != "qwen-image-generate-v1":
            failures.append("grant did not carry the qwen-image-generate-v1 context: " + repr(grant))
        if not isinstance(grant.get("prompt_hash"), str) or len(grant["prompt_hash"]) != 64:
            failures.append("grant did not carry a SHA-256 prompt hash: " + repr(grant.get("prompt_hash")))
        if grant.get("aspect") != "1:1":
            failures.append("grant aspect was not derived from width and height: " + repr(grant))
        if grant.get("max_dimension") != 512:
            failures.append("grant max_dimension was not the larger side: " + repr(grant))
        if not isinstance(grant.get("seed"), int):
            failures.append("grant did not carry an integer seed: " + repr(grant.get("seed")))

    image_tool_calls = [body for body in tools_bodies if body.get("tool") == IMAGE_TOOL_NAME]
    if len(image_tool_calls) != 1:
        failures.append("expected exactly one POST /tools for " + IMAGE_TOOL_NAME + ", saw {}"
                         .format(len(image_tool_calls)))
    else:
        params = image_tool_calls[0].get("params") or {}
        if params.get("authorization") != GRANT_TOKEN:
            failures.append("the " + IMAGE_TOOL_NAME + " call did not carry the issued grant")
        if "prompt" not in params:
            failures.append("the " + IMAGE_TOOL_NAME + " call carried no prompt")
        # remote/image-mcp/server.py names this argument profile_id, requires
        # it, and refuses any name outside its schema, so the page's own wire
        # spelling is checked here rather than only against a stub that would
        # accept either.
        if params.get("profile_id") != "sdxs-512-arm-a":
            failures.append("the " + IMAGE_TOOL_NAME + " call named no profile_id: " + repr(params.get("profile_id")))
        if "profile" in params:
            failures.append("the " + IMAGE_TOOL_NAME + " call carries a profile key the tool refuses by name")

    if "Bearer " + API_KEY not in artifact_headers:
        failures.append("the artifact fetch never carried the page's credential header")

    if not (report.get("imgSrc") or "").startswith("blob:"):
        failures.append("the artifact <img> did not resolve to a blob: URL: " + repr(report.get("imgSrc")))

    caption = report.get("caption") or ""
    if ARTIFACT_SHA256 not in caption:
        failures.append("the artifact card caption does not name the sha256")
    if "512x512" not in caption:
        failures.append("the artifact card caption does not name the dimensions")

    tool_messages = [m for m in report.get("history", [])
                      if m.get("role") == "tool" and m.get("name") == IMAGE_TOOL_NAME]
    if len(tool_messages) != 1:
        failures.append("expected exactly one retained " + IMAGE_TOOL_NAME + " tool message, saw {}"
                         .format(len(tool_messages)))
    else:
        content = tool_messages[0].get("content", "")
        if ARTIFACT_SHA256 not in content:
            failures.append("the retained tool message does not name the sha256")
        if PROVENANCE_PATH not in content:
            failures.append("the retained tool message does not name the provenance URL")
        if GRANT_TOKEN in content:
            failures.append("the retained tool message carries the spent grant")
        if base64.b64encode(ONE_PIXEL_PNG).decode("ascii")[:16] in content:
            failures.append("the retained tool message carries image bytes")

    history_text = json.dumps(report.get("history", []))
    if GRANT_TOKEN in history_text:
        failures.append("the grant token reached the transcript somewhere")

    requests_to_grant_image = [r for r in report.get("requests", [])
                                if r.get("url", "").endswith("/grant-image")]
    if len(requests_to_grant_image) != 1:
        failures.append("expected exactly one browser fetch to /grant-image, saw {}"
                         .format(len(requests_to_grant_image)))

    if failures:
        sys.stderr.write("test-fallback-page-image failures (full-authorization):\n")
        for failure in failures:
            sys.stderr.write("  - " + failure + "\n")
        sys.stderr.write("report: " + json.dumps(report, indent=1) + "\n")
        return failures, []

    success_lines = [
        "fallback_page_image_authorization=accepted",
        "dialog_fields=" + json.dumps(dialog_fields),
        "grant_context=" + grant_bodies[0]["context"],
        "artifact_sha256=" + ARTIFACT_SHA256,
        "history_tool_message=" + tool_messages[0]["content"],
    ]
    return [], success_lines


def main():
    failures = []

    authorization_failures, success_lines = test_full_authorization()
    failures.extend(authorization_failures)

    timeout_failures = test_timeout_without_proposal()
    failures.extend(timeout_failures)
    if timeout_failures:
        sys.stderr.write("test-fallback-page-image failures (timeout-without-proposal):\n")
        for failure in timeout_failures:
            sys.stderr.write("  - " + failure + "\n")

    if failures:
        return 1

    for line in success_lines:
        print(line)
    print("browser_turn_timeout_retains_prose=accepted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
