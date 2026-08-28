#!/usr/bin/env python3
"""Drive the served fallback page through one web-search turn in headless Chromium.

The page is the executor the broker path is built around, so an admission
that reads its source proves the request shape and nothing about the path
the browser runs. This driver opens the page at the router origin in a
headless Chromium, turns the per-turn Web toggle on, sends one prompt, waits
for the approval dialog the page opens over the model's proposal, records the
fields the dialog shows, clicks the one approval, and waits for the turn to
end. It talks to Chromium over the DevTools protocol with the standard
library alone, because the appliance carries Chromium and Python and no
browser-automation package.

The report on stdout is one JSON object: the page origin, the model the page
selected, the dialog fields, the transcript the page holds after the turn,
and the request log the page's own fetch calls produced, captured by wrapping
window.fetch before the prompt is sent. Every request in that log is what the
browser sent; the shell harness compares them against the routes it drove.
"""

import argparse
import base64
import json
import os
import re
import secrets
import socket
import struct
import subprocess
import sys
import tempfile
import time
import urllib.request


class DevToolsSocket:
    """A minimal WebSocket client for one DevTools page session."""

    def __init__(self, url):
        match = re.match(r"ws://([^:/]+):(\d+)(/.*)", url)
        if match is None:
            raise ValueError("unexpected DevTools URL: " + url)
        host, port, path = match.group(1), int(match.group(2)), match.group(3)
        self.sock = socket.create_connection((host, port), timeout=30)
        key = base64.b64encode(secrets.token_bytes(16)).decode("ascii")
        request = (
            "GET {path} HTTP/1.1\r\nHost: {host}:{port}\r\nUpgrade: websocket\r\n"
            "Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        ).format(path=path, host=host, port=port, key=key)
        self.sock.sendall(request.encode("ascii"))
        response = b""
        while b"\r\n\r\n" not in response:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("DevTools handshake closed early")
            response += chunk
        if not response.startswith(b"HTTP/1.1 101"):
            raise ConnectionError("DevTools handshake refused: " + response[:120].decode("latin-1"))
        self.buffer = response.split(b"\r\n\r\n", 1)[1]
        self.next_id = 0

    def _read_exactly(self, count):
        while len(self.buffer) < count:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("DevTools socket closed")
            self.buffer += chunk
        data, self.buffer = self.buffer[:count], self.buffer[count:]
        return data

    def send_text(self, text):
        payload = text.encode("utf-8")
        header = bytearray([0x81])
        length = len(payload)
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", length)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", length)
        mask = secrets.token_bytes(4)
        header += mask
        masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        self.sock.sendall(bytes(header) + masked)

    def receive_text(self):
        message = b""
        while True:
            first, second = self._read_exactly(2)
            opcode = first & 0x0F
            length = second & 0x7F
            if length == 126:
                length = struct.unpack(">H", self._read_exactly(2))[0]
            elif length == 127:
                length = struct.unpack(">Q", self._read_exactly(8))[0]
            if second & 0x80:
                mask = self._read_exactly(4)
                data = bytes(byte ^ mask[index % 4] for index, byte in enumerate(self._read_exactly(length)))
            else:
                data = self._read_exactly(length)
            if opcode == 0x8:
                raise ConnectionError("DevTools closed the socket")
            if opcode == 0x9:
                continue
            message += data
            if first & 0x80:
                return message.decode("utf-8")

    def call(self, method, **params):
        self.next_id += 1
        call_id = self.next_id
        self.send_text(json.dumps({"id": call_id, "method": method, "params": params}))
        while True:
            reply = json.loads(self.receive_text())
            if reply.get("id") == call_id:
                if "error" in reply:
                    raise RuntimeError(method + ": " + json.dumps(reply["error"]))
                return reply.get("result", {})

    def evaluate(self, expression):
        result = self.call(
            "Runtime.evaluate",
            expression=expression,
            awaitPromise=True,
            returnByValue=True,
        )
        if "exceptionDetails" in result:
            raise RuntimeError("page threw: " + json.dumps(result["exceptionDetails"])[:400])
        return result.get("result", {}).get("value")


def wait_for(socket_, expression, seconds, what):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = socket_.evaluate(expression)
        if value:
            return value
        time.sleep(0.5)
    raise TimeoutError("waited {}s for {}".format(seconds, what))


