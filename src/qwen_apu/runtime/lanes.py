"""The two lane children `appliance serve` derives from a profile id.

`qwen-webui-session.sh` composes both argv out of variables an earlier launch
script exported, so a Python launch that took only `--image-service ARG` and
`--searxng ARG` left the operator restating what the ledgers already say. These
functions read the ledgers and the runtime root instead and return the
`ChildSpec` the appliance owns.

The image worker runs a job under validated parameters rather than under the
ledger row, because the row names no runtime binary and no argv template.
`remote/admit-image-router.sh` writes that parameter file for its own
admission harness and `remote/image-launch-lib.sh` validates it field by field
against the row it claims to serve; `image_parameters` is the same derivation
against the checked-in ledgers, written to the declared path
`qwen_home_image_parameters`, so the shell launch and this one hand the worker
the same bytes. `remote/build-web-presets.sh` names that path in the preset and
derives nothing itself.

SearXNG stays a shell launch: `remote/searxng-launch.sh serve STATE_DIRECTORY`
renders the settings, writes a fresh secret at mode 0600, and execs the
instance so the pid the caller forked stays the instance's. This module runs it
as an owned child argv and waits on `GET /healthz`; porting the render is that
script's own cluster.
"""

from __future__ import annotations

import json
import os
import secrets
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

from qwen_apu.config import models as config_models
from qwen_apu.config.schema import ImageProfile, WebProfile
from qwen_apu.install import models as image_ledgers
from qwen_apu.runtime.paths import RuntimePaths

# The image worker binds its control socket under `<state>/images/`, the
# directory `image-service.py` derives from `--state-dir` and
# `remote/build-web-presets.sh` names in QWEN_IMAGE_SERVICE_SOCKET.
IMAGE_DIRECTORY_NAME = "images"
IMAGE_SERVICE_SCRIPT = "image-service.py"
IMAGE_VERIFIER = "image_signed_verifier:verify"
SEARXNG_SCRIPT = "searxng-launch.sh"
LOOPBACK_HOSTS: frozenset[str] = frozenset({"127.0.0.1", "::1", "localhost"})
# The Web UI bearer the worker's artifact listener compares against. The
# gateway serves artifacts from its own `/api/artifacts/` route, so nothing
# else reads this value and the launch mints it fresh rather than sharing the
# grant signing key with a second purpose.
ARTIFACT_KEY_NAME = "image-artifact.key"
SECRET_MODE = 0o600
# `A` places the text encoder, the diffusion trunk, and the VAE on Vulkan, and
# `evidence/image-appliance/served-turn-admission/` is the served turn that
# fixes this spelling. Arms `B` and `C` split the placement across the CPU and
# the device through the runtime's own `te=,vae=,diffusion=` backend form, and
# no retained run fixes which spelling a served launch uses, so this derivation
# refuses them by name rather than guessing one.
VULKAN_BACKEND = "vulkan0"


class LaneRefused(RuntimeError):
    """A lane child cannot be derived, naming the ledger or the root that refused it."""


# -- the image lane -----------------------------------------------------


def image_model_directory(paths: RuntimePaths, profile: ImageProfile) -> Path:
    """The directory the bundle's own fetch script writes every component into.

    `remote/download-sdxs-512.sh` writes `$qwen_home_models/image/sdxs-512` and
    every other image download script follows the identical rule, so the
    diffusion artifact's `fetch_script` names the directory the runtime loads
    the bundle from.
    """
    artifacts = image_ledgers.load_image_artifacts()
    model = image_ledgers.image_model(profile.model_id)
    diffusion = image_ledgers.image_artifact(model.diffusion_artifact, artifacts)
    relative = image_ledgers.image_destination_directory(diffusion.fetch_script)
    return paths["qwen_home_models"] / relative


