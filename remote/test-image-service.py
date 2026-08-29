#!/usr/bin/env python3
"""Drive image-service.py as a subprocess against the fake image runtime.

The service is spawned the way a launch spawns it and every check runs over
the two wires it serves rather than against an imported function: a JSON line
on the Unix control socket and an HTTP request on the loopback artifact
listener. The fake runtime stands in for the pinned Vulkan binary, so the
success arm, every refusal, the timeout, and the cancellation all run without a
device and without a downloaded checkpoint.
"""

import hashlib
import http.client
import json
import os
import signal
import socket
import subprocess
import sys
import tempfile
import time
import unittest

SERVICE_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
SERVICE_PATH = os.path.join(SERVICE_DIRECTORY, "image-service.py")
FAKE_RUNTIME_PATH = os.path.join(
    SERVICE_DIRECTORY, "test-fixtures", "fake-image-runtime.sh"
)
sys.path.insert(0, SERVICE_DIRECTORY)

API_KEY = "image-api-key-TESTONLY7Q2X"
PAGE_ORIGIN = "http://127.0.0.1:8080"
STARTUP_SECONDS = 20.0
REQUEST_SECONDS = 60.0


def load_module():
    """Import image-service.py under a name a dash keeps out of `import`."""
    import importlib.util

    specification = importlib.util.spec_from_file_location(
        "qwen_image_service", SERVICE_PATH
    )
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


service_module = load_module()


def build_profile(runtime_path, execution_policy="validator-gated", **overrides):
    profile = {
        "profile_id": "sdxs-512-a",
        "model_id": "sdxs-512-0.9",
        "placement": "A",
        "width": 64,
        "height": 64,
        "steps": 1,
        "sampler": "euler_a",
        "cfg": 1.0,
        "max_steps": 8,
        "max_dimension": 512,
        "timeout_s": 20,
        "execution_policy": execution_policy,
        "validated_evidence": "evidence/image-service-fake.md",
        "runtime_path": runtime_path,
        "model_path": "",
        "model_sha256": "-",
        "runtime_argv": [
            "--output",
            "{output}",
            "--width",
            "{width}",
            "--height",
            "{height}",
            "--seed",
            "{seed}",
            "--steps",
            "{steps}",
            "--sampler",
            "{sampler}",
            "--cfg",
            "{cfg}",
            "--prompt",
            "{prompt}",
            "--negative-prompt",
            "{negative_prompt}",
        ],
    }
    profile.update(overrides)
    return profile