FETCH_RECORDER = """
(() => {
  window.__qwenRequests = [];
  const original = window.fetch;
  window.fetch = function (input, init) {
    const url = typeof input === 'string' ? input : input.url;
    let body = init && init.body;
    if (typeof body !== 'string') body = null;
    window.__qwenRequests.push({
      url: new URL(url, window.location.href).href,
      method: (init && init.method) || 'GET',
      body: body === null ? null : body.slice(0, 4000),
    });
    return original.apply(this, arguments);
  };
  return true;
})()
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--origin", required=True, help="router origin the page is served from")
    parser.add_argument("--prompt", required=True, help="the user turn to send")
    parser.add_argument("--api-key-file", default="",
                        help="file whose first line is the bearer key the page sets before connecting")
    parser.add_argument("--chromium", default="chromium")
    parser.add_argument("--load-timeout", type=int, default=180)
    parser.add_argument("--dialog-timeout", type=int, default=600)
    parser.add_argument("--turn-timeout", type=int, default=900)
    arguments = parser.parse_args()

    profile_directory = tempfile.mkdtemp(prefix="qwen-page-drive.")
    command = [
        arguments.chromium,
        "--headless=new",
        "--no-sandbox",
        "--disable-gpu",
        "--no-first-run",
        "--remote-debugging-port=0",
        "--user-data-dir=" + profile_directory,
        "about:blank",
    ]
    # Chromium keeps writing to stderr for the life of the process, so it
    # goes to a file the driver polls rather than a pipe that would fill.
    browser_log = open(os.path.join(profile_directory, "chromium.log"), "w+b")
    browser = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=browser_log)
    try:
        devtools = None
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline and browser.poll() is None:
            browser_log.seek(0)
            match = re.search(r"DevTools listening on (ws://\S+)", browser_log.read().decode("utf-8", "replace"))
            if match:
                devtools = match.group(1)
                break
            time.sleep(0.2)
        if devtools is None:
            raise RuntimeError("Chromium printed no DevTools address")
        http_origin = re.match(r"ws://([^/]+)/", devtools).group(1)
        request = urllib.request.Request(
            "http://{}/json/new?{}".format(http_origin, arguments.origin + "/"), method="PUT"
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            target = json.load(response)
        page = DevToolsSocket(target["webSocketDebuggerUrl"])
        page.call("Page.enable")
        page.call("Runtime.enable")

        wait_for(page, "document.readyState === 'complete' && typeof requestModel !== 'undefined'",
                 arguments.load_timeout, "the page to load")
        if arguments.api_key_file:
            # The key enters the page through its own field and set-key
            # click, which is the path a user takes; it stays in the
            # throwaway profile's sessionStorage and in no report field.
            with open(arguments.api_key_file, encoding="utf-8") as handle:
                api_key = handle.readline().strip()
            page.evaluate(
                "(() => { document.querySelector('#api-key').value = "
                + json.dumps(api_key)
                + "; document.querySelector('#set-key').click(); return true; })()"
            )
        selected_model = wait_for(page, "requestModel", arguments.load_timeout, "the page to select a model")
        page.evaluate(FETCH_RECORDER)
        page.evaluate("(() => { document.querySelector('#web-tools').checked = true; return true; })()")
        page.evaluate(
            "(() => { const box = document.querySelector('#input'); box.value = "
            + json.dumps(arguments.prompt)
            + "; document.querySelector('#send').click(); return true; })()"
        )
        wait_for(page, "document.querySelector('#web-approval').open", arguments.dialog_timeout,
                 "the approval dialog")
        dialog = page.evaluate(
            "(() => { const args = {}; document.querySelectorAll('#approval-args dt').forEach(dt => {"
            " args[dt.textContent.trim()] = (dt.nextElementSibling || {}).textContent; });"
            " return { heading: document.querySelector('#web-approval h2').textContent,"
            " note: document.querySelector('#approval-note').textContent, args }; })()"
        )
        page.evaluate("(() => { document.querySelector('#approve-once').click(); return true; })()")
        wait_for(page, "busy === false", arguments.turn_timeout, "the turn to end")
        report = page.evaluate(
            "JSON.stringify({ origin: window.location.origin, model: requestModel,"
            " history, requests: window.__qwenRequests,"
            " log: document.querySelector('#log').innerText.slice(0, 6000) })"
        )
        report = json.loads(report)
        report["selected_model_at_load"] = selected_model
        report["dialog"] = dialog
        json.dump(report, sys.stdout, indent=1)
        sys.stdout.write("\n")
        return 0
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


if __name__ == "__main__":
    sys.exit(main())
