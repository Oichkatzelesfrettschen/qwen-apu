"""The two lane children `appliance serve` derives, proven against the checked-in ledgers.

Nothing here reaches a device. The parameter document is compared field by
field with the ledger rows it claims to serve, the argv is compared word for
word with what `remote/qwen-webui-session.sh` composes, and both readiness
waits run against fakes: a child that binds the control socket, and a child
that answers `GET /healthz` on a loopback port.
"""

from __future__ import annotations

import json
import shutil
import socket
import sys
from pathlib import Path

import pytest

from qwen_apu.config import models as config_models
from qwen_apu.config.schema import ImageProfile, WebProfile
from qwen_apu.engines.image import ImageControlClient
from qwen_apu.runtime import appliance, lanes
from qwen_apu.runtime.paths import RuntimePaths

TREE = Path(__file__).resolve().parents[1]
SERVED_PROFILE = "image-sdxs-512-a"
SHAPE_ONLY_PROFILE = "image-sdxs-512-b"
SEARXNG_PROFILE = "web-lookup"
PYTHON = shutil.which("python3")

pytestmark = pytest.mark.skipif(PYTHON is None, reason="no python3")


@pytest.fixture
def root(tmp_path: Path) -> RuntimePaths:
    paths = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    paths.lay_out()
    return paths


# ---------------------------------------------------------------------------
# The parameter document
# ---------------------------------------------------------------------------


def test_the_parameters_carry_the_ledger_row_field_by_field(root: RuntimePaths) -> None:
    """`remote/image-launch-lib.sh` compares eleven fields; the derivation states all of them."""
    document = lanes.image_parameters(root, SERVED_PROFILE)
    assert set(document) == {SERVED_PROFILE}
    entry = document[SERVED_PROFILE]
    row = config_models.image_profile(SERVED_PROFILE)
    for field in (
        "model_id",
        "placement",
        "width",
        "height",
        "steps",
        "sampler",
        "cfg",
        "max_steps",
        "max_dimension",
        "timeout_s",
        "execution_policy",
    ):
        assert entry[field] == getattr(row, field), field
    assert entry["runtime_path"] == str(root["qwen_home_image_runtime"])
    assert entry["model_path"] == str(root["qwen_home_models"] / "image" / "sdxs-512")


def test_the_autoencoder_slot_follows_the_artifact_component_type(root: RuntimePaths) -> None:
    """`sdxs-512-vae` reads `tae`, so it reaches the runtime through `--taesd`."""
    argv = lanes.image_runtime_argv(root, _profile(SERVED_PROFILE))
    assert "--taesd" in argv
    assert "--vae" not in argv
    taesd = argv[argv.index("--taesd") + 1]
    assert taesd == str(
        root["qwen_home_models"]
        / "image"
        / "sdxs-512"
        / "vae"
        / "diffusion_pytorch_model.safetensors"
    )
    # Every value the worker substitutes is a placeholder rather than a number
    # this derivation baked in, so one parameter set serves every admitted job.
    for placeholder in ("{width}", "{height}", "{steps}", "{seed}", "{prompt}", "{output}"):
        assert placeholder in argv
    assert argv[argv.index("--backend") + 1] == "vulkan0"


def test_a_split_placement_refuses_rather_than_guessing_a_backend(root: RuntimePaths) -> None:
    with pytest.raises(lanes.LaneRefused) as refusal:
        lanes.image_runtime_argv(root, _profile(SHAPE_ONLY_PROFILE))
    assert "placement B" in str(refusal.value)


def test_the_parameters_publish_at_the_path_the_root_declares(root: RuntimePaths) -> None:
    written = lanes.write_image_parameters(root, SERVED_PROFILE)
    assert written == root["qwen_home_image_parameters"]
    assert written.stat().st_mode & 0o077 == 0
    assert set(json.loads(written.read_text(encoding="utf-8"))) == {SERVED_PROFILE}


# ---------------------------------------------------------------------------
# The argv the session composes
# ---------------------------------------------------------------------------

# The flags `remote/qwen-webui-session.sh` passes to `image-service.py` on a
# loopback launch, in its own order. A LAN launch adds --lan-exposure and the
# open flags; this is the pairing the derivation reproduces.
SESSION_IMAGE_FLAGS: tuple[str, ...] = (
    "--state-dir",
    "--profiles-json",
    "--verifier",
    "--api-key-file",
    "--origin",
    "--http-host",
    "--http-port",
)