class ServiceSession:
    """One running service, its control socket, and its artifact listener."""

    def __init__(self, directory, profiles, runtime_environment=None):
        self.directory = directory
        self.state_directory = os.path.join(directory, "state")
        os.makedirs(self.state_directory, mode=0o700, exist_ok=True)
        self.api_key_path = os.path.join(directory, "api.key")
        with open(self.api_key_path, "w", encoding="ascii") as handle:
            handle.write(API_KEY + "\n")
        os.chmod(self.api_key_path, 0o600)
        self.profiles_path = os.path.join(directory, "profiles.json")
        with open(self.profiles_path, "w", encoding="utf-8") as handle:
            json.dump(profiles, handle)
        argv = [
            sys.executable,
            SERVICE_PATH,
            "--state-dir",
            self.state_directory,
            "--profiles-json",
            self.profiles_path,
            "--api-key-file",
            self.api_key_path,
            "--origin",
            PAGE_ORIGIN,
            "--http-host",
            "127.0.0.1",
            "--http-port",
            "0",
        ]
        for name, value in (runtime_environment or {}).items():
            argv.extend(["--runtime-env", f"{name}={value}"])
        self.process = subprocess.Popen(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.socket_path = ""
        self.http_port = 0
        self.pid = 0
        self.read_startup()

    def read_startup(self):
        deadline = time.time() + STARTUP_SECONDS
        while time.time() < deadline and not self.pid:
            line = self.process.stdout.readline()
            if not line:
                raise AssertionError(
                    "the service exited before it announced its addresses: "
                    f"{self.process.stderr.read()}"
                )
            key, _, rest = line.strip().partition(" ")
            if key == "socket":
                self.socket_path = rest
            elif key == "listening":
                self.http_port = int(rest.split()[1])
            elif key == "pid":
                self.pid = int(rest)
        if not self.pid:
            raise AssertionError("the service announced no pid")

    def control(self, payload, timeout=REQUEST_SECONDS):
        connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        connection.settimeout(timeout)
        connection.connect(self.socket_path)
        try:
            connection.sendall(json.dumps(payload).encode("utf-8") + b"\n")
            with connection.makefile("rb") as handle:
                line = handle.readline()
        finally:
            connection.close()
        if not line:
            raise AssertionError("the control socket closed without a response")
        return json.loads(line.decode("utf-8"))

    def http(self, path, headers=None, method="GET"):
        connection = http.client.HTTPConnection("127.0.0.1", self.http_port, timeout=10)
        connection.request(method, path, headers=headers or {})
        response = connection.getresponse()
        body = response.read()
        connection.close()
        return response.status, dict(response.getheaders()), body

    def authorized_http(self, path, extra=None, method="GET"):
        headers = {"Authorization": f"Bearer {API_KEY}"}
        headers.update(extra or {})
        return self.http(path, headers, method)

    def artifact_directory(self):
        return os.path.join(self.state_directory, "images", "artifacts")

    def lease_path(self):
        return os.path.join(self.state_directory, "vulkan-workload.lock")

    def lease_is_free(self):
        """Return whether the workload lease can be taken right now.

        The kernel lock is the authority, so the check acquires and releases it
        rather than reading the text status line beside it.
        """
        import fcntl

        descriptor = os.open(self.lease_path(), os.O_RDWR | os.O_CREAT, 0o644)
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return False
        else:
            fcntl.flock(descriptor, fcntl.LOCK_UN)
            return True
        finally:
            os.close(descriptor)

    def stop(self, timeout=20.0):
        if self.process.poll() is None:
            self.process.send_signal(signal.SIGTERM)
        try:
            stdout, stderr = self.process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            self.process.kill()
            stdout, stderr = self.process.communicate()
            raise AssertionError("the service outlived its SIGTERM")
        return self.process.returncode, stdout, stderr


def generate_request(**overrides):
    request = {
        "protocol_version": 1,
        "request_id": "req-0001",
        "action": "image_generate",
        "authorization": "opaque-grant-string",
        "profile_id": "sdxs-512-a",
        "prompt": "a measured raven",
        "negative_prompt": "blurry",
        "seed": 4242,
        "aspect": "1:1",
        "width": 64,
        "height": 64,
        "steps": 1,
    }
    request.update(overrides)
    return request


class ImageServiceTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="image-service-test-")
        self.addCleanup(self.temporary.cleanup)
        self.sessions = []

    def start(self, profiles=None, runtime_environment=None):
        directory = tempfile.mkdtemp(dir=self.temporary.name)
        if profiles is None:
            profiles = {"sdxs-512-a": build_profile(FAKE_RUNTIME_PATH)}
        session = ServiceSession(directory, profiles, runtime_environment)
        self.sessions.append(session)
        self.addCleanup(self.quiet_stop, session)
        return session

    @staticmethod
    def quiet_stop(session):
        try:
            session.stop()
        except (AssertionError, ValueError):
            pass

    def test_success_names_the_artifact_by_its_own_digest(self):
        """A completed job renames the .part to the SHA-256 of its own bytes."""
        session = self.start()
        response = session.control(generate_request())
        self.assertEqual(response["status"], "completed", response)
        self.assertEqual(response["protocol_version"], 1)
        self.assertEqual(response["request_id"], "req-0001")
        self.assertIsNone(response["error"])
        digest = response["sha256"]
        artifact = os.path.join(session.artifact_directory(), f"{digest}.png")
        with open(artifact, "rb") as handle:
            body = handle.read()
        self.assertEqual(
            hashlib.sha256(body).hexdigest(),
            digest,
            "the artifact name is the digest of the artifact's own bytes",
        )
        self.assertEqual(
            response["provenance_url"],
            f"http://127.0.0.1:{session.http_port}/artifacts/{digest}.json",
        )
        self.assertEqual(
            [name for name in os.listdir(session.artifact_directory())
             if name.endswith(".part")],
            [],
            "a completed job leaves no partial file",
        )

    def test_provenance_records_what_the_service_observed(self):
        """Provenance carries the observed fields and `-` for the rest."""
        session = self.start()
        response = session.control(generate_request())
        digest = response["sha256"]
        with open(
            os.path.join(session.artifact_directory(), f"{digest}.json"),
            encoding="utf-8",
        ) as handle:
            record = json.load(handle)
        self.assertEqual(record["schema"], "qwen-image-provenance/1")
        self.assertEqual(record["png_sha256"], digest)
        self.assertEqual(record["seed"], 4242)
        self.assertEqual(record["width"], 64)
        self.assertEqual(record["height"], 64)
        self.assertEqual(record["aspect"], "1:1")
        self.assertEqual(record["profile_id"], "sdxs-512-a")
        self.assertEqual(record["exit_status"], 0)
        self.assertEqual(record["nice"], 19, "the runtime priority is read back")
        self.assertEqual(record["timeout_s_applied"], 20)
        self.assertEqual(
            record["prompt_sha256"],
            hashlib.sha256("a measured raven".encode("utf-8")).hexdigest(),
            "the record carries the prompt digest rather than the prompt",
        )
        self.assertNotIn("a measured raven", json.dumps(record))
        with open(FAKE_RUNTIME_PATH, "rb") as handle:
            self.assertEqual(
                record["runtime_sha256"],
                hashlib.sha256(handle.read()).hexdigest(),
            )
        self.assertIn(
            f"sha256:{record['prompt_sha256']}",
            record["runtime_argv"],
            "the retained argv names the prompt by its digest",
        )
        for field in (
            "load_seconds",
            "diffusion_seconds",
            "vae_seconds",
            "ring_resets",
            "vm_faults",
            "device_loss",
        ):
            self.assertEqual(
                record[field], "-", f"{field} is reported by the runtime, not here"
            )

    def test_same_seed_reproduces_one_artifact_name(self):
        """Two runs at one seed agree on the digest, on this host."""
        session = self.start()
        first = session.control(generate_request())
        second = session.control(generate_request(request_id="req-0002"))
        self.assertEqual(first["sha256"], second["sha256"])

    def test_dimension_mismatch_is_refused(self):
        """A runtime that ignores the requested geometry produces no artifact."""
        session = self.start(runtime_environment={"QWEN_FAKE_IMAGE_MODE": "dimension"})
        response = session.control(generate_request())
        self.assertEqual(response["status"], "failed", response)
        self.assertEqual(response["reason"], "png_invalid")
        self.assertEqual(response["png_detail"], "dimension")
        self.assertEqual(os.listdir(session.artifact_directory()), [])

    def test_truncated_png_is_refused(self):
        """A half-written file fails the chunk walk rather than being named."""
        session = self.start(runtime_environment={"QWEN_FAKE_IMAGE_MODE": "truncated"})
        response = session.control(generate_request())
        self.assertEqual(response["status"], "failed", response)
        self.assertEqual(response["reason"], "png_invalid")
        self.assertIn(response["png_detail"], ("truncated", "checksum", "decode"))
        self.assertEqual(os.listdir(session.artifact_directory()), [])

    def test_runtime_failure_is_reported_and_leaves_the_lease_free(self):
        """A non-zero runtime exit fails the job and releases the lease."""
        session = self.start(runtime_environment={"QWEN_FAKE_IMAGE_MODE": "fail"})
        response = session.control(generate_request())
        self.assertEqual(response["status"], "failed", response)
        self.assertEqual(response["reason"], "runtime_failed")
        self.assertTrue(session.lease_is_free())

    def test_hang_reaches_the_timeout_and_the_kill(self):
        """A runtime ignoring SIGTERM is ended by SIGKILL after the grace."""
        profiles = {"sdxs-512-a": build_profile(FAKE_RUNTIME_PATH, timeout_s=2)}
        session = self.start(
            profiles=profiles,
            runtime_environment={"QWEN_FAKE_IMAGE_MODE": "hang"},
        )
        started = time.time()
        response = session.control(generate_request())
        elapsed = time.time() - started
        self.assertEqual(response["status"], "failed", response)
        self.assertEqual(response["reason"], "runtime_timeout")
        self.assertGreaterEqual(elapsed, 2.0)
        self.assertLess(elapsed, 40.0)
        self.assertTrue(session.lease_is_free())
        self.assertEqual(
            [name for name in os.listdir(session.artifact_directory())
             if name.endswith(".part")],
            [],
        )

    def test_cancel_ends_the_owned_child_and_removes_the_part(self):
        """Cancellation kills the runtime and the partial file goes with it."""
        session = self.start(
            runtime_environment={"QWEN_FAKE_IMAGE_SLEEP_SECONDS": "10"}
        )
        result = {}

        def run_generate():
            result["response"] = session.control(generate_request())

        import threading

        worker = threading.Thread(target=run_generate)
        worker.start()
        self.wait_for_running(session)
        cancel = session.control(
            {"protocol_version": 1, "request_id": "req-cancel", "action": "cancel"}
        )
        self.assertEqual(cancel["status"], "accepted", cancel)
        worker.join(timeout=30)
        self.assertFalse(worker.is_alive(), "the cancelled generate returned")
        self.assertEqual(result["response"]["status"], "cancelled", result)
        self.assertTrue(session.lease_is_free())
        self.assertEqual(
            [name for name in os.listdir(session.artifact_directory())
             if name.endswith(".part")],
            [],
        )

    def test_cancel_without_a_job_is_refused(self):
        session = self.start()
        response = session.control(
            {"protocol_version": 1, "request_id": "req-idle", "action": "cancel"}
        )
        self.assertEqual(response["status"], "refused")
        self.assertEqual(response["reason"], "not_running")

    def test_second_generate_is_refused_while_one_runs(self):
        """One Vulkan workload at a time, with no queue behind it."""
        session = self.start(
            runtime_environment={"QWEN_FAKE_IMAGE_SLEEP_SECONDS": "5"}
        )
        result = {}

        def run_generate():
            result["response"] = session.control(generate_request())

        import threading

        worker = threading.Thread(target=run_generate)
        worker.start()
        try:
            self.wait_for_running(session)
            second = session.control(generate_request(request_id="req-second"))
            self.assertEqual(second["status"], "refused", second)
            self.assertEqual(second["reason"], "busy")
        finally:
            worker.join(timeout=60)
        self.assertEqual(result["response"]["status"], "completed")

    def test_lease_is_held_during_the_job_and_released_after(self):
        session = self.start(
            runtime_environment={"QWEN_FAKE_IMAGE_SLEEP_SECONDS": "5"}
        )
        result = {}

        def run_generate():
            result["response"] = session.control(generate_request())

        import threading

        worker = threading.Thread(target=run_generate)
        worker.start()
        try:
            status = self.wait_for_running(session)
            self.assertTrue(status["lease_held"])
            self.assertFalse(
                session.lease_is_free(),
                "the kernel lock is taken while the runtime executes",
            )
        finally:
            worker.join(timeout=60)
        self.assertEqual(result["response"]["status"], "completed")
        self.assertTrue(session.lease_is_free())
        idle = session.control(
            {"protocol_version": 1, "request_id": "req-idle2", "action": "status"}
        )
        self.assertEqual(idle["state"], "idle")
        self.assertFalse(idle["lease_held"])

    def test_refused_profile_leaves_the_lease_untouched(self):
        """A policy refusal happens above the lease, so the lock stays free."""
        profiles = {
            "sdxs-512-a": build_profile(FAKE_RUNTIME_PATH, execution_policy="refused")
        }
        session = self.start(profiles=profiles)
        response = session.control(generate_request())
        self.assertEqual(response["status"], "refused", response)
        self.assertEqual(response["reason"], "profile_refused")
        self.assertTrue(session.lease_is_free())
        # Acquisition writes `state=held` beside the lock, so the absence of
        # that line proves the refusal happened before flock rather than after
        # a lease was taken and given back.
        status_path = os.path.join(
            session.state_directory, "vulkan-workload.status"
        )
        self.assertFalse(
            os.path.exists(status_path),
            "a refusal above the lease writes no lease status line",
        )

    def test_lease_held_elsewhere_refuses_the_job(self):
        import fcntl

        session = self.start()
        descriptor = os.open(session.lease_path(), os.O_RDWR | os.O_CREAT, 0o644)
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            response = session.control(generate_request())
        finally:
            fcntl.flock(descriptor, fcntl.LOCK_UN)
            os.close(descriptor)
        self.assertEqual(response["status"], "refused", response)
        self.assertEqual(response["reason"], "lease_unavailable")

    def test_missing_seed_is_refused(self):
        """Randomness is chosen before approval rather than by the service."""
        request = generate_request()
        del request["seed"]
        session = self.start()
        response = session.control(request)
        self.assertEqual(response["status"], "refused")
        self.assertEqual(response["reason"], "invalid_argument")
        self.assertIn("seed", response["error"])

    def test_caller_supplied_path_is_refused(self):
        session = self.start()
        response = session.control(
            generate_request(**{"output": "/tmp/steered.png"})
        )
        self.assertEqual(response["status"], "refused")
        self.assertEqual(response["reason"], "invalid_argument")

    def test_steps_above_the_profile_ceiling_are_refused(self):
        session = self.start()
        response = session.control(generate_request(steps=99))
        self.assertEqual(response["status"], "refused")
        self.assertEqual(response["reason"], "profile_refused")

    def test_oversized_control_line_is_refused(self):
        session = self.start()
        response = session.control(
            generate_request(prompt="x" * (70 * 1024))
        )
        self.assertEqual(response["status"], "refused")
        self.assertEqual(response["reason"], "invalid_argument")

    def test_wrong_protocol_version_is_refused(self):
        session = self.start()
        response = session.control(generate_request(protocol_version=2))
        self.assertEqual(response["status"], "refused")
        self.assertIn("protocol_version", response["error"])

    def test_unauthenticated_artifact_read_is_refused(self):
        """A present hash and an absent one answer 401 to an anonymous reader."""
        session = self.start()
        digest = session.control(generate_request())["sha256"]
        absent = "0" * 64
        for name in (f"{digest}.png", f"{absent}.png"):
            status, headers, _ = session.http(f"/artifacts/{name}")
            self.assertEqual(status, 401, name)
            self.assertIn("WWW-Authenticate", headers)
        status, _, _ = session.http("/health")
        self.assertEqual(status, 401, "health carries the same credential gate")
        status, _, _ = session.http(
            f"/artifacts/{digest}.png?key={API_KEY}"
        )
        self.assertEqual(
            status, 401, "a query parameter carries no authorization"
        )

    def test_authenticated_read_serves_the_artifact_immutably(self):
        session = self.start()
        response = session.control(generate_request())
        digest = response["sha256"]
        status, headers, body = session.authorized_http(f"/artifacts/{digest}.png")
        self.assertEqual(status, 200)
        self.assertEqual(headers["Content-Type"], "image/png")
        self.assertEqual(
            headers["Cache-Control"], "private, max-age=31536000, immutable"
        )
        self.assertEqual(headers["ETag"], f'"{digest}"')
        self.assertEqual(headers["X-Content-Type-Options"], "nosniff")
        self.assertEqual(hashlib.sha256(body).hexdigest(), digest)
        status, headers, body = session.authorized_http(f"/artifacts/{digest}.json")
        self.assertEqual(status, 200)
        self.assertEqual(headers["Content-Type"], "application/json")
        self.assertEqual(json.loads(body)["png_sha256"], digest)

    def test_artifact_path_outside_the_digest_form_is_refused(self):
        session = self.start()
        for path in (
            "/artifacts/../../etc/passwd",
            "/artifacts/%2e%2e%2fetc%2fpasswd",
            "/artifacts/report.png",
            "/artifacts/" + "0" * 63 + ".png",
        ):
            status, _, _ = session.authorized_http(path)
            self.assertEqual(status, 404, path)

    def test_admitted_origin_answers_the_preflight(self):
        session = self.start()
        status, headers, _ = session.http(
            "/health", {"Origin": PAGE_ORIGIN}, method="OPTIONS"
        )
        self.assertEqual(status, 204)
        self.assertEqual(headers["Access-Control-Allow-Origin"], PAGE_ORIGIN)
        self.assertIn("Authorization", headers["Access-Control-Allow-Headers"])
        status, headers, _ = session.http(
            "/health", {"Origin": "http://elsewhere.example"}, method="OPTIONS"
        )
        self.assertEqual(status, 403)
        self.assertNotIn("Access-Control-Allow-Origin", headers)

    def test_health_reports_the_service_state(self):
        session = self.start()
        status, _, body = session.authorized_http("/health")
        self.assertEqual(status, 200)
        payload = json.loads(body)
        self.assertEqual(payload["protocol"], "qwen-image-service/1")
        self.assertEqual(payload["state"], "idle")
        self.assertFalse(payload["lease_held"])
        self.assertEqual(payload["pid"], session.pid)

    def test_shutdown_proves_no_child_no_part_and_a_free_lease(self):
        """SIGTERM during a job leaves no runtime, no .part, and no lease."""
        session = self.start(
            runtime_environment={"QWEN_FAKE_IMAGE_SLEEP_SECONDS": "20"}
        )
        result = {}

        def run_generate():
            try:
                result["response"] = session.control(generate_request())
            except Exception as error:  # noqa: BLE001 -- the socket closes on stop
                result["error"] = error

        import threading

        worker = threading.Thread(target=run_generate)
        worker.start()
        status = self.wait_for_running(session)
        self.assertTrue(status["job_id"], "a job is running when the signal arrives")
        code, stdout, stderr = session.stop()
        worker.join(timeout=30)
        self.assertIn("shutdown", stdout, stderr)
        residue_line = [
            line for line in stdout.splitlines() if line.startswith("shutdown ")
        ][-1]
        self.assertIn("child=absent", residue_line)
        self.assertIn("part_files=0", residue_line)
        self.assertIn("lease=released", residue_line)
        self.assertIn("socket=removed", residue_line)
        self.assertEqual(code, 0, residue_line)
        self.assertFalse(os.path.exists(session.socket_path))
        self.assertTrue(session.lease_is_free())
        self.assertEqual(
            [name for name in os.listdir(session.artifact_directory())
             if name.endswith(".part")],
            [],
        )

    def wait_for_running(self, session, timeout=20.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            status = session.control(
                {
                    "protocol_version": 1,
                    "request_id": "req-status",
                    "action": "status",
                }
            )
            if status["state"] == "running":
                return status
            time.sleep(0.05)
        raise AssertionError("no generation reached the running state")


class PngValidatorTest(unittest.TestCase):
    """The PNG rules, exercised against bytes rather than through a runtime."""

    def valid_png(self, width=4, height=3):
        import binascii
        import struct
        import zlib

        def chunk(kind, body):
            return (
                struct.pack(">I", len(body))
                + kind
                + body
                + struct.pack(">I", binascii.crc32(kind + body) & 0xFFFFFFFF)
            )

        raw = bytearray()
        for _ in range(height):
            raw.append(0)
            raw.extend(b"\x10\x20\x30" * width)
        return (
            b"\x89PNG\r\n\x1a\x0a"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw)))
            + chunk(b"IEND", b"")
        )

    def test_valid_png_reports_its_geometry(self):
        header = service_module.parse_png(self.valid_png(), 4, 3)
        self.assertEqual((header["width"], header["height"]), (4, 3))

    def test_signature_is_required(self):
        with self.assertRaises(service_module.PngInvalid) as caught:
            service_module.parse_png(b"not a png at all", 4, 3)
        self.assertEqual(caught.exception.detail, "signature")

    def test_truncation_is_named(self):
        raw = self.valid_png()
        with self.assertRaises(service_module.PngInvalid) as caught:
            service_module.parse_png(raw[: len(raw) - 20], 4, 3)
        self.assertEqual(caught.exception.detail, "truncated")

    def test_dimension_disagreement_is_named(self):
        with self.assertRaises(service_module.PngInvalid) as caught:
            service_module.parse_png(self.valid_png(), 8, 3)
        self.assertEqual(caught.exception.detail, "dimension")

    def test_corrupt_chunk_fails_its_crc(self):
        raw = bytearray(self.valid_png())
        raw[-5] ^= 0xFF
        with self.assertRaises(service_module.PngInvalid) as caught:
            service_module.parse_png(bytes(raw), 4, 3)
        self.assertIn(caught.exception.detail, ("checksum", "truncated"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
