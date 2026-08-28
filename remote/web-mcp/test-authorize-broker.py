#!/usr/bin/env python3
"""Drive the approval broker over its own socket with the fake provider.

Each arm launches the broker as a subprocess the way a session launches it,
reads the listening port from its first stdout line, and speaks HTTP to that
port, so the bind refusal, the CORS preflight, the session header, and the
audit rows are measured on the wire rather than through an imported handler.
The grant the broker issues is then spent against `server.py` itself under a
fake provider, which is what proves the two paths agree on one canonical
claim without reaching a network or a key of the operator's.
"""

import hashlib
import http.client
import importlib.util
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest

BROKER_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
BROKER_PATH = os.path.join(BROKER_DIRECTORY, "authorize-broker.py")
SERVER_PATH = os.path.join(BROKER_DIRECTORY, "server.py")
sys.path.insert(0, BROKER_DIRECTORY)

import server  # noqa: E402


def load_broker_module():
    """Import the broker by path so the constants under test are its own."""
    specification = importlib.util.spec_from_file_location(
        "authorize_broker_module", BROKER_PATH
    )
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


broker_module = load_broker_module()
SESSION_HEADER = broker_module.SESSION_HEADER
SESSION_SECRET_FILE_NAME = broker_module.SESSION_SECRET_FILE_NAME

TOKEN_SECRET = "broker-token-secret-QJ4LZP"
ORIGIN = "http://127.0.0.1:8080"
START_WAIT_SECONDS = 15.0
STOP_WAIT_SECONDS = 5.0

FIXTURES = {
    "search": {
        "raven2 vulkan decode": [
            {
                "title": "Vulkan decode on Raven2",
                "url": "https://example.org/raven2",
                "publishedDate": "2026-01-05",
                "author": "A. Measurer",
                "highlights": ["decode reaches 3.07 tok/s"],
            }
        ]
    },
    "contents": {
        "https://example.org/raven2": {"text": "measured decode", "status": "ok"}
    },
}


class BrokerProcess:
    """A running broker and the client that speaks to its port."""

    def __init__(self, test, **overrides):
        self.test = test
        arguments = {
            "--state-dir": test.state_directory,
            "--token-key-file": test.token_key_path,
            "--provider": "fake",
            "--profile": "default",
            "--origin": ORIGIN,
        }
        arguments.update(overrides)
        argv = [sys.executable, BROKER_PATH]
        for option, value in arguments.items():
            if value is not None:
                argv += [option, str(value)]
        self.process = subprocess.Popen(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        )
        self.host = ""
        self.port = 0
        line = self.process.stdout.readline()
        parts = line.split()
        if len(parts) == 3 and parts[0] == "listening":
            self.host, self.port = parts[1], int(parts[2])

    def request(self, method, path, body=None, headers=None):
        connection = http.client.HTTPConnection(self.host, self.port, timeout=10)
        try:
            connection.request(method, path, body, headers or {})
            response = connection.getresponse()
            payload = response.read().decode("utf-8")
            return response.status, dict(response.getheaders()), payload
        finally:
            connection.close()

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=STOP_WAIT_SECONDS)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=STOP_WAIT_SECONDS)
        self.process.stdout.close()
        self.process.stderr.close()