def test_the_image_argv_is_the_one_the_session_composes(root: RuntimePaths) -> None:
    parameters = lanes.write_image_parameters(root, SERVED_PROFILE)
    key = lanes.image_artifact_key(root)
    argv = lanes.image_service_argv(
        root,
        origin="http://127.0.0.1:8600",
        bind_host="127.0.0.1",
        parameters=parameters,
        api_key_file=key,
    )
    assert argv[0] == sys.executable
    assert argv[1] == str(TREE / "remote" / "image-service.py")
    values = {argv[index]: argv[index + 1] for index in range(1, len(argv) - 1)}
    for flag in SESSION_IMAGE_FLAGS:
        assert flag in argv, flag
    assert values["--state-dir"] == str(root["qwen_home_state"])
    assert values["--profiles-json"] == str(parameters)
    assert values["--verifier"] == "image_signed_verifier:verify"
    assert values["--api-key-file"] == str(key)
    assert values["--origin"] == "http://127.0.0.1:8600"
    assert values["--http-host"] == "127.0.0.1"
    assert values["--http-port"] == "0"
    assert "--lan-exposure" not in argv


def test_a_routable_bind_carries_the_exposure_literal(root: RuntimePaths) -> None:
    argv = lanes.image_service_argv(
        root,
        origin="http://192.168.1.20:8600",
        bind_host="192.168.1.20",
        parameters=root["qwen_home_image_parameters"],
        api_key_file=root["qwen_home_state"] / "image-artifact.key",
    )
    assert argv[argv.index("--lan-exposure") + 1] == "192.168.1.20"


def test_the_image_environment_states_every_verifier_authority(root: RuntimePaths) -> None:
    """`image_signed_verifier._load_authorities` raises at import where one is absent."""
    env = lanes.image_service_env(
        root,
        profile_id=SERVED_PROFILE,
        web_profile="web-open",
        parameters=root["qwen_home_image_parameters"],
    )
    assert env["QWEN_IMAGE_PROFILES_JSON"] == str(root["qwen_home_image_parameters"])
    assert env["QWEN_IMAGE_TOKEN_KEY_FILE"] == str(root["qwen_home_web_token_key"])
    assert env["QWEN_IMAGE_PROFILE"] == SERVED_PROFILE
    assert env["QWEN_IMAGE_LANGUAGE_PROFILE"] == "web-open"


def test_the_socket_is_where_the_worker_binds_and_the_gateway_connects(root: RuntimePaths) -> None:
    """`image-service.py` joins `--state-dir` to `images/`, and so does the client."""
    derived = lanes.image_control_socket(root)
    assert derived == root["qwen_home_state"] / "images" / "image-service.sock"
    assert ImageControlClient.under_state(root["qwen_home_state"]).socket_path == derived


# ---------------------------------------------------------------------------
# The search instance
# ---------------------------------------------------------------------------


def test_the_searxng_endpoint_comes_from_the_profile_url() -> None:
    row = next(
        entry for entry in config_models.load_web_profiles() if entry.profile_id == SEARXNG_PROFILE
    )
    assert lanes.searxng_endpoint(row) == ("127.0.0.1", 8888)


def test_a_profile_naming_no_instance_derives_no_child(root: RuntimePaths) -> None:
    row = WebProfile(
        profile_id="web-fake",
        model_id="qwen35-08b",
        web_mode="off",
        context=4096,
        validated_filled_depth=None,
        max_results=1,
        max_fetches=1,
        max_chars_per_fetch=1,
        multi_source="no",
        vision_allowed="no",
        tool_selection="graded",
        execution_policy="refused",
        provider="fake",
        primary_category=None,
        fallback_category=None,
        minimum_results=None,
        searxng_url=None,
    )
    assert lanes.searxng_endpoint(row) is None


def test_the_searxng_child_runs_the_launch_script_as_an_argv_list(root: RuntimePaths) -> None:
    _image, search = appliance.child_specs_from_request(root, web_profile=SEARXNG_PROFILE)
    assert search is not None
    assert search.argv == (
        str(TREE / "remote" / "searxng-launch.sh"),
        "serve",
        str(root["qwen_home_state"]),
    )
    assert search.env["QWEN_SEARXNG_PORT"] == "8888"
    assert search.env["QWEN_SEARXNG_BIND_ADDRESS"] == "127.0.0.1"
    assert search.port == 8888
    assert search.ready == appliance.READY_HEALTHZ


# ---------------------------------------------------------------------------
# The derivation the appliance performs
# ---------------------------------------------------------------------------


def test_a_shape_only_image_profile_arms_no_worker(root: RuntimePaths) -> None:
    """`refused` admits a shape and spends no device time, so no process exists."""
    image, _search = appliance.child_specs_from_request(root, image_profile=SHAPE_ONLY_PROFILE)
    assert image is None


def test_the_served_image_profile_derives_the_whole_child(root: RuntimePaths) -> None:
    image, _search = appliance.child_specs_from_request(
        root,
        image_profile=SERVED_PROFILE,
        web_profile="web-open",
        origin="http://127.0.0.1:8600",
    )
    assert image is not None
    assert image.name == appliance.IMAGE_CHILD
    assert image.ready == appliance.READY_SOCKET
    assert image.socket_path == str(lanes.image_control_socket(root))
    assert image.env["QWEN_IMAGE_PROFILE"] == SERVED_PROFILE
    assert root["qwen_home_image_parameters"].is_file()