def image_runtime_argv(paths: RuntimePaths, profile: ImageProfile) -> list[str]:
    """The `sd-cli` argv template the worker substitutes one job's values into.

    The autoencoder slot branches on the artifact's own `component_type`:
    `sdxs-512-vae` reads `tae`, a Tiny AutoEncoder that reaches the runtime
    through `--taesd` because stable-diffusion.cpp's metadata check refuses it
    under the full-VAE loading path
    (evidence/image-appliance/sdxs-512-standalone/README.md). A `vae` artifact
    takes `--vae`, and `packaged` or `-` names no file and adds no flag.
    """
    if profile.placement != "A":
        raise LaneRefused(
            f"image profile {profile.profile_id} reads placement {profile.placement}, and the "
            "retained served turn fixes the backend spelling for placement A alone"
        )
    artifacts = image_ledgers.load_image_artifacts()
    model = image_ledgers.image_model(profile.model_id)
    directory = image_model_directory(paths, profile)
    argv = ["--model", "{model_path}"]
    if model.vae_artifact not in image_ledgers.IMAGE_COMPONENT_SENTINELS:
        component = image_ledgers.image_artifact(model.vae_artifact, artifacts)
        flag = "--taesd" if component.component_type == "tae" else "--vae"
        argv += [flag, str(directory / component.filename)]
    argv += [
        "--backend",
        VULKAN_BACKEND,
        "-W",
        "{width}",
        "-H",
        "{height}",
        "--steps",
        "{steps}",
        "--sampling-method",
        "{sampler}",
        "--cfg-scale",
        "{cfg}",
        "--seed",
        "{seed}",
        "-p",
        "{prompt}",
        "-n",
        "{negative_prompt}",
        "-o",
        "{output}",
    ]
    return argv


def image_parameters(paths: RuntimePaths, profile_id: str) -> dict[str, object]:
    """The parameter document for one profile, keyed by its own profile_id.

    `image_signed_verifier.verify` resolves a request through
    `PROFILES.get(profile_id)`, so one served profile is one entry; a document
    carrying every ledger row would offer a shape this launch armed no worker
    for.
    """
    profile = config_models.image_profile(profile_id)
    return {
        profile.profile_id: {
            "profile_id": profile.profile_id,
            "model_id": profile.model_id,
            "placement": profile.placement,
            "width": profile.width,
            "height": profile.height,
            "steps": profile.steps,
            "sampler": profile.sampler,
            "cfg": profile.cfg,
            "max_steps": profile.max_steps,
            "max_dimension": profile.max_dimension,
            "timeout_s": profile.timeout_s,
            "execution_policy": profile.execution_policy,
            "runtime_path": str(paths["qwen_home_image_runtime"]),
            "runtime_argv": image_runtime_argv(paths, profile),
            "model_path": str(image_model_directory(paths, profile)),
        }
    }