class BrokerTest(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        root = self.workspace.name
        self.state_directory = os.path.join(root, "state")
        os.makedirs(self.state_directory, mode=0o700)
        self.token_key_path = os.path.join(root, "token.key")
        with open(self.token_key_path, "w", encoding="utf-8") as handle:
            handle.write(TOKEN_SECRET + "\n")
        os.chmod(self.token_key_path, 0o600)
        self.fixture_path = os.path.join(root, "fixtures.json")
        with open(self.fixture_path, "w", encoding="utf-8") as handle:
            json.dump(FIXTURES, handle)
        self.brokers = []
        self.addCleanup(self.workspace.cleanup)
        self.addCleanup(self.stop_brokers)

    def stop_brokers(self):
        for broker in self.brokers:
            broker.close()

    def launch(self, **overrides):
        broker = BrokerProcess(self, **overrides)
        self.brokers.append(broker)
        return broker

    def session_secret(self):
        """Read the secret from its file rather than through the endpoint.

        The file is the delivery channel a page uses, so reading it here
        exercises the same authority the browser presents while leaving the
        `/session` arm free to measure the Origin gate on its own.
        """
        path = os.path.join(
            self.state_directory, SESSION_SECRET_FILE_NAME
        )
        deadline = time.time() + START_WAIT_SECONDS
        while time.time() < deadline:
            if os.path.exists(path):
                with open(path, encoding="ascii") as handle:
                    return handle.read().strip()
            time.sleep(0.05)
        self.fail("the broker wrote no session secret file")

    def grant_headers(self, secret=None):
        return {
            "Content-Type": "application/json",
            "Origin": ORIGIN,
            SESSION_HEADER: (
                self.session_secret() if secret is None else secret
            ),
        }

    def post_grant(self, broker, payload, headers=None):
        status, response_headers, body = broker.request(
            "POST",
            "/grant",
            json.dumps(payload),
            self.grant_headers() if headers is None else headers,
        )
        return status, response_headers, json.loads(body)

    def audit_rows(self):
        connection = sqlite3.connect(
            os.path.join(self.state_directory, server.LEDGER_FILE_NAME)
        )
        try:
            return connection.execute(
                "SELECT profile, operation, query_sha256, domains, result_count,"
                " fetched_host, provider_bytes, returned_characters, status"
                " FROM audit"
            ).fetchall()
        finally:
            connection.close()

    def spend(self, token, **overrides):
        """Run one `search_exa` through the server with this grant."""
        arguments = {
            "query": "raven2 vulkan decode",
            "max_results": 1,
            "authorization": token,
        }
        arguments.update(overrides)
        requests = [
            {
                "jsonrpc": "2.0",
                "id": "1",
                "method": "initialize",
                "params": {"protocolVersion": server.PROTOCOL_VERSION},
            },
            {
                "jsonrpc": "2.0",
                "id": "2",
                "method": "tools/call",
                "params": {"name": "search_exa", "arguments": arguments},
            },
        ]
        completed = subprocess.run(
            [sys.executable, SERVER_PATH],
            input="".join(json.dumps(entry) + "\n" for entry in requests),
            capture_output=True,
            text=True,
            env={
                **os.environ,
                "PYTHONDONTWRITEBYTECODE": "1",
                "QWEN_WEB_PROVIDER": "fake",
                "QWEN_WEB_FAKE_FIXTURES": self.fixture_path,
                "QWEN_WEB_TOKEN_KEY_FILE": self.token_key_path,
                "QWEN_WEB_STATE_DIR": self.state_directory,
                "QWEN_WEB_SEARCH_AUTH": "required",
                "QWEN_WEB_PROFILE": "default",
            },
        )
        for line in completed.stdout.splitlines():
            message = json.loads(line)
            if message.get("id") == "2":
                return message
        self.fail(f"the server returned no tool result: {completed.stderr}")

    def test_the_broker_refuses_a_bind_outside_loopback(self):
        for host in ("0.0.0.0", "localhost", "192.168.1.10", "::"):
            with self.subTest(host=host):
                completed = subprocess.run(
                    [
                        sys.executable,
                        BROKER_PATH,
                        "--host",
                        host,
                        "--state-dir",
                        self.state_directory,
                        "--token-key-file",
                        self.token_key_path,
                        "--origin",
                        ORIGIN,
                    ],
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(completed.returncode, 2)
                self.assertIn("loopback literal alone", completed.stderr)
                self.assertEqual(completed.stdout, "")

    def test_the_broker_requires_a_state_directory_and_an_origin(self):
        for argv, expected in (
            (["--token-key-file", self.token_key_path, "--origin", ORIGIN],
             "QWEN_WEB_STATE_DIR"),
            (["--token-key-file", self.token_key_path,
              "--state-dir", self.state_directory], "QWEN_WEB_BROKER_ORIGIN"),
        ):
            with self.subTest(argv=argv):
                completed = subprocess.run(
                    [sys.executable, BROKER_PATH, *argv],
                    capture_output=True,
                    text=True,
                    env={
                        **os.environ,
                        "QWEN_WEB_STATE_DIR": "",
                        "QWEN_WEB_BROKER_ORIGIN": "",
                    },
                )
                self.assertEqual(completed.returncode, 2)
                self.assertIn(expected, completed.stderr)

    def test_a_grant_request_without_the_session_secret_is_refused(self):
        broker = self.launch()
        headers = self.grant_headers()
        for description, replacement in (
            ("absent", None),
            ("empty", ""),
            ("wrong", "a-secret-this-launch-never-wrote"),
        ):
            with self.subTest(secret=description):
                sent = dict(headers)
                if replacement is None:
                    sent.pop(SESSION_HEADER)
                else:
                    sent[SESSION_HEADER] = replacement
                status, _, payload = self.post_grant(
                    broker, {"query": "raven2 vulkan decode"}, sent
                )
                self.assertEqual(status, 403)
                self.assertIn(SESSION_HEADER, payload["error"])
                self.assertNotIn("authorization", payload)

    def test_the_session_endpoint_gates_on_an_admitted_origin(self):
        broker = self.launch()
        secret = self.session_secret()
        for description, headers in (
            ("absent", {}),
            ("foreign", {"Origin": "https://evil.example.net"}),
        ):
            with self.subTest(origin=description):
                status, _, body = broker.request("GET", "/session", None, headers)
                self.assertEqual(status, 403)
                self.assertNotIn(secret, body)
        status, response_headers, body = broker.request(
            "GET", "/session", None, {"Origin": ORIGIN}
        )
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["session_secret"], secret)
        self.assertEqual(response_headers["Access-Control-Allow-Origin"], ORIGIN)
        self.assertNotIn("*", response_headers["Access-Control-Allow-Origin"])
        self.assertNotIn("Access-Control-Allow-Credentials", response_headers)

    def test_the_preflight_admits_the_session_header_for_one_origin(self):
        broker = self.launch()
        status, headers, _ = broker.request(
            "OPTIONS",
            "/grant",
            None,
            {
                "Origin": ORIGIN,
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": SESSION_HEADER,
            },
        )
        self.assertEqual(status, 204)
        self.assertEqual(headers["Access-Control-Allow-Origin"], ORIGIN)
        self.assertIn(
            SESSION_HEADER, headers["Access-Control-Allow-Headers"]
        )
        status, headers, _ = broker.request(
            "OPTIONS", "/grant", None, {"Origin": "https://evil.example.net"}
        )
        self.assertEqual(status, 403)
        self.assertNotIn("Access-Control-Allow-Origin", headers)

    def test_a_host_header_naming_a_resolved_name_is_refused(self):
        broker = self.launch()
        headers = self.grant_headers()
        headers["Host"] = f"rebind.example.net:{broker.port}"
        status, _, payload = self.post_grant(
            broker, {"query": "raven2 vulkan decode"}, headers
        )
        self.assertEqual(status, 403)
        self.assertIn("loopback literal", payload["error"])

    def test_the_issued_grant_admits_the_search_exactly_once(self):
        broker = self.launch()
        status, _, payload = self.post_grant(
            broker, {"query": "  raven2 vulkan decode  ", "max_results": 1}
        )
        self.assertEqual(status, 200)
        token = payload["authorization"]
        first = self.spend(token)
        self.assertFalse(first["result"]["isError"])
        self.assertIn("URL: https://example.org/raven2", self.text(first))
        replayed = self.spend(token)
        self.assertTrue(replayed["result"]["isError"])
        self.assertIn("spent", self.text(replayed))

    def test_a_changed_field_leaves_the_grant(self):
        broker = self.launch()
        status, _, payload = self.post_grant(
            broker,
            {
                "query": "raven2 vulkan decode",
                "max_results": 3,
                "include_domains": ["Example.ORG"],
                "max_age_hours": 24,
            },
        )
        self.assertEqual(status, 200)
        token = payload["authorization"]
        for description, overrides in (
            ("query", {"query": "raven2 vulkan decode in Paris"}),
            ("include_domains", {"include_domains": ["evil.example.net"]}),
            ("exclude_domains", {"exclude_domains": ["example.org"]}),
            ("max_age_hours", {"max_age_hours": 0}),
            ("published_after", {"published_after": "2026-01-01"}),
            ("max_results", {"max_results": 10}),
        ):
            with self.subTest(field=description):
                arguments = {
                    "max_results": 3,
                    "include_domains": ["example.org"],
                    "max_age_hours": 24,
                }
                arguments.update(overrides)
                response = self.spend(token, **arguments)
                self.assertTrue(response["result"]["isError"])
                self.assertIn("authorization", self.text(response))
        admitted = self.spend(
            token,
            max_results=2,
            include_domains=["example.org"],
            max_age_hours=24,
        )
        self.assertFalse(admitted["result"]["isError"])

    def test_a_malformed_field_is_refused_before_the_key_is_read(self):
        broker = self.launch(**{"--token-key-file": "/nonexistent/token.key"})
        for payload in (
            {"query": 5},
            {"query": "q", "max_results": "many"},
            {"query": "q", "include_domains": "example.org"},
            {"query": "q", "max_age_hours": "soon"},
        ):
            with self.subTest(payload=sorted(payload)):
                status, _, body = self.post_grant(broker, payload)
                self.assertEqual(status, 400)
                self.assertNotIn("authorization", body)

    def test_the_rate_bucket_bounds_the_approval_endpoint(self):
        broker = self.launch(**{"--per-minute": 2})
        for _ in range(2):
            status, _, _ = self.post_grant(broker, {"query": "raven2 vulkan decode"})
            self.assertEqual(status, 200)
        status, _, payload = self.post_grant(
            broker, {"query": "raven2 vulkan decode"}
        )
        self.assertEqual(status, 429)
        self.assertIn("authorize-minute", payload["error"])
        self.assertIn("rate_limited", [row[8] for row in self.audit_rows()])

    def test_the_audit_trail_carries_the_digest_and_no_secret(self):
        broker = self.launch()
        status, _, payload = self.post_grant(
            broker,
            {
                "query": "raven2 vulkan decode",
                "max_results": 4,
                "include_domains": ["example.org"],
                "exclude_domains": ["evil.example.net"],
            },
        )
        self.assertEqual(status, 200)
        token = payload["authorization"]
        self.post_grant(broker, {"query": 5})
        rows = self.audit_rows()
        self.assertEqual([row[1] for row in rows], ["authorize", "authorize"])
        self.assertEqual(
            sorted(row[8] for row in rows), ["invalid_argument", "success"]
        )
        issued = next(row for row in rows if row[8] == "success")
        self.assertEqual(issued[2], query_digest("raven2 vulkan decode"))
        self.assertEqual(issued[3], "example.org,-evil.example.net")
        self.assertEqual(issued[4], 4)
        flattened = "\n".join(str(field) for row in rows for field in row)
        self.assertNotIn(TOKEN_SECRET, flattened)
        self.assertNotIn(token, flattened)
        self.assertNotIn("raven2 vulkan decode", flattened)
        self.assertNotIn(self.session_secret(), flattened)

    def test_the_secret_file_is_private_and_leaves_no_residue(self):
        broker = self.launch()
        path = os.path.join(
            self.state_directory, SESSION_SECRET_FILE_NAME
        )
        self.session_secret()
        self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)
        broker.close()
        deadline = time.time() + STOP_WAIT_SECONDS
        while time.time() < deadline and os.path.lexists(path):
            time.sleep(0.05)
        self.assertFalse(os.path.lexists(path))

    def test_no_response_or_stream_carries_the_signing_key(self):
        broker = self.launch()
        status, _, payload = self.post_grant(
            broker, {"query": "raven2 vulkan decode"}
        )
        self.assertEqual(status, 200)
        self.assertNotIn(TOKEN_SECRET, json.dumps(payload))
        # A refusal path is what would raise, so the malformed request runs
        # before stderr is read: a traceback carrying the key would arrive
        # there rather than in the response the client already checked.
        self.post_grant(broker, {"query": 5})
        secret = self.session_secret()
        broker.process.terminate()
        broker.process.wait(timeout=STOP_WAIT_SECONDS)
        stderr = broker.process.stderr.read()
        self.assertNotIn(TOKEN_SECRET, stderr)
        self.assertNotIn("raven2 vulkan decode", stderr)
        self.assertNotIn(secret, stderr)

    def text(self, message):
        return message["result"]["content"][0]["text"]


def query_digest(query):
    return hashlib.sha256(query.strip().encode("utf-8")).hexdigest()


if __name__ == "__main__":
    unittest.main(verbosity=2)