def test_a_whole_argv_override_keeps_the_process_identity_alone(root: RuntimePaths) -> None:
    image, search = appliance.child_specs_from_request(
        root,
        image_service=["python3", "worker.py"],
        searxng=["searxng-launch.sh", "serve", "/state"],
        image_profile=SERVED_PROFILE,
        web_profile=SEARXNG_PROFILE,
    )
    assert image is not None and search is not None
    assert image.argv == ("python3", "worker.py")
    assert search.argv == ("searxng-launch.sh", "serve", "/state")


# ---------------------------------------------------------------------------
# The readiness waits
# ---------------------------------------------------------------------------


def _run(root: RuntimePaths) -> appliance.Appliance:
    return appliance.Appliance(root, appliance.ApplianceRequest())


def _socket_fake(root: RuntimePaths, path: Path) -> appliance.ChildSpec:
    program = (
        "import socket,sys,time,os\n"
        "os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True)\n"
        "s=socket.socket(socket.AF_UNIX)\n"
        "s.bind(sys.argv[1])\n"
        "s.listen(1)\n"
        "time.sleep(30)\n"
    )
    return appliance.ChildSpec(
        name=appliance.IMAGE_CHILD,
        argv=(str(PYTHON), "-c", program, str(path)),
        env={"PATH": "/usr/bin:/bin"},
        log_name="fake-image",
        socket_path=str(path),
        ready=appliance.READY_SOCKET,
        ready_deadline_s=20.0,
    )


def test_the_appliance_waits_for_the_control_socket(root: RuntimePaths) -> None:
    path = root["qwen_home_state"] / "images" / "image-service.sock"
    spec = _socket_fake(root, path)
    run = _run(root)
    owned = run._start(spec)
    try:
        run._await_ready(spec, owned)
        assert path.is_socket()
    finally:
        run._shut_down(None)


def test_a_worker_that_leaves_before_binding_names_itself(root: RuntimePaths) -> None:
    spec = appliance.ChildSpec(
        name=appliance.IMAGE_CHILD,
        argv=(str(PYTHON), "-c", "raise SystemExit(3)"),
        env={"PATH": "/usr/bin:/bin"},
        log_name="fake-image",
        socket_path=str(root["qwen_home_state"] / "images" / "image-service.sock"),
        ready=appliance.READY_SOCKET,
        ready_deadline_s=20.0,
    )
    run = _run(root)
    owned = run._start(spec)
    try:
        with pytest.raises(appliance.ApplianceRefused) as refusal:
            run._await_ready(spec, owned)
        assert "image-service exited status=3" in str(refusal.value)
    finally:
        run._shut_down(None)


def test_the_appliance_waits_for_healthz(root: RuntimePaths) -> None:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    program = (
        "import http.server,sys\n"
        "class H(http.server.BaseHTTPRequestHandler):\n"
        "    def do_GET(self):\n"
        "        self.send_response(200 if self.path=='/healthz' else 404)\n"
        "        self.end_headers()\n"
        "    def log_message(self,*a):\n"
        "        pass\n"
        "http.server.HTTPServer(('127.0.0.1',int(sys.argv[1])),H).serve_forever()\n"
    )
    spec = appliance.ChildSpec(
        name=appliance.SEARXNG_CHILD,
        argv=(str(PYTHON), "-c", program, str(port)),
        env={"PATH": "/usr/bin:/bin"},
        log_name="fake-searxng",
        port=port,
        ready=appliance.READY_HEALTHZ,
        ready_deadline_s=20.0,
    )
    run = _run(root)
    owned = run._start(spec)
    try:
        run._await_ready(spec, owned)
    finally:
        run._shut_down(None)


def test_the_record_carries_both_lane_children(root: RuntimePaths) -> None:
    """`state/appliance.json` names every owned child's listener identity."""
    record = appliance.ApplianceRecord(path=appliance.record_path(root))
    record.write(
        appliance.ApplianceState(
            state="ready",
            children=(
                appliance.ChildRecord(
                    name=appliance.IMAGE_CHILD,
                    pid=11,
                    pgid=11,
                    start_time=101,
                    argv0=sys.executable,
                    socket_path=str(lanes.image_control_socket(root)),
                ),
                appliance.ChildRecord(
                    name=appliance.SEARXNG_CHILD,
                    pid=12,
                    pgid=12,
                    start_time=102,
                    argv0="searxng-launch.sh",
                    port=8888,
                ),
            ),
        )
    )
    read = record.read()
    assert read is not None
    assert [child.name for child in read.children] == [
        appliance.IMAGE_CHILD,
        appliance.SEARXNG_CHILD,
    ]
    rendered = appliance.render(read)
    assert "images/image-service.sock" in rendered
    assert "child name=searxng pid=12 start_time=102 port=8888" in rendered


def _profile(profile_id: str) -> ImageProfile:
    return config_models.image_profile(profile_id)