def write_image_parameters(paths: RuntimePaths, profile_id: str) -> Path:
    """Publish the parameter document at the path the runtime root declares.

    `remote/image-launch-lib.sh` refuses a `QWEN_IMAGE_PROFILES_JSON` resolving
    outside the root, so writing at `qwen_home_image_parameters` keeps the
    shell launch and this one interchangeable over one file.
    """
    destination = paths["qwen_home_image_parameters"]
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(image_parameters(paths, profile_id), indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    destination.chmod(SECRET_MODE)
    return destination


def image_artifact_key(paths: RuntimePaths) -> Path:
    """Mint this launch's bearer for the worker's own artifact listener."""
    destination = paths["qwen_home_state"] / ARTIFACT_KEY_NAME
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(secrets.token_hex(32) + "\n", encoding="utf-8")
    destination.chmod(SECRET_MODE)
    return destination


def image_control_socket(paths: RuntimePaths) -> Path:
    """Where the worker binds, which is where the gateway's client connects."""
    return paths["qwen_home_state"] / IMAGE_DIRECTORY_NAME / "image-service.sock"


def image_service_argv(
    paths: RuntimePaths,
    *,
    origin: str,
    bind_host: str,
    parameters: Path,
    api_key_file: Path,
    http_port: int = 0,
) -> tuple[str, ...]:
    """The argv `qwen-webui-session.sh` composes, derived here instead.

    `--http-port 0` is the session's own loopback default, since the artifact
    listener's reader is this process rather than a browser that keeps a URL. A
    gateway bound to a routable address carries that literal through
    `--lan-exposure` the way `QWEN_WEB_LAN=1` admits one IPv4 literal, and the
    listener then binds that literal rather than every interface.
    """
    argv = [
        sys.executable,
        str(paths.tree / "remote" / IMAGE_SERVICE_SCRIPT),
        "--state-dir",
        str(paths["qwen_home_state"]),
        "--profiles-json",
        str(parameters),
        "--verifier",
        IMAGE_VERIFIER,
        "--api-key-file",
        str(api_key_file),
        "--origin",
        origin,
        "--http-host",
        bind_host,
        "--http-port",
        str(http_port),
    ]
    if bind_host not in LOOPBACK_HOSTS:
        argv += ["--lan-exposure", bind_host]
    return tuple(argv)


def image_service_env(
    paths: RuntimePaths, *, profile_id: str, web_profile: str, parameters: Path
) -> dict[str, str]:
    """The four authorities `image_signed_verifier._load_authorities` reads at import.

    That module runs inside the worker and raises before the socket binds where
    any of them is absent, so the spec states them rather than inheriting
    whatever the operator's shell held.
    """
    env = dict(os.environ)
    env["QWEN_IMAGE_PROFILES_JSON"] = str(parameters)
    env["QWEN_IMAGE_TOKEN_KEY_FILE"] = str(paths["qwen_home_web_token_key"])
    env["QWEN_IMAGE_PROFILE"] = profile_id
    env["QWEN_IMAGE_LANGUAGE_PROFILE"] = web_profile
    return env


# -- the search lane ----------------------------------------------------


def searxng_endpoint(profile: WebProfile) -> tuple[str, int] | None:
    """The loopback host and port the profile's `searxng_url` names.

    `config.models.load_web_profiles` already refuses a `searxng_url` outside
    loopback, so a row reaching here either names a loopback endpoint or names
    none at all under provider `exa` or `fake`.
    """
    if profile.provider != "searxng" or not profile.searxng_url:
        return None
    parsed = urlsplit(profile.searxng_url)
    host = parsed.hostname or ""
    if host not in LOOPBACK_HOSTS:
        return None
    return host, parsed.port or 8888


def searxng_argv(paths: RuntimePaths) -> tuple[str, ...]:
    """`serve` runs the render and execs the instance in this child's own pid."""
    return (
        str(paths.tree / "remote" / SEARXNG_SCRIPT),
        "serve",
        str(paths["qwen_home_state"]),
    )


def searxng_components_present(paths: RuntimePaths, *, timeout_s: float = 30.0) -> str:
    """The `check` verdict, which is the one the instance's own launch applies.

    `remote/searxng-launch.sh check` runs `check_instance_components` and exits
    2 where the source tree, the virtual environment, or the settings template
    is absent, printing `searxng_components=present` when all three are there.
    `serve` runs that same check and exits before it binds, so a launch reading
    the verdict first derives no child rather than starting one that leaves at
    once. The return is the empty string where the components are present and
    the refusal sentence otherwise.
    """
    argv = (str(paths.tree / "remote" / SEARXNG_SCRIPT), "check", str(paths["qwen_home_state"]))
    try:
        completed = subprocess.run(  # noqa: S603
            argv, capture_output=True, text=True, timeout=timeout_s, check=False
        )
    except (OSError, subprocess.SubprocessError) as error:
        return f"{SEARXNG_SCRIPT} check did not run: {error}"
    if completed.returncode == 0:
        return ""
    return (completed.stderr or completed.stdout).strip().replace("\n", "; ") or (
        f"{SEARXNG_SCRIPT} check exited {completed.returncode}"
    )


def searxng_env(*, host: str, port: int) -> dict[str, str]:
    """The endpoint the render writes into the instance's own settings.

    `remote/searxng-launch.sh` substitutes `QWEN_SEARXNG_PORT` and
    `QWEN_SEARXNG_BIND_ADDRESS` into the rendered settings rather than only
    comparing them, so a profile choosing a loopback port other than the
    template's default gets an instance listening where its `searxng_url` says.
    """
    env = dict(os.environ)
    env["QWEN_SEARXNG_PORT"] = str(port)
    env["QWEN_SEARXNG_BIND_ADDRESS"] = host
    return env
