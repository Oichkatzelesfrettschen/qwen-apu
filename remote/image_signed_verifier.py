"""Revalidate an image grant at the image-service trust boundary."""

import json
import os
import sys
import time

MODULE_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
WEB_MCP_DIRECTORY = os.path.join(MODULE_DIRECTORY, "web-mcp")
for candidate_directory in (WEB_MCP_DIRECTORY, MODULE_DIRECTORY):
    if candidate_directory not in sys.path:
        sys.path.insert(0, candidate_directory)

import image_grant  # noqa: E402
import server as web_server  # noqa: E402


def _load_authorities():
    profiles_path = os.environ.get("QWEN_IMAGE_PROFILES_JSON", "")
    signing_key_path = os.environ.get("QWEN_IMAGE_TOKEN_KEY_FILE", "")
    language_profile = os.environ.get("QWEN_IMAGE_LANGUAGE_PROFILE") or os.environ.get(
        "QWEN_WEB_PROFILE", ""
    )
    image_profile = os.environ.get("QWEN_IMAGE_PROFILE", "")
    if not all((profiles_path, signing_key_path, language_profile, image_profile)):
        raise RuntimeError("the signed image verifier authorities are incomplete")
    with open(profiles_path, encoding="utf-8") as handle:
        profiles = json.load(handle)
    signing_key = web_server.read_secret_file(signing_key_path, "image signing")
    return profiles, signing_key, language_profile, image_profile


PROFILES, SIGNING_KEY, LANGUAGE_PROFILE, IMAGE_PROFILE = _load_authorities()


def verify(request):
    """Verify the grant and return the bound profile parameters."""
    authorization = request.get("authorization")
    claim = image_grant.verify_image_grant(SIGNING_KEY, authorization, time.time())
    image_grant.enforce_image_authorization(
        claim, LANGUAGE_PROFILE, IMAGE_PROFILE, request
    )
    profile = PROFILES.get(request.get("profile_id"))
    if not isinstance(profile, dict):
        raise web_server.AuthorizationDenied("the signed request names no profile")
    return profile
